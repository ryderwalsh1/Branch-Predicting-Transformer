/*
 * Copyright (C) 2004-2021 Intel Corporation.
 * SPDX-License-Identifier: MIT
 */

#include <iostream>
#include <fstream>
#include "pin.H"
using std::cerr;
using std::endl;
using std::ios;
using std::ofstream;
using std::string;
using std::hex;

ofstream InsOut;
ofstream RegOut;

// The running count of instructions is kept here
// make it static to help the compiler optimize docount
static UINT64 icount = 0;

// This function is called before every instruction is executed
VOID gatherinstinfo(ADDRINT pc, string sIns, INS ins, BOOL isBranch, BOOL brTaken, CONTEXT* context) { 
    icount++; 
    // Get immediate 
    string immediateOp = "";
    UINT32 numOperands = INS_OperandCount(ins);
    for (UINT32 i = 0; i < numOperands; ++i) {
        if (INS_OperandIsImmediate(ins, i)) {
            ADDRINT imm = INS_OperandImmediate(ins, i);
            immediateOp += hexstr(imm) + " ";
        }
    }
    if (immediateOp == "") immediateOp = "{no imm}";

    // Get source registers
    string srcRegs = "";
    UINT32 srcCount = INS_MaxNumRRegs(ins);
    for (UINT32 i = 0; i < srcCount; ++i) {
        REG srcReg = INS_RegR(ins, i);
        if (REG_valid(srcReg)) {
            srcRegs += REG_StringShort(srcReg) + " ";
        }
    }
    if (srcRegs == "") srcRegs = "{no source}";

    // Get dest registers
    string destRegs = "";
    UINT32 destCount = INS_MaxNumWRegs(ins);
    for (UINT32 i = 0; i < destCount; ++i) {
        REG destReg = INS_RegW(ins, i);
        if (REG_valid(destReg)) {
            destRegs += REG_StringShort(destReg) + " ";
        }
    }
    if (destRegs == "") destRegs = "{no dest}";

    // Output instruction info to file
    InsOut << hex << pc << " | " << sIns << " | " << isBranch << " " << brTaken << " | ";
    // Dump imm, source, and dest registers
    InsOut << immediateOp << " | " << srcRegs << " | " << destRegs << endl;
    // Dump register file
    string rDump = "";
    for (int reg = REG_GR_BASE; reg <= REG_GR_LAST; ++reg) {
        if (REG_valid((REG)reg)) {
            ADDRINT value = PIN_GetContextReg(context, (REG)reg);
            rDump += hexstr(value) + " ";
        }
    }
    RegOut << rDump << endl;
}




// Pin calls this function every time a new instruction is encountered
VOID Instruction(INS ins, VOID* v)
{
    // Insert a call to docount before every instruction, no arguments are passed
    INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR)gatherinstinfo, 
    IARG_INST_PTR, 
    IARG_PTR, new string(INS_Disassemble(ins)),
    IARG_PTR, ins,
    IARG_BOOL, INS_IsBranch(ins), 
    IARG_BRANCH_TAKEN,
    IARG_CONST_CONTEXT,
    IARG_END);

}

KNOB< string > KnobOutputFile1(KNOB_MODE_WRITEONCE, "pintool", "o1", "branchtraceIns_sort.out", "specify first output file name");
KNOB< string > KnobOutputFile2(KNOB_MODE_WRITEONCE, "pintool", "o2", "branchtraceReg_sort.out", "specify second output file name");

// This function is called when the application exits
VOID Fini(INT32 code, VOID* v)
{
    // Write to a file since cout and cerr maybe closed by the application
    InsOut.setf(ios::showbase);
    RegOut.setf(ios::showbase);
    InsOut.close();
    RegOut.close();
}

/* ===================================================================== */
/* Print Help Message                                                    */
/* ===================================================================== */

INT32 Usage()
{
    cerr << "This tool counts the number of dynamic instructions executed" << endl;
    cerr << endl << KNOB_BASE::StringKnobSummary() << endl;
    return -1;
}

/* ===================================================================== */
/* Main                                                                  */
/* ===================================================================== */
/*   argc, argv are the entire command line: pin -t <toolname> -- ...    */
/* ===================================================================== */

int main(int argc, char* argv[])
{
    // Initialize pin
    if (PIN_Init(argc, argv)) return Usage();

    InsOut.open(KnobOutputFile1.Value().c_str());
    RegOut.open(KnobOutputFile2.Value().c_str());

    // Register Instruction to be called to instrument instructions
    INS_AddInstrumentFunction(Instruction, 0);

    // Register Fini to be called when the application exits
    PIN_AddFiniFunction(Fini, 0);

    // Start the program, never returns
    PIN_StartProgram();

    return 0;
}
