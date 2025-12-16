// ModuleName:lcd_driver
// Function  :Driving a RGB_LCD
// Author    :No.2
// Date      :2025/11/27
// Model     :1024 * 600 RGB_LCD


module lcd_driver(
    input lcd_pclk,
    input rst_n,
    input [23:0] pixel_data,
    
    output reg lcd_de,
    output [23:0] lcd_rgb,
    output lcd_bl,
    output lcd_hs,
    output lcd_vs,
    output reg [10:0] pixel_xpos,
    output reg [9:0] pixel_ypos
);

//=========Parameter Definition=============
localparam HS_SYNC_NUM = 20;
localparam HS_TRAILING_EDGE_NUM = 140;
localparam HS_DIS_NUM = 1024;
localparam HS_LEADING_EDGE_NUM = 160;
localparam HS_TOTAL_NUM = 1344;
localparam VS_SYNC_NUM = 3;
localparam VS_TRAILING_EDGE_NUM = 20;
localparam VS_DIS_NUM = 600;
localparam VS_LEADING_EDGE_NUM = 12;
localparam VS_TOTAL_NUM = 635;

localparam ROW_FRONT_DELAY = HS_SYNC_NUM + HS_TRAILING_EDGE_NUM;
localparam ROW_BACK_DELAY = HS_LEADING_EDGE_NUM;
localparam COL_FRONT_DELAY = VS_SYNC_NUM + VS_TRAILING_EDGE_NUM;
localparam COL_BACK_DELAY = VS_LEADING_EDGE_NUM;

//=========Internal Signal Declaration=======
reg [10:0] hs_cnt;
reg [9:0] vs_cnt;
wire lcd_de_next;
wire [10:0] pixel_xpos_next;
wire [9:0] pixel_ypos_next;


//===============Counting Part===============
//---------------
// Row Counting Part
//---------------
always @(posedge lcd_pclk or negedge rst_n)begin
    if(!rst_n)begin
        hs_cnt <= 11'd0;
    end
    else if(hs_cnt == HS_TOTAL_NUM - 1)begin
        hs_cnt <= 11'd0;
    end
    else begin
        hs_cnt <= hs_cnt + 11'd1;
    end
end
//--------------
// Column Counting Part
//--------------
always @(posedge lcd_pclk or negedge rst_n)begin
    if(!rst_n)begin
        vs_cnt <= 10'd0;
    end
    else if(vs_cnt == VS_TOTAL_NUM-1)begin
        vs_cnt <= 10'd0;
    end
    else if(hs_cnt == HS_TOTAL_NUM-1)begin
        vs_cnt <= vs_cnt + 10'd1;
    end
    else begin
        vs_cnt <= vs_cnt;
    end
end


//==============Data Enable Part==============
//---------------
// Sequential Logic Control
//---------------
always @(posedge lcd_pclk or negedge rst_n)begin
    if(!rst_n)begin
        lcd_de <= 1'b0;
    end
    else begin
        lcd_de <= lcd_de_next;
    end
end
//-------------
// Combinational Logic Operation
//-------------
assign lcd_de_next = (hs_cnt >= ROW_FRONT_DELAY) && 
                     (hs_cnt < ROW_FRONT_DELAY + HS_DIS_NUM) &&
                     (vs_cnt >= COL_FRONT_DELAY) && 
                     (vs_cnt < COL_FRONT_DELAY + VS_DIS_NUM);


//=========Coordinate Calculation Part=========
always @(posedge lcd_pclk or negedge rst_n)begin
    if(!rst_n)begin
        pixel_xpos <= 11'd0;
    end
    else begin
        pixel_xpos <= pixel_xpos_next;
    end
end

always @(posedge lcd_pclk or negedge rst_n)begin
    if(!rst_n)begin
        pixel_ypos <= 10'd0;
    end
    else begin
        pixel_ypos <= pixel_ypos_next;
    end
end

assign pixel_xpos_next = (hs_cnt >= ROW_FRONT_DELAY && hs_cnt < ROW_FRONT_DELAY + HS_DIS_NUM) ? 
                        (hs_cnt - ROW_FRONT_DELAY + 1) : 11'd0;

assign pixel_ypos_next = (vs_cnt >= COL_FRONT_DELAY && vs_cnt < COL_FRONT_DELAY + VS_DIS_NUM) ? 
                        (vs_cnt - COL_FRONT_DELAY + 1) : 10'd0;


//=========BACK LIGHT=============
//--------------
// Always Light
//--------------
assign lcd_bl = 1'b1;


//==========RGB Data Output========
assign lcd_rgb = lcd_de ? pixel_data : 24'd0;


//==========HS/VS Output===========
assign lcd_hs = 1'b1;
assign lcd_vs = 1'b1;


endmodule 