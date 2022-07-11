-- This version of the script is for inclusion in the CLI flasher. 
-- It contains some changes to make it compatible to the 
-- versions of romloader and tester_cli used in the flasher.
-- 
-- Changes for compatibility with Romloader: 
-- Added chip types net90C and netx90D to astrBinaryName
-- 
-- Changes for compatibility with old tester_cli.lua:
-- tester:fn() -> tester.fn()
-- tester:fn(...) -> tester.fn(nil, ...)
-- for fn in mbin_write, mbin_execute, stdRead, stdWrite, stdCall

-- Removed reading the unique ID

local class = require 'pl.class'
local BootPins = class()

function BootPins:_init()
  self.romloader = require 'romloader'

  local atChipID = {
    ['unknown']                            = 0,
    ['NETX500']                            = 1,
    ['NETX100']                            = 2,
    ['NETX50']                             = 3,
    ['NETX10']                             = 4,
    ['NETX51A_NETX50_COMPATIBILITY_MODE']  = 5,
    ['NETX51B_NETX50_COMPATIBILITY_MODE']  = 6,
    ['NETX51A']                            = 7,
    ['NETX51B']                            = 8,
    ['NETX52A']                            = 9,
    ['NETX52B']                            = 10,
    ['NETX4000_RELAXED']                   = 11,
    ['NETX4000_FULL']                      = 12,
    ['NETX4000_SMALL']                     = 13,
    ['NETX90_MPW']                         = 14,
    ['NETX90']                             = 15,
    ['NETX90B']                            = 16,
    ['NETX90BPHYR3']                       = 17,
    ['NETX90C']                            = 18
  }
  self.atChipID = atChipID

  -- Build a reverse lookup table.
  local aulIdToChip = {}
  for strId, ulId in pairs(atChipID) do
    aulIdToChip[ulId] = strId
  end
  self.aulIdToChip = aulIdToChip

-- added netx90C/D to astrBinaryName
  self.astrBinaryName = {
    [romloader.ROMLOADER_CHIPTYP_NETX4000_RELAXED] = '4000',
    [romloader.ROMLOADER_CHIPTYP_NETX4000_FULL]    = '4000',
    [romloader.ROMLOADER_CHIPTYP_NETX4100_SMALL]   = '4000',
    [romloader.ROMLOADER_CHIPTYP_NETX500]          = '500',
    [romloader.ROMLOADER_CHIPTYP_NETX100]          = '500',
    [romloader.ROMLOADER_CHIPTYP_NETX90_MPW]       = '90_mpw',
    [romloader.ROMLOADER_CHIPTYP_NETX90]           = '90',
    [romloader.ROMLOADER_CHIPTYP_NETX90B]          = '90',
    [romloader.ROMLOADER_CHIPTYP_NETX90C]          = '90',
    [romloader.ROMLOADER_CHIPTYP_NETX90D]          = '90',
    [romloader.ROMLOADER_CHIPTYP_NETX56]           = '56',
    [romloader.ROMLOADER_CHIPTYP_NETX56B]          = '56',
    [romloader.ROMLOADER_CHIPTYP_NETX50]           = '50',
    [romloader.ROMLOADER_CHIPTYP_NETX10]           = '10'
--    [romloader.ROMLOADER_CHIPTYP_NETIOLA]          = 'IOL',
--    [romloader.ROMLOADER_CHIPTYP_NETIOLB]          = 'IOL'
  }
end



-- Read the boot pins from the netX.

function BootPins:read(tPlugin)
  -- Get the binary for the ASIC.
  local tAsicTyp = tPlugin:GetChiptyp()
  local strBinary = self.astrBinaryName[tAsicTyp]
  if strBinary==nil then
    error('Unknown chiptyp!')
  end
  local strNetxBinary = string.format('netx/bootpins_netx%s.bin', strBinary)

  -- Download the binary, execute it and get the results back.
  local aParameter = {
    'OUTPUT',
    'OUTPUT',
    'OUTPUT',
    'OUTPUT',
    'OUTPUT'
  }
	local aAttr = tester.mbin_open(strNetxBinary, tPlugin)
  tester.mbin_debug(aAttr)
  tester.mbin_write(nil, tPlugin, aAttr)
  tester.mbin_set_parameter(tPlugin, aAttr, aParameter)
  local ulResult = tester.mbin_execute(nil, tPlugin, aAttr, aParameter)
   
  -- Note: the routine always returns OK.
  -- If the clock enable fails because the clock_enable_mask bits are cleared,
  -- The routine returns OK and chip_id is == CHIPID_unknown 
  -- CHIPID_unknown - this is returned if the clock enable mask bits are cleared
  -- CHIPID_netX90 - either MPW OR Rev0
  -- CHIPID_netX90B - Rev1
  -- CHIPID_netX90C - Rev2
  -- CHIPID_netX90BPhyR3 - Rev1 with PHY v3
  if ulResult~=0 then
    error('The test failed with return code:' .. ulResult)
  end

-- asic_typ:       14
-- boot_mode :     2
-- strapping_options :     7
-- chip_id :       18
  local atResult = {
    -- chip type returned by plugin:get_chiptyp()
    asic_typ = tAsicTyp,

    boot_mode = aParameter[1],
    strapping_options = aParameter[2],
    -- chip type as detected by the routine
    chip_id = aParameter[3],
  }

  return atResult
end

return BootPins
