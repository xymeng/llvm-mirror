//===- Mips16InstrFormats.td - Mips Instruction Formats ----*- tablegen -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
//  Describe MIPS instructions format
//
//  CPU INSTRUCTION FORMATS
//
//  funct or f      Function field
//
//  immediate       4-,5-,8- or 11-bit immediate, branch displacemen, or
//  or imm          address displacement
//
//  op              5-bit major operation code  
//
//  rx              3-bit source or destination register
//
//  ry              3-bit source or destination register
//
//  rz              3-bit source or destination register
//
//  sa              3- or 5-bit shift amount
//
//===----------------------------------------------------------------------===//

// Format specifies the encoding used by the instruction.  This is part of the
// ad-hoc solution used to emit machine instruction encodings by our machine
// code emitter.
//
class Format16<bits<5> val> {
  bits<5> Value = val;
}

def Pseudo16          : Format16<0>;
def FrmI16            : Format16<1>;
def FrmRI16           : Format16<2>;
def FrmRR16           : Format16<3>;
def FrmRRI16          : Format16<4>;
def FrmRRR16          : Format16<5>;
def FrmRRI_A16        : Format16<6>;
def FrmSHIFT16        : Format16<7>;
def FrmI8_TYPE16      : Format16<8>;
def FrmI8_MOVR3216    : Format16<9>;
def FrmI8_MOV32R16    : Format16<10>;
def FrmI8_SVRS16      : Format16<11>;
def FrmJAL16          : Format16<12>;
def FrmJALX16         : Format16<13>;
def FrmEXT_I16        : Format16<14>;
def FrmASMACRO16      : Format16<15>;
def FrmEXT_RI16       : Format16<16>;
def FrmEXT_RRI16      : Format16<17>;
def FrmEXT_RRI_A16    : Format16<18>;
def FrmEXT_SHIFT16    : Format16<19>;
def FrmEXT_I816       : Format16<20>;
def FrmEXT_I8_SVRS16  : Format16<21>;
def FrmOther16        : Format16<22>; // Instruction w/ a custom format

// Generic Mips 16 Format
class MipsInst16<dag outs, dag ins, string asmstr, list<dag> pattern,
                 InstrItinClass itin, Format16 f>: Instruction
{
  field bits<16> Inst;
  Format16 Form = f;

  let Namespace = "Mips";

  bits<5> Opcode = 0;

  // Top 6 bits are the 'opcode' field
  let Inst{15-11} = Opcode;

  let OutOperandList = outs;
  let InOperandList  = ins;

  let AsmString   = asmstr;
  let Pattern     = pattern;
  let Itinerary   = itin;

  //
  // Attributes specific to Mips instructions...
  //
  bits<5> FormBits = Form.Value;

  // TSFlags layout should be kept in sync with MipsInstrInfo.h.
  let TSFlags{4-0}   = FormBits;
}

//
// TBD. Maybe MipsInst16 and Mips16_EXTEND should be derived from a single
// base class
//

class MipsInst16_EXTEND<dag outs, dag ins, string asmstr, list<dag> pattern,
                        InstrItinClass itin, Format16 f>: Instruction
{
  field bits<32> Inst;
  Format16 Form = f;

  let Namespace = "Mips";

  bits<5> Opcode = 0;
  bits<5> extend;

  // Top 6 bits are the 'opcode' field
  let Inst{31-27} = extend;
  let Inst{15-11} = Opcode;

  let OutOperandList = outs;
  let InOperandList  = ins;

  let AsmString   = asmstr;
  let Pattern     = pattern;
  let Itinerary   = itin;

  //
  // Attributes specific to Mips instructions...
  //
  bits<5> FormBits = Form.Value;

  // TSFlags layout should be kept in sync with MipsInstrInfo.h.
  let TSFlags{4-0}   = FormBits;
}



// Mips Pseudo Instructions Format
class MipsPseudo16<dag outs, dag ins, string asmstr, list<dag> pattern>:
                   MipsInst16<outs, ins, asmstr, pattern, IIPseudo, Pseudo16> {
  let isCodeGenOnly = 1;
  let isPseudo = 1;
}


