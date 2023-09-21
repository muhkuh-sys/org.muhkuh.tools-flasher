#include "archive.h"
#include "archive_entry.h"

#ifdef __cplusplus
extern "C" {
#endif
#include "lua.h"
#ifdef __cplusplus
}
#endif


#include <stdint.h>



#ifndef SWIGRUNTIME
#include <swigluarun.h>
#endif



#ifndef __WRAPPER_H__
#define __WRAPPER_H__


enum ARCHIVE_FILTER_ENUM
{
	_ARCHIVE_FILTER_NONE     = ARCHIVE_FILTER_NONE,
	_ARCHIVE_FILTER_GZIP     = ARCHIVE_FILTER_GZIP,
	_ARCHIVE_FILTER_BZIP2    = ARCHIVE_FILTER_BZIP2,
	_ARCHIVE_FILTER_COMPRESS = ARCHIVE_FILTER_COMPRESS,
	_ARCHIVE_FILTER_PROGRAM  = ARCHIVE_FILTER_PROGRAM,
	_ARCHIVE_FILTER_LZMA     = ARCHIVE_FILTER_LZMA,
	_ARCHIVE_FILTER_XZ       = ARCHIVE_FILTER_XZ,
	_ARCHIVE_FILTER_UU       = ARCHIVE_FILTER_UU,
	_ARCHIVE_FILTER_RPM      = ARCHIVE_FILTER_RPM,
	_ARCHIVE_FILTER_LZIP     = ARCHIVE_FILTER_LZIP,
	_ARCHIVE_FILTER_LRZIP    = ARCHIVE_FILTER_LRZIP,
	_ARCHIVE_FILTER_LZOP     = ARCHIVE_FILTER_LZOP,
	_ARCHIVE_FILTER_GRZIP    = ARCHIVE_FILTER_GRZIP,
	_ARCHIVE_FILTER_LZ4      = ARCHIVE_FILTER_LZ4,
	_ARCHIVE_FILTER_ZSTD     = ARCHIVE_FILTER_ZSTD
};

