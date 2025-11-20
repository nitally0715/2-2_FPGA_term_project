//====================================================
// Money_Manager.v
// - 베팅 금액 / 배수 / 승패에 따라 잔액 갱신
// - UPDATE_MONEY 상태 딱 1클럭에서만 갱신
//====================================================

module Money_Manager(
    input  wire        clk,
    input  wire        rst,

    input  wire [3:0]  state,        // FSM 상태
    input  wire [15:0] bet_amount,   // 입력된 베팅 금액
    input  wire [2:0]  bet_count,    // 입력된 베팅 개수 (1~4)
    input  wire        win_flag,     // 상태 STOP_RESULT에서 결정됨

    output reg [15:0]  current_money // 현재 잔액
);

    // FSM 상태 정의 (FSM_Controller와 반드시 일치할 것)
    localparam S_UPDATE_MONEY = 4'd9;
    localparam START_MONEY    = 16'd100;

    // UPDATE_MONEY를 1회만 수행하기 위한 이전 상태 저장
    reg [3:0] prev_state;

    // 배당 배수 테이블 함수
    function [15:0] payout_multiplier(input [2:0] count);
        begin
            case (count)
                1: payout_multiplier = 16'd8;  
                2: payout_multiplier = 16'd4;
                3: payout_multiplier = 16'd3;
                4: payout_multiplier = 16'd2;
                default: payout_multiplier = 16'd1;
            endcase
        end
    endfunction

    //====================================================
    // 메인 로직
    //====================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_money <= START_MONEY;
            prev_state    <= 4'd0;
        end else begin
            prev_state <= state;

            //------------------------------------------------------
            // UPDATE_MONEY 상태에서 "state가 처음 진입할 때" 단 1회 처리
            //------------------------------------------------------
            if (state == S_UPDATE_MONEY && prev_state != S_UPDATE_MONEY) begin
                
                // 안전장치: 베팅 금액이 보유금액보다 많다면 제한
                if (bet_amount > current_money) begin
                    // 사실 FSM에서 이미 금액 검증하지만 안전하게 차단
                    current_money <= current_money;
                end 
                else if (win_flag) begin
                    // WIN: 추가 수익 = bet_amount * (배당 - 1)
                    current_money <= current_money 
                                   + bet_amount * payout_multiplier(bet_count)
                                   - bet_amount;
                end 
                else begin
                    // LOSE: bet_amount만큼 차감
                    if (current_money > bet_amount)
                        current_money <= current_money - bet_amount;
                    else
                        current_money <= 16'd0;  // 0 아래로는 안내려감
                end

            end
        end
    end

endmodule
