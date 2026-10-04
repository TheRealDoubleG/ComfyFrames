ComfyFrames = ComfyFrames or {}
local A = ComfyFrames

A.tickSamples = A.tickSamples or {}

local function IsSecret(value)
    if type(issecretvalue)=="function" then local ok,v=pcall(issecretvalue,value); if ok then return v and true or false end end
    if type(canaccessvalue)=="function" then local ok,v=pcall(canaccessvalue,value); if ok then return not v end end
    return false
end
local function Num(value)
    if value==nil or IsSecret(value) then return nil end
    local ok,v=pcall(tonumber,value); return ok and v or nil
end
local function Now()
    if type(GetTimePreciseSec)=="function" then local ok,v=pcall(GetTimePreciseSec); if ok and tonumber(v) then return tonumber(v) end end
    return type(GetTime)=="function" and (tonumber(GetTime()) or 0) or 0
end

local function EnsureDefaults()
    if not A.db then return end
    A.db.auras=A.db.auras or {}
    local a=A.db.auras
    local defaults={
        playerBuffs=true,playerDebuffs=true,
        targetBuffs=true,targetDebuffs=true,
        targettargetBuffs=false,targettargetDebuffs=true,
        position="above",size=18,spacing=2,maxCount=10,
        ownDebuffs=false,timers=true,stacks=true,
    }
    for k,v in pairs(defaults) do if a[k]==nil then a[k]=v end end
    A.db.ticks=A.db.ticks or {}
    local t=A.db.ticks
    local tickDefaults={enabled=true,mode="both",source="all",showTime=true,showValue=true,height=4}
    for k,v in pairs(tickDefaults) do if t[k]==nil then t[k]=v end end
end

local originalInitializeDB=A.InitializeDB
function A:InitializeDB(...)
    local r
    if originalInitializeDB then r=originalInitializeDB(self,...) end
    EnsureDefaults(); return r
end

local function AuraData(unit,index,filter)
    if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex)=="function" then
        local ok,d=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,filter)
        if ok and type(d)=="table" then
            return {name=d.name,icon=d.icon,applications=d.applications or d.charges or 0,duration=d.duration,expirationTime=d.expirationTime,sourceUnit=d.sourceUnit,spellId=d.spellId or d.spellID}
        end
    end
    local fn=UnitAura
    if filter=="HELPFUL" and type(UnitBuff)=="function" then fn=UnitBuff elseif filter=="HARMFUL" and type(UnitDebuff)=="function" then fn=UnitDebuff end
    if type(fn)~="function" then return nil end
    local v={pcall(fn,unit,index,filter)}
    if not v[1] or not v[2] then return nil end
    return {name=v[2],icon=v[3],applications=v[4] or 0,duration=v[7],expirationTime=v[8],sourceUnit=v[9],spellId=v[11]}
end

local function EnsureAuraButton(frame,index)
    frame.comfyAuras=frame.comfyAuras or {}
    local b=frame.comfyAuras[index]
    if b then return b end
    b=CreateFrame("Frame",nil,frame,"BackdropTemplate")
    b:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(.07,.93,.07,.93)
    b.cooldown=CreateFrame("Cooldown",nil,b,"CooldownFrameTemplate"); b.cooldown:SetAllPoints()
    b.stack=b:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall"); b.stack:SetPoint("BOTTOMRIGHT",1,-1)
    b:Hide(); frame.comfyAuras[index]=b; return b
end

local function AuraTogglesFor(unit)
    local a=A.db.auras
    if unit=="player" then return a.playerBuffs,a.playerDebuffs end
    if unit=="target" then return a.targetBuffs,a.targetDebuffs end
    if unit=="targettarget" then return a.targettargetBuffs,a.targettargetDebuffs end
    return false,false
end

