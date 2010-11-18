# -*- coding: utf-8 -*-
#-------------------------------------------------------------------------#
#   Copyright (C) 2010 by Christoph Thelen                                #
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


import zipfile

from SCons.Script import *


def zip_package_get_package_suffix(env):
	global PROJECT_VERSION
	
	
	# Get a fallback SVN version.
	if 'PROJECT_VERSION_SVN' in env:
		strSvnVersion = env['PROJECT_VERSION_SVN'].replace(':', '_').replace('\\', '_').replace('/', '_')
	else:
		strSvnVersion = 'unknown'
	
	# Get the package name.
	strPackageName = '%s.%s'%(PROJECT_VERSION,strSvnVersion)
	
	return strPackageName


def zip_package_add(env, strFolder, files):
	global ZIP_PACKAGE_LIST
	
	
	# Convert a single file to a list.
	if isinstance(files, basestring):
		aFiles = [ files ]
	else:
		aFiles = files
	
	# Does the folder already exist?
	if strFolder in ZIP_PACKAGE_LIST:
		# Add the file list to this folder.
		ZIP_PACKAGE_LIST[strFolder].extend(aFiles)
	else:
		# Create a new folder.
		ZIP_PACKAGE_LIST[strFolder] = aFiles


def zip_package_action(target, source, env):
	global ZIP_PACKAGE_LIST
	
	
	strPackageName = '%s-%s'%(env['PROJECT_NAME'], zip_package_get_package_suffix(env))
	
	fZip = zipfile.ZipFile(target[0].get_path(), 'w', zipfile.ZIP_DEFLATED)
	
	for (strFolder, aFiles) in ZIP_PACKAGE_LIST.items():
		for tFile in aFiles:
			if isinstance(tFile, basestring):
				strFilename = tFile
			else:
				strFilename = tFile.get_path()
			strArchiveFullPath = os.path.join(strPackageName, strFolder, os.path.basename(strFilename))
			fZip.write(strFilename, strArchiveFullPath)
	
	# Close the archive.
	fZip.close()


def zip_package_emitter(target, source, env):
	global PROJECT_VERSION
	global ZIP_PACKAGE_LIST
	
	
	# Make the target depend on the project version and the project name.
	Depends(target, SCons.Node.Python.Value(PROJECT_VERSION))
	Depends(target, SCons.Node.Python.Value(env['PROJECT_NAME']))
	
	# Make the target depend on all source files and on the combination of the file and the archive path.
	for (strFolder, aFiles) in ZIP_PACKAGE_LIST.items():
		for tFile in aFiles:
			if isinstance(tFile, basestring):
				strFilename = tFile
			else:
				# Assume this is a file node.
				strFilename = tFile.get_path()
			Depends(target, tFile)
			Depends(target, SCons.Node.Python.Value('%s:%s'%(strFolder,strFilename)))
	
	return target, source


def zip_package_string(target, source, env):
	return 'ZipPackage %s' % target[0].get_path()


def ApplyToEnv(env):
	global ZIP_PACKAGE_LIST
	
	
	#----------------------------------------------------------------------------
	#
	# Add the zip package builder.
	#
	zip_package_act = SCons.Action.Action(zip_package_action, zip_package_string)
	zip_package_bld = Builder(action=zip_package_act, emitter=zip_package_emitter, suffix='.zip')
	env['BUILDERS']['ZipPackage'] = zip_package_bld
	
	# Create an empty package list.
	try:
		ZIP_PACKAGE_LIST
	except NameError:
		ZIP_PACKAGE_LIST = dict({})
	
	env.AddMethod(zip_package_add, "ZipPackageAdd")
	env.AddMethod(zip_package_get_package_suffix, "ZipPackageSuffix")
