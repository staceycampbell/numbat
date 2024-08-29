`include "vchess.vh"

module evaluate #
  (
   parameter PIECE_WIDTH = `PIECE_BITS,
   parameter SIDE_WIDTH = PIECE_WIDTH * 8,
   parameter BOARD_WIDTH = SIDE_WIDTH * 8,
   parameter EVAL_WIDTH = 22
   )
   (
    input                            clk,
    input                            reset,

    input                            board_valid,
    input [BOARD_WIDTH - 1:0]        board_in,
    input                            white_to_move_in,
    input [3:0]                      castle_mask_in,
    input [3:0]                      en_passant_col_in,

    output signed [EVAL_WIDTH - 1:0] eval,
    output                           eval_valid
    );
   
   localparam VALUE_PAWN =   100;
   localparam VALUE_KNIT =   310;
   localparam VALUE_BISH =   320;
   localparam VALUE_ROOK =   500;
   localparam VALUE_QUEN =   900;
   localparam VALUE_KING = 10000;

   reg signed [$clog2(VALUE_KING) - 1 + 1:0] value [0:`PIECE_KING];

   initial
     begin
        value[`EMPTY_POSN] = 0;
        value[`PIECE_PAWN] = VALUE_PAWN;
        value[`PIECE_KNIT] = VALUE_KNIT;
        value[`PIECE_BISH] = VALUE_BISH;
        value[`PIECE_ROOK] = VALUE_ROOK;
        value[`PIECE_QUEN] = VALUE_QUEN;
        value[`PIECE_KING] = VALUE_KING;
     end

endmodule
