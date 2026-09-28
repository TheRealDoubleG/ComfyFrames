ComfyFrames=ComfyFrames or {}
local A=ComfyFrames

A.unitFrames=A.unitFrames or {}
A.unitButtonListeners=A.unitButtonListeners or {}

local SINGLE={"player","target","targettarget","focus","pet"}

local UNIT_EVENTS={
 "UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_POWER_UPDATE","UNIT_MAXPOWER","UNIT_NAME_UPDATE",
 "UNIT_CONNECTION","UNIT_HEAL_PREDICTION","UNIT_ABSORB_AMOUNT_CHANGED","UNIT_AURA",
}

function A:RegisterUnitButtonListener(fn)
 if type(fn)~="function" then return end
 self.unitButtonListeners[#self.unitButtonListeners+1]=fn
 for _,frame in pairs(self.unitFrames) do pcall(fn,frame) end
 for _,frame in pairs(self.partyFrames or {}) do pcall(fn,frame) end
 for _,frame in pairs(self.raidFrames or {}) do pcall(fn,frame) end
end

function A:NotifyUnitButtonCreated(frame)
 for _,fn in ipairs(self.unitButtonListeners or {}) do pcall(fn,frame) end
end

function A:CreateMover(key,cfg,label)
 local m=CreateFrame("Frame","ComfyFramesMover_"..key,UIParent,"BackdropTemplate")
 m.key=key; m.cfg=cfg; m:SetSize(cfg.width,cfg.height); m:SetPoint("CENTER",UIParent,"CENTER",cfg.x,cfg.y)
 m:SetFrameStrata("DIALOG"); m:SetClampedToScreen(true); m:SetMovable(true); m:RegisterForDrag("LeftButton")
 m:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10})
 m:SetBackdropColor(0.15,0.55,0.85,0.25); m:SetBackdropBorderColor(0.3,0.76,0.97,0.8)
 m.label=m:CreateFontString(nil,"OVERLAY","GameFontNormal"); m.label:SetPoint("CENTER"); m.label:SetText(label or key)
 m:SetScript("OnDragStart",function(self)
   if InCombatLockdown() then A:Print(A:T("LOCKED_COMBAT")); return end
   if not A.db.unlocked then return end
   self:StartMoving()
 end)
 m:SetScript("OnDragStop",function(self)
   self:StopMovingOrSizing()
   local x,y=self:GetCenter(); local ux,uy=UIParent:GetCenter()
   if x and y and ux and uy then self.cfg.x=math.floor(x-ux+0.5); self.cfg.y=math.floor(y-uy+0.5) end
 end)
 m:Hide(); m:EnableMouse(false)
 return m
end

function A:CreateUnitButton(unit,key,cfg,parentMover)
 local f=CreateFrame("Button","ComfyFrame_"..key,UIParent,"SecureUnitButtonTemplate,BackdropTemplate")
 f.unit=unit; f.key=key; f.cfg=cfg
 f:SetAttribute("unit",unit); f:SetAttribute("type1","target"); f:RegisterForClicks("AnyUp")
 f:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
 f.bg=f:CreateTexture(nil,"BACKGROUND"); f.bg:SetAllPoints(f)

 f.health=CreateFrame("StatusBar",nil,f); f.power=CreateFrame("StatusBar",nil,f)
 f.incoming=CreateFrame("StatusBar",nil,f.health); f.absorb=CreateFrame("StatusBar",nil,f.health)
 f.incoming:SetPoint("TOPLEFT",f.health,"TOPLEFT"); f.incoming:SetPoint("TOPRIGHT",f.health,"TOPRIGHT"); f.incoming:SetHeight(3)
 f.absorb:SetPoint("BOTTOMLEFT",f.health,"BOTTOMLEFT"); f.absorb:SetPoint("BOTTOMRIGHT",f.health,"BOTTOMRIGHT"); f.absorb:SetHeight(3)

 f.name=f.health:CreateFontString(nil,"OVERLAY"); f.name:SetPoint("TOPLEFT",f.health,"TOPLEFT",5,-4); f.name:SetPoint("RIGHT",f.health,"RIGHT",-5,0); f.name:SetJustifyH("LEFT")
 f.healthText=f.health:CreateFontString(nil,"OVERLAY"); f.healthText:SetPoint("BOTTOMRIGHT",f.health,"BOTTOMRIGHT",-5,3)
 f.status=f.health:CreateFontString(nil,"OVERLAY"); f.status:SetPoint("CENTER")
 f.role=f.health:CreateFontString(nil,"OVERLAY"); f.role:SetPoint("TOPRIGHT",f.health,"TOPRIGHT",-4,-3)

 if parentMover then f:SetAllPoints(parentMover) end
 self:ApplyFrameStyle(f,cfg)

 for _,ev in ipairs(UNIT_EVENTS) do
   if f.RegisterUnitEvent then pcall(f.RegisterUnitEvent,f,ev,unit) else pcall(f.RegisterEvent,f,ev) end
 end
 f:SetScript("OnEvent",function() A:UpdateUnitFrame(f) end)

 if unit~="player" and type(RegisterUnitWatch)=="function" then pcall(RegisterUnitWatch,f) end
 self.unitFrames[key]=f
 self:NotifyUnitButtonCreated(f)
 self:UpdateUnitFrame(f)
 return f
