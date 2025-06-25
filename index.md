#           <center>数字逻辑设计大程实验报告</center>

## 1 设计说明

我们小组基于 Vivado 工程与 SWORD 开发板设计了一款单人游戏。游戏的灵感源自于几何冲刺，玩家需要使用改变重力的形式躲避前方生成的不规则物块，玩家通过使用SWORD开发板上的按钮进行对象的移动，并完成游戏的开始与暂停。

#### 开始界面

状态开关拨到00，进入游戏初始画面，并播放我们的主题曲（节选自maimaidx2024开始界面音乐）

#### 游戏中

状态开关拨到01，进入游戏。玩家通过切换一个游戏开关的状态，实现史蒂夫的加速度的上下切换，从而躲避从屏幕右侧随机生成的障碍物。切换加速度方向时，蜂鸣器会播放对应的音效（上下音效不同）。为了实现玩家向右移动的视觉效果，我们在玩家左侧通过粒子效果生成了拖尾，拖尾方向与玩家速度方向相反。我们把躲避的障碍物数量定义为游戏的分数，并用七段数码管实现了十进制分数的显示，分数家有五条生命，在屏幕左下角用心来显示。每发生一次碰撞，生命值减1，并进入一秒钟的无敌状态，在无敌状态期间，蜂鸣器会播放一段对应的无敌状态音乐。

#### 游戏结束

当玩家生命值减为0，游戏结束，画面暂停，玩家拖尾逐渐消失，并在屏幕中央出现GAME OVER图像。此时玩家通过波动状态开关，可以重新进入开始界面，开始新一轮的游玩。

#### 整体设计思路

