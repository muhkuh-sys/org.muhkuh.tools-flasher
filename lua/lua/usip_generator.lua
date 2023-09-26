--require("LuaPanda").start("127.0.0.1", 8818)

local argparse = require 'argparse'
local mhash = require 'mhash'
local pl = require 'pl.import_into'()
local class = require 'pl.class'
local path = require 'pl.path'
local tFlasherHelper = require 'flasher_helper'

local atLogLevels = {
    'debug',
    'info',
    'warning',
    'error',
    'fatal'
}



local UsipGenerator = class()

function UsipGenerator:_init(tLog)
    print("initialize USIP Generator")
    self.tLog = tLog
end

function UsipGenerator:gen_multi_usip(tUsipConfigDict)
   local aDataList = {}
   local tDataNames = {}
    for iIdx = 0, tUsipConfigDict["num_of_chunks"] -1 do
        local tChunkContent = tUsipConfigDict['content'][iIdx]

        -- open the first output file

        local strUsipData = ""

        -- write the magic sequence
        strUsipData = strUsipData .. string.char(0x00, 0xaf, 0xbe, 0xf3)

        -- fill up with 12 zeros
        strUsipData = strUsipData .. string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)

        -- write header image size
        strUsipData = strUsipData .. tUsipConfigDict["header_image_size"]

        -- fill up with 4 zeros
        strUsipData = strUsipData .. string.char(0x00, 0x00, 0x00, 0x00)

        -- write MOOH
        strUsipData = strUsipData .. string.char(0x4d, 0x4f, 0x4f, 0x48)

        -- fill up with 4 zeros
        strUsipData = strUsipData .. string.char(0x00, 0x00, 0x00, 0x00)

        -- write header hash
        strUsipData = strUsipData .. tUsipConfigDict['sha224']

        -- write header checksum
        strUsipData = strUsipData .. tUsipConfigDict['header_check_sum']

        -- write usip cookie
        strUsipData = strUsipData .. string.char(0x55, 0x53, 0x49, 0x50)

        -- write chunk size
        strUsipData = strUsipData .. tChunkContent['chunk_size']

        -- add page type
        strUsipData = strUsipData .. tChunkContent['page_type']

        -- add key index
        strUsipData = strUsipData .. tChunkContent['key_idx']

        -- add patched size
        strUsipData = strUsipData .. tChunkContent['patched_size']

        if tChunkContent['key_idx_int'] ~= 255 then
            strUsipData = strUsipData .. tChunkContent['uuid']
            strUsipData = strUsipData .. tChunkContent['anchor_0']
            strUsipData = strUsipData .. tChunkContent['anchor_1']
            strUsipData = strUsipData .. tChunkContent['anchor_2']
            strUsipData = strUsipData .. tChunkContent['anchor_3']
            strUsipData = strUsipData .. tChunkContent['uuid_mask']
            strUsipData = strUsipData .. tChunkContent['anchor_mask_0']
            strUsipData = strUsipData .. tChunkContent['anchor_mask_1']
            strUsipData = strUsipData .. tChunkContent['anchor_mask_2']
            strUsipData = strUsipData .. tChunkContent['anchor_mask_3']
            strUsipData = strUsipData .. tChunkContent['padded_key']
        end

        -- add data
        for iDataIdx=0, tChunkContent['ulDataCount'] do
            strUsipData = strUsipData .. tChunkContent['data'][iDataIdx]['offset']
            strUsipData = strUsipData .. tChunkContent['data'][iDataIdx]['size']
            strUsipData = strUsipData .. tChunkContent['data'][iDataIdx]['patched_data']
        end

        -- add padding
        strUsipData = strUsipData .. tChunkContent['padding']

        --add signature
        strUsipData = strUsipData .. tChunkContent['signature']
        -- add 4 zeros
        strUsipData = strUsipData .. string.char(0x00, 0x00, 0x00, 0x00)

        table.insert(aDataList, strUsipData)
        table.insert(tDataNames, "single_usip_".. iIdx)
    end
    return aDataList, tDataNames
end

