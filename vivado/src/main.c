#include <stdio.h>
#include <xparameters.h>
#include <netif/xadapter.h>
#include <xil_printf.h>
#include <lwip/tcp.h>
#include <lwip/priv/tcp_priv.h>
#include <lwip/init.h>
#include <xil_cache.h>
#include <xuartps.h>
#include "vchess.h"

#define PLATFORM_EMAC_BASEADDR XPAR_XEMACPS_0_BASEADDR

extern volatile int TcpFastTmrFlag;
extern volatile int TcpSlowTmrFlag;
static struct netif server_netif;

struct netif *cmd_netif;
struct tcp_pcb *cmd_pcb;

static void
print_ip(char *msg, ip_addr_t * ip)
{
	print(msg);
	xil_printf("%d.%d.%d.%d\n\r", ip4_addr1(ip), ip4_addr2(ip), ip4_addr3(ip), ip4_addr4(ip));
}

static void
print_ip_settings(ip_addr_t * ip, ip_addr_t * mask, ip_addr_t * gw)
{
	print_ip("Board IP: ", ip);
	print_ip("Netmask : ", mask);
	print_ip("Gateway : ", gw);
}

static uint32_t
process_serial_port(uint8_t cmdbuf[512], uint32_t *index)
{
	unsigned char c;
	uint32_t status;

	c = inbyte();
	status = c == '\r' || c == '\n' || *index == 511;
	if (status)
		cmdbuf[*index] = '\0';
	else
		cmdbuf[*index] = c;
	++*index;

	return status;
}

static void
process_cmd(uint8_t cmd[512])
{
	int len;
	
	xil_printf("cmd: %s\n", cmd);
	len = strlen((char *)cmd);
	tcp_write(cmd_pcb, cmd, len, TCP_WRITE_FLAG_COPY);
	tcp_write(cmd_pcb, "\n", 1, TCP_WRITE_FLAG_COPY);
}

int
main(void)
{
	ip_addr_t ipaddr, netmask, gw;
	unsigned char mac_ethernet_address[] = { 0x00, 0x0a, 0x35, 0x00, 0x01, 0x03 };
	board_t board;
	uint8_t cmdbuf[512];
	uint32_t index;
	uint32_t ip_status, com_status;

	cmd_netif = &server_netif;

	init_platform();

	IP4_ADDR(&ipaddr, 192, 168, 0, 90);
	IP4_ADDR(&netmask, 255, 255, 255, 0);
	IP4_ADDR(&gw, 192, 168, 0, 1);
	print_app_header();

	lwip_init();

	if (!xemac_add(cmd_netif, &ipaddr, &netmask, &gw, mac_ethernet_address, PLATFORM_EMAC_BASEADDR))
	{
		xil_printf("Error adding N/W interface\n\r");
		return -1;
	}
	netif_set_default(cmd_netif);

	platform_enable_interrupts();
	netif_set_up(cmd_netif);
	print_ip_settings(&ipaddr, &netmask, &gw);

	start_application();

	vchess_init_board(&board);
	vchess_load_board(&board);
	index = 0;
	ip_status = 0;
	com_status = 0;

	while (1)
	{
		if (XUartPs_IsReceiveData(XPAR_XUARTPS_0_BASEADDR))
			com_status = process_serial_port(cmdbuf, &index);
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
		xemacif_input(cmd_netif);
		ip_status = cmd_transfer_data(cmdbuf, &index);
		if (ip_status || com_status)
		{
			process_cmd(cmdbuf);
			index = 0;
			ip_status = 0;
			com_status = 0;
		}
	}

	cleanup_platform();

	return 0;
}
