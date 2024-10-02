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

uint32_t
vchess_get_piece(board_t *board, uint32_t row, uint32_t col)
{
        uint32_t row_contents, shift, piece;

        row_contents = board->board[row];
        shift = col * PIECE_BITS;
        piece = (row_contents >> shift) & 0xF;

        return piece;
}

//typedef struct uci_t {
//	uint8_t row_from;
//	uint8_t col_from;
//	uint8_t row_to;
//	uint8_t col_to;
//	uint8_t promotion;
//} uci_t;
//
//typedef struct board_t {
//        uint32_t board[8];
//        int32_t eval;
//        uint32_t half_move_clock;
//        uint32_t full_move_number;
//        uint32_t en_passant_col;
//        uint32_t castle_mask;
//        uint32_t white_to_move;
//        uint32_t black_in_check;
//        uint32_t white_in_check;
//        uint32_t capture;
//        uint32_t thrice_rep;
//        uint32_t fifty_move;
//	uci_t uci;
//} board_t;

void
move_string(char *p)
{
        int32_t col_from, row_from, col_to, row_to;
        uint32_t piece, promotion, piece_type;
        board_t *previous_board, next_board;

        previous_board = &game[game_moves - 1];
        next_board = *previous_board;
        next_board.capture = 0;
        next_board.white_to_move = ! previous_board->white_to_move;
        if (next_board.white_to_move)
                ++next_board.full_move_number;
        
        col_from = p[0] - 'a';
        row_from = p[1] - '1';
        col_to = p[2] - 'a';
        row_to = p[3] - '1';
        switch (p[4])
        {
        case 'Q' :
                promotion = PIECE_QUEN;
                break;
        case 'N' :
                promotion = PIECE_KNIT;
                break;
        case 'B' :
                promotion = PIECE_BISH;
                break;
        case 'R' :
                promotion = PIECE_ROOK;
                break;
        case '\0' :
                promotion = EMPTY_POSN;
                break;
        default :
                fprintf(stderr, "%s: problems (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                exit(1);
        }
        if (promotion != EMPTY_POSN)
                if (previous_board->white_to_move)
                        promotion |= 0 << BLACK_BIT;
                else
                        promotion |= 1 << BLACK_BIT;
        
        piece = vchess_get_piece(previous_board, row_from, col_from);
        piece_type = piece & ~(1 << BLACK_BIT);

        // unconditionally vacate "from" square
        vchess_place(&next_board, row_from, col_from, EMPTY_POSN);

        if (piece == WHITE_ROOK && row_from == 0)
        {
                if (col_from == 7)
                        next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_WHITE_SHORT);
                else if (col_from == 0)
                        next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_WHITE_LONG);
        }
        else if (piece == BLACK_ROOK && row_from == 7)
        {
                if (col_from == 7)
                        next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_BLACK_SHORT);
                else if (col_from == 0)
                        next_board.castle_mask = previous_board->castle_mask & ~(1 << CASTLE_BLACK_LONG);
        } else if (piece == WHITE_KING)
                next_board.castle_mask = previous_board->castle_mask &
                        ~(1 << CASTLE_WHITE_SHORT | 1 << CASTLE_WHITE_LONG);
        else if (piece == BLACK_KING)
                next_board.castle_mask = previous_board->castle_mask &
                        ~(1 << CASTLE_BLACK_SHORT | 1 << CASTLE_BLACK_LONG);

        // castling
        if (piece == WHITE_KING && row_from == 0 && row_to == 0 && col_from == 4 && col_to == 6)
        {
                vchess_place(&next_board, row_from, 7, EMPTY_POSN);
                vchess_place(&next_board, row_from, 5, WHITE_ROOK);
                vchess_place(&next_board, row_from, 6, WHITE_KING);
                next_board.half_move_clock = 0;
        }
        else if (piece == WHITE_KING && row_from == 0 && row_to == 0 && col_from == 4 && col_to == 2)
        {
                vchess_place(&next_board, row_from, 0, EMPTY_POSN);
                vchess_place(&next_board, row_from, 1, EMPTY_POSN);
                vchess_place(&next_board, row_from, 3, WHITE_ROOK);
                vchess_place(&next_board, row_from, 2, WHITE_KING);
                next_board.half_move_clock = 0;
        }
        else if (piece == BLACK_KING && row_from == 7 && row_to == 7 && col_from == 4 && col_to == 6)
        {
                vchess_place(&next_board, row_from, 7, EMPTY_POSN);
                vchess_place(&next_board, row_from, 5, BLACK_ROOK);
                vchess_place(&next_board, row_from, 6, BLACK_KING);
                next_board.half_move_clock = 0;
        }
        else if (piece == BLACK_KING && row_from == 0 && row_to == 0 && col_from == 4 && col_to == 2)
        {
                vchess_place(&next_board, row_from, 0, EMPTY_POSN);
                vchess_place(&next_board, row_from, 1, EMPTY_POSN);
                vchess_place(&next_board, row_from, 3, WHITE_ROOK);
                vchess_place(&next_board, row_from, 2, WHITE_KING);
                next_board.half_move_clock = 0;
        }
        // en-passant
        else if (piece == WHITE_PAWN && vchess_get_piece(previous_board, row_to, col_to) == EMPTY_POSN && col_from != col_to)
        {
                vchess_place(&next_board, row_to, col_to, WHITE_PAWN);
                vchess_place(&next_board, row_to, col_to - 1, EMPTY_POSN);
                next_board.capture = 1;
                next_board.half_move_clock = 0;
        }
        else if (piece == BLACK_PAWN && vchess_get_piece(previous_board, row_to, col_to) == EMPTY_POSN && col_from != col_to)
        {
                vchess_place(&next_board, row_to, col_to, BLACK_PAWN);
                vchess_place(&next_board, row_to, col_to + 1, EMPTY_POSN);
                next_board.capture = 1;
                next_board.half_move_clock = 0;
        }
        // promotion
        else if (piece == WHITE_PAWN && row_to == 7)
        {
                vchess_place(&next_board, 7, col_to, promotion);
                next_board.capture = vchess_get_piece(previous_board, 7, col_to) != EMPTY_POSN;
                next_board.half_move_clock = 0;
        }
        else if (piece == BLACK_PAWN && row_to == 0)
        {
                vchess_place(&next_board, 0, col_to, promotion);
                next_board.capture = vchess_get_piece(previous_board, 7, col_to) != EMPTY_POSN;
                next_board.half_move_clock = 0;
        }
        // all other moves
        else
        {
                vchess_place(&next_board, row_to, col_to, piece);
                next_board.capture = vchess_get_piece(previous_board, row_to, col_to) != EMPTY_POSN;
                if (! next_board.capture && ! (piece_type == PIECE_PAWN))
                        ++next_board.half_move_clock;
        }
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
        game[0].half_move_clock = 0;
        game[0].full_move_number = 1;

        game_moves = 1;

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
                        if (strlen(p) > 1)
                                move_string(p);
                        p = next;
                }
        } while (next);
        printf("\n");

        return 0;
}
