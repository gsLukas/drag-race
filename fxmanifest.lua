fx_version 'cerulean'
game 'gta5'

description 'qb-race - Corrida de arrancada (drag race) + Sistema de XP e Customizações'
author 'Grupo Sales, pikolin0 & gsLukao'
version '2.7.1'

dependency 'qb-core'

shared_script 'config.lua'

client_scripts {
    'client.lua',
    'client/main.lua',
    'client/mods.lua',
    'npc.lua'
}

server_scripts {
    'server.lua',
    '@qb-core/server/main.lua',
    'server/main.lua'
}

exports {
    'AddXP_Treino',
    'AddXP_Disputa',
    'AddXP_Vitoria'
}

ui_page 'html/nui.html'

files {
    'html/nui.html',
    'html/**/*.js',
    'html/**/*.mp3',
    'html/**/*.svg',
    'html/img/*',
    'html/**/*.css',
    'html/sounds/*'
}