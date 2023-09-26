
/* Swig 3.0.5 has no lua implementation of the cstring library. The following
 * typemaps are a subset of the library.
 */
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
	}
	else
	{
		lua_pushnil(L);
	}
	++SWIG_arg;
%}
