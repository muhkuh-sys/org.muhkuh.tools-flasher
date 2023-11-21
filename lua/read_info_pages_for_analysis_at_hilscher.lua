require("muhkuh_cli_init")
local flasher = require("flasher")

local path = require 'pl.path'

local function read_info_page(tPlugin, aAttr, tBus, ulUnit, ulChipSelect, ulOffset, strPageName, strFileName)

    local fOk = flasher.detect(tPlugin, aAttr, tBus, ulUnit, ulChipSelect)
    if not fOk then
        error("Failed to detect an info page!")
    end

    -- Read the info page CAL 
    local strPageContent, strMessage = flasher.readArea(tPlugin, aAttr, ulOffset, 0x1000, tester.callback, tester.callback_progress)
    if not strPageContent then
        error("Failed to read the " .. strPageName .. " page: " .. strMessage)
    end

    -- Save the flash contents.
    local tFile, strMsg = io.open(strFileName, "wb")
    if not tFile then
        error("Failed to open file " .. strFileName .. " for writing: " .. strMsg)
    end

    tFile:write(strPageContent)
    tFile:close()

	return strPageContent

end

local function write_file (strFileName, data)

    -- Save the data to a file.

    local tFile, strMsg = io.open(strFileName, "wb")
    if not tFile then
        error("Failed to open file " .. strFileName .. " for writing: " .. strMsg)
    end

    tFile:write(data)
    tFile:close()

end

local function getPluginByName(strName)
	for _, tPluginClass in ipairs(__MUHKUH_PLUGINS) do
		local iDetected
		local aDetectedInterfaces = {}
		print(string.format("Detecting interfaces with plugin %s", tPluginClass:GetID()))
		iDetected = tPluginClass:DetectInterfaces(aDetectedInterfaces)
		print(string.format("Found %d interfaces with plugin %s", iDetected, tPluginClass:GetID()))

		for i,v in ipairs(aDetectedInterfaces) do
			print(string.format("%d: %s (%s) Used: %s, Valid: %s", i, v:GetName(), v:GetTyp(), tostring(v:IsUsed()), tostring(v:IsValid())))
			if strName == v:GetName() then
				if not v:IsValid() then
					return nil, "Plugin is not valid"
				elseif v:IsUsed() then
					return nil, "Plugin is in use"
				else
					print("found plugin")
					local tPlugin = v:Create()
					if tPlugin then 
						return tPlugin
					else
						return nil, "Error creating plugin instance"
					end
				end
			end
		end
	end
	return nil, "plugin not found"
end

-- detect netX chip typ
local function detect_chip(tPlugin)

    local iChiptype = tPlugin:GetChiptyp()
    local strChipName

    if iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90B or
    iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90C then
        print("Detecting PHY version on netX 90 Rev1")
        local bootpins = require("bootpins")
        bootpins:_init()
        local atResult = bootpins:read(tPlugin)
        if atResult.chip_id == bootpins.atChipID.NETX90B then
            iChiptype = romloader.ROMLOADER_CHIPTYP_NETX90B
        elseif atResult.chip_id == bootpins.atChipID.NETX90BPHYR3 then
            iChiptype = romloader.ROMLOADER_CHIPTYP_NETX90C
        else
            iChiptype = nil
        end
    end

    if iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90B
      or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90C
      or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90D then
        if iChiptype==romloader.ROMLOADER_CHIPTYP_NETX90B then
            strChipName = "netX90 Rev1 (PHY V2)"
        else
            strChipName = tPlugin:GetChiptypName(iChiptype)
        end
        print("")
        print(string.format("Chip type: (%d) %s", iChiptype, strChipName))
        print("")
    else
        if iChiptype ~= nil then
            strChipName = tPlugin:GetChiptypName(iChiptype)
            print("")
            print(string.format("Chip type: (%d) %s", iChiptype, strChipName))
            print("")
            print("This script is only for netX90 rev1 and rev2")
        else
            print("")
            print("No netX detected")
        end
        print("")
        os.exit(1)
    end
    return string.format("Chip type: (%d) %s", iChiptype, strChipName)
end


if #arg~=2 then
    print("")
    print("Backup info pages of netX 90 into a given directory for further analysis at Hilscher side")
    print("")
    print("Usage:")
    print("  lua5.1.exe read_info_pages_for_analysis_at_hilscher.lua <plugin> <output directory>")
    print("")
    print("      <plugin>             Plugin name. Same name as used for the -p option of the CLI Flasher")
    print("      <output directory>   Output directory must be an existing directory")
    print("")
    print("Provide the whole directory to Hilscher for further analysis")
    print("")
    os.exit(1)
