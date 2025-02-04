// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

module evaluate_castling #
  (
   parameter EVAL_WIDTH = 0,
   parameter WHITE_CASTLING = 0
   )
   (
    input                                clk,
    input                                reset,
    input                                board_valid,
    input [`BOARD_WIDTH - 1:0]           board,
    input [3:0]                          castle_mask,
    input [3:0]                          castle_mask_orig,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg_t5,
    output reg                           eval_valid_t5
    );

   localparam LATENCY_COUNT = 6;

   localparam OPPOSITION_QUEEN = WHITE_CASTLING ? `BLACK_QUEN : `WHITE_QUEN;
   localparam MY_KING = WHITE_CASTLING ? `WHITE_KING : `BLACK_KING;
   localparam MY_ROOK = WHITE_CASTLING ? `WHITE_ROOK : `BLACK_ROOK;
   localparam CASTLE_SHORT = WHITE_CASTLING ? `CASTLE_WHITE_SHORT : `CASTLE_BLACK_SHORT;
   localparam CASTLE_LONG = WHITE_CASTLING ? `CASTLE_WHITE_LONG : `CASTLE_BLACK_LONG;
   localparam KING_SHORT = WHITE_CASTLING ? 0 << 3 | 6 : 7 << 3 | 6;
   localparam KING_LONG = WHITE_CASTLING ? 0 << 3 | 2 : 7 << 3 | 2;
   localparam ROOK_SHORT = WHITE_CASTLING ? 0 << 3 | 7 : 7 << 3 | 7;
   localparam ROOK_LONG = WHITE_CASTLING ? 0 << 3 | 0 : 7 << 3 | 0;

   reg signed [EVAL_WIDTH - 1:0]         enemy_queen_t1;
   reg signed [EVAL_WIDTH - 1:0]         enemy_queen_t2;
   reg signed [EVAL_WIDTH - 1:0]         castle_eval_t1;
   reg signed [EVAL_WIDTH - 1:0]         castle_eval_t2;
   reg signed [EVAL_WIDTH - 1:0]         castle_eval_t3;
   reg signed [EVAL_WIDTH - 1:0]         castle_eval_t4;
   
   reg                                   eval_valid_t1, eval_valid_t2, eval_valid_t3, eval_valid_t4;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   integer                               i;

   wire [`BOARD_WIDTH - 1:0]             board_t0 = board;
   wire                                  eval_valid_t0 = board_valid;
   wire [3:0]                            castle_mask_t0 = castle_mask;
   wire [3:0]                            castle_mask_orig_t0 = castle_mask_orig;

   always @(posedge clk)
     begin
        enemy_queen_t1 <= 1;
        for (i = 0; i < 64; i = i + 1)
          if (board_t0[i * `PIECE_WIDTH+:`PIECE_WIDTH] == OPPOSITION_QUEEN)
            enemy_queen_t1 <= 3;
        castle_eval_t1 <= 0; // castle by default
        if (castle_mask_orig_t0[CASTLE_SHORT] == 1'b1 && castle_mask_t0[CASTLE_SHORT] == 1'b0)
          begin
             if (board_t0[KING_SHORT * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_KING)
               castle_eval_t1 <= -10; // lost castling via rook move
             else if (board_t0[ROOK_SHORT * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_ROOK)
               castle_eval_t1 <= -20; // lost castling via king move
          end
        else if (castle_mask_orig_t0[CASTLE_LONG] == 1'b1 && castle_mask_t0[CASTLE_LONG] == 1'b0)
          begin
             if (board_t0[KING_LONG * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_KING)
               castle_eval_t1 <= -10; // lost castling via rook move
             else if (board_t0[ROOK_LONG * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_ROOK)
               castle_eval_t1 <= -20; // lost castling via king move
          end
        castle_eval_t2 <= castle_eval_t1;
        enemy_queen_t2 <= enemy_queen_t1;
        castle_eval_t3 <= castle_eval_t2 * enemy_queen_t2;
        castle_eval_t4 <= castle_eval_t3;
        if (WHITE_CASTLING)
          eval_mg_t5 <= castle_eval_t4;
        else
          eval_mg_t5 <= -castle_eval_t4;
     end

   always @(posedge clk)
     begin
	eval_valid_t1 <= eval_valid_t0;
	eval_valid_t2 <= eval_valid_t1;
	eval_valid_t3 <= eval_valid_t2;
	eval_valid_t4 <= eval_valid_t3;
	eval_valid_t5 <= eval_valid_t4;
     end

endmodule
