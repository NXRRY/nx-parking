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
            cb(true)  -- พบรถในฐานข้อมูล (เป็นรถส่วนบุคคล)
        else
            cb(false) -- ไม่พบข้อมูล (เป็นรถ NPC หรือรถเสก)
        end
    end)
end)

-- ==========================================
--              Server Events
-- ==========================================

-- [ อัปเดตข้อมูลการจอดรถ ]
RegisterNetEvent('parking:server:UpdateVehicleData', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    -- 1. ตรวจสอบความสมบูรณ์ของข้อมูล
    if not Player or not data or not data.plate then return end

    local plate = data.plate
    local citizenid = Player.PlayerData.citizenid

    -- [ Debug Log ]
    if Config.Debug then
        print('[Parking Debug] Data: ' .. json.encode(data))
    end

    -- 2. เตรียมข้อมูลบันทึกลง Database
    -- หมายเหตุ: ใช้ json.encode(data) ตาม Logic เดิมของคุณเพื่อเก็บข้อมูลทั้งหมด
    local parkingJson = json.encode(data)

    -- 3. รันคำสั่ง SQL Update
    MySQL.Async.execute('UPDATE player_vehicles SET parking = @parking, fuel = @fuel, engine = @engine, body = @body, rotation = @rotation, coords = @coords, parkingcitizenid = @parkingcitizenid WHERE plate = @plate', {
        ['@parking'] = parkingJson,
        ['@parkingcitizenid'] = data.parkingcitizenid,
        ['@hash']    = data.model,
        ['@model']   = data.modelName,
        ['@mods']    = json.encode(data.mods), -- เก็บข้อมูลการโมดิฟายของรถ
        ['@fuel']    = data.fuelLevel,
        ['@engine']  = data.engineHealth,
        ['@body']    = data.bodyHealth,
        ['@rotation'] = json.encode(data.rotation), -- เก็บข้อมูลการหมุนของรถ
        ['@coords'] = json.encode(data.coords), -- เก็บข้อมูลพิกัดของรถ
        ['@plate']   = plate
    }, function(rowsChanged)
        if rowsChanged > 0 then
            print('[Parking Debug] Successfully updated parking data for plate: ' .. plate)
        else
            print('[Parking Debug] Failed to update parking data for plate: ' .. plate)
        end
    end)
end)

RegisterNetEvent('parking:server:updateVehicleState', function(state, plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    MySQL.update('UPDATE player_vehicles SET state = ?, depotprice = ? WHERE plate = ? AND citizenid = ?', { state, 0, plate, Player.PlayerData.citizenid })
end)

QBCore.Functions.CreateCallback('parking:getVehicles', function(source, cb) -- เพิ่ม cb เข้ามา
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end -- ป้องกัน Error ถ้าหาผู้เล่นไม่เจอ

    local citizenid = Player.PlayerData.citizenid
    local vehicles = {}
    
    print('[Parking Debug] Fetching vehicles for CID: ' .. citizenid)

    -- ใช้ MySQL.query.await ได้ปกติ (ถ้าใช้ oxmysql)
    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', {citizenid})

    if result then
        for i = 1, #result do
            local data = result[i]
            
            -- ป้องกัน Error กรณี mods ใน DB เป็นค่าว่าง
            local mods = data.mods and json.decode(data.mods) or {}
            local coords = data.coords and json.decode(data.coords) or {x = 0, y = 0, z = 0}
            local rot = data.rotation and json.decode(data.rotation) or {x = 0, y = 0, z = 0}

            table.insert(vehicles, {
                plate = data.plate,
                vehicle = data.vehicle,
                state = data.state,
                hash = data.hash,
                mods = mods,
                -- ตรวจสอบชื่อ Column ใน DB ดีๆ นะครับ (ปกติ QBCore มักจะเก็บใน mods ไม่ได้แยก column engineHealth)
                -- ถ้าไม่มี column แยก ให้ดึงจาก mods แทน
                engine = data.engineHealth or (mods.engineHealth or 1000.0),
                body = data.bodyHealth or (mods.bodyHealth or 1000.0),
                fuel = data.fuel or (mods.fuelLevel or 100.0),
                -- แปลงกลับเป็น vector3 เพื่อให้ฝั่ง Client ใช้งานได้ทันที
                coords = vector3(coords.x, coords.y, coords.z),
                rotation = vector3(rot.x, rot.y, rot.z),
            })
        end
    end
    print('[Parking Debug] Found ' .. #vehicles .. ' vehicles for CID: ' .. citizenid)
    cb(vehicles) -- ส่งค่ากลับผ่าน cb
end)

QBCore.Functions.CreateCallback('qb-garages:server:spawnvehicle', function(source, cb, plate, vehicle, coords)
    local vehType = QBCore.Shared.Vehicles[vehicle] and QBCore.Shared.Vehicles[vehicle].type or GetVehicleTypeByModel(vehicle)
    local veh = CreateVehicleServerSetter(GetHashKey(vehicle), vehType, coords.x, coords.y, coords.z, coords.w)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    SetVehicleNumberPlateText(veh, plate)
    local vehProps = {}
    local result = MySQL.rawExecute.await('SELECT mods FROM player_vehicles WHERE plate = ?', { plate })
    if result and result[1] then vehProps = json.decode(result[1].mods) end
    OutsideVehicles[plate] = { netID = netId, entity = veh }
    cb(netId, vehProps, plate)
end)

