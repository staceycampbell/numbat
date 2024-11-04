#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <xil_printf.h>
#include "vchess.h"

#pragma GCC optimize ("O2")

static char piece_char[1 << PIECE_BITS];

uint32_t
vchess_get_piece(board_t * board, uint32_t row, uint32_t col)
{
        uint32_t row_contents, shift, piece;

        row_contents = board->board[row];
        shift = col * PIECE_BITS;
        piece = (row_contents >> shift) & 0xF;

        return piece;
}

void
vchess_place(board_t * board, uint32_t row, uint32_t col, uint32_t piece)
{
        uint32_t row_contents;
        uint32_t shift;

        shift = col * PIECE_BITS;
        row_contents = board->board[row];
        row_contents &= ~(0xF << shift);
        row_contents |= piece << shift;
        board->board[row] = row_contents;
}

uint32_t
vchess_move_piece(board_t * board, uint32_t row_from, uint32_t col_from, uint32_t row_to, uint32_t col_to)
{
        uint32_t piece, occupied;

        piece = vchess_get_piece(board, row_from, col_from);
        occupied = vchess_get_piece(board, row_to, col_to) != EMPTY_POSN;
        vchess_place(board, row_from, col_from, EMPTY_POSN);
        vchess_place(board, row_to, col_to, piece);

        return occupied;
}

void
vchess_read_uci(uci_t * uci)
{
        uint32_t val;

        val = vchess_read(139);
        uci->col_from = (val >> 0) & 0x7;
        uci->row_from = (val >> 4) & 0x7;
        uci->col_to = (val >> 8) & 0x7;
        uci->row_to = (val >> 12) & 0x7;
        uci->promotion = (val >> 16) & 0xF;
}

void
vchess_uci_string(uci_t * uci, char *str)
{
        char ch;
        uint32_t promotion_type;

        str[0] = uci->col_from + 'a';
        str[1] = uci->row_from + '1';
        str[2] = uci->col_to + 'a';
        str[3] = uci->row_to + '1';

        if (uci->promotion != EMPTY_POSN)
        {
                promotion_type = uci->promotion & ~(1 << BLACK_BIT);
                switch (promotion_type)
                {
                case PIECE_QUEN:
                        ch = 'Q';
                        break;
                case PIECE_ROOK:
                        ch = 'R';
                        break;
                case PIECE_BISH:
                        ch = 'B';
                        break;
                case PIECE_KNIT:
                        ch = 'N';
                        break;
                default:
                        ch = '?';
                        break;
                }
                str[4] = ch;
                str[5] = '\0';
        }
        else
                str[4] = '\0';
}

void
vchess_print_board(board_t * board, uint32_t initial_board)
{
        int y, x, rev;
        char uci_str[6];
        uint32_t piece;
        int32_t eval, material;
        uint32_t mate, stalemate, thrice_rep, fifty_move;

        for (y = 7; y >= 0; --y)
        {
                printf("%c%c%c%c %c ", 27, 91, 50, 109, '1' + y);       // dim
                printf("%c%c%c%c%c%c", 27, 40, 66, 27, 91, 109);        // sgr0
                for (x = 0; x < 8; ++x)
                {
                        piece = vchess_get_piece(board, y, x);
                        rev = (y ^ x) & 1;
                        if (rev)
                                printf("%c%c%c%c%c", 27, 91, 52, 55, 109);      // setb 7, light bg
                        else
                                printf("%c%c%c%c%c", 27, 91, 52, 48, 109);      // setb 0, black bg
                        if ((piece & (1 << BLACK_BIT)) != 0)
                                printf("%c%c%c%c%c", 27, 91, 51, 50, 109);      // green
                        else
                                printf("%c%c%c%c%c", 27, 91, 51, 49, 109);      // red
                        printf(" %c ", piece_char[piece]);
                        printf("%c%c%c%c%c%c", 27, 40, 66, 27, 91, 109);        // sgr0
                }
                printf("\n");
        }
        printf("   %c%c%c%c", 27, 91, 50, 109); // dim
        for (x = 0; x < 8; ++x)
                printf(" %c ", 'a' + x);
        printf("%c%c%c%c%c%c\n", 27, 40, 66, 27, 91, 109);      // sgr0
        if (initial_board)
        {
                eval = vchess_initial_eval();
                vchess_status(0, 0, &mate, &stalemate, &thrice_rep, 0, &fifty_move);
                material = vchess_initial_material();
        }
        else
        {
                eval = board->eval;
                material = 0;
        }
        if (!initial_board)
                printf("capture: %d, thrice rep: %d, half move: %d", board->capture, board->thrice_rep, board->half_move_clock);
        else
        {
                printf("mate: %d, stalemate: %d, thrice rep: %d, fifty move: %d\n", mate, stalemate, thrice_rep, fifty_move);
                printf("material: %.2f", (double)material / 100.0);
        }
        vchess_uci_string(&board->uci, uci_str);
        printf(", eval: %d, uci: %s\n", eval, uci_str);
        if (board->black_in_check)
                printf("Black in check\n");
        if (board->white_in_check)
                printf("White in check\n");
}

