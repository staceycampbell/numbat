#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#define EXCLUDE_VITIS 1
#include "../vivado/src/numbat.h"

static board_t game[GAME_MAX];
static uint32_t game_moves;

void
fen_print(const board_t * board, uint32_t nl)
{
        int row, col, empty, i;
        uint32_t piece;
        char en_passant_col;
        char piece_char[1 << PIECE_BITS];

        for (i = 0; i < (1 << PIECE_BITS); ++i)
                piece_char[i] = '?';
        piece_char[WHITE_PAWN] = 'P';
        piece_char[WHITE_ROOK] = 'R';
        piece_char[WHITE_KNIT] = 'N';
        piece_char[WHITE_BISH] = 'B';
        piece_char[WHITE_KING] = 'K';
        piece_char[WHITE_QUEN] = 'Q';
        piece_char[BLACK_PAWN] = 'p';
        piece_char[BLACK_ROOK] = 'r';
        piece_char[BLACK_KNIT] = 'n';
        piece_char[BLACK_BISH] = 'b';
        piece_char[BLACK_KING] = 'k';
        piece_char[BLACK_QUEN] = 'q';

        for (row = 7; row >= 0; --row)
        {
                empty = 0;
                for (col = 0; col < 8; ++col)
                {
                        piece = numbat_get_piece(board, row, col);
                        if (piece == EMPTY_POSN)
                                ++empty;
                        else
                        {
                                if (empty > 0)
                                {
                                        printf("%d", empty);
                                        empty = 0;
                                }
                                printf("%c", piece_char[piece]);
                        }
                }
                if (empty > 0)
                        printf("%d", empty);
                if (row > 0)
                        printf("/");
        }
        printf(" ");
// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
        if (board->white_to_move)
                printf("w");
        else
                printf("b");
        printf(" ");
        if (board->castle_mask == 0)
                printf("-");
        if ((board->castle_mask & (1 << CASTLE_WHITE_SHORT)) != 0)
                printf("K");
        if ((board->castle_mask & (1 << CASTLE_WHITE_LONG)) != 0)
                printf("Q");
        if ((board->castle_mask & (1 << CASTLE_BLACK_SHORT)) != 0)
                printf("k");
        if ((board->castle_mask & (1 << CASTLE_BLACK_LONG)) != 0)
                printf("q");
        printf(" ");
        if ((board->en_passant_col & (1 << EN_PASSANT_VALID_BIT)) == 0)
                printf("-");
        else
        {
                en_passant_col = 'a' + (board->en_passant_col & 0x7);
                if (board->white_to_move)
                        printf("%c6", en_passant_col);
                else
                        printf("%c3", en_passant_col);
        }
        printf(" %d %d\n", board->half_move_clock, board->full_move_number);
}

void
numbat_place(board_t *board, uint32_t row, uint32_t col, uint32_t piece)
{
        uint32_t row_contents;
        uint32_t shift;

        shift = col * PIECE_BITS;
        row_contents = board->board[row];
        row_contents &= ~(0xF << shift);
        row_contents |= piece << shift;
        board->board[row] = row_contents;
}

uint32_t
numbat_get_piece(const board_t *board, uint32_t row, uint32_t col)
{
        uint32_t row_contents, shift, piece;

        row_contents = board->board[row];
        shift = col * PIECE_BITS;
        piece = (row_contents >> shift) & 0xF;

        return piece;
}

