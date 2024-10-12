#include <stdio.h>
#include <xparameters.h>
#include <xil_printf.h>
#include <xtime_l.h>
#include "vchess.h"

#define TRANS_BASE_ADDR ((void *)UINT64_C(0x400000000))

void
trans_clear_table(void)
{
	int32_t i;
	uint32_t d;
	volatile uint32_t *table = TRANS_BASE_ADDR;

	for (i = 0; i < 10000; ++i)
		table[i] = i;
	for (i = 10000; i < 20000; ++i)
		table[i] = ~i;
	for (i = 10000 - 1; i >= 0; --i)
	{
		d = table[i];
		if (d != i)
			xil_printf("problem: %d %u\n", i, d);
	}
}
