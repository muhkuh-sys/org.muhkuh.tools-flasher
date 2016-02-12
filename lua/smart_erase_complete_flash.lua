-----------------------------------------------------------------------------
--   Script for initiating smarterasing serailflash on the netX            --
--                                                                         --
--   Does the same like normal erase but in less time                      --
-----------------------------------------------------------------------------

require("muhkuh_cli_init")
require("flasher")

tPlugin = tester.getCommonPlugin()
if not tPlugin then
  error("No plugin selected, nothing to do!")
end

-- Download the binary.
local aAttr = flasher.download(tPlugin, "netx/", tester.callback_progress)

-- Use SPI Flash CS0.
local fOk = flasher.detect(tPlugin, aAttr, flasher.BUS_Spi, 0, 0, ulDevDescAdr)
if not fOk then
  error("Failed to get a device description!")
end

-- Get the complete devicesize.
ulFlashSize = flasher.getFlashSize(tPlugin, aAttr, tester.callback, tester.callback_progress)
print(string.format("The device size is: 0x%08x", ulFlashSize))

-- Erase the complete device.
ulEraseStart, ulEraseEnd = flasher.getEraseArea(tPlugin, aAttr, 0, ulFlashSize)
if not ulEraseStart then
  error("Failed to get erase areas!")
end


-- Flash the file.
local tBus = flasher.BUS_Spi
local ulUnit = 0
local ulChipSelect = 0
print("\n\n!!!! Here it's getting interesting!!!\n\n\n")

--local fIsOk = flasher.erase(tPlugin, aAttr, ulEraseStart, ulEraseEnd)

local fIsOk = flasher.smart_erase(tPlugin, aAttr, 0, ulFlashSize, tester.callback, tester.callback_progress)

--fIsErased = flasher.isErased(tPlugin, aAttr, ulEraseStart, ulEraseEnd)
--if not fIsErased then
--  error("No error reported, but the area is not erased!")
--else
--
--  print("")
--  print(" #######  ##    ## ")
--  print("##     ## ##   ##  ")
--  print("##     ## ##  ##   ")
--  print("##     ## #####    ")
--  print("##     ## ##  ##   ")
--  print("##     ## ##   ##  ")
--  print(" #######  ##    ## ")
--  print("")
--end
-- Disconnect the plugin.
tester.closeCommonPlugin()
-- or tPlugin:Disconnect() ????


