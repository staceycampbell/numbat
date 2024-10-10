#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>
#define EXCLUDE_VITIS 1
#include "../vivado/src/vchess.h"

#define TABLE_SIZE_LOG2 23 // 2^23 * 512 bits

static inline void
place(board_t *board, uint32_t row, uint32_t col, uint32_t piece)
{
        uint32_t row_contents;
        uint32_t shift;

        shift = col * PIECE_BITS;
        row_contents = board->board[row];
        row_contents &= ~(0xF << shift);
        row_contents |= piece << shift;
        board->board[row] = row_contents;
}

static void
local_fen_board(char buffer[4096], board_t *board)
{
	int row, col, i, stop_col;

	row = 7;
	col = 0;
	i = 0;
	while (i < 4096 && buffer[i] != '\0' && ! (buffer[i] == ' ' || buffer[i] == '\t'))
	{
		switch (buffer[i])
		{
		case 'r' :
			place(board, row, col, BLACK_ROOK);
			++col;
			break;
		case 'n' :
			place(board, row, col, BLACK_KNIT);
			++col;
			break;
		case 'b' :
			place(board, row, col, BLACK_BISH);
			++col;
			break;
		case 'q' :
			place(board, row, col, BLACK_QUEN);
			++col;
			break;
		case 'k' :
			place(board, row, col, BLACK_KING);
			++col;
			break;
		case 'p' :
			place(board, row, col, BLACK_PAWN);
			++col;
			break;
		case 'R' :
			place(board, row, col, WHITE_ROOK);
			++col;
			break;
		case 'N' :
			place(board, row, col, WHITE_KNIT);
			++col;
			break;
		case 'B' :
			place(board, row, col, WHITE_BISH);
			++col;
			break;
		case 'Q' :
			place(board, row, col, WHITE_QUEN);
			++col;
			break;
		case 'K' :
			place(board, row, col, WHITE_KING);
			++col;
			break;
		case 'P' :
			place(board, row, col, WHITE_PAWN);
			++col;
			break;
		case '/' :
			col = 0;
			--row;
			break;
		default :
			assert(buffer[i] >= '1' && buffer[i] <= '8');
			stop_col = col + buffer[i] - '1';
			while (col <= stop_col)
			{
				place(board, row, col, EMPTY_POSN);
				++col;
			}
			break;
		}
		++i;
	}
	++i;
	assert(i < 4096 && (buffer[i] == 'w' || buffer[i] == 'b'));
	board->white_to_move = buffer[i] == 'w';
	i += 2;
	board->castle_mask = 0;
	while (i < 4096 && buffer[i] != '\0' && ! (buffer[i] == ' ' || buffer[i] == '\t'))
	{
		switch (buffer[i])
		{
		case 'K' :
			board->castle_mask |= 1 << CASTLE_WHITE_SHORT;
			break;
		case 'Q' :
			board->castle_mask |= 1 << CASTLE_WHITE_LONG;
			break;
		case 'k' :
			board->castle_mask |= 1 << CASTLE_BLACK_SHORT;
			break;
		case 'q' :
			board->castle_mask |= 1 << CASTLE_BLACK_LONG;
			break;
		case '-' :
			board->castle_mask = 0;
			break;
		default :
			assert(0);
			break;
		}
		++i;
	}
	++i;
	assert(i < 4096);
// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
	assert(buffer[i] == '-' || (buffer[i] >= 'a' && buffer[i] <= 'h'));
	if (buffer[i] == '-')
        {
		board->en_passant_col = 0 << EN_PASSANT_VALID_BIT;
                ++i;
        }
	else
        {
		board->en_passant_col = (1 << EN_PASSANT_VALID_BIT) | (buffer[i] - 'a');
                i += 2;
        }
        if (sscanf((char *)&buffer[i], "%d %d", &board->half_move_clock, &board->full_move_number) != 2)
                printf("%s: bad FEN half move clock or ful move number%s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
}

int
main(int argc, char *argv[])
{
        board_t board;
        char buffer[4096];

        while (fgets(buffer, sizeof(buffer), stdin))
                if (strlen(buffer) > 1)
                        local_fen_board(buffer, &board);
        
        return 0;
}
