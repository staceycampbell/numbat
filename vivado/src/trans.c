#include <stdio.h>
#include <string.h>
#include <xparameters.h>
#include <xil_printf.h>
#include <xtime_l.h>
#include "vchess.h"

#pragma GCC optimize ("O3")

#define TRANS_BASE_ADDR ((void *)UINT64_C(0x400000000))
#define TABLE_SIZE_LOG2 25
#define TABLE_SIZE (1 << TABLE_SIZE_LOG2)
#define TABLE_WORD64_COUNT (TABLE_SIZE * (512 / (8 * 8)))

void
trans_clear_table(void)
{
	uint32_t i;
        XTime t_end, t_start, elapsed_ticks;
	double elapsed_time;
	volatile uint64_t *table64 = TRANS_BASE_ADDR;

	xil_printf("Clearing transposition table of %d 64 bit words...", TABLE_WORD64_COUNT);
        XTime_GetTime(&t_start);
	for (i = 0; i < TABLE_WORD64_COUNT; ++i)
		table64[i] = 0;
        XTime_GetTime(&t_end);
        elapsed_ticks = t_end - t_start;
        elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
	printf("done in %0.2f seconds.\n", elapsed_time);
}

static void
trans_test_idle(const char *func, const char *file, int line)
{
        uint32_t trans_idle;

	vchess_trans_read(0, 0, 0, 0, &trans_idle);
	if (! trans_idle)
	{
		printf("%s: transposition table state machine is not idle, stopping. (%s %d)\n", func, file, line);
		while (1);
	}
}

static void
trans_wait_idle(const char *func, const char *file, int line)
{
	uint32_t i;
	uint32_t trans_idle;
	
        i = 0;
        do
        {
                vchess_trans_read(0, 0, 0, 0, &trans_idle);
                ++i;
        }
        while (!trans_idle && i < 1000);
	if (! trans_idle)
	{
		printf("%s: transposition table state machine is not idle, stopping. (%s %d)\n", func, file, line);
		while (1);
	}
}

void
trans_lookup(trans_t *trans)
{
        uint32_t trans_idle;

	trans_test_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
        vchess_trans_lookup();  // lookup hash will be calculated on board in last call to vchess_write_board_basic
	trans_wait_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
	vchess_trans_read(&trans->eval, &trans->depth, &trans->flag, &trans->entry_valid, &trans_idle);
}

void
trans_store(trans_t *trans)
{
	trans_test_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
	vchess_trans_store(trans->depth, trans->flag, trans->eval);
	trans_wait_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
}
