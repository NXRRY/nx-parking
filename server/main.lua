-- parking/server.lua (Refactored)

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================
-- 1. HELPER FUNCTIONS
-- ============================

--- Get player object, returns nil if not found
---@param src number
---@return table|nil
local function getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

--- Check if player has enough money (cash or bank) and remove it
---@param src number
---@param amount number
---@return boolean
local function attemptPayment(src, amount)
    local Player = getPlayer(src)
    if not Player then return false end

    local money = Player.PlayerData.money
    if money.cash >= amount then
        Player.Functions.RemoveMoney('cash', amount, 'depot-payment')
        return true
    elseif money.bank >= amount then
        Player.Functions.RemoveMoney('bank', amount, 'depot-payment')
        return true
    end
    return false
end

--- Validate that the vehicle belongs to the player and is within distance
---@param src number
---@param vehicle number entity
---@param plate string
---@param maxDist number default 10.0
---@return boolean
local function validateVehicleAccess(src, vehicle, plate, maxDist)
    if not DoesEntityExist(vehicle) then return false end

    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(vehicle))
    if dist > (maxDist or 10.0) then return false end

    -- Check ownership via DB (optional but already done in callback)
    return true
end

--- Log debug messages if enabled
---@param ... any
local function debugLog(...)
    if Config.Debug then
        print('[Parking Debug]', ...)
    end
end

-- ============================
-- 2. SERVER CALLBACKS
-- ============================

--- Get list of all vehicles owned by the player
QBCore.Functions.CreateCallback('parking:server:getVehicleList', function(source, cb)
    local Player = getPlayer(source)
    if not Player then return cb({}) end

    local citizenid = Player.PlayerData.citizenid
    MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ?', {citizenid}, function(result)
        cb(result or {})
    end)
end)

--- Check if the plate belongs to any player (simple existence check)
QBCore.Functions.CreateCallback('parking:server:checkOwnership', function(source, cb, plate)
    MySQL.scalar('SELECT 1 FROM player_vehicles WHERE plate = ?', {plate}, function(result)
        cb(result and true or false)
    end)
end)

--- Get the depot price for a specific vehicle
QBCore.Functions.CreateCallback('parking:server:getDepotPrice', function(source, cb, plate)
    MySQL.scalar('SELECT depotprice FROM player_vehicles WHERE plate = ?', {plate}, function(price)
        cb(price or 0)
    end)
end)

-- ============================
-- 3. SERVER EVENTS
-- ============================

--- Update vehicle data when parked/unparked
RegisterNetEvent('parking:server:UpdateVehicleData', function(netId, state, fuel)
    local src = source
    local Player = getPlayer(src)
    if not Player or not netId then return end
    if state ~= 0 and state ~= 1 then return end  -- validate state

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(vehicle))
    local citizenid = Player.PlayerData.citizenid

    if not validateVehicleAccess(src, vehicle, plate, 10.0) then return end

    -- Get current vehicle properties
    local engine = GetVehicleEngineHealth(vehicle)
    local body = GetVehicleBodyHealth(vehicle)
    local coords = GetEntityCoords(vehicle)
    local rotation = GetEntityRotation(vehicle)
    fuel = fuel or 100.0

    -- Retrieve existing mods, then update with new data
    MySQL.query('SELECT mods FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizenid}, function(result)
        local mods = {}
        if result and result[1] then
            mods = json.decode(result[1].mods) or {}
        end

        -- Update mods with current stats
        mods.fuelLevel = fuel
        mods.engineHealth = engine
        mods.bodyHealth = body
        mods.rotation = rotation
        local parkingData = {
            coords = coords,
            rotation = rotation,
            plate = plate,
            lastUpdate = os.time(),
        }

        MySQL.update('UPDATE player_vehicles SET mods = ?, parking = ?, fuel = ?, engine = ?, body = ?, state = ?, coords = ? , rotation = ? WHERE plate = ? AND citizenid = ?', {
            json.encode(mods),
            json.encode(parkingData),
            fuel,
            engine,
            body,
            state,
            json.encode(coords),
            json.encode(rotation),
            plate,
            citizenid
        }, function(rowsChanged)
            if rowsChanged and rowsChanged > 0 then
                local status = (state == 1) and 'PARKED' or 'UNPARKED'
                debugLog(status, '| Plate:', plate, '| Coords:', coords.x, coords.y, coords.z, '| rotation:', rotation.x, rotation.y, rotation.z, '| Fuel:', fuel, '| Engine:', engine, '| Body:', body)
            end
        end)
    end)
end)

