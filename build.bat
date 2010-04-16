set PYTHON_DIR=c:\Programme\Python24

rem path to python and SCons.bat
set PATH=%PATH%;%PYTHON_DIR%;%PYTHON_DIR%\Scripts

rem path to SCons Python package
set PYTHONPATH=%PYTHON_DIR%\Lib\site-packages\scons-1.2.0

rem path to GNU tools, not sure if this is necessary
set PATH=%PATH%;C:\Programme\Hitex\GnuToolPackageArm\bin

rem path to C libs
set LIBPATH=%PATH_GNU_ARM%/arm-hitex-elf/lib/interwork/arm926ej-s;%PATH_GNU_ARM%/lib/gcc/arm-hitex-elf/4.0.3/interwork/arm926ej-s

scons prefix=arm-hitex-elf- libdir_netx500=%LIBPATH% libdir_netx50=%LIBPATH% 
