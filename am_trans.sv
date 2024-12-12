`include "vchess.vh"

module am_trans #
  (
   parameter EVAL_WIDTH = 0,
   parameter MAX_POSITIONS_LOG2 = 0
   )
   (
    input                                 clk,
    input                                 reset,

(* mark_debug = "true" *)    input                                 init,

(* mark_debug = "true" *)    input [MAX_POSITIONS_LOG2 - 1:0]      trans_table_index,

    input                                 board_valid_in,
    input [`BOARD_WIDTH - 1:0]            board_in,
    input                                 white_to_move_in,
    input [3:0]                           castle_mask_in,
    input [3:0]                           en_passant_col_in,

(* mark_debug = "true" *)    output reg                            entry_valid_out,
(* mark_debug = "true" *)    output reg [EVAL_WIDTH - 1:0]         eval_out,
(* mark_debug = "true" *)    output reg [7:0]                      depth_out,
(* mark_debug = "true" *)    output reg [1:0]                      flag_out,
(* mark_debug = "true" *)    output reg [`TRANS_NODES_WIDTH - 1:0] nodes_out,
(* mark_debug = "true" *)    output reg                            capture_out,
(* mark_debug = "true" *)    output reg                            collision_out,

    input                                 am_trans_rd_axi_arready,
    input                                 am_trans_rd_axi_awready,
    input [1:0]                           am_trans_rd_axi_bresp,
    input                                 am_trans_rd_axi_bvalid,
    input [127:0]                         am_trans_rd_axi_rdata,
    input                                 am_trans_rd_axi_rlast,
    input [1:0]                           am_trans_rd_axi_rresp,
    input                                 am_trans_rd_axi_rvalid,
    input                                 am_trans_rd_axi_wready,

    output [31:0]                         am_trans_rd_axi_araddr,
    output [1:0]                          am_trans_rd_axi_arburst,
    output [3:0]                          am_trans_rd_axi_arcache,
    output [7:0]                          am_trans_rd_axi_arlen,
    output [0:0]                          am_trans_rd_axi_arlock,
    output [2:0]                          am_trans_rd_axi_arprot,
    output [3:0]                          am_trans_rd_axi_arqos,
    output [2:0]                          am_trans_rd_axi_arsize,
    output                                am_trans_rd_axi_arvalid,
    output [31:0]                         am_trans_rd_axi_awaddr,
    output [1:0]                          am_trans_rd_axi_awburst,
    output [3:0]                          am_trans_rd_axi_awcache,
    output [7:0]                          am_trans_rd_axi_awlen,
    output [0:0]                          am_trans_rd_axi_awlock,
    output [2:0]                          am_trans_rd_axi_awprot,
    output [3:0]                          am_trans_rd_axi_awqos,
    output [2:0]                          am_trans_rd_axi_awsize,
    output                                am_trans_rd_axi_awvalid,
    output                                am_trans_rd_axi_bready,
    output                                am_trans_rd_axi_rready,
    output [127:0]                        am_trans_rd_axi_wdata,
    output                                am_trans_rd_axi_wlast,
    output [15:0]                         am_trans_rd_axi_wstrb,
    output                                am_trans_rd_axi_wvalid,
    output [3:0]                          am_trans_rd_axi_arregion,
    output [3:0]                          am_trans_rd_axi_awregion
    );

   localparam FIFO_DEPTH_LOG2 = $clog2(`MAX_POSITIONS) + 1;
   localparam FIFO_DEPTH = 1 << FIFO_DEPTH_LOG2;
   localparam FIFO_WIDTH = `BOARD_WIDTH + 4 + 4 + 1;

   localparam TABLE_WIDTH = 1 + EVAL_WIDTH + 8 + 2 + `TRANS_NODES_WIDTH + 1 + 1;

   reg [FIFO_WIDTH - 1:0]      fifo [0:FIFO_DEPTH - 1];
(* mark_debug = "true" *)   reg [FIFO_DEPTH_LOG2 - 1:0] fifo_count, fifo_wr_addr, fifo_rd_addr;
(* mark_debug = "true" *)   reg                         fifo_rd_en = 0;

   reg [TABLE_WIDTH - 1:0]     trans_table [0:`MAX_POSITIONS - 1];
(* mark_debug = "true" *)   reg [MAX_POSITIONS_LOG2 - 1:0] trans_table_wr_addr;
(* mark_debug = "true" *)   reg                            trans_table_wr_en;

   reg                         board_valid_in_r;

   reg [`BOARD_WIDTH - 1:0] local_board;
   reg [3:0]            local_castle_mask;
   reg [3:0]            local_en_passant_col;
