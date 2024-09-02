#include <stdio.h>
#include <xparameters.h>
#include <netif/xadapter.h>
#include <xil_printf.h>
#include <lwip/tcp.h>
#include <lwip/priv/tcp_priv.h>
#include <lwip/init.h>
#include <xil_cache.h>
#include "vchess.h"

#define PLATFORM_EMAC_BASEADDR XPAR_XEMACPS_0_BASEADDR

extern volatile int TcpFastTmrFlag;
extern volatile int TcpSlowTmrFlag;
static struct netif server_netif;
struct netif *echo_netif;

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

int
main(void)
{
	ip_addr_t ipaddr, netmask, gw;
	unsigned char mac_ethernet_address[] = { 0x00, 0x0a, 0x35, 0x00, 0x01, 0x03 };

	echo_netif = &server_netif;

	init_platform();

	IP4_ADDR(&ipaddr, 192, 168, 0, 90);
	IP4_ADDR(&netmask, 255, 255, 255, 0);
	IP4_ADDR(&gw, 192, 168, 0, 1);
	print_app_header();

	lwip_init();

	if (!xemac_add(echo_netif, &ipaddr, &netmask, &gw, mac_ethernet_address, PLATFORM_EMAC_BASEADDR))
	{
		xil_printf("Error adding N/W interface\n\r");
		return -1;
	}
	netif_set_default(echo_netif);

	platform_enable_interrupts();
	netif_set_up(echo_netif);
	print_ip_settings(&ipaddr, &netmask, &gw);

	start_application();

	while (1)
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
		xemacif_input(echo_netif);
		transfer_data();
	}

	cleanup_platform();

	return 0;
}
