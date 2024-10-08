local M = {}

local tLogWriterConsole = require 'log.writer.console'.new()
local tLogWriterFilter = require 'log.writer.filter'.new('info', tLogWriterConsole)
local tLogWriter = require 'log.writer.prefix'.new('[Main] ', tLogWriterFilter)
local tLog = require 'log'.new('trace', tLogWriter, require 'log.formatter.format'.new())
local sipper = require 'sipper'
local tSipper = sipper(tLog)
local path = require 'pl.path'


-- fOk, atResults verifySignature(tPlugin, strPluginType, astrPathList, strTempPath, strSipperExePath, strVerifySigPath)
-- Verify the signature of every usip file in the list
-- The SIPper is used for the data-block generation only
-- The verify_sig binary does not need to be signed if it is used via JTAG,
-- because the image is called directly via the tPlugin:call command.
-- Both addresses for the result and debug registers are hard coded inside the verify_sig program.
-- To change these addresses the binary needs to be build  again.
-- For every single usip in the list, a data block is generated and signature verification
-- is performed individually.
-- Every signature is checked even if one has already failed.
--
-- Returns true if every signature is correct, otherwise false
-- Also returns a list of the results for each file.
-- Each entry has the following format:
--   path: the full path to and name of the file
--   check: the type of check ("signature")
--   ok: true/false
--   message: optional a message string

function M.verifySignature(tPlugin, strPluginType, tDatalist, tPathList, strTempPath, strVerifySigPath)
    -- NOTE: For more information of how the verify_sig program works and how the data block is structured and how the
    --       result register is structured take a look at https://kb.hilscher.com/x/VpbJBw

    -- be optimistic
    local tFlasher = require 'flasher'
    local tFlasherHelper = require 'flasher_helper'
    local fOk = true
    local atResults = {}
    local ulVerifySigResult
    local ulVerifySigDebug
    local ulVerifySigDataLoadAddress = 0x00060000
    local ulVerifySigHbootLoadAddress = 0x000200c0
    local ulDataBlockLoadAddress = 0x000220c0
    local ulVerifySigResultAddress = 0x000220b8
    local ulVerifySigDebugAddress = 0x000220bc
    local ulM2MMajor = tPlugin:get_mi_version_maj()
    local ulM2MMinor = tPlugin:get_mi_version_min()

    -- get verify sig program data only
    local strVerifySigData, strMsg = tFlasherHelper.loadBin(strVerifySigPath)
    if strVerifySigData then
        -- cut out the program data from the rest of the image
        -- this is the raw program data
        -- local strVerifySigData, strMsg = tFlasherHelper.loadBin(strVerifySigPath)
        if ulM2MMajor == 3 and ulM2MMinor >= 1 then
            -- use the whole hboot image
            tFlasher.write_image(tPlugin, ulVerifySigHbootLoadAddress, strVerifySigData)
        else

            strVerifySigData = string.sub(strVerifySigData, 1037)
            tFlasher.write_image(tPlugin, ulVerifySigDataLoadAddress, strVerifySigData)
        end

        -- iterate over the path list to check the signature of every usip file
        for idx, strFileData in ipairs(tDatalist) do
            local tResult = {
                path = tPathList[idx],
                data_block = nil,
                check = "signature",
                ok = true,
                message = nil
                }

            if strFileData ~= "" then
                local strDataBlockTmpPath = nil


                if tFlasherHelper.getStoreTempFiles() then
                    -- only if fStoreTempFiles is enabled set a path to store the data_block binary in the temp folder
                    strDataBlockTmpPath = path.join(strTempPath, string.format("data_block_%s.bin", idx))
                end

                -- generate data block
                local strDataBlock, tGenDataBlockResult, strErrorMsg = tSipper:gen_data_block(
                  strFileData,
                  strDataBlockTmpPath
                )
                tResult.data_block = strDataBlock

                -- check if the command executes without an error
                if tGenDataBlockResult == true then
                    -- execute verify signature binary

                    tLog.debug("Clearing result areas ...")
                    tPlugin:write_data32(ulVerifySigResultAddress, 0x00000000)
                    tPlugin:write_data32(ulVerifySigDebugAddress, 0x00000000)

                    -- todo: why is the plugin type checked inside the loop?
                    if (
                      strPluginType == 'romloader_jtag' or
                      strPluginType == 'romloader_uart' or
                      strPluginType == 'romloader_eth'
                    ) then
                        tLog.info("Write data block into intram at offset 0x%08x", ulDataBlockLoadAddress)
                        tFlasher.write_image(tPlugin, ulDataBlockLoadAddress, strDataBlock)
                        -- tFlasherHelper.dump_intram(
                        --  tPlugin,
                        --  0x000220b0,
                        --  0x400,
                        --  strTempPath,
                        --  "dump_data_block_before.bin"
                        -- )
                        tLog.info("Start signature verification ...")
                        if ulM2MMajor == 3 and ulM2MMinor >= 1 then
                            tFlasher.call_hboot(tPlugin)
                        else
                            tPlugin:call(
                                ulVerifySigDataLoadAddress + 1,
                                ulDataBlockLoadAddress,
                                tFlasher.default_callback_message,
                                2
                            )
                        end
                        -- tFlasherHelper.dump_intram(
                        --   tPlugin,
                        --   0x000220b0,
                        --   0x400,
                        --   strTempPath,
                        --   "dump_data_block_after.bin"
                        -- )

                        ulVerifySigResult = tPlugin:read_data32(ulVerifySigResultAddress)
                        ulVerifySigDebug = tPlugin:read_data32(ulVerifySigDebugAddress)
                        tLog.debug( "ulVerifySigDebug: 0x%08x ", ulVerifySigDebug )
                        tLog.debug( "ulVerifySigResult: 0x%08x", ulVerifySigResult )
                        -- if the verify sig program runs without errors the result
                        -- register has a value of 0x00000701
                        if ulVerifySigResult == 0x701 then
                             tLog.info( "Successfully verified the signature of file: %s", tPathList[idx])
                            tResult.ok = true
                        else
                            fOk = false
                            tLog.error( "Failed to verify the signature of file: %s", tPathList[idx])
                            tResult.ok = false
                            tResult.message = "Signature verification failed."
                        end

                    else
                        -- netX90 rev_1 and ethernet detected, this function is not supported
                        tLog.error( "This Interface is not yet supported! -> %s", strPluginType )
                        fOk = false
                    end
                else
                    fOk = false
                    tLog.error( strErrorMsg )
                    -- tLog.error( "Failed to generate data_block for file: %s ", strSingleFilePath )
                    tResult.ok = false
                    tResult.message = strErrorMsg
                end
            else
                tResult.ok = false
                tResult.message = string.format("File does not exist: %s", tPathList[idx])
                fOk = false
            end



            table.insert(atResults, tResult)
        end
    else
        tLog.error(strMsg)
        tLog.error( "Could not load data from file: %s", strVerifySigPath )
        fOk = false
    end

    return fOk, atResults
