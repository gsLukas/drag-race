local QBCore = exports["qb-core"]:GetCoreObject()
local raceThreads = {}
local tyreWear = 0
local opponentNames = nil
local splitText = ""
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
    if veh == 0 or not veh then
        return false
    end
    local model = GetEntityModel(veh)
    for _, allowed in ipairs(Config.AllowedVehicles.Recommended) do
        if model == GetHashKey(allowed) then
            return true
        end
    end
    for _, allowed in ipairs(Config.AllowedVehicles.NotRecommended) do
        if model == GetHashKey(allowed) then
            return true
        end
    end
    return false
end

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

RegisterNetEvent(
    "qb-race:setOpponents",
    function(names)
        opponentNames = names
    end
)

RegisterNetEvent("qb-race:startSolo")
AddEventHandler(
    "qb-race:startSolo",
    function(trackId)
        StartRace(GetGameTimer(), "treino", trackId)
    end
)

RegisterNetEvent("qb-race:startRace")
AddEventHandler(
    "qb-race:startRace",
    function(timestamp, trackId, slot)
        local startPos
        if slot == 1 then
            startPos = Config.StartPositions.Disputa1
        elseif slot == 2 then
            startPos = Config.StartPositions.Disputa2
        else
            startPos = Config.StartPositions.Disputa1 -- fallback
        end

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh and veh ~= 0 then
            SetEntityCoords(veh, startPos.x, startPos.y, startPos.z, false, false, false, true)
            SetEntityHeading(veh, startPos.w or 0.0)
        else
            SetEntityCoords(ped, startPos.x, startPos.y, startPos.z, false, false, false, true)
            SetEntityHeading(ped, startPos.w or 0.0)
        end

        Wait(1000)
        StartRace(timestamp, "disputa", trackId)
    end
)

local startFaults = 0
local maxFaults = 1
local raceSignalCallback = nil

RegisterNUICallback(
    "signalDone",
    function(_, cb)
        if raceSignalCallback then
            raceSignalCallback()
            raceSignalCallback = nil
        end
        if cb then
            cb()
        end
    end
)

function StartRace(startTimestamp, mode, trackId)
    if inRace and not IsPauseMenuActive() then
        return
    end
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
            pos = Config.StartPositions.Disputa1
        else
            local starts = {}
            for _, v in pairs(Config.StartPositions) do
                table.insert(starts, v)
            end
            local idx = #starts > 0 and math.random(1, #starts) or 1
            pos = starts[idx]
        end
        SetEntityCoords(veh, pos.x, pos.y, pos.z)
        SetEntityHeading(veh, pos.w)
    end
    warpVehicleToStart(mode, veh)
    SendNUIMessage({showCountdown = true})

    local state = {burned = false}
    local burnReleased = false
    CreateThread(
        function()
            Wait(3000)
            burnReleased = true
        end
    )

    local function showTemporaryBurnNotice(msg, faults)
        SendNUIMessage(
            {
                showResult = true,
                time = 0,
                burned = true,
                personalBest = tonumber(GetResourceKvpString("bestTime")) or 0,
                faults = faults
            }
        )
        QBCore.Functions.Notify(msg, "error")
        Citizen.SetTimeout(
            3000,
            function()
                SendNUIMessage({reset = true})
            end
        )
    end
    CreateThread(
        function()
            local veh = getPlayerVehicle()
            local startPos = GetEntityCoords(veh)
            local lastPos = startPos
            while inRace do
                Wait(20)
                veh = getPlayerVehicle()
                if veh == nil then
                    inRace = false
                    QBCore.Functions.Notify("Você foi desclassificado: saiu do carro durante a corrida.", "error")
                    SendNUIMessage({reset = true})
                    break
                end
                local currentPos = GetEntityCoords(veh)
                if not burnedStart and not burnReleased then
                    local dist = #(startPos - currentPos)
                    if dist > 1.0 then
                        burnedStart = true
                        PlayBurnoutSmoke(veh)
                        if raceMode == "disputa" then
                            inRace = false
                            QBCore.Functions.Notify("Desclassificado! Oponente venceu.", "error")
                            TriggerServerEvent("qb-race:largadaDesclassificado", serverId)
                            break
                        else
                            showTemporaryBurnNotice("QUEIMOU A LARGADA! (Treino)", 0)
                        end
                    end
                end
                if HasCrossedFinishLine(lastPos, currentPos, Config.FinishLinePoints) then
                    local endTime = GetGameTimer()
                    local totalTime = (endTime - startTime) / 1000
                    EndRace(totalTime, currentTrack)
                    CleanRaceState()
                    break
                end
                lastPos = currentPos
            end
        end
    )
    PlayStartParticles(veh)
