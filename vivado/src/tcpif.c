#include <stdio.h>
#include <string.h>
#include <lwip/err.h>
#include <lwip/tcp.h>
#include <xil_printf.h>
#include "vchess.h"

int
transfer_data()
{
	return 0;
}

void
print_app_header()
{
	xil_printf("\n\r\n\r-------Starting TCP server-------n\r");
}

static err_t
recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err)
{
	char buffer[TCP_SND_BUF + 1];
	/* do not read the packet if we are not in ESTABLISHED state */
	if (!p)
	{
		tcp_close(tpcb);
		tcp_recv(tpcb, NULL);
		return ERR_OK;
	}

	/* indicate that the packet has been received */
	tcp_recved(tpcb, p->len);

	/* echo back the payload */
	/* in this case, we assume that the payload is < TCP_SND_BUF */
	if (tcp_sndbuf(tpcb) > p->len)
	{
		err = tcp_write(tpcb, p->payload, p->len, 1);
		memset(buffer, 0, sizeof(buffer));
		memcpy(buffer, p->payload, p->len);
		xil_printf("payload: %s", buffer);
	}
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
	struct tcp_pcb *pcb;
	err_t err;
	unsigned port = 7777;

	/* create new TCP PCB structure */
	pcb = tcp_new_ip_type(IPADDR_TYPE_ANY);
	if (!pcb)
	{
		xil_printf("Error creating PCB. Out of Memory\n\r");
		return -1;
	}

	/* bind to specified @port */
	err = tcp_bind(pcb, IP_ANY_TYPE, port);
	if (err != ERR_OK)
	{
		xil_printf("Unable to bind to port %d: err = %d\n\r", port, err);
		return -2;
	}

	/* we do not need any arguments to callback functions */
	tcp_arg(pcb, NULL);

	/* listen for connections */
	pcb = tcp_listen(pcb);
	if (!pcb)
	{
		xil_printf("Out of memory while tcp_listen\n\r");
		return -3;
	}

	/* specify callback to use for incoming connections */
	tcp_accept(pcb, accept_callback);

	xil_printf("TCP interface started at port %d\n\r", port);

	return 0;
}
