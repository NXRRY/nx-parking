local QBCore = exports['qb-core']:GetCoreObject()
local strings = Config.Strings 


RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    TriggerServerEvent('parking:server:requestMyVehicles')
end)

-- ฟังก์ชันแจ้งเตือน
-- ฟังก์ชันแจ้งเตือน
local function notify(text, type, timeout)
    local notifySettings = {
        ['success'] = { icon = 'check-circle', color = '#48BB78', chatIcon = '✅', chatTitle = strings['notify_success'] },
        ['error']   = { icon = 'xmark-circle', color = '#F56565', chatIcon = '🚨', chatTitle = strings['notify_error'] },
        ['warning'] = { icon = 'exclamation-triangle', color = '#ECC94B', chatIcon = '⚠️', chatTitle = strings['notify_warning'] },
        ['inform']  = { icon = 'info-circle', color = '#4299E1', chatIcon = '📩', chatTitle = strings['notify_info'] }
    }
    local settings = notifySettings[type] or notifySettings['inform']
    local oxType = type == 'inform' and 'info' or type

    if Config.notifyType == 'ox' then
        lib.notify({ 
            title = strings['menu_title'] or 'SYSTEM', 
            description = text, 
            type = oxType,
            icon = settings.icon,
            iconColor = settings.color,
            position = 'bottom-center',
            duration = timeout or 5000,
            showDuration = true, 
            iconAnimation = (type == 'error' or type == 'warning') and 'bounce' or nil
        })
    elseif Config.notifyType == 'qb' then
        TriggerEvent('QBCore:Notify', text, type, timeout or 5000)
    elseif Config.notifyType == 'chat' then
        local chatColor = {255, 255, 255}
        if type == 'error' then chatColor = {255, 50, 50}
        elseif type == 'success' then chatColor = {50, 255, 150}
        elseif type == 'inform' then chatColor = {50, 200, 255} end
        TriggerEvent('chat:addMessage', {
            color = chatColor,
            multiline = true,
            args = {
                string.format('%s ^7| %s', settings.chatIcon, settings.chatTitle),
                string.format('^7%s', text)
            }
        })
    else
        TriggerEvent('QBCore:Notify', text, type, timeout or 5000)
    end
end

-- ตรวจสอบเงื่อนไขการจอด
local function CanParkVehicleparking(ped, veh)
    if not veh or veh == 0 then
        notify(strings['not_in_veh'], 'error')
        return false
    end
    if insidenoParkingZone then
        notify(strings['no_parking_zone'], 'error')
        return false
    end
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        notify(strings['not_driver'], 'error')
        return false
    end
    if GetEntitySpeed(veh) * 3.6 > 5 then
        notify(strings['slow_down'], 'error')
        return false
    end
    return true
end

-- Fade เอฟเฟกต์
local function FadeOutEntity(entity, duration)
    if not DoesEntityExist(entity) then return end
    for alpha = 255, 0, -5 do
        SetEntityAlpha(entity, alpha, false)
        Wait(duration / (255 / 5)) 
    end
    SetEntityAlpha(entity, 0, false)
end

local function FadeInEntity(entity, duration)
    if not DoesEntityExist(entity) then return end
    SetEntityAlpha(entity, 0, false)
    for alpha = 0, 255, 5 do
        SetEntityAlpha(entity, alpha, false)
        Wait(duration / (255 / 5))
    end
    ResetEntityAlpha(entity)
end

local function GetStreetNameFromCoords(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return GetStreetNameFromHashKey(streetHash)
end

local function EnterVehicleNormally(ped, vehicle)
    ClearPedTasks(ped)
    TaskEnterVehicle(ped, vehicle, 10000, -1, 1.0, 1, 0)
end

local function format_thousand(v)
    local s = string.format("%d", math.floor(v))
    local pos = string.len(s) % 3
    if pos == 0 then pos = 3 end
    return string.sub(s, 1, pos) .. string.gsub(string.sub(s, pos + 1), "(...)", ",%1")
end

-- Commands
if Config.EnableParkCommand then
    RegisterCommand('park', function()
        TriggerEvent('parking:client:parkVehicle')
    end, false)
end

-- Event: จอดรถ
RegisterNetEvent('parking:client:parkVehicle', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return end 
    if not CanParkVehicleparking(ped, veh) then return end
    QBCore.Functions.TriggerCallback('parking:server:checkOwnership', function(isOwner)
        if isOwner then
            if lib.progressCircle({
                duration = 5000,
                label = strings['prog_parking'],
                position = 'bottom',
                useWhileDead = false,
                canCancel = true,
                disable = { car = true, move = true, combat = true }
            }) then
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
                        FadeOutEntity(veh, 1000)
                        notify(strings['park_success'], 'success') 
                        TriggerEvent('parking:client:createtarget', netId)
                        TriggerServerEvent('parking:server:UpdateVehicleData', netId, 1)
                    end
                end)
            else
                notify(strings['park_cancel'], 'error') 
            end
        else
            notify(strings['not_owner'], 'error')
        end
    end, GetVehicleNumberPlateText(veh))
end)

