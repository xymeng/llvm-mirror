//===- opt.cpp - The LLVM Modular Optimizer -------------------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file was developed by the LLVM research group and is distributed under
// the University of Illinois Open Source License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// Optimizations may be specified an arbitrary number of times on the command
// line, They are run in the order specified.
//
//===----------------------------------------------------------------------===//

#include "llvm/Module.h"
#include "llvm/PassManager.h"
#include "llvm/Bytecode/Reader.h"
#include "llvm/Bytecode/WriteBytecodePass.h"
#include "llvm/Assembly/PrintModulePass.h"
#include "llvm/Analysis/Verifier.h"
#include "llvm/Target/TargetData.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Support/PassNameParser.h"
#include "llvm/System/Signals.h"
#include "llvm/Support/PluginLoader.h"
#include "llvm/Support/Streams.h"
#include "llvm/Support/SystemUtils.h"
#include "llvm/Support/Timer.h"
#include "llvm/LinkAllPasses.h"
#include "llvm/LinkAllVMCore.h"
#include <iostream>
#include <fstream>
#include <memory>
#include <algorithm>
using namespace llvm;

// The OptimizationList is automatically populated with registered Passes by the
// PassNameParser.
//
static cl::list<const PassInfo*, bool, PassNameParser>
PassList(cl::desc("Optimizations available:"));

static cl::opt<bool> NoCompress("disable-compression", cl::init(false),
       cl::desc("Don't compress the generated bytecode"));

// Other command line options...
//
static cl::opt<std::string>
InputFilename(cl::Positional, cl::desc("<input bytecode file>"), 
    cl::init("-"), cl::value_desc("filename"));

static cl::opt<std::string>
OutputFilename("o", cl::desc("Override output filename"),
               cl::value_desc("filename"), cl::init("-"));

static cl::opt<bool>
Force("f", cl::desc("Overwrite output files"));

static cl::opt<bool>
PrintEachXForm("p", cl::desc("Print module after each transformation"));

static cl::opt<bool>
NoOutput("disable-output",
         cl::desc("Do not write result bytecode file"), cl::Hidden);

static cl::opt<bool>
NoVerify("disable-verify", cl::desc("Do not verify result module"), cl::Hidden);

static cl::opt<bool>
Quiet("q", cl::desc("Obsolete option"), cl::Hidden);

static cl::alias
QuietA("quiet", cl::desc("Alias for -q"), cl::aliasopt(Quiet));

static cl::opt<bool>
AnalyzeOnly("analyze", cl::desc("Only perform analysis, no optimization"));

static Timer BytecodeLoadTimer("Bytecode Loader");

// ---------- Define Printers for module and function passes ------------
namespace {

struct ModulePassPrinter : public ModulePass {
  const PassInfo *PassToPrint;
  ModulePassPrinter(const PassInfo *PI) : PassToPrint(PI) {}

  virtual bool runOnModule(Module &M) {
    if (!Quiet) {
      llvm_cout << "Printing analysis '" << PassToPrint->getPassName() 
                << "':\n";
      getAnalysisID<Pass>(PassToPrint).print(llvm_cout, &M);
    }

    // Get and print pass...
    return false;
  }

  virtual const char *getPassName() const { return "'Pass' Printer"; }

  virtual void getAnalysisUsage(AnalysisUsage &AU) const {
    AU.addRequiredID(PassToPrint);
    AU.setPreservesAll();
  }
};

struct FunctionPassPrinter : public FunctionPass {
  const PassInfo *PassToPrint;
  FunctionPassPrinter(const PassInfo *PI) : PassToPrint(PI) {}

  virtual bool runOnFunction(Function &F) {
    if (!Quiet) {
      llvm_cout << "Printing analysis '" << PassToPrint->getPassName()
		<< "' for function '" << F.getName() << "':\n";
    }
    // Get and print pass...
    getAnalysisID<Pass>(PassToPrint).print(llvm_cout, F.getParent());
    return false;
  }

  virtual const char *getPassName() const { return "FunctionPass Printer"; }

  virtual void getAnalysisUsage(AnalysisUsage &AU) const {
    AU.addRequiredID(PassToPrint);
    AU.setPreservesAll();
  }
};

struct BasicBlockPassPrinter : public BasicBlockPass {
  const PassInfo *PassToPrint;
  BasicBlockPassPrinter(const PassInfo *PI) : PassToPrint(PI) {}

  virtual bool runOnBasicBlock(BasicBlock &BB) {
    if (!Quiet) {
      llvm_cout << "Printing Analysis info for BasicBlock '" << BB.getName()
		<< "': Pass " << PassToPrint->getPassName() << ":\n";
    }

    // Get and print pass...
    getAnalysisID<Pass>(PassToPrint).print(
      llvm_cout, BB.getParent()->getParent());
    return false;
  }

