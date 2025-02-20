// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <xtime_l.h>
#include "numbat.h"

#pragma GCC optimize ("O2")

#define FIXED_TIME 5
#define MID_GAME_HALF_MOVES 40

#define LBS_COUNT 3		// number of most recent best scores for one side
#define LBS_RESIGN -600		// if this is seen LBS_COUNT times return resign as true

#define LARGE_EVAL (1 << 20)

#define Q_DELTA 200		// stop q search if eval + this doesn't beat alpha

extern board_t game[GAME_MAX];
extern uint32_t game_moves;

static uint32_t nodes_visited, n_nodes_visited, q_nodes_visited, trans_collision, no_trans, q_no_trans, q_trans_hit;
static uint32_t q_trans_collision;
static board_t board_stack[MAX_DEPTH][MAX_POSITIONS];
static board_t *board_vert[MAX_DEPTH];
static int32_t q_ply_reached, valid_q_ply_reached;
static XTime time_limit;
static uint32_t ui_data_stop;
static uint32_t uci_data_stop;
static uint32_t abort_search;
static uci_t pv_array[PV_ARRAY_COUNT];
static const uci_t zero_move = { 0, 0, 0, 0, 0 };

static uint32_t abort_test_move_count;

static const uint32_t debug_pv_info = 0;

static tune_t tune;

static uint32_t
board_match(const board_t * a, const board_t * b)
{
	int32_t cmp;

	cmp = memcmp(a->board, b->board, 32);
	if (cmp != 0)
		return 0;

	return a->castle_mask == b->castle_mask;
}

static inline int32_t
next_full_move(void)
{
	return 1 + game_moves / 2;
}

static uint32_t
repeat_draw(uint32_t ply_count, const board_t * board)
{
	int32_t count, i;

	count = 0;
	i = (int32_t) ply_count - 1;
	if (board_vert[i]->half_move_clock < 2)
		return 0;
	while (i >= 0 && count < 2)
	{
		if (board_match(board_vert[i], board))
			++count;
		--i;
	}
	if (count == 2)
		return 1;
	i = game_moves - 1;
	while (i >= 0 && count < 2)
	{
		if (board_match(&game[i], board))
			++count;
		--i;
	}

	return count == 2;
}

static inline int32_t
eval_side(int32_t value, uint32_t wtm, uint32_t ply)
{
	if (!wtm)
		value = -value;
	if (value == GLOBAL_VALUE_KING)
		value = GLOBAL_VALUE_KING - ply;
	else if (value == -GLOBAL_VALUE_KING)
		value = -GLOBAL_VALUE_KING + ply;
	return value;
}

static int32_t
nm_initial_eval(uint32_t wtm, uint32_t ply)
{
	int32_t value;
	uint32_t stalemate, fifty_move;

	numbat_status(0, 0, 0, &stalemate, 0, &fifty_move, 0, 0);
	if (stalemate || fifty_move)
		return 0;

	value = numbat_initial_eval();
	value = eval_side(value, wtm, ply);

	return value;
}

static void
abort_test(void)
{
	XTime t_now;
	uint32_t time_limit_exceeded;

	++abort_test_move_count;
	if (abort_test_move_count < 1000)
		return;

	abort_test_move_count = 0;
	XTime_GetTime(&t_now);
	time_limit_exceeded = t_now > time_limit;
	ui_data_stop = ui_data_available();
	uci_data_stop = uci_input_poll() == UCI_SEARCH_STOP;
	abort_search = time_limit_exceeded || ui_data_stop || uci_data_stop;
}

