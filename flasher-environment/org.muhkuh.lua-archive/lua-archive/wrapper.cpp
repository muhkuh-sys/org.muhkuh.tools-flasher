#include "wrapper.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>


int version_number(void)
{
	return archive_version_number();
}



const char* version_string(void)
{
	return archive_version_string();
}



const char* version_details(void)
{
	return archive_version_details();
}



const char* zlib_version(void)
{
	return archive_zlib_version();
}



const char* liblzma_version(void)
{
	return archive_liblzma_version();
}



const char* bzlib_version(void)
{
	return archive_bzlib_version();
}



const char* liblz4_version(void)
{
	return archive_liblz4_version();
}



/*--------------------------------------------------------------------------*/


ArchiveEntry::ArchiveEntry(void)
 : m_ptArchiveEntry(NULL)
{
	m_ptArchiveEntry = archive_entry_new();
}



ArchiveEntry::ArchiveEntry(struct archive_entry *ptArchiveEntry)
 : m_ptArchiveEntry(NULL)
{
	m_ptArchiveEntry = archive_entry_clone(ptArchiveEntry);
}



ArchiveEntry::~ArchiveEntry(void)
{
	if( m_ptArchiveEntry!=NULL )
	{
		archive_entry_free(m_ptArchiveEntry);
		m_ptArchiveEntry = NULL;
	}
}



time_t ArchiveEntry::atime(void)
{
	return archive_entry_atime(m_ptArchiveEntry);
}



long ArchiveEntry::atime_nsec(void)
{
	return archive_entry_atime_nsec(m_ptArchiveEntry);
}



int ArchiveEntry::atime_is_set(void)
{
	return archive_entry_atime_is_set(m_ptArchiveEntry);
}



time_t ArchiveEntry::birthtime(void)
{
	return archive_entry_birthtime(m_ptArchiveEntry);
}



long ArchiveEntry::birthtime_nsec(void)
{
	return archive_entry_birthtime_nsec(m_ptArchiveEntry);
}



int ArchiveEntry::birthtime_is_set(void)
{
	return archive_entry_birthtime_is_set(m_ptArchiveEntry);
}



time_t ArchiveEntry::ctime(void)
{
	return archive_entry_ctime(m_ptArchiveEntry);
}



long ArchiveEntry::ctime_nsec(void)
{
	return archive_entry_ctime_nsec(m_ptArchiveEntry);
}



int ArchiveEntry::ctime_is_set(void)
{
	return archive_entry_ctime_is_set(m_ptArchiveEntry);
}



dev_t ArchiveEntry::dev(void)
{
	return archive_entry_dev(m_ptArchiveEntry);
}



int ArchiveEntry::dev_is_set(void)
{
	return archive_entry_dev_is_set(m_ptArchiveEntry);
}



dev_t ArchiveEntry::devmajor(void)
{
	return archive_entry_devmajor(m_ptArchiveEntry);
}



dev_t ArchiveEntry::devminor(void)
{
	return archive_entry_devminor(m_ptArchiveEntry);
}



__LA_MODE_T ArchiveEntry::filetype(void)
{
	return archive_entry_filetype(m_ptArchiveEntry);
}



const char* ArchiveEntry::fflags_text(void)
{
	return archive_entry_fflags_text(m_ptArchiveEntry);
}



int64_t ArchiveEntry::gid(void)
{
	return archive_entry_gid(m_ptArchiveEntry);
}



const char* ArchiveEntry::gname(void)
{
	return archive_entry_gname(m_ptArchiveEntry);
}



const char* ArchiveEntry::gname_utf8(void)
{
	return archive_entry_gname_utf8(m_ptArchiveEntry);
}



const wchar_t* ArchiveEntry::gname_w(void)
{
	return archive_entry_gname_w(m_ptArchiveEntry);
}



const char* ArchiveEntry::hardlink(void)
{
	return archive_entry_hardlink(m_ptArchiveEntry);
}



const char* ArchiveEntry::hardlink_utf8(void)
{
	return archive_entry_hardlink_utf8(m_ptArchiveEntry);
}



const wchar_t* ArchiveEntry::hardlink_w(void)
{
	return archive_entry_hardlink_w(m_ptArchiveEntry);
}



int64_t ArchiveEntry::ino(void)
{
	return archive_entry_ino(m_ptArchiveEntry);
}



int64_t ArchiveEntry::ino64(void)
{
	return archive_entry_ino64(m_ptArchiveEntry);
}



int ArchiveEntry::ino_is_set(void)
{
	return archive_entry_ino_is_set(m_ptArchiveEntry);
}



int ArchiveEntry::mode(void)
{
	return archive_entry_mode(m_ptArchiveEntry);
}



time_t ArchiveEntry::mtime(void)
{
	return archive_entry_mtime(m_ptArchiveEntry);
}



long ArchiveEntry::mtime_nsec(void)
{
	return archive_entry_mtime_nsec(m_ptArchiveEntry);
}



int ArchiveEntry::mtime_is_set(void)
{
	return archive_entry_mtime_is_set(m_ptArchiveEntry);
}



unsigned int ArchiveEntry::nlink(void)
{
	return archive_entry_nlink(m_ptArchiveEntry);
}



const char* ArchiveEntry::pathname(void)
{
	return archive_entry_pathname(m_ptArchiveEntry);
}



const char* ArchiveEntry::pathname_utf8(void)
{
	return archive_entry_pathname_utf8(m_ptArchiveEntry);
}



const wchar_t* ArchiveEntry::pathname_w(void)
{
	return archive_entry_pathname_w(m_ptArchiveEntry);
}



int ArchiveEntry::perm(void)
{
	return archive_entry_perm(m_ptArchiveEntry);
}



dev_t ArchiveEntry::rdev(void)
{
	return archive_entry_rdev(m_ptArchiveEntry);
}



