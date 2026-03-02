Config = {}
Config.Debug = false
-- Enable /park command
Config.EnableParkCommand = true
-- Notification system: 'ox', 'qb', or 'chat'
Config.notifyType = 'ox'
-- Depot locations where players can retrieve impounded vehicles
Config.DefaultSpawnCoords = vector4(-58.01, -1108.42, 26.14, 71.89)

Config.Depot = {
    { -- จุดที่ 1: Legion
        name = "Legion Depot",
        coords = vector4(408.63, -1623.13, 29.29, 228.48),
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
            name = "Legion Depot",
        }
    },
    { -- จุดที่ 2: Sandy Shores (ตัวอย่างการเพิ่มจุด)
        name = "Sandy Depot",
        coords = vector4(1854.24, 3679.31, 33.83, 210.46),
        spawnPoint = {
            vector4(1853.94, 3675.89, 33.32, 210.97),
        },
        marker = {
            type = 2,
            size = vector3(0.8, 0.8, 0.8),
            color = { r = 0, g = 255, b = 0, a = 100 },
        },
        blip = {
            sprite = 67,
            color = 2,
            scale = 0.8,
            name = "Sandy Depot",
        }
    }
}
Config.SpawnimpoundCoords = vector4(422.98, -1014.13, 28.63, 92.53)

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
        debug = false,
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
        debug = false,
        -- No allowJobs means everyone can park
    },
}

Config.ImpoundReasons = {
    -- หมวดหมู่: การจอดและการจราจร (Traffic & Parking)
    { label = 'จอดในที่ห้ามจอด/กีดขวางจราจร ($500 / 30 mins)', value = 'illegal_parking', price = 500, time = 30 },
    { label = 'จอดรถย้อนศร/ในจุดอันตราย ($750 / 45 mins)', value = 'dangerous_parking', price = 750, time = 45 },
    { label = 'ขับรถโดยไม่มีใบอนุญาตขับขี่ ($1,000 / 60 mins)', value = 'no_license', price = 1000, time = 60 },
    
    -- หมวดหมู่: สภาพรถและภาษี (Vehicle Condition & Tax)
    { label = 'ค้างชำระภาษี/แผ่นป้ายทะเบียนขาด ($1,200 / 60 mins)', value = 'tax_evasion', price = 1200, time = 60 },
    { label = 'ดัดแปลงสภาพรถผิดกฎหมาย ($1,500 / 90 mins)', value = 'modified_vehicle', price = 1500, time = 90 },
    { label = 'รถมีสภาพไม่มั่นคงแข็งแรง/อันตราย ($800 / 45 mins)', value = 'unsafe_vehicle', price = 800, time = 45 },

    -- หมวดหมู่: ความผิดร้ายแรง/คดีอาญา (Serious Offenses & Criminal)
    { label = 'ขับรถขณะมึนเมา/เสพสารเสพติด ($2,500 / 120 mins)', value = 'dui', price = 2500, time = 120 },
    { label = 'ขับรถประมาทหวาดเสียว/แข่งรถในทาง ($3,000 / 180 mins)', value = 'street_racing', price = 3000, time = 180 },
    { label = 'ยานพาหนะต้องสงสัย/ใช้ในการก่ออาชญากรรม ($5,000 / 240 mins)', value = 'criminal_vehicle', price = 5000, time = 240 },
    { label = 'รถของกลางเพื่อรอการพิสูจน์หลักฐาน ($2,000 / 120 mins)', value = 'evidence', price = 2000, time = 120 },
    
    -- หมวดหมู่: อื่นๆ
    { label = 'เจ้าของรถถูกจับกุม/ไม่มีผู้ขับขี่แทน ($1,000 / 30 mins)', value = 'owner_arrested', price = 1000, time = 30 },
}

