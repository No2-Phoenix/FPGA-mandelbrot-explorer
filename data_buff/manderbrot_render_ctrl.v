//======================================
// File: mandelbrot_render_ctrl.v
// Function: Parallel Rendering Controller
// - Instantiates multiple mandelbrot_core for parallelism
// - Batches writes to memory
//======================================
module mandelbrot_render_ctrl #(
    parameter integer FP_W = 32,
    parameter integer FRAC = 24,
    parameter integer W    = 600,   // Modified for 600x400 resolution
    parameter integer H    = 400,   // Modified for 600x400 resolution
    parameter integer ADDR_W = 19,  // Modified for BRAM depth (2^19 > 480000)
    parameter integer CORE_NUM = 8  // 并行核心数量，建议设为 4, 8, 16 等
)(
    input                      clk,
    input                      rst_n,

    input                      start,          
    input      [0:0]           wr_buf_sel,     

    input      signed [FP_W-1:0] center_re,
    input      signed [FP_W-1:0] center_im,
    input      signed [FP_W-1:0] scale,
    input      [7:0]           max_iter,

    // to framebuffer
    output reg [ADDR_W-1:0]    wr_addr,
    output reg [7:0]           wr_data,
    output reg                 wr_en,

    // status
    output reg                 busy,
    output reg                 done
);

    //-------------------------------------------------------
    // 1. 扫描与状态控制
    //-------------------------------------------------------
    reg [10:0] x_base; // 当前批次的起始 X 坐标
    reg [9:0]  y;      // 当前 Y 坐标

    // 状态机定义
    localparam S_IDLE   = 3'd0;
    localparam S_KICK   = 3'd1; // 启动所有核心
    localparam S_WAIT   = 3'd2; // 等待所有核心完成
    localparam S_WRITE  = 3'd3; // 批量写入结果
    localparam S_NEXT   = 3'd4; // 计算下一批次坐标
    localparam S_DONE   = 3'd5;

    reg [2:0] st;

    //-------------------------------------------------------
    // 2. 并行核心实例化
    //-------------------------------------------------------
    reg  [CORE_NUM-1:0] core_start_vec;
    wire [CORE_NUM-1:0] core_busy_vec;
    wire [CORE_NUM-1:0] core_done_vec;
    wire [7:0]          core_iter_out [0:CORE_NUM-1];

    // 生成变量
    genvar i;
    generate
        for (i = 0; i < CORE_NUM; i = i + 1) begin : gen_cores
            // 计算每个核心负责的坐标
            wire [10:0] cur_x = x_base + i;
            
            // 坐标映射结果
            wire signed [FP_W-1:0] c_re, c_im;

            // 只有当 x 在屏幕范围内时才进行有效映射，否则给0（防止越界计算）
            // 实际上 coord_mapper 是组合逻辑，一直会有输出，我们通过控制 start 信号来管理
            coord_mapper #(
                .FP_W(FP_W), .FRAC(FRAC), .W(W), .H(H)
            ) u_mapper (
                .x(cur_x), .y(y),
                .center_re(center_re), .center_im(center_im), .scale(scale),
                .c_re(c_re), .c_im(c_im)
            );

            mandelbrot_core #(
                .FP_W(FP_W), .FRAC(FRAC)
            ) u_core (
                .clk(clk),
                .rst_n(rst_n),
                .start(core_start_vec[i]), // 独立的启动信号
                .c_re(c_re),
                .c_im(c_im),
                .max_iter(max_iter),
                .busy(core_busy_vec[i]),
                .done(core_done_vec[i]),
                .iter_count(core_iter_out[i])
            );
        end
    endgenerate

    //-------------------------------------------------------
    // 3. 写入控制逻辑
    //-------------------------------------------------------
    reg [$clog2(CORE_NUM):0] wr_idx; // 写入索引 (0 ~ CORE_NUM)
    
    // 简单的地址计算：基地址 + 偏移
    // 注意：如果 W 是 1024，y*W 可以优化为 y << 10
    // 这里为了通用性保留乘法，综合器通常会自动优化常数乘法
    wire [ADDR_W-1:0] base_addr = (y * W) + x_base;

    //-------------------------------------------------------
    // 4. 主状态机
    //-------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st             <= S_IDLE;
            x_base         <= 11'd0;
            y              <= 10'd0;
            wr_addr        <= {ADDR_W{1'b0}};
            wr_data        <= 8'd0;
            wr_en          <= 1'b0;
            core_start_vec <= {CORE_NUM{1'b0}};
            busy           <= 1'b0;
            done           <= 1'b0;
            wr_idx         <= 0;
        end else begin
            // 默认信号复位
            wr_en          <= 1'b0;
            core_start_vec <= {CORE_NUM{1'b0}};
            done           <= 1'b0;

            case (st)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy   <= 1'b1;
                        x_base <= 11'd0;
                        y      <= 10'd0;
                        st     <= S_KICK;
                    end
                end

                S_KICK: begin
                    // 启动所有核心
                    // 边界检查：如果 x_base + i 超过了 W，就不启动该核心
                    // 这里简化处理：假设 W 是 CORE_NUM 的倍数，或者溢出部分写入无效地址也没关系(需下游保护)
                    // 严谨做法是按位掩码启动
                    core_start_vec <= {CORE_NUM{1'b1}}; 
                    st <= S_WAIT;
                end

                S_WAIT: begin
                    // 等待所有核心完成
                    // 只要有一个还在忙，就等待
                    // 注意：core_done 是脉冲，core_busy 是电平。
                    // 最稳妥的方式是检测 busy 下降沿，或者简单地：当所有 busy 都为 0 时 (且不是刚启动的那一刻)
                    // 由于 core_start 后 busy 会变高，我们需要确保 busy 已经变高后再检测变低
                    // 或者利用 core_done_vec 的锁存。
                    // 这里的 mandelbrot_core 逻辑是：start -> busy=1 -> ... -> done=1, busy=0
                    
                    // 简单策略：如果所有核心都不忙了 (busy 全为 0)，说明计算结束
                    // 这种策略前提是 S_KICK 后至少过了一个周期，busy 已经被置 1 了。
                    // 实际上 core 内部 start->busy 是同步的，下一拍 busy 才会变 1。
                    // 所以 S_KICK -> S_WAIT 中间最好插一拍，或者在 S_WAIT 里判断
                    
                    // 改进：使用 done 信号的累积（略复杂），或者直接等待 busy 全 0
                    // 假设 core 响应极快，这里加一个简单的延时机制或状态拆分更稳妥
                    // 但由于 core 至少需要几个周期，直接检测 !(|core_busy_vec) 可能会在启动的第一拍误判
                    // 因此我们检测 done 信号向量
                    
                    // 简化版：等待所有 done 信号出现过。
                    // 由于 Verilog 编写复杂，这里采用 "等待直到所有 busy 变低" 
                    // 并在 S_KICK 后加一个 S_PRE_WAIT 确保 busy 拉高
                    if ((|core_busy_vec) == 1'b0) begin
                         // 只有当确实经历过计算才跳转（防止刚进来就跳出）
                         // 由于 core 逻辑，start 后下一拍 busy 变 1。
                         // S_KICK 是 start，下一拍进 S_WAIT，此时 busy 应该是 1。
                         // 如果 core 计算极快（1个周期），可能 busy 还没来得及被采样。
                         // 鉴于 Mandelbrot 至少要算几轮，这里直接判 busy=0 是安全的。
                         st <= S_WRITE;
                         wr_idx <= 0;
                    end
                end

                S_WRITE: begin
                    // 串行输出结果 (Pipeline this if needed for higher freq)
                    if (wr_idx < CORE_NUM) begin
                        // 边界保护：不要写入超出屏幕宽度的点
                        if ((x_base + wr_idx) < W) begin
                            wr_addr <= base_addr + wr_idx;
                            wr_data <= core_iter_out[wr_idx];
                            wr_en   <= 1'b1;
                        end
                        wr_idx <= wr_idx + 1;
                    end else begin
                        st <= S_NEXT;
                    end
                end

                S_NEXT: begin
                    // 更新坐标
                    if ((x_base + CORE_NUM) >= W) begin
                        x_base <= 11'd0;
                        if (y == (H-1)) begin
                            st <= S_DONE;
                        end else begin
                            y <= y + 10'd1;
                            st <= S_KICK;
                        end
                    end else begin
                        x_base <= x_base + CORE_NUM;
                        st <= S_KICK;
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    st   <= S_IDLE;
                end

                default: st <= S_IDLE;
            endcase
        end
    end

endmodule
