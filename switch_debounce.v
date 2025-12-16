//================
// ModuleName:SwitchDebounce
// Function  :Debouncing the key
// Author    :No.2
// Date      :2025/11/23
//Attention  :The default state of the switch is 1
//================


module SwitchDebounce #(
    parameter [18:0] Timing_cnt_max = 19'd500_000)(
    input clk,
    input rst_n,
    input sw,

    output db_sw
);

//=====================
//Parameter Definition
//=====================
localparam       N              = 19;
localparam [2:0] S_LOW          = 3'b000;
localparam [2:0] S_WAIT_1_1     = 3'b001;
localparam [2:0] S_WAIT_1_2     = 3'b010;
localparam [2:0] S_WAIT_1_3     = 3'b011;
localparam [2:0] S_HIGH         = 3'b100;
localparam [2:0] S_WAIT_0_1     = 3'b101;
localparam [2:0] S_WAIT_0_2     = 3'b110;
localparam [2:0] S_WAIT_0_3     = 3'b111;

//===================
// Internal Signal Declaration
//===================
reg db_sw_reg;
reg db_sw_next;

reg [2:0] state;
reg [2:0] state_next;

reg [N-1:0] time_cnt;

wire ten_ms_tick;


//===================
// 10ms Timing
//===================
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        time_cnt <= {N{1'b0}};
    end
    else if(time_cnt >= (Timing_cnt_max - 19'd1))begin
        time_cnt <= {N{1'b0}};
    end
    else begin
        time_cnt <= time_cnt + 19'd1;
    end
end

assign ten_ms_tick = (time_cnt == (Timing_cnt_max - 19'd1)) ? 1'b1 : 1'b0;

//==================
// Debouncing FSM
//==================
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        state <= S_HIGH;
    end
    else begin
        state <= state_next;
    end

end

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        db_sw_reg <= 1'b0;
    end
    else begin
        db_sw_reg <= db_sw_next;
    end
end


always @* begin
    state_next = state;
    db_sw_next = db_sw_reg;
    case(state)
    //-----------------------
    // Switch Shift: 1-->0
    //-----------------------
        S_HIGH:begin
            db_sw_next = 1'b1;
            if(!sw)begin
                state_next = S_WAIT_0_1;
            end
        end
        S_WAIT_0_1:begin
            if(sw)begin
                state_next = S_HIGH;
            end
            else begin
                if(ten_ms_tick)begin
                    state_next = S_WAIT_0_2;
                end
            end
        end
        S_WAIT_0_2:begin
            if(sw)begin
                state_next = S_HIGH;
            end
            else begin
                if(ten_ms_tick)begin
                    state_next = S_WAIT_0_3;
                end
            end
        end
        S_WAIT_0_3:begin
            if(sw)begin
                state_next = S_HIGH;
            end
            else begin
                if(ten_ms_tick)begin
                    state_next = S_LOW;
                end
            end
        end
        //--------------
        // Switch Shift: 1-->0
        //--------------
        S_LOW:begin
            db_sw_next = 1'b0;
            if(sw)begin
                state_next = S_WAIT_1_1;
            end
        end
        S_WAIT_1_1:begin
            if(!sw)begin
                state_next = S_LOW;
            end
            else begin
                if(ten_ms_tick)begin
                    state_next = S_WAIT_1_2;
                end
            end
        end
        S_WAIT_1_2:begin
            if(!sw)begin
                state_next = S_LOW;
            end
            else begin
                if(ten_ms_tick)begin
                    state_next = S_WAIT_1_3;
                end
            end
        end
        S_WAIT_1_3:begin
            if(!sw)begin
                state_next = S_LOW;
            end
            else begin
                if(ten_ms_tick)begin
                    db_sw_next = 1'b1;
                    state_next = S_HIGH;
                end
            end
        end
        default:begin
            state_next = S_HIGH;
            db_sw_next = db_sw_reg;
        end
    endcase
end

//===============
// Output Signal Assignment
//===============
assign db_sw = db_sw_reg;

endmodule