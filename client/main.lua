local QBCore = exports['qb-core']:GetCoreObject()

-- ==========================================
--              Helper Functions
-- ==========================================

local function notify(text, type)
    if Config.notifyType == 'qb' then
        TriggerEvent('QBCore:Notify', text, type)
    elseif Config.notifyType == 'okok' then
        TriggerEvent('okokNotify:Alert', "SYSTEM", text, 5000, type)
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

    -- 1. ตรวจสอบสถานะการขับขี่
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        notify('คุณต้องนั่งอยู่บนรถ และนั่งที่ตำแหน่งคนขับเพื่อดำเนินการ', 'error')
        return false
    end

    -- 2. ตรวจสอบความเร็ว
    if (GetEntitySpeed(vehicle) * 3.6) > 5 then
        notify('กรุณาชะลอความเร็วก่อนจอด!', 'error')
        return false
    end

    -- 3. รวบรวมข้อมูลรถ
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
--              Parking Command
-- ==========================================

RegisterCommand('parking', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 then
        notify('คุณไม่ได้อยู่ในรถ', 'error')
        return
    end

    if GetPedInVehicleSeat(veh, -1) ~= ped then
        notify('คุณต้องเป็นคนขับรถเท่านั้น!', 'error')
        return
    end

    local plate = QBCore.Functions.GetPlate(veh)
    local data  = dataparking()

    if not data then return end

    QBCore.Functions.TriggerCallback('parking:server:checkOwnership', function(hasOwner)
        if hasOwner then
            -- เริ่ม Progress Bar (ox_lib)
            if lib.progressCircle({
                duration = 5000,
                label = 'กำลังบันทึกพิกัดการจอด...',
                position = 'bottom',
                useWhileDead = false,
                canCancel = true,
                disable = { car = true, move = true, combat = true }
            }) then
                -- 1. บันทึกข้อมูลไปที่ Server
                TriggerServerEvent('parking:server:UpdateVehicleData', data)
                TriggerServerEvent('parking:server:updateVehicleState', 1, data.plate)


                -- 2. ตั้งค่าทางกายภาพเริ่มต้น
                SetVehicleEngineOn(veh, false, false, true)
                SetVehicleHandbrake(veh, true)
                TaskLeaveVehicle(ped, veh, 1)

                -- 3. รอผู้เล่นลงรถแล้วทำการ Freeze/Invincible
                SetTimeout(6000, function()
                    if DoesEntityExist(veh) then
                        SetVehicleDoorsLocked(veh, 2)
                        FreezeEntityPosition(veh, true)
                        SetEntityInvincible(veh, true)
                        notify('จอดรถและล็อกประตูเรียบร้อย', 'success')
                    end
                end)
            else
                notify('ยกเลิกการจอด', 'error')
            end
        else
            notify('รถคันนี้ไม่ใช่รถส่วนบุคคล ไม่สามารถจอดที่นี่ได้', 'error')
        end
    end, plate)
end, false)

-- ==========================================
--              Unparking Command
-- ==========================================

RegisterCommand('unparking', function()
    local data = dataparking()

    if not data or not DoesEntityExist(data.entity) then
        notify('ไม่พบรถในระยะบันทึกการจอด', 'error')
        return
    end

    local plate = QBCore.Functions.GetPlate(data.entity)

    QBCore.Functions.TriggerCallback('parking:server:checkOwnership', function(hasOwner)
        if not hasOwner then
            notify('คุณไม่ใช่เจ้าของรถคันนี้', 'error')
            return
        end

        if lib.progressCircle({
            duration = 3000,
            label = 'กำลังปลดล็อกการจอด...',
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, combat = true },
            anim = { dict = 'anim@mp_player_intmenu@key_fob@', clip = 'fob_click' }
        }) then
            -- 1. อัปเดตสถานะเป็นปกติ (State 0)
            TriggerServerEvent('parking:server:updateVehicleState', 0, data.plate)


            -- 2. คืนค่าฟิสิกส์รถ
            FreezeEntityPosition(data.entity, false)
            SetEntityInvincible(data.entity, false)
            SetVehicleHandbrake(data.entity, false)
            SetVehicleDoorsLocked(data.entity, 1)
            SetVehicleEngineOn(data.entity, true, true, false)

            notify('ปลดล็อกการจอดเรียบร้อย พร้อมใช้งาน', 'success')
        else
            notify('ยกเลิกการปลดล็อก', 'error')
        end
    end, plate)
