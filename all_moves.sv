// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

module all_moves #
  (
   parameter MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS),
   parameter EVAL_WIDTH = 0,
   parameter HALF_MOVE_WIDTH = 0,
   parameter UCI_WIDTH = 4 + 6 + 6,
   parameter MAX_DEPTH_LOG2 = 0
   )
   (
    input                                clk,
    input                                reset,

    input [EVAL_WIDTH - 1:0]             random_score_mask,
    input [EVAL_WIDTH - 1:0]             random_number,

    input [31:0]                         algorithm_enable,

    input                                board_valid_in,
    input [`BOARD_WIDTH - 1:0]           board_in,
    input                                white_to_move_in,
    input [3:0]                          castle_mask_in,
    input [3:0]                          en_passant_col_in,
    input [HALF_MOVE_WIDTH - 1:0]        half_move_in,
    input [3:0]                          castle_mask_orig_in,

    input [MAX_DEPTH_LOG2 - 1:0]         killer_ply_in,
    input [`BOARD_WIDTH - 1:0]           killer_board_in,
    input                                killer_update_in,
    input                                killer_clear_in,
    input signed [EVAL_WIDTH - 1:0]      killer_bonus0_in,
    input signed [EVAL_WIDTH - 1:0]      killer_bonus1_in,

    input [31:0]                         pv_ctrl_in,

    input [MAX_POSITIONS_LOG2 - 1:0]     am_move_index,
    input                                am_clear_moves,

    output reg                           initial_mate = 0,
    output reg                           initial_stalemate = 0,
    output reg signed [EVAL_WIDTH - 1:0] initial_eval,
    output reg                           initial_fifty_move = 0,
    output reg                           initial_insufficient_material = 0,
    output reg                           initial_board_check,

    output reg                           am_idle,
    output reg                           am_moves_ready,
    output                               am_move_ready,
    output [MAX_POSITIONS_LOG2 - 1:0]    am_move_count,

    output [`BOARD_WIDTH - 1:0]          board_out,
    output                               white_to_move_out,
    output [3:0]                         castle_mask_out,
    output [3:0]                         en_passant_col_out,
    output                               capture_out,
    output                               pv_out,
    output                               white_in_check_out,
    output                               black_in_check_out,
    output [63:0]                        white_is_attacking_out,
    output [63:0]                        black_is_attacking_out,
    output signed [EVAL_WIDTH - 1:0]     eval_out,
    output [HALF_MOVE_WIDTH - 1:0]       half_move_out,
    output                               fifty_move_out,
    output [UCI_WIDTH - 1:0]             uci_out,
    output                               insufficient_material_out,

    output [31:0]                        all_moves_bram_addr,
    output [511:0]                       all_moves_bram_din,
    output [63:0]                        all_moves_bram_we
    );

   // board + castle mask + en passant col + color to move
   localparam INITIAL_WIDTH = `BOARD_WIDTH + 4 + 4 + 1;
   // UCI, initial width + capture + pawn adv (to zero-out half move)
   localparam RAM_WIDTH = UCI_WIDTH + INITIAL_WIDTH + 1 + 1;
   localparam LEGAL_RAM_WIDTH = 451; // to verify, increase to excessively large number then look for x's on bus in sim

   reg [RAM_WIDTH - 1:0]                 move_ram [0:`MAX_POSITIONS - 1];
   reg [RAM_WIDTH - 1:0]                 ram_rd_data;
   reg                                   ram_wr_addr_init;
   reg [MAX_POSITIONS_LOG2 - 1:0]        ram_wr_addr, ram_rd_addr;
   reg [$clog2(`BOARD_WIDTH) - 1:0]      idx [0:7][0:7];
   reg [`PIECE_WIDTH - 1:0]              piece;
   reg [`BOARD_WIDTH - 1:0]              board;
   reg                                   white_to_move;
   reg [3:0]                             castle_mask;
   reg [3:0]                             en_passant_col, en_passant_col_r;
   reg [HALF_MOVE_WIDTH - 1:0]           half_move;
   reg [3:0]                             castle_mask_orig;

   reg                                   legal_ram_wr_addr_init;

   reg [`BOARD_WIDTH - 1:0]              board_ram_wr;
   reg [3:0]                             en_passant_col_ram_wr;
   reg [3:0]                             castle_mask_ram_wr;
   reg                                   white_to_move_ram_wr;
   reg                                   capture_ram_wr;
   reg                                   pawn_zero_half_move_ram_wr;
   reg [3:0]                             uci_promotion_ram_wr;
   reg [2:0]                             uci_from_row_ram_wr, uci_from_col_ram_wr;
   reg [2:0]                             uci_to_row_ram_wr, uci_to_col_ram_wr;
   reg                                   ram_wr;

   reg [`BOARD_WIDTH - 1:0]              legal_board_ram_wr;
   reg [3:0]                             legal_en_passant_col_ram_wr;
   reg [3:0]                             legal_castle_mask_ram_wr;
   reg                                   legal_white_to_move_ram_wr;
   reg                                   legal_capture_ram_wr;
   reg [HALF_MOVE_WIDTH - 1:0]           legal_half_move_ram_wr;
   reg                                   legal_fifty_move_ram_wr;
   reg                                   legal_white_in_check_ram_wr;
   reg                                   legal_black_in_check_ram_wr;
   reg [63:0]                            legal_white_is_attacking_ram_wr;
   reg [63:0]                            legal_black_is_attacking_ram_wr;
   reg [UCI_WIDTH - 1:0]                 legal_uci_ram_wr;
   reg                                   legal_ram_wr = 0;

   reg [`BOARD_WIDTH - 1:0]              attack_test_board;
   reg [3:0]                             attack_test_en_passant_col;
   reg [3:0]                             attack_test_castle_mask;
   reg                                   attack_test_white_to_move;
   reg                                   attack_test_capture;
   reg                                   attack_pawn_zero_half_move;
   reg [UCI_WIDTH - 1:0]                 attack_uci;

   reg                                   initial_evaluation_complete = 0;

   reg [`BOARD_WIDTH - 1:0]              initial_evaluate_board, legal_evaluate_board, evaluate_board_r;
   reg                                   initial_attack_go = 0, legal_attack_go = 0;
   reg                                   initial_evaluate_go = 0, legal_evaluate_go = 0, evaluate_go_r;
   reg [UCI_WIDTH - 1:0]                 initial_evaluate_uci, legal_evaluate_uci, evaluate_uci_r;
   reg [3:0]                             initial_evaluate_castle_mask, legal_evaluate_castle_mask, evaluate_castle_mask_r;
   reg                                   initial_evaluate_white_to_move, legal_evaluate_white_to_move, evaluate_white_to_move_r;

   reg                                   initial_clear_attack = 0, legal_clear_attack = 0;

   reg signed [3:0]                      row, col;
   reg signed [3:0]                      col_r, row_r; // one clock delayed, for timing/fanout, be careful using this

   reg signed [1:0]                      slider_offset_col [`PIECE_QUEN:`PIECE_BISH][0:7];
   reg signed [1:0]                      slider_offset_row [`PIECE_QUEN:`PIECE_BISH][0:7];
   reg [3:0]                             slider_offset_count [`PIECE_QUEN:`PIECE_BISH];
   reg [3:0]                             slider_index;
   reg signed [4:0]                      slider_row, slider_col;

   reg signed [2:0]                      discrete_offset_col[`PIECE_KNIT:`PIECE_KING][0:7];
   reg signed [2:0]                      discrete_offset_row[`PIECE_KNIT:`PIECE_KING][0:7];
   reg [3:0]                             discrete_index;
   reg signed [4:0]                      discrete_row, discrete_col;

   reg signed [1:0]                      pawn_advance [0:1];
   reg signed [4:0]                      pawn_promote_row [0:1];
   reg signed [4:0]                      pawn_init_row [0:1];
   reg signed [4:0]                      pawn_row_adv1, pawn_col_adv1;
   reg signed [4:0]                      pawn_row_adv2, pawn_col_adv2;
   reg signed [4:0]                      pawn_row_cap_left, pawn_col_cap_left;
   reg signed [4:0]                      pawn_row_cap_right, pawn_col_cap_right;
   reg [`PIECE_WIDTH - 1:0]              pawn_promotions [0:3];
   reg [2:0]                             pawn_adv1_mask;
   reg                                   pawn_adv2;
   reg [1:0]                             pawn_en_passant_mask;
   reg signed [4:0]                      pawn_en_passant_row [0:1];
   reg                                   pawn_en_passant_count;
   reg [1:0]                             pawn_move_count;
   reg [1:0]                             pawn_promotion_count;
   reg                                   pawn_do_init;
   reg                                   pawn_do_en_passant;
   reg                                   pawn_do_promote;

   reg [1:0]                             castle_short_legal;
   reg [1:0]                             castle_long_legal;
   reg [2:0]                             castle_row [0:1];

   reg                                   legal_sort_clear = 0;
   reg                                   legal_sort_start = 0;

   reg [MAX_POSITIONS_LOG2 - 1:0]        am_move_index_s0, am_move_index_s1;

   reg                                   all_generated_moves_complete = 0;
   reg                                   legal_eval_done = 0;
   reg [MAX_POSITIONS_LOG2 - 1:0]        eval_input_count;

   reg [`BOARD_WIDTH - 1:0]              presort_board_out;
   reg                                   presort_white_to_move_out;
   reg [3:0]                             presort_castle_mask_out;
   reg [3:0]                             presort_en_passant_col_out;
   reg                                   presort_capture_out;
   reg                                   presort_pv_out;
   reg                                   presort_white_in_check_out;
   reg                                   presort_black_in_check_out;
   reg [63:0]                            presort_white_is_attacking_out;
   reg [63:0]                            presort_black_is_attacking_out;
   reg signed [EVAL_WIDTH - 1:0]         presort_eval_out;
   reg [HALF_MOVE_WIDTH - 1:0]           presort_half_move_out;
   reg                                   presort_fifty_move_out;
   reg [UCI_WIDTH - 1:0]                 presort_uci_out;
   reg                                   presort_insufficient_material_out;

   reg [63:0]                            square_active;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [31:0]          all_moves_bram_intermediate_addr;// From move_sort_legal of move_sort.v
   wire [511:0]         all_moves_bram_intermediate_din;// From move_sort_legal of move_sort.v
   wire [63:0]          all_moves_bram_intermediate_we;// From move_sort_legal of move_sort.v
   wire                 black_in_check;         // From board_attack of board_attack.v
   wire [63:0]          black_is_attacking;     // From board_attack of board_attack.v
   wire signed [EVAL_WIDTH-1:0] eval;           // From evaluate of evaluate.v
   wire [LEGAL_RAM_WIDTH-1:0] eval_bypass_out;  // From evaluate of evaluate.v
   wire                 eval_pv_flag;           // From evaluate of evaluate.v
   wire                 eval_valid;             // From evaluate of evaluate.v
   wire                 insufficient_material;  // From evaluate of evaluate.v
   wire                 is_attacking_done;      // From board_attack of board_attack.v
   wire [LEGAL_RAM_WIDTH-1:0] legal_ram_rd_data;// From move_sort_legal of move_sort.v
   wire [MAX_POSITIONS_LOG2-1:0] legal_ram_wr_addr;// From move_sort_legal of move_sort.v
   wire                 legal_sort_complete;    // From move_sort_legal of move_sort.v
   wire                 white_in_check;         // From board_attack of board_attack.v
   wire [63:0]          white_is_attacking;     // From board_attack of board_attack.v
   // End of automatics

   integer                               i, x, y, ri, s, sy, sx;

   wire signed [4:0]                     pawn_adv1_row [0:2];
   wire signed [4:0]                     pawn_adv1_col [0:2];
   wire signed [4:0]                     pawn_enp_row[0:1];

   wire [`BOARD_WIDTH - 1:0]             all_moves_bram_board_out;
   wire [31:0]                           all_moves_bram_board_out_debug = all_moves_bram_board_out[31:0];
   wire                                  all_moves_bram_white_to_move_out;
   wire [3:0]                            all_moves_bram_castle_mask_out;
   wire [3:0]                            all_moves_bram_en_passant_col_out;
   wire                                  all_moves_bram_capture_out;
   wire                                  all_moves_bram_pv_out;
   wire                                  all_moves_bram_white_in_check_out;
   wire                                  all_moves_bram_black_in_check_out;
   wire [63:0]                           all_moves_bram_white_is_attacking_out;
   wire [63:0]                           all_moves_bram_black_is_attacking_out;
   wire signed [EVAL_WIDTH - 1:0]        all_moves_bram_eval_out;
   wire signed [EVAL_WIDTH - 1:0]        all_moves_bram_eval_out_debug = all_moves_bram_eval_out;
   wire [HALF_MOVE_WIDTH - 1:0]          all_moves_bram_half_move_out;
   wire                                  all_moves_bram_fifty_move_out;
   wire [UCI_WIDTH - 1:0]                all_moves_bram_uci_out;
   wire                                  all_moves_bram_insufficient_material_out;

   wire [`BOARD_WIDTH - 1:0]             ebp_board_out;
   wire                                  ebp_white_to_move_out;
   wire [3:0]                            ebp_castle_mask_out;
   wire [3:0]                            ebp_en_passant_col_out;
   wire                                  ebp_capture_out;
   wire                                  ebp_pv_out;
   wire                                  ebp_white_in_check_out;
   wire                                  ebp_black_in_check_out;
   wire [63:0]                           ebp_white_is_attacking_out;
   wire [63:0]                           ebp_black_is_attacking_out;
   wire signed [EVAL_WIDTH - 1:0]        ebp_eval_out;
   wire [HALF_MOVE_WIDTH - 1:0]          ebp_half_move_out;
   wire                                  ebp_fifty_move_out;
   wire [UCI_WIDTH - 1:0]                ebp_uci_out;
   wire                                  ebp_insufficient_material_out;

   wire                                  black_to_move = ~white_to_move;

   wire                                  clear_attack = initial_evaluation_complete ? legal_clear_attack : initial_clear_attack;

   wire [LEGAL_RAM_WIDTH - 1:0]          legal_bypass = {1'b0, // insufficient
							 legal_uci_ram_wr[UCI_WIDTH - 1:0],
                                                         legal_fifty_move_ram_wr,
							 legal_half_move_ram_wr[HALF_MOVE_WIDTH - 1:0],
                                                         legal_white_is_attacking_ram_wr[63:0],
							 legal_black_is_attacking_ram_wr[63:0],
                                                         legal_en_passant_col_ram_wr[3:0],
							 legal_castle_mask_ram_wr[3:0],
                                                         legal_board_ram_wr[`BOARD_WIDTH - 1:0],
                                                         legal_white_to_move_ram_wr,
                                                         1'b0, // pv flag
                                                         legal_capture_ram_wr,
                                                         legal_white_in_check_ram_wr,
                                                         legal_black_in_check_ram_wr,
                                                         {EVAL_WIDTH{1'b0}}}; // eval

   wire [LEGAL_RAM_WIDTH - 1:0]          legal_ram_wr_data = {presort_insufficient_material_out,
                                                              presort_uci_out[UCI_WIDTH - 1:0],
                                                              presort_fifty_move_out,
                                                              presort_half_move_out[HALF_MOVE_WIDTH - 1:0],
                                                              presort_white_is_attacking_out[63:0],
                                                              presort_black_is_attacking_out[63:0],
                                                              presort_en_passant_col_out[3:0],
                                                              presort_castle_mask_out[3:0],
                                                              presort_board_out[`BOARD_WIDTH - 1:0],
                                                              presort_white_to_move_out,
                                                              presort_pv_out,
                                                              presort_capture_out,
                                                              presort_white_in_check_out,
                                                              presort_black_in_check_out,
                                                              presort_eval_out[EVAL_WIDTH - 1:0]};

   assign {insufficient_material_out,
	   uci_out[UCI_WIDTH - 1:0],
           fifty_move_out,
	   half_move_out[HALF_MOVE_WIDTH - 1:0],
	   white_is_attacking_out[63:0],
	   black_is_attacking_out[63:0],
           en_passant_col_out[3:0],
	   castle_mask_out[3:0],
           board_out[`BOARD_WIDTH - 1:0],
	   white_to_move_out,
           pv_out,
	   capture_out,
	   white_in_check_out,
	   black_in_check_out,
           eval_out[EVAL_WIDTH - 1:0]} = legal_ram_rd_data;

   assign {ebp_insufficient_material_out, // dummy, ignored
           ebp_uci_out[UCI_WIDTH - 1:0],
           ebp_fifty_move_out,
           ebp_half_move_out[HALF_MOVE_WIDTH - 1:0],
           ebp_white_is_attacking_out[63:0],
           ebp_black_is_attacking_out[63:0],
           ebp_en_passant_col_out[3:0],
           ebp_castle_mask_out[3:0],
           ebp_board_out[`BOARD_WIDTH - 1:0],
           ebp_white_to_move_out,
           ebp_pv_out, // dummy, ignored
           ebp_capture_out,
           ebp_white_in_check_out,
           ebp_black_in_check_out,
           ebp_eval_out[EVAL_WIDTH - 1:0] // dummy, ignored
           } = eval_bypass_out;

   assign {all_moves_bram_insufficient_material_out,
	   all_moves_bram_uci_out[UCI_WIDTH - 1:0],
           all_moves_bram_fifty_move_out,
	   all_moves_bram_half_move_out[HALF_MOVE_WIDTH - 1:0],
	   all_moves_bram_white_is_attacking_out[63:0],
	   all_moves_bram_black_is_attacking_out[63:0],
           all_moves_bram_en_passant_col_out[3:0],
	   all_moves_bram_castle_mask_out[3:0],
           all_moves_bram_board_out[`BOARD_WIDTH - 1:0],
	   all_moves_bram_white_to_move_out,
           all_moves_bram_pv_out,
	   all_moves_bram_capture_out,
	   all_moves_bram_white_in_check_out,
	   all_moves_bram_black_in_check_out,
           all_moves_bram_eval_out[EVAL_WIDTH - 1:0]} = all_moves_bram_intermediate_din;

   wire signed [31:0]                    all_moves_bram_eval_out_signed = $signed(all_moves_bram_eval_out[EVAL_WIDTH - 1:0]);

   assign all_moves_bram_we = all_moves_bram_intermediate_we;
   assign all_moves_bram_addr = all_moves_bram_intermediate_addr;

   // C-friendly data alignments

   localparam NEXTZ = 0; // byte 0, word 0, dword 0
   assign all_moves_bram_din[NEXTZ+:256] = all_moves_bram_board_out[`BOARD_WIDTH - 1:0];

   localparam NEXTA = NEXTZ + 256; // byte 32, word 8, dword 4
   assign all_moves_bram_din[NEXTA+:32] = all_moves_bram_eval_out_signed[31:0];
   localparam NEXTB = NEXTA + 32; // byte 36, word 9
   assign all_moves_bram_din[NEXTB+:16] = all_moves_bram_uci_out[UCI_WIDTH - 1:0];
   localparam NEXTC = NEXTB + 16; // byte 38
   assign all_moves_bram_din[NEXTC+:10] = all_moves_bram_half_move_out[HALF_MOVE_WIDTH - 1:0];
   localparam NEXTD = NEXTC + 10; // padding
   assign all_moves_bram_din[NEXTD+:6] = 6'b0;

   localparam NEXTE = NEXTD + 6; // byte 40, word 10, dword 5
   assign all_moves_bram_din[NEXTE + 0] = all_moves_bram_white_to_move_out;
   assign all_moves_bram_din[NEXTE + 1] = all_moves_bram_black_in_check_out;
   assign all_moves_bram_din[NEXTE + 2] = all_moves_bram_white_in_check_out;
   assign all_moves_bram_din[NEXTE + 3] = all_moves_bram_capture_out;
   assign all_moves_bram_din[NEXTE + 4] = all_moves_bram_pv_out;
   assign all_moves_bram_din[NEXTE + 5] = 0;
   assign all_moves_bram_din[NEXTE + 6] = all_moves_bram_fifty_move_out;
   assign all_moves_bram_din[NEXTE + 7] = all_moves_bram_insufficient_material_out;
   localparam NEXTF = NEXTE + 8; // byte 41
   assign all_moves_bram_din[NEXTF+:4] = all_moves_bram_en_passant_col_out[3:0];
   localparam NEXTG = NEXTF + 4; // byte 41, mask out 4 bits
   assign all_moves_bram_din[NEXTG+:4] = all_moves_bram_castle_mask_out[3:0];

   localparam NEXTH = NEXTG + 4; // bit 336, padding
   assign all_moves_bram_din[511:NEXTH] = 0;

   assign am_move_count = legal_ram_wr_addr;
   assign am_move_ready = am_move_index == am_move_index_s1;

   initial
     begin
        for (y = 0; y < 8; y = y + 1)
          begin
             ri = y * `SIDE_WIDTH;
             for (x = 0; x < 8; x = x + 1)
               idx[y][x] = ri + x * `PIECE_WIDTH;
          end

        pawn_advance[0] = -1; // black to move
        pawn_advance[1] =  1; // white to move
        pawn_promote_row[0] = 1; // black to move
        pawn_promote_row[1] = 6; // white to move
        pawn_init_row[0] = 6; // black to move
        pawn_init_row[1] = 1; // white to move
        pawn_en_passant_row[0] = 3; // black to move
        pawn_en_passant_row[1] = 4; // white to move

        pawn_promotions[0] = `PIECE_QUEN;
        pawn_promotions[1] = `PIECE_BISH;
        pawn_promotions[2] = `PIECE_ROOK;
        pawn_promotions[3] = `PIECE_KNIT;

        // avoid driver warnings in vivado
        for (ri = `PIECE_QUEN; ri <= `PIECE_BISH; ri = ri + 1)
          for (x = 0; x < 8; x = x + 1)
            begin
               slider_offset_row[ri][x] = 0;
               slider_offset_col[ri][x] = 0;
            end

        slider_offset_count[`PIECE_QUEN] = 8;
        ri = 0;
        for (y = -1; y <= +1; y = y + 1)
          for (x = -1; x <= +1; x = x + 1)
            if (! (y == 0 && x == 0))
              begin
                 slider_offset_row[`PIECE_QUEN][ri] = y;
                 slider_offset_col[`PIECE_QUEN][ri] = x;
                 ri = ri + 1;
              end

        slider_offset_count[`PIECE_ROOK] = 4;
        slider_offset_row[`PIECE_ROOK][0] = 0; slider_offset_col[`PIECE_ROOK][0] = +1;
        slider_offset_row[`PIECE_ROOK][1] = 0; slider_offset_col[`PIECE_ROOK][1] = -1;
        slider_offset_row[`PIECE_ROOK][2] = +1; slider_offset_col[`PIECE_ROOK][2] = 0;
        slider_offset_row[`PIECE_ROOK][3] = -1; slider_offset_col[`PIECE_ROOK][3] = 0;

        slider_offset_count[`PIECE_BISH] = 4;
        slider_offset_row[`PIECE_BISH][0] = +1; slider_offset_col[`PIECE_BISH][0] = +1;
        slider_offset_row[`PIECE_BISH][1] = +1; slider_offset_col[`PIECE_BISH][1] = -1;
        slider_offset_row[`PIECE_BISH][2] = -1; slider_offset_col[`PIECE_BISH][2] = +1;
        slider_offset_row[`PIECE_BISH][3] = -1; slider_offset_col[`PIECE_BISH][3] = -1;

        discrete_offset_row[`PIECE_KNIT][0] = -2; discrete_offset_col[`PIECE_KNIT][0] = -1;
        discrete_offset_row[`PIECE_KNIT][1] = -1; discrete_offset_col[`PIECE_KNIT][1] = -2;
        discrete_offset_row[`PIECE_KNIT][2] =  1; discrete_offset_col[`PIECE_KNIT][2] = -2;
        discrete_offset_row[`PIECE_KNIT][3] =  2; discrete_offset_col[`PIECE_KNIT][3] = -1;
        discrete_offset_row[`PIECE_KNIT][4] =  2; discrete_offset_col[`PIECE_KNIT][4] =  1;
        discrete_offset_row[`PIECE_KNIT][5] =  1; discrete_offset_col[`PIECE_KNIT][5] =  2;
        discrete_offset_row[`PIECE_KNIT][6] = -1; discrete_offset_col[`PIECE_KNIT][6] =  2;
        discrete_offset_row[`PIECE_KNIT][7] = -2; discrete_offset_col[`PIECE_KNIT][7] =  1;

        ri = 0;
        for (y = -1; y <= +1; y = y + 1)
          for (x = -1; x <= +1; x = x + 1)
            if (! (y == 0 && x == 0))
              begin
                 discrete_offset_row[`PIECE_KING][ri] = y;
                 discrete_offset_col[`PIECE_KING][ri] = x;
                 ri = ri + 1;
              end

        castle_row[0] = 7; // black to move
        castle_row[1] = 0; // white to move
     end

   // merge evaluation data into position information, write to sort ram
   always @(posedge clk)
     begin
        legal_ram_wr <= eval_valid && initial_evaluation_complete;

        {presort_insufficient_material_out,
         presort_uci_out[UCI_WIDTH - 1:0],
         presort_fifty_move_out,
         presort_half_move_out[HALF_MOVE_WIDTH - 1:0],
         presort_white_is_attacking_out[63:0],
         presort_black_is_attacking_out[63:0],
         presort_en_passant_col_out[3:0],
         presort_castle_mask_out[3:0],
         presort_board_out[`BOARD_WIDTH - 1:0],
         presort_white_to_move_out,
         presort_pv_out,
         presort_capture_out,
         presort_white_in_check_out,
         presort_black_in_check_out,
         presort_eval_out[EVAL_WIDTH - 1:0]} <=
                                               {insufficient_material, // from evaluation
                                                ebp_uci_out[UCI_WIDTH - 1:0],
                                                ebp_fifty_move_out,
                                                ebp_half_move_out[HALF_MOVE_WIDTH - 1:0],
                                                ebp_white_is_attacking_out[63:0],
                                                ebp_black_is_attacking_out[63:0],
                                                ebp_en_passant_col_out[3:0],
                                                ebp_castle_mask_out[3:0],
                                                ebp_board_out[`BOARD_WIDTH - 1:0],
                                                ebp_white_to_move_out,
                                                eval_pv_flag, // from evaluation
                                                ebp_capture_out,
                                                ebp_white_in_check_out,
                                                ebp_black_in_check_out,
                                                eval[EVAL_WIDTH - 1:0]}; // from evaluation
     end

   always @(posedge clk)
     begin
        ram_rd_data <= move_ram[ram_rd_addr];
        if (ram_wr_addr_init)
          ram_wr_addr <= 0;
        if (ram_wr)
          begin
             move_ram[ram_wr_addr] <= {uci_promotion_ram_wr, uci_to_row_ram_wr, uci_to_col_ram_wr, uci_from_row_ram_wr, uci_from_col_ram_wr,
                                       pawn_zero_half_move_ram_wr, capture_ram_wr, en_passant_col_ram_wr,
                                       castle_mask_ram_wr, white_to_move_ram_wr, board_ram_wr};
             ram_wr_addr <= ram_wr_addr + 1;
          end
     end

   always @(posedge clk)
     begin
        am_move_index_s0 <= am_move_index;
        am_move_index_s1 <= am_move_index_s0;
     end

   assign pawn_enp_row[0] = pawn_row_cap_left;
   assign pawn_enp_row[1] = pawn_row_cap_right;

   assign pawn_adv1_row[0] = pawn_row_cap_left;
   assign pawn_adv1_row[1] = pawn_row_adv1;
   assign pawn_adv1_row[2] = pawn_row_cap_right;
   assign pawn_adv1_col[0] = pawn_col_cap_left;
   assign pawn_adv1_col[1] = pawn_col_adv1;
   assign pawn_adv1_col[2] = pawn_col_cap_right;

   wire [`BOARD_WIDTH - 1:0] attack_board = initial_evaluation_complete ? legal_evaluate_board : initial_evaluate_board;
   wire                      attack_go = initial_evaluation_complete ? legal_attack_go : initial_attack_go;

   always @(posedge clk)
     begin
        piece <= board[idx[row][col]+:`PIECE_WIDTH];

        col_r <= col;
        row_r <= row;

        en_passant_col_r <= en_passant_col;

        white_to_move_ram_wr <= ~white_to_move;

        if (initial_evaluation_complete)
          begin
             evaluate_go_r <= legal_evaluate_go;
             evaluate_board_r <= legal_evaluate_board;
             evaluate_uci_r <= legal_evaluate_uci;
             evaluate_castle_mask_r <= legal_evaluate_castle_mask;
             evaluate_white_to_move_r <= legal_evaluate_white_to_move;
          end
        else
          begin
             evaluate_go_r <= initial_evaluate_go;
             evaluate_board_r <= initial_evaluate_board;
             evaluate_uci_r <= initial_evaluate_uci;
             evaluate_castle_mask_r <= initial_evaluate_castle_mask;
             evaluate_white_to_move_r <= initial_evaluate_white_to_move;
          end

        // free-run these for timing, only valid when used in states
        pawn_row_adv1 <= row_r + pawn_advance[white_to_move];
        pawn_col_adv1 <= col_r;
        pawn_row_adv2 <= row_r + pawn_advance[white_to_move] * 2;
        pawn_col_adv2 <= col_r;
        pawn_row_cap_left <= row_r + pawn_advance[white_to_move];
        pawn_col_cap_left <= col_r - 1;
        pawn_row_cap_right <= row_r + pawn_advance[white_to_move];
        pawn_col_cap_right <= col_r + 1;
        for (i = 0; i < 4; i = i + 1)
          pawn_promotions[i][`BLACK_BIT] <= black_to_move;

        pawn_adv1_mask[0] <= pawn_col_cap_left >= 0 &&
                             board[idx[pawn_row_cap_left[2:0]][pawn_col_cap_left[2:0]]+:`PIECE_WIDTH] != `EMPTY_POSN && // can't be empty, and
                             board[idx[pawn_row_cap_left[2:0]][pawn_col_cap_left[2:0]] + `BLACK_BIT] != black_to_move; // contains opponent's piece
        pawn_adv1_mask[1] <= board[idx[pawn_row_adv1[2:0]][pawn_col_adv1[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN;
        pawn_adv1_mask[2] <= pawn_col_cap_right <= 7 &&
                             board[idx[pawn_row_cap_right[2:0]][pawn_col_cap_right[2:0]]+:`PIECE_WIDTH] != `EMPTY_POSN && // can't be empty, and
                             board[idx[pawn_row_cap_right[2:0]][pawn_col_cap_right[2:0]] + `BLACK_BIT] != black_to_move; // contains opponent's piece
        pawn_adv2 <= board[idx[pawn_row_adv1[2:0]][pawn_col_adv1[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                     board[idx[pawn_row_adv2[2:0]][pawn_col_adv2[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN;

        pawn_en_passant_mask[0] <= en_passant_col_r[`EN_PASSANT_VALID_BIT] &&
                                   pawn_col_cap_left >= 0 &&
                                   en_passant_col_r[2:0] == pawn_col_cap_left[2:0];
        pawn_en_passant_mask[1] <= en_passant_col_r[`EN_PASSANT_VALID_BIT] &&
                                   pawn_col_cap_right <= 7 &&
                                   en_passant_col_r[2:0] == pawn_col_cap_right[2:0];
        pawn_do_init <= row_r == pawn_init_row[white_to_move];
        pawn_do_en_passant <= row_r == pawn_en_passant_row[white_to_move];
        pawn_do_promote <= row_r == pawn_promote_row[white_to_move];
     end

   localparam STATE_IDLE = 0;
   localparam STATE_INIT_WAIT_ATTACK = 1;
   localparam STATE_INIT_WAIT_EVAL = 2;
   localparam STATE_INIT = 3;
   localparam STATE_INIT_WS = 4;
   localparam STATE_FIND_PIECE = 5;
   localparam STATE_DO_SQUARE = 6;
   localparam STATE_SLIDER_INIT = 7;
   localparam STATE_SLIDER = 8;
   localparam STATE_DISCRETE_INIT = 9;
   localparam STATE_DISCRETE = 10;
   localparam STATE_PAWN_INIT_0 = 11;
   localparam STATE_PAWN_INIT_1 = 12;
   localparam STATE_PAWN_ROW_1 = 13;
   localparam STATE_PAWN_ROW_4 = 14;
   localparam STATE_PAWN_ROW_6 = 15;
   localparam STATE_PAWN_ADVANCE = 16;
   localparam STATE_NEXT = 17;
   localparam STATE_CASTLE_SHORT = 18;
   localparam STATE_CASTLE_LONG = 19;
   localparam STATE_ALL_MOVES_DONE = 20;
   localparam STATE_START_LEGAL = 21;
   localparam STATE_WAIT_LEGAL = 22;
   localparam STATE_DONE = 23;

   reg [4:0] state = STATE_IDLE;

   always @(posedge clk)
     if (reset)
       begin
          state <= STATE_IDLE;
          all_generated_moves_complete <= 0;
          initial_evaluation_complete <= 0;
          ram_wr_addr_init <= 1;
       end
     else
       case (state)
         STATE_IDLE :
           begin
              all_generated_moves_complete <= 0;
              initial_evaluation_complete <= 0;

              am_moves_ready <= 0;
              board <= board_in;
              white_to_move <= white_to_move_in;
              castle_mask <= castle_mask_in;
              en_passant_col <= en_passant_col_in;
              half_move <= half_move_in;
              castle_mask_orig <= castle_mask_orig_in;

              initial_evaluate_board <= board_in;
              initial_evaluate_uci <= 0; // PV flag will not be assigned
              initial_evaluate_white_to_move <= white_to_move_in;
              initial_evaluate_castle_mask <= castle_mask_in;
              initial_attack_go <= board_valid_in;

              initial_insufficient_material <= 0;
              initial_fifty_move <= half_move_in >= 100;

              ram_wr_addr_init <= 1;
              initial_clear_attack <= 0;

              if (board_valid_in)
                state <= STATE_INIT_WAIT_ATTACK;
           end
         STATE_INIT_WAIT_ATTACK :
           if (initial_fifty_move)
             state <= STATE_DONE;
           else if (is_attacking_done)
             begin
                initial_clear_attack <= 1;
                initial_evaluate_go <= 1;
                state <= STATE_INIT_WAIT_EVAL;
             end
         STATE_INIT_WAIT_EVAL :
           begin
              initial_evaluate_go <= 0;
              initial_eval <= eval;
              initial_insufficient_material <= insufficient_material;
              initial_board_check <= (white_to_move && white_in_check) || (black_to_move && black_in_check);
              if (eval_valid)
                state <= STATE_INIT;
           end
         STATE_INIT :
           begin
              initial_attack_go <= 0;

              ram_wr_addr_init <= 0;
              ram_wr <= 0;

              // bitmask of all potentially moveable pieces
              for (s = 0; s < 64; s = s + 1)
                square_active[s] <= board[s * `PIECE_WIDTH+:`PIECE_WIDTH] != `EMPTY_POSN && // square not empty
                       board[s * `PIECE_WIDTH + `BLACK_BIT] == black_to_move; // my piece

              // castling possibilities
              // black to move
              castle_short_legal[0] <= castle_mask[`CASTLE_BLACK_SHORT] &&
                                       board[idx[7][5]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                       board[idx[7][6]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                       white_is_attacking[7 << 3 | 4] == 1'b0 &&
                                       white_is_attacking[7 << 3 | 5] == 1'b0 &&
                                       white_is_attacking[7 << 3 | 6] == 1'b0;
              castle_long_legal[0] <= castle_mask[`CASTLE_BLACK_LONG] &&
                                      board[idx[7][1]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                      board[idx[7][2]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                      board[idx[7][3]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                      white_is_attacking[7 << 3 | 2] == 1'b0 &&
                                      white_is_attacking[7 << 3 | 3] == 1'b0 &&
                                      white_is_attacking[7 << 3 | 4] == 1'b0;
              // white to move
              castle_short_legal[1] <= castle_mask[`CASTLE_WHITE_SHORT] &&
                                       board[idx[0][5]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                       board[idx[0][6]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                       black_is_attacking[0 << 3 | 4] == 1'b0 &&
                                       black_is_attacking[0 << 3 | 5] == 1'b0 &&
                                       black_is_attacking[0 << 3 | 6] == 1'b0;
              castle_long_legal[1] <= castle_mask[`CASTLE_WHITE_LONG] &&
                                      board[idx[0][1]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                      board[idx[0][2]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                      board[idx[0][3]+:`PIECE_WIDTH] == `EMPTY_POSN &&
                                      black_is_attacking[0 << 3 | 2] == 1'b0 &&
                                      black_is_attacking[0 << 3 | 3] == 1'b0 &&
                                      black_is_attacking[0 << 3 | 4] == 1'b0;

              state <= STATE_INIT_WS;
           end
         STATE_INIT_WS :
           begin
              initial_clear_attack <= 0;
              state <= STATE_FIND_PIECE;
           end
         STATE_FIND_PIECE :
           begin
              initial_evaluation_complete <= 1;
              if (white_to_move)
                begin
                   for (sy = 7; sy >= 0; sy = sy - 1)
                     for (sx = 0; sx <= 7; sx = sx + 1)
                       if (square_active[sy << 3 | sx])
                         begin
                            row <= sy;
                            col <= sx;
                         end
                end
              else
                begin
                   for (sy = 0; sy <= 7; sy = sy + 1)
                     for (sx = 0; sx <= 7; sx = sx + 1)
                       if (square_active[sy << 3 | sx])
                         begin
                            row <= sy;
                            col <= sx;
                         end
                end
              if (square_active == 64'b0)
                state <= STATE_CASTLE_SHORT; // all individual piece moves done
              else
                state <= STATE_DO_SQUARE;
           end
         STATE_DO_SQUARE :
           begin
              initial_clear_attack <= 0;
              castle_mask_ram_wr <= castle_mask;
              en_passant_col_ram_wr <= 4'b0;
              pawn_zero_half_move_ram_wr <= 0;
              slider_index <= 0;
              uci_from_row_ram_wr <= row;
              uci_from_col_ram_wr <= col;
              uci_promotion_ram_wr <= `EMPTY_POSN;
              if (board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_QUEN ||
                  board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_ROOK ||
                  board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_BISH)
                state <= STATE_SLIDER_INIT;
              else if (board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_KNIT ||
                       board[idx[row][col]+:`PIECE_WIDTH - 1] == `PIECE_KING)
                state <= STATE_DISCRETE_INIT;
              else
                state <= STATE_PAWN_INIT_0; // must be a pawn
           end
         STATE_SLIDER_INIT :
           begin
              ram_wr <= 0;
              if (slider_index < slider_offset_count[piece[`BLACK_BIT - 1:0]])
                begin
                   slider_row <= row_r + slider_offset_row[piece[`BLACK_BIT - 1:0]][slider_index];
                   slider_col <= col_r + slider_offset_col[piece[`BLACK_BIT - 1:0]][slider_index];
                   state <= STATE_SLIDER;
                end
              else
                state <= STATE_NEXT;
           end
         STATE_SLIDER :
           begin
              board_ram_wr <= board;
              board_ram_wr[idx[row_r][col_r]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[slider_row[2:0]][slider_col[2:0]]+:`PIECE_WIDTH] <= piece;
              capture_ram_wr <= board[idx[slider_row[2:0]][slider_col[2:0]] + `BLACK_BIT] != black_to_move &&
                                ! board[idx[slider_row[2:0]][slider_col[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN;
              uci_to_row_ram_wr <= slider_row[2:0];
              uci_to_col_ram_wr <= slider_col[2:0];
              if ((slider_row >= 0 && slider_row <= 7 && slider_col >= 0 && slider_col <= 7) &&
                  (board[idx[slider_row[2:0]][slider_col[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN || // empty square
                   board[idx[slider_row[2:0]][slider_col[2:0]] + `BLACK_BIT] != black_to_move)) // opponent's piece
                begin
                   ram_wr <= 1;
                   slider_row <= slider_row + slider_offset_row[piece[`BLACK_BIT - 1:0]][slider_index];
                   slider_col <= slider_col + slider_offset_col[piece[`BLACK_BIT - 1:0]][slider_index];
                   if (board[idx[slider_row[2:0]][slider_col[2:0]]+:`PIECE_WIDTH] != `EMPTY_POSN)
                     begin
                        slider_index <= slider_index + 1;
                        state <= STATE_SLIDER_INIT;
                     end
                end
              else
                begin
                   ram_wr <= 0;
                   slider_index <= slider_index + 1;
                   state <= STATE_SLIDER_INIT;
                end
           end
         STATE_DISCRETE_INIT :
           begin
              discrete_index <= 1;
              discrete_row <= row + discrete_offset_row[piece[`BLACK_BIT - 1:0]][0];
              discrete_col <= col + discrete_offset_col[piece[`BLACK_BIT - 1:0]][0];
              state <= STATE_DISCRETE;
           end
         STATE_DISCRETE :
           begin
              board_ram_wr <= board;
              board_ram_wr[idx[row_r][col_r]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[discrete_row[2:0]][discrete_col[2:0]]+:`PIECE_WIDTH] <= piece;
              capture_ram_wr <= board[idx[discrete_row[2:0]][discrete_col[2:0]] + `BLACK_BIT] != black_to_move &&
                                ! board[idx[discrete_row[2:0]][discrete_col[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN;
              uci_to_row_ram_wr <= discrete_row[2:0];
              uci_to_col_ram_wr <= discrete_col[2:0];
              if (discrete_row >= 0 && discrete_row <= 7 && discrete_col >= 0 && discrete_col <= 7 &&
                  (board[idx[discrete_row[2:0]][discrete_col[2:0]]+:`PIECE_WIDTH] == `EMPTY_POSN || // empty square
                   board[idx[discrete_row[2:0]][discrete_col[2:0]] + `BLACK_BIT] != black_to_move)) // opponent's piece
                ram_wr <= 1;
              else
                ram_wr <= 0;
              discrete_index <= discrete_index + 1;
              discrete_row <= row_r + discrete_offset_row[piece[`BLACK_BIT - 1:0]][discrete_index];
              discrete_col <= col_r + discrete_offset_col[piece[`BLACK_BIT - 1:0]][discrete_index];
              if (discrete_index == 8)
                state <= STATE_NEXT;
           end
         STATE_PAWN_INIT_0 : // wait state
           state <= STATE_PAWN_INIT_1;
         STATE_PAWN_INIT_1 :
           begin
              pawn_en_passant_count <= 0;
              pawn_move_count <= 0;
              pawn_promotion_count <= 0;
              if (pawn_do_init)
                state <= STATE_PAWN_ROW_1;
              else if (pawn_do_en_passant)
                state <= STATE_PAWN_ROW_4;
              else if (pawn_do_promote)
                state <= STATE_PAWN_ROW_6;
              else
                state <= STATE_PAWN_ADVANCE;
           end
         STATE_PAWN_ROW_1 : // initial pawn
           begin
              board_ram_wr <= board;
              en_passant_col_ram_wr <= (1 << `EN_PASSANT_VALID_BIT) | pawn_col_adv2[2:0];
              board_ram_wr[idx[row_r[2:0]][col_r[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[pawn_row_adv2[2:0]][pawn_col_adv2[2:0]]+:`PIECE_WIDTH] <= piece;
              capture_ram_wr <= 0;
              uci_to_row_ram_wr <= pawn_row_adv2[2:0];
              uci_to_col_ram_wr <= pawn_col_adv2[2:0];
              if (pawn_adv2)
                begin
                   pawn_zero_half_move_ram_wr <= 1;
                   ram_wr <= 1;
                end
              state <= STATE_PAWN_ADVANCE;
           end
         STATE_PAWN_ROW_4 : // en passant pawn
           begin
              board_ram_wr <= board;
              board_ram_wr[idx[row_r[2:0]][col_r[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[row_r[2:0]][en_passant_col_r[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[pawn_enp_row[pawn_en_passant_count][2:0]][en_passant_col_r[2:0]]+:`PIECE_WIDTH] <= piece;
              uci_to_row_ram_wr <= pawn_enp_row[pawn_en_passant_count][2:0];
              uci_to_col_ram_wr <= en_passant_col_r[2:0];
              if (pawn_en_passant_mask[pawn_en_passant_count])
                begin
                   capture_ram_wr <= 1;
                   pawn_zero_half_move_ram_wr <= 1;
                   ram_wr <= 1;
                   state <= STATE_PAWN_ADVANCE;
                end
              else
                capture_ram_wr <= 0;
              pawn_en_passant_count <= pawn_en_passant_count + 1;
              if (pawn_en_passant_count == 1)
                state <= STATE_PAWN_ADVANCE;
           end
         STATE_PAWN_ROW_6 : // promotion pawn
           begin
              board_ram_wr <= board;
              board_ram_wr[idx[row_r[2:0]][col_r[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[pawn_adv1_row[pawn_move_count][2:0]][pawn_adv1_col[pawn_move_count][2:0]]+:`PIECE_WIDTH]
                <= pawn_promotions[pawn_promotion_count];
              capture_ram_wr <= pawn_move_count != 1;
              uci_to_row_ram_wr <= pawn_adv1_row[pawn_move_count][2:0];
              uci_to_col_ram_wr <= pawn_adv1_col[pawn_move_count][2:0];
              uci_promotion_ram_wr <= pawn_promotions[pawn_promotion_count];
              if (pawn_adv1_mask[pawn_move_count])
                begin
                   pawn_zero_half_move_ram_wr <= 1;
                   ram_wr <= 1;
                end
              else
                ram_wr <= 0;
              if (pawn_promotion_count == 3)
                begin
                   pawn_promotion_count <= 0;
                   pawn_move_count <= pawn_move_count + 1;
                   if (pawn_move_count == 2)
                     state <= STATE_NEXT;
                end
              else
                pawn_promotion_count <= pawn_promotion_count + 1;
           end
         STATE_PAWN_ADVANCE : // default pawn moves
           begin
              en_passant_col_ram_wr <= 0 << `EN_PASSANT_VALID_BIT;
              board_ram_wr <= board;
              board_ram_wr[idx[row_r[2:0]][col_r[2:0]]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[pawn_adv1_row[pawn_move_count][2:0]][pawn_adv1_col[pawn_move_count][2:0]]+:`PIECE_WIDTH] <= piece;
              capture_ram_wr <= pawn_move_count != 1;
              uci_to_row_ram_wr <= pawn_adv1_row[pawn_move_count][2:0];
              uci_to_col_ram_wr <= pawn_adv1_col[pawn_move_count][2:0];
              if (pawn_adv1_mask[pawn_move_count])
                begin
                   pawn_zero_half_move_ram_wr <= 1;
                   ram_wr <= 1;
                end
              else
                ram_wr <= 0;
              pawn_move_count <= pawn_move_count + 1;
              if (pawn_move_count == 2)
                state <= STATE_NEXT;
           end
         STATE_NEXT :
           begin
              ram_wr <= 0;
              square_active[{row[2:0], col[2:0]}] <= 1'b0;
              state <= STATE_FIND_PIECE;
           end
         STATE_CASTLE_SHORT :
           begin
              pawn_zero_half_move_ram_wr <= 0; // no pawn moves possible
              capture_ram_wr <= 0; // no captures possible
              uci_promotion_ram_wr <= `EMPTY_POSN; // no promotion possible

              board_ram_wr <= board;
              board_ram_wr[idx[castle_row[white_to_move]][4]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[castle_row[white_to_move]][7]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[castle_row[white_to_move]][5]+:`PIECE_WIDTH] <= (black_to_move << `BLACK_BIT) | `PIECE_ROOK;
              board_ram_wr[idx[castle_row[white_to_move]][6]+:`PIECE_WIDTH] <= (black_to_move << `BLACK_BIT) | `PIECE_KING;
              uci_from_row_ram_wr <= castle_row[white_to_move];
              uci_from_col_ram_wr <= 4;
              uci_to_row_ram_wr <= castle_row[white_to_move];
              uci_to_col_ram_wr <= 6;
              if (castle_short_legal[white_to_move])
                ram_wr <= 1;
              state <= STATE_CASTLE_LONG;
           end
         STATE_CASTLE_LONG :
           begin
              board_ram_wr <= board;
              board_ram_wr[idx[castle_row[white_to_move]][0]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[castle_row[white_to_move]][1]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[castle_row[white_to_move]][4]+:`PIECE_WIDTH] <= `EMPTY_POSN;
              board_ram_wr[idx[castle_row[white_to_move]][3]+:`PIECE_WIDTH] <= (black_to_move << `BLACK_BIT) | `PIECE_ROOK;
              board_ram_wr[idx[castle_row[white_to_move]][2]+:`PIECE_WIDTH] <= (black_to_move << `BLACK_BIT) | `PIECE_KING;
              uci_from_row_ram_wr <= castle_row[white_to_move];
              uci_from_col_ram_wr <= 4;
              uci_to_row_ram_wr <= castle_row[white_to_move];
              uci_to_col_ram_wr <= 2;
              if (castle_long_legal[white_to_move])
                ram_wr <= 1;
              else
                ram_wr <= 0;
              state <= STATE_ALL_MOVES_DONE;
           end
         STATE_ALL_MOVES_DONE :
           begin
              ram_wr <= 0;
              capture_ram_wr <= 0;

              if (ram_wr_addr == 0)
                state <= STATE_DONE; // no moves, mate or stalemate
              else
                state <= STATE_START_LEGAL;
           end
         STATE_START_LEGAL :
           begin
              all_generated_moves_complete <= 1;
              state <= STATE_WAIT_LEGAL;
           end
         STATE_WAIT_LEGAL :
           if (legal_eval_done)
             begin
                all_generated_moves_complete <= 0;
                state <= STATE_DONE;
             end
         STATE_DONE :
           begin
              if (am_move_count == 0) // no legal moves found
                begin
                   if (initial_board_check)
                     if (white_to_move)
                       initial_eval <= -(`GLOBAL_VALUE_KING); // white mated
                     else
                       initial_eval <= `GLOBAL_VALUE_KING; // black mated
                   else
                     initial_eval <= 0; // stalemate
                   initial_mate <= initial_board_check;
                   initial_stalemate <= ~initial_board_check;
                end
              else
                begin
                   initial_mate <= 0;
                   initial_stalemate <= 0;
                end
              am_moves_ready <= 1;
              if (am_clear_moves)
                state <= STATE_IDLE;
           end
         default :
           state <= STATE_IDLE;
       endcase

   localparam LEGAL_INIT = 0;
   localparam LEGAL_LOAD = 1;
   localparam LEGAL_KING_POS = 2;
   localparam LEGAL_ATTACK_WAIT = 3;
   localparam LEGAL_EVAL = 4;
   localparam LEGAL_NEXT = 5;
   localparam LEGAL_WS = 6;
   localparam LEGAL_WAIT_EVAL_FLUSH = 7;
   localparam LEGAL_MOVE_SORT_INIT = 8;
   localparam LEGAL_MOVE_SORT = 9;
   localparam LEGAL_DONE = 10;

   reg [3:0] legal = LEGAL_INIT;

   always @(posedge clk)
     if (reset)
       begin
          legal <= LEGAL_INIT;
          legal_eval_done <= 0;
          legal_evaluate_go <= 0;
          legal_ram_wr_addr_init <= 1;
       end
     else
       case (legal)
         LEGAL_INIT :
           begin
              legal_ram_wr_addr_init <= 1;
              legal_sort_start <= 0;
              legal_sort_clear <= 0;
              legal_eval_done <= 0;
              legal_attack_go <= 0;
              legal_evaluate_go <= 0;
              ram_rd_addr <= 0;
              if (ram_wr_addr > 0)
                legal <= LEGAL_LOAD;
           end
         LEGAL_LOAD :
           begin
              legal_ram_wr_addr_init <= 0;

              {attack_uci, attack_pawn_zero_half_move, attack_test_capture, attack_test_en_passant_col,
               attack_test_castle_mask, attack_test_white_to_move, attack_test_board} <= ram_rd_data;
              ram_rd_addr <= ram_rd_addr + 1;

              legal_attack_go <= 0;
              legal_evaluate_go <= 0;
              legal_clear_attack <= 0;
              legal <= LEGAL_KING_POS;
           end
         LEGAL_KING_POS :
           begin
              legal_evaluate_castle_mask <= attack_test_castle_mask; // default, overridden below
              if (attack_test_board[idx[0][0]+:`PIECE_WIDTH] != `WHITE_ROOK || attack_test_board[idx[0][4]+:`PIECE_WIDTH] != `WHITE_KING)
                begin
                   attack_test_castle_mask[`CASTLE_WHITE_LONG] <= 1'b0;
                   legal_evaluate_castle_mask[`CASTLE_WHITE_LONG] <= 1'b0;
                end
              if (attack_test_board[idx[0][7]+:`PIECE_WIDTH] != `WHITE_ROOK || attack_test_board[idx[0][4]+:`PIECE_WIDTH] != `WHITE_KING)
                begin
                   attack_test_castle_mask[`CASTLE_WHITE_SHORT] <= 1'b0;
                   legal_evaluate_castle_mask[`CASTLE_WHITE_SHORT] <= 1'b0;
                end
              if (attack_test_board[idx[7][0]+:`PIECE_WIDTH] != `BLACK_ROOK || attack_test_board[idx[7][4]+:`PIECE_WIDTH] != `BLACK_KING)
                begin
                   attack_test_castle_mask[`CASTLE_BLACK_LONG] <= 1'b0;
                   legal_evaluate_castle_mask[`CASTLE_BLACK_LONG] <= 1'b0;
                end
              if (attack_test_board[idx[7][7]+:`PIECE_WIDTH] != `BLACK_ROOK || attack_test_board[idx[7][4]+:`PIECE_WIDTH] != `BLACK_KING)
                begin
                   attack_test_castle_mask[`CASTLE_BLACK_SHORT] <= 1'b0;
                   legal_evaluate_castle_mask[`CASTLE_BLACK_SHORT] <= 1'b0;
                end

              legal_evaluate_white_to_move <= attack_test_white_to_move;
              legal_evaluate_board <= attack_test_board;
              legal_evaluate_uci <= attack_uci;
              legal_attack_go <= 1;

              legal <= LEGAL_ATTACK_WAIT;
           end
         LEGAL_ATTACK_WAIT :
           if (is_attacking_done)
             begin
                legal_attack_go <= 0;
                legal_clear_attack <= 1;
                if ((white_to_move && white_in_check) ||
                    (black_to_move && black_in_check))
                  legal <= LEGAL_NEXT; // side to move still in check
                else
                  legal <= LEGAL_EVAL; // evaluate a legal move
             end
         LEGAL_EVAL :
           begin
              legal_clear_attack <= 0;
              legal_evaluate_go <= 1; // enable evaluation pipeline for this position info

              // fen info
              legal_board_ram_wr <= attack_test_board;
              legal_en_passant_col_ram_wr <= attack_test_en_passant_col;
              legal_castle_mask_ram_wr <= attack_test_castle_mask;
              legal_white_to_move_ram_wr <= attack_test_white_to_move;

              // info found during make-all-moves
              legal_capture_ram_wr <= attack_test_capture;
              legal_uci_ram_wr <= attack_uci;
              if (attack_pawn_zero_half_move || attack_test_capture)
                begin
                   legal_half_move_ram_wr <= 0;
                   legal_fifty_move_ram_wr <= 0;
                end
              else
                begin
                   legal_half_move_ram_wr <= half_move + 1;
                   legal_fifty_move_ram_wr <= half_move >= 99;
                end

              // info found during attack test
              legal_white_in_check_ram_wr <= white_in_check;
              legal_black_in_check_ram_wr <= black_in_check;
              legal_white_is_attacking_ram_wr <= white_is_attacking;
              legal_black_is_attacking_ram_wr <= black_is_attacking;

              legal <= LEGAL_NEXT;
           end
         LEGAL_NEXT :
           begin
              legal_evaluate_go <= 0;
              legal_clear_attack <= 0;
              if (all_generated_moves_complete && ram_wr_addr == ram_rd_addr) // all moves checked for legality
                if (legal_evaluate_go == 0 && eval_input_count == 0)
                  legal <= LEGAL_DONE; // no legal moves, either mate or stalemate
                else
                  legal <= LEGAL_WS; // legal moves, start eval sort
              else
                if (ram_rd_addr < ram_wr_addr) // wait for more moves to be generated
                  legal <= LEGAL_LOAD;
           end
         LEGAL_WS :
           legal <= LEGAL_WAIT_EVAL_FLUSH;
         LEGAL_WAIT_EVAL_FLUSH :
           if (eval_input_count == legal_ram_wr_addr)
             legal <= LEGAL_MOVE_SORT_INIT;
         LEGAL_MOVE_SORT_INIT :
           begin
              legal_sort_start <= 1;
              legal <= LEGAL_MOVE_SORT;
           end
         LEGAL_MOVE_SORT :
           begin
              legal_sort_start <= 0;
              if (legal_sort_complete)
                begin
                   legal_sort_clear <= 1;
                   legal <= LEGAL_DONE;
                end
           end
         LEGAL_DONE :
           begin
              legal_sort_clear <= 0;
              legal_eval_done <= 1;
              if (state == STATE_IDLE && ram_wr_addr == 0)
                begin
                   legal_eval_done <= 0;
                   legal <= LEGAL_INIT;
                end
           end
         default :
           legal <= LEGAL_INIT;
       endcase

   always @(posedge clk)
     begin
        if (! initial_evaluation_complete)
          eval_input_count <= 0;
        if (legal_evaluate_go)
          eval_input_count <= eval_input_count + 1;
     end

   always @(posedge clk)
     am_idle <= legal == LEGAL_INIT && state == STATE_IDLE;

   /* board_attack AUTO_TEMPLATE (
    .board (attack_board[]),
    .board_valid (attack_go),
    );*/
   board_attack board_attack
     (/*AUTOINST*/
      // Outputs
      .is_attacking_done                (is_attacking_done),
      .white_is_attacking               (white_is_attacking[63:0]),
      .black_is_attacking               (black_is_attacking[63:0]),
      .white_in_check                   (white_in_check),
      .black_in_check                   (black_in_check),
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (attack_board[`BOARD_WIDTH-1:0]), // Templated
      .board_valid                      (attack_go),             // Templated
      .clear_attack                     (clear_attack));

   /* evaluate AUTO_TEMPLATE (
    .board_in (evaluate_board_r[]),
    .uci_in (evaluate_uci_r[]),
    .white_to_move (evaluate_white_to_move_r),
    .castle_mask (evaluate_castle_mask_r[]),
    .board_valid (evaluate_go_r),
    .killer_\(.*\) (killer_\1_in[]),
    .bp_in (legal_bypass[]),
    .bp_out (eval_bypass_out[]),
    );*/
   evaluate #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .MAX_DEPTH_LOG2 (MAX_DEPTH_LOG2),
      .UCI_WIDTH (UCI_WIDTH),
      .BYPASS_WIDTH (LEGAL_RAM_WIDTH)
      )
   evaluate
     (/*AUTOINST*/
      // Outputs
      .insufficient_material            (insufficient_material),
      .eval                             (eval[EVAL_WIDTH-1:0]),
      .eval_pv_flag                     (eval_pv_flag),
      .eval_valid                       (eval_valid),
      .bp_out                           (eval_bypass_out[LEGAL_RAM_WIDTH-1:0]), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .random_score_mask                (random_score_mask[EVAL_WIDTH-1:0]),
      .random_number                    (random_number[EVAL_WIDTH-1:0]),
      .algorithm_enable                 (algorithm_enable[31:0]),
      .board_valid                      (evaluate_go_r),         // Templated
      .board_in                         (evaluate_board_r[`BOARD_WIDTH-1:0]), // Templated
      .uci_in                           (evaluate_uci_r[UCI_WIDTH-1:0]), // Templated
      .castle_mask                      (evaluate_castle_mask_r[3:0]), // Templated
      .castle_mask_orig                 (castle_mask_orig[3:0]),
      .white_to_move                    (evaluate_white_to_move_r), // Templated
      .bp_in                            (legal_bypass[LEGAL_RAM_WIDTH-1:0]), // Templated
      .white_is_attacking               (white_is_attacking[63:0]),
      .black_is_attacking               (black_is_attacking[63:0]),
      .white_in_check                   (white_in_check),
      .black_in_check                   (black_in_check),
      .killer_ply                       (killer_ply_in[MAX_DEPTH_LOG2-1:0]), // Templated
      .killer_board                     (killer_board_in[`BOARD_WIDTH-1:0]), // Templated
      .killer_update                    (killer_update_in),      // Templated
      .killer_clear                     (killer_clear_in),       // Templated
      .killer_bonus0                    (killer_bonus0_in[EVAL_WIDTH-1:0]), // Templated
      .killer_bonus1                    (killer_bonus1_in[EVAL_WIDTH-1:0]), // Templated
      .pv_ctrl_in                       (pv_ctrl_in[31:0]));

   /* move_sort AUTO_TEMPLATE (
    .clk (clk),
    .reset (reset),
    .white_to_move (white_to_move),
    .ram_rd_addr (am_move_index[]),
    .all_moves_bram_\(.*\) (all_moves_bram_intermediate_\1[]),
    .\(.*\) (legal_\1[]),
    );*/
   move_sort #
     (
      .RAM_WIDTH (LEGAL_RAM_WIDTH),
      .MAX_POSITIONS_LOG2 (MAX_POSITIONS_LOG2),
      .EVAL_WIDTH (EVAL_WIDTH)
      )
   move_sort_legal
     (/*AUTOINST*/
      // Outputs
      .ram_rd_data                      (legal_ram_rd_data[LEGAL_RAM_WIDTH-1:0]), // Templated
      .ram_wr_addr                      (legal_ram_wr_addr[MAX_POSITIONS_LOG2-1:0]), // Templated
      .all_moves_bram_addr              (all_moves_bram_intermediate_addr[31:0]), // Templated
      .all_moves_bram_din               (all_moves_bram_intermediate_din[511:0]), // Templated
      .all_moves_bram_we                (all_moves_bram_intermediate_we[63:0]), // Templated
      .sort_complete                    (legal_sort_complete),   // Templated
      // Inputs
      .clk                              (clk),                   // Templated
      .reset                            (reset),                 // Templated
      .evaluate_go                      (legal_evaluate_go),     // Templated
      .sort_start                       (legal_sort_start),      // Templated
      .sort_clear                       (legal_sort_clear),      // Templated
      .white_to_move                    (white_to_move),         // Templated
      .ram_wr_addr_init                 (legal_ram_wr_addr_init), // Templated
      .ram_wr_data                      (legal_ram_wr_data[LEGAL_RAM_WIDTH-1:0]), // Templated
      .ram_wr                           (legal_ram_wr),          // Templated
      .ram_rd_addr                      (am_move_index[MAX_POSITIONS_LOG2-1:0])); // Templated

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:

