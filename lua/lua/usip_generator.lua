--require("LuaPanda").start("127.0.0.1", 8818)

local argparse = require 'argparse'
local mhash = require 'mhash'
local class = require 'pl.class'
local tFlasherHelper = require 'flasher_helper'

local atLogLevels = {
    'debug',
    'info',
    'warning',
    'error',
    'fatal'
}

local tBootCookies = {}

tBootCookies["NETX90"] = {}
tBootCookies["NETX90"]["cookie"] = string.char(0x00, 0xAF, 0xBE, 0xF3)


local UsipGenerator = class()

function UsipGenerator:_init(tLog)
    tLog.debug("initialize USIP Generator")
    self.tLog = tLog

    -- This is the SIP protection cookie.
    self.strSipProtectionCookie = string.char(
        0x8b, 0x42, 0x3b, 0x75, 0xe2, 0x63, 0x25, 0x62,
        0x8a, 0x1e, 0x31, 0x6b, 0x28, 0xb4, 0xd7, 0x03
    )
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

    local path = require 'pl.path'
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
        local strOutputFilePath = path.join(strOutputDir, string.format("%ssingle_usip_%s.usp", strPrefix, iIdx))
        table.insert(aOutputList, strOutputFilePath)

        strUsipData = aDataList[iIdx+1]

        local tUsipFileHandle = io.open(strOutputFilePath, 'wb')
        tUsipFileHandle:write(strUsipData)
        tUsipFileHandle:close()

    end

    return tResult, aOutputList, aDataList
end

function UsipGenerator:analyze_usip(strUsipFilePath)
    local tResult
    local strErrorMsg
    local tUsipFileContent
    local iUsipChunkIdx
    local tLog = self.tLog

    tLog.info(string.format("Analyzing usip file: %s", strUsipFilePath))

    self.strUsipFilePath = strUsipFilePath

    -- set initial values for the usip config
    self.tUsipConfigDict = {}
    self.tUsipConfigDict["num_of_chunks"] = 0
    self.tUsipConfigDict["boot_cookie"] = "unknown"
    self.tUsipConfigDict["netx_type"] = "unknown"
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

    local path = require 'pl.path'
    if path.exists(strUsipFilePath) then
        local tUsipFileHandle = io.open(strUsipFilePath, 'rb')
        local strCookieBytes = tUsipFileHandle:read(4)
        self.tUsipConfigDict["boot_cookie"] = strCookieBytes
        local strImageCookie = tFlasherHelper.bytes_to_uint32(strCookieBytes)

        for tNetX in pairs(tBootCookies) do
            if strCookieBytes == tBootCookies[tNetX]["cookie"] then
                self.tUsipConfigDict["netx_type"] = tNetX
                break
            end
        end
        -- read 4 bytes at offset 16 for the header checksum
        tUsipFileHandle:seek("set", 16)
        local strHeaderImgSize = tUsipFileHandle:read(4)
        self.tUsipConfigDict["header_image_size"] = strHeaderImgSize
        tLog.debug("Header size: 0x%02X bytes", string.byte(strHeaderImgSize))

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
                    if(
                        self.tUsipConfigDict["uuid_int"] ~= "unknown" and
                        self.tUsipConfigDict["uuid_int"] ~= tUsipFileContent[iIdx]["uuid_int"]
                    ) then
                        tResult = false
                        strErrorMsg = "Identity conflict occur! Multiple Chunks in one file with colliding identities."
                        break
                    else
                        self.__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_0_int")
                        self.__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_1_int")
                        self.__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_2_int")
                        self.__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_3_int")
                        self.__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "uuid_mask_int")
                        self.__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_mask_0_int")
                        self.__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_mask_1_int")
                        self.__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_mask_2_int")
                        self.__check_binding_value(tUsipFileContent[iIdx], self.tUsipConfigDict, "anchor_mask_3_int")
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

