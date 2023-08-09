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


#include <stddef.h>

#include "spi_flash.h"

#ifndef __SFDP_H__
#define __SFDP_H__

// TODO clean this up, do we need this here? Also get rid of testvar
// some init things?
typedef struct SFDP_Data{
	unsigned char isValid;
	unsigned int eraseOperation1;
	unsigned char eraseInstruction1;
	unsigned int eraseOperation2;
	unsigned char eraseInstruction2;
	unsigned int eraseOperation3;
	unsigned char eraseInstruction3;
	unsigned int eraseOperation4;
	unsigned char eraseInstruction4;
	SPIFLASH_ATTRIBUTES_T * pFlashDeviceInfo;
}SFDP_Data_t;

// TODO is this fixed now?
// extern SFDP_Data_t myData __attribute__ ((section (".data")));
extern SFDP_Data_t myData;
static const int testvar = 10;
// XXX remove this after testing
extern SPIFLASH_ATTRIBUTES_T tSfdpAttributes;

const SPIFLASH_ATTRIBUTES_T *sfdp_detect(FLASHER_SPI_FLASH_T *ptFlash);

#endif  /* __SFDP_H__ */