我们采用 Top-Down 设计思路，由 top 模块来组织连接其他子模块，其中主要的功能模块有 map（地图模块）, VGA，beep（蜂鸣器），game_logic(游戏逻辑），使用 IP 核来存储图片等数据。主要实现了图形显示与贴图，障碍物随机化，游戏人物移动，蜂鸣器等功能。

## 2 VGA设计思路

VGA模块主要用于处理游戏的显示状态与更新。

### 2.1 vga_ctrl 模块

此模块助教已提供。接收像素点的色彩信息（$Din$），输出当前像素点的坐标（$row,col$）和 $VGA$ 有关的变量（$R,G,B,HS,VS$​）

```verilog
// -----------------------------------------------------------------------------
// VGA 控制模块 vga_ctrl
// 输入：
//   clk   - VGA 时钟信号（25 MHz）
//   rst   - 异步复位信号，高有效
//   Din   - 输入像素数据（12位，格式为 bbbb_gggg_rrrr）
// 输出：
//   row   - 像素 RAM 行地址（9位，480 行）
//   col   - 像素 RAM 列地址（10位，640 列）
//   rdn   - 读像素 RAM 使能（低有效）
//   R,G,B - VGA 红、绿、蓝三色输出（各 4 位）
//   HS    - VGA 行同步信号
//   VS    - VGA 场同步信号
// -----------------------------------------------------------------------------

module vga_ctrl(
    input clk,                   // vga clk = 25 MHz
    input rst,
    input [11:0]Din,            // bbbb_gggg_rrrr, pixel
    output reg [8:0]row,        // pixel ram row address, 480 (512) lines
    output reg [9:0]col,        // pixel ram col address, 640 (1024) pixels
    output reg rdn,             // read pixel RAM(active_low)
    output reg [3:0]R, G, B,    // red, green, blue colors
    output reg HS, VS           // horizontal and vertical synchronization
   );
    // h_count: VGA horizontal counter (0~799)
    reg [9:0] h_count;          // VGA horizontal counter (0~799): pixels
initial h_count = 10'h0;
    always @ (posedge clk) begin
        if (rst)  h_count <= 10'h0;
        else if  (h_count == 10'd799)
                     h_count <= 10'h0;
              else h_count <= h_count + 10'h1;
    end

       							// v_count: VGA vertical counter (0~524)
reg [9:0] v_count; 				// VGA vertical counter (0~524): pixel
initial v_count = 10'h0;
    always @ (posedge clk or posedge rst) begin
        if (rst)  v_count <= 10'h0;
        else if  (h_count == 10'd799) begin
                    if (v_count == 10'd524) v_count <= 10'h0;
                    else v_count <= v_count + 10'h1;
        end
    end


// signals, will be latched for outputs
wire    [9:0] row_addr = v_count - 10'd35;     		// pixel ram row addr
wire    [9:0] col_addr = h_count - 10'd143;     	// pixel ram col addr
wire            h_sync = (h_count > 10'd95);    	// 96 -> 799
wire            v_sync = (v_count > 10'd1);    		// 2 -> 524
wire            read   = (h_count > 10'd142) && 	// 143 -> 782
                            (h_count < 10'd783) &&  // 640 pixels
                            (v_count > 10'd34)  &&  // 35 -> 514
                            (v_count < 10'd525);    // 480 lines
// vga signals
always @ (posedge clk) begin
    row <= row_addr[8:0];   	// pixel ram row address
    col <= col_addr;            // pixel ram col address
    rdn <= ~read;               // read pixel (active low)
    HS  <= h_sync;              // horizontal synchronization
    VS  <= v_sync;              // vertical   synchronization
    R   <= rdn ? 4'h0 : Din[3:0];       // 3-bit red
    G    <= rdn ? 4'h0 : Din[7:4];      // 3-bit green
    B    <= rdn ? 4'h0 : Din[11:8]; 	// 2-bit blue
end

endmodule
```

### 2.3 vga_screen_pic 模块

输出当前像素点的色彩信息并提供给 *vga_ctrl* 模块

#### 2.3.1 IP 核的生成

此步骤将图片转换为符合格式的 $.coe$ 文件。我们采用了python与matlab两种语言实现原始图片(raw image)转换为$coe$文件以进行进一步处理，该过程可以处理各种后缀的图片。

获取原始图片，例如开始界面:

***StartImage.png***

![StartImage](C:\Users\13566\Desktop\lcdf\StartImage.png)

利用python将图片处理成合适的分辨率大小

`DPIadjust.py`

```python
from PIL import Image

# 打开图片
image = Image.open("StartImage.png")

width = 40
height = 40
# 直接调整分辨率（DPI）
image.info['dpi'] = (width,height)  # 修改为72DPI

rgb_image = image.convert("RGB")

low_res_image= rgb_image.resize((width, height), Image.Resampling.LANCZOS)

# 保存
low_res_image.save("StartImage.jpg", quality=100)
```

##### 利用$matlib$将图片处理成$.coe$文件

`ImgtoCoe.m`

```matlab
clear;
clc;

% 读取图片（替换为图片路径）
image_array = imread('your_image.png'); 

% 检查图片尺寸
[height, width, ~] = size(image_array);
if height ~= 40 || width ~= 40                %（定义图片合法大小）
    error('图片尺寸不是40x40，请检查！');
end

% 提取 RGB 分量
red   = image_array(:,:,1);   % R 通道 (uint8)
green = image_array(:,:,2);   % G 通道 (uint8)
blue  = image_array(:,:,3);   % B 通道 (uint8)

% 转换为 uint32 并展开成一维向量（按行扫描顺序）
r = uint32(reshape(red',   1, []));  % 转置后展开
g = uint32(reshape(green', 1, []));
b = uint32(reshape(blue',  1, []));

% 初始化 RGB 数据（12-bit RGB444 格式）
rgb = zeros(1, 1600, 'uint32'); % 40x40=1600像素

% 将 RGB888 转换为 RGB444（每个通道取高4位）
for i = 1:1600
    r_4bit = bitshift(r(i), -4);  % 取R通道高4位
    g_4bit = bitshift(g(i), -4);  % 取G通道高4位
    b_4bit = bitshift(b(i), -4);  % 取B通道高4位
    
    % 合并为12-bit RGB (R[3:0]G[3:0]B[3:0])
    rgb(i) = bitor(bitshift(r_4bit, 8), bitor(bitshift(g_4bit, 4), b_4bit));
end

% 写入 COE 文件,这里改成对应的文件名字
fid = fopen('output.coe', 'w');

% COE 文件头
fprintf(fid, 'MEMORY_INITIALIZATION_RADIX=16;\n');
fprintf(fid, 'MEMORY_INITIALIZATION_VECTOR=\n');

% 写入像素数据（16进制）
for i = 1:1600
    if i == 1600
        fprintf(fid, '%03x;', rgb(i));  % 最后一个数据加分号
    else
        fprintf(fid, '%03x,\n', rgb(i)); % 其他数据加逗号和换行
    end
end

fclose(fid);
disp('40x40 COE 文件生成成功！');
```



#### 2.3.2 IP 核的调用

##### 模块接口以及变量定义与初始化，包含游戏对象常量，拖尾效果常量，HEART常量：

```verilog
module vga_screen_pic(
    input wire [9:0] pix_x,
    input wire [8:0] pix_y,
    input wire clk,

    input wire [1:0] gamemode,
    input wire [8:0] player_y,//玩家x固定
    input wire [2:0] heart, //一共有5条命
    //障碍物
    input logic [9:0] [1:0] obstacle_class, 
    input logic [9:0] [9:0] obstacle_x_game_left,
    input logic [9:0] [9:0] obstacle_x_game_right,
    input logic [9:0] [8:0] obstacle_y_game_up,
    input logic [9:0] [8:0] obstacle_y_game_down,
    // Trail effect inputs(拖尾轨迹)
    input logic [40:0] [9:0] trail_x,
    input logic [40:0] [8:0] trail_y,
    input logic [40:0] [3:0] trail_life,

    output reg [11:0] rgb //这里是bgr的依次输出
);

//参量说明    
    // Game object constants (游戏对象常量)
    parameter   PLAYER_X        = 160,
                PLAYER_SIZE     = 40,
                GAMEOVER_X      = 220,
                GAMEOVER_Y      = 140,
                UPPER_BOUND     = 20,
                LOWER_BOUND     = 460;
    parameter   DEFAULT_COLOR   = 12'h000,  
                COLOR_INITIAL   = 12'h0F0,  
                COLOR_INGAME    = 12'hFFF,  
                COLOR_PAUSED    = 12'hFF0,  
                COLOR_ENDED     = 12'hFFF,  
                COLOR_OBSTACLE  = 12'hFA0,  
                COLOR_PLAYER    = 12'h00F;  
    // Trail effect constants (拖尾效果常量)
    parameter   TRAIL_SIZE      = 4,        // Trail particle size
                TRAIL_BASE_COLOR = 12'h44F, // Base trail color (darker blue)
                TRAIL_FADE_LEVELS = 10;     // Number of fade levels
    parameter H_PIC = 10'd200, // over图片宽度 (Game Over image width/height for square)
              SCREEN_W_PIC = 10'd640, // VGA 宽度 (VGA width)
              PLAYER_PIC = 10'd40; // Player image size
    //HEART参量
    parameter HEART_SIZE = 10'd18, // Heart图片的宽度
              // 第一张图片的位置                      
              HEART_Y = 10'd460,
              HEART_X = 10'd0,
              MAX_HEART = 5; // 最大心形数量
    parameter UNIT_SIZE = 30;

    // --- 新增：定义一个将RGB转换为BGR的宏 ---
    `define RGB_TO_BGR(color) {color[3:0], color[7:4], color[11:8]}
```

##### ROM模块，包含：玩家，开始界面，结束界面，背景界面，心形界面，四种不同贴图的障碍物

```verilog
    // 玩家
    StevePlayer player_rom (
      .clka(clk),    // input wire clka
      .addra(pic_romaddrPlayer),  // input wire [10 : 0] addra
      .douta(player_out_data)  // output wire [11 : 0] douta
    );
    // 开始界面
    start game_start (
      .clka(clk),    // input wire clka
      .addra(pic_romaddrStart),  // input wire [18 : 0] addra
      .douta(game_start_data)  // output wire [11 : 0] douta
    );
    // 结束界面
   game_over  game_over_rom (
      .clka(clk),
      .addra(pic_romaddrOver),
      .douta(game_over_data)
    );
    // 背景界面
    background background_rom (
        .clka(clk),    // input wire clka
        .addra(pic_romaddrBackground),  // input wire [18 : 0] addra
        .douta(background_data)  // output wire [11 : 0] douta
    );
    // 心形界面
    Heart heart_rom (
        .clka(clk),
        .addra(pic_romaddrHeart),
        .douta(heart_data)
    );
    // 四种不同类型的障碍物
    black black_rom (
        .clka(clk),
        .addra(pic_romaddrBlack),  // 连接地址寄存器
        .douta(black_data)         // 连接到数据线而非直接连rgb
    );
    skeleton skeleton_rom (
        .clka(clk),
        .addra(pic_romaddrSkeleton),
        .douta(skeleton_data)
    );
    crepper crepper_rom (
        .clka(clk),
        .addra(pic_romaddrCrepper),
        .douta(crepper_data)
    );
    zomber zomber_rom (
        .clka(clk),
        .addra(pic_romaddrZomber),
        .douta(zomber_data)
    );


```

##### 计算rom地址

```verilog
always_comb begin
        pic_romaddrBackground = (pix_y >= UPPER_BOUND && pix_y < LOWER_BOUND) ?  pix_x  + (pix_y - UPPER_BOUND) * SCREEN_W_PIC : 0; // In-game background ROM address
        pic_romaddrStart = pix_x + pix_y * SCREEN_W_PIC;
        pic_romaddrPlayer = (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                             pix_y >= player_y && pix_y < player_y + PLAYER_SIZE) ?
                            (pix_x - PLAYER_X) + (pix_y - player_y) * PLAYER_PIC : 0; 
    // Default to 0 if out of bounds
        pic_romaddrOver = (pix_x >= GAMEOVER_X && pix_x < GAMEOVER_X + H_PIC &&
                           pix_y >= GAMEOVER_Y && pix_y < GAMEOVER_Y + H_PIC) ?
                          (pix_x - GAMEOVER_X) + (pix_y - GAMEOVER_Y) * H_PIC : 0; 
    // Default to 0 if out of bounds
        pic_romaddrHeart = 0;
        for (int h = 0; h < MAX_HEART; h++) begin
            if (pix_y >= HEART_Y && pix_y < HEART_Y + HEART_SIZE && 
                pix_x >= HEART_X + h*HEART_SIZE && pix_x < HEART_X + (h+1)*HEART_SIZE && h < heart) begin
            pic_romaddrHeart = (pix_x - (HEART_X + h*HEART_SIZE)) + (pix_y - HEART_Y) * HEART_SIZE;
            end
        end
        // 计算障碍物的ROM地址
        pic_romaddrBlack = 0;
        pic_romaddrSkeleton = 0;
        pic_romaddrCrepper = 0;
        pic_romaddrZomber = 0;
        for (int j = 0; j < 10; j = j + 1) begin
            if (pix_x >= obstacle_x_game_left[j] && pix_x < obstacle_x_game_right[j] &&
            pix_y >= obstacle_y_game_up[j] && pix_y < obstacle_y_game_down[j]) begin
            
                // 计算障碍物内的相对坐标
                automatic logic [9:0] rel_x = pix_x - obstacle_x_game_left[j];
                automatic logic [8:0] rel_y = pix_y - obstacle_y_game_up[j];
                
                // 缩放到单元格内坐标(0-29)
                automatic logic [4:0] unit_x = rel_x % UNIT_SIZE;
                automatic logic [4:0] unit_y = rel_y % UNIT_SIZE;
                
                // 根据障碍物类型计算ROM地址
                case (obstacle_class[j])
                    2'd0: pic_romaddrBlack = unit_x + unit_y * UNIT_SIZE;    // 小黑
                    2'd1: pic_romaddrSkeleton = unit_x + unit_y * UNIT_SIZE; // 小白 
                    2'd2: pic_romaddrCrepper = unit_x + unit_y * UNIT_SIZE;  // 苦力怕
                    2'd3: pic_romaddrZomber = unit_x + unit_y * UNIT_SIZE;   // 僵尸
                endcase
                break; // 找到一个障碍物后停止搜索
            end
        end
    end
```

##### 拖尾效果计算

```verilog
always_comb begin
        trail_hit = 1'b0;
        trail_alpha = 4'd0;
        trail_idx = 0;
        // Check all trail particles to see if current pixel hits any
        for (integer i = 0; i < 41; i = i + 1) begin
            // Use center as reference, so calculate left/top and right/bottom
            if (trail_life[i] > 0 &&
                pix_x >= (trail_x[i] - TRAIL_SIZE/2) && pix_x < (trail_x[i] + (TRAIL_SIZE+1)/2) &&
                pix_y >= (trail_y[i] - TRAIL_SIZE/2) && pix_y < (trail_y[i] + (TRAIL_SIZE+1)/2)) begin
                trail_hit = 1'b1;
                trail_alpha = trail_life[i]; // Use life as alpha intensity
                trail_idx = i;
                break; // Use first hit trail (highest priority)
            end
        end
    end
```

##### 基于拖尾的生命值的颜色计算，距离玩家越远，拖尾生命值越低，显示效果越暗

```verilog
always_comb begin
        case (trail_alpha)
            4'd10: trail_color = 12'hFDD; // Brightest trail (white)
            4'd9:  trail_color = 12'hEEF; // Very bright (light blue-white)
            4'd8:  trail_color = 12'hDDF; // Bright (light blue)
            4'd7:  trail_color = 12'hCCF; // Medium-bright (medium light blue)
            4'd6:  trail_color = 12'hBBE; // Medium (medium blue)
            4'd5:  trail_color = 12'hAAD; // Medium-dim (darker blue)
            4'd4:  trail_color = 12'h99C; // Dim (dark blue)
            4'd3:  trail_color = 12'h88B; // Very dim (very dark blue)
            4'd2:  trail_color = 12'h77A; // Almost invisible (extremely dark blue)
            4'd1:  trail_color = 12'h669; // Barely visible (near black)
            default: trail_color = 12'h000; // Invisible
        endcase
    end
```

##### 像素类型状态信号说明

```verilog

    reg [3:0] pixel_state;  // Changed from [2:0] to [3:0]
    integer i;
    //确定当前像素的状态
    //0: Border (边界)
    //1: Obstacle (障碍物)
    //2: player(史蒂夫)
    //3: Game Over image (游戏结束图片)
    //4: Game Over background (游戏结束背景)
    //5: In-game background (游戏内背景)
    //6: 初始画面
    //7: Paused screen (暂停画面)
    //8: Trail particle (拖尾粒子) - New state
    //9: Heart (心形图标)
    //10: 障碍物-小黑  obstacle_class = 2'd0
    //11: 障碍物-小白   obstacle_class = 2'd1
    //12: 障碍物-苦力怕 obstacle_class = 2'd2
    //13: 障碍物-僵尸 obstacle_class = 2'd3
```

##### 判断像素状态

```verilog
    always_comb begin
        pixel_state = 4'd0; // Default to background (默认为背景)
        if (gamemode == 2'b00) begin
                pixel_state = 4'd6; //(初始画面)
            end
        else begin
            if(heart != 0) begin
                for (int h = 0; h < MAX_HEART; h++) begin
                    if (pix_y >= HEART_Y && pix_y < HEART_Y + HEART_SIZE && 
                        pix_x >= HEART_X + h*HEART_SIZE && pix_x < HEART_X + (h+1)*HEART_SIZE && 
                        h < heart) begin
                        pixel_state = 4'd9; // Heart状态
                        break;
                    end
                end
            end
            // 如果不是heart，再判断其他
            if (pixel_state != 4'd9) begin
                if (gamemode == 2'b01) begin
                    if (pix_y <= UPPER_BOUND || pix_y >= LOWER_BOUND) begin
                        pixel_state = 4'd0; // Border (边界)
                    end
                    else if (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                            pix_y >= player_y && pix_y < player_y + PLAYER_SIZE)
                        begin
                        pixel_state = 4'd2; // Player (玩家)
                    end
                    else begin
                        logic is_obstacle;
                        is_obstacle = 1'b0;
                        for (i = 0; i < 10; i = i + 1) begin
                            // 使用width和height参数计算障碍物边界
                            if (pix_x >= obstacle_x_game_left[i] && pix_x < obstacle_x_game_right[i]&&
                                pix_y >= obstacle_y_game_up[i] && pix_y < obstacle_y_game_down[i])     
                                begin
                                // 根据obstacle_class设置对应的状态
                                case (obstacle_class[i])
                                    2'd0: pixel_state = 4'd10;  // 小黑
                                    2'd1: pixel_state = 4'd11;  // 小白
                                    2'd2: pixel_state = 4'd12;  // 苦力怕
                                    2'd3: pixel_state = 4'd13;  // 僵尸
                                    default: pixel_state = 4'd1; // 默认障碍物
                                endcase
                                
                                is_obstacle = 1'b1;
                                break;
                            end
                        end

                        if (!is_obstacle) begin
                            if (trail_hit) pixel_state = 4'd8; // Trail particle
                            else pixel_state = 4'd5; // In-game background
                        end
                    end
                end
                else if (gamemode == 2'b11) begin
                    // Game Over图片
                    if (pix_x >= GAMEOVER_X && pix_x < GAMEOVER_X + H_PIC &&
                        pix_y >= GAMEOVER_Y && pix_y < GAMEOVER_Y + H_PIC) begin
                        pixel_state = 4'd3; 
                    end 
                    // 边界
                    else if (pix_y <= UPPER_BOUND || pix_y >= LOWER_BOUND) begin
                        pixel_state = 4'd0; 
                    end 
                    // 玩家
                    else if (pix_x >= PLAYER_X && pix_x < PLAYER_X + PLAYER_SIZE &&
                        pix_y >= player_y && pix_y < player_y + PLAYER_SIZE) begin
                        pixel_state = 4'd2;
                    end 
                    // 障碍物和背景
                    else begin
                        logic is_obstacle;
                        is_obstacle = 1'b0;
                        for (i = 0; i < 10; i = i + 1) begin
                            // 使用width和height参数计算障碍物边界
                            if (pix_x >= obstacle_x_game_left[i] && pix_x < obstacle_x_game_right[i]&&
                                pix_y >= obstacle_y_game_up[i] && pix_y < obstacle_y_game_down[i]) begin
                                
                                // 根据obstacle_class设置对应的状态
                                case (obstacle_class[i])
                                    2'd0: pixel_state = 4'd10;  // 小黑
                                    2'd1: pixel_state = 4'd11;  // 小白
                                    2'd2: pixel_state = 4'd12;  // 苦力怕
                                    2'd3: pixel_state = 4'd13;  // 僵尸
                                    default: pixel_state = 4'd1; // 默认障碍物
                                endcase
                                
                                is_obstacle = 1'b1;
                                break;
                            end
                        end

                        if (!is_obstacle) begin
                            if (trail_hit) pixel_state = 4'd8; // Trail particle
                            else pixel_state = 4'd4; // Game over background
                        end
                    end
                end //end gamemode 2'b11
                else if (gamemode == 2'b10) pixel_state = 4'd7;
                else begin
                    pixel_state = 4'd0; //黑色背景
                end
            end
        end
    end //end pixel_state detection

```

##### 修改RGB输出部分，处理不同类型障碍物的颜色

```verilog
always_comb begin
    // Default to black
    rgb = `RGB_TO_BGR(DEFAULT_COLOR); // 使用宏
    case (gamemode)
        2'b00: begin // 初始游戏模式
                rgb = `RGB_TO_BGR(game_start_data); // 使用宏
        end
        2'b01, 2'b11: begin // 游戏进行模式和游戏结束模式
            case (pixel_state)
                4'd0: rgb = `RGB_TO_BGR(DEFAULT_COLOR);      // Border (边界) or Default (默认)
                4'd1: rgb = `RGB_TO_BGR(COLOR_OBSTACLE);     // 普通障碍物
                4'd2: rgb = `RGB_TO_BGR(player_out_data);    // Player (玩家)
                4'd3: rgb = `RGB_TO_BGR(game_over_data);     // 游戏结束图片
                4'd4: rgb = `RGB_TO_BGR(background_data);    // 游戏结束背景
                4'd5: rgb = `RGB_TO_BGR(background_data);    // In-game background (游戏内背景)
                4'd8: rgb = `RGB_TO_BGR(trail_color);        // 轨迹粒子
                4'd9: rgb = `RGB_TO_BGR(heart_data);         // 心形图标
                // 障碍物类型对应ROM数据
                4'd10: rgb = `RGB_TO_BGR(black_data);    // 小黑 - 使用ROM数据
                4'd11: rgb = `RGB_TO_BGR(skeleton_data); // 小白 - 使用ROM数据
                4'd12: rgb = `RGB_TO_BGR(crepper_data);  // 苦力怕 - 使用ROM数据
                4'd13: rgb = `RGB_TO_BGR(zomber_data);   // 僵尸 - 使用ROM数据
                default: rgb = `RGB_TO_BGR(DEFAULT_COLOR);
            endcase
        end
        2'b10: begin //暂停模式
            if (pixel_state == 4'd9)
                rgb = `RGB_TO_BGR(heart_data); // 显示心形图标
            else
                rgb = `RGB_TO_BGR(COLOR_PAUSED);
        end
        default: rgb = `RGB_TO_BGR(DEFAULT_COLOR);
    endcase
end
endmodule
```



## 3 蜂鸣器设计思路

### 3.1 实现原理

我们采用无源蜂鸣器，内部不带震荡源，因此需要PWM方波驱动其发声。PWM方波的频率决定声音的音调，而PWM方波的占空比决定声音的响度。所以只需产生不同频率和占空比的PWM方波去驱动无源蜂鸣器，就能让无源蜂鸣器发出想要的声音序列。

#### 3.2.1 top_beep 模块

我们设计了三种beep状态，分别为$beep\_gamestart$，$beep\_gameover$，$beep\_gaming$，归总入top中。

```verilog
module top_beep(
    input wire clk,
    input [1:0] gamemode,
    input wire sw,
    output reg beep
);
    wire beep_start;
    wire beep_over;
    wire beep_player;

    initial begin
        beep = 1'b0;
    end

    beep_gamestart bp_gs(.clk(clk), .gamemode(gamemode), .beep(beep_start)); 
    beep_gameover bp_go(.clk(clk), .gamemode(gamemode), .beep(beep_over));
    beep_gaming bp_gi(.clk(clk), .gamemode(gamemode), .sw(sw), .beep(beep_player));

    always @(posedge clk) begin
        if (gamemode == 2'b00) begin
            beep = beep_start; // 游戏待开始状态，beep 为 game_start 
        end 
        else if (gamemode == 2'b11) begin
            beep = beep_over; // 游戏结束状态，beep 为 game_over
        end
        else if (gamemode == 2'b01) begin
            beep = beep_player; // 游戏进行状态，beep 为 player 操作反馈
        end
        else begin
            beep = 1'b0; // 其他状态静音
        end
    end
endmodule
```

#### 3.2.2 beep_gamestart与beep_gameover模块

$clk$ 频率为 $100MHz$ ，周期为 $10ns$，该音乐的 bpm 为 $120$ ，即每分钟$120$拍。以 1 个 16 分音符的长度为单位时间，即 $1/8=0.125s=125ms$ ，则一单位时间等价于$12500000$个clk周期。根据每个音的音调换算成clk周期，例如$A4$音，$f=440Hz$，音波周期$T=1/440=2272727ns=227273$个$clk$周期。

`beep_gamestart.v`

```verilog
module beep_gamestart(
    input clk,
    input [1:0] gamemode, // 游戏状态变量
    output reg beep
    );

    reg rst;
    reg [23:0] cnt; //cnt用来计时，记录125ms的时间,这里4/4拍的音乐，每 125ms 产生一个音符
    reg [5:0] cnt_125ms; // 125ms个数计数,用来数经过了几拍

    reg [19:0] freq_cnt; // 音调频率计数
    reg [19:0] freq_data; // 音调频率

    wire [19:0] duty_data; // 占空比

    initial begin // 初始化所有 reg 信号
        rst = 1'b0;
        beep = 1'b0;
        cnt = 24'b0;
        freq_cnt = 20'b0;
        cnt_125ms = 6'b0;
        freq_data = 20'b0;
    end

    parameter TIME_125ms = 24'd12499999, // 125 ms
                A4 = 19'd227273, // 440 Hz
                A14= 19'd214519, // 466.16Hz(A#4)
                G4 = 19'd255101, // 392Hz
                D4 = 19'd378787, // 264Hz
                E4 = 19'd303030, // 330Hz
                F4 = 19'd286532, // 349Hz
                C4 = 19'd381678; // 262Hz
```

选择占空比为 $50%$% 的PWM方波,并根据游戏状态信号调整 $rst$信号：

```verilog
assign duty_data = freq_data >> 1'b1;

always @(*) begin
        if (gamemode == 2'b00) begin // 游戏开始页面
            rst = 1'b0; // rst 为 0 时，声波正常产生
        end 
        else begin
            rst = 1'b1; // rst 为 1 时，声波不产生
        end
    end
```

$cnt,cnt\_125ms,freq\_cnt,beep$ 的调整 ：

```verilog
//cnt用来计时，记录125ms的时间,这里4/4拍的音乐，每 125ms 产生一个音符
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt <= 24'd0;end 
        else if (cnt == TIME_125ms) begin // 每当 cnt 达到 TIME_125ms 即每过 1 个单位时间，该变量重置为 0 重新开始计数
            cnt <= 24'd0;end 
        else begin
            cnt <= cnt + 1'b1;end
    end

// cnt_125ms 用来计数 125ms 的个数
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt_125ms <= 6'd0;end 
    else if (cnt == TIME_125ms && cnt_125ms == 7'd64) begin // 音乐播放结束时，重置为 0 ，实现循环播放音乐
        cnt_125ms <= 6'd0;end 
    else if (cnt == TIME_125ms) begin // 每过 1 个时间单位，变量值加 1
        cnt_125ms <=    cnt_125ms + 1'b1;
    end
end
//调整freq_cnt
always @(posedge clk or posedge rst) begin
    if (rst) begin
        freq_cnt <= 19'd0;end 
    else if (freq_cnt >= freq_data || cnt == TIME_125ms) begin // 当频率计数信号大于此时的声音频率，或每当过 1 个板载时钟周期时，该值重置为 0 
        c<= 19'd0;end 
    else begin
        freq_cnt <= freq_cnt + 1'b1;
    end
end
//调整beep
always @(posedge clk or posedge rst) begin
    if (rst) begin
        beep <= 1'b0;
    end else if (freq_cnt > duty_data) begin // 当频率计数信号大于占空比时，使 PWM 为 1，实现 50% 的占空比
        beep <= 1'b1;
    end else begin
        beep <= 1'b0;
    end
end
```

调整freq_data实现乐谱写入

```verilog
always @(posedge clk or posedge rst) begin
    if (rst) begin
        freq_data <= 19'd0;
    end else begin
        case (cnt_125ms) // 根据不同的时间段，为该变量赋值不同的频率值
            7'd0: freq_data <= D4;  
            7'd1: freq_data <= E4;
            7'd2: freq_data <= F4;
            7'd3: freq_data <= G4;
            7'd4: freq_data <= A4;  
            7'd5: freq_data <= A4;
            7'd6: freq_data <= A4;
            --snip--
            7'd54: freq_data <= G4;
            7'd55: freq_data <= G4;            
            7'd56: freq_data <= G4;
            7'd57: freq_data <= G4;
            default: freq_data <= 19'd0;
        endcase
    end
end

endmodule
```

结束音乐和开始音乐的设计思路同理

#### 3.2.3 beep_gaming模块的相关设计

##### 根据音效类型设置音符持续时间

```verilog
 always @(*) begin
        if (sound_type == 2'b10) begin
            current_duration = CRASH_NOTE_DURATION;//碰撞音效持续时间
        end else begin
            current_duration = MOVE_NOTE_DURATION;//移动音效持续时间
        end
    end
```

##### 检测信号变化并控制音符播放

```verilog
 always @(posedge clk or posedge rst) begin
        if (rst) begin
            sw_prev <= 1'b0;
            crash_prev <= 2'b00;
            sound_active <= 1'b0;
            note_cnt <= 24'd0;
            note_index <= 4'd0;
            total_notes <= 4'd0;
            sound_type <= 2'b00;
        end else begin
            sw_prev <= sw;
            crash_prev <= crash;
            
            // 优先检测碰撞信号
            if (crash == 2'b11 && crash_prev != 2'b11) begin
                // 碰撞发生，播放失落音效
                sound_active <= 1'b1;
                note_cnt <= 24'd0;
                note_index <= 4'd0;
                sound_type <= 2'b10; // 碰撞音效
                total_notes <= 4'd10; // 10个音符，总共1秒
            end
            // 只有在没有碰撞音效播放时才响应玩家操作
            else if (crash == 2'b00 && sw != sw_prev && !sound_active) begin
                sound_active <= 1'b1;
                note_cnt <= 24'd0;
                note_index <= 4'd0;
                
                if (sw) begin
                    // 上移音效
                    sound_type <= 2'b00;
                    total_notes <= 4'd4;
                end else begin
                    // 下移音效
                    sound_type <= 2'b01;
                    total_notes <= 4'd4;
                end
            end
            
            // 音符时间控制和切换
            else if (sound_active) begin
                if (note_cnt >= current_duration) begin
                    note_cnt <= 24'd0;
                    if (note_index >= total_notes - 1) begin
                        // 所有音符播放完毕
                        sound_active <= 1'b0;
                        note_index <= 4'd0;
                    end else begin
                        // 切换到下一个音符
                        note_index <= note_index + 1'b1;
                    end
                end else begin
                    note_cnt <= note_cnt + 1'b1;
                end
            end
        end
    end
```

##### 根据当前音符索引和音效类型选择不同播放频率

```verilog
always @(posedge clk or posedge rst) begin
        if (rst) begin
            freq_data <= 20'd0;
        end else if (sound_active) begin
            case (sound_type)
                2'b00: begin // 上移音效
                    case (note_index)
                        4'd0: freq_data <= C5;  // 523Hz
                        4'd1: freq_data <= E5;  // 659Hz
                        4'd2: freq_data <= G5;  // 784Hz
                        4'd3: freq_data <= C6;  // 1047Hz
                        default: freq_data <= C5;
                    endcase
                end
                2'b01: begin // 下移音效
                    case (note_index)
                        4'd0: freq_data <= G4;  // 392Hz
                        4'd1: freq_data <= E4;  // 330Hz
                        4'd2: freq_data <= C4;  // 262Hz
                        4'd3: freq_data <= A3;  // 220Hz
                        default: freq_data <= G4;
                    endcase
                end
                2'b10: begin // 碰撞音效
                    case (note_index)
                        4'd0: freq_data <= F4;   // 349Hz
                        4'd1: freq_data <= D4;   // 294Hz
                        4'd2: freq_data <= AS3;  // 245Hz
                        4'd3: freq_data <= G3;   // 196Hz
                        4'd4: freq_data <= F3;   // 175Hz
                        4'd5: freq_data <= D3;   // 147Hz
                        4'd6: freq_data <= AS2;  // 122Hz
                        4'd7: freq_data <= G2;   // 98Hz
                        4'd8: freq_data <= G2;   // 87Hz
                        4'd9: freq_data <= G2;   // 73Hz
                        default: freq_data <= F4;
                    endcase
                end
                default: freq_data <= 20'd0;
            endcase
        end else begin
            freq_data <= 20'd0;
        end
    end
    
```



## 4 game_logic设计思路

### 4.1 ·参数常量设置

```verilog
module game_logic(
    input wire rst_n,
    input wire clk, // 60Hz frame clock
    input [2:0] sw,
    input logic [9:0] [9:0] obstacle_x_left,
    input logic [9:0] [9:0] obstacle_x_right,
    input logic [9:0] [8:0] obstacle_y_up,
    input logic [9:0] [8:0] obstacle_y_down,
    output reg [1:0] gamemode,
    output reg [8:0] player_y,
    output wire [2:0] heart,
    output reg [1:0] crash,
    // Trail effect outputs
    output reg [40:0] [9:0] trail_x,
    output reg [40:0] [8:0] trail_y,
    output reg [40:0] [3:0] trail_life
);

    wire sw_n = ~sw[0]; // Player control switch
    reg [8:0] velocity;
    reg [1:0] crash; 
    reg velocity_direction; // 0 for up, 1 for down
    
    // Heart system variables
    reg [2:0] heart_reg;
    reg [8:0] safe_time_counter; // Counter for safe time after collision
    wire in_safe_time = (safe_time_counter > 0);
    
    // Game constants
    parameter UPPER_BOUND   = 20;
    parameter LOWER_BOUND   = 460;
    parameter PLAYER_SIZE   = 40;
    parameter PLAYER_X_LEFT = 160;
    parameter PLAYER_X_RIGHT= 200;
    parameter MAX_VELOCITY  = 10;
    parameter ACCELERATION  = 1;
    
    // Heart system constants
    parameter INITIAL_HEARTS = 5;
    parameter SAFE_TIME_DURATION = 60; // 1 seconds at 60Hz
    
    // Trail constants
    parameter TRAIL_COUNT      = 41;
    parameter TRAIL_SPAWN_X    = PLAYER_X_LEFT - 8;
    parameter TRAIL_HORIZONTAL_SPEED = 4;
    parameter TRAIL_MAX_LIFE_CENTER = 10;
    parameter TRAIL_MAX_LIFE_INNER  = 8;
    parameter TRAIL_MAX_LIFE_OUTER  = 6;
    parameter SPAWN_DELAY = 3; // 新增生成粒子的延迟参数
    parameter TAIL_SIZE = 4;   // 新增拖尾大小参数

    // Trail generation variables
    reg [2:0] trail_timer; // Timer for trail generation
    reg [4:0] trail_write_index; // Index for writing new trails
    reg [3:0] spawn_timer; // Timer for controlling particle spawn rate

    // Boundary collision flags
    wire hit_upper_bound = (player_y <= UPPER_BOUND);
    wire hit_lower_bound = (player_y >= LOWER_BOUND - PLAYER_SIZE);
    wire hit_boundary = hit_upper_bound || hit_lower_bound;

    // Heart output assignment
    assign heart = heart_reg;

    // gamemode logic
    always_comb begin
        if (heart_reg == 0) begin
            gamemode = 2'b11; // Game over when no hearts left
        end else begin
            gamemode = sw[2:1];
        end
    end
```

### 4.2 游戏模式切换

当生命值为0时切换游戏模式

```verilog

    // gamemode logic
    always_comb begin
        if (heart_reg == 0) begin
            gamemode = 2'b11; // Game over when no hearts left
        end else begin
            gamemode = sw[2:1];
        end
    end
```

### 4.3 玩家状态

player速度与方向的控制，当遇到边界时，速度强制设置为0，方向不变直至出现改变方向操作。然后根据当前速度，方向以及前一刻y坐标计算出player当前y坐标。

```verilog
    // Enhanced velocity and direction logic with boundary handling
    wire [8:0] velocity_next = (gamemode == 2'b01) ? (
        // If hitting boundary and trying to move into it, set velocity to 0
        (hit_upper_bound && velocity_direction == 0) ? 9'd0 :
        (hit_lower_bound && velocity_direction == 1) ? 9'd0 :
        // Normal velocity calculation
        (sw_n == velocity_direction) ? 
            ((velocity + ACCELERATION > MAX_VELOCITY) ? MAX_VELOCITY : velocity + ACCELERATION) :
        ((velocity < ACCELERATION) ? (ACCELERATION - velocity) : velocity - ACCELERATION)//设置最大阈值与速度绝对值
    ) : velocity;//竖直方向上做匀变速运动,ACCELERATION为常量


    wire velocity_direction_next = (gamemode == 2'b01) ? (
        // If hitting boundary, don't change direction unless switching control
        (hit_boundary && sw_n != velocity_direction) ? ~velocity_direction :
        // Normal direction logic
        (sw_n == velocity_direction) ? velocity_direction :
            ((velocity < ACCELERATION) ? ~velocity_direction : velocity_direction)
    ) : velocity_direction;

    // Player position logic - simplified since velocity is now properly controlled
    wire [8:0] player_y_calc = velocity_direction_next ? player_y + velocity_next : player_y - velocity_next;
    wire [8:0] player_y_next = (gamemode == 2'b01) ? (
        (player_y_calc < UPPER_BOUND) ? UPPER_BOUND :
        (player_y_calc > LOWER_BOUND - PLAYER_SIZE) ? (LOWER_BOUND - PLAYER_SIZE) :
        player_y_calc
    ) : player_y;
```

### 4.4 粒子轨迹效果

####  4.4.1 游戏初始化

```verilog
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            player_y           <= (LOWER_BOUND + UPPER_BOUND - PLAYER_SIZE) / 2;
            velocity           <= 0;
            crash              <= 2'b00;
            velocity_direction <= 0;
            trail_timer        <= 0;
            trail_write_index  <= 0;
            spawn_timer        <= 0;
            heart_reg          <= INITIAL_HEARTS;
            safe_time_counter  <= 0;
        // Initialize trail points
        for (integer i = 0; i < TRAIL_COUNT; i = i + 1) begin
            trail_x[i] <= 10'd0;
            trail_y[i] <= 9'd0;
            trail_life[i] <= 4'd0;
        end
        
    end else if (sw[2:1] == 2'b00) begin // Reset game
        player_y           <= (LOWER_BOUND + UPPER_BOUND - PLAYER_SIZE) / 2;
        velocity           <= 0;
        crash              <= 2'b00;
        velocity_direction <= 0;
        trail_timer        <= 0;
        trail_write_index  <= 0;
        spawn_timer        <= 0;
        heart_reg          <= INITIAL_HEARTS;
        safe_time_counter  <= 0;
        
        //拖尾轨迹初始化
        for (integer i = 0; i < TRAIL_COUNT; i = i + 1) begin
            trail_x[i] <= 10'd0;
            trail_y[i] <= 9'd0;
            trail_life[i] <= 4'd0;
        end
        
    end 
```

#### 4.4.2更新游戏状态

无敌帧状态：为避免多次连续碰撞，需要在一次碰撞后加入无敌帧。拖尾轨迹状态：x方向上，与玩家同步移动；y方向上，与玩家相反方向移动。每一个拖尾粒子都存在独立的生命值，并且进行计数，根据不同生命值显示颜色，以此达成渐变效果。

```verilog
else if (heart_reg > 0) begin // Normal game logic (only when hearts > 0)
        player_y           <= player_y_next;
        velocity           <= velocity_next;
        velocity_direction <= velocity_direction_next;
        
    // Update safe time counter(无敌帧计数)
        if (safe_time_counter > 0) begin
            safe_time_counter <= safe_time_counter - 1;
        end

        // Update existing trail points
        for (integer i = 0; i < TRAIL_COUNT; i = i + 1) begin
            if (trail_life[i] > 0) begin
                // Move trail point horizontally (向左移动)
                trail_x[i] <= trail_x[i] - TRAIL_HORIZONTAL_SPEED;
                
             // Apply subtle vertical movement based on ACTUAL velocity and direction
                if (gamemode == 2'b01 && velocity > 1 && !hit_boundary) begin
                    if (velocity_direction == 0) begin
                        // Player moving up, trail moves down slightly
                        trail_y[i] <= trail_y[i] + (velocity >> 2);
                    end else begin
                        // Player moving down, trail moves up slightly
                        if (trail_y[i] >= (velocity >> 2)) begin
                            trail_y[i] <= trail_y[i] - (velocity >> 2);
                        end else begin
                            trail_y[i] <= 0;
                        end
                    end
                end
                // Decrease life counter(拖尾粒子生命值计数)
                trail_life[i] <= trail_life[i] - 1;
                
                // Remove trail points that go off screen or die(移除无效粒子)
                if (trail_x[i] < 10 || trail_life[i] == 1) begin
                    trail_life[i] <= 4'd0;
                end
            end
        end
```

#### 4.4.3 trail生成逻辑

##### 初始化拖尾轨迹

```verilog

            if (gamemode == 2'b01) begin
                trail_timer <= trail_timer + 1;
                if (trail_timer >= 2) begin
                    trail_timer <= 0;
                    // 每次生成5个拖尾点
                    // 检查是否有足够的空间生成5个点
                    if (trail_write_index + 5 <= TRAIL_COUNT) begin
                        // 生成5个均匀分布的拖尾点
                        for (integer j = 0; j < 5; j = j + 1) begin
                            trail_x[trail_write_index + j] <= TRAIL_SPAWN_X;
                            // 计算均匀分布的y坐标
                            // 玩家方块高度为PLAYER_SIZE，分成5等份，对应5个拖尾点
                            trail_y[trail_write_index + j] <= player_y + (j * (PLAYER_SIZE / 4)) + TAIL_SIZE;
                            
                            // 根据位置设置不同的生命值
                            if (j == 2) begin // 中心点
                                trail_life[trail_write_index + j] <= TRAIL_MAX_LIFE_CENTER;
                            end else if (j == 1 || j == 3) begin // 内侧点
                                trail_life[trail_write_index + j] <= TRAIL_MAX_LIFE_INNER;
                            end else begin // 外侧点
                                trail_life[trail_write_index + j] <= TRAIL_MAX_LIFE_OUTER;
                            end
                        end
                        
                        // 更新写入索引，每次增加5
                        trail_write_index <= trail_write_index + 5;
                    end else begin
                        // 如果剩余空间不足5个，则重置到开头
                        trail_write_index <= 0;
                        
                        // 生成5个均匀分布的拖尾点
                        for (integer j = 0; j < 5; j = j + 1) begin
                            trail_x[j] <= TRAIL_SPAWN_X;
                            // 计算均匀分布的y坐标
                            trail_y[j] <= player_y + (j * (PLAYER_SIZE / 4)) + TAIL_SIZE;
                            
                            // 根据位置设置不同的生命值
                            if (j == 2) begin // 中心点
                                trail_life[j] <= TRAIL_MAX_LIFE_CENTER;
                            end else if (j == 1 || j == 3) begin // 内侧点
                                trail_life[j] <= TRAIL_MAX_LIFE_INNER;
                            end else begin // 外侧点
                                trail_life[j] <= TRAIL_MAX_LIFE_OUTER;
                            end
                        end
                        
                        trail_write_index <= 5;
                    end
                end
            end
```

#### 4.4.4 碰撞检测模块

当处于正在游戏状态（gamemode 01）并且不处于无敌帧状态下检测

```verilog
 // Collision detection logic - only in gamemode 01 and when not in safe time
        if (gamemode == 2'b01 && !in_safe_time) begin
            crash <= 2'b00; // Assume no collision initially
            for (integer k = 0; k < 10; k = k + 1) begin
                // AABB collision detection algorithm
                if ( (PLAYER_X_RIGHT > obstacle_x_left[k]) &&
                     (PLAYER_X_LEFT < obstacle_x_right[k]) &&
                     (player_y + PLAYER_SIZE > obstacle_y_up[k]) &&
                     (player_y < obstacle_y_down[k]) ) 
                begin
                    // Collision detected - reduce heart and start safe time
                    if (heart_reg > 1) begin
                        heart_reg <= heart_reg - 1;
                        safe_time_counter <= SAFE_TIME_DURATION;
                    end else begin
                        heart_reg <= 0; // Game over
                    end
                    crash <= 2'b11; // Set crash state for this frame
                end
            end
        end
    end else begin
        // Game over state (heart_reg == 0), still update existing trail points but don't spawn new ones
        for (integer i = 0; i < TRAIL_COUNT; i = i + 1) begin
            if (trail_life[i] > 0) begin
                // Continue moving existing trail points
                trail_x[i] <= trail_x[i] - TRAIL_HORIZONTAL_SPEED;
                trail_life[i] <= trail_life[i] - 1;
                
                // Remove trail points that go off screen or die
                if (trail_x[i] < 10 || trail_life[i] == 1) begin
                    trail_life[i] <= 4'd0;
                end
            end
        end
    end
end
```

## 5 map模块

该模块主要实现地图的状态的模拟，障碍物大小与位置的随机化。

### 5.1 参数常量设置

#### 5.1.1 基础参数定义

```verilog
module map(
    input wire rst_n,
    input wire clk, // Input clock (60Hz frame clock)
    input wire [1:0] gamemode,
    output wire [13:0] score,
    output logic [9:0] [1:0] obstacle_class,
    output logic [9:0] [9:0] obstacle_x_left,
    output logic [9:0] [9:0] obstacle_x_right,
    output logic [9:0] [8:0] obstacle_y_up,
    output logic [9:0] [8:0] obstacle_y_down
);

//================================================================
// Parameters Definition
//================================================================
localparam NUM_OBSTACLES    = 10;
localparam SCREEN_WIDTH     = 640;
localparam UPPER_BOUND      = 20;
localparam LOWER_BOUND      = 460;
localparam PLAY_AREA_HEIGHT = LOWER_BOUND - UPPER_BOUND;

// Obstacle Parameters
localparam UNIT_LENGTH = 30;
localparam SCROLL_SPEED       = 4;
localparam MIN_OBSTACLE_WIDTH = 20;
localparam MAX_OBSTACLE_WIDTH = 80;
localparam MIN_OBSTACLE_HEIGHT = 20;
localparam MAX_OBSTACLE_HEIGHT = 150;

localparam MIN_GAP_DIFFICULTY = 80;
localparam MAX_GAP_DIFFICULTY = 180;

localparam PLAYER_SIZE_Y      = 40;
```

#### 5.1.2 对障碍物相关数据进行初始化

这里重点说明40%的障碍物被选择在地图边界以保证地图难度。

```verilog
// Boundary bias parameters
localparam BOUNDARY_PREFERENCE_THRESHOLD = 8'd102;  // 40% probability to select boundary (102/255 ≈ 40%)
localparam UPPER_BOUNDARY_ZONE_SIZE = 60;           // Upper boundary zone size
localparam LOWER_BOUNDARY_ZONE_SIZE = 60;           // Lower boundary zone size

// Obstacle removal boundary - ensures obstacle is fully off screen before removal
localparam DELETE_BOUNDARY = -100;  // Removal boundary, ensures obstacle is fully off screen
```

#### 5.1.2 内部信号定义

```verilog
//================================================================
// Internal Signal Definitions
//================================================================
reg [NUM_OBSTACLES-1:0] active;
// Use signed X position to prevent overflow
reg signed [11:0] pos_x [0:NUM_OBSTACLES-1];  // 12-bit signed X position, range -2048 to 2047
reg [8:0]  pos_y [0:NUM_OBSTACLES-1];
reg [6:0]  width [0:NUM_OBSTACLES-1];
reg [7:0]  height [0:NUM_OBSTACLES-1];

reg signed [11:0] next_spawn_x;  // Next spawn X position
reg [1:0] gamemode_prev;

// Registered outputs
reg [9:0] [9:0] obstacle_x_left_reg;
reg [9:0] [9:0] obstacle_x_right_reg;
reg [9:0] [8:0] obstacle_y_up_reg;
reg [9:0] [8:0] obstacle_y_down_reg;

// Score register
reg [13:0] score_reg; // 14 bits, enough for 0~9999
```

### 5.2 随机化系统

以下是随机数生成与分布逻辑说明

#### 5.2.1 随机数生成机制

我们的map.sv 模块采用了多组 LFSR（线性反馈移位寄存器）和混合熵源来生成高质量的伪随机数。主要相关代码如下：

```systemverilog
// 随机数寄存器
reg [31:0] rng1, rng2, rng3;
reg [23:0] rng4;
reg [15:0] chaos_counter;
reg [31:0] feedback_shift;
reg [7:0]  noise_accumulator;

// 每帧更新
rng1 <= {rng1[30:0], rng1[31] ^ rng1[21] ^ rng1[1] ^ rng1[0]};
rng2 <= {rng2[30:0], rng2[31] ^ rng2[27] ^ rng2[5] ^ rng2[3]};
rng3 <= {rng3[30:0], rng3[31] ^ rng3[25] ^ rng3[7] ^ rng3[2]};
rng4 <= {rng4[22:0], rng4[23] ^ rng4[18] ^ rng4[12] ^ rng4[6]};
chaos_counter <= chaos_counter + ((rng1[7:0] & 8'h0F) | 8'h01);
feedback_shift <= {feedback_shift[30:0], (rng1[15] ^ rng2[7] ^ rng3[23] ^ rng4[11] ^ chaos_counter[3])};
noise_accumulator <= noise_accumulator + rng1[7:0] + rng2[15:8] + rng3[23:16] + rng4[7:0] + chaos_counter[7:0];
```

这些寄存器的值在每个时钟周期都会更新，保证了随机数的复杂性和不可预测性。

最终通过如下函数混合所有熵源，得到主随机数：

```systemverilog
function automatic [31:0] get_chaos_random;
    input [4:0] counter;
    begin
        get_chaos_random = rng1 ^ rng2 ^ rng3 ^ {rng4, rng4[7:0]} ^ 
                          feedback_shift ^ {noise_accumulator, noise_accumulator, 
                          noise_accumulator, noise_accumulator} ^
                          ({counter, counter, counter, counter, counter, counter, 2'b0} << 
                           (chaos_counter[3:0] % 16)) ^
                          (chaos_counter * 16'hACE1);
    end
endfunction
```

#### 5.2.2 障碍物Y坐标分布与区域覆盖

障碍物的Y坐标分布采用了分区和动态概率机制，确保边界和中间区域都能被覆盖，且分布均匀。

##### 动态边界概率

根据当前障碍物生成的统计数据，动态调整边界生成概率：

```systemverilog
// 计算当前边界障碍物比例
if (total_count > 0) begin
    boundary_ratio = (boundary_count * 8'd100) / total_count;
end else begin
    boundary_ratio = 8'd0;
end

// 动态调整边界概率
if (boundary_ratio < 8'd35) begin
    boundary_preference = BOUNDARY_PREFERENCE_THRESHOLD + 8'd51; // 增加到约60%
end else if (boundary_ratio > 8'd50) begin
    boundary_preference = BOUNDARY_PREFERENCE_THRESHOLD - 8'd25; // 降低到约30%
end else begin
    boundary_preference = BOUNDARY_PREFERENCE_THRESHOLD; // 默认40%
end

// 随机决定是否生成在边界
use_boundary_generation = (chaos_rng[7:0] < boundary_preference);
```

##### 区域强制覆盖机制

将Y轴分为8个分区，每次生成障碍物时，记录其覆盖的分区：

```systemverilog
selected_zone = ((new_y_pos - UPPER_BOUND) * 8) / (LOWER_BOUND - UPPER_BOUND - new_height);
if (selected_zone <= 7) begin
    force_coverage_map[selected_zone] <= 1'b1;
end
```

每16次生成（counter[3:0]==4'b1111）时，如果最上或最下分区未被覆盖，则强制生成边界障碍物:


```systemverilog
if (counter[3:0] == 4'b1111) begin
    if (!coverage_map[0] || !coverage_map[7]) begin
        use_boundary_generation = 1'b1;
    end
end
```

#####  Y坐标分布代码片段

障碍物Y坐标的最终分布逻辑如下：

```systemverilog
if (use_boundary_generation) begin
    // 边界区
    use_upper_boundary = chaos_rng[8];
    if (use_upper_boundary) begin
        // 上边界
        boundary_offset = (chaos_rng[23:16] ^ noise_accumulator) % UPPER_BOUNDARY_ZONE_SIZE;
        result_y = UPPER_BOUND + boundary_offset;
    end else begin
        // 下边界
        boundary_offset = (chaos_rng[15:8] ^ noise_accumulator) % LOWER_BOUNDARY_ZONE_SIZE;
        result_y = max_y_pos - boundary_offset;
        if (result_y < UPPER_BOUND) result_y = UPPER_BOUND;
    end
end else begin
    // 中间区
    middle_area_start = UPPER_BOUND + UPPER_BOUNDARY_ZONE_SIZE;
    middle_area_end = max_y_pos - LOWER_BOUNDARY_ZONE_SIZE;
    if (middle_area_end > middle_area_start) begin
        boundary_offset = (chaos_rng[31:24] ^ chaos_rng[15:8] ^ noise_accumulator) % 
                        (middle_area_end - middle_area_start);
        result_y = middle_area_start + boundary_offset;
    end else begin
        boundary_offset = (chaos_rng[23:16] ^ noise_accumulator) % (max_y_pos - UPPER_BOUND);
        result_y = UPPER_BOUND + boundary_offset;
    end
end
```

#### 5.2.3 总结

+ 通过多级LFSR和混合熵源生成高质量的随机数，保证障碍物参数的不可预测性。
+ 通过动态概率和分区强制覆盖机制，确保Y轴所有区域（尤其是边界）都能被障碍物覆盖，避免出现长时间无障碍物的“死区”。
+ 这种设计既保证了游戏的随机性和挑战性，又保证了游戏体验的公平和完整性。

### 5.3 主状态与障碍物逻辑

```
//================================================================
// Main state machine and obstacle logic
//================================================================
// Disappeared obstacle counter
reg [3:0] disappear_count;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        next_spawn_x <= SCREEN_WIDTH + MIN_GAP_DIFFICULTY;
        gamemode_prev <= 2'b00;
        boundary_generation_count <= 8'b0;
        total_generation_count <= 8'b0;
        score_reg <= 14'd0;
        disappear_count <= 4'd0;  // 初始化计数器
        for (integer i = 0; i < NUM_OBSTACLES; i++) begin
            active[i] <= 1'b0;
            pos_x[i] <= SCREEN_WIDTH + 100;
            pos_y[i] <= UPPER_BOUND;
            width[i] <= MIN_OBSTACLE_WIDTH;
            height[i] <= MIN_OBSTACLE_HEIGHT;
        end
    end else begin
        gamemode_prev <= gamemode;

        if (gamemode == 2'b00) begin
            // Reset state in idle mode
            for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                active[i] <= 1'b0;
                pos_x[i] <= SCREEN_WIDTH + 100;
            end
            next_spawn_x <= SCREEN_WIDTH + MIN_GAP_DIFFICULTY;
            force_coverage_map <= 8'b0;
            boundary_generation_count <= 8'b0;
            total_generation_count <= 8'b0;
            score_reg <= 14'd0;
            disappear_count <= 4'd0;
        end
        else if (gamemode == 2'b01) begin
            if (gamemode_prev == 2'b00) begin
                for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                    active[i] <= 1'b0;
                    pos_x[i] <= SCREEN_WIDTH + 100;
                end
                next_spawn_x <= SCREEN_WIDTH + MIN_GAP_DIFFICULTY;
                force_coverage_map <= 8'b0;
                boundary_generation_count <= 8'b0;
                total_generation_count <= 8'b0;
                score_reg <= 14'd0;
                disappear_count <= 4'd0;
            end

            // Move all active obstacles
            for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                if (active[i]) begin
                    pos_x[i] <= pos_x[i] - SCROLL_SPEED;
                end
            end

            next_spawn_x <= next_spawn_x - SCROLL_SPEED;

            // 重置消失计数器
            disappear_count <= 4'd0;

            // Remove obstacles that are off screen and count them
            for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                if (active[i] && (pos_x[i] + $signed({5'b0, width[i]}) < DELETE_BOUNDARY)) begin
                    active[i] <= 1'b0;
                    disappear_count <= disappear_count + 1'b1;
                end
            end

            // Score accumulation in next clock cycle (will be handled by the register update)
            if (score_reg + disappear_count > 14'd9999)
                score_reg <= 14'd9999;
            else
                score_reg <= score_reg + disappear_count;



```

#### 5.3.2 生成障碍物

随机化生成障碍物后需判断是否为边界障碍物并更新数据与防止溢出。

```verilog

            if (next_spawn_x <= SCREEN_WIDTH) begin
                for (integer i = 0; i < NUM_OBSTACLES; i++) begin
                    if (!active[i]) begin
                        reg [31:0] chaos_random;
                        reg [7:0] new_width, new_height;
                        reg [8:0] new_y_pos;
                        reg [7:0] gap_size;
                        reg [2:0] selected_zone;
                        reg is_boundary_obstacle;

                        // Generate random numbers
                        chaos_random = get_chaos_random(coverage_counter);
                        
                        new_width = get_random_width(chaos_random);
                        new_height = get_random_height(chaos_random);
                        
                        // Use enhanced boundary Y algorithm
                        new_y_pos = get_enhanced_boundary_y(chaos_random, new_height, 
                                                          coverage_counter, last_zone, force_coverage_map,
                                                          boundary_generation_count, total_generation_count);
                        gap_size = get_random_gap(chaos_random);

                        // Check if this is a boundary obstacle
                        is_boundary_obstacle = (new_y_pos <= (UPPER_BOUND + UPPER_BOUNDARY_ZONE_SIZE)) ||
                                             (new_y_pos >= (LOWER_BOUND - new_height - LOWER_BOUNDARY_ZONE_SIZE));

                        // Update statistics
                        total_generation_count <= total_generation_count + 1;
                        if (is_boundary_obstacle) begin
                            boundary_generation_count <= boundary_generation_count + 1;
                        end
                        
                        // Prevent overflow
                        if (total_generation_count == 8'hFF) begin
                            total_generation_count <= 8'd100;
                            boundary_generation_count <= (boundary_generation_count > 8'd100) ? 
                                                        8'd40 : (boundary_generation_count * 8'd100) / 8'hFF;
                        end

```

#### 5.3.3 地图状态更新

```verilog
                        // Update coverage map
                        selected_zone = ((new_y_pos - UPPER_BOUND) * 8) / (LOWER_BOUND - UPPER_BOUND - new_height);
                        if (selected_zone <= 7) begin
                            force_coverage_map[selected_zone] <= 1'b1;
                        end
                        last_zone <= selected_zone;

                        // Every 32 obstacles, reset coverage map
                        if (coverage_counter == 5'b11111) begin
                            force_coverage_map <= 8'b0;
                        end

                        active[i] <= 1'b1;
                        pos_x[i] <= SCREEN_WIDTH;
                        pos_y[i] <= new_y_pos;
                        width[i] <= new_width[6:0];
                        height[i] <= new_height;

                        next_spawn_x <= SCREEN_WIDTH + gap_size;
                        break;
                    end
                end
            end
        end
    end
end
```

### 5.4 障碍物输出逻辑

```verilog
//================================================================
// Output logic
//================================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (integer k = 0; k < NUM_OBSTACLES; k++) begin
            obstacle_x_left_reg[k]  <= 10'd700;
            obstacle_x_right_reg[k] <= 10'd700;
            obstacle_y_up_reg[k]    <= 9'd500;
            obstacle_y_down_reg[k]  <= 9'd500;
        end
    end else begin
        for (integer k = 0; k < NUM_OBSTACLES; k++) begin
            // Only output obstacles that are active and within screen
            if (active[k] && pos_x[k] >= 0 && pos_x[k] < SCREEN_WIDTH) begin
                obstacle_x_left_reg[k]  <= 10'(pos_x[k]);
                obstacle_x_right_reg[k] <= 10'(pos_x[k] + $signed({5'b0, width[k]}));
                obstacle_y_up_reg[k]    <= pos_y[k];
                obstacle_y_down_reg[k]  <= 9'(pos_y[k] + height[k]);
            end else begin
                obstacle_x_left_reg[k]  <= 10'd700;
                obstacle_x_right_reg[k] <= 10'd700;
                obstacle_y_up_reg[k]    <= 9'd500;
                obstacle_y_down_reg[k]  <= 9'd500;
            end
        end
    end
end

assign obstacle_x_left  = obstacle_x_left_reg;
assign obstacle_x_right = obstacle_x_right_reg;
assign obstacle_y_up    = obstacle_y_up_reg;
assign obstacle_y_down  = obstacle_y_down_reg;

// Output score
assign score = score_reg;
assign obstacle_class[0] = 2'b00; // Example class based on Y position
assign obstacle_class[1] = 2'b10;
assign obstacle_class[2] = 2'b01;
assign obstacle_class[3] = 2'b11;
assign obstacle_class[4] = 2'b10;
assign obstacle_class[5] = 2'b00;
assign obstacle_class[6] = 2'b01;
assign obstacle_class[7] = 2'b11;
assign obstacle_class[8] = 2'b10;
assign obstacle_class[9] = 2'b01;
```

## 6 top模块

我们在top模块中增加了抗锯齿功能，并使其支持拖尾效果。

```verilog
module top(
    input wire clk,         // Main input clock (e.g., 100MHz)
    input wire RST_n,       // On-board reset button (active-low)
    input wire [2:0] sw,    // Switches for game control
    output wire [3:0] R,    // VGA Red output
    output wire [3:0] G,    // VGA Green output
    output wire [3:0] B,    // VGA Blue output
    output wire HS,         // VGA Horizontal Sync
    output wire VS,         // VGA Vertical Sync
    output wire beep,
    output wire [3:0] AN,
    output wire [7:0] SEGMENT,
    output wire [1:0] gamemode_led
);

```

### 6.1 内部信号初始化

```verilog
 // --- Internal Signals ---
    wire rst_n_debounced; // Debounced active-low reset signal
    wire clk_25mhz;       // 25MHz clock for VGA pixel timing
    wire clk_60hz;        // 60Hz clock for game logic timing
    
    wire score_rst; // Reset signal for score display
    
    wire [13:0] score;
    wire [3:0] bcd3, bcd2, bcd1, bcd0; // BCD outputs for score display

    wire [1:0] gamemode;
    wire [8:0] player_y;
    wire [2:0] heart_game; // 游戏逻辑时钟域的心脏数量
    wire [1:0] crash;
    
    // Trail effect signals from game logic
    wire [40:0] [9:0] trail_x_game;
    wire [40:0] [8:0] trail_y_game;
    wire [40:0] [3:0] trail_life_game;
    
    // 游戏逻辑时钟域的障碍物数据
    logic [9:0] [1:0] obstacle_class; // 障碍物类别（双缓冲）
    logic [9:0] [9:0] obstacle_x_game_left;
    logic [9:0] [9:0] obstacle_x_game_right;
    logic [9:0] [8:0] obstacle_y_game_up;
    logic [9:0] [8:0] obstacle_y_game_down;

    // VGA时钟域的障碍物数据（双缓冲）
    logic [9:0] [9:0] obstacle_x_left_vga;
    logic [9:0] [9:0] obstacle_x_right_vga;
    logic [9:0] [8:0] obstacle_y_up_vga;
    logic [9:0] [8:0] obstacle_y_down_vga;
    logic [8:0] player_y_vga;
    logic [1:0] gamemode_vga;
    logic [2:0] heart_vga; // VGA时钟域的心脏数量（双缓冲）
    
    // VGA时钟域的拖尾数据（双缓冲）
    logic [40:0] [9:0] trail_x_vga;
    logic [40:0] [8:0] trail_y_vga;
    logic [40:0] [3:0] trail_life_vga;
    
    // VGA signals
    wire [9:0] pix_x;
    wire [8:0] pix_y;
    wire [11:0] vga_data_out; // 12-bit color data from screen generator

    // --- Debouncer ---
    assign rst_n_debounced = RST_n;

    // --- Clock Generation ---
    // Generate 25MHz clock for VGA from main clock (assuming 100MHz input)
    reg [1:0] clk_div_25m;
    always_ff @(posedge clk or negedge rst_n_debounced) begin
        if (!rst_n_debounced) clk_div_25m <= 2'b0;
        else clk_div_25m <= clk_div_25m + 1;
    end
    assign clk_25mhz = clk_div_25m[1];

    // Generate 60Hz clock for game logic
    clkdiv_60hz u_clkdiv_60hz(.clk(clk), .rst_n(rst_n_debounced), .clk_60hz(clk_60hz));
```

### 6.2 抗锯齿效果实现

```verilog
    // --- 关键修复：时钟域同步器（增加拖尾数据同步）---
    // 将游戏逻辑数据同步到VGA时钟域，避免锯齿问题
    always_ff @(posedge clk_25mhz or negedge rst_n_debounced) begin
        if (!rst_n_debounced) begin
            // 复位时初始化障碍物数据
            for (integer i = 0; i < 10; i++) begin
                obstacle_x_left_vga[i] <= 10'd700;
                obstacle_x_right_vga[i] <= 10'd700;
                obstacle_y_up_vga[i] <= 9'd500;
                obstacle_y_down_vga[i] <= 9'd500;
            end
            player_y_vga <= 9'd240;
            gamemode_vga <= 2'b00;
            heart_vga <= 3'd5; // 初始化心脏数量
            
            // 复位时初始化拖尾数据
            for (integer i = 0; i < 41; i++) begin
                trail_x_vga[i] <= 10'd0;
                trail_y_vga[i] <= 9'd0;
                trail_life_vga[i] <= 4'd0;
            end
        end else begin
            // 在垂直同步信号（VS）有效时更新显示数据
            // 这样可以确保VGA在绘制下一帧时使用一套完整且稳定的数据
            if (!VS) begin // 在垂直消隐期间更新数据
                // 同步障碍物和玩家数据
                obstacle_x_left_vga <= obstacle_x_game_left;
                obstacle_x_right_vga <= obstacle_x_game_right;
                obstacle_y_up_vga <= obstacle_y_game_up;
                obstacle_y_down_vga <= obstacle_y_game_down;
                player_y_vga <= player_y;
                gamemode_vga <= gamemode;
                heart_vga <= heart_game; // 同步心脏数量
                
                // 同步拖尾数据
                trail_x_vga <= trail_x_game;
                trail_y_vga <= trail_y_game;
                trail_life_vga <= trail_life_game;
            end
            // 否则，保持当前帧的数据不变
        end
    end
```

### 6.3 各类模块汇总

包含game_logic,map,VGA,beep等模块。

```verilog
    // --- Game Logic Module (Enhanced with Trail Effect and Heart System) ---
    game_logic u_game_logic (
        .rst_n(rst_n_debounced),
        .sw(sw),
        .clk(clk_60hz),                    // 使用60Hz时钟
        .obstacle_x_left(obstacle_x_game_left),
        .obstacle_x_right(obstacle_x_game_right),
        .obstacle_y_up(obstacle_y_game_up),
        .obstacle_y_down(obstacle_y_game_down),
        .gamemode(gamemode),
        .player_y(player_y),
        .heart(heart_game),                // 连接心脏数量输出
        .crash(crash),
        // Trail effect outputs
        .trail_x(trail_x_game),
        .trail_y(trail_y_game),
        .trail_life(trail_life_game)
    );

    // --- Map Generation Module ---
    map u_map (
        .rst_n(rst_n_debounced),
        .clk(clk_60hz),                    // 使用60Hz时钟
        .gamemode(gamemode),
        .score(score),
        .obstacle_class(obstacle_class), // 传递障碍物类别
        .obstacle_x_left(obstacle_x_game_left),
        .obstacle_x_right(obstacle_x_game_right),
        .obstacle_y_up(obstacle_y_game_up),
        .obstacle_y_down(obstacle_y_game_down)
    );

    // --- VGA Screen Picture Generator (Enhanced with Trail Effect) ---
    vga_screen_pic u_vga_screen_pic(
        .pix_x(pix_x),
        .pix_y(pix_y),
        .clk(clk),
        .gamemode(gamemode_vga),           // 使用VGA时钟域的同步数据
        .player_y(player_y_vga),           // 使用VGA时钟域的同步数据
        .heart(heart_vga),                 // 传递心脏数量给VGA显示模块
        .obstacle_class(obstacle_class), // 传递障碍物类别
        .obstacle_x_game_left(obstacle_x_left_vga),
        .obstacle_x_game_right(obstacle_x_right_vga),
        .obstacle_y_game_up(obstacle_y_up_vga),
        .obstacle_y_game_down(obstacle_y_down_vga),
        // Trail effect inputs
        .trail_x(trail_x_vga),
        .trail_y(trail_y_vga),
        .trail_life(trail_life_vga),
        .rgb(vga_data_out)
    );

    // --- VGA Controller ---
    vga_ctrl u_vga_ctrl(
        .clk(clk_25mhz),
        .rst(~rst_n_debounced), // vga_ctrl often uses an active-high reset
        .Din(vga_data_out),
        .row(pix_y),
        .col(pix_x),
        .R(R),
        .G(G),
        .B(B),
        .HS(HS),
        .VS(VS)
    );
    
    // --- Other Peripherals ---
    assign gamemode_led = score[1:0];
    assign heart = heart_vga; // 输出心脏数量（使用VGA时钟域同步后的数据）

    assign score_rst = (gamemode == 2'b00); // Reset score when in initial state
    BinToBCD bcd_instance (
        .bin(score),
        .bcd3(bcd3),
        .bcd2(bcd2),
        .bcd1(bcd1),
        .bcd0(bcd0)
    );
    DisplayNumber d1(.clk(clk), .RST(score_rst), .Hexs({bcd3, bcd2, bcd1, bcd0}), 
                    .Points(4'b0000), .LES(4'b0000), .Segment(SEGMENT), .AN(AN));

   top_beep u_top_beep(
       .clk(clk),
       .gamemode(gamemode),
       .sw(sw[0]),
       .crash(crash),
       .beep(beep)
   );
```

## 7 仿真与调试过程分析

我们主要通过下板验证我们的代码，这里主要讲述VGA模块的仿真实现。在使用vga显示时，常常要利用一个模块生成rgb的值，传入vga，以下将介绍如何对生成rgb的模块进行仿真，检验rgb生成的逻辑。

### 7.1 仿真流程

我们的目标是在不实际上板的情况下，通过仿真验证 `vga_screen_pic` 模块生成的画面是否正确。核心思路是“扫描”屏幕上的每一个像素点，记录其颜色值，最后将这些颜色值利用python组合成一张图片。

#### 7.1.1 仿真代码

```verilog
//实例化和定义接口省略
    integer f;
    initial f = $fopen("screen_pixels.txt", "w");

    initial begin
    //初始化参数省略

        for (pix_y = 0; pix_y < 480; pix_y = pix_y + 1) begin
            for (pix_x = 0; pix_x < 640; pix_x = pix_x + 1) begin
                #1;
                $fwrite(f, "%d %d %h %h %h\n", pix_y, pix_x, rgb[11:8], rgb[7:4], rgb[3:0]); //注意这里的rgb的高低位是rgb还是bgr
            end
        end

        $fclose(f);
        $stop;
    end

endmodule
```

#### 7.1.2 修改路径

将上面的`$fopen("screen_pixels.txt", "w");`的`screen_pixels.txt`改成改成本地文件夹下文件的一个绝对路径,如`C:/Users/simu/screen_pixels.txt`,实测发现不需要有原来的文件，仿真时会新建。(注意这里如果windows的路径是`\`,请使用`/`)

#### 7.1.3 vivado仿真

使用vivado进行仿真，注意下面示例界面的继续的按钮，如果仿真没有完成(弹到仿真文件的`$stop`,请点击“继续仿真”)

<img src="C:\Users\13566\Documents\WeChat Files\wxid_etqwvos0ixfg29\FileStorage\Temp\14fa0acfc4421afdcb232ba83bc3fde.png" alt="14fa0acfc4421afdcb232ba83bc3fde" style="zoom: 50%;" />

#### 7.1.4 使用python生成图片

在`txt`文件对应的文件夹下，让ai创建一个python文件,用于生成图片。

```bash
#配置python环境
pip install pillow #也可使用conda
```

```python
from PIL import Image

WIDTH, HEIGHT = 640, 480
img = Image.new("RGB", (WIDTH, HEIGHT), "black")
pixels = img.load()

with open("screen_pixels.txt") as f:
    for line in f:
        row, col, r, g, b = line.strip().split() #注意这里的rgb还是bgr
        row = int(row)
        col = int(col)
        r = int(r, 16) * 17
        g = int(g, 16) * 17
        b = int(b, 16) * 17
        if 0 <= col < WIDTH and 0 <= row < HEIGHT:
            pixels[col, row] = (r, g, b)

img.save("screen_output.png")
print("图片已保存为 screen_output.png")
```

#### 7.1.5 代码运行

运行python代码，查看结果，下面是一个示例结果

![new_screen_pixels](C:\Users\13566\Desktop\lcdf\new_screen_pixels.png)

### 7.2 具体思路

1. **编写Testbench**:创建一个专门用于测试 `vga_screen_pic` 的仿真文件（例如`tb_vga.sv`）。
2. **模拟像素扫描**: 在Testbench中，使用嵌套循环遍历所有像素坐标，即 `pix_y` 从 0 到 479，`pix_x` 从 0 到 639。
3. **提供输入**: 为 `vga_screen_pic` 模块提供必要的输入，如 `gamemode`, `player_y` 等，以模拟特定的游戏场景。
4. **记录像素颜色**: 对于每一个像素坐标 (`pix_x`, `pix_y`)，Testbench会记录下 `vga_screen_pic` 模块输出的 `rgb` 颜色值。
5. **导出数据到文件**: 使用Verilog的系统任务 (`$fopen`, `$fwrite`, `$fclose`)，将每个像素的坐标和颜色值写入一个文本文件（例如 `screen_pixels.txt`）。文件格式通常为：`行坐标 列坐标 B G R`。(注意`vga_screen_pic.sv`的写入的是`bgr`还是`rgb`,需与python代码对应)
6. **运行仿真**: 在Vivado等仿真工具中运行此Testbench。(注意如果默认仿真时间不足，请点击继续仿真，直到结束，这里结束时会跳转到仿真代码的`$finish`)仿真结束后，你将得到路径里的`screen_pixels.txt` 文件。
7. **生成图片**: 使用一个简单的Python脚本（需安装Pillow库），读取 `screen_pixels.txt` 文件。python脚本会创建一个640x480的空白图片，并根据文件中的数据填充每一个像素的颜色。
8. **验证结果**: 查看生成的图片（例如 `screen_output.png`），即可直观地判断你的 `vga_screen_pic` 模块逻辑是否正确

## 8 下板检验

**开始界面：**

![image-20250624230459833](C:\Users\13566\AppData\Roaming\Typora\typora-user-images\image-20250624230459833.png)

**游戏过程：**

<img src="C:\Users\13566\AppData\Roaming\Typora\typora-user-images\image-20250624230536231.png" alt="image-20250624230536231" style="zoom: 80%;" />

**结束界面：**

<img src="C:\Users\13566\AppData\Roaming\Typora\typora-user-images\image-20250624230621347.png" alt="image-20250624230621347" style="zoom:80%;" />

**分数显示:**

<img src="C:\Users\13566\AppData\Roaming\Typora\typora-user-images\image-20250624230726211.png" alt="image-20250624230726211" style="zoom:80%;" />

## 9 Debug与实验心得

### 9.1数组问题

我们最初使用了一个高达200位的数据存储并在模块间传递障碍物的x坐标，共10个障碍物，每个障碍物20位。但是在下板过程中发现结果不对，推测极有可能是这个过于宽的数据导致了下板失败。

**解决方法**

我们决定采用数组来存这个10*20的信号。但是Verilog并不支持在模块接口中使用数组，所以我们采用了SystemVerilog。

**$SystemVerilog$简介** 

SystemVerilog 是 Verilog 的超集，完全兼容 Verilog 的语法，并在此基础上扩展了许多新特性。

1. **Verilog 兼容性**：所有 Verilog 代码都可以直接在 SystemVerilog 中使用。
2. **数组支持**：SystemVerilog 增强了对数组的支持，允许在模块端口、参数和变量中直接使用多维数组，极大地方便了复杂数据结构的表达和传递。
3. **always_ff 和 always_comb**：引入了 `always_ff`（专用于时序逻辑）和 `always_comb`（专用于组合逻辑）块，语义更清晰，能帮助避免常见的综合和仿真陷阱。
4. **logic 变量**：新增 `logic` 类型，既可用于综合也可用于仿真，避免了 `reg` 和 `wire` 的混淆，适合大多数信号声明。
5. **混用 .sv 和 .v 文件**：在同一个工程中，可以同时使用 `.sv`（SystemVerilog）和 `.v`（Verilog）文件，便于逐步迁移和兼容旧代码。

### 9.2锯齿问题

我们最初下板时，障碍物出现了锯齿问题。

![64a9da4c67fa0d7697e6cceaae568d7](C:\Users\13566\Documents\WeChat Files\wxid_etqwvos0ixfg29\FileStorage\Temp\64a9da4c67fa0d7697e6cceaae568d7.jpg)

这是因为我们的障碍物（图中蓝色)在向右移动，它的坐标值以wire形式输出，以60Hz的频率改变的。VGA扫描信号扫到障碍物下方时，障碍物的坐标发生了变化，导致障碍物上下呈现出““脱节””的状态。

**解决方法**

在top文件中，障碍物的坐标不要直接以**wire**形式接入vga相关模块，而是在垂直消隐时存入**reg**，并且把这个**reg**接入vga相关模块。

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

### 9.3 ROM地址生成

rom地址生成需要根据相对位置进行生成，开始使用的是绝对坐标计算得到rom的地址，出现了图像滚动/图像rgb不定态的问题。

**解决办法**：使用正负判断以及确定基准点计算相对坐标。

```verilog
//正负（即超出rom显示图片边界判断），相对位置
pic_romaddrOver = (pix_x >= GAMEOVER_X && pix_x < GAMEOVER_X + H_PIC &&
                           pix_y >= GAMEOVER_Y && pix_y < GAMEOVER_Y + H_PIC) ?
                          (pix_x - GAMEOVER_X) + (pix_y - GAMEOVER_Y) * H_PIC : 0; // Default to 0 if out bounds

```

### 9.4 state的引入

vga要使用rom加载的图像类型很多，一开始使用的是直接判断生成rgb的逻辑，这样使得代码复杂，并且拓展性不强。

**解决办法**：这里引入了state变量，先根据gamemode以及障碍物等参数给state赋值，借助state对rgb进行赋值。后续利用state确实具有很强的拓展性。

### 9.5 debug不定态

**Q：**我遇到了txt文件里的rgb是x？ **A:** 再次进行仿真，在vivado的scope加入仿真模块，查看对应坐标的不定态原因，可能是一个一个input的不定态导致的输出不定态 

**Tip**：vivado波形界面改变`pix_x`或者`pix_y`是radix使用unsigned integer可以查看十进制坐标

<img src="C:\Users\13566\Documents\WeChat Files\wxid_etqwvos0ixfg29\FileStorage\Temp\e601b18dd45cd387e33ab5a7e7fc64b.png" alt="e601b18dd45cd387e33ab5a7e7fc64b" style="zoom: 80%;" />

**分工情况：**

map，game_logic：汤宇帆

VGA，beep：阳震

beep，实验报告：张庭宇

**参考资料：**https://wintermelonc.github.io/WintermelonC_Docs/zju/basic_courses/digital_logic_design/lab/final/

**个人签名：**![image-20250624234303353](C:\Users\13566\AppData\Roaming\Typora\typora-user-images\image-20250624234303353.png)