function UsipGenerator.__check_binding_value(tInputTable, tOutputTable, strCompareKey)
    if tOutputTable[strCompareKey] ~= ("unknown") then
        local ulValueInput = tInputTable[strCompareKey]
        local ulValueOutput = tOutputTable[strCompareKey]
        local ulNewVal = ulValueInput | ulValueOutput
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
    local tUsipFileContent = {}
    local ulSignatureSize = 4
    local iUsipChunkIdx = 0
    local tLog = self.tLog

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

        local iUsipFileOffset


        -- read whole file and find the first USIP chunk
        -- Note: this will cause an error if the string "USIP" occurs
        -- somewhere before the first USIP chunk.
        local strUsipFileContent = tUsipFileHandle:read("*a")
        i = string.find(strUsipFileContent, "USIP")
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
                tLog.debug("No Chunk ID found. End of loop.")
                break
            end

            -- get the chunk size
            ulChunkSize = tFlasherHelper.bytes_to_uint32(strChunkSize) * 4
            tLog.debug(
                'Found chunk "%s" at offset 0x%04x with 0x%04x bytes.',
                strChunkId,
                iUsipFileOffset,
                ulChunkSize
            )
            if strChunkId ~= "USIP" then
                -- skip over this chunk
                tLog.debug(string.format("Skip over '%s' chunk", strChunkId))
                -- add chunk size to the usip file offset plus 8 bytes for chunk id and size value
                iUsipFileOffset = iUsipFileOffset + ulChunkSize + 8

            elseif strChunkId == "USIP" then
                tLog.info("found USIP chunk at offset %s", iUsipFileOffset)

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

                    tLog.debug("strKeyAlgorithm offset " ..tUsipFileHandle:seek())
                    -- extract the key algorithm
                    local strKeyAlgorithm = tUsipFileHandle:read(1)
                    local ulKeyAlgorithm = tFlasherHelper.bytes_to_uint32(strKeyAlgorithm)
                    tUsipFileContent[iUsipChunkIdx]["key_algorithm"] = strKeyAlgorithm


                    tLog.debug("strKeyStrength offset " ..tUsipFileHandle:seek())
                    -- extract key strength
                    local strKeyStrength = tUsipFileHandle:read(1)
                    local ulKeyStrength = tFlasherHelper.bytes_to_uint32(strKeyStrength)
                    tUsipFileContent[iUsipChunkIdx]["key_strength"] = strKeyStrength

                    tUsipFileHandle:seek("set", tUsipFileHandle:seek()-2)
                    tLog.debug("strPaddedKey offset " ..tUsipFileHandle:seek())
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
                tLog.debug("Data part offset " .. tUsipFileHandle:seek())

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

                    tUsipFileHandle:seek()
                    local strPatchedData = tUsipFileHandle:read(ulDataSize)
                    mh_sha384:hash(strPatchedData)
                    tUsipFileContent[iUsipChunkIdx]["data"][iDataIdx]["patched_data"] = strPatchedData
                    ulExtractedDataSize = ulExtractedDataSize + ulDataSize

                    -- check if only padding bytes are left
                    local ulDataLeftSize = ulPatchedDataSize - ulExtractedDataSize
                    if ulDataLeftSize <= 1 then


                        tLog.debug("exit loop")
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

                tUsipFileHandle:seek()
                local strSignature = tUsipFileHandle:read(ulSignatureSize)
                tUsipFileContent[iUsipChunkIdx]["signature"] = strSignature

                tUsipFileContent[iUsipChunkIdx]["sha384_hash"] = mh_sha384:hash_end()

                -- add chunk size to the usip file offset plus 8 bytes for chunk id and size value
                iUsipFileOffset = iUsipFileOffset + ulChunkSize + 8
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


--- Set the SIP protection cookie in a COM SIP.
-- @param strComSipData The COM SIP where the cookie should be set.
-- @return The modified COM SIP page.
function UsipGenerator:setSipProtectionCookie(strComSipData)
    -- Replace the first 16 bytes of the COM page with the SIP protection cookie.
    return self.strSipProtectionCookie .. string.sub(strComSipData, 16+1)
