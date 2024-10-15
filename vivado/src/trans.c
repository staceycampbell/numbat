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
