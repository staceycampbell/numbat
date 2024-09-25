#include <stdio.h>
#include <stdint.h>
#include <xil_printf.h>
#include <xtime_l.h>
#include <xil_io.h>
#include "vchess.h"

// #pragma GCC optimize ("O3")

#define DEPTH_MAX 5
#define LARGE_EVAL (1 << 15)

extern board_t game[GAME_MAX];
extern uint32_t game_move_index, game_moves;
extern uint32_t position;

static board_t root_node_boards[MAX_POSITIONS];
static uint32_t nodes_searched;
static board_t board_stack[DEPTH_MAX][MAX_POSITIONS];
static board_t *board_vert[DEPTH_MAX];

static void
nm_load_rep_table(board_t game[GAME_MAX], uint32_t game_moves, board_t *board_vert[DEPTH_MAX], uint32_t ply)
{
	int32_t i, entry, status;

	i = (int32_t)ply - 1;
	entry = 0;
	status = 0;
	while (i >= 0 && (status = board_vert[i]->half_move_clock > 0) != 0)
	{
		vchess_repdet_board(board_vert[i]->board);
		vchess_repdet_castle_mask(board_vert[i]->castle_mask);
		vchess_repdet_write(entry);
		--i;
		++entry;
	}
	if (status)
	{
		i = (int32_t)game_moves - 1;
		while (i >= 0 && game[i].half_move_clock > 0)
		{
			vchess_repdet_board(game[i].board);
			vchess_repdet_castle_mask(game[i].castle_mask);
			vchess_repdet_write(entry);
			--i;
			++entry;
		}
	}
	vchess_repdet_depth(entry);
}

static int32_t
nm_load_positions(board_t boards[MAX_POSITIONS])
{
	int32_t i;
	uint32_t moves_ready, status, move_count;

	vchess_status(0, &moves_ready, 0, 0, 0);
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
	if (move_count >= MAX_POSITIONS)
	{
		xil_printf("%s: stopping here, %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		while (1);
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

void
nm_sort(board_t **board_ptr, uint32_t move_count, uint32_t white_to_move)
{
	int i, j;
	board_t *tmp_board_ptr;

	if (white_to_move)
	{
		for (i = 0; i < move_count - 1; ++i)
			for (j = i + 1; j < move_count; ++j)
				if (board_ptr[i]->eval < board_ptr[j]->eval)
				{
					tmp_board_ptr = board_ptr[i];
					board_ptr[i] = board_ptr[j];
					board_ptr[j] = tmp_board_ptr;
				}
	}
	else
		for (i = 0; i < move_count - 1; ++i)
			for (j = i + 1; j < move_count; ++j)
				if (board_ptr[i]->eval > board_ptr[j]->eval)
				{
					tmp_board_ptr = board_ptr[i];
					board_ptr[i] = board_ptr[j];
					board_ptr[j] = tmp_board_ptr;
				}
}

static inline int32_t
valmax(int32_t a, int32_t b)
{
	if (a > b)
		return a;
	return b;
}

static int32_t
negamax(board_t *board, int32_t depth, int32_t alpha, int32_t beta, uint32_t ply)
{
	uint32_t move_count, index;
	int32_t value;
	uint32_t status;
	board_t *board_ptr[MAX_POSITIONS];

	++nodes_searched;
	nm_load_rep_table(game, game_moves, board_vert, ply);
	vchess_write_board(board);
	move_count = vchess_move_count();
	if (move_count >= 218)
	{
		int i;

		for (i = 0; i <= ply; ++i)
		{
			xil_printf("debug ply %d:\n", i);
			vchess_print_board(board_vert[i], 1);
			fen_print(board_vert[i]);
		}
		xil_printf("%s: stopping here, %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		while (1);
	}
	value = vchess_initial_eval();
	if (move_count == 0) // mate, stalemate, or thrice repetition
	{
		if (value < 0) // white mated
			value += DEPTH_MAX - depth; // fastest path to black win, slowest for white loss
		else if (value > 0) // black mated
			value -= DEPTH_MAX - depth; // fastest path to white win, slowest for black loss
		if (! board->white_to_move)
			value = -value;
		return value;
	}
	if (move_count >= MAX_POSITIONS)
	{
		xil_printf("%s: stopping here, move_count=%d, %s %d\n", __PRETTY_FUNCTION__, move_count, __FILE__, __LINE__);
		while (1);
	}
	if (depth == 0)
	{
		if (! board->white_to_move)
			value = -value;
		return value;
	}
	if (ply >= DEPTH_MAX)
	{
		xil_printf("%s: ply >= DEPTH_MAX\n", __PRETTY_FUNCTION__);
		return 0;
	}
	for (index = 0; index < move_count; ++index)
	{
		status = vchess_read_board(&board_stack[ply][index], index);
		if (status)
		{
			xil_printf("%s: problem reading boards (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
			return 0;
		}
		board_ptr[index] = &board_stack[ply][index];
	}
	nm_sort(board_ptr, move_count, board->white_to_move);

	value = -LARGE_EVAL;
	index = 0;
	++ply;
	do
	{
		board_vert[ply] = board_ptr[index];
		value = valmax(value, -negamax(board_ptr[index], depth - 1, -beta, -alpha, ply));
		alpha = valmax(alpha, value);
		++index;
	} while (index < move_count && alpha < beta);

	return value;
}

board_t
nm_top(board_t *board)
{
	int32_t i, status;
	uint32_t ply;
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
		vchess_status(0, &moves_ready, 0, 0, 0);
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
	ply = 0;
	best_evaluation = -LARGE_EVAL;
	for (i = 0; i < move_count; ++i)
	{
		board_vert[ply] = &root_node_boards[i];
		evaluate_move = -negamax(&root_node_boards[i], DEPTH_MAX - 1, -LARGE_EVAL, LARGE_EVAL, ply);
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