RegisterNetEvent('parking:client:createtarget', function(netId)
    local timeout = 0
    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(veh) then
        FadeInEntity(veh, 500)
        exports['qb-target']:AddTargetEntity(veh, {
            options = {
                {
                    type = "client",
                    icon = "fas fa-key",
                    label = strings['target_take_out'],
                    action = function(entity)
                        local nId = NetworkGetNetworkIdFromEntity(entity)
                        TriggerEvent("parking:client:takeOutVehicle", nId)
                    end
                },
                {
                    type = "client",
                    action = function(entity)
                        TriggerEvent("parking:client:checkVehicleStatus", {entity = entity})
                    end,
                    icon = "fas fa-info-circle",
                    label = strings['target_check'],
                },
            },
            distance = 2.5,
        })
    end
end)

RegisterNetEvent('parking:client:takeOutVehicle', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then return end
    
    local plate = GetVehicleNumberPlateText(veh)

    -- [เพิ่มการตรวจสอบ] เช็คค่า depot ใน SQL ก่อนเริ่มขบวนการ
    QBCore.Functions.TriggerCallback('parking:server:getDepotPrice', function(depotPrice)
        if depotPrice > 0 then
            -- ถ้ายังมีค่าปรับค้างอยู่ ให้ดักไว้ไม่ให้เอาออก
            notify(string.format("ต้องชำระค่าธรรมเนียม $%s ก่อนนำรถออก!", depotPrice), 'error')
            return 
        end

        -- ถ้าค่าเป็น 0 แล้ว (จ่ายแล้ว) ถึงจะเริ่ม Progress Bar
        if lib.progressCircle({
            duration = 5000,
            label = strings['prog_take_out'],
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true, combat = true }
        }) then
            if DoesEntityExist(veh) then
                -- ปลดสถานะการจอดทั้งหมด
                FadeInEntity(veh, 500)
                SetVehicleDoorsLocked(veh, 1)
                FreezeEntityPosition(veh, false)
                SetVehicleUndriveable(veh, false)
                SetEntityInvincible(veh, false)
                SetVehicleEngineOn(veh, true, false, true)

                SetEntityAsNoLongerNeeded(veh) 
                SetVehicleHasBeenOwnedByPlayer(veh, true)

                -- ลบ Target และอัปเดตสถานะใน DB เป็น 0 (พร้อมขับ)
                exports['qb-target']:RemoveTargetEntity(veh)
                notify(strings['take_out_success'], 'success') 
                TriggerServerEvent('parking:server:UpdateVehicleData', netId, 0)

                -- ให้ตัวละครขึ้นรถอัตโนมัติ (ถ้าต้องการ)
                EnterVehicleNormally(PlayerPedId(), veh)
            end
        else
            notify(strings['take_out_cancel'], 'error') 
        end
    end, plate)
end)

RegisterNetEvent('parking:client:checkVehicleStatus', function(data)
    local vehicle = data.entity
    if not DoesEntityExist(vehicle) then return end

    local plate = GetVehicleNumberPlateText(vehicle)
    local nId = NetworkGetNetworkIdFromEntity(vehicle)

    -- [1] เช็คความเป็นเจ้าของ
    QBCore.Functions.TriggerCallback('parking:server:checkOwnership', function(isOwner)
        
        -- [2] เช็คค่าธรรมเนียม (Depot Price)
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

            -- ถ้าเป็นเจ้าของ ให้แสดงตัวเลือกนำรถออกพร้อมราคา
            if isOwner then
                local formattedPrice = format_thousand(depotPrice)
                local priceLabel = depotPrice > 0 and ("💰 ค่าธรรมเนียม: $" .. formattedPrice) or "🆓 ไม่มีค่าใช้จ่าย"
                
                table.insert(options, {
                    title = 'นำรถออกจากพื้นที่จอด',
                    description = priceLabel .. "\nยืนยันชำระเงินและยกเลิกการจอด",
                    icon = 'key',
                    iconColor = depotPrice > 0 and '#ff4d4d' or '#5fb6ff',
                    onSelect = function()
                        -- ส่งไปให้ Server ตรวจสอบเงินและราคาจริงอีกครั้ง
                        TriggerServerEvent("parking:server:payAndTakeOut", nId, plate)
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



RegisterNetEvent('parking:client:spawnAllStoredVehicles', function(vehicles)
    for i = 1, #vehicles do
        local data = vehicles[i]
        local plate = data.plate
        local existingVeh = nil
        local allVehicles = QBCore.Functions.GetVehicles()
        
        for j = 1, #allVehicles do
            if QBCore.Functions.GetPlate(allVehicles[j]) == plate then
                existingVeh = allVehicles[j]
                break
            end
        end

        if not existingVeh then
            local model = data.vehicle or data.model
            model = type(model) == 'string' and joaat(model) or model
            QBCore.Functions.LoadModel(model)

            local coords = type(data.coords) == 'string' and json.decode(data.coords) or data.coords
            -- [TIP] บวกค่า Z ขึ้น 0.5 เพื่อให้รถมีพื้นที่ในการคำนวณการวางล้อลงพื้น
            local spawnPos = vector3(coords.x, coords.y, coords.z)
            
            local rotation = type(data.rotation) == 'string' and json.decode(data.rotation) or data.rotation
            local heading = rotation.z or 0.0
            
            local veh = CreateVehicle(model, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)
            
            local netId = 0
            local timeout = 0
            while netId == 0 and timeout < 100 do
                netId = NetworkGetNetworkIdFromEntity(veh)
                Wait(10)
                timeout = timeout + 1
            end


            RequestCollisionAtCoord(spawnPos.x, spawnPos.y, spawnPos.z)
            while not HasCollisionLoadedAroundEntity(veh) do 
                Wait(1) 
            end
            SetVehicleOnGroundProperly(veh)

            SetEntityAlpha(veh, 0, false)
            SetEntityCollision(veh, false, false)
            FreezeEntityPosition(veh, true)
            SetVehicleNumberPlateText(veh, plate)

            if rotation then
                SetEntityRotation(veh, rotation.x or 0.0, rotation.y or 0.0, rotation.z or 0.0, 2, true)
            end

            local vehicleMods = type(data.mods) == 'string' and json.decode(data.mods) or data.mods
            if vehicleMods then
                QBCore.Functions.SetVehicleProperties(veh, vehicleMods)
            end

            local fuelLevel = data.fuel or data.fuelLevel or 100.0
            exports['qb-fuel']:SetFuel(veh, fuelLevel)

            SetEntityAsMissionEntity(veh, true, true)
            SetVehicleDoorsLocked(veh, 2)     
            SetVehicleUndriveable(veh, true)   
            SetEntityInvincible(veh, true)     
            
            SetVehicleLights(veh, 2)
            Wait(150)
            SetVehicleLights(veh, 0)

            local alpha = 0
            CreateThread(function()
                while alpha < 255 do
                    alpha = alpha + 15
                    if alpha > 255 then alpha = 255 end
                    SetEntityAlpha(veh, alpha, false)
                    Wait(30)
                end
                ResetEntityAlpha(veh)
                SetEntityCollision(veh, true, true)
                FreezeEntityPosition(veh, true) 
            end)

            TriggerEvent('parking:client:createtarget', netId)
        else
            local netId = NetworkGetNetworkIdFromEntity(existingVeh)
            TriggerEvent('parking:client:createtarget', netId)
        end
    end
end)

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

        for _, v in pairs(vehicles) do
            local statusText = ""
            local statusIcon = "car"
            
            -- ดึงสถานะจาก Config
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

RegisterNetEvent('parking:client:showVehicleDetail', function(v)
    local streetName = GetStreetNameFromCoords(v.coords)
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

    lib.registerContext({
        id = 'vehicle_detail_menu',
        title = strings.vehicle_detail_title:format(v.plate),
        menu = 'vehicle_list_menu',
        options = {
            {
                title = strings.location_title,
                description = strings.location_desc:format(streetName),
                icon = 'location-dot',
                onSelect = function()
                    SetNewWaypoint(v.coords.x, v.coords.y)
                    notify(strings.location_notify, 'inform')
                end
            },
            {
                title = strings.status_title,
                description = statusText,
                icon = 'info-circle',
                iconColor = color,
                readonly = true
            },
            {
                title = strings.engine_title,
                description = strings.engine_desc:format(math.ceil(v.engine/10)),
                icon = 'microchip',
                progress = math.ceil(v.engine/10),
                colorScheme = (v.engine > 700 and 'green' or v.engine > 300 and 'orange' or 'red'),
                readonly = true
            },
            {
                title = strings.body_title,
                description = strings.body_desc:format(math.ceil(v.body/10)),
                icon = 'car-side',
                progress = math.ceil(v.body/10),
                colorScheme = (v.body > 700 and 'blue' or v.body > 300 and 'orange' or 'red'),
                readonly = true
            },
            {
                title = strings.fuel_title,
                description = strings.fuel_desc:format(math.ceil(v.fuel)),
                icon = 'gas-pump',
                progress = math.ceil(v.fuel),
                colorScheme = (v.fuel > 50 and 'yellow' or 'red'),
                readonly = true
            },
        }
    })

    lib.showContext('vehicle_detail_menu')
end)