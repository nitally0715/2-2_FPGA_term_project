//==============================================================
// Hit_Check.v  (FINAL VERSION)
// ·ê·¿ °á°ú(result_pos)¿Í »ç¿ëÀÚ ¼±ÅÃ ¹øÈ£(user_num0~3) ºñ±³
//==============================================================

module Hit_Check(
    input  wire        clk,
    input  wire        rst,

    input  wire [2:0]  bet_count,     // 1~4
    input  wire [2:0]  result_pos,    // 0~7 (LED ÀÎµ¦½º)

    input  wire [2:0]  user_num0,     // Top_Roulette¿¡¼­ FSMÀÌ Àü´Þ
    input  wire [2:0]  user_num1,
    input  wire [2:0]  user_num2,
    input  wire [2:0]  user_num3,

    output reg  [2:0]  hit_count,     // 0~4
    output reg         win_flag       // 1 = ´çÃ·, 0 = ²Î
);

    reg [2:0] temp_hit;

    always @(*) begin
        temp_hit = 3'd0;

        if (bet_count >= 3'd1 && user_num0 == result_pos)
            temp_hit = temp_hit + 3'd1;

        if (bet_count >= 3'd2 && user_num1 == result_pos)
            temp_hit = temp_hit + 3'd1;

        if (bet_count >= 3'd3 && user_num2 == result_pos)
            temp_hit = temp_hit + 3'd1;

        if (bet_count >= 3'd4 && user_num3 == result_pos)
            temp_hit = temp_hit + 3'd1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hit_count <= 3'd0;
            win_flag  <= 1'b0;
        end else begin
            hit_count <= temp_hit;
            win_flag  <= (temp_hit > 0);
        end
    end

endmodule