end



local strPluginName = arg[1]
local strArchiveName = arg[2]

local pl = require 'pl.import_into'()

-- Does the directory already exist?
if pl.path.exists(strArchiveName) ~= strArchiveName then
    local tFsResult, strError = pl.dir.makepath(strArchiveName)
    if tFsResult == nil then
        print(string.format('Failed to create the directory "%s": %s', strArchiveName, strError))
        print("")
        os.exit(1)
    end
end


-- Open the plugin.
local tPlugin, strMsg = getPluginByName(strPluginName)
if tPlugin==nil then
    print(strMsg or "Error opening connection")
    print("Check the given plugin name")
    print("")
    os.exit(1)
end

tPlugin:Connect()

-- Check if the connected netX is really a netX90 rev1 or rev2.
local strChipDetected = detect_chip(tPlugin)

-- Download the binary.
local aAttr = flasher.download(tPlugin, "netx/", tester.progress)

print("Reading info pages for detailed analysis at Hilscher side ")

-- Read info pages.
local tBus = flasher.BUS_IFlash
local ulUnit = 0
local ulChipSelect = 1
local ulOffset = 0
local strPageName = "CAL"
local strFileName = path.join(strArchiveName, "cal_sip_page_part1.bin")


local strdataCal0 = read_info_page(tPlugin, aAttr, tBus, ulUnit, ulChipSelect, ulOffset, strPageName, strFileName)

-- Read info pages.
ulOffset = 0x1000
strFileName = path.join(strArchiveName, "cal_sip_page_part2.bin")

local strdataCal1 = read_info_page(tPlugin, aAttr, tBus, ulUnit, ulChipSelect, ulOffset, strPageName, strFileName)

-- Read info pages.
ulChipSelect = 2
ulOffset = 0
strFileName = path.join(strArchiveName, "krasse_cal_page.bin")

local strKInfo0 = read_info_page(tPlugin, aAttr, tBus, ulUnit, ulChipSelect, ulOffset, strPageName, strFileName)


-- Read info pages.
ulUnit = 1
ulChipSelect = 1
ulOffset = 0x0000
strPageName = "COM"
strFileName = path.join(strArchiveName, "com_sip_part1.bin")

local strdataCom0 = read_info_page(tPlugin, aAttr, tBus, ulUnit, ulChipSelect, ulOffset, strPageName, strFileName)

-- Read info pages.
ulOffset = 0x1000
strFileName = path.join(strArchiveName, "com_sip_part2.bin")

local strdataCom1 = read_info_page(tPlugin, aAttr, tBus, ulUnit, ulChipSelect, ulOffset, strPageName, strFileName)

-- Read info pages.
ulChipSelect = 2
ulOffset = 0
strFileName = path.join(strArchiveName, "krasse_com_page.bin")

local strKInfo1 = read_info_page(tPlugin, aAttr, tBus, ulUnit, ulChipSelect, ulOffset, strPageName, strFileName)

-- Read info pages.
ulUnit = 2
ulChipSelect = 1
ulOffset = 0x0000
strPageName = "APP"
strFileName = path.join(strArchiveName, "app_sip_part1.bin")

local strdataApp0 = read_info_page(tPlugin, aAttr, tBus, ulUnit, ulChipSelect, ulOffset, strPageName, strFileName)

-- Read info pages.
ulOffset = 0x1000
strFileName = path.join(strArchiveName, "app_sip_part2.bin")

local strdataApp1 = read_info_page(tPlugin, aAttr, tBus, ulUnit, ulChipSelect, ulOffset, strPageName, strFileName)

-- Read info pages.
ulChipSelect = 2
ulOffset = 0
strFileName = path.join(strArchiveName, "krasse_app_page.bin")

local strKInfo2 = read_info_page(tPlugin, aAttr, tBus, ulUnit, ulChipSelect, ulOffset, strPageName, strFileName)


-- extract the UID and hope it is there
local strUid = "UID: "

for i = 1,12 do
  local b = strKInfo0:byte(i,i)
  strUid = strUid .. string.format("%02x", b)
end


strFileName = path.join(strArchiveName, "netX90_identification.txt")

local data = strChipDetected .. "\n" .. strUid
write_file(strFileName, data)


-- Disconnect the plugin.
tPlugin:Disconnect()

print("")
print(strUid)

print("")
print(" ######                       ")
print(" #     #  ####  #    # ###### ")
print(" #     # #    # ##   # #      ")
print(" #     # #    # # #  # #####  ")
print(" #     # #    # #  # # #      ")
print(" #     # #    # #   ## #      ")
print(" ######   ####  #    # ###### ")
print("")

os.exit(0)