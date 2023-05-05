
local argparse = require 'argparse'
local class = require 'pl.class'
local tFlasherHelper = require 'flasher_helper'
local mhash = require 'mhash'

local atLogLevels = {
    'debug',
    'info',
    'warning',
    'error',
    'fatal'
}

local tSignatures = {}
tSignatures[1] = {}  --ECC
tSignatures[1][1] = 64  -- 265
tSignatures[1][2] = 96  -- 384
tSignatures[1][3] = 64  -- 512
tSignatures[2] = {}  --RSA
tSignatures[2][1] = 256  -- 2048
tSignatures[2][2] = 384  -- 3072
tSignatures[2][3] = 512  -- 4096

local Sipper = class()

function Sipper:_init(tLog)
    print("initialize USIP")
    self.tLog = tLog
end

function Sipper:verify_usip(tUsipConfigData, strComSipFilePath, strAppSipFilePath)
    local tResult = true
    local strErrorMsg = ""
    local strCompareSipPath
    local strCompSip
    for iUsipChunkId = 0, tUsipConfigData['num_of_chunks'] -1 do
        local tUsipChunk = tUsipConfigData['content'][iUsipChunkId]
        -- get the target SIP of the usip chunk
        if tUsipChunk['page_type_int'] == 1 then
            strCompareSipPath = strComSipFilePath
            strCompSip = "COM"
        elseif tUsipChunk['page_type_int'] == 2 then
            strCompareSipPath = strAppSipFilePath
            strCompSip = "APP"
        else
            tResult = false
            strErrorMsg = string.format("Unknown Secure Info Page '%'",
                    tUsipChunk['page_type_int'])
        end

        self.tLog.info(string.format("Verify content of USIP inside %s-SIP Page", strCompSip))
        local tSipFile = io.open(strCompareSipPath, "rb")
        for iDataIdx=0, tUsipChunk['ulDataCount'] do
            local tData = tUsipChunk['data'][iDataIdx]
            tSipFile:seek("set", tData['offset_int'])
            local strSipData = tSipFile:read(tData['size_int'])

            if strSipData ~= tData['patched_data'] then
                tResult = false
                strErrorMsg = string.format("Data was not patched correctly to offset 0x%08x", tData['offset_int'])
                break
            end
        end
        tSipFile:close()
    end
    return tResult, strErrorMsg
end

function Sipper:compare_usip_sip(ulOffset, strUsipContent, strSipContent, ulSize)
    local tResult = true
    local strErrorMsg = ""
    for idx=0, ulSize do
        if strUsipContent[idx] ~= strSipContent[idx+ulOffset] then
            tResult = false
            strErrorMsg = string.format("Found a difference at offset %s", (idx+ulOffset))
            break
        end
    end
    return tResult, strErrorMsg
end

