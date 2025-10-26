module top(input  logic        clk, reset,
           output logic [31:0] WriteData, DataAdr,
           output logic        MemWrite);
           
    logic [31:0] PC, Instr; //, ReadData
    
    // instantiate processor and memories
    riscvmulti rvmulti(.clk(clk), .reset(reset), .Instr(Instr), .PC(PC), // .ReadData(ReadData),
                       .MemWrite(MemWrite), .WriteData(WriteData), .Result(DataAdr));
                         
    mem mem(.clk(clk), .we(MemWrite), .a(PC), .wd(WriteData), .Instr(Instr)); // .rd(ReadData), .adr(DataAdr),
endmodule