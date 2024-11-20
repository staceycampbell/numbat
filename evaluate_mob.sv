`include "vchess.vh"

module evaluate_mob #
  (
   parameter EVAL_WIDTH = 0
   )
   (
    input                            clk,
    input                            reset,

    input                            board_valid,
    input [`BOARD_WIDTH - 1:0]       board,
    input                            clear_eval,

    output signed [EVAL_WIDTH - 1:0] eval_mg,
    output signed [EVAL_WIDTH - 1:0] eval_eg,
    output reg                       eval_valid
    );
   
   localparam LATENCY_COUNT = 7;

   reg                               board_valid_r;
   reg [$clog2(LATENCY_COUNT) + 1 - 1:0] latency;

   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   genvar                                row, col;
   
   wire signed [EVAL_WIDTH-1:0]          eval_whitebish_eg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_whitebish_mg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_whiteknit_eg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_whiteknit_mg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_blackbish_eg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_blackbish_mg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_blackknit_eg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_blackknit_mg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_blackquen_eg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_blackquen_mg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_blackrook_eg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_blackrook_mg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_whitequen_eg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_whitequen_mg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_whiterook_eg [0:63];
   wire signed [EVAL_WIDTH-1:0]          eval_whiterook_mg [0:63];
   
   localparam STATE_IDLE = 0;
   localparam STATE_LATENCY = 1;
   localparam STATE_WAIT_CLEAR = 2;

   reg [1:0]                             state = STATE_IDLE;
   
   always @(posedge clk)
     begin
        board_valid_r <= board_valid;
     end

   always @(posedge clk)
     if (reset)
       begin
          state <= STATE_IDLE;
          eval_valid <= 0;
       end
     else
       case (state)
         STATE_IDLE :
           begin
              latency <= 1;
              eval_valid <= 0;
              if (board_valid && ~board_valid_r)
                state <= STATE_LATENCY;
           end
         STATE_LATENCY :
           begin
              latency <= latency + 1;
              if (latency == LATENCY_COUNT - 1)
                begin
                   eval_valid <= 1;
                   state <= STATE_WAIT_CLEAR;
                end
           end
         STATE_WAIT_CLEAR :
           if (clear_eval)
             state <= STATE_IDLE;
         default :
           state <= STATE_IDLE;
       endcase // case (state)
   
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

endmodule
