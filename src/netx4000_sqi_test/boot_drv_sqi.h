/***************************************************************************
 *   Copyright (C) 2005, 2006, 2007, 2008, 2009 by Hilscher GmbH           *
 *                                                                         *
 *   Author: Christoph Thelen (cthelen@hilscher.com)                       *
 *                                                                         *
 *   Redistribution or unauthorized use without expressed written          *
 *   agreement from the Hilscher GmbH is forbidden.                        *
 ***************************************************************************/


#include <stddef.h>


#ifndef __BOOT_DRV_SQI_H__
#define __BOOT_DRV_SQI_H__

#include "boot_spi.h"


/*-------------------------------------*/


int boot_drv_sqi_init_b(SPI_CFG_T *ptCfg, const BOOT_SPI_CONFIGURATION_T *ptSpiCfg, unsigned int uiSqiUnit, unsigned int uiChipSelect);


/*-------------------------------------*/


#endif	/* __BOOT_DRV_SQI_H__ */

