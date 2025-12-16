//=================//
// ModuleName :frame_buffer_dual
// Function   :Dual Buffer Video Memory (Using BRAM IP)
// Author     :No.2
// Date       :2025/12/16
//=================//

module frame_buffer_dual #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 19   // 2^19 = 524288 > 480000 (600*400*2)
)(
    input                         clk_wr_i,       // Write Clock (System Clock)
    input                         clk_rd_i,       // Read Clock (Pixel Clock)

    // Write Port (from Render Ctrl)
    input      [ADDR_WIDTH-1:0]   wr_addr_i,      // 0 ~ 239999
    input      [DATA_WIDTH-1:0]   wr_data_i,
    input                         wr_en_i,
    input                         wr_buf_sel_i,   // 0: Write buf0 | 1: Write buf1

    // Read Port (to VGA/HDMI)
    input      [ADDR_WIDTH-1:0]   rd_addr_i,      // 0 ~ 239999
    input                         rd_buf_sel_i,   // 0: Read buf0 | 1: Read buf1
    output     [DATA_WIDTH-1:0]   rd_data_o
);

    // Offset for Buffer 1 (600 * 400 = 240000)
    localparam [ADDR_WIDTH-1:0] BUF_OFFSET = 19'd240000;

    // Address Calculation
    wire [ADDR_WIDTH-1:0] final_wr_addr;
    wire [ADDR_WIDTH-1:0] final_rd_addr;

    assign final_wr_addr = (wr_buf_sel_i) ? (wr_addr_i + BUF_OFFSET) : wr_addr_i;
    assign final_rd_addr = (rd_buf_sel_i) ? (rd_addr_i + BUF_OFFSET) : rd_addr_i;

    // BRAM IP Instantiation
    blk_mem_gen_0 u_vram (
      .clka(clk_wr_i),    // input wire clka
      .ena(1'b1),         // input wire ena (Always enabled)
      .wea(wr_en_i),      // input wire [0 : 0] wea
      .addra(final_wr_addr),  // input wire [18 : 0] addra
      .dina(wr_data_i),   // input wire [7 : 0] dina
      .douta(),           // output wire [7 : 0] douta (Unused)
      
      .clkb(clk_rd_i),    // input wire clkb
      .enb(1'b1),         // input wire enb (Always enabled)
      .web(1'b0),         // input wire [0 : 0] web (Read only)
      .addrb(final_rd_addr),  // input wire [18 : 0] addrb
      .dinb(8'd0),        // input wire [7 : 0] dinb (Unused)
      .doutb(rd_data_o)   // output wire [7 : 0] doutb
    );

endmodule
