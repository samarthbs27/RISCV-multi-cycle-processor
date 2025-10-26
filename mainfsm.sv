module mainfsm(input clk,
               input reset,
               input logic [6:0] op,
               output logic RegWrite,
               output logic MemWrite,
               output logic IRWrite,
               output logic Branch,
               output logic PCUpdate,
               output logic [1:0] ALUSrcA, ALUSrcB,
               output logic AdrSrc,
               output logic [1:0] ResultSrc,
               output logic [1:0] ALUOp);
               
    reg [3:0] state;
	reg [3:0] nextstate;
	reg [13:0] controls;
               
    localparam [3:0] FETCH = 0;
	localparam [3:0] DECODE = 1;
	localparam [3:0] MEMADR = 2;
	localparam [3:0] MEMRD = 3;
	localparam [3:0] MEMWB = 4;
	localparam [3:0] MEMWR = 5;
	localparam [3:0] EXECUTER = 6;
	localparam [3:0] EXECUTEI = 7;
	localparam [3:0] ALUWB = 8;
	localparam [3:0] BEQ = 9;
	localparam [3:0] JAL = 10;
	localparam [3:0] UNKNOWN = 11;
	
	always @(posedge clk, posedge reset)
	   if (reset)
	       state <= FETCH;
	   else
	       state <= nextstate;
	       
    always @(*)
        casex (state)
            FETCH: nextstate = DECODE;
            DECODE: 
                case(op)
                    7'b0000011: nextstate = MEMADR; // lw
                    7'b0100011: nextstate = MEMADR; // sw
                    7'b0110011: nextstate = EXECUTER; // R-Type
                    7'b1100011: nextstate = BEQ; // beq
                    7'b0010011: nextstate = EXECUTEI; // I-Type
                    7'b1101111: nextstate = JAL; // jal
                endcase
            MEMADR: 
                case(op)
                    7'b0000011: nextstate = MEMRD; // lw
                    7'b0100011:nextstate = MEMWR; // sw
                endcase
            MEMRD: nextstate = MEMWB;
            MEMWB: nextstate = FETCH;
            MEMWR: nextstate = FETCH;
            EXECUTER: nextstate = ALUWB;
            ALUWB: nextstate = FETCH;
            BEQ: nextstate = FETCH;
            EXECUTEI: nextstate = ALUWB;
            JAL: nextstate = ALUWB;
            default: nextstate = FETCH;
        endcase
     
    always @(*)
        case (state)
        // PCUpdate, Branch, MemWrite, RegWrite, IRWrite, AdrSrc, ResultSrc, ALUSrcA, ALUSrcB, ALUOp
            FETCH: controls =    14'b1_0_0_0_1_0_10_00_10_00;
			DECODE: controls =   14'b0_0_0_0_0_x_xx_01_01_00;
			MEMADR: controls =   14'b0_0_0_0_0_0_xx_10_01_00;
			MEMRD: controls =    14'b0_0_0_0_0_1_00_xx_xx_xx;
			MEMWB: controls =    14'b0_0_0_1_0_x_01_xx_xx_xx;
			MEMWR: controls =    14'b0_0_1_0_0_1_00_xx_xx_xx;
			EXECUTER: controls = 14'b0_0_0_0_0_0_xx_10_00_10; // ALUop will look at funct3
			EXECUTEI: controls = 14'b0_0_0_0_0_x_xx_10_01_10; // ALUop will look at funct3
			ALUWB: controls =    14'b0_0_0_1_0_x_00_xx_xx_xx;
			BEQ: controls =      14'b0_1_0_0_0_x_00_10_00_01;
			JAL: controls =      14'b1_0_0_0_0_x_00_01_10_00;
			default: controls =  14'b0_0_0_0_0_x_xx_xx_xx_xx;
        endcase
    
    assign {PCUpdate, Branch, MemWrite, RegWrite, IRWrite, AdrSrc, ResultSrc, ALUSrcA, ALUSrcB, ALUOp} = controls;
    
//    initial begin
//        $monitor("MainFSM: At time %t, Controls = %0b, State = %0d", $time, controls, state);
//    end

endmodule
