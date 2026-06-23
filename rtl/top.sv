module top #(parameter string MEM_FILE = "../mem/riscvtest.txt")
            (input  logic        clk, reset,
             output logic [31:0] WriteData, DataAdr,
             output logic        MemWrite);

    logic [31:0] PC, Instr;

    riscvmulti rvmulti(.clk(clk), .reset(reset), .Instr(Instr), .PC(PC),
                       .MemWrite(MemWrite), .WriteData(WriteData), .Result(DataAdr));

    mem #(.MEM_FILE(MEM_FILE)) mem(.clk(clk), .we(MemWrite), .a(PC), .wd(WriteData), .Instr(Instr));

endmodule
