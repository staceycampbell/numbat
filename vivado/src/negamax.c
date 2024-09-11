#include <stdint.h>
#include <xil_printf.h>
#include "vchess.h"

#define DEPTH_MAX 4
#define VALUE_KING 10000 // must match evaluate.sv

static board_t board_stack[DEPTH_MAX][MAX_POSITIONS];
static uint32_t board_count[DEPTH_MAX];
static board_t root_node_boards[MAX_POSITIONS];

static int32_t
nm_load_positions(board_t boards[MAX_POSITIONS])
{
	int32_t i;
	uint32_t moves_ready, status, move_count;

	vchess_status(0, 0, &moves_ready, 0, 0);
	if (! moves_ready)
	{
		xil_printf("%s: moves_ready not set (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return -1;
	}
	move_count = vchess_move_count();
	if (move_count == 0)
	{
		xil_printf("%s: no moves available (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return -2;
	}
	for (i = 0; i < move_count; ++i)
	{
		status = vchess_read_board(&boards[i], i);
		if (status)
		{
			xil_printf("%s: problem with vchess_read_board (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
			return -3;
		}
	}
	return move_count;
}

static int32_t
valmax(int32_t a, int32_t b)
{
	if (a > b)
		return a;
	return b;
}

static int32_t
negamax(board_t *board, int32_t depth, int32_t a, int32_t b)
{
	uint32_t move_count, mate, stalemate, index;
	int32_t value;
	uint32_t status;
	
	vchess_write_board(board);
	move_count = vchess_move_count();
	if (move_count == 0)
	{
		vchess_status(0, 0, 0, &mate, &stalemate);
		if (stalemate)
			return 0;
		if (! mate)
		{
			xil_printf("%s: problem, no moves but no mate or stalemate (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
			return 0;
		}
		value = VALUE_KING + DEPTH_MAX - depth;
		if (board->white_to_move)
			return -value;
		return value;
	}
	if (depth == 0)
	{
		if (! board->eval_valid)
		{
			xil_printf("%s: problem, no evaluation for board (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
			return 0;
		}
		value = board->eval;
		return value;
	}
	if (depth < 0 || depth >= DEPTH_MAX)
	{
		xil_printf("%s: bad recursion (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return 0;
	}
	for (index = 0; index < move_count; ++index)
	{
		status = vchess_read_board(&board_stack[depth][index], index);
		if (status)
		{
			xil_printf("%s: problem reading boards (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
			return 0;
		}
	}
	board_count[depth] = move_count;
	value = INT32_MIN;
	index = 0;
	do
	{
		value = valmax(value, -negamax(&board_stack[depth][index], depth - 1, -b, -a));
		a = valmax(a, value);
		++index;
	} while (index < board_count[depth] && a < b);

	return value;
}

board_t
nm_top(board_t *board)
{
	int32_t i, status;
	uint32_t moves_ready, move_count;
	int32_t evaluate_move, best_evaluation;
	board_t best_board;

	vchess_write_board(board);
	i = 0;
	do
	{
		vchess_status(0, 0, &moves_ready, 0, 0);
		++i;
	} while (i < 1000 && ! moves_ready);
	if (! moves_ready)
	{
		xil_printf("%s: moves_ready timeout (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return *board;
	}
	move_count = vchess_move_count();
	if (move_count == 0)
	{
		xil_printf("%s: game is over, no moves (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return *board;
	}
	status = nm_load_positions(root_node_boards);
	if (status != move_count)
	{
		xil_printf("%s: bad call to nm_load_positions (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return *board;
	}
	best_evaluation = INT32_MIN;
	for (i = 0; i < move_count; ++i)
	{
		evaluate_move = -negamax(&root_node_boards[i], DEPTH_MAX - 1, INT32_MIN, INT32_MAX);
		if (evaluate_move > best_evaluation)
		{
			best_evaluation = evaluate_move;
			best_board = root_node_boards[i];
		}
	}

	return best_board;
}
