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
tc_display(const tc_t *tc)
{
        uint32_t hour_white, minute_white, second_white;
        uint32_t hour_black, minute_black, second_black;

        if (tc->valid)
        {
                hour_white = tc->main_remaining[0] / (60 * 60);
                minute_white = (tc->main_remaining[0] - hour_white * 60 * 60) / 60;
                second_white = tc->main_remaining[0] % 60;
                hour_black = tc->main_remaining[1] / (60 * 60);
                minute_black = (tc->main_remaining[1] - hour_black * 60 * 60) / 60;
                second_black = tc->main_remaining[1] % 60;
                printf("W:%02d:%02d:%02d B:%02d:%02d:%02d", hour_white, minute_white, second_white, hour_black, minute_black, second_black);
        }
        else
                printf("fixed time");
}

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

void
tc_set(tc_t *tc, uint32_t side, int32_t main_remaining, int32_t increment)
{
	tc->valid = 1;
	tc->side = side;
	tc->main = main_remaining;
	tc->main_remaining[side] = main_remaining;
	tc->increment = increment;
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
