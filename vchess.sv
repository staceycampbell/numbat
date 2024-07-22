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
    input                     white_to_move
    );


   // should be empty
   /*AUTOREGINPUT*/
   
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 attacked_black_display_done;// From display_is_attacked_black of display_is_attacked.v
   // End of automatics
   
   wire [63:0]                attacked_white, attacked_black;
   wire [63:0]                attacked_white_valid, attacked_black_valid;

   genvar                     row, col;

   /* display_board AUTO_TEMPLATE (
    .display (attacked_black_display_done),
    );*/
   display_board #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH)
      )
   display_board
     (/*AUTOINST*/
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (board[BOARD_WIDTH-1:0]),
      .display                          (attacked_black_display_done)); // Templated

//   /* display_is_attacked AUTO_TEMPLATE (
//    .attacked (attacked_white[]),
//    .attacked_valid (attacked_white_valid != 0),
//    .display_done (attacked_white_display_done),
//    );*/
//   display_is_attacked display_is_attacked_white
//     (/*AUTOINST*/
//      // Outputs
//      .display_done                     (attacked_white_display_done),
//      // Inputs
//      .clk                              (clk),
//      .reset                            (reset),
//      .attacked                         (attacked_white[63:0]),
//      .attacked_valid                   (attacked_white_valid != 0));

   /* display_is_attacked AUTO_TEMPLATE (
    .attacked (attacked_black[]),
    .attacked_valid (attacked_black_valid != 0),
    .display_done (attacked_black_display_done),
    );*/
   display_is_attacked display_is_attacked_black
     (/*AUTOINST*/
      // Outputs
      .display_done                     (attacked_black_display_done), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .attacked                         (attacked_black[63:0]),  // Templated
      .attacked_valid                   (attacked_black_valid != 0)); // Templated

   generate
      for (row = 0; row < 8; row = row + 1)
        begin : row_attacked_blk
           for (col = 0; col < 8; col = col + 1)
             begin : col_attacked_block

                /* is_attacked AUTO_TEMPLATE (
                 .attacked (attacked_white[row << 3 | col]),
                 .attacked_valid (attacked_white_valid[row << 3 | col]),
                 );*/
                is_attacked #
                      (
                       .PIECE_WIDTH (PIECE_WIDTH),
                       .SIDE_WIDTH (SIDE_WIDTH),
                       .BOARD_WIDTH (BOARD_WIDTH),
                       .ATTACKER (`WHITE_ATTACK),
                       .ROW (row),
                       .COL (col)
                       )
                is_attacked_white
                      (/*AUTOINST*/
                       // Outputs
                       .attacked        (attacked_white[row << 3 | col]), // Templated
                       .attacked_valid  (attacked_white_valid[row << 3 | col]), // Templated
                       // Inputs
                       .clk             (clk),
                       .reset           (reset),
                       .board           (board[BOARD_WIDTH-1:0]),
                       .board_valid     (board_valid));
                
                /* is_attacked AUTO_TEMPLATE (
                 .attacked (attacked_black[row << 3 | col]),
                 .attacked_valid (attacked_black_valid[row << 3 | col]),
                 );*/
                is_attacked #
                  (
                   .PIECE_WIDTH (PIECE_WIDTH),
                   .SIDE_WIDTH (SIDE_WIDTH),
                   .BOARD_WIDTH (BOARD_WIDTH),
                   .ATTACKER (`BLACK_ATTACK),
                   .ROW (row),
                   .COL (col)
                   )
                is_attacked_black
                  (/*AUTOINST*/
                   // Outputs
                   .attacked            (attacked_black[row << 3 | col]), // Templated
                   .attacked_valid      (attacked_black_valid[row << 3 | col]), // Templated
                   // Inputs
                   .clk                 (clk),
                   .reset               (reset),
                   .board               (board[BOARD_WIDTH-1:0]),
                   .board_valid         (board_valid));
             end
        end
   endgenerate

endmodule // vchess

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