//===----------------------------------------------------------------------===//
// Format I instruction class in Mips : <|opcode|immediate|>
//===----------------------------------------------------------------------===//

class FI16<bits<5> op, dag outs, dag ins, string asmstr, list<dag> pattern,
           InstrItinClass itin>: MipsInst16<outs, ins, asmstr, pattern, 
                                            itin, FrmI16>
{
  bits<11> imm11;

  let Opcode = op;

  let Inst{10-0}  = imm11;
}

//===----------------------------------------------------------------------===//
// Format RI instruction class in Mips : <|opcode|rx|immed|>
//===----------------------------------------------------------------------===//

class FRI16<bits<5> op, dag outs, dag ins, string asmstr,
            list<dag> pattern, InstrItinClass itin>:
            MipsInst16<outs, ins, asmstr, pattern, itin, FrmRI16>
{
  bits<3>  rx;
  bits<8>   imm8;

  let Opcode = op;

  let Inst{10-8} = rx;
  let Inst{7-0} = imm8;
}

//===----------------------------------------------------------------------===//
// Format RR instruction class in Mips : <|opcode|rx|ry|funct|>
//===----------------------------------------------------------------------===//

class FRR16<bits<5> op, bits<5> _funct, dag outs, dag ins, string asmstr,
            list<dag> pattern, InstrItinClass itin>:
            MipsInst16<outs, ins, asmstr, pattern, itin, FrmRR16>
{
  bits<3>  rx;
  bits<3>  ry;
  bits<5>  funct;

  let Opcode = op;
  let funct  = _funct;

  let Inst{10-8} = rx;
  let Inst{7-5} = ry;
  let Inst{4-0}   = funct;
}

//===----------------------------------------------------------------------===//
// Format RRI instruction class in Mips : <|opcode|rx|ry|immed|>
//===----------------------------------------------------------------------===//

class FRRI16<bits<5> op, dag outs, dag ins, string asmstr,
             list<dag> pattern, InstrItinClass itin>:
             MipsInst16<outs, ins, asmstr, pattern, itin, FrmRRI16>
{
  bits<3>  rx;
  bits<3>  ry;
  bits<5>  imm5;

  let Opcode = op;


  let Inst{10-8} = rx;
  let Inst{7-5} = ry;
  let Inst{4-0}   = imm5;
}

//===----------------------------------------------------------------------===//
// Format RRR instruction class in Mips : <|opcode|rx|ry|rz|f|>
//===----------------------------------------------------------------------===//

class FRRR16<bits<5> op, bits<2> _f, dag outs, dag ins, string asmstr,
             list<dag> pattern, InstrItinClass itin>:
             MipsInst16<outs, ins, asmstr, pattern, itin, FrmRRR16>
{
  bits<3>  rx;
  bits<3>  ry;
  bits<3>  rz;
  bits<2>  f;

  let Opcode = op;
  let f  = _f;

  let Inst{10-8} = rx;
  let Inst{7-5} = ry;
  let Inst{4-2} = rz;
  let Inst{1-0}   = f;
}

//===----------------------------------------------------------------------===//
// Format RRI-A instruction class in Mips : <|opcode|rx|ry|f|immed|>
//===----------------------------------------------------------------------===//

class FRRI_A16<bits<5> op, bits<1> _f, dag outs, dag ins, string asmstr,
               list<dag> pattern, InstrItinClass itin>:
               MipsInst16<outs, ins, asmstr, pattern, itin, FrmRRI_A16>
{
  bits<3>  rx;
  bits<3>  ry;
  bits<1>  f;
  bits<4>  imm4;

  let Opcode = op;
  let  f = _f;

  let Inst{10-8} = rx;
  let Inst{7-5} = ry;
  let Inst{4} = f;
  let Inst{3-0}   = imm4;
}

//===----------------------------------------------------------------------===//
// Format Shift instruction class in Mips : <|opcode|rx|ry|sa|f|>
//===----------------------------------------------------------------------===//

