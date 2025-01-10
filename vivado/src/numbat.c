// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <xil_printf.h>
#include "numbat.h"

#pragma GCC optimize ("O2")

static char piece_char[1 << PIECE_BITS];

uint32_t
numbat_get_piece(const board_t * board, uint32_t row, uint32_t col)
{
        uint32_t row_contents, shift, piece;

        row_contents = board->board[row];
        shift = col * PIECE_BITS;
        piece = (row_contents >> shift) & 0xF;

        return piece;
}

void
numbat_place(board_t * board, uint32_t row, uint32_t col, uint32_t piece)
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
numbat_move_piece(board_t * board, uint32_t row_from, uint32_t col_from, uint32_t row_to, uint32_t col_to)
{
        uint32_t piece, occupied;

        piece = numbat_get_piece(board, row_from, col_from);
        occupied = numbat_get_piece(board, row_to, col_to) != EMPTY_POSN;
        numbat_place(board, row_from, col_from, EMPTY_POSN);
        numbat_place(board, row_to, col_to, piece);

        return occupied;
}

void
numbat_read_uci(uci_t * uci)
{
        uint32_t val;

        val = numbat_read(139);
        uci->col_from = (val >> 0) & 0x7;
        uci->row_from = (val >> 4) & 0x7;
        uci->col_to = (val >> 8) & 0x7;
        uci->row_to = (val >> 12) & 0x7;
        uci->promotion = (val >> 16) & 0xF;
}

