`timescale 1ns/1ps

module testbench();

    logic        clk;
    logic        reset;
    logic [31:0] WriteData, DataAdr;
    logic        MemWrite;
    
    // instantiate device to be tested
    top dut(.clk(clk), .reset(reset), .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
    
    // initialize test
    initial begin
        reset <= 1; #22; reset <= 0;
    end

    // generate clock to sequence tests
    always begin
        clk <= 1; #5; clk <= 0; #5;
    end

    // simulation timeout
    initial begin
        #10000;
        $display("TIMEOUT: simulation did not complete in time");
        $finish;
    end

    // check results
    always @(negedge clk) begin
        if (MemWrite) begin
            if (DataAdr === 32'd100 && WriteData === 32'd25) begin
                $display("Simulation succeeded");
                $finish;
            end
        end
    end
endmodule
