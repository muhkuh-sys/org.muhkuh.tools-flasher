module("helper_files", package.seeall)

require("pl")
path = require("pl.path")
local tFlasherHelper = require 'flasher_helper'

function printf(...) print(string.format(...)) end



-- ==========================================================================
-- The list of known helper files.
-- The key is a short name for the helper. It is passed by the caller.
-- filename is the actual file name of the helper.
-- version is the expected version string.byte
-- version_offset is the offset of the version string inside the file.
-- If it is not specified, the entire file is searched for the
-- version string. 

atHelperFileVersions = {
    bootswitch = {
        filename = "bootswitch.bin",
        version = "GITV1.0.2-0-gec97ccacc78d",
        version_offset = 0x4bc
    },

    -- read_sip_m2m = {
    --     filename = "read_sip_M2M.bin",
    --     version = "",
    --     version_offset = 0x
    -- },
    -- 
    -- return_exec = {
    --     filename = "return_exec.bin",
    --     version = "",
    --     version_offset = 0x
    -- },
    -- 
    -- set_kek = {
    --     filename = "set_kek.bin",
    --     version = "",
    --     version_offset = 0x
    -- },
    -- 
    -- verify_sig = {
    --     filename = "verify_sig.bin",
    --     version = "",
    --     version_offset = 0x
    -- },

    flasher_netx90_hboot = {
        filename = "flasher_netx90_hboot.bin",
        version = "GITv2.0.0-dev6-0", 
        version_offset = 0x0410
    },

    start_mi = {
        filename = "hboot_start_mi_netx90_com_intram.bin",
        version = "Ver:GITv2.5.4-dev5-2-g7c67f4dc7910+:reV",
        version_offset = 0x0454
    },

    -- testing
    start_mi__wrong_filename = {
        filename = "hboot_start_mi_netx90_com_intram__.bin",
        version = "Ver:GITv2.5.4-dev5-2-g7c67f4dc7910+:reV",
        version_offset = 0x0454
    },
    start_mi__wrong_offset = {
        filename = "hboot_start_mi_netx90_com_intram.bin",
        version = "Ver:GITv2.5.4-dev5-2-g7c67f4dc7910+:reV",
        version_offset = 0x0458
    },
    start_mi__wrong_version = {
        filename = "hboot_start_mi_netx90_com_intram.bin",
        version = "Ver:GITv2.5.5-dev4-6-ga3277b9142e5+:reV",
        version_offset = 0x0454
    },
    
    start_mi_clr = {
        filename = "hboot_start_mi_netx90_com_intram_clear_workarea.bin",
        version = "Ver:GITv2.5.4-dev5-2-g7c67f4dc7910+:reV",
    },
    
    start_mi_clr_wrong_version = {
        filename = "hboot_start_mi_netx90_com_intram_clear_workarea.bin",
        version = "Ver:GITv2.5.5-dev4-6-ga3277b9142e5+:reV",
    }
}


-- ==========================================================================
-- Load a helper file and check its version.
-- strKey: short name for the binary, e.g. "start_mi"
-- strDir: directory where the binary is located
-- fDontCheckversion: if true, the version check is skipped
-- 
-- Returns:
-- a binary string of the helper file, if it was found and has the 
--    expected version.
-- nil and a message string if an error occurred, e.g.
--     - unknown key
--     - file not found 
--     - version did not match
    
function getHelperFile(strKey, strDir, fDontCheckversion)
    local strBin, strMsg 
    
    fDontCheckversion = fDontCheckversion or false
    
    tEntry = atHelperFileVersions[strKey]
    if tEntry == nil then
        strMsg = string.format("Unknown helper name: %s", strKey)
    else
        -- build the path
        local strPath = path.join(strDir, tEntry.filename)
        local strVersion = tEntry.version
        local iOffset = tEntry.version_offset
        printf("Loading helper file %s from path path %s", strKey, strPath)
        
        -- read the file
        strBin, strMsg = tFlasherHelper.loadBin(strPath)
        
        -- failed to read the file 
        if strBin == nil then
            strMsg = string.format("Failed to load helper file %s: %s",
                strKey, strMsg)
            print(strMsg)
                
        -- 
        else
            printf("Helper file %s loaded (%d bytes)", strKey, strBin:len())
            
            if fDontCheckversion ~= true then
                local fOk
                if iOffset ~= nil then
                    local iStartOffset = iOffset+1
                    local iEndOffset = iOffset+strVersion:len()
                    local strFileVersion = strBin:sub(iStartOffset, iEndOffset)
                    fOk = ( strFileVersion == strVersion)
                else 
                    local m = strBin:find(strVersion, 1, true)
                    fOk = (m ~= nil)
                end
                
                if fOk then
                    strMsg = nil
                    printf("Helper file %s has the expected version (%s) - OK", strKey, strVersion)
                else 
                    strBin = nil
                    strMsg = string.format("Helper file %s does not have the expected version (%s).", strKey, strVersion)
                    print(strMsg)
                end
            end
        end
    end
    
    return strBin, strMsg
end

-- ==========================================================================
-- Verify if all helper files have the correct version.
-- Returns true or false.

function checkAllHelpers(strDir)
    local fOk = true
    for strKey, _ in pairs(atHelperFileVersions) do
        print()
        strBin, strMsg = getHelperFile(strKey, strDir)
        if strBin == nil then
            fOk = false
        end
    end
    print()
    
    if fOk == true then
        printf("%s: All helper files were found and have the correct version.", strDir)
    else 
        printf("%s: Some helper files were not found or do not have the correct version.", strDir)
    end 
    return fOk
end
