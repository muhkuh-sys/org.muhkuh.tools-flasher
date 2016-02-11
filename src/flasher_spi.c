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

//#include <string.h>
#include <stdbool.h>

#include "flasher_spi.h"
#include "spi_flash.h"
#include "flasher_header.h"
#include "flasher_interface.h"
#include "progress_bar.h"
#include "uprintf.h"
#include "systime.h"

/*-----------------------------------*/

#define SPI_BUFFER_SIZE 8192
unsigned char pucSpiBuffer[SPI_BUFFER_SIZE];

/*-----------MY DEFINES--------------*/

#define ZERO 0xFF

/* -- Erase Timings -- */
#define ERASE_TIME_AVG_4KB_MS 66
#define ERASE_TIME_AVG_64KB_MS 533
#define ERASE_TIME_AVG_CHIP_MS 27425

#define FLASH_SIZE_KB 4096
#define FLASH_SIZE_BYTE FLASH_SIZE_KB * 1024

#define ERASE_BLOCK_MIN_KB 4
#define ERASE_BLOCK_MIN_BYTE 4096

#define ERASE_SECTOR_SIZE_KB 64
#define ERASE_SECTOR_SIZE_BYTE ERASE_SECTOR_SIZE_KB * 1024

#define CHUNKSIZE_BYTE 32 // How much data should be red in one turn --> must be a power of 2.
#define BLOCKSIZE_BYTE ERASE_BLOCK_MIN_BYTE // the as Erase_min_byte because the smallest eraseoperation defines the pagesize (for my purposes)
#define BLOCKSIZE_KB ERASE_BLOCK_MIN_KB
#define BLOCK_COUNT FLASH_SIZE_KB / BLOCKSIZE_KB
#define CHUNKS_PER_BLOCK BLOCKSIZE_BYTE / CHUNKSIZE_BYTE

#define MAP_LENGTH FLASH_SIZE_KB / ERASE_BLOCK_MIN_KB

enum eraseOperations
{
	BLOCK_ERASE_4K, SECTOR_ERASE_64K, CHIP_ERASE
};

/*-----------------------------------*/

/*-----------------------------------*/

static NETX_CONSOLEAPP_RESULT_T spi_write_with_progress(const SPI_FLASH_T *ptFlashDev, unsigned long ulFlashStartAdr, unsigned long ulDataByteLen, const unsigned char *pucDataStartAdr)
{
	const unsigned char *pucDC;
	unsigned long ulC, ulE;
	unsigned long ulSegSize;
	unsigned long ulMaxSegSize;
	unsigned long ulPageSize;
	unsigned long ulPageStartAdr;
	unsigned long ulProgressCnt;
	unsigned long ulOffset;
	int iResult;
	NETX_CONSOLEAPP_RESULT_T tResult;

	/* Expect success. */
	tResult = NETX_CONSOLEAPP_RESULT_OK;

	/* use the pagesize as segmentation */
	ulPageSize = ptFlashDev->tAttributes.ulPageSize;
	if (ulPageSize > SPI_BUFFER_SIZE)
	{
		uprintf("! pagesize exceeds reserved buffer.\n");
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}
	else
	{
		/* write the complete data */
		uprintf("# Writing...\n");

		/* loop over all data */
		ulC = ulFlashStartAdr;
		ulE = ulC + ulDataByteLen;
		pucDC = pucDataStartAdr;

		ulProgressCnt = 0;
		progress_bar_init(ulDataByteLen);

		/* start inside a page? */
		ulOffset = ulFlashStartAdr % ulPageSize;
		if (ulOffset != 0)
		{
			/* yes, start inside a page */

			/* get the startaddress of the page */
			ulPageStartAdr = ulFlashStartAdr - ulOffset;

			/* get the new max segment size for the rest of the page */
			ulMaxSegSize = ulPageSize - ulOffset;

			/* get the next segment, limit it to 'ulMaxSegSize' */
			ulSegSize = ulE - ulC;
			if (ulSegSize > ulMaxSegSize)
			{
				ulSegSize = ulMaxSegSize;
			}

			/* read the whole page */
			iResult = Drv_SpiReadFlash(ptFlashDev, ulPageStartAdr, pucSpiBuffer, ulPageSize);
			if (iResult != 0)
			{
				tResult = NETX_CONSOLEAPP_RESULT_ERROR;
			}
			else
			{
				/* modify the rest of the page */
				memcpy(pucSpiBuffer + ulOffset, pucDC, ulSegSize);

				/* write the modified buffer */
				iResult = Drv_SpiWritePage(ptFlashDev, ulPageStartAdr, pucSpiBuffer, ulPageSize);
				/*				iResult = Drv_SpiEraseAndWritePage(ptFlashDev, ulPageStartAdr, ulPageSize, pucSpiBuffer); */
				if (iResult != 0)
				{
					uprintf("! write error\n");
					tResult = NETX_CONSOLEAPP_RESULT_ERROR;
				}
				else
				{
					/* next segment */
					ulC += ulSegSize;
					pucDC += ulSegSize;

					/* inc progress */
					ulProgressCnt += ulSegSize;
					progress_bar_set_position(ulProgressCnt);
				}
			}
		}

		if (tResult == NETX_CONSOLEAPP_RESULT_OK)
		{
			/* process complete pages */
			while (ulC + ulPageSize < ulE)
			{
				/* write one page */
				iResult = Drv_SpiWritePage(ptFlashDev, ulC, pucDC, ulPageSize);
				/*				iResult = Drv_SpiEraseAndWritePage(ptFlashDev, ulC, ulPageSize, pucDC); */
				if (iResult != 0)
				{
					uprintf("! write error\n");
					tResult = NETX_CONSOLEAPP_RESULT_ERROR;
					break;
				}

				/* next segment */
				ulC += ulPageSize;
				pucDC += ulPageSize;

				/* inc progress */
				ulProgressCnt += ulPageSize;
				progress_bar_set_position(ulProgressCnt);
			}

			if (tResult == NETX_CONSOLEAPP_RESULT_OK)
			{
				/* part of a page left? */
				if (ulC < ulE)
				{
					/* yes, start inside a page -> get the next segment */
					ulSegSize = ulE - ulC;

					/* modify the beginning of the page */
					memcpy(pucSpiBuffer, pucDC, ulSegSize);
					/* read the rest of the buffer */
					iResult = Drv_SpiReadFlash(ptFlashDev, ulC + ulSegSize, pucSpiBuffer + ulSegSize, ulPageSize - ulSegSize);
					if (iResult != 0)
					{
						tResult = NETX_CONSOLEAPP_RESULT_ERROR;
					}
					else
					{
						/* write the buffer */
						iResult = Drv_SpiWritePage(ptFlashDev, ulC, pucSpiBuffer, ulPageSize);
						/*						iResult = Drv_SpiEraseAndWritePage(ptFlashDev, ulC, ulPageSize, pucSpiBuffer); */
						if (iResult != 0)
						{
							uprintf("! write error\n");
							tResult = NETX_CONSOLEAPP_RESULT_ERROR;
						}
					}
				}
			}
		}
	}

	progress_bar_finalize();

	if (tResult == NETX_CONSOLEAPP_RESULT_OK)
	{
		uprintf(". write ok\n");
	}

	return tResult;
}

