#include <stdio.h>
#include <xparameters.h>
#include <netif/xadapter.h>
#include <lwip/tcp.h>
#include <lwip/priv/tcp_priv.h>
#include <lwip/init.h>
#include <xil_cache.h>
#include <xuartps.h>
#include <xtime_l.h>
#include "vchess.h"

extern board_t game[GAME_MAX];
extern uint32_t game_moves;
extern uint32_t tc_main, tc_increment;

static tc_t tc;

void
do_both(void)
{
        uint32_t move_count, key_hit, game_result;
        uint32_t book_move_found;
        board_t best_board;
        uint32_t mate, stalemate, thrice_rep, fifty_move, insufficient;
        XTime t_end, t_start;
        uint64_t elapsed_ticks;
        double elapsed_time;
        uint32_t tc_status;

        XTime_GetTime(&t_start);
        tc_init(&tc, tc_main * 60, tc_increment);
        do
        {
                book_move_found = book_game_move(&game[game_moves - 1]);
                if (book_move_found)
                {
                        printf("book move\n");

                        mate = 0;
                        stalemate = 0;
                        thrice_rep = 0;
                        fifty_move = 0;
                        insufficient = 0;
                        move_count = 1;
                        best_board = game[game_moves - 1];
                }
                else
                {
                        best_board = nm_top(&tc);
                        vchess_write_board_basic(&best_board);
                        vchess_write_board_wait(&best_board, 0);
                        move_count = vchess_move_count();
                        vchess_status(0, 0, &mate, &stalemate, &thrice_rep, 0, &fifty_move, &insufficient, 0);
                        vchess_reset_all_moves();
                        game[game_moves] = best_board;
                        ++game_moves;
                }
                tc_status = tc_clock_toggle(&tc);
                if (game_moves >= GAME_MAX)
                {
                        printf("%s: game_moves (%d) >= GAME_MAX (%d), stopping here %s %d\n", __PRETTY_FUNCTION__,
                               game_moves, GAME_MAX, __FILE__, __LINE__);
                        while (1);
                }
                vchess_print_board(&best_board, 1);
                fen_print(&best_board);
                printf("\n");
                key_hit = ui_data_available();
        }
        while (move_count > 0 && !(mate || stalemate || thrice_rep || fifty_move || insufficient) && tc_status == TC_OK && !key_hit);
        XTime_GetTime(&t_end);
        elapsed_ticks = t_end - t_start;
        elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
        printf("total elapsed time: %.1f\n", elapsed_time);
        if (key_hit)
        {
                printf("Abort\n");
                tc_ignore(&tc);
        }
        else
        {
                printf("white clock: %d, black clock %d\n", tc.main_remaining[0], tc.main_remaining[1]);
                printf("both done: mate %d, stalemate %d, thrice rep %d, fifty move: %d, insufficient: %d\n\n",
                       mate, stalemate, thrice_rep, fifty_move, insufficient);
                if (mate)
                        if (best_board.white_in_check)
                                game_result = RESULT_BLACK_WIN;
                        else
                                game_result = RESULT_WHITE_WIN;
                else
                        game_result = RESULT_DRAW;
                uci_print_game(game_result);
        }
}

void
fen_print(const board_t * board)
{
        int row, col, empty, i;
        uint32_t piece;
        char en_passant_col;
        char piece_char[1 << PIECE_BITS];

        for (i = 0; i < (1 << PIECE_BITS); ++i)
                piece_char[i] = '?';
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

        for (row = 7; row >= 0; --row)
        {
                empty = 0;
                for (col = 0; col < 8; ++col)
                {
                        piece = vchess_get_piece(board, row, col);
                        if (piece == EMPTY_POSN)
                                ++empty;
                        else
                        {
                                if (empty > 0)
                                {
                                        printf("%d", empty);
                                        empty = 0;
                                }
                                printf("%c", piece_char[piece]);
                        }
                }
                if (empty > 0)
                        printf("%d", empty);
                if (row > 0)
                        printf("/");
        }
        printf(" ");
        if (board->white_to_move)
                printf("w");
        else
                printf("b");
        printf(" ");
        if (board->castle_mask == 0)
                printf("-");
        if ((board->castle_mask & (1 << CASTLE_WHITE_SHORT)) != 0)
                printf("K");
        if ((board->castle_mask & (1 << CASTLE_WHITE_LONG)) != 0)
                printf("Q");
        if ((board->castle_mask & (1 << CASTLE_BLACK_SHORT)) != 0)
                printf("k");
        if ((board->castle_mask & (1 << CASTLE_BLACK_LONG)) != 0)
                printf("q");
        printf(" ");
        if ((board->en_passant_col & (1 << EN_PASSANT_VALID_BIT)) == 0)
                printf("-");
        else
        {
                en_passant_col = 'a' + (board->en_passant_col & 0x7);
                if (board->white_to_move)
                        printf("%c6", en_passant_col);
                else
                        printf("%c3", en_passant_col);
        }
        printf(" %d %d\n", board->half_move_clock, board->full_move_number);
}

