local QBCore = exports['qb-core']:GetCoreObject()

-- ==========================================
--               Helper Functions
-- ==========================================

local function notify(text, type)
    if Config.notifyType == 'ox' then
        lib.notify({ title = Config.Strings['menu_title'], description = text, type = type })
    elseif Config.notifyType == 'qb' then
        TriggerEvent('QBCore:Notify', text, type)
    elseif Config.notifyType == 'okok' then
        TriggerEvent('okokNotify:Alert', Config.Strings['menu_title'], text, 5000, type)
    elseif Config.notifyType == 'chat' then
        local chatTheme = {
            ['error']   = { color = {255, 50, 50},  icon = '🚨', title = 'SYSTEM ERROR' },
            ['success'] = { color = {50, 255, 150}, icon = '✅', title = 'SUCCESS'      },
            ['inform']  = { color = {50, 200, 255}, icon = '📩', title = 'NOTIFICATION' }
        }
        local theme = chatTheme[type] or chatTheme['inform']
        TriggerEvent('chat:addMessage', {
            color = theme.color,
            multiline = true,
            args = {
                string.format('%s ^7| %s', theme.icon, theme.title),
                string.format('^7%s', text)
            }
        })
    else
        TriggerEvent('QBCore:Notify', text, type)
    end
end

local function dataparking()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        notify(Config.Strings['not_driver'], 'error')
        return false
    end

    if (GetEntitySpeed(vehicle) * 3.6) > 5 then
        notify(Config.Strings['slow_down'], 'error')
        return false
    end

    local PlayerData = QBCore.Functions.GetPlayerData()
    local vehicleData = {
        parkingcitizenid = PlayerData.citizenid,
        entity       = vehicle,
        plate        = GetVehicleNumberPlateText(vehicle),
        model        = GetEntityModel(vehicle),
        modelName    = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))),
        mods         = QBCore.Functions.GetVehicleProperties(vehicle),
        coords       = GetEntityCoords(vehicle),
        heading      = GetEntityHeading(vehicle),
        rotation     = GetEntityRotation(vehicle, 2),
        engineHealth = GetVehicleEngineHealth(vehicle),
        bodyHealth   = GetVehicleBodyHealth(vehicle),
        fuelLevel    = GetVehicleFuelLevel(vehicle),
        locked       = GetVehicleDoorLockStatus(vehicle)
    }

    if Config.Debug then
        print("Captured Vehicle Data:")
        print(json.encode(vehicleData, {indent = true}))
    end

    return vehicleData
end

-- ==========================================
--               Parking Command
-- ==========================================
RegisterNetEvent('parking:client:parkVehicle', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 then
        notify(Config.Strings['not_in_veh'], 'error')
        return
    end

    if GetPedInVehicleSeat(veh, -1) ~= ped then
        notify(Config.Strings['not_driver'], 'error')
        return
    end

    local plate = QBCore.Functions.GetPlate(veh)
    local data  = dataparking()

    if not data then return end

    QBCore.Functions.TriggerCallback('parking:server:checkOwnership', function(hasOwner)
        if hasOwner then
            if lib.progressCircle({
                duration = 5000,
                label = Config.Strings['prog_parking'],
                position = 'bottom',
                useWhileDead = false,
                canCancel = true,
                disable = { car = true, move = true, combat = true }
            }) then
                TriggerServerEvent('parking:server:UpdateVehicleData', data)
                TriggerServerEvent('parking:server:updateVehicleState', 1, data.plate)

                SetVehicleEngineOn(veh, false, false, true)
                SetVehicleHandbrake(veh, true)
                TaskLeaveVehicle(ped, veh, 1)

                SetTimeout(6000, function()
                    if DoesEntityExist(veh) then
                        SetVehicleDoorsLocked(veh, 2)
                        FreezeEntityPosition(veh, true)
                        SetEntityInvincible(veh, true)
                        notify(Config.Strings['park_success'], 'success')
                    end
                end)
            else
                notify(Config.Strings['park_cancel'], 'error')
            end
        else
            notify(Config.Strings['not_owner'], 'error')
        end
    end, plate)
end, false)

