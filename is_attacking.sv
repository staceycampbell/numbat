module is_attacking #
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

   localparam PIECE_WIDTH2 = `PIECE_MASK_BITS;
   localparam SIDE_WIDTH2 = PIECE_WIDTH2 * 8;
   localparam BOARD_WIDTH2 = SIDE_WIDTH2 * 8;

   localparam EMPTY_POSN2 = 1 << `EMPTY_POSN;
   localparam ATTACK_ROOK = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_ROOK : `BLACK_ROOK);
   localparam ATTACK_KNIT = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_KNIT : `BLACK_KNIT);
   localparam ATTACK_BISH = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_BISH : `BLACK_BISH);
   localparam ATTACK_QUEN = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_QUEN : `BLACK_QUEN);
   localparam ATTACK_KING = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_KING : `BLACK_KING);
   localparam ATTACK_PAWN = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_PAWN : `BLACK_PAWN);

   localparam ATTACK_COUNT = 75;

   reg [BOARD_WIDTH2 - 1:0]   attack_mask [0:ATTACK_COUNT - 1];
   reg [PIECE_WIDTH2 - 1:0]   attack_array [0:7][0:7];
   reg [ATTACK_COUNT - 1:0]   attack_list_t1;
   reg                        attacked_valid_t1;
   reg                        board_valid_t1;

   integer                    knight_offset_x [0:7], knight_offset_y [0:7];
   integer                    king_offset_x [0:7], king_offset_y [0:7];

   integer                    idx, i, j, ai, aj, f, fi, fj;
   genvar                     gen_i;

   wire [BOARD_WIDTH2 - 1:0]  board2_t0;
   wire                       board_valid_t0 = board_valid;

   initial
     begin
        if (0)
          begin
             $dumpfile("wave.vcd");
             for (i = 0; i < ATTACK_COUNT; i = i + 1)
               begin
                  $dumpvars(0, attack_mask[i]);
               end
          end
        for (idx = 0; idx < ATTACK_COUNT; idx = idx + 1)
          attack_mask[idx] = 0; // default is "don't care"
        idx = 0;
        // rook horizontal
        for (j = 0; j < 8; j = j + 1)
          if (j != COL)
            begin
               for (ai = 0; ai < 8; ai = ai + 1)
                 for (aj = 0; aj < 8; aj = aj + 1)
                   attack_array[ai][aj] = 0;
               attack_array[ROW][j] = ATTACK_ROOK;
               for (f = j + 1; f < COL; f = f + 1)
                 attack_array[ROW][f] = EMPTY_POSN2;
               for (f = COL + 1; f < j - 1; f = f + 1)
                 attack_array[ROW][f] = EMPTY_POSN2;
               for (ai = 0; ai < 8; ai = ai + 1)
                 for (aj = 0; aj < 8; aj = aj + 1)
                   attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
               idx = idx + 1;
            end
        // rook vertical
        for (i = 0; i < 8; i = i + 1)
          if (i != ROW)
            begin
               for (ai = 0; ai < 8; ai = ai + 1)
                 for (aj = 0; aj < 8; aj = aj + 1)
                   attack_array[ai][aj] = 0;
               attack_array[i][COL] = ATTACK_ROOK;
               for (f = i + 1; f < ROW; f = f + 1)
                 attack_array[f][COL] = EMPTY_POSN2;
               for (f = ROW + 1; f < i; f = f + 1)
                 attack_array[f][COL] = EMPTY_POSN2;
               for (ai = 0; ai < 8; ai = ai + 1)
                 for (aj = 0; aj < 8; aj = aj + 1)
                   attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
               idx = idx + 1;
            end
        // queen horizontal
        for (j = 0; j < 8; j = j + 1)
          if (j != COL)
            begin
               for (ai = 0; ai < 8; ai = ai + 1)
                 for (aj = 0; aj < 8; aj = aj + 1)
                   attack_array[ai][aj] = 0;
               attack_array[ROW][j] = ATTACK_QUEN;
               for (f = j + 1; f < COL; f = f + 1)
                 attack_array[ROW][f] = EMPTY_POSN2;
               for (f = COL + 1; f < j - 1; f = f + 1)
                 attack_array[ROW][f] = EMPTY_POSN2;
               for (ai = 0; ai < 8; ai = ai + 1)
                 for (aj = 0; aj < 8; aj = aj + 1)
                   attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
               idx = idx + 1;
            end
        // queen vertical
        for (i = 0; i < 8; i = i + 1)
          if (i != ROW)
            begin
               for (ai = 0; ai < 8; ai = ai + 1)
                 for (aj = 0; aj < 8; aj = aj + 1)
                   attack_array[ai][aj] = 0;
               attack_array[i][COL] = ATTACK_QUEN;
               for (f = i + 1; f < ROW; f = f + 1)
                 attack_array[f][COL] = EMPTY_POSN2;
               for (f = ROW + 1; f < i; f = f + 1)
                 attack_array[f][COL] = EMPTY_POSN2;
               for (ai = 0; ai < 8; ai = ai + 1)
                 for (aj = 0; aj < 8; aj = aj + 1)
                   attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
               idx = idx + 1;
            end
        // bishop, diag 0
        i = ROW - 1;
        j = COL - 1;
        while (i >= 0 && j >= 0)
          begin
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_array[ai][aj] = 0;
             attack_array[i][j] = ATTACK_BISH;
             fi = i + 1;
             fj = j + 1;
             while (fi < ROW && fj < COL)
               begin
                  attack_array[fi][fj] = EMPTY_POSN2;
                  fi = fi + 1;
                  fj = fj + 1;
               end
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
             idx = idx + 1;
             i = i - 1;
             j = j - 1;
          end
        // bishop, diag 1
        i = ROW + 1;
        j = COL + 1;
        while (i < 8 && j < 8)
          begin
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_array[ai][aj] = 0;
             attack_array[i][j] = ATTACK_BISH;
             fi = i - 1;
             fj = j - 1;
             while (fi > ROW && fj > COL)
               begin
                  attack_array[fi][fj] = EMPTY_POSN2;
                  fi = fi - 1;
                  fj = fj - 1;
               end
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
             idx = idx + 1;
             i = i + 1;
             j = j + 1;
          end
        // bishop, diag 2
        i = ROW - 1;
        j = COL + 1;
        while (i >= 0 && j < 8)
          begin
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_array[ai][aj] = 0;
             attack_array[i][j] = ATTACK_BISH;
             fi = i + 1;
             fj = j - 1;
             while (fi < ROW && fj > COL)
               begin
                  attack_array[fi][fj] = EMPTY_POSN2;
                  fi = fi + 1;
                  fj = fj - 1;
               end
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
             idx = idx + 1;
             i = i - 1;
             j = j + 1;
          end
        // bishop, diag 3
        i = ROW + 1;
        j = COL - 1;
        while (i < 8 && j < 8)
          begin
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_array[ai][aj] = 0;
             attack_array[i][j] = ATTACK_BISH;
             fi = i - 1;
             fj = j + 1;
             while (fi > ROW && fj < COL)
               begin
                  attack_array[fi][fj] = EMPTY_POSN2;
                  fi = fi - 1;
                  fj = fj + 1;
               end
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
             idx = idx + 1;
             i = i + 1;
             j = j - 1;
          end
        // queen, diag 0
        i = ROW - 1;
        j = COL - 1;
        while (i >= 0 && j >= 0)
          begin
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_array[ai][aj] = 0;
             attack_array[i][j] = ATTACK_QUEN;
             fi = i + 1;
             fj = j + 1;
             while (fi < ROW && fj < COL)
               begin
                  attack_array[fi][fj] = EMPTY_POSN2;
                  fi = fi + 1;
                  fj = fj + 1;
               end
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
             idx = idx + 1;
             i = i - 1;
             j = j - 1;
          end
        // queen, diag 1
        i = ROW + 1;
        j = COL + 1;
        while (i < 8 && j < 8)
          begin
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_array[ai][aj] = 0;
             attack_array[i][j] = ATTACK_QUEN;
             fi = i - 1;
             fj = j - 1;
             while (fi > ROW && fj > COL)
               begin
                  attack_array[fi][fj] = EMPTY_POSN2;
                  fi = fi - 1;
                  fj = fj - 1;
               end
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
             idx = idx + 1;
             i = i + 1;
             j = j + 1;
          end
        // queen, diag 2
        i = ROW - 1;
        j = COL + 1;
        while (i >= 0 && j < 8)
          begin
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_array[ai][aj] = 0;
             attack_array[i][j] = ATTACK_QUEN;
             fi = i + 1;
             fj = j - 1;
             while (fi < ROW && fj > COL)
               begin
                  attack_array[fi][fj] = EMPTY_POSN2;
                  fi = fi + 1;
                  fj = fj - 1;
               end
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
             idx = idx + 1;
             i = i - 1;
             j = j + 1;
          end
        // queen, diag 3
        i = ROW + 1;
        j = COL - 1;
        while (i < 8 && j < 8)
          begin
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_array[ai][aj] = 0;
             attack_array[i][j] = ATTACK_QUEN;
             fi = i - 1;
             fj = j + 1;
             while (fi > ROW && fj < COL)
               begin
                  attack_array[fi][fj] = EMPTY_POSN2;
                  fi = fi - 1;
                  fj = fj + 1;
               end
             for (ai = 0; ai < 8; ai = ai + 1)
               for (aj = 0; aj < 8; aj = aj + 1)
                 attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
             idx = idx + 1;
             i = i + 1;
             j = j - 1;
          end
        // knight
        knight_offset_x[0] = -2; knight_offset_y[0] = -1;
        knight_offset_x[1] = -1; knight_offset_y[1] = -2;
        knight_offset_x[2] = +1; knight_offset_y[2] = -2;
        knight_offset_x[3] = +2; knight_offset_y[3] = -1;
        knight_offset_x[4] = +2; knight_offset_y[4] = +1;
        knight_offset_x[5] = +1; knight_offset_y[5] = +2;
        knight_offset_x[6] = -1; knight_offset_y[6] = +2;
        knight_offset_x[7] = -2; knight_offset_y[7] = +1;
        for (i = 0; i < 8; i = i + 1)
          begin
             fi = ROW + knight_offset_y[i];
             fj = COL + knight_offset_x[i];
             if (fi >= 0 && fi < 8 && fj >= 0 && fj < 8)
               begin
                  for (ai = 0; ai < 8; ai = ai + 1)
                    for (aj = 0; aj < 8; aj = aj + 1)
                      attack_array[ai][aj] = 0;
                  attack_array[fi][fj] = ATTACK_KNIT;
                  for (ai = 0; ai < 8; ai = ai + 1)
                    for (aj = 0; aj < 8; aj = aj + 1)
                      attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
                  idx = idx + 1;
               end
          end
        // king
        king_offset_x[0] = -1; king_offset_y[0] = -1;
        king_offset_x[1] =  0; king_offset_y[1] = -1;
        king_offset_x[2] = +1; king_offset_y[2] = -1;
        king_offset_x[3] = +1; king_offset_y[3] =  0;
        king_offset_x[4] = +1; king_offset_y[4] = +1;
        king_offset_x[5] =  0; king_offset_y[5] = +1;
        king_offset_x[6] = -1; king_offset_y[6] = +1;
        king_offset_x[7] = -1; king_offset_y[7] =  0;
        for (i = 0; i < 8; i = i + 1)
            begin
               fi = ROW + king_offset_y[i];
               fj = COL + king_offset_x[i];
               if (fi >= 0 && fi < 8 && fj >= 0 && fj < 8)
                 begin
                    for (ai = 0; ai < 8; ai = ai + 1)
                      for (aj = 0; aj < 8; aj = aj + 1)
                        attack_array[ai][aj] = 0;
                    attack_array[fi][fj] = ATTACK_KING;
                    for (ai = 0; ai < 8; ai = ai + 1)
                      for (aj = 0; aj < 8; aj = aj + 1)
                        attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
                    idx = idx + 1;
                 end
            end
        // pawn
        if (ATTACKER == `WHITE_ATTACK)
          fi = ROW - 1;
        else
          fi = ROW + 1;
        if (fi >= 0 && fi < 8)
          begin
             fj = COL - 1;
             if (fj > 0)
               begin
                  for (ai = 0; ai < 8; ai = ai + 1)
                    for (aj = 0; aj < 8; aj = aj + 1)
                      attack_array[ai][aj] = 0;
                  attack_array[fi][fj] = ATTACK_PAWN;
                  for (ai = 0; ai < 8; ai = ai + 1)
                    for (aj = 0; aj < 8; aj = aj + 1)
                      attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
                  idx = idx + 1;
               end
             fj = COL + 1;
             if (fj < 8)
               begin
                  for (ai = 0; ai < 8; ai = ai + 1)
                    for (aj = 0; aj < 8; aj = aj + 1)
                      attack_array[ai][aj] = 0;
                  attack_array[fi][fj] = ATTACK_PAWN;
                  for (ai = 0; ai < 8; ai = ai + 1)
                    for (aj = 0; aj < 8; aj = aj + 1)
                      attack_mask[idx][ai * SIDE_WIDTH2 + aj * PIECE_WIDTH2+:PIECE_WIDTH2] = attack_array[ai][aj];
                  idx = idx + 1;
               end
          end
     end

   generate
      for (gen_i = 0; gen_i < 64; gen_i = gen_i + 1)
        begin : bitmap_assign_blk
           assign board2_t0[gen_i * PIECE_WIDTH2+:PIECE_WIDTH2] = 1 << (board[gen_i * PIECE_WIDTH+:PIECE_WIDTH]);
        end
   endgenerate

   always @(posedge clk)
     begin
        for (i = 0; i < ATTACK_COUNT; i = i + 1)
          if (attack_mask[i] != 0)
            attack_list_t1[i] <= (board2_t0 & attack_mask[i]) == attack_mask[i];
          else
            attack_list_t1[i] <= 1'b0;
        board_valid_t1 <= board_valid_t0;
        
        attacked <= attack_list_t1 != 0;
        attacked_valid <= board_valid_t1;
     end

endmodule
