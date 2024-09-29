#include <stdint.h>
#include <xil_printf.h>
#include "vchess.h"

static char *sample[] = {
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
	#if 0
        "rnbqkbnr/pppppppp/8/8/8/2N5/PPPPPPPP/R1BQKBNR b KQkq - 1 1",
        "rnbqkbnr/pppp1ppp/4p3/8/8/2N5/PPPPPPPP/R1BQKBNR w KQkq - 0 2",
        "rnbqkbnr/pppp1ppp/4p3/8/8/2N1P3/PPPP1PPP/R1BQKBNR b KQkq - 0 2",
        "r1bqkbnr/pppp1ppp/2n1p3/8/8/2N1P3/PPPP1PPP/R1BQKBNR w KQkq - 1 3",
        "r1bqkbnr/pppp1ppp/2n1p3/1B6/8/2N1P3/PPPP1PPP/R1BQK1NR b KQkq - 2 3",
        "r1bqkbnr/1ppp1ppp/p1n1p3/1B6/8/2N1P3/PPPP1PPP/R1BQK1NR w KQkq - 0 4",
        "r1bqkbnr/1ppp1ppp/p1B1p3/8/8/2N1P3/PPPP1PPP/R1BQK1NR b KQkq - 0 4",
        "r1bqkbnr/1pp2ppp/p1p1p3/8/8/2N1P3/PPPP1PPP/R1BQK1NR w KQkq - 0 5",
        "r1bqkbnr/1pp2ppp/p1p1p3/8/6Q1/2N1P3/PPPP1PPP/R1B1K1NR b KQkq - 1 5",
        "r1bqkb1r/1pp2ppp/p1p1pn2/8/6Q1/2N1P3/PPPP1PPP/R1B1K1NR w KQkq - 2 6",
        "r1bqkb1r/1pp2ppp/p1p1pn2/8/2Q5/2N1P3/PPPP1PPP/R1B1K1NR b KQkq - 3 6",
        "r1b1kb1r/1pp1qppp/p1p1pn2/8/2Q5/2N1P3/PPPP1PPP/R1B1K1NR w KQkq - 4 7",
        "r1b1kb1r/1pp1qppp/p1p1pn2/8/2Q5/2N1PN2/PPPP1PPP/R1B1K2R b KQkq - 5 7",
        "r1b1kb1r/1pp2ppp/p1p1pn2/8/1qQ5/2N1PN2/PPPP1PPP/R1B1K2R w KQkq - 6 8",
        "r1b1kb1r/1pp2ppp/p1p1pn2/8/1qQ5/1PN1PN2/P1PP1PPP/R1B1K2R b KQkq - 0 8",
        "r1b1kb1r/1pp2ppp/p1p1pn2/8/2q5/1PN1PN2/P1PP1PPP/R1B1K2R w KQkq - 0 9",
        "r1b1kb1r/1pp2ppp/p1p1pn2/8/2P5/2N1PN2/P1PP1PPP/R1B1K2R b KQkq - 0 9",
        "r1b1k2r/1pp2ppp/p1p1pn2/8/1bP5/2N1PN2/P1PP1PPP/R1B1K2R w KQkq - 1 10",
        "r1b1k2r/1pp2ppp/p1p1pn2/8/1bP5/2N1PN2/PBPP1PPP/R3K2R b KQkq - 2 10",
        "r1b2rk1/1pp2ppp/p1p1pn2/8/1bP5/2N1PN2/PBPP1PPP/R3K2R w KQ - 3 11",
        "r1b2rk1/1pp2ppp/p1p1pn2/8/1bP5/4PN2/PBPPNPPP/R3K2R b KQ - 4 11",
        "r1b2rk1/1pp2ppp/p1p1p3/8/1bP1n3/4PN2/PBPPNPPP/R3K2R w KQ - 5 12",
        "r1b2rk1/1pp2ppp/p1p1p3/8/1bP1n3/P3PN2/1BPPNPPP/R3K2R b KQ - 0 12",
        "r1b2rk1/1pp1bppp/p1p1p3/8/2P1n3/P3PN2/1BPPNPPP/R3K2R w KQ - 1 13",
        "r1b2rk1/1pp1bppp/p1p1p3/8/2P1n3/P2PPN2/1BP1NPPP/R3K2R b KQ - 0 13",
        "r1b2rk1/1pp1bppp/p1p1p3/6n1/2P5/P2PPN2/1BP1NPPP/R3K2R w KQ - 1 14",
        "r1b2rk1/1pp1bppp/p1p1p3/4B1n1/2P5/P2PPN2/2P1NPPP/R3K2R b KQ - 2 14",
        "r1b2rk1/1pp1bppp/p1p1p3/4B3/2P5/P2PPn2/2P1NPPP/R3K2R w KQ - 0 15",
        "r1b2rk1/1pp1bppp/p1p1p3/4B3/2P5/P2PPP2/2P1NP1P/R3K2R b KQ - 0 15",
        "r1b2rk1/1pp2ppp/p1pbp3/4B3/2P5/P2PPP2/2P1NP1P/R3K2R w KQ - 1 16",
        "r1b2rk1/1pp2ppp/p1pBp3/8/2P5/P2PPP2/2P1NP1P/R3K2R b KQ - 0 16",
        "r1b2rk1/1p3ppp/p1ppp3/8/2P5/P2PPP2/2P1NP1P/R3K2R w KQ - 0 17",
        "r1b2rk1/1p3ppp/p1ppp3/8/2P5/P2PPP2/2P1NP1P/1R2K2R b K - 1 17",
        "r1b2rk1/5ppp/p1ppp3/1p6/2P5/P2PPP2/2P1NP1P/1R2K2R w K b6 0 18",
        "r1b2rk1/5ppp/p1ppp3/1p6/2P5/P2PPP2/2P1NP1P/1R3RK1 b - - 1 18",
        "r1b2rk1/5ppp/p1ppp3/8/2p5/P2PPP2/2P1NP1P/1R3RK1 w - - 0 19",
        "r1b2rk1/5ppp/p1ppp3/8/2P5/P3PP2/2P1NP1P/1R3RK1 b - - 0 19",
        "r1b2rk1/5ppp/p1pp4/4p3/2P5/P3PP2/2P1NP1P/1R3RK1 w - - 0 20",
        "r1b2rk1/5ppp/pRpp4/4p3/2P5/P3PP2/2P1NP1P/5RK1 b - - 1 20",
        "r4rk1/3b1ppp/pRpp4/4p3/2P5/P3PP2/2P1NP1P/5RK1 w - - 2 21",
        "r4rk1/3b1ppp/pRpp4/4p3/2P5/P3PP2/2P1NP1P/3R2K1 b - - 3 21",
        "rr4k1/3b1ppp/pRpp4/4p3/2P5/P3PP2/2P1NP1P/3R2K1 w - - 4 22",
        "rR4k1/3b1ppp/p1pp4/4p3/2P5/P3PP2/2P1NP1P/3R2K1 b - - 0 22",
        "1r4k1/3b1ppp/p1pp4/4p3/2P5/P3PP2/2P1NP1P/3R2K1 w - - 0 23",
        "1r4k1/3b1ppp/p1pR4/4p3/2P5/P3PP2/2P1NP1P/6K1 b - - 0 23",
        "1r4k1/5ppp/p1pR4/4pb2/2P5/P3PP2/2P1NP1P/6K1 w - - 1 24",
        "1r4k1/5ppp/p1pR4/4pb2/2P5/P1P1PP2/4NP1P/6K1 b - - 0 24",
        "1r4k1/5ppp/p2R4/2p1pb2/2P5/P1P1PP2/4NP1P/6K1 w - - 0 25",
        "1r4k1/5ppp/p2R4/2p1pb2/2P5/P1P1PP2/5P1P/2N3K1 b - - 1 25",
        "1r4k1/5p1p/p2R4/2p1pbp1/2P5/P1P1PP2/5P1P/2N3K1 w - g6 0 26",
        "1r4k1/5p1p/p2R4/2p1pbp1/2P1P3/P1P2P2/5P1P/2N3K1 b - - 0 26",
        "1r4k1/5p1p/p2R4/2p1p1p1/2P1P3/P1P2P1b/5P1P/2N3K1 w - - 1 27",
        "1r4k1/5p1p/p2R4/2p1p1p1/2P1PP2/P1P4b/5P1P/2N3K1 b - - 0 27",
        "1r4k1/5p1p/p2R4/2p1p3/2P1Pp2/P1P4b/5P1P/2N3K1 w - - 0 28",
        "1r4k1/5p1p/p2R4/2p1p3/2P1Pp2/P1P4b/5P1P/2N4K b - - 1 28",
        "1r4k1/5p1p/p2R4/2p1p3/2P1Ppb1/P1P5/5P1P/2N4K w - - 2 29",
        "1r4k1/5p1p/p2R4/2p1p3/2P1Ppb1/P1P5/5PKP/2N5 b - - 3 29",
        "6k1/5p1p/p2R4/2p1p3/2P1Ppb1/P1P5/5PKP/1rN5 w - - 4 30",
        "6k1/5p1p/p2R4/2p1p3/2P1Ppb1/P1P2P2/6KP/1rN5 b - - 0 30",
        "6k1/5p1p/p2R4/2p1p3/2P1Pp2/P1P2b2/6KP/1rN5 w - - 0 31",
        "6k1/5p1p/p2R4/2p1p3/2P1Pp2/P1P2K2/7P/1rN5 b - - 0 31",
        "6k1/5p1p/p2R4/2p1p3/2P1Pp2/P1P2K2/7P/2r5 w - - 0 32",
        "6k1/5p1p/p2R4/2p1p3/2P1PpK1/P1P5/7P/2r5 b - - 1 32",
        "6k1/5p1p/p2R4/2p1p3/2P1PpK1/P1r5/7P/8 w - - 0 33",
        "6k1/5p1p/p2R4/2p1pK2/2P1Pp2/P1r5/7P/8 b - - 1 33",
        "6k1/5p1p/p2R4/2p1pK2/2P1Pp2/r7/7P/8 w - - 0 34",
        "6k1/5p1p/p2R4/2p1K3/2P1Pp2/r7/7P/8 b - - 0 34",
        "6k1/5p1p/p2R4/2p1K3/2P1Pp2/7r/7P/8 w - - 1 35",
        "6k1/5p1p/R7/2p1K3/2P1Pp2/7r/7P/8 b - - 0 35",
        "6k1/5p1p/R7/2p1K2r/2P1Pp2/8/7P/8 w - - 1 36",
        "6k1/5p1p/R7/2p4r/2P1PK2/8/7P/8 b - - 0 36",
        "6k1/5p1p/R7/2p5/2P1PK1r/8/7P/8 w - - 1 37",
        "6k1/5p1p/R7/2p5/2P1P2r/5K2/7P/8 b - - 2 37",
        "6k1/5p1p/R7/2p5/2P1P3/5K2/7r/8 w - - 0 38",
        "6k1/5p1p/2R5/2p5/2P1P3/5K2/7r/8 b - - 1 38",
        "6k1/5p1p/2R5/2p5/2P1P3/5K2/2r5/8 w - - 2 39",
        "6k1/5p1p/8/2R5/2P1P3/5K2/2r5/8 b - - 0 39",
        "6k1/5p1p/8/2R5/2P1P3/2r2K2/8/8 w - - 1 40",
        "6k1/5p1p/8/2R5/2P1P3/2r5/4K3/8 b - - 2 40",
        "6k1/5p1p/8/2R5/2P1P3/7r/4K3/8 w - - 3 41",
        "6k1/5p1p/8/2R5/2P1P3/7r/3K4/8 b - - 4 41",
        "6k1/5p1p/8/2R5/2P1P3/8/3K3r/8 w - - 5 42",
        "6k1/5p1p/8/2R5/2P1P3/2K5/7r/8 b - - 6 42",
        "6k1/5p1p/8/2R5/2P1P3/2K5/4r3/8 w - - 7 43",
        "6k1/5p1p/8/2R5/2P1P3/3K4/4r3/8 b - - 8 43",
        "6k1/5p1p/8/2R5/2P1P3/3K4/5r2/8 w - - 9 44",
        "6k1/5p1p/8/2R5/2P1P3/4K3/5r2/8 b - - 10 44",
        "6k1/5p1p/8/2R5/2P1P3/4K3/6r1/8 w - - 11 45",
        "6k1/5p1p/8/2R5/2P1P3/5K2/6r1/8 b - - 12 45",
        "6k1/5p1p/8/2R5/2P1P3/5K2/2r5/8 w - - 13 46",
        "6k1/5p1p/8/2R5/2P1P3/4K3/2r5/8 b - - 14 46",
        "6k1/5p1p/8/2R5/2P1P3/4K3/5r2/8 w - - 15 47",
        "6k1/5p1p/8/2R5/2P1P3/8/5K2/8 b - - 0 47",
	#endif
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
