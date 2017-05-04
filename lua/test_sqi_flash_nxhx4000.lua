strUsage = [[
Usage: lua test_sqiflash_nxhx4000.lua <datafile>
The contents of datafile must be at the beginning of the SQI flash.
They will be read in 2 bit IO mode and compared to the data from the file.
]]

if #arg ~= 1 then
	print(strUsage)
	os.exit(0)
end

strDataFileName = arg[1]
fd, msg = io.open(strDataFileName, "rb")
assert(fd, msg)
strFileData = fd:read("*a")
fd:close()


require("muhkuh_cli_init")
require("sqitest")

PC_0400  = 0x0000
PC_0600  = 0x0010
PC_0800  = 0x0020
PC_1200  = 0x0030
PC_U0400 = 0x0001
PC_U0600 = 0x0011
PC_U0800 = 0x0021
PC_U1200 = 0x0031
PC_D0400 = 0x0003
PC_D0600 = 0x0013
PC_D0800 = 0x0023
PC_D1200 = 0x0033

-- Set the range of PortControl registers Py_x0 .. Py_x1 to val
function set_portcontrol(tPlugin, y, x0, x1, val)
	local ADDR_PORTCONTROL = 0xfb100000 + 16 * y * 4
	for x = x0, x1 do
		tPlugin:write_data32(ADDR_PORTCONTROL + 4*x, val)
	end
end  

local tBus = sqitest.BUS_Spi
local uiUnit = 0
local uiChipSelect = 0
local atParameter = {
		ulInitialSpeed = 10000,
		ulMaximumSpeed = 1000,
		ulIdleCfg = 
			  sqitest.MSK_SQI_CFG_IDLE_IO1_OE + sqitest.MSK_SQI_CFG_IDLE_IO1_OUT
			+ sqitest.MSK_SQI_CFG_IDLE_IO2_OE + sqitest.MSK_SQI_CFG_IDLE_IO2_OUT
			+ sqitest.MSK_SQI_CFG_IDLE_IO3_OE + sqitest.MSK_SQI_CFG_IDLE_IO3_OUT,
		ulSpiMode = 3,
		-- LSB = CS, CLK, MISO, MSB = MOSI
		ulMmioConfiguration = 0xffffffff
	}
	

ulDeviceOffset = 0
ulSize = 0x100000 -- 1MB

function getRandomData(ulSize)
	local acChars = {}
	for i=1, ulSize do
		table.insert(acChars, string.char(math.random(0, 255)))
	end
	return table.concat(acChars)
end


-- Open the plugin
tPlugin = tester.getCommonPlugin()
if tPlugin==nil then
	error("No plugin selected, nothing to do!")
end

-- Configure the pads
-- set_portcontrol(tPlugin, 3,  9,  9,  PC_U0600) 
-- set_portcontrol(tPlugin, 3, 10, 12,  PC_0600) 

-- Download the binary.
local aAttr = sqitest.download(tPlugin, "netx/", tester.progress)


atParameter.strCmpData = strFileData
print()
print("=======================================================")
print("=======================================================")
print()


local fOk = sqitest.sqitest(tPlugin, aAttr, tBus, uiUnit, uiChipSelect, fnCallbackMessage, fnCallbackProgress, atParameter)


print()
print("=======================================================")
print("=======================================================")
print()

-- disconnect the plugin
tPlugin:Disconnect()


if fOk then
	print("")
	print(" #######  ##    ## ")
	print("##     ## ##   ##  ")
	print("##     ## ##  ##   ")
	print("##     ## #####    ")
	print("##     ## ##  ##   ")
	print("##     ## ##   ##  ")
	print(" #######  ##    ## ")
	print("")
else
	print("")
	print("######   ####  ###### ##     ###### ####### ")
	print("##      ##  ##   ##   ##     ##      ##   ##")
	print("##      ##  ##   ##   ##     ##      ##   ##")
	print("#####   ######   ##   ##     #####   ##   ##")
	print("##      ##  ##   ##   ##     ##      ##   ##")
	print("##      ##  ##   ##   ##     ##      ##   ##")
	print("##      ##  ## ###### ###### ###### #######" )
	print("")

	error("SQI test failed")
end




