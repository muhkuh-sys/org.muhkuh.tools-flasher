--[[
This version of the script is for inclusion in the CLI flasher. 
It contains some changes to make it compatible to the 
versions of romloader and tester_cli used in the flasher.

Changes for compatibility with Romloader: 
Added chip types net90C and netx90D to astrBinaryName

Changes for compatibility with old tester_cli.lua:
tester:fn() -> tester.fn()
tester:fn(...) -> tester.fn(nil, ...)
for mbin_write, mbin_execute, stdRead, stdWrite, stdCall

Return values:
asic_typ:               14  romloader chip type returned by plugin:get_chiptyp()
boot_mode:              2
strapping_options:      7
chip_id:                18  chip type from bootpins.atChipID as detected by the routine
size_of_unique_id_in_bits
unique_id

Values for chip_id that are relevant for netX 90:
bootpins.atChipID.unknown      - clock enable mask bits are cleared
bootpins.atChipID.NETX90       - either netX 90 MPW OR Rev0
bootpins.atChipID.NETX90B      - netX 90 Rev1
bootpins.atChipID.NETX90BPHYR3 - netX 90 Rev1 with PHY V3
bootpins.atChipID.NETX90C      - netX 90 Rev2 

Note: the routine always returns OK.
If the clock enable fails because the clock_enable_mask bits are cleared,
The routine returns OK and chip_id is == bootpins.atChipID.unknown
--]]


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
    'INPUT', -- 0: skip PHY setup
    'OUTPUT',
    'OUTPUT',
    'OUTPUT',
    'OUTPUT',
    'OUTPUT'
  }

  -- Skip the PHY setup when the routine is called via ethernet.
  if (tPlugin:GetTyp()=="romloader_eth") then
    aParameter[1] = 0 -- do not set up Phy
  else
    aParameter[1] = 1 -- set up Phy
  end

  local aAttr = tester.mbin_open(strNetxBinary, tPlugin)
  tester.mbin_debug(aAttr)
  tester.mbin_write(nil, tPlugin, aAttr)
  tester.mbin_set_parameter(tPlugin, aAttr, aParameter)
  local ulResult = tester.mbin_execute(nil, tPlugin, aAttr, aParameter)
  if ulResult~=0 then
    error('The test failed with return code:' .. ulResult)
  end

  -- Read the unique ID if there is one.
  local sizUniqueIdInBits = aParameter[5]
  local strUniqueId = ''
  if sizUniqueIdInBits>0 then
    -- Check for an upper limit.
    if sizUniqueIdInBits>2048 then
      error('Cowardly refusing to read more than 2048 bits.')
    end
    -- Get the size of the unique ID in bytes.
    local sizUniqueId = math.ceil(sizUniqueIdInBits / 8)

    -- Read the unique ID.
    strUniqueId = tester.stdRead(nil, tPlugin, aAttr.ulParameterStartAddress+0x0c+0x10, sizUniqueId)
  end

  local atResult = {
    asic_typ = tAsicTyp,
    boot_mode = aParameter[2],
    strapping_options = aParameter[3],
    chip_id = aParameter[4],
    size_of_unique_id_in_bits = sizUniqueIdInBits,
    unique_id = strUniqueId
  }

  return atResult
end

return BootPins
