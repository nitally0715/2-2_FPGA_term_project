//==============================================================
// Money_Manager.v (FINAL Version - port name unified)
// - FSM_Controller / Hit_Check / Top_Roulette와 완전 연동
//==============================================================

module Money_Manager(
    input  wire        clk,
    input  wire        rst,

    // FSM → Money_Manager
    input  wire        update_req,     // 잔액 갱신 요청 (1클럭)
    input  wire        win_flag,       // Hit_Check 결과 (승/패)  <-- 이름 통일!
    input  wire [15:0] bet_amount,     // 베팅 금액
    input  wire [2:0]  bet_count,      // 베팅 개수(1~4)
    input  wire [2:0]  hit_count,      // 맞춘 개수

    // Money_Manager → FSM / Display / Top
    output reg [15:0] current_money,   // 현재 잔액 (0~10000)
    output reg        money_zero,      // 잔액 == 0
    output reg        money_10000,     // 잔액 >= 10000 (게임 클리어)
    output reg        win_flag_out     // FSM 전달용 패스스루
);

    //==========================================================
    // 초기 자본
    //==========================================================
    localparam INITIAL_MONEY = 16'd100;
    localparam MAX_MONEY     = 16'd10000;

    //==========================================================
    // 배당 배수 계산 : bet_count에 따라 payout 배수 결정
    //==========================================================
    reg [3:0] payout_multi;

    always @(*) begin
        case (bet_count)
            3'd1: payout_multi = 4'd8;
            3'd2: payout_multi = 4'd4;
            3'd3: payout_multi = 4'd2;
            3'd4: payout_multi = 4'd1;
            default: payout_multi = 4'd0;
        endcase
    end

    //==========================================================
    // update_req rising-edge detect
    //==========================================================
    reg update_req_prev;
    wire update_pulse = (update_req == 1'b1 && update_req_prev == 1'b0);

    always @(posedge clk or posedge rst) begin
        if (rst)
            update_req_prev <= 1'b0;
        else
            update_req_prev <= update_req;
    end

    //==========================================================
    // 계산용 임시 레지스터
    //==========================================================
    reg [31:0] payout;
    reg [31:0] temp_money;

    //==========================================================
    // Money Update Logic
    //==========================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_money <= INITIAL_MONEY;
            money_zero    <= 1'b0;
            money_10000   <= 1'b0;
            win_flag_out  <= 1'b0;
        end else begin
            // Hit_Check → FSM → Money_Manager 패스 스루
            win_flag_out <= win_flag;

            //------------------------------------------------------
            // update_req 1클럭 시 잔액 갱신
            //------------------------------------------------------
            if (update_pulse) begin

                // 패배
                if (!win_flag) begin
                    if (current_money > bet_amount)
                        current_money <= current_money - bet_amount;
                    else
                        current_money <= 16'd0;
                end

                // 승리
                else begin
                    payout = bet_amount * payout_multi;

                    temp_money = current_money;

                    // 베팅금 차감
                    if (temp_money > bet_amount)
                        temp_money = temp_money - bet_amount;
                    else
                        temp_money = 0;

                    // 배당금 더함
                    temp_money = temp_money + payout;

                    // 상한 제한
                    if (temp_money >= MAX_MONEY)
                        current_money <= MAX_MONEY;
                    else
                        current_money <= temp_money[15:0];
                end
            end

            //------------------------------------------------------
            // 잔액 상태 플래그 업데이트
            //------------------------------------------------------
            money_zero  <= (current_money == 16'd0);
            money_10000 <= (current_money >= MAX_MONEY);
        end
    end

endmodule
