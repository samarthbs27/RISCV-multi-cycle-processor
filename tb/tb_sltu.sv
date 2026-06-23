`timescale 1ns/1ps

// Tests SLTU, BLTU, and BGEU instructions.
// Program (sltu_branch_test.hex):
//   0x00: addi x1, x0, 3
//   0x04: addi x2, x0, 5
//   0x08: sltu x3, x1, x2   -> x3 = 1  (3 <u 5)
//   0x0C: sw   x3, 100(x0)  -> addr=100, data=1
//   0x10: bltu x1, x2, +8   -> branch taken (3 <u 5), skip 0x14
//   0x14: addi x10, x0, 0   -> NOT EXECUTED (if branch taken)
//   0x18: addi x10, x0, 1   -> x10 = 1
//   0x1C: sw   x10, 104(x0) -> addr=104, data=1
//   0x20: bgeu x2, x1, +8   -> branch taken (5 >=u 3), skip 0x24
//   0x24: addi x11, x0, 0   -> NOT EXECUTED (if branch taken)
//   0x28: addi x11, x0, 1   -> x11 = 1
//   0x2C: sw   x11, 108(x0) -> addr=108, data=1
//   0x30: jal  x0, 0        -> halt

module testbench_sltu();

    logic        clk, reset;
    logic [31:0] WriteData, DataAdr;
    logic        MemWrite;

    top #(.MEM_FILE("../mem/sltu_branch_test.hex")) dut(
        .clk(clk), .reset(reset),
        .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

    initial begin reset <= 1; #22; reset <= 0; end
    always begin clk <= 1; #5; clk <= 0; #5; end

    initial begin
        #20000;
        $display("TIMEOUT: SLTU/BLTU/BGEU test did not complete");
        $finish;
    end

    // Print every memory write to show what the processor is doing
    always @(negedge clk) begin
        if (MemWrite)
            $display("t=%0t MemWrite: addr=%0d data=%0d (0x%08h)",
                     $time, DataAdr, WriteData, WriteData);
    end

    logic sltu_ok, bltu_ok;
    initial begin sltu_ok = 0; bltu_ok = 0; end

    always @(negedge clk) begin
        if (MemWrite) begin
            if (DataAdr === 32'd100 && WriteData === 32'd1)
                sltu_ok <= 1;
            if (DataAdr === 32'd104 && WriteData === 32'd1 && sltu_ok)
                bltu_ok <= 1;
            if (DataAdr === 32'd108 && WriteData === 32'd1 && bltu_ok) begin
                $display("SLTU/BLTU/BGEU test passed");
                $finish;
            end
        end
    end

endmodule
