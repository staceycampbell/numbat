`include "vchess.vh"

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
    input                                clear_eval,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg,
    output                               eval_valid
    );

   localparam LATENCY_COUNT = 4;

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
   reg signed [EVAL_WIDTH - 1:0]         castle_eval_t1;
   reg signed [EVAL_WIDTH - 1:0]         castle_eval_t2;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   integer                               i;

   always @(posedge clk)
     begin
        enemy_queen_t1 <= 1;
        for (i = 0; i < 64; i = i + 1)
          if (board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == OPPOSITION_QUEEN)
            enemy_queen_t1 <= 3;
        castle_eval_t1 <= 0; // castle by default
        if (castle_mask_orig[CASTLE_SHORT] == 1'b1 && castle_mask[CASTLE_SHORT] == 1'b0)
          begin
             if (board[KING_SHORT * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_KING)
               castle_eval_t1 <= -10; // lost castling via rook move
             else if (board[ROOK_SHORT * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_ROOK)
               castle_eval_t1 <= -20; // lost castling via king move
          end
        else if (castle_mask_orig[CASTLE_LONG] == 1'b1 && castle_mask[CASTLE_LONG] == 1'b0)
          begin
             if (board[KING_LONG * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_KING)
               castle_eval_t1 <= -10; // lost castling via rook move
             else if (board[ROOK_LONG * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_ROOK)
               castle_eval_t1 <= -20; // lost castling via king move
          end
        castle_eval_t2 <= castle_eval_t1 * enemy_queen_t1;
        if (WHITE_CASTLING)
          eval_mg <= castle_eval_t2;
        else
          eval_mg <= -castle_eval_t2;
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
