local function readBoolMeta(key, default)
    local val = GetResourceMetadata(GetCurrentResourceName(), key, 0)
    if not val then return default end
    val = tostring(val):lower()
    return (val == 'true' or val == '1' or val == 'yes' or val == 'on')
end

local SUPPRESS_UPDATES = readBoolMeta('suppress_updates', false)

if not SUPPRESS_UPDATES then
    local function parseVersion(version)
        local parts = {}
        if version then
            for num in version:gmatch("%d+") do
                table.insert(parts, tonumber(num))
            end
        end
        return parts
    end

    local function compareVersions(current, newest)
        local currentParts = parseVersion(current)
        local newestParts = parseVersion(newest)
        for i = 1, math.max(#currentParts, #newestParts) do
            local c = currentParts[i] or 0
            local n = newestParts[i] or 0
            if c < n then return -1
            elseif c > n then return 1 end
        end
        return 0 -- equal
    end

    function CheckResourceVersion()
        local scriptName = GetCurrentResourceName()
        if IsDuplicityVersion() then
            CreateThread(function()
                Wait(4000)
                local currentVersionRaw = GetResourceMetadata(scriptName, 'version', 0)
                -- ลิงก์ GitHub ของคุณ
                local githubUrl = "https://github.com/NXRRY/nx-parking"
                local repoUrl = "https://raw.githubusercontent.com/NXRRY/nx-parking/main/fxmanifest.lua"

                PerformHttpRequest(repoUrl, function(err, body, headers)
                    if err ~= 200 or not body then
                        print("^1Unable to run version check for ^7'^3"..scriptName.."^7'")
                        return
                    end

                    local newestVersionRaw = body:match("[%s\n]version%s+['\"]([^'\"]+)['\"]")

                    if not newestVersionRaw then
                        print("^1Could not find version string in fxmanifest.lua for ^7'^3"..scriptName.."^7'")
                        return
                    end

                    local compareResult = compareVersions(currentVersionRaw, newestVersionRaw)
                    TriggerClientEvent('nx-parking:client:VersionLog', -1, currentVersionRaw, newestVersionRaw, compareResult)
                    if compareResult == 0 then
                        print("^0'" .. scriptName .. "' - ^2You are running the latest version. (" .. currentVersionRaw .. ")^0")
                    elseif compareResult < 0 then
                        -- แสดงผลเมื่อเวอร์ชันเก่า พร้อมลิงก์ GitHub
                        print("^1----------------------------------------------------------------------^7")
                        print("^0'" .. scriptName .. "' - ^1You are running an outdated version^7! ^7(^1" .. currentVersionRaw .. "^7 → ^2" .. newestVersionRaw .. "^7)")
                        print("^3Please update from GitHub for the latest features:^7")
                        print("^5" .. githubUrl .. "^7") -- ลิงก์จะเป็นสีฟ้า (^5)
                        print("^1----------------------------------------------------------------------^7")
                        
                        SetTimeout(3600000, function()
                            CheckResourceVersion()
                        end)
                    else
                        print("^0'" .. scriptName .. "' - ^5You are running a newer version ^7(^3" .. currentVersionRaw .. "^7 ← ^3" .. newestVersionRaw .. "^7)")
                    end
                end, 'GET')
            end)
        end
    end

    CheckResourceVersion()
end