static NETX_CONSOLEAPP_RESULT_T spi_verify_with_progress(const SPI_FLASH_T *ptFlashDev, unsigned long ulFlashStartAdr, unsigned long ulDataByteLen, const unsigned char *pucDataStartAdr)
{
	int iResult;
	unsigned long ulC, ulE;
	unsigned long ulSegSize, ulMaxSegSize;
	unsigned long ulProgressCnt;
	unsigned char *pucCmp0;
	const unsigned char *pucCmp1;
	const unsigned char *pucDC;
	size_t sizCmpCnt;

	uprintf("# Verifying...\n");

	ulMaxSegSize = SPI_BUFFER_SIZE;

	/* loop over all data */
	ulC = ulFlashStartAdr;
	ulE = ulC + ulDataByteLen;
	pucDC = pucDataStartAdr;

	ulProgressCnt = 0;
	progress_bar_init(ulDataByteLen);

	while (ulC < ulE)
	{
		/* get the next segment, limit it to 'ulMaxSegSize' */
		ulSegSize = ulE - ulC;
		if (ulSegSize > ulMaxSegSize)
		{
			ulSegSize = ulMaxSegSize;
		}

		/* read the segment */
		iResult = Drv_SpiReadFlash(ptFlashDev, ulC, pucSpiBuffer, ulSegSize);
		if (iResult != 0)
		{
			return NETX_CONSOLEAPP_RESULT_ERROR;
		}

		/* compare... */
		pucCmp0 = pucSpiBuffer;
		pucCmp1 = pucDC;
		sizCmpCnt = 0;
		while (sizCmpCnt < ulSegSize)
		{
			if (pucCmp0[sizCmpCnt] != pucCmp1[sizCmpCnt])
			{
				uprintf(". verify error at offset 0x%08x. buffer: 0x%02x, flash: 0x%02x.\n", ulC + ulProgressCnt + sizCmpCnt, pucCmp1[sizCmpCnt], pucCmp0[sizCmpCnt]);
				return NETX_CONSOLEAPP_RESULT_ERROR;
			}
			++sizCmpCnt;
		}

		/* next segment */
		ulC += ulSegSize;
		pucDC += ulSegSize;

		/* inc progress */
		ulProgressCnt += ulSegSize;
		progress_bar_set_position(ulProgressCnt);
	}

	progress_bar_finalize();
	uprintf(". verify ok\n");

	/* compare ok! */
	return NETX_CONSOLEAPP_RESULT_OK;
}

static NETX_CONSOLEAPP_RESULT_T spi_read_with_progress(const SPI_FLASH_T *ptFlashDev, unsigned long ulFlashStartAdr, unsigned long ulFlashEndAdr, unsigned char *pucDataAdr)
{
	unsigned long ulSegSize, ulMaxSegSize;
	unsigned long ulProgressCnt;
	int iResult;

	uprintf("# Reading...\n");

	ulMaxSegSize = SPI_BUFFER_SIZE;

	ulProgressCnt = 0;
	progress_bar_init(ulFlashEndAdr - ulFlashStartAdr);

	while (ulFlashStartAdr < ulFlashEndAdr)
	{
		/* get the next segment, limit it to 'ulMaxSegSize' */
		ulSegSize = ulFlashEndAdr - ulFlashStartAdr;
		if (ulSegSize > ulMaxSegSize)
		{
			ulSegSize = ulMaxSegSize;
		}

		/* read the segment */
		iResult = Drv_SpiReadFlash(ptFlashDev, ulFlashStartAdr, pucDataAdr, ulSegSize);
		if (iResult != 0)
		{
			return NETX_CONSOLEAPP_RESULT_ERROR;
		}

		/* next segment */
		ulFlashStartAdr += ulSegSize;
		pucDataAdr += ulSegSize;

		/* inc progress */
		ulProgressCnt += ulSegSize;
		progress_bar_set_position(ulProgressCnt);
	}

	progress_bar_finalize();
	uprintf(". read ok\n");

	/* read ok! */
	return NETX_CONSOLEAPP_RESULT_OK;
}

