//==============================================================
// Top_Roulette.v
// Casino Roulette 전체 시스템 통합 최상위 모듈
//==============================================================

module Top_Roulette(
    input  wire clk,       // 50MHz 보드 클럭
    input  wire rst,       // 전체 리셋

    //============== Button Switch 12개 ==============
    input wire KEY01, KEY02, KEY03, KEY04,
               KEY05, KEY06, KEY07, KEY08,
               KEY09, KEY10, KEY11, KEY12,

    //============== Text LCD (보드 핀 11개) ==============
    output wire [7:0] TLCD_D,   // D0~D7
    output wire       TLCD_E,
    output wire       TLCD_RS,
    output wire       TLCD_RW,

    //============== 7-segment (5 digit) ==============
    output wire [6:0] seg,
    output wire [4:0] an,

    //============== Roulette LED 8개 ==============
    output wire [7:0] roulette_led,

    //============== Piezo ==============
    output wire piezo_out
);

    //==========================================================
    // 상태 코드 상수 (FSM과 일치)
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
    // 1) Button_Keypad : 12 버튼 → key_valid / key_value
    //==========================================================
    wire       key_valid;
    wire [3:0] key_value;

    Button_Keypad keypad_btn(
        .clk   (clk),
        .rst   (rst),

        .key01 (KEY01),
        .key02 (KEY02),
        .key03 (KEY03),
        .key04 (KEY04),
        .key05 (KEY05),
        .key06 (KEY06),
        .key07 (KEY07),
        .key08 (KEY08),
        .key09 (KEY09),
        .key10 (KEY10),
        .key11 (KEY11),
        .key12 (KEY12),

        .key_valid (key_valid),
        .key_value (key_value)
    );

    //==========================================================
    // 2) FSM_Controller
    //==========================================================
    wire [3:0]  fsm_state;
    wire [2:0]  bet_count;
    wire [15:0] bet_amount;

    wire        clear_input;
    wire        start_spin;
    wire        update_money_req;
    wire        reset_round;

    wire        spin_done;
    wire        win_flag;
    wire        money_zero;
    wire        money_10000;
    wire [15:0] current_money;

    FSM_Controller fsm(
        .clk           (clk),
        .rst           (rst),

        .key_valid     (key_valid),
        .key_value     (key_value),

        .spin_done     (spin_done),
        .win_flag      (win_flag),
        .money_zero    (money_zero),
        .money_10000   (money_10000),
        .current_money (current_money),

        .state            (fsm_state),
        .bet_count        (bet_count),
        .bet_amount       (bet_amount),
        .clear_input      (clear_input),
        .start_spin       (start_spin),
        .update_money_req (update_money_req),
        .reset_round      (reset_round)
    );

    //==========================================================
    // 3) Roulette_LED
    //==========================================================
    wire [2:0] result_pos;
    wire       spin_active;

    Roulette_LED roulette(
        .clk         (clk),
        .rst         (rst),
        .start_spin  (start_spin),
        .led_out     (roulette_led),
        .result_pos  (result_pos),
        .spin_done   (spin_done),
        .spin_active (spin_active)
    );

    //==========================================================
    // 4) 사용자 베팅 번호 저장
    //==========================================================
    reg [3:0] prev_state;
    reg [1:0] num_store_idx;
    reg [2:0] user_num0, user_num1, user_num2, user_num3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            prev_state    <= S_IDLE;
            num_store_idx <= 2'd0;
            user_num0     <= 3'd0;
            user_num1     <= 3'd0;
            user_num2     <= 3'd0;
            user_num3     <= 3'd0;
        end else begin
            prev_state <= fsm_state;

            if (reset_round || clear_input) begin
                num_store_idx <= 2'd0;
                user_num0     <= 3'd0;
                user_num1     <= 3'd0;
                user_num2     <= 3'd0;
                user_num3     <= 3'd0;
            end
            else begin
                if (prev_state != S_NUMBER_INPUT && fsm_state == S_NUMBER_INPUT) begin
                    num_store_idx <= 2'd0;
                    user_num0     <= 3'd0;
                    user_num1     <= 3'd0;
                    user_num2     <= 3'd0;
                    user_num3     <= 3'd0;
                end
                else if (fsm_state == S_NUMBER_INPUT && key_valid) begin
                    if (key_value == 4'd11) begin   // '#'
                        num_store_idx <= 2'd0;
                        user_num0     <= 3'd0;
                        user_num1     <= 3'd0;
                        user_num2     <= 3'd0;
                        user_num3     <= 3'd0;
                    end
                    else if (key_value >= 4'd1 && key_value <= 4'd8) begin
                        if (num_store_idx < 2'd4) begin
                            case (num_store_idx)
                                2'd0: user_num0 <= key_value[2:0] - 3'd1;
                                2'd1: user_num1 <= key_value[2:0] - 3'd1;
                                2'd2: user_num2 <= key_value[2:0] - 3'd1;
                                2'd3: user_num3 <= key_value[2:0] - 3'd1;
                            endcase
                            if (num_store_idx < bet_count - 1 && num_store_idx < 2'd3)
                                num_store_idx <= num_store_idx + 2'd1;
                        end
                    end
                end
            end
        end
    end

    //==========================================================
    // 5) Hit_Check
    //==========================================================
    wire [2:0] hit_count;

    Hit_Check hit_checker(
        .clk       (clk),
        .rst       (rst),
        .bet_count  (bet_count),
        .result_pos (result_pos),
        .user_num0  (user_num0),
        .user_num1  (user_num1),
        .user_num2  (user_num2),
        .user_num3  (user_num3),
        .win_flag   (win_flag),
        .hit_count  (hit_count)
    );

    //==========================================================
    // 6) Money_Manager
    //==========================================================
    wire win_flag_out;

    Money_Manager money(
        .clk           (clk),
        .rst           (rst),

        .update_req    (update_money_req),
        .win_flag      (win_flag),
        .bet_amount    (bet_amount),
        .bet_count     (bet_count),
        .hit_count     (hit_count),

        .current_money (current_money),
        .money_zero    (money_zero),
        .money_10000   (money_10000),
        .win_flag_out  (win_flag_out)
    );

    //==========================================================
    // 7) LCD_Display + TextLCD_Controller
    //==========================================================
    wire [127:0] lcd_line1;
    wire [127:0] lcd_line2;

    LCD_Display lcd_disp(
        .clk           (clk),
        .rst           (rst),
        .state         (fsm_state),
        .bet_amount    (bet_amount),
        .bet_count     (bet_count),
        .current_money (current_money),
        .win_flag      (win_flag),
        .money_zero    (money_zero),
        // 사용자 입력 
        .num_store_idx (num_store_idx),
        .user_num0     (user_num0),
        .user_num1     (user_num1),
        .user_num2     (user_num2),
        .user_num3     (user_num3),
        
        .line1         (lcd_line1),
        .line2         (lcd_line2)
    );

    TextLCD_Controller lcd_core(
        .clk      (clk),
        .rst      (rst),
        .line1    (lcd_line1),
        .line2    (lcd_line2),
        .TLCD_D   (TLCD_D),
        .TLCD_E   (TLCD_E),
        .TLCD_RS  (TLCD_RS),
        .TLCD_RW  (TLCD_RW)
    );

    //==========================================================
    // 8) SevenSegment_Display
    //==========================================================
    SevenSegment_Display seg7(
        .clk          (clk),
        .rst          (rst),
        .current_money(current_money),
        .seg          (seg),
        .an           (an)
    );

    //==========================================================
    // 9) Piezo_Buzzer
    //==========================================================
    Piezo_Buzzer buzzer(
        .clk        (clk),
        .rst        (rst),
        .state      (fsm_state),
        .spin_active(spin_active),
        .win_flag   (win_flag),
        .piezo_out  (piezo_out)
    );

endmodule
