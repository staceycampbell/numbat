`include "vchess.vh"

module vchess_top;

   localparam PIECE_WIDTH = `PIECE_BITS;
   localparam SIDE_WIDTH = PIECE_WIDTH * 8;
   localparam BOARD_WIDTH = PIECE_WIDTH * 8 * 8;

   integer i;

   reg [BOARD_WIDTH - 1:0] board;
   reg                     board_valid = 0;
   reg                     white_to_move = 1;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 black_in_check;         // From vchess of vchess.v
   wire [63:0]          black_is_attacking;     // From vchess of vchess.v
   wire                 clk200;                 // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [39:0]          ctrl0_axi_araddr;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [2:0]           ctrl0_axi_arprot;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl0_axi_arready;      // From control of control.v
   wire [0:0]           ctrl0_axi_arvalid;      // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [39:0]          ctrl0_axi_awaddr;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [2:0]           ctrl0_axi_awprot;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl0_axi_awready;      // From control of control.v
   wire [0:0]           ctrl0_axi_awvalid;      // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl0_axi_bready;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [1:0]           ctrl0_axi_bresp;        // From control of control.v
   wire [0:0]           ctrl0_axi_bvalid;       // From control of control.v
   wire [31:0]          ctrl0_axi_rdata;        // From control of control.v
   wire [0:0]           ctrl0_axi_rready;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [1:0]           ctrl0_axi_rresp;        // From control of control.v
   wire [0:0]           ctrl0_axi_rvalid;       // From control of control.v
   wire [31:0]          ctrl0_axi_wdata;        // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl0_axi_wready;       // From control of control.v
   wire [3:0]           ctrl0_axi_wstrb;        // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl0_axi_wvalid;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [39:0]          ctrl1_axi_araddr;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [2:0]           ctrl1_axi_arprot;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl1_axi_arready;      // From control of control.v
   wire [0:0]           ctrl1_axi_arvalid;      // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [39:0]          ctrl1_axi_awaddr;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [2:0]           ctrl1_axi_awprot;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl1_axi_awready;      // From control of control.v
   wire [0:0]           ctrl1_axi_awvalid;      // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl1_axi_bready;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [1:0]           ctrl1_axi_bresp;        // From control of control.v
   wire [0:0]           ctrl1_axi_bvalid;       // From control of control.v
   wire [31:0]          ctrl1_axi_rdata;        // From control of control.v
   wire [0:0]           ctrl1_axi_rready;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [1:0]           ctrl1_axi_rresp;        // From control of control.v
   wire [0:0]           ctrl1_axi_rvalid;       // From control of control.v
   wire [31:0]          ctrl1_axi_wdata;        // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl1_axi_wready;       // From control of control.v
   wire [3:0]           ctrl1_axi_wstrb;        // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire [0:0]           ctrl1_axi_wvalid;       // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 display_attacking_done; // From vchess of vchess.v
   wire                 is_attacking_done;      // From vchess of vchess.v
   wire [BOARD_WIDTH-1:0] new_board;            // From control of control.v
   wire                 new_board_valid;        // From control of control.v
   wire [0:0]           reset;                  // From mpsoc_preset_wrapper of mpsoc_preset_wrapper.v
   wire                 white_in_check;         // From vchess of vchess.v
   wire [63:0]          white_is_attacking;     // From vchess of vchess.v
   // End of automatics
   
   wire                    clk = clk200;

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

   /* vchess AUTO_TEMPLATE (
    );*/
   vchess #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH)
      )
   vchess
     (/*AUTOINST*/
      // Outputs
      .white_is_attacking               (white_is_attacking[63:0]),
      .black_is_attacking               (black_is_attacking[63:0]),
      .black_in_check                   (black_in_check),
      .white_in_check                   (white_in_check),
      .is_attacking_done                (is_attacking_done),
      .display_attacking_done           (display_attacking_done),
      // Inputs
      .reset                            (reset),
      .clk                              (clk),
      .board                            (board[BOARD_WIDTH-1:0]),
      .board_valid                      (board_valid),
      .white_to_move                    (white_to_move));

   /* control AUTO_TEMPLATE (
    );*/
   control #
     (
      .PIECE_WIDTH (PIECE_WIDTH),
      .SIDE_WIDTH (SIDE_WIDTH),
      .BOARD_WIDTH (BOARD_WIDTH)
      )
   control
     (/*AUTOINST*/
      // Outputs
      .new_board                        (new_board[BOARD_WIDTH-1:0]),
      .new_board_valid                  (new_board_valid),
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
      .black_is_attacking               (black_is_attacking[63:0]),
      .white_is_attacking               (white_is_attacking[63:0]),
      .white_in_check                   (white_in_check),
      .black_in_check                   (black_in_check),
      .ctrl0_axi_araddr                 (ctrl0_axi_araddr[39:0]),
      .ctrl0_axi_arprot                 (ctrl0_axi_arprot[2:0]),
      .ctrl0_axi_arvalid                (ctrl0_axi_arvalid[0:0]),
      .ctrl0_axi_awaddr                 (ctrl0_axi_awaddr[39:0]),
      .ctrl0_axi_awprot                 (ctrl0_axi_awprot[2:0]),
      .ctrl0_axi_awvalid                (ctrl0_axi_awvalid[0:0]),
      .ctrl0_axi_bready                 (ctrl0_axi_bready[0:0]),
      .ctrl0_axi_rready                 (ctrl0_axi_rready[0:0]),
      .ctrl0_axi_wdata                  (ctrl0_axi_wdata[31:0]),
      .ctrl0_axi_wstrb                  (ctrl0_axi_wstrb[3:0]),
      .ctrl0_axi_wvalid                 (ctrl0_axi_wvalid[0:0]),
      .ctrl1_axi_araddr                 (ctrl1_axi_araddr[39:0]),
      .ctrl1_axi_arprot                 (ctrl1_axi_arprot[2:0]),
      .ctrl1_axi_arvalid                (ctrl1_axi_arvalid[0:0]),
      .ctrl1_axi_awaddr                 (ctrl1_axi_awaddr[39:0]),
      .ctrl1_axi_awprot                 (ctrl1_axi_awprot[2:0]),
      .ctrl1_axi_awvalid                (ctrl1_axi_awvalid[0:0]),
      .ctrl1_axi_bready                 (ctrl1_axi_bready[0:0]),
      .ctrl1_axi_rready                 (ctrl1_axi_rready[0:0]),
      .ctrl1_axi_wdata                  (ctrl1_axi_wdata[31:0]),
      .ctrl1_axi_wstrb                  (ctrl1_axi_wstrb[3:0]),
      .ctrl1_axi_wvalid                 (ctrl1_axi_wvalid[0:0]));

   /* mpsoc_preset_wrapper AUTO_TEMPLATE (
    );*/
   mpsoc_preset_wrapper mpsoc_preset_wrapper
     (/*AUTOINST*/
      // Outputs
      .clk200                           (clk200),
      .ctrl0_axi_araddr                 (ctrl0_axi_araddr[39:0]),
      .ctrl0_axi_arprot                 (ctrl0_axi_arprot[2:0]),
      .ctrl0_axi_arvalid                (ctrl0_axi_arvalid[0:0]),
      .ctrl0_axi_awaddr                 (ctrl0_axi_awaddr[39:0]),
      .ctrl0_axi_awprot                 (ctrl0_axi_awprot[2:0]),
      .ctrl0_axi_awvalid                (ctrl0_axi_awvalid[0:0]),
      .ctrl0_axi_bready                 (ctrl0_axi_bready[0:0]),
      .ctrl0_axi_rready                 (ctrl0_axi_rready[0:0]),
      .ctrl0_axi_wdata                  (ctrl0_axi_wdata[31:0]),
      .ctrl0_axi_wstrb                  (ctrl0_axi_wstrb[3:0]),
      .ctrl0_axi_wvalid                 (ctrl0_axi_wvalid[0:0]),
      .ctrl1_axi_araddr                 (ctrl1_axi_araddr[39:0]),
      .ctrl1_axi_arprot                 (ctrl1_axi_arprot[2:0]),
      .ctrl1_axi_arvalid                (ctrl1_axi_arvalid[0:0]),
      .ctrl1_axi_awaddr                 (ctrl1_axi_awaddr[39:0]),
      .ctrl1_axi_awprot                 (ctrl1_axi_awprot[2:0]),
      .ctrl1_axi_awvalid                (ctrl1_axi_awvalid[0:0]),
      .ctrl1_axi_bready                 (ctrl1_axi_bready[0:0]),
      .ctrl1_axi_rready                 (ctrl1_axi_rready[0:0]),
      .ctrl1_axi_wdata                  (ctrl1_axi_wdata[31:0]),
      .ctrl1_axi_wstrb                  (ctrl1_axi_wstrb[3:0]),
      .ctrl1_axi_wvalid                 (ctrl1_axi_wvalid[0:0]),
      .reset                            (reset[0:0]),
      // Inputs
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
      .ctrl1_axi_wready                 (ctrl1_axi_wready[0:0]));

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     "/usr/local/Xilinx/Vivado/2022.1/data/verilog/src/unisims"
//     "vivado/./vchess/vchess_1.gen/sources_1/bd/mpsoc_preset/hdl"
//     )
// End:

