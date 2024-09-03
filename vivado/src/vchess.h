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