enum ARCHIVE_FORMAT_ENUM
{
	_ARCHIVE_FORMAT_BASE_MASK                = ARCHIVE_FORMAT_BASE_MASK,
	_ARCHIVE_FORMAT_CPIO                     = ARCHIVE_FORMAT_CPIO,
	_ARCHIVE_FORMAT_CPIO_POSIX               = ARCHIVE_FORMAT_CPIO_POSIX,
	_ARCHIVE_FORMAT_CPIO_BIN_LE              = ARCHIVE_FORMAT_CPIO_BIN_LE,
	_ARCHIVE_FORMAT_CPIO_BIN_BE              = ARCHIVE_FORMAT_CPIO_BIN_BE,
	_ARCHIVE_FORMAT_CPIO_SVR4_NOCRC          = ARCHIVE_FORMAT_CPIO_SVR4_NOCRC,
	_ARCHIVE_FORMAT_CPIO_SVR4_CRC            = ARCHIVE_FORMAT_CPIO_SVR4_CRC,
	_ARCHIVE_FORMAT_CPIO_AFIO_LARGE          = ARCHIVE_FORMAT_CPIO_AFIO_LARGE,
	_ARCHIVE_FORMAT_SHAR                     = ARCHIVE_FORMAT_SHAR,
	_ARCHIVE_FORMAT_SHAR_BASE                = ARCHIVE_FORMAT_SHAR_BASE,
	_ARCHIVE_FORMAT_SHAR_DUMP                = ARCHIVE_FORMAT_SHAR_DUMP,
	_ARCHIVE_FORMAT_TAR                      = ARCHIVE_FORMAT_TAR,
	_ARCHIVE_FORMAT_TAR_USTAR                = ARCHIVE_FORMAT_TAR_USTAR,
	_ARCHIVE_FORMAT_TAR_PAX_INTERCHANGE      = ARCHIVE_FORMAT_TAR_PAX_INTERCHANGE,
	_ARCHIVE_FORMAT_TAR_PAX_RESTRICTED       = ARCHIVE_FORMAT_TAR_PAX_RESTRICTED,
	_ARCHIVE_FORMAT_TAR_GNUTAR               = ARCHIVE_FORMAT_TAR_GNUTAR,
	_ARCHIVE_FORMAT_ISO9660                  = ARCHIVE_FORMAT_ISO9660,
	_ARCHIVE_FORMAT_ISO9660_ROCKRIDGE        = ARCHIVE_FORMAT_ISO9660_ROCKRIDGE,
	_ARCHIVE_FORMAT_ZIP                      = ARCHIVE_FORMAT_ZIP,
	_ARCHIVE_FORMAT_EMPTY                    = ARCHIVE_FORMAT_EMPTY,
	_ARCHIVE_FORMAT_AR                       = ARCHIVE_FORMAT_AR,
	_ARCHIVE_FORMAT_AR_GNU                   = ARCHIVE_FORMAT_AR_GNU,
	_ARCHIVE_FORMAT_AR_BSD                   = ARCHIVE_FORMAT_AR_BSD,
	_ARCHIVE_FORMAT_MTREE                    = ARCHIVE_FORMAT_MTREE,
	_ARCHIVE_FORMAT_RAW                      = ARCHIVE_FORMAT_RAW,
	_ARCHIVE_FORMAT_XAR                      = ARCHIVE_FORMAT_XAR,
	_ARCHIVE_FORMAT_LHA                      = ARCHIVE_FORMAT_LHA,
	_ARCHIVE_FORMAT_CAB                      = ARCHIVE_FORMAT_CAB,
	_ARCHIVE_FORMAT_RAR                      = ARCHIVE_FORMAT_RAR,
	_ARCHIVE_FORMAT_7ZIP                     = ARCHIVE_FORMAT_7ZIP,
	_ARCHIVE_FORMAT_WARC                     = ARCHIVE_FORMAT_WARC,
	_ARCHIVE_FORMAT_RAR_V5                   = ARCHIVE_FORMAT_RAR_V5
};


enum ARCHIVE_READ_FORMAT_ENUM
{
	_ARCHIVE_READ_FORMAT_CAPS_NONE              = ARCHIVE_READ_FORMAT_CAPS_NONE,
	_ARCHIVE_READ_FORMAT_CAPS_ENCRYPT_DATA      = ARCHIVE_READ_FORMAT_CAPS_ENCRYPT_DATA,
	_ARCHIVE_READ_FORMAT_CAPS_ENCRYPT_METADATA  = ARCHIVE_READ_FORMAT_CAPS_ENCRYPT_METADATA,
	_ARCHIVE_READ_FORMAT_ENCRYPTION_UNSUPPORTED = ARCHIVE_READ_FORMAT_ENCRYPTION_UNSUPPORTED,
	_ARCHIVE_READ_FORMAT_ENCRYPTION_DONT_KNOW   = ARCHIVE_READ_FORMAT_ENCRYPTION_DONT_KNOW
};


