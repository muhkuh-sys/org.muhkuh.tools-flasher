
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

VERIFY_RESULT_OK = 0
VERIFY_RESULT_ERROR = 1
VERIFY_RESULT_FALSE = 2
function Sipper:_init(tLog)
    print("initialize Sipper")
    self.tLog = tLog

end

function Sipper:verify_usip(tUsipConfigData, strComSipData, strAppSipData)
    -- verify the configuration data extracted from an usip file with the content of the COM and APP SIP
    -- return values:
    --  0: (RESULT_VERIFY_OK) data verified
    --  1: (RESULT_VERIFY_ERROR) error while verifying
    --  2: (VERIFY_RESULT_FALSE) verification failed


    local uResult = VERIFY_RESULT_OK
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
            uResult = VERIFY_RESULT_ERROR
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
                uResult = VERIFY_RESULT_FALSE
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

function Sipper.compare_usip_sip(ulOffset, strUsipContent, strSipContent, ulSize)
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


function Sipper:analyze_hboot_image(strFileData)
    local tParsedHbootImage = {}
    local tHbootHeader = {}
    local atChunks = {}
    local tResult = true
    local strErrorMsg
    local tNewChunk
    local ulSignatureSize
    local tChunkHash = mhash.mhash_state()


    if strFileData == nil then
        tResult = false
        strErrorMsg = string.format("No data received")
    else
        local tBinStringHandle = tFlasherHelper.StringHandle(strFileData)
        -- parse hboot header
        tHbootHeader["strMagic"] = tBinStringHandle:read(4)
        tHbootHeader["ulMagicCookie"] = tFlasherHelper.bytes_to_uint32(tHbootHeader["strMagic"])
        tHbootHeader["strSpeedLimit"] = tBinStringHandle:read(4)
        tHbootHeader["strFlashOffsetBytes"] = tBinStringHandle:read(4)
        tBinStringHandle:read(4) -- skip reserved
        tHbootHeader["strChunksSizeDword"] = tBinStringHandle:read(4)
        tHbootHeader["strFlashSelection"] = tBinStringHandle:read(4)
        tHbootHeader["strSignature"] = tBinStringHandle:read(4)
        tHbootHeader["strHashSizeDword"] = tBinStringHandle:read(4)
        tHbootHeader["strSHA224"] = tBinStringHandle:read(28)
        tHbootHeader["ulBootChksm"] = tBinStringHandle:read(4)


        while true do
            -- loop over chunks until chunk id is 00 00
            tNewChunk = {}
            tNewChunk["strChunkId"] = tBinStringHandle:read(4)

            -- check if we reached the end of the image
            if tNewChunk["strChunkId"] == nil or tNewChunk["strChunkId"] == '' then
                self.tLog.error("found invalid chunk id or end of image '%s'", tNewChunk["strChunkId"])
                tResult = false
                strErrorMsg = string.format(
                    "found invalid chunk id or end of image '%s'", tNewChunk["strChunkId"])
                break
            end
            local ulChunkId = tFlasherHelper.bytes_to_uint32(tNewChunk["strChunkId"])
            if ulChunkId == 0 or ulChunkId == nil then
                -- self.tLog.info("found end of image")
                break
            end

            tNewChunk["strChunkSize"] = tBinStringHandle:read(4)
            tNewChunk["ulChunkSize"] = tFlasherHelper.bytes_to_uint32(tNewChunk["strChunkSize"]) * 4

            -- self.tLog.info("found %s chunk", tNewChunk["strChunkId"])

            if tNewChunk["strChunkId"] == "SKIP" then
                -- parse SKIP chunk
                local newOffset = tBinStringHandle:seek() + tNewChunk["ulChunkSize"]
                -- ignore data until end of chunk
                tBinStringHandle:seek("set", newOffset)

            elseif tNewChunk["strChunkId"] == "USIP" then

                tChunkHash:init(mhash.MHASH_SHA384)
                tChunkHash:hash(tNewChunk["strChunkId"])
                tChunkHash:hash(tNewChunk["strChunkSize"])

                -- update the hash with page select
                tNewChunk["strPageSelect"] = tBinStringHandle:read(1)
                tNewChunk["ulPageSelect"] = tFlasherHelper.bytes_to_uint32(tNewChunk["strPageSelect"])
                tChunkHash:hash(tNewChunk["strPageSelect"])

                -- get the key idx
                tNewChunk["strKeyIdx"] = tBinStringHandle:read(1)
                tNewChunk["ulKeyIdx"] = tFlasherHelper.bytes_to_uint32(tNewChunk["strKeyIdx"])
                tChunkHash:hash(tNewChunk["strKeyIdx"])

                -- get the content size
                tNewChunk["strContentSize"] = tBinStringHandle:read(2)
                local ulContentSize = tFlasherHelper.bytes_to_uint32(tNewChunk["strContentSize"])
                tNewChunk["ulContentSize"] = ulContentSize + (ulContentSize % 4) -- round up to dword
                tChunkHash:hash(tNewChunk["strContentSize"])

                if tNewChunk["ulKeyIdx"] ~= 255 then
                    -- get the uuid
                    tNewChunk["strUUID"] = tBinStringHandle:read(12)
                    tChunkHash:hash(tNewChunk["strUUID"])

                    -- extract all 4 anchors
                    tNewChunk["strAnchor"] = tBinStringHandle:read(16)
                    tChunkHash:hash(tNewChunk["strAnchor"])

                    -- get the uuid mask
                    tNewChunk["strUUIDMask"] = tBinStringHandle:read(12)
                    tChunkHash:hash(tNewChunk["strUUIDMask"])

                    -- get the anchor mask
                    tNewChunk["strAnchorMask"] = tBinStringHandle:read(16)
                    tChunkHash:hash(tNewChunk["strAnchorMask"])

                    -- extract the key algorithm
                    tNewChunk["strKeyAlgorithm"] = tBinStringHandle:read(1)
                    tNewChunk["ulKeyAlgorithm"] = tFlasherHelper.bytes_to_uint32(tNewChunk["strKeyAlgorithm"])

                    -- extract key strength
                    tNewChunk["strKeyStrength"] = tBinStringHandle:read(1)
                    tNewChunk["ulKeyStrength"] = tFlasherHelper.bytes_to_uint32(tNewChunk["strKeyStrength"])

                    tBinStringHandle:seek("set", tBinStringHandle:seek()-2)

                    -- extract padded key
                    tNewChunk["strPaddedKey"] = tBinStringHandle:read(520)
                    tChunkHash:hash(tNewChunk["strPaddedKey"])

                    -- check if the extracted values are valid
                    if tSignatures[tNewChunk["ulKeyAlgorithm"]] == nil then
                        tResult = false
                        strErrorMsg = string.format(
                                "Unknown key algorithm extracted: %s (allowed are [1, 2])", tNewChunk["ulKeyAlgorithm"]
                        )
                    end
                    if tSignatures[tNewChunk["ulKeyAlgorithm"]][tNewChunk["ulKeyStrength"]] == nil then
                        tResult = false
                        strErrorMsg = string.format(
                                "Unknown key strength extracted: %s (allowed are [1, 2, 3])", tNewChunk["ulKeyStrength"]
                        )
                    end
                    ulSignatureSize = tSignatures[tNewChunk["ulKeyAlgorithm"]][tNewChunk["ulKeyStrength"]]
                    tNewChunk["strDataContent"] = tBinStringHandle:read(tNewChunk["ulContentSize"])
                    tChunkHash:hash(tNewChunk["strDataContent"])

                    tNewChunk["strSignature"] = tBinStringHandle:read(ulSignatureSize)

                    while string.len(tNewChunk["strSignature"]) < 512 do
                        tNewChunk["strSignature"] = tNewChunk["strSignature"] .. string.char(0x0)
                    end
                end

                -- skip rest of USIP chunk as it is not interesting now
                local newOffset = tBinStringHandle:seek() + tNewChunk["ulChunkSize"]

                -- ignore data until end of chunk
                tBinStringHandle:seek("set", newOffset)
                tNewChunk["strChunkHash"] = tChunkHash:hash_end()
            elseif tNewChunk["strChunkId"] =="HTBL" then

                tChunkHash:init(mhash.MHASH_SHA384)
                tChunkHash:hash(tNewChunk["strChunkId"])
                tChunkHash:hash(tNewChunk["strChunkSize"])

                local ulReadSize = 8  -- we start after chunk id and chunk size

                -- update the hash with page select
                tNewChunk["strPageSelect"] = tBinStringHandle:read(1)
                tNewChunk["ulPageSelect"] = tFlasherHelper.bytes_to_uint32(tNewChunk["strPageSelect"])
                tChunkHash:hash(tNewChunk["strPageSelect"])
                ulReadSize = ulReadSize + 1

                -- update the hash with key idx
                tNewChunk["strKeyIdx"] = tBinStringHandle:read(1)
                tNewChunk["ulKeyIdx"] = tFlasherHelper.bytes_to_uint32(tNewChunk["strKeyIdx"])
                tChunkHash:hash(tNewChunk["strKeyIdx"])
                ulReadSize = ulReadSize + 1

                local strHashTableEntries = tBinStringHandle:read(2)
                local ulHashTableEntries = tFlasherHelper.bytes_to_uint32(strHashTableEntries)
                local ulHashTableSize = ulHashTableEntries * 48
                tChunkHash:hash(strHashTableEntries)
                ulReadSize = ulReadSize + 2

                -- get the uuid
                tNewChunk["strUUID"] = tBinStringHandle:read(12)
                tChunkHash:hash(tNewChunk["strUUID"])
                ulReadSize = ulReadSize + 12

                -- extract all 4 anchors
                tNewChunk["strAnchor"] = tBinStringHandle:read(16)
                tChunkHash:hash(tNewChunk["strAnchor"])
                ulReadSize = ulReadSize + 16

                -- get the uuid mask
                tNewChunk["strUUIDMask"] = tBinStringHandle:read(12)
                tChunkHash:hash(tNewChunk["strUUIDMask"])
                ulReadSize = ulReadSize + 12

                tNewChunk["strAnchorMask"] = tBinStringHandle:read(16)
                tChunkHash:hash(tNewChunk["strAnchorMask"])
                ulReadSize = ulReadSize + 16

                local strHashTableContent = tBinStringHandle:read(ulHashTableSize)
                tChunkHash:hash(strHashTableContent)
                ulReadSize = ulReadSize + ulHashTableSize

                tNewChunk["strChunkHash"] = tChunkHash:hash_end()

                -- print(tBinStringHandle:seek())
                -- chunk size does not include the chunk id and the chunk size itself
                tNewChunk["ulSignatureSize"] = tNewChunk["ulChunkSize"] - ulReadSize + 8
                tNewChunk["strSignature"] = tBinStringHandle:read(tNewChunk["ulSignatureSize"])
                -- write whole 512 bytes as signature for verify_sig.bin to determine the actual signature size
                -- to get the the signature from the end of buffer
                if tNewChunk["ulSignatureSize"] > 512 then
                    -- strip signature string to be exact 512 bytes
                    tNewChunk["strSignature"] = string.sub(tNewChunk["strSignature"], -512)
                else
                    -- fill up signature string to be exact 512 bytes
                    local ulFillupSize = 512 - tNewChunk["ulSignatureSize"]

                    tNewChunk["strSignature"] = string.rep(string.char(0x0), ulFillupSize) .. tNewChunk["strSignature"]
                end
            else
                tNewChunk["strChunkInfo"] = string.format(
                    "Chunk ID '%s' not parsed in detail for now. This feature will be added in the future", tNewChunk["strChunkId"])
                -- parse SKIP chunk
                local newOffset = tBinStringHandle:seek() + tNewChunk["ulChunkSize"]
                -- ignore data until end of chunk
                tBinStringHandle:seek("set", newOffset)
            end
            -- insert chunk into table
            table.insert(atChunks, tNewChunk)
        end
        tBinStringHandle:close()
    end

    tParsedHbootImage["tHbootHeader"] = tHbootHeader
    tParsedHbootImage["atChunks"] = atChunks
    return tParsedHbootImage, tResult, strErrorMsg
end

function Sipper:gen_data_block(strFileData, strOutputBinPath)
    local tParsedHbootImage
    local tResult
    local strErrorMsg
    local strDataBlock = ""
    local ulPageSelect
    local ulKeyIdx
    local fPlaceSignatureAtEnd = false
    local strChunkHash
    local strUUID
    local strAnchor
    local strUUIDMask
    local strAnchorMask
    local strSignature

    tParsedHbootImage, tResult, strErrorMsg = self:analyze_hboot_image(strFileData)

    for _, tChunk in pairs(tParsedHbootImage["atChunks"]) do
        if tChunk["strChunkId"] == "HTBL" or tChunk["strChunkId"] == "USIP" then
            ulPageSelect = tChunk["ulPageSelect"]
            ulKeyIdx = tChunk["ulKeyIdx"]
            strChunkHash = tChunk["strChunkHash"]
            strUUID = tChunk["strUUID"]
            strAnchor = tChunk["strAnchor"]
            strUUIDMask = tChunk["strUUIDMask"]
            strAnchorMask = tChunk["strAnchorMask"]
            strSignature = tChunk["strSignature"]
            if tChunk["strChunkId"] == "HTBL" then
                fPlaceSignatureAtEnd = true
            end
            break
        end
    end
    if strSignature == nil then
        tResult = false
        strErrorMsg = "Image is not signed. No need to generate data block."
    end
    if ulPageSelect == nil then
        tResult = false
        strErrorMsg = "No secure chunk found in image"
    end
    if tResult == true then
        -- create the data block with the collected data
        local usOption  = 0x0100
        local usUsedKeys = 0x0000

        if ulPageSelect == 1 and ulKeyIdx == 16 then
            usOption = usOption | 0x0003
            usUsedKeys = usOption | 0x0004
            -- strDataBlock = strDataBlock .. string.char(0x03, 0x01)
            -- strDataBlock = strDataBlock .. string.char(0x04, 0x00)
        elseif ulPageSelect == 1 and ulKeyIdx == 17 then
            usOption = usOption | 0x0002
            usUsedKeys =usOption | 0x0001
            -- strDataBlock = strDataBlock .. string.char(0x02, 0x01)
            -- strDataBlock = strDataBlock .. string.char(0x01, 0x00)
        elseif ulPageSelect == 2 and ulKeyIdx == 16 then
            usOption = usOption | 0x0004
            usUsedKeys = usOption | 0x0008
            -- strDataBlock = strDataBlock .. string.char(0x04, 0x01)
            -- strDataBlock = strDataBlock .. string.char(0x08, 0x00)
        elseif ulPageSelect == 2 and ulKeyIdx == 17 then
            usOption = usOption | 0x0004
            usUsedKeys = usOption | 0x0008
            -- strDataBlock = strDataBlock .. string.char(0x00, 0x01)
            -- strDataBlock = strDataBlock .. string.char(0x02, 0x00)
        end
        if fPlaceSignatureAtEnd then
            usOption = usOption | 0x1000  -- set flag UNKNOWN_SIGNATURE_SIZE
        end

        local usOptionL = (usOption >> 8) & 0xff;
        local usOptionH = (usOption) & 0xff;
        local usUsedKeysL = (usUsedKeys >> 8) & 0xff;
        local usUsedKeysH = (usUsedKeys) & 0xff;

        strDataBlock = strDataBlock .. string.char(usOptionH, usOptionL)
        strDataBlock = strDataBlock .. string.char(usUsedKeysH, usUsedKeysL)

        strDataBlock = strDataBlock .. strChunkHash

        local strBindingData = ""
        if ulPageSelect == 1 then
            strBindingData = strBindingData .. strUUID
            strBindingData = strBindingData .. strAnchor
            strBindingData = strBindingData .. strUUIDMask
            strBindingData = strBindingData .. strAnchorMask
            strBindingData = strBindingData .. string.rep(string.char(0x0), 12)
            strBindingData = strBindingData .. string.rep(string.char(0x0), 16)
            strBindingData = strBindingData .. string.rep(string.char(0x0), 12)
            strBindingData = strBindingData .. string.rep(string.char(0x0), 16)
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
    return strDataBlock, tResult, strErrorMsg
end

local function main()
    local tParser = argparse('UsipGenerator', ''):command_target("strSubcommand")
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
    local tParserCommandHbootAnalyze = tParser:command('analyze_hboot ah', ''):target('fCommandAnalyzeHbootSelected')
    tParserCommandHbootAnalyze:argument('input_file', 'input file'):target('strInputFilePath')
    tParserCommandHbootAnalyze:option('-V --verbose')
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
    local sipper = Sipper(tLog)

    
    if tArgs.fCommandAnalyzeSelected == true then
        print("=== gen_data_block ===")
        local strData, strMsg = tFlasherHelper.loadBin(tArgs.strInputFilePath)
        --sipper:gen_data_block(strData, tArgs.strOutputFilePath.."_old.bin")

        sipper:gen_data_block_new(strData, tArgs.strOutputFilePath.."_new.bin")
    end
    if tArgs.fCommandAnalyzeHbootSelected == true then
        print("=== analyze hboot ===")

        sipper:analyze_hboot_image(strData)
    end
end


if pcall(debug.getlocal, 4, 1) then
    -- print("Sipper used as Library")
    -- do nothing
else
    -- print("Main file")
    main()
end

return Sipper