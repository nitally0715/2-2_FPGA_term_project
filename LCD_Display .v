//==============================================================
// LCD_Display.v  (Vivado Synthesizable Version)
//==============================================================

module LCD_Display(
    input  wire        clk,
    input  wire        rst,

    // FSM 입력
    input  wire [3:0]  state,
    input  wire [15:0] bet_amount,
    input  wire [2:0]  bet_count,
    input  wire [15:0] current_money,
    input  wire        win_flag,
    input  wire        money_zero,

    // LCD 출력 버퍼
    output reg [127:0] line1,
    output reg [127:0] line2
);

    //==========================================================
    // FSM CODE
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
    // 내부 버퍼
    //==========================================================
    reg [7:0] l1 [0:15];
    reg [7:0] l2 [0:15];

    integer i;

    //==========================================================
    // MONEY CLAMP
    //==========================================================
    reg [15:0] money_clamped;

    always @(*) begin
        money_clamped = (current_money > 10000) ? 10000 : current_money;
    end

    //==========================================================
    // ASCII 변환 함수
    //==========================================================
    function [7:0] to_ascii;
        input [3:0] d;
        begin
            to_ascii = 8'd48 + d;
        end
    endfunction

    reg [7:0] ascii_money [0:4];

    always @(*) begin
        ascii_money[0] = to_ascii((money_clamped / 10000) % 10);
        ascii_money[1] = to_ascii((money_clamped / 1000)  % 10);
        ascii_money[2] = to_ascii((money_clamped / 100)   % 10);
        ascii_money[3] = to_ascii((money_clamped / 10)    % 10);
        ascii_money[4] = to_ascii((money_clamped)         % 10);
    end

    //==========================================================
    // 메인 LCD 문자열 생성
    //==========================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 16; i = i+1) begin
                l1[i] <= 8'h20;
                l2[i] <= 8'h20;
            end
        end else begin

            // STEP 1: 모든 값을 공백으로 초기화 (blocking =)
            for (i = 0; i < 16; i = i+1) begin
                l1[i] = 8'h20;
                l2[i] = 8'h20;
            end

            // STEP 2: 상태에 따라 문자열 업데이트 (<=)
            case (state)

                S_IDLE: begin
                    l1[0] <= "P"; l1[1] <= "R"; l1[2] <= "E"; l1[3] <= "S";
                    l1[4] <= "S"; l1[5] <= " "; l1[6] <= "*"; l1[7] <= " ";
                    l1[8] <= "T"; l1[9] <= "O"; l1[10] <= " "; l1[11] <= "S";
                    l1[12] <= "T"; l1[13] <= "A"; l1[14] <= "R"; l1[15] <= "T";
                end

                S_BET_SELECT: begin
                    l1[0] <= "B"; l1[1] <= "E"; l1[2] <= "T"; l1[3] <= " ";
                    l1[4] <= "C"; l1[5] <= "O"; l1[6] <= "U"; l1[7] <= "N";
                    l1[8] <= "T"; l1[9] <= "("; l1[10] <= "1"; l1[11] <= "-";
                    l1[12] <= "4"; l1[13] <= ")";
                end

                S_NUMBER_INPUT: begin
                    l1[0] <= "I"; l1[1] <= "N"; l1[2] <= "P";
                    l1[3] <= "U"; l1[4] <= "T";
                end

                S_WIN_DISPLAY: begin
                    l1[0] <= "Y"; l1[1] <= "O"; l1[2] <= "U"; l1[3] <= " ";
                    l1[4] <= "W"; l1[5] <= "I"; l1[6] <= "N"; l1[7] <= "!";

                    l2[7] <= ascii_money[0];
                    l2[8] <= ascii_money[1];
                    l2[9] <= ascii_money[2];
                    l2[10] <= ascii_money[3];
                    l2[11] <= ascii_money[4];
                end

                S_LOSE_DISPLAY: begin
                    l1[0] <= "T"; l1[1] <= "R"; l1[2] <= "Y";
                    l1[3] <= " "; l1[4] <= "A"; l1[5] <= "G";
                    l1[6] <= "A"; l1[7] <= "I"; l1[8] <= "N";

                    l2[7] <= ascii_money[0];
                    l2[8] <= ascii_money[1];
                    l2[9] <= ascii_money[2];
                    l2[10] <= ascii_money[3];
                    l2[11] <= ascii_money[4];
                end

                S_GAME_OVER: begin
                    l1[0] <= "G"; l1[1] <= "A"; l1[2] <= "M"; l1[3] <= "E";
                    l1[4] <= " "; l1[5] <= "O"; l1[6] <= "V"; l1[7] <= "E";
                    l1[8] <= "R";
                end
            endcase

        end
    end

    //==========================================================
    // PACK to 128-bit line
    //==========================================================
    always @(*) begin
        line1 = { l1[0], l1[1], l1[2], l1[3], l1[4], l1[5], l1[6], l1[7],
                  l1[8], l1[9], l1[10], l1[11], l1[12], l1[13], l1[14], l1[15] };

        line2 = { l2[0], l2[1], l2[2], l2[3], l2[4], l2[5], l2[6], l2[7],
                  l2[8], l2[9], l2[10], l2[11], l2[12], l2[13], l2[14], l2[15] };
    end

endmodule
