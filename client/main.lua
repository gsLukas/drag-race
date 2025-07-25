local QBCore = exports['qb-core']:GetCoreObject()

-- FiveM native vector3
local vector3 = vector3
local registered = false

local xpHUD = nil
local xpTimer = 0

RegisterNetEvent('qb-drag-xp:showXP')
AddEventHandler('qb-drag-xp:showXP', function(xp, level)
    xpHUD = { xp = xp, level = level }
    xpTimer = GetGameTimer() + 7000 -- Exibir por 7 segundos
end)

-- Desenhar XP na telaSim,
CreateThread(function()
    while true do
        if xpHUD and GetGameTimer() < xpTimer then
            Wait(0)
            local nivelTxt = xpHUD.level == -1 and "—" or tostring(xpHUD.level)
            DrawText2D(("🏁 XP: %d | Nível: %s"):format(xpHUD.xp, nivelTxt), 0.85, 0.8, 0.6)
        else
            Wait(500) -- Reduz o uso de CPU quando não há informações para exibir
        end
    end
end)

function DrawText2D(text, x, y, scale)
    SetTextFont(0)
    SetTextProportional(false)
    SetTextScale(scale, scale)
    -- Otimização: calcula cor antes de desenhar
    local color = {r = 255, g = 255, b = 255, a = 215} -- padrão (branco)
    if xpHUD and xpHUD.level and xpHUD.level >= 1 then
        color = {r = 0, g = 255, b = 0, a = 215} -- verde
    elseif xpHUD and xpHUD.xp and xpHUD.xp >= 100 then
        color = {r = 255, g = 255, b = 0, a = 215} -- amarelo
    end
    SetTextColour(color.r, color.g, color.b, color.a)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Blip fixo no mapa
CreateThread(function()
    local blip = AddBlipForCoord(Config.RegistroCorrida.x, Config.RegistroCorrida.y, Config.RegistroCorrida.z)
    SetBlipSprite(blip, 38)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Registro Corrida")
    EndTextCommandSetBlipName(blip)
end)


CreateThread(function()
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        local registro = Config.RegistroCorrida
        if #(coords - vector3(registro.x, registro.y, registro.z)) < 10.0 then
            sleep = 0
            if #(coords - vector3(registro.x, registro.y, registro.z)) < 5.0 then
                local markerColor = not registered and {0, 150, 255, 120} or {0, 100, 200, 255}
                DrawMarker(1, registro.x, registro.y, registro.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 0.5, markerColor[1], markerColor[2], markerColor[3], markerColor[4], false, true)
                if not registered then
                    QBCore.Functions.DrawText3D(registro.x, registro.y, registro.z + 1.0, '[E] Registrar-se no Sistema de Corridas')
                    if #(coords - vector3(registro.x, registro.y, registro.z)) < 1.5 and IsControlJustPressed(0, 38) then
                        registered = true
                        TriggerServerEvent("qb-drag-xp:setRegistered", true)
                        TriggerEvent('qb-drag-xp:showXP', 0, -1)
                        QBCore.Functions.Notify('🏁 Você está registrado! Corra para ganhar XP.', 'success')
                        PlaySoundFrontend(-1, "SELECT", "HUD_LIQUOR_STORE", true)
                    end
                else
                    QBCore.Functions.DrawText3D(registro.x, registro.y, registro.z + 1.0, 'Você já está registrado!')
                end
            end
        end
        Wait(sleep)
    end
end)

function IsPlayerRegistered()
    return registered
end

-- Atualiza registro ao entrar no servidor
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.TriggerCallback("qb-drag-xp:getRegistered", function(result)
        registered = result
    end)
end)
-- Funções utilitárias para XP
-- Função para verificar se o jogador está registrado e adicionar XP
function CheckIfRegisteredAndAddXP(xpAmount)
    if registered then
        TriggerServerEvent('qb-drag-xp:addXP', xpAmount)
    else
        QBCore.Functions.Notify('Você precisa estar registrado para ganhar XP.', 'error')
    end
end

function AddXP_Treino()
    CheckIfRegisteredAndAddXP(Config.XP.Treino)
end

function AddXP_Disputa()
    CheckIfRegisteredAndAddXP(Config.XP.Disputa)
end

function AddXP_Vitoria()
    CheckIfRegisteredAndAddXP(Config.XP.VitoriaDisputa)
end

-- Exports para uso externo
exports("AddXP_Treino", AddXP_Treino)
exports("AddXP_Disputa", AddXP_Disputa)
exports("AddXP_Vitoria", AddXP_Vitoria)

