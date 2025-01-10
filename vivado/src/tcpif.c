// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#pragma GCC optimize ("O2")

#include <stdio.h>
#include <string.h>
#include <netif/xadapter.h>
#include <lwip/err.h>
#include <lwip/init.h>
#include <lwip/priv/tcp_priv.h>
#include <lwip/tcp.h>
#include "numbat.h"

extern volatile int TcpFastTmrFlag;
extern volatile int TcpSlowTmrFlag;
extern struct netif *uci_netif;

static struct tcp_pcb *server_pcb;
static struct tcp_pcb *uci_pcb = 0;

static char fifo[4096];
static int32_t fifo_write_index, fifo_read_index, fifo_count;

static err_t
recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err)
{
        int32_t i;
        char *buf;

        if (!p)
        {
                tcp_close(tpcb);
                tcp_recv(tpcb, NULL);
                return ERR_OK;
        }

        tcp_recved(tpcb, p->len);       // indicate that the packet has been received

        buf = (char *)p->payload;
        i = 0;
        while (i < p->len)
        {
                fifo[fifo_write_index] = buf[i];
                if (fifo_write_index == sizeof(fifo) - 1)
                        fifo_write_index = 0;
                else
                        ++fifo_write_index;
                ++i;
        }
        fifo_count += p->len;
        if (fifo_count > sizeof(fifo))
        {
                printf("%s: fifo overflow, stopping\n", __PRETTY_FUNCTION__);
                while (1);
        }

        pbuf_free(p);           // free the received pbuf

        return ERR_OK;
}

int32_t
tcp_uci_fifo_count(void)
{
        return fifo_count;
}

char
tcp_uci_read_char(void)
{
        char c;

        if (fifo_count <= 0)
        {
                printf("%s: fifo underflow, stopping\n", __PRETTY_FUNCTION__);
                while (1);
        }
        c = fifo[fifo_read_index];
        if (fifo_read_index == sizeof(fifo) - 1)
                fifo_read_index = 0;
        else
                ++fifo_read_index;
        --fifo_count;
        if (fifo_count < 0)
        {
                printf("%s: fifo negative , stopping\n", __PRETTY_FUNCTION__);
                while (1);
        }

        return c;
}

void
tcp_write_uci(const char *str)
{
        int err;
        int len;

        if (!uci_pcb)
                return;
        len = strlen(str);
        err = tcp_write(uci_pcb, str, len, 1);
        if (err != ERR_OK)
                printf("%s: tcp_write returned %d\n", __PRETTY_FUNCTION__, err);
}

static err_t
accept_callback(void *arg, struct tcp_pcb *newpcb, err_t err)
{
        static int connection = 1;

        tcp_recv(newpcb, recv_callback);
        tcp_arg(newpcb, (void *)(UINTPTR) connection);
        connection++;

        uci_pcb = newpcb;

        return ERR_OK;
}

int
start_application(void)
{
        err_t err;
        unsigned port = 12320;

        server_pcb = tcp_new_ip_type(IPADDR_TYPE_ANY);
        if (!server_pcb)
        {
                printf("Error creating PCB. Out of Memory\n\r");
                return -1;
        }

        err = tcp_bind(server_pcb, IP_ANY_TYPE, port);
        if (err != ERR_OK)
        {
                printf("Unable to bind to port %d: err = %d\n\r", port, err);
                return -2;
        }

        tcp_arg(server_pcb, NULL);

        server_pcb = tcp_listen(server_pcb);
        if (!server_pcb)
        {
                printf("Out of memory while tcp_listen\n\r");
                return -3;
        }

        tcp_accept(server_pcb, accept_callback);

        printf("TCP interface started at port %d\n\r", port);

        fifo_write_index = 0;
        fifo_read_index = 0;
        fifo_count = 0;

        return 0;
}

void
tcp_task(void)
{
        if (TcpFastTmrFlag)
        {
                tcp_fasttmr();
                TcpFastTmrFlag = 0;
        }
        if (TcpSlowTmrFlag)
        {
                tcp_slowtmr();
                TcpSlowTmrFlag = 0;
        }
        xemacif_input(uci_netif);
}
