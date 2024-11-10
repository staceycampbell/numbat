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

#define UCI_INPUT_BUFFER_SIZE 4096

extern board_t game[GAME_MAX];
extern uint32_t game_moves;
extern uint32_t tc_main, tc_increment;

static char uci_input_buffer[UCI_INPUT_BUFFER_SIZE];
static uint32_t uci_input_index;

static void
uci_reply(const char *str)
{
        int32_t len, i;

        len = strlen(str);
        for (i = 0; i < len; ++i)
                XUartPs_SendByte(XPAR_XUARTPS_1_BASEADDR, str[i]);
        XUartPs_SendByte(XPAR_XUARTPS_1_BASEADDR, '\n');
}

static uint32_t
uci_dispatch(void)
{
        char *p, *next;
        uint32_t uci_search_action;

        uci_search_action = UCI_SEARCH_STOP;
        p = uci_input_buffer;
        next = p;
        p = strsep(&next, " \n\t\r");
        if (strlen(p) <= 1)
                return UCI_SEARCH_CONT;
        if (strcmp(p, "uci") == 0)
        {
                uci_reply("id name fpgachess");
                uci_reply("id author Stacey Campbell");
                uci_reply("option name OwnBook type check default true");
        }
        else if (strcmp(p, "isready") == 0)
        {
                uci_search_action = UCI_SEARCH_CONT;
                uci_reply("readyok");
        }
	else if (strcmp(p, "ucinewgame") == 0)
	{
                trans_clear_table();
                uci_init();
	}
	else if (strcmp(p, "position") == 0)
	{
	}

        return uci_search_action;
}

void
uci_input_reset(void)
{
        memset(uci_input_buffer, 0, UCI_INPUT_BUFFER_SIZE);
        uci_input_index = 0;
}

uint32_t
uci_input_poll(void)
{
        char c;
        uint32_t uci_search_action;

        if (!XUartPs_IsReceiveData(XPAR_XUARTPS_1_BASEADDR))
                return UCI_SEARCH_CONT;
        c = XUartPs_ReadReg(XPAR_XUARTPS_1_BASEADDR, XUARTPS_FIFO_OFFSET);
        uci_input_buffer[uci_input_index] = c;
        uci_input_buffer[uci_input_index + 1] = '\0';
        ++uci_input_index;
        if (uci_input_index >= UCI_INPUT_BUFFER_SIZE - 1)
        {
                printf("%s: input buffer overflow, stopping\n", __PRETTY_FUNCTION__);
                while (1);
        }
        if (c != '\n')
                return UCI_SEARCH_CONT;
        uci_search_action = uci_dispatch();
        uci_input_reset();

        return uci_search_action;
}

void
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

int32_t
uci_move(char *p)
{
        int32_t col_from, row_from, col_to, row_to;
        uint32_t piece, promotion, piece_type;
        board_t *previous_board, next_board;

        if (game_moves == 0)
        {
                printf("%s: no game has been started, ignoring %s\n", __PRETTY_FUNCTION__, p);
                return -3;
        }
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
        if (col_from < 0 || col_from > 7 || row_from < 0 || row_from > 7 || col_to < 0 || col_to > 7 || row_to < 0 || row_to > 7)
        {
                xil_printf("%s: bad uci move (%s)\n", __PRETTY_FUNCTION__, p);
                return -2;
        }
        switch (p[4])
        {
        case 'Q':
        case 'q':
                promotion = PIECE_QUEN;
                break;
        case 'N':
        case 'n':
                promotion = PIECE_KNIT;
                break;
        case 'B':
        case 'b':
                promotion = PIECE_BISH;
                break;
        case 'R':
        case 'r':
                promotion = PIECE_ROOK;
                break;
        case '\0':
                promotion = EMPTY_POSN;
                break;
        default:
                fprintf(stderr, "%s: problems (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                return -1;
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
                next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_WHITE_SHORT | 1 << CASTLE_WHITE_LONG);
        else if (piece == BLACK_KING)
                next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_BLACK_SHORT | 1 << CASTLE_BLACK_LONG);

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
        else if (piece == BLACK_KING && row_from == 7 && row_to == 7 && col_from == 4 && col_to == 2)
        {
                vchess_place(&next_board, row_from, 0, EMPTY_POSN);
                vchess_place(&next_board, row_from, 1, EMPTY_POSN);
                vchess_place(&next_board, row_from, 3, BLACK_ROOK);
                vchess_place(&next_board, row_from, 2, BLACK_KING);
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
        else if (piece == WHITE_PAWN && vchess_get_piece(previous_board, row_to, col_to) == EMPTY_POSN && col_from != col_to)
        {
                vchess_place(&next_board, row_to, col_to, WHITE_PAWN);
                vchess_place(&next_board, row_from, col_to, EMPTY_POSN);
                next_board.capture = 1;
                next_board.half_move_clock = 0;
        }
        else if (piece == BLACK_PAWN && vchess_get_piece(previous_board, row_to, col_to) == EMPTY_POSN && col_from != col_to)
        {
                vchess_place(&next_board, row_to, col_to, BLACK_PAWN);
                vchess_place(&next_board, row_from, col_to, EMPTY_POSN);
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

        return 0;
}

void
uci_print_game(uint32_t result)
{
        uint32_t i;
        char uci_str[6];
        static const char *result_str[4] = { "1/2-1/2", "1-0", "0-1", "" };

        if (game_moves <= 1)
                return;
        for (i = 1; i < game_moves; ++i)
        {
                vchess_uci_string(&game[i].uci, uci_str);
                printf("%s ", uci_str);
                if (i % 16 == 0)
                        printf("\n");
        }
        if (result >= sizeof(result_str) / sizeof(result_str[0]))
        {
                printf("%s: Bad result value!\n", __PRETTY_FUNCTION__);
                return;
        }
        printf("%s\n", result_str[result]);
}
