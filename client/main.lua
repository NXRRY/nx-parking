-- parking/client.lua (Refactored)

local QBCore = exports['qb-core']:GetCoreObject()
local strings = Config.Strings
local depotPeds = {}  -- Store NPCs for cleanup
local vehicleCache = {} -- [plate] = entity

-- ============================
-- 1. NOTIFICATION HELPERS
-- ============================
local notifySettings = {
    success = { icon = 'check-circle', color = '#48BB78', chatIcon = '✅', chatTitle = strings['notify_success'] },
    error   = { icon = 'xmark-circle', color = '#F56565', chatIcon = '🚨', chatTitle = strings['notify_error'] },
    warning = { icon = 'exclamation-triangle', color = '#ECC94B', chatIcon = '⚠️', chatTitle = strings['notify_warning'] },
    inform  = { icon = 'info-circle', color = '#4299E1', chatIcon = '📩', chatTitle = strings['notify_info'] }
}

local function showNotification(text, type, timeout)
    type = type or 'inform'
    local settings = notifySettings[type] or notifySettings.inform
    local oxType = type == 'inform' and 'info' or type
    timeout = timeout or 5000

    if Config.notifyType == 'ox' then
        lib.notify({
            title = strings.menu_title or 'SYSTEM',
            description = text,
            type = oxType,
            icon = settings.icon,
            iconColor = settings.color,
            position = 'bottom-center',
            duration = timeout,
            showDuration = true,
            iconAnimation = (type == 'error' or type == 'warning') and 'bounce' or nil
        })
    elseif Config.notifyType == 'chat' then
        local chatColor = {255, 255, 255}
        if type == 'error' then
            chatColor = {255, 50, 50}
        elseif type == 'success' then
            chatColor = {50, 255, 150}
        elseif type == 'inform' then
            chatColor = {50, 200, 255}
        end
        TriggerEvent('chat:addMessage', {
            color = chatColor,
            multiline = true,
            args = {
                string.format('%s ^7| %s', settings.chatIcon, settings.chatTitle),
                string.format('^7%s', text)
            }
        })
    else  -- default to QBCore.Notify
        TriggerEvent('QBCore:Notify', text, type, timeout)
    end
end

-- ============================
-- 2. VEHICLE HELPER FUNCTIONS
-- ============================
local function canParkVehicle(ped, veh)
    if not veh or veh == 0 then
        showNotification(strings.not_in_veh, 'error')
        return false
    end
    if insidenoParkingZone then   -- global variable set elsewhere
        showNotification(strings.no_parking_zone, 'error')
        return false
    end
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        showNotification(strings.not_driver, 'error')
        return false
    end
    if GetEntitySpeed(veh) * 3.6 > 5 then   -- speed > 5 km/h
        showNotification(strings.slow_down, 'error')
        return false
    end
    return true
end

local function fadeEntity(entity, duration, fadeIn)
    if not DoesEntityExist(entity) then return end
    local start, stop, step = fadeIn and 0 or 255, fadeIn and 255 or 0, fadeIn and 5 or -5
    SetEntityAlpha(entity, start, false)
    for alpha = start, stop, step do
        SetEntityAlpha(entity, alpha, false)
        Wait(duration / 50)  -- 50 steps (255/5 ≈ 51)
    end
    if fadeIn then
        ResetEntityAlpha(entity)
    else
        SetEntityAlpha(entity, 0, false)
    end
end

