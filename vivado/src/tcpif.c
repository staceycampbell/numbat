// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <stdio.h>
#include <string.h>
#include <lwip/err.h>
#include <lwip/tcp.h>
#include <xil_printf.h>
#include "numbat.h"

#if 0
extern struct tcp_pcb *cmd_pcb;

static char Buffer[TCP_SND_BUF + 1];
static uint32_t BufLen;

uint32_t
cmd_transfer_data(uint8_t cmdbuf[512], uint32_t *index)
{
        int i, j;
        uint32_t status;

        status = 0;
        if (BufLen > 0)
        {
                i = *index;
                j = 0;
                while (i < 511 && j < TCP_SND_BUF && ! (status = (Buffer[j] == '\r' || Buffer[j] == '\n' || i == 510)))
                {
                        cmdbuf[i] = Buffer[j];
                        ++i;
                        ++j;
                }
                *index = i;
        }
        if (status)
                BufLen = 0;
        return status;
}

void
print_app_header()
{
        xil_printf("\n\r\n\r-------Starting TCP server-------\n\r");
}

static err_t
recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err)
{
        /* do not read the packet if we are not in ESTABLISHED state */
        if (!p)
        {
                tcp_close(tpcb);
                tcp_recv(tpcb, NULL);
                return ERR_OK;
        }

        /* indicate that the packet has been received */
        tcp_recved(tpcb, p->len);
        memset(Buffer, 0, sizeof(Buffer));
        memcpy(Buffer, p->payload, p->len);
        BufLen = p->len;

        /* in this case, we assume that the payload is < TCP_SND_BUF */
        if (tcp_sndbuf(tpcb) > p->len)
                err = tcp_write(tpcb, p->payload, p->len, 1);
        else
                xil_printf("no space in tcp_sndbuf\n\r");

        /* free the received pbuf */
        pbuf_free(p);

        return ERR_OK;
}

static err_t
accept_callback(void *arg, struct tcp_pcb *newpcb, err_t err)
{
        static int connection = 1;

        /* set the receive callback for this connection */
        tcp_recv(newpcb, recv_callback);

        /* just use an integer number indicating the connection id as the
           callback argument */
        tcp_arg(newpcb, (void *)(UINTPTR) connection);

        /* increment for subsequent accepted connections */
        connection++;

        return ERR_OK;
}

int
start_application(void)
{
        err_t err;
        unsigned port = 7777;

        /* create new TCP PCB structure */
        cmd_pcb = tcp_new_ip_type(IPADDR_TYPE_ANY);
        if (!cmd_pcb)
        {
                xil_printf("Error creating PCB. Out of Memory\n\r");
                return -1;
        }

        /* bind to specified @port */
        err = tcp_bind(cmd_pcb, IP_ANY_TYPE, port);
        if (err != ERR_OK)
        {
                xil_printf("Unable to bind to port %d: err = %d\n\r", port, err);
                return -2;
        }

        /* we do not need any arguments to callback functions */
        tcp_arg(cmd_pcb, NULL);

        /* listen for connections */
        cmd_pcb = tcp_listen(cmd_pcb);
        if (!cmd_pcb)
        {
                xil_printf("Out of memory while tcp_listen\n\r");
                return -3;
        }

        /* specify callback to use for incoming connections */
        tcp_accept(cmd_pcb, accept_callback);

        xil_printf("TCP interface started at port %d\n\r", port);

        BufLen = 0;

        return 0;
}
#endif
