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

#include "sfdp.h"

#include <string.h>

#include "spi_flash_types.h"
#include "spi_flash.h"
#include "uprintf.h"



#if CFG_DEBUGMSG!=0

	/* show all messages by default */
	static unsigned long s_ulCurSettings = 0xffffffff;

	#define DEBUGZONE(n)  (s_ulCurSettings&(0x00000001<<(n)))

	/* NOTE: These defines must match the ZONE_* defines. */
	#define DBG_ZONE_ERROR      0
	#define DBG_ZONE_WARNING    1
	#define DBG_ZONE_FUNCTION   2
	#define DBG_ZONE_INIT       3
	#define DBG_ZONE_VERBOSE    7

	#define ZONE_ERROR          DEBUGZONE(DBG_ZONE_ERROR)
	#define ZONE_WARNING        DEBUGZONE(DBG_ZONE_WARNING)
	#define ZONE_FUNCTION       DEBUGZONE(DBG_ZONE_FUNCTION)
	#define ZONE_INIT           DEBUGZONE(DBG_ZONE_INIT)
	#define ZONE_VERBOSE        DEBUGZONE(DBG_ZONE_VERBOSE)

	#define DEBUGMSG(cond,printf_exp) ((void)((cond)?(uprintf printf_exp),1:0))
#else  /* CFG_DEBUGMSG!=0 */
	#define DEBUGMSG(cond,printf_exp) ((void)0)
#endif /* CFG_DEBUGMSG!=0 */


SPIFLASH_ATTRIBUTES_T tSfdpAttributes;


static int read_sfdp(const FLASHER_SPI_FLASH_T *ptFlash, unsigned long ulAddress, unsigned char *pucData, size_t sizData)
{
	int iResult;
	const FLASHER_SPI_CFG_T *ptSpiDev;
	unsigned char aucCmd[5];


	DEBUGMSG(ZONE_FUNCTION, ("+read_sfdp(): ptFlash=0x%08x, ulAddress=0x%08x, pucData=0x%08x, sizData=0x%08x\n", ptFlash, ulAddress, pucData, sizData));

	/* Construct the command. */
	aucCmd[0] = 0x5aU;
	aucCmd[1] = (unsigned char)((ulAddress>>16U) & 0xffU);
	aucCmd[2] = (unsigned char)((ulAddress>> 8U) & 0xffU);
	aucCmd[3] = (unsigned char)( ulAddress       & 0xffU);
	aucCmd[4] = 0x00U;

	/* Get the SPI device. */
	ptSpiDev = &ptFlash->tSpiDev;

	/* Select the slave. */
	ptSpiDev->pfnSelect(ptSpiDev, 1);

	/* Send the command. */
	iResult = ptSpiDev->pfnSendData(ptSpiDev, aucCmd, sizeof(aucCmd));
	if( iResult!=0 )
	{
		DEBUGMSG(ZONE_ERROR, ("pfnSendData: %d\n", iResult));
	}
	else
	{
		/* Receive the data. */
		iResult = ptSpiDev->pfnReceiveData(ptSpiDev, pucData, sizData);
		if( iResult!=0 )
		{
			DEBUGMSG(ZONE_ERROR, ("pfnReceiveData: %d\n", iResult));
		}
	}

	/*  Deselect the slave. */
	ptSpiDev->pfnSelect(ptSpiDev, 0);
	if( iResult==0 )
	{
		/* Send 1 idle byte. */
		iResult = ptSpiDev->pfnSendIdle(ptSpiDev, 1);
		if( iResult!=0 )
		{
			DEBUGMSG(ZONE_ERROR, ("pfnSendIdle: %d\n", iResult));
		}
	}

	DEBUGMSG(ZONE_FUNCTION, ("-read_sfdp(): iResult=%d\n", iResult));
	return iResult;
}



typedef struct STRUCT_SECTOR_TYPE
{
	unsigned long ulSize;
	unsigned char ucOpcode;
} SECTOR_TYPE_T;

