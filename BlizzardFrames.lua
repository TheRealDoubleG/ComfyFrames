ComfyFrames = ComfyFrames or {}
local A = ComfyFrames

A.version = "0.5"
A.buildDate = "04.10.2026"

local function IsInCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function EnsureDefaults()
    if not A.db then return end
    A.db.blizzardFrames = A.db.blizzardFrames or {}
    local b = A.db.blizzardFrames
    if b.player == nil then b.player = true end
    if b.target == nil then b.target = true end
    if b.targettarget == nil then b.targettarget = true end
end

local originalInitializeDB = A.InitializeDB
function A:InitializeDB(...)
    local result
    if originalInitializeDB then result = originalInitializeDB(self, ...) end
    EnsureDefaults()
    return result
end

local FRAME_SPECS = {
    player = {
        names = {"PlayerFrame"},
        shouldShow = function() return true end,
    },
    target = {
        names = {"TargetFrame"},
        shouldShow = function()
            if type(UnitExists) ~= "function" then return true end
            local ok, exists = pcall(UnitExists, "target")
            return ok and exists and true or false
        end,
        updater = function(frame)
            if type(TargetFrame_Update) == "function" then pcall(TargetFrame_Update, frame) end
        end,
    },
    targettarget = {
        names = {"TargetFrameToT", "TargetFrameToTFrame"},
        shouldShow = function()
            if type(UnitExists) ~= "function" then return true end
            local ok, exists = pcall(UnitExists, "targettarget")
            return ok and exists and true or false
        end,
        updater = function(frame)
            if type(TargetFrameToT_Update) == "function" then pcall(TargetFrameToT_Update, frame) end
        end,
    },
}

local function ResolveFrame(spec)
    for _, name in ipairs(spec.names or {}) do
        local frame = _G[name]
        if frame then return frame end
    end
end

local function RestoreFrame(key, spec, frame)
    if not frame or not frame.__ComfyFramesHiddenByAddon then return end
    frame.__ComfyFramesHiddenByAddon = nil
    if spec.updater then spec.updater(frame) end
    if spec.shouldShow and spec.shouldShow() and type(frame.Show) == "function" then
        pcall(frame.Show, frame)
    end
end

local function HideFrame(key, spec, frame)
    if not frame then return end
    if type(frame.IsShown) == "function" then
        local ok, shown = pcall(frame.IsShown, frame)
        if ok and shown then frame.__ComfyFramesHiddenByAddon = true end
    else
        frame.__ComfyFramesHiddenByAddon = true
    end
    if type(frame.Hide) == "function" then pcall(frame.Hide, frame) end
end

function A:ApplyBlizzardFrameVisibility()
    if not self.db then return end
    EnsureDefaults()

    if IsInCombat() then
        if self.AfterCombat then
            self:AfterCombat("blizzard-frame-visibility", function() A:ApplyBlizzardFrameVisibility() end)
        end
        return
    end

    local enabled = self.db.enabled ~= false
    for key, spec in pairs(FRAME_SPECS) do
        local frame = ResolveFrame(spec)
        local show = (not enabled) or self.db.blizzardFrames[key] ~= false
        if show then RestoreFrame(key, spec, frame) else HideFrame(key, spec, frame) end
    end
end

local function HookFrame(key, spec)
    local frame = ResolveFrame(spec)
    if not frame or frame.__ComfyFramesVisibilityHooked or type(frame.HookScript) ~= "function" then return end
    frame.__ComfyFramesVisibilityHooked = true
    frame:HookScript("OnShow", function(self)
        if not A.db or A.db.enabled == false then return end
        EnsureDefaults()
        if A.db.blizzardFrames[key] == false then
            if IsInCombat() then
                if A.AfterCombat then A:AfterCombat("blizzard-frame-hide-" .. key, function() A:ApplyBlizzardFrameVisibility() end) end
                return
            end
            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(0, function()
                    if A.db and A.db.enabled ~= false and A.db.blizzardFrames[key] == false and self:IsShown() then
                        self.__ComfyFramesHiddenByAddon = true
                        self:Hide()
                    end
                end)
            else
                self.__ComfyFramesHiddenByAddon = true
                self:Hide()
            end
        end
    end)
end

local function InstallHooks()
    for key, spec in pairs(FRAME_SPECS) do HookFrame(key, spec) end
end

local originalApplyAll = A.ApplyAll
function A:ApplyAll(...)
    local result
    if originalApplyAll then result = originalApplyAll(self, ...) end
    self:ApplyBlizzardFrameVisibility()
    return result
end

local function Check(parent, text, x, y, get, set)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", x, y)
    local label = c.Text or c.text
    if label then label:SetText(text) end
    c:SetChecked(get() and true or false)
    c:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        A:ApplyBlizzardFrameVisibility()
    end)
    return c
end

local originalInitializeOptions = A.InitializeOptions
function A:InitializeOptions(...)
    if originalInitializeOptions then originalInitializeOptions(self, ...) end
    if self.__blizzardFrameOptionsAdded or not self.optionsPages or not self.db then return end
    self.__blizzardFrameOptionsAdded = true
    EnsureDefaults()

    local page = self.optionsPages[1]
    if not page then return end
    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -515)
    title:SetText(type(GetLocale)=="function" and GetLocale()=="deDE" and "Blizzard-Frames" or "Blizzard frames")

    local de = type(GetLocale)=="function" and GetLocale()=="deDE"
    Check(page, de and "Blizzard-Spielerframe anzeigen" or "Show Blizzard player frame", 20, -548,
        function() return A.db.blizzardFrames.player end,
        function(v) A.db.blizzardFrames.player = v end)
    Check(page, de and "Blizzard-Zielframe anzeigen" or "Show Blizzard target frame", 285, -548,
        function() return A.db.blizzardFrames.target end,
        function(v) A.db.blizzardFrames.target = v end)
    Check(page, de and "Blizzard-Ziel-des-Ziels anzeigen" or "Show Blizzard target-of-target frame", 540, -548,
        function() return A.db.blizzardFrames.targettarget end,
        function(v) A.db.blizzardFrames.targettarget = v end)
end

local e = CreateFrame("Frame")
for _, ev in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED"}) do
    pcall(e.RegisterEvent, e, ev)
end
e:SetScript("OnEvent", function(_, event)
    InstallHooks()
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        A:ApplyBlizzardFrameVisibility()
    end
end)
A.blizzardFrameEventFrame = e
