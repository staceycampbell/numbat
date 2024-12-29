#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>
#include <memory.h>
#include <malloc.h>
#define EXCLUDE_VITIS 1
#include "../vivado/src/numbat.h"

#pragma GCC optimize ("O3")

#define TABLE_SIZE_LOG2 25      // 2^25 * 512 bits for 2GByte DDR4
// #define TABLE_SIZE_LOG2 16      // 2^16 * 360 bits for 27Mbit URAM
#define TABLE_SIZE (1 << TABLE_SIZE_LOG2)

static uint32_t zob_rand_board[8][8][BLACK_KING + 1];
static uint32_t zob_rand_btm;
static uint32_t zob_rand_en_passant_col[2][16];
static uint32_t zob_rand_castle_mask[16];

static uint32_t
get_piece(board_t *board, uint32_t row, uint32_t col)
{
        uint32_t row_contents, shift, piece;

        row_contents = board->board[row];
        shift = col * PIECE_BITS;
        piece = (row_contents >> shift) & 0xF;

        return piece;
}

static void
zobrist_init(uint32_t seed)
{
        int32_t row, col, piece, i, color;

        srandom(seed);

        for (row = 0; row < 8; ++row)
                for (col = 0; col < 8; ++col)
                        for (piece = 1; piece <= BLACK_KING; ++piece)
                                zob_rand_board[row][col][piece] = random();
        zob_rand_btm = random();
        for (color = 0; color <= 1; ++color)
                for (col = 0; col < 16; ++col)
                        zob_rand_en_passant_col[color][col] = random();
        for (i = 0; i < 16; ++i)
                zob_rand_castle_mask[i] = random();
}

static inline uint32_t
hash_calc(board_t * board)
{
        uint32_t hash, row, col, piece;

        hash = 0;
        if (! board->white_to_move)
                hash ^= zob_rand_btm;

        for (row = 0; row < 8; ++row)
                for (col = 0; col < 8; ++col)
                {
                        piece = get_piece(board, row, col);
                        if (piece != EMPTY_POSN)
                                hash ^= zob_rand_board[row][col][piece];
                }
        hash ^= zob_rand_en_passant_col[board->white_to_move ? 0 : 1][board->en_passant_col];
        hash ^= zob_rand_castle_mask[board->castle_mask];

        hash &= TABLE_SIZE - 1;

        return hash;
}

