/*---------------------------------------------------------------------------
  Author : Christoph Thelen

           Hilscher GmbH, Copyright (c) 2006, All Rights Reserved

           Redistribution or unauthorized use without expressed written
           agreement from the Hilscher GmbH is forbidden
---------------------------------------------------------------------------*/


#include <string.h>

#include "boot_drv_sqi.h"
//#include "console_io.h"
#include "netx_io_areas.h"
//#include "tools.h"



//#define MAXIMUM_TRANSACTION_SIZE_BYTES 0x80000



static unsigned char qsi_exchange_byte(const SPI_CFG_T *ptCfg, unsigned char uiByte)
{
	HOSTADEF(SQI) * ptSqi;
	unsigned long ulValue;
	unsigned char ucByte;


	ptSqi = (HOSTADEF(SQI) *)(ptCfg->pvArea);

	/* Set mode to "full duplex". */
	ulValue  = ptCfg->ulTrcBase;
	ulValue |= 3 << HOSTSRT(sqi_tcr_duplex);
	/* Start the transfer. */
	ulValue |= HOSTMSK(sqi_tcr_start_transfer);
	ptSqi->ulSqi_tcr = ulValue;

	/* Send byte. */
	ptSqi->ulSqi_dr = uiByte;

	/* Wait for one byte in the FIFO. */
	do
	{
		ulValue  = ptSqi->ulSqi_sr;
		ulValue &= HOSTMSK(sqi_sr_busy);
	} while( ulValue!=0 );

	/* Grab byte. */
	ucByte = (unsigned char)(ptSqi->ulSqi_dr);
	return ucByte;
}

//---------------------------------------------------------------------------


static unsigned long qsi_get_device_speed_representation(unsigned int uiSpeed)
{
	unsigned long ulDevSpeed;
	unsigned long ulInputFilter;


	/* ulSpeed is in kHz. */

	/* Limit speed to upper border. */
	if( uiSpeed>50000 )
	{
		uiSpeed = 50000;
	}

	/* Convert speed to "multiply add value". */
	ulDevSpeed  = uiSpeed * 4096;

	/* NOTE: do not round up here. */
	ulDevSpeed /= 100000;

	/* Use input filtering? */
	ulInputFilter = 0;
	if( ulDevSpeed<=0x0200 )
	{
		ulInputFilter = HOSTMSK(sqi_cr0_filter_in);
	}

	/* Shift to register position. */
	ulDevSpeed <<= HOSTSRT(sqi_cr0_sck_muladd);

	/* Add filter bit. */
	ulDevSpeed |= ulInputFilter;

	return ulDevSpeed;
}



static void qsi_slave_select(const SPI_CFG_T *ptCfg, int fIsSelected)
{
	HOSTADEF(SQI) * ptSqi;
	unsigned long uiChipSelect;
	unsigned long ulValue;


	ptSqi = (HOSTADEF(SQI) *)(ptCfg->pvArea);

	/* Get the chip select value. */
	uiChipSelect  = 0;
	if( fIsSelected!=0 )
	{
		uiChipSelect  = ptCfg->uiChipSelect << HOSTSRT(sqi_cr1_fss);
		uiChipSelect &= HOSTMSK(sqi_cr1_fss);
	}

	/* Get control register contents. */
	ulValue  = ptSqi->aulSqi_cr[1];

	/* Mask out the slave select bits. */
	ulValue &= ~HOSTMSK(sqi_cr1_fss);

	/* Mask in the new slave ID. */
	ulValue |= uiChipSelect;

	/* Write back new value. */
	ptSqi->aulSqi_cr[1] = ulValue;
}



static int qsi_send_idle_cycles(const SPI_CFG_T *ptCfg, size_t sizIdleCycles)
{
	HOSTADEF(SQI) * ptSqi;
	unsigned long ulValue;
	size_t sizChunkTransaction;


	ptSqi = (HOSTADEF(SQI) *)(ptCfg->pvArea);

	while( sizIdleCycles!=0 )
	{
		/* Limit the number of cycles to the maximum transaction size. */
		sizChunkTransaction = sizIdleCycles;
		if( sizChunkTransaction>((HOSTMSK(sqi_tcr_transfer_size)<<HOSTSRT(sqi_tcr_transfer_size))+1U) )
		{
			sizChunkTransaction = ((HOSTMSK(sqi_tcr_transfer_size)<<HOSTSRT(sqi_tcr_transfer_size))+1U);
		}

		/* Set mode to "send dummy". */
		ulValue  = ptCfg->ulTrcBase;
		ulValue |= 0 << HOSTSRT(sqi_tcr_duplex);
		/* Set the transfer size. */
		ulValue |= (sizChunkTransaction-1) << HOSTSRT(sqi_tcr_transfer_size);
		/* Clear the output bits. */
		ulValue &= ~(HOSTMSK(sqi_tcr_tx_oe)|HOSTMSK(sqi_tcr_tx_out));
		/* Start the transfer. */
		ulValue |= HOSTMSK(sqi_tcr_start_transfer);
		ptSqi->ulSqi_tcr = ulValue;

		/* Wait until the transfer is done. */
		do
		{
			ulValue  = ptSqi->ulSqi_sr;
			ulValue &= HOSTMSK(sqi_sr_busy);
		} while( ulValue!=0 );

		sizIdleCycles -= sizChunkTransaction;
	}

	return 0;
}



