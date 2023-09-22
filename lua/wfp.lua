-- uncomment the following line to debug code (use IP of computer this is running on)

local argparse = require 'argparse'
local pl = require 'pl.import_into'()
local wfp_control = require 'wfp_control'
local wfp_verify = require 'wfp_verify'

local class = require 'pl.class'
local WFPXml = class()
local xml = require 'pl.xml'

--local tFlasher = require 'flasher'(tLog)
local tFlasher = require 'flasher'
local tFlasherHelper = require 'flasher_helper'
local tHelperFiles = require 'helper_files'

local tVerifySignature = require 'verify_signature'



local atName2Bus = {
    ['Parflash'] = tFlasher.BUS_Parflash,
    ['Spi'] = tFlasher.BUS_Spi,
    ['IFlash'] = tFlasher.BUS_IFlash,
    ['SDIO'] = tFlasher.BUS_SDIO
}
local atBus2Name = {
    [tFlasher.BUS_Parflash] = 'Parflash',
    [tFlasher.BUS_Spi] = 'Spi',
    [tFlasher.BUS_IFlash] = 'IFlash',
    [tFlasher.BUS_SDIO] = 'SDIO'
}



function WFPXml:_init(version, tLog)
    -- more information about pl.xml here: https://stevedonovan.github.io/Penlight/api/libraries/pl.xml.html
    version = version or "1.3.0"
    self.tLog = tLog
    self.nodeFlasherPack = xml.new("FlasherPackage")
    self.nodeFlasherPack:set_attrib("version", version)
    self.nodeFlasherPack:set_attrib("has_subdirs", "True")
end

function WFPXml:addTarget(strTargetName)
	self.tTarget = xml.new("Target")
	self.tTarget:set_attrib("netx", strTargetName)
	self.nodeFlasherPack:add_child(self.tTarget)

end

function WFPXml:addFlash(strBus, ucChipSelect, ucUnit)
	local tFlash = xml.new("Flash")
	tFlash:set_attrib("bus", strBus)
	tFlash:set_attrib("chip_select", ucChipSelect)
	tFlash:set_attrib("unit", ucUnit)
	self.tTarget:add_child(tFlash)

	local tData = xml.new("Data")
	tData:set_attrib("file", "test_data.bin")
	tData:set_attrib("size", "0x1000")
	tData:set_attrib("offset", "0x0")
	tFlash:add_child(tData)

	local tErase = xml.new("Erase")
	tErase:set_attrib("size", "0x1000")
	tErase:set_attrib("offset", "0x0")
	tFlash:add_child(tErase)

end

function WFPXml:exportXml(outputDir)
    self.tLog.info("export example XML ", outputDir)
    local strXmlData = xml.tostring(self.nodeFlasherPack, "", "    ", nil, true)
    pl.utils.writefile(outputDir, strXmlData)
end

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
            local strNetxPath = pl.path.join(pl.path.dirname(pl.path.dirname(pl.path.abspath(strPath))), 'netx')
            if pl.path.exists(strNetxPath) ~= nil and pl.path.isdir(strNetxPath) == true then
                -- Append a directory separator at the end of the path.
                -- Otherwise the flasher will not be happy.
                strPathNetx = strNetxPath .. pl.path.sep
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

local function show_plugin_options(tOpts)
	print("Plugin options:")
	for strPluginId, tPluginOptions in pairs(tOpts) do
		print(string.format("For %s:", strPluginId))
		for strKey, tVal in pairs(tPluginOptions) do
			print(strKey, tVal)
		end
	end
end

-- strData, strMsg loadBin(strFilePath)
-- Load a binary file.
-- returns
--   data if successful
--   nil, message if an error occurred
local function loadBin(strFilePath)
	local strData
	local tFile
	local strMsg

	tFile, strMsg = io.open(strFilePath, "rb")
	if tFile then
		strData = tFile:read("*a")
		tFile:close()
		if strData == nil then
			strMsg = string.format("Could not read from file %s", strFilePath)
		end
	else
		strMsg = string.format("Could not open file %s: %s", strFilePath, strMsg or "Unknown error")
	end
	return strData, strMsg
end

local function printTable(tTable, ulIndent)
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

local function printArgs(tArgs, tLog)
    print("")
    print("run wfp.lua with the following args:")
    print("------------------------------------")
    printTable(tArgs, 0)
    print("")
end


