module dmem (
    input logic clk,we, // write enable
    input logic [31:0] a,wd, // a: 32 bit address input, wd: 32 bit write data input
    input logic [2:0] funct3, // tells how much data to access(byte,half or word)
    output logic [31:0] rd // 32 bit data output
);
    // declared RAM as 4 separate byte banks with each capable of storing upto 64 bytes of data
    logic [7:0] RAM0[63:0]; // Byte 0
    logic [7:0] RAM1[63:0]; // Byte 1
    logic [7:0] RAM2[63:0]; // Byte 2
    logic [7:0] RAM3[63:0]; // Byte 3

    logic [5:0] idx; // Word index(we need 6 bits to define 64 values)
    assign idx=a[7:2]; // change idx whenever a changes(a[1:0] is simply an offset of 4 bytes(1 word) so not considered)
 
    // --- READ LOGIC ---
    logic [31:0] word_read; // temporarily holds a 32 bit word
    assign word_read={RAM3[idx],RAM2[idx],RAM1[idx],RAM0[idx]}; // load an entire 32 bit data from the 4 separate byte banks by concatenating them

    always_comb // blocking assignment is used for combinational logic as lines execute one by one
    begin
        case(funct3)
            3'b000: rd={{24{word_read[8*a[1:0]+7]}},word_read[8*a[1:0]+:8]};  // LB (same as lbu just replicating the signed bit)
            3'b001: rd={{16{word_read[16*a[1]+15]}},word_read[16*a[1]+:16]}; // LH
            3'b010: rd=word_read;                                            // LW
            3'b100: rd={24'b0,word_read[8*a[1:0]+:8]};                       // LBU (we look at the end of the address(ie [1:0]) and then multiply 8 to convert it to bit number and then read 8 bits and return)
            3'b101: rd={16'b0,word_read[16*a[1]+:16]};                       // LHU
            default: rd=word_read;
        endcase
    end

    // --- WRITE LOGIC ---
    always_ff @(posedge clk) begin // always use a non blocking assignment for flip flops as all the lines happen at same time at the end of clock cycle. 
                                   // It ensures that when data is swapped between 2 registers they dont overwrite each other instantly.
        if (we) begin // modify memory iff write enable
            // STORE BYTE (SB)
            if (funct3==3'b000) begin
                if      (a[1:0]==0) RAM0[idx]<=wd[7:0]; // if bottom 2 bits are 00 store in byte 0
                else if (a[1:0]==1) RAM1[idx]<=wd[7:0]; // if bottom 2 bits are 01 store in byte 1
                else if (a[1:0]==2) RAM2[idx]<=wd[7:0]; // if bottom 2 bits are 10 store in byte 2
                else                RAM3[idx]<=wd[7:0]; // if bottom 2 bits are 11 store in byte 3
            end
            // STORE HALF (SH)
            else if (funct3==3'b001) begin
                if (a[1]==0) begin // Bytes 0,1
                    RAM0[idx]<=wd[7:0];
                    RAM1[idx]<=wd[15:8];
                end 
                else begin     // Bytes 2,3
                    RAM2[idx]<=wd[7:0];
                    RAM3[idx]<=wd[15:8];
                end
            end
            // STORE WORD (SW)
            else if (funct3==3'b010) begin // simply store the 32 bit data in the 4 banks
                RAM0[idx]<=wd[7:0];
                RAM1[idx]<=wd[15:8];
                RAM2[idx]<=wd[23:16];
                RAM3[idx]<=wd[31:24];
            end
        end
    end
    
// note- the cpu asks for 32 bit instructions, so we need to store a word and not only a byte(like logic [7:0] RAM [64:0])
//       because on implementing this instruction, we will have to wait for 4 clock cycles to fetch a single 32 bit(1 word) instruction.
//       So we create 4 such RAMs with each containing a byte of the entire 1 word instruction for a given same address. 
//       In this way, we can modify the ram byte wise. If this were a 64 bit processor, we would need 8 byte banks!
endmodule