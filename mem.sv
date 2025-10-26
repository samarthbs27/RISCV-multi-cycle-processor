module mem(input  logic        clk, we,
           input  logic [31:0] a, wd, // adr,
           output logic [31:0] Instr); //, rd
            
    reg [31:0] RAM1[256:0];
    logic [31:0] a_wrapped;
    
    initial
    begin
//        $display(RAM);
//        $readmemh("/home/cmos/Desktop/Samarth/multi_cycle_processor/riscvtest.txt", RAM1);
//        $readmemh("/home/cmos/Desktop/Samarth/new_multi_cycle_processor/branch_test.txt", RAM1);
	$readmemh("C:\\Users\\samar\\OneDrive\\Desktop\\Projects\\new_multi_cycle_processor\\bubble.txt", RAM1);
    end
        
    assign Instr = RAM1[a[31:2]]; // word aligned
//    assign rd = RAM1[adr[31:2]]; // word aligned

    assign a_wrapped = a & 32'hFF;
    
    always_ff @(posedge clk)
        // if (we) RAM1[a[31:2]] <= wd;
        if (we) RAM1[a_wrapped[31:2]] <= wd;
    
//    initial begin
//        $monitor("At time %t, Hex a[31:2] = %0h, Hex RAM1[a[31:2]], Hex a_wrapped[31:2] = %0h, Hex RAM1[a_wrapped[31:2]] = %0h", $time, a[31:2], RAM1[a[31:2]], a_wrapped[31:2], RAM1[a_wrapped[31:2]]);
//    end
endmodule
