module controller(input clk, reset,
                  input logic [6:0] op,
                  input logic [2:0] funct3,
                  input logic funct7b5,
                  input logic Zero,
                  output logic [1:0] ImSrc,
                  output logic [2:0] ALUControl,
                  output logic RegWrite,
                  output logic MemWrite,
                  output logic IRWrite,
                  output logic [1:0] ALUSrcA,
                  output logic [1:0] ALUSrcB,
                  output logic AdrSrc,
                  output logic [1:0] ResultSrc,
                  output logic PCWrite,
		  input logic branch_lesser
);
                  
    logic [1:0] ALUOp;
    logic Branch;
    logic PCUpdate;
    
    ImmSrc immsource(.op(op), .ImmSrc(ImSrc));
    aludec  ad(.opb5(op[5]), .funct3(funct3), .funct7b5(funct7b5), .ALUOp(ALUOp), .ALUControl(ALUControl));
    mainfsm md(.clk(clk), .reset(reset), .op(op), .RegWrite(RegWrite), .MemWrite(MemWrite), .IRWrite(IRWrite), .Branch(Branch), .PCUpdate(PCUpdate), 
               .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB), .AdrSrc(AdrSrc), .ResultSrc(ResultSrc), .ALUOp(ALUOp));
    
    assign PCWrite = (Branch & (funct3 == 3'b000) & Zero) |             // BEQ
                     (Branch & (funct3 == 3'b100) & branch_lesser) |    // BLT
                     (Branch & (funct3 == 3'b101) & ~branch_lesser) |   // BGE
                     PCUpdate;
//    assign PCWrite = (Branch & (Zero ^ funct3[0])) | PCUpdate;
    
//    initial begin
//       $monitor("Controller: At time %t, PCWrite = %0b, PCUpdate = %0b", $time, PCWrite, PCUpdate);
//    end
    
endmodule
