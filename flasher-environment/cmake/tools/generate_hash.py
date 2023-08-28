import argparse
import glob
import hashlib
import os.path
import string


tParser = argparse.ArgumentParser(description='Generate a hash file for jonchki.')
tParser.add_argument('input')
tParser.add_argument('output', nargs='?', default=None)
tArgs = tParser.parse_args()

astrIn = glob.glob(tArgs.input)
if len(astrIn)==0:
    raise Exception('The input file "%s" does not exist.' % tArgs.input)
if len(astrIn)!=1:
    raise Exception('More than one match found for pattern "%s".' % tArgs.input)
strInputPath = astrIn[0]

if tArgs.output is None:
  strOutputPath = '%s.hash' % strInputPath
else:
  strOutputPath = tArgs.output


# Create all hash instances.
tHash_MD5 = hashlib.md5()
tHash_SHA1 = hashlib.sha1()
tHash_SHA224 = hashlib.sha224()
tHash_SHA256 = hashlib.sha256()
tHash_SHA384 = hashlib.sha384()
tHash_SHA512 = hashlib.sha512()

tFile = open(strInputPath, 'rb')
while True:
    strData = tFile.read(4096)
    if strData=='':
        break

    tHash_MD5.update(strData)
    tHash_SHA1.update(strData)
    tHash_SHA224.update(strData)
    tHash_SHA256.update(strData)
    tHash_SHA384.update(strData)
    tHash_SHA512.update(strData)

tFile.close()

atReplace = dict()
atReplace['MD5'] = tHash_MD5.hexdigest()
atReplace['SHA1'] = tHash_SHA1.hexdigest()
atReplace['SHA224'] = tHash_SHA224.hexdigest()
atReplace['SHA256'] = tHash_SHA256.hexdigest()
atReplace['SHA384'] = tHash_SHA384.hexdigest()
atReplace['SHA512'] = tHash_SHA512.hexdigest()

tTemplate = string.Template("""MD5:${MD5}
SHA1:${SHA1}
SHA224:${SHA224}
SHA256:${SHA256}
SHA384:${SHA384}
SHA512:${SHA512}
""")
strHash = tTemplate.safe_substitute(atReplace)

tFile = open(strOutputPath, 'wt')
tFile.write(strHash)
tFile.close()
