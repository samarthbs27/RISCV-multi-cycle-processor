`timescale 1ns/1ps
module testbench_ecall();
    logic        clk, reset;
    logic [31:0] WriteData, DataAdr;
    logic        MemWrite;

    top #(.MEM_FILE("../mem/ecall_test.hex")) dut(
        .clk(clk), .reset(reset),
        .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

    initial begin reset <= 1; #22; reset <= 0; end
    always  begin clk   <= 1; #5;  clk   <= 0; #5; end

    initial begin
        #5000;
        $display("TIMEOUT: ecall/fence test did not terminate");
        $finish;
    end

    always @(negedge clk) begin
        if (MemWrite) begin
            $display("t=%0t MemWrite: addr=%0d data=%0d", $time, DataAdr, WriteData);
            if (DataAdr === 32'd100 && WriteData === 32'd42)
                $display("SW result correct (42 at addr 100); waiting for ecall...");
        end
    end
endmodule
