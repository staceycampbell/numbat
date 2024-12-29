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
    input 			     clk,
    input 			     reset,

    input 			     board_valid,
    input [`BOARD_WIDTH - 1:0] 	     board,
    input 			     clear_eval,
    input [63:0] 		     white_is_attacking,
    input [63:0] 		     black_is_attacking,

    output signed [EVAL_WIDTH - 1:0] eval_mg,
    output signed [EVAL_WIDTH - 1:0] eval_eg,
    output 			     eval_valid
    );

   localparam LATENCY_COUNT = 7;

   localparam MY_PAWN = WHITE_PAWNS ? `WHITE_PAWN : `BLACK_PAWN;
   localparam OP_PAWN = WHITE_PAWNS ? `BLACK_PAWN : `WHITE_PAWN;

   reg signed [EVAL_WIDTH - 1:0]     pawns_isolated_mg [0:7];
   reg signed [EVAL_WIDTH - 1:0]     pawns_isolated_eg [0:7];
   reg signed [EVAL_WIDTH - 1:0]     pawns_doubled_mg [0:7][1:5];
   reg signed [EVAL_WIDTH - 1:0]     pawns_doubled_eg [0:7][1:5];
   reg signed [EVAL_WIDTH - 1:0]     pawns_connected_mg [0:7][0:7];
   reg signed [EVAL_WIDTH - 1:0]     pawns_connected_eg [0:7][0:7];
   reg signed [EVAL_WIDTH - 1:0]     pawns_backward_mg [0:7];
   reg signed [EVAL_WIDTH - 1:0]     pawns_backward_eg [0:7];
   reg signed [EVAL_WIDTH - 1:0]     passed_pawn [0:7];
   reg [63:0] 			     not_passed_mask [0:63];
   reg [63:0] 			     passed_pawn_path [0:63];
   reg signed [EVAL_WIDTH - 1:0]     passed_pawn_base_mg;
   reg signed [EVAL_WIDTH - 1:0]     passed_pawn_base_eg;
   reg signed [EVAL_WIDTH - 1:0]     passed_pawn_free_advance;
   reg signed [EVAL_WIDTH - 1:0]     passed_pawn_defended;

   reg [63:0] 			     board_neutral_t1;
   reg [63:0] 			     enemy_neutral_t2;
   reg [7:0] 			     col_with_pawn_t1;

   reg signed [EVAL_WIDTH - 1:0]     isolated_mg_t2 [0:63];
   reg signed [EVAL_WIDTH - 1:0]     isolated_eg_t2 [0:63];
   reg signed [EVAL_WIDTH - 1:0]     isolated_mg_t3 [0:15];
   reg signed [EVAL_WIDTH - 1:0]     isolated_eg_t3 [0:15];
   reg signed [EVAL_WIDTH - 1:0]     isolated_mg_t4 [0:3];
   reg signed [EVAL_WIDTH - 1:0]     isolated_eg_t4 [0:3];
   reg signed [EVAL_WIDTH - 1:0]     isolated_mg_t5;
   reg signed [EVAL_WIDTH - 1:0]     isolated_eg_t5;

   reg [3:0] 			     doubled_distance_t2 [0:63];
   reg signed [EVAL_WIDTH - 1:0]     doubled_mg_t3 [0:63];
   reg signed [EVAL_WIDTH - 1:0]     doubled_eg_t3 [0:63];
   reg signed [EVAL_WIDTH - 1:0]     doubled_mg_t4 [0:7];
   reg signed [EVAL_WIDTH - 1:0]     doubled_eg_t4 [0:7];
   reg signed [EVAL_WIDTH - 1:0]     doubled_mg_t5 [0:1];
   reg signed [EVAL_WIDTH - 1:0]     doubled_eg_t5 [0:1];
   reg signed [EVAL_WIDTH - 1:0]     doubled_mg_t6;
   reg signed [EVAL_WIDTH - 1:0]     doubled_eg_t6;

   reg [63:0] 			     connected_t2;
   reg signed [EVAL_WIDTH - 1:0]     connected_mg_t3 [0:63];
   reg signed [EVAL_WIDTH - 1:0]     connected_eg_t3 [0:63];
   reg signed [EVAL_WIDTH - 1:0]     connected_mg_t4 [0:15];
   reg signed [EVAL_WIDTH - 1:0]     connected_eg_t4 [0:15];
   reg signed [EVAL_WIDTH - 1:0]     connected_mg_t5 [0:3];
   reg signed [EVAL_WIDTH - 1:0]     connected_eg_t5 [0:3];
   reg signed [EVAL_WIDTH - 1:0]     connected_mg_t6;
   reg signed [EVAL_WIDTH - 1:0]     connected_eg_t6;

   reg [63:0] 			     backward_t2;
   reg signed [EVAL_WIDTH - 1:0]     backward_mg_t3 [0:63];
   reg signed [EVAL_WIDTH - 1:0]     backward_eg_t3 [0:63];
   reg signed [EVAL_WIDTH - 1:0]     backward_mg_t4 [0:15];
   reg signed [EVAL_WIDTH - 1:0]     backward_eg_t4 [0:15];
   reg signed [EVAL_WIDTH - 1:0]     backward_mg_t5 [0:3];
   reg signed [EVAL_WIDTH - 1:0]     backward_eg_t5 [0:3];
   reg signed [EVAL_WIDTH - 1:0]     backward_mg_t6;
   reg signed [EVAL_WIDTH - 1:0]     backward_eg_t6;

   reg [2:0] 			     most_adv_row_t2 [0:7];
   reg [7:0] 			     passed_pawn_t3;
   reg signed [EVAL_WIDTH - 1:0]     bonus_t3 [0:7];
   reg signed [EVAL_WIDTH - 1:0]     score_mult_t3 [0:7];
   reg signed [EVAL_WIDTH - 1:0]     passed_mg_t4 [0:7];
   reg signed [EVAL_WIDTH - 1:0]     passed_eg_t4 [0:7];
   reg signed [EVAL_WIDTH - 1:0]     passed_mg_t5 [0:1];
   reg signed [EVAL_WIDTH - 1:0]     passed_eg_t5 [0:1];
   reg signed [EVAL_WIDTH - 1:0]     passed_mg_t6;
   reg signed [EVAL_WIDTH - 1:0]     passed_eg_t6;

   reg signed [EVAL_WIDTH - 1:0]     eval_mg_t7;
   reg signed [EVAL_WIDTH - 1:0]     eval_eg_t7;

   reg [2:0] 			     row_flip [0:1][0:7];
   reg [63:0] 			     enemy_is_attacking;
   reg [63:0] 			     square_is_defended;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   integer                           i, row, col, row_adv;

   assign eval_mg = WHITE_PAWNS ? eval_mg_t7 : -eval_mg_t7;
   assign eval_eg = WHITE_PAWNS ? eval_eg_t7 : -eval_eg_t7;

   always @(posedge clk)
     begin
        col_with_pawn_t1 <= 0;
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            begin
               if (row != 0 && row != 7)
                 begin
                    board_neutral_t1[(row_flip[WHITE_PAWNS][row] << 3) | col] <= board[(row << 3 | col)  * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_PAWN;
                    enemy_neutral_t2[(row_flip[WHITE_PAWNS][row] << 3) | col] <= board[(row << 3 | col)  * `PIECE_WIDTH+:`PIECE_WIDTH] == OP_PAWN;
                    if (board[(row << 3 | col)  * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_PAWN)
                      col_with_pawn_t1[col] <= 1;
		    if (WHITE_PAWNS)
		      begin
			 enemy_is_attacking[(row_flip[WHITE_PAWNS][row] << 3) | col] <= black_is_attacking[row << 3 | col];
			 square_is_defended[(row_flip[WHITE_PAWNS][row] << 3) | col] <= white_is_attacking[row << 3 | col];
		      end
		    else
		      begin
			 enemy_is_attacking[(row_flip[WHITE_PAWNS][row] << 3) | col] <= white_is_attacking[row << 3 | col];
			 square_is_defended[(row_flip[WHITE_PAWNS][row] << 3) | col] <= black_is_attacking[row << 3 | col];
		      end
                 end
               else
                 begin
                    board_neutral_t1[row << 3 | col] <= 1'b0; // keep x's out of sim, tossed by optimizer
                    enemy_neutral_t2[row << 3 | col] <= 1'b0;
		    enemy_is_attacking[row << 3| col] <= 1'b0;
		    square_is_defended[row << 3| col] <= 1'b0;
                 end
            end

        eval_mg_t7 <= isolated_mg_t5 + doubled_mg_t6 + connected_mg_t6 + backward_mg_t6 + passed_mg_t6;
        eval_eg_t7 <= isolated_eg_t5 + doubled_eg_t6 + connected_eg_t6 + backward_eg_t6 + passed_eg_t6;
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
	       if (! enemy_is_attacking[(most_adv_row_t2[col] + 1) << 3 | col])
		 if (square_is_defended[(most_adv_row_t2[col] + 1) << 3 | col])
		   bonus_t3[col] <= passed_pawn_free_advance + passed_pawn_defended;
		 else
		   bonus_t3[col] <= passed_pawn_free_advance;
	       else if (square_is_defended[(most_adv_row_t2[col] + 1) << 3 | col])
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

   /* latency_sm AUTO_TEMPLATE (
    );*/
   latency_sm #
     (
      .LATENCY_COUNT (LATENCY_COUNT)
      )
   latency_sm
     (/*AUTOINST*/
      // Outputs
      .eval_valid			(eval_valid),
      // Inputs
      .clk				(clk),
      .reset				(reset),
      .board_valid			(board_valid),
      .clear_eval			(clear_eval));

endmodule
