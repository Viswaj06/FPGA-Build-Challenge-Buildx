// =====================================================================
// output_buffer.sv
//
// fpga_top produces one 8-lane group of pixel_out per clock cycle, but
// pixel_out is just 8 registers reused every cycle -- nothing holds
// onto a group once the next one arrives. This module captures every
// group into a small dual-port memory as it's produced, so software
// can read the entire output map back after 'done' at its own pace
// instead of racing the pipeline.
//
// One word per group (all PAR lanes packed together), since the
// pipeline naturally produces one group per cycle -- this needs only
// a single write port, which maps cleanly onto Block RAM (unlike
// window_gen_3x3's mem, which needs many simultaneous reads and is
// forced into registers instead).
// =====================================================================

module output_buffer #(
    parameter int TOTAL_GROUPS = 104,   // OUT_H * ceil(OUT_W / PAR)
    parameter int PAR          = 8,
    parameter int DATA_W       = 8
)(
    input  logic clk,
    input  logic rst_n,   // unused (BRAM inference wants no reset on mem) -- kept for interface consistency

    // ---- write side: one packed PAR*DATA_W word per valid group ----
    input  logic                            wr_en,
    input  logic [$clog2(TOTAL_GROUPS)-1:0] wr_addr,
    input  logic [PAR*DATA_W-1:0]           wr_data,

    // ---- read side: addressed independently, e.g. by the AXI wrapper ----
    input  logic [$clog2(TOTAL_GROUPS)-1:0] rd_addr,
    output logic [PAR*DATA_W-1:0]           rd_data
);

    // Force Block RAM: at ~TOTAL_GROUPS*PAR*DATA_W/8 bytes (832B default),
    // Vivado's default heuristics may otherwise pick LUTRAM.
    (* ram_style = "block" *)
    logic [PAR*DATA_W-1:0] mem [0:TOTAL_GROUPS-1];

    always_ff @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    // Registered read -- standard BRAM timing (1-cycle latency: present
    // rd_addr one cycle before rd_data is valid).
    always_ff @(posedge clk) begin
        rd_data <= mem[rd_addr];
    end

endmodule
