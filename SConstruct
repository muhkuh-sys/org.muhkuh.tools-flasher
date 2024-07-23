# -*- coding: utf-8 -*- 1111
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


import os.path
import struct
from gitVersionManager import gitVersionManager

#----------------------------------------------------------------------------
#
# Select the platforms to build
#
atPickNetxForBuild_All = ['NETX4000', 'NETX500', 'NETX90_MPW', 'NETX90', 'NETX56', 'NETX50', 'NETX10', 'NETIOL']
AddOption('--netx',
          dest='atPickNetxForBuild',
          type='choice',
          choices=atPickNetxForBuild_All,
          action='append',
          metavar='NETX',
          help='Select the platforms to build the flasher for.')
atPickNetxForBuild = GetOption('atPickNetxForBuild')
if atPickNetxForBuild is None:
    atPickNetxForBuild = atPickNetxForBuild_All
fBuildIsFull = True
for strNetx in atPickNetxForBuild_All:
    if strNetx not in atPickNetxForBuild:
        fBuildIsFull = False
        break


#----------------------------------------------------------------------------
#
# Set up the Muhkuh Build System.
#
SConscript('mbs/SConscript')
Import('atEnv')

import spi_flashes
spi_flashes.ApplyToEnv(atEnv.DEFAULT)

# Create a build environment for the ARM9 based netX chips.
env_arm9 = atEnv.DEFAULT.CreateEnvironment(['gcc-arm-none-eabi-4.7', 'asciidoc', 'exoraw-2.0.7_2'])
if 'NETX500' in atPickNetxForBuild:
    env_arm9.CreateCompilerEnv('NETX500', ['arch=armv5te'])
    spi_flashes.ApplyToEnv(atEnv.NETX500)
if 'NETX56' in atPickNetxForBuild:
    env_arm9.CreateCompilerEnv('NETX56', ['arch=armv5te'])
    spi_flashes.ApplyToEnv(atEnv.NETX56)
if 'NETX50' in atPickNetxForBuild:
    env_arm9.CreateCompilerEnv('NETX50', ['arch=armv5te'])
    spi_flashes.ApplyToEnv(atEnv.NETX50)
if 'NETX10' in atPickNetxForBuild:
    env_arm9.CreateCompilerEnv('NETX10', ['arch=armv5te'])
    spi_flashes.ApplyToEnv(atEnv.NETX10)

# Create a build environment for the Cortex-R7 and Cortex-A9 based netX chips.
env_cortexR7 = atEnv.DEFAULT.CreateEnvironment(['gcc-arm-none-eabi-4.9', 'asciidoc', 'exoraw-2.0.7_2'])
if 'NETX4000' in atPickNetxForBuild:
    env_cortexR7.CreateCompilerEnv('NETX4000', ['arch=armv7', 'thumb'], ['arch=armv7-r', 'thumb'])
    spi_flashes.ApplyToEnv(atEnv.NETX4000)

# Create a build environment for the Cortex-M4 based netX chips.
env_cortexM4 = atEnv.DEFAULT.CreateEnvironment(['gcc-arm-none-eabi-4.9', 'asciidoc', 'exoraw-2.0.7_2'])
if 'NETX90_MPW' in atPickNetxForBuild:
    env_cortexM4.CreateCompilerEnv('NETX90_MPW', ['arch=armv7', 'thumb'], ['arch=armv7e-m', 'thumb'])
    spi_flashes.ApplyToEnv(atEnv.NETX90_MPW)
if 'NETX90' in atPickNetxForBuild:
    env_cortexM4.CreateCompilerEnv('NETX90', ['arch=armv7', 'thumb'], ['arch=armv7e-m', 'thumb'])
    spi_flashes.ApplyToEnv(atEnv.NETX90)

# Create a build environment for the RISCV based netIOL.
env_riscv = atEnv.DEFAULT.CreateEnvironment(['gcc-riscv-none-embed-7.2', 'asciidoc', 'exoraw-2.0.7_2'])
if 'NETIOL' in atPickNetxForBuild:
    env_riscv.CreateCompilerEnv('NETIOL', ['arch=rv32im', 'abi=ilp32'], ['arch=rv32imc', 'abi=ilp32'])
    spi_flashes.ApplyToEnv(atEnv.NETIOL)

# Build the platform libraries.
SConscript('platform/SConscript')


#----------------------------------------------------------------------------
# This is the list of sources. The elements must be separated with whitespace
# (i.e. spaces, tabs, newlines). The amount of whitespace does not matter.
flasher_sources_main = """
	src/main.c
	src/init_netx_test.S
	src/progress_bar.c
"""

flasher_sources_lib = """
	src/internal_flash/flasher_internal_flash.c
	src/internal_flash/internal_flash_maz_v0.c
	src/cfi_flash.c
	src/delay.c
	src/spi_flash.c
	src/exodecr.c
	src/flasher_parflash.c
	src/flasher_spi.c
	src/sfdp.c
	src/spansion.c
	src/spi_macro_player.c
	src/strata.c
	src/units.c
	src/reset.c
"""


flasher_sources_main_netx4000 = """
	src/netx4000/flasher_header.c
"""

flasher_sources_lib_netx4000 = """
	src/netx4000/board.c
	src/netx4000/cr7_global_timer.c
	src/netx4000/portcontrol.c
	src/sha1_arm/sha1.c
	src/sha1_arm/sha1_arm.S
	src/drv_spi_hsoc_v2.c
	src/drv_sqi.c
	src/mmio.c
	src/pl353_nor.c
	src/netx4000/netx4000_sdio.c
	src/flasher_sdio.c
"""

flasher_sources_main_netx90 = """
	src/netx90/flasher_header.c
"""

flasher_sources_lib_netx90 = """
	src/netx90/board.c
	src/netx90/cortexm_systick.c
	src/netx90/sha384.c
	src/drv_spi_hsoc_v2.c
	src/drv_sqi.c
	src/mmio.c
	src/sha1_netx/sha1.c
"""


flasher_sources_main_netx500 = """
	src/netx500/flasher_header.c
"""

flasher_sources_lib_netx500 = """
	src/netx500/board.c
	src/sha1_arm/sha1.c
	src/sha1_arm/sha1_arm.S
	src/drv_spi_hsoc_v1.c
"""


flasher_sources_main_netx56 = """
	src/netx56/flasher_header.c
"""

flasher_sources_lib_netx56 = """
	src/netx56/board.c
	src/sha1_arm/sha1.c
	src/sha1_arm/sha1_arm.S
	src/drv_spi_hsoc_v2.c
	src/drv_sqi.c
	src/mmio.c
"""


flasher_sources_main_netx50 = """
	src/netx50/flasher_header.c
"""

flasher_sources_lib_netx50 = """
	src/netx50/board.c
	src/sha1_arm/sha1.c
	src/sha1_arm/sha1_arm.S
	src/drv_spi_hsoc_v2.c
	src/mmio.c
"""


flasher_sources_main_netx10 = """
	src/netx10/flasher_header.c
"""

flasher_sources_lib_netx10 = """
	src/netx10/board.c
	src/sha1_arm/sha1.c
	src/sha1_arm/sha1_arm.S
	src/drv_spi_hsoc_v2.c
	src/drv_sqi.c
	src/mmio.c
"""


flasher_sources_main_netiol = """
	src/netiol/flasher_header.c
"""

flasher_sources_lib_netiol = """
	src/delay.c
	src/spi_flash.c
	src/exodecr.c
	src/flasher_spi.c
	src/sfdp.c
	src/spi_macro_player.c
	src/units.c
	src/netiol/board.c
	src/drv_spi_hsoc_v2.c
	src/reset.c
"""


src_lib_netx4000 = flasher_sources_lib + flasher_sources_lib_netx4000
src_lib_netx500  = flasher_sources_lib + flasher_sources_lib_netx500
src_lib_netx90   = flasher_sources_lib + flasher_sources_lib_netx90
src_lib_netx56   = flasher_sources_lib + flasher_sources_lib_netx56
src_lib_netx50   = flasher_sources_lib + flasher_sources_lib_netx50
src_lib_netx10   = flasher_sources_lib + flasher_sources_lib_netx10
src_lib_netiol   = flasher_sources_lib_netiol

src_main_netx4000 = flasher_sources_main + flasher_sources_main_netx4000
src_main_netx500  = flasher_sources_main + flasher_sources_main_netx500
src_main_netx90   = flasher_sources_main + flasher_sources_main_netx90
src_main_netx56   = flasher_sources_main + flasher_sources_main_netx56
src_main_netx50   = flasher_sources_main + flasher_sources_main_netx50
src_main_netx10   = flasher_sources_main + flasher_sources_main_netx10
src_main_netiol   = flasher_sources_main + flasher_sources_main_netiol


#----------------------------------------------------------------------------
#
# Get the source code version from the VCS.
#
atEnv.DEFAULT.Version('targets/version/flasher_version.h', 'templates/flasher_version.h')
atEnv.DEFAULT.Version('targets/version/flasher_version.xsl', 'templates/flasher_version.xsl')

from datetime import datetime
tBuildTime = datetime.now()
strBuildTime = tBuildTime.strftime("%Y-%B-%d-T%H:%M")
tDict = {'BUILD_TIME': strBuildTime} 

# Set the dev ending
# dev-branch:      "devX"
# release-branch:  ""
# everything else: branch name
repoManager = gitVersionManager(".")
if repoManager.onDevBranch() or repoManager.onReleaseBranch():
    tDict['BUILD_TYPE'] = repoManager.getDevEnding()
else:
    tDict['BUILD_TYPE'] = "-" + repoManager.getCurrentBranchName()

lua_flasher_version_tmp = atEnv.DEFAULT.Version('targets/version/flasher_version_TMP.lua', 'templates/flasher_version.lua')
lua_flasher_version = atEnv.DEFAULT.Filter('#/targets/version/flasher_version.lua', lua_flasher_version_tmp, SUBSTITUTIONS=tDict)

#----------------------------------------------------------------------------
#
# Create the compiler environments.
#
astrCommonIncludePaths = ['src', '#platform/src', '#platform/src/lib', 'targets/spi_flash_types', 'targets/version']

# Note: CFG_INCLUDE_PARFLASH, CFG_INCLUDE_INTFLASH are checked using ifdef. The value is irrelevant.
if 'NETX4000' in atPickNetxForBuild:
    env_netx4000_default = atEnv.NETX4000.Clone()
    env_netx4000_default.Replace(LDFILE = File('src/netx4000/netx4000.ld'))
    env_netx4000_default.Append(CPPPATH = astrCommonIncludePaths + ['src/netx4000','src/sha1_arm'])
    env_netx4000_default.Append(CPPDEFINES = [['CFG_INCLUDE_SHA1', '1'], ['CFG_INCLUDE_PARFLASH', '1'], ['CFG_INCLUDE_SMART_ERASE', '1'], ['CFG_INCLUDE_SDIO', '1']])

if 'NETX500' in atPickNetxForBuild:
    env_netx500_default = atEnv.NETX500.Clone()
    env_netx500_default.Replace(LDFILE = File('src/netx500/netx500.ld'))
    env_netx500_default.Append(CPPPATH = astrCommonIncludePaths + ['src/netx500','src/sha1_arm'])
    env_netx500_default.Append(CPPDEFINES = [['CFG_INCLUDE_SHA1', '1'], ['CFG_INCLUDE_PARFLASH', '1'], ['CFG_INCLUDE_SMART_ERASE', '1']])

if 'NETX90_MPW' in atPickNetxForBuild:
    env_netx90_mpw_default  = atEnv.NETX90_MPW.Clone()
    env_netx90_mpw_default.Replace(LDFILE = File('src/netx90/netx90.ld'))
    env_netx90_mpw_default.Append(CPPPATH = astrCommonIncludePaths + ['src/netx90','src/sha1_netx'])
    env_netx90_mpw_default.Append(CPPDEFINES = [['CFG_INCLUDE_SHA1', '1'], ['CFG_INCLUDE_PARFLASH', '1'], ['CFG_INCLUDE_INTFLASH', '1'], ['CFG_INCLUDE_SMART_ERASE', '1']])

if 'NETX90' in atPickNetxForBuild:
    env_netx90_default  = atEnv.NETX90.Clone()
    env_netx90_default.Replace(LDFILE = File('src/netx90/netx90.ld'))
    env_netx90_default.Append(CPPPATH = astrCommonIncludePaths + ['src/netx90','src/sha1_netx'])
    env_netx90_default.Append(CPPDEFINES = [['CFG_INCLUDE_SHA1', '1'], ['CFG_INCLUDE_PARFLASH', '1'], ['CFG_INCLUDE_INTFLASH', '1'], ['CFG_INCLUDE_SMART_ERASE', '1']])

if 'NETX56' in atPickNetxForBuild:
    env_netx56_default  = atEnv.NETX56.Clone()
    env_netx56_default.Replace(LDFILE = File('src/netx56/netx56.ld'))
    env_netx56_default.Append(CPPPATH = astrCommonIncludePaths + ['src/netx56','src/sha1_arm'])
    env_netx56_default.Append(CPPDEFINES = [['CFG_INCLUDE_SHA1', '1'], ['CFG_INCLUDE_PARFLASH', '1'], ['CFG_INCLUDE_SMART_ERASE', '1']])

if 'NETX50' in atPickNetxForBuild:
    env_netx50_default  = atEnv.NETX50.Clone()
    env_netx50_default.Replace(LDFILE = File('src/netx50/netx50.ld'))
    env_netx50_default.Append(CPPPATH = astrCommonIncludePaths + ['src/netx50','src/sha1_arm'])
    env_netx50_default.Append(CPPDEFINES = [['CFG_INCLUDE_SHA1', '1'], ['CFG_INCLUDE_PARFLASH', '1'], ['CFG_INCLUDE_SMART_ERASE', '1']])

if 'NETX10' in atPickNetxForBuild:
    env_netx10_default  = atEnv.NETX10.Clone()
    env_netx10_default.Replace(LDFILE = File('src/netx10/netx10.ld'))
    env_netx10_default.Append(CPPPATH = astrCommonIncludePaths + ['src/netx10','src/sha1_arm'])
    env_netx10_default.Append(CPPDEFINES = [['CFG_INCLUDE_SHA1', '1'], ['CFG_INCLUDE_PARFLASH', '1'], ['CFG_INCLUDE_SMART_ERASE', '1']])

if 'NETIOL' in atPickNetxForBuild:
    env_netiol_default  = atEnv.NETIOL.Clone()
    env_netiol_default.Replace(LDFILE = File('src/netiol/netiol.ld'))
    env_netiol_default.Append(CPPPATH = astrCommonIncludePaths + ['src/netiol','src/sha1_arm'])
    env_netiol_default.Append(CPPDEFINES = [['CFG_INCLUDE_SHA1', '0'], ['CFG_INCLUDE_SMART_ERASE', '0']])

#----------------------------------------------------------------------------
#
# Provide a function to build a flasher binary.
#
def flasher_build(strFlasherName, tEnv, strBuildPath, astrSourcesLib, astrSourcesMain):
	# Get the platform library.
	tLibPlatform = tEnv['PLATFORM_LIBRARY']

	# Create the list of known SPI flashes.
	srcSpiFlashes = tEnv.SPIFlashes(os.path.join(strBuildPath, 'spi_flash_types', 'spi_flash_types.c'), 'src/spi_flash_types.xml')
	objSpiFlashes = tEnv.Object(os.path.join(strBuildPath, 'spi_flash_types', 'spi_flash_types.o'), srcSpiFlashes[0])
	# Extract the binary.
	binSpiFlashes = tEnv.ObjCopy(os.path.join(strBuildPath, 'spi_flash_types', 'spi_flash_types.bin'), objSpiFlashes)
	# Pack the binary with exomizer.
	exoSpiFlashes = tEnv.Exoraw(os.path.join(strBuildPath, 'spi_flash_types', 'spi_flash_types.exo'), binSpiFlashes)
	# Convert the packed binary to an object.
	objExoSpiFlashes = tEnv.ObjImport(os.path.join(strBuildPath, 'spi_flash_types', 'spi_flash_types_exo.o'), exoSpiFlashes)

	# Append the path to the SPI flash list.
	tEnv.Append(CPPPATH = [os.path.join(strBuildPath, 'spi_flash_types')])

	# Build the library.
	tSrcFlasherLib = tEnv.SetBuildPath(os.path.join(strBuildPath, 'lib'), 'src', astrSourcesLib)
	tLibFlasher = tEnv.StaticLibrary(os.path.join(strBuildPath, strFlasherName), tSrcFlasherLib + objExoSpiFlashes)

	tSrcFlasher = tEnv.SetBuildPath(strBuildPath, 'src', astrSourcesMain)
	tElfFlasher = tEnv.Elf(os.path.join(strBuildPath, strFlasherName+'.elf'), tSrcFlasher + tLibFlasher + [tLibPlatform])
	tBinFlasher = tEnv.ObjCopy(os.path.join(strBuildPath, strFlasherName+'.bin'), tElfFlasher)
	tTxtFlasher = tEnv.ObjDump(os.path.join(strBuildPath, strFlasherName+'.txt'), tElfFlasher, OBJDUMP_FLAGS=['--disassemble', '--source', '--all-headers', '--wide'])

	return tElfFlasher,tBinFlasher,tLibFlasher


#----------------------------------------------------------------------------
#
# Build the netX10 flasher with the old netX50 console io interface.
#
if 'NETX10' in atPickNetxForBuild:
    env_netx10_oldio_nodbg = env_netx10_default.Clone()
    env_netx10_oldio_nodbg.Replace(LDFILE = File('src/netx10/netx10_oldio.ld'))
    env_netx10_oldio_nodbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
    elf_netx10_oldio_nodbg, bin_netx10_oldio_nodbg, lib_netx10_oldio_nodbg = flasher_build('flasher_netx10', env_netx10_oldio_nodbg, 'targets/netx10_oldio_nodbg', src_lib_netx10, src_main_netx10)

    env_netx10_oldio_dbg = env_netx10_default.Clone()
    env_netx10_oldio_dbg.Replace(LDFILE = File('src/netx10/netx10_oldio.ld'))
    env_netx10_oldio_dbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
    elf_netx10_oldio_dbg, bin_netx10_oldio_dbg, lib_netx10_oldio_dbg = flasher_build('flasher_netx10_debug', env_netx10_oldio_dbg, 'targets/netx10_oldio_dbg', src_lib_netx10, src_main_netx10)


#----------------------------------------------------------------------------
#
# Build the flasher without debug messages.
#
if 'NETX4000' in atPickNetxForBuild:
    env_netx4000_nodbg = env_netx4000_default.Clone()
    env_netx4000_nodbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
    elf_netx4000_nodbg, bin_netx4000_nodbg, lib_netx4000_nodbg = flasher_build('flasher_netx4000', env_netx4000_nodbg, 'targets/netx4000_nodbg', src_lib_netx4000, src_main_netx4000)

if 'NETX500' in atPickNetxForBuild:
    env_netx500_nodbg = env_netx500_default.Clone()
    env_netx500_nodbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
    elf_netx500_nodbg, bin_netx500_nodbg, lib_netx500_nodbg = flasher_build('flasher_netx500', env_netx500_nodbg, 'targets/netx500_nodbg', src_lib_netx500, src_main_netx500)

if 'NETX90_MPW' in atPickNetxForBuild:
    env_netx90_mpw_nodbg = env_netx90_mpw_default.Clone()
    env_netx90_mpw_nodbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
    elf_netx90_mpw_nodbg,bin_netx90_mpw_nodbg, lib_netx90_mpw_nodbg = flasher_build('flasher_netx90_mpw', env_netx90_mpw_nodbg, 'targets/netx90_mpw_nodbg', src_lib_netx90, src_main_netx90)

if 'NETX90' in atPickNetxForBuild:
    env_netx90_nodbg = env_netx90_default.Clone()
    env_netx90_nodbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
    elf_netx90_nodbg,bin_netx90_nodbg, lib_netx90_nodbg = flasher_build('flasher_netx90', env_netx90_nodbg, 'targets/netx90_nodbg', src_lib_netx90, src_main_netx90)
    
    cwd = os.getcwd()
    output_dir_name = "netx90_nodbg"
    output_path = os.path.join('targets', output_dir_name)
    hboot_netx90_flasher_bin =  os.path.join(cwd, output_path, "flasher_netx90_hboot.bin" )
    strHbootDefinitionTemplate = os.path.join(cwd,"src", "netx90", "hboot_netx90_flasher_template.xml" )
    strHbootDefinitionTemplateTmp = os.path.join(cwd,"targets", "netx90_nodbg", "hboot_netx90_flasher_template.xml" )
    strHbootDefinition = os.path.join(cwd,"targets", "netx90_nodbg", "hboot_netx90_flasher_nodbg.xml" )
    tPublicOptionPatchTable = os.path.join(cwd,"mbs", "site_scons", "hboot_netx90b_patch_table.xml" )

    env_netx90_nodbg.GccSymbolTemplate(strHbootDefinitionTemplateTmp, elf_netx90_nodbg, GCCSYMBOLTEMPLATE_TEMPLATE=strHbootDefinitionTemplate)

    atEnv.DEFAULT.Version(strHbootDefinition, strHbootDefinitionTemplateTmp)

    if(os.path.exists(tPublicOptionPatchTable)):
        tImg = env_netx90_nodbg.HBootImage(
            hboot_netx90_flasher_bin,
            strHbootDefinition,
            HBOOTIMAGE_PATCH_DEFINITION=tPublicOptionPatchTable,
            HBOOTIMAGE_KNOWN_FILES=dict({"tElf0": elf_netx90_nodbg}),
            HBOOTIMAGE_DEFINES=dict(),
            ASIC_TYP='NETX90B')
    else:
        print("one of these files does not exists: ")
        for f in [strKeyRomPath, tPublicOptionPatchTable]:
            print("    %s" % f)
    
    
    # build hboot_netx90_exec_bxlr.bin
    hboot_netx90_exec_bxlr_bin = env_netx90_nodbg.HBootImage(
        os.path.join('targets', 'hboot_netx90_exec_bxlr', 'hboot_netx90_exec_bxlr.bin'),
        os.path.join('src', 'netx90', 'hboot_netx90_exec_bxlr.xml'),
        HBOOTIMAGE_PATCH_DEFINITION=tPublicOptionPatchTable,
        HBOOTIMAGE_KNOWN_FILES=dict(),
        HBOOTIMAGE_DEFINES=dict(),
        ASIC_TYP='NETX90B')
 
    # build disable_security_settings.usp
    disable_security_settings_usp = env_netx90_nodbg.HBootImage(
        os.path.join('targets', 'disable_security_settings', 'disable_security_settings.usp'),
        os.path.join('helper_binaries', 'netx90_usip', 'disable_security_settings.xml'),
        HBOOTIMAGE_PATCH_DEFINITION=tPublicOptionPatchTable,
        HBOOTIMAGE_KNOWN_FILES=dict(),
        HBOOTIMAGE_DEFINES=dict(),
        ASIC_TYP='NETX90B')
 
    disable_security_settings_app_usp = env_netx90_nodbg.HBootImage(
        os.path.join('targets', 'disable_security_settings', 'disable_security_settings_app.usp'),
        os.path.join('helper_binaries', 'netx90_usip', 'disable_security_settings_app.xml'),
        HBOOTIMAGE_PATCH_DEFINITION=tPublicOptionPatchTable,
        HBOOTIMAGE_KNOWN_FILES=dict(),
        HBOOTIMAGE_DEFINES=dict(),
        ASIC_TYP='NETX90B')
 
    disable_security_settings_com_usp = env_netx90_nodbg.HBootImage(
        os.path.join('targets', 'disable_security_settings', 'disable_security_settings_com.usp'),
        os.path.join('helper_binaries', 'netx90_usip', 'disable_security_settings_com.xml'),
        HBOOTIMAGE_PATCH_DEFINITION=tPublicOptionPatchTable,
        HBOOTIMAGE_KNOWN_FILES=dict(),
        HBOOTIMAGE_DEFINES=dict(),
        ASIC_TYP='NETX90B')

    set_sip_protection_cookie_com_usp = env_netx90_nodbg.HBootImage(
        os.path.join('targets', 'detect_sip_protection', 'set_sip_protection_cookie.usp'),
        os.path.join('helper_binaries', 'netx90_usip', 'set_sip_protection_cookie.xml'),
        HBOOTIMAGE_PATCH_DEFINITION=tPublicOptionPatchTable,
        HBOOTIMAGE_KNOWN_FILES=dict(),
        HBOOTIMAGE_DEFINES=dict(),
        ASIC_TYP='NETX90B')
 

if 'NETX56' in atPickNetxForBuild:
    env_netx56_nodbg = env_netx56_default.Clone()
    env_netx56_nodbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
    elf_netx56_nodbg, bin_netx56_nodbg, lib_netx56_nodbg = flasher_build('flasher_netx56', env_netx56_nodbg, 'targets/netx56_nodbg', src_lib_netx56, src_main_netx56)

if 'NETX50' in atPickNetxForBuild:
    env_netx50_nodbg = env_netx50_default.Clone()
    env_netx50_nodbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
    elf_netx50_nodbg, bin_netx50_nodbg, lib_netx50_nodbg = flasher_build('flasher_netx50', env_netx50_nodbg, 'targets/netx50_nodbg', src_lib_netx50, src_main_netx50)

if 'NETX10' in atPickNetxForBuild:
    env_netx10_nodbg = env_netx10_default.Clone()
    env_netx10_nodbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
    elf_netx10_nodbg, bin_netx10_nodbg, lib_netx10_nodbg = flasher_build('flasher_netx10', env_netx10_nodbg, 'targets/netx10_nodbg', src_lib_netx10, src_main_netx10)

if 'NETIOL' in atPickNetxForBuild:
    env_netiol_nodbg = env_netiol_default.Clone()
    env_netiol_nodbg.Replace(LIBS = ['c'])
    env_netiol_nodbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
    elf_netiol_nodbg, bin_netiol_nodbg, lib_netiol_nodbg = flasher_build('flasher_netiol', env_netiol_nodbg, 'targets/netiol_nodbg', src_lib_netiol, src_main_netiol)


#----------------------------------------------------------------------------
#
# Build the flasher with debug messages.
#
if 'NETX4000' in atPickNetxForBuild:
    env_netx4000_dbg = env_netx4000_default.Clone()
    env_netx4000_dbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
    elf_netx4000_dbg, bin_netx4000_dbg, lib_netx4000_dbg = flasher_build('flasher_netx4000_debug', env_netx4000_dbg, 'targets/netx4000_dbg', src_lib_netx4000, src_main_netx4000)

if 'NETX500' in atPickNetxForBuild:
    env_netx500_dbg = env_netx500_default.Clone()
    env_netx500_dbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
    elf_netx500_dbg, bin_netx500_dbg, lib_netx500_dbg = flasher_build('flasher_netx500_debug', env_netx500_dbg, 'targets/netx500_dbg', src_lib_netx500, src_main_netx500)

if 'NETX90_MPW' in atPickNetxForBuild:
    env_netx90_mpw_dbg = env_netx90_mpw_default.Clone()
    env_netx90_mpw_dbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
    elf_netx90_mpw_dbg, bin_netx90_mpw_dbg, lib_netx90_mpw_dbg = flasher_build('flasher_netx90_mpw_debug', env_netx90_mpw_dbg, 'targets/netx90_mpw_dbg', src_lib_netx90, src_main_netx90)

if 'NETX90' in atPickNetxForBuild:
    env_netx90_dbg = env_netx90_default.Clone()
    env_netx90_dbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
    elf_netx90_dbg, bin_netx90_dbg, lib_netx90_dbg = flasher_build('flasher_netx90_debug', env_netx90_dbg, 'targets/netx90_dbg', src_lib_netx90, src_main_netx90)
    
    cwd = os.getcwd()
    # strKeyRomPath = "keys/keys.xml" # must be copied to repo
    output_dir_name = "netx90_dbg"
    output_path = os.path.join('targets', output_dir_name)
    strOutputImg =  os.path.join(cwd, output_path, "flasher_netx90_hboot.bin" )
    strHbootDefinitionTemplate = os.path.join(cwd,"src", "netx90", "hboot_netx90_flasher_template.xml" )
    strHbootDefinition = os.path.join(cwd,"targets", "netx90_dbg", "hboot_netx90_flasher_dbg.xml" )
    tPublicOptionPatchTable = os.path.join(cwd,"mbs", "site_scons", "hboot_netx90b_patch_table.xml" )

    env_netx90_dbg.GccSymbolTemplate(strHbootDefinition, elf_netx90_dbg, GCCSYMBOLTEMPLATE_TEMPLATE=strHbootDefinitionTemplate)
    if(os.path.exists(tPublicOptionPatchTable)):
        tImg = env_netx90_dbg.HBootImage(strOutputImg,
            strHbootDefinition,
            HBOOTIMAGE_PATCH_DEFINITION=tPublicOptionPatchTable,
            HBOOTIMAGE_KNOWN_FILES=dict({"tElf0": elf_netx90_dbg}),
            HBOOTIMAGE_DEFINES=dict(),
            ASIC_TYP='NETX90B')
    else:
        print("one of these files does not exists: ")
        for f in [strKeyRomPath, tPublicOptionPatchTable]:
            print("    %s" % f)

if 'NETX56' in atPickNetxForBuild:
    env_netx56_dbg = env_netx56_default.Clone()
    env_netx56_dbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
    elf_netx56_dbg, bin_netx56_dbg, lib_netx56_dbg = flasher_build('flasher_netx56_debug', env_netx56_dbg, 'targets/netx56_dbg', src_lib_netx56, src_main_netx56)

if 'NETX50' in atPickNetxForBuild:
    env_netx50_dbg = env_netx50_default.Clone()
    env_netx50_dbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
    elf_netx50_dbg, bin_netx50_dbg, lib_netx50_dbg = flasher_build('flasher_netx50_debug', env_netx50_dbg, 'targets/netx50_dbg', src_lib_netx50, src_main_netx50)

if 'NETX10' in atPickNetxForBuild:
    env_netx10_dbg = env_netx10_default.Clone()
    env_netx10_dbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
    elf_netx10_dbg, bin_netx10_dbg, lib_netx10_dbg = flasher_build('flasher_netx10_debug', env_netx10_dbg, 'targets/netx10_dbg', src_lib_netx10, src_main_netx10)

if 'NETIOL' in atPickNetxForBuild:
    env_netiol_dbg = env_netiol_default.Clone()
    env_netiol_dbg.Replace(LIBS = ['c'])
    env_netiol_dbg.Append(CPPDEFINES = [['CFG_DEBUGMSG', '1']])
    elf_netiol_dbg, bin_netiol_dbg, lib_netiol_dbg = flasher_build('flasher_netiol_debug', env_netiol_dbg, 'targets/netiol_dbg', src_lib_netiol, src_main_netiol)


#----------------------------------------------------------------------------
#
# Build the BOB flasher without debug messages.
# This version runs from SDRAM starting at 0x8002000 to save the INTRAM for
# the 2ndStageLoader.
#
if 'NETX500' in atPickNetxForBuild:
    env_netx500_bob = env_netx500_default.Clone()
    env_netx500_bob.Append(CPPDEFINES = [['CFG_DEBUGMSG', '0']])
    env_netx500_bob.Replace(LDFILE = File('src/netx500/netx500_bob.ld'))
    elf_netx500_bob, bin_netx500_bob, lib_netx500_bob = flasher_build('flasher_netx500_bob', env_netx500_bob, 'targets/netx500_bob', src_lib_netx500, src_main_netx500)


#----------------------------------------------------------------------------
#
# Generate the LUA scripts from the template.
# This extracts symbols and enumeration values from the ELF file and inserts
# them into the LUA script.
# The netX500 ELF file is used here as a source for no special reason. All of
# the symbols and values which are used in the template are the same in every
# ELF file in this project.
#

# Get the first available build environment and ELF file.
tEnv = None
tElf = None
if 'NETX4000' in atPickNetxForBuild:
    tEnv = env_netx4000_nodbg
    tElf = elf_netx4000_nodbg
elif 'NETX500' in atPickNetxForBuild:
    tEnv = env_netx500_nodbg
    tElf = elf_netx500_nodbg
elif 'NETX90_MPW' in atPickNetxForBuild:
    tEnv = env_netx90_mpw_nodbg
    tElf = elf_netx90_mpw_nodbg
elif 'NETX90' in atPickNetxForBuild:
    tEnv = env_netx90_nodbg
    tElf = elf_netx90_nodbg
elif 'NETX56' in atPickNetxForBuild:
    tEnv = env_netx56_nodbg
    tElf = elf_netx56_nodbg
elif 'NETX50' in atPickNetxForBuild:
    tEnv = env_netx50_nodbg
    tElf = elf_netx50_nodbg
elif 'NETX10' in atPickNetxForBuild:
    tEnv = env_netx10_nodbg
    tElf = elf_netx10_nodbg
elif 'NETIOL' in atPickNetxForBuild:
    tEnv = env_netiol_nodbg
    tElf = elf_netiol_nodbg

lua_flasher = tEnv.GccSymbolTemplate('targets/lua/flasher.lua', tElf, GCCSYMBOLTEMPLATE_TEMPLATE='templates/flasher.lua')
tDemoShowEraseAreas = tEnv.GccSymbolTemplate('targets/lua/show_erase_areas.lua', tElf, GCCSYMBOLTEMPLATE_TEMPLATE='templates/show_erase_areas.lua')

#----------------------------------------------------------------------------
#
# Build the documentation.
#

tDocSpiFlashTypesHtml = atEnv.DEFAULT.XSLT('targets/doc/spi_flash_types.html', ['src/spi_flash_types.xml', 'src/spi_flash_types_html.xsl'])
tDocSpiFlashListTxt = atEnv.DEFAULT.XSLT('targets/doc/spi_flash_types.txt', ['src/spi_flash_types.xml', 'src/spi_flash_types_txt.xsl'])


# Get the default attributes.
aAttribs = atEnv.DEFAULT['ASCIIDOC_ATTRIBUTES']
# Add some custom attributes.
aAttribs.update(dict({
    # Use ASCIIMath formulas.
    'asciimath': True,

    # Embed images into the HTML file as data URIs.
    'data-uri': True,

    # Use icons instead of text for markers and callouts.
    'icons': True,

    # Use numbers in the table of contents.
    'numbered': True,

    # Generate a scrollable table of contents on the left of the text.
    'toc2': True,

    # Use 4 levels in the table of contents.
    'toclevels': 4
}))

doc = atEnv.DEFAULT.Asciidoc('targets/doc/flasher.html', 'doc/flasher.asciidoc', ASCIIDOC_BACKEND='html5', ASCIIDOC_ATTRIBUTES=aAttribs)


#----------------------------------------------------------------------------
#
# Build the artifact.
#
if fBuildIsFull==True:
#    strGroup = 'org.muhkuh.tools'
#    strModule = 'flasher'
#
#    # Split the group by dots.
#    aGroup = strGroup.split('.')
#    # Build the path for all artifacts.
#    strModulePath = 'targets/jonchki/repository/%s/%s/%s' % ('/'.join(aGroup), strModule, PROJECT_VERSION)
#
#
#    strArtifact = 'lua5.4-flasher'
#
#    tArcList = atEnv.DEFAULT.ArchiveList('zip')
#
#    tArcList.AddFiles('netx/',
#        bin_netx4000_nodbg,
#        bin_netx500_nodbg,
#        bin_netx90_mpw_nodbg,
#        bin_netx90_nodbg,
#        bin_netx90_nodbg_secure,
#        bin_netx56_nodbg,
#        bin_netx50_nodbg,
#        bin_netx10_nodbg,
#        bin_netiol_nodbg,
#        'bootpins_netx90/bootpins_netx90.bin')
#
#    tArcList.AddFiles('netx/hboot/unsigned/netx90/',
#        hboot_netx90_flasher_bin,
#        'helper_binaries/netx90/bootswitch.bin',
#        'helper_binaries/netx90/read_sip_M2M.bin',
#        'helper_binaries/netx90/return_exec.bin',
#        'helper_binaries/netx90/set_kek.bin',
#        'helper_binaries/netx90/verify_sig.bin',
#        'helper_binaries/netx90/hboot_start_mi_netx90_com_intram.bin')
#        
#    tArcList.AddFiles('netx/helper/netx90/',
#        hboot_netx90_exec_bxlr_bin,
#        'helper_binaries/netx90/com_default_rom_init_ff_netx90_rev2.bin',
#        'helper_binaries/netx90/set_kek.usp',
#        set_sip_protection_cookie_com_usp)
#        
#    tArcList.AddFiles('netx/hboot/unsigned/netx90_usip/',
#        disable_security_settings_usp,
#        disable_security_settings_com_usp,
#        disable_security_settings_app_usp)
#    
#    tArcList.AddFiles('netx/debug/',
#        bin_netx4000_dbg,
#        bin_netx500_dbg,
#        bin_netx90_mpw_dbg,
#        bin_netx90_dbg,
#        bin_netx56_dbg,
#        bin_netx50_dbg,
#        bin_netx10_dbg,
#        bin_netiol_dbg)
#
#    tArcList.AddFiles('doc/',
#        doc,
#        tDocSpiFlashTypesHtml,
#        tDocSpiFlashListTxt, 
#        "doc/cli_flasher_changelog.txt")
#
#    tArcList.AddFiles('lua/',
#        lua_flasher,
#        'lua/flasher_test.lua',
#        'lua/lua/helper_files.lua',
#        'lua/lua/Version.lua',
#        'lua/lua/wfp_control.lua', 
#        'bootpins_netx90/bootpins.lua',
#        'lua/lua/flasher_helper.lua', 
#        'lua/lua/sipper.lua',
#        'lua/lua/usip_generator.lua',
#        'lua/lua/usip_player_conf.lua',
#        'lua/lua/verify_signature.lua',
#        )
#
#    tArcList.AddFiles('',
#        'lua/cli_flash.lua',
#        'lua/usip_player.lua',
#        'lua/muhkuh_cli_init.lua',
#        'lua/wfp.lua',
#        'lua/wfp_verify.lua',
#        lua_flasher_version)

#        'lua/demo_getBoardInfo.lua',
#        'lua/erase_complete_flash.lua',
#        'lua/erase_first_flash_sector.lua',
#        'lua/erase_first_flash_sector_intflash0.lua',
#        'lua/erase_first_flash_sector_intflash1.lua',
#        'lua/erase_first_flash_sector_intflash2.lua',
#        'lua/flash_intflash0.lua',
#        'lua/flash_intflash1.lua',
#        'lua/flash_intflash2.lua',
#        'lua/flash_parflash.lua',
#        'lua/flash_serflash.lua',
#        'lua/get_erase_areas_parflash.lua',
#        'lua/identify_intflash0.lua',
#        'lua/identify_parflash.lua',
#        'lua/identify_serflash.lua',
#        'lua/is_erased_parflash.lua',
#        'lua/netx90mpw_iflash.lua',
#        'lua/read_bootimage.lua',
#        'lua/read_bootimage_intflash0.lua',
#        'lua/read_bootimage_intflash2.lua',
#        'lua/read_complete_flash.lua',
#        tDemoShowEraseAreas)

    # # Split the group by dots.
    # aGroup = strGroup.split('.')
    # # Build the path for all artifacts.
    # strModulePath = 'targets/jonchki/repository/%s/%s/%s' % ('/'.join(aGroup), strModule, PROJECT_VERSION)


    # strArtifact = 'lua5.4-flasher'

    # tArcList = atEnv.DEFAULT.ArchiveList('zip')

    # tArcList.AddFiles('netx/',
    #     bin_netx4000_nodbg,
    #     bin_netx500_nodbg,
    #     bin_netx90_mpw_nodbg,
    #     bin_netx90_nodbg,
    #     bin_netx90_nodbg_secure,
    #     bin_netx56_nodbg,
    #     bin_netx50_nodbg,
    #     bin_netx10_nodbg,
    #     bin_netiol_nodbg,
    #     'bootpins_netx90/bootpins_netx90.bin')

    # tArcList.AddFiles('netx/hboot/unsigned/netx90/',
    #     hboot_netx90_flasher_bin,
    #     'helper_binaries/netx90/bootswitch.bin',
    #     'helper_binaries/netx90/read_sip_M2M.bin',
    #     'helper_binaries/netx90/return_exec.bin',
    #     'helper_binaries/netx90/set_kek.bin',
    #     'helper_binaries/netx90/verify_sig.bin',
    #     'helper_binaries/netx90/hboot_start_mi_netx90_com_intram.bin')
        
    # tArcList.AddFiles('netx/helper/netx90/',
    #     hboot_netx90_exec_bxlr_bin,
    #     'helper_binaries/netx90/com_default_rom_init_ff_netx90_rev2.bin',
    #     'helper_binaries/netx90/app_sip_default_ff.bin',
    #     'helper_binaries/netx90/com_sip_default_ff.bin',
    #     'helper_binaries/netx90/set_kek.usp')
        
    # tArcList.AddFiles('netx/hboot/unsigned/netx90_usip/',
    #     disable_security_settings_usp,
    #     disable_security_settings_com_usp,
    #     disable_security_settings_app_usp,
    #     set_sip_protection_cookie_com_usp)
    
    # tArcList.AddFiles('netx/debug/',
    #     bin_netx4000_dbg,
    #     bin_netx500_dbg,
    #     bin_netx90_mpw_dbg,
    #     bin_netx90_dbg,
    #     bin_netx56_dbg,
    #     bin_netx50_dbg,
    #     bin_netx10_dbg,
    #     bin_netiol_dbg)

    # tArcList.AddFiles('doc/',
    #     doc,
    #     tDocSpiFlashTypesHtml,
    #     tDocSpiFlashListTxt, 
    #     "doc/cli_flasher_changelog.txt")

    # tArcList.AddFiles('lua/',
    #     lua_flasher,
    #     'lua/flasher_test.lua',
    #     'lua/lua/muhkuh_cli_init.lua',
    #     'lua/lua/wfp_verify.lua',
    #     'lua/lua/helper_files.lua',
    #     'lua/lua/Version.lua',
    #     'lua/lua/wfp_control.lua', 
    #     'bootpins_netx90/bootpins.lua',
    #     'lua/lua/flasher_helper.lua', 
    #     'lua/lua/sipper.lua',
    #     'lua/lua/usip_generator.lua',
    #     'lua/lua/usip_player_conf.lua',
    #     'lua/lua/verify_signature.lua',
    #     )

    # tArcList.AddFiles('',
    #     'lua/cli_flash.lua',
    #     'lua/usip_player.lua',
    #     'lua/demo_getBoardInfo.lua',
    #     'lua/erase_complete_flash.lua',
    #     'lua/erase_first_flash_sector.lua',
    #     'lua/erase_first_flash_sector_intflash0.lua',
    #     'lua/erase_first_flash_sector_intflash1.lua',
    #     'lua/erase_first_flash_sector_intflash2.lua',
    #     'lua/flash_intflash0.lua',
    #     'lua/flash_intflash1.lua',
    #     'lua/flash_intflash2.lua',
    #     'lua/flash_parflash.lua',
    #     'lua/flash_serflash.lua',
    #     'lua/get_erase_areas_parflash.lua',
    #     'lua/identify_intflash0.lua',
    #     'lua/identify_parflash.lua',
    #     'lua/identify_serflash.lua',
    #     'lua/is_erased_parflash.lua',
    #     'lua/netx90mpw_iflash.lua',
    #     'lua/read_bootimage.lua',
    #     'lua/read_bootimage_intflash0.lua',
    #     'lua/read_bootimage_intflash2.lua',
    #     'lua/read_complete_flash.lua',
    #     'lua/wfp.lua',
    #     lua_flasher_version,
    #     tDemoShowEraseAreas)

#    strBasePath = os.path.join(strModulePath, '%s-%s' % (strArtifact, PROJECT_VERSION))
#    tArtifact = atEnv.DEFAULT.Archive('%s.zip' % strBasePath, None, ARCHIVE_CONTENTS = tArcList)


    #----------------------------------------------------------------------------
    #
    # Make a local demo installation.
    #
    atCopyFiles = {
        # Copy all binaries.
        'targets/testbench/netx/bootpins_netx90.bin':                      'bootpins_netx90/bootpins_netx90.bin',
        'targets/testbench/netx/flasher_netx4000.bin':                     bin_netx4000_nodbg,
        'targets/testbench/netx/flasher_netx500.bin':                      bin_netx500_nodbg,
        'targets/testbench/netx/flasher_netx90_mpw.bin':                   bin_netx90_mpw_nodbg,
        'targets/testbench/netx/flasher_netx90.bin':                       bin_netx90_nodbg,
        'targets/testbench/netx/flasher_netx56.bin':                       bin_netx56_nodbg,
        'targets/testbench/netx/flasher_netx50.bin':                       bin_netx50_nodbg,
        'targets/testbench/netx/flasher_netx10.bin':                       bin_netx10_nodbg,
        'targets/testbench/netx/flasher_netiol.bin':                       bin_netiol_nodbg,

        # Copy all debug binaries.
        'targets/testbench/netx/debug/flasher_netx4000_debug.bin':         bin_netx4000_dbg,
        'targets/testbench/netx/debug/flasher_netx500_debug.bin':          bin_netx500_dbg,
        'targets/testbench/netx/debug/flasher_netx90_mpw_debug.bin':       bin_netx90_mpw_dbg,
        'targets/testbench/netx/debug/flasher_netx90_debug.bin':           bin_netx90_dbg,
        'targets/testbench/netx/debug/flasher_netx56_debug.bin':           bin_netx56_dbg,
        'targets/testbench/netx/debug/flasher_netx50_debug.bin':           bin_netx50_dbg,
        'targets/testbench/netx/debug/flasher_netx10_debug.bin':           bin_netx10_dbg,
        'targets/testbench/netx/debug/flasher_netiol_debug.bin':           bin_netiol_dbg,

        'targets/testbench/netx/hboot/unsigned/netx90/flasher_netx90_hboot.bin':             hboot_netx90_flasher_bin,
        'targets/testbench/netx/hboot/unsigned/netx90/bootswitch.bin':                       'helper_binaries/netx90/bootswitch.bin',
        'targets/testbench/netx/hboot/unsigned/netx90/read_sip_M2M.bin':                     'helper_binaries/netx90/read_sip_M2M.bin',
        'targets/testbench/netx/hboot/unsigned/netx90/return_exec.bin':                      'helper_binaries/netx90/return_exec.bin',
        'targets/testbench/netx/hboot/unsigned/netx90/set_kek.bin':                          'helper_binaries/netx90/set_kek.bin',
        'targets/testbench/netx/hboot/unsigned/netx90/verify_sig.bin':                       'helper_binaries/netx90/verify_sig.bin',
        #'targets/testbench/netx/hboot/unsigned/netx90/hboot_start_mi_netx90_com_intram.bin': 'helper_binaries/netx90/hboot_start_mi_netx90_com_intram.bin',

        'targets/testbench/netx/helper/netx90/hboot_netx90_exec_bxlr.bin':              hboot_netx90_exec_bxlr_bin,
        'targets/testbench/netx/helper/netx90/com_default_rom_init_ff_netx90_rev2.bin': 'helper_binaries/netx90/com_default_rom_init_ff_netx90_rev2.bin',
        'targets/testbench/netx/helper/netx90/app_sip_default_ff.bin':                  'helper_binaries/netx90/app_sip_default_ff.bin',
        'targets/testbench/netx/helper/netx90/com_sip_default_ff.bin':                  'helper_binaries/netx90/com_sip_default_ff.bin',
        'targets/testbench/netx/helper/netx90/set_kek.usp':                             'helper_binaries/netx90/set_kek.usp',
        'targets/testbench/netx/helper/netx90/set_sip_protection_cookie.usp':     set_sip_protection_cookie_com_usp,

        'targets/testbench/netx/hboot/unsigned/netx90_usip/disable_security_settings.usp':     disable_security_settings_usp,
        'targets/testbench/netx/hboot/unsigned/netx90_usip/disable_security_settings_com.usp': disable_security_settings_com_usp,
        'targets/testbench/netx/hboot/unsigned/netx90_usip/disable_security_settings_app.usp': disable_security_settings_app_usp,

        'targets/testbench/doc/flasher.html':              doc,
        'targets/testbench/doc/spi_flash_types.html':      tDocSpiFlashTypesHtml,
        'targets/testbench/doc/spi_flash_types.txt':       tDocSpiFlashListTxt,
        'targets/testbench/doc/cli_flasher_changelog.txt': 'doc/cli_flasher_changelog.txt',

        # Copy all LUA modules.
        'targets/testbench/lua/Version.lua':                               'lua/lua/Version.lua',
        'targets/testbench/lua/flasher.lua':                               lua_flasher,
        'targets/testbench/lua/wfp_control.lua':                           'lua/lua/wfp_control.lua',
        'targets/testbench/lua/bootpins.lua':                              'bootpins_netx90/bootpins.lua',
        'targets/testbench/lua/flasher_helper.lua':                        'lua/lua/flasher_helper.lua', 
        'targets/testbench/lua/flasher_test.lua':                          'lua/flasher_test.lua',
        'targets/testbench/lua/helper_files.lua':                          'lua/lua/helper_files.lua', 
        'targets/testbench/lua/muhkuh_cli_init.lua':                       'lua/lua/muhkuh_cli_init.lua',
        'targets/testbench/lua/sipper.lua':                                'lua/lua/sipper.lua',
        'targets/testbench/lua/wfp_verify.lua':                            'lua/lua/wfp_verify.lua',
        'targets/testbench/lua/verify_signature.lua':                      'lua/lua/verify_signature.lua',
        'targets/testbench/lua/usip_generator.lua':                        'lua/lua/usip_generator.lua',
        'targets/testbench/lua/usip_player_conf.lua':                      'lua/lua/usip_player_conf.lua',
        'targets/testbench/lua/usip_player_class.lua':                      'lua/lua/usip_player_class.lua',

        # Copy all LUA scripts.
        'targets/testbench/flasher_version.lua':                           lua_flasher_version,
        'targets/testbench/cli_flash.lua':                                 'lua/cli_flash.lua',
        'targets/testbench/demo_getBoardInfo.lua':                         'lua/demo_getBoardInfo.lua',
        'targets/testbench/erase_complete_flash.lua':                      'lua/erase_complete_flash.lua',
        'targets/testbench/erase_first_flash_sector.lua':                  'lua/erase_first_flash_sector.lua',
        'targets/testbench/erase_first_flash_sector_intflash0.lua':        'lua/erase_first_flash_sector_intflash0.lua',
        'targets/testbench/erase_first_flash_sector_intflash1.lua':        'lua/erase_first_flash_sector_intflash1.lua',
        'targets/testbench/erase_first_flash_sector_intflash2.lua':        'lua/erase_first_flash_sector_intflash2.lua',
        'targets/testbench/flash_intflash0.lua':                           'lua/flash_intflash0.lua',
        'targets/testbench/flash_intflash1.lua':                           'lua/flash_intflash1.lua',
        'targets/testbench/flash_intflash2.lua':                           'lua/flash_intflash2.lua',
        'targets/testbench/flash_parflash.lua':                            'lua/flash_parflash.lua',
        'targets/testbench/flash_serflash.lua':                            'lua/flash_serflash.lua',
        'targets/testbench/get_erase_areas_parflash.lua':                  'lua/get_erase_areas_parflash.lua',
        'targets/testbench/identify_intflash0.lua':                        'lua/identify_intflash0.lua',
        'targets/testbench/identify_parflash.lua':                         'lua/identify_parflash.lua',
        'targets/testbench/identify_serflash.lua':                         'lua/identify_serflash.lua',
        'targets/testbench/is_erased_parflash.lua':                        'lua/is_erased_parflash.lua',
        'targets/testbench/netx90mpw_iflash.lua':                          'lua/netx90mpw_iflash.lua',
        'targets/testbench/read_bootimage.lua':                            'lua/read_bootimage.lua',
        'targets/testbench/read_bootimage_intflash0.lua':                  'lua/read_bootimage_intflash0.lua',
        'targets/testbench/read_bootimage_intflash2.lua':                  'lua/read_bootimage_intflash2.lua',
        'targets/testbench/read_complete_flash.lua':                       'lua/read_complete_flash.lua',
        'targets/testbench/usip_player.lua':                               'lua/usip_player.lua',
        'targets/testbench/wfp.lua':                                       'lua/wfp.lua',
        'targets/testbench/show_erase_areas.lua':                          tDemoShowEraseAreas,

        # collect the lib files in a directory
        'targets/flasher_lib/includes/spi.h':                              'src/spi.h',
        'targets/flasher_lib/includes/flasher_spi.h':                      'src/flasher_spi.h',
        'targets/flasher_lib/includes/netx_consoleapp.h':                  'src/netx_consoleapp.h',
        'targets/flasher_lib/includes/sha1_arm/sha1.h':                    'src/sha1_arm/sha1.h',
        'targets/flasher_lib/includes/sha1_netx/sha1.h':                   'src/sha1_netx/sha1.h',
        'targets/flasher_lib/includes/spi_flash.h':                        'src/spi_flash.h',
        'targets/flasher_lib/includes/flasher_version.h':                  'targets/version/flasher_version.h',
        'targets/flasher_lib/includes/spi_flash_types.h':                  'targets/netx50_nodbg/spi_flash_types/spi_flash_types.h',
        'targets/flasher_lib/includes/reset.h':                            'src/reset.h',

        'targets/flasher_lib/libflasher_netx4000.a':                       lib_netx4000_nodbg,
        'targets/flasher_lib/libflasher_netx500.a':                        lib_netx500_nodbg,
        'targets/flasher_lib/libflasher_netx90mpw.a':                      lib_netx90_mpw_nodbg,
        'targets/flasher_lib/libflasher_netx56.a':                         lib_netx56_nodbg,
        'targets/flasher_lib/libflasher_netx50.a':                         lib_netx50_nodbg,
        'targets/flasher_lib/libflasher_netx50.a':                         lib_netx10_nodbg,
        'targets/flasher_lib/libflasher_netiol.a':                         lib_netiol_nodbg,

        'targets/flasher_lib/libflasher_netx4000_debug.a':                 lib_netx4000_dbg,
        'targets/flasher_lib/libflasher_netx500_debug.a':                  lib_netx500_dbg,
        'targets/flasher_lib/libflasher_netx90mpw_debug.a':                lib_netx90_mpw_dbg,
        'targets/flasher_lib/libflasher_netx56_debug.a':                   lib_netx56_dbg,
        'targets/flasher_lib/libflasher_netx50_debug.a':                   lib_netx50_dbg,
        'targets/flasher_lib/libflasher_netx50_debug.a':                   lib_netx10_dbg,
        'targets/flasher_lib/libflasher_netiol_debug.a':                   lib_netiol_dbg,
    }

    for tDst, tSrc in atCopyFiles.items():
        InstallAs(tDst, tSrc)
