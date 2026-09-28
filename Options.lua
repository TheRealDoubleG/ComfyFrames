ComfyFrames=ComfyFrames or {}
local A=ComfyFrames
local controls={}
local currentTab=1
local sliderIndex=0

local function Label(parent,text,x,y,font)
 local l=parent:CreateFontString(nil,"ARTWORK",font or "GameFontNormal"); l:SetPoint("TOPLEFT",x,y); l:SetText(text); return l
end
local function Button(parent,text,x,y,w,fn)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetSize(w or 130,24); b:SetPoint("TOPLEFT",x,y); b:SetText(text); b:SetScript("OnClick",fn); return b
end
local function Check(parent,text,x,y,get,set)
 local c=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate"); c:SetPoint("TOPLEFT",x,y)
 local l=c.Text or c.text or c:CreateFontString(nil,"ARTWORK","GameFontNormal")
 if not c.Text and not c.text then l:SetPoint("LEFT",c,"RIGHT",3,1); c.Text=l end
 l:SetText(text); c._get=get
 c:SetScript("OnClick",function(self) set(self:GetChecked() and true or false); A:ApplyAll(); A:RefreshOptions() end)
 controls[#controls+1]=c; return c
end
local function Slider(parent,text,minv,maxv,step,x,y,w,get,set)
 sliderIndex=sliderIndex+1; local name="ComfyFramesSlider"..sliderIndex
 local s=CreateFrame("Slider",name,parent,"OptionsSliderTemplate"); s:SetPoint("TOPLEFT",x,y); s:SetWidth(w or 180); s:SetMinMaxValues(minv,maxv); s:SetValueStep(step); s:SetObeyStepOnDrag(true)
 _G[name.."Low"]:SetText(tostring(minv)); _G[name.."High"]:SetText(tostring(maxv)); _G[name.."Text"]:SetText(text)
 s.val=parent:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); s.val:SetPoint("LEFT",s,"RIGHT",8,0); s._get=get
 s:SetScript("OnValueChanged",function(self,v) if self._refresh then return end v=math.floor(v/step+0.5)*step; set(v); self.val:SetText(tostring(v)); A:ApplyAll() end)
 controls[#controls+1]=s; return s
end
local function Edit(parent,text,x,y,w,get,set)
 Label(parent,text,x,y); local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate"); e:SetPoint("TOPLEFT",x,y-22); e:SetSize(w or 200,28); e:SetAutoFocus(false); e._get=get
 e:SetScript("OnEnterPressed",function(self) set(self:GetText() or ""); self:ClearFocus(); A:ApplyAll() end)
 controls[#controls+1]=e; return e
end
local function Dropdown(parent,x,y,w,items,get,set)
 local d=CreateFrame("Frame",nil,parent,"UIDropDownMenuTemplate"); d:SetPoint("TOPLEFT",x,y); UIDropDownMenu_SetWidth(d,w or 220)
 UIDropDownMenu_Initialize(d,function(_,level)
  local cur=get()
  for _,it in ipairs(items()) do local info=UIDropDownMenu_CreateInfo(); info.text=it.text; info.value=it.value; info.checked=it.value==cur
   info.func=function() set(it.value); CloseDropDownMenus(); A:RefreshOptions() end; UIDropDownMenu_AddButton(info,level) end
 end)
 d._get=get; d._refreshDropdown=function() local cur=get(); local txt=tostring(cur or ""); for _,it in ipairs(items()) do if it.value==cur then txt=it.text break end end; UIDropDownMenu_SetText(d,txt) end
 controls[#controls+1]=d; return d
end
local function SelectTab(i)
 currentTab=i
 for n,p in ipairs(A.optionsPages or {}) do p:SetShown(n==i) end
 for n,b in ipairs(A.optionsTabs or {}) do b:SetEnabled(n~=i); b:SetButtonState(n==i and "PUSHED" or "NORMAL",n==i) end
end

function A:RefreshOptions()
 if not self.optionsFrame or not self.db then return end
 for _,c in ipairs(controls) do
  if c._refreshDropdown then c._refreshDropdown()
  elseif c._get then
   local v=c._get(); local t=c:GetObjectType()
   if t=="CheckButton" then c:SetChecked(v and true or false)
   elseif t=="Slider" then c._refresh=true; c:SetValue(tonumber(v) or 0); c._refresh=false; c.val:SetText(tostring(v))
   elseif t=="EditBox" and not c:HasFocus() then c:SetText(tostring(v or "")) end
  end
 end
end

function A:ShowOptions() if not self.optionsFrame then self:InitializeOptions() end self.optionsFrame:Show(); self.optionsFrame:Raise(); self:RefreshOptions() end

function A:InitializeOptions()
 if self.optionsFrame then return end
 local f=CreateFrame("Frame","ComfyFramesOptions",UIParent,"BasicFrameTemplateWithInset"); f:SetSize(940,690); f:SetPoint("CENTER",0,20); f:SetFrameStrata("HIGH"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
 f.TitleText:SetText("ComfyFrames"); f:SetScript("OnDragStart",function(self) if not A.db.ui.windowLocked then self:StartMoving() end end); f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end); table.insert(UISpecialFrames,f:GetName())
 self.optionsFrame=f; self.optionsTabs={}; self.optionsPages={}
 local names={A:T("GENERAL"),A:T("UNITS"),A:T("GROUPS"),A:T("STYLE"),A:T("PROFILES"),A:T("INFO")}
 for i,n in ipairs(names) do self.optionsTabs[i]=Button(f,n,18+(i-1)*145,-35,135,function() SelectTab(i) end); local p=CreateFrame("Frame",nil,f); p:SetPoint("TOPLEFT",12,-70); p:SetPoint("BOTTOMRIGHT",-12,12); self.optionsPages[i]=p end

 local p=self.optionsPages[1]
 Check(p,A:T("ENABLE"),20,-20,function() return A.db.enabled end,function(v) A.db.enabled=v end)
 Check(p,A:T("TEST"),20,-55,function() return A.db.testMode end,function(v) A.db.testMode=v; A:ApplyTestMode() end)
 Button(p,A:T("UNLOCK"),20,-105,160,function() A:SetUnlocked(true) end); Button(p,A:T("LOCK"),190,-105,160,function() A:SetUnlocked(false) end); Button(p,A:T("RESET_POSITIONS"),360,-105,210,function() A:ResetPositions() end)
 Button(p,A:T("PRESET_MINIMAL"),20,-165,150,function() A:ApplyPreset("minimal") end); Button(p,A:T("PRESET_STANDARD"),180,-165,150,function() A:ApplyPreset("standard") end); Button(p,A:T("PRESET_HEALER"),340,-165,150,function() A:ApplyPreset("healer") end); Button(p,A:T("PRESET_RAID"),500,-165,150,function() A:ApplyPreset("raid") end)
 Check(p,A:T("HEALTH_TEXT"),20,-225,function() return A.db.display.healthText end,function(v) A.db.display.healthText=v end)
 Check(p,A:T("INCOMING_HEAL"),20,-260,function() return A.db.display.incomingHeal end,function(v) A.db.display.incomingHeal=v end)
 Check(p,A:T("ABSORB"),20,-295,function() return A.db.display.absorb end,function(v) A.db.display.absorb=v end)

 p=self.optionsPages[2]
 local keys={"player","target","targettarget","focus","pet"}
 for i,key in ipairs(keys) do
  local unitKey=key
  local y=-15-(i-1)*112; Label(p,A:T(string.upper(unitKey)),20,y,"GameFontNormalLarge")
  Check(p,A:T("ENABLE"),20,y-28,function() return A.db.units[unitKey].enabled end,function(v) A.db.units[unitKey].enabled=v end)
  Check(p,A:T("SHOW_POWER"),180,y-28,function() return A.db.units[unitKey].showPower end,function(v) A.db.units[unitKey].showPower=v end)
  Slider(p,A:T("WIDTH"),100,400,5,35,y-70,170,function() return A.db.units[unitKey].width end,function(v) A.db.units[unitKey].width=v end)
  Slider(p,A:T("HEIGHT"),24,90,1,285,y-70,170,function() return A.db.units[unitKey].height end,function(v) A.db.units[unitKey].height=v end)
  Slider(p,A:T("FONT_SIZE"),9,20,1,535,y-70,170,function() return A.db.units[unitKey].fontSize end,function(v) A.db.units[unitKey].fontSize=v end)
 end

 p=self.optionsPages[3]
 Label(p,A:T("PARTY"),20,-15,"GameFontNormalLarge")
 Check(p,A:T("ENABLE"),20,-45,function() return A.db.party.enabled end,function(v) A.db.party.enabled=v end)
 Check(p,A:T("INCLUDE_PLAYER"),190,-45,function() return A.db.party.includePlayer end,function(v) A.db.party.includePlayer=v end)
 Check(p,A:T("RANGE_FADE"),430,-45,function() return A.db.party.rangeFade end,function(v) A.db.party.rangeFade=v end)
 Slider(p,A:T("WIDTH"),100,300,5,35,-95,180,function() return A.db.party.width end,function(v) A.db.party.width=v end)
 Slider(p,A:T("HEIGHT"),24,70,1,300,-95,180,function() return A.db.party.height end,function(v) A.db.party.height=v end)
 Label(p,A:T("RAID"),20,-185,"GameFontNormalLarge")
 Check(p,A:T("ENABLE"),20,-215,function() return A.db.raid.enabled end,function(v) A.db.raid.enabled=v end)
 Check(p,A:T("RANGE_FADE"),190,-215,function() return A.db.raid.rangeFade end,function(v) A.db.raid.rangeFade=v end)
 Slider(p,A:T("WIDTH"),70,180,2,35,-265,180,function() return A.db.raid.width end,function(v) A.db.raid.width=v end)
 Slider(p,A:T("HEIGHT"),20,60,1,300,-265,180,function() return A.db.raid.height end,function(v) A.db.raid.height=v end)
 Slider(p,A:T("RAID_COLUMNS"),1,8,1,565,-265,160,function() return A.db.raid.columns end,function(v) A.db.raid.columns=v end)

 p=self.optionsPages[4]
 Check(p,A:T("STYLE_CLASS_COLORS"),20,-20,function() return A.db.style.classColors end,function(v) A.db.style.classColors=v end)
 Edit(p,"Health RGB",20,-65,180,function() return A.db.style.healthColor end,function(v) A.db.style.healthColor=v end)
 Edit(p,"Power RGB",230,-65,180,function() return A.db.style.powerColor end,function(v) A.db.style.powerColor=v end)
 Edit(p,"Incoming Heal RGB",440,-65,180,function() return A.db.style.incomingHealColor end,function(v) A.db.style.incomingHealColor=v end)
 Edit(p,"Absorb RGB",650,-65,180,function() return A.db.style.absorbColor end,function(v) A.db.style.absorbColor=v end)

 p=self.optionsPages[5]
 Label(p,A:T("PROFILES_HINT"),20,-20,"GameFontHighlight")
 Dropdown(p,5,-75,270,function() return A:GetProfileEntries() end,function() return A:GetActiveProfileKey() end,function(v) A:SetActiveProfile(v) end)
 local e=Edit(p,A:T("CUSTOM_PROFILE"),20,-135,220,function() return "" end,function() end)
 Button(p,A:T("CREATE"),250,-157,120,function() if A:CreateCustomProfile(e:GetText()) then e:SetText("") end end); Button(p,A:T("DELETE"),380,-157,140,function() A:DeleteActiveCustomProfile() end); Button(p,A:T("RESET_PROFILE"),530,-157,160,function() A:ResetActiveProfile() end)

 p=self.optionsPages[6]
 Label(p,"ComfyFrames "..A.version.." "..A.status,20,-20,"GameFontNormalLarge")
 local info=Label(p,"",20,-65,"GameFontHighlight"); info:SetWidth(800); info:SetJustifyH("LEFT")
 local cv,cb,_,ci=A:GetClientBuildInfo()
 info:SetText("Build-Datum: "..A.buildDate.."\nAutor: "..A.author.."\nDiscord: "..A.discord.."\nGitHub: "..A.github.."\n\nClient: "..cv.." / Build "..cb.." / Interface "..tostring(ci or "?").."\nTarget: "..A.gameVersion.." / Interface "..A.interface.."\n\n"..A:T("INFO_COMMANDS").."\n\n"..A:T("INFO_NOTICE"))
 SelectTab(1); self:RefreshOptions()
end