void
move_string(char *p)
{
        int32_t col_from, row_from, col_to, row_to;
        uint32_t piece, promotion, piece_type;
        board_t *previous_board, next_board;

        previous_board = &game[game_moves - 1];
        next_board = *previous_board;
        next_board.capture = 0;
        next_board.white_to_move = ! previous_board->white_to_move;
        if (next_board.white_to_move)
                ++next_board.full_move_number;
	++next_board.half_move_clock;
	next_board.en_passant_col = 0 << EN_PASSANT_VALID_BIT;
        
        col_from = p[0] - 'a';
        row_from = p[1] - '1';
        col_to = p[2] - 'a';
        row_to = p[3] - '1';
        switch (p[4])
        {
        case 'Q' :
                promotion = PIECE_QUEN;
                break;
        case 'N' :
                promotion = PIECE_KNIT;
                break;
        case 'B' :
                promotion = PIECE_BISH;
                break;
        case 'R' :
                promotion = PIECE_ROOK;
                break;
        case '\0' :
                promotion = EMPTY_POSN;
                break;
        default :
                fprintf(stderr, "%s: problems (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                exit(1);
        }
        if (promotion != EMPTY_POSN)
                if (previous_board->white_to_move)
                        promotion |= 0 << BLACK_BIT;
                else
                        promotion |= 1 << BLACK_BIT;
        next_board.uci.row_from = row_from;
        next_board.uci.col_from = col_from;
        next_board.uci.row_to = row_to;
        next_board.uci.col_to = col_to;
        next_board.uci.promotion = promotion;
        
        piece = numbat_get_piece(previous_board, row_from, col_from);
        piece_type = piece & ~(1 << BLACK_BIT);

        // unconditionally vacate "from" square
        numbat_place(&next_board, row_from, col_from, EMPTY_POSN);

        if (piece == WHITE_ROOK && row_from == 0)
        {
                if (col_from == 7)
                        next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_WHITE_SHORT);
                else if (col_from == 0)
                        next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_WHITE_LONG);
        }
        else if (piece == BLACK_ROOK && row_from == 7)
        {
                if (col_from == 7)
                        next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_BLACK_SHORT);
                else if (col_from == 0)
                        next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_BLACK_LONG);
        } else if (piece == WHITE_KING)
                next_board.castle_mask = previous_board->castle_mask &
                        ~(1 << CASTLE_WHITE_SHORT | 1 << CASTLE_WHITE_LONG);
        else if (piece == BLACK_KING)
                next_board.castle_mask = previous_board->castle_mask &
                        ~(1 << CASTLE_BLACK_SHORT | 1 << CASTLE_BLACK_LONG);

        // castling
        if (piece == WHITE_KING && row_from == 0 && row_to == 0 && col_from == 4 && col_to == 6)
        {
                numbat_place(&next_board, row_from, 7, EMPTY_POSN);
                numbat_place(&next_board, row_from, 5, WHITE_ROOK);
                numbat_place(&next_board, row_from, 6, WHITE_KING);
        }
        else if (piece == WHITE_KING && row_from == 0 && row_to == 0 && col_from == 4 && col_to == 2)
        {
                numbat_place(&next_board, row_from, 0, EMPTY_POSN);
                numbat_place(&next_board, row_from, 1, EMPTY_POSN);
                numbat_place(&next_board, row_from, 3, WHITE_ROOK);
                numbat_place(&next_board, row_from, 2, WHITE_KING);
        }
        else if (piece == BLACK_KING && row_from == 7 && row_to == 7 && col_from == 4 && col_to == 6)
        {
                numbat_place(&next_board, row_from, 7, EMPTY_POSN);
                numbat_place(&next_board, row_from, 5, BLACK_ROOK);
                numbat_place(&next_board, row_from, 6, BLACK_KING);
        }
        else if (piece == BLACK_KING && row_from == 0 && row_to == 0 && col_from == 4 && col_to == 2)
        {
                numbat_place(&next_board, row_from, 0, EMPTY_POSN);
                numbat_place(&next_board, row_from, 1, EMPTY_POSN);
                numbat_place(&next_board, row_from, 3, WHITE_ROOK);
                numbat_place(&next_board, row_from, 2, WHITE_KING);
        }
	// en-passant target
	else if (piece == WHITE_PAWN && row_from == 1 && row_to == 3)
	{
		numbat_place(&next_board, row_to, col_to, WHITE_PAWN);
		next_board.half_move_clock = 0;
		next_board.en_passant_col = 1 << EN_PASSANT_VALID_BIT | col_to;
	}
	else if (piece == BLACK_PAWN && row_from == 6 && row_to == 4)
	{
		numbat_place(&next_board, row_to, col_to, BLACK_PAWN);
		next_board.half_move_clock = 0;
		next_board.en_passant_col = 1 << EN_PASSANT_VALID_BIT | col_to;
	}
        // en-passant capture
        else if (piece == WHITE_PAWN && numbat_get_piece(previous_board, row_to, col_to) == EMPTY_POSN && col_from != col_to)
        {
                numbat_place(&next_board, row_to, col_to, WHITE_PAWN);
                numbat_place(&next_board, row_to, col_to - 1, EMPTY_POSN);
                next_board.capture = 1;
                next_board.half_move_clock = 0;
        }
        else if (piece == BLACK_PAWN && numbat_get_piece(previous_board, row_to, col_to) == EMPTY_POSN && col_from != col_to)
        {
                numbat_place(&next_board, row_to, col_to, BLACK_PAWN);
                numbat_place(&next_board, row_to, col_to + 1, EMPTY_POSN);
                next_board.capture = 1;
                next_board.half_move_clock = 0;
        }
        // promotion
        else if (piece == WHITE_PAWN && row_to == 7)
        {
                numbat_place(&next_board, 7, col_to, promotion);
                next_board.capture = numbat_get_piece(previous_board, 7, col_to) != EMPTY_POSN;
                next_board.half_move_clock = 0;
        }
        else if (piece == BLACK_PAWN && row_to == 0)
        {
                numbat_place(&next_board, 0, col_to, promotion);
                next_board.capture = numbat_get_piece(previous_board, 7, col_to) != EMPTY_POSN;
                next_board.half_move_clock = 0;
        }
        // all other moves
        else
        {
                numbat_place(&next_board, row_to, col_to, piece);
                next_board.capture = numbat_get_piece(previous_board, row_to, col_to) != EMPTY_POSN;
                if (next_board.capture || piece_type == PIECE_PAWN)
                        next_board.half_move_clock = 0;
        }
	game[game_moves] = next_board;
	++game_moves;
}

int
main(int argc, char *argv[])
{
        int i, j;
        char buffer[65536];
        char *p, *next;
        size_t buffer_count;

        for (i = 2; i <= 5; ++i)
                for (j = 0; j < 8; ++j)
                        numbat_place(&game[0], i, j, EMPTY_POSN);
        for (j = 0; j < 8; ++j)
        {
                numbat_place(&game[0], 1, j, WHITE_PAWN);
                numbat_place(&game[0], 6, j, BLACK_PAWN);
        }
        numbat_place(&game[0], 0, 0, WHITE_ROOK);
        numbat_place(&game[0], 0, 1, WHITE_KNIT);
        numbat_place(&game[0], 0, 2, WHITE_BISH);
        numbat_place(&game[0], 0, 3, WHITE_QUEN);
        numbat_place(&game[0], 0, 4, WHITE_KING);
        numbat_place(&game[0], 0, 5, WHITE_BISH);
        numbat_place(&game[0], 0, 6, WHITE_KNIT);
        numbat_place(&game[0], 0, 7, WHITE_ROOK);

        numbat_place(&game[0], 7, 0, BLACK_ROOK);
        numbat_place(&game[0], 7, 1, BLACK_KNIT);
        numbat_place(&game[0], 7, 2, BLACK_BISH);
        numbat_place(&game[0], 7, 3, BLACK_QUEN);
        numbat_place(&game[0], 7, 4, BLACK_KING);
        numbat_place(&game[0], 7, 5, BLACK_BISH);
        numbat_place(&game[0], 7, 6, BLACK_KNIT);
        numbat_place(&game[0], 7, 7, BLACK_ROOK);

        game[0].en_passant_col = 0 << EN_PASSANT_VALID_BIT;
        game[0].castle_mask = 0xF;
        game[0].white_to_move = 1;
        game[0].half_move_clock = 0;
        game[0].full_move_number = 1;

        game_moves = 1;

        buffer_count = fread(buffer, 1, sizeof(buffer), stdin);
        if (buffer_count == 0)
        {
                fprintf(stderr, "%s: no data read\n", argv[0]);
                exit(1);
        }
        i = buffer_count - 1;
        while (i >= 0 && buffer[i] != ']')
                --i;
        if (i < 0)
        {
                fprintf(stderr, "%s: backwards search for ']' failed\n", argv[0]);
                exit(1);
        }
        ++i;
        while (i < buffer_count && isspace(buffer[i]))
                ++i;
        if (i == buffer_count)
        {
                fprintf(stderr, "%s: could not find UCI move list\n", argv[0]);
                exit(1);
        }
        p = &buffer[i];
        do
        {
                next = p;
                p = strsep(&next, " \n\t\r");
                if (p && ! (*p == '0' || *p == '1'))
                {
                        if (strlen(p) > 1)
                                move_string(p);
                        p = next;
                }
        } while (next);

	for (i = 0; i < game_moves; ++i)
		fen_print(&game[i], 1);

        return 0;
}
