-- parking_zones/client.lua

local QBCore = exports['qb-core']:GetCoreObject()
local PlayerJob = nil
local CreatedZones = {}

insidenoParkingZone = false

-- ============================
-- 1. JOB TRACKING
-- ============================
local function updateJob()
    local PlayerData = QBCore.Functions.GetPlayerData()
    PlayerJob = PlayerData and PlayerData.job and PlayerData.job.name or nil
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        updateJob()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', updateJob)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo.name
end)

-- ============================
-- 2. ZONE HANDLING HELPERS
-- ============================

local function formatAllowedJobList(allowJobs)
    if not allowJobs then return "" end
    local jobs = {}
    for jobName, _ in pairs(allowJobs) do
        jobs[#jobs + 1] = jobName:gsub("^%l", string.upper)
    end
    return table.concat(jobs, ", ")
end

local function isJobAllowed(allowJobs)
    if not allowJobs or not PlayerJob then return false end
    return allowJobs[PlayerJob] ~= nil
end

local function buildZoneMessage(zoneData, isAllowed, allowedList)
    local title = zoneData.title or zoneData.name or Config.Strings.zone_default_title
    local statusMsg = ""

    if isAllowed then
        statusMsg = Config.Strings.zone_allowed_msg
    else
        local listText = (allowedList ~= "") and allowedList or Config.Strings.zone_no_jobs_msg
        statusMsg = string.format(Config.Strings.zone_restricted_msg, listText)
    end
    
    return string.format("# %s\n---\n%s", title, statusMsg)
end

local function getStatusStyle(isAllowed)
    if isAllowed then
        return "#2ecc71", "square-check"
    else
        return "#ff4d4d", "circle-exclamation"
    end
end

local function handleZoneUI(zoneData, isInside)
    if isInside then
        updateJob()

        local isAllowed = isJobAllowed(zoneData.allowJobs)
        insidenoParkingZone = not isAllowed

        local allowedList = formatAllowedJobList(zoneData.allowJobs)
        local msg = buildZoneMessage(zoneData, isAllowed, allowedList)
        local statusColor, statusIcon = getStatusStyle(isAllowed)

        lib.showTextUI(msg, {
            position = "bottom-center",
            icon = statusIcon,
            iconColor = statusColor,
            style = {
                borderRadius = '12px',
                backgroundColor = 'rgba(10, 10, 10, 0.9)',
                color = '#ffffff',
                borderBottom = '4px solid ' .. statusColor,
                padding = '15px 25px',
                minWidth = '320px',
                boxShadow = '0 4px 15px rgba(0, 0, 0, 0.6)'
            }
        })
    else
        insidenoParkingZone = false
        lib.hideTextUI()
    end
end

-- ============================
-- 3. CREATE ZONES FROM CONFIG
-- ============================
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
            handleZoneUI(zoneData, isPointInside)
        end)
    end
end)