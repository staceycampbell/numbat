#include <stdio.h>
#include <stdint.h>
#include <assert.h>

#define EXCLUDE_VITIS 1
#include "vivado/src/vchess.h"

typedef struct offset_t
{
        int32_t y;
        int32_t x;
} offset_t;

static uint16_t attack_rook[2];
static uint16_t attack_knit[2];
static uint16_t attack_bish[2];
static uint16_t attack_quen[2];
static uint16_t attack_king[2];
static uint16_t attack_pawn[2];
static char *attacker[2][1 << BLACK_BIT];

static uint16_t opponents[2][7];

#define MOBILITY_COUNT 75

static void
clear_array(uint16_t mobility[8][8])
{
        int32_t i, j;

        for (i = 0; i < 8; ++i)
                for (j = 0; j < 8; ++j)
                        mobility[i][j] = 0;
}

void
print_data(FILE * data_fp, int32_t idx, uint16_t mobility[8][8])
{
        int32_t row, col;

        fprintf(data_fp, "mobility_mask[%2d] = {\n", idx);
        for (row = 7; row >= 0; --row)
        {
                for (col = 7; col >= 0; --col)
                {
                        fprintf(data_fp, "%d'h%04X", PIECE_MASK_BITS, mobility[row][col]);
                        if (row == 0 && col == 0)
                                fprintf(data_fp, "\n");
                        else if (col == 0)
                                fprintf(data_fp, ",\n");
                        else
                                fprintf(data_fp, ", ");
                }
        }
        fprintf(data_fp, "};\n");
}

static uint32_t
do_knight(char *attacker, FILE * data_fp, uint32_t side, int row, int col)
{
        int32_t i, n_idx, n_row, n_col;
        uint32_t opp_idx;
        uint16_t mobility[8][8];
        static const offset_t n_off[] = { {-2, -1}, {-1, -2}, {+1, -2}, {+2, -1}, {+2, +1}, {+1, +2}, {-1, +2}, {-2, +1} };

        fprintf(data_fp, "if (ATTACKER == %s && ROW == %d && COL == %d)\nbegin\n", attacker, row, col);
        n_idx = 0;
        for (i = 0; i < 8; ++i)
        {
                clear_array(mobility);
                n_row = row + n_off[i].y;
                n_col = col + n_off[i].x;
                if (n_row >= 0 && n_row < 8 && n_col >= 0 && n_col < 8)
                {
                        for (opp_idx = 0; opp_idx < 7; ++opp_idx)
                        {
                                mobility[row][col] = attack_knit[side];
                                mobility[n_row][n_col] = opponents[side][opp_idx];
                                print_data(data_fp, n_idx, mobility);
                                ++n_idx;
                        }
                }
        }
        fprintf(data_fp, "end\n");

        return n_idx;
}

static uint32_t
do_bishop(char *attacker, FILE * data_fp, uint32_t side, int row, int col)
{
        int32_t i, b_idx, b_row, b_col, bi, bj;
        uint32_t opp_idx;
        uint16_t mobility[8][8];
        static const offset_t boff[4] = { {-1, -1}, {-1, +1}, {+1, -1}, {+1, +1} };
        static const offset_t inv_boff[4] = { {+1, +1}, {+1, -1}, {-1, +1}, {-1, -1} };

        fprintf(data_fp, "if (ATTACKER == %s && ROW == %d && COL == %d)\nbegin\n", attacker, row, col);
        b_idx = 0;
        for (i = 0; i < 4; ++i)
        {
                b_row = row + boff[i].y;
                b_col = col + boff[i].x;
                while (b_row >= 0 && b_row < 8 && b_col >= 0 && b_col < 8)
                {
                        clear_array(mobility);
                        mobility[row][col] = attack_bish[side];
                        for (opp_idx = 0; opp_idx < 7; ++opp_idx)
                        {
                                mobility[b_row][b_col] = opponents[side][opp_idx];
                                bi = b_row + inv_boff[i].y;
                                bj = b_col + inv_boff[i].x;
                                while (bi != row && bj != col)
                                {
                                        mobility[bi][bj] = 1 << EMPTY_POSN;
                                        bi += inv_boff[i].y;
                                        bj += inv_boff[i].x;
                                }
                                print_data(data_fp, b_idx, mobility);
                                ++b_idx;
                        }
                        b_row += boff[i].y;
                        b_col += boff[i].x;
                }
        }
        fprintf(data_fp, "end\n");

        return b_idx;
}

