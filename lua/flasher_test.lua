local M = {}

---------------------------------------------------------------------------
-- Copyright (C) 2019 Hilscher Gesellschaft für Systemautomation mbH
--
-- Description:
--   flasher_test.lua: flasher test routines
--
---------------------------------------------------------------------------

local tFlasher = require("flasher")

-- local m_logMsgFile = nil
local m_logMsgFile = "flasher_test.log"

local function log_printf_fallback(...)
	local strMsg = string.format(...)
	print(strMsg)
	if m_logMsgFile then
		local fd = io.open(m_logMsgFile, "a+")
		assert(fd, "Could not open log file")
		fd:write(strMsg)
		fd:write("\n")
		fd:close()
	end
end

-- Number of random data segments to add
local iNumAddSegments = 100

-- Limit the reported device size (size of the test area) to 128 MB.
local ulDeviceSizeMax = 0x8000000

--========================================================================
--                      interface to flasher.lua
--========================================================================

-- Interface to the actual flash functions.
-- Generally, the routines return either true or false and an error message.
-- Read routines return the data or nil and an error message.
-- isErased returns true or false and an error message.
--
-- fOk, strMsg      init()            -- open plugin, download flasher, detect chip etc.
--
-- ulSize           getDeviceSize()   -- returns chip size in bytes
-- ulBusWidth       getBusWidth()     -- returns 1, 2 or 4
--
-- fOk, strMsg      flash(ulOffset, strData)
-- fOk, strMsg      verify(ulOffset, strData)
-- strData, strMsg  read(ulOffset, ulSize)   -- returns data or nil and an error message
-- fOk, strMsg      erase(ulOffset, ulSize)
-- fOk, strMsg      isErased(ulOffset, ulSize)
--
-- strData, strMsg  readChip()
-- fOK, strMsg      eraseChip()
-- fOk, strMsg      isChipErased()


local flasher_interface = {
	-- private:
	tPlugin = nil,
	a_attr = nil,
	iBus = nil,
	iUnit = nil,
	iChipSelect =nil,
}

function flasher_interface:configure(tPlugin, strFlasherPath, iBus, iUnit, iChipSelect, bCompMode, strSecureOption)
	self.tPlugin = tPlugin
	self.strFlasherPath = strFlasherPath
	self.iBus = iBus
	self.iUnit = iUnit
	self.iChipSelect = iChipSelect
	self.bCompMode = bCompMode
	self.strSecureOption = strSecureOption
end

function flasher_interface:init()
	if self.iBus == tFlasher.BUS_IFlash then
		error("This test is not suitable to test intflash. Write chunks may collide in 16 byte pages.")
	end

	print("Downloading flasher binary")
	self.aAttr = tFlasher.download(
	self.tPlugin,
	self.strFlasherPath,
	self.fnCallbackProgress,
	self.bCompMode,
	self.strSecureOption
	)
	if not self.aAttr then
		return false, "Error while downloading flasher binary"
	end

	-- check if the selected flash is present
	print("Detecting flash device")
	local fOk = tFlasher.detect(
		self.tPlugin, self.aAttr,
		self.iBus, self.iUnit, self.iChipSelect,
		self.fnCallbackMessage, self.fnCallbackProgress
		)
	if not fOk then
		return false, "Failed to get a device description!"
	end

	return true
end

function flasher_interface.finish()
end

function flasher_interface:getDeviceSize()
	local ulSize = tFlasher.getFlashSize(
		self.tPlugin, self.aAttr,
		self.fnCallbackMessage, self.fnCallbackProgress)

	if ulSize then
		if ulSize > ulDeviceSizeMax then
			ulSize = ulDeviceSizeMax
		end
		return ulSize
	else
		return nil, "Failed to get device size"
	end
end

function flasher_interface:getBus()
	return self.iBus
end

function flasher_interface:getBusWidth()
	if self.iBus == tFlasher.BUS_Parflash then
		return 2 -- 1 or 2 or 4
	elseif self.iBus == tFlasher.BUS_Spi then
		return 1
	elseif self.iBus == tFlasher.BUS_IFlash then
		return 4
	elseif self.iBus == tFlasher.BUS_SDIO then
		return 1
	end
end

function flasher_interface:getEmptyByte()
	if self.iBus == tFlasher.BUS_Parflash then
		return 0xff
	elseif self.iBus == tFlasher.BUS_Spi then
		return 0xff
	elseif self.iBus == tFlasher.BUS_IFlash then
		return 0xff
	elseif self.iBus == tFlasher.BUS_SDIO then
		return 0x00
	end
end

function flasher_interface:flash(ulOffset, strData)
	return tFlasher.flashArea(
		self.tPlugin, self.aAttr,
		ulOffset, strData,
		self.fnCallbackMessage, self.fnCallbackProgress)
end

