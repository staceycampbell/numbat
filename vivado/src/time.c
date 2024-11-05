#include <stdio.h>
#include <xparameters.h>
#include <netif/xadapter.h>
#include <xil_printf.h>
#include <lwip/tcp.h>
#include <lwip/priv/tcp_priv.h>
#include <lwip/init.h>
#include <xil_cache.h>
#include <xuartps.h>
#include <xtime_l.h>
#include "vchess.h"

void
tc_init(tc_t *tc, int32_t main, int32_t increment)
{
	tc->valid = 1;
	tc->main = main;
	tc->increment = increment;
	tc->main_remaining[0] = main;
	tc->main_remaining[1] = main;
	tc->side = 0;
	XTime_GetTime(&tc->control_start);
}

uint32_t
tc_clock_toggle(tc_t *tc)
{
	XTime control_end, duration_ticks;
	int64_t duration_seconds;
	uint32_t status;

	status = TC_OK;
	XTime_GetTime(&control_end);
	duration_ticks = control_end - tc->control_start;
	duration_seconds = (double)duration_ticks / (double)COUNTS_PER_SECOND + 0.5;
	tc->main_remaining[tc->side] -= duration_seconds;
	if (tc->main_remaining[tc->side] <= 0)
		status = TC_EXPIRED;
	else
		tc->main_remaining[tc->side] += tc->increment;
	tc->control_start = control_end;
	tc->side = ! tc->side;
	++tc->move_number;

	return status;
}

void
tc_ignore(tc_t *tc)
{
	tc->valid = 0;
}
