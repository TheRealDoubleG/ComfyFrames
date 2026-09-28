ComfyFrames = ComfyFrames or {}
local A = ComfyFrames

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local dst={}
    for k,v in pairs(src) do dst[k]=DeepCopy(v) end
    return dst
end

local function ApplyDefaults(dst,src)
    if type(dst)~="table" or type(src)~="table" then return end
    for k,v in pairs(src) do
        if type(v)=="table" then
            if type(dst[k])~="table" then dst[k]={} end
            ApplyDefaults(dst[k],v)
        elseif dst[k]==nil then
            dst[k]=v
        end
    end
end

local function Trim(v) return tostring(v or ""):match("^%s*(.-)%s*$") or "" end

function A:GetCharacterStorageKey()
    local name,realm
    if UnitFullName then
        local ok,n,r=pcall(UnitFullName,"player")
        if ok then name,realm=n,r end
    end
    if not name and UnitName then
        local ok,n=pcall(UnitName,"player"); if ok then name=n end
    end
    if not realm and GetRealmName then
        local ok,r=pcall(GetRealmName); if ok then realm=r end
    end
    return tostring(name or "Unknown").." - "..tostring(realm or "Realm")
end

function A:GetCharacterProfileKey() return "character:"..self:GetCharacterStorageKey() end

function A:InitializeProfileStorage(defaults,savedName)
    self._profileDefaults=DeepCopy(defaults or {})
    local existing=_G[savedName]
    local root
    if type(existing)=="table" and existing.__comfyProfileSchema==1 and type(existing.profiles)=="table" then
        root=existing
    else
        root={
            __comfyProfileSchema=1, profiles={}, labels={}, kinds={}, characters={},
            activeByCharacter={}, nextCustomId=1,
        }
        root.profiles.account=DeepCopy(defaults or {})
        root.labels.account="Account"; root.kinds.account="account"
        _G[savedName]=root
    end

    root.profiles=root.profiles or {}; root.labels=root.labels or {}; root.kinds=root.kinds or {}
    root.characters=root.characters or {}; root.activeByCharacter=root.activeByCharacter or {}
    root.nextCustomId=tonumber(root.nextCustomId) or 1
    if type(root.profiles.account)~="table" then root.profiles.account=DeepCopy(defaults or {}) end
    ApplyDefaults(root.profiles.account,defaults or {})

    local char=self:GetCharacterStorageKey()
    local key="character:"..char
    if type(root.profiles[key])~="table" then root.profiles[key]=DeepCopy(defaults or {}) end
    ApplyDefaults(root.profiles[key],defaults or {})
    root.labels[key]=char; root.kinds[key]="character"; root.characters[char]=key

    local active=root.activeByCharacter[char] or key
    if type(root.profiles[active])~="table" then active=key end
    root.activeByCharacter[char]=active

    self.profileRoot=root
    self.db=root.profiles[active]
    ApplyDefaults(self.db,defaults or {})
end

function A:GetActiveProfileKey()
    if not self.profileRoot then return nil end
    return self.profileRoot.activeByCharacter[self:GetCharacterStorageKey()] or self:GetCharacterProfileKey()
end

function A:GetProfileEntries()
    local root=self.profileRoot
    if not root then return {} end
    local current=self:GetCharacterProfileKey()
    local out={
        {value=current,text=self:T("CHARACTER_PROFILE")..": "..(root.labels[current] or current)},
        {value="account",text=self:T("ACCOUNT_PROFILE")},
    }
    local custom={}
    for key,kind in pairs(root.kinds) do
        if kind=="custom" and root.profiles[key] then custom[#custom+1]={value=key,text=root.labels[key] or key} end
    end
    table.sort(custom,function(a,b) return tostring(a.text):lower()<tostring(b.text):lower() end)
    for _,e in ipairs(custom) do out[#out+1]=e end
    return out
end

function A:SetActiveProfile(key)
    local root=self.profileRoot
    if not root or type(root.profiles[key])~="table" then return false end
    local current=self:GetCharacterProfileKey()
    local kind=root.kinds[key]
    if key~="account" and key~=current and kind~="custom" then return false end
    root.activeByCharacter[self:GetCharacterStorageKey()]=key
    self.db=root.profiles[key]
    ApplyDefaults(self.db,self._profileDefaults or {})
    if self.ApplyAll then self:ApplyAll() end
    if self.RefreshOptions then self:RefreshOptions() end
    return true
end

function A:CreateCustomProfile(name)
    local root=self.profileRoot
    name=Trim(name)
    if not root or name=="" then return false end
    if #name>40 then name=name:sub(1,40) end
    local id=root.nextCustomId or 1
    local key
    repeat key="custom:"..id; id=id+1 until not root.profiles[key]
    root.nextCustomId=id
    root.profiles[key]=DeepCopy(self.db or self._profileDefaults or {})
    root.labels[key]=name; root.kinds[key]="custom"
    return self:SetActiveProfile(key)
end

function A:DeleteActiveCustomProfile()
    local root=self.profileRoot
    if not root then return false end
    local key=self:GetActiveProfileKey()
    if root.kinds[key]~="custom" then return false end
    root.profiles[key]=nil; root.labels[key]=nil; root.kinds[key]=nil
    return self:SetActiveProfile(self:GetCharacterProfileKey())
end

function A:ResetActiveProfile()
    local root=self.profileRoot
    if not root then return false end
    local key=self:GetActiveProfileKey()
    root.profiles[key]=DeepCopy(self._profileDefaults or {})
    self.db=root.profiles[key]
    if self.ApplyAll then self:ApplyAll() end
    if self.RefreshOptions then self:RefreshOptions() end
    return true
end
