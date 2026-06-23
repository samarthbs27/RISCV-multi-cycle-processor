module ImmSrc(input logic [6:0] op,
               output logic [2:0] ImmSrc);

    logic [2:0] controls;

    assign ImmSrc = controls;

    always_comb
        case(op)
            7'b0000011: controls = 3'b000; // lw       (I-type)
            7'b0100011: controls = 3'b001; // sw       (S-type)
            7'b0110011: controls = 3'bxxx; // R-type   (no immediate)
            7'b1100011: controls = 3'b010; // branches (B-type)
            7'b0010011: controls = 3'b000; // I-type ALU
            7'b1101111: controls = 3'b011; // jal      (J-type)
            7'b1100111: controls = 3'b000; // jalr     (I-type)
            7'b0110111: controls = 3'b100; // lui      (U-type)
            7'b0010111: controls = 3'b100; // auipc    (U-type)
            default:    controls = 3'bxxx;
        endcase
        
    // initial begin
    //     $monitor("ImmSrc: At time %t, ImmSrc = %0b", $time, ImmSrc);
    // end
endmodule
