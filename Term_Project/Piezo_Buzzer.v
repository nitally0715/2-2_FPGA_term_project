//===========================================================
// Piezo_Buzzer.v
// - FSM 상태에 따라 다른 톤/멜로디 출력
// - START_SPIN: 빠른 반복음
// - SPIN_WAIT: 감속 반복음
// - WIN_DISPLAY: 짧은 멜로디
// - LOSE_DISPLAY: 낮은 경고음
//===========================================================

module Piezo_Buzzer(
    input  wire clk,          // 50MHz 기준
    input  wire rst,
    input  wire [3:0] state,
    output reg  piezo
);

    //----------------------------------------------------
    // 상태코드(FSM과 반드시 일치)
    //----------------------------------------------------
    localparam S_START_SPIN   = 4'd4;
    localparam S_SPIN_WAIT    = 4'd5;
    localparam S_WIN_DISPLAY  = 4'd7;
    localparam S_LOSE_DISPLAY = 4'd8;

    //----------------------------------------------------
    // Piezo는 단순 square wave → divider로 톤 생성
    //----------------------------------------------------
    reg [31:0] cnt;
    reg [31:0] tone_div;   // 주파수 제어
    reg        enable;     // Piezo on/off

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt   <= 0;
            piezo <= 0;
            enable <= 0;
            tone_div <= 32'd0;
        end else begin

            //------------------------------------------------
            // 상태별 톤 설정
            //------------------------------------------------
            case (state)

                // --------------------------------------------
                // 1) 회전 시작 → 빠른 4kHz 부저음
                // --------------------------------------------
                S_START_SPIN: begin
                    enable   <= 1;
                    tone_div <= 32'd6250;  // 50MHz / 6250 = 8kHz → /2 → 약 4kHz
                end

                // --------------------------------------------
                // 2) SPIN_WAIT → 조금 느린 2.5~3kHz (중간 속도)
                // --------------------------------------------
                S_SPIN_WAIT: begin
                    enable   <= 1;
                    tone_div <= 32'd10000; // ~2.5kHz
                end

                // --------------------------------------------
                // 3) 승리 멜로디 (C → E → G → C)
                // --------------------------------------------
                S_WIN_DISPLAY: begin
                    enable <= 1;

                    // 멜로디 진행용 카운터
                    case (cnt[18:16])   // 약 150ms 단위
                        3'd0: tone_div <= 32'd38220; // C (261 Hz)
                        3'd1: tone_div <= 32'd30337; // E (329 Hz)
                        3'd2: tone_div <= 32'd25510; // G (392 Hz)
                        3'd3: tone_div <= 32'd38220; // C (261 Hz)
                        default: tone_div <= 32'd38220;
                    endcase
                end

                // --------------------------------------------
                // 4) 패배 → 낮은 경고음 300Hz
                // --------------------------------------------
                S_LOSE_DISPLAY: begin
                    enable   <= 1;
                    tone_div <= 32'd41666; // 300Hz
                end

                // --------------------------------------------
                // 5) 그 외 = 무음
                // --------------------------------------------
                default: begin
                    enable   <= 0;
                    tone_div <= 32'd0;
                end
            endcase


            //------------------------------------------------
            // Tone 생성 (Square Wave)
            //------------------------------------------------
            if (enable && tone_div != 0) begin
                cnt <= cnt + 1;
                if (cnt >= tone_div) begin
                    cnt   <= 0;
                    piezo <= ~piezo; // square wave
                end
            end else begin
                cnt   <= 0;
                piezo <= 0;
            end
        end
    end

endmodule
