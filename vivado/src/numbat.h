// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <stdio.h>
#include <stdint.h>
#include <assert.h>

#define UCI_TCP_COMMS 1         // 0 - UART1, 1 - lwip

#if ! defined(EXCLUDE_VITIS)
#include <xtime_l.h>
#include <xuartps.h>
#include <xparameters.h>
#else
#define XPAR_CTRL0_AXI_BASEADDR 0
#define XPAR_ALL_MOVES_BRAM_AXI_CTRL_S_AXI_BASEADDR 0
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

#define TRANS_NODES_WIDTH 28

#define RESULT_DRAW 0
#define RESULT_WHITE_WIN 1
#define RESULT_BLACK_WIN 2
#define RESULT_NONE 3

#define TC_OK 0
#define TC_EXPIRED 1

#define UCI_SEARCH_STOP 0
#define UCI_SEARCH_CONT 1

#define MAX_DEPTH 40            // must match verilog
#define PV_ARRAY_COUNT ((MAX_DEPTH * MAX_DEPTH + MAX_DEPTH) / 2)

typedef struct tc_t
{
        uint32_t valid;
        uint32_t side;
        int32_t main;
        int32_t increment;
        int32_t move_number;
        int32_t main_remaining[2];
#if ! defined(EXCLUDE_VITIS)
        XTime control_start;
#endif
} tc_t;

typedef struct uci_t
{
        uint8_t row_from;
        uint8_t col_from;
        uint8_t row_to;
        uint8_t col_to;
        uint8_t promotion;
} uci_t;

typedef struct trans_t
{
        uint32_t entry_valid;
        int32_t depth;
        int32_t eval;
        uint32_t flag;
        uint32_t nodes;
        uint32_t capture;
} trans_t;

typedef struct board_t
{
        uint32_t board[8] __attribute__((aligned(sizeof(uint64_t))));
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
        uint32_t pv;
        uci_t uci;
}
board_t;

static inline void
numbat_write(uint32_t reg, uint32_t val)
{
        volatile uint32_t *ptr;

        ptr = (volatile uint32_t *)(uint64_t) (XPAR_CTRL0_AXI_BASEADDR + reg * 4);
        *ptr = val;
}

static inline void
numbat_write64(uint32_t reg, uint64_t val)
{
        volatile uint64_t *ptr;

        ptr = (volatile uint64_t *)(uint64_t) (XPAR_CTRL0_AXI_BASEADDR + reg * 4);
        *ptr = val;
}

static inline uint32_t
numbat_read(uint32_t reg)
{
        volatile uint32_t *ptr;
        uint32_t val;

        ptr = (volatile uint32_t *)(uint64_t) (XPAR_CTRL0_AXI_BASEADDR + reg * 4);
        val = *ptr;

        return val;
}

static inline uint64_t
numbat_read64(uint32_t reg)
{
        volatile uint64_t *ptr;
        uint64_t val;

        ptr = (volatile uint64_t *)(uint64_t) (XPAR_CTRL0_AXI_BASEADDR + reg * 4);
        val = *ptr;

        return val;
}

#define FAN_MAX_DUTY_CYCLE 3999

static inline void
numbat_fan_pwm(uint32_t duty_cycle)
{
        if (duty_cycle >= 4000)
                duty_cycle = FAN_MAX_DUTY_CYCLE;
        numbat_write(257, duty_cycle);
}

static inline void
numbat_led(uint32_t led_mask)
{
        numbat_write(256, led_mask);
}

static inline int32_t
numbat_initial_material_black(void)
{
        int32_t material;

        material = (int32_t) numbat_read(141);

        return material;
}

static inline int32_t
numbat_initial_material_white(void)
{
        int32_t material;

        material = (int32_t) numbat_read(142);

        return material;
}

static inline uint32_t
numbat_random(void)
{
        return numbat_read(254);
}

static inline void
numbat_random_score_mask(uint32_t mask)
{
        numbat_write(252, mask);
}

static inline void
numbat_trans_store(int32_t depth, uint32_t flag, int32_t eval, uint32_t nodes, uint32_t capture)
{
        uint32_t val;
        uint32_t depth32;
        uint8_t depth_u8;
        const uint32_t entry_store = 1 << 1;

        depth_u8 = (uint8_t) depth;
        depth32 = depth_u8;

        val = (uint32_t) eval;
        val &= ~(1 << 31);
        val |= (capture != 0) << 31;    // msbit of this reg stores capture flag
        numbat_write(521, (uint32_t) val);
        numbat_write(525, nodes);

        val = depth32 << 8 | flag << 2 | entry_store;   // toggle store on
        numbat_write(520, val);

        val = depth32 << 8 | flag << 2; // toggle store off
        numbat_write(520, val);
}