#if CFG_INCLUDE_SHA1!=0
static NETX_CONSOLEAPP_RESULT_T spi_sha1_with_progress(const SPI_FLASH_T *ptFlashDev, unsigned long ulFlashStartAdr, unsigned long ulFlashEndAdr, SHA_CTX *ptSha1Context)
{
	unsigned long ulSegSize, ulMaxSegSize;
	unsigned long ulProgressCnt;
	int iResult;

	uprintf("# Calculating hash...\n");

	ulMaxSegSize = SPI_BUFFER_SIZE;

	ulProgressCnt = 0;
	progress_bar_init(ulFlashEndAdr-ulFlashStartAdr);

	while( ulFlashStartAdr<ulFlashEndAdr )
	{
		/* get the next segment, limit it to 'ulMaxSegSize' */
		ulSegSize = ulFlashEndAdr - ulFlashStartAdr;
		if( ulSegSize>ulMaxSegSize )
		{
			ulSegSize = ulMaxSegSize;
		}

		/* read the segment */
		iResult = Drv_SpiReadFlash(ptFlashDev, ulFlashStartAdr, pucSpiBuffer, ulSegSize);
		if( iResult!=0 )
		{
			return NETX_CONSOLEAPP_RESULT_ERROR;
		}

		SHA1_Update(ptSha1Context, (const void*)pucSpiBuffer, ulSegSize);

		/* next segment */
		ulFlashStartAdr += ulSegSize;

		/* inc progress */
		ulProgressCnt += ulSegSize;
		progress_bar_set_position(ulProgressCnt);
	}

	progress_bar_finalize();
	uprintf(". hash done\n");

	/* read ok! */
	return NETX_CONSOLEAPP_RESULT_OK;
}
#endif

/*-------------------------*/

static NETX_CONSOLEAPP_RESULT_T spi_erase_with_progress(const SPI_FLASH_T *ptFlashDev, unsigned long ulStartAdr, unsigned long ulEndAdr)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	unsigned long ulSectorSize;
	unsigned long ulSectorOffset;
	unsigned long ulAddress;
	unsigned long ulProgressCnt;
	int iResult;

	uprintf("# Erase flash...\n");

	/* Assume success. */
	tResult = NETX_CONSOLEAPP_RESULT_OK;

	/* Get the sector size. */
	ulSectorSize = ptFlashDev->ulSectorSize;
	/* Get the offset in the first sector. */
	ulSectorOffset = ulStartAdr % ulSectorSize;
	if (ulSectorOffset != 0)
	{
		uprintf("Warning: the start address is not aligned to a sector border!\n");
		uprintf("Warning: changing the start address from 0x%08x", ulStartAdr);
		ulStartAdr -= ulSectorOffset;
		uprintf(" to 0x%08x.\n", ulStartAdr);
	}
	/* Get the offset in the last sector. */
	ulSectorOffset = ulEndAdr % ulSectorSize;
	if (ulSectorOffset != 0)
	{
		uprintf("Warning: the end address is not aligned to a sector border!\n");
		uprintf("Warning: changing the end address from 0x%08x", ulEndAdr);
		ulEndAdr += ulSectorSize - ulSectorOffset;
		uprintf(" to 0x%08x.\n", ulEndAdr);
	}

	/* Show the start and the end address of the erase area. */
	uprintf(". erase 0x%08x - 0x%08x\n", ulStartAdr, ulEndAdr);

	ulProgressCnt = 0;
	progress_bar_init(ulEndAdr - ulStartAdr);

	/* Erase the complete area. */
	ulAddress = ulStartAdr;
	while (ulAddress < ulEndAdr)
	{
		iResult = Drv_SpiEraseFlashSector(ptFlashDev, ulAddress);
		if (iResult != 0)
		{
			uprintf("! erase failed at address 0x%08x\n", ulAddress);
			tResult = NETX_CONSOLEAPP_RESULT_ERROR;
			break;
		}

		/* Move to the next segment. */
		ulAddress += ulSectorSize;

		/* Increment the progress bar. */
		ulProgressCnt += ulSectorSize;
		progress_bar_set_position(ulProgressCnt);
	}

	progress_bar_finalize();
	uprintf(". erase ok\n");

	/* Return the result. */
	return tResult;
}

/*-------------------------*/
/**
 * added smart erase_.. to follow programming structure
 */
static NETX_CONSOLEAPP_RESULT_T spi_smart_erase_with_progress(const SPI_FLASH_T *ptFlashDev, unsigned long ulStartAdr, unsigned long ulEndAdr)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	unsigned long ulSectorSize;
	unsigned long ulSectorOffset;
	unsigned long ulAddress;
	unsigned long ulProgressCnt;
	int iResult;

	uprintf("# Erase flash...\n");

	/* Assume success. */
	tResult = NETX_CONSOLEAPP_RESULT_OK;

	/* Get the sector size. */
	ulSectorSize = ptFlashDev->ulSectorSize;
	/* Get the offset in the first sector. */
	ulSectorOffset = ulStartAdr % ulSectorSize;
	if (ulSectorOffset != 0)
	{
		uprintf("Warning: the start address is not aligned to a sector border!\n");
		uprintf("Warning: changing the start address from 0x%08x", ulStartAdr);
		ulStartAdr -= ulSectorOffset;
		uprintf(" to 0x%08x.\n", ulStartAdr);
	}
	/* Get the offset in the last sector. */
	ulSectorOffset = ulEndAdr % ulSectorSize;
	if (ulSectorOffset != 0)
	{
		uprintf("Warning: the end address is not aligned to a sector border!\n");
		uprintf("Warning: changing the end address from 0x%08x", ulEndAdr);
		ulEndAdr += ulSectorSize - ulSectorOffset;
		uprintf(" to 0x%08x.\n", ulEndAdr);
	}

	/* Show the start and the end address of the erase area. */
	uprintf(". erase 0x%08x - 0x%08x\n", ulStartAdr, ulEndAdr);

	ulProgressCnt = 0;
	progress_bar_init(ulEndAdr - ulStartAdr);

	/* Erase the complete area. */
	ulAddress = ulStartAdr;
	while (ulAddress < ulEndAdr)
	{
		iResult = Drv_SpiEraseFlashSector(ptFlashDev, ulAddress);
		if (iResult != 0)
		{
			uprintf("! erase failed at address 0x%08x\n", ulAddress);
			tResult = NETX_CONSOLEAPP_RESULT_ERROR;
			break;
		}

		/* Move to the next segment. */
		ulAddress += ulSectorSize;

		/* Increment the progress bar. */
		ulProgressCnt += ulSectorSize;
		progress_bar_set_position(ulProgressCnt);
	}

	progress_bar_finalize();
	uprintf(". erase ok\n");

	/* Return the result. */
	return tResult;
}

