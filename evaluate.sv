// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

module evaluate #
  (
   parameter EVAL_WIDTH = 0,
   parameter MAX_DEPTH_LOG2 = 0,
   parameter EVAL_MOBILITY_DISABLE = 0,
   parameter UCI_WIDTH = 0
   )
   (
    input                            clk,
    input                            reset,

    input [EVAL_WIDTH - 1:0]         random_score_mask,
    input [EVAL_WIDTH - 1:0]         random_number,

    input [31:0]                     algorithm_enable,

    input                            board_valid,
    input                            is_attacking_done,
    input [`BOARD_WIDTH - 1:0]       board_in,
    input [UCI_WIDTH - 1:0]          uci_in,
    input [3:0]                      castle_mask,
    input [3:0]                      castle_mask_orig,
    input                            clear_eval,
    input                            white_to_move,

    input [63:0]                     white_is_attacking,
    input [63:0]                     black_is_attacking,
    input                            white_in_check,
    input                            black_in_check,

    input [MAX_DEPTH_LOG2 - 1:0]     killer_ply,
    input [`BOARD_WIDTH - 1:0]       killer_board,
    input                            killer_update,
    input                            killer_clear,
    input signed [EVAL_WIDTH - 1:0]  killer_bonus0,
    input signed [EVAL_WIDTH - 1:0]  killer_bonus1,
   
    input [31:0]                     pv_ctrl_in,
   
    output                           insufficient_material,
    output signed [EVAL_WIDTH - 1:0] eval,
    output                           eval_pv_flag,
    output reg                       eval_valid = 0
    );

   localparam LATENCY_COUNT = 8;
   localparam EVALUATION_COUNT = 13;
   localparam PHASE_CALC_WIDTH = EVAL_WIDTH + 8 + 1 + $clog2('h100000 / 62);

   reg                               board_valid_r = 0;
   reg                               local_board_valid = 0;
   reg [`BOARD_WIDTH - 1:0]          board, board_pre;
   reg [2:0]                         latency;
   reg signed [7:0]                  phase, phase_r;
   reg signed [EVAL_WIDTH + EVALUATION_COUNT - 1:0] eval_a_mg_t1, eval_b_mg_t1, eval_c_mg_t1, eval_d_mg_t1;
   reg signed [EVAL_WIDTH + EVALUATION_COUNT - 1:0] eval_a_eg_t1, eval_b_eg_t1, eval_c_eg_t1;
   reg signed [EVAL_WIDTH + EVALUATION_COUNT - 1:0] eval_mg_t2, eval_eg_t2;
   reg signed [PHASE_CALC_WIDTH - 1:0]              score_mg_t3, score_eg_t3;
   reg signed [PHASE_CALC_WIDTH - 1:0]              score_mg_t4, score_eg_t4;
   reg signed [PHASE_CALC_WIDTH - 1:0]              score_t5;
   reg signed [PHASE_CALC_WIDTH - 1:0]              score_t6, score_t7;
   reg signed [EVAL_WIDTH - 1:0]                    eval_t8;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 eval_bishops_black_valid;// From evaluate_bishops_black of evaluate_bishops.v
   wire                 eval_bishops_white_valid;// From evaluate_bishops_white of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] eval_castling_black_mg;// From evaluate_castling_black of evaluate_castling.v
   wire                 eval_castling_black_valid;// From evaluate_castling_black of evaluate_castling.v
   wire signed [EVAL_WIDTH-1:0] eval_castling_white_mg;// From evaluate_castling_white of evaluate_castling.v
   wire                 eval_castling_white_valid;// From evaluate_castling_white of evaluate_castling.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_bishops_black;// From evaluate_bishops_black of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_bishops_white;// From evaluate_bishops_white of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_general;// From evaluate_general of evaluate_general.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_killer; // From evaluate_killer of evaluate_killer.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_mob;    // From evaluate_mob of evaluate_mob.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_pawns_black;// From evaluate_pawns_black of evaluate_pawns.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_pawns_white;// From evaluate_pawns_white of evaluate_pawns.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_rooks_black;// From evaluate_rooks_black of evaluate_rooks.v
   wire signed [EVAL_WIDTH-1:0] eval_eg_rooks_white;// From evaluate_rooks_white of evaluate_rooks.v
   wire                 eval_general_valid;     // From evaluate_general of evaluate_general.v
   wire                 eval_killer_valid;      // From evaluate_killer of evaluate_killer.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_bishops_black;// From evaluate_bishops_black of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_bishops_white;// From evaluate_bishops_white of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_general;// From evaluate_general of evaluate_general.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_killer; // From evaluate_killer of evaluate_killer.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_mob;    // From evaluate_mob of evaluate_mob.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_pawns_black;// From evaluate_pawns_black of evaluate_pawns.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_pawns_white;// From evaluate_pawns_white of evaluate_pawns.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_rooks_black;// From evaluate_rooks_black of evaluate_rooks.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_rooks_white;// From evaluate_rooks_white of evaluate_rooks.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_tropism_black;// From evaluate_tropism_black of evaluate_tropism.v
   wire signed [EVAL_WIDTH-1:0] eval_mg_tropism_white;// From evaluate_tropism_white of evaluate_tropism.v
   wire                 eval_mob_valid;         // From evaluate_mob of evaluate_mob.v
   wire                 eval_pawns_black_valid; // From evaluate_pawns_black of evaluate_pawns.v
   wire                 eval_pawns_white_valid; // From evaluate_pawns_white of evaluate_pawns.v
   wire                 eval_pv_valid;          // From evaluate_pv of evaluate_pv.v
   wire                 eval_rooks_black_valid; // From evaluate_rooks_black of evaluate_rooks.v
   wire                 eval_rooks_white_valid; // From evaluate_rooks_white of evaluate_rooks.v
   wire                 eval_tropism_black_valid;// From evaluate_tropism_black of evaluate_tropism.v
   wire                 eval_tropism_white_valid;// From evaluate_tropism_white of evaluate_tropism.v
   wire [5:0]           occupied_count;         // From popcount_occupied of popcount.v
   // End of automatics

   genvar                                           c;

   wire [63:0]                                      occupied;

   wire [EVALUATION_COUNT - 1:0]                    eval_done_status =
                                                    {
                                                     eval_pv_valid,
                                                     eval_tropism_black_valid,
                                                     eval_tropism_white_valid,
                                                     eval_castling_black_valid,
                                                     eval_castling_white_valid,
                                                     eval_bishops_black_valid,
                                                     eval_bishops_white_valid,
                                                     eval_rooks_black_valid,
                                                     eval_rooks_white_valid,
                                                     eval_killer_valid,
                                                     eval_mob_valid,
                                                     eval_pawns_black_valid,
                                                     eval_pawns_white_valid,
                                                     eval_general_valid
                                                     };
   wire [EVALUATION_COUNT - 1:0]                    evals_complete = ~0;

   assign eval = eval_t8;

   generate
      for (c = 0; c < 64; c = c + 1)
        begin : occupied_block
           assign occupied[c] = board[c * `PIECE_WIDTH+:`PIECE_WIDTH] != `EMPTY_POSN &&
                                board[c * `PIECE_WIDTH+:`PIECE_WIDTH - 1] != `PIECE_PAWN;
        end
   endgenerate

   // From crafty:
   // phase = Min(62, TotalPieces(white, occupied) + TotalPieces(black, occupied));
   // score = ((tree->score_mg * phase) + (tree->score_eg * (62 - phase))) / 62;
   // note: "occupied" excludes pawns in crafty phase calc
   always @(posedge clk)
     begin
        board_valid_r <= board_valid;
        board <= board_pre; // flopped for timing

        if (occupied_count > 62)
          phase <= 62;
        else
          phase <= occupied_count;
        phase_r <= phase;
        eval_a_mg_t1 <= eval_mg_general + eval_mg_pawns_white + eval_mg_pawns_black;
        eval_b_mg_t1 <= eval_mg_mob + eval_mg_killer + eval_mg_bishops_white + eval_mg_bishops_black;
        eval_c_mg_t1 <= eval_castling_white_mg + eval_castling_black_mg + eval_mg_rooks_white + eval_mg_rooks_black;
        eval_d_mg_t1 <= eval_mg_tropism_white + eval_mg_tropism_black;
        
        eval_a_eg_t1 <= eval_eg_general + eval_eg_pawns_white + eval_eg_pawns_black;
        eval_b_eg_t1 <= eval_eg_mob + eval_eg_killer + eval_eg_bishops_white + eval_eg_bishops_black;
        eval_c_eg_t1 <= eval_eg_rooks_white + eval_eg_rooks_black;
        
        eval_mg_t2 <= eval_a_mg_t1 + eval_b_mg_t1 + eval_c_mg_t1 + eval_d_mg_t1;
        eval_eg_t2 <= eval_a_eg_t1 + eval_b_eg_t1 + eval_b_eg_t1;
        score_mg_t3 <= eval_mg_t2 * phase_r;
        score_eg_t3 <= eval_eg_t2 * (62 - phase_r);
        score_mg_t4 <= score_mg_t3;
        score_eg_t4 <= score_eg_t3;
        score_t5 <= score_mg_t4 + score_eg_t4;
        score_t6 <= score_t5 * $signed(32'h100000 / 62);
        score_t7 <= score_t6 / $signed(32'h100000);
        eval_t8 <= score_t7;
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
              board_pre <= board_in;
              local_board_valid <= 0;
              eval_valid <= 0;
              latency <= 0;
              if (board_valid && ~board_valid_r)
                state <= STATE_WAIT_ATTACKING_DONE; // note: one ws required for board to valid, flopped for timing
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
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .random_score_mask                (random_score_mask[EVAL_WIDTH-1:0]),
      .random_number                    (random_number[EVAL_WIDTH-1:0]),
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
      .clear_eval                       (clear_eval),
      .white_is_attacking               (white_is_attacking[63:0]),
      .black_is_attacking               (black_is_attacking[63:0]));

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
      .clear_eval                       (clear_eval),
      .white_is_attacking               (white_is_attacking[63:0]),
      .black_is_attacking               (black_is_attacking[63:0]));

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
            .enable (algorithm_enable[0]),
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
              .enable                   (algorithm_enable[0]),   // Templated
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

   /* evaluate_castling AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_castling_white_valid),
    .eval_mg (eval_castling_white_mg[]),
    );*/
   evaluate_castling #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_CASTLING (1)
      )
   evaluate_castling_white
     (/*AUTOINST*/
      // Outputs
      .eval_mg                          (eval_castling_white_mg[EVAL_WIDTH-1:0]), // Templated
      .eval_valid                       (eval_castling_white_valid), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (local_board_valid),     // Templated
      .board                            (board[`BOARD_WIDTH-1:0]),
      .castle_mask                      (castle_mask[3:0]),
      .castle_mask_orig                 (castle_mask_orig[3:0]),
      .clear_eval                       (clear_eval));

   /* evaluate_castling AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_castling_black_valid),
    .eval_mg (eval_castling_black_mg[]),
    );*/
   evaluate_castling #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_CASTLING (0)
      )
   evaluate_castling_black
     (/*AUTOINST*/
      // Outputs
      .eval_mg                          (eval_castling_black_mg[EVAL_WIDTH-1:0]), // Templated
      .eval_valid                       (eval_castling_black_valid), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (local_board_valid),     // Templated
      .board                            (board[`BOARD_WIDTH-1:0]),
      .castle_mask                      (castle_mask[3:0]),
      .castle_mask_orig                 (castle_mask_orig[3:0]),
      .clear_eval                       (clear_eval));

   /* evaluate_rooks AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_rooks_white_valid),
    .eval_\([me]\)g (eval_\1g_rooks_white[]),
    );*/
   evaluate_rooks #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_ROOKS (1)
      )
   evaluate_rooks_white
     (/*AUTOINST*/
      // Outputs
      .eval_mg                          (eval_mg_rooks_white[EVAL_WIDTH-1:0]), // Templated
      .eval_eg                          (eval_eg_rooks_white[EVAL_WIDTH-1:0]), // Templated
      .eval_valid                       (eval_rooks_white_valid), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (local_board_valid),     // Templated
      .board                            (board[`BOARD_WIDTH-1:0]),
      .clear_eval                       (clear_eval));

   /* evaluate_rooks AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_rooks_black_valid),
    .eval_\([me]\)g (eval_\1g_rooks_black[]),
    );*/
   evaluate_rooks #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_ROOKS (0)
      )
   evaluate_rooks_black
     (/*AUTOINST*/
      // Outputs
      .eval_mg                          (eval_mg_rooks_black[EVAL_WIDTH-1:0]), // Templated
      .eval_eg                          (eval_eg_rooks_black[EVAL_WIDTH-1:0]), // Templated
      .eval_valid                       (eval_rooks_black_valid), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (local_board_valid),     // Templated
      .board                            (board[`BOARD_WIDTH-1:0]),
      .clear_eval                       (clear_eval));
   
   /* evaluate_tropism AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_tropism_white_valid),
    .eval_\([me]\)g (eval_\1g_tropism_white[]),
    );*/
   evaluate_tropism #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE (1)
      )
   evaluate_tropism_white
     (/*AUTOINST*/
      // Outputs
      .eval_mg                          (eval_mg_tropism_white[EVAL_WIDTH-1:0]), // Templated
      .eval_valid                       (eval_tropism_white_valid), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (local_board_valid),     // Templated
      .castle_mask                      (castle_mask[3:0]),
      .board                            (board[`BOARD_WIDTH-1:0]),
      .clear_eval                       (clear_eval));

   /* evaluate_tropism AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_tropism_black_valid),
    .eval_\([me]\)g (eval_\1g_tropism_black[]),
    );*/
   evaluate_tropism #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE (0)
      )
   evaluate_tropism_black
     (/*AUTOINST*/
      // Outputs
      .eval_mg                          (eval_mg_tropism_black[EVAL_WIDTH-1:0]), // Templated
      .eval_valid                       (eval_tropism_black_valid), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (local_board_valid),     // Templated
      .castle_mask                      (castle_mask[3:0]),
      .board                            (board[`BOARD_WIDTH-1:0]),
      .clear_eval                       (clear_eval));

   /* evaluate_pv AUTO_TEMPLATE (
    .board_valid (local_board_valid),
    .eval_valid (eval_pv_valid),
    .pv_ply (killer_ply[]), // this works for now, create a pv ply if that changes
    );*/
   evaluate_pv #
     (
      .UCI_WIDTH (UCI_WIDTH),
      .MAX_DEPTH_LOG2 (MAX_DEPTH_LOG2)
      )
   evaluate_pv
     (/*AUTOINST*/
      // Outputs
      .eval_pv_flag                     (eval_pv_flag),
      .eval_valid                       (eval_pv_valid),         // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (local_board_valid),     // Templated
      .uci_in                           (uci_in[UCI_WIDTH-1:0]),
      .pv_ply                           (killer_ply[MAX_DEPTH_LOG2-1:0]), // Templated
      .clear_eval                       (clear_eval),
      .pv_ctrl_in                       (pv_ctrl_in[31:0]));
   
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
