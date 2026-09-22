module tb_mac;

    parameter BITWIDTH = 8;

    reg clk;
    reg rst;

    reg [BITWIDTH-1:0] p00, p01, p02;
    reg [BITWIDTH-1:0] p10, p11, p12;
    reg [BITWIDTH-1:0] p20, p21, p22;

    wire [BITWIDTH-1:0] result;


    // ============================================================
    // DUT
    // ============================================================

    mac_unit #(
        .BITWIDTH(BITWIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),

        .p00(p00),
        .p01(p01),
        .p02(p02),

        .p10(p10),
        .p11(p11),
        .p12(p12),

        .p20(p20),
        .p21(p21),
        .p22(p22),

        .result(result)
    );


    // ============================================================
    // CLOCK
    // 10 ns period
    // ============================================================

    always #5 clk = ~clk;


    // ============================================================
    // TEST PROCEDURE
    // ============================================================

    initial begin

        clk = 0;
        rst = 1;

        p00 = 0;
        p01 = 0;
        p02 = 0;

        p10 = 0;
        p11 = 0;
        p12 = 0;

        p20 = 0;
        p21 = 0;
        p22 = 0;


        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        #20;

        rst = 0;


        // ========================================================
        // TEST 1
        // Constant image
        //
        // No edge should exist.
        //
        // Gx = 0
        // Gy = 0
        // Output = 0
        // ========================================================

        p00 = 100;
        p01 = 100;
        p02 = 100;

        p10 = 100;
        p11 = 100;
        p12 = 100;

        p20 = 100;
        p21 = 100;
        p22 = 100;

        #10;

        $display("TEST 1");
        $display("Expected = 0");
        $display("Result   = %d", result);


        if (result == 0)
            $display("PASS");
        else
            $display("FAIL");


        // ========================================================
        // TEST 2
        //
        // Vertical edge
        //
        // Left side  = 0
        // Right side = 255
        //
        // Gx = 255 + 2*255 + 255
        //    = 1020
        //
        // Gy = 0
        //
        // magnitude = 1020
        //
        // Output is clamped to 255
        // ========================================================

        p00 = 0;
        p01 = 0;
        p02 = 255;

        p10 = 0;
        p11 = 0;
        p12 = 255;

        p20 = 0;
        p21 = 0;
        p22 = 255;

        #10;

        $display("TEST 2");
        $display("Expected = 255");
        $display("Result   = %d", result);


        if (result == 255)
            $display("PASS");
        else
            $display("FAIL");


        // ========================================================
        // TEST 3
        //
        // Horizontal edge
        //
        // Top    = 0
        // Bottom = 255
        //
        // Gy = 255 + 2*255 + 255
        //    = 1020
        //
        // Gx = 0
        //
        // Output = 255 after clamping
        // ========================================================

        p00 = 0;
        p01 = 0;
        p02 = 0;

        p10 = 0;
        p11 = 0;
        p12 = 0;

        p20 = 255;
        p21 = 255;
        p22 = 255;

        #10;

        $display("TEST 3");
        $display("Expected = 255");
        $display("Result   = %d", result);


        if (result == 255)
            $display("PASS");
        else
            $display("FAIL");


        // ========================================================
        // TEST 4
        //
        // Simple vertical gradient
        //
        // Left column = 10
        // Middle      = 10
        // Right       = 20
        //
        // Gx = -10 + 20
        //    + -20 + 40
        //    + -10 + 20
        //
        // Gx = 40
        //
        // Gy = 0
        //
        // Output = 40
        // ========================================================

        p00 = 10;
        p01 = 10;
        p02 = 20;

        p10 = 10;
        p11 = 10;
        p12 = 20;

        p20 = 10;
        p21 = 10;
        p22 = 20;

        #10;

        $display("TEST 4");
        $display("Expected = 40");
        $display("Result   = %d", result);


        if (result == 40)
            $display("PASS");
        else
            $display("FAIL");


        // ========================================================
        // TEST 5
        //
        // Random example
        // ========================================================

        p00 = 20;
        p01 = 30;
        p02 = 40;

        p10 = 50;
        p11 = 60;
        p12 = 70;

        p20 = 80;
        p21 = 90;
        p22 = 100;

        #10;

        $display("TEST 5");
        $display("Input:");
        $display("%d %d %d", p00, p01, p02);
        $display("%d %d %d", p10, p11, p12);
        $display("%d %d %d", p20, p21, p22);

        $display("Result = %d", result);


        // ========================================================
        // END
        // ========================================================

        #10;

        $display("----------------------------------");
        $display("SIMULATION COMPLETE");
        $display("----------------------------------");

        $finish;

    end

endmodule
