// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <xparameters.h>
#include <xil_printf.h>
#include <xtime_l.h>
#include "numbat.h"

extern board_t game[GAME_MAX];
extern uint32_t game_moves;

#pragma GCC optimize ("O2")

static inline void
q_trans_wait_idle(const char *func, const char *file, int line)
{
	uint32_t i;
	uint32_t trans_idle;

	i = 0;
	do
	{
		trans_idle = numbat_q_trans_idle();
		++i;
	}
	while (!trans_idle && i < 1000);
	if (!trans_idle)
	{
		printf("%s: quiescence transposition table state machine is not idle, stopping.\n(%s %d)\n", func, file, line);
		while (1);
	}
}

void
trans_clear_table(void)
{
	XTime t_end, t_start, elapsed_ticks;
	double elapsed_time;
	uint32_t trans_idle, transaction;

	trans_wait_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
	XTime_GetTime(&t_start);
	numbat_trans_clear_table();
	do
	{
		XTime_GetTime(&t_end);
		elapsed_ticks = t_end - t_start;
		elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
		trans_idle = numbat_trans_idle();
	}
	while (elapsed_time < 2.0 && !trans_idle);
	if (!trans_idle)
	{
		transaction = numbat_read(253);
		xil_printf("%s: timeout on trans_idle, transaction=%d, stopping.\n(%s %d)\n", __PRETTY_FUNCTION__, transaction, __FILE__, __LINE__);
		while (1);
	}
}

void
trans_lookup(trans_t * trans, uint32_t * collision)
{
	trans_lookup_init();
	trans_wait_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
	numbat_trans_read(collision, &trans->eval, &trans->depth, &trans->flag, &trans->nodes, &trans->entry_valid);
}

void
trans_store(const trans_t * trans)
{
	trans_test_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
	numbat_trans_store(trans->depth, trans->flag, trans->eval, trans->nodes, 0);
	trans_wait_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
}

void
q_trans_clear_table(void)
{
	XTime t_end, t_start, elapsed_ticks;
	double elapsed_time;
	uint32_t trans_idle;

	q_trans_wait_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
	XTime_GetTime(&t_start);
	numbat_q_trans_clear_table();
	do
	{
		XTime_GetTime(&t_end);
		elapsed_ticks = t_end - t_start;
		elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
		trans_idle = numbat_q_trans_idle();
	}
	while (elapsed_time < 2.0 && !trans_idle);
	if (!trans_idle)
	{
		xil_printf("%s: timeout on quiescence trans_idle, stopping.\n(%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
		while (1);
	}
}

void
q_trans_lookup(trans_t * trans, uint32_t * collision)
{
	q_trans_lookup_init();
	q_trans_wait_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
	numbat_q_trans_read(collision, &trans->eval, &trans->depth, &trans->flag, &trans->nodes, &trans->entry_valid);
}

void
q_trans_store(const trans_t * trans)
{
	q_trans_test_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
	numbat_q_trans_store(trans->depth, trans->flag, trans->eval, trans->nodes, 0);
	q_trans_wait_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
}

void
trans_wait_idle(const char *func, const char *file, int line)
{
	uint32_t i;
	uint32_t transaction;
	uint32_t trans_idle;

	i = 0;
	do
	{
		trans_idle = numbat_trans_idle();
		++i;
	}
	while (!trans_idle && i < 1000);
	if (!trans_idle)
	{
		transaction = numbat_read(253);
		printf("%s: transaction=%d, transposition table state machine is not idle, stopping.\n(%s %d)\n", func, transaction, file, line);
		while (1);
	}
}

void
trans_test(void)
{
	board_t test_board;
	trans_t store, verify;
	uint32_t collision;

	if (game_moves == 0)
	{
		printf("%s: no game move to test\n", __PRETTY_FUNCTION__);
		return;
	}
	printf("Clearing tt...");
	fflush(stdout);
	trans_clear_table();
	printf("done.\n");
	test_board = game[game_moves - 1];
	numbat_write_board_basic(&test_board);

	store.entry_valid = 1;
	store.depth = numbat_random() % 50;
	store.eval = ((int32_t) numbat_random() % 4000) - 2000;
	store.flag = numbat_random() & 0x3;
	store.nodes = numbat_random() % 100;

	trans_store(&store);
	trans_lookup(&verify, &collision);

	if (collision)
		printf("%s: collision set!\n", __PRETTY_FUNCTION__);
	if (!verify.entry_valid || store.depth != verify.depth || store.eval != verify.eval ||
	    store.flag != verify.flag || store.nodes != verify.nodes)
		printf("%s: transposition table problem!\n", __PRETTY_FUNCTION__);
	else if (!collision)
		printf("%s: test passed\n", __PRETTY_FUNCTION__);
}
