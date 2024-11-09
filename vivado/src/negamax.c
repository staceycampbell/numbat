#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <xil_printf.h>
#include <xtime_l.h>
#include <xil_io.h>
#include "vchess.h"

#pragma GCC optimize ("O2")

#define FIXED_TIME 30
#define MID_GAME_HALF_MOVES 50

#define MAX_DEPTH 30
#define LARGE_EVAL (1 << 20)

static uint32_t nodes_visited, terminal_nodes, q_hard_cutoff, q_end, trans_collision, no_trans;
static board_t board_stack[MAX_DEPTH][MAX_POSITIONS];
static board_t *board_vert[MAX_DEPTH];
static int32_t depth_limit;
static int32_t quiescence_ply_reached, valid_quiescence_ply_reached;
static XTime time_limit;
static uint32_t time_limit_exceeded;
static uint32_t ui_data_stop;

static int32_t
nm_eval(uint32_t wtm, uint32_t ply)
{
        int32_t value;

        value = vchess_initial_eval();
        if (!wtm)
                value = -value;
        if (value == GLOBAL_VALUE_KING)
                value -= ply;
        else if (value == -GLOBAL_VALUE_KING)
                value += ply;

        return value;
}

static void
nm_load_rep_table(board_t game[GAME_MAX], uint32_t game_moves, board_t * board_vert[MAX_DEPTH], uint32_t ply, uint32_t quiescence)
{
        uint32_t entries;
        int32_t sel, index;
        uint32_t am_idle;

        vchess_status(0, 0, 0, 0, 0, &am_idle, 0, 0, 0);
        if (!am_idle)
        {
                xil_printf("%s: all moves state machine not idle, stopping (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                while (1);
        }
        if (game_moves == 0 || quiescence)      // mate, stalemate or quiescence (only looking at captures)
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
        uint32_t moves_ready, move_count;

        vchess_status(0, &moves_ready, 0, 0, 0, 0, 0, 0, 0);
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
        for (i = 0; i < move_count; ++i)
                vchess_read_board(&boards[i], i);
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
        uint32_t mate, stalemate, thrice_rep, fifty_move, insufficient, check;
        int32_t value;
        int32_t alpha_orig;
        uint32_t quiescence;
        uint32_t collision;
        trans_t trans;
        XTime t_now;
        board_t *board_ptr[MAX_POSITIONS];

        ++nodes_visited;

        alpha_orig = alpha;
        quiescence = depth <= 0;

        vchess_reset_all_moves();
        nm_load_rep_table(game, game_moves, board_vert, ply, quiescence);
        vchess_write_board_basic(board);
        vchess_capture_moves(quiescence);
        vchess_write_board_wait(board);
        vchess_status(0, 0, &mate, &stalemate, &thrice_rep, 0, &fifty_move, &insufficient, &check);

        quiescence = quiescence || check;

        value = nm_eval(board->white_to_move, ply);

        move_count = vchess_move_count();
        if (move_count >= MAX_POSITIONS)
        {
                xil_printf("%s: stopping here, move_count=%d, quiescence=%d, %s %d\n", __PRETTY_FUNCTION__,
                           move_count, quiescence, __FILE__, __LINE__);
                fen_print(board);
                while (1);
        }
        if (!quiescence && move_count == 0)
        {
                ++terminal_nodes;
                if (stalemate || thrice_rep || fifty_move || insufficient)
                        return 0;
                return value;
        }

        // mate distance pruning
        alpha = valmax(alpha, -GLOBAL_VALUE_KING + ply - 1);
        beta = valmin(beta, GLOBAL_VALUE_KING - ply);
        if (alpha >= beta)
                return alpha;

        trans_lookup(&trans, &collision);
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
        ++no_trans;

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
                if (ply > quiescence_ply_reached)
                        quiescence_ply_reached = ply;
                if (ply == MAX_DEPTH - 1)
                {
                        ++q_hard_cutoff;
                        return alpha;
                }
        }

        XTime_GetTime(&t_now);
        time_limit_exceeded = t_now > time_limit;
        ui_data_stop = ui_data_available();
        if (time_limit_exceeded || ui_data_stop)
                return value;

        for (index = 0; index < move_count; ++index)
        {
                vchess_read_board(&board_stack[ply][index], index);
                board_ptr[index] = &board_stack[ply][index];
        }

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

        if (value != 0)         // keep draws out of transposition table for now
        {
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
        }

        return value;
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

board_t
nm_top(board_t game[GAME_MAX], uint32_t game_moves, const tc_t * tc)
{
        int32_t i, game_index;
        uint32_t ply;
        uint32_t move_count;
        uint64_t elapsed_ticks;
        int64_t duration_seconds;
        double elapsed_time, nps;
        int32_t evaluate_move, best_evaluation, overall_best, trans_hit;
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
        no_trans = 0;
        trans_collision = 0;

        trans_clear_table();    // for easier debug

        vchess_reset_all_moves();
        nm_load_rep_table(game, game_index, 0, 0, 0);
        vchess_write_board_basic(&game[game_index]);
        vchess_write_board_wait(&game[game_index]);
        vchess_capture_moves(0);
        move_count = vchess_move_count();
        if (move_count == 0)
        {
                xil_printf("%s: game is over, no moves (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                return best_board;
        }

        tc_display(tc);
        printf(" - %s to move - ", best_board.white_to_move ? "white" : "black");

        nm_load_positions(root_node_boards);
        best_board = root_node_boards[0];
        if (move_count == 1)
        {
                printf("one move possible\n");
                return best_board;
        }

        for (i = 0; i < move_count; ++i)
                board_ptr[i] = &root_node_boards[i];

        if (!tc->valid)
                duration_seconds = UINT64_C(FIXED_TIME);
        else
        {
                duration_seconds = (double)(tc->main_remaining[tc->side] / (double)MID_GAME_HALF_MOVES / 25.0) * (double)move_count + 0.5;
                duration_seconds += (double)tc->increment * 2.0 / 3.0 + 0.5;
                if (duration_seconds * 5 > tc->main_remaining[tc->side])
                        duration_seconds /= 8;
                if (duration_seconds <= 0)
                        duration_seconds = 1;
        }
        printf("pondering %d moves for %d seconds\n", move_count, (int32_t) duration_seconds);
        time_limit = t_start + duration_seconds * UINT64_C(COUNTS_PER_SECOND);
        time_limit_exceeded = 0;
        ui_data_stop = 0;

        quiescence_ply_reached = 0;
        valid_quiescence_ply_reached = 0;

        overall_best = -LARGE_EVAL;
        depth_limit = 2;        // top nodes already sorted in all_moves.sv
        while (depth_limit < MAX_DEPTH - 1 && !time_limit_exceeded && !ui_data_stop)
        {
                ply = 0;
                i = 0;
                best_evaluation = -LARGE_EVAL;
                while (i < move_count && !time_limit_exceeded && !ui_data_stop)
                {
                        board_vert[ply] = board_ptr[i];
                        evaluate_move = -negamax(game, game_moves, board_ptr[i], depth_limit, -LARGE_EVAL, LARGE_EVAL, ply);
                        board_ptr[i]->eval = evaluate_move;     // sort key for iterative deepening depth-first search
                        if (!time_limit_exceeded && !ui_data_stop && evaluate_move > best_evaluation)
                        {
                                best_board = *board_ptr[i];
                                best_evaluation = evaluate_move;
                                overall_best = evaluate_move;
                        }
                        ++i;
                }
                if (!time_limit_exceeded && !ui_data_stop)
                {
                        qsort(board_ptr, move_count, sizeof(board_t *), nm_move_sort_compare);
                        ++depth_limit;
                        if (quiescence_ply_reached > valid_quiescence_ply_reached)
                                valid_quiescence_ply_reached = quiescence_ply_reached;
                }

        }
        best_board.full_move_number = 1 + game_moves / 2;

        XTime_GetTime(&t_end);
        elapsed_ticks = t_end - t_start;
        elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
        nps = (double)nodes_visited / elapsed_time;
        trans_hit = nodes_visited - no_trans;

        printf("best_evaluation=%d, nodes_visited=%u, terminal_nodes=%u, seconds=%.2f, nps=%.0f\n",
               overall_best, nodes_visited, terminal_nodes, elapsed_time, nps);
        printf("depth_limit=%d, q_hard_cutoff=%u, q_end=%u, q_depth=%d\n", depth_limit, q_hard_cutoff, q_end, valid_quiescence_ply_reached);
        printf("no_trans=%u, trans_hit=%d (%.2f%%), trans_collision=%u (%.2f%%)\n", no_trans,
               trans_hit, ((double)trans_hit * 100.0) / (double)nodes_visited, trans_collision,
               ((double)trans_collision * 100.0) / (double)nodes_visited);

        return best_board;
}
