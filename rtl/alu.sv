module alu(input  logic [31:0] a, b,
           input  logic [3:0]  alucontrol,
           output logic [31:0] result,
           output logic        zero,
           output logic        branch_lesser);

    logic [31:0] condinvb, sum;
    logic        v;        // signed overflow
    logic        isAddSub; // true for add or subtract

    assign condinvb = alucontrol[0] ? ~b : b;
    assign sum      = a + condinvb + alucontrol[0];
    assign isAddSub = (alucontrol[3:1] == 3'b000); // codes 4'b000x (ADD/SUB only)

    always_comb
        case (alucontrol)
            4'b0000: result = sum;                       // add
            4'b0001: result = sum;                       // subtract
            4'b0010: result = a & b;                     // and
            4'b0011: result = a | b;                     // or
            4'b0100: result = a ^ b;                     // xor
            4'b0101: result = {31'b0, sum[31] ^ v};      // slt (signed)
            4'b0110: result = a << b[4:0];               // sll
            4'b0111: result = a >> b[4:0];               // srl
            4'b1000: result = $signed(a) >>> b[4:0];     // sra
            default: result = 32'bx;
        endcase

    assign v             = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]) & isAddSub;
    assign zero          = (result == 32'b0);
    assign branch_lesser = result[31] ^ v; // signed less-than: accounts for overflow

endmodule
