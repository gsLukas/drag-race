local QBCore = exports['qb-core']:GetCoreObject()
-- O objeto global Config já está disponível via shared_script no manifest

    -- Variáveis globais auxiliares
    local raceThreads = {}
    local tyreWear = 0
    local opponentNames = nil
    local splitText = ''
    local splitTimer = 0
    local inRace = false
    local raceMode = nil
    local startTime = 0
    local burnedStart = false
    local raceTimeoutId = nil


    local serverId = GetPlayerServerId(PlayerId())




    local function getPlayerVehicle()
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        return veh ~= 0 and veh or nil
    end

    local function isMuscleVehicle(veh)
        veh = veh or getPlayerVehicle()
        if veh == 0 or not veh then return false end
        local model = GetEntityModel(veh)
        for _, allowed in ipairs(Config.AllowedVehicles.Recommended) do
            if model == GetHashKey(allowed) then return true end
        end
        for _, allowed in ipairs(Config.AllowedVehicles.NotRecommended) do
            if model == GetHashKey(allowed) then return true end
        end
        return false
    end

    -- Limpa threads e variáveis antigas

    function CleanRaceState()
        inRace = false
        burnedStart = false
        opponentNames = nil
        tyreWear = 0
        if raceTimeoutId then
            Citizen.ClearTimeout(raceTimeoutId)
            raceTimeoutId = nil
        end
    end

    -- Recebe nomes dos adversários
    RegisterNetEvent('qb-race:setOpponents', function(names)
        opponentNames = names
    end)

    -- Proximity check and marker drawing handled in optimized loop at the end of the file.

    -- Opcional: Detectar timeout de início da corrida
    local raceTimeoutId = nil
    RegisterNetEvent('qb-race:queued')
    AddEventHandler('qb-race:queued', function()
        QBCore.Functions.Notify('Você entrou na fila. Aguardando outro jogador...', 'primary')
        if raceTimeoutId then
            Citizen.ClearTimeout(raceTimeoutId)
            raceTimeoutId = nil
        end
        raceTimeoutId = Citizen.SetTimeout(30000, function()
            if not inRace then
                QBCore.Functions.Notify('Tempo de espera excedido. Corrida não iniciada.', 'error')
            end
            raceTimeoutId = nil
        end)
        table.insert(raceThreads, raceTimeoutId)
    end)


RegisterNetEvent('qb-race:startSolo')
AddEventHandler('qb-race:startSolo', function(trackId)
    StartRace(GetGameTimer(), "treino", trackId)
end)