uint32_t
fen_board(uint8_t buffer[BUF_SIZE], board_t * board)
{
        int row, col, i, stop_col;

        row = 7;
        col = 0;
        i = 0;
        while (i < BUF_SIZE && buffer[i] != '\0' && !(buffer[i] == ' ' || buffer[i] == '\t'))
        {
                switch (buffer[i])
                {
                case 'r':
                        vchess_place(board, row, col, BLACK_ROOK);
                        ++col;
                        break;
                case 'n':
                        vchess_place(board, row, col, BLACK_KNIT);
                        ++col;
                        break;
                case 'b':
                        vchess_place(board, row, col, BLACK_BISH);
                        ++col;
                        break;
                case 'q':
                        vchess_place(board, row, col, BLACK_QUEN);
                        ++col;
                        break;
                case 'k':
                        vchess_place(board, row, col, BLACK_KING);
                        ++col;
                        break;
                case 'p':
                        vchess_place(board, row, col, BLACK_PAWN);
                        ++col;
                        break;
                case 'R':
                        vchess_place(board, row, col, WHITE_ROOK);
                        ++col;
                        break;
                case 'N':
                        vchess_place(board, row, col, WHITE_KNIT);
                        ++col;
                        break;
                case 'B':
                        vchess_place(board, row, col, WHITE_BISH);
                        ++col;
                        break;
                case 'Q':
                        vchess_place(board, row, col, WHITE_QUEN);
                        ++col;
                        break;
                case 'K':
                        vchess_place(board, row, col, WHITE_KING);
                        ++col;
                        break;
                case 'P':
                        vchess_place(board, row, col, WHITE_PAWN);
                        ++col;
                        break;
                case '/':
                        col = 0;
                        --row;
                        break;
                default:
                        if (!(buffer[i] >= '1' && buffer[i] <= '8'))
                        {
                                printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                                return 1;
                        }
                        stop_col = col + buffer[i] - '1';
                        while (col <= stop_col)
                        {
                                vchess_place(board, row, col, EMPTY_POSN);
                                ++col;
                        }
                        break;
                }
                ++i;
        }
        ++i;
        if (!(i < BUF_SIZE && (buffer[i] == 'w' || buffer[i] == 'b')))
        {
                printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                return 1;
        }
        board->white_to_move = buffer[i] == 'w';
        i += 2;
        board->castle_mask = 0;
        while (i < BUF_SIZE && buffer[i] != '\0' && !(buffer[i] == ' ' || buffer[i] == '\t'))
        {
                switch (buffer[i])
                {
                case 'K':
                        board->castle_mask |= 1 << CASTLE_WHITE_SHORT;
                        break;
                case 'Q':
                        board->castle_mask |= 1 << CASTLE_WHITE_LONG;
                        break;
                case 'k':
                        board->castle_mask |= 1 << CASTLE_BLACK_SHORT;
                        break;
                case 'q':
                        board->castle_mask |= 1 << CASTLE_BLACK_LONG;
                        break;
                case '-':
                        board->castle_mask = 0;
                        break;
                default:
                        printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                        return 1;
                }
                ++i;
        }
        ++i;
        if (!(i < BUF_SIZE))
        {
                printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                return 1;
        }
        if (!(buffer[i] == '-' || (buffer[i] >= 'a' && buffer[i] <= 'h')))
        {
                printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                return 1;
        }
        if (buffer[i] == '-')
        {
                board->en_passant_col = 0 << EN_PASSANT_VALID_BIT;
                ++i;
        }
        else
        {
                board->en_passant_col = (1 << EN_PASSANT_VALID_BIT) | (buffer[i] - 'a');
                i += 2;
        }
        if (!(i < BUF_SIZE))
        {
                printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                return 1;
        }
        if (sscanf((char *)&buffer[i], "%d %d", &board->half_move_clock, &board->full_move_number) != 2)
        {
                printf("%s: bad FEN half move clock or ful move number%s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                return 1;
        }

        return 0;
}

void
process_cmd(uint8_t cmd[BUF_SIZE])
{
        int /* len, */ move_index;
        char str[BUF_SIZE];
        int arg1, arg2, arg3;
        static board_t board;
        board_t best_board;
        uint32_t status;

        printf("cmd: %s\n", cmd);
#if 0
        len = strlen((char *)cmd);
        tcp_write(cmd_pcb, cmd, len, TCP_WRITE_FLAG_COPY);
        tcp_write(cmd_pcb, "\n", 1, TCP_WRITE_FLAG_COPY);
#endif
        sscanf((char *)cmd, "%s %d %d %d\n", str, &arg1, &arg2, &arg3);

        if (strcmp((char *)str, "status") == 0)
        {
                uint32_t move_ready, moves_ready, mate, stalemate, thrice_rep, fifty_move, insufficient, check;

                status = vchess_status(&move_ready, &moves_ready, &mate, &stalemate, &thrice_rep, 0, &fifty_move, &insufficient, &check);
                printf("moves_ready=%d, mate=%d, stalemate=%d, thrice_rep=%d, fifty_move=%d, insufficient=%d, check=%d",
                       moves_ready, mate, stalemate, thrice_rep, fifty_move, insufficient, check);
                if (moves_ready)
                        printf(", moves=%d, eval=%d", vchess_move_count(), vchess_initial_eval());
                printf("\n");
        }
        else if (strcmp((char *)str, "read") == 0)
        {
                move_index = arg1;
                status = vchess_read_board(&board, move_index);
                if (status == 0)
                        vchess_print_board(&board, 0);
        }
        else if (strcmp((char *)str, "nm") == 0)
        {
                tc_t tc;

                if (game_moves > 0)
                {
                        tc_ignore(&tc);
                        trans_clear_table();    // for ease of debug
                        best_board = nm_top(&tc);
                        vchess_write_board_basic(&best_board);
                        vchess_write_board_wait(&best_board, 0);
                        vchess_print_board(&best_board, 1);
                        fen_print(&best_board);
                        vchess_reset_all_moves();
                        game[game_moves] = best_board;
                        ++game_moves;
                }
                else
                        printf("%s: ignored, no game sequence to analyze (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
        }
        else if (strcmp((char *)str, "both") == 0)
        {
                do_both();
        }
        else if (strcmp((char *)str, "game") == 0)
        {
                killer_clear_table();
                trans_clear_table();
                uci_init();
        }
        else if (strcmp((char *)str, "pos") == 0)
        {
                char *fen_ptr, *str_ptr;

                game_moves = 1;
                strcpy(str, (char *)cmd);
                str_ptr = str;
                fen_ptr = strsep(&str_ptr, " ");
                if (!fen_ptr)
                {
                        printf("%s: error, no fen data\n", __PRETTY_FUNCTION__);
                        return;
                }
                status = fen_board(cmd, &board);
                if (status)
                        return;
                killer_clear_table();
                trans_clear_table();
                game_moves = 1;
                board.half_move_clock = 0;
                board.full_move_number = 0;
                game[0] = board;
        }
        else if (strcmp((char *)str, "print") == 0)
        {
                if (game_moves > 0)
                        vchess_print_board(&game[game_moves - 1], 1);
                else
                        printf("No positions to print.\n");
        }
        else if (strcmp((char *)str, "sample") == 0)
        {
                killer_clear_table();
                trans_clear_table();
                game_moves = sample_game(game);
                if (game_moves > 0)
                {
                        printf("last move in sample game:\n");
                        vchess_write_board_basic(&game[game_moves - 1]);
                        vchess_write_board_wait(&game[game_moves - 1], 0);
                        vchess_print_board(&game[game_moves - 1], 1);
                        fen_print(&game[game_moves - 1]);
                        vchess_reset_all_moves();
                }
                else
                        printf("%s: no moves found in sample\n", __PRETTY_FUNCTION__);
        }
        else if (strcmp((char *)str, "dump") == 0)
        {
                uci_print_game(RESULT_NONE);
        }
        else if (strcmp((char *)str, "tclear") == 0)
        {
                trans_clear_table();
        }
        else if (strcmp((char *)str, "mstatus") == 0)
        {
                printf("misc_status=%08X\n", vchess_misc_status());
        }
        else if (strcmp((char *)str, "bbook") == 0)
        {
                book_build();
        }
        else if (strcmp((char *)str, "bopen") == 0)
        {
                book_open();
        }
        else if (strcmp((char *)str, "btest") == 0)
        {
                uint32_t status, trans_idle;
                uint16_t hash_extra;
                uint64_t hash;
                uci_t uci;

                uci_init();
                uci_move("e2e4");
                uci_move("c7c5");
                uci_move("g1f3");
                uci_move("d7d6");
                vchess_write_board_basic(&game[game_moves - 1]);
                vchess_trans_hash_only();
                trans_idle = vchess_trans_idle_wait();
                if (!trans_idle)
                {
                        printf("%s: hash state machine idle timeout, stopping. (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                        while (1);
                }
                hash = vchess_trans_hash(&hash_extra);
                status = book_move(hash_extra, hash, BOOK_RANDOM_COMMON, &uci);
                if (!status)
                        printf("no book move found\n");
        }
        else if (strcmp((char *)str, "rand") == 0)
        {
                printf("%08X\n", vchess_random());
        }
        else if (strcmp((char *)str, "rmask") == 0)
        {
                uint32_t rmask = arg1;

                printf("random score mask: 0x%04X\n", rmask);
                vchess_random_score_mask(rmask);
        }
        else if (strcmp((char *)str, "tc") == 0)
        {
                if (arg1 <= 0 || arg2 < 0)
                        printf("usage: tc minutes seconds\n");
                else
                {
                        tc_main = arg1;
                        tc_increment = arg2;
                        printf("time control now main %d minutes, %d seconds increment\n", tc_main, tc_increment);
                }
        }
        else
        {
                char *uci_ptr, *c;

                strcpy(str, (char *)cmd);
                uci_ptr = str;
                c = str;
                while ((uci_ptr = strsep(&c, " \n\r")) != 0)
                        if (uci_move(uci_ptr))
                        {
                                printf("%s: unkown uci move\n", __PRETTY_FUNCTION__);
                                return;
                        }
        }
}
