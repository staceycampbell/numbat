#include <stdint.h>
#include <xil_printf.h>
#include "vchess.h"

static char *sample[] = {
"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
"rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
"rnbqkb1r/pppppppp/5n2/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 1 2",
"rnbqkb1r/pppppppp/5n2/8/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 2 2",
"rnbqkb1r/pppppppp/8/8/2B1n3/8/PPPP1PPP/RNBQK1NR w KQkq - 0 3",
"rnbqkb1r/pppppBpp/8/8/4n3/8/PPPP1PPP/RNBQK1NR b KQkq - 0 3",
"rnbq1b1r/pppppkpp/8/8/4n3/8/PPPP1PPP/RNBQK1NR w KQ - 0 4",
"rnbq1b1r/pppppkpp/8/7Q/4n3/8/PPPP1PPP/RNB1K1NR b KQ - 1 4",
"rnbq1bkr/ppppp1pp/8/7Q/4n3/8/PPPP1PPP/RNB1K1NR w KQ - 2 5",
"rnbq1bkr/ppppp1pp/8/3Q4/4n3/8/PPPP1PPP/RNB1K1NR b KQ - 3 5",
"rnbq1bkr/pppp2pp/4p3/3Q4/4n3/8/PPPP1PPP/RNB1K1NR w KQ - 0 6",
"rnbq1bkr/pppp2pp/4p3/8/4Q3/8/PPPP1PPP/RNB1K1NR b KQ - 0 6",
"rnbq1bkr/ppp3pp/4p3/3p4/4Q3/8/PPPP1PPP/RNB1K1NR w KQ d6 0 7",
"rnbq1bkr/ppp3pp/4p3/3p4/5Q2/8/PPPP1PPP/RNB1K1NR b KQ - 1 7",
"rnbq1bkr/ppp3pp/8/3pp3/5Q2/8/PPPP1PPP/RNB1K1NR w KQ - 0 8",
"rnbq1bkr/ppp3pp/8/3pQ3/8/8/PPPP1PPP/RNB1K1NR b KQ - 0 8",
"r1bq1bkr/ppp3pp/2n5/3pQ3/8/8/PPPP1PPP/RNB1K1NR w KQ - 1 9",
"r1bq1bkr/ppp3pp/2n5/3p4/5Q2/8/PPPP1PPP/RNB1K1NR b KQ - 2 9",
"r1bq2kr/ppp3pp/2nb4/3p4/5Q2/8/PPPP1PPP/RNB1K1NR w KQ - 3 10",
"r1bq2kr/ppp3pp/2nb4/3p4/8/4Q3/PPPP1PPP/RNB1K1NR b KQ - 4 10",
"r2q2kr/ppp3pp/2nb4/3p4/6b1/4Q3/PPPP1PPP/RNB1K1NR w KQ - 5 11",
"r2q2kr/ppp3pp/2nb4/3p4/6b1/4Q3/PPPP1PPP/RNB2KNR b - - 6 11",
"r5kr/ppp3pp/2nb1q2/3p4/6b1/4Q3/PPPP1PPP/RNB2KNR w - - 7 12",
"r5kr/ppp3pp/2nb1q2/3p4/6b1/4QP2/PPPP2PP/RNB2KNR b - - 0 12",
"r5kr/ppp3pp/3b1q2/3p4/3n2b1/4QP2/PPPP2PP/RNB2KNR w - - 1 13",
"r5kr/ppp3pp/3b1q2/3p4/3n2b1/N3QP2/PPPP2PP/R1B2KNR b - - 2 13",
"r5kr/ppp3pp/5q2/3p4/3n2b1/b3QP2/PPPP2PP/R1B2KNR w - - 0 14",
"r5kr/ppp3pp/5q2/3p4/3n2b1/P3QP2/P1PP2PP/R1B2KNR b - - 0 14",
"r5kr/ppp3pp/5q2/3p4/6b1/P3Qn2/P1PP2PP/R1B2KNR w - - 0 15",
"r5kr/ppp3pp/5q2/3p4/6b1/P3QP2/P1PP3P/R1B2KNR b - - 0 15",
"r5kr/ppp3pp/8/3p4/6b1/P3QP2/P1PP3P/q1B2KNR w - - 0 16",
"r5kr/ppp3pp/8/3p4/6P1/P3Q3/P1PP3P/q1B2KNR b - - 0 16",
"r5kr/ppp3pp/8/3p4/6P1/P3Q3/P1PP3P/2q2KNR w - - 0 17",
"r5kr/ppp3pp/8/3p4/6P1/P3Q3/P1PPK2P/2q3NR b - - 1 17",
"r5kr/ppp3pp/8/3p4/6P1/P3Q3/P1qPK2P/6NR w - - 0 18",
"r5kr/ppp3pp/8/3p4/6P1/P3QN2/P1qPK2P/7R b - - 1 18",
"r5kr/ppp3pp/6q1/3p4/6P1/P3QN2/P2PK2P/7R w - - 2 19",
"r5kr/ppp3pp/6q1/3pQ3/6P1/P4N2/P2PK2P/7R b - - 3 19",
"4r1kr/ppp3pp/6q1/3pQ3/6P1/P4N2/P2PK2P/7R w - - 4 20",
"4Q1kr/ppp3pp/6q1/3p4/6P1/P4N2/P2PK2P/7R b - - 0 20",
"4q1kr/ppp3pp/8/3p4/6P1/P4N2/P2PK2P/7R w - - 0 21",
"4q1kr/ppp3pp/8/3p4/6P1/P4N2/P2P1K1P/7R b - - 1 21",
"6kr/ppp1q1pp/8/3p4/6P1/P4N2/P2P1K1P/7R w - - 2 22",
"6kr/ppp1q1pp/8/3p4/6P1/P4N2/P2P1K1P/2R5 b - - 3 22",
"6kr/ppp1q2p/8/3p2p1/6P1/P4N2/P2P1K1P/2R5 w - g6 0 23",
"6kr/ppp1q2p/8/3p2p1/6P1/P4N2/P2P1K1P/4R3 b - - 1 23",
"5qkr/ppp4p/8/3p2p1/6P1/P4N2/P2P1K1P/4R3 w - - 2 24",
"5qkr/ppp4p/8/3pR1p1/6P1/P4N2/P2P1K1P/8 b - - 3 24",
"6kr/ppp4p/8/2qpR1p1/6P1/P4N2/P2P1K1P/8 w - - 4 25",
"6kr/ppp4p/8/2qp2p1/6P1/P3RN2/P2P1K1P/8 b - - 5 25",
"6kr/ppp5/8/2qp2pp/6P1/P3RN2/P2P1K1P/8 w - h6 0 26",
"6kr/ppp5/8/2qp2pP/8/P3RN2/P2P1K1P/8 b - - 0 26",
"6kr/ppp5/8/2qp3P/6p1/P3RN2/P2P1K1P/8 w - - 0 27",
"6kr/ppp5/8/2qp2NP/6p1/P3R3/P2P1K1P/8 b - - 1 27",
"6k1/ppp5/8/2qp2Nr/6p1/P3R3/P2P1K1P/8 w - - 0 28",
"6k1/ppp5/8/2qp2Nr/6pP/P3R3/P2P1K2/8 b - h3 0 28",
"6k1/ppp5/8/2qp2Nr/8/P3R2p/P2P1K2/8 w - - 0 29",
"6k1/ppp5/4N3/2qp3r/8/P3R2p/P2P1K2/8 b - - 1 29",
"6k1/ppp5/4N3/3p3r/8/P3R2p/P1qP1K2/8 w - - 2 30",
"6k1/ppp5/8/3p3r/5N2/P3R2p/P1qP1K2/8 b - - 3 30",
"6k1/ppp5/8/3p3r/5N2/P3R2p/P2q1K2/8 w - - 0 31",
"6k1/ppp5/8/3p3r/5N2/P3RK1p/P2q4/8 b - - 1 31",
"6k1/ppp5/8/3p1r2/5N2/P3RK1p/P2q4/8 w - - 2 32",
"4R1k1/ppp5/8/3p1r2/5N2/P4K1p/P2q4/8 b - - 3 32",
"4R3/ppp2k2/8/3p1r2/5N2/P4K1p/P2q4/8 w - - 4 33",
"4R3/ppp2k2/8/3p1r2/5N2/P5Kp/P2q4/8 b - - 5 33",
"4R3/ppp2k2/8/3p1r2/5q2/P5Kp/P7/8 w - - 0 34",
"4R3/ppp2k2/8/3p1r2/5q2/P6K/P7/8 b - - 0 34",
"4R3/ppp2k2/8/3p2r1/5q2/P6K/P7/8 w - - 1 35",
"8/ppp2k2/8/3p2r1/5q2/P6K/P7/4R3 b - - 2 35",
"8/ppp2k2/8/3p4/5q2/P5rK/P7/4R3 w - - 3 36",
"8/ppp2k2/8/3p4/5q2/P5r1/P6K/4R3 b - - 4 36",
"8/ppp2k2/8/3p4/5q2/P3r3/P6K/4R3 w - - 5 37",
"8/ppp2k2/8/3p4/5q2/P3r3/P7/4R1K1 b - - 6 37",
"8/ppp2k2/8/3p4/5q2/P7/P7/4r1K1 w - - 0 38",
"8/ppp2k2/8/3p4/5q2/P7/P5K1/4r3 b - - 1 38",
"6k1/ppp5/8/3p4/5q2/P7/P5K1/4r3 w - - 2 39",
"6k1/ppp5/8/3p4/P4q2/8/P5K1/4r3 b - - 0 39",
"6k1/pp6/8/2pp4/P4q2/8/P5K1/4r3 w - c6 0 40",
"6k1/pp6/8/2pp4/P4q2/P7/6K1/4r3 b - - 0 40",
"6k1/pp6/8/2pp4/P4q2/P7/4r1K1/8 w - - 1 41",
"6k1/pp6/8/2pp4/P4q2/P7/4r3/6K1 b - - 2 41",
"6k1/pp6/8/2pp4/q7/P7/4r3/6K1 w - - 0 42",
"6k1/pp6/8/2pp4/q7/P7/4r3/7K b - - 1 42",
"6k1/pp6/8/2pp4/8/q7/4r3/7K w - - 0 43",
"6k1/pp6/8/2pp4/8/q7/4r3/6K1 b - - 1 43",
// "6k1/pp6/8/2pp4/8/6q1/4r3/6K1 w - - 2 44"
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
