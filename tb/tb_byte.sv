`timescale 1ns/1ps
module testbench_byte();
    logic        clk, reset;
    logic [31:0] WriteData, DataAdr;
    logic        MemWrite;

    top #(.MEM_FILE("../mem/byte_halfword_test.hex")) dut(
        .clk(clk), .reset(reset),
        .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

    initial begin reset <= 1; #22; reset <= 0; end
    always  begin clk   <= 1; #5;  clk   <= 0; #5; end

    initial begin
        #20000;
        $display("TIMEOUT: byte/halfword test did not complete");
        $finish;
    end

    always @(negedge clk)
        if (MemWrite)
            $display("t=%0t MemWrite: addr=%0d data=0x%08h",
                     $time, DataAdr, WriteData);

    // Expected writes (addresses 200-212):
    //   addr=200: lb  result = 0xFFFFFFFF  (signed byte  0xFF)
    //   addr=204: lbu result = 0x000000FF  (unsigned byte 0xFF)
    //   addr=208: lh  result = 0xFFFFFFFF  (signed halfword 0xFFFF)
    //   addr=212: lhu result = 0x0000FFFF  (unsigned halfword 0xFFFF)
    logic lb_ok, lbu_ok, lh_ok, lhu_ok;
    initial begin lb_ok = 0; lbu_ok = 0; lh_ok = 0; lhu_ok = 0; end

    always @(negedge clk) begin
        if (MemWrite) begin
            if (DataAdr === 32'd200 && WriteData === 32'hFFFFFFFF) lb_ok  <= 1;
            if (DataAdr === 32'd204 && WriteData === 32'h000000FF) lbu_ok <= 1;
            if (DataAdr === 32'd208 && WriteData === 32'hFFFFFFFF) lh_ok  <= 1;
            if (DataAdr === 32'd212 && WriteData === 32'h0000FFFF) lhu_ok <= 1;
        end
        if (lb_ok && lbu_ok && lh_ok && lhu_ok) begin
            $display("byte/halfword load/store test PASSED");
            $finish;
        end
    end
endmodule
