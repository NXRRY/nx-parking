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

--- Unified notification function
---@param text string
---@param type string 'success'|'error'|'warning'|'inform'
---@param timeout number? (default 5000)
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

--- Check if player can park the vehicle
---@param ped number
---@param veh number
---@return boolean
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

--- Fade entity in/out
---@param entity number
---@param duration number ms
---@param fadeIn boolean true = fade in, false = fade out
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

--- Get street name from coordinates
---@param coords vector3
---@return string
local function getStreetName(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return GetStreetNameFromHashKey(streetHash)
end

--- Make ped enter vehicle normally
---@param ped number
---@param vehicle number
local function enterVehicleNormally(ped, vehicle)
    ClearPedTasks(ped)
    TaskEnterVehicle(ped, vehicle, 10000, -1, 1.0, 1, 0)
end

--- Format number with thousand separators
---@param v number
---@return string
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

    -- cleanup ghost reference
    vehicleCache[clean] = nil
    return false, nil
end

--- Find a vehicle on the map by plate
---@param plate string
---@return boolean, number|nil
local function getVehicleByPlate(plate)
    local found, entity = getVehicleFromCache(plate)
    if found then
        return true, entity
    end

    -- fallback scan once
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

--- Check if a spawn point is clear
---@param coords table {x,y,z}
---@param radius number
---@return boolean
local function isSpawnPointClear(coords, radius)
    local ray = StartShapeTestCapsule(
        coords.x, coords.y, coords.z,
        coords.x, coords.y, coords.z + 0.5,
        radius, 10, 0, 7
    )
    local _, hit = GetShapeTestResult(ray)
    return hit == 0
end

-- ============================
-- 3. INITIALIZATION
-- ============================
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    TriggerServerEvent('parking:server:requestMyVehicles')
end)

-- Park command
if Config.EnableParkCommand then
    RegisterCommand('park', function()
        TriggerEvent('parking:client:parkVehicle')
    end, false)
end

-- ============================
-- 4. PARKING EVENTS
-- ============================

--- Park the current vehicle
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

        -- Park the vehicle
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
                TriggerEvent('parking:client:createtarget', netId)
                TriggerServerEvent('parking:server:UpdateVehicleData', netId, 1, GetVehicleFuelLevel(veh))
            end
        end)
    end, GetVehicleNumberPlateText(veh))
end)