int
main(void)
{
        int32_t row, col;
        uint32_t idx;
        uint32_t side;
        FILE *data_fp, *head_fp;

        assert((data_fp = fopen("mobility_mask.vh", "w")) != 0);
        assert((head_fp = fopen("mobility_head.vh", "w")) != 0);

        attacker[WHITE_ATTACK][PIECE_KNIT] = "`WHITE_KNIT";
        attacker[WHITE_ATTACK][PIECE_BISH] = "`WHITE_BISH";
        attacker[WHITE_ATTACK][PIECE_ROOK] = "`WHITE_ROOK";
        attacker[WHITE_ATTACK][PIECE_QUEN] = "`WHITE_QUEN";
        attack_rook[WHITE_ATTACK] = 1 << WHITE_ROOK;
        attack_knit[WHITE_ATTACK] = 1 << WHITE_KNIT;
        attack_bish[WHITE_ATTACK] = 1 << WHITE_BISH;
        attack_quen[WHITE_ATTACK] = 1 << WHITE_QUEN;
        attack_king[WHITE_ATTACK] = 1 << WHITE_KING;
        attack_pawn[WHITE_ATTACK] = 1 << WHITE_PAWN;

        attacker[BLACK_ATTACK][PIECE_KNIT] = "`BLACK_KNIT";
        attacker[BLACK_ATTACK][PIECE_BISH] = "`BLACK_BISH";
        attacker[BLACK_ATTACK][PIECE_ROOK] = "`BLACK_ROOK";
        attacker[BLACK_ATTACK][PIECE_QUEN] = "`BLACK_QUEN";
        attack_rook[BLACK_ATTACK] = 1 << BLACK_ROOK;
        attack_knit[BLACK_ATTACK] = 1 << BLACK_KNIT;
        attack_bish[BLACK_ATTACK] = 1 << BLACK_BISH;
        attack_quen[BLACK_ATTACK] = 1 << BLACK_QUEN;
        attack_king[BLACK_ATTACK] = 1 << BLACK_KING;
        attack_pawn[BLACK_ATTACK] = 1 << BLACK_PAWN;

        opponents[WHITE_ATTACK][0] = 1 << BLACK_ROOK;
        opponents[WHITE_ATTACK][1] = 1 << BLACK_KNIT;
        opponents[WHITE_ATTACK][2] = 1 << BLACK_BISH;
        opponents[WHITE_ATTACK][3] = 1 << BLACK_QUEN;
        opponents[WHITE_ATTACK][4] = 1 << BLACK_KING;
        opponents[WHITE_ATTACK][5] = 1 << BLACK_PAWN;
        opponents[WHITE_ATTACK][6] = 1 << EMPTY_POSN;

        opponents[BLACK_ATTACK][0] = 1 << WHITE_ROOK;
        opponents[BLACK_ATTACK][1] = 1 << WHITE_KNIT;
        opponents[BLACK_ATTACK][2] = 1 << WHITE_BISH;
        opponents[BLACK_ATTACK][3] = 1 << WHITE_QUEN;
        opponents[BLACK_ATTACK][4] = 1 << WHITE_KING;
        opponents[BLACK_ATTACK][5] = 1 << WHITE_PAWN;
        opponents[BLACK_ATTACK][6] = 1 << EMPTY_POSN;

        for (side = 0; side <= 1; ++side)
        {
                for (row = 0; row < 8; ++row)
                        for (col = 0; col < 8; ++col)
                        {
                                fprintf(head_fp, "if (ATTACKER == %s && ROW == %d && COL == %d)\nbegin\n", attacker[side][PIECE_KNIT], row, col);
                                idx = do_knight(attacker[side][PIECE_KNIT], data_fp, side, row, col);
                                fprintf(head_fp, "localparam MOBILITY_LIST_COUNT = %d;\n", idx);
                                fprintf(head_fp, "end\n");

                                fprintf(head_fp, "if (ATTACKER == %s && ROW == %d && COL == %d)\nbegin\n", attacker[side][PIECE_BISH], row, col);
                                idx = do_bishop(attacker[side][PIECE_BISH], data_fp, side, row, col);
                                fprintf(head_fp, "localparam MOBILITY_LIST_COUNT = %d;\n", idx);
                                fprintf(head_fp, "end\n");

                        }
        }
        fclose(data_fp);
        fclose(head_fp);
}