/*
 *    Copyright (C) 2008 Christoph Thelen
 *
 *    This library is free software; you can redistribute it and/or modify it 
 *    under the terms of the GNU Library General Public License as published 
 *    by the Free Software Foundation; either version 2 of the License, or 
 *    (at your option) any later version.
 *
 *    This library is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *    Library General Public License for more details.
 *
 *    You should have received a copy of the GNU Library General Public
 *    License along with this library; if not, write to the
 *    Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 *    Boston, MA 02111-1307, USA.
 */


#include "libdefs.h"

#ifdef ENABLE_CRC16

#include "mhash_crc16.h"


static mutils_word16 CalcCrc16(mutils_word16 uCrc, mutils_word8 uData)
{
	uCrc  = (uCrc >> 8) | ((uCrc & 0xff) << 8);
	uCrc ^= uData;
	uCrc ^= (uCrc & 0xff) >> 4;
	uCrc ^= (uCrc & 0x0f) << 12;
	uCrc ^= ((uCrc & 0xff) << 4) << 1;

	return uCrc;
}


void Crc16_Init(struct Crc16Context *context)
{
	context->checksum = 0;
}


void Crc16_Update(struct Crc16Context *context, mutils_word8 __const *buf, mutils_word32 len)
{
	mutils_word8 __const *pucCnt;
	mutils_word8 __const *pucEnd;
	mutils_word16 checksum;


	checksum = context->checksum;

	pucCnt = buf;
	pucEnd = pucCnt + len;

	while(pucCnt<pucEnd)
	{
		checksum = CalcCrc16(checksum, *(pucCnt++));
	}

	context->checksum = checksum;
}

void Crc16_Final(struct Crc16Context *context, mutils_word8 *digest)
{
	mutils_word16 tmp;

	tmp = context->checksum;

#if defined(WORDS_BIGENDIAN)
	tmp = mutils_word16swap(tmp);
#endif
	if (digest != NULL)
	{
		mutils_memcpy(digest, &tmp, sizeof(mutils_word16));	
	}

	memset(context, 0, sizeof(struct Crc16Context));
}


#endif /* ENABLE_CRC16 */
