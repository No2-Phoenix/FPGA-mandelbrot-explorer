//======================================
// File: mandelbrot_display.v
// Function: Display Controller Adapter
// - Maps 800x600 VGA timing to 600x400 Framebuffer
// - Centers the image
// - Handles Palette lookup
//======================================
module mandelbrot_display #(
    parameter integer W = 600,       // Image Width
    parameter integer H = 400,       // Image Height
    parameter integer SCREEN_W = 800,// Screen Width
    parameter integer SCREEN_H = 600,// Screen Height
    parameter integer ADDR_W = 19    // Framebuffer Address Width
)(
    input                    clk,
    input                    rst_n,

    // from lcd_driver (VGA timing)
    input                    lcd_de,       // Data Enable
    input      [10:0]        pixel_xpos,   // Current X
    input      [9:0]         pixel_ypos,   // Current Y

    // framebuffer select (Not used here, handled in top level address mux)
    input                    rd_buf_sel,

    // framebuffer read port
    output reg [ADDR_W-1:0]  rd_addr,
    input      [7:0]         rd_data,      // Data from BRAM (Latency assumed)

    // palette control
    input      [7:0]         max_iter,
    input      [1:0]         pal_mode,

    output reg [23:0]        pixel_data
);

    //-------------------------------------------------------
    // 1. Coordinate Calculation (Centering)
    //-------------------------------------------------------
    // Calculate margins
    localparam X_START = (SCREEN_W - W) >> 1; // 100
    localparam Y_START = (SCREEN_H - H) >> 1; // 100
    localparam X_END   = X_START + W;        // 700
    localparam Y_END   = Y_START + H;        // 500

    // Check if current pixel is within the image area
    wire in_box;
    assign in_box = (pixel_xpos > X_START && pixel_xpos <= X_END) &&
                    (pixel_ypos > Y_START && pixel_ypos <= Y_END);

    // Calculate Image Coordinates (0-based)
    // If pixel_xpos is 1-based (1..800), then pixel_xpos - 1 - X_START
    // If pixel_xpos is 0-based (0..799), then pixel_xpos - X_START
    // Assuming 1-based input from typical driver logic in this project context
    wire [10:0] img_x = (pixel_xpos > X_START) ? (pixel_xpos - 11'd1 - X_START) : 11'd0;
    wire [9:0]  img_y = (pixel_ypos > Y_START) ? (pixel_ypos - 10'd1 - Y_START) : 10'd0;

    //-------------------------------------------------------
    // 2. Address Generation
    //-------------------------------------------------------
    // Address = img_y * W + img_x
    wire [ADDR_W-1:0] next_addr;
    assign next_addr = (img_y * W) + img_x;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_addr <= {ADDR_W{1'b0}};
        end else begin
            // If inside the box, output the calculated address
            if (in_box)
                rd_addr <= next_addr;
            else
                rd_addr <= {ADDR_W{1'b0}};
        end
    end

    //-------------------------------------------------------
    // 3. Palette Instantiation
    //-------------------------------------------------------
    wire [23:0] pal_rgb;
    
    palette u_pal(
        .iter(rd_data),
        .max_iter(max_iter),
        .mode(pal_mode),
        .rgb(pal_rgb)
    );

    //-------------------------------------------------------
    // 4. Output Logic (Pipeline alignment)
    //-------------------------------------------------------
    // Delay in_box to match BRAM latency (2 cycles assumed: 1 for BRAM reg, 1 for output reg)
    reg in_box_d1, in_box_d2;
    
    always @(posedge clk) begin
        in_box_d1 <= in_box;
        in_box_d2 <= in_box_d1;
        
        if (in_box_d2) 
            pixel_data <= pal_rgb;
        else 
            pixel_data <= 24'd0; // Black border
    end

endmodule
