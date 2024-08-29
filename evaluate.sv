`include "vchess.vh"

module evaluate #
  (
   parameter PIECE_WIDTH = `PIECE_BITS,
   parameter SIDE_WIDTH = PIECE_WIDTH * 8,
   parameter BOARD_WIDTH = SIDE_WIDTH * 8,
   parameter EVAL_WIDTH = 22
   )
   (
    input                                clk,
    input                                reset,

    input                                board_valid,
    input [BOARD_WIDTH - 1:0]            board_in,
    input                                white_to_move_in,
    input [3:0]                          castle_mask_in,
    input [3:0]                          en_passant_col_in,

    input                                clear_eval,

    output reg signed [EVAL_WIDTH - 1:0] eval,
    output reg                           eval_valid
    );
   
   localparam VALUE_PAWN =   100;
   localparam VALUE_KNIT =   310;
   localparam VALUE_BISH =   320;
   localparam VALUE_ROOK =   500;
   localparam VALUE_QUEN =   900;
   localparam VALUE_KING = 10000;

   reg [BOARD_WIDTH - 1:0]               board;
   reg signed [$clog2(VALUE_KING) - 1 + 1:0] value [`EMPTY_POSN:`PIECE_KING];
   reg signed [$clog2(VALUE_KING) - 1 + 1:0] pst [`EMPTY_POSN:`PIECE_KING][0:63];
   reg signed [$clog2(VALUE_KING) - 1 + 2:0] score [0:7][0:7];
   reg [$clog2(BOARD_WIDTH) - 1:0]           idx [0:7][0:7];
   reg signed [EVAL_WIDTH - 1:0]             sum_a [0:7][0:1];
   reg signed [EVAL_WIDTH - 1:0]             sum_b [0:3];

   integer                                   i, ri, y, x;

   localparam STATE_IDLE = 0;
   localparam STATE_SCORE = 1;
   localparam STATE_SUM_0 = 2;
   localparam STATE_SUM_1 = 3;
   localparam STATE_DONE = 4;

   reg [3:0]                                 state = STATE_IDLE;

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
              eval_valid <= 0;
              board <= board_in;
              if (board_valid)
                state <= STATE_SCORE;
           end
         STATE_SCORE :
           begin
              for (y = 0; y < 8; y = y + 1)
                for (x = 0; x < 8; x = x + 1)
                  score[y][x] <= value[board[idx[y][x]+:PIECE_WIDTH - 1]];
              state <= STATE_SUM_0;
           end
         STATE_SUM_0 :
           begin
              for (y = 0; y < 8; y = y + 1)
                for (x = 0; x < 8; x = x + 4)
                  sum_a[y][x / 4] <= score[y][x + 0] + score[y][x + 1] + score[y][x + 2] + score[y][x + 3];
              state <= STATE_SUM_1;
           end
         STATE_SUM_1 :
           begin
              for (y = 0; y < 8; y = y + 2)
                sum_b[y / 2] <= sum_a[y + 0][0] + sum_a[y + 0][1] + sum_a[y + 1][0] + sum_a[y + 1][1];
              state <= STATE_DONE;
           end
         STATE_DONE :
           begin
              eval <= sum_b[0] + sum_b[1] + sum_b[2] + sum_b[3];
              eval_valid <= 1;
              if (clear_eval)
                state <= STATE_IDLE;
           end
       endcase

   initial
     begin
        for (y = 0; y < 8; y = y + 1)
          begin
             ri = y * SIDE_WIDTH;
             for (x = 0; x < 8; x = x + 1)
               idx[y][x] = ri + x * PIECE_WIDTH;
          end
        
        value[`EMPTY_POSN] = 0;
        value[`PIECE_PAWN] = VALUE_PAWN;
        value[`PIECE_KNIT] = VALUE_KNIT;
        value[`PIECE_BISH] = VALUE_BISH;
        value[`PIECE_ROOK] = VALUE_ROOK;
        value[`PIECE_QUEN] = VALUE_QUEN;
        value[`PIECE_KING] = VALUE_KING;

        for (i = 0; i < 64; i = i + 1)
          pst[`PIECE_QUEN][i] = 0;
        
        pst[`PIECE_PAWN][ 0] =   0;pst[`PIECE_PAWN][ 1] =   0;pst[`PIECE_PAWN][ 2] =   0;pst[`PIECE_PAWN][ 3] =   0;
        pst[`PIECE_PAWN][ 4] =   0;pst[`PIECE_PAWN][ 5] =   0;pst[`PIECE_PAWN][ 6] =   0;pst[`PIECE_PAWN][ 7] =   0;
        pst[`PIECE_PAWN][ 8] =   0;pst[`PIECE_PAWN][ 9] =   0;pst[`PIECE_PAWN][10] =   0;pst[`PIECE_PAWN][11] = -25;
        pst[`PIECE_PAWN][12] = -25;pst[`PIECE_PAWN][13] =   0;pst[`PIECE_PAWN][14] =   0;pst[`PIECE_PAWN][15] =   0;
        pst[`PIECE_PAWN][16] =   0;pst[`PIECE_PAWN][17] =   0;pst[`PIECE_PAWN][18] =   0;pst[`PIECE_PAWN][19] =   5;
        pst[`PIECE_PAWN][20] =   5;pst[`PIECE_PAWN][21] =   0;pst[`PIECE_PAWN][22] =   0;pst[`PIECE_PAWN][23] =   0;
        pst[`PIECE_PAWN][24] =   0;pst[`PIECE_PAWN][25] =   0;pst[`PIECE_PAWN][26] =   0;pst[`PIECE_PAWN][27] =  10;
        pst[`PIECE_PAWN][28] =  10;pst[`PIECE_PAWN][29] =   0;pst[`PIECE_PAWN][30] =   0;pst[`PIECE_PAWN][31] =   0;
        pst[`PIECE_PAWN][32] =   0;pst[`PIECE_PAWN][33] =   0;pst[`PIECE_PAWN][34] =   0;pst[`PIECE_PAWN][35] =  15;
        pst[`PIECE_PAWN][36] =  15;pst[`PIECE_PAWN][37] =   0;pst[`PIECE_PAWN][38] =   0;pst[`PIECE_PAWN][39] =   0;
        pst[`PIECE_PAWN][40] =   0;pst[`PIECE_PAWN][41] =   0;pst[`PIECE_PAWN][42] =   0;pst[`PIECE_PAWN][43] =   0;
        pst[`PIECE_PAWN][44] =   0;pst[`PIECE_PAWN][45] =   0;pst[`PIECE_PAWN][46] =   0;pst[`PIECE_PAWN][47] =   0;
        pst[`PIECE_PAWN][48] =   0;pst[`PIECE_PAWN][49] =   0;pst[`PIECE_PAWN][50] =   0;pst[`PIECE_PAWN][51] =   0;
        pst[`PIECE_PAWN][52] =   0;pst[`PIECE_PAWN][53] =   0;pst[`PIECE_PAWN][54] =   0;pst[`PIECE_PAWN][55] =   0;
        pst[`PIECE_PAWN][56] =   0;pst[`PIECE_PAWN][57] =   0;pst[`PIECE_PAWN][58] =   0;pst[`PIECE_PAWN][59] =   0;
        pst[`PIECE_PAWN][60] =   0;pst[`PIECE_PAWN][61] =   0;pst[`PIECE_PAWN][62] =   0;pst[`PIECE_PAWN][63] =   0;

        pst[`PIECE_KNIT][ 0] = -40;pst[`PIECE_KNIT][ 1] = -30;pst[`PIECE_KNIT][ 2] = -25;pst[`PIECE_KNIT][ 3] = -25;
        pst[`PIECE_KNIT][ 4] = -25;pst[`PIECE_KNIT][ 5] = -25;pst[`PIECE_KNIT][ 6] = -30;pst[`PIECE_KNIT][ 7] = -40;
        pst[`PIECE_KNIT][ 8] = -30;pst[`PIECE_KNIT][ 9] =   0;pst[`PIECE_KNIT][10] =   0;pst[`PIECE_KNIT][11] =   5;
        pst[`PIECE_KNIT][12] =   5;pst[`PIECE_KNIT][13] =   0;pst[`PIECE_KNIT][14] =   0;pst[`PIECE_KNIT][15] = -30;
        pst[`PIECE_KNIT][16] = -30;pst[`PIECE_KNIT][17] =   0;pst[`PIECE_KNIT][18] =  10;pst[`PIECE_KNIT][19] =   0;
        pst[`PIECE_KNIT][20] =   0;pst[`PIECE_KNIT][21] =  10;pst[`PIECE_KNIT][22] =   0;pst[`PIECE_KNIT][23] = -30;
        pst[`PIECE_KNIT][24] = -30;pst[`PIECE_KNIT][25] =   0;pst[`PIECE_KNIT][26] =   0;pst[`PIECE_KNIT][27] =  15;
        pst[`PIECE_KNIT][28] =  15;pst[`PIECE_KNIT][29] =   0;pst[`PIECE_KNIT][30] =   0;pst[`PIECE_KNIT][31] = -30;
        pst[`PIECE_KNIT][32] = -30;pst[`PIECE_KNIT][33] =   0;pst[`PIECE_KNIT][34] =   0;pst[`PIECE_KNIT][35] =  15;
        pst[`PIECE_KNIT][36] =  15;pst[`PIECE_KNIT][37] =   0;pst[`PIECE_KNIT][38] =   0;pst[`PIECE_KNIT][39] = -30;
        pst[`PIECE_KNIT][40] = -30;pst[`PIECE_KNIT][41] =   0;pst[`PIECE_KNIT][42] =   0;pst[`PIECE_KNIT][43] =   0;
        pst[`PIECE_KNIT][44] =   0;pst[`PIECE_KNIT][45] =   0;pst[`PIECE_KNIT][46] =   0;pst[`PIECE_KNIT][47] = -30;
        pst[`PIECE_KNIT][48] = -30;pst[`PIECE_KNIT][49] =   0;pst[`PIECE_KNIT][50] =   0;pst[`PIECE_KNIT][51] =   0;
        pst[`PIECE_KNIT][52] =   0;pst[`PIECE_KNIT][53] =   0;pst[`PIECE_KNIT][54] =   0;pst[`PIECE_KNIT][55] = -30;
        pst[`PIECE_KNIT][56] = -40;pst[`PIECE_KNIT][57] = -25;pst[`PIECE_KNIT][58] = -25;pst[`PIECE_KNIT][59] = -25;
        pst[`PIECE_KNIT][60] = -25;pst[`PIECE_KNIT][61] = -25;pst[`PIECE_KNIT][62] = -25;pst[`PIECE_KNIT][63] = -40;

        pst[`PIECE_BISH][ 0] = -10;pst[`PIECE_BISH][ 1] = -20;pst[`PIECE_BISH][ 2] = -20;pst[`PIECE_BISH][ 3] = -20;
        pst[`PIECE_BISH][ 4] = -20;pst[`PIECE_BISH][ 5] = -20;pst[`PIECE_BISH][ 6] = -20;pst[`PIECE_BISH][ 7] = -10;
        pst[`PIECE_BISH][ 8] = -10;pst[`PIECE_BISH][ 9] =   5;pst[`PIECE_BISH][10] =   0;pst[`PIECE_BISH][11] =   0;
        pst[`PIECE_BISH][12] =   0;pst[`PIECE_BISH][13] =   0;pst[`PIECE_BISH][14] =   5;pst[`PIECE_BISH][15] = -10;
        pst[`PIECE_BISH][16] = -10;pst[`PIECE_BISH][17] =   0;pst[`PIECE_BISH][18] =   5;pst[`PIECE_BISH][19] =   0;
        pst[`PIECE_BISH][20] =   0;pst[`PIECE_BISH][21] =   5;pst[`PIECE_BISH][22] =   0;pst[`PIECE_BISH][23] = -10;
        pst[`PIECE_BISH][24] = -10;pst[`PIECE_BISH][25] =   0;pst[`PIECE_BISH][26] =   5;pst[`PIECE_BISH][27] =  10;
        pst[`PIECE_BISH][28] =  10;pst[`PIECE_BISH][29] =   5;pst[`PIECE_BISH][30] =   0;pst[`PIECE_BISH][31] = -10;
        pst[`PIECE_BISH][32] = -10;pst[`PIECE_BISH][33] =   0;pst[`PIECE_BISH][34] =   0;pst[`PIECE_BISH][35] =  10;
        pst[`PIECE_BISH][36] =  10;pst[`PIECE_BISH][37] =   0;pst[`PIECE_BISH][38] =   0;pst[`PIECE_BISH][39] = -10;
        pst[`PIECE_BISH][40] = -10;pst[`PIECE_BISH][41] =   0;pst[`PIECE_BISH][42] =   5;pst[`PIECE_BISH][43] =   0;
        pst[`PIECE_BISH][44] =   0;pst[`PIECE_BISH][45] =   5;pst[`PIECE_BISH][46] =   0;pst[`PIECE_BISH][47] = -10;
        pst[`PIECE_BISH][48] = -10;pst[`PIECE_BISH][49] =   5;pst[`PIECE_BISH][50] =   0;pst[`PIECE_BISH][51] =   0;
        pst[`PIECE_BISH][52] =   0;pst[`PIECE_BISH][53] =   0;pst[`PIECE_BISH][54] =   5;pst[`PIECE_BISH][55] = -10;
        pst[`PIECE_BISH][56] = -10;pst[`PIECE_BISH][57] =   0;pst[`PIECE_BISH][58] =   0;pst[`PIECE_BISH][59] =   0;
        pst[`PIECE_BISH][60] =   0;pst[`PIECE_BISH][61] =   0;pst[`PIECE_BISH][62] =   0;pst[`PIECE_BISH][63] = -10;

        pst[`PIECE_ROOK][ 0] =   0;pst[`PIECE_ROOK][ 1] =   0;pst[`PIECE_ROOK][ 2] =   0;pst[`PIECE_ROOK][ 3] =   5;
        pst[`PIECE_ROOK][ 4] =   5;pst[`PIECE_ROOK][ 5] =   0;pst[`PIECE_ROOK][ 6] =   0;pst[`PIECE_ROOK][ 7] =   0;
        pst[`PIECE_ROOK][ 8] =   0;pst[`PIECE_ROOK][ 9] =   0;pst[`PIECE_ROOK][10] =   0;pst[`PIECE_ROOK][11] =   0;
        pst[`PIECE_ROOK][12] =   0;pst[`PIECE_ROOK][13] =   0;pst[`PIECE_ROOK][14] =   0;pst[`PIECE_ROOK][15] =   0;
        pst[`PIECE_ROOK][16] =   0;pst[`PIECE_ROOK][17] =   0;pst[`PIECE_ROOK][18] =   0;pst[`PIECE_ROOK][19] =   0;
        pst[`PIECE_ROOK][20] =   0;pst[`PIECE_ROOK][21] =   0;pst[`PIECE_ROOK][22] =   0;pst[`PIECE_ROOK][23] =   0;
        pst[`PIECE_ROOK][24] =   0;pst[`PIECE_ROOK][25] =   0;pst[`PIECE_ROOK][26] =   0;pst[`PIECE_ROOK][27] =   0;
        pst[`PIECE_ROOK][28] =   0;pst[`PIECE_ROOK][29] =   0;pst[`PIECE_ROOK][30] =   0;pst[`PIECE_ROOK][31] =   0;
        pst[`PIECE_ROOK][32] =   0;pst[`PIECE_ROOK][33] =   0;pst[`PIECE_ROOK][34] =   0;pst[`PIECE_ROOK][35] =   0;
        pst[`PIECE_ROOK][36] =   0;pst[`PIECE_ROOK][37] =   0;pst[`PIECE_ROOK][38] =   0;pst[`PIECE_ROOK][39] =   0;
        pst[`PIECE_ROOK][40] =   0;pst[`PIECE_ROOK][41] =   0;pst[`PIECE_ROOK][42] =   0;pst[`PIECE_ROOK][43] =   0;
        pst[`PIECE_ROOK][44] =   0;pst[`PIECE_ROOK][45] =   0;pst[`PIECE_ROOK][46] =   0;pst[`PIECE_ROOK][47] =   0;
        pst[`PIECE_ROOK][48] =  10;pst[`PIECE_ROOK][49] =  10;pst[`PIECE_ROOK][50] =  10;pst[`PIECE_ROOK][51] =  10;
        pst[`PIECE_ROOK][52] =  10;pst[`PIECE_ROOK][53] =  10;pst[`PIECE_ROOK][54] =  10;pst[`PIECE_ROOK][55] =  10;
        pst[`PIECE_ROOK][56] =   0;pst[`PIECE_ROOK][57] =   0;pst[`PIECE_ROOK][58] =   0;pst[`PIECE_ROOK][59] =   0;
        pst[`PIECE_ROOK][60] =   0;pst[`PIECE_ROOK][61] =   0;pst[`PIECE_ROOK][62] =   0;pst[`PIECE_ROOK][63] =   0;

        pst[`PIECE_KING][ 0] =  10;pst[`PIECE_KING][ 1] =  15;pst[`PIECE_KING][ 2] = -15;pst[`PIECE_KING][ 3] = -15;
        pst[`PIECE_KING][ 4] = -15;pst[`PIECE_KING][ 5] = -15;pst[`PIECE_KING][ 6] =  15;pst[`PIECE_KING][ 7] =  10;
        pst[`PIECE_KING][ 8] = -25;pst[`PIECE_KING][ 9] = -25;pst[`PIECE_KING][10] = -25;pst[`PIECE_KING][11] = -25;
        pst[`PIECE_KING][12] = -25;pst[`PIECE_KING][13] = -25;pst[`PIECE_KING][14] = -25;pst[`PIECE_KING][15] = -25;
        pst[`PIECE_KING][16] = -25;pst[`PIECE_KING][17] = -25;pst[`PIECE_KING][18] = -25;pst[`PIECE_KING][19] = -25;
        pst[`PIECE_KING][20] = -25;pst[`PIECE_KING][21] = -25;pst[`PIECE_KING][22] = -25;pst[`PIECE_KING][23] = -25;
        pst[`PIECE_KING][24] = -25;pst[`PIECE_KING][25] = -25;pst[`PIECE_KING][26] = -25;pst[`PIECE_KING][27] = -25;
        pst[`PIECE_KING][28] = -25;pst[`PIECE_KING][29] = -25;pst[`PIECE_KING][30] = -25;pst[`PIECE_KING][31] = -25;
        pst[`PIECE_KING][32] = -25;pst[`PIECE_KING][33] = -25;pst[`PIECE_KING][34] = -25;pst[`PIECE_KING][35] = -25;
        pst[`PIECE_KING][36] = -25;pst[`PIECE_KING][37] = -25;pst[`PIECE_KING][38] = -25;pst[`PIECE_KING][39] = -25;
        pst[`PIECE_KING][40] = -25;pst[`PIECE_KING][41] = -25;pst[`PIECE_KING][42] = -25;pst[`PIECE_KING][43] = -25;
        pst[`PIECE_KING][44] = -25;pst[`PIECE_KING][45] = -25;pst[`PIECE_KING][46] = -25;pst[`PIECE_KING][47] = -25;
        pst[`PIECE_KING][48] = -25;pst[`PIECE_KING][49] = -25;pst[`PIECE_KING][50] = -25;pst[`PIECE_KING][51] = -25;
        pst[`PIECE_KING][52] = -25;pst[`PIECE_KING][53] = -25;pst[`PIECE_KING][54] = -25;pst[`PIECE_KING][55] = -25;
        pst[`PIECE_KING][56] = -25;pst[`PIECE_KING][57] = -25;pst[`PIECE_KING][58] = -25;pst[`PIECE_KING][59] = -25;
        pst[`PIECE_KING][60] = -25;pst[`PIECE_KING][61] = -25;pst[`PIECE_KING][62] = -25;pst[`PIECE_KING][63] = -25;
     end

endmodule
