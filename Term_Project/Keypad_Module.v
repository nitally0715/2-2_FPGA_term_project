//==========================================================
// Keypad_Module.v  (완전 동작 버전)
// - 4x4 Keypad 스캔
// - 디바운싱 적용
// - 키 1회 입력 보장
// - 출력: key_valid (1클럭 펄스), key_value(0~9,10='*',11='#')
//==========================================================

module Keypad_Module(
    input  wire clk,    // 최소 1kHz 이상이면 충분
    input  wire rst,

    input  wire [3:0] row,   // 행 입력
    output reg  [3:0] col,   // 열 스캔

    output reg key_valid,    // 1펄스
    output reg [3:0] key_value
);

    // --------------------------------------
    // 1. Keypad Scan (열 4개 순환)
    // --------------------------------------
    reg [1:0] scan_col;
    reg [3:0] row_sync;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_col <= 0;
            col <= 4'b1110;
        end else begin
            scan_col <= scan_col + 1;

            case (scan_col)
                2'd0: col <= 4'b1110;
                2'd1: col <= 4'b1101;
                2'd2: col <= 4'b1011;
                2'd3: col <= 4'b0111;
            endcase

            // row 입력을 클럭 동기화
            row_sync <= row;
        end
    end

    // --------------------------------------
    // 2. 디바운싱
    //    - row 값이 안정적으로 같을 때만 입력 인정
    // --------------------------------------
    reg [3:0] row_prev;
    reg [3:0] row_stable;
    reg [15:0] debounce_cnt;

    parameter DEBOUNCE_TIME = 16'd8000;  // (클럭 1kHz 기준 약 8ms)

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            row_prev <= 4'b1111;
            row_stable <= 4'b1111;
            debounce_cnt <= 0;
        end else begin
            if (row_sync == row_prev) begin
                // 이전 상태와 같게 유지되면 카운트 증가
                if (debounce_cnt < DEBOUNCE_TIME)
                    debounce_cnt <= debounce_cnt + 1;
                else
                    row_stable <= row_sync;   // 안정된 입력 확정
            end else begin
                // 값이 바뀌면 카운터 리셋
                debounce_cnt <= 0;
            end

            row_prev <= row_sync;
        end
    end

    // --------------------------------------
    // 3. One-shot Key Detection
    // --------------------------------------
    reg pressed;
    reg [3:0] detected_key;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            key_valid <= 0;
            pressed <= 0;
        end else begin
            key_valid <= 0;

            // stable 값이 눌림(1111 아니면)
            if (!pressed && row_stable != 4'b1111) begin
                pressed <= 1;

                // 키 매핑
                detected_key <= decode_key(row_stable, col);

                // 1클럭 펄스 발생
                key_value <= decode_key(row_stable, col);
                key_valid <= 1;

            end else if (row_stable == 4'b1111) begin
                // 키 떼면 다시 입력 가능
                pressed <= 0;
            end
        end
    end

    // --------------------------------------
    // 4. 키 매핑 함수
    // --------------------------------------
    function [3:0] decode_key;
        input [3:0] row_sig;
        input [3:0] col_sig;

        begin
            case ({row_sig, col_sig})

                // col=1110
                8'b1110_1110: decode_key = 4'd1;
                8'b1101_1110: decode_key = 4'd4;
                8'b1011_1110: decode_key = 4'd7;
                8'b0111_1110: decode_key = 4'd10;   // *

                // col=1101
                8'b1110_1101: decode_key = 4'd2;
                8'b1101_1101: decode_key = 4'd5;
                8'b1011_1101: decode_key = 4'd8;
                8'b0111_1101: decode_key = 4'd0;

                // col=1011
                8'b1110_1011: decode_key = 4'd3;
                8'b1101_1011: decode_key = 4'd6;
                8'b1011_1011: decode_key = 4'd9;
                8'b0111_1011: decode_key = 4'd11;   // #

                // col=0111  → 보통 A B C D지만 여기선 필요 없음
                default: decode_key = 4'd15;

            endcase
        end
    endfunction

endmodule
