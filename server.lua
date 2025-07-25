local QBCore = exports['qb-core']:GetCoreObject()
local raceQueues = {} -- Armazena filas por pista, ex: raceQueues["airport"] = { player1, player2 }
local startRaceTimeouts = {}

-- Função para montar e enviar lista de nomes para todos na fila
-- XP e Level
function GetPlayerLevel(xp)
    local level = 0
    for lvl, requiredXP in pairs(Config.LevelXP) do
        if xp >= requiredXP and lvl > level then
            level = lvl
        end
    end
    return level
end

function DarXP(playerId, tipoCorrida, venceu)
    if tipoCorrida == "treino" then
        TriggerClientEvent("qb-drag-xp:AddXP_Treino", playerId)
    elseif tipoCorrida == "disputa" then
        TriggerClientEvent("qb-drag-xp:AddXP_Disputa", playerId)
        if venceu then
            TriggerClientEvent("qb-drag-xp:AddXP_Vitoria", playerId)
        end
    end
end
local function notifyQueue(trackId)
    local queue = raceQueues[trackId]
    if not queue or #queue == 0 then return end
    local names = {}
    for _, src in ipairs(queue) do
        local Player = QBCore.Functions.GetPlayer(src)
        local charinfo = Player and Player.PlayerData.charinfo or nil
        if type(charinfo) == "string" then
            charinfo = json.decode(charinfo)
        end
        local name = (charinfo and charinfo.firstname or "N/A") .. " " .. (charinfo and charinfo.lastname or "")
        table.insert(names, name)
    end
    for _, src in ipairs(queue) do
        TriggerClientEvent('qb-race:updateQueue', src, trackId, names)
    end
end

-- Notifica todos da fila ao sair/desconectar
function NotifyAllQueue(trackId, msg)
    local queue = raceQueues[trackId]
    if queue then
        for _, src in ipairs(queue) do
            TriggerClientEvent('QBCore:Notify', src, msg, 'error')
        end
    end
end

-- Função auxiliar para iniciar corrida
local function startRace(trackId)
    local queue = raceQueues[trackId]
    if not queue or #queue < 2 then return end
    local timestamp = os.time()
    -- Notifica no chat todos os jogadores
    local name1 = GetPlayerName(queue[1]) or "?"
    local name2 = GetPlayerName(queue[2]) or "?"
    TriggerClientEvent('chat:addMessage', -1, {
        args = { "🏁 Corrida iniciada!", "Jogadores: " .. name1 .. " vs " .. name2 }
    })
    for _, src in ipairs(queue) do
        local opponent = queue[1] == src and queue[2] or queue[1]
        TriggerClientEvent('qb-race:setOpponents', src, { GetPlayerName(opponent) })
        TriggerClientEvent('qb-race:startRace', src, timestamp, trackId)
    end
    -- Timeout para evitar corrida travada
    if startRaceTimeouts[trackId] and startRaceTimeouts[trackId].timer then
        Citizen.ClearTimeout(startRaceTimeouts[trackId].timer)
    end
    startRaceTimeouts[trackId] = {
        timer = Citizen.SetTimeout(30000, function()
            if raceQueues[trackId] then
                for _, src in ipairs(raceQueues[trackId]) do
                    TriggerClientEvent('QBCore:Notify', src, 'Corrida cancelada por inatividade.', 'error')
                end
                raceQueues[trackId] = nil
                notifyQueue(trackId)
            end
            startRaceTimeouts[trackId] = nil
        end)
    }
    -- Limpa a fila para essa pista após iniciar
    raceQueues[trackId] = nil
end