static inline void
numbat_trans_lookup(void)
{
        const uint32_t entry_lookup = 1 << 0;

        numbat_write(520, entry_lookup);
        numbat_write(520, 0);
}

static inline void
numbat_trans_read(uint32_t * collision, int32_t * eval, int32_t * depth, uint32_t * flag,
                  uint32_t * nodes, uint32_t * capture, uint32_t * entry_valid, uint32_t * trans_idle)
{
        uint32_t val;

        if (eval)
                *eval = (int32_t) numbat_read(514);
        if (nodes)
                *nodes = numbat_read(515);
        val = numbat_read(512);
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
        if (capture)
                *capture = (val >> 10) & 0x1;
}

static inline void
numbat_trans_hash_only(void)
{
        const uint32_t hash_only = 1 << 4;

        numbat_write(520, hash_only);
        numbat_write(520, 0);
}

static inline void
numbat_trans_clear_table(void)
{
        const uint32_t clear_trans = 1 << 5;

        numbat_write(520, clear_trans);
        numbat_write(520, 0);
}

static inline uint64_t
numbat_trans_hash(uint16_t * bits_79_64)
{
        uint64_t bits_31_0, bits_63_32;
        uint64_t hash;

        bits_31_0 = numbat_read(522);
        bits_63_32 = numbat_read(523);
        if (bits_79_64)
                *bits_79_64 = numbat_read(524);
        hash = bits_63_32 << 32 | bits_31_0;

        return hash;
}

static inline int32_t
numbat_trans_idle_wait(void)
{
        uint32_t counter;
        uint32_t trans_idle;

        counter = 0;
        do
        {
                numbat_trans_read(0, 0, 0, 0, 0, 0, 0, &trans_idle);
                ++counter;
        }
        while (counter < 100 && !trans_idle);

        return trans_idle;
}

static inline void
trans_test_idle(const char *func, const char *file, int line)
{
        uint32_t trans_idle;

        numbat_trans_read(0, 0, 0, 0, 0, 0, 0, &trans_idle);
        if (!trans_idle)
        {
                printf("%s: transposition table state machine is not idle, stopping. (%s %d)\n", func, file, line);
                while (1);
        }
}

static inline void
trans_lookup_init(void)
{
        trans_test_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
        numbat_trans_lookup();  // lookup hash will be calculated for board in most recent call to numbat_write_board_basic
}

static inline void
numbat_q_trans_store(int32_t depth, uint32_t flag, int32_t eval, uint32_t nodes, uint32_t capture)
{
        uint32_t val;
        uint32_t depth32;
        uint8_t depth_u8;
        const uint32_t entry_store = 1 << 1;

        depth_u8 = (uint8_t) depth;
        depth32 = depth_u8;

        val = (uint32_t) eval;
        val &= ~(1 << 31);
        val |= (capture != 0) << 31;    // msbit of this reg stores capture flag
        numbat_write(621, (uint32_t) val);
        numbat_write(625, nodes);

        val = depth32 << 8 | flag << 2 | entry_store;   // toggle store on
        numbat_write(620, val);

        val = depth32 << 8 | flag << 2; // toggle store off
        numbat_write(620, val);
}

static inline void
numbat_q_trans_lookup(void)
{
        const uint32_t entry_lookup = 1 << 0;

        numbat_write(620, entry_lookup);
        numbat_write(620, 0);
}

static inline void
numbat_q_trans_read(uint32_t * collision, int32_t * eval, int32_t * depth, uint32_t * flag,
                    uint32_t * nodes, uint32_t * capture, uint32_t * entry_valid, uint32_t * trans_idle)
{
        uint32_t val;

        if (eval)
                *eval = (int32_t) numbat_read(614);
        if (nodes)
                *nodes = numbat_read(615);
        val = numbat_read(612);
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
        if (capture)
                *capture = (val >> 10) & 0x1;
}

static inline void
numbat_q_trans_hash_only(void)
{
        const uint32_t hash_only = 1 << 4;

        numbat_write(620, hash_only);
        numbat_write(620, 0);
}