enum ARCHIVE_EXTRACT_ENUM
{
	_ARCHIVE_EXTRACT_OWNER                   = ARCHIVE_EXTRACT_OWNER,
	_ARCHIVE_EXTRACT_PERM                    = ARCHIVE_EXTRACT_PERM,
	_ARCHIVE_EXTRACT_TIME                    = ARCHIVE_EXTRACT_TIME,
	_ARCHIVE_EXTRACT_NO_OVERWRITE            = ARCHIVE_EXTRACT_NO_OVERWRITE,
	_ARCHIVE_EXTRACT_UNLINK                  = ARCHIVE_EXTRACT_UNLINK,
	_ARCHIVE_EXTRACT_ACL                     = ARCHIVE_EXTRACT_ACL,
	_ARCHIVE_EXTRACT_FFLAGS                  = ARCHIVE_EXTRACT_FFLAGS,
	_ARCHIVE_EXTRACT_XATTR                   = ARCHIVE_EXTRACT_XATTR,
	_ARCHIVE_EXTRACT_SECURE_SYMLINKS         = ARCHIVE_EXTRACT_SECURE_SYMLINKS,
	_ARCHIVE_EXTRACT_SECURE_NODOTDOT         = ARCHIVE_EXTRACT_SECURE_NODOTDOT,
	_ARCHIVE_EXTRACT_NO_AUTODIR              = ARCHIVE_EXTRACT_NO_AUTODIR,
	_ARCHIVE_EXTRACT_NO_OVERWRITE_NEWER      = ARCHIVE_EXTRACT_NO_OVERWRITE_NEWER,
	_ARCHIVE_EXTRACT_SPARSE                  = ARCHIVE_EXTRACT_SPARSE,
	_ARCHIVE_EXTRACT_MAC_METADATA            = ARCHIVE_EXTRACT_MAC_METADATA,
	_ARCHIVE_EXTRACT_NO_HFS_COMPRESSION      = ARCHIVE_EXTRACT_NO_HFS_COMPRESSION,
	_ARCHIVE_EXTRACT_HFS_COMPRESSION_FORCED  = ARCHIVE_EXTRACT_HFS_COMPRESSION_FORCED,
	_ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS  = ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS,
	_ARCHIVE_EXTRACT_CLEAR_NOCHANGE_FFLAGS   = ARCHIVE_EXTRACT_CLEAR_NOCHANGE_FFLAGS,
	_ARCHIVE_EXTRACT_SAFE_WRITES             = ARCHIVE_EXTRACT_SAFE_WRITES
};


enum ARCHIVE_READDISK_ENUM
{
	_ARCHIVE_READDISK_RESTORE_ATIME          = ARCHIVE_READDISK_RESTORE_ATIME,
	_ARCHIVE_READDISK_HONOR_NODUMP           = ARCHIVE_READDISK_HONOR_NODUMP,
	_ARCHIVE_READDISK_MAC_COPYFILE           = ARCHIVE_READDISK_MAC_COPYFILE,
	_ARCHIVE_READDISK_NO_TRAVERSE_MOUNTS     = ARCHIVE_READDISK_NO_TRAVERSE_MOUNTS,
	_ARCHIVE_READDISK_NO_XATTR               = ARCHIVE_READDISK_NO_XATTR,
	_ARCHIVE_READDISK_NO_ACL                 = ARCHIVE_READDISK_NO_ACL,
	_ARCHIVE_READDISK_NO_FFLAGS              = ARCHIVE_READDISK_NO_FFLAGS
};


enum ARCHIVE_MATCH_ENUM
{
	_ARCHIVE_MATCH_MTIME     = ARCHIVE_MATCH_MTIME,
	_ARCHIVE_MATCH_CTIME     = ARCHIVE_MATCH_CTIME,
	_ARCHIVE_MATCH_NEWER     = ARCHIVE_MATCH_NEWER,
	_ARCHIVE_MATCH_OLDER     = ARCHIVE_MATCH_OLDER,
	_ARCHIVE_MATCH_EQUAL     = ARCHIVE_MATCH_EQUAL
};


enum AE_ENM
{
	_AE_IFMT         = AE_IFMT,
	_AE_IFREG        = AE_IFREG,
	_AE_IFLNK        = AE_IFLNK,
	_AE_IFSOCK       = AE_IFSOCK,
	_AE_IFCHR        = AE_IFCHR,
	_AE_IFBLK        = AE_IFBLK,
	_AE_IFDIR        = AE_IFDIR,
	_AE_IFIFO        = AE_IFIFO
};