/*-----------------------------------*/

NETX_CONSOLEAPP_RESULT_T spi_flash(CMD_PARAMETER_FLASH_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const unsigned char *pucDataStartAdr;
	unsigned long ulFlashStartAdr;
	unsigned long ulDataByteSize;
	const SPI_FLASH_T *ptFlashDescription;

	tResult = NETX_CONSOLEAPP_RESULT_OK;
	ulFlashStartAdr = ptParameter->ulStartAdr;
	ulDataByteSize = ptParameter->ulDataByteSize;
	pucDataStartAdr = ptParameter->pucData;
	ptFlashDescription = &(ptParameter->ptDeviceDescription->uInfo.tSpiInfo);

	/* write data */
	tResult = spi_write_with_progress(ptFlashDescription, ulFlashStartAdr, ulDataByteSize, pucDataStartAdr);
	if (tResult != NETX_CONSOLEAPP_RESULT_OK)
	{
		uprintf("! write error\n");
	}
	else
	{
		/* verify data */
		tResult = spi_verify_with_progress(ptFlashDescription, ulFlashStartAdr, ulDataByteSize, pucDataStartAdr);
	}

	return tResult;
}

/*-----------------------------------*/

NETX_CONSOLEAPP_RESULT_T spi_erase(CMD_PARAMETER_ERASE_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const SPI_FLASH_T *ptFlashDescription;
	unsigned long ulStartAdr;
	unsigned long ulEndAdr;

	systime_init();
	unsigned long tstart = systime_get_ms();
	uprintf("SYSTIME: %d", start);

	ptFlashDescription = &(ptParameter->ptDeviceDescription->uInfo.tSpiInfo);
	ulStartAdr = ptParameter->ulStartAdr;
	ulEndAdr = ptParameter->ulEndAdr;

	/* erase the block */
	tResult = spi_erase_with_progress(ptFlashDescription, ulStartAdr, ulEndAdr);
	if (tResult != NETX_CONSOLEAPP_RESULT_OK)
	{
		uprintf("! erase error\n");
	}

	unsigned long end = systime_get_ms();
	uprintf("\n\nThe alg took %d time. \n\n\n", end - tstart);

	return tResult;
}

/*-----------------------------------*/

/**
 * NOTE: Changed the parameter of smartErase to tRead because have to read mem again
 * TODO: own typedef CMD_PARAMETER_SMART_ERASE_T *DONE*
 * tRead contains the same data as tErase but also contains: unsigned char *pucData;
 *
 */
NETX_CONSOLEAPP_RESULT_T spi_smart_erase(CMD_PARAMETER_SMART_ERASE_T *ptParameter)
{

	initMemory();
	NETX_CONSOLEAPP_RESULT_T tResult;
	const SPI_FLASH_T *ptFlashDescription;
	unsigned long ulStartAdr;
	unsigned long ulEndAdr;
	unsigned long ulCnt;
	unsigned char *pucCnt;
	unsigned char *pucEnd;
	unsigned long ulSegSize, ulMaxSegSize;
	unsigned long ulProgressCnt;
	int iResult;
	unsigned long ulErased;

	systime_init();
	unsigned long tstart = systime_get_ms();
	uprintf("SYSTIME: %d", tstart);

	unsigned char * cHexMapByte = NULL; //newArray(MAP_LENGTH);
	newArray(&cHexMapByte, MAP_LENGTH);

	dumpBoolArray16(cHexMapByte, MAP_LENGTH, "Fresh Map");

	//bool cHexMapByte[MAP_LENGTH]; // muss int werden
	//memset(cHexMapByte, 0, MAP_LENGTH);

	/* expect success */
	tResult = NETX_CONSOLEAPP_RESULT_OK;

	ptFlashDescription = &(ptParameter->ptDeviceDescription->uInfo.tSpiInfo);
	ulStartAdr = ptParameter->ulStartAdr;
	ulEndAdr = ptParameter->ulEndAdr;

	ulErased = 0xffU;

	uprintf("# Checking data...\n");

	ulMaxSegSize = ERASE_BLOCK_MIN_BYTE; // read and analyze 4k: 1 chunk = 1 bit in matrix

	/* loop over all data */
	ulCnt = ulStartAdr;
	ulProgressCnt = 0;
	progress_bar_init(ulEndAdr - ulStartAdr);

	int counter = 0;
	while (ulCnt < ulEndAdr)
	{
		/* get the next segment, limit it to 'ulMaxSegSize' */
		ulSegSize = ulEndAdr - ulCnt;
		if (ulSegSize > ulMaxSegSize)
		{
			ulSegSize = ulMaxSegSize;
		}

		/* read the segment */
		iResult = Drv_SpiReadFlash(ptFlashDescription, ulCnt, pucSpiBuffer, ulSegSize);
		if (iResult != 0)
		{
			tResult = NETX_CONSOLEAPP_RESULT_ERROR;
			break;
		}

//		uprintf("\n\n Reading Segment: %d\n", ulCnt);
//
//		for (unsigned int i = 0; i < ulSegSize; i++) {
//			//DEBUG-print of one chung
//			uprintf("0x%02x ", pucSpiBuffer[i]);
//			if (i % 32 == 31)
//				uprintf("\n");
//		}

		ulErased = 0xffU;

		pucCnt = pucSpiBuffer;
		pucEnd = pucSpiBuffer + ulSegSize;
		while (pucCnt < pucEnd)
		{
			ulErased &= *(pucCnt++);
		}

		if (ulErased != 0xff)
		{
			//cHexMapByte[counter] = 1;
			setValue(cHexMapByte, counter, 1);
			uprintf("Seg: %d is Dirty", counter);
		}

		/* next segment */
		ulCnt += ulSegSize;
		pucCnt += ulSegSize;

		/* inc progress */
		ulProgressCnt += ulSegSize;
		progress_bar_set_position(ulProgressCnt);
		counter++;
	}

	progress_bar_finalize();

//	uprintf("\n\nHEXMap:\n");
//	for (unsigned int i = 0; i < MAP_LENGTH; i++)
//	{
//		//DEBUG-print of one chunk
//		unsigned char tmp = getValue(cHexMapByte, i);
//		uprintf("%d", tmp);
//		if (i % 32 == 31)
//			uprintf("\n%d: ", i);
//	}

	analyzeMap(cHexMapByte, ptParameter);

	unsigned long end = systime_get_ms();
	uprintf("\n\nThe alg took %d mSecs. \n\n\n", end - tstart);
	return tResult;

}