-- ==========================================
--               Unparking Command
-- ==========================================
RegisterNetEvent('parking:client:unparkVehicle', function()
    local data = dataparking()

    if not data or not DoesEntityExist(data.entity) then
        notify(Config.Strings['unpark_not_found'], 'error')
        return
    end

    local plate = QBCore.Functions.GetPlate(data.entity)

    QBCore.Functions.TriggerCallback('parking:server:checkOwnership', function(hasOwner)
        if not hasOwner then
            notify(Config.Strings['unpark_not_owner'], 'error')
            return
        end

        if lib.progressCircle({
            duration = 3000,
            label = Config.Strings['prog_unparking'],
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, combat = true },
            anim = { dict = 'anim@mp_player_intmenu@key_fob@', clip = 'fob_click' }
        }) then
            TriggerServerEvent('parking:server:updateVehicleState', 0, data.plate)

            FreezeEntityPosition(data.entity, false)
            SetEntityInvincible(data.entity, false)
            SetVehicleHandbrake(data.entity, false)
            SetVehicleDoorsLocked(data.entity, 1)
            SetVehicleEngineOn(data.entity, true, true, false)

            notify(Config.Strings['unpark_success'], 'success')
        else
            notify(Config.Strings['unpark_cancel'], 'error')
        end
    end, plate)
end, false)

-- ==========================================
--               My Vehicles Menu
-- ==========================================
RegisterNetEvent('parking:client:vehicleslist', function()
    QBCore.Functions.TriggerCallback('parking:server:getVehicles', function(vehicles)
        if not vehicles or #vehicles == 0 then
            notify(Config.Strings['veh_not_found'], 'error')
            return
        end

        local menuOptions = {}
        local pPed = PlayerPedId()
        local pCoords = GetEntityCoords(pPed)

        for i = 1, #vehicles do
            local veh = vehicles[i]
            local stateText = (veh.state == 1) and Config.Strings['state_parked'] or (veh.state == 2 and Config.Strings['state_impounded'] or Config.Strings['state_unknown'])

            table.insert(menuOptions, {
                title = string.format('%s [%s]', (veh.vehicle or "CAR"):upper(), veh.plate),
                description = string.format(Config.Strings['veh_list_desc'], math.floor(veh.engine / 10), stateText),
                icon = 'car',
                onSelect = function()
                    if veh.state ~= 1 then
                        notify(Config.Strings['not_parked_here'], 'error')
                        return
                    end

                    local dist = #(pCoords - vector3(veh.coords.x, veh.coords.y, veh.coords.z))

                    if dist > 10.0 then
                        SetNewWaypoint(veh.coords.x, veh.coords.y)
                        local vehicleBlip = AddBlipForCoord(veh.coords.x, veh.coords.y, veh.coords.z)
                        SetBlipSprite(vehicleBlip, 225)
                        SetBlipColour(vehicleBlip, 47)
                        SetBlipFlashes(vehicleBlip, true)
                        BeginTextCommandSetBlipName("STRING")
                        AddTextComponentString(string.format(Config.Strings['blip_name'], veh.plate))
                        EndTextCommandSetBlipName(vehicleBlip)

                        notify(Config.Strings['gps_set'], 'inform')

                        SetTimeout(30000, function()
                            if DoesBlipExist(vehicleBlip) then RemoveBlip(vehicleBlip) end
                        end)
                        return
                    end

                    SpawnPlayerVehicle(veh)
                end
            })
        end

        lib.registerContext({ id = 'vehicle_list_menu', title = Config.Strings['my_veh_title'], options = menuOptions })
        lib.showContext('vehicle_list_menu')
    end)
end)

-- ==========================================
--               Spawn Vehicle Function
-- ==========================================