RegisterNetEvent('qb-race:startRace')
AddEventHandler('qb-race:startRace', function(timestamp, trackId)
    StartRace(timestamp, "disputa", trackId)
    AddXP_Disputa()
end)

    --[[ ========================
    MELHORIA: INTEGRAÇÃO DO CONTADOR ANIMADO E FLUXO MODERNO
    ======================== ]]
    local startFaults = 0
    local maxFaults = 1 -- Só 1 oportunidade de queima em disputa (mas agora não reinicia mais)
    local raceSignalCallback = nil

    RegisterNUICallback('signalDone', function(_, cb)
        if raceSignalCallback then
            raceSignalCallback()
            raceSignalCallback = nil
        end
        if cb then cb() end
    end)

    function StartRace(startTimestamp, mode, trackId)
        if inRace and not IsPauseMenuActive() then return end
        raceMode = mode
        inRace = true
        burnedStart = false
        local currentTrack = trackId or "default"
        startTime = GetGameTimer()


        local ped = PlayerPedId()
        local veh = getPlayerVehicle()
        local function warpVehicleToStart(mode, veh)
            local pos
            if mode == "disputa" then
                pos = Config.StartPositions.Player1Start
            else
                local starts = {}
                for _, v in pairs(Config.StartPositions) do table.insert(starts, v) end
                local idx = #starts > 0 and math.random(1, #starts) or 1
                pos = starts[idx]
            end
            SetEntityCoords(veh, pos.x, pos.y, pos.z)
            SetEntityHeading(veh, pos.w)
        end
        warpVehicleToStart(mode, veh)

        -- SÓ UM SINALEIRO/CONTADOR: NUI faz toda a sequência
        SendNUIMessage({ showCountdown = true })

        -- XP só será concedido ao finalizar a corrida sem burnout

        local state = { burned = false }
        local burnReleased = false
        -- Start burn monitor timer with NUI
        CreateThread(function()
            Wait(3000) -- 3 seconds: same as traffic light/countdown
            burnReleased = true
        end)

        -- BURN MONITOR: only if moved more than 1m BEFORE green

        local function showTemporaryBurnNotice(msg, faults)
            SendNUIMessage({
                showResult = true,
                time = 0,
                burned = true,
                personalBest = tonumber(GetResourceKvpString("bestTime")) or 0,
                faults = faults
            })
            QBCore.Functions.Notify(msg, 'error')
            Citizen.SetTimeout(3000, function()
                SendNUIMessage({ reset = true })
            end)
        end

        -- Thread unificada para monitoramento do veículo
        CreateThread(function()
            local veh = getPlayerVehicle()
            local startPos = GetEntityCoords(veh)
            local lastPos = startPos
            while inRace do
                Wait(20)
                veh = getPlayerVehicle()
                if veh == nil then
                    inRace = false
                    QBCore.Functions.Notify('Você foi desclassificado: saiu do carro durante a corrida.', 'error')
                    SendNUIMessage({ reset = true })
                    break
                end
                local currentPos = GetEntityCoords(veh)
                -- Queima de largada
                if not burnedStart and not burnReleased then
                    local dist = #(startPos - currentPos)
                    if dist > 1.0 then
                        burnedStart = true
                        PlayBurnoutSmoke(veh)
                        if raceMode == "disputa" then
                            inRace = false
                            QBCore.Functions.Notify('Desclassificado! Oponente venceu.', 'error')
                            TriggerServerEvent('qb-race:largadaDesclassificado', serverId)
                            SendNUIMessage({ reset = true })
                            break
                        else
                            showTemporaryBurnNotice('QUEIMOU A LARGADA! (Treino)', 0)
                        end
                    end
                end
                -- Linha de chegada
                if HasCrossedFinishLine(lastPos, currentPos, Config.FinishLinePoints) then
                    local endTime = GetGameTimer()
                    local totalTime = (endTime - startTime) / 1000
                    -- Só ganha XP extra se não queimou a largada
                    if not burnedStart then
                        if raceMode == "disputa" then
                            AddXP_Vitoria()
                        else
                            AddXP_Treino()
                        end
                    end
                    EndRace(totalTime, currentTrack)
                    break
                end
                lastPos = currentPos
            end
        end)

        -- Partículas na largada
        PlayStartParticles(veh)
    end

    --[[ ========================
    MELHORIA: PERSONAL BEST E FEEDBACK VISUAL
    ======================== ]]
    function EndRace(time, trackId)
        inRace = false
        -- Salva melhor tempo localmente
        local bestTime = tonumber(GetResourceKvpString("bestTime"))
        if not bestTime or (time < bestTime) then
            SetResourceKvp("bestTime", tostring(time))
            bestTime = time
        end
        local split = ''
        if bestTime and bestTime > 0 then
            split = string.format('Tempo: %.2fs | Melhor: %.2fs', time, bestTime)
        end
        splitText = split
        splitTimer = 160 -- ~8 segundos
        SendNUIMessage({
            showResult = true,
            time = time,
            burned = burnedStart,
            personalBest = bestTime
        })
        if raceMode == "disputa" then
            TriggerServerEvent('qb-race:logResult', {
                track = trackId or "default",
                time = time,
                venceu = not burnedStart -- true se não queimou, false se queimou
            })
            if not burnedStart then
                -- Só ganha XP se cruzar a linha de chegada sem queimar
                AddXP_Vitoria()
                TriggerServerEvent("qb-race:syncFireworks")
            else
                QBCore.Functions.Notify('❌ Queimou a largada! Você perdeu 1 XP.', 'error')
                CheckIfRegisteredAndAddXP(-1)
            end
            Wait(5000)
            SendNUIMessage({ reset = true })
        else
            -- Modo treino: apenas mostra resultado e reseta UI
            -- Só ganha XP se cruzar a linha de chegada sem queimar
            if not burnedStart then
                AddXP_Treino()
            end
            Wait(5000)
            SendNUIMessage({ reset = true })
            -- Não reinicia mais o treino automaticamente
        end
    end

    -- Função para reiniciar treino com novo contador/semáforo

