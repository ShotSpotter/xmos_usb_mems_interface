/*
    boardrev.xc

    Robert B. Calhoun <rcalhoun@soundthinking.com>

    Both XUD and PDM code need to know the board rev but they
    run on different tiles, so we need a thread that queries
    the board rev fuses and distributes it to both tiles via
    xmos channels.

    On Tile 0 (pdm tile) channel is read from pcm_pdm_mic.xc
    On Tile 1 (usb tile) channel is read from endpoint0.c

    XMOS endpoint0 is inexplicably written in straight C and
    can't accept XC syntax, so define a reader
    function in this XC code that can be linked from endpoint0.c
*/
#include "boardrev.h"
#ifdef DEBUG
#include <stdio.h>
#endif


int boardrev_fuse_wait_value(chanend c_boardrev, int tile)
{
#ifdef DEBUG
    printf("boardrev_fuse_wait_value start tile %d\n", tile);
#endif
    int value;
#ifdef DEBUG
    printf("boardrev_fuse_wait_value\n");
#endif
    c_boardrev :> value;
#ifdef DEBUG
    printf("boardrev_fuse_wait_value tile %d retval %d\n", tile, value);
#endif
    return value;
}
