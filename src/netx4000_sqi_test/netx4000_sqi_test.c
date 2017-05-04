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

#include "flasher_version.h"
#include "netx_consoleapp.h"
#include "rdy_run.h"
#include "uprintf.h"
#include "systime.h"
#include "netx4000_sqi_test.h"
#include "sqitest_interface.h"
#include "boot_drv_sqi.h"
/* ------------------------------------- */

void hexdump_mini(const unsigned char* pucData, size_t sizData);
void hexdump1(const unsigned char* pucData, size_t sizData, size_t sizBytesPerLine);
int check_response(unsigned char *pucResponse, const unsigned char *pucDatasheet, size_t sizLen, const char *pcName);

int sqi_init(SPI_CONFIGURATION_T *ptSpiCnf, SPI_CFG_T *ptSqiCfg);

int sqi_test(SPI_CFG_T *ptSqiCfg, SQITEST_PARAM_T *ptParam);

/* generic SQI command exchange:
   Send a number of bytes, a number of dummy bytes and receive a number of bytes. */
void sqi_command(SPI_CFG_T *ptSqiCfg, 
	const unsigned char *pucCmd, size_t sizCmdSize, 
	size_t sizDummyBytes, 
	unsigned char *pucResp, size_t sizResp);

/* Send a command byte followed by a 3-byte addres, send dummy bytes (optional), receive bytes */
void sqi_cmd_addr_response(SPI_CFG_T *ptSqiCfg, 
	const unsigned char ucCmd, unsigned long ulAddr, 
	size_t sizDummyBytes, 
	unsigned char *pucResp, size_t sizResp);

/* send the command, switch to 2 bit mode, 
   send address and dummy bytes,
   receive response, switch to 1 bit mode. */
int sqi_2io_cmd_addr_response(SPI_CFG_T *ptSqiCfg, 
	const unsigned char ucCmd, unsigned long ulAddr, size_t sizDummyBytes, 
	unsigned char *pucResp, size_t sizResp);

/* Send a command byte, send dummy bytes (optional), receive bytes */
void sqi_cmd_response(SPI_CFG_T *ptSqiCfg, 
	const unsigned char ucCmd, 
	size_t sizDummyBytes, 
	unsigned char *pucResp, size_t sizResp);

/* Send a command byte. */
void sqi_cmd(SPI_CFG_T *ptSqiCfg, const unsigned char ucCmd);

/* Send command to enter QPI mode and setup interface for 4 bit mode. */
int set_1bit(SPI_CFG_T *ptSqiCfg);

/* Send command to exit QPI mode and setup interface for 1 bit mode. */
int set_4bit(SPI_CFG_T *ptSqiCfg);



void hexdump_mini(const unsigned char* pucData, size_t sizData)
{
	unsigned int i;
	for (i=0; i<sizData; i++)
	{
		uprintf("%02x ", pucData[i]);
	}
}

/* not used */
void hexdump1(const unsigned char* pucData, size_t sizData, size_t sizBytesPerLine)
{
	unsigned int i;
	size_t sizByteCnt;
	
	sizByteCnt = 0;
	for (i=0; i<sizData; i++)
	{
		uprintf("%02x ", pucData[i]);
		
		sizByteCnt++;
		if (sizByteCnt==sizBytesPerLine)
		{
			sizByteCnt = 0;
			uprintf("\n");
		}
	}
	
	if (sizByteCnt!= 0)
	{
		sizByteCnt = 0;
		uprintf("\n");
	}
}

/*
	boot_drv_sqi_init_b   status 0/-1
	pfnSetBusWidth        status 0/-1
	pfnSelect             no return value
	pfnSendData           always returns status 0
	pfnReceiveData        always returns status 0
	pfnSendDummy          always returns status 0
	
	transaction types: 
	command code, response data (RDID, RES)
	command code, no response (QPI enable/disable)
*/