local function example_xml(tArgs, tLog, tWfpControl, bCompMode, strSecureOption)
	-- create an example xml based on the selected plugin (NXTFLASHER-264)

    tLog.info("Creating example control XML")
    local iChiptype
    local aAttr
    local aBoardInfo
    local fResult = true
    local strMsg

    local tPlugin, strError = tFlasherHelper.getPlugin(tArgs.strPluginName, tArgs.strPluginType, atPluginOptions)

    if tPlugin then
        fResult, strError = tFlasherHelper.connect_retry(tPlugin, 5)
        if fResult == false then
            tLog.error(strError)
        end
    else
        tLog.error(strError)
        fResult = false
    end

    if fResult==true then
        -- check helper signatures
        fResult, strMsg = tVerifySignature.verifyHelperSignatures_wrap(tPlugin, tArgs.strSecureOption,
                                                                       tArgs.aHelperKeysForSigCheck)
        if fResult ~= true then
            tLog.error(strMsg or "Failed to verify the signatures of the helper files")
            fResult = false
        end
    end

    if fResult==true then
        local exampleXml = WFPXml(nil, tLog)

        iChiptype = tPlugin:GetChiptyp()
        local strTargetName = tWfpControl.atChiptyp2name[iChiptype]
        -- Download the binary. (load the flasher binary into intram)
        aAttr = tFlasher.download(tPlugin, strFlasherPrefix, nil, bCompMode, strSecureOption)
        -- get the board info
        aBoardInfo = tFlasher.getBoardInfo(tPlugin, aAttr)
        exampleXml:addTarget(strTargetName)
        for _,tBusInfo in ipairs(aBoardInfo) do
            local ucBus = tBusInfo.iIdx
            local strBus = atBus2Name[ucBus]
            for _,tUnitInfo in ipairs(tBusInfo.aUnitInfo) do
                local ucChipSelect = 0
                local ucUnit = tUnitInfo.iIdx
                -- add only unit 2 and 3 for IFlash of netx90
                if strTargetName == "NETX90" and ucBus == 2 then
                    if ucUnit == 2 or ucUnit == 3 then
                        exampleXml:addFlash(strBus, ucChipSelect, ucUnit)
                    end
                -- only add Unit 0 Flashes to example
                elseif ucUnit == 0 then
                    exampleXml:addFlash(strBus, ucChipSelect, ucUnit)
                end
            end
        end

        exampleXml:exportXml(tArgs.strWfpControlFile)
    end

    return fResult
end


local function pack(strWfpArchiveFile,strWfpControlFile,tWfpControl,tLog,fOverwrite,fBuildSWFP)

    local archive = require 'archive'
    local fOk=true

    -- Does the archive already exist?
    if pl.path.exists(strWfpArchiveFile) == strWfpArchiveFile then
        if fOverwrite ~= true then
            tLog.error(
                'The output archive "%s" already exists. Use "--overwrite" to force overwriting it.',
                strWfpArchiveFile
            )
            fOk = false
        else
            local tFsResult, strError = pl.file.delete(strWfpArchiveFile)
            if tFsResult == nil then
                tLog.error('Failed to delete the old archive "%s": %s', strWfpArchiveFile, strError)
                fOk = false
            end
        end
    end

    if fOk == true then
        local tResult = tWfpControl:openXml(strWfpControlFile)
        if tResult == nil then
            tLog.error('Failed to read the control file "%s"!', strWfpControlFile)
            fOk = false
        else
            -- Get the absolute directory of the control file.
            local strWorkingPath = pl.path.dirname(pl.path.abspath(strWfpControlFile))

            -- Collect all file references from the control file.
            local atFiles = {}
            local atSortedFiles = {}
            for _, tTarget in pairs(tWfpControl.atConfigurationTargets) do
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
                                local strCompareName
                                if tWfpControl:getHasSubdirs() == true then
									print("Wfp uses subdirs so we use the complete path as reference")
                                    strCompareName = strFile
                                else
									print("Wfp does not use subdirs so we use file name as reference")
                                    strCompareName = strFileBase
                                end
                                if atFiles[strCompareName] == nil then
                                    if pl.path.exists(strFileAbs) ~= strFileAbs then
                                        tLog.error('The path "%s" does not exist.', strFileAbs)
                                        fOk = false
                                    elseif pl.path.isfile(strFileAbs) ~= true then
                                        tLog.error('The path "%s" does not point to a file.', strFileAbs)
                                        fOk = false
                                    else
                                        tLog.debug('Adding file "%s" to the list.', strFileAbs)
                                        atFiles[strCompareName] = strFileAbs
                                        local tAttr = {
                                            ucBus = tBus,
                                            ucUnit = tTargetFlash.ulUnit,
                                            ucChipSelect = tTargetFlash.ulChipSelect,
                                            ulOffset = tData.ulOffset,
                                            strFilename = strFileAbs,
                                            strFileRelPath = tData.strFile
                                        }
                                        table.insert(atSortedFiles, tAttr)
                                    end
                                elseif atFiles[strCompareName] ~= strFileAbs then
                                    tLog.error('Multiple files with the path "%s" found.', strFileBase)
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
                if fBuildSWFP == false then
                    -- Create a new archive.
                    local tArchive = archive.ArchiveWrite()
                    local tFormat = archive.ARCHIVE_FORMAT_TAR_GNUTAR
                    local tArcResult = tArchive:set_format(tFormat)
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
                        tArcResult = tArchive:open_filename(strWfpArchiveFile)
                        if tArcResult ~= 0 then
                            tLog.error(
                                'Failed to open the archive "%s": %s',
                                strWfpArchiveFile,
                                tArchive:error_string()
                            )
                            fOk = false
                        else
                            -- Add the control file.
                            local strData = pl.utils.readfile(strWfpControlFile, true)
                            local ulCreationTime = pl.file.creation_time(strWfpControlFile)
                            local ulModTime = pl.file.modified_time(strWfpControlFile)
                            local tEntryCtrl = archive.ArchiveEntry()

                            tEntryCtrl:set_pathname('wfp.xml')
                            tEntryCtrl:set_size(string.len(strData))
                            tEntryCtrl:set_filetype(archive.AE_IFREG)
                            tEntryCtrl:set_perm(420)
                            tEntryCtrl:set_gname('wfp')
                            tEntryCtrl:set_ctime(ulCreationTime, 0)
                            tEntryCtrl:set_mtime(ulModTime, 0)

                            tArchive:write_header(tEntryCtrl)
                            tArchive:write_data(strData)
                            tArchive:finish_entry()

                            for _, tAttr in ipairs(atSortedFiles) do
                                local tEntry = archive.ArchiveEntry()
                                if tWfpControl:getHasSubdirs() == true then
                                    tLog.info('Pack WFP with subdirs.')
                                    tEntry:set_pathname(tAttr.strFileRelPath)
                                else
                                    tLog.info('Pack WFP without subdirs.')
                                    tEntry:set_pathname(pl.path.basename(tAttr.strFilename))
                                end
                                strData = pl.utils.readfile(tAttr.strFilename, true)
                                ulCreationTime = pl.file.creation_time(tAttr.strFilename)
                                ulModTime = pl.file.modified_time(tAttr.strFilename)

                                tEntry:set_size(string.len(strData))
                                tEntry:set_filetype(archive.AE_IFREG)
                                tEntry:set_perm(420)
                                tEntry:set_gname('wfp')
                                tEntry:set_ctime(ulCreationTime, 0)
                                tEntry:set_mtime(ulModTime, 0)

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
                    local tArchive, strError = io.open(strWfpArchiveFile, 'wb')
                    if tArchive == nil then
                        tLog.error('Failed to create the new SWFP archive "%s": %s', strWfpArchiveFile, strError)
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

    return fOk
end

local function backup(tArgs, tLog, tWfpControl, bCompMode, strSecureOption)
	-- create a backup for all flash areas in netX
	-- read the flash areas and save the images to reinstall them later
	-- Steps:
		-- read the control file
		-- detect the exisiting flashes
		-- read the offset and size for each area inside the flash
		-- copy the contents to different bin files
		-- copy xml file

    local ulSize
    local ulOffset
    local DestinationFolder = tArgs.strBackupPath
    local DestinationXml = DestinationFolder .. "/wfp.xml"
    local strMsg

    local fOk = true --be optimistic
	-- overwrite :
	-- check if the directory exists
	-- if the overwrite parameter is given then delete the directory otherwise throw an error
    if pl.path.exists(DestinationFolder) == DestinationFolder then
        if tArgs.fOverwrite ~= true then
            tLog.error(
                'The output directory "%s" already exists. Use "--overwrite" to force overwriting it.',
                DestinationFolder
            )
            fOk = false
        else
            local tFsResult, strError = pl.dir.rmtree(DestinationFolder)
            if tFsResult == nil then
                tLog.error('Failed to delete the output directory "%s": %s', DestinationFolder, strError)
                fOk = false
            end
        end
    end
    if fOk == true then
        pl.dir.makepath(DestinationFolder)
        tLog.info('Folder created "%s":', DestinationFolder)
        local txmlResult = tWfpControl:openXml(tArgs.strWfpControlFile)

        if txmlResult == nil then
            fOk = false
        else
            local Version = require 'Version'
            local tConfigurationVersion=tWfpControl:getVersion()   --current_version
            -- Reject the control file if the version is >= 1.3
            local tVersion_1_3 = Version()
            tVersion_1_3:set("1.3")
            -- only allow xml versions 1.3 and newer
            if Version.compare(tVersion_1_3, tConfigurationVersion) > 0 then
                tLog.error('The read command is only supported from version 1.3.0 and further')
                fOk=false
            end
        end


        if fOk == true then


           -- Select a plugin and connect to the netX.
            local tPlugin, strError = tFlasherHelper.getPlugin(
                tArgs.strPluginName,
                tArgs.strPluginType,
                atPluginOptions
            )

            if tPlugin then
                fOk, strError = tFlasherHelper.connect_retry(tPlugin, 5)
                if fOk == false then
                    tLog.error(strError)
                end
            else
                tLog.error(strError)
                fOk = false
            end

            if tPlugin then
                -- check helper signatures
                fOk, strMsg = tVerifySignature.verifyHelperSignatures_wrap(
                    tPlugin,
                    tArgs.strSecureOption,
                    tArgs.aHelperKeysForSigCheck
                )

                if fOk ~= true then
                    tLog.error(strMsg or "Failed to verify the signatures of the helper files")
                    fOk = false
                else
                    local iChiptype = tPlugin:GetChiptyp()
                    print("found chip type: ", iChiptype)
                    -- Does the WFP have an entry for the chip?
                    local tTarget = tWfpControl:getTarget(iChiptype)
                    if tTarget == nil then
                        tLog.error("The chip type %s is not supported.", tostring(iChiptype))
                        fOk = false
                    else
                        -- Download the binary. (load the flasher binary into intram)
                        local aAttr = tFlasher.download(tPlugin, strFlasherPrefix, nil, bCompMode, strSecureOption)

                        -- Loop over all flashes. (inside xml)
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
                                tLog.debug(
                                    "Processing bus: %s, unit: %d, chip select: %d",
                                    strBusName,
                                    ulUnit,
                                    ulChipSelect
                                )

                                -- Detect the device and check if the size is in 32 bit range.
                                local fDetectOk
                                --detect whether the flash i have selected exists inside the hardware
                                fDetectOk, strMsg = tFlasher.detectAndCheckSizeLimit(
                                    tPlugin,
                                    aAttr,
                                    tBus,
                                    ulUnit,
                                    ulChipSelect
                                )

                                if fDetectOk ~= true then
                                    tLog.error(strMsg)
                                    fOk = false
                                    break
                                end

                                for _, tData in ipairs(tTargetFlash.atData) do
                                    -- Is this a data area?
                                    if tData.strType == "Data" then
                                        if (tData.ulSize) == nil then
                                            tLog.error("Size attribute is missing")
                                            fOk = false
                                            break
                                        end

                                        local strFile
                                        if tWfpControl:getHasSubdirs() == true then
                                            tLog.info("WFP archive uses subdirs.")
                                            strFile = tData.strFile
                                        else
                                            tLog.info("WFP archive does not use subdirs.")
                                            strFile = pl.path.basename(tData.strFile)
                                        end
                                        ulOffset = tData.ulOffset
                                        ulSize = tData.ulSize

                                        tLog.info(
                                            'read data from area 0x%08x-0x%08x  ".',
                                            ulOffset,
                                            ulOffset + ulSize
                                        )

                                        -- continue with reading the selected area

                                        -- read
                                        local strData
                                        strData, strMsg = tFlasher.readArea(tPlugin, aAttr, ulOffset, ulSize)
                                        if strData == nil then
                                            fOk = false
                                            strMsg = strMsg or "Error while reading"
                                        else
                                            -- save the read area  to the output file (write binary)
                                            local fileName = DestinationFolder .. "/" .. strFile

                                            -- create the subdirectory inside the output folder if it does not exist
                                            local strSubFolderPath = pl.path.dirname(fileName)
                                                if not pl.path.exists(strSubFolderPath) then
                                                    pl.dir.makepath(strSubFolderPath)
                                                end

                                            pl.utils.writefile(fileName, strData, true)
                                        end
                                    elseif tData.strType == "Erase" then
                                        tLog.info("ignore Erase areas with Read function")
                                    end
                                end
                            end
                        end
                    end
                end


            end
        end
        if fOk==true then
            --copy xml_file from target to a destination
            local strDataxml = pl.utils.readfile(tArgs.strWfpControlFile, false)
            local fWriteOk = pl.utils.writefile(DestinationXml, strDataxml, false)
            if fWriteOk == true then
                tLog.info("Xml file copied")
            else
                fOk=false
            end
        end
        if fOk==false then
            local tFsResult, strError = pl.dir.rmtree(DestinationFolder)
            if tFsResult == nil then
                tLog.error('Failed to delete the output directory "%s": %s', DestinationFolder, strError)
                fOk = false
            end
        end
    end

    return fOk, DestinationXml
end


local strEpilog = [==[
Note: the command 'check_helper_signature' and the optional arguments
for secure boot mode (--sec, --comp, --disable_helper_signature_check)
are only valid for the netX 90.
]==]

local tParser = argparse('wfp', 'Flash, list and create WFP packages.'):command_target("strSubcommand")
                                                                       :epilog(strEpilog)

tParser:flag "-v --version":description "Show version info and exit. ":action(function()
    require("flasher_version")
    print(FLASHER_VERSION_STRING)
    os.exit(0)
end)

-- Add a hidden flag to disable the version checks on helper files.
tParser:flag "--disable_helper_version_check":hidden(true)
    :description "Disable version checks on helper files."
    :action(function()
        tHelperFiles.disableHelperFileChecks()
    end)

-- Add the "flash" command and all its options.
local tParserCommandFlash = tParser:command('flash f', 'Flash the contents of the WFP.')
                                   :target('fCommandFlashSelected')
tParserCommandFlash:argument('archive', 'The WFP file to process.')
                   :target('strWfpArchiveFile')
tParserCommandFlash:flag('-d --dry-run')
                   :description('Dry run. Connect to a netX and read all data from the WFP, ' ..
                                'but to not alter the flash.')
                   :default(false)
                   :target('fDryRun')
tParserCommandFlash:option('-c --condition')
                   :description('Add a condition in the form KEY=VALUE.')
                   :count('*')
                   :target('astrConditions')
tParserCommandFlash:option('-V --verbose')
                   :description(string.format(
                     'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
                     table.concat(atLogLevels, ', ')
                   ))
                   :argname('<LEVEL>')
                   :default('debug')
                   :target('strLogLevel')
tParserCommandFlash:option('-p --plugin_name')
                   :description("plugin name")
                   :target('strPluginName')
tParserCommandFlash:option('-t --plugin_type')
                   :description("plugin type")
                   :target('strPluginType')
tParserCommandFlash:mutex(
    tParserCommandFlash:flag('--comp')
                       :description("use compatibility mode for netx90 M2M interfaces")
                       :target('bCompMode')
                       :default(false),
    tParserCommandFlash:option('--sec')
                       :description("Path to signed image directory")
                       :target('strSecureOption')
                       :default(tFlasher.DEFAULT_HBOOT_OPTION)
)
tParserCommandFlash:flag('--disable_helper_signature_check')
                   :description('Disable signature checks on helper files.')
                   :target('fDisableHelperSignatureChecks')
                   :default(false)

-- Add the "verify" command and all its options.
local tParserCommandVerify = tParser:command('verify v', 'verify the contents of the WFP.')
                                    :target('fCommandVerifySelected')
tParserCommandVerify:argument('archive', 'The WFP file to process.')
                    :target('strWfpArchiveFile')
tParserCommandVerify:option('-c --condition')
                    :description('Add a condition in the form KEY=VALUE.')
                    :count('*')
                    :target('astrConditions')
tParserCommandVerify:option('-V --verbose')
                    :description(string.format(
                      'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
                      table.concat(atLogLevels, ', ')
                    ))
                    :argname('<LEVEL>')
                    :default('debug')
                    :target('strLogLevel')
tParserCommandVerify:option('-p --plugin_name')
                    :description("plugin name")
                    :target('strPluginName')
tParserCommandVerify:option('-t --plugin_type')
                    :description("plugin type")
                    :target('strPluginType')
tParserCommandVerify:mutex(
    tParserCommandVerify:flag('--comp')
                        :description("use compatibility mode for netx90 M2M interfaces")
                        :target('bCompMode')
                        :default(false),
    tParserCommandVerify:option('--sec')
                        :description("Path to signed image directory")
                        :target('strSecureOption')
                        :default(tFlasher.DEFAULT_HBOOT_OPTION)
)
tParserCommandVerify:flag('--disable_helper_signature_check')
                    :description('Disable signature checks on helper files.')
                    :target('fDisableHelperSignatureChecks')
                    :default(false)

-- Add the "Read" command and all its options.
local tParserCommandRead = tParser:command("read r",
                                           "read command based on XML control file.")
                                  :target("fCommandReadSelected")
tParserCommandRead:argument("xml", "The XML control file.")
                  :target("strWfpControlFile")
tParserCommandRead:argument("output_dir", "The destination path to create the backup.")
                  :target("strBackupPath")
tParserCommandRead:option("-a --archive", 'Create a WFP file from the output directory.')
                  :default(nil)
                  :target('strWfpArchiveFile')
tParserCommandRead:flag('-s --simple')
                  :description('Build a SWFP file without compression.')
                  :default(false)
                  :target('fBuildSWFP')
tParserCommandRead:option("-V --verbose")
                  :description(string.format(
                    "Set the verbosity level to LEVEL. Possible values for LEVEL are %s.",
                    table.concat(atLogLevels, ", ")
                  ))
                  :argname("<LEVEL>")
                  :default("debug")
                  :target("strLogLevel")
tParserCommandRead:option("-p --plugin_name")
                  :description("plugin name")
                  :target("strPluginName")
tParserCommandRead:option('-t --plugin_type')
                  :description("plugin type")
                  :target('strPluginType')
tParserCommandRead:flag("-o --overwrite")
                  :description("Overwrite an existing folder. " ..
                               "The default is to do nothing if the target folder already exists.")
                  :default(false)
                  :target("fOverwrite")
tParserCommandRead:mutex(
    tParserCommandRead:flag('--comp')
                      :description("use compatibility mode for netx90 M2M interfaces")
                      :target('bCompMode')
                      :default(false),
    tParserCommandRead:option('--sec')
                      :description("Path to signed image directory")
                      :target('strSecureOption')
                      :default(tFlasher.DEFAULT_HBOOT_OPTION)
)
tParserCommandRead:flag('--disable_helper_signature_check')
                  :description('Disable signature checks on helper files.')
                  :target('fDisableHelperSignatureChecks')
                  :default(false)

-- Add the "list" command and all its options.
local tParserCommandList = tParser:command('list l',
                                           'List the contents of the WFP.')
                                  :target('fCommandListSelected')
tParserCommandList:argument('archive', 'The WFP file to process.')
                  :target('strWfpArchiveFile')
tParserCommandList:option('-V --verbose')
                  :description(string.format(
                    'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
                    table.concat(atLogLevels, ', ')
                  ))
                  :argname('<LEVEL>')
                  :default('debug')
                  :target('strLogLevel')

-- Add the "pack" command and all its options.
local tParserCommandPack = tParser:command('pack p',
                                           'Pack a WFP based on an XML.')
                                  :target('fCommandPackSelected')
tParserCommandPack:argument('xml', 'The XML control file.')
                  :target('strWfpControlFile')
tParserCommandPack:argument('archive', 'The WFP file to create.')
                  :target('strWfpArchiveFile')
tParserCommandPack:flag('-o --overwrite')
                  :description('Overwrite an existing WFP archive. ' ..
                               'The default is to do nothing if the target archive already exists.')
                  :default(false)
                  :target('fOverwrite')
tParserCommandPack:flag('-s --simple')
                  :description('Build a SWFP file without compression.')
                  :default(false)
                  :target('fBuildSWFP')
tParserCommandPack:option('-V --verbose')
                  :description(string.format(
                    'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
                    table.concat(atLogLevels, ', ')
                  ))
                  :argname('<LEVEL>')
                  :default('debug')
                  :target('strLogLevel')

-- Add the "example" command and all its options.
local tParserCommandExample = tParser:command('example e',
                                              'Create example XML for connected netX.')
                                     :target('fCommandExampleSelected')
tParserCommandExample:argument('xml', 'Output example XML control file.')
                     :target('strWfpControlFile')
tParserCommandExample:option("-p --plugin_name")
                     :description("plugin name")
                     :target("strPluginName")
tParserCommandExample:option('-t --plugin_type')
                     :description("plugin type")
                     :target('strPluginType')
tParserCommandExample:option('-V --verbose')
                     :description(string.format(
                       'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
                       table.concat(atLogLevels, ', ')
                     ))
                     :argname('<LEVEL>')
                     :default('debug')
                     :target('strLogLevel')
tParserCommandExample:mutex(
    tParserCommandExample:flag('--comp')
                         :description("use compatibility mode for netx90 M2M interfaces")
                         :target('bCompMode')
                         :default(false),
    tParserCommandExample:option('--sec')
                         :description("Path to signed image directory")
                         :target('strSecureOption')
                         :default(tFlasher.DEFAULT_HBOOT_OPTION)
)
tParserCommandExample:flag('--disable_helper_signature_check')
                     :description('Disable signature checks on helper files.')
                     :target('fDisableHelperSignatureChecks')
                     :default(false)


-- Add the "check_helper_signature" command and all its options.
local tParserCommandVerifyHelperSig = tParser:command('check_helper_signature chs',
                                                      'Verify the signatures of the helper files.')
                                             :target('fCommandCheckHelperSignatureSelected')
