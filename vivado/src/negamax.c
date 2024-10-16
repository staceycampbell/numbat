#include <stdio.h>
#include <stdint.h>
#include <xil_printf.h>
#include <xtime_l.h>
#include <xil_io.h>
#include "vchess.h"

#pragma GCC optimize ("O3")

#define DEPTH_MAX 6
#define Q_MAX (DEPTH_MAX + 25)  // when search reaches depth max switch to quiescence search
#define LARGE_EVAL (1 << 15)

#define GLOBAL_VALUE_KING 10000

static uint32_t nodes_visited, terminal_nodes, q_hard_cutoff, q_end, trans_lower, trans_upper, trans_exact, trans_save, trans_collision;
static board_t board_stack[Q_MAX][MAX_POSITIONS];
static board_t *board_vert[Q_MAX];

static int32_t
nm_eval(uint32_t wtm)
{
        int32_t value;

        value = vchess_initial_eval();
        if (!wtm)
                value = -value;

        return value;
}

static void
nm_load_rep_table(board_t game[GAME_MAX], uint32_t game_moves, board_t * board_vert[DEPTH_MAX], uint32_t ply)
{
        uint32_t entries;
        int32_t sel, index;
        uint32_t am_idle;

        vchess_status(0, 0, 0, 0, 0, &am_idle, 0);
        if (!am_idle)
        {
                xil_printf("%s: all moves state machine not idle, stopping (%s %d)\n", __PRETTY_FUNCTION__, __FILE__,
                           __LINE__);
                while (1);
        }
        if (game_moves == 0 || ply >= DEPTH_MAX)        // mate, stalemate or quiescence (only looking at captures)
        {
                vchess_repdet_write(0);
                return;
        }
        if (board_vert)         // if there's a search tree load half-moves in search tree
        {
                sel = ply;
                index = board_vert[ply]->half_move_clock;
                entries = board_vert[ply]->half_move_clock + 1;
                while (index >= 0 && sel >= 0)
                {
                        vchess_repdet_board(board_vert[sel]->board);
                        vchess_repdet_castle_mask(board_vert[sel]->castle_mask);
                        vchess_repdet_write(board_vert[sel]->half_move_clock);
                        --sel;
                        --index;
                }
        }
        // if there's no search tree, or if the search tree half-move move clock is non-zero at ply 0
        // then load game moves,
        if (!board_vert || index > 0)
        {
                sel = game_moves - 1;
                if (!board_vert)
                {
                        index = game[sel].half_move_clock;
                        entries = game[sel].half_move_clock + 1;
                }
                while (index >= 0)
                {
                        if (sel < 0)
                        {
                                xil_printf("%s: bad half_move_clock (%d), game_moves (%d), and/or ply (%d)\n",
                                           __PRETTY_FUNCTION__, board_vert[ply]->half_move_clock, game_moves, ply);
                                while (1);
                        }
                        vchess_repdet_board(game[sel].board);
                        vchess_repdet_castle_mask(game[sel].castle_mask);
                        vchess_repdet_write(game[sel].half_move_clock);
                        --sel;
                        --index;
                }
        }

        vchess_repdet_depth(entries);
}

static int32_t
nm_load_positions(board_t boards[MAX_POSITIONS])
{
        int32_t i;
        uint32_t moves_ready, status, move_count;

        vchess_status(0, &moves_ready, 0, 0, 0, 0, 0);
        if (!moves_ready)
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
                        xil_printf("%s: problem with vchess_read_board (%s %d)\n", __PRETTY_FUNCTION__, __FILE__,
                                   __LINE__);
                        return -3;
                }
        }
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

