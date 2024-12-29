// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "vchess.vh"

module board_attack
  (
   input                      reset,
   input                      clk,
  
   input [`BOARD_WIDTH - 1:0] board,
   input                      board_valid,
   input                      clear_attack,

   output reg                 is_attacking_done = 0,
   output [63:0]              white_is_attacking,
   output [63:0]              black_is_attacking,
   output                     white_in_check,
   output                     black_in_check,
   output [5:0]               attack_white_pop,
   output [5:0]               attack_black_pop
   );

   // should be empty
   /*AUTOREGINPUT*/
   
   /*AUTOWIRE*/
   
   wire [63:0]                white_is_attacking_valid, black_is_attacking_valid;
   wire [63:0]                white_in_check_list, black_in_check_list;

   genvar                     row, col;

   assign white_in_check = white_in_check_list != 0;
   assign black_in_check = black_in_check_list != 0;

   localparam STATE_IDLE = 0;
   localparam STATE_RUN = 1;
   localparam STATE_POP_COUNT_WS = 2;
   localparam STATE_DONE = 3;

   reg [1:0]                  state = STATE_IDLE;

   always @(posedge clk)
     if (reset)
       state <= STATE_IDLE;
     else
       case (state)
         STATE_IDLE :
           begin
              is_attacking_done <= 0;
              if (board_valid)
                state <= STATE_RUN;
           end
         STATE_RUN :
           if (white_is_attacking_valid != 0)
             state <= STATE_POP_COUNT_WS;
         STATE_POP_COUNT_WS : // wait for pop count to be valid
           state <= STATE_DONE;
         STATE_DONE :
           begin
              is_attacking_done <= 1;
              if (clear_attack)
                state <= STATE_IDLE;
           end
         default :
           state <= STATE_IDLE;
       endcase

   /* popcount AUTO_TEMPLATE (
    .x0 (white_is_attacking[]),
    .population (attack_white_pop[]),
    );*/
   popcount popcount_white
     (/*AUTOINST*/
      // Outputs
      .population                       (attack_white_pop[5:0]), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (white_is_attacking[63:0])); // Templated

   /* popcount AUTO_TEMPLATE (
    .x0 (black_is_attacking[]),
    .population (attack_black_pop[]),
    );*/
   popcount popcount_black
     (/*AUTOINST*/
      // Outputs
      .population                       (attack_black_pop[5:0]), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (black_is_attacking[63:0])); // Templated
   
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
                       .board           (board[`BOARD_WIDTH-1:0]),
                       .board_valid     (board_valid));
                
                /* is_attacking AUTO_TEMPLATE (
                 .attacking (black_is_attacking[row << 3 | col]),
                 .attacking_valid (black_is_attacking_valid[row << 3 | col]),
                 .opponent_in_check (white_in_check_list[row << 3 | col]),
                 );*/
                is_attacking #
                  (
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
                   .board               (board[`BOARD_WIDTH-1:0]),
                   .board_valid         (board_valid));
             end
        end
      
   endgenerate

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

