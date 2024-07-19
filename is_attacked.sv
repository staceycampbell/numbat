module is_attacked #
  (
   parameter PIECE_WIDTH = 0,
   parameter ROW_WIDTH = 0,
   parameter BOARD_WIDTH = 0,
   parameter ATTACKER = `WHITE_ATTACK,
   parameter RANK = 0,
   parameter FILE = 0
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

endmodule
