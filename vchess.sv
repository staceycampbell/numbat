`include "vchess.vh"

module vchess #
  (
   parameter PIECE_WIDTH = 0,
   parameter SIDE_WIDTH = 0,
   parameter BOARD_WIDTH = 0
   )
   (
    input                     reset,
    input                     clk,
   
    input [BOARD_WIDTH - 1:0] board,
    input                     board_valid,
    input                     white_to_move,

    output [63:0]             attacking_white,
    output [63:0]             attacking_black,
    output                    is_attacking_done,
    output                    display_attacking_done
    );

   // should be empty
   /*AUTOREGINPUT*/
   
   /*AUTOWIRE*/

   /* board_attack AUTO_TEMPLATE (
    );*/
   board_attack #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH)
      )
   board_attack
     (/*AUTOINST*/
      // Outputs
      .attacking_white                  (attacking_white[63:0]),
      .attacking_black                  (attacking_black[63:0]),
      .is_attacking_done                (is_attacking_done),
      .display_attacking_done           (display_attacking_done),
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (board[BOARD_WIDTH-1:0]),
      .board_valid                      (board_valid));

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