static inline void
place(board_t * board, uint32_t row, uint32_t col, uint32_t piece)
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
local_fen_board(char buffer[4096], board_t * board)
{
        int row, col, i, stop_col;

        row = 7;
        col = 0;
        i = 0;
        while (i < 4096 && buffer[i] != '\0' && !(buffer[i] == ' ' || buffer[i] == '\t'))
        {
                switch (buffer[i])
                {
                case 'r':
                        place(board, row, col, BLACK_ROOK);
                        ++col;
                        break;
                case 'n':
                        place(board, row, col, BLACK_KNIT);
                        ++col;
                        break;
                case 'b':
                        place(board, row, col, BLACK_BISH);
                        ++col;
                        break;
                case 'q':
                        place(board, row, col, BLACK_QUEN);
                        ++col;
                        break;
                case 'k':
                        place(board, row, col, BLACK_KING);
                        ++col;
                        break;
                case 'p':
                        place(board, row, col, BLACK_PAWN);
                        ++col;
                        break;
                case 'R':
                        place(board, row, col, WHITE_ROOK);
                        ++col;
                        break;
                case 'N':
                        place(board, row, col, WHITE_KNIT);
                        ++col;
                        break;
                case 'B':
                        place(board, row, col, WHITE_BISH);
                        ++col;
                        break;
                case 'Q':
                        place(board, row, col, WHITE_QUEN);
                        ++col;
                        break;
                case 'K':
                        place(board, row, col, WHITE_KING);
                        ++col;
                        break;
                case 'P':
                        place(board, row, col, WHITE_PAWN);
                        ++col;
                        break;
                case '/':
                        col = 0;
                        --row;
                        break;
                default:
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
        while (i < 4096 && buffer[i] != '\0' && !(buffer[i] == ' ' || buffer[i] == '\t'))
        {
                switch (buffer[i])
                {
                case 'K':
                        board->castle_mask |= 1 << CASTLE_WHITE_SHORT;
                        break;
                case 'Q':
                        board->castle_mask |= 1 << CASTLE_WHITE_LONG;
                        break;
                case 'k':
                        board->castle_mask |= 1 << CASTLE_BLACK_SHORT;
                        break;
                case 'q':
                        board->castle_mask |= 1 << CASTLE_BLACK_LONG;
                        break;
                case '-':
                        board->castle_mask = 0;
                        break;
                default:
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

static inline uint32_t
empty_entry(board_t * board)
{
        uint32_t sum, i;

        i = 0;
        sum = 0;
        while (i < 8 && sum == 0)
        {
                sum += board->board[i];
                ++i;
        }

        return sum == 0;
}

static inline uint32_t
board_match(board_t * a, board_t * b)
{
        uint32_t i;

        for (i = 0; i < 8; ++i)
                if (a->board[i] != b->board[i])
                        return 0;
        if (a->castle_mask != b->castle_mask)
                return 0;
        if (a->en_passant_col != b->en_passant_col)
                return 0;
        if (a->white_to_move != b->white_to_move)
                return 0;

        return 1;
}

static int
compuint32(const void *p1, const void *p2)
{
        uint32_t n1, n2;

        n1 = *(uint32_t *) p1;
        n2 = *(uint32_t *) p2;

        return n1 < n2;
}

int
main(int argc, char *argv[])
{
        uint32_t i, j, hash, total_collisions, total_hits, worst_collision, total, entry;
        uint32_t median_collisions, seed;
        double average_collisions;
        board_t board;
        char buffer[4096];
        uint32_t *collision;
        board_t *hash_table;
        double collision_percent, capacity;

        assert((collision = (uint32_t *) malloc(TABLE_SIZE * sizeof(uint32_t))) != 0);
        assert((hash_table = (board_t *) malloc(TABLE_SIZE * sizeof(board_t))) != 0);
        for (i = 0; i < TABLE_SIZE; ++i)
        {
                collision[i] = 0;
                for (j = 0; j < 8; ++j)
                        hash_table[i].board[j] = 0;
        }
        if (argc == 2)
                seed = strtoul(argv[1], 0, 0);
        else
                seed = 1;
        zobrist_init(seed);
        total_collisions = 0;
        total_hits = 0;
        total = 0;
        while (fgets(buffer, sizeof(buffer), stdin))
                if (strlen(buffer) > 1)
                {
                        ++total;
                        local_fen_board(buffer, &board);
                        hash = hash_calc(&board);
                        if (empty_entry(&hash_table[hash]))
                                hash_table[hash] = board;
                        else if (board_match(&hash_table[hash], &board))
                                ++total_hits;
                        else
			{
                                ++collision[hash];
                                ++total_collisions;
			}
                }
        worst_collision = 0;
        entry = 0;
        average_collisions = 0;
        for (i = 0; i < TABLE_SIZE; ++i)
        {
                if (collision[i] > worst_collision)
                {
                        entry = i;
                        worst_collision = collision[i];
                }
                average_collisions += collision[i];
        }
        average_collisions /= (double)TABLE_SIZE;
        qsort(collision, TABLE_SIZE, sizeof(uint32_t), compuint32);
        median_collisions = collision[TABLE_SIZE / 2];

        collision_percent = (double)total_collisions / (double)total *100.0;
        capacity = (double)total / (double)TABLE_SIZE * 100.0;

        printf("seed=%u total=%u, total_hits=%u, total_collisions=%u, worst_collision=%u (entry=%u)\n",
               seed, total, total_hits, ++total_collisions, worst_collision, entry);
        printf("median_collisions=%u, average_collisions=%.5f, collision_percent=%.1f%%, capacity=%.1f%%\n",
               median_collisions, average_collisions, collision_percent, capacity);

        return 0;
}