static int qsi_send_dummy(const SPI_CFG_T *ptCfg, size_t sizDummyBytes)
{
	HOSTADEF(SQI) * ptSqi;
	unsigned long ulValue;
	size_t sizChunkTransaction;
	size_t sizChunkFifo;
	unsigned char ucDummyByte;


	ptSqi = (HOSTADEF(SQI) *)(ptCfg->pvArea);
	ucDummyByte = ptCfg->ucDummyByte;

	while( sizDummyBytes!=0 )
	{
		/* Limit the number of bytes by the maximum transaction size. */
		sizChunkTransaction = sizDummyBytes;
		if( sizChunkTransaction>((HOSTMSK(sqi_tcr_transfer_size)<<HOSTSRT(sqi_tcr_transfer_size))+1U) )
		{
			sizChunkTransaction = ((HOSTMSK(sqi_tcr_transfer_size)<<HOSTSRT(sqi_tcr_transfer_size))+1U);
		}
		sizDummyBytes -= sizChunkTransaction;

		/* Set the mode to "send". */
		ulValue  = ptCfg->ulTrcBase;
		ulValue |= 2 << HOSTSRT(sqi_tcr_duplex);
		/* Set the transfer size. */
		ulValue |= (sizChunkTransaction - 1U) << HOSTSRT(sqi_tcr_transfer_size);
		/* Start the transfer. */
		ulValue |= HOSTMSK(sqi_tcr_start_transfer);
		ptSqi->ulSqi_tcr = ulValue;

		/* Check the mode. */
		ulValue  = ptCfg->ulTrcBase;
		ulValue &= HOSTMSK(sqi_tcr_mode);
		if( ulValue==0 )
		{
			/* Mode 0 : the FIFO size is 8 bit. */
			while( sizChunkTransaction!=0 )
			{
				ulValue   = ptSqi->ulSqi_sr;
				ulValue  &= HOSTMSK(spi_sr_tx_fifo_level);
				ulValue >>= HOSTSRT(spi_sr_tx_fifo_level);
				/* The FIFO has 16 entries. Get the number of free entries from the fill level. */
				ulValue = 16 - ulValue;

				/* Try to fill up the complete FIFO... */
				sizChunkFifo = ulValue;
				/* .. but limit this by the number of bytes left to send. */
				if( sizChunkFifo>sizChunkTransaction )
				{
					sizChunkFifo = sizChunkTransaction;
				}

				sizChunkTransaction -= sizChunkFifo;
				while( sizChunkFifo!=0 )
				{
					/* Send byte */
					ptSqi->ulSqi_dr = (unsigned long)ucDummyByte;
					--sizChunkFifo;
				}
			}
		}
		else
		{
			/* DSI/QSI mode : the FIFO size is 32 bit */
			do
			{
				/* collect a DWORD */
				sizChunkFifo = 4;
				if( sizChunkFifo>sizChunkTransaction )
				{
					sizChunkFifo = sizChunkTransaction;
				}
				sizChunkTransaction -= sizChunkFifo;

				/* wait for space in the FIFO */
				do
				{
					ulValue  = ptSqi->ulSqi_sr;
					ulValue &= HOSTMSK(sqi_sr_rx_fifo_full);
				} while( ulValue!=0 );

				/* send DWORD */
				ulValue  =  (unsigned long)ucDummyByte;
				ulValue |= ((unsigned long)ucDummyByte) <<  8U;
				ulValue |= ((unsigned long)ucDummyByte) << 16U;
				ulValue |= ((unsigned long)ucDummyByte) << 24U;
				ptSqi->ulSqi_dr = ulValue;
			} while( sizChunkTransaction!=0 );
		}

		/* wait until the transfer is done */
		do
		{
			ulValue  = ptSqi->ulSqi_sr;
			ulValue &= HOSTMSK(sqi_sr_busy);
		} while( ulValue!=0 );
	}

	return 0;
}



