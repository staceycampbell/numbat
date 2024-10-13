`include "vchess.vh"

module trans #
  (
   parameter EVAL_WIDTH = 0
   )
   (
    input                      clk,
    input                      reset,

    input                      entry_lookup_in,
    input                      entry_store_in,
   
    input [`BOARD_WIDTH - 1:0] board_in,
    input                      white_to_move_in,
    input [3:0]                castle_mask_in,
    input [3:0]                en_passant_col_in,

    input [1:0]                flag_in,
    input [EVAL_WIDTH - 1:0]   eval_in,
    input [7:0]                depth_in,

    output                     trans_idle_out,

    output                     entry_valid_out,
    output [31:0]              hash_out,
    output [EVAL_WIDTH - 1:0]  eval_out,
    output [7:0]               depth_out,
    output [1:0]               flag_out,
   
    input                      trans_axi_arready,
    input                      trans_axi_awready,
    input [1:0]                trans_axi_bresp,
    input                      trans_axi_bvalid,
    input [511:0]              trans_axi_rdata,
    input                      trans_axi_rlast,
    input [1:0]                trans_axi_rresp,
    input                      trans_axi_rvalid,
    input                      trans_axi_wready,

    output [31:0]              trans_axi_araddr,
    output [1:0]               trans_axi_arburst,
    output [3:0]               trans_axi_arcache,
    output [7:0]               trans_axi_arlen,
    output [0:0]               trans_axi_arlock,
    output [2:0]               trans_axi_arprot,
    output [3:0]               trans_axi_arqos,
    output [2:0]               trans_axi_arsize,
    output                     trans_axi_arvalid,
    output [31:0]              trans_axi_awaddr,
    output [1:0]               trans_axi_awburst,
    output [3:0]               trans_axi_awcache,
    output [7:0]               trans_axi_awlen,
    output [0:0]               trans_axi_awlock,
    output [2:0]               trans_axi_awprot,
    output [3:0]               trans_axi_awqos,
    output [2:0]               trans_axi_awsize,
    output                     trans_axi_awvalid,
    output                     trans_axi_bready,
    output                     trans_axi_rready,
    output [511:0]             trans_axi_wdata,
    output                     trans_axi_wlast,
    output [63:0]              trans_axi_wstrb,
    output                     trans_axi_wvalid
    );

   localparam TABLE_SIZE_LOG2 = 25; // 2^25 * 512 bits for 2GByte DDR4
   
   assign trans_axi_arvalid = 0;
   assign trans_axi_awvalid = 0;
   assign trans_axi_wvalid = 0;
   assign trans_axi_bready = 0;
   assign trans_axi_rready = 0;

endmodule
