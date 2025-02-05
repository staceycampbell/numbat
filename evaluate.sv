// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

module evaluate #
  (
   parameter EVAL_WIDTH = 0,
   parameter MAX_DEPTH_LOG2 = 0,
   parameter UCI_WIDTH = 0,
   parameter BYPASS_WIDTH = 0
   )
   (
    input                            clk,
    input                            reset,

    input [EVAL_WIDTH - 1:0]         random_score_mask,
    input [EVAL_WIDTH - 1:0]         random_number,

    input [31:0]                     algorithm_enable,

    input                            board_valid,
    input [`BOARD_WIDTH - 1:0]       board_in,
    input [UCI_WIDTH - 1:0]          uci_in,
    input [3:0]                      castle_mask,
    input [3:0]                      castle_mask_orig,
    input                            white_to_move,
    input [BYPASS_WIDTH - 1:0]       bp_in,

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
    output                           eval_valid,
    output [BYPASS_WIDTH - 1:0]      bp_out
    );

   localparam EVALUATION_COUNT = 13;
   localparam SUM_WIDTH = EVAL_WIDTH + EVALUATION_COUNT;
   localparam PHASE_CALC_WIDTH = EVAL_WIDTH + 8 + 1 + $clog2('h100000 / 62);
   
   reg signed [SUM_WIDTH - 1:0]      sum_mg_t4, sum_mg_t5, sum_mg_t6, sum_mg_t7, sum_mg_t8, sum_mg_t9, sum_mg_t10, sum_mg_t11;
   reg signed [SUM_WIDTH - 1:0]      sum_eg_t4, sum_eg_t5, sum_eg_t6, sum_eg_t7, sum_eg_t8, sum_eg_t9, sum_eg_t10, sum_eg_t11;
   
   reg signed [PHASE_CALC_WIDTH - 1:0] score_mg_t12, score_eg_t12;
   reg signed [PHASE_CALC_WIDTH - 1:0] score_mg_t13, score_eg_t13;
   reg signed [PHASE_CALC_WIDTH - 1:0] score_t14;
   reg signed [PHASE_CALC_WIDTH - 1:0] score_t15, score_t16;
   reg signed [EVAL_WIDTH - 1:0]       eval_t17;
   
   reg signed [7:0]                    phase_t2, phase_t3, phase_t4, phase_t5, phase_t6, phase_t7, phase_t8, phase_t9, phase_t10, phase_t11;
   reg                                 insufficient_material_t8, insufficient_material_t9, insufficient_material_t10,
                                       insufficient_material_t11, insufficient_material_t12, insufficient_material_t13,
                                       insufficient_material_t14, insufficient_material_t15, insufficient_material_t16,
                                       insufficient_material_t17;
   reg                                 eval_pv_flag_t1, eval_pv_flag_t2, eval_pv_flag_t3, eval_pv_flag_t4, eval_pv_flag_t5,
                                       eval_pv_flag_t6, eval_pv_flag_t7, eval_pv_flag_t8, eval_pv_flag_t9, eval_pv_flag_t10,
                                       eval_pv_flag_t11, eval_pv_flag_t12, eval_pv_flag_t13, eval_pv_flag_t14, eval_pv_flag_t15,
                                       eval_pv_flag_t16, eval_pv_flag_t17;
   reg [BYPASS_WIDTH - 1:0]            bp_t1, bp_t2, bp_t3, bp_t4, bp_t5, bp_t6, bp_t7, bp_t8, bp_t9, bp_t10, bp_t11, bp_t12,
                                       bp_t13, bp_t14, bp_t15, bp_t16, bp_t17;
   reg                                 eval_valid_t1, eval_valid_t2, eval_valid_t3, eval_valid_t4, eval_valid_t5, eval_valid_t6,
                                       eval_valid_t7, eval_valid_t8, eval_valid_t9, eval_valid_t10, eval_valid_t11, eval_valid_t12,
                                       eval_valid_t13, eval_valid_t14, eval_valid_t15, eval_valid_t16, eval_valid_t17;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 eval_pv_valid_t1;       // From evaluate_pv of evaluate_pv.v
   wire signed [EVAL_WIDTH-1:0] evaluate_bishops_black_eg_t7;// From evaluate_bishops_black of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] evaluate_bishops_black_mg_t7;// From evaluate_bishops_black of evaluate_bishops.v
   wire                 evaluate_bishops_black_valid_t7;// From evaluate_bishops_black of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] evaluate_bishops_white_eg_t7;// From evaluate_bishops_white of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] evaluate_bishops_white_mg_t7;// From evaluate_bishops_white of evaluate_bishops.v
   wire                 evaluate_bishops_white_valid_t7;// From evaluate_bishops_white of evaluate_bishops.v
   wire signed [EVAL_WIDTH-1:0] evaluate_castling_black_mg_t5;// From evaluate_castling_black of evaluate_castling.v
   wire                 evaluate_castling_black_valid_t5;// From evaluate_castling_black of evaluate_castling.v
   wire signed [EVAL_WIDTH-1:0] evaluate_castling_white_mg_t5;// From evaluate_castling_white of evaluate_castling.v
   wire                 evaluate_castling_white_valid_t5;// From evaluate_castling_white of evaluate_castling.v
   wire signed [EVAL_WIDTH-1:0] evaluate_general_eg_t7;// From evaluate_general of evaluate_general.v
   wire signed [EVAL_WIDTH-1:0] evaluate_general_mg_t7;// From evaluate_general of evaluate_general.v
   wire                 evaluate_general_valid_t7;// From evaluate_general of evaluate_general.v
   wire signed [EVAL_WIDTH-1:0] evaluate_killer_eg_t3;// From evaluate_killer of evaluate_killer.v
   wire signed [EVAL_WIDTH-1:0] evaluate_killer_mg_t3;// From evaluate_killer of evaluate_killer.v
   wire                 evaluate_killer_valid_t3;// From evaluate_killer of evaluate_killer.v
   wire signed [EVAL_WIDTH-1:0] evaluate_pawns_black_eg_t8;// From evaluate_pawns_black of evaluate_pawns.v
   wire signed [EVAL_WIDTH-1:0] evaluate_pawns_black_mg_t8;// From evaluate_pawns_black of evaluate_pawns.v
   wire                 evaluate_pawns_black_valid_t8;// From evaluate_pawns_black of evaluate_pawns.v
   wire signed [EVAL_WIDTH-1:0] evaluate_pawns_white_eg_t8;// From evaluate_pawns_white of evaluate_pawns.v
   wire signed [EVAL_WIDTH-1:0] evaluate_pawns_white_mg_t8;// From evaluate_pawns_white of evaluate_pawns.v
   wire                 evaluate_pawns_white_valid_t8;// From evaluate_pawns_white of evaluate_pawns.v
   wire signed [EVAL_WIDTH-1:0] evaluate_rooks_black_eg_t5;// From evaluate_rooks_black of evaluate_rooks.v
   wire signed [EVAL_WIDTH-1:0] evaluate_rooks_black_mg_t5;// From evaluate_rooks_black of evaluate_rooks.v
   wire                 evaluate_rooks_black_valid_t5;// From evaluate_rooks_black of evaluate_rooks.v
   wire signed [EVAL_WIDTH-1:0] evaluate_rooks_white_eg_t5;// From evaluate_rooks_white of evaluate_rooks.v
   wire signed [EVAL_WIDTH-1:0] evaluate_rooks_white_mg_t5;// From evaluate_rooks_white of evaluate_rooks.v
   wire                 evaluate_rooks_white_valid_t5;// From evaluate_rooks_white of evaluate_rooks.v
   wire signed [EVAL_WIDTH-1:0] evaluate_tropism_black_mg_t10;// From evaluate_tropism_black of evaluate_tropism.v
   wire                 evaluate_tropism_black_valid_t10;// From evaluate_tropism_black of evaluate_tropism.v
   wire signed [EVAL_WIDTH-1:0] evaluate_tropism_white_mg_t10;// From evaluate_tropism_white of evaluate_tropism.v
   wire                 evaluate_tropism_white_valid_t10;// From evaluate_tropism_white of evaluate_tropism.v
   wire                 insufficient_material_t7;// From evaluate_general of evaluate_general.v
   wire [5:0]           occupied_count_t1;      // From popcount_occupied of popcount.v
   // End of automatics

   genvar                              c;
   integer                             i;
   
   wire [`BOARD_WIDTH - 1:0]           board = board_in;
   wire [`BOARD_WIDTH - 1:0]           board_t0 = board_in;
   wire [BYPASS_WIDTH - 1:0]           bp_t0 = bp_in;
   wire                                eval_valid_t0 = board_valid;

   wire [63:0]                         occupied_t0;

   assign eval = eval_t17;
   assign eval_pv_flag = eval_pv_flag_t17;
   assign insufficient_material = insufficient_material_t17;
   assign bp_out = bp_t17;
   assign eval_valid = eval_valid_t17;

   generate
      for (c = 0; c < 64; c = c + 1)
        begin : occupied_block
           assign occupied_t0[c] = board_t0[c * `PIECE_WIDTH+:`PIECE_WIDTH] != `EMPTY_POSN &&
                                   board_t0[c * `PIECE_WIDTH+:`PIECE_WIDTH - 1] != `PIECE_PAWN &&
                                   board_t0[c * `PIECE_WIDTH+:`PIECE_WIDTH - 1] != `PIECE_KING;
        end
   endgenerate

   // From crafty:
   // phase = Min(62, TotalPieces(white, occupied) + TotalPieces(black, occupied));
   // score = ((tree->score_mg * phase) + (tree->score_eg * (62 - phase))) / 62;
   // note: "occupied" excludes pawns in crafty phase calc
   always @(posedge clk)
     begin
        if (occupied_count_t1 > 62)
          phase_t2 <= 62;
        else
          phase_t2 <= occupied_count_t1;

        sum_mg_t4 <= evaluate_killer_mg_t3;
        sum_eg_t4 <= evaluate_killer_eg_t3;

        sum_mg_t5 <= sum_mg_t4;
        sum_eg_t5 <= sum_eg_t4;

        sum_mg_t6 <= sum_mg_t5 +
                     evaluate_castling_black_mg_t5 + evaluate_castling_white_mg_t5 +
                     evaluate_rooks_black_mg_t5 + evaluate_rooks_white_mg_t5;
        sum_eg_t6 <= sum_eg_t5 +
                     evaluate_rooks_black_eg_t5 + evaluate_rooks_white_eg_t5;

        sum_mg_t7 <= sum_mg_t6;
        sum_eg_t7 <= sum_eg_t6;

        sum_mg_t8 <= sum_mg_t7 +
                     evaluate_bishops_black_mg_t7 + evaluate_bishops_white_mg_t7 +
                     evaluate_general_mg_t7;
        sum_eg_t8 <= sum_eg_t7 +
                     evaluate_bishops_black_eg_t7 + evaluate_bishops_white_eg_t7 +
                     evaluate_general_eg_t7;

        sum_mg_t9 <= sum_mg_t8 +
                     evaluate_pawns_black_mg_t8 + evaluate_pawns_white_mg_t8;
        sum_eg_t9 <= sum_eg_t8 +
                     evaluate_pawns_black_eg_t8 + evaluate_pawns_white_eg_t8;

        sum_mg_t10 <= sum_mg_t9;
        sum_eg_t10 <= sum_eg_t9;

        sum_mg_t11 <= sum_mg_t10 +
                      evaluate_tropism_black_mg_t10 + evaluate_tropism_white_mg_t10;
        sum_eg_t11 <= sum_eg_t10;
        
        score_mg_t12 <= sum_mg_t11 * phase_t11;
        score_eg_t12 <= sum_eg_t11 * (62 - phase_t11);
        score_mg_t13 <= score_mg_t12;
        score_eg_t13 <= score_eg_t12;
        score_t14 <= score_mg_t13 + score_eg_t13;
        score_t15 <= score_t14 * $signed(32'h100000 / 62);
        score_t16 <= score_t15 / $signed(32'h100000);
        eval_t17 <= score_t16;
     end

   // infer shift regs
   always @(posedge clk)
     begin
        phase_t3 <= phase_t2;
	phase_t4 <= phase_t3;
	phase_t5 <= phase_t4;
	phase_t6 <= phase_t5;
	phase_t7 <= phase_t6;
	phase_t8 <= phase_t7;
	phase_t9 <= phase_t8;
	phase_t10 <= phase_t9;
	phase_t11 <= phase_t10;
        
	insufficient_material_t8 <= insufficient_material_t7;
	insufficient_material_t9 <= insufficient_material_t8;
	insufficient_material_t10 <= insufficient_material_t9;
	insufficient_material_t11 <= insufficient_material_t10;
	insufficient_material_t12 <= insufficient_material_t11;
	insufficient_material_t13 <= insufficient_material_t12;
	insufficient_material_t14 <= insufficient_material_t13;
	insufficient_material_t15 <= insufficient_material_t14;
	insufficient_material_t16 <= insufficient_material_t15;
	insufficient_material_t17 <= insufficient_material_t16;
        
	eval_pv_flag_t2 <= eval_pv_flag_t1;
	eval_pv_flag_t3 <= eval_pv_flag_t2;
	eval_pv_flag_t4 <= eval_pv_flag_t3;
	eval_pv_flag_t5 <= eval_pv_flag_t4;
	eval_pv_flag_t6 <= eval_pv_flag_t5;
	eval_pv_flag_t7 <= eval_pv_flag_t6;
	eval_pv_flag_t8 <= eval_pv_flag_t7;
	eval_pv_flag_t9 <= eval_pv_flag_t8;
	eval_pv_flag_t10 <= eval_pv_flag_t9;
	eval_pv_flag_t11 <= eval_pv_flag_t10;
	eval_pv_flag_t12 <= eval_pv_flag_t11;
	eval_pv_flag_t13 <= eval_pv_flag_t12;
	eval_pv_flag_t14 <= eval_pv_flag_t13;
	eval_pv_flag_t15 <= eval_pv_flag_t14;
	eval_pv_flag_t16 <= eval_pv_flag_t15;
	eval_pv_flag_t17 <= eval_pv_flag_t16;
        
	bp_t1 <= bp_t0;
	bp_t2 <= bp_t1;
	bp_t3 <= bp_t2;
	bp_t4 <= bp_t3;
	bp_t5 <= bp_t4;
	bp_t6 <= bp_t5;
	bp_t7 <= bp_t6;
	bp_t8 <= bp_t7;
	bp_t9 <= bp_t8;
	bp_t10 <= bp_t9;
	bp_t11 <= bp_t10;
	bp_t12 <= bp_t11;
	bp_t13 <= bp_t12;
	bp_t14 <= bp_t13;
	bp_t15 <= bp_t14;
	bp_t16 <= bp_t15;
	bp_t17 <= bp_t16;
        
	eval_valid_t1 <= eval_valid_t0;
	eval_valid_t2 <= eval_valid_t1;
	eval_valid_t3 <= eval_valid_t2;
	eval_valid_t4 <= eval_valid_t3;
	eval_valid_t5 <= eval_valid_t4;
	eval_valid_t6 <= eval_valid_t5;
	eval_valid_t7 <= eval_valid_t6;
	eval_valid_t8 <= eval_valid_t7;
	eval_valid_t9 <= eval_valid_t8;
	eval_valid_t10 <= eval_valid_t9;
	eval_valid_t11 <= eval_valid_t10;
	eval_valid_t12 <= eval_valid_t11;
	eval_valid_t13 <= eval_valid_t12;
	eval_valid_t14 <= eval_valid_t13;
	eval_valid_t15 <= eval_valid_t14;
	eval_valid_t16 <= eval_valid_t15;
	eval_valid_t17 <= eval_valid_t16;
     end

   /* evaluate_general AUTO_TEMPLATE (
    .eval_valid_\(.*\) (@"vl-cell-name"_valid_\1[]),
    .eval_\([me]\)g_\(.*\) (@"vl-cell-name"_\1g_\2[]),
    .insufficient_material_\(.*\) (insufficient_material_\1),
    );*/
   evaluate_general #
     (
      .EVAL_WIDTH (EVAL_WIDTH)
      )
   evaluate_general
     (/*AUTOINST*/
      // Outputs
      .insufficient_material_t7         (insufficient_material_t7), // Templated
      .eval_mg_t7                       (evaluate_general_mg_t7[EVAL_WIDTH-1:0]), // Templated
      .eval_eg_t7                       (evaluate_general_eg_t7[EVAL_WIDTH-1:0]), // Templated
      .eval_valid_t7                    (evaluate_general_valid_t7), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .random_score_mask                (random_score_mask[EVAL_WIDTH-1:0]),
      .random_number                    (random_number[EVAL_WIDTH-1:0]),
      .board_valid                      (board_valid),
      .board                            (board[`BOARD_WIDTH-1:0]));

   /* evaluate_pawns AUTO_TEMPLATE (
    .eval_valid_\(.*\) (@"vl-cell-name"_valid_\1[]),
    .eval_\([me]\)g_\(.*\) (@"vl-cell-name"_\1g_\2[]),
    );*/
   evaluate_pawns #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_PAWNS (1)
      )
   evaluate_pawns_white
     (/*AUTOINST*/
      // Outputs
      .eval_mg_t8                       (evaluate_pawns_white_mg_t8[EVAL_WIDTH-1:0]), // Templated
      .eval_eg_t8                       (evaluate_pawns_white_eg_t8[EVAL_WIDTH-1:0]), // Templated
      .eval_valid_t8                    (evaluate_pawns_white_valid_t8), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .board                            (board[`BOARD_WIDTH-1:0]),
      .white_to_move                    (white_to_move),
      .white_is_attacking               (white_is_attacking[63:0]),
      .black_is_attacking               (black_is_attacking[63:0]));

   /* evaluate_pawns AUTO_TEMPLATE (
    .eval_valid_\(.*\) (@"vl-cell-name"_valid_\1[]),
    .eval_\([me]\)g_\(.*\) (@"vl-cell-name"_\1g_\2[]),
    );*/
   evaluate_pawns #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_PAWNS (0)
      )
   evaluate_pawns_black
     (/*AUTOINST*/
      // Outputs
      .eval_mg_t8                       (evaluate_pawns_black_mg_t8[EVAL_WIDTH-1:0]), // Templated
      .eval_eg_t8                       (evaluate_pawns_black_eg_t8[EVAL_WIDTH-1:0]), // Templated
      .eval_valid_t8                    (evaluate_pawns_black_valid_t8), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .board                            (board[`BOARD_WIDTH-1:0]),
      .white_to_move                    (white_to_move),
      .white_is_attacking               (white_is_attacking[63:0]),
      .black_is_attacking               (black_is_attacking[63:0]));

   /* evaluate_bishops AUTO_TEMPLATE (
    .eval_valid_\(.*\) (@"vl-cell-name"_valid_\1[]),
    .eval_\([me]\)g_\(.*\) (@"vl-cell-name"_\1g_\2[]),
    );*/
   evaluate_bishops #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_BISHOPS (1)
      )
   evaluate_bishops_white
     (/*AUTOINST*/
      // Outputs
      .eval_mg_t7                       (evaluate_bishops_white_mg_t7[EVAL_WIDTH-1:0]), // Templated
      .eval_eg_t7                       (evaluate_bishops_white_eg_t7[EVAL_WIDTH-1:0]), // Templated
      .eval_valid_t7                    (evaluate_bishops_white_valid_t7), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .board                            (board[`BOARD_WIDTH-1:0]));

   /* evaluate_bishops AUTO_TEMPLATE (
    .eval_valid_\(.*\) (@"vl-cell-name"_valid_\1[]),
    .eval_\([me]\)g_\(.*\) (@"vl-cell-name"_\1g_\2[]),
    );*/
   evaluate_bishops #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_BISHOPS (0)
      )
   evaluate_bishops_black
     (/*AUTOINST*/
      // Outputs
      .eval_mg_t7                       (evaluate_bishops_black_mg_t7[EVAL_WIDTH-1:0]), // Templated
      .eval_eg_t7                       (evaluate_bishops_black_eg_t7[EVAL_WIDTH-1:0]), // Templated
      .eval_valid_t7                    (evaluate_bishops_black_valid_t7), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .board                            (board[`BOARD_WIDTH-1:0]));

   /* evaluate_killer AUTO_TEMPLATE (
    .eval_valid_\(.*\) (@"vl-cell-name"_valid_\1[]),
    .eval_\([me]\)g_\(.*\) (@"vl-cell-name"_\1g_\2[]),
    );*/
   evaluate_killer #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .MAX_DEPTH_LOG2 (MAX_DEPTH_LOG2)
      )
   evaluate_killer
     (/*AUTOINST*/
      // Outputs
      .eval_mg_t3                       (evaluate_killer_mg_t3[EVAL_WIDTH-1:0]), // Templated
      .eval_eg_t3                       (evaluate_killer_eg_t3[EVAL_WIDTH-1:0]), // Templated
      .eval_valid_t3                    (evaluate_killer_valid_t3), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .board                            (board[`BOARD_WIDTH-1:0]),
      .white_to_move                    (white_to_move),
      .killer_ply                       (killer_ply[MAX_DEPTH_LOG2-1:0]),
      .killer_board                     (killer_board[`BOARD_WIDTH-1:0]),
      .killer_update                    (killer_update),
      .killer_clear                     (killer_clear),
      .killer_bonus0                    (killer_bonus0[EVAL_WIDTH-1:0]),
      .killer_bonus1                    (killer_bonus1[EVAL_WIDTH-1:0]));

   /* evaluate_castling AUTO_TEMPLATE (
    .eval_valid_\(.*\) (@"vl-cell-name"_valid_\1[]),
    .eval_\([me]\)g_\(.*\) (@"vl-cell-name"_\1g_\2[]),
    );*/
   evaluate_castling #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_CASTLING (1)
      )
   evaluate_castling_white
     (/*AUTOINST*/
      // Outputs
      .eval_mg_t5                       (evaluate_castling_white_mg_t5[EVAL_WIDTH-1:0]), // Templated
      .eval_valid_t5                    (evaluate_castling_white_valid_t5), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .board                            (board[`BOARD_WIDTH-1:0]),
      .castle_mask                      (castle_mask[3:0]),
      .castle_mask_orig                 (castle_mask_orig[3:0]));

   /* evaluate_castling AUTO_TEMPLATE (
    .eval_valid_\(.*\) (@"vl-cell-name"_valid_\1[]),
    .eval_\([me]\)g_\(.*\) (@"vl-cell-name"_\1g_\2[]),
    );*/
   evaluate_castling #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_CASTLING (0)
      )
   evaluate_castling_black
     (/*AUTOINST*/
      // Outputs
      .eval_mg_t5                       (evaluate_castling_black_mg_t5[EVAL_WIDTH-1:0]), // Templated
      .eval_valid_t5                    (evaluate_castling_black_valid_t5), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .board                            (board[`BOARD_WIDTH-1:0]),
      .castle_mask                      (castle_mask[3:0]),
      .castle_mask_orig                 (castle_mask_orig[3:0]));

   /* evaluate_rooks AUTO_TEMPLATE (
    .eval_valid_\(.*\) (@"vl-cell-name"_valid_\1[]),
    .eval_\([me]\)g_\(.*\) (@"vl-cell-name"_\1g_\2[]),
    );*/
   evaluate_rooks #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_ROOKS (1)
      )
   evaluate_rooks_white
     (/*AUTOINST*/
      // Outputs
      .eval_mg_t5                       (evaluate_rooks_white_mg_t5[EVAL_WIDTH-1:0]), // Templated
      .eval_eg_t5                       (evaluate_rooks_white_eg_t5[EVAL_WIDTH-1:0]), // Templated
      .eval_valid_t5                    (evaluate_rooks_white_valid_t5), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .board                            (board[`BOARD_WIDTH-1:0]));

   /* evaluate_rooks AUTO_TEMPLATE (
    .eval_valid_\(.*\) (@"vl-cell-name"_valid_\1[]),
    .eval_\([me]\)g_\(.*\) (@"vl-cell-name"_\1g_\2[]),
    );*/
   evaluate_rooks #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE_ROOKS (0)
      )
   evaluate_rooks_black
     (/*AUTOINST*/
      // Outputs
      .eval_mg_t5                       (evaluate_rooks_black_mg_t5[EVAL_WIDTH-1:0]), // Templated
      .eval_eg_t5                       (evaluate_rooks_black_eg_t5[EVAL_WIDTH-1:0]), // Templated
      .eval_valid_t5                    (evaluate_rooks_black_valid_t5), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .board                            (board[`BOARD_WIDTH-1:0]));

   /* evaluate_tropism AUTO_TEMPLATE (
    .eval_valid_\(.*\) (@"vl-cell-name"_valid_\1[]),
    .eval_\([me]\)g_\(.*\) (@"vl-cell-name"_\1g_\2[]),
    );*/
   evaluate_tropism #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE (1)
      )
   evaluate_tropism_white
     (/*AUTOINST*/
      // Outputs
      .eval_mg_t10                      (evaluate_tropism_white_mg_t10[EVAL_WIDTH-1:0]), // Templated
      .eval_valid_t10                   (evaluate_tropism_white_valid_t10), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .castle_mask                      (castle_mask[3:0]),
      .board                            (board[`BOARD_WIDTH-1:0]));

   /* evaluate_tropism AUTO_TEMPLATE (
    .eval_valid_\(.*\) (@"vl-cell-name"_valid_\1[]),
    .eval_\([me]\)g_\(.*\) (@"vl-cell-name"_\1g_\2[]),
    );*/
   evaluate_tropism #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .WHITE (0)
      )
   evaluate_tropism_black
     (/*AUTOINST*/
      // Outputs
      .eval_mg_t10                      (evaluate_tropism_black_mg_t10[EVAL_WIDTH-1:0]), // Templated
      .eval_valid_t10                   (evaluate_tropism_black_valid_t10), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .castle_mask                      (castle_mask[3:0]),
      .board                            (board[`BOARD_WIDTH-1:0]));

   /* evaluate_pv AUTO_TEMPLATE (
    .eval_valid_\(.*\) (eval_pv_valid_\1),
    .eval_pv_flag_\(.*\) (eval_pv_flag_\1),
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
      .eval_pv_flag_t1                  (eval_pv_flag_t1),       // Templated
      .eval_valid_t1                    (eval_pv_valid_t1),      // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .uci_in                           (uci_in[UCI_WIDTH-1:0]),
      .pv_ply                           (killer_ply[MAX_DEPTH_LOG2-1:0]), // Templated
      .pv_ctrl_in                       (pv_ctrl_in[31:0]));

   /* popcount AUTO_TEMPLATE (
    .population (occupied_count_t1[]),
    .x0 (occupied_t0[]),
    );*/
   popcount popcount_occupied
     (/*AUTOINST*/
      // Outputs
      .population                       (occupied_count_t1[5:0]), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (occupied_t0[63:0]));     // Templated

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

