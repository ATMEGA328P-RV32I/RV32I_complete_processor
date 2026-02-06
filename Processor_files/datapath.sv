module datapath (
    input logic clk,reset,
    input logic [2:0] immsrcD, // 3 bit selector from controller tells extend unit the format(I,S,B,J,U) to use
    input logic [1:0] resultsrcW, // 2 bit selector for writeback mux(00=ALU,01=Mem,10=PC+4)
    input logic alusrcAE,alusrcBE, // A: choose b/w RegA and PC, B: choose b/w RegB and Immediate
    input logic [3:0] alucontrolE, // 4 bit opcode for ALU
    input logic regwriteW, // write enable for reg file at the end
    input logic pcsrcE,jumpE,jalrE, // Flags: pcsrcE- if 1, the branch condition(BEQ/BNE) is met, hence take the branch
                                    // jumpE- unconditional jump(JAL), jalrE- register jump(JALR)
    input logic stallF,stallD,flushD,flushE, // stallF freezes PC, stallD freezes decode stage(for load use hazards)
                                             // flushD clears decode reg and flushE clears execute register
    input logic [1:0] forwardAE,forwardBE, // forwarding controls
    output logic [6:0] opD, // 7 bit opcode sent to controller
    output logic [2:0] funct3D, // function codes
    output logic funct7b5D, // function codes
    output logic zeroE,ltE,ltuE, // ALU flags sent to controller
    output logic [4:0] rs1D,rs2D,rs1E,rs2E,rdE,rdM,rdW, // 5 bit source register addresses sent to hazard unit
    input logic [31:0] instrF,readdataM, // instrF- 32 bit raw instruction fetched from imem, readdataM- 32 bit data read from dmem
    output logic [31:0] pcF,aluresultM,writedataM // pcF- 32 bit current PC address sent to imem to fetch instruction
                                                  // aluresultM- 32 bit calculated address sent to dmem
                                                  // writedataM- 32 bit data to write to dmem 
);

    logic [31:0] pcnextF,pcplus4F,pcplus4D,pcplus4E,pcplus4M,pcplus4W; // next pc value,   pc <- pc+4 
    logic [31:0] instrD; // 32 bit instructon in decode stage
    logic [31:0] rd1D,rd2D,rd1E,rd2E; // data read from reg fileafter passing register numbers rs1 and rs2
    logic [31:0] immextD,immextE; // extended immediate from decode stage to execute stage
    logic [31:0] srcAE_raw,srcBE_raw,srcAE,srcBE,writedataE; // srcAE,BE- final inputs for ALU(choosing pc vs reg and imm vs reg), writedataE- data to be written to memory
    logic [31:0] aluresultE,aluresultW; // result of alu operation
    logic [31:0] readdataW,resultW; // resultW- data to be written to dmem 
    logic [4:0] rdD; // destination register address
    logic [31:0] pctargetE,branchtargetE; // target for branch
    logic [31:0] pcD,pcE; // pc of instructions in decode and execute stage

    // --- FETCH STAGE ---
    mux2 #(32) pcmux(pcplus4F,pctargetE,pcsrcE,pcnextF); // choose for pcnextF from pc+4 and pctarget(i.e. branch) based on pcsrcE
    flopenrc #(32) pcreg(clk,reset,~stallF,1'b0,pcnextF,pcF);
    adder pcadd4(pcF,32'd4,pcplus4F);
    
    

    // --- DECODE STAGE ---
    flopenrc #(32) fdreg(clk,reset,~stallD,flushD,instrF,instrD); // pipeline register for instruction
    flopenrc #(32) fdreg2(clk,reset,~stallD,flushD,pcplus4F,pcplus4D); // pipeline register for pc+4
    flopenrc #(32) fdreg3(clk,reset,~stallD,flushD,pcF,pcD); // Propagate pcF -> pcD
    
    // splitting instruction into useful chunks
    assign opD=instrD[6:0]; // opcode
    assign funct3D=instrD[14:12]; // funct3
    assign funct7b5D=instrD[30]; // funct7 bit 5 to distinguish add and sub
    assign rdD=instrD[11:7]; 
    assign rs1D=instrD[19:15];
    assign rs2D=instrD[24:20];
    // note- RISC V is designed so that the rs1,rs2 and rd are in exact same place for every instruction format.
    //       funct3,funct7 and immediates fill the empty gaps between these. this creates wiring inside the chip simpler.
    //       Also, we cant store unique opcodes for every instruction as main decoder will turn very large.
    //       Instead we create a faster multi-step decision tree. we group them into sets which the main decoder looks at.
    //       Then funct3 and funct7 further distinguish the instruction.

    regfile rf(clk,regwriteW,rs1D,rs2D,rdW,resultW,rd1D,rd2D); // write to reg file
    extend ext(instrD[31:7],immsrcD,immextD); // extend immediate



    // --- EXECUTE STAGE ---
    flopenrc #(32) dereg1(clk,reset,1'b1,flushE,rd1D,rd1E); // data A 
    flopenrc #(32) dereg2(clk,reset,1'b1,flushE,rd2D,rd2E); // data B
    flopenrc #(32) dereg3(clk,reset,1'b1,flushE,pcplus4D,pcplus4E); // pc+4
    flopenrc #(32) dereg4(clk,reset,1'b1,flushE,immextD,immextE); // extended immediate
    flopenrc #(32) dereg5(clk,reset,1'b1,flushE,pcD,pcE); // propagate pcD -> pcE
    // for hazard unit
    flopenrc #(5) dereg6(clk,reset,1'b1,flushE,rs1D,rs1E);
    flopenrc #(5) dereg7(clk,reset,1'b1,flushE,rs2D,rs2E);
    flopenrc #(5) dereg8(clk,reset,1'b1,flushE,rdD,rdE);

    // forwarding Muxes for RAW dependencies
    mux3 #(32) fa_mux(rd1E,resultW,aluresultM,forwardAE,srcAE_raw);
    mux3 #(32) fb_mux(rd2E,resultW,aluresultM,forwardBE,writedataE);
    
    mux2 #(32) srcamux(srcAE_raw,pcE,alusrcAE,srcAE); // source selection (AUIPC/LUI(i.e. PC) vs registers(like add,sub))
    mux2 #(32) srcbmux(writedataE,immextE,alusrcBE,srcBE); // for ADDI/LW(use immediate) vs add/sub(use registers)

    alu alu(srcAE,srcBE,alucontrolE,aluresultE,zeroE,ltE,ltuE);

    adder branchadd(pcE,immextE,branchtargetE); // calculate branchtarget
    
    mux2 #(32) targetmux(branchtargetE,aluresultE,jalrE,pctargetE); // for JALR. If jalrE is 1, jump to ALU result(reg+imm), else jump to branchtarget(pc+imm)



    // --- MEMORY STAGE ---
    // using flopr instead of flopenrc as no need to flush here, so reduce space on chip
    flopr #(32) emreg1(clk,reset,aluresultE,aluresultM); // aluresult -> address for memory
    flopr #(32) emreg2(clk,reset,writedataE,writedataM); // writedata -> data for memory
    flopr #(5) emreg3(clk,reset,rdE,rdM); // destination register
    flopr #(32) emreg4(clk,reset,pcplus4E,pcplus4M); // pc+4



    // --- WRITEBACK STAGE ---
    flopr #(32) mwreg1(clk,reset,aluresultM,aluresultW);
    flopr #(32) mwreg2(clk,reset,readdataM,readdataW);
    flopr #(5) mwreg3(clk,reset,rdM,rdW);
    flopr #(32) mwreg4(clk,reset,pcplus4M,pcplus4W);

    mux3 #(32) resultmux(aluresultW,readdataW,pcplus4W,resultsrcW,resultW); // final writeback mux
    
    // note- we have propagated pc all the way down to writeback as branching instructions(like BEQ,JAL) use pc relative offset for next instruction, 
    //       so using a global pc will create all sorts of problems and including complex logic instead of passing the pc down will result in a high time debugging!
    //       Also, if the instruction is a jump instruction(like JAL) the pc+4 value goes to the final writeback mux and is selected for writing into the reg file using resultsrcW(10 for writing pc+4)
endmodule