dev_t ArchiveEntry::rdevmajor(void)
{
	return archive_entry_rdevmajor(m_ptArchiveEntry);
}



dev_t ArchiveEntry::rdevminor(void)
{
	return archive_entry_rdevminor(m_ptArchiveEntry);
}



const char* ArchiveEntry::sourcepath(void)
{
	return archive_entry_sourcepath(m_ptArchiveEntry);
}



const wchar_t* ArchiveEntry::sourcepath_w(void)
{
	return archive_entry_sourcepath_w(m_ptArchiveEntry);
}



int64_t ArchiveEntry::size(void)
{
	return archive_entry_size(m_ptArchiveEntry);
}



int ArchiveEntry::size_is_set(void)
{
	return archive_entry_size_is_set(m_ptArchiveEntry);
}



const char* ArchiveEntry::strmode(void)
{
	return archive_entry_strmode(m_ptArchiveEntry);
}



const char* ArchiveEntry::symlink(void)
{
	return archive_entry_symlink(m_ptArchiveEntry);
}



const char* ArchiveEntry::symlink_utf8(void)
{
	return archive_entry_symlink_utf8(m_ptArchiveEntry);
}



const wchar_t* ArchiveEntry::symlink_w(void)
{
	return archive_entry_symlink_w(m_ptArchiveEntry);
}



int64_t ArchiveEntry::uid(void)
{
	return archive_entry_uid(m_ptArchiveEntry);
}



const char* ArchiveEntry::uname(void)
{
	return archive_entry_uname(m_ptArchiveEntry);
}



const char* ArchiveEntry::uname_utf8(void)
{
	return archive_entry_uname_utf8(m_ptArchiveEntry);
}



const wchar_t* ArchiveEntry::uname_w(void)
{
	return archive_entry_uname_w(m_ptArchiveEntry);
}



int ArchiveEntry::is_data_encrypted(void)
{
	return archive_entry_is_data_encrypted(m_ptArchiveEntry);
}



int ArchiveEntry::is_metadata_encrypted(void)
{
	return archive_entry_is_metadata_encrypted(m_ptArchiveEntry);
}



int ArchiveEntry::is_encrypted(void)
{
	return archive_entry_is_encrypted(m_ptArchiveEntry);
}



ArchiveEntry* ArchiveEntry::set_atime(time_t tTime, long lNs)
{
	archive_entry_set_atime(m_ptArchiveEntry, tTime, lNs);
	return this;
}



ArchiveEntry* ArchiveEntry::unset_atime(void)
{
	archive_entry_unset_atime(m_ptArchiveEntry);
	return this;
}



ArchiveEntry* ArchiveEntry::set_birthtime(time_t tTime, long lNs)
{
	archive_entry_set_birthtime(m_ptArchiveEntry, tTime, lNs);
	return this;
}



ArchiveEntry* ArchiveEntry::unset_birthtime(void)
{
	archive_entry_unset_birthtime(m_ptArchiveEntry);
	return this;
}



ArchiveEntry* ArchiveEntry::set_ctime(time_t tTime, long lNs)
{
	archive_entry_set_ctime(m_ptArchiveEntry, tTime, lNs);
	return this;
}



ArchiveEntry* ArchiveEntry::unset_ctime(void)
{
	archive_entry_unset_ctime(m_ptArchiveEntry);
	return this;
}



ArchiveEntry* ArchiveEntry::set_dev(dev_t tDev)
{
	archive_entry_set_dev(m_ptArchiveEntry, tDev);
	return this;
}



ArchiveEntry* ArchiveEntry::set_devmajor(dev_t tDev)
{
	archive_entry_set_devmajor(m_ptArchiveEntry, tDev);
	return this;
}



ArchiveEntry* ArchiveEntry::set_devminor(dev_t tDev)
{
	archive_entry_set_devminor(m_ptArchiveEntry, tDev);
	return this;
}



ArchiveEntry* ArchiveEntry::set_filetype(unsigned int uiFileType)
{
	archive_entry_set_filetype(m_ptArchiveEntry, uiFileType);
	return this;
}



ArchiveEntry* ArchiveEntry::set_gid(la_int64_t llGid)
{
	archive_entry_set_gid(m_ptArchiveEntry, llGid);
	return this;
}



ArchiveEntry* ArchiveEntry::set_gname(const char *pcGname)
{
	archive_entry_set_gname(m_ptArchiveEntry, pcGname);
	return this;
}



ArchiveEntry* ArchiveEntry::set_gname_utf8(const char *pcGname)
{
	archive_entry_set_gname_utf8(m_ptArchiveEntry, pcGname);
	return this;
}



ArchiveEntry* ArchiveEntry::copy_gname(const char *pcGname)
{
	archive_entry_copy_gname(m_ptArchiveEntry, pcGname);
	return this;
}



ArchiveEntry* ArchiveEntry::copy_gname_w(const wchar_t *pcGname)
{
	archive_entry_copy_gname_w(m_ptArchiveEntry, pcGname);
	return this;
}



int ArchiveEntry::update_gname_utf8(const char *pcGname)
{
	return archive_entry_update_gname_utf8(m_ptArchiveEntry, pcGname);
}



ArchiveEntry* ArchiveEntry::set_hardlink(const char *pcHardlink)
{
	archive_entry_set_hardlink(m_ptArchiveEntry, pcHardlink);
	return this;
}



ArchiveEntry* ArchiveEntry::set_hardlink_utf8(const char *pcHardlink)
{
	archive_entry_set_hardlink_utf8(m_ptArchiveEntry, pcHardlink);
	return this;
}



ArchiveEntry* ArchiveEntry::copy_hardlink(const char *pcHardlink)
{
	archive_entry_copy_hardlink(m_ptArchiveEntry, pcHardlink);
	return this;
}



