# -*- coding: utf-8 -*-
#-------------------------------------------------------------------------#
#   Copyright (C) 2011 by Christoph Thelen                                #
#   doc_bacardi@users.sourceforge.net                                     #
#                                                                         #
#   This program is free software; you can redistribute it and/or modify  #
#   it under the terms of the GNU General Public License as published by  #
#   the Free Software Foundation; either version 2 of the License, or     #
#   (at your option) any later version.                                   #
#                                                                         #
#   This program is distributed in the hope that it will be useful,       #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#   GNU General Public License for more details.                          #
#                                                                         #
#   You should have received a copy of the GNU General Public License     #
#   along with this program; if not, write to the                         #
#   Free Software Foundation, Inc.,                                       #
#   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
#-------------------------------------------------------------------------#

#----------------------------------------------------------------------------
#
# Set up the Muhkuh Build System.
#

SConscript('mbs/SConscript')
Import('env_default')

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


#----------------------------------------------------------------------------
#
# Insert the project and svn version into the template.
#
env_default.SVNVersion('src/flasher_version.h', 'templates/flasher_version.h')


#----------------------------------------------------------------------------
#
# Create the compiler environments.
#

env_default.Append(CPPDEFINES = [['CFG_INCLUDE_SHA1', '1']])

env_netx500_default = env_default.CreateCompilerEnv('500', ['cpu=arm926ej-s'])
env_netx500_default.Replace(LDFILE = File('src/netx500/flasher_netx500.ld'))
env_netx500_default.Append(CPPPATH = ['src', 'src/netx500'])

env_netx50_default  = env_default.CreateCompilerEnv('50',  ['cpu=arm966e-s'])
env_netx50_default.Replace(LDFILE = File('src/netx50/flasher_netx50.ld'))
env_netx50_default.Append(CPPPATH = ['src', 'src/netx50'])


#----------------------------------------------------------------------------
#
# Build the netx500 versions.
#
env_netx500_nodbg = env_netx500_default.Clone()
env_netx500_nodbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
src_netx500_nodbg = env_netx500_nodbg.SetBuildPath('targets/netx500_nodbg', 'src', src_netx500)
elf_netx500_nodbg = env_netx500_nodbg.Elf('targets/flasher_netx500.elf', src_netx500_nodbg)
bin_netx500_nodbg = env_netx500_nodbg.ObjCopy('targets/flasher_netx500.bin', elf_netx500_nodbg)


env_netx500_dbg = env_netx500_default.Clone()
env_netx500_dbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
src_netx500_dbg = env_netx500_dbg.SetBuildPath('targets/netx500_dbg', 'src', src_netx500)
elf_netx500_dbg = env_netx500_dbg.Elf('targets/flasher_netx500_debug.elf', src_netx500_dbg)
bin_netx500_dbg = env_netx500_dbg.ObjCopy('targets/flasher_netx500_debug.bin', elf_netx500_dbg)


#----------------------------------------------------------------------------
#
# Build the netx50 versions.
#
env_netx50_nodbg = env_netx50_default.Clone()
env_netx50_nodbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
src_netx50_nodbg = env_netx50_nodbg.SetBuildPath('targets/netx50_nodbg', 'src', src_netx50)
elf_netx50_nodbg = env_netx50_nodbg.Elf('targets/flasher_netx50.elf', src_netx50_nodbg)
bin_netx50_nodbg = env_netx50_nodbg.ObjCopy('targets/flasher_netx50.bin', elf_netx50_nodbg)


env_netx50_dbg = env_netx50_default.Clone()
env_netx50_dbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
src_netx50_dbg = env_netx50_dbg.SetBuildPath('targets/netx50_dbg', 'src', src_netx50)
elf_netx50_dbg = env_netx50_dbg.Elf('targets/flasher_netx50_debug.elf', src_netx50_dbg)
bin_netx50_dbg = env_netx50_dbg.ObjCopy('targets/flasher_netx50_debug.bin', elf_netx50_dbg)


#----------------------------------------------------------------------------
#
# Build the documentation.
#
docs = env_default.Asciidoc('targets/doc/flasher.html', 'doc/flasher.txt')


#----------------------------------------------------------------------------
#
# Package all files.
#
aPathTranslate = dict({
	bin_netx500_nodbg[0]: 'bin',
	bin_netx50_nodbg[0]: 'bin',
	bin_netx500_dbg[0]: 'bin/debug',
	bin_netx50_dbg[0]: 'bin/debug',
	docs[0]: 'doc'
})
env_default.FlexZip('targets/flasher.zip', bin_netx500_nodbg+bin_netx50_nodbg+bin_netx500_dbg+bin_netx50_dbg+docs, ZIP_PATH_TRANSLATE=aPathTranslate)

