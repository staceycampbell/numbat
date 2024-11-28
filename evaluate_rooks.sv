`include "vchess.vh"

module evaluate_rooks #
  (
   parameter EVAL_WIDTH = 0,
   parameter WHITE_ROOKS = 0
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

   localparam LATENCY_COUNT = 5;

   localparam OPPONENT_PAWN = WHITE_ROOKS ? `BLACK_PAWN : `WHITE_PAWN;
   localparam MY_ROOK = WHITE_ROOKS ? `WHITE_ROOK : `BLACK_ROOK;

   reg [7:0]                             column_open_mask_t1 [0:7];
   reg [7:0]                             column_half_open_mask_t1 [0:7];
   reg signed [EVAL_WIDTH - 1:0]         open_eval_mg_t2 [0:63], open_eval_eg_t2 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         open_eval_mg_t3 [0:7], open_eval_eg_t3 [0:7];
   reg signed [EVAL_WIDTH - 1:0]         open_eval_mg_t4, open_eval_eg_t4;
   
   // should be empty
   /*AUTOREGINPUT*/

   /*AUTOWIRE*/

   integer                               row, col, i;
   genvar                                c;
   
   wire [7:0]                            column_open_t1;
   wire [7:0]                            column_half_open_t1;

   generate
      for (c = 0; c < 8; c = c + 1)
        begin : mask_blk
           assign column_open_t1[c] = column_open_mask_t1[c] == 8'hFF;
           assign column_half_open_t1[c] = column_half_open_mask_t1[c] == 8'hFF & ~column_open_t1[c];
        end
   endgenerate
   
   always @(posedge clk)
     begin
        for (col = 0; col < 8; col = col + 1)
          for (row = 0; row < 8; row = row + 1)
            begin
               column_open_mask_t1[col][row] <= board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_ROOK ||
                     board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH] == `EMPTY_POSN;
               column_half_open_mask_t1[col][row] <= board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_ROOK ||
                                                     board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH] == `EMPTY_POSN ||
                                                     board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH] == OPPONENT_PAWN;
            end
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            if (board[(row << 3 | col) * `PIECE_WIDTH+:`PIECE_WIDTH] == MY_ROOK)
              if (column_open_t1[col])
                begin
                   open_eval_mg_t2[row << 3 | col] <= 35;
                   open_eval_eg_t2[row << 3 | col] <= 20;
                end
              else if (column_half_open_t1[col])
                begin
                   open_eval_mg_t2[row << 3 | col] <= 10;
                   open_eval_eg_t2[row << 3 | col] <= 10;
                end
              else
                begin
                   open_eval_mg_t2[row << 3 | col] <= 0;
                   open_eval_eg_t2[row << 3 | col] <= 0;
                end
            else
              begin
                 open_eval_mg_t2[row << 3 | col] <= 0;
                 open_eval_eg_t2[row << 3 | col] <= 0;
              end
        for (i = 0; i < 8; i = i + 1)
          begin
             open_eval_mg_t3[i] <= open_eval_mg_t2[i << 3 | 0] + open_eval_mg_t2[i << 3 | 1] + open_eval_mg_t2[i << 3 | 2] + open_eval_mg_t2[i << 3 | 3] +
                 open_eval_mg_t2[i << 3 | 4] + open_eval_mg_t2[i << 3 | 5] + open_eval_mg_t2[i << 3 | 6] + open_eval_mg_t2[i << 3 | 7];
             open_eval_eg_t3[i] <= open_eval_eg_t2[i << 3 | 0] + open_eval_eg_t2[i << 3 | 1] + open_eval_eg_t2[i << 3 | 2] + open_eval_eg_t2[i << 3 | 3] +
                                   open_eval_eg_t2[i << 3 | 4] + open_eval_eg_t2[i << 3 | 5] + open_eval_eg_t2[i << 3 | 6] + open_eval_eg_t2[i << 3 | 7];
          end
        open_eval_mg_t4 <= open_eval_mg_t3[0] + open_eval_mg_t3[1] + open_eval_mg_t3[2] + open_eval_mg_t3[3] +
                           open_eval_mg_t3[4] + open_eval_mg_t3[5] + open_eval_mg_t3[6] + open_eval_mg_t3[7];
        open_eval_eg_t4 <= open_eval_eg_t3[0] + open_eval_eg_t3[1] + open_eval_eg_t3[2] + open_eval_eg_t3[3] +
                           open_eval_eg_t3[4] + open_eval_eg_t3[5] + open_eval_eg_t3[6] + open_eval_eg_t3[7];
        if (WHITE_ROOKS)
          begin
             eval_mg <= open_eval_mg_t4;
             eval_eg <= open_eval_eg_t4;
          end
        else
          begin
             eval_mg <= -open_eval_mg_t4;
             eval_eg <= -open_eval_eg_t4;
          end
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
