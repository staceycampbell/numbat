`include "vchess.vh"

module board_attack #
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

    output [63:0]             attacking_white,
    output [63:0]             attacking_black,
    output                    is_attacking_done,
    output                    display_attacking_done
    );

   // should be empty
   /*AUTOREGINPUT*/
   
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 attacking_black_display_done;// From display_is_attacking_black of display_is_attacking.v
   wire                 attacking_white_display_done;// From display_is_attacking_white of display_is_attacking.v
   // End of automatics
   
   wire [63:0]                attacking_white_valid, attacking_black_valid;

   genvar                     row, col;

   assign is_attacking_done = attacking_white_valid != 0;
   assign display_attacking_done = attacking_black_display_done;

   generate
      for (row = 0; row < 8; row = row + 1)
        begin : row_attacking_blk
           for (col = 0; col < 8; col = col + 1)
             begin : col_attacking_block

                /* is_attacking AUTO_TEMPLATE (
                 .attacking (attacking_white[row << 3 | col]),
                 .attacking_valid (attacking_white_valid[row << 3 | col]),
                 );*/
                is_attacking #
                      (
                       .PIECE_WIDTH (PIECE_WIDTH),
                       .SIDE_WIDTH (SIDE_WIDTH),
                       .BOARD_WIDTH (BOARD_WIDTH),
                       .ATTACKER (`WHITE_ATTACK),
                       .ROW (row),
                       .COL (col)
                       )
                is_attacking_white
                      (/*AUTOINST*/
                       // Outputs
                       .attacking       (attacking_white[row << 3 | col]), // Templated
                       .attacking_valid (attacking_white_valid[row << 3 | col]), // Templated
                       // Inputs
                       .clk             (clk),
                       .reset           (reset),
                       .board           (board[BOARD_WIDTH-1:0]),
                       .board_valid     (board_valid));
                
                /* is_attacking AUTO_TEMPLATE (
                 .attacking (attacking_black[row << 3 | col]),
                 .attacking_valid (attacking_black_valid[row << 3 | col]),
                 );*/
                is_attacking #
                  (
                   .PIECE_WIDTH (PIECE_WIDTH),
                   .SIDE_WIDTH (SIDE_WIDTH),
                   .BOARD_WIDTH (BOARD_WIDTH),
                   .ATTACKER (`BLACK_ATTACK),
                   .ROW (row),
                   .COL (col)
                   )
                is_attacking_black
                  (/*AUTOINST*/
                   // Outputs
                   .attacking           (attacking_black[row << 3 | col]), // Templated
                   .attacking_valid     (attacking_black_valid[row << 3 | col]), // Templated
                   // Inputs
                   .clk                 (clk),
                   .reset               (reset),
                   .board               (board[BOARD_WIDTH-1:0]),
                   .board_valid         (board_valid));
             end
        end
      
   endgenerate
   
   /* display_is_attacking AUTO_TEMPLATE (
    .attacking (attacking_white[]),
    .attacking_valid (attacking_white_valid != 0),
    .display_done (attacking_white_display_done),
    );*/
   display_is_attacking #
     (
      .COLOR_ATTACKS ("White")
      )
   display_is_attacking_white
     (/*AUTOINST*/
      // Outputs
      .display_done                     (attacking_white_display_done), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .attacking                        (attacking_white[63:0]), // Templated
      .attacking_valid                  (attacking_white_valid != 0)); // Templated

   /* display_is_attacking AUTO_TEMPLATE (
    .attacking (attacking_black[]),
    .attacking_valid (attacking_white_display_done),
    .display_done (attacking_black_display_done),
    );*/
   display_is_attacking #
     (
      .COLOR_ATTACKS ("Black")
      )
   display_is_attacking_black
     (/*AUTOINST*/
      // Outputs
      .display_done                     (attacking_black_display_done), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .attacking                        (attacking_black[63:0]), // Templated
      .attacking_valid                  (attacking_white_display_done)); // Templated

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

