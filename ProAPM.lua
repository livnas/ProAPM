
-- Setup frames
local standaloneFrame = CreateFrame("Frame")
local checkKeyInputFrame  = Test or CreateFrame("Frame", "Test", UIParent)
local timerFrame = CreateFrame("Frame")
local commFrame = CreateFrame("Frame")

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

-- Other player data
local otherPlayers = {}


-- UI --

-- Local UI frame
local apmFrame = CreateFrame("Frame", "APMTrackerFrame", UIParent)
Mixin(apmFrame, BackdropTemplateMixin) -- Add this!
apmFrame:SetSize(150, 40)
apmFrame:SetPoint("CENTER")
apmFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
apmFrame:SetMovable(true)
apmFrame:EnableMouse(true)
apmFrame:RegisterForDrag("LeftButton")
apmFrame:SetScript("OnDragStart", apmFrame.StartMoving)
apmFrame:SetScript("OnDragStop", apmFrame.StopMovingOrSizing)
apmFrame:Hide()

local apmText = apmFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
apmText:SetPoint("CENTER")
apmText:SetText("APM: 0")

-- Shared Display Frame
local sharedFrame = CreateFrame("Frame", "ProAPMSharedDisplay", UIParent, "BackdropTemplate")
Mixin(sharedFrame, BackdropTemplateMixin)

sharedFrame:SetSize(200, 200)
sharedFrame:SetPoint("RIGHT", -100, 0)
sharedFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
sharedFrame:SetMovable(true)
sharedFrame:EnableMouse(true)
sharedFrame:RegisterForDrag("LeftButton")
sharedFrame:SetScript("OnDragStart", sharedFrame.StartMoving)
sharedFrame:SetScript("OnDragStop", sharedFrame.StopMovingOrSizing)

sharedFrame:Show()



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

    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        elapsedTime = GetTime() - combatStartTime
        finalAPM = actions / elapsedTime * 60
        elapsedTime = 0
        actions = 0

        if AreAllGroupMembersInSameGuild() then
            SendChatMessage(string.format("Holy shit is that %d APM?!!!?", finalAPM), "YELL")
        end
    end

end)


local sharedRows = {}

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

    if inCombat then
        throttle = throttle + elapsed

        if throttle > 1 then
            elapsedTime = GetTime() - combatStartTime
            currentAPM = actions / elapsedTime * 60
            apmText:SetText("APM: " .. string.format("%d", currentAPM))

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

    if inCombat then
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
