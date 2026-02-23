Config = {}
Config.notifyType = 'ox' -- Options: 'qb', 'okok', 'chat', 'ox'
Config.Debug = false

Config.ParkingZones = {
    {
        name = "parking_square_1",
        points = {
            vector2(-1437.83, -2781.57),
            vector2(-1422.40, -2781.57),
            vector2(-1422.40, -2796.24),
            vector2(-1437.83, -2796.24)
        },
        minZ = 10.0,
        maxZ = 30.0,
        debug = true,
        allowJobs = {
            ['ambulance'] = true,
            ['police'] = true
        }
    },
    {
        name = "parking_mall_2",
        points = {
            vector2(-1415.66, -2781.17),
            vector2(-1400.23, -2781.17),
            vector2(-1400.23, -2795.84),
            vector2(-1415.66, -2795.84)
        },
        minZ = 10.0,
        maxZ = 30.0,
        debug = true,
    },
}

Config.Strings = {
    -- Notifications
    ['not_in_veh'] = 'You are not in a vehicle.',
    ['not_driver'] = 'You must be the driver to perform this action!',
    ['slow_down'] = 'Please slow down before parking!',
    ['not_owner'] = 'This is not a personal vehicle. You cannot park here.',
    ['park_success'] = 'Vehicle parked and doors locked successfully.',
    ['park_cancel'] = 'Parking cancelled.',
    ['unpark_not_found'] = 'No parked vehicle found in range.',
    ['unpark_not_owner'] = 'You do not own this vehicle.',
    ['unpark_success'] = 'Vehicle unlocked and ready for use.',
    ['unpark_cancel'] = 'Unlocking cancelled.',
    ['veh_not_found'] = 'No vehicle data found.',
    ['veh_already_out'] = 'Vehicle [%s] is already out in the city. GPS marked.',
    ['too_far'] = 'You are too far from the parking location.',
    ['gps_set'] = 'You are too far away. A GPS waypoint has been set.',
    ['spawn_cancel'] = 'Vehicle retrieval cancelled.',
    ['spawn_success'] = 'Vehicle [%s] has arrived.',
    ['not_parked_here'] = 'This vehicle is not parked here.',
    ['no_parking_zone'] = 'You cannot park here! This area is a no-parking zone.',
    ['no_parking_zone_all'] = '🚫 **NO PARKING ZONE** : All vehicles are strictly prohibited',
    ['no_parking_zone_jobs'] = '⚠️ **RESTRICTED AREA** : Authorized for [ %s ] only',
    
    -- Progress Bar Labels
    ['prog_parking'] = 'Saving parking location...',
    ['prog_unparking'] = 'Unlocking vehicle...',
    ['prog_spawning'] = 'Retrieving vehicle from system...',

    -- Menu UI
    ['menu_title'] = 'Parking System',
    ['my_veh_title'] = 'My Vehicles',
    ['current_veh_info'] = '🚘 Current Vehicle Info',
    ['current_veh_desc'] = 'Model: %s\nPlate: %s\nFuel: %d%%\nEngine: %d%%',
    ['btn_park'] = '📍 Park Vehicle',
    ['btn_park_desc'] = 'Save location and lock vehicle',
    ['btn_unpark'] = '🔓 Unlock Parking',
    ['btn_unpark_desc'] = 'Unlock your parked vehicle',
    ['btn_my_veh'] = '🚗 My Vehicles',
    ['btn_my_veh_desc'] = 'View list of all your vehicles',
    
    -- Blip & State
    ['blip_name'] = 'Parked Vehicle [%s]',
    ['state_parked'] = 'Parked',
    ['state_impounded'] = 'Impounded',
    ['state_unknown'] = 'Unknown',
    ['veh_list_desc'] = 'Engine: %d%% | Status: %s'
}
