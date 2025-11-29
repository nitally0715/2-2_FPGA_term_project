//==============================================================
// TextLCD_Controller.v
// HD44780 16x2 Text LCD Driver (8bit mode)
// - 입력: line1, line2 (각 16 bytes)
// - 출력: TLCD_D[7:0], TLCD_E, TLCD_RS, TLCD_RW
//==============================================================

module TextLCD_Controller(
    input  wire        clk,      // 50MHz
    input  wire        rst,

    input  wire [127:0] line1,   // 16 characters
    input  wire [127:0] line2,   // 16 characters

    output reg  [7:0]  TLCD_D,
    output reg         TLCD_E,
    output reg         TLCD_RS,
    output wire        TLCD_RW
);

    assign TLCD_RW = 1'b0;   // WRITE ONLY (RW = 0)

    //==========================================================
    // Clock divider → 약 1ms 간격으로 tick 생성 (대충이라도 OK)
    //==========================================================
    reg [15:0] clk_div;
    wire tick_1ms = (clk_div == 16'd0);

    always @(posedge clk or posedge rst) begin
        if (rst)
            clk_div <= 16'd0;
        else
            clk_div <= clk_div + 16'd1;
    end

    //==========================================================
    // FSM 상태 정의
    //==========================================================
    localparam INIT_1         = 4'd0,
               INIT_2         = 4'd1,
               INIT_3         = 4'd2,
               INIT_4         = 4'd3,
               SET_LINE1_ADDR = 4'd4,
               WRITE_LINE1    = 4'd5,
               SET_LINE2_ADDR = 4'd6,
               WRITE_LINE2    = 4'd7;

    reg [3:0] state;
    reg [4:0] char_index;   // 0~15

    //==========================================================
    // E-pulse 요청 신호 (FSM → 펄스 생성기)
    //==========================================================
    reg e_req;              // 한 번의 LCD 사이클마다 1클럭으로만 올라감

    //==========================================================
    // Enable Pulse Generator
    //   - e_req가 1이 되면 TLCD_E를 짧게 한 번 High로
    //==========================================================
    reg [1:0] e_cnt;
    reg       e_busy;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            TLCD_E <= 1'b0;
            e_cnt  <= 2'd0;
            e_busy <= 1'b0;
        end else begin
            if (e_busy) begin
                // 간단하게 2~3클럭짜리 펄스 생성
                e_cnt <= e_cnt + 2'd1;
                case (e_cnt)
                    2'd0: TLCD_E <= 1'b1;  // 펄스 시작
                    2'd1: TLCD_E <= 1'b0;  // 펄스 종료
                    default: begin
                        TLCD_E <= 1'b0;
                        e_busy <= 1'b0;
                        e_cnt  <= 2'd0;
                    end
                endcase
            end else if (e_req) begin
                // 새로운 요청이 들어오면 펄스 시작
                e_busy <= 1'b1;
                e_cnt  <= 2'd0;
            end
        end
    end

    //==========================================================
    // 메인 FSM - LCD 초기화 + 문자 출력
    //==========================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= INIT_1;
            char_index <= 5'd0;

            TLCD_RS    <= 1'b0;
            TLCD_D     <= 8'h00;
            e_req      <= 1'b0;

        end else begin
            // 기본값: 요청 없음
            e_req <= 1'b0;

            if (tick_1ms) begin   // 1ms마다 한 동작 수행
                case (state)

                    //--------------------------------------------------
                    // LCD 초기화 (8bit mode, Display ON, Clear)
                    //--------------------------------------------------
                    INIT_1: begin
                        TLCD_RS <= 1'b0;
                        TLCD_D  <= 8'h38;   // function set: 8bit 2line
                        e_req   <= 1'b1;
                        state   <= INIT_2;
                    end

                    INIT_2: begin
                        TLCD_RS <= 1'b0;
                        TLCD_D  <= 8'h0C;   // display ON
                        e_req   <= 1'b1;
                        state   <= INIT_3;
                    end

                    INIT_3: begin
                        TLCD_RS <= 1'b0;
                        TLCD_D  <= 8'h06;   // entry mode
                        e_req   <= 1'b1;
                        state   <= INIT_4;
                    end

                    INIT_4: begin
                        TLCD_RS <= 1'b0;
                        TLCD_D  <= 8'h01;   // clear display
                        e_req   <= 1'b1;
                        state   <= SET_LINE1_ADDR;
                    end

                    //--------------------------------------------------
                    // line 1 시작 주소 설정
                    //--------------------------------------------------
                    SET_LINE1_ADDR: begin
                        TLCD_RS   <= 1'b0;
                        TLCD_D    <= 8'h80;  // DDRAM address 0x00
                        e_req     <= 1'b1;
                        char_index<= 0;
                        state     <= WRITE_LINE1;
                    end

                    //--------------------------------------------------
                    // line1 출력 (16글자)
                    //--------------------------------------------------
                    WRITE_LINE1: begin
                        TLCD_RS <= 1'b1;     // data mode

                        // line1[127:0] → l1[0]이 첫 글자
                        TLCD_D <= line1[(15-char_index)*8 +: 8];

                        e_req <= 1'b1;

                        if (char_index == 15)
                            state <= SET_LINE2_ADDR;
                        else
                            char_index <= char_index + 1;
                    end

                    //--------------------------------------------------
                    // line 2 주소 설정
                    //--------------------------------------------------
                    SET_LINE2_ADDR: begin
                        TLCD_RS   <= 1'b0;
                        TLCD_D    <= 8'hC0;   // DDRAM address 0x40
                        e_req     <= 1'b1;
                        char_index<= 0;
                        state     <= WRITE_LINE2;
                    end

                    //--------------------------------------------------
                    // line2 출력 (16글자)
                    //--------------------------------------------------
                    WRITE_LINE2: begin
                        TLCD_RS <= 1'b1;
                        TLCD_D  <= line2[(15-char_index)*8 +: 8];

                        e_req <= 1'b1;

                        if (char_index == 15)
                            state <= SET_LINE1_ADDR;   // 반복 출력
                        else
                            char_index <= char_index + 1;
                    end

                endcase
            end
        end
    end

endmodule
