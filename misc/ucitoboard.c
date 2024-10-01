#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#define EXCLUDE_VITIS 1
#include "../vivado/src/vchess.h"

static board_t game[GAME_MAX];
static uint32_t game_moves;

void
vchess_place(board_t *board, uint32_t row, uint32_t col, uint32_t piece)
{
        uint32_t row_contents;
        uint32_t shift;

        shift = col * PIECE_BITS;
        row_contents = board->board[row];
        row_contents &= ~(0xF << shift);
        row_contents |= piece << shift;
        board->board[row] = row_contents;
}

int
main(int argc, char *argv[])
{
        int i, j;
        char buffer[65536];
        char *p, *next;
        size_t buffer_count;

        for (i = 2; i <= 5; ++i)
                for (j = 0; j < 8; ++j)
                        vchess_place(&game[0], i, j, EMPTY_POSN);
        for (j = 0; j < 8; ++j)
        {
                vchess_place(&game[0], 1, j, WHITE_PAWN);
                vchess_place(&game[0], 6, j, BLACK_PAWN);
        }
        vchess_place(&game[0], 0, 0, WHITE_ROOK);
        vchess_place(&game[0], 0, 1, WHITE_KNIT);
        vchess_place(&game[0], 0, 2, WHITE_BISH);
        vchess_place(&game[0], 0, 3, WHITE_QUEN);
        vchess_place(&game[0], 0, 4, WHITE_KING);
        vchess_place(&game[0], 0, 5, WHITE_BISH);
        vchess_place(&game[0], 0, 6, WHITE_KNIT);
        vchess_place(&game[0], 0, 7, WHITE_ROOK);

        vchess_place(&game[0], 7, 0, BLACK_ROOK);
        vchess_place(&game[0], 7, 1, BLACK_KNIT);
        vchess_place(&game[0], 7, 2, BLACK_BISH);
        vchess_place(&game[0], 7, 3, BLACK_QUEN);
        vchess_place(&game[0], 7, 4, BLACK_KING);
        vchess_place(&game[0], 7, 5, BLACK_BISH);
        vchess_place(&game[0], 7, 6, BLACK_KNIT);
        vchess_place(&game[0], 7, 7, BLACK_ROOK);

        game[0].en_passant_col = 0 << EN_PASSANT_VALID_BIT;
        game[0].castle_mask = 0xF;
        game[0].white_to_move = 1;

        game_moves = 0;

        buffer_count = fread(buffer, 1, sizeof(buffer), stdin);
        if (buffer_count == 0)
        {
                fprintf(stderr, "%s: no data read\n", argv[0]);
                exit(1);
        }
        i = buffer_count - 1;
        while (i >= 0 && buffer[i] != ']')
                --i;
        if (i < 0)
        {
                fprintf(stderr, "%s: backwards search for ']' failed\n", argv[0]);
                exit(1);
        }
        ++i;
        while (i < buffer_count && isspace(buffer[i]))
                ++i;
        if (i == buffer_count)
        {
                fprintf(stderr, "%s: could not find UCI move list\n", argv[0]);
                exit(1);
        }
        p = &buffer[i];
        do
        {
                next = p;
                p = strsep(&next, " \n\t\r");
                if (p)
                {
                        printf("'%s' ", p);
                        p = next;
                }
        }while (next);
        
        return 0;
}
