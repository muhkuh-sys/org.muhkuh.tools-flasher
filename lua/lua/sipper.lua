
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
    print("initialize Sipper")
    self.tLog = tLog

    self.VERIFY_RESULT_OK = 0
    self.VERIFY_RESULT_ERROR = 1
    self.VERIFY_RESULT_FALSE = 2
end

function Sipper:verify_usip(tUsipConfigData, strComSipData, strAppSipData)
    -- verify the configuration data extracted from an usip file with the content of the COM and APP SIP
    -- return values:
    --  0: (RESULT_VERIFY_OK) data verified
    --  1: (RESULT_VERIFY_ERROR) error while verifying
    --  2: (VERIFY_RESULT_FALSE) verification failed


    local uResult = self.VERIFY_RESULT_OK
    local strErrorMsg = ""
    local strCompareSipData
    local strCompSip
    for iUsipChunkId = 0, tUsipConfigData['num_of_chunks'] -1 do
        local tUsipChunk = tUsipConfigData['content'][iUsipChunkId]
        -- get the target SIP of the usip chunk
        if tUsipChunk['page_type_int'] == 1 then
            strCompareSipData = strComSipData
            strCompSip = "COM"
        elseif tUsipChunk['page_type_int'] == 2 then
            strCompareSipData = strAppSipData
            strCompSip = "APP"
        else
            uResult = self.VERIFY_RESULT_ERROR
            strErrorMsg = string.format("Unknown Secure Info Page '%'",
                    tUsipChunk['page_type_int'])
            break
        end

        self.tLog.info(string.format("Verify content of USIP inside %s-SIP Page", strCompSip))

        local tSipDataHandle = tFlasherHelper.StringHandle(strCompareSipData)
        for iDataIdx=0, tUsipChunk['ulDataCount'] do
            local tData = tUsipChunk['data'][iDataIdx]
            tSipDataHandle:seek("set", tData['offset_int'])
            local strSipData = tSipDataHandle:read(tData['size_int'])

            if strSipData ~= tData['patched_data'] then
                uResult = self.VERIFY_RESULT_FALSE
                strErrorMsg = string.format(
                    "Data was not patched correctly on %s SIP to offset 0x%08x",
                    strCompSip,
                    tData['offset_int']
                )
                break
            end
        end
    end
    return uResult, strErrorMsg
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

function Sipper:gen_data_block(strFileData, strOutputBinPath)
    local strDataBlock = ""

    local tResult = true
    local strErrorMsg = ""
    local strChunkID = nil
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

    if strFileData == nil then
        tResult = false
        strErrorMsg = string.format("No data received")
    else
        local tBinStringHandle = tFlasherHelper.StringHandle(strFileData)
        -- read file type at offset 64
        tBinStringHandle:seek("set", 64)
        strChunkID = tBinStringHandle:read(4)

        -- check the second expected offset for a secure chunk
        --  - if the first chunk is a skip-chunk it could be possible that this chunk used for the FHV3-Header,
        --    skip that chunk and check the next possible area for a secure chunk. The FHV3-Header-Skip chunk has
        --    always the same length!
        --  - if the FHV3-Header is already set no skip chunk is found but also no secure chunk is found, check the
        --    next area in this case.
        if strChunkID == nil or strChunkID == "SKIP" then
            strSkipSize = tBinStringHandle:read(4)
            ulSkipSize = tFlasherHelper.bytes_to_uint32(strSkipSize) * 4
            local newOffset = tBinStringHandle:seek() + ulSkipSize

            tBinStringHandle:seek("set", newOffset)
            strChunkID = tBinStringHandle:read(4)

        end

        if strChunkID == "SKIP" then
            tResult = false
            strErrorMsg = string.format("Found SKIP chunk, which is no security chunk. Make sure the image is signed.")
        elseif strChunkID ~= "USIP" and strChunkID ~= "HTBL" then
            tResult = false
           strErrorMsg = string.format("Found a %s chunk, which is no security chunk.", strChunkID)
        elseif strChunkID == "USIP" then

            self.tLog.info("found USIP chunk")


            -- update the hash with chunk id
            tChunkHash:hash(strChunkID)

            -- update the hash with chunk size
            strChunkSize = tBinStringHandle:read(4)
            tChunkHash:hash(strChunkSize)

            -- update the hash with page select
            strPageSelect = tBinStringHandle:read(1)
            ulPageSelect = tFlasherHelper.bytes_to_uint32(strPageSelect)
            tChunkHash:hash(strPageSelect)

            -- update the hash with key idx
            strKeyIdx = tBinStringHandle:read(1)
            ulKeyIdx = tFlasherHelper.bytes_to_uint32(strKeyIdx)
            tChunkHash:hash(strKeyIdx)

            -- update the hash with content size
            strContentSize = tBinStringHandle:read(2)
            local ulContentSize = tFlasherHelper.bytes_to_uint32(strContentSize)
            ulContentSize = ulContentSize + (ulContentSize % 4) -- round up to dword
            tChunkHash:hash(strContentSize)

            if ulKeyIdx ~= 255 then
                -- get the uuid
                strUUID = tBinStringHandle:read(12)
                tChunkHash:hash(strUUID)

                -- extract all 4 anchors

                strAnchor = tBinStringHandle:read(16)
                tChunkHash:hash(strAnchor)


                -- get the uuid mask
                strUUIDMask = tBinStringHandle:read(12)
                tChunkHash:hash(strUUIDMask)

                strAnchorMask = tBinStringHandle:read(16)
                tChunkHash:hash(strAnchorMask)

                print("strKeyAlgorithm offset " .. tBinStringHandle:seek())
                -- extract the key algorithm
                strKeyAlgorithm = tBinStringHandle:read(1)
                ulKeyAlgorithm = tFlasherHelper.bytes_to_uint32(strKeyAlgorithm)

                print("strKeyStrength offset " .. tBinStringHandle:seek())
                -- extract key strength
                local strKeyStrength = tBinStringHandle:read(1)
                local ulKeyStrength = tFlasherHelper.bytes_to_uint32(strKeyStrength)

                tBinStringHandle:seek("set", tBinStringHandle:seek()-2)
                print("strPaddedKey offset " .. tBinStringHandle:seek())
                -- extract padded key
                strPaddedKey = tBinStringHandle:read(520)
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
                local currentOffset = tBinStringHandle:seek()
                ulSignatureSize = tSignatures[ulKeyAlgorithm][ulKeyStrength]
                strDataContent = tBinStringHandle:read(ulContentSize)
                strSignature = tBinStringHandle:read(ulSignatureSize)
                tChunkHash:hash(strDataContent)

                while string.len(strSignature) < 512 do
                    strSignature = strSignature .. string.char(0x0)
                end
            end
            strChunkHash = tChunkHash:hash_end()
        elseif strChunkID =="HTBL" then
            self.tLog.info("found HTBL chunk")
            local ulReadSize = 0

            -- update the hash with chunk id
            tChunkHash:hash(strChunkID)
            ulReadSize = ulReadSize + 4

            -- update the hash with chunk size
            strChunkSize = tBinStringHandle:read(4)
            local ulChunkSize = tFlasherHelper.bytes_to_uint32(strChunkSize) * 4
            tChunkHash:hash(strChunkSize)
            ulReadSize = ulReadSize + 4

            -- update the hash with page select
            strPageSelect = tBinStringHandle:read(1)
            ulPageSelect = tFlasherHelper.bytes_to_uint32(strPageSelect)
            tChunkHash:hash(strPageSelect)
            ulReadSize = ulReadSize + 1

            -- update the hash with key idx
            strKeyIdx = tBinStringHandle:read(1)
            ulKeyIdx = tFlasherHelper.bytes_to_uint32(strKeyIdx)
            tChunkHash:hash(strKeyIdx)
            ulReadSize = ulReadSize + 1

            local strHashTableEntries = tBinStringHandle:read(2)
            local ulHashTableEntries = tFlasherHelper.bytes_to_uint32(strHashTableEntries)
            local ulHashTableSize = ulHashTableEntries * 48
            tChunkHash:hash(strHashTableEntries)
            ulReadSize = ulReadSize + 2

            -- get the uuid
            strUUID = tBinStringHandle:read(12)
            tChunkHash:hash(strUUID)
            ulReadSize = ulReadSize + 12

            -- extract all 4 anchors
            strAnchor = tBinStringHandle:read(16)
            tChunkHash:hash(strAnchor)
            ulReadSize = ulReadSize + 16

            -- get the uuid mask
            strUUIDMask = tBinStringHandle:read(12)
            tChunkHash:hash(strUUIDMask)
            ulReadSize = ulReadSize + 12

            strAnchorMask = tBinStringHandle:read(16)
            tChunkHash:hash(strAnchorMask)
            ulReadSize = ulReadSize + 16

            local strHashTableContent = tBinStringHandle:read(ulHashTableSize)
            tChunkHash:hash(strHashTableContent)
            ulReadSize = ulReadSize + ulHashTableSize

            strChunkHash = tChunkHash:hash_end()

            print(tBinStringHandle:seek())
            -- chunk size does not include the chunk id and the chunk size itself
            ulSignatureSize = ulChunkSize - ulReadSize + 8
            strSignature = tBinStringHandle:read(ulSignatureSize)
        end

        if tResult == true then
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
                strBindingData = strBindingData .. string.rep(string.char(0x0), 12)
                print(string.len(strBindingData))
                strBindingData = strBindingData .. string.rep(string.char(0x0), 16)
                print(string.len(strBindingData))
                strBindingData = strBindingData .. string.rep(string.char(0x0), 12)
                print(string.len(strBindingData))
                strBindingData = strBindingData .. string.rep(string.char(0x0), 16)
                print(string.len(strBindingData))
            elseif ulPageSelect == 2 then
                strBindingData = strBindingData .. string.rep(string.char(0x0), 12)
                strBindingData = strBindingData .. string.rep(string.char(0x0), 16)
                strBindingData = strBindingData .. string.rep(string.char(0x0), 12)
                strBindingData = strBindingData .. string.rep(string.char(0x0), 16)
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
        end

        tBinStringHandle:close()
    end
    return strDataBlock, tResult, strErrorMsg
end


function main()
    local tParser = argparse('UsipGenerator', ''):command_target("strSubcommand")
    local tUsipData
    local tParserCommandAnalyze = tParser:command('gen_data_block g', ''):target('fCommandAnalyzeSelected')
    tParserCommandAnalyze:argument('input_file', 'input file')
                         :target('strInputFilePath')
    tParserCommandAnalyze:argument('output_file', 'output file')
                         :target('strOutputFilePath')
                         :default(nil)
    tParserCommandAnalyze:option('-V --verbose')
                         :description(string.format(
                             'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
                             table.concat(atLogLevels, ', ')
                         ))
                         :argname('<LEVEL>')
                         :default('debug')
                         :target('strLogLevel')

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
    print("Sipper used as Library")
    -- do nothing
else
    print("Main file")
    main()
end

return Sipper