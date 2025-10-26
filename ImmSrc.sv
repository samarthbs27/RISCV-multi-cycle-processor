module ImmSrc(input logic [6:0] op,
               output logic [1:0] ImmSrc);
               
    logic [1:0] controls;
    
    assign ImmSrc = controls;
            
    always_comb
        case(op)
        // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump
            7'b0000011: controls = 2'b00; // lw
            7'b0100011: controls = 2'b01; // sw
            7'b0110011: controls = 2'bxx; // R-type
            7'b1100011: controls = 2'b10; // beq
            7'b0010011: controls = 2'b00; // I-type ALU
            7'b1101111: controls = 2'b11; // jal
            default: controls = 2'bxx; // ???
        endcase
        
    // initial begin
    //     $monitor("ImmSrc: At time %t, ImmSrc = %0b", $time, ImmSrc);
    // end
endmodule
