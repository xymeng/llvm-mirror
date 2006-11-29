//===--- llvm-as.cpp - The low-level LLVM assembler -----------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file was developed by the LLVM research group and is distributed under
// the University of Illinois Open Source License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
//  This utility may be invoked in the following manner:
//   llvm-as --help         - Output information about command line switches
//   llvm-as [options]      - Read LLVM asm from stdin, write bytecode to stdout
//   llvm-as [options] x.ll - Read LLVM asm from the x.ll file, write bytecode
//                            to the x.bc file.
//
//===----------------------------------------------------------------------===//

#include "llvm/Module.h"
#include "llvm/Assembly/Parser.h"
#include "llvm/Bytecode/Writer.h"
#include "llvm/Analysis/Verifier.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Streams.h"
#include "llvm/Support/SystemUtils.h"
#include "llvm/System/Signals.h"
#include <fstream>
#include <iostream>
#include <memory>
using namespace llvm;

static cl::opt<std::string>
InputFilename(cl::Positional, cl::desc("<input .llvm file>"), cl::init("-"));

static cl::opt<std::string>
OutputFilename("o", cl::desc("Override output filename"),
               cl::value_desc("filename"));

static cl::opt<bool>
Force("f", cl::desc("Overwrite output files"));

static cl::opt<bool>
DumpAsm("d", cl::desc("Print assembly as parsed"), cl::Hidden);

static cl::opt<bool>
NoCompress("disable-compression", cl::init(false),
           cl::desc("Don't compress the generated bytecode"));

static cl::opt<bool>
DisableVerify("disable-verify", cl::Hidden,
              cl::desc("Do not run verifier on input LLVM (dangerous!)"));

int main(int argc, char **argv) {
  cl::ParseCommandLineOptions(argc, argv, " llvm .ll -> .bc assembler\n");
  sys::PrintStackTraceOnErrorSignal();

  int exitCode = 0;
  std::ostream *Out = 0;
  try {
    // Parse the file now...
    ParseError Err;
    std::auto_ptr<Module> M(ParseAssemblyFile(InputFilename,&Err));
    if (M.get() == 0) {
      llvm_cerr << argv[0] << ": " << Err.getMessage() << "\n"; 
      return 1;
    }

    if (!DisableVerify) {
      std::string Err;
      if (verifyModule(*M.get(), ReturnStatusAction, &Err)) {
        llvm_cerr << argv[0]
                  << ": assembly parsed, but does not verify as correct!\n";
        llvm_cerr << Err;
        return 1;
      } 
    }

    if (DumpAsm) llvm_cerr << "Here's the assembly:\n" << *M.get();

    if (OutputFilename != "") {   // Specified an output filename?
      if (OutputFilename != "-") {  // Not stdout?
        if (!Force && std::ifstream(OutputFilename.c_str())) {
          // If force is not specified, make sure not to overwrite a file!
          llvm_cerr << argv[0] << ": error opening '" << OutputFilename
                    << "': file exists!\n"
                    << "Use -f command line argument to force output\n";
          return 1;
        }
        Out = new std::ofstream(OutputFilename.c_str(), std::ios::out |
                                std::ios::trunc | std::ios::binary);
      } else {                      // Specified stdout
        // FIXME: cout is not binary!
        Out = &std::cout;
      }
    } else {
      if (InputFilename == "-") {
        OutputFilename = "-";
        Out = &std::cout;
      } else {
        std::string IFN = InputFilename;
        int Len = IFN.length();
        if (IFN[Len-3] == '.' && IFN[Len-2] == 'l' && IFN[Len-1] == 'l') {
          // Source ends in .ll
          OutputFilename = std::string(IFN.begin(), IFN.end()-3);
        } else {
          OutputFilename = IFN;   // Append a .bc to it
        }
        OutputFilename += ".bc";

        if (!Force && std::ifstream(OutputFilename.c_str())) {
          // If force is not specified, make sure not to overwrite a file!
          llvm_cerr << argv[0] << ": error opening '" << OutputFilename
                    << "': file exists!\n"
                    << "Use -f command line argument to force output\n";
          return 1;
        }

        Out = new std::ofstream(OutputFilename.c_str(), std::ios::out |
                                std::ios::trunc | std::ios::binary);
        // Make sure that the Out file gets unlinked from the disk if we get a
        // SIGINT
        sys::RemoveFileOnSignal(sys::Path(OutputFilename));
      }
    }

    if (!Out->good()) {
      llvm_cerr << argv[0] << ": error opening " << OutputFilename << "!\n";
      return 1;
    }

    if (Force || !CheckBytecodeOutputToConsole(Out,true)) {
      llvm_ostream L(*Out);
      WriteBytecodeToFile(M.get(), L, !NoCompress);
    }
  } catch (const std::string& msg) {
    llvm_cerr << argv[0] << ": " << msg << "\n";
    exitCode = 1;
  } catch (...) {
    llvm_cerr << argv[0] << ": Unexpected unknown exception occurred.\n";
    exitCode = 1;
  }

  if (Out != &std::cout) delete Out;
  return exitCode;
}