end
function EndRace(time, trackId)
    inRace = false
    local bestTime = tonumber(GetResourceKvpString("bestTime"))
    if not bestTime or (time < bestTime) then
        SetResourceKvp("bestTime", tostring(time))
        bestTime = time
    end
    local split = ""
    if bestTime and bestTime > 0 then
        split = string.format("Tempo: %.2fs | Melhor: %.2fs", time, bestTime)
    end
    splitText = split
    splitTimer = 160 -- ~8 segundos
    SendNUIMessage(
        {
            showResult = true,
            time = time,
            burned = burnedStart,
            personalBest = bestTime
        }
    )
    
    TriggerServerEvent(
        "qb-race:logResult",
        {
            track = trackId or "default",
            time = time,
            venceu = not burnedStart,
            tipoCorrida = raceMode,
            mode = raceMode,
            burned = burnedStart and 1 or 0
        }
    )
    Wait(5000)
    SendNUIMessage({reset = true})
end

function HasCrossedFinishLine(prevPos, currPos, finishPoints)
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
        if LinesIntersect(Vector2(prevPos), Vector2(currPos), Vector2(finishPoints[i]), Vector2(finishPoints[i + 1])) then
            return true
        end
    end
    return false
end

RegisterNetEvent("qb-race:fireworksAll")
AddEventHandler(
    "qb-race:fireworksAll",
    function()
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
            StartParticleFxNonLoopedAtCoord(fx, mid.x + math.random(-2, 2), mid.y + math.random(-2, 2), baseZ + math.random(1, 3), 0.0, 0.0, 0.0, 1.0, false, false, false)
            Wait(350)
        end
    end
)

-- Tecla para sair da corrida (F6)
CreateThread(
    function()
        while true do
            Wait(0)
            if IsControlJustPressed(0, 167) then -- F6
                if inRace and not IsPauseMenuActive() then
                    inRace = false
                    SendNUIMessage({reset = true})
                    QBCore.Functions.Notify("Você saiu da corrida.", "error")
                    CleanRaceState()
                end
                TriggerServerEvent("qb-race:leaveQueue")
            end
        end
    end
)

CreateThread(
    function()
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
                    AddTextComponentString("Adversário(s): " .. table.concat(opponentNames, ", "))
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
    end
)

