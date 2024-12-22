#include <stdint.h>
#include <xil_printf.h>
#include "vchess.h"

static char *sample[] = {
"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
"rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1",
"rnbqkb1r/pppppppp/5n2/8/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 1 2",
"rnbqkb1r/pppppppp/5n2/8/3P4/5N2/PPP1PPPP/RNBQKB1R b KQkq - 2 2",
"rnbqkb1r/p1pppppp/1p3n2/8/3P4/5N2/PPP1PPPP/RNBQKB1R w KQkq - 0 3",
"rnbqkb1r/p1pppppp/1p3n2/8/2PP4/5N2/PP2PPPP/RNBQKB1R b KQkq c3 0 3",
"rnbqkb1r/p2ppppp/1p3n2/2p5/2PP4/5N2/PP2PPPP/RNBQKB1R w KQkq c6 0 4",
"rnbqkb1r/p2ppppp/1p3n2/2p5/2PP4/2N2N2/PP2PPPP/R1BQKB1R b KQkq - 1 4",
"rnbqkb1r/p2ppppp/1p3n2/8/2Pp4/2N2N2/PP2PPPP/R1BQKB1R w KQkq - 0 5",
"rnbqkb1r/p2ppppp/1p3n2/8/2PQ4/2N2N2/PP2PPPP/R1B1KB1R b KQkq - 0 5",
"r1bqkb1r/p2ppppp/1pn2n2/8/2PQ4/2N2N2/PP2PPPP/R1B1KB1R w KQkq - 1 6",
"r1bqkb1r/p2ppppp/1pn2Q2/8/2P5/2N2N2/PP2PPPP/R1B1KB1R b KQkq - 0 6",
"r1bqkb1r/p2ppp1p/1pn2p2/8/2P5/2N2N2/PP2PPPP/R1B1KB1R w KQkq - 0 7",
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
