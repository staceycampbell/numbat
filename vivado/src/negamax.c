#include <stdio.h>
#include <stdint.h>
#include <xil_printf.h>
#include <xtime_l.h>
#include <xil_io.h>
#include "vchess.h"

#define DEPTH_MAX 4

static uint32_t board_count[DEPTH_MAX];
static board_t root_node_boards[MAX_POSITIONS];
static uint32_t nodes_searched;

static int32_t
nm_load_positions(board_t boards[MAX_POSITIONS])
{
	int32_t i;
	uint32_t moves_ready, status, move_count;

	vchess_status(0, &moves_ready, 0, 0);
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
negamax(board_t *board, int32_t depth, int32_t a, int32_t b)
{
	uint32_t move_count, index;
	int32_t value, best_score;
	uint32_t status;
	board_t board_stack[MAX_POSITIONS];

	++nodes_searched;
	vchess_write_board(board);
	move_count = vchess_move_count();
	if (depth == 0 || move_count == 0)
	{
		value = vchess_initial_eval();
		return value;
	}
	for (index = 0; index < move_count; ++index)
	{
		status = vchess_read_board(&board_stack[index], index);
		if (status)
		{
			xil_printf("%s: problem reading boards (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
			return 0;
		}
	}
	board_count[depth] = move_count;
	best_score = INT32_MIN;
	index = 0;
	do
	{
		value = -negamax(&board_stack[index], depth - 1, -b, -a);
		if (value >= b)
			return value;
		if (value > best_score)
			best_score = value;
		if (value > a)
			a = value;
		++index;
	} while (index < move_count);

	return best_score;
}

board_t
nm_top(board_t *board)
{
	int32_t i, status;
	uint32_t moves_ready, move_count, elapsed_ticks;
	double elapsed_time, nps;
	int32_t evaluate_move, best_evaluation;
	board_t best_board;
	XTime t_end, t_start;

	nodes_searched = 0;
	XTime_GetTime(&t_start);
	vchess_write_board(board);
	i = 0;
	do
	{
		vchess_status(0, &moves_ready, 0, 0);
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

	XTime_GetTime(&t_end);
	elapsed_ticks = t_end - t_start;
	elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
	if (elapsed_time == 0.0) // hmm
		elapsed_time = 1.0;
	nps = (double)nodes_searched * (1.0 / elapsed_time);
	printf("best_evaluation=%d, nodes_searched=%u, seconds=%f, nps=%f\n", best_evaluation, nodes_searched, elapsed_time, nps);

	return best_board;
}
