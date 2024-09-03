#include <stdint.h>
#include <xparameters.h>

#define EMPTY_POSN 0

#define PIECE_QUEN 1
#define PIECE_ROOK 2
#define PIECE_BISH 3
#define PIECE_PAWN 4
#define PIECE_KNIT 5
#define PIECE_KING 6

#define BLACK_BIT 3 // if set this is a black piece

#define WHITE_PAWN PIECE_PAWN
#define WHITE_ROOK PIECE_ROOK
#define WHITE_KNIT PIECE_KNIT
#define WHITE_BISH PIECE_BISH
#define WHITE_KING PIECE_KING
#define WHITE_QUEN PIECE_QUEN

#define BLACK_PAWN ((1 << BLACK_BIT) | PIECE_PAWN)
#define BLACK_ROOK ((1 << BLACK_BIT) | PIECE_ROOK)
#define BLACK_KNIT ((1 << BLACK_BIT) | PIECE_KNIT)
#define BLACK_BISH ((1 << BLACK_BIT) | PIECE_BISH)
#define BLACK_KING ((1 << BLACK_BIT) | PIECE_KING)
#define BLACK_QUEN ((1 << BLACK_BIT) | PIECE_QUEN)

#define PIECE_BITS 4
#define PIECE_MASK_BITS 15

#define WHITE_ATTACK 0
#define BLACK_ATTACK 1

#define CASTLE_WHITE_SHORT 0
#define CASTLE_WHITE_LONG 1
#define CASTLE_BLACK_SHORT 2
#define CASTLE_BLACK_LONG 3

#define EN_PASSANT_VALID_BIT 3

#define MAX_POSITIONS 218

typedef struct board_t {
	uint32_t board[8];
	uint32_t en_passant_col;
	uint32_t castle_mask;
	uint32_t white_to_move;
} board_t;

extern int transfer_data(void);
extern void print_app_header(void);
extern int start_application(void);
extern void init_platform(void);
extern void cleanup_platform(void);
extern void platform_enable_interrupts(void);

extern uint32_t move_piece(board_t *board, uint32_t row_from, uint32_t col_from, uint32_t row_to, uint32_t col_to);
extern void vchess_init_board(board_t *board);

static inline void
vchess_write(uint32_t reg, uint32_t val)
{
	volatile uint32_t *ptr;

	ptr = (volatile uint32_t *)(uint64_t)(XPAR_CTRL0_AXI_BASEADDR + reg * 4);
	*ptr = val;
}

static inline uint32_t
vchess_read(uint32_t reg)
{
	volatile uint32_t *ptr;
	uint32_t val;

	ptr = (volatile uint32_t *)(uint64_t)(XPAR_CTRL0_AXI_BASEADDR + reg * 4);
	val = *ptr;

	return val;
}

static inline void
vchess_write_control(uint32_t soft_reset, uint32_t new_board_valid, uint32_t clear_moves, uint32_t clear_eval)
{
	uint32_t val;
	
	soft_reset = (soft_reset != 0) << 31;
	new_board_valid = (new_board_valid != 0) << 0;
	clear_moves = (clear_moves != 0) << 1;
	clear_eval = (clear_eval != 0) << 2;

	val = soft_reset | new_board_valid | clear_moves | clear_eval;
	vchess_write(0, val);
}

static inline void
vchess_move_index(uint32_t move_index)
{
	vchess_write(1, move_index);
}

static inline void
vchess_write_board_row(uint32_t row, uint32_t row_pieces)
{
	vchess_write(8 + row, row_pieces);
}

static inline uint32_t
vchess_status(uint32_t *eval_valid, uint32_t *move_ready, uint32_t *moves_ready)
{
	uint32_t val;

	val = vchess_read(0);
	if (eval_valid)
		*eval_valid = (val & (1 << 5)) != 0;
	if (move_ready)
		*move_ready = (val & (1 << 4)) != 0;
	if (moves_ready)
		*moves_ready = (val & (1 << 3)) != 0;

	return val;
}

static inline uint32_t
vchess_read_move_row(uint32_t row)
{
	uint32_t val;
	
	val = vchess_read(172 + row);

	return val;
}

static inline uint64_t
vchess_read_white_is_attacking(void)
{
	uint64_t bits_lo, bits_hi, val;

	bits_lo = vchess_read(128);
	bits_hi = vchess_read(129);

	val = bits_hi << 31 | bits_lo;

	return val;
}

static inline uint64_t
vchess_read_black_is_attacking(void)
{
	uint64_t bits_lo, bits_hi, val;

	bits_lo = vchess_read(130);
	bits_hi = vchess_read(131);

	val = bits_hi << 31 | bits_lo;

	return val;
}

static inline uint32_t
vchess_board_status0(uint32_t *black_in_check, uint32_t *white_in_check, uint32_t *capture)
{
	uint32_t val;

	val = vchess_read(132);
	if (capture)
		*capture = (val & (1 << 0)) != 0;
	if (white_in_check)
		*white_in_check = (val & (1 << 1)) != 0;
	if (black_in_check)
		*black_in_check = (val & (1 << 2)) != 0;

	return val;
}

static inline uint32_t
vchess_board_status1(uint32_t *white_to_move, uint32_t *castle_mask, uint32_t *en_passant_col)
{
	uint32_t val;

	val = vchess_read(133);
	if (white_to_move)
		*white_to_move = (val & (1 << 8)) != 0;
	if (castle_mask)
		*castle_mask = (val & (0xF << 4)) >> 4;
	if (en_passant_col)
		*en_passant_col = val & 0xF;

	return val;
}

static inline int32_t
vchess_eval(void)
{
	int32_t val;

	val = (int32_t)vchess_read(134); // check this is sign extended

	return val;
}
