//==============================================================
// Button_Keypad.v
// 12개의 독립 버튼을 4×3 Keypad처럼 매핑하는 모듈
//==============================================================

module Button_Keypad(
    input  wire clk,
    input  wire rst,

    input  wire key01,  // 1
    input  wire key02,  // 2
    input  wire key03,  // 3
    input  wire key04,  // 4
    input  wire key05,  // 5
    input  wire key06,  // 6
    input  wire key07,  // 7
    input  wire key08,  // 8
    input  wire key09,  // 9
    input  wire key10,  // * (=10)
    input  wire key11,  // 0 (=11)
    input  wire key12,  // # (=12)

    output reg  key_valid,
    output reg [3:0] key_value
);

    // 버튼은 active-low일 가능성이 높으므로 invert할 수도 있음
    // 일단 active-high 가정. 필요시 !keyXX 로 바꾸면 됨.

    reg [11:0] key_prev;
    wire [11:0] key_now;
    assign key_now = {key12,key11,key10,key09,key08,key07,key06,key05,key04,key03,key02,key01};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            key_prev  <= 12'b0;
            key_valid <= 1'b0;
            key_value <= 4'd0;
        end
        else begin
            key_valid <= 1'b0;  // 기본은 0

            // ? 하나의 버튼만 눌린 경우만 처리
            if (key_now != key_prev) begin
                // 눌림 감지 (rising edge)
                if (key_now > key_prev) begin
                    case (key_now)
                        12'b000000000001: begin key_valid <= 1'b1; key_value <= 4'd1; end
                        12'b000000000010: begin key_valid <= 1'b1; key_value <= 4'd2; end
                        12'b000000000100: begin key_valid <= 1'b1; key_value <= 4'd3; end
                        12'b000000001000: begin key_valid <= 1'b1; key_value <= 4'd4; end
                        12'b000000010000: begin key_valid <= 1'b1; key_value <= 4'd5; end
                        12'b000000100000: begin key_valid <= 1'b1; key_value <= 4'd6; end
                        12'b000001000000: begin key_valid <= 1'b1; key_value <= 4'd7; end
                        12'b000010000000: begin key_valid <= 1'b1; key_value <= 4'd8; end
                        12'b000100000000: begin key_valid <= 1'b1; key_value <= 4'd9; end
                        12'b001000000000: begin key_valid <= 1'b1; key_value <= 4'd10; end // *
                        12'b010000000000: begin key_valid <= 1'b1; key_value <= 4'd11; end // 0
                        12'b100000000000: begin key_valid <= 1'b1; key_value <= 4'd12; end // #
                    endcase
                end
            end

            key_prev <= key_now;
        end
    end
endmodule
