local QBCore = exports['qb-core']:GetCoreObject()
local activeDisputes = {}
local activeTrainings = {}
local lastResultTime = {}

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
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return end

    local xp = Player.PlayerData.metadata["dragxp"] or 0
    local add = 0

    if tipoCorrida == "treino" and venceu then
        add = Config.XP.Treino
    elseif tipoCorrida == "disputa" then
        if venceu then
            add = Config.XP.VitoriaDisputa
        else
            add = Config.XP.Disputa
        end
    end

    if add > 0 then
        xp = xp + add
        Player.Functions.SetMetaData("dragxp", xp)
        TriggerClientEvent('QBCore:Notify', playerId, ('Você ganhou %d XP de corrida!'):format(add), 'success')
    end
end
RegisterCommand('desafiar', function(source, args, raw)
    local src = source
    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then
        TriggerClientEvent('QBCore:Notify', src, 'ID inválido.', 'error')
        return
    end
    if src == target then
        TriggerClientEvent('QBCore:Notify', src, 'Você não pode desafiar a si mesmo!', 'error')
        return
    end
    if activeDisputes[src] or activeDisputes[target] then
        TriggerClientEvent('QBCore:Notify', src, 'Você ou o desafiante já está em disputa.', 'error')
        return
    end
    TriggerClientEvent('qb-race:receiveChallenge', target, src)
    TriggerClientEvent('QBCore:Notify', src, 'Convite enviado!', 'success')
end, false)
RegisterNetEvent('qb-race:acceptChallenge', function(fromId)
    local src = source
    if activeDisputes[src] or activeDisputes[fromId] then
        TriggerClientEvent('QBCore:Notify', src, 'Você ou o desafiante já está em disputa.', 'error')
        return
    end
    activeDisputes[src] = true
    activeDisputes[fromId] = true
    local timestamp = os.time()
    TriggerClientEvent('qb-race:setOpponents', src, { GetPlayerName(fromId) })
    TriggerClientEvent('qb-race:setOpponents', fromId, { GetPlayerName(src) })
    TriggerClientEvent('qb-race:startRace', src, timestamp, trackId, 1) 
    TriggerClientEvent('qb-race:startRace', fromId, timestamp, trackId, 2) 
end)


RegisterNetEvent('qb-race:startSolo', function(trackId)
    local src = source
    if activeDisputes[src] then
        TriggerClientEvent('QBCore:Notify', src, 'Você está em disputa, não pode iniciar treino!', 'error')
        return
    end
    activeTrainings[src] = true
    TriggerClientEvent('qb-race:startSolo', src, trackId)
end)
RegisterNetEvent('qb-race:leaveQueue', function()
    local src = source
    activeDisputes[src] = nil
    activeTrainings[src] = nil
end)
AddEventHandler('playerDropped', function()
    local src = source
    activeDisputes[src] = nil
    activeTrainings[src] = nil
end)
RegisterNetEvent('qb-race:logResult', function(data)
    local src = source
    local now = os.time()
    if lastResultTime[src] and now - lastResultTime[src] < 5 then
        print("[qb-drag][ERRO] Flood de resultado do jogador:", src)
        return
    end
    lastResultTime[src] = now
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not activeDisputes[src] and not activeTrainings[src] then
        print("[qb-drag][ERRO] Jogador tentou registrar resultado sem estar em corrida:", src)
        return
    end
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
    DarXP(src, data.tipoCorrida or "disputa", data.venceu == true)
    activeDisputes[src] = nil
    activeTrainings[src] = nil

    TriggerClientEvent('qb-race:showRaceResult', src, data.venceu and "win" or "lose")
end)
RegisterNetEvent('qb-race:getLeaderboard', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    exports.oxmysql:execute(
        [[SELECT player_name, MIN(time) as best_time FROM race_results WHERE mode = 'disputa' AND burned = 0 GROUP BY citizenid ORDER BY best_time ASC LIMIT 3]],
        {},
        function(disputa)
            exports.oxmysql:execute(
                [[SELECT player_name, time, track, date FROM race_results WHERE mode = 'treino' AND burned = 0 AND citizenid = ? ORDER BY date DESC, time ASC LIMIT 2]],
                {citizenid},
                function(treino)
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
RegisterNetEvent('qb-race:getRaceHistory', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    exports.oxmysql:execute('SELECT track, time, date, venceu FROM race_results WHERE citizenid = ? ORDER BY date DESC LIMIT 10', {citizenid}, function(result)
        TriggerClientEvent('qb-race:showRaceHistory', src, result)
    end)
    exports.oxmysql:execute('SELECT track, MIN(time) as best_time FROM race_results WHERE citizenid = ? GROUP BY track', {citizenid}, function(records)
        TriggerClientEvent('qb-race:showPersonalRecords', src, records)
    end)
end)
RegisterNetEvent('qb-race:getRaceAchievements', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local weekStart = os.date('%Y-%m-%d', os.time() - (os.date('%w') * 86400))
    exports.oxmysql:execute('SELECT player_name, track, MIN(time) as best_time FROM race_results WHERE date >= ? GROUP BY citizenid, track ORDER BY best_time ASC LIMIT 1', {weekStart}, function(week)
        TriggerClientEvent('qb-race:showWeeklyBest', src, week[1])
    end)
    exports.oxmysql:execute('SELECT COUNT(*) as streak FROM race_results WHERE citizenid = ? AND venceu = 1 AND date >= DATE_SUB(NOW(), INTERVAL 30 DAY)', {citizenid}, function(streak)
        TriggerClientEvent('qb-race:showWinStreak', src, streak[1] and streak[1].streak or 0)
    end)
end)
