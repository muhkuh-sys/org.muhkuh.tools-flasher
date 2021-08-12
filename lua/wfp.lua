local archive = require 'archive'
local argparse = require 'argparse'
local pl = require 'pl.import_into'()
local wfp_control = require 'wfp_control'
local wfp_verify = require 'wfp_verify'



local function __writeU32(tFile, ulData)
    local ucB0 = math.fmod(ulData, 256)
    ulData = (ulData - ucB0) / 256
    local ucB1 = math.fmod(ulData, 256)
    ulData = (ulData - ucB1) / 256
    local ucB2 = math.fmod(ulData, 256)
    local ucB3 = (ulData - ucB2) / 256
    tFile:write(string.char(ucB0, ucB1, ucB2, ucB3))
end



local function __getNetxPath()
    local strPathNetx

    -- Split the Lua module path.
    local astrPaths = pl.stringx.split(package.path, ';')
    for _, strPath in ipairs(astrPaths) do
        -- Only process search paths which end in "?.lua".
        if string.sub(strPath, -5) == '?.lua' then
            -- Cut off the "?.lua" part.
            -- Expect the "netx" folder one below the module folder.
            local strPath = pl.path.join(pl.path.dirname(pl.path.dirname(pl.path.abspath(strPath))), 'netx')
            if pl.path.exists(strPath) ~= nil and pl.path.isdir(strPath) == true then
                -- Append a directory separator at the end of the path.
                -- Otherwise the flasher will not be happy.
                strPathNetx = strPath .. pl.path.sep
                break
            end
        end
    end
    return strPathNetx
end

local strFlasherPrefix = __getNetxPath()



local atLogLevels = {
    'debug',
    'info',
    'warning',
    'error',
    'fatal'
}

-- copied from cli_flash.lua!
-- this was necessarry because when importing it with "require 'cli_flash'" the argparser is overwritten
function getPluginByName(strName)
    for iPluginClass, tPluginClass in ipairs(__MUHKUH_PLUGINS) do
        local iDetected
        local aDetectedInterfaces = {}
        print(string.format("Detecting interfaces with plugin %s", tPluginClass:GetID()))
        iDetected = tPluginClass:DetectInterfaces(aDetectedInterfaces)
        print(string.format("Found %d interfaces with plugin %s", iDetected, tPluginClass:GetID()))

        for i, v in ipairs(aDetectedInterfaces) do
            print(string.format("%d: %s (%s) Used: %s, Valid: %s", i, v:GetName(), v:GetTyp(), tostring(v:IsUsed()), tostring(v:IsValid())))
            if strName == v:GetName() then
                if not v:IsValid() then
                    return nil, "Plugin is not valid"
                elseif v:IsUsed() then
                    return nil, "Plugin is in use"
                else
                    print("found plugin")
                    local tPlugin = v:Create()
                    if tPlugin then
                        return tPlugin
                    else
                        return nil, "Error creating plugin instance"
                    end
                end
            end
        end
    end
    return nil, "plugin not found"
end

function getPlugin(strPluginName, strPluginType)
	local tPlugin, strError
	if strPluginName then
		-- get the plugin by name
		tPlugin, strError = getPluginByName(strPluginName)
	else
		-- Ask the user to pick a plugin.
		tPlugin = SelectPlugin(nil, strPluginType)
		if tPlugin == nil then
			strError = "No plugin selected!"
		end
	end

	return tPlugin, strError
end

