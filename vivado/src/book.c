#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <malloc.h>
#include <stdlib.h>
#include <inttypes.h>
#include <xtime_l.h>
#include <xil_printf.h>
#include <ff.h>
#include "vchess.h"

// #pragma GCC optimize ("O3")

#define SORT_THRESHOLD 256

extern board_t game[GAME_MAX];
extern uint32_t game_moves;

static const TCHAR *sd_path = "0:/";
static const char *book_bin_fn = "book.bin";
static int fs_init = 0;
static FATFS fatfs;

static book_t *book;
static uint32_t book_count;

static void
book_print_entry(book_t *entry)
{
        char str[6];
        uint32_t hash_high, hash_low;

        hash_high = entry->hash >> 32;
        hash_low = entry->hash << 32 >> 32;
        vchess_uci_string(&entry->uci, str);
        printf("hash_extra=%4X hash=%08X%08X count=%6d %s\n", entry->hash_extra, hash_high, hash_low, entry->count, str);
}

static int32_t
book_compare(const void *p1, const void *p2)
{
        const book_t *b1, *b2;

        b1 = (book_t *) p1;
        b2 = (book_t *) p2;

        if (b1->hash_extra < b2->hash_extra)
                return -1;
        if (b1->hash_extra > b2->hash_extra)
                return 1;
        if (b1->hash < b2->hash)
                return -1;
        if (b1->hash > b2->hash)
                return 1;
        return 0;
}

uint32_t
book_move(uint16_t hash_extra, uint64_t hash, uci_t *uci, uint32_t sel_flag)
{
	int32_t book_index, i, start_index, end_index;
	book_t *book_entry_found, book_entry;

	book_entry.hash_extra = hash_extra;
	book_entry.hash = hash;
	book_entry_found = bsearch(&book_entry, book, book_count, sizeof(book_t), book_compare);
	if (! book_entry_found)
		return 0;
	book_index = book_entry_found - book;
	i = book_index;
	if (i > 0)
	{
		while (i >= 0 && book[i].hash_extra == hash_extra && book[i].hash == hash)
			--i;
		if (i < 0)
			start_index = 0;
		else
			start_index = i + 1;
	}
	else
		start_index = 0;
	i = book_index;
	if (i < book_count)
	{
		while (i < book_count && book[i].hash_extra == hash_extra && book[i].hash == hash)
			++i;
		if (i == book_count)
			end_index = book_count - 1;
		else
			end_index = i - 1;
	}
	else
		end_index = book_count - 1;
	xil_printf("start_index=%d end_index=%d\n", start_index, end_index);
	for (i = start_index; i <= end_index; ++i)
		book_print_entry(&book[i]);
	*uci = book[end_index].uci;
	xil_printf("looking for more\n");
	for (i = 0; i < book_count; ++i)
		if (book[i].hash_extra == hash_extra && book[i].hash == hash)
			book_print_entry(&book[i]);

	return 1;
}

