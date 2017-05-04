module("sqitest", package.seeall)

-----------------------------------------------------------------------------
--   Copyright (C) 2009 by Christoph Thelen                                --
--   doc_bacardi@users.sourceforge.net                                     --
--                                                                         --
--   This program is free software; you can redistribute it and/or modify  --
--   it under the terms of the GNU General Public License as published by  --
--   the Free Software Foundation; either version 2 of the License, or     --
--   (at your option) any later version.                                   --
--                                                                         --
--   This program is distributed in the hope that it will be useful,       --
--   but WITHOUT ANY WARRANTY; without even the implied warranty of        --
--   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
--   GNU General Public License for more details.                          --
--                                                                         --
--   You should have received a copy of the GNU General Public License     --
--   along with this program; if not, write to the                         --
--   Free Software Foundation, Inc.,                                       --
--   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             --
-----------------------------------------------------------------------------
-- 
-- Description:
-----------------------------------------------------------------------------

require("bit")
require("muhkuh")
require("romloader")


-----------------------------------------------------------------------------
--                           Definitions
-----------------------------------------------------------------------------

BUS_Parflash    = ${BUS_ParFlash}             -- parallel flash
BUS_Spi         = ${BUS_SPI}             -- serial flash on spi bus
BUS_IFlash      = ${BUS_IFlash}             -- internal flash

OPERATION_MODE_Sqitest             = ${OPERATION_MODE_Sqitest}


MSK_SQI_CFG_IDLE_IO1_OE          = ${MSK_SQI_CFG_IDLE_IO1_OE}
SRT_SQI_CFG_IDLE_IO1_OE          = ${SRT_SQI_CFG_IDLE_IO1_OE}
MSK_SQI_CFG_IDLE_IO1_OUT         = ${MSK_SQI_CFG_IDLE_IO1_OUT}
SRT_SQI_CFG_IDLE_IO1_OUT         = ${SRT_SQI_CFG_IDLE_IO1_OUT}
MSK_SQI_CFG_IDLE_IO2_OE          = ${MSK_SQI_CFG_IDLE_IO2_OE}
SRT_SQI_CFG_IDLE_IO2_OE          = ${SRT_SQI_CFG_IDLE_IO2_OE}
MSK_SQI_CFG_IDLE_IO2_OUT         = ${MSK_SQI_CFG_IDLE_IO2_OUT}
SRT_SQI_CFG_IDLE_IO2_OUT         = ${SRT_SQI_CFG_IDLE_IO2_OUT}
MSK_SQI_CFG_IDLE_IO3_OE          = ${MSK_SQI_CFG_IDLE_IO3_OE}
SRT_SQI_CFG_IDLE_IO3_OE          = ${SRT_SQI_CFG_IDLE_IO3_OE}
MSK_SQI_CFG_IDLE_IO3_OUT         = ${MSK_SQI_CFG_IDLE_IO3_OUT}
SRT_SQI_CFG_IDLE_IO3_OUT         = ${SRT_SQI_CFG_IDLE_IO3_OUT}

FLASHER_INTERFACE_VERSION        = ${FLASHER_INTERFACE_VERSION}


--------------------------------------------------------------------------
-- callback/progress functions, 
-- read/write image, call
--------------------------------------------------------------------------


local ulProgressLastTime    = 0
local fProgressLastPercent  = 0
local ulProgressLastMax     = nil
PROGRESS_STEP_PERCENT       = 10

function default_callback_progress(ulCnt, ulMax)
	local fPercent = ulCnt * 100 / ulMax
	local ulTime = os.time()
	if ulProgressLastMax ~= ulMax
		or ulCnt == 0
		or ulCnt == ulMax
		or fProgressLastPercent - fPercent > PROGRESS_STEP_PERCENT
		or ulTime - ulProgressLastTime > 1 then
			fProgressLastPercent = fPercent
			ulProgressLastMax = ulMax
			ulProgressLastTime = ulTime
			print(string.format("%d%% (%d/%d)", fPercent, ulCnt, ulMax))
	end
	return true
end


