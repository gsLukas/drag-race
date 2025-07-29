-- Função utilitária para gerar posições baseadas na referência real de prop
local function normalizeHeading(h)
    h = h % 360
    if h < 0 then h = h + 360 end
    return h
end

function generateBleacherNPCPositions(baseCoords, baseHeading)
    local offsets = {
        { x = -1.67, y = -1.60, z = 1.70, h = 356.34 },
        { x = -0.72, y = -1.36, z = 1.70, h = 15.55 },
        { x =  0.00, y = -1.20, z = 1.70, h = 15.00 },

        { x = -1.83, y = -0.75, z = 1.49, h = 6.23 },
        { x = -1.07, y = -0.54, z = 1.49, h = 13.24 },
        { x = -0.38, y = -0.42, z = 1.49, h = 11.92 },

        { x = -2.11, y =  0.03, z = 1.28, h = 13.93 },
        { x = -1.35, y =  0.21, z = 1.28, h = 7.49 },
        { x = -0.55, y =  0.45, z = 1.28, h = 9.79 }
    }

    local positions = {}
    local angle = math.rad(baseHeading)

    for _, o in ipairs(offsets) do
        local rotatedX = o.x * math.cos(angle) - o.y * math.sin(angle)
        local rotatedY = o.x * math.sin(angle) + o.y * math.cos(angle)

        table.insert(positions, {
            coords = vector3(
                baseCoords.x + rotatedX,
                baseCoords.y + rotatedY,
                baseCoords.z + (o.z - 1.7)
            ),
            heading = normalizeHeading(baseHeading + (o.h - 13.93) + 180) -- gira 180 graus
        })
    end

    return positions
end

-- Lista de modelos variados (homens e mulheres)

local npcModels = {
    "a_m_y_stbla_01", "a_m_y_stwhi_02", "a_m_y_vinewood_01", "a_m_m_skater_01",
    "a_f_m_bevhills_01", "a_f_m_fatbla_01", "a_f_y_tourist_01", "a_f_y_hipster_01",
    "a_m_o_tramp_01", "a_m_y_hipster_01", "a_f_y_scdressy_01", "a_m_m_socenlat_01",
    "a_m_y_business_01", "a_f_m_soucent_01", "a_m_m_afriamer_01"
}

local spawnedNpcs = {}
local npcDistance = 40.0 -- distância máxima para spawn/despawn

