//====================================================
// FSM_Controller.v
//  - 키패드 입력으로 베팅 금액/개수/번호 설정
//  - 룰렛 시작 신호(start_spin) 발생
//  - spin_done 이후 당첨 여부 판정
//  - Money_Manager가 쓸 win_flag / lose_flag / bet_amount / bet_count 출력
//====================================================
module FSM_Controller(
    input  wire        clk,
    input  wire        rst,

    input  wire        key_valid,
    input  wire [3:0]  key_value,      // 0~9, 10='*', 11='#'

    input  wire        spin_done,
    input  wire [2:0]  roulette_pos,   // 0~7 (=> 1~8)
    input  wire [15:0] current_money,  // 현재 잔액 (Money_Manager 출력)

    output reg         start_spin,     // Roulette_LED 시작 트리거 (1클럭)
    output reg         win_flag,
    output reg         lose_flag,

    output reg [15:0]  bet_amount,
    output reg [2:0]   bet_count,

    output reg [3:0]   state
);

    //------------------------------------------------
    // 상태 정의
    //------------------------------------------------
    localparam S_IDLE         = 4'd0,
               S_BET_AMOUNT   = 4'd1,
               S_BET_COUNT    = 4'd2,
               S_NUM_INPUT    = 4'd3,
               S_START_SPIN   = 4'd4,
               S_SPIN_WAIT    = 4'd5,
               S_STOP_RESULT  = 4'd6,
               S_WIN_DISPLAY  = 4'd7,
               S_LOSE_DISPLAY = 4'd8,
               S_UPDATE_MONEY = 4'd9,
               S_CHECK_OVER   = 4'd10,
               S_GAME_OVER    = 4'd11;

    //------------------------------------------------
    // 내부 저장소: 베팅 번호 최대 4개
    //------------------------------------------------
    reg [3:0] bet_nums [0:3];    // 1~8 저장
    reg [2:0] num_idx;           // 몇 개 입력했는지

    // 결과 번호 (1~8)
    wire [3:0] result_num = roulette_pos + 1;

    // 디스플레이용 유지 시간 카운터 (WIN/LOSE 상태 유지)
    reg [15:0] disp_cnt;

    // for-loop용 변수는 모듈 상단에 선언
    integer i;


    //------------------------------------------------
    // 메인 FSM
    //------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= S_IDLE;
            bet_amount <= 16'd0;
            bet_count  <= 3'd0;
            num_idx    <= 3'd0;
            start_spin <= 1'b0;
            win_flag   <= 1'b0;
            lose_flag  <= 1'b0;
            disp_cnt   <= 16'd0;
        end else begin
            // 기본값
            start_spin <= 1'b0;

            case (state)

                //------------------------------------------------
                // 0. 대기 상태
                //------------------------------------------------
                S_IDLE: begin
                    bet_amount <= 16'd0;
                    bet_count  <= 3'd0;
                    num_idx    <= 3'd0;
                    win_flag   <= 1'b0;
                    lose_flag  <= 1'b0;

                    // '*' 로 게임 시작 (잔액 > 0 일 때만)
                    if (key_valid && key_value == 4'd10 && current_money > 0)
                        state <= S_BET_AMOUNT;
                end

                //------------------------------------------------
                // 1. 베팅 금액 입력 (숫자 누르고 '*' 확정, '#' 초기화)
                //------------------------------------------------
                S_BET_AMOUNT: begin
                    if (key_valid) begin
                        if (key_value <= 4'd9) begin
                            // 10진수 자리수 추가
                            bet_amount <= bet_amount * 10 + key_value;
                        end else if (key_value == 4'd11) begin
                            // '#': 다시 입력
                            bet_amount <= 16'd0;
                        end else if (key_value == 4'd10) begin
                            // '*': 확정 (0보다 크고, 잔액 이하일 때만)
                            if (bet_amount > 0 && bet_amount <= current_money)
                                state <= S_BET_COUNT;
                        end
                    end
                end

                //------------------------------------------------
                // 2. 베팅 개수(1~4) 입력
                //------------------------------------------------
                S_BET_COUNT: begin
                    if (key_valid) begin
                        if (key_value >= 4'd1 && key_value <= 4'd4) begin
                            bet_count <= key_value[2:0];
                            num_idx   <= 3'd0;
                            state     <= S_NUM_INPUT;
                        end else if (key_value == 4'd11) begin
                            // '#': 금액 단계로 돌아가기
                            state <= S_BET_AMOUNT;
                        end
                    end
                end

                //------------------------------------------------
                // 3. 번호 입력 (1~8), bet_count 개수만큼
                //------------------------------------------------
                S_NUM_INPUT: begin
                    if (key_valid) begin
                        if (key_value >= 4'd1 && key_value <= 4'd8) begin
                            // 번호 저장
                            bet_nums[num_idx] <= key_value;
                            num_idx <= num_idx + 1'b1;

                            // 마지막 개수까지 입력 완료했으면 SPIN으로
                            if (num_idx == bet_count - 1)
                                state <= S_START_SPIN;
                        end else if (key_value == 4'd11) begin
                            // '#': 번호 전부 다시
                            num_idx <= 3'd0;
                        end
                    end
                end

                //------------------------------------------------
                // 4. 룰렛 회전 시작 (start_spin 1클럭 펄스)
                //------------------------------------------------
                S_START_SPIN: begin
                    start_spin <= 1'b1;
                    state      <= S_SPIN_WAIT;
                end

                //------------------------------------------------
                // 5. spin_done 신호 기다리기
                //------------------------------------------------
                S_SPIN_WAIT: begin
                    if (spin_done)
                        state <= S_STOP_RESULT;
                end

                //------------------------------------------------
                // 6. 결과 판정
                //------------------------------------------------
                S_STOP_RESULT: begin
                    win_flag  <= 1'b0;
                    lose_flag <= 1'b0;

                    // bet_count 개수만큼만 비교
                    for (i = 0; i < 4; i = i + 1) begin
                        if (i < bet_count && bet_nums[i] == result_num)
                            win_flag <= 1'b1;
                    end

                    // lose_flag는 win_flag의 반대
                    // (동일 클럭에서 둘 다 결정되게, 먼저 win_flag 전부 계산 후)
                    if (!win_flag)
                        lose_flag <= 1'b1;

                    disp_cnt <= 16'd0;
                    if (win_flag)
                        state <= S_WIN_DISPLAY;
                    else
                        state <= S_LOSE_DISPLAY;
                end

                //------------------------------------------------
                // 7. 승리 메시지 잠깐 유지
                //------------------------------------------------
                S_WIN_DISPLAY: begin
                    disp_cnt <= disp_cnt + 1'b1;
                    if (disp_cnt == 16'h0FFF)  // 적당한 딜레이
                        state <= S_UPDATE_MONEY;
                end

                //------------------------------------------------
                // 8. 패배 메시지 잠깐 유지
                //------------------------------------------------
                S_LOSE_DISPLAY: begin
                    disp_cnt <= disp_cnt + 1'b1;
                    if (disp_cnt == 16'h0FFF)
                        state <= S_UPDATE_MONEY;
                end

                //------------------------------------------------
                // 9. 잔액 갱신은 Money_Manager 쪽에서 처리
                //------------------------------------------------
                S_UPDATE_MONEY: begin
                    state <= S_CHECK_OVER;
                end

                //------------------------------------------------
                // 10. Game Over 여부 확인
                //------------------------------------------------
                S_CHECK_OVER: begin
                    if (current_money == 16'd0)
                        state <= S_GAME_OVER;
                    else
                        state <= S_IDLE;
                end

                //------------------------------------------------
                // 11. GAME OVER 상태 (다시 시작은 상위에서 처리)
                //------------------------------------------------
                S_GAME_OVER: begin
                    // 여기서는 그냥 머물고,
                    // 필요하면 key 입력으로 IDLE로 돌아가게 수정 가능
                    if (key_valid && key_value == 4'd11) // '#'로 리셋 같은 느낌
                        state <= S_IDLE;
                end

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule
