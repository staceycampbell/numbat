#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <xil_printf.h>
#include <xtime_l.h>
#include <xil_io.h>
#include "vchess.h"

#pragma GCC optimize ("O2")

#define FIXED_TIME 60
#define MID_GAME_HALF_MOVES 40

#define LARGE_EVAL (1 << 20)

#define Q_DELTA 200             // stop q search if eval + this doesn't beat alpha

extern board_t game[GAME_MAX];
extern uint32_t game_moves;

static uint32_t repdet_game_moves;

static uint64_t all_moves_ticks;
static uint64_t q_ticks;
static uint32_t nodes_visited, trans_collision, no_trans, mate_distance_pruning;
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

static const uint32_t debug_pv_info = 1;

static int32_t
nm_initial_eval(uint32_t wtm, uint32_t ply)
{
        int32_t value;
        uint32_t thrice_rep, stalemate, fifty_move;

        vchess_status(0, 0, 0, &stalemate, &thrice_rep, 0, &fifty_move, 0, 0);
        if (stalemate || fifty_move || thrice_rep)
                return 0;

        value = vchess_initial_eval();
        if (value == GLOBAL_VALUE_KING)
                value -= ply;
        else if (value == -GLOBAL_VALUE_KING)
                value += ply;
        if (!wtm)
                value = -value;

        return value;
}

static inline void
rep_table_idle_test(const char *func, const char *file, uint32_t line)
{
        uint32_t am_idle;

        vchess_status(0, 0, 0, 0, 0, &am_idle, 0, 0, 0);
        if (!am_idle)
        {
                xil_printf("%s: all moves state machine not idle, stopping (%s %d)\n", func, file, line);
                while (1);
        }
}

static void
rep_table_entry(const uint32_t board[8], uint32_t castle_mask, uint32_t addr)
{
        vchess_repdet_board(board);
        vchess_repdet_castle_mask(castle_mask);
        vchess_repdet_write(addr);
}

static void
rep_table_init(uint32_t exclude_initial_board)
{
        int32_t index;
        uint32_t half_move_zero;

        rep_table_idle_test(__PRETTY_FUNCTION__, __FILE__, __LINE__);
        if (exclude_initial_board)
        {
                repdet_game_moves = 0;
                index = (int32_t) game_moves - 2;
                if (index < 0)
                {
                        vchess_repdet_depth(0);
                        return;
                }
        }
        else
                index = game_moves - 1;
        repdet_game_moves = 0;
        half_move_zero = 0;
        do
        {
                if (game[index].half_move_clock >= 0)
                {
                        rep_table_entry(game[index].board, game[index].castle_mask, repdet_game_moves);
                        half_move_zero = game[index].half_move_clock == 0;
                        ++repdet_game_moves;
                }
                --index;
        }
        while (index >= 0 && !half_move_zero);
        vchess_repdet_depth(repdet_game_moves);
}

static void
rep_table_load(const board_t * board, uint32_t ply)
{
        int32_t index, entries;

        rep_table_idle_test(__PRETTY_FUNCTION__, __FILE__, __LINE__);
        index = repdet_game_moves + ply;
        entries = index + 1;
        rep_table_entry(board->board, board->castle_mask, entries);
        vchess_repdet_depth(entries);
}

static int32_t
load_positions(board_t boards[MAX_POSITIONS])
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
        uint32_t move_count, index, endgame;
        uint32_t mate, stalemate, fifty_move;
        int32_t value;
        XTime t_now, am_t_start, am_t_stop;
        uint32_t time_limit_exceeded;
        board_t *board_ptr[MAX_POSITIONS];
        int32_t pv_next_index;

        ++nodes_visited;

        if (ply >= MAX_DEPTH - 1)
                return beta;

        pv_array[pv_index] = zero_move;
        pv_next_index = pv_index + MAX_DEPTH - ply;

        vchess_reset_all_moves();
        vchess_write_board_basic(board);

        XTime_GetTime(&am_t_start);
        vchess_write_board_wait(board, 1);
        XTime_GetTime(&am_t_stop);
        all_moves_ticks += am_t_stop - am_t_start;

        vchess_status(0, 0, &mate, &stalemate, 0, 0, &fifty_move, 0, 0);

        value = nm_initial_eval(board->white_to_move, ply);
        move_count = vchess_move_count();
        if (move_count == 0)
                return value;

        if (value >= beta)
                return value;

        if (value > alpha)
                alpha = value;

        // https://talkchess.com/viewtopic.php?p=930531&sid=748ca5279f802b33c538fae0e82da09a#p930531
        endgame = vchess_initial_material_black() < 1700 && vchess_initial_material_white() < 1700;
        if (!endgame && value + Q_DELTA < alpha && !(board->black_in_check || board->white_in_check))
                return alpha;

        ++abort_test_move_count;
        if (abort_test_move_count >= 1000)
        {
                abort_test_move_count = 0;
                XTime_GetTime(&t_now);
                time_limit_exceeded = t_now > time_limit;
                ui_data_stop = ui_data_available();
                uci_data_stop = uci_input_poll() == UCI_SEARCH_STOP;
                abort_search = time_limit_exceeded || ui_data_stop || uci_data_stop;
        }
        if (abort_search)
                return 0;       // will be ignored

        if (ply > q_ply_reached)
                q_ply_reached = ply;

        board_ptr[0] = 0;       // stop gcc -Wuninitialized, move count is always > 0 here
        for (index = 0; index < move_count; ++index)
        {
                vchess_read_board(&board_stack[ply][index], index);
                board_ptr[index] = &board_stack[ply][index];
                if (!board_ptr[index]->capture)
                {
                        printf("%s - non capture move in quiescence, stopping.\n", __PRETTY_FUNCTION__);
                        while (1);
                }
        }

        vchess_reset_all_moves();
        rep_table_load(board, ply);     // update thrice rep table

        index = 0;
        do
        {
                board_vert[ply] = board_ptr[index];
                value = -quiescence(board_ptr[index], -beta, -alpha, ply + 1, pv_next_index);
                if (abort_search)
                        return 0;
                if (value > alpha)
                        alpha = value;
                ++index;
        }
        while (!abort_search && index < move_count && alpha < beta);

        if (abort_search)
                return 0;       // will be ignored

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
        XTime t_now, am_t_start, am_t_stop;
        XTime q_start, q_stop;
        uint32_t time_limit_exceeded;
        board_t *board_ptr[MAX_POSITIONS];
        uint64_t node_start, node_stop, nodes;
        int32_t pv_next_index;
        int32_t ply_delta;

        if (ply >= MAX_DEPTH - 1)
        {
                printf("%s: increase MAX_DEPTH, stopping (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                while (1);
        }

        pv_array[pv_index] = zero_move;
        pv_next_index = pv_index + MAX_DEPTH - ply;

        node_start = nodes_visited;
        ++nodes_visited;

        alpha_orig = alpha;

        vchess_reset_all_moves();
        killer_ply(ply);
        vchess_write_board_basic(board);
        trans_lookup_init();    // trigger transposition table lookup

        XTime_GetTime(&am_t_start);
        vchess_write_board_wait(board, 0);
        XTime_GetTime(&am_t_stop);
        all_moves_ticks += am_t_stop - am_t_start;

        value = nm_initial_eval(board->white_to_move, ply);
        move_count = vchess_move_count();

        if (move_count == 0)
                return value;

        // mate distance pruning
        alpha = valmax(alpha, -GLOBAL_VALUE_KING + ply - 1);
        beta = valmin(beta, GLOBAL_VALUE_KING - ply);
        if (alpha >= beta)
        {
                ++mate_distance_pruning;
                return alpha;
        }

        trans_test_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
        vchess_trans_read(&collision, &trans.eval, &trans.depth, &trans.flag, &trans.nodes, &trans.capture, &trans.entry_valid, 0);
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

        ++abort_test_move_count;
        if (abort_test_move_count > 1000)
        {
                abort_test_move_count = 0;
                XTime_GetTime(&t_now);
                time_limit_exceeded = t_now > time_limit;
                ui_data_stop = ui_data_available();
                uci_data_stop = uci_input_poll() == UCI_SEARCH_STOP;
                abort_search = time_limit_exceeded || ui_data_stop || uci_data_stop;
        }
        if (abort_search)
                return 0;       // will be ignored

        board_ptr[0] = 0;       // stop gcc -Wuninitialized, move count is always > 0 here
        for (index = 0; index < move_count; ++index)
        {
                vchess_read_board(&board_stack[ply][index], index);
                board_ptr[index] = &board_stack[ply][index];
        }

        vchess_reset_all_moves();
        rep_table_load(board, ply);     // update thrice rep table

        ply_delta = ply * 20;
        in_check = board->white_in_check || board->black_in_check;
        index = 0;
        do
        {
                board_vert[ply] = board_ptr[index];
                if (board_ptr[index]->thrice_rep || board_ptr[index]->fifty_move)
                        board_eval = 0;
                else
                {
                        board_eval = board_ptr[index]->eval;
                        if (!board->white_to_move)
                                board_eval = -board_eval;
                }
                if (depth <= 0 && (in_check || board_ptr[index]->capture || board_ptr[index]->white_in_check || board_ptr[index]->black_in_check))
                {
                        XTime_GetTime(&q_start);
                        value = -quiescence(board_ptr[index], -beta, -alpha, ply + 1, pv_next_index);
                        XTime_GetTime(&q_stop);
                        q_ticks += q_stop - q_start;
                        if (abort_search)
                                return 0;       // will be ignored
                }
                else if (depth > 0)
                {
                        if (index == 0 || ply < 2 || in_check || board_eval + 100 > alpha + ply_delta)
                                value = -negamax(board_ptr[index], depth - 1, -beta, -alpha, ply + 1, pv_next_index);
                        else
                                value = -GLOBAL_VALUE_KING;
                        if (abort_search)
                                return 0;       // will be ignored
                        if (value > alpha && value < beta)
                        {
                                pv_array[pv_index] = board_ptr[index]->uci;
                                local_movcpy(pv_array + pv_index + 1, pv_array + pv_next_index, MAX_DEPTH - ply - 1);
                        }
                }
                else if (board_eval > alpha)
                        value = board_eval;
                if (value > alpha)
                        alpha = value;

                ++index;
        }
        while (!abort_search && index < move_count && alpha < beta);

        if (abort_search)
                return 0;       // will be ignored

        if (ply > 1 && index < move_count && !board_ptr[index - 1]->capture)    // beta cutoff
        {
                killer_ply(ply);
                killer_write_board(board_ptr[index - 1]->board);
                killer_update_table();
        }

        node_stop = nodes_visited;
        nodes = node_stop - node_start;
        if (nodes >= (1 << TRANS_NODES_WIDTH))
                nodes = (1 << TRANS_NODES_WIDTH) - 1;
        vchess_write_board_basic(board);
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
                trans.capture = board->capture;
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

#if 0
        if ((*b1)->capture == 1 && (*b2)->capture == 0)
                return -1;
        if ((*b1)->capture == 0 && (*b2)->capture == 1)
                return 1;
#endif
        if ((*b1)->eval > (*b2)->eval)
                return -1;
        if ((*b1)->eval < (*b2)->eval)
                return 1;

        return 0;
}

