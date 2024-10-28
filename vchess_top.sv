`include "vchess.vh"

module vchess_top
  (
   input         user_si570_sysclk_clk_n,
   input         user_si570_sysclk_clk_p,

   output        ddr4_sdram_062_act_n,
   output [16:0] ddr4_sdram_062_adr,
   output [1:0]  ddr4_sdram_062_ba,
   output        ddr4_sdram_062_bg,
   output        ddr4_sdram_062_ck_c,
   output        ddr4_sdram_062_ck_t,
   output        ddr4_sdram_062_cke,
   output        ddr4_sdram_062_cs_n,
   inout [7:0]   ddr4_sdram_062_dm_n,
   inout [63:0]  ddr4_sdram_062_dq,
   inout [7:0]   ddr4_sdram_062_dqs_c,
   inout [7:0]   ddr4_sdram_062_dqs_t,
   output        ddr4_sdram_062_odt,
   output        ddr4_sdram_062_reset_n
   );

   localparam EVAL_WIDTH = 24;
   localparam MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS);
   localparam REPDET_WIDTH = 8;
   localparam HALF_MOVE_WIDTH = 10;
   localparam UCI_WIDTH = 4 + 6 + 6; // promotion, row/col to, row/col from

   integer       i;
   
   reg [15:0]    ddr4_counter; // incremented on DDR4 async clock

   reg [`BOARD_WIDTH - 1:0] am_board_in;
   reg                      am_board_valid_in = 0;
   reg                      am_new_board_valid_in_z = 0;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 am_black_in_check_out;  // From all_moves of all_moves.v
   wire [63:0]          am_black_is_attacking_out;// From all_moves of all_moves.v
   wire [5:0]           am_black_pop_out;       // From all_moves of all_moves.v
   wire [`BOARD_WIDTH-1:0] am_board_out;        // From all_moves of all_moves.v
   wire                 am_capture_moves;       // From control of control.v
   wire                 am_capture_out;         // From all_moves of all_moves.v
   wire [3:0]           am_castle_mask_in;      // From control of control.v
   wire [3:0]           am_castle_mask_out;     // From all_moves of all_moves.v
   wire                 am_clear_moves;         // From control of control.v
   wire [3:0]           am_en_passant_col_in;   // From control of control.v
   wire [3:0]           am_en_passant_col_out;  // From all_moves of all_moves.v
   wire signed [EVAL_WIDTH-1:0] am_eval_out;    // From all_moves of all_moves.v
   wire                 am_fifty_move_out;      // From all_moves of all_moves.v
   wire [HALF_MOVE_WIDTH-1:0] am_half_move_in;  // From control of control.v
   wire [HALF_MOVE_WIDTH-1:0] am_half_move_out; // From all_moves of all_moves.v
   wire                 am_idle;                // From all_moves of all_moves.v
   wire                 am_insufficient_material_out;// From all_moves of all_moves.v
   wire [MAX_POSITIONS_LOG2-1:0] am_move_count; // From all_moves of all_moves.v
   wire [MAX_POSITIONS_LOG2-1:0] am_move_index; // From control of control.v
   wire                 am_move_ready;          // From all_moves of all_moves.v
   wire                 am_moves_ready;         // From all_moves of all_moves.v
   wire [`BOARD_WIDTH-1:0] am_new_board_in;     // From control of control.v
   wire                 am_new_board_valid_in;  // From control of control.v
   wire [`BOARD_WIDTH-1:0] am_repdet_board_in;  // From control of control.v
   wire [3:0]           am_repdet_castle_mask_in;// From control of control.v
   wire [REPDET_WIDTH-1:0] am_repdet_depth_in;  // From control of control.v
   wire [REPDET_WIDTH-1:0] am_repdet_wr_addr_in;// From control of control.v
   wire                 am_repdet_wr_en_in;     // From control of control.v
   wire                 am_thrice_rep_out;      // From all_moves of all_moves.v
   wire [UCI_WIDTH-1:0] am_uci_out;             // From all_moves of all_moves.v
   wire                 am_white_in_check_out;  // From all_moves of all_moves.v
   wire [63:0]          am_white_is_attacking_out;// From all_moves of all_moves.v
   wire [5:0]           am_white_pop_out;       // From all_moves of all_moves.v
   wire                 am_white_to_move_in;    // From control of control.v
   wire                 am_white_to_move_out;   // From all_moves of all_moves.v
   wire                 c0_ddr4_ui_clk;         // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 c0_ddr4_ui_clk_sync_rst;// From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 c0_ddr4_ui_clk_sync_rst_out;// From sync_c0_ddr4_ui_clk_sync_rst of sync.v
   wire                 c0_init_calib_complete; // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 c0_init_calib_complete_out;// From sync_c0_init_calib_complete of sync.v
   wire [39:0]          ctrl0_axi_araddr;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [2:0]           ctrl0_axi_arprot;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl0_axi_arready;      // From control of control.v
   wire                 ctrl0_axi_arvalid;      // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [39:0]          ctrl0_axi_awaddr;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [2:0]           ctrl0_axi_awprot;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl0_axi_awready;      // From control of control.v
   wire                 ctrl0_axi_awvalid;      // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 ctrl0_axi_bready;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [1:0]           ctrl0_axi_bresp;        // From control of control.v
   wire [0:0]           ctrl0_axi_bvalid;       // From control of control.v
   wire [31:0]          ctrl0_axi_rdata;        // From control of control.v
   wire                 ctrl0_axi_rready;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [1:0]           ctrl0_axi_rresp;        // From control of control.v
   wire [0:0]           ctrl0_axi_rvalid;       // From control of control.v
   wire [31:0]          ctrl0_axi_wdata;        // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl0_axi_wready;       // From control of control.v
   wire [3:0]           ctrl0_axi_wstrb;        // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 ctrl0_axi_wvalid;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 digclk;                 // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire signed [EVAL_WIDTH-1:0] initial_eval;   // From all_moves of all_moves.v
   wire                 initial_fifty_move;     // From all_moves of all_moves.v
   wire                 initial_insufficient_material;// From all_moves of all_moves.v
   wire                 initial_mate;           // From all_moves of all_moves.v
   wire signed [31:0]   initial_material;       // From all_moves of all_moves.v
   wire                 initial_stalemate;      // From all_moves of all_moves.v
   wire                 initial_thrice_rep;     // From all_moves of all_moves.v
   wire [0:0]           reset;                  // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 soft_reset;             // From control of control.v
   wire [31:0]          trans_axi_araddr;       // From trans of trans.v
   wire [1:0]           trans_axi_arburst;      // From trans of trans.v
   wire [3:0]           trans_axi_arcache;      // From trans of trans.v
   wire [7:0]           trans_axi_arlen;        // From trans of trans.v
   wire [0:0]           trans_axi_arlock;       // From trans of trans.v
   wire [2:0]           trans_axi_arprot;       // From trans of trans.v
   wire [3:0]           trans_axi_arqos;        // From trans of trans.v
   wire                 trans_axi_arready;      // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [2:0]           trans_axi_arsize;       // From trans of trans.v
   wire                 trans_axi_arvalid;      // From trans of trans.v
   wire [31:0]          trans_axi_awaddr;       // From trans of trans.v
   wire [1:0]           trans_axi_awburst;      // From trans of trans.v
   wire [3:0]           trans_axi_awcache;      // From trans of trans.v
   wire [7:0]           trans_axi_awlen;        // From trans of trans.v
   wire [0:0]           trans_axi_awlock;       // From trans of trans.v
   wire [2:0]           trans_axi_awprot;       // From trans of trans.v
   wire [3:0]           trans_axi_awqos;        // From trans of trans.v
   wire                 trans_axi_awready;      // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [2:0]           trans_axi_awsize;       // From trans of trans.v
   wire                 trans_axi_awvalid;      // From trans of trans.v
   wire                 trans_axi_bready;       // From trans of trans.v
   wire [1:0]           trans_axi_bresp;        // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 trans_axi_bvalid;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [127:0]         trans_axi_rdata;        // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 trans_axi_rlast;        // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 trans_axi_rready;       // From trans of trans.v
   wire [1:0]           trans_axi_rresp;        // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 trans_axi_rvalid;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [127:0]         trans_axi_wdata;        // From trans of trans.v
   wire                 trans_axi_wlast;        // From trans of trans.v
   wire                 trans_axi_wready;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [15:0]          trans_axi_wstrb;        // From trans of trans.v
   wire                 trans_axi_wvalid;       // From trans of trans.v
   wire [`BOARD_WIDTH-1:0] trans_board_in;      // From control of control.v
   wire [3:0]           trans_castle_mask_in;   // From control of control.v
   wire                 trans_clear_trans_in;   // From control of control.v
   wire                 trans_collision_out;    // From trans of trans.v
   wire [7:0]           trans_depth_in;         // From control of control.v
   wire [7:0]           trans_depth_out;        // From trans of trans.v
   wire [3:0]           trans_en_passant_col_in;// From control of control.v
   wire                 trans_entry_lookup_in;  // From control of control.v
   wire                 trans_entry_store_in;   // From control of control.v
   wire                 trans_entry_valid_out;  // From trans of trans.v
   wire [EVAL_WIDTH-1:0] trans_eval_in;         // From control of control.v
   wire [EVAL_WIDTH-1:0] trans_eval_out;        // From trans of trans.v
   wire [1:0]           trans_flag_in;          // From control of control.v
   wire [1:0]           trans_flag_out;         // From trans of trans.v
   wire                 trans_hash_only_in;     // From control of control.v
   wire [79:0]          trans_hash_out;         // From trans of trans.v
   wire                 trans_trans_idle_out;   // From trans of trans.v
   wire                 trans_white_to_move_in; // From control of control.v
   wire                 use_random_bit;         // From control of control.v
   wire [31:0]          xorshift32_reg;         // From xorshift32 of xorshift32.v
   // End of automatics

   wire [15:0]                   ddr4_counter_out;

   wire                          random_bit = ddr4_counter_out[0];

   always @(posedge c0_ddr4_ui_clk)
     ddr4_counter <= ddr4_counter + 1;
   
   wire [31:0]                   misc_status = {ddr4_counter_out[15:0], 14'b0, c0_ddr4_ui_clk_sync_rst_out, c0_init_calib_complete_out};
   
   wire                          clk = digclk;

   initial
     begin
        for (i = 0; i < 64; i = i + 1)
          am_board_in[i * `PIECE_WIDTH+:`PIECE_WIDTH] = `EMPTY_POSN;
        am_board_in[0 * `SIDE_WIDTH + 0 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_ROOK;
        am_board_in[0 * `SIDE_WIDTH + 1 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_KNIT;
        am_board_in[0 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_BISH;
        am_board_in[0 * `SIDE_WIDTH + 3 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_QUEN;
        am_board_in[0 * `SIDE_WIDTH + 4 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_KING;
        am_board_in[0 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_BISH;
        am_board_in[0 * `SIDE_WIDTH + 6 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_KNIT;
        am_board_in[0 * `SIDE_WIDTH + 7 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_ROOK;
        for (i = 0; i < 8; i = i + 1)
          am_board_in[1 * `SIDE_WIDTH + i * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;

        am_board_in[7 * `SIDE_WIDTH + 0 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_ROOK;
        am_board_in[7 * `SIDE_WIDTH + 1 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_KNIT;
        am_board_in[7 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_BISH;
        am_board_in[7 * `SIDE_WIDTH + 3 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_QUEN;
        am_board_in[7 * `SIDE_WIDTH + 4 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_KING;
        am_board_in[7 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_BISH;
        am_board_in[7 * `SIDE_WIDTH + 6 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_KNIT;
        am_board_in[7 * `SIDE_WIDTH + 7 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_ROOK;
        for (i = 0; i < 8; i = i + 1)
          am_board_in[6 * `SIDE_WIDTH + i * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
     end

   always @(posedge clk)
     begin
        am_new_board_valid_in_z <= am_new_board_valid_in;
        if (am_new_board_valid_in && ~am_new_board_valid_in_z)
          begin
             am_board_in <= am_new_board_in;
             am_board_valid_in <= 1;
          end
        else
          am_board_valid_in <= 0;
     end
   
   /* all_moves AUTO_TEMPLATE (
    .reset (soft_reset),
    .clk (clk),
    .\(.*\)_in (am_\1_in[]),
    .\(.*\)_out (am_\1_out[]),
    );*/
   all_moves #
     (
      .MAX_POSITIONS_LOG2 (MAX_POSITIONS_LOG2),
      .EVAL_WIDTH (EVAL_WIDTH),
      .REPDET_WIDTH (REPDET_WIDTH),
      .HALF_MOVE_WIDTH (HALF_MOVE_WIDTH),
      .UCI_WIDTH (UCI_WIDTH)
      )
   all_moves
     (/*AUTOINST*/
      // Outputs
      .initial_mate                     (initial_mate),
      .initial_stalemate                (initial_stalemate),
      .initial_eval                     (initial_eval[EVAL_WIDTH-1:0]),
      .initial_thrice_rep               (initial_thrice_rep),
      .initial_fifty_move               (initial_fifty_move),
      .initial_insufficient_material    (initial_insufficient_material),
      .initial_material                 (initial_material[31:0]),
      .am_idle                          (am_idle),
      .am_moves_ready                   (am_moves_ready),
      .am_move_ready                    (am_move_ready),
      .am_move_count                    (am_move_count[MAX_POSITIONS_LOG2-1:0]),
      .board_out                        (am_board_out[`BOARD_WIDTH-1:0]), // Templated
      .white_to_move_out                (am_white_to_move_out),  // Templated
      .castle_mask_out                  (am_castle_mask_out[3:0]), // Templated
      .en_passant_col_out               (am_en_passant_col_out[3:0]), // Templated
      .capture_out                      (am_capture_out),        // Templated
      .white_in_check_out               (am_white_in_check_out), // Templated
      .black_in_check_out               (am_black_in_check_out), // Templated
      .white_is_attacking_out           (am_white_is_attacking_out[63:0]), // Templated
      .black_is_attacking_out           (am_black_is_attacking_out[63:0]), // Templated
      .eval_out                         (am_eval_out[EVAL_WIDTH-1:0]), // Templated
      .thrice_rep_out                   (am_thrice_rep_out),     // Templated
      .half_move_out                    (am_half_move_out[HALF_MOVE_WIDTH-1:0]), // Templated
      .fifty_move_out                   (am_fifty_move_out),     // Templated
      .uci_out                          (am_uci_out[UCI_WIDTH-1:0]), // Templated
      .white_pop_out                    (am_white_pop_out[5:0]), // Templated
      .black_pop_out                    (am_black_pop_out[5:0]), // Templated
      .insufficient_material_out        (am_insufficient_material_out), // Templated
      // Inputs
      .clk                              (clk),                   // Templated
      .reset                            (soft_reset),            // Templated
      .use_random_bit                   (use_random_bit),
      .random_bit                       (random_bit),
      .board_valid_in                   (am_board_valid_in),     // Templated
      .board_in                         (am_board_in[`BOARD_WIDTH-1:0]), // Templated
      .white_to_move_in                 (am_white_to_move_in),   // Templated
      .castle_mask_in                   (am_castle_mask_in[3:0]), // Templated
      .en_passant_col_in                (am_en_passant_col_in[3:0]), // Templated
      .half_move_in                     (am_half_move_in[HALF_MOVE_WIDTH-1:0]), // Templated
      .repdet_board_in                  (am_repdet_board_in[`BOARD_WIDTH-1:0]), // Templated
      .repdet_castle_mask_in            (am_repdet_castle_mask_in[3:0]), // Templated
      .repdet_depth_in                  (am_repdet_depth_in[REPDET_WIDTH-1:0]), // Templated
      .repdet_wr_addr_in                (am_repdet_wr_addr_in[REPDET_WIDTH-1:0]), // Templated
      .repdet_wr_en_in                  (am_repdet_wr_en_in),    // Templated
      .am_capture_moves                 (am_capture_moves),
      .am_move_index                    (am_move_index[MAX_POSITIONS_LOG2-1:0]),
      .am_clear_moves                   (am_clear_moves));

   /* trans AUTO_TEMPLATE (
    .clk (clk),
    .reset (reset),
    .trans_axi_\(.*\) (trans_axi_\1[]),
    .\(.*\)_in (trans_\1_in[]),
    .\(.*\)_out (trans_\1_out[]),
    );*/
   trans #
     (
      .EVAL_WIDTH (EVAL_WIDTH)
      )
   trans
     (/*AUTOINST*/
      // Outputs
      .trans_idle_out                   (trans_trans_idle_out),  // Templated
      .entry_valid_out                  (trans_entry_valid_out), // Templated
      .eval_out                         (trans_eval_out[EVAL_WIDTH-1:0]), // Templated
      .depth_out                        (trans_depth_out[7:0]),  // Templated
      .flag_out                         (trans_flag_out[1:0]),   // Templated
      .collision_out                    (trans_collision_out),   // Templated
      .hash_out                         (trans_hash_out[79:0]),  // Templated
      .trans_axi_araddr                 (trans_axi_araddr[31:0]), // Templated
      .trans_axi_arburst                (trans_axi_arburst[1:0]), // Templated
      .trans_axi_arcache                (trans_axi_arcache[3:0]), // Templated
      .trans_axi_arlen                  (trans_axi_arlen[7:0]),  // Templated
      .trans_axi_arlock                 (trans_axi_arlock[0:0]), // Templated
      .trans_axi_arprot                 (trans_axi_arprot[2:0]), // Templated
      .trans_axi_arqos                  (trans_axi_arqos[3:0]),  // Templated
      .trans_axi_arsize                 (trans_axi_arsize[2:0]), // Templated
      .trans_axi_arvalid                (trans_axi_arvalid),     // Templated
      .trans_axi_awaddr                 (trans_axi_awaddr[31:0]), // Templated
      .trans_axi_awburst                (trans_axi_awburst[1:0]), // Templated
      .trans_axi_awcache                (trans_axi_awcache[3:0]), // Templated
      .trans_axi_awlen                  (trans_axi_awlen[7:0]),  // Templated
      .trans_axi_awlock                 (trans_axi_awlock[0:0]), // Templated
      .trans_axi_awprot                 (trans_axi_awprot[2:0]), // Templated
      .trans_axi_awqos                  (trans_axi_awqos[3:0]),  // Templated
      .trans_axi_awsize                 (trans_axi_awsize[2:0]), // Templated
      .trans_axi_awvalid                (trans_axi_awvalid),     // Templated
      .trans_axi_bready                 (trans_axi_bready),      // Templated
      .trans_axi_rready                 (trans_axi_rready),      // Templated
      .trans_axi_wdata                  (trans_axi_wdata[127:0]), // Templated
      .trans_axi_wlast                  (trans_axi_wlast),       // Templated
      .trans_axi_wstrb                  (trans_axi_wstrb[15:0]), // Templated
      .trans_axi_wvalid                 (trans_axi_wvalid),      // Templated
      // Inputs
      .clk                              (clk),                   // Templated
      .reset                            (reset),                 // Templated
      .entry_lookup_in                  (trans_entry_lookup_in), // Templated
      .entry_store_in                   (trans_entry_store_in),  // Templated
      .hash_only_in                     (trans_hash_only_in),    // Templated
      .clear_trans_in                   (trans_clear_trans_in),  // Templated
      .board_in                         (trans_board_in[`BOARD_WIDTH-1:0]), // Templated
      .white_to_move_in                 (trans_white_to_move_in), // Templated
      .castle_mask_in                   (trans_castle_mask_in[3:0]), // Templated
      .en_passant_col_in                (trans_en_passant_col_in[3:0]), // Templated
      .flag_in                          (trans_flag_in[1:0]),    // Templated
      .eval_in                          (trans_eval_in[EVAL_WIDTH-1:0]), // Templated
      .depth_in                         (trans_depth_in[7:0]),   // Templated
      .trans_axi_arready                (trans_axi_arready),     // Templated
      .trans_axi_awready                (trans_axi_awready),     // Templated
      .trans_axi_bresp                  (trans_axi_bresp[1:0]),  // Templated
      .trans_axi_bvalid                 (trans_axi_bvalid),      // Templated
      .trans_axi_rdata                  (trans_axi_rdata[127:0]), // Templated
      .trans_axi_rlast                  (trans_axi_rlast),       // Templated
      .trans_axi_rresp                  (trans_axi_rresp[1:0]),  // Templated
      .trans_axi_rvalid                 (trans_axi_rvalid),      // Templated
      .trans_axi_wready                 (trans_axi_wready));      // Templated

   /* control AUTO_TEMPLATE (
    .\(.*\)_out (\1_in[]),
    .\(.*\)_in (\1_out[]),
    );*/
   control #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .MAX_POSITIONS_LOG2 (MAX_POSITIONS_LOG2),
      .REPDET_WIDTH (REPDET_WIDTH),
      .HALF_MOVE_WIDTH (HALF_MOVE_WIDTH),
      .UCI_WIDTH (UCI_WIDTH)
      )
   control
     (/*AUTOINST*/
      // Outputs
      .soft_reset                       (soft_reset),
      .use_random_bit                   (use_random_bit),
      .am_new_board_valid_out           (am_new_board_valid_in), // Templated
      .am_new_board_out                 (am_new_board_in[`BOARD_WIDTH-1:0]), // Templated
      .am_castle_mask_out               (am_castle_mask_in[3:0]), // Templated
      .am_en_passant_col_out            (am_en_passant_col_in[3:0]), // Templated
      .am_white_to_move_out             (am_white_to_move_in),   // Templated
      .am_half_move_out                 (am_half_move_in[HALF_MOVE_WIDTH-1:0]), // Templated
      .am_repdet_board_out              (am_repdet_board_in[`BOARD_WIDTH-1:0]), // Templated
      .am_repdet_castle_mask_out        (am_repdet_castle_mask_in[3:0]), // Templated
      .am_repdet_depth_out              (am_repdet_depth_in[REPDET_WIDTH-1:0]), // Templated
      .am_repdet_wr_addr_out            (am_repdet_wr_addr_in[REPDET_WIDTH-1:0]), // Templated
      .am_repdet_wr_en_out              (am_repdet_wr_en_in),    // Templated
      .am_move_index                    (am_move_index[MAX_POSITIONS_LOG2-1:0]),
      .am_clear_moves                   (am_clear_moves),
      .am_capture_moves                 (am_capture_moves),
      .trans_board_out                  (trans_board_in[`BOARD_WIDTH-1:0]), // Templated
      .trans_white_to_move_out          (trans_white_to_move_in), // Templated
      .trans_castle_mask_out            (trans_castle_mask_in[3:0]), // Templated
      .trans_en_passant_col_out         (trans_en_passant_col_in[3:0]), // Templated
      .trans_depth_out                  (trans_depth_in[7:0]),   // Templated
      .trans_entry_lookup_out           (trans_entry_lookup_in), // Templated
      .trans_entry_store_out            (trans_entry_store_in),  // Templated
      .trans_hash_only_out              (trans_hash_only_in),    // Templated
      .trans_clear_trans_out            (trans_clear_trans_in),  // Templated
      .trans_eval_out                   (trans_eval_in[EVAL_WIDTH-1:0]), // Templated
      .trans_flag_out                   (trans_flag_in[1:0]),    // Templated
      .ctrl0_axi_arready                (ctrl0_axi_arready[0:0]),
      .ctrl0_axi_awready                (ctrl0_axi_awready[0:0]),
      .ctrl0_axi_bresp                  (ctrl0_axi_bresp[1:0]),
      .ctrl0_axi_bvalid                 (ctrl0_axi_bvalid[0:0]),
      .ctrl0_axi_rdata                  (ctrl0_axi_rdata[31:0]),
      .ctrl0_axi_rresp                  (ctrl0_axi_rresp[1:0]),
      .ctrl0_axi_rvalid                 (ctrl0_axi_rvalid[0:0]),
      .ctrl0_axi_wready                 (ctrl0_axi_wready[0:0]),
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .trans_depth_in                   (trans_depth_out[7:0]),  // Templated
      .trans_entry_valid_in             (trans_entry_valid_out), // Templated
      .trans_eval_in                    (trans_eval_out[EVAL_WIDTH-1:0]), // Templated
      .trans_flag_in                    (trans_flag_out[1:0]),   // Templated
      .trans_trans_idle_in              (trans_trans_idle_out),  // Templated
      .trans_collision_in               (trans_collision_out),   // Templated
      .trans_hash_in                    (trans_hash_out[79:0]),  // Templated
      .initial_mate                     (initial_mate),
      .initial_stalemate                (initial_stalemate),
      .initial_eval                     (initial_eval[EVAL_WIDTH-1:0]),
      .initial_thrice_rep               (initial_thrice_rep),
      .initial_fifty_move               (initial_fifty_move),
      .initial_insufficient_material    (initial_insufficient_material),
      .initial_material                 (initial_material[31:0]),
      .am_idle                          (am_idle),
      .am_moves_ready                   (am_moves_ready),
      .am_move_ready                    (am_move_ready),
      .am_move_count                    (am_move_count[MAX_POSITIONS_LOG2-1:0]),
      .am_board_in                      (am_board_out[`BOARD_WIDTH-1:0]), // Templated
      .am_castle_mask_in                (am_castle_mask_out[3:0]), // Templated
      .am_en_passant_col_in             (am_en_passant_col_out[3:0]), // Templated
      .am_white_to_move_in              (am_white_to_move_out),  // Templated
      .am_white_in_check_in             (am_white_in_check_out), // Templated
      .am_black_in_check_in             (am_black_in_check_out), // Templated
      .am_white_is_attacking_in         (am_white_is_attacking_out[63:0]), // Templated
      .am_black_is_attacking_in         (am_black_is_attacking_out[63:0]), // Templated
      .am_capture_in                    (am_capture_out),        // Templated
      .am_eval_in                       (am_eval_out[EVAL_WIDTH-1:0]), // Templated
      .am_thrice_rep_in                 (am_thrice_rep_out),     // Templated
      .am_half_move_in                  (am_half_move_out[HALF_MOVE_WIDTH-1:0]), // Templated
      .am_fifty_move_in                 (am_fifty_move_out),     // Templated
      .am_uci_in                        (am_uci_out[UCI_WIDTH-1:0]), // Templated
      .am_white_pop_in                  (am_white_pop_out[5:0]), // Templated
      .am_black_pop_in                  (am_black_pop_out[5:0]), // Templated
      .am_insufficient_material_in      (am_insufficient_material_out), // Templated
      .ctrl0_axi_araddr                 (ctrl0_axi_araddr[39:0]),
      .ctrl0_axi_arprot                 (ctrl0_axi_arprot[2:0]),
      .ctrl0_axi_arvalid                (ctrl0_axi_arvalid),
      .ctrl0_axi_awaddr                 (ctrl0_axi_awaddr[39:0]),
      .ctrl0_axi_awprot                 (ctrl0_axi_awprot[2:0]),
      .ctrl0_axi_awvalid                (ctrl0_axi_awvalid),
      .ctrl0_axi_bready                 (ctrl0_axi_bready),
      .ctrl0_axi_rready                 (ctrl0_axi_rready),
      .ctrl0_axi_wdata                  (ctrl0_axi_wdata[31:0]),
      .ctrl0_axi_wstrb                  (ctrl0_axi_wstrb[3:0]),
      .ctrl0_axi_wvalid                 (ctrl0_axi_wvalid),
      .misc_status                      (misc_status[31:0]),
      .xorshift32_reg                   (xorshift32_reg[31:0]));

   /* xorshift32 AUTO_TEMPLATE (
    .x (xorshift32_reg[]),
    );*/
   xorshift32 xorshift32
     (/*AUTOINST*/
      // Outputs
      .x                                (xorshift32_reg[31:0]),  // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset));

   /* mpsoc_preset_wrapper AUTO_TEMPLATE (
    );*/
   mpsoc_preset_wrapper mpsoc_preset_wrapper
     (/*AUTOINST*/
      // Outputs
      .c0_ddr4_ui_clk                   (c0_ddr4_ui_clk),
      .c0_ddr4_ui_clk_sync_rst          (c0_ddr4_ui_clk_sync_rst),
      .c0_init_calib_complete           (c0_init_calib_complete),
      .ctrl0_axi_araddr                 (ctrl0_axi_araddr[39:0]),
      .ctrl0_axi_arprot                 (ctrl0_axi_arprot[2:0]),
      .ctrl0_axi_arvalid                (ctrl0_axi_arvalid),
      .ctrl0_axi_awaddr                 (ctrl0_axi_awaddr[39:0]),
      .ctrl0_axi_awprot                 (ctrl0_axi_awprot[2:0]),
      .ctrl0_axi_awvalid                (ctrl0_axi_awvalid),
      .ctrl0_axi_bready                 (ctrl0_axi_bready),
      .ctrl0_axi_rready                 (ctrl0_axi_rready),
      .ctrl0_axi_wdata                  (ctrl0_axi_wdata[31:0]),
      .ctrl0_axi_wstrb                  (ctrl0_axi_wstrb[3:0]),
      .ctrl0_axi_wvalid                 (ctrl0_axi_wvalid),
      .ddr4_sdram_062_act_n             (ddr4_sdram_062_act_n),
      .ddr4_sdram_062_adr               (ddr4_sdram_062_adr[16:0]),
      .ddr4_sdram_062_ba                (ddr4_sdram_062_ba[1:0]),
      .ddr4_sdram_062_bg                (ddr4_sdram_062_bg),
      .ddr4_sdram_062_ck_c              (ddr4_sdram_062_ck_c),
      .ddr4_sdram_062_ck_t              (ddr4_sdram_062_ck_t),
      .ddr4_sdram_062_cke               (ddr4_sdram_062_cke),
      .ddr4_sdram_062_cs_n              (ddr4_sdram_062_cs_n),
      .ddr4_sdram_062_odt               (ddr4_sdram_062_odt),
      .ddr4_sdram_062_reset_n           (ddr4_sdram_062_reset_n),
      .digclk                           (digclk),
      .reset                            (reset[0:0]),
      .trans_axi_arready                (trans_axi_arready),
      .trans_axi_awready                (trans_axi_awready),
      .trans_axi_bresp                  (trans_axi_bresp[1:0]),
      .trans_axi_bvalid                 (trans_axi_bvalid),
      .trans_axi_rdata                  (trans_axi_rdata[127:0]),
      .trans_axi_rlast                  (trans_axi_rlast),
      .trans_axi_rresp                  (trans_axi_rresp[1:0]),
      .trans_axi_rvalid                 (trans_axi_rvalid),
      .trans_axi_wready                 (trans_axi_wready),
      // Inouts
      .ddr4_sdram_062_dm_n              (ddr4_sdram_062_dm_n[7:0]),
      .ddr4_sdram_062_dq                (ddr4_sdram_062_dq[63:0]),
      .ddr4_sdram_062_dqs_c             (ddr4_sdram_062_dqs_c[7:0]),
      .ddr4_sdram_062_dqs_t             (ddr4_sdram_062_dqs_t[7:0]),
      // Inputs
      .ctrl0_axi_arready                (ctrl0_axi_arready),
      .ctrl0_axi_awready                (ctrl0_axi_awready),
      .ctrl0_axi_bresp                  (ctrl0_axi_bresp[1:0]),
      .ctrl0_axi_bvalid                 (ctrl0_axi_bvalid),
      .ctrl0_axi_rdata                  (ctrl0_axi_rdata[31:0]),
      .ctrl0_axi_rresp                  (ctrl0_axi_rresp[1:0]),
      .ctrl0_axi_rvalid                 (ctrl0_axi_rvalid),
      .ctrl0_axi_wready                 (ctrl0_axi_wready),
      .trans_axi_araddr                 (trans_axi_araddr[31:0]),
      .trans_axi_arburst                (trans_axi_arburst[1:0]),
      .trans_axi_arcache                (trans_axi_arcache[3:0]),
      .trans_axi_arlen                  (trans_axi_arlen[7:0]),
      .trans_axi_arlock                 (trans_axi_arlock[0:0]),
      .trans_axi_arprot                 (trans_axi_arprot[2:0]),
      .trans_axi_arqos                  (trans_axi_arqos[3:0]),
      .trans_axi_arsize                 (trans_axi_arsize[2:0]),
      .trans_axi_arvalid                (trans_axi_arvalid),
      .trans_axi_awaddr                 (trans_axi_awaddr[31:0]),
      .trans_axi_awburst                (trans_axi_awburst[1:0]),
      .trans_axi_awcache                (trans_axi_awcache[3:0]),
      .trans_axi_awlen                  (trans_axi_awlen[7:0]),
      .trans_axi_awlock                 (trans_axi_awlock[0:0]),
      .trans_axi_awprot                 (trans_axi_awprot[2:0]),
      .trans_axi_awqos                  (trans_axi_awqos[3:0]),
      .trans_axi_awsize                 (trans_axi_awsize[2:0]),
      .trans_axi_awvalid                (trans_axi_awvalid),
      .trans_axi_bready                 (trans_axi_bready),
      .trans_axi_rready                 (trans_axi_rready),
      .trans_axi_wdata                  (trans_axi_wdata[127:0]),
      .trans_axi_wlast                  (trans_axi_wlast),
      .trans_axi_wstrb                  (trans_axi_wstrb[15:0]),
      .trans_axi_wvalid                 (trans_axi_wvalid),
      .user_si570_sysclk_clk_n          (user_si570_sysclk_clk_n),
      .user_si570_sysclk_clk_p          (user_si570_sysclk_clk_p));

   /* sync AUTO_TEMPLATE (
    .clk (clk),
    .async_in (c0_ddr4_ui_clk_sync_rst),
    .sync_out (c0_ddr4_ui_clk_sync_rst_out),
    );*/
   sync sync_c0_ddr4_ui_clk_sync_rst
     (/*AUTOINST*/
      // Outputs
      .sync_out                         (c0_ddr4_ui_clk_sync_rst_out), // Templated
      // Inputs
      .clk                              (clk),                   // Templated
      .async_in                         (c0_ddr4_ui_clk_sync_rst)); // Templated

   /* sync AUTO_TEMPLATE (
    .clk (clk),
    .async_in (c0_init_calib_complete),
    .sync_out (c0_init_calib_complete_out),
    );*/
   sync sync_c0_init_calib_complete
     (/*AUTOINST*/
      // Outputs
      .sync_out                         (c0_init_calib_complete_out), // Templated
      // Inputs
      .clk                              (clk),                   // Templated
      .async_in                         (c0_init_calib_complete)); // Templated

   genvar                        c;

   generate
      for (c = 0; c < 16; c = c + 1)
        begin
           /* sync AUTO_TEMPLATE (
            .clk (clk),
            .async_in (ddr4_counter[c]),
            .sync_out (ddr4_counter_out[c]),
            );*/
           sync sync_ddr4_counter
               (/*AUTOINST*/
                // Outputs
                .sync_out               (ddr4_counter_out[c]),   // Templated
                // Inputs
                .clk                    (clk),                   // Templated
                .async_in               (ddr4_counter[c]));       // Templated
           
        end
   endgenerate

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     "/usr/local/Xilinx/Vivado/2022.1/data/verilog/src/unisims"
//     "vivado/./vchess/vchess_1.gen/sources_1/bd/mpsoc_preset/hdl"
//     )
// End:

