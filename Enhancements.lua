ComfyFrames = ComfyFrames or {}
local A = ComfyFrames

A.version = "0.4"
A.buildDate = "04.10.2026"

local function IsSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, v)
    return ok and secret == true
end

local function EnsureEnhancementDefaults()
    if not A.db then return end
    A.db.party = A.db.party or {}
    A.db.raid = A.db.raid or {}
    A.db.display = A.db.display or {}

    if A.db.party.rangeFadeAlpha == nil then A.db.party.rangeFadeAlpha = 45 end
    if A.db.raid.rangeFadeAlpha == nil then A.db.raid.rangeFadeAlpha = 45 end
    if A.db.display.absorbPlayer == nil then A.db.display.absorbPlayer = true end
    if A.db.display.absorbTarget == nil then A.db.display.absorbTarget = true end
    if A.db.display.absorbParty == nil then A.db.display.absorbParty = true end
    if A.db.display.absorbRaid == nil then A.db.display.absorbRaid = true end
    if A.db.display.absorbText == nil then A.db.display.absorbText = false end
    if A.db.display.absorbAlpha == nil then A.db.display.absorbAlpha = 45 end
end

local originalInitializeDB = A.InitializeDB
function A:InitializeDB(...)
    local result
    if originalInitializeDB then result = originalInitializeDB(self, ...) end
    EnsureEnhancementDefaults()
    return result
end

local function SetRangeAlpha(frame, inRange, outAlpha)
    if not frame then return end
    outAlpha = math.max(0, math.min(1, tonumber(outAlpha) or 0.45))

    if IsSecret(inRange) then
        if type(frame.SetAlphaFromBoolean) == "function" then
            local ok = pcall(frame.SetAlphaFromBoolean, frame, inRange, 1, outAlpha)
            if ok then return end
        end
        frame:SetAlpha(1)
        return
    end

    if type(inRange) == "boolean" then
        if type(frame.SetAlphaFromBoolean) == "function" then
            local ok = pcall(frame.SetAlphaFromBoolean, frame, inRange, 1, outAlpha)
            if ok then return end
        end
        frame:SetAlpha(inRange and 1 or outAlpha)
        return
    end

    frame:SetAlpha(1)
end

function A:UpdateRange()
    if not self.db then return end
    EnsureEnhancementDefaults()

    if self.db.testMode then
        for _, f in ipairs(self.partyFrames or {}) do f:SetAlpha(1) end
        for _, f in ipairs(self.raidFrames or {}) do f:SetAlpha(1) end
        return
    end

    local function one(frame, enabled, alphaPercent)
        if not frame then return end
        if not enabled or frame.unit == "player" or type(UnitInRange) ~= "function" then
            frame:SetAlpha(1)
            return
        end

        local ok, inRange, checked = pcall(UnitInRange, frame.unit)
        if not ok then
            frame:SetAlpha(1)
            return
        end

        -- A non-secret checked=false means the client has no useful range result.
        if checked ~= nil and not IsSecret(checked) and checked == false then
            frame:SetAlpha(1)
            return
        end

        SetRangeAlpha(frame, inRange, (tonumber(alphaPercent) or 45) / 100)
    end

    for _, f in ipairs(self.partyFrames or {}) do
        one(f, self.db.party.rangeFade, self.db.party.rangeFadeAlpha)
    end
    for _, f in ipairs(self.raidFrames or {}) do
        one(f, self.db.raid.rangeFade, self.db.raid.rangeFadeAlpha)
    end
end

local function AbsorbEnabledForFrame(frame)
    if not A.db or not A.db.display or not A.db.display.absorb then return false end
    if frame.groupKind == "party" then return A.db.display.absorbParty ~= false end
    if frame.groupKind == "raid" then return A.db.display.absorbRaid ~= false end
    if frame.unit == "player" then return A.db.display.absorbPlayer ~= false end
    if frame.unit == "target" or frame.unit == "targettarget" or frame.unit == "focus" then
        return A.db.display.absorbTarget ~= false
    end
    return true
end

local originalApplyFrameStyle = A.ApplyFrameStyle
function A:ApplyFrameStyle(frame, cfg)
    if originalApplyFrameStyle then originalApplyFrameStyle(self, frame, cfg) end
    EnsureEnhancementDefaults()
    if not frame or not frame.absorb or not frame.health then return end

    frame.absorb:ClearAllPoints()
    frame.absorb:SetAllPoints(frame.health)
    if frame.absorb.SetFrameLevel and frame.health.GetFrameLevel then
        frame.absorb:SetFrameLevel(frame.health:GetFrameLevel() + 1)
    end
    frame.absorb:SetAlpha((tonumber(self.db.display.absorbAlpha) or 45) / 100)

    if not frame.absorbText then
        frame.absorbText = frame.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.absorbText:SetPoint("LEFT", frame.health, "LEFT", 5, 0)
    end
end

local originalUpdateUnitFrame = A.UpdateUnitFrame
function A:UpdateUnitFrame(frame)
    if originalUpdateUnitFrame then originalUpdateUnitFrame(self, frame) end
    if not frame or not self.db then return end
    EnsureEnhancementDefaults()

    local enabled = AbsorbEnabledForFrame(frame)
    if frame.absorb then
        frame.absorb:SetShown(enabled)
        frame.absorb:SetAlpha((tonumber(self.db.display.absorbAlpha) or 45) / 100)
    end

    if frame.absorbText then
        if enabled and self.db.display.absorbText and type(UnitGetTotalAbsorbs) == "function" then
            local ok, value = pcall(UnitGetTotalAbsorbs, frame.unit)
            if ok and not IsSecret(value) and type(value) == "number" and value > 0 then
                frame.absorbText:SetText("+" .. tostring(math.floor(value + 0.5)))
                frame.absorbText:Show()
            else
                frame.absorbText:SetText("")
                frame.absorbText:Hide()
            end
        else
            frame.absorbText:SetText("")
            frame.absorbText:Hide()
        end
    end
end

local function CreateSlider(parent, name, label, x, y, get, set)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetWidth(180)
    slider:SetMinMaxValues(10, 100)
    slider:SetValueStep(5)
    slider:SetObeyStepOnDrag(true)
    _G[name .. "Low"]:SetText("10")
    _G[name .. "High"]:SetText("100")
    _G[name .. "Text"]:SetText(label)
    slider:SetValue(tonumber(get()) or 45)
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor((tonumber(value) or 45) / 5 + 0.5) * 5
        set(value)
        A:UpdateRange()
        A:ApplyAll()
    end)
    return slider
end

local function CreateCheck(parent, label, x, y, get, set)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", x, y)
    local t = c.Text or c.text
    if t then t:SetText(label) end
    c:SetChecked(get() and true or false)
    c:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        A:ApplyAll()
    end)
    return c
end

local originalInitializeOptions = A.InitializeOptions
function A:InitializeOptions(...)
    if originalInitializeOptions then originalInitializeOptions(self, ...) end
    if self.__enhancementOptionsAdded or not self.optionsPages or not self.db then return end
    self.__enhancementOptionsAdded = true
    EnsureEnhancementDefaults()

    local groups = self.optionsPages[3]
    if groups then
        CreateSlider(groups, "ComfyFramesPartyRangeAlpha", "Party außerhalb Reichweite %", 35, -345,
            function() return A.db.party.rangeFadeAlpha end,
            function(v) A.db.party.rangeFadeAlpha = v end)
        CreateSlider(groups, "ComfyFramesRaidRangeAlpha", "Raid außerhalb Reichweite %", 300, -345,
            function() return A.db.raid.rangeFadeAlpha end,
            function(v) A.db.raid.rangeFadeAlpha = v end)
    end

    local general = self.optionsPages[1]
    if general then
        local title = general:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 20, -355)
        title:SetText("Absorb")
        CreateCheck(general, "Spieler", 20, -385, function() return A.db.display.absorbPlayer end, function(v) A.db.display.absorbPlayer = v end)
        CreateCheck(general, "Ziel/ToT/Fokus", 150, -385, function() return A.db.display.absorbTarget end, function(v) A.db.display.absorbTarget = v end)
        CreateCheck(general, "Gruppe", 330, -385, function() return A.db.display.absorbParty end, function(v) A.db.display.absorbParty = v end)
        CreateCheck(general, "Raid", 450, -385, function() return A.db.display.absorbRaid end, function(v) A.db.display.absorbRaid = v end)
        CreateCheck(general, "Absorb-Zahl", 560, -385, function() return A.db.display.absorbText end, function(v) A.db.display.absorbText = v end)
        CreateSlider(general, "ComfyFramesAbsorbAlpha", "Absorb Deckkraft %", 35, -455,
            function() return A.db.display.absorbAlpha end,
            function(v) A.db.display.absorbAlpha = v end)
    end
end