class FSHIFT16<bits<5> op, bits<2> _f, dag outs, dag ins, string asmstr,
               list<dag> pattern, InstrItinClass itin>:
               MipsInst16<outs, ins, asmstr, pattern, itin, FrmSHIFT16>
{
  bits<3>  rx;
  bits<3>  ry;
  bits<3>  sa;
  bits<2>  f;

  let Opcode = op;
  let f  = _f;

  let Inst{10-8} = rx;
  let Inst{7-5} = ry;
  let Inst{4-2} = sa;
  let Inst{1-0}   = f;
}

//===----------------------------------------------------------------------===//
// Format i8 instruction class in Mips : <|opcode|funct|immed>
//===----------------------------------------------------------------------===//

class FI816<bits<5> op, bits<3> _func, dag outs, dag ins, string asmstr,
            list<dag> pattern, InstrItinClass itin>:
            MipsInst16<outs, ins, asmstr, pattern, itin, FrmI8_TYPE16>
{
  bits<3>  func;
  bits<8>   immed8;
  
  let Opcode = op;
  let func  = _func;

  let Inst{10-8} = func;
  let Inst{7-0} = immed8;
}

//===----------------------------------------------------------------------===//
// Format i8_MOVR32 instruction class in Mips : <|opcode|func|ry|r32>
//===----------------------------------------------------------------------===//

class FI8_MOVR3216<bits<5> op, bits<3> _func, dag outs, dag ins, string asmstr,
                   list<dag> pattern, InstrItinClass itin>:
                   MipsInst16<outs, ins, asmstr, pattern, itin, FrmI8_MOVR3216>
{

  bits<3>  func;
  bits<4> ry;
  bits<4> r32;
  
  let Opcode = op;
  let func  = _func;

  let Inst{10-8} = func;
  let Inst{7-4} = ry;
  let Inst{3-0} = r32;
  
}



//===----------------------------------------------------------------------===//
// Format i8_MOV32R instruction class in Mips : <|opcode|func|ry|r32>
//===----------------------------------------------------------------------===//

class FI8_MOV32R16<bits<5> op, bits<3> _func, dag outs, dag ins, string asmstr,
                   list<dag> pattern, InstrItinClass itin>:
                   MipsInst16<outs, ins, asmstr, pattern, itin, FrmI8_MOV32R16>
{

  bits<3>  func;
  bits<5> r32;
  bits<3> rz;

  
  let Opcode = op;
  let func  = _func;

  let Inst{10-8} = func;
  let Inst{7-5} = r32{2-0}; 
  let Inst{4-3} = r32{4-3};
  let Inst{2-0} = rz;
  
}

//===----------------------------------------------------------------------===//
// Format i8_SVRS instruction class in Mips : 
//    <|opcode|svrs|s|ra|s0|s1|framesize>
//===----------------------------------------------------------------------===//

class FI8_SVRS16<bits<5> op, bits<3> _SVRS, dag outs, dag ins, string asmstr,
                 list<dag> pattern, InstrItinClass itin>:
                 MipsInst16<outs, ins, asmstr, pattern, itin, FrmI8_SVRS16>
{
  bits<3>  SVRS;
  bits<1> s;
  bits<1> ra;
  bits<1> s0;
  bits<1> s1;
  bits<4> framesize;
  
  let Opcode = op;
  let SVRS = _SVRS;

  let Inst{10-8} = SVRS;
  let Inst{7} = s;
  let Inst{6} = ra;
  let Inst{5} = s0;
  let Inst{4} = s1;
  let Inst{3-0} = framesize;
    
}

//===----------------------------------------------------------------------===//
// Format JAL instruction class in Mips16 : 
//    <|opcode|svrs|s|ra|s0|s1|framesize>
//===----------------------------------------------------------------------===//

class FJAL16<bits<5> op, bits<1> _X, dag outs, dag ins, string asmstr,
             list<dag> pattern, InstrItinClass itin>:
             MipsInst16_EXTEND<outs, ins, asmstr, pattern, itin, FrmJAL16>
{
  bits<1> X;
  bits<26> immed26;

  
  let Opcode = op;
  let X = _X;

  let Inst{26} = X;
  let Inst{25-21} = immed26{20-16};
  let Inst{20-16} = immed26{25-21};
  let Inst{15-0}  = immed26{15-0}; 
    
}


