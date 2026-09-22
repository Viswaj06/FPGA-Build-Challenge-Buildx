// =====================================================================
// tb_fpga_top.sv
// Self-checking testbench for fpga_top (window_gen_3x3 + compute_top).
//
// Loads a known test image, runs a full scan, and checks every
// pixel_out value that streams out against a golden model of the
// real Sobel-magnitude mac_unit (|Gx| + |Gy|, saturated to 255).
//
// Compile this against your real mac_unit.sv -- do NOT also compile
// mac_unit_stub.sv, it defines a module with the same name and will
// conflict.
//
// IMG_W/IMG_H are deliberately chosen (12 x 7) so that OUT_W and OUT_H
// are NOT exact powers of two. window_gen_3x3's row_o/col_base_o
// output ports are sized as $clog2(IMG_H-2) / $clog2(IMG_W-2), but the
// values driven onto them are (row+1)/(col_base+1) -- one bit wider
// than that in the worst case. When OUT_H or OUT_W is an exact power
// of two, the max row_o/col_base_o value silently truncates (e.g.
// IMG_H=6 -> OUT_H=4 -> row_o's max value of 4 wraps to 0 in a 2-bit
// field). That's a pre-existing sizing quirk in window_gen_3x3 itself,
// not something this testbench works around in the DUT -- the
// parameters below just avoid tripping it so a mismatch you see here
// is a real datapath bug, not a debug-port truncation artifact. Widen
// row_o/col_base_o (e.g. $clog2(IMG_H-1)) if you need it to hold for
// all image sizes.
// =====================================================================

//`timescale 1ns/1ps

module tb_fpga_top;

    // ---------------- parameters ----------------
    localparam int IMG_W        = 12;
    localparam int IMG_H        = 7;
    localparam int PIXEL_WIDTH  = 8;
    localparam int OUTPUT_WIDTH = 8;
    localparam int PAR          = 8;
    localparam int OUT_W        = IMG_W - 2;   // 10
    localparam int OUT_H        = IMG_H - 2;   // 5

    // ---------------- DUT signals ----------------
    logic clk, rst_n;
    logic wr_en;
    logic [$clog2(IMG_W*IMG_H)-1:0] wr_addr;
    logic [PIXEL_WIDTH-1:0]         wr_data;
    logic start, busy, done;
    logic [$clog2(IMG_H-2)-1:0] row_o;
    logic [$clog2(IMG_W-2)-1:0] col_base_o;
    logic [OUTPUT_WIDTH-1:0] pixel_out [PAR];
    logic [PAR-1:0]          output_valid;

    // ---------------- clock ----------------
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    // ---------------- DUT ----------------
    fpga_top #(
        .IMG_W        (IMG_W),
        .IMG_H        (IMG_H),
        .PIXEL_WIDTH  (PIXEL_WIDTH),
        .OUTPUT_WIDTH (OUTPUT_WIDTH),
        .PAR          (PAR)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .wr_en        (wr_en),
        .wr_addr      (wr_addr),
        .wr_data      (wr_data),
        .start        (start),
        .busy         (busy),
        .done         (done),
        .row_o        (row_o),
        .col_base_o   (col_base_o),
        .pixel_out    (pixel_out),
        .output_valid (output_valid)
    );

    // ---------------- reference image (testbench-side model) ----------------
    logic [PIXEL_WIDTH-1:0] img [0:IMG_H-1][0:IMG_W-1];

    initial begin
        for (int r = 0; r < IMG_H; r++)
            for (int c = 0; c < IMG_W; c++)
                img[r][c] = (r*IMG_W + c) % 256;
    end

    // ---------------- golden model ----------------
    // Matches the real mac_unit: Sobel Gx/Gy convolution, magnitude
    // approximated as |Gx| + |Gy|, saturated to OUTPUT_WIDTH bits.
    function automatic [OUTPUT_WIDTH-1:0] expected_result(int r, int c);
        int signed p00, p01, p02, p10, p11, p12, p20, p21, p22;
        int signed gx, gy;
        int abs_gx, abs_gy, magnitude;

        p00 = img[r+0][c+0]; p01 = img[r+0][c+1]; p02 = img[r+0][c+2];
        p10 = img[r+1][c+0]; p11 = img[r+1][c+1]; p12 = img[r+1][c+2];
        p20 = img[r+2][c+0]; p21 = img[r+2][c+1]; p22 = img[r+2][c+2];

        gx = -p00 + p02 - 2*p10 + 2*p12 - p20 + p22;
        gy = -p00 - 2*p01 - p02 + p20 + 2*p21 + p22;

        abs_gx = (gx < 0) ? -gx : gx;
        abs_gy = (gy < 0) ? -gy : gy;
        magnitude = abs_gx + abs_gy;

        expected_result = (magnitude > ((1<<OUTPUT_WIDTH)-1)) ? ((1<<OUTPUT_WIDTH)-1) : magnitude[OUTPUT_WIDTH-1:0];
    endfunction

    // ---------------- tasks ----------------
    task automatic reset_dut();
        rst_n   = 0;
        wr_en   = 0;
        wr_addr = '0;
        wr_data = '0;
        start   = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
    endtask

    task automatic load_image();
        for (int addr = 0; addr < IMG_W*IMG_H; addr++) begin
            @(posedge clk);
            wr_addr <= addr;
            wr_data <= img[addr / IMG_W][addr % IMG_W];
            wr_en   <= 1'b1;
        end
        @(posedge clk);
        wr_en <= 1'b0;
    endtask

    task automatic run_scan();
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
    endtask

    // ---------------- scoreboard ----------------
    // One-cycle pipe of "what the window extractor saw this cycle", to
    // line up with mac_unit's registered output latency.
    logic [OUTPUT_WIDTH-1:0] exp_pixel_q [PAR];
    logic                    exp_valid_q [PAR];
    logic [OUTPUT_WIDTH-1:0] exp_pixel_d [PAR];
    logic                    exp_valid_d [PAR];

    int errors = 0;
    int checked = 0;
    bit valid_skew_flagged = 0;

    always_comb begin
        int r_idx, c_idx;
        r_idx = int'(row_o) - 1;
        c_idx = int'(col_base_o) - 1;
        for (int k = 0; k < PAR; k++) begin
            if (busy && (c_idx + k) < OUT_W && r_idx < OUT_H && r_idx >= 0) begin
                exp_valid_d[k] = 1'b1;
                exp_pixel_d[k] = expected_result(r_idx, c_idx + k);
            end else begin
                exp_valid_d[k] = 1'b0;
                exp_pixel_d[k] = '0;
            end
        end
    end

    always_ff @(posedge clk) begin
        for (int k = 0; k < PAR; k++) begin
            exp_pixel_q[k] <= exp_pixel_d[k];
            exp_valid_q[k] <= exp_valid_d[k];
        end
    end

    always_ff @(posedge clk) begin
        if (rst_n) begin
            for (int k = 0; k < PAR; k++) begin
                // Check pixel data one cycle after the window that produced it.
                if (exp_valid_q[k]) begin
                    checked++;
                    if (pixel_out[k] !== exp_pixel_q[k]) begin
                        errors++;
                        $display("[%0t] MISMATCH lane %0d: got=%0d expected=%0d",
                                  $time, k, pixel_out[k], exp_pixel_q[k]);
                    end
                end
                // output_valid is wired combinationally to window_valid in
                // compute_top ('assign output_valid = window_valid;'), so it
                // reflects THIS cycle's window, not the cycle whose pixel
                // data mac_unit is registering out right now. Flagged once
                // so the skew isn't missed rather than spamming every cycle.
                if (!valid_skew_flagged && output_valid[k] !== exp_valid_q[k]) begin
                    valid_skew_flagged = 1;
                    $display("[%0t] NOTE: output_valid is not delayed to match pixel_out's registered latency (compute_top: assign output_valid = window_valid;). Consider registering output_valid by mac_unit's latency so it lines up with pixel_out.", $time);
                end
            end
        end
    end

    // ---------------- stimulus ----------------
    initial begin
        reset_dut();
        load_image();
        run_scan();

        wait (done);
        repeat (5) @(posedge clk);   // let the pipeline drain

        if (errors == 0 && checked > 0)
            $display("\nTEST PASSED: %0d pixel values checked, 0 mismatches.", checked);
        else
            $display("\nTEST FAILED: %0d errors out of %0d checked.", errors, checked);

        $finish;
    end

    // safety timeout
    initial begin
        #100000;
        $display("TIMEOUT: scan never completed");
        $finish;
    end

endmodule
