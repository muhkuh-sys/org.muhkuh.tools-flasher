# -*- coding: utf-8 -*-

# TODO:
#  * more than one system include dir (for arg parsing etc)
#  * set a default location for the compiler dir (but where could this be?)
#
# Done:
#  * print help even if the site dir for the compiler stuff is missing.
#  * generate relocated sources from list of real locations
#  * set compiler flags from build properties
#  * show command line summary (e.g. "Cc blah.o") for the actions, but show complete line if the command failed.
#  * accept 'clean' target like make
#  * auto dependency for LDFILE
#

import scons_common
import build_properties
import svnversion

build_properties.Read()

#----------------------------------------------------------------------------
#
# set help text
#
Help("""
	Set the compiler dir with all the gcc_*.py files with --site-dir=path .
	Example: The compiler dir is usually in the folder '.ant' in the users home directory.
	This expands for the user 'brunhild' to '/home/brunhild/.ant'.

	Type: 'scons --site-dir=compiler_dir' to build the production program,
	      'scons --site-dir=compiler_dir clean' to clean everything.
""")

build_properties.GenerateHelp()


#----------------------------------------------------------------------------
# This is the list of sources. The elements must be separated with whitespace
# (i.e. spaces, tabs, newlines). The amount of whitespace does not matter.
flasher_sources_common = """
	src/cfi_flash.c
	src/delay.c
	src/flasher_ext.c
	src/flasher_i2c.c
	src/flasher_spi.c
	src/flasher_srb.c
	src/init_netx_test.s
	src/main.c
	src/netx_consoleapp.c
	src/parflash_common.c
	src/progress_bar.c
	src/rdyrun.c
	src/spansion.c
	src/spi_flash.c
	src/spi_flash_types.c
	src/startvector.s
	src/strata.c
	src/uprintf.c
"""


flasher_sources_netx500 = """
	src/netx500/flasher_header.c
	src/netx500/hal_spi.c
	src/netx500/netx_io_areas.c
"""


flasher_sources_netx50 = """
	src/netx50/flasher_header.c
	src/netx50/hal_spi.c
	src/netx50/netx_io_areas.c
"""


src_netx500 = Split(flasher_sources_common + flasher_sources_netx500)
src_netx50  = Split(flasher_sources_common + flasher_sources_netx50)


default_ccflags = """
	-ffreestanding
	-mlong-calls
	-Wall
	-Wextra
	-Wconversion
	-Wshadow
	-Wcast-qual
	-Wwrite-strings
	-Wcast-align
	-Wpointer-arith
	-Wmissing-prototypes
	-Wstrict-prototypes
	-mapcs
	-g3
	-gdwarf-2
"""


