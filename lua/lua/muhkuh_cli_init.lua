-- Load the common romloader plugins.
require("romloader_eth")
require("romloader_usb")
require("romloader_uart")
require("romloader_jtag")

-- Load the common modules for a CLI environment.
_G.muhkuh = require("muhkuh")
_G.select_plugin = require("select_plugin_cli")
_G.tester = require("tester_cli")

-- This string is appended to all paths in the function "load_from_working_folder".
_G.__MUHKUH_WORKING_FOLDER = ""
