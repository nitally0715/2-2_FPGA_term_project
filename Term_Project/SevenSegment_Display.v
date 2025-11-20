//============================================================
// SevenSegment_Display.v
// - 4자리 7-Segment 표현 (Multiplexing)
// - value: 0~9999 decimal
//============================================================

module SevenSegment_Display(
    input  wire clk,           // 50 MHz
    input  wire rst,
    input  wire [15:0] value,  // 표시할 숫자

    output reg  [6:0] seg,     // a,b,c,d,e,f,g
    output reg  [3:0] an       // 4-digit enable (active low)
);

    //--------------------------------------------------------
    // 클럭 분주 (자리 스캔 속도 조절)
    //--------------------------------------------------------
    reg [15:0] refresh_cnt;
    reg [1:0]  digit_sel;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            refresh_cnt <= 0;
            digit_sel   <= 0;
        end else begin
            refresh_cnt <= refresh_cnt + 1;

            // 약 1kHz 정도의 스캔 속도
            if (refresh_cnt >= 16'd5000) begin
                refresh_cnt <= 0;
                digit_sel   <= digit_sel + 1;
            end
        end
    end


    //--------------------------------------------------------
    // value를 각 자릿수로 분리 (BCD)
    //--------------------------------------------------------
    wire [3:0] d0 = value % 10;
    wire [3:0] d1 = (value / 10) % 10;
    wire [3:0] d2 = (value / 100) % 10;
    wire [3:0] d3 = (value / 1000) % 10;

    reg [3:0] current_digit;


    //--------------------------------------------------------
    // Digit enable 및 선택 숫자 설정
    //--------------------------------------------------------
    always @(*) begin
        case (digit_sel)
            2'd0: begin an = 4'b1110; current_digit = d0; end  // 1의 자리
            2'd1: begin an = 4'b1101; current_digit = d1; end  // 10의 자리
            2'd2: begin an = 4'b1011; current_digit = d2; end  // 100의 자리
            2'd3: begin an = 4'b0111; current_digit = d3; end  // 1000의 자리
        endcase
    end


    //--------------------------------------------------------
    // 세그먼트 디코딩 (Common Anode 기준)
    //--------------------------------------------------------
    always @(*) begin
        case (current_digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111; // Blank
        endcase
    end

endmodule
