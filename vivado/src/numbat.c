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
        int32_t eval;
        uint32_t mate, stalemate, fifty_move;
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
                if (y == 7)
                        printf(" %c%c%c%c%c Black", 27, 91, 51, 50, 109);
                else if (y == 0)
                        printf(" %c%c%c%c%c White", 27, 91, 51, 49, 109);
                if (y == 7 || y == 0)
                        printf("%c%c%c%c%c%c", 27, 40, 66, 27, 91, 109);        // sgr0
                printf("\n");
        }
        printf("   %c%c%c%c", 27, 91, 50, 109); // dim
        for (x = 0; x < 8; ++x)
                printf(" %c ", 'a' + x);
        printf("%c%c%c%c%c%c\n", 27, 40, 66, 27, 91, 109);      // sgr0
        if (initial_board)
        {
                eval = numbat_initial_eval();
                numbat_status(0, 0, &mate, &stalemate, 0, &fifty_move, 0, 0);
        }
        else
                eval = board->eval;
        if (!initial_board)
                printf("capture: %d, half move: %d\n", board->capture, board->half_move_clock);
        else
                printf("mate: %d, stalemate: %d, fifty move: %d\n", mate, stalemate, fifty_move);
        uci_string(&board->uci, uci_str);
        printf("eval: %d, uci: %s\n", eval, uci_str);
        if (board->black_in_check)
                printf("Black in check\n");
        if (board->white_in_check)
                printf("White in check\n");
}

void
numbat_write_board_basic(const board_t * board)
{
        numbat_reset_all_moves();
        numbat_write256(8, (void *)&board->board[0]);
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
                numbat_status(0, &moves_ready, 0, 0, 0, 0, 0, 0);
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
        uint32_t status;
        const uint64_t *entry_addr_uint64;
        uint64_t *ptr64;
        uint64_t dma[6];
        uint32_t uci_half_move_val;
        static const uint32_t entry_offset_uint64 = 512 / 64;
        static const uint64_t *dma_base = (void *)XPAR_ALL_MOVES_BRAM_AXI_CTRL_S_AXI_BASEADDR;
        static const uint32_t verify_move_ready = 0;

        entry_addr_uint64 = dma_base + index * entry_offset_uint64;

        if (verify_move_ready)
        {
                status = numbat_status(&move_ready, &moves_ready, 0, 0, 0, 0, 0, 0);
                move_count = numbat_move_count();
                if (!move_ready || !moves_ready || index >= move_count)
                {
                        printf("%s: problems, stopping (%s %d) [%d %d %d 0x%08X]\n", __PRETTY_FUNCTION__, __FILE__, __LINE__, move_ready, moves_ready,
                               index >= move_count, status);
                        while (1);
                }
        }

        memcpy(dma, entry_addr_uint64, sizeof(dma));    // triggers AXI4 burst

        ptr64 = (void *)&board->board[0];       // note: board is correctly aligned, see header

        ptr64[0] = dma[0];
        ptr64[1] = dma[1];
        ptr64[2] = dma[2];
        ptr64[3] = dma[3];

        board->eval = (int32_t) (dma[4] & 0xFFFFFFFFULL);

        uci_half_move_val = dma[4] >> 32;
        board->uci.col_from = (uci_half_move_val >> 0) & 0x7;
        board->uci.row_from = (uci_half_move_val >> 3) & 0x7;
        board->uci.col_to = (uci_half_move_val >> 6) & 0x7;
        board->uci.row_to = (uci_half_move_val >> 9) & 0x7;
        board->uci.promotion = (uci_half_move_val >> 12) & 0xF;
        board->half_move_clock = uci_half_move_val >> 16;

        board->white_to_move = (dma[5] >> 0) & 0x1;
        board->black_in_check = (dma[5] >> 1) & 0x1;
        board->white_in_check = (dma[5] >> 2) & 0x1;
        board->capture = (dma[5] >> 3) & 0x1;
        board->pv = (dma[5] >> 4) & 0x1;
        board->fifty_move = (dma[5] >> 6) & 0x1;

        board->en_passant_col = (dma[5] >> 8) & 0xF;
        board->castle_mask = (dma[5] >> 12) & 0xF;

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
