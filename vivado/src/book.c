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

#pragma GCC optimize ("O2")

#define SORT_THRESHOLD 64

extern board_t game[GAME_MAX];
extern uint32_t game_moves;

static const TCHAR *sd_path = "0:/";
static const char *book_bin_fn = "book.bin";
static int fs_init = 0;
static FATFS fatfs;

static book_t *book;
static uint32_t book_count;

void
book_print_entry(book_t * entry)
{
        char str[6];
        uint32_t hash_high, hash_low;

        hash_high = entry->hash >> 32;
        hash_low = entry->hash << 32 >> 32;
        uci_string(&entry->uci, str);
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
book_game_move(const board_t * board)
{
        int32_t trans_idle;
        uint64_t hash;
        uint16_t hash_extra;
        uint32_t found, move_count, i, status, confirmed;
        board_t next_board;
        uci_t uci;
        char uci_str[6];

        vchess_write_board_basic(board);
        vchess_trans_hash_only();
        trans_idle = vchess_trans_idle_wait();
        if (!trans_idle)
        {
                xil_printf("%s: hash state machine idle timeout, stopping. (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                while (1);
        }
        hash = vchess_trans_hash(&hash_extra);
        found = book_move(hash_extra, hash, BOOK_RANDOM_COMMON, &uci);
        if (!found)
                return 0;

        vchess_write_board_wait(0);
        vchess_capture_moves(0);
        move_count = vchess_move_count();
        if (move_count == 0)
                return 0;       // game is over

        // test for hash collision which could result in an illegal move
        confirmed = 0;
        i = 0;
        do
        {
                status = vchess_read_board(&next_board, i);
                if (status)
                {
                        xil_printf("%s: problem with vchess_read_board (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                        return 0;
                }
                confirmed = uci_match(&uci, &next_board.uci);
                ++i;
        }
        while (i < move_count && !confirmed);

        if (!confirmed)
        {
                xil_printf("%s: book returned move %s that is not in all_moves!\n", __PRETTY_FUNCTION__, uci_str);
                return 0;
        }

        uci_string(&uci, uci_str);
        uci_move(uci_str);

        return 1;
}

uint32_t
book_move(uint16_t hash_extra, uint64_t hash, uint32_t sel_flag, uci_t * uci)
{
        int32_t book_index, i, start_index, end_index, sel_index, random_count;
        book_t *book_entry_found, book_entry;

        book_entry.hash_extra = hash_extra;
        book_entry.hash = hash;
        book_entry_found = bsearch(&book_entry, book, book_count, sizeof(book_t), book_compare);
        if (!book_entry_found)
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
        switch (sel_flag)
        {
        case BOOK_MOST_COMMON:
                sel_index = start_index;
                break;
        case BOOK_RANDOM:
                sel_index = vchess_random() % (end_index - start_index + 1) + start_index;
                break;
        case BOOK_RANDOM_COMMON:
        default:
                random_count = vchess_random() % book[start_index].count;
                sel_index = end_index;
                while (sel_index >= start_index && book[sel_index].count < random_count)
                        --sel_index;
                break;
        }

        *uci = book[sel_index].uci;

        return 1;
}

int32_t
book_open(void)
{
        FRESULT status;
        FIL fp;
        uint32_t bytes, br;
        static int32_t book_init = 0;

        if (book_init)
                return 0;
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
        book = (book_t *) malloc(bytes);
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

        book_init = 1;

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
        if (b1->count > b2->count)
                return -1;
        if (b1->count < b2->count)
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
        uint32_t bw;
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

        sorted_hit = 0;
        unsorted_hit = 0;
        counter = 0;
        sorted_counter = 0;
        unsorted_index = 0;
        next_sort = SORT_THRESHOLD;
        xil_printf("%s opened\n", fn);
        while (counter < 2000000 && f_gets(buffer, sizeof(buffer), &fp))
        {
                len = strnlen(buffer, sizeof(buffer) - 2);
                if (len > 0)
                {
                        buffer[len - 1] = '\0';
                        if (counter % 4096 == 0)
                                xil_printf("line %9d: %s, book_count=%u, sorted_hit=%u, unsorted_hit=%u\r",
                                           counter, buffer, book_count, sorted_hit, unsorted_hit);
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
                                                                qsort(book, sorted_counter, sizeof(book_t), book_compare_uci);
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

        status = f_open(&fp, book_bin_fn, FA_CREATE_ALWAYS | FA_WRITE);
        if (status != FR_OK)
        {
                xil_printf("%s: cannot write %s\n", __PRETTY_FUNCTION__, book_bin_fn);
                return;
        }
        status = f_write(&fp, (void *)book, book_count * sizeof(book_t), &bw);
        xil_printf("\n%s: %u bytes (%u x %u) written to %s\n", __PRETTY_FUNCTION__, bw, book_count, sizeof(book_t), book_bin_fn);
        f_close(&fp);

        XTime_GetTime(&t_end);
        elapsed_ticks = t_end - t_start;
        elapsed_time = (double)elapsed_ticks / (double)COUNTS_PER_SECOND;
        lps = (double)counter / elapsed_time;
        printf("\n%u lines in %.0f seconds, %.1f lines per second\n", counter, elapsed_time, lps);
        printf("%u book entries, %u sorted hits, %u unsorted hits\n", book_count, sorted_hit, unsorted_hit);

        free(book);
}
