ComfyFrames = ComfyFrames or {}
local A = ComfyFrames

-- WoW Forever may return secret booleans from UnitInRange while addon
-- execution is tainted. Secret booleans must never be compared or tested in
-- Lua. Let the native frame API consume the value whenever possible.
local function IsSecretValue(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret and true or false
end

local function SetVisible(frame)
    if frame and frame.SetAlpha then frame:SetAlpha(1) end
end

local function SetRangeAlpha(frame, inRange)
    if not frame then return end

    if IsSecretValue(inRange) then
        if type(frame.SetAlphaFromBoolean) == "function" then
            local ok = pcall(frame.SetAlphaFromBoolean, frame, inRange, 1, 0.45)
            if ok then return end
        end
        -- Conservative fallback: unknown/secret range must never hide a unit
        -- or generate another Lua error on clients without the native helper.
        SetVisible(frame)
        return
    end

    if inRange == false then
        frame:SetAlpha(0.45)
    else
        frame:SetAlpha(1)
    end
end

function A:UpdateRange()
    if not self.db then return end

    if self.db.testMode then
        for _, frame in ipairs(self.partyFrames or {}) do SetVisible(frame) end
        for _, frame in ipairs(self.raidFrames or {}) do SetVisible(frame) end
        return
    end

    local function UpdateOne(frame, enabled)
        if not frame then return end
        if not enabled or frame.unit == "player" or type(UnitInRange) ~= "function" then
            SetVisible(frame)
            return
        end

        local ok, inRange, checkedRange = pcall(UnitInRange, frame.unit)
        if not ok then
            SetVisible(frame)
            return
        end

        -- If WoW gives us a normal checkedRange=false, range information is
        -- unavailable and the unit should stay fully visible.
        if not IsSecretValue(checkedRange) and checkedRange == false then
            SetVisible(frame)
            return
        end

        -- inRange itself can be a secret boolean on Forever. The native
        -- SetAlphaFromBoolean path handles it without a Lua comparison.
        SetRangeAlpha(frame, inRange)
    end

    for _, frame in ipairs(self.partyFrames or {}) do
        UpdateOne(frame, self.db.party and self.db.party.rangeFade)
    end
    for _, frame in ipairs(self.raidFrames or {}) do
        UpdateOne(frame, self.db.raid and self.db.raid.rangeFade)
    end
end