(* mark_debug = "true" *)   reg                  local_entry_lookup;
   reg                  local_white_to_move;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 table_capture;          // From am_trans_rd of trans.v
   wire                 table_collision;        // From am_trans_rd of trans.v
   wire [7:0]           table_depth;            // From am_trans_rd of trans.v
   wire                 table_entry_valid;      // From am_trans_rd of trans.v
   wire [EVAL_WIDTH-1:0] table_eval;            // From am_trans_rd of trans.v
   wire [1:0]           table_flag;             // From am_trans_rd of trans.v
   wire [`TRANS_NODES_WIDTH-1:0] table_nodes;   // From am_trans_rd of trans.v
(* mark_debug = "true" *)   wire                 table_trans_idle;       // From am_trans_rd of trans.v
   // End of automatics

(* mark_debug = "true" *)   wire                 fifo_wr_en = board_valid_in && ~board_valid_in_r;

   always @(posedge clk)
     begin
        if (init)
          trans_table_wr_addr <= 0;
        if (trans_table_wr_en)
          begin
             trans_table[trans_table_wr_addr] <= {table_entry_valid, table_capture, table_collision, table_depth[7:0],
                                                  table_eval[EVAL_WIDTH - 1:0], table_flag[1:0], table_nodes[`TRANS_NODES_WIDTH - 1:0]};
             trans_table_wr_addr <= trans_table_wr_addr + 1;
          end
        {entry_valid_out, capture_out, collision_out, depth_out[7:0],
         eval_out[EVAL_WIDTH - 1:0], flag_out[1:0], nodes_out[`TRANS_NODES_WIDTH - 1:0]} <= trans_table[trans_table_index];
     end

   always @(posedge clk)
     begin
        board_valid_in_r <= board_valid_in;
        if (init)
          begin
             fifo_wr_addr <= 0;
             fifo_rd_addr <= 0;
             fifo_count <= 0;
          end
        if (fifo_wr_en)
          begin
             fifo[fifo_wr_addr] <= {white_to_move_in, castle_mask_in[3:0], en_passant_col_in[3:0], board_in[`BOARD_WIDTH - 1:0]};
             fifo_wr_addr <= fifo_wr_addr + 1;
          end
        if (fifo_rd_en)
          begin
             {local_white_to_move, local_castle_mask[3:0], local_en_passant_col[3:0], local_board[`BOARD_WIDTH - 1:0]} <= fifo[fifo_rd_addr];
             fifo_rd_addr <= fifo_rd_addr + 1;
          end
        if (fifo_wr_en && ! fifo_rd_en)
          fifo_count <= fifo_count + 1;
        else if (! fifo_wr_en && fifo_rd_en)
          fifo_count <= fifo_count - 1;
     end

   localparam STATE_IDLE = 0;
   localparam STATE_FIFO_POP = 1;
   localparam STATE_LOAD_TRANS = 2;
   localparam STATE_LOAD_TRANS_WS = 3;
   localparam STATE_WAIT_LOOKUP = 4;
   localparam STATE_WRITE_TABLE = 5;

(* mark_debug = "true" *)   reg [2:0] state = STATE_IDLE;

   always @(posedge clk)
     if (reset)
       state <= STATE_IDLE;
     else
       case (state)
         STATE_IDLE :
           begin
              fifo_rd_en <= 0;
              local_entry_lookup <= 0;
              trans_table_wr_en <= 0;
              if (table_trans_idle && fifo_count > 0)
                state <= STATE_FIFO_POP;
           end
         STATE_FIFO_POP :
           begin
              fifo_rd_en <= 1;
              state <= STATE_LOAD_TRANS;
           end
         STATE_LOAD_TRANS :
           begin
              fifo_rd_en <= 0;
              local_entry_lookup <= 1;
              state <= STATE_WAIT_LOOKUP;
           end
         STATE_LOAD_TRANS_WS : // wait state
           begin
              local_entry_lookup <= 0;
              state <= STATE_WAIT_LOOKUP;
           end
         STATE_WAIT_LOOKUP :
           if (table_trans_idle)
             state <= STATE_WRITE_TABLE;
         STATE_WRITE_TABLE :
           begin
              trans_table_wr_en <= 1;
              state <= STATE_IDLE;
           end
         default :
           state <= STATE_IDLE;
       endcase

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
    .hash_out (),
    .trans_axi_\(.*\) (am_trans_rd_axi_\1[]),
    .\(.*\)_out (table_\1[]),
    .\(.*\)_in (local_\1[]),
    );*/
   trans #
     (
      .EVAL_WIDTH (EVAL_WIDTH)
      )
   am_trans_rd
     (/*AUTOINST*/
      // Outputs
      .trans_idle_out                   (table_trans_idle),      // Templated
      .entry_valid_out                  (table_entry_valid),     // Templated
      .eval_out                         (table_eval[EVAL_WIDTH-1:0]), // Templated
      .depth_out                        (table_depth[7:0]),      // Templated
      .flag_out                         (table_flag[1:0]),       // Templated
      .nodes_out                        (table_nodes[`TRANS_NODES_WIDTH-1:0]), // Templated
      .capture_out                      (table_capture),         // Templated
      .collision_out                    (table_collision),       // Templated
      .hash_out                         (),                      // Templated
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
      .entry_lookup_in                  (local_entry_lookup),    // Templated
      .entry_store_in                   ({1{1'b0}}),             // Templated
      .hash_only_in                     ({1{1'b0}}),             // Templated
      .clear_trans_in                   ({1{1'b0}}),             // Templated
      .board_in                         (local_board[`BOARD_WIDTH-1:0]), // Templated
      .white_to_move_in                 (local_white_to_move),   // Templated
      .castle_mask_in                   (local_castle_mask[3:0]), // Templated
      .en_passant_col_in                (local_en_passant_col[3:0]), // Templated
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