end


-- apply data from an usip file to APP and COM SIP data
function UsipGenerator.apply_usip_data(strComSipData, strAppSipData, tUsipConfigDict)
    local strNewComSipData = strComSipData
    local strNewAppSipData = strAppSipData
    local ulSipPage
    local strUsedData
    local strBefore
    local strAfter
    local tData
    local tSipPage

    for ulChunks= 0, tUsipConfigDict.num_of_chunks - 1 do
    --for _, tSipPage in ipairs(tUsipConfigDict.content) do
        tSipPage = tUsipConfigDict.content[ulChunks]
        ulSipPage = tSipPage.page_type_int
        if ulSipPage == 1 then
            strUsedData = strNewComSipData
        elseif ulSipPage == 2 then
            strUsedData = strNewAppSipData
        end
        for iDataIdx=0, tSipPage['ulDataCount'] do
        -- for ulIdx, tData in ipairs(tSipPage.data) do
            tData = tSipPage.data[iDataIdx]
            strBefore = string.sub(strUsedData, 1, tData.offset_int)
            strAfter = string.sub(strUsedData, tData.offset_int + tData.size_int + 1)
            strUsedData = strBefore .. tData.patched_data ..strAfter
        end
        if ulSipPage == 1 then
            strNewComSipData = strUsedData
        elseif ulSipPage == 2 then
            strNewAppSipData = strUsedData
        end
    end

    return strNewComSipData, strNewAppSipData
end


-- convert an input USIP binary to SIP binaries of the COM and APP SIP
-- if no USIP is provided, the default SIP data will be returned
function UsipGenerator:convertUsipToBin(strComSipBinPath, strAppSipBinPath, tUsipConfigDict, fSetSipProtectionCookie)

    local fResult = true
    local strErrorMsg
    local strComSipData
    local strAppSipData

    strComSipData, strErrorMsg = tFlasherHelper.loadBin(strComSipBinPath)
    if strComSipData == nil then
        self = false
    else
        strAppSipData, strErrorMsg = tFlasherHelper.loadBin(strAppSipBinPath)
        if strAppSipData == nil then
            fResult = false
        end
    end

    if fResult == true then
        if tUsipConfigDict ~= nil then
            -- Set the SIP protection cookie if requested.
            if fSetSipProtectionCookie then
                strComSipData = self:setSipProtectionCookie(strComSipData)
            end
            strComSipData, strAppSipData = self.apply_usip_data(strComSipData, strAppSipData, tUsipConfigDict)

            strComSipData = self.updateSipHash(strComSipData)
            strAppSipData = self.updateSipHash(strAppSipData)
        end
    end

    return fResult, strErrorMsg, strComSipData, strAppSipData
end


--- Update the hash for a COM and APP secure info page.
-- The hash is used to check the integrity of the pages. It is a SHA384 sum over the complete data area.
-- @param strSipData The data of the complete secure info page.
-- @return The updated page.
function UsipGenerator.updateSipHash(strSipData)
    -- Get the data part of the page.
    local strData = string.sub(strSipData, 1, 0x0fd0)
    -- Get the hash for the data part.
    local mh = mhash.mhash_state()
    mh:init(mhash.MHASH_SHA384)
    mh:hash(strData)
    local strHash = mh:hash_end()
    -- Return the updated page.
    return strData .. strHash
end