local function getStreetName(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return GetStreetNameFromHashKey(streetHash)
end

local function enterVehicleNormally(ped, vehicle)
    ClearPedTasks(ped)
    TaskEnterVehicle(ped, vehicle, 10000, -1, 1.0, 1, 0)
end

local function formatThousand(v)
    local s = string.format("%d", math.floor(v))
    local pos = string.len(s) % 3
    if pos == 0 then pos = 3 end
    return string.sub(s, 1, pos) .. string.gsub(string.sub(s, pos + 1), "(...)", ",%1")
end

local function normalizePlate(plate)
    return plate and plate:gsub("%s+", ""):upper() or nil
end

local function addVehicleToCache(plate, entity)
    local clean = normalizePlate(plate)
    if clean and DoesEntityExist(entity) then
        vehicleCache[clean] = entity
    end
end

local function removeVehicleFromCache(plate)
    local clean = normalizePlate(plate)
    if clean then
        vehicleCache[clean] = nil
    end
end

local function getVehicleFromCache(plate)
    local clean = normalizePlate(plate)
    if not clean then return false, nil end
    local entity = vehicleCache[clean]
    if entity and DoesEntityExist(entity) then
        return true, entity
    end
    vehicleCache[clean] = nil
    return false, nil
end

local function getVehicleByPlate(plate)
    local found, entity = getVehicleFromCache(plate)
    if found then
        return true, entity
    end

    local cleanPlate = normalizePlate(plate)
    if not cleanPlate then return false, nil end

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            local currentPlate = normalizePlate(GetVehicleNumberPlateText(veh))
            if currentPlate == cleanPlate then
                addVehicleToCache(cleanPlate, veh)
                return true, veh
            end
        end
    end

    return false, nil
end

local function isSpawnPointClear(coords, radius)
    local ray = StartShapeTestCapsule(
        coords.x, coords.y, coords.z,
        coords.x, coords.y, coords.z + 0.5,
        radius, 10, 0, 7
    )
    local _, hit = GetShapeTestResult(ray)
    return hit == 0
end

local function openPoliceImpoundMenu(plate, netId)
    local reasonOptions = {}
    for i, v in ipairs(Config.ImpoundReasons) do
        table.insert(reasonOptions, { label = v.label, value = i })
    end
    local input = lib.inputDialog(strings.police_impound_header, {
        { type = 'input', label = strings.police_impound_plate_label, default = plate, disabled = true },
        { 
            type = 'select', 
            label = strings.police_impound_type_label, 
            options = {
                { label = strings.police_impound_type_impound, value = 'impound' },
                { label = strings.police_impound_type_depot, value = 'depot' }
            },
            required = true 
        },
        { 
            type = 'select', 
            label = strings.police_impound_reason_label, 
            options = reasonOptions,
            required = true 
        },
    })

    if not input then return end

    local actionType = input[2]
    local selectedReasonIndex = tonumber(input[3])
    local reasonData = Config.ImpoundReasons[selectedReasonIndex]

    local finePrice = reasonData.price
    local impoundTime = reasonData.time

    local alert = lib.alertDialog({
        header = strings.police_impound_confirm_header,
        content = string.format(strings.police_impound_content_template, 
            plate, 
            actionType == 'impound' and strings.police_impound_type_impound or strings.police_impound_type_depot, 
            reasonData.label, 
            formatThousand(finePrice), 
            impoundTime),
        centered = true,
        cancel = true,
        labels = {
            confirm = strings.police_impound_confirm_btn,
            cancel = strings.police_impound_cancel_btn
        }
    })

    if alert == 'confirm' then
        TriggerServerEvent('parking:server:processImpound', netId, plate, actionType, finePrice, impoundTime, reasonData.label)
    end
end

-- ============================
-- 3. INITIALIZATION
-- ============================
if Config.EnableParkCommand then
    RegisterCommand('park', function()
        TriggerEvent('parking:client:parkVehicle')
    end, false)
end

-- ============================
-- 4. PARKING EVENTS
-- ============================
RegisterNetEvent('parking:client:parkVehicle', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not canParkVehicle(ped, veh) then return end

    QBCore.Functions.TriggerCallback('parking:server:checkOwnership', function(isOwner)
        if not isOwner then
            showNotification(strings.not_owner, 'error')
            return
        end

        if not lib.progressCircle({
            duration = 5000,
            label = strings.prog_parking,
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true, combat = true }
        }) then
            showNotification(strings.park_cancel, 'error')
            return
        end

        SetVehicleEngineOn(veh, false, false, true)
        TaskLeaveVehicle(ped, veh, 1)
        while IsPedInVehicle(ped, veh, true) do Wait(100) end

        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleHasBeenOwnedByPlayer(veh, true)
        if not NetworkGetEntityIsNetworked(veh) then
            NetworkRegisterEntityAsNetworked(veh)
        end
        local netId = NetworkGetNetworkIdFromEntity(veh)

        SetVehicleDoorsLocked(veh, 2)
        FreezeEntityPosition(veh, true)

        SetTimeout(2000, function()
            if DoesEntityExist(veh) then
                SetVehicleUndriveable(veh, true)
                SetEntityInvincible(veh, true)
                fadeEntity(veh, 1000, false)
                showNotification(strings.park_success, 'success')
                TriggerServerEvent('parking:server:UpdateVehicleData', netId, 1, GetVehicleFuelLevel(veh))
            end
        end)
    end, GetVehicleNumberPlateText(veh))
end)

