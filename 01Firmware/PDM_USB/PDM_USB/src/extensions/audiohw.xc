#include <xs1.h>

#include <assert.h>
#include "devicedefines.h"
#include <platform.h>
#include "print.h"

void genclock()
{
    return;
}

void wait_us(int microseconds)
{
    timer t;
    unsigned time;

    t :> time;
    t when timerafter(time + (microseconds * 100)) :> void;
}

void AudioHwInit(chanend ?c_codec)
{
    return;
}

/* Configures the external audio hardware for the required sample frequency.
 * See gpio.h for I2C helper functions and gpio access
 */
void AudioHwConfig( unsigned samFreq,
                    unsigned mClk,
                    chanend ?c_codec,
                    unsigned dsdMode,
                    unsigned sampRes_DAC,
                    unsigned sampRes_ADC)
{
    return;
}
