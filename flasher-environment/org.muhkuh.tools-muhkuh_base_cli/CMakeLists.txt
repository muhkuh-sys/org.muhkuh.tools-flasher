PROJECT("muhkuh_base_cli")

SET(VERSION_EXTERNAL "2.3.3")


#----------------------------------------------------------------------------
#
# Install all files.
#
INSTALL(FILES lua/muhkuh.lua lua/select_plugin_cli.lua lua/tester_cli.lua lua/utils.lua
        DESTINATION ${FLASHER_PACKAGE_DIR}/lua)