function SpawnPlayerVehicle(data)
    local pPed = PlayerPedId()
    local pCoords = GetEntityCoords(pPed)
    local allVehicles = QBCore.Functions.GetVehicles()
    local isVehicleOut = false
    local targetVehicle = nil

    for i = 1, #allVehicles do
        local vehicleInMap = allVehicles[i]
        if DoesEntityExist(vehicleInMap) then
            local existingPlate = QBCore.Functions.GetPlate(vehicleInMap)
            if existingPlate and existingPlate == data.plate then
                isVehicleOut = true
                targetVehicle = vehicleInMap
                break
            end
        end
    end

    if isVehicleOut and DoesEntityExist(targetVehicle) then
        local vehCoords = GetEntityCoords(targetVehicle)
        SetNewWaypoint(vehCoords.x, vehCoords.y)
        notify(string.format(Config.Strings['veh_already_out'], data.plate), 'error')
        return
    end

    if #(pCoords - vector3(data.coords.x, data.coords.y, data.coords.z)) > 20.0 then
        notify(Config.Strings['too_far'], 'error')
        return
    end

    if not lib.progressCircle({
        duration = 4000,
        label = Config.Strings['prog_spawning'],
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'anim@mp_player_intmenu@key_fob@', clip = 'fob_click' }
    }) then
        notify(Config.Strings['spawn_cancel'], 'error')
        return
    end

    local spawnPos = vector3(data.coords.x, data.coords.y, data.coords.z)
    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        SetEntityAlpha(veh, 0, false)
        SetEntityCollision(veh, false, false)
        FreezeEntityPosition(veh, true)
        SetEntityCoords(veh, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, true)
        SetEntityRotation(veh, data.rotation.x or 0.0, data.rotation.y or 0.0, data.rotation.z or 0.0, 2, true)
        
        local vehicleMods = type(data.mods) == 'string' and json.decode(data.mods) or data.mods
        if vehicleMods then
            QBCore.Functions.SetVehicleProperties(veh, vehicleMods)
        end
        
        local fuelLevel = data.fuel or data.fuelLevel or 100.0
        exports['qb-fuel']:SetFuel(veh, fuelLevel)
        
        TriggerServerEvent('parking:server:updateVehicleState', 0, data.plate)
        TriggerEvent('vehiclekeys:client:SetOwner', data.plate)
        
        SetVehicleDoorsLocked(veh, 2)
        PlayVehicleDoorCloseSound(veh, 1)
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
            FreezeEntityPosition(veh, false)
            SetVehicleDoorsLocked(veh, 1)
        end)
        notify(string.format(Config.Strings['spawn_success'], data.plate), 'success')
    end, data.vehicle or data.model, spawnPos, false)
end

-- ==========================================
--               Parking Menu (UI)
-- ==========================================

local function OpenParkingMenu()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local options = {}

    if veh ~= 0 then
        local plate = GetVehicleNumberPlateText(veh)
        local model = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
        local fuel = GetVehicleFuelLevel(veh)
        local engine = GetVehicleEngineHealth(veh)

        table.insert(options, {
            title = Config.Strings['current_veh_info'],
            description = string.format(Config.Strings['current_veh_desc'], model, plate, math.floor(fuel), math.floor(engine / 10)),
            icon = 'car',
            readOnly = true
        })

        table.insert(options, {
            title = Config.Strings['btn_park'],
            description = Config.Strings['btn_park_desc'],
            icon = 'square-parking',
            onSelect = function() TriggerEvent('parking:client:parkVehicle') end
        })

        table.insert(options, {
            title = Config.Strings['btn_unpark'],
            description = Config.Strings['btn_unpark_desc'],
            icon = 'unlock',
            onSelect = function() TriggerEvent('parking:client:unparkVehicle') end
        })
    end

    table.insert(options, {
        title = Config.Strings['btn_my_veh'],
        description = Config.Strings['btn_my_veh_desc'],
        icon = 'car',
        onSelect = function() TriggerEvent('parking:client:vehicleslist') end
    })

    lib.registerContext({ id = 'parking_main_menu', title = Config.Strings['menu_title'], options = options })
    lib.showContext('parking_main_menu')
end

RegisterCommand('openparkingmenu', function() OpenParkingMenu() end, false)
RegisterKeyMapping('openparkingmenu', 'เปิดเมนู Parking', 'keyboard', 'F6')