/*-----------------------------------*/

NETX_CONSOLEAPP_RESULT_T spi_read(CMD_PARAMETER_READ_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const SPI_FLASH_T *ptFlashDescription;
	unsigned long ulStartAdr;
	unsigned long ulEndAdr;

	/* Expect success. */
	tResult = NETX_CONSOLEAPP_RESULT_OK;

	ptFlashDescription = &(ptParameter->ptDeviceDescription->uInfo.tSpiInfo);
	ulStartAdr = ptParameter->ulStartAdr;
	ulEndAdr = ptParameter->ulEndAdr;

	/* read data */
	tResult = spi_read_with_progress(ptFlashDescription, ulStartAdr, ulEndAdr, ptParameter->pucData);
	if (tResult != NETX_CONSOLEAPP_RESULT_OK)
	{
		uprintf("! read error\n");
	}

	return tResult;
}

#if CFG_INCLUDE_SHA1!=0
NETX_CONSOLEAPP_RESULT_T spi_sha1(CMD_PARAMETER_CHECKSUM_T *ptParameter, SHA_CTX *ptSha1Context)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const SPI_FLASH_T *ptFlashDescription;
	unsigned long ulStartAdr;
	unsigned long ulEndAdr;

	ptFlashDescription = &(ptParameter->ptDeviceDescription->uInfo.tSpiInfo);
	ulStartAdr = ptParameter->ulStartAdr;
	ulEndAdr = ptParameter->ulEndAdr;

	/* read data */
	tResult = spi_sha1_with_progress(ptFlashDescription, ulStartAdr, ulEndAdr, ptSha1Context);
	if( tResult!=NETX_CONSOLEAPP_RESULT_OK )
	{
		uprintf("! error calculating hash\n");
	}

	return tResult;
}
#endif

/*-----------------------------------*/

NETX_CONSOLEAPP_RESULT_T spi_verify(CMD_PARAMETER_VERIFY_T *ptParameter, NETX_CONSOLEAPP_PARAMETER_T *ptConsoleParams)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const unsigned char *pucDataStartAdr;
	unsigned long ulFlashStartAdr;
	unsigned long ulFlashEndAdr;
	unsigned long ulDataByteSize;
	const SPI_FLASH_T *ptFlashDescription;

	ulFlashStartAdr = ptParameter->ulStartAdr;
	ulFlashEndAdr = ptParameter->ulEndAdr;
	ulDataByteSize = ulFlashEndAdr - ulFlashStartAdr;
	pucDataStartAdr = ptParameter->pucData;

	ptFlashDescription = &(ptParameter->ptDeviceDescription->uInfo.tSpiInfo);

	/* verify data */
	tResult = spi_verify_with_progress(ptFlashDescription, ulFlashStartAdr, ulDataByteSize, pucDataStartAdr);

	ptConsoleParams->pvReturnMessage = (void*) tResult;

	return tResult;
}

/*-----------------------------------*/

NETX_CONSOLEAPP_RESULT_T spi_detect(CMD_PARAMETER_DETECT_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	int iResult;
	DEVICE_DESCRIPTION_T *ptDeviceDescription;
	SPI_FLASH_T *ptFlashDescription;

	ptDeviceDescription = ptParameter->ptDeviceDescription;
	ptFlashDescription = &(ptDeviceDescription->uInfo.tSpiInfo);

	/* try to detect flash */
	uprintf(". Detecting SPI flash on unit %d, cs %d...\n", ptParameter->uSourceParameter.tSpi.uiUnit, ptParameter->uSourceParameter.tSpi.uiChipSelect);
	ptFlashDescription->uiSlaveId = ptParameter->uSourceParameter.tSpi.uiChipSelect;
	iResult = Drv_SpiInitializeFlash(&(ptParameter->uSourceParameter.tSpi), ptFlashDescription);
	if (iResult != 0)
	{
		/* failed to detect the SPI flash */
		uprintf("! failed to detect flash!\n");

		/* clear the result data */
		memset(ptDeviceDescription, 0, sizeof(DEVICE_DESCRIPTION_T));

		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}
	else
	{
		uprintf(". OK, found %s\n", ptFlashDescription->tAttributes.acName);

		/* set the result data */
		ptDeviceDescription->fIsValid = 1;
		ptDeviceDescription->sizThis = sizeof(DEVICE_DESCRIPTION_T);
		ptDeviceDescription->ulVersion = FLASHER_INTERFACE_VERSION;
		ptDeviceDescription->tSourceTyp = BUS_SPI;

		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}

	return tResult;
}

/*-----------------------------------*/

