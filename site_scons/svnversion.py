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


import os

from SCons.Script import *


def svnversion_action(target, source, env):
	global PROJECT_VERSION
	
	# split up the project version
	version_info = PROJECT_VERSION.split('.')
	project_version_maj = version_info[0]
	project_version_min = version_info[1]
	project_version_svn = env['PROJECT_VERSION_SVN']
	
	# apply the project version to the environment
	substenv = Environment()
	substenv['PROJECT_VERSION_MAJ'] = project_version_maj
	substenv['PROJECT_VERSION_MIN'] = project_version_min
	substenv['PROJECT_VERSION_SVN'] = project_version_svn
	
	# read the template
	src_file = open(source[0].get_path(), 'r')
	src_txt = src_file.read()
	src_file.close()
	
	# read the destination (if exists)
	try:
		dst_file = open(target[0].get_path(), 'r')
		dst_oldtxt = dst_file.read()
		dst_file.close()
	except IOError:
		dst_oldtxt = ''
	
	# filter the src file
	dst_newtxt = substenv.subst(src_txt)
	if dst_newtxt!=dst_oldtxt:
		# overwrite the file
		dst_file = open(target[0].get_path(), 'w')
		dst_file.write(dst_newtxt)
		dst_file.close()


def svnversion_emitter(target, source, env):
	global PROJECT_VERSION
	
	# Is the environment variable "PROJECT_VERSION_SVN" already set?
	if not 'PROJECT_VERSION_SVN' in env:
		# The default for the SVN version is 'unknown'.
		project_version_svn = 'unknown'
		
		# Is the 'svnversion' command available?
		if env['SVNVERSION']:
			# Yes -> get the svn version.
			child = os.popen(env['SVNVERSION']+' -n')
			project_version_svn = child.read()
			err = child.close()
			# Do not use the output if an error occured.
			if err:
				project_version_svn = 'unknown'
		
		# Set the environment variable "PROJECT_VERSION_SVN".
		env['PROJECT_VERSION_SVN'] = project_version_svn
		# Set the filesystem friendly variant.
		env['PROJECT_VERSION_SVN_ESCAPED'] = project_version_svn.replace(':', '_').replace('\\', '_').replace('/', '_')
	
	# Make the target depend on the project version and the SVN version.
	Depends(target, SCons.Node.Python.Value(PROJECT_VERSION))
	Depends(target, SCons.Node.Python.Value(env['PROJECT_VERSION_SVN']))
	
	return target, source


def svnversion_string(target, source, env):
	return 'SVNVersion %s' % target[0].get_path()


def ApplyToEnv(env):
	#----------------------------------------------------------------------------
	#
	# Add uuencode builder.
	#
	env['SVNVERSION'] = env.Detect('svnversion')
	
	svnversion_act = SCons.Action.Action(svnversion_action, svnversion_string)
	svnversion_bld = Builder(action=svnversion_act, emitter=svnversion_emitter, single_source=1)
	env['BUILDERS']['SVNVersion'] = svnversion_bld

