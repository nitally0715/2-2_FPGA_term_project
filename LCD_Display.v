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
    
    // 사용자 입력 KEY_PAD
    input  wire [1:0] num_store_idx,
    input  wire [3:0] user_num0,
    input  wire [3:0] user_num1,
    input  wire [3:0] user_num2,
    input  wire [3:0] user_num3,


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
    function [7:0] disp_num;
        input [3:0] n;
        begin
            if (n == 3'd0)
                disp_num = 8'h20; // space when empty
            else
                disp_num = to_ascii(n); // show keypad digit (1~8)
        end
    endfunction

    reg [7:0] ascii_money [0:4];
    reg [7:0] ascii_bet   [0:4];   

    always @(*) begin
        ascii_money[0] = to_ascii((money_clamped / 10000) % 10);
        ascii_money[1] = to_ascii((money_clamped / 1000)  % 10);
        ascii_money[2] = to_ascii((money_clamped / 100)   % 10);
        ascii_money[3] = to_ascii((money_clamped / 10)    % 10);
        ascii_money[4] = to_ascii((money_clamped)         % 10);
        
        // ★ bet_amount 표시용
        ascii_bet[0] = to_ascii((bet_amount / 10000) % 10);
        ascii_bet[1] = to_ascii((bet_amount / 1000)  % 10);
        ascii_bet[2] = to_ascii((bet_amount / 100)   % 10);
        ascii_bet[3] = to_ascii((bet_amount / 10)    % 10);
        ascii_bet[4] = to_ascii((bet_amount)         % 10);
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
                
                // 1. S_IDLE: 게임 시작 대기 화면 
                S_IDLE: begin
                    l1[0] <= "P"; l1[1] <= "R"; l1[2] <= "E"; l1[3] <= "S";
                    l1[4] <= "S"; l1[5] <= " "; l1[6] <= "*"; l1[7] <= " ";
                    l1[8] <= "T"; l1[9] <= "O"; l1[10] <= " "; l1[11] <= "S";
                    l1[12] <= "T"; l1[13] <= "A"; l1[14] <= "R"; l1[15] <= "T";
                    
                    l2[0] <= "M"; l2[1] <= "O"; l2[2] <= "N"; l2[3] <= "E";
                    l2[4] <= "Y"; l2[5] <= ":"; l2[6] <= " "; 
                    l2[7] <= ascii_money[0];
                    l2[8] <= ascii_money[1];
                    l2[9] <= ascii_money[2];
                    l2[10] <= ascii_money[3];
                    l2[11] <= ascii_money[4];
                end
                
                // 2. BET_MONEY: 베팅 금액 입력
                S_BET_MONEY: begin
                    l1[0] <= "B"; l1[1] <= "E"; l1[2] <= "T"; l1[3] <= " ";
                    l1[4] <= "M"; l1[5] <= "O"; l1[6] <= "N"; l1[7] <= "E";
                    l1[8] <= "Y"; l1[9] <= " "; l1[10] <= "("; l1[11] <= "O";
                    l1[12] <= "K"; l1[13] <= ")";
                                        
                    l2[0] <= "["; l2[1] <= "1"; l2[2] <= "~";
                    l2[3] <= ascii_money[0];
                    l2[4] <= ascii_money[1];
                    l2[5] <= ascii_money[2];
                    l2[6] <= ascii_money[3];
                    l2[7] <= ascii_money[4];
                    l2[8] <= "]"; l2[9] <= ":"; l2[10] <= " "; 
                    l2[11] <= ascii_bet[0];
                    l2[12] <= ascii_bet[1];
                    l2[13] <= ascii_bet[2];
                    l2[14] <= ascii_bet[3];
                    l2[15] <= ascii_bet[4];
                end

                // 3. BET_SELECT: 베팅 개수 선택
                S_BET_SELECT: begin
                    l1[0] <= "S"; l1[1] <= "E"; l1[2] <= "L"; l1[3] <= "E";
                    l1[4] <= "C"; l1[5] <= "T"; l1[6] <= " "; l1[7] <= "C";
                    l1[8] <= "N"; l1[9] <= "T"; l1[10] <= " "; l1[11] <= "[";
                    l1[12] <= "1"; l1[13] <= "~"; l1[14] <= "4"; l1[15] <= "]";
                    
                    l2[0] <= "C"; l2[1] <= "N"; l2[2] <= "T"; l2[3] <= ":";
                    
                    if (bet_count == 3'd0)
                        l2[4] <= 8'h20; // space
                    else
                        l2[4] <= to_ascii(bet_count);
   
                    l2[5] <= " ";
                    l2[6] <= "O"; l2[7] <= "K";
                    l2[8] <= ":"; l2[9] <= "*"; l2[10] <= " "; l2[11] <= "C";
                    l2[12] <= "L"; l2[13] <= "R"; l2[14] <= ":"; l2[15] <= "#";                    
                end

                // 4. NUMBER_INPUT: 룰렛 번호 입력(1~8)
                S_NUMBER_INPUT: begin
                    l1[0] <= "P"; l1[1] <= "I"; l1[2] <= "C"; l1[3] <= "K";
                    l1[4] <= " "; l1[5] <= "N"; l1[6] <= "U"; l1[7] <= "M";
                    l1[8] <= " "; l1[9] <= "["; l1[10] <= "1"; l1[11] <= "~";
                    l1[12] <= "8"; l1[13] <= "]"; l1[14] <= " "; l1[15] <= " ";
                    
                    l2[0] <= "I"; l2[1] <= "N"; l2[2] <= "P"; l2[3] <= "U"; 
                    l2[4] <= "T"; l2[5] <= ":"; 
                    l2[6] <= disp_num(user_num0); 
                    l2[7] <= disp_num(user_num1); 
                    l2[8] <= disp_num(user_num2);  
                    l2[9] <= disp_num(user_num3); 
                    
                    l2[10] <= " "; l2[11] <= "C";
                    l2[12] <= "L"; l2[13] <= "R"; l2[14] <= ":"; l2[15] <= "#";
                end
                
                // 5. START_SPIN: 회전 시작
                S_START_SPIN: begin
                    l1[0] <= "S"; l1[1] <= "P"; l1[2] <= "I"; l1[3] <= "N";
                    l1[4] <= " "; l1[5] <= "S"; l1[6] <= "T"; l1[7] <= "A";
                    l1[8] <= "R"; l1[9] <= "T"; l1[10] <= "!"; l1[11] <= "!";
                    l1[12] <= " "; l1[13] <= " "; l1[14] <= " "; l1[15] <= " ";
                    
                    l2[0] <= "G"; l2[1] <= "O"; l2[2] <= "O"; l2[3] <= "D";
                    l2[4] <= " "; l2[5] <= "L"; l2[6] <= "U"; l2[7] <= "C";
                    l2[8] <= "K"; l2[9] <= "."; l2[10] <= "."; l2[11] <= ".";
                    l2[12] <= "!"; l2[13] <= " "; l2[14] <= " "; l2[15] <= " ";
                end 
                
                // 6. SLOW_DOWN: 속도 감소
                S_SLOW_DOWN: begin
                    l1[0] <= "S"; l1[1] <= "L"; l1[2] <= "O"; l1[3] <= "W";
                    l1[4] <= "I"; l1[5] <= "N"; l1[6] <= "G"; l1[7] <= " ";
                    l1[8] <= "D"; l1[9] <= "O"; l1[10] <= "W"; l1[11] <= "N";
                    l1[12] <= "."; l1[13] <= "."; l1[14] <= "."; l1[15] <= " ";
                    
                    l2[0] <= "W"; l2[1] <= "A"; l2[2] <= "I"; l2[3] <= "T";
                    l2[4] <= " "; l2[5] <= "A"; l2[6] <= " "; l2[7] <= "M";
                    l2[8] <= "O"; l2[9] <= "M"; l2[10] <= "E"; l2[11] <= "N";
                    l2[12] <= "T"; l2[13] <= "."; l2[14] <= "."; l2[15] <= "!";
                end
                
                // 7. STOP_RESULT: 결과 정지 
                S_STOP_RESULT: begin
                    l1[0] <= "R"; l1[1] <= "E"; l1[2] <= "S"; l1[3] <= "U";
                    l1[4] <= "L"; l1[5] <= "T"; l1[6] <= " "; l1[7] <= "S";
                    l1[8] <= "T"; l1[9] <= "O"; l1[10] <= "P"; l1[11] <= "!";
                    l1[12] <= "!"; l1[13] <= " "; l1[14] <= " "; l1[15] <= " ";
                    
                    l2[0] <= "C"; l2[1] <= "H"; l2[2] <= "E"; l2[3] <= "C";
                    l2[4] <= "K"; l2[5] <= "I"; l2[6] <= "N"; l2[7] <= "G";
                    l2[8] <= "."; l2[9] <= "."; l2[10] <= "."; l2[11] <= " ";
                    l2[12] <= " "; l2[13] <= " "; l2[14] <= " "; l2[15] <= " ";
                end
                
                // 8. WIN_DISPLAY: 승리 메세지
                S_WIN_DISPLAY: begin
                    l1[0] <= "★"; l1[1] <= "Y"; l1[2] <= "O"; l1[3] <= "U";
                    l1[4] <= " "; l1[5] <= "W"; l1[6] <= "I"; l1[7] <= "N";
                    l1[8] <= "!"; l1[9] <= "!"; l1[10] <= "★"; l1[11] <= " ";

                    l2[0] <= "M"; l2[1] <= "O"; l2[2] <= "N"; l2[3] <= "E";
                    l2[4] <= "Y"; l2[5] <= ":"; l2[6] <= " "; 
                    l2[7] <= ascii_money[0];
                    l2[8] <= ascii_money[1];
                    l2[9] <= ascii_money[2];
                    l2[10] <= ascii_money[3];
                    l2[11] <= ascii_money[4];
                end

                // 9. LOSE_DISPLAY: 패배 메세지
                S_LOSE_DISPLAY: begin
                    l1[0] <= "T"; l1[1] <= "R"; l1[2] <= "Y";
                    l1[3] <= " "; l1[4] <= "A"; l1[5] <= "G";
                    l1[6] <= "A"; l1[7] <= "I"; l1[8] <= "N"; l1[9] <= ".";
                    l1[10] <= "."; l1[11] <= ".";
                    
                    
                    l2[0] <= "M"; l2[1] <= "O"; l2[2] <= "N"; l2[3] <= "E";
                    l2[4] <= "Y"; l2[5] <= ":"; l2[6] <= " "; 
                    l2[7] <= ascii_money[0];
                    l2[8] <= ascii_money[1];
                    l2[9] <= ascii_money[2];
                    l2[10] <= ascii_money[3];
                    l2[11] <= ascii_money[4];
                end

                // 10. UPDATE_MONEY: 돈 계산 중
                S_UPDATE_MONEY: begin
                    l1[0] <= "U"; l1[1] <= "P"; l1[2] <= "D"; l1[3] <= "A";
                    l1[4] <= "I"; l1[5] <= "T"; l1[6] <= "I"; l1[7] <= "N";
                    l1[8] <= "G"; l1[9] <= " "; l1[10] <= "M"; l1[11] <= "O";
                    l1[12] <= "N"; l1[13] <= "E"; l1[14] <= "Y"; l1[15] <= " ";
                    
                    l2[0] <= "P"; l2[1] <= "L"; l2[2] <= "E"; l2[3] <= "A";
                    l2[4] <= "S"; l2[5] <= "E"; l2[6] <= " "; l2[7] <= "W";
                    l2[8] <= "A"; l2[9] <= "I"; l2[10] <= "T"; l2[11] <= ".";
                    l2[12] <= "."; l2[13] <= "."; l2[14] <= " "; l2[15] <= " ";
                end
                
                // 11. NEXT_STAGE: 다음 라운드로
                S_NEXT_STAGE: begin
                    l1[0] <= "N"; l1[1] <= "E"; l1[2] <= "X"; l1[3] <= "T";
                    l1[4] <= " "; l1[5] <= "R"; l1[6] <= "O"; l1[7] <= "U";
                    l1[8] <= "N"; l1[9] <= "D"; l1[10] <= "?"; l1[11] <= "?";
                    l1[12] <= " "; l1[13] <= " "; l1[14] <= " "; l1[15] <= " ";
                    
                    l2[0] <= "P"; l2[1] <= "R"; l2[2] <= "E"; l2[3] <= "S";
                    l2[4] <= "S"; l2[5] <= " "; l2[6] <= "*"; l2[7] <= " ";
                    l2[8] <= "T"; l2[9] <= "O"; l2[10] <= " "; l2[11] <= "G";
                    l2[12] <= "O"; l2[13] <= "!"; l2[14] <= "!"; l2[15] <= " ";
                end
                
                // 12. GAME_OVER: 게임 오버(파산)
                S_GAME_OVER: begin
                    l1[0] <= "G"; l1[1] <= "A"; l1[2] <= "M"; l1[3] <= "E";
                    l1[4] <= " "; l1[5] <= "O"; l1[6] <= "V"; l1[7] <= "E";
                    l1[8] <= "R"; l1[9] <= "!"; l1[10] <= "!"; l1[11] <= " ";
                    l1[12] <= " "; l1[13] <= " "; l1[14] <= " "; l1[15] <= " ";
                    
                    l2[0] <= "Y"; l2[1] <= "O"; l2[2] <= "U"; l2[3] <= " ";
                    l2[4] <= "L"; l2[5] <= "O"; l2[6] <= "S"; l2[7] <= "T";
                    l2[8] <= " "; l2[9] <= "M"; l2[10] <= "O"; l2[11] <= "N";
                    l2[12] <= "E"; l2[13] <= "Y"; l2[14] <= " "; l2[15] <= " ";
                end
                
                // 13. GAME_CLEAR: 목표 금액 달성
                S_GAME_CLEAR: begin
                    l1[0] <= "★"; l1[1] <= "G"; l1[2] <= "A"; l1[3] <= "M";
                    l1[4] <= "E"; l1[5] <= " "; l1[6] <= "C"; l1[7] <= "L";
                    l1[8] <= "E"; l1[9] <= "A"; l1[10] <= "R"; l1[11] <= "★";
                    l1[12] <= " "; l1[13] <= " "; l1[14] <= " "; l1[15] <= " ";
                    
                    l2[0] <= "M"; l2[1] <= "O"; l2[2] <= "N"; l2[3] <= "E";
                    l2[4] <= "Y"; l2[5] <= ":"; l2[6] <= " "; 
                    l2[7] <= ascii_money[0];
                    l2[8] <= ascii_money[1];
                    l2[9] <= ascii_money[2];
                    l2[10] <= ascii_money[3];
                    l2[11] <= ascii_money[4];
                    l2[12] <= "!"; l2[13] <= "!";
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
