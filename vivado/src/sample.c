#include <stdint.h>
#include <xil_printf.h>
#include "vchess.h"

static char *sample[] = {
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        "rnbqkbnr/pppppppp/8/8/8/2N5/PPPPPPPP/R1BQKBNR b KQkq - 1 1",
        "rnbqkbnr/pppp1ppp/8/4p3/8/2N5/PPPPPPPP/R1BQKBNR w KQkq e6 0 2",
        "rnbqkbnr/pppp1ppp/8/4p3/4P3/2N5/PPPP1PPP/R1BQKBNR b KQkq e3 0 2",
        "rnbqkb1r/pppp1ppp/5n2/4p3/4P3/2N5/PPPP1PPP/R1BQKBNR w KQkq - 1 3",
        "rnbqkb1r/pppp1ppp/5n2/4p3/2B1P3/2N5/PPPP1PPP/R1BQK1NR b KQkq - 2 3",
        "rnbqk2r/pppp1ppp/5n2/2b1p3/2B1P3/2N5/PPPP1PPP/R1BQK1NR w KQkq - 3 4",
        "rnbqk2r/pppp1ppp/5n2/2b1p3/2B1PP2/2N5/PPPP2PP/R1BQK1NR b KQkq f3 0 4",
        "rnbqk2r/ppp2ppp/5n2/2bpp3/2B1PP2/2N5/PPPP2PP/R1BQK1NR w KQkq d6 0 5",
        "rnbqk2r/ppp2ppp/5n2/2bPp3/2B2P2/2N5/PPPP2PP/R1BQK1NR b KQkq - 0 5",
        "rnbqk2r/ppp2ppp/5n2/2bP4/2B1pP2/2N5/PPPP2PP/R1BQK1NR w KQkq - 0 6",
        "rnbqk2r/ppp2ppp/5n2/2bP4/2B1pP2/2N5/PPPPN1PP/R1BQK2R b KQkq - 1 6",
        "rnbq1rk1/ppp2ppp/5n2/2bP4/2B1pP2/2N5/PPPPN1PP/R1BQK2R w KQ - 2 7",
	#if 0
        "rnbq1rk1/ppp2ppp/5n2/2bP4/2B1pP2/2N4P/PPPPN1P1/R1BQK2R b KQ - 0 7",
        "rnbq1rk1/ppp2ppp/8/2bn4/2B1pP2/2N4P/PPPPN1P1/R1BQK2R w KQ - 0 8",
        "rnbq1rk1/ppp2ppp/8/2bB4/4pP2/2N4P/PPPPN1P1/R1BQK2R b KQ - 0 8",
        "rnbq1rk1/pp3ppp/2p5/2bB4/4pP2/2N4P/PPPPN1P1/R1BQK2R w KQ - 0 9",
        "rnbq1rk1/pp3ppp/2p5/2b5/4BP2/2N4P/PPPPN1P1/R1BQK2R b KQ - 0 9",
        "rnb2rk1/pp3ppp/2p5/2b5/4BP1q/2N4P/PPPPN1P1/R1BQK2R w KQ - 1 10",
        "rnb2rk1/pp3ppp/2p5/2b5/4BP1q/2N3PP/PPPPN3/R1BQK2R b KQ - 0 10",
        "rnb2rk1/pp2qppp/2p5/2b5/4BP2/2N3PP/PPPPN3/R1BQK2R w KQ - 1 11",
        "rnb2rk1/pp2qppp/2p5/2b5/3PBP2/2N3PP/PPP1N3/R1BQK2R b KQ d3 0 11",
        "rnb2rk1/pp3ppp/2p5/2b5/3PqP2/2N3PP/PPP1N3/R1BQK2R w KQ - 0 12",
        "rnb2rk1/pp3ppp/2p5/2b5/3PNP2/6PP/PPP1N3/R1BQK2R b KQ - 0 12",
        "rnb2rk1/pp3ppp/2p5/8/1b1PNP2/6PP/PPP1N3/R1BQK2R w KQ - 1 13",
        "rnb2rk1/pp3ppp/2p5/8/1b1PNP2/2P3PP/PP2N3/R1BQK2R b KQ - 0 13",
        "rnb1r1k1/pp3ppp/2p5/8/1b1PNP2/2P3PP/PP2N3/R1BQK2R w KQ - 1 14",
        "rnb1r1k1/pp3ppp/2p5/8/1P1PNP2/6PP/PP2N3/R1BQK2R b KQ - 0 14",
        "rnb3k1/pp3ppp/2p5/8/1P1PrP2/6PP/PP2N3/R1BQK2R w KQ - 0 15",
        "rnb3k1/pp3ppp/2p5/8/1P1PrPP1/7P/PP2N3/R1BQK2R b KQ - 0 15",
        "rn4k1/pp3ppp/2p5/8/1P1PrPb1/7P/PP2N3/R1BQK2R w KQ - 0 16",
        "rn4k1/pp3ppp/2p5/8/1P1PrPP1/8/PP2N3/R1BQK2R b KQ - 0 16",
        "r5k1/pp3ppp/n1p5/8/1P1PrPP1/8/PP2N3/R1BQK2R w KQ - 1 17",
        "r5k1/pp3ppp/n1p5/1P6/3PrPP1/8/PP2N3/R1BQK2R b KQ - 0 17",
        "r5k1/pp3ppp/n7/1p6/3PrPP1/8/PP2N3/R1BQK2R w KQ - 0 18",
        "r5k1/pp3ppp/n7/1p6/3PrPP1/3Q4/PP2N3/R1B1K2R b KQ - 1 18",
        "4r1k1/pp3ppp/n7/1p6/3PrPP1/3Q4/PP2N3/R1B1K2R w KQ - 2 19",
        "4r1k1/pp3ppp/n7/1p6/3PrPP1/3Q4/PP2N2R/R1B1K3 b Q - 3 19",
        "4r1k1/pp3p1p/n5p1/1p6/3PrPP1/3Q4/PP2N2R/R1B1K3 w Q - 0 20",
        "4r1k1/pp3p1p/n5p1/1p6/3PrPP1/3Q4/PP2N2R/R1B2K2 b - - 1 20",
        "4r1k1/ppn2p1p/6p1/1p6/3PrPP1/3Q4/PP2N2R/R1B2K2 w - - 2 21",
        "4r1k1/ppn2p1p/6p1/1p6/3PrPP1/7Q/PP2N2R/R1B2K2 b - - 3 21",
        "4rk2/ppn2p1p/6p1/1p6/3PrPP1/7Q/PP2N2R/R1B2K2 w - - 4 22",
        "4rk2/ppn2p1Q/6p1/1p6/3PrPP1/8/PP2N2R/R1B2K2 b - - 0 22",
        "4rk2/pp3p1Q/6p1/1p1n4/3PrPP1/8/PP2N2R/R1B2K2 w - - 1 23",
        "4rk2/pp3p1Q/6p1/1p1n4/3PrPP1/8/PP2N2R/R1B3K1 b - - 2 23",
        "4rk2/pp3p1Q/5np1/1p6/3PrPP1/8/PP2N2R/R1B3K1 w - - 3 24",
        "4rk2/pp3p2/5np1/1p6/3PrPP1/7Q/PP2N2R/R1B3K1 b - - 4 24",
        "4rk2/pp3p2/6p1/1p6/3PrPn1/7Q/PP2N2R/R1B3K1 w - - 0 25",
        "4rk2/pp3p2/6p1/1p6/3PrPn1/7Q/PP1BN2R/R5K1 b - - 1 25",
        "4rk2/pp3p2/6p1/1p6/3PrP2/7Q/PP1BN2n/R5K1 w - - 0 26",
        "4rk1Q/pp3p2/6p1/1p6/3PrP2/8/PP1BN2n/R5K1 b - - 1 26",
        "4r2Q/pp2kp2/6p1/1p6/3PrP2/8/PP1BN2n/R5K1 w - - 2 27",
        "4r3/pp2kp2/6p1/1p6/3PrP2/8/PP1BN2Q/R5K1 b - - 0 27",
        "4r3/pp3p2/5kp1/1p6/3PrP2/8/PP1BN2Q/R5K1 w - - 1 28",
        "4r3/pp3p2/5kp1/1p1P4/4rP2/8/PP1BN2Q/R5K1 b - - 0 28",
        "4r3/pp3p2/5kp1/1p1P4/5P2/8/PP1Br2Q/R5K1 w - - 0 29",
        "4r3/pp3p2/5kp1/1p1P4/5P1Q/8/PP1Br3/R5K1 b - - 1 29",
        "4r3/pp3p2/6p1/1p1P1k2/5P1Q/8/PP1Br3/R5K1 w - - 2 30",
        "4r3/pp3p2/6p1/1p1P1k2/5P2/7Q/PP1Br3/R5K1 b - - 3 30",
        "4r3/pp3p2/6p1/1p1P4/4kP2/7Q/PP1Br3/R5K1 w - - 4 31",
        "4r3/pp3p2/6p1/Bp1P4/4kP2/7Q/PP2r3/R5K1 b - - 5 31",
        "4r3/pp3p2/6p1/Bp1P4/4kP2/4r2Q/PP6/R5K1 w - - 6 32",
        "4r3/pp3p2/6p1/Bp1P4/4kP2/4r3/PP4Q1/R5K1 b - - 7 32",
        "4r3/pp3p2/6p1/Bp1P4/3k1P2/4r3/PP4Q1/R5K1 w - - 8 33",
        "4r3/pp3p2/6p1/Bp1P4/3k1P2/4r3/PP4Q1/3R2K1 b - - 9 33",
        "4r3/pp3p2/6p1/Bp1P4/3k1P2/3r4/PP4Q1/3R2K1 w - - 10 34",
        "4r3/pp3p2/6p1/Bp1P4/3k1P2/3R4/PP4Q1/6K1 b - - 0 34",
        "4r3/pp3p2/6p1/Bp1P4/5P2/3k4/PP4Q1/6K1 w - - 0 35",
        "4r3/pp3p2/3P2p1/Bp6/5P2/3k4/PP4Q1/6K1 b - - 0 35",
        "1r6/pp3p2/3P2p1/Bp6/5P2/3k4/PP4Q1/6K1 w - - 1 36",
        "1r1B4/pp3p2/3P2p1/1p6/5P2/3k4/PP4Q1/6K1 b - - 2 36",
        "3r4/pp3p2/3P2p1/1p6/5P2/3k4/PP4Q1/6K1 w - - 0 37",
        "3r4/pp3p2/3P2p1/1p6/5P2/3k3Q/PP6/6K1 b - - 1 37",
        "3r4/pp3p2/3P2p1/1p6/4kP2/7Q/PP6/6K1 w - - 2 38",
        "3r4/pp3p2/3P2p1/1p6/4kP2/2Q5/PP6/6K1 b - - 3 38",
        "3r4/pp3p2/3P2p1/1p6/5k2/2Q5/PP6/6K1 w - - 0 39",
        "3r4/pp3p2/3P2p1/1p6/P4k2/2Q5/1P6/6K1 b - a3 0 39",
        "3r4/pp3p2/3P2p1/8/p4k2/2Q5/1P6/6K1 w - - 0 40",
        "3r4/pp3p2/3P2p1/8/pP3k2/2Q5/8/6K1 b - b3 0 40",
        "8/pp3p2/3r2p1/8/pP3k2/2Q5/8/6K1 w - - 0 41",
        "8/pp3p2/3r2p1/8/pP3k2/2Q5/6K1/8 b - - 1 41",
        "3r4/pp3p2/6p1/8/pP3k2/2Q5/6K1/8 w - - 2 42",
        "3r4/pp3p2/6p1/1P6/p4k2/2Q5/6K1/8 b - - 0 42",
        "3r4/pp6/6p1/1P3p2/p4k2/2Q5/6K1/8 w - f6 0 43",
        "3r4/pp6/1P4p1/5p2/p4k2/2Q5/6K1/8 b - - 0 43",
        "3r4/1p6/1p4p1/5p2/p4k2/2Q5/6K1/8 w - - 0 44",
        "3r4/1p6/1p4p1/5p2/p4k2/2Q5/5K2/8 b - - 1 44",
        "3r4/1p6/1p4p1/5p2/5k2/p1Q5/5K2/8 w - - 0 45",
        "3r4/1p6/1p4p1/5p2/5k2/p1Q5/6K1/8 b - - 1 45",
        "3r4/1p6/1p4p1/5p2/5k2/2Q5/p5K1/8 w - - 0 46",
        "3r4/1p6/1p4p1/5p2/5k2/2Q5/p4K2/8 b - - 1 46",
        "3r4/1p6/1p4p1/5p2/5k2/2Q5/5K2/q7 w - - 0 47",
        "3r4/1p6/1p4p1/5p2/5k2/4Q3/5K2/q7 b - - 1 47",
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
