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

#ifdef ENABLE_HILROM

#include "mhash_hilrom.h"


void HilRom_Init(struct HilRomContext *context)
{
	context->iOffs = 0;
	context->iIsInverted = 0;
	context->checksum = 0;
}

void HilRom_Init_Inv(struct HilRomContext *context)
{
	context->iOffs = 0;
	context->iIsInverted = 1;
	context->checksum = 0;
}


void HilRom_Update(struct HilRomContext *context, mutils_word8 __const *buf, mutils_word32 len)
{
	int iOffset;
	mutils_word8 __const *pucCnt;
	mutils_word8 __const *pucEnd;
	mutils_word32 checksum;


	iOffset = context->iOffs << 3;
	checksum = context->checksum;

	pucCnt = buf;
	pucEnd = pucCnt + len;

	while(pucCnt<pucEnd)
	{
		checksum += *(pucCnt++) << iOffset;
	
		/* inc offset */
		iOffset += 8;
		iOffset &= 0x1f;
	}

	context->iOffs = iOffset >> 3;
	context->checksum = checksum;
}

void HilRom_Final(struct HilRomContext *context, mutils_word8 *digest)
{
	mutils_word32 tmp;

	tmp = context->checksum;
	if( context->iIsInverted!=0 )
	{
		--tmp;
		tmp ^= 0xffffffff;
	}

#if defined(WORDS_BIGENDIAN)
	tmp = mutils_word32swap(tmp);
#endif
	if (digest != NULL)
	{
		mutils_memcpy(digest, &tmp, sizeof(mutils_word32));	
	}

	memset(context, 0, sizeof(struct HilRomContext));
}


#endif /* ENABLE_HILROM */
