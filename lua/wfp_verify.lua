module("wfp_verify", package.seeall)

local pl = require 'pl.import_into'()


function verifyWFP(tTarget, tWfpControl, iChiptype, atWfpConditions, tPlugin, tFlasher, aAttr, tLog)

	-- loop over each target flash
	---- get all files (write or erase commands) for current target flash
	---- create a buffer containing the write/erase data of each flash
	------ NEW: for netx90 the data of Bus:2 CS: 0 Unit:3 will be added to the flashes that are morrored by that flash
	---- whenever data overlaps data that was already added to the buffer, it will replace that data either partially or completely

	-- loop over created buffer table for each flash
	---- switch to current flash via detect command
	---- clean flash list (remove entries that were flagged with 'delete' -> whole chunks overwritten by other data)
	---- run verifyWFPData() function with the cleaned chunk list for each flash

    local fOK
    local fVerified = true -- return boolean of function -> be optimistic

    local atFlashDataTable = {} -- stores data chunks for each flash
    local strChipType = tWfpControl.atChiptyp2name[iChiptype]  -- chip type as string

    local tCurrentFlashEntry  -- store the current entry of atFlashDataTable

    local tIntfl0Entry  -- store intflash0 entry for later
    local tIntfl1Entry  -- store intflash1 entry for later

    local ulIntflash0Size = 0x80000
    local tNewChunk

    -- loop over Flashes inside Target
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

            -- add entry inside atFlashDataTable for the flash
			-- strChunkKey is used as a key for the entry in the atFlashDataTable for the flash
            local strChunkKey = "b" .. tBus .. "c" .. ulChipSelect .. "u" .. ulUnit

            if strChipType == "NETX90" and tBus == 2 and ulChipSelect == 0 and ulUnit == 3 then
                -- skip this flash since it is only a mirror of intflash0 and intflash1
				-- entries for that flash will be added to intflash0 and/or intflash1
                local strChunkKeyIf0 = "b2c0u0"
                local strChunkKeyIf1 = "b2c0u1"
                local tNewEntry
                -- add entries for intflash0 and intflash1 if they are not set yet
                if atFlashDataTable[strChunkKeyIf0] == nil then
                    atFlashDataTable[strChunkKeyIf0] = {}
                    tNewEntry = atFlashDataTable[strChunkKeyIf0]
                    tNewEntry['atChunkList'] = {}
                    tNewEntry['tBus'] = 2
                    tNewEntry['ulUnit'] = 0
                    tNewEntry['ulChipSelect'] = 0
                    tIntfl0Entry = tNewEntry
                end
                if atFlashDataTable[strChunkKeyIf1] == nil then
                    atFlashDataTable[strChunkKeyIf1] = {}
                    tNewEntry = atFlashDataTable[strChunkKeyIf1]
                    tNewEntry['atChunkList'] = {}
                    tNewEntry['tBus'] = 2
                    tNewEntry['ulUnit'] = 1
                    tNewEntry['ulChipSelect'] = 0
                    tIntfl1Entry = tNewEntry
                end
            else
				-- new entry for the current flash

                if atFlashDataTable[strChunkKey] == nil then
                    atFlashDataTable[strChunkKey] = {}
                    atFlashDataTable[strChunkKey]['atChunkList'] = {}
                    atFlashDataTable[strChunkKey]['tBus'] = tBus
                    atFlashDataTable[strChunkKey]['ulUnit'] = ulUnit
                    atFlashDataTable[strChunkKey]['ulChipSelect'] = ulChipSelect
                end
                tCurrentFlashEntry = atFlashDataTable[strChunkKey]
            end
            -- save intflash0 entry for later
            if strChipType == "NETX90" and tBus == 2 and ulChipSelect == 0 and ulUnit == 0 then
                tIntfl0Entry = tCurrentFlashEntry
            end
            -- save intflash1 entry for later
            if strChipType == "NETX90" and tBus == 2 and ulChipSelect == 0 and ulUnit == 1 then
                tIntfl1Entry = tCurrentFlashEntry
            end


            -- get file list of entry
            local tFiles = generateFileList(tTargetFlash, tWfpControl, atWfpConditions, tLog)
			-- tFiles contains a list of all flash commands or erase commands inside the wfp.xml control file for the current flash


            -- loop over files
            for i, tFile in ipairs(tFiles) do

                tLog.info('Data Chunk: %d', i)
                tLog.info('ulOffset: 0x%08x', tFile['ulOffset'])
                tLog.info('ulEndOffset: 0x%08x', tFile['ulEndOffset'])
                tLog.info('')

                -- create a new chunk for the file
                tNewChunk = {}
                tSplitChunk = nil

                tNewChunk['ulOffset'] = tFile['ulOffset']
                tNewChunk['ulEndOffset'] = tFile['ulEndOffset']
                tNewChunk['strType'] = tFile['strType']
                tNewChunk['tFile'] = tFile
                tNewChunk['strData'] = tFile['strData']
                tNewChunk['delete'] = false

				-- special treatment for netx90 Bus:2 `CS: 0 Unit:3 (mirror of intflash0 and intflash1)
                if strChipType == "NETX90" and tBus == 2 and ulChipSelect == 0 and ulUnit == 3 then
                    -- get if0 and if1 chunk list
                    tLog.debug("intflash0/1 has extra rules since it is a mirror of intflash0 and intflash1")

                    -- split file into two chunks for intflash0 and intflash1 since unit3 is a mirror if intflash0 and 1
                    if tNewChunk['ulOffset'] < ulIntflash0Size and tNewChunk['ulEndOffset'] > ulIntflash0Size then
                        tLog.info("split chunk into two chunks. it is overlapping two flashes")

                        local strNewChunkData
                        local strSplitChunkData
                        local ulSplitOffset = ulIntflash0Size -tNewChunk['ulOffset']
                        local tSplitChunk1 = {}

                        tSplitChunk1['ulOffset'] = 0x0  -- the part will be mapped to intflash1 and all offsets are subtracted by 0x80000
                        tSplitChunk1['strType'] = tNewChunk['strType']
                        tSplitChunk1['tFile'] = tNewChunk['tFile']
                        tSplitChunk1['delete'] = tNewChunk['delete']
                        if tNewChunk['ulEndOffset'] == 0xFFFFFFFF then
                            -- if the ulEndOffset is 0xFFFFFFFF it needs to stay like that
                            -- this means "use the whole flash size"
                            tNewChunk['ulEndOffset'] = 0xFFFFFFFF
                            tSplitChunk1['ulEndOffset'] = 0xFFFFFFFF
                        else
                            tSplitChunk1['ulEndOffset'] = tNewChunk['ulEndOffset'] - ulIntflash0Size
                            tNewChunk['ulEndOffset'] = ulIntflash0Size
                        end


                        if tNewChunk['strType'] == "flash" then
                            -- split the data only if the type is flash (erase has no data to split)
                            strNewChunkData, strSplitChunkData = splitDataString(tNewChunk['strData'], ulSplitOffset)
                            tNewChunk['strData'] = strNewChunkData
                            tSplitChunk1['strData'] = strSplitChunkData
                        end

                        -- add the new chunk part that is inside intflash0 to intflash0 chunk list
                        addChunkToList(tIntfl0Entry['atChunkList'], tNewChunk, tNewChunk['tFile'], tLog)
                        -- add the new chunk part that is inside intflash1 to intflash1 chunk list
                        addChunkToList(tIntfl1Entry['atChunkList'], tSplitChunk1, tSplitChunk1['tFile'], tLog)

                    elseif tNewChunk['ulOffset'] < ulIntflash0Size and tNewChunk['ulEndOffset'] < ulIntflash0Size then
                        -- add the new chunk part that is inside intflash0 to intflash0 chunk list
                        addChunkToList(tIntfl0Entry['atChunkList'], tNewChunk, tNewChunk['tFile'], tLog)
                    elseif tNewChunk['ulOffset'] >= ulIntflash0Size and tNewChunk['ulEndOffset'] >= ulIntflash0Size then
                        -- add the new chunk part that is inside intflash1 to intflash1 chunk list
                        -- the offsets need to be subtracted by ulIntflDiff
                        tNewChunk['ulOffset'] = tNewChunk['ulOffset'] - ulIntflash0Size
                        if tNewChunk['ulEndOffset'] ~= 0xFFFFFFFF then
                            tNewChunk['ulEndOffset'] = tNewChunk['ulEndOffset'] - ulIntflash0Size
                        end
                        tNewChunk['tFile']['ulOffset'] = tNewChunk['tFile']['ulOffset'] - ulIntflash0Size
                        tNewChunk['tFile']['ulEndOffset'] = tNewChunk['tFile']['ulEndOffset'] - ulIntflash0Size
                        addChunkToList(tIntfl1Entry['atChunkList'], tNewChunk, tNewChunk['tFile'], tLog)
                    end
                else
                    -- add the new chunk to the current chunk entry

                    addChunkToList(tCurrentFlashEntry['atChunkList'], tNewChunk, tNewChunk['tFile'], tLog)
                end
            end
        end
    end


    tLog.info("Verify After gathering data.")

    for strChunkKey, atFlashData in pairs(atFlashDataTable) do
        tLog.info("Verify Data inside Flash B"..atFlashData['tBus'] .." CS" .. atFlashData['ulChipSelect'] .." U"..atFlashData['ulUnit'])
         -- Detect the device. (switch to right flash)
        fOk = tFlasher.detect(tPlugin, aAttr, atFlashData['tBus'], atFlashData['ulUnit'],atFlashData['ulChipSelect'])
        if fOk ~= true then
            tLog.error("Failed to detect the device!")
            fOk = false
            break
        end

        -- clean chunk list and print final chunks that will be verified
        local tCleanChunkList = {}
        for _, tChunk in ipairs(atFlashData['atChunkList']) do
            if tChunk['delete'] ~= true then
                table.insert(tCleanChunkList, tChunk)
                if tChunk['strType'] == "erase" then
                    tLog.debug("verify erase area")
                elseif tChunk['strType'] == "flash" then
                    tLog.debug("verify file data %s", tChunk['tFile']['strFilePath'])
                end
                tLog.debug("at flash offset: [0x%08x - 0x%08x[\n", tChunk['ulOffset'], tChunk['ulEndOffset'])
            end
        end
        atFlashData['atChunkList'] = tCleanChunkList

        -- pass the chunk list of current flash to verifyWFPData
        fOk = verifyWFPData(atFlashData['atChunkList'], tPlugin, tFlasher, aAttr, tLog)
        if fOk == false then
            fVerified = false
        end
    end
    -- print final verify result and return
    print_verify_summary(atFlashDataTable, tLog)

    return fVerified
end

function print_verify_summary(atFlashDataTable, tLog)
    local ulSuccessCount = 0
    local ulFailCount = 0
    tLog.info("Verification summary:")
    tLog.info("===========================================")
    for strChunkKey, atFlashData in pairs(atFlashDataTable) do
        if atFlashData['atChunkList'] ~= nil then
            tLog.info("Flash Bus: "..atFlashData['tBus'] .." Unit: "..atFlashData['ulUnit'].." ChipSelect: " .. atFlashData['ulChipSelect'])
            tLog.info("-------------------------------------------")
        end
        for _, tChunk in ipairs(atFlashData['atChunkList']) do
            if tChunk.verified == true then
                tLog.info("    %s Chunk 0x%08x - 0x%08x: OK ", tChunk.strType, tChunk.ulOffset, tChunk.ulEndOffset)
                ulSuccessCount = ulSuccessCount +1
            else
                tLog.info("    %s Chunk 0x%08x - 0x%08x: FAILED ", tChunk.strType, tChunk.ulOffset, tChunk.ulEndOffset)
                ulFailCount = ulFailCount +1
            end
        end
        print("")
    end
    tLog.info("===========================================")
    tLog.info("    Passes:   %s", ulSuccessCount)
    tLog.info("    Failures: %s", ulFailCount)
    tLog.info("-------------------------------------------")
end

function addChunkToList(tDataChunks, tNewChunk, tFile, tLog)
    -- add tNewChunk to tDataChunks
    ---- modify chunks that would be overwritten by tNewChunk
    tLog.info("Add to chunk list")
    local tSplitChunk
    for ulChunkIdx, tChunk in ipairs(tDataChunks) do
        if tChunk['delete'] ~= true then
            local tFile = tNewChunk['tFile']
            -- check if start of file overlaps start of chunk
            if tNewChunk['ulOffset'] <= tChunk['ulOffset'] and
                tNewChunk['ulEndOffset'] > tChunk['ulOffset'] and
                tNewChunk['ulEndOffset'] < tChunk['ulEndOffset'] then

                -- alter the start of the chunk
                tLog.info('alter the start of the chunk')
                tLog.info('alter chunk area from : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])
                local ulDataSize = tChunk['ulEndOffset']-tChunk['ulOffset']
                local ulSplitOffset = tNewChunk['ulEndOffset']-tChunk['ulOffset']

                tChunk['ulOffset'] = tNewChunk['ulEndOffset']
                if tChunk.strType == "flash" then
                    local strSplitChunkData
                    _, strSplitChunkData = splitDataString(tChunk['strData'], ulSplitOffset)
                    tChunk['strData'] = strSplitChunkData
                end
                -- modify strData inside tChunk

                tLog.info('                   to : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])


            -- check if the whole chunk is overwritten by file
            elseif tNewChunk['ulOffset'] <= tChunk['ulOffset'] and
                tNewChunk['ulEndOffset'] >= tChunk['ulEndOffset'] then

                -- mark index to be removed
                tLog.info('delete chunk          : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])
                tChunk['delete'] = true

            -- check if file overlaps end of chunk
            elseif tNewChunk['ulEndOffset'] >= tChunk['ulEndOffset'] and
                tNewChunk['ulOffset'] < tChunk['ulEndOffset'] and
                tNewChunk['ulOffset'] > tChunk['ulOffset'] then

                -- alter the end of the chunk
                tLog.info('alter the end of the chunk')
                tLog.info('alter chunk area from : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])
                local ulDataSize = tChunk['ulEndOffset']-tChunk['ulOffset']
                local ulSplitOffset = tNewChunk['ulOffset']-tChunk['ulOffset']

                -- modify strData inside tChunk
                if tChunk.strType == "flash" then
                    local strNewChunkData
                    strNewChunkData, _ = splitDataString(tChunk['strData'], ulSplitOffset)
                    tChunk['strData'] = strNewChunkData
                end
                tChunk['ulEndOffset'] = tNewChunk['ulOffset']
                tLog.info('                   to : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])


            -- check if file is inside of chunk
            elseif tNewChunk['ulOffset'] > tChunk['ulOffset'] and
                tNewChunk['ulEndOffset'] < tChunk['ulEndOffset'] then

                -- get data of chunk behind if tNewChunk and add it to new created tSplitChunk
                local ulDataSize = tChunk['ulEndOffset']-tChunk['ulOffset']
                local ulSplitOffset = tNewChunk['ulEndOffset']-tChunk['ulOffset']
                local strSplitChunkData
                local strNewChunkData


                -- create split chunk
                tSplitChunk = {}
                tSplitChunk['ulOffset'] = tNewChunk['ulEndOffset']
                tSplitChunk['ulEndOffset'] = tChunk['ulEndOffset']
                tSplitChunk['strType'] = tChunk['strType']
                tSplitChunk['delete'] = false
                tSplitChunk['tFile'] = tChunk['tFile']

                if tChunk.strType == "flash" then
                    strNewChunkData, strSplitChunkData = splitDataString(tChunk['strData'], ulSplitOffset)
                    tSplitChunk['strData'] = strSplitChunkData


                    -- get the data of the chunk that is in front of tNewChunk
                    ulSplitOffset = tNewChunk['ulOffset']-tChunk['ulOffset']
                    strNewChunkData, _ = splitDataString(tChunk['strData'], ulSplitOffset)
                end

                tChunk['ulEndOffset'] = tNewChunk['ulOffset']
                tChunk['strData'] = strNewChunkData

                tLog.info('split chunk area to : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])
                tLog.info('                and : 0x%08x - 0x%08x', tSplitChunk['ulOffset'], tSplitChunk['ulEndOffset'])
            end
        end
    end

    -- append the new chunk to the list
    table.insert(tDataChunks, tNewChunk)

    -- append the split chunk to the list if there is one
    if tSplitChunk ~= nil then
        table.insert(tDataChunks, tSplitChunk)
    end

end

function splitDataString(strData, ulSplitOffset)
    -- split a data stringinto two data strings at the split offset
    local strDataNew
    local StrDataSplit
    strDataNew =  string.sub(strData, 0x1, ulSplitOffset)
    StrDataSplit =  string.sub(strData, ulSplitOffset+1)
    return strDataNew, StrDataSplit
end

function generateFileList(tTargetFlash, tWfpControl, atWfpConditions, tLog)
    -- collect file data in tFiles table

    local tFiles = {}
    for _, tData in ipairs(tTargetFlash.atData) do
         if tWfpControl:matchCondition(atWfpConditions, tData.strCondition)~=true then
             tLog.info('Not processing file: prevented by condition.')

         else
            if tData.strFile == nil then
                -- erase commands here
                local tCommand = {}
                tCommand["ulOffset"] = tData.ulOffset
                tCommand["ulSize"] = tData.ulSize
                tCommand["ulEndOffset"] = tData.ulOffset + tData.ulSize -- first address after data
                tCommand["strType"] = "erase"
                table.insert(tFiles, tCommand)
            else
                -- data (flash) commands here
                local strFile
                if tWfpControl:getHasSubdirs() == true then
                    tLog.info('WFP archive uses subdirs.')
                    strFile = tData.strFile
                else
                    tLog.info('WFP archive does not use subdirs.')
                    strFile = pl.path.basename(tData.strFile)
                end
                local ulOffset = tData.ulOffset

                tLog.info('Found file "%s" with offset 0x%08x', strFile, ulOffset)
                local strData = tWfpControl:getData(strFile)
                local sizData = string.len(strData)

                local tCommand = {}
                tCommand["strFile"] = pl.path.basename(tData.strFile)
                tCommand["strFilePath"] = tData.strFile
                tCommand["ulOffset"] = tData.ulOffset
                tCommand["ulEndOffset"] = tData.ulOffset + sizData
                tCommand["strData"] = strData
                tCommand["ulSize"] = sizData
                tCommand["strType"] = "flash"
                table.insert(tFiles, tCommand)
            end
         end
    end
    return tFiles
end

function verifyWFPData(tDataChunks, tPlugin, tFlasher, aAttr, tLog)
    -- run verify command for flash data chunks with in wfp.xml
    -- run iserased command for erase commands in wfp.xml
    local fVerified = true  -- be optimistic
    local fOk
    tLog.info('verify chunks from chunk list')

    -- verify the created chunks
    for _, tChunk in ipairs(tDataChunks) do

        if tChunk['strType'] == "erase" then
            -- run isErased function for areas that are expected to be erased after using the wfp archive
            tLog.info('verify erase command at offset 0x%08x to 0x%08x.', tChunk['ulOffset'], tChunk['ulEndOffset'])

            fOk = tFlasher.isErased(tPlugin, aAttr, tChunk['ulOffset'], tChunk['ulEndOffset'])
            if fOk == true then
                tLog.info('ok')
                tChunk['verified'] = true
            else
                tLog.info("ERROR: area 0x%08x to 0x%08x not erased!", tChunk['ulOffset'], tChunk['ulEndOffset'])
                fVerified = false
                tChunk['verified'] = false
                print("verified result: " .. tostring(fVerified))
            end


        elseif tChunk['strType'] == "flash" then
            local strChunkData = tChunk['strData']

            -- run verify function for flashed data that is supposed to be in the flash after flashing the whole wfp archive
            tLog.info('verify flash command at offset [0x%08x, 0x%08x[. file %s', tChunk['ulOffset'], tChunk['ulEndOffset'], tChunk['tFile']['strFilePath'])

            fOk, strMessage = tFlasher.verifyArea(tPlugin, aAttr, tChunk['ulOffset'], strChunkData)
            if fOk == true then
                tLog.info('ok')
                tLog.info(strMessage or "")
                tChunk['verified'] = true
            else
                tLog.info('ERROR: verify failed for area 0x%08x to 0x%08x!', tChunk['ulOffset'], tChunk['ulEndOffset'])
                tLog.info(strMessage or "")
                fVerified = false
                tChunk['verified'] = false
                print("verified result: " .. tostring(fVerified))
            end
        end

    end
    return fVerified
end