static int qsi_send_data(const SPI_CFG_T *ptCfg, const unsigned char *pucData, size_t sizData)
{
	HOSTADEF(SQI) * ptSqi;
	unsigned long ulValue;
	unsigned int uiShiftCnt;
	unsigned long ulSend;
	size_t sizChunkTransaction;
	size_t sizChunkFifo;


	ptSqi = (HOSTADEF(SQI) *)(ptCfg->pvArea);

	while( sizData!=0 )
	{
		/* Limit the number of bytes by the maximum transaction size. */
		sizChunkTransaction = sizData;
		if( sizChunkTransaction>((HOSTMSK(sqi_tcr_transfer_size)<<HOSTSRT(sqi_tcr_transfer_size))+1U) )
		{
			sizChunkTransaction = ((HOSTMSK(sqi_tcr_transfer_size)<<HOSTSRT(sqi_tcr_transfer_size))+1U);
		}
		sizData -= sizChunkTransaction;

		/* Set the mode to "send". */
		ulValue  = ptCfg->ulTrcBase;
		ulValue |= 2 << HOSTSRT(sqi_tcr_duplex);
		/* Set the transfer size. */
		ulValue |= (sizChunkTransaction - 1U) << HOSTSRT(sqi_tcr_transfer_size);
		/* Start the transfer. */
		ulValue |= HOSTMSK(sqi_tcr_start_transfer);
		ptSqi->ulSqi_tcr = ulValue;

		/* Check the mode. */
		ulValue  = ptCfg->ulTrcBase;
		ulValue &= HOSTMSK(sqi_tcr_mode);
		if( ulValue==0 )
		{
			/* Mode 0 : the FIFO size is 8 bit. */
			while( sizChunkTransaction!=0 )
			{
				ulValue   = ptSqi->ulSqi_sr;
				ulValue  &= HOSTMSK(spi_sr_tx_fifo_level);
				ulValue >>= HOSTSRT(spi_sr_tx_fifo_level);
				/* The FIFO has 16 entries. Get the number of free entries from the fill level. */
				ulValue = 16 - ulValue;

				/* Try to fill up the complete FIFO... */
				sizChunkFifo = ulValue;
				/* .. but limit this by the number of bytes left to send. */
				if( sizChunkFifo>sizChunkTransaction )
				{
					sizChunkFifo = sizChunkTransaction;
				}

				sizChunkTransaction -= sizChunkFifo;
				while( sizChunkFifo!=0 )
				{
					/* Send byte */
					ptSqi->ulSqi_dr = *(pucData++);
					--sizChunkFifo;
				}
			}
		}
		else
		{
			/* DSI/QSI mode : the FIFO size is 32 bit */
			do
			{
				/* collect a DWORD */
				ulSend = 0;
				uiShiftCnt = 0;
				do
				{
					ulSend |= ((unsigned long)(*(pucData++))) << (uiShiftCnt<<3U);
					++uiShiftCnt;
					--sizChunkTransaction;
				} while( sizChunkTransaction!=0 && uiShiftCnt<4 );

				/* wait for space in the FIFO */
				do
				{
					ulValue  = ptSqi->ulSqi_sr;
					ulValue &= HOSTMSK(sqi_sr_rx_fifo_full);
				} while( ulValue!=0 );
				/* send DWORD */
				ptSqi->ulSqi_dr = ulSend;
			} while( sizChunkTransaction!=0 );
		}

		/* wait until the transfer is done */
		do
		{
			ulValue  = ptSqi->ulSqi_sr;
			ulValue &= HOSTMSK(sqi_sr_busy);
		} while( ulValue!=0 );
	}

	return 0;
}