static inline void
numbat_q_trans_clear_table(void)
{
        const uint32_t clear_trans = 1 << 5;

        numbat_write(620, clear_trans);
        numbat_write(620, 0);
}

static inline uint64_t
numbat_q_trans_hash(uint16_t * bits_79_64)
{
        uint64_t bits_31_0, bits_63_32;
        uint64_t hash;

        bits_31_0 = numbat_read(622);
        bits_63_32 = numbat_read(623);
        if (bits_79_64)
                *bits_79_64 = numbat_read(624);
        hash = bits_63_32 << 32 | bits_31_0;

        return hash;
}

static inline int32_t
numbat_q_trans_idle_wait(void)
{
        uint32_t counter;
        uint32_t trans_idle;

        counter = 0;
        do
        {
                numbat_q_trans_read(0, 0, 0, 0, 0, 0, 0, &trans_idle);
                ++counter;
        }
        while (counter < 100 && !trans_idle);

        return trans_idle;
}

static inline void
q_trans_test_idle(const char *func, const char *file, int line)
{
        uint32_t trans_idle;

        numbat_q_trans_read(0, 0, 0, 0, 0, 0, 0, &trans_idle);
        if (!trans_idle)
        {
                printf("%s: transposition table state machine is not idle, stopping. (%s %d)\n", func, file, line);
                while (1);
        }
}

static inline void
q_trans_lookup_init(void)
{
        trans_test_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
        numbat_q_trans_lookup();        // lookup hash will be calculated for board in most recent call to numbat_write_board_basic
}

static inline uint32_t
numbat_misc_status(void)
{
        return numbat_read(255);
}

static inline void
numbat_write_control(uint32_t soft_reset, uint32_t new_board_valid, uint32_t clear_moves, uint32_t use_random_bit)
{
        uint32_t val;

        soft_reset = (soft_reset != 0) << 31;
        use_random_bit = (use_random_bit != 0) << 30;
        new_board_valid = (new_board_valid != 0) << 0;
        clear_moves = (clear_moves != 0) << 1;

        val = soft_reset | new_board_valid | clear_moves;
        numbat_write(0, val);
}

static inline void
numbat_write_board_misc(uint32_t white_to_move, uint32_t castle_mask, uint32_t en_passant_col)
{
        uint32_t val;

        white_to_move = (white_to_move != 0) << 8;
        castle_mask = (castle_mask & 0xF) << 4;
        en_passant_col &= 0xF;

        val = white_to_move | castle_mask | en_passant_col;
        numbat_write(2, val);
}

static inline void
numbat_move_index(uint32_t move_index)
{
        numbat_write(1, move_index);
}

static inline void
numbat_quiescence_moves(uint32_t quiescence_moves)
{
        numbat_write(4, quiescence_moves);
}

static inline void
numbat_write_board_row(uint32_t row, uint32_t row_pieces)
{
        numbat_write(8 + row, row_pieces);
}

static inline void
numbat_write_board_two_rows(uint32_t row0, uint64_t row_pieces0, uint64_t row_pieces1)
{
        uint64_t row_pieces;

        row_pieces = row_pieces1 << (uint64_t) 32 | row_pieces0;
        numbat_write64(8 + row0, row_pieces);
}

