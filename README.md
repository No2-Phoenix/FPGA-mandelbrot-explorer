# FPGA Mandelbrot Zoomer (Zynq-7020)

[English](#english) | [中文](#chinese)

<a name="english"></a>
## 🇬🇧 English Description

A high-performance, real-time Mandelbrot set explorer implemented entirely in Verilog on the Xilinx Zynq-7020 FPGA. This project demonstrates parallel computing, fixed-point arithmetic, and efficient memory management without relying on external DDR memory or the PS (Processing System) side.

### 🎥 Features

*   **Real-Time Rendering**: Utilizes **8 parallel compute cores** to render the fractal in real-time.
*   **Pure PL Implementation**: Runs entirely on Programmable Logic (FPGA fabric), no CPU/PS required.
*   **High Precision**: Uses **32-bit Fixed-Point Arithmetic (Q8.24)** allowing for deep zoom capabilities.
*   **Double Buffering**: Implements Ping-Pong buffering using on-chip BRAM for tear-free animation.
*   **Interactive Controls**: 3-Button interface to control Zoom, Pan, Iteration Depth, and Color Palettes.
*   **Customizable Display**: Renders at 600x400 resolution, centered on an 800x600 VGA/LCD timing signal.
*   **Dynamic Coloring**: Real-time switching between multiple color palettes (Blue-Gold, Red-Purple, High-Contrast, etc.).

### 🛠 Hardware Requirements

*   **FPGA Chip**: Xilinx Zynq-7020 (XC7Z020)
*   **Clock**: 50MHz System Clock
*   **Display**: VGA Monitor or RGB LCD (800x600 @ 60Hz timing)
*   **Input**: 3 Push Buttons (Active Low) + 1 Reset Button

### 🏗 Architecture

The design is modular and pipelined:

1.  **Top Level (`sys_top.v`)**: Manages the global state machine, clock generation (PLL), and user input.
2.  **Render Controller (`mandelbrot_render_ctrl.v`)**:
    *   Dispatches pixel coordinates to 8 parallel `mandelbrot_core` instances.
    *   Collects iteration results and manages write operations to the frame buffer.
3.  **Compute Cores (`mandelbrot_core.v`)**:
    *   Implements the iterative equation $Z_{n+1} = Z_n^2 + C$.
    *   Optimized fixed-point multipliers.
4.  **Memory Subsystem (`frame_buffer_dual.v`)**:
    *   Wraps Xilinx Block RAM (BRAM) in a True Dual-Port configuration.
    *   Total Memory Usage: ~480KB (fits within Zynq-7020's 4.9Mb BRAM).
5.  **Display Pipeline (`mandelbrot_display.v` & `lcd_driver.v`)**:
    *   Generates VGA timing signals.
    *   Maps iteration counts to RGB colors via `palette.v`.
    *   Handles resolution scaling (centering 600x400 on 800x600).

### 🎮 Controls

The system uses a **Mode-Based** control scheme with just 3 buttons to maximize functionality on limited hardware.

| Button | Function |
| :--- | :--- |
| **Key 1 (Mode)** | Cycle through modes: **Zoom** $\to$ **Pan X** $\to$ **Pan Y** $\to$ **Iter** $\to$ **Color** |
| **Key 2 (Inc)** | Increase Value / Zoom In / Move Right / Move Up / Next Color |
| **Key 3 (Dec)** | Decrease Value / Zoom Out / Move Left / Move Down / Prev Color |

#### Mode Details:
1.  **Zoom Mode**: Adjusts the magnification level.
2.  **Pan X Mode**: Moves the view horizontally.
3.  **Pan Y Mode**: Moves the view vertically.
4.  **Iter Mode**: Adjusts `Max Iterations` (Detail level). Higher iterations reveal more detail at edges but slow down rendering.
5.  **Color Mode**: Cycles through different color palettes defined in `palette.v`.

### 📂 File Structure

```text
rtl/
├── sys_top.v                 # Top-level module
├── switch_debounce.v         # Button debouncing
├── edge_detect.v             # Button edge detection
├── operation/
│   ├── mandelbrot_core.v     # Math calculation core
│   └── coord_mapper.v        # Screen coordinate to Complex plane mapper
├── data_buff/
│   ├── mandelbrot_render_ctrl.v # Parallel rendering scheduler
│   └── frame_buffer_dual.v      # BRAM wrapper for double buffering
├── display/
│   ├── mandelbrot_display.v     # Display adapter & centering logic
│   └── lcd_driver.v             # VGA/LCD timing generator
└── color/
    └── palette.v             # Iteration to RGB mapping
```

### 🚀 Build Instructions (Vivado)

1.  **Create Project**: Create a new RTL project in Vivado targeting XC7Z020.
2.  **Add Sources**: Add all `.v` files from the `rtl` folder.
3.  **Generate IPs**:
    *   **Clocking Wizard (`clk_wiz_0`)**:
        *   Input: 50MHz
        *   Output 1: 100MHz (`clk_core`) - For calculation
        *   (Optional) Output 2: 40MHz/50MHz - For VGA Pixel Clock
    *   **Block Memory Generator (`blk_mem_gen_0`)**:
        *   Interface Type: Native
        *   Memory Type: True Dual Port RAM
        *   Port A/B Width: 8 bits
        *   Port A/B Depth: 524288 (2^19) or sufficient for 480,000 bytes.
        *   Enable "Common Clock" if possible, or handle clock domain crossing.
        *   **Important**: Ensure "Primitives Output Register" is unchecked if latency is an issue, or adjust timing logic.
4.  **Constraints**: Create a `.xdc` file mapping `sys_clk`, `rst_n`, `key_*`, and `lcd_*` to your board's specific pins.
5.  **Synthesize & Implement**: Run the flow and generate the bitstream.

---

<a name="chinese"></a>
## 🇨🇳 中文说明

这是一个基于 Xilinx Zynq-7020 FPGA 的高性能实时 Mandelbrot 分形浏览器。该项目完全使用 Verilog 在可编程逻辑（PL）端实现，展示了并行计算、定点数运算以及无需外部 DDR 或 PS（处理器系统）参与的高效片上内存管理。

### 🎥 功能特性

*   **实时渲染**：利用 **8 个并行计算核心** 实现分形图像的实时渲染。
*   **纯 PL 实现**：完全运行在 FPGA 逻辑上，无需 CPU/PS 参与。
*   **高精度计算**：采用 **32位定点数运算 (Q8.24)**，支持深度的缩放浏览。
*   **双缓冲显示**：利用片上 BRAM 实现乒乓缓冲（Ping-Pong Buffering），确保动画流畅无撕裂。
*   **交互式控制**：仅需 3 个按键即可控制缩放、平移、迭代深度和颜色切换。
*   **自定义显示**：渲染分辨率为 600x400，居中显示在 800x600 的 VGA/LCD 时序信号上。
*   **动态配色**：支持实时切换多种调色板（蓝金、红紫、高对比度等）。

### 🛠 硬件需求

*   **FPGA 芯片**: Xilinx Zynq-7020 (XC7Z020)
*   **时钟**: 50MHz 系统时钟
*   **显示**: VGA 显示器或 RGB LCD 屏幕 (支持 800x600 @ 60Hz 时序)
*   **输入**: 3 个按键 (低电平有效) + 1 个复位按键

### 🏗 系统架构

设计采用模块化和流水线架构：

1.  **顶层模块 (`sys_top.v`)**: 管理全局状态机、时钟生成 (PLL) 和用户输入。
2.  **渲染控制器 (`mandelbrot_render_ctrl.v`)**:
    *   将像素坐标分发给 8 个并行的 `mandelbrot_core` 实例。
    *   收集迭代计算结果并管理帧缓冲区的写入操作。
3.  **计算核心 (`mandelbrot_core.v`)**:
    *   实现迭代公式 $Z_{n+1} = Z_n^2 + C$。
    *   包含优化的定点数乘法器。
4.  **存储子系统 (`frame_buffer_dual.v`)**:
    *   封装 Xilinx Block RAM (BRAM) 为真双端口（True Dual-Port）配置。
    *   总内存占用: ~480KB (完全适配 Zynq-7020 的 4.9Mb BRAM 资源)。
5.  **显示流水线 (`mandelbrot_display.v` & `lcd_driver.v`)**:
    *   生成 VGA 时序信号。
    *   通过 `palette.v` 将迭代次数映射为 RGB 颜色。
    *   处理分辨率适配（将 600x400 图像居中显示在 800x600 屏幕上）。

### 🎮 操作说明

系统采用 **基于模式（Mode-Based）** 的控制方案，仅用 3 个按键即可实现丰富的功能。

| 按键 | 功能 |
| :--- | :--- |
| **Key 1 (模式键)** | 循环切换模式：**缩放 (Zoom)** $\to$ **水平平移 (Pan X)** $\to$ **垂直平移 (Pan Y)** $\to$ **迭代深度 (Iter)** $\to$ **颜色 (Color)** |
| **Key 2 (增加键)** | 增加数值 / 放大 / 向右移 / 向上移 / 下一个颜色 |
| **Key 3 (减少键)** | 减少数值 / 缩小 / 向左移 / 向下移 / 上一个颜色 |

#### 模式详情:
1.  **Zoom Mode (缩放)**: 调整图像的放大倍数。
2.  **Pan X Mode (水平)**: 左右移动视野。
3.  **Pan Y Mode (垂直)**: 上下移动视野。
4.  **Iter Mode (迭代)**: 调整 `最大迭代次数` (细节等级)。更高的迭代次数能揭示边缘处的更多细节，但会增加渲染时间。
5.  **Color Mode (颜色)**: 循环切换 `palette.v` 中定义的多种配色方案。

### 📂 文件结构

```text
rtl/
├── sys_top.v                 # 顶层模块
├── switch_debounce.v         # 按键消抖
├── edge_detect.v             # 按键边沿检测
├── operation/
│   ├── mandelbrot_core.v     # 数学计算核心
│   └── coord_mapper.v        # 屏幕坐标到复平面坐标映射
├── data_buff/
│   ├── mandelbrot_render_ctrl.v # 并行渲染调度器
│   └── frame_buffer_dual.v      # 双缓冲 BRAM 封装
├── display/
│   ├── mandelbrot_display.v     # 显示适配与居中逻辑
│   └── lcd_driver.v             # VGA/LCD 时序发生器
└── color/
    └── palette.v             # 迭代次数到 RGB 颜色映射
```

### 🚀 构建指南 (Vivado)

1.  **创建工程**: 在 Vivado 中创建一个针对 XC7Z020 的新 RTL 工程。
2.  **添加源文件**: 将 `rtl` 文件夹下的所有 `.v` 文件添加到工程中。
3.  **生成 IP 核**:
    *   **Clocking Wizard (`clk_wiz_0`)**:
        *   输入: 50MHz
        *   输出 1: 100MHz (`clk_core`) - 用于核心计算
        *   (可选) 输出 2: 40MHz/50MHz - 用于 VGA 像素时钟
    *   **Block Memory Generator (`blk_mem_gen_0`)**:
        *   接口类型: Native
        *   内存类型: True Dual Port RAM (真双端口 RAM)
        *   端口 A/B 位宽: 8 bits
        *   端口 A/B 深度: 524288 (2^19) 或至少能容纳 480,000 字节。
        *   建议启用 "Common Clock" (公共时钟)。
        *   **重要**: 确保 "Primitives Output Register" 未勾选（除非你处理了额外的延迟），否则可能导致显示错位。
4.  **约束文件**: 创建 `.xdc` 文件，将 `sys_clk`, `rst_n`, `key_*`, 和 `lcd_*` 映射到开发板的具体引脚。
5.  **综合与实现**: 运行 Synthesis 和 Implementation，生成 Bitstream。

## 📝 License

Open Source. Feel free to use, modify, and distribute.
开源项目，欢迎使用、修改和分发。
