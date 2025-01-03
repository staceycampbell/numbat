// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <stdio.h>
#include <xparameters.h>
#include <netif/xadapter.h>
#include <lwip/tcp.h>
#include <lwip/priv/tcp_priv.h>
#include <lwip/init.h>
#include <xil_cache.h>
#include <xuartps.h>
#include <xtime_l.h>
#include "numbat.h"

#define PLATFORM_EMAC_BASEADDR XPAR_XEMACPS_0_BASEADDR

board_t game[GAME_MAX];
uint32_t game_moves;
uint32_t tc_main = 15;          // minutes
uint32_t tc_increment = 0;      // seconds

extern volatile int TcpFastTmrFlag;
extern volatile int TcpSlowTmrFlag;
static struct netif server_netif;

struct netif *uci_netif;

static void
print_ip(char *msg, ip_addr_t * ip)
{
        print(msg);
        printf("%d.%d.%d.%d\n\r", ip4_addr1(ip), ip4_addr2(ip), ip4_addr3(ip), ip4_addr4(ip));
}

static void
print_ip_settings(ip_addr_t * ip, ip_addr_t * mask, ip_addr_t * gw)
{
        print_ip("Board IP: ", ip);
        print_ip("Netmask : ", mask);
        print_ip("Gateway : ", gw);
}

static uint32_t
process_serial_port(uint8_t cmdbuf[BUF_SIZE], uint32_t * index)
{
        unsigned char c;
        uint32_t status;

        c = inbyte();
        printf("%c", c);
        fflush(stdout);
        status = c == '\r' || c == '\n' || *index == BUF_SIZE - 1;
        if (status)
                cmdbuf[*index] = '\0';
        else
                cmdbuf[*index] = c;
        ++*index;

        return status;
}

int
main(void)
{
        ip_addr_t ipaddr, netmask, gw;
        unsigned char mac_ethernet_address[] = { 0x00, 0x0a, 0x35, 0xaf, 0x01, 0x03 };
        uint8_t cmdbuf[BUF_SIZE];
        uint32_t index;
        uint32_t com_status;

        uci_netif = &server_netif;

        init_platform();

        IP4_ADDR(&ipaddr, 192, 168, 0, 90);
        IP4_ADDR(&netmask, 255, 255, 255, 0);
        IP4_ADDR(&gw, 192, 168, 0, 1);
        lwip_init();

        if (!xemac_add(uci_netif, &ipaddr, &netmask, &gw, mac_ethernet_address, PLATFORM_EMAC_BASEADDR))
        {
                printf("%s: error adding N/W interface, stopping\n", __PRETTY_FUNCTION__);
                while (1);
        }
        netif_set_default(uci_netif);

        platform_enable_interrupts();
        netif_set_up(uci_netif);
        print_ip_settings(&ipaddr, &netmask, &gw);
        start_application();

        index = 0;
        com_status = 0;

        numbat_init();
        trans_clear_table();
        q_trans_clear_table();
        killer_clear_table();
        killer_bonus(100, 90);
        uci_init();
        uci_input_reset();
        book_open();
        numbat_random_score_mask(0x0);

        printf("ready\n");

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
                xemacif_input(uci_netif);
                uci_input_poll();
                if (com_status)
                {
                        process_cmd(cmdbuf);
                        index = 0;
                        com_status = 0;
                }
        }

        return 0;
}