function Sipper:gen_data_block(strBinFilePath, strOutputBinPath)
    local strDataBlock = ""

    local tResult = true
    local strErrorMsg = ""
    local strFileType = None
    local strSkipSize
    local ulSkipSize
    local strChunkSize
    local strPageSelect
    local ulPageSelect
    local strKeyIdx
    local ulKeyIdx
    local strContentSize
    local strUUID
    local strAnchor
    local strUUIDMask
    local strAnchorMask
    local strKeyAlgorithm
    local ulKeyAlgorithm
    local strSignature
    local strDataContent
    local ulSignatureSize
    local strPaddedKey
    local strChunkHash

    local tChunkHash = mhash.mhash_state()
    tChunkHash:init(mhash.MHASH_SHA384)


    self.tLog.info("generate data block for binary: %s", strBinFilePath)
    if path.exists(strBinFilePath) then
        local tBinFileHandle = io.open(strBinFilePath, 'rb')

        if tBinFileHandle == nil then
            tResult = false
            strErrorMsg = string.format("Could not open file: %s", strBinFilePath)
        else
            -- read file type at offset 64
            tBinFileHandle:seek("set", 64)
            strFileType = tBinFileHandle:read(4)

            -- check the second expected offset for a secure chunk
            --  - if the first chunk is a skip-chunk it could be possible that this chunk used for the FHV3-Header, skip that
            -- chunk and check the next possible area for a secure chunk. The FHV3-Header-Skip chunk has always the same length!
            --  - if the FHV3-Header is already set no skip chunk is found but also no secure chunk is found, check the next area
            -- in this case.
            if strFileType == nil or strFileType == "SKIP" then
                strSkipSize = tBinFileHandle:read(4)
                ulSkipSize = tFlasherHelper.bytes_to_uint32(strSkipSize) * 4
                local newOffset = tBinFileHandle:seek() + ulSkipSize
                
                tBinFileHandle:seek("set", newOffset)
                strFileType = tBinFileHandle:read(4)

            end

            if strFileType == "SKIP" then
                tResult = false
                strErrorMsg = string.format("Found s chunk that is no security chunk. Found a SKIP Chunk, be sure the image is signed")
            elseif strFileType ~= "USIP" and strFileType ~= "HTBL" then
                tResult = false
                strErrorMsg = string.format("Found s chunk that is no security chunk. Found a %s Chunk", strFileType)
            elseif strFileType == "USIP" then

                self.tLog.info("found USIP chunk")


                -- update the hash with chunk id
                tChunkHash:hash(strFileType)

                -- update the hash with chunk size
                strChunkSize = tBinFileHandle:read(4)
                tChunkHash:hash(strChunkSize)

                -- update the hash with page select
                strPageSelect = tBinFileHandle:read(1)
                ulPageSelect = tFlasherHelper.bytes_to_uint32(strPageSelect)
                tChunkHash:hash(strPageSelect)

                -- update the hash with key idx
                strKeyIdx = tBinFileHandle:read(1)
                ulKeyIdx = tFlasherHelper.bytes_to_uint32(strKeyIdx)
                tChunkHash:hash(strKeyIdx)

                -- update the hash with content size
                strContentSize = tBinFileHandle:read(2)
                local ulContentSize = tFlasherHelper.bytes_to_uint32(strContentSize)
                ulContentSize = ulContentSize + (ulContentSize % 4) -- round up to dword
                tChunkHash:hash(strContentSize)

                if ulKeyIdx ~= 255 then
                    -- get the uuid
                    strUUID = tBinFileHandle:read(12)
                    tChunkHash:hash(strUUID)

                    -- extract all 4 anchors
                    
                    strAnchor = tBinFileHandle:read(16)
                    tChunkHash:hash(strAnchor)
                    

                    -- get the uuid mask
                    strUUIDMask = tBinFileHandle:read(12)
                    tChunkHash:hash(strUUIDMask)

                    strAnchorMask = tBinFileHandle:read(16)
                    tChunkHash:hash(strAnchorMask)

                    print("strKeyAlgorithm offset " ..tBinFileHandle:seek())
                    -- extract the key algorithm
                    strKeyAlgorithm = tBinFileHandle:read(1)
                    ulKeyAlgorithm = tFlasherHelper.bytes_to_uint32(strKeyAlgorithm)

                    print("strKeyStrength offset " ..tBinFileHandle:seek())
                    -- extract key strength
                    local strKeyStrength = tBinFileHandle:read(1)
                    local ulKeyStrength = tFlasherHelper.bytes_to_uint32(strKeyStrength)

                    tBinFileHandle:seek("set", tBinFileHandle:seek()-2)
                    print("strPaddedKey offset " ..tBinFileHandle:seek())
                    -- extract padded key
                    strPaddedKey = tBinFileHandle:read(520)
                    tChunkHash:hash(strPaddedKey)

                                        -- check if the extracted values are valid
                    if tSignatures[ulKeyAlgorithm] == nil then
                        tResult = false
                        strErrorMsg = string.format(
                                "Unknown key algorithm extracted: %s (allowed are [1, 2])", ulKeyAlgorithm
                        )
                    end
                    if tSignatures[ulKeyAlgorithm][ulKeyStrength] == nil then
                        tResult = false
                        strErrorMsg = string.format(
                                "Unknown key strength extracted: %s (allowed are [1, 2, 3])", ulKeyStrength
                        )
                    end
                    local currentOffset = tBinFileHandle:seek()
                    ulSignatureSize = tSignatures[ulKeyAlgorithm][ulKeyStrength]
                    strDataContent = tBinFileHandle:read(ulContentSize)
                    strSignature = tBinFileHandle:read(ulSignatureSize)
                    tChunkHash:hash(strDataContent)

                    while string.len(strSignature) < 512 do
                        strSignature = strSignature .. string.char(0x0)
                    end
                end
                strChunkHash = tChunkHash:hash_end()
            elseif strFileType =="HTBL" then
                self.tLog.info("found HTBL chunk")
                local ulReadSize = 0

                -- update the hash with chunk id
                tChunkHash:hash(strFileType)
                ulReadSize = ulReadSize + 4

                -- update the hash with chunk size
                strChunkSize = tBinFileHandle:read(4)
                local ulChunkSize = tFlasherHelper.bytes_to_uint32(strChunkSize) * 4
                tChunkHash:hash(strChunkSize)
                ulReadSize = ulReadSize + 4

                -- update the hash with page select
                strPageSelect = tBinFileHandle:read(1)
                ulPageSelect = tFlasherHelper.bytes_to_uint32(strPageSelect)
                tChunkHash:hash(strPageSelect)
                ulReadSize = ulReadSize + 1

                -- update the hash with key idx
                strKeyIdx = tBinFileHandle:read(1)
                ulKeyIdx = tFlasherHelper.bytes_to_uint32(strKeyIdx)
                tChunkHash:hash(strKeyIdx)
                ulReadSize = ulReadSize + 1

                local strHashTableEntries = tBinFileHandle:read(2)
                local ulHashTableEntries = tFlasherHelper.bytes_to_uint32(strHashTableEntries)
                local ulHashTableSize = ulHashTableEntries * 48
                tChunkHash:hash(strHashTableEntries)
                ulReadSize = ulReadSize + 2

                -- get the uuid
                strUUID = tBinFileHandle:read(12)
                tChunkHash:hash(strUUID)
                ulReadSize = ulReadSize + 12

                -- extract all 4 anchors
                strAnchor = tBinFileHandle:read(16)
                tChunkHash:hash(strAnchor)
                ulReadSize = ulReadSize + 16

                -- get the uuid mask
                strUUIDMask = tBinFileHandle:read(12)
                tChunkHash:hash(strUUIDMask)
                ulReadSize = ulReadSize + 12

                strAnchorMask = tBinFileHandle:read(16)
                tChunkHash:hash(strAnchorMask)
                ulReadSize = ulReadSize + 16

                local strHashTableContent = tBinFileHandle:read(ulHashTableSize)
                tChunkHash:hash(strHashTableContent)
                ulReadSize = ulReadSize + ulHashTableSize

                strChunkHash = tChunkHash:hash_end()
                
                print(tBinFileHandle:seek())
                ulSignatureSize = ulChunkSize - ulReadSize + 8 -- chunk size does not include the chunk id and the chunk size itself
                strSignature = tBinFileHandle:read(ulSignatureSize)
            end

            -- create the data block with the collected data
            if ulPageSelect == 1 and ulKeyIdx == 16 then
                strDataBlock = strDataBlock .. string.char(0x03, 0x01)
                strDataBlock = strDataBlock .. string.char(0x04, 0x00)
            elseif ulPageSelect == 1 and ulKeyIdx == 17 then
                strDataBlock = strDataBlock .. string.char(0x02, 0x01)
                strDataBlock = strDataBlock .. string.char(0x01, 0x00)
            elseif ulPageSelect == 2 and ulKeyIdx == 16 then
                strDataBlock = strDataBlock .. string.char(0x04, 0x01)
                strDataBlock = strDataBlock .. string.char(0x08, 0x00)
            elseif ulPageSelect == 2 and ulKeyIdx == 17 then
                strDataBlock = strDataBlock .. string.char(0x00, 0x01)
                strDataBlock = strDataBlock .. string.char(0x02, 0x00)
            else
                strDataBlock = strDataBlock .. string.char(0x00, 0x01)
                strDataBlock = strDataBlock .. string.char(0x00, 0x00)
            end

            strDataBlock = strDataBlock .. strChunkHash

            local strBindingData = ""
            if ulPageSelect == 1 then
                strBindingData = strBindingData .. strUUID
                print(string.len(strBindingData))
                strBindingData = strBindingData .. strAnchor
                print(string.len(strBindingData))
                strBindingData = strBindingData .. strUUIDMask
                print(string.len(strBindingData))
                strBindingData = strBindingData .. strAnchorMask
                print(string.len(strBindingData))
                strBindingData = strBindingData .. string.char(0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0)
                print(string.len(strBindingData))
                strBindingData = strBindingData .. string.char(0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                 0x0, 0x0, 0x0, 0x0)
                 print(string.len(strBindingData))
                 strBindingData = strBindingData .. string.char(0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0)
                 print(string.len(strBindingData))
                 strBindingData = strBindingData .. string.char(0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                 0x0, 0x0, 0x0, 0x0)
                 print(string.len(strBindingData))
            elseif ulPageSelect == 2 then
                strBindingData = strBindingData .. string.char(0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0)
                strBindingData = strBindingData .. string.char(0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                 0x0, 0x0, 0x0, 0x0)
                 strBindingData = strBindingData .. string.char(0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0)
                 strBindingData = strBindingData .. string.char(0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                 0x0, 0x0, 0x0, 0x0)
                 strBindingData = strBindingData .. strUUID
                 strBindingData = strBindingData .. strAnchor
                 strBindingData = strBindingData .. strUUIDMask
                 strBindingData = strBindingData .. strAnchorMask
            else
                tResult = false
                strErrorMsg = string.format("The selected secure info '%s' page is not supported", ulPageSelect)
            end
            print(string.len(strBindingData))
            strDataBlock = strDataBlock .. strBindingData
            strDataBlock = strDataBlock .. strSignature

            -- add padding to flush the intram data
            strDataBlock = strDataBlock .. string.char(0x00, 0x00, 0x00, 0x00)

            if strOutputBinPath ~= nil then
                local tOutputFileHandle = io.open(strOutputBinPath, 'wb')
                tOutputFileHandle:write(strDataBlock)
                tOutputFileHandle:close()
            end
            
            tBinFileHandle:close()
        end
    else
        tResult = false
        strErrorMsg = string.format("File does not exist: %s", strBinFilePath)
    end
    return strDataBlock, tResult, strErrorMsg
