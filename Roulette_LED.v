//==============================================================
// Roulette_LED.v
// - 8개의 LED를 이용한 룰렛 회전/감속/정지 표시
// - FSM_Controller 의 start_spin(1클럭) 입력을 받아 동작
// - 결과 위치 result_pos(0~7) 출력
// - LFSR을 이용해서 랜덤성 부여
//==============================================================

module Roulette_LED(
    input  wire clk,
    input  wire rst,
    input  wire start_spin,       // FSM에서 1클럭 펄스

    output reg  [7:0] led_out,    // 현재 LED 출력 (one-hot)
    output reg  [2:0] result_pos, // 최종 멈춘 위치 (0~7)
    output reg        spin_done,  // 회전 종료 신호 (1클럭 펄스)
    output reg        spin_active // 회전 중일 때 1 (RUN, SLOW 상태)
);

    //==========================================================
    // 0. 회전 FSM 상태 정의
    //==========================================================
    localparam  S_IDLE = 2'd0,
                S_RUN  = 2'd1,
                S_SLOW = 2'd2,
                S_STOP = 2'd3;

    reg [1:0] state, state_next;

    //==========================================================
    // 1. 내부 pos (0~7)
    //==========================================================
    reg [2:0] pos;  // 현재 LED 인덱스

    // LED one-hot 생성 (active-high)
    wire [7:0] led_pattern = (8'b0000_0001 << pos);

    //==========================================================
    // 2. 속도 제어용 분주기
    //==========================================================
    reg [31:0] speed_cnt;
    reg [31:0] interval;       // 현재 딜레이 (작을수록 빠름)

    // 고속 회전 기본속도 & 감속 증가량
    localparam BASE_SPEED   = 32'd50000;   // 50MHz 기준 ≒ 1ms
    localparam SLOW_STEP    = 32'd25000;   // 감속 단계 증가량
    localparam MAX_INTERVAL = 32'd400000;  // 감속 한계

    //==========================================================
    // 3. LFSR(난수 생성)
    //==========================================================
    reg [7:0] lfsr;

    always @(posedge clk or posedge rst) begin
        if (rst)
            lfsr <= 8'hA5; // 초기 seed
        else begin
            // x^8 + x^6 + x^5 + x^4 + 1 다항식
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
        end
    end

    //==========================================================
    // 4. 상태 레지스터
    //==========================================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= S_IDLE;
        else
            state <= state_next;
    end

    //==========================================================
    // 5. 상태 전이 조건 (조합 논리)
//==========================================================
    always @(*) begin
        state_next = state;
        case (state)
            //--------------------------------------------------
            // IDLE
            //--------------------------------------------------
            S_IDLE: begin
                if (start_spin)
                    state_next = S_RUN;
            end

            //--------------------------------------------------
            // 고속 회전
            //--------------------------------------------------
            S_RUN: begin
                // interval이 일정 수준 이상 커지면 감속 단계로
                if (interval >= (BASE_SPEED + SLOW_STEP * 4))
                    state_next = S_SLOW;
            end

            //--------------------------------------------------
            // 감속 중
            //--------------------------------------------------
            S_SLOW: begin
                if (interval >= MAX_INTERVAL)
                    state_next = S_STOP;
            end

            //--------------------------------------------------
            // 정지
            //--------------------------------------------------
            S_STOP: begin
                // spin_done 1클럭 후 IDLE 복귀
                state_next = S_IDLE;
            end

            default: begin
                state_next = S_IDLE;
            end
        endcase
    end

    //==========================================================
    // 6. 속도 제어 & pos 업데이트 & 출력
    //==========================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pos        <= 3'd0;
            speed_cnt  <= 32'd0;
            interval   <= BASE_SPEED;
            led_out    <= 8'd0;
            result_pos <= 3'd0;
            spin_done  <= 1'b0;
            spin_active<= 1'b0;
        end else begin
            // 기본값
            led_out     <= led_pattern; // 현재 pos 기준 one-hot
            spin_done   <= 1'b0;        // 펄스 신호
            spin_active <= 1'b0;        // 기본은 0

            case (state)
                //--------------------------------------------------
                // IDLE
                //--------------------------------------------------
                S_IDLE: begin
                    // 멈춰 있을 때 속도 관련 값 초기화
                    interval  <= BASE_SPEED;
                    speed_cnt <= 32'd0;
                    // LED를 전부 끄고 싶으면 아래 주석을 해제
                    // led_out   <= 8'd0;

                    if (start_spin) begin
                        // 랜덤 시작 위치
                        pos <= lfsr[2:0];
                    end
                end

                //--------------------------------------------------
                // RUN (빠르게 회전)
                //--------------------------------------------------
                S_RUN: begin
                    spin_active <= 1'b1;

                    if (speed_cnt >= interval) begin
                        speed_cnt <= 32'd0;
                        pos       <= pos + 3'd1;  // 0~7 순환

                        // 서서히 감속 시작
                        if (interval < (BASE_SPEED + SLOW_STEP * 4))
                            interval <= interval + SLOW_STEP;
                    end else begin
                        speed_cnt <= speed_cnt + 32'd1;
                    end
                end

                //--------------------------------------------------
                // SLOW_DOWN (느리게 회전)
                //--------------------------------------------------
                S_SLOW: begin
                    spin_active <= 1'b1;

                    if (speed_cnt >= interval) begin
                        speed_cnt <= 32'd0;
                        pos       <= pos + 3'd1;

                        // 더 급격한 감속
                        if (interval < MAX_INTERVAL)
                            interval <= interval + (SLOW_STEP << 1);
                    end else begin
                        speed_cnt <= speed_cnt + 32'd1;
                    end
                end

                //--------------------------------------------------
                // STOP_RESULT
                //--------------------------------------------------
                S_STOP: begin
                    // 최종 위치 확정
                    result_pos <= pos;
                    spin_done  <= 1'b1;   // FSM에 회전 종료 알림 (1클럭)
                    // led_out 는 led_pattern으로 현재 pos 유지
                end

                default: begin
                    // 안전빵
                end
            endcase
        end
    end

endmodule
