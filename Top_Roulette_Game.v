//==============================================================
// Top_Roulette.v  (FIXED VERSION - NUMBER_INPUT 버그 수정)
//==============================================================

module Top_Roulette(
    input  wire clk,
    input  wire rst,

    //============== Button Switch 12개 ==============
    input wire KEY01, KEY02, KEY03, KEY04,
               KEY05, KEY06, KEY07, KEY08,
               KEY09, KEY10, KEY11, KEY12,

    //============== Text LCD ==============
    output wire [7:0] TLCD_D,
    output wire       TLCD_E,
    output wire       TLCD_RS,
    output wire       TLCD_RW,

    //============== 7-segment ==============
    output wire [6:0] seg,
    output wire [4:0] an,

    //============== Roulette LED ==============
    output wire [7:0] roulette_led,

    //============== Piezo ==============
    output wire piezo_out
);

    //==========================================================
    // FSM 상태 코드
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

    //==========================================================
    // 1) Button_Keypad
    //==========================================================
    wire       key_valid;
    wire [3:0] key_value;

    Button_Keypad keypad_btn(
        .clk   (clk),
        .rst   (rst),

        .key01(KEY01), .key02(KEY02), .key03(KEY03), .key04(KEY04),
        .key05(KEY05), .key06(KEY06), .key07(KEY07), .key08(KEY08),
        .key09(KEY09), .key10(KEY10), .key11(KEY11), .key12(KEY12),

        .key_valid(key_valid),
        .key_value(key_value)
    );

    //==========================================================
    // 2) FSM_Controller
    //==========================================================
    wire [3:0]  fsm_state;
    wire [2:0]  bet_count;
    wire [15:0] bet_amount;

    wire clear_input;
    wire start_spin;
    wire update_money_req;
    wire reset_round;

    wire spin_done;
    wire win_flag;
    wire money_zero;
    wire money_10000;
    wire [15:0] current_money;

    FSM_Controller fsm(
        .clk(clk), .rst(rst),

        .key_valid(key_valid),
        .key_value(key_value),

        .spin_done(spin_done),
        .win_flag(win_flag),
        .money_zero(money_zero),
        .money_10000(money_10000),
        .current_money(current_money),

        .state(fsm_state),
        .bet_count(bet_count),
        .bet_amount(bet_amount),
        .clear_input(clear_input),
        .start_spin(start_spin),
        .update_money_req(update_money_req),
        .reset_round(reset_round)
    );

    //==========================================================
    // 3) Roulette LED
    //==========================================================
    wire [2:0] result_pos;
    wire       spin_active;

    Roulette_LED roulette(
        .clk(clk), .rst(rst),
        .start_spin(start_spin),
        .led_out(roulette_led),
        .result_pos(result_pos),
        .spin_done(spin_done),
        .spin_active(spin_active)
    );
    //==========================================================
    // 3-1) LED 인덱스 역순 매핑 (물리 LED 순서 보정)
    //  - 코드 상 0~7 인덱스가 보드에서 반대로 보일 때 사용
    //==========================================================
    function [2:0] map_led;
        input [2:0] x;
        begin
            // 0↔7, 1↔6, 2↔5, 3↔4 로 뒤집는다고 가정
            map_led = 3'd7 - x;
        end
    endfunction

    wire [2:0] mapped_result_pos;
    assign mapped_result_pos = map_led(result_pos);

    //==========================================================
    // 4) 사용자 번호 입력 저장 (FIXED)
    //==========================================================
    reg [1:0] num_store_idx;
    reg [3:0] user_num0, user_num1, user_num2, user_num3;
    reg [3:0] display_num0, display_num1, display_num2, display_num3;

    reg [3:0] latched_num0, latched_num1, latched_num2, latched_num3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            num_store_idx <= 0;

            user_num0 <= 0; user_num1 <= 0; user_num2 <= 0; user_num3 <= 0;
            display_num0 <= 0; display_num1 <= 0; display_num2 <= 0; display_num3 <= 0;

        end else begin
            
            // 1) reset_round or clear_input → 전체 초기화
            if (reset_round || clear_input) begin
                num_store_idx <= 0;

                user_num0 <= 0; user_num1 <= 0; user_num2 <= 0; user_num3 <= 0;

                if (reset_round) begin
                    display_num0 <= 0; display_num1 <= 0;
                    display_num2 <= 0; display_num3 <= 0;
                end

            end
            // 2) NUMBER_INPUT 상태에서 key_valid 발생 → 숫자 저장
            else if (fsm_state == S_NUMBER_INPUT && key_valid) begin
                if (key_value == 4'd11) begin
                    // '#' → 전체 CLEAR
                    num_store_idx <= 0;

                    user_num0 <= 0; display_num0 <= 0;
                    user_num1 <= 0; display_num1 <= 0;
                    user_num2 <= 0; display_num2 <= 0;
                    user_num3 <= 0; display_num3 <= 0;

                end else if (key_value >= 1 && key_value <= 8) begin
                    if (num_store_idx < bet_count) begin
                        case (num_store_idx)
                            2'd0: begin user_num0 <= key_value; display_num0 <= key_value; end
                            2'd1: begin user_num1 <= key_value; display_num1 <= key_value; end
                            2'd2: begin user_num2 <= key_value; display_num2 <= key_value; end
                            2'd3: begin user_num3 <= key_value; display_num3 <= key_value; end
                        endcase

                        if (num_store_idx < bet_count - 1)
                            num_store_idx <= num_store_idx + 1;
                    end
                end
            end
        end
    end

    //==========================================================
    // 4-1) RESULT 스냅샷 (Hit_Check용)
    //==========================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            latched_num0 <= 0;
            latched_num1 <= 0;
            latched_num2 <= 0;
            latched_num3 <= 0;
        end
        else if (reset_round) begin
            latched_num0 <= 0;
            latched_num1 <= 0;
            latched_num2 <= 0;
            latched_num3 <= 0;
        end
        else if (start_spin) begin
            latched_num0 <= display_num0;
            latched_num1 <= display_num1;
            latched_num2 <= display_num2;
            latched_num3 <= display_num3;
        end
    end

    // 문자열을 0~7로 변환
    wire [2:0] hit_num0 = (latched_num0 == 0) ? 0 : (latched_num0 - 1);
    wire [2:0] hit_num1 = (latched_num1 == 0) ? 0 : (latched_num1 - 1);
    wire [2:0] hit_num2 = (latched_num2 == 0) ? 0 : (latched_num2 - 1);
    wire [2:0] hit_num3 = (latched_num3 == 0) ? 0 : (latched_num3 - 1);

    //==========================================================
    // 5) Hit_Check
    //==========================================================
    wire [2:0] hit_count;

    Hit_Check hit_checker(
        .clk(clk), .rst(rst),
        .bet_count(bet_count),
        .result_pos(mapped_result_pos),

        .user_num0(hit_num0),
        .user_num1(hit_num1),
        .user_num2(hit_num2),
        .user_num3(hit_num3),

        .hit_count(hit_count),
        .win_flag(win_flag)
    );

    //==========================================================
    // 6) Money_Manager
    //==========================================================
    wire win_flag_out;

    Money_Manager money(
        .clk(clk), .rst(rst),
        .update_req(update_money_req),
        .win_flag(win_flag),
        .bet_amount(bet_amount),
        .bet_count(bet_count),
        .hit_count(hit_count),
        .current_money(current_money),
        .money_zero(money_zero),
        .money_10000(money_10000),
        .win_flag_out(win_flag_out)
    );

    //==========================================================
    // 7) LCD_Display
    //==========================================================
    wire [127:0] lcd_line1;
    wire [127:0] lcd_line2;

    LCD_Display lcd_disp(
        .clk(clk), .rst(rst),
        .state(fsm_state),
        .bet_amount(bet_amount),
        .bet_count(bet_count),
        .current_money(current_money),
        .win_flag(win_flag),
        .money_zero(money_zero),

        .num_store_idx(num_store_idx),
        .user_num0(display_num0),
        .user_num1(display_num1),
        .user_num2(display_num2),
        .user_num3(display_num3),

        .line1(lcd_line1),
        .line2(lcd_line2)
    );

    TextLCD_Controller lcd_core(
        .clk(clk), .rst(rst),
        .line1(lcd_line1), .line2(lcd_line2),
        .TLCD_D(TLCD_D), .TLCD_E(TLCD_E),
        .TLCD_RS(TLCD_RS), .TLCD_RW(TLCD_RW)
    );

    //==========================================================
    // 8) Seven Segment
    //==========================================================
    SevenSegment_Display seg7(
        .clk(clk), .rst(rst),
        .current_money(current_money),
        .seg(seg), .an(an)
    );

    //==========================================================
    // 9) Piezo
    //==========================================================
    Piezo_Buzzer buzzer(
        .clk(clk), .rst(rst),
        .state(fsm_state),
        .spin_active(spin_active),
        .win_flag(win_flag),
        .piezo_out(piezo_out)
    );

endmodule
