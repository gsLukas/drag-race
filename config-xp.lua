Config = {}

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

-- Definições de customizações que são liberadas conforme o nível do jogador
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

    -- Garante que o nível não seja maior que o máximo (5)
    local maxLevel = 5
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
