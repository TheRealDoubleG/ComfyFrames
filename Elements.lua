ComfyFrames=ComfyFrames or {}
local A=ComfyFrames

local function IsSecret(v) return type(issecretvalue)=="function" and issecretvalue(v)==true end
local function PlainNumber(v) if IsSecret(v) or type(v)~="number" then return nil end return v end
local function PlainBoolCall(fn,...)
 if type(fn)~="function" then return nil end
 local ok,v=pcall(fn,...); if not ok or IsSecret(v) then return nil end
 return v and true or false
end
local function Hex(v,fr,fg,fb)
 v=tostring(v or ""):gsub("#",""):gsub("%s+",""):upper()
 if not v:match("^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$") then return fr,fg,fb end
 return (tonumber(v:sub(1,2),16) or 255)/255,(tonumber(v:sub(3,4),16) or 255)/255,(tonumber(v:sub(5,6),16) or 255)/255
end
local function SafeFont(fs,path,size)
 local ok,result=pcall(fs.SetFont,fs,path,size,"OUTLINE")
 if not ok or result==false then pcall(fs.SetFont,fs,STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size,"OUTLINE") end
end

A.Secrets={IsSecret=IsSecret,PlainNumber=PlainNumber,PlainBoolCall=PlainBoolCall}
A.Hex=Hex

function A:GetUnitColor(unit)
 if self.db.style.classColors and UnitClass then
   local ok,_,class=pcall(UnitClass,unit)
   if ok and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
     local c=RAID_CLASS_COLORS[class]; return c.r,c.g,c.b
   end
 end
 return Hex(self.db.style.healthColor,0.24,0.75,0.39)
end

local function SafeUnitValue(fn,unit,...)
 if type(fn)~="function" then return nil end
 local ok,v=pcall(fn,unit,...); return ok and v or nil
end

function A:ApplyFrameStyle(frame,cfg)
 frame.cfg=cfg
 frame:SetSize(cfg.width,cfg.height)
 local powerH=cfg.showPower and math.max(4,math.floor(cfg.height*0.18)) or 0
 frame.health:ClearAllPoints(); frame.health:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-1); frame.health:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-1,powerH+1)
 frame.power:SetShown(cfg.showPower)
 if cfg.showPower then
   frame.power:ClearAllPoints(); frame.power:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",1,1); frame.power:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-1,1); frame.power:SetHeight(powerH)
 end
 frame.health:SetStatusBarTexture(self.db.style.texture)
 frame.power:SetStatusBarTexture(self.db.style.texture)
 frame.incoming:SetStatusBarTexture(self.db.style.texture)
 frame.absorb:SetStatusBarTexture(self.db.style.texture)

 local br,bg,bb=Hex(self.db.style.backgroundColor,0.08,0.08,0.08)
 frame.bg:SetColorTexture(br,bg,bb,0.92)
 local pr,pg,pb=Hex(self.db.style.powerColor,0.2,0.45,0.82); frame.power:SetStatusBarColor(pr,pg,pb,1)
 local hr,hg,hb=self:GetUnitColor(frame.unit); frame.health:SetStatusBarColor(hr,hg,hb,1)
 local ir,ig,ib=Hex(self.db.style.incomingHealColor,0.34,0.89,0.54); frame.incoming:SetStatusBarColor(ir,ig,ib,0.8)
 local ar,ag,ab=Hex(self.db.style.absorbColor,0.38,0.71,1); frame.absorb:SetStatusBarColor(ar,ag,ab,0.8)
 local rr,rg,rb=Hex(self.db.style.borderColor,0.33,0.33,0.33); frame:SetBackdropBorderColor(rr,rg,rb,1)

 SafeFont(frame.name,self.db.style.font,cfg.fontSize)
 SafeFont(frame.healthText,self.db.style.font,math.max(9,cfg.fontSize-1))
 SafeFont(frame.status,self.db.style.font,math.max(9,cfg.fontSize-1))
 SafeFont(frame.role,self.db.style.font,math.max(9,cfg.fontSize-2))
 frame.healthText:SetShown(self.db.display.healthText)
end

function A:SetExternalHighlight(frame,key,color)
 if not frame then return end
 frame.externalHighlights=frame.externalHighlights or {}
 if color then frame.externalHighlights[key]=color else frame.externalHighlights[key]=nil end
 local chosen=nil
 for _,c in pairs(frame.externalHighlights) do chosen=c break end
 if chosen then
   frame:SetBackdropBorderColor(chosen[1] or 1,chosen[2] or 1,chosen[3] or 0,chosen[4] or 1)
 else
   local r,g,b=Hex(self.db.style.borderColor,0.33,0.33,0.33); frame:SetBackdropBorderColor(r,g,b,1)
 end
end

function A:UpdateUnitFrame(frame)
 if not frame or not self.db then return end
 if self.db.testMode and frame.preview then
   frame.name:SetText(self:T("TEST_NAME").." "..tostring(frame.previewIndex or ""))
   frame.health:SetMinMaxValues(0,100); frame.health:SetValue(73)
   frame.power:SetMinMaxValues(0,100); frame.power:SetValue(58)
   frame.incoming:SetMinMaxValues(0,100); frame.incoming:SetValue(18)
   frame.absorb:SetMinMaxValues(0,100); frame.absorb:SetValue(12)
   frame.healthText:SetText("73%"); frame.status:SetText(""); frame.role:SetText(frame.groupKind and "HEALER" or "")
   return
 end

 local unit=frame.unit
 local exists=PlainBoolCall(UnitExists,unit)
 if exists==false then return end

 local hp=SafeUnitValue(UnitHealth,unit)
 local maxhp=SafeUnitValue(UnitHealthMax,unit)
 if type(maxhp)~="nil" then pcall(frame.health.SetMinMaxValues,frame.health,0,maxhp) end
 if type(hp)~="nil" then pcall(frame.health.SetValue,frame.health,hp) end

 local power=SafeUnitValue(UnitPower,unit)
 local maxpower=SafeUnitValue(UnitPowerMax,unit)
 if type(maxpower)~="nil" then pcall(frame.power.SetMinMaxValues,frame.power,0,maxpower) end
 if type(power)~="nil" then pcall(frame.power.SetValue,frame.power,power) end

 if self.db.display.incomingHeal then
   local heal=SafeUnitValue(UnitGetIncomingHeals,unit)
   if type(maxhp)~="nil" then pcall(frame.incoming.SetMinMaxValues,frame.incoming,0,maxhp) end
   if type(heal)~="nil" then pcall(frame.incoming.SetValue,frame.incoming,heal) else pcall(frame.incoming.SetValue,frame.incoming,0) end
   frame.incoming:Show()
 else frame.incoming:Hide() end

 if self.db.display.absorb then
   local absorb=SafeUnitValue(UnitGetTotalAbsorbs,unit)
   if type(maxhp)~="nil" then pcall(frame.absorb.SetMinMaxValues,frame.absorb,0,maxhp) end
   if type(absorb)~="nil" then pcall(frame.absorb.SetValue,frame.absorb,absorb) else pcall(frame.absorb.SetValue,frame.absorb,0) end
   frame.absorb:Show()
 else frame.absorb:Hide() end

 local okName,name=pcall(UnitName,unit)
 if okName and type(name)~="nil" then frame.name:SetText(name) end

 local nhp,nmax=PlainNumber(hp),PlainNumber(maxhp)
 if self.db.display.healthText then
   if nhp and nmax and nmax>0 then frame.healthText:SetFormattedText("%d%%",math.floor((nhp/nmax)*100+0.5))
   elseif type(hp)~="nil" then frame.healthText:SetText(hp)
   else frame.healthText:SetText("") end
 end

 local connected=PlainBoolCall(UnitIsConnected,unit)
 local dead=PlainBoolCall(UnitIsDeadOrGhost,unit)
 if connected==false then frame.status:SetText(self:T("OFFLINE"))
 elseif dead==true then frame.status:SetText(self:T("DEAD"))
 else frame.status:SetText("") end

 if frame.cfg.showRole and type(UnitGroupRolesAssigned)=="function" then
   local ok,role=pcall(UnitGroupRolesAssigned,unit)
   if ok and role and role~="NONE" then frame.role:SetText(role) else frame.role:SetText("") end
 else frame.role:SetText("") end

 local r,g,b=self:GetUnitColor(unit); frame.health:SetStatusBarColor(r,g,b,1)
end
