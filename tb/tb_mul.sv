`timescale 1ns/1ps
module testbench_mul();
    logic        clk, reset;
    logic [31:0] WriteData, DataAdr;
    logic        MemWrite;

    top #(.MEM_FILE("../mem/mul_test.hex")) dut(
        .clk(clk), .reset(reset),
        .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

    initial begin reset <= 1; #22; reset <= 0; end
    always  begin clk   <= 1; #5;  clk   <= 0; #5; end

    initial begin
        #20000;
        $display("TIMEOUT: mul test did not complete");
        $finish;
    end

    always @(negedge clk)
        if (MemWrite)
            $display("t=%0t MemWrite: addr=%0d data=0x%08h",
                     $time, DataAdr, WriteData);

    // Expected writes:
    //   addr=100: mul  6 *  7 =  42  (0x0000002A)
    //   addr=104: mul -3 *  5 = -15  (0xFFFFFFF1)
    logic mul_pos_ok, mul_neg_ok;
    initial begin mul_pos_ok = 0; mul_neg_ok = 0; end

    always @(negedge clk) begin
        if (MemWrite) begin
            if (DataAdr === 32'd100 && WriteData === 32'h0000002A) mul_pos_ok <= 1;
            if (DataAdr === 32'd104 && WriteData === 32'hFFFFFFF1) mul_neg_ok <= 1;
        end
        if (mul_pos_ok && mul_neg_ok) begin
            $display("mul test PASSED");
            $finish;
        end
    end
endmodule
