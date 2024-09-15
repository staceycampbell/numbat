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
#define BUF_SIZE 1024

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
        xil_printf("%d.%d.%d.%d\n\r", ip4_addr1(ip), ip4_addr2(ip), ip4_addr3(ip), ip4_addr4(ip));
}

static void
print_ip_settings(ip_addr_t * ip, ip_addr_t * mask, ip_addr_t * gw)
{
        print_ip("Board IP: ", ip);
        print_ip("Netmask : ", mask);
        print_ip("Gateway : ", gw);
}
#endif

static int
fen_board(uint8_t buffer[BUF_SIZE], board_t * board)
{
        int row, col, i, stop_col;

        row = 7;
        col = 0;
        i = 0;
        while (i < BUF_SIZE && buffer[i] != '\0' && !(buffer[i] == ' ' || buffer[i] == '\t'))
        {
                switch (buffer[i])
                {
                case 'r':
                        vchess_place(board, row, col, BLACK_ROOK);
                        ++col;
                        break;
                case 'n':
                        vchess_place(board, row, col, BLACK_KNIT);
                        ++col;
                        break;
                case 'b':
                        vchess_place(board, row, col, BLACK_BISH);
                        ++col;
                        break;
                case 'q':
                        vchess_place(board, row, col, BLACK_QUEN);
                        ++col;
                        break;
                case 'k':
                        vchess_place(board, row, col, BLACK_KING);
                        ++col;
                        break;
                case 'p':
                        vchess_place(board, row, col, BLACK_PAWN);
                        ++col;
                        break;
                case 'R':
                        vchess_place(board, row, col, WHITE_ROOK);
                        ++col;
                        break;
                case 'N':
                        vchess_place(board, row, col, WHITE_KNIT);
                        ++col;
                        break;
                case 'B':
                        vchess_place(board, row, col, WHITE_BISH);
                        ++col;
                        break;
                case 'Q':
                        vchess_place(board, row, col, WHITE_QUEN);
                        ++col;
                        break;
                case 'K':
                        vchess_place(board, row, col, WHITE_KING);
                        ++col;
                        break;
                case 'P':
                        vchess_place(board, row, col, WHITE_PAWN);
                        ++col;
                        break;
                case '/':
                        col = 0;
                        --row;
                        break;
                default:
                        if (!(buffer[i] >= '1' && buffer[i] <= '8'))
                        {
                                xil_printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                                return 1;
                        }
                        stop_col = col + buffer[i] - '1';
                        while (col <= stop_col)
                        {
                                vchess_place(board, row, col, EMPTY_POSN);
                                ++col;
                        }
                        break;
                }
                ++i;
        }
        ++i;
        if (!(i < BUF_SIZE && (buffer[i] == 'w' || buffer[i] == 'b')))
        {
                xil_printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                return 1;
        }
        board->white_to_move = buffer[i] == 'w';
        i += 2;
        board->castle_mask = 0;
        while (i < BUF_SIZE && buffer[i] != '\0' && !(buffer[i] == ' ' || buffer[i] == '\t'))
        {
                switch (buffer[i])
                {
                case 'K':
                        board->castle_mask |= 1 << CASTLE_WHITE_SHORT;
                        break;
                case 'Q':
                        board->castle_mask |= 1 << CASTLE_WHITE_LONG;
                        break;
                case 'k':
                        board->castle_mask |= 1 << CASTLE_BLACK_SHORT;
                        break;
                case 'q':
                        board->castle_mask |= 1 << CASTLE_BLACK_LONG;
                        break;
                case '-':
                        board->castle_mask = 0;
                        break;
                default:
                        xil_printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                        return 1;
                }
                ++i;
        }
        ++i;
        if (!(i < BUF_SIZE))
        {
                xil_printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                return 1;
        }
// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
        if (!(buffer[i] == '-' || (buffer[i] >= 'a' && buffer[i] <= 'h')))
        {
                xil_printf("%s: bad FEN data %s (%s %d)\n", __PRETTY_FUNCTION__, buffer, __FILE__, __LINE__);
                return 1;
        }
        if (buffer[i] == '-')
                board->en_passant_col = 0 << EN_PASSANT_VALID_BIT;
        else
                board->en_passant_col = (1 << EN_PASSANT_VALID_BIT) | (buffer[i] - 'a');

        return 0;
}

static uint32_t
process_serial_port(uint8_t cmdbuf[BUF_SIZE], uint32_t * index)
{
        unsigned char c;
        uint32_t status;

        c = inbyte();
        xil_printf("%c", c);
        status = c == '\r' || c == '\n' || *index == BUF_SIZE - 1;
        if (status)
                cmdbuf[*index] = '\0';
        else
                cmdbuf[*index] = c;
        ++*index;

        return status;
}

static void
process_cmd(uint8_t cmd[BUF_SIZE])
{
        int /* len, */ move_index;
        char str[BUF_SIZE];
        int arg1, arg2, arg3;
        static board_t board;
        board_t best_board;
        uint32_t status;

        xil_printf("cmd: %s\n", cmd);
#if 0
        len = strlen((char *)cmd);
        tcp_write(cmd_pcb, cmd, len, TCP_WRITE_FLAG_COPY);
        tcp_write(cmd_pcb, "\n", 1, TCP_WRITE_FLAG_COPY);
#endif
        sscanf((char *)cmd, "%s %d %d %d\n", str, &arg1, &arg2, &arg3);

        if (strcmp((char *)str, "status") == 0)
        {
                uint32_t move_ready, moves_ready, mate, stalemate;

                status = vchess_status(&move_ready, &moves_ready, &mate, &stalemate);
                xil_printf("moves_ready=%d, mate=%d, stalemate=%d", moves_ready, mate, stalemate);
                if (moves_ready)
                        xil_printf(", moves=%d, eval=%d", vchess_move_count(), vchess_initial_eval());
                xil_printf("\n");
        }
        else if (strcmp((char *)str, "read") == 0)
        {
                move_index = arg1;
                status = vchess_read_board(&board, move_index);
                if (status == 0)
                        vchess_print_board(&board, 0);
        }
        else if (strcmp((char *)str, "init") == 0)
        {
                vchess_init_board(&board);
                vchess_move_piece(&board, 0, 3, 3, 3);
                vchess_write_board(&board);
                vchess_print_board(&board, 1);
        }
        else if (strcmp((char *)str, "nm") == 0)
        {
                best_board = nm_top(&board);
                vchess_print_board(&best_board, 0);
        }
        else
        {
                fen_board(cmd, &board);
                vchess_write_board(&board);
                vchess_print_board(&board, 1);
        }
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
                xil_printf("Error adding N/W interface\n\r");
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

        xil_printf("ready\n");

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
