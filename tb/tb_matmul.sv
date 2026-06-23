`timescale 1ns/1ps
module testbench_matmul();
    logic        clk, reset;
    logic [31:0] WriteData, DataAdr;
    logic        MemWrite;

    top #(.MEM_FILE("../mem/matmul.hex")) dut(
        .clk(clk), .reset(reset),
        .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

    initial begin reset <= 1; #22; reset <= 0; end
    always  begin clk   <= 1; #5;  clk   <= 0; #5; end

    initial begin
        #200000;
        $display("TIMEOUT: matmul test did not complete");
        $finish;
    end

    always @(negedge clk)
        if (MemWrite)
            $display("t=%0t MemWrite: addr=%0d data=%0d",
                     $time, DataAdr, $signed(WriteData));

    // A = [[1,2,3],[4,5,6],[7,8,9]]
    // B = [[9,8,7],[6,5,4],[3,2,1]]
    // C = A*B stored row-major at addr 704 (0x2C0)
    //   C = [[30,24,18],[84,69,54],[138,114,90]]
    logic [8:0] got;    // one bit per expected write
    initial got = 9'b0;

    always @(negedge clk) begin
        if (MemWrite) begin
            if (DataAdr === 32'd704 && WriteData === 32'd30 ) got[0] <= 1;
            if (DataAdr === 32'd708 && WriteData === 32'd24 ) got[1] <= 1;
            if (DataAdr === 32'd712 && WriteData === 32'd18 ) got[2] <= 1;
            if (DataAdr === 32'd716 && WriteData === 32'd84 ) got[3] <= 1;
            if (DataAdr === 32'd720 && WriteData === 32'd69 ) got[4] <= 1;
            if (DataAdr === 32'd724 && WriteData === 32'd54 ) got[5] <= 1;
            if (DataAdr === 32'd728 && WriteData === 32'd138) got[6] <= 1;
            if (DataAdr === 32'd732 && WriteData === 32'd114) got[7] <= 1;
            if (DataAdr === 32'd736 && WriteData === 32'd90 ) got[8] <= 1;
        end
        if (got === 9'b111111111) begin
            $display("matmul test PASSED — C = [[30,24,18],[84,69,54],[138,114,90]]");
            $finish;
        end
    end
endmodule