RegisterNetEvent('parking:client:createtarget', function(netId)
    local timeout = 0
    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then return end
    fadeEntity(veh, 500, true)

    exports['qb-target']:AddTargetEntity(veh, {
        options = {
            {
                type = "client",
                icon = "fas fa-key",
                label = strings.target_take_out,
                action = function(entity)
                    local nId = NetworkGetNetworkIdFromEntity(entity)
                    TriggerEvent("parking:client:takeOutVehicle", nId)
                end
            },
            {
                type = "client",
                action = function(entity)
                    TriggerEvent("parking:client:checkVehicleStatus", { entity = entity })
                end,
                icon = "fas fa-info-circle",
                label = strings.target_check,
            }
        },
        distance = 2.5,
    })
end)

RegisterNetEvent('parking:client:removetarget', function(netId)
    if NetworkDoesEntityExistWithNetworkId(netId) then
        local veh = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(veh) then
            exports['qb-target']:RemoveTargetEntity(veh)
        end
    end
end)

RegisterNetEvent('parking:client:takeOutVehicle', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then return end

    local plate = GetVehicleNumberPlateText(veh)

    QBCore.Functions.TriggerCallback('parking:server:getDepotPrice', function(depotPrice)
        if depotPrice > 0 then
            showNotification(string.format(strings.depot_fee_required, depotPrice), 'error')
            return
        end

        if not lib.progressCircle({
            duration = 5000,
            label = strings.prog_take_out,
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true, combat = true }
        }) then
            showNotification(strings.take_out_cancel, 'error')
            return
        end

        -- Release vehicle
        fadeEntity(veh, 500, true)
        SetVehicleDoorsLocked(veh, 1)
        FreezeEntityPosition(veh, false)
        SetVehicleUndriveable(veh, false)
        SetEntityInvincible(veh, false)
        SetVehicleEngineOn(veh, true, false, true)

        SetEntityAsNoLongerNeeded(veh)
        SetVehicleHasBeenOwnedByPlayer(veh, true)

        showNotification(strings.take_out_success, 'success')
        TriggerServerEvent('parking:server:UpdateVehicleData', netId, 0, GetVehicleFuelLevel(veh))

        enterVehicleNormally(PlayerPedId(), veh)
    end, plate)
end)

