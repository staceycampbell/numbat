// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <stdio.h>
#include <stdint.h>
#include <assert.h>

#define EXCLUDE_VITIS 1
#include "vivado/src/vchess.h"

#define ATTACK_COUNT 75
#define EMPTY_POSN2 (1 << EMPTY_POSN)

int
main(void)
{
        int row, col, idx, i, j, color, fi, fj, f;
        uint16_t attack_array[ATTACK_COUNT][8][8];
        uint16_t attack_rook[2];
        uint16_t attack_knit[2];
        uint16_t attack_bish[2];
        uint16_t attack_quen[2];
        uint16_t attack_king[2];
        uint16_t attack_pawn[2];
        char *attacker[2];

        attacker[WHITE_ATTACK] = "`WHITE_ATTACK";
        attack_rook[WHITE_ATTACK] = 1 << WHITE_ROOK;
        attack_knit[WHITE_ATTACK] = 1 << WHITE_KNIT;
        attack_bish[WHITE_ATTACK] = 1 << WHITE_BISH;
        attack_quen[WHITE_ATTACK] = 1 << WHITE_QUEN;
        attack_king[WHITE_ATTACK] = 1 << WHITE_KING;
        attack_pawn[WHITE_ATTACK] = 1 << WHITE_PAWN;

        attacker[BLACK_ATTACK] = "`BLACK_ATTACK";
        attack_rook[BLACK_ATTACK] = 1 << BLACK_ROOK;
        attack_knit[BLACK_ATTACK] = 1 << BLACK_KNIT;
        attack_bish[BLACK_ATTACK] = 1 << BLACK_BISH;
        attack_quen[BLACK_ATTACK] = 1 << BLACK_QUEN;
        attack_king[BLACK_ATTACK] = 1 << BLACK_KING;
        attack_pawn[BLACK_ATTACK] = 1 << BLACK_PAWN;

        for (color = 0; color <= 1; ++color)
                for (row = 0; row < 8; ++row)
                        for (col = 0; col < 8; ++col)
                        {
                                for (idx = 0; idx < ATTACK_COUNT; ++idx)
                                        for (fi = 0; fi < 8; ++fi)
                                                for (fj = 0; fj < 8; ++fj)
                                                        attack_array[idx][fi][fj] = 0; // default is "don't care"
                                idx = 0;
                                // rook horizontal
                                for (j = col - 1; j >= 0; j = j - 1)
                                {
                                        attack_array[idx][row][j] = attack_rook[color];
                                        for (f = j + 1; f < col; f = f + 1)
                                                attack_array[idx][row][f] = EMPTY_POSN2;
                                        idx = idx + 1;
                                }
                                for (j = col + 1; j < 8; j = j + 1)
                                {
                                        attack_array[idx][row][j] = attack_rook[color];
                                        for (f = j - 1; f > col; f = f - 1)
                                                attack_array[idx][row][f] = EMPTY_POSN2;
                                        idx = idx + 1;
                                }
                                // rook vertical
                                for (i = row - 1; i >= 0; i = i - 1)
                                {
                                        attack_array[idx][i][col] = attack_rook[color];
                                        for (f = i + 1; f < row; f = f + 1)
                                                attack_array[idx][f][col] = EMPTY_POSN2;
                                        idx = idx + 1;
                                }
                                for (i = row + 1; i < 8; i = i + 1)
                                {
                                        attack_array[idx][i][col] = attack_rook[color];
                                        for (f = i - 1; f > row; f = f - 1)
                                                attack_array[idx][f][col] = EMPTY_POSN2;
                                        idx = idx + 1;
                                }
                                // queen horizontal
                                for (j = col - 1; j >= 0; j = j - 1)
                                {
                                        attack_array[idx][row][j] = attack_quen[color];
                                        for (f = j + 1; f < col; f = f + 1)
                                                attack_array[idx][row][f] = EMPTY_POSN2;
                                        idx = idx + 1;
                                }
                                for (j = col + 1; j < 8; j = j + 1)
                                {
                                        attack_array[idx][row][j] = attack_quen[color];
                                        for (f = j - 1; f > col; f = f - 1)
                                                attack_array[idx][row][f] = EMPTY_POSN2;
                                        idx = idx + 1;
                                }
                                // queen vertical
                                for (i = row - 1; i >= 0; i = i - 1)
                                {
                                        attack_array[idx][i][col] = attack_quen[color];
                                        for (f = i + 1; f < row; f = f + 1)
                                                attack_array[idx][f][col] = EMPTY_POSN2;
                                        idx = idx + 1;
                                }
                                for (i = row + 1; i < 8; i = i + 1)
                                {
                                        attack_array[idx][i][col] = attack_quen[color];
                                        for (f = i - 1; f > row; f = f - 1)
                                                attack_array[idx][f][col] = EMPTY_POSN2;
                                        idx = idx + 1;
                                }
                                // bishop, diag 0
                                i = row - 1;
                                j = col - 1;
                                while (i >= 0 && j >= 0)
                                {
                                        attack_array[idx][i][j] = attack_bish[color];
                                        fi = i + 1;
                                        fj = j + 1;
                                        while (fi < row && fj < col)
                                        {
                                                attack_array[idx][fi][fj] = EMPTY_POSN2;
                                                fi = fi + 1;
                                                fj = fj + 1;
                                        }
                                        idx = idx + 1;
                                        i = i - 1;
                                        j = j - 1;
                                }
                                // bishop, diag 1
                                i = row + 1;
                                j = col + 1;
                                while (i < 8 && j < 8)
                                {
                                        attack_array[idx][i][j] = attack_bish[color];
                                        fi = i - 1;
                                        fj = j - 1;
                                        while (fi > row && fj > col)
                                        {
                                                attack_array[idx][fi][fj] = EMPTY_POSN2;
                                                fi = fi - 1;
                                                fj = fj - 1;
                                        }
                                        idx = idx + 1;
                                        i = i + 1;
                                        j = j + 1;
                                }
                                // bishop, diag 2
                                i = row - 1;
                                j = col + 1;
                                while (i >= 0 && j < 8)
                                {
                                        attack_array[idx][i][j] = attack_bish[color];
                                        fi = i + 1;
                                        fj = j - 1;
                                        while (fi < row && fj > col)
                                        {
                                                attack_array[idx][fi][fj] = EMPTY_POSN2;
                                                fi = fi + 1;
                                                fj = fj - 1;
                                        }
                                        idx = idx + 1;
                                        i = i - 1;
                                        j = j + 1;
                                }
                                // bishop, diag 3
                                i = row + 1;
                                j = col - 1;
                                while (i < 8 && j >= 0)
                                {
                                        attack_array[idx][i][j] = attack_bish[color];
                                        fi = i - 1;
                                        fj = j + 1;
                                        while (fi > row && fj < col)
                                        {
                                                attack_array[idx][fi][fj] = EMPTY_POSN2;
                                                fi = fi - 1;
                                                fj = fj + 1;
                                        }
                                        idx = idx + 1;
                                        i = i + 1;
                                        j = j - 1;
                                }
                                // queen, diag 0
                                i = row - 1;
                                j = col - 1;
                                while (i >= 0 && j >= 0)
                                {
                                        attack_array[idx][i][j] = attack_quen[color];
                                        fi = i + 1;
                                        fj = j + 1;
                                        while (fi < row && fj < col)
                                        {
                                                attack_array[idx][fi][fj] = EMPTY_POSN2;
                                                fi = fi + 1;
                                                fj = fj + 1;
                                        }
                                        idx = idx + 1;
                                        i = i - 1;
                                        j = j - 1;
                                }
                                // queen, diag 1
                                i = row + 1;
                                j = col + 1;
                                while (i < 8 && j < 8)
                                {
                                        attack_array[idx][i][j] = attack_quen[color];
                                        fi = i - 1;
                                        fj = j - 1;
                                        while (fi > row && fj > col)
                                        {
                                                attack_array[idx][fi][fj] = EMPTY_POSN2;
                                                fi = fi - 1;
                                                fj = fj - 1;
                                        }
                                        idx = idx + 1;
                                        i = i + 1;
                                        j = j + 1;
                                }
                                // queen, diag 2
                                i = row - 1;
                                j = col + 1;
                                while (i >= 0 && j < 8)
                                {
                                        attack_array[idx][i][j] = attack_quen[color];
                                        fi = i + 1;
                                        fj = j - 1;
                                        while (fi < row && fj > col)
                                        {
                                                attack_array[idx][fi][fj] = EMPTY_POSN2;
                                                fi = fi + 1;
                                                fj = fj - 1;
                                        }
                                        idx = idx + 1;
                                        i = i - 1;
                                        j = j + 1;
                                }
                                // queen, diag 3
                                i = row + 1;
                                j = col - 1;
                                while (i < 8 && j >= 0)
                                {
                                        attack_array[idx][i][j] = attack_quen[color];
                                        fi = i - 1;
                                        fj = j + 1;
                                        while (fi > row && fj < col)
                                        {
                                                attack_array[idx][fi][fj] = EMPTY_POSN2;
                                                fi = fi - 1;
                                                fj = fj + 1;
                                        }
                                        idx = idx + 1;
                                        i = i + 1;
                                        j = j - 1;
                                }
                                // knight
                                for (i = 0; i < 8; i = i + 1)
                                {
                                        switch (i) // coded like this for vivado :-(
                                        {
                                        case 0 :
                                                fj = col + -2;
                                                fi = row + -1;
                                                break;
                                        case 1 :
                                                fj = col + -1;
                                                fi = row + -2;
                                                break;
                                        case 2 :
                                                fj = col +  1;
                                                fi = row + -2;
                                                break;
                                        case 3 :
                                                fj = col +  2;
                                                fi = row + -1;
                                                break;
                                        case 4 :
                                                fj = col +  2;
                                                fi = row +  1;
                                                break;
                                        case 5 :
                                                fj = col +  1;
                                                fi = row +  2;
                                                break;
                                        case 6 :
                                                fj = col + -1;
                                                fi = row +  2;
                                                break;
                                        case 7 :
                                                fj = col + -2;
                                                fi = row +  1;
                                                break;
                                        }

                                        if (fi >= 0 && fi < 8 && fj >= 0 && fj < 8)
                                        {
                                                attack_array[idx][fi][fj] = attack_knit[color];
                                                idx = idx + 1;
                                        }
                                }
                                // king
                                for (fi = row - 1; fi <= row + 1; fi = fi + 1)
                                        for (fj = col - 1; fj <= col + 1; fj = fj + 1)
                                                if (fi >= 0 && fi < 8 && fj >= 0 && fj < 8)
                                                        if (! (fi == row && fj == col))
                                                        {
                                                                attack_array[idx][fi][fj] = attack_king[color];
                                                                idx = idx + 1;
                                                        }
                                // pawn
                                if (color == WHITE_ATTACK)
                                        fi = row - 1;
                                else
                                        fi = row + 1;
                                if (fi >= 0 && fi < 8)
                                {
                                        fj = col - 1;
                                        if (fj >= 0)
                                        {
                                                attack_array[idx][fi][fj] = attack_pawn[color];
                                                idx = idx + 1;
                                        }
                                        fj = col + 1;
                                        if (fj < 8)
                                        {
                                                attack_array[idx][fi][fj] = attack_pawn[color];
                                                idx = idx + 1;
                                        }
                                }
                                assert(idx < ATTACK_COUNT);
                                printf("if (ATTACKER == %s && ROW == %d && COL == %d)\nbegin\n", attacker[color], row, col);
                                for (idx = 0; idx < ATTACK_COUNT; ++idx)
                                {
                                        printf("attack_mask[%2d] = {\n", idx);
                                        for (fi = 7; fi >= 0; --fi)
                                                for (fj = 7; fj >= 0; --fj)
                                                {
                                                        printf("%d'h%04X", PIECE_MASK_BITS, attack_array[idx][fi][fj]);
                                                        if (fi == 0 && fj == 0)
                                                                printf("\n");
                                                        else
                                                                printf(", ");
                                                }
                                        printf("};\n");
                                }
                                printf("end\n");
                        }
        return 0;
}
