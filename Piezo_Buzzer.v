//======================================================================
// Piezo_Buzzer.v (50MHz)
// - FSM state / spin_active 에 따라 효과음 & 멜로디 출력
//   * START_SPIN, SLOW_DOWN : 회전 효과음
//   * WIN_DISPLAY          : 짧은 승리 멜로디 (딩↗딩↘딩)
//   * LOSE_DISPLAY         : 낮은 패배음
//   * GAME_CLEAR           : 간단 마리오 클리어 느낌 4음
//   * 나머지 상태          : 무음
//======================================================================

module Piezo_Buzzer(
    input  wire       clk,         // 50MHz
    input  wire       rst,
    input  wire [3:0] state,
    input  wire       spin_active, // 룰렛 회전 중이면 1
    input  wire       win_flag,    // (지금은 안 써도 됨, 포트만 유지)

    output reg        piezo_out
);

    // FSM 상태코드 (FSM_Controller랑 맞춰야 함)
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

    //==========================================================
    // 1) 멜로디용 free-running 카운터
    //    -> 여러 비트를 잘라서 "몇 번째 음인지"로 사용
    //==========================================================
    reg [23:0] mel_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst)
            mel_cnt <= 24'd0;
        else
            mel_cnt <= mel_cnt + 24'd1;
    end

    //==========================================================
    // 2) 톤 분주기 : 50MHz -> 원하는 주파수의 사각파
    //
    //    tone_divider = 0 : 무음
    //    tone_divider > 0 : clk을 나눠서 tone_clk 생성
    //
    //    대략적인 주파수 (50MHz 기준)
    //      25000 -> 약 1kHz
    //      20000 -> 약 1.25kHz
    //      15000 -> 약 1.6kHz
    //      10000 -> 약 2.5kHz
    //      50000 -> 약 500Hz
    //==========================================================
    reg [31:0] tone_divider;
    reg [31:0] tone_cnt;
    reg        tone_clk;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tone_cnt  <= 32'd0;
            tone_clk  <= 1'b0;
        end else begin
            if (tone_divider == 32'd0) begin
                // 무음일 때는 카운터 리셋 + 출력 0
                tone_cnt <= 32'd0;
                tone_clk <= 1'b0;
            end else begin
                if (tone_cnt >= tone_divider) begin
                    tone_cnt <= 32'd0;
                    tone_clk <= ~tone_clk;
                end else begin
                    tone_cnt <= tone_cnt + 32'd1;
                end
            end
        end
    end

    //==========================================================
    // 3) 상태별 tone_divider 결정
    //==========================================================
    always @(*) begin
        // 기본값 : 무음
        tone_divider = 32'd0;

        case (state)

            //--------------------------------------------------
            // 회전 효과음 : START_SPIN / SLOW_DOWN + spin_active
            //--------------------------------------------------
            S_START_SPIN,
            S_SLOW_DOWN: begin
                if (spin_active) begin
                    // mel_cnt 일부 비트로 약간의 "위잉위잉" 느낌
                    case (mel_cnt[18:17])
                        2'd0: tone_divider = 32'd22000; // 약 1.1kHz
                        2'd1: tone_divider = 32'd18000; // 약 1.4kHz
                        2'd2: tone_divider = 32'd15000; // 약 1.6kHz
                        default: tone_divider = 32'd18000;
                    endcase
                end else begin
                    tone_divider = 32'd0; // 회전 안 하면 무음
                end
            end

            //--------------------------------------------------
            // WIN_DISPLAY : 짧은 승리 멜로디 (딩↗딩↘딩)
            //--------------------------------------------------
            S_WIN_DISPLAY: begin
                case (mel_cnt[20:19])   // 4단계 반복 (note당 약 수십 ms)
                    2'd0: tone_divider = 32'd20000; // 중간음
                    2'd1: tone_divider = 32'd15000; // 좀 더 높은 음
                    2'd2: tone_divider = 32'd20000; // 중간음
                    2'd3: tone_divider = 32'd25000; // 약간 낮은 음
                    default: tone_divider = 32'd0;
                endcase
            end

            //--------------------------------------------------
            // LOSE_DISPLAY : 낮은 패배음 (웅-)
            //--------------------------------------------------
            S_LOSE_DISPLAY: begin
                tone_divider = 32'd50000; // 약 500Hz, 낮은 음
            end

            //--------------------------------------------------
            // GAME_CLEAR : 간단 4음 (A-B-A-G 느낌)
            //--------------------------------------------------
            S_GAME_CLEAR: begin
                case (mel_cnt[21:19])   // 8단계 중 앞의 4단계 사용
                    3'd0: tone_divider = 32'd17000; // A
                    3'd1: tone_divider = 32'd15000; // B (조금 높게)
                    3'd2: tone_divider = 32'd17000; // A
                    3'd3: tone_divider = 32'd22000; // G (조금 낮게)
                    default: tone_divider = 32'd0;
                endcase
            end

            //--------------------------------------------------
            // GAME_OVER : 아주 낮은 경고음
            //--------------------------------------------------
            S_GAME_OVER: begin
                tone_divider = 32'd80000; // 더 낮은 음
            end

            //--------------------------------------------------
            // 나머지 상태 : 무음
            //--------------------------------------------------
            default: begin
                tone_divider = 32'd0;
            end
        endcase
    end

    //==========================================================
    // 4) 최종 piezo 출력
    //==========================================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            piezo_out <= 1'b0;
        else begin
            if (tone_divider == 32'd0)
                piezo_out <= 1'b0;   // 무음
            else
                piezo_out <= tone_clk; // 사각파 출력
        end
    end

endmodule
