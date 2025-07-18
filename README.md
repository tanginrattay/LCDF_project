# Intro

这里是数逻大程的代码文件，工程借鉴了几何冲刺的`ship`状态的玩法，采取`Minecraft`的主题。[实验报告网站](https://tanginrattay.github.io/LCDF_project/)



# Lab

~~下面的双重标点是某位同学的编辑器特色~~

## Todo

- [x] 生命值的设定
- [x] 分数（以障碍物来判定）
- [x] 改变状态时蜂鸣器发声
- [x] 开始、结束、和玩家图片的加载
- [x] beep的歌曲
- [x] 障碍物的移动产生的问题<br>
- ~~-[ ] 同一列障碍物多个，，以及障碍物的速度~~<br>
- ~~- [ ] 开发者模式(不想做了)~~

## Structure 

```
├─Pictures
│  ├─Experience
│  └─Instruction
├─srcs
│  ├─beep
│  ├─seg
│  └─VGA(VGA显示模块代码)
│      └─COE(ROM的coe文件)
├─testbench(仿真文件文件夹)
│  └─result(仿真结果示例)
└─xdc(引脚约束)
```

## Current State

### Problems

+ 碰撞发生时不能静止在刚刚碰撞的状态

## Illustration

这是我们以几何冲刺为背景制作、以我的世界为主题制作的一款躲避障碍物小游戏。

我们的游戏共实现了：开始(Game_start)、游戏中(Gaming)、暂停以及结束(Game_over)四个状态，状态由两个状态开关和游戏内逻辑共同决定。

### 开始界面

状态开关拨到00，，进入游戏初始画面，并播放我们的主题曲（节选自maimaidx2024开始界面音乐）

### 游戏中

状态开关拨到01，，进入游戏。。玩家通过切换一个游戏开关的状态，，实现史蒂夫的加速度的上下切换，，从而躲避从屏幕右侧随机生成的障碍物。。切换加速度方向时，，蜂鸣器会播放对应的音效（（上下音效不同））。。为了实现玩家向右移动的视觉效果，，我们在玩家左侧通过粒子效果生成了拖尾，，拖尾方向与玩家速度方向相反。。我们把躲避的障碍物数量定义为游戏的分数，，并用七段数码管实现了十进制分数的显示，，分数家有五条生命，，在屏幕左下角用心来显示。。每发生一次碰撞，，生命值减1，，并进入一秒钟的无敌状态，，在无敌状态期间，，蜂鸣器会播放一段对应的无敌状态音乐。。

### 游戏结束

当玩家生命值减为0，，游戏结束，，画面暂停，，玩家拖尾逐渐消失，，并在屏幕中央出现GAME OVER图像。。此时玩家通过波动状态开关，，可以重新进入开始界面，，开始新一轮的游玩。。

## 经验

### 数组问题

我们最初使用了一个高达**200**位的数据存储并在模块间传递障碍物的x坐标，，共10个障碍物，，每个障碍物20位。。但是在下板过程中发现结果不对，，推测极有可能是这个过于宽的数据导致了下板失败。。

**解决方法**

我们决定采用数组来存这个10*20的信号。。但是Verilog并不支持在模块接口中使用数组，，所以我们采用了SystemVerilog。。

**SystemVerilog简介**
SystemVerilog 是 Verilog 的超集，完全兼容 Verilog 的语法，并在此基础上扩展了许多新特性。  
1. **Verilog 兼容性**：所有 Verilog 代码都可以直接在 SystemVerilog 中使用。  
2. **数组支持**：SystemVerilog 增强了对数组的支持，允许在模块端口、参数和变量中直接使用多维数组，极大地方便了复杂数据结构的表达和传递。  
3. **always_ff 和 always_comb**：引入了 `always_ff`（专用于时序逻辑）和 `always_comb`（专用于组合逻辑）块，语义更清晰，能帮助避免常见的综合和仿真陷阱。  
4. **logic 变量**：新增 `logic` 类型，既可用于综合也可用于仿真，避免了 `reg` 和 `wire` 的混淆，适合大多数信号声明。  
5. **混用 .sv 和 .v 文件**：在同一个工程中，可以同时使用 `.sv`（SystemVerilog）和 `.v`（Verilog）文件，便于逐步迁移和兼容旧代码。

> 注意：我们下板时遇到了top中实例化和模块中端口不匹配（top中少接了一个端口）仍能下板的情况，所以即使通过了综合、实现、生成比特流的过程也可能有端口不匹配的情况


### 锯齿问题

我们最初下板时，，障碍物出现了锯齿问题。。

![锯齿示例](/Pictures/Experience/锯齿实例.jpg)

这是因为我们的障碍物（（图中蓝色））在向右移动，，它的坐标值以wire形式输出，，以60Hz的频率改变的。。VGA扫描信号扫到障碍物下方时，，障碍物的坐标发生了变化，，导致障碍物上下呈现出““脱节””的状态。。

**解决方法**

在top文件中，，障碍物的坐标不要直接以**wire**形式接入vga相关模块，，而是在垂直消隐时存入**reg**中，，并且把这个**reg**接入vga相关模块。。

```verilog
module top(
    //...
);
    // 游戏逻辑时钟域的障碍物数据
    // 这个变量用于接受某个模块的output
    logic [9:0] [9:0] obstacle_x_game_left;

    // VGA时钟域的障碍物数据
    // 这个用于vga相关模块的input
    logic [9:0] [9:0] obstacle_x_left_vga;

    // --- 关键：时钟域同步器 ---
    // 将游戏逻辑数据同步到VGA时钟域，避免锯齿问题
    always_ff @(posedge clk_25mhz or negedge rst_n_debounced) begin
        if(reset) begin
            //...
        end else begin
            // 在垂直同步信号（VS）有效时更新显示数据
            // 这样可以确保VGA在绘制下一帧时使用一套完整且稳定的数据
            if (!VS) begin // 在垂直消隐期间更新数据
                obstacle_x_left_vga <= obstacle_x_game_left;
                //...
            end
        end
    end
    //...
endmodule
```

### ROM地址生成

rom地址生成需要根据相对位置进行生成，开始使用的是绝对坐标计算得到rom的地址，出现了图像滚动/图像rgb不定态的问题。（这里的图像滚动较为炫酷，若不是以bug形式出现，想来创意十足。）

**解决办法**：使用正负判断以及确定基准点计算相对坐标。

```verilog
//正负（即超出rom显示图片边界判断），相对位置
pic_romaddrOver = (pix_x >= GAMEOVER_X && pix_x < GAMEOVER_X + H_PIC &&
                           pix_y >= GAMEOVER_Y && pix_y < GAMEOVER_Y + H_PIC) ?
                          (pix_x - GAMEOVER_X) + (pix_y - GAMEOVER_Y) * H_PIC : 0; // Default to 0 if out bounds
```

### state的引入

vga要使用rom加载的图像类型很多，一开始使用的是直接判断生成rgb的逻辑，这样使得代码复杂，并且拓展性不强。

**解决办法**：这里引入了state变量，先根据gamemode以及障碍物等参数给state赋值，借助state对rgb进行赋值。后续利用state确实具有很强的拓展性。


# 致谢

本项目的部分代码文件参考了[前辈的工程文件](https://wintermelonc.github.io/WintermelonC_Docs/zju/basic_courses/digital_logic_design/lab/final/)，包括VGA参考学习了前辈的显示思路，Beep模块更是借鉴了前辈的代码实现。
