module riscvmulti(input logic 	      clk, reset,
                  input logic  [31:0] Instr,
                  output logic [31:0] PC,
                  output logic 	      MemWrite,
                  output logic [31:0] WriteData, Result,
                  output logic [2:0]  funct3,
                  output logic        AdrSrc);
                   
    logic 	 RegWrite, Zero, IRWrite, PCWrite, branch_lesser, branch_lesser_u;
    logic [1:0]  ALUSrcA, ALUSrcB, ResultSrc;
    logic [2:0]  ImmSrc;
    logic [3:0]  ALUControl;
    logic [31:0] datapath_Instr;
    assign funct3 = datapath_Instr[14:12];
    
    controller c(.clk(clk), .reset(reset), .op(datapath_Instr[6:0]), .funct3(datapath_Instr[14:12]), .funct7b5(datapath_Instr[30]), .funct7b0(datapath_Instr[25]),
                 .Zero(Zero), .ImSrc(ImmSrc), .ALUControl(ALUControl),
                 .RegWrite(RegWrite), .MemWrite(MemWrite), .IRWrite(IRWrite),
                 .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB), .AdrSrc(AdrSrc), .ResultSrc(ResultSrc), .PCWrite(PCWrite),
                 .branch_lesser(branch_lesser), .branch_lesser_u(branch_lesser_u));
                 
    datapath dp(.clk(clk), .reset(reset), .PCWrite(PCWrite), .AdrSrc(AdrSrc), .IRWrite(IRWrite), .Instr_in(Instr), 
                .RegWrite(RegWrite), .ImmSrc(ImmSrc), .AluSrcA(ALUSrcA), .AluSrcB(ALUSrcB), .ALUControl(ALUControl), 
                .ResultSrc(ResultSrc), .adr(PC), .WriteData(WriteData), .Result(Result), .Instr(datapath_Instr), .Zero(Zero),
		.branch_lesser(branch_lesser), .branch_lesser_u(branch_lesser_u));
                
endmodule
