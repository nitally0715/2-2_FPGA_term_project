//======================================================================
// Piezo_Buzzer.v
// 상태에 따라 룰렛 회전음 / 승리 멜로디 / 패배음 출력
// 50MHz clk 기준
//======================================================================

module Piezo_Buzzer(
    input  wire clk,
    input  wire rst,

    input  wire [3:0] state,
    input  wire       spin_active,  // 룰렛이 실제 회전 중이면 1
    input  wire       win_flag,     // 승리 여부

    output reg        piezo_out
);

    //==========================================================
    // FSM 상태 정의 (사용자가 사용 중인 FSM과 동일)
    //==========================================================
    localparam  S_IDLE         = 4'd0,
                S_BET_MONEY    = 4'd1,
                S_BET_SELECT   = 4'd2,
                S_NUMBER_INPUT = 4'd3,
                S_START_SPIN   = 4'd4,
                S_SLOW_DOWN    = 4'd5,
                S_STOP_RESULT  = 4'd6,
                S_WIN_DISPLAY  = 4'd7,
                S_LOSE_DISPLAY = 4'd8,
                S_UPDATE_MONEY = 4'd9,
                S_CHECK_MONEY  = 4'd10,
                S_NEXT_STAGE   = 4'd11,
                S_GAME_OVER    = 4'd12,
                S_GAME_CLEAR   = 4'd13;

    //==========================================================
    // 기본 톤 주파수 분주 (50MHz 기준)
    //==========================================================
    // tone_freq = 50,000,000 / (divider * 2)

    reg [31:0] tone_divider;
    reg [31:0] tone_cnt;
    reg        tone_clk;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tone_cnt <= 0;
            tone_clk <= 0;
        end else begin
            if (tone_cnt >= tone_divider) begin
                tone_cnt <= 0;
                tone_clk <= ~tone_clk;
            end else begin
                tone_cnt <= tone_cnt + 1;
            end
        end
    end

    //==========================================================
    // 멜로디 제어용 카운터
    //==========================================================
    reg [31:0] mel_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst)
            mel_cnt <= 0;
        else
            mel_cnt <= mel_cnt + 1;
    end

    //==========================================================
    // 마리오 클리어 / 승리 / 패배 / 회전음 주파수 설정
    //==========================================================

    always @(*) begin
        case (state)

            //==================================================
            // 룰렛 회전음 (spin_active == 1)
            // 짧은 비프 → 빠르게 반복되는 느낌
            //==================================================
            S_START_SPIN, S_SLOW_DOWN: begin
                if (spin_active)
                    tone_divider = 32'd50000;   // 약 500Hz
                else
                    tone_divider = 32'd0;
            end

            //==================================================
            // 패배음 - 낮은 삐- 삐- 두 번
            //==================================================
            S_LOSE_DISPLAY: begin
                if ((mel_cnt[20] == 0))
                    tone_divider = 32'd90000;   // 약 277Hz
                else
                    tone_divider = 32'd0;
            end

            //==================================================
            // 일반 승리 → 딩동댕
            //==================================================
            S_WIN_DISPLAY: begin
                case (mel_cnt[19:17])  // 3단계 딩 동 댕
                    3'd0: tone_divider = 32'd35000;  // 높은음
                    3'd1: tone_divider = 32'd50000;  // 중간음
                    3'd2: tone_divider = 32'd70000;  // 낮은음
                    default: tone_divider = 32'd0;
                endcase
            end

            //==================================================
            // GAME_CLEAR (10000원 도달)
            // 마리오 클리어 음악 간단 패턴
            // A B A G (느낌만 비슷하게)
            //==================================================
            S_GAME_CLEAR: begin
                case (mel_cnt[21:19])
                    3'd0: tone_divider = 32'd30000; // A (높음)
                    3'd1: tone_divider = 32'd35000; // B
                    3'd2: tone_divider = 32'd30000; // A
                    3'd3: tone_divider = 32'd45000; // G (조금 낮춤)
                    default: tone_divider = 32'd0;
                endcase
            end

            //==================================================
            // 나머지 상태는 무음
            //==================================================
            default: tone_divider = 0;
        endcase
    end

    //==========================================================
    // 최종 piezo 출력
    //==========================================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            piezo_out <= 0;
        else begin
            if (tone_divider == 0)
                piezo_out <= 0;
            else
                piezo_out <= tone_clk;   // 사각파 출력
        end
    end

endmodule
