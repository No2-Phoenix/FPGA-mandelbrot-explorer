//===============================
// File: mandelbrot_core.v
// Function: Mandelbrot iteration core (1 iter / clk)
// Fixed-point: signed Q(FP_W-FRAC).FRAC
//===============================
module mandelbrot_core #(
    parameter integer FP_W  = 32,
    parameter integer FRAC  = 24
)(
    input                       clk,
    input                       rst_n,

    input                       start,
    input      signed [FP_W-1:0] c_re,
    input      signed [FP_W-1:0] c_im,
    input      [7:0]            max_iter,

    output reg                  busy,
    output reg                  done,
    output reg [7:0]            iter_count
);

    // z = 0
    reg signed [FP_W-1:0] z_re, z_im;
    reg signed [FP_W-1:0] c_re_r, c_im_r;
    reg [7:0] iter;

    // Multiplication helpers
    function signed [FP_W-1:0] fp_mul;
        input signed [FP_W-1:0] a;
        input signed [FP_W-1:0] b;
        reg   signed [2*FP_W-1:0] p;
        begin
            p = a * b;
            fp_mul = p >>> FRAC;
        end
    endfunction

    // 4.0 in Q format
    wire signed [FP_W-1:0] FOUR_Q = (32'sd4 <<< FRAC);

    // combinational next
    reg signed [FP_W-1:0] z_re2, z_im2, zrzi2;
    reg signed [FP_W-1:0] next_re, next_im;
    reg signed [FP_W-1:0] mag2;

    always @(*) begin
        z_re2  = fp_mul(z_re, z_re);
        z_im2  = fp_mul(z_im, z_im);
        zrzi2  = fp_mul(z_re, z_im);        // z_re*z_im (Q)
        next_re = z_re2 - z_im2 + c_re_r;
        next_im = (zrzi2 <<< 1) + c_im_r;   // 2*z_re*z_im + c_im
        mag2    = z_re2 + z_im2;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy       <= 1'b0;
            done       <= 1'b0;
            iter_count <= 8'd0;
            iter       <= 8'd0;
            z_re       <= {FP_W{1'b0}};
            z_im       <= {FP_W{1'b0}};
            c_re_r     <= {FP_W{1'b0}};
            c_im_r     <= {FP_W{1'b0}};
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                // latch c and start
                busy   <= 1'b1;
                iter   <= 8'd0;
                z_re   <= {FP_W{1'b0}};
                z_im   <= {FP_W{1'b0}};
                c_re_r <= c_re;
                c_im_r <= c_im;
            end else if (busy) begin
                // escape check uses current z (before update)
                if (mag2 > FOUR_Q) begin
                    busy       <= 1'b0;
                    done       <= 1'b1;
                    iter_count <= iter;      // escaped at iter
                end else if (iter >= max_iter) begin
                    busy       <= 1'b0;
                    done       <= 1'b1;
                    iter_count <= max_iter;  // in-set (or reached max)
                end else begin
                    // do one iteration
                    z_re <= next_re;
                    z_im <= next_im;
                    iter <= iter + 8'd1;
                end
            end
        end
    end

endmodule
