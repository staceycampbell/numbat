// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

module evaluate_tropism #
  (
   parameter EVAL_WIDTH = 0,
   parameter WHITE = 0
   )
   (
    input                                clk,
    input                                reset,

    input                                board_valid,
    input [3:0]                          castle_mask,
    input [`BOARD_WIDTH - 1:0]           board,
    input                                clear_eval,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg,
    output                               eval_valid
    );

   localparam LATENCY_COUNT = 11;
   
   localparam MY_PAWN = WHITE ? `WHITE_PAWN : `BLACK_PAWN;
   localparam OP_PAWN = WHITE ? `BLACK_PAWN : `WHITE_PAWN;
   localparam CASTLE_SHORT = WHITE ? `CASTLE_WHITE_SHORT : `CASTLE_BLACK_SHORT;
   localparam CASTLE_LONG = WHITE ? `CASTLE_WHITE_LONG : `CASTLE_BLACK_LONG;

   localparam MAX_LUT_INDEX = 15;
   localparam MAX_LUT_INDEX_LOG2 = $clog2(MAX_LUT_INDEX);
   localparam LUT_SUM_LOG2 = MAX_LUT_INDEX_LOG2 + $clog2(64);
   localparam DEFECT_WIDTH = $clog2(MAX_LUT_INDEX) + 8;
   
   localparam LUT_COUNT = (`PIECE_KING + 1) << 3;
   localparam MY_KING = WHITE ? `WHITE_KING : `BLACK_KING;
   localparam ENEMY_KNIT = WHITE ? `BLACK_KNIT : `WHITE_KNIT;
   localparam ENEMY_BISH = WHITE ? `BLACK_BISH : `WHITE_BISH;
   localparam ENEMY_ROOK = WHITE ? `BLACK_ROOK : `WHITE_ROOK;
   localparam ENEMY_QUEN = WHITE ? `BLACK_QUEN : `WHITE_QUEN;

   reg [DEFECT_WIDTH - 1:0]              open_file [0:7];
   reg [DEFECT_WIDTH - 1:0]              half_open_file [0:7];
   reg [DEFECT_WIDTH - 1:0]              pawn_defects [0:7];
   reg [2:0]                             row_flip [0:1][0:7];
   
   reg [63:0]                            board_neutral_t1;
   reg [63:0]                            enemy_neutral_t1;
   reg [7:0]                             col_with_pawn_t1;

   reg signed [EVAL_WIDTH - 1:0]         king_safety[0:255];
   reg [3:0]                             tropism_lut [0:LUT_COUNT - 1];
   reg [2:0]                             my_king_row_t1, my_king_col_t1;
   reg [2:0]                             row_dist_t2 [0:7];
   reg [2:0]                             col_dist_t2 [0:7];
   reg [2:0]                             distance_t3 [0:63];
   reg [$clog2(LUT_COUNT) - 1:0]         lut_index_t4 [0:63];
   reg [MAX_LUT_INDEX_LOG2 - 1:0]        ksi_t5 [0:63];
   reg [LUT_SUM_LOG2 - 1:0]              ksi_t6 [0:15];
   reg [LUT_SUM_LOG2 - 1:0]              ksi_t7 [0:3];
   reg [LUT_SUM_LOG2 - 1:0]              ksi_t8;

   reg [DEFECT_WIDTH - 1:0]              defects_q_t6;
   reg [DEFECT_WIDTH - 1:0]              defects_m_t6;
   reg [DEFECT_WIDTH - 1:0]              defects_k_t6;
   reg [DEFECT_WIDTH - 1:0]              defects_t7;
   reg 					 castle_min3_t7;
   reg [3:0]                             defect_index_t8;
   reg [7:0]                             ksi_final_t9;
   
   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   integer                               row, col, i, j;
   
   genvar 				 col_g;

   wire [DEFECT_WIDTH - 1:0]             file_defects_t5 [0:7];
   
   wire [7:0]                            ksi_final_t8 = (defect_index_t8 << 4) | (ksi_t8 < 16 ? ksi_t8[3:0] : 15);
   
   function [4:0] abs_dist (input signed [4:0] x);
      begin
         abs_dist = x < 0 ? -x : x;
      end
   endfunction
   
   function [2:0] max_dist (input [2:0] a, input [2:0] b);
      begin
         max_dist = a > b ? a : b;
      end
   endfunction

   function enemy_tropism_piece (input [`PIECE_WIDTH - 1:0] p);
      begin
         enemy_tropism_piece = p == ENEMY_KNIT || p == ENEMY_BISH || p == ENEMY_ROOK || p == ENEMY_QUEN;
      end
   endfunction // enemy_tropism_piece

   wire [DEFECT_WIDTH - 1:0] min_q_m_t6 = defects_q_t6 < defects_m_t6 ? defects_q_t6 : defects_m_t6;
   wire [DEFECT_WIDTH - 1:0] min_k_m_t6 = defects_k_t6 < defects_m_t6 ? defects_k_t6 : defects_m_t6;
   wire [DEFECT_WIDTH - 1:0] min_q_m_k_t6 = min_q_m_t6 < min_k_m_t6 ? min_q_m_t6 : min_k_m_t6;

   always @(posedge clk)
     begin
	defects_q_t6 <= file_defects_t5[0] + file_defects_t5[1] + file_defects_t5[2];
	defects_m_t6 <= file_defects_t5[2] + file_defects_t5[3] + file_defects_t5[4] + file_defects_t5[5];
	defects_k_t6 <= file_defects_t5[6] + file_defects_t5[7];

	defects_t7 <= 0;
	castle_min3_t7 <= 0;
	if (castle_mask[CASTLE_SHORT] == 1'b0 && castle_mask[CASTLE_LONG] == 1'b0)
	  begin
	     if (my_king_col_t1 > 4)
	       defects_t7 <= defects_k_t6;
	     else if (my_king_col_t1 < 3)
	       defects_t7 <= defects_q_t6;
	     else
	       defects_t7 <= defects_m_t6;
	  end
	else
	  begin
	     if (castle_mask[CASTLE_SHORT] == 1'b1 && castle_mask[CASTLE_LONG] == 1'b1)
	       defects_t7 <= min_q_m_k_t6;
	     else if (castle_mask[CASTLE_SHORT] == 1'b1)
	       defects_t7 <= min_k_m_t6;
	     else
	       defects_t7 <= min_k_m_t6;
	     castle_min3_t7 <= 1;
	  end
	
	if (defects_t7 > 15)
	  defect_index_t8 <= 15;
	else
	  if (castle_min3_t7 && defects_t7 < 3)
	    defect_index_t8 <= 3;
	  else
	    defect_index_t8 <= defects_t7;
     end

   always @(posedge clk)
     begin
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            if (board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_KING)
              begin
                 my_king_row_t1 <= row;
                 my_king_col_t1 <= col;
              end
        for (row = 0; row < 8; row = row + 1)
          row_dist_t2[row] <= abs_dist(my_king_row_t1 - row);
        for (col = 0; col < 8; col = col + 1)
          col_dist_t2[col] <= abs_dist(my_king_col_t1 - col);
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            distance_t3[row << 3 | col] <= max_dist(row_dist_t2[row], col_dist_t2[col]);
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            begin
               lut_index_t4[row << 3 | col] <= board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH - 1] << 3 | distance_t3[row << 3 | col];
               if (enemy_tropism_piece(board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH]))
                 ksi_t5[row << 3 | col] <= tropism_lut[lut_index_t4[row << 3 | col]];
               else
                 ksi_t5[row << 3 | col] <= 0;
            end
        for (i = 0; i < 16; i = i + 1)
          ksi_t6[i] <= ksi_t5[i * 4 + 0] + ksi_t5[i * 4 + 1] + ksi_t5[i * 4 + 2] + ksi_t5[i * 4 + 3];
        for (i = 0; i < 4; i = i + 1)
          ksi_t7[i] <= ksi_t6[i * 4 + 0] + ksi_t6[i * 4 + 1] + ksi_t6[i * 4 + 2] + ksi_t6[i * 4 + 3];
        ksi_t8 <= ksi_t7[0] + ksi_t7[1] + ksi_t7[2] + ksi_t7[3];
        ksi_final_t9 <= (defect_index_t8 << 4) | (ksi_t8 < 16 ? ksi_t8[3:0] : 15);
        if (WHITE)
          eval_mg <= king_safety[ksi_final_t9];
        else
          eval_mg <= -king_safety[ksi_final_t9];
     end
   
   always @(posedge clk)
     for (row = 0; row < 8; row = row + 1)
       for (col = 0; col < 8; col = col + 1)
         if (row != 0 && row != 7)
           begin
              board_neutral_t1[(row_flip[WHITE][row] << 3) | col] <= board[(row << 3 | col)  * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_PAWN;
              enemy_neutral_t1[(row_flip[WHITE][row] << 3) | col] <= board[(row << 3 | col)  * `PIECE_WIDTH+:`PIECE_WIDTH] == OP_PAWN;
           end
         else
           begin
              board_neutral_t1[row << 3 | col] <= 0; // keep x's out of sim, tossed by optimizer
              enemy_neutral_t1[row << 3 | col] <= 0; // keep x's out of sim, tossed by optimizer
           end

   generate
      for (col_g = 0; col_g < 8; col_g = col_g + 1)
	begin : file_defect_blk
	   reg [7:0] pawn_on_file_t2;
	   reg [7:0] my_pawn_on_file_t2;
	   reg [7:0] enemy_pawn_on_file_t2;
	   reg [2:0] most_advanced_enemy_t2;
	   reg 	     my_pawn_row1_t2;
	   reg 	     my_pawn_row2_t2;
	   reg [DEFECT_WIDTH - 1:0] defect_open_file_t3;
	   reg [DEFECT_WIDTH - 1:0] defect_half_open_file_t3;
	   reg [DEFECT_WIDTH - 1:0] defect_enemy_half_open_file_t3;
	   reg [DEFECT_WIDTH - 1:0] defect_my_half_open_file_t3;
	   reg [DEFECT_WIDTH - 1:0] defect_row1_bonus_t3;
	   reg [DEFECT_WIDTH - 1:0] defect_row2_bonus_t3;
	   reg [DEFECT_WIDTH - 1:0] file_defect_a_t4, file_defect_b_t4;
	   reg [DEFECT_WIDTH - 1:0] file_defect_t5;
	   
	   integer 		    ri;

	   assign file_defects_t5[col_g] = file_defect_t5;

	   always @(posedge clk)
	     begin
		most_advanced_enemy_t2 <= 0;
		for (ri = 7; ri >= 0; ri = ri - 1)
		  begin
		     if (board_neutral_t1[ri << 3 | col_g] || enemy_neutral_t1[ri << 3 | col_g])
		       pawn_on_file_t2[ri] <= 1'b1;
		     else
		       pawn_on_file_t2[ri] <= 1'b0;
		     if (enemy_neutral_t1[ri << 3 | col_g])
		       begin
			  enemy_pawn_on_file_t2[ri] <= 1'b1;
			  most_advanced_enemy_t2 <= ri;
		       end
		     else
		       enemy_pawn_on_file_t2[ri] <= 1'b0;
		     my_pawn_on_file_t2[ri] <= board_neutral_t1[ri << 3 | col_g];
		  end
		my_pawn_row1_t2 <= board_neutral_t1[1 << 3 | col_g];
		my_pawn_row2_t2 <= board_neutral_t1[2 << 3 | col_g];

		defect_open_file_t3 <= 0;
		defect_half_open_file_t3 <= 0;
		defect_enemy_half_open_file_t3 <= 0;
		defect_my_half_open_file_t3 <= 0;
		defect_row1_bonus_t3 <= 0;
		defect_row2_bonus_t3 <= 0;
		if (pawn_on_file_t2 == 0) // open file
		  defect_open_file_t3 <= open_file[col_g];
		else
		  begin
		     if (enemy_pawn_on_file_t2 == 0) // no enemies on file
		       defect_enemy_half_open_file_t3 <= half_open_file[col_g] / 2;
		     else
		       defect_enemy_half_open_file_t3 <= pawn_defects[most_advanced_enemy_t2]; // closest enemy
		     if (my_pawn_on_file_t2 == 0) // only enemy pawns on file
		       defect_my_half_open_file_t3 <= half_open_file[col_g];
		     else if (! my_pawn_row1_t2) // pawn on rank 1 of file is gone
		       begin
			  defect_row1_bonus_t3 <= 1;
			  if (! my_pawn_row2_t2) // pawn on rank 2 of file is gone
			    defect_row2_bonus_t3 <= 1;
		       end
		  end
		file_defect_a_t4 <= defect_open_file_t3 + defect_half_open_file_t3 + defect_enemy_half_open_file_t3;
		file_defect_b_t4 <= defect_my_half_open_file_t3 + defect_row1_bonus_t3 + defect_row2_bonus_t3;
		file_defect_t5 <= file_defect_a_t4 + file_defect_b_t4;
	     end
	end
   endgenerate

   initial
     begin
        for (i = 0; i < LUT_COUNT; i = i + 1)
          tropism_lut[i] = 0;
        for (i = 0; i < 8; i = i + 1)
          begin
             row_flip[0][i] = 7 - i;
             row_flip[1][i] = i;
          end
        
`include "evaluate_tropism.vh"
        
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