static inline uint32_t
numbat_status(uint32_t * move_ready, uint32_t * moves_ready, uint32_t * mate, uint32_t * stalemate,
              uint32_t * thrice_rep, uint32_t * am_idle, uint32_t * fifty_move, uint32_t * insufficient, uint32_t * check)
{
        uint32_t val;

        val = numbat_read(0);
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
numbat_read_move_row(uint32_t row)
{
        uint32_t val;

        val = numbat_read(172 + row);

        return val;
}

static inline uint64_t
numbat_read_move_two_rows(uint32_t row0)
{
        uint64_t val;

        val = numbat_read64(172 + row0);

        return val;
}

static inline uint64_t
numbat_read_white_is_attacking(void)
{
        uint64_t bits_lo, bits_hi, val;

        bits_lo = numbat_read(128);
        bits_hi = numbat_read(129);

        val = bits_hi << 31 | bits_lo;

        return val;
}

static inline uint64_t
numbat_read_black_is_attacking(void)
{
        uint64_t bits_lo, bits_hi, val;

        bits_lo = numbat_read(130);
        bits_hi = numbat_read(131);

        val = bits_hi << 31 | bits_lo;

        return val;
}

static inline uint32_t
numbat_board_status0(uint32_t * black_in_check, uint32_t * white_in_check, uint32_t * capture, uint32_t * thrice_rep, uint32_t * fifty_move,
                     uint32_t * pv)
{
        uint32_t val;

        val = numbat_read(132);
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
        if (pv)
                *pv = (val & (1 << 6)) != 0;

        return val;
}

static inline uint32_t
numbat_board_status1(uint32_t * white_to_move, uint32_t * castle_mask, uint32_t * en_passant_col)
{
        uint32_t val;

        val = numbat_read(133);
        if (white_to_move)
                *white_to_move = (val & (1 << 8)) != 0;
        if (castle_mask)
                *castle_mask = (val & (0xF << 4)) >> 4;
        if (en_passant_col)
                *en_passant_col = val & 0xF;

        return val;
}

static inline int32_t
numbat_move_eval(void)
{
        int32_t val;

        val = (int32_t) numbat_read(134);

        return val;
}

static inline int32_t
numbat_initial_eval(void)
{
        int32_t val;

        val = (int32_t) numbat_read(136);

        return val;
}

static inline uint32_t
numbat_move_count(void)
{
        int32_t val;

        val = numbat_read(135);

        return val;
}

static inline void
numbat_repdet_write(uint32_t addr)
{
        numbat_write(0x12, 1 << 31 | addr);     // toggle write enable
        numbat_write(0x12, addr);
}

static inline void
numbat_repdet_depth(uint32_t depth)
{
        numbat_write(0x10, depth);
}

static inline void
numbat_repdet_castle_mask(uint32_t castle_mask)
{
        numbat_write(0x11, castle_mask);
}

static inline void
numbat_repdet_board(const uint32_t board[8])
{
        uint32_t i;
        uint64_t row_pieces0, row_pieces1, row_pieces;

        for (i = 0; i < 8; i += 2)
        {
                row_pieces0 = board[i + 0];
                row_pieces1 = board[i + 1];
                row_pieces = row_pieces1 << (uint64_t) 32 | row_pieces0;
                numbat_write64(0x18 + i, row_pieces);
        }
}

static inline void
numbat_write_half_move(uint32_t half_move)
{
        numbat_write(0x3, half_move);
}

static inline uint32_t
numbat_read_half_move(void)
{
        uint32_t half_move;

        half_move = numbat_read(138);

        return half_move;
}

static inline void
numbat_reset_all_moves(void)
{
        numbat_write_control(1, 0, 0, 0);       // soft reset, new board valid, clear moves
        numbat_write_control(0, 0, 0, 0);
}

static inline uint32_t
uci_match(const uci_t * a, const uci_t * b)
{
        uint32_t ret;

        ret = a->row_from == b->row_from && a->row_to == b->row_to && a->col_from == b->col_from && a->col_to == b->col_to
                && a->promotion == b->promotion;

        return ret;
}

static inline uint32_t
ui_data_available(void)
{
        uint32_t status;

#if ! defined(EXCLUDE_VITIS)
        status = XUartPs_IsReceiveData(XPAR_XUARTPS_0_BASEADDR);
#else
        status = 0;
#endif

        return status;
}

static inline void
killer_control(uint32_t clear, uint32_t update)
{
        uint32_t val;

        val = (clear != 0) << 1 | (update != 0) << 0;
        numbat_write(1032, val);
}

static inline void
killer_bonus(int32_t bonus0, int32_t bonus1)
{
        numbat_write(134, bonus0);
        numbat_write(135, bonus1);
}

static inline void
killer_ply(uint32_t ply)
{
        numbat_write(1033, ply);
}

static inline void
killer_write_board_two_rows(uint32_t row0, uint64_t row_pieces0, uint64_t row_pieces1)
{
        uint64_t row_pieces;

        row_pieces = row_pieces1 << (uint64_t) 32 | row_pieces0;
        numbat_write64(1024 + row0, row_pieces);
}

static inline void
killer_write_board(const uint32_t board[8])
{
        killer_write_board_two_rows(0, board[0], board[1]);
        killer_write_board_two_rows(2, board[2], board[3]);
        killer_write_board_two_rows(4, board[4], board[5]);
        killer_write_board_two_rows(6, board[6], board[7]);
}

static inline void
killer_clear_table(void)
{
        killer_control(1, 0);
        killer_control(0, 0);
}

static inline void
killer_update_table(void)
{
        killer_control(0, 1);
        killer_control(0, 0);
}

static inline uint32_t
uci_nonzero(const uci_t * p)
{
        uint32_t nonzero;

        nonzero = p->promotion != 0 || p->row_from != 0 || p->col_from != 0 || p->row_to != 0 || p->col_to != 0;

        return nonzero;
}

static inline void
pv_write_ctrl(uint32_t table_write, uint32_t table_clear, const uci_t * move, uint32_t ply, uint32_t entry_valid)
{
        uint32_t val;
        uint32_t table_entry_packed;

        if (move)
                table_entry_packed = move->promotion << 12 | move->row_to << 9 | move->col_to << 6 | move->row_from << 3 | move->col_from << 0;
        else
                table_entry_packed = 0;
        val = 0;
        val |= (table_write != 0) << 31;
        val |= (table_clear != 0) << 30;
        val |= (entry_valid != 0) << (16 + 6);  // UCI_WIDTH + MAX_DEPTH_LOG2
        val |= ply << 16;       // UCI_WIDTH
        val |= table_entry_packed;

        numbat_write(600, val);
}

static inline void
pv_load_table(const uci_t * pv)
{
        int32_t ply;

        pv_write_ctrl(0, 1, 0, 0, 0);   // clear pv table
        for (ply = 0; ply < MAX_DEPTH && uci_nonzero(&pv[ply]); ++ply)
                pv_write_ctrl(1, 0, &pv[ply], ply, 1);  // write entry
        pv_write_ctrl(0, 0, 0, 0, 0);   // disable write
}

extern int start_application(void);
extern void init_platform(void);
extern void platform_enable_interrupts(void);
extern void tcp_write_uci(const char *str);
extern int32_t tcp_uci_fifo_count(void);
extern char tcp_uci_read_char(void);
extern void tcp_task(void);

extern void numbat_init(void);
extern uint32_t numbat_move_piece(board_t * board, uint32_t row_from, uint32_t col_from, uint32_t row_to, uint32_t col_to);
extern void numbat_init_board(board_t * board);
extern void numbat_write_board_basic(const board_t * board);
extern void numbat_write_board_wait(const board_t * board, uint32_t quiescence);
extern void numbat_init_board(board_t * board);
extern void numbat_print_board(const board_t * board, uint32_t initial_board);
extern uint32_t numbat_read_board(board_t * board, uint32_t index);
extern void numbat_place(board_t * board, uint32_t row, uint32_t col, uint32_t piece);
extern uint32_t numbat_get_piece(const board_t * board, uint32_t row, uint32_t col);
extern void numbat_repdet_entry(uint32_t index, const uint32_t board[8], uint32_t castle_mask);
extern void numbat_read_uci(uci_t * uci);

extern void nm_init(void);
extern board_t nm_top(const tc_t * tc, uint32_t * resign);

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
extern void uci_string(const uci_t * uci, char *str);
extern void uci_pv(int32_t depth, int32_t score, uint32_t time_ms, uint32_t nodes, uint32_t nps, const uci_t * ply0_move, const uci_t * pv);
extern void uci_currmove(int32_t depth, int32_t seldepth, const uci_t * currmove, int32_t currmovenumber, int32_t score);
extern void uci_resign(void);

extern void trans_clear_table(void);
extern void trans_lookup(trans_t * trans, uint32_t * collision);
extern void trans_store(const trans_t * trans);
extern void q_trans_clear_table(void);
extern void q_trans_lookup(trans_t * trans, uint32_t * collision);
extern void q_trans_store(const trans_t * trans);

extern void tc_init(tc_t * tc, int32_t main, int32_t increment);
extern uint32_t tc_clock_toggle(tc_t * tc);
extern void tc_ignore(tc_t * tc);
extern void tc_display(const tc_t * tc);
extern void tc_set(tc_t * tc, uint32_t side, int32_t main_remaining, int32_t increment);

extern int tmon_init(void);
extern int tmon_poll(void);
#if ! defined(EXCLUDE_VITIS)
extern XTime tmon_temperature_check_time;
#endif
extern float tmon_temperature;
extern float tmon_max_temperature;
extern float tmon_min_temperature;
