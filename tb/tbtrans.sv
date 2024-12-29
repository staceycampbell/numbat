`include "numbat.vh"

module tbtrans;

   localparam EVAL_WIDTH = 24;
   localparam MAX_POSITIONS_LOG2 = $clog2(`MAX_POSITIONS);
   localparam REPDET_WIDTH = 8;
   localparam HALF_MOVE_WIDTH = 10;
   localparam TB_REP_HISTORY = 9;
   localparam UCI_WIDTH = 4 + 6 + 6; // promotion, to, from

   reg clk = 0;
   reg reset = 1;
   integer t = 0;
   integer i, j;

   reg     am_clear_moves = 1'b0;
   reg     board_valid = 0;
   reg [7:0] pawn_promotions [0:(1 << `PIECE_BITS) - 1];

   reg [`BOARD_WIDTH - 1:0] board;
   reg                      white_to_move;
   reg [3:0]                castle_mask;
   reg [3:0]                en_passant_col;
   reg [HALF_MOVE_WIDTH - 1:0] half_move;
   reg [HALF_MOVE_WIDTH - 1:0] full_move_number;

   reg [MAX_POSITIONS_LOG2 - 1:0] am_move_index = 0;
   reg                            display_move = 0;
   reg [`BOARD_WIDTH - 1:0]       repdet_board = 0;
   reg [3:0]                      repdet_castle_mask = 0;
   reg [REPDET_WIDTH - 1:0]       repdet_depth = 0;
   reg [REPDET_WIDTH - 1:0]       repdet_wr_addr = 0;
   reg                            repdet_wr_en = 0;
   reg [`BOARD_WIDTH - 1:0]       tb_rep_history [0:TB_REP_HISTORY - 1];
   reg [$clog2(TB_REP_HISTORY) - 1:0] tb_rep_index;
   reg                                am_capture_moves = 0;
   reg                                random_bit = 0;
   reg                                use_random_bit = 0;
   
   reg                                trans_axi_arready = 1;
   reg                                trans_axi_awready = 1;
   reg [1:0]                          trans_axi_bresp = 0;
   reg                                trans_axi_bvalid = 0;
   reg [127:0]                        trans_axi_rdata = 0;
   reg                                trans_axi_rlast = 1;
   reg [1:0]                          trans_axi_rresp = 0;
   reg                                trans_axi_rvalid = 1;
   reg                                trans_axi_wready = 1;
   reg                                white_to_move_in = 0;
   reg [7:0]                          depth_in = 0;
   reg                                entry_lookup_in = 0;
   reg                                entry_store_in = 0;
   reg [EVAL_WIDTH-1:0]               eval_in = 0;
   reg [1:0]                          flag_in = 0;
   reg                                hash_only_in = 0;
   reg                                clear_trans_in = 0;
   reg [`TRANS_NODES_WIDTH - 1:0]     nodes_in = 0;
   reg                                capture_in = 0;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 capture_out;            // From trans of trans.v
   wire                 collision_out;          // From trans of trans.v
   wire [7:0]           depth_out;              // From trans of trans.v
   wire                 entry_valid_out;        // From trans of trans.v
   wire signed [EVAL_WIDTH-1:0] eval_out;       // From trans of trans.v
   wire [1:0]           flag_out;               // From trans of trans.v
   wire [79:0]          hash_out;               // From trans of trans.v
   wire [`TRANS_NODES_WIDTH-1:0] nodes_out;     // From trans of trans.v
   wire [31:0]          trans_axi_araddr;       // From trans of trans.v
   wire [1:0]           trans_axi_arburst;      // From trans of trans.v
   wire [3:0]           trans_axi_arcache;      // From trans of trans.v
   wire [7:0]           trans_axi_arlen;        // From trans of trans.v
   wire [0:0]           trans_axi_arlock;       // From trans of trans.v
   wire [2:0]           trans_axi_arprot;       // From trans of trans.v
   wire [3:0]           trans_axi_arqos;        // From trans of trans.v
   wire [3:0]           trans_axi_arregion;     // From trans of trans.v
   wire [2:0]           trans_axi_arsize;       // From trans of trans.v
   wire                 trans_axi_arvalid;      // From trans of trans.v
   wire [31:0]          trans_axi_awaddr;       // From trans of trans.v
   wire [1:0]           trans_axi_awburst;      // From trans of trans.v
   wire [3:0]           trans_axi_awcache;      // From trans of trans.v
   wire [7:0]           trans_axi_awlen;        // From trans of trans.v
   wire [0:0]           trans_axi_awlock;       // From trans of trans.v
   wire [2:0]           trans_axi_awprot;       // From trans of trans.v
   wire [3:0]           trans_axi_awqos;        // From trans of trans.v
   wire [3:0]           trans_axi_awregion;     // From trans of trans.v
   wire [2:0]           trans_axi_awsize;       // From trans of trans.v
   wire                 trans_axi_awvalid;      // From trans of trans.v
   wire                 trans_axi_bready;       // From trans of trans.v
   wire                 trans_axi_rready;       // From trans of trans.v
   wire [127:0]         trans_axi_wdata;        // From trans of trans.v
   wire                 trans_axi_wlast;        // From trans of trans.v
   wire [15:0]          trans_axi_wstrb;        // From trans of trans.v
   wire                 trans_axi_wvalid;       // From trans of trans.v
   wire                 trans_idle_out;         // From trans of trans.v
   wire [31:0]          trans_trans;            // From trans of trans.v
   // End of automatics
   
   wire [3:0]                         uci_promotion;
   wire [2:0]                         uci_from_row, uci_from_col;
   wire [2:0]                         uci_to_row, uci_to_col;

   initial
     begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tbtrans);
        for (i = 0; i < (1 << `PIECE_BITS); i = i + 1)
          pawn_promotions[i] = "?";
        pawn_promotions[`EMPTY_POSN] = " ";
        pawn_promotions[`WHITE_QUEN] = "Q";
        pawn_promotions[`WHITE_BISH] = "B";
        pawn_promotions[`WHITE_ROOK] = "R";
        pawn_promotions[`WHITE_KNIT] = "N";
        pawn_promotions[`BLACK_QUEN] = "Q";
        pawn_promotions[`BLACK_BISH] = "B";
        pawn_promotions[`BLACK_ROOK] = "R";
        pawn_promotions[`BLACK_KNIT] = "N";
        for (i = 0; i < 64; i = i + 1)
          board[i * `PIECE_WIDTH+:`PIECE_WIDTH] = `EMPTY_POSN;
        
        board[7 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_ROOK;
        board[7 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_ROOK;
        board[7 * `SIDE_WIDTH + 6 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_KING;
        board[6 * `SIDE_WIDTH + 1 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[6 * `SIDE_WIDTH + 3 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_KNIT;
        board[6 * `SIDE_WIDTH + 4 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_BISH;
        board[6 * `SIDE_WIDTH + 6 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[6 * `SIDE_WIDTH + 7 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[5 * `SIDE_WIDTH + 0 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[5 * `SIDE_WIDTH + 1 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_QUEN;
        board[5 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_BISH;
        board[5 * `SIDE_WIDTH + 4 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[4 * `SIDE_WIDTH + 1 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_KNIT;
        board[4 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[4 * `SIDE_WIDTH + 3 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[4 * `SIDE_WIDTH + 4 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[4 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `BLACK_PAWN;
        board[3 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[3 * `SIDE_WIDTH + 6 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[2 * `SIDE_WIDTH + 1 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[2 * `SIDE_WIDTH + 2 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[2 * `SIDE_WIDTH + 3 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[2 * `SIDE_WIDTH + 4 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_BISH;
        board[2 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_KNIT;
        board[2 * `SIDE_WIDTH + 6 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_KNIT;
        board[2 * `SIDE_WIDTH + 7 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[1 * `SIDE_WIDTH + 0 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_PAWN;
        board[1 * `SIDE_WIDTH + 6 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_BISH;
        board[0 * `SIDE_WIDTH + 0 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_ROOK;
        board[0 * `SIDE_WIDTH + 3 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_QUEN;
        board[0 * `SIDE_WIDTH + 5 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_ROOK;
        board[0 * `SIDE_WIDTH + 7 * `PIECE_WIDTH+:`PIECE_WIDTH] = `WHITE_KING;
        white_to_move = 1;
        castle_mask = 4'h0;
        en_passant_col = 4'h0;
        half_move = 1;
        full_move_number = 18;

        forever
          #1 clk = ~clk;
     end

   always @(posedge clk)
     begin
        t <= t + 1;
        reset <= t < 64;
        hash_only_in <= t >= 128 && t < 130;
        if (t >= 512)
          $finish;
     end
   
   /* trans AUTO_TEMPLATE (
    .board_in (board[]),
    .castle_mask_in (castle_mask[]),
    .en_passant_col_in (en_passant_col[]),
    .white_to_move_in (white_to_move),
    );*/
   trans #
     (
      .ADDRESS_WIDTH (32),
      .MEM_SIZE_BYTES (2 * 1024 * 1024 * 1024),
      .EVAL_WIDTH (EVAL_WIDTH)
      )
   trans
     (/*AUTOINST*/
      // Outputs
      .trans_idle_out                   (trans_idle_out),
      .entry_valid_out                  (entry_valid_out),
      .eval_out                         (eval_out[EVAL_WIDTH-1:0]),
      .depth_out                        (depth_out[7:0]),
      .flag_out                         (flag_out[1:0]),
      .nodes_out                        (nodes_out[`TRANS_NODES_WIDTH-1:0]),
      .capture_out                      (capture_out),
      .collision_out                    (collision_out),
      .hash_out                         (hash_out[79:0]),
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
      .trans_axi_arregion               (trans_axi_arregion[3:0]),
      .trans_axi_awregion               (trans_axi_awregion[3:0]),
      .trans_trans                      (trans_trans[31:0]),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .entry_lookup_in                  (entry_lookup_in),
      .entry_store_in                   (entry_store_in),
      .hash_only_in                     (hash_only_in),
      .clear_trans_in                   (clear_trans_in),
      .board_in                         (board[`BOARD_WIDTH-1:0]), // Templated
      .white_to_move_in                 (white_to_move),         // Templated
      .castle_mask_in                   (castle_mask[3:0]),      // Templated
      .en_passant_col_in                (en_passant_col[3:0]),   // Templated
      .flag_in                          (flag_in[1:0]),
      .eval_in                          (eval_in[EVAL_WIDTH-1:0]),
      .depth_in                         (depth_in[7:0]),
      .nodes_in                         (nodes_in[`TRANS_NODES_WIDTH-1:0]),
      .capture_in                       (capture_in),
      .trans_axi_arready                (trans_axi_arready),
      .trans_axi_awready                (trans_axi_awready),
      .trans_axi_bresp                  (trans_axi_bresp[1:0]),
      .trans_axi_bvalid                 (trans_axi_bvalid),
      .trans_axi_rdata                  (trans_axi_rdata[127:0]),
      .trans_axi_rlast                  (trans_axi_rlast),
      .trans_axi_rresp                  (trans_axi_rresp[1:0]),
      .trans_axi_rvalid                 (trans_axi_rvalid),
      .trans_axi_wready                 (trans_axi_wready));

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     ".."
//     )
// End:

