`timescale 1ns/1ps
module tb_window_gen_3x3;

    localparam int IMG_W = 28, IMG_H = 28, DW = 8, PAR = 8;

    logic clk = 0;
    logic rst_n = 0;
    logic wr_en = 0;
    logic [$clog2(IMG_W*IMG_H)-1:0] wr_addr = 0;
    logic [DW-1:0] wr_data = 0;
    logic start = 0;

    logic busy, done;
    logic [DW-1:0] win_out [PAR][9];
    logic [PAR-1:0] win_valid;
    logic [$clog2(IMG_H-2)-1:0] row_o;
    logic [$clog2(IMG_W-2)-1:0] col_base_o;

    window_gen_3x3 #(.IMG_W(IMG_W), .IMG_H(IMG_H), .DW(DW), .PAR(PAR)) dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data),
        .start(start), .busy(busy), .done(done),
        .win_out(win_out), .win_valid(win_valid),
        .row_o(row_o), .col_base_o(col_base_o)
    );

    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        #20 rst_n = 1;

        // Load image: pixel value = (r*IMG_W + c) & 0xFF
        for (int r = 0; r < IMG_H; r++) begin
            for (int c = 0; c < IMG_W; c++) begin
                @(posedge clk);
                wr_en   = 1;
                wr_addr = r*IMG_W + c;
                wr_data = (r*IMG_W + c) & 8'hFF;
            end
        end
        @(posedge clk);
        wr_en = 0;

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Print the first few cycles: row, col_base, per-lane valid,
        // and every lane's 9 pixels (much easier to read than the
        // flattened-bus version thanks to the 2D array port).
        for (int cyc = 0; cyc < 5; cyc++) begin
            @(posedge clk);
            #1;
            $display("---- cyc=%0d row=%0d col_base=%0d valid=%b ----",
                       cyc, row_o, col_base_o, win_valid);
            for (int k = 0; k < PAR; k++) begin
                $display("  lane%0d: %0d %0d %0d / %0d %0d %0d / %0d %0d %0d",
                          k,
                          win_out[k][0], win_out[k][1], win_out[k][2],
                          win_out[k][3], win_out[k][4], win_out[k][5],
                          win_out[k][6], win_out[k][7], win_out[k][8]);
            end
        end

        wait(done);
        @(posedge clk);
        $display("done pulse observed -- full 28x28 scan complete");

        #20 $finish;
    end

endmodule
