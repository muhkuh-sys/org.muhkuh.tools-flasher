local t = ...

t:install {
  -- Copy all demo scripts to the installation base.
  ['${depack_path_org.muhkuh.tools.flasher.lua5.4-flasher}/demo'] = '${install_base}/',

  -- Copy the report.
  ['${report_path}']                                              = '${install_base}/.jonchki/'
}

return true