local torcidaPositions = {
    vector4(1594.47, 3205.9, 41.2, 31.6),
    vector4(1593.7, 3205.7, 41.2, 13.05),
    vector4(1591.98, 3205.25, 41.2, 16.45),
    vector4(1591.15, 3205.08, 41.2, 12.36),
    vector4(1590.53, 3204.88, 41.2, 8.98),
    vector4(1590.4, 3205.77, 40.99, 8.75),
    vector4(1591.42, 3206.11, 40.99, 13.49),
    vector4(1592.85, 3206.36, 40.99, 12.93),
    vector4(1593.65, 3206.6, 40.99, 10.33),
    vector4(1594.29, 3206.73, 40.99, 16.98),
    vector4(1594.07, 3207.55, 40.75, 16.98),
    vector4(1593.34, 3207.54, 40.78, 14.92),
    vector4(1592.6, 3207.16, 40.78, 11.3),
    vector4(1590.75, 3206.69, 40.78, 12.49),
    vector4(1585.02, 3205.2, 40.78, 14.32),
    vector4(1585.8, 3205.4, 40.78, 10.67),
    vector4(1588.6, 3206.14, 40.78, 10.93),
    vector4(1587.55, 3205.86, 40.78, 13.35),
    vector4(1589.21, 3205.38, 41.06, 14.9),
    vector4(1588.45, 3205.21, 40.99, 31.14),
    vector4(1587.8, 3205.13, 40.99, 13.79),
    vector4(1586.55, 3204.91, 40.99, 49.98),
    vector4(1585.63, 3204.68, 40.99, 31.39),
    vector4(1586.31, 3203.94, 41.2, 16.4),
    vector4(1585.49, 3203.69, 41.2, 16.08),
    vector4(1588.58, 3204.41, 41.2, 10.89),
    vector4(1580.42, 3202.31, 41.2, 2.75),
    vector4(1581.12, 3202.43, 41.2, 12.58),
    vector4(1581.81, 3202.68, 41.2, 13.36),
    vector4(1583.38, 3203.09, 41.2, 13.31),
    vector4(1584.24, 3203.28, 41.2, 11.65),
    vector4(1583.39, 3203.93, 40.99, 16.01),
    vector4(1575.32, 3200.92, 41.2, 22.48),
    vector4(1574.19, 3200.67, 41.2, 39.25),
    vector4(1571.72, 3199.99, 41.2, 15.98),
    vector4(1572.57, 3200.28, 41.2, 2.09),
    vector4(1571.26, 3200.79, 40.99, 14.41),
    vector4(1572.45, 3201.05, 40.99, 12.48),
    vector4(1574.78, 3201.71, 40.99, 8.68),
    vector4(1573.84, 3201.46, 40.99, 13.53),
    vector4(1571.14, 3201.59, 40.78, 14.2),
    vector4(1571.95, 3201.83, 40.78, 12.4),
    vector4(1574.36, 3202.55, 40.78, 11.41),
    vector4(1573.55, 3202.44, 41.01, 9.29),
    vector4(1570.44, 3199.66, 41.18, 23.37),
    vector4(1569.28, 3199.46, 41.2, 27.39),
    vector4(1566.66, 3198.82, 41.22, 16.1),
    vector4(1567.87, 3199.07, 41.2, 14.66),
    vector4(1567.68, 3199.84, 40.99, 14.66),
    vector4(1567.46, 3200.68, 40.77, 14.57),
    vector4(1561.8, 3198.29, 40.99, 15.22),
    vector4(1562.85, 3198.7, 40.99, 16.1),
    vector4(1564.57, 3198.12, 41.2, 15.36),
    vector4(1564.31, 3199.03, 40.98, 15.36),
    vector4(1565.43, 3199.23, 40.99, 11.8),
    vector4(1565.04, 3200.05, 40.78, 4.09),
    vector4(1565.85, 3200.29, 40.78, 11.8),
    vector4(1566.66, 3200.53, 40.78, 9.29),
    vector4(1567.46, 3200.77, 40.78, 7.49),
    vector4(1568.27, 3201.01, 40.78, 5.69),
    vector4(1580.75, 3203.21, 40.99, 9.88),
    vector4(1581.56, 3203.45, 40.99, 7.08),
    vector4(1582.37, 3203.69, 40.99, 5.28),
    vector4(1583.18, 3203.93, 40.99, 3.48),
    vector4(1583.99, 3204.17, 40.99 , 1.68),

    






    -- ARQ 2

    vector4(1559.21, 3227.51, 41.2, 199.68),
    vector4(1559.55, 3226.69, 41.0, 207.3),
    vector4(1559.83, 3225.96, 40.85, 198.85),
    vector4(1559.01, 3225.69, 40.79, 191.32),
    vector4(1558.47, 3227.15, 41.25, 193.93),
    vector4(1558.61, 3226.53, 41.08, 191.64),
    vector4(1559.62, 3226.69, 41.07, 193.92),
    vector4(1560.06, 3225.97, 40.9, 195.68),
    vector4(1561.56, 3226.32, 40.81, 211.49),
    vector4(1562.51, 3226.71, 40.94, 193.63),
    vector4(1564.44, 3228.93, 41.22, 197.9),
    vector4(1563.14, 3228.58, 41.22, 199.38),
    vector4(1563.42, 3227.77, 40.97, 197.87),
    vector4(1563.67, 3226.92, 40.79, 198.91),
    vector4(1564.68, 3227.19, 40.79, 194.12),
    vector4(1564.36, 3228.09, 41.11, 189.04),
    vector4(1566.02, 3228.48, 41.0, 194.03),
    vector4(1567.21, 3228.77, 41.0, 193.46),
    vector4(1567.32, 3227.94, 40.77, 195.84),
    vector4(1566.25, 3227.66, 40.79, 191.21),
    vector4(1573.28, 3231.32, 41.35, 193.55),
    vector4(1572.15, 3230.92, 41.22, 193.26),
    vector4(1575.92, 3231.86, 41.22, 191.63),
    vector4(1574.58, 3231.47, 41.22, 196.35),
    vector4(1575.54, 3231.74, 41.22, 206.53),
    vector4(1576.21, 3231.05, 40.99, 190.58),
    vector4(1576.42, 3230.1, 40.8, 190.77),
    vector4(1575.71, 3230.07, 40.79, 193.69),
    vector4(1575.03, 3229.91, 40.79, 194.53),
    vector4(1574.96, 3230.7, 41.0, 193.88),
    vector4(1573.71, 3229.49, 40.79, 184.9),
    vector4(1573.34, 3230.37, 40.98, 197.84),
    vector4(1572.86, 3230.24, 41.0, 195.43),
    vector4(1573.08, 3229.42, 40.77, 195.42),

    
    vector4(1585.56, 3234.14, 41.21, 188.86),
    vector4(1584.16, 3233.76, 41.21, 186.09),
    vector4(1584.27, 3232.99, 41.04, 193.81),
    vector4(1584.51, 3232.14, 40.78, 195.41),
    vector4(1586.04, 3232.51, 40.79, 191.01),
    vector4(1585.28, 3232.34, 40.79, 194.37),
    vector4(1585.68, 3233.3, 41.0, 190.12),
    vector4(1584.87, 3233.11, 41.0, 191.61),
    vector4(1583.66, 3232.82, 41.0, 193.1), 
    vector4(1583.05, 3232.55, 41.0, 194.59),
    vector4(1582.44, 3232.28, 41.0, 196.08),
    

}

function LoadModel(model)
    local hash = GetHashKey(model)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            Wait(10)
        end
    end
end

function SpawnTorcidaNPC(index, data)
    if spawnedNpcs[index] and DoesEntityExist(spawnedNpcs[index]) then return end
    local npcModel = npcModels[((index - 1) % #npcModels) + 1]
    LoadModel(npcModel)
    local zAdjusted = data.z - 1.0 -- ajuste para descer o NPC
    local npc = CreatePed(4, GetHashKey(npcModel), data.x, data.y, zAdjusted, data.w, false, true)
    SetEntityInvincible(npc, true)
    FreezeEntityPosition(npc, true)
    TaskStartScenarioInPlace(npc, "WORLD_HUMAN_CHEERING", 0, true)
    spawnedNpcs[index] = npc
end

function DeleteTorcidaNPC(index)
    if spawnedNpcs[index] and DoesEntityExist(spawnedNpcs[index]) then
        DeleteEntity(spawnedNpcs[index])
        spawnedNpcs[index] = nil
    end
end

-- Thread otimizada: só spawna/despawna conforme distância do jogador
Citizen.CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        for i, pos in ipairs(torcidaPositions) do
            local npcCoords = vector3(pos.x, pos.y, pos.z)
            local dist = #(playerCoords - npcCoords)
            if dist < npcDistance then
                SpawnTorcidaNPC(i, pos)
            else
                DeleteTorcidaNPC(i)
            end
        end
        Wait(2000) -- ajustável para performance
    end
end)