void sqi_command(SPI_CFG_T *ptSqiCfg, 
	const unsigned char *pucCmd, size_t sizCmd, size_t sizDummyBytes, 
	unsigned char *pucResp, size_t sizResp)
{
	ptSqiCfg->pfnSelect(ptSqiCfg, 1);
	if ((pucCmd!=NULL) && (sizCmd>0))
	{
		uprintf("Cmd: ");
		hexdump_mini(pucCmd, sizCmd);
		uprintf("  ");
		ptSqiCfg->pfnSendData(ptSqiCfg, pucCmd, sizCmd);
	}
	
	if (sizDummyBytes != 0)
	{
		//ptSqiCfg->pfnSendDummy(ptSqiCfg, sizDummyBytes);
		ptSqiCfg->pfnSendIdleCycles(ptSqiCfg, sizDummyBytes*8);
	}
	
	if ((pucResp!=NULL) && (sizResp>0))
	{
		ptSqiCfg->pfnReceiveData(ptSqiCfg, pucResp, sizResp);
		uprintf("  Response: ");
		hexdump_mini(pucResp, sizResp);
	}
	
	ptSqiCfg->pfnSelect(ptSqiCfg, 0);
	uprintf("\n");
}


int sqi_2io_cmd_addr_response(SPI_CFG_T *ptSqiCfg, 
	const unsigned char ucCmd, unsigned long u24Addr, size_t sizDummyCycles, 
	unsigned char *pucResp, size_t sizResp)
{
	int iRes;
	unsigned char aucAddr[3];
	size_t sizDump;
	
	sizDump = sizResp;
	if (sizDump > 64) 
	{
		sizDump = 64;
	}
	
	aucAddr[0] = (unsigned char) ((u24Addr >> 16)& 0xffUL);
	aucAddr[1] = (unsigned char) ((u24Addr >> 8) & 0xffUL);
	aucAddr[2] = (unsigned char) (u24Addr & 0xffUL);
	
	ptSqiCfg->pfnSelect(ptSqiCfg, 1);
	
	uprintf("Cmd: 0x%08x address: 0x%08x ", ucCmd, u24Addr);
	ptSqiCfg->pfnSendData(ptSqiCfg, &ucCmd, 1);
	uprintf("\n");
	
	uprintf("Setting bus width to 2 bits\n");
	iRes = ptSqiCfg->pfnSetBusWidth(ptSqiCfg, SPI_BUS_WIDTH_2BIT);
	uprintf("Result: %d\n", iRes);
	
	if (iRes == 0)
	{
		ptSqiCfg->pfnSendData(ptSqiCfg, aucAddr, 3);
		
		if (sizDummyCycles != 0)
		{
			//ptSqiCfg->pfnSendDummy(ptSqiCfg, sizDummyBytes);
			ptSqiCfg->pfnSendIdleCycles(ptSqiCfg, sizDummyCycles*4);
		}
		
		ptSqiCfg->pfnReceiveData(ptSqiCfg, pucResp, sizResp);
		uprintf("  Response: ");
		hexdump_mini(pucResp, sizDump);
		if (sizDump<sizResp)
		{
			uprintf("<truncated>");
		}
		uprintf("\n");
		
		ptSqiCfg->pfnSelect(ptSqiCfg, 0);
		
		uprintf("Setting bus width to 1 bit\n");
		iRes = ptSqiCfg->pfnSetBusWidth(ptSqiCfg, SPI_BUS_WIDTH_1BIT);
		uprintf("Result: %d\n", iRes);
		
		uprintf("\n");
	}
	
	return iRes;
}


void sqi_cmd_addr_response(SPI_CFG_T *ptSqiCfg, 
	const unsigned char ucCmd, unsigned long u24Addr, size_t sizDummyBytes, 
	unsigned char *pucResp, size_t sizResp)
{
	unsigned char aucCmd[4];
	uprintf("Cmd: 0x%02x address: 0x%08x  ", ucCmd, u24Addr);
	aucCmd[0] = ucCmd;
	aucCmd[1] = (unsigned char) ((u24Addr >> 16)& 0xffUL);
	aucCmd[2] = (unsigned char) ((u24Addr >> 8) & 0xffUL);
	aucCmd[3] = (unsigned char) (u24Addr & 0xffUL);
	sqi_command(ptSqiCfg, &aucCmd[0], sizeof(aucCmd), sizDummyBytes, pucResp, sizResp);
}


void sqi_cmd_response(SPI_CFG_T *ptSqiCfg, 
	const unsigned char ucCmd, size_t sizDummyBytes, 
	unsigned char *pucResp, size_t sizResp)
{
	unsigned char aucCmd[1];
	aucCmd[0] = ucCmd;
	sqi_command(ptSqiCfg, &aucCmd[0], sizeof(aucCmd), sizDummyBytes, pucResp, sizResp);
}

