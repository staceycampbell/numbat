#include <stdint.h>
#include <xil_printf.h>
#include "vchess.h"

static char *sample[] = {
"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
"rnbqkbnr/pppppppp/8/8/8/1P6/P1PPPPPP/RNBQKBNR b KQkq - 0 1",
"rnbqkbnr/p1pppppp/1p6/8/8/1P6/P1PPPPPP/RNBQKBNR w KQkq - 0 2",
"rnbqkbnr/p1pppppp/1p6/8/8/1P6/PBPPPPPP/RN1QKBNR b KQkq - 1 2",
"rn1qkbnr/pbpppppp/1p6/8/8/1P6/PBPPPPPP/RN1QKBNR w KQkq - 2 3",
"rn1qkbnr/pbpppppp/1p6/8/8/1P1P4/PBP1PPPP/RN1QKBNR b KQkq - 0 3",
"rn1qkbnr/pbpp1ppp/1p2p3/8/8/1P1P4/PBP1PPPP/RN1QKBNR w KQkq - 0 4",
"rn1qkbnr/pbpp1ppp/1p2p3/8/8/1P1P4/PBPNPPPP/R2QKBNR b KQkq - 1 4",
"r2qkbnr/pbpp1ppp/1pn1p3/8/8/1P1P4/PBPNPPPP/R2QKBNR w KQkq - 2 5",
"r2qkbnr/pbpp1ppp/1pn1p3/8/8/1P1P1N2/PBPNPPPP/R2QKB1R b KQkq - 3 5",
"r3kbnr/pbppqppp/1pn1p3/8/8/1P1P1N2/PBPNPPPP/R2QKB1R w KQkq - 4 6",
"r3kbnr/pbppqppp/1pn1p3/8/8/1P1P1NP1/PBPNPP1P/R2QKB1R b KQkq - 0 6",
#if 0
"2kr1bnr/pbppqppp/1pn1p3/8/8/1P1P1NP1/PBPNPP1P/R2QKB1R w KQ - 1 7",
"2kr1bnr/pbppqppp/1pn1p3/8/2N5/1P1P1NP1/PBP1PP1P/R2QKB1R b KQ - 2 7",
"2kr1bnr/pbp1qppp/1pn1p3/3p4/2N5/1P1P1NP1/PBP1PP1P/R2QKB1R w KQ d6 0 8",
"2kr1bnr/pbp1qppp/1pn1p3/3p4/8/1P1P1NP1/PBPNPP1P/R2QKB1R b KQ - 1 8",
"2kr1bnr/pbp2ppp/1pnqp3/3p4/8/1P1P1NP1/PBPNPP1P/R2QKB1R w KQ - 2 9",
"2kr1bnr/pbp2ppp/1pnqp3/3p4/8/1P1P1NP1/PBPNPP1P/2RQKB1R b K - 3 9",
"2kr1bnr/pbp2ppp/2nqp3/1p1p4/8/1P1P1NP1/PBPNPP1P/2RQKB1R w K - 0 10",
"2kr1bnr/pbp2ppp/2nqp3/1p1p4/8/1P1P1NPB/PBPNPP1P/2RQK2R b K - 1 10",
"2kr1bnr/pbpq1ppp/2n1p3/1p1p4/8/1P1P1NPB/PBPNPP1P/2RQK2R w K - 2 11",
"2kr1bnr/pbpq1pBp/2n1p3/1p1p4/8/1P1P1NPB/P1PNPP1P/2RQK2R b K - 0 11",
"2kr2nr/pbpq1pbp/2n1p3/1p1p4/8/1P1P1NPB/P1PNPP1P/2RQK2R w K - 0 12",
"2kr2nr/pbpq1pbp/2n1p3/1p1p4/P7/1P1P1NPB/2PNPP1P/2RQK2R b K a3 0 12",
"2kr2nr/pbpq1pbp/2n1p3/1p6/P2p4/1P1P1NPB/2PNPP1P/2RQK2R w K - 0 13",
"2kr2nr/pbpq1pbp/2n1p3/1P6/3p4/1P1P1NPB/2PNPP1P/2RQK2R b K - 0 13",
"2kr2nr/pbpq1pbp/4p3/1P6/1n1p4/1P1P1NPB/2PNPP1P/2RQK2R w K - 1 14",
"2kr2nr/pbpq1pbp/4p3/1P6/1n1pP3/1P1P1NPB/2PN1P1P/2RQK2R b K e3 0 14",
"2kr2nr/pbpq1pbp/4p3/1P6/3pP3/1P1P1NPB/n1PN1P1P/2RQK2R w K - 1 15",
"2kr2nr/pbpq1pbp/4p3/1P6/3pP3/1P1P1NPB/n1PN1P1P/R2QK2R b K - 2 15",
"2kr2nr/pbpq1pbp/4p3/1P6/3pP3/1PnP1NPB/2PN1P1P/R2QK2R w K - 3 16",
"2kr2nr/pbpq1pbp/4p3/1P6/3pP3/1PnP1NPB/2PN1P1P/R1Q1K2R b K - 4 16",
"1k1r2nr/pbpq1pbp/4p3/1P6/3pP3/1PnP1NPB/2PN1P1P/R1Q1K2R w K - 5 17",
"1k1r2nr/pbpq1pbp/4p3/1P6/2NpP3/1PnP1NPB/2P2P1P/R1Q1K2R b K - 6 17",
"1k1r2nr/pbpq2bp/4p3/1P3p2/2NpP3/1PnP1NPB/2P2P1P/R1Q1K2R w K f6 0 18",
"1k1r2nr/pbpq2bp/4p3/1P3pQ1/2NpP3/1PnP1NPB/2P2P1P/R3K2R b K - 1 18",
"1k1r2nr/pbp1q1bp/4p3/1P3pQ1/2NpP3/1PnP1NPB/2P2P1P/R3K2R w K - 2 19",
"1k1r2nr/pbp1Q1bp/4p3/1P3p2/2NpP3/1PnP1NPB/2P2P1P/R3K2R b K - 0 19",
"1k1r3r/pbp1n1bp/4p3/1P3p2/2NpP3/1PnP1NPB/2P2P1P/R3K2R w K - 0 20",
"1k1r3r/pbp1n1bp/4p3/1P3pN1/2NpP3/1PnP2PB/2P2P1P/R3K2R b K - 1 20",
"1k1r3r/pbp1n1bp/4p3/1P4N1/2Npp3/1PnP2PB/2P2P1P/R3K2R w K - 0 21",
"1k1r3r/pbp1n1bp/4p3/1P4N1/2NpP3/1Pn3PB/2P2P1P/R3K2R b K - 0 21",
"1k1r3r/pbp1n1bp/4p3/1P4N1/2Npn3/1P4PB/2P2P1P/R3K2R w K - 0 22",
"1k1r3r/pbp1n1bp/4p3/1P6/2NpN3/1P4PB/2P2P1P/R3K2R b K - 0 22",
"1k1r3r/p1p1n1bp/4p3/1P6/2Npb3/1P4PB/2P2P1P/R3K2R w K - 0 23",
"1k1r3r/p1p1n1bp/4p3/1P6/2Npb3/1P4PB/2P2P1P/R4RK1 b - - 1 23",
"1k1r1r2/p1p1n1bp/4p3/1P6/2Npb3/1P4PB/2P2P1P/R4RK1 w - - 2 24",
"1k1r1r2/p1p1n1bp/4p3/1P6/2Npb3/1P4PB/2P2P1P/R3R1K1 b - - 3 24",
"1k1r1r2/p1p1n1bp/4p3/1P6/2N1b3/1P1p2PB/2P2P1P/R3R1K1 w - - 0 25",
"1k1r1r2/p1p1n1bp/4p3/1P6/2N1b3/1P1p2PB/2P2P1P/3RR1K1 b - - 1 25",
"1k1r1r2/p1p1n1bp/4p3/1P6/2N1b3/1P4PB/2p2P1P/3RR1K1 w - - 0 26",
"1k1r1r2/p1pRn1bp/4p3/1P6/2N1b3/1P4PB/2p2P1P/4R1K1 b - - 1 26",
"1k1r1r2/p1pRn2p/4p3/1P6/2Nbb3/1P4PB/2p2P1P/4R1K1 w - - 2 27",
"1k1r1r2/p1pRn2p/4p3/1P6/3bb3/1P2N1PB/2p2P1P/4R1K1 b - - 3 27",
"1k1r1r2/p1pRn2p/2b1p3/1P6/3b4/1P2N1PB/2p2P1P/4R1K1 w - - 4 28",
"1k1r1r2/p1pRn2p/2P1p3/8/3b4/1P2N1PB/2p2P1P/4R1K1 b - - 0 28",
"1k1r1r2/p1pRn2p/2P1p3/8/8/1P2b1PB/2p2P1P/4R1K1 w - - 0 29",
"1k1r1r2/p1p1R2p/2P1p3/8/8/1P2b1PB/2p2P1P/4R1K1 b - - 0 29",
"1k1r1r2/p1p1R2p/2P1p3/8/8/1P4PB/2p2b1P/4R1K1 w - - 0 30",
"1k1r1r2/p1p1R2p/2P1p3/8/8/1P4PB/2p2bKP/4R3 b - - 1 30",
"1k1r1r2/p1p1R2p/2P1p3/8/8/1P4PB/2p3KP/4b3 w - - 0 31",
"1k1r1r2/p1p1R2p/2P1B3/8/8/1P4P1/2p3KP/4b3 b - - 0 31",
"1k1r1r2/p1p1R2p/2P1B3/8/8/1P4P1/6KP/2q1b3 w - - 0 32",
"1k1r1r2/p1p4R/2P1B3/8/8/1P4P1/6KP/2q1b3 b - - 0 32",
"1k1r1r2/p1p4R/2P1B3/8/8/1P4P1/2q3KP/4b3 w - - 1 33",
"1k1r1r2/p1p4R/2P1B3/8/8/1P4PK/2q4P/4b3 b - - 2 33",
"1k1r1r2/p1p4q/2P1B3/8/8/1P4PK/7P/4b3 w - - 0 34",
"1k1r1r2/p1p4q/2P1B3/8/6K1/1P4P1/7P/4b3 b - - 1 34",
"1k1r4/p1p4q/2P1B3/8/6K1/1P4P1/5r1P/4b3 w - - 2 35",
"1kBr4/p1p4q/2P5/8/6K1/1P4P1/5r1P/4b3 b - - 3 35",
"1kBr4/p1p5/2P3q1/8/6K1/1P4P1/5r1P/4b3 w - - 4 36",
"1kBr4/p1p5/2P3q1/8/7K/1P4P1/5r1P/4b3 b - - 5 36",
"1kBr4/p1p5/2P3q1/8/7K/1P4P1/7r/4b3 w - - 0 37",
"1k1r4/p1p5/2P3q1/8/7K/1P4PB/7r/4b3 b - - 1 37",
"1k1r4/p1p5/2P3q1/8/7K/1P4bB/7r/8 w - - 0 38"
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