enum ARCHIVE_ENTRY_ACL_ENUM
{
	_ARCHIVE_ENTRY_ACL_EXECUTE                     = ARCHIVE_ENTRY_ACL_EXECUTE,
	_ARCHIVE_ENTRY_ACL_WRITE                       = ARCHIVE_ENTRY_ACL_WRITE,
	_ARCHIVE_ENTRY_ACL_READ                        = ARCHIVE_ENTRY_ACL_READ,
	_ARCHIVE_ENTRY_ACL_READ_DATA                   = ARCHIVE_ENTRY_ACL_READ_DATA,
	_ARCHIVE_ENTRY_ACL_LIST_DIRECTORY              = ARCHIVE_ENTRY_ACL_LIST_DIRECTORY,
	_ARCHIVE_ENTRY_ACL_WRITE_DATA                  = ARCHIVE_ENTRY_ACL_WRITE_DATA,
	_ARCHIVE_ENTRY_ACL_ADD_FILE                    = ARCHIVE_ENTRY_ACL_ADD_FILE,
	_ARCHIVE_ENTRY_ACL_APPEND_DATA                 = ARCHIVE_ENTRY_ACL_APPEND_DATA,
	_ARCHIVE_ENTRY_ACL_ADD_SUBDIRECTORY            = ARCHIVE_ENTRY_ACL_ADD_SUBDIRECTORY,
	_ARCHIVE_ENTRY_ACL_READ_NAMED_ATTRS            = ARCHIVE_ENTRY_ACL_READ_NAMED_ATTRS,
	_ARCHIVE_ENTRY_ACL_WRITE_NAMED_ATTRS           = ARCHIVE_ENTRY_ACL_WRITE_NAMED_ATTRS,
	_ARCHIVE_ENTRY_ACL_DELETE_CHILD                = ARCHIVE_ENTRY_ACL_DELETE_CHILD,
	_ARCHIVE_ENTRY_ACL_READ_ATTRIBUTES             = ARCHIVE_ENTRY_ACL_READ_ATTRIBUTES,
	_ARCHIVE_ENTRY_ACL_WRITE_ATTRIBUTES            = ARCHIVE_ENTRY_ACL_WRITE_ATTRIBUTES,
	_ARCHIVE_ENTRY_ACL_DELETE                      = ARCHIVE_ENTRY_ACL_DELETE,
	_ARCHIVE_ENTRY_ACL_READ_ACL                    = ARCHIVE_ENTRY_ACL_READ_ACL,
	_ARCHIVE_ENTRY_ACL_WRITE_ACL                   = ARCHIVE_ENTRY_ACL_WRITE_ACL,
	_ARCHIVE_ENTRY_ACL_WRITE_OWNER                 = ARCHIVE_ENTRY_ACL_WRITE_OWNER,
	_ARCHIVE_ENTRY_ACL_SYNCHRONIZE                 = ARCHIVE_ENTRY_ACL_SYNCHRONIZE,
	_ARCHIVE_ENTRY_ACL_PERMS_POSIX1E               = ARCHIVE_ENTRY_ACL_PERMS_POSIX1E,
	_ARCHIVE_ENTRY_ACL_PERMS_NFS4                  = ARCHIVE_ENTRY_ACL_PERMS_NFS4,
	_ARCHIVE_ENTRY_ACL_ENTRY_FILE_INHERIT          = ARCHIVE_ENTRY_ACL_ENTRY_FILE_INHERIT,
	_ARCHIVE_ENTRY_ACL_ENTRY_DIRECTORY_INHERIT     = ARCHIVE_ENTRY_ACL_ENTRY_DIRECTORY_INHERIT,
	_ARCHIVE_ENTRY_ACL_ENTRY_NO_PROPAGATE_INHERIT  = ARCHIVE_ENTRY_ACL_ENTRY_NO_PROPAGATE_INHERIT,
	_ARCHIVE_ENTRY_ACL_ENTRY_INHERIT_ONLY          = ARCHIVE_ENTRY_ACL_ENTRY_INHERIT_ONLY,
	_ARCHIVE_ENTRY_ACL_ENTRY_SUCCESSFUL_ACCESS     = ARCHIVE_ENTRY_ACL_ENTRY_SUCCESSFUL_ACCESS,
	_ARCHIVE_ENTRY_ACL_ENTRY_FAILED_ACCESS         = ARCHIVE_ENTRY_ACL_ENTRY_FAILED_ACCESS,
	_ARCHIVE_ENTRY_ACL_INHERITANCE_NFS4            = ARCHIVE_ENTRY_ACL_INHERITANCE_NFS4,
	_ARCHIVE_ENTRY_ACL_TYPE_ACCESS                 = ARCHIVE_ENTRY_ACL_TYPE_ACCESS,
	_ARCHIVE_ENTRY_ACL_TYPE_DEFAULT                = ARCHIVE_ENTRY_ACL_TYPE_DEFAULT,
	_ARCHIVE_ENTRY_ACL_TYPE_ALLOW                  = ARCHIVE_ENTRY_ACL_TYPE_ALLOW,
	_ARCHIVE_ENTRY_ACL_TYPE_DENY                   = ARCHIVE_ENTRY_ACL_TYPE_DENY,
	_ARCHIVE_ENTRY_ACL_TYPE_AUDIT                  = ARCHIVE_ENTRY_ACL_TYPE_AUDIT,
	_ARCHIVE_ENTRY_ACL_TYPE_ALARM                  = ARCHIVE_ENTRY_ACL_TYPE_ALARM,
	_ARCHIVE_ENTRY_ACL_TYPE_POSIX1E                = ARCHIVE_ENTRY_ACL_TYPE_POSIX1E,
	_ARCHIVE_ENTRY_ACL_TYPE_NFS4                   = ARCHIVE_ENTRY_ACL_TYPE_NFS4,
	_ARCHIVE_ENTRY_ACL_USER                        = ARCHIVE_ENTRY_ACL_USER,
	_ARCHIVE_ENTRY_ACL_USER_OBJ                    = ARCHIVE_ENTRY_ACL_USER_OBJ,
	_ARCHIVE_ENTRY_ACL_GROUP                       = ARCHIVE_ENTRY_ACL_GROUP,
	_ARCHIVE_ENTRY_ACL_GROUP_OBJ                   = ARCHIVE_ENTRY_ACL_GROUP_OBJ,
	_ARCHIVE_ENTRY_ACL_MASK                        = ARCHIVE_ENTRY_ACL_MASK,
	_ARCHIVE_ENTRY_ACL_OTHER                       = ARCHIVE_ENTRY_ACL_OTHER,
	_ARCHIVE_ENTRY_ACL_EVERYONE                    = ARCHIVE_ENTRY_ACL_EVERYONE,
	_ARCHIVE_ENTRY_ACL_STYLE_EXTRA_ID              = ARCHIVE_ENTRY_ACL_STYLE_EXTRA_ID,
	_ARCHIVE_ENTRY_ACL_STYLE_MARK_DEFAULT          = ARCHIVE_ENTRY_ACL_STYLE_MARK_DEFAULT
};


