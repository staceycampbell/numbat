`include "vchess.vh"

module evaluate_mob_square #
  (
   parameter ATTACKING_PIECE = 0,
   parameter ROW = 0,
   parameter COL = 0,
   parameter EVAL_WIDTH = 0
   )
   (
    input                            clk,
    input                            reset,
   
    input [`BOARD_WIDTH - 1:0]       board,
    input                            board_valid,

    output signed [EVAL_WIDTH - 1:0] eval_mg,
    output signed [EVAL_WIDTH - 1:0] eval_eg
    );

`include "mobility_head.vh"
   
   localparam PIECE_WIDTH2 = `PIECE_MASK_BITS;
   localparam SIDE_WIDTH2 = PIECE_WIDTH2 * 8;
   localparam BOARD_WIDTH2 = SIDE_WIDTH2 * 8;

   reg [BOARD_WIDTH2 - 1:0]          mobility_mask [0:MOBILITY_LIST_COUNT - 1];
   reg [63:0]                        mobility_t1;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [5:0]           population;             // From popcount of popcount.v
   // End of automatics

   integer                           i, j;
   genvar                            gen_i;

   wire [BOARD_WIDTH2 - 1:0]         board2_t0;
   
   generate
      for (gen_i = 0; gen_i < 64; gen_i = gen_i + 1)
        begin : bitmap_assign_blk
           assign board2_t0[gen_i * PIECE_WIDTH2+:PIECE_WIDTH2] = 1 << (board[gen_i * `PIECE_WIDTH+:`PIECE_WIDTH]);
        end
   endgenerate

   assign eval_mg = (ATTACKING_PIECE & (1 << `BLACK_BIT)) == 0 ? population : -population;
   assign eval_eg = (ATTACKING_PIECE & (1 << `BLACK_BIT)) == 0 ? population : -population;

   always @(posedge clk)
     begin
        mobility_t1 <= 0;
        for (i = 0; i < MOBILITY_LIST_COUNT; i = i + 1)
          if (mobility_mask[i] != 0 && (board2_t0 & mobility_mask[i]) == mobility_mask[i])
            for (j = 0; j < 64; j = j + 1)
              if (mobility_mask[i][j * PIECE_WIDTH2+:PIECE_WIDTH2] != 0 && j != (ROW << 3 | COL))
                mobility_t1[j] <= 1;
     end

   initial
     begin
        for (i = 0; i < MOBILITY_LIST_COUNT; i = i + 1)
          mobility_mask[i] = 0; // don't care
        
`include "mobility_mask.vh"
     end

   /* popcount AUTO_TEMPLATE (
    .x0 (mobility_t1[]),
    );*/
   popcount popcount
     (/*AUTOINST*/
      // Outputs
      .population                       (population[5:0]),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .x0                               (mobility_t1[63:0]));     // Templated


endmodule
