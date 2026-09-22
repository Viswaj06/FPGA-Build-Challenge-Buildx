module fpga_top #(
    parameter int IMG_W        = 28,
    parameter int IMG_H        = 28,
    parameter int PIXEL_WIDTH  = 8,    // pixel / window data width
    parameter int OUTPUT_WIDTH = 8,    // compute_top result width
    parameter int PAR          = 8     // parallel windows / MAC lanes
)(
    input  logic clk,
    input  logic rst_n,                // active-low async reset (source of truth)

    // ---- image load interface (random access write into window_gen_3x3) ----
    input  logic wr_en,
    input  logic [$clog2(IMG_W*IMG_H)-1:0] wr_addr,
    input  logic [PIXEL_WIDTH-1:0]         wr_data,

    // ---- scan control ----
    input  logic start,     // pulse to begin a full image scan
    output logic busy,      // scan in progress
    output logic done,      // pulses 1 cycle when scan completes

    // ---- window generator position outputs (debug / downstream use) ----
    output logic [$clog2(IMG_H-2)-1:0] row_o,
    output logic [$clog2(IMG_W-2)-1:0] col_base_o,

    // ---- live per-cycle compute outputs (still available, still ephemeral) ----
    output logic [OUTPUT_WIDTH-1:0] pixel_out [PAR],
    output logic [PAR-1:0]          output_valid,

    // ---- buffered result readback: every group, addressable after done ----
    // (TOTAL_GROUPS computed inline here since it must be known in the
    // port list; the same value is recomputed as a localparam below for
    // use in the module body.)
    input  logic [$clog2((IMG_H-2) * (((IMG_W-2)+PAR-1)/PAR))-1:0] buf_rd_addr,
    output logic [PAR*OUTPUT_WIDTH-1:0]                            buf_rd_data
);

    localparam int OUT_W          = IMG_W - 2;
    localparam int OUT_H          = IMG_H - 2;
    localparam int GROUPS_PER_ROW = (OUT_W + PAR - 1) / PAR;   // ceil division
    localparam int TOTAL_GROUPS   = OUT_H * GROUPS_PER_ROW;

    // Active-high reset derived from the active-low source, for compute_top.
    logic rst;
    assign rst = ~rst_n;

    // ---------------------------------------------------------------
    // Wires between window_gen_3x3 and compute_top
    // ---------------------------------------------------------------
    logic [PIXEL_WIDTH-1:0] win [PAR][9];
    logic [PAR-1:0]         win_valid;

    // ---------------------------------------------------------------
    // Window generator
    // ---------------------------------------------------------------
    window_gen_3x3 #(
        .IMG_W (IMG_W),
        .IMG_H (IMG_H),
        .DW    (PIXEL_WIDTH),
        .PAR   (PAR)
    ) u_window_gen (
        .clk        (clk),
        .rst_n      (rst_n),

        .wr_en      (wr_en),
        .wr_addr    (wr_addr),
        .wr_data    (wr_data),

        .start      (start),
        .busy       (busy),
        .done       (done),

        .win_out    (win),
        .win_valid  (win_valid),
        .row_o      (row_o),
        .col_base_o (col_base_o)
    );

    // ---------------------------------------------------------------
    // Compute pipeline (PAR MAC lanes)
    // ---------------------------------------------------------------
    compute_top #(
        .PIXEL_WIDTH  (PIXEL_WIDTH),
        .OUTPUT_WIDTH (OUTPUT_WIDTH),
        .PAR          (PAR)
    ) u_compute_top (
        .clk           (clk),
        .rst           (rst),

        .win_in        (win),
        .window_valid  (win_valid),

        .pixel_out     (pixel_out),
        .output_valid  (output_valid)
    );

    // ---------------------------------------------------------------
    // One-cycle delay to align busy/row_o/col_base_o (combinational,
    // describing the window on THIS cycle's inputs) with pixel_out
    // (registered, describing LAST cycle's inputs -- mac_unit latency).
    // ---------------------------------------------------------------
    logic                               busy_q;
    logic [$clog2(IMG_H-2)-1:0]         row_o_q;
    logic [$clog2(IMG_W-2)-1:0]         col_base_o_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_q       <= 1'b0;
            row_o_q      <= '0;
            col_base_o_q <= '0;
        end else begin
            busy_q       <= busy;
            row_o_q      <= row_o;
            col_base_o_q <= col_base_o;
        end
    end

    // Buffer write address: flatten (row, col_base) into a group index.
    // row_o_q/col_base_o_q are 1-indexed (see window_gen_3x3), so
    // subtract 1 back to 0-indexed row/col_base before computing.
    logic [$clog2(TOTAL_GROUPS)-1:0] buf_wr_addr;
    assign buf_wr_addr = (row_o_q - 1) * GROUPS_PER_ROW
                        + (col_base_o_q - 1) / PAR;

    // Pack all PAR lanes into one word per group. Written manually
    // (rather than a loop-based concat) since PAR=8 is hardcoded
    // throughout compute_top already.
    logic [PAR*OUTPUT_WIDTH-1:0] buf_wr_data;
    assign buf_wr_data = { pixel_out[7], pixel_out[6], pixel_out[5], pixel_out[4],
                           pixel_out[3], pixel_out[2], pixel_out[1], pixel_out[0] };

    // ---------------------------------------------------------------
    // Output buffer: captures every group before it's overwritten
    // ---------------------------------------------------------------
    output_buffer #(
        .TOTAL_GROUPS (TOTAL_GROUPS),
        .PAR          (PAR),
        .DATA_W       (OUTPUT_WIDTH)
    ) u_output_buffer (
        .clk     (clk),
        .rst_n   (rst_n),

        .wr_en   (busy_q),
        .wr_addr (buf_wr_addr),
        .wr_data (buf_wr_data),

        .rd_addr (buf_rd_addr),
        .rd_data (buf_rd_data)
    );

endmodule