ArchiveEntry* ArchiveEntry::copy_hardlink_w(const wchar_t *pcHardlink)
{
	archive_entry_copy_hardlink_w(m_ptArchiveEntry, pcHardlink);
	return this;
}



int ArchiveEntry::update_hardlink_utf8(const char *pcHardlink)
{
	return archive_entry_update_hardlink_utf8(m_ptArchiveEntry, pcHardlink);
}



ArchiveEntry* ArchiveEntry::set_ino(la_int64_t llIno)
{
	archive_entry_set_ino(m_ptArchiveEntry, llIno);
	return this;
}



ArchiveEntry* ArchiveEntry::set_ino64(la_int64_t llIno)
{
	archive_entry_set_ino64(m_ptArchiveEntry, llIno);
	return this;
}



ArchiveEntry* ArchiveEntry::set_link(const char *pcLink)
{
	archive_entry_set_link(m_ptArchiveEntry, pcLink);
	return this;
}



ArchiveEntry* ArchiveEntry::set_link_utf8(const char *pcLink)
{
	archive_entry_set_link_utf8(m_ptArchiveEntry, pcLink);
	return this;
}



ArchiveEntry* ArchiveEntry::copy_link(const char *pcLink)
{
	archive_entry_copy_link(m_ptArchiveEntry, pcLink);
	return this;
}



ArchiveEntry* ArchiveEntry::copy_link_w(const wchar_t *pcLink)
{
	archive_entry_copy_link_w(m_ptArchiveEntry, pcLink);
	return this;
}



int ArchiveEntry::update_link_utf8(const char *pcLink)
{
	return archive_entry_update_link_utf8(m_ptArchiveEntry, pcLink);
}



ArchiveEntry* ArchiveEntry::set_mode(int iMode)
{
	archive_entry_set_mode(m_ptArchiveEntry, iMode);
	return this;
}



ArchiveEntry* ArchiveEntry::set_mtime(time_t tTime, long lNs)
{
	archive_entry_set_mtime(m_ptArchiveEntry, tTime, lNs);
	return this;
}



ArchiveEntry* ArchiveEntry::unset_mtime(void)
{
	archive_entry_unset_mtime(m_ptArchiveEntry);
	return this;
}



ArchiveEntry* ArchiveEntry::set_nlink(unsigned int uiNlink)
{
	archive_entry_set_nlink(m_ptArchiveEntry, uiNlink);
	return this;
}



ArchiveEntry* ArchiveEntry::set_pathname(const char *pcPathName)
{
	archive_entry_set_pathname(m_ptArchiveEntry, pcPathName);
	return this;
}



ArchiveEntry* ArchiveEntry::set_pathname_utf8(const char *pcPathName)
{
	archive_entry_set_pathname_utf8(m_ptArchiveEntry, pcPathName);
	return this;
}



ArchiveEntry* ArchiveEntry::copy_pathname(const char *pcPathName)
{
	archive_entry_copy_pathname(m_ptArchiveEntry, pcPathName);
	return this;
}



ArchiveEntry* ArchiveEntry::copy_pathname_w(const wchar_t *pcPathName)
{
	archive_entry_copy_pathname_w(m_ptArchiveEntry, pcPathName);
	return this;
}



int ArchiveEntry::update_pathname_utf8(const char *pcPathName)
{
	return archive_entry_update_pathname_utf8(m_ptArchiveEntry, pcPathName);
}



ArchiveEntry* ArchiveEntry::set_perm(int iMode)
{
	archive_entry_set_perm(m_ptArchiveEntry, iMode);
	return this;
}



ArchiveEntry* ArchiveEntry::set_rdev(dev_t tDev)
{
	archive_entry_set_rdev(m_ptArchiveEntry, tDev);
	return this;
}



ArchiveEntry* ArchiveEntry::set_rdevmajor(dev_t tDev)
{
	archive_entry_set_rdevmajor(m_ptArchiveEntry, tDev);
	return this;
}



ArchiveEntry* ArchiveEntry::set_rdevminor(dev_t tDev)
{
	archive_entry_set_rdevminor(m_ptArchiveEntry, tDev);
	return this;
}



ArchiveEntry* ArchiveEntry::set_size(la_int64_t llSize )
{
	archive_entry_set_size(m_ptArchiveEntry, llSize);
	return this;
}



ArchiveEntry* ArchiveEntry::unset_size(void)
{
	archive_entry_unset_size(m_ptArchiveEntry);
	return this;
}



ArchiveEntry* ArchiveEntry::copy_sourcepath(const char *pcPath)
{
	archive_entry_copy_sourcepath(m_ptArchiveEntry, pcPath);
	return this;
}



ArchiveEntry* ArchiveEntry::copy_sourcepath_w(const wchar_t *pcPath)
{
	archive_entry_copy_sourcepath_w(m_ptArchiveEntry, pcPath);
	return this;
}



ArchiveEntry* ArchiveEntry::set_symlink(const char *pcPath)
{
	archive_entry_set_symlink(m_ptArchiveEntry, pcPath);
	return this;
}



struct archive_entry *ArchiveEntry::_get_raw(void)
{
	return m_ptArchiveEntry;
}


/*--------------------------------------------------------------------------*/


Archive::Archive(void)
 : m_ptArchive(NULL)
{
}



Archive::~Archive(void)
{
}



int Archive::error_errno(void)
{
	return archive_errno(m_ptArchive);
}



const char* Archive::error_string(void)
{
	return archive_error_string(m_ptArchive);
}



int Archive::file_count(void)
{
	return archive_file_count(m_ptArchive);
}



int Archive::filter_count(void)
{
	return archive_filter_count(m_ptArchive);
}



int64_t Archive::filter_bytes(int iFilterNumber)
{
	return archive_filter_bytes(m_ptArchive, iFilterNumber);
}



int Archive::filter_code(int iFilterNumber)
{
	return archive_filter_code(m_ptArchive, iFilterNumber);
}