NETX_CONSOLEAPP_RESULT_T spi_isErased(CMD_PARAMETER_ISERASED_T *ptParameter, NETX_CONSOLEAPP_PARAMETER_T *ptConsoleParams)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const SPI_FLASH_T *ptFlashDescription;
	unsigned long ulStartAdr;
	unsigned long ulEndAdr;
	unsigned long ulCnt;
	unsigned char *pucCnt;
	unsigned char *pucEnd;
	unsigned long ulSegSize, ulMaxSegSize;
	unsigned long ulProgressCnt;
	int iResult;
	unsigned long ulErased;

	systime_init();
	unsigned long tstart = systime_get_ms();
	uprintf("SYSTIME: %d", tstart);

	/* expect success */
	tResult = NETX_CONSOLEAPP_RESULT_OK;

	ptFlashDescription = &(ptParameter->ptDeviceDescription->uInfo.tSpiInfo);
	ulStartAdr = ptParameter->ulStartAdr;
	ulEndAdr = ptParameter->ulEndAdr;

	ulErased = 0xffU;

	uprintf("# Checking data...\n");

	ulMaxSegSize = SPI_BUFFER_SIZE;

	/* loop over all data */
	ulCnt = ulStartAdr;
	ulProgressCnt = 0;
	progress_bar_init(ulEndAdr - ulStartAdr);

	while (ulCnt < ulEndAdr)
	{
		/* get the next segment, limit it to 'ulMaxSegSize' */
		ulSegSize = ulEndAdr - ulCnt;
		if (ulSegSize > ulMaxSegSize)
		{
			ulSegSize = ulMaxSegSize;
		}

		/* read the segment */
		iResult = Drv_SpiReadFlash(ptFlashDescription, ulCnt, pucSpiBuffer, ulSegSize);
		if (iResult != 0)
		{
			tResult = NETX_CONSOLEAPP_RESULT_ERROR;
			break;
		}

		pucCnt = pucSpiBuffer;
		pucEnd = pucSpiBuffer + ulSegSize;
		while (pucCnt < pucEnd)
		{
			ulErased &= *(pucCnt++);
		}

		if (ulErased != 0xff)
		{
			break;
		}

		/* next segment */
		ulCnt += ulSegSize;
		pucCnt += ulSegSize;

		/* inc progress */
		ulProgressCnt += ulSegSize;
		progress_bar_set_position(ulProgressCnt);
	}

	progress_bar_finalize();

	if (tResult == NETX_CONSOLEAPP_RESULT_OK)
	{
		if (ulErased == 0xff)
		{
			uprintf(". CLEAN! The area is erased.\n");
		}
		else
		{
			uprintf(". DIRTY! The area is not erased.\n");
		}
		ptConsoleParams->pvReturnMessage = (void*) ulErased;
	}

	unsigned long end = systime_get_ms();
	uprintf("\n\nThe isErsed took %d ms. \n\n\n", end - tstart);
	return tResult;
}

/*-----------------------------------*/

NETX_CONSOLEAPP_RESULT_T spi_getEraseArea(CMD_PARAMETER_GETERASEAREA_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	const SPI_FLASH_T *ptFlashDescription;
	unsigned long ulStartAdr;
	unsigned long ulEndAdr;
	unsigned long ulEraseBlockSize;

	ptFlashDescription = &(ptParameter->ptDeviceDescription->uInfo.tSpiInfo);
	ulStartAdr = ptParameter->ulStartAdr;
	ulEndAdr = ptParameter->ulEndAdr;

	/* NOTE: this code assumes that the serial flash has uniform erase block sizes. */
	ulEraseBlockSize = ptFlashDescription->ulSectorSize;
	uprintf("erase block size: 0x%08x\n", ulEraseBlockSize);
	uprintf("0x%08x - 0x%08x\n", ulStartAdr, ulEndAdr);

	/* round down the first address */
	ulStartAdr /= ulEraseBlockSize;
	ulStartAdr *= ulEraseBlockSize;
	/* round up the last address */
	ulEndAdr += ulEraseBlockSize - 1;
	ulEndAdr /= ulEraseBlockSize;
	ulEndAdr *= ulEraseBlockSize;

	uprintf("0x%08x - 0x%08x\n", ulStartAdr, ulEndAdr);

	ptParameter->ulStartAdr = ulStartAdr;
	ptParameter->ulEndAdr = ulEndAdr;

	tResult = NETX_CONSOLEAPP_RESULT_OK;

	/* all ok */
	return tResult;
}

/*-----------------------------------*/

/**
 * first stupid approach:
 */
