`include "vchess.vh"

module evaluate #
  (
   parameter EVAL_WIDTH = 22
   )
   (
    input                                clk,
    input                                reset,

    input                                use_random_bit,
    input                                random_bit,

    input                                board_valid,
    input [5:0]                          white_pop,
    input [5:0]                          black_pop,
    input                                is_attacking_done,
    input [`BOARD_WIDTH - 1:0]           board_in,
    input                                clear_eval,
    input                                white_to_move,

    output reg signed [EVAL_WIDTH - 1:0] eval,
    output reg                           eval_valid
    );

   localparam POP_SHIFT = 1;
   localparam POP_SCORE_WIDTH = POP_SHIFT + 6 + 1; // signed

   localparam VALUE_PAWN = 100;
   localparam VALUE_KNIT = 310;
   localparam VALUE_BISH = 320;
   localparam VALUE_ROOK = 500;
   localparam VALUE_QUEN = 900;
   localparam VALUE_KING = `GLOBAL_VALUE_KING;

   reg [`BOARD_WIDTH - 1:0]              board;
   reg signed [$clog2(VALUE_KING) - 1 + 1:0] value [`EMPTY_POSN:`BLACK_KING];
   reg signed [$clog2(VALUE_KING) - 1 + 1:0] pst [`EMPTY_POSN:`BLACK_KING][0:63];
   reg [$clog2(`BOARD_WIDTH) - 1:0]          idx [0:7][0:7];
   reg signed [POP_SCORE_WIDTH - 1:0]        black_pop_score, white_pop_score;
   reg signed [POP_SCORE_WIDTH + 1 - 1:0]    pop_score;
   
   reg signed [$clog2(VALUE_KING) - 1 + 2:0] score [0:7][0:7];
   reg signed [EVAL_WIDTH - 1:0]             sum_a [0:7][0:1];
   reg signed [EVAL_WIDTH - 1:0]             sum_b [0:3];

   reg [1:0]                                 insufficent_score_white [0:63];
   reg [1:0]                                 insufficent_score_black [0:63];
   reg [8:0]                                 insufficent_score_white_accum;
   reg [8:0]                                 insufficent_score_black_accum;

   reg   signed [2:0]                        random_bit_final;

   integer                                   i, ri, y, x;

   always @(posedge clk)
     begin
        for (i = 0; i < 64; i = i + 1)
          begin
             if (board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_PAWN ||
                 board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_ROOK ||
                 board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_QUEN)
               insufficent_score_white[i] <= 2'b11;
             else if (board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_BISH ||
                      board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `WHITE_KNIT)
               insufficent_score_white[i] <= 2'b01;
             else
               insufficent_score_white[i] <= 2'b00;
             if (board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_PAWN ||
                 board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_ROOK ||
                 board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_QUEN)
               insufficent_score_white[i] <= 2'b11;
             else if (board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_BISH ||
                      board[i * `PIECE_WIDTH+:`PIECE_WIDTH] == `BLACK_KNIT)
               insufficent_score_black[i] <= 2'b01;
             else
               insufficent_score_black[i] <= 2'b00;
          end

        insufficent_score_white_accum <= insufficent_score_white[ 0] + insufficent_score_white[ 1] +
                                         insufficent_score_white[ 2] + insufficent_score_white[ 3] +
                                         insufficent_score_white[ 4] + insufficent_score_white[ 5] +
                                         insufficent_score_white[ 6] + insufficent_score_white[ 7] +
                                         insufficent_score_white[ 8] + insufficent_score_white[ 9] +
                                         insufficent_score_white[10] + insufficent_score_white[11] +
                                         insufficent_score_white[12] + insufficent_score_white[13] +
                                         insufficent_score_white[14] + insufficent_score_white[15] +
                                         insufficent_score_white[16] + insufficent_score_white[17] +
                                         insufficent_score_white[18] + insufficent_score_white[19] +
                                         insufficent_score_white[20] + insufficent_score_white[21] +
                                         insufficent_score_white[22] + insufficent_score_white[23] +
                                         insufficent_score_white[24] + insufficent_score_white[25] +
                                         insufficent_score_white[26] + insufficent_score_white[27] +
                                         insufficent_score_white[28] + insufficent_score_white[29] +
                                         insufficent_score_white[30] + insufficent_score_white[31] +
                                         insufficent_score_white[32] + insufficent_score_white[33] +
                                         insufficent_score_white[34] + insufficent_score_white[35] +
                                         insufficent_score_white[36] + insufficent_score_white[37] +
                                         insufficent_score_white[38] + insufficent_score_white[39] +
                                         insufficent_score_white[40] + insufficent_score_white[41] +
                                         insufficent_score_white[42] + insufficent_score_white[43] +
                                         insufficent_score_white[44] + insufficent_score_white[45] +
                                         insufficent_score_white[46] + insufficent_score_white[47] +
                                         insufficent_score_white[48] + insufficent_score_white[49] +
                                         insufficent_score_white[50] + insufficent_score_white[51] +
                                         insufficent_score_white[52] + insufficent_score_white[53] +
                                         insufficent_score_white[54] + insufficent_score_white[55] +
                                         insufficent_score_white[56] + insufficent_score_white[57] +
                                         insufficent_score_white[58] + insufficent_score_white[59] +
                                         insufficent_score_white[60] + insufficent_score_white[61] +
                                         insufficent_score_white[62] + insufficent_score_white[63];
        
        insufficent_score_black_accum <= insufficent_score_black[ 0] + insufficent_score_black[ 1] +
                                         insufficent_score_black[ 2] + insufficent_score_black[ 3] +
                                         insufficent_score_black[ 4] + insufficent_score_black[ 5] +
                                         insufficent_score_black[ 6] + insufficent_score_black[ 7] +
                                         insufficent_score_black[ 8] + insufficent_score_black[ 9] +
                                         insufficent_score_black[10] + insufficent_score_black[11] +
                                         insufficent_score_black[12] + insufficent_score_black[13] +
                                         insufficent_score_black[14] + insufficent_score_black[15] +
                                         insufficent_score_black[16] + insufficent_score_black[17] +
                                         insufficent_score_black[18] + insufficent_score_black[19] +
                                         insufficent_score_black[20] + insufficent_score_black[21] +
                                         insufficent_score_black[22] + insufficent_score_black[23] +
                                         insufficent_score_black[24] + insufficent_score_black[25] +
                                         insufficent_score_black[26] + insufficent_score_black[27] +
                                         insufficent_score_black[28] + insufficent_score_black[29] +
                                         insufficent_score_black[30] + insufficent_score_black[31] +
                                         insufficent_score_black[32] + insufficent_score_black[33] +
                                         insufficent_score_black[34] + insufficent_score_black[35] +
                                         insufficent_score_black[36] + insufficent_score_black[37] +
                                         insufficent_score_black[38] + insufficent_score_black[39] +
                                         insufficent_score_black[40] + insufficent_score_black[41] +
                                         insufficent_score_black[42] + insufficent_score_black[43] +
                                         insufficent_score_black[44] + insufficent_score_black[45] +
                                         insufficent_score_black[46] + insufficent_score_black[47] +
                                         insufficent_score_black[48] + insufficent_score_black[49] +
                                         insufficent_score_black[50] + insufficent_score_black[51] +
                                         insufficent_score_black[52] + insufficent_score_black[53] +
                                         insufficent_score_black[54] + insufficent_score_black[55] +
                                         insufficent_score_black[56] + insufficent_score_black[57] +
                                         insufficent_score_black[58] + insufficent_score_black[59] +
                                         insufficent_score_black[60] + insufficent_score_black[61] +
                                         insufficent_score_black[62] + insufficent_score_black[63];
        
        if (use_random_bit)
          if (white_to_move)
            random_bit_final <= {1'b0, random_bit};
          else
            random_bit_final <= -$signed({1'b0,random_bit});
        else
          random_bit_final <= 0;
        
        // Claude Shannon's mobility score
        black_pop_score <= -(black_pop << POP_SHIFT);
        white_pop_score <= white_pop << POP_SHIFT;
        pop_score <= black_pop_score + white_pop_score + random_bit_final;
        
        for (y = 0; y < 8; y = y + 1)
          for (x = 0; x < 8; x = x + 1)
            score[y][x] <= value[board[idx[y][x]+:`PIECE_WIDTH]] + pst[board[idx[y][x]+:`PIECE_WIDTH]][y << 3 | x];
        for (y = 0; y < 8; y = y + 1)
          for (x = 0; x < 8; x = x + 4)
            sum_a[y][x / 4] <= score[y][x + 0] + score[y][x + 1] + score[y][x + 2] + score[y][x + 3];
        for (y = 0; y < 8; y = y + 2)
          sum_b[y / 2] <= sum_a[y + 0][0] + sum_a[y + 0][1] + sum_a[y + 1][0] + sum_a[y + 1][1];
        if ((insufficent_score_white_accum == 0 && insufficent_score_black_accum <= 1) ||
            (insufficent_score_white_accum <= 1 && insufficent_score_black_accum == 0))
          eval <= 0;
        else
          eval <= pop_score + sum_b[0] + sum_b[1] + sum_b[2] + sum_b[3];
     end

   localparam STATE_IDLE = 0;
   localparam STATE_WAIT_POP_VALID = 1;
   localparam STATE_SCORE = 2;
   localparam STATE_SUM_A = 3;
   localparam STATE_SUM_B = 4;
   localparam STATE_EVAL = 5;

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
                state <= STATE_WAIT_POP_VALID;
           end
         STATE_WAIT_POP_VALID :
           if (is_attacking_done)
             state <= STATE_SCORE;
         STATE_SCORE :
           state <= STATE_SUM_A;
         STATE_SUM_A :
           state <= STATE_SUM_B;
         STATE_SUM_B :
           state <= STATE_EVAL;
         STATE_EVAL :
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
        for (y = 0; y < 8; y = y + 1)
          begin
             ri = y * `SIDE_WIDTH;
             for (x = 0; x < 8; x = x + 1)
               idx[y][x] = ri + x * `PIECE_WIDTH;
          end
        
        for (ri = `EMPTY_POSN; ri <= `BLACK_KING; ri = ri + 1)
          begin
             value[ri] = 0;
             for (i = 0; i < 64; i = i + 1)
               pst[ri][i] = 0;
          end

        value[`EMPTY_POSN] = 0;
        value[`WHITE_PAWN] = VALUE_PAWN;
        value[`WHITE_KNIT] = VALUE_KNIT;
        value[`WHITE_BISH] = VALUE_BISH;
        value[`WHITE_ROOK] = VALUE_ROOK;
        value[`WHITE_QUEN] = VALUE_QUEN;
        value[`WHITE_KING] = VALUE_KING;

        value[`BLACK_PAWN] = -VALUE_PAWN;
        value[`BLACK_KNIT] = -VALUE_KNIT;
        value[`BLACK_BISH] = -VALUE_BISH;
        value[`BLACK_ROOK] = -VALUE_ROOK;
        value[`BLACK_QUEN] = -VALUE_QUEN;
        value[`BLACK_KING] = -VALUE_KING;

        pst[`WHITE_PAWN][ 0] =   0; pst[`WHITE_PAWN][ 1] =   0; pst[`WHITE_PAWN][ 2] =   0; pst[`WHITE_PAWN][ 3] =   0;
        pst[`WHITE_PAWN][ 4] =   0; pst[`WHITE_PAWN][ 5] =   0; pst[`WHITE_PAWN][ 6] =   0; pst[`WHITE_PAWN][ 7] =   0;
        pst[`WHITE_PAWN][ 8] =   0; pst[`WHITE_PAWN][ 9] =   0; pst[`WHITE_PAWN][10] =   0; pst[`WHITE_PAWN][11] = -25;
        pst[`WHITE_PAWN][12] = -25; pst[`WHITE_PAWN][13] =   0; pst[`WHITE_PAWN][14] =   0; pst[`WHITE_PAWN][15] =   0;
        pst[`WHITE_PAWN][16] =   0; pst[`WHITE_PAWN][17] =   0; pst[`WHITE_PAWN][18] =   0; pst[`WHITE_PAWN][19] =   5;
        pst[`WHITE_PAWN][20] =   5; pst[`WHITE_PAWN][21] =   0; pst[`WHITE_PAWN][22] =   0; pst[`WHITE_PAWN][23] =   0;
        pst[`WHITE_PAWN][24] =   0; pst[`WHITE_PAWN][25] =   0; pst[`WHITE_PAWN][26] =   0; pst[`WHITE_PAWN][27] =  10;
        pst[`WHITE_PAWN][28] =  10; pst[`WHITE_PAWN][29] =   0; pst[`WHITE_PAWN][30] =   0; pst[`WHITE_PAWN][31] =   0;
        pst[`WHITE_PAWN][32] =   0; pst[`WHITE_PAWN][33] =   0; pst[`WHITE_PAWN][34] =   0; pst[`WHITE_PAWN][35] =  15;
        pst[`WHITE_PAWN][36] =  15; pst[`WHITE_PAWN][37] =   0; pst[`WHITE_PAWN][38] =   0; pst[`WHITE_PAWN][39] =   0;
        pst[`WHITE_PAWN][40] =   0; pst[`WHITE_PAWN][41] =   0; pst[`WHITE_PAWN][42] =   0; pst[`WHITE_PAWN][43] =   0;
        pst[`WHITE_PAWN][44] =   0; pst[`WHITE_PAWN][45] =   0; pst[`WHITE_PAWN][46] =   0; pst[`WHITE_PAWN][47] =   0;
        pst[`WHITE_PAWN][48] =   0; pst[`WHITE_PAWN][49] =   0; pst[`WHITE_PAWN][50] =   0; pst[`WHITE_PAWN][51] =   0;
        pst[`WHITE_PAWN][52] =   0; pst[`WHITE_PAWN][53] =   0; pst[`WHITE_PAWN][54] =   0; pst[`WHITE_PAWN][55] =   0;
        pst[`WHITE_PAWN][56] =   0; pst[`WHITE_PAWN][57] =   0; pst[`WHITE_PAWN][58] =   0; pst[`WHITE_PAWN][59] =   0;
        pst[`WHITE_PAWN][60] =   0; pst[`WHITE_PAWN][61] =   0; pst[`WHITE_PAWN][62] =   0; pst[`WHITE_PAWN][63] =   0;

        pst[`WHITE_KNIT][ 0] = -40; pst[`WHITE_KNIT][ 1] = -30; pst[`WHITE_KNIT][ 2] = -25; pst[`WHITE_KNIT][ 3] = -25;
        pst[`WHITE_KNIT][ 4] = -25; pst[`WHITE_KNIT][ 5] = -25; pst[`WHITE_KNIT][ 6] = -30; pst[`WHITE_KNIT][ 7] = -40;
        pst[`WHITE_KNIT][ 8] = -30; pst[`WHITE_KNIT][ 9] =   0; pst[`WHITE_KNIT][10] =   0; pst[`WHITE_KNIT][11] =   5;
        pst[`WHITE_KNIT][12] =   5; pst[`WHITE_KNIT][13] =   0; pst[`WHITE_KNIT][14] =   0; pst[`WHITE_KNIT][15] = -30;
        pst[`WHITE_KNIT][16] = -30; pst[`WHITE_KNIT][17] =   0; pst[`WHITE_KNIT][18] =  10; pst[`WHITE_KNIT][19] =   0;
        pst[`WHITE_KNIT][20] =   0; pst[`WHITE_KNIT][21] =  10; pst[`WHITE_KNIT][22] =   0; pst[`WHITE_KNIT][23] = -30;
        pst[`WHITE_KNIT][24] = -30; pst[`WHITE_KNIT][25] =   0; pst[`WHITE_KNIT][26] =   0; pst[`WHITE_KNIT][27] =  15;
        pst[`WHITE_KNIT][28] =  15; pst[`WHITE_KNIT][29] =   0; pst[`WHITE_KNIT][30] =   0; pst[`WHITE_KNIT][31] = -30;
        pst[`WHITE_KNIT][32] = -30; pst[`WHITE_KNIT][33] =   0; pst[`WHITE_KNIT][34] =   0; pst[`WHITE_KNIT][35] =  15;
        pst[`WHITE_KNIT][36] =  15; pst[`WHITE_KNIT][37] =   0; pst[`WHITE_KNIT][38] =   0; pst[`WHITE_KNIT][39] = -30;
        pst[`WHITE_KNIT][40] = -30; pst[`WHITE_KNIT][41] =   0; pst[`WHITE_KNIT][42] =   0; pst[`WHITE_KNIT][43] =   0;
        pst[`WHITE_KNIT][44] =   0; pst[`WHITE_KNIT][45] =   0; pst[`WHITE_KNIT][46] =   0; pst[`WHITE_KNIT][47] = -30;
        pst[`WHITE_KNIT][48] = -30; pst[`WHITE_KNIT][49] =   0; pst[`WHITE_KNIT][50] =   0; pst[`WHITE_KNIT][51] =   0;
        pst[`WHITE_KNIT][52] =   0; pst[`WHITE_KNIT][53] =   0; pst[`WHITE_KNIT][54] =   0; pst[`WHITE_KNIT][55] = -30;
        pst[`WHITE_KNIT][56] = -40; pst[`WHITE_KNIT][57] = -25; pst[`WHITE_KNIT][58] = -25; pst[`WHITE_KNIT][59] = -25;
        pst[`WHITE_KNIT][60] = -25; pst[`WHITE_KNIT][61] = -25; pst[`WHITE_KNIT][62] = -25; pst[`WHITE_KNIT][63] = -40;

        pst[`WHITE_BISH][ 0] = -10; pst[`WHITE_BISH][ 1] = -20; pst[`WHITE_BISH][ 2] = -20; pst[`WHITE_BISH][ 3] = -20;
        pst[`WHITE_BISH][ 4] = -20; pst[`WHITE_BISH][ 5] = -20; pst[`WHITE_BISH][ 6] = -20; pst[`WHITE_BISH][ 7] = -10;
        pst[`WHITE_BISH][ 8] = -10; pst[`WHITE_BISH][ 9] =   5; pst[`WHITE_BISH][10] =   0; pst[`WHITE_BISH][11] =   0;
        pst[`WHITE_BISH][12] =   0; pst[`WHITE_BISH][13] =   0; pst[`WHITE_BISH][14] =   5; pst[`WHITE_BISH][15] = -10;
        pst[`WHITE_BISH][16] = -10; pst[`WHITE_BISH][17] =   0; pst[`WHITE_BISH][18] =   5; pst[`WHITE_BISH][19] =   0;
        pst[`WHITE_BISH][20] =   0; pst[`WHITE_BISH][21] =   5; pst[`WHITE_BISH][22] =   0; pst[`WHITE_BISH][23] = -10;
        pst[`WHITE_BISH][24] = -10; pst[`WHITE_BISH][25] =   0; pst[`WHITE_BISH][26] =   5; pst[`WHITE_BISH][27] =  10;
        pst[`WHITE_BISH][28] =  10; pst[`WHITE_BISH][29] =   5; pst[`WHITE_BISH][30] =   0; pst[`WHITE_BISH][31] = -10;
        pst[`WHITE_BISH][32] = -10; pst[`WHITE_BISH][33] =   0; pst[`WHITE_BISH][34] =   0; pst[`WHITE_BISH][35] =  10;
        pst[`WHITE_BISH][36] =  10; pst[`WHITE_BISH][37] =   0; pst[`WHITE_BISH][38] =   0; pst[`WHITE_BISH][39] = -10;
        pst[`WHITE_BISH][40] = -10; pst[`WHITE_BISH][41] =   0; pst[`WHITE_BISH][42] =   5; pst[`WHITE_BISH][43] =   0;
        pst[`WHITE_BISH][44] =   0; pst[`WHITE_BISH][45] =   5; pst[`WHITE_BISH][46] =   0; pst[`WHITE_BISH][47] = -10;
        pst[`WHITE_BISH][48] = -10; pst[`WHITE_BISH][49] =   5; pst[`WHITE_BISH][50] =   0; pst[`WHITE_BISH][51] =   0;
        pst[`WHITE_BISH][52] =   0; pst[`WHITE_BISH][53] =   0; pst[`WHITE_BISH][54] =   5; pst[`WHITE_BISH][55] = -10;
        pst[`WHITE_BISH][56] = -10; pst[`WHITE_BISH][57] =   0; pst[`WHITE_BISH][58] =   0; pst[`WHITE_BISH][59] =   0;
        pst[`WHITE_BISH][60] =   0; pst[`WHITE_BISH][61] =   0; pst[`WHITE_BISH][62] =   0; pst[`WHITE_BISH][63] = -10;

        pst[`WHITE_ROOK][ 0] =   0; pst[`WHITE_ROOK][ 1] =   0; pst[`WHITE_ROOK][ 2] =   0; pst[`WHITE_ROOK][ 3] =   5;
        pst[`WHITE_ROOK][ 4] =   5; pst[`WHITE_ROOK][ 5] =   0; pst[`WHITE_ROOK][ 6] =   0; pst[`WHITE_ROOK][ 7] =   0;
        pst[`WHITE_ROOK][ 8] =   0; pst[`WHITE_ROOK][ 9] =   0; pst[`WHITE_ROOK][10] =   0; pst[`WHITE_ROOK][11] =   0;
        pst[`WHITE_ROOK][12] =   0; pst[`WHITE_ROOK][13] =   0; pst[`WHITE_ROOK][14] =   0; pst[`WHITE_ROOK][15] =   0;
        pst[`WHITE_ROOK][16] =   0; pst[`WHITE_ROOK][17] =   0; pst[`WHITE_ROOK][18] =   0; pst[`WHITE_ROOK][19] =   0;
        pst[`WHITE_ROOK][20] =   0; pst[`WHITE_ROOK][21] =   0; pst[`WHITE_ROOK][22] =   0; pst[`WHITE_ROOK][23] =   0;
        pst[`WHITE_ROOK][24] =   0; pst[`WHITE_ROOK][25] =   0; pst[`WHITE_ROOK][26] =   0; pst[`WHITE_ROOK][27] =   0;
        pst[`WHITE_ROOK][28] =   0; pst[`WHITE_ROOK][29] =   0; pst[`WHITE_ROOK][30] =   0; pst[`WHITE_ROOK][31] =   0;
        pst[`WHITE_ROOK][32] =   0; pst[`WHITE_ROOK][33] =   0; pst[`WHITE_ROOK][34] =   0; pst[`WHITE_ROOK][35] =   0;
        pst[`WHITE_ROOK][36] =   0; pst[`WHITE_ROOK][37] =   0; pst[`WHITE_ROOK][38] =   0; pst[`WHITE_ROOK][39] =   0;
        pst[`WHITE_ROOK][40] =   0; pst[`WHITE_ROOK][41] =   0; pst[`WHITE_ROOK][42] =   0; pst[`WHITE_ROOK][43] =   0;
        pst[`WHITE_ROOK][44] =   0; pst[`WHITE_ROOK][45] =   0; pst[`WHITE_ROOK][46] =   0; pst[`WHITE_ROOK][47] =   0;
        pst[`WHITE_ROOK][48] =  10; pst[`WHITE_ROOK][49] =  10; pst[`WHITE_ROOK][50] =  10; pst[`WHITE_ROOK][51] =  10;
        pst[`WHITE_ROOK][52] =  10; pst[`WHITE_ROOK][53] =  10; pst[`WHITE_ROOK][54] =  10; pst[`WHITE_ROOK][55] =  10;
        pst[`WHITE_ROOK][56] =   0; pst[`WHITE_ROOK][57] =   0; pst[`WHITE_ROOK][58] =   0; pst[`WHITE_ROOK][59] =   0;
        pst[`WHITE_ROOK][60] =   0; pst[`WHITE_ROOK][61] =   0; pst[`WHITE_ROOK][62] =   0; pst[`WHITE_ROOK][63] =   0;

        pst[`WHITE_KING][ 0] =  10; pst[`WHITE_KING][ 1] =  15; pst[`WHITE_KING][ 2] = -15; pst[`WHITE_KING][ 3] = -15;
        pst[`WHITE_KING][ 4] = -15; pst[`WHITE_KING][ 5] = -15; pst[`WHITE_KING][ 6] =  15; pst[`WHITE_KING][ 7] =  10;
        pst[`WHITE_KING][ 8] = -25; pst[`WHITE_KING][ 9] = -25; pst[`WHITE_KING][10] = -25; pst[`WHITE_KING][11] = -25;
        pst[`WHITE_KING][12] = -25; pst[`WHITE_KING][13] = -25; pst[`WHITE_KING][14] = -25; pst[`WHITE_KING][15] = -25;
        pst[`WHITE_KING][16] = -25; pst[`WHITE_KING][17] = -25; pst[`WHITE_KING][18] = -25; pst[`WHITE_KING][19] = -25;
        pst[`WHITE_KING][20] = -25; pst[`WHITE_KING][21] = -25; pst[`WHITE_KING][22] = -25; pst[`WHITE_KING][23] = -25;
        pst[`WHITE_KING][24] = -25; pst[`WHITE_KING][25] = -25; pst[`WHITE_KING][26] = -25; pst[`WHITE_KING][27] = -25;
        pst[`WHITE_KING][28] = -25; pst[`WHITE_KING][29] = -25; pst[`WHITE_KING][30] = -25; pst[`WHITE_KING][31] = -25;
        pst[`WHITE_KING][32] = -25; pst[`WHITE_KING][33] = -25; pst[`WHITE_KING][34] = -25; pst[`WHITE_KING][35] = -25;
        pst[`WHITE_KING][36] = -25; pst[`WHITE_KING][37] = -25; pst[`WHITE_KING][38] = -25; pst[`WHITE_KING][39] = -25;
        pst[`WHITE_KING][40] = -25; pst[`WHITE_KING][41] = -25; pst[`WHITE_KING][42] = -25; pst[`WHITE_KING][43] = -25;
        pst[`WHITE_KING][44] = -25; pst[`WHITE_KING][45] = -25; pst[`WHITE_KING][46] = -25; pst[`WHITE_KING][47] = -25;
        pst[`WHITE_KING][48] = -25; pst[`WHITE_KING][49] = -25; pst[`WHITE_KING][50] = -25; pst[`WHITE_KING][51] = -25;
        pst[`WHITE_KING][52] = -25; pst[`WHITE_KING][53] = -25; pst[`WHITE_KING][54] = -25; pst[`WHITE_KING][55] = -25;
        pst[`WHITE_KING][56] = -25; pst[`WHITE_KING][57] = -25; pst[`WHITE_KING][58] = -25; pst[`WHITE_KING][59] = -25;
        pst[`WHITE_KING][60] = -25; pst[`WHITE_KING][61] = -25; pst[`WHITE_KING][62] = -25; pst[`WHITE_KING][63] = -25;

        pst[`BLACK_PAWN][ 0] =   0; pst[`BLACK_PAWN][ 1] =   0; pst[`BLACK_PAWN][ 2] =   0; pst[`BLACK_PAWN][ 3] =   0;
        pst[`BLACK_PAWN][ 4] =   0; pst[`BLACK_PAWN][ 5] =   0; pst[`BLACK_PAWN][ 6] =   0; pst[`BLACK_PAWN][ 7] =   0;
        pst[`BLACK_PAWN][ 8] =   0; pst[`BLACK_PAWN][ 9] =   0; pst[`BLACK_PAWN][10] =   0; pst[`BLACK_PAWN][11] =   0;
        pst[`BLACK_PAWN][12] =   0; pst[`BLACK_PAWN][13] =   0; pst[`BLACK_PAWN][14] =   0; pst[`BLACK_PAWN][15] =   0;
        pst[`BLACK_PAWN][16] =   0; pst[`BLACK_PAWN][17] =   0; pst[`BLACK_PAWN][18] =   0; pst[`BLACK_PAWN][19] =   0;
        pst[`BLACK_PAWN][20] =   0; pst[`BLACK_PAWN][21] =   0; pst[`BLACK_PAWN][22] =   0; pst[`BLACK_PAWN][23] =   0;
        pst[`BLACK_PAWN][24] =   0; pst[`BLACK_PAWN][25] =   0; pst[`BLACK_PAWN][26] =   0; pst[`BLACK_PAWN][27] = -15;
        pst[`BLACK_PAWN][28] = -15; pst[`BLACK_PAWN][29] =   0; pst[`BLACK_PAWN][30] =   0; pst[`BLACK_PAWN][31] =   0;
        pst[`BLACK_PAWN][32] =   0; pst[`BLACK_PAWN][33] =   0; pst[`BLACK_PAWN][34] =   0; pst[`BLACK_PAWN][35] = -10;
        pst[`BLACK_PAWN][36] = -10; pst[`BLACK_PAWN][37] =   0; pst[`BLACK_PAWN][38] =   0; pst[`BLACK_PAWN][39] =   0;
        pst[`BLACK_PAWN][40] =   0; pst[`BLACK_PAWN][41] =   0; pst[`BLACK_PAWN][42] =   0; pst[`BLACK_PAWN][43] =  -5;
        pst[`BLACK_PAWN][44] =  -5; pst[`BLACK_PAWN][45] =   0; pst[`BLACK_PAWN][46] =   0; pst[`BLACK_PAWN][47] =   0;
        pst[`BLACK_PAWN][48] =   0; pst[`BLACK_PAWN][49] =   0; pst[`BLACK_PAWN][50] =   0; pst[`BLACK_PAWN][51] =  25;
        pst[`BLACK_PAWN][52] =  25; pst[`BLACK_PAWN][53] =   0; pst[`BLACK_PAWN][54] =   0; pst[`BLACK_PAWN][55] =   0;
        pst[`BLACK_PAWN][56] =   0; pst[`BLACK_PAWN][57] =   0; pst[`BLACK_PAWN][58] =   0; pst[`BLACK_PAWN][59] =   0;
        pst[`BLACK_PAWN][60] =   0; pst[`BLACK_PAWN][61] =   0; pst[`BLACK_PAWN][62] =   0; pst[`BLACK_PAWN][63] =   0;

        pst[`BLACK_KNIT][ 0] =  40; pst[`BLACK_KNIT][ 1] =  25; pst[`BLACK_KNIT][ 2] =  25; pst[`BLACK_KNIT][ 3] =  25;
        pst[`BLACK_KNIT][ 4] =  25; pst[`BLACK_KNIT][ 5] =  25; pst[`BLACK_KNIT][ 6] =  25; pst[`BLACK_KNIT][ 7] =  40;
        pst[`BLACK_KNIT][ 8] =  30; pst[`BLACK_KNIT][ 9] =   0; pst[`BLACK_KNIT][10] =   0; pst[`BLACK_KNIT][11] =   0;
        pst[`BLACK_KNIT][12] =   0; pst[`BLACK_KNIT][13] =   0; pst[`BLACK_KNIT][14] =   0; pst[`BLACK_KNIT][15] =  30;
        pst[`BLACK_KNIT][16] =  30; pst[`BLACK_KNIT][17] =   0; pst[`BLACK_KNIT][18] =   0; pst[`BLACK_KNIT][19] =   0;
        pst[`BLACK_KNIT][20] =   0; pst[`BLACK_KNIT][21] =   0; pst[`BLACK_KNIT][22] =   0; pst[`BLACK_KNIT][23] =  30;
        pst[`BLACK_KNIT][24] =  30; pst[`BLACK_KNIT][25] =   0; pst[`BLACK_KNIT][26] =   0; pst[`BLACK_KNIT][27] = -15;
        pst[`BLACK_KNIT][28] = -15; pst[`BLACK_KNIT][29] =   0; pst[`BLACK_KNIT][30] =   0; pst[`BLACK_KNIT][31] =  30;
        pst[`BLACK_KNIT][32] =  30; pst[`BLACK_KNIT][33] =   0; pst[`BLACK_KNIT][34] =   0; pst[`BLACK_KNIT][35] = -15;
        pst[`BLACK_KNIT][36] = -15; pst[`BLACK_KNIT][37] =   0; pst[`BLACK_KNIT][38] =   0; pst[`BLACK_KNIT][39] =  30;
        pst[`BLACK_KNIT][40] =  30; pst[`BLACK_KNIT][41] =   0; pst[`BLACK_KNIT][42] = -10; pst[`BLACK_KNIT][43] =   0;
        pst[`BLACK_KNIT][44] =   0; pst[`BLACK_KNIT][45] = -10; pst[`BLACK_KNIT][46] =   0; pst[`BLACK_KNIT][47] =  30;
        pst[`BLACK_KNIT][48] =  30; pst[`BLACK_KNIT][49] =   0; pst[`BLACK_KNIT][50] =   0; pst[`BLACK_KNIT][51] =  -5;
        pst[`BLACK_KNIT][52] =  -5; pst[`BLACK_KNIT][53] =   0; pst[`BLACK_KNIT][54] =   0; pst[`BLACK_KNIT][55] =  30;
        pst[`BLACK_KNIT][56] =  40; pst[`BLACK_KNIT][57] =  30; pst[`BLACK_KNIT][58] =  25; pst[`BLACK_KNIT][59] =  25;
        pst[`BLACK_KNIT][60] =  25; pst[`BLACK_KNIT][61] =  25; pst[`BLACK_KNIT][62] =  30; pst[`BLACK_KNIT][63] =  40;

        pst[`BLACK_BISH][ 0] =  10; pst[`BLACK_BISH][ 1] =   0; pst[`BLACK_BISH][ 2] =   0; pst[`BLACK_BISH][ 3] =   0;
        pst[`BLACK_BISH][ 4] =   0; pst[`BLACK_BISH][ 5] =   0; pst[`BLACK_BISH][ 6] =   0; pst[`BLACK_BISH][ 7] =  10;
        pst[`BLACK_BISH][ 8] =  10; pst[`BLACK_BISH][ 9] =  -5; pst[`BLACK_BISH][10] =   0; pst[`BLACK_BISH][11] =   0;
        pst[`BLACK_BISH][12] =   0; pst[`BLACK_BISH][13] =   0; pst[`BLACK_BISH][14] =  -5; pst[`BLACK_BISH][15] =  10;
        pst[`BLACK_BISH][16] =  10; pst[`BLACK_BISH][17] =   0; pst[`BLACK_BISH][18] =  -5; pst[`BLACK_BISH][19] =   0;
        pst[`BLACK_BISH][20] =   0; pst[`BLACK_BISH][21] =  -5; pst[`BLACK_BISH][22] =   0; pst[`BLACK_BISH][23] =  10;
        pst[`BLACK_BISH][24] =  10; pst[`BLACK_BISH][25] =   0; pst[`BLACK_BISH][26] =   0; pst[`BLACK_BISH][27] = -10;
        pst[`BLACK_BISH][28] = -10; pst[`BLACK_BISH][29] =   0; pst[`BLACK_BISH][30] =   0; pst[`BLACK_BISH][31] =  10;
        pst[`BLACK_BISH][32] =  10; pst[`BLACK_BISH][33] =   0; pst[`BLACK_BISH][34] =  -5; pst[`BLACK_BISH][35] = -10;
        pst[`BLACK_BISH][36] = -10; pst[`BLACK_BISH][37] =  -5; pst[`BLACK_BISH][38] =   0; pst[`BLACK_BISH][39] =  10;
        pst[`BLACK_BISH][40] =  10; pst[`BLACK_BISH][41] =   0; pst[`BLACK_BISH][42] =  -5; pst[`BLACK_BISH][43] =   0;
        pst[`BLACK_BISH][44] =   0; pst[`BLACK_BISH][45] =  -5; pst[`BLACK_BISH][46] =   0; pst[`BLACK_BISH][47] =  10;
        pst[`BLACK_BISH][48] =  10; pst[`BLACK_BISH][49] =  -5; pst[`BLACK_BISH][50] =   0; pst[`BLACK_BISH][51] =   0;
        pst[`BLACK_BISH][52] =   0; pst[`BLACK_BISH][53] =   0; pst[`BLACK_BISH][54] =  -5; pst[`BLACK_BISH][55] =  10;
        pst[`BLACK_BISH][56] =  10; pst[`BLACK_BISH][57] =  20; pst[`BLACK_BISH][58] =  20; pst[`BLACK_BISH][59] =  20;
        pst[`BLACK_BISH][60] =  20; pst[`BLACK_BISH][61] =  20; pst[`BLACK_BISH][62] =  20; pst[`BLACK_BISH][63] =  10;

        pst[`BLACK_ROOK][ 0] =   0; pst[`BLACK_ROOK][ 1] =   0; pst[`BLACK_ROOK][ 2] =   0; pst[`BLACK_ROOK][ 3] =   0;
        pst[`BLACK_ROOK][ 4] =   0; pst[`BLACK_ROOK][ 5] =   0; pst[`BLACK_ROOK][ 6] =   0; pst[`BLACK_ROOK][ 7] =   0;
        pst[`BLACK_ROOK][ 8] = -10; pst[`BLACK_ROOK][ 9] = -10; pst[`BLACK_ROOK][10] = -10; pst[`BLACK_ROOK][11] = -10;
        pst[`BLACK_ROOK][12] = -10; pst[`BLACK_ROOK][13] = -10; pst[`BLACK_ROOK][14] = -10; pst[`BLACK_ROOK][15] = -10;
        pst[`BLACK_ROOK][16] =   0; pst[`BLACK_ROOK][17] =   0; pst[`BLACK_ROOK][18] =   0; pst[`BLACK_ROOK][19] =   0;
        pst[`BLACK_ROOK][20] =   0; pst[`BLACK_ROOK][21] =   0; pst[`BLACK_ROOK][22] =   0; pst[`BLACK_ROOK][23] =   0;
        pst[`BLACK_ROOK][24] =   0; pst[`BLACK_ROOK][25] =   0; pst[`BLACK_ROOK][26] =   0; pst[`BLACK_ROOK][27] =   0;
        pst[`BLACK_ROOK][28] =   0; pst[`BLACK_ROOK][29] =   0; pst[`BLACK_ROOK][30] =   0; pst[`BLACK_ROOK][31] =   0;
        pst[`BLACK_ROOK][32] =   0; pst[`BLACK_ROOK][33] =   0; pst[`BLACK_ROOK][34] =   0; pst[`BLACK_ROOK][35] =   0;
        pst[`BLACK_ROOK][36] =   0; pst[`BLACK_ROOK][37] =   0; pst[`BLACK_ROOK][38] =   0; pst[`BLACK_ROOK][39] =   0;
        pst[`BLACK_ROOK][40] =   0; pst[`BLACK_ROOK][41] =   0; pst[`BLACK_ROOK][42] =   0; pst[`BLACK_ROOK][43] =   0;
        pst[`BLACK_ROOK][44] =   0; pst[`BLACK_ROOK][45] =   0; pst[`BLACK_ROOK][46] =   0; pst[`BLACK_ROOK][47] =   0;
        pst[`BLACK_ROOK][48] =   0; pst[`BLACK_ROOK][49] =   0; pst[`BLACK_ROOK][50] =   0; pst[`BLACK_ROOK][51] =   0;
        pst[`BLACK_ROOK][52] =   0; pst[`BLACK_ROOK][53] =   0; pst[`BLACK_ROOK][54] =   0; pst[`BLACK_ROOK][55] =   0;
        pst[`BLACK_ROOK][56] =   0; pst[`BLACK_ROOK][57] =   0; pst[`BLACK_ROOK][58] =   0; pst[`BLACK_ROOK][59] =  -5;
        pst[`BLACK_ROOK][60] =  -5; pst[`BLACK_ROOK][61] =   0; pst[`BLACK_ROOK][62] =   0; pst[`BLACK_ROOK][63] =   0;

        pst[`BLACK_KING][ 0] =  25; pst[`BLACK_KING][ 1] =  25; pst[`BLACK_KING][ 2] =  25; pst[`BLACK_KING][ 3] =  25;
        pst[`BLACK_KING][ 4] =  25; pst[`BLACK_KING][ 5] =  25; pst[`BLACK_KING][ 6] =  25; pst[`BLACK_KING][ 7] =  25;
        pst[`BLACK_KING][ 8] =  25; pst[`BLACK_KING][ 9] =  25; pst[`BLACK_KING][10] =  25; pst[`BLACK_KING][11] =  25;
        pst[`BLACK_KING][12] =  25; pst[`BLACK_KING][13] =  25; pst[`BLACK_KING][14] =  25; pst[`BLACK_KING][15] =  25;
        pst[`BLACK_KING][16] =  25; pst[`BLACK_KING][17] =  25; pst[`BLACK_KING][18] =  25; pst[`BLACK_KING][19] =  25;
        pst[`BLACK_KING][20] =  25; pst[`BLACK_KING][21] =  25; pst[`BLACK_KING][22] =  25; pst[`BLACK_KING][23] =  25;
        pst[`BLACK_KING][24] =  25; pst[`BLACK_KING][25] =  25; pst[`BLACK_KING][26] =  25; pst[`BLACK_KING][27] =  25;
        pst[`BLACK_KING][28] =  25; pst[`BLACK_KING][29] =  25; pst[`BLACK_KING][30] =  25; pst[`BLACK_KING][31] =  25;
        pst[`BLACK_KING][32] =  25; pst[`BLACK_KING][33] =  25; pst[`BLACK_KING][34] =  25; pst[`BLACK_KING][35] =  25;
        pst[`BLACK_KING][36] =  25; pst[`BLACK_KING][37] =  25; pst[`BLACK_KING][38] =  25; pst[`BLACK_KING][39] =  25;
        pst[`BLACK_KING][40] =  25; pst[`BLACK_KING][41] =  25; pst[`BLACK_KING][42] =  25; pst[`BLACK_KING][43] =  25;
        pst[`BLACK_KING][44] =  25; pst[`BLACK_KING][45] =  25; pst[`BLACK_KING][46] =  25; pst[`BLACK_KING][47] =  25;
        pst[`BLACK_KING][48] =  25; pst[`BLACK_KING][49] =  25; pst[`BLACK_KING][50] =  25; pst[`BLACK_KING][51] =  25;
        pst[`BLACK_KING][52] =  25; pst[`BLACK_KING][53] =  25; pst[`BLACK_KING][54] =  25; pst[`BLACK_KING][55] =  25;
        pst[`BLACK_KING][56] = -10; pst[`BLACK_KING][57] = -15; pst[`BLACK_KING][58] =  15; pst[`BLACK_KING][59] =  15;
        pst[`BLACK_KING][60] =  15; pst[`BLACK_KING][61] =  15; pst[`BLACK_KING][62] = -15; pst[`BLACK_KING][63] = -10;
     end

endmodule