static int read_jedec_flash_parameter(FLASHER_SPI_FLASH_T *ptFlash, unsigned long ulAddress)
{
	union UNION_SFDP_DATA
	{
		unsigned char auc[36];
		unsigned long aul[9];
	} uSfdpData;
	SECTOR_TYPE_T atSectorTypes[4];
	int iResult;
	unsigned long ulValue;
	unsigned int uiPageSizePow;
	size_t sizCnt;
	size_t sizBestSectorIdx;
	unsigned long ulBestSectorSize;


	iResult = read_sfdp(ptFlash, ulAddress, uSfdpData.auc, sizeof(uSfdpData.auc));
	if( iResult!=0 )
	{
		DEBUGMSG(ZONE_ERROR, ("read_sfdp: %d\n", iResult));
	}
	else
	{
		hexdump(uSfdpData.auc, sizeof(uSfdpData.auc));

#if CFG_INCLUDE_SMART_ERASE==1

		/** Read erase instruction entries from JEDEC Basic Flash Parametes
		 *  Read starting from DWORD 8, there are 4 erase entries each with:
		 *  8-Bit for the size in 2^N format
		 *  8-Bit for the OpCode
		 */
		const unsigned char DWORD_8_START = 7*4; /* Nr of DWords starts at 1*/
		unsigned short nrEraseOps = 0; /* Required for sorting */

		/* Clear the array */
		for(int opNr = 0; opNr < FLASHER_SPI_NR_ERASE_INSTRUCTIONS; opNr++){
			ptFlash->tSpiErase[nrEraseOps].Size = 0;
			ptFlash->tSpiErase[nrEraseOps].OpCode = 0;
		}

		/* Get erase operations from SFDP data */
		for(int opNr = 0; opNr < FLASHER_SPI_NR_ERASE_INSTRUCTIONS; opNr++){
			unsigned char shift = uSfdpData.auc[DWORD_8_START + 2*opNr];
			unsigned char opCode = uSfdpData.auc[DWORD_8_START + 2*opNr + 1];
			/* No instruction present or shift further than variable size */
			if(shift != 0 && shift < sizeof(unsigned long long)*8){
				ptFlash->tSpiErase[nrEraseOps].Size = 1U << shift;
				ptFlash->tSpiErase[nrEraseOps].OpCode = opCode;
				nrEraseOps++;
			}
		}
		ptFlash->usNrEraseOperations = nrEraseOps;

		/* Sort the erase commands so the smallest is in element 0 */
		spi_sort_erase_entries(ptFlash->tSpiErase, ptFlash->usNrEraseOperations);

		/* Print sorted list of operations */
		uprintf("Erase operations:\n");
		for(unsigned int opNr = 0; opNr < FLASHER_SPI_NR_ERASE_INSTRUCTIONS; opNr++)
		{
			uprintf("OpCode: 0x%2x, Memory: %d\n", ptFlash->tSpiErase[opNr].OpCode, ptFlash->tSpiErase[opNr].Size);
		}
#endif
		/* Clear the complete structure. */
		memset(&tSfdpAttributes, 0, sizeof(tSfdpAttributes));

		/* Set a generic name. */
		memcpy(tSfdpAttributes.acName, "SFDP", 5);

		/* All SFDP capable devices must support at least 50MHz. There are no more hints. */
		tSfdpAttributes.ulClock = 50000;

		/* SFDP supports only linear addressing for now. */
		tSfdpAttributes.tAdrMode = SPIFLASH_ADR_LINEAR;

		/* Set some defaults. */
		tSfdpAttributes.ucReadOpcode = 0x03U;
		tSfdpAttributes.ucReadOpcodeDCBytes = 0;
		tSfdpAttributes.ucPageProgOpcode = 0x02U;
		tSfdpAttributes.ucReadStatusOpcode = 0x05;
		tSfdpAttributes.ucStatusReadyMask = 0x01U;
		tSfdpAttributes.ucStatusReadyValue = 0x00;
		tSfdpAttributes.ucWriteEnableOpcode = 0x06;

		/* Get the size. */
		ulValue = uSfdpData.aul[1];
		/* Bit 31 is clear if the size is <= 2GBit. */
		if( (ulValue&0x80000000U)==0 )
		{
			++ulValue;
			if( (ulValue&7U)!=0 )
			{
				uprintf("The size is no multiple of 8!\n");
				iResult = -1;
			}
			else
			{
				tSfdpAttributes.ulSize = (ulValue + 1U)>>3U;
			}
		}
		else
		{
			ulValue &= 0x7fffffffU;
			if( ulValue<3 )
			{
				uprintf("The size is smaller than 8!\n");
				iResult = -1;
			}
			tSfdpAttributes.ulSize = 1U << (ulValue-3U);
		}

		if( iResult==0 )
		{
			uprintf("size: %d\n", tSfdpAttributes.ulSize);


			/* Get the page size. */
			ulValue = uSfdpData.aul[0];
			if( (ulValue&(1<<2))==0 )
			{
				uiPageSizePow = 0;
			}
			else
			{
				uiPageSizePow = 6;
			}
			tSfdpAttributes.ulPageSize = 1U << uiPageSizePow;
			uprintf("Page size: 0x%08x\n", tSfdpAttributes.ulPageSize);


			/* Get the 4 sector types. */
			sizCnt = 0;
			do
			{
				atSectorTypes[sizCnt].ulSize   = 1U << uSfdpData.auc[0x1cU + sizCnt*2];
				atSectorTypes[sizCnt].ucOpcode = uSfdpData.auc[0x1dU + sizCnt*2];
				++sizCnt;
			} while( sizCnt<4 );

			/* Get the smallest sector type above 256 bytes. */
			sizCnt = 0;
			sizBestSectorIdx = 0;
			ulBestSectorSize = 0xffffffffU;
			do
			{
				if( atSectorTypes[sizCnt].ucOpcode!=0 &&  /* The entry must be valid. */
				    atSectorTypes[sizCnt].ulSize>=256 &&  /* The sector size must be >= 256 bytes. */
				    atSectorTypes[sizCnt].ulSize<ulBestSectorSize )
				{
					sizBestSectorIdx = sizCnt;
					ulBestSectorSize = atSectorTypes[sizCnt].ulSize;
				}
				++sizCnt;
			} while( sizCnt<4 );

			/* Found a matching sector? */
			if( ulBestSectorSize==0xffffffffU )
			{
				iResult = -1;
			}
			else
			{
				/* Get the sector size. */
				tSfdpAttributes.ulSectorPages = ulBestSectorSize >> uiPageSizePow;
				tSfdpAttributes.ucEraseSectorOpcode = atSectorTypes[sizBestSectorIdx].ucOpcode;
			}
		}
	}

	return iResult;
}



static int read_parameter_headers(FLASHER_SPI_FLASH_T *ptFlash, size_t sizSfdpHeaders)
{
	int iResult;
	union UNION_SFDP_DATA
	{
		unsigned char auc[8];
		unsigned long aul[2];
	} uSfdpData;
	size_t sizCnt;
	unsigned long ulAddress;
	unsigned char ucHeaderId;
	unsigned char ucHeaderVersion_Maj;
	unsigned char ucHeaderVersion_Min;
	size_t sizSfdpHeadersDw;
	unsigned long ulHeaderAddress;


	iResult = 0;

	sizCnt = 0;
	while( sizCnt<sizSfdpHeaders )
	{
		++sizCnt;
		uprintf("Read header %d\n", sizCnt);

		ulAddress = sizCnt*8;
		iResult = read_sfdp(ptFlash, ulAddress, uSfdpData.auc, 8);
		if( iResult!=0 )
		{
			break;
		}
		else
		{
			uprintf("iResult: %d\n", iResult);

			ucHeaderId = uSfdpData.auc[0];
			ucHeaderVersion_Min = uSfdpData.auc[1];
			ucHeaderVersion_Maj = uSfdpData.auc[2];
			sizSfdpHeadersDw = uSfdpData.auc[3];
			ulHeaderAddress = uSfdpData.aul[1] & 0x00ffffffU;

			uprintf("Found Header ID 0x%02x V%d.%d @ 0x%08x (%d bytes)\n", ucHeaderId, ucHeaderVersion_Maj, ucHeaderVersion_Min, ulHeaderAddress, sizSfdpHeadersDw*sizeof(unsigned long));

			/* Is this a known header? */
			if( ucHeaderId==0x00 && sizSfdpHeadersDw>=9 )
			{
				iResult = read_jedec_flash_parameter(ptFlash, ulHeaderAddress);
				if( iResult!=0 )
				{
					break;
				}
			}
			else
			{
				uprintf("Ignoring unknown header ID 0x%02x\n", ucHeaderId);
			}
		}
	}

	return iResult;
}



static void hexdump_line(const unsigned char *pucData, size_t sizData)
{
	const unsigned char *pucCnt;
	const unsigned char *pucEnd;


	pucCnt = pucData;
	pucEnd = pucCnt + sizData;
	while( pucCnt<pucEnd )
	{
		uprintf("0x%02x", *pucCnt);
		++pucCnt;
		if( pucCnt<pucEnd )
		{
			uprintf(", ");
		}
	}
}



static unsigned int get_jedec_id_length(unsigned char *pucArrayPointer, unsigned int uiArraySize){
    unsigned int uiIdSize = 1;
    unsigned char *pucArrayPointer0 = pucArrayPointer++;
    unsigned int uiArrayCnt;
    unsigned int uiIdValidationCnt;
    unsigned int uiArrayValidationCnt;
    for(uiArrayCnt = 1 ; uiArrayCnt < uiArraySize ; uiArrayCnt++){
        if (*pucArrayPointer != *pucArrayPointer0){
            /*current byte is different from the first byte*/
            pucArrayPointer++;
            uiIdSize++;
        } else{
            /*current byte equals the first byte*/
            for (uiIdValidationCnt = 0;uiIdValidationCnt < uiArrayCnt;uiIdValidationCnt++){
                if(*(pucArrayPointer0 + uiIdValidationCnt) != *(pucArrayPointer + uiIdValidationCnt)){
                    pucArrayPointer++;
                    uiIdSize++;
                    /*id not found yet*/
                    break;
                }
            }
            if (uiIdValidationCnt == uiArrayCnt){
                /*found a double sequence*/
                uiIdValidationCnt=0;
                for(uiArrayValidationCnt = (2*uiArrayCnt);uiArrayValidationCnt<uiArraySize;uiArrayValidationCnt++){
                    if(*(pucArrayPointer0 + uiIdValidationCnt) != *(pucArrayPointer+uiArrayValidationCnt-uiArrayCnt)){
                        /*id not found yet*/
                        pucArrayPointer++;
                        uiIdSize++;
                        break;
                    }
                    uiIdValidationCnt++;
                    if (uiIdValidationCnt == uiArrayCnt){
                        /*reset counter for validation of following id bytes*/
                        uiIdValidationCnt = 0;
                    }
                }
                if(uiArrayValidationCnt==uiArraySize){
                    /*id found*/
                    break;
                }
            }
        }

    }
    return uiIdSize;
}

static int read_jedec_id(const FLASHER_SPI_FLASH_T *ptFlash, unsigned char *pucJedecId, unsigned int sizJedecId, unsigned int *puiDetectedSize)
{
	int iResult;
	const FLASHER_SPI_CFG_T *ptSpiDev;
	unsigned char aucCmd[1];
	unsigned int uiDetectedSize = 0;

	DEBUGMSG(ZONE_FUNCTION, ("+read_jedec_id(): ptFlash=0x%08x\n", ptFlash));

	/* Construct the command. */
	aucCmd[0] = 0x9fU;

	/* Get the SPI device. */
	ptSpiDev = &ptFlash->tSpiDev;

	/* Select the slave. */
	ptSpiDev->pfnSelect(ptSpiDev, 1);

	/* Send the command. */
	iResult = ptSpiDev->pfnSendData(ptSpiDev, aucCmd, sizeof(aucCmd));
	if( iResult!=0 )
	{
		DEBUGMSG(ZONE_ERROR, ("pfnSendData: %d\n", iResult));
	}
	else
	{
		/* Receive the data. */
		iResult = ptSpiDev->pfnReceiveData(ptSpiDev, pucJedecId, sizJedecId);
		if( iResult!=0 )
		{
			DEBUGMSG(ZONE_ERROR, ("pfnReceiveData: %d\n", iResult));
		}
	}

	/*  Deselect the slave. */
	ptSpiDev->pfnSelect(ptSpiDev, 0);
	if( iResult==0 )
	{
		/* Send 1 idle byte. */
		iResult = ptSpiDev->pfnSendIdle(ptSpiDev, 1);
		if( iResult!=0 )
		{
			DEBUGMSG(ZONE_ERROR, ("pfnSendIdle: %d\n", iResult));
		}
	}


	if( iResult==0 )
	{
		/* Jetzt haben wir 32Byte JEDEC IDs in aucData! */
		uiDetectedSize = get_jedec_id_length(pucJedecId, sizJedecId);
		if (uiDetectedSize >8 || uiDetectedSize < 3)
		{
			if (uiDetectedSize == 1 && ((*pucJedecId == 0x00) || (*pucJedecId == 0xff)))
			{
				uiDetectedSize = 0;
			}
			else
			{
				uiDetectedSize = 3;
			}
		}
	}

	*puiDetectedSize = uiDetectedSize;
	DEBUGMSG(ZONE_FUNCTION, ("-read_jedec_id(): iResult=%d\n", iResult));
	return iResult;
}




