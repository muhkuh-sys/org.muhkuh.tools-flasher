/***************************************************************************
 *   Copyright (C) 2007 by Christoph Thelen                                *
 *   doc_bacardi@users.sourceforge.net                                     *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/


#include "mhash_state.h"



const char *get_version(void)
{
	return PACKAGE_STRING;
}


double count(void)
{
	double d;


	d = (double)mhash_count();
	return d;
}


double get_block_size(hashid type)
{
	double d;


	d = (double)mhash_get_block_size(type);
	return d;
}


const char *get_hash_name(hashid type)
{
	const char *pc;


	// NOTE: use the static version here, the other one mallocs the string
	pc = (const char*)mhash_get_hash_name_static(type);
	return pc;
}










mhash_state::mhash_state(void)
 : m_hMHash(NULL)
{
}


mhash_state::mhash_state(hashid type)
 : m_hMHash(NULL)
{
	m_hMHash = mhash_init(type);
}


mhash_state::mhash_state(mhash_state *ptMHash)
 : m_hMHash(NULL)
{
	m_hMHash = mhash_cp(ptMHash->m_hMHash);
}


mhash_state::~mhash_state()
{
	deinit();
}


void mhash_state::deinit(void)
{
	if( m_hMHash!=NULL )
	{
		mhash_deinit(m_hMHash, NULL);
		m_hMHash = NULL;
	}
}




void mhash_state::init(hashid type)
{
	// clear any existing state
	deinit();

	// init new state
	m_hMHash = mhash_init(type);
}


void mhash_state::hash(const char *pcData, size_t sizData)
{
	this->hash(pcData, sizData, sizData, 0);
}


void mhash_state::hash(const char *pcData, size_t sizData, size_t sizLength)
{
	this->hash(pcData, sizData, sizLength, 0);
}


void mhash_state::hash(const char *pcData, size_t sizData, size_t sizLength, size_t sizOffset)
{
	mutils_boolean tMb;


	// limit the input values
	if( sizOffset<=sizData )
	{
		if( sizOffset+sizLength>sizData )
		{
			sizLength = sizData - sizOffset;
		}

		if( m_hMHash!=NULL )
		{
			tMb = mhash(m_hMHash, pcData+sizOffset, sizLength);
//			if( tMb!=MUTILS_OK )
//			{
//				strErrorMsg.Printf(_("mhash: failed to hash %d bytes!"), sizSize);
//				wxlua_error(L, strErrorMsg);
//			}
		}
	}
}


void mhash_state::hash_end(char **ppcData, size_t *psizData)
{
	hashid tId;
	size_t sizBlockSize;
	void *pvHash;
	char *pcData;
	size_t sizData;


	pcData = NULL;
	sizData = 0;

	// get blocksize
	if( m_hMHash!=NULL )
	{
		tId = mhash_get_mhash_algo(m_hMHash);
		sizBlockSize = mhash_get_block_size(tId);
		if( sizBlockSize>0 )
		{
			pvHash = mhash_end(m_hMHash);
			if( pvHash!=NULL )
			{
				pcData = (char*)pvHash;
				sizData = sizBlockSize;
			}
			m_hMHash = NULL;
		}
	}

	*ppcData = pcData;
	*psizData = sizData;
}