end, false)

-- ==========================================
--              My Vehicles Menu
-- ==========================================

RegisterCommand('myvehicles', function()
    QBCore.Functions.TriggerCallback('parking:getVehicles', function(vehicles)
        if not vehicles or #vehicles == 0 then
            notify('ไม่พบข้อมูลรถของคุณ', 'error')
            return
        end

        local menuOptions = {}
        local pPed = PlayerPedId()
        local pCoords = GetEntityCoords(pPed)

        for i = 1, #vehicles do
            local veh = vehicles[i]
            local stateText = (veh.state == 1) and 'จอดอยู่' or (veh.state == 2 and 'โดนยึด' or 'ไม่ทราบสถานะ')

            table.insert(menuOptions, {
                title = string.format('%s [%s]', (veh.vehicle or "CAR"):upper(), veh.plate),
                description = string.format('เครื่องยนต์: %d%% | สถานะ: %s', math.floor(veh.engine / 10), stateText),
                icon = 'car',
                metadata = {
                    {label = 'สถานะ', value = stateText},
                    {label = 'ทะเบียน', value = veh.plate},
                    {label = 'น้ำมัน', value = math.floor(veh.fuel) .. '%'}
                },
                onSelect = function()
                    if veh.state ~= 1 then
                        notify('รถคันนี้ไม่ได้จอดอยู่ที่นี่', 'error')
                        return
                    end

                    local dist = #(pCoords - veh.coords)

                    -- ถ้าอยู่ไกล ให้ปักหมุด (GPS)
                    if dist > 10.0 then
                        SetNewWaypoint(veh.coords.x, veh.coords.y)
                        local vehicleBlip = AddBlipForCoord(veh.coords.x, veh.coords.y, veh.coords.z)
                        SetBlipSprite(vehicleBlip, 225)
                        SetBlipColour(vehicleBlip, 47)
                        SetBlipFlashes(vehicleBlip, true)
                        BeginTextCommandSetBlipName("STRING")
                        AddTextComponentString("Parking System [" .. veh.plate .. "]")
                        EndTextCommandSetBlipName(vehicleBlip)

                        notify('คุณอยู่ห่างเกินไป ระบบได้ปักหมุดตำแหน่งรถให้แล้ว', 'inform')

                        SetTimeout(30000, function()
                            if DoesBlipExist(vehicleBlip) then RemoveBlip(vehicleBlip) end
                        end)
                        return
                    end

                    -- ถ้าอยู่ใกล้ ให้เบิกออกมา
                    SpawnPlayerVehicle(veh)
                end
            })
        end

        lib.registerContext({ id = 'vehicle_list_menu', title = 'รายการรถของฉัน', options = menuOptions })
        lib.showContext('vehicle_list_menu')
    end)
end)

-- ==========================================
--              Spawn Vehicle Function
-- ==========================================

