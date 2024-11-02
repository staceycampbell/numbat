`include "vchess.vh"

// notes:
// - if white_to_move is set then we are evaluating black moves in anticipation of white to move
// - black/white pawn evaluation is symmetric, so for black flip rows as though white and negate
//   eval on output

module evaluate_pawns #
  (
   parameter EVAL_WIDTH = 0
   )
   (
    input                            clk,
    input                            reset,

    input                            board_valid,
    input [`BOARD_WIDTH - 1:0]       board,
    input                            clear_eval,
    input                            white_to_move,

    output signed [EVAL_WIDTH - 1:0] eval_mg,
    output signed [EVAL_WIDTH - 1:0] eval_eg,
    output reg                       eval_valid
    );

   localparam LATENCY_COUNT = 8;

   reg                               board_valid_r;
   reg [$clog2(LATENCY_COUNT) + 1 - 1:0] latency;
   reg signed [EVAL_WIDTH - 1:0]         pawns_isolated_mg [0:7];
   reg signed [EVAL_WIDTH - 1:0]         pawns_isolated_eg [0:7];
   reg [63:0]                            board_neutral_t1;
   reg [7:0]                             col_with_pawn_t1;
   reg signed [EVAL_WIDTH - 1:0]         isolated_mg_t2 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         isolated_eg_t2 [0:63];
   reg signed [EVAL_WIDTH - 1:0]         isolated_mg_t3 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         isolated_eg_t3 [0:15];
   reg signed [EVAL_WIDTH - 1:0]         isolated_mg_t4 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         isolated_eg_t4 [0:3];
   reg signed [EVAL_WIDTH - 1:0]         isolated_mg_t5;
   reg signed [EVAL_WIDTH - 1:0]         isolated_eg_t5;
   reg signed [EVAL_WIDTH - 1:0]         eval_mg_t6;
   reg signed [EVAL_WIDTH - 1:0]         eval_eg_t6;

   reg [2:0]                             row_flip [0:1][0:7];

   integer                               i, row, col;

   wire [`PIECE_WIDTH - 1:0]             pawn = white_to_move ? `BLACK_PAWN : `WHITE_PAWN;

   assign eval_mg = white_to_move ? -eval_mg_t6 : eval_mg_t6;
   assign eval_eg = white_to_move ? -eval_eg_t6 : eval_eg_t6;

   initial
     begin
        // $dumpfile("wave.vcd");
        // for (i = 0; i < 4; i = i + 1)
        //  $dumpvars(0, isolated_mg_t4[i]);
     end

   always @(posedge clk)
     begin
        board_valid_r <= board_valid;

        col_with_pawn_t1 <= 0;
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            begin
               board_neutral_t1[(row_flip[white_to_move][row] << 3) | col] <= board[(row << 3 | col)  * `PIECE_WIDTH+:`PIECE_WIDTH] == pawn;
               if (board[(row << 3 | col)  * `PIECE_WIDTH+:`PIECE_WIDTH] == pawn)
                 col_with_pawn_t1[col] <= 1;
            end

        eval_mg_t6 <= isolated_mg_t5;
        eval_eg_t6 <= isolated_eg_t5;
     end

   // isloated pawns
   always @(posedge clk)
     begin
        for (row = 0; row < 8; row = row + 1)
          for (col = 0; col < 8; col = col + 1)
            begin
               isolated_mg_t2[row << 3 | col] <= 0;
               isolated_eg_t2[row << 3 | col] <= 0;
               if (board_neutral_t1[row << 3 | col])
                 if (col == 0)
                   begin
                      if (col_with_pawn_t1[1] == 0)
                        begin
                           isolated_mg_t2[row << 3 | col] <= pawns_isolated_mg[col];
                           isolated_eg_t2[row << 3 | col] <= pawns_isolated_eg[col];
                        end
                   end
                 else if (col == 7)
                   begin
                      if (col_with_pawn_t1[6] == 0)
                        begin
                           isolated_mg_t2[row << 3 | col] <= pawns_isolated_mg[col];
                           isolated_eg_t2[row << 3 | col] <= pawns_isolated_eg[col];
                        end
                   end
                 else
                   if (col_with_pawn_t1[col - 1] == 0 && col_with_pawn_t1[col + 1] == 0)
                     begin
                        isolated_mg_t2[row << 3 | col] <= pawns_isolated_mg[col];
                        isolated_eg_t2[row << 3 | col] <= pawns_isolated_eg[col];
                     end
            end
        for (i = 0; i < 16; i = i + 1)
          begin
             isolated_mg_t3[i] <= isolated_mg_t2[i * 4 + 0] + isolated_mg_t2[i * 4 + 1] + isolated_mg_t2[i * 4 + 2] + isolated_mg_t2[i * 4 + 3];
             isolated_eg_t3[i] <= isolated_eg_t2[i * 4 + 0] + isolated_eg_t2[i * 4 + 1] + isolated_eg_t2[i * 4 + 2] + isolated_eg_t2[i * 4 + 3];
          end
        for (i = 0; i < 4; i = i + 1)
          begin
             isolated_mg_t4[i] <= isolated_mg_t3[i * 4 + 0] + isolated_mg_t3[i * 4 + 1] + isolated_mg_t3[i * 4 + 2] + isolated_mg_t3[i * 4 + 3];
             isolated_eg_t4[i] <= isolated_eg_t3[i * 4 + 0] + isolated_eg_t3[i * 4 + 1] + isolated_eg_t3[i * 4 + 2] + isolated_eg_t3[i * 4 + 3];
          end
        isolated_mg_t5 <= isolated_mg_t4[0] + isolated_mg_t4[1] + isolated_mg_t4[2] + isolated_mg_t4[3];
        isolated_eg_t5 <= isolated_eg_t4[0] + isolated_eg_t4[1] + isolated_eg_t4[2] + isolated_eg_t4[3];
     end

   localparam STATE_IDLE = 0;
   localparam STATE_LATENCY = 1;
   localparam STATE_WAIT_CLEAR = 2;

   reg [1:0]                                 state = STATE_IDLE;

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
              latency <= 0;
              eval_valid <= 0;
              if (board_valid && ~board_valid_r)
                state <= STATE_LATENCY;
           end
         STATE_LATENCY :
           begin
              latency <= latency + 1;
              if (latency == LATENCY_COUNT - 1)
                state <= STATE_WAIT_CLEAR;
           end
         STATE_WAIT_CLEAR :
           begin
              eval_valid <= 1;
              if (clear_eval)
                state <= STATE_IDLE;
           end
         default :
           state <= STATE_IDLE;
       endcase

   initial
     begin
        for (i = 0; i < 8; i = i + 1)
          begin
             row_flip[0][i] = i;
             row_flip[1][i] = 7 - i;
          end

`include "evaluate_pawns.vh"
     end

endmodule
