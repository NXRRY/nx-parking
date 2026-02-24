RegisterNetEvent('nx-parking:client:VersionLog', function(current, newest, result)
    local scriptName = "^2nx^7-^2parking"
    local author = "^4NXRRY"
    
    if result == 0 then
        -- กรณีเวอร์ชันล่าสุด (Latest)
        print(scriptName .. " ^7v^5" .. current .. "^7 - ^2You are running the latest version ^2by " .. author .. "^7")
    
    elseif result < 0 then
        -- กรณีเวอร์ชันเก่า (Outdated)
        print("^1----------------------------------------------------------------------")
        print(scriptName .. " ^7- ^1Outdated Version^7! (^1" .. current .. "^7 → ^2" .. newest .. "^7)")
        print("^3New update available at: ^5https://github.com/NXRRY/nx-parking")
        print("^1----------------------------------------------------------------------")
    end
end)