local function CollectAuras(unit)
    local a=A.db.auras; local buffs,debuffs=AuraTogglesFor(unit); local out={}
    local max=math.max(1,math.min(24,tonumber(a.maxCount) or 10))
    local function add(filter,harmful)
        for i=1,40 do
            local d=AuraData(unit,i,filter); if not d then break end
            if not (harmful and a.ownDebuffs and d.sourceUnit~="player" and d.sourceUnit~="pet") then
                out[#out+1]={data=d,harmful=harmful}; if #out>=max then return true end
            end
        end
    end
    if buffs and add("HELPFUL",false) then return out end
    if debuffs then add("HARMFUL",true) end
    return out
end

function A:UpdateFrameAuras(frame)
    if not frame or not self.db then return end
    EnsureDefaults(); local unit=frame.unit
    local supported=unit=="player" or unit=="target" or unit=="targettarget"
    if not supported or frame.preview or not self.db.enabled then
        for _,b in ipairs(frame.comfyAuras or {}) do b:Hide() end; return
    end
    local list=CollectAuras(unit); local a=self.db.auras; local size=math.max(12,math.min(36,tonumber(a.size) or 18)); local gap=math.max(0,math.min(8,tonumber(a.spacing) or 2))
    for i,item in ipairs(list) do
        local b=EnsureAuraButton(frame,i); b:SetSize(size,size); b.icon:SetTexture(item.data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        b:SetBackdropBorderColor(item.harmful and 1 or .25,item.harmful and .2 or .75,item.harmful and .2 or 1,1)
        b:ClearAllPoints()
        local rowWidth=(size+gap)*(math.max(1,math.min(#list,10)))-gap
        local startX=-rowWidth/2+size/2
        local row=math.floor((i-1)/10); local col=(i-1)%10; local y=(size+gap)*row
        if a.position=="below" then b:SetPoint("TOP",frame,"BOTTOM",startX+col*(size+gap),-3-y)
        else b:SetPoint("BOTTOM",frame,"TOP",startX+col*(size+gap),3+y) end
        local stacks=Num(item.data.applications) or 0
        b.stack:SetShown(a.stacks and stacks>1); if a.stacks and stacks>1 then b.stack:SetText(tostring(math.floor(stacks))) end
        local duration,expiration=Num(item.data.duration),Num(item.data.expirationTime)
        if a.timers and duration and expiration and duration>0 and expiration>0 then
            pcall(b.cooldown.SetCooldown,b.cooldown,expiration-duration,duration)
            b.cooldown:Show()
        else
            if b.cooldown.Clear then pcall(b.cooldown.Clear,b.cooldown) end
            b.cooldown:Hide()
        end
        b:Show()
    end
    for i=#list+1,#(frame.comfyAuras or {}) do frame.comfyAuras[i]:Hide() end
end

local function EnsureTickBar(frame)
    if frame.comfyTickBar then return end
    local b=CreateFrame("StatusBar",nil,frame,"BackdropTemplate"); b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); b:SetStatusBarColor(.85,.18,.55,.95)
    b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); b:SetBackdropColor(.02,.02,.02,.8); b:SetBackdropBorderColor(0,0,0,.9)
    b.text=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); b.text:SetPoint("CENTER"); b:Hide(); frame.comfyTickBar=b
end

local function BestPlayerTick()
    local playerGUID=type(UnitGUID)=="function" and UnitGUID("player") or nil; local entries=playerGUID and A.tickSamples[playerGUID]; if not entries then return nil end
    local cfg=A.db.ticks; local now=Now(); local best,bestRemain
    for _,s in pairs(entries) do
        local allow=(cfg.mode=="both") or (cfg.mode==s.kind)
        if allow and (cfg.source=="all" or s.own) then
            local interval=Num(s.intervalAvg); local last=Num(s.lastAt)
            if interval and last and interval>.25 and interval<30 then
                local remain=last+interval-now
                if remain>=-.25 and remain<=interval+.5 and (not bestRemain or remain<bestRemain) then best=s; bestRemain=math.max(0,remain) end
            end
        end
    end
    return best,bestRemain
end

function A:UpdatePlayerTick(frame)
    if not frame or frame.unit~="player" then return end
    EnsureDefaults(); EnsureTickBar(frame); local cfg=self.db.ticks
    if not cfg.enabled or frame.preview then frame.comfyTickBar:Hide(); return end
    local s,remain=BestPlayerTick(); if not s then frame.comfyTickBar:Hide(); return end
    local interval=Num(s.intervalAvg) or 1; local h=math.max(2,math.min(10,tonumber(cfg.height) or 4))
    frame.comfyTickBar:ClearAllPoints(); frame.comfyTickBar:SetPoint("BOTTOMLEFT",frame.health,"TOPLEFT",0,1); frame.comfyTickBar:SetPoint("BOTTOMRIGHT",frame.health,"TOPRIGHT",0,1); frame.comfyTickBar:SetHeight(h)
    frame.comfyTickBar:SetMinMaxValues(0,interval); frame.comfyTickBar:SetValue(math.max(0,math.min(interval,interval-(remain or 0))))
    if s.kind=="heal" then frame.comfyTickBar:SetStatusBarColor(.18,.85,.30,.95) else frame.comfyTickBar:SetStatusBarColor(.85,.18,.25,.95) end
    local parts={}; if cfg.showTime then parts[#parts+1]=string.format("%.1fs",remain or 0) end
    if cfg.showValue and Num(s.amountAvg) then parts[#parts+1]=(s.kind=="heal" and "+" or "-")..tostring(math.floor(s.amountAvg+.5)) end
    frame.comfyTickBar.text:SetText(table.concat(parts," | ")); frame.comfyTickBar:Show()
end

local originalUpdateUnitFrame=A.UpdateUnitFrame
function A:UpdateUnitFrame(frame)
    if originalUpdateUnitFrame then originalUpdateUnitFrame(self,frame) end
    self:UpdateFrameAuras(frame); self:UpdatePlayerTick(frame)
end

local function RecordPeriodic()
    if type(CombatLogGetCurrentEventInfo)~="function" then return end
    local e={CombatLogGetCurrentEventInfo()}; local sub=e[2]
    local kind=sub=="SPELL_PERIODIC_DAMAGE" and "damage" or sub=="SPELL_PERIODIC_HEAL" and "heal" or nil; if not kind then return end
    local sourceGUID,destGUID=e[4],e[8]; local playerGUID=type(UnitGUID)=="function" and UnitGUID("player") or nil; if destGUID~=playerGUID then return end
    local spellID,amount=tonumber(e[12]),tonumber(e[15]); if not spellID or not amount or amount<=0 then return end
    local byGuid=A.tickSamples[destGUID]; if not byGuid then byGuid={}; A.tickSamples[destGUID]=byGuid end
    local key=kind..":"..spellID..":"..tostring(sourceGUID or "?"); local s=byGuid[key]; if not s then s={samples=0,kind=kind,own=(sourceGUID==playerGUID)}; byGuid[key]=s end
    local now=Now(); local previous=s.lastAt; s.samples=(s.samples or 0)+1; s.amountAvg=s.amountAvg and ((s.amountAvg*(s.samples-1)+amount)/s.samples) or amount
    if previous and now>previous then local interval=now-previous; if interval>.25 and interval<30 then s.intervalAvg=s.intervalAvg and (s.intervalAvg*.65+interval*.35) or interval end end
    s.lastAt=now
end

local function StartTickEvents()
    if A.tickEventFrame then return end
    local f=CreateFrame("Frame"); f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED"); f:SetScript("OnEvent",function() RecordPeriodic() end)
    f:SetScript("OnUpdate",function(self,elapsed) self.elapsed=(self.elapsed or 0)+(tonumber(elapsed) or 0); if self.elapsed<.10 then return end; self.elapsed=0; local pf=A.unitFrames and A.unitFrames.player; if pf then A:UpdatePlayerTick(pf) end end); A.tickEventFrame=f
end

local originalInitializeFrames=A.InitializeFrames
function A:InitializeFrames(...)
    if originalInitializeFrames then originalInitializeFrames(self,...) end
    StartTickEvents()
end

local function Check(parent,text,x,y,get,set)
    local c=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate"); c:SetPoint("TOPLEFT",x,y); local t=c.Text or c.text; if t then t:SetText(text) end; c:SetChecked(get() and true or false)
    c:SetScript("OnClick",function(self) set(self:GetChecked() and true or false); A:ApplyAll() end); return c
end
local function Dropdown(parent,x,y,w,items,get,set)
    local d=CreateFrame("Frame",nil,parent,"UIDropDownMenuTemplate"); d:SetPoint("TOPLEFT",x,y); UIDropDownMenu_SetWidth(d,w); UIDropDownMenu_Initialize(d,function(_,level) local cur=get(); for _,it in ipairs(items) do local info=UIDropDownMenu_CreateInfo(); info.text=it.text; info.value=it.value; info.checked=cur==it.value; info.func=function() set(it.value); UIDropDownMenu_SetText(d,it.text); CloseDropDownMenus(); A:ApplyAll() end; UIDropDownMenu_AddButton(info,level) end end); local cur=get(); for _,it in ipairs(items) do if it.value==cur then UIDropDownMenu_SetText(d,it.text) end end; return d
end
local function Slider(parent,name,label,minv,maxv,step,x,y,get,set)
    local s=CreateFrame("Slider",name,parent,"OptionsSliderTemplate"); s:SetPoint("TOPLEFT",x,y); s:SetWidth(210); s:SetMinMaxValues(minv,maxv); s:SetValueStep(step); s:SetObeyStepOnDrag(true); _G[name.."Low"]:SetText(tostring(minv)); _G[name.."High"]:SetText(tostring(maxv)); _G[name.."Text"]:SetText(label); s:SetValue(tonumber(get()) or minv); s:SetScript("OnValueChanged",function(_,v) set(math.floor((tonumber(v) or minv)+.5)); A:ApplyAll() end); return s
end

function A:OpenAuraTickOptions()
    EnsureDefaults()
    if not self.auraTickOptions then
        local f=CreateFrame("Frame","ComfyFramesAuraTickOptions",UIParent,"BasicFrameTemplateWithInset"); f:SetSize(720,610); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart",function(self) self:StartMoving() end); f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end); f.TitleText:SetText("ComfyFrames · Auren & Ticks")
        local a=A.db.auras; local t=A.db.ticks
        local h=f:CreateFontString(nil,"ARTWORK","GameFontNormalLarge"); h:SetPoint("TOPLEFT",24,-42); h:SetText("Buffs / Debuffs")
        Check(f,"Spieler Buffs",24,-78,function() return a.playerBuffs end,function(v) a.playerBuffs=v end); Check(f,"Spieler Debuffs",190,-78,function() return a.playerDebuffs end,function(v) a.playerDebuffs=v end)
        Check(f,"Ziel Buffs",24,-112,function() return a.targetBuffs end,function(v) a.targetBuffs=v end); Check(f,"Ziel Debuffs",190,-112,function() return a.targetDebuffs end,function(v) a.targetDebuffs=v end)
        Check(f,"ToT Buffs",24,-146,function() return a.targettargetBuffs end,function(v) a.targettargetBuffs=v end); Check(f,"ToT Debuffs",190,-146,function() return a.targettargetDebuffs end,function(v) a.targettargetDebuffs=v end)
        Check(f,"Nur eigene Debuffs",390,-78,function() return a.ownDebuffs end,function(v) a.ownDebuffs=v end); Check(f,"Timer",390,-112,function() return a.timers end,function(v) a.timers=v end); Check(f,"Stacks",510,-112,function() return a.stacks end,function(v) a.stacks=v end)
        Dropdown(f,375,-150,170,{{text="Über Frame",value="above"},{text="Unter Frame",value="below"}},function() return a.position end,function(v) a.position=v end)
        Slider(f,"ComfyFramesAuraSize","Icon-Größe",12,36,1,35,-230,function() return a.size end,function(v) a.size=v end); Slider(f,"ComfyFramesAuraMax","Max. Auren",1,24,1,300,-230,function() return a.maxCount end,function(v) a.maxCount=v end)
        local th=f:CreateFontString(nil,"ARTWORK","GameFontNormalLarge"); th:SetPoint("TOPLEFT",24,-325); th:SetText("DoT / HoT Tick-Vorschau (Spieler)")
        Check(f,"Tick-Balken",24,-360,function() return t.enabled end,function(v) t.enabled=v end); Check(f,"Zeit",190,-360,function() return t.showTime end,function(v) t.showTime=v end); Check(f,"Wert",300,-360,function() return t.showValue end,function(v) t.showValue=v end)
        Dropdown(f,10,-405,180,{{text="Schaden + Heilung",value="both"},{text="Nur Schaden",value="damage"},{text="Nur Heilung",value="heal"}},function() return t.mode end,function(v) t.mode=v end)
        Dropdown(f,250,-405,180,{{text="Alle Quellen",value="all"},{text="Nur eigene Effekte",value="own"}},function() return t.source end,function(v) t.source=v end)
        Slider(f,"ComfyFramesTickHeight","Balkenhöhe",2,10,1,35,-500,function() return t.height end,function(v) t.height=v end)
        A.auraTickOptions=f
    end
    self.auraTickOptions:Show(); self.auraTickOptions:Raise()
end

local originalInitializeOptions=A.InitializeOptions
function A:InitializeOptions(...)
    if originalInitializeOptions then originalInitializeOptions(self,...) end
    if self.__auraTickOptionsButton or not self.optionsPages then return end
    self.__auraTickOptionsButton=true
    local p=self.optionsPages[1]; if not p then return end
    local b=CreateFrame("Button",nil,p,"UIPanelButtonTemplate"); b:SetSize(180,24); b:SetPoint("TOPLEFT",390,-500); b:SetText("Auren & Ticks"); b:SetScript("OnClick",function() A:OpenAuraTickOptions() end)
end