const SPIFLASH_ATTRIBUTES_T *sfdp_detect(FLASHER_SPI_FLASH_T *ptFlash)
{
	FLASHER_SPI_CFG_T *ptSpiDev;
	int iResult;
	const SPIFLASH_ATTRIBUTES_T *ptResult;
	union UNION_SFDP_DATA
	{
		unsigned char auc[8];
		unsigned long aul[2];
	} uSfdpData;
	unsigned char ucSfdpVersion_Maj;
	unsigned char ucSfdpVersion_Min;
	size_t sizSfdpHeaders;
	int iJedecIdResult;
	unsigned char aucJedecId[32];
	unsigned int uiIdSequenceSize;
	char *pcName;
	unsigned int uiDevNameCnt;


	/* Get the SPI device. */
	ptSpiDev = &ptFlash->tSpiDev;

	/* Deselect all chips. */
	ptSpiDev->pfnSelect(ptSpiDev, 0);

	/* Send 8 idle bytes to clear the bus. */
	iResult = ptSpiDev->pfnSendIdle(ptSpiDev, 8);
	if( iResult!=0 )
	{
		DEBUGMSG(ZONE_VERBOSE, ("pfnSendIdle: %d", iResult));
	}
	else
	{
		iResult = read_sfdp(ptFlash, 0, uSfdpData.auc, 8);
		if( iResult==0 )
		{
			hexdump(uSfdpData.auc, 8);

			if( uSfdpData.aul[0]!=0x50444653 )
			{
				uprintf("SFDP Magic not found. Expected 0x50444653, got: 0x%08x\n", uSfdpData.aul[0]);
				iResult = -1;
			}
			else
			{
				ucSfdpVersion_Min = uSfdpData.auc[4];
				ucSfdpVersion_Maj = uSfdpData.auc[5];
				/* The number of headers are 0 based, i.e. a 0 indicates 1 header. */
				sizSfdpHeaders = (size_t)(uSfdpData.auc[6] + 1);
				uprintf("Found SFDP V%d.%d with %d headers.\n", ucSfdpVersion_Maj, ucSfdpVersion_Min, sizSfdpHeaders);

				iResult = read_parameter_headers(ptFlash, sizSfdpHeaders);
				uprintf("read_parameter_headers: %d\n", iResult);
				if( iResult==0 )
				{
					iJedecIdResult = read_jedec_id(ptFlash, aucJedecId, sizeof(aucJedecId), &uiIdSequenceSize);
					if( iJedecIdResult==0 )
					{
						pcName = tSfdpAttributes.acName;

						*(pcName++) = 'S';
						*(pcName++) = 'F';
						*(pcName++) = 'D';
						*(pcName++) = 'P';
						*(pcName++) = '_';

						for(uiDevNameCnt = 0; uiDevNameCnt < uiIdSequenceSize;uiDevNameCnt++)
						{
							/* high digit */
							if((aucJedecId[uiDevNameCnt] >> 4) <= 9)
							{
								/* char number */
								*(pcName++) = (unsigned char)((aucJedecId[uiDevNameCnt] >> 4) + 0x30);
							}
							else
							{
								/* char letter */
								*(pcName++) = (unsigned char) ((aucJedecId[uiDevNameCnt] >> 4) + 0x57);
							}

							/* low digit */
							if((aucJedecId[uiDevNameCnt] & 0x0f) <= 9)
							{
								/* char number */
								*(pcName++) = (unsigned char)((aucJedecId[uiDevNameCnt] & 0x0f) + 0x30);
							}
							else
							{
								/* char letter */
								*(pcName++) = (unsigned char)((aucJedecId[uiDevNameCnt] & 0x0f) + 0x57);
							}
						}

						/* 0 termination of string */
						*pcName = 0;

					}

					uprintf("SFDP flash parameters:\n");
					uprintf("<SerialFlash name=\"%s\" size=\"%d\" clock=\"%d\">\n", tSfdpAttributes.acName, tSfdpAttributes.ulSize, tSfdpAttributes.ulClock);
					uprintf("\t<Description>SFDP flash</Description>\n");
					uprintf("\t<Note>This flash was auto-detected with SFDP</Note>\n");
					uprintf("\t<Layout pageSize=\"%d\" sectorPages=\"%d\" mode=\"linear\" />\n", tSfdpAttributes.ulPageSize, tSfdpAttributes.ulSectorPages, spi_flash_get_adr_mode_name(tSfdpAttributes.tAdrMode));
					uprintf("\t<Read readArrayCommand=\"0x%02x\" ignoreBytes=\"%d\" />\n", tSfdpAttributes.ucReadOpcode, tSfdpAttributes.ucReadOpcodeDCBytes);
					uprintf("\t<Write writeEnableCommand=\"0x%02x\" pageProgramCommand=\"0x%02x\" bufferFillCommand=\"0x%02x\" bufferWriteCommand=\"0x%02x\" eraseAndPageProgramCommand=\"0x%02x\" />\n", tSfdpAttributes.ucWriteEnableOpcode, tSfdpAttributes.ucPageProgOpcode, tSfdpAttributes.ucBufferFill, tSfdpAttributes.ucBufferWriteOpcode, tSfdpAttributes.ucEraseAndPageProgOpcode);
					uprintf("\t<Erase erasePageCommand=\"0x%02x\" eraseSectorCommand=\"0x%02x\" eraseChipCommand=\"", tSfdpAttributes.ucErasePageOpcode, tSfdpAttributes.ucEraseSectorOpcode);
					hexdump_line(tSfdpAttributes.aucEraseChipCmd, tSfdpAttributes.ucEraseChipCmdLen);
					uprintf("\" />\n");
					uprintf("\t<Status readStatusCommand=\"0x%02x\" statusReadyMask=\"0x%02x\" statusReadyValue=\"0x%02x\" />\n", tSfdpAttributes.ucReadStatusOpcode, tSfdpAttributes.ucStatusReadyMask, tSfdpAttributes.ucStatusReadyValue);
					uprintf("\t<Init0 command=\"");
					hexdump_line(tSfdpAttributes.aucInitCmd0, tSfdpAttributes.ucInitCmd0_length);
					uprintf("\" />\n");
					uprintf("\t<Init1 command=\"");
					hexdump_line(tSfdpAttributes.aucInitCmd1, tSfdpAttributes.ucInitCmd1_length);
					uprintf("\" />\n");
					uprintf("\t<Id send=\"");
					hexdump_line(tSfdpAttributes.aucIdSend, tSfdpAttributes.ucIdLength);
					uprintf("\"\n\t    mask=\"");
					hexdump_line(tSfdpAttributes.aucIdMask, tSfdpAttributes.ucIdLength);
					uprintf("\"\n\t    magic=\"");
					hexdump_line(tSfdpAttributes.aucIdMagic, tSfdpAttributes.ucIdLength);
					uprintf("\" />\n");
					uprintf("</SerialFlash>\n");
				}
			}
		}
	}

	if( iResult==0 )
	{
		ptResult = &tSfdpAttributes;
	}
	else
	{
		ptResult = NULL;
	}

	DEBUGMSG(ZONE_FUNCTION, ("-sfdp_detect(): ptResult=0x%08x\n", ptResult));
	return ptResult;
}