static int qsi_receive_data(const SPI_CFG_T *ptCfg, unsigned char *pucData, size_t sizData /*, int iHashTheData*/)
{
	HOSTADEF(SQI) * ptSqi;
	unsigned long ulValue;
	size_t sizChunkTransaction;
	size_t sizChunkFifo;
	size_t sizBytes;
	unsigned char ucReceivedChar;


	ptSqi = (HOSTADEF(SQI) *)(ptCfg->pvArea);

	while( sizData!=0 )
	{
		/* Limit the number of bytes by the maximum transaction size. */
		sizChunkTransaction = sizData;
		if( sizChunkTransaction>((HOSTMSK(sqi_tcr_transfer_size)<<HOSTSRT(sqi_tcr_transfer_size))+1U) )
		{
			sizChunkTransaction = ((HOSTMSK(sqi_tcr_transfer_size)<<HOSTSRT(sqi_tcr_transfer_size))+1U);
		}
		sizData -= sizChunkTransaction;

		/* Set mode to "receive". */
		ulValue  = ptCfg->ulTrcBase;
		ulValue |= 1 << HOSTSRT(sqi_tcr_duplex);
		/* Set the transfer size. */
		ulValue |= (sizChunkTransaction - 1) << HOSTSRT(sqi_tcr_transfer_size);
		/* Start the transfer. */
		ulValue |= HOSTMSK(sqi_tcr_start_transfer);
		ptSqi->ulSqi_tcr = ulValue;

		/* Check the mode. */
		if( (ptCfg->ulTrcBase&HOSTMSK(sqi_tcr_mode))==0 )
		{
			/* Mode 0 : the FIFO size is 8 bit. */
			while( sizChunkTransaction!=0 )
			{
				/* Get the fill level of the FIFO. */
				ulValue   = ptSqi->ulSqi_sr;
				ulValue  &= HOSTMSK(spi_sr_rx_fifo_level);
				ulValue >>= HOSTSRT(spi_sr_rx_fifo_level);

				/* Limit the chunk by the number of bytes to transfer. */
				sizChunkFifo = ulValue;
				if( sizChunkFifo>sizChunkTransaction )
				{
					sizChunkFifo = sizChunkTransaction;
				}

				sizChunkTransaction -= sizChunkFifo;
				while( sizChunkFifo!=0 )
				{
					/* Grab a byte. */
					ucReceivedChar = (unsigned char)(ptSqi->ulSqi_dr & 0xffU);
					*(pucData++) = ucReceivedChar;
					//if( iHashTheData!=0 )
					//{
					//	/* Add the byte to the running hash. */
					//	sha384_update_uc(ucReceivedChar);
					//}

					--sizChunkFifo;
				}
			}
		}
		else
		{
			/* DSI/QSI mode : the FIFO size is 32 bit. */
			while( sizChunkTransaction!=0 )
			{
				/* Get the fill level of the FIFO. */
				ulValue   = ptSqi->ulSqi_sr;
				ulValue  &= HOSTMSK(spi_sr_rx_fifo_level);
				ulValue >>= HOSTSRT(spi_sr_rx_fifo_level);

				/* Limit the chunk by the number of bytes to transfer. */
				sizChunkFifo = ulValue * sizeof(unsigned long);
				if( sizChunkFifo>sizChunkTransaction )
				{
					sizChunkFifo = sizChunkTransaction;
				}

				sizChunkTransaction -= sizChunkFifo;
				while( sizChunkFifo!=0 )
				{
					/* Get the DWORD. */
					ulValue = ptSqi->ulSqi_dr;

					sizBytes = 4;
					if( sizBytes>sizChunkFifo )
					{
						sizBytes = sizChunkFifo;
					}

					sizChunkFifo -= sizBytes;
					while( sizBytes!=0 )
					{
						ucReceivedChar = (unsigned char)(ulValue & 0xffU);
						*(pucData++) = ucReceivedChar;
						//if( iHashTheData!=0 )
						//{
						//	sha384_update_uc(ucReceivedChar);
						//}
						ulValue >>= 8U;

						--sizBytes;
					}
				}
			}
		}
	}

	return 0;
}



