module tb_compute_top;

    parameter PIXEL_WIDTH  = 8;
    parameter OUTPUT_WIDTH = 8;
    parameter PAR          = 8;

    reg clk;
    reg rst;

    always #5 clk = ~clk;

    reg [PIXEL_WIDTH-1:0] win_in [PAR][9];
    reg [PAR-1:0] window_valid;

    wire [OUTPUT_WIDTH-1:0] pixel_out [PAR];
    wire [PAR-1:0] output_valid;

    compute_top #(
        .PIXEL_WIDTH (PIXEL_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH),
        .PAR         (PAR)
    ) dut (
        .clk(clk),
        .rst(rst),
        .win_in(win_in),
        .window_valid(window_valid),
        .pixel_out(pixel_out),
        .output_valid(output_valid)
    );

    initial begin

        clk = 0;
        rst = 1;
        window_valid = 8'b0;

        for (int k = 0; k < PAR; k = k + 1)
            for (int p = 0; p < 9; p = p + 1)
                win_in[k][p] = 0;

        #20;
        rst = 0;

        #10;

        // TEST 1: CONSTANT WINDOWS

        for (int k = 0; k < PAR; k = k + 1)
            for (int p = 0; p < 9; p = p + 1)
                win_in[k][p] = 100;

        window_valid = 8'b11111111;

        @(posedge clk);
        #1;

        $display("----------------------------------------");
        $display("TEST 1: CONSTANT WINDOWS");
        $display("Valid = %b", output_valid);

        $display("Outputs: %d %d %d %d %d %d %d %d",
                 pixel_out[0],
                 pixel_out[1],
                 pixel_out[2],
                 pixel_out[3],
                 pixel_out[4],
                 pixel_out[5],
                 pixel_out[6],
                 pixel_out[7]);

        if ((pixel_out[0] == 0) &&
            (pixel_out[1] == 0) &&
            (pixel_out[2] == 0) &&
            (pixel_out[3] == 0) &&
            (pixel_out[4] == 0) &&
            (pixel_out[5] == 0) &&
            (pixel_out[6] == 0) &&
            (pixel_out[7] == 0))
            $display("PASS");
        else
            $display("FAIL");


        // TEST 2: VERTICAL EDGE

        for (int k = 0; k < PAR; k = k + 1) begin
            win_in[k][0] = 0;
            win_in[k][1] = 0;
            win_in[k][2] = 255;

            win_in[k][3] = 0;
            win_in[k][4] = 0;
            win_in[k][5] = 255;

            win_in[k][6] = 0;
            win_in[k][7] = 0;
            win_in[k][8] = 255;
        end

        window_valid = 8'b11111111;

        @(posedge clk);
        #1;

        $display("----------------------------------------");
        $display("TEST 2: VERTICAL EDGE");
        $display("Valid = %b", output_valid);

        $display("Outputs: %d %d %d %d %d %d %d %d",
                 pixel_out[0],
                 pixel_out[1],
                 pixel_out[2],
                 pixel_out[3],
                 pixel_out[4],
                 pixel_out[5],
                 pixel_out[6],
                 pixel_out[7]);

        if ((pixel_out[0] == 255) &&
            (pixel_out[1] == 255) &&
            (pixel_out[2] == 255) &&
            (pixel_out[3] == 255) &&
            (pixel_out[4] == 255) &&
            (pixel_out[5] == 255) &&
            (pixel_out[6] == 255) &&
            (pixel_out[7] == 255))
            $display("PASS");
        else
            $display("FAIL");


        // TEST 3: DIFFERENT WINDOWS

        for (int p = 0; p < 9; p = p + 1)
            win_in[0][p] = 50;

        win_in[1][0] = 0;
        win_in[1][1] = 0;
        win_in[1][2] = 255;
        win_in[1][3] = 0;
        win_in[1][4] = 0;
        win_in[1][5] = 255;
        win_in[1][6] = 0;
        win_in[1][7] = 0;
        win_in[1][8] = 255;

        win_in[2][0] = 0;
        win_in[2][1] = 0;
        win_in[2][2] = 0;
        win_in[2][3] = 0;
        win_in[2][4] = 0;
        win_in[2][5] = 0;
        win_in[2][6] = 255;
        win_in[2][7] = 255;
        win_in[2][8] = 255;

        for (int p = 0; p < 9; p = p + 1)
            win_in[3][p] = 100;

        win_in[4][0] = 0;
        win_in[4][1] = 0;
        win_in[4][2] = 255;
        win_in[4][3] = 0;
        win_in[4][4] = 0;
        win_in[4][5] = 255;
        win_in[4][6] = 0;
        win_in[4][7] = 0;
        win_in[4][8] = 255;

        win_in[5][0] = 0;
        win_in[5][1] = 0;
        win_in[5][2] = 0;
        win_in[5][3] = 0;
        win_in[5][4] = 0;
        win_in[5][5] = 0;
        win_in[5][6] = 255;
        win_in[5][7] = 255;
        win_in[5][8] = 255;

        for (int p = 0; p < 9; p = p + 1)
            win_in[6][p] = 200;

        win_in[7][0] = 0;
        win_in[7][1] = 0;
        win_in[7][2] = 255;
        win_in[7][3] = 0;
        win_in[7][4] = 0;
        win_in[7][5] = 255;
        win_in[7][6] = 0;
        win_in[7][7] = 0;
        win_in[7][8] = 255;

        window_valid = 8'b11111111;

        @(posedge clk);
        #1;

        $display("----------------------------------------");
        $display("TEST 3: 8 DIFFERENT WINDOWS");
        $display("Valid = %b", output_valid);

        $display("Output 0 = %d", pixel_out[0]);
        $display("Output 1 = %d", pixel_out[1]);
        $display("Output 2 = %d", pixel_out[2]);
        $display("Output 3 = %d", pixel_out[3]);
        $display("Output 4 = %d", pixel_out[4]);
        $display("Output 5 = %d", pixel_out[5]);
        $display("Output 6 = %d", pixel_out[6]);
        $display("Output 7 = %d", pixel_out[7]);

        if ((pixel_out[0] == 0)   &&
            (pixel_out[1] == 255) &&
            (pixel_out[2] == 255) &&
            (pixel_out[3] == 0)   &&
            (pixel_out[4] == 255) &&
            (pixel_out[5] == 255) &&
            (pixel_out[6] == 0)   &&
            (pixel_out[7] == 255))
            $display("PASS");
        else
            $display("FAIL");


        // TEST 4: PARTIAL VALIDITY

        window_valid = 8'b00000011;

        @(posedge clk);
        #1;

        $display("----------------------------------------");
        $display("TEST 4: PARTIAL VALIDITY");
        $display("Valid = %b", output_valid);

        $display("Output 0 = %d", pixel_out[0]);
        $display("Output 1 = %d", pixel_out[1]);


        window_valid = 8'b00000000;

        #10;

        $display("----------------------------------------");
        $display("COMPUTE TOP TESTBENCH COMPLETE");
        $display("----------------------------------------");

        $finish;

    end

endmodule