RegisterNetEvent('parking:client:checkVehicleStatus', function(data)
    local vehicle = data.entity
    if not DoesEntityExist(vehicle) then return end

    local plate = GetVehicleNumberPlateText(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    local PlayerData = QBCore.Functions.GetPlayerData()
    local isPolice = (PlayerData.job.name == 'police' and PlayerData.job.onduty)

    QBCore.Functions.TriggerCallback('parking:server:checkOwnership', function(isOwner)
        QBCore.Functions.TriggerCallback('parking:server:getDepotPrice', function(depotPrice)
            
            local engineHealth = math.floor(GetVehicleEngineHealth(vehicle) / 10)
            local fuel = math.floor(exports['LegacyFuel']:GetFuel(vehicle))

            local options = {
                {
                    title = strings.status_plate_prefix .. ' ' .. plate,
                    description = isOwner and strings.status_owner_yes or strings.status_owner_no,
                    icon = 'car-side',
                    readOnly = true
                },
                {
                    title = strings.engine_title,
                    progress = engineHealth,
                    colorScheme = engineHealth > 70 and 'green' or engineHealth > 35 and 'yellow' or 'red',
                },
                {
                    title = strings.fuel_title,
                    progress = fuel,
                    colorScheme = 'blue',
                }
            }

            if isOwner then
                local formattedPrice = formatThousand(depotPrice or 0)
                table.insert(options, {
                    title = strings.status_takeout_title,
                    description = (depotPrice > 0 and string.format(strings.status_takeout_fee_desc, formattedPrice) or strings.status_takeout_free_desc),
                    icon = 'key',
                    iconColor = '#5fb6ff',
                    onSelect = function()
                        TriggerServerEvent("parking:server:payAndTakeOut", netId, plate)
                    end
                })
            end

            if isPolice then
                table.insert(options, {
                    title = strings.status_police_menu_title,
                    description = strings.status_police_menu_desc,
                    icon = 'shield-halved',
                    iconColor = '#3b82f6',
                    arrow = true,
                    onSelect = function()
                        openPoliceImpoundMenu(plate, netId)
                    end
                })
            end

            lib.registerContext({
                id = 'parking_status_menu',
                title = strings.status_menu_header,
                options = options
            })
            lib.showContext('parking_status_menu')

        end, plate)
    end, plate)
end)

--- Show vehicle list menu
RegisterNetEvent('parking:client:checkVehicleList', function()
    QBCore.Functions.TriggerCallback('parking:server:getVehicleList', function(vehicles)
        if not vehicles or #vehicles == 0 then
            showNotification(strings.list_not_found_desc, 'error')
            return
        end

        local options = {}
        for _, v in ipairs(vehicles) do
            local statusText = ""
            local statusIcon = "car"
            if v.state == 0 then
                statusText = strings.status_list_out
                statusIcon = "circle-xmark"
            elseif v.state == 1 then
                statusText = strings.status_list_parked
                statusIcon = "circle-check"
            elseif v.state == 2 then
                statusText = strings.status_list_impounded
                statusIcon = "handcuffs"
            end

            local vehicleName = QBCore.Shared.Vehicles[v.vehicle] and QBCore.Shared.Vehicles[v.vehicle].name or v.vehicle
            table.insert(options, {
                title = vehicleName,
                description = strings.list_item_desc:format(v.plate, statusText),
                icon = statusIcon,
                arrow = true,
                onSelect = function()
                    TriggerEvent('parking:client:showVehicleDetail', v)
                end
            })
        end

        lib.registerContext({
            id = 'vehicle_list_menu',
            title = strings.list_menu_title,
            options = options
        })
        lib.showContext('vehicle_list_menu')
    end)
end)

--- Show detailed vehicle info
RegisterNetEvent('parking:client:showVehicleDetail', function(v)
    local rawCoords = type(v.coords) == 'string' and json.decode(v.coords) or v.coords
    if rawCoords == nil then 
        rawCoords = Config.DefaultSpawnCoords
    end
    local vCoords = vector3(rawCoords.x or 0.0, rawCoords.y or 0.0, rawCoords.z or 0.0)

    local streetName = getStreetName(vCoords)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - vCoords)

    local rotation = type(v.rotation) == 'string' and json.decode(v.rotation) or v.rotation
    local heading = (rotation and rotation.z) or 0.0
    if heading == 0.0 then 
        heading = Config.DefaultSpawnCoords.w
    end

    local statusText = strings.status_unknown
    local color = "white"
    if v.state == 0 then
        statusText = strings.status_out
        color = "#ff4d4d"
    elseif v.state == 1 then
        statusText = strings.status_parked
        color = "#2ecc71"
    elseif v.state == 2 then
        statusText = strings.status_impounded
        color = "#f1c40f"
    end

    local actionItem = {}
    local found, vehEntity = getVehicleByPlate(v.plate)

    if v.state == 1 then
        -- Parked
        if distance > 20.0 then
            actionItem = {
                title = strings.detail_action_gps_parked,
                description = string.format(strings.detail_action_gps_desc, distance),
                icon = 'location-arrow',
                iconColor = '#3498db',
                onSelect = function()
                    SetNewWaypoint(vCoords.x, vCoords.y)
                    showNotification(strings.gps_set_parked, 'inform')
                end
            }
        else
            actionItem = {
                title = strings.detail_action_takeout_near,
                description = strings.detail_action_takeout_near_desc,
                icon = 'key',
                iconColor = '#2ecc71',
                onSelect = function()
                    if found then
                        local nId = NetworkGetNetworkIdFromEntity(vehEntity)
                        TriggerEvent('parking:client:takeOutVehicle', nId)
                    else
                        if lib.progressCircle({
                            duration = 5000,
                            label = strings.detail_action_retrieving,
                            position = 'bottom',
                            useWhileDead = false,
                            canCancel = true,
                            disable = { car = true, move = true, combat = true }
                        }) then
                            TriggerServerEvent('parking:server:respawnParkedVehicle', v.plate, vCoords, heading)
                        else
                            showNotification(strings.cancel_retrieve, 'error')
                        end
                    end
                end
            }
        end
    elseif v.state == 0 then
        -- Out
        if found then
            local currentCoords = GetEntityCoords(vehEntity)
            actionItem = {
                title = strings.detail_action_track,
                description = strings.detail_action_track_desc,
                icon = 'radar',
                iconColor = '#e67e22',
                onSelect = function()
                    SetNewWaypoint(currentCoords.x, currentCoords.y)
                    showNotification(strings.gps_set_current, 'success')
                end
            }
        else
            actionItem = {
                title = strings.detail_action_depot_contact,
                description = strings.detail_action_depot_contact_desc,
                icon = 'warehouse',
                iconColor = '#95a5a6',
                onSelect = function()
                    showNotification(strings.vehicle_not_found_depot, 'error')
                end
            }
        end
    else
        -- Impounded or other
        actionItem = {
            title = strings.detail_action_blocked,
            description = strings.detail_action_blocked_desc,
            icon = 'ban',
            iconColor = '#c0392b',
            disabled = true
        }
    end

    lib.registerContext({
        id = 'vehicle_detail_menu',
        title = strings.vehicle_detail_title:format(v.plate),
        menu = 'vehicle_list_menu',
        options = {
            actionItem,
            {
                title = strings.location_title,
                description = strings.location_desc:format(streetName),
                icon = 'location-dot',
                onSelect = function()
                    SetNewWaypoint(vCoords.x, vCoords.y)
                    showNotification(strings.location_notify, 'inform')
                end
            },
            {
                title = strings.status_title,
                description = statusText,
                icon = 'info-circle',
                iconColor = color,
                readOnly = true
            },
            {
                title = strings.engine_title,
                progress = math.ceil(v.engine / 10),
                colorScheme = (v.engine > 700 and 'green' or v.engine > 300 and 'orange' or 'red'),
                icon = 'microchip'
            },
            {
                title = strings.fuel_title,
                progress = math.ceil(v.fuel),
                colorScheme = (v.fuel > 50 and 'yellow' or 'red'),
                icon = 'gas-pump'
            }
        }
    })
    lib.showContext('vehicle_detail_menu')
end)

