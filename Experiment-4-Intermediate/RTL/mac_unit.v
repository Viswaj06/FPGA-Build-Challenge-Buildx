module mac_unit #(
    parameter BITWIDTH = 8
)(
    input clk,
    input rst,

    input [BITWIDTH-1:0] p00, p01, p02,
    input [BITWIDTH-1:0] p10, p11, p12,
    input [BITWIDTH-1:0] p20, p21, p22,

    output reg [BITWIDTH-1:0] result
);

    // Gx and Gy need extra bits because
    // the result can be negative and > 255
    wire signed [BITWIDTH+2:0] gx;
    wire signed [BITWIDTH+2:0] gy;

    wire [BITWIDTH+2:0] abs_gx;
    wire [BITWIDTH+2:0] abs_gy;

    wire [BITWIDTH+3:0] magnitude;


    // -------------------------
    // Sobel Gx
    // -------------------------

    assign gx = -p00 + p02
              - 2*p10 + 2*p12
              - p20 + p22;


    // -------------------------
    // Sobel Gy
    // -------------------------

    assign gy = -p00 - 2*p01 - p02
              + p20 + 2*p21 + p22;


    // -------------------------
    // Absolute values
    // -------------------------

    assign abs_gx = (gx < 0) ? -gx : gx;
    assign abs_gy = (gy < 0) ? -gy : gy;


    // -------------------------
    // Sobel magnitude
    // |Gx| + |Gy|
    // -------------------------

    assign magnitude = abs_gx + abs_gy;


    // -------------------------
    // Output register
    // -------------------------

    always @(posedge clk)
    begin
        if (rst)
            result <= 0;
        else if (magnitude > 255)
            result <= 8'd255;
        else
            result <= magnitude[BITWIDTH-1:0];
    end

endmodule