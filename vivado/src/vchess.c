#include <stdint.h>
#include "vchess.h"

static uint32_t
get_piece(board_t *board, uint32_t row, uint32_t col)
{
	uint32_t row_contents, shift, piece;

	row_contents = board->board[row];
	shift = col * 4;
	piece = (row_contents >> shift) & 0xF;

	return piece;
}

static void
place(board_t *board, uint32_t piece, uint32_t row, uint32_t col)
{
	uint32_t row_contents;
	uint32_t shift;

	shift = col * 4;
	row_contents = board->board[row];
	row_contents &= ~(0xF << shift);
	row_contents |= piece << shift;
	board->board[row] = piece;
}

uint32_t
move_piece(board_t *board, uint32_t row_from, uint32_t col_from, uint32_t row_to, uint32_t col_to)
{
	uint32_t piece, occupied;

	piece = get_piece(board, row_from, col_from);
	occupied = get_piece(board, row_to, col_to) != EMPTY_POSN;
	place(board, EMPTY_POSN, row_from, col_from);
	place(board, piece, row_to, col_to);

	return occupied;
}

void
vchess_init_board(board_t *board)
{
	int i, j;

	for (i = 2; i <= 5; ++i)
		for (j = 0; j < 8; ++j)
			place(board, i, j, EMPTY_POSN);
	for (j = 0; j < 8; ++j)
	{
		place(board, 1, j, WHITE_PAWN);
		place(board, 6, j, BLACK_PAWN);
	}
	place(board, 0, 0, WHITE_ROOK);
	place(board, 0, 1, WHITE_KNIT);
	place(board, 0, 2, WHITE_BISH);
	place(board, 0, 3, WHITE_QUEN);
	place(board, 0, 4, WHITE_KING);
	place(board, 0, 5, WHITE_BISH);
	place(board, 0, 6, WHITE_KNIT);
	place(board, 0, 7, WHITE_ROOK);

	place(board, 7, 0, BLACK_ROOK);
	place(board, 7, 1, BLACK_KNIT);
	place(board, 7, 2, BLACK_BISH);
	place(board, 7, 3, BLACK_QUEN);
	place(board, 7, 4, BLACK_KING);
	place(board, 7, 5, BLACK_BISH);
	place(board, 7, 6, BLACK_KNIT);
	place(board, 7, 7, BLACK_ROOK);

	board->en_passant_col = 0 << EN_PASSANT_VALID_BIT;
	board->castle_mask = 0xF;
	board->white_to_move = 1;
}