static int32_t
negamax(board_t game[GAME_MAX], uint32_t game_moves, board_t * board, int32_t depth, int32_t alpha, int32_t beta, uint32_t ply)
{
        uint32_t move_count, index;
        uint32_t mate, stalemate, thrice_rep, fifty_move;
        int32_t value;
	int32_t alpha_orig;
        uint32_t status, quiescence;
	uint32_t collision;
	trans_t trans;
        board_t *board_ptr[MAX_POSITIONS];

        ++nodes_visited;

	alpha_orig = alpha;

        vchess_reset_all_moves();
        nm_load_rep_table(game, game_moves, board_vert, ply);

        vchess_write_board_basic(board);

	// transposition table lookup
	trans_lookup(&trans, &collision);
	trans_collision += collision;
	if (trans.entry_valid && trans.depth >= depth)
	{
		if (trans.flag == TRANS_EXACT)
		{
			++trans_exact;
			return trans.eval;
		}
		else if (trans.flag == TRANS_LOWER_BOUND)
		{
			++trans_lower;
			alpha = valmax(alpha, trans.eval);
		}
		else if (trans.flag == TRANS_UPPER_BOUND)
		{
			++trans_upper;
			beta = valmin(beta, trans.eval);
		}
		if (alpha >= beta)
		{
			++trans_save;
			return trans.eval;
		}
	}

        vchess_write_board_wait(board);

        value = nm_eval(board->white_to_move);

        quiescence = depth <= 0;

        vchess_capture_moves(quiescence);
        move_count = vchess_move_count();
        if (move_count >= MAX_POSITIONS)
        {
                xil_printf("%s: stopping here, move_count=%d, quiescence=%d, %s %d\n", __PRETTY_FUNCTION__,
			   move_count, quiescence, __FILE__, __LINE__);
		fen_print(board);
                while (1);
        }

        if (quiescence)
        {
                if (value >= beta)
                        return beta;
                if (alpha < value)
                        alpha = value;
                if (move_count == 0)
                {
                        ++q_end;
                        return alpha;
                }
                if (ply == Q_MAX - 1)   // hard limit on quiescese search depth
                {
                        ++q_hard_cutoff;
                        return alpha;
                }
        }
        else if (move_count == 0)       // mate, stalemate, or thrice repetition
        {
                vchess_status(0, 0, &mate, &stalemate, &thrice_rep, 0, &fifty_move);
                if (stalemate || thrice_rep || fifty_move)
                        return 0;
                value = -GLOBAL_VALUE_KING + ply;       // add ply for shortest path to win, longest to loss
                ++terminal_nodes;
                return value;
        }
        for (index = 0; index < move_count; ++index)
        {
                status = vchess_read_board(&board_stack[ply][index], index);
                if (status)
                {
                        xil_printf("%s: problem reading boards (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                        while (1);
                }
                if (quiescence && !board_stack[ply][index].capture)
                {
                        xil_printf("%s: problem with capture and quiescense, stopping (%s %d)\n", __PRETTY_FUNCTION__,
                                   __FILE__, __LINE__);
                        while (1);
                }
                board_ptr[index] = &board_stack[ply][index];
        }

        value = -LARGE_EVAL;
        index = 0;
        ++ply;
        do
        {
                board_vert[ply] = board_ptr[index];
                value = valmax(value,
                               -negamax(game, game_moves, board_ptr[index], depth - 1, -beta, -alpha, ply));
                alpha = valmax(alpha, value);
                ++index;
        }
        while (index < move_count && alpha < beta);

	trans.eval = value;
	if (value <= alpha_orig)
		trans.flag = TRANS_UPPER_BOUND;
	else if (value >= beta)
		trans.flag = TRANS_LOWER_BOUND;
	else
		trans.flag = TRANS_EXACT;
	trans.depth = depth;
	trans.entry_valid = 1;
        vchess_write_board_basic(board);
	trans_store(&trans);

        return value;
}

board_t
nm_top(board_t game[GAME_MAX], uint32_t game_moves)
{
        int32_t i, status, game_index;
        uint32_t ply;
        uint32_t move_count;
        uint64_t elapsed_ticks;
        double elapsed_time, nps;
        int32_t evaluate_move, best_evaluation;
        board_t best_board = { 0 };
        XTime t_end, t_start;
        board_t root_node_boards[MAX_POSITIONS];
        board_t *board_ptr[MAX_POSITIONS];

        if (game_moves == 0)
        {
                xil_printf("%s: no moves in game (%s %d)!", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                return best_board;
        }
        XTime_GetTime(&t_start);
        game_index = game_moves - 1;
        best_board = game[game_index];
        nodes_visited = 0;
        terminal_nodes = 0;
        q_hard_cutoff = 0;
        q_end = 0;
	trans_lower = 0;
	trans_upper = 0;
	trans_exact = 0;
	trans_save = 0;
	trans_collision = 0;

        vchess_reset_all_moves();
        nm_load_rep_table(game, game_index, 0, 0);
        vchess_write_board_basic(&game[game_index]);
        vchess_write_board_wait(&game[game_index]);

        vchess_capture_moves(0);
        move_count = vchess_move_count();
        if (move_count == 0)
        {
                xil_printf("%s: game is over, no moves (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                return best_board;
        }

        status = nm_load_positions(root_node_boards);
        if (status != move_count)
        {
                xil_printf("%s: bad call to nm_load_positions (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                return best_board;
        }

        for (i = 0; i < move_count; ++i)
                board_ptr[i] = &root_node_boards[i];

        ply = 0;
        best_evaluation = -LARGE_EVAL;
        for (i = 0; i < move_count; ++i)
        {
                board_vert[ply] = board_ptr[i];
                evaluate_move =
                        -negamax(game, game_moves, board_ptr[i], DEPTH_MAX - 1, -LARGE_EVAL, LARGE_EVAL, ply);
                if (evaluate_move > best_evaluation)
                {
                        best_board = *board_ptr[i];
                        best_evaluation = evaluate_move;
                }
        }
        best_board.full_move_number = 1 + game_moves / 2;

        vchess_reset_all_moves();
        nm_load_rep_table(game, game_moves, 0, 0);
        vchess_write_board_basic(&best_board);
        vchess_write_board_wait(&best_board);
        vchess_capture_moves(0);
        move_count = vchess_move_count();

        XTime_GetTime(&t_end);
        elapsed_ticks = t_end - t_start;
        elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
        nps = (double)nodes_visited / elapsed_time;
        printf("\nbest_evaluation=%d, nodes_visited=%u, terminal_nodes=%u, seconds=%f, nps=%f, move_count=%u\n",
               best_evaluation, nodes_visited, terminal_nodes, elapsed_time, nps, move_count);
        printf("q_hard_cutoff=%u, q_end=%u\n", q_hard_cutoff, q_end);
	printf("trans_lower=%u, trans_upper=%u, trans_exact=%u, trans_save=%u, trans_collision=%u (%.2f%%)\n",
	       trans_lower, trans_upper, trans_exact, trans_save, trans_collision,
	       ((double)trans_collision * 100.0) / (double)nodes_visited);

        return best_board;
}
