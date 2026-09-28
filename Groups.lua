ComfyFrames=ComfyFrames or {}
local A=ComfyFrames

A.partyFrames=A.partyFrames or {}
A.raidFrames=A.raidFrames or {}

local function CreateGroupFrame(unit,key,cfg,parent,idx,kind)
 local f=CreateFrame("Button","ComfyFrame_"..key,UIParent,"SecureUnitButtonTemplate,BackdropTemplate")
 f.unit=unit; f.key=key; f.cfg=cfg; f.groupKind=kind
 f:SetAttribute("unit",unit); f:SetAttribute("type1","target"); f:RegisterForClicks("AnyUp")
 f:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
 f.bg=f:CreateTexture(nil,"BACKGROUND"); f.bg:SetAllPoints()
 f.health=CreateFrame("StatusBar",nil,f); f.power=CreateFrame("StatusBar",nil,f)
 f.incoming=CreateFrame("StatusBar",nil,f.health); f.absorb=CreateFrame("StatusBar",nil,f.health)
 f.incoming:SetPoint("TOPLEFT",f.health); f.incoming:SetPoint("TOPRIGHT",f.health); f.incoming:SetHeight(3)
 f.absorb:SetPoint("BOTTOMLEFT",f.health); f.absorb:SetPoint("BOTTOMRIGHT",f.health); f.absorb:SetHeight(3)
 f.name=f.health:CreateFontString(nil,"OVERLAY"); f.name:SetPoint("TOPLEFT",5,-4); f.name:SetPoint("RIGHT",-5,0); f.name:SetJustifyH("LEFT")
 f.healthText=f.health:CreateFontString(nil,"OVERLAY"); f.healthText:SetPoint("BOTTOMRIGHT",-5,3)
 f.status=f.health:CreateFontString(nil,"OVERLAY"); f.status:SetPoint("CENTER")
 f.role=f.health:CreateFontString(nil,"OVERLAY"); f.role:SetPoint("TOPRIGHT",-4,-3)
 A:ApplyFrameStyle(f,cfg)
 for _,ev in ipairs({"UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_POWER_UPDATE","UNIT_MAXPOWER","UNIT_NAME_UPDATE","UNIT_CONNECTION","UNIT_HEAL_PREDICTION","UNIT_ABSORB_AMOUNT_CHANGED","UNIT_AURA"}) do
   if f.RegisterUnitEvent then pcall(f.RegisterUnitEvent,f,ev,unit) end
 end
 f:SetScript("OnEvent",function() A:UpdateUnitFrame(f) end)
 if type(RegisterUnitWatch)=="function" then pcall(RegisterUnitWatch,f) end
 A:NotifyUnitButtonCreated(f)
 A:UpdateUnitFrame(f)
 return f
end

function A:LayoutParty()
 if not self.partyMover then return end
 if InCombatLockdown() then self:AfterCombat("layout:party",function() A:LayoutParty() end); return end
 local cfg=self.db.party
 self.partyMover.cfg=cfg; self.partyMover:SetSize(cfg.width,cfg.height*5+cfg.spacing*4)
 self.partyMover:ClearAllPoints(); self.partyMover:SetPoint("TOPLEFT",UIParent,"CENTER",cfg.x,cfg.y)
 for i,f in ipairs(self.partyFrames) do
   f.cfg=cfg; self:ApplyFrameStyle(f,cfg)
   f:ClearAllPoints(); f:SetPoint("TOPLEFT",self.partyMover,"TOPLEFT",0,-(i-1)*(cfg.height+cfg.spacing))
   f:SetSize(cfg.width,cfg.height)
 end
end

function A:LayoutRaid()
 if not self.raidMover then return end
 if InCombatLockdown() then self:AfterCombat("layout:raid",function() A:LayoutRaid() end); return end
 local cfg=self.db.raid
 local cols=math.max(1,math.min(8,tonumber(cfg.columns) or 5))
 local rows=math.ceil(40/cols)
 self.raidMover.cfg=cfg; self.raidMover:SetSize(cols*cfg.width+(cols-1)*cfg.spacing,rows*cfg.height+(rows-1)*cfg.spacing)
 self.raidMover:ClearAllPoints(); self.raidMover:SetPoint("TOPLEFT",UIParent,"CENTER",cfg.x,cfg.y)
 for i,f in ipairs(self.raidFrames) do
   f.cfg=cfg; self:ApplyFrameStyle(f,cfg)
   local col=(i-1)%cols; local row=math.floor((i-1)/cols)
   f:ClearAllPoints(); f:SetPoint("TOPLEFT",self.raidMover,"TOPLEFT",col*(cfg.width+cfg.spacing),-row*(cfg.height+cfg.spacing))
   f:SetSize(cfg.width,cfg.height)
 end
end

function A:ApplyTestMode()
 if InCombatLockdown() then self:Print(self:T("LOCKED_COMBAT")); return end
 local on=self.db.testMode
 local i=0
 for _,f in pairs(self.unitFrames or {}) do i=i+1; self:ApplyTestToFrame(f,on,i) end
 for n,f in ipairs(self.partyFrames) do self:ApplyTestToFrame(f,on,n) end
 for n,f in ipairs(self.raidFrames) do self:ApplyTestToFrame(f,on,n) end
 self:ApplyAll()
end

function A:UpdateRange()
 if self.db.testMode then
   for _,f in ipairs(self.partyFrames) do f:SetAlpha(1) end
   for _,f in ipairs(self.raidFrames) do f:SetAlpha(1) end
   return
 end
 local function one(f,enabled)
   if not enabled or f.unit=="player" or type(UnitInRange)~="function" then f:SetAlpha(1); return end
   local ok,v=pcall(UnitInRange,f.unit)
   if ok and v==false then f:SetAlpha(0.45) else f:SetAlpha(1) end
 end
 for _,f in ipairs(self.partyFrames) do one(f,self.db.party.rangeFade) end
 for _,f in ipairs(self.raidFrames) do one(f,self.db.raid.rangeFade) end
end

function A:InitializeGroups()
 local pcfg=self.db.party
 self.partyMover=self:CreateMover("party",pcfg,self:T("PARTY"))
 self.partyMover:SetPoint("TOPLEFT",UIParent,"CENTER",pcfg.x,pcfg.y)
 local units={"player","party1","party2","party3","party4"}
 for i,unit in ipairs(units) do
   self.partyFrames[i]=CreateGroupFrame(unit,"party"..i,pcfg,self.partyMover,i,"party")
 end

 local rcfg=self.db.raid
 self.raidMover=self:CreateMover("raid",rcfg,self:T("RAID"))
 self.raidMover:SetPoint("TOPLEFT",UIParent,"CENTER",rcfg.x,rcfg.y)
 for i=1,40 do self.raidFrames[i]=CreateGroupFrame("raid"..i,"raid"..i,rcfg,self.raidMover,i,"raid") end

 self:LayoutParty(); self:LayoutRaid()

 if C_Timer and type(C_Timer.NewTicker)=="function" then
   self.rangeTicker=C_Timer.NewTicker(0.5,function() A:UpdateRange() end)
 else
   local rangeFrame=CreateFrame("Frame"); local acc=0
   rangeFrame:SetScript("OnUpdate",function(_,elapsed)
     acc=acc+(tonumber(elapsed) or 0)
     if acc>=0.5 then acc=0; A:UpdateRange() end
   end)
   self.rangeFrame=rangeFrame
 end
end

function A:ApplyAll()
 if not self.db then return end

 if InCombatLockdown() then
   self:AfterCombat("applyAll",function() A:ApplyAll() end)
   for _,f in pairs(self.unitFrames or {}) do self:UpdateUnitFrame(f) end
   for _,f in ipairs(self.partyFrames or {}) do self:UpdateUnitFrame(f) end
   for _,f in ipairs(self.raidFrames or {}) do self:UpdateUnitFrame(f) end
   self:UpdateRange()
   return
 end

 for key,_ in pairs(self.db.units) do self:RefreshSingleLayout(key) end
 self:LayoutParty(); self:LayoutRaid()

 local partyOn=self.db.enabled and self.db.party.enabled
 for i,f in ipairs(self.partyFrames or {}) do
   local should=partyOn and (i~=1 or self.db.party.includePlayer)
   f.cfg=self.db.party
   self:ApplyFrameStyle(f,self.db.party)
   if self.db.testMode then
     self:ApplyTestToFrame(f,should,i)
   elseif should then
     f.preview=nil
     if type(RegisterUnitWatch)=="function" then pcall(RegisterUnitWatch,f)
     elseif UnitExists then local ok,exists=pcall(UnitExists,f.unit); f:SetShown(ok and exists and true or false) end
   else
     if type(UnregisterUnitWatch)=="function" then pcall(UnregisterUnitWatch,f) end
     f:Hide()
   end
   self:UpdateUnitFrame(f)
 end

 local raidOn=self.db.enabled and self.db.raid.enabled
 for i,f in ipairs(self.raidFrames or {}) do
   f.cfg=self.db.raid
   self:ApplyFrameStyle(f,self.db.raid)
   if self.db.testMode then
     self:ApplyTestToFrame(f,raidOn,i)
   elseif raidOn then
     f.preview=nil
     if type(RegisterUnitWatch)=="function" then pcall(RegisterUnitWatch,f)
     elseif UnitExists then local ok,exists=pcall(UnitExists,f.unit); f:SetShown(ok and exists and true or false) end
   else
     if type(UnregisterUnitWatch)=="function" then pcall(UnregisterUnitWatch,f) end
     f:Hide()
   end
   self:UpdateUnitFrame(f)
 end

 self:SetUnlocked(self.db.unlocked)
 self:RegisterWithComfyHub()
 self:UpdateRange()
end
