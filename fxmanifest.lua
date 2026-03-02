fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_fxv2_oal 'yes'
author 'NXRRY'
description 'A parking system for FiveM servers.'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

server_script {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/PolyZone.lua',  -- Important: use PolyZone.lua, not BoxZone alone
    'client/*.lua'
}
