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


-- ==========================================
--              Server Events
-- ==========================================
RegisterNetEvent('parking:server:UpdateVehicleData', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not data or not data.plate then return end
    local plate = data.plate
    local citizenid = Player.PlayerData.citizenid
    if Config.Debug then
        print('[Parking Debug] Data: ' .. json.encode(data))
    end
    local parkingJson = json.encode(data)
    MySQL.Async.execute('UPDATE player_vehicles SET parking = @parking, fuel = @fuel, engine = @engine, body = @body, rotation = @rotation, coords = @coords WHERE plate = @plate', {
        ['@parking'] = parkingJson,
        ['@hash']    = data.model,
        ['@model']   = data.modelName,
        ['@mods']    = json.encode(data.mods),
        ['@engine']  = data.engineHealth,
        ['@body']    = data.bodyHealth,
        ['@rotation'] = json.encode(data.rotation), 
        ['@coords'] = json.encode(data.coords), 
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
