#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <assert.h>

#define EXCLUDE_VITIS 1
#include "vivado/src/vchess.h"

// Crafty weights, copyright 1996-2020 by Robert M. Hyatt, Ph.D.

#define MATE                                 32768
#define PAWN_VALUE                             100
#define KNIGHT_VALUE                           305
#define BISHOP_VALUE                           305
#define ROOK_VALUE                             490
#define QUEEN_VALUE                           1000
#define KING_VALUE                           40000

typedef struct fileinfo_t
{
        const char *fn;
        FILE *fp;
} fileinfo_t;

typedef enum
{ mg = 0, eg = 1 } PHASE;       // mid-game, end-game

static const int pval[2][64] = {
        {0, 0, 0, 0, 0, 0, 0, 0,
         -5, 0, 0, 0, 0, 0, 0, -5,
         -5, 0, 0, 0, 0, 0, 0, -5,
         -5, 0, 3, 5, 5, 3, 0, -5,      /* [mg][black][sq] */
         -5, 0, 5, 10, 10, 5, 0, -5,
         -5, 0, 3, 5, 5, 3, 0, -5,
         -5, 0, 0, 0, 0, 0, 0, -5,
         0, 0, 0, 0, 0, 0, 0, 0},

        {0, 0, 0, 0, 0, 0, 0, 0,
         -5, 0, 0, 0, 0, 0, 0, -5,
         -5, 0, 3, 5, 5, 3, 0, -5,
         -5, 0, 5, 10, 10, 5, 0, -5,    /* [mg][white][sq] */
         -5, 0, 3, 5, 5, 3, 0, -5,
         -5, 0, 0, 0, 0, 0, 0, -5,
         -5, 0, 0, 0, 0, 0, 0, -5,
         0, 0, 0, 0, 0, 0, 0, 0}
};

static const int nval[2][2][64] = {
        {{-41, -29, -27, -15, -15, -27, -29, -41,
          -9, 4, 14, 20, 20, 14, 4, -9,
          -7, 10, 23, 29, 29, 23, 10, -7,
          -5, 12, 25, 32, 32, 25, 12, -5,       /* [mg][black][sq] */
          -5, 10, 23, 28, 28, 23, 10, -5,
          -7, -2, 19, 19, 19, 19, -2, -7,
          -9, -6, -2, 0, 0, -2, -6, -9,
          -31, -29, -27, -25, -25, -27, -29, -31},

         {-31, -29, -27, -25, -25, -27, -29, -31,
          -9, -6, -2, 0, 0, -2, -6, -9,
          -7, -2, 19, 19, 19, 19, -2, -7,
          -5, 10, 23, 28, 28, 23, 10, -5,       /* [mg][white][sq] */
          -5, 12, 25, 32, 32, 25, 12, -5,
          -7, 10, 23, 29, 29, 23, 10, -7,
          -9, 4, 14, 20, 20, 14, 4, -9,
          -41, -29, -27, -15, -15, -27, -29, -41}},

        {{-41, -29, -27, -15, -15, -27, -29, -41,
          -9, 4, 14, 20, 20, 14, 4, -9,
          -7, 10, 23, 29, 29, 23, 10, -7,
          -5, 12, 25, 32, 32, 25, 12, -5,       /* [eg][black][sq] */
          -5, 10, 23, 28, 28, 23, 10, -5,
          -7, -2, 19, 19, 19, 19, -2, -7,
          -9, -6, -2, 0, 0, -2, -6, -9,
          -31, -29, -27, -25, -25, -27, -29, -31},

         {-31, -29, -27, -25, -25, -27, -29, -31,
          -9, -6, -2, 0, 0, -2, -6, -9,
          -7, -2, 19, 19, 19, 19, -2, -7,
          -5, 10, 23, 28, 28, 23, 10, -5,       /* [eg][white][sq] */
          -5, 12, 25, 32, 32, 25, 12, -5,
          -7, 10, 23, 29, 29, 23, 10, -7,
          -9, 4, 14, 20, 20, 14, 4, -9,
          -41, -29, -27, -15, -15, -27, -29, -41}}
};

