`include "vchess.vh"

module evaluate_mob_square #
  (
   parameter ATTACKING_PIECE = 0,
   parameter ROW = 0,
   parameter COL = 0,
   parameter EVAL_WIDTH = 0
   )
   (
    input                                clk,
    input                                reset,
   
    input [`BOARD_WIDTH - 1:0]           board,
    input                                board_valid,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg,
    output reg signed [EVAL_WIDTH - 1:0] eval_eg
    );

   localparam MAX_MOBILITY = 32; // queen + extra

`include "mobility_head.vh"
   
   localparam PIECE_WIDTH2 = `PIECE_MASK_BITS;
   localparam SIDE_WIDTH2 = PIECE_WIDTH2 * 8;
   localparam BOARD_WIDTH2 = SIDE_WIDTH2 * 8;

   reg [BOARD_WIDTH2 - 1:0]              mobility_mask [0:MOBILITY_LIST_COUNT - 1];
   reg [$clog2(64) - 1:0]                landing [0:MOBILITY_LIST_COUNT - 1];
   reg [MOBILITY_LIST_COUNT - 1:0]       landing_valid;
   reg [63:0]                            mobility_t1;
   reg signed [EVAL_WIDTH - 1:0]         score_mg [0:MAX_MOBILITY - 1], score_eg [0:MAX_MOBILITY - 1];
   reg [`PIECE_WIDTH - 1:0]              piece_t1;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [5:0]           population;             // From popcount of popcount.v
   // End of automatics

   integer                               i, j;
   genvar                                gen_i;

   wire [BOARD_WIDTH2 - 1:0]             board2_t0;
   
   generate
      for (gen_i = 0; gen_i < 64; gen_i = gen_i + 1)
        begin : bitmap_assign_blk
           assign board2_t0[gen_i * PIECE_WIDTH2+:PIECE_WIDTH2] = 1 << (board[gen_i * `PIECE_WIDTH+:`PIECE_WIDTH]);
        end
   endgenerate

   always @(posedge clk)
     begin
        piece_t1 <= board[(ROW << 3 | COL) * `PIECE_WIDTH+:`PIECE_WIDTH];

        if (piece_t1 == ATTACKING_PIECE)
          if ((ATTACKING_PIECE & (1 << `BLACK_BIT)) == 0)
            begin
               eval_mg <= score_mg[population];
               eval_eg <= score_eg[population];
            end
          else
            begin
               eval_mg <= -score_mg[population];
               eval_eg <= -score_eg[population];
            end
        else
          begin
             eval_mg <= 0;
             eval_eg <= 0;
          end
     end

   always @(posedge clk)
     begin
        mobility_t1 <= 0;
        for (i = 0; i < MOBILITY_LIST_COUNT; i = i + 1)
          if ((board2_t0 & mobility_mask[i]) == mobility_mask[i] && landing_valid[i] &&
              (board[landing[i] * `PIECE_WIDTH+:`PIECE_WIDTH] == `EMPTY_POSN || // landing is empty
               (board[landing[i] * `PIECE_WIDTH+:`PIECE_WIDTH] & (1 << `BLACK_BIT) != (ATTACKING_PIECE & (1 << `BLACK_BIT))) // opponent in landing
               ))
            for (j = 0; j < 64; j = j + 1)
              if (mobility_mask[i][j * PIECE_WIDTH2+:PIECE_WIDTH2] != 0 || j == landing[i])
                mobility_t1[j] <= 1;
     end

   initial
     begin
        for (i = 0; i < MOBILITY_LIST_COUNT; i = i + 1)
          begin
             mobility_mask[i] = 0; // don't care
             landing[i] = 0;
             landing_valid[i] = 1'b0;
          end
        for (i = 0; i < MAX_MOBILITY; i = i + 1)
          begin
             score_mg[i] = 0;
             score_eg[i] = 0;
          end
        
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