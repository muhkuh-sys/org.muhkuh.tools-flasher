#! /usr/bin/python3

from cmake import cli_args
from cmake import install

import xml.etree.ElementTree
import os
import subprocess
import sys


tPlatform = cli_args.parse()
print('Building for %s' % tPlatform['platform_id'])


# --------------------------------------------------------------------------
# -
# - Configuration
# -

# Get the project folder. This is the folder of this script.
strCfg_projectFolder = os.path.dirname(os.path.realpath(__file__))

# This is the complete path to the testbench folder. The installation will be
# written there.
strCfg_workingFolder = os.path.join(
    strCfg_projectFolder,
    'flasher-environment',
    'build',
    tPlatform['platform_id']
)

# -
# --------------------------------------------------------------------------

astrCMAKE_COMPILER = None
astrCMAKE_PLATFORM = None
astrJONCHKI_SYSTEM = None
strMake = None
astrEnv = None

if tPlatform['host_distribution_id'] == 'ubuntu':
    if tPlatform['distribution_id'] == 'ubuntu':
        # Build on linux for linux.
        # It is currently not possible to build for another version of the OS.
        if tPlatform['distribution_version'] != tPlatform['host_distribution_version']:
            raise Exception('The target Ubuntu version must match the build host.')

        if tPlatform['cpu_architecture'] == tPlatform['host_cpu_architecture']:
            # Build for the build host.

            astrDeb = [
                'libacl1-dev',
                'libreadline-dev',
                'libudev-dev',
                'pkg-config'
            ]
            install.install_host_debs(astrDeb)

            astrCMAKE_COMPILER = []
            astrCMAKE_PLATFORM = []
            astrJONCHKI_SYSTEM = []
            strMake = 'make'

        elif tPlatform['cpu_architecture'] == 'armhf':
            # Build on linux for raspberry.

            astrDeb = [
                'dpkg-dev',
                'pkg-config'
            ]
            install.install_host_debs(astrDeb)
            astrDeb = [
                'libacl1-dev:armhf',
                'libreadline-dev:armhf',
                'libudev-dev:armhf'
            ]
            install.install_foreign_debs(astrDeb, strCfg_workingFolder, strCfg_projectFolder)
            strLib = os.path.join(
                strCfg_workingFolder,
                'packages',
                'lib',
                'arm-linux-gnueabihf',
                'libacl.a'
            )
            strLibNew = os.path.join(
                strCfg_workingFolder,
                'packages',
                'usr',
                'lib',
                'arm-linux-gnueabihf',
                'libacl.a'
            )
            if os.path.exists(strLib) is not True:
                if os.path.exists(strLibNew) is not True:
                    raise Exception(
                        'libacl does not exist in the 2 expected locations '
                        '%s and %s.' % (
                            strLib,
                            strLibNew
                        )
                    )
                else:
                    os.symlink(
                        strLibNew,
                        strLib
                    )

            astrCMAKE_COMPILER = [
                '-DCMAKE_TOOLCHAIN_FILE=%s/cmake/toolchainfiles/toolchain_ubuntu_armhf.cmake' % strCfg_projectFolder
            ]
            astrCMAKE_PLATFORM = [
                '-DJONCHKI_PLATFORM_DIST_ID=%s' % tPlatform['distribution_id'],
                '-DJONCHKI_PLATFORM_DIST_VERSION=%s' % tPlatform['distribution_version'],
                '-DJONCHKI_PLATFORM_CPU_ARCH=%s' % tPlatform['cpu_architecture']
            ]

            astrJONCHKI_SYSTEM = [
                '--distribution-id %s' % tPlatform['distribution_id'],
                '--distribution-version %s' % tPlatform['distribution_version'],
                '--cpu-architecture %s' % tPlatform['cpu_architecture']
            ]
            strMake = 'make'

        elif tPlatform['cpu_architecture'] == 'arm64':
            # Build on linux for raspberry.

            astrDeb = [
                'dpkg-dev',
                'pkg-config'
            ]
            install.install_host_debs(astrDeb)
            astrDeb = [
                'libacl1-dev:arm64',
                'libreadline-dev:arm64',
                'libudev-dev:arm64'
            ]
            install.install_foreign_debs(astrDeb, strCfg_workingFolder, strCfg_projectFolder)
            strLib = os.path.join(
                strCfg_workingFolder,
                'packages',
                'lib',
                'aarch64-linux-gnu',
                'libacl.a'
            )
            strLibNew = os.path.join(
                strCfg_workingFolder,
                'packages',
                'usr',
                'lib',
                'aarch64-linux-gnu',
                'libacl.a'
            )
            if os.path.exists(strLib) is not True:
                if os.path.exists(strLibNew) is not True:
                    raise Exception(
                        'libacl does not exist in the 2 expected locations '
                        '%s and %s.' % (
                            strLib,
                            strLibNew
                        )
                    )
                else:
                    os.symlink(
                        strLibNew,
                        strLib
                    )

            astrCMAKE_COMPILER = [
                '-DCMAKE_TOOLCHAIN_FILE=%s/cmake/toolchainfiles/toolchain_ubuntu_arm64.cmake' % strCfg_projectFolder
            ]
            astrCMAKE_PLATFORM = [
                '-DJONCHKI_PLATFORM_DIST_ID=%s' % tPlatform['distribution_id'],
                '-DJONCHKI_PLATFORM_DIST_VERSION=%s' % tPlatform['distribution_version'],
                '-DJONCHKI_PLATFORM_CPU_ARCH=%s' % tPlatform['cpu_architecture']
            ]

            astrJONCHKI_SYSTEM = [
                '--distribution-id %s' % tPlatform['distribution_id'],
                '--distribution-version %s' % tPlatform['distribution_version'],
                '--cpu-architecture %s' % tPlatform['cpu_architecture']
            ]
            strMake = 'make'

        elif tPlatform['cpu_architecture'] == 'riscv64':
            # Build on linux for riscv64.

            astrDeb = [
                'dpkg-dev',
                'pkg-config'
            ]
            install.install_host_debs(astrDeb)
            astrDeb = [
                'libacl1-dev:riscv64',
                'libreadline-dev:riscv64',
                'libudev-dev:riscv64'
            ]
            install.install_foreign_debs(astrDeb, strCfg_workingFolder, strCfg_projectFolder)
            strLib = os.path.join(
                strCfg_workingFolder,
                'packages',
                'lib',
                'riscv64-linux-gnu',
                'libacl.a'
            )
            strLibNew = os.path.join(
                strCfg_workingFolder,
                'packages',
                'usr',
                'lib',
                'riscv64-linux-gnu',
                'libacl.a'
            )
            if os.path.exists(strLib) is not True:
                if os.path.exists(strLibNew) is not True:
                    raise Exception(
                        'libacl does not exist in the 2 expected locations '
                        '%s and %s.' % (
                            strLib,
                            strLibNew
                        )
                    )
                else:
                    os.symlink(
                        strLibNew,
                        strLib
                    )

            astrCMAKE_COMPILER = [
                '-DCMAKE_TOOLCHAIN_FILE=%s/cmake/toolchainfiles/toolchain_ubuntu_riscv64.cmake' % strCfg_projectFolder
            ]
            astrCMAKE_PLATFORM = [
                '-DJONCHKI_PLATFORM_DIST_ID=%s' % tPlatform['distribution_id'],
                '-DJONCHKI_PLATFORM_DIST_VERSION=%s' % tPlatform['distribution_version'],
                '-DJONCHKI_PLATFORM_CPU_ARCH=%s' % tPlatform['cpu_architecture']
            ]

            astrJONCHKI_SYSTEM = [
                '--distribution-id %s' % tPlatform['distribution_id'],
                '--distribution-version %s' % tPlatform['distribution_version'],
                '--cpu-architecture %s' % tPlatform['cpu_architecture']
            ]
            strMake = 'make'

        else:
            raise Exception('Unknown CPU architecture: "%s"' % tPlatform['cpu_architecture'])

    elif tPlatform['distribution_id'] == 'windows':
        # Cross build on linux for windows.

        if tPlatform['cpu_architecture'] == 'x86':
            # Build for 32bit windows.
            astrCMAKE_COMPILER = [
                '-DCMAKE_TOOLCHAIN_FILE=%s/cmake/toolchainfiles/toolchain_windows_32.cmake' % strCfg_projectFolder
            ]
            astrCMAKE_PLATFORM = [
                '-DJONCHKI_PLATFORM_DIST_ID=windows',
                '-DJONCHKI_PLATFORM_DIST_VERSION=""',
                '-DJONCHKI_PLATFORM_CPU_ARCH=x86'
            ]
            astrJONCHKI_SYSTEM = [
                '--distribution-id windows',
                '--empty-distribution-version',
                '--cpu-architecture x86'
            ]
            strMake = 'make'

        elif tPlatform['cpu_architecture'] == 'x86_64':
            # Build for 64bit windows.
            astrCMAKE_COMPILER = [
                '-DCMAKE_TOOLCHAIN_FILE=%s/cmake/toolchainfiles/toolchain_windows_64.cmake' % strCfg_projectFolder
            ]
            astrCMAKE_PLATFORM = [
                '-DJONCHKI_PLATFORM_DIST_ID=windows',
                '-DJONCHKI_PLATFORM_DIST_VERSION=""',
                '-DJONCHKI_PLATFORM_CPU_ARCH=x86_64'
            ]
            astrJONCHKI_SYSTEM = [
                '--distribution-id windows',
                '--empty-distribution-version',
                '--cpu-architecture x86_64'
            ]
            strMake = 'make'

        else:
            raise Exception('Unknown CPU architecture: "%s"' % tPlatform['cpu_architecture'])

    else:
        raise Exception('Unknown distribution: "%s"' % tPlatform['distribution_id'])

else:
    raise Exception(
        'Unknown host distribution: "%s"' %
        tPlatform['host_distribution_id']
    )

# Create the folders if they do not exist yet.
astrFolders = [
    strCfg_workingFolder
]
for strPath in astrFolders:
    if os.path.exists(strPath) is not True:
        os.makedirs(strPath)


# ---------------------------------------------------------------------------
#
# Read the project version from the "setup.xml" file in the root folder.
#
tSetupXml = xml.etree.ElementTree.parse(
    os.path.join(
        strCfg_projectFolder,
        'setup.xml'
    )
)
strMbsProjectVersion = tSetupXml.find('project_version').text
print('Project version = %s' % strMbsProjectVersion)


# ---------------------------------------------------------------------------
#
# Build the flasher netX code.
#
astrArguments = [
    sys.executable,
    'mbs/mbs'
]
subprocess.check_call(
    astrArguments,
    cwd=strCfg_projectFolder
)


# ---------------------------------------------------------------------------
#
# Build the romloader netX code.
#
astrArguments = [
    sys.executable,
    'mbs/mbs'
]
subprocess.check_call(
    astrArguments,
    cwd=os.path.join(
        strCfg_projectFolder,
        'flasher-environment',
        'org.muhkuh.lua-romloader'
    )
)


# ---------------------------------------------------------------------------
#
# Build the project.
#
strCmakeFolder = os.path.join(
    strCfg_projectFolder,
    'flasher-environment'
)
astrCmd = [
    'cmake',
    '-DCMAKE_INSTALL_PREFIX=""',
    '-DPRJ_DIR=%s' % strCmakeFolder,
    '-DWORKING_DIR=%s' % strCfg_workingFolder,
    '-DMBS_PROJECT_VERSION=%s' % strMbsProjectVersion
]
astrCmd.extend(astrCMAKE_COMPILER)
astrCmd.extend(astrCMAKE_PLATFORM)
astrCmd.append(strCmakeFolder)
subprocess.check_call(' '.join(astrCmd), shell=True, cwd=strCfg_workingFolder, env=astrEnv)

astrCmd = [
    strMake,
    'install'
]
subprocess.check_call(' '.join(astrCmd), shell=True, cwd=strCfg_workingFolder, env=astrEnv)
