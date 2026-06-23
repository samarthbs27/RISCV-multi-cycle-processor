`timescale 1ns/1ps

// Tests LUI and AUIPC instructions.
// Program:
//   0x00: lui  x1, 0x12345    -> x1 = 0x12345000
//   0x04: auipc x2, 1         -> x2 = 0x4 + 0x1000 = 0x00001004
//   0x08: sw   x1, 100(x0)    -> mem write: addr=100, data=0x12345000
//   0x0C: sw   x2, 104(x0)    -> mem write: addr=104, data=0x00001004
//   0x10: jal  x0, 0          -> halt

module testbench_lui();

    logic        clk, reset;
    logic [31:0] WriteData, DataAdr;
    logic        MemWrite;

    top #(.MEM_FILE("../mem/lui_auipc_test.hex")) dut(
        .clk(clk), .reset(reset),
        .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

    initial begin reset <= 1; #22; reset <= 0; end
    always begin clk <= 1; #5; clk <= 0; #5; end

    initial begin
        #2000;
        $display("TIMEOUT: LUI/AUIPC test did not complete");
        $finish;
    end

    logic lui_ok;
    initial lui_ok = 0;

    always @(negedge clk) begin
        if (MemWrite) begin
            if (DataAdr === 32'd100 && WriteData === 32'h12345000)
                lui_ok <= 1;
            if (DataAdr === 32'd104 && WriteData === 32'h00001004 && lui_ok) begin
                $display("LUI/AUIPC test passed: lui=0x12345000, auipc=0x00001004");
                $finish;
            end
        end
    end

endmodule
