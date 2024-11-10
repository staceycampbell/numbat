#include <stdint.h>
#include <assert.h>
#include <xtime_l.h>
#include <xuartps.h>

#if ! defined(EXCLUDE_VITIS)
#include <xparameters.h>
#else
#define XPAR_CTRL0_AXI_BASEADDR 0
#endif

#define EMPTY_POSN 0

#define PIECE_QUEN 1
#define PIECE_ROOK 2
#define PIECE_BISH 3
#define PIECE_PAWN 4
#define PIECE_KNIT 5
#define PIECE_KING 6

#define BLACK_BIT 3             // if set this is a black piece

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

#define GLOBAL_VALUE_KING 40000

#define MAX_POSITIONS 219
#define GAME_MAX 2048           // maximum half moves
#define BUF_SIZE 65536

#define TRANS_EXACT 0
#define TRANS_LOWER_BOUND 1
#define TRANS_UPPER_BOUND 2

#define BOOK_RANDOM 0
#define BOOK_MOST_COMMON 1
#define BOOK_RANDOM_COMMON 2

#define RESULT_DRAW 0
#define RESULT_WHITE_WIN 1
#define RESULT_BLACK_WIN 2
#define RESULT_NONE 3

#define TC_OK 0
#define TC_EXPIRED 1

#define UCI_SEARCH_STOP 0
#define UCI_SEARCH_CONT 1

typedef struct tc_t
{
        uint32_t valid;
        uint32_t side;
        int32_t main;
        int32_t increment;
        int32_t move_number;
        int32_t main_remaining[2];
        XTime control_start;
} tc_t;

typedef struct uci_t
{
        uint8_t row_from;
        uint8_t col_from;
        uint8_t row_to;
        uint8_t col_to;
        uint8_t promotion;
} uci_t;

typedef struct book_t
{
        uint64_t hash;
        uint32_t count;
        uint16_t hash_extra;
        uci_t uci;
} book_t;

typedef struct board_t
{
        uint32_t board[8];
        int32_t eval;
        uint32_t half_move_clock;
        uint32_t full_move_number;
        uint32_t en_passant_col;
        uint32_t castle_mask;
        uint32_t white_to_move;
        uint32_t black_in_check;
        uint32_t white_in_check;
        uint32_t capture;
        uint32_t thrice_rep;
        uint32_t fifty_move;
        uci_t uci;
} board_t;

typedef struct trans_t
{
        uint32_t entry_valid;
        int32_t depth;
        int32_t eval;
        uint32_t flag;
} trans_t;

static inline void
vchess_write(uint32_t reg, uint32_t val)
{
        volatile uint32_t *ptr;

        ptr = (volatile uint32_t *)(uint64_t) (XPAR_CTRL0_AXI_BASEADDR + reg * 4);
        *ptr = val;
}

static inline void
vchess_write64(uint32_t reg, uint64_t val)
{
        volatile uint64_t *ptr;

        ptr = (volatile uint64_t *)(uint64_t) (XPAR_CTRL0_AXI_BASEADDR + reg * 4);
        *ptr = val;
}

static inline uint32_t
vchess_read(uint32_t reg)
{
        volatile uint32_t *ptr;
        uint32_t val;

        ptr = (volatile uint32_t *)(uint64_t) (XPAR_CTRL0_AXI_BASEADDR + reg * 4);
        val = *ptr;

        return val;
}

static inline int32_t
vchess_initial_material(void)
{
        int32_t material;

        material = (int32_t) vchess_read(141);

        return material;
}

static inline uint32_t
vchess_random(void)
{
        return vchess_read(254);
}

static inline void
vchess_trans_store(int32_t depth, uint32_t flag, int32_t eval)
{
        uint32_t val;
        uint32_t depth32;
        uint8_t depth_u8;
        const uint32_t entry_store = 1 << 1;

        depth_u8 = (uint8_t) depth;
        depth32 = depth_u8;
        vchess_write(521, (uint32_t) eval);

        val = depth32 << 8 | flag << 2 | entry_store;
        vchess_write(520, val);
        val = depth32 << 8 | flag << 2;
        vchess_write(520, val);
}

static inline void
vchess_trans_lookup(void)
{
        const uint32_t entry_lookup = 1 << 0;

        vchess_write(520, entry_lookup);
        vchess_write(520, 0);
}

static inline void
vchess_trans_read(uint32_t * collision, int32_t * eval, int32_t * depth, uint32_t * flag, uint32_t * entry_valid, uint32_t * trans_idle)
{
        uint32_t val;

        if (eval)
                *eval = (int32_t) vchess_read(514);
        val = vchess_read(512);
        if (trans_idle)
                *trans_idle = val & 0x1;
        if (entry_valid)
                *entry_valid = (val >> 1) & 0x1;
        if (flag)
                *flag = (val >> 2) & 0x3;
        if (depth)
                *depth = (int8_t) ((val >> 8) & 0xFF);
        if (collision)
                *collision = (val >> 9) & 0x1;
}

