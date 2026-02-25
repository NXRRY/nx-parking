-- parking/config.lua
-- Configuration for the parking system

Config = {}

-- Enable debug mode to see extra console logs (e.g., zone enter/exit)
Config.Debug = true

-- Enable /park command
Config.EnableParkCommand = true

-- Notification system: 'ox', 'qb', or 'chat'
Config.notifyType = 'ox'

-- Depot locations where players can retrieve impounded vehicles
Config.Depot = {
    {
        name = "Legion Depot",
        coords = vector4(409.28, -1623.88, 29.29, 236.02),
        spawnPoint = {
            vector4(401.92, -1631.87, 28.97, 328.06),
            vector4(417.02, -1627.9, 28.97, 139.54),
            vector4(421.21, -1635.76, 28.97, 87.72),
            vector4(411.1, -1636.79, 28.97, 50.43),
            vector4(418.49, -1646.45, 28.97, 50.94),
            vector4(405.41, -1652.7, 28.97, 139.85),
            vector4(401.39, -1648.24, 28.97, 319.58),
        },
        marker = {
            type = 2,
            size = vector3(0.8, 0.8, 0.8),
            color = { r = 255, g = 0, b = 0, a = 100 },
        },
        blip = {
            sprite = 67,
            color = 1,
            scale = 0.8,
            name = "Depot",
        }
    }
}

-- Parking zones with job restrictions
Config.ParkingZones = {
    {
        name = "police_station_1",
        title = "Police Station Parking",
        points = {
            vector2(410.82, -1031.62),
            vector2(409.98, -1011.9),
            vector2(457.25, -1011.69),
            vector2(457.66, -1026.4)
        },
        minZ = 20.0,
        maxZ = 40.0,
        debug = true,
        allowJobs = {
            ['ambulance'] = true,
            ['police'] = true
        }
    },
    {
        name = "parking_mall_2",
        title = "Parking Mall 2",
        points = {
            vector2(-1415.66, -2781.17),
            vector2(-1400.23, -2781.17),
            vector2(-1400.23, -2795.84),
            vector2(-1415.66, -2795.84)
        },
        minZ = 10.0,
        maxZ = 30.0,
        debug = true,
        -- No allowJobs means everyone can park
    },
}

-- Localized strings (Thai)
Config.Strings = {
    -- Vehicle list menu
    list_not_found_title = "ไม่พบข้อมูล",
    list_not_found_desc = "คุณไม่มีรายการรถในระบบ",
    list_menu_title = "รายการรถของฉัน",
    list_item_desc = "ทะเบียน: %s | สถานะ: %s",

    -- Vehicle list statuses
    status_list_out = "ไม่ได้ทำการจอด",
    status_list_parked = "จอดเข้าระบบ",
    status_list_impounded = "ถูกยึดโดยเจ้าหน้าที่",

    -- Vehicle detail menu
    vehicle_detail_title = "ข้อมูลรถ: %s",
    location_title = "📍 ตำแหน่งล่าสุด",
    location_desc = "ถนน: %s กดเพื่อนำทาง",
    location_notify = "ตำแหน่งล่าสุดของรถถูกตั้งเป็น GPS แล้ว",

    status_title = "🚦 สถานะปัจจุบัน",
    status_unknown = "ไม่ทราบสถานะ",
    status_out = "ไม่ได้ทำการจอด",
    status_parked = "จอดเข้าระบบ (Parking)",
    status_impounded = "ถูกยึด (Impounded)",

    engine_title = "📊 สภาพเครื่องยนต์",
    engine_desc = "สุขภาพเครื่องยนต์: %d%%",

    body_title = "🛡️ สภาพตัวถัง",
    body_desc = "ความแข็งแรงตัวถัง: %d%%",

    fuel_title = "⛽ ระดับน้ำมัน",
    fuel_desc = "น้ำมันคงเหลือ: %d%%",

    -- Take out vehicle
    prog_take_out = "กำลังนำรถออกจากที่จอด...",
    take_out_success = "นำรถออกจากระบบเรียบร้อยแล้ว",
    take_out_cancel = "ยกเลิกการนำรถออก",

    -- Target interactions
    target_take_out = "นำรถออกจากที่จอด",
    target_check = "ตรวจสอบสถานะรถ",

    -- Parking
    prog_parking = "กำลังทำการจอดรถ...",
    park_success = "จอดรถเรียบร้อยแล้ว",
    park_cancel = "ยกเลิกการจอดรถ",
    not_owner = "คุณไม่ใช่เจ้าของรถคันนี้",

    -- General notifications
    menu_title = "ระบบจอดรถ",
    notify_success = "สำเร็จ",
    notify_error = "เกิดข้อผิดพลาด",
    notify_warning = "คำเตือน",
    notify_info = "ข้อมูล",

    -- Parking condition checks
    not_in_veh = "คุณต้องอยู่บนรถเพื่อดำเนินการ",
    no_parking_zone = "บริเวณนี้ไม่อนุญาตให้จอดรถ",
    not_driver = "คุณต้องเป็นคนขับเท่านั้น",
    slow_down = "กรุณาจอดรถให้สนิทก่อน",
}