--- 
RegisterNetEvent('parking:client:setupRespawnedVehicle', function(netId, mods)
    local timeout = 0
    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout < 1000 do
        Wait(10)
        timeout = timeout + 10
    end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then return end

    if mods.heading then
        SetEntityHeading(veh, mods.heading)
    end
    QBCore.Functions.SetVehicleProperties(veh, mods)

    SetEntityVisible(veh, true, false)
    SetEntityAlpha(veh, 255, false)
    NetworkFadeInEntity(veh, 1)

    FreezeEntityPosition(veh, false)
    SetVehicleUndriveable(veh, false)
    SetEntityInvincible(veh, false)

    TriggerEvent("vehiclekeys:client:SetOwner", GetVehicleNumberPlateText(veh))
    showNotification(strings.respawn_success, "success")
end)


-- ============================
-- 5. DEPOT SYSTEM (NPC & MENU)
-- ============================

CreateThread(function()
    local npcModel = `s_m_y_cop_01`
    RequestModel(npcModel)
    while not HasModelLoaded(npcModel) do Wait(10) end

    for index, depot in ipairs(Config.Depot) do 
        local blip = AddBlipForCoord(depot.coords.x, depot.coords.y, depot.coords.z)
        SetBlipSprite(blip, depot.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, depot.blip.scale)
        SetBlipColour(blip, depot.blip.color)
        SetBlipAsShortRange(blip, true)
        SetBlipCategory(blip, 12)
        local entryKey = "DPT_" .. index
        local blipName = "Depot : " .. depot.blip.name
        AddTextEntry(entryKey, blipName)
        BeginTextCommandSetBlipName(entryKey)
        EndTextCommandSetBlipName(blip)

        -- NPC
        local ped = CreatePed(0, npcModel, depot.coords.x, depot.coords.y, depot.coords.z - 1.0, depot.coords.w, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CLIPBOARD", 0, true)
        table.insert(depotPeds, ped)

        -- Target (จุดที่ต้องแก้ไข)
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    type = "client",
                    event = "parking:client:openDepotMenu",
                    icon = "fas fa-clipboard-list",
                    label = string.format(strings.depot_target_label, depot.name),
                    depotIndex = index -- *** แก้ไขจาก depot.index เป็น index ***
                }
            },
            distance = 2.0
        })
    end
    SetModelAsNoLongerNeeded(npcModel)
