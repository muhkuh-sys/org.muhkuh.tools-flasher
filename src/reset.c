#include "reset.h"
#include "asic_types.h"
#include "stdint.h"
#include "uprintf.h"

#include "netx_io_areas.h"

// Configure watchdog register base address for each chip type
#if   ASIC_TYP==ASIC_TYP_NETX500
//#include "netx500_regdef.h"
static const uint32_t ulWdgBaseAddr = NX500_NETX_WDG_AREA;
#elif ASIC_TYP==ASIC_TYP_NETX50
// #include "netx50_regdef.h"
static const uint32_t ulWdgBaseAddr = NX50_NETX_WDG_AREA;
#elif ASIC_TYP==ASIC_TYP_NETX10
// #include "netx10_regdef.h"
static const uint32_t ulWdgBaseAddr = NX10_NETX_WDG_AREA;
#elif ASIC_TYP==ASIC_TYP_NETX56
// #include "netx56_regdef.h"
static const uint32_t ulWdgBaseAddr = NX56_NETX_WDG_AREA;
#elif ASIC_TYP==ASIC_TYP_NETX6
// #include "netx6_regdef.h"
static const uint32_t ulWdgBaseAddr = NX6_NETX_WDG_AREA;
#error "What even is this chip type?"
#elif ASIC_TYP==ASIC_TYP_NETX4000_RELAXED
// #include "netx4000_regdef.h"
static const uint32_t ulWdgBaseAddr = NX4000_NETX_WDG_AREA;
#elif ASIC_TYP==ASIC_TYP_NETX4000
// #include "regdef_netx4000.h"
static const uint32_t ulWdgBaseAddr = NX4000_NETX_WDG_AREA;
#elif ASIC_TYP==ASIC_TYP_NETX90_MPW
// #include "platform/src/netx90_mpw/netx90_regdef.h"
static const uint32_t ulWdgBaseAddr = Addr_NX90MPW_wdg_com;
#elif ASIC_TYP==ASIC_TYP_NETX90
// #include "platform/src/netx90/netx90_regdef.h"
static const uint32_t ulWdgBaseAddr = Addr_NX90_wdg_com;
#elif ASIC_TYP==ASIC_TYP_NETIOL
// #include "netiol_regdef.h"
static const uint32_t ulWdgBaseAddr = Addr_NIOL_wdg_sys;
#else
static const uint32_t ulWdgBaseAddr = 0;
#warning "This netX type does not support resets."
#endif

NETX_CONSOLEAPP_RESULT_T resetNetX(void){
    #if (ASIC_TYP==ASIC_TYP_NETX4000 || ASIC_TYP==ASIC_TYP_NETX4000_RELAXED)
    //These require special treatment and are not implemented yet
    uprintf("Error: This hardware is not supported");
    return NETX_CONSOLEAPP_RESULT_ERROR;
    #elif (ASIC_TYP==ASIC_TYP_NETIOL)
    // This is untested and purely theoretical
    uprintf("Warning: netIOL resets are untested!");
    volatile uint32_t *pAddr_WdgSysCfg         = (uint32_t*) ulWdgBaseAddr + 0;  /** wdg_sys_cfg */
    volatile uint32_t *pAddr_wdgSysCmd         = (uint32_t*) ulWdgBaseAddr + 1;  /** wdg_sys_cmd */
    volatile uint32_t *pAddr_wdgSysPrescaleRld = (uint32_t*) ulWdgBaseAddr + 2;  /** wdg_sys_cnt_upper_rld */
    volatile uint32_t *pAddr_wdgSysCounterRld  = (uint32_t*) ulWdgBaseAddr + 3;  /** wdg_sys_cnt_lower_rld */
    if(1==0){
        // Immediately asserts a WDG reset, will not work because flasher will not return
        *pAddr_wdgSysCmd = 0xDEAD;
    }
    else{
        // Assume 100MHz system clk rate (from datasheet), set WDG for 1sec
        // Prescaler reload registers
        *pAddr_wdgSysPrescaleRld = 10000;
        // WDG counter reload registers
        *pAddr_wdgSysCounterRld = 10000;

        // Activate WDG
        *pAddr_WdgSysCfg = (0x3Fa<<2)|0x3;

        // Readback to make sure activation was executed
        *pAddr_WdgSysCfg = *pAddr_WdgSysCfg;
    }

    return NETX_CONSOLEAPP_RESULT_OK;
    #else
    if(ulWdgBaseAddr == 0){
        uprintf("Error: watchdog address invalid 0x00");
        return NETX_CONSOLEAPP_RESULT_ERROR;
    }
    // TODO Enable trace
    //trace_write_restart_cookie();

    volatile uint32_t *pAddr_WdgCtrl =       (uint32_t*) ulWdgBaseAddr + 0;   /** Watchdog control register */
    volatile uint32_t *pAddr_WdgIrqTimeout = (uint32_t*) ulWdgBaseAddr + 2;   /** Watchdog Reset timeout register */
    volatile uint32_t *pAddr_WdgResTimeout = (uint32_t*) ulWdgBaseAddr + 3;   /** Watchdog IRQ timeout register */

    // Enable write access to timeout registers
    *pAddr_WdgCtrl = (*pAddr_WdgCtrl) | (1u<<31u);

	// IRQ after 0.8 seconds (Units in 100µs, interrupt not handled)
	*pAddr_WdgIrqTimeout = 0.8*10000; // Factor 10'000 so the left number is timeout in seconds
	// Reset 0.2 seconds after unhandled IRQ
	*pAddr_WdgResTimeout = 0.2*10000;

    // Trigger watchdog once to start it
    *pAddr_WdgCtrl = (*pAddr_WdgCtrl) | (1u<<28u);

    // Readback register to guarantee activating the watchdog has finished
    *pAddr_WdgCtrl = (*pAddr_WdgCtrl);

    return NETX_CONSOLEAPP_RESULT_OK;

    #endif /* ASIC_TYP */
}