const char *Archive::filter_name(int iFilterNumber)
{
	return archive_filter_name(m_ptArchive, iFilterNumber);
}



struct archive *Archive::_get_raw(void)
{
	return m_ptArchive;
}


/*--------------------------------------------------------------------------*/


ArchiveReadCommon::ArchiveReadCommon(void)
 : Archive()
{
}



ArchiveReadCommon::~ArchiveReadCommon(void)
{
}



ArchiveEntry *ArchiveReadCommon::next_header(void)
{
	int iResult;
	struct archive_entry* ptArchiveEntryStruct;
	ArchiveEntry *ptArchiveEntryClass;


	ptArchiveEntryClass = NULL;

	iResult = archive_read_next_header(m_ptArchive, &ptArchiveEntryStruct);
	if( iResult==ARCHIVE_OK )
	{
		ptArchiveEntryClass = new ArchiveEntry(ptArchiveEntryStruct);
	}

	return ptArchiveEntryClass;
}



void ArchiveReadCommon::iter_header(lua_State *MUHKUH_SWIG_OUTPUT_CUSTOM_OBJECT, swig_type_info *p_ArchiveEntry)
{
	/* Push the pointer to this instance of the "Archive" class as the first up-value. */
	lua_pushlightuserdata(MUHKUH_SWIG_OUTPUT_CUSTOM_OBJECT, (void*)this);
	/* Push the type of the result as the second up-value. */
	lua_pushlightuserdata(MUHKUH_SWIG_OUTPUT_CUSTOM_OBJECT, (void*)p_ArchiveEntry);
	/* Create a C closure with 2 arguments. */
	lua_pushcclosure(MUHKUH_SWIG_OUTPUT_CUSTOM_OBJECT, &(ArchiveRead::iterator_next_header), 2);

	/* NOTE: This function does not return the produced number of
	 *       arguments. This is done in the SWIG wrapper.
	 */
}



int ArchiveReadCommon::iterator_next_header(lua_State *ptLuaState)
{
	int iUpvalueIndex;
	void *pvUpvalue;
	ArchiveRead *ptThis;
	swig_type_info *ptTypeInfo;
	ArchiveEntry *ptArchiveEntry;


	/* Get the first up-value. */
	iUpvalueIndex = lua_upvalueindex(1);
	pvUpvalue = lua_touserdata(ptLuaState, iUpvalueIndex);
	/* Cast the up-value to a class pointer. */
	ptThis = (ArchiveRead*)pvUpvalue;

	/* Get the second up-value. */
	iUpvalueIndex = lua_upvalueindex(2);
	pvUpvalue = lua_touserdata(ptLuaState, iUpvalueIndex);
	ptTypeInfo = (swig_type_info*)pvUpvalue;

	/* Get the next archive entry. */
	ptArchiveEntry = ptThis->next_header();
	/* Push the class on the LUA stack. */
	if( ptArchiveEntry==NULL )
	{
		lua_pushnil(ptLuaState);
	}
	else
	{
		/* Create a new pointer object from the archive entry and transfer the ownership to LUA (this is the last parameter). */
		SWIG_NewPointerObj(ptLuaState, ptArchiveEntry, ptTypeInfo, 1);
	}

	return 1;
}



int ArchiveReadCommon::data_skip(void)
{
	return archive_read_data_skip(m_ptArchive);
}



void ArchiveReadCommon::read_data(size_t sizChunk, char **ppcBUFFER_OUT, size_t *psizBUFFER_OUT)
{
	la_ssize_t sResult;
	char *pcBuffer;
	size_t sizRead;


	/* No data read yet. */
	sizRead = 0;

	/* Allocate the buffer. */
	pcBuffer = (char*)malloc(sizChunk);
	if( pcBuffer!=NULL )
	{
		sResult = archive_read_data(m_ptArchive, pcBuffer, sizChunk);
		if( sResult<0 )
		{
			/* An error occured, discard the data. */
			free(pcBuffer);
			pcBuffer = NULL;
		}
		else
		{
			sizRead = (size_t)sResult;
		}
	}

	*ppcBUFFER_OUT = pcBuffer;
	*psizBUFFER_OUT = sizRead;
}



void ArchiveReadCommon::iter_data(size_t sizChunk, lua_State *MUHKUH_SWIG_OUTPUT_CUSTOM_OBJECT)
{
	lua_Number tNumber;


	/* Push the pointer to this instance of the "Archive" class as the first upvalue. */
	lua_pushlightuserdata(MUHKUH_SWIG_OUTPUT_CUSTOM_OBJECT, (void*)this);
	/* Push the chunk size as the second upvalue. */
	tNumber = (lua_Number)sizChunk;
	lua_pushnumber(MUHKUH_SWIG_OUTPUT_CUSTOM_OBJECT, tNumber);
	/* Create a C closure with 2 arguments. */
	lua_pushcclosure(MUHKUH_SWIG_OUTPUT_CUSTOM_OBJECT, &(ArchiveRead::iterator_read_data), 2);

	/* NOTE: This function does not return the produced number of
	 *       arguments. This is done in the SWIG wrapper.
	 */
}



int ArchiveReadCommon::iterator_read_data(lua_State *ptLuaState)
{
	int iUpvalueIndex;
	void *pvUpvalue;
	lua_Number tNumber;
	ArchiveRead *ptThis;
	size_t sizChunk;
	char *pcBuffer;
	size_t sizBuffer;


	/* Get the first up-value. */
	iUpvalueIndex = lua_upvalueindex(1);
	pvUpvalue = lua_touserdata(ptLuaState, iUpvalueIndex);
	/* Cast the up-value to a class pointer. */
	ptThis = (ArchiveRead*)pvUpvalue;

	/* Get the second up-value. */
	iUpvalueIndex = lua_upvalueindex(2);
	tNumber = lua_tonumber(ptLuaState, iUpvalueIndex);
	sizChunk = (size_t)tNumber;

	/* Get the next data chunk. */
	ptThis->read_data(sizChunk, &pcBuffer, &sizBuffer);
	/* Push the class on the LUA stack. */
	if( pcBuffer!=NULL && sizBuffer!=0 )
	{
		lua_pushlstring(ptLuaState, pcBuffer, sizBuffer);
	}
	else
	{
		lua_pushnil(ptLuaState);
	}

	return 1;
}



