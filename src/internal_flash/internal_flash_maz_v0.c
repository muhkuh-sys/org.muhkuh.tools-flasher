/***************************************************************************
 *   Copyright (C) 2016 by Hilscher GmbH                                   *
 *   cthelen@hilscher.com                                                  *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Library General Public License as       *
 *   published by the Free Software Foundation; either version 2 of the    *
 *   License, or (at your option) any later version.                       *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU Library General Public     *
 *   License along with this program; if not, write to the                 *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/


#include "internal_flash_maz_v0.h"

#include "delay.h"
#include "flasher_header.h"
#include "netx_io_areas.h"
#include "netx90/sha384.h"
#include "uprintf.h"


/* This unit is only available on the netX90 MPW chip. */
#if ASIC_TYP==ASIC_TYP_NETX90_MPW || ASIC_TYP==ASIC_TYP_NETX90

#define IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES  0x80000
#define IFLASH_NETX90_INFO_ARRAY_SIZE_BYTES  0x2000
#define IFLASH_NETX90_INFOK_ARRAY_SIZE_BYTES 0x1000

#define IFLASH_MAZ_V0_PAGE_SIZE_BYTES 16U
#define IFLASH_MAZ_V0_PAGE_SIZE_DWORD 4U

#define IFLASH_MAZ_V0_ROW_SIZE_IN_BYTES 0x0200
#define IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES 0x1000


#define IFLASH_MODE_READ        0U
#define IFLASH_MODE_PROGRAM     1U
#define IFLASH_MODE_ERASE       2U
#define IFLASH_MODE_MASS_ERASE  3U
#define IFLASH_MODE_MANUAL      4U


#define COM_SIP_KEK_SET                 0xA11C0DED   // KEK was programmed into the SIP
#define COM_SIP_KEK_NOT_SET             0xBA1DBA1D   // KEK area is bald (no kek is set)
#define COM_SIP_SIP_PROTECTION_SET      0xAFFEDEAD   // sip protection closed monkey dead
#define COM_SIP_SIP_PROTECTION_NOT_SET  0x0A11C001   // sip protection not set all cool
#define MASK_OUT_SIP_COOKIE             0x0A0B0C0D   // used for verify command to mask out sip protection cookie

#define ROM_STARTUP_PROTECT0            0x753b428b
#define ROM_STARTUP_PROTECT1            0x622563e2
#define ROM_STARTUP_PROTECT2            0x6b311e8a
#define ROM_STARTUP_PROTECT3            0x03d7b428

typedef union IFLASH_PAGE_BUFFER_UNION
{
	unsigned char auc[IFLASH_MAZ_V0_PAGE_SIZE_BYTES];
	unsigned long aul[IFLASH_MAZ_V0_PAGE_SIZE_DWORD];
} IFLASH_PAGE_BUFFER_T;



typedef struct FLASH_BLOCK_ATTRIBUTES_STRUCT
{
	HOSTADEF(IFLASH_CFG) *ptIFlashCfgArea;
	unsigned long ulUnitOffsetInBytes;
} FLASH_BLOCK_ATTRIBUTES_T;



static NETX_CONSOLEAPP_RESULT_T check_command_area(const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr, unsigned long ulOffsetStart, unsigned long ulOffsetEnd)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	unsigned long ulFlashSize;


	/* Be pessimistic... */
	tResult = NETX_CONSOLEAPP_RESULT_ERROR;

	if( ulOffsetStart>ulOffsetEnd )
	{
		uprintf("! The start address is larger than the end address.\n");
		uprintf("! Start address: 0x%08x\n", ulOffsetStart);
		uprintf("! End address:   0x%08x\n", ulOffsetEnd);
	}
	else
	{
		/* Get the start and size of the data area. */
		ulFlashSize = ptAttr->ulSizeInBytes;

		/* Is the start and end inside the flash area? */
		if( (ulOffsetStart>=ulFlashSize) || (ulOffsetEnd>ulFlashSize) )
		{
			uprintf("! The requested area exceeds the flash size.");
			uprintf("! Requested area: [%d, %d[\n", ulOffsetStart, ulOffsetEnd);
			uprintf("! Available area: [0, %d[\n", ulFlashSize);
		}
		else
		{
			tResult = NETX_CONSOLEAPP_RESULT_OK;
		}
	}

	return tResult;
}



static NETX_CONSOLEAPP_RESULT_T iflash_get_controller(const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptFlashAttributes, unsigned long ulOffset, FLASH_BLOCK_ATTRIBUTES_T *ptAttr)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	HOSTDEF(ptIflashCfg0ComArea);
	HOSTDEF(ptIflashCfg1ComArea);
	HOSTDEF(ptIflashCfg2Area);
	HOSTADEF(IFLASH_CFG) *ptIFlashCfgArea;
	unsigned long ulUnitOffsetInBytes;
	INTERNAL_FLASH_AREA_T tArea;


	tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	ptIFlashCfgArea = NULL;
	ulUnitOffsetInBytes = 0;

	tArea = ptFlashAttributes->tArea;
	switch( tArea )
	{
	case INTERNAL_FLASH_AREA_Unknown:
		break;

	case INTERNAL_FLASH_AREA_Flash0_Main:
		if( ulOffset<IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES )
		{
			ptIFlashCfgArea = ptIflashCfg0ComArea;
			ulUnitOffsetInBytes = 0;
			tResult = NETX_CONSOLEAPP_RESULT_OK;
		}
		break;

	case INTERNAL_FLASH_AREA_Flash0_Info:
		if( ulOffset<IFLASH_NETX90_INFO_ARRAY_SIZE_BYTES )
		{
			ptIFlashCfgArea = ptIflashCfg0ComArea;
			ulUnitOffsetInBytes = 0;
			tResult = NETX_CONSOLEAPP_RESULT_OK;
		}
		break;

	case INTERNAL_FLASH_AREA_Flash0_InfoK:
		if( ulOffset<IFLASH_NETX90_INFOK_ARRAY_SIZE_BYTES )
		{
			ptIFlashCfgArea = ptIflashCfg0ComArea;
			ulUnitOffsetInBytes = 0;
			tResult = NETX_CONSOLEAPP_RESULT_OK;
		}
		break;

	case INTERNAL_FLASH_AREA_Flash1_Main:
		if( ulOffset<IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES )
		{
			ptIFlashCfgArea = ptIflashCfg1ComArea;
			ulUnitOffsetInBytes = IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES;
			tResult = NETX_CONSOLEAPP_RESULT_OK;
		}
		break;

	case INTERNAL_FLASH_AREA_Flash1_Info:
	case INTERNAL_FLASH_AREA_Flash1_InfoS:
		if( ulOffset<IFLASH_NETX90_INFO_ARRAY_SIZE_BYTES )
		{
			ptIFlashCfgArea = ptIflashCfg1ComArea;
			ulUnitOffsetInBytes = IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES;
			tResult = NETX_CONSOLEAPP_RESULT_OK;
		}
		break;

	case INTERNAL_FLASH_AREA_Flash1_InfoK:
		if( ulOffset<IFLASH_NETX90_INFOK_ARRAY_SIZE_BYTES )
		{
			ptIFlashCfgArea = ptIflashCfg1ComArea;
			ulUnitOffsetInBytes = IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES;
			tResult = NETX_CONSOLEAPP_RESULT_OK;
		}
		break;

	case INTERNAL_FLASH_AREA_Flash2_Main:
		if( ulOffset<IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES )
		{
			ptIFlashCfgArea = ptIflashCfg2Area;
			ulUnitOffsetInBytes = 2 * IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES;
			tResult = NETX_CONSOLEAPP_RESULT_OK;
		}
		break;

	case INTERNAL_FLASH_AREA_Flash2_Info:
	case INTERNAL_FLASH_AREA_Flash2_InfoS:
		if( ulOffset<IFLASH_NETX90_INFO_ARRAY_SIZE_BYTES )
		{
			ptIFlashCfgArea = ptIflashCfg2Area;
			ulUnitOffsetInBytes = 2 * IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES;
			tResult = NETX_CONSOLEAPP_RESULT_OK;
		}
		break;

	case INTERNAL_FLASH_AREA_Flash2_InfoK:
		if( ulOffset<IFLASH_NETX90_INFOK_ARRAY_SIZE_BYTES )
		{
			ptIFlashCfgArea = ptIflashCfg2Area;
			ulUnitOffsetInBytes = 2 * IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES;
			tResult = NETX_CONSOLEAPP_RESULT_OK;
		}
		break;

	case INTERNAL_FLASH_AREA_Flash01_Main:
		if( ulOffset<IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES )
		{
			ptIFlashCfgArea = ptIflashCfg0ComArea;
			ulUnitOffsetInBytes = 0;
			tResult = NETX_CONSOLEAPP_RESULT_OK;
		}
		else if( ulOffset<(2*IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES) )
		{
			ptIFlashCfgArea = ptIflashCfg1ComArea;
			/* NOTE: the offset must be 0 here so that the total sum of IFLASH0 start,
			 *       the unit offset and the program offset is in the IFLASH1 area.
			 */
			ulUnitOffsetInBytes = 0;
			tResult = NETX_CONSOLEAPP_RESULT_OK;
		}
		break;
	}

	ptAttr->ptIFlashCfgArea = ptIFlashCfgArea;
	ptAttr->ulUnitOffsetInBytes = ulUnitOffsetInBytes;

	return tResult;
} 



static void internal_flash_select_page(HOSTADEF(IFLASH_CFG) *ptIFlashCfgArea, int iMain0_Info1_InfoK2_InfoS3)
{
	unsigned long ulValue;


	/* Select the main memory or info page. */
	ulValue = 0;
	if( iMain0_Info1_InfoK2_InfoS3==1 || iMain0_Info1_InfoK2_InfoS3==3 )
	{
		ulValue = HOSTMSK(iflash_ifren_cfg_ifren);
	}
	else if( iMain0_Info1_InfoK2_InfoS3==2 )
	{
		ulValue = HOSTMSK(iflash_ifren_cfg_ifren1);
	}
	ptIFlashCfgArea->ulIflash_ifren_cfg = ulValue;

	/* Read back ifren to make sure the write has finished. */
	(void) ptIFlashCfgArea->ulIflash_ifren_cfg;
	
	/* Clear the the CPU caches. */
	__asm__("DSB");
	__asm__("ISB");
}



/* Configure all flash banks to read from the main array. */
static void internal_flash_select_mode_and_clear_caches(const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr, HOSTADEF(IFLASH_CFG) *ptIFlashCfgArea, unsigned long ulMode)
{
	/* Reset the flash. This clears the "read" caches. */
	ptIFlashCfgArea->ulIflash_reset = HOSTMSK(iflash_reset_reset);
	ptIFlashCfgArea->ulIflash_reset = 0;

	/* Select the main memory or info page. */
	internal_flash_select_page(ptIFlashCfgArea, ptAttr->iMain0_Info1_InfoK2_InfoS3);

	/* Set the TMR line to 1. */
	ptIFlashCfgArea->ulIflash_special_cfg = HOSTMSK(iflash_special_cfg_tmr);

	/* Select "read" mode. */
	ptIFlashCfgArea->ulIflash_mode_cfg = ulMode;
}


static void internal_flash_select_read_mode_and_clear_caches(const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr, HOSTADEF(IFLASH_CFG) *ptIFlashCfgArea)
{
	internal_flash_select_mode_and_clear_caches(ptAttr, ptIFlashCfgArea, IFLASH_MODE_READ);
}

/* Set all three flash banks to the main array and read mode. */
static void internal_flash_select_main_array_read(void)
{
	INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T tAttr;
	HOSTDEF(ptIflashCfg0ComArea);
	HOSTDEF(ptIflashCfg1ComArea);
	HOSTDEF(ptIflashCfg2Area);
	
	tAttr.iMain0_Info1_InfoK2_InfoS3 = 0;
	tAttr.ulSizeInBytes = IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES;
	tAttr.tArea = INTERNAL_FLASH_AREA_Flash0_Main;
	internal_flash_select_read_mode_and_clear_caches(&tAttr, ptIflashCfg0ComArea);
	
	tAttr.tArea = INTERNAL_FLASH_AREA_Flash1_Main;
	internal_flash_select_read_mode_and_clear_caches(&tAttr, ptIflashCfg1ComArea);

	tAttr.tArea = INTERNAL_FLASH_AREA_Flash2_Main;
	internal_flash_select_read_mode_and_clear_caches(&tAttr, ptIflashCfg2Area);
}


static void iflash_start_and_wait(HOSTADEF(IFLASH_CFG) *ptIFlashCfgArea)
{
	unsigned long ulValue;


	/* Start the operation. */
	ptIFlashCfgArea->ulIflash_access = HOSTMSK(iflash_access_run);

	/* Wait for the operation to finish. */
	do
	{
		ulValue  = ptIFlashCfgArea->ulIflash_access;
		ulValue &= HOSTMSK(iflash_access_run);
	} while( ulValue!=0 );
}



static void iflash_enter_ifren1_access(HOSTADEF(IFLASH_CFG) *ptIFlashCfgArea)
{
	unsigned long ulValue;


	/* Switch to manual mode. */
	ptIFlashCfgArea->ulIflash_signals_cfg = 0;
	ptIFlashCfgArea->ulIflash_ifren_cfg = 0;
	ptIFlashCfgArea->ulIflash_mode_cfg = IFLASH_MODE_MANUAL;

	/* Reset the test mode. */
	ptIFlashCfgArea->ulIflash_special_cfg = 0;
	ptIFlashCfgArea->ulIflash_special_cfg = HOSTMSK(iflash_special_cfg_tmr);
	ptIFlashCfgArea->ulIflash_special_cfg = 0;

	/* Latch the test mode code. */
	ulValue  = HOSTMSK(iflash_signals_cfg_nvstr);
	ulValue |= HOSTMSK(iflash_signals_cfg_se);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;
	ulValue  = HOSTMSK(iflash_signals_cfg_ye);
	ulValue |= HOSTMSK(iflash_signals_cfg_erase);
	ulValue |= HOSTMSK(iflash_signals_cfg_mas1);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ulValue |= HOSTMSK(iflash_signals_cfg_se);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;
	ptIFlashCfgArea->ulIflash_ifren_cfg = HOSTMSK(iflash_ifren_cfg_ifren);
	ptIFlashCfgArea->ulIflash_special_cfg = HOSTMSK(iflash_special_cfg_tmr);
	ptIFlashCfgArea->ulIflash_special_cfg = 0;
	ptIFlashCfgArea->ulIflash_ifren_cfg = 0;
	ulValue  = HOSTMSK(iflash_signals_cfg_nvstr);
	ulValue |= HOSTMSK(iflash_signals_cfg_se);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;
	ptIFlashCfgArea->ulIflash_signals_cfg = 0;
}



static void iflash_leave_ifren1_access(HOSTADEF(IFLASH_CFG) *ptIFlashCfgArea)
{
	ptIFlashCfgArea->ulIflash_special_cfg = HOSTMSK(iflash_special_cfg_tmr);
	ptIFlashCfgArea->ulIflash_mode_cfg = IFLASH_MODE_READ;
}



static void iflash_manual_erase(HOSTADEF(IFLASH_CFG) *ptIFlashCfgArea, unsigned long ulXAddr)
{
	unsigned long ulValue;


	ptIFlashCfgArea->ulIflash_xadr = ulXAddr;

	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;
	ptIFlashCfgArea->ulIflash_mode_cfg = IFLASH_MODE_MANUAL;

	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_erase);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;

	delay_us(5);

	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_erase);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;

	delay_us(20000);

	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;

	delay_us(5);

	ptIFlashCfgArea->ulIflash_signals_cfg = 0;

	delay_us(10);

	ptIFlashCfgArea->ulIflash_mode_cfg = IFLASH_MODE_READ;
}



static void iflash_manual_program(HOSTADEF(IFLASH_CFG) *ptIFlashCfgArea, unsigned long ulXAdr, unsigned long ulYAdr, const unsigned long *pulData)
{
	unsigned long ulValue;
	unsigned long ulEcc;


	ptIFlashCfgArea->ulIflash_xadr = ulXAdr;
	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;
	ptIFlashCfgArea->ulIflash_mode_cfg = IFLASH_MODE_MANUAL;

	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_prog);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;

	/* Tnvs > 5.000 ns */
	delay_us(5);

	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ulValue |= HOSTMSK(iflash_signals_cfg_prog);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;

	/* Tpgs > 10.000 ns */
	delay_us(10);

	/* Set the column address. */
	ptIFlashCfgArea->ulIflash_yadr = ulYAdr;

	/* Get the ECC for the data. */
	ptIFlashCfgArea->aulIflash_din[0] = pulData[0];
	ptIFlashCfgArea->aulIflash_din[1] = pulData[1];
	ptIFlashCfgArea->aulIflash_din[2] = pulData[2];
	ptIFlashCfgArea->aulIflash_din[3] = pulData[3];
	ulEcc = ptIFlashCfgArea->ulIflash_din4_ecc;

	/* write data[35:0] */
	ulValue  = pulData[1] & 0x0000000fU;
	ulValue |= 0xfffffff0U;
	ptIFlashCfgArea->aulIflash_din[1] = ulValue;
	ptIFlashCfgArea->aulIflash_din[2] = 0xffffffffU;
	ptIFlashCfgArea->aulIflash_din[3] = 0xffffffffU;
	ptIFlashCfgArea->aulIflash_din[4] = 0xffffffffU;

	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_ye);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ulValue |= HOSTMSK(iflash_signals_cfg_prog);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;
	/* Tprog > 20.000 ns */
	delay_us(20);
	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ulValue |= HOSTMSK(iflash_signals_cfg_prog);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;

	/* write data[71:36] */
	ptIFlashCfgArea->aulIflash_din[0] = 0xffffffffU;
	ulValue  = 0x0000000fU;
	ulValue |= pulData[1] & 0xfffffff0U;
	ptIFlashCfgArea->aulIflash_din[1] = ulValue;
	ulValue  = pulData[2] & 0x000000ffU;
	ulValue |= 0xffffff00U;
	ptIFlashCfgArea->aulIflash_din[2] = ulValue;

	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_ye);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ulValue |= HOSTMSK(iflash_signals_cfg_prog);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;
	/* Tprog > 20.000 ns */
	delay_us(20);
	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ulValue |= HOSTMSK(iflash_signals_cfg_prog);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;

	/* write data[107:72] */
	ptIFlashCfgArea->aulIflash_din[1] = 0xffffffffU;
	ulValue  = 0x000000ffU;
	ulValue |= pulData[2] & 0xffffff00U;
	ptIFlashCfgArea->aulIflash_din[2] = ulValue;
	ulValue  = pulData[3] & 0x00000fffU;
	ulValue |= 0xfffff000U;
	ptIFlashCfgArea->aulIflash_din[3] = ulValue;

	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_ye);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ulValue |= HOSTMSK(iflash_signals_cfg_prog);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;
	/* Tprog > 20.000 ns */
	delay_us(20);
	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ulValue |= HOSTMSK(iflash_signals_cfg_prog);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;

	/* write data[143:108] */
	ptIFlashCfgArea->aulIflash_din[2] = 0xffffffffU;
	ulValue  = 0x00000fffU;
	ulValue |= pulData[3] & 0xfffff000U;
	ptIFlashCfgArea->aulIflash_din[3] = ulValue;
	ptIFlashCfgArea->aulIflash_din[4] = ulEcc;

	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_ye);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ulValue |= HOSTMSK(iflash_signals_cfg_prog);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;
	/* Tprog > 20.000 ns */
	delay_us(20);
	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ulValue |= HOSTMSK(iflash_signals_cfg_prog);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;


	ulValue  = HOSTMSK(iflash_signals_cfg_xe);
	ulValue |= HOSTMSK(iflash_signals_cfg_nvstr);
	ptIFlashCfgArea->ulIflash_signals_cfg = ulValue;
	/* Tnvh > 5.000 ns */
	delay_us(5);

	ptIFlashCfgArea->ulIflash_signals_cfg = 0;
	/* Trcv > 10.000 ns */
	delay_us(10);

	ptIFlashCfgArea->ulIflash_mode_cfg = IFLASH_MODE_READ;
}



static unsigned long is_block_erased(const FLASH_BLOCK_ATTRIBUTES_T *ptAttr, unsigned long ulBlockNumber)
{
	const unsigned long *pulFlashDataArea;
	const unsigned long *pulCnt;
	const unsigned long *pulEnd;
	unsigned long ulValue;


	pulFlashDataArea = (const unsigned long*)(HOSTADDR(intflash0) + ptAttr->ulUnitOffsetInBytes);
	pulCnt = pulFlashDataArea + ((IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES * ulBlockNumber) / sizeof(unsigned long));
	pulEnd = pulCnt + (IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES / sizeof(unsigned long));
	ulValue = 0xffffffffU;
	do
	{
		ulValue &= *(pulCnt++);
	} while( pulCnt<pulEnd );

	return ulValue;
}



static NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_erase_block(const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr, unsigned long ulOffsetInBytes)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	HOSTADEF(IFLASH_CFG) *ptIFlashCfgArea;
	unsigned long ulMisalignmentInBytes;
	unsigned long ulBlockNumber;
	unsigned long ulXAddr;
	unsigned long ulYAddr;
	unsigned long ulValue;
	FLASH_BLOCK_ATTRIBUTES_T tFlashBlock;


	/* Get the pointer to the controller and the offset in the memory map. */
	tResult = iflash_get_controller(ptAttr, ulOffsetInBytes, &tFlashBlock);
	ptIFlashCfgArea = tFlashBlock.ptIFlashCfgArea;
	if( tResult==NETX_CONSOLEAPP_RESULT_OK )
	{
		/* Is the offset aligned to the page start? */
		ulMisalignmentInBytes = ulOffsetInBytes % IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES;
		if( ulMisalignmentInBytes!=0 )
		{
			uprintf("! Refuse to erase non-aligned block at offset 0x%08x. The correct offset for the aligned block would be 0x08x.\n", ulOffsetInBytes, ulOffsetInBytes - ulMisalignmentInBytes);
			tResult = NETX_CONSOLEAPP_RESULT_ERROR;
		}
		else
		{
			/* Check if the block is already erased. */
			internal_flash_select_read_mode_and_clear_caches(ptAttr, ptIFlashCfgArea);
			ulBlockNumber = ulOffsetInBytes / IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES;
			ulValue = is_block_erased(&tFlashBlock, ulBlockNumber);
			if( ulValue==0xffffffffU )
			{
				uprintf(". The erase block at offset 0x%08x is already clear. Skipping the ERASE command.\n", ulOffsetInBytes);
				tResult = NETX_CONSOLEAPP_RESULT_OK;
			}
			else
			{
				ulXAddr = ulOffsetInBytes / IFLASH_MAZ_V0_ROW_SIZE_IN_BYTES;
				ulYAddr = 0;

				/* The ifren1 page needs special handling. */
				if( ptAttr->iMain0_Info1_InfoK2_InfoS3==2 )
				{
					/* Enter the test mode. */
					iflash_enter_ifren1_access(ptIFlashCfgArea);

					/* Select the ifren1 block. */
					internal_flash_select_page(ptIFlashCfgArea, ptAttr->iMain0_Info1_InfoK2_InfoS3);

					/* Erase a block. */
					iflash_manual_erase(ptIFlashCfgArea, ulXAddr);

					/* Leave the test mode. */
					iflash_leave_ifren1_access(ptIFlashCfgArea);
				}
				else
				{
					/* Select "erase" mode and main memory or info page. */
					internal_flash_select_mode_and_clear_caches(ptAttr, ptIFlashCfgArea, IFLASH_MODE_ERASE);

					/* Set the X address. */
					ptIFlashCfgArea->ulIflash_xadr = ulXAddr;

					/* Program one column. */
					ptIFlashCfgArea->ulIflash_yadr = ulYAddr;

					/* Start erasing. */
					iflash_start_and_wait(ptIFlashCfgArea);

					/* Go back to the read mode. */
					internal_flash_select_read_mode_and_clear_caches(ptAttr, ptIFlashCfgArea);
				}

				/* Check if the block is now erased. */
				ulValue = is_block_erased(&tFlashBlock, ulBlockNumber);
				if( ulValue!=0xffffffffU )
				{
					uprintf("! The erase block at offset 0x%08x was not erased.\n", ulOffsetInBytes);
					tResult = NETX_CONSOLEAPP_RESULT_ERROR;
				}
				else
				{
					tResult = NETX_CONSOLEAPP_RESULT_OK;
				}
			}
		}
	}

	return tResult;
}



static NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_flash_page(const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr, unsigned long ulOffsetInBytes, IFLASH_PAGE_BUFFER_T *ptDataToBeFlashed)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	HOSTADEF(IFLASH_CFG) *ptIFlashCfgArea;
	unsigned long ulMisalignment;
	unsigned long ulXAddr;
	unsigned long ulYAddr;
	unsigned long ulValue;
	const unsigned char *pucFlashDataArray;
	int iCmpResult;
	unsigned int uiCnt;
	unsigned long ulDifference;
	IFLASH_PAGE_BUFFER_T tExistingDataInFlash;
	IFLASH_PAGE_BUFFER_T tDifference;
	FLASH_BLOCK_ATTRIBUTES_T tFlashBlock;


	/* Get the pointer to the controller and the offset in the memory map. */
	tResult = iflash_get_controller(ptAttr, ulOffsetInBytes, &tFlashBlock);
	ptIFlashCfgArea = tFlashBlock.ptIFlashCfgArea;
	
	if( tResult==NETX_CONSOLEAPP_RESULT_OK )
	{
		/* Is the offset aligned to the page start? */
		ulMisalignment = ulOffsetInBytes % IFLASH_MAZ_V0_PAGE_SIZE_BYTES;
		if( ulMisalignment!=0 )
		{
			uprintf("! Refuse to program non-aligned page at offset 0x%08x. The correct offset for the aligned page would be 0x08x.\n", ulOffsetInBytes, ulOffsetInBytes - ulMisalignment);
			tResult = NETX_CONSOLEAPP_RESULT_ERROR;
		}
		else
		{
			/* Get a pointer to the data array of the flash. */
			pucFlashDataArray = (const unsigned char*)(HOSTADDR(intflash0) + tFlashBlock.ulUnitOffsetInBytes);
			
			/* Select read mode and main array or info page */
			internal_flash_select_read_mode_and_clear_caches(ptAttr, ptIFlashCfgArea);

			/* Get the old contents of the flash. */
			memcpy(tExistingDataInFlash.auc, pucFlashDataArray + ulOffsetInBytes, IFLASH_MAZ_V0_PAGE_SIZE_BYTES);

			/* Compare the data to be programmed with the flash contents. */
			iCmpResult = memcmp(tExistingDataInFlash.aul, ptDataToBeFlashed->aul, IFLASH_MAZ_V0_PAGE_SIZE_BYTES);
			if( iCmpResult==0 )
			{
				/* The requested data is already in the flash. Do not program again. */
				tResult = NETX_CONSOLEAPP_RESULT_OK;
			}
			else
			{
				/* Check if the requested data will only change bits from 1 to 0.
				 *
				 * Get the difference first. "tDifference" will have
				 * all bits set to 1 which differ between the flash
				 * contents and the requested data.
				 *
				 * The flash contents must have all bits of the
				 * difference set to 1. This can be checked by
				 * masking the flash contents with the difference.
				 * The result must be the difference.
				 */

				/* Get the difference between the flash contents and
				 * the data to program.
				 */
				for(uiCnt=0; uiCnt<IFLASH_MAZ_V0_PAGE_SIZE_DWORD; ++uiCnt)
				{
					tDifference.aul[uiCnt] = tExistingDataInFlash.aul[uiCnt] ^ ptDataToBeFlashed->aul[uiCnt];
				}

				tResult = NETX_CONSOLEAPP_RESULT_OK;

				/* Check if all bits from the difference are set to 1
				 * in the flash.
				 */
				for(uiCnt=0; uiCnt<IFLASH_MAZ_V0_PAGE_SIZE_DWORD; ++uiCnt)
				{
					ulDifference = tDifference.aul[uiCnt];
					ulValue = tExistingDataInFlash.aul[uiCnt] & ulDifference;
					if( ulValue!=ulDifference )
					{
						uprintf("! Invalid program request: trying to set bits from 0 to 1 at offset 0x%08x.\n", ulOffsetInBytes + uiCnt * sizeof(unsigned long));
						uprintf("! Flash contents:  0x%08x\n", tExistingDataInFlash.aul[uiCnt]);
						uprintf("! Data to program: 0x%08x\n", ptDataToBeFlashed->aul[uiCnt]);
						tResult = NETX_CONSOLEAPP_RESULT_ERROR;
					}
				}
				if( tResult==NETX_CONSOLEAPP_RESULT_OK )
				{
					/* Convert the offset to an X and Y component. */
					ulXAddr = ulOffsetInBytes / IFLASH_MAZ_V0_ROW_SIZE_IN_BYTES;
					ulYAddr  = ulOffsetInBytes;
					ulYAddr -= (ulXAddr * IFLASH_MAZ_V0_ROW_SIZE_IN_BYTES);
					ulYAddr /= IFLASH_MAZ_V0_PAGE_SIZE_BYTES;

					/* The ifren1 page needs special handling. */
					if( ptAttr->iMain0_Info1_InfoK2_InfoS3==2 )
					{
						/* Enter the test mode. */
						iflash_enter_ifren1_access(ptIFlashCfgArea);

						/* Select the ifren1 block. */
						internal_flash_select_page(ptIFlashCfgArea, ptAttr->iMain0_Info1_InfoK2_InfoS3);

						/* Program the page. */
						iflash_manual_program(ptIFlashCfgArea, ulXAddr, ulYAddr, ptDataToBeFlashed->aul);

						/* Leave the test mode. */
						iflash_leave_ifren1_access(ptIFlashCfgArea);
					}
					else
					{
						/* Set the TMR line to 1. */
						ptIFlashCfgArea->ulIflash_special_cfg = HOSTMSK(iflash_special_cfg_tmr);

						/* Select "program" mode and main array or info block. */
						internal_flash_select_mode_and_clear_caches(ptAttr, ptIFlashCfgArea, IFLASH_MODE_PROGRAM);

						/* Set the X and Y address. */
						ptIFlashCfgArea->ulIflash_xadr = ulXAddr;
						ptIFlashCfgArea->ulIflash_yadr = ulYAddr;

						/* Set the data for the "program" operation. */
						ptIFlashCfgArea->aulIflash_din[0] = ptDataToBeFlashed->aul[0];
						ptIFlashCfgArea->aulIflash_din[1] = ptDataToBeFlashed->aul[1];
						ptIFlashCfgArea->aulIflash_din[2] = ptDataToBeFlashed->aul[2];
						ptIFlashCfgArea->aulIflash_din[3] = ptDataToBeFlashed->aul[3];

						/* Start programming. */
						iflash_start_and_wait(ptIFlashCfgArea);

						/* Go back to the read mode. */
						internal_flash_select_read_mode_and_clear_caches(ptAttr, ptIFlashCfgArea);
					}

					/* Verify the data. */
					memcpy(tExistingDataInFlash.auc, pucFlashDataArray + ulOffsetInBytes, IFLASH_MAZ_V0_PAGE_SIZE_BYTES);
					iCmpResult = memcmp(tExistingDataInFlash.aul, ptDataToBeFlashed->aul, IFLASH_MAZ_V0_PAGE_SIZE_BYTES);
					if( iCmpResult==0 )
					{
						/* The requested data was written to the flash. */
						tResult = NETX_CONSOLEAPP_RESULT_OK;
					}
					else
					{
						uprintf("! Verify error at offset 0x%08x.\n", ulOffsetInBytes);
						uprintf("Expected data:\n");
						hexdump(ptDataToBeFlashed->auc, IFLASH_MAZ_V0_PAGE_SIZE_BYTES);
						uprintf("Flash contents:\n");
						hexdump(tExistingDataInFlash.auc, IFLASH_MAZ_V0_PAGE_SIZE_BYTES);

						tResult = NETX_CONSOLEAPP_RESULT_ERROR;
					}
				}
			}
		}
	}

	return tResult;
}



typedef struct UNIT_CS_TO_ATTR_STRUCT
{
	unsigned int uiUnit;
	unsigned int uiChipSelect;
	int iMain0_Info1_InfoK2_InfoS3;
	unsigned long ulSizeInBytes;
	INTERNAL_FLASH_AREA_T tArea;
} UNIT_CS_TO_ATTR_T;

static const UNIT_CS_TO_ATTR_T atUnitCsToAttr[] =
{
	{
		.uiUnit = 0,
		.uiChipSelect = 0,
		.iMain0_Info1_InfoK2_InfoS3 = 0,
		.ulSizeInBytes = IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES,
		.tArea = INTERNAL_FLASH_AREA_Flash0_Main
	},
	{
		.uiUnit = 1,
		.uiChipSelect = 0,
		.iMain0_Info1_InfoK2_InfoS3 = 0,
		.ulSizeInBytes = IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES,
		.tArea = INTERNAL_FLASH_AREA_Flash1_Main
	},
	{
		.uiUnit = 2,
		.uiChipSelect = 0,
		.iMain0_Info1_InfoK2_InfoS3 = 0,
		.ulSizeInBytes = IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES,
		.tArea = INTERNAL_FLASH_AREA_Flash2_Main
	},
	{
		.uiUnit = 3,
		.uiChipSelect = 0,
		.iMain0_Info1_InfoK2_InfoS3 = 0,
		.ulSizeInBytes = 2 * IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES,
		.tArea = INTERNAL_FLASH_AREA_Flash01_Main
	},
	{   /* CAL SIP */
		.uiUnit = 0,
		.uiChipSelect = 1,
		.iMain0_Info1_InfoK2_InfoS3 = 1,
		.ulSizeInBytes = IFLASH_NETX90_INFO_ARRAY_SIZE_BYTES,
		.tArea = INTERNAL_FLASH_AREA_Flash0_Info
	},
	{   /* COM SIP */
		.uiUnit = 1,
		.uiChipSelect = 1,
		.iMain0_Info1_InfoK2_InfoS3 = 1,
		.ulSizeInBytes = IFLASH_NETX90_INFO_ARRAY_SIZE_BYTES,
		.tArea = INTERNAL_FLASH_AREA_Flash1_Info
	},
	{   /* APP SIP */
		.uiUnit = 2,
		.uiChipSelect = 1,
		.iMain0_Info1_InfoK2_InfoS3 = 1,
		.ulSizeInBytes = IFLASH_NETX90_INFO_ARRAY_SIZE_BYTES,
		.tArea = INTERNAL_FLASH_AREA_Flash2_Info
	},
	{   /* COM SIP with set kek option */
		.uiUnit = 1,
		.uiChipSelect = 3,
		.iMain0_Info1_InfoK2_InfoS3 = 3,
		.ulSizeInBytes = IFLASH_NETX90_INFO_ARRAY_SIZE_BYTES / 2,
		.tArea = INTERNAL_FLASH_AREA_Flash1_InfoS
	},
	{   /* APP SIP with copy temp diode calibrations */
		.uiUnit = 2,
		.uiChipSelect = 3,
		.iMain0_Info1_InfoK2_InfoS3 = 3,
		.ulSizeInBytes = IFLASH_NETX90_INFO_ARRAY_SIZE_BYTES / 2,
		.tArea = INTERNAL_FLASH_AREA_Flash2_InfoS
	},
	{
		.uiUnit = 0,
		.uiChipSelect = 2,
		.iMain0_Info1_InfoK2_InfoS3 = 2,
		.ulSizeInBytes = IFLASH_NETX90_INFOK_ARRAY_SIZE_BYTES,
		.tArea = INTERNAL_FLASH_AREA_Flash0_InfoK
	},
	{
		.uiUnit = 1,
		.uiChipSelect = 2,
		.iMain0_Info1_InfoK2_InfoS3 = 2,
		.ulSizeInBytes = IFLASH_NETX90_INFOK_ARRAY_SIZE_BYTES,
		.tArea = INTERNAL_FLASH_AREA_Flash1_InfoK
	},
	{
		.uiUnit = 2,
		.uiChipSelect = 2,
		.iMain0_Info1_InfoK2_InfoS3 = 2,
		.ulSizeInBytes = IFLASH_NETX90_INFOK_ARRAY_SIZE_BYTES,
		.tArea = INTERNAL_FLASH_AREA_Flash2_InfoK
	}
};


/* In this case, detect checks if the combination of unit and chip select is contained in the table atUnitCsToAttr. 
   Unit selects the flash bank (0/1/2), and chip select selects the main area of the bank or its info page. */
NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_detect(CMD_PARAMETER_DETECT_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	INTERNAL_FLASH_TYPE_T tFlashType;
	DEVICE_DESCRIPTION_T *ptDeviceDescription;
	INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr;
	unsigned int uiUnit;
	unsigned int uiChipSelect;
	const UNIT_CS_TO_ATTR_T *ptCnt;
	const UNIT_CS_TO_ATTR_T *ptEnd;
	const UNIT_CS_TO_ATTR_T *ptHit;


	/* Be pessimistic. */
	tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	tFlashType = INTERNAL_FLASH_TYPE_Unknown;

	/* Get a pointer to the device description and the flash attributes. */
	ptDeviceDescription = ptParameter->ptDeviceDescription;
	ptAttr = &(ptDeviceDescription->uInfo.tInternalFlashInfo.uAttributes.tMazV0);

	/* Set the default values. */
	ptAttr->iMain0_Info1_InfoK2_InfoS3 = 0;
	ptAttr->ulSizeInBytes = 0;
	ptAttr->tArea = INTERNAL_FLASH_AREA_Unknown;

	/* Get the unit. */
	uiUnit = ptParameter->uSourceParameter.tInternalFlash.uiUnit;
	/* Chip select 0 is the main memory area. Chip select 1 is the info page. */
	uiChipSelect = ptParameter->uSourceParameter.tInternalFlash.uiChipSelect;
	ptCnt = atUnitCsToAttr;
	ptEnd = ptCnt + (sizeof(atUnitCsToAttr)/sizeof(UNIT_CS_TO_ATTR_T));
	ptHit = NULL;
	while( ptCnt<ptEnd )
	{
		if( ptCnt->uiUnit==uiUnit && ptCnt->uiChipSelect==uiChipSelect )
		{
			ptHit = ptCnt;
			break;
		}
		else
		{
			++ptCnt;
		}
	}
	if( ptHit==NULL )
	{
		uprintf("! Invalid chip select %d for unit %d\n", uiChipSelect, uiUnit);
	}
	else
	{
		ptAttr->iMain0_Info1_InfoK2_InfoS3 = ptHit->iMain0_Info1_InfoK2_InfoS3;
		ptAttr->ulSizeInBytes = ptHit->ulSizeInBytes;
		ptAttr->tArea = ptHit->tArea;

		tResult = NETX_CONSOLEAPP_RESULT_OK;
		tFlashType = INTERNAL_FLASH_TYPE_MAZ_V0;
	}

	/* Set the flash type. */
	ptParameter->ptDeviceDescription->uInfo.tInternalFlashInfo.tType = tFlashType;

	return tResult;
}



static NETX_CONSOLEAPP_RESULT_T getFlashAttributesByArea(INTERNAL_FLASH_AREA_T tArea, INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const UNIT_CS_TO_ATTR_T *ptCnt;
	const UNIT_CS_TO_ATTR_T *ptEnd;


	/* Be pessimistic... */
	tResult = NETX_CONSOLEAPP_RESULT_ERROR;

	/* Search the list of known areas. */
	ptCnt = atUnitCsToAttr;
	ptEnd = ptCnt + (sizeof(atUnitCsToAttr)/sizeof(UNIT_CS_TO_ATTR_T));
	while( ptCnt<ptEnd )
	{
		if( ptCnt->tArea==tArea )
		{
			ptAttr->iMain0_Info1_InfoK2_InfoS3 = ptCnt->iMain0_Info1_InfoK2_InfoS3;
			ptAttr->ulSizeInBytes = ptCnt->ulSizeInBytes;
			ptAttr->tArea = ptCnt->tArea;

			tResult = NETX_CONSOLEAPP_RESULT_OK;
			break;
		}
		else
		{
			++ptCnt;
		}
	}

	return tResult;
}



static void infoS_update_hash(unsigned char *pucBuffer)
{
	HOSTDEF(ptHashArea);
	unsigned char *pucCnt;
	unsigned char *pucEnd;
	unsigned long sizData;


	sizData = 0x0fd0U;
	sha384_initialize();
	pucCnt = pucBuffer;
	pucEnd = pucBuffer + sizData;
	while( pucCnt<pucEnd )
	{
		sha384_update_uc(*(pucCnt++));
	}
	sha384_finalize(pucCnt, sizData);
}



static int infoS_check_hash(const unsigned char *pucBuffer)
{
	HOSTDEF(ptHashArea);
	const unsigned char *pucCnt;
	const unsigned char *pucEnd;
	unsigned long sizData;
	SHA384_HASH_SUM_T tHash;


	sizData = 0x0fd0U;
	sha384_initialize();
	pucCnt = pucBuffer;
	pucEnd = pucBuffer + sizData;
	while( pucCnt<pucEnd )
	{
		sha384_update_uc(*(pucCnt++));
	}
	sha384_finalize(tHash.auc, sizData);
	return memcmp(pucCnt, tHash.auc, sizeof(SHA384_HASH_SUM_T));
}



static void infoS_patch_IF1(unsigned char *pucBuffer)
{
	HOSTDEF(ptRandomArea);
	HOSTDEF(ptSampleAtPornStatArea);
	HOSTDEF(ptSystimeUcComArea);
	unsigned long ulValue;
	unsigned char *pucCnt;
	unsigned char *pucEnd;


	/* Get the sample at porn values and mix them with the current systime to get a good start for the random generator. */
	ulValue  = ptSampleAtPornStatArea->aulSample_at_porn_stat_in[0];
	ulValue ^= ptSampleAtPornStatArea->aulSample_at_porn_stat_in[1];
	ulValue ^= ptSystimeUcComArea->ulSystime_s;
	ulValue ^= ptSystimeUcComArea->ulSystime_ns;
	ptRandomArea->ulRandom_init = ulValue;

	/* Fill offset 0x0740 with a length of 0xc0 bytes with random data. */
	pucCnt = pucBuffer + 0x0740U;
	pucEnd = pucCnt + 0xc0U;
	while( pucCnt<pucEnd )
	{
		ulValue = ptRandomArea->ulRandom_random;
		*(pucCnt++) = (unsigned char)( ulValue         & 0x000000ffU);
		*(pucCnt++) = (unsigned char)((ulValue >>  8U) & 0x000000ffU);
		*(pucCnt++) = (unsigned char)((ulValue >> 16U) & 0x000000ffU);
		*(pucCnt++) = (unsigned char)((ulValue >> 24U) & 0x000000ffU);
	}

	infoS_update_hash(pucBuffer);
}



static void infoS_clear_IF1(unsigned char *pucBuffer, unsigned long ulMaskSipProtectionCookie)
{
	/* Fill offset 0x0740 with a length of 0xc0 bytes with 0xffU. */
	memset(pucBuffer+0x0740U, 0xffU, 0xc0U);

	if (ulMaskSipProtectionCookie == MASK_OUT_SIP_COOKIE)
	{
		/* Mask out the sip protection cookie from the data. */
	    memset(pucBuffer, 0xffU, 0x10U);
	}
	/* Update the hash. */
	infoS_update_hash(pucBuffer);
}



static NETX_CONSOLEAPP_RESULT_T infoS_patch_IF2(unsigned char *pucBuffer)
{
	INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T tAttr;
	const unsigned char *pucCalArea;
	NETX_CONSOLEAPP_RESULT_T tResult;
	FLASH_BLOCK_ATTRIBUTES_T tFlashBlock;


	/* Read the calibration data from the info page of flash 0. */
	tResult = getFlashAttributesByArea(INTERNAL_FLASH_AREA_Flash0_Info, &tAttr);
	if( tResult==NETX_CONSOLEAPP_RESULT_OK )
	{
		tResult = iflash_get_controller(&tAttr, 0, &tFlashBlock);
		if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
			internal_flash_select_read_mode_and_clear_caches(&tAttr, tFlashBlock.ptIFlashCfgArea);

			/* The calibration data are 48 bytes at offset 2192 (0x890).
			* Copy it to offset 2048 (0x800)
			*/
			pucCalArea = (const unsigned char*)(HOSTADDR(intflash0) + 0x0890U);
			memcpy(pucBuffer+0x0800U, pucCalArea, 48U);

			infoS_update_hash(pucBuffer);
		}
	}

	return tResult;
}



static void infoS_clear_IF2(unsigned char *pucBuffer)
{
	/* Clear the calibration data with 0xff. */
	memset(pucBuffer+0x0800U, 0xffU, 48U);
	/* Update the hash. */
	infoS_update_hash(pucBuffer);
}



