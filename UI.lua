-- Shared Display Frame


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
