#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <malloc.h>
#include <xtime_l.h>
#include <xil_printf.h>
#include <ff.h>
#include "vchess.h"

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
        uint32_t counter;
        int32_t len;
        FRESULT status;
        FIL fp;
        XTime t_end, t_start;
        uint64_t elapsed_ticks;
        double elapsed_time, lps;
	book_t *book;
	uint32_t book_size, book_count, book_index;
	board_t board;
        TCHAR buffer[4096];

        static const char *fn = "popular.txt";
        static int fs_init = 0;
        static FATFS fatfs;

        XTime_GetTime(&t_start);

	book_size = 100000;
	book_count = 0;
	book = (book_t *)malloc(book_size * sizeof(book_t));
	if (book == 0)
	{
		xil_printf("%s: unable to malloc %d bytes for book (%s %d)\n", __PRETTY_FUNCTION__, book_size * sizeof(book_t),
			   __FILE__, __LINE__);
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
                }
                ++counter;
        }
        f_close(&fp);

        XTime_GetTime(&t_end);
        elapsed_ticks = t_end - t_start;
        elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
	lps = (double)counter / elapsed_time;
        printf("\n%u lines in %.0f seconds, %.1f lines per second, %s closed\n", counter, elapsed_time, lps, fn);
}
