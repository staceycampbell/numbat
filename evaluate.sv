`include "vchess.vh"

module evaluate #
  (
   parameter EVAL_WIDTH = 0,
   parameter MAX_DEPTH_LOG2 = 0,
   parameter EVAL_MOBILITY_DISABLE = 0
   )
   (
    input                            clk,
    input                            reset,

    input                            use_random_bit,
    input                            random_bit,

    input [MAX_DEPTH_LOG2 - 1:0]     killer_ply,
    input [`BOARD_WIDTH - 1:0]       killer_board,
    input                            killer_update,
    input                            killer_clear,
    input signed [EVAL_WIDTH - 1:0]  killer_bonus0,
    input signed [EVAL_WIDTH - 1:0]  killer_bonus1,
   
    input                            board_valid,
    input                            is_attacking_done,
    input [`BOARD_WIDTH - 1:0]       board_in,
    input                            clear_eval,
    input                            white_to_move,

    input [63:0]                     white_is_attacking,
    input [63:0]                     black_is_attacking,
    input                            white_in_check,
    input                            black_in_check,

    output                           insufficient_material,
    output signed [EVAL_WIDTH - 1:0] eval,
    output reg                       eval_valid,
    output signed [31:0]             material
    );

   localparam LATENCY_COUNT = 5;
   localparam EVALUATION_COUNT = 6;
   localparam PHASE_CALC_WIDTH = EVAL_WIDTH + 8 + 1 + $clog2('h100000 / 62);

   reg                               board_valid_r = 0;
   reg                               local_board_valid = 0;
   reg [`BOARD_WIDTH - 1:0]          board;
   reg signed [EVAL_WIDTH - 1:0]     eval_t3;
   reg [2:0]                         latency;
   reg signed [7:0]                  phase;
   reg signed [EVAL_WIDTH + EVALUATION_COUNT - 1:0] eval_a_mg_t1, eval_a_eg_t1;
   reg signed [EVAL_WIDTH + EVALUATION_COUNT - 1:0] eval_b_mg_t1, eval_b_eg_t1;
   reg signed [EVAL_WIDTH + EVALUATION_COUNT - 1:0] eval_mg_t2, eval_eg_t2;
   reg signed [PHASE_CALC_WIDTH - 1:0]              score_mg_t3, score_eg_t3;
   reg signed [PHASE_CALC_WIDTH - 1:0]              score_t4;
   reg signed [PHASE_CALC_WIDTH - 1:0]              score_t5, score_t6;
   reg signed [EVAL_WIDTH - 1:0]                    eval_t7;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 eval_bishops_black_valid;// From evaluate_bishops_black of evaluate_bishops.v
   wire                 eval_bishops_white_valid;// From evaluate_bishops_white of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_bishops_black;// From evaluate_bishops_black of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_bishops_white;// From evaluate_bishops_white of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_general;// From evaluate_general of evaluate_general.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_killer; // From evaluate_killer of evaluate_killer.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_mob;    // From evaluate_mob of evaluate_mob.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_pawns_black;// From evaluate_pawns_black of evaluate_pawns.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_pawns_white;// From evaluate_pawns_white of evaluate_pawns.v
   wire                 eval_general_valid;     // From evaluate_general of evaluate_general.v
   wire                 eval_killer_valid;      // From evaluate_killer of evaluate_killer.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_bishops_black;// From evaluate_bishops_black of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_bishops_white;// From evaluate_bishops_white of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_general;// From evaluate_general of evaluate_general.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_killer; // From evaluate_killer of evaluate_killer.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_mob;    // From evaluate_mob of evaluate_mob.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_pawns_black;// From evaluate_pawns_black of evaluate_pawns.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_pawns_white;// From evaluate_pawns_white of evaluate_pawns.v
   wire                 eval_mob_valid;         // From evaluate_mob of evaluate_mob.v
   wire                 eval_pawns_black_valid; // From evaluate_pawns_black of evaluate_pawns.v
   wire                 eval_pawns_white_valid; // From evaluate_pawns_white of evaluate_pawns.v
   wire [5:0]           occupied_count;         // From popcount_occupied of popcount.v
   // End of automatics

   genvar                                           c;

   wire [63:0]                                      occupied;

   wire [EVALUATION_COUNT - 1:0]                    eval_done_status = {eval_bishops_black_valid,
                                                                        eval_bishops_white_valid,
                                                                        eval_killer_valid,
                                                                        eval_mob_valid,
                                                                        eval_pawns_black_valid,
                                                                        eval_pawns_white_valid,
                                                                        eval_general_valid};
   wire [EVALUATION_COUNT - 1:0]                    evals_complete = ~0;

   assign eval = eval_t7;

   generate
      for (c = 0; c < 64; c = c + 1)
        begin : occupied_block
           assign occupied[c] = board[c * `PIECE_WIDTH+:`PIECE_WIDTH] != `EMPTY_POSN;
        end
   endgenerate

   // From crafty:
   // phase = Min(62, TotalPieces(white, occupied) + TotalPieces(black, occupied));
   // score = ((tree->score_mg * phase) + (tree->score_eg * (62 - phase))) / 62;
   always @(posedge clk)
     begin
        board_valid_r <= board_valid;

        if (occupied_count > 62)
          phase <= 62;
        else
          phase <= occupied_count;
        eval_a_mg_t1 <= eval_mg_general + eval_mg_pawns_white + eval_mg_pawns_black;
        eval_b_mg_t1 <= eval_mg_mob + eval_mg_killer + eval_mg_bishops_white + eval_mg_bishops_black;
        eval_a_eg_t1 <= eval_eg_general + eval_eg_pawns_white + eval_eg_pawns_black;
        eval_b_eg_t1 <= eval_eg_mob + eval_eg_killer + eval_eg_bishops_white + eval_eg_bishops_black;
        eval_mg_t2 <= eval_a_mg_t1 + eval_b_mg_t1;
        eval_eg_t2 <= eval_a_eg_t1 + eval_b_eg_t1;
        score_mg_t3 <= eval_mg_t2 * phase;
        score_eg_t3 <= eval_eg_t2 * (62 - phase);
        score_t4 <= score_mg_t3 + score_eg_t3;
        score_t5 <= score_t4 * $signed(32'h100000 / 62);
        score_t6 <= score_t5 / $signed(32'h100000);
        eval_t7 <= score_t6;
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
              if (board_valid && ~board_valid_r)
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
         default :
           state <= STATE_IDLE;
       endcase

   /* evaluate_general AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_general_valid),
    .eval_\([me]\)g (eval_\1g_general[]),
    );*/
   evaluate_general #
     (
      .EVAL_WIDTH (EVAL_WIDTH)
      )
   evaluate_general
     (/*AUTOINST*/
      // Outputs
      .insufficient_material            (insufficient_material),
      .eval_mg                          (eval_mg_general[EVAL_WIDTH-1:0]), // Templated
      .eval_eg                          (eval_eg_general[EVAL_WIDTH-1:0]), // Templated
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
      .white_to_move                    (white_to_move));

   /* evaluate_pawns AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_pawns_white_valid),
    .eval_\([me]\)g (eval_\1g_pawns_white[]),
    );*/
   evaluate_pawns #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_PAWNS (1)
      )
   evaluate_pawns_white
     (/*AUTOINST*/
      // Outputs
      .eval_mg                          (eval_mg_pawns_white[EVAL_WIDTH-1:0]), // Templated
      .eval_eg                          (eval_eg_pawns_white[EVAL_WIDTH-1:0]), // Templated
      .eval_valid                       (eval_pawns_white_valid), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (local_board_valid),     // Templated
      .board                            (board[`BOARD_WIDTH-1:0]),
      .clear_eval                       (clear_eval));

   /* evaluate_pawns AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_pawns_black_valid),
    .eval_\([me]\)g (eval_\1g_pawns_black[]),
    );*/
   evaluate_pawns #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_PAWNS (0)
      )
   evaluate_pawns_black
     (/*AUTOINST*/
      // Outputs
      .eval_mg                          (eval_mg_pawns_black[EVAL_WIDTH-1:0]), // Templated
      .eval_eg                          (eval_eg_pawns_black[EVAL_WIDTH-1:0]), // Templated
      .eval_valid                       (eval_pawns_black_valid), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (local_board_valid),     // Templated
      .board                            (board[`BOARD_WIDTH-1:0]),
      .clear_eval                       (clear_eval));

   /* evaluate_bishops AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_bishops_white_valid),
    .eval_\([me]\)g (eval_\1g_bishops_white[]),
    );*/
   evaluate_bishops #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_BISHOPS (1)
      )
   evaluate_bishops_white
     (/*AUTOINST*/
      // Outputs
      .eval_mg                          (eval_mg_bishops_white[EVAL_WIDTH-1:0]), // Templated
      .eval_eg                          (eval_eg_bishops_white[EVAL_WIDTH-1:0]), // Templated
      .eval_valid                       (eval_bishops_white_valid), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (local_board_valid),     // Templated
      .board                            (board[`BOARD_WIDTH-1:0]),
      .clear_eval                       (clear_eval));

   /* evaluate_bishops AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_bishops_black_valid),
    .eval_\([me]\)g (eval_\1g_bishops_black[]),
    );*/
   evaluate_bishops #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_BISHOPS (0)
      )
   evaluate_bishops_black
     (/*AUTOINST*/
      // Outputs
      .eval_mg                          (eval_mg_bishops_black[EVAL_WIDTH-1:0]), // Templated
      .eval_eg                          (eval_eg_bishops_black[EVAL_WIDTH-1:0]), // Templated
      .eval_valid                       (eval_bishops_black_valid), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (local_board_valid),     // Templated
      .board                            (board[`BOARD_WIDTH-1:0]),
      .clear_eval                       (clear_eval));
   
   generate
      if (! EVAL_MOBILITY_DISABLE)
        begin : eval_mob_blk
           /* evaluate_mob AUTO_TEMPLATE (
            .board_valid (local_board_valid),
            .eval_valid (eval_mob_valid),
            .eval_\([me]\)g (eval_\1g_mob[]),
            );*/
           evaluate_mob #
             (
              .EVAL_WIDTH (EVAL_WIDTH)
              )
           evaluate_mob
             (/*AUTOINST*/
              // Outputs
              .eval_mg                  (eval_mg_mob[EVAL_WIDTH-1:0]), // Templated
              .eval_eg                  (eval_eg_mob[EVAL_WIDTH-1:0]), // Templated
              .eval_valid               (eval_mob_valid),        // Templated
              // Inputs
              .clk                      (clk),
              .reset                    (reset),
              .board_valid              (local_board_valid),     // Templated
              .board                    (board[`BOARD_WIDTH-1:0]),
              .clear_eval               (clear_eval));
        end
      else
        begin
           assign eval_mob_valid = 1;
           assign eval_mg_mob = 0;
           assign eval_eg_mob = 0;
        end
   endgenerate

   /* evaluate_killer AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_killer_valid),
    .eval_\([me]\)g (eval_\1g_killer[]),
    );*/
   evaluate_killer #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .MAX_DEPTH_LOG2 (MAX_DEPTH_LOG2)
      )
   evaluate_killer
     (/*AUTOINST*/
      // Outputs
      .eval_mg                          (eval_mg_killer[EVAL_WIDTH-1:0]), // Templated
      .eval_eg                          (eval_eg_killer[EVAL_WIDTH-1:0]), // Templated
      .eval_valid                       (eval_killer_valid),     // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (local_board_valid),     // Templated
      .board                            (board[`BOARD_WIDTH-1:0]),
      .clear_eval                       (clear_eval),
      .white_to_move                    (white_to_move),
      .killer_ply                       (killer_ply[MAX_DEPTH_LOG2-1:0]),
      .killer_board                     (killer_board[`BOARD_WIDTH-1:0]),
      .killer_update                    (killer_update),
      .killer_clear                     (killer_clear),
      .killer_bonus0                    (killer_bonus0[EVAL_WIDTH-1:0]),
      .killer_bonus1                    (killer_bonus1[EVAL_WIDTH-1:0]));

   /* popcount AUTO_TEMPLATE (
    .population (occupied_count[]),
    .x0 (occupied[]),
    );*/
   popcount popcount_occupied
     (/*AUTOINST*/
      // Outputs
      .population                       (occupied_count[5:0]),   // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (occupied[63:0]));        // Templated

endmodule
