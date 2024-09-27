#include <stdio.h>
#include <stdint.h>
#include <xil_printf.h>
#include <xtime_l.h>
#include <xil_io.h>
#include "vchess.h"

// #pragma GCC optimize ("O3")

#define DEPTH_MAX 5
#define LARGE_EVAL (1 << 15)

static uint32_t nodes_visited, leaf_nodes;
static board_t board_stack[DEPTH_MAX][MAX_POSITIONS];
static board_t *board_vert[DEPTH_MAX];

static void
nm_load_rep_table(board_t game[GAME_MAX], uint32_t game_moves, board_t * board_vert[DEPTH_MAX], uint32_t ply)
{
        uint32_t entries;
        int32_t sel, index;
	uint32_t am_idle;

	vchess_status(0, 0, 0, 0, 0, &am_idle);
	if (! am_idle)
	{
		xil_printf("%s: all moves state machine not idle, stopping (%s %d)\n", __PRETTY_FUNCTION__,
				__FILE__, __LINE__);
		while (1);
	}
        if (board_vert) // if there's a search tree load half-moves in search tree
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
        if (index > 0 || !board_vert)
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

        vchess_status(0, &moves_ready, 0, 0, 0, 0);
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
                        xil_printf("%s: problem with vchess_read_board (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                        return -3;
                }
        }
        return move_count;
}

void
nm_sort(board_t ** board_ptr, uint32_t move_count, uint32_t white_to_move)
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
negamax(board_t game[GAME_MAX], uint32_t game_moves, board_t * board, int32_t depth, int32_t alpha, int32_t beta, uint32_t ply)
{
        uint32_t move_count, index;
        int32_t value;
        uint32_t status;
        board_t *board_ptr[MAX_POSITIONS];

        ++nodes_visited;

	vchess_reset_all_moves();
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
        if (move_count == 0)    // mate, stalemate, or thrice repetition
        {
		++leaf_nodes;
                if (value < 0)  // white mated
                        value += DEPTH_MAX - depth;     // fastest path to black win, slowest for white loss
                else if (value > 0)     // black mated
                        value -= DEPTH_MAX - depth;     // fastest path to white win, slowest for black loss
                if (!board->white_to_move)
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
                if (!board->white_to_move)
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
                value = valmax(value, -negamax(game, game_moves, board_ptr[index], depth - 1, -beta, -alpha, ply));
                alpha = valmax(alpha, value);
                ++index;
        }
        while (index < move_count && alpha < beta);

        return value;
}

board_t
nm_top(board_t game[GAME_MAX], uint32_t game_moves)
{
        int32_t i, status, game_index;
        uint32_t ply;
        uint32_t  move_count, elapsed_ticks;
        double elapsed_time, nps;
        int32_t evaluate_move, best_evaluation;
        board_t best_board = { 0 };
        XTime t_end, t_start;
        board_t root_node_boards[MAX_POSITIONS];

        if (game_moves == 0)
        {
                xil_printf("%s: no moves in game (%s %d)!", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                return best_board;
        }
        XTime_GetTime(&t_start);
        game_index = game_moves - 1;
	best_board = game[game_index];
        nodes_visited = 0;
	leaf_nodes = 0;

	vchess_reset_all_moves();
	nm_load_rep_table(game, game_index, 0, 0);
        vchess_write_board(&game[game_index]);

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
        ply = 0;
        best_evaluation = -LARGE_EVAL;
        for (i = 0; i < move_count; ++i)
        {
                board_vert[ply] = &root_node_boards[i];
                evaluate_move = -negamax(game, game_moves, &root_node_boards[i], DEPTH_MAX - 1, -LARGE_EVAL, LARGE_EVAL, ply);
                if (evaluate_move > best_evaluation)
                {
                        best_evaluation = evaluate_move;
                        best_board = root_node_boards[i];
                }
        }
	best_board.full_move_number = 1 + game_index / 2;

        XTime_GetTime(&t_end);
        elapsed_ticks = t_end - t_start;
        elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
        if (elapsed_time == 0.0)        // hmm
                elapsed_time = 1.0;
        nps = (double)nodes_visited *(1.0 / elapsed_time);
        printf("best_evaluation=%d, nodes_visited=%u, leaf_nodes=%u, seconds=%f, nps=%f\n",
	       best_evaluation, nodes_visited, leaf_nodes, elapsed_time, nps);

        return best_board;
}
