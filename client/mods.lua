local QBCore = exports['qb-core']:GetCoreObject()
RegisterCommand("remover", function(_, args, rawCommand)
    -- Verifica se o tipo foi passado como argumento
    local tipo = args[1]
    if not tipo then
        QBCore.Functions.Notify("❌ Use: /remover [portas|capo|porta-malas]", "error")
        return
    end

    -- Função para remover a parte do veículo
    local function removerParte(tipo)
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        
        if tipo == "portas" then
            SetVehicleDoorBroken(veh, 0, true)
            SetVehicleDoorBroken(veh, 1, true)
            QBCore.Functions.Notify("✅ Portas removidas!", "success")
        elseif tipo == "capo" then
            SetVehicleDoorBroken(veh, 4, true)
            QBCore.Functions.Notify("✅ Capô removido!", "success")
        elseif tipo == "porta-malas" then
            SetVehicleDoorBroken(veh, 5, true)
            QBCore.Functions.Notify("✅ Porta-malas removido!", "success")
        else
            QBCore.Functions.Notify("❌ Tipo inválido.", "error")
        end
    end

    -- Chama a callback para verificar o nível e liberar a customização
    QBCore.Functions.TriggerCallback('qb-drag-xp:getXPData', function(data)
        local liberado = false

        -- Verifica se o jogador tem nível suficiente para liberar a customização
        for lvl, itens in pairs(Config.CustomizacoesPorNivel) do
            if data.level >= lvl then
                for _, mod in ipairs(itens.visual or {}) do
                    if mod == tipo then
                        liberado = true
                        break
                    end
                end
                for _, mod in ipairs(itens.desempenho or {}) do
                    if mod == tipo then
                        liberado = true
                        break
                    end
                end
            end
            if liberado then break end
        end

        -- Se o jogador tem permissão, remove a parte do veículo
        if liberado then
            removerParte(tipo)
        else
            QBCore.Functions.Notify("🔒 Nível insuficiente! Participe de corridas para liberar.", "error")
        end
    end)
end)