int ArchiveReadCommon::close(void)
{
	return archive_read_close(m_ptArchive);
}




/*--------------------------------------------------------------------------*/


ArchiveRead::ArchiveRead(void)
 : ArchiveReadCommon()
 , m_pvBuffer(NULL)
 , m_sizBufferAllocated(0)
{
	/* Allocate a new archive structure. */
	m_ptArchive = archive_read_new();
}



ArchiveRead::~ArchiveRead(void)
{
	int iResult;


	if( m_ptArchive!=NULL )
	{
		iResult = archive_read_free(m_ptArchive);
		if( iResult!=ARCHIVE_OK )
		{
			printf("Failed to free the archive structure!\n");
		}
		m_ptArchive = NULL;
	}

	if( m_pvBuffer!=NULL )
	{
		free(m_pvBuffer);
		m_pvBuffer = NULL;
		m_sizBufferAllocated = 0;
	}
}



int ArchiveRead::support_filter_all(void)
{
	return archive_read_support_filter_all(m_ptArchive);
}



int ArchiveRead::support_filter_bzip2(void)
{
	return archive_read_support_filter_bzip2(m_ptArchive);
}



int ArchiveRead::support_filter_compress(void)
{
	return archive_read_support_filter_compress(m_ptArchive);
}



int ArchiveRead::support_filter_gzip(void)
{
	return archive_read_support_filter_gzip(m_ptArchive);
}



int ArchiveRead::support_filter_grzip(void)
{
	return archive_read_support_filter_grzip(m_ptArchive);
}



int ArchiveRead::support_filter_lrzip(void)
{
	return archive_read_support_filter_lrzip(m_ptArchive);
}



int ArchiveRead::support_filter_lz4(void)
{
	return archive_read_support_filter_lz4(m_ptArchive);
}



int ArchiveRead::support_filter_lzip(void)
{
	return archive_read_support_filter_lzip(m_ptArchive);
}



int ArchiveRead::support_filter_lzma(void)
{
	return archive_read_support_filter_lzma(m_ptArchive);
}



int ArchiveRead::support_filter_lzop(void)
{
	return archive_read_support_filter_lzop(m_ptArchive);
}



int ArchiveRead::support_filter_none(void)
{
	return archive_read_support_filter_none(m_ptArchive);
}



int ArchiveRead::support_filter_rpm(void)
{
	return archive_read_support_filter_rpm(m_ptArchive);
}



int ArchiveRead::support_filter_uu(void)
{
	return archive_read_support_filter_uu(m_ptArchive);
}



int ArchiveRead::support_filter_xz(void)
{
	return archive_read_support_filter_xz(m_ptArchive);
}



int ArchiveRead::support_filter_zstd(void)
{
	return archive_read_support_filter_zstd(m_ptArchive);
}



int ArchiveRead::support_format_all(void)
{
	return archive_read_support_format_all(m_ptArchive);
}



int ArchiveRead::support_format_7zip(void)
{
	return archive_read_support_format_7zip(m_ptArchive);
}



int ArchiveRead::support_format_ar(void)
{
	return archive_read_support_format_ar(m_ptArchive);
}



int ArchiveRead::support_format_by_code(int iCode)
{
	return archive_read_support_format_by_code(m_ptArchive, iCode);
}



int ArchiveRead::support_format_cab(void)
{
	return archive_read_support_format_cab(m_ptArchive);
}



int ArchiveRead::support_format_cpio(void)
{
	return archive_read_support_format_cpio(m_ptArchive);
}



int ArchiveRead::support_format_empty(void)
{
	return archive_read_support_format_empty(m_ptArchive);
}



int ArchiveRead::support_format_gnutar(void)
{
	return archive_read_support_format_gnutar(m_ptArchive);
}



int ArchiveRead::support_format_iso9660(void)
{
	return archive_read_support_format_iso9660(m_ptArchive);
}



int ArchiveRead::support_format_lha(void)
{
	return archive_read_support_format_lha(m_ptArchive);
}



int ArchiveRead::support_format_mtree(void)
{
	return archive_read_support_format_mtree(m_ptArchive);
}



int ArchiveRead::support_format_rar(void)
{
	return archive_read_support_format_rar(m_ptArchive);
}



int ArchiveRead::support_format_rar5(void)
{
	return archive_read_support_format_rar5(m_ptArchive);
}



int ArchiveRead::support_format_raw(void)
{
	return archive_read_support_format_raw(m_ptArchive);
}



int ArchiveRead::support_format_tar(void)
{
	return archive_read_support_format_tar(m_ptArchive);
}



int ArchiveRead::support_format_warc(void)
{
	return archive_read_support_format_warc(m_ptArchive);
}



int ArchiveRead::support_format_xar(void)
{
	return archive_read_support_format_xar(m_ptArchive);
}



int ArchiveRead::support_format_zip(void)
{
	return archive_read_support_format_zip(m_ptArchive);
}



int ArchiveRead::support_format_zip_streamable(void)
{
	return archive_read_support_format_zip_streamable(m_ptArchive);
}



int ArchiveRead::support_format_zip_seekable(void)
{
	return archive_read_support_format_zip_seekable(m_ptArchive);
}



int ArchiveRead::open_filename(const char *_filename, size_t _block_size)
{
	return archive_read_open_filename(m_ptArchive, _filename, _block_size);
}



