//==============================================================
// Money_Manager.v (FIXED Version)
// - FSM_Controller / Hit_Check / Top_Roulette와 완전 연동
// - 수정사항: money_zero, money_10000을 wire(assign)로 변경하여 
//            잔액 갱신 즉시 플래그가 반영되도록 함 (한 박자 지연 해결)
//==============================================================

module Money_Manager(
    input  wire        clk,
    input  wire        rst,
    
    

    // FSM → Money_Manager
    input  wire        update_req,     // 잔액 갱신 요청 (1클럭)
    input  wire        win_flag,       // Hit_Check 결과 (승/패)
    input  wire [15:0] bet_amount,     // 베팅 금액
    input  wire [2:0]  bet_count,      // 베팅 개수(1~4)
    input  wire [2:0]  hit_count,      // 맞춘 개수
    
    input  wire        game_reset,

    // Money_Manager → FSM / Display / Top
    output reg [15:0] current_money,   // 현재 잔액 (0~10000)
    
    // [수정] reg -> wire로 변경 (실시간 반영을 위해)
    output wire       money_zero,      // 잔액 == 0
    output wire       money_10000,     // 잔액 >= 10000 (게임 클리어)
    
    output reg        win_flag_out     // FSM 전달용 패스스루
);

    //==========================================================
    // 초기 자본
    //==========================================================
    localparam INITIAL_MONEY = 16'd100;
    localparam MAX_MONEY     = 16'd110; // 이미지에 있는 값 유지

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
            win_flag_out  <= 1'b0;
            // [수정] money_zero, money_10000 초기화 삭제 (wire라 필요 없음)
        end else begin
            // Hit_Check → FSM → Money_Manager 패스 스루
            win_flag_out <= win_flag;
            
            // [수정] Game Reset 신호가 오면 즉시 초기화 (최우선 순위)
            if (game_reset) begin
                current_money <= INITIAL_MONEY;
            end
            //------------------------------------------------------
            // update_req 1클럭 시 잔액 갱신
            //------------------------------------------------------
            else if (update_pulse) begin
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
            
            // [수정] 기존의 플래그 업데이트 로직 삭제
            // (여기 있던 money_zero <= ... 코드는 삭제됨)
        end
    end

    //==========================================================
    // [수정] 잔액 상태 플래그 : 조합 회로(assign)로 실시간 연결
    // current_money가 바뀌면 즉시(같은 클럭 사이클 내) 반영됨
    //==========================================================
    assign money_zero  = (current_money == 16'd0);
    assign money_10000 = (current_money >= MAX_MONEY);

endmodule