void analyzeMap(unsigned char * cHexMap, CMD_PARAMETER_SMART_ERASE_T *ptParameter)
{
//	bool c64KMap[FLASH_SIZE_KB / ERASE_SECTOR_SIZE_KB]; // = malloc(FLASH_SIZE_KB / ERASE_SECTOR_SIZE_KB);
//	memset(c64KMap, 0, FLASH_SIZE_KB / ERASE_SECTOR_SIZE_KB);
	unsigned char * c64KMap = NULL;
	newArray(&c64KMap, FLASH_SIZE_KB / ERASE_SECTOR_SIZE_KB);
	dumpBoolArray16(c64KMap, FLASH_SIZE_KB / ERASE_SECTOR_SIZE_KB, "FRESH Map:");

	int iCounter = 0;
	for (int i = 0; i < FLASH_SIZE_KB / ERASE_SECTOR_SIZE_KB; i++)
	{
		/* Check the first 16 4K Blocks (= 64k Sector) if set*/
		for (int j = 0; j < 16; j++)
		{
			if (cHexMap[j + i * 16] == 1)
			{
				iCounter++;
			}
			if (iCounter > 8)
			{ // than its better to perform sec err
//				c64KMap[i] = 1;
				setValue(c64KMap, i, 1);
				for (int k = 0; k < 16; k++)
				{
//					cHexMap[k + i * 16] = 0;
					setValue(cHexMap, k + i * 16, 0);
				}

				iCounter = 0;
				break;
			}
		}
		iCounter = 0;
	}

	/* UNTESTED --> WATCH WARNING*/

	dumpBoolArray16(cHexMap, MAP_LENGTH, "4KMap");
	uprintf("\n-----------------------------\n");
	dumpBoolArray16(c64KMap, FLASH_SIZE_KB / ERASE_SECTOR_SIZE_KB, "64KMap");

//	uprintf("\n4KMap\n");
//	for (int i = 0; i < MAP_LENGTH; i++)
//	{
////		bool * tmp = cHexMap + i;
//		unsigned char tmp = getValue(cHexMap, i); //????
//		uprintf("%d ", tmp);
//		if (i % 16 == 15)
//		{
//			uprintf("\n");
//		}
//	}
//
//	uprintf("\n64KMap\n");
//	for (int i = 0; i < FLASH_SIZE_KB / ERASE_SECTOR_SIZE_KB; i++)
//	{
//		unsigned char tmp = getValue(c64KMap, i);
//		uprintf("%d ", tmp);
//		if (i % 16 == 15)
//		{
//			uprintf("\n");
//		}
//
//	}
	//perform erase
	for (int i = 0; i < MAP_LENGTH; i++)
	{
		if (/*cHexMap[i] == 1*/1 == getValue(cHexMap, i))
		{
			performErase(BLOCK_ERASE_4K, (unsigned long) i, ptParameter);
		}
	}

	for (int i = 0; i < FLASH_SIZE_KB / ERASE_SECTOR_SIZE_KB; i++)
	{
		if (/*c64KMap[i] == 1*/1 == getValue(c64KMap, i))
		{
			performErase(SECTOR_ERASE_64K, (unsigned long) i, ptParameter);
		}
	}
}

/**
 *
 */
void performErase(int EraseMode, unsigned long startSector, CMD_PARAMETER_SMART_ERASE_T *ptParameter)
{
	unsigned long errMem = 0;
	NETX_CONSOLEAPP_RESULT_T tResult;

	const SPI_FLASH_T *ptFlashDescription;
	unsigned long ulStartAdr;
	unsigned long ulEndAdr;
//	unsigned long ulCnt;
//	unsigned char *pucCnt;
//	unsigned char *pucEnd;
//	unsigned long ulSegSize, ulMaxSegSize;
//	unsigned long ulProgressCnt;
	int iResult;
//	unsigned long ulErased;

	switch (EraseMode)
	{
	case BLOCK_ERASE_4K:
		uprintf("\nok we're asked to erase 4k at block %d ", startSector);
		uprintf("this block starts at %d in real mem", errMem);
		errMem = startSector * BLOCKSIZE_BYTE;

		uprintf("Erase at: %d", errMem);

		//--->
		/* expect success */
		tResult = NETX_CONSOLEAPP_RESULT_OK;

		ptFlashDescription = &(ptParameter->ptDeviceDescription->uInfo.tSpiInfo);
		ulStartAdr = errMem; //ptParameter->ulStartAdr;
		ulEndAdr = errMem + ERASE_BLOCK_MIN_BYTE; //ptParameter->ulEndAdr;

		/* erase the block */
		unsigned long ulSectorSize;
		unsigned long ulSectorOffset;
		unsigned long ulAddress;

		/* Assume success. */
		tResult = NETX_CONSOLEAPP_RESULT_OK;

		/* Get the sector size. */
		ulSectorSize = ptFlashDescription->ulSectorSize;
		/* Get the offset in the first sector. */

		//	THIS MUST BE AVOIDED BY INPUT DATA
		ulSectorOffset = ulStartAdr % ulSectorSize;
		//	if (ulSectorOffset != 0) {
		//		uprintf(
		//				"Warning: the start address is not aligned to a sector border!\n");
		//		uprintf("Warning: changing the start address from 0x%08x", ulStartAdr);
		//		ulStartAdr -= ulSectorOffset;
		//		uprintf(" to 0x%08x.\n", ulStartAdr);
		//	}
		//	/* Get the offset in the last sector. */
		ulSectorOffset = ulEndAdr % ulSectorSize;
		//	if (ulSectorOffset != 0) {
		//		uprintf(
		//				"Warning: the end address is not aligned to a sector border!\n");
		//		uprintf("Warning: changing the end address from 0x%08x", ulEndAdr);
		//		ulEndAdr += ulSectorSize - ulSectorOffset;
		//		uprintf(" to 0x%08x.\n", ulEndAdr);
		//	}

		/* Show the start and the end address of the erase area. */
		uprintf(". erase 0x%08x - 0x%08x\n", ulStartAdr, ulEndAdr);

		/* Erase the complete area. Should be one iteration if 4k erase is supported. */
		ulAddress = ulStartAdr;
		while (ulAddress < ulEndAdr)
		{
			iResult = Drv_SpiEraseFlashSector(ptFlashDescription, ulAddress);
			if (iResult != 0)
			{
				uprintf("! erase failed at address 0x%08x\n", ulAddress);
				tResult = NETX_CONSOLEAPP_RESULT_ERROR;
				break;
			}

			/* Move to the next segment. */
			ulAddress += ulSectorSize;
		}

		if (tResult != NETX_CONSOLEAPP_RESULT_OK)
		{
			uprintf("! erase error\n");
		}

		//<---
		break;
	case SECTOR_ERASE_64K:

		uprintf("\nok we're asked to erase 64k at block %d ", startSector);
		uprintf("this block starts at %d in real mem", errMem);
		errMem = startSector * ERASE_SECTOR_SIZE_BYTE;
		uprintf("Erase at: %d\n\n!!!NOTE THAT THIS IS NOT WORKING CORRECTLY AT THE MOMENT!!!", errMem);

		//--->
		/* expect success */
		tResult = NETX_CONSOLEAPP_RESULT_OK;

		ptFlashDescription = &(ptParameter->ptDeviceDescription->uInfo.tSpiInfo);
		ulStartAdr = errMem; //ptParameter->ulStartAdr;
		ulEndAdr = errMem + ERASE_SECTOR_SIZE_BYTE; //ptParameter->ulEndAdr;

		/* erase the block */
//		unsigned long ulSectorSize;
//		unsigned long ulSectorOffset;
//		unsigned long ulAddress;
		/* Assume success. */
		tResult = NETX_CONSOLEAPP_RESULT_OK;

		/* Get the sector size. */
		ulSectorSize = ptFlashDescription->ulSectorSize;
		/* Get the offset in the first sector. */

		//	THIS MUST BE AVOIDED BY INPUT DATA
		ulSectorOffset = ulStartAdr % ulSectorSize;
		//	if (ulSectorOffset != 0) {
		//		uprintf(
		//				"Warning: the start address is not aligned to a sector border!\n");
		//		uprintf("Warning: changing the start address from 0x%08x", ulStartAdr);
		//		ulStartAdr -= ulSectorOffset;
		//		uprintf(" to 0x%08x.\n", ulStartAdr);
		//	}
		//	/* Get the offset in the last sector. */
		ulSectorOffset = ulEndAdr % ulSectorSize;
		//	if (ulSectorOffset != 0) {
		//		uprintf(
		//				"Warning: the end address is not aligned to a sector border!\n");
		//		uprintf("Warning: changing the end address from 0x%08x", ulEndAdr);
		//		ulEndAdr += ulSectorSize - ulSectorOffset;
		//		uprintf(" to 0x%08x.\n", ulEndAdr);
		//	}

		/* Show the start and the end address of the erase area. */
		uprintf(". erase 0x%08x - 0x%08x\n", ulStartAdr, ulEndAdr);

		/* Erase the complete area. Should be 1 iterations*/
		ulAddress = ulStartAdr;
		while (ulAddress < ulEndAdr)
		{

			/**
			 * Here we have to change to Drv_SpiEraseFlashPage which is declared but not implemented resp. defined out
			 */
			//iResult = Drv_SpiEraseFlashPage(ptFlashDescription, ulAddress);
			iResult = 1;
			if (iResult != 0)
			{
				uprintf("! erase failed at address 0x%08x\n", ulAddress);
				tResult = NETX_CONSOLEAPP_RESULT_ERROR;
				break;
			}

			/* Move to the next segment. */
			ulAddress += ulSectorSize;
		}

		/***************/
		if (tResult != NETX_CONSOLEAPP_RESULT_OK)
		{
			uprintf("! erase error\n");
		}

		//<---

		break;
//	case CHIP_ERASE:
//		uprintf("\nok we're asked to erase the whole chip");
//		uprintf("Erase at: %d", errMem);
//
//		for (int i = 0; i < FLASH_SIZE_BYTE; i++) {
////			printf("\nStep: %d: Erasing: %d\n", i, errMem + i);
////			cDummyMapByte[i] = ZERO;
//		}
//		break;
	default:
		break;
	}
}

