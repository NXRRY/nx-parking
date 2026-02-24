local QBCore = exports['qb-core']:GetCoreObject()



-- ==========================================
--              Server Callbacks
-- ==========================================

QBCore.Functions.CreateCallback('parking:server:getVehicleList', function(source, cb) -- เพิ่ม cb เข้ามา
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

QBCore.Functions.CreateCallback('parking:server:getDepotPrice', function(source, cb, plate)
    MySQL.scalar('SELECT depotprice FROM player_vehicles WHERE plate = ?', {plate}, function(price)
        cb(price or 0)
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
        if Config.Debug then    
            print(string.format('[Debug] Invalid state received from %s: %s', GetPlayerName(src), tostring(state)))
        end
        return 
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(vehicle))
        local citizenid = Player.PlayerData.citizenid
        
        -- [Security Check 1] ตรวจสอบระยะห่าง (ห้ามอยู่ไกลเกิน 10 เมตร)
        local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(vehicle))
        if dist > 10.0 then return end

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

RegisterNetEvent('parking:server:requestMyVehicles', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid

    -- ดึงข้อมูลรถ State 1
    MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND state = 1', {citizenid}, function(result)
        if result and #result > 0 then
            TriggerClientEvent('parking:client:spawnAllStoredVehicles', src, result)
        end
    end)
end)

-- Event จัดการจ่ายเงินและนำรถออก
RegisterNetEvent('parking:server:payAndTakeOut', function(netId, plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- [1] ดึงราคาจริงจาก SQL อีกครั้งเพื่อความปลอดภัย (Anti-Cheat)
    MySQL.scalar('SELECT depotprice FROM player_vehicles WHERE plate = ? AND citizenid = ?', {
        plate, 
        Player.PlayerData.citizenid
    }, function(price)
        if price == nil then 
            TriggerClientEvent('QBCore:Notify', src, "ไม่พบข้อมูลความเป็นเจ้าของรถคันนี้", "error")
            return 
        end

        price = tonumber(price) or 0

        -- กรณีไม่มีค่าธรรมเนียม (0 บาท) ให้ผ่านไปได้เลย
        if price <= 0 then
            MySQL.update('UPDATE player_vehicles SET depotprice = 0 WHERE plate = ?', {plate})
            TriggerClientEvent("parking:client:takeOutVehicle", src, netId)
            return
        end

        -- [2] ตรวจสอบจำนวนเงินที่มีอยู่จริง (Cash + Bank)
        local cashMoney = Player.Functions.GetMoney('cash')
        local bankMoney = Player.Functions.GetMoney('bank')
        local totalMoney = cashMoney + bankMoney

        -- [3] เช็คว่าเงินรวมพอจ่ายไหม
        if totalMoney >= price then
            -- พยายามหักเงินสดก่อน
            if cashMoney >= price then
                Player.Functions.RemoveMoney('cash', price, "unparking-fee")
            -- ถ้าเงินสดไม่พอ ให้หักจากธนาคารทั้งหมด
            elseif bankMoney >= price then
                Player.Functions.RemoveMoney('bank', price, "unparking-fee")
            -- ถ้าแยกกันไม่พอ แต่รวมกันพอ (กรณีพิเศษ) ให้หักเงินสดจนหมดแล้วไปหักส่วนต่างที่ธนาคาร
            else
                local remainder = price - cashMoney
                Player.Functions.RemoveMoney('cash', cashMoney, "unparking-fee")
                Player.Functions.RemoveMoney('bank', remainder, "unparking-fee")
            end

            -- [4] จ่ายเงินสำเร็จ -> อัปเดต DB และสั่ง Client นำรถออก
            MySQL.update('UPDATE player_vehicles SET depotprice = 0 WHERE plate = ?', {plate})
            TriggerClientEvent("parking:client:takeOutVehicle", src, netId)
            TriggerClientEvent('QBCore:Notify', src, "ชำระค่าธรรมเนียม $"..price.." เรียบร้อยแล้ว", "success")
        else
            -- [5] เงินไม่พอ
            local missingMoney = price - totalMoney
            TriggerClientEvent('QBCore:Notify', src, "คุณมีเงินไม่เพียงพอ! (ขาดอีก $"..missingMoney..")", "error")
        end
    end)
end)
