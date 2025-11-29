//==============================================================
// FSM_Controller.v  (FINAL / Hit_Check + Money_Manager 연동 버전)
// - Keypad / Roulette_LED / Hit_Check / Money_Manager / Display 전체 흐름 제어
//==============================================================

module FSM_Controller(
    input  wire        clk,
    input  wire        rst,

    // Keypad 입력
    input  wire        key_valid,
    input  wire [3:0]  key_value,      // 0~9, 10='*', 11='#'

    // Roulette & Money 플래그
    input  wire        spin_done,      // Roulette_LED 회전 완료
    input  wire        win_flag,       // Hit_Check에서 오는 승리 여부
    input  wire        money_zero,     // Money_Manager: 잔액 == 0
    input  wire        money_10000,    // Money_Manager: 잔액 >= 10000
    input  wire [15:0] current_money,  // Money_Manager: 현재 잔액 (BET_MONEY 검증용)

    // FSM 출력
    output reg  [3:0]  state,          // 현재 상태 코드 (LCD, Piezo 등에서 사용)
    output reg  [2:0]  bet_count,      // 베팅 개수(1~4)
    output reg  [15:0] bet_amount,     // 베팅 금액
    output reg         clear_input,    // 키패드 입력 버퍼 초기화 (1클럭 펄스)
    output reg         start_spin,     // 룰렛 시작 트리거 (1클럭 펄스)
    output reg         update_money_req, // 잔액 갱신 요청 (1클럭)
    output reg         reset_round,    // 한 판/게임 리셋용 (1클럭)

    // Hit_Check 용 유저 선택 번호 4개
    output reg  [3:0]  user_num0,
    output reg  [3:0]  user_num1,
    output reg  [3:0]  user_num2,
    output reg  [3:0]  user_num3
);

    //==========================================================
    // 상태 정의 (다른 모듈과 동일하게 맞춰 사용할 것)
    //==========================================================
    localparam S_IDLE         = 4'd0;
    localparam S_BET_MONEY    = 4'd1;
    localparam S_BET_SELECT   = 4'd2;
    localparam S_NUMBER_INPUT = 4'd3;
    localparam S_START_SPIN   = 4'd4;
    localparam S_SLOW_DOWN    = 4'd5;
    localparam S_STOP_RESULT  = 4'd6;
    localparam S_WIN_DISPLAY  = 4'd7;
    localparam S_LOSE_DISPLAY = 4'd8;
    localparam S_UPDATE_MONEY = 4'd9;
    localparam S_CHECK_MONEY  = 4'd10;
    localparam S_NEXT_STAGE   = 4'd11;
    localparam S_GAME_OVER    = 4'd12;
    localparam S_GAME_CLEAR   = 4'd13;

    reg [3:0] state_next;
    reg [2:0] numbers_entered;   // NUMBER_INPUT에서 실제 입력된 개수

    //==========================================================
    // 순차 논리 : 상태, 레지스터 업데이트
    //==========================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state            <= S_IDLE;
            bet_amount       <= 16'd0;
            bet_count        <= 3'd0;
            numbers_entered  <= 3'd0;

            clear_input      <= 1'b0;
            start_spin       <= 1'b0;
            update_money_req <= 1'b0;
            reset_round      <= 1'b0;

            // 유저 번호 초기화
            user_num0        <= 4'd0;
            user_num1        <= 4'd0;
            user_num2        <= 4'd0;
            user_num3        <= 4'd0;
        end else begin
            state <= state_next;

            // 펄스성 신호 기본값 0
            clear_input      <= 1'b0;
            start_spin       <= 1'b0;
            update_money_req <= 1'b0;
            reset_round      <= 1'b0;

            case (state)

                //--------------------------------------------------
                // IDLE : 대기 (PRESS * TO START)
                //--------------------------------------------------
                S_IDLE: begin
                    if (key_valid && key_value == 4'd10) begin // '*'
                        reset_round     <= 1'b1;   // Hit_Check, Money_Manager 등 라운드 관련 리셋
                        bet_amount      <= 16'd0;
                        bet_count       <= 3'd0;
                        numbers_entered <= 3'd0;

                        // 유저 번호 초기화
                        user_num0       <= 4'd0;
                        user_num1       <= 4'd0;
                        user_num2       <= 4'd0;
                        user_num3       <= 4'd0;
                    end
                end

                //--------------------------------------------------
                // BET_MONEY : 베팅 금액 입력
                //--------------------------------------------------
                S_BET_MONEY: begin
                    if (key_valid) begin
                        if (key_value <= 4'd9) begin
                            // 10진수 누적: 기존 *10 + 새 자리
                            bet_amount <= (bet_amount * 10) + key_value;

                        end else if (key_value == 4'd11) begin
                            // '#' : 금액 초기화
                            bet_amount  <= 16'd0;
                            clear_input <= 1'b1;

                        end else if (key_value == 4'd10) begin
                            // '*' : 확정 시도 → 잘못된 값이면 여기서 바로 초기화
                            // 잘못된 경우: 0원 이거나, 현재 자본보다 큰 금액
                            if (bet_amount == 16'd0 || bet_amount > current_money) begin
                                bet_amount  <= 16'd0;
                                clear_input <= 1'b1;
                            end
                        end
                    end
                end

                //--------------------------------------------------
                // BET_SELECT : 베팅 개수 (1~4)
                //--------------------------------------------------
                S_BET_SELECT: begin
                    if (key_valid) begin
                        if (key_value >= 4'd1 && key_value <= 4'd4) begin
                            bet_count <= key_value[2:0];

                        end else if (key_value == 4'd11) begin
                            // '#' : 개수 초기화
                            bet_count   <= 3'd0;
                            clear_input <= 1'b1;

                        end else if (key_value == 4'd10) begin
                            // '*' : 확정 시도 → 잘못되면 리셋
                            if (bet_count < 3'd1 || bet_count > 3'd4) begin
                                bet_count   <= 3'd0;
                                clear_input <= 1'b1;
                            end
                        end
                    end
                end

                //--------------------------------------------------
                // NUMBER_INPUT : 번호 입력 (1~8, bet_count개)
                //--------------------------------------------------
                S_NUMBER_INPUT: begin
                    if (key_valid) begin
                        if (key_value >= 4'd1 && key_value <= 4'd8) begin
                            // 유효 번호 입력 + 아직 더 받을 수 있을 때
                            if (numbers_entered < bet_count) begin
                                case (numbers_entered)
                                    3'd0: user_num0 <= key_value;
                                    3'd1: user_num1 <= key_value;
                                    3'd2: user_num2 <= key_value;
                                    3'd3: user_num3 <= key_value;
                                    default: ; // do nothing
                                endcase
                                numbers_entered <= numbers_entered + 3'd1;
                            end

                        end else if (key_value == 4'd11) begin
                            // '#' : 전체 초기화
                            numbers_entered <= 3'd0;
                            clear_input     <= 1'b1;

                            user_num0       <= 4'd0;
                            user_num1       <= 4'd0;
                            user_num2       <= 4'd0;
                            user_num3       <= 4'd0;

                        end else if (key_value == 4'd10) begin
                            // '*' : 확정 시도
                            if (numbers_entered != bet_count || bet_count == 3'd0) begin
                                numbers_entered <= 3'd0;
                                clear_input     <= 1'b1;

                                user_num0       <= 4'd0;
                                user_num1       <= 4'd0;
                                user_num2       <= 4'd0;
                                user_num3       <= 4'd0;
                            end
                        end
                    end
                end

                //--------------------------------------------------
                // START_SPIN : 룰렛 시작 트리거
                //--------------------------------------------------
                S_START_SPIN: begin
                    start_spin <= 1'b1;   // 1클럭 펄스 → Roulette_LED 시작
                end

                //--------------------------------------------------
                // S_SLOW_DOWN : 룰렛 감속 / 회전 중
                //--------------------------------------------------
                S_SLOW_DOWN: begin
                    // spin_done을 기다리는 상태 (Roulette_LED에서 올라옴)
                end

                //--------------------------------------------------
                // STOP_RESULT : 결과 확정
                //--------------------------------------------------
                S_STOP_RESULT: begin
                    // Hit_Check가 result_pos 기반으로 win_flag를 갱신해 놓았다고 가정
                end

                //--------------------------------------------------
                // WIN_DISPLAY : 승리 → Money_Manager에 갱신 요청
                //--------------------------------------------------
                S_WIN_DISPLAY: begin
                    update_money_req <= 1'b1;   // 1클럭 펄스
                end

                //--------------------------------------------------
                // LOSE_DISPLAY : 패배 → Money_Manager에 갱신 요청
                //--------------------------------------------------
                S_LOSE_DISPLAY: begin
                    update_money_req <= 1'b1;   // 1클럭 펄스
                end

                //--------------------------------------------------
                // UPDATE_MONEY : Money_Manager 동작 (계산 중이라고 가정)
                //--------------------------------------------------
                S_UPDATE_MONEY: begin
                    // 별도 동작 없음
                end

                //--------------------------------------------------
                // CHECK_MONEY : 잔액 상태 확인
                //--------------------------------------------------
                S_CHECK_MONEY: begin
                    // money_zero / money_10000 은 Money_Manager에서 생성
                end

                //--------------------------------------------------
                // NEXT_STAGE : 다음 라운드 여부
                //--------------------------------------------------
                S_NEXT_STAGE: begin
                    if (key_valid && key_value == 4'd10) begin // '*'
                        reset_round     <= 1'b1;   // Hit_Check 번호 / 내부 카운터 리셋
                        bet_amount      <= 16'd0;
                        bet_count       <= 3'd0;
                        numbers_entered <= 3'd0;

                        user_num0       <= 4'd0;
                        user_num1       <= 4'd0;
                        user_num2       <= 4'd0;
                        user_num3       <= 4'd0;
                    end
                end

                //--------------------------------------------------
                // GAME_OVER : 잔액 0
                //--------------------------------------------------
                S_GAME_OVER: begin
                    if (key_valid && key_value == 4'd10) begin
                        reset_round     <= 1'b1;
                        bet_amount      <= 16'd0;
                        bet_count       <= 3'd0;
                        numbers_entered <= 3'd0;

                        user_num0       <= 4'd0;
                        user_num1       <= 4'd0;
                        user_num2       <= 4'd0;
                        user_num3       <= 4'd0;
                    end
                end

                //--------------------------------------------------
                // GAME_CLEAR : 잔액 >= 10000 (게임 클리어)
                //--------------------------------------------------
                S_GAME_CLEAR: begin
                    if (key_valid && key_value == 4'd10) begin
                        reset_round     <= 1'b1;
                        bet_amount      <= 16'd0;
                        bet_count       <= 3'd0;
                        numbers_entered <= 3'd0;

                        user_num0       <= 4'd0;
                        user_num1       <= 4'd0;
                        user_num2       <= 4'd0;
                        user_num3       <= 4'd0;
                    end
                end

                default: begin
                    // 안전빵: 별도 처리 없음, state_next가 알아서 IDLE로 보낼 것
                end
            endcase
        end
    end

    //==========================================================
    // 조합 논리 : 다음 상태 결정
    //==========================================================
    always @(*) begin
        state_next = state;

        case (state)

            //--------------------------------------------------
            S_IDLE: begin
                if (key_valid && key_value == 4'd10)
                    state_next = S_BET_MONEY;
            end

            //--------------------------------------------------
            S_BET_MONEY: begin
                // '*' 눌렸고, bet_amount가 0이 아니고 current_money 이하이면 BET_SELECT로
                if (key_valid && key_value == 4'd10) begin
                    if (bet_amount != 16'd0 && bet_amount <= current_money)
                        state_next = S_BET_SELECT;
                    else
                        state_next = S_BET_MONEY; // 잘못된 입력 → 다시 BET_MONEY
                end
            end

            //--------------------------------------------------
            S_BET_SELECT: begin
                if (key_valid && key_value == 4'd10) begin
                    if (bet_count >= 3'd1 && bet_count <= 3'd4)
                        state_next = S_NUMBER_INPUT;
                    else
                        state_next = S_BET_SELECT;
                end
            end

            //--------------------------------------------------
            S_NUMBER_INPUT: begin
                if (key_valid && key_value == 4'd10) begin
                    if (numbers_entered == bet_count && bet_count != 3'd0)
                        state_next = S_START_SPIN;
                    else
                        state_next = S_NUMBER_INPUT;
                end
            end

            //--------------------------------------------------
            S_START_SPIN: begin
                state_next = S_SLOW_DOWN;
            end

            //--------------------------------------------------
            S_SLOW_DOWN: begin
                if (spin_done)
                    state_next = S_STOP_RESULT;
            end

            //--------------------------------------------------
            S_STOP_RESULT: begin
                // Hit_Check에서 계산된 win_flag에 따라 승/패 분기
                if (win_flag)
                    state_next = S_WIN_DISPLAY;
                else
                    state_next = S_LOSE_DISPLAY;
            end

            //--------------------------------------------------
            S_WIN_DISPLAY: begin
                state_next = S_UPDATE_MONEY;
            end

            //--------------------------------------------------
            S_LOSE_DISPLAY: begin
                state_next = S_UPDATE_MONEY;
            end

            //--------------------------------------------------
            S_UPDATE_MONEY: begin
                state_next = S_CHECK_MONEY;
            end

            //--------------------------------------------------
            S_CHECK_MONEY: begin
                if (money_zero)
                    state_next = S_GAME_OVER;
                else if (money_10000)
                    state_next = S_GAME_CLEAR;
                else
                    state_next = S_NEXT_STAGE;
            end

            //--------------------------------------------------
            S_NEXT_STAGE: begin
                // '*' 누르면 다음 라운드 → BET_MONEY
                if (key_valid && key_value == 4'd10)
                    state_next = S_BET_MONEY;
            end

            //--------------------------------------------------
            S_GAME_OVER: begin
                // '*' 누르면 완전 초기화 → IDLE
                if (key_valid && key_value == 4'd10)
                    state_next = S_IDLE;
            end

            //--------------------------------------------------
            S_GAME_CLEAR: begin
                // '*' 누르면 완전 초기화 → IDLE
                if (key_valid && key_value == 4'd10)
                    state_next = S_IDLE;
            end

            default: begin
                state_next = S_IDLE;
            end
        endcase
    end

endmodule
