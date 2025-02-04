// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

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
    input                                white_to_move,

    input [MAX_DEPTH_LOG2 - 1:0]         killer_ply,
    input [`BOARD_WIDTH - 1:0]           killer_board,
    input                                killer_update,
    input                                killer_clear,
    input signed [EVAL_WIDTH - 1:0]      killer_bonus0,
    input signed [EVAL_WIDTH - 1:0]      killer_bonus1,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg_t3,
    output reg signed [EVAL_WIDTH - 1:0] eval_eg_t3,
    output reg                           eval_valid_t3
    );

   reg                                   killer_clear_r;
   reg                                   killer_update_r;
   reg                                   board_valid_t1, board_valid_t2;
   reg [`BOARD_WIDTH - 1:0]              board_zero, board_one;
   reg [`BOARD_WIDTH * 2 - 1:0]          killer_table [0:`MAX_DEPTH - 1]; // two killer moves per ply
   reg [`MAX_DEPTH * 2 - 1:0]            killer_valid = 0;
   reg signed [EVAL_WIDTH - 1:0]         eval_mg_t2;
   reg signed [EVAL_WIDTH - 1:0]         eval_eg_t2;
   reg [MAX_DEPTH_LOG2 - 1:0]            ply_r0, ply_r1;
   reg                                   killer_zero_t1, killer_one_t1;

   reg [EVAL_WIDTH - 1:0]                bonus0_t1, bonus1_t1;

   reg                                   eval_valid_t1, eval_valid_t2;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   wire [`BOARD_WIDTH - 1:0]             board_t0 = board;
   wire                                  eval_valid_t0 = board_valid;
   wire                                  white_to_move_t0 = white_to_move;

   always @(posedge clk)
     begin
        killer_clear_r <= killer_clear;
        killer_update_r <= killer_update;
        ply_r0 <= killer_ply;
        ply_r1 <= ply_r0; // flop for par

        if (white_to_move_t0)
          begin
             bonus0_t1 <= -killer_bonus0;
             bonus1_t1 <= -killer_bonus1;
          end
        else
          begin
             bonus0_t1 <= killer_bonus0;
             bonus1_t1 <= killer_bonus1;
          end
        board_zero <= killer_table[ply_r1][`BOARD_WIDTH - 1:0];
        board_one  <= killer_table[ply_r1][`BOARD_WIDTH * 2 - 1:`BOARD_WIDTH];

        killer_zero_t1 <= killer_valid[ply_r1 * 2 + 0] && board_t0 == board_zero;
        killer_one_t1  <= killer_valid[ply_r1 * 2 + 1] && board_t0 == board_one;

        if (killer_clear && ~killer_clear_r)
          killer_valid <= 0;

        if (killer_update && ~killer_update_r)
          begin
             killer_table[ply_r1][`BOARD_WIDTH - 1:0] <= killer_board;
             killer_table[ply_r1][`BOARD_WIDTH * 2 - 1:`BOARD_WIDTH] <= killer_table[ply_r1][`BOARD_WIDTH - 1:0];
             killer_valid[ply_r1 * 2] <= 1;
             killer_valid[ply_r1 * 2 + 1] <= killer_valid[ply_r1 * 2];
          end

        if (killer_zero_t1)
          begin
             eval_mg_t2 <= bonus0_t1;
             eval_eg_t2 <= bonus0_t1;
          end
        else if (killer_one_t1)
          begin
             eval_mg_t2 <= bonus1_t1;
             eval_eg_t2 <= bonus1_t1;
          end
        else
          begin
             eval_mg_t2 <= 0;
             eval_eg_t2 <= 0;
          end
        eval_mg_t3 <= eval_mg_t2;
        eval_eg_t3 <= eval_eg_t2;
     end

   always @(posedge clk)
     begin
	eval_valid_t1 <= eval_valid_t0;
	eval_valid_t2 <= eval_valid_t1;
	eval_valid_t3 <= eval_valid_t2;
     end

endmodule
