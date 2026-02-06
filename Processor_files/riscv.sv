module riscv (
    input logic clk,reset,
    output logic [31:0] pcF, // pc for fetching instructions from imem
    input logic [31:0] instrF, // instruction from imem
    output logic [31:0] aluresultM,writedataM, // dmem: aluresult- address to read/write, writedata- data to write
    input logic [31:0] readdataM, // data read from dmem 
    output logic memwriteM, // write enable for dmem
    output logic [2:0] funct3M // width (000=byte, 001=half, 010=word)
);
    logic [6:0] opD; // opcode from datapath to controller
    logic [2:0] funct3D; // funct3 from datapath to controller
    logic funct7b5D; // 5th bit of funct7 from datapath to controller
    logic [2:0] immsrcD; // type of instruction sent to datapath(I,S,B,J,U)
    logic [1:0] resultsrcW; // goes to datapath to tell it what to writeback(pc+4,mem or ALU)
    logic alusrcAE,alusrcBE,regwriteW,regwriteM,zeroE,ltE,ltuE,pcsrcE,jumpE,jalrE; // tells whether to use the A and B operands(see controls of controller.sv), write enables for reg file, alu flags from datapath to controller, jump instruction indicators 
    logic [3:0] alucontrolE; // opcode for alu
    logic [4:0] rs1D,rs2D,rs1E,rs2E,rdE,rdM,rdW; // to track which registers are being read/written in every stage
    logic stallF,stallD,flushD,flushE; // hazard signals from hazard unit to datapath/controller
    logic [1:0] forwardAE,forwardBE; // forwarding selectors
    logic resultsrcE0; // LSB of resultsrc, sent to hazard unit to detect a lw instruction(see controls of controller.sv)

    // --- CONTROLLER INSTANCE ---
    controller c(
        .clk(clk),.reset(reset),
        .op(opD),.funct3(funct3D),.funct7b5(funct7b5D), // decoded instruction bits from datapath
        .zeroE(zeroE),.ltE(ltE),.ltuE(ltuE), // ALU flags
        .immsrcD(immsrcD), // immediate format(I,S,B,J,U)
        .resultsrcW(resultsrcW), // what to writeback to dmem
        .memwriteM(memwriteM), // write enable for dmem
        .alusrcAE(alusrcAE),.alusrcBE(alusrcBE), // tells "use these alu operands"
        .regwriteW(regwriteW),.regwriteM(regwriteM), // write to reg file
        .alucontrolE(alucontrolE), // opcode for alu
        .pcsrcE(pcsrcE), // update pc to branch target
        .resultsrcE0(resultsrcE0), // to detect load lw for load use hazards
        .jumpE(jumpE),.jalrE(jalrE), // perform jump
        .funct3M(funct3M) // width of data to write
    );

    // --- DATAPATH INSTANCE ---
    datapath dp(
        .clk(clk),.reset(reset),
        
        // Inputs: control signals from controller
        .immsrcD(immsrcD),
        .resultsrcW(resultsrcW), 
        .alusrcAE(alusrcAE),.alusrcBE(alusrcBE), 
        .alucontrolE(alucontrolE), 
        .regwriteW(regwriteW),
        .pcsrcE(pcsrcE),.jumpE(jumpE),.jalrE(jalrE), 
       
        // Inputs: hazard signals from hazard unit
        .stallF(stallF),.stallD(stallD),.flushD(flushD),.flushE(flushE),
        .forwardAE(forwardAE),.forwardBE(forwardBE),
        
        // Outputs: information sent to controller
        .opD(opD),.funct3D(funct3D),.funct7b5D(funct7b5D),
        .zeroE(zeroE),.ltE(ltE),.ltuE(ltuE),
        
        // Outputs: register addresses sent to hazard unit for tracking
        .rs1D(rs1D),.rs2D(rs2D),.rs1E(rs1E),.rs2E(rs2E),.rdE(rdE),.rdM(rdM),.rdW(rdW),
        
        // Inputs/outputs: memory intrrface to outside world
        .instrF(instrF),.readdataM(readdataM), 
        .pcF(pcF),.aluresultM(aluresultM),.writedataM(writedataM)
    );

    // --- HAZARD UNIT INSTANCE ---
    hazard h(
        
        // inputs from datapath
        .rs1D(rs1D),.rs2D(rs2D),.rs1E(rs1E),.rs2E(rs2E), 
        .rdE(rdE),.rdM(rdM),.rdW(rdW),
        
        //inputs from controller
        .regwriteM(regwriteM),.regwriteW(regwriteW), 
        .resultsrcE0(resultsrcE0),
        .pcsrcE(pcsrcE), // checks if branch is taken
        
        // output commands to datapath
        .forwardAE(forwardAE),.forwardBE(forwardBE), 
        .stallF(stallF),.stallD(stallD),.flushD(flushD),.flushE(flushE)
    );
    
    
    
// note - .x(y) is called named port mapping. It means connect wire y to port .x
//        Imagine this file as a motherboard in which we have 3 ICs ICdatapath, ICcontroller and IChazard and hundreds of wires connecting them
endmodule