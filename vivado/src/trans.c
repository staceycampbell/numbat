// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <xparameters.h>
#include <xil_printf.h>
#include <xtime_l.h>
#include "numbat.h"

#pragma GCC optimize ("O2")

static inline void
trans_wait_idle(const char *func, const char *file, int line)
{
        uint32_t i;
        uint32_t transaction;
        uint32_t trans_idle;

        i = 0;
        do
        {
                numbat_trans_read(0, 0, 0, 0, 0, 0, 0, &trans_idle);
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

static inline void
q_trans_wait_idle(const char *func, const char *file, int line)
{
        uint32_t i;
        uint32_t trans_idle;

        i = 0;
        do
        {
                numbat_q_trans_read(0, 0, 0, 0, 0, 0, 0, &trans_idle);
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
                numbat_trans_read(0, 0, 0, 0, 0, 0, 0, &trans_idle);
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
        uint32_t trans_idle;

        trans_lookup_init();
        trans_wait_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
        numbat_trans_read(collision, &trans->eval, &trans->depth, &trans->flag, &trans->nodes, &trans->capture, &trans->entry_valid, &trans_idle);
}

void
trans_store(const trans_t * trans)
{
        trans_test_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
        numbat_trans_store(trans->depth, trans->flag, trans->eval, trans->nodes, trans->capture);
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
                numbat_q_trans_read(0, 0, 0, 0, 0, 0, 0, &trans_idle);
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
        uint32_t trans_idle;

        q_trans_lookup_init();
        q_trans_wait_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
        numbat_q_trans_read(collision, &trans->eval, &trans->depth, &trans->flag, &trans->nodes, &trans->capture, &trans->entry_valid, &trans_idle);
}

void
q_trans_store(const trans_t * trans)
{
        q_trans_test_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
        numbat_q_trans_store(trans->depth, trans->flag, trans->eval, trans->nodes, trans->capture);
        q_trans_wait_idle(__PRETTY_FUNCTION__, __FILE__, __LINE__);
}
