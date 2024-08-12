#! /usr/bin/python3

from cmake import cli_args
from cmake import install

import xml.etree.ElementTree
import os
import subprocess
import sys
import zipfile
import shutil
from gitVersionManager import gitVersionManager
import re
from datetime import datetime
import hashlib

tPlatform, flags = cli_args.parse()
print('Building for %s' % tPlatform['platform_id'])
if (flags["gitTagRequested"]):
    print('Setting a new git Tag after build.')

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

        astrDeb = [
            'pkg-config'
        ]
        install.install_host_debs(astrDeb)

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
# Versioning
#
# Set git tag if desired.
# Get the flasher version from git.
# Prepare the artifact archive name.
# Write the flasher version to the setup.xml file
#

# Get the flasher repo and the current branch name
repoManager = gitVersionManager(strCfg_projectFolder, "flasher")
if flags["gitTagRequested"]:
    repoManager.createDevTag()

# Set the artifact name
strMbsProjectVersion = repoManager.getFullVersionString()

# Create the name of the platform following the hilscher naming conventions
translator = dict(x86="x86", x86_64="x64", windows="Windows", ubuntu="Ubuntu", arm64="arm64", armhf="armhf",
                  riscv64="riscv64")
strPlatform = tPlatform["distribution_version"] or ""
strArtifactPlatform = translator[tPlatform["distribution_id"]] + strPlatform + "-" + translator[
    tPlatform["cpu_architecture"]]

# Write the flasher version to the xml file (XML parser would delete comments in file)
with open(os.path.join(strCfg_projectFolder, 'setup.xml'), "r+") as tSetupXmlFile:
    groups = list(
        re.search(r"([\d\D\s]+)(<project_version>)(.+)(<\/project_version>)([\d\D\s]*)", tSetupXmlFile.read()).groups())
    groups[2] = repoManager.getVersionNumber()[1:]
    stringOut = "".join(groups)
    tSetupXmlFile.seek(0)
    tSetupXmlFile.write(stringOut)
    tSetupXmlFile.truncate()

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
# Generate the output folder name out of the romloader git tags
print("load romloader files")
strRomloaderFolder = os.path.join(strCfg_projectFolder, "flasher-environment", "org.muhkuh.lua-romloader")
romloaderRepoManager = gitVersionManager(strRomloaderFolder, "romloader")
romloaderArtifactName = "montest_" + romloaderRepoManager.getFullVersionString()
print(f"romloader artifact: {romloaderArtifactName}")

# Build
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

build_artifact_path = os.path.join(strCfg_projectFolder, "flasher-environment", "build", "artifacts")

# Copy the romloader binaries and a version info file to a separate zip
# Create paths
if flags["buildMontest"]:
    print("Creating romloader montest artifact")
    tRomloaderSetupXml = xml.etree.ElementTree.parse(os.path.join(strRomloaderFolder, 'setup.xml'))
    strRomloaderVersion = tRomloaderSetupXml.find('project_version').text
    print('Romloader version parsed from setup.xml = %s' % strRomloaderVersion)
    strMontestOutputFolder = os.path.join(
        strRomloaderFolder, "targets", "jonchki", "repository", "org",
        "muhkuh", "lua", "romloader", strRomloaderVersion
    )
    strMontestUnZipFolder = os.path.join(strMontestOutputFolder, "romloader-montest-" + strRomloaderVersion)
    strMontestZipFolder = strMontestUnZipFolder + '.zip'
    strMontestArtifactPath = os.path.join(build_artifact_path, romloaderArtifactName)

    # Check that the romloader version parsed from the xml file is valid
    assert os.path.exists(strMontestOutputFolder), "Can not find montest output folder"
    assert os.path.exists(strMontestZipFolder), "Montest output zip archive is missing"

    # Unzip the romloader artifact (delete output from previous run first)
    if os.path.exists(strMontestUnZipFolder):
        shutil.rmtree(strMontestUnZipFolder)
    with zipfile.ZipFile(strMontestZipFolder, 'r') as zip:
        zip.extractall(strMontestUnZipFolder)

    # Copy the required files to a fresh zip-preparation folder
    strMontestPreparedForZipPath = os.path.join(strMontestOutputFolder, romloaderArtifactName)
    if os.path.exists(strMontestPreparedForZipPath):
        shutil.rmtree(strMontestPreparedForZipPath)
    os.mkdir(strMontestPreparedForZipPath)
    atCopyFiles = {
        "/test_romloader_lua54.lua",
        "/netx/montest_netiol.bin",
        "/netx/montest_netx10.bin",
        "/netx/montest_netx4000.bin",
        "/netx/montest_netx50.bin",
        "/netx/montest_netx500.bin",
        "/netx/montest_netx56.bin",
        "/netx/montest_netx90.bin",
        "/netx/montest_netx90_mpw.bin"
    }
    for file in atCopyFiles:
        ret = shutil.copy(strMontestUnZipFolder + file, strMontestPreparedForZipPath)

    # Create a file that contains version information
    with open(os.path.join(strMontestPreparedForZipPath, "version_info.txt"), "w") as versionInfoFile:
        commitTime = romloaderRepoManager.repo.head.commit.authored_datetime.strftime("%Y.%m.%d %H:%M:%S")
        currentTime = datetime.now().strftime("%Y.%M.%d %H:%M:%S")
        info = f"This file contains version information about the romloader montest artifacts.\n"
        info += f"Generated by build_artifact.py during flasher build process.\n"
        info += f"Used for human reading only, no processing elsewhere.\n\n"
        info += f"Version:     {romloaderRepoManager.getFullVersionString()}\n"
        info += f"Commit:      {romloaderRepoManager.repo.head.commit.hexsha}\n"
        info += f"Commit time: {commitTime}\n"
        info += f"Repo dirty:  {romloaderRepoManager.repo.is_dirty()}\n"
        info += f"Build time:  {currentTime}\n"
        versionInfoFile.write(info)

    # Rename the lua5.4 file to be the "normal" file
    rename_old = os.path.join(strMontestPreparedForZipPath, "test_romloader_lua54.lua")
    rename_new = os.path.join(strMontestPreparedForZipPath, "test_romloader.lua")
    os.rename(rename_old, rename_new)

    # Compress the files in the zip preparation folder into a .zip archive in the artifacts directory
    shutil.make_archive(strMontestArtifactPath, 'zip', strMontestPreparedForZipPath)

    # Remove the folders created in the lua repository folder
    shutil.rmtree(strMontestPreparedForZipPath)
    shutil.rmtree(strMontestUnZipFolder)

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
    '-DMBS_PROJECT_VERSION=%s' % strMbsProjectVersion,
    '-DARTIFACT_PLATFORM_STRING=%s' % strArtifactPlatform
]
astrCmd.extend(astrCMAKE_COMPILER)
astrCmd.extend(astrCMAKE_PLATFORM)
astrCmd.append(strCmakeFolder)
subprocess.check_call(' '.join(astrCmd), shell=True, cwd=strCfg_workingFolder, env=astrEnv)

astrCmd = [
    strMake,
    'install', 'package'
]
subprocess.check_call(' '.join(astrCmd), shell=True, cwd=strCfg_workingFolder, env=astrEnv)

print("creating sha256 images of flasher packet")
print(f"search dir: {build_artifact_path}")
for filename in os.listdir(build_artifact_path):
    if filename.endswith(".tar.gz") or filename.endswith(".zip") and filename.startswith("flasher"):
        print(f"found image:    {filename}")
        filepath = os.path.join(build_artifact_path, filename)
        with open(filepath, 'rb') as f:
            data = f.read()
            filename_sha = os.path.join(build_artifact_path, filename + ".sha256")
            hash_sha256 = hashlib.sha256(data).hexdigest()
            print(f"generate image: {filename_sha}")
            with open(filename_sha, "w") as sha_f:
                sha_f.write(f"{hash_sha256} *{filename}")
            print("")

# Print a message that reminds the user to push the tag to the repository
if flags["gitTagRequested"]:
    print("A local git tag was requested. Do not forget to push it to the GitHub repository using \"git push --tags\"")