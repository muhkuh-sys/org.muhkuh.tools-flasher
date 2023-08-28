import logging
import os
import os.path
import patch
import string


def apply_diffs(strWorkingFolder, strPatchFolder, uiStrip):
    # Collect all ".diff" files from the patch folder.
    astrPatches = []
    for strDirname, astrDirnames, astrFilenames in os.walk(strPatchFolder):
        for strFilename in astrFilenames:
            strDummy, strExt = os.path.splitext(strFilename)
            if strExt == '.diff':
                strAbsFilename = os.path.join(strDirname, strFilename)
                astrPatches.append(strAbsFilename)

    # Sort the patches alphabetically.
    astrSortedPatches = sorted(astrPatches)
    for strPatch in astrSortedPatches:
        print('Apply patch "%s"...' % strPatch)

        # Apply the patches.
        tPatch = patch.fromfile(strPatch)
        tPatch.diffstat()
        tResult = tPatch.apply(uiStrip, root=strWorkingFolder)
        if tResult is not True:
            raise Exception('Failed to apply patch "%s"!' % strPatch)


def __copy_file(strSource, strDestination):
    # Copy the data in chunks of 4096 bytes.
    sizChunk = 4096

    # Open the files.
    tFileSrc = open(strSource, 'rb')
    tFileDst = open(strDestination, 'wb')

    # Copy the data in chunks of 4096 bytes.
    fEof = False
    while fEof is False:
        strData = tFileSrc.read(sizChunk)
        tFileDst.write(strData)
        if len(strData) < sizChunk:
            fEof = True

    tFileSrc.close()
    tFileDst.close()


def copy_files(strWorkingFolder, strCopyFolder):
    for strDirname, astrDirnames, astrFilenames in os.walk(strCopyFolder):
        # Get the path from the start folder to the current folder.
        strCurrentRelPath = os.path.relpath(strDirname, strCopyFolder)

        strWorkingSubFolder = os.path.join(strWorkingFolder, strCurrentRelPath)

        # Create the current subfolder in the working folder.
        if os.path.exists(strWorkingSubFolder) is not True:
            print('Create folder "%s".' % strWorkingSubFolder)
            os.mkdir(strWorkingSubFolder)

        # Copy all files in the folder.
        for strFilename in astrFilenames:
            strSourceFile = os.path.join(strDirname, strFilename)
            strDestinationFile = os.path.join(strWorkingSubFolder,
                                              strFilename)
            print('Copy file "%s" -> "%s".' % (strSourceFile,
                                               strDestinationFile))
            __copy_file(strSourceFile, strDestinationFile)


def copy_list(strWorkingFolder, strCopyList):
    # Open the copy list.
    tFile = open(strCopyList, 'rt')
    uiLineCnt = 0
    # Read the file line by line.
    for strLine in tFile:
        # Count lines starting with 1.
        uiLineCnt += 1
        # Strip whitespace at the beginning and end of the file.
        strLine = string.strip(strLine)
        # Ignore empty lines or comments (starting with "#").
        if len(strLine) != 0 and strLine[0] != '#':
            # Split the line by commata. There should be 2 elements.
            astrArgs = string.split(strLine, ',')
            if len(astrArgs) != 2:
                raise Exception('Invalid entry in copy list "%s" line %d. Expected one comma.' % (strCopyList, uiLineCnt))
            # Strip whitespace from both arguments.
            strSrc = string.strip(astrArgs[0])
            strDst = string.strip(astrArgs[1])
            print('Copy file "%s" -> "%s".' % (strSrc, strDst))
            __copy_file(strSrc, strDst)
    tFile.close()


def main():
    import argparse

    tParser = argparse.ArgumentParser(
        description='Apply diffs and copy files to patch a source tree.')
    tParser.add_argument(
        '-w', '--working-folder',
        dest='strWorkingFolder',
        required=True,
        help='use PATH as the working folder',
        metavar='PATH'
    )
    tParser.add_argument(
        '-p', '--patch-folder',
        dest='strPatchFolder',
        required=False,
        default=None,
        help='scan PATH for .diff files and apply them to the working folder',
        metavar='PATH'
    )
    tParser.add_argument(
        '-s', '--strip',
        dest='uiStrip',
        required=False,
        default=0,
        metavar='N',
        type=int,
        help='strip N levels from the paths in all patch files'
    )
    tParser.add_argument(
        '-c', '--copy-folder',
        dest='strCopyFolder',
        required=False,
        default=None,
        help='copy the contents of PATH recursively over the working folder',
        metavar='PATH'
    )
    tParser.add_argument(
        '-l', '--copy-list',
        dest='strCopyList',
        required=False,
        default=None,
        help='process FILE as a list of SOURCE,DESTINATION entries of files to copy',
        metavar='PATH'
    )
    aOptions = tParser.parse_args()

    print('Using patch %s by %s.' % (patch.__version__, patch.__author__))

    # verbosity levels = logging.WARNING, logging.INFO, logging.DEBUG
    logformat = "%(message)s"
    patch.logger.setLevel(logging.DEBUG)
    patch.streamhandler.setFormatter(logging.Formatter(logformat))
    patch.setdebug()

    # Check if the working folder exists.
    if os.path.exists(aOptions.strWorkingFolder) is not True:
        raise Exception(
            'The working folder "%s" does not exist or is not accessible.' %
            aOptions.strWorkingFolder
        )
    if os.path.isdir(aOptions.strWorkingFolder) is not True:
        raise Exception(
            'The working folder "%s" is no folder.' %
            aOptions.strWorkingFolder
        )

    # Is the patch folder defined?
    if aOptions.strPatchFolder is not None:
        if os.path.exists(aOptions.strPatchFolder) is not True:
            raise Exception(
                'The patch folder "%s" does not exist or is not accessible.' %
                aOptions.strPatchFolder
            )
        if os.path.isdir(aOptions.strPatchFolder) is not True:
            raise Exception(
                'The patch folder "%s" is no folder.' %
                aOptions.strPatchFolder
            )

        apply_diffs(aOptions.strWorkingFolder,
                    aOptions.strPatchFolder,
                    aOptions.uiStrip)

    # Is the copy folder defined?
    if aOptions.strCopyFolder is not None:
        if os.path.exists(aOptions.strCopyFolder) is not True:
            raise Exception(
                'The copy folder "%s" does not exist or is not accessible.' %
                aOptions.strCopyFolder
            )
        if os.path.isdir(aOptions.strCopyFolder) is not True:
            raise Exception(
                'The copy folder "%s" is no folder.' %
                aOptions.strCopyFolder
            )

        copy_files(aOptions.strWorkingFolder, aOptions.strCopyFolder)

    # Is the copy list defined?
    if aOptions.strCopyList is not None:
        if os.path.exists(aOptions.strCopyList) is not True:
            raise Exception(
                'The copy list "%s" does not exist or is not accessible.' %
                aOptions.strCopyList
            )
        if os.path.isfile(aOptions.strCopyList) is not True:
            raise Exception(
                'The copy list "%s" is no regular file.' %
                aOptions.strCopyList
            )

        copy_list(aOptions.strWorkingFolder, aOptions.strCopyList)


if __name__ == "__main__":
    main()
