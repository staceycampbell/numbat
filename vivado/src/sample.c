// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <xil_printf.h>
#include "numbat.h"

static char *sample[] = {
	"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
	"rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1",
	"rnbqkb1r/pppppppp/5n2/8/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 1 2",
	"rnbqkb1r/pppppppp/5n2/8/3P4/5N2/PPP1PPPP/RNBQKB1R b KQkq - 2 2",
	"rnbqkb1r/pp1ppppp/5n2/2p5/3P4/5N2/PPP1PPPP/RNBQKB1R w KQkq c6 0 3",
	"rnbqkb1r/pp1ppppp/5n2/2p5/2PP4/5N2/PP2PPPP/RNBQKB1R b KQkq c3 0 3",
	"rnbqkb1r/pp1ppppp/5n2/8/2Pp4/5N2/PP2PPPP/RNBQKB1R w KQkq - 0 4",
	"rnbqkb1r/pp1ppppp/5n2/8/2PN4/8/PP2PPPP/RNBQKB1R b KQkq - 0 4",
	"rnbqkb1r/pp1p1ppp/4pn2/8/2PN4/8/PP2PPPP/RNBQKB1R w KQkq - 0 5",
	"rnbqkb1r/pp1p1ppp/4pn2/8/2PN4/6P1/PP2PP1P/RNBQKB1R b KQkq - 0 5",
	"rnb1kb1r/ppqp1ppp/4pn2/8/2PN4/6P1/PP2PP1P/RNBQKB1R w KQkq - 1 6",
	"rnb1kb1r/ppqp1ppp/4pn2/8/2PN4/6P1/PP1NPP1P/R1BQKB1R b KQkq - 2 6",
	"rnb1k2r/ppqp1ppp/4pn2/8/1bPN4/6P1/PP1NPP1P/R1BQKB1R w KQkq - 3 7",
	"rnb1k2r/ppqp1ppp/4pn2/8/1bPN4/4P1P1/PP1N1P1P/R1BQKB1R b KQkq - 0 7",
	"r1b1k2r/ppqp1ppp/2n1pn2/8/1bPN4/4P1P1/PP1N1P1P/R1BQKB1R w KQkq - 1 8",
	"r1b1k2r/ppqp1ppp/2n1pn2/8/1bPN4/P3P1P1/1P1N1P1P/R1BQKB1R b KQkq - 0 8",
	"r1b1k2r/pp1p1ppp/2n1pn2/q7/1bPN4/P3P1P1/1P1N1P1P/R1BQKB1R w KQkq - 1 9",
	"r1b1k2r/pp1p1ppp/2n1pn2/q7/1bP5/PN2P1P1/1P1N1P1P/R1BQKB1R b KQkq - 2 9",
	"r1b1k2r/pp1p1ppp/2n1pn2/q7/2P5/PN2P1P1/1P1b1P1P/R1BQKB1R w KQkq - 0 10",
	"r1b1k2r/pp1p1ppp/2n1pn2/q7/2P5/PN2P1P1/1P1B1P1P/R2QKB1R b KQkq - 0 10",
	"r1b1k2r/pp1p1ppp/2n1pn2/5q2/2P5/PN2P1P1/1P1B1P1P/R2QKB1R w KQkq - 1 11",
	"r1b1k2r/pp1p1ppp/2n1pn2/5q2/2P2P2/PN2P1P1/1P1B3P/R2QKB1R b KQkq f3 0 11"
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
