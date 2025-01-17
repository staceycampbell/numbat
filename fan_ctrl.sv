// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

module fan_ctrl
  (
   input        clk100,

   output reg   fan_ctrl_read_rd_en,

   input        fan_ctrl_valid,
   input [31:0] fan_ctrl_read_rd_data,

   output       fan_pwm
   );

   localparam PWM_FREQUENCY = 25 * 1000; // 25kHz
   localparam FULL_DUTY_CYCLE = (100 * 1000000) / PWM_FREQUENCY;
   localparam COUNTER_WIDTH_LOG2 = $clog2(FULL_DUTY_CYCLE) + 1;
   localparam MIN_DUTY_CYCLE = FULL_DUTY_CYCLE / 10; // min duty cycle to avoid a fan stall
   localparam MAX_DUTY_CYCLE = FULL_DUTY_CYCLE - 1;

   reg          fan_pwm_reg = 1'b1;

   reg [COUNTER_WIDTH_LOG2 - 1:0] pwm_high_count = FULL_DUTY_CYCLE - 1;
   reg [COUNTER_WIDTH_LOG2 - 1:0] pwm_count = 0;

   wire [COUNTER_WIDTH_LOG2 - 1:0] user_pwm_high = fan_ctrl_read_rd_data[COUNTER_WIDTH_LOG2 - 1:0];

   assign fan_pwm = ~fan_pwm_reg; // note: 0 = 12V, 1 = 0V

   always @(posedge clk100)
     begin
        if (pwm_count >= FULL_DUTY_CYCLE - 1)
          pwm_count <= 0;
        else
          pwm_count <= pwm_count + 1;

        if (pwm_count <= pwm_high_count)
          fan_pwm_reg <= 1'b1;
        else
          fan_pwm_reg <= 1'b0;

        fan_ctrl_read_rd_en <= 0;
        if (fan_ctrl_valid)
          begin
             if (user_pwm_high > MAX_DUTY_CYCLE)
               pwm_high_count <= MAX_DUTY_CYCLE;
             else if (user_pwm_high < MIN_DUTY_CYCLE)
               pwm_high_count <= MIN_DUTY_CYCLE;
             else
               pwm_high_count <= user_pwm_high;
             fan_ctrl_read_rd_en <= 1;
          end

        if (pwm_high_count < MIN_DUTY_CYCLE)
          pwm_high_count <= MIN_DUTY_CYCLE;
        else if (pwm_high_count > MAX_DUTY_CYCLE)
          pwm_high_count <= MAX_DUTY_CYCLE;
     end

endmodule