static int qsi_exchange_data(const SPI_CFG_T *ptCfg, unsigned char *pucData, size_t sizData /*, int iHashTheData*/)
{
	HOSTADEF(SQI) * ptSqi;
	int iResult;
	unsigned long ulValue;
	size_t sizChunkTransaction;
	size_t sizChunkFifo;
	unsigned char *pucDataRx;
	unsigned char *pucDataTx;
	size_t sizDataRx;
	size_t sizDataTx;
	unsigned char ucReceivedChar;


	/* Be optimistic. */
	iResult = 0;

	/* Exchanging data works only in 1bit full-duplex mode. */
	if( (ptCfg->ulTrcBase&HOSTMSK(sqi_tcr_mode))!=0 )
	{
		//trace_message(TRACEMSG_BootDrvSqi_InvalidBusWidthForExchangeData);
		iResult = -1;
	}
	else
	{
		ptSqi = (HOSTADEF(SQI) *)(ptCfg->pvArea);

		pucDataRx = pucData;
		pucDataTx = pucData;

		while( sizData!=0 )
		{
			/* Limit the number of bytes by the maximum transaction size. */
			sizChunkTransaction = sizData;
			if( sizChunkTransaction>((HOSTMSK(sqi_tcr_transfer_size)<<HOSTSRT(sqi_tcr_transfer_size))+1U) )
			{
				sizChunkTransaction = ((HOSTMSK(sqi_tcr_transfer_size)<<HOSTSRT(sqi_tcr_transfer_size))+1U);
			}
			sizData -= sizChunkTransaction;

			/* Set mode to "send and receive". */
			ulValue  = ptCfg->ulTrcBase;
			ulValue |= 3 << HOSTSRT(sqi_tcr_duplex);
			/* Set the transfer size. */
			ulValue |= (sizChunkTransaction - 1U) << HOSTSRT(sqi_tcr_transfer_size);
			/* Start the transfer. */
			ulValue |= HOSTMSK(sqi_tcr_start_transfer);
			ptSqi->ulSqi_tcr = ulValue;

			/* The requested amount of data must be send and received. */
			sizDataRx = sizChunkTransaction;
			sizDataTx = sizChunkTransaction;

			/* Mode 0 : the FIFO size is 8 bit. */
			do
			{
				/*
				 * Send data.
				 */
				/* Get the fill level of the transmit FIFO. */
				ulValue   = ptSqi->ulSqi_sr;
				ulValue  &= HOSTMSK(spi_sr_tx_fifo_level);
				ulValue >>= HOSTSRT(spi_sr_tx_fifo_level);
				/* The FIFO has 16 entries. Get the number of free entries from the fill level. */
				ulValue = 16U - ulValue;

				/* Try to fill up the complete FIFO... */
				sizChunkFifo = ulValue;
				/* .. but limit this by the number of bytes left to send. */
				if( sizChunkFifo>sizDataTx )
				{
					sizChunkFifo = sizDataTx;
				}

				sizDataTx -= sizChunkFifo;
				while( sizChunkFifo!=0 )
				{
					/* Send byte */
					ptSqi->ulSqi_dr = *(pucDataTx++);
					--sizChunkFifo;
				}


				/*
				 * Receive data.
				 */
				/* Get the fill level of the receive FIFO. */
				ulValue   = ptSqi->ulSqi_sr;
				ulValue  &= HOSTMSK(spi_sr_rx_fifo_level);
				ulValue >>= HOSTSRT(spi_sr_rx_fifo_level);

				/* Limit the chunk by the number of bytes to transfer. */
				sizChunkFifo = ulValue;
				if( sizChunkFifo>sizDataRx )
				{
					sizChunkFifo = sizDataRx;
				}

				sizDataRx -= sizChunkFifo;
				while( sizChunkFifo!=0 )
				{
					/* Grab a byte. */
					ucReceivedChar = (unsigned char)(ptSqi->ulSqi_dr & 0xffU);
					*(pucDataRx++) = ucReceivedChar;
					//if( iHashTheData!=0 )
					//{
					//	/* Add the byte to the running hash. */
					//	sha384_update_uc(ucReceivedChar);
					//}

					--sizChunkFifo;
				}
			} while( (sizDataRx | sizDataTx)!=0 );
		}
	}

	return iResult;
}



static int qsi_set_new_speed(const SPI_CFG_T *ptCfg, unsigned long ulDeviceSpecificSpeed)
{
	HOSTADEF(SQI) * ptSqi;
	int iResult;
	unsigned long ulValue;


	ptSqi = (HOSTADEF(SQI) *)(ptCfg->pvArea);

	/* Expect error. */
	iResult = 1;

	/* All irrelevant bits must be 0. */
	if( (ulDeviceSpecificSpeed&(~(HOSTMSK(sqi_cr0_sck_muladd)|HOSTMSK(sqi_cr0_filter_in))))!=0 )
	{
		//trace_message_ul(TRACEMSG_BootDrvSqi_InvalidNewSpeed, ulDeviceSpecificSpeed);
	}
	else if( ulDeviceSpecificSpeed==0 )
	{
		//trace_message_ul(TRACEMSG_BootDrvSqi_InvalidNewSpeed, ulDeviceSpecificSpeed);
	}
	else
	{
		//trace_message_ul(TRACEMSG_BootDrvSqi_NewSpeed, ulDeviceSpecificSpeed);

		ulValue  = ptSqi->aulSqi_cr[0];
		ulValue &= ~(HOSTMSK(sqi_cr0_sck_muladd)|HOSTMSK(sqi_cr0_filter_in));
		ulValue |= ulDeviceSpecificSpeed;
		ptSqi->aulSqi_cr[0] = ulValue;

		/* All OK! */
		iResult = 0;
	}

	return iResult;
}





static int qsi_set_bus_width(SPI_CFG_T *ptCfg, SPI_BUS_WIDTH_T tBusWidth)
{
	HOSTADEF(SQI) * ptSqi;
	int iResult;
	unsigned long ulTcrMode;
	unsigned long ulSioCfg;
	unsigned long ulValue;


	ptSqi = (HOSTADEF(SQI) *)(ptCfg->pvArea);

	iResult = -1;
	switch(tBusWidth)
	{
	case SPI_BUS_WIDTH_1BIT:
		ulTcrMode = 0;
		ulSioCfg = 0;
		iResult = 0;
		break;

	case SPI_BUS_WIDTH_2BIT:
		ulTcrMode = 1;
		ulSioCfg = 0;
		iResult = 0;
		break;

	case SPI_BUS_WIDTH_4BIT:
		ulTcrMode = 2;
		ulSioCfg = 1;
		iResult = 0;
		break;
	}

	if( iResult==0 )
	{
		//trace_message_uc(TRACEMSG_BootDrvSqi_NewBusWidth, (unsigned char)tBusWidth);

		/* Set the new SIO configuration. */
		ulValue  = ptSqi->aulSqi_cr[0];
		ulValue &= ~HOSTMSK(sqi_cr0_sio_cfg);
		ulValue |= ulSioCfg << HOSTSRT(sqi_cr0_sio_cfg);
		ptSqi->aulSqi_cr[0] = ulValue;

		ulValue  = ptCfg->ulTrcBase;
		ulValue &= ~HOSTMSK(sqi_tcr_mode);
		ulValue |= ulTcrMode << HOSTSRT(sqi_tcr_mode);;
		ptCfg->ulTrcBase = ulValue;
	}
	else
	{
		//trace_message_uc(TRACEMSG_BootDrvSqi_InvalidBusWidth, (unsigned char)tBusWidth);
	}

	return iResult;
}



