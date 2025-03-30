SLASH_APM1 = "/apm"

SlashCmdList["APM"] = function(msg)
    msg = msg:lower()

    if msg == "disable" then
        apmEnabled = false
        sharedFrame:Hide()
        print("|cffffcc00ProAPM|r is now |cffff0000disabled|r.")

    elseif msg == "enable" then
        apmEnabled = true
        sharedFrame:Show()
        print("|cffffcc00ProAPM|r is now |cff00ff00enabled|r.")

    else
        print("|cffffcc00ProAPM Commands:|r")
        print("  /apm enable    - Enable APM tracking")
        print("  /apm disable   - Disable APM tracking")
    end
end