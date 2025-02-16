// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

module evaluate_material #
  (
   parameter EVAL_WIDTH = 0,
   parameter P_VAL_WIDTH = 0
   )
   (
    input                                clk,
    input                                reset,

    input                                board_valid,
    input [`BOARD_WIDTH - 1:0]           board,
    input                                white_to_move,

    input signed [P_VAL_WIDTH - 1:0]     totp_black_t4,
    input signed [P_VAL_WIDTH - 1:0]     totp_white_t4,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg_t8,
    output reg signed [EVAL_WIDTH - 1:0] eval_eg_t8
    );

   localparam VALUE_COUNT = 1 << `PIECE_WIDTH;

   localparam PAWN_VALUE =  100;
   localparam KNIT_VALUE =  305;
   localparam BISH_VALUE =  305;
   localparam ROOK_VALUE =  490;
   localparam QUEN_VALUE = 1000;
   localparam KING_VALUE = `GLOBAL_VALUE_KING;

   localparam P_VAL_COUNT = 1 << `PIECE_WIDTH;

   reg signed [P_VAL_WIDTH - 1:0]        p_val_white [0:VALUE_COUNT - 1];
   reg signed [P_VAL_WIDTH - 1:0]        p_val_black [0:VALUE_COUNT - 1];
   reg signed [EVAL_WIDTH - 1:0]         value_table [0:VALUE_COUNT - 1];
   reg signed [EVAL_WIDTH - 1:0]         move_bonus_mg [0:1];
   reg signed [EVAL_WIDTH - 1:0]         move_bonus_eg [0:1];
   reg signed [EVAL_WIDTH - 1:0]         bad_trade;

   reg signed [EVAL_WIDTH - 1:0]         material_t1 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         sum_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         sum_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         sum_t4;
   reg signed [EVAL_WIDTH - 1:0]         sum_mg_t5, sum_mg_t6, sum_mg_t7;
   reg signed [EVAL_WIDTH - 1:0]         sum_eg_t5, sum_eg_t6, sum_eg_t7;

   reg [63:0]                            quen_white_t1;
   reg [63:0]                            quen_black_t1;
   reg [63:0]                            rook_white_t1;
   reg [63:0]                            rook_black_t1;
   reg [63:0]                            minor_white_t1;
   reg [63:0]                            minor_black_t1;

   reg signed [EVAL_WIDTH - 1:0]         majors_t3;
   reg signed [EVAL_WIDTH - 1:0]         minors_t3;
   reg signed [EVAL_WIDTH - 1:0]         majors_t4;
   reg signed [EVAL_WIDTH - 1:0]         minors_t4;
   reg signed [EVAL_WIDTH - 1:0]         majors_t5;
   reg signed [EVAL_WIDTH - 1:0]         minors_t5;
   reg signed [EVAL_WIDTH - 1:0]         tot_diff_t5;
   reg signed [EVAL_WIDTH - 1:0]         score_mg_t6, score_eg_t6;
   reg signed [EVAL_WIDTH - 1:0]         score_mg_t7, score_eg_t7;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [5:0]           minor_black_count_t2;   // From minor_black of popcount.v
   wire [5:0]           minor_white_count_t2;   // From minor_white of popcount.v
   wire [5:0]           quen_black_count_t2;    // From quen_black of popcount.v
   wire [5:0]           quen_white_count_t2;    // From quen_white of popcount.v
   wire [5:0]           rook_black_count_t2;    // From rook_black of popcount.v
   wire [5:0]           rook_white_count_t2;    // From rook_white of popcount.v
   // End of automatics

   function signed [EVAL_WIDTH - 1:0] abs_x (input signed [EVAL_WIDTH - 1:0] x);
      begin
         if (x < 0)
           abs_x = -x;
         else
           abs_x = x;
      end
   endfunction

   function signed [EVAL_WIDTH - 1:0] sign_x (input signed [EVAL_WIDTH - 1:0] x);
      begin
         if (x < 0)
           sign_x = -1;
         else
           sign_x = 1;
      end
   endfunction

   integer                               i;

   wire [`BOARD_WIDTH - 1:0]             board_t0 = board;

   initial
     begin
        for (i = 0; i < VALUE_COUNT; i = i + 1)
          value_table[i] = 0;
        value_table[`WHITE_PAWN] = PAWN_VALUE;
        value_table[`WHITE_KNIT] = KNIT_VALUE;
        value_table[`WHITE_BISH] = BISH_VALUE;
        value_table[`WHITE_ROOK] = ROOK_VALUE;
        value_table[`WHITE_QUEN] = QUEN_VALUE;
        value_table[`WHITE_KING] = KING_VALUE;

        value_table[`BLACK_PAWN] = -PAWN_VALUE;
        value_table[`BLACK_KNIT] = -KNIT_VALUE;
        value_table[`BLACK_BISH] = -BISH_VALUE;
        value_table[`BLACK_ROOK] = -ROOK_VALUE;
        value_table[`BLACK_QUEN] = -QUEN_VALUE;
        value_table[`BLACK_KING] = -KING_VALUE;

        move_bonus_mg[0] = -8; // black
        move_bonus_eg[0] = -5;
        move_bonus_mg[1] = 8; // white
        move_bonus_eg[1] = 5;

        bad_trade = 90;

        for (i = 0; i < P_VAL_COUNT; i = i + 1)
          begin
             p_val_white[i] = 0;
             p_val_black[i] = 0;
          end
        p_val_white[`EMPTY_POSN] = 0;
        p_val_white[`WHITE_PAWN] = 0;
        p_val_white[`WHITE_KNIT] = 3;
        p_val_white[`WHITE_BISH] = 3;
        p_val_white[`WHITE_ROOK] = 5;
        p_val_white[`WHITE_QUEN] = 9;
        p_val_white[`WHITE_KING] = 0;

        p_val_black[`EMPTY_POSN] = 0;
        p_val_black[`BLACK_PAWN] = 0;
        p_val_black[`BLACK_KNIT] = 3;
        p_val_black[`BLACK_BISH] = 3;
        p_val_black[`BLACK_ROOK] = 5;
        p_val_black[`BLACK_QUEN] = 9;
        p_val_black[`BLACK_KING] = 0;
     end

   always @(posedge clk)
     begin
        for (i = 0; i < 64; i = i + 1)
          begin
             quen_white_t1[i] <= board_t0[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_QUEN;
             rook_white_t1[i] <= board_t0[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_ROOK;
             quen_black_t1[i] <= board_t0[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_QUEN;
             rook_black_t1[i] <= board_t0[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_ROOK;

             minor_white_t1[i] <= board_t0[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_BISH ||
                                  board_t0[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_KNIT;
             minor_black_t1[i] <= board_t0[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_BISH ||
                                  board_t0[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_KNIT;
          end

        majors_t3 <= $signed({1'b0, rook_white_count_t2}) * p_val_white[`WHITE_ROOK] +
                     2 * $signed({1'b0, quen_white_count_t2}) * p_val_white[`WHITE_QUEN] -
                     $signed({1'b0, rook_black_count_t2}) * p_val_black[`BLACK_ROOK] -
                     2 * $signed({1'b0, quen_black_count_t2}) * p_val_black[`BLACK_QUEN];
        minors_t3 <= $signed({1'b0, minor_white_count_t2}) * p_val_white[`WHITE_BISH] -
                     $signed({1'b0, minor_black_count_t2}) * p_val_white[`BLACK_BISH];

        majors_t4 <= majors_t3;
        minors_t4 <= minors_t3;

        tot_diff_t5 <= totp_white_t4 - totp_black_t4;
        majors_t5 <= majors_t4;
        minors_t5 <= minors_t4;

        score_mg_t6 <= 0;
        score_eg_t6 <= 0;
        if (majors_t5 != 0 || minors_t5 != 0)
          if (abs_x(tot_diff_t5) != 2 && tot_diff_t5 != 0)
            begin
               score_mg_t6 <= sign_x(tot_diff_t5) * bad_trade;
               score_eg_t6 <= sign_x(tot_diff_t5) * bad_trade;
            end
        score_mg_t7 <= score_mg_t6;
        score_eg_t7 <= score_eg_t6;
     end

   always @(posedge clk)
     begin
        for (i = 0; i < 64; i = i + 1)
          material_t1[i] <= value_table[board_t0[i * `PIECE_WIDTH+:`PIECE_WIDTH]];
        for (i = 0; i < 16; i = i + 1)
          sum_t2[i] <= material_t1[i * 4 + 0] + material_t1[i * 4 + 1] + material_t1[i * 4 + 2] + material_t1[i * 4 + 3];
        for (i = 0; i < 4; i = i + 1)
          sum_t3[i] <= sum_t2[i * 4 + 0] + sum_t2[i * 4 + 1] + sum_t2[i * 4 + 2] + sum_t2[i * 4 + 3];
        sum_t4 <= sum_t3[0] + sum_t3[1] + sum_t3[2] + sum_t3[3];

        sum_mg_t5 <= sum_t4 + move_bonus_mg[white_to_move];
        sum_eg_t5 <= sum_t4 + move_bonus_eg[white_to_move];

        sum_mg_t6 <= sum_mg_t5;
        sum_eg_t6 <= sum_eg_t5;

        sum_mg_t7 <= sum_mg_t6;
        sum_eg_t7 <= sum_eg_t6;

        eval_mg_t8 <= score_mg_t7 + sum_mg_t7;
        eval_eg_t8 <= score_eg_t7 + sum_eg_t7;
     end

   /* popcount AUTO_TEMPLATE (
    .population (@"(downcase vl-cell-name)"_count_t2[]),
    .x0 (@"(downcase vl-cell-name)"_t1[]),
    );*/
   popcount quen_white
     (/*AUTOINST*/
      // Outputs
      .population                       (quen_white_count_t2[5:0]), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (quen_white_t1[63:0]));   // Templated
   popcount quen_black
     (/*AUTOINST*/
      // Outputs
      .population                       (quen_black_count_t2[5:0]), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (quen_black_t1[63:0]));   // Templated
   popcount rook_white
     (/*AUTOINST*/
      // Outputs
      .population                       (rook_white_count_t2[5:0]), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (rook_white_t1[63:0]));   // Templated
   popcount rook_black
     (/*AUTOINST*/
      // Outputs
      .population                       (rook_black_count_t2[5:0]), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (rook_black_t1[63:0]));   // Templated
   popcount minor_white
     (/*AUTOINST*/
      // Outputs
      .population                       (minor_white_count_t2[5:0]), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (minor_white_t1[63:0]));  // Templated
   popcount minor_black
     (/*AUTOINST*/
      // Outputs
      .population                       (minor_black_count_t2[5:0]), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (minor_black_t1[63:0]));  // Templated

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:
