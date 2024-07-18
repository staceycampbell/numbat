module display_board #
  (
   parameter PIECE_WIDTH = 0,
   parameter ROW_WIDTH = 0,
   parameter BOARD_WIDTH = 0
   )
   (
    input                     reset,
    input                     clk,

    input [BOARD_WIDTH - 1:0] board,
    input                     display
    );

   reg [7:0]                  piece_char [0:(1 << PIECE_WIDTH) - 1];
   reg [$clog2(BOARD_WIDTH) - 1:0] index, row_start;
   reg [2:0]                       col;

   initial
     begin
        piece_char[0] = ".";
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
     end // initial begin

   localparam STATE_INIT = 0;
   localparam STATE_ROW = 1;

   reg [1:0] state = STATE_INIT;

   always @(posedge clk)
     if (reset)
       state <= STATE_INIT;
     else
       case (state)
         STATE_INIT :
           begin
              row_start <= ROW_WIDTH * 7;
              index <= ROW_WIDTH * 7;
              col <= 0;
              if (display)
                state <= STATE_ROW;
           end
         STATE_ROW :
           begin
              $write("%c", piece_char[board[index+:PIECE_WIDTH]]);
              index <= index + PIECE_WIDTH;
              if (col == 7)
                begin
                   col <= 0;
                   row_start <= row_start - ROW_WIDTH;
                   index <= row_start - ROW_WIDTH;
                   $write("\n");
                end
              else
                col <= col + 1;
              if (index == ROW_WIDTH - PIECE_WIDTH)
                state <= STATE_INIT;
           end
       endcase

endmodule