--- Create target on parked vehicle
RegisterNetEvent('parking:client:createtarget', function(netId)
    local timeout = 0
    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout < 100 do
        Wait(10)
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

--- Take out a parked vehicle
RegisterNetEvent('parking:client:takeOutVehicle', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then return end

    local plate = GetVehicleNumberPlateText(veh)

    QBCore.Functions.TriggerCallback('parking:server:getDepotPrice', function(depotPrice)
        if depotPrice > 0 then
            showNotification(string.format("ต้องชำระค่าธรรมเนียม $%s ก่อนนำรถออก!", depotPrice), 'error')
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

        exports['qb-target']:RemoveTargetEntity(veh)
        showNotification(strings.take_out_success, 'success')
        TriggerServerEvent('parking:server:UpdateVehicleData', netId, 0, GetVehicleFuelLevel(veh))

        enterVehicleNormally(PlayerPedId(), veh)
    end, plate)
end)

--- Show vehicle status menu
RegisterNetEvent('parking:client:checkVehicleStatus', function(data)
    local vehicle = data.entity
    if not DoesEntityExist(vehicle) then return end

    local plate = GetVehicleNumberPlateText(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    QBCore.Functions.TriggerCallback('parking:server:checkOwnership', function(isOwner)
        QBCore.Functions.TriggerCallback('parking:server:getDepotPrice', function(depotPrice)
            local engineHealth = math.floor(GetVehicleEngineHealth(vehicle) / 10)
            local bodyHealth = math.floor(GetVehicleBodyHealth(vehicle) / 10)
            local fuel = math.floor(exports['LegacyFuel']:GetFuel(vehicle))

            local options = {
                {
                    title = 'ทะเบียน: ' .. plate,
                    description = isOwner and "✅ ยานพาหนะของคุณ" or "🔒 ยานพาหนะของผู้อื่น",
                    icon = 'car-side',
                    readOnly = true
                },
                {
                    title = 'สภาพเครื่องยนต์',
                    progress = engineHealth,
                    colorScheme = engineHealth > 70 and 'green' or engineHealth > 35 and 'yellow' or 'red',
                },
                {
                    title = 'ระดับน้ำมัน',
                    progress = fuel,
                    colorScheme = 'blue',
                }
            }

            if isOwner then
                local formattedPrice = formatThousand(depotPrice)
                local priceLabel = depotPrice > 0 and ("💰 ค่าธรรมเนียม: $" .. formattedPrice) or "🆓 ไม่มีค่าใช้จ่าย"
                table.insert(options, {
                    title = 'นำรถออกจากพื้นที่จอด',
                    description = priceLabel .. "\nยืนยันชำระเงินและยกเลิกการจอด",
                    icon = 'key',
                    iconColor = depotPrice > 0 and '#ff4d4d' or '#5fb6ff',
                    onSelect = function()
                        TriggerServerEvent("parking:server:payAndTakeOut", netId, plate)
                    end
                })
            end

            lib.registerContext({
                id = 'parking_status_menu',
                title = 'Vehicle Diagnostic',
                options = options
            })
            lib.showContext('parking_status_menu')
        end, plate)
    end, plate)
end)

--- Spawn all stored vehicles (called from server)
RegisterNetEvent('parking:client:spawnAllStoredVehicles', function(vehicles)
    for _, data in ipairs(vehicles) do
        local plate = data.plate
        local exists, veh = getVehicleByPlate(plate)
        if exists then
            local netId = NetworkGetNetworkIdFromEntity(veh)
            TriggerEvent('parking:client:createtarget', netId)
        else
            -- Spawn new vehicle
            local model = data.vehicle or data.model
            model = type(model) == 'string' and joaat(model) or model
            QBCore.Functions.LoadModel(model)

            local coords = type(data.coords) == 'string' and json.decode(data.coords) or data.coords
            local spawnPos = vector3(coords.x, coords.y, coords.z)

            local rotation = type(data.rotation) == 'string' and json.decode(data.rotation) or data.rotation
            local heading = rotation.z

            local veh = CreateVehicle(model, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)

            -- Wait for network ID
            local netId = 0
            local timeout = 0
            while netId == 0 and timeout < 100 do
                netId = NetworkGetNetworkIdFromEntity(veh)
                Wait(10)
                timeout = timeout + 1
            end

            SetEntityHeading(veh, heading) 
            SetVehicleOnGroundProperly(veh)
            FreezeEntityPosition(veh, true)

            if rotation then
                SetEntityRotation(veh, rotation.x or 0.0, rotation.y or 0.0, rotation.z or 0.0, 2, true)
            end

            RequestCollisionAtCoord(spawnPos.x, spawnPos.y, spawnPos.z)
            while not HasCollisionLoadedAroundEntity(veh) do Wait(1) end
            SetVehicleOnGroundProperly(veh)

            -- Hide initially
            SetEntityAlpha(veh, 0, false)
            SetEntityCollision(veh, false, false)
            FreezeEntityPosition(veh, true)
            SetVehicleNumberPlateText(veh, plate)

            if rotation then
                SetEntityRotation(veh, rotation.x or 0.0, rotation.y or 0.0, rotation.z or 0.0, 2, true)
            end

            local mods = type(data.mods) == 'string' and json.decode(data.mods) or data.mods
            if mods then
                QBCore.Functions.SetVehicleProperties(veh, mods)
            end

            local fuel = data.fuel or data.fuelLevel or 100.0
            exports['qb-fuel']:SetFuel(veh, fuel)

            SetEntityAsMissionEntity(veh, true, true)
            SetVehicleDoorsLocked(veh, 2)
            SetVehicleUndriveable(veh, true)
            SetEntityInvincible(veh, true)

            SetVehicleLights(veh, 2)
            Wait(150)
            SetVehicleLights(veh, 0)

            -- Fade in
            fadeEntity(veh, 1000, true)

            addVehicleToCache(plate, veh)
            TriggerEvent('parking:client:createtarget', netId)
        end
    end
end)

--- Show vehicle list menu
RegisterNetEvent('parking:client:checkVehicleList', function()
    QBCore.Functions.TriggerCallback('parking:server:getVehicleList', function(vehicles)
        if not vehicles or #vehicles == 0 then
            lib.notify({
                title = strings.list_not_found_title,
                description = strings.list_not_found_desc,
                type = 'error'
            })
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
    local vCoords = vector3(rawCoords.x or 0.0, rawCoords.y or 0.0, rawCoords.z or 0.0)

    local streetName = getStreetName(vCoords)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - vCoords)

    local rotation = type(v.rotation) == 'string' and json.decode(v.rotation) or v.rotation
    local heading = (rotation and rotation.z) or 0.0

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
                title = "📌 ตั้งค่า GPS ไปยังจุดจอด",
                description = ("ห่างจากคุณ %.2f เมตร"):format(distance),
                icon = 'location-arrow',
                iconColor = '#3498db',
                onSelect = function()
                    SetNewWaypoint(vCoords.x, vCoords.y)
                    showNotification("มาร์คตำแหน่งจุดจอดแล้ว", 'inform')
                end
            }
        else
            actionItem = {
                title = "🔑 นำรถออกจากพื้นที่จอด",
                description = "คุณอยู่ใกล้รถแล้ว สามารถนำออกได้",
                icon = 'key',
                iconColor = '#2ecc71',
                onSelect = function()
                    if found then
                        local nId = NetworkGetNetworkIdFromEntity(vehEntity)
                        TriggerEvent('parking:client:takeOutVehicle', nId)
                    else
                        if lib.progressCircle({
                            duration = 5000,
                            label = "กำลังเรียกข้อมูลรถจากคลัง...",
                            position = 'bottom',
                            useWhileDead = false,
                            canCancel = true,
                            disable = { car = true, move = true, combat = true }
                        }) then
                            TriggerServerEvent('parking:server:respawnParkedVehicle', v.plate, vCoords, heading)
                        else
                            showNotification("ยกเลิกการเรียกข้อมูลรถ", 'error')
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
                title = "📡 ติดตามตำแหน่งรถปัจจุบัน",
                description = "ตรวจพบสัญญาณรถในพื้นที่ มาร์คพิกัดบนแผนที่",
                icon = 'radar',
                iconColor = '#e67e22',
                onSelect = function()
                    SetNewWaypoint(currentCoords.x, currentCoords.y)
                    showNotification("มาร์คตำแหน่งปัจจุบันของรถแล้ว", 'success')
                end
            }
        else
            actionItem = {
                title = "📂 ติดต่อเจ้าหน้าที่ Depot",
                description = "ไม่พบสัญญาณรถในพื้นที่ กรุณาตรวจสอบที่จุดเก็บรถ",
                icon = 'warehouse',
                iconColor = '#95a5a6',
                onSelect = function()
                    showNotification("ไม่พบรถในพื้นที่ กรุณาติดต่อเบิกที่ Depot", 'error')
                end
            }
        end
    else
        -- Impounded or other
        actionItem = {
            title = "🚫 ไม่สามารถเข้าถึงได้",
            description = "รถคันนี้ถูกระงับการเข้าถึงชั่วคราว",
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
                title = "ระดับความสมบูรณ์เครื่องยนต์",
                progress = math.ceil(v.engine / 10),
                colorScheme = (v.engine > 700 and 'green' or v.engine > 300 and 'orange' or 'red'),
                icon = 'microchip'
            },
            {
                title = "ระดับน้ำมัน",
                progress = math.ceil(v.fuel),
                colorScheme = (v.fuel > 50 and 'yellow' or 'red'),
                icon = 'gas-pump'
            }
        }
    })
    lib.showContext('vehicle_detail_menu')