static unsigned long qsi_get_device_specific_sqirom_cfg(SPI_CFG_T *ptCfg __attribute__((unused)), unsigned int uiDummyCycles, unsigned int uiAddressBits, unsigned int uiAddressNibbles)
{
	unsigned long ulDeviceSpecificValue;
	unsigned long ulFreqKHz;
	unsigned long ulClockDivider;


	/* Get the maximum frequency for the ROM mode. */
	//ulFreqKHz = g_t_romloader_options.atSpiFlashCfg[SPI_UNIT_OFFSET_CURRENT].uiMaximumSpeedInRomMode_kHz;

	if( uiDummyCycles>15 )
	{
		/* The number of dummy cycles exceed the capabilities of the hardware. */
		//trace_message_ul(TRACEMSG_BootDrvSqi_SqiRom_InvalidDummyCycles, uiDummyCycles);
		ulDeviceSpecificValue = 0;
	}
	else if( (uiAddressNibbles<5) || (uiAddressNibbles>8) )
	{
		/* The address bits can not be realized by the hardware. */
		//trace_message_ul(TRACEMSG_BootDrvSqi_SqiRom_InvalidAddressBits, uiAddressNibbles);
		ulDeviceSpecificValue = 0;
	}
	else
	{
		if( uiAddressBits<20 )
		{
			uiAddressBits = 20;
		}
		else if( uiAddressBits>26 )
		{
			uiAddressBits = 26;
		}

		/* The maximum frequency is 142MHz. */
		if( ulFreqKHz>142000U )
		{
			/* Limit the frequency to the maximum. */
			ulFreqKHz = 142000U;
		}

		/* The formula for the frequency is:
		 *
		 *   freq = 1GHz / (val+1) = 1000000kHz / (val+1)
		 *
		 * This results in the value:
		 *
		 *   val + 1 =  1000000kHz / freq
		 *   val     = (1000000kHz / freq) - 1
		 */
		ulClockDivider  = 1000000U;
		ulClockDivider /= ulFreqKHz;
		ulClockDivider -= 1U;
		/* The value must not be smaller than 6. */
		if( ulClockDivider<6U )
		{
			ulClockDivider = 6U;
		}


		/* SFDP does not provide any speed information for read operation. Use 50MHz. */
		ulDeviceSpecificValue  = ulClockDivider << HOSTSRT(sqi_sqirom_cfg_clk_div_val);

		/* Set the minimum high time for the chip select signal to 1 clock. */
		ulDeviceSpecificValue |= 0 << HOSTSRT(sqi_sqirom_cfg_t_csh);

		/* Set the dummy cycles. */
		ulDeviceSpecificValue |= uiDummyCycles << HOSTSRT(sqi_sqirom_cfg_dummy_cycles);

		/* Set the default mode byte as the command. */
		ulDeviceSpecificValue |= 0xa5 << HOSTSRT(sqi_sqirom_cfg_cmd_byte);

		/* Set the number of address bits for internal calculation.  */
		ulDeviceSpecificValue |= (uiAddressBits-20U) << HOSTSRT(sqi_sqirom_cfg_addr_bits);

		/* Set the number of address nibbles. */
		ulDeviceSpecificValue |= (uiAddressNibbles-5U) << HOSTSRT(sqi_sqirom_cfg_addr_nibbles);

		/* The command is here the mode byte. Send the address before the mode byte. */
		ulDeviceSpecificValue |= HOSTMSK(sqi_sqirom_cfg_addr_before_cmd);
		ulDeviceSpecificValue |= HOSTMSK(sqi_sqirom_cfg_enable);

		//trace_message_ul(TRACEMSG_BootDrvSqi_SqiRom_NewConfiguration, ulDeviceSpecificValue);
	}

	return ulDeviceSpecificValue;
}



static int qsi_activate_sqirom(SPI_CFG_T *ptCfg, unsigned long ulSettings)
{
	HOSTADEF(SQI) * ptSqi;


	ptSqi = (HOSTADEF(SQI) *)(ptCfg->pvArea);
	ptSqi->ulSqi_sqirom_cfg = ulSettings;

	//trace_message(TRACEMSG_BootDrvSqi_SqiRom_Activated);

	return 0;
}



