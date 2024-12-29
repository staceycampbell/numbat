// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

`include "numbat.vh"

module evaluate_mob #
  (
   parameter EVAL_WIDTH = 0
   )
   (
    input                                clk,
    input                                reset,

    input                                board_valid,
    input [`BOARD_WIDTH - 1:0]           board,
    input                                clear_eval,

    output reg signed [EVAL_WIDTH - 1:0] eval_mg,
    output reg signed [EVAL_WIDTH - 1:0] eval_eg,
   
    output                               eval_valid
    );
   
   localparam LATENCY_COUNT = 10;

   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_whitebish_eg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_whitebish_mg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_whiteknit_eg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_whiteknit_mg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_blackbish_eg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_blackbish_mg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_blackknit_eg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_blackknit_mg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_blackquen_eg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_blackquen_mg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_blackrook_eg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_blackrook_mg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_whitequen_eg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_whitequen_mg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_whiterook_eg_t1 [0:15];
   (* use_dsp = "yes" *) reg signed [EVAL_WIDTH - 1:0] eval_whiterook_mg_t1 [0:15];
   
   reg signed [EVAL_WIDTH - 1:0]         eval_whitebish_eg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_whitebish_mg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_whiteknit_eg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_whiteknit_mg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackbish_eg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackbish_mg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackknit_eg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackknit_mg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackquen_eg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackquen_mg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackrook_eg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackrook_mg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_whitequen_eg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_whitequen_mg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_whiterook_eg_t2 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         eval_whiterook_mg_t2 [0:15];
   
   reg signed [EVAL_WIDTH - 1:0]         eval_whitebish_eg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_whitebish_mg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_whiteknit_eg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_whiteknit_mg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackbish_eg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackbish_mg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackknit_eg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackknit_mg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackquen_eg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackquen_mg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackrook_eg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_blackrook_mg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_whitequen_eg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_whitequen_mg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_whiterook_eg_t3 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         eval_whiterook_mg_t3 [0:3];
   
   reg signed [EVAL_WIDTH - 1:0]         eval_whitebish_eg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_whitebish_mg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_whiteknit_eg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_whiteknit_mg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_blackbish_eg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_blackbish_mg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_blackknit_eg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_blackknit_mg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_blackquen_eg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_blackquen_mg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_blackrook_eg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_blackrook_mg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_whitequen_eg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_whitequen_mg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_whiterook_eg_t4;
   reg signed [EVAL_WIDTH - 1:0]         eval_whiterook_mg_t4;
   
   reg signed [EVAL_WIDTH - 1:0]         eval_white_mg_t5;
   reg signed [EVAL_WIDTH - 1:0]         eval_white_eg_t5;
   reg signed [EVAL_WIDTH - 1:0]         eval_black_mg_t5;
   reg signed [EVAL_WIDTH - 1:0]         eval_black_eg_t5;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   genvar                                row, col;
   integer                               i;
   
   wire signed [EVAL_WIDTH - 1:0]        eval_whitebish_eg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_whitebish_mg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_whiteknit_eg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_whiteknit_mg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_blackbish_eg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_blackbish_mg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_blackknit_eg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_blackknit_mg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_blackquen_eg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_blackquen_mg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_blackrook_eg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_blackrook_mg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_whitequen_eg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_whitequen_mg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_whiterook_eg [0:63];
   wire signed [EVAL_WIDTH - 1:0]        eval_whiterook_mg [0:63];
   
   always @(posedge clk)
     for (i = 0; i < 16; i = i + 1)
       begin
          eval_whitebish_eg_t1[i] <= eval_whitebish_eg[i*4+0] + eval_whitebish_eg[i*4+1] + eval_whitebish_eg[i*4+2] + eval_whitebish_eg[i*4+3];
          eval_whitebish_mg_t1[i] <= eval_whitebish_mg[i*4+0] + eval_whitebish_mg[i*4+1] + eval_whitebish_mg[i*4+2] + eval_whitebish_mg[i*4+3];
          eval_whiteknit_eg_t1[i] <= eval_whiteknit_eg[i*4+0] + eval_whiteknit_eg[i*4+1] + eval_whiteknit_eg[i*4+2] + eval_whiteknit_eg[i*4+3];
          eval_whiteknit_mg_t1[i] <= eval_whiteknit_mg[i*4+0] + eval_whiteknit_mg[i*4+1] + eval_whiteknit_mg[i*4+2] + eval_whiteknit_mg[i*4+3];
          eval_blackbish_eg_t1[i] <= eval_blackbish_eg[i*4+0] + eval_blackbish_eg[i*4+1] + eval_blackbish_eg[i*4+2] + eval_blackbish_eg[i*4+3];
          eval_blackbish_mg_t1[i] <= eval_blackbish_mg[i*4+0] + eval_blackbish_mg[i*4+1] + eval_blackbish_mg[i*4+2] + eval_blackbish_mg[i*4+3];
          eval_blackknit_eg_t1[i] <= eval_blackknit_eg[i*4+0] + eval_blackknit_eg[i*4+1] + eval_blackknit_eg[i*4+2] + eval_blackknit_eg[i*4+3];
          eval_blackknit_mg_t1[i] <= eval_blackknit_mg[i*4+0] + eval_blackknit_mg[i*4+1] + eval_blackknit_mg[i*4+2] + eval_blackknit_mg[i*4+3];
          eval_blackquen_eg_t1[i] <= eval_blackquen_eg[i*4+0] + eval_blackquen_eg[i*4+1] + eval_blackquen_eg[i*4+2] + eval_blackquen_eg[i*4+3];
          eval_blackquen_mg_t1[i] <= eval_blackquen_mg[i*4+0] + eval_blackquen_mg[i*4+1] + eval_blackquen_mg[i*4+2] + eval_blackquen_mg[i*4+3];
          eval_blackrook_eg_t1[i] <= eval_blackrook_eg[i*4+0] + eval_blackrook_eg[i*4+1] + eval_blackrook_eg[i*4+2] + eval_blackrook_eg[i*4+3];
          eval_blackrook_mg_t1[i] <= eval_blackrook_mg[i*4+0] + eval_blackrook_mg[i*4+1] + eval_blackrook_mg[i*4+2] + eval_blackrook_mg[i*4+3];
          eval_whitequen_eg_t1[i] <= eval_whitequen_eg[i*4+0] + eval_whitequen_eg[i*4+1] + eval_whitequen_eg[i*4+2] + eval_whitequen_eg[i*4+3];
          eval_whitequen_mg_t1[i] <= eval_whitequen_mg[i*4+0] + eval_whitequen_mg[i*4+1] + eval_whitequen_mg[i*4+2] + eval_whitequen_mg[i*4+3];
          eval_whiterook_eg_t1[i] <= eval_whiterook_eg[i*4+0] + eval_whiterook_eg[i*4+1] + eval_whiterook_eg[i*4+2] + eval_whiterook_eg[i*4+3];
          eval_whiterook_mg_t1[i] <= eval_whiterook_mg[i*4+0] + eval_whiterook_mg[i*4+1] + eval_whiterook_mg[i*4+2] + eval_whiterook_mg[i*4+3];
          
          eval_whitebish_eg_t2[i] <= eval_whitebish_eg_t1[i];
          eval_whitebish_mg_t2[i] <= eval_whitebish_mg_t1[i];
          eval_whiteknit_eg_t2[i] <= eval_whiteknit_eg_t1[i];
          eval_whiteknit_mg_t2[i] <= eval_whiteknit_mg_t1[i];
          eval_blackbish_eg_t2[i] <= eval_blackbish_eg_t1[i];
          eval_blackbish_mg_t2[i] <= eval_blackbish_mg_t1[i];
          eval_blackknit_eg_t2[i] <= eval_blackknit_eg_t1[i];
          eval_blackknit_mg_t2[i] <= eval_blackknit_mg_t1[i];
          eval_blackquen_eg_t2[i] <= eval_blackquen_eg_t1[i];
          eval_blackquen_mg_t2[i] <= eval_blackquen_mg_t1[i];
          eval_blackrook_eg_t2[i] <= eval_blackrook_eg_t1[i];
          eval_blackrook_mg_t2[i] <= eval_blackrook_mg_t1[i];
          eval_whitequen_eg_t2[i] <= eval_whitequen_eg_t1[i];
          eval_whitequen_mg_t2[i] <= eval_whitequen_mg_t1[i];
          eval_whiterook_eg_t2[i] <= eval_whiterook_eg_t1[i];
          eval_whiterook_mg_t2[i] <= eval_whiterook_mg_t1[i];
       end

   always @(posedge clk)
     for (i = 0; i < 4; i = i + 1)
       begin
          eval_whitebish_eg_t3[i] <= eval_whitebish_eg_t2[i*4+0] + eval_whitebish_eg_t2[i*4+1] + eval_whitebish_eg_t2[i*4+2] + eval_whitebish_eg_t2[i*4+3];
          eval_whitebish_mg_t3[i] <= eval_whitebish_mg_t2[i*4+0] + eval_whitebish_mg_t2[i*4+1] + eval_whitebish_mg_t2[i*4+2] + eval_whitebish_mg_t2[i*4+3];
          eval_whiteknit_eg_t3[i] <= eval_whiteknit_eg_t2[i*4+0] + eval_whiteknit_eg_t2[i*4+1] + eval_whiteknit_eg_t2[i*4+2] + eval_whiteknit_eg_t2[i*4+3];
          eval_whiteknit_mg_t3[i] <= eval_whiteknit_mg_t2[i*4+0] + eval_whiteknit_mg_t2[i*4+1] + eval_whiteknit_mg_t2[i*4+2] + eval_whiteknit_mg_t2[i*4+3];
          eval_blackbish_eg_t3[i] <= eval_blackbish_eg_t2[i*4+0] + eval_blackbish_eg_t2[i*4+1] + eval_blackbish_eg_t2[i*4+2] + eval_blackbish_eg_t2[i*4+3];
          eval_blackbish_mg_t3[i] <= eval_blackbish_mg_t2[i*4+0] + eval_blackbish_mg_t2[i*4+1] + eval_blackbish_mg_t2[i*4+2] + eval_blackbish_mg_t2[i*4+3];
          eval_blackknit_eg_t3[i] <= eval_blackknit_eg_t2[i*4+0] + eval_blackknit_eg_t2[i*4+1] + eval_blackknit_eg_t2[i*4+2] + eval_blackknit_eg_t2[i*4+3];
          eval_blackknit_mg_t3[i] <= eval_blackknit_mg_t2[i*4+0] + eval_blackknit_mg_t2[i*4+1] + eval_blackknit_mg_t2[i*4+2] + eval_blackknit_mg_t2[i*4+3];
          eval_blackquen_eg_t3[i] <= eval_blackquen_eg_t2[i*4+0] + eval_blackquen_eg_t2[i*4+1] + eval_blackquen_eg_t2[i*4+2] + eval_blackquen_eg_t2[i*4+3];
          eval_blackquen_mg_t3[i] <= eval_blackquen_mg_t2[i*4+0] + eval_blackquen_mg_t2[i*4+1] + eval_blackquen_mg_t2[i*4+2] + eval_blackquen_mg_t2[i*4+3];
          eval_blackrook_eg_t3[i] <= eval_blackrook_eg_t2[i*4+0] + eval_blackrook_eg_t2[i*4+1] + eval_blackrook_eg_t2[i*4+2] + eval_blackrook_eg_t2[i*4+3];
          eval_blackrook_mg_t3[i] <= eval_blackrook_mg_t2[i*4+0] + eval_blackrook_mg_t2[i*4+1] + eval_blackrook_mg_t2[i*4+2] + eval_blackrook_mg_t2[i*4+3];
          eval_whitequen_eg_t3[i] <= eval_whitequen_eg_t2[i*4+0] + eval_whitequen_eg_t2[i*4+1] + eval_whitequen_eg_t2[i*4+2] + eval_whitequen_eg_t2[i*4+3];
          eval_whitequen_mg_t3[i] <= eval_whitequen_mg_t2[i*4+0] + eval_whitequen_mg_t2[i*4+1] + eval_whitequen_mg_t2[i*4+2] + eval_whitequen_mg_t2[i*4+3];
          eval_whiterook_eg_t3[i] <= eval_whiterook_eg_t2[i*4+0] + eval_whiterook_eg_t2[i*4+1] + eval_whiterook_eg_t2[i*4+2] + eval_whiterook_eg_t2[i*4+3];
          eval_whiterook_mg_t3[i] <= eval_whiterook_mg_t2[i*4+0] + eval_whiterook_mg_t2[i*4+1] + eval_whiterook_mg_t2[i*4+2] + eval_whiterook_mg_t2[i*4+3];
       end

   always @(posedge clk)
     begin
        eval_whitebish_eg_t4 <= eval_whitebish_eg_t3[0] + eval_whitebish_eg_t3[1] + eval_whitebish_eg_t3[2] + eval_whitebish_eg_t3[3];
        eval_whitebish_mg_t4 <= eval_whitebish_mg_t3[0] + eval_whitebish_mg_t3[1] + eval_whitebish_mg_t3[2] + eval_whitebish_mg_t3[3];
        eval_whiteknit_eg_t4 <= eval_whiteknit_eg_t3[0] + eval_whiteknit_eg_t3[1] + eval_whiteknit_eg_t3[2] + eval_whiteknit_eg_t3[3];
        eval_whiteknit_mg_t4 <= eval_whiteknit_mg_t3[0] + eval_whiteknit_mg_t3[1] + eval_whiteknit_mg_t3[2] + eval_whiteknit_mg_t3[3];
        eval_blackbish_eg_t4 <= eval_blackbish_eg_t3[0] + eval_blackbish_eg_t3[1] + eval_blackbish_eg_t3[2] + eval_blackbish_eg_t3[3];
        eval_blackbish_mg_t4 <= eval_blackbish_mg_t3[0] + eval_blackbish_mg_t3[1] + eval_blackbish_mg_t3[2] + eval_blackbish_mg_t3[3];
        eval_blackknit_eg_t4 <= eval_blackknit_eg_t3[0] + eval_blackknit_eg_t3[1] + eval_blackknit_eg_t3[2] + eval_blackknit_eg_t3[3];
        eval_blackknit_mg_t4 <= eval_blackknit_mg_t3[0] + eval_blackknit_mg_t3[1] + eval_blackknit_mg_t3[2] + eval_blackknit_mg_t3[3];
        eval_blackquen_eg_t4 <= eval_blackquen_eg_t3[0] + eval_blackquen_eg_t3[1] + eval_blackquen_eg_t3[2] + eval_blackquen_eg_t3[3];
        eval_blackquen_mg_t4 <= eval_blackquen_mg_t3[0] + eval_blackquen_mg_t3[1] + eval_blackquen_mg_t3[2] + eval_blackquen_mg_t3[3];
        eval_blackrook_eg_t4 <= eval_blackrook_eg_t3[0] + eval_blackrook_eg_t3[1] + eval_blackrook_eg_t3[2] + eval_blackrook_eg_t3[3];
        eval_blackrook_mg_t4 <= eval_blackrook_mg_t3[0] + eval_blackrook_mg_t3[1] + eval_blackrook_mg_t3[2] + eval_blackrook_mg_t3[3];
        eval_whitequen_eg_t4 <= eval_whitequen_eg_t3[0] + eval_whitequen_eg_t3[1] + eval_whitequen_eg_t3[2] + eval_whitequen_eg_t3[3];
        eval_whitequen_mg_t4 <= eval_whitequen_mg_t3[0] + eval_whitequen_mg_t3[1] + eval_whitequen_mg_t3[2] + eval_whitequen_mg_t3[3];
        eval_whiterook_eg_t4 <= eval_whiterook_eg_t3[0] + eval_whiterook_eg_t3[1] + eval_whiterook_eg_t3[2] + eval_whiterook_eg_t3[3];
        eval_whiterook_mg_t4 <= eval_whiterook_mg_t3[0] + eval_whiterook_mg_t3[1] + eval_whiterook_mg_t3[2] + eval_whiterook_mg_t3[3];
     end

   always @(posedge clk)
     begin
        eval_white_eg_t5 <= eval_whitebish_eg_t4 + eval_whiteknit_eg_t4 + eval_whitequen_eg_t4 + eval_whiterook_eg_t4;
        eval_white_mg_t5 <= eval_whitebish_mg_t4 + eval_whiteknit_mg_t4 + eval_whitequen_mg_t4 + eval_whiterook_mg_t4;
        eval_black_eg_t5 <= eval_blackbish_eg_t4 + eval_blackknit_eg_t4 + eval_blackquen_eg_t4 + eval_blackrook_eg_t4;
        eval_black_mg_t5 <= eval_blackbish_mg_t4 + eval_blackknit_mg_t4 + eval_blackquen_mg_t4 + eval_blackrook_mg_t4;

        eval_eg <= eval_white_eg_t5 + eval_black_eg_t5;
        eval_mg <= eval_white_mg_t5 + eval_black_mg_t5;
     end

   generate
      for (row = 0; row < 8; row = row + 1)
        begin : row_attacking_blk
           for (col = 0; col < 8; col = col + 1)
             begin : col_attacking_block
                
