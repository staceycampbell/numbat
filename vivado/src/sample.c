#include <stdint.h>
#include <xil_printf.h>
#include "vchess.h"

static char *sample[] = {
"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
"rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1",
"rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR w KQkq d6 0 2",
"rnbqkbnr/ppp1pppp/8/3p4/2PP4/8/PP2PPPP/RNBQKBNR b KQkq c3 0 2",
"rnbqkbnr/ppp2ppp/4p3/3p4/2PP4/8/PP2PPPP/RNBQKBNR w KQkq - 0 3",
"rnbqkbnr/ppp2ppp/4p3/3p4/2PP4/2N5/PP2PPPP/R1BQKBNR b KQkq - 1 3",
"rnbqkbnr/pp3ppp/4p3/2pp4/2PP4/2N5/PP2PPPP/R1BQKBNR w KQkq c6 0 4",
"rnbqkbnr/pp3ppp/4p3/2pP4/3P4/2N5/PP2PPPP/R1BQKBNR b KQkq - 0 4",
"rnbqkbnr/pp3ppp/8/2pp4/3P4/2N5/PP2PPPP/R1BQKBNR w KQkq - 0 5",
"rnbqkbnr/pp3ppp/8/2pp4/3P4/2N2N2/PP2PPPP/R1BQKB1R b KQkq - 1 5",
"r1bqkbnr/pp3ppp/2n5/2pp4/3P4/2N2N2/PP2PPPP/R1BQKB1R w KQkq - 2 6",
"r1bqkbnr/pp3ppp/2n5/2pp4/3P4/2N2NP1/PP2PP1P/R1BQKB1R b KQkq - 0 6",
"r1bqkb1r/pp3ppp/2n2n2/2pp4/3P4/2N2NP1/PP2PP1P/R1BQKB1R w KQkq - 1 7",
"r1bqkb1r/pp3ppp/2n2n2/2Pp4/8/2N2NP1/PP2PP1P/R1BQKB1R b KQkq - 0 7",
"r1bqk2r/pp3ppp/2n2n2/2bp4/8/2N2NP1/PP2PP1P/R1BQKB1R w KQkq - 0 8",
"r1bqk2r/pp3ppp/2n2n2/2bp4/4P3/2N2NP1/PP3P1P/R1BQKB1R b KQkq e3 0 8",
"r2qk2r/pp3ppp/2n2n2/2bp4/4P1b1/2N2NP1/PP3P1P/R1BQKB1R w KQkq - 1 9",
"r2qk2r/pp3ppp/2n2n2/2bP4/6b1/2N2NP1/PP3P1P/R1BQKB1R b KQkq - 0 9",
"r2qk2r/pp3ppp/5n2/2bPn3/6b1/2N2NP1/PP3P1P/R1BQKB1R w KQkq - 1 10",
"r2qk2r/pp3ppp/5n2/2bPn3/Q5b1/2N2NP1/PP3P1P/R1B1KB1R b KQkq - 2 10",
"r2qk2r/p4ppp/5n2/1pbPn3/Q5b1/2N2NP1/PP3P1P/R1B1KB1R w KQkq b6 0 11",
"r2qk2r/p4ppp/5n2/1BbPn3/Q5b1/2N2NP1/PP3P1P/R1B1K2R b KQkq - 0 11",
"r2q1k1r/p4ppp/5n2/1BbPn3/Q5b1/2N2NP1/PP3P1P/R1B1K2R w KQ - 1 12",
"r2q1k1r/p4ppp/5n2/1BbPN3/Q5b1/2N3P1/PP3P1P/R1B1K2R b KQ - 0 12",
"r2q1k1r/p4ppp/5n2/1BbPN3/Q7/2N2bP1/PP3P1P/R1B1K2R w KQ - 1 13",
"r2q1k1r/p4ppp/5n2/1BbP4/Q7/2N2NP1/PP3P1P/R1B1K2R b KQ - 0 13",
"1r1q1k1r/p4ppp/5n2/1BbP4/Q7/2N2NP1/PP3P1P/R1B1K2R w KQ - 1 14",
"1r1q1k1r/p4ppp/5n2/1BbP4/Q7/2N2NP1/PP3P1P/R1B2RK1 b - - 2 14",
"1r1q1k1r/p4ppp/8/1Bbn4/Q7/2N2NP1/PP3P1P/R1B2RK1 w - - 0 15",
"1r1q1k1r/p4ppp/8/1Bbn4/Q7/2N2NP1/PP1B1P1P/R4RK1 b - - 1 15",
"1r1q1k1r/5ppp/p7/1Bbn4/Q7/2N2NP1/PP1B1P1P/R4RK1 w - - 0 16",
"1r1q1k1r/5ppp/Q7/1Bbn4/8/2N2NP1/PP1B1P1P/R4RK1 b - - 0 16",
"r2q1k1r/5ppp/Q7/1Bbn4/8/2N2NP1/PP1B1P1P/R4RK1 w - - 1 17",
"r2q1k1r/5ppp/2Q5/1Bbn4/8/2N2NP1/PP1B1P1P/R4RK1 b - - 2 17",
"r2q1k1r/5ppp/1bQ5/1B1n4/8/2N2NP1/PP1B1P1P/R4RK1 w - - 3 18",
"r2q1k1r/5ppp/1bQ5/1B1N4/8/5NP1/PP1B1P1P/R4RK1 b - - 0 18",
"r2q1k1r/5ppp/2Q5/bB1N4/8/5NP1/PP1B1P1P/R4RK1 w - - 1 19",
"r2q1k1r/5ppp/2Q5/bB1N2B1/8/5NP1/PP3P1P/R4RK1 b - - 2 19",
"rq3k1r/5ppp/2Q5/bB1N2B1/8/5NP1/PP3P1P/R4RK1 w - - 3 20",
"rq3k1r/5ppp/2Q5/bB1NN1B1/8/6P1/PP3P1P/R4RK1 b - - 4 20",
"1q3k1r/r4ppp/2Q5/bB1NN1B1/8/6P1/PP3P1P/R4RK1 w - - 5 21",
"1q3k1r/r4ppp/2Q5/bB1NN1B1/5P2/6P1/PP5P/R4RK1 b - f3 0 21",
"1q4kr/r4ppp/2Q5/bB1NN1B1/5P2/6P1/PP5P/R4RK1 w - - 1 22",
"1q4kr/r4ppp/2Q5/bB1NN1B1/5P2/6P1/PP5P/2R2RK1 b - - 2 22",
"1q4kr/r5pp/2Q2p2/bB1NN1B1/5P2/6P1/PP5P/2R2RK1 w - - 0 23",
"1q4kr/r5pp/2Q2B2/bB1NN3/5P2/6P1/PP5P/2R2RK1 b - - 0 23",
"1q4kr/r6p/2Q2p2/bB1NN3/5P2/6P1/PP5P/2R2RK1 w - - 0 24",
"1q4kr/r2N3p/2Q2p2/bB1N4/5P2/6P1/PP5P/2R2RK1 b - - 1 24",
"3q2kr/r2N3p/2Q2p2/bB1N4/5P2/6P1/PP5P/2R2RK1 w - - 2 25",
"3q2kr/r2N3p/2Q2N2/bB6/5P2/6P1/PP5P/2R2RK1 b - - 0 25",
"3q3r/r2N1k1p/2Q2N2/bB6/5P2/6P1/PP5P/2R2RK1 w - - 1 26",
"3q3r/r2N1k1p/5N2/bB1Q4/5P2/6P1/PP5P/2R2RK1 b - - 2 26",
"3q3r/r2Nk2p/5N2/bB1Q4/5P2/6P1/PP5P/2R2RK1 w - - 3 27",
"3q3r/r2Nk2p/5N2/bB1Q4/5P2/6P1/PP3R1P/2R3K1 b - - 4 27",
"3q3r/r2Nk2p/5N2/1B1Q4/5P2/6P1/PP1b1R1P/2R3K1 w - - 5 28",
"3q3r/r2Nk2p/5N2/1B1Q4/5P2/6P1/PP1R3P/2R3K1 b - - 0 28",
"3q3r/3Nk2p/r4N2/1B1Q4/5P2/6P1/PP1R3P/2R3K1 w - - 1 29",
"3q3r/3Nk2p/B4N2/3Q4/5P2/6P1/PP1R3P/2R3K1 b - - 0 29",
"q6r/3Nk2p/B4N2/3Q4/5P2/6P1/PP1R3P/2R3K1 w - - 1 30",
#if 0
"Q6r/3Nk2p/B4N2/8/5P2/6P1/PP1R3P/2R3K1 b - - 0 30",
"r7/3Nk2p/B4N2/8/5P2/6P1/PP1R3P/2R3K1 w - - 0 31",
"r7/3Nk2N/B7/8/5P2/6P1/PP1R3P/2R3K1 b - - 0 31",
"8/3Nk2N/r7/8/5P2/6P1/PP1R3P/2R3K1 w - - 0 32",
"8/4k2N/rN6/8/5P2/6P1/PP1R3P/2R3K1 b - - 1 32",
"8/4k2N/1r6/8/5P2/6P1/PP1R3P/2R3K1 w - - 0 33",
"8/4k2N/1r6/8/5P2/6P1/PP1R3P/3R2K1 b - - 1 33",
"8/7N/1r2k3/8/5P2/6P1/PP1R3P/3R2K1 w - - 2 34",
"8/7N/1r2k3/8/5P1P/6P1/PP1R4/3R2K1 b - h3 0 34",
"8/7N/1r6/5k2/5P1P/6P1/PP1R4/3R2K1 w - - 1 35",
"8/3R3N/1r6/5k2/5P1P/6P1/PP6/3R2K1 b - - 2 35",
"8/3R3N/8/5k2/5P1P/6P1/Pr6/3R2K1 w - - 0 36",
"8/4R2N/8/5k2/5P1P/6P1/Pr6/3R2K1 b - - 1 36",
"8/4R2N/8/5k2/5P1P/6P1/r7/3R2K1 w - - 0 37",
"8/6RN/8/5k2/5P1P/6P1/r7/3R2K1 b - - 1 37",
"8/6RN/8/5k2/5P1P/6P1/4r3/3R2K1 w - - 2 38",
"8/6RN/8/5k1P/5P2/6P1/4r3/3R2K1 b - - 0 38",
"8/6RN/8/5k1P/5P2/6P1/8/3Rr1K1 w - - 1 39",
"8/6RN/8/5k1P/5P2/6P1/6K1/3Rr3 b - - 2 39",
"8/6RN/8/5k1P/5P2/6P1/6K1/3r4 w - - 0 40",
"8/6RN/8/5k1P/5P2/5KP1/8/3r4 b - - 1 40",
"8/6RN/8/5k1P/5P2/5KP1/8/2r5 w - - 2 41",
"8/6R1/8/5kNP/5P2/5KP1/8/2r5 b - - 3 41",
"8/6R1/8/5kNP/5P2/5KP1/8/r7 w - - 4 42",
"8/5R2/8/5kNP/5P2/5KP1/8/r7 b - - 5 42",
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