void sqi_cmd(SPI_CFG_T *ptSqiCfg, const unsigned char ucCmd)
{
	unsigned char aucCmd;
	aucCmd = ucCmd;
	sqi_command(ptSqiCfg, &aucCmd, sizeof(aucCmd), 0, NULL, 0);
}


int set_4bit(SPI_CFG_T *ptSqiCfg)
{
	int iRes;
	uprintf("Enable QPI (1-bit) ");
	sqi_cmd(ptSqiCfg, 0x35);
	uprintf("Setting bus width to 4 bits\n");
	iRes = ptSqiCfg->pfnSetBusWidth(ptSqiCfg, SPI_BUS_WIDTH_4BIT);
	uprintf("Result: %d\n", iRes);
	return iRes;
}

int set_1bit(SPI_CFG_T *ptSqiCfg)
{
	int iRes;
	uprintf("Disable QPI (4-bit) ");
	sqi_cmd(ptSqiCfg, 0xf5);
	uprintf("Setting bus width to 1 bit\n");
	iRes = ptSqiCfg->pfnSetBusWidth(ptSqiCfg, SPI_BUS_WIDTH_1BIT);
	uprintf("Result: %d\n", iRes);
	return iRes;
}

/* Initialize/Configure SQI interface according to the settings in ptSpiCnf.

	ptSpiCnf [in]
	ptSqiCfg [out]
*/
int sqi_init(SPI_CONFIGURATION_T *ptSpiCnf, SPI_CFG_T *ptSqiCfg)
{
	int iRes;
	unsigned int uiUnit;
	unsigned int uiChipSelect;
	BOOT_SPI_CONFIGURATION_T tBootSpiCnf; 
	
	tBootSpiCnf.ulInitialSpeedKhz = ptSpiCnf->ulInitialSpeedKhz;
	tBootSpiCnf.ucDummyByte = 0xffU; /* todo: check */
	tBootSpiCnf.ucMode = (unsigned char) ptSpiCnf->uiMode;
	tBootSpiCnf.ucIdleConfiguration = (unsigned char) ptSpiCnf->uiIdleCfg;
	
	uiUnit = ptSpiCnf->uiUnit;
	uiChipSelect = ptSpiCnf->uiChipSelect;
	
	uprintf("boot_drv_sqi_init_b\n");
	iRes = boot_drv_sqi_init_b(ptSqiCfg, &tBootSpiCnf, uiUnit, uiChipSelect);
	uprintf("Result: %d\n", iRes);
	return iRes;
}


int check_response(unsigned char *pucResponse, const unsigned char *pucDatasheet, size_t sizLen, const char *pcName)
{
	int iRes;
	iRes = memcmp(pucResponse, pucDatasheet, sizLen);
	if (iRes == 0)
	{
		uprintf(pcName);
		uprintf(" OK\n");
	}
	else
	{
		uprintf(pcName);
		uprintf(" NOT OK\n");
	}
	return iRes;
}


/* SFDP responses from the MX25L12835F datasheet.
16/32 bit numbers are assumed to be in little endian notation. */

const unsigned char aucRDID_Response[] = {
	0xc2, 0x20, 0x18
};

const unsigned char aucRES_Response[] = {
	0x17
};

const unsigned char aucSFDP_ID[] = {
	0x53, 0x46, 0x44, 0x50, 0x00, 0x01, 0x01, 0xff,
	0x00, 0x00, 0x01, 0x09, 0x30, 0x00, 0x00, 0xff,
	0xc2, 0x00, 0x01, 0x04, 0x60, 0x00, 0x00, 0xff
};

const unsigned char aucSFDP_Param0[] = {
	0xe5, 0x20, 0xf1, 0xff, 0xff, 0xff, 0xff, 0x07,
	0x44, 0xeb, 0x08, 0x6b, 0x08, 0x3b, 0x04, 0xbb, 
	0xfe, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0xff, 
	0xff, 0xff, 0x44, 0xeb, 0x0c, 0x20, 0x0f, 0x52, 
	0x10, 0xd8, 0x00, 0xff
};

const unsigned char aucSFDP_Param1[] = {
	0x00, 0x36, 0x00, 0x27, 0x9d, 0xf9, 0xc0, 0x64,
	0x85, 0xcb, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
};



