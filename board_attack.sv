`include "vchess.vh"

module board_attack #
  (
   parameter PIECE_WIDTH = 0,
   parameter SIDE_WIDTH = 0,
   parameter BOARD_WIDTH = 0,
   parameter DO_DISPLAY = 0
   )
   (
    input                     reset,
    input                     clk,
   
    input [BOARD_WIDTH - 1:0] board,
    input                     board_valid,

    output [63:0]             white_is_attacking,
    output [63:0]             black_is_attacking,
    output                    white_in_check,
    output                    black_in_check,
    output                    is_attacking_done,
    output                    display_attacking_done
    );

   // should be empty
   /*AUTOREGINPUT*/
   
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                       black_is_attacking_display_done;// From display_is_black_is_attacking of display_is_attacking.v
   wire                       white_is_attacking_display_done;// From display_is_white_is_attacking of display_is_attacking.v
   // End of automatics
   
   wire [63:0]                white_is_attacking_valid, black_is_attacking_valid;
   wire [63:0]                white_in_check_list, black_in_check_list;

   genvar                     row, col;

   assign white_in_check = white_in_check_list != 0;
   assign black_in_check = black_in_check_list != 0;
   assign is_attacking_done = white_is_attacking_valid != 0;
   assign display_attacking_done = black_is_attacking_display_done;

   generate
      for (row = 0; row < 8; row = row + 1)
        begin : row_attacking_blk
           for (col = 0; col < 8; col = col + 1)
             begin : col_attacking_block

                /* is_attacking AUTO_TEMPLATE (
                 .attacking (white_is_attacking[row << 3 | col]),
                 .attacking_valid (white_is_attacking_valid[row << 3 | col]),
                 .opponent_in_check (black_in_check_list[row << 3 | col]),
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
                is_white_is_attacking
                      (/*AUTOINST*/
                       // Outputs
                       .attacking       (white_is_attacking[row << 3 | col]), // Templated
                       .opponent_in_check(black_in_check_list[row << 3 | col]), // Templated
                       .attacking_valid (white_is_attacking_valid[row << 3 | col]), // Templated
                       // Inputs
                       .clk             (clk),
                       .reset           (reset),
                       .board           (board[BOARD_WIDTH-1:0]),
                       .board_valid     (board_valid));
                
                /* is_attacking AUTO_TEMPLATE (
                 .attacking (black_is_attacking[row << 3 | col]),
                 .attacking_valid (black_is_attacking_valid[row << 3 | col]),
                 .opponent_in_check (white_in_check_list[row << 3 | col]),
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
                is_black_is_attacking
                  (/*AUTOINST*/
                   // Outputs
                   .attacking           (black_is_attacking[row << 3 | col]), // Templated
                   .opponent_in_check   (white_in_check_list[row << 3 | col]), // Templated
                   .attacking_valid     (black_is_attacking_valid[row << 3 | col]), // Templated
                   // Inputs
                   .clk                 (clk),
                   .reset               (reset),
                   .board               (board[BOARD_WIDTH-1:0]),
                   .board_valid         (board_valid));
             end
        end
      
   endgenerate

   generate
      if (DO_DISPLAY)
        begin
           
           /* display_is_attacking AUTO_TEMPLATE (
            .attacking (white_is_attacking[]),
            .attacking_valid (white_is_attacking_valid != 0),
            .display_done (white_is_attacking_display_done),
            );*/
           display_is_attacking #
             (
              .COLOR_ATTACKS ("White")
              )
           display_is_white_is_attacking
             (/*AUTOINST*/
              // Outputs
              .display_done             (white_is_attacking_display_done), // Templated
              // Inputs
              .clk                      (clk),
              .reset                    (reset),
              .attacking                (white_is_attacking[63:0]), // Templated
              .attacking_valid          (white_is_attacking_valid != 0)); // Templated

           /* display_is_attacking AUTO_TEMPLATE (
            .attacking (black_is_attacking[]),
            .attacking_valid (white_is_attacking_display_done),
            .display_done (black_is_attacking_display_done),
            );*/
           display_is_attacking #
             (
              .COLOR_ATTACKS ("Black")
              )
           display_is_black_is_attacking
             (/*AUTOINST*/
              // Outputs
              .display_done             (black_is_attacking_display_done), // Templated
              // Inputs
              .clk                      (clk),
              .reset                    (reset),
              .attacking                (black_is_attacking[63:0]), // Templated
              .attacking_valid          (white_is_attacking_display_done)); // Templated
        end // if (DO_DISPLAY)
   endgenerate

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

