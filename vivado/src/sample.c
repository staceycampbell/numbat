#include <stdint.h>
#include <xil_printf.h>
#include "vchess.h"

static char *sample[] = {
"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
"rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
"rnbqkbnr/ppp1pppp/3p4/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2",
"rnbqkbnr/ppp1pppp/3p4/8/3PP3/8/PPP2PPP/RNBQKBNR b KQkq d3 0 2",
"rnbqkb1r/ppp1pppp/3p1n2/8/3PP3/8/PPP2PPP/RNBQKBNR w KQkq - 1 3",
"rnbqkb1r/ppp1pppp/3p1n2/8/3PP3/2N5/PPP2PPP/R1BQKBNR b KQkq - 2 3",
"rnbqkb1r/ppp1pp1p/3p1np1/8/3PP3/2N5/PPP2PPP/R1BQKBNR w KQkq - 0 4",
"rnbqkb1r/ppp1pp1p/3p1np1/8/3PPP2/2N5/PPP3PP/R1BQKBNR b KQkq f3 0 4",
"rnbqk2r/ppp1ppbp/3p1np1/8/3PPP2/2N5/PPP3PP/R1BQKBNR w KQkq - 1 5",
"rnbqk2r/ppp1ppbp/3p1np1/8/3PPP2/2N2N2/PPP3PP/R1BQKB1R b KQkq - 2 5",
"rnbq1rk1/ppp1ppbp/3p1np1/8/3PPP2/2N2N2/PPP3PP/R1BQKB1R w KQ - 3 6",
"rnbq1rk1/ppp1ppbp/3p1np1/8/3PPP2/2NB1N2/PPP3PP/R1BQK2R b KQ - 4 6",
"rnbq1rk1/pp2ppbp/3p1np1/2p5/3PPP2/2NB1N2/PPP3PP/R1BQK2R w KQ c6 0 7",
"rnbq1rk1/pp2ppbp/3p1np1/2pP4/4PP2/2NB1N2/PPP3PP/R1BQK2R b KQ - 0 7",
"rnbq1rk1/pp2ppbp/3p2p1/2pn4/4PP2/2NB1N2/PPP3PP/R1BQK2R w KQ - 0 8",
"rnbq1rk1/pp2ppbp/3p2p1/2pP4/5P2/2NB1N2/PPP3PP/R1BQK2R b KQ - 0 8",
#if 0
"rnbq1rk1/pp2pp1p/3p2p1/2pP4/5P2/2bB1N2/PPP3PP/R1BQK2R w KQ - 0 9",
"rnbq1rk1/pp2pp1p/3p2p1/2pP4/5P2/2PB1N2/P1P3PP/R1BQK2R b KQ - 0 9",
"rn1q1rk1/pp2pp1p/3p2p1/2pP4/5Pb1/2PB1N2/P1P3PP/R1BQK2R w KQ - 1 10",
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
