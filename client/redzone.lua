insidenoParkingZone = false 
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerJob = nil
local CreatedZones = {}

-- ฟังก์ชันดึงข้อมูลอาชีพให้ปลอดภัยขึ้น
local function UpdateJob()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.job then
        PlayerJob = PlayerData.job.name
    else
        -- ถ้ายังไม่มีข้อมูล ให้รอจังหวะถัดไป (เช่น OnPlayerLoaded)
        PlayerJob = nil
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
                UpdateJob() -- รีเช็คอาชีพทุกครั้งที่เข้าโซน

                local isAllowed = false
                local allowedList = ""
                
                -- 1. ตรวจสอบสิทธิ์และดึงรายชื่ออาชีพที่อนุญาต
                if zoneData.allowJobs then
                    for jobName, _ in pairs(zoneData.allowJobs) do
                        local formattedJob = jobName:gsub("^%l", string.upper)
                        allowedList = (allowedList == "") and formattedJob or (allowedList .. ", " .. formattedJob)
                        
                        if PlayerJob == jobName then
                            isAllowed = true
                        end
                    end
                end
                
                insidenoParkingZone = not isAllowed

                -- 2. ตั้งค่าการแสดงผล
                local statusColor = isAllowed and "#2ecc71" or "#ff4d4d"
                local statusIcon = isAllowed and "square-check" or "circle-exclamation"
                local displayTitle = zoneData.title or zoneData.name or "Parking Zone"
                
                -- ใช้ Markdown ในการจัดรูปแบบ: # คือหัวข้อใหญ่, --- คือเส้นคั่น
                local uiMsg = string.format([[
# %s
---
%s]], 
                displayTitle,
                isAllowed and "✅ คุณได้รับอนุญาตให้จอดในพื้นที่นี้" or "❌ **เขตห้ามจอด:** เฉพาะ (" .. (allowedList ~= "" and allowedList or "ห้ามจอดทุกอาชีพ") .. ")"
                )

                -- 3. เรียกใช้ Text UI (ปรับ Style สำหรับ bottom-center โดยเฉพาะ)
                lib.showTextUI(uiMsg, {
                    position = "bottom-center",
                    icon = statusIcon,
                    iconColor = statusColor,
                    style = {
                        borderRadius = '12px',
                        backgroundColor = 'rgba(10, 10, 10, 0.9)',
                        color = '#ffffff',
                        borderBottom = '4px solid ' .. statusColor, -- เส้นสีเน้นสถานะที่ขอบล่าง
                        padding = '15px 25px',
                        minWidth = '320px',
                        boxShadow = '0 4px 15px rgba(0, 0, 0, 0.6)'
                    }
                })
            else
                -- รีเซ็ตค่าเมื่อออกจากโซน
                insidenoParkingZone = false
                lib.hideTextUI()
            end
        end)
    end
end)
