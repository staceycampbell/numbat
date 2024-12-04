`include "vchess.vh"

module evaluate_tropism #
  (
   parameter EVAL_WIDTH = 0,
   parameter WHITE = 0
   )
   (
    input                            clk,
    input                            reset,

    input                            board_valid,
    input [`BOARD_WIDTH - 1:0]       board,
    input                            clear_eval,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg = 0,
    output reg signed [EVAL_WIDTH - 1:0] eval_eg = 0,
    output                           eval_valid
    );

   localparam LATENCY_COUNT = 7;
   localparam LUT_COUNT = (`PIECE_KING << 3 | 7) + 1;

   reg signed [EVAL_WIDTH - 1:0]     king_safety[0:255];
   reg [3:0]                         tropism_lut [0:LUT_COUNT - 1];
   
   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   initial
     begin
`include "evaluate_tropism.vh"
     end

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
