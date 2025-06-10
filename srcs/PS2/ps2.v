module ps2(
    input clk,
    input rst,
    input ps2_clk,
    input ps2_data,
    output reg [8:0] data
    );

    reg [1:0] clk_state;
    reg [3:0] r_state;// 计时
    reg [7:0] r_data; // 存储临时数据
    reg f,e; //是否特殊数据

    wire neg; // 探测ps2_clk的负边沿
    assign neg = ~clk_state[0] & clk_state[1];

    always @(posedge clk or negedge rst) //初始化clk_state
        if(!rst)
            clk_state <= 2'b00;
        else
            clk_state <= {clk_state[0], ps2_clk};

    always @(posedge clk or negedge rst) begin //初始化数据
        if(!rst) begin
            r_state <= 4'b0000;
            r_data <= 8'b00000000;
            f <= 1'b0;
            e <= 1'b0;
            data <= 9'b000000000;
        end
        else if(neg) begin  
            if(r_state > 4'b1001) //读取完一整串数据后重置计时信号
                r_state <=4'b0000; 
            else begin
                if(r_state < 4'b1001&&r_state>4'b0)
                    r_data[r_state-1]<= ps2_data;  //存入ps2_data
                r_state <= r_state + 1'b1;
            end
        end
        else if(r_state==4'b1010&&|r_data)begin
            if(r_data ==8'hf0) 
                f <=1'b1;
            else if(r_data ==8'he0)
                e <=1'b1;
            else
                if(f)begin  //代表断码，重置信号
                    data<=9'b0;
                    f<=1'b0;
                    e<=1'b0;
                end
                else if(e)begin //在data头部输入1代表已经接受e信号
                    e<=1'b0;
                    data <={1'b1,r_data};
                end
                else
                    data <= {1'b0,r_data};
            r_data <= 8'b00000000;
        end
    end
endmodule