end


-- Check the signatures of the helper binaries.
-- - Get the temp folder path from usip_player_conf
-- - Get the path to verify_sig
-- - Get the paths to the helper binaries
-- - Open the plugin
-- - Run the signature check
-- - Print the results

function M.verifyHelperSignatures(strPluginName, strPluginType, atPluginOptions, strSecureOption)
    tLog.info("Checking signatures of helper files...**")

    local usipPlayerConf = require 'usip_player_conf'
    local strTmpFolderPath = usipPlayerConf.tempFolderConfPath

    local strVerifySigPath = path.join(strSecureOption, "netx90", "verify_sig.bin")

    local strPath = path.join(strSecureOption, "netx90")
    local tHelperFiles = require 'helper_files'
    local tHelperFileDataList, tPathList = tHelperFiles.getAllHelperFilesData({strPath})
    local astrHelpersToCheck = tHelperFiles.getAllHelperKeys()

    local atResults

    local tResult = false
    local tFlasher = require 'flasher'
    local tFlasherHelper = require 'flasher_helper'
    local tPlugin
    local strErrorMsg
    local strDetectedHTBLType
    tPlugin, strErrorMsg = tFlasherHelper.getPlugin(strPluginName, strPluginType, atPluginOptions)

    if not tPlugin then
        tLog.error("Failed to open connection: %s", strMsg or "Unknown error")
    else

        local romloader = _G.romloader

        local strUnsignedHelperDir = path.join(tFlasher.DEFAULT_HBOOT_OPTION, "netx90")
        local aStrHelperFileDirs = path.join(strSecureOption, "netx90")


        tResult, strErrorMsg = pcall(tPlugin.Connect, tPlugin)
        if not tResult then
            tLog.error("Failed to open connection: %s", strMsg or "Unknown error")
        else
            local iChiptype = tPlugin:GetChiptyp()
            if iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90A or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90B or
            iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90C then
                if strSecureOption ~= tFlasher.DEFAULT_HBOOT_OPTION then
                    tResult, strErrorMsg, strDetectedHTBLType = M.detectRev2Signatures(
                        strUnsignedHelperDir, {aStrHelperFileDirs}, astrHelpersToCheck)
                    if tResult ~= true then
                        tLog.error(strErrorMsg)
                        os.exit(1)
                    elseif strDetectedHTBLType == "netx90_rev2" then
                        tLog.error(
                            "netX 90 rev1 chip is not compatible with the enhanced HTBL chunk used inside the helper files. (Please sign helper files for netX90 rev1 or use a netX 90 rev2 chip)"
                        )
                        os.exit(1)
                    end
                end
            end
            local strConnectedPluginType = tPlugin:GetTyp()

            tResult, atResults = M.verifySignature(
                tPlugin, strConnectedPluginType, tHelperFileDataList, tPathList, strTmpFolderPath, strVerifySigPath
            )

            tPlugin:Disconnect()

            tHelperFiles.showFileCheckResults(atResults)

            if tResult then
                tLog.info("The signatures of the helper files have been successfully verified.")
            else
                tLog.error( "The signatures of the helper files could not be verified." )
                tLog.error( "Please check if the helper files are signed correctly." )
            end
        end
        collectgarbage('collect')
    end
    return tResult, atResults