function UsipGenerator:gen_uniform_data(strComSipTemplate, strAppSipTemplate, strUsipFilePath, fSetSipProtectionCookie)
    local tLog = self.tLog
    local strComSipData
    local strAppSipData
    local strMessage

    -- The template data for the COM and APP secure info page must have 4096 bytes.
    local sizComSipPage = string.len(strComSipTemplate)
    local sizAppSipPage = string.len(strAppSipTemplate)
    if sizComSipPage~=4096 then
        strMessage = string.format('The COM SIP template must have 4096 bytes, but it has %d.', sizComSipPage)

    elseif sizAppSipPage~=4096 then
        strMessage = string.format('The APP SIP template must have 4096 bytes, but it has %d.', sizAppSipPage)

    else
        -- Analyze the USIP file.
        local tUsipAnalyzeResult, strUsipAnalyzeMsg, tUsipConfigDict = self:analyze_usip(strUsipFilePath)
        if tUsipAnalyzeResult~=true then
            strMessage = string.format(
                'Failed to analyze the USIP data from "%s": %s',
                strUsipFilePath,
                strUsipAnalyzeMsg
            )

        else
            -- Dump the analyzed USIP data.
            -- This is a lot of output including some binary data. Do not print this by default, even not on
            -- the "debug" level.
            -- tLog.debug('USIP contents: %s', require 'pl.pretty'.write(tUsipConfigDict))

            -- Use the template as the initial contents for the secure info pages.
            strComSipData = strComSipTemplate
            strAppSipData = strAppSipTemplate

            -- Set the SIP protection cookie if requested.
            if fSetSipProtectionCookie then
                strComSipData = self:setSipProtectionCookie(strComSipData)
            end

            -- Apply the USIP file to the secure info pages.
            strComSipData, strAppSipData = self.apply_usip_data(strComSipData, strAppSipData, tUsipConfigDict)

            -- Update the hashes.
            strComSipData = self.updateSipHash(strComSipData)
            strAppSipData = self.updateSipHash(strAppSipData)
        end
    end

    return strComSipData, strAppSipData, strMessage
end


function UsipGenerator:cmd_gen_uniform_data(strComSipTemplatePath, strAppSipTemplatePath, strUsipFilePath,
                                            strComOutputFile, strAppOutputFile,
                                            fSetSipProtectionCookie)
    local tLog = self.tLog

    local utils = require 'pl.utils'
    tLog.debug('Reading COM SIP template from "%s".', strComSipTemplatePath)
    local strComSipTemplate, strComSipReadError = utils.readfile(strComSipTemplatePath, true)
    if strComSipTemplate==nil then
        tLog.error(
            'Failed to read the COM SIP template from "%s": %s',
            strComSipTemplatePath,
            strComSipReadError
        )
    else
        tLog.debug('Reading APP SIP template from "%s".', strAppSipTemplatePath)
        local strAppSipTemplate, strAppSipReadError = utils.readfile(strAppSipTemplatePath, true)
        if strAppSipTemplate==nil then
            tLog.error(
                'Failed to read the APP SIP template from "%s": %s',
                strAppSipTemplatePath,
                strAppSipReadError
            )
        else
            tLog.debug('Generating uniform data...')
            local strComSipPage, strAppSipPage, strMessage = self:gen_uniform_data(
                strComSipTemplate,
                strAppSipTemplate,
                strUsipFilePath,
                fSetSipProtectionCookie
            )
            if strComSipPage==nil or strAppSipPage==nil then
                tLog.error('Failed to generate the uniform data: %s', strMessage)
            else
                local fWriteComResult, strWriteComMessage = utils.writefile(strComOutputFile, strComSipPage, true)
                if fWriteComResult~=true then
                    tLog.error(
                        'Failed to write the generated COM SIP data to "%s": %s',
                        strComOutputFile,
                        strWriteComMessage
                    )
                else
                    local fWriteAppResult, strWriteAppMessage = utils.writefile(strAppOutputFile, strAppSipPage, true)
                    if fWriteAppResult~=true then
                        tLog.error(
                            'Failed to write the generated APP SIP data to "%s": %s',
                            strAppOutputFile,
                            strWriteAppMessage
                        )
                    else
                        tLog.info('Generated uniform COM SIP data: "%s"',strComOutputFile)
                        tLog.info('Generated uniform APP SIP data: "%s"',strAppOutputFile)
                    end
                end
            end
        end
    end
end