end)

RegisterNetEvent('parking:client:openDepotMenu', function(data)
    local index = data.depotIndex or 1
    local currentDepot = Config.Depot[index]
    if not currentDepot then return end

    QBCore.Functions.TriggerCallback('parking:server:getVehicleList', function(vehicles)
        local options = {}
        for _, v in ipairs(vehicles) do
            if v.state == 0 then
                local price = v.depotprice or 0
                table.insert(options, {
                    title = GetDisplayNameFromVehicleModel(v.vehicle) .. " [" .. v.plate .. "]",
                    description = string.format(strings.depot_item_desc, price),
                    icon = 'car',
                    onSelect = function()
                        TriggerServerEvent('parking:server:takeOutVehicleDepot', v.plate, index)
                    end
                })
            end
        end

        if #options == 0 then
            showNotification(strings.no_vehicle_in_depot, 'error')
            return
        end

        lib.registerContext({
            id = 'depot_list_menu',
            title = currentDepot.name,
            options = options
        })
        lib.showContext('depot_list_menu')
    end)
end)

--- Spawn vehicle from depot (server-triggered)
RegisterNetEvent('parking:client:spawnVehicleFromDepot', function(plate, mods, index)
    local exists, _ = getVehicleByPlate(plate)
    if exists then
        showNotification(string.format(strings.vehicle_already_exists, plate), 'error')
        return
    end

    local depot = Config.Depot[index]
    local vehicleData = type(mods) == "string" and json.decode(mods) or mods
    local model = vehicleData.model or vehicleData.vehicle

    local spawnCoords = nil
    for _, coords in ipairs(depot.spawnPoint) do
        if isSpawnPointClear(coords, 2.5) then
            spawnCoords = coords
            break
        end
    end

    if not spawnCoords then
        showNotification(strings.spawn_point_blocked, 'error')
        return
    end

    QBCore.Functions.SpawnVehicle(model, function(veh)
        QBCore.Functions.SetVehicleProperties(veh, vehicleData)
        SetVehicleNumberPlateText(veh, plate)

        local fuel = vehicleData.fuelLevel or 100.0
        if exports['LegacyFuel'] then
            exports['LegacyFuel']:SetFuel(veh, fuel)
        else
            SetVehicleFuelLevel(veh, fuel)
        end

        if vehicleData.bodyHealth then SetVehicleBodyHealth(veh, vehicleData.bodyHealth) end
        if vehicleData.engineHealth then SetVehicleEngineHealth(veh, vehicleData.engineHealth) end

        TriggerEvent("vehiclekeys:client:SetOwner", plate)

        SetEntityHeading(veh, spawnCoords.w)
        SetVehicleOnGroundProperly(veh)

        addVehicleToCache(plate, veh)

        showNotification(string.format(strings.spawn_success, plate, math.floor(fuel)), 'success')
    end, spawnCoords, true)
end)

