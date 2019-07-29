#ifndef __NETX4000_SDIO_WRAP__
#define __NETX4000_SDIO_WRAP__

#include "flasher_interface.h"
#if CFG_INCLUDE_SHA1!=0
#       include "sha1.h"
#endif
 

NETX_CONSOLEAPP_RESULT_T sdio_detect_wrap(SDIO_HANDLE_T *ptSdioHandle);
NETX_CONSOLEAPP_RESULT_T sdio_read(CMD_PARAMETER_READ_T *ptParams);
NETX_CONSOLEAPP_RESULT_T sdio_write(CMD_PARAMETER_FLASH_T *ptParams);
NETX_CONSOLEAPP_RESULT_T sdio_verify(CMD_PARAMETER_VERIFY_T *ptParams, unsigned long *pulVerifyResult);
NETX_CONSOLEAPP_RESULT_T sdio_erase(CMD_PARAMETER_ERASE_T *ptParams);
NETX_CONSOLEAPP_RESULT_T sdio_is_erased(CMD_PARAMETER_ISERASED_T *ptParams, unsigned long *pulIsErasedResult);

NETX_CONSOLEAPP_RESULT_T sdio_get_erase_area(CMD_PARAMETER_GETERASEAREA_T *ptParameter);
#if CFG_INCLUDE_SHA1!=0
NETX_CONSOLEAPP_RESULT_T sdio_sha1(CMD_PARAMETER_CHECKSUM_T *ptParams, SHA_CTX *ptSha1Context);
#endif
#endif /* __NETX4000_SDIO_WRAP__ */