int ArchiveRead::set_format(int iFormat)
{
	return archive_read_set_format(m_ptArchive, iFormat);
}



int ArchiveRead::append_filter(int iFilter)
{
	return archive_read_append_filter(m_ptArchive, iFilter);
}



int ArchiveRead::set_format_option(const char *m, const char *o, const char *v)
{
	return archive_read_set_format_option(m_ptArchive, m, o, v);
}



int ArchiveRead::set_filter_option(const char *m, const char *o, const char *v)
{
	return archive_read_set_filter_option(m_ptArchive, m, o, v);
}



int ArchiveRead::set_option(const char *m, const char *o, const char *v)
{
	return archive_read_set_option(m_ptArchive, m, o, v);
}



int ArchiveRead::set_options(const char *opts)
{
	return archive_read_set_options(m_ptArchive, opts);
}



int ArchiveRead::extract(ArchiveEntry *ptEntry, int iFlags)
{
	return archive_read_extract(m_ptArchive, ptEntry->_get_raw(), iFlags);
}



int ArchiveRead::extract2(ArchiveEntry *ptEntry, ArchiveWrite *ptDestArchive)
{
	return archive_read_extract2(m_ptArchive, ptEntry->_get_raw(), ptDestArchive->_get_raw());
}



int ArchiveRead::open_memory(const char *pcBUFFER_IN, size_t sizBUFFER_IN)
{
	int iResult;
	void *pvBuffer;


	if( sizBUFFER_IN==0 )
	{
		iResult = ARCHIVE_FAILED;
	}
	else
	{
		/* Free any old buffers. */
		if( m_pvBuffer!=NULL )
		{
			free(m_pvBuffer);
			m_pvBuffer = NULL;
			m_sizBufferAllocated = 0;
		}

		/* Make a copy of the archive data. */
		pvBuffer = malloc(sizBUFFER_IN);
		if( pvBuffer==NULL )
		{
			iResult = ARCHIVE_FAILED;
		}
		else
		{
			m_pvBuffer = pvBuffer;
			m_sizBufferAllocated = sizBUFFER_IN;
			memcpy(m_pvBuffer, pcBUFFER_IN, sizBUFFER_IN);

			iResult = archive_read_open_memory(m_ptArchive, m_pvBuffer, sizBUFFER_IN);
		}
	}

	return iResult;
}


/*--------------------------------------------------------------------------*/


ArchiveReadDisk::ArchiveReadDisk(void)
 : ArchiveReadCommon()
{
	m_ptArchive = archive_read_disk_new();
}



ArchiveReadDisk::~ArchiveReadDisk(void)
{
	int iResult;


	if( m_ptArchive!=NULL )
	{
		/* NOTE: the ReadDisk object uses the "free" function from the "Read" object. */
		iResult = archive_read_free(m_ptArchive);
		if( iResult!=ARCHIVE_OK )
		{
			printf("Failed to free the archive structure!\n");
		}
		m_ptArchive = NULL;
	}
}



int ArchiveReadDisk::set_symlink_logical(void)
{
	return archive_read_disk_set_symlink_logical(m_ptArchive);
}



int ArchiveReadDisk::set_symlink_physical(void)
{
	return archive_read_disk_set_symlink_physical(m_ptArchive);
}



int ArchiveReadDisk::set_symlink_hybrid(void)
{
	return archive_read_disk_set_symlink_hybrid(m_ptArchive);
}



const char *ArchiveReadDisk::gname(int64_t iGID)
{
	return archive_read_disk_gname(m_ptArchive, iGID);
}



const char *ArchiveReadDisk::uname(int64_t iUID)
{
	return archive_read_disk_uname(m_ptArchive, iUID);
}



int ArchiveReadDisk::set_standard_lookup(void)
{
	return archive_read_disk_set_standard_lookup(m_ptArchive);
}



int ArchiveReadDisk::open(const char *pcFilename)
{
	return archive_read_disk_open(m_ptArchive, pcFilename);
}



int ArchiveReadDisk::open_w(const wchar_t *pcFilename)
{
	return archive_read_disk_open_w(m_ptArchive, pcFilename);
}



ArchiveEntry *ArchiveReadDisk::entry_from_file(const char *pcFilename)
{
	int iResult;
	int iFd;
	struct archive_entry *ptArchiveEntry;
	ArchiveEntry *ptArchiveEntryClass;


	/* Open the file in read only mode. */
	iFd = ::open(pcFilename, O_RDONLY);
	if( iFd<0 )
	{
		/* Failed to open the file. */
		ptArchiveEntryClass = NULL;
	}
	else
	{
		/* Create a new entry. */
		ptArchiveEntry = archive_entry_new();
		if( ptArchiveEntry==NULL )
		{
			/* Failed to create a new entry. */
			ptArchiveEntryClass = NULL;
		}
		else
		{
			/* Set the filename to the entry. */
			archive_entry_copy_pathname(ptArchiveEntry, pcFilename);
			/* Read the entry data from disk. */
			iResult = archive_read_disk_entry_from_file(m_ptArchive, ptArchiveEntry, iFd, NULL);
			if( iResult!=ARCHIVE_OK )
			{
				/* Failed to read the data from disk. */
				archive_entry_free(ptArchiveEntry);
				ptArchiveEntryClass = NULL;
			}
			else
			{
				ptArchiveEntryClass = new ArchiveEntry(ptArchiveEntry);
			}
		}

		::close(iFd);
	}

	return ptArchiveEntryClass;
}



int ArchiveReadDisk::descend(void)
{
	return archive_read_disk_descend(m_ptArchive);
}



int ArchiveReadDisk::can_descend(void)
{
	return archive_read_disk_can_descend(m_ptArchive);
}



int ArchiveReadDisk::current_filesystem(void)
{
	return archive_read_disk_current_filesystem(m_ptArchive);
}