end


function main()
    local tParser = argparse('UsipGenerator', ''):command_target("strSubcommand")
    local tUsipData
    local tParserCommandAnalyze = tParser:command('gen_data_block g', ''):target('fCommandAnalyzeSelected')
    tParserCommandAnalyze:argument('input_file', 'input file'):target('strInputFilePath')
    tParserCommandAnalyze:argument('output_file', 'output file'):target('strOutputFilePath'):default(nil)
    tParserCommandAnalyze                    :option(
            '-V --verbose'
    )                                        :description(string.format('Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
            table.concat(atLogLevels, ', '))):argname('<LEVEL>'):default('debug'):target('strLogLevel')

    local tArgs = tParser:parse()

    local tLogWriterConsole = require 'log.writer.console'.new()
    local tLogWriterFilter = require 'log.writer.filter'.new(tArgs.strLogLevel, tLogWriterConsole)
    local tLogWriter = require 'log.writer.prefix'.new('[Main] ', tLogWriterFilter)
    local tLog = require 'log'.new('trace', tLogWriter, require 'log.formatter.format'.new())

    if tArgs.fCommandAnalyzeSelected == true then
        print("=== gen_data_block ===")
        sipper = Sipper(tLog)
        sipper:gen_data_block(tArgs.strInputFilePath, tArgs.strOutputFilePath)
    end
end


if pcall(debug.getlocal, 4, 1) then
    print("Library")
    -- do nothing
else
    print("Main file")
    main()
end

return Sipper