static NETX_CONSOLEAPP_RESULT_T infoS_flash(const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr, unsigned long ulOffset, const unsigned char *pucBuffer)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	unsigned long ulOffsetCnt;
	IFLASH_PAGE_BUFFER_T tFlashBuffer;


	ulOffsetCnt = 0U;
	do
	{
		memcpy(tFlashBuffer.auc, pucBuffer, IFLASH_MAZ_V0_PAGE_SIZE_BYTES);
		tResult = internal_flash_maz_v0_flash_page(ptAttr, ulOffset+ulOffsetCnt, &tFlashBuffer);
		if( tResult!=NETX_CONSOLEAPP_RESULT_OK )
		{
			uprintf("! Failed to flash the page at offset 0x%08x.\n", ulOffset);
			break;
		}
		else
		{
			ulOffsetCnt += IFLASH_MAZ_V0_PAGE_SIZE_BYTES;
			pucBuffer += IFLASH_MAZ_V0_PAGE_SIZE_BYTES;
		}
	} while( ulOffsetCnt<IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES );

	return tResult;
}



static NETX_CONSOLEAPP_RESULT_T infoS_prepareReadData(const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr, unsigned long ulOffsetStart, unsigned long ulLength, unsigned char *pucBuffer, unsigned long *pulKekInfo, unsigned long *pulSipProtectionInfo)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	INTERNAL_FLASH_AREA_T tFlashArea;
	FLASH_BLOCK_ATTRIBUTES_T tFlashBlock;
	const unsigned char *pucFlashData;
    unsigned char ucData;
	const unsigned char *pucCnt;
	const unsigned char *pucEnd;
	const unsigned long *pulProtectionCnt;
	unsigned long ulMaskSipProtectionCookie;

	unsigned long ulData;

	ulMaskSipProtectionCookie = *pulSipProtectionInfo;


	/* The special "S" secure info pages can only be flashed as a complete page. */
	if( ulOffsetStart!=0 )
	{
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
		uprintf("! The info S pages can only be read at offset 0.\n");
	}
	else if( ulLength!=IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES )
	{
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
		uprintf("! The info S pages can only be read with 4096 bytes.\n");
	}
	else
	{
		/* Get the pointer to the controller and the offset in the memory map. */
		tResult = iflash_get_controller(ptAttr, 0U, &tFlashBlock);
		if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
			/* Select read mode and main array or info page */
			internal_flash_select_read_mode_and_clear_caches(ptAttr, tFlashBlock.ptIFlashCfgArea);

			pucFlashData = (const unsigned char*)(HOSTADDR(intflash0) + tFlashBlock.ulUnitOffsetInBytes);

			/* Check the integrity of the secure info page. */

			/* The info page contains 2 copies of the secure info page. They must be the same. */
			if( memcmp(pucFlashData, pucFlashData+IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES, IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES)!=0 )
			{
				uprintf("! Both SIPs in the info page should be the same, but they differ.\n");
				tResult = NETX_CONSOLEAPP_RESULT_ERROR;
			}
			/* The checksum must be valid.
			 * NOTE: Validate only one checksum here as both copies are the same.
			 */
			else if( infoS_check_hash(pucFlashData)!=0 )
			{
				uprintf("! The SIP has an invalid checksum.\n");
				tResult = NETX_CONSOLEAPP_RESULT_ERROR;
			}
			else
			{
				/* Copy the secure info page to the buffer. */
				memcpy(pucBuffer, pucFlashData, IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES);

				/* Clear the data. */
				tFlashArea = ptAttr->tArea;
				if( tFlashArea==INTERNAL_FLASH_AREA_Flash1_InfoS )
				{
				    uprintf("Check if KEK is set.\n");
				    /* get info if KEK is set or not */
                    ucData = 0xffU;
                    pucCnt = (const unsigned char*)pucBuffer;
                    pucCnt += 0x0740U;
                    pucEnd = pucCnt + 0xc0U;
                    do
                    {
                        ucData &= *(pucCnt++);
                    } while( pucCnt<pucEnd );
                    if( ucData!=0xffU )
                    {
                        uprintf("Found data in KEK area.\n");
                        *pulKekInfo = COM_SIP_KEK_SET;
                    }
                    else
                    {
                        uprintf("No data found in KEK area.\n");
                        *pulKekInfo = COM_SIP_KEK_NOT_SET;
                    }

				    /* get info if SIP protection cookie is set or not */
				    pulProtectionCnt = (const unsigned long*)pucBuffer;

                    uprintf("Checking if SIP protection cookie is set.\n");
                    *pulSipProtectionInfo = COM_SIP_SIP_PROTECTION_NOT_SET;

                    if (*(pulProtectionCnt+0) == ROM_STARTUP_PROTECT0 &&
                        *(pulProtectionCnt+1) == ROM_STARTUP_PROTECT1 &&
                        *(pulProtectionCnt+2) == ROM_STARTUP_PROTECT2 &&
                        *(pulProtectionCnt+3) == ROM_STARTUP_PROTECT3)
                    {
                        uprintf("Checking if SIP protection cookie is set.\n");
                        *pulSipProtectionInfo = COM_SIP_SIP_PROTECTION_SET;
                    }

				    /* mask out KEK */
					infoS_clear_IF1(pucBuffer, ulMaskSipProtectionCookie);
				}
				else
				{
				    /* mask out temp diode values */
					infoS_clear_IF2(pucBuffer);
				}
			}
		}
	}

	return tResult;
}


#if ASIC_TYP==ASIC_TYP_NETX90_MPW
static NETX_CONSOLEAPP_RESULT_T check_info_write_protection(INTERNAL_FLASH_AREA_T tFlashArea __attribute__((unused)), int iCheckWriteAccess __attribute__((unused)))
{
	return NETX_CONSOLEAPP_RESULT_OK;
}
#elif ASIC_TYP==ASIC_TYP_NETX90
static NETX_CONSOLEAPP_RESULT_T check_info_write_protection(INTERNAL_FLASH_AREA_T tFlashArea, int iCheckWriteAccess)
{
	HOSTDEF(ptIflashCfg0ComArea);
	HOSTDEF(ptIflashCfg1ComArea);
	HOSTDEF(ptIflashCfg2Area);
	NETX_CONSOLEAPP_RESULT_T tResult;
	NX90_IFLASH_CFG_AREA_T *ptIflashCfgArea;
	unsigned long ulProtectionMask;
	unsigned long ulValue;


	tResult = NETX_CONSOLEAPP_RESULT_OK;

	/* Is the selected area one of the info pages? In this case the pointer "ptIflashCfgArea" is not NULL. */
	ptIflashCfgArea = NULL;

	/* Use a switch-case here as it warns when some values of the ENUM
	 * "INTERNAL_FLASH_AREA_ENUM" are missing as long as there is no "default".
	 */
	switch( tFlashArea )
	{
	case INTERNAL_FLASH_AREA_Unknown:
	case INTERNAL_FLASH_AREA_Flash0_Main:
	case INTERNAL_FLASH_AREA_Flash1_Main:
	case INTERNAL_FLASH_AREA_Flash2_Main:
	case INTERNAL_FLASH_AREA_Flash01_Main:
		/* This is no info page. */
		break;

	case INTERNAL_FLASH_AREA_Flash0_Info:
	case INTERNAL_FLASH_AREA_Flash0_InfoK:
		/* This is one of the info pages of flash block 0. */
		ptIflashCfgArea = ptIflashCfg0ComArea;
		break;

	case INTERNAL_FLASH_AREA_Flash1_Info:
	case INTERNAL_FLASH_AREA_Flash1_InfoS:
	case INTERNAL_FLASH_AREA_Flash1_InfoK:
		/* This is one of the info pages of flash block 1. */
		ptIflashCfgArea = ptIflashCfg1ComArea;
		break;

	case INTERNAL_FLASH_AREA_Flash2_Info:
	case INTERNAL_FLASH_AREA_Flash2_InfoS:
	case INTERNAL_FLASH_AREA_Flash2_InfoK:
		/* This is one of the info pages of flash block 2. */
		ptIflashCfgArea = ptIflashCfg2Area;
		break;
	}

	if( ptIflashCfgArea!=NULL )
	{
		/* Get the protection mask. Check for a read protection, and if
		 * iCheckWriteAccess is not 0 also for write protection.
		 */
		ulProtectionMask  = MSK_NX90_iflash_protection_info_read_0_dw;
		ulProtectionMask |= MSK_NX90_iflash_protection_info_read_0_up;
		ulProtectionMask |= MSK_NX90_iflash_protection_info_read_1_dw;
		ulProtectionMask |= MSK_NX90_iflash_protection_info_read_1_up;
		if( iCheckWriteAccess!=0 )
		{
			ulProtectionMask |= MSK_NX90_iflash_protection_info_write_0;
			ulProtectionMask |= MSK_NX90_iflash_protection_info_write_1;
		}

		/* Is the info page protected? */
		ulValue  = ptIflashCfgArea->ulIflash_protection_info;
		ulValue &= ulProtectionMask;
		if( ulValue!=0U )
		{
			/* At least one of the protection bits are set. */
			tResult = NETX_CONSOLEAPP_RESULT_ERROR;
			uprintf("! The selected info page is protected.\n");
		}
	}

	return tResult;
}
#endif


NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_flash(CMD_PARAMETER_FLASH_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr;
	unsigned long ulOffsetStart;
	unsigned long ulOffsetEnd;
	const unsigned char *pucFlashDataArea; /* This is the data area of the flash. */
	const unsigned char *pucDataToBeFlashed; /* This is the data to be flashed. */
	unsigned long ulOffset;
	unsigned long ulPageStartOffset;
	unsigned long ulChunkOffset;
	unsigned long ulChunkSize;
	unsigned long ulDataSize;
	unsigned char *pucInternalWorkingBuffer;
    unsigned char *pucBufferStart;
	INTERNAL_FLASH_AREA_T tFlashArea;
	FLASH_BLOCK_ATTRIBUTES_T tFlashBlock;
	IFLASH_PAGE_BUFFER_T tFlashBuffer; /* This is the buffer for the data to flash. */


	/* Be pessimistic... */
	tResult = NETX_CONSOLEAPP_RESULT_ERROR;

	ulOffsetStart = ptParameter->ulStartAdr;
	ulOffsetEnd = ulOffsetStart + ptParameter->ulDataByteSize;

	/* Silently ignore flash requests with a size of 0 bytes. */
	if( ulOffsetStart==ulOffsetEnd )
	{
		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}
	else
	{
		/* Get a pointer to the flash attributes. */
		ptAttr = &(ptParameter->ptDeviceDescription->uInfo.tInternalFlashInfo.uAttributes.tMazV0);

		tFlashArea = ptAttr->tArea;
		tResult = check_info_write_protection(tFlashArea, 1);
		if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
		    /* check if the data's checksum is correct */
            if( tFlashArea==INTERNAL_FLASH_AREA_Flash1_InfoS || tFlashArea==INTERNAL_FLASH_AREA_Flash2_InfoS ||
             tFlashArea==INTERNAL_FLASH_AREA_Flash2_Info || tFlashArea==INTERNAL_FLASH_AREA_Flash1_Info)
            {
                pucBufferStart = ptParameter->pucData;
                if( infoS_check_hash(pucBufferStart)!=0 )
                {
                    uprintf("! The flash data has an invalid checksum.\n");
                    tResult = NETX_CONSOLEAPP_RESULT_ERROR;
                }
            }
        }
		if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
			if( tFlashArea==INTERNAL_FLASH_AREA_Flash1_InfoS || tFlashArea==INTERNAL_FLASH_AREA_Flash2_InfoS )
			{
				/* This command needs an internal working buffer. Place it at the end of the data buffer. */
				pucInternalWorkingBuffer = flasher_version.pucBuffer_End - IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES;

				/* The special "S" secure info pages can only be flashed as a complete page. */
				if( ulOffsetStart!=0 )
				{
					tResult = NETX_CONSOLEAPP_RESULT_ERROR;
					uprintf("! The info S pages can only be flashed at offset 0.\n");
				}
				else if( ptParameter->ulDataByteSize!=IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES )
				{
					tResult = NETX_CONSOLEAPP_RESULT_ERROR;
					uprintf("! The info S pages can only be flashed with 4096 bytes.\n");
				}
				/* Does the command buffer overlap with the internal working buffer? */
				else if( (ptParameter->pucData+IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES)>=pucInternalWorkingBuffer )
				{
					tResult = NETX_CONSOLEAPP_RESULT_ERROR;
					uprintf("! The selected buffer overlaps with the internal working buffer.\n");
				}
				else
				{
					tResult = iflash_get_controller(ptAttr, 0, &tFlashBlock);
					if( tResult==NETX_CONSOLEAPP_RESULT_OK )
					{
						/* Create a copy of the data in the internal working buffer. */
						memcpy(pucInternalWorkingBuffer, ptParameter->pucData, IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES);

						if( tFlashArea==INTERNAL_FLASH_AREA_Flash1_InfoS )
						{
							/* Flash the secure COM info page. */
							infoS_patch_IF1(pucInternalWorkingBuffer);
						}
						else
						{
							/* Flash the secure APP page. */
							tResult = infoS_patch_IF2(pucInternalWorkingBuffer);
						}

						if( tResult==NETX_CONSOLEAPP_RESULT_OK )
						{
							/* Select read mode and main array or info page */
							internal_flash_select_read_mode_and_clear_caches(ptAttr, tFlashBlock.ptIFlashCfgArea);

							/* Flash the page to offset 0 and offset 4096. */
							tResult = infoS_flash(ptAttr, 0, pucInternalWorkingBuffer);
							if( tResult==NETX_CONSOLEAPP_RESULT_OK )
							{
								/* Erase the 2nd block in the info page. */
								tResult = internal_flash_maz_v0_erase_block(ptAttr, IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES);
								if( tResult==NETX_CONSOLEAPP_RESULT_OK )
								{
									tResult = infoS_flash(ptAttr, IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES, pucInternalWorkingBuffer);
								}
							}

							/* Clear the internal working buffer. */
							memset(pucInternalWorkingBuffer, 0x00U, IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES);
						}
					}
				}
			}
			else
			{
				tResult = check_command_area(ptAttr, ulOffsetStart, ulOffsetEnd);
				if( tResult==NETX_CONSOLEAPP_RESULT_OK )
				{
					/* Get a pointer to the data to be flashed. */
					pucDataToBeFlashed = ptParameter->pucData;

					ulOffset = ulOffsetStart;

					/* Does the area start in the middle of a page? */
					ulChunkOffset = ulOffset % IFLASH_MAZ_V0_PAGE_SIZE_BYTES;
					if( ulChunkOffset!=0 )
					{
						/* Yes -> modify the last part of a page. */

						/* Get the pointer to the controller and the offset in the memory map. */
						tResult = iflash_get_controller(ptAttr, ulOffset, &tFlashBlock);
						if( tResult==NETX_CONSOLEAPP_RESULT_OK )
						{
							pucFlashDataArea = (const unsigned char*)(HOSTADDR(intflash0) + tFlashBlock.ulUnitOffsetInBytes);

							/* Get the start offset of the page. */
							ulPageStartOffset = ulOffset - ulChunkOffset;

							/* Get the old contents of the page. */
							memcpy(tFlashBuffer.auc, pucFlashDataArea + ulPageStartOffset, IFLASH_MAZ_V0_PAGE_SIZE_BYTES);

							/* Add the new part to the buffer. */
							ulChunkSize = IFLASH_MAZ_V0_PAGE_SIZE_BYTES - ulChunkOffset;
							ulDataSize = ulOffsetEnd - ulOffset;
							if( ulChunkSize>ulDataSize )
							{
								ulChunkSize = ulDataSize;
							}
							memcpy(tFlashBuffer.auc + ulChunkOffset, pucDataToBeFlashed, ulChunkSize);

							/* Flash the chunk. */
							tResult = internal_flash_maz_v0_flash_page(ptAttr, ulPageStartOffset, &tFlashBuffer);
							if( tResult!=NETX_CONSOLEAPP_RESULT_OK )
							{
								uprintf("! Failed to flash the page at offset 0x%08x.\n", ulPageStartOffset);
							}
							else
							{
								ulOffset += ulChunkSize;
								pucDataToBeFlashed += ulChunkSize;
							}
						}
					}

					if( tResult==NETX_CONSOLEAPP_RESULT_OK )
					{
						/* Write all complete pages. */
						while( (ulOffset+IFLASH_MAZ_V0_PAGE_SIZE_BYTES)<=ulOffsetEnd )
						{
							memcpy(tFlashBuffer.auc, pucDataToBeFlashed, IFLASH_MAZ_V0_PAGE_SIZE_BYTES);
							tResult = internal_flash_maz_v0_flash_page(ptAttr, ulOffset, &tFlashBuffer);
							if( tResult!=NETX_CONSOLEAPP_RESULT_OK )
							{
								uprintf("! Failed to flash the page at offset 0x%08x.\n", ulOffset);
								break;
							}
							else
							{
								ulOffset += IFLASH_MAZ_V0_PAGE_SIZE_BYTES;
								pucDataToBeFlashed += IFLASH_MAZ_V0_PAGE_SIZE_BYTES;
							}
						}
					}

					if( tResult==NETX_CONSOLEAPP_RESULT_OK )
					{
						/* Is a part of the last page left? */
						ulChunkSize = ulOffsetEnd - ulOffset;
						if( ulChunkSize!=0 )
						{
							/* Get the pointer to the controller and the offset in the memory map. */
							tResult = iflash_get_controller(ptAttr, ulOffset, &tFlashBlock);
							if( tResult==NETX_CONSOLEAPP_RESULT_OK )
							{
								pucFlashDataArea = (const unsigned char*)(HOSTADDR(intflash0) + tFlashBlock.ulUnitOffsetInBytes);

								/* Get the old contents of the page. */
								memcpy(tFlashBuffer.auc, pucFlashDataArea + ulOffset, IFLASH_MAZ_V0_PAGE_SIZE_BYTES);

								/* Add the new part to the buffer. */
								memcpy(tFlashBuffer.auc, pucDataToBeFlashed, ulChunkSize);

								/* Flash the chunk. */
								tResult = internal_flash_maz_v0_flash_page(ptAttr, ulOffset, &tFlashBuffer);
								if( tResult!=NETX_CONSOLEAPP_RESULT_OK )
								{
									uprintf("! Failed to flash the page at offset 0x%08x.\n", ulOffset);
								}
								else
								{
									ulOffset += ulChunkSize;
									pucDataToBeFlashed += ulChunkSize;
								}
							}
						}
					}
				}
			}
		}
	}
	
	internal_flash_select_main_array_read();
	return tResult;
}



NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_erase(CMD_PARAMETER_ERASE_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr;
	unsigned long ulOffsetStart;
	unsigned long ulOffsetEnd;
	unsigned long ulEraseBlockSize;
	unsigned long ulBlockOffset;
	unsigned long ulOffset;
	unsigned char ucData;
	const unsigned char *pucCnt;
	const unsigned char *pucEnd;
	INTERNAL_FLASH_AREA_T tFlashArea;
	FLASH_BLOCK_ATTRIBUTES_T tFlashBlock;


	ulOffsetStart = ptParameter->ulStartAdr;
	ulOffsetEnd = ptParameter->ulEndAdr;

	/* Silently ignore erase requests with a size of 0 bytes. */
	if( ulOffsetStart==ulOffsetEnd )
	{
		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}
	else
	{
		/* Get a pointer to the flash attributes. */
		ptAttr = &(ptParameter->ptDeviceDescription->uInfo.tInternalFlashInfo.uAttributes.tMazV0);

		tFlashArea = ptAttr->tArea;
		tResult = check_info_write_protection(tFlashArea, 1);
		if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
			if( tFlashArea==INTERNAL_FLASH_AREA_Flash1_InfoS || tFlashArea==INTERNAL_FLASH_AREA_Flash2_InfoS )
			{
				/* The special "S" secure info pages can only be flashed as a complete page. */
				if( ulOffsetStart!=0 )
				{
					tResult = NETX_CONSOLEAPP_RESULT_ERROR;
					uprintf("! The info S pages can only be erased at offset 0.\n");
				}
				else if( (ulOffsetEnd-ulOffsetStart)!=IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES )
				{
					tResult = NETX_CONSOLEAPP_RESULT_ERROR;
					uprintf("! The info S pages can only be erased with 4096 bytes.\n");
				}
				else
				{
					/* Erase both SIP pages. */
					ulOffsetEnd = 2U * IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES;
					tResult = NETX_CONSOLEAPP_RESULT_OK;

					/* Do not erase an existing KEK. */
					if( tFlashArea==INTERNAL_FLASH_AREA_Flash1_InfoS )
					{
						tResult = iflash_get_controller(ptAttr, 0, &tFlashBlock);
						if( tResult==NETX_CONSOLEAPP_RESULT_OK )
						{
							/* Select read mode and main array or info page */
							internal_flash_select_read_mode_and_clear_caches(ptAttr, tFlashBlock.ptIFlashCfgArea);

							/* Check the flash area [0x0740,0x07ff] for 0xff.
							 * The bitwise "and" operation over the complete area has the result of 0xff if and only if the
							 * complete area is filled with 0xff.
							 */
							ucData = 0xffU;
							pucCnt = (const unsigned char*)(HOSTADDR(intflash0) + tFlashBlock.ulUnitOffsetInBytes);
							pucCnt += 0x0740U;
							pucEnd = pucCnt + 0xc0U;
							do
							{
								ucData &= *(pucCnt++);
							} while( pucCnt<pucEnd );
							if( ucData!=0xffU )
							{
								tResult = NETX_CONSOLEAPP_RESULT_ERROR;
								uprintf("! Refusing to erase existing KEK.\n");
							}
						}
					}
				}
			}
			else
			{
				tResult = check_command_area(ptAttr, ulOffsetStart, ulOffsetEnd);
			}
		}
		if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
			/* The offset must be aligned to the erase block size. */
			ulEraseBlockSize = IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES;
			ulBlockOffset = ulOffsetStart % ulEraseBlockSize;
			if( ulBlockOffset!=0 )
			{
				uprintf("! The erase start is not aligned to the erase blocks.\n");
				uprintf("! Requested erase start: 0x%08x\n", ulOffsetStart);
				uprintf("! Erase block start:     0x%08x\n", ulOffsetStart - ulBlockOffset);
				tResult = NETX_CONSOLEAPP_RESULT_ERROR;
			}
			else
			{
				/* The end offset must be aligned to the erase block size. */
				ulBlockOffset =ulOffsetEnd % ulEraseBlockSize;
				if( ulBlockOffset!=0 )
				{
					uprintf("! The erase end is not aligned to the erase blocks.\n");
					uprintf("! Requested erase end: 0x%08x\n", ulOffsetEnd);
					uprintf("! Erase block end:     0x%08x\n", ulOffsetEnd + ulEraseBlockSize - ulBlockOffset);
					tResult = NETX_CONSOLEAPP_RESULT_ERROR;
				}
				else
				{
					ulOffset = ulOffsetStart;
					do
					{
						tResult = internal_flash_maz_v0_erase_block(ptAttr, ulOffset);
						if( tResult!=NETX_CONSOLEAPP_RESULT_OK )
						{
							break;
						}
						ulOffset += ulEraseBlockSize;
					} while( ulOffset<ulOffsetEnd );
				}
			}
		}
	}

	internal_flash_select_main_array_read();
	return tResult;
}


NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_read(CMD_PARAMETER_READ_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr;
	unsigned long ulOffsetStart;
	unsigned long ulOffsetEnd;
	unsigned long ulLength;
	const unsigned char *pucFlashArea;
	const unsigned char *pucFlashStart;
	unsigned char *pucBufferStart;
	unsigned long ulOffset;
	unsigned long ulKekInfo;
	unsigned long ulSipProtectionInfo;
	INTERNAL_FLASH_AREA_T tFlashArea;
	FLASH_BLOCK_ATTRIBUTES_T tFlashBlock;


	ulOffsetStart = ptParameter->ulStartAdr;
	ulOffsetEnd = ptParameter->ulEndAdr;
	ulLength = ulOffsetEnd - ulOffsetStart;

	/* Silently ignore read requests with a size of 0 bytes. */
	if( ulOffsetStart==ulOffsetEnd )
	{
		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}
	else
	{
		/* Get a pointer to the flash attributes. */
		ptAttr = &(ptParameter->ptDeviceDescription->uInfo.tInternalFlashInfo.uAttributes.tMazV0);

		tFlashArea = ptAttr->tArea;
		tResult = check_info_write_protection(tFlashArea, 0);
		if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
			if( tFlashArea==INTERNAL_FLASH_AREA_Flash1_InfoS || tFlashArea==INTERNAL_FLASH_AREA_Flash2_InfoS )
			{
			    /* only implemented for APP and COM SIP with chip_select 3 */
				tResult = infoS_prepareReadData(ptAttr, ulOffsetStart, ulLength, ptParameter->pucData, &ulKekInfo, &ulSipProtectionInfo);
			}
			else
			{
				tResult = check_command_area(ptAttr, ulOffsetStart, ulOffsetEnd);
				if( tResult==NETX_CONSOLEAPP_RESULT_OK )
				{
					/* Get the pointer to the controller and the offset in the memory map. */
					tResult = iflash_get_controller(ptAttr, ulOffsetStart, &tFlashBlock);
					if( tResult==NETX_CONSOLEAPP_RESULT_OK )
					{
						pucFlashArea = (const unsigned char*)(HOSTADDR(intflash0) + tFlashBlock.ulUnitOffsetInBytes);

						/* Get the start and size of the data area. */
						pucFlashStart = pucFlashArea + ulOffsetStart;

						/* Set the flash to read mode. */
						internal_flash_select_read_mode_and_clear_caches(ptAttr, tFlashBlock.ptIFlashCfgArea);

						/* If Iflash01 (unit 3) is selected and the access starts in intflash0
						 * but ends in intflash1, configure intflash1, too */
						if ((ptAttr->tArea == INTERNAL_FLASH_AREA_Flash01_Main) &&
							(ulOffsetStart < IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES) &&
							(ulOffsetEnd > IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES)
						)
						{
							tResult = iflash_get_controller(ptAttr, IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES, &tFlashBlock);
							if( tResult==NETX_CONSOLEAPP_RESULT_OK )
							{
								internal_flash_select_read_mode_and_clear_caches(ptAttr, tFlashBlock.ptIFlashCfgArea);
							}
						}
						
						if( tResult==NETX_CONSOLEAPP_RESULT_OK )
						{
							/* Copy the data block to the destination buffer.*/
							pucBufferStart = ptParameter->pucData;
		
							/* Copy the data block to the destination buffer.*/
							ulOffset = 0;
							do
							{
								pucBufferStart[ulOffset] = pucFlashStart[ulOffset];
								++ulOffset;
							} while( ulOffset<ulLength );
		
							tResult = NETX_CONSOLEAPP_RESULT_OK;
						}
					}
				}
			}
		}
	}

	internal_flash_select_main_array_read();
	return tResult;
}


#       if CFG_INCLUDE_SHA1!=0
NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_sha1(CMD_PARAMETER_CHECKSUM_T *ptParameter, SHA_CTX *ptSha1Context)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr;
	unsigned long ulOffsetStart;
	unsigned long ulOffsetEnd;
	unsigned long ulLength;
	const unsigned char *pucFlashArea;
	const unsigned char *pucFlashStart;
	unsigned char *pucInternalWorkingBuffer;
	unsigned long ulKekInfo;
	unsigned long ulSipProtectionInfo;
	INTERNAL_FLASH_AREA_T tFlashArea;
	FLASH_BLOCK_ATTRIBUTES_T tFlashBlock;


	ulOffsetStart = ptParameter->ulStartAdr;
	ulOffsetEnd = ptParameter->ulEndAdr;
	ulLength = ulOffsetEnd - ulOffsetStart;

	/* Be pessimistic. */
	tResult = NETX_CONSOLEAPP_RESULT_ERROR;

	uprintf("# Calculating checksum...\n");

	/* Silently ignore read requests with a size of 0 bytes. */
	if( ulOffsetStart==ulOffsetEnd )
	{
		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}
	else
	{
		/* Get a pointer to the flash attributes. */
		ptAttr = &(ptParameter->ptDeviceDescription->uInfo.tInternalFlashInfo.uAttributes.tMazV0);

		tFlashArea = ptAttr->tArea;
		tResult = check_info_write_protection(tFlashArea, 0);
		if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
			if( tFlashArea==INTERNAL_FLASH_AREA_Flash1_InfoS || tFlashArea==INTERNAL_FLASH_AREA_Flash2_InfoS )
			{
				/* This command needs an internal working buffer. Place it at the end of the data buffer. */
				pucInternalWorkingBuffer = flasher_version.pucBuffer_End - IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES;

				tResult = infoS_prepareReadData(ptAttr, ulOffsetStart, ulLength, pucInternalWorkingBuffer, &ulKekInfo, &ulSipProtectionInfo);
				if( tResult==NETX_CONSOLEAPP_RESULT_OK )
				{
					/* NOTE: The "hash" command initializes the netX90 hash unit for a SHA1 sum.
					 *       The function "infoS_prepareReadData" resets the hash unit and configures it for a
					 *       SHA384 sum to update the hashes of the secure info pages.
					 *       Fortunetely there was no data added to tha SHA1 sum, so it is enough to reset the
					 *       unit and start a new SHA1 sum.
					 */
					SHA1_Init(ptSha1Context);

					SHA1_Update(ptSha1Context, pucInternalWorkingBuffer, ulLength);
				}
			}
			else
			{
				tResult = check_command_area(ptAttr, ulOffsetStart, ulOffsetEnd);
				if( tResult==NETX_CONSOLEAPP_RESULT_OK )
				{
					/* Get the pointer to the controller and the offset in the memory map. */
					tResult = iflash_get_controller(ptAttr, ulOffsetStart, &tFlashBlock);
					if( tResult==NETX_CONSOLEAPP_RESULT_OK )
					{
						pucFlashArea = (const unsigned char*)(HOSTADDR(intflash0) + tFlashBlock.ulUnitOffsetInBytes);

						/* Get the start and size of the data area. */
						pucFlashStart = pucFlashArea + ulOffsetStart;

						/* Set the flash to read mode. */
						internal_flash_select_read_mode_and_clear_caches(ptAttr, tFlashBlock.ptIFlashCfgArea);

						/* If Iflash01 (unit 3) is selected and the access starts in intflash0
						 * but ends in intflash1, configure intflash1, too */
						if ((ptAttr->tArea == INTERNAL_FLASH_AREA_Flash01_Main) &&
							(ulOffsetStart < IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES) &&
							(ulOffsetEnd > IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES)
						)
						{
							tResult = iflash_get_controller(ptAttr, IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES, &tFlashBlock);
							if( tResult==NETX_CONSOLEAPP_RESULT_OK )
							{
								internal_flash_select_read_mode_and_clear_caches(ptAttr, tFlashBlock.ptIFlashCfgArea);
							}
						}

						SHA1_Update(ptSha1Context, pucFlashStart, ulLength);

						tResult = NETX_CONSOLEAPP_RESULT_OK;
					}
				}
			}
		}
	}

	uprintf(". hash done\n");

	return tResult;
}
#       endif


NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_verify(CMD_PARAMETER_VERIFY_T *ptParameter, NETX_CONSOLEAPP_PARAMETER_T *ptConsoleParams)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr;
	unsigned long ulOffsetStart;
	unsigned long ulOffsetEnd;
	const unsigned char *pucFlashStart;
	unsigned char *pucBufferStart;
	unsigned char ucFlashData;
	unsigned char ucBufferData;
	unsigned long ulOffset;
	unsigned long ulLength;
	unsigned char *pucInternalWorkingBuffer;
	unsigned long ulKekInfo;
	unsigned long ulSipProtectionInfo;
	INTERNAL_FLASH_AREA_T tFlashArea;
	FLASH_BLOCK_ATTRIBUTES_T tFlashBlock;


	ulOffsetStart = ptParameter->ulStartAdr;
	ulOffsetEnd = ptParameter->ulEndAdr;
	ulLength = ulOffsetEnd - ulOffsetStart;

	/* Silently ignore read requests with a size of 0 bytes. */
	if( ulOffsetStart==ulOffsetEnd )
	{
		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}
	else
	{
		/* Get a pointer to the flash attributes. */
		ptAttr = &(ptParameter->ptDeviceDescription->uInfo.tInternalFlashInfo.uAttributes.tMazV0);

		tFlashArea = ptAttr->tArea;
		tResult = check_info_write_protection(tFlashArea, 0);
        if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
		    /* check if the data's checksum is correct */
            if( tFlashArea==INTERNAL_FLASH_AREA_Flash1_InfoS || tFlashArea==INTERNAL_FLASH_AREA_Flash2_InfoS ||
             tFlashArea==INTERNAL_FLASH_AREA_Flash2_Info || tFlashArea==INTERNAL_FLASH_AREA_Flash1_Info)
            {
                pucBufferStart = ptParameter->pucData;
                if( infoS_check_hash(pucBufferStart)!=0 )
                {
                    uprintf("! The verify data has an invalid checksum.\n");
                    tResult = NETX_CONSOLEAPP_RESULT_ERROR;
                }
            }
        }
		if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
			if( tFlashArea==INTERNAL_FLASH_AREA_Flash1_InfoS || tFlashArea==INTERNAL_FLASH_AREA_Flash2_InfoS )
			{
                /* This command needs an internal working buffer. Place it at the end of the data buffer. */
                pucInternalWorkingBuffer = flasher_version.pucBuffer_End - IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES;
                if (tFlashArea==INTERNAL_FLASH_AREA_Flash1_InfoS)
                {
                    ulSipProtectionInfo = MASK_OUT_SIP_COOKIE;
                    /* mask out the SIP protection cookie of the verify data (it is also done to the SIP content) */
                    pucBufferStart = ptParameter->pucData;
                    memset(pucBufferStart, 0xFFU, 0x10U);
                    infoS_update_hash(pucBufferStart);
                }

                tResult = infoS_prepareReadData(ptAttr, ulOffsetStart, ulLength, pucInternalWorkingBuffer, &ulKekInfo, &ulSipProtectionInfo);
                ptParameter->ulKekInfo = ulKekInfo;
                ptParameter->ulSipProtectionInfo = ulSipProtectionInfo;

                pucFlashStart = pucInternalWorkingBuffer;


			}
			else
			{
				tResult = check_command_area(ptAttr, ulOffsetStart, ulOffsetEnd);
				if( tResult==NETX_CONSOLEAPP_RESULT_OK )
				{
					/* Get the pointer to the controller and the offset in the memory map. */
					tResult = iflash_get_controller(ptAttr, ulOffsetStart, &tFlashBlock);
					if( tResult==NETX_CONSOLEAPP_RESULT_OK )
					{
						/* Get the start of the data area. */
						pucFlashStart  = (const unsigned char*)(HOSTADDR(intflash0) + tFlashBlock.ulUnitOffsetInBytes);
						pucFlashStart += ulOffsetStart;

						/* Set the flash to read mode. */
						internal_flash_select_read_mode_and_clear_caches(ptAttr, tFlashBlock.ptIFlashCfgArea);

						/* If Iflash01 (unit 3) is selected and the access starts in intflash0
						 * but ends in intflash1, configure intflash1, too */
						if ((ptAttr->tArea == INTERNAL_FLASH_AREA_Flash01_Main) &&
							(ulOffsetStart < IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES) &&
							(ulOffsetEnd > IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES)
						)
						{
							tResult = iflash_get_controller(ptAttr, IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES, &tFlashBlock);
							if( tResult==NETX_CONSOLEAPP_RESULT_OK )
							{
								internal_flash_select_read_mode_and_clear_caches(ptAttr, tFlashBlock.ptIFlashCfgArea);
							}
						}
					}
				}
			}
		}

		if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
			/* Compare the data from the buffer with the flash contents. */
			pucBufferStart = ptParameter->pucData;

			ulOffset = 0;
			do
			{
				ucFlashData = pucFlashStart[ulOffset];
				ucBufferData = pucBufferStart[ulOffset];
				if( ucFlashData!=ucBufferData )
				{
					uprintf(". verify error at offset 0x%08x. buffer: 0x%02x, flash: 0x%02x.\n", ulOffsetStart + ulOffset, ucBufferData, ucFlashData);
					tResult = NETX_CONSOLEAPP_RESULT_ERROR;
					break;
				}

				++ulOffset;
			} while( ulOffset<ulLength );
		}

		ptConsoleParams->pvReturnMessage = (void*)tResult;
	}

	internal_flash_select_main_array_read();
	return tResult;
}



NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_is_erased(CMD_PARAMETER_ISERASED_T *ptParameter, NETX_CONSOLEAPP_PARAMETER_T *ptConsoleParams)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr;
	unsigned long ulOffsetStart;
	unsigned long ulOffsetEnd;
	const unsigned char *pucFlashArea;
	const unsigned char *pucFlashStart;
	unsigned long ulOffset;
	unsigned long ulLength;
	unsigned char ucFlashData;
	INTERNAL_FLASH_AREA_T tFlashArea;
	FLASH_BLOCK_ATTRIBUTES_T tFlashBlock;


	ulOffsetStart = ptParameter->ulStartAdr;
	ulOffsetEnd = ptParameter->ulEndAdr;
	ulLength = ulOffsetEnd - ulOffsetStart;

	/* Silently ignore requests with a size of 0 bytes. */
	if( ulOffsetStart==ulOffsetEnd )
	{
		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}
	else
	{
		/* Get a pointer to the flash attributes. */
		ptAttr = &(ptParameter->ptDeviceDescription->uInfo.tInternalFlashInfo.uAttributes.tMazV0);

		tFlashArea = ptAttr->tArea;
		tResult = check_info_write_protection(tFlashArea, 0);
		if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
			if( tFlashArea==INTERNAL_FLASH_AREA_Flash1_InfoS || tFlashArea==INTERNAL_FLASH_AREA_Flash2_InfoS )
			{
				/* The special "S" secure info pages can only be flashed as a complete page. */
				if( ulOffsetStart!=0 )
				{
					tResult = NETX_CONSOLEAPP_RESULT_ERROR;
					uprintf("! The info S pages can only be checked at offset 0.\n");
				}
				else if( ulLength!=IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES )
				{
					tResult = NETX_CONSOLEAPP_RESULT_ERROR;
					uprintf("! The info S pages can only be checked with 4096 bytes.\n");
				}
				else
				{
					/* Check both SIP pages. */
					ulLength = 2U * IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES;
					tResult = NETX_CONSOLEAPP_RESULT_OK;
				}
			}
			else
			{
				tResult = check_command_area(ptAttr, ulOffsetStart, ulOffsetEnd);
			}
		}
		if( tResult==NETX_CONSOLEAPP_RESULT_OK )
		{
			/* Get the pointer to the controller and the offset in the memory map. */
			tResult = iflash_get_controller(ptAttr, ulOffsetStart, &tFlashBlock);
			if( tResult==NETX_CONSOLEAPP_RESULT_OK )
			{
				pucFlashArea = (const unsigned char*)(HOSTADDR(intflash0) + tFlashBlock.ulUnitOffsetInBytes);

				/* Get the start and size of the data area. */
				pucFlashStart = pucFlashArea + ulOffsetStart;

				/* Set the flash to read mode. */
				internal_flash_select_read_mode_and_clear_caches(ptAttr, tFlashBlock.ptIFlashCfgArea);

				/* If Iflash01 (unit 3) is selected and the access starts in intflash0
				 * but ends in intflash1, configure intflash1, too */
				if ((ptAttr->tArea == INTERNAL_FLASH_AREA_Flash01_Main) &&
					(ulOffsetStart < IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES) &&
					(ulOffsetEnd > IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES)
				)
				{
					tResult = iflash_get_controller(ptAttr, IFLASH_NETX90_MAIN_ARRAY_SIZE_BYTES, &tFlashBlock);
					if( tResult==NETX_CONSOLEAPP_RESULT_OK )
					{
						internal_flash_select_read_mode_and_clear_caches(ptAttr, tFlashBlock.ptIFlashCfgArea);
					}
				}
					
				if( tResult==NETX_CONSOLEAPP_RESULT_OK )
				{
					/* Be optimistic... */
					tResult = NETX_CONSOLEAPP_RESULT_OK;
	
					ulOffset = 0;
					do
					{
						ucFlashData = pucFlashStart[ulOffset];
						if( ucFlashData!=0xffU )
						{
							uprintf("! Memory not erased at offset 0x%08x - expected: 0x%02x found: 0x%02x\n", ulOffsetStart + ulOffset, 0xff, ucFlashData);
							break;
						}
	
						++ulOffset;
					} while( ulOffset<ulLength );
	
					if( ucFlashData==0xff )
					{
						uprintf(". CLEAN! The area is erased.\n");
					}
					else
					{
						uprintf(". DIRTY! The area is not erased.\n");
					}
					
					ptConsoleParams->pvReturnMessage = (void*)((unsigned long)ucFlashData);
				}
			}
		}
	}

	internal_flash_select_main_array_read();
	return tResult;
}



NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_get_erase_area(CMD_PARAMETER_GETERASEAREA_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const INTERNAL_FLASH_ATTRIBUTES_MAZ_V0_T *ptAttr;
	unsigned long ulOffsetStart;
	unsigned long ulOffsetEnd;
	unsigned long ulEraseBlockSize;


	ulOffsetStart = ptParameter->ulStartAdr;
	ulOffsetEnd = ptParameter->ulEndAdr;

	/* Get a pointer to the flash attributes. */
	ptAttr = &(ptParameter->ptDeviceDescription->uInfo.tInternalFlashInfo.uAttributes.tMazV0);

	tResult = check_command_area(ptAttr, ulOffsetStart, ulOffsetEnd);
	if( tResult==NETX_CONSOLEAPP_RESULT_OK )
	{
		ulEraseBlockSize = IFLASH_MAZ_V0_ERASE_BLOCK_SIZE_IN_BYTES;
		uprintf("erase block size: 0x%08x\n", ulEraseBlockSize);
		uprintf("0x%08x - 0x%08x\n", ulOffsetStart, ulOffsetEnd);

		/* Round down the start address. */
		ulOffsetStart /= ulEraseBlockSize;
		ulOffsetStart *= ulEraseBlockSize;

		/* Round up the end address. */
		ulOffsetEnd += ulEraseBlockSize - 1;
		ulOffsetEnd /= ulEraseBlockSize;
		ulOffsetEnd *= ulEraseBlockSize;

		uprintf("0x%08x - 0x%08x\n", ulOffsetStart, ulOffsetEnd);

		ptParameter->ulStartAdr = ulOffsetStart;
		ptParameter->ulEndAdr = ulOffsetEnd;

		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}

	return tResult;
}

#else
NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_detect(CMD_PARAMETER_DETECT_T *ptParameter __attribute__((unused)))
{
	uprintf("! Internal flash MAZ V0 is not available on this platform.\n");
	return NETX_CONSOLEAPP_RESULT_ERROR;
}



NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_flash(CMD_PARAMETER_FLASH_T *ptParameter __attribute__((unused)))
{
	uprintf("! Internal flash MAZ V0 is not available on this platform.\n");
	return NETX_CONSOLEAPP_RESULT_ERROR;
}



NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_erase(CMD_PARAMETER_ERASE_T *ptParameter __attribute__((unused)))
{
	uprintf("! Internal flash MAZ V0 is not available on this platform.\n");
	return NETX_CONSOLEAPP_RESULT_ERROR;
}



NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_read(CMD_PARAMETER_READ_T *ptParameter __attribute__((unused)))
{
	uprintf("! Internal flash MAZ V0 is not available on this platform.\n");
	return NETX_CONSOLEAPP_RESULT_ERROR;
}


#       if CFG_INCLUDE_SHA1!=0
NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_sha1(CMD_PARAMETER_CHECKSUM_T *ptParameter __attribute__((unused)), SHA_CTX *ptSha1Context __attribute__((unused)))
{
	uprintf("! Internal flash MAZ V0 is not available on this platform.\n");
	return NETX_CONSOLEAPP_RESULT_ERROR;
}
#       endif


NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_verify(CMD_PARAMETER_VERIFY_T *ptParameter __attribute__((unused)), NETX_CONSOLEAPP_PARAMETER_T *ptConsoleParams __attribute__((unused)))
{
	uprintf("! Internal flash MAZ V0 is not available on this platform.\n");
	return NETX_CONSOLEAPP_RESULT_ERROR;
}



NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_is_erased(CMD_PARAMETER_ISERASED_T *ptParameter __attribute__((unused)), NETX_CONSOLEAPP_PARAMETER_T *ptConsoleParams __attribute__((unused)))
{
	uprintf("! Internal flash MAZ V0 is not available on this platform.\n");
	return NETX_CONSOLEAPP_RESULT_ERROR;
}



NETX_CONSOLEAPP_RESULT_T internal_flash_maz_v0_get_erase_area(CMD_PARAMETER_GETERASEAREA_T *ptParameter __attribute__((unused)))
{
	uprintf("! Internal flash MAZ V0 is not available on this platform.\n");
	return NETX_CONSOLEAPP_RESULT_ERROR;
}
#endif