-- Localized strings (Thai)
Config.Strings = {
    -- Vehicle list menu
    list_not_found_title = "Data Not Found",
    list_not_found_desc = "You do not have any vehicles in the system.",
    list_menu_title = "My Vehicle List",
    list_item_desc = "Plate: %s | Status: %s",

    -- Vehicle list statuses
    status_list_out = "Out of Garage",
    status_list_parked = "Parked in System",
    status_list_impounded = "Impounded by Officers",

    -- Vehicle detail menu
    vehicle_detail_title = "Vehicle Info: %s",
    location_title = "📍 Last Known Location",
    location_desc = "Street: %s (Click to Set GPS)",
    location_notify = "Vehicle's last location has been set on your GPS.",

    status_title = "🚦 Current Status",
    status_unknown = "Unknown Status",
    status_out = "Out of Garage",
    status_parked = "Parked (System)",
    status_impounded = "Impounded",

    engine_title = "📊 Engine Condition",
    engine_desc = "Engine Health: %d%%",
    body_title = "🛡️ Body Condition",
    body_desc = "Body Integrity: %d%%",
    fuel_title = "⛽ Fuel Level",
    fuel_desc = "Fuel Remaining: %d%%",

    -- Take out vehicle
    prog_take_out = "Retrieving vehicle from parking...",
    take_out_success = "Vehicle successfully removed from parking system.",
    take_out_cancel = "Retrieval cancelled.",

    -- Target interactions
    target_take_out = "Retrieve Vehicle",
    target_check = "Check Vehicle Status",

    -- Parking
    prog_parking = "Parking vehicle...",
    park_success = "Vehicle successfully parked.",
    park_cancel = "Parking cancelled.",
    not_owner = "You are not the owner of this vehicle.",

    -- General notifications
    menu_title = "Parking System",
    notify_success = "Success",
    notify_error = "Error",
    notify_warning = "Warning",
    notify_info = "Information",

    -- Parking condition checks
    not_in_veh = "You must be inside the vehicle to proceed.",
    no_parking_zone = "Parking is not allowed in this area.",
    not_driver = "You must be the driver to do this.",
    slow_down = "Please come to a complete stop first.",

    -- Depot / Impound / General notifications
    depot_fee_required      = "You must pay a fee of $%s before retrieving the vehicle!",
    gps_set_parked          = "Parking location marked on GPS.",
    cancel_retrieve         = "Vehicle retrieval cancelled.",
    gps_set_current         = "Current vehicle position marked on GPS.",
    vehicle_not_found_depot = "Vehicle not found in this area. Please contact Depot.",
    respawn_success         = "Vehicle coordinates successfully recovered!",
    no_vehicle_in_depot     = "You have no vehicles pending in this depot.",
    vehicle_already_exists  = "Vehicle with plate %s is already out in the world!",
    spawn_point_blocked     = "Spawn area is blocked by another vehicle!",
    spawn_success           = "Vehicle plate %s retrieved (Fuel: %d%%)",
    no_impounded_vehicle    = "You have no impounded vehicles at this time.",
    no_civilians_nearby     = "No citizens detected nearby.",
    release_success         = "Vehicle %s released with all original parts installed.",

    -- Police impound menu (openPoliceImpoundMenu)
    police_impound_header         = "👮 Vehicle Management (Officers Only)",
    police_impound_plate_label    = "License Plate",
    police_impound_type_label     = "Action Type",
    police_impound_type_impound   = "Police Impound (Impound)",
    police_impound_type_depot     = "Send to Public Depot (Depot)",
    police_impound_reason_label   = "Charge / Reason for Violation",
    police_impound_confirm_header = "🚔 Vehicle Impoundment Record",
    police_impound_content_template = [[
---
📋 Action Information
   Plate: %s
   Type: %s

⚖️ Violation Details
   Charge: %s
   Fine: $%s
   Impound Duration: %s

---
🔔 Please Confirm
Confirmation will immediately move the vehicle to the Police Station or Public Depot.
---
    ]],
    police_impound_confirm_btn   = "Confirm Impound",
    police_impound_cancel_btn    = "Cancel",

    -- Vehicle status menu (checkVehicleStatus)
    status_plate_prefix          = "Plate:",
    status_owner_yes             = "✅ Your Vehicle",
    status_owner_no              = "🔒 Someone Else's Vehicle",
    status_takeout_title         = "Retrieve from Parking",
    status_takeout_fee_desc      = "💰 Fee: $%s",
    status_takeout_free_desc     = "🆓 No Charge",
    status_police_menu_title     = "🛡️ Law Enforcement Menu",
    status_police_menu_desc      = "Manage Vehicle / Send to Depot",
    status_menu_header           = "Vehicle Diagnostic",

    -- Vehicle detail actions (showVehicleDetail)
    detail_action_gps_parked      = "📌 Set GPS to Parked Spot",
    detail_action_gps_desc        = "Distance: %.2f meters",
    detail_action_takeout_near    = "🔑 Retrieve Vehicle",
    detail_action_takeout_near_desc = "You are near the vehicle. You can take it out.",
    detail_action_retrieving      = "Fetching vehicle data from storage...",
    detail_action_track           = "📡 Track Current Position",
    detail_action_track_desc      = "Signal detected. Marking location on map.",
    detail_action_depot_contact   = "📂 Contact Depot Officer",
    detail_action_depot_contact_desc = "No signal detected. Please check the public impound.",
    detail_action_blocked         = "🚫 Access Denied",
    detail_action_blocked_desc    = "This vehicle is currently restricted.",

    -- Depot target
    depot_target_label            = "View Pending Vehicles (%s)",
    depot_item_desc               = "Retrieval Fee: $%s",

    -- Radial menu
    radial_park                   = "Park Vehicle",
    radial_list                   = "My Parked Vehicles",

    -- Impound menu
    impound_target_label          = "Contact Impound Officer",
    impound_item_desc             = "📅 Date: %s\n⚖️ Charge: %s\n💰 Fine: $%s",
    impound_time_left             = "Time Remaining",
    impound_menu_title            = "Impounded Vehicles List",

    -- Police search menu
    police_target_label           = "Search Impound Records",
    police_search_header          = "Impound Record Check",
    police_search_label           = "Select Nearby Citizen",
    police_impound_details_desc   = "📅 Date: %s\n⚖️ Charge: %s\n💰 Fine: $%s\n⏳ Remaining: %s",
    police_release_header         = "Confirm Vehicle Release",
    police_release_content        = "Do you want to release plate %s to this citizen?",
    police_impound_view_title     = "Impound Records for: %s",

    -- เพิ่มต่อท้ายใน Config.Strings
    zone_allowed_msg              = "✅ You are authorized to park in this area.",
    zone_restricted_msg           = "❌ **No Parking:** Allowed for (%s) only",
    zone_no_jobs_msg              = "No parking for any profession",
    zone_default_title            = "Parking Zone",

        -- Server-side notifications
    vehicle_not_found_data        = "Vehicle data not found.",
    payment_success               = "Fee of $%s has been paid successfully.",
    insufficient_funds            = "You do not have enough funds to retrieve the vehicle!",
    retrieve_free_success         = "Vehicle retrieved successfully (No fee applied).",
    insufficient_funds_required   = "Insufficient funds (Requires $%s).",
    impound_success               = "Vehicle plate %s has been impounded (State 2).",
    depot_success                 = "Vehicle plate %s has been sent to the depot (State 0).",
    vehicle_entity_not_found      = "Vehicle entity not found (Possible sync issue).",
    release_success_officer       = "Vehicle plate %s has been successfully released.",
    vehicle_not_found             = "This vehicle could not be found in the database.",
    vehicle_released_notify       = "Your vehicle has been released. The keys are with you.",
}
