module riscvmulti(input logic 	      clk, reset,
                  input logic  [31:0] Instr, 
                  output logic [31:0] PC,
                  output logic 	      MemWrite,
                  output logic [31:0] WriteData, Result);
                   
    logic 	 RegWrite, Zero, IRWrite, AdrSrc, PCWrite, branch_lesser;
    logic [1:0]  ALUSrcA, ALUSrcB, ResultSrc, ImmSrc;
    logic [2:0]  ALUControl;
    logic [31:0] datapath_Instr;
    
    controller c(.clk(clk), .reset(reset), .op(datapath_Instr[6:0]), .funct3(datapath_Instr[14:12]), .funct7b5(datapath_Instr[30]), 
                 .Zero(Zero), .ImSrc(ImmSrc), .ALUControl(ALUControl), 
                 .RegWrite(RegWrite), .MemWrite(MemWrite), .IRWrite(IRWrite), 
                 .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB), .AdrSrc(AdrSrc), .ResultSrc(ResultSrc), .PCWrite(PCWrite), .branch_lesser(branch_lesser));
                 
    datapath dp(.clk(clk), .reset(reset), .PCWrite(PCWrite), .AdrSrc(AdrSrc), .IRWrite(IRWrite), .Instr_in(Instr), 
                .RegWrite(RegWrite), .ImmSrc(ImmSrc), .AluSrcA(ALUSrcA), .AluSrcB(ALUSrcB), .ALUControl(ALUControl), 
                .ResultSrc(ResultSrc), .adr(PC), .WriteData(WriteData), .Result(Result), .Instr(datapath_Instr), .Zero(Zero),
		.branch_lesser(branch_lesser));
                
endmodule
