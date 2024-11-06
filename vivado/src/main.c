#include <stdio.h>
#include <xparameters.h>
#include <netif/xadapter.h>
#include <lwip/tcp.h>
#include <lwip/priv/tcp_priv.h>
#include <lwip/init.h>
#include <xil_cache.h>
#include <xuartps.h>
#include <xtime_l.h>
#include "vchess.h"

#define PLATFORM_EMAC_BASEADDR XPAR_XEMACPS_0_BASEADDR

board_t game[GAME_MAX];
uint32_t game_moves;
uint32_t tc_main = 15; // minutes
uint32_t tc_increment = 0; // seconds
static tc_t tc;

#if 0
extern volatile int TcpFastTmrFlag;
extern volatile int TcpSlowTmrFlag;
static struct netif server_netif;

struct netif *cmd_netif;
struct tcp_pcb *cmd_pcb;

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
#endif

void
do_both(void)
{
        uint32_t move_count, key_hit, game_result;
        uint32_t book_move_found;
        board_t best_board;
        uint32_t mate, stalemate, thrice_rep, fifty_move, insufficient;
        XTime t_end, t_start;
        uint64_t elapsed_ticks;
        double elapsed_time;
	uint32_t tc_status;

        XTime_GetTime(&t_start);

        book_open();
	tc_init(&tc, tc_main * 60, tc_increment);

        do
        {
                book_move_found = book_game_move(&game[game_moves - 1]);
                if (book_move_found)
                {
                        printf("book move\n");

                        mate = 0;
                        stalemate = 0;
                        thrice_rep = 0;
                        fifty_move = 0;
			insufficient = 0;
                        move_count = 1;
                        best_board = game[game_moves - 1];
                }
                else
                {
                        best_board = nm_top(game, game_moves, &tc);
                        vchess_write_board_basic(&best_board);
                        vchess_write_board_wait(&best_board);
                        move_count = vchess_move_count();
                        vchess_status(0, 0, &mate, &stalemate, &thrice_rep, 0, &fifty_move, &insufficient, 0);
                        vchess_reset_all_moves();
                        game[game_moves] = best_board;
                        ++game_moves;
                }
		tc_status = tc_clock_toggle(&tc);
                if (game_moves >= GAME_MAX)
                {
                        printf("%s: game_moves (%d) >= GAME_MAX (%d), stopping here %s %d\n", __PRETTY_FUNCTION__,
                                   game_moves, GAME_MAX, __FILE__, __LINE__);
                        while (1);
                }
                vchess_print_board(&best_board, 1);
                fen_print(&best_board);
                printf("\n");
                key_hit = XUartPs_IsReceiveData(XPAR_XUARTPS_0_BASEADDR);
        }
        while (move_count > 0 && !(mate || stalemate || thrice_rep || fifty_move || insufficient) && tc_status == TC_OK && !key_hit);
        XTime_GetTime(&t_end);
        elapsed_ticks = t_end - t_start;
        elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
        printf("total elapsed time: %.1f\n", elapsed_time);
        if (key_hit)
	{
                printf("Abort\n");
		tc_ignore(&tc);
	}
        else
        {
		printf("white clock: %d, black clock %d\n", tc.main_remaining[0], tc.main_remaining[1]);
                printf("both done: mate %d, stalemate %d, thrice rep %d, fifty move: %d, insufficient: %d\n\n",
			   mate, stalemate, thrice_rep, fifty_move, insufficient);
                if (mate)
                        if (best_board.white_in_check)
                                game_result = RESULT_BLACK_WIN;
                        else
                                game_result = RESULT_WHITE_WIN;
                else
                        game_result = RESULT_DRAW;
                uci_print_game(game_result);
        }
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
        // ip_addr_t ipaddr, netmask, gw;
        // unsigned char mac_ethernet_address[] = { 0x00, 0x0a, 0x35, 0x00, 0x01, 0x03 };
        uint8_t cmdbuf[BUF_SIZE];
        uint32_t index;
        uint32_t /* ip_status, */ com_status;

#if 0
        cmd_netif = &server_netif;
#endif

        init_platform();

#if 0
        IP4_ADDR(&ipaddr, 192, 168, 0, 90);
        IP4_ADDR(&netmask, 255, 255, 255, 0);
        IP4_ADDR(&gw, 192, 168, 0, 1);
        print_app_header();
        lwip_init();

        if (!xemac_add(cmd_netif, &ipaddr, &netmask, &gw, mac_ethernet_address, PLATFORM_EMAC_BASEADDR))
        {
                printf("Error adding N/W interface\n\r");
                return -1;
        }
        netif_set_default(cmd_netif);

        platform_enable_interrupts();
        netif_set_up(cmd_netif);
        print_ip_settings(&ipaddr, &netmask, &gw);

        start_application();
#endif

        vchess_init();

        index = 0;
        // ip_status = 0;
        com_status = 0;

        trans_clear_table();
        uci_init();

        printf("ready\n");

        while (1)
        {
                if (XUartPs_IsReceiveData(XPAR_XUARTPS_0_BASEADDR))
                        com_status = process_serial_port(cmdbuf, &index);
#if 0
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
#endif
                if ( /* ip_status || */ com_status)
                {
                        process_cmd(cmdbuf);
                        index = 0;
                        // ip_status = 0;
                        com_status = 0;
                }
        }

        cleanup_platform();

        return 0;
}
