%module mhash

%include muhkuh_typemaps.i

%{
	#include "mhash_state.h"
%}

enum hashid
{
	MHASH_CRC32,
	MHASH_MD5,
	MHASH_SHA1,
	MHASH_HAVAL256,
	MHASH_RIPEMD160,
	MHASH_TIGER192,
	MHASH_GOST,
	MHASH_CRC32B,
	MHASH_HAVAL224,
	MHASH_HAVAL192,
	MHASH_HAVAL160,
	MHASH_HAVAL128,
	MHASH_TIGER128,
	MHASH_TIGER160,
	MHASH_MD4,
	MHASH_SHA256,
	MHASH_ADLER32,
	MHASH_SHA224,
	MHASH_SHA512,
	MHASH_SHA384,
	MHASH_WHIRLPOOL,
	MHASH_RIPEMD128,
	MHASH_RIPEMD256,
	MHASH_RIPEMD320,
	MHASH_SNEFRU128,
	MHASH_SNEFRU256,
	MHASH_MD2,
	MHASH_AR,
	MHASH_BOOGNISH,
	MHASH_CELLHASH,
	MHASH_FFT_HASH_I,
	MHASH_FFT_HASH_II,
	MHASH_NHASH,
	MHASH_PANAMA,
	MHASH_SMASH,
	MHASH_SUBHASH,
	MHASH_HILROM,
	MHASH_HILROMI,
	MHASH_CRC16
};


enum mutils_error_codes
{
	MUTILS_OK,
	MUTILS_SYSTEM_ERROR,
	MUTILS_UNSPECIFIED_ERROR,
	MUTILS_SYSTEM_RESOURCE_ERROR,
	MUTILS_PARAMETER_ERROR,
	MUTILS_INVALID_FUNCTION,
	MUTILS_INVALID_INPUT_BUFFER,
	MUTILS_INVALID_OUTPUT_BUFFER,
	MUTILS_INVALID_PASSES,
	MUTILS_INVALID_FORMAT,
	MUTILS_INVALID_SIZE,
	MUTILS_INVALID_RESULT
};

enum keygenid
{
	KEYGEN_MCRYPT,
	KEYGEN_ASIS,
	KEYGEN_HEX,
	KEYGEN_PKDES,
	KEYGEN_S2K_SIMPLE,
	KEYGEN_S2K_SALTED,
	KEYGEN_S2K_ISALTED
};


const char *get_version();

double count();
double get_block_size(hashid type);
const char *get_hash_name(hashid type);

class mhash_state
{
public:
	mhash_state();
	mhash_state(hashid type);
	mhash_state(mhash_state *ptMHash);
	~mhash_state();

	void init(hashid type);
	void hash(const char *pcBUFFER_IN, size_t sizBUFFER_IN);
	void hash(const char *pcBUFFER_IN, size_t sizBUFFER_IN, size_t sizLength);
	void hash(const char *pcBUFFER_IN, size_t sizBUFFER_IN, size_t sizLength, size_t sizOffset);

	void hash_end(char **ppcBUFFER_OUT, size_t *psizBUFFER_OUT);
};

