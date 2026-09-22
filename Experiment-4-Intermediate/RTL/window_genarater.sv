// =====================================================================
// window_gen_3x3.sv
// 3x3 sliding-window generator, no padding.
// - Image is loaded into an internal memory via a simple write port
//   (random access), matching "image already sits in on-chip memory".
// - Each cycle, PAR (default 8) windows are produced in parallel:
//   lane k = the 3x3 window whose top-left corner is (row, col_base+k).
// - col_base steps by PAR each cycle; when it would run off the row,
//   it wraps to 0 and row increments. Lanes that fall outside the
//   valid range (last, partial group of a row) are flagged invalid.
//
// This is a SystemVerilog module (uses real 2D array ports / logic
// types) but is instantiable from, or can instantiate, plain Verilog
// modules without any issue -- SV is a superset of Verilog.
// =====================================================================

module window_gen_3x3 #(
    parameter int IMG_W = 28,
    parameter int IMG_H = 28,
    parameter int DW    = 8,     // pixel data width
    parameter int PAR   = 8      // number of windows produced per cycle
)(
    input  logic  clk,
    input  logic  rst_n,

    // ---- image load interface (random access write) ----
    input  logic  wr_en,
    input  logic [$clog2(IMG_W*IMG_H)-1:0] wr_addr,
    input  logic [DW-1:0] wr_data,

    // ---- control ----
    input  logic  start,   // pulse to begin a full scan
    output logic  busy,
    output logic  done,    // pulses 1 cycle when scan completes

    // ---- window outputs ----
    // win_out[k] = lane k's 3x3 window, row-major:
    //   win_out[k][0] win_out[k][1] win_out[k][2]   <- top row
    //   win_out[k][3] win_out[k][4] win_out[k][5]   <- middle row
    //   win_out[k][6] win_out[k][7] win_out[k][8]   <- bottom row
    output logic [DW-1:0] win_out [PAR][9],
    output logic [PAR-1:0] win_valid,   // per-lane valid
    output logic [$clog2(IMG_H-2)-1:0]row_o,       // window group's top row
    output logic [$clog2(IMG_W-2)-1:0]col_base_o   // lane 0's left column
);

    localparam int WIN   = 3;
    localparam int OUT_W = IMG_W - WIN + 1;   // valid column starts (26 for 28x28)
    localparam int OUT_H = IMG_H - WIN + 1;   // valid row starts    (26 for 28x28)

    // ---------------------------------------------------------------
    // Image memory: register array so PAR*9 reads/cycle are combinational
    // (synthesizes as distributed RAM / LUTRAM on FPGA for this size)
    // ---------------------------------------------------------------
    logic [DW-1:0] mem [0:IMG_W*IMG_H-1];

    always_ff @(posedge clk) begin
        if (wr_en) mem[wr_addr] <= wr_data;
    end

    function automatic int addr(int r, int c);
        return r*IMG_W + c;
    endfunction

    // ---------------------------------------------------------------
    // Scan counters
    // ---------------------------------------------------------------
    logic [$clog2(OUT_H)-1:0] row;
    logic [$clog2(OUT_W)-1:0] col_base;
    logic                     running;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row      <= '0;
            col_base <= '0;
            running  <= 1'b0;
            busy     <= 1'b0;
            done     <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && !running) begin
                running  <= 1'b1;
                busy     <= 1'b1;
                row      <= '0;
                col_base <= '0;
            end else if (running) begin
                if (col_base + PAR >= OUT_W) begin
                    col_base <= '0;
                    if (row == OUT_H-1) begin
                        running <= 1'b0;
                        busy    <= 1'b0;
                        done    <= 1'b1;
                    end else begin
                        row <= row + 1'b1;
                    end
                end else begin
                    col_base <= col_base + PAR;
                end
            end
        end
    end

    // ---------------------------------------------------------------
    // Combinational window extraction: PAR lanes, each a 3x3 read.
    // lane k covers the window whose top-left is (row, col_base+k)
    // ---------------------------------------------------------------
    always_comb begin
        row_o      = row + 1;
        col_base_o = col_base + 1;
        for (int k = 0; k < PAR; k++) begin
            if ((col_base + k) < OUT_W) begin
                win_valid[k] = running;
                for (int i = 0; i < WIN; i++) begin
                    for (int j = 0; j < WIN; j++) begin
                        win_out[k][i*WIN + j] = mem[addr(row+i, col_base+k+j)];
                    end
                end
            end else begin
                win_valid[k] = 1'b0;
                for (int idx = 0; idx < 9; idx++)
                    win_out[k][idx] = '0;
            end
        end
    end

endmodule
