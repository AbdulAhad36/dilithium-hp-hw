module adder_tb;

    logic [7:0] a, b;
    logic [8:0] sum;

    // Instantiate DUT
    adder dut (
        .a(a),
        .b(b),
        .sum(sum)
    );

    initial begin
        // Dump waves
        $dumpfile("waves/adder.vcd");
        $dumpvars(0, adder_tb);

        // Test cases
        a = 10; b = 5;   #10;
        a = 20; b = 30;  #10;
        a = 100; b = 50; #10;
        a = 255; b = 1;  #10;

        $finish;
    end

endmodule