/*
SQI test:
  Set bus width to 1 bit
  RDID command 9f
  RES command ab 
  Set bus width to 4 bit
  RES command ab 
  Set bus width to 1 bit
  Read SFDP data
  Set bus width to 4 bit
  Read SFDP data again and compare
  Set bus width to 1 bit
  2xIO (2Read) command bb

*/
int sqi_test(SPI_CFG_T *ptSqiCfg, SQITEST_PARAM_T *ptParam)
{
	int iRes;
	
	unsigned char aucBuffer[1024]; /* general buffer for responses */
	
	/* buffers for SFDP data */
	unsigned char aucRDSFDPResponse1_1[sizeof(aucSFDP_ID)]; 
	unsigned char aucRDSFDPResponse1_2[sizeof(aucSFDP_Param0)]; 
	unsigned char aucRDSFDPResponse1_3[sizeof(aucSFDP_Param1)];
	unsigned char aucRDSFDPResponse4_1[sizeof(aucSFDP_ID)]; 
	unsigned char aucRDSFDPResponse4_2[sizeof(aucSFDP_Param0)]; 
	unsigned char aucRDSFDPResponse4_3[sizeof(aucSFDP_Param1)];
	
	iRes = 0;
	
	if (iRes == 0)
	{
		uprintf("Setting bus width to 1 bit\n");
		iRes = ptSqiCfg->pfnSetBusWidth(ptSqiCfg, SPI_BUS_WIDTH_1BIT);
		uprintf("Result: %d\n", iRes);
		uprintf("\n");
	}
	
	if (iRes == 0)
	{
		uprintf("Read configuration register (RDCR)  ");
		sqi_cmd_response(ptSqiCfg, 0x15, 0, aucBuffer, 1);
		uprintf("\n");
	}
	
	
	if (iRes == 0)
	{
		uprintf("Read device ID (RDID)  ");
		sqi_cmd_response(ptSqiCfg, 0x9f, 0, aucBuffer, sizeof(aucRDID_Response));
		iRes = check_response(aucBuffer, aucRDID_Response, sizeof(aucRDID_Response), "Device ID");
		uprintf("\n");
	}
	
	if (iRes == 0)
	{
		uprintf("Read electronic signature (RES) (1-bit)  ");
		sqi_cmd_response(ptSqiCfg, 0xab, 3, aucBuffer, sizeof(aucRES_Response));
		iRes = check_response(aucBuffer, aucRES_Response, sizeof(aucRES_Response), "Electronic signature");
		uprintf("\n");
	}
	
	if (iRes == 0)
	{
		iRes = set_4bit(ptSqiCfg);
		uprintf("\n");
	}
	
	if (iRes == 0)
	{
		uprintf("Read electronic signature (RES) (4-bit)  ");
		sqi_cmd_response(ptSqiCfg, 0xab, 3, aucBuffer, sizeof(aucRES_Response));
		iRes = check_response(aucBuffer, aucRES_Response, sizeof(aucRES_Response), "Electronic signature");
		uprintf("\n");
	}
	
	if (iRes == 0)
	{
		iRes = set_1bit(ptSqiCfg);
		uprintf("\n");
	}

	if (iRes == 0)
	{
		uprintf("Read SFDP data (1-bit)\n");
		sqi_cmd_addr_response(ptSqiCfg, 0x5a, 0x000000U, 1, aucRDSFDPResponse1_1, sizeof(aucRDSFDPResponse1_1));
		sqi_cmd_addr_response(ptSqiCfg, 0x5a, 0x000030U, 1, aucRDSFDPResponse1_2, sizeof(aucRDSFDPResponse1_2));
		sqi_cmd_addr_response(ptSqiCfg, 0x5a, 0x000060U, 1, aucRDSFDPResponse1_3, sizeof(aucRDSFDPResponse1_3));

		if ((0 == check_response(aucRDSFDPResponse1_1, aucSFDP_ID, sizeof(aucSFDP_ID), "SFDP ID"))
			&& (0 == check_response(aucRDSFDPResponse1_2, aucSFDP_Param0, sizeof(aucSFDP_Param0), "SFDP Jedec Parameters"))
			&& (0 == check_response(aucRDSFDPResponse1_3, aucSFDP_Param1, sizeof(aucSFDP_Param1), "SFDP Macronic Parameters")))
		{
			uprintf("SFDP data is equal to the values in the datasheet.\n");
		}
		else
		{
			uprintf("SFDP data is NOT equal to the values in the datasheet.\n");
			iRes = -1;
		}
		uprintf("\n");
	}
	
	if (iRes == 0)
	{
		iRes = set_4bit(ptSqiCfg);
		uprintf("\n");
	}
	
	if (iRes == 0)
	{
		uprintf("Read SFDP data (4-bit)\n");
		/* No timing diagram for RDSFDP in QPI mode. */
		sqi_cmd_addr_response(ptSqiCfg, 0x5a, 0x000000U, 1, aucRDSFDPResponse4_1, sizeof(aucRDSFDPResponse4_1));
		sqi_cmd_addr_response(ptSqiCfg, 0x5a, 0x000030U, 1, aucRDSFDPResponse4_2, sizeof(aucRDSFDPResponse4_2));
		sqi_cmd_addr_response(ptSqiCfg, 0x5a, 0x000060U, 1, aucRDSFDPResponse4_3, sizeof(aucRDSFDPResponse4_3));
		
		if ((0 == check_response(aucRDSFDPResponse4_1, aucSFDP_ID, sizeof(aucSFDP_ID), "SFDP ID"))
			&& (0 == check_response(aucRDSFDPResponse4_2, aucSFDP_Param0, sizeof(aucSFDP_Param0), "SFDP Jedec Parameters"))
			&& (0 == check_response(aucRDSFDPResponse4_3, aucSFDP_Param1, sizeof(aucSFDP_Param1), "SFDP Macronic Parameters")))
		{
			uprintf("SFDP data is equal to the values in the datasheet.\n");
		}
		else
		{
			uprintf("SFDP data is NOT equal to the values in the datasheet.\n");
			iRes = -1;
		}
		uprintf("\n");
	}
	
	if (iRes == 0)
	{
		iRes = set_1bit(ptSqiCfg);
		uprintf("\n");
	}
	
	
	if (iRes == 0)
	{
		uprintf("2xIO read (2read)  \n");
		uprintf("Start offset in flash: 0x%08x\n", ptParam->ulOffset);
		uprintf("Size:                  0x%08x\n", ptParam->ulSize);
		uprintf("Read data to:          0x%08x\n", ptParam->pucDest);
		uprintf("Compare to data at:    0x%08x\n", ptParam->pucCmpData);
		
		iRes = sqi_2io_cmd_addr_response(ptSqiCfg, 0xbb, ptParam->ulOffset, 1, ptParam->pucDest, ptParam->ulSize);
		
		if (0==memcmp(ptParam->pucDest, ptParam->pucCmpData, ptParam->ulSize))
		{
			uprintf("Equal\n");
		}
		else
		{
			uprintf("NOT EQUAL\n");
			iRes = -1;
		}
		uprintf("\n");
	}
	
	return iRes;
}