local function main()
    -- Get the path to this source file.
    local strThisModulePath = debug.getinfo(1, "S").source:sub(2)
    -- Construct the path to the helper binaries starting at this module.
    local path = require 'pl.path'
    local strHelperFilesPath = path.normpath(
        path.join(
            path.dirname(strThisModulePath),
            '..',
            'netx',
            'helper'
        )
    )

    -- Get the path to the default COM and APP SIP templates.
    local NETX90_DEFAULT_COM_SIP_BIN = path.join(strHelperFilesPath, 'netx90', 'com_sip_default_ff.bin')
    local NETX90_DEFAULT_APP_SIP_BIN = path.join(strHelperFilesPath, 'netx90', 'app_sip_default_ff.bin')

    local tParser = argparse('UsipGenerator', ''):command_target("strSubcommand")

    local tParserCommandAnalyze = tParser:command('analyze a', 'analyze an usip file and create json file')
                                         :target('fCommandAnalyzeSelected')
    tParserCommandAnalyze:argument('usip_file', 'input usip file')
                        :target('strUsipFilePath')
    tParserCommandAnalyze:argument('json_file', 'json file')
                         :target('strJsonFilePath')
    tParserCommandAnalyze:option('-V --verbose')
                         :description(string.format(
                             'Set the verbosity level to LEVEL. Possible values for LEVEL are %s.',
                             table.concat(atLogLevels, ', ')
                         ))
                         :argname('<LEVEL>')
                         :default('debug')
                         :target('strLogLevel')

    local tParserCommandUniform = tParser:command('uniform u', ''):target('fCommandUniformSelected')
    tParserCommandUniform:argument('usip_input')
                        :argname('<USIP_FILE>')
                        :description("Apply the contents of USIP_FILE to the secure info pages.")
                        :target('strUsipFilePath')
    tParserCommandUniform:argument('com_sip_output')
                        :argname('<COM_OUTPUT_FILE>')
                        :description('Write the generated COM SIP page to COM_OUTPUT_FILE.')
                        :target('strComOutputFile')
    tParserCommandUniform:argument('app_sip_output')
                        :argname('<APP_OUTPUT_FILE>')
                        :description('Write the generated APP SIP page to APP_OUTPUT_FILE.')
                        :target('strAppOutputFile')
    tParserCommandUniform:option('--com_sip_template')
                        :argname('<COM_TEMPLATE_FILE>')
                        :description("Read the default COM SIP contents from COM_TEMPLATE_FILE.")
                        :target('strComSipTemplatePath')
                        :default(NETX90_DEFAULT_COM_SIP_BIN)
    tParserCommandUniform:option('--app_sip_template')
                        :argname('<APP_TEMPLATE_FILE>')
                        :description("Read the default APP SIP contents from APP_TEMPLATE_FILE.")
                        :target('strAppSipTemplatePath')
                        :default(NETX90_DEFAULT_APP_SIP_BIN)
    tParserCommandUniform:flag('--set_sip_protection')
                        :description('Set the SIP protection cookie.')
                        :target('fSetSipProtectionCookie')
                        :default(false)
    tParserCommandUniform:option('-V --verbose')
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
        tLog.debug("=== Analyze ===")
        local usip_gen = UsipGenerator(tLog)
        local tResult, strErrorMsg, tUsipData = usip_gen:analyze_usip(tArgs.strUsipFilePath, tArgs.strJsonFilePath)

        local strOutputDir = ".tmp"
        usip_gen:gen_multi_usip_hboot(tUsipData, strOutputDir)

    elseif tArgs.fCommandUniformSelected then
        tLog.info('Generate uniform data.')
        local usip_gen = UsipGenerator(tLog)
        usip_gen:cmd_gen_uniform_data(
            tArgs.strComSipTemplatePath,
            tArgs.strAppSipTemplatePath,
            tArgs.strUsipFilePath,
            tArgs.strComOutputFile,
            tArgs.strAppOutputFile,
            tArgs.fSetSipProtectionCookie
        )
    end
end



if pcall(debug.getlocal, 4, 1) then
    -- print("USIP Generator used as Library")
    -- do nothing
else
    -- print("Main file")
    main()
end


return UsipGenerator
