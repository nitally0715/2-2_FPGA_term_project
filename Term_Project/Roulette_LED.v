//=======================================================================
// Roulette_LED.v  (부드러운 감속 + 정확 정지 완성본)
//=======================================================================
module Roulette_LED(
    input  wire clk,          // 50 MHz
    input  wire rst,
    input  wire start,        // FSM이 1클럭 펄스 생성
    output reg  [7:0] led,    // LED 8개 (active high)
    output reg  [2:0] pos,    // 0~7, 당첨 위치
    output reg  spin_done     // 1클럭 펄스
);

    //-------------------------------------------------------------
    // 내부 상태 변수
    //-------------------------------------------------------------
    reg spinning;             // 회전 중 여부
    reg [31:0] delay_cnt;     // 회전 속도 카운터
    reg [31:0] delay_max;     // 카운트 목표값 (점점 증가)
    reg [31:0] decel_step;    // 감속 정도

    localparam DELAY_FAST  = 32'd200000;   // 초기 속도 (빠름)
    localparam DELAY_SLOW  = 32'd5000000;  // 감속 상한 (멈추기 직전)
    localparam DECEL_INIT  = 32'd20000;    // 감속 기본 증가값


    //-------------------------------------------------------------
    // 메인 룰렛 회전 로직
    //-------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            spinning   <= 0;
            pos        <= 0;
            delay_cnt  <= 0;
            delay_max  <= DELAY_FAST;
            decel_step <= DECEL_INIT;
            spin_done  <= 0;
        end 
        else begin
            spin_done <= 0;

            // ----------------------------------------------------
            // START 신호 → 회전 시작
            // ----------------------------------------------------
            if (start && !spinning) begin
                spinning   <= 1;
                delay_max  <= DELAY_FAST;
                decel_step <= DECEL_INIT;
                delay_cnt  <= 0;
            end

            // ----------------------------------------------------
            // 회전 중
            // ----------------------------------------------------
            if (spinning) begin

                // delay_cnt가 delay_max를 초과하면 pos 증가
                if (delay_cnt >= delay_max) begin
                    delay_cnt <= 0;

                    // LED 위치 한 칸 이동
                    pos <= (pos == 3'd7) ? 3'd0 : pos + 1'b1;

                    // 감속: 점점 delay_max가 커져서 회전이 느려짐
                    if (delay_max < DELAY_SLOW)
                        delay_max <= delay_max + decel_step;
                    else begin
                        // 감속 끝 → 정지
                        spinning  <= 0;
                        spin_done <= 1;
                    end

                end else begin
                    delay_cnt <= delay_cnt + 1;
                end
            end
        end
    end

    //-------------------------------------------------------------
    // LED 패턴 생성 (pos 위치만 점등)
    //-------------------------------------------------------------
    always @(*) begin
        led = 8'b00000000;
        led[pos] = 1'b1;
    end

endmodule