void
vchess_write_board_basic(const board_t * board)
{
        vchess_reset_all_moves();
	vchess_write_board_row(0, board->board[0]);
	vchess_write_board_row(1, board->board[1]);
	vchess_write_board_row(2, board->board[2]);
	vchess_write_board_row(3, board->board[3]);
	vchess_write_board_row(4, board->board[4]);
	vchess_write_board_row(5, board->board[5]);
	vchess_write_board_row(6, board->board[6]);
	vchess_write_board_row(7, board->board[7]);
        vchess_write_board_misc(board->white_to_move, board->castle_mask, board->en_passant_col);
        vchess_write_half_move(board->half_move_clock);
}

void
vchess_write_board_wait(board_t * board)
{
        int32_t i;
        uint32_t moves_ready, move_count;

        vchess_write_control(0, 1, 0, 0);       // new board valid bit set
        vchess_write_control(0, 0, 0, 0);       // new board valid bit clear
        i = 0;
        do
        {
                vchess_status(0, &moves_ready, 0, 0, 0, 0, 0);
                ++i;
        }
        while (i < 5000 && !moves_ready);
        if (!moves_ready)
                xil_printf("%s: timeout! (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
        move_count = vchess_move_count();
        if (move_count >= 218)
        {
                if (board)
                {
                        vchess_print_board(board, 1);
                        fen_print(board);
                }
                xil_printf("%s: stopping here, %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                while (1);
        }
}

uint32_t
vchess_read_board(board_t * board, uint32_t index)
{
        uint32_t move_count;
        uint32_t move_ready, moves_ready;
        uint32_t y;
        uint32_t status;

        move_count = vchess_move_count();
        if (move_count >= MAX_POSITIONS)
        {
                xil_printf("%s: stopping here, %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                while (1);
        }
        status = vchess_status(&move_ready, &moves_ready, 0, 0, 0, 0, 0);
        if (!moves_ready)
        {
                xil_printf("moves_ready not set\n");
                return 2;
        }
        if (index >= move_count)
        {
                xil_printf("bad index %d, move count is %d\n", index, move_count);
                return 1;
        }
        vchess_move_index(index);
        status = vchess_status(&move_ready, 0, 0, 0, 0, 0, 0);
        if (!move_ready)
        {
                xil_printf("move_ready not set: 0x%X\n", status);
                return 3;
        }

        for (y = 0; y < 8; ++y)
                board->board[y] = vchess_read_move_row(y);
        vchess_board_status0(&board->black_in_check, &board->white_in_check, &board->capture, &board->thrice_rep, &board->fifty_move);
        vchess_board_status1(&board->white_to_move, &board->castle_mask, &board->en_passant_col);
        board->eval = vchess_move_eval();
        board->half_move_clock = vchess_read_half_move();
        vchess_read_uci(&board->uci);

        return 0;
}

void
vchess_init_board(board_t * board)
{
        int i, j;

        for (i = 2; i <= 5; ++i)
                for (j = 0; j < 8; ++j)
                        vchess_place(board, i, j, EMPTY_POSN);
        for (j = 0; j < 8; ++j)
        {
                vchess_place(board, 1, j, WHITE_PAWN);
                vchess_place(board, 6, j, BLACK_PAWN);
        }
        vchess_place(board, 0, 0, WHITE_ROOK);
        vchess_place(board, 0, 1, WHITE_KNIT);
        vchess_place(board, 0, 2, WHITE_BISH);
        vchess_place(board, 0, 3, WHITE_QUEN);
        vchess_place(board, 0, 4, WHITE_KING);
        vchess_place(board, 0, 5, WHITE_BISH);
        vchess_place(board, 0, 6, WHITE_KNIT);
        vchess_place(board, 0, 7, WHITE_ROOK);

        vchess_place(board, 7, 0, BLACK_ROOK);
        vchess_place(board, 7, 1, BLACK_KNIT);
        vchess_place(board, 7, 2, BLACK_BISH);
        vchess_place(board, 7, 3, BLACK_QUEN);
        vchess_place(board, 7, 4, BLACK_KING);
        vchess_place(board, 7, 5, BLACK_BISH);
        vchess_place(board, 7, 6, BLACK_KNIT);
        vchess_place(board, 7, 7, BLACK_ROOK);

        board->en_passant_col = 0 << EN_PASSANT_VALID_BIT;
        board->castle_mask = 0xF;
        board->white_to_move = 1;
}

void
vchess_repdet_entry(uint32_t index, uint32_t board[8], uint32_t castle_mask)
{
        vchess_repdet_board(board);
        vchess_repdet_castle_mask(castle_mask);
        vchess_repdet_write(index);
}

void
vchess_init(void)
{
        int i;

        for (i = 0; i < (1 << PIECE_BITS); ++i)
                piece_char[i] = '?';
        piece_char[EMPTY_POSN] = ' ';
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
}
