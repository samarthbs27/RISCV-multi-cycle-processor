module datapath(input logic 	    clk, reset,
                input logic 	    PCWrite, // Multi cycle implementation
                input logic 	    AdrSrc, // Multi cycle implementation
                input logic 	    IRWrite, // Multi cycle implementation
                input logic  [31:0] Instr_in, // Multi cycle modification
                input logic 	    RegWrite,
                input logic  [1:0]  ImmSrc, // Multi cycle modification
                input logic  [1:0]  AluSrcA, AluSrcB,
                input logic  [2:0]  ALUControl,
                input logic  [1:0]  ResultSrc,         
                output logic [31:0] adr,
                output logic [31:0] WriteData, Result, Instr,
                output logic 	    Zero,
                output logic 	    branch_lesser);
                
    logic [31:0] OldPC;
    logic [31:0] PC, Data; // Multi cycle implementation
    logic [31:0] ImmExt;
    logic [31:0] RD1, RD2; // Multi cycle implementation
    logic [31:0] Addr; // Multi cycle implementation
    logic [31:0] SrcA, SrcB;
    logic [31:0] ALUOutput; // Multi cycle implementation
    logic [31:0] ALUResult;
    
    // next PC logic
    flopenr #(.WIDTH(32)) pcupdate(.clk(clk), .reset(reset), .en(PCWrite), .d(Result), .q(PC)); // Multi cycle modification
    mux2    #(.WIDTH(32)) adrmux(.d0(PC), .d1(Result), .s(AdrSrc), .y(adr)); // Multi cycle implementation
    flopenr #(.WIDTH(32)) pcreg(.clk(clk), .reset(reset), .en(IRWrite), .d(PC), .q(OldPC)); // Multi cycle modification
    flopenr #(.WIDTH(32)) instrreg(.clk(clk), .reset(reset), .en(IRWrite), .d(Instr_in), .q(Instr)); // Multi cycle implementation
    flopr   #(.WIDTH(32)) readreg(.clk(clk), .reset(reset), .d(Instr_in), .q(Data));
    
    // register file logic
    regfile               rf(.clk(clk), .reset(reset), .we3(RegWrite), .a1(Instr[19:15]), .a2(Instr[24:20]),
                             .a3(Instr[11:7]), .wd3(Result), .rd1(RD1), .rd2(RD2)); // Multi cycle modification
    extend                ext(.instr(Instr[31:7]), .immsrc(ImmSrc), .immext(ImmExt));
    flopr2  #(.WIDTH(32)) regfilereg(.clk(clk), .reset(reset), .d0(RD1), .d1(RD2), .q0(Addr), .q1(WriteData)); // Multi cycle implementation
    // ALU logic

    mux3    #(.WIDTH(32)) srcamux(.d0(PC), .d1(OldPC), .d2(Addr), .s(AluSrcA), .y(SrcA)); // Multi cycle implementation
    mux3    #(.WIDTH(32)) srcbmux(.d0(WriteData), .d1(ImmExt), .d2(32'd4), .s(AluSrcB), .y(SrcB)); // Multi cycle implementation
    alu                   alu(.a(SrcA), .b(SrcB), .alucontrol(ALUControl), .result(ALUResult), .zero(Zero), .branch_lesser(branch_lesser)); // Multi cycle modification
    flopr   #(.WIDTH(32)) aluout(.clk(clk), .reset(reset), .d(ALUResult), .q(ALUOutput)); // Multi cycle implementation
    mux3    #(.WIDTH(32)) resultmux(.d0(ALUOutput), .d1(Data), .d2(ALUResult), .s(ResultSrc), .y(Result)); // Multi cycle implementation
    
    
//    initial begin
//        $monitor("Datapath: At time %t, PC = %0h, adr = %0h, ALUSrcA = %0h, ALUSrcAData = %0h, ALUSrcB = %0h, ALUSrcBData = %0h, ALUResult = %0h, ALUOutput = %0h, Result = %0h", $time, PC, adr, AluSrcA, SrcA, AluSrcB, SrcB, ALUResult, ALUOutput, Result);
//    end
endmodule
