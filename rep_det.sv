`include "vchess.vh"

module rep_det #
  (
   parameter REPDET_WIDTH = 7
   )
   (
    input                      clk,
    input                      reset,

    input [`BOARD_WIDTH - 1:0] board_0_in,
    input [3:0]                castle_mask_0_in,
    input                      board_0_valid,

    input                      clear_repdet_0,

    input [`BOARD_WIDTH - 1:0] board_1_in,
    input [3:0]                castle_mask_1_in,
    input                      board_1_valid,

    input                      clear_repdet_1,

    input [`BOARD_WIDTH - 1:0] repdet_board_in,
    input [3:0]                repdet_castle_mask_in,
    input [REPDET_WIDTH - 1:0] repdet_wr_addr_in,
    input                      repdet_wr_en,
    input [REPDET_WIDTH - 1:0] repdet_depth_in,

    output                     board_0_three_move_rep,
    output                     board_0_three_move_rep_valid,
   
    output                     board_1_three_move_rep,
    output                     board_1_three_move_rep_valid
    );

   localparam RAM_WIDTH = `BOARD_WIDTH + 4;
   localparam RAM_COUNT = 1 << REPDET_WIDTH;
   
   reg [RAM_WIDTH - 1:0]       repdet_0_read;
   reg [RAM_WIDTH - 1:0]       repdet_1_read;
   
   reg [RAM_WIDTH - 1:0]       repdet_table [0:RAM_COUNT - 1]; // infer dual port, ultraram compatible

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [REPDET_WIDTH-1:0] repdet_0_rd_addr;    // From rep_det_sub_0 of rep_det_sub.v
   wire [REPDET_WIDTH-1:0] repdet_1_rd_addr;    // From rep_det_sub_1 of rep_det_sub.v
   // End of automatics

   always @(posedge clk)
     begin
        repdet_0_read <= repdet_table[repdet_0_rd_addr];
        repdet_1_read <= repdet_table[repdet_1_rd_addr];

        if (repdet_wr_en)
          repdet_table[repdet_wr_addr_in] <= {repdet_castle_mask_in, repdet_board_in};
     end

   /* rep_det_sub AUTO_TEMPLATE (
    .repdet_read (repdet_@_read[]),
    .board_in (board_@_in[]),
    .castle_mask_in (castle_mask_@_in[]),
    .board_valid (board_@_valid),
    .clear_repdet (clear_repdet_@),
    .repdet_rd_addr (repdet_@_rd_addr[]),
    .board_three_move_rep (board_@_three_move_rep[]),
    .board_three_move_rep_valid (board_@_three_move_rep_valid),
    );*/
   rep_det_sub #
     (
      .REPDET_WIDTH (REPDET_WIDTH),
      .RAM_WIDTH (RAM_WIDTH)
      )
   rep_det_sub_0
     (/*AUTOINST*/
      // Outputs
      .repdet_rd_addr                   (repdet_0_rd_addr[REPDET_WIDTH-1:0]), // Templated
      .board_three_move_rep             (board_0_three_move_rep), // Templated
      .board_three_move_rep_valid       (board_0_three_move_rep_valid), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_in                         (board_0_in[`BOARD_WIDTH-1:0]), // Templated
      .castle_mask_in                   (castle_mask_0_in[3:0]), // Templated
      .board_valid                      (board_0_valid),         // Templated
      .repdet_depth_in                  (repdet_depth_in[REPDET_WIDTH-1:0]),
      .clear_repdet                     (clear_repdet_0),        // Templated
      .repdet_read                      (repdet_0_read[RAM_WIDTH-1:0])); // Templated
   
   rep_det_sub #
     (
      .REPDET_WIDTH (REPDET_WIDTH),
      .RAM_WIDTH (RAM_WIDTH)
      )
   rep_det_sub_1
     (/*AUTOINST*/
      // Outputs
      .repdet_rd_addr                   (repdet_1_rd_addr[REPDET_WIDTH-1:0]), // Templated
      .board_three_move_rep             (board_1_three_move_rep), // Templated
      .board_three_move_rep_valid       (board_1_three_move_rep_valid), // Templated
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_in                         (board_1_in[`BOARD_WIDTH-1:0]), // Templated
      .castle_mask_in                   (castle_mask_1_in[3:0]), // Templated
      .board_valid                      (board_1_valid),         // Templated
      .repdet_depth_in                  (repdet_depth_in[REPDET_WIDTH-1:0]),
      .clear_repdet                     (clear_repdet_1),        // Templated
      .repdet_read                      (repdet_1_read[RAM_WIDTH-1:0])); // Templated
   
endmodule

// Local Variables:
// verilog-auto-inst-param-value:t
// verilog-library-directories:(
//     "."
//     )
// End:
