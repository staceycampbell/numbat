`define EMPTY_POSN 0

`define WHITE_PAWN 1
`define WHITE_ROOK 2
`define WHITE_KNIT 3
`define WHITE_BISH 4
`define WHITE_KING 5
`define WHITE_QUEN 6

`define WHITE_MASK (1 << `WHITE_PAWN | 1 << `WHITE_ROOK | 1 << `WHITE_KNIT | 1 << `WHITE_BISH | 1 << `WHITE_KING | 1 << `WHITE_QUEN)

`define BLACK_PAWN 8
`define BLACK_ROOK 9
`define BLACK_KNIT 10
`define BLACK_BISH 11
`define BLACK_KING 12
`define BLACK_QUEN 13

`define BLACK_MASK (1 << `BLACK_PAWN | 1 << `BLACK_ROOK | 1 << `BLACK_KNIT | 1 << `BLACK_BISH | 1 << `BLACK_KING | 1 << `BLACK_QUEN)

`define PIECE_BITS 4
`define PIECE_MASK_BITS 14

`define WHITE_ATTACK 0
`define BLACK_ATTACK 1