function PlayBurnoutSmoke(veh)
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do
        Wait(0)
    end
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedOnEntity("exp_grd_flare", veh, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
end

function PlayStartParticles(veh)
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do
        Wait(0)
    end
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedOnEntity("ent_sht_flare", veh, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
end

local function handleRaceStart(mode)
    local veh = getPlayerVehicle()
    if not isMuscleVehicle(veh) then
        QBCore.Functions.Notify("Você precisa estar em um carro muscle para iniciar.", "error")
        return
    end
    if mode == "Treino" then
        local trackId = Config.TrackIds and Config.TrackIds[mode] or 1
        TriggerEvent("qb-race:startSolo", trackId)
    else
        local trackId = Config.ModeToTrackId and Config.ModeToTrackId[mode] or mode
        TriggerServerEvent("qb-race:joinRace", trackId)
    end
end

CreateThread(
    function()
        while true do
            local sleep = 1000
            local coords = GetEntityCoords(PlayerPedId())
            for mode, loc in pairs(Config.Locations) do
                local locPos = loc.pos or loc
                if #(coords - vector3(locPos.x, locPos.y, locPos.z)) < 10.0 then
                    sleep = 0
                    if #(coords - vector3(locPos.x, locPos.y, locPos.z)) < 5.0 then
                        DrawMarker(1, locPos.x, locPos.y, locPos.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 0.5, 255, 0, 0, 100, false, true)
                        QBCore.Functions.DrawText3D(locPos.x, locPos.y, locPos.z + 1.0, "[E] Iniciar Corrida (" .. mode .. ")")
                        if IsControlJustPressed(0, 38) then
                            handleRaceStart(mode) -- mode será "Disputa1" ou "Disputa2"
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end
)

RegisterCommand(
    "rankrace",
    function()
        TriggerServerEvent("qb-race:getLeaderboard")
    end
)

RegisterNetEvent(
    "qb-race:showLeaderboard",
    function(list)
        local leaderboardData = list or {}
        leaderboardData.lastTrainings = {}
        if leaderboardData.treino and type(leaderboardData.treino) == "table" then
            for i = 1, math.min(2, #leaderboardData.treino) do
                table.insert(leaderboardData.lastTrainings, leaderboardData.treino[i])
            end
        end
        leaderboardData.personalBest = leaderboardData.personalBest or nil
        SendNUIMessage(
            {
                leaderboard = leaderboardData
            }
        )
    end
)

local isRacing = false
local startTime = 0
local burnStart = false
function StartRaceWithSignal(useRandomDelay)
    if isRacing then
        return
    end
    isRacing = true
    burnStart = false

    SendNUIMessage({showCountdown = true})
    SetNuiFocus(false, false)

    local redDelay = Config.GetTrafficLightDelay("red", useRandomDelay)
    Citizen.Wait(redDelay * 1000)
    RegisterNUICallback(
        "signalDone",
        function(_, cb)
            startTime = GetGameTimer()
            if cb then
                cb({})
            end
        end
    )
end
CreateThread(
    function()
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
    end
)

function EndRaceWithSignal(burned)
    isRacing = false
    local endTime = GetGameTimer()
    local totalTime = ((endTime - startTime) / 1000.0)

    SendNUIMessage(
        {
            showResult = true,
            burned = burned,
            time = totalTime
        }
    )

    if not burned then
        TriggerServerEvent("qb-drag:recordTime", totalTime)
    end
end

RegisterCommand(
    "cancelarcorrida",
    function()
        if isRacing then
            isRacing = false
            SendNUIMessage({reset = true})
        end
    end
)

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

local challengeFrom = nil

RegisterNetEvent(
    "qb-race:receiveChallenge",
    function(fromId)
        challengeFrom = fromId
        local challengerName = GetPlayerName(GetPlayerFromServerId(fromId))
        QBCore.Functions.Notify("Você foi desafiado para uma corrida por: " .. (challengerName or fromId) .. ". Pressione ~g~Y~s~ para aceitar ou ~r~N~s~ para recusar.", "primary")
        CreateThread(
            function()
                local waiting = true
                local timer = GetGameTimer()
                while waiting and GetGameTimer() - timer < 10000 do -- 10 segundos para responder
                    if IsControlJustReleased(0, 246) then -- Y
                        waiting = false
                        TriggerServerEvent("qb-race:acceptChallenge", challengeFrom)
                        challengeFrom = nil
                        QBCore.Functions.Notify("Desafio aceito!", "success")
                    elseif IsControlJustReleased(0, 249) then -- N
                        waiting = false
                        challengeFrom = nil
                        QBCore.Functions.Notify("Desafio recusado.", "error")
                    end
                    Wait(0)
                end
                challengeFrom = nil
            end
        )
    end
)

RegisterNetEvent(
    "qb-race:showRaceResult",
    function(result)
        if result == "win" then
            SendNUIMessage({showRaceResult = true, text = "VOCÊ GANHOU!"})
        else
            SendNUIMessage({showRaceResult = true, text = "VOCÊ PERDEU!"})
        end
    end
)
