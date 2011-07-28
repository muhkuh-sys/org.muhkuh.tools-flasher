/***************************************************************************  
 *   Copyright (C) 2011 by Hilscher GmbH                                   *  
 ***************************************************************************/ 

/***************************************************************************  
  File          : spi_atmega.h                                                   
 ---------------------------------------------------------------------------- 
  Description:                                                                
                                                                              
      SPI functions for ATmega
 ---------------------------------------------------------------------------- 
  - The following functions are not implemented: checksum   getEraseArea  isErased
    
  - We could add a sync check to the command execution:
    When the command is           aa bb cc dd
    the received data should be   xx aa bb yy
    
 ---------------------------------------------------------------------------- 
  Known Problems:                                                             
                                                                              
  -
                                                                              
 ----------------------------------------------------------------------------
 5 jul 11    SL   initial version
 26 jul 11   SL   don't use SPI chip select lines
                  use 250 kHz SPI clock
 ***************************************************************************/ 
 
#include <string.h>
#include "uprintf.h"
#include "spi_atmega.h"
#include "spi_atmega_types.h"
#include "delay.h"
#include "progress_bar.h"


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

#define DBG_CALL_FAILED_VAL(n, v)  DEBUGMSG(ZONE_ERROR, ("! ERROR: %s: %s failed with %d\n", __func__, (n), (v)));
#define DBG_ERROR(str)             DEBUGMSG(ZONE_ERROR, ("! ERROR: %s: %s\n", __func__, (str)));
#define DBG_ERROR_VAL(format, ...) DEBUGMSG(ZONE_ERROR, ("! ERROR: %s: " format "\n", __func__, __VA_ARGS__));

#define DBG_ENTER                  DEBUGMSG(ZONE_FUNCTION, ("+%s\n", __func__));
#define DBG_LEAVE                  DEBUGMSG(ZONE_FUNCTION, ("-%s\n", __func__));
#define DBG_LEAVE_RET              DEBUGMSG(ZONE_FUNCTION, ("-%s return value = 0x%08x\n", __func__, iResult));
#define DBG_ENTER_VAL(str, v)      DEBUGMSG(ZONE_FUNCTION, ("+%s " str "\n", __func__, (v)));
#define DBG_LEAVE_VAL(str, v)      DEBUGMSG(ZONE_FUNCTION, ("-%s " str "\n", __func__, (v)));


const SPI_ATMEGA_ATTRIBUTES_T atKnownSpiATMegaTypes[] = 
{
	{
		.acName="ATMega16\0",
		
		.ulClock = 250, 
		
		.ulFlashSize = 16384,
		.ulFlashWordSize = 2,
		.ulFlashPageSizeWords = 64,
		.ulFlashPageSizeBytes = 128,
		.ulFlashSectorPages = 1,
		
		.uiChipIdLength = 3,
		.aucChipId = {0x1e, 0x94, 0x03},
		
		.uitWD_fuse                  = 4500,
		.uitWD_flash                 = 4500,
		.uitWD_eeprom                = 9000,
		.uitWD_erase                 = 9000,

		
		.aucProgEnableCmd            = {0xac, 0x53},
		.aucChipEraseCmd             = {0xac, 0x80},
		.aucPollRdyBusyCmd           = {0xf0},
		.aucLoadExtAddrByteCmd       = {0x4d},
		.aucLoadPrgMemHighCmd        = {0x48},
		.aucLoadPrgMemLowCmd         = {0x40},
		.aucLoadEepromMemPageCmd     = {0xc1},
		.aucReadProgMemHighCmd       = {0x28},
		.aucReadProgMemLowCmd        = {0x20},
		.aucReadEepromMemCmd         = {0xa0},
		.aucReadLockBitsCmd          = {0x58, 0x00},
		.aucReadSignatureByteCmd     = {0x30},
		.aucReadFuseBitsCmd          = {0x50, 0x00},
		.aucReadFuseHighBitsCmd      = {0x58, 0x08},
		.aucReadExtendedFuseBitsCmd  = {0x50, 0x08},
		.aucReadCalibrationByteCmd   = {0x38},
		.aucWritePrgMemPageCmd       = {0x4c},
		.aucWriteEepromMemCmd        = {0xc0},
		.aucWriteEepromMemPageCmd    = {0xc2},
		.aucWriteLockBitsCmd         = {0xac, 0xe0},
		.aucWriteFuseBitsCmd         = {0xac, 0xa0},
		.aucWriteFuseHighBitsCmd     = {0xac, 0xa8},
		.aucWriteExtendedFuseBitsCmd = {0xac, 0xa4},
	}
};

const int iATMegaTypes = sizeof(atKnownSpiATMegaTypes)/sizeof(SPI_ATMEGA_ATTRIBUTES_T);


void uprintHex(const char* pcName, const unsigned char* pucData, size_t sizLen)
{
	unsigned int uiCnt;
	if (pcName)
	{
		uprintf(pcName);
	}
	
	for(uiCnt = 0; uiCnt<sizLen; uiCnt++ )
	{
		uprintf("%02x ", pucData[uiCnt]);
	}
	
	uprintf("\n");
}


/* 
 * Low level command execution: 
 * send 4 bytes and read 4 bytes.
 * 
 * ptDevice: contains tSpiDev required by SPI routines
 * pucSendBuffer         send buffer, sizCmdLen bytes
 * pucReceiveBuffer      receive buffer, sizCmdLen bytes
 * sizCmdLen             the number of bytes to exchange
 */
int atmega_exec_command(const SPI_ATMEGA_T *ptDevice, const unsigned char *pucSendBuffer, unsigned char *pucReceiveBuffer, size_t sizCmdLen)
{
	int iResult = 0;
	const SPI_CFG_T *ptSpiDev = &ptDevice->tSpiDev;
	
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_exec_command(): ptDevice=0x%08x, pucSendBuffer=0x%08x  pucReceiveBuffer=0x%08x  sizCmdLen=%d\n", 
		ptDevice, pucSendBuffer, pucReceiveBuffer, sizCmdLen));
	
	/* deselect all chips */
	ptSpiDev->pfnSelect(ptSpiDev, 0);
	
	/* send 8 idle bytes to clear the bus */
	//iResult = ptSpiDev->pfnSendIdle(ptSpiDev, 8);
	if( iResult!=0 )
	{
		DBG_CALL_FAILED_VAL("pfnSendIdle", iResult)
	}
	else
	{
		/* select the slave */
		//ptSpiDev->pfnSelect(ptSpiDev, 1);

		/* send id magic and receive response */
		iResult = ptSpiDev->pfnExchangeData(ptSpiDev, pucSendBuffer, pucReceiveBuffer, sizCmdLen);

		/* deselect slave */
		//ptSpiDev->pfnSelect(ptSpiDev, 0);

		/* did the send and receive operation fail? */
		if( iResult!=0 )
		{
			DBG_CALL_FAILED_VAL("pfnExchangeData", iResult)
		}

#if CFG_DEBUGMSG!=0
		if( ZONE_VERBOSE )
		{
			uprintHex("Sent:     ", pucSendBuffer,    sizCmdLen);
			uprintHex("Received: ", pucReceiveBuffer, sizCmdLen);
		}
#endif
	}
	
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_exec_command(): iResult=%d.\n", iResult));
	return iResult;
}


