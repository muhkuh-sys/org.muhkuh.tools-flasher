#! /usr/bin/python3

from cmake import cli_args
from cmake import install

import xml.etree.ElementTree
import os
import subprocess
import sys
import zipfile
import shutil
import git
import re


tPlatform, flags = cli_args.parse()
print('Building for %s' % tPlatform['platform_id'])
if(flags["gitTagRequested"]):
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
# Read the project version from the "setup.xml" file in the root folder.
# Get the last git tag on the current branch if enabled
#
tSetupXml = xml.etree.ElementTree.parse(
    os.path.join(
        strCfg_projectFolder,
        'setup.xml'
    )
)
strMbsProjectVersion = tSetupXml.find('project_version').text # "2.1.0"

# Get the current branch name
repo = git.Repo(strCfg_projectFolder)
strBranchName = repo.active_branch.name
strBranchName = "dev_v2.1.0" #TODO set for test purposes, delete this

# only dev branches will have dev tags (they match the pattern "dev_vX.Y.Z")
if not re.match(r"^dev_v\d+.\d+.\d+$", strBranchName):
    if flags["gitTagRequested"]:
        sys.exit("Not on dev-Branch, no Tag will be set!")
else:
    # Get the previous git tag on the branch
    lastTag = sorted(repo.tags, key=lambda t: t.commit.committed_datetime)[-1]
    lastTagCommit = lastTag._get_commit()

        # Check that the name of the previous tag is valid
        assert re.match(r"^v\d+.\d+.\d+-dev\d+$", lastTag.name), "Invalid previous dev tag!"
        commitVersion = re.search(r"v\d+.\d+.\d+", strBranchName).group()
        lastTagVersion = re.search(r"v\d+.\d+.\d+", lastTag.name).group()
        assert commitVersion == lastTagVersion, """Invalid version in previous dev tag! Forgot to manually 
            set \"dev_vX.Y.Z-dev0\" Tag at branch creation??"""
    lastDevTagNumber = int(re.findall(r'\d+', lastTag.name)[-1])
        
    # Find out how many commits have been made since the last tag was set and if the repository is dirty
        commitsSinceLastTag = int(repo.git.rev_list('--count', f'{lastTagCommit.hexsha}..{repo.head.commit.hexsha}'))
    isDirtyPlusChar = "+" if repo.is_dirty() else ""

    # Avoid setting multiple tags on a single commit (compare their hashes)
    if flags["gitTagRequested"] and lastTagCommit.binsha != repo.head.reference._get_commit().binsha:
        # Create a new tag increased by the number of commits since last tag and generate project version string
        newDevTagNumber = lastDevTagNumber + commitsSinceLastTag
        newDevTagName = lastTagVersion + "-dev" + str(newDevTagNumber)
        try:
            newTag = git.Tag.create(repo, newDevTagName, repo.head.commit, "Tag created automatically by flasher build process")
            commitsSinceLastTag = 0
            strMbsProjectVersion += "-dev" + str(newDevTagNumber)
        except:
            print(f'Could not create tag \"{newDevTagName}\" on commit \"{repo.head.commit.hexsha}\" on branch \"{strBranchName}\"')
                sys.exit("Failed to set git tag, check that the repository is clean!")
    else:
        strMbsProjectVersion += "-dev" + str(lastDevTagNumber) 
    strMbsProjectVersion += "-" + str(commitsSinceLastTag) + isDirtyPlusChar + "g" + str(repo.head.commit.hexsha)[:7]

# Create the name of the platform following the hilscher naming conventions
dict = {}
dict["x86"] = "x86"
dict["x86_64"] = "x64"
dict["windows"] = "Windows"
dict["ubuntu"] = "Ubuntu"
strPlatform = tPlatform["distribution_version"] or ""
strArtifactPlatform = dict[tPlatform["distribution_id"]] + strPlatform + "-" + dict[tPlatform["cpu_architecture"]]



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
romloaderSubmodule = None

romloaderSubmodule = next(submodule for submodule in repo.submodules if submodule.name == "flasher-environment/org.muhkuh.lua-romloader")
assert romloaderSubmodule is not None, "Romloader Submodule not found"
romloaderRepo = git.Repo(romloaderSubmodule.abspath)
romloaderLatestTag = sorted(romloaderRepo.tags, key=lambda t: t.commit.committed_datetime)[-1]
romloaderLatestTagName = romloaderLatestTag.name
commitsSinceLastTag = int(romloaderRepo.git.rev_list('--count', f'{romloaderLatestTag.commit.hexsha}..{romloaderRepo.head.commit.hexsha}'))
isDirtyPlusChar = "+" if romloaderRepo.is_dirty() else ""
romloaderArtifactName = "montest_" + romloaderLatestTagName[1:] + "-" + str(commitsSinceLastTag) + isDirtyPlusChar + "g" + str(romloaderRepo.head.commit.hexsha)[:7]

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

# Copy the romloader binaries to a separate zip
# Create paths
if flags["buildMontest"]:
    print("Creating romloader montest artifact")
strRomloaderFolder = os.path.join(strCfg_projectFolder, "flasher-environment", "org.muhkuh.lua-romloader")
tRomloaderSetupXml = xml.etree.ElementTree.parse(os.path.join(strRomloaderFolder,'setup.xml'))
strRomloaderVersion = tRomloaderSetupXml.find('project_version').text
print('Romloader version parsed from setup.xml = %s' % strRomloaderVersion)
strMontestOutputFolder = os.path.join(strRomloaderFolder, "targets", "jonchki", "repository", "org", "muhkuh", "lua", "romloader", strRomloaderVersion)
strMontestUnZipFolder = os.path.join(strMontestOutputFolder, "romloader-montest-" + strRomloaderVersion)
strMontestZipFolder = os.path.join(strMontestUnZipFolder + '.zip')
    strMontestArtifactPath = os.path.join(strCfg_projectFolder, "flasher-environment", "build", "artifacts", romloaderArtifactName)

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

# Rename the lua5.4 file to be the "normal" file
rename_old = os.path.join(strMontestPreparedForZipPath, "test_romloader_lua54.lua")
rename_new = os.path.join(strMontestPreparedForZipPath, "test_romloader.lua")
os.rename(rename_old, rename_new)

# Compress the files in the zip preparation folder into a .zip archive in the artifacts directory
shutil.make_archive(strMontestArtifactPath , 'zip', strMontestPreparedForZipPath)

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

# Print a message that reminds the user to push the tag to the repository
if flags["gitTagRequested"]:
    print("A local git tag was requested. Do not forget to push it to the GitHub repository using \"git push --tags\"")