int version_number(void);
const char* version_string(void);
const char* version_details(void);

const char* zlib_version(void);
const char* liblzma_version(void);
const char* bzlib_version(void);
const char* liblz4_version(void);


class ArchiveEntry
{
public:
	ArchiveEntry(void);
	ArchiveEntry(struct archive_entry *ptArchiveEntry);
	~ArchiveEntry(void);


	time_t         atime(void);
	long           atime_nsec(void);
	int            atime_is_set(void);
	time_t         birthtime(void);
	long           birthtime_nsec(void);
	int            birthtime_is_set(void);
	time_t         ctime(void);
	long           ctime_nsec(void);
	int            ctime_is_set(void);
	dev_t          dev(void);
	int            dev_is_set(void);
	dev_t          devmajor(void);
	dev_t          devminor(void);
	__LA_MODE_T    filetype(void);
#if 0
	void           fflags(void,
                            unsigned long * /* set */,
                            unsigned long * /* clear */);
#endif
	const char    *fflags_text(void);
	int64_t        gid(void);
	const char    *gname(void);
	const char    *gname_utf8(void);
	const wchar_t *gname_w(void);
	const char    *hardlink(void);
	const char    *hardlink_utf8(void);
	const wchar_t *hardlink_w(void);
	int64_t        ino(void);
	int64_t        ino64(void);
	int            ino_is_set(void);
	int            mode(void);
	time_t         mtime(void);
	long           mtime_nsec(void);
	int            mtime_is_set(void);
	unsigned int   nlink(void);
	const char    *pathname(void);
	const char    *pathname_utf8(void);
	const wchar_t *pathname_w(void);
	int            perm(void);
	dev_t          rdev(void);
	dev_t          rdevmajor(void);
	dev_t          rdevminor(void);
	const char    *sourcepath(void);
	const wchar_t *sourcepath_w(void);
	int64_t        size(void);
	int            size_is_set(void);
	const char    *strmode(void);
	const char    *symlink(void);
	const char    *symlink_utf8(void);
	const wchar_t *symlink_w(void);
	int64_t        uid(void);
	const char    *uname(void);
	const char    *uname_utf8(void);
	const wchar_t *uname_w(void);
	int            is_data_encrypted(void);
	int            is_metadata_encrypted(void);
	int            is_encrypted(void);


