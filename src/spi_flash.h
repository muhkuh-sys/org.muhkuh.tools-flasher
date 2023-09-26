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

/***************************************************************************  
  File          : spi_flash.h                                                   
 ---------------------------------------------------------------------------- 
  Description:                                                                
                                                                              
      SPI Flash Functions
 ---------------------------------------------------------------------------- 
  Todo:                                                                       
                                                                              
 ---------------------------------------------------------------------------- 
  Known Problems:                                                             
                                                                              
    -                                                                         
                                                                              
 ---------------------------------------------------------------------------- 
 ***************************************************************************/ 

#ifndef __SPI_FLASH_H__
#define __SPI_FLASH_H__

#include <stdint.h>

#include "spi.h"
#include "spi_flash_types.h"

/* ------------------------------------- */

/** 
 * Represents the OpCode and area sizes of an erase instructions.
 * Size in Byte.
 * Empty/Invalid entires should have a size of 0
*/
typedef struct FLASHER_SPI_ERASE_STRUCT
{
  unsigned char OpCode;
  unsigned long Size;
} FLASHER_SPI_ERASE_T;
#define FLASHER_SPI_NR_ERASE_INSTRUCTIONS 4

/**
 * This structure holds the information needed to access the specific flash device.
 * It is filled in by spi_detect(), if a flash device was found.
 */
typedef struct FLASHER_SPI_FLASH_STRUCT
{
	SPIFLASH_ATTRIBUTES_T tAttributes;                                    /**< @brief attributes of the flash.                                                   */
	FLASHER_SPI_CFG_T tSpiDev;                                            /**< @brief SPI device and it's settings.                                              */
	FLASHER_SPI_ERASE_T tSpiErase[FLASHER_SPI_NR_ERASE_INSTRUCTIONS];     /**< @brief Sorted list of SPI erase instructions (Element 0 is smallest)              */
  unsigned short usNrEraseOperations;                                   /**< @brief Number of valid erase operations contained in the tSpiErase array          */
	unsigned long ulSectorSize;                                           /**< @brief size of one sector in bytes.                                               */
	unsigned int uiSlaveId;                                               /**< @brief SPI Slave Id of the flash.                                                 */
	unsigned int uiPageAdrShift;                                          /**< @brief bit shift for the page part of the address, 0 means no page / byte split.  */
	unsigned int uiSectorAdrShift;                                        /**< @brief bit shift for one sector, 0 means no page / byte split.                    */
} FLASHER_SPI_FLASH_T;

/*-----------------------------------*/

int Drv_SpiInitializeFlash        (const FLASHER_SPI_CONFIGURATION_T *ptSpiCfg, FLASHER_SPI_FLASH_T *ptFlash, char *pcBufferEnd, FLASHER_SPI_FLAGS_T flags);
int Drv_SpiEraseFlashPage         (const FLASHER_SPI_FLASH_T *ptFlash, unsigned long ulLinearAddress);
int Drv_SpiEraseFlashArea         (const FLASHER_SPI_FLASH_T *ptFlash, unsigned long ulLinearAddress, const unsigned char eraseOpcode);
int Drv_SpiEraseFlashSector       (const FLASHER_SPI_FLASH_T *ptFlash, unsigned long ulLinearAddress);
int Drv_SpiEraseFlashMultiSectors (const FLASHER_SPI_FLASH_T *ptFlash, unsigned long ulLinearStartAddress, unsigned long ulLinearEndAddress);
int Drv_SpiEraseFlashComplete     (const FLASHER_SPI_FLASH_T *ptFlash);
int Drv_SpiWriteFlashPages        (const FLASHER_SPI_FLASH_T *ptFlash, unsigned long ulOffs, const unsigned char *pabSrc, unsigned long ulNum);
int Drv_SpiReadFlash              (const FLASHER_SPI_FLASH_T *ptFlash, unsigned long ulLinearAddress, unsigned char       *pucData, size_t sizData);
int Drv_SpiEraseAndWritePage      (const FLASHER_SPI_FLASH_T *ptFlash, unsigned long ulLinearAddress, const unsigned char *pucData, size_t sizData);
int Drv_SpiWritePage              (const FLASHER_SPI_FLASH_T *ptFlash, unsigned long ulLinearAddress, const unsigned char *pucData, size_t sizData);

const char *spi_flash_get_adr_mode_name(SPIFLASH_ADR_T tAdrMode);

int board_get_spi_driver(const FLASHER_SPI_CONFIGURATION_T *ptSpiCfg, FLASHER_SPI_CFG_T *ptSpiDev);

/**
 * \brief Sorts an array of erase operations by size in ascending order.
 * 
 * \param ptEraseArray Pointer to array of erase operations
 * \param iNrEntries Nr of elements which will be sorted beginning at element [0]
 */
void spi_sort_erase_entries(FLASHER_SPI_ERASE_T* ptEraseArray, const unsigned int iNrEntries);

#endif
