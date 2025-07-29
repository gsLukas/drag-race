local QBCore = exports['qb-core']:GetCoreObject()
QBCore.Functions.CreateCallback('qb-drag-xp:getRegistered', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false)
        return
    end
    local registered = Player.PlayerData.metadata["registered"] or false
    cb(registered)
end)
RegisterNetEvent("qb-drag-xp:setRegistered")
AddEventHandler("qb-drag-xp:setRegistered", function(isRegistered)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.PlayerData.metadata["registered"] = isRegistered
        Player.Functions.SetMetaData("registered", isRegistered)
    end
end)
local function GetPlayerData(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        print("Erro: Jogador não encontrado! src=" .. tostring(src))
        return nil
    end
    return Player
end
function GetPlayerLevel(xp)
    for level, xpRequired in ipairs(Config.LevelXP) do
        if xp < xpRequired then
            return level - 1
        end
    end
    return #Config.LevelXP
end
-- ✅ mostrar XP
RegisterCommand("meuxp", function(source, args, rawCommand)
    local Player = GetPlayerData(source)
    if not Player then return end
    if Player.PlayerData.metadata["dragxp"] == nil then
        Player.PlayerData.metadata["dragxp"] = 0
        Player.Functions.SetMetaData("dragxp", 0)
    end
    local xp = Player.PlayerData.metadata["dragxp"]
    local level = GetPlayerLevel(xp)
    TriggerClientEvent('QBCore:Notify', source, ("🏁 XP: %d | Nível: %d"):format(xp, level), "primary")
end, false)
RegisterNetEvent('qb-drag-xp:addXP')
AddEventHandler('qb-drag-xp:addXP', function(amount)
    local src = source
    local Player = GetPlayerData(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    if type(amount) ~= "number" or amount <= 0 then
        print("Erro: Tentativa de adicionar XP inválido! src=" .. tostring(src) .. " amount=" .. tostring(amount))
        return
    end
    local maxXP = 1500 -- definido em Config.LevelXP
    local currentXP = Player.PlayerData.metadata["dragxp"] or 0
    local newXP = math.min(currentXP + amount, maxXP)
    Player.Functions.SetMetaData("dragxp", newXP)
    exports['oxmysql']:execute('INSERT INTO qb_drag_xp (citizenid, xp) VALUES (?, ?) ON DUPLICATE KEY UPDATE xp = ?', {citizenid, newXP, newXP})
    local oldLevel = GetPlayerLevel(currentXP)
    local newLevel = GetPlayerLevel(newXP)
    if not _G.lastXPNotification then _G.lastXPNotification = {} end
    local now = os.time()
    local last = _G.lastXPNotification[src] or 0
    if now - last > 10 then -- segundos entre notificações
        TriggerClientEvent('QBCore:Notify', src, ("+%d XP! Total: %d XP"):format(amount, newXP), "success")
        _G.lastXPNotification[src] = now
    end
    if newLevel > oldLevel then
        TriggerClientEvent('QBCore:Notify', src, ("🎉 Nível %d alcançado! Novas customizações disponíveis."):format(newLevel), "success")
    end
end)
RegisterNetEvent('qb-drag-xp:initXP')
AddEventHandler('qb-drag-xp:initXP', function()
    local src = source
    local Player = GetPlayerData(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    exports['oxmysql']:execute('SELECT xp FROM qb_drag_xp WHERE citizenid = ?', {citizenid}, function(result)
        local xp = 0
        if result and result[1] and result[1].xp then
            xp = tonumber(result[1].xp)
        end
        Player.Functions.SetMetaData("dragxp", xp)
    end)
end)
QBCore.Functions.CreateCallback('qb-drag-xp:getXPData', function(source, cb)
    local Player = GetPlayerData(source)
    if not Player then
        cb(nil)
        return
    end
    local citizenid = Player.PlayerData.citizenid
    exports['oxmysql']:execute('SELECT xp FROM qb_drag_xp WHERE citizenid = ?', {citizenid}, function(result)
        local xp = 0
        if result and result[1] and result[1].xp then
            xp = tonumber(result[1].xp)
        end
        local level = GetPlayerLevel(xp)
        cb({ xp = xp, level = level })
    end)
end)
