`include "vchess.vh"

module evaluate_bishops #
  (
   parameter EVAL_WIDTH = 0,
   parameter WHITE_BISHOPS = 0
   )
   (
    input                                clk,
    input                                reset,

    input                                board_valid,
    input [`BOARD_WIDTH - 1:0]           board,
    input                                clear_eval,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg = 0,
    output reg signed [EVAL_WIDTH - 1:0] eval_eg = 0,
    output                               eval_valid
    );

   localparam LATENCY_COUNT = 7;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   /* latency_sm AUTO_TEMPLATE (
    );*/
   latency_sm #
     (
      .LATENCY_COUNT (LATENCY_COUNT)
      )
   latency_sm
     (/*AUTOINST*/
      // Outputs
      .eval_valid                       (eval_valid),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .clear_eval                       (clear_eval));

endmodule