//===----------------------------------------------------------------------===//
// Format EXT-I instruction class in Mips16 : 
//     <|opcode|immed10:5|immed15:1|op|0|0|0|0|0|0|immed4:0>
//===----------------------------------------------------------------------===//

class FEXT_I16<bits<5> op, bits<5> _eop, dag outs, dag ins, string asmstr,
               list<dag> pattern, InstrItinClass itin>:
               MipsInst16_EXTEND<outs, ins, asmstr, pattern, itin, FrmEXT_I16>
{
  bits<16> immed16;
  bits<5> eop;
  
  let Opcode = op;
  let eop = _eop;

  let Inst{26-21} = immed16{10-5};
  let Inst{20-16} = immed16{15-11};
  let Inst{15-11} = eop;
  let Inst{10-5} = 0;
  let Inst{4-0} = immed16{4-0}; 
    
}






//===----------------------------------------------------------------------===//
// Format ASMACRO instruction class in Mips16 : 
//    <EXTEND|select|p4|p3|RRR|p2|p1|p0>
//===----------------------------------------------------------------------===//

class FASMACRO16<bits<5> op, dag outs, dag ins, string asmstr,
                 list<dag> pattern, InstrItinClass itin>:
                 MipsInst16_EXTEND<outs, ins, asmstr, pattern, itin, 
                                   FrmASMACRO16>
{
  bits<3> select;
  bits<3> p4;
  bits<5> p3;
  bits<5> RRR;
  bits<3> p2;
  bits<3> p1;
  bits<5> p0;
  
  let Opcode = op;

  let Inst{26-24} = select;
  let Inst{23-21} = p4;
  let Inst{20-16} = p3;
  let Inst{15-11} = RRR;
  let Inst{10-8} = p2;
  let Inst{7-5} = p1;
  let Inst{4-0} = p0; 
    
}


//===----------------------------------------------------------------------===//
// Format EXT-RI instruction class in Mips16 : 
//    <|opcode|immed10:5|immed15:11|op|rx|0|0|0|immed4:0>
//===----------------------------------------------------------------------===//

class FEXT_RI16<bits<5> op, bits<5> _eop, dag outs, dag ins, string asmstr,
                list<dag> pattern, InstrItinClass itin>:
                MipsInst16_EXTEND<outs, ins, asmstr, pattern, itin, 
                                  FrmEXT_RI16>
{
  bits<16> immed16;
  bits<5> eop;
  bits<3> rx;
  
  let Opcode = op;
  let eop = _eop;

  let Inst{26-21} = immed16{10-5};
  let Inst{20-16} = immed16{15-11};
  let Inst{15-11} = eop;
  let Inst{10-8} = rx;
  let Inst{7-5} = 0;
  let Inst{4-0} = immed16{4-0}; 
    
}

//===----------------------------------------------------------------------===//
// Format EXT-RRI instruction class in Mips16 :
//     <|opcode|immed10:5|immed15:11|op|rx|ry|immed4:0>
//===----------------------------------------------------------------------===//

class FEXT_RRI16<bits<5> op, bits<5> _eop, dag outs, dag ins, string asmstr,
                 list<dag> pattern, InstrItinClass itin>:
                 MipsInst16_EXTEND<outs, ins, asmstr, pattern, itin, 
                                   FrmEXT_RRI16>
{
  bits<16> immed16;
  bits<5> eop;
  bits<3> rx;
  bits<3> ry;
  
  let Opcode = op;
  let eop = _eop;

  let Inst{26-21} = immed16{10-5};
  let Inst{20-16} = immed16{15-11};
  let Inst{15-11} = eop;
  let Inst{10-8} = rx;
  let Inst{7-5} = ry;
  let Inst{4-0} = immed16{4-0}; 
    
}

//===----------------------------------------------------------------------===//
// Format EXT-RRI-A instruction class in Mips16 : 
//    <|opcode|immed10:4|immed14:11|RRI-A|rx|ry|f|immed3:0>
//===----------------------------------------------------------------------===//

