`timescale 1ns/1ps

module testbench_bubble;

    logic        clk, reset;
    logic [31:0] WriteData, DataAdr;
    logic        MemWrite;

    // Instantiate top with bubble sort hex
    top #(.MEM_FILE("../mem/bubble_fixed_instr.hex"))
        dut(.clk(clk), .reset(reset),
            .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

    // Clock: 10 ns period
    initial clk = 0;
    always  clk = #5 ~clk;

    // Single clean reset
    initial begin
        reset = 1;
        #22;
        reset = 0;
    end

    // Pass check: poll sorted array directly from RAM every cycle.
    // arr[0..4] live at word indices 244..248 (a[9:2] mapped from 0xFFFFFFD0..0xFFFFFFE0).
    // First time all five equal [1,2,3,4,5] the sort is done.
    always @(negedge clk) begin
        if (!reset) begin
            if (dut.mem.RAM1[244] === 32'd1 &&
                dut.mem.RAM1[245] === 32'd2 &&
                dut.mem.RAM1[246] === 32'd3 &&
                dut.mem.RAM1[247] === 32'd4 &&
                dut.mem.RAM1[248] === 32'd5) begin
                $display("Bubble sort passed: [%0d,%0d,%0d,%0d,%0d]",
                    dut.mem.RAM1[244], dut.mem.RAM1[245], dut.mem.RAM1[246],
                    dut.mem.RAM1[247], dut.mem.RAM1[248]);
                $finish;
            end
        end
    end

    // Timeout: 100 us (10000 cycles)
    initial begin
        #100000;
        $display("TIMEOUT — array: [%0d,%0d,%0d,%0d,%0d]",
            dut.mem.RAM1[244], dut.mem.RAM1[245], dut.mem.RAM1[246],
            dut.mem.RAM1[247], dut.mem.RAM1[248]);
        $finish;
    end

endmodule