function flasher_interface:verify(ulOffset, strData)
	return tFlasher.verifyArea(
		self.tPlugin, self.aAttr,
		ulOffset, strData,
		self.fnCallbackMessage, self.fnCallbackProgress)
end

function flasher_interface:read(ulOffset, ulSize)
	return tFlasher.readArea(
		self.tPlugin, self.aAttr,
		ulOffset, ulSize,
		self.fnCallbackMessage, self.fnCallbackProgress)
end

function flasher_interface:erase(ulOffset, ulSize)
	return tFlasher.eraseArea(
		self.tPlugin, self.aAttr,
		ulOffset, ulSize,
		self.fnCallbackMessage, self.fnCallbackProgress)
end

function flasher_interface:isErased(ulOffset, ulSize)
	local fIsErased = tFlasher.isErased(
		self.tPlugin, self.aAttr, ulOffset, ulOffset + ulSize,
		self.fnCallbackMessage, self.fnCallbackProgress)

	return fIsErased, fIsErased and "The area is empty" or "The area is not empty"
end

function flasher_interface:eraseChip()
	return self:erase(0, self:getDeviceSize())
end

function flasher_interface:readChip()
	return self:read(0, self:getDeviceSize())
end

function flasher_interface:isChipErased()
	return self:isErased(0, self:getDeviceSize())
end

M.flasher_interface = flasher_interface

--========================================================================
--                           Helper routines
--========================================================================


local function printf(...) print(string.format(...)) end

-- random string
local function getRandomData(iSize)
	local acBytes = {}
	for i=1, iSize do
		acBytes[i] = string.char(math.random(0, 255))
	end
	return table.concat(acBytes)
end


-- randomly re-order the elements of l
-- l is a list with integer keys 1..n
-- usage: l = reorder_randomly(l)
local function reorder_randomly(l)
	local l2 = {}
	local iPos
	for iLen=#l, 1, -1 do
		iPos = math.random(1, iLen)
		table.insert(l2, l[iPos])
		table.remove(l, iPos)
	end
	return l2
end


-- insert a random segment in unused space.
-- segments must be ordered by offset and non-overlapping
-- iWordSize: round addresses to 1/2/4 bytes
-- returns true if a segment was inserted, false otherwise

