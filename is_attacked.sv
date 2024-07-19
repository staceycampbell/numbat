module is_attacked #
  (
   parameter PIECE_WIDTH = 0,
   parameter SIDE_WIDTH = 0,
   parameter BOARD_WIDTH = 0,
   parameter ATTACKER = `WHITE_ATTACK,
   parameter ROW = 0,
   parameter COL = 0
   )
   (
    input                     clk,
    input                     reset,
   
    input [BOARD_WIDTH - 1:0] board,
    input                     board_valid,

    output reg                attacked,
    output reg                attacked_valid
    );

   localparam ATTACK_ROOK = ATTACKER == `WHITE_ATTACK ? `WHITE_ROOK : `BLACK_ROOK;
   localparam ATTACK_KNIT = ATTACKER == `WHITE_ATTACK ? `WHITE_KNIT : `BLACK_KNIT;
   localparam ATTACK_BISH = ATTACKER == `WHITE_ATTACK ? `WHITE_BISH : `BLACK_BISH;
   localparam ATTACK_QUEN = ATTACKER == `WHITE_ATTACK ? `WHITE_QUEN : `BLACK_QUEN;
   localparam ATTACK_KING = ATTACKER == `WHITE_ATTACK ? `WHITE_KING : `BLACK_KING;
   localparam ATTACK_PAWN = ATTACKER == `WHITE_ATTACK ? `WHITE_PAWN : `BLACK_PAWN;

   reg [SIDE_WIDTH - 1:0]     rook_row_pattern [0:6];
   reg [SIDE_WIDTH - 1:0]     rook_col_pattern [0:6];

   integer                    idx, i, j;

   initial
     begin
        idx = 0;
        for (i = 0; i < 8; i = i + 1)
          if (i != COL)
            begin
               for (j = 0; j < 8; j = j + 1)
                 rook_row_pattern[idx][j * PIECE_WIDTH+:PIECE_WIDTH] = 0;
               rook_row_pattern[idx][idx * PIECE_WIDTH+:PIECE_WIDTH] = ATTACK_ROOK;
               if (idx < COL)
                 for (j = idx + 1; j < COL; j = j + 1)
                   rook_row_pattern[idx][j * PIECE_WIDTH+:PIECE_WIDTH] = `EMPTY_POSN;
               else
                 for (j = COL + 1; j < idx; j = j + 1)
                   rook_row_pattern[idx][j * PIECE_WIDTH+:PIECE_WIDTH] = `EMPTY_POSN;
               idx = idx + 1;
            end
        idx = 0;
        for (i = 0; i < 8; i = i + 1)
          if (i != ROW)
            begin
               for (j = 0; j < 8; j = j + 1)
                 rook_col_pattern[idx][j * PIECE_WIDTH+:PIECE_WIDTH] = 0;
               rook_col_pattern[idx][idx * PIECE_WIDTH+:PIECE_WIDTH] = ATTACK_ROOK;
               if (idx < ROW)
                 for (j = idx + 1; j < ROW; j = j + 1)
                   rook_col_pattern[idx][j * PIECE_WIDTH+:PIECE_WIDTH] = `EMPTY_POSN;
               else
                 for (j = ROW + 1; j < idx; j = j + 1)
                   rook_col_pattern[idx][j * PIECE_WIDTH+:PIECE_WIDTH] = `EMPTY_POSN;
               idx = idx + 1;
            end
     end

endmodule
