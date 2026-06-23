module top #(parameter string MEM_FILE = "../mem/riscvtest.txt")
            (input  logic        clk, reset,
             output logic [31:0] WriteData, DataAdr,
             output logic        MemWrite);

    logic [31:0] PC, Instr;
    logic [2:0]  funct3;
    logic        data_en;

    riscvmulti rvmulti(.clk(clk), .reset(reset), .Instr(Instr), .PC(PC),
                       .MemWrite(MemWrite), .WriteData(WriteData), .Result(DataAdr),
                       .funct3(funct3), .AdrSrc(data_en));

    mem #(.MEM_FILE(MEM_FILE)) mem(.clk(clk), .we(MemWrite), .a(PC),
                                   .wd(WriteData), .Instr(Instr),
                                   .funct3(funct3), .data_en(data_en));

endmodule
