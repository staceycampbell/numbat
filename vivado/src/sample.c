// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <xil_printf.h>
#include "numbat.h"

// 6k1/3b4/1p1p4/p1n2p2/1PP1p3/P3q1p1/1R1R2P1/3B1KNr b - - 3 10

static char *sample[] = {
        "6k1/3b3r/1p1p4/p1n2p2/1PPNpP1q/P3Q1p1/1R1RB1P1/5K2 b - - 0 1"
};

uint32_t
sample_game(board_t game[GAME_MAX])
{
        uint32_t i;
        uint32_t half_moves = sizeof(sample) / sizeof(sample[0]);

        for (i = 0; i < half_moves; ++i)
                if (fen_board((uint8_t *) sample[i], &game[i]))
                {
                        xil_printf("%s: sample game load error, stopping here\n", __PRETTY_FUNCTION__);
                        return 0;
                }
        xil_printf("%s: loaded %d half moves\n", __PRETTY_FUNCTION__, half_moves);

        return half_moves;
}