function SelectPlugin(strPattern, strPluginType)
	local iInterfaceIdx
	local aDetectedInterfaces
	local tPlugin
	local strPattern = strPattern or ".*"

	repeat do
		-- Detect all interfaces.
		aDetectedInterfaces = {}
		for i,v in ipairs(__MUHKUH_PLUGINS) do
			if strPluginType == nil or strPluginType == v:GetID() then
				local iDetected
				print(string.format("Detecting interfaces with plugin %s", v:GetID()))
				iDetected = v:DetectInterfaces(aDetectedInterfaces)
				print(string.format("Found %d interfaces with plugin %s", iDetected, v:GetID()))
			end
		end
		print(string.format("Found a total of %d interfaces with %d plugins", #aDetectedInterfaces, #__MUHKUH_PLUGINS))
		print("")

		-- Show all detected interfaces.
		print("Please select the interface:")
		for i,v in ipairs(aDetectedInterfaces) do
			print(string.format("%d: %s (%s) Used: %s, Valid: %s", i, v:GetName(), v:GetTyp(), tostring(v:IsUsed()), tostring(v:IsValid())))
		end
		print("R: rescan")
		print("C: cancel")

		-- Get the user input.
		repeat do
			io.write(">")
			strInterface = io.read():lower()
			iInterfaceIdx = tonumber(strInterface)
		-- Ask again until...
		--  1) the user requested a rescan ("r")
		--  2) the user canceled the selection ("c")
		--  3) the input is a number and it is an index to an entry in aDetectedInterfaces
		end until strInterface=="r" or strInterface=="c" or (iInterfaceIdx~=nil and iInterfaceIdx>0 and iInterfaceIdx<=#aDetectedInterfaces)
	-- Scan again if the user requested it.
	end until strInterface~="r"

	if strInterface~="c" then
		-- Create the plugin.
		tPlugin = aDetectedInterfaces[iInterfaceIdx]:Create()
	else
		tPlugin = nil
	end

	return tPlugin
end

function printTable(tTable, ulIndent)
    local strIndentSpace = string.rep(" ", ulIndent)
    for key, value in pairs(tTable) do
        if type(value) == "table" then
            print(strIndentSpace, key)
            printTable(value, ulIndent + 4)
        else
            print(strIndentSpace, key, " = ", value)
        end
    end
    if next(tTable) == nil then
        print(strIndentSpace, " -- empty --")
    end
end

function printArgs(tArgs, tLog)
    print("")
    print("run wfp.lua with the following args:")
    print("------------------------------------")
    printTable(tArgs, 0)
    print("")
end

local tParser = argparse('wfp', 'Flash, list and create WFP packages.'):command_target("strSubcommand")

tParser:flag "--version":description "Show version info and exit. ":action(function()
    require("flasher_version")
    print(FLASHER_VERSION_STRING)
    os.exit(0)
end)

-- Add the "flash" command and all its options.
local tParserCommandFlash = tParser:command('flash f', 'Flash the contents of the WFP.'):target('fCommandFlashSelected')
tParserCommandFlash:argument('archive', 'The WFP file to process.'):target('strWfpArchiveFile')
tParserCommandFlash:flag('-d --dry-run'):description('Dry run. Connect to a netX and read all data from the WFP, but to not alter the flash.'):default(false):target('fDryRun')
tParserCommandFlash:option('-c --condition'):description('Add a condition in the form KEY=VALUE.'):count('*'):target('astrConditions')
tParserCommandFlash:option('-v --verbose'):description(string.format('Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', '))):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandFlash:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserCommandFlash:option('-t --plugin_type'):description("plugin type"):target('strPluginType')

local tParserCommandVerify = tParser:command('verify v', 'verify the contents of the WFP.'):target('fCommandVerifySelected')
tParserCommandVerify:argument('archive', 'The WFP file to process.'):target('strWfpArchiveFile')
tParserCommandVerify:option('-c --condition'):description('Add a condition in the form KEY=VALUE.'):count('*'):target('astrConditions')
tParserCommandVerify:option('-v --verbose'):description(string.format('Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', '))):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandVerify:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserCommandVerify:option('-t --plugin_type'):description("plugin type"):target('strPluginType')


-- Add the "list" command and all its options.
local tParserCommandList = tParser:command('list l', 'List the contents of the WFP.'):target('fCommandListSelected')
tParserCommandList:argument('archive', 'The WFP file to process.'):target('strWfpArchiveFile')
tParserCommandList:option('-v --verbose'):description(string.format('Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', '))):argname('<LEVEL>'):default('debug'):target('strLogLevel')

-- Add the "pack" command and all its options.
local tParserCommandPack = tParser:command('pack p', 'Pack a WFP based on an XML.'):target('fCommandPackSelected')
tParserCommandPack:argument('xml', 'The XML control file.'):target('strWfpControlFile')
tParserCommandPack:argument('archive', 'The WFP file to create.'):target('strWfpArchiveFile')
tParserCommandPack:flag('-o --overwrite'):description('Overwrite an existing WFP archive. The default is to do nothing if the target archive already exists.'):default(false):target('fOverwrite')
tParserCommandPack:flag('-s --simple'):description('Build a SWFP file without compression.'):default(false):target('fBuildSWFP')
tParserCommandPack:option('-v --verbose'):description(string.format('Set the verbosity level to LEVEL. Possible values for LEVEL are %s.', table.concat(atLogLevels, ', '))):argname('<LEVEL>'):default('debug'):target('strLogLevel')


local tArgs = tParser:parse()


-- moved requirements here to avoid prints before argparse
require 'muhkuh_cli_init'
--require 'flasher'

local tLogWriterConsole = require 'log.writer.console'.new()
local tLogWriterFilter = require 'log.writer.filter'.new(tArgs.strLogLevel, tLogWriterConsole)
local tLogWriter = require 'log.writer.prefix'.new('[Main] ', tLogWriterFilter)
local tLog = require 'log'.new('trace',
    tLogWriter,
    require 'log.formatter.format'.new())

printArgs(tArgs, tLog)

-- Register the CLI tester.
-- tester = require 'tester_cli'(tLog)
-- tester = require 'tester_cli'
-- Ask the user to select a plugin.
tester.fInteractivePluginSelection = true

--local tFlasher = require 'flasher'(tLog)
local tFlasher = require 'flasher'


local atName2Bus = {
    ['Parflash'] = tFlasher.BUS_Parflash,
    ['Spi'] = tFlasher.BUS_Spi,
    ['IFlash'] = tFlasher.BUS_IFlash,
    ['SDIO'] = tFlasher.BUS_SDIO
}


-- Create the WFP controller.
local tWfpControl = wfp_control(tLogWriterFilter)

local fOk = true

if tArgs.fCommandFlashSelected == true or tArgs.fCommandVerifySelected then
    -- Read the control file from the WFP archive.
    tLog.debug('Using WFP archive "%s".', tArgs.strWfpArchiveFile)
    local tResult = tWfpControl:open(tArgs.strWfpArchiveFile)
    if tResult == nil then
        tLog.error('Failed to open the archive "%s"!', tArgs.strWfpArchiveFile)
        fOk = false
    else
        -- Parse the conditions.
        local atConditions = tWfpControl:getConditions()
        local atWfpConditions = {}
        for _, strCondition in ipairs(tArgs.astrConditions) do
            local strKey, strValue = string.match(strCondition, '%s*([^ =]+)%s*=%s*([^ =]+)%s*')
            if strKey == nil then
                tLog.error('Condition "%s" is invalid.', strCondition)
                fOk = false
            elseif atWfpConditions[strKey] ~= nil then
                tLog.error('Redefinition of condition "%s" from "%s" to "%s".', strKey, strValue, atWfpConditions[strKey])
                fOk = false
            else
                tLog.info('Setting condition "%s" = "%s".', strKey, strValue)
                atWfpConditions[strKey] = strValue
            end
        end
        if fOk == true then
            -- Set the default values for missing conditions.
            for _, tCondition in ipairs(atConditions) do
                local strName = tCondition.name
                local tDefault = tCondition.default
                if atWfpConditions[strName] == nil and tDefault ~= nil then
                    tLog.debug('Set condition "%s" to the default value of "%s".', strName, tostring(tDefault))
                    atWfpConditions[strName] = tDefault
                end
            end

            -- Validate all conditions.
            for _, tCondition in ipairs(atConditions) do
                local strName = tCondition.name
                local strValue = atWfpConditions[strName]
                -- Does the condition exist?
                if strValue == nil then
                    tLog.error('The condition "%s" is not set.', strName)
                    fOk = false
                else
                    -- Validate the condition.
                    local fCondOk, strError = tWfpControl:validateCondition(strName, strValue)
                    if fCondOk ~= true then
                        tLog.error('The condition "%s" is invalid: %s', strName, tostring(strError))
                        fOk = false
                    end
                end
            end
        end

        if fOk == true then
            -- Select a plugin and connect to the netX.
            local tPlugin
            if tArgs.strPluginName == nil then
                tPlugin = tester:getCommonPlugin()
            else
                local strError
                tPlugin, strError = getPlugin(tArgs.strPluginName, tArgs.strPluginType)
            end

            tPlugin:Connect()

            if not tPlugin then
                tLog.error('No plugin selected, nothing to do!')
                fOk = false
            else
                local iChiptype = tPlugin:GetChiptyp()
                print("found chip type: ", iChiptype)
                -- Does the WFP have an entry for the chip?
                local tTarget = tWfpControl:getTarget(iChiptype)
                if tTarget == nil then
                    tLog.error('The chip type %s is not supported.', tostring(iChiptype))
                    fOk = false
                else
                    -- Download the binary.
                    local aAttr = tFlasher.download(tPlugin, strFlasherPrefix)

                    -- Loop over all flashes.
                    for _, tTargetFlash in ipairs(tTarget.atFlashes) do
                        local strBusName = tTargetFlash.strBus
                        local tBus = atName2Bus[strBusName]
                        if tBus == nil then
                            tLog.error('Unknown bus "%s" found in WFP control file.', strBusName)
                            fOk = false
                            break
                        else
                            local ulUnit = tTargetFlash.ulUnit
                            local ulChipSelect = tTargetFlash.ulChipSelect
                            tLog.debug('Processing bus: %s, unit: %d, chip select: %d', strBusName, ulUnit, ulChipSelect)

                            -- Detect the device.
                            fOk = tFlasher.detect(tPlugin, aAttr, tBus, ulUnit, ulChipSelect)
                            if fOk ~= true then
                                tLog.error("Failed to detect the device!")
                                fOk = false
                                break
                            end

                            if tArgs.fCommandVerifySelected == true then
                                -- new verify function here
                                fOk = wfp_verify.verify_wfp_data(tTargetFlash, tWfpControl, atWfpConditions, tPlugin, tFlasher, aAttr, tLog)
                                tLog.log('verification: ')
                                tLog.log(fOk)
                            end
                            if tArgs.fCommandFlashSelected == true then
                                for _, tData in ipairs(tTargetFlash.atData) do
                                    -- Is this an erase command?
                                    if tData.strFile == nil then
                                        local ulOffset = tData.ulOffset
                                        local ulSize = tData.ulSize
                                        local strCondition = tData.strCondition
                                        tLog.info('Found erase 0x%08x-0x%08x and condition "%s".', ulOffset, ulOffset + ulSize, strCondition)

                                        if tWfpControl:matchCondition(atWfpConditions, strCondition) ~= true then
                                            tLog.info('Not processing erase : prevented by condition.')
                                        else
                                            if tArgs.fDryRun == true then
                                                tLog.warning('Not touching the flash as dry run is selected.')
                                            else
                                                fOk, strMsg = tFlasher.eraseArea(tPlugin, aAttr, ulOffset, ulSize)
                                                if fOk ~= true then
                                                    tLog.error('Failed to erase the area: %s', strMsg)
                                                    break
                                                end
                                            end
                                        end
                                    else
                                        local strFile = pl.path.basename(tData.strFile)
                                        local ulOffset = tData.ulOffset
                                        local strCondition = tData.strCondition
                                        tLog.info('Found file "%s" with offset 0x%08x and condition "%s".', strFile, ulOffset, strCondition)

                                        if tWfpControl:matchCondition(atWfpConditions, strCondition) ~= true then
                                            tLog.info('Not processing file %s : prevented by condition.', strFile)
                                        else
                                            -- Loading the file data from the archive.
                                            local strData = tWfpControl:getData(strFile)
                                            if strData == nil then
                                                tLog.error('Failed to get the data %s', strFile)
                                                fOk = false
                                                break
                                            else
                                                local sizData = string.len(strData)
                                                if tArgs.fDryRun == true then
                                                    tLog.warning('Not touching the flash as dry run is selected.')
                                                else
                                                    tLog.debug('Flashing %d bytes...', sizData)

                                                    fOk, strMsg = tFlasher.eraseArea(tPlugin, aAttr, ulOffset, sizData)
                                                    if fOk ~= true then
                                                        tLog.error('Failed to erase the area: %s', strMsg)
                                                        fOk = false
                                                        break
                                                    else
                                                        fOk, strMsg = tFlasher.flashArea(tPlugin, aAttr, ulOffset, strData)
                                                        if fOk ~= true then
                                                            tLog.error('Failed to flash the area: %s', strMsg)
                                                            fOk = false
                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        if fOk ~= true then
                            break
                        end
                    end
                end
            end
        end
    end
elseif tArgs.fCommandListSelected == true then
    -- Read the control file from the WFP archive.
    tLog.debug('Using WFP archive "%s".', tArgs.strWfpArchiveFile)
    local tResult = tWfpControl:open(tArgs.strWfpArchiveFile)
    if tResult == nil then
        tLog.error('Failed to open the archive "%s"!', tArgs.strWfpArchiveFile)
        fOk = false
    else
        tLog.info('WFP conditions:')
        local atConditions = tWfpControl:getConditions()
        for uiConditionIdx, tCondition in ipairs(atConditions) do
            local strTest = tCondition.test
            local tConstraints = tCondition.constraints
            local strCheck = ''
            if strTest == 're' then
                strCheck = string.format(', must match the regular expression %s', tostring(tConstraints))
            elseif strTest == 'list' then
                strCheck = string.format(', must be one of the list %s', table.concat(tConstraints, ','))
            else
                strCheck = string.format(', unknown check "%s" with constraints "%s"', strCheck, tostring(tConstraints))
            end
            tLog.info('  Condition "%s", default "%s"%s', tCondition.name, tCondition.default, strCheck)
        end
        tLog.info('')

        tLog.info('WFP contents:')
        for strTarget, tTarget in pairs(tWfpControl.atConfigurationTargets) do
            tLog.info('  "%s":', strTarget)

            -- Loop over all flashes.
            for _, tTargetFlash in ipairs(tTarget.atFlashes) do
                local strBusName = tTargetFlash.strBus
                local tBus = atName2Bus[strBusName]
                if tBus == nil then
                    tLog.error('Unknown bus "%s" found in WFP control file.', strBusName)
                    fOk = false
                    break
                else
                    local ulUnit = tTargetFlash.ulUnit
                    local ulChipSelect = tTargetFlash.ulChipSelect
                    tLog.info('    Bus: %s, unit: %d, chip select: %d', strBusName, ulUnit, ulChipSelect)
                    for _, tData in ipairs(tTargetFlash.atData) do
                        local strFile = tData.strFile
                        local strCondition = tData.strCondition
                        local strConditionPretty = ''
                        if strCondition ~= '' then
                            strConditionPretty = string.format(' with condition "%s"', strCondition)
                        end
                        local ulOffset = tData.ulOffset
                        if strFile == nil then
                            -- This seems to be an erase command.
                            local ulSize = tData.ulSize
                            tLog.info('      erase [0x%08x,0x%08x[%s', ulOffset, ulOffset + ulSize, strConditionPretty)
                        else
                            tLog.info('      write 0x%08x: "%s"%s', ulOffset, strFile, strConditionPretty)
                        end
                    end
                end
            end

            if fOk ~= true then
                break
            end
        end
    end
elseif tArgs.fCommandPackSelected == true then
    local archive = require 'archive'

    -- Does the archive already exist?
    local strWfpArchiveFile = tArgs.strWfpArchiveFile
    if pl.path.exists(strWfpArchiveFile) == strWfpArchiveFile then
        if tArgs.fOverwrite ~= true then
            tLog.error('The output archive "%s" already exists. Use "--overwrite" to force overwriting it.', strWfpArchiveFile)
            fOk = false
        else
            local tFsResult, strError = pl.file.delete(strWfpArchiveFile)
            if tFsResult == nil then
                self.tLog.error('Failed to delete the old archive "%s": %s', strArchivePath, strError)
                fOk = false
            end
        end
    end

    if fOk == true then
        local tResult = tWfpControl:openXml(tArgs.strWfpControlFile)
        if tResult == nil then
            tLog.error('Failed to read the control file "%s"!', tArgs.strWfpControlFile)
            fOk = false
        else
            -- Get the absolute directory of the control file.
            local strWorkingPath = pl.path.dirname(pl.path.abspath(tArgs.strWfpControlFile))

            -- Collect all file references from the control file.
            local atFiles = {}
            local atSortedFiles = {}
            for strTarget, tTarget in pairs(tWfpControl.atConfigurationTargets) do
                for _, tTargetFlash in ipairs(tTarget.atFlashes) do
                    local strBusName = tTargetFlash.strBus
                    local tBus = atName2Bus[strBusName]
                    if tBus == nil then
                        tLog.error('Unknown bus "%s" found in WFP control file.', strBusName)
                        fOk = false
                        break
                    else
                        for _, tData in ipairs(tTargetFlash.atData) do
                            local strFile = tData.strFile
                            -- Skip erase entries.
                            if strFile ~= nil then
                                local strFileAbs = strFile
                                if pl.path.isabs(strFileAbs) ~= true then
                                    strFileAbs = pl.path.join(strWorkingPath, strFileAbs)
                                    tLog.debug('Extending the relative path "%s" to "%s".', strFile, strFileAbs)
                                end
                                local strFileBase = pl.path.basename(strFile)
                                if atFiles[strFileBase] == nil then
                                    if pl.path.exists(strFileAbs) ~= strFileAbs then
                                        tLog.error('The path "%s" does not exist.', strFileAbs)
                                        fOk = false
                                    elseif pl.path.isfile(strFileAbs) ~= true then
                                        tLog.error('The path "%s" does not point to a file.', strFileAbs)
                                        fOk = false
                                    else
                                        tLog.debug('Adding file "%s" to the list.', strFileAbs)
                                        atFiles[strFileBase] = strFileAbs
                                        local tAttr = {
                                            ucBus = tBus,
                                            ucUnit = tTargetFlash.ulUnit,
                                            ucChipSelect = tTargetFlash.ulChipSelect,
                                            ulOffset = tData.ulOffset,
                                            strFilename = strFileAbs
                                        }
                                        table.insert(atSortedFiles, tAttr)
                                    end
                                elseif atFiles[strFileBase] ~= strFileAbs then
                                    tLog.error('Multiple files with the base name "%s" found.', strFileBase)
                                    fOk = false
                                end
                            end
                        end
                    end
                end
            end
            if fOk ~= true then
                tLog.error('Not all files are OK. Stopping here.')
            else
                if tArgs.fBuildSWFP == false then
                    -- Create a new archive.
                    local tArchive = archive.ArchiveWrite()
                    local tFormat = archive.ARCHIVE_FORMAT_TAR_GNUTAR
                    tArcResult = tArchive:set_format(tFormat)
                    if tArcResult ~= 0 then
                        tLog.error('Failed to set the archive format to ID %d: %s', tFormat, tArchive:error_string())
                        fOk = false
                    else
                        local atFilter = { archive.ARCHIVE_FILTER_XZ }
                        for _, tFilter in ipairs(atFilter) do
                            tArcResult = tArchive:add_filter(tFilter)
                            if tArcResult ~= 0 then
                                tLog.error('Failed to add filter with ID %d: %s', tFilter, tArchive:error_string())
                                fOk = false
                                break
                            end
                        end

                        local tTimeNow = os.time()
                        local strWfpArchiveFile = tArgs.strWfpArchiveFile
                        tArcResult = tArchive:open_filename(strWfpArchiveFile)
                        if tArcResult ~= 0 then
                            tLog.error('Failed to open the archive "%s": %s', strWfpArchiveFile, tArchive:error_string())
                            fOk = false
                        else
                            -- Add the control file.
                            local tEntry = archive.ArchiveEntry()
                            tEntry:set_pathname('wfp.xml')
                            local strData = pl.utils.readfile(tArgs.strWfpControlFile, true)
                            tEntry:set_size(string.len(strData))
                            tEntry:set_filetype(archive.AE_IFREG)
                            tEntry:set_perm(420)
                            tEntry:set_gname('wfp')
                            --              tEntry:set_uname('wfp')
                            tArchive:write_header(tEntry)
                            tArchive:write_data(strData)
                            tArchive:finish_entry()

                            for _, tAttr in ipairs(atSortedFiles) do
                                local tEntry = archive.ArchiveEntry()
                                tEntry:set_pathname(pl.path.basename(tAttr.strFilename))
                                local strData = pl.utils.readfile(tAttr.strFilename, true)
                                tEntry:set_size(string.len(strData))
                                tEntry:set_filetype(archive.AE_IFREG)
                                tEntry:set_perm(420)
                                tEntry:set_gname('wfp')
                                --                tEntry:set_uname('wfp')
                                tArchive:write_header(tEntry)
                                tArchive:write_data(strData)
                                tArchive:finish_entry()
                            end
                        end

                        tArchive:close()
                    end
                else
                    -- Build a SWFP.

                    -- Create the new archive.
                    local tArchive, strError = io.open(tArgs.strWfpArchiveFile, 'wb')
                    if tArchive == nil then
                        tLog.error('Failed to create the new SWFP archive "%s": %s', tArgs.strWfpArchiveFile, strError)
                        fOk = false
                    else
                        -- Write the SWFP magic.
                        tArchive:write(string.char(0x53, 0x57, 0x46, 0x50))

                        -- Loop over all files.
                        for _, tAttr in ipairs(atSortedFiles) do
                            -- Get the file data.
                            local strData = pl.utils.readfile(tAttr.strFilename, true)

                            -- Write the chunk header.
                            tArchive:write(string.char(tAttr.ucBus))
                            tArchive:write(string.char(tAttr.ucUnit))
                            tArchive:write(string.char(tAttr.ucChipSelect))
                            __writeU32(tArchive, tAttr.ulOffset)
                            __writeU32(tArchive, string.len(strData))

                            -- Write the data.
                            tArchive:write(strData)
                        end

                        tArchive:close()
                    end
                end
            end
        end
    end
end


if fOk == true then
    tLog.info('')
    tLog.info(' #######  ##    ## ')
    tLog.info('##     ## ##   ##  ')
    tLog.info('##     ## ##  ##   ')
    tLog.info('##     ## #####    ')
    tLog.info('##     ## ##  ##   ')
    tLog.info('##     ## ##   ##  ')
    tLog.info(' #######  ##    ## ')
    tLog.info('')
    tLog.info('RESULT: OK')
    os.exit(0)
else
    tLog.info('RESULT: ERROR')
    os.exit(1)
end
