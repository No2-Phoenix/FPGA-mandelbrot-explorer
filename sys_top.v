//======================================
// File: sys_top.v
// Function: Top level for Mandelbrot Zoomer (Zynq 7020 BRAM Version)
// Control Scheme: 3-Button Mode Based
// - Key 1 (Mode): Switch Mode (Zoom -> Pan X -> Pan Y -> Iter)
// - Key 2 (Inc):  Zoom In / Right / Up / Iter+
// - Key 3 (Dec):  Zoom Out / Left / Down / Iter-
//======================================
module sys_top (
    input        sys_clk,      // System Clock (50MHz)
    input        rst_n,        // Reset (Active Low)

    // 3 User Keys (Active Low)
    input        key_mode,     // Switch Control Mode
    input        key_inc,      // Increase / Action A
    input        key_dec,      // Decrease / Action B

    // LCD/VGA Interface
    output       lcd_clk,
    output       lcd_hs,
    output       lcd_vs,
    output       lcd_de,
    output [23:0] lcd_rgb,
    output       lcd_bl        // Backlight
);

    //-------------------------------------------------------
    // 1. Clock Generation
    //-------------------------------------------------------
    wire clk_core;   // 100MHz for calculation
    wire clk_pixel;  // 50MHz for display
    wire locked;
    
    clk_wiz_0 u_pll (
        .clk_out1(clk_core), // 100MHz output
        .reset(!rst_n),      // PLL reset is Active High
        .locked(locked),
        .clk_in1(sys_clk)    // 50MHz input
    );

    assign clk_pixel = sys_clk; 
    wire sys_rst_n = rst_n & locked;

    //-------------------------------------------------------
    // 2. Key Processing (3 Keys)
    //-------------------------------------------------------
    wire [2:0] key_in = {key_dec, key_inc, key_mode};
    wire [2:0] key_db;
    wire [2:0] key_pulse; // [2]Dec, [1]Inc, [0]Mode

    genvar k;
    generate
        for(k=0; k<3; k=k+1) begin : KEYS
            SwitchDebounce u_db (
                .clk(clk_core), .rst_n(sys_rst_n), .sw(key_in[k]), .db_sw(key_db[k])
            );
            edge_detect u_edge (
                .clk(clk_core), .rst_n(sys_rst_n), .level(key_db[k]), .type(1'b0), // Falling edge (press)
                .tick(key_pulse[k])
            );
        end
    endgenerate

    //-------------------------------------------------------
    // 3. Parameter Control & State Machine
    //-------------------------------------------------------
    parameter FP_W = 32;
    
    // Control Modes
    localparam MODE_ZOOM  = 3'd0;
    localparam MODE_PAN_X = 3'd1;
    localparam MODE_PAN_Y = 3'd2;
    localparam MODE_ITER  = 3'd3;
    localparam MODE_COLOR = 3'd4;

    reg [2:0] ctrl_mode; // Current Control Mode

    reg signed [FP_W-1:0] center_re, center_im;
    reg signed [FP_W-1:0] scale;
    reg [7:0] max_iter;
    
    // Palette Mode
    reg [1:0] pal_mode; 

    reg start_render;
    reg first_start;

    // Initial values
    localparam signed [31:0] INIT_SCALE = 32'd50331; // ~0.003
    localparam signed [31:0] INIT_RE    = -32'd12582912; // -0.75
    localparam signed [31:0] INIT_IM    = 32'd0;

    always @(posedge clk_core or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            center_re <= INIT_RE;
            center_im <= INIT_IM;
            scale     <= INIT_SCALE;
            max_iter  <= 8'd128;
            pal_mode  <= 2'd0;
            ctrl_mode <= MODE_ZOOM;
            start_render <= 1'b0;
            first_start <= 1'b0;
        end else begin
            start_render <= 1'b0; // Pulse

            // Auto start
            if (!first_start) begin
                start_render <= 1'b1;
                first_start <= 1'b1;
            end

            // --- Mode Switch (Key 0) ---
            if (key_pulse[0]) begin
                if (ctrl_mode == MODE_COLOR)
                    ctrl_mode <= MODE_ZOOM;
                else
                    ctrl_mode <= ctrl_mode + 1'b1;
            end

            // --- Action Keys (Key 1: Inc/Pos, Key 2: Dec/Neg) ---
            if (key_pulse[1] || key_pulse[2]) begin
                case (ctrl_mode)
                    MODE_ZOOM: begin
                        if (key_pulse[1]) // Inc Key -> Zoom In (Scale Down)
                            scale <= scale - (scale >>> 2);
                        else              // Dec Key -> Zoom Out (Scale Up)
                            scale <= scale + (scale >>> 2);
                        start_render <= 1'b1;
                    end
                    MODE_PAN_X: begin
                        if (key_pulse[1]) // Inc Key -> Right
                            center_re <= center_re + (32'd100 * scale);
                        else              // Dec Key -> Left
                            center_re <= center_re - (32'd100 * scale);
                        start_render <= 1'b1;
                    end
                    MODE_PAN_Y: begin
                        if (key_pulse[1]) // Inc Key -> Up
                            center_im <= center_im + (32'd100 * scale);
                        else              // Dec Key -> Down
                            center_im <= center_im - (32'd100 * scale);
                        start_render <= 1'b1;
                    end
                    MODE_ITER: begin
                        if (key_pulse[1]) // Inc Key -> More Iter
                            max_iter <= max_iter + 8'd16;
                        else              // Dec Key -> Less Iter
                            max_iter <= max_iter - 8'd16;
                        start_render <= 1'b1;
                    end
                    MODE_COLOR: begin
                        if (key_pulse[1]) // Inc Key -> Next Color
                            pal_mode <= pal_mode + 1'b1;
                        else              // Dec Key -> Prev Color
                            pal_mode <= pal_mode - 1'b1;
                    end
                endcase
            end
        end
    end

    //-------------------------------------------------------
    // 4. Render Controller
    //-------------------------------------------------------
    wire [18:0] wr_addr;
    wire [7:0]  wr_data;
    wire        wr_en;
    wire        render_busy, render_done;
    reg         wr_buf_sel; 

    always @(posedge clk_core or negedge sys_rst_n) begin
        if(!sys_rst_n) wr_buf_sel <= 1'b0;
        else if(render_done) wr_buf_sel <= ~wr_buf_sel;
    end

    mandelbrot_render_ctrl #(
        .W(600), .H(400), .ADDR_W(19), .CORE_NUM(8)
    ) u_render (
        .clk(clk_core),
        .rst_n(sys_rst_n),
        .start(start_render),
        .wr_buf_sel(wr_buf_sel),
        .center_re(center_re),
        .center_im(center_im),
        .scale(scale),
        .max_iter(max_iter),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .busy(render_busy),
        .done(render_done)
    );

    //-------------------------------------------------------
    // 5. Frame Buffer (BRAM)
    //-------------------------------------------------------
    wire [18:0] rd_addr;
    wire [7:0]  rd_data;
    wire        rd_buf_sel = ~wr_buf_sel; 

    frame_buffer_dual #(
        .ADDR_WIDTH(19)
    ) u_vram (
        .clk_wr_i(clk_core),
        .clk_rd_i(clk_pixel),
        .wr_addr_i(wr_addr),
        .wr_data_i(wr_data),
        .wr_en_i(wr_en),
        .wr_buf_sel_i(wr_buf_sel),
        .rd_addr_i(rd_addr),
        .rd_buf_sel_i(rd_buf_sel),
        .rd_data_o(rd_data)
    );

    //-------------------------------------------------------
    // 6. Display Controller
    //-------------------------------------------------------
    wire [10:0] lcd_x;
    wire [9:0]  lcd_y;
    wire        lcd_de_int;

    lcd_driver u_driver (
        .lcd_pclk(clk_pixel),
        .rst_n(sys_rst_n),
        .pixel_data(24'd0),
        .lcd_hs(lcd_hs),
        .lcd_vs(lcd_vs),
        .lcd_de(lcd_de_int),
        .lcd_rgb(), 
        .lcd_bl(),
        .pixel_xpos(lcd_x),
        .pixel_ypos(lcd_y)
    );
    
    assign lcd_de = lcd_de_int;
    assign lcd_clk = clk_pixel;
    assign lcd_bl  = 1'b1;

    mandelbrot_display #(
        .W(600), .H(400), .SCREEN_W(800), .SCREEN_H(600), .ADDR_W(19)
    ) u_display (
        .clk(clk_pixel),
        .rst_n(sys_rst_n),
        .lcd_de(lcd_de_int),
        .pixel_xpos(lcd_x),
        .pixel_ypos(lcd_y),
        .rd_buf_sel(rd_buf_sel),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .max_iter(max_iter),
        .pal_mode(pal_mode),
        .pixel_data(lcd_rgb)
    );

endmodule
