module hazard (
    input logic [4:0] rs1D,rs2D,rs1E,rs2E,rdE,rdM,rdW, // source and destination registers in decode,execute,memory and writeback stages
    input logic regwriteM,regwriteW, // write enable(we forward only if instruction is actually writing to a register)
    input logic resultsrcE0, // LSB of resultsrcE(0->aluresult, 1->memory load(LW)) (see controls of controller.sv)
    input logic pcsrcE, // branch taken flag. If 1, instructions in fetch and decode stage are wrong and must be flushed
    output logic [1:0] forwardAE,forwardBE, // forwarding data between stages
    output logic stallF,stallD, // freeze fetch and decode registers
    output logic flushD,flushE //flushes decode and execute registers
);
    logic lwstall; // this goes 1 if load-use hazard is detected

    always_comb begin
        forwardAE=2'b00; // default- no forwarding, just read from reg file
        forwardBE=2'b00; // default- no forwarding, just read from reg file
        if (((rs1E==rdM)&&regwriteM)&&(rs1E!=0)) forwardAE=2'b10; // if rs1 in execute stage matches rd in memory stage and memory stage is writing to memory and it is not x0, forward from memory stage to start of execute stage
        else if (((rs1E==rdW)&&regwriteW)&&(rs1E!=0)) forwardAE=2'b01; // if rs1 in execute stage matches rd in writeback stage and writeback stage is writing to memory and it is not x0, forward from writeback stage to start of execute stage
        
        if (((rs2E==rdM)&&regwriteM)&&(rs2E!=0)) forwardBE=2'b10;
        else if (((rs2E==rdW)&&regwriteW)&&(rs2E!=0)) forwardBE=2'b01;
    end

    assign lwstall=resultsrcE0&((rs1D==rdE)|(rs2D==rdE)); // if instruction in execute stage is a LW(resultsrcE0) and instruction in decode is trying to read the register being loaded, we stall(load use hazard)
    assign stallF=lwstall; // if lwstall is true, we freeze fetch and decode stages
    assign stallD=lwstall; // same here, these are used for load use hazards
    assign flushD=pcsrcE; // (we begin assuming branch not taken) if a branch is taken(pcsrcE) we flush the instruction currently in decode stage
    assign flushE=lwstall|pcsrcE; // decode is stalled and we cant let the instruction move to execute so we flush
                                  // we also flush execute if a branch is taken so that wrong instructions dont get executed
endmodule