	ArchiveEntry* set_atime(time_t, long);
	ArchiveEntry* unset_atime(void);
	ArchiveEntry* set_birthtime(time_t, long);
	ArchiveEntry* unset_birthtime(void);
	ArchiveEntry* set_ctime(time_t, long);
	ArchiveEntry* unset_ctime(void);
	ArchiveEntry* set_dev(dev_t);
	ArchiveEntry* set_devmajor(dev_t);
	ArchiveEntry* set_devminor(dev_t);
	ArchiveEntry* set_filetype(unsigned int);
#if 0
__LA_DECL void  archive_entry_set_fflags(void,
            unsigned long /* set */, unsigned long /* clear */);
/* Returns pointer to start of first invalid token, or NULL if none. */
/* Note that all recognized tokens are processed, regardless. */
__LA_DECL const char *archive_entry_copy_fflags_text(void,
            const char *);
__LA_DECL const wchar_t *archive_entry_copy_fflags_text_w(void,
            const wchar_t *);
#endif
	ArchiveEntry* set_gid(int64_t);
	ArchiveEntry* set_gname(const char *);
	ArchiveEntry* set_gname_utf8(const char *);
	ArchiveEntry* copy_gname(const char *);
	ArchiveEntry* copy_gname_w(const wchar_t *);
	int update_gname_utf8(const char *);
	ArchiveEntry* set_hardlink(const char *);
	ArchiveEntry* set_hardlink_utf8(const char *);
	ArchiveEntry* copy_hardlink(const char *);
	ArchiveEntry* copy_hardlink_w(const wchar_t *);
	int update_hardlink_utf8(const char *);
	ArchiveEntry* set_ino(int64_t);
	ArchiveEntry* set_ino64(int64_t);
	ArchiveEntry* set_link(const char *);
	ArchiveEntry* set_link_utf8(const char *);
	ArchiveEntry* copy_link(const char *);
	ArchiveEntry* copy_link_w(const wchar_t *);
	int update_link_utf8(const char *);
	ArchiveEntry* set_mode(int);
	ArchiveEntry* set_mtime(time_t, long);
	ArchiveEntry* unset_mtime(void);
	ArchiveEntry* set_nlink(unsigned int);
	ArchiveEntry* set_pathname(const char *);
	ArchiveEntry* set_pathname_utf8(const char *);
	ArchiveEntry* copy_pathname(const char *);
	ArchiveEntry* copy_pathname_w(const wchar_t *);
	int update_pathname_utf8(const char *);
	ArchiveEntry* set_perm(int);
	ArchiveEntry* set_rdev(dev_t);
	ArchiveEntry* set_rdevmajor(dev_t);
	ArchiveEntry* set_rdevminor(dev_t);
	ArchiveEntry* set_size(int64_t);
	ArchiveEntry* unset_size(void);
	ArchiveEntry* copy_sourcepath(const char *);
	ArchiveEntry* copy_sourcepath_w(const wchar_t *);
	ArchiveEntry* set_symlink(const char *);

#ifndef SWIG
	struct archive_entry *_get_raw(void);
#endif

private:
	struct archive_entry *m_ptArchiveEntry;
};



class Archive
{
public:
	Archive(void);
	~Archive(void);

	int error_errno(void);
	const char* error_string(void);

	int file_count(void);

	int filter_count(void);
	int64_t filter_bytes(int iFilterNumber);
	int filter_code(int iFilterNumber);
	const char *filter_name(int iFilterNumber);

#ifndef SWIG
	struct archive *_get_raw(void);
#endif

protected:
	struct archive *m_ptArchive;
};



class ArchiveWriteCommon : public Archive
{
protected:
	ArchiveWriteCommon(void);
	~ArchiveWriteCommon(void);

public:
	int write_header(ArchiveEntry *ptEntry);
	int write_data(const char *pcBUFFER_IN, size_t sizBUFFER_IN);
	int finish_entry(void);
	int close(void);
};



class ArchiveWrite : public ArchiveWriteCommon
{
public:
	ArchiveWrite(void);
	~ArchiveWrite(void);

	int add_filter(int filter_code);
	int add_filter_by_name(const char *name);
	int add_filter_b64encode(void);
	int add_filter_bzip2(void);
	int add_filter_compress(void);
	int add_filter_grzip(void);
	int add_filter_gzip(void);
	int add_filter_lrzip(void);
	int add_filter_lz4(void);
	int add_filter_lzip(void);
	int add_filter_lzma(void);
	int add_filter_lzop(void);
	int add_filter_none(void);
	int add_filter_program(const char *cmd);
	int add_filter_uuencode(void);
	int add_filter_xz(void);
	int add_filter_zstd(void);

	int set_format(int format_code);
	int set_format_by_name(const char *name);
	int set_format_7zip(void);
	int set_format_ar_bsd(void);
	int set_format_ar_svr4(void);
	int set_format_cpio(void);
	int set_format_cpio_newc(void);
	int set_format_gnutar(void);
	int set_format_iso9660(void);
	int set_format_mtree(void);
	int set_format_mtree_classic(void);
	int set_format_pax(void);
	int set_format_pax_restricted(void);
	int set_format_raw(void);
	int set_format_shar(void);
	int set_format_shar_dump(void);
	int set_format_ustar(void);
	int set_format_v7tar(void);
	int set_format_warc(void);
	int set_format_xar(void);
	int set_format_zip(void);
	int set_format_filter_by_ext(const char *filename);
	int set_format_filter_by_ext_def(const char *filename, const char * def_ext);

	int zip_set_compression_deflate(void);
	int zip_set_compression_store(void);

	int set_format_option(const char *m, const char *o, const char *v);
	int set_filter_option(const char *m, const char *o, const char *v);
	int set_option(const char *m, const char *o, const char *v);
	int set_options(const char *opts);

	int open_filename(const char *_file);
	int open_filename_w(const wchar_t *_file);
	int open_memory(unsigned int uiBufferSize);
	void get_memory(char **ppcBUFFER_OUT, size_t *psizBUFFER_OUT);

#ifndef SWIG
private:
	size_t m_sizBufferAllocated;
	void *m_pvBuffer;
	size_t m_sizBufferUsed;
#endif
};



