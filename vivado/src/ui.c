#include <stdio.h>
#include <xparameters.h>
#include <netif/xadapter.h>
#include <xil_printf.h>
#include <lwip/tcp.h>
#include <lwip/priv/tcp_priv.h>
#include <lwip/init.h>
#include <xil_cache.h>
#include <xuartps.h>
#include <xtime_l.h>
#include "vchess.h"

extern board_t game[GAME_MAX];
extern uint32_t game_moves;

static void
uci_init(void)
{
        int32_t i, j;

        for (i = 2; i <= 5; ++i)
                for (j = 0; j < 8; ++j)
                        vchess_place(&game[0], i, j, EMPTY_POSN);
        for (j = 0; j < 8; ++j)
        {
                vchess_place(&game[0], 1, j, WHITE_PAWN);
                vchess_place(&game[0], 6, j, BLACK_PAWN);
        }
        vchess_place(&game[0], 0, 0, WHITE_ROOK);
        vchess_place(&game[0], 0, 1, WHITE_KNIT);
        vchess_place(&game[0], 0, 2, WHITE_BISH);
        vchess_place(&game[0], 0, 3, WHITE_QUEN);
        vchess_place(&game[0], 0, 4, WHITE_KING);
        vchess_place(&game[0], 0, 5, WHITE_BISH);
        vchess_place(&game[0], 0, 6, WHITE_KNIT);
        vchess_place(&game[0], 0, 7, WHITE_ROOK);

        vchess_place(&game[0], 7, 0, BLACK_ROOK);
        vchess_place(&game[0], 7, 1, BLACK_KNIT);
        vchess_place(&game[0], 7, 2, BLACK_BISH);
        vchess_place(&game[0], 7, 3, BLACK_QUEN);
        vchess_place(&game[0], 7, 4, BLACK_KING);
        vchess_place(&game[0], 7, 5, BLACK_BISH);
        vchess_place(&game[0], 7, 6, BLACK_KNIT);
        vchess_place(&game[0], 7, 7, BLACK_ROOK);

        game[0].en_passant_col = 0 << EN_PASSANT_VALID_BIT;
        game[0].castle_mask = 0xF;
        game[0].white_to_move = 1;
        game[0].half_move_clock = 0;
        game[0].full_move_number = 1;

        game_moves = 1;
}