int ArchiveReadDisk::current_filesystem_is_synthetic(void)
{
	return archive_read_disk_current_filesystem_is_synthetic(m_ptArchive);
}



int ArchiveReadDisk::current_filesystem_is_remote(void)
{
	return archive_read_disk_current_filesystem_is_remote(m_ptArchive);
}



int ArchiveReadDisk::set_atime_restored(void)
{
	return archive_read_disk_set_atime_restored(m_ptArchive);
}



int ArchiveReadDisk::set_behavior(int iFlags)
{
	return archive_read_disk_set_behavior(m_ptArchive, iFlags);
}


/*--------------------------------------------------------------------------*/


ArchiveWriteCommon::ArchiveWriteCommon(void)
 : Archive()
{
}



ArchiveWriteCommon::~ArchiveWriteCommon(void)
{
}



int ArchiveWriteCommon::write_header(ArchiveEntry *ptEntry)
{
	struct archive_entry *ptArchiveEntryStruct;


	/* Get the archive entry structure from the class. */
	ptArchiveEntryStruct = ptEntry->_get_raw();
	return archive_write_header(m_ptArchive, ptArchiveEntryStruct);
}



int ArchiveWriteCommon::write_data(const char *pcBUFFER_IN, size_t sizBUFFER_IN)
{
	int iResult;
	la_ssize_t sResult;
	const char *pcCnt;
	size_t sizLeft;


	iResult = 0;
	pcCnt = pcBUFFER_IN;
	sizLeft = sizBUFFER_IN;
	while( sizLeft!=0 )
	{
		sResult = archive_write_data(m_ptArchive, pcCnt, sizLeft);
		if( sResult<0 )
		{
			iResult = sResult;
			break;
		}
		else
		{
			pcCnt += sResult;
			sizLeft -= sResult;
		}
	}

	return iResult;
}



int ArchiveWriteCommon::finish_entry(void)
{
	return archive_write_finish_entry(m_ptArchive);
}



int ArchiveWriteCommon::close(void)
{
	return archive_write_close(m_ptArchive);
}


/*--------------------------------------------------------------------------*/


ArchiveWrite::ArchiveWrite(void)
 : ArchiveWriteCommon()
 , m_sizBufferAllocated(0)
 , m_pvBuffer(NULL)
 , m_sizBufferUsed(0)
{
	/* Allocate a new archive structure. */
	m_ptArchive = archive_write_new();
}



ArchiveWrite::~ArchiveWrite(void)
{
	int iResult;


	if( m_ptArchive!=NULL )
	{
		iResult = archive_write_free(m_ptArchive);
		if( iResult!=ARCHIVE_OK )
		{
			printf("Failed to free the archive structure!\n");
		}
		m_ptArchive = NULL;
	}

	if( m_pvBuffer!=NULL )
	{
		free(m_pvBuffer);
		m_pvBuffer = NULL;
	}
}



int ArchiveWrite::add_filter(int filter_code)
{
	return archive_write_add_filter(m_ptArchive, filter_code);
}



int ArchiveWrite::add_filter_by_name(const char *name)
{
	return archive_write_add_filter_by_name(m_ptArchive, name);
}



int ArchiveWrite::add_filter_b64encode(void)
{
	return archive_write_add_filter_b64encode(m_ptArchive);
}



int ArchiveWrite::add_filter_bzip2(void)
{
	return archive_write_add_filter_bzip2(m_ptArchive);
}



int ArchiveWrite::add_filter_compress(void)
{
	return archive_write_add_filter_compress(m_ptArchive);
}



int ArchiveWrite::add_filter_grzip(void)
{
	return archive_write_add_filter_grzip(m_ptArchive);
}



int ArchiveWrite::add_filter_gzip(void)
{
	return archive_write_add_filter_gzip(m_ptArchive);
}



int ArchiveWrite::add_filter_lrzip(void)
{
	return archive_write_add_filter_lrzip(m_ptArchive);
}



int ArchiveWrite::add_filter_lz4(void)
{
	return archive_write_add_filter_lz4(m_ptArchive);
}



int ArchiveWrite::add_filter_lzip(void)
{
	return archive_write_add_filter_lzip(m_ptArchive);
}



int ArchiveWrite::add_filter_lzma(void)
{
	return archive_write_add_filter_lzma(m_ptArchive);
}



int ArchiveWrite::add_filter_lzop(void)
{
	return archive_write_add_filter_lzop(m_ptArchive);
}



int ArchiveWrite::add_filter_none(void)
{
	return archive_write_add_filter_none(m_ptArchive);
}



int ArchiveWrite::add_filter_program(const char *cmd)
{
	return archive_write_add_filter_program(m_ptArchive, cmd);
}



int ArchiveWrite::add_filter_uuencode(void)
{
	return archive_write_add_filter_uuencode(m_ptArchive);
}



int ArchiveWrite::add_filter_xz(void)
{
	return archive_write_add_filter_xz(m_ptArchive);
}



int ArchiveWrite::add_filter_zstd(void)
{
	return archive_write_add_filter_zstd(m_ptArchive);
}



int ArchiveWrite::set_format(int format_code)
{
	return archive_write_set_format(m_ptArchive, format_code);
}



int ArchiveWrite::set_format_by_name(const char *name)
{
	return archive_write_set_format_by_name(m_ptArchive, name);
}



int ArchiveWrite::set_format_7zip(void)
{
	return archive_write_set_format_7zip(m_ptArchive);
}



int ArchiveWrite::set_format_ar_bsd(void)
{
	return archive_write_set_format_ar_bsd(m_ptArchive);
}



int ArchiveWrite::set_format_ar_svr4(void)
{
	return archive_write_set_format_ar_svr4(m_ptArchive);
}



int ArchiveWrite::set_format_cpio(void)
{
	return archive_write_set_format_cpio(m_ptArchive);
}



int ArchiveWrite::set_format_cpio_newc(void)
{
	return archive_write_set_format_cpio_newc(m_ptArchive);
}



int ArchiveWrite::set_format_gnutar(void)
{
	return archive_write_set_format_gnutar(m_ptArchive);
}



int ArchiveWrite::set_format_iso9660(void)
{
	return archive_write_set_format_iso9660(m_ptArchive);
}



int ArchiveWrite::set_format_mtree(void)
{
	return archive_write_set_format_mtree(m_ptArchive);
}



int ArchiveWrite::set_format_mtree_classic(void)
{
	return archive_write_set_format_mtree_classic(m_ptArchive);
}



int ArchiveWrite::set_format_pax(void)
{
	return archive_write_set_format_pax(m_ptArchive);
}



int ArchiveWrite::set_format_pax_restricted(void)
{
	return archive_write_set_format_pax_restricted(m_ptArchive);
}



int ArchiveWrite::set_format_raw(void)
{
	return archive_write_set_format_raw(m_ptArchive);
}



int ArchiveWrite::set_format_shar(void)
{
	return archive_write_set_format_shar(m_ptArchive);
}



int ArchiveWrite::set_format_shar_dump(void)
{
	return archive_write_set_format_shar_dump(m_ptArchive);
}



int ArchiveWrite::set_format_ustar(void)
{
	return archive_write_set_format_ustar(m_ptArchive);
}



int ArchiveWrite::set_format_v7tar(void)
{
	return archive_write_set_format_v7tar(m_ptArchive);
}



int ArchiveWrite::set_format_warc(void)
{
	return archive_write_set_format_warc(m_ptArchive);
}



int ArchiveWrite::set_format_xar(void)
{
	return archive_write_set_format_xar(m_ptArchive);
}



int ArchiveWrite::set_format_zip(void)
{
	return archive_write_set_format_zip(m_ptArchive);
}



int ArchiveWrite::set_format_filter_by_ext(const char *filename)
{
	return archive_write_set_format_filter_by_ext(m_ptArchive, filename);
}



int ArchiveWrite::set_format_filter_by_ext_def(const char *filename, const char * def_ext)
{
	return archive_write_set_format_filter_by_ext_def(m_ptArchive, filename, def_ext);
}



int ArchiveWrite::zip_set_compression_deflate(void)
{
	return archive_write_zip_set_compression_deflate(m_ptArchive);
}



int ArchiveWrite::zip_set_compression_store(void)
{
	return archive_write_zip_set_compression_store(m_ptArchive);
}



int ArchiveWrite::set_format_option(const char *m, const char *o, const char *v)
{
	return archive_write_set_format_option(m_ptArchive, m, o, v);
}



int ArchiveWrite::set_filter_option(const char *m, const char *o, const char *v)
{
	return archive_write_set_filter_option(m_ptArchive, m, o, v);
}



int ArchiveWrite::set_option(const char *m, const char *o, const char *v)
{
	return archive_write_set_option(m_ptArchive, m, o, v);
}



int ArchiveWrite::set_options(const char *opts)
{
	return archive_write_set_options(m_ptArchive, opts);
}



int ArchiveWrite::open_filename(const char *_file)
{
	return archive_write_open_filename(m_ptArchive, _file);
}



int ArchiveWrite::open_filename_w(const wchar_t *_file)
{
	return archive_write_open_filename_w(m_ptArchive, _file);
}



int ArchiveWrite::open_memory(unsigned int uiBufferSize)
{
	int iResult;
	void *pvBuffer;


	if( uiBufferSize==0 )
	{
		iResult = ARCHIVE_FAILED;
	}
	else
	{
		if( m_pvBuffer!=NULL )
		{
			free(m_pvBuffer);
			m_pvBuffer = NULL;
		}

		pvBuffer = malloc(uiBufferSize);
		if( pvBuffer==NULL )
		{
			iResult = ARCHIVE_FAILED;
		}
		else
		{
			m_pvBuffer = pvBuffer;
			m_sizBufferAllocated = uiBufferSize;
			iResult = archive_write_open_memory(m_ptArchive, m_pvBuffer, m_sizBufferAllocated, &m_sizBufferUsed);
		}
	}

	return iResult;
}



void ArchiveWrite::get_memory(char **ppcBUFFER_OUT, size_t *psizBUFFER_OUT)
{
	void *pvBuffer;


	if( m_sizBufferUsed==0 )
	{
		pvBuffer = NULL;
	}
	else
	{
		pvBuffer = malloc(m_sizBufferUsed);
		if( pvBuffer!=NULL )
		{
			memcpy(pvBuffer, m_pvBuffer, m_sizBufferUsed);
		}
	}

	*ppcBUFFER_OUT = (char*)pvBuffer;
	*psizBUFFER_OUT = m_sizBufferUsed;
}


/*--------------------------------------------------------------------------*/


ArchiveWriteDisk::ArchiveWriteDisk(void)
 : ArchiveWriteCommon()
{
	/* Allocate a new archive structure. */
	m_ptArchive = archive_write_disk_new();
}



ArchiveWriteDisk::~ArchiveWriteDisk(void)
{
	int iResult;


	if( m_ptArchive!=NULL )
	{
		/* NOTE: the WriteDisk object uses the "free" function from the "Write" object. */
		iResult = archive_write_free(m_ptArchive);
		if( iResult!=ARCHIVE_OK )
		{
			printf("Failed to free the archive structure!\n");
		}
		m_ptArchive = NULL;
	}
}



int ArchiveWriteDisk::set_options(int iFlags)
{
	return archive_write_disk_set_options(m_ptArchive, iFlags);
}



int ArchiveWriteDisk::set_standard_lookup(void)
{
	return archive_write_disk_set_standard_lookup(m_ptArchive);
}
