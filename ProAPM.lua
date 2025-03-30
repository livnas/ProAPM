
-- Setup frames
local standaloneFrame = CreateFrame("Frame")
local checkKeyInputFrame  = Test or CreateFrame("Frame", "Test", UIParent)
local timerFrame = CreateFrame("Frame")
local commFrame = CreateFrame("Frame")
-- UI Frame
sharedFrame = CreateFrame("Frame", "ProAPMSharedDisplay", UIParent, "BackdropTemplate")
Mixin(sharedFrame, BackdropTemplateMixin)

-- Check for "combat" events
standaloneFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
standaloneFrame:RegisterEvent("PLAYER_REGEN_ENABLED") 

-- Setup addon communcation
C_ChatInfo.RegisterAddonMessagePrefix("ProAPM")
commFrame:RegisterEvent("CHAT_MSG_ADDON")

-- Variables
local actions = 0
local inCombat = false
local combatStartTime = 0
local elapsedTime = 0
local currentAPM = 0
local finalAPM = 0

local throttle = 0


-- Global Variables for UI && Options
-- Other player data
otherPlayers = {}
sharedRows = {}

-- Enable/Disable APM tracking
apmEnabled = true

-- Options
ProAPM_Settings = ProAPM_Settings or {}
ProAPM_Settings.customYell = ProAPM_Settings.customYell or "Holy shit is that %d APM?!!!?"


-- Events

local function AreAllGroupMembersInSameGuild()
    if not IsInGroup() or not IsInGuild() then
        return false
    end

    local myGuildName = GetGuildInfo("player")
    if not myGuildName then return false end

    local total = GetNumGroupMembers()
    for i = 1, total do
        local unit = IsInRaid() and "raid"..i or "party"..i
        if UnitExists(unit) and UnitName(unit) ~= UnitName("player") then
            local guild = GetGuildInfo(unit)
            if guild ~= myGuildName then
                return false
            end
        end
    end

    return true
end

-- Check if we entered combat or not
standaloneFrame:SetScript("OnEvent", function(self, event)

    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        actions = 0
        combatStartTime = GetTime()

        -- Should probably, hopefully, clear the entire table and be ready for new data
        table.wipe(otherPlayers)
        for _, row in ipairs(sharedRows) do
            row:SetText("")
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        elapsedTime = GetTime() - combatStartTime
        finalAPM = actions / elapsedTime * 60
        elapsedTime = 0
        actions = 0

        if AreAllGroupMembersInSameGuild() then
            local yellText = ProAPM_Settings.customYell or "APM: %d"
            SendChatMessage(string.format(yellText, finalAPM), "YELL")
        end
    end

end)

local function UpdateSharedDisplay()
    local index = 1

    local sorted = {}
    for playerName, apm in pairs(otherPlayers) do
        table.insert(sorted, { name = playerName, apm = apm })
    end

    table.sort(sorted, function(a, b)
        return a.apm > b.apm
    end)

    -- Render sorted rows
    local index = 1
    for _, entry in ipairs(sorted) do
        local row = sharedRows[index]

        if not row then
            row = sharedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row:SetPoint("TOPLEFT", 10, -10 - ((index - 1) * 20))
            sharedRows[index] = row
        end

        local shortName = Ambiguate(entry.name, "short")
        local name = (shortName == UnitName("player") and "|cffffff00You|r" or shortName)

        row:SetText(name .. " : " .. string.format("%d", entry.apm))
        index = index + 1
    end

    -- Hide unused rows
    for i = index, #sharedRows do
        sharedRows[i]:SetText("")
    end
end


-- Update APM every second
timerFrame:SetScript("OnUpdate", function(self, elapsed)

    if inCombat and apmEnabled then 
        throttle = throttle + elapsed

        if throttle > 1 then
            elapsedTime = GetTime() - combatStartTime
            currentAPM = actions / elapsedTime * 60

            otherPlayers[UnitName("player")] = currentAPM
            UpdateSharedDisplay()

            if IsInGroup() then
                local msg = string.format("APM:%.2f", currentAPM)
                local channel = IsInRaid() and "RAID" or "PARTY"
                C_ChatInfo.SendAddonMessage("ProAPM", msg, channel)
            end

            throttle = 0
        end
    end
end)


-- Checks for keyboard input, if key is pressed, add +1 to actions 
checkKeyInputFrame:SetScript("OnKeyDown", function(self, key)

    if inCombat and apmEnabled then
        actions = actions + 1
    end

end)

checkKeyInputFrame:SetPropagateKeyboardInput(true)

-- Check if we're in a party or raid, if yes, send data to other players using ProAPM
commFrame:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)

    if prefix == "ProAPM" and Ambiguate(sender, "short") ~= UnitName("player") then
        local apm = tonumber(msg:match("APM:(%d+%.?%d*)"))
        if apm then
            otherPlayers[sender] = apm
            UpdateSharedDisplay()
        end
    end

end)