end

function A:RefreshSingleLayout(key)
 local frame=self.unitFrames[key]; if not frame then return end
 local cfg=self.db.units[key]
 frame.cfg=cfg
 local mover=self.singleMovers and self.singleMovers[key]
 if InCombatLockdown() then
   self:AfterCombat("single:"..key,function() A:RefreshSingleLayout(key) end)
   self:UpdateUnitFrame(frame)
   return
 end
 if mover then
   mover.cfg=cfg; mover:SetSize(cfg.width,cfg.height); mover:ClearAllPoints(); mover:SetPoint("CENTER",UIParent,"CENTER",cfg.x,cfg.y)
   frame:ClearAllPoints(); frame:SetAllPoints(mover)
 end
 self:ApplyFrameStyle(frame,cfg)

 if self.db.testMode then
   self:ApplyTestToFrame(frame,true,1)
 elseif self.db.enabled and cfg.enabled then
   frame.preview=nil
   if key=="player" then
     frame:Show()
   elseif type(RegisterUnitWatch)=="function" then
     pcall(RegisterUnitWatch,frame)
   elseif UnitExists then
     local ok,exists=pcall(UnitExists,frame.unit); frame:SetShown(ok and exists and true or false)
   end
 else
   if key~="player" and type(UnregisterUnitWatch)=="function" then pcall(UnregisterUnitWatch,frame) end
   frame:Hide()
 end
 self:UpdateUnitFrame(frame)
end

function A:ApplyTestToFrame(frame,on,index)
 if not frame then return end
 if InCombatLockdown() then self:Print(self:T("LOCKED_COMBAT")); return end
 frame.preview=on and true or nil; frame.previewIndex=index
 if frame.unit~="player" then
   if on and type(UnregisterUnitWatch)=="function" then pcall(UnregisterUnitWatch,frame)
   elseif not on and type(RegisterUnitWatch)=="function" then pcall(RegisterUnitWatch,frame) end
 end
 if on then frame:Show() else
   if frame.unit=="player" then frame:Show() elseif type(RegisterUnitWatch)~="function" then frame:SetShown(UnitExists(frame.unit)) end
 end
 self:UpdateUnitFrame(frame)
end

function A:SetUnlocked(on)
 if InCombatLockdown() then self:Print(self:T("LOCKED_COMBAT")); return false end
 self.db.unlocked=on and true or false
 for _,m in pairs(self.singleMovers or {}) do m:SetShown(self.db.unlocked); m:EnableMouse(self.db.unlocked) end
 if self.partyMover then self.partyMover:SetShown(self.db.unlocked); self.partyMover:EnableMouse(self.db.unlocked) end
 if self.raidMover then self.raidMover:SetShown(self.db.unlocked); self.raidMover:EnableMouse(self.db.unlocked) end
 return true
end

function A:RegisterWithComfyHub()
 local hub=_G.ComfyHub
 if not hub or type(hub.RegisterLayoutTarget)~="function" then return end
 for key,m in pairs(self.singleMovers or {}) do
   hub:RegisterLayoutTarget("ComfyFrames","unit:"..key,m,{setEditMode=function(on) A:SetUnlocked(on) end})
 end
 if self.partyMover then hub:RegisterLayoutTarget("ComfyFrames","party",self.partyMover,{setEditMode=function(on) A:SetUnlocked(on) end}) end
 if self.raidMover then hub:RegisterLayoutTarget("ComfyFrames","raid",self.raidMover,{setEditMode=function(on) A:SetUnlocked(on) end}) end
end

function A:ResetPositions()
 for key,d in pairs(self.defaults.units) do self.db.units[key].x=d.x; self.db.units[key].y=d.y end
 self.db.party.x=self.defaults.party.x; self.db.party.y=self.defaults.party.y
 self.db.raid.x=self.defaults.raid.x; self.db.raid.y=self.defaults.raid.y
 self:ApplyAll()
end

function A:InitializeFrames()
 self.singleMovers=self.singleMovers or {}
 for _,key in ipairs(SINGLE) do
   local cfg=self.db.units[key]
   local mover=self:CreateMover("unit_"..key,cfg,self:T(string.upper(key)))
   self.singleMovers[key]=mover
   local frame=self:CreateUnitButton(key,key,cfg,mover)
   frame:ClearAllPoints(); frame:SetAllPoints(mover)
 end

 local events=CreateFrame("Frame")
 for _,ev in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","UNIT_PET","GROUP_ROSTER_UPDATE","ADDON_LOADED","PLAYER_REGEN_DISABLED"}) do pcall(events.RegisterEvent,events,ev) end
 events:SetScript("OnEvent",function(_,ev,arg1)
   if ev=="PLAYER_REGEN_DISABLED" and A.db.unlocked then A:SetUnlocked(false)
   elseif ev=="ADDON_LOADED" and arg1=="ComfyHub" then A:RegisterWithComfyHub()
   else A:ApplyAll() end
 end)
end