static inline void
vchess_trans_hash_only(void)
{
        const uint32_t hash_only = 1 << 4;

        vchess_write(520, hash_only);
        vchess_write(520, 0);
}

static inline void
vchess_trans_clear_table(void)
{
        const uint32_t clear_trans = 1 << 5;

        vchess_write(520, clear_trans);
        vchess_write(520, 0);
}

static inline uint64_t
vchess_trans_hash(uint16_t * bits_79_64)
{
        uint64_t bits_31_0, bits_63_32;
        uint64_t hash;

        bits_31_0 = vchess_read(522);
        bits_63_32 = vchess_read(523);
        if (bits_79_64)
                *bits_79_64 = vchess_read(524);
        hash = bits_63_32 << 32 | bits_31_0;

        return hash;
}

static inline int32_t
vchess_trans_idle_wait(void)
{
        uint32_t counter;
        uint32_t trans_idle;

        counter = 0;
        do
        {
                vchess_trans_read(0, 0, 0, 0, 0, &trans_idle);
                ++counter;
        }
        while (counter < 100 && !trans_idle);

        return trans_idle;
}

static inline uint32_t
vchess_misc_status(void)
{
        return vchess_read(255);
}

static inline void
vchess_write_control(uint32_t soft_reset, uint32_t new_board_valid, uint32_t clear_moves, uint32_t use_random_bit)
{
        uint32_t val;

        soft_reset = (soft_reset != 0) << 31;
        use_random_bit = (use_random_bit != 0) << 30;
        new_board_valid = (new_board_valid != 0) << 0;
        clear_moves = (clear_moves != 0) << 1;

        val = soft_reset | new_board_valid | clear_moves;
        vchess_write(0, val);
}

static inline void
vchess_write_board_misc(uint32_t white_to_move, uint32_t castle_mask, uint32_t en_passant_col)
{
        uint32_t val;

        white_to_move = (white_to_move != 0) << 8;
        castle_mask = (castle_mask & 0xF) << 4;
        en_passant_col &= 0xF;

        val = white_to_move | castle_mask | en_passant_col;
        vchess_write(2, val);
}

static inline void
vchess_move_index(uint32_t move_index)
{
        vchess_write(1, move_index);
}

static inline void
vchess_capture_moves(uint32_t capture_moves)
{
        vchess_write(4, capture_moves);
}

static inline void
vchess_write_board_row(uint32_t row, uint32_t row_pieces)
{
        vchess_write(8 + row, row_pieces);
}

static inline void
vchess_write_board_two_rows(uint32_t row0, uint64_t row_pieces0, uint64_t row_pieces1)
{
        uint64_t row_pieces;

        row_pieces = row_pieces1 << (uint64_t) 32 | row_pieces0;
        vchess_write64(8 + row0, row_pieces);
}