static int qsi_deactivate_sqi_rom(SPI_CFG_T *ptCfg)
{
	HOSTADEF(SQI) * ptSqi;


	ptSqi = (HOSTADEF(SQI) *)(ptCfg->pvArea);
	ptSqi->ulSqi_sqirom_cfg = 0;

	//trace_message(TRACEMSG_BootDrvSqi_SqiRom_Deactivated);

	return 0;
}


/*-------------------------------------------------------------------------*/


static void qsi_deactivate(const SPI_CFG_T *ptCfg)
{
	HOSTADEF(SQI) * ptSqi;
	unsigned long ulValue;


	ptSqi = (HOSTADEF(SQI) *)(ptCfg->pvArea);

	/* Deactivate IRQs. */
	ptSqi->ulSqi_irq_mask = 0;
	/* Clear all pending IRQs. */
	ulValue  = HOSTMSK(sqi_irq_clear_RORIC);
	ulValue |= HOSTMSK(sqi_irq_clear_RTIC);
	ulValue |= HOSTMSK(sqi_irq_clear_RXIC);
	ulValue |= HOSTMSK(sqi_irq_clear_TXIC);
	ulValue |= HOSTMSK(sqi_irq_clear_rxneic);
	ulValue |= HOSTMSK(sqi_irq_clear_rxfic);
	ulValue |= HOSTMSK(sqi_irq_clear_txeic);
	ulValue |= HOSTMSK(sqi_irq_clear_trans_end);
	ptSqi->ulSqi_irq_clear = ulValue;

	/* Deactivate DMAs. */
	ptSqi->ulSqi_dmacr = 0;

	/* Deactivate XIP. */
	ptSqi->ulSqi_sqirom_cfg = 0;

	ptSqi->ulSqi_tcr = 0;
	ptSqi->ulSqi_pio_oe = 0;
	ptSqi->ulSqi_pio_out = 0;

	/* Deactivate the unit. */
	ptSqi->aulSqi_cr[0] = 0;
	ptSqi->aulSqi_cr[1] = 0;

}