uint32_t
load_root_nodes(board_t boards[MAX_POSITIONS])
{
	int32_t i;
	uint32_t moves_ready, move_count;

	numbat_status(0, &moves_ready, 0, 0, 0, 0, 0, 0);
	if (!moves_ready)
	{
		printf("%s: moves_ready not set (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return 0;
	}
	move_count = numbat_move_count();
	if (move_count == 0)
	{
		printf("%s: no moves available (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return 0;
	}
	for (i = 0; i < move_count; ++i)
		numbat_read_board(&boards[i], i);

	return move_count;
}

static inline int32_t
valmax(int32_t a, int32_t b)
{
	if (a > b)
		return a;
	return b;
}

static inline int32_t
valmin(int32_t a, int32_t b)
{
	if (a < b)
		return a;
	return b;
}

static void
local_movcpy(uci_t * p_dst, const uci_t * p_src, int32_t n)
{
	uint32_t src_nonzero;
	// while (n-- && (*pTarget++ = *pSource++));
	if (n > 0)
		do
		{
			src_nonzero = uci_nonzero(p_src);
			*p_dst++ = *p_src++;
			n--;
		}
		while (n && src_nonzero);
}

static int32_t
quiescence(const board_t * board, int32_t alpha, int32_t beta, uint32_t ply, int32_t pv_index)
{
	uint32_t move_count, index;
	uint32_t mate, stalemate, fifty_move;
	int32_t value;
	board_t *board_ptr[MAX_POSITIONS];
	int32_t pv_next_index;
	uint32_t collision;
	trans_t trans;
	int32_t alpha_orig;
	int32_t board_eval, initial_eval, initial_delta;
	uint32_t in_check;

	++nodes_visited;
	++q_nodes_visited;

	if (ply >= MAX_DEPTH - 1)
		return beta;

	alpha_orig = alpha;

	pv_array[pv_index] = zero_move;
	pv_next_index = pv_index + MAX_DEPTH - ply;

	numbat_reset_all_moves();
	numbat_write_board_basic(board);
	q_trans_lookup_init();	// trigger transposition table lookup

	numbat_write_board_wait(board);
	numbat_status(0, 0, &mate, &stalemate, 0, &fifty_move, 0, 0);
	in_check = board->white_in_check || board->black_in_check;
	if (repeat_draw(ply, board) && !in_check)
		return 0;	// draw score

	value = nm_initial_eval(board->white_to_move, ply);
	initial_eval = value;
	move_count = numbat_move_count();
	if (move_count == 0)
		return value;

	q_trans_test_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
	numbat_q_trans_read(&collision, &trans.eval, &trans.depth, &trans.flag, &trans.nodes, &trans.entry_valid);
	q_trans_collision += collision;

	if (trans.entry_valid)
	{
		++q_trans_hit;
		if (trans.flag == TRANS_EXACT)
			return trans.eval;
		else if (trans.flag == TRANS_LOWER_BOUND)
			alpha = valmax(alpha, trans.eval);
		else if (trans.flag == TRANS_UPPER_BOUND)
			beta = valmin(beta, trans.eval);
		if (alpha >= beta)
			return trans.eval;
	}
	else
		++q_no_trans;

	if (value >= beta)
		return value;

	if (value > alpha)
	{
		alpha = value;
		pv_array[pv_index] = board->uci;
		local_movcpy(pv_array + pv_index + 1, pv_array + pv_next_index, MAX_DEPTH - ply - 1);
	}
	else if (value + tune.q_delta < alpha && !in_check)
		return alpha;

	abort_test();
	if (abort_search)
		return 0;	// will be ignored

	if (ply > q_ply_reached)
		q_ply_reached = ply;

	board_ptr[0] = 0;	// stop gcc -Wuninitialized, move count is always > 0 here
	for (index = 0; index < move_count; ++index)
	{
		numbat_read_board(&board_stack[ply][index], index);
		board_ptr[index] = &board_stack[ply][index];
	}

	numbat_reset_all_moves();

	index = 0;
	do
	{
		board_vert[ply] = board_ptr[index];
		if (board_ptr[index]->fifty_move)
			board_eval = 0;
		else
			board_eval = eval_side(board_ptr[index]->eval, board->white_to_move, ply);
		initial_delta = abs(initial_eval - board_eval);

		if (board_ptr[index]->capture || initial_delta >= tune.q_enter_1 || board_ptr[index]->white_in_check
		    || board_ptr[index]->black_in_check || in_check)
			value = -quiescence(board_ptr[index], -beta, -alpha, ply + 1, pv_next_index);
		else
			value = board_eval;
		if (abort_search)
			return 0;
		if (value > alpha)
			alpha = value;
		++index;
	}
	while (!abort_search && index < move_count && alpha < beta);

	if (abort_search)
		return 0;	// will be ignored

	numbat_write_board_basic(board);
	trans.eval = alpha;
	if (alpha <= alpha_orig)
		trans.flag = TRANS_UPPER_BOUND;
	else if (value >= beta)
		trans.flag = TRANS_LOWER_BOUND;
	else
		trans.flag = TRANS_EXACT;
	trans.entry_valid = 1;
	q_trans_store(&trans);

	return alpha;
}

static int32_t
negamax(const board_t * board, int32_t depth, int32_t alpha, int32_t beta, uint32_t ply, int32_t pv_index)
{
	uint32_t move_count, index;
	uint32_t in_check;
	int32_t value, board_eval;
	int32_t alpha_orig;
	uint32_t collision;
	trans_t trans;
	board_t *board_ptr[MAX_POSITIONS];
	uint64_t node_start, node_stop, nodes;
	int32_t pv_next_index = 0;
	int32_t initial_eval, initial_delta;

	if (ply >= MAX_DEPTH - 1)
	{
		printf("%s: increase MAX_DEPTH, stopping (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		while (1);
	}

	numbat_led(ply);

	node_start = n_nodes_visited;
	++nodes_visited;
	++n_nodes_visited;

	// mate distance pruning
	alpha = valmax(alpha, -GLOBAL_VALUE_KING + ply);
	beta = valmin(beta, GLOBAL_VALUE_KING - ply);
	if (alpha >= beta)
		return alpha;

	pv_array[pv_index] = zero_move;
	pv_next_index = pv_index + MAX_DEPTH - ply;

	alpha_orig = alpha;

	numbat_reset_all_moves();
	killer_ply(ply);
	numbat_write_board_basic(board);
	trans_lookup_init();	// trigger transposition table lookup

	numbat_write_board_wait(board);

	value = nm_initial_eval(board->white_to_move, ply);
	initial_eval = value;
	move_count = numbat_move_count();
	if (move_count == 0)
		return value;

	in_check = board->white_in_check || board->black_in_check;
	if (repeat_draw(ply, board) && !in_check)
		return 0;	// draw score

	trans_wait_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
	numbat_trans_read(&collision, &trans.eval, &trans.depth, &trans.flag, &trans.nodes, &trans.entry_valid);
	trans_collision += collision;

	if (trans.entry_valid && trans.depth >= depth)
	{
		if (trans.flag == TRANS_EXACT)
			return trans.eval;
		else if (trans.flag == TRANS_LOWER_BOUND)
			alpha = valmax(alpha, trans.eval);
		else if (trans.flag == TRANS_UPPER_BOUND)
			beta = valmin(beta, trans.eval);
		if (alpha >= beta)
			return trans.eval;
	}
	else
		++no_trans;

	abort_test();
	if (abort_search)
		return 0;	// will be ignored

	board_ptr[0] = 0;	// stop gcc -Wuninitialized, move count is always > 0 here
	for (index = 0; index < move_count; ++index)
	{
		numbat_read_board(&board_stack[ply][index], index);
		board_ptr[index] = &board_stack[ply][index];
	}

	numbat_reset_all_moves();

	index = 0;
	do
	{
		board_vert[ply] = board_ptr[index];
		if (board_ptr[index]->fifty_move)
			board_eval = 0;
		else
			board_eval = eval_side(board_ptr[index]->eval, board->white_to_move, ply);

		initial_delta = abs(initial_eval - board_eval);
		if (depth <= 0 && (in_check || board_ptr[index]->capture || board_ptr[index]->white_in_check || board_ptr[index]->black_in_check ||
				   initial_delta >= tune.q_enter_0))
			value = -quiescence(board_ptr[index], -beta, -alpha, ply + 1, pv_next_index);
		else if (depth == 0)
			value = board_eval;
		else
			value = -negamax(board_ptr[index], depth - 1, -beta, -alpha, ply + 1, pv_next_index);
		if (abort_search)
			return 0;	// will be ignored
		if (value > alpha && value < beta)
		{
			pv_array[pv_index] = board_ptr[index]->uci;
			local_movcpy(pv_array + pv_index + 1, pv_array + pv_next_index, MAX_DEPTH - ply - 1);
		}
		if (value > alpha)
			alpha = value;

		++index;
	}
	while (!abort_search && index < move_count && alpha < beta);

	if (abort_search)
		return 0;	// will be ignored

	if (ply > 1 && index < move_count && !board_ptr[index - 1]->capture)	// beta cutoff
	{
		killer_ply(ply);
		killer_write_board(board_ptr[index - 1]->board);
		killer_update_table();
	}

	node_stop = n_nodes_visited;
	nodes = node_stop - node_start;
	if (nodes >= (1 << TRANS_NODES_WIDTH))
		nodes = (1 << TRANS_NODES_WIDTH) - 1;
	numbat_write_board_basic(board);
	trans_lookup(&trans, &collision);
	if (!trans.entry_valid || trans.nodes < nodes)
	{
		trans.eval = alpha;
		if (alpha <= alpha_orig)
			trans.flag = TRANS_UPPER_BOUND;
		else if (value >= beta)
			trans.flag = TRANS_LOWER_BOUND;
		else
			trans.flag = TRANS_EXACT;
		trans.nodes = nodes;
		trans.depth = depth;
		trans.entry_valid = 1;
		trans_store(&trans);
	}

	return alpha;
}

static int32_t
nm_move_sort_compare(const void *p1, const void *p2)
{
	const board_t **b1, **b2;

	b1 = (const board_t **)p1;
	b2 = (const board_t **)p2;

	if ((*b1)->eval > (*b2)->eval)
		return -1;
	if ((*b1)->eval < (*b2)->eval)
		return 1;

	return 0;
}

void
nm_tune(const tune_t * new_tune)
{
	tune = *new_tune;
}

tune_t
nm_current_tune(void)
{
	return tune;
}

void
nm_init(void)
{
	tune.q_enter_0 = 50;
	tune.q_enter_1 = 50;
	tune.algorithm_enable = 0;
	tune.q_delta = Q_DELTA;
	tune.initial_depth_limit = 1;
	tune.depth_duration = 0;
}

board_t
nm_top(const tc_t * tc, uint32_t * resign, uint32_t opponent_time, uint32_t quiet)
{
	int32_t i, game_index;
	int32_t alpha, beta;
	int32_t depth_limit;
	uint32_t move_count;
	uint32_t wtm;
	uint64_t elapsed_ticks;
	int64_t duration_seconds;
	double elapsed_time, nps;
	int32_t evaluate_move, best_evaluation, overall_best, trans_hit;
	board_t best_board = { 0 };
	board_t best_complete_board = { 0 };
	XTime t_end, t_report, t_start;
	XTime depth_start, depth_end;
	double depth_duration;
	board_t root_node_boards[MAX_POSITIONS];
	board_t *board_ptr[MAX_POSITIONS];
	char uci_str[6];
	static int32_t last_best_score[2][LBS_COUNT];

	if (game_moves == 0)
	{
		printf("%s: no moves in game (%s %d)!", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return best_board;
	}

	XTime_GetTime(&t_start);

	game_index = game_moves - 1;
	best_board = game[game_index];
	wtm = best_board.white_to_move;
	if (resign)
		*resign = 0;
	numbat_algorithm_enable(tune.algorithm_enable);

	nodes_visited = 0;
	q_nodes_visited = 0;
	q_trans_hit = 0;
	n_nodes_visited = 0;
	no_trans = 0;
	trans_collision = 0;
	q_trans_collision = 0;
	q_no_trans = 0;

	numbat_reset_all_moves();
	numbat_castle_mask_orig(game[game_index].castle_mask);	// pre-search castle state
	numbat_write_board_basic(&game[game_index]);
	numbat_write_board_wait(&game[game_index]);
	move_count = numbat_move_count();
	if (move_count == 0)
	{
		printf("%s: game is over, no moves (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return best_board;
	}

	if (!quiet)
	{
		tc_display(tc);
		printf(" - %s to move - ", best_board.white_to_move ? "white" : "black");
	}

	load_root_nodes(root_node_boards);
	best_board = root_node_boards[0];
	best_complete_board = best_board;
	if (move_count == 1)
	{
		if (!quiet)
			printf("one move possible\n");
		best_board.full_move_number = next_full_move();
		return best_board;
	}

	numbat_reset_all_moves();

	for (i = 0; i < move_count; ++i)
		board_ptr[i] = &root_node_boards[i];

	if (!tc->valid)
	{
		duration_seconds = UINT64_C(FIXED_TIME);
	}
	else if (tc->fixed)
	{
		duration_seconds = tc->fixed;
	}
	else
	{
		duration_seconds = (double)(tc->main_remaining[tc->side] / (double)MID_GAME_HALF_MOVES) + 0.5;
		duration_seconds += (double)tc->increment * 0.8 + 0.5;
		if (duration_seconds * 10 > tc->main_remaining[tc->side])
			duration_seconds = tc->main_remaining[tc->side] / 7;
		if (duration_seconds <= 0)
			duration_seconds = 1;
		else if (duration_seconds > 60 && !opponent_time)	// deal with "moretime" people on FICS
			duration_seconds = 60;
	}
	if (!quiet)
		printf("pondering %d moves for %d seconds\n", move_count, (int32_t) duration_seconds);
	time_limit = t_start + duration_seconds * UINT64_C(COUNTS_PER_SECOND);

	abort_search = 0;
	ui_data_stop = 0;
	uci_data_stop = 0;
	abort_test_move_count = 0;
	q_ply_reached = 0;
	valid_q_ply_reached = 0;
	alpha = -LARGE_EVAL;
	beta = LARGE_EVAL;
	overall_best = -LARGE_EVAL;
	best_evaluation = -LARGE_EVAL;
	depth_limit = tune.initial_depth_limit;
	depth_start = 0;
	depth_end = 0;
	while (depth_limit < MAX_DEPTH - 1 && !abort_search)
	{
		i = 0;
		best_evaluation = -LARGE_EVAL;
		XTime_GetTime(&depth_start);
		if (!quiet)
			printf("dl=%d ", depth_limit);
		while (i < move_count && !abort_search)
		{
			board_vert[0] = board_ptr[i];
			uci_string(&board_ptr[i]->uci, uci_str);
			evaluate_move = -negamax(board_ptr[i], depth_limit, alpha, beta, 0, 0);
			board_ptr[i]->eval = evaluate_move;	// sort key for iterative deepening depth-first search
			if (!abort_search && evaluate_move > best_evaluation)
			{
				best_board = *board_ptr[i];
				best_evaluation = evaluate_move;
				overall_best = evaluate_move;
				if (!quiet)
				{
					uci_string(&best_board.uci, uci_str);
					if (!opponent_time)
						printf("%s", ansi_bold);
					printf("be=%d (%s) ", best_evaluation, uci_str);
					if (!opponent_time)
						printf("%s", ansi_sgr0);
					fflush(stdout);
				}
			}
			++i;
		}
		XTime_GetTime(&depth_end);
		if (!quiet)
			printf("\n");
		if (debug_pv_info)
		{
			best_board.full_move_number = next_full_move();
			XTime_GetTime(&t_report);
			elapsed_ticks = t_report - t_start;
			elapsed_time = (double)elapsed_ticks / ((double)COUNTS_PER_SECOND / 1000.0);
			nps = (double)nodes_visited / ((double)elapsed_ticks / (double)COUNTS_PER_SECOND);
			if (!quiet)
			{
				uci_currmove(depth_limit, q_ply_reached, &board_ptr[0]->uci, best_board.full_move_number, best_evaluation);
				uci_pv(depth_limit, best_evaluation, (uint32_t) elapsed_time, nodes_visited, (uint32_t) nps, &board_ptr[0]->uci,
				       pv_array);
			}
		}
		if (!abort_search)
		{
			best_complete_board = best_board;
			qsort(board_ptr, move_count, sizeof(board_t *), nm_move_sort_compare);
			pv_load_table(pv_array);
			++depth_limit;
		}
		if (q_ply_reached > valid_q_ply_reached)
			valid_q_ply_reached = q_ply_reached;
	}
	depth_duration = (double)(depth_end - depth_start) / (double)COUNTS_PER_SECOND;
	if (depth_duration < tune.depth_duration)
		best_board = best_complete_board;
	best_board.full_move_number = next_full_move();

	last_best_score[wtm][(game_index / 2) % LBS_COUNT] = overall_best;
	if (resign && game_index >= LBS_COUNT)
	{
		i = 0;
		while (i < LBS_COUNT && last_best_score[wtm][i] <= LBS_RESIGN)
			++i;
		*resign = i == LBS_COUNT;
	}

	XTime_GetTime(&t_end);
	elapsed_ticks = t_end - t_start;
	elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
	nps = (double)nodes_visited / elapsed_time;
	trans_hit = nodes_visited - no_trans;

	if (!quiet)
	{
		uci_currmove(depth_limit, valid_q_ply_reached, &best_board.uci, best_board.full_move_number, overall_best);
		uci_pv(depth_limit, overall_best, (uint32_t) elapsed_time * 1000.0, nodes_visited, (uint32_t) nps, &best_board.uci, pv_array);
	}

	if (!quiet)
	{
		printf("%sbest_evaluation=%s%d%s, %snps=%.0f%s, nodes_visited=%u, seconds=%.2f\n",
		       opponent_time ? "" : ansi_bold,
		       opponent_time ? "" : overall_best < 0 ? ansi_red : overall_best > 0 ? ansi_green : "",
		       overall_best, ansi_sgr0, opponent_time ? "" : ansi_bold, nps, ansi_sgr0, nodes_visited, elapsed_time);
		if (1)
		{
			printf("depth_limit=%d, q_depth=%d\n", depth_limit, valid_q_ply_reached);
			printf("no_trans=%u, trans_hit=%d (%.2f%%), trans_collision=%u (%.2f%%)\n", no_trans,
			       trans_hit, ((double)trans_hit * 100.0) / (double)nodes_visited, trans_collision,
			       ((double)trans_collision * 100.0) / (double)nodes_visited);
			if (q_nodes_visited > 0)
				printf("q_no_trans=%u, q_trans_hit=%u (%.2f%%), q_trans_collision=%u (%.2f%%)\n", q_no_trans, q_trans_hit,
				       ((double)q_trans_hit * 100.0) / (double)(q_nodes_visited),
				       q_trans_collision, ((double)q_trans_collision * 100.0) / (double)q_nodes_visited);
		}
		printf("temps: %s%.2fC%s (max %s%.2fC%s min %s%.2fC%s)\n",
		       ansi_bold, tmon_temperature, ansi_sgr0,
		       ansi_red, tmon_max_temperature, ansi_sgr0, ansi_green, tmon_min_temperature, ansi_sgr0);
	}

	numbat_led(0);

	return best_board;
}
