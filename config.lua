Config = {}

-- Bloco: Posições de início
Config.Locations = {
    Treino = { pos = vector3(1555.13, 3220.62, 40.45), heading = 43.2 },
    Disputa = { pos = vector3(1545.59, 3217.69, 40.45), heading = 85.0 },
}






-- Bloco: Linha de chegada (área ampla)
Config.FinishLinePoints = {
    vector3(1151.44, 3098.92, 39.44), -- P1
    vector3(1149.28, 3107.58, 39.44), -- P2
    vector3(1153.79, 3089.54, 39.44), -- P3
}

-- Bloco: Posições de largada nomeadas
Config.StartPositions = {
    Player1Start = vector4(1518.52, 3201.51, 39.91, 105.79),
    Player2Start = vector4(1520.67, 3193.47, 39.93, 104.99)
}

-- Bloco: Veículos muscle permitidos
Config.AllowedVehicles = {
    Recommended = {
        "dominatorasp", "buffalostx", "arbitergt", "gauntlet4", "impaler", "dominator7", "vigero2", "clique", "dominator6", "ruiner4", "yosemite2", "vamos", "sabregt2", "slamvan3", "tampa", "phoenix", "gauntlet", "dominator", "sabregt", "buccaneer", "vigero", "gauntlet3", "gauntlet5", "tulip2"
    },
    NotRecommended = {
        "chino", "stalion", "ruiner", "blade", "faction", "picador", "moonbeam2", "ratloader2", "slamvan", "ellie", "deviant", "coquette3", "nightshade", "faction3", "dominator3", "tulip"
    }
}
-- Comentário: Os veículos em NotRecommended possuem limitações ou problemas conhecidos ⚠️

-- Bloco: Delays do semáforo
Config.TrafficLightDelays = { red = 5, yellow = 3, green = 1.5 }

-- Bloco: Faixas aleatórias para delays (opcional, para largada menos previsível)
Config.TrafficLightRandomRange = {
    red = { min = 4, max = 6 },
    yellow = { min = 2.5, max = 3.5 },
    green = { min = 1.2, max = 1.8 }
}

-- Função utilitária para obter delay do semáforo
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
-- Exemplo de uso:
-- local delay = Config.GetTrafficLightDelay('red', true) -- randômico
-- local delay = Config.GetTrafficLightDelay('red', false) -- fixo
-- Citizen.Wait(delay * 1000)


-- Posição para registro no sistema de XP (onde o jogador pode se registrar para começar a ganhar XP)
Config.RegistroCorrida = vector3(1539.15, 3211.9, 40.41)

-- Definições de XP para diferentes ações no jogo
Config.XP = {
    Treino = 1,             -- XP por treinar (ex: fazer treinos)
    Disputa = 3,            -- XP por participar de uma disputa
    VitoriaDisputa = 7,     -- XP por vencer uma disputa
}

-- Requisitos de XP para alcançar cada nível
Config.LevelXP = {
    [0] = 1,    -- Nível 0 começa com 1 XP
    [1] = 100,  -- Nível 1 requer 100 XP
    [2] = 300,  -- Nível 2 requer 300 XP
    [3] = 600,  -- Nível 3 requer 600 XP
    [4] = 1000, -- Nível 4 requer 1000 XP
    [5] = 1500, -- Nível máximo com 1500 XP
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

-- Função para retornar as customizações desbloqueadas com base no nível do jogador
Config.getCustomizacoesPorNivel = function(level)
    local customizacoes = { visual = {}, desempenho = {} }

    -- Validação: nível deve ser número entre 1 e 5
    local maxLevel = 5
    if type(level) ~= "number" or level < 1 then
        level = 1
    end
    level = math.min(level, maxLevel)

    -- Adiciona as customizações para o nível até o nível atual
    for lvl = 1, level do
        if Config.CustomizacoesPorNivel[lvl] then
            -- Adiciona as customizações visuais
            for _, custom in ipairs(Config.CustomizacoesPorNivel[lvl].visual or {}) do
                table.insert(customizacoes.visual, custom)
            end
            -- Adiciona as customizações de desempenho
            for _, custom in ipairs(Config.CustomizacoesPorNivel[lvl].desempenho or {}) do
                table.insert(customizacoes.desempenho, custom)
            end
        end
    end

    return customizacoes
end