tParserCommandVerifyHelperSig:option('-V --verbose')
                             :description(string.format(
                               'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
                               table.concat(atLogLevels, ', '
                             ))
):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandVerifyHelperSig:option('-p --plugin_name')
                             :description("plugin name")
                            :target('strPluginName')
tParserCommandVerifyHelperSig:option('-t --plugin_type')
                             :description("plugin type")
                             :target("strPluginType")
tParserCommandVerifyHelperSig:option('--sec')
                             :description("Path to signed image directory")
                             :target('strSecureOption')
                             :default(tFlasher.DEFAULT_HBOOT_OPTION)

local tArgs = tParser:parse()

if tArgs.strSecureOption == nil then
	tArgs.strSecureOption = tFlasher.DEFAULT_HBOOT_OPTION
end

-- If a signed helper directory was specified (--sec)
-- and it is not the default (unsigned) directory,
-- and the flag --disable_helper_signature_check was not specified,
-- and the command is one that connects to the netx and uses the flasher,
-- set a list of helper files to be checked later after connecting.
if tArgs.strSecureOption ~= nil
and tArgs.strSecureOption ~= tFlasher.DEFAULT_HBOOT_OPTION
and tArgs.fDisableHelperSignatureChecks ~= true then
    if tArgs.fCommandFlashSelected               -- flash
    or tArgs.fCommandReadSelected                -- read
    or tArgs.fCommandVerifySelected              -- verify
    or tArgs.fCommandExampleSelected             -- example
    then
        tArgs.aHelperKeysForSigCheck = {"start_mi", "flasher_netx90_hboot"}
    end
end

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
local strHelperFileStatus = tHelperFiles.getStatusString()
print(strHelperFileStatus)
print()

-- Register the CLI tester.
-- tester = require 'tester_cli'(tLog)
-- tester = require 'tester_cli'
-- Ask the user to select a plugin.
tester.fInteractivePluginSelection = true

local strnetX90M2MImagePath = path.join(tArgs.strSecureOption, "netx90")

tLog.info("Trying to load netX 90 M2M image from %s", strnetX90M2MImagePath)

local strnetX90M2MImageBin, strMsg = tHelperFiles.getHelperFile(strnetX90M2MImagePath, "start_mi")
if strnetX90M2MImageBin == nil then
    tLog.info(strMsg or "Error: Failed to load netX 90 M2M image (unknown error)")
    -- tLog.info("Error: Failed to load netX 90 M2M image: %s", strMsg or "unknown error")
    os.exit(1)
end

local atPluginOptions = {
    romloader_jtag = {
    jtag_reset = "Attach", -- HardReset, SoftReset or Attach
    jtag_frequency_khz = 6000 -- optional
    },
    romloader_uart = {
    netx90_m2m_image = strnetX90M2MImageBin
    }
}

-- Create the WFP controller.
local tWfpControl = wfp_control(tLogWriterFilter)

local fOk = true
if tArgs.fCommandReadSelected == true then
    local strReadXml
    fOk, strReadXml =  backup(tArgs, tLog, tWfpControl, tArgs.bCompMode, tArgs.strSecureOption)
    if tArgs.strWfpArchiveFile and fOk == true then
        fOk = pack(tArgs.strWfpArchiveFile, strReadXml, tWfpControl, tLog, tArgs.fOverwrite, tArgs.fBuildSWFP)
    end
elseif tArgs.fCommandExampleSelected == true then
    print("EXAMPLE")
    fOk = example_xml(tArgs, tLog, tWfpControl, tArgs.bCompMode, tArgs.strSecureOption)