void
nm_init(void)
{
        // no ops just for now
}

board_t
nm_top(const tc_t * tc)
{
        int32_t i, game_index;
        int32_t alpha, beta;
        int32_t depth_limit;
        uint32_t move_count;
        uint64_t elapsed_ticks;
        int64_t duration_seconds;
        double elapsed_time, nps, elapsed_am_time;
        double q_time;
        int32_t evaluate_move, best_evaluation, overall_best, trans_hit;
        board_t best_board = { 0 };
        XTime t_end, t_report, t_start;
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
        no_trans = 0;
        trans_collision = 0;
        mate_distance_pruning = 0;
        all_moves_ticks = 0;
        q_ticks = 0;

        vchess_reset_all_moves();
        rep_table_init(1);
        vchess_write_board_basic(&game[game_index]);
        vchess_write_board_wait(&game[game_index], 0);
        move_count = vchess_move_count();
        if (move_count == 0)
        {
                xil_printf("%s: game is over, no moves (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                return best_board;
        }

        tc_display(tc);
        printf(" - %s to move - ", best_board.white_to_move ? "white" : "black");

        load_positions(root_node_boards);

        vchess_reset_all_moves();
        rep_table_init(0);

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
                duration_seconds += (double)tc->increment * 7.0 / 8.0 + 0.5;
                if (duration_seconds * 5 > tc->main_remaining[tc->side])
                        duration_seconds /= 8;
                if (duration_seconds <= 0)
                        duration_seconds = 1;
        }
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
        depth_limit = 1;
        while (depth_limit < MAX_DEPTH - 1 && !abort_search)
        {
                i = 0;
                best_evaluation = -LARGE_EVAL;
                while (i < move_count && !abort_search)
                {
                        board_vert[0] = board_ptr[i];
                        evaluate_move = -negamax(board_ptr[i], depth_limit, alpha, beta, 0, 0);
                        board_ptr[i]->eval = evaluate_move;     // sort key for iterative deepening depth-first search
                        if (!abort_search && evaluate_move > best_evaluation)
                        {
                                best_board = *board_ptr[i];
                                best_evaluation = evaluate_move;
                                overall_best = evaluate_move;
                                printf("be=%d ", best_evaluation);
                                fflush(stdout);
                        }
                        ++i;
                }
                if (best_evaluation != -LARGE_EVAL)
                        printf("\n");
                if (!abort_search)
                {
                        qsort(board_ptr, move_count, sizeof(board_t *), nm_move_sort_compare);
                        pv_load_table(pv_array);
                        if (debug_pv_info)
                        {
                                XTime_GetTime(&t_report);
                                elapsed_ticks = t_report - t_start;
                                elapsed_time = (double)elapsed_ticks / ((double)COUNTS_PER_SECOND / 1000.0);
                                nps = (double)nodes_visited / ((double)elapsed_ticks / (double)COUNTS_PER_SECOND);
                                uci_pv(depth_limit, best_evaluation, (uint32_t) elapsed_time, nodes_visited, (uint32_t) nps, &board_ptr[0]->uci,
                                       pv_array);
                        }
                }
                ++depth_limit;
                if (q_ply_reached > valid_q_ply_reached)
                        valid_q_ply_reached = q_ply_reached;
        }
        best_board.full_move_number = 1 + game_moves / 2;

        XTime_GetTime(&t_end);
        elapsed_ticks = t_end - t_start;
        elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
        nps = (double)nodes_visited / elapsed_time;
        trans_hit = nodes_visited - no_trans;
        elapsed_am_time = (double)all_moves_ticks / (double)COUNTS_PER_SECOND;
        q_time = (double)q_ticks / (double)COUNTS_PER_SECOND;

        printf("best_evaluation=%d, nodes_visited=%u, seconds=%.2f, nps=%.0f, all_moves_time=%.2f%%, q_time=%.2f%%\n",
               overall_best, nodes_visited, elapsed_time, nps, (elapsed_am_time * 100.0) / elapsed_time, (q_time * 100.0) / elapsed_time);
        printf("depth_limit=%d, q_depth=%d mate_distance_pruning=%d\n", depth_limit, valid_q_ply_reached, mate_distance_pruning);
        printf("no_trans=%u, trans_hit=%d (%.2f%%), trans_collision=%u (%.2f%%)\n", no_trans,
               trans_hit, ((double)trans_hit * 100.0) / (double)nodes_visited, trans_collision,
               ((double)trans_collision * 100.0) / (double)nodes_visited);

        return best_board;
}