end


-- Verify if the connected netx accepts signed helper binaries.
-- astrKeys: keys of the helpers to verify.
-- strSecureOption: the directory where the helpers are located.
-- The helper_files module is used to obtain the paths to the actual files.
--
-- Returns true the signatures could be verified,
-- or false and an error message if the signatures are invalid, or
-- the signature verification has failed.
local function verifyHelperSignatures1(tPlugin, strSecureOption, astrKeys)
    local tResult
    local strErrorMsg
    local atResults
    local strSecPathNx90 = path.join(strSecureOption, "netx90")
    local tHelperFiles = require 'helper_files'
    local tFlasher = require 'flasher'
    local _, astrFileData, astrPaths = tHelperFiles.getHelperDataAndPaths({strSecPathNx90}, astrKeys)
    local strDetectedHTBLType
    if astrPaths == nil then
    tResult = false
    strErrorMsg = "Bug: some helper files are unknown"
    else
        tLog.info("Checking signatures of helper files ...**")

        local usipPlayerConf = require 'usip_player_conf'
        local tempFolderConfPath = usipPlayerConf.tempFolderConfPath

        local strVerifySigPath
        strVerifySigPath, strErrorMsg = tHelperFiles.getHelperPath(strSecPathNx90, "verify_sig")
        local astrHelpersToCheck = tHelperFiles.getAllHelperKeys()
        if strVerifySigPath == nil then
            tResult = false
            strErrorMsg = strErrorMsg or "Failed to get the path to verify_sig"
        else
            local romloader = _G.romloader

            local strUnsignedHelperDir = path.join(tFlasher.DEFAULT_HBOOT_OPTION, "netx90")
            local aStrHelperFileDirs = path.join(strSecureOption, "netx90")
            local iChiptype = tPlugin:GetChiptyp()
            if iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90A or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90B or
            iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90C then
                if strSecureOption ~= tFlasher.DEFAULT_HBOOT_OPTION then
                    tResult, strErrorMsg, strDetectedHTBLType = M.detectRev2Signatures(
                        strUnsignedHelperDir, {aStrHelperFileDirs}, astrHelpersToCheck)
                    if tResult ~= true then
                        tLog.error(strErrorMsg)
                        os.exit(1)
                    elseif strDetectedHTBLType == "netx90_rev2" then
                        tLog.error(
                            "netX 90 rev1 chip is not compatible with the enhanced HTBL chunk used inside the helper files. (Please sign helper files for netX90 rev1 or use a netX 90 rev2 chip)"
                        )
                        os.exit(1)
                    end
                end
            end
            local strPluginType = tPlugin:GetTyp()
            tResult, atResults = M.verifySignature(
                tPlugin, strPluginType, astrFileData, astrPaths, tempFolderConfPath, strVerifySigPath
            )

            tHelperFiles.showFileCheckResults(atResults)

            if tResult then
                tLog.info("The signatures of the helper files have been successfully verified.")
                --fOk = true
                strErrorMsg = "Helper file signatures OK."
            else
                tLog.error( "The signatures of the helper files could not be verified." )
                tLog.error( "Please check if the helper files are signed correctly." )
                tResult = false
                strErrorMsg = "Could not verify the signatures of the helper files."
            end
        end
    end

    return tResult, strErrorMsg
