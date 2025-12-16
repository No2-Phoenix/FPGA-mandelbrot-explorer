//===============================
// File: palette.v
// Function: map iter_count to RGB888
// mode 0/1/2/3: different simple palettes
//===============================
module palette(
    input      [7:0] iter,
    input      [7:0] max_iter,
    input      [1:0] mode,
    output reg [23:0] rgb
);
    reg [7:0] r, g, b;

    always @(*) begin
        if (iter >= max_iter) begin
            // inside set
            r = 8'd0; g = 8'd0; b = 8'd0;
        end else begin
            case (mode)
                2'd0: begin
                    r = iter * 8'd5;
                    g = iter * 8'd13;
                    b = iter * 8'd29;
                end
                2'd1: begin
                    r = iter * 8'd9;
                    g = iter * 8'd3;
                    b = iter * 8'd17;
                end
                2'd2: begin
                    r = (iter << 2);
                    g = (iter << 1);
                    b = (iter * 8'd11);
                end
                default: begin
                    r = (iter * 8'd7);
                    g = (iter * 8'd21);
                    b = (iter * 8'd4);
                end
            endcase
        end
        rgb = {r,g,b};
    end
endmodule