int boot_drv_sqi_init_b(SPI_CFG_T *ptCfg, const BOOT_SPI_CONFIGURATION_T *ptSpiCfg, unsigned int uiSqiUnit, unsigned int uiChipSelect)
{
	HOSTDEF(ptSQI0Area);
	HOSTDEF(ptSQI1Area);
	HOSTADEF(SQI) * ptSqi;
	void *pvSqiRom;
	unsigned long ulValue;
	int iResult;
	unsigned int uiIdleCfg;


	ptSqi = NULL;
	if( uiSqiUnit==0 )
	{
		ptSqi = ptSQI0Area;
		pvSqiRom = (unsigned long*)Addr_NX4000_NX2RAP_SQIROM0;
	}
	else if( uiSqiUnit==1 )
	{
		ptSqi = ptSQI1Area;
		pvSqiRom = (unsigned long*)Addr_NX4000_NX2RAP_SQIROM1;
	}

	if( ptSqi==NULL )
	{
		/* Error: the unit is invalid! */
		//trace_message_ul(TRACEMSG_BootDrvSqi_InvalidUnit, uiSqiUnit);
		iResult = -1;
	}
	else
	{
		ptCfg->pvArea = ptSqi;
		ptCfg->pvSqiRom = pvSqiRom;
		ptCfg->ulSpeed = ptSpiCfg->ulInitialSpeedKhz;   /* Initial device speed in kHz. */
		ptCfg->ucDummyByte = ptSpiCfg->ucDummyByte;     /* The idle configuration. */
		ptCfg->uiIdleConfiguration = (unsigned int)(ptSpiCfg->ucIdleConfiguration);
		ptCfg->tMode = ptSpiCfg->ucMode;                /* Bus mode. */
		ptCfg->uiUnit = uiSqiUnit;                      /* the unit */
		ptCfg->uiChipSelect = 1U<<uiChipSelect;         /* Chip select. */

		/* Set the function pointers. */
		ptCfg->pfnSelect = qsi_slave_select;
		ptCfg->pfnExchangeByte = qsi_exchange_byte;
		ptCfg->pfnSendIdleCycles = qsi_send_idle_cycles;
		ptCfg->pfnSendDummy = qsi_send_dummy;
		ptCfg->pfnSendData = qsi_send_data;
		ptCfg->pfnReceiveData = qsi_receive_data;
		ptCfg->pfnExchangeData = qsi_exchange_data;
		ptCfg->pfnSetNewSpeed = qsi_set_new_speed;
		ptCfg->pfnGetDeviceSpeedRepresentation = qsi_get_device_speed_representation;
		ptCfg->pfnReconfigureIos = NULL;
		ptCfg->pfnSetBusWidth = qsi_set_bus_width;
		ptCfg->pfnGetDeviceSpecificSqiRomCfg = qsi_get_device_specific_sqirom_cfg;
		ptCfg->pfnActivateSqiRom = qsi_activate_sqirom;
		ptCfg->pfnDeactivateSqiRom = qsi_deactivate_sqi_rom;
		ptCfg->pfnDeactivate = qsi_deactivate;


		/* Do not use IRQs in boot loader. */
		ptSqi->ulSqi_irq_mask = 0;
		/* Clear all pending IRQs. */
		ulValue  = HOSTMSK(sqi_irq_clear_RORIC);
		ulValue |= HOSTMSK(sqi_irq_clear_RTIC);
		ulValue |= HOSTMSK(sqi_irq_clear_RXIC);
		ulValue |= HOSTMSK(sqi_irq_clear_TXIC);
		ulValue |= HOSTMSK(sqi_irq_clear_rxneic);
		ulValue |= HOSTMSK(sqi_irq_clear_rxfic);
		ulValue |= HOSTMSK(sqi_irq_clear_txeic);
		ulValue |= HOSTMSK(sqi_irq_clear_trans_end);
		ptSqi->ulSqi_irq_clear = ulValue;

		/* Do not use DMAs. */
		ptSqi->ulSqi_dmacr = 0;

		/* Do not use XIP. */
		ptSqi->ulSqi_sqirom_cfg = 0;

		/* Set 8 bits. */
		ulValue  = 7 << HOSTSRT(sqi_cr0_datasize);
		/* Set speed and filter. */
		ulValue |= qsi_get_device_speed_representation(ptCfg->ulSpeed);
		/* Start in SPI mode: use only IO0 and IO1 for transfer. */
		ulValue |= 0 << HOSTSRT(sqi_cr0_sio_cfg);
		/* Set the clock polarity.  */
		if( (ptCfg->tMode==SPI_MODE2) || (ptCfg->tMode==SPI_MODE3) )
		{
			ulValue |= HOSTMSK(sqi_cr0_sck_pol);
		}
		/* Set the clock phase. */
		if( (ptCfg->tMode==SPI_MODE1) || (ptCfg->tMode==SPI_MODE3) )
		{
			ulValue |= HOSTMSK(sqi_cr0_sck_phase);
		}
		ptSqi->aulSqi_cr[0] = ulValue;


		/* Set the chip select to manual mode. */
		ulValue  = HOSTMSK(sqi_cr1_fss_static);
		/* Manual transfer start. */
		ulValue |= HOSTMSK(sqi_cr1_spi_trans_ctrl);
		/* Enable the interface. */
		ulValue |= HOSTMSK(sqi_cr1_sqi_en);
		/* Clear both FIFOs. */
		ulValue |= HOSTMSK(sqi_cr1_rx_fifo_clr)|HOSTMSK(sqi_cr1_tx_fifo_clr);
		ptSqi->aulSqi_cr[1] = ulValue;


		uiIdleCfg = ptCfg->uiIdleConfiguration;
		
		/* Set transfer control base. */
		ulValue  = HOSTMSK(sqi_tcr_ms_bit_first);
		if( (uiIdleCfg&MSK_SQI_CFG_IDLE_IO1_OE)!=0 )
		{
			ulValue |= HOSTMSK(sqi_tcr_tx_oe);
		}
		if( (uiIdleCfg&MSK_SQI_CFG_IDLE_IO1_OUT)!=0 )
		{
			ulValue |= HOSTMSK(sqi_tcr_tx_out);
		}
		ptCfg->ulTrcBase = ulValue;
		ptSqi->ulSqi_tcr = ulValue;

		ulValue = 0;
		if( (uiIdleCfg&MSK_SQI_CFG_IDLE_IO2_OUT)!=0 )
		{
			ulValue |= HOSTMSK(sqi_pio_out_sio2);
		}
		if( (uiIdleCfg&MSK_SQI_CFG_IDLE_IO3_OUT)!=0 )
		{
			ulValue |= HOSTMSK(sqi_pio_out_sio3);
		}
		ptSqi->ulSqi_pio_out = ulValue;

		ulValue = 0;
		if( (uiIdleCfg&MSK_SQI_CFG_IDLE_IO2_OE)!=0 )
		{
			ulValue |= HOSTMSK(sqi_pio_oe_sio2);
		}
		if( (uiIdleCfg&MSK_SQI_CFG_IDLE_IO3_OE)!=0 )
		{
			ulValue |= HOSTMSK(sqi_pio_oe_sio3);
		}
		ptSqi->ulSqi_pio_oe = ulValue;

		iResult = 0;
	}

	return iResult;
}