-- Jogador entra na fila da corrida
RegisterNetEvent('qb-race:joinRace', function(trackId)
    local src = source
    if not raceQueues[trackId] then raceQueues[trackId] = {} end

    -- Previne duplicatas na mesma pista
    for _, p in pairs(raceQueues[trackId]) do
        if p == src then
            TriggerClientEvent('QBCore:Notify', src, 'Você já está na fila.', 'error')
            return
        end
    end

    if #raceQueues[trackId] < 2 then
        table.insert(raceQueues[trackId], src)
        TriggerClientEvent('qb-race:queued', src, trackId)
        notifyQueue(trackId)

        if #raceQueues[trackId] == 2 then
            -- Remove desconectados antes de iniciar
            for i = #raceQueues[trackId], 1, -1 do
                if not GetPlayerName(raceQueues[trackId][i]) then
                    table.remove(raceQueues[trackId], i)
                end
            end
            notifyQueue(trackId)
            if #raceQueues[trackId] < 2 then return end
            -- Evita race condition: processa segundo joinRace no próximo tick
            Citizen.SetTimeout(0, function()
                startRace(trackId)
            end)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Fila cheia. Aguarde.', 'error')
    end
end)

-- Jogador sai da fila manualmente
RegisterNetEvent('qb-race:leaveQueue', function()
    local src = source
    for trackId, queue in pairs(raceQueues) do
        for i = #queue, 1, -1 do
            if queue[i] == src then
                table.remove(queue, i)
                notifyQueue(trackId)
                NotifyAllQueue(trackId, 'Alguém saiu/desconectou da fila.')
                if #queue == 0 then raceQueues[trackId] = nil end
                break
            end
        end
    end
end)

-- Remove jogador da fila ao desconectar
AddEventHandler('playerDropped', function(reason)
    local src = source
    -- Remove da fila, se estiver
    for trackId, queue in pairs(raceQueues) do
        for i = #queue, 1, -1 do
            if queue[i] == src then
                table.remove(queue, i)
                notifyQueue(trackId)
                NotifyAllQueue(trackId, 'Alguém saiu/desconectou da fila.')
                if #queue == 0 then raceQueues[trackId] = nil end
                -- Se era disputa e sobrou só 1, notifica e cancela
                if #queue == 1 then
                    local other = queue[1]
                    TriggerClientEvent('QBCore:Notify', other, 'Oponente saiu/desconectou. Corrida cancelada.', 'error')
                    TriggerClientEvent('qb-race:leaveQueue', other)
                    raceQueues[trackId] = nil
                end
                break
            end
        end
    end
end)

-- Registrar o resultado da corrida no banco
RegisterNetEvent('qb-race:logResult', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local charinfo = Player.PlayerData.charinfo
    if type(charinfo) == "string" then
        charinfo = json.decode(charinfo)
    end
    local first = charinfo and charinfo.firstname or "N/A"
    local last = charinfo and charinfo.lastname or ""
    local name = tostring(first):gsub('[^%w ]','') .. " " .. tostring(last):gsub('[^%w ]','')
    local track = data.track or "desconhecida"
    local time = tonumber(data.time)
    local date = os.date('%Y-%m-%d %H:%M:%S')

    if not time or time < 0.1 or time > 600 then
        print("Resultado inválido recebido do jogador " .. src)
        return
    end

    exports.oxmysql:insert(
        [[INSERT INTO race_results (citizenid, player_name, track, time, date, burned, mode, xp, level) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { citizenid, name, track, time, date, data.burned or 0, data.mode or nil, Player.PlayerData.metadata["dragxp"] or 0, GetPlayerLevel(Player.PlayerData.metadata["dragxp"] or 0) },
        function(success)
            if success then
                print(('[CORRIDA] %s completou "%s" em %.2f segundos'):format(name, track, time))
            else
                print(('[CORRIDA][ERRO] Falha ao salvar resultado para %s na pista %s'):format(name, track))
            end
        end
    )

    -- XP simples: 3 por disputa, +7 se venceu
    -- local currentXP = Player.PlayerData.metadata["dragxp"] or 0
    -- local xpToAdd = 3
    -- local won = data.venceu == true -- usa campo enviado do client
    -- if won then xpToAdd = xpToAdd + 7 end
    -- Player.Functions.SetMetaData("dragxp", currentXP + xpToAdd)
    -- TriggerClientEvent('QBCore:Notify', src, ("+%d XP ganho!"):format(xpToAdd), "success")
    -- Chama função centralizada para XP:
    DarXP(src, data.tipoCorrida or "disputa", data.venceu == true)
end)

-- Sincroniza fogos para todos os jogadores
RegisterNetEvent("qb-race:syncFireworks", function()
    TriggerClientEvent("qb-race:fireworksAll", -1)
end)

-- Reinicia corrida para todos em caso de queimar largada (disputa)


RegisterNetEvent('qb-race:getLeaderboard', function()
    local src = source
    -- Melhores tempos de disputa
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    exports.oxmysql:execute(
        [[SELECT player_name, MIN(time) as best_time FROM race_results WHERE mode = 'disputa' AND burned = 0 GROUP BY citizenid ORDER BY best_time ASC LIMIT 3]],
        {},
        function(disputa)
            -- Últimos tempos de treino do jogador atual
            exports.oxmysql:execute(
                [[SELECT player_name, time, track, date FROM race_results WHERE mode = 'treino' AND burned = 0 AND citizenid = ? ORDER BY date DESC, time ASC LIMIT 2]],
                {citizenid},
                function(treino)
                    -- Melhor tempo pessoal (personalBest)
                    exports.oxmysql:execute(
                        [[SELECT MIN(time) as personalBest FROM race_results WHERE citizenid = ? AND burned = 0]],
                        {citizenid},
                        function(bestResult)
                            local personalBest = bestResult and bestResult[1] and bestResult[1].personalBest or nil
                            TriggerClientEvent('qb-race:showLeaderboard', src, { disputa = disputa, treino = treino, personalBest = personalBest })
                        end
                    )
                end
            )
        end
    )
end)

-- Histórico de corridas do jogador
RegisterNetEvent('qb-race:getRaceHistory', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    -- Últimas 10 corridas
    exports.oxmysql:execute('SELECT track, time, date, venceu FROM race_results WHERE citizenid = ? ORDER BY date DESC LIMIT 10', {citizenid}, function(result)
        TriggerClientEvent('qb-race:showRaceHistory', src, result)
    end)
    -- Recorde pessoal
    exports.oxmysql:execute('SELECT track, MIN(time) as best_time FROM race_results WHERE citizenid = ? GROUP BY track', {citizenid}, function(records)
        TriggerClientEvent('qb-race:showPersonalRecords', src, records)
    end)
end)

-- Conquistas: melhor tempo da semana e sequência de vitórias
RegisterNetEvent('qb-race:getRaceAchievements', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    -- Melhor tempo da semana
    local weekStart = os.date('%Y-%m-%d', os.time() - (os.date('%w') * 86400))
    exports.oxmysql:execute('SELECT player_name, track, MIN(time) as best_time FROM race_results WHERE date >= ? GROUP BY citizenid, track ORDER BY best_time ASC LIMIT 1', {weekStart}, function(week)
        TriggerClientEvent('qb-race:showWeeklyBest', src, week[1])
    end)
    -- Sequência de vitórias
    exports.oxmysql:execute('SELECT COUNT(*) as streak FROM race_results WHERE citizenid = ? AND venceu = 1 AND date >= DATE_SUB(NOW(), INTERVAL 30 DAY)', {citizenid}, function(streak)
        TriggerClientEvent('qb-race:showWinStreak', src, streak[1] and streak[1].streak or 0)
    end)
end)
-- Comando /desafiar [id]
RegisterCommand('desafiar', function(source, args, raw)
    local src = source
    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then
        TriggerClientEvent('QBCore:Notify', src, 'ID inválido.', 'error')
        return
    end
    TriggerClientEvent('qb-race:receiveChallenge', target, src)
    TriggerClientEvent('QBCore:Notify', src, 'Convite enviado!', 'success')
end, false)

RegisterNetEvent('qb-race:acceptChallenge', function(fromId)
    local src = source
    local trackId = 1
    if not raceQueues[trackId] then raceQueues[trackId] = {} end
    -- Prevenção de duplicatas
    for _, p in ipairs(raceQueues[trackId]) do
        if p == src or p == fromId then
            TriggerClientEvent('QBCore:Notify', src, 'Você ou o desafiante já está na fila.', 'error')
            return
        end
    end
    table.insert(raceQueues[trackId], src)
    table.insert(raceQueues[trackId], fromId)
    notifyQueue(trackId)
    Citizen.SetTimeout(0, function()
        startRace(trackId)
    end)
end)

