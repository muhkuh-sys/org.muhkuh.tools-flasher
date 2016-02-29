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


#ifndef __FLASHER_SPI_H__
#define __FLASHER_SPI_H__

#include "netx_consoleapp.h"
#include "flasher_interface.h"
#include "sha1.h"


NETX_CONSOLEAPP_RESULT_T spi_flash(CMD_PARAMETER_FLASH_T *ptParameter);
NETX_CONSOLEAPP_RESULT_T spi_erase(CMD_PARAMETER_ERASE_T *ptParameter);
NETX_CONSOLEAPP_RESULT_T spi_smart_erase(CMD_PARAMETER_SMART_ERASE_T *ptParameter);





void analyzeMap(unsigned char * cHexMap, CMD_PARAMETER_SMART_ERASE_T *ptParameter);
void performErase(unsigned int eraseMode, unsigned char eraseInstruction, unsigned long startSector, CMD_PARAMETER_SMART_ERASE_T *ptParameter);


NETX_CONSOLEAPP_RESULT_T spi_read(CMD_PARAMETER_READ_T *ptParameter);
NETX_CONSOLEAPP_RESULT_T spi_sha1(CMD_PARAMETER_CHECKSUM_T *ptParameter, SHA_CTX *ptSha1Context);
NETX_CONSOLEAPP_RESULT_T spi_verify(CMD_PARAMETER_VERIFY_T *ptParameter, NETX_CONSOLEAPP_PARAMETER_T *ptConsoleParams);

NETX_CONSOLEAPP_RESULT_T spi_detect(CMD_PARAMETER_DETECT_T *ptParameter);
NETX_CONSOLEAPP_RESULT_T spi_isErased(CMD_PARAMETER_ISERASED_T *ptParameter, NETX_CONSOLEAPP_PARAMETER_T *ptConsoleParams);
NETX_CONSOLEAPP_RESULT_T spi_getEraseArea(CMD_PARAMETER_GETERASEAREA_T *ptParameter);



void setSFDPData(unsigned char isValid, unsigned int eraseOperation1, unsigned char eraseInstruction1, unsigned int eraseOperation2, unsigned char eraseInstruction2, unsigned int eraseOperation3, unsigned char eraseInstruction3, unsigned int eraseOperation4, unsigned char eraseInstruction4, SPIFLASH_ATTRIBUTES_T * flashAttributes);

void newArray(unsigned char ** boolArray, unsigned long long int dimension);
int setValue(unsigned char * array, unsigned long long index, unsigned char val);
unsigned char getValue(unsigned char * array, unsigned long long index);
void dumpBoolArray16(unsigned char * map, unsigned int len, const char * description);
void dumpBoolArray2(unsigned char * map, unsigned int len, const char * description);

void initMemory(void);
unsigned char * getMemory(unsigned long long int sizeByte);
extern unsigned long long int totalMemory;
extern unsigned char * memStarPtr;
extern unsigned char * memCurrentPtr;
extern unsigned char * memEndPtr;
extern unsigned long long int freeMem;

#endif	/* __FLASHER_SPI_H__ */
