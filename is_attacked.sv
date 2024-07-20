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

   localparam PIECE_WIDTH2 = 1 << PIECE_WIDTH;
   localparam SIDE_WIDTH2 = PIECE_WIDTH2 * 8;
   localparam BOARD_WIDTH2 = PIECE_WIDTH2 * 64;

   localparam EMPTY_POSN2 = 1 << `EMPTY_POSN;
   localparam ATTACK_ROOK = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_ROOK : `BLACK_ROOK);
   localparam ATTACK_KNIT = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_KNIT : `BLACK_KNIT);
   localparam ATTACK_BISH = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_BISH : `BLACK_BISH);
   localparam ATTACK_QUEN = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_QUEN : `BLACK_QUEN);
   localparam ATTACK_KING = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_KING : `BLACK_KING);
   localparam ATTACK_PAWN = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_PAWN : `BLACK_PAWN);

   localparam ATTACK_COUNT = 14;

   reg [BOARD_WIDTH2 - 1:0]   attack_mask [0:ATTACK_COUNT - 1];

   integer                    idx, i, j, a;
   genvar                     gen_i;

   wire [BOARD_WIDTH2 - 1:0]  board2;

   initial
     begin
        //        $dumpfile("wave.vcd");
        //        for (i = 0; i <= 6; i = i + 1)
        //          begin
        //          end
        for (idx = 0; idx < ATTACK_COUNT; idx = idx + 1)
          attack_mask[idx] = 0; // default is "don't care"
        idx = 0;
        // rook, queen, horizontal
        for (i = 0; i < 8; i = i + 1)
          if (i != COL)
            begin
               attack_mask[idx][ROW * SIDE_WIDTH2 + i * PIECE_WIDTH2+:PIECE_WIDTH2] = ATTACK_ROOK | ATTACK_QUEN;
               for (j = i + 1; j < COL; j = j + 1)
                 attack_mask[idx][ROW * SIDE_WIDTH2 + j * PIECE_WIDTH2+:PIECE_WIDTH2] = EMPTY_POSN2;
               for (j = COL + 1; j < i - 1; j = j + 1)
                 attack_mask[idx][ROW * SIDE_WIDTH2 + j * PIECE_WIDTH2+:PIECE_WIDTH2] = EMPTY_POSN2;
               idx = idx + 1;
            end
        // rook, queen, vertical 
        for (i = 0; i < 8; i = i + 1)
          if (i != ROW)
            begin
               attack_mask[idx][COL * PIECE_WIDTH2 + i * SIDE_WIDTH2+:PIECE_WIDTH2] = ATTACK_ROOK | ATTACK_QUEN;
               for (j = i + 1; j < ROW; j = j + 1)
                 attack_mask[idx][COL * PIECE_WIDTH2 + j * SIDE_WIDTH2+:PIECE_WIDTH2] = EMPTY_POSN2;
               for (j = ROW + 1; j < i - 1; j = j + 1)
                 attack_mask[idx][COL * PIECE_WIDTH2 + j * SIDE_WIDTH2+:PIECE_WIDTH2] = EMPTY_POSN2;
               idx = idx + 1;
            end
     end

   generate
      for (gen_i = 0; gen_i < 64; gen_i = gen_i + 1)
        begin : bitmap_assign_blk
           assign board2[gen_i * PIECE_WIDTH2+:PIECE_WIDTH2] = 1 << (board[gen_i * PIECE_WIDTH+:PIECE_WIDTH]);
        end
   endgenerate

endmodule
