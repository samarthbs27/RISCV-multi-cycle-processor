module mem #(parameter string MEM_FILE = "../mem/riscvtest.txt")
            (input  logic        clk, we,
             input  logic [2:0]  funct3,
             input  logic        data_en,
             input  logic [31:0] a, wd,
             output logic [31:0] Instr);

    reg [31:0] RAM1[0:255];

    initial
        $readmemh(MEM_FILE, RAM1);

    // Read path: byte/halfword extraction when data_en=1
    logic [31:0] word;
    logic [7:0]  byte_val;
    logic [15:0] half_val;

    assign word     = RAM1[a[9:2]];
    assign byte_val = word[{a[1:0], 3'b0} +: 8];
    assign half_val = word[{a[1],   4'b0} +: 16];

    always_comb
        if (!data_en)
            Instr = word;
        else
            case (funct3)
                3'b000: Instr = {{24{byte_val[7]}}, byte_val};    // lb
                3'b001: Instr = {{16{half_val[15]}}, half_val};   // lh
                3'b010: Instr = word;                              // lw
                3'b100: Instr = {24'b0, byte_val};                // lbu
                3'b101: Instr = {16'b0, half_val};                // lhu
                default: Instr = word;
            endcase

    // Write path: byte-enable based on funct3
    always_ff @(posedge clk)
        if (we)
            case (funct3)
                3'b000: RAM1[a[9:2]][{a[1:0], 3'b0} +: 8]  <= wd[7:0];   // sb
                3'b001: RAM1[a[9:2]][{a[1],   4'b0} +: 16] <= wd[15:0];  // sh
                default: RAM1[a[9:2]] <= wd;                               // sw
            endcase

endmodule