int32_t
book_open(void)
{
        FRESULT status;
        FIL fp;
        uint32_t bytes, br, i;
        
        if (!fs_init)
        {
                status = f_mount(&fatfs, sd_path, 0);
                if (status != FR_OK)
                {
                        xil_printf("%s: SD filesystem mount failed (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                        return -2;
                }
                fs_init = 1;
        }
        status = f_open(&fp, book_bin_fn, FA_READ);
        if (status != FR_OK)
        {
                xil_printf("%s: cannot read %s\n", __PRETTY_FUNCTION__, book_bin_fn);
                return -1;
        }
        bytes = f_size(&fp);
        book_count = bytes / sizeof(book_t);
        book = (book_t *)malloc(bytes);
        if (book == 0)
        {
                xil_printf("%s: book malloc failed with %d entries\n", __PRETTY_FUNCTION__, book_count);
                return -1;
        }
        xil_printf("%s: reading %d entries from %s\n", __PRETTY_FUNCTION__, book_count, book_bin_fn);
        status = f_read(&fp, book, bytes, &br);
        if (status != FR_OK)
        {
                xil_printf("%s: %s f_read failed (%d)\n", __PRETTY_FUNCTION__, book_bin_fn, status);
                return -1;
        }
        if (bytes != br)
        {
                xil_printf("%s: asked for %d byts from %s, received %d\n", __PRETTY_FUNCTION__, bytes, br);
                return -1;
        }
        f_close(&fp);

        xil_printf("first 10 book entries\n");
        for (i = 0; i < 10; ++i)
                book_print_entry(&book[i]);
        xil_printf("last 10 book entries\n");
        for (i = book_count - 10; i < book_count; ++i)
                book_print_entry(&book[i]);

        return 0;
}

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

static int32_t
book_compare_uci(const void *p1, const void *p2)
{
        const book_t *b1, *b2;

        b1 = (book_t *) p1;
        b2 = (book_t *) p2;

        if (b1->hash_extra < b2->hash_extra)
                return -1;
        if (b1->hash_extra > b2->hash_extra)
                return 1;
        if (b1->hash < b2->hash)
                return -1;
        if (b1->hash > b2->hash)
                return 1;
	if (b1->uci.row_from < b2->uci.row_from)
		return -1;
	if (b1->uci.row_from > b2->uci.row_from)
		return 1;
	if (b1->uci.col_from < b2->uci.col_from)
		return -1;
	if (b1->uci.col_from > b2->uci.col_from)
		return 1;
        return 0;
}

static int32_t
book_compare_count(const void *p1, const void *p2)
{
        const book_t *b1, *b2;
	int32_t initial;

	initial = book_compare_uci(p1, p2);

	if (initial != 0)
		return initial;

        b1 = (book_t *) p1;
        b2 = (book_t *) p2;

	if (b1->count < b2->count)
		return -1;
	if (b1->count > b2->count)
		return 1;
        return 0;
}

void
book_build(void)
{
        uint32_t counter, done, sorted_counter, unsorted_index, next_sort;
        uint32_t sorted_hit, unsorted_hit;
        int32_t len, move_ok;
        uint32_t trans_idle;
        uint64_t hash;
        uint16_t hash_extra;
        char *uci_str_ptr, *c;
        FRESULT status;
        FIL fp;
        XTime t_end, t_start;
        uint64_t elapsed_ticks;
        double elapsed_time, lps;
        book_t book_entry, *book_entry_found;
        uint32_t book_size, book_index;
        TCHAR buffer[4096];

        static const char *fn = "popular.txt";

        XTime_GetTime(&t_start);

        book_size = 100000;
        book_count = 0;
        book = (book_t *) malloc(book_size * sizeof(book_t));
        if (book == 0)
        {
                xil_printf("%s: unable to malloc %d bytes for book (%s %d)\n", __PRETTY_FUNCTION__, book_size * sizeof(book_t), __FILE__, __LINE__);
                return;
        }

        if (!fs_init)
        {
                status = f_mount(&fatfs, sd_path, 0);
                if (status != FR_OK)
                {
                        free(book);
                        xil_printf("%s: SD filesystem mount failed (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                        return;
                }
                fs_init = 1;
        }

        status = f_open(&fp, fn, FA_READ);
        if (status != FR_OK)
        {
                free(book);
                xil_printf("%s: cannot read %s (%s %d)\n", __PRETTY_FUNCTION__, fn, __FILE__, __LINE__);
                return;
        }

	uint32_t pboard;
	board_t tboard;

        sorted_hit = 0;
        unsorted_hit = 0;
        counter = 0;
        sorted_counter = 0;
        unsorted_index = 0;
        next_sort = SORT_THRESHOLD;
        xil_printf("%s opened\n", fn);
        while (counter < 1000000 && f_gets(buffer, sizeof(buffer), &fp))
        {
                len = strnlen(buffer, sizeof(buffer) - 2);
                if (len > 0)
                {
                        buffer[len - 1] = '\0';
                        if (counter % 4096 == 0)
                                xil_printf("line %9d: %s, book_count=%u, sorted_hit=%u, unsorted_hit=%u\r",
                                           counter, buffer, book_count, sorted_hit, unsorted_hit);
                        uci_init();
			tboard = game[game_moves - 1];
			pboard = 1;
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
				if (pboard)
				{
					fen_print(&tboard);
					fen_print(&game[game_moves - 1]);
					pboard = 0;
				}
                                uci_str_ptr = strsep(&c, " \n\r");
                                done = uci_str_ptr == 0;
                                if (!done)
                                {
                                        move_ok = uci_move(uci_str_ptr) == 0;
                                        if (!move_ok)
                                        {
                                                free(book);
                                                xil_printf("%s: bad uci data line %d. (%s %d)\n", __PRETTY_FUNCTION__,
                                                           counter + 1, __FILE__, __LINE__);
                                                return;
                                        }
                                        book_entry.count = 1;
                                        book_entry.hash = hash;
                                        book_entry.hash_extra = hash_extra;
                                        book_entry.uci = game[game_moves - 1].uci;

                                        book_entry_found = bsearch(&book_entry, book, sorted_counter, sizeof(book_t), book_compare_uci);

                                        if (book_entry_found)
                                        {
                                                book_index = book_entry_found - book;
                                                ++sorted_hit;
                                                ++book[book_index].count;
                                        }
                                        else
                                        {
                                                book_index = unsorted_index;
                                                while (book_index < book_count &&
                                                       !(hash == book[book_index].hash &&
							 hash_extra == book[book_index].hash_extra &&
							 uci_match(&book[book_index].uci, &book_entry.uci)))
                                                        ++book_index;
                                                if (book_index < book_count)
                                                {
                                                        ++unsorted_hit;
                                                        ++book[book_index].count;
                                                }
                                                else
                                                {
                                                        book[book_count] = book_entry;
                                                        ++book_count;
                                                        if (book_count == book_size)
                                                        {
                                                                book_size += 10000;
                                                                book = (book_t *) realloc(book, book_size * sizeof(book_t));
                                                                if (book == 0)
                                                                {
                                                                        xil_printf("%s: realloc of %d failed. (%s %d)\n", __PRETTY_FUNCTION__,
                                                                                   book_size * sizeof(book_t), __FILE__, __LINE__);
                                                                        return;
                                                                }
                                                        }
                                                        if (book_count == next_sort)
                                                        {
                                                                sorted_counter = book_count;
                                                                unsorted_index = book_count;
                                                                qsort(book, sorted_counter, sizeof(book_t), book_compare);
                                                                next_sort = next_sort + SORT_THRESHOLD;
                                                        }
                                                }
                                        }
                                }
                        }
                        while (!done);
                }
                ++counter;
        }
        f_close(&fp);

        qsort(book, book_count, sizeof(book_t), book_compare_count);

//        status = f_open(&fp, book_bin_fn, FA_CREATE_ALWAYS | FA_WRITE);
//        if (status != FR_OK)
//        {
//                xil_printf("%s: cannot write %s\n", __PRETTY_FUNCTION__, book_bin_fn);
//                return;
//        }
//        status = f_write(&fp, (void *)book, book_count * sizeof(book_t), &bw);
//        xil_printf("\n%s: %u bytes (%u x %u) written to %s\n", __PRETTY_FUNCTION__, bw, book_count, sizeof(book_t), book_bin_fn);
//        f_close(&fp);

        XTime_GetTime(&t_end);
        elapsed_ticks = t_end - t_start;
        elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
        lps = (double)counter / elapsed_time;
        printf("\n%u lines in %.0f seconds, %.1f lines per second\n", counter, elapsed_time, lps);
        printf("%u book entries, %u sorted hits, %u unsorted hits\n", book_count, sorted_hit, unsorted_hit);

//         free(book);
}