static inline uint32_t
vchess_status(uint32_t * move_ready, uint32_t * moves_ready, uint32_t * mate, uint32_t * stalemate,
              uint32_t * thrice_rep, uint32_t * am_idle, uint32_t * fifty_move, uint32_t * insufficient, uint32_t * check)
{
        uint32_t val;

        val = vchess_read(0);
        if (check)
                *check = (val & (1 << 10)) != 0;
        if (insufficient)
                *insufficient = (val & (1 << 9)) != 0;
        if (fifty_move)
                *fifty_move = (val & (1 << 8)) != 0;
        if (am_idle)
                *am_idle = (val & (1 << 7)) != 0;
        if (thrice_rep)
                *thrice_rep = (val & (1 << 6)) != 0;
        if (mate)
                *mate = (val & (1 << 5)) != 0;
        if (stalemate)
                *stalemate = (val & (1 << 4)) != 0;
        if (move_ready)
                *move_ready = (val & (1 << 3)) != 0;
        if (moves_ready)
                *moves_ready = (val & (1 << 2)) != 0;

        return val >> 4;
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
vchess_board_status0(uint32_t * black_in_check, uint32_t * white_in_check, uint32_t * capture, uint32_t * thrice_rep, uint32_t * fifty_move)
{
        uint32_t val;

        val = vchess_read(132);
        if (capture)
                *capture = (val & (1 << 0)) != 0;
        if (white_in_check)
                *white_in_check = (val & (1 << 1)) != 0;
        if (black_in_check)
                *black_in_check = (val & (1 << 2)) != 0;
        if (thrice_rep)
                *thrice_rep = (val & (1 << 3)) != 0;
        if (fifty_move)
                *fifty_move = (val & (1 << 4)) != 0;

        return val;
}

static inline uint32_t
vchess_board_status1(uint32_t * white_to_move, uint32_t * castle_mask, uint32_t * en_passant_col)
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
vchess_move_eval(void)
{
        int32_t val;

        val = (int32_t) vchess_read(134);

        return val;
}

static inline int32_t
vchess_initial_eval(void)
{
        int32_t val;

        val = (int32_t) vchess_read(136);

        return val;
}

static inline uint32_t
vchess_move_count(void)
{
        int32_t val;

        val = vchess_read(135);

        return val;
}

static inline void
vchess_repdet_write(uint32_t addr)
{
        vchess_write(0x12, 1 << 31 | addr);     // toggle write enable
        vchess_write(0x12, addr);
}

static inline void
vchess_repdet_depth(uint32_t depth)
{
        vchess_write(0x10, depth);
}

static inline void
vchess_repdet_castle_mask(uint32_t castle_mask)
{
        vchess_write(0x11, castle_mask);
}

static inline void
vchess_repdet_board(const uint32_t board[8])
{
        uint32_t i;
        uint64_t row_pieces0, row_pieces1, row_pieces;

        for (i = 0; i < 8; i += 2)
        {
                row_pieces0 = board[i + 0];
                row_pieces1 = board[i + 1];
                row_pieces = row_pieces1 << (uint64_t) 32 | row_pieces0;
                vchess_write64(0x18 + i, row_pieces);
        }
}

static inline void
vchess_write_half_move(uint32_t half_move)
{
        vchess_write(0x3, half_move);
}

static inline uint32_t
vchess_read_half_move(void)
{
        uint32_t half_move;

        half_move = vchess_read(138);

        return half_move;
}

static inline void
vchess_reset_all_moves(void)
{
        vchess_write_control(1, 0, 0, 0);       // soft reset, new board valid, clear moves
        vchess_write_control(0, 0, 0, 0);
}

static inline uint32_t
uci_match(const uci_t * a, const uci_t * b)
{
        uint32_t ret;

        ret = a->row_from == b->row_from && a->row_to == b->row_to && a->col_from == b->col_from &&
                a->col_to == b->col_to && a->promotion == b->promotion;

        return ret;
}

static inline uint32_t
ui_data_available(void)
{
	uint32_t status;

	status = XUartPs_IsReceiveData(XPAR_XUARTPS_0_BASEADDR);

	return status;
}

extern void print_app_header(void);
extern int start_application(void);
extern void init_platform(void);
extern void cleanup_platform(void);
extern void platform_enable_interrupts(void);
extern uint32_t cmd_transfer_data(uint8_t cmdbuf[512], uint32_t * index);

extern void vchess_init(void);
extern uint32_t vchess_move_piece(board_t * board, uint32_t row_from, uint32_t col_from, uint32_t row_to, uint32_t col_to);
extern void vchess_init_board(board_t * board);
extern void vchess_write_board_basic(const board_t * board);
extern void vchess_write_board_wait(const board_t * board);
extern void vchess_init_board(board_t * board);
extern void vchess_print_board(const board_t * board, uint32_t initial_board);
extern uint32_t vchess_read_board(board_t * board, uint32_t index);
extern void vchess_place(board_t * board, uint32_t row, uint32_t col, uint32_t piece);
extern uint32_t vchess_get_piece(const board_t * board, uint32_t row, uint32_t col);
extern void vchess_repdet_entry(uint32_t index, uint32_t board[8], uint32_t castle_mask);
extern void vchess_read_uci(uci_t * uci);
extern void vchess_uci_string(const uci_t * uci, char *str);

extern board_t nm_top(board_t game[GAME_MAX], uint32_t game_moves, const tc_t * tc);

extern uint32_t sample_game(board_t game[GAME_MAX]);
extern void do_both(void);

extern void process_cmd(uint8_t cmd[BUF_SIZE]);
extern void fen_print(const board_t * board);
extern uint32_t fen_board(uint8_t buffer[BUF_SIZE], board_t * board);

extern void uci_input_reset(void);
extern uint32_t uci_input_poll(void);
extern void uci_init(void);
extern int32_t uci_move(char *p);
extern void uci_print_game(uint32_t result);

extern void trans_clear_table(void);
extern void trans_lookup(trans_t * trans, uint32_t * collision);
extern void trans_store(const trans_t * trans);

extern void book_build(void);
extern void book_format_media(void);
extern int32_t book_open(void);
extern uint32_t book_move(uint16_t hash_extra, uint64_t hash, uint32_t sel_flag, uci_t * uci);
extern uint32_t book_game_move(const board_t * board);
extern void book_print_entry(book_t * entry);

extern void tc_init(tc_t * tc, int32_t main, int32_t increment);
extern uint32_t tc_clock_toggle(tc_t * tc);
extern void tc_ignore(tc_t * tc);
extern void tc_display(const tc_t * tc);
