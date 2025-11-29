//====================================================================
// SevenSegment_Display.v
// 5자리 7-seg 디스플레이 구동
// current_money(0~10000) 표시, 초과 시 10000으로 고정
// active-low 방식 (일반적인 FPGA 보드 기준)
//
//====================================================================

module SevenSegment_Display(
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] current_money,   // 0~10000까지 유효

    output reg  [6:0]  seg,             // active-low 7-seg (a~g)
    output reg  [4:0]  an               // active-low 자리 선택 5자리
);

    //============================================================
    // 내부 값 클램프: 0~10000만 허용
    //============================================================
    reg [15:0] money_clamped;

    always @(*) begin
        if (current_money > 16'd10000)
            money_clamped = 16'd10000;
        else
            money_clamped = current_money;
    end

    //============================================================
    // 5자리 분해 (만/천/백/십/일)
    //============================================================
    reg [3:0] digit [0:4];  // digit[0] = 만의 자리, digit[4] = 일의 자리

    always @(*) begin
        digit[0] = (money_clamped / 10000) % 10;  // 만
        digit[1] = (money_clamped / 1000)  % 10;  // 천
        digit[2] = (money_clamped / 100)   % 10;  // 백
        digit[3] = (money_clamped / 10)    % 10;  // 십
        digit[4] = (money_clamped)         % 10;  // 일
    end

    //============================================================
    // 자리 선택 Multiplex Counter
    //============================================================
    reg [15:0] refresh_cnt = 0;
    reg [2:0]  digit_sel = 0;  // 0~4 반복

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            refresh_cnt <= 0;
            digit_sel   <= 0;
        end else begin
            refresh_cnt <= refresh_cnt + 1;

            // 약 1kHz 정도로 자리 변경 (보드 클럭 100MHz 가정)
            if (refresh_cnt == 16'd2000) begin
                refresh_cnt <= 0;
                digit_sel <= (digit_sel == 4) ? 0 : digit_sel + 1;
            end
        end
    end

    //============================================================
    // 숫자 → 7-seg 패턴 (active-low)
    //============================================================
    function [6:0] seg_decode;
        input [3:0] num;
        case(num)
            4'd0: seg_decode = ~7'b1000000;
            4'd1: seg_decode = ~7'b1111001;
            4'd2: seg_decode = ~7'b0100100;
            4'd3: seg_decode = ~7'b0110000;
            4'd4: seg_decode = ~7'b0011001;
            4'd5: seg_decode = ~7'b0010010;
            4'd6: seg_decode = ~7'b0000010;
            4'd7: seg_decode = ~7'b1111000;
            4'd8: seg_decode = ~7'b0000000;
            4'd9: seg_decode = ~7'b0010000;
            default: seg_decode = ~7'b1111111; // blank
        endcase
    endfunction

    //============================================================
    // Multiplex: digit_sel에 따라 an 및 seg 결정
    //============================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            an  <= 5'b11111;   // 모두 꺼짐 (active-low)
            seg <= 7'b1111111;
        end else begin
            case (digit_sel)
                0: begin  // 만의 자리
                    an  <= 5'b01111;
                    seg <= seg_decode(digit[0]);
                end
                1: begin  // 천의 자리
                    an  <= 5'b10111;
                    seg <= seg_decode(digit[1]);
                end
                2: begin  // 백의 자리
                    an  <= 5'b11011;
                    seg <= seg_decode(digit[2]);
                end
                3: begin  // 십의 자리
                    an  <= 5'b11101;
                    seg <= seg_decode(digit[3]);
                end
                4: begin  // 일의 자리
                    an  <= 5'b11110;
                    seg <= seg_decode(digit[4]);
                end
                default: begin
                    an  <= 5'b11111;
                    seg <= 7'b1111111;
                end
            endcase
        end
    end

endmodule