-- Cleanup NPCs on resource stop
AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    for _, ped in ipairs(depotPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)


------------------------------
local currentOption = nil

RegisterNetEvent('parking:client:radialmenusetup', function(type)
    updateRadialMenu(type)
end)

function updateRadialMenu(type)
    if currentOption then
        exports['qb-radialmenu']:RemoveOption(currentOption)
        currentOption = nil
    end

    if type == "park" then
        currentOption = exports['qb-radialmenu']:AddOption({
            id = 'park_system',
            title = strings.radial_park,
            icon = 'square-parking',
            type = 'client',
            event = 'parking:client:parkVehicle',
            shouldClose = true
        })
    elseif type == "list" then
        currentOption = exports['qb-radialmenu']:AddOption({
            id = 'park_system_list', 
            title = strings.radial_list,
            icon = 'clipboard-list',
            type = 'client',
            event = 'parking:client:checkVehicleList',
            shouldClose = true
        })
    end
end

local impoundPed = nil

CreateThread(function()
    local model = `s_m_m_security_01`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local coords = vector4(421.25, -1010.75, 29.13, 178.27)
    impoundPed = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
    
    SetEntityAsMissionEntity(impoundPed, true, true)
    SetBlockingOfNonTemporaryEvents(impoundPed, true)
    SetEntityInvincible(impoundPed, true)
    FreezeEntityPosition(impoundPed, true)

    exports['qb-target']:AddTargetEntity(impoundPed, {
        options = {
            {
                type = "client",
                event = "parking:client:openImpoundMenu",
                icon = "fas fa-warehouse",
                label = strings.impound_target_label,
            },
        },
        distance = 2.0
    })
end)

RegisterNetEvent('parking:client:openImpoundMenu', function()
    QBCore.Functions.TriggerCallback('parking:server:getImpoundedVehicles', function(vehicles)
        if not vehicles or #vehicles == 0 then
            showNotification(strings.no_impounded_vehicle, 'error')
            return
        end

        local options = {}
        for _, v in ipairs(vehicles) do
            table.insert(options, {
                title = v.modelName .. " [" .. v.plate .. "]",
                description = string.format(strings.impound_item_desc, v.date, v.charge, v.fee),
                icon = 'car',
                metadata = {
                    {label = strings.impound_time_left, value = v.timeLeft}
                },
                readOnly = true,
            })
        end

        lib.registerContext({
            id = 'impound_list_menu',
            title = strings.impound_menu_title,
            options = options
        })
        lib.showContext('impound_list_menu')
    end)
end)

local officerPed = nil