void initMemory()
{
	totalMemory = flasher_version.pucBuffer_End - flasher_version.pucBuffer_Data;
	memStarPtr = flasher_version.pucBuffer_Data;
	memCurrentPtr = memStarPtr;
	freeMem = totalMemory;
	memEndPtr = flasher_version.pucBuffer_End;
	uprintf("---\n- DEBUGGING: \n- Total Mem: %d\n- StartPtr: %d", totalMemory, memStarPtr);

}

unsigned char * getMemory(long long int sizeByte)
{
	unsigned char * retPtr;
	if (sizeByte > freeMem)
	{
		uprintf("out of mem "); // do some error handling here
		return 0;
	}
	else
	{
		retPtr = memCurrentPtr;
		memCurrentPtr = memCurrentPtr + sizeByte;
		freeMem = freeMem - sizeByte;
	}
	uprintf("---\n- DEBUGGING: \n- Allocated Mem size: %d\n- Free Mem size: %d\n- StartPtr: %d", memCurrentPtr - retPtr, freeMem, retPtr);
	return retPtr;
}

void newArray(unsigned char ** boolArray, long long int dimension)
{
	if (dimension % 8 != 0)
		dimension = dimension + 8;

	*boolArray = getMemory(dimension); // = (unsigned char*) malloc(dimension / 8);
	//memset(boolArray, 0, ((size_t) dimension) / 8);
	for (int i = 0; i < dimension; i++)
	{
		setValue(*boolArray, i, 0);
	}
}

/*
 * some sanaty checking should be done
 */
int setValue(unsigned char * array, long long int index, unsigned char val)
{
	long long int indexByte = index / 8;
	long long int indexBit = index % 8;
	long long int x = array[indexByte]; //??? needed

	if (val == 0)
	{
		x = x & ~(1 << indexBit);
	}
	else if (val == 1)
	{
		x = x | val << indexBit;
	}
	else
	{
		return -1;
	}

	array[indexByte] = (char) x;
	return 0;
}

unsigned char getValue(unsigned char * array, long long int index)
{
	long long int indexByte = index / 8;
	long long int indexBit = index % 8;
	long long int a = array[indexByte];
	long long int b = a & (1 << indexBit);
	long long int c = b >> indexBit;
	unsigned char yx = (unsigned char) c;

	return yx;
}

void dumpBoolArray16(unsigned char * map, int len, const char * description)
{
	uprintf("\n%s\n0 \t", description);

	for (int i = 0; i < len; i++)
	{
		uprintf("0x%02x ", getValue(map, i));
		if (i % 16 == 15)
		{
			if (i % 16 == 16 - 1)
			{
				uprintf("\n%02x\t", i + 1);

			}
			else
			{
				uprintf("\n\t");
			}
		}
	}
	uprintf("\n");
}