function default_callback_message(a,b)
	if type(a)=="string" then
		local strCnt, strMax = string.match(a, "%% ([%x%X]+)/([%x%X]+)")
		if strCnt and strMax then
			local ulCnt = tonumber(strCnt, 16)
			local ulMax = tonumber(strMax, 16)
			if ulCnt and ulMax then
				return default_callback_progress(ulCnt, ulMax)
			end
		end
		io.write("[netx] ")
		local strLastChar = string.sub(a, -1)
		if strLastChar == "\r" or strLastChar == "\n" then
			io.write(a)
		else
			print(a)
		end
	end
	return true
end

function write_image(tPlugin, ulAddress, strData, fnCallbackProgress)
	return tPlugin:write_image(ulAddress, strData, fnCallbackProgress or default_callback_progress, strData:len())
end

function read_image(tPlugin, ulAddress, ulSize, fnCallbackProgress)
	return tPlugin:read_image(ulAddress, ulSize, fnCallbackProgress or default_callback_progress, ulSize)
end

function call(tPlugin, ulExecAddress, ulParameterAddress, fnCallbackMessage)
	return tPlugin:call(ulExecAddress, ulParameterAddress, fnCallbackMessage or default_callback_message, 2)
end

-----------------------------------------------------------------------------
--                    Downloading the flasher
-----------------------------------------------------------------------------

-- map chip type to flasher
local chiptyp2name = {
	[romloader.ROMLOADER_CHIPTYP_NETX500]          = "netx500",
	[romloader.ROMLOADER_CHIPTYP_NETX100]          = "netx500",
	[romloader.ROMLOADER_CHIPTYP_NETX50]           = "netx50",
	[romloader.ROMLOADER_CHIPTYP_NETX10]           = "netx10",
	[romloader.ROMLOADER_CHIPTYP_NETX56]           = "netx56",
	[romloader.ROMLOADER_CHIPTYP_NETX56B]          = "netx56",
	[romloader.ROMLOADER_CHIPTYP_NETX4000RELAXED] = "netx4000_relaxed",
	[romloader.ROMLOADER_CHIPTYP_NETX90MPW]       = "netx90_mpw",
}

-- *adapted for sqi test*
-- prefix must include a trailing backslash if it's a directory
function get_flasher_binary_path(iChiptype, strPathPrefix, fDebug)
	local strNetxName = chiptyp2name[iChiptype]
	local strDebug = fDebug and "_debug" or ""
	local strPrefix = strPathPrefix or ""
	
	if not strNetxName then
		error("Unknown chiptyp! " .. tostring(iChiptype))
	end
	
	local strPath = strPrefix .. "netx4000_sqitest.bin"
	return strPath
end


local function get_dword(strData, ulOffset)
	return strData:byte(ulOffset) + strData:byte(ulOffset+1)*0x00000100 + strData:byte(ulOffset+2)*0x00010000 + strData:byte(ulOffset+3)*0x01000000
end


-- Extract header information from the flasher binary
-- information about code/exec/buffer addresses
function get_flasher_binary_attributes(strData)
	local aAttr = {}
	
	-- Get the load and exec address from the binary.
	aAttr.ulLoadAddress = get_dword(strData, ${OFFSETOF_FLASHER_VERSION_STRUCT_pulLoadAddress} + 1)
	aAttr.ulExecAddress = get_dword(strData, ${OFFSETOF_FLASHER_VERSION_STRUCT_pfnExecutionAddress} + 1)
	aAttr.ulParameter   = get_dword(strData, ${OFFSETOF_FLASHER_VERSION_STRUCT_pucBuffer_Parameter} + 1)
	aAttr.ulDeviceDesc  = get_dword(strData, ${OFFSETOF_FLASHER_VERSION_STRUCT_pucBuffer_DeviceDescription} + 1)
	aAttr.ulBufferAdr   = get_dword(strData, ${OFFSETOF_FLASHER_VERSION_STRUCT_pucBuffer_Data} + 1)
	aAttr.ulBufferEnd   = get_dword(strData, ${OFFSETOF_FLASHER_VERSION_STRUCT_pucBuffer_End} + 1)
	aAttr.ulBufferLen   = aAttr.ulBufferEnd - aAttr.ulBufferAdr

	-- Show the information:
	print(string.format("parameter:          0x%08x", aAttr.ulParameter))
	print(string.format("device description: 0x%08x", aAttr.ulDeviceDesc))
	print(string.format("buffer start:       0x%08x", aAttr.ulBufferAdr))
	print(string.format("buffer end:         0x%08x", aAttr.ulBufferEnd))

	return aAttr
end


-- download binary to netX. Extracts and returns the header information.
-- Download a netx binary.
-- Returns the binary's attribute list.
function download_netx_binary(tPlugin, strData, fnCallbackProgress)
	local aAttr = get_flasher_binary_attributes(strData)
	print(string.format("downloading to 0x%08x", aAttr.ulLoadAddress))
	write_image(tPlugin, aAttr.ulLoadAddress, strData, fnCallbackProgress)
	-- tPlugin:write_image(aAttr.ulLoadAddress, strData, fnCallbackProgress, string.len(strData))
	
	return aAttr
end

-- Download flasher.
-- - Load the flasher binary according to the chip type the
--    plugin is connected to
-- - Extract header information from the flasher
--   (static information about code/exec/buffer addresses)
-- - Download the flasher to the specified address

-- tPlugin plugin object with an active connection
-- strPrefix path to flasher binaries
-- fnCallbackProgress is a function to call while downloading the flasher.
--   This parameter is optional. The default is to print a simple progress
--   message to stdout.

--   The function must accept 2 parameters:
--    1) the number of processed bytes
--    2) the total number of bytes
--   The function must return one boolean. A value of 'true' continues the
--   download operation, while a value of 'false' cancels the download.
--
-- Returns flasher attributes (parameter address, buffer address etc.)



function download(tPlugin, strPrefix, fnCallbackProgress)
	local iChiptype = tPlugin:GetChiptyp()
	local fDebug = false
	local strPath = get_flasher_binary_path(iChiptype, strPrefix, fDebug)
	local strFlasherBin, strMsg = muhkuh.load(strPath)
	assert(strFlasherBin, strMsg)

	local aAttr = get_flasher_binary_attributes(strFlasherBin)
	aAttr.strBinaryName = strFlasherBin
	
	print(string.format("downloading to 0x%08x", aAttr.ulLoadAddress))
	write_image(tPlugin, aAttr.ulLoadAddress, strFlasherBin, fnCallbackProgress)
	
	return aAttr
end


-- set the buffer area (when using SDRAM as a buffer, for instance)
function set_buffer_area(aAttr, ulBufferAdr, ulBufferLen)
	aAttr.ulBufferAdr   = ulBufferAdr
	aAttr.ulBufferEnd   = ulBufferAdr + ulBufferLen
	aAttr.ulBufferLen   = ulBufferLen
end



-----------------------------------------------------------------------------
--                    Calling the flasher
-----------------------------------------------------------------------------



-- download parameters to netX
local function set_parameterblock(tPlugin, ulAddress, aulParameters, fnCallbackProgress)

	local strBin = ""
	for i,v in ipairs(aulParameters) do
		strBin = strBin .. string.char( bit.band(v,0xff), bit.band(bit.rshift(v,8),0xff), bit.band(bit.rshift(v,16),0xff), bit.band(bit.rshift(v,24),0xff) )
	end
	write_image(tPlugin, ulAddress, strBin, fnCallbackProgress) 
end

