module imem (
    input logic [31:0] a, // address coming from PC
    output logic [31:0] rd // 32 bit instruction sent to fetch stage
);
    logic [31:0] RAM[63:0];

    initial begin
        
        // --- MILESTONE 1: START ---
        // Write 0x1111 to Address 200 (0xC8)
        RAM[0]=32'h11100293; // addi x5, x0, 0x111
        RAM[1]=32'h0c502823; // sw x5, 200(x0)

        // --- MILESTONE 2: TESTING BRANCH ---
        // x1=10, x2=20. BNE should jump to Milestone 3.
        RAM[2]=32'h00a00093; // addi x1, x0, 10
        RAM[3]=32'h01400113; // addi x2, x0, 20
        // bne x1, x2, +12 (Jump to Index 7)
        RAM[4]=32'h00209663; 

        // TRAP (Index 5) - If we hit this, Branch Failed.
        RAM[5]=32'hbad00293; // addi x5, x0, 0xBAD
        RAM[6]=32'h0c502a23; // sw x5, 204(x0)

        // --- MILESTONE 3: BRANCH SUCCESS ---
        // Index 7. Write 0x222 to Address 204.
        RAM[7]=32'h22200293; // addi x5, x0, 0x222
        RAM[8]=32'h0c502a23; // sw x5, 204(x0)

        // --- MILESTONE 4: TESTING JAL/JALR ---
        // Call Function at Index 14.
        RAM[9]=32'h014000ef; 

        // RETURN POINT (Index 10)
        RAM[10]=32'h44400293; // addi x5, x0, 0x444
        RAM[11]=32'h0d402423; // sw x5, 212(x0)
        // Jump to End (Index 17)
        RAM[12]=32'h0140006f; 

        // --- FUNCTION BODY (Index 14) ---
        RAM[14]=32'h33300293; // addi x5, x0, 0x333
        RAM[15]=32'h0d002023; // sw x5, 208(x0)
        // Return
        RAM[16]=32'h00008067; // jalr x0, x1, 0

        // --- MILESTONE 5: MEMORY WIDTH (Index 17) ---
        RAM[17]=32'hffc00293; // addi x5, x0, -4
        // Write FE to 100
        RAM[18]=32'h06500223; // sb x5, 100(x0)
        // Write FE to 101
        RAM[19]=32'h065002a3; // sb x5, 101(x0)
        // Write FFFE to 102
        RAM[20]=32'h06501323; // sh x5, 102(x0)
        // Load Word
        RAM[21]=32'h06402483; // lw x9, 100(x0)

    end

    assign rd=RAM[a[31:2]];
    
    
// note- Always remember one thing, NOP is not a true instruction but a pseudo instruction. We internally translate it to:
//                       ADDI x0, x0, 0 (Add the value 0 to Register x0, and store the result in Register x0).
//       Since x0 is hardwired to zero, this instruction does absolutely nothing and changes no state, which is exactly what a NOP should do.
//       instruction: 0x00000013, format: I type
//       Decoding this: opcode= 0010011 => ADDI
//                      rd= 00000 => x0
//                      rs1= 00000 => x0
//                      immediate= 000000000000 = 0
//       thus we implemented "Do nothing" with 0x00000013
endmodule