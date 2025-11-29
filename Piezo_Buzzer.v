//======================================================================
// Piezo_Buzzer.v (Rhythm FIXED Version)
// - 멜로디 속도를 사람이 들을 수 있는 박자로 수정함
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
    // FSM 상태 정의
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
    // 기본 톤 주파수 분주
    //==========================================================
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
    // [수정] 비트 인덱스를 상향 조정하여 박자를 느리게 만듦
    //==========================================================
    always @(*) begin
        case (state)

            //==================================================
            // 룰렛 회전음 (spin_active == 1)
            //==================================================
            S_START_SPIN, S_SLOW_DOWN: begin
                if (spin_active)
                    tone_divider = 32'd50000;   // 500Hz
                else
                    tone_divider = 32'd0;
            end

            //==================================================
            // 패배음 : [25]번 비트 사용 (약 0.67초 주기 깜빡임)
            //==================================================
            S_LOSE_DISPLAY: begin
                // [수정] [20] -> [25] (속도 느리게)
                if ((mel_cnt[25] == 0)) 
                    tone_divider = 32'd90000;   // 277Hz (낮은음)
                else
                    tone_divider = 32'd0;
            end

            //==================================================
            // 일반 승리 : [25:23] 사용 (음 하나당 약 0.16초)
            // 딩(0.16s) -> 동(0.16s) -> 댕(0.16s) -> 무음...
            //==================================================
            S_WIN_DISPLAY: begin
                // [수정] [19:17] -> [25:23] (속도 느리게)
                case (mel_cnt[25:23])  
                    3'd0: tone_divider = 32'd35000;  // 딩
                    3'd1: tone_divider = 32'd50000;  // 동
                    3'd2: tone_divider = 32'd70000;  // 댕
                    default: tone_divider = 32'd0;   // 잠깐 쉬기
                endcase
            end

            //==================================================
            // GAME_CLEAR : [26:24] 사용 (음 하나당 약 0.33초)
            // 천천히 웅장하게
            //==================================================
            S_GAME_CLEAR: begin
                // [수정] [21:19] -> [26:24] (속도 느리게)
                case (mel_cnt[26:24])
                    3'd0: tone_divider = 32'd30000; // A
                    3'd1: tone_divider = 32'd35000; // B
                    3'd2: tone_divider = 32'd30000; // A
                    3'd3: tone_divider = 32'd45000; // G
                    default: tone_divider = 32'd0;
                endcase
            end

            default: tone_divider = 0;
        endcase
    end

    //==========================================================
    // 최종 piezo 출력 (무음 처리 포함)
    //==========================================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            piezo_out <= 0;
        else begin
            if (tone_divider == 0)
                piezo_out <= 0;
            else
                piezo_out <= tone_clk;
        end
    end

endmodule