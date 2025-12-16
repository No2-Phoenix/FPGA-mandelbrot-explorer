//===================
// Module   : EdgeDetector
// Function : Detecting the Rising or Falling Edge of the Input Signal
// Author   : No.2
// Date     : 2025/11/23
//===================

module edge_detect(
    input  clk,
    input  rst_n,
    input  level,
    input  type,   // 1 = RISING, 0 = FALLING

    output tick
);

//===========================
// Parameter Definition
//===========================
localparam       TYPE_RISING   = 1'b1;
localparam       TYPE_FALLING  = 1'b0;

localparam       S_INIT = 2'b00;
localparam [1:0] S_BEFORE_EDGE = 2'b01;
localparam [1:0] S_EDGE        = 2'b10;
localparam [1:0] S_AFTER_EDGE  = 2'b11;

//===========================
// Internal Registers
//===========================
reg [1:0] status, status_next;
reg       tick_reg;

//============================
// Sequential Logic
//============================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        status   <= S_INIT;
        tick_reg <= 1'b0;
    end
    else begin
        status   <= status_next;
        tick_reg <= (status_next == S_EDGE); 
    end
end

//============================
// Combinational Logic
//============================
always @* begin
    status_next = status;

    case(type)

        //---------------------------------------------------------
        // Rising Edge
        //---------------------------------------------------------
        TYPE_RISING: begin
            case(status)
                S_INIT:begin
                    if(level)begin
                        status_next = S_AFTER_EDGE;
                    end
                    else begin
                        status_next = S_BEFORE_EDGE;
                    end
                end

                S_BEFORE_EDGE: begin
                    if(level)
                        status_next = S_EDGE;
                end

                S_EDGE: begin
                    if(level)
                        status_next = S_AFTER_EDGE;
                    else
                        status_next = S_BEFORE_EDGE;
                end

                S_AFTER_EDGE: begin
                    if(!level)
                        status_next = S_BEFORE_EDGE;
                end

                default: status_next = S_INIT;

            endcase
        end

        //---------------------------------------------------------
        // Falling Edge
        //---------------------------------------------------------
        TYPE_FALLING: begin
            case(status)

            S_INIT:begin
                if(!level)begin
                    status_next = S_AFTER_EDGE;
                end
                else begin
                    status_next = S_BEFORE_EDGE;
                end
            end

                S_BEFORE_EDGE: begin
                    if(!level)
                        status_next = S_EDGE;
                end

                S_EDGE: begin
                    if(!level)
                        status_next = S_AFTER_EDGE;
                    else
                        status_next = S_BEFORE_EDGE;
                end

                S_AFTER_EDGE: begin
                    if(level)
                        status_next = S_BEFORE_EDGE;
                end

                default: status_next = S_INIT;

            endcase
        end

        default: status_next = S_INIT;

    endcase
end

//=====================
// Output
//=====================
assign tick = tick_reg;

endmodule
