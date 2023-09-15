#include "reset.h"
#include "asic_types.h"
#include "stdint.h"
#include "uprintf.h"

// Configure watchdog register base address for each chip type
#if   ASIC_TYP==ASIC_TYP_NETX500
static const uint32_t ulWdgBaseAddr = 0x00100200;
#elif ASIC_TYP==ASIC_TYP_NETX50
static const uint32_t ulWdgBaseAddr = 0x1c000200;
#elif ASIC_TYP==ASIC_TYP_NETX10
static const uint32_t ulWdgBaseAddr = 0x101c0200;
#elif ASIC_TYP==ASIC_TYP_NETX56
static const uint32_t ulWdgBaseAddr = 0x1018c5b0;
#elif ASIC_TYP==ASIC_TYP_NETX6
#error "What even is this chip type?"
#elif ASIC_TYP==ASIC_TYP_NETX4000_RELAXED
static const uint32_t ulWdgBaseAddr = 0xf409c200;
#elif ASIC_TYP==ASIC_TYP_NETX90_MPW
static const uint32_t ulWdgBaseAddr = 0xFF001640;
#elif ASIC_TYP==ASIC_TYP_NETX4000
static const uint32_t ulWdgBaseAddr = 0xf409c200;
#elif ASIC_TYP==ASIC_TYP_NETX90
static const uint32_t ulWdgBaseAddr = 0xFF001640;
#elif ASIC_TYP==ASIC_TYP_NETIOL
static const uint32_t ulWdgBaseAddr = 0x00000500;
#else
static const uint32_t ulWdgBaseAddr = 0;
// TODO maybe put a compiler warning here
#endif

NETX_CONSOLEAPP_RESULT_T resetNetX(void){
    #if (ASIC_TYP==ASIC_TYP_NETIOL || ASIC_TYP==ASIC_TYP_NETX4000 || ASIC_TYP==ASIC_TYP_NETX4000_RELAXED)
        //These require special treatment and are not implemented yet
    return NETX_CONSOLEAPP_RESULT_ERROR;
    #endif

    // TODO Enable trace
    //trace_write_restart_cookie();

    volatile uint32_t *pAddr_WdgCtrl =       (uint32_t*) ulWdgBaseAddr + 0;   /** Watchdog control register */
    volatile uint32_t *pAddr_WdgIrqTimeout = (uint32_t*) ulWdgBaseAddr + 2;   /** Watchdog Reset timeout register */
    volatile uint32_t *pAddr_WdgResTimeout = (uint32_t*) ulWdgBaseAddr + 3;   /** Watchdog IRQ timeout register */

    // Enable write access to timeout registers
    *pAddr_WdgCtrl = (*pAddr_WdgCtrl) | (1u<<31u);

	// IRQ after 0.9 seconds (Units in 100µs, not handled)
	*pAddr_WdgIrqTimeout = 0.8*10000; // Factor 10'000 so the left number is timeout in seconds
	// Reset 0.1 seconds after unhandled IRQ
	*pAddr_WdgResTimeout = 0.2*10000;

    // Trigger watchdog once to start it
    *pAddr_WdgCtrl = (*pAddr_WdgCtrl) | (1u<<28u);

    // Readback register to guarantee activating the watchdog has finished
    *pAddr_WdgCtrl = (*pAddr_WdgCtrl);

    return NETX_CONSOLEAPP_RESULT_OK;
}