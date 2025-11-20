//======================================================================
// Top_Roulette.v  (전체 Roulette 시스템 통합)
// - FSM, Keypad, LCD, LED Roulette, Piezo, 7-seg, Money 통합
// - 50MHz 입력 클럭 기준
//======================================================================

module Top_Roulette(
    input  wire clk,      // ★ 50MHz system clock
    input  wire rst,      // Active-high reset

    // Keypad
    input  wire [3:0] row,
    output wire [3:0] col,

    // 8 LEDs for roulette ring
    output wire [7:0] led,

    // 7-Segment
    output wire [6:0] seg,
    output wire [3:0] an,

    // LCD 16x2 (HD44780)
    output wire lcd_rs,
    output wire lcd_rw,
    output wire lcd_e,
    output wire [7:0] lcd_data,

    // Piezo
    output wire piezo
);

    //------------------------------------------------------------
    // Internal wires
    //------------------------------------------------------------

    // Keypad
    wire key_valid;
    wire [3:0] key_value;

    // FSM
    wire start_spin;
    wire win_flag;
    wire lose_flag;
    wire [15:0] bet_amount;
    wire [2:0]  bet_count;
    wire [3:0]  fsm_state;

    // Roulette
    wire spinning_done;
    wire [2:0] roulette_pos;

    // Money
    wire [15:0] current_money;


    //------------------------------------------------------------
    // Keypad Module
    //------------------------------------------------------------
    Keypad_Module keypad_inst (
        .clk(clk),
        .rst(rst),
        .row(row),
        .col(col),
        .key_valid(key_valid),
        .key_value(key_value)
    );


    //------------------------------------------------------------
    // FSM Controller
    //------------------------------------------------------------
    FSM_Controller fsm_inst (
        .clk(clk),
        .rst(rst),
        .key_valid(key_valid),
        .key_value(key_value),
        .spin_done(spinning_done),
        .roulette_pos(roulette_pos),
        .current_money(current_money),

        .start_spin(start_spin),
        .win_flag(win_flag),
        .lose_flag(lose_flag),
        .bet_amount(bet_amount),
        .bet_count(bet_count),
        .state(fsm_state)
    );


    //------------------------------------------------------------
    // Roulette LED Spinner
    //------------------------------------------------------------
    Roulette_LED roulette_inst (
        .clk(clk),
        .rst(rst),
        .start(start_spin),
        .led(led),
        .pos(roulette_pos),
        .spin_done(spinning_done)
    );


    //------------------------------------------------------------
    // Money Manager
    //------------------------------------------------------------
    Money_Manager money_inst (
        .clk(clk),
        .rst(rst),
        .state(fsm_state),
        .bet_amount(bet_amount),
        .bet_count(bet_count),
        .win_flag(win_flag),
        .current_money(current_money)
    );


    //------------------------------------------------------------
    // 7-Segment Display
    //------------------------------------------------------------
    SevenSegment_Display seg_inst (
        .clk(clk),
        .rst(rst),
        .value(current_money),
        .seg(seg),
        .an(an)
    );


    //------------------------------------------------------------
    // LCD (16x2, HD44780)
    //------------------------------------------------------------
    LCD_Display lcd_inst (
        .clk(clk),
        .rst(rst),
        .state(fsm_state),
        .bet_amount(bet_amount),
        .bet_count(bet_count),
        .current_money(current_money),
        .win_flag(win_flag),
        .lose_flag(lose_flag),

        .lcd_rs(lcd_rs),
        .lcd_rw(lcd_rw),
        .lcd_e(lcd_e),
        .lcd_data(lcd_data)
    );


    //------------------------------------------------------------
    // Piezo Sound Generator
    //------------------------------------------------------------
    Piezo_Buzzer piezo_inst (
        .clk(clk),
        .rst(rst),
        .state(fsm_state),
        .piezo(piezo)
    );

endmodule
