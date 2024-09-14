`include "vchess.vh"

module is_attacking #
  (
   parameter ATTACKER = `WHITE_ATTACK,
   parameter ROW = 0,
   parameter COL = 0
   )
   (
    input                     clk,
    input                     reset,
   
    input [`BOARD_WIDTH - 1:0] board,
    input                     board_valid,

    output                    attacking,
    output                    opponent_in_check,
    output                    attacking_valid
    );

   localparam PIECE_WIDTH2 = `PIECE_MASK_BITS;
   localparam SIDE_WIDTH2 = PIECE_WIDTH2 * 8;
   localparam BOARD_WIDTH2 = SIDE_WIDTH2 * 8;

   // convert encoded piece id to bitmask piece id
   localparam EMPTY_POSN2 = 1 << `EMPTY_POSN;
   localparam ATTACK_ROOK = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_ROOK : `BLACK_ROOK);
   localparam ATTACK_KNIT = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_KNIT : `BLACK_KNIT);
   localparam ATTACK_BISH = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_BISH : `BLACK_BISH);
   localparam ATTACK_QUEN = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_QUEN : `BLACK_QUEN);
   localparam ATTACK_KING = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_KING : `BLACK_KING);
   localparam ATTACK_PAWN = 1 << (ATTACKER == `WHITE_ATTACK ? `WHITE_PAWN : `BLACK_PAWN);

   localparam PIECE_MASK = ATTACKER == `WHITE_ATTACK ? `WHITE_MASK : `BLACK_MASK;
   
   localparam ATTACKED_KING = 1 << (ATTACKER == `BLACK_ATTACK ? `WHITE_KING : `BLACK_KING);
   
   // maximum number of attacks possible from any square on the board using any piece
   localparam ATTACK_COUNT = 75;

   reg [BOARD_WIDTH2 - 1:0]   attack_mask [0:ATTACK_COUNT - 1];
   reg [ATTACK_COUNT - 1:0]   attack_list_t1;
   reg                        attacking_valid_t1;
   reg                        board_valid_t1;
   reg                        opponent_king_t1;
   reg                        attacking_t2;
   reg                        attacking_valid_t2;
   reg                        opponent_in_check_t2;

   integer                    i;
   genvar                     gen_i;

   wire [63:0]                my_piece_t0;
   wire [BOARD_WIDTH2 - 1:0]  board2_t0;
   wire                       board_valid_t0 = board_valid;
   wire [PIECE_WIDTH2 - 1:0]  piece_t0 = board2_t0[ROW * SIDE_WIDTH2 + COL * PIECE_WIDTH2+:PIECE_WIDTH2];
   wire [PIECE_WIDTH2 - 1:0]  attacked_king_t0 = ATTACKED_KING;
   wire                       opponent_king_t0 = piece_t0 == attacked_king_t0;

   generate
      for (gen_i = 0; gen_i < 64; gen_i = gen_i + 1)
        begin : bitmap_assign_blk
           assign board2_t0[gen_i * PIECE_WIDTH2+:PIECE_WIDTH2] = 1 << (board[gen_i * `PIECE_WIDTH+:`PIECE_WIDTH]);
           assign my_piece_t0[gen_i] = (board2_t0[gen_i * PIECE_WIDTH2+:PIECE_WIDTH2] & PIECE_MASK) != 0;
        end
   endgenerate

   assign attacking = attacking_t2;
   assign attacking_valid = attacking_valid_t2;
   assign opponent_in_check = opponent_in_check_t2;

   initial
     begin
        `include "attack_mask.vh"
     end

   always @(posedge clk)
     begin
        for (i = 0; i < ATTACK_COUNT; i = i + 1)
          if (attack_mask[i] != 0 && ! my_piece_t0[ROW << 3 | COL])
            attack_list_t1[i] <= ((board2_t0 & attack_mask[i]) == attack_mask[i]);
          else
            attack_list_t1[i] <= 1'b0;
        board_valid_t1 <= board_valid_t0;
        opponent_king_t1 <= opponent_king_t0;
        
        attacking_t2 <= attack_list_t1 != 0;
        attacking_valid_t2 <= board_valid_t1;
        opponent_in_check_t2 <= attack_list_t1 != 0 && opponent_king_t1;
     end

endmodule
