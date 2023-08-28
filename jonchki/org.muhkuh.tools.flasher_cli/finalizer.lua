local t = ...

t:install {
  -- Copy all demo scripts to the installation base.
  ['${depack_path_org.muhkuh.tools.flasher.lua5.4-flasher}/demo'] = '${install_base}/',

  -- Copy the report.
  ['${report_path}']                                              = '${install_base}/.jonchki/'
}

-- Install the wrapper.
local strDistId = t:get_platform()
if strDistId=='ubuntu' then
  -- This is a shell script setting the library search path for the LUA shared object.
  t:install('../../wrapper/linux/lua5.1.sh', '${install_base}/')
  -- Copy the muhkuh CLI init for linux.
  t:install('../../jonchki/org.muhkuh.tools.flasher_cli/linux/muhkuh_cli_init.lua', '${install_base}/')
elseif strDistId=='windows' then
  -- Copy the muhkuh CLI init for windows.
  t:install('../../jonchki/org.muhkuh.tools.flasher_cli/windows/muhkuh_cli_init.lua', '${install_base}/')
end

return true
