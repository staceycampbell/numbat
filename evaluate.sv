`include "vchess.vh"

module evaluate #
  (
   parameter EVAL_WIDTH = 0
   )
   (
    input                            clk,
    input                            reset,

    input                            use_random_bit,
    input                            random_bit,

    input                            board_valid,
    input                            is_attacking_done,
    input [`BOARD_WIDTH - 1:0]       board_in,
    input                            clear_eval,
    input                            white_to_move,
   
    input [5:0]                      white_pop,
    input [5:0]                      black_pop,

    output                           insufficient_material,
    output signed [EVAL_WIDTH - 1:0] eval,
    output reg                       eval_valid,
    output signed [31:0]             material
    );

   localparam LATENCY_COUNT = 2;
   localparam EVALUATION_COUNT = 1;
   
   reg                               local_board_valid = 0;
   reg [`BOARD_WIDTH - 1:0]          board;
   reg signed [EVAL_WIDTH - 1:0]     eval_t1;
   reg [2:0]                         latency;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire signed [EVAL_WIDTH-1:0] eval_general;   // From evaluate_general of evaluate_general.v
   wire                 eval_general_valid;     // From evaluate_general of evaluate_general.v
   // End of automatics

   wire [EVALUATION_COUNT - 1:0]     eval_done_status = {eval_general_valid};
   wire [EVALUATION_COUNT - 1:0]     evals_complete = ~0;

   assign eval = eval_t1;

   always @(posedge clk)
     begin
        eval_t1 <= eval_general;
     end

   localparam STATE_IDLE = 0;
   localparam STATE_WAIT_ATTACKING_DONE = 1;
   localparam STATE_WAIT_EVAL = 2;
   localparam STATE_WAIT_LATENCY = 3;
   localparam STATE_WAIT_CLEAR = 4;

   reg [2:0]                                            state = STATE_IDLE;

   always @(posedge clk)
     if (reset)
       state <= STATE_IDLE;
     else
       case (state)
         STATE_IDLE :
           begin
              board <= board_in;
              local_board_valid <= 0;
              eval_valid <= 0;
              latency <= 0;
              if (board_valid)
                state <= STATE_WAIT_ATTACKING_DONE;
           end
         STATE_WAIT_ATTACKING_DONE :
           if (is_attacking_done)
             begin
                local_board_valid <= 1;
                state <= STATE_WAIT_EVAL;
             end
         STATE_WAIT_EVAL :
           begin
              if (eval_done_status == evals_complete)
                state <= STATE_WAIT_LATENCY;
           end
         STATE_WAIT_LATENCY :
           begin
              latency <= latency + 1;
              if (latency == LATENCY_COUNT - 1)
                state <= STATE_WAIT_CLEAR;
           end
         STATE_WAIT_CLEAR :
           begin
              eval_valid <= 1;
              if (clear_eval)
                state <= STATE_IDLE;
           end
       endcase

   /* evaluate_general AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_general_valid),
    .eval (eval_general[]),
    );*/
   evaluate_general #
     (
      .EVAL_WIDTH (EVAL_WIDTH)
      )
   evaluate_general
     (/*AUTOINST*/
      // Outputs
      .insufficient_material            (insufficient_material),
      .eval                             (eval_general[EVAL_WIDTH-1:0]), // Templated
      .eval_valid                       (eval_general_valid),    // Templated
      .material                         (material[31:0]),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .use_random_bit                   (use_random_bit),
      .random_bit                       (random_bit),
      .board_valid                      (local_board_valid),     // Templated
      .board                            (board[`BOARD_WIDTH-1:0]),
      .clear_eval                       (clear_eval),
      .white_to_move                    (white_to_move),
      .white_pop                        (white_pop[5:0]),
      .black_pop                        (black_pop[5:0]));

endmodule