static const int bval[2][2][64] = {
        {{0, 0, 0, 0, 0, 0, 0, 0,
          0, 4, 4, 4, 4, 4, 4, 0,
          0, 4, 8, 8, 8, 8, 4, 0,
          0, 4, 8, 12, 12, 8, 4, 0,
          0, 4, 8, 12, 12, 8, 4, 0,     /* [mg][black][sq] */
          0, 4, 8, 8, 8, 8, 4, 0,
          0, 4, 4, 4, 4, 4, 4, 0,
          -15, -15, -15, -15, -15, -15, -15, -15},

         {-15, -15, -15, -15, -15, -15, -15, -15,
          0, 4, 4, 4, 4, 4, 4, 0,
          0, 4, 8, 8, 8, 8, 4, 0,
          0, 4, 8, 12, 12, 8, 4, 0,
          0, 4, 8, 12, 12, 8, 4, 0,     /* [mg][white][sq] */
          0, 4, 8, 8, 8, 8, 4, 0,
          0, 4, 4, 4, 4, 4, 4, 0,
          0, 0, 0, 0, 0, 0, 0, 0}},

        {{0, 0, 0, 0, 0, 0, 0, 0,
          0, 4, 4, 4, 4, 4, 4, 0,
          0, 4, 8, 8, 8, 8, 4, 0,
          0, 4, 8, 12, 12, 8, 4, 0,
          0, 4, 8, 12, 12, 8, 4, 0,     /* [eg][black][sq] */
          0, 4, 8, 8, 8, 8, 4, 0,
          0, 4, 4, 4, 4, 4, 4, 0,
          -15, -15, -15, -15, -15, -15, -15, -15},

         {-15, -15, -15, -15, -15, -15, -15, -15,
          0, 4, 4, 4, 4, 4, 4, 0,
          0, 4, 8, 8, 8, 8, 4, 0,
          0, 4, 8, 12, 12, 8, 4, 0,
          0, 4, 8, 12, 12, 8, 4, 0,     /* [eg][white][sq] */
          0, 4, 8, 8, 8, 8, 4, 0,
          0, 4, 4, 4, 4, 4, 4, 0,
          0, 0, 0, 0, 0, 0, 0, 0}}
};

static const int qval[2][2][64] = {
        {{0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 4, 4, 4, 4, 0, 0,
          0, 4, 4, 6, 6, 4, 4, 0,
          0, 4, 6, 8, 8, 6, 4, 0,
          0, 4, 6, 8, 8, 6, 4, 0,       /* [mg][black][sq] */
          0, 4, 4, 6, 6, 4, 4, 0,
          0, 0, 4, 4, 4, 4, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0},

         {0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 4, 4, 4, 4, 0, 0,
          0, 4, 4, 6, 6, 4, 4, 0,
          0, 4, 6, 8, 8, 6, 4, 0,
          0, 4, 6, 8, 8, 6, 4, 0,       /* [mg][white][sq] */
          0, 4, 4, 6, 6, 4, 4, 0,
          0, 0, 4, 4, 4, 4, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0}},

        {{0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 4, 4, 4, 4, 0, 0,
          0, 4, 4, 6, 6, 4, 4, 0,
          0, 4, 6, 8, 8, 6, 4, 0,
          0, 4, 6, 8, 8, 6, 4, 0,       /* [eg][black][sq] */
          0, 4, 4, 6, 6, 4, 4, 0,
          0, 0, 4, 4, 4, 4, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0},

         {0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 4, 4, 4, 4, 0, 0,
          0, 4, 4, 6, 6, 4, 4, 0,
          0, 4, 6, 8, 8, 6, 4, 0,
          0, 4, 6, 8, 8, 6, 4, 0,       /* [eg][white][sq] */
          0, 4, 4, 6, 6, 4, 4, 0,
          0, 0, 4, 4, 4, 4, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0}}
};