/*
 * Construct and execute a command.
 * 
 * ptDevice     device description
 * pucCmd       pointer to 4-byte command
 * usParam      value to put in bytes 2 and 3
 * tParamType   format of usParam
 * bByte4In     value of byte 4
 * pbByte4Out   For commands which return a byte.
 *              If non-NULL, the fourth byte of the returned 
 *              data is written to this location.
 */
int atmega_command(const SPI_ATMEGA_T *ptDevice, 
	const unsigned char *pucCmd, 
	unsigned short usParam, ATMEGA_CMDPARAM_T tParamType, 
	unsigned char bByte4In, 
	unsigned char *pbByte4Out)
{
	int iResult = 0;
	unsigned char aucSendBuffer[ATMEGA_CMDLEN];
	unsigned char aucReceiveBuffer[ATMEGA_CMDLEN];
	
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_command(): ptDevice=0x%08x pucCmd=0x%08x usParam=0x%04x tParamType=%d bByte4In=0x%08x pbByte4Out=0x%08x\n", 
		ptDevice, pucCmd, tParamType, usParam, bByte4In, pbByte4Out));
		
	
	/* copy the command and fill in parameters */
	memcpy(aucSendBuffer, pucCmd, ATMEGA_CMDLEN);
	
	switch(tParamType)
	{
		case ATMEGA_CMDPARAM_NONE:
			break;
		
		case ATMEGA_CMDPARAM_8BIT:
			aucSendBuffer[2] = (unsigned char) (usParam & 0xff);
			break;
		
		case ATMEGA_CMDPARAM_16BIT:
			aucSendBuffer[1] = (unsigned char) ((usParam >> 8) & 0xff);
			aucSendBuffer[2] = (unsigned char) (usParam & 0xff);
			break;
		
		default:
			iResult = 1;
			DBG_ERROR_VAL("atmega_command: invalid parameter type: 0x%08x.", tParamType);
			break;
	}
	
	aucSendBuffer[3]=bByte4In;
	
	/* execute the command and read out the returned byte, if any */
	if (iResult==0)
	{
		iResult = atmega_exec_command(ptDevice, aucSendBuffer, aucReceiveBuffer, ATMEGA_CMDLEN);
		
		if (iResult!=0)
		{
			DBG_CALL_FAILED_VAL("exec_atmega_command", iResult)
		}
		else
		{
			if (pbByte4Out != NULL)
			{
				*pbByte4Out = aucReceiveBuffer[3];
				DEBUGMSG(ZONE_VERBOSE, ("atmega_command: return byte: 0x%02x\n", *pbByte4Out));
			}
		}
	}
	
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_command(): iResult=%d.\n", iResult));
	
	return iResult;
}



/*************************************************************************
                     program enable/poll ready/chip erase
 *************************************************************************/

/* 
 * Send Program Enable
 * ptDeviceAttr is an extra argument because this is called before the device attributes are copied into tDevice 
 */
int atmega_program_enable(const SPI_ATMEGA_T *ptDevice, const SPI_ATMEGA_ATTRIBUTES_T *ptDeviceAttr)
{
	int iResult;
	unsigned char aucReceiveBuffer[ATMEGA_CMDLEN];
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_program_enable(): ptDevice=0x%08x\n", ptDevice));
	iResult = atmega_exec_command(ptDevice, ptDeviceAttr->aucProgEnableCmd, aucReceiveBuffer, ATMEGA_CMDLEN);
	if (iResult == 0) 
	{
		if (aucReceiveBuffer[2]!=0x53)
		{
			iResult=1;
			DBG_ERROR_VAL("atmega_program_enable: 3rd byte read is 0x%02x, should be 0x53.", aucReceiveBuffer[2]);
		}
	}
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_program_enable(): iResult=%d.\n", iResult));
	return iResult;
}

/* Chip Erase */
int atmega_chip_erase(const SPI_ATMEGA_T *ptDevice)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_chip_erase(): ptDevice=0x%08x\n", ptDevice));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucChipEraseCmd, 0, ATMEGA_CMDPARAM_NONE, 0, NULL);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_chip_erase(): iResult=%d.\n", iResult));
	return iResult;
}


/* Poll for ready/busy */
int atmega_poll_rdy_busy(const SPI_ATMEGA_T *ptDevice, unsigned char *pbRdy)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_poll_rdy_busy(): ptDevice=0x%08x\n", ptDevice));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucPollRdyBusyCmd, 0, ATMEGA_CMDPARAM_NONE, 0, pbRdy);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_poll_rdy_busy(): iResult=%d\n", iResult));
	return iResult;
}



/*************************************************************************
                     Load instructions
 *************************************************************************/

int atmega_load_extended_address_byte(const SPI_ATMEGA_T *ptDevice, unsigned char ucAddr)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_load_extended_address_byte(): ptDevice=0x%08x ucAddr=0x%02x\n", ptDevice, ucAddr));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucLoadExtAddrByteCmd, ucAddr, ATMEGA_CMDPARAM_8BIT, 0, NULL);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_load_extended_address_byte(): iResult=%d.\n", iResult));
	return iResult;
}
 
 
 
