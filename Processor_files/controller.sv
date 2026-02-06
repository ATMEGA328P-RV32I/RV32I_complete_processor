module controller (
    input logic clk,reset,
    input logic [6:0] op, // 7 bit opcode
    input logic [2:0] funct3,
    input logic funct7b5,
    input logic zeroE,ltE,ltuE, // flags from ALU
    
    output logic [2:0] immsrcD, // sent to extend unit in decode stage to choose immediate format(I,S,B,J,U)
    output logic [1:0] resultsrcW, // selector for final writebackk mux(00=ALU,01=mem,10=pc+4)
    output logic memwriteM, // write enable for dmem(1=write,0=read)
    output logic alusrcAE, // selects input A of ALU for AUIPC,JAL(0=reg,1=pc)
    output logic alusrcBE, // selects ALU input B for ADDI,LW,SW(0=reg,1=imm)
    output logic regwriteW,regwriteM, // regwriteW- write enable for reg file, regwriteM- passed to hazard unit 
    output logic [3:0] alucontrolE, // opcode for ALU
    output logic pcsrcE, // branch taken flag. If 1, PC mux switches to target address
    output logic resultsrcE0, // lsb of resultsrc, used by hazard unit to detect a load instruction 
    output logic jumpE,jalrE, // jumpE- indicates unconditional jump(JAL), jalrE- indicating register jump(JALR)
    output logic [2:0] funct3M // to dmem to control width(byte,half,word)      
);

    logic [1:0] aluop; // from main decoder telling category of math(00=add,01=sub,10=function dependent)
    logic branchD,jumpD,jalrD; // branchD indicates branch instruction in decode stage, others indicate jump instructions in Decode
    logic regwriteD,memwriteD,alusrcAD,alusrcBD; // regwriteD- register write signal in decode stage, memwriteD- memory write signal in decode stage, others are ALU source selectors in decode stage
    logic [1:0] resultsrcD; // result source selector in decode stage
    logic [3:0] alucontrolD; // decoded ALU operation in decode 
    logic regwriteE,memwriteE,branchE; // decode->execute
    logic [1:0] resultsrcE,resultsrcM; // decode->execute
    logic [2:0] funct3E; // decode->execute

    // --- Main Decoder ---
    logic [13:0] controls; // holds all control signals made by the decoder
    always_comb 
    begin
        case(op)
            7'b0000011: controls=14'b1_01_0_0_0_00_0_1_000_0; // lw
            7'b0100011: controls=14'b0_00_1_0_0_00_0_1_001_0; // sw
            7'b0110011: controls=14'b1_00_0_0_0_10_0_0_000_0; // R-type
            7'b1100011: controls=14'b0_00_0_0_1_01_0_0_010_0; // beq
            7'b0010011: controls=14'b1_00_0_0_0_10_0_1_000_0; // I-type ALU
            7'b1101111: controls=14'b1_10_0_1_0_00_0_1_011_0; // jal
            7'b1100111: controls=14'b1_10_0_1_0_00_0_1_000_1; // jalr
            7'b0110111: controls=14'b1_00_0_0_0_11_1_1_100_0; // lui 
            7'b0010111: controls=14'b1_00_0_0_0_00_1_1_100_0; // auipc
            default: controls=14'b0_00_0_0_0_00_0_0_000_0;
        endcase
    end
    assign {regwriteD,resultsrcD,memwriteD,jumpD,branchD,aluop,alusrcAD,alusrcBD,immsrcD,jalrD}=controls; // splitting controls bus to smaller pieces

    // --- ALU Decoder ---
    logic [3:0] aluctrl; // for claculated ALU control cofe
    always_comb begin
        case(aluop)
            2'b00: aluctrl=4'b0000; // ADD 
            2'b01: aluctrl=4'b0001; // SUB 
            2'b10: begin            // R/I-type
                case(funct3)
                    3'b000: if (op[5]&funct7b5) aluctrl=4'b0001; // sub
                            else aluctrl=4'b0000; // add
                    3'b001: aluctrl=4'b0110; // sll
                    3'b010: aluctrl=4'b0101; // slt
                    3'b011: aluctrl=4'b0100; // sltu
                    3'b100: aluctrl=4'b0100; // xor
                    3'b101: if (funct7b5) aluctrl=4'b1000; // sra 
                            else aluctrl=4'b0111; // srl 
                    3'b110: aluctrl=4'b0011; // or
                    3'b111: aluctrl=4'b0010; // and
                    default: aluctrl=4'bxxxx;
                endcase
            end
            2'b11: aluctrl=4'b0000; // LUI (the instruction is just a directive, an add operation in disguise)
            default: aluctrl=4'bxxxx;
        endcase
    end
    assign alucontrolD=aluctrl; // connect both the wires

    // --- Pipeline Registers ---
    // these just move control signals down the pilepline at every posedge clock
    flopenrc #(16) regE(
        clk,reset,1'b1,flushE,
        {regwriteD,resultsrcD,memwriteD,branchD,jumpD,jalrD,alucontrolD,alusrcAD,alusrcBD,funct3},
        {regwriteE,resultsrcE,memwriteE,branchE,jumpE,jalrE,alucontrolE,alusrcAE,alusrcBE,funct3E}
    );
    
    flopr #(7) regM(clk,reset, 
        {regwriteE,resultsrcE,memwriteE,funct3E}, 
        {regwriteM,resultsrcM,memwriteM,funct3M}
    );
    
    flopr #(3) regW(clk,reset,{regwriteM,resultsrcM},{regwriteW,resultsrcW});

    // --- Branch Logic ---
    logic take_branch; // flag which tells if branch should be taken
    always_comb begin
        case(funct3E)
            3'b000: take_branch=zeroE; // BEQ 
            3'b001: take_branch=~zeroE; // BNE
            3'b100: take_branch=ltE; // BLT
            3'b101: take_branch=~ltE;
            3'b110: take_branch=ltuE; // BLTU
            3'b111: take_branch=~ltuE;
            default: take_branch=1'b0;
        endcase
    end

    assign pcsrcE=(branchE&take_branch)|jumpE; // switch the PC if it is a branch instruction(branchE) AND the condition is met(take_branch) OR it is unconditional jump(jumpE)
    assign resultsrcE0=resultsrcE[0]; // extracts LSB of resultsrcE for hazard unit(indicating load operation)

endmodule