`include "mobility_head.vh"
                
                /* evaluate_mob_square AUTO_TEMPLATE "_\([a-z]+\)" (
                 .eval_\(.\)g (eval_@_\1g[row << 3 | col][]),
                 );*/
                evaluate_mob_square #
                      (
                       .ATTACKING_PIECE (`WHITE_KNIT),
                       .ROW (row),
                       .COL (col),
                       .EVAL_WIDTH (EVAL_WIDTH)
                       )
                ems_whiteknit
                      (/*AUTOINST*/
                       // Outputs
                       .eval_mg         (eval_whiteknit_mg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                       .eval_eg         (eval_whiteknit_eg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                       // Inputs
                       .clk             (clk),
                       .reset           (reset),
                       .board           (board[`BOARD_WIDTH-1:0]),
                       .board_valid     (board_valid));
                
                evaluate_mob_square #
                  (
                   .ATTACKING_PIECE (`WHITE_BISH),
                   .ROW (row),
                   .COL (col),
                   .EVAL_WIDTH (EVAL_WIDTH)
                   )
                ems_whitebish
                  (/*AUTOINST*/
                   // Outputs
                   .eval_mg             (eval_whitebish_mg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   .eval_eg             (eval_whitebish_eg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   // Inputs
                   .clk                 (clk),
                   .reset               (reset),
                   .board               (board[`BOARD_WIDTH-1:0]),
                   .board_valid         (board_valid));
                
                evaluate_mob_square #
                  (
                   .ATTACKING_PIECE (`WHITE_ROOK),
                   .ROW (row),
                   .COL (col),
                   .EVAL_WIDTH (EVAL_WIDTH)
                   )
                ems_whiterook
                  (/*AUTOINST*/
                   // Outputs
                   .eval_mg             (eval_whiterook_mg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   .eval_eg             (eval_whiterook_eg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   // Inputs
                   .clk                 (clk),
                   .reset               (reset),
                   .board               (board[`BOARD_WIDTH-1:0]),
                   .board_valid         (board_valid));
                
                evaluate_mob_square #
                  (
                   .ATTACKING_PIECE (`WHITE_QUEN),
                   .ROW (row),
                   .COL (col),
                   .EVAL_WIDTH (EVAL_WIDTH)
                   )
                ems_whitequen
                  (/*AUTOINST*/
                   // Outputs
                   .eval_mg             (eval_whitequen_mg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   .eval_eg             (eval_whitequen_eg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   // Inputs
                   .clk                 (clk),
                   .reset               (reset),
                   .board               (board[`BOARD_WIDTH-1:0]),
                   .board_valid         (board_valid));
                
                evaluate_mob_square #
                  (
                   .ATTACKING_PIECE (`BLACK_KNIT),
                   .ROW (row),
                   .COL (col),
                   .EVAL_WIDTH (EVAL_WIDTH)
                   )
                ems_blackknit
                  (/*AUTOINST*/
                   // Outputs
                   .eval_mg             (eval_blackknit_mg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   .eval_eg             (eval_blackknit_eg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   // Inputs
                   .clk                 (clk),
                   .reset               (reset),
                   .board               (board[`BOARD_WIDTH-1:0]),
                   .board_valid         (board_valid));
                
                evaluate_mob_square #
                  (
                   .ATTACKING_PIECE (`BLACK_BISH),
                   .ROW (row),
                   .COL (col),
                   .EVAL_WIDTH (EVAL_WIDTH)
                   )
                ems_blackbish
                  (/*AUTOINST*/
                   // Outputs
                   .eval_mg             (eval_blackbish_mg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   .eval_eg             (eval_blackbish_eg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   // Inputs
                   .clk                 (clk),
                   .reset               (reset),
                   .board               (board[`BOARD_WIDTH-1:0]),
                   .board_valid         (board_valid));
                
                evaluate_mob_square #
                  (
                   .ATTACKING_PIECE (`BLACK_ROOK),
                   .ROW (row),
                   .COL (col),
                   .EVAL_WIDTH (EVAL_WIDTH)
                   )
                ems_blackrook
                  (/*AUTOINST*/
                   // Outputs
                   .eval_mg             (eval_blackrook_mg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   .eval_eg             (eval_blackrook_eg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   // Inputs
                   .clk                 (clk),
                   .reset               (reset),
                   .board               (board[`BOARD_WIDTH-1:0]),
                   .board_valid         (board_valid));
                
                evaluate_mob_square #
                  (
                   .ATTACKING_PIECE (`BLACK_QUEN),
                   .ROW (row),
                   .COL (col),
                   .EVAL_WIDTH (EVAL_WIDTH)
                   )
                ems_blackquen
                  (/*AUTOINST*/
                   // Outputs
                   .eval_mg             (eval_blackquen_mg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   .eval_eg             (eval_blackquen_eg[row << 3 | col][EVAL_WIDTH-1:0]), // Templated
                   // Inputs
                   .clk                 (clk),
                   .reset               (reset),
                   .board               (board[`BOARD_WIDTH-1:0]),
                   .board_valid         (board_valid));
             end
        end
   endgenerate

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
