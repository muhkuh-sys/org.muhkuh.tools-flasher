/***************************************************************************  
 *   Copyright (C) 2011 by Hilscher GmbH                                   *  
 ***************************************************************************/ 

/***************************************************************************  
  File          : spi_atmega.h                                                   
 ---------------------------------------------------------------------------- 
  Description:                                                                
                                                                              
      SPI functions for ATmega
 ---------------------------------------------------------------------------- 
  Todo:                                                                       
                                                                              
 ---------------------------------------------------------------------------- 
  Known Problems:                                                             
                                                                              
    -                                                                         
                                                                              
 ---------------------------------------------------------------------------- 
 5 jul 11   SL   initial version
 ***************************************************************************/ 


#ifndef __SPI_ATMEGA_H__
#define __SPI_ATMEGA_H__


#include "netx_consoleapp.h"
#include "flasher_interface.h"
#include "spi_atmega_types.h"

void uprintHex(const char* pcName, const unsigned char* pucData, size_t sizLen);

/* low level routines (SPI, command execution) */

/* clock frequency in kHz */
#define ATMEGA_SPI_CLOCK_KHZ 200

typedef enum ATMEGA_CMDPARAM_Ttag
{
	ATMEGA_CMDPARAM_NONE,
	ATMEGA_CMDPARAM_16BIT, 
	ATMEGA_CMDPARAM_8BIT
} ATMEGA_CMDPARAM_T;

int atmega_exec_command(const SPI_ATMEGA_T *ptDevice, const unsigned char *pucSendBuffer, unsigned char *pucReceiveBuffer, size_t sizCmdLen);
int atmega_command(const SPI_ATMEGA_T *ptDevice, const unsigned char *pucCmd, unsigned short usParam, ATMEGA_CMDPARAM_T tParamType, unsigned char bByte4In, unsigned char *pbByte4Out);


/* SPI commands */
int atmega_program_enable              (const SPI_ATMEGA_T *ptDevice, const SPI_ATMEGA_ATTRIBUTES_T *ptDeviceAttr);
int atmega_chip_erase                  (const SPI_ATMEGA_T *ptDevice);
int atmega_poll_rdy_busy               (const SPI_ATMEGA_T *ptDevice,                        unsigned char *pbRdy);

int atmega_load_extended_address_byte  (const SPI_ATMEGA_T *ptDevice, unsigned char ucAddr);
int atmega_load_prg_mem_page_high_byte (const SPI_ATMEGA_T *ptDevice, unsigned short usAddr, unsigned char bByte);
int atmega_load_prg_mem_page_low_byte  (const SPI_ATMEGA_T *ptDevice, unsigned short usAddr, unsigned char bByte);
int atmega_load_eeprom_mem_page        (const SPI_ATMEGA_T *ptDevice, unsigned char ucAddr,  unsigned char bByte);

int atmega_read_prg_mem_high_byte      (const SPI_ATMEGA_T *ptDevice, unsigned short usAddr, unsigned char *pbByte);
int atmega_read_prg_mem_low_byte       (const SPI_ATMEGA_T *ptDevice, unsigned short usAddr, unsigned char *pbByte);
int atmega_read_eeprom_mem             (const SPI_ATMEGA_T *ptDevice, unsigned short usAddr, unsigned char *pbByte);
int atmega_read_lock_bits              (const SPI_ATMEGA_T *ptDevice,                        unsigned char *pbByte);
int atmega_read_signature_byte         (const SPI_ATMEGA_T *ptDevice, unsigned char ucIndex, unsigned char *pbByte);
int atmega_read_fuse_bits              (const SPI_ATMEGA_T *ptDevice,                        unsigned char *pbByte);
int atmega_read_fuse_high_bits         (const SPI_ATMEGA_T *ptDevice,                        unsigned char *pbByte);
int atmega_read_extended_fuse_bits     (const SPI_ATMEGA_T *ptDevice,                        unsigned char *pbByte);
int atmega_read_calibration_byte       (const SPI_ATMEGA_T *ptDevice, unsigned char ucIndex, unsigned char *pbByte);

int atmega_write_prg_mem_page          (const SPI_ATMEGA_T *ptDevice, unsigned short usAddr);
int atmega_write_eeprom_mem            (const SPI_ATMEGA_T *ptDevice, unsigned short usAddr, unsigned char bByte);
int atmega_write_eeprom_mem_page       (const SPI_ATMEGA_T *ptDevice, unsigned short usAddr);
int atmega_write_lock_bits             (const SPI_ATMEGA_T *ptDevice,                        unsigned char bByte);
int atmega_write_fuse_bits             (const SPI_ATMEGA_T *ptDevice,                        unsigned char bByte);
int atmega_write_fuse_high_bits        (const SPI_ATMEGA_T *ptDevice,                        unsigned char bByte);
int atmega_write_extended_fuse_bits    (const SPI_ATMEGA_T *ptDevice,                        unsigned char bByte);

/* "convenience" routines */
int atmega_read_prg_mem_byte      (const SPI_ATMEGA_T *ptDevice, unsigned long ulAddr, unsigned char *pbByte);
int atmega_load_prg_mem_page_byte (const SPI_ATMEGA_T *ptDevice, unsigned long ulAddr, unsigned char bByte);
int atmega_read_device_id         (const SPI_ATMEGA_T *ptDevice, const SPI_ATMEGA_ATTRIBUTES_T *ptDeviceAttr, unsigned char *pucSignature, size_t sizBufferLen);


int Drv_SpiInitializeATMega(const SPI_CONFIGURATION_T *ptSpiCfg, SPI_ATMEGA_T *ptDevice);
int detect_atmega_type(const SPI_ATMEGA_T *ptDevice, const SPI_ATMEGA_ATTRIBUTES_T **pptDeviceAttr);

/* entry points from outside */
NETX_CONSOLEAPP_RESULT_T spi_atmega_detect(CMD_PARAMETER_DETECT_T *ptParameter);
NETX_CONSOLEAPP_RESULT_T spi_atmega_read_flash(CMD_PARAMETER_READ_T *ptParameter);
NETX_CONSOLEAPP_RESULT_T spi_atmega_write_flash(CMD_PARAMETER_FLASH_T *ptParameter);
NETX_CONSOLEAPP_RESULT_T spi_atmega_verify_flash(CMD_PARAMETER_VERIFY_T *ptParameter, NETX_CONSOLEAPP_PARAMETER_T *ptConsoleParams);
NETX_CONSOLEAPP_RESULT_T spi_atmega_chip_erase(CMD_PARAMETER_ERASE_T *ptParameter);

NETX_CONSOLEAPP_RESULT_T spi_atmega_read_fuses(SPI_ATMEGA_T *ptDevice);

NETX_CONSOLEAPP_RESULT_T spi_atmega_write_fuse_bits(CMD_PARAMETER_FUSES_T *ptParameter);
NETX_CONSOLEAPP_RESULT_T spi_atmega_write_lock_bits(CMD_PARAMETER_LOCK_BITS_T *ptParameter);

#endif /* __SPI_ATMEGA_H__ */