function RetryTraining(trackId)
    local veh = getPlayerVehicle()
    if veh ~= nil and veh ~= 0 then
        local idx = math.random(1, #Config.StartPositions)
        local pos = Config.StartPositions[idx]
        SetEntityCoords(veh, pos.x, pos.y, pos.z, false, false, false, true)
        SetEntityHeading(veh, pos.w)
        Wait(1000)
        StartRace(GetGameTimer(), "treino", trackId)
    end
end

function HasCrossedFinishLine(prevPos, currPos, finishPoints)
    -- Considera cruzado se passar qualquer segmento entre pontos consecutivos
    local function Vector2(v)
        return vector2(v.x, v.y)
    end
    local function LinesIntersect(p1, p2, q1, q2)
        local function ccw(a, b, c)
            return (c.y - a.y) * (b.x - a.x) > (b.y - a.y) * (c.x - a.x)
        end
        return (ccw(p1, q1, q2) ~= ccw(p2, q1, q2)) and (ccw(p1, p2, q1) ~= ccw(p1, p2, q2))
    end
    for i = 1, #finishPoints - 1 do
        if LinesIntersect(Vector2(prevPos), Vector2(currPos), Vector2(finishPoints[i]), Vector2(finishPoints[i+1])) then
            return true
        end
    end
    return false
end

    RegisterNetEvent("qb-race:fireworksAll")
    AddEventHandler("qb-race:fireworksAll", function()
        -- Efeito de fogos coloridos (exemplo)
        local p1 = Config.FinishLinePoints[1]
        local p2 = Config.FinishLinePoints[2]
        local mid = {
            x = (p1.x + p2.x) / 2,
            y = (p1.y + p2.y) / 2,
            z = (p1.z + p2.z) / 2
        }
        local baseZ = mid.z + 1.0

        RequestNamedPtfxAsset("scr_indep_firework")
        while not HasNamedPtfxAssetLoaded("scr_indep_firework") do
            Wait(0)
        end

        local effects = {"scr_indep_firework_starburst", "scr_indep_firework_trailburst", "scr_indep_firework_shotburst"}

        for i = 1, 5 do
            local fx = effects[math.random(1, #effects)]
            UseParticleFxAssetNextCall("scr_indep_firework")
            StartParticleFxNonLoopedAtCoord(fx, mid.x + math.random(-2, 2), mid.y + math.random(-2, 2),
                baseZ + math.random(1, 3), 0.0, 0.0, 0.0, 1.0, false, false, false)
            Wait(350)
        end
    end)

    -- Tecla para sair da corrida (F6)
    CreateThread(function()
        while true do
            Wait(0)
            if IsControlJustPressed(0, 167) then -- F6
                if inRace and not IsPauseMenuActive() then
                    inRace = false
                    SendNUIMessage({ reset = true })
                    QBCore.Functions.Notify('Você saiu da corrida.', 'error')
                end
                TriggerServerEvent('qb-race:leaveQueue')
            end
        end
    end)

    -- HUD: Exibe status da corrida no canto superior esquerdo

    -- HUD otimizado: desenha tudo em um único loop, polling reduzido
    CreateThread(function()
        while true do
            if inRace and not IsPauseMenuActive() then
                Wait(0)
                local text = (raceMode == "disputa") and "Em Disputa - F6 para sair" or "Treino - F6 para sair"
                SetTextFont(4)
                SetTextProportional(1)
                SetTextScale(0.35, 0.35)
                SetTextColour(255, 255, 255, 180)
                SetTextOutline()
                SetTextEntry("STRING")
                AddTextComponentString(text)
                DrawText(0.03, 0.12)
                if opponentNames then
                    SetTextFont(4)
                    SetTextScale(0.32, 0.32)
                    SetTextColour(255, 255, 0, 180)
                    SetTextEntry("STRING")
                    AddTextComponentString("Adversário(s): "..table.concat(opponentNames, ", "))
                    DrawText(0.03, 0.16)
                end
                if splitTimer > 0 then
                    SetTextFont(4)
                    SetTextScale(0.32, 0.32)
                    SetTextColour(0, 255, 0, 180)
                    SetTextEntry("STRING")
                    AddTextComponentString(splitText)
                    DrawText(0.03, 0.20)
                    splitTimer = splitTimer - 1
                end
            else
                Wait(100)
            end
        end
    end)

    -- Penaliza sair do carro durante a corrida



    -- Efeito de fumaça ao queimar largada
    
    function PlayBurnoutSmoke(veh)
        RequestNamedPtfxAsset('core')
        while not HasNamedPtfxAssetLoaded('core') do Wait(0) end
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedOnEntity('exp_grd_flare', veh, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
    end

    -- Partículas na largada
    function PlayStartParticles(veh)
        RequestNamedPtfxAsset('core')
        while not HasNamedPtfxAssetLoaded('core') do Wait(0) end
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedOnEntity('ent_sht_flare', veh, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
    end

    -- Melhor loop de proximidade para performance

    local function handleRaceStart(mode)
        local veh = getPlayerVehicle()
        if not isMuscleVehicle(veh) then
            QBCore.Functions.Notify('Você precisa estar em um carro muscle para iniciar.', 'error')
            return
        end
        if mode == 'Treino' then
            local trackId = Config.TrackIds and Config.TrackIds[mode] or 1
            TriggerEvent('qb-race:startSolo', trackId)
        else
            local trackId = Config.ModeToTrackId and Config.ModeToTrackId[mode] or mode
            TriggerServerEvent('qb-race:joinRace', trackId)
        end
    end

    CreateThread(function()
        while true do
            local sleep = 1000
            local coords = GetEntityCoords(PlayerPedId())
            for mode, loc in pairs(Config.Locations) do
                local locPos = loc.pos or loc -- garante compatibilidade
                if #(coords - vector3(locPos.x, locPos.y, locPos.z)) < 10.0 then
                    sleep = 0
                    if #(coords - vector3(locPos.x, locPos.y, locPos.z)) < 5.0 then
                        DrawMarker(1, locPos.x, locPos.y, locPos.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 0.5, 255, 0, 0, 100, false, true)
                        QBCore.Functions.DrawText3D(locPos.x, locPos.y, locPos.z + 1.0, '[E] Iniciar Corrida (' .. mode .. ')')
                        if IsControlJustPressed(0, 38) then
                            handleRaceStart(mode)
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end)

    -- Evento para reiniciar corrida para todos (disputa)

    RegisterNetEvent('qb-race:restartRaceForAll')
    AddEventHandler('qb-race:restartRaceForAll', function(trackId)
        local veh = getPlayerVehicle()
        if veh ~= 0 then
            local pos = Config.StartPositions[1]
            SetEntityCoords(veh, pos.x, pos.y, pos.z)
            SetEntityHeading(veh, pos.w)
            Wait(1000)
            StartRace(GetGameTimer(), "disputa", trackId)
        end
    end)

    -- Comando para leaderboard
    RegisterCommand('rankrace', function()
        TriggerServerEvent('qb-race:getLeaderboard')
    end)


    RegisterNetEvent('qb-race:showLeaderboard', function(list)
        -- Exibe leaderboard visual via NUI
        SendNUIMessage({
            leaderboard = true,
            data = list
        })
        -- Opcional: também notifica texto
        local text = 'TOP 3 TEMPOS:\n'
        for i, v in ipairs(list) do
            text = text .. string.format('%d. %s - %.2fs\n', i, v.name, v.time)
        end
        QBCore.Functions.Notify(text, 'primary', 8000)
    end)

    -- =====================
    -- Corrida com semáforo e delay randômico/fixo
    -- =====================

    local isRacing = false
    local startTime = 0
    local burnStart = false

    -- Função para iniciar a corrida com semáforo
    function StartRaceWithSignal(useRandomDelay)
        if isRacing then return end
        isRacing = true
        burnStart = false

        -- Mostra o semáforo NUI
        SendNUIMessage({ showCountdown = true })
        SetNuiFocus(false, false)

        -- Aguarda delay do semáforo
        local redDelay = Config.GetTrafficLightDelay('red', useRandomDelay)
        Citizen.Wait(redDelay * 1000)
        -- Aqui pode adicionar yellow/green se quiser

        -- Aguarda sequência do NUI
        RegisterNUICallback("signalDone", function(_, cb)
            startTime = GetGameTimer()
            if cb then cb({}) end
        end)

        -- Permite detecção de largada antes do verde
        CreateThread(function()
            local player = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(player, false)
            while isRacing and not burnStart do
                Wait(0)
                if IsPedInAnyVehicle(player, false) and GetIsVehicleEngineRunning(vehicle) then
                    local vel = GetEntitySpeed(vehicle)
                    if vel > 0.1 and startTime == 0 then
                        burnStart = true
                        EndRaceWithSignal(true)
                    end
                end
            end
        end)
    end

    -- Encerrar corrida
    function EndRaceWithSignal(burned)
        isRacing = false
        local endTime = GetGameTimer()
        local totalTime = ((endTime - startTime) / 1000.0)

        SendNUIMessage({
            showResult = true,
            burned = burned,
            time = totalTime
        })

        -- Envia tempo ao servidor (opcional)
        if not burned then
            TriggerServerEvent("qb-drag:recordTime", totalTime)
        end
    end

    -- Comando para iniciar corrida
--    RegisterCommand("iniciarcorrida", function()
  --      StartRaceWithSignal(true) -- true para delay randômico
    --end)

    -- Reset UI (exemplo: cancelar por tecla)
    RegisterCommand("cancelarcorrida", function()
        if isRacing then
            isRacing = false
            SendNUIMessage({ reset = true })
        end
    end)

    function isVehicleAllowed(vehModel)
        for _, model in ipairs(Config.AllowedVehicles.Recommended) do
            if vehModel == GetHashKey(model) then
                return true
            end
        end
        for _, model in ipairs(Config.AllowedVehicles.NotRecommended) do
            if vehModel == GetHashKey(model) then
                return true
            end
        end
        return false
    end

    -- Solicita histórico de corridas
RegisterCommand("meuhistorico", function()
    TriggerServerEvent("qb-race:getRaceHistory")
end)

RegisterNetEvent("qb-race:showRaceHistory", function(history)
    SendNUIMessage({ showHistory = true, history = history })
end)

RegisterNetEvent("qb-race:showPersonalRecords", function(records)
    SendNUIMessage({ showRecords = true, records = records })
end)

RegisterCommand("minhasconquistas", function()
    TriggerServerEvent("qb-race:getRaceAchievements")
end)

RegisterNetEvent("qb-race:showWeeklyBest", function(best)
    SendNUIMessage({ showAchievements = true, weeklyBest = best })
end)

RegisterNetEvent("qb-race:showWinStreak", function(streak)
    SendNUIMessage({ showAchievements = true, winStreak = streak })
end)