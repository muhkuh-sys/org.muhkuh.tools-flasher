module("wfp_verify", package.seeall)

local pl = require 'pl.import_into'()

function generate_verify_chunks(tFiles, tLog)
    -- take the file list and generate chunks from that are not overwritten by other files
    local tDataChunks = {}

    for i, tFile in ipairs(tFiles) do
        local ulRemoveChunkIdx
        local tNewChunk = {}
        local tSplitChunk

        tNewChunk['ulOffset'] = tFile['ulOffset']
        tNewChunk['ulEndOffset'] = tFile['ulEndOffset']
        tNewChunk['strType'] = tFile['strType']
        tNewChunk['tFile'] = tFile

        tLog.info('file: %d', i)
        tLog.info('ulOffset: 0x%08x', tFile['ulOffset'])
        tLog.info('ulEndOffset: 0x%08x', tFile['ulEndOffset'])
        tLog.info('')

        for ulChunkIdx, tChunk in ipairs(tDataChunks) do
            -- check if start of file overlaps start of chunk
            if tFile['ulOffset'] <= tChunk['ulOffset'] and
                    tChunk['ulOffset'] < tFile['ulEndOffset'] and
                    tFile['ulEndOffset'] < tChunk['ulEndOffset'] then

                -- alter the start of the chunk
                tLog.info('alter the start of the chunk')
                tLog.info('alter chunk area from : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])
                tChunk['ulOffset'] = tFile['ulEndOffset']
                tLog.info('                   to : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])


            -- check if the whole chunk is overwritten by file
            elseif tFile['ulOffset'] <= tChunk['ulOffset'] and
                    tFile['ulEndOffset'] >= tChunk['ulEndOffset'] then

                -- mark index to be removed
                tLog.info('delete chunk          : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])
                ulRemoveChunkIdx = ulChunkIdx


            -- check if file overlaps end of chunk
            elseif tFile['ulEndOffset'] >= tChunk['ulEndOffset'] and
                    tFile['ulOffset'] < tChunk['ulEndOffset'] and
                    tFile['ulOffset'] > tChunk['ulOffset'] then

                -- alter the end of the chunk
                tLog.info('alter the end of the chunk')
                tLog.info('alter chunk area from : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])
                tChunk['ulEndOffset'] = tFile['ulOffset']
                tLog.info('                   to : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])


            -- check if file is inside of chunk
            elseif tFile['ulOffset'] >= tChunk['ulOffset'] and
                    tFile['ulEndOffset'] < tChunk['ulEndOffset'] then

                -- create split chunk
                tSplitChunk = {}
                tSplitChunk['ulOffset'] = tFile['ulEndOffset']
                tSplitChunk['ulEndOffset'] = tChunk['ulEndOffset']
                tSplitChunk['strType'] = tChunk['strType']
                tNewChunk['tFile'] = tChunk['tFile']
                tLog.info('alter chunk area from : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])
                tChunk['ulEndOffset'] = tFile['ulOffset']
                tLog.info('                   to : 0x%08x - 0x%08x', tChunk['ulOffset'], tChunk['ulEndOffset'])
                tLog.info('add new chunk         : 0x%08x - 0x%08x', tNewChunk['ulOffset'], tNewChunk['ulEndOffset'])
            end
        end

        -- if a chunk has to be removed, remove it from the list
        if ulRemoveChunkIdx then
            table.remove(tDataChunks, ulRemoveChunkIdx)
        end

        -- append the new chunk to the list
        tDataChunks[#tDataChunks + 1] = tNewChunk

        -- append the split chunk to the list if there is one
        if tSplitChunk then
            tDataChunks[#tDataChunks + 1] = tSplitChunk
        end
    end

    return tDataChunks
end

function generate_file_list(tTargetFlash, tWfpControl, atWfpConditions, tLog)
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
                tCommand["ulEndOffset"] = tData.ulOffset + tData.ulSize
                tCommand["strType"] = "erase"
                tFiles[#tFiles + 1] = tCommand
            else
                -- data (flash) commands here
                local strFile = pl.path.basename(tData.strFile)
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
                tFiles[#tFiles + 1] = tCommand
            end
         end
    end
    return tFiles
end

function verify_wfp_data(tTargetFlash, tWfpControl, atWfpConditions, tPlugin, tFlasher, aAttr, tLog)
    local fVerified = true  -- be optimistic
    local tFiles = generate_file_list(tTargetFlash, tWfpControl, atWfpConditions, tLog)

    -- generate table of chunks that have to be verified
    local tDataChunks = generate_verify_chunks(tFiles, tLog)

    for _, tChunk in ipairs(tDataChunks) do

    end
    -- verify the created chunks
    for _, tChunk in ipairs(tDataChunks) do

        if tChunk['strType'] == "erase" then
            tLog.info('verify erase command at offset 0x%08x to 0x%08x.', tChunk['ulOffset'], tChunk['ulEndOffset'])
            if tFlasher.isErased(tPlugin, aAttr, tChunk['ulOffset'], tChunk['ulEndOffset']) == true then
                print("ok")
            else
                print("ERROR: area not erased!")
                fVerified = false
            end


        elseif tChunk['strType'] == "flash" then
            tLog.info('verify flash command at offset 0x%08x to 0x%08x. file %s', tChunk['ulOffset'], tChunk['ulEndOffset'], tChunk['tFile']['strFilePath'])
            -- get the chunk data from the file
            local strChunkData
            local ulChunkSize = tChunk['ulEndOffset'] - tChunk['ulOffset']
            local ulDataOffset = tChunk['ulOffset'] - tChunk['tFile']['ulOffset'] + 1
            local ulDataEndOffset = ulDataOffset + ulChunkSize - 1
            tLog.info('get data from file offset 0x%08x to 0x%08x.', ulDataOffset, ulDataEndOffset)
            strChunkData = string.sub(tChunk['tFile']['strData'], ulDataOffset, ulDataEndOffset)
            if tFlasher.verifyArea(tPlugin, aAttr, tChunk['ulOffset'], strChunkData) == true then
                print("ok")
            else
                print("ERROR: wrong data found!")
                fVerified = false
            end
        end

    end
    return fVerified
end
