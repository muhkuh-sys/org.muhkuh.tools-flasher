module("verify_signature", package.seeall)

local tLogWriterConsole = require 'log.writer.console'.new()
local tLogWriterFilter = require 'log.writer.filter'.new('info', tLogWriterConsole)
local tLogWriter = require 'log.writer.prefix'.new('[Main] ', tLogWriterFilter)
local tLog = require 'log'.new('trace', tLogWriter, require 'log.formatter.format'.new())

local tFlasher = require 'flasher' -- write_image(), call(), call_hboot()
local tFlasherHelper = require 'flasher_helper' --loadBin(), dump_intram()
local sipper = require 'sipper'
local tSipper = sipper(tLog)

local tHelperFiles = require 'helper_files'

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

function verifySignature(tPlugin, strPluginType, astrPathList, strTempPath, strVerifySigPath)
    -- NOTE: For more information of how the verify_sig program works and how the data block is structured and how the
    --       result register is structured take a look at https://kb.hilscher.com/x/VpbJBw
    
    -- be optimistic
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

            strVerifySigData = string.sub(strVerifySigData, 1037, 0x2000)
            tFlasher.write_image(tPlugin, ulVerifySigDataLoadAddress, strVerifySigData)
        end

        -- iterate over the path list to check the signature of every usip file
        for idx, strSingleFilePath in ipairs(astrPathList) do
            local strDataBlockTmpPath = path.join(strTempPath, string.format("data_block_%s.bin", idx))
            -- generate data block
            local strDataBlock, tGenDataBlockResult, strErrorMsg = tSipper:gen_data_block(strSingleFilePath, strDataBlockTmpPath)
            local tResult = {
                path = strSingleFilePath, 
                check = "signature",
                ok = true,
                message = nil
                }
            
            -- check if the command executes without an error
            if tGenDataBlockResult == true then
                -- execute verify signature binary

                tLog.debug("Clearing result areas ...")
                tPlugin:write_data32(ulVerifySigResultAddress, 0x00000000)
                tPlugin:write_data32(ulVerifySigDebugAddress, 0x00000000)

                -- todo: why is the plugin type checked inside the loop?
                if strPluginType == 'romloader_jtag' or strPluginType == 'romloader_uart' or strPluginType == 'romloader_eth' then
                    tLog.info("Write data block into intram at offset 0x%08x", ulDataBlockLoadAddress)
                    tFlasher.write_image(tPlugin, ulDataBlockLoadAddress, strDataBlock)
                    tFlasherHelper.dump_intram(tPlugin, 0x000220b0, 0x400, strTempPath, "dump_data_block_before.bin")
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
                    tFlasherHelper.dump_intram(tPlugin, 0x000220b0, 0x400, strTempPath, "dump_data_block_after.bin")

                    ulVerifySigResult = tPlugin:read_data32(ulVerifySigResultAddress)
                    ulVerifySigDebug = tPlugin:read_data32(ulVerifySigDebugAddress)
                    tLog.debug( "ulVerifySigDebug: 0x%08x ", ulVerifySigDebug )
                    tLog.debug( "ulVerifySigResult: 0x%08x", ulVerifySigResult )
                    -- if the verify sig program runs without errors the result
                    -- register has a value of 0x00000701
                    if ulVerifySigResult == 0x701 then
                        tLog.info( "Successfully verified the signature of file: %s", strSingleFilePath )
                        tResult.ok = true
                    else
                        fOk = false
                        tLog.error( "Failed to verify the signature of file: %s", strSingleFilePath )
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
                tLog.error( "Failed to generate data_block for file: %s ", strSingleFilePath )
                tResult.ok = false
                tResult.message = strErrorMsg 
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

function verifyHelperSignatures (strPluginName, strPluginType, atPluginOptions, strSecureOption)
    tLog.info("Checking signatures of support files...**")

    local usipPlayerConf = require 'usip_player_conf'
    local tempFolderConfPath = usipPlayerConf.tempFolderConfPath
    local strTmpFolderPath = tempFolderConfPath
    
    local strVerifySigPath = path.join(strSecureOption, "netx90", "verify_sig.bin")
        
    local strPath = path.join(strSecureOption, "netx90")
    local astrSigCheckPaths = tHelperFiles.getAllHelperPaths({strPath})

    local atResults

    local fOk = false
    local tPlugin, strMsg = tFlasherHelper.getPlugin(strPluginName, strPluginType, atPluginOptions)
    if not tPlugin then
        tLog.error("Failed to open connection: %s", strMsg or "Unknown error")
    else
        fOk, strMsg = pcall(tPlugin.Connect, tPlugin)
        if not fOk then 
            tLog.error("Failed to open connection: %s", strMsg or "Unknown error")
        else 
            local strPluginType = tPlugin:GetTyp()
            
            fOk, atResults = verifySignature(
                tPlugin, strPluginType, astrSigCheckPaths, strTmpFolderPath, strVerifySigPath
            )
        
            tPlugin:Disconnect()
            
            tHelperFiles.showFileCheckResults(atResults)
            
            if fOk then
                tLog.info("The signatures of the helper files have been successfully verified.")
            else
                tLog.error( "The signatures of the helper files could not be verified." )
                tLog.error( "Please check if the helper files are signed correctly." )
            end
        end
        tPlugin = nil
    end
    return fOk, atResults
end


function verifyHelperSignatures_wrap (tPlugin, strSecureOption, astrKeys)
    local iChiptype = tPlugin:GetChiptyp()
    if (iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90B
        or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90C
        or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90D)
        and astrKeys ~= nil then
        return verifyHelperSignatures1 (tPlugin, strSecureOption, astrKeys)
    else 
        return true
    end 
end
    
-- Verify if the connected netx accepts signed helper binaries.
-- astrKeys: keys of the helpers to verify.
-- strSecureOption: the directory where the helpers are located.
-- The helper_files module is used to obtain the paths to the actual files.
--
-- Returns true the signatures could be verified,
-- or false and an error message if the signatures are invalid, or 
-- the signature verification has failed.
function verifyHelperSignatures1 (tPlugin, strSecureOption, astrKeys)
    local fOk = true
    local strMsg 
    local atResults
    local strSecPathNx90 = path.join(strSecureOption, "netx90")
    local astrPaths, astrFileData
    fOk, astrPaths, astrFileData = helper_files.getHelperDataAndPaths({strSecPathNx90}, astrKeys)
    
    if astrPaths == nil then
        fOk = false
        strMsg = "Bug: some helper files are unknown"
    else 
        tLog.info("Checking signatures of support files ...**")
    
        local usipPlayerConf = require 'usip_player_conf'
        local tempFolderConfPath = usipPlayerConf.tempFolderConfPath

        local strVerifySigPath
        strVerifySigPath, strMsg = helper_files.getHelperPath(strSecPathNx90, "verify_sig")
        if strVerifySigPath == nil then 
            fOk = false
            strMsg = strMsg or "Failed to get the path to verify_sig"
        else 
            local strPluginType = tPlugin:GetTyp()
            fOk, atResults = verifySignature(
                tPlugin, strPluginType, astrPaths, astrFileData, tempFolderConfPath, strVerifySigPath
            )
            
            tHelperFiles.showFileCheckResults(atResults)
            
            if fOk then
                tLog.info("The signatures of the helper files have been successfully verified.")
                --fOk = true
                strMsg = "Helper file signatures OK."
            else
                tLog.error( "The signatures of the helper files could not be verified." )
                tLog.error( "Please check if the helper files are signed correctly." )
                fOk = false
                strMsg = "Could not verify the signatures of the helper files."
            end
        end
    end
    
    return fOk, strMsg
end