function UsipGenerator:gen_multi_usip_hboot(tUsipConfigDict, strOutputDir, strPrefix)
    local tResult = true

    if not path.exists(strOutputDir) then
        path.mkdir(strOutputDir)
    end

    if strPrefix == nil then
        strPrefix = ""
    end

    local aOutputList = {}
    local aDataList = self:gen_multi_usip(tUsipConfigDict)
    local strUsipData

    for iIdx = 0, tUsipConfigDict["num_of_chunks"] -1 do
        local strOutputFilePath = pl.path.join(strOutputDir, string.format("%ssingle_usip_%s.usp", strPrefix, iIdx))
        table.insert(aOutputList, strOutputFilePath)

        strUsipData = aDataList[iIdx]

        local tUsipFileHandle = io.open(strOutputFilePath, 'wb')
        tUsipFileHandle:write(strUsipData)
        tUsipFileHandle:close()

    end

    return tResult, aOutputList, aDataList
end

function UsipGenerator:analyze_usip(strUsipFilePath)
    local tResult = true -- be optimistic
    local strErrorMsg = ""
    local tUsipFileContent
    local iUsipChunkIdx

    self.tLog.info(string.format("Analyzing usip file: %s", strUsipFilePath))

    self.strUsipFilePath = strUsipFilePath

    -- set initial values for the usip config
    self.tUsipConfigDict = {}
    self.tUsipConfigDict["num_of_chunks"] = 0
    -- key settings
    self.tUsipConfigDict["master_key"] = "not used"
    self.tUsipConfigDict["firmware_key"] = "not used"
    self.tUsipConfigDict["root_key"] = "not used"
    -- binding values
    self.tUsipConfigDict["uuid_int"] = "unknown"
    self.tUsipConfigDict["anchor_0_int"] = "unknown"
    self.tUsipConfigDict["anchor_1_int"] = "unknown"
    self.tUsipConfigDict["anchor_2_int"] = "unknown"
    self.tUsipConfigDict["anchor_3_int"] = "unknown"
    self.tUsipConfigDict["uuid_mask_int"] = "unknown"
    -- binding mask values
    self.tUsipConfigDict["anchor_mask_0_int"] = "unknown"
    self.tUsipConfigDict["anchor_mask_1_int"] = "unknown"
    self.tUsipConfigDict["anchor_mask_2_int"] = "unknown"
    self.tUsipConfigDict["anchor_mask_3_int"] = "unknown"
    -- header chunk size
    self.tUsipConfigDict["header_image_size"] = "unknown"
    -- sha224 hash of the header
    self.tUsipConfigDict["sha224"] = "unknown"
    -- header checksum
    self.tUsipConfigDict["header_check_sum"] = "unknown"

    if path.exists(strUsipFilePath) then
        local tUsipFileHandle = io.open(strUsipFilePath, 'rb')

        -- read 4 bytes at offset 16 for the header checksum
        tUsipFileHandle:seek("set", 16)
        local strHeaderImgSize = tUsipFileHandle:read(4)
        self.tUsipConfigDict["header_image_size"] = strHeaderImgSize
        --print(string.format("%02X ", string.byte(strHeaderImgSize)))

        -- read 28 bytes at offset 32 for the sha224
        tUsipFileHandle:seek("set", 32)
        local strSha224 = tUsipFileHandle:read(28)
        self.tUsipConfigDict["sha224"] = strSha224

        -- read the next 4 bytes after the sha224 for the header checksum
        local strHeaderChecksum = tUsipFileHandle:read(4)
        self.tUsipConfigDict["header_check_sum"] = strHeaderChecksum
        tUsipFileHandle:close()

        -- get the rest of the data from the file
        tResult, strErrorMsg, tUsipFileContent, iUsipChunkIdx = self:get_usip_file_content(strUsipFilePath)
        if tResult then
            self.tUsipConfigDict["num_of_chunks"] = iUsipChunkIdx

            for iIdx = 0, (self.tUsipConfigDict["num_of_chunks"] - 1) do
                if tUsipFileContent[iIdx]['key_idx_int'] ~= 255 then
                    if self.tUsipConfigDict["uuid_int"] ~= "unknown" and self.tUsipConfigDict["uuid_int"] ~= tUsipFileContent[iIdx]["uuid_int"] then
                        tResult = false
                        strErrorMsg = "Identity conflict occur! Multiple Chunks in one file with colliding identities."
                        break
                    else
                        self:__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_0_int")
                        self:__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_1_int")
                        self:__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_2_int")
                        self:__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_3_int")
                        self:__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "uuid_mask_int")
                        self:__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_mask_0_int")
                        self:__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_mask_1_int")
                        self:__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_mask_2_int")
                        self:__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_mask_3_int")
                    end
                end
            end
        end

        self.tUsipConfigDict["content"] = tUsipFileContent
    else
    tResult = false
    strErrorMsg = string.format("Usip file does not exist: %s", strUsipFilePath)
    end

    return tResult, strErrorMsg, self.tUsipConfigDict
