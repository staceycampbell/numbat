`include "vchess.vh"

// crafty tropism, currently missing some calcs

module evaluate_tropism #
  (
   parameter EVAL_WIDTH = 0,
   parameter WHITE = 0
   )
   (
    input                                clk,
    input                                reset,

    input                                board_valid,
    input [`BOARD_WIDTH - 1:0]           board,
    input                                clear_eval,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg,
    output                               eval_valid
    );

   localparam LATENCY_COUNT = 9;
   
   localparam MAX_LUT_INDEX = 15;
   localparam MAX_LUT_INDEX_LOG2 = $clog2(MAX_LUT_INDEX);
   localparam LUT_SUM_LOG2 = MAX_LUT_INDEX_LOG2 + $clog2(64);
   
   localparam LUT_COUNT = (`PIECE_KING + 1) << 3;
   localparam MY_KING = WHITE ? `WHITE_KING : `BLACK_KING;
   localparam ENEMY_KNIT = WHITE ? `BLACK_KNIT : `WHITE_KNIT;
   localparam ENEMY_BISH = WHITE ? `BLACK_BISH : `WHITE_BISH;
   localparam ENEMY_ROOK = WHITE ? `BLACK_ROOK : `WHITE_ROOK;
   localparam ENEMY_QUEN = WHITE ? `BLACK_QUEN : `WHITE_QUEN;

   reg signed [EVAL_WIDTH - 1:0]         king_safety[0:255];
   reg [3:0]                             tropism_lut [0:LUT_COUNT - 1];
   reg [2:0]                             my_king_row_t1, my_king_col_t1;
   reg [2:0]                             row_dist_t2 [0:7];
   reg [2:0]                             col_dist_t2 [0:7];
   reg [2:0]                             distance_t3 [0:63];
   reg [$clog2(LUT_COUNT) - 1:0]         lut_index_t4 [0:63];
   reg [MAX_LUT_INDEX_LOG2 - 1:0]        ksi_t5 [0:63];
   reg [LUT_SUM_LOG2 - 1:0]              ksi_t6 [0:15];
   reg [LUT_SUM_LOG2 - 1:0]              ksi_t7 [0:3];
   reg [LUT_SUM_LOG2 - 1:0]              ksi_t8;
   
   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   integer                               row, col, i, j;
   
   wire [7:0]                            ksi_final_t8 = 0 << 4 | (ksi_t8 < 16 ? ksi_t8[3:0] : 15);
   
   function [4:0] abs_dist (input signed [4:0] x);
      begin
         abs_dist = x < 0 ? -x : x;
      end
   endfunction
   
   function [2:0] max_dist (input [2:0] a, input [2:0] b);
      begin
         max_dist = a > b ? a : b;
      end
   endfunction

   function enemy_tropism_piece (input [`PIECE_WIDTH - 1:0] p);
      begin
         enemy_tropism_piece = p == ENEMY_KNIT || p == ENEMY_BISH || p == ENEMY_ROOK || p == ENEMY_QUEN;
      end
   endfunction

   always @(posedge clk)
     begin
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            if (board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_KING)
              begin
                 my_king_row_t1 <= row;
                 my_king_col_t1 <= col;
              end
        for (row = 0; row < 8; row = row + 1)
          row_dist_t2[row] <= abs_dist(my_king_row_t1 - row);
        for (col = 0; col < 8; col = col + 1)
          col_dist_t2[col] <= abs_dist(my_king_col_t1 - col);
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            distance_t3[row << 3 | col] <= max_dist(row_dist_t2[row], col_dist_t2[col]);
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            begin
               lut_index_t4[row << 3 | col] <= board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH - 1] << 3 | distance_t3[row << 3 | col];
               if (enemy_tropism_piece(board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH]))
                 ksi_t5[row << 3 | col] <= tropism_lut[lut_index_t4[row << 3 | col]];
               else
                 ksi_t5[row << 3 | col] <= 0;
            end
        for (i = 0; i < 16; i = i + 1)
          ksi_t6[i] <= ksi_t5[i * 4 + 0] + ksi_t5[i * 4 + 1] + ksi_t5[i * 4 + 2] + ksi_t5[i * 4 + 3];
        for (i = 0; i < 4; i = i + 1)
          ksi_t7[i] <= ksi_t6[i * 4 + 0] + ksi_t6[i * 4 + 1] + ksi_t6[i * 4 + 2] + ksi_t6[i * 4 + 3];
        ksi_t8 <= ksi_t7[0] + ksi_t7[1] + ksi_t7[2] + ksi_t7[3];
        if (WHITE)
          eval_mg <= king_safety[ksi_final_t8];
        else
          eval_mg <= -king_safety[ksi_final_t8];
     end

   initial
     begin
        for (i = 0; i < LUT_COUNT; i = i + 1)
          tropism_lut[i] = 0;
        
`include "evaluate_tropism.vh"
        
     end

   /* latency_sm AUTO_TEMPLATE (
    );*/
   latency_sm #
     (
      .LATENCY_COUNT (LATENCY_COUNT)
      )
   latency_sm
     (/*AUTOINST*/
      // Outputs
      .eval_valid                       (eval_valid),
      // Inputs
      .clk                              (clk),
      .reset                            (reset),
      .board_valid                      (board_valid),
      .clear_eval                       (clear_eval));

endmodule
