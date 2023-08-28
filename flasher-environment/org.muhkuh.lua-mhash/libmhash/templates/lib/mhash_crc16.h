#if defined(ENABLE_CRC16)

#if !defined(__MHASH_CRC16_H)
#define __MHASH_CRC16_H

#include "libdefs.h"

struct Crc16Context {
	mutils_word16 checksum;		/* the checksum */
};

void Crc16_Init(struct Crc16Context *context);
void Crc16_Init_Inv(struct Crc16Context *context);
void Crc16_Update(struct Crc16Context *context, mutils_word8 __const *buf, mutils_word32 len);
void Crc16_Final(struct Crc16Context *context, mutils_word8 *digest);


typedef struct Crc16Context CRC16_CTX;

#endif

#endif
