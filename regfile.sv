module regfile(input  logic        clk, reset,
               input  logic        we3,
               input  logic [4:0]  a1, a2, a3,
               input  logic [31:0] wd3,
               output logic [31:0] rd1, rd2);
               
    logic [31:0] rf[31:0];
    // three ported register file
    // read two ports combinationally (A1/RD1, A2/RD2)
    // write third port on rising edge of clock (A3/WD3/WE3)
    // register 0 hardwired to 0
    always_ff @(posedge clk) begin
        // if (we3 && (a3!=0)) rf[a3] <= wd3;
        if (reset) begin
            for (int i = 0; i < 32; i++) begin
                rf[i] <= 32'b0;
            end
        end 
        else if (we3 && (a3 != 0)) begin
            rf[a3] <= wd3;
        end
        // for (int i = 0; i < 32; i++) begin
        //     $display("rf[%d] = %0h", i, rf[i]);   // Initialize each element to zero
        // end
    end

    assign rd1 = (a1 == 5'b0) ? 32'b0 : rf[a1];
    assign rd2 = (a2 == 5'b0) ? 32'b0 : rf[a2];
        
   initial begin
       $monitor("RegFile: At time %t, wd3 = %0h, we3 = %0h", $time, wd3, we3);
   end
endmodule
