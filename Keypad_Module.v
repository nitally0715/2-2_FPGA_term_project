//==============================================================
// Keypad_Module.v
// - 3x4 Keypad (R0~R3, C0~C2)
// - 스캔 + 디바운싱 + 원샷 key_valid
// - 출력: key_valid(1클럭), key_value(0~9,10='*',11='#')
//==============================================================

module Keypad_Module(
    input  wire clk,       // 50MHz
    input  wire rst,

    input  wire [3:0] row, // R0~R3 (눌리면 0)
    output reg  [2:0] col, // C0~C2 (하나씩 0, 나머지 1)

    output reg        key_valid,
    output reg  [3:0] key_value
);

    //==========================================================
    // 0. 스캔 속도 분주기 (약 1kHz ~ 2kHz 스캔)
    //==========================================================
    // 50MHz / 50000 = 1kHz (1ms)
    localparam SCAN_DIV = 16'd50000;

    reg [15:0] scan_cnt;
    reg        scan_en;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_cnt <= 0;
            scan_en  <= 0;
        end else begin
            if (scan_cnt == SCAN_DIV) begin
                scan_cnt <= 0;
                scan_en  <= 1;     // 1클럭 펄스
            end else begin
                scan_cnt <= scan_cnt + 1;
                scan_en  <= 0;
            end
        end
    end

    //==========================================================
    // 1. 열 스캔 (C0 → C1 → C2)
    //==========================================================
    reg [1:0] scan_col;    // 0,1,2 순환

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_col <= 2'd0;
            col      <= 3'b110;  // C0 활성화
        end else if (scan_en) begin
            scan_col <= (scan_col == 2'd2) ? 2'd0 : scan_col + 1;

            case (scan_col)
                2'd0: col <= 3'b110; // C0 = 0
                2'd1: col <= 3'b101; // C1 = 0
                2'd2: col <= 3'b011; // C2 = 0
                default: col <= 3'b110;
            endcase
        end
    end

    //==========================================================
    // 2. 디바운싱
    //==========================================================

    // DEBOUNCE_TIME = 스캔 주기(1ms) * 5~8번 = 약 5~8ms
    localparam DEBOUNCE_TIME = 8'd8;

    reg [3:0] row_sync;
    reg [3:0] row_prev;
    reg [3:0] row_stable;
    reg [7:0] debounce_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            row_sync     <= 4'b1111;
            row_prev     <= 4'b1111;
            row_stable   <= 4'b1111;
            debounce_cnt <= 0;
        end else if (scan_en) begin
            row_sync <= row;   // 스캔 타이밍마다 row 샘플

            // 같은 값 유지 중이면 디바운스 카운트 증가
            if (row_sync == row_prev) begin
                if (debounce_cnt < DEBOUNCE_TIME)
                    debounce_cnt <= debounce_cnt + 1;
                else
                    row_stable <= row_sync; // 안정된 입력 확정
            end else begin
                debounce_cnt <= 0;
            end

            row_prev <= row_sync;
        end
    end

    //==========================================================
    // 3. 키 매핑 함수
    //==========================================================

    function [3:0] decode_key;
        input [3:0] row_s;
        input [1:0] col_s;
    begin
        case ({row_s, col_s})

            // C0 (scan_col = 0)
            {4'b1110,2'd0}: decode_key = 4'd1;
            {4'b1101,2'd0}: decode_key = 4'd4;
            {4'b1011,2'd0}: decode_key = 4'd7;
            {4'b0111,2'd0}: decode_key = 4'd10; // *

            // C1 (scan_col = 1)
            {4'b1110,2'd1}: decode_key = 4'd2;
            {4'b1101,2'd1}: decode_key = 4'd5;
            {4'b1011,2'd1}: decode_key = 4'd8;
            {4'b0111,2'd1}: decode_key = 4'd0;  // 0

            // C2 (scan_col = 2)
            {4'b1110,2'd2}: decode_key = 4'd3;
            {4'b1101,2'd2}: decode_key = 4'd6;
            {4'b1011,2'd2}: decode_key = 4'd9;
            {4'b0111,2'd2}: decode_key = 4'd11; // #

            default: decode_key = 4'd15;
        endcase
    end
    endfunction

    //==========================================================
    // 4. 키 원샷 검출 (pressed edge detect)
    //==========================================================
    reg pressed;  // 1이면 이미 누르고 있는 상태

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            key_valid <= 0;
            key_value <= 4'd15;
            pressed   <= 0;
        end else begin
            key_valid <= 0; // 기본값: 0 (펄스)

            // 눌리지 않은 상태 → 눌리는 순간
            if (!pressed && row_stable != 4'b1111) begin
                pressed   <= 1;
                key_value <= decode_key(row_stable, scan_col);
                key_valid <= 1;       // 1클럭 펄스
            end 
            // 손 떼면 pressed 리셋
            else if (row_stable == 4'b1111) begin
                pressed <= 0;
            end
        end
    end

endmodule
