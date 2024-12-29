// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

module latency_sm #
  (
   parameter LATENCY_COUNT = 0
   )
   (
    input      clk,
    input      reset,

    input      board_valid,
    input      clear_eval,

    output reg eval_valid
    );

   reg         board_valid_r;
   reg [$clog2(LATENCY_COUNT) + 1 - 1:0] latency;

   localparam STATE_IDLE = 0;
   localparam STATE_LATENCY = 1;
   localparam STATE_WAIT_CLEAR = 2;

   reg [1:0]                             state = STATE_IDLE;

   always @(posedge clk)
     board_valid_r <= board_valid;

   always @(posedge clk)
     if (reset)
       begin
          state <= STATE_IDLE;
          eval_valid <= 0;
       end
     else
       case (state)
         STATE_IDLE :
           begin
              latency <= 1;
              eval_valid <= 0;
              if (board_valid && ~board_valid_r)
                state <= STATE_LATENCY;
           end
         STATE_LATENCY :
           begin
              latency <= latency + 1;
              if (latency == LATENCY_COUNT - 1)
                begin
                   eval_valid <= 1;
                   state <= STATE_WAIT_CLEAR;
                end
           end
         STATE_WAIT_CLEAR :
           if (clear_eval)
             state <= STATE_IDLE;
         default :
           state <= STATE_IDLE;
       endcase
   
endmodule
