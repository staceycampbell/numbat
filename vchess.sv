module vchess #
  (
   parameter PIECE_WIDTH = 0,
   parameter ROW_WIDTH = 0,
   parameter BOARD_WIDTH = 0
   )
   (
    input                     reset,
    input                     clk,

    input [BOARD_WIDTH - 1:0] board,
    input                     board_valid,
    input                     white_to_move
    );

   // should be empty
   /*AUTOREGINPUT*/
   
   /*AUTOWIRE*/

   /* display_board AUTO_TEMPLATE (
    .display (board_valid),
    );*/
   display_board #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .ROW_WIDTH (ROW_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH)
      )
   display_board
     (/*AUTOINST*/
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (board[BOARD_WIDTH-1:0]),
      .display                          (board_valid));           // Templated

endmodule // vchess

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

