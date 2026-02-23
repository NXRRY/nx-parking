local QBCore = exports['qb-core']:GetCoreObject()

-- ==========================================
--               Helper Functions
-- ==========================================

function notify(text, type)
    if Config.notifyType == 'ox' then
        lib.notify({ 
            title = Config.Strings['menu_title'], 
            description = text, 
            type = type,
            position = 'bottom-center',
            duration = 5000,
        })
    elseif Config.notifyType == 'qb' then
        TriggerEvent('QBCore:Notify', text, type)
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

    if isInsideParkingZone then
        notify(Config.Strings['no_parking_zone'], 'error')
        return
    end

    if GetPedInVehicleSeat(veh, -1) ~= ped then
        notify(Config.Strings['not_driver'], 'error')
        return
    end
    if GetEntitySpeed(veh) * 3.6 > 5 then
        notify(Config.Strings['slow_down'], 'error')
        return
    end
    if lib.progressCircle({
        duration = 5000,
        label = Config.Strings['prog_parking'],
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true }
    }) then
        local netId = NetworkGetNetworkIdFromEntity(veh)
        SetVehicleEngineOn(veh, false, false, true)
        SetVehicleHandbrake(veh, true)
        TaskLeaveVehicle(ped, veh, 1)
        local netId = NetworkGetNetworkIdFromEntity(veh)
        TriggerServerEvent('parking:server:UpdateVehicleData', netId, 1)
        SetTimeout(3000, function() 
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
end, false)

-- ==========================================
--               Unparking Command
-- ==========================================
RegisterNetEvent('parking:client:unparkVehicle', function()
    local coords = GetEntityCoords(PlayerPedId())
    local veh = QBCore.Functions.GetClosestVehicle(coords)
    local dist = #(coords - GetEntityCoords(veh))
    
    if veh == 0 or dist > 3.0 then
        notify(Config.Strings['unpark_not_found'], 'error')
        return
    end

    if not veh or not DoesEntityExist(veh) then
        notify(Config.Strings['unpark_not_found'], 'error')
        return
    end
    local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(veh))
    local netId = NetworkGetNetworkIdFromEntity(veh)
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
            TriggerServerEvent('parking:server:UpdateVehicleData', netId, 0)
            FreezeEntityPosition(veh, false)
            SetEntityInvincible(veh, false)
            SetVehicleHandbrake(veh, false)
            SetVehicleDoorsLocked(veh, 1)
            SetVehicleEngineOn(veh, true, true, false)
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
    
    -- [1] Duplicate Check: เหมือนเดิม
    local allVehicles = QBCore.Functions.GetVehicles()
    for i = 1, #allVehicles do
        local vehicleInMap = allVehicles[i]
        if DoesEntityExist(vehicleInMap) then
            local existingPlate = QBCore.Functions.GetPlate(vehicleInMap)
            if existingPlate == data.plate then
                local vehCoords = GetEntityCoords(vehicleInMap)
                SetNewWaypoint(vehCoords.x, vehCoords.y)
                notify(string.format(Config.Strings['veh_already_out'], data.plate), 'error')
                return
            end
        end
    end

    -- [2] Distance Check
    local spawnPos = vector3(data.coords.x, data.coords.y, data.coords.z)
    if #(pCoords - spawnPos) > 20.0 then
        notify(Config.Strings['too_far'], 'error')
        return
    end

    -- [3] Progress Bar
    if not lib.progressCircle({
        duration = 4000,
        label = Config.Strings['prog_spawning'],
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'anim@mp_player_intmenu@key_fob@', clip = 'fob_click' }
    }) then return end
    local model = data.vehicle or data.model
    model = type(model) == 'string' and joaat(model) or model
    QBCore.Functions.LoadModel(model)
    local heading = data.rotation and data.rotation.z or 0.0
    local veh = CreateVehicle(model, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)
    local netId = 0
    local timeout = 0
    while netId == 0 and timeout < 100 do
        netId = NetworkGetNetworkIdFromEntity(veh)
        Wait(10)
        timeout = timeout + 1
    end
    SetEntityAlpha(veh, 0, false)
    SetEntityCollision(veh, false, false)
    FreezeEntityPosition(veh, true)
    SetEntityCoords(veh, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, true)
    if data.rotation then
        SetEntityRotation(veh, data.rotation.x or 0.0, data.rotation.y or 0.0, data.rotation.z or 0.0, 2, true)
    end
    local vehicleMods = type(data.mods) == 'string' and json.decode(data.mods) or data.mods
    if vehicleMods then
        QBCore.Functions.SetVehicleProperties(veh, vehicleMods)
    end
    if netId ~= 0 then
        TriggerServerEvent('parking:server:UpdateVehicleData', netId, 0)
    end
    local fuelLevel = data.fuel or data.fuelLevel or 100.0
    exports['qb-fuel']:SetFuel(veh, fuelLevel)
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
    end)

    notify(string.format(Config.Strings['spawn_success'], data.plate), 'success')
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
