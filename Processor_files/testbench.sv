`timescale 1ns / 1ps

module testbench(); // list is empty as this is the "universe" and everything is expected to happen inside this itself
    logic clk;
    logic reset;
    logic [31:0] writedata,dataadr; // writedata: data to be written to memory, dataaddr: address in memory the cpu wants to access
    logic memwrite; // 1 bit control signal (1=write, 0=read)
    logic [2:0] funct3M; // size information(byte,half or word) from CPU to memory
    logic [31:0] pc,instr,readdata; // readdata: data read from dmem, instr: instruction read from imem

    always begin // clock generation(100MHz)
        clk=1; #5;
        clk=0; #5;
    end // total time period=10ns

    initial begin
        reset=1; #22; reset=0; // just reset for some time so all the flipflops reset at the rising clock edge
    end
    
    riscv riscv(clk,reset,pc,instr,dataadr,writedata,readdata,memwrite,funct3M);
    imem imem(pc,instr);
    dmem dmem(clk,memwrite,dataadr,writedata,funct3M,readdata);
    
endmodule