class ArchiveWriteDisk : public ArchiveWriteCommon
{
public:
	ArchiveWriteDisk(void);
	~ArchiveWriteDisk(void);

	int set_options(int flags);
	int set_standard_lookup(void);
};



class ArchiveReadCommon : public Archive
{
protected:
	ArchiveReadCommon(void);
	~ArchiveReadCommon(void);

public:
	ArchiveEntry *next_header(void);
	void iter_header(lua_State *MUHKUH_SWIG_OUTPUT_CUSTOM_OBJECT, swig_type_info *p_ArchiveEntry);

	void read_data(size_t sizChunk, char **ppcBUFFER_OUT, size_t *psizBUFFER_OUT);
	void iter_data(size_t sizChunk, lua_State *MUHKUH_SWIG_OUTPUT_CUSTOM_OBJECT);

	int data_skip(void);

	static int iterator_next_header(lua_State *ptLuaState);
	static int iterator_read_data(lua_State *ptLuaState);

	int close(void);
};



class ArchiveRead : public ArchiveReadCommon
{
public:
	ArchiveRead(void);
	~ArchiveRead(void);

	int support_filter_all(void);
	int support_filter_bzip2(void);
	int support_filter_compress(void);
	int support_filter_gzip(void);
	int support_filter_grzip(void);
	int support_filter_lrzip(void);
	int support_filter_lz4(void);
	int support_filter_lzip(void);
	int support_filter_lzma(void);
	int support_filter_lzop(void);
	int support_filter_none(void);
	int support_filter_rpm(void);
	int support_filter_uu(void);
	int support_filter_xz(void);
	int support_filter_zstd(void);

	int support_format_all(void);
	int support_format_7zip(void);
	int support_format_ar(void);
	int support_format_by_code(int);
	int support_format_cab(void);
	int support_format_cpio(void);
	int support_format_empty(void);
	int support_format_gnutar(void);
	int support_format_iso9660(void);
	int support_format_lha(void);
	int support_format_mtree(void);
	int support_format_rar(void);
	int support_format_rar5(void);
	int support_format_raw(void);
	int support_format_tar(void);
	int support_format_warc(void);
	int support_format_xar(void);
	int support_format_zip(void);
	int support_format_zip_streamable(void);
	int support_format_zip_seekable(void);

	int set_format(int);
	int append_filter(int);

	int set_format_option(const char *m, const char *o, const char *v);
	int set_filter_option(const char *m, const char *o, const char *v);
	int set_option(const char *m, const char *o, const char *v);
	int set_options(const char *opts);

	int open_filename(const char *_filename, size_t _block_size);


	int extract(ArchiveEntry *ptEntry, int flags);
	int extract2(ArchiveEntry *ptEntry, ArchiveWrite *ptDestArchive);

	int open_memory(const char *pcBUFFER_IN, size_t sizBUFFER_IN);

#ifndef SWIG
private:
	size_t m_sizBufferAllocated;
	void *m_pvBuffer;
#endif
};



class ArchiveReadDisk : public ArchiveReadCommon
{
public:
	ArchiveReadDisk(void);
	~ArchiveReadDisk(void);

	int set_symlink_logical(void);
	int set_symlink_physical(void);
	int set_symlink_hybrid(void);

	const char *gname(int64_t);
	const char *uname(int64_t);

	int set_standard_lookup(void);

	int open(const char *);
	int open_w(const wchar_t *);
	ArchiveEntry *entry_from_file(const char *pcFilename);

	int descend(void);
	int can_descend(void);
	int current_filesystem(void);
	int current_filesystem_is_synthetic(void);
	int current_filesystem_is_remote(void);
	int set_atime_restored(void);

	int set_behavior(int iFlags);
};


#endif  /* __WRAPPER_H__ */
