`timescale 1ns/1ps
module testbench_mulh();
    logic        clk, reset;
    logic [31:0] WriteData, DataAdr;
    logic        MemWrite;

    top #(.MEM_FILE("../mem/mulh_test.hex")) dut(
        .clk(clk), .reset(reset),
        .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

    initial begin reset <= 1; #22; reset <= 0; end
    always  begin clk   <= 1; #5;  clk   <= 0; #5; end

    initial begin
        #20000;
        $display("TIMEOUT: mulh test did not complete");
        $finish;
    end

    always @(negedge clk)
        if (MemWrite)
            $display("t=%0t MemWrite: addr=%0d data=0x%08h",
                     $time, DataAdr, WriteData);

    // x1 = 0xFFFFFFFF
    // mulh  x1,x1: (-1)*(-1)=1         → upper = 0x00000000
    // mulhu x1,x1: (2^32-1)^2          → upper = 0xFFFFFFFE
    // mulhsu x1,x1: signed(-1)*unsigned(2^32-1)=-(2^32-1) → upper = 0xFFFFFFFF
    logic mulh_ok, mulhu_ok, mulhsu_ok;
    initial begin mulh_ok = 0; mulhu_ok = 0; mulhsu_ok = 0; end

    always @(negedge clk) begin
        if (MemWrite) begin
            if (DataAdr === 32'd100 && WriteData === 32'h00000000) mulh_ok  <= 1;
            if (DataAdr === 32'd104 && WriteData === 32'hFFFFFFFE) mulhu_ok <= 1;
            if (DataAdr === 32'd108 && WriteData === 32'hFFFFFFFF) mulhsu_ok <= 1;
        end
        if (mulh_ok && mulhu_ok && mulhsu_ok) begin
            $display("mulh/mulhu/mulhsu test PASSED");
            $finish;
        end
    end
endmodule