  virtual const char *getPassName() const { return "BasicBlockPass Printer"; }

  virtual void getAnalysisUsage(AnalysisUsage &AU) const {
    AU.addRequiredID(PassToPrint);
    AU.setPreservesAll();
  }
};

} // anonymous namespace


//===----------------------------------------------------------------------===//
// main for opt
//
int main(int argc, char **argv) {
  try {
    cl::ParseCommandLineOptions(argc, argv,
      " llvm .bc -> .bc modular optimizer and analysis printer \n");
    sys::PrintStackTraceOnErrorSignal();

    // Allocate a full target machine description only if necessary.
    // FIXME: The choice of target should be controllable on the command line.
    std::auto_ptr<TargetMachine> target;

    std::string ErrorMessage;

    // Load the input module...
    std::auto_ptr<Module> M(ParseBytecodeFile(InputFilename, &ErrorMessage));
    if (M.get() == 0) {
      llvm_cerr << argv[0] << ": ";
      if (ErrorMessage.size())
        llvm_cerr << ErrorMessage << "\n";
      else
        llvm_cerr << "bytecode didn't read correctly.\n";
      return 1;
    }

    // Figure out what stream we are supposed to write to...
    // FIXME: cout is not binary!
    std::ostream *Out = &std::cout;  // Default to printing to stdout...
    if (OutputFilename != "-") {
      if (!Force && std::ifstream(OutputFilename.c_str())) {
        // If force is not specified, make sure not to overwrite a file!
        llvm_cerr << argv[0] << ": error opening '" << OutputFilename
                  << "': file exists!\n"
                  << "Use -f command line argument to force output\n";
        return 1;
      }
      std::ios::openmode io_mode = std::ios::out | std::ios::trunc |
                                   std::ios::binary;
      Out = new std::ofstream(OutputFilename.c_str(), io_mode);

      if (!Out->good()) {
        llvm_cerr << argv[0] << ": error opening " << OutputFilename << "!\n";
        return 1;
      }

      // Make sure that the Output file gets unlinked from the disk if we get a
      // SIGINT
      sys::RemoveFileOnSignal(sys::Path(OutputFilename));
    }

    // If the output is set to be emitted to standard out, and standard out is a
    // console, print out a warning message and refuse to do it.  We don't
    // impress anyone by spewing tons of binary goo to a terminal.
    if (!Force && !NoOutput && CheckBytecodeOutputToConsole(Out,!Quiet)) {
      NoOutput = true;
    }

    // Create a PassManager to hold and optimize the collection of passes we are
    // about to build...
    //
    PassManager Passes;

    // Add an appropriate TargetData instance for this module...
    Passes.add(new TargetData(M.get()));

    // Create a new optimization pass for each one specified on the command line
    for (unsigned i = 0; i < PassList.size(); ++i) {
      const PassInfo *PassInf = PassList[i];
      Pass *P = 0;
      if (PassInf->getNormalCtor())
        P = PassInf->getNormalCtor()();
      else if (PassInf->getTargetCtor()) {
        assert(target.get() && "Could not allocate target machine!");
        P = PassInf->getTargetCtor()(*target.get());
      } else
        llvm_cerr << argv[0] << ": cannot create pass: "
                  << PassInf->getPassName() << "\n";
      if (P) {
        Passes.add(P);
        
        if (AnalyzeOnly) {
          if (dynamic_cast<BasicBlockPass*>(P))
            Passes.add(new BasicBlockPassPrinter(PassInf));
          else if (dynamic_cast<FunctionPass*>(P))
            Passes.add(new FunctionPassPrinter(PassInf));
          else
            Passes.add(new ModulePassPrinter(PassInf));
        }
      }
      
      if (PrintEachXForm)
        Passes.add(new PrintModulePass(&llvm_cerr));
    }

    // Check that the module is well formed on completion of optimization
    if (!NoVerify)
      Passes.add(createVerifierPass());

    // Write bytecode out to disk or cout as the last step...
    if (!NoOutput && !AnalyzeOnly) {
      llvm_ostream L(*Out);
      Passes.add(new WriteBytecodePass(&L, Out != &std::cout, !NoCompress));
    }

    // Now that we have all of the passes ready, run them.
    Passes.run(*M.get());

    return 0;

  } catch (const std::string& msg) {
    llvm_cerr << argv[0] << ": " << msg << "\n";
  } catch (...) {
    llvm_cerr << argv[0] << ": Unexpected unknown exception occurred.\n";
  }
  return 1;
}
