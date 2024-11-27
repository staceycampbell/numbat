`include "vchess.vh"

module evaluate_castling #
  (
   parameter EVAL_WIDTH = 0,
   parameter WHITE_CASTLING = 0
   )
   (
    input                                clk,
    input                                reset,
    input                                board_valid,
    input [`BOARD_WIDTH - 1:0]           board,
    input [3:0]                          castle_mask,
    input [3:0]                          castle_mask_orig,
    input                                clear_eval,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg = 0,
    output                               eval_valid
    );

   localparam LATENCY_COUNT = 7;
   localparam OPPOSITION_QUEEN = WHITE_CASTLING ? `BLACK_QUEN : `WHITE_QUEN;

   reg                                   enemy_queen_t1;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   integer                               i;

   always @(posedge clk)
     begin
        enemy_queen_t1 <= 0;
        for (i = 0; i < 64; i = i + 1)
          if (board[i] == OPPOSITION_QUEEN)
            enemy_queen_t1 <= 1;
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
