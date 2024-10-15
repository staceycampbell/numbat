#include <stdio.h>
#include <xparameters.h>
#include <xil_printf.h>
#include <xtime_l.h>
#include "vchess.h"

#pragma GCC optimize ("O3")

#define TRANS_BASE_ADDR ((void *)UINT64_C(0x400000000))
#define TABLE_SIZE_LOG2 25
#define TABLE_SIZE (1 << TABLE_SIZE_LOG2)
#define TABLE_WORD32_COUNT (TABLE_SIZE * (512 / (8 * 4)))

void
trans_clear_table(void)
{
	uint32_t i;
        XTime t_end, t_start, elapsed_ticks;
	double elapsed_time;
	volatile uint32_t *table = TRANS_BASE_ADDR;
	volatile uint64_t *table64 = TRANS_BASE_ADDR;

	for (i = 0; i < TABLE_WORD32_COUNT; ++i)
		table[i] = i;

	xil_printf("Clearing transposition table of %d 32 bit words...", TABLE_WORD32_COUNT);
        XTime_GetTime(&t_start);
	for (i = 0; i < TABLE_WORD32_COUNT / 2; ++i)
		table64[i] = 0;
        XTime_GetTime(&t_end);
        elapsed_ticks = t_end - t_start;
        elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
	printf("done in %0.2f seconds.\n", elapsed_time);

	xil_printf("Verifying...");
	i = 0;
	while (i < TABLE_WORD32_COUNT && table[i] == 0)
		++i;
	if (i < TABLE_WORD32_COUNT)
		xil_printf("problem at address 0x%08X contains 0x%08X!\n", i, table[i]);
	else
		xil_printf("done.\n");
}
