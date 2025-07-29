Config = {}

Config.Locations = {
    Treino = { pos = vector3(1619.14, 3230.75, 39.91), heading = 43.2 },
    Disputa1 = { pos = vector3(1588.33, 3222.32, 40.41), heading = 85.0 },
    Disputa2 = { pos = vector3(1589.99, 3216.28, 40.41), heading = 43.2 },
}

Config.FinishLinePoints = {
    vector3(1190.15, 3122.29, 40.46), -- P1
    vector3(1190.86, 3119.32, 40.43),
    vector3(1191.57, 3116.35, 40.41), -- P2
    vector3(1192.58, 3112.89, 40.41),
    vector3(1193.41, 3109.80, 40.41),
    vector3(1194.69, 3105.20, 40.43)
    
}

Config.StartPositions = {
    Disputa1 = vector4(1575.85, 3221.530, 39.91, 105.),
    Disputa2 = vector4(1577.92, 3212.14, 39.91, 105.44),
    Treino = vector4(1575.85, 3221.0, 39.91, 105.53)
}



Config.AllowedVehicles = {
    Recommended = {
        "dominatorasp", "buffalostx", "arbitergt", "gauntlet4", "impaler", "dominator7", "vigero2", "clique", "dominator6", "ruiner4", "yosemite2", "vamos", "sabregt2", "slamvan3", "tampa", "phoenix", "gauntlet", "dominator", "sabregt", "buccaneer", "vigero", "gauntlet3", "gauntlet5", "tulip2"
    },
    NotRecommended = {
        "chino", "stalion", "ruiner", "blade", "faction", "picador", "moonbeam2", "ratloader2", "slamvan", "ellie", "deviant", "coquette3", "nightshade", "faction3", "dominator3", "tulip"
    }
}

Config.TrafficLightDelays = { red = 5, yellow = 3, green = 1.5 }

Config.TrafficLightRandomRange = {
    red = { min = 4, max = 6 },
    yellow = { min = 2.5, max = 3.5 },
    green = { min = 1.2, max = 1.8 }
}


function Config.GetTrafficLightDelay(color, useRandom)
    if useRandom and Config.TrafficLightRandomRange[color] then
        local min = Config.TrafficLightRandomRange[color].min
        local max = Config.TrafficLightRandomRange[color].max
        return math.random(min * 1000, max * 1000) / 1000 -- retorna em segundos
    elseif Config.TrafficLightDelays[color] then
        return Config.TrafficLightDelays[color]
    else
        return 3 -- fallback padrão
    end
end

Config.RegistroCorrida = vector3(1615.2, 3224.55, 39.91)


Config.XP = {
    Treino = 1,
    Disputa = 2,
    VitoriaDisputa = 5,
}


Config.LevelXP = {
    [0] = 1,
    [1] = 100,
    [2] = 300,
    [3] = 600,
    [4] = 1000,
    [5] = 1500,
}


Config.CustomizacoesPorNivel = {
    [1] = {  -- Nível 1
        visual = {"portas", "retrovisores"},  -- Customizações visuais
        desempenho = {"motor_stage_1", "freios_esportivos"} -- Customizações de desempenho
    },
    [2] = {  -- Nível 2
        visual = {"capo", "spoiler"},
        desempenho = {"transmissao_drag", "embreagem_esportiva"}
    },
    [3] = {  -- Nível 3
        visual = {"porta-malas", "saias"},
        desempenho = {"suspensao_drag", "diferencial_curto"}
    },
    [4] = {  -- Nível 4
        visual = {"farois", "para-choque", "roda"},
        desempenho = {"turbo", "pneus_drag", "escapamento_esportivo"}
    },
    [5] = {  -- Nível 5
        visual = {"completo", "pintura especial"},
        desempenho = {"motor_stage_3", "nitro", "controle_lancamento", "peso_reduzido"}
    },
}

Config.getCustomizacoesPorNivel = function(level)
    local customizacoes = { visual = {}, desempenho = {} }

    local maxLevel = 5
    if type(level) ~= "number" or level < 1 then
        level = 1
    end
    level = math.min(level, maxLevel)

    for lvl = 1, level do
        if Config.CustomizacoesPorNivel[lvl] then
            for _, custom in ipairs(Config.CustomizacoesPorNivel[lvl].visual or {}) do
                table.insert(customizacoes.visual, custom)
            end
            for _, custom in ipairs(Config.CustomizacoesPorNivel[lvl].desempenho or {}) do
                table.insert(customizacoes.desempenho, custom)
            end
        end
    end

    return customizacoes
end