#----------------------------------------------------------------------------
# Only execute this part if the help text is not requested.
# This keeps the help message functional even if no include path for the
# compiler definitions was specified.
if not GetOption('help'):
	# Show summary of the build properties.
	build_properties.PrintSummary()
	
	
	#----------------------------------------------------------------------------
	#
	# Import the tool definitions.
	#
	gcc_arm_elf = scons_common.get_tool('gcc-arm-elf-4.3.3_4')
	asciidoc = scons_common.get_tool('asciidoc-8.5.3_1')
	
	
	#----------------------------------------------------------------------------
	#
	# Create the default environment.
	#
	env_def = Environment(tools=['default', 'packaging'])
	env_def.Decider('MD5')
	
	gcc_arm_elf.ApplyToEnv(env_def)
	asciidoc.ApplyToEnv(env_def)
	svnversion.ApplyToEnv(env_def)
	
	env_def.Append(CPPPATH = ['src'])
	env_def.Replace(CCFLAGS = Split(default_ccflags))
	env_def.Replace(LIBS = ['m', 'c', 'gcc'])
	env_def.Replace(LINKFLAGS = ['-nostdlib', '-static', '-Map=${TARGET}.map'])
	
	build_properties.ApplyToEnv(env_def)
	
	Export('env_def')
	
	
	#----------------------------------------------------------------------------
	#
	# Insert the project and svn version into the template.
	#
	env_def.SVNVersion('src/flasher_version.h', 'templates/flasher_version.h')
	
	
	#----------------------------------------------------------------------------
	#
	# Create the default environments for the different asics.
	#
	env_def_netx500 = env_def.Clone()
	env_def_netx500.Append(CCFLAGS = ['-mcpu=arm926ej-s'])
	env_def_netx500.Replace(LIBPATH = ['${GCC_DIR}/arm-elf/lib/arm926ej-s', '${GCC_DIR}/lib/gcc/arm-elf/${GCC_VERSION}/arm926ej-s'])
	env_def_netx500.Append(CPPDEFINES = [['ASIC_TYP', '500']])
	env_def_netx500.Append(CPPPATH = ['#src/netx500'])
	Export('env_def_netx500')
	
	env_def_netx50 = env_def.Clone()
	env_def_netx50.Append(CCFLAGS = ['-mcpu=arm966e-s'])
	env_def_netx50.Replace(LDFILE = File('#src/netx50/flasher_netx50.ld'))
	env_def_netx50.Replace(LIBPATH = ['${GCC_DIR}/arm-elf/lib/arm966e-s', '${GCC_DIR}/lib/gcc/arm-elf/${GCC_VERSION}/arm966e-s'])
	env_def_netx50.Append(CPPDEFINES = [['ASIC_TYP', '50']])
	env_def_netx50.Append(CPPPATH = ['#src/netx50'])
	Export('env_def_netx50')
	
	env_def_netx10 = env_def.Clone()
	env_def_netx10.Append(CCFLAGS = ['-mcpu=arm966e-s'])
	env_def_netx10.Replace(LDFILE = File('#src/netx10/flasher_netx10.ld'))
	env_def_netx10.Replace(LIBPATH = ['${GCC_DIR}/arm-elf/lib/arm966e-s', '${GCC_DIR}/lib/gcc/arm-elf/${GCC_VERSION}/arm966e-s'])
	env_def_netx10.Append(CPPDEFINES = [['ASIC_TYP', '10']])
	env_def_netx10.Append(CPPPATH = ['#src/netx10'])
	Export('env_def_netx10')
	
	
	#----------------------------------------------------------------------------
	#
	# Build the netx500 version.
	#
	env_netx500_plain = env_def_netx500.Clone()
	src_netx500_plain = scons_common.set_build_path(env_netx500_plain, 'targets/netx500', 'src', src_netx500)
	env_netx500_plain.Replace(LDFILE = File('#src/netx500/flasher_netx500.ld'))
	env_netx500_plain.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
	elf_netx500_plain = env_netx500_plain.Elf('targets/flasher_netx500', src_netx500_plain)
	bin_netx500_plain = env_netx500_plain.ObjCopy('targets/flasher_netx500', elf_netx500_plain)
	env_netx500_plain.Install('/', bin_netx500_plain)
	
	
	#----------------------------------------------------------------------------
	#
	# Build the netx500 debug version.
	#
	env_netx500_debug = env_def_netx500.Clone()
	src_netx500_debug = scons_common.set_build_path(env_netx500_debug, 'targets/netx500_debug', 'src', src_netx500)
	env_netx500_debug.Replace(LDFILE = File('#src/netx500/flasher_netx500.ld'))
	env_netx500_debug.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
	elf_netx500_debug = env_netx500_debug.Elf('targets/flasher_netx500_debug', src_netx500_debug)
	bin_netx500_debug = env_netx500_debug.ObjCopy('targets/flasher_netx500_debug', elf_netx500_debug)
	env_netx500_debug.Install('/', bin_netx500_debug)
	
	
	#----------------------------------------------------------------------------
	#
	# Build the netx50 version.
	#
	env_netx50_plain = env_def_netx50.Clone()
	src_netx50_plain = scons_common.set_build_path(env_netx50_plain, 'targets/netx50', 'src', src_netx50)
	env_netx50_plain.Replace(LDFILE = File('#src/netx50/flasher_netx50.ld'))
	env_netx50_plain.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
	elf_netx50_plain = env_netx50_plain.Elf('targets/flasher_netx50', src_netx50_plain)
	bin_netx50_plain = env_netx50_plain.ObjCopy('targets/flasher_netx50', elf_netx50_plain)
	env_netx50_plain.Install('/', bin_netx50_plain)
	
	
	#----------------------------------------------------------------------------
	#
	# Build the netx50 debug version.
	#
	env_netx50_debug = env_def_netx50.Clone()
	src_netx50_debug = scons_common.set_build_path(env_netx50_debug, 'targets/netx50_debug', 'src', src_netx50)
	env_netx50_debug.Replace(LDFILE = File('#src/netx50/flasher_netx50.ld'))
	env_netx50_debug.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
	elf_netx50_debug = env_netx50_debug.Elf('targets/flasher_netx50_debug', src_netx50_debug)
	bin_netx50_debug = env_netx50_debug.ObjCopy('targets/flasher_netx50_debug', elf_netx50_debug)
	env_netx50_debug.Install('/', bin_netx50_debug)
	
	
	#----------------------------------------------------------------------------
	#
	# Build the documentation.
	#
	docs = env_def.Asciidoc('targets/doc/flasher.html', 'doc/flasher.txt')
	env_def.Install('/', docs)
	
	
	#----------------------------------------------------------------------------
	#
	# Package all files.
	#
	env_def.Package(NAME           = 'flasher',
	                VERSION        = '1.0.882',
	                PACKAGEVERSION = 0,
	                PACKAGETYPE    = 'zip'
	)
	
