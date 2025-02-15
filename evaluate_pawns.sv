// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

// note:
// - black/white pawn evaluation is symmetric, so for black flip rows as though white and negate
//   eval on output

module evaluate_pawns #
  (
   parameter EVAL_WIDTH = 0,
   parameter WHITE_PAWNS = 0
   )
   (
    input                                clk,
    input                                reset,

    input                                board_valid,
    input [`BOARD_WIDTH - 1:0]           board,
    input                                white_to_move,
    input [63:0]                         white_is_attacking,
    input [63:0]                         black_is_attacking,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg_t8,
    output reg signed [EVAL_WIDTH - 1:0] eval_eg_t8,
    output reg                           eval_valid_t8
    );

   localparam MY_PAWN = WHITE_PAWNS ? `WHITE_PAWN : `BLACK_PAWN;
   localparam OP_PAWN = WHITE_PAWNS ? `BLACK_PAWN : `WHITE_PAWN;
   localparam MY_KING = WHITE_PAWNS ? `WHITE_KING : `BLACK_KING;
   localparam OP_KING = WHITE_PAWNS ? `BLACK_KING : `WHITE_KING;

   reg signed [EVAL_WIDTH - 1:0]         pawns_isolated_mg [0:7];
   reg signed [EVAL_WIDTH - 1:0]         pawns_isolated_eg [0:7];
   reg signed [EVAL_WIDTH - 1:0]         pawns_doubled_mg [0:7][1:5];
   reg signed [EVAL_WIDTH - 1:0]         pawns_doubled_eg [0:7][1:5];
   reg signed [EVAL_WIDTH - 1:0]         pawns_connected_mg [0:7][0:7];
   reg signed [EVAL_WIDTH - 1:0]         pawns_connected_eg [0:7][0:7];
   reg signed [EVAL_WIDTH - 1:0]         pawns_backward_mg [0:7];
   reg signed [EVAL_WIDTH - 1:0]         pawns_backward_eg [0:7];
   reg signed [EVAL_WIDTH - 1:0]         passed_pawn [0:7];
   reg [63:0]                            not_passed_mask [0:63];
   reg [63:0]                            passed_pawn_path [0:63];
   reg signed [EVAL_WIDTH - 1:0]         passed_pawn_base_mg;
   reg signed [EVAL_WIDTH - 1:0]         passed_pawn_base_eg;
   reg signed [EVAL_WIDTH - 1:0]         passed_pawn_free_advance;
   reg signed [EVAL_WIDTH - 1:0]         passed_pawn_defended;
   reg signed [EVAL_WIDTH - 1:0]         pawn_can_promote;

   reg [63:0]                            board_neutral_t1, board_neutral_t2;
   reg [63:0]                            enemy_neutral_t1, enemy_neutral_t2, enemy_neutral_t3;
   reg [7:0]                             col_with_pawn_t1;

   reg [2:0]                             my_king_row_t1, my_king_col_t1;
   reg [2:0]                             my_king_row_t2, my_king_col_t2;
   reg [2:0]                             op_king_row_t1, op_king_col_t1;
   reg [2:0]                             op_king_row_t2, op_king_col_t2;
   reg                                   my_occupied_t1, my_occupied_t2;
   reg                                   op_occupied_t1, op_occupied_t2;
   reg                                   opposition_t2;
   reg                                   on_move_t1;
   reg [2:0]                             my_king_a8_dist_t2, my_king_h8_dist_t2;
   reg [2:0]                             my_king_pawn_dist_t3 [0:7];
   reg [2:0]                             op_king_pawn_dist_t3 [0:7];
   reg [2:0]                             op_king_row7_dist_t2 [0:7];
   reg [2:0]                             op_king_row7_dist_t3 [0:7];

   reg signed [EVAL_WIDTH - 1:0]         isolated_mg_t2 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         isolated_eg_t2 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         isolated_mg_t3 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         isolated_eg_t3 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         isolated_mg_t4 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         isolated_eg_t4 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         isolated_mg_t5, isolated_mg_t6;
   reg signed [EVAL_WIDTH - 1:0]         isolated_eg_t5, isolated_eg_t6;

   reg [3:0]                             doubled_distance_t2 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         doubled_mg_t3 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         doubled_eg_t3 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         doubled_mg_t4 [0:7];
   reg signed [EVAL_WIDTH - 1:0]         doubled_eg_t4 [0:7];
   reg signed [EVAL_WIDTH - 1:0]         doubled_mg_t5 [0:1];
   reg signed [EVAL_WIDTH - 1:0]         doubled_eg_t5 [0:1];
   reg signed [EVAL_WIDTH - 1:0]         doubled_mg_t6;
   reg signed [EVAL_WIDTH - 1:0]         doubled_eg_t6;

   reg [63:0]                            connected_t2;
   reg signed [EVAL_WIDTH - 1:0]         connected_mg_t3 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         connected_eg_t3 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         connected_mg_t4 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         connected_eg_t4 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         connected_mg_t5 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         connected_eg_t5 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         connected_mg_t6;
   reg signed [EVAL_WIDTH - 1:0]         connected_eg_t6;

   reg [63:0]                            backward_t2;
   reg signed [EVAL_WIDTH - 1:0]         backward_mg_t3 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         backward_eg_t3 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         backward_mg_t4 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         backward_eg_t4 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         backward_mg_t5 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         backward_eg_t5 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         backward_mg_t6;
   reg signed [EVAL_WIDTH - 1:0]         backward_eg_t6;

   reg [2:0]                             most_adv_row_t2 [0:7];
   reg [7:0]                             passed_pawn_t3;
   reg [2:0]                             dist_to_queen_t3 [0:7];
   reg signed [EVAL_WIDTH - 1:0]         bonus_t3 [0:7];
   reg signed [EVAL_WIDTH - 1:0]         score_mult_t3 [0:7];
   reg signed [EVAL_WIDTH - 1:0]         passed_mg_t4 [0:7];
   reg signed [EVAL_WIDTH - 1:0]         passed_eg_t4 [0:7];
   reg signed [EVAL_WIDTH - 1:0]         passed_mg_t5 [0:1];
   reg signed [EVAL_WIDTH - 1:0]         passed_eg_t5 [0:1];
   reg signed [EVAL_WIDTH - 1:0]         passed_mg_t6;
   reg signed [EVAL_WIDTH - 1:0]         passed_eg_t6;

   reg                                   simple_pawn_can_promote_bonus_t3;
   reg signed [EVAL_WIDTH - 1:0]         pawn_can_promote_bonus_t4;
   reg signed [EVAL_WIDTH - 1:0]         pawn_race_win_t4;
   reg signed [EVAL_WIDTH - 1:0]         queener_t5, queener_t6;

   reg signed [EVAL_WIDTH - 1:0]         eval_mg_t7;
   reg signed [EVAL_WIDTH - 1:0]         eval_eg_t7;

   reg [2:0]                             row_flip [0:1][0:7];
   reg [63:0]                            enemy_is_attacking_t1;
   reg [63:0]                            enemy_is_attacking_t2;
   reg [63:0]                            square_is_defended_t1;
   reg [63:0]                            square_is_defended_t2;

   reg                                   eval_valid_t1, eval_valid_t2, eval_valid_t3, eval_valid_t4, eval_valid_t5, eval_valid_t6, eval_valid_t7;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   integer                               i, row, col, row_adv;

   wire [`BOARD_WIDTH - 1:0]             board_t0 = board;
   wire                                  eval_valid_t0 = board_valid;
   wire                                  white_to_move_t0 = white_to_move;
   wire [63:0]                           white_is_attacking_t0 = white_is_attacking;
   wire [63:0]                           black_is_attacking_t0 = black_is_attacking;

   function [2:0] dist_x  (input [2:0] x0, input [2:0] x1);
      begin
         reg [2:0] diff;

         if (x0 > x1)
           diff = x0 - x1;
         else
           diff = x1 - x0;

         dist_x = diff;
      end
   endfunction

   function [2:0] dist_max (input [2:0] dist_row, input [2:0] dist_col);
      begin
         if (dist_row > dist_col)
           dist_max = dist_row;
         else
           dist_max = dist_col;
      end
   endfunction

   // note: only correct within scope of usage in this module, not a general solution!
   function has_opposition (input [2:0] my_k_row, input [2:0] my_k_col, input [2:0] op_k_row, input [2:0] op_k_col, input on_move_t1);
      begin
         reg outcome;
         reg [2:0] col_distance, row_distance;

         col_distance = dist_x(my_k_col, op_k_col);
         row_distance = dist_x(my_k_row, op_k_row);
         outcome = 0;
         if (row_distance < 2)
           outcome = 1;
         else
           begin
              if (on_move_t1)
                begin
                   if (row_distance & 1)
                     row_distance = row_distance - 1;
                   if (col_distance & 1)
                     col_distance = col_distance - 1;
                end
              if (!(col_distance & 1) && !(row_distance & 1))
                outcome = 1;
           end
         has_opposition = outcome;
      end
   endfunction

   function [2:0] distance (input [2:0] row0, input [2:0] col0, input [2:0] row1, input [2:0] col1);
      begin
         reg [2:0] dist_row, dist_col;

         dist_row = dist_x(row0, row1);
         dist_col = dist_x(col0, col1);
         distance = dist_max(dist_row, dist_col);
      end
   endfunction

   always @(posedge clk)
     begin
        isolated_mg_t6 <= isolated_mg_t5;
        isolated_eg_t6 <= isolated_eg_t5;

        queener_t6 <= queener_t5;

        eval_mg_t7 <= isolated_mg_t6 + doubled_mg_t6 + connected_mg_t6 + backward_mg_t6 + passed_mg_t6;
        eval_eg_t7 <= isolated_eg_t6 + doubled_eg_t6 + connected_eg_t6 + backward_eg_t6 + passed_eg_t6 + queener_t6;

        eval_mg_t8 <= WHITE_PAWNS ? eval_mg_t7 : -eval_mg_t7;
        eval_eg_t8 <= WHITE_PAWNS ? eval_eg_t7 : -eval_eg_t7;
     end

   always @(posedge clk)
     begin
        col_with_pawn_t1 <= 0;
        my_occupied_t1 <= 0;
        op_occupied_t1 <= 0;
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            begin
               if (WHITE_PAWNS)
                 case (board_t0[(row << 3 | col)  * `PIECE_WIDTH+:`PIECE_WIDTH])
                   `WHITE_ROOK : my_occupied_t1 <= 1;
                   `WHITE_KNIT : my_occupied_t1 <= 1;
                   `WHITE_BISH : my_occupied_t1 <= 1;
                   `WHITE_QUEN : my_occupied_t1 <= 1;
                   `BLACK_ROOK : op_occupied_t1 <= 1;
                   `BLACK_KNIT : op_occupied_t1 <= 1;
                   `BLACK_BISH : op_occupied_t1 <= 1;
                   `BLACK_QUEN : op_occupied_t1 <= 1;
                 endcase
               else
                 case (board_t0[(row << 3 | col)  * `PIECE_WIDTH+:`PIECE_WIDTH])
                   `BLACK_ROOK : my_occupied_t1 <= 1;
                   `BLACK_KNIT : my_occupied_t1 <= 1;
                   `BLACK_BISH : my_occupied_t1 <= 1;
                   `BLACK_QUEN : my_occupied_t1 <= 1;
                   `WHITE_ROOK : op_occupied_t1 <= 1;
                   `WHITE_KNIT : op_occupied_t1 <= 1;
                   `WHITE_BISH : op_occupied_t1 <= 1;
                   `WHITE_QUEN : op_occupied_t1 <= 1;
                 endcase

               if (board_t0[((row_flip[WHITE_PAWNS][row] << 3) | col) * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_KING)
                 begin
                    my_king_col_t1 <= col;
                    my_king_row_t1 <= row;
                 end
               if (board_t0[((row_flip[WHITE_PAWNS][row] << 3) | col) * `PIECE_WIDTH+:`PIECE_WIDTH] == OP_KING)
                 begin
                    op_king_col_t1 <= col;
                    op_king_row_t1 <= row;
                 end
	       if (WHITE_PAWNS)
		 begin
		    enemy_is_attacking_t1[(row_flip[WHITE_PAWNS][row] << 3) | col] <= black_is_attacking_t0[row << 3 | col];
		    square_is_defended_t1[(row_flip[WHITE_PAWNS][row] << 3) | col] <= white_is_attacking_t0[row << 3 | col];
		 end
	       else
		 begin
		    enemy_is_attacking_t1[(row_flip[WHITE_PAWNS][row] << 3) | col] <= white_is_attacking_t0[row << 3 | col];
		    square_is_defended_t1[(row_flip[WHITE_PAWNS][row] << 3) | col] <= black_is_attacking_t0[row << 3 | col];
		 end
               if (row != 0 && row != 7)
                 begin
                    board_neutral_t1[(row_flip[WHITE_PAWNS][row] << 3) | col] <= board_t0[(row << 3 | col)  * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_PAWN;
                    enemy_neutral_t1[(row_flip[WHITE_PAWNS][row] << 3) | col] <= board_t0[(row << 3 | col)  * `PIECE_WIDTH+:`PIECE_WIDTH] == OP_PAWN;
                    if (board_t0[(row << 3 | col)  * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_PAWN)
                      col_with_pawn_t1[col] <= 1;
                 end
               else
                 begin
                    board_neutral_t1[row << 3 | col] <= 1'b0; // keep x's out of sim, tossed by optimizer
                    enemy_neutral_t1[row << 3 | col] <= 1'b0;
                 end
            end

        square_is_defended_t2 <= square_is_defended_t1;
        enemy_is_attacking_t2 <= enemy_is_attacking_t1;

        my_king_row_t2 <= my_king_row_t1;
        my_king_col_t2 <= my_king_col_t1;
        op_king_row_t2 <= op_king_row_t1;
        op_king_col_t2 <= op_king_col_t1;

        my_king_a8_dist_t2 <= distance(7, 0, my_king_row_t1, my_king_col_t1);
        my_king_h8_dist_t2 <= distance(7, 7, my_king_row_t1, my_king_col_t1);
        for (col = 0; col < 8; col = col + 1)
          begin
             op_king_row7_dist_t2[col] <= distance(7, col, op_king_row_t1, op_king_col_t1);
             op_king_row7_dist_t3[col] <= op_king_row7_dist_t2[col];
          end

        on_move_t1 <= (white_to_move_t0 && WHITE_PAWNS) || (! white_to_move_t0 && ! WHITE_PAWNS);
        opposition_t2 <= has_opposition(my_king_row_t1, my_king_col_t1, op_king_row_t1, op_king_col_t1, on_move_t1);

        for (col = 0; col < 8; col = col + 1)
          begin
             my_king_pawn_dist_t3[col] <= distance(my_king_row_t2, my_king_col_t2, most_adv_row_t2[col], col);
             op_king_pawn_dist_t3[col] <= distance(op_king_row_t2, op_king_col_t2, most_adv_row_t2[col], col);
          end

        for (col = 0; col < 8; col = col + 1)
          if (most_adv_row_t2[col] == 1)
            dist_to_queen_t3[col] <= 8 - most_adv_row_t2[col] - 1 - on_move_t1;
          else
            dist_to_queen_t3[col] <= 8 - most_adv_row_t2[col] - on_move_t1;
     end

   // pawn race simple
   always @(posedge clk)
     begin
        board_neutral_t2 <= board_neutral_t1;
        enemy_neutral_t2 <= enemy_neutral_t1;
        simple_pawn_can_promote_bonus_t3 <= 0;
        my_occupied_t2 <= my_occupied_t1;
        op_occupied_t2 <= op_occupied_t1;
        if (board_neutral_t2 != 0 && enemy_neutral_t2 == 0 && my_occupied_t2 == 0 && op_occupied_t2 == 0)
          for (col = 0; col < 8; col = col + 1)
            if (most_adv_row_t2[col] != 0)
              begin
                 if (my_king_row_t2 > most_adv_row_t2[col])
                   begin
                      if (col == 0 && my_king_col_t2 == 1 && my_king_a8_dist_t2 < op_king_row7_dist_t2[0]) // A8
                        simple_pawn_can_promote_bonus_t3 <= 1;
                      if (col == 7 && my_king_col_t2 == 6 && my_king_h8_dist_t2 < op_king_row7_dist_t2[7]) // H8
                        simple_pawn_can_promote_bonus_t3 <= 1;
                   end
                 if (my_king_pawn_dist_t3[col] < op_king_pawn_dist_t3[col])
                   begin
                      if (my_king_row_t2 > most_adv_row_t2[col] - 1)
                        simple_pawn_can_promote_bonus_t3 <= 1;
                      if (my_king_row_t1 == 5)
                        simple_pawn_can_promote_bonus_t3 <= 1;
                   end
              end
        if (simple_pawn_can_promote_bonus_t3)
          pawn_can_promote_bonus_t4 <= pawn_can_promote;
        else
          pawn_can_promote_bonus_t4 <= 0;

        enemy_neutral_t3 <= enemy_neutral_t2;
        pawn_race_win_t4 <= 0;
        if (enemy_neutral_t3 == 0)
          for (col = 0; col < 8; col = col + 1)
            if (passed_pawn_t3[col])
              if (dist_to_queen_t3[col] < op_king_row7_dist_t3[col])
                pawn_race_win_t4 <= pawn_can_promote; // todo: weight final award on closeness to row7

        if (pawn_can_promote_bonus_t4 > 0)
          queener_t5 <= pawn_can_promote_bonus_t4;
        else if (pawn_race_win_t4 > 0)
          queener_t5 <= pawn_can_promote;
        else
          queener_t5 <= 0;
     end

   // passed pawns
   always @(posedge clk)
     begin
        for (col = 0; col < 8; col = col + 1)
          most_adv_row_t2[col] <= 0; // row value of 0 is "no pawn" in this column

        for (row = 1; row < 7; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            if (board_neutral_t1[row << 3 | col])
              most_adv_row_t2[col] <= row;

        for (col = 0; col < 8; col = col + 1)
          if (most_adv_row_t2[col] != 0 && (enemy_neutral_t2[63:0] & not_passed_mask[most_adv_row_t2[col] << 3 | col]) == 0)
            begin
               passed_pawn_t3[col] <= 1'b1;
               score_mult_t3[col] <= passed_pawn[most_adv_row_t2[col]];
	       if (! enemy_is_attacking_t2[(most_adv_row_t2[col] + 1) << 3 | col])
		 if (square_is_defended_t2[(most_adv_row_t2[col] + 1) << 3 | col])
		   bonus_t3[col] <= passed_pawn_free_advance + passed_pawn_defended;
		 else
		   bonus_t3[col] <= passed_pawn_free_advance;
	       else if (square_is_defended_t2[(most_adv_row_t2[col] + 1) << 3 | col])
		 bonus_t3[col] <= passed_pawn_defended;
	       else
		 bonus_t3[col] <= 0;
            end
          else
            begin
               passed_pawn_t3[col] <= 1'b0;
               score_mult_t3[col] <= 0;
	       bonus_t3[col] <= 0;
            end
        for (col = 0; col < 8; col = col + 1)
          begin
             passed_mg_t4[col] <= score_mult_t3[col] * (passed_pawn_base_mg + bonus_t3[col]);
             passed_eg_t4[col] <= score_mult_t3[col] * (passed_pawn_base_eg + bonus_t3[col]);
          end
        for (i = 0; i < 2; i = i + 1)
          begin
             passed_mg_t5[i] <= passed_mg_t4[i * 4 + 0] + passed_mg_t4[i * 4 + 1] + passed_mg_t4[i * 4 + 2] + passed_mg_t4[i * 4 + 3];
             passed_eg_t5[i] <= passed_eg_t4[i * 4 + 0] + passed_eg_t4[i * 4 + 1] + passed_eg_t4[i * 4 + 2] + passed_eg_t4[i * 4 + 3];
          end
        passed_mg_t6 <= passed_mg_t5[0] + passed_mg_t5[1];
        passed_eg_t6 <= passed_eg_t5[0] + passed_eg_t5[1];
     end

   // backward pawns (no adjacent or rear supporting pawn)
   always @(posedge clk)
     begin
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            backward_t2[row << 3 | col] <= 0;
        for (row = 1; row < 7; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            if (board_neutral_t1[row << 3 | col])
              if (col == 0 && col_with_pawn_t1[1] != 0) // exclude isolated, penalized elsewhere
                begin
                   if (board_neutral_t1[(row - 1) << 3 | 1] == 0 && board_neutral_t1[row << 3 | 1] == 0)
                     backward_t2[row << 3 | col] <= 1;
                end
              else if (col == 7 && col_with_pawn_t1[6] != 0) // exclude isolated
                begin
                   if (board_neutral_t1[(row - 1) << 3 | 6] == 0 && board_neutral_t1[row << 3 | 6] == 0)
                     backward_t2[row << 3 | col] <= 1;
                end
              else if (col_with_pawn_t1[col - 1] != 0 || col_with_pawn_t1[col + 1] != 0) // exclude isolated
                if (board_neutral_t1[(row - 1) << 3 | (col - 1)] == 0 && board_neutral_t1[(row - 1) << 3 | (col + 1)] == 0 &&
                    board_neutral_t1[row << 3 | (col - 1)] == 0 && board_neutral_t1[row << 3 | (col + 1)] == 0)
                  backward_t2[row << 3 | col] <= 1;
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            if (backward_t2[row << 3 | col] && doubled_distance_t2[row << 3 | col] == 0) // exclude doubled, penalized elsewhere
              begin
                 backward_mg_t3[row << 3 | col] <= pawns_backward_mg[col];
                 backward_eg_t3[row << 3 | col] <= pawns_backward_eg[col];
              end
            else
              begin
                 backward_mg_t3[row << 3 | col] <= 0;
                 backward_eg_t3[row << 3 | col] <= 0;
              end
        for (i = 0; i < 16; i = i + 1)
          begin
             backward_mg_t4[i] <= backward_mg_t3[i * 4 + 0] + backward_mg_t3[i * 4 + 1] + backward_mg_t3[i * 4 + 2] + backward_mg_t3[i * 4 + 3];
             backward_eg_t4[i] <= backward_eg_t3[i * 4 + 0] + backward_eg_t3[i * 4 + 1] + backward_eg_t3[i * 4 + 2] + backward_eg_t3[i * 4 + 3];
          end
        for (i = 0; i < 4; i = i + 1)
          begin
             backward_mg_t5[i] <= backward_mg_t4[i * 4 + 0] + backward_mg_t4[i * 4 + 1] + backward_mg_t4[i * 4 + 2] + backward_mg_t4[i * 4 + 3];
             backward_eg_t5[i] <= backward_eg_t4[i * 4 + 0] + backward_eg_t4[i * 4 + 1] + backward_eg_t4[i * 4 + 2] + backward_eg_t4[i * 4 + 3];
          end
        backward_mg_t6 <= backward_mg_t5[0] + backward_mg_t5[1] + backward_mg_t5[2] + backward_mg_t5[3];
        backward_eg_t6 <= backward_eg_t5[0] + backward_eg_t5[1] + backward_eg_t5[2] + backward_eg_t5[3];
     end

   // connected pawns (per crafty masking)
   always @(posedge clk)
     begin
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            connected_t2[row << 3 | col] <= 0;
        for (row = 1; row < 7; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            if (board_neutral_t1[row << 3 | col])
              if (col == 0 && (board_neutral_t1[row << 3 | 1] || board_neutral_t1[(row - 1) << 3 | 1]))
                connected_t2[row << 3 | col] <= 1;
              else if (col == 7 && (board_neutral_t1[row << 3 | 6] || board_neutral_t1[(row - 1) << 3 | 6]))
                connected_t2[row << 3 | col] <= 1;
              else if (board_neutral_t1[row << 3 | (col - 1)] || board_neutral_t1[row << 3 | (col + 1)] ||
                       board_neutral_t1[(row - 1) << 3 | (col - 1)] || board_neutral_t1[(row - 1) << 3 | (col + 1)])
                connected_t2[row << 3 | col] <= 1;
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            if (connected_t2[row << 3 | col])
              begin
                 connected_mg_t3[row << 3 | col] <= pawns_connected_mg[row][col];
                 connected_eg_t3[row << 3 | col] <= pawns_connected_eg[row][col];
              end
            else
              begin
                 connected_mg_t3[row << 3 | col] <= 0;
                 connected_eg_t3[row << 3 | col] <= 0;
              end
        for (i = 0; i < 16; i = i + 1)
          begin
             connected_mg_t4[i] <= connected_mg_t3[i * 4 + 0] + connected_mg_t3[i * 4 + 1] + connected_mg_t3[i * 4 + 2] + connected_mg_t3[i * 4 + 3];
             connected_eg_t4[i] <= connected_eg_t3[i * 4 + 0] + connected_eg_t3[i * 4 + 1] + connected_eg_t3[i * 4 + 2] + connected_eg_t3[i * 4 + 3];
          end
        for (i = 0; i < 4; i = i + 1)
          begin
             connected_mg_t5[i] <= connected_mg_t4[i * 4 + 0] + connected_mg_t4[i * 4 + 1] + connected_mg_t4[i * 4 + 2] + connected_mg_t4[i * 4 + 3];
             connected_eg_t5[i] <= connected_eg_t4[i * 4 + 0] + connected_eg_t4[i * 4 + 1] + connected_eg_t4[i * 4 + 2] + connected_eg_t4[i * 4 + 3];
          end
        connected_mg_t6 <= connected_mg_t5[0] + connected_mg_t5[1] + connected_mg_t5[2] + connected_mg_t5[3];
        connected_eg_t6 <= connected_eg_t5[0] + connected_eg_t5[1] + connected_eg_t5[2] + connected_eg_t5[3];
     end

   // doubled pawns
   always @(posedge clk)
     begin
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            doubled_distance_t2[row << 3 | col] <= 0; // overridden below
        for (row = 1; row < 6; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            if (board_neutral_t1[row << 3 | col])
              for (row_adv = row + 1; row_adv < 7; row_adv = row_adv + 1)
                if (board_neutral_t1[row_adv << 3 | col])
                  doubled_distance_t2[row << 3 | col] <= row_adv - row;
        for (row = 1; row < 6; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            if (doubled_distance_t2[row << 3 | col])
              begin
                 doubled_mg_t3[row << 3 | col] <= pawns_doubled_mg[col][doubled_distance_t2[row << 3 | col]];
                 doubled_eg_t3[row << 3 | col] <= pawns_doubled_eg[col][doubled_distance_t2[row << 3 | col]];
              end
            else
              begin
                 doubled_mg_t3[row << 3 | col] <= 0;
                 doubled_eg_t3[row << 3 | col] <= 0;
              end
        for (i = 8; i < 40; i = i + 4)
          begin
             doubled_mg_t4[(i - 8) / 4] <= doubled_mg_t3[i + 0] +  doubled_mg_t3[i + 1] + doubled_mg_t3[i + 2] +  doubled_mg_t3[i + 3];
             doubled_eg_t4[(i - 8) / 4] <= doubled_eg_t3[i + 0] +  doubled_eg_t3[i + 1] + doubled_eg_t3[i + 2] +  doubled_eg_t3[i + 3];
          end
        for (i = 0; i < 2; i = i + 1)
          begin
             doubled_mg_t5[i] <= doubled_mg_t4[i * 4 + 0] + doubled_mg_t4[i * 4 + 1] + doubled_mg_t4[i * 4 + 2] + doubled_mg_t4[i * 4 + 3];
             doubled_eg_t5[i] <= doubled_eg_t4[i * 4 + 0] + doubled_eg_t4[i * 4 + 1] + doubled_eg_t4[i * 4 + 2] + doubled_eg_t4[i * 4 + 3];
          end
        doubled_mg_t6 <= doubled_mg_t5[0] + doubled_mg_t5[1];
        doubled_eg_t6 <= doubled_eg_t5[0] + doubled_eg_t5[1];
     end

   // isloated pawns
   always @(posedge clk)
     begin
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            begin
               isolated_mg_t2[row << 3 | col] <= 0;
               isolated_eg_t2[row << 3 | col] <= 0;
               if (board_neutral_t1[row << 3 | col])
                 if (col == 0)
                   begin
                      if (col_with_pawn_t1[1] == 0)
                        begin
                           isolated_mg_t2[row << 3 | col] <= pawns_isolated_mg[col];
                           isolated_eg_t2[row << 3 | col] <= pawns_isolated_eg[col];
                        end
                   end
                 else if (col == 7)
                   begin
                      if (col_with_pawn_t1[6] == 0)
                        begin
                           isolated_mg_t2[row << 3 | col] <= pawns_isolated_mg[col];
                           isolated_eg_t2[row << 3 | col] <= pawns_isolated_eg[col];
                        end
                   end
                 else
                   if (col_with_pawn_t1[col - 1] == 0 && col_with_pawn_t1[col + 1] == 0)
                     begin
                        isolated_mg_t2[row << 3 | col] <= pawns_isolated_mg[col];
                        isolated_eg_t2[row << 3 | col] <= pawns_isolated_eg[col];
                     end
            end
        for (i = 0; i < 16; i = i + 1)
          begin
             isolated_mg_t3[i] <= isolated_mg_t2[i * 4 + 0] + isolated_mg_t2[i * 4 + 1] + isolated_mg_t2[i * 4 + 2] + isolated_mg_t2[i * 4 + 3];
             isolated_eg_t3[i] <= isolated_eg_t2[i * 4 + 0] + isolated_eg_t2[i * 4 + 1] + isolated_eg_t2[i * 4 + 2] + isolated_eg_t2[i * 4 + 3];
          end
        for (i = 0; i < 4; i = i + 1)
          begin
             isolated_mg_t4[i] <= isolated_mg_t3[i * 4 + 0] + isolated_mg_t3[i * 4 + 1] + isolated_mg_t3[i * 4 + 2] + isolated_mg_t3[i * 4 + 3];
             isolated_eg_t4[i] <= isolated_eg_t3[i * 4 + 0] + isolated_eg_t3[i * 4 + 1] + isolated_eg_t3[i * 4 + 2] + isolated_eg_t3[i * 4 + 3];
          end
        isolated_mg_t5 <= isolated_mg_t4[0] + isolated_mg_t4[1] + isolated_mg_t4[2] + isolated_mg_t4[3];
        isolated_eg_t5 <= isolated_eg_t4[0] + isolated_eg_t4[1] + isolated_eg_t4[2] + isolated_eg_t4[3];
     end // always @ (posedge clk)

   always @(posedge clk)
     begin
	eval_valid_t1 <= eval_valid_t0;
	eval_valid_t2 <= eval_valid_t1;
	eval_valid_t3 <= eval_valid_t2;
	eval_valid_t4 <= eval_valid_t3;
	eval_valid_t5 <= eval_valid_t4;
	eval_valid_t6 <= eval_valid_t5;
	eval_valid_t7 <= eval_valid_t6;
	eval_valid_t8 <= eval_valid_t7;
     end

   initial
     begin
        for (i = 0; i < 8; i = i + 1)
          begin
             row_flip[0][i] = 7 - i;
             row_flip[1][i] = i;
          end

`include "evaluate_pawns.vh"

     end

endmodule

