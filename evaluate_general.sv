// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

module evaluate_general #
  (
   parameter EVAL_WIDTH = 0
   )
   (
    input                            clk,
    input                            reset,

    input [EVAL_WIDTH - 1:0]         random_score_mask,
    input [EVAL_WIDTH - 1:0]         random_number,

    input                            board_valid,
    input [`BOARD_WIDTH - 1:0]       board,
    input                            clear_eval,
    input                            white_to_move,
   
    output                           insufficient_material,
    output signed [EVAL_WIDTH - 1:0] eval_mg,
    output signed [EVAL_WIDTH - 1:0] eval_eg,
    output                           eval_valid
    );

   localparam LATENCY_COUNT = 7;

   reg signed [$clog2(`GLOBAL_VALUE_KING) - 1 + 1:0] value [`EMPTY_POSN:`BLACK_KING];
   reg signed [$clog2(`GLOBAL_VALUE_KING) - 1 + 1:0] pst_mg [`EMPTY_POSN:`BLACK_KING][0:63];
   reg signed [$clog2(`GLOBAL_VALUE_KING) - 1 + 1:0] pst_eg [`EMPTY_POSN:`BLACK_KING][0:63];
   reg [$clog2(`BOARD_WIDTH) - 1:0]                  idx [0:7][0:7];
   reg                                               insufficient_material_t4;

   reg signed [EVAL_WIDTH - 1:0]                     random_score_offset;
   
   reg signed [$clog2(`GLOBAL_VALUE_KING) - 1 + 2:0] score_mg_t1 [0:7][0:7];
   reg signed [$clog2(`GLOBAL_VALUE_KING) - 1 + 2:0] score_eg_t1 [0:7][0:7];
   reg signed [EVAL_WIDTH - 1:0]                     sum_a_mg_t2 [0:7][0:1];
   reg signed [EVAL_WIDTH - 1:0]                     sum_a_eg_t2 [0:7][0:1];
   reg signed [EVAL_WIDTH - 1:0]                     sum_a_mg_t3 [0:7][0:1];
   reg signed [EVAL_WIDTH - 1:0]                     sum_a_eg_t3 [0:7][0:1];
   reg signed [EVAL_WIDTH - 1:0]                     sum_b_mg_t4 [0:3];
   reg signed [EVAL_WIDTH - 1:0]                     sum_b_eg_t4 [0:3];
   reg signed [EVAL_WIDTH - 1:0]                     sum_b_mg_t5 [0:3];
   reg signed [EVAL_WIDTH - 1:0]                     sum_b_eg_t5 [0:3];
   reg signed [EVAL_WIDTH - 1:0]                     eval_mg_t6;
   reg signed [EVAL_WIDTH - 1:0]                     eval_eg_t6;
   
   reg [1:0]                                         isw_t1 [0:63];
   reg [1:0]                                         isb_t1 [0:63];
   reg [8:0]                                         isw_accum_t3;
   reg [8:0]                                         isb_accum_t3;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   integer                                           i, ri, y, x;

   assign eval_mg = eval_mg_t6 + random_score_offset;
   assign eval_eg = eval_eg_t6 + random_score_offset;
   assign insufficient_material = insufficient_material_t4;

   always @(posedge clk)
     begin
        if (random_number[EVAL_WIDTH - 1])
          random_score_offset <= $signed(random_number[EVAL_WIDTH - 2:0] & random_score_mask);
        else
          random_score_offset <= -$signed(random_number[EVAL_WIDTH - 2:0] & random_score_mask);
        for (i = 0; i < 64; i = i + 1)
          begin
             if (board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_PAWN ||
                 board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_ROOK ||
                 board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_QUEN)
               isw_t1[i] <= 2'b11;
             else if (board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_BISH ||
                      board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_KNIT)
               isw_t1[i] <= 2'b01;
             else
               isw_t1[i] <= 2'b00;
             if (board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_PAWN ||
                 board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_ROOK ||
                 board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_QUEN)
               isb_t1[i] <= 2'b11;
             else if (board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_BISH ||
                      board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_KNIT)
               isb_t1[i] <= 2'b01;
             else
               isb_t1[i] <= 2'b00;
          end

        isw_accum_t3 <= isw_t1[ 0] + isw_t1[ 1] + isw_t1[ 2] + isw_t1[ 3] + isw_t1[ 4] + isw_t1[ 5] + isw_t1[ 6] + isw_t1[ 7] +
                        isw_t1[ 8] + isw_t1[ 9] + isw_t1[10] + isw_t1[11] + isw_t1[12] + isw_t1[13] + isw_t1[14] + isw_t1[15] +
                        isw_t1[16] + isw_t1[17] + isw_t1[18] + isw_t1[19] + isw_t1[20] + isw_t1[21] + isw_t1[22] + isw_t1[23] +
                        isw_t1[24] + isw_t1[25] + isw_t1[26] + isw_t1[27] + isw_t1[28] + isw_t1[29] + isw_t1[30] + isw_t1[31] +
                        isw_t1[32] + isw_t1[33] + isw_t1[34] + isw_t1[35] + isw_t1[36] + isw_t1[37] + isw_t1[38] + isw_t1[39] +
                        isw_t1[40] + isw_t1[41] + isw_t1[42] + isw_t1[43] + isw_t1[44] + isw_t1[45] + isw_t1[46] + isw_t1[47] +
                        isw_t1[48] + isw_t1[49] + isw_t1[50] + isw_t1[51] + isw_t1[52] + isw_t1[53] + isw_t1[54] + isw_t1[55] +
                        isw_t1[56] + isw_t1[57] + isw_t1[58] + isw_t1[59] + isw_t1[60] + isw_t1[61] + isw_t1[62] + isw_t1[63];
        
        isb_accum_t3 <= isb_t1[ 0] + isb_t1[ 1] + isb_t1[ 2] + isb_t1[ 3] + isb_t1[ 4] + isb_t1[ 5] + isb_t1[ 6] + isb_t1[ 7] +
                        isb_t1[ 8] + isb_t1[ 9] + isb_t1[10] + isb_t1[11] + isb_t1[12] + isb_t1[13] + isb_t1[14] + isb_t1[15] +
                        isb_t1[16] + isb_t1[17] + isb_t1[18] + isb_t1[19] + isb_t1[20] + isb_t1[21] + isb_t1[22] + isb_t1[23] +
                        isb_t1[24] + isb_t1[25] + isb_t1[26] + isb_t1[27] + isb_t1[28] + isb_t1[29] + isb_t1[30] + isb_t1[31] +
                        isb_t1[32] + isb_t1[33] + isb_t1[34] + isb_t1[35] + isb_t1[36] + isb_t1[37] + isb_t1[38] + isb_t1[39] +
                        isb_t1[40] + isb_t1[41] + isb_t1[42] + isb_t1[43] + isb_t1[44] + isb_t1[45] + isb_t1[46] + isb_t1[47] +
                        isb_t1[48] + isb_t1[49] + isb_t1[50] + isb_t1[51] + isb_t1[52] + isb_t1[53] + isb_t1[54] + isb_t1[55] +
                        isb_t1[56] + isb_t1[57] + isb_t1[58] + isb_t1[59] + isb_t1[60] + isb_t1[61] + isb_t1[62] + isb_t1[63];
        insufficient_material_t4 <= ((isw_accum_t3 == 0 && isb_accum_t3 <= 1) || (isw_accum_t3 <= 1 && isb_accum_t3 == 0));
        
        for (y = 0; y < 8; y = y + 1)
          for (x = 0; x < 8; x = x + 1)
            begin
               score_mg_t1[y][x] <= value[board[idx[y][x]+:`PIECE_WIDTH]] + pst_mg[board[idx[y][x]+:`PIECE_WIDTH]][y << 3 | x];
               score_eg_t1[y][x] <= value[board[idx[y][x]+:`PIECE_WIDTH]] + pst_eg[board[idx[y][x]+:`PIECE_WIDTH]][y << 3 | x];
            end
        for (y = 0; y < 8; y = y + 1)
          for (x = 0; x < 8; x = x + 4)
            begin
               sum_a_mg_t2[y][x / 4] <= score_mg_t1[y][x + 0] + score_mg_t1[y][x + 1] + score_mg_t1[y][x + 2] + score_mg_t1[y][x + 3];
               sum_a_eg_t2[y][x / 4] <= score_eg_t1[y][x + 0] + score_eg_t1[y][x + 1] + score_eg_t1[y][x + 2] + score_eg_t1[y][x + 3];
            end
        for (y = 0; y < 8; y = y + 1)
          for (x = 0; x < 2; x = x + 1)
            begin
               sum_a_mg_t3[y][x] <= sum_a_mg_t2[y][x];
               sum_a_eg_t3[y][x] <= sum_a_eg_t2[y][x];
            end
        for (y = 0; y < 8; y = y + 2)
          begin
             sum_b_mg_t4[y / 2] <= sum_a_mg_t3[y + 0][0] + sum_a_mg_t3[y + 0][1] + sum_a_mg_t3[y + 1][0] + sum_a_mg_t3[y + 1][1];
             sum_b_eg_t4[y / 2] <= sum_a_eg_t3[y + 0][0] + sum_a_eg_t3[y + 0][1] + sum_a_eg_t3[y + 1][0] + sum_a_eg_t3[y + 1][1];
          end
        for (y = 0; y < 4; y = y + 1)
          begin
             sum_b_mg_t5[y] <= sum_b_mg_t4[y];
             sum_b_eg_t5[y] <= sum_b_eg_t4[y];
          end
        eval_mg_t6 <= sum_b_mg_t5[0] + sum_b_mg_t5[1] + sum_b_mg_t5[2] + sum_b_mg_t5[3];
        eval_eg_t6 <= sum_b_eg_t5[0] + sum_b_eg_t5[1] + sum_b_eg_t5[2] + sum_b_eg_t5[3];
     end

   initial
     begin
        for (y = 0; y < 8; y = y + 1)
          begin
             ri = y * `SIDE_WIDTH;
             for (x = 0; x < 8; x = x + 1)
               idx[y][x] = ri + x * `PIECE_WIDTH;
          end
        
        for (ri = `EMPTY_POSN; ri <= `BLACK_KING; ri = ri + 1)
          begin
             value[ri] = 0;
             for (i = 0; i < 64; i = i + 1)
               pst_mg[ri][i] = 0;
          end

        for (ri = `EMPTY_POSN; ri <= `BLACK_KING; ri = ri + 1)
          begin
             value[ri] = 0;
             for (i = 0; i < 64; i = i + 1)
               pst_eg[ri][i] = 0;
          end

`include "evaluate_general.vh"

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
