#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <malloc.h>
#include <xtime_l.h>
#include <xil_printf.h>
#include <ff.h>
#include "vchess.h"

#pragma GCC optimize ("O3")

extern board_t game[GAME_MAX];
extern uint32_t game_moves;

static const TCHAR *sd_path = "0:/";

void
book_format_media(void)
{
        FRESULT status;
        BYTE work[FF_MAX_SS];

        status = f_mkfs(sd_path, FM_FAT32, 0, work, sizeof work);
        if (status != FR_OK)
        {
                xil_printf("%s: f_mkfs fail (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                return;
        }
}

void
book_build(void)
{
        uint32_t counter, done;
	uint32_t entry_hit;
        int32_t len, move_ok;
        uint32_t trans_idle;
        uint32_t hash;
        uint16_t hash_extra;
        char *uci_str_ptr, *c;
        FRESULT status;
        FIL fp;
        XTime t_end, t_start;
        uint64_t elapsed_ticks;
        double elapsed_time, lps;
        book_t *book;
        uint32_t book_size, book_count, book_index;
        TCHAR buffer[4096];

        static const char *fn = "popular.txt";
        static int fs_init = 0;
        static FATFS fatfs;

        XTime_GetTime(&t_start);

        book_size = 100000;
        book_count = 0;
        book = (book_t *) malloc(book_size * sizeof(book_t));
        if (book == 0)
        {
                xil_printf("%s: unable to malloc %d bytes for book (%s %d)\n", __PRETTY_FUNCTION__,
                           book_size * sizeof(book_t), __FILE__, __LINE__);
                return;
        }

        if (!fs_init)
        {
                status = f_mount(&fatfs, sd_path, 0);
                if (status != FR_OK)
                {
                        xil_printf("%s: SD filesystem mount failed (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                        return;
                }
                fs_init = 1;
        }

        status = f_open(&fp, fn, FA_READ);
        if (status != FR_OK)
        {
                xil_printf("%s: cannot read %s (%s %d)\n", __PRETTY_FUNCTION__, fn, __FILE__, __LINE__);
                return;
        }

	entry_hit = 0;
        counter = 0;
        xil_printf("%s opened\n", fn);
        while (counter < 100000 && f_gets(buffer, sizeof(buffer), &fp))
        {
                len = strnlen(buffer, sizeof(buffer) - 2);
                if (len > 0)
                {
                        buffer[len - 1] = '\0';
                        if (counter % 4096 == 0)
                                xil_printf("line %9d: %s\r", counter, buffer);
                        uci_init();
                        c = buffer;
                        do
                        {
                                vchess_write_board_basic(&game[game_moves - 1]);
                                vchess_trans_hash_only();
                                trans_idle = vchess_trans_idle_wait();
                                if (!trans_idle)
                                {
                                        xil_printf("%s: hash state machine idle timeout, stopping. (%s %d)\n",
                                                   __PRETTY_FUNCTION__, __FILE__, __LINE__);
                                        while (1);
                                }
                                hash = vchess_trans_hash(&hash_extra);
                                uci_str_ptr = strsep(&c, " \n\r");
                                done = uci_str_ptr == 0;
                                if (!done)
                                {
                                        move_ok = uci_move(uci_str_ptr) == 0;
                                        if (!move_ok)
                                        {
                                                xil_printf("%s: bad uci data %d. (%s %d)\n", __PRETTY_FUNCTION__,
                                                           move_ok, __FILE__, __LINE__);
                                                return;
                                        }
                                        book_index = 0;
                                        while (book_index < book_count &&
                                               !(hash == book[book_index].hash &&
                                                 hash_extra == book[book_index].hash_extra &&
                                                 uci_match(&game[game_moves - 2].uci, &game[game_moves - 1].uci)))
                                                ++book_index;
					if (book_index < book_count)
					{
						++entry_hit;
						++book[book_index].count;
					}
					else
					{
						++book_index;
						if (book_index == book_size)
						{
							book_size += 10000;
							book = (book_t *)realloc(book, book_size * sizeof(book_t));
							if (book == 0)
							{
								xil_printf("%s: realloc of %d failed. (%s %d)\n", __PRETTY_FUNCTION__,
									   book_size * sizeof(book_t), __FILE__, __LINE__);
								return;
							}
						}
						book[book_index].count = 1;
						book[book_index].hash = hash;
						book[book_index].hash_extra = hash_extra;
						book[book_index].uci = game[game_moves - 1].uci;
						++book_count;
					}
                                }
                        }
                        while (!done);
                }
                ++counter;
        }
        f_close(&fp);

        XTime_GetTime(&t_end);
        elapsed_ticks = t_end - t_start;
        elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
        lps = (double)counter / elapsed_time;
        printf("\n%u lines in %.0f seconds, %.1f lines per second, %s closed\n", counter, elapsed_time, lps, fn);
	printf("%u book entries, %u book hits\n", book_count, entry_hit);
}