class FEXT_RRI_A16<bits<5> op, bits<1> _f, dag outs, dag ins, string asmstr,
                   list<dag> pattern, InstrItinClass itin>:
                   MipsInst16_EXTEND<outs, ins, asmstr, pattern, itin, 
                                     FrmEXT_RRI_A16>
{
  bits<15> immed15;
  bits<5> RRI_A;
  bits<3> rx;
  bits<3> ry;
  bits<1> f;
  
  let Opcode = op;
  let f = _f;

  let Inst{26-20} = immed15{10-4};
  let Inst{19-16} = immed15{14-11};
  let Inst{15-11} = RRI_A;
  let Inst{10-8} = rx;
  let Inst{7-5} = ry;
  let Inst{4} = f;
  let Inst{3-0} = immed15{3-0}; 
    
}

//===----------------------------------------------------------------------===//
// Format EXT-SHIFT instruction class in Mips16 : 
//    <|opcode|sa 4:0|s5|0|SHIFT|rx|ry|0|f>
//===----------------------------------------------------------------------===//

class FEXT_SHIFT16<bits<5> op, bits<2> _f, dag outs, dag ins, string asmstr,
                   list<dag> pattern, InstrItinClass itin>:
                   MipsInst16_EXTEND<outs, ins, asmstr, pattern, itin, 
                                     FrmEXT_SHIFT16>
{
  bits<6> sa6;
  bits<5> shift;
  bits<3> rx;
  bits<3> ry;
  bits<2> f;
  
  let Opcode = op;
  let f = _f;

  let Inst{26-22} = sa6{4-0};
  let Inst{21} = sa6{5};
  let Inst{20-16} = 0;
  let Inst{15-11} = shift;
  let Inst{10-8} = rx;
  let Inst{7-5} = ry;
  let Inst{4-2} = 0;
  let Inst{1-0} = f; 
    
}

//===----------------------------------------------------------------------===//
// Format EXT-I8 instruction class in Mips16 : 
//    <|opcode|immed10:5|immed15:11|I8|funct|0|immed4:0>
//===----------------------------------------------------------------------===//

class FEXT_I816<bits<5> op, bits<3> _funct, dag outs, dag ins, string asmstr,
                list<dag> pattern, InstrItinClass itin>:
                MipsInst16_EXTEND<outs, ins, asmstr, pattern, itin, 
                                  FrmEXT_I816>
{
  bits<16> immed16;
  bits<5> I8;
  bits<3> funct;
  
  let Opcode = op;
  let funct = _funct;

  let Inst{26-21} = immed16{10-5};
  let Inst{20-16} = immed16{15-11};
  let Inst{15-11} = I8;
  let Inst{10-8} = funct;
  let Inst{7-5} = 0;
  let Inst{4-0} = immed16{4-0};
    
}

//===----------------------------------------------------------------------===//
// Format EXT-I8_SVRS instruction class in Mips16 : 
//    <|opcode|xsregs|framesize7:4|aregs|I8|SVRS|s|ra|s0|s1|framesize3:0>
//===----------------------------------------------------------------------===//

class FEXT_I8_SVRS16<bits<5> op, dag outs, dag ins, string asmstr,
                     list<dag> pattern, InstrItinClass itin>:
                     MipsInst16_EXTEND<outs, ins, asmstr, pattern, itin, 
                                       FrmI8_SVRS16>
{
  bits<3> xsregs;
  bits<8> framesize;
  bits<3> aregs;
  bits<5> I8;
  bits<3> SVRS;
  bits<1> s;
  bits<1> ra;
  bits<1> s0;
  bits<1> s1;
  
  let Opcode = op;

  let Inst{26-24} = xsregs;
  let Inst{23-20} = framesize{7-4};
  let Inst{19} = 0;
  let Inst{18-16} = aregs;
  let Inst{15-11} = I8;
  let Inst{10-8} = SVRS;
  let Inst{7} = s;
  let Inst{6} = ra;
  let Inst{5} = s0;
  let Inst{4} = s1;
  let Inst{3-0} = framesize{3-0};
  
    
}



