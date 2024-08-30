`include "vchess.vh"

module vchess_top;

   localparam PIECE_WIDTH = `PIECE_BITS;
   localparam SIDE_WIDTH = PIECE_WIDTH * 8;
   localparam BOARD_WIDTH = PIECE_WIDTH * 8 * 8;
   localparam EVAL_WIDTH = 22;

   integer i;

   reg [BOARD_WIDTH - 1:0] board;
   reg                     board_valid = 0;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [3:0]           castle_mask;            // From control of control.v
   wire                 clear_eval;             // From control of control.v
   wire                 clear_moves;            // From control of control.v
   wire                 clk200;                 // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
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
   wire [39:0]          ctrl1_axi_araddr;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [2:0]           ctrl1_axi_arprot;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl1_axi_arready;      // From control of control.v
   wire                 ctrl1_axi_arvalid;      // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [39:0]          ctrl1_axi_awaddr;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [2:0]           ctrl1_axi_awprot;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl1_axi_awready;      // From control of control.v
   wire                 ctrl1_axi_awvalid;      // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 ctrl1_axi_bready;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [1:0]           ctrl1_axi_bresp;        // From control of control.v
   wire [0:0]           ctrl1_axi_bvalid;       // From control of control.v
   wire [31:0]          ctrl1_axi_rdata;        // From control of control.v
   wire                 ctrl1_axi_rready;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [1:0]           ctrl1_axi_rresp;        // From control of control.v
   wire [0:0]           ctrl1_axi_rvalid;       // From control of control.v
   wire [31:0]          ctrl1_axi_wdata;        // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl1_axi_wready;       // From control of control.v
   wire [3:0]           ctrl1_axi_wstrb;        // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 ctrl1_axi_wvalid;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [3:0]           en_passant_col;         // From control of control.v
   wire signed [EVAL_WIDTH-1:0] eval;           // From evaluate of evaluate.v
   wire                 eval_valid;             // From evaluate of evaluate.v
   wire                 initial_black_in_check; // From all_moves_initial of all_moves.v
   wire [BOARD_WIDTH-1:0] initial_board;        // From all_moves_initial of all_moves.v
   wire                 initial_capture;        // From all_moves_initial of all_moves.v
   wire [3:0]           initial_castle_mask;    // From all_moves_initial of all_moves.v
   wire [3:0]           initial_en_passant_col; // From all_moves_initial of all_moves.v
   wire                 initial_moves_ready;    // From all_moves_initial of all_moves.v
   wire                 initial_white_in_check; // From all_moves_initial of all_moves.v
   wire                 initial_white_to_move;  // From all_moves_initial of all_moves.v
   wire [($clog2(`MAX_POSITIONS))-1:0] move_count;// From all_moves_initial of all_moves.v
   wire [($clog2(`MAX_POSITIONS))-1:0] move_index;// From control of control.v
   wire [BOARD_WIDTH-1:0] new_board;            // From control of control.v
   wire                 new_board_valid;        // From control of control.v
   wire [0:0]           reset;                  // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 white_to_move;          // From control of control.v
   // End of automatics
   
   wire                                clk = clk200;

   initial
     begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);
        for (i = 0; i < 64; i = i + 1)
          board[i * PIECE_WIDTH+:PIECE_WIDTH] = `EMPTY_POSN;
        board[0 * SIDE_WIDTH + 0 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_ROOK;
        board[0 * SIDE_WIDTH + 1 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_KNIT;
        board[0 * SIDE_WIDTH + 2 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_BISH;
        board[0 * SIDE_WIDTH + 3 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_QUEN;
        board[0 * SIDE_WIDTH + 4 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_KING;
        board[0 * SIDE_WIDTH + 5 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_BISH;
        board[0 * SIDE_WIDTH + 6 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_KNIT;
        board[0 * SIDE_WIDTH + 7 * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_ROOK;
        for (i = 0; i < 8; i = i + 1)
          if (i != 4)
            board[1 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_PAWN;
          else
            board[3 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `WHITE_PAWN;

        board[7 * SIDE_WIDTH + 0 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_ROOK;
        board[7 * SIDE_WIDTH + 1 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KNIT;
        board[7 * SIDE_WIDTH + 2 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_BISH;
        board[7 * SIDE_WIDTH + 3 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_QUEN;
        board[7 * SIDE_WIDTH + 4 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KING;
        board[7 * SIDE_WIDTH + 5 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_BISH;
        board[7 * SIDE_WIDTH + 6 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_KNIT;
        board[7 * SIDE_WIDTH + 7 * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_ROOK;
        for (i = 0; i < 8; i = i + 1)
          if (i != 4)
            board[6 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_PAWN;
          else
            board[4 * SIDE_WIDTH + i * PIECE_WIDTH+:PIECE_WIDTH] = `BLACK_PAWN;
     end // initial begin

   always @(posedge clk)
     begin
        board_valid <= 0;
        if (new_board_valid)
          begin
             board <= new_board;
             board_valid <= 1;
          end
     end
   
   /* all_moves AUTO_TEMPLATE (
    .moves_ready (initial_moves_ready),
    .board_out (initial_board[]),
    .castle_mask_out (initial_castle_mask[]),
    .en_passant_col_out (initial_en_passant_col[]),
    .white_to_move_out (initial_white_to_move),
    .white_in_check_out (initial_white_in_check),
    .black_in_check_out (initial_black_in_check),
    .capture_out (initial_capture),
    .\(.*\)_in (\1[]),
    );*/
   all_moves #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH),
      .MAX_POSITIONS (`MAX_POSITIONS),
      .MAX_POSITIONS_LOG2 ($clog2(`MAX_POSITIONS))
      )
   all_moves_initial
     (/*AUTOINST*/
      // Outputs
      .moves_ready                      (initial_moves_ready),   // Templated
      .move_count                       (move_count[($clog2(`MAX_POSITIONS))-1:0]),
      .board_out                        (initial_board[BOARD_WIDTH-1:0]), // Templated
      .white_to_move_out                (initial_white_to_move), // Templated
      .castle_mask_out                  (initial_castle_mask[3:0]), // Templated
      .en_passant_col_out               (initial_en_passant_col[3:0]), // Templated
      .capture_out                      (initial_capture),       // Templated
      .white_in_check_out               (initial_white_in_check), // Templated
      .black_in_check_out               (initial_black_in_check), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .board_in                         (board[BOARD_WIDTH-1:0]), // Templated
      .white_to_move_in                 (white_to_move),         // Templated
      .castle_mask_in                   (castle_mask[3:0]),      // Templated
      .en_passant_col_in                (en_passant_col[3:0]),   // Templated
      .move_index                       (move_index[($clog2(`MAX_POSITIONS))-1:0]),
      .clear_moves                      (clear_moves));

   /* evaluate AUTO_TEMPLATE (
    .\(.*\)_in (\1[]),
    );*/
   evaluate #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH),
      .EVAL_WIDTH (EVAL_WIDTH)
      )
   evaluate
     (/*AUTOINST*/
      // Outputs
      .eval                             (eval[EVAL_WIDTH-1:0]),
      .eval_valid                       (eval_valid),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .board_in                         (board[BOARD_WIDTH-1:0]), // Templated
      .white_to_move_in                 (white_to_move),         // Templated
      .castle_mask_in                   (castle_mask[3:0]),      // Templated
      .en_passant_col_in                (en_passant_col[3:0]),   // Templated
      .clear_eval                       (clear_eval));

   /* control AUTO_TEMPLATE (
    );*/
   control #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH),
      .EVAL_WIDTH (EVAL_WIDTH)
      )
   control
     (/*AUTOINST*/
      // Outputs
      .new_board                        (new_board[BOARD_WIDTH-1:0]),
      .new_board_valid                  (new_board_valid),
      .castle_mask                      (castle_mask[3:0]),
      .clear_moves                      (clear_moves),
      .en_passant_col                   (en_passant_col[3:0]),
      .white_to_move                    (white_to_move),
      .move_index                       (move_index[($clog2(`MAX_POSITIONS))-1:0]),
      .clear_eval                       (clear_eval),
      .ctrl0_axi_arready                (ctrl0_axi_arready[0:0]),
      .ctrl0_axi_awready                (ctrl0_axi_awready[0:0]),
      .ctrl0_axi_bresp                  (ctrl0_axi_bresp[1:0]),
      .ctrl0_axi_bvalid                 (ctrl0_axi_bvalid[0:0]),
      .ctrl0_axi_rdata                  (ctrl0_axi_rdata[31:0]),
      .ctrl0_axi_rresp                  (ctrl0_axi_rresp[1:0]),
      .ctrl0_axi_rvalid                 (ctrl0_axi_rvalid[0:0]),
      .ctrl0_axi_wready                 (ctrl0_axi_wready[0:0]),
      .ctrl1_axi_arready                (ctrl1_axi_arready[0:0]),
      .ctrl1_axi_awready                (ctrl1_axi_awready[0:0]),
      .ctrl1_axi_bresp                  (ctrl1_axi_bresp[1:0]),
      .ctrl1_axi_bvalid                 (ctrl1_axi_bvalid[0:0]),
      .ctrl1_axi_rdata                  (ctrl1_axi_rdata[31:0]),
      .ctrl1_axi_rresp                  (ctrl1_axi_rresp[1:0]),
      .ctrl1_axi_rvalid                 (ctrl1_axi_rvalid[0:0]),
      .ctrl1_axi_wready                 (ctrl1_axi_wready[0:0]),
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .eval_valid                       (eval_valid),
      .eval                             (eval[EVAL_WIDTH-1:0]),
      .initial_moves_ready              (initial_moves_ready),
      .initial_board                    (initial_board[BOARD_WIDTH-1:0]),
      .initial_castle_mask              (initial_castle_mask[3:0]),
      .initial_en_passant_col           (initial_en_passant_col[3:0]),
      .initial_white_to_move            (initial_white_to_move),
      .initial_white_in_check           (initial_white_in_check),
      .initial_black_in_check           (initial_black_in_check),
      .initial_capture                  (initial_capture),
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
      .ctrl1_axi_araddr                 (ctrl1_axi_araddr[39:0]),
      .ctrl1_axi_arprot                 (ctrl1_axi_arprot[2:0]),
      .ctrl1_axi_arvalid                (ctrl1_axi_arvalid),
      .ctrl1_axi_awaddr                 (ctrl1_axi_awaddr[39:0]),
      .ctrl1_axi_awprot                 (ctrl1_axi_awprot[2:0]),
      .ctrl1_axi_awvalid                (ctrl1_axi_awvalid),
      .ctrl1_axi_bready                 (ctrl1_axi_bready),
      .ctrl1_axi_rready                 (ctrl1_axi_rready),
      .ctrl1_axi_wdata                  (ctrl1_axi_wdata[31:0]),
      .ctrl1_axi_wstrb                  (ctrl1_axi_wstrb[3:0]),
      .ctrl1_axi_wvalid                 (ctrl1_axi_wvalid));

   /* mpsoc_preset_wrapper AUTO_TEMPLATE (
    );*/
   mpsoc_preset_wrapper mpsoc_preset_wrapper
     (/*AUTOINST*/
      // Outputs
      .clk200                           (clk200),
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
      .ctrl1_axi_araddr                 (ctrl1_axi_araddr[39:0]),
      .ctrl1_axi_arprot                 (ctrl1_axi_arprot[2:0]),
      .ctrl1_axi_arvalid                (ctrl1_axi_arvalid),
      .ctrl1_axi_awaddr                 (ctrl1_axi_awaddr[39:0]),
      .ctrl1_axi_awprot                 (ctrl1_axi_awprot[2:0]),
      .ctrl1_axi_awvalid                (ctrl1_axi_awvalid),
      .ctrl1_axi_bready                 (ctrl1_axi_bready),
      .ctrl1_axi_rready                 (ctrl1_axi_rready),
      .ctrl1_axi_wdata                  (ctrl1_axi_wdata[31:0]),
      .ctrl1_axi_wstrb                  (ctrl1_axi_wstrb[3:0]),
      .ctrl1_axi_wvalid                 (ctrl1_axi_wvalid),
      .reset                            (reset[0:0]),
      // Inputs
      .ctrl0_axi_arready                (ctrl0_axi_arready),
      .ctrl0_axi_awready                (ctrl0_axi_awready),
      .ctrl0_axi_bresp                  (ctrl0_axi_bresp[1:0]),
      .ctrl0_axi_bvalid                 (ctrl0_axi_bvalid),
      .ctrl0_axi_rdata                  (ctrl0_axi_rdata[31:0]),
      .ctrl0_axi_rresp                  (ctrl0_axi_rresp[1:0]),
      .ctrl0_axi_rvalid                 (ctrl0_axi_rvalid),
      .ctrl0_axi_wready                 (ctrl0_axi_wready),
      .ctrl1_axi_arready                (ctrl1_axi_arready),
      .ctrl1_axi_awready                (ctrl1_axi_awready),
      .ctrl1_axi_bresp                  (ctrl1_axi_bresp[1:0]),
      .ctrl1_axi_bvalid                 (ctrl1_axi_bvalid),
      .ctrl1_axi_rdata                  (ctrl1_axi_rdata[31:0]),
      .ctrl1_axi_rresp                  (ctrl1_axi_rresp[1:0]),
      .ctrl1_axi_rvalid                 (ctrl1_axi_rvalid),
      .ctrl1_axi_wready                 (ctrl1_axi_wready));

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     "/usr/local/Xilinx/Vivado/2022.1/data/verilog/src/unisims"
//     "vivado/./vchess/vchess_1.gen/sources_1/bd/mpsoc_preset/hdl"
//     )
// End:

