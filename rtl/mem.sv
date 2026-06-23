module mem #(parameter string MEM_FILE = "../mem/riscvtest.txt")
            (input  logic        clk, we,
             input  logic [31:0] a, wd,
             output logic [31:0] Instr);

    reg [31:0] RAM1[0:255];

    initial
        $readmemh(MEM_FILE, RAM1);

    assign Instr = RAM1[a[9:2]];

    always_ff @(posedge clk)
        if (we) RAM1[a[9:2]] <= wd;

endmodule
