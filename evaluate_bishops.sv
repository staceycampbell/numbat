// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "vchess.vh"

module evaluate_bishops #
  (
   parameter EVAL_WIDTH = 0,
   parameter WHITE_BISHOPS = 0
   )
   (
    input                                clk,
    input                                reset,
    input                                board_valid,
    input [`BOARD_WIDTH - 1:0]           board,
    input                                clear_eval,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg,
    output reg signed [EVAL_WIDTH - 1:0] eval_eg,
    output                               eval_valid
    );

   localparam LATENCY_COUNT = 7;
   localparam BISHOP = WHITE_BISHOPS ? `WHITE_BISH : `BLACK_BISH;
   localparam PAWN = WHITE_BISHOPS ? `WHITE_PAWN : `BLACK_PAWN;

   reg [63:0]                            bish_loc_t1;
   reg [63:0]                            my_pawn_on_white_loc_t2, my_pawn_on_black_loc_t2;
   reg [63:0]                            loc_t1;
   reg signed [EVAL_WIDTH - 1:0]         pair_bonus_mg_t3, pair_bonus_eg_t3;
   reg [$clog2(64) - 1:0]                solo_bish_loc_t2;
   reg signed [EVAL_WIDTH - 1:0]         tpawns_t4;
   reg signed [EVAL_WIDTH - 1:0]         tpawn_penalty_mg_t5;
   reg signed [EVAL_WIDTH - 1:0]         tpawn_penalty_eg_t5;
   reg signed [EVAL_WIDTH - 1:0]         eval_mg_t6, eval_eg_t6;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [5:0]           bish_count_t2;          // From popcount of popcount.v
   wire [5:0]           mpob_count_t3;          // From popcount_mpob of popcount.v
   wire [5:0]           mpow_count_t3;          // From popcount_mpow of popcount.v
   // End of automatics

   integer                               i, row, col;

   always @(posedge clk)
     begin
        for (i = 0; i < 64; i = i + 1)
          if (board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == BISHOP)
            bish_loc_t1[i] <= 1'b1;
          else
            bish_loc_t1[i] <= 1'b0;
        for (i = 0; i < 64; i = i + 1)
          if (bish_loc_t1[i])
            solo_bish_loc_t2 <= i;
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            if ((row & 1) != (col & 1)) // white square
              begin
                 my_pawn_on_white_loc_t2[row << 3 | col] <= board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH] == PAWN;
                 my_pawn_on_black_loc_t2[row << 3 | col] <= 1'b0;
              end
            else
              begin
                 my_pawn_on_black_loc_t2[row << 3 | col] <= board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH] == PAWN;
                 my_pawn_on_white_loc_t2[row << 3 | col] <= 1'b0;
              end
        if (bish_count_t2 >= 2)
          begin
             pair_bonus_mg_t3 <= 38;
             pair_bonus_eg_t3 <= 56;
          end
        else
          begin
             pair_bonus_mg_t3 <= 0;
             pair_bonus_eg_t3 <= 0;
          end
        if (bish_count_t2 == 1)
          begin
             if (solo_bish_loc_t2[3] != solo_bish_loc_t2[0]) // white square
               tpawns_t4 <= mpow_count_t3;
             else
               tpawns_t4 <= mpob_count_t3;
             tpawn_penalty_mg_t5 <= -(tpawns_t4 * 4);
             tpawn_penalty_eg_t5 <= -(tpawns_t4 * 6);
          end
        else
          begin
             tpawn_penalty_mg_t5 <= 0;
             tpawn_penalty_eg_t5 <= 0;
          end
        eval_mg_t6 <= tpawn_penalty_mg_t5 + pair_bonus_mg_t3;
        eval_eg_t6 <= tpawn_penalty_eg_t5 + pair_bonus_eg_t3;
        if (WHITE_BISHOPS)
          begin
             eval_mg <= eval_mg_t6;
             eval_eg <= eval_eg_t6;
          end
        else
          begin
             eval_mg <= -eval_mg_t6;
             eval_eg <= -eval_eg_t6;
          end
     end
   
   /* popcount AUTO_TEMPLATE (
    .x0 (my_pawn_on_white_loc_t2[]),
    .population (mpow_count_t3[]),
    );*/
   popcount popcount_mpow
     (/*AUTOINST*/
      // Outputs
      .population                       (mpow_count_t3[5:0]),    // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (my_pawn_on_white_loc_t2[63:0])); // Templated

   /* popcount AUTO_TEMPLATE (
    .x0 (my_pawn_on_black_loc_t2[]),
    .population (mpob_count_t3[]),
    );*/
   popcount popcount_mpob
     (/*AUTOINST*/
      // Outputs
      .population                       (mpob_count_t3[5:0]),    // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (my_pawn_on_black_loc_t2[63:0])); // Templated

   /* popcount AUTO_TEMPLATE (
    .x0 (bish_loc_t1[]),
    .population (bish_count_t2[]),
    );*/
   popcount popcount
     (/*AUTOINST*/
      // Outputs
      .population                       (bish_count_t2[5:0]),    // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (bish_loc_t1[63:0]));     // Templated

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