end)

--- Setup respawned vehicle after depot retrieval
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
    showNotification("กู้คืนพิกัดรถสำเร็จ!", "success")
end)


-- ============================
-- 5. DEPOT SYSTEM (NPC & MENU)
-- ============================

CreateThread(function()
    local npcModel = `s_m_y_cop_01`
    RequestModel(npcModel)
    while not HasModelLoaded(npcModel) do Wait(10) end

    for _, depot in ipairs(Config.Depot) do
        -- Blip
        local blip = AddBlipForCoord(depot.coords.x, depot.coords.y, depot.coords.z)
        SetBlipSprite(blip, depot.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, depot.blip.scale)
        SetBlipColour(blip, depot.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(depot.blip.name)
        EndTextCommandSetBlipName(blip)

        -- NPC
        local ped = CreatePed(0, npcModel, depot.coords.x, depot.coords.y, depot.coords.z - 1.0, depot.coords.w, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CLIPBOARD", 0, true)
        table.insert(depotPeds, ped)

        -- Target
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    type = "client",
                    event = "parking:client:openDepotMenu",
                    icon = "fas fa-clipboard-list",
                    label = "เปิดดูรายการรถค้างจ่าย (" .. depot.name .. ")",
                    depotIndex = depot.index  -- assuming you have index in config
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
                    description = "ค่าธรรมเนียมเบิกคืน: $" .. price,
                    icon = 'car',
                    onSelect = function()
                        TriggerServerEvent('parking:server:takeOutVehicleDepot', v.plate, index)
                    end
                })
            end
        end

        if #options == 0 then
            showNotification("ไม่มีรถของคุณค้างอยู่ในคลังนี้", 'error')
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
    -- Check if vehicle already exists on map
    local exists, _ = getVehicleByPlate(plate)
    if exists then
        showNotification("รถทะเบียน " .. plate .. " อยู่บนโลกนี้แล้ว!", 'error')
        return
    end

    local depot = Config.Depot[index]
    local vehicleData = type(mods) == "string" and json.decode(mods) or mods
    local model = vehicleData.model or vehicleData.vehicle

    -- Find a free spawn point
    local spawnCoords = nil
    for _, coords in ipairs(depot.spawnPoint) do
        if isSpawnPointClear(coords, 2.5) then
            spawnCoords = coords
            break
        end
    end

    if not spawnCoords then
        showNotification("พื้นที่ไม่ว่าง มีรถขวางอยู่!", 'error')
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

        showNotification(string.format("นำรถทะเบียน %s ออกมาแล้ว (น้ำมัน: %d%%)", plate, math.floor(fuel)), 'success')
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

-- ฟังก์ชันสำหรับล้างเมนูเดิมและเพิ่มใหม่
function updateRadialMenu(type)
    if currentOption then
        exports['qb-radialmenu']:RemoveOption(currentOption)
        currentOption = nil
    end

    if type == "park" then
        currentOption = exports['qb-radialmenu']:AddOption({
            id = 'park_system',
            title = 'จอดรถ (Parking)',
            icon = 'square-parking',
            type = 'client',
            event = 'parking:client:parkVehicle',
            shouldClose = true
        })
    elseif type == "list" then
        currentOption = exports['qb-radialmenu']:AddOption({
            id = 'park_system_list', 
            title = 'รายการรถที่จอดไว้',
            icon = 'clipboard-list',
            type = 'client',
            event = 'parking:client:checkVehicleList',
            shouldClose = true
        })
    end
end

-- รันเช็คสถานะครั้งแรกตอนโหลด Script
CreateThread(function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        updateRadialMenu("park")
    else
        updateRadialMenu("list")
    end
end)

