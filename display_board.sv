`include "vchess.vh"

module display_board #
  (
   parameter EVAL_WIDTH = 0
   )
   (
    input                           reset,
    input                           clk,

    input [`BOARD_WIDTH - 1:0]      board,
    input [3:0]                     castle_mask,
    input [3:0]                     en_passant_col,
    input                           capture,
    input                           white_in_check,
    input                           black_in_check,
    input signed [EVAL_WIDTH - 1:0] eval,
    input                           thrice_rep,
    input                           display,

    output reg                      display_done = 0
    );

   reg [7:0]                        piece_char [0:(1 << `PIECE_WIDTH) - 1];
   reg [$clog2(`BOARD_WIDTH) - 1:0] index, row_start;
   reg [2:0]                        col;

   initial
     begin
        piece_char[`EMPTY_POSN] = ".";
        piece_char[`WHITE_PAWN] = "P";
        piece_char[`WHITE_ROOK] = "R";
        piece_char[`WHITE_KNIT] = "N";
        piece_char[`WHITE_BISH] = "B";
        piece_char[`WHITE_KING] = "K";
        piece_char[`WHITE_QUEN] = "Q";
        piece_char[`BLACK_PAWN] = "p";
        piece_char[`BLACK_ROOK] = "r";
        piece_char[`BLACK_KNIT] = "n";
        piece_char[`BLACK_BISH] = "b";
        piece_char[`BLACK_KING] = "k";
        piece_char[`BLACK_QUEN] = "q";
     end

   localparam STATE_INIT = 0;
   localparam STATE_ROW = 1;
   localparam STATE_DONE = 2;

   reg [1:0] state = STATE_INIT;

   always @(posedge clk)
     if (reset)
       state <= STATE_INIT;
     else
       case (state)
         STATE_INIT :
           begin
              row_start <= `SIDE_WIDTH * 7;
              index <= `SIDE_WIDTH * 7;
              col <= 0;
              display_done <= 0;
              if (display)
                state <= STATE_ROW;
           end
         STATE_ROW :
           begin
              $write("%c ", piece_char[board[index+:`PIECE_WIDTH]]);
              index <= index + `PIECE_WIDTH;
              if (col == 7)
                begin
                   col <= 0;
                   row_start <= row_start - `SIDE_WIDTH;
                   index <= row_start - `SIDE_WIDTH;
                   $write("\n");
                end
              else
                col <= col + 1;
              if (index == `SIDE_WIDTH - `PIECE_WIDTH)
                state <= STATE_DONE;
           end
         STATE_DONE :
           begin
              if (white_in_check)
                if (black_in_check)
                  $display("Both in check!");
                else
                  $display("White in check.");
              else
                if (black_in_check)
                  $display("Black in check.");
              $display("castle=%04b en_passant=%04b capture=%1b, eval=%d thrice: %d", castle_mask, en_passant_col, capture, eval, thrice_rep);
              display_done <= 1;
              state <= STATE_INIT;
           end
       endcase

endmodule