static const int kval[2][64] = {
        {-40, -40, -40, -40, -40, -40, -40, -40,
         -40, -10, -10, -10, -10, -10, -10, -40,
         -40, -10, 60, 60, 60, 60, -10, -40,
         -40, -10, 60, 60, 60, 60, -10, -40,
         -40, -10, 40, 40, 40, 40, -10, -40,    /* [black][sq] */
         -40, -10, 20, 20, 20, 20, -10, -40,
         -40, -10, -10, -10, -10, -10, -10, -40,
         -40, -40, -40, -40, -40, -40, -40, -40},

        {-40, -40, -40, -40, -40, -40, -40, -40,
         -40, -10, -10, -10, -10, -10, -10, -40,
         -40, -10, 20, 20, 20, 20, -10, -40,
         -40, -10, 40, 40, 40, 40, -10, -40,
         -40, -10, 60, 60, 60, 60, -10, -40,    /* [white][sq] */
         -40, -10, 60, 60, 60, 60, -10, -40,
         -40, -10, -10, -10, -10, -10, -10, -40,
         -40, -40, -40, -40, -40, -40, -40, -40}
};

static const int pawn_isolated[2][8] = {
        {14, 21, 23, 23, 23, 23, 21, 14},
        {5, 7, 8, 8, 8, 8, 7, 5}
};

static const int pawn_doubled[2][8] = {
        {7, 8, 9, 9, 9, 9, 8, 7},
        {22, 19, 19, 19, 19, 19, 19, 22}
};

static const int pawn_connected[2][8][8] = {
        {{0, 0, 0, 0, 0, 0, 0, 0},
         {0, 1, 1, 2, 2, 1, 1, 0},
         {1, 2, 2, 3, 3, 2, 2, 1},
         {3, 5, 6, 10, 10, 6, 5, 3},    /* [mg][file][rank] */
         {12, 14, 17, 22, 22, 17, 14, 12},
         {27, 29, 31, 35, 35, 31, 29, 27},
         {54, 63, 65, 70, 70, 65, 63, 54},
         {0, 0, 0, 0, 0, 0, 0, 0}},

        {{0, 0, 0, 0, 0, 0, 0, 0},
         {1, 3, 3, 3, 3, 3, 1, 1},
         {3, 6, 6, 6, 6, 6, 6, 1},
         {6, 10, 10, 10, 10, 10, 10, 3},        /* [eg][file][rank] */
         {13, 17, 17, 17, 17, 17, 17, 13},
         {32, 38, 38, 38, 38, 38, 38, 32},
         {76, 87, 87, 87, 87, 87, 87, 76},
         {0, 0, 0, 0, 0, 0, 0, 0}}
};

static const int pawn_backward[2][8] = {
        {8, 12, 14, 14, 14, 14, 12, 8},
        {2, 3, 3, 3, 3, 3, 3, 2}
};

static const int passed_pawn[8] = { 0, 0, 0, 2, 6, 12, 21, 0 };
static const int passed_pawn_base[2] = { 4, 8 };

