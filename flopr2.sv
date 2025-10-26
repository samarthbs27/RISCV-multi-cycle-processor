module flopr2 #(parameter WIDTH = 8)
              (input  logic             clk, reset,
               input  logic [WIDTH-1:0] d0, d1,
               output reg   [WIDTH-1:0] q0, q1);
               
    always_ff @(posedge clk, posedge reset)
                if (reset)
                begin
                    q0 <= 0;
                    q1 <= 0;
                end
                else
                begin
                    q0 <= d0;
                    q1 <= d1;
                end
endmodule