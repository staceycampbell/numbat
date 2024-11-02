`include "vchess.vh"

module evaluate_pawns #
  (
   parameter EVAL_WIDTH = 0
   )
   (
    input                            clk,
    input                            reset,

    input                            board_valid,
    input [`BOARD_WIDTH - 1:0]       board,
    input                            clear_eval,
    input                            white_to_move,
   
    output signed [EVAL_WIDTH - 1:0] eval_mg,
    output signed [EVAL_WIDTH - 1:0] eval_eg,
    output                           eval_valid
    );

   assign eval_mg = 0;
   assign eval_eg = 0;
   assign eval_valid = 1;
   
endmodule
