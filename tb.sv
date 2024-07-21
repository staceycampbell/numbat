`include "vchess.vh"

module tb;

   localparam PIECE_WIDTH = `PIECE_BITS;
   localparam SIDE_WIDTH = PIECE_WIDTH * 8;
   localparam BOARD_WIDTH = PIECE_WIDTH * 8 * 8;

   reg clk = 0;
   reg reset = 1;
   integer t = 0;
   integer i;

   reg [BOARD_WIDTH - 1:0] board;
   reg                     board_valid = 0;
   reg                     white_to_move = 1;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   initial
     begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);
        for (i = 0; i < 64; i = i + 1)
          board[i * PIECE_WIDTH+:PIECE_WIDTH] = `EMPTY_POSN;
        board[0 * SIDE_WIDTH + 0 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_ROOK;
        board[0 * SIDE_WIDTH + 1 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_KNIT;
        board[0 * SIDE_WIDTH + 2 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_BISH;
        board[0 * SIDE_WIDTH + 3 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_QUEN;
        board[0 * SIDE_WIDTH + 4 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_KING;
        board[0 * SIDE_WIDTH + 5 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_BISH;
        board[0 * SIDE_WIDTH + 6 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_KNIT;
        board[0 * SIDE_WIDTH + 7 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_ROOK;
        for (i = 0; i < 8; i = i + 1)
          if (i != 4)
            board[1 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_PAWN;
          else
            board[3 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_PAWN;
        board[7 * SIDE_WIDTH + 0 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_ROOK;
        board[7 * SIDE_WIDTH + 1 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KNIT;
        board[7 * SIDE_WIDTH + 2 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_BISH;
        board[7 * SIDE_WIDTH + 3 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_QUEN;
        board[7 * SIDE_WIDTH + 4 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KING;
        board[7 * SIDE_WIDTH + 5 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_BISH;
        board[7 * SIDE_WIDTH + 6 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KNIT;
        board[7 * SIDE_WIDTH + 7 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_ROOK;
        for (i = 0; i < 8; i = i + 1)
          board[6 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_PAWN;
        forever
          #1 clk = ~clk;
     end

   always @(posedge clk)
     begin
        t <= t + 1;
        reset <= t < 64;

        board_valid <= t == 72;
        white_to_move <= 1;

        if (t >= 512)
          $finish;
     end

   /* vchess AUTO_TEMPLATE (
    );*/
   vchess #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH)
      )
   vchess
     (/*AUTOINST*/
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (board[BOARD_WIDTH-1:0]),
      .board_valid                      (board_valid),
      .white_to_move                    (white_to_move));

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