int
main(void)
{
        int32_t c, i, j, row, col, idx, b;
        uint64_t shift64[64];
        uint64_t not_passed_mask[8][8];
        uint64_t passed_pawn_path[8][8];
        static const char *c_str[2] = { "BLACK", "WHITE" };
        static const int32_t sign[2] = { -1, 1 };
        fileinfo_t fileinfo[] = {
                {"evaluate_general.vh", 0},
                {"evaluate_pawns.vh", 0}
        };
        static const int eval_general = 0;
        static const int eval_pawns = 1;

        for (i = 0; i < sizeof(fileinfo) / sizeof(fileinfo_t); ++i)
                assert((fileinfo[i].fp = fopen(fileinfo[i].fn, "w")) != 0);

        for (i = 0; i < 64; ++i)
                shift64[i] = (uint64_t) 1 << (uint64_t) i;

        for (i = 0; i < 8; ++i)
        {
                fprintf(fileinfo[eval_pawns].fp, "pawns_isolated_mg[%d] = %3d;\n", i, -pawn_isolated[mg][i]);
                fprintf(fileinfo[eval_pawns].fp, "pawns_isolated_eg[%d] = %3d;\n", i, -pawn_isolated[eg][i]);
                for (j = 1; j <= 5; ++j)
                {
                        fprintf(fileinfo[eval_pawns].fp, "pawns_doubled_mg[%d][%d] = %3.0f;\n", i, j, -((double)pawn_doubled[mg][i] / (double)j));
                        fprintf(fileinfo[eval_pawns].fp, "pawns_doubled_eg[%d][%d] = %3.0f;\n", i, j, -((double)pawn_doubled[eg][i] / (double)j));
                }
                for (j = 0; j < 8; ++j)
                {
                        fprintf(fileinfo[eval_pawns].fp, "pawns_connected_mg[%d][%d] = %3d;\n", i, j, pawn_connected[mg][i][j]);
                        fprintf(fileinfo[eval_pawns].fp, "pawns_connected_eg[%d][%d] = %3d;\n", i, j, pawn_connected[eg][i][j]);
                }
                fprintf(fileinfo[eval_pawns].fp, "pawns_backward_mg[%d] = %3d;\n", i, -pawn_backward[mg][i]);
                fprintf(fileinfo[eval_pawns].fp, "pawns_backward_eg[%d] = %3d;\n", i, -pawn_backward[eg][i]);
                fprintf(fileinfo[eval_pawns].fp, "passed_pawn[%d] = %3d;\n", i, passed_pawn[i]);
        }
        fprintf(fileinfo[eval_pawns].fp, "passed_pawn_base_mg = %d;\n", passed_pawn_base[0]);
        fprintf(fileinfo[eval_pawns].fp, "passed_pawn_base_eg = %d;\n", passed_pawn_base[1]);

        for (i = 0; i < 8; ++i)
                for (j = 0; j < 8; ++j)
                {
                        not_passed_mask[i][j] = 0;
                        passed_pawn_path[i][j] = 0;
                }
        for (i = 1; i < 8; ++i)
                for (j = 0; j < 8; ++j)
                        for (row = i + 1; row < 8; ++row)
                        {
                                idx = row << 3 | j;
                                assert(idx >= 0 && idx < 64);
                                passed_pawn_path[i][j] |= shift64[idx];
                                for (col = j - 1; col <= j + 1; ++col)
                                        if (row >= 0 && row < 7 && col >= 0 && col < 8)
                                        {
                                                idx = row << 3 | col;
                                                assert(idx >= 0 && idx < 64);
                                                not_passed_mask[i][j] |= shift64[idx];
                                        }
                        }
        for (i = 0; i < 8; ++i)
                for (j = 0; j < 8; ++j)
                {
                        fprintf(fileinfo[eval_pawns].fp, "not_passed_mask[%d << 3 | %d] = 64'b", i, j);
                        for (b = 63; b >= 0; --b)
                                fprintf(fileinfo[eval_pawns].fp, "%c", (not_passed_mask[i][j] & shift64[b]) == shift64[b] ? '1' : '0');
                        fprintf(fileinfo[eval_pawns].fp, ";\n");
                }


        for (i = 0; i < 8; ++i)
                for (j = 0; j < 8; ++j)
                {
                        fprintf(fileinfo[eval_pawns].fp, "passed_pawn_path[%d << 3 | %d] = 64'b", i, j);
                        for (b = 63; b >= 0; --b)
                                fprintf(fileinfo[eval_pawns].fp, "%c", (passed_pawn_path[i][j] & shift64[b]) == shift64[b] ? '1' : '0');
                        fprintf(fileinfo[eval_pawns].fp, ";\n");
                }

        fprintf(fileinfo[eval_general].fp, "value[`EMPTY_POSN] = 0;\n");
        fprintf(fileinfo[eval_general].fp, "value[`WHITE_PAWN] = %d;\n", PAWN_VALUE);
        fprintf(fileinfo[eval_general].fp, "value[`WHITE_KNIT] = %d;\n", KNIGHT_VALUE);
        fprintf(fileinfo[eval_general].fp, "value[`WHITE_BISH] = %d;\n", BISHOP_VALUE);
        fprintf(fileinfo[eval_general].fp, "value[`WHITE_ROOK] = %d;\n", ROOK_VALUE);
        fprintf(fileinfo[eval_general].fp, "value[`WHITE_QUEN] = %d;\n", QUEEN_VALUE);
        fprintf(fileinfo[eval_general].fp, "value[`WHITE_KING] = `GLOBAL_VALUE_KING;\n");
        fprintf(fileinfo[eval_general].fp, "value[`EMPTY_POSN] = 0;\n");
        fprintf(fileinfo[eval_general].fp, "value[`BLACK_PAWN] = %d;\n", -PAWN_VALUE);
        fprintf(fileinfo[eval_general].fp, "value[`BLACK_KNIT] = %d;\n", -KNIGHT_VALUE);
        fprintf(fileinfo[eval_general].fp, "value[`BLACK_BISH] = %d;\n", -BISHOP_VALUE);
        fprintf(fileinfo[eval_general].fp, "value[`BLACK_ROOK] = %d;\n", -ROOK_VALUE);
        fprintf(fileinfo[eval_general].fp, "value[`BLACK_QUEN] = %d;\n", -QUEEN_VALUE);
        fprintf(fileinfo[eval_general].fp, "value[`BLACK_KING] = -(`GLOBAL_VALUE_KING);\n");
        for (c = 0; c <= 1; ++c)
                for (i = 0; i < 64; ++i)
                {
                        fprintf(fileinfo[eval_general].fp, "pst_mg[`%s_PAWN][%2d] = %3d;\n", c_str[c], i, pval[c][i] * sign[c]);
                        fprintf(fileinfo[eval_general].fp, "pst_mg[`%s_KNIT][%2d] = %3d;\n", c_str[c], i, nval[mg][c][i] * sign[c]);
                        fprintf(fileinfo[eval_general].fp, "pst_mg[`%s_BISH][%2d] = %3d;\n", c_str[c], i, bval[mg][c][i] * sign[c]);
                        fprintf(fileinfo[eval_general].fp, "pst_mg[`%s_QUEN][%2d] = %3d;\n", c_str[c], i, qval[mg][c][i] * sign[c]);
                        fprintf(fileinfo[eval_general].fp, "pst_mg[`%s_KING][%2d] = %3d;\n", c_str[c], i, kval[c][i] * sign[c]);
                        fprintf(fileinfo[eval_general].fp, "pst_eg[`%s_PAWN][%2d] = %3d;\n", c_str[c], i, pval[c][i] * sign[c]);        // use mg
                        fprintf(fileinfo[eval_general].fp, "pst_eg[`%s_KNIT][%2d] = %3d;\n", c_str[c], i, nval[eg][c][i] * sign[c]);
                        fprintf(fileinfo[eval_general].fp, "pst_eg[`%s_BISH][%2d] = %3d;\n", c_str[c], i, bval[eg][c][i] * sign[c]);
                        fprintf(fileinfo[eval_general].fp, "pst_eg[`%s_QUEN][%2d] = %3d;\n", c_str[c], i, qval[eg][c][i] * sign[c]);
                        fprintf(fileinfo[eval_general].fp, "pst_eg[`%s_KING][%2d] = %3d;\n", c_str[c], i, kval[c][i] * sign[c]);        // use mg
                }

        for (i = 0; i < sizeof(fileinfo) / sizeof(fileinfo_t); ++i)
                fclose(fileinfo[i].fp);
        return 0;
}
