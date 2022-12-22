
local class = require 'pl.class'

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

return Sipper