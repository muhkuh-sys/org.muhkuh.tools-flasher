-----------------------------------------------------------------------------
--   Script for flashing random data into specified area of the serial     --
--   flash.                                                                --
--                                                                         --
--   You need to secify the sections which shold be written by an input-   --
--   file as inputargument structured as followes:                         --
--   [0x000start, 0x00000end] #comment                                     --
--                                                                         --
-----------------------------------------------------------------------------

require("muhkuh_cli_init")
require("flasher")

if #arg~=1 then
  error("\n\n[FILE ERROR] No Filename \n\n")
end

strFileName = arg[1]
tFile = io.open(strFileName, "r")
if tFile == nil then 
 error("\n\n[FILE ERROR] Wrong filename \n\n")
end

tPlugin = tester.getCommonPlugin()
if not tPlugin then
  error("No plugin selected, nothing to do!")
end

-- Download the binary.
local aAttr = flasher.download(tPlugin, "netx/", progress)
-- Use SPI Flash CS0.
local fOk = flasher.detect(tPlugin, aAttr, flasher.BUS_Spi, 0, 0, ulDevDescAdr)
if not fOk then
  error("Failed to get a device description!")
end

-- Get the complete devicesize.
ulFlashSize = flasher.getFlashSize(tPlugin, aAttr, tester.callback, tester.callback_progress)
print(string.format("The device size is: 0x%08x", ulFlashSize))

-- Erase the complete device.
ulMemStart, ulMemEnd = flasher.getEraseArea(tPlugin, aAttr, 0, ulFlashSize)
if not ulMemStart then
  error("Failed to get erase areas!")
end

local fIsErased
print(string.format("Checking area 0x%08x-0x%08x...", ulMemStart, ulMemEnd))
fIsErased = flasher.isErased(tPlugin, aAttr, ulMemStart, ulMemEnd)
if fIsErased==nil then
  error("failed to check the area!")
end

if fIsErased==true then
  print("The area is already erased.")
else
  print("The area is not erased. Erasing it now...")
  local fIsOk = flasher.erase(tPlugin, aAttr, ulMemStart, ulMemEnd)
  if not fIsOk then
    error("Failed to erase the area!")
  end

  fIsErased = flasher.isErased(tPlugin, aAttr, ulMemStart, ulMemEnd)
  if not fIsErased then
    error("No error reported, but the area is not erased!")
  end
end

-----------------------------------------------------------------------------
-- getRandomSequence
-- could be optimized if we don't call random every time instead of hashing up one random
-----------------------------------------------------------------------------
local function getRandomSequence(iLength)
  tRandoms = {}
  for i=0, iLength do
    tRandoms[i] = string.char(math.random(255))
  end
  sRandoms = table.concat(tRandoms)
  return sRandoms;
end

-----------------------------------------------------------------------------
-- shrinkList
-- this could be cone more efficient if we only sort once --> 2 fcts
-----------------------------------------------------------------------------
local function shrinkList(tAdressSegments)
  --this pair is NOT in the listOfPair so it will not be recognized by sorting
  table.sort(tAdressSegments, function(a, b) return a < b end)

  --   Debugging
  --  print("\n")
  --  for key,value in pairs(tAdressSegments) do print("lop: key", key, "pair key", tAdressSegments[key], "pair value", tSegment[tAdressSegments[key]])end
  --  print("\n")

  tSegment[-1] = -1 -- we need this as dummy pair at start of the for loop
  ulOldStartAdr = -1 -- the startAdr of last memory segment

  local iIter = 1


  while iIter <= #tAdressSegments do
    if tonumber(tAdressSegments[iIter]) < tSegment[ulOldStartAdr] then

      print("[PARSER WARNING] Double writing memory in",  string.format("0x%2x", ulOldStartAdr), " - " , string.format("0x%2x", tSegment[tAdressSegments[iIter]]), "merging memory segments")
      --    merging fields
      if ulOldStartAdr ~= -1 then
        tSegment[ulOldStartAdr] = tSegment[tAdressSegments[iIter]]
        table.remove(tAdressSegments, iIter)
      else
        iIter = iIter + 1
      end
    else
      ulOldStartAdr = tAdressSegments[iIter]

      iIter = iIter + 1
    end
  end

  return tAdressSegments
end


-----------------------------------------------------------------------------
-- parseInputString
-----------------------------------------------------------------------------
local function parseInputString()
  local iErrorCounter = 0;
  --local tFile = assert(io.open(strFileName, "r"))  
  local tAdressSegments = {}
  tSegment = {}
  local iAdressSegmentIter = 1;
  for line in tFile:lines() do
    if string.sub(line, 1, 1) == '#' or line == '' or line == '\r' then

    else
      _, _, ulStartAdr, ulEndAdr = string.find(line,  "%[%s*0x(%x+)%s*,%s*0x(%x+)%s*%]%s*")
        print("ulStart: ", ulStartAdr, "\n")

        ulStartAdr = tonumber(ulStartAdr, 16)
        ulEndAdr = tonumber(ulEndAdr, 16)
        if(ulStartAdr > ulEndAdr) then
          print("[PARSER ERROR] Start is behind end --> skip entry: ", line, "\n")
          iErrorCounter = iErrorCounter + 1
        elseif(ulStartAdr > ulMemEnd or ulStartAdr < ulMemStart)  then
          print("[PARSER ERROR] Start Parameter out of memory range:", line, "adjusting to memory start\n")
          iErrorCounter = iErrorCounter + 1
        elseif(ulEndAdr > ulMemEnd) then
          print("[PARSER WARNING] End Parameter out of memory range:", line, "adjusting to memory end\n")
          tSegment[ulStartAdr] = ulMemEnd
          tAdressSegments[iAdressSegmentIter] = ulStartAdr
          iAdressSegmentIter = iAdressSegmentIter + 1
        else
          tSegment[ulStartAdr] = ulEndAdr
          tAdressSegments[iAdressSegmentIter] = ulStartAdr
          iAdressSegmentIter = iAdressSegmentIter + 1
        end
    end
  end
  tFile:close()

  if iErrorCounter > 0 then
    error(string.format("\n\n\n###Parsing ended with %i errors###\n\n", iErrorCounter))
  end

  tAdressSegments = shrinkList(tAdressSegments)

  -- Debugging
  --  print("\n")
  --  for key,value in pairs(tAdressSegments) do print("lop: key", key, "pair key", tAdressSegments[key], "pair value", tSegment[tAdressSegments[key]])end
  --  print("\n")

  return tAdressSegments
end

-----------------------------------------------------------------------------
-- main starts here
-----------------------------------------------------------------------------
tAdressSegments = parseInputString()
tPlugin = tester.getCommonPlugin()
if not tPlugin then
  error("No plugin selected, nothing to do!")
end

for iIter in pairs(tAdressSegments) do
  ulStartAdr = tAdressSegments[iIter]
  ulEndAdr = tSegment[ulStartAdr]
  ulLen = ulEndAdr - ulStartAdr
  strRandom = getRandomSequence(ulLen)
  flasher.flashArea(tPlugin, aAttr, ulStartAdr, strRandom,  tester.callback, tester.callback_progress);
end

print("")
print(" #######  ##    ## ")
print("##     ## ##   ##  ")
print("##     ## ##  ##   ")
print("##     ## #####    ")
print("##     ## ##  ##   ")
print("##     ## ##   ##  ")
print(" #######  ##    ## ")
print("")

-- Disconnect the plugin.
tester.closeCommonPlugin()

