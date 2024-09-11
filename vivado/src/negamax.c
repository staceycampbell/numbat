#include <stdint.h>
#include <xil_printf.h>
#include "vchess.h"

#define DEPTH_MAX 3

// static board_t board_stack[DEPTH_MAX][MAX_POSITIONS];
//static uint32_t board_count[DEPTH_MAX];

static int32_t
nm_load_positions(board_t boards[MAX_POSITIONS])
{
	int32_t i;
	uint32_t moves_ready, status, move_count;

	vchess_status(0, 0, &moves_ready, 0, 0);
	if (! moves_ready)
	{
		xil_printf("%s: moves_ready not set (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return -1;
	}
	move_count = vchess_move_count();
	if (move_count == 0)
	{
		xil_printf("%s: no moves available (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return -2;
	}
	for (i = 0; i < move_count; ++i)
	{
		status = vchess_read_board(&boards[i], i);
		if (status)
		{
			xil_printf("%s: problem with vchess_read_board (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
			return -3;
		}
	}
	return move_count;
}

static board_t root_node_boards[MAX_POSITIONS];

void
nm_top(void)
{
	int32_t i, status;
	uint32_t moves_ready, move_count;

	i = 0;
	do
	{
		vchess_status(0, 0, &moves_ready, 0, 0);
		++i;
	} while (i < 1000 && ! moves_ready);
	if (! moves_ready)
	{
		xil_printf("%s: moves_ready timeout (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return;
	}
	move_count = vchess_move_count();
	if (move_count == 0)
	{
		xil_printf("%s: game is over, no moves (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return;
	}
	status = nm_load_positions(root_node_boards);
	if (status != move_count)
	{
		xil_printf("%s: bad call to nm_load_positions (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		return;
	}
}
