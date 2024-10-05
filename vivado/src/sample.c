#include <stdint.h>
#include <xil_printf.h>
#include "vchess.h"

static char *sample[] = {
"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
"rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1",
"rnbqkbnr/pppppp1p/6p1/8/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 0 2",
"rnbqkbnr/pppppp1p/6p1/8/2PP4/8/PP2PPPP/RNBQKBNR b KQkq c3 0 2",
"rnbqk1nr/ppppppbp/6p1/8/2PP4/8/PP2PPPP/RNBQKBNR w KQkq - 1 3",
"rnbqk1nr/ppppppbp/6p1/8/2PP4/5N2/PP2PPPP/RNBQKB1R b KQkq - 2 3",
"rnbqk2r/ppppppbp/5np1/8/2PP4/5N2/PP2PPPP/RNBQKB1R w KQkq - 3 4",
"rnbqk2r/ppppppbp/5np1/8/2PP4/2N2N2/PP2PPPP/R1BQKB1R b KQkq - 4 4",
"rnbq1rk1/ppppppbp/5np1/8/2PP4/2N2N2/PP2PPPP/R1BQKB1R w KQ - 5 5",
"rnbq1rk1/ppppppbp/5np1/8/2PPP3/2N2N2/PP3PPP/R1BQKB1R b KQ e3 0 5",
"rnbq1rk1/pp1pppbp/2p2np1/8/2PPP3/2N2N2/PP3PPP/R1BQKB1R w KQ - 0 6",
"rnbq1rk1/pp1pppbp/2p2np1/8/2PPP3/2N2N2/PP2BPPP/R1BQK2R b KQ - 1 6",
"rnbq1rk1/pp2ppbp/2pp1np1/8/2PPP3/2N2N2/PP2BPPP/R1BQK2R w KQ - 0 7",
"rnbq1rk1/pp2ppbp/2pp1np1/6B1/2PPP3/2N2N2/PP2BPPP/R2QK2R b KQ - 1 7",
"rnbq1rk1/pp2ppb1/2pp1npp/6B1/2PPP3/2N2N2/PP2BPPP/R2QK2R w KQ - 0 8",
"rnbq1rk1/pp2ppb1/2pp1npp/8/2PPPB2/2N2N2/PP2BPPP/R2QK2R b KQ - 1 8",
"r1bq1rk1/pp1nppb1/2pp1npp/8/2PPPB2/2N2N2/PP2BPPP/R2QK2R w KQ - 2 9",
"r1bq1rk1/pp1nppb1/2pp1npp/8/2PPPB2/2N2N2/PP2BPPP/R2Q1RK1 b - - 3 9",
"r1bq1rk1/pp1nppb1/2pp2pp/7n/2PPPB2/2N2N2/PP2BPPP/R2Q1RK1 w - - 4 10",
"r1bq1rk1/pp1nppb1/2pp2pp/7n/2PPP3/2N1BN2/PP2BPPP/R2Q1RK1 b - - 5 10",
"r1bq1rk1/pp1n1pb1/2pp2pp/4p2n/2PPP3/2N1BN2/PP2BPPP/R2Q1RK1 w - e6 0 11",
"r1bq1rk1/pp1n1pb1/2pp2pp/4p2n/2PPP3/2N1BN2/PP1QBPPP/R4RK1 b - - 1 11",
"r1bq1r2/pp1n1pbk/2pp2pp/4p2n/2PPP3/2N1BN2/PP1QBPPP/R4RK1 w - - 2 12",
"r1bq1r2/pp1n1pbk/2pp2pp/4p2n/2PPP3/2N1BN2/PP1QBPPP/3R1RK1 b - - 3 12",
"r1b2r2/pp1nqpbk/2pp2pp/4p2n/2PPP3/2N1BN2/PP1QBPPP/3R1RK1 w - - 4 13",
"r1b2r2/pp1nqpbk/2pp2pp/4P2n/2P1P3/2N1BN2/PP1QBPPP/3R1RK1 b - - 0 13",
"r1b2r2/pp1nqpbk/2p3pp/4p2n/2P1P3/2N1BN2/PP1QBPPP/3R1RK1 w - - 0 14",
"r1b2r2/pp1nqpbk/2pQ2pp/4p2n/2P1P3/2N1BN2/PP2BPPP/3R1RK1 b - - 1 14",
"r1b2r2/pp1n1pbk/2pq2pp/4p2n/2P1P3/2N1BN2/PP2BPPP/3R1RK1 w - - 0 15",
"r1b2r2/pp1n1pbk/2pR2pp/4p2n/2P1P3/2N1BN2/PP2BPPP/5RK1 b - - 0 15",
"r1b1r3/pp1n1pbk/2pR2pp/4p2n/2P1P3/2N1BN2/PP2BPPP/5RK1 w - - 1 16",
"r1b1r3/pp1n1pbk/2pR2pp/4p2n/2P1P3/2N1BN2/PP2BPPP/3R2K1 b - - 2 16",
"r1b5/pp1nrpbk/2pR2pp/4p2n/2P1P3/2N1BN2/PP2BPPP/3R2K1 w - - 3 17",
"r1b5/pp1nrpbk/2pR2pp/4p2n/2P1P3/2N1BNP1/PP2BP1P/3R2K1 b - - 0 17",
"r1b5/1p1nrpbk/p1pR2pp/4p2n/2P1P3/2N1BNP1/PP2BP1P/3R2K1 w - - 0 18",
"r1b5/1p1nrpbk/p1pR2pp/2P1p2n/4P3/2N1BNP1/PP2BP1P/3R2K1 b - - 0 18",
"r1b2n2/1p2rpbk/p1pR2pp/2P1p2n/4P3/2N1BNP1/PP2BP1P/3R2K1 w - - 1 19",
"r1b2n2/1p2rpbk/p1pR2pp/2P1p2n/2B1P3/2N1BNP1/PP3P1P/3R2K1 b - - 2 19",
"r4n2/1p2rpbk/p1pRb1pp/2P1p2n/2B1P3/2N1BNP1/PP3P1P/3R2K1 w - - 3 20",
"r4n2/1p2rpbk/p1pRb1pp/2P1p2n/4P3/2NBBNP1/PP3P1P/3R2K1 b - - 4 20",
"r4n2/1p2rpbk/p1pRb2p/2P1p1pn/4P3/2NBBNP1/PP3P1P/3R2K1 w - - 0 21",
"r4n2/1p2rpbk/p1pRb2p/2P1p1pn/4P3/2NBBNP1/PP3PKP/3R4 b - - 1 21",
"r4n2/1p2rpbk/p1pRb2p/2P1p2n/4P1p1/2NBBNP1/PP3PKP/3R4 w - - 0 22",
"r4n2/1p2rpbk/p1pRb2p/2P1p2n/4P1pN/2NBB1P1/PP3PKP/3R4 b - - 1 22",
"r7/1p2rpbk/p1pRb1np/2P1p2n/4P1pN/2NBB1P1/PP3PKP/3R4 w - - 2 23",
"r7/1p2rpbk/p1pRb1np/2P1pN1n/4P1p1/2NBB1P1/PP3PKP/3R4 b - - 3 23",
"r7/1p2rpbk/p1pR2np/2P1pb1n/4P1p1/2NBB1P1/PP3PKP/3R4 w - - 0 24",
"r7/1p2rpbk/p1pR2np/2P1pP1n/6p1/2NBB1P1/PP3PKP/3R4 b - - 0 24",
"r4n2/1p2rpbk/p1pR3p/2P1pP1n/6p1/2NBB1P1/PP3PKP/3R4 w - - 1 25",
"r4n2/1p2rpbk/p1pR1P1p/2P1p2n/6p1/2NBB1P1/PP3PKP/3R4 b - - 0 25",
"r4n2/1p2rpbk/p1pR1P1p/2P4n/4p1p1/2NBB1P1/PP3PKP/3R4 w - - 0 26",
"r4n2/1p2Ppbk/p1pR3p/2P4n/4p1p1/2NBB1P1/PP3PKP/3R4 b - - 0 26",
"r4n2/1p2Ppbk/p1pR3p/2P4n/6p1/2NpB1P1/PP3PKP/3R4 w - - 0 27",
"r2R1n2/1p2Ppbk/p1p4p/2P4n/6p1/2NpB1P1/PP3PKP/3R4 b - - 1 27",
"r2R1n2/1p2Pp1k/p1p4p/2P4n/6p1/2bpB1P1/PP3PKP/3R4 w - - 0 28",
"R4n2/1p2Pp1k/p1p4p/2P4n/6p1/2bpB1P1/PP3PKP/3R4 b - - 0 28",
#if 0
"R4n2/1p2Pp1k/p1p4p/2P4n/6p1/3pB1P1/Pb3PKP/3R4 w - - 0 29",
"R4Q2/1p3p1k/p1p4p/2P4n/6p1/3pB1P1/Pb3PKP/3R4 b - - 0 29",
"R4Q2/1p3p1k/2p4p/p1P4n/6p1/3pB1P1/Pb3PKP/3R4 w - - 0 30",
"R7/1p3p1k/2p4Q/p1P4n/6p1/3pB1P1/Pb3PKP/3R4 b - - 0 30"
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