end

function M.detectRev2Signatures(strHelperDirUnsigned, aStrHelperDirSigned, astrHelpersToCheck)
    local tHelperFiles = require 'helper_files'
    -- TODO add check HTBL chunk here
    local aStrHelperDataSigned
    local aStrHelperDataUnigned
    local astrPaths
    local strErrorMsg
    local strDetectedHTBLType
    local fResult = true

    tLog.info("Verify signature type of helper images")
    for idx, strHelperDirSigned in pairs(aStrHelperDirSigned) do

        fResult, aStrHelperDataSigned, astrPaths = tHelperFiles.getHelperDataAndPaths(
            {strHelperDirSigned}, astrHelpersToCheck)
        if fResult then
            fResult, aStrHelperDataUnigned = tHelperFiles.getHelperDataAndPaths(
                {strHelperDirUnsigned}, astrHelpersToCheck)
            if fResult then
                for ulIdx = 1, #aStrHelperDataSigned do
                    strDetectedHTBLType, fResult, strErrorMsg = M.analyzeNetx90SignatureType(
                        aStrHelperDataUnigned[ulIdx], aStrHelperDataSigned[ulIdx]
                    )
                end
            end
        end
    end
    if fResult then
        tLog.info("signature type of helper images is OK")
    end
    return fResult, strErrorMsg, strDetectedHTBLType
end

function M.analyzeNetx90SignatureType(strImageUnsignedData, strImageSignedData)
    local tParsedHbootImageUnsigned
    local tParsedHbootImageSigned
    local fResult
    local strErrorMsg

    local tFirstChunkUnsigned
    local tFirstChunkSigned
    local strDetectedHTBLType

    tParsedHbootImageUnsigned, fResult, strErrorMsg = tSipper:analyze_hboot_image(strImageUnsignedData)
    if fResult then
        tParsedHbootImageSigned, fResult, strErrorMsg = tSipper:analyze_hboot_image(strImageSignedData)

        if fResult then
            -- get first chunks of each analyzed image
            -- check if the SKIP chunk of the unsigned image is the same size as the HTBL chunk of the stigned image
            tFirstChunkUnsigned = tParsedHbootImageUnsigned["atChunks"][0] or tParsedHbootImageUnsigned["atChunks"][1]
            tFirstChunkSigned = tParsedHbootImageSigned["atChunks"][0] or tParsedHbootImageSigned["atChunks"][1]
            if tFirstChunkSigned["strChunkId"] ~= "HTBL" then
                strDetectedHTBLType = "unsigned"
            elseif tFirstChunkUnsigned["ulChunkSize"] == tFirstChunkSigned["ulChunkSize"] then
                strDetectedHTBLType = "netx90_rev2"
            elseif tFirstChunkUnsigned["ulChunkSize"] > tFirstChunkSigned["ulChunkSize"] then
                strDetectedHTBLType = "netx90_rev1"
            else
                fResult = false
                strErrorMsg = "Could not compare unsigned image with signed image."
            end
        end
    end
    return strDetectedHTBLType, fResult, strErrorMsg
end

function M.verifyHelperSignatures_wrap(tPlugin, strSecureOption, astrKeys)
    local fOk = true
    local strMsg = nil
    local romloader = require 'romloader'
    local iChiptype = tPlugin:GetChiptyp()

    if (iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90B
        or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90C
        or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90D)
        and astrKeys ~= nil then

        -- start_mi only needs to be checked when romloader_uart is used.
        local strPluginType = tPlugin:GetTyp()
        local astrKeysToCheck = {}
        for i, strHelperKey in ipairs(astrKeys) do
            if strHelperKey~="start_mi" or strPluginType == "romloader_uart" then
                table.insert(astrKeysToCheck, strHelperKey)
            end
        end

        fOk, strMsg = verifyHelperSignatures1(tPlugin, strSecureOption, astrKeysToCheck)
    end

    return fOk, strMsg
end


return M
