-- uncomment the following line to debug code (use IP of computer this is running on)
--require("LuaPanda").start("127.0.0.1",8818)

local argparse = require 'argparse'
local pl = require 'pl.import_into'()
local wfp_control = require 'wfp_control'
local wfp_verify = require 'wfp_verify'
_G.tester = require 'tester_cli'

--local tFlasher = require 'flasher'(tLog)
local tFlasher = require 'flasher'
local tFlasherHelper = require 'flasher_helper'
local tHelperFiles = require 'helper_files'

local tVerifySignature = require 'verify_signature'



atName2Bus = {
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



local WFPXml = require 'pl.class'()
function WFPXml:_init(tLog)
    -- more information about pl.xml here: https://stevedonovan.github.io/Penlight/api/libraries/pl.xml.html
    self.xml = require 'pl.xml'
    self.nodeFlasherPack = nil
    self.tTargets = {}
    self.tLog = tLog
    self.ulTestFileIdx = 0
end

function WFPXml:parse(strWfpXmlData)
    self.nodeFlasherPack = self.xml.parse(strWfpXmlData, true, true)
    -- self.tTarget = ???
    self.tTargets = self.nodeFlasherPack:get_elements_with_name("Target")
    -- local strXmlData = self.xml.tostring(self.nodeFlasherPack, "", "    ", nil, true)
    -- print(strXmlData)
end

function WFPXml:get_target(strNetX)
    for _, tTarget in ipairs(self.tTargets) do

        if strNetX == tTarget["attr"]['netx'] then
            return tTarget
        end
    end
    return nil
end

function WFPXml:new(version)
    version = version or "1.3.0"
    self.nodeFlasherPack = self.xml.new("FlasherPackage")
    self.nodeFlasherPack:set_attrib("version", version)
    self.nodeFlasherPack:set_attrib("has_subdirs", "True")
    self:addComment(
        self.nodeFlasherPack, "Automatically generated WFP control file. Not suitable for usage before modifying.")
end

function WFPXml:addTarget(strTargetName)
	local tTarget = self.xml.new("Target")
	tTarget:set_attrib("netx", strTargetName)
	self.nodeFlasherPack:add_child(tTarget)
    table.insert(self.tTargets, tTarget)
    return tTarget

end

function WFPXml:addComment(tNode, strComment)
    local tComment = self.xml.new("!-- "..strComment.." --")

    if tNode.last_add == nil then
        tNode.last_add = {}
    end
    tNode:add_child(tComment)
end

function WFPXml:removeChild(tParentNode, tChildToRemove)
    for idx, tCurrentChild in pairs(tParentNode) do
        if tCurrentChild == tChildToRemove then
            print("removing child node " .. tChildToRemove.tag)
            table.remove(tParentNode, idx)
        end
    end
end

function WFPXml:addSip(tTarget, strSipPage, strSipPath, fSetKek)
	local tSip = self.xml.new("Sip")
	tSip:set_attrib("page", strSipPage)
	tSip:set_attrib("file", strSipPath)
    if fSetKek then
        tSip:set_attrib("set_kek", "true")
    end
    if tTarget.last_add == nil then
        tTarget.last_add = {}
    end
    local tUsipTag = tTarget:child_with_name("usip")
    self:removeChild(tTarget, tUsipTag)
	tTarget:add_child(tSip)
end

function WFPXml:addFlash(tTarget, strBus, ucChipSelect, ucUnit)
	local tFlash = self.xml.new("Flash")
	tFlash:set_attrib("bus", strBus)
	tFlash:set_attrib("chip_select", ucChipSelect)
	tFlash:set_attrib("unit", ucUnit)
	tTarget:add_child(tFlash)

	local tData = self.xml.new("Data")
	tData:set_attrib("file", "test_data"..self.ulTestFileIdx..".bin")
    self.ulTestFileIdx = self.ulTestFileIdx + 1
	tData:set_attrib("size", "0x1000")
	tData:set_attrib("offset", "0x0")
	tFlash:add_child(tData)

	local tErase = self.xml.new("Erase")
	tErase:set_attrib("size", "0x1000")
	tErase:set_attrib("offset", "0x0")
	tFlash:add_child(tErase)
    return tFlash
end
function WFPXml:toString()
    local strXmlData = self.xml.tostring(self.nodeFlasherPack, "", "    ", nil, true)
    -- workaround to fix comment lines (somehow pl.xml does not provide a proper way to add comments)
    strXmlData = strXmlData:gsub("%-%-/>", "-->")
    return strXmlData
end

function WFPXml:exportXml(outputDir)
    local strErrorMsg
    local fResult

    self.tLog.info("export example XML to: " .. outputDir)
    local strXmlData = self:toString()
    fResult, strErrorMsg = pl.utils.writefile(outputDir, strXmlData)
    return fResult, strErrorMsg
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

--[[
local function show_plugin_options(tOpts)
	print("Plugin options:")
	for strPluginId, tPluginOptions in pairs(tOpts) do
		print(string.format("For %s:", strPluginId))
		for strKey, tVal in pairs(tPluginOptions) do
			print(strKey, tVal)
		end
	end
end
--]]

--[[
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
--]]


local function example_xml(tArgs, tLog, tWfpControl, bCompMode, strSecureOption, atPluginOptions)
	-- create an example xml based on the selected plugin (NXTFLASHER-264)

    tLog.info("Creating example control XML")
    local iChiptype
    local aAttr
    local aBoardInfo
    local fResult
    local strMsg
    local strErrorMsg =""

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
        local exampleXml = WFPXml(tLog)
        local tCurrentTarget

        exampleXml:new()

        iChiptype = tPlugin:GetChiptyp()
        local strTargetName = tWfpControl.atChiptyp2name[iChiptype]
        -- Download the binary. (load the flasher binary into intram)
        aAttr = tFlasher.download(tPlugin, strFlasherPrefix, nil, bCompMode, strSecureOption)
        -- get the board info
        aBoardInfo = tFlasher.getBoardInfo(tPlugin, aAttr)
        tCurrentTarget = exampleXml:addTarget(strTargetName)
        for _,tBusInfo in ipairs(aBoardInfo) do
            local ucBus = tBusInfo.iIdx
            local strBus = atBus2Name[ucBus]
            for _,tUnitInfo in ipairs(tBusInfo.aUnitInfo) do
                local ucChipSelect = 0
                local ucUnit = tUnitInfo.iIdx
                -- add only unit 2 and 3 for IFlash of netx90
                if strTargetName == "NETX90" and ucBus == 2 then
                    if ucUnit == 2 or ucUnit == 3 then
                        exampleXml:addFlash(tCurrentTarget, strBus, ucChipSelect, ucUnit)
                    end
                -- only add Unit 0 Flashes to example
                elseif ucUnit == 0 then
                    exampleXml:addFlash(tCurrentTarget, strBus, ucChipSelect, ucUnit)
                end
            end
        end

        fResult, strErrorMsg = exampleXml:exportXml(tArgs.strWfpControlFile)
    end

    return fResult, strErrorMsg
end

local function add_sip_data_to_wfp_xml(strWfpPath, strComSipBin, strAppSipBin, strNetX, strUsipFilePath, fSetKek)
    local tparsedTarget
    local wfp_xml = WFPXml()
    local strWfpData
    local strUsipBaseName

    -- parse input wfp xml
    wfp_xml:parse(strWfpPath)
    tparsedTarget = wfp_xml:get_target(strNetX)

    -- add comments to the xml
    wfp_xml:addComment(
        tparsedTarget,
         "The following binaries are automaticlly generated and are based on the default values for COM and APP SIP"
        )

    if strUsipFilePath ~= nil then
        strUsipBaseName = pl.path.basename(strUsipFilePath)
        wfp_xml:addComment(
            tparsedTarget,
             string.format("The binaries are modified based on the values from USIP file: %s", strUsipBaseName)
            )
    end

    -- add SIP chunk for each SIP to the xml
    wfp_xml:addSip(tparsedTarget, "COM", strComSipBin, fSetKek)
    wfp_xml:addSip(tparsedTarget, "APP", strAppSipBin)

    -- create new xml file content
    strWfpData = wfp_xml:toString()

    return strWfpData
end

local function prepare_usip(tLog, strUsipFilePath, fSetSipProtectionCookie)
    tLog.info("Add Secure Info Page (SIP) data to wfp archive")
    local usip_generator = require 'usip_generator'
    local tUsipGen = usip_generator(tLog)
    local fResult
    local strErrorMsg
    local tUsipConfigDict
    local strComSipData
    local strAppSipData
    local fOk = true

    fResult, strErrorMsg, tUsipConfigDict = tUsipGen:analyze_usip(strUsipFilePath)
    if not fResult then
        tLog.error('Failed to analyze usip file "%s: %s"!', strUsipFilePath, strErrorMsg)
        fOk = false
    else
        fResult, strErrorMsg, strComSipData, strAppSipData = tUsipGen:convertUsipToBin(
            tFlasherHelper.NETX90_DEFAULT_COM_SIP_BIN,
            tFlasherHelper.NETX90_DEFAULT_APP_SIP_BIN,
            tUsipConfigDict,
            fSetSipProtectionCookie
        )

        if not fResult then
            tLog.error('Failed to convert usip file "%s: %s"!', strUsipFilePath, strErrorMsg)
            fOk = false
        end
    end
    return fOk, strErrorMsg, strComSipData, strAppSipData, tUsipConfigDict
end

local function pack(strWfpArchiveFile,strWfpControlFile,tWfpControl,tLog,fOverwrite,fBuildSWFP,
      strUsipFilePath, fSetSipProtectionCookie, fSetKek)

    local archive = require 'archive'
    local fOk=true
    local strComSipData
    local strComSipBin = "COM_SIP.bin"
    local strAppSipData
    local strAppSipBin = "APP_SIP.bin"
    local tUsipConfigDict
    local strErrorMsg

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
        local strWorkingPath = pl.path.dirname(pl.path.abspath(strWfpControlFile))

        if tResult == nil then
            tLog.error('Failed to read the control file "%s"!', strWfpControlFile)
            fOk = false
        else
            if tWfpControl.tUsip ~= nil then
                local strFileBase = pl.path.basename(tWfpControl.tUsip.file)
                local strUsipPath
                if tWfpControl:getHasSubdirs() == true then
                    print("Wfp uses subdirs so we use the complete path as reference")
                    strUsipPath = tWfpControl.tUsip.file
                else
                    print("Wfp does not use subdirs so we use file name as reference")
                    strUsipPath = strFileBase
                end
                strUsipPath = pl.path.join(strWorkingPath, strUsipPath)
                -- prepare USIP data if usip element was found
                fOk, strErrorMsg, strComSipData, strAppSipData, tUsipConfigDict = prepare_usip(tLog, strUsipPath, tWfpControl.tUsip.set_sip_protection)
            end

            -- Get the absolute directory of the control file.


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

                        -- local tTimeNow = os.time()
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

                            if tWfpControl.tUsip ~= nil then
                                -- modify the input xml to add COM and APP SIP binaries
                                strData = add_sip_data_to_wfp_xml(strWfpControlFile, strComSipBin, strAppSipBin,
                                tUsipConfigDict['netx_type'], strUsipFilePath, tWfpControl.tUsip.set_kek)
                            end
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

                            if tWfpControl.tUsip ~= nil then
                                local tEntry
                                local ulCreationTime = os.time()
                                local ulModTime = os.time()
                                -- add COM SIP
                                tEntry = archive.ArchiveEntry()
                                tEntry:set_pathname(strComSipBin)

                                tEntry:set_size(string.len(strComSipData))
                                tEntry:set_filetype(archive.AE_IFREG)
                                tEntry:set_perm(420)
                                tEntry:set_gname('wfp')
                                tEntry:set_ctime(ulCreationTime, 0)
                                tEntry:set_mtime(ulModTime, 0)

                                tArchive:write_header(tEntry)
                                tArchive:write_data(strComSipData)
                                tArchive:finish_entry()

                                -- add APP SIP
                                tEntry = archive.ArchiveEntry()
                                tEntry:set_pathname(strAppSipBin)
                                tEntry:set_size(string.len(strAppSipData))
                                tEntry:set_filetype(archive.AE_IFREG)
                                tEntry:set_perm(420)
                                tEntry:set_gname('wfp')
                                tEntry:set_ctime(ulCreationTime, 0)
                                tEntry:set_mtime(ulModTime, 0)

                                tArchive:write_header(tEntry)
                                tArchive:write_data(strComSipData)
                                tArchive:finish_entry()

                            end

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

local function backup(tArgs, tLog, tWfpControl, bCompMode, strSecureOption, atPluginOptions, fUseProductionMode)
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
    local strWorkingPath = pl.path.dirname(pl.path.abspath(tArgs.strWfpControlFile))

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
        if not pl.path.exists(DestinationFolder) then
            pl.dir.makepath(DestinationFolder)
        end
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

                -- Download the binary. (load the flasher binary into intram)
                local aAttr = tFlasher.download(tPlugin, strFlasherPrefix, nil, bCompMode, strSecureOption)

                if fOk ~= true then
                    tLog.error(strMsg or "Failed to verify the signatures of the helper files")
                    fOk = false
                else
                    local iChiptype = tPlugin:GetChiptyp()
                    print("found chip type: ", iChiptype)
                    -- Does the WFP have an entry for the chip?
                    local tTarget = tWfpControl:getTarget(iChiptype)
                    local tConditions = tWfpControl:getConditions()
                    if #tConditions > 0 then
                        tLog.error("Conditions not supported for command 'read'", tostring(iChiptype))
                        fOk = false
                    elseif tTarget == nil then
                        tLog.error("The chip type %s is not supported.", tostring(iChiptype))
                        fOk = false
                    else
                        if tWfpControl.tUsip ~= nil and fUseProductionMode then
                            -- if control file contains an 'USIP' chunk and we use production mode, we add read commands for SIPs

                            local tFlash = {}
                            local tData

                            -- read command for COM SIP
                            tFlash.strBus = "IFlash"
                            tFlash.ulUnit = 1
                            tFlash.ulChipSelect = 3
                            tFlash.tRequirements = nil
                            tFlash.atData = {}

                            tData = {}
                            tData.strType = "Data"
                            tData.strFile = "com_sip.bin"
                            tData.ulSize = 0x1000
                            tData.ulOffset = 0x0
                            tData.strCondition = nil

                            table.insert(tFlash.atData, tData)
                            table.insert(tTarget.atFlashes, tFlash)

                            -- read command for APP SIP
                            tFlash = {}
                            tFlash.strBus = "IFlash"
                            tFlash.ulUnit = 2
                            tFlash.ulChipSelect = 3
                            tFlash.tRequirements = nil
                            tFlash.atData = {}

                            tData = {}
                            tData.strType = "Data"
                            tData.strFile = "app_sip.bin"
                            tData.ulSize = 0x1000
                            tData.ulOffset = 0x0
                            tData.strCondition = nil

                            table.insert(tFlash.atData, tData)
                            table.insert(tTarget.atFlashes, tFlash)

                            if tWfpControl.tUsip.read_cal then
                                -- read command for CAL SIP
                                tFlash = {}
                                tFlash.strBus = "IFlash"
                                tFlash.ulUnit = 0
                                tFlash.ulChipSelect = 1
                                tFlash.tRequirements = nil
                                tFlash.atData = {}

                                tData = {}
                                tData.strType = "Data"
                                tData.strFile = "cal_sip.bin"
                                tData.ulSize = 0x1000
                                tData.ulOffset = 0x0
                                tData.strCondition = nil

                                table.insert(tFlash.atData, tData)
                                table.insert(tTarget.atFlashes, tFlash)
                            end
                        end

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
                                    if tData.strType == "Data" or tData.strType == "Erase" then
                                        if (tData.ulSize) == nil then
                                            tLog.error("Size attribute is missing")
                                            fOk = false
                                            break
                                        end

                                        local strFile
                                        if tData.strType == "Erase" then
                                            strFile = string.format("erase-%s-u%i-c%i-s0x%08x-l0x%08x.bin",
                                            strBusName,
                                            ulUnit,
                                            ulChipSelect,
                                            tData.ulOffset,
                                            tData.ulSize
                                        )
                                        elseif tData.strType == "Data" then
                                            if tWfpControl:getHasSubdirs() == true then
                                                tLog.info("WFP archive uses subdirs.")
                                                strFile = tData.strFile
                                            else
                                                tLog.info("WFP archive does not use subdirs.")
                                                strFile = pl.path.basename(tData.strFile)
                                            end
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
                                    end
                                end
                            end
                        end

                        -- check if usip element is inside the WFP Control file
                        if tWfpControl.tUsip ~= nil and not fUseProductionMode then
                            local fResult
                            local strErrorMsg
                            local usip_player = require 'lua.usip_player_class'

                            -- if we don't use production mode, we use function read_sip of usip_player

                            local tUsipPlayer = usip_player(
                                tLog,
                                tArgs.strSecureOption,
                                tArgs.strSecureOptionPhaseTwo,
                                tArgs.strPluginName,
                                tArgs.strPluginType
                            )
                            fResult, strErrorMsg = tUsipPlayer:commandReadSip(
                                tArgs.strBackupPath, tWfpControl.tUsip.read_cal, tPlugin
                            )
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

local function isOperand(atOperands, strValue)
    for operand, _  in pairs(atOperands) do
        if  strValue == operand then return true end
    end
    return false
end

-- Validates an expression and evaluates it with the operands
--
-- Usage:
-- strExpression - contains the expression in Lua syntax as a string
--   The %-Operator is not supported
--   Parantheses are supported
--   Spaces, newline and carriage return characters are supported
--   Constants are allowed: integers, floats (use dot), hex (use 0x), strings (use \"...\")
--   Quotation marks inside of strings are not supported.
--   Examples:
--     "(A == true or B == false) and C == false"
--     "(A or not B) and not C"
--     "Text == \"(Hello World)\""
--     "Var == 0x08"
--     "Value == 1.4"
--     "A < 5 * (B - 3)"
-- astrOperands - contains the corresponding definitions of variables used in the expression
--   Dict: key = <operand name>,   value = <value of operand>
--   No spaces are allowed (except in strings)
--   The values must be passed in the string format. Text must be passed without \"
--   Numerical constants (any type) can be negative (use -)
--   The value must be a simple constant, no calculations are supported
--   Multiple definitions of the same operand are invalid
--   Examples:
--     "A": "true"
--     "Text": "Hello World"
--     "A": "-1"
-- return:
--   0: expression returns false
--   1: expression is invalid
--   2: expression returns true
local function validateAndCalculate(tLog, tWfpControl, strExpression, atOperands)
    -- Check and parse the list of the known operands and their values
    for strName, strValue in pairs(atOperands) do
        -- Operand is somehow empty: abort (causes trouble at packing)
        if strName == nil or strName == "" or strValue == nil or strValue == "" then
            tLog.error("At least one operand has empty name or no value: %s=%s", strName, strValue)
            return 1
        -- Operand is a bool-keyword
        elseif strValue == "true" or strValue == "false" then
            atOperands[strName] = strValue == "true"
        -- Operand is a number; Parse the value and save it
        elseif string.match(strValue, "^-?%d+$") or                 -- int
               string.match(strValue, "^-?%d+.?") or                -- float
               string.match(strValue, "^-?0[xX][0-9a-fA-F]+") then  -- hex
            atOperands[strName] = tonumber(strValue)
        -- Operand is nothing of the above? Must be a string
        else
            -- Abort if there are other quotation marks in the string
            -- The sandbox is somehow not able to properly evaluate strings containing
            -- quotation mark-characters (always returns "sucess, false")
            if string.find(strValue, "\"") or string.find(strValue, "\'") then
                tLog.error("Quotation Marks in operand: %s=%s", strName, strValue)
                return 1
            end
            -- Leave the value as it is (a string)
            -- Sourrounding quotation marks are omitted to ensure compatibility with old wfp.xml versions
        end
    end

    -- Prepare a copy of the expression for validity check
    -- Remove all "("" and ")" that are not part of strings
    -- Remove all spaces inside of strings in expression
    local inString = false
    local strExprForCheck = ""
    local previousCharacter = nil
    for i = 1, #strExpression do
        local character = string.sub(strExpression, i,i)

        -- \" --> string delimiter, \\\" --> quotation mark in string
        if ((character == "\"" or character == "\'") and previousCharacter ~= "\\") then
            inString = not inString
        end

        -- Outside of strings: Remove paranteses, \r and \n
        -- Inside  of strings: Remove spaces
        if (inString == false and character ~= "(" and character ~= ")"
            and character ~= "\r" and character ~= "\n") or
            (inString == true and character ~= " ") then
                strExprForCheck = strExprForCheck .. character
        end
        previousCharacter = character
    end

    -- Replace supported operators with spaces (= separators)
    -- "%" is not supported due to a problem in a printArgs function
    local validOperators = {" not ", " and ", " or ", "<=", ">=", ">", "<", "==", "~=", "%+" , "%-",
            "%*", "/", "%^"}
    -- Add space for correct " not "-substitution when not is written in the first place
    strExprForCheck = " " .. strExprForCheck
    for _, operator in ipairs(validOperators) do
        strExprForCheck = string.gsub(strExprForCheck, operator, " ");
    end

    -- Split the remaining parts of the expression at remaining spaces and check that every part is valid
    for partOfExpr in string.gmatch(strExprForCheck, "[^" .. " " .. "]+") do
        -- If in quotation marks, it must be a string
        if string.sub(partOfExpr, 1, 1) == "\"" and string.sub(partOfExpr, -1) == "\"" or
               string.sub(partOfExpr, 1, 1) == "\'" and string.sub(partOfExpr, -1) == "\'" then
            tLog.debug("%s is a string", partOfExpr)
            -- Abort if there are other quotation marks in the string (including \\\")
            -- The sandbox is somehow not able to properly evaluate strings containing
            -- quotation mark-characters (\\\") (always returns success-false)
            if string.find(string.sub(partOfExpr, 2, -2), "\"") or
               string.find(string.sub(partOfExpr, 2, -2), "\'") then
                tLog.error("%s is invalid: quotation marks in expression", partOfExpr)
                return 1
            end
        -- If one of the regex is matched, it must be a number
        elseif string.match(partOfExpr, "^-?%d+$") or          -- int
        string.match(partOfExpr, "^-?%d+.?") or                -- float
        string.match(partOfExpr, "^-?0[xX][0-9a-fA-F]+") then  -- hex
            tLog.debug("%s is a number", partOfExpr)
        -- Bool-Values
        elseif partOfExpr == "true" or partOfExpr == "false" then
            tLog.debug("%s is a boolean value", partOfExpr)
        -- Compare to the list of known operands
        elseif isOperand(atOperands, partOfExpr) then
            tLog.debug("%s is an operand", partOfExpr)
        -- Nothing of the above? --> Invalid expression
        else
            tLog.error("%s is invalid", partOfExpr)
            return 1
        end
    end

    -- Try to run the original expression in a sandbox. If it fails, the arguments are invalid (syntax etc).
    local isValid, result = pcall(wfp_control.matchCondition, tWfpControl, atOperands, strExpression)
    if isValid == false then
        tLog.error("Error: Sandbox failed")
        return 1
    end
    tLog.info("Result: %s", tostring(result))
    if result then
        return 2
    else
        return 0
    end
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
tParserCommandFlash:flag('--allow_future_version')
                   :description('Allow the WFP control xml to have a version with a minor version later than the supported version (only show warning and continue process).')
                   :target('fAllowFutureVersion')
                   :default(false)

-- Add the "verify" command and all its options.
local tParserCommandVerify = tParser:command('verify v', 'Verify the contents of the WFP.'):target(
    'fCommandVerifySelected')
tParserCommandVerify:argument('archive', 'The WFP file to process.'):target('strWfpArchiveFile')
tParserCommandVerify:option('-c --condition'):description(
    'Add a condition in the form KEY=VALUE.'):count('*'):target('astrConditions')
tParserCommandVerify:option('-V --verbose'):description(string.format(
    'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
     table.concat(atLogLevels, ', '))):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandVerify:option('-p --plugin_name'):description("plugin name"):target('strPluginName')
tParserCommandVerify:option('-t --plugin_type'):description("plugin type"):target('strPluginType')
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
tParserCommandVerify:flag('--production_mode -m')
                    :description("Use production mode. If wfp.xml control file contains 'usip' or 'SIP' elements, read data directly from flash and not perform any resets.")
                    :target('fUseProductionMode')
                    :default(false)
tParserCommandVerify:flag('--allow_future_version')
                    :description('Allow the WFP control xml to have a version with a minor version later than the supported version (only show warning and continue process).')
                    :target('fAllowFutureVersion')
                    :default(false)


-- Add the "Read" command and all its options.
local tParserCommandRead =
    tParser:command("read r",
     "Read command based on XML control file."):target("fCommandReadSelected")
tParserCommandRead:argument("xml", "The XML control file."):target("strWfpControlFile")
tParserCommandRead:argument("output_dir",
 "The destination path to create the backup."):target("strBackupPath")
tParserCommandRead:option("-a --archive",
 'Create a WFP file from the output directory.'):default(nil):target('strWfpArchiveFile')
tParserCommandRead:flag('-s --simple'):description(
    'Build a SWFP file without compression.'):default(false):target('fBuildSWFP')
tParserCommandRead:option("-V --verbose"):description(
    string.format(
        "Set the verbosity level to LEVEL. Possible values for LEVEL are %s.",
        table.concat(atLogLevels, ", ")
    )
):argname("<LEVEL>"):default("debug"):target("strLogLevel")
tParserCommandRead:option("-p --plugin_name"):description("plugin name"):target("strPluginName")
tParserCommandRead:option('-t --plugin_type'):description("plugin type"):target('strPluginType')
tParserCommandRead:flag("-o --overwrite"):description(
    "Overwrite an existing folder. The default is to do nothing if the target folder already exists."
):default(false):target("fOverwrite")
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
tParserCommandRead:flag('-m --production_mode')
                  :description("Use production mode. If wfp.xml control file contains 'usip' or 'SIP' elements, read data directly from flash and not perform any resets.")
                  :target('fUseProductionMode')
                  :default(false)

tParserCommandRead:flag('--allow_future_version')
                  :description('Allow the WFP control xml to have a version with a minor version later than the supported version (only show warning and continue process).')
                  :target('fAllowFutureVersion')
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
tParserCommandList:flag('--allow_future_version')
                  :description('Allow the WFP control xml to have a version with a minor version later than the supported version (only show warning and continue process).')
                  :target('fAllowFutureVersion')
                  :default(false)

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
tParserCommandPack:flag('--allow_future_version')
                  :description('Allow the WFP control xml to have a version with a minor version later than the supported version (only show warning and continue process).')
                  :target('fAllowFutureVersion')
                  :default(false)


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

-- Add the "check_helper_signature" command and all its options.
local tParserCommandSupportedXmlVersion = tParser:command('show_supported_version ssv',
                                                      'Show supported XML control file version.')
                                             :target('fCommandSupportedXmlVersion')
tParserCommandSupportedXmlVersion:option('-V --verbose')
                            :description(string.format(
                                'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
                             table.concat(atLogLevels, ', '))):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandSupportedXmlVersion:flag('--allow_future_version')
                             :description('Allow the WFP control xml to have a version with a minor version later than the supported version (only show warning and continue process).')
                             :target('fAllowFutureVersion')
                             :default(true):hidden(true)
-- Add the "check_helper_signature" command and all its options.
local tParserCommandXmlVersion = tParser:command('show_wfp_version swv',
                                                      'Show version of XML control file or WFP archive.')
                                             :target('fCommandXmlVersion')
tParserCommandXmlVersion:option('-V --verbose')
                            :description(string.format(
                                'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
                             table.concat(atLogLevels, ', '))):argname('<LEVEL>'):default('debug'):target('strLogLevel')
tParserCommandXmlVersion:argument('wfp', 'The XML control file or WFP archive to check.')
                             :target('strWfpPath')
tParserCommandXmlVersion:flag('--allow_future_version')
                    :description('Allow the WFP control xml to have a version with a minor version later than the supported version (only show warning and continue process).')
                    :target('fAllowFutureVersion')
                    :default(true):hidden(true)
tParserCommandXmlVersion:flag('--allow_future_major')
                    :description('Only used for this command')
                    :target('fAllowFutureMajor')
                    :default(true):hidden(true)

-- Add the "calc" command and all its options.
local tParserCommandCalculate = tParser:command('calc calculate',
                                'Verify and calculate an expression.')
                       :target('fCommandCalculateSelected')
                       :usage('Provide an expression and at least one variable definition.\n'..
                        'Example:\n'..
                        "lua5.4.exe wfp.lua calculate \"Var == 1\" \"Var=1\"\n\n"..
                        "In expression: operators must be surrounded by spaces.\n"..
                        "In operands: Do not use spaces (except in strings).\n"..
                        "Do not use spaces in string constants.\n\n"..
                        "The expression will be checked and evaluated.\n"..
                        "Exit codes:\n"..
                        "0 = false\n"..
                        "1 = error\n"..
                        "2 = true")

tParserCommandCalculate:option('-V --verbose')
                       :description(string.format(
                         'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
                         table.concat(atLogLevels, ', ')
                       ))
                       :argname('<LEVEL>')
                       :default('debug')
                       :target('strLogLevel')

tParserCommandCalculate:argument('expression', 'Expression in Lua Syntax.')
                       :target('strExpression')

tParserCommandCalculate:argument('operand', 'Value of operand')
                       :target('astrOperands')
                       :args("+") -- at least one operand

local tArgs = tParser:parse()

if tArgs.strSecureOption == nil then
	tArgs.strSecureOption = tFlasher.DEFAULT_HBOOT_OPTION
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

tFlasherHelper:printArgs(tArgs, "cli_flash.lua", tLog)
local strHelperFileStatus = tHelperFiles.getStatusString()
print(strHelperFileStatus)
print()

-- ===========================================================================================


local astrHelpersToCheck = {}

-- Define which helper fines are (potentially) required for the selected
-- command and check presence and version.
if tArgs.fCommandFlashSelected               -- flash
or tArgs.fCommandReadSelected                -- read
or tArgs.fCommandVerifySelected              -- verify
or tArgs.fCommandExampleSelected             -- example
or tArgs.fCommandCheckHelperSignatureSelected-- check_helper_signature
then
    astrHelpersToCheck = {"start_mi", "verify_sig", "flasher_netx90_hboot"}
end

local path = require 'pl.path'
local strnetX90UnsignedHelperPath = pl.path.join(tFlasher.DEFAULT_HBOOT_OPTION, "netx90")
local strnetX90HelperPath = path.join(tArgs.strSecureOption, "netx90")
tLog.info("Helper path: %s", strnetX90HelperPath)
local strnetX90M2MImageBin

if #astrHelpersToCheck == 0 then
    tLog.info ("No helper binaries required - Skipping version/signature tests.")
else
    tLog.info("Helpers to check:")
    for _, v in ipairs (astrHelpersToCheck) do
        tLog.info(v)
    end

    -- check the helper versions
    local fHelpersOk = tHelperFiles.checkHelperFiles(
        {strnetX90UnsignedHelperPath, strnetX90HelperPath},
        astrHelpersToCheck)
    if not fHelpersOk then
        tLog.info("Error during file version checks.")
        os.exit(1)
    end

    -- if any helpers are used at all, start_mi is always included.
    strnetX90M2MImageBin, strMsg = tHelperFiles.getHelperFile(strnetX90HelperPath, "start_mi")
    if strnetX90M2MImageBin == nil then
        tLog.info(strMsg or "Error: Failed to load netX 90 M2M image (unknown error)")
        os.exit(1)
    end

    -- if a signed helper directory is specified on the command line,
    -- set aArgs.astrHelpersToSigCheck, unless --disable_helper_signature_check
    -- is specified, too.
    if tArgs.strSecureOption ~= nil and
      tArgs.strSecureOption ~= tFlasher.DEFAULT_HBOOT_OPTION then
        if tArgs.fDisableHelperSignatureChecks ~= true then
            tArgs.aHelperKeysForSigCheck = astrHelpersToCheck
        else
            tLog.info("Skipping signature checks for helper files.")
        end
    end

end



-- ===========================================================================================

-- construct the option list for DetectInterfaces
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
local tWfpControl = wfp_control(tLogWriterFilter, tArgs.fAllowFutureVersion, tArgs.fAllowFutureMajor)

local fOk = true
local strErrorMsg
if tArgs.fCommandSupportedXmlVersion then
    local strSupportedVersion = tWfpControl.getSupportedVersionStr()
    tLog.info("Supported WFP version: %s", strSupportedVersion)
    tLog.info("This CLI Flasher version supports WFP control XML files up to version %s.x", strSupportedVersion)
elseif tArgs.fCommandXmlVersion then

    local strSuffix = tArgs.strWfpPath:sub(-4):lower()
    if strSuffix == ".xml" then
        fOk = tWfpControl:openXml(tArgs.strWfpPath)
    elseif strSuffix == ".wfp" or strSuffix == ".zip" then
        fOk = tWfpControl:open(tArgs.strWfpPath)
    else
        fOk = false
        tLog.error("Unknown suffix '%s' in input file '%s'", strSuffix, tArgs.strWfpPath)
    end
    if fOk then
        local strVersion = tWfpControl:getVersionStr()
        tLog.info("The input file has the WFP version %s", strVersion)
    else
        tLog.error("Could not open input file '%s'", tArgs.strWfpPath)
    end


elseif tArgs.fCommandReadSelected == true then
    local strReadXml
    fOk, strReadXml =  backup(tArgs, tLog, tWfpControl, tArgs.bCompMode, tArgs.strSecureOption, atPluginOptions, tArgs.fUseProductionMode)
    if tArgs.strWfpArchiveFile and fOk == true then
        fOk = pack(tArgs.strWfpArchiveFile, strReadXml, tWfpControl, tLog, tArgs.fOverwrite, tArgs.fBuildSWFP)
    end
elseif tArgs.fCommandExampleSelected == true then
    fOk, strErrorMsg = example_xml(tArgs, tLog, tWfpControl, tArgs.bCompMode, tArgs.strSecureOption, atPluginOptions)
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
            local strKey, strValue = string.match(strCondition, "(.*)=(.*)")
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
                            if tTarget.tSips ~= nil then
                                for _, tSip in ipairs(tTarget.tSips) do
                                    if  tArgs.fUseProductionMode then
                                        local ulUnit
                                        local ulChipSelect
                                        if tSip['page']=='COM' then
                                            -- Write the COM page. This is unit 1.
                                            ulUnit = 1
                                        else
                                            -- Write the APP page. This is unit 2.
                                            ulUnit = 2
                                            -- The calibration is always set. This is achieved with CS 3.
                                        end
                                        ulChipSelect = 3

                                        -- Create a new data entry.
                                        local atData = {
                                            {
                                            strType = "Data",
                                            strFile = tSip['file'],
                                            ulOffset = 0,
                                            strCondition = tSip['condition'],
                                            fUpdateHash = true
                                            }
                                        }

                                        -- Create a new flash entry in the current target.
                                        table.insert(tTarget.atFlashes, {
                                        strBus = 'IFlash',
                                        ulUnit = ulUnit,
                                        ulChipSelect = ulChipSelect,
                                        atData = atData
                                        })
                                    end
                                end
                            end
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
                            if  tArgs.fUseProductionMode == false and tTarget.tSips ~= nil then
                                local strComSipBinData
                                local strAppSipBinData
                                local strCalSipData
                                local strComSipData
                                local strAppSipData
                                for _, tSip in ipairs(tTarget.tSips) do
                                    if tSip.page == "COM" then
                                        strComSipBinData = tWfpControl:getData(tSip.file)
                                    elseif tSip.page == "APP" then
                                        strAppSipBinData = tWfpControl:getData(tSip.file)
                                    end
                                end
                                local usip_player = require 'lua.usip_player_class'
                                local tUsipPlayer = usip_player(
                                    tLog,
                                    tArgs.strSecureOption,
                                    nil,
                                    tArgs.strPluginName,
                                    tArgs.strPluginType
                                )

                                tResult, strErrorMsg, strCalSipData, strComSipData, strAppSipData = tUsipPlayer:commandReadSip(
                                    nil, false, tPlugin, false)
                                if tResult then
                                    local sipper = require 'sipper'
                                    local tSipper = sipper(tLog)

                                    tResult, strErrorMsg = tSipper.compare_sip_content(
                                        strComSipBinData, strComSipData, "COM")
                                    if tResult then
                                        tResult, strErrorMsg = tSipper.compare_sip_content(
                                            strAppSipBinData, strAppSipData, "APP")
                                    end
                                end
                                if not tResult then
                                    tLog.error(strErrorMsg)
                                    fOk = false
                                end

                            end
                            tLog.info('verification result: %s', tostring(fOk))
                        else
                            if tTarget.tSips ~= nil then
                                for _, tSip in ipairs(tTarget.tSips) do
                                    local ulUnit
                                    local ulChipSelect
                                    local fDouble = false
                                    if tSip['page']=='COM' then
                                        -- Write the COM page. This is unit 1.
                                        ulUnit = 1
                                        -- If the KEK should be set, the page must be patched. This is achieved with CS 3.
                                        -- If the KEK should not be set, the unmodified page should be written. This is achieved with CS 1.
                                        --
                                        -- The following expression results to 3 if "fSetKEK" is true, and 1 if it is false.
                                        ulChipSelect = tSip['set_kek'] and 3 or 1

                                        -- CS 3 handles the duplication of the SIP internally.
                                        -- CS 1 needs 2 separate entries.
                                        if ulChipSelect~=3 then
                                        fDouble = true
                                        end
                                    else
                                        -- Write the APP page. This is unit 2.
                                        ulUnit = 2
                                        -- The calibration is always set. This is achieved with CS 3.
                                        ulChipSelect = 3
                                    end

                                                -- Create a new data entry.
                                    local atData = {
                                        {
                                        strType = "Data",
                                        strFile = tSip['file'],
                                        ulOffset = 0,
                                        strCondition = tSip['condition'],
                                        fUpdateHash = true
                                        }
                                    }

                                    if fDouble then
                                    table.insert(atData, {
                                        strType = "Data",
                                        strFile = tSip['file'],
                                        ulOffset = 4096,
                                        strCondition = tSip['condition'],
                                        fUpdateHash = true
                                    })
                                    end

                                    -- Create a new flash entry in the current target.
                                    table.insert(tTarget.atFlashes, {
                                    strBus = 'IFlash',
                                    ulUnit = ulUnit,
                                    ulChipSelect = ulChipSelect,
                                    atData = atData
                                    })

                                end
                            end
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
                                        -- loop over data inside xml and check if the conditions are valid
                                        for _, tData in ipairs(tTargetFlash.atData) do
                                            if tData.strCondition ~= "" then
                                                if validateAndCalculate(tLog, tWfpControl, tData.strCondition,
                                                        atWfpConditions) == 1 then
                                                    tLog.error('Invalid Condition! Expression: %s; Operands: %s', tData.strCondition, atWfpConditions)
                                                    fOk = false
                                                    break
                                                end
                                            end
                                        end

                                        -- loop over data in xml and flash/erase
                                        if fOk == true then
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
                                                        if tData.fUpdateHash then
                                                            local usip_generator = require 'usip_generator'
                                                            local tUsipGen = usip_generator(tLog)
                                                            strData = tUsipGen.updateSipHash(strData)
                                                        end
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

elseif tArgs.fCommandPackSelected == true  then
    print("")
    fOk=pack(
        tArgs.strWfpArchiveFile,
        tArgs.strWfpControlFile,
        tWfpControl,
        tLog,tArgs.fOverwrite,
        tArgs.fBuildSWFP,
        tArgs.strUsipFilePath,
        tArgs.fSetSipProtectionCookie,
        tArgs.fSetKek
    )

elseif tArgs.fCommandCheckHelperSignatureSelected then
    tArgs.atPluginOptions = atPluginOptions
    fOk = tVerifySignature.verifyHelperSignatures(
        tArgs.strPluginName, tArgs.strPluginType, tArgs.atPluginOptions, tArgs.strSecureOption)

elseif tArgs.fCommandCalculateSelected == true then
    tLog.debug("Expression: %s", tArgs.strExpression)
    local atOperands ={}
    for _, arg in ipairs(tArgs.astrOperands) do
        operandName, operandValue = string.match(arg, "(.*)=(.*)")
        -- Throw an error if an element is passed twice
        if(atOperands[operandName] ~= nil) then
            tLog.error("Operand %s has multiple definitions", operandName)
            os.exit(1)
        end
        atOperands[operandName] = operandValue
        tLog.debug("Operands: %s", arg)
    end
    local result = validateAndCalculate(tLog, tWfpControl, tArgs.strExpression, atOperands)
    if(result == 1) then
        tLog.error("invalid expression or operands")
    end
    os.exit(result)
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
    if strErrorMsg ~= nil then
        tLog.error(strErrorMsg)
    end
    os.exit(1)
end
