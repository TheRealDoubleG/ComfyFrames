-- Stock Lua cannot create WoW secret booleans. Opaque sentinels verify native
-- forwarding/fallbacks; source and load-order checks prevent the old override bug.
local function read(path)
 local f = assert(io.open(path, "r")); local s = f:read("*a"); f:close(); return s
end
local toc = read("ComfyFrames.toc")
local groups = assert(toc:find("\nGroups.lua", 1, true))
assert(assert(toc:find("\nRangeSafe.lua", 1, true)) > groups)
local definitions = 0
for file in toc:gmatch("[^\r\n]+") do
 if file:match("%.lua$") then
  local source = read(file)
  for _ in source:gmatch("function A:UpdateRange%(") do definitions = definitions + 1 end
 end
end
assert(definitions == 1, "Range must have exactly one implementation")
assert(not read("Groups.lua"):find("v==false", 1, true))

ComfyFrames = {}
dofile("Groups.lua")
local A = ComfyFrames
local implementation = A.UpdateRange
-- These modules must never replace the implementation again.
dofile("Enhancements.lua")
CreateFrame = function()
 return {RegisterEvent=function() end, SetScript=function() end}
end
dofile("BlizzardFrames.lua")
dofile("RangeSafe.lua")
assert(A.UpdateRange == implementation)
A:UpdateRange() -- pre-initialization is safe

local secretInRange, secretChecked = {}, {}
local cases = 0
local function run(name, opts, expected, nativeExpected)
 cases = cases + 1
 local calls, nativeCalls = 0, 0
 local frame = {unit = opts.player and "player" or "party1"}
 function frame:SetAlpha(alpha) self.alpha = alpha end
 if not opts.noNative then
  function frame:SetAlphaFromBoolean(value, yes, no)
   nativeCalls = nativeCalls + 1
   assert(rawequal(value, secretInRange), name .. ": opaque value was changed")
   assert(yes == 1)
   if opts.nativeError then error("native unavailable") end
   self.alpha = no -- simulate out-of-range on the native side
  end
 end
 issecretvalue = function(value)
  if opts.detectorError then error("detector unavailable") end
  return rawequal(value, secretInRange) or rawequal(value, secretChecked)
 end
 if opts.noDetector then issecretvalue = nil end
 UnitInRange = function()
  calls = calls + 1
  if opts.apiError then error("range unavailable") end
  return opts.value, opts.checked
 end
 if opts.noAPI then UnitInRange = nil end
 A.db = {testMode = opts.testMode, party = {rangeFade = not opts.disabled, rangeFadeAlpha = opts.alpha}, raid = {rangeFade = true, rangeFadeAlpha = opts.alpha}}
 A.partyFrames = opts.raid and {} or {frame}
 A.raidFrames = opts.raid and {frame} or {}
 A:UpdateRange()
 assert(frame.alpha == expected, name .. ": wrong alpha " .. tostring(frame.alpha))
 assert(nativeCalls == (nativeExpected or 0), name .. ": wrong native calls")
 if opts.testMode or opts.disabled or opts.player or opts.noAPI then assert(calls == 0) end
end

run("in range", {value=true, checked=true}, 1)
run("out of range", {value=false, checked=true}, .45)
run("party opacity", {value=false, checked=true, alpha=20}, .2)
run("raid opacity", {value=false, checked=true, alpha=70, raid=true}, .7)
run("clamp opacity", {value=false, checked=true, alpha=150}, 1)
run("unknown", {checked=true}, 1)
run("not checked", {value=false, checked=false}, 1)
run("legacy single result", {value=false}, .45)
run("secret range", {value=secretInRange, checked=true, alpha=30}, .3, 1)
run("secret raid", {value=secretInRange, checked=true, alpha=65, raid=true}, .65, 1)
run("secret without helper", {value=secretInRange, checked=true, noNative=true}, 1)
run("native failure", {value=secretInRange, checked=true, nativeError=true}, 1, 1)
run("secret checked", {value=false, checked=secretChecked}, 1)
run("both secret", {value=secretInRange, checked=secretChecked}, 1)
run("missing detector", {value=secretInRange, checked=true, noDetector=true}, 1)
run("failed detector", {value=secretInRange, checked=true, detectorError=true}, 1)
run("API error", {apiError=true}, 1)
run("API missing", {noAPI=true}, 1)
run("test mode", {testMode=true}, 1)
run("disabled", {disabled=true}, 1)
run("player", {player=true}, 1)
print("PASS: " .. cases .. " range scenarios, TOC order and single implementation")