static void
uci_move(char *p)
{
        int32_t col_from, row_from, col_to, row_to;
        uint32_t piece, promotion, piece_type;
        board_t *previous_board, next_board;

        previous_board = &game[game_moves - 1];
        next_board = *previous_board;
        next_board.capture = 0;
        next_board.white_to_move = !previous_board->white_to_move;
        if (next_board.white_to_move)
                ++next_board.full_move_number;
        ++next_board.half_move_clock;
        next_board.en_passant_col = 0 << EN_PASSANT_VALID_BIT;

        col_from = p[0] - 'a';
        row_from = p[1] - '1';
        col_to = p[2] - 'a';
        row_to = p[3] - '1';
        switch (p[4])
        {
        case 'Q':
                promotion = PIECE_QUEN;
                break;
        case 'N':
                promotion = PIECE_KNIT;
                break;
        case 'B':
                promotion = PIECE_BISH;
                break;
        case 'R':
                promotion = PIECE_ROOK;
                break;
        case '\0':
                promotion = EMPTY_POSN;
                break;
        default:
                fprintf(stderr, "%s: problems (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                exit(1);
        }
        if (promotion != EMPTY_POSN)
        {
                if (previous_board->white_to_move)
                        promotion |= 0 << BLACK_BIT;
                else
                        promotion |= 1 << BLACK_BIT;
        }
        next_board.uci.row_from = row_from;
        next_board.uci.col_from = col_from;
        next_board.uci.row_to = row_to;
        next_board.uci.col_to = col_to;
        next_board.uci.promotion = promotion;

        piece = vchess_get_piece(previous_board, row_from, col_from);
        piece_type = piece & ~(1 << BLACK_BIT);

        // unconditionally vacate "from" square
        vchess_place(&next_board, row_from, col_from, EMPTY_POSN);

        if (piece == WHITE_ROOK && row_from == 0)
        {
                if (col_from == 7)
                        next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_WHITE_SHORT);
                else if (col_from == 0)
                        next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_WHITE_LONG);
        }
        else if (piece == BLACK_ROOK && row_from == 7)
        {
                if (col_from == 7)
                        next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_BLACK_SHORT);
                else if (col_from == 0)
                        next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_BLACK_LONG);
        }
        else if (piece == WHITE_KING)
                next_board.castle_mask = previous_board->castle_mask &
                        ~(1 << CASTLE_WHITE_SHORT | 1 << CASTLE_WHITE_LONG);
        else if (piece == BLACK_KING)
                next_board.castle_mask = previous_board->castle_mask &
                        ~(1 << CASTLE_BLACK_SHORT | 1 << CASTLE_BLACK_LONG);

        // castling
        if (piece == WHITE_KING && row_from == 0 && row_to == 0 && col_from == 4 && col_to == 6)
        {
                vchess_place(&next_board, row_from, 7, EMPTY_POSN);
                vchess_place(&next_board, row_from, 5, WHITE_ROOK);
                vchess_place(&next_board, row_from, 6, WHITE_KING);
        }
        else if (piece == WHITE_KING && row_from == 0 && row_to == 0 && col_from == 4 && col_to == 2)
        {
                vchess_place(&next_board, row_from, 0, EMPTY_POSN);
                vchess_place(&next_board, row_from, 1, EMPTY_POSN);
                vchess_place(&next_board, row_from, 3, WHITE_ROOK);
                vchess_place(&next_board, row_from, 2, WHITE_KING);
        }
        else if (piece == BLACK_KING && row_from == 7 && row_to == 7 && col_from == 4 && col_to == 6)
        {
                vchess_place(&next_board, row_from, 7, EMPTY_POSN);
                vchess_place(&next_board, row_from, 5, BLACK_ROOK);
                vchess_place(&next_board, row_from, 6, BLACK_KING);
        }
        else if (piece == BLACK_KING && row_from == 0 && row_to == 0 && col_from == 4 && col_to == 2)
        {
                vchess_place(&next_board, row_from, 0, EMPTY_POSN);
                vchess_place(&next_board, row_from, 1, EMPTY_POSN);
                vchess_place(&next_board, row_from, 3, WHITE_ROOK);
                vchess_place(&next_board, row_from, 2, WHITE_KING);
        }
        // en-passant target
        else if (piece == WHITE_PAWN && row_from == 1 && row_to == 3)
        {
                vchess_place(&next_board, row_to, col_to, WHITE_PAWN);
                next_board.half_move_clock = 0;
                next_board.en_passant_col = 1 << EN_PASSANT_VALID_BIT | col_to;
        }
        else if (piece == BLACK_PAWN && row_from == 6 && row_to == 4)
        {
                vchess_place(&next_board, row_to, col_to, BLACK_PAWN);
                next_board.half_move_clock = 0;
                next_board.en_passant_col = 1 << EN_PASSANT_VALID_BIT | col_to;
        }
        // en-passant capture
        else if (piece == WHITE_PAWN && vchess_get_piece(previous_board, row_to, col_to) == EMPTY_POSN
                 && col_from != col_to)
        {
                vchess_place(&next_board, row_to, col_to, WHITE_PAWN);
                vchess_place(&next_board, row_to, col_to - 1, EMPTY_POSN);
                next_board.capture = 1;
                next_board.half_move_clock = 0;
        }
        else if (piece == BLACK_PAWN && vchess_get_piece(previous_board, row_to, col_to) == EMPTY_POSN
                 && col_from != col_to)
        {
                vchess_place(&next_board, row_to, col_to, BLACK_PAWN);
                vchess_place(&next_board, row_to, col_to + 1, EMPTY_POSN);
                next_board.capture = 1;
                next_board.half_move_clock = 0;
        }
        // promotion
        else if (piece == WHITE_PAWN && row_to == 7)
        {
                vchess_place(&next_board, 7, col_to, promotion);
                next_board.capture = vchess_get_piece(previous_board, 7, col_to) != EMPTY_POSN;
                next_board.half_move_clock = 0;
        }
        else if (piece == BLACK_PAWN && row_to == 0)
        {
                vchess_place(&next_board, 0, col_to, promotion);
                next_board.capture = vchess_get_piece(previous_board, 7, col_to) != EMPTY_POSN;
                next_board.half_move_clock = 0;
        }
        // all other moves
        else
        {
                vchess_place(&next_board, row_to, col_to, piece);
                next_board.capture = vchess_get_piece(previous_board, row_to, col_to) != EMPTY_POSN;
                if (next_board.capture || piece_type == PIECE_PAWN)
                        next_board.half_move_clock = 0;
        }
        game[game_moves] = next_board;
        ++game_moves;
}

void
fen_print(board_t * board)
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
                                        xil_printf("%d", empty);
                                        empty = 0;
                                }
                                xil_printf("%c", piece_char[piece]);
                        }
                }
                if (empty > 0)
                        xil_printf("%d", empty);
                if (row > 0)
                        xil_printf("/");
        }
        xil_printf(" ");
// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
        if (board->white_to_move)
                xil_printf("w");
        else
                xil_printf("b");
        xil_printf(" ");
        if (board->castle_mask == 0)
                xil_printf("-");
        if ((board->castle_mask & (1 << CASTLE_WHITE_SHORT)) != 0)
                xil_printf("K");
        if ((board->castle_mask & (1 << CASTLE_WHITE_LONG)) != 0)
                xil_printf("Q");
        if ((board->castle_mask & (1 << CASTLE_BLACK_SHORT)) != 0)
                xil_printf("k");
        if ((board->castle_mask & (1 << CASTLE_BLACK_LONG)) != 0)
                xil_printf("q");
        xil_printf(" ");
        if ((board->en_passant_col & (1 << EN_PASSANT_VALID_BIT)) == 0)
                xil_printf("-");
        else
        {
                en_passant_col = 'a' + (board->en_passant_col & 0x7);
                if (board->white_to_move)
                        xil_printf("%c6", en_passant_col);
                else
                        xil_printf("%c3", en_passant_col);
        }
        xil_printf(" %d %d\n", board->half_move_clock, board->full_move_number);
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
                                xil_printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__,
                                           __LINE__);
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
                xil_printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
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
                        xil_printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                        return 1;
                }
                ++i;
        }
        ++i;
        if (!(i < BUF_SIZE))
        {
                xil_printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                return 1;
        }
// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
        if (!(buffer[i] == '-' || (buffer[i] >= 'a' && buffer[i] <= 'h')))
        {
                xil_printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
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
                xil_printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                return 1;
        }
        if (sscanf((char *)&buffer[i], "%d %d", &board->half_move_clock, &board->full_move_number) != 2)
        {
                xil_printf("%s: bad FEN half move clock or ful move number%s (%s %d)\n", __PRETTY_FUNCTION__, buffer,
                           __FILE__, __LINE__);
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

        xil_printf("cmd: %s\n", cmd);
#if 0
        len = strlen((char *)cmd);
        tcp_write(cmd_pcb, cmd, len, TCP_WRITE_FLAG_COPY);
        tcp_write(cmd_pcb, "\n", 1, TCP_WRITE_FLAG_COPY);
#endif
        sscanf((char *)cmd, "%s %d %d %d\n", str, &arg1, &arg2, &arg3);

        if (strcmp((char *)str, "status") == 0)
        {
                uint32_t move_ready, moves_ready, mate, stalemate, thrice_rep, fifty_move;

                status = vchess_status(&move_ready, &moves_ready, &mate, &stalemate, &thrice_rep, 0, &fifty_move);
                xil_printf("moves_ready=%d, mate=%d, stalemate=%d, thrice_rep=%d, fifty_move=%d",
                           moves_ready, mate, stalemate, thrice_rep, fifty_move);
                if (moves_ready)
                        xil_printf(", moves=%d, eval=%d", vchess_move_count(), vchess_initial_eval());
                xil_printf("\n");
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
                if (game_moves > 0)
                {
                        best_board = nm_top(game, game_moves);
                        vchess_write_board(&best_board);
                        vchess_print_board(&best_board, 1);
                        fen_print(&best_board);
                        vchess_reset_all_moves();
                        game[game_moves] = best_board;
                        ++game_moves;
                }
                else
                        xil_printf("%s: ignored, no game sequence to analyze (%s %d)\n", __PRETTY_FUNCTION__, __FILE__,
                                   __LINE__);
        }
        else if (strcmp((char *)str, "both") == 0)
        {
                do_both();
        }
        else if (strcmp((char *)str, "game") == 0)
        {
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
                        xil_printf("%s: error, no fen data\n", __PRETTY_FUNCTION__);
                        return;
                }
                status = fen_board(cmd, &board);
                if (status)
                        return;
                game_moves = 1;
                board.half_move_clock = 0;
                board.full_move_number = 0;
                game[0] = board;
        }
        else if (strcmp((char *)str, "sample") == 0)
        {
                game_moves = sample_game(game);
                if (game_moves > 0)
                {
                        xil_printf("last move in sample game:\n");
                        vchess_write_board(&game[game_moves - 1]);
                        vchess_print_board(&game[game_moves - 1], 1);
                        fen_print(&game[game_moves - 1]);
                        vchess_reset_all_moves();
                }
                else
                        xil_printf("%s: no moves found in sample\n", __PRETTY_FUNCTION__);
        }
        else if (strcmp((char *)str, "dump") == 0)
        {
                uint32_t i;
                char uci_str[6];

                for (i = 1; i < game_moves; ++i)
                {
                        vchess_uci_string(&game[i].uci, uci_str);
                        xil_printf("%s ", uci_str);
                        if (i % 16 == 0)
                                xil_printf("\n");
                }
                xil_printf("\n");
        }
        else
        {
                uci_move(str);
        }
}