function SpawnPlayerVehicle(data)
    local plate = data.plate or data.Plate
    local pPed = PlayerPedId()
    local allVehicles = QBCore.Functions.GetVehicles()
    local isVehicleOut = false
    local targetVehicle = nil

    -- ตรวจสอบว่ารถอยู่ในเมืองแล้วหรือยัง
    for i = 1, #allVehicles do
        local vehicleInMap = allVehicles[i]
        if DoesEntityExist(vehicleInMap) and QBCore.Functions.GetPlate(vehicleInMap) == plate then
            isVehicleOut = true
            targetVehicle = vehicleInMap
            break
        end
    end

    if isVehicleOut then
        local vehCoords = GetEntityCoords(targetVehicle)
        SetNewWaypoint(vehCoords.x, vehCoords.y)
        notify('รถทะเบียน ' .. plate .. ' อยู่ในเมืองแล้ว ระบบปักหมุดให้บนแผนที่', 'error')
        return
    end

    -- Progress RP Style
    if not lib.progressCircle({
        duration = 4000,
        label = 'กำลังเรียกรถจากระบบ...',
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true },
        anim = {
            dict = 'anim@mp_player_intmenu@key_fob@',
            clip = 'fob_click'
        }
    }) then
        notify('ยกเลิกการเรียกรถ', 'error')
        return
    end

    local pCoords = GetEntityCoords(pPed)

    if #(pCoords - data.coords) > 20.0 then
        notify('คุณอยู่ห่างจากจุดจอดรถมากเกินไป', 'error')
        return
    end

    local spawnPos = vector3(data.coords.x, data.coords.y, data.coords.z)

    -- เรียก spawn จาก server
    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)

        if not netId then
            notify('เกิดข้อผิดพลาดในการเรียกรถ', 'error')
            return
        end

        local timeout = 0
        while not NetworkDoesNetworkIdExist(netId) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end

        if not NetworkDoesNetworkIdExist(netId) then
            notify('Network Error', 'error')
            return
        end

        local veh = NetToVeh(netId)

        SetEntityCoords(veh, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, true)

        if data.rotation then
            SetEntityRotation(
                veh,
                data.rotation.x,
                data.rotation.y,
                data.rotation.z,
                2,
                true
            )
        end

        Wait(200)

        -- โหลดของแต่ง
        local vehicleMods = type(data.mods) == 'string' and json.decode(data.mods) or data.mods
        QBCore.Functions.SetVehicleProperties(veh, vehicleMods)

        -- น้ำมัน
        local fuelLevel = data.fuel or 100.0
        if exports['qb-fuel'] then
            exports['qb-fuel']:SetFuel(veh, fuelLevel)
        else
            SetVehicleFuelLevel(veh, fuelLevel)
        end

        -- ตั้งสถานะ
        TriggerServerEvent('parking:server:updateVehicleState', 0, plate)
        TriggerEvent('vehiclekeys:client:SetOwner', plate)

        -- เอฟเฟกต์ RP (ไฟกระพริบ + เสียงล็อก)
        SetVehicleDoorsLocked(veh, 2)
        PlayVehicleDoorCloseSound(veh, 1)

        SetVehicleLights(veh, 2)
        Wait(150)
        SetVehicleLights(veh, 0)

        SetVehicleDoorsLocked(veh, 1)

        notify('รถทะเบียน ' .. plate .. ' มาถึงแล้ว', 'success')

    end, data.vehicle, spawnPos, false)
end

-- ==========================================
--              Parking Menu (UI)
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
            title = '🚘 ข้อมูลรถปัจจุบัน',
            description = string.format('รุ่น: %s\nทะเบียน: %s\nน้ำมัน: %d%%\nเครื่องยนต์: %d%%', model, plate, math.floor(fuel), math.floor(engine / 10)),
            icon = 'car',
            disabled = true
        })

        table.insert(options, {
            title = '📍 จอดรถ',
            description = 'บันทึกตำแหน่งและล็อครถ',
            icon = 'square-parking',
            onSelect = function() ExecuteCommand('parking') end
        })

        table.insert(options, {
            title = '🔓 ปลดล็อกการจอด',
            description = 'ปลดล็อครถที่จอดไว้',
            icon = 'unlock',
            onSelect = function() ExecuteCommand('unparking') end
        })
    end

    table.insert(options, {
        title = '🚗 รถของฉัน',
        description = 'ดูรายการรถทั้งหมด',
        icon = 'car',
        onSelect = function() ExecuteCommand('myvehicles') end
    })

    lib.registerContext({ id = 'parking_main_menu', title = 'Parking System', options = options })
    lib.showContext('parking_main_menu')
end

RegisterCommand('openparkingmenu', function() OpenParkingMenu() end, false)

RegisterKeyMapping('openparkingmenu', 'เปิดเมนู Parking', 'keyboard', 'F6')