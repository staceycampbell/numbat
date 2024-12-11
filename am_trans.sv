`include "vchess.vh"

module am_trans #
  (
   parameter EVAL_WIDTH = 0
   )
   (
    input                      clk,
    input                      reset,

    input                      board_valid_in,
    input [`BOARD_WIDTH - 1:0] board_in,
    input                      white_to_move_in,
    input [3:0]                castle_mask_in,
    input [3:0]                en_passant_col_in,
   
    input                      am_trans_rd_axi_arready,
    input                      am_trans_rd_axi_awready,
    input [1:0]                am_trans_rd_axi_bresp,
    input                      am_trans_rd_axi_bvalid,
    input [127:0]              am_trans_rd_axi_rdata,
    input                      am_trans_rd_axi_rlast,
    input [1:0]                am_trans_rd_axi_rresp,
    input                      am_trans_rd_axi_rvalid,
    input                      am_trans_rd_axi_wready,
   
    output [31:0]              am_trans_rd_axi_araddr,
    output [1:0]               am_trans_rd_axi_arburst,
    output [3:0]               am_trans_rd_axi_arcache,
    output [7:0]               am_trans_rd_axi_arlen,
    output [0:0]               am_trans_rd_axi_arlock,
    output [2:0]               am_trans_rd_axi_arprot,
    output [3:0]               am_trans_rd_axi_arqos,
    output [2:0]               am_trans_rd_axi_arsize,
    output                     am_trans_rd_axi_arvalid,
    output [31:0]              am_trans_rd_axi_awaddr,
    output [1:0]               am_trans_rd_axi_awburst,
    output [3:0]               am_trans_rd_axi_awcache,
    output [7:0]               am_trans_rd_axi_awlen,
    output [0:0]               am_trans_rd_axi_awlock,
    output [2:0]               am_trans_rd_axi_awprot,
    output [3:0]               am_trans_rd_axi_awqos,
    output [2:0]               am_trans_rd_axi_awsize,
    output                     am_trans_rd_axi_awvalid,
    output                     am_trans_rd_axi_bready,
    output                     am_trans_rd_axi_rready,
    output [127:0]             am_trans_rd_axi_wdata,
    output                     am_trans_rd_axi_wlast,
    output [15:0]              am_trans_rd_axi_wstrb,
    output                     am_trans_rd_axi_wvalid,
    output [3:0]               am_trans_rd_axi_arregion,
    output [3:0]               am_trans_rd_axi_awregion
    );
   
   reg                         entry_lookup_in = 0;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 capture_out;            // From am_trans_rd of trans.v
   wire                 collision_out;          // From am_trans_rd of trans.v
   wire [7:0]           depth_out;              // From am_trans_rd of trans.v
   wire                 entry_valid_out;        // From am_trans_rd of trans.v
   wire [EVAL_WIDTH-1:0] eval_out;              // From am_trans_rd of trans.v
   wire [1:0]           flag_out;               // From am_trans_rd of trans.v
   wire [79:0]          hash_out;               // From am_trans_rd of trans.v
   wire [`TRANS_NODES_WIDTH-1:0] nodes_out;     // From am_trans_rd of trans.v
   wire                 trans_idle_out;         // From am_trans_rd of trans.v
   // End of automatics
   
   /* trans AUTO_TEMPLATE (
    .clk (clk),
    .reset (reset),
    .clear_trans_in ({@"vl-width"{1'b0}}),
    .entry_store_in ({@"vl-width"{1'b0}}),
    .eval_in ({@"vl-width"{1'b0}}),
    .flag_in ({@"vl-width"{1'b0}}),
    .hash_only_in ({@"vl-width"{1'b0}}),
    .capture_in ({@"vl-width"{1'b0}}),
    .nodes_in ({@"vl-width"{1'b0}}),
    .depth_in ({@"vl-width"{1'b0}}),
    .trans_trans (),
    .trans_axi_\(.*\) (am_trans_rd_axi_\1[]),
    );*/
   trans #
     (
      .EVAL_WIDTH (EVAL_WIDTH)
      )
   am_trans_rd
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
      .trans_axi_araddr                 (am_trans_rd_axi_araddr[31:0]), // Templated
      .trans_axi_arburst                (am_trans_rd_axi_arburst[1:0]), // Templated
      .trans_axi_arcache                (am_trans_rd_axi_arcache[3:0]), // Templated
      .trans_axi_arlen                  (am_trans_rd_axi_arlen[7:0]), // Templated
      .trans_axi_arlock                 (am_trans_rd_axi_arlock[0:0]), // Templated
      .trans_axi_arprot                 (am_trans_rd_axi_arprot[2:0]), // Templated
      .trans_axi_arqos                  (am_trans_rd_axi_arqos[3:0]), // Templated
      .trans_axi_arsize                 (am_trans_rd_axi_arsize[2:0]), // Templated
      .trans_axi_arvalid                (am_trans_rd_axi_arvalid), // Templated
      .trans_axi_awaddr                 (am_trans_rd_axi_awaddr[31:0]), // Templated
      .trans_axi_awburst                (am_trans_rd_axi_awburst[1:0]), // Templated
      .trans_axi_awcache                (am_trans_rd_axi_awcache[3:0]), // Templated
      .trans_axi_awlen                  (am_trans_rd_axi_awlen[7:0]), // Templated
      .trans_axi_awlock                 (am_trans_rd_axi_awlock[0:0]), // Templated
      .trans_axi_awprot                 (am_trans_rd_axi_awprot[2:0]), // Templated
      .trans_axi_awqos                  (am_trans_rd_axi_awqos[3:0]), // Templated
      .trans_axi_awsize                 (am_trans_rd_axi_awsize[2:0]), // Templated
      .trans_axi_awvalid                (am_trans_rd_axi_awvalid), // Templated
      .trans_axi_bready                 (am_trans_rd_axi_bready), // Templated
      .trans_axi_rready                 (am_trans_rd_axi_rready), // Templated
      .trans_axi_wdata                  (am_trans_rd_axi_wdata[127:0]), // Templated
      .trans_axi_wlast                  (am_trans_rd_axi_wlast), // Templated
      .trans_axi_wstrb                  (am_trans_rd_axi_wstrb[15:0]), // Templated
      .trans_axi_wvalid                 (am_trans_rd_axi_wvalid), // Templated
      .trans_axi_arregion               (am_trans_rd_axi_arregion[3:0]), // Templated
      .trans_axi_awregion               (am_trans_rd_axi_awregion[3:0]), // Templated
      .trans_trans                      (),                      // Templated
      // Inputs
      .clk                              (clk),                   // Templated
      .reset                            (reset),                 // Templated
      .entry_lookup_in                  (entry_lookup_in),
      .entry_store_in                   ({1{1'b0}}),             // Templated
      .hash_only_in                     ({1{1'b0}}),             // Templated
      .clear_trans_in                   ({1{1'b0}}),             // Templated
      .board_in                         (board_in[`BOARD_WIDTH-1:0]),
      .white_to_move_in                 (white_to_move_in),
      .castle_mask_in                   (castle_mask_in[3:0]),
      .en_passant_col_in                (en_passant_col_in[3:0]),
      .flag_in                          ({2{1'b0}}),             // Templated
      .eval_in                          ({EVAL_WIDTH{1'b0}}),    // Templated
      .depth_in                         ({8{1'b0}}),             // Templated
      .nodes_in                         ({(1+(`TRANS_NODES_WIDTH-1)){1'b0}}), // Templated
      .capture_in                       ({1{1'b0}}),             // Templated
      .trans_axi_arready                (am_trans_rd_axi_arready), // Templated
      .trans_axi_awready                (am_trans_rd_axi_awready), // Templated
      .trans_axi_bresp                  (am_trans_rd_axi_bresp[1:0]), // Templated
      .trans_axi_bvalid                 (am_trans_rd_axi_bvalid), // Templated
      .trans_axi_rdata                  (am_trans_rd_axi_rdata[127:0]), // Templated
      .trans_axi_rlast                  (am_trans_rd_axi_rlast), // Templated
      .trans_axi_rresp                  (am_trans_rd_axi_rresp[1:0]), // Templated
      .trans_axi_rvalid                 (am_trans_rd_axi_rvalid), // Templated
      .trans_axi_wready                 (am_trans_rd_axi_wready)); // Templated

endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:
