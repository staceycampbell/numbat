#include <stdio.h>
#include <stdint.h>
#include <xil_printf.h>
#include <ff.h>
#include "vchess.h"

void
book_build(void)
{
        FRESULT status;
        FIL fp;

        static char *fn = "popular.txt";
        static int fs_init = 0;
        static FATFS fatfs;
        static TCHAR *path = "0:/";

#if 0
        BYTE work[FF_MAX_SS];
        status = f_mkfs(path, FM_FAT32, 0, work, sizeof work);
        if (status != FR_OK)
        {
                xil_printf("%s: f_mkfs fail (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                return;
        }
#endif

        if (!fs_init)
        {
                status = f_mount(&fatfs, path, 0);
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
        xil_printf("%s open\n", fn);
        f_close(&fp);
}
