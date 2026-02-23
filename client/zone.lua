isInsideParkingZone = false 
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerJob = nil
local CreatedZones = {}

local function UpdateJob()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.job then
        PlayerJob = PlayerData.job.name
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        UpdateJob()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    UpdateJob()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo.name
end)

CreateThread(function()
    for _, zoneData in ipairs(Config.ParkingZones) do
        local zone = PolyZone:Create(zoneData.points, {
            name = zoneData.name,
            minZ = zoneData.minZ,
            maxZ = zoneData.maxZ,
            debugPoly = zoneData.debug
        })

        CreatedZones[zoneData.name] = zone

        zone:onPlayerInOut(function(isPointInside)
            if isPointInside then
                local isAllowed = false
                
                -- ตรวจสอบสิทธิ์
                if PlayerJob and zoneData.allowJobs then
                    if zoneData.allowJobs[PlayerJob] ~= nil then
                        isAllowed = true
                    end
                end
                
                isInsideParkingZone = not isAllowed

                -- --- ส่วนการแสดง Text UI ---
                if isInsideParkingZone then
                    local allowedList = ""
                    if zoneData.allowJobs then
                        for jobName, _ in pairs(zoneData.allowJobs) do
                            local formattedJob = jobName:gsub("^%l", string.upper)
                            allowedList = (allowedList == "") and formattedJob or (allowedList .. ", " .. formattedJob)
                        end
                    end

                    local uiMsg = ""
                    if allowedList ~= "" then
                        uiMsg = string.format(Config.Strings['no_parking_zone_jobs'], allowedList)
                    else
                        uiMsg = Config.Strings['no_parking_zone_all']
                    end

                    -- เรียกใช้ Text UI ของ ox_lib
                    lib.showTextUI(uiMsg, {
                        position = "bottom-center",
                        icon = 'circle-exclamation', -- เปลี่ยนไอคอนให้ดูทันสมัยขึ้น
                        iconColor = '#ff4d4d',       -- สีไอคอนแยกกับตัวหนังสือ
                        style = {
                            borderRadius = '10px',   -- มนขึ้นจะดูโมเดิร์นกว่า
                            backgroundColor = 'rgba(148, 30, 30, 0.5)', -- ใส่ความโปร่งแสง 10% ให้เห็นฉากหลังนิดๆ
                            color = '#ffffff',
                            border = '1px solid rgba(255, 255, 255, 0.2)', -- เส้นขอบจางๆ เพิ่มความคม
                            boxShadow = '0 0 15px rgba(0, 0, 0, 0.5)',     -- ใส่เงาให้ UI ลอยขึ้นมา
                            padding = '12px'                               
                        }
                    })
                end
            else
                -- เมื่อเดินออกจากโซน
                isInsideParkingZone = false
                -- ปิด Text UI ทันทีที่ออกจากโซน
                lib.hideTextUI()
            end
        end)
    end
end)
