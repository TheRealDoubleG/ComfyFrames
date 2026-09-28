local ADDON_NAME=...

ComfyFrames=ComfyFrames or {}
local A=ComfyFrames

A.name=ADDON_NAME or "ComfyFrames"
A.version="0.1"
A.buildDate="28.09.2026"
A.status="Beta"
A.gameVersion="WoW Forever 1.60.1"
A.interface=16001
A.targetBuild="70009"
A.author="TheRealDoubleG"
A.discord="the.real.double.g"
A.github="https://github.com/TheRealDoubleG/ComfyFrames"

local defaults={
 enabled=true,
 testMode=false,
 unlocked=false,
 style={
   font="Fonts\\FRIZQT__.TTF",
   texture="Interface\\TargetingFrame\\UI-StatusBar",
   classColors=true,
   healthColor="3CBF63",
   powerColor="3578D4",
   backgroundColor="171717",
   incomingHealColor="57E38A",
   absorbColor="61B5FF",
   borderColor="555555",
 },
 display={healthText=true,powerText=false,incomingHeal=true,absorb=true},
 units={
   player={enabled=true,width=230,height=52,x=-260,y=-155,fontSize=12,showPower=true},
   target={enabled=true,width=230,height=52,x=260,y=-155,fontSize=12,showPower=true},
   targettarget={enabled=true,width=155,height=34,x=260,y=-215,fontSize=10,showPower=false},
   focus={enabled=true,width=200,height=44,x=360,y=60,fontSize=11,showPower=true},
   pet={enabled=true,width=155,height=34,x=-260,y=-215,fontSize=10,showPower=true},
 },
 party={enabled=true,width=190,height=42,x=-430,y=210,fontSize=11,showPower=true,showRole=true,rangeFade=true,includePlayer=true,spacing=5},
 raid={enabled=true,width=112,height=34,x=250,y=315,fontSize=10,showPower=false,showRole=true,rangeFade=true,columns=5,spacing=3},
 optionsWindow={point="CENTER",relativePoint="CENTER",x=0,y=20},
 ui={windowLocked=false,windowOpacity=100,showWindowBorder=true,backgroundAlpha=92},
}
A.defaults=defaults

local function Copy(src)
 if type(src)~="table" then return src end
 local out={}; for k,v in pairs(src) do out[k]=Copy(v) end; return out
end

function A:Print(msg)
 if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd200ComfyFrames:|r "..tostring(msg)) end
end

function A:GetClientBuildInfo()
 if not GetBuildInfo then return "?","?","?",nil end
 local a,b,c,d=GetBuildInfo(); return tostring(a or "?"),tostring(b or "?"),tostring(c or "?"),tonumber(d)
end

A.afterCombat=A.afterCombat or {}

function A:AfterCombat(key,fn)
 if type(InCombatLockdown)=="function" and InCombatLockdown() then
   self.afterCombat[key or tostring(fn)]=fn
   return false
 end
 local ok,err=pcall(fn)
 if not ok then self:Print(err) end
 return ok
end

function A:FlushAfterCombat()
 local queued=self.afterCombat
 self.afterCombat={}
 for _,fn in pairs(queued or {}) do
   local ok,err=pcall(fn)
   if not ok then self:Print(err) end
 end
end

function A:InitializeDB()
 if self.InitializeProfileStorage then
   self:InitializeProfileStorage(defaults,"ComfyFramesDB")
 else
   ComfyFramesDB=type(ComfyFramesDB)=="table" and ComfyFramesDB or Copy(defaults)
   self.db=ComfyFramesDB
 end
end

function A:ApplyPreset(key)
 if not self.db then return end
 if key=="minimal" then
   self.db.units.focus.enabled=false; self.db.units.pet.enabled=false; self.db.units.targettarget.enabled=true
   self.db.party.enabled=false; self.db.raid.enabled=false
   self.db.display.incomingHeal=false; self.db.display.absorb=false
 elseif key=="healer" then
   self.db.party.enabled=true; self.db.raid.enabled=true
   self.db.party.width=210; self.db.party.height=48; self.db.raid.width=120; self.db.raid.height=38
   self.db.display.incomingHeal=true; self.db.display.absorb=true
 elseif key=="raid" then
   self.db.party.enabled=false; self.db.raid.enabled=true; self.db.raid.columns=5
   self.db.display.incomingHeal=true; self.db.display.absorb=true
 else
   for k,v in pairs(defaults.units) do for kk,vv in pairs(v) do self.db.units[k][kk]=vv end end
   for k,v in pairs(defaults.party) do self.db.party[k]=v end
   for k,v in pairs(defaults.raid) do self.db.raid[k]=v end
   for k,v in pairs(defaults.display) do self.db.display[k]=v end
 end
 if self.ApplyAll then self:ApplyAll() end
 if self.RefreshOptions then self:RefreshOptions() end
end

SLASH_COMFYFRAMES1="/comfyframes"
SLASH_COMFYFRAMES2="/cf"
SlashCmdList.COMFYFRAMES=function(msg)
 msg=tostring(msg or ""):lower():match("^%s*(.-)%s*$")
 if msg=="test" then
   A.db.testMode=not A.db.testMode
   if A.ApplyTestMode then A:ApplyTestMode() end
 elseif msg=="unlock" then A:SetUnlocked(true)
 elseif msg=="lock" then A:SetUnlocked(false)
 elseif msg=="reset" then A:ResetPositions()
 else if A.ShowOptions then A:ShowOptions() end end
end

local event=CreateFrame("Frame")
event:RegisterEvent("ADDON_LOADED")
event:RegisterEvent("PLAYER_LOGIN")
event:RegisterEvent("PLAYER_REGEN_ENABLED")
event:SetScript("OnEvent",function(_,ev,arg1)
 if ev=="ADDON_LOADED" and arg1==A.name then
   A:InitializeDB()
   if A.InitializeFrames then A:InitializeFrames() end
   if A.InitializeGroups then A:InitializeGroups() end
   if A.InitializeOptions then A:InitializeOptions() end
   A:Print(A:T("LOADED").." v"..A.version)
 elseif ev=="PLAYER_LOGIN" then
   if A.ApplyAll then A:ApplyAll() end
 elseif ev=="PLAYER_REGEN_ENABLED" then
   A:FlushAfterCombat()
 end
end)
