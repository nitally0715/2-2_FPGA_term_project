//==============================================================
// LCD_Display.v - 16x2 LCD Controller (HD44780, 8bit mode)
//==============================================================

module LCD_Display(
    input  wire clk,
    input  wire rst,

    input  wire [3:0] state,
    input  wire [15:0] bet_amount,
    input  wire [2:0]  bet_count,
    input  wire [15:0] current_money,
    input  wire win_flag,
    input  wire lose_flag,

    output reg  lcd_rs,
    output reg  lcd_rw,
    output reg  lcd_e,
    output reg [7:0] lcd_data
);

    //----------------------------------------------------------
    // 클럭 분주 (LCD Enable 파형용)
    // HD44780은 최소 40~230ns 펄스 필요 → 느린 펄스 사용
    //----------------------------------------------------------
    reg [15:0] clkdiv;
    always @(posedge clk or posedge rst) begin
        if (rst) clkdiv <= 0;
        else     clkdiv <= clkdiv + 1;
    end
    wire slow_clk = clkdiv[10];   // 약 1/1024 속도 → 안정적


    //----------------------------------------------------------
    // LCD 내부 상태
    //----------------------------------------------------------
    reg [5:0]  init_step;
    reg [7:0]  cmd;
    reg [7:0]  data_byte;
    reg        sending_cmd;
    reg        sending_data;

    reg [5:0]  msg_idx;      // 문자열 인덱스
    reg [7:0]  message [0:31]; // 16자+16자 = 32바이트

    // 현재 FSM state 저장 (변동 감지)
    reg [3:0] prev_state;


    //----------------------------------------------------------
    // HD44780 LCD에 명령 전송
    //----------------------------------------------------------
    task lcd_cmd(input [7:0] c);
    begin
        lcd_rs   <= 0;
        lcd_rw   <= 0;
        lcd_data <= c;
        lcd_e    <= 1;
    end
    endtask

    //----------------------------------------------------------
    // HD44780 LCD에 데이터 전송
    //----------------------------------------------------------
    task lcd_data_write(input [7:0] d);
    begin
        lcd_rs   <= 1;
        lcd_rw   <= 0;
        lcd_data <= d;
        lcd_e    <= 1;
    end
    endtask

    //----------------------------------------------------------
    // 메시지 버퍼 초기화 (32칸 모두 공백)
    //----------------------------------------------------------
    task clear_msg;
        integer i;
        begin
            for (i = 0; i < 32; i = i + 1)
                message[i] = " ";
        end
    endtask


    //----------------------------------------------------------
    // 상태별 LCD 메시지 정의
    //----------------------------------------------------------
    task load_message(input [3:0] st);
        integer i;
        begin
            clear_msg();

            case (st)

                //--------------------------------------------------
                0: begin // IDLE
                    message_string(0, "PRESS STAR      ");
                    message_string(1, "TO START        ");
                end

                //--------------------------------------------------
                1: begin // BET_AMOUNT
                    message_string(0, "ENTER BET AMOUNT");
                    message_string(1, "PRESS * TO CONF ");
                end

                //--------------------------------------------------
                2: begin // BET_COUNT
                    message_string(0, "ENTER COUNT     ");
                    message_string(1, "1 TO 4          ");
                end

                //--------------------------------------------------
                3: begin // NUMBER_INPUT
                    message_string(0, "ENTER NUMBER    ");
                    message_string(1, "1 TO 8          ");
                end

                //--------------------------------------------------
                4,5: begin // SPINNING
                    message_string(0, "SPINNING...     ");
                    message_string(1, "                ");
                end

                //--------------------------------------------------
                6: begin // STOP_RESULT
                    message_string(0, "RESULT:         ");
                    message[16] = "0" + (roulette_pos + 1);
                end

                //--------------------------------------------------
                7: begin // WIN
                    message_string(0, "YOU WIN!!!      ");
                    message_string(1, "CONGRATS        ");
                end

                //--------------------------------------------------
                8: begin // LOSE
                    message_string(0, "TRY AGAIN       ");
                    message_string(1, "                ");
                end

                //--------------------------------------------------
                11: begin // GAME OVER
                    message_string(0, "GAME OVER       ");
                    message_string(1, "PRESS #         ");
                end

                //--------------------------------------------------
                default: begin
                    message_string(0, "                ");
                    message_string(1, "                ");
                end

            endcase
        end
    endtask


    //----------------------------------------------------------
    // 문자열 복사 함수 (line: 0=첫줄, 1=둘째줄)
    //----------------------------------------------------------
    task message_string(input integer line, input [127:0] str);
        integer i;
        begin
            for (i = 0; i < 16; i = i + 1)
                message[line*16 + i] = str[8*(15-i)+:8];
        end
    endtask


    //----------------------------------------------------------
    // LCD 초기화 → 메시지 → 화면 출력 FSM
    //----------------------------------------------------------
    reg [3:0]  lcd_state; 
    localparam LCD_INIT   = 0,
               LCD_IDLE   = 1,
               LCD_CLEAR  = 2,
               LCD_PRINT  = 3;

    always @(posedge slow_clk or posedge rst) begin
        if (rst) begin
            lcd_state  <= LCD_INIT;
            init_step  <= 0;
            msg_idx    <= 0;
            prev_state <= 4'hF;
        end else begin

            case (lcd_state)

                //--------------------------------------------------
                // (1) LCD 초기화 시퀀스
                //--------------------------------------------------
                LCD_INIT: begin
                    case (init_step)
                        0:  lcd_cmd(8'h38); // 8bit, 2줄
                        1:  lcd_cmd(8'h0C); // Display ON
                        2:  lcd_cmd(8'h01); // Clear display
                        3:  lcd_cmd(8'h06); // Entry mode
                        default: lcd_state <= LCD_IDLE;
                    endcase
                    init_step <= init_step + 1;
                end

                //--------------------------------------------------
                // (2) 상태가 바뀌면 새로운 메시지 로드 + Clear
                //--------------------------------------------------
                LCD_IDLE: begin
                    if (state != prev_state) begin
                        prev_state <= state;
                        load_message(state);
                        lcd_cmd(8'h01); // clear
                        msg_idx <= 0;
                        lcd_state <= LCD_PRINT;
                    end
                end

                //--------------------------------------------------
                // (3) 메시지 32바이트(DRAM에 2줄) 출력
                //--------------------------------------------------
                LCD_PRINT: begin

                    if (msg_idx == 0)
                        lcd_cmd(8'h80);   // Line 1 DDRAM addr = 0
                    else if (msg_idx == 16)
                        lcd_cmd(8'hC0);   // Line 2 addr = 0x40

                    lcd_data_write(message[msg_idx]);
                    msg_idx <= msg_idx + 1;

                    if (msg_idx == 32)
                        lcd_state <= LCD_IDLE;
                end

            endcase
        end
    end

endmodule
