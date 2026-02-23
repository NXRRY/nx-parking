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
                if zoneData.allowJobs then
                    if zoneData.allowJobs[PlayerJob] ~= nil then
                        isAllowed = true
                    end
                else
                    isAllowed = false
                end
                isInsideParkingZone = not isAllowed
            else
                isInsideParkingZone = false
            end
        end)
    end
end)