int atmega_load_prg_mem_page_high_byte(const SPI_ATMEGA_T *ptDevice, unsigned short usAddr, unsigned char bByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_load_prg_mem_page_high_byte(): ptDevice=0x%08x usAddr=0x%04x  bByte=0x%02x\n", ptDevice, usAddr, bByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucLoadPrgMemHighCmd, usAddr, ATMEGA_CMDPARAM_16BIT, bByte, NULL);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_load_prg_mem_page_high_byte(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_load_prg_mem_page_low_byte(const SPI_ATMEGA_T *ptDevice, unsigned short usAddr, unsigned char bByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_load_prg_mem_page_low_byte(): ptDevice=0x%08x usAddr=0x%04x  bByte=0x%02x\n", ptDevice, usAddr, bByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucLoadPrgMemLowCmd, usAddr, ATMEGA_CMDPARAM_16BIT, bByte, NULL);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_load_prg_mem_page_low_byte(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_load_eeprom_mem_page(const SPI_ATMEGA_T *ptDevice, unsigned char ucAddr, unsigned char bByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_load_eeprom_mem_page(): ptDevice=0x%08x ucAddr=0x%02x  bByte=0x%02x\n", ptDevice, ucAddr, bByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucLoadEepromMemPageCmd, ucAddr, ATMEGA_CMDPARAM_8BIT, bByte, NULL);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_load_eeprom_mem_page(): iResult=%d.\n", iResult));
	return iResult;
}


/*************************************************************************
                     Read instructions
 *************************************************************************/


