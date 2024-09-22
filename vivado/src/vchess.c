#include <stdlib.h>
#include <unistd.h>
#include <xil_printf.h>
#include "vchess.h"

static char piece_char[1 << PIECE_BITS];

uint32_t
vchess_get_piece(board_t *board, uint32_t row, uint32_t col)
{
	uint32_t row_contents, shift, piece;

	row_contents = board->board[row];
	shift = col * PIECE_BITS;
	piece = (row_contents >> shift) & 0xF;

	return piece;
}

void
vchess_place(board_t *board, uint32_t row, uint32_t col, uint32_t piece)
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

	piece = vchess_get_piece(board, row_from, col_from);
	occupied = vchess_get_piece(board, row_to, col_to) != EMPTY_POSN;
	vchess_place(board, row_from, col_from, EMPTY_POSN);
	vchess_place(board, row_to, col_to, piece);

	return occupied;
}

void
vchess_print_board(board_t *board, uint32_t initial_board)
{
	int y, x;
	uint32_t piece;
	int32_t eval;
	static const char *to_move[2] = {"Black", "White"};

	for (y = 7; y >= 0; --y)
	{
		for (x = 0; x < 8; ++x)
		{
			piece = vchess_get_piece(board, y, x);
			xil_printf("%c ", piece_char[piece]);
		}
		xil_printf("\n");
	}
	if (initial_board)
		eval = vchess_initial_eval();
	else
		eval = board->eval;
	xil_printf("%s to move, en passant col: %1X, castle mask: %1X, eval: %d", to_move[board->white_to_move],
		   board->en_passant_col, board->castle_mask, eval);
	if (! initial_board)
		xil_printf(", capture: %d, half move: %d", board->capture, board->half_move_clock);
	else
		xil_printf(", legal moves: %d", vchess_move_count());
	xil_printf("\n");
	if (board->black_in_check)
		xil_printf("Black in check\n");
	if (board->white_in_check)
		xil_printf("White in check\n");
}

void
vchess_write_board(board_t *board)
{
	int i;
	uint32_t moves_ready;

	vchess_write_control(1, 0, 1); // soft reset, new board valid, clear moves
	vchess_write_control(0, 0, 0);
	for (i = 0; i < 8; ++i)
		vchess_write_board_row(i, board->board[i]);
	vchess_write_board_misc(board->white_to_move, board->castle_mask, board->en_passant_col);
	vchess_write_half_move(board->half_move_clock);
	vchess_write_control(0, 1, 0); // new board valid bit set
	vchess_write_control(0, 0, 0); // new board valid bit clear
	i = 0;
	do
	{
		vchess_status(0, &moves_ready, 0, 0);
		++i;
	} while (i < 1000 && ! moves_ready);
	if (! moves_ready)
		xil_printf("%s: problems in vchess_write_board (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
}

uint32_t
vchess_read_board(board_t *board, uint32_t index)
{
	uint32_t move_count;
	uint32_t move_ready, moves_ready;
	uint32_t y;
	uint32_t status;

	move_count = vchess_move_count();
	if (move_count >= MAX_POSITIONS)
	{
		xil_printf("%s: stopping here, %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		while (1);
	}
	status = vchess_status(&move_ready, &moves_ready, 0, 0);
	if (! moves_ready)
	{
		xil_printf("moves_ready not set\n");
		return 2;
	}
	if (index >= move_count)
	{
		xil_printf("bad index %d, move count is %d\n", index, move_count);
		return 1;
	}
	vchess_move_index(index);
	status = vchess_status(&move_ready, 0, 0, 0);
	if (! move_ready)
	{
		xil_printf("move_ready not set: 0x%X\n", status);
		return 3;
	}

	for (y = 0; y < 8; ++y)
		board->board[y] = vchess_read_move_row(y);
	vchess_board_status0(&board->black_in_check, &board->white_in_check, &board->capture);
	vchess_board_status1(&board->white_to_move, &board->castle_mask, &board->en_passant_col);
	board->eval = vchess_move_eval();
	board->half_move_clock = vchess_read_half_move();

	return 0;
}

void
vchess_init_board(board_t *board)
{
	int i, j;

	for (i = 2; i <= 5; ++i)
		for (j = 0; j < 8; ++j)
			vchess_place(board, i, j, EMPTY_POSN);
	for (j = 0; j < 8; ++j)
	{
		vchess_place(board, 1, j, WHITE_PAWN);
		vchess_place(board, 6, j, BLACK_PAWN);
	}
	vchess_place(board, 0, 0, WHITE_ROOK);
	vchess_place(board, 0, 1, WHITE_KNIT);
	vchess_place(board, 0, 2, WHITE_BISH);
	vchess_place(board, 0, 3, WHITE_QUEN);
	vchess_place(board, 0, 4, WHITE_KING);
	vchess_place(board, 0, 5, WHITE_BISH);
	vchess_place(board, 0, 6, WHITE_KNIT);
	vchess_place(board, 0, 7, WHITE_ROOK);

	vchess_place(board, 7, 0, BLACK_ROOK);
	vchess_place(board, 7, 1, BLACK_KNIT);
	vchess_place(board, 7, 2, BLACK_BISH);
	vchess_place(board, 7, 3, BLACK_QUEN);
	vchess_place(board, 7, 4, BLACK_KING);
	vchess_place(board, 7, 5, BLACK_BISH);
	vchess_place(board, 7, 6, BLACK_KNIT);
	vchess_place(board, 7, 7, BLACK_ROOK);

	board->en_passant_col = 0 << EN_PASSANT_VALID_BIT;
	board->castle_mask = 0xF;
	board->white_to_move = 1;
}

void
vchess_repdet_entry(uint32_t index, uint32_t board[8], uint32_t castle_mask)
{
	vchess_repdet_board(board);
	vchess_repdet_castle_mask(castle_mask);
	vchess_repdet_write(index);
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