void
numbat_print_board(const board_t * board, uint32_t initial_board)
{
        int y, x, rev;
        char uci_str[6];
        uint32_t piece;
        int32_t eval, material_black, material_white, material;
        uint32_t mate, stalemate, thrice_rep, fifty_move;
        uint32_t btm;

        btm = board->white_to_move;     // move from board to display is inverse of next to move
        for (y = 7; y >= 0; --y)
        {
                printf("%c%c%c%c %c ", 27, 91, 50, 109, '1' + y);       // dim
                printf("%c%c%c%c%c%c", 27, 40, 66, 27, 91, 109);        // sgr0
                for (x = 0; x < 8; ++x)
                {
                        piece = numbat_get_piece(board, y, x);
                        rev = (y ^ x) & 1;
                        if (rev)
                                printf("%c%c%c%c%c", 27, 91, 52, 55, 109);      // setb 7, light bg
                        else
                                printf("%c%c%c%c%c", 27, 91, 52, 48, 109);      // setb 0, black bg
                        if ((piece & (1 << BLACK_BIT)) != 0 || (btm && y == board->uci.row_from && x == board->uci.col_from))
                                printf("%c%c%c%c%c", 27, 91, 51, 50, 109);      // green
                        else
                                printf("%c%c%c%c%c", 27, 91, 51, 49, 109);      // red
                        if ((y == board->uci.row_to && x == board->uci.col_to) || (y == board->uci.row_from && x == board->uci.col_from))
                                printf("%c%c%c%c", 27, 91, 49, 109);    // bold
                        if (y == board->uci.row_from && x == board->uci.col_from)
                                printf(" . ");
                        else
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
                eval = numbat_initial_eval();
                numbat_status(0, 0, &mate, &stalemate, &thrice_rep, 0, &fifty_move, 0, 0);
                material_white = numbat_initial_material_white();
                material_black = numbat_initial_material_black();
                material = material_white - material_black;
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
                printf("material: %.2f - %.2f = %.2f", (double)material_white / 100.0, (double)material_black / 100, (double)material / 100.0);
        }
        uci_string(&board->uci, uci_str);
        printf(", eval: %d, uci: %s\n", eval, uci_str);
        if (board->black_in_check)
                printf("Black in check\n");
        if (board->white_in_check)
                printf("White in check\n");
}

void
numbat_write_board_basic(const board_t * board)
{
        numbat_reset_all_moves();
        numbat_write_board_two_rows(0, board->board[0], board->board[1]);
        numbat_write_board_two_rows(2, board->board[2], board->board[3]);
        numbat_write_board_two_rows(4, board->board[4], board->board[5]);
        numbat_write_board_two_rows(6, board->board[6], board->board[7]);
        numbat_write_board_misc(board->white_to_move, board->castle_mask, board->en_passant_col);
        numbat_write_half_move(board->half_move_clock);
}

void
numbat_write_board_wait(const board_t * board, uint32_t quiescence)
{
        int32_t i;
        uint32_t moves_ready, move_count;

        numbat_quiescence_moves(quiescence);
        numbat_write_control(0, 1, 0, 0);       // new board valid bit set
        numbat_write_control(0, 0, 0, 0);       // new board valid bit clear
        i = 0;
        do
        {
                numbat_status(0, &moves_ready, 0, 0, 0, 0, 0, 0, 0);
                ++i;
        }
        while (i < 5000 && !moves_ready);
        if (!moves_ready)
                xil_printf("%s: timeout! (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
        move_count = numbat_move_count();
        if (move_count >= MAX_POSITIONS)
        {
                if (board)
                {
                        numbat_print_board(board, 1);
                        fen_print(board);
                }
                xil_printf("%s: stopping here, %s %d\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                while (1);
        }
}

uint32_t
numbat_read_board(board_t * board, uint32_t index)
{
        uint32_t move_count;
        uint32_t move_ready, moves_ready;
        uint32_t y;
        uint32_t status;
        uint64_t *ptr;
        static const uint32_t verify_move_ready = 0;

        // assume moves_ready is tested elsewhere and move_ready is always set due to Zynq to PL latency
        numbat_move_index(index);
        if (verify_move_ready)
        {
                status = numbat_status(&move_ready, &moves_ready, 0, 0, 0, 0, 0, 0, 0);
                move_count = numbat_move_count();
                if (!move_ready || !moves_ready || index >= move_count)
                {
                        printf("%s: problems, stopping (%s %d) [%d %d %d 0x%08X]\n", __PRETTY_FUNCTION__, __FILE__, __LINE__, move_ready, moves_ready,
                               index >= move_count, status);
                        while (1);
                }
        }

        for (y = 0; y < 8; y += 2)
        {
                ptr = (uint64_t *) (void *)&board->board[y];
                *ptr = numbat_read_move_two_rows(y);    // rewrite if alignment problems :-)
        }
        numbat_board_status0(&board->black_in_check, &board->white_in_check, &board->capture, &board->thrice_rep, &board->fifty_move, &board->pv);
        numbat_board_status1(&board->white_to_move, &board->castle_mask, &board->en_passant_col);
        board->eval = numbat_move_eval();
        board->half_move_clock = numbat_read_half_move();
        numbat_read_uci(&board->uci);

        return 0;
}

void
numbat_init_board(board_t * board)
{
        int i, j;

        for (i = 2; i <= 5; ++i)
                for (j = 0; j < 8; ++j)
                        numbat_place(board, i, j, EMPTY_POSN);
        for (j = 0; j < 8; ++j)
        {
                numbat_place(board, 1, j, WHITE_PAWN);
                numbat_place(board, 6, j, BLACK_PAWN);
        }
        numbat_place(board, 0, 0, WHITE_ROOK);
        numbat_place(board, 0, 1, WHITE_KNIT);
        numbat_place(board, 0, 2, WHITE_BISH);
        numbat_place(board, 0, 3, WHITE_QUEN);
        numbat_place(board, 0, 4, WHITE_KING);
        numbat_place(board, 0, 5, WHITE_BISH);
        numbat_place(board, 0, 6, WHITE_KNIT);
        numbat_place(board, 0, 7, WHITE_ROOK);

        numbat_place(board, 7, 0, BLACK_ROOK);
        numbat_place(board, 7, 1, BLACK_KNIT);
        numbat_place(board, 7, 2, BLACK_BISH);
        numbat_place(board, 7, 3, BLACK_QUEN);
        numbat_place(board, 7, 4, BLACK_KING);
        numbat_place(board, 7, 5, BLACK_BISH);
        numbat_place(board, 7, 6, BLACK_KNIT);
        numbat_place(board, 7, 7, BLACK_ROOK);

        board->en_passant_col = 0 << EN_PASSANT_VALID_BIT;
        board->castle_mask = 0xF;
        board->white_to_move = 1;
}

void
numbat_repdet_entry(uint32_t index, const uint32_t board[8], uint32_t castle_mask)
{
        numbat_repdet_board(board);
        numbat_repdet_castle_mask(castle_mask);
        numbat_repdet_write(index);
}

void
numbat_init(void)
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