local function insert_random_segment(atSegments, ulDeviceSize, iWordSize)
	-- get a random position
	-- the new segment is inserted between atSegments[iPos] and atSegments[iPos+1]
	local iPos = math.random(0, #atSegments)

	-- get the inter-segment space at this position
	local offset   -- 0-based offset of the inter-segment space
	local size     -- size of the inter-segment space

	if #atSegments == 0 then
		offset = 0
		size = ulDeviceSize
	elseif iPos == 0 then
		offset = 0
		size = atSegments[1].offset
	elseif iPos == #atSegments then
		offset = atSegments[iPos].offset + atSegments[iPos].size
		size = ulDeviceSize - offset
	else
		offset = atSegments[iPos].offset + atSegments[iPos].size
		size = atSegments[iPos+1].offset - offset
	end

	if size > 0 then
		local offset1 = math.random(offset, offset+size-1)  -- start addr
		local offset2 = math.random(offset1, offset+size-1) -- end addr (incl)

		offset1 = offset1 - (offset1 % iWordSize)
		offset2 = offset2 - (offset2 % iWordSize) + (iWordSize-1)

		local size1 = offset2 - offset1 + 1

		-- Only add segments that are bigger than the minimum size
		if size1 < iWordSize then
			return false

		-- Limit segment size to 1MiB (0x100000) to avoid performance issues
		elseif size1 > 0x100000 then
			size1 = size1 % 0x100000
		end

		printf("0x%08x+0x%08x --> 0x%08x+0x%08x", offset, size, offset1, size1)
		local tSegment = {offset = offset1, size = size1}

		table.insert(atSegments, iPos+1, tSegment)
		return true

	else
		return false
	end
end


--========================================================================
--                           Test
--========================================================================


function M.testFlasher(tFlasherInterface, fnLogPrintf)

	tFlasherInterface = tFlasherInterface or flasher_interface
	local log_printf = fnLogPrintf or log_printf_fallback

	-- init flasher
	local fOk, strMsg = tFlasherInterface:init()
	assert(fOk, strMsg)

	local ulDeviceSize = tFlasherInterface:getDeviceSize()

	local bEmptyByte = tFlasherInterface:getEmptyByte()

	-- Detect if a NetX90 is connected and the internal flash is targeted (iBus = 2)
	-- Will use different segment adresses to avoid problems with CRC generation
	local tFlasherHelper = require 'flasher_helper'
	local tPlugin, strMsg = tFlasherHelper.getPlugin(tFlasherInterface.aArgs["strPluginName"],
		nil, tFlasherInterface.aArgs["atPluginOptions"])
	tPlugin:Connect()
	local iChiptype = tPlugin:GetChiptyp()
	tPlugin:Disconnect()
	local netX90iFlashDetected =
		(iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90
		or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90A
		or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90B
		or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90C
		or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90D
		or iChiptype == romloader.ROMLOADER_CHIPTYP_NETX90_MPW)
		and tFlasherInterface.aArgs.iBus == 2

	-- for serial flash
	local atSegments_1={
		{offset = 0, size = 12345},
		{offset = 0x10000, size = 0x10000},
		{offset = 0x30001, size = 0x10000},
		{offset = 0x50002, size = 0x10000},
		{offset = 0x70003, size = 0x10000},
		{offset = 0x90004, size = 0x10001},
		{offset = 0xb0004, size = 0x10002},
		{offset = 0xd0004, size = 0x10003},

		{offset = 0x20000, size = 1},
		{offset = 0x21004, size = 2},
		{offset = 0x22008, size = 3},

		{offset = 0x23000, size = 1},
		{offset = 0x23210, size = 1},

		{offset = ulDeviceSize - 12345, size = 12345},
	}

	-- for 16 bit parflash:
	-- offset/size must be multiples of bus width
	local atSegments_2={
		{offset = 0, size = 12346},
		{offset = 0x10000, size = 0x10000},
		{offset = 0x30002, size = 0x10000},
		{offset = 0x50002, size = 0x10000},
		{offset = 0x70004, size = 0x10000},
		{offset = 0x90004, size = 0x10000},
		{offset = 0xb0004, size = 0x10002},
		{offset = 0xd0004, size = 0x10004},

		{offset = 0x20000, size = 2},
		{offset = 0x21004, size = 4},
		{offset = 0x22008, size = 6},

		{offset = 0x23000, size = 2},
		{offset = 0x23210, size = 2},

		{offset = ulDeviceSize - 12346, size = 12346},
	}

	-- for 32 bit parflash:
	-- offset/size must be multiples of bus width
	local atSegments_4={
		{offset = 0, size = 12348},
		{offset = 0x10000, size = 0x10000},
		{offset = 0x30004, size = 0x10000},
		{offset = 0x50008, size = 0x10000},
		{offset = 0x6000c, size = 0x10000},

		{offset = 0x20000, size = 4},
		{offset = 0x21004, size = 8},
		{offset = 0x2200c, size = 12},

		{offset = 0x23000, size = 4},
		{offset = 0x23210, size = 4},

		{offset = ulDeviceSize - 12348, size = 12348},
	}

	-- for NetX90 iFlash
	-- offset/size must be multiples of 8 because of 8Byte-CRC
	local atSegments_8={
		{offset = 0, size = 12344},
		{offset = 0x10000, size = 0x10000},
		{offset = 0x30000, size = 0x10000},
		{offset = 0x50008, size = 0x10000},
		{offset = 0x60008, size = 0x10000},

		{offset = 0x20000, size = 8},
		{offset = 0x21008, size = 8},
		{offset = 0x22008, size = 16},

		{offset = 0x23000, size = 8},
		{offset = 0x23210, size = 8},

		{offset = ulDeviceSize - 12344, size = 12344},
	}

	-- select the segments list according to the flash type
	local atSegments
	local iBusWidth = tFlasherInterface:getBusWidth()
	if netX90iFlashDetected then
		atSegments = atSegments_8
		iBusWidth = 8
	elseif iBusWidth==1 then
		atSegments = atSegments_1
	elseif iBusWidth==2 then
		atSegments = atSegments_2
	elseif iBusWidth==4 then
		atSegments = atSegments_4
	end

	-- add random segments
	table.sort(atSegments, function(a, b) return a.offset<b.offset end)
	math.randomseed(os.time())
	local iSize = #atSegments

	log_printf("")
	log_printf("Create random segments:")
	while #atSegments < iSize + iNumAddSegments do
		insert_random_segment(atSegments, ulDeviceSize, iBusWidth)
	end

	log_printf("")
	log_printf("Segments:")
	for iSegment, tSegment in ipairs(atSegments) do
		local offset = tSegment.offset
		local size = tSegment.size
		log_printf("%d 0x%08x-0x%08x size 0x%x", iSegment, offset, offset+size-1, size)
	end

	-- reorder
	atSegments = reorder_randomly(atSegments)

	log_printf("")
	log_printf("Randomly reordered segments:")
	for iSegment, tSegment in ipairs(atSegments) do
		local offset = tSegment.offset
		local size = tSegment.size
		log_printf("%d 0x%08x-0x%08x size 0x%x", iSegment, offset, offset+size-1, size)
	end


	-- fill segments with data
	for _, tSegment in ipairs(atSegments) do
		tSegment.data = tSegment.data or getRandomData(tSegment.size)
	end


	-- erase
	log_printf("")
	log_printf("Erase whole flash")
	fOk, strMsg = tFlasherInterface:eraseChip()
	log_printf("Result: %s %s", tostring(fOk), tostring(strMsg))
	assert(fOk, strMsg)

	-- flash the segments
	log_printf("")
	log_printf("Flash the segments")
	for iSegment, tSegment in ipairs(atSegments) do
		log_printf("Flashing Segment %d  offset:0x%08x  size: %d", iSegment, tSegment.offset, tSegment.size)
		fOk, strMsg = tFlasherInterface:flash(tSegment.offset, tSegment.data)
		log_printf("Flashed Segment %d  offset:0x%08x  size: %d", iSegment, tSegment.offset, tSegment.size)
		log_printf("Result: %s %s", tostring(fOk), tostring(strMsg))
		assert(fOk)
	end

	-- verify the segments
	log_printf("")
	log_printf("Verify the segments")
	for iSegment, tSegment in ipairs(atSegments) do
		log_printf("Verifying Segment %d  offset:0x%08x  size: %d", iSegment, tSegment.offset, tSegment.size)
		fOk, strMsg = tFlasherInterface:verify(tSegment.offset, tSegment.data)
		log_printf("Verified Segment %d  offset:0x%08x  size: %d", iSegment, tSegment.offset, tSegment.size)
		log_printf("Result: %s %s", tostring(fOk), tostring(strMsg))
		assert(fOk)
	end

	-- read back
	log_printf("")
	log_printf("Read back the segments")
	fOk = true
	for iSegment, tSegment in ipairs(atSegments) do
		log_printf("Reading Segment %d  offset:0x%08x  size: %d", iSegment, tSegment.offset, tSegment.size)
		local strData, strMsgRead = tFlasherInterface:read(tSegment.offset, tSegment.size)
		log_printf("Read Segment %d  offset:0x%08x  size: %d", iSegment, tSegment.offset, tSegment.size)

		assert(strData, strMsgRead or "Error reading segment")

		if strData == tSegment.data then
			log_printf("Segment %d equal", iSegment)
		else
			log_printf("Segment %d differs!", iSegment)
			fOk = false

			-- prints mismatching data for manual comparison
			local function printContentsInHex(str)
				local text = ""
				for i=1, #str do
					text = text .. string.format("%02x ", string.byte(str,i,i))
				end
				log_printf(text)
			end
			log_printf("Read (Hex):")
			printContentsInHex(strData)
			log_printf("Expected (Hex):")
			printContentsInHex(tSegment.data)
		end

	end
	assert(fOk, "Errors while reading segments")




	-- Read an image of the whole chip.
	-- Check that the data segments have been writen correctly
	-- and that the space in-between is empty (ff)

	-- Read image
	log_printf("")
	log_printf("Read image")
	local strImage = tFlasherInterface:readChip()
	log_printf("Image read")

	-- Compare the segments and check the space in-between
	log_printf("")
	log_printf("Compare the segments")
	table.sort(atSegments, function(a, b) return a.offset<b.offset end)

	for iSegment, tSegment in ipairs(atSegments) do
	log_printf("Compare Segment %d with image. offset:0x%08x  size: %d", iSegment, tSegment.offset, tSegment.size)
		local iStart = tSegment.offset + 1
		local iEnd   = tSegment.offset + tSegment.size
		local iNextStart

		local strData = strImage:sub(iStart, iEnd)
		assert(strData == tSegment.data, "Segment does not match")

		if iSegment < #atSegments then
			tSegment = atSegments[iSegment+1]
			iNextStart = tSegment.offset
		else
			iNextStart = ulDeviceSize
		end

		log_printf("Checking Range 0x%08x - 0x%08x", iEnd, iNextStart)
		for iPos = iEnd+1, iNextStart do
			assert(strImage:byte(iPos) == bEmptyByte, string.format("0x%08x non-empty", iPos))
		end

	end


	-- Erase the segments
	log_printf("")
	log_printf("Erase the segments")
	for iSegment, tSegment in ipairs(atSegments) do
		log_printf("Erasing Segment %d  offset:0x%08x  size: %d", iSegment, tSegment.offset, tSegment.size)
		fOk, strMsg = tFlasherInterface:erase(tSegment.offset, tSegment.size)
		log_printf("Erased Segment %d  offset:0x%08x  size: %d", iSegment, tSegment.offset, tSegment.size)
		log_printf("Result: %s %s", tostring(fOk), tostring(strMsg))
		assert(fOk)
	end

	-- the flash should now be empty
	log_printf("")
	log_printf("Check emptyness")
	fOk, strMsg = tFlasherInterface:isChipErased()
	log_printf("Empty: %s %s", tostring(fOk), tostring(strMsg))
	assert(fOk)

	return true, "Test completed"
end

return M