-- Stores parameters in netX memory, calls the flasher and returns the result value
-- 0 = success, 1 = failure
function callFlasher(tPlugin, aAttr, aulParams, fnCallbackMessage, fnCallbackProgress)
	fnCallbackMessage = fnCallbackMessage or default_callback_message
	fnCallbackProgress = fnCallbackProgress or default_callback_progress
	
	-- set the parameters
	local aulParameter = {}
	aulParameter[1] = 0xffffffff                 -- placeholder for return vallue, will be 0 if ok
	aulParameter[2] = aAttr.ulParameter+0x0c     -- pointer to actual parameters
	aulParameter[3] = 0x00000000                 -- unused
	                                             -- extended parameters
	aulParameter[4] = FLASHER_INTERFACE_VERSION  -- set the parameter version
	for i=1, #aulParams do
		aulParameter[4+i] = aulParams[i]     -- actual parameters for the particular function
	end

	set_parameterblock(tPlugin, aAttr.ulParameter, aulParameter, fnCallbackProgress)
	
	-- call
	call(tPlugin, aAttr.ulExecAddress, aAttr.ulParameter, fnCallbackMessage) 
	
	-- get the return value (ok/failed)
	-- any further return values must be read by the calling function
	ulValue = tPlugin:read_data32(aAttr.ulParameter+0x00)
	print(string.format("call finished with result 0x%08x", ulValue))
	return ulValue
end



-----------------------------------------------------------------------------
--                  Detecting flash 
-----------------------------------------------------------------------------


-- check if a device is available on tBus/ulUnit/ulChipSelect
function sqitest(tPlugin, aAttr, tBus, ulUnit, ulChipSelect, fnCallbackMessage, fnCallbackProgress, atParameter)
	local aulParameter
	atParameter = atParameter or {}
	
	
	if tBus==BUS_Spi then
		-- Set the initial SPI speed. The default is 1000kHz (1MHz).
		local ulInitialSpeed = atParameter.ulInitialSpeed
		ulInitialSpeed = ulInitialSpeed or 1000
		
		-- Set the maximum SPI speed. The default is 25000kHz (25MHz).
		local ulMaximumSpeed = atParameter.ulMaximumSpeed
		ulMaximumSpeed = ulMaximumSpeed or 25000
		
		-- Set the idle configuration. The default is all lines driving 1.
		local ulIdleCfg = atParameter.ulIdleCfg
		ulIdleCfg = ulIdleCfg or (MSK_SQI_CFG_IDLE_IO1_OE + MSK_SQI_CFG_IDLE_IO1_OUT
		                        + MSK_SQI_CFG_IDLE_IO2_OE + MSK_SQI_CFG_IDLE_IO2_OUT
		                        + MSK_SQI_CFG_IDLE_IO3_OE + MSK_SQI_CFG_IDLE_IO3_OUT)
		
		-- Set the SPI mode. The default is 3.
		local ulSpiMode = atParameter.ulSpiMode
		ulSpiMode = ulSpiMode or 3
		
		-- Set the MMIO configuration. The default is 0xffffffff (no MMIO pins).
		local ulMmioConfiguration = atParameter.ulMmioConfiguration
		ulMmioConfiguration = ulMmioConfiguration or 0xffffffff
		
		local ulFlashOffset = atParameter.ulOffset or 0
		local ulCmpDataSize =  atParameter.strCmpData:len()
		local pucDest = aAttr.ulBufferAdr 
		local pucCmpData = aAttr.ulBufferAdr + ulCmpDataSize

		aulParameter =
		{
			OPERATION_MODE_Sqitest,                -- operation mode: sqitest
			tBus,                                 -- the bus
			ulUnit,                               -- unit
			ulChipSelect,                         -- chip select
			ulInitialSpeed,                       -- initial speed in kHz
			ulMaximumSpeed,                       -- maximum allowed speed in kHz
			ulIdleCfg,                            -- idle configuration
			ulSpiMode,                            -- mode
			ulMmioConfiguration,                  -- MMIO configuration
			
			ulFlashOffset,                        -- offset in flash to read from,
			ulCmpDataSize,                        -- number of bytes to read,
			pucDest,                              -- dest address to read to,
			pucCmpData,                           -- data to compare with
		}
		
		-- Download the 2 bit SPI test data
		write_image(tPlugin, pucCmpData, atParameter.strCmpData)
	
	else
		error("Unknown bus: " .. tostring(tBus))
	end
	
	 
	local ulValue = callFlasher(tPlugin, aAttr, aulParameter, fnCallbackMessage, fnCallbackProgress)
	return ulValue == 0
end


