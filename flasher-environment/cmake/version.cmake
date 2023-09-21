#-----------------------------------------------------------------------------
#
# Get the VCS version and store it in the variable PROJECT_VERSION_VCS.
#

# TODO: Check the project's root folder for a ".git", ".hg" or ".svn" folder.
# For now we know that this project uses GIT.
FIND_PACKAGE(Git)
IF(GIT_FOUND)
	# Run this command in the project root folder. The build folder might be somewhere else.
	EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} describe --abbrev=12 --always --dirty=+
	                WORKING_DIRECTORY ${CMAKE_HOME_DIRECTORY}
	                RESULT_VARIABLE VCS_VERSION_RESULT
	                OUTPUT_VARIABLE VCS_VERSION_OUTPUT)
	
	IF(VCS_VERSION_RESULT EQUAL 0)
		STRING(STRIP "${VCS_VERSION_OUTPUT}" VCS_VERSION_OUTPUT_STRIP)
		
		STRING(REGEX MATCH "^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\\+?$" MATCH ${VCS_VERSION_OUTPUT_STRIP})
		IF(NOT MATCH STREQUAL "")
			# This is a repository with no tags. Use the raw SHA sum.
			SET(PROJECT_VERSION_VCS_VERSION ${MATCH})
		ELSE(NOT MATCH STREQUAL "")
			STRING(REGEX MATCH "^v([0-9]+\\.[0-9]+\\.[0-9]+)$" MATCH ${VCS_VERSION_OUTPUT_STRIP})
			IF(NOT MATCH STREQUAL "")
				# This is a repository which is exactly on a tag. Use the tag name.
				SET(PROJECT_VERSION_VCS_VERSION ${CMAKE_MATCH_1})
			ELSE(NOT MATCH STREQUAL "")
				STRING(REGEX MATCH "^v[0-9]+\\.[0-9]+\\.[0-9]+-[0-9]+-g([0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\\+?)$" MATCH ${VCS_VERSION_OUTPUT_STRIP})
				IF(NOT MATCH STREQUAL "")
					# This is a repository with commits after the last tag.
					SET(PROJECT_VERSION_VCS_VERSION ${CMAKE_MATCH_1})
				ELSE(NOT MATCH STREQUAL "")
					# The description has an unknown format.
					SET(PROJECT_VERSION_VCS_VERSION ${VCS_VERSION_OUTPUT_STRIP})
				ENDIF(NOT MATCH STREQUAL "")
			ENDIF(NOT MATCH STREQUAL "")
		ENDIF(NOT MATCH STREQUAL "")
	ENDIF(VCS_VERSION_RESULT EQUAL 0)
	
	STRING(CONCAT PROJECT_VERSION_VCS "GIT" "${PROJECT_VERSION_VCS_VERSION}")
ELSE(GIT_FOUND)
	SET(PROJECT_VERSION_VCS unknown)
ENDIF(GIT_FOUND)

MESSAGE("PROJECT_VERSION_VCS: ${PROJECT_VERSION_VCS}")
