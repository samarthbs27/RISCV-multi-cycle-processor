module alu(input  logic [31:0] a, b,
           input  logic [3:0]  alucontrol,
           output logic [31:0] result,
           output logic        zero,
           output logic        branch_lesser,
           output logic        branch_lesser_u);

    logic [31:0] condinvb, sum;
    logic [32:0] sum_ext;  // 33-bit to capture carry out
    logic        v;        // signed overflow
    logic        isAddSub; // true for add or subtract
    logic [63:0] product_ss, product_uu, product_su;
    assign product_ss = $signed({{32{a[31]}}, a}) * $signed({{32{b[31]}}, b});
    assign product_uu = {32'b0, a} * {32'b0, b};
    assign product_su = $signed({{32{a[31]}}, a}) * $signed({32'b0, b});

    assign condinvb = alucontrol[0] ? ~b : b;
    assign sum_ext  = {1'b0, a} + {1'b0, condinvb} + {32'b0, alucontrol[0]};
    assign sum      = sum_ext[31:0];
    assign isAddSub = (alucontrol[3:1] == 3'b000); // codes 4'b000x (ADD/SUB only)

    always_comb
        case (alucontrol)
            4'b0000: result = sum;                        // add
            4'b0001: result = sum;                        // subtract
            4'b0010: result = a & b;                      // and
            4'b0011: result = a | b;                      // or
            4'b0100: result = a ^ b;                      // xor
            4'b0101: result = {31'b0, sum[31] ^ v};       // slt (signed)
            4'b0110: result = a << b[4:0];                // sll
            4'b0111: result = a >> b[4:0];                // srl
            4'b1000: result = $signed(a) >>> b[4:0];      // sra
            4'b1001: result = b;                          // pass B (lui)
            4'b1011: result = {31'b0, ~sum_ext[32]};      // sltu (unsigned)
            4'b1100: result = a * b;                      // mul (lower 32 bits)
            4'b1101: result = product_ss[63:32];          // mulh  (signed   × signed)
            4'b1110: result = product_su[63:32];          // mulhsu (signed  × unsigned)
            4'b1111: result = product_uu[63:32];          // mulhu (unsigned × unsigned)
            default: result = 32'bx;
        endcase

    assign v               = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]) & isAddSub;
    assign zero            = (result == 32'b0);
    assign branch_lesser   = result[31] ^ v;       // signed less-than
    assign branch_lesser_u = ~sum_ext[32];          // unsigned less-than: borrow = no carry out

endmodule