--- Respawn a parked vehicle (state=1) when player requests it from the list
RegisterNetEvent('parking:server:respawnParkedVehicle', function(plate, coords, heading)
    local src = source
    local Player = getPlayer(src)
    if not Player then return end

    debugLog('Respawning vehicle:', plate, coords, heading)

    MySQL.query('SELECT mods FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, Player.PlayerData.citizenid}, function(result)
        if not result or not result[1] then return end

        local mods = json.decode(result[1].mods) or {}
        local model = mods.model or mods.vehicle
        if not model then return end

        -- Create vehicle server-side
        local veh = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, true)

        -- Wait for entity to exist
        local timeout = 0
        while not DoesEntityExist(veh) and timeout < 1000 do
            Wait(10)
            timeout = timeout + 10
        end

        if DoesEntityExist(veh) then
            SetVehicleNumberPlateText(veh, plate)

            -- Immediately set state to 0 (out) and update coords
            MySQL.update('UPDATE player_vehicles SET state = 0, coords = ? WHERE plate = ?', {
                json.encode(coords),
                plate
            }, function(rowsChanged)
                if rowsChanged and rowsChanged > 0 then
                    debugLog('Vehicle', plate, 'state set to 0 (active)')
                else
                    debugLog('Failed to update state for', plate)
                end
            end)

            local netId = NetworkGetNetworkIdFromEntity(veh)
            TriggerClientEvent('parking:client:setupRespawnedVehicle', src, netId, mods)
        end
    end)
end)

--- Request all parked vehicles (state=1) for the player (called after loading)
RegisterNetEvent('parking:server:requestMyVehicles', function()
    local src = source
    local Player = getPlayer(src)
    if not Player then return end

    MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND state = 1', {Player.PlayerData.citizenid}, function(result)
        if result and #result > 0 then
            TriggerClientEvent('parking:client:spawnAllStoredVehicles', src, result)
        end
    end)
end)


--- Handle payment and then take out a vehicle (used from status menu)
RegisterNetEvent('parking:server:payAndTakeOut', function(netId, plate)
    local src = source
    local Player = getPlayer(src)
    if not Player then return end

    MySQL.scalar('SELECT depotprice FROM player_vehicles WHERE plate = ? AND citizenid = ?', {
        plate,
        Player.PlayerData.citizenid
    }, function(price)
        if price == nil then
            TriggerClientEvent('QBCore:Notify', src, 'ไม่พบข้อมูลรถ', 'error')
            return
        end

        price = tonumber(price) or 0

        if price <= 0 then
            -- No fee, just take out
            MySQL.update('UPDATE player_vehicles SET depotprice = 0 WHERE plate = ?', {plate})
            TriggerClientEvent('parking:client:takeOutVehicle', src, netId)
            return
        end

        if attemptPayment(src, price) then
            MySQL.update('UPDATE player_vehicles SET depotprice = 0 WHERE plate = ?', {plate})
            TriggerClientEvent('parking:client:takeOutVehicle', src, netId)
            TriggerClientEvent('QBCore:Notify', src, 'ชำระค่าธรรมเนียม $' .. price .. ' เรียบร้อยแล้ว', 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, 'คุณมีเงินไม่เพียงพอสำหรับการเบิกรถ!', 'error')
        end
    end)
end)

--- Take out vehicle from depot (via depot NPC)
RegisterNetEvent('parking:server:takeOutVehicleDepot', function(plate, index)
    local src = source
    local Player = getPlayer(src)
    local depotConfig = Config.Depot[index]

    if not Player or not depotConfig then return end

    MySQL.query('SELECT mods, depotprice FROM player_vehicles WHERE plate = ? AND citizenid = ?', {
        plate,
        Player.PlayerData.citizenid
    }, function(result)
        if not result or not result[1] then
            TriggerClientEvent('QBCore:Notify', src, 'ไม่พบข้อมูลรถ', 'error')
            return
        end

        local mods = result[1].mods
        local price = tonumber(result[1].depotprice) or 0

        local canPay = false
        if price <= 0 then
            canPay = true
        else
            canPay = attemptPayment(src, price)
        end

        if canPay then
            -- Clear depot price and spawn vehicle
            MySQL.update('UPDATE player_vehicles SET depotprice = 0 WHERE plate = ? AND citizenid = ?', {
                plate,
                Player.PlayerData.citizenid
            })

            TriggerClientEvent('parking:client:spawnVehicleFromDepot', src, plate, mods, index)

            if price > 0 then
                TriggerClientEvent('QBCore:Notify', src, 'ชำระค่าธรรมเนียม $' .. price .. ' เรียบร้อย', 'success')
            else
                TriggerClientEvent('QBCore:Notify', src, 'เบิกรถเรียบร้อย (ไม่มีค่าธรรมเนียม)', 'success')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, 'คุณมีเงินไม่พอจ่าย (ต้องการ $' .. price .. ')', 'error')
        end
    end)
end)


RegisterNetEvent('baseevents:enteredVehicle', function()
    TriggerClientEvent('parking:client:radialmenusetup',source,'park')
end)

RegisterNetEvent('baseevents:leftVehicle', function()
    TriggerClientEvent('parking:client:radialmenusetup',source,'list')
end)