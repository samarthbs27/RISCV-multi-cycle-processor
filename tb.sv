`timescale 1ns/1ps

module testbench();

    logic        clk;
    logic        reset;
    logic [31:0] WriteData, DataAdr;
    logic        MemWrite;
    
    // instantiate device to be tested
    top dut(.clk(clk), .reset(reset), .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
    
    // initialize test
    initial
        begin
            reset <= 1; #22; reset <= 0; #100; reset <= 1; #30; reset <= 0; #50; reset <= 1; # 22; reset <= 0;
    end
    
    // generate clock to sequence tests
    always
        begin
            clk <= 1; # 5; clk <= 0; # 5;
    end
    
    // check results
    always @(negedge clk)
        begin
            if(MemWrite) begin
                if(DataAdr === 100 & WriteData === 25) begin
                    $display("Simulation succeeded");
                    $stop;
                end //else if (DataAdr !== 96) begin
                    //$display("Simulation failed");
                    //$stop;
                //end
            end
        end
        
    // initial begin
    //     $monitor("Testbench: At time %t, DataAdr = %0h, WriteData = %0h", $time, DataAdr, WriteData);
    // end
endmodule
