#include <stdio.h>
#include <stdint.h>
#include <assert.h>

#define EMPTY_POSN 0

#define PIECE_QUEN 1
#define PIECE_ROOK 2
#define PIECE_BISH 3
#define PIECE_PAWN 4
#define PIECE_KNIT 5
#define PIECE_KING 6

#define BLACK_BIT 3             // if set this is a black piece

#define WHITE_PAWN PIECE_PAWN
#define WHITE_ROOK PIECE_ROOK
#define WHITE_KNIT PIECE_KNIT
#define WHITE_BISH PIECE_BISH
#define WHITE_KING PIECE_KING
#define WHITE_QUEN PIECE_QUEN

#define BLACK_PAWN ((1 << BLACK_BIT) | PIECE_PAWN)
#define BLACK_ROOK ((1 << BLACK_BIT) | PIECE_ROOK)
#define BLACK_KNIT ((1 << BLACK_BIT) | PIECE_KNIT)
#define BLACK_BISH ((1 << BLACK_BIT) | PIECE_BISH)
#define BLACK_KING ((1 << BLACK_BIT) | PIECE_KING)
#define BLACK_QUEN ((1 << BLACK_BIT) | PIECE_QUEN)

#define PIECE_BITS 4
#define PIECE_MASK_BITS 15

#define WHITE_ATTACK 0
#define BLACK_ATTACK 1

#define CASTLE_WHITE_SHORT 0
#define CASTLE_WHITE_LONG 1
#define CASTLE_BLACK_SHORT 2
#define CASTLE_BLACK_LONG 3

#define EN_PASSANT_VALID_BIT 3

static void
fen_board(char buffer[4096], int board[8][8], int *white_to_move, int *castle_mask, int *en_passant_col, int *half_move_clock, int *full_move_number)
{
        int row, col, i, stop_col;

        row = 7;
        col = 0;
        i = 0;
        while (i < 4096 && buffer[i] != '\0' && !(buffer[i] == ' ' || buffer[i] == '\t'))
        {
                switch (buffer[i])
                {
                case 'r':
                        board[row][col] = BLACK_ROOK;
                        ++col;
                        break;
                case 'n':
                        board[row][col] = BLACK_KNIT;
                        ++col;
                        break;
                case 'b':
                        board[row][col] = BLACK_BISH;
                        ++col;
                        break;
                case 'q':
                        board[row][col] = BLACK_QUEN;
                        ++col;
                        break;
                case 'k':
                        board[row][col] = BLACK_KING;
                        ++col;
                        break;
                case 'p':
                        board[row][col] = BLACK_PAWN;
                        ++col;
                        break;
                case 'R':
                        board[row][col] = WHITE_ROOK;
                        ++col;
                        break;
                case 'N':
                        board[row][col] = WHITE_KNIT;
                        ++col;
                        break;
                case 'B':
                        board[row][col] = WHITE_BISH;
                        ++col;
                        break;
                case 'Q':
                        board[row][col] = WHITE_QUEN;
                        ++col;
                        break;
                case 'K':
                        board[row][col] = WHITE_KING;
                        ++col;
                        break;
                case 'P':
                        board[row][col] = WHITE_PAWN;
                        ++col;
                        break;
                case '/':
                        col = 0;
                        --row;
                        break;
                default:
                        assert(buffer[i] >= '1' && buffer[i] <= '8');
                        stop_col = col + buffer[i] - '1';
                        while (col <= stop_col)
                        {
                                board[row][col] = EMPTY_POSN;
                                ++col;
                        }
                        break;
                }
                ++i;
        }
        ++i;
        assert(i < 4096 && (buffer[i] == 'w' || buffer[i] == 'b'));
        *white_to_move = buffer[i] == 'w';
        i += 2;
        *castle_mask = 0;
        while (i < 4096 && buffer[i] != '\0' && !(buffer[i] == ' ' || buffer[i] == '\t'))
        {
                switch (buffer[i])
                {
                case 'K':
                        *castle_mask |= 1 << CASTLE_WHITE_SHORT;
                        break;
                case 'Q':
                        *castle_mask |= 1 << CASTLE_WHITE_LONG;
                        break;
                case 'k':
                        *castle_mask |= 1 << CASTLE_BLACK_SHORT;
                        break;
                case 'q':
                        *castle_mask |= 1 << CASTLE_BLACK_LONG;
                        break;
                case '-':
                        *castle_mask = 0;
                        break;
                default:
                        assert(0);
                        break;
                }
                ++i;
        }
        ++i;
        assert(i < 4096);
// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
        assert(buffer[i] == '-' || (buffer[i] >= 'a' && buffer[i] <= 'h'));
        if (buffer[i] == '-')
        {
                *en_passant_col = 0 << EN_PASSANT_VALID_BIT;
                ++i;
        }
        else
        {
                *en_passant_col = (1 << EN_PASSANT_VALID_BIT) | (buffer[i] - 'a');
                i += 2;
        }
        if (sscanf((char *)&buffer[i], "%d %d", half_move_clock, full_move_number) != 2)
                printf("%s: bad FEN half move clock or ful move number%s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
}

int
main(void)
{
        int i, row, col;
        int board[8][8];
        char buffer[4096];
        int white_to_move, castle_mask, en_passant_col, half_move_clock, full_move_number;
        char *defines[1 << PIECE_BITS];
        static const char spaces[9] = "        ";

        for (i = 0; i < (1 << PIECE_BITS); ++i)
                defines[i] = "EMPTY_POSN";
        defines[EMPTY_POSN] = "EMPTY_POSN";
        defines[WHITE_PAWN] = "WHITE_PAWN";
        defines[WHITE_ROOK] = "WHITE_ROOK";
        defines[WHITE_KNIT] = "WHITE_KNIT";
        defines[WHITE_BISH] = "WHITE_BISH";
        defines[WHITE_KING] = "WHITE_KING";
        defines[WHITE_QUEN] = "WHITE_QUEN";
        defines[BLACK_PAWN] = "BLACK_PAWN";
        defines[BLACK_ROOK] = "BLACK_ROOK";
        defines[BLACK_KNIT] = "BLACK_KNIT";
        defines[BLACK_BISH] = "BLACK_BISH";
        defines[BLACK_KING] = "BLACK_KING";
        defines[BLACK_QUEN] = "BLACK_QUEN";

        while (fgets(buffer, sizeof(buffer), stdin))
        {
                fen_board(buffer, board, &white_to_move, &castle_mask, &en_passant_col, &half_move_clock, &full_move_number);
                for (row = 7; row >= 0; --row)
                        for (col = 0; col < 8; ++col)
                                if (board[row][col] != EMPTY_POSN)
                                        printf("%sboard[%d * `SIDE_WIDTH + %d * `PIECE_WIDTH+:`PIECE_WIDTH] = `%s;\n", spaces, row, col, defines[board[row][col]]);
                printf("%swhite_to_move = %d;\n", spaces, white_to_move);
                printf("%scastle_mask = 4'h%X;\n", spaces, castle_mask);
                printf("%sen_passant_col = 4'h%X;\n", spaces, en_passant_col);
                printf("%shalf_move = %d;\n", spaces, half_move_clock);
                printf("%sfull_move_number = %d;\n", spaces, full_move_number);
        }

        return 0;
}
