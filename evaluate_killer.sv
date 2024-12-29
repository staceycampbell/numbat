// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "vchess.vh"

module evaluate_killer #
  (
   parameter EVAL_WIDTH = 0,
   parameter MAX_DEPTH_LOG2 = 0
   )
   (
    input                                clk,
    input                                reset,

    input                                board_valid,
    input [`BOARD_WIDTH - 1:0]           board,
    input                                clear_eval,
    input                                white_to_move,

    input [MAX_DEPTH_LOG2 - 1:0]         killer_ply,
    input [`BOARD_WIDTH - 1:0]           killer_board,
    input                                killer_update,
    input                                killer_clear,
    input signed [EVAL_WIDTH - 1:0]      killer_bonus0,
    input signed [EVAL_WIDTH - 1:0]      killer_bonus1,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg,
    output reg signed [EVAL_WIDTH - 1:0] eval_eg,
    output                               eval_valid
    );

   localparam LATENCY_COUNT = 4;

   reg                                   killer_clear_r;
   reg                                   killer_update_r;
   reg                                   board_valid_t1, board_valid_t2;
   reg [`BOARD_WIDTH * 2 - 1:0]          killer_table [0:`MAX_DEPTH - 1]; // two killer moves per ply
   reg [`MAX_DEPTH * 2 - 1:0]            killer_valid = 0;
   reg signed [EVAL_WIDTH - 1:0]         eval_mg_pre;
   reg signed [EVAL_WIDTH - 1:0]         eval_eg_pre;
   (* shreg_extract = "no" *) reg [MAX_DEPTH_LOG2 - 1:0] ply_r0, ply_r1; // assist tools in avoiding timing problems
   reg                                   killer_zero, killer_one;

   reg [EVAL_WIDTH - 1:0]                bonus0, bonus1;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   always @(posedge clk)
     begin
        killer_clear_r <= killer_clear;
        killer_update_r <= killer_update;
        board_valid_t1 <= board_valid;
        board_valid_t2 <= board_valid_t1;
        ply_r0 <= killer_ply;
        ply_r1 <= ply_r0;

        if (white_to_move)
          begin
             bonus0 <= -killer_bonus0;
             bonus1 <= -killer_bonus1;
          end
        else
          begin
             bonus0 <= killer_bonus0;
             bonus1 <= killer_bonus1;
          end
        killer_zero <= killer_valid[ply_r1 * 2 + 0] && board == killer_table[ply_r1][`BOARD_WIDTH - 1:0];
        killer_one  <= killer_valid[ply_r1 * 2 + 1] && board == killer_table[ply_r1][`BOARD_WIDTH * 2 - 1:`BOARD_WIDTH];

        if (killer_clear && ~killer_clear_r)
          killer_valid <= 0;

        if (killer_update && ~killer_update_r)
          begin
             killer_table[ply_r1][`BOARD_WIDTH - 1:0] <= killer_board;
             killer_table[ply_r1][`BOARD_WIDTH * 2 - 1:`BOARD_WIDTH] <= killer_table[ply_r1][`BOARD_WIDTH - 1:0];
             killer_valid[ply_r1 * 2] <= 1;
             killer_valid[ply_r1 * 2 + 1] <= killer_valid[ply_r1 * 2];
          end
        
        if (board_valid_t1 && ~board_valid_t2)
          if (killer_zero)
            begin
               eval_mg_pre <= bonus0;
               eval_eg_pre <= bonus0;
            end
          else if (killer_one)
            begin
               eval_mg_pre <= bonus1;
               eval_eg_pre <= bonus1;
            end
          else
            begin
               eval_mg_pre <= 0;
               eval_eg_pre <= 0;
            end
        eval_mg <= eval_mg_pre;
        eval_eg <= eval_eg_pre;
     end
   
   /* latency_sm AUTO_TEMPLATE (
    );*/
   latency_sm #
     (
      .LATENCY_COUNT (LATENCY_COUNT)
      )
   latency_sm
     (/*AUTOINST*/
      // Outputs
      .eval_valid                       (eval_valid),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .clear_eval                       (clear_eval));

endmodule