int atmega_read_prg_mem_high_byte(const SPI_ATMEGA_T *ptDevice, unsigned short usAddr, unsigned char *pbByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_read_prg_mem_high_byte(): ptDevice=0x%08x usAddr=0x%04x  pbByte=0x%02x\n", ptDevice, usAddr, pbByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucReadProgMemHighCmd, usAddr, ATMEGA_CMDPARAM_16BIT, 0, pbByte);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_read_prg_mem_high_byte(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_read_prg_mem_low_byte(const SPI_ATMEGA_T *ptDevice, unsigned short usAddr, unsigned char *pbByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_read_prg_mem_low_byte(): ptDevice=0x%08x usAddr=0x%04x  pbByte=0x%02x\n", ptDevice, usAddr, pbByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucReadProgMemLowCmd, usAddr, ATMEGA_CMDPARAM_16BIT, 0, pbByte);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_read_prg_mem_low_byte(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_read_eeprom_mem(const SPI_ATMEGA_T *ptDevice, unsigned short usAddr, unsigned char *pbByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_read_eeprom_mem(): ptDevice=0x%08x usAddr=0x%04x  pbByte=0x%02x\n", ptDevice, usAddr, pbByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucReadEepromMemCmd, usAddr, ATMEGA_CMDPARAM_16BIT, 0, pbByte);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_read_eeprom_mem(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_read_lock_bits(const SPI_ATMEGA_T *ptDevice, unsigned char *pbByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_read_lock_bits(): ptDevice=0x%08x pbByte=0x%02x\n", ptDevice, pbByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucReadLockBitsCmd, 0, ATMEGA_CMDPARAM_NONE, 0, pbByte);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_read_lock_bits(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_read_signature_byte(const SPI_ATMEGA_T *ptDevice, unsigned char ucIndex, unsigned char *pbByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_read_signature_byte(): ptDevice=0x%08x ucIndex=0x%02x  pbByte=0x%02x\n", ptDevice, ucIndex, pbByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucReadSignatureByteCmd, ucIndex, ATMEGA_CMDPARAM_8BIT, 0, pbByte);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_read_signature_byte(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_read_fuse_bits(const SPI_ATMEGA_T *ptDevice, unsigned char *pbByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_read_fuse_bits(): ptDevice=0x%08x  pbByte=0x%02x\n", ptDevice, pbByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucReadFuseBitsCmd, 0, ATMEGA_CMDPARAM_NONE, 0, pbByte);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_read_fuse_bits(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_read_fuse_high_bits(const SPI_ATMEGA_T *ptDevice, unsigned char *pbByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_read_fuse_high_bits(): ptDevice=0x%08x  pbByte=0x%02x\n", ptDevice, pbByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucReadFuseHighBitsCmd, 0, ATMEGA_CMDPARAM_NONE, 0, pbByte);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_read_fuse_high_bits(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_read_extended_fuse_bits(const SPI_ATMEGA_T *ptDevice, unsigned char *pbByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_read_extended_fuse_bits(): ptDevice=0x%08x  pbByte=0x%02x\n", ptDevice, pbByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucReadExtendedFuseBitsCmd, 0, ATMEGA_CMDPARAM_NONE, 0, pbByte);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_read_extended_fuse_bits(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_read_calibration_byte(const SPI_ATMEGA_T *ptDevice, unsigned char ucIndex, unsigned char *pbByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_read_calibration_byte(): ptDevice=0x%08x ucIndex=0x%02x  pbByte=0x%02x\n", ptDevice, ucIndex, pbByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucReadCalibrationByteCmd, ucIndex, ATMEGA_CMDPARAM_8BIT, 0, pbByte);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_read_calibration_byte(): iResult=%d.\n", iResult));
	return iResult;
}


/*************************************************************************
                     Write instructions
 *************************************************************************/

 
int atmega_write_prg_mem_page(const SPI_ATMEGA_T *ptDevice, unsigned short usAddr)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_write_prg_mem_page(): ptDevice=0x%08x usAddr=0x%04x\n", ptDevice, usAddr));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucWritePrgMemPageCmd, usAddr, ATMEGA_CMDPARAM_16BIT, 0, NULL);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_write_prg_mem_page(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_write_eeprom_mem(const SPI_ATMEGA_T *ptDevice, unsigned short usAddr, unsigned char bByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_write_eeprom_mem(): ptDevice=0x%08x usAddr=0x%04x  bByte=0x%02x\n", ptDevice, usAddr, bByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucWriteEepromMemCmd, usAddr, ATMEGA_CMDPARAM_16BIT, bByte, NULL);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_write_eeprom_mem(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_write_eeprom_mem_page(const SPI_ATMEGA_T *ptDevice, unsigned short usAddr)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_write_eeprom_mem_page(): ptDevice=0x%08x usAddr=0x%04x\n", ptDevice, usAddr));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucWriteEepromMemPageCmd, usAddr, ATMEGA_CMDPARAM_16BIT, 0, NULL);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_write_eeprom_mem_page(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_write_lock_bits(const SPI_ATMEGA_T *ptDevice, unsigned char bByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_write_lock_bits(): ptDevice=0x%08x  bByte=0x%02x\n", ptDevice, bByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucWriteLockBitsCmd, 0, ATMEGA_CMDPARAM_NONE, bByte, NULL);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_write_lock_bits(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_write_fuse_bits(const SPI_ATMEGA_T *ptDevice, unsigned char bByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_write_fuse_bits(): ptDevice=0x%08x  bByte=0x%02x\n", ptDevice, bByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucWriteFuseBitsCmd, 0, ATMEGA_CMDPARAM_NONE, bByte, NULL);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_write_fuse_bits(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_write_fuse_high_bits(const SPI_ATMEGA_T *ptDevice, unsigned char bByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_write_fuse_high_bits(): ptDevice=0x%08x  bByte=0x%02x\n", ptDevice, bByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucWriteFuseHighBitsCmd, 0, ATMEGA_CMDPARAM_NONE, bByte, NULL);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_write_fuse_high_bits(): iResult=%d.\n", iResult));
	return iResult;
}


int atmega_write_extended_fuse_bits(const SPI_ATMEGA_T *ptDevice, unsigned char bByte)
{
	int iResult;
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_write_extended_fuse_bits(): ptDevice=0x%08x  bByte=0x%02x\n", ptDevice, bByte));
	iResult = atmega_command(ptDevice, ptDevice->tAttributes.aucWriteExtendedFuseBitsCmd, 0, ATMEGA_CMDPARAM_NONE, bByte, NULL);
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_write_extended_fuse_bits(): iResult=%d.\n", iResult));
	return iResult;
}




/*************************************************************************
  
 *************************************************************************/

 /* Read a byte from flash memory */
int atmega_read_prg_mem_byte(const SPI_ATMEGA_T *ptDevice, unsigned long ulAddr, unsigned char *pbByte)
{
	unsigned short usAddr = (unsigned short) ulAddr>>1;
	int iResult;
	
	if ((ulAddr & 1) == 0)
	{
		iResult = atmega_read_prg_mem_low_byte(ptDevice, usAddr, pbByte);
	}
	else
	{
		iResult = atmega_read_prg_mem_high_byte(ptDevice, usAddr, pbByte);
	}
	
	//uprintf("byte addr = 0x%04x value = 0x%02x iResult = %d\n", ulAddr, *pbByte, iResult);
	return iResult;
}

/* 
 * Load one byte into page buffer for flash programming
 * usAddr   byte offset in page buffer 
 * bByte    byte value to put
 */

int atmega_load_prg_mem_page_byte (const SPI_ATMEGA_T *ptDevice, unsigned long ulAddr, unsigned char bByte)
{
	unsigned short usAddr = (unsigned short) ulAddr>>1;
	int iResult;
	
	if ((ulAddr & 1) == 0)
	{
		iResult = atmega_load_prg_mem_page_low_byte(ptDevice, usAddr, bByte);
	}
	else
	{
		iResult = atmega_load_prg_mem_page_high_byte(ptDevice, usAddr, bByte);
	}
	
	//uprintf("ulAddr: 0x%08x  byte: 0x%02x iResult:\n", ulAdr, bByte);
	
	return iResult;
}

/*
 * Read the device ID
 * 
 * Read sizBufferLen bytes to location pucSignature
 * pucSignature  target location of the device ID
 * sizBufferLen  number of bytes to read
 */
int atmega_read_device_id(const SPI_ATMEGA_T *ptDevice, const SPI_ATMEGA_ATTRIBUTES_T *ptDeviceAttr, unsigned char *pucSignature, size_t sizBufferLen)
{
	int iResult = 0;
	const unsigned char *pucReadSigByteCmd = ptDeviceAttr->aucReadSignatureByteCmd;
	size_t sizSigLen = ptDeviceAttr->uiChipIdLength;
	unsigned char iByteIndex;
	
	DEBUGMSG(ZONE_FUNCTION, ("+atmega_read_device_id(): ptDevice=0x%08x, ptDeviceAttr=0x%08x, pucSignature=0x%08x sizBufferLen=%d\n", 
		ptDevice, ptDeviceAttr, pucSignature, sizBufferLen));
	
	if (sizSigLen > sizBufferLen)
	{
		iResult = 1;
		uprintf("Signature does not fit in signature buffer\n");
	}
	else
	{
		for (iByteIndex = 0; (iByteIndex < sizSigLen) && (iResult == 0); iByteIndex++)
		{
			iResult = atmega_command(ptDevice, pucReadSigByteCmd, iByteIndex, ATMEGA_CMDPARAM_8BIT, 0, pucSignature+iByteIndex);
		}
	
		if( iResult==0 )
		{
			uprintHex("Signature: ", pucSignature, sizSigLen);
		}
	}
	
	DEBUGMSG(ZONE_FUNCTION, ("-atmega_read_device_id(): iResult=%d.\n", iResult));
	return iResult;
}

/*************************************************************************
                                MMIO setup
 *************************************************************************/


#if ASIC_TYP==10
/* netX10 has a SQI and a SPI unit. */
#	include "drv_sqi.h"
#	include "drv_spi_hsoc_v2.h"
#elif ASIC_TYP==50
#	include "drv_spi_hsoc_v2.h"
#elif ASIC_TYP==100 || ASIC_TYP==500
#	include "drv_spi_hsoc_v1.h"
#endif


/*
 * Signal Pos.         GPIO/cfg val  SPI1/cfg val
 * SCLK_1 V9   MMIO26  GPIO26  0x2c  SPI1_CLK 0x6d
 * MISO_1 R8   MMIO25  GPIO25  0x2b  SPI1_MISO 0x71
 * MOSI_1 U7   MMIO24  GPIO24  0x2a  SPI1_MOSI 0x72
 * CS0n_1 V7   MMIO23  GPIO23  0x29  SPI1_CS0n 0x6e
 * CS1n_1 T7   MMIO22  GPIO22  0x28  SPI1_CS1n 0x6f
 * RES_S2 U6   MMIO21  GPIO21  0x27  
 * RES_S1 V6   MMIO20  GPIO20  0x26
 */



#define NX50_GPIO_OUT_0 4
#define NX50_GPIO_OUT_1 5

/* map cs 0/1 to GPIO number to use for reset */
static const unsigned char aucATMegaResetGPIOPins[2] = {20, 21}; 

#if ASIC_TYP==50
#include "mmio.h"
static const unsigned char aucMmioPinNumbers[7] = {26, 25, 24, 23, 22, 21, 20 };
static const MMIO_CFG_T atMmioValues[7] =
{
	/*
	 * ATMega Chip Select 0/1, Reset
	 */
		MMIO_CFG_spi1_clk,		/* clock */
		MMIO_CFG_spi1_miso,		/* miso */
		MMIO_CFG_spi1_mosi,		/* mosi */
		
		MMIO_CFG_spi1_cs0n,		/* chip select */
		MMIO_CFG_spi1_cs1n,		/* chip select */
		
		MMIO_CFG_gpio21,        /* reset S2*/
		MMIO_CFG_gpio20,        /* reset S1*/
};
#endif


/*************************************************************************
                   initialize/detect ATMega
 *************************************************************************/


/*
To program and verify the ATmega in the SPI Serial Programming mode, the follow
sequence is recommended (See four byte instruction formats in Figure 116 on page 276):

1.Power-up sequence:
Apply power between VCC and GND while RESET and SCK are set to “0”. In some sys-
tems, the programmer can not guarantee that SCK is held low during power-up. In this 
case, RESET must be given a positive pulse of at least two CPU clock cycles duration 
after SCK has been set to “0”.

CPU clock is 1-16 MHz -> 2 clock cycles >= 2 microseconds

CLK = low
Reset = high
wait 2 us
Reset = low

2.Wait for at least 20 ms and 

3.enable SPI Serial Programming by sending the Programming Enable serial instruction to pin MOSI.

3.The SPI Serial Programming instructions will not work if the communication is out of syn-
chronization. When in sync. the second byte ($53), will echo back when issuing the third 
byte of the Programming Enable instruction. Whether the echo is correct or not, all four 
bytes of the instruction must be transmitted. If the $53 did not echo back, give RESET a 
positive pulse and issue a new Programming Enable command. 

uiChipSelect in SPI_CONFIGURATION_T is a number.
uiChipSelect in SPI_CFG_T (ptDevice->tSpiDev.uiChipSelect is 2^this number.
uiSlaveId in SPI_ATMEGA_T is equal to uiChipSelect in SPI_CONFIGURATION_T
*/


/*! detect_atmega
 *   try to initialize and detect one type of ATMega
 *               
 *   \param  ptDevice     pointer to device description, with valid SPI_CFG_T and slave id
 *   \param  ptDeviceAttr pointer to attributes of the chip type to probe
 *
 *                                                                              
 *   \return  0  ATMega successcully initialized
 *            1  failed to detect/initialize
 */

#define ATMEGA_PRG_ENABLE_DELAY 30000  /* min 20000 ms */
#define ATMEGA_RESET_TIME 4            /* reset delay in micorseconds, min. 2 clock cycles of ATMega
                                          If the ATMega is running at 1 MHz, 
                                          the reset delay must be at least 2 microseconds. */

/* 
 * Try to detect an ATmega of a particular type.
 * Try to read a device ID and check if it matches the one in the device attributes at ptDeviceAttr
 */
static int detect_atmega(const SPI_ATMEGA_T *ptDevice, const SPI_ATMEGA_ATTRIBUTES_T *ptDeviceAttr)
{
	int iResult = 1;
	int iCmpRes; /* 0 = match */
	const SPI_CFG_T *ptSpiDev;

	unsigned char aucSignature[SPI_ATMEGA_IDSIZE]; 
	
	size_t sizSigLen = ptDeviceAttr->uiChipIdLength;
	
	DEBUGMSG(ZONE_FUNCTION, ("+detect_atmega(): ptDevice=0x%08x\n", ptDevice));

	/* get spi device */
	ptSpiDev = &ptDevice->tSpiDev;

	uprintf("Probing for %s\n", ptDeviceAttr->acName);
	
	unsigned int uiChipSelect = ptDevice->uiSlaveId;
	unsigned int uiResetGPIO = aucATMegaResetGPIOPins[uiChipSelect];

	uprintf("Resetting ATMega\n");
	
	/* set ALL reset lines to 1 */
	ptGpioArea->aulGpio_cfg[aucATMegaResetGPIOPins[0]] = NX50_GPIO_OUT_1;
	ptGpioArea->aulGpio_cfg[aucATMegaResetGPIOPins[1]] = NX50_GPIO_OUT_1;
	
	/* set reset line for selected chip to 0 */
	ptGpioArea->aulGpio_cfg[uiResetGPIO] = NX50_GPIO_OUT_0;
	uprintf("\nReset = 0\n");
	
	/* set clk line to 0 */
	ptSpiDev->pfnSendIdle(ptSpiDev, 4);
	
	/* set reset line for selected chip to 1 */
	ptGpioArea->aulGpio_cfg[uiResetGPIO] = NX50_GPIO_OUT_1;
	uprintf("\nReset = 1\n");
	
	delay_us (ATMEGA_RESET_TIME);
	
	/* set reset line for selected chip to 0 */
	ptGpioArea->aulGpio_cfg[uiResetGPIO] = NX50_GPIO_OUT_0;
	uprintf("\nReset = 0\n");
	
	delay_us (ATMEGA_PRG_ENABLE_DELAY);
	
	iResult = atmega_program_enable(ptDevice, ptDeviceAttr);
	
	if (iResult != 0)
	{
		uprintf("Sync failed\n");
	}
	else
	{
		iResult = atmega_read_device_id(ptDevice, ptDeviceAttr, aucSignature, sizSigLen);
		
		if (iResult != 0) 
		{
			uprintf("Failed to read signature\n");
		}
		else
		{
			iCmpRes = memcmp(aucSignature, ptDeviceAttr->aucChipId, ptDeviceAttr->uiChipIdLength);
			if (iCmpRes == 0)
			{
				uprintf("Signature matched.\n");
				iResult = 0; 
			}
			else
			{
				uprintf("Signature mismatch.\n");
				iResult = 1; 
			}
		}
	}
	
	DEBUGMSG(ZONE_FUNCTION, ("-detect_atmega(): iResult=%d.\n", iResult));
	return iResult;
}


/*! detect_atmega_type
 *   Try all ATMega types defined (currently only one)
 *               
 *   \param  ptDevice  pointer to device description, with valid SPI_CFG_T and slave id
 *   \param  pptDeviceAttr pointer to location to store the attributes of the recognized chip
 *
 *                                                                              
 *   \return  0  ATMega successcully initialized
 *            1  failed to detect/initialize
 */

int detect_atmega_type(const SPI_ATMEGA_T *ptDevice, const SPI_ATMEGA_ATTRIBUTES_T **pptDeviceAttr)
{
	const SPI_ATMEGA_ATTRIBUTES_T *ptKnownSpiATMegaTypesEnd = atKnownSpiATMegaTypes + iATMegaTypes;
	const SPI_ATMEGA_ATTRIBUTES_T *ptDeviceAttr = &atKnownSpiATMegaTypes[0];
	
	int iResult = 1;
	while ((ptDeviceAttr < ptKnownSpiATMegaTypesEnd) && (iResult!=0)) 
	{
		iResult = detect_atmega(ptDevice, ptDeviceAttr);
		if (iResult != 0) {
			++ptDeviceAttr;
		}
	}
	
	if (iResult==0) 
	{
		*pptDeviceAttr = ptDeviceAttr;
	}

	return iResult;
}

/*! Drv_SpiInitializeATMega
 *   Initializes the FLASH
 *               
 *   \param  ptSpiCfg  pointer to SPI unit/cs
 *   \param  ptDevice  pointer to device description, points to an empty buffer to be filled
 *
 *                                                                              
 *   \return  0  ATMega successcully initialized
 *            1  failed to detect/initialize
 */

int Drv_SpiInitializeATMega(const SPI_CONFIGURATION_T *ptSpiCfg, SPI_ATMEGA_T *ptDevice)
{
	int   iResult;
	const SPI_ATMEGA_ATTRIBUTES_T *ptDeviceAttr;
	SPI_CFG_T *ptSpiDev;
	//unsigned int uiCmdLen;


	DEBUGMSG(ZONE_FUNCTION, ("+Drv_SpiInitializeATMega(): ptSpiCfg=%08x, ptDevice=0x%08x\n", ptSpiCfg, ptDevice));

	/* no flash detected yet */
	ptDeviceAttr = NULL;

	/* get device */
	ptSpiDev = &ptDevice->tSpiDev;


	
#if ASIC_TYP==500 || ASIC_TYP==100
	switch( ptSpiCfg->uiUnit )
	{
	case 0:
		ptSpiDev->ptUnit = ptSpiArea;
		iResult = boot_drv_spi_init(ptSpiDev, ptSpiCfg);
		break;

	default:
		iResult = -1;
		break;
	}
#elif ASIC_TYP==50
	switch( ptSpiCfg->uiUnit )
	{
	case 0:
		ptSpiDev->ptUnit = ptSpi0Area;
		iResult = boot_drv_spi_init(ptSpiDev, ptSpiCfg);
		break;
		
	/* This is the only configuration which has been tested.
		bus 2 (SPI/ATMega)  unit 1  cs 0/1  */
	case 1:
		ptSpiDev->ptUnit = ptSpi1Area;
		iResult = boot_drv_spi_init(ptSpiDev, ptSpiCfg);
		mmio_activate(aucMmioPinNumbers, sizeof(aucMmioPinNumbers), atMmioValues);
		/* todo: make sure clk is low */
		break;

	default:
		iResult = -1;
		break;
	}
#elif ASIC_TYP==10
	switch( ptSpiCfg->uiUnit )
	{
	case 0:
		iResult = boot_drv_sqi_init(ptSpiDev, ptSpiCfg);
		break;

	case 1:
		ptSpiDev->ptUnit = ptSpiArea;
		iResult = boot_drv_spi_init(ptSpiDev, ptSpiCfg);
		break;

	default:
		iResult = -1;
		break;
	}
#else
	DBG_ERROR_VAL("unknown asic type %d. Forgot to extend this function for a new asic?", ASIC_TYP)
	iResult = -1;
#endif


	if( iResult!=0 )
	{
		DBG_CALL_FAILED_VAL("boot_drv_spi_init", iResult)
	}
	else
	{
		iResult = detect_atmega_type(ptDevice, &ptDeviceAttr);
		if( iResult!=0 )
		{
			DBG_CALL_FAILED_VAL("detect_atmega", iResult)
		}
		else
		{
			/* was a spi flash detected? */
			if(NULL == ptDeviceAttr)
			{
				/* failed to detect flash */
				iResult = -1;
			}
			else
			{
				/* yes, detected spi flash -> copy all attributes */
				memcpy(&ptDevice->tAttributes, ptDeviceAttr, sizeof(SPI_ATMEGA_ATTRIBUTES_T));

				/* set higher speed for the device */
				ptSpiDev->ulSpeed = ptSpiDev->pfnGetDeviceSpeedRepresentation(ptDevice->tAttributes.ulClock);
				ptSpiDev->pfnSetNewSpeed(ptSpiDev, ptSpiDev->ulSpeed);
			}
		}
	}
	DEBUGMSG(ZONE_FUNCTION, ("-Drv_SpiInitializeATMega(): iResult=%d.\n", iResult));
	return iResult;
}


/*************************************************************************
                    detect chip 
*************************************************************************/

/*
 * Try to detect ATMega chip. Fills in device description if successful

typedef struct
{
	BUS_T tSourceTyp;                                 valid
	union
	{
		PARFLASH_CONFIGURATION_T tParFlash;
		SPI_CONFIGURATION_T tSpi;                     valid
	} uSourceParameter;
	DEVICE_DESCRIPTION_T *ptDeviceDescription;        not valid, will be filled if chip is successfully detected
} CMD_PARAMETER_DETECT_T;

 */
 
NETX_CONSOLEAPP_RESULT_T spi_atmega_detect(CMD_PARAMETER_DETECT_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	int iResult;
	
	SPI_CONFIGURATION_T *ptSpi;
	DEVICE_DESCRIPTION_T *ptDeviceDescription;
	SPI_ATMEGA_T *ptATMegaDescription;
	
	ptSpi = &(ptParameter->uSourceParameter.tSpi);
	ptDeviceDescription = ptParameter->ptDeviceDescription;
	ptATMegaDescription = &(ptDeviceDescription->uInfo.tSpiAtmegaInfo);

	
	/* try to detect flash */
	uprintf(". Detecting ATmega on unit %d, cs %d...\n", ptSpi->uiUnit, ptSpi->uiChipSelect);
	ptATMegaDescription->uiSlaveId = ptSpi->uiChipSelect;
	iResult = Drv_SpiInitializeATMega(ptSpi, ptATMegaDescription);
	
	
	if( iResult!=0 )
	{
		/* failed to detect the spi flash */
		uprintf("! failed to detect ATmega!\n");

		/* clear the result data */
		memset(ptDeviceDescription, 0, sizeof(DEVICE_DESCRIPTION_T));

		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}
	else
	{
		uprintf(". ok, found %s\n", ptATMegaDescription->tAttributes.acName);

		spi_atmega_read_fuses(ptATMegaDescription);
		
		/* set the result data */
		ptDeviceDescription->fIsValid = 1;
		ptDeviceDescription->sizThis = sizeof(DEVICE_DESCRIPTION_T);
		ptDeviceDescription->ulVersion = FLASHER_INTERFACE_VERSION;
		ptDeviceDescription->tSourceTyp = BUS_SPI_ATMega;

		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}

	return tResult;
}


/*************************************************************************
                             read from flash
 *************************************************************************/

NETX_CONSOLEAPP_RESULT_T spi_atmega_read_flash(CMD_PARAMETER_READ_T *ptParameter)
{
	/* Expect success. */
	NETX_CONSOLEAPP_RESULT_T tResult = NETX_CONSOLEAPP_RESULT_OK;
	const SPI_ATMEGA_T *ptDevice = &(ptParameter->ptDeviceDescription->uInfo.tSpiAtmegaInfo);
	
	unsigned long ulStartAdr = ptParameter->ulStartAdr;
	unsigned long ulEndAdr = ptParameter->ulEndAdr;
	unsigned long ulDataSize = ulEndAdr - ulStartAdr;
	unsigned char *pucData = ptParameter->pucData;
	unsigned long ulOffset;
	int iResult = 0;

	progress_bar_init(ulEndAdr - ulStartAdr);
	
	/* read data */
	for (ulOffset = 0; ulOffset < ulDataSize && iResult==0 ; ulOffset++)
	{
		iResult = atmega_read_prg_mem_byte(ptDevice, ulStartAdr + ulOffset, pucData + ulOffset);
		progress_bar_set_position(ulOffset);
	}
	
	progress_bar_finalize();
	
	if (iResult == 0) 
	{
		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}
	else
	{
		uprintf("! read error\n");
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}
	
	return tResult;
}


/*************************************************************************
                             write to flash
 *************************************************************************/

NETX_CONSOLEAPP_RESULT_T spi_atmega_write_flash(CMD_PARAMETER_FLASH_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult = NETX_CONSOLEAPP_RESULT_OK;
	int iResult = 0;
	const SPI_ATMEGA_T *ptDevice = &(ptParameter->ptDeviceDescription->uInfo.tSpiAtmegaInfo);
	unsigned long ulFlashPageSizeBytes = ptDevice->tAttributes.ulFlashPageSizeBytes;

	unsigned char *pucData = ptParameter->pucData;
	
	unsigned long ulFlashStartAdr = ptParameter->ulStartAdr;
	unsigned long ulDataByteSize  = ptParameter->ulDataByteSize;
	unsigned long ulFlashEndAdr = ulFlashStartAdr + ulDataByteSize;
	
	unsigned long ulAdr = ulFlashStartAdr - (ulFlashStartAdr % ulFlashPageSizeBytes);
	unsigned long ulFlashPageAdr;
	unsigned long ulBufferByteOffset;
	unsigned char bByte;
	
	uprintf("Range: [0x%08x-0x%08x[\n", ulFlashStartAdr, ulFlashEndAdr);
	progress_bar_init(ulDataByteSize);

	while (ulAdr < ulFlashEndAdr)
	{
		ulFlashPageAdr = ulAdr;
		DEBUGMSG(ZONE_VERBOSE, ("Page: 0x%08x\n", ulFlashPageAdr));
		
		if ((ulAdr >= ulFlashStartAdr) && (ulAdr < ulFlashEndAdr)) 
		{
			progress_bar_set_position(ulFlashPageAdr-ulFlashStartAdr);
		}
		
		/* Fill the page buffer.
		   For addresses outside [start, end[ use the data currently in the flash. 
		*/
		for (ulBufferByteOffset = 0; ulBufferByteOffset < ulFlashPageSizeBytes; ++ulBufferByteOffset)
		{
			if ((ulAdr >= ulFlashStartAdr) && (ulAdr < ulFlashEndAdr)) 
			{
				bByte = *pucData;
				++pucData;
			}
			else
			{
				iResult = atmega_read_prg_mem_byte(ptDevice, ulAdr, &bByte);
				if (iResult != 0)
				{
					uprintf("Failed to read byte.\n");
					break;
				}
			}
			
			DEBUGMSG(ZONE_VERBOSE, ("ulAdr: 0x%08x  byte: 0x%02x\n", ulAdr, bByte));
			
			/* write to page buffer */
			iResult = atmega_load_prg_mem_page_byte(ptDevice, ulBufferByteOffset, bByte);
			if (iResult != 0)
			{
				uprintf("Failed to write byte to page buffer.\n");
				break;
			}
			++ulAdr;
		}
		
		
		/* Write the page */
		if (iResult == 0)
		{
			DEBUGMSG(ZONE_VERBOSE, ("writing page\n"));
			iResult = atmega_write_prg_mem_page(ptDevice, (unsigned short) (ulFlashPageAdr>>1));
			/* delay */
			delay_us(ptDevice->tAttributes.uitWD_flash);
			
			if (iResult == 0)
			{
				DEBUGMSG(ZONE_VERBOSE, ("Page written\n"));
			}
			else
			{
				uprintf("Failed to write page\n");
				break;
			}
		}
	}
	
	progress_bar_finalize();
	if (iResult == 0)
	{
		uprintf("Flash write succeeded!\n");
		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}
	else
	{
		uprintf("Flash write failed!\n");
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}
	return tResult;
}

/*************************************************************************
                         verify/compare with flash
 *************************************************************************/

NETX_CONSOLEAPP_RESULT_T spi_atmega_verify_flash(CMD_PARAMETER_VERIFY_T *ptParameter, NETX_CONSOLEAPP_PARAMETER_T *ptConsoleParams)
{
	/* Expect success. */
	NETX_CONSOLEAPP_RESULT_T tResult = NETX_CONSOLEAPP_RESULT_OK;
	const SPI_ATMEGA_T *ptDevice = &(ptParameter->ptDeviceDescription->uInfo.tSpiAtmegaInfo);
	
	unsigned long ulStartAdr = ptParameter->ulStartAdr;
	unsigned long ulEndAdr = ptParameter->ulEndAdr;
	unsigned long ulDataSize = ulEndAdr - ulStartAdr;
	unsigned char *pucData = ptParameter->pucData;
	unsigned char bByte = 0;
	int iResult = 0;
	int fEqual = 1;
	unsigned long ulOffset;
	
	progress_bar_init(ulEndAdr - ulStartAdr);
	
	/* read data */
	for (ulOffset = 0; ulOffset < ulDataSize; ulOffset++)
	{
		iResult = atmega_read_prg_mem_byte(ptDevice, ulStartAdr + ulOffset, &bByte);
		progress_bar_set_position(ulOffset);
		
		if (iResult!=0)
		{
			break;
		}
		
		if (bByte != pucData[ulOffset])
		{
			uprintf("Difference found at address 0x%08x offset 0x%08x: flash=0x%02x data=0x%02x\n",
			ulStartAdr + ulOffset, ulOffset, bByte, pucData[ulOffset]);
			fEqual = 0;
			break;
		}		
	}
	
	progress_bar_finalize();
	
	if (iResult == 0) 
	{
		if (fEqual)
		{
			uprintf("Flash contents are equal\n");
		}
		ptConsoleParams->pvReturnMessage = fEqual?(void*)NETX_CONSOLEAPP_RESULT_OK:(void*)NETX_CONSOLEAPP_RESULT_ERROR;
		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}
	else
	{
		uprintf("! read error\n");
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}
	
	return tResult;
}


/*************************************************************************
                            chip erase
 *************************************************************************/

NETX_CONSOLEAPP_RESULT_T spi_atmega_chip_erase(CMD_PARAMETER_ERASE_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult = NETX_CONSOLEAPP_RESULT_OK;
	const SPI_ATMEGA_T *ptDevice = &(ptParameter->ptDeviceDescription->uInfo.tSpiAtmegaInfo);
	int iResult;
	
	iResult = atmega_chip_erase(ptDevice);
	/* delay */
	delay_us(ptDevice->tAttributes.uitWD_erase);

	if (iResult == 0)
	{
		uprintf("Erase succeeded!\n");
		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}
	else
	{
		uprintf("Erase failed!\n");
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}
	return tResult;

}

/*************************************************************************
                           read fuses and lock bits
 *************************************************************************/

/* read fuse and lock bits */
NETX_CONSOLEAPP_RESULT_T spi_atmega_read_fuses(SPI_ATMEGA_T *ptDevice)
{
	NETX_CONSOLEAPP_RESULT_T tResult = NETX_CONSOLEAPP_RESULT_OK;

	int iResult;
	unsigned char ucLockBits;
	unsigned char ucFuseBits;
	unsigned char ucFuseBitsHigh;
	unsigned char ucExtendedFuseBits;
	
	iResult = atmega_read_lock_bits(ptDevice, &ucLockBits);
	if (iResult == 0)
	{
		uprintf("Lock bits = 0x%02x\n", ucLockBits);
	}
	else
	{
		uprintf("Failed to read Lock bits\n");
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}
	
	iResult = atmega_read_fuse_bits(ptDevice, &ucFuseBits);
	if (iResult == 0)
	{
		uprintf("Fuse bits = 0x%02x\n", ucFuseBits);
	}
	else
	{
		uprintf("Failed to read Fuse bits\n");
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}
	
	iResult = atmega_read_fuse_high_bits(ptDevice, &ucFuseBitsHigh);
	if (iResult == 0)
	{
		uprintf("Fuse High bits = 0x%02x\n", ucFuseBitsHigh);
	}
	else
	{
		uprintf("Failed to read Fuse Gigh bits\n");
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}

	iResult = atmega_read_extended_fuse_bits(ptDevice, &ucExtendedFuseBits);
	if (iResult == 0)
	{
		uprintf("Extended Fuse bits = 0x%02x\n", ucExtendedFuseBits);
	}
	else
	{
		uprintf("Failed to read Extended Fuse bits\n");
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}
	
	return tResult;
}

/*************************************************************************
                        write fuse and lock bits
 *************************************************************************/

NETX_CONSOLEAPP_RESULT_T spi_atmega_write_fuse_bits(CMD_PARAMETER_FUSES_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult = NETX_CONSOLEAPP_RESULT_OK;
	const SPI_ATMEGA_T *ptDevice = &(ptParameter->ptDeviceDescription->uInfo.tSpiAtmegaInfo);
	int iResult = 0;
	
	if (ptParameter->ucFuseBitsLowFlag)
	{
		uprintf("Setting Fuse Low bits to 0x%02x\n", ptParameter->ucFuseBitsLowVal);
		iResult = atmega_write_fuse_bits(ptDevice, ptParameter->ucFuseBitsLowVal);
		delay_us(ptDevice->tAttributes.uitWD_fuse);
	}
	
	if ((ptParameter->ucFuseBitsHighFlag) && (iResult==0))
	{
		uprintf("Setting Fuse High bits to 0x%02x\n", ptParameter->ucFuseBitsHighVal);
		iResult = atmega_write_fuse_high_bits(ptDevice, ptParameter->ucFuseBitsHighVal);
		delay_us(ptDevice->tAttributes.uitWD_fuse);
	}
	
	if ((ptParameter->ucFuseBitsExtFlag) && (iResult==0))
	{
		uprintf("Setting Extended Fuse bits to 0x%02x\n", ptParameter->ucFuseBitsExtVal);
		iResult = atmega_write_extended_fuse_bits(ptDevice, ptParameter->ucFuseBitsExtVal);
		delay_us(ptDevice->tAttributes.uitWD_fuse);
	}

	if (iResult == 0)
	{
		uprintf("Fuse bits successfully set\n");
		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}
	else
	{
		uprintf("Error setting fuse bits!\n");
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}
	return tResult;
}

NETX_CONSOLEAPP_RESULT_T spi_atmega_write_lock_bits(CMD_PARAMETER_LOCK_BITS_T *ptParameter)
{
	NETX_CONSOLEAPP_RESULT_T tResult = NETX_CONSOLEAPP_RESULT_OK;
	const SPI_ATMEGA_T *ptDevice = &(ptParameter->ptDeviceDescription->uInfo.tSpiAtmegaInfo);
	int iResult;
	
	uprintf("Setting Lock bits to 0x%02x\n", ptParameter->ucLockBitsVal);
	iResult = atmega_write_lock_bits(ptDevice, ptParameter->ucLockBitsVal);
	delay_us(ptDevice->tAttributes.uitWD_fuse);
	
	if (iResult == 0)
	{
		uprintf("Lock bits successfully set\n");
		tResult = NETX_CONSOLEAPP_RESULT_OK;
	}
	else
	{
		uprintf("Error setting lock bits!\n");
		tResult = NETX_CONSOLEAPP_RESULT_ERROR;
	}
	return tResult;
}

