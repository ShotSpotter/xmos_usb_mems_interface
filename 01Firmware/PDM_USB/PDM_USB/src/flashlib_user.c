#include "devicedefines.h"
#include "uac_hwresources.h"

#ifdef DFU

#include <xs1.h>
#include <xclib.h>
#include <quadflashlib.h>

fl_QSPIPorts p_qflash =
{
    XS1_PORT_1B,
    XS1_PORT_1C,
    XS1_PORT_4B,
    CLKBLK_FLASHLIB
};

/* return 1 for opened ports successfully */
int flash_cmd_enable_ports()
{
    int result = 0;
    /* Use default flash list */
    result = fl_connect(&p_qflash);

    if (!result)
    {
        /* All okay.. */
        return 1;
    }
    else
    {
        return 0;
    }
}

int flash_cmd_disable_ports()
{
    fl_disconnect();

    return 1;
}
#endif
