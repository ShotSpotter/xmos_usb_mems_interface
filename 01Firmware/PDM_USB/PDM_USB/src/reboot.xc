#include <xs1.h>
#include <platform.h>
#include <xs1_su.h>

#include "xud.h"

#define PLL_MASK 0x7FFFFFFF

extern tileref tile[];

inline void reboot_tile(unsigned int tileId)
{
    unsigned int pllVal;

    read_sswitch_reg(tileId, 6, pllVal);
    pllVal &= PLL_MASK;
    write_sswitch_reg_no_ack(tileId, 6, pllVal);
}

void device_reboot_aux(void)
{
    unsigned int localTileId = get_local_tile_id();
    unsigned int tileId;
    unsigned int tileArrayLength;

    /* Find size of tile array */
    asm volatile ("ldc %0, tile.globound":"=r"(tileArrayLength));

    /* Reset all remote tiles */
    for (int i = 0; i < tileArrayLength; i++)
    {
        tileId = get_tile_id(tile[i]);

        /* Do not reboot local tile yet! */
        if (localTileId == tileId) {
            continue;
        }

        reboot_tile(tileId);
    }

    /* Finally reboot the local tile */
    reboot_tile(localTileId);
}

/* Reboots XMOS device by writing to the PLL config register */
void device_reboot(chanend spare)
{
    device_reboot_aux();

    while(1);
}
