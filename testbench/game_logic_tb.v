module game_logic_tb;

    // 输入信号
    reg clk;
    reg rst_n;
    reg [2:0] btn;
    reg [199:0] obstacle_x;
    reg [179:0] obstacle_y;

    // 输出信号
    wire [1:0] gamemode;
    wire [9:0] player_y;

    // 实例化被测试模块
    game_logic uut (
        .rst_n(rst_n),
        .clk(clk),
        .btn(btn),
        .obstacle_x(obstacle_x),
        .obstacle_y(obstacle_y),
        .gamemode(gamemode),
        .player_y(player_y)
    );

    // 时钟生成：100 MHz，周期 10ns
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns 周期
    end

    // 测试激励
    initial begin
        // 初始化信号
        rst_n = 0;
        btn = 3'b000;
        obstacle_x = 200'b0;
        obstacle_y = 180'b0;
        #20 rst_n = 1; // 释放复位

        // 测试用例 1: 初始化状态
        #100 btn[1] = 1; #10 btn[1] = 0; // 按下开始按钮，进入游戏状态
        #1000; // 等待观察初始位置和速度

        // 测试用例 2: 玩家向上运动
        btn[0] = 1; #10 btn[0] = 0; // 切换到向上
        #5000; // 观察匀加速运动到上边界

        // 测试用例 3: 玩家向下运动
        btn[0] = 1; #10 btn[0] = 0; // 切换到向下
        #5000; // 观察匀加速运动到下边界

        // 测试用例 4: 碰撞检测
        obstacle_x[19:0] = {10'd200, 10'd240}; // 障碍物 1: x_left=200, x_right=240
        obstacle_y[17:0] = {9'd240, 9'd280};   // 障碍物 1: y_top=240, y_bottom=280
        #1000; // 观察碰撞触发游戏结束

        // 测试用例 5: 暂停和恢复
        btn[1] = 1; #10 btn[1] = 0; // 暂停
        #1000;
        btn[1] = 1; #10 btn[1] = 0; // 恢复
        #1000;

        // 测试用例 6: 结束并重置
        btn[2] = 1; #10 btn[2] = 0; // 结束游戏
        #1000;
        btn[2] = 1; #10 btn[2] = 0; // 重置到初始状态
        #1000;

        $finish; // 结束仿真
    end

    // 监控输出
    initial begin
        $monitor("Time=%0t rst_n=%b btn=%b gamemode=%b player_y=%d velocity=%d direction=%b collision=%b",
                 $time, rst_n, btn, gamemode, player_y, uut.velocity, uut.direction, uut.collision);
    end

endmodule