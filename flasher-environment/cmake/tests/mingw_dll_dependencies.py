import argparse
import re
import subprocess
import sys


__astrStandardDlls = [
    'advapi32',
    'crypt32',
    'kernel32',
    'msvcrt',
    'secur32',
    'setupapi',
    'shlwapi',
    'user32',
    'ws2_32'
]


def main(argv):
    tParser = argparse.ArgumentParser(
        description='Check the DLL dependencies of an executable.'
    )
    tParser.add_argument('infile', nargs='+',
                         help='read the input data from INPUT_FILENAME',
                         metavar='INPUT')
    tParser.add_argument('-o', '--objdump',
                         dest='strObjDump',
                         default='objdump',
                         help='use OBJDUMP to extract the dependencies',
                         metavar='OBJDUMP')
    tParser.add_argument('-v', '--verbose',
                         dest='fVerbose',
                         action='store_true',
                         default=False,
                         help='be more verbose')
    tParser.add_argument('-u', '--userdll',
                         dest='astrUserDlls',
                         action='append',
                         help='add DLL to the list of known user DLLs',
                         metavar='DLL')
    aOptions = tParser.parse_args()

    # Build the combined list of DLLs.
    astrAllowedDlls = __astrStandardDlls
    if aOptions.astrUserDlls is not None:
        for strDll in aOptions.astrUserDlls:
            astrAllowedDlls.append(strDll.lower())

    for strInFile in aOptions.infile:
        if aOptions.fVerbose is True:
            print('Checking %s...' % strInFile)

        # Get all DLL dependencies from the file.
        aCmd = [aOptions.strObjDump, '-p', strInFile]
        tProc = subprocess.Popen(aCmd, stdout=subprocess.PIPE)
        strOutput = tProc.communicate()[0].decode("utf-8", "replace")
        if tProc.returncode != 0:
            raise Exception('The command failed with return code %d: %s' % (
                tProc.returncode,
                ' '.join(aCmd)
            ))

        # Find all DLL dependencies.
        for tMatch in re.finditer(r'DLL Name:\s+(.+).dll', strOutput):
            # Strip all leading and trailing spaces from the DLL name and
            # convert it to lower case.
            strDll = tMatch.group(1).strip().lower()
            if aOptions.fVerbose is True:
                print('Found dependency %s.dll' % strDll)
            if strDll not in astrAllowedDlls:
                raise Exception('The DLL dependency %s is not part of the '
                                'standard system DLLs.' % strDll)


if __name__ == '__main__':
    main(sys.argv[1:])
    print("All OK!")
    sys.exit(0)