end

function UsipGenerator:__check_binding_value(tInputTable, tOutputTable, strCompareKey)
    if tOutputTable[strCompareKey] ~= ("unknown") then
        ulValueInput = tInputTable[strCompareKey]
        ulValueOutput = tOutputTable[strCompareKey]
        ulNewVal = ulValueInput | ulValueOutput
        tOutputTable[strCompareKey] = ulNewVal
    else
        tOutputTable[strCompareKey] = tInputTable[strCompareKey]
    end
end

function UsipGenerator:get_usip_file_content(strUsipFilePath)
    local tResult = true -- be optimistic
    local strErrorMsg = ""
    local tUsipFileHandle
    local i
    local j
    local tUsipFileContent = {}
    local ulSignatureSize = 4
    local iUsipChunkIdx = 0

    local tSignatures = {}
    tSignatures[1] = {}  --ECC
    tSignatures[1][1] = 64  -- 265
    tSignatures[1][2] = 96  -- 384
    tSignatures[1][3] = 64  -- 512
    tSignatures[2] = {}  --RSA
    tSignatures[2][1] = 256  -- 2048
    tSignatures[2][2] = 384  -- 3072
    tSignatures[2][3] = 512  -- 4096

    if strUsipFilePath ~= nil then
        tUsipFileHandle = io.open(strUsipFilePath, 'rb')
    else
        tResult = false
        strErrorMsg = "Missing argument in function get_usip_file_content() strUsipFilePath"
    end

    if tUsipFileHandle ~= nil then

        local iUsipFileOffset = 0


        -- read whole file and find the first USIP chunk
        -- Note: this will cause an error if the string "USIP" occurs 
        -- somewhere before the first USIP chunk.
        local strUsipFileContent = tUsipFileHandle:read("*a")
        i, j = string.find(strUsipFileContent, "USIP")
        iUsipFileOffset = i - 1

        -- reset the file pointer
        tUsipFileHandle:seek("set", 0)

        while 1 do
            -- go to first appearance of USIP chunk
            tUsipFileHandle:seek("set", iUsipFileOffset)
            local strChunkId = tUsipFileHandle:read(4)
            local strChunkSize = tUsipFileHandle:read(4)
            local ulChunkSize

            if strChunkId == nil or tFlasherHelper.bytes_to_uint32(strChunkId) == 0 then
                print("No Chunk ID found. End of loop.")
                break
            end

            -- get the chunk size
            ulChunkSize = tFlasherHelper.bytes_to_uint32(strChunkSize) * 4
            if strChunkId ~= "USIP" then
                -- skip over this chunk
                print(string.format("Skip over '%s' chunk", strChunkId))
                iUsipFileOffset = iUsipFileOffset + ulChunkSize + 8 -- add chunk size to the usip file offset plus 8 bytes for chunk id and size value

            elseif strChunkId == "USIP" then
                self.tLog.info("found USIP chunk at offset %s", iUsipFileOffset)

                -- add new entry for this USIP chunk
                tUsipFileContent[iUsipChunkIdx] = {}

                -- initialize a sha384
                local mh_sha384 = mhash.mhash_state()
                mh_sha384:init(mhash.MHASH_SHA384)

                -- add the chunk id to the hash
                mh_sha384:hash(strChunkId)

                -- add the chunk size to the hash and the table
                mh_sha384:hash(strChunkSize)
                tUsipFileContent[iUsipChunkIdx]["chunk_size"] = strChunkSize

                -- get the destination SIP
                local strChunkPage = tUsipFileHandle:read(1)
                mh_sha384:hash(strChunkPage)
                tUsipFileContent[iUsipChunkIdx]["page_type"] = strChunkPage
                tUsipFileContent[iUsipChunkIdx]["page_type_int"] = tFlasherHelper.bytes_to_uint32(strChunkPage)

                -- get the key type
                local strUsipChunkKey = tUsipFileHandle:read(1)
                local ulUsipChunkKey = tFlasherHelper.bytes_to_uint32(strUsipChunkKey)
                mh_sha384:hash(strUsipChunkKey)
                tUsipFileContent[iUsipChunkIdx]["key_idx"] = strUsipChunkKey
                tUsipFileContent[iUsipChunkIdx]["key_idx_int"] = ulUsipChunkKey
                if ulUsipChunkKey == 0 then
                    tUsipFileContent["root_key"] = "used"
                elseif ulUsipChunkKey == 16 then
                    tUsipFileContent["master_key"] = "used"
                elseif ulUsipChunkKey == 17 then
                    tUsipFileContent["firmware_key"] = "used"
                end

                -- get the patched data size
                local strPatchedDataSize = tUsipFileHandle:read(2)
                mh_sha384:hash(strPatchedDataSize)
                tUsipFileContent[iUsipChunkIdx]["patched_size"] = strPatchedDataSize
                local ulPatchedDataSize = tFlasherHelper.bytes_to_uint32(strPatchedDataSize)

                if ulUsipChunkKey ~= 255 then

                    -- get the uuid
                    local strUUID = tUsipFileHandle:read(12)
                    local ulUUID = tFlasherHelper.bytes_to_uint32(strUUID)
                    mh_sha384:hash(strUUID)
                    tUsipFileContent[iUsipChunkIdx]["uuid"] = strUUID
                    tUsipFileContent[iUsipChunkIdx]["uuid_int"] = ulUUID

                    -- extract all 4 anchors
                    for idx = 0, 3 do
                        local strAnchor = tUsipFileHandle:read(4)
                        local ulAnchor = tFlasherHelper.bytes_to_uint32(strAnchor)
                        mh_sha384:hash(strAnchor)
                        tUsipFileContent[iUsipChunkIdx][string.format("anchor_%s", idx)] = strAnchor
                        tUsipFileContent[iUsipChunkIdx][string.format("anchor_%s_int", idx)] = ulAnchor
                    end

                    -- get the uuid mask
                    local strUUIDMask = tUsipFileHandle:read(12)
                    local ulUUIDMask = tFlasherHelper.bytes_to_uint32(strUUIDMask)
                    mh_sha384:hash(strUUIDMask)
                    tUsipFileContent[iUsipChunkIdx]["uuid_mask"] = strUUIDMask
                    tUsipFileContent[iUsipChunkIdx]["uuid_mask_int"] = ulUUIDMask

                    -- extract all 4 anchor masks
                    for idx = 0, 3 do
                        local strAnchorMask = tUsipFileHandle:read(4)
                        local ulAnchorMask = tFlasherHelper.bytes_to_uint32(strAnchorMask)
                        mh_sha384:hash(strAnchorMask)
                        tUsipFileContent[iUsipChunkIdx][string.format("anchor_mask_%s", idx)] = strAnchorMask
                        tUsipFileContent[iUsipChunkIdx][string.format("anchor_mask_%s_int", idx)] = ulAnchorMask
                    end

                    print("strKeyAlgorithm offset " ..tUsipFileHandle:seek())
                    -- extract the key algorithm
                    local strKeyAlgorithm = tUsipFileHandle:read(1)
                    local ulKeyAlgorithm = tFlasherHelper.bytes_to_uint32(strKeyAlgorithm)
                    tUsipFileContent[iUsipChunkIdx]["key_algorithm"] = strKeyAlgorithm


                    print("strKeyStrength offset " ..tUsipFileHandle:seek())
                    -- extract key strength
                    local strKeyStrength = tUsipFileHandle:read(1)
                    local ulKeyStrength = tFlasherHelper.bytes_to_uint32(strKeyStrength)
                    tUsipFileContent[iUsipChunkIdx]["key_strength"] = strKeyStrength

                    tUsipFileHandle:seek("set", tUsipFileHandle:seek()-2)
                    print("strPaddedKey offset " ..tUsipFileHandle:seek())
                    -- extract padded key
                    local strPaddedKey = tUsipFileHandle:read(520)
                    tUsipFileContent[iUsipChunkIdx]["padded_key"] = strPaddedKey



                    -- check if the extracted values are valid
                    if tSignatures[ulKeyAlgorithm] == nil then
                        tResult = false
                        strErrorMsg = string.format(
                                "Unknown key algorithm extracted: %s (allowed are [1, 2])", ulKeyAlgorithm
                        )
                        break
                    end
                    if tSignatures[ulKeyAlgorithm][ulKeyStrength] == nil then
                        tResult = false
                        strErrorMsg = string.format(
                                "Unknown key strength extracted: %s (allowed are [1, 2, 3])", ulKeyStrength
                        )
                        break
                    end

                    ulSignatureSize = tSignatures[ulKeyAlgorithm][ulKeyStrength]
                end

                local iDataIdx = 0
                local ulExtractedDataSize = 0
                tUsipFileContent[iUsipChunkIdx]["data"] = {}
                print("Data part offset " .. tUsipFileHandle:seek())

                while tResult do
                    tUsipFileContent[iUsipChunkIdx]["data"][iDataIdx] = {}

                    local strDataOffset = tUsipFileHandle:read(2)
                    local ulDataOffset = tFlasherHelper.bytes_to_uint32(strDataOffset)
                    mh_sha384:hash(strDataOffset)
                    tUsipFileContent[iUsipChunkIdx]["data"][iDataIdx]["offset"] = strDataOffset
                    tUsipFileContent[iUsipChunkIdx]["data"][iDataIdx]["offset_int"] = ulDataOffset
                    ulExtractedDataSize = ulExtractedDataSize + 2

                    local strDataSize = tUsipFileHandle:read(2)
                    local ulDataSize = tFlasherHelper.bytes_to_uint32(strDataSize)
                    mh_sha384:hash(strDataSize)
                    tUsipFileContent[iUsipChunkIdx]["data"][iDataIdx]["size"] = strDataSize
                    tUsipFileContent[iUsipChunkIdx]["data"][iDataIdx]["size_int"] = ulDataSize
                    ulExtractedDataSize = ulExtractedDataSize + 2

                    local current = tUsipFileHandle:seek()
                    local strPatchedData = tUsipFileHandle:read(ulDataSize)
                    mh_sha384:hash(strPatchedData)
                    tUsipFileContent[iUsipChunkIdx]["data"][iDataIdx]["patched_data"] = strPatchedData
                    ulExtractedDataSize = ulExtractedDataSize + ulDataSize

                    -- check if only padding bytes are left
                    local ulDataLeftSize = ulPatchedDataSize - ulExtractedDataSize
                    if ulDataLeftSize <= 1 then


                        print("exit loop")
                        break
                    end
                    iDataIdx = iDataIdx + 1
                end

                -- save the amount of data elements
                tUsipFileContent[iUsipChunkIdx]["ulDataCount"] = iDataIdx

                -- add the padding size to the patched data size
                local ulPaddingSize = (4 - (ulPatchedDataSize % 4) ) % 4

                local strPadding = tUsipFileHandle:read(ulPaddingSize)
                local ulPadding = tFlasherHelper.bytes_to_uint32(strPadding)
                if ulPadding == 0 and ulPadding ~= nil then
                    tUsipFileContent[iUsipChunkIdx]["padding"] = strPadding
                else
                    tUsipFileContent[iUsipChunkIdx]["padding"] = ""
                end

                local current = tUsipFileHandle:seek()
                local strSignature = tUsipFileHandle:read(ulSignatureSize)
                tUsipFileContent[iUsipChunkIdx]["signature"] = strSignature

                tUsipFileContent[iUsipChunkIdx]["sha384_hash"] = mh_sha384:hash_end()

                iUsipFileOffset = iUsipFileOffset + ulChunkSize + 8 -- add chunk size to the usip file offset plus 8 bytes for chunk id and size value
                -- increment the index
                iUsipChunkIdx = iUsipChunkIdx + 1
            end
        end
    else
        tResult = false
        strErrorMsg = "Could not open Usip file."
    end

    tUsipFileHandle:close()
    return tResult, strErrorMsg, tUsipFileContent, iUsipChunkIdx
end

function main()
    local tParser = argparse('UsipGenerator', ''):command_target("strSubcommand")
    local tUsipData
    local tParserCommandAnalyze = tParser:command('analyze a', 'analyze an usip file and create json file'):target('fCommandAnalyzeSelected')
    tParserCommandAnalyze:argument('usip_file', 'input usip file'):target('strUsipFilePath')
    tParserCommandAnalyze:argument('json_file', 'json file'):target('strJsonFilePath')
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
        print("=== Analyze ===")
        usip_gen = UsipGenerator(tLog)
        tResult, strErrorMsg, tUsipData = usip_gen:analyze_usip(tArgs.strUsipFilePath, tArgs.strJsonFilePath)

        strOutputDir = ".tmp"
        usip_gen:gen_multi_usip_hboot(tUsipData, strOutputDir)
    end
end



if pcall(debug.getlocal, 4, 1) then
    print("USIP Generator used as Library")
    -- do nothing
else
    print("Main file")
    main()
end


return UsipGenerator


