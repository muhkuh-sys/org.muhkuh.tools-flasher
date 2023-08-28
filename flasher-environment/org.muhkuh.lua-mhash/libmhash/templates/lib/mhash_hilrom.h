#if defined(ENABLE_HILROM)

#if !defined(__MHASH_HILROM_H)
#define __MHASH_HILROM_H

#include "libdefs.h"

struct HilRomContext {
	int iOffs;			/* current byteoffset in the dword (0..3) */
	int iIsInverted;		/* !=0 if the checksum is inverted */
	mutils_word32 checksum;		/* the checksum */
};

void HilRom_Init(struct HilRomContext *context);
void HilRom_Init_Inv(struct HilRomContext *context);
void HilRom_Update(struct HilRomContext *context, mutils_word8 __const *buf, mutils_word32 len);
void HilRom_Final(struct HilRomContext *context, mutils_word8 *digest);


typedef struct HilRomContext HILROM_CTX;

#endif

#endif
