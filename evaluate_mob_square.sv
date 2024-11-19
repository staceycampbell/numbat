`include "vchess.vh"

module evaluate_mob_square #
  (
   parameter ATTACKING_PIECE = 0,
   parameter ROW = 0,
   parameter COL = 0,
   parameter EVAL_WIDTH = 0
   )
   (
    input                      clk,
    input                      reset,
   
    input [`BOARD_WIDTH - 1:0] board,
    input                      board_valid,

    output signed [EVAL_WIDTH - 1:0]              eval_mg,
    output signed [EVAL_WIDTH - 1:0]              eval_eg
    );

`include "mobility_head.vh"
   
   localparam PIECE_WIDTH2 = `PIECE_MASK_BITS;
   localparam SIDE_WIDTH2 = PIECE_WIDTH2 * 8;
   localparam BOARD_WIDTH2 = SIDE_WIDTH2 * 8;

   reg [PIECE_WIDTH2 - 1:0]    mobility_mask [0:MOBILITY_LIST_COUNT - 1];

   assign eval_mg = 0;
   assign eval_eg = 0;

   initial
     begin
`include "mobility_mask.vh"
     end

endmodule

