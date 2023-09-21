%module archive

%include "stdint.i"
%include "typemaps.i"

%{
	#include "wrapper.h"
%}

typedef long time_t;

/* This typemap adds "SWIGTYPE_" to the name of the input parameter to
 * construct the swig typename. The parameter name must match the definition
 * in the wrapper.
 */
%typemap(in, numinputs=0) swig_type_info *
%{
	$1 = SWIGTYPE_$1_name;
%}


/* This typemap passes Lua state to the function. The function must create one
 * lua object on the stack. This is passes as the return value to lua.
 * No further checks are done!
 */
%typemap(in, numinputs=0) lua_State *MUHKUH_SWIG_OUTPUT_CUSTOM_OBJECT
%{
	$1 = L;
	++SWIG_arg;
%}


%typemap(in) (const char *pcBUFFER_IN, size_t sizBUFFER_IN)
{
        size_t sizBuffer;
        $1 = (char*)lua_tolstring(L, $argnum, &sizBuffer);
        $2 = sizBuffer;
}


%typemap(in, numinputs=0) (char **ppcBUFFER_OUT, size_t *psizBUFFER_OUT)
%{
	char *pcOutputData;
	size_t sizOutputData;
	$1 = &pcOutputData;
	$2 = &sizOutputData;
%}

/* NOTE: This "argout" typemap can only be used in combination with the above "in" typemap. */
%typemap(argout) (char **ppcBUFFER_OUT, size_t *psizBUFFER_OUT)
%{
	if( pcOutputData!=NULL && sizOutputData!=0 )
	{
		lua_pushlstring(L, pcOutputData, sizOutputData);
		free(pcOutputData);
	}
	else
	{
		lua_pushnil(L);
	}
	++SWIG_arg;
%}


%newobject ArchiveReadCommon::next_header;
%ignore ArchiveReadCommon::iterator_next_header;
%ignore ArchiveReadCommon::iterator_read_data;

%rename("%(regex:/_(ARCHIVE_FILTER_.*)/\\1/)s", %$isenumitem) "";
%rename("%(regex:/_(ARCHIVE_FORMAT_.*)/\\1/)s", %$isenumitem) "";
%rename("%(regex:/_(ARCHIVE_READ_FORMAT_.*)/\\1/)s", %$isenumitem) "";
%rename("%(regex:/_(ARCHIVE_EXTRACT_.*)/\\1/)s", %$isenumitem) "";
%rename("%(regex:/_(ARCHIVE_READDISK_.*)/\\1/)s", %$isenumitem) "";
%rename("%(regex:/_(ARCHIVE_MATCH_.*)/\\1/)s", %$isenumitem) "";
%rename("%(regex:/_(AE_IF.*)/\\1/)s", %$isenumitem) "";
%rename("%(regex:/_(ARCHIVE_ENTRY_ACL_.*)/\\1/)s", %$isenumitem) "";


%include "wrapper.h"
