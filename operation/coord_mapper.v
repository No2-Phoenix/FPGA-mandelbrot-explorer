//===============================
// File: coord_mapper.v
// Function: map (x,y) to complex c (fixed-point)
// c_re = center_re + (x - W/2)*scale
// c_im = center_im + (y - H/2)*scale
//===============================
module coord_mapper #(
    parameter integer FP_W  = 32,
    parameter integer FRAC  = 24,
    parameter integer W     = 1024,
    parameter integer H     = 600
)(
    input      [10:0]          x,   // 0..W-1
    input      [9:0]           y,   // 0..H-1
    input      signed [FP_W-1:0] center_re,
    input      signed [FP_W-1:0] center_im,
    input      signed [FP_W-1:0] scale,       // Q format step per pixel
    output reg signed [FP_W-1:0] c_re,
    output reg signed [FP_W-1:0] c_im
);

    // signed pixel offsets
    wire signed [12:0] dx = $signed({1'b0, x}) - $signed(W/2);
    wire signed [11:0] dy = $signed({1'b0, y}) - $signed(H/2);

    // dx*scale, dy*scale (scale is Q; dx is integer)
    wire signed [FP_W+13-1:0] mul_re = $signed(dx) * $signed(scale);
    wire signed [FP_W+12-1:0] mul_im = $signed(dy) * $signed(scale);

    always @(*) begin
        c_re = center_re + (mul_re >>> 0); // mul already in Q (dx is int)
        c_im = center_im + (mul_im >>> 0);
    end

endmodule
