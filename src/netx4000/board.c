/*************************************************************************** 
 *   Copyright (C) 2012 by Hilscher GmbH                                   * 
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


#include "board.h"

#include "units.h"


/*-------------------------------------------------------------------------*/


static const UNIT_TABLE_T tUnitTable_BusSPI =
{
	.sizEntries = 4,
	.atEntries =
	{
		{ 0,  "SQI0",      (void * const)HOSTADDR(SQI0) },
		{ 1,  "SQI1",      (void * const)HOSTADDR(SQI1) },
		{ 2,  "SPI",       (void * const)HOSTADDR(spi) },
		{ 3,  "SPI_XPIC3", (void * const)HOSTADDR(spi_xpic3) }
	}
};


static const UNIT_TABLE_T tUnitTable_BusParFlash =
{
	.sizEntries = 3,
	.atEntries =
	{
		{ 0,  "SRamBus",        NULL },
		{ 1,  "ExtBus",         NULL },
		{ 2,  "RAP_SRamBus",    NULL },
	}
};


static const UNIT_TABLE_T tUnitTable_BusSDIO =
{
	.sizEntries = 1,
	.atEntries =
	{
		{ 0,  "SDIO",      (void * const)HOSTADDR(SDIO) },
	}
};

const BUS_TABLE_T tBusTable =
{
	.sizEntries = 3,
	.atEntries =
	{
		{ BUS_ParFlash,  "Parallel Flash",      &tUnitTable_BusParFlash },
		{ BUS_SPI,       "Serial Flash",        &tUnitTable_BusSPI },
		{ BUS_SDIO,      "SD/MMC",              &tUnitTable_BusSDIO }
	}
};


/*-------------------------------------------------------------------------*/


NETX_CONSOLEAPP_RESULT_T board_init(void)
{
	return NETX_CONSOLEAPP_RESULT_OK;
}

