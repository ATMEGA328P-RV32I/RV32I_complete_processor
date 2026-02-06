// --- ALU ---
module alu (
    input logic [31:0] srca,srcb,
    input logic [3:0] alucontrol,
    output logic [31:0] aluresult,
    output logic zero,lt,ltu // if lu operation resulted in a zero or less than or less than(unsigned)
);
    always_comb // this ensures the block executes once at time 0 unlike always @(*) which executes only when inputs change 
                // also explicitly telling the simulator that pure combinational logic is intended
    begin
        case (alucontrol)
            4'b0000: aluresult=srca+srcb; // ADD
            4'b0001: aluresult=srca-srcb; // SUB
            4'b0010: aluresult=srca&srcb; // AND
            4'b0011: aluresult=srca|srcb; // OR
            4'b0100: aluresult=srca^srcb; // XOR
            4'b0101: aluresult=($signed(srca)<$signed(srcb))?32'd1:32'd0; // SLT
            4'b0110: aluresult=srca<<srcb[4:0]; // SLL
            4'b0111: aluresult=srca>>srcb[4:0]; // SRL
            4'b1000: aluresult=$signed(srca)>>>srcb[4:0]; // SRA
            4'b1001: aluresult=(srca<srcb)?32'd1:32'd0; // SLTU
            default: aluresult=32'bx;
        endcase
    end

    assign zero=(aluresult==0);
    assign lt=($signed(srca)<$signed(srcb));
    assign ltu=(srca<srcb);
endmodule

// --- REGISTER FILE ---
module regfile (
    input logic clk,
    input logic we3, // write enable
    input logic [4:0] a1,a2,a3, // a1 and a2 are read registers, a3 is for write to register 
    input logic [31:0] wd3, // data to be written to a3 register
    output logic [31:0] rd1,rd2 // data read from a1 and a2 registers
);
    logic [31:0] rf[31:0];

    // 1. Initialize to Zero
    initial begin
        int i;
        for (i=0; i<32; i=i+1) rf[i]=0;
    end

    // 2. Write Logic
    always_ff @(posedge clk)
        if (we3&&a3!=0) rf[a3]<=wd3;

    // 3. Read Logic
    always_comb begin
        // Port 1
        if (a1==0) rd1=0; // this is highest priority as even if one tries to write to register x0
                          // it must return 0 while reading 
        else if (a1==a3&&we3) rd1=wd3; // INTERNAL FORWARDING if one writes to register at clock edge and other reads at the same clock edge, the value written must be returned, and not the previous "wrong" value
        else rd1=rf[a1];

        // Port 2
        if (a2==0) rd2=0;
        else if (a2==a3&&we3) rd2=wd3; // INTERNAL FORWARDING
        else rd2=rf[a2];
        
        // majority of instructions are of the form <inst> <rd>, <rs1>, <rs2>. so we need two read ports to increase speed of access here and one write port is sufficient
    end
endmodule

// --- EXTEND UNIT ---
module extend (
    input logic [31:7] instr,
    input logic [2:0] immsrc,
    output logic [31:0] immext
);
    always_comb
        case(immsrc)
            // I-type 
            3'b000: immext={{20{instr[31]}},instr[31:20]};
            // S-type 
            3'b001: immext={{20{instr[31]}},instr[31:25],instr[11:7]};
            // B-type 
            3'b010: immext={{20{instr[31]}},instr[7],instr[30:25],instr[11:8],1'b0};
            // J-type 
            3'b011: immext={{12{instr[31]}},instr[19:12],instr[20],instr[30:21],1'b0};
            // U-type
            3'b100: immext={instr[31:12],12'b0}; 
            default: immext=32'bx;
        endcase
endmodule