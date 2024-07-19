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
   
   wire [63:0]                attacked_white, attacked_black;
   wire [63:0]                attacked_white_valid, attacked_black_valid;

   genvar                     rank, file;

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

   generate
      for (rank = 0; rank < 8; rank = rank + 1)
        for (file = 0; file < 8; file = file + 1)
          begin : is_attacked_block

             /* is_attacked AUTO_TEMPLATE (
              .attacked (attacked_white[rank << 3 | file]),
              .attacked_valid (attacked_white_valid[rank << 3 | file]),
              );*/
             is_attacked #
                    (
                     .PIECE_WIDTH (PIECE_WIDTH),
                     .ROW_WIDTH (ROW_WIDTH),
                     .BOARD_WIDTH (BOARD_WIDTH),
                     .ATTACKER (`WHITE_ATTACK),
                     .RANK (rank),
                     .FILE (file)
                     )
             is_attacked_white
                    (/*AUTOINST*/
                     // Outputs
                     .attacked          (attacked_white[rank << 3 | file]), // Templated
                     .attacked_valid    (attacked_white_valid[rank << 3 | file]), // Templated
                     // Inputs
                     .clk               (clk),
                     .reset             (reset),
                     .board             (board[BOARD_WIDTH-1:0]),
                     .board_valid       (board_valid));
             
             /* is_attacked AUTO_TEMPLATE (
              .attacked (attacked_black[rank << 3 | file]),
              .attacked_valid (attacked_black_valid[rank << 3 | file]),
              );*/
             is_attacked #
               (
                .PIECE_WIDTH (PIECE_WIDTH),
                .ROW_WIDTH (ROW_WIDTH),
                .BOARD_WIDTH (BOARD_WIDTH),
                .ATTACKER (`BLACK_ATTACK),
                .RANK (rank),
                .FILE (file)
                )
             is_attacked_black
               (/*AUTOINST*/
                // Outputs
                .attacked               (attacked_black[rank << 3 | file]), // Templated
                .attacked_valid         (attacked_black_valid[rank << 3 | file]), // Templated
                // Inputs
                .clk                    (clk),
                .reset                  (reset),
                .board                  (board[BOARD_WIDTH-1:0]),
                .board_valid            (board_valid));
             
          end
   endgenerate

endmodule // vchess

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