elseif tArgs.fCommandFlashSelected == true or tArgs.fCommandVerifySelected then
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
                tLog.error(
                    'Redefinition of condition "%s" from "%s" to "%s".',
                    strKey,
                    strValue,
                    atWfpConditions[strKey]
                )
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
            local tPlugin, strError = tFlasherHelper.getPlugin(
                tArgs.strPluginName,
                tArgs.strPluginType,
                atPluginOptions
            )

            if tPlugin then
                fOk, strError = tFlasherHelper.connect_retry(tPlugin, 5)
                if fOk == false then
                    tLog.error(strError)
                end
            end

            if not tPlugin then
                tLog.error('No plugin selected, nothing to do!')
                fOk = false
            else

                -- check helper signatures
                fOk, strMsg = tVerifySignature.verifyHelperSignatures_wrap(
                    tPlugin,
                    tArgs.strSecureOption,
                    tArgs.aHelperKeysForSigCheck
                )

                if fOk ~= true then
                    tLog.error(strMsg or "Failed to verify the signatures of the helper files")
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
                        local aAttr = tFlasher.download(tPlugin, strFlasherPrefix, nil,
                                                        tArgs.bCompMode, tArgs.strSecureOption)

                        -- Verify command now moved above Target Flash Loop to collect data for each flash before
                        -- running verification
                        if tArgs.fCommandVerifySelected == true then
                            -- new verify function here
                            fOk = wfp_verify.verifyWFP(
                                tTarget,
                                tWfpControl,
                                iChiptype,
                                atWfpConditions,
                                tPlugin,
                                tFlasher,
                                aAttr,
                                tLog
                            )
                            tLog.info('verification result: %s', tostring(fOk))
                        else

                            -- Loop over all flashes. (inside xml)
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
                                    tLog.debug(
                                        'Processing bus: %s, unit: %d, chip select: %d',
                                        strBusName,
                                        ulUnit,
                                        ulChipSelect
                                    )

                                    -- Detect the device and check if the size is in 32 bit range.
                                    local fDetectOk
                                    fDetectOk, strMsg = tFlasher.detectAndCheckSizeLimit(
                                        tPlugin,
                                        aAttr,
                                        tBus,
                                        ulUnit,
                                        ulChipSelect
                                    )
                                    if fDetectOk ~= true then
                                        tLog.error(strMsg)
                                        fOk = false
                                        break
                                    end

                                    if tArgs.fCommandFlashSelected == true then
                                        -- loop over data inside xml
                                        for _, tData in ipairs(tTargetFlash.atData) do
                                            -- Is this an erase command?
                                            if tData.strFile == nil then
                                                local ulOffset = tData.ulOffset
                                                local ulSize = tData.ulSize
                                                local strCondition = tData.strCondition
                                                tLog.info(
                                                    'Found erase 0x%08x-0x%08x and condition "%s".',
                                                    ulOffset,
                                                    ulOffset + ulSize,
                                                    strCondition
                                                )

                                                if tWfpControl:matchCondition(atWfpConditions, strCondition)~=true then
                                                    tLog.info('Not processing erase : prevented by condition.')
                                                else
                                                    if tArgs.fDryRun == true then
                                                        tLog.warning('Not touching the flash as dry run is selected.')
                                                    else
                                                        fOk, strMsg = tFlasher.eraseArea(
                                                            tPlugin,
                                                            aAttr,
                                                            ulOffset,
                                                            ulSize
                                                        )
                                                        if fOk ~= true then
                                                            tLog.error('Failed to erase the area: %s', strMsg)
                                                            break
                                                        end
                                                    end
                                                end
                                            else
                                                local strFile
                                                if tWfpControl:getHasSubdirs() == true then
                                                    tLog.info('WFP archive uses subdirs.')
                                                    strFile = tData.strFile
                                                else
                                                    tLog.info('WFP archive does not use subdirs.')
                                                    strFile = pl.path.basename(tData.strFile)
                                                end

                                                local ulOffset = tData.ulOffset
                                                local strCondition = tData.strCondition
                                                tLog.info(
                                                    'Found file "%s" with offset 0x%08x and condition "%s".',
                                                    strFile,
                                                    ulOffset,
                                                    strCondition
                                                )

                                                if tWfpControl:matchCondition(atWfpConditions, strCondition)~=true then
                                                    tLog.info(
                                                        'Not processing file %s : prevented by condition.',
                                                        strFile
                                                    )
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
                                                            tLog.warning(
                                                                'Not touching the flash as dry run is selected.'
                                                            )
                                                        else
                                                            tLog.debug('Flashing %d bytes...', sizData)

                                                            fOk, strMsg = tFlasher.eraseArea(
                                                                tPlugin,
                                                                aAttr,
                                                                ulOffset,
                                                                sizData
                                                            )
                                                            if fOk ~= true then
                                                                tLog.error('Failed to erase the area: %s', strMsg)
                                                                fOk = false
                                                                break
                                                            else
                                                                fOk, strMsg = tFlasher.flashArea(
                                                                    tPlugin,
                                                                    aAttr,
                                                                    ulOffset,
                                                                    strData
                                                                )
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
        for _, tCondition in ipairs(atConditions) do
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
    fOk=pack(tArgs.strWfpArchiveFile,tArgs.strWfpControlFile,tWfpControl,tLog,tArgs.fOverwrite,tArgs.fBuildSWFP)

elseif tArgs.fCommandCheckHelperSignatureSelected then
    tArgs.atPluginOptions = atPluginOptions
    fOk = tVerifySignature.verifyHelperSignatures(
        tArgs.strPluginName, tArgs.strPluginType, tArgs.atPluginOptions, tArgs.strSecureOption)
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
