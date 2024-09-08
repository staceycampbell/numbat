#include <stdlib.h>
#include <unistd.h>
#include <xil_printf.h>
#include "vchess.h"

static char piece_char[1 << PIECE_BITS];

static uint32_t
get_piece(board_t *board, uint32_t row, uint32_t col)
{
	uint32_t row_contents, shift, piece;

	row_contents = board->board[row];
	shift = col * PIECE_BITS;
	piece = (row_contents >> shift) & 0xF;

	return piece;
}

static void
place(board_t *board, uint32_t row, uint32_t col, uint32_t piece)
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
vchess_move_piece(board_t *board, uint32_t row_from, uint32_t col_from, uint32_t row_to, uint32_t col_to)
{
	uint32_t piece, occupied;

	piece = get_piece(board, row_from, col_from);
	occupied = get_piece(board, row_to, col_to) != EMPTY_POSN;
	place(board, row_from, col_from, EMPTY_POSN);
	place(board, row_to, col_to, piece);

	return occupied;
}

void
vchess_print_board(board_t *board)
{
	int y, x;
	uint32_t piece;
	static const char *to_move[2] = {"Black", "White"};

	for (y = 7; y >= 0; --y)
	{
		for (x = 0; x < 8; ++x)
		{
			piece = get_piece(board, y, x);
			xil_printf("%c ", piece_char[piece]);
		}
		xil_printf("\n");
	}
	xil_printf("%s to move, en passant col: %1X, castle mask: %1X", to_move[board->white_to_move],
		   board->en_passant_col, board->castle_mask);
	if (board->eval_valid)
		xil_printf(", eval: %d", board->eval);
	xil_printf("\n");
}

void
vchess_write_board(board_t *board)
{
	int i;

	vchess_write_control(1, 0, 1, 1); // soft reset, clear moves, clear eval
	vchess_write_control(0, 0, 0, 0);
	for (i = 0; i < 8; ++i)
		vchess_write_board_row(i, board->board[i]);
	vchess_write_board_misc(board->white_to_move, board->castle_mask, board->en_passant_col);
	vchess_write_control(0, 1, 0, 0); // new board valid bit set
	vchess_write_control(0, 0, 0, 0); // new board valid bit clear
}

uint32_t
vchess_read_board(board_t *board, uint32_t index)
{
	uint32_t move_count;
	uint32_t eval_valid, move_ready, moves_ready;
	uint32_t y;

	move_count = vchess_move_count();
	if (index >= move_count)
	{
		xil_printf("bad index %d, move count is %d\n", index, move_count);
		return 1;
	}
	vchess_status(&eval_valid, &move_ready, &moves_ready);
	if (! moves_ready)
	{
		xil_printf("moves_ready not set\n");
		return 2;
	}
	vchess_move_index(index);
	usleep(100);
	vchess_status(&eval_valid, &move_ready, &moves_ready);
	if (! eval_valid)
	{
		xil_printf("eval_valid not set\n");
		return 3;
	}
	xil_printf("move count: %d\n", move_count);

	for (y = 0; y < 8; ++y)
		board->board[y] = vchess_read_move_row(y);
	vchess_board_status1(&board->white_to_move, &board->castle_mask, &board->en_passant_col);
	board->eval_valid = 1;
	board->eval = vchess_eval();

	return 0;
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
	board->eval_valid = 0;
}

void
vchess_init(void)
{
	int i;
	
	for (i = 0; i < (1 << PIECE_BITS); ++i)
		piece_char[i] = '?';
	piece_char[EMPTY_POSN] = '.';
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
}
