local QBCore = exports['qb-core']:GetCoreObject()

-- ==========================================
--              Server Callbacks
-- ==========================================

-- [ ตรวจสอบการเป็นเจ้าของรถ ]
QBCore.Functions.CreateCallback('parking:server:checkOwnership', function(source, cb, plate)
    MySQL.Async.fetchScalar('SELECT 1 FROM player_vehicles WHERE plate = @plate', {
        ['@plate'] = plate
    }, function(result)
        if result then
            cb(true) 
        else
            cb(false) 
        end
    end)
end)

QBCore.Functions.CreateCallback('parking:server:getVehicles', function(source, cb) -- เพิ่ม cb เข้ามา
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end 

    local citizenid = Player.PlayerData.citizenid
    local vehicles = {}
    if Config.Debug then
        print('[Parking Debug] Fetching vehicles for CitizenID: ' .. citizenid)
    end
    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', {citizenid})

    if result then
        for i = 1, #result do
            local data = result[i]
            local mods = data.mods and json.decode(data.mods) or {}
            local coords = data.coords and json.decode(data.coords) or {x = 0, y = 0, z = 0}
            local rot = data.rotation and json.decode(data.rotation) or {x = 0, y = 0, z = 0}

            table.insert(vehicles, {
                plate = data.plate,
                vehicle = data.vehicle,
                state = data.state,
                hash = data.hash,
                mods = mods,
                engine = data.engineHealth or (mods.engineHealth or 1000.0),
                body = data.bodyHealth or (mods.bodyHealth or 1000.0),
                fuel = data.fuel or (mods.fuelLevel or 100.0),
                coords = vector3(coords.x, coords.y, coords.z),
                rotation = vector3(rot.x, rot.y, rot.z),
            })
        end
    end
    if Config.Debug then
        print('[Parking Debug] Retrieved ' .. #vehicles .. ' vehicles for CitizenID: ' .. citizenid)
    end
    cb(vehicles) 
end)

QBCore.Functions.CreateCallback('parking:server:RequestSpawnVehicle', function(source, cb, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not data then return cb(false) end

    local plate = QBCore.Shared.Trim(data.plate)
    local citizenid = Player.PlayerData.citizenid

    -- [SECURITY 1] เช็คความเป็นเจ้าของ
    local isOwner = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? AND citizenid = ?', {
        plate, citizenid
    })

    if not isOwner then
        print(string.format("[BAN RISK] %s tried to spawn vehicle %s without ownership!", GetPlayerName(src), plate))
        return cb(false)
    end

    -- [SECURITY 2] เช็คระยะห่าง
    local pPed = GetPlayerPed(src)
    local pCoords = GetEntityCoords(pPed)
    local vCoords = vector3(data.coords.x, data.coords.y, data.coords.z)
    
    if #(pCoords - vCoords) > 25.0 then 
        return cb(false)
    end

    -- [ACTION] สปาวน์รถ (Server-side)
    QBCore.Functions.SpawnVehicle(src, data.vehicle or data.model, vCoords, false, function(veh)
        local netId = NetworkGetNetworkIdFromEntity(veh)
        
        -- อัปเดตสถานะใน DB ทันที
        MySQL.update('UPDATE player_vehicles SET state = 0 WHERE plate = ? AND citizenid = ?', {
            plate, citizenid
        })

        -- ส่ง netId กลับไปให้ Client
        cb(netId)
    end)
end)

-- ==========================================
--              Server Events
-- ==========================================
RegisterNetEvent('parking:server:UpdateVehicleData', function(netId, state)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not netId then return end

    -- [Validation] ตรวจสอบว่า state ที่ส่งมาถูกต้อง (ป้องกันคนส่งเลขมั่ว)
    if state ~= 0 and state ~= 1 then 
        print(string.format('[Security Warning] %s tried to send invalid state: %s', GetPlayerName(src), tostring(state)))
        return 
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(vehicle))
        local citizenid = Player.PlayerData.citizenid
        
        -- [Security Check 1] ตรวจสอบระยะห่าง (ห้ามอยู่ไกลเกิน 10 เมตร)
        local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(vehicle))
        if dist > 10.0 then return end

        -- [Security Check 2] ตรวจสอบความเป็นเจ้าของ
        local isOwner = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? AND citizenid = ?', {
            plate, citizenid
        })

        if not isOwner then
            print(string.format('[Security Warning] %s tried to modify vehicle %s without ownership!', GetPlayerName(src), plate))
            return 
        end

        -- เตรียมข้อมูลสำหรับการบันทึก
        local engine = GetVehicleEngineHealth(vehicle)
        local body = GetVehicleBodyHealth(vehicle)
        local coords = GetEntityCoords(vehicle)
        local rotation = GetEntityRotation(vehicle)
        local fuel = Entity(vehicle).state.fuel or 100 

        local parkingData = {
            plate = plate,
            engineHealth = engine,
            bodyHealth = body,
            fuel = fuel,
            coords = coords,
            rotation = rotation,
            citizenid = citizenid,
            lastUpdate = os.time()
        }

        -- อัปเดต Database
        -- หาก state = 1 (จอด) จะบันทึก coords/rotation
        -- หาก state = 0 (เอารถออก) จะเปลี่ยนแค่สถานะ หรือล้างค่า coords ตามต้องการ
        MySQL.Async.execute('UPDATE player_vehicles SET parking = @parking, fuel = @fuel, engine = @engine, body = @body, rotation = @rotation, coords = @coords, state = @state WHERE plate = @plate AND citizenid = @cid', {
            ['@parking']  = json.encode(parkingData),
            ['@fuel']     = fuel,
            ['@engine']   = engine,
            ['@body']     = body,
            ['@rotation'] = json.encode(rotation), 
            ['@coords']   = json.encode(coords), 
            ['@plate']    = plate,
            ['@cid']      = citizenid,
            ['@state']    = state -- ใช้ state ที่ส่งมาจาก Client (0 หรือ 1)
        }, function(rowsChanged)
            if rowsChanged > 0 and Config.Debug then
                local status = (state == 1) and "PARKED" or "UNPARKED"
                print(string.format('[Parking Debug] %s | Plate: %s', status, plate))
            end
        end)
    end
end)