CreateThread(function()
    local model = `s_m_m_security_01` 
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local coords = vector4(426.73, -1010.04, 28.98, 92.61)
    officerPed = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
    
    SetEntityAsMissionEntity(officerPed, true, true)
    SetBlockingOfNonTemporaryEvents(officerPed, true)
    SetEntityInvincible(officerPed, true)
    FreezeEntityPosition(officerPed, true)

    exports['qb-target']:AddTargetEntity(officerPed, {
        options = {
            {
                type = "client",
                action = function()
                    openPoliceSearchMenu()
                end,
                icon = "fas fa-address-card",
                label = strings.police_target_label,
                job = "police",
            },
        },
        distance = 2.0
    })
end)

function openPoliceSearchMenu()
    local nearbyPlayers = QBCore.Functions.GetPlayersFromCoords(GetEntityCoords(PlayerPedId()), 10.0)
    local playerIds = {}

    for _, v in pairs(nearbyPlayers) do
        table.insert(playerIds, GetPlayerServerId(v))
    end

    if #playerIds == 0 then
        showNotification(strings.no_civilians_nearby, 'error')
        return
    end

    QBCore.Functions.TriggerCallback('parking:server:getNearbyPlayersInfo', function(playerOptions)
        if not playerOptions or #playerOptions == 0 then return end

        local input = lib.inputDialog(strings.police_search_header, {
            { 
                type = 'select', 
                label = strings.police_search_label, 
                options = playerOptions,
                required = true 
            },
        })

        if not input then return end
        
        TriggerServerEvent('parking:server:getOfficerCheckImpound', input[1])
    end, playerIds)
end

RegisterNetEvent('parking:client:showImpoundDetails', function(vehicles, citizenName)
    local options = {}

    for _, v in ipairs(vehicles) do
        table.insert(options, {
            title = v.modelName .. " [" .. v.plate .. "]",
            description = string.format(strings.police_impound_details_desc, 
                v.date, v.charge, v.fee, v.timeLeft),
            icon = 'car',
            onSelect = function()
                local alert = lib.alertDialog({
                    header = strings.police_release_header,
                    content = string.format(strings.police_release_content, v.plate),
                    centered = true,
                    cancel = true
                })

                if alert == 'confirm' then
                    TriggerServerEvent('parking:server:releaseVehicleByOfficer', v.plate, Config.SpawnimpoundCoords)
                end
            end
        })
    end

    lib.registerContext({
        id = 'police_impound_view',
        title = string.format(strings.police_impound_view_title, citizenName),
        options = options
    })
    lib.showContext('police_impound_view')
end)

RegisterNetEvent('parking:client:spawnReleasedVehicle', function(model, plate, coords, vehicleMods)
    local vehicleModel = type(model) == 'string' and GetHashKey(model) or model
    if not IsModelInCdimage(vehicleModel) then 
        return print("^1[nx-parking] Error: Invalid vehicle model: " .. tostring(model) .. "^7")
    end

    QBCore.Functions.SpawnVehicle(vehicleModel, function(veh)
        SetEntityCoords(veh, coords.x, coords.y, coords.z)
        SetEntityHeading(veh, coords.w)
        SetVehicleNumberPlateText(veh, plate)
        if vehicleMods and vehicleMods ~= "" and vehicleMods ~= "null" then
            local props = nil
            if type(vehicleMods) == 'table' then
                props = vehicleMods
            else
                props = json.decode(vehicleMods)
            end

            if props then
                QBCore.Functions.SetVehicleProperties(veh, props)
            end
        else
            if exports['LegacyFuel'] then
                exports['LegacyFuel']:SetFuel(veh, 100.0)
            end
            print("^3[nx-parking] Warning: No mods found for plate " .. plate .. ". Spawning stock vehicle.^7")
        end
        
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleEngineOn(veh, true, true, false)
        
        TriggerEvent("vehiclekeys:client:SetOwner", plate)
        
        showNotification(string.format(Config.Strings.release_success, plate), 'success')
    end, coords, true)
end)

CreateThread(function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        updateRadialMenu("park")
    else
        updateRadialMenu("list")
    end
end)