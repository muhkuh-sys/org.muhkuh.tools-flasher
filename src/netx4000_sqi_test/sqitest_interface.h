/***************************************************************************
 *   Copyright (C) 2008 by Hilscher GmbH                                   *
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

#ifndef __FLASHER_INTERFACE_H__
#define __FLASHER_INTERFACE_H__


#include <string.h>

//#include "spi_flash.h"
#include "boot_spi.h"

/*-------------------------------------*/

#define FLASHER_INTERFACE_VERSION 0x00030000


typedef enum BUS_ENUM
{
	BUS_ParFlash                    = 0,    /* Parallel flash */
	BUS_SPI                         = 1,    /* Serial flash on SPI bus. */
	BUS_IFlash                      = 2     /* Internal flash. */
} BUS_T;

typedef enum OPERATION_MODE_ENUM
{
	OPERATION_MODE_Sqitest            = 0,
} OPERATION_MODE_T;

typedef struct
{
	unsigned int uiUnit;
	unsigned int uiChipSelect;
	unsigned long ulInitialSpeedKhz;
	unsigned long ulMaximumSpeedKhz;
	unsigned int uiIdleCfg;
	unsigned int uiMode;
	unsigned char aucMmio[4];
} SPI_CONFIGURATION_T;
  
typedef struct
{
	unsigned long ulOffset;
	unsigned long ulSize;
	unsigned char *pucDest;
	unsigned char *pucCmpData;
} SQITEST_PARAM_T;

typedef struct CMD_PARAMETER_DETECT_STRUCT
{
	BUS_T tSourceTyp;
	SPI_CONFIGURATION_T tSpi;
	SQITEST_PARAM_T tSqitest_Param;
} CMD_PARAMETER_SQITEST_T;


typedef struct tFlasherInputParameter_STRUCT
{
	unsigned long ulParamVersion;
	OPERATION_MODE_T tOperationMode;
	union
	{
		CMD_PARAMETER_SQITEST_T tSqitest;
	} uParameter;
} tFlasherInputParameter;


/*-------------------------------------------------------------------------*/

#endif  /*__FLASHER_INTERFACE_H__ */

