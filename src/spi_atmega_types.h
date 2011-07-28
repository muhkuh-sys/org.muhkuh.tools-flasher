/***************************************************************************  
 *   Copyright (C) 2011 by Hilscher GmbH                                   *  
 ***************************************************************************/ 

/***************************************************************************  
  File          : spi_atmega_types.h                                                   
 ---------------------------------------------------------------------------- 
  Description:                                                                
                                                                              
      typedef for ATmega device parameters and commands
 ---------------------------------------------------------------------------- 
  Todo:                                                                       
                                                                              
 ---------------------------------------------------------------------------- 
  Known Problems:                                                             
                                                                              
    -                                                                         
                                                                              
 ---------------------------------------------------------------------------- 
 5 jul 11   SL   initial version
 ***************************************************************************/ 

#ifndef __SPI_ATMEGA_TYPES_H__
#define __SPI_ATMEGA_TYPES_H__

#include "spi.h"

#define ATMEGA_CMDLEN 4
#define SPI_ATMEGA_CMDLEN 4
#define SPI_ATMEGA_NAMESIZE 16
#define SPI_ATMEGA_IDSIZE 8

typedef struct SPI_ATMEGA_ATTRIBUTES_Ttag
{
	char			acName[SPI_ATMEGA_NAMESIZE];	/* name of the flash, 0 terminated    */
	unsigned long	ulClock;						/* maximum speed in kHz               */
	
	unsigned long	ulFlashSize;					/* size of the flash memory in bytes  */
	unsigned long	ulFlashWordSize;				/* word size                          */
	unsigned long	ulFlashPageSizeWords;			/* size of one page in words          */
	unsigned long	ulFlashPageSizeBytes;			/* size of one page in bytes          */
	unsigned long	ulFlashSectorPages;				/* size of one sector in pages        */

	unsigned int	uiChipIdLength;
	unsigned char	aucChipId[SPI_ATMEGA_IDSIZE];
	
	 /* minimum wait delay after write operations */
	unsigned int	uitWD_fuse;
	unsigned int	uitWD_flash;
	unsigned int	uitWD_eeprom;
	unsigned int	uitWD_erase;
	
	unsigned char	aucProgEnableCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucChipEraseCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucPollRdyBusyCmd[SPI_ATMEGA_CMDLEN];
	
	unsigned char	aucLoadExtAddrByteCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucLoadPrgMemHighCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucLoadPrgMemLowCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucLoadEepromMemPageCmd[SPI_ATMEGA_CMDLEN];
	
	unsigned char	aucReadProgMemHighCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucReadProgMemLowCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucReadEepromMemCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucReadLockBitsCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucReadSignatureByteCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucReadFuseBitsCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucReadFuseHighBitsCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucReadExtendedFuseBitsCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucReadCalibrationByteCmd[SPI_ATMEGA_CMDLEN];
	
	unsigned char	aucWritePrgMemPageCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucWriteEepromMemCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucWriteEepromMemPageCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucWriteLockBitsCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucWriteFuseBitsCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucWriteFuseHighBitsCmd[SPI_ATMEGA_CMDLEN];
	unsigned char	aucWriteExtendedFuseBitsCmd[SPI_ATMEGA_CMDLEN];
	
} SPI_ATMEGA_ATTRIBUTES_T;



typedef struct SPI_ATMEGA_Ttag
{
	SPI_ATMEGA_ATTRIBUTES_T tAttributes;	/* attributes of the flash      */
	SPI_CFG_T tSpiDev;						/* spi device and its settings  */
	unsigned long ulSectorSize;				/* size of one sector in bytes  */
	unsigned int uiSlaveId;					/* SPI Slave Id of the flash    */
	unsigned int uiPageAdrShift;			/* bitshift for the page part of the address, 0 means no page / byte split  */
	unsigned int uiSectorAdrShift;			/* bitshift for one sector, 0 means no page / byte split                    */
} SPI_ATMEGA_T;

#endif /* __SPI_ATMEGA_TYPES_H__ */