NETX_CONSOLEAPP_RESULT_T netx_consoleapp_main(NETX_CONSOLEAPP_PARAMETER_T *ptTestParam)
{
	NETX_CONSOLEAPP_RESULT_T tResult;
	int iResult;
	tFlasherInputParameter *ptAppParams;
	OPERATION_MODE_T tOpMode;
	
	ptAppParams = (tFlasherInputParameter*)ptTestParam->pvInitParams;
	tOpMode = ptAppParams->tOperationMode; 
	tResult=NETX_CONSOLEAPP_RESULT_ERROR;
	iResult=-1;
	
	/* Switch off the SYS led. */
	rdy_run_setLEDs(RDYRUN_OFF);
	
	/* Configure the systime, used by progress functions. */
	systime_init();  

	/* say hi */
	uprintf(
	"\f\n\n\n\nnetx 4000 SQI Test v" FLASHER_VERSION_ALL " " FLASHER_VERSION_VCS "\n\n");
	
	switch(tOpMode)
	{
		case OPERATION_MODE_Sqitest:
		uprintf("SQI Test\n");
		
		SPI_CFG_T tSqiCfg; /* this is filled in by the driver */
		iResult = sqi_init(&(ptAppParams->uParameter.tSqitest.tSpi), &tSqiCfg);
		if (iResult == 0)
		{
			iResult = sqi_test(&tSqiCfg, &(ptAppParams->uParameter.tSqitest.tSqitest_Param));
		}
		
		break;
	}

	if( iResult==0 )
	{
		/*  Operation OK! */
		tResult=NETX_CONSOLEAPP_RESULT_OK;
		uprintf("* OK *\n");
		rdy_run_setLEDs(RDYRUN_GREEN);
	}
	else
	{
		tResult=NETX_CONSOLEAPP_RESULT_ERROR;
		/*  Operation failed. */
		rdy_run_setLEDs(RDYRUN_YELLOW);
	}


	return tResult;
}
