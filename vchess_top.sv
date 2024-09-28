`include "vchess.vh"

module vchess_top;

   localparam EVAL_WIDTH = 22;
   localparam MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS);
   localparam REPDET_WIDTH = 8;
   localparam HALF_MOVE_WIDTH = 10;

   integer i;

   reg [`BOARD_WIDTH - 1:0] am_board_in;
   reg                      am_board_valid_in = 0;
   reg                      am_new_board_valid_in_z = 0;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 am_black_in_check_out;  // From all_moves of all_moves.v
   wire [63:0]          am_black_is_attacking_out;// From all_moves of all_moves.v
   wire [`BOARD_WIDTH-1:0] am_board_out;        // From all_moves of all_moves.v
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
   wire                 am_white_in_check_out;  // From all_moves of all_moves.v
   wire [63:0]          am_white_is_attacking_out;// From all_moves of all_moves.v
   wire                 am_white_to_move_in;    // From control of control.v
   wire                 am_white_to_move_out;   // From all_moves of all_moves.v
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
   wire                 initial_mate;           // From all_moves of all_moves.v
   wire                 initial_stalemate;      // From all_moves of all_moves.v
   wire                 initial_thrice_rep;     // From all_moves of all_moves.v
   wire [0:0]           reset;                  // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 soft_reset;             // From control of control.v
   // End of automatics
   
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
      .HALF_MOVE_WIDTH (HALF_MOVE_WIDTH)
      )
   all_moves
     (/*AUTOINST*/
      // Outputs
      .initial_mate                     (initial_mate),
      .initial_stalemate                (initial_stalemate),
      .initial_eval                     (initial_eval[EVAL_WIDTH-1:0]),
      .initial_thrice_rep               (initial_thrice_rep),
      .initial_fifty_move               (initial_fifty_move),
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
      // Inputs
      .clk                              (clk),                   // Templated
      .reset                            (soft_reset),            // Templated
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
      .am_move_index                    (am_move_index[MAX_POSITIONS_LOG2-1:0]),
      .am_clear_moves                   (am_clear_moves));

   /* control AUTO_TEMPLATE (
    .\(.*\)_out (\1_in[]),
    .\(.*\)_in (\1_out[]),
    );*/
   control #
     (
      .EVAL_WIDTH (EVAL_WIDTH),
      .MAX_POSITIONS_LOG2 (MAX_POSITIONS_LOG2),
      .REPDET_WIDTH (REPDET_WIDTH),
      .HALF_MOVE_WIDTH (HALF_MOVE_WIDTH)
      )
   control
     (/*AUTOINST*/
      // Outputs
      .soft_reset                       (soft_reset),
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
      .initial_mate                     (initial_mate),
      .initial_stalemate                (initial_stalemate),
      .initial_eval                     (initial_eval[EVAL_WIDTH-1:0]),
      .initial_thrice_rep               (initial_thrice_rep),
      .initial_fifty_move               (initial_fifty_move),
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
      .ctrl0_axi_wvalid                 (ctrl0_axi_wvalid));

   /* mpsoc_preset_wrapper AUTO_TEMPLATE (
    );*/
   mpsoc_preset_wrapper mpsoc_preset_wrapper
     (/*AUTOINST*/
      // Outputs
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
      .digclk                           (digclk),
      .reset                            (reset[0:0]),
      // Inputs
      .ctrl0_axi_arready                (ctrl0_axi_arready),
      .ctrl0_axi_awready                (ctrl0_axi_awready),
      .ctrl0_axi_bresp                  (ctrl0_axi_bresp[1:0]),
      .ctrl0_axi_bvalid                 (ctrl0_axi_bvalid),
      .ctrl0_axi_rdata                  (ctrl0_axi_rdata[31:0]),
      .ctrl0_axi_rresp                  (ctrl0_axi_rresp[1:0]),
      .ctrl0_axi_rvalid                 (ctrl0_axi_rvalid),
      .ctrl0_axi_wready                 (ctrl0_axi_wready));

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     "/usr/local/Xilinx/Vivado/2022.1/data/verilog/src/unisims"
//     "vivado/./vchess/vchess_1.gen/sources_1/bd/mpsoc_preset/hdl"
//     )
// End:

