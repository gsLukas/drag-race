local npcSpawns = {
    {
        prop = {
            model = "prop_table_03b_chr",
            coords = vector3(1538.1, 3213.94, 39.43),
            heading = 347.32,
            rotation = vector3(0.0, 0.0, -12.68)
        },
        npcs = {
            "a_m_y_business_01"
        }
    },
    {
        prop = {
            model = "prop_table_03b_chr",
            coords = vector3(1539.04, 3214.06, 39.43),
            heading = 14.52,
            rotation = vector3(0.0, 0.0, 14.52)
        },
        npcs = {
            "a_f_m_salton_01"
        }
    },
    {
        prop = {
            model = "prop_table_03b_chr",
            coords = vector3(1542.04, 3202.71, 39.43),
            heading = 329.24,
            rotation = vector3(0.0, 0.0, -30.76)
        },
        npcs = {
            "a_f_m_salton_01"
        }
    },
    {
        prop = {
            model = "prop_table_03b_chr",
            coords = vector3(1542.92, 3202.31, 39.41),
            heading = 305.73,
            rotation = vector3(0.0, 0.0, -54.27)
        },
        npcs = {
            "a_f_m_salton_01"
        }
    },
    {
        prop = {
            model = "prop_table_03b_chr",
            coords = vector3(1543.2, 3201.24, 39.41),
            heading = 268.2,
            rotation = vector3(0.0, 0.0, -91.8)
        },
        npcs = {
            "a_f_m_salton_01"
        }
    },
    {
        prop = {
            model = "prop_table_03b_chr",
            coords = vector3(1543.46, 3198.97, 39.43),
            heading = 257.75,
            rotation = vector3(0.0, 0.0, -102.25)
        },
        npcs = {
            "a_f_m_salton_01"
        }
    },
    -- Exemplo de NPC sem prop, apenas para referência
    {
        prop = {
            model = nil,
            coords = vector3(1566.91, 3202.0, 39.93),
            heading = 88.2,
            rotation = vector3(0.0, 0.0, 88.2)
        },
        npcs = {
            "a_f_m_salton_01"
        }
    },
}

-- Gerenciamento dinâmico de spawn/despawn conforme distância do jogador
local LOOP_WAIT = 5000 -- ajuste aqui para performance (ms)
CreateThread(function()
    local spawned = {}
    while true do
        Wait(LOOP_WAIT)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        for i, spawnInfo in ipairs(npcSpawns) do
            local dist = #(playerCoords - spawnInfo.prop.coords)
            if dist < 80.0 then
                if not spawned[i] or not DoesEntityExist(spawnInfo._npc) then
                    spawned[i] = true
                    if spawnInfo._npc and DoesEntityExist(spawnInfo._npc) then
                        DeleteEntity(spawnInfo._npc)
                    end
                    spawnInfo._npc = spawnRandomNPCWithProp(spawnInfo)
                end
            else
                if spawned[i] and spawnInfo._npc and DoesEntityExist(spawnInfo._npc) then
                    DeleteEntity(spawnInfo._npc)
                    spawned[i] = false
                    spawnInfo._npc = nil
                end
            end
        end
    end
end)

function spawnRandomNPCWithProp(spawnInfo)
    -- Verifica se já existe o prop no local
    local propHash = GetHashKey(spawnInfo.prop.model)
    local existingProp = nil
    local radius = 1.0 -- tolerância de distância
    for obj in EnumerateObjects() do
        if GetEntityModel(obj) == propHash then
            local objCoords = GetEntityCoords(obj)
            if #(objCoords - spawnInfo.prop.coords) < radius then
                existingProp = obj
                break
            end
        end
    end
    if not existingProp then
        RequestModel(propHash)
        while not HasModelLoaded(propHash) do Wait(10) end
        local propObj = CreateObject(propHash, spawnInfo.prop.coords.x, spawnInfo.prop.coords.y, spawnInfo.prop.coords.z, false, true, false)
        SetEntityHeading(propObj, spawnInfo.prop.heading)
        SetEntityRotation(propObj, spawnInfo.prop.rotation.x, spawnInfo.prop.rotation.y, spawnInfo.prop.rotation.z, 2, true)
    end

    -- Escolhe um NPC aleatório
    local npcModel = spawnInfo.npcs[math.random(1, #spawnInfo.npcs)]
    local npcHash = GetHashKey(npcModel)
    RequestModel(npcHash)
    while not HasModelLoaded(npcHash) do Wait(10) end
    -- Spawn do NPC exatamente na posição da cadeira (prop)
    local sitX = spawnInfo.prop.coords.x
    local sitY = spawnInfo.prop.coords.y
    local sitZ = spawnInfo.prop.coords.z -- sem offset no spawn
    local npcHeading = (spawnInfo.prop.heading + 180.0) % 360 -- gira 180 graus
    local npc = CreatePed(4, npcHash, sitX, sitY, sitZ, npcHeading, false, true)
    -- Randomização de roupas/acessórios
    SetPedRandomComponentVariation(npc, true)
    SetPedRandomProps(npc)
    -- Faz o NPC sentar na cadeira usando a posição exata + offset de altura
    local sitAnim = spawnInfo.sitAnim or "PROP_HUMAN_SEAT_CHAIR_UPRIGHT" -- permite trocar animação facilmente
    local animZ = sitZ + 0.5 -- offset de altura só na animação
    TaskStartScenarioAtPosition(npc, sitAnim, sitX, sitY, animZ, npcHeading, 0, true, true)
    SetEntityAsMissionEntity(npc, true, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    FreezeEntityPosition(npc, true)

    -- Exemplo: conversa entre múltiplos NPCs
    if spawnInfo.conversation and type(spawnInfo.conversation) == "table" then
        local npcs = {npc}
        for idx, conv in ipairs(spawnInfo.conversation) do
            local offset = conv.offset or {x = 1.0 * idx, y = 0.0, z = 0.0}
            local anim = conv.anim or "gesture_hello"
            local convNpc = CreatePed(4, npcHash, sitX + offset.x, sitY + offset.y, sitZ + offset.z, spawnInfo.prop.heading, false, true)
            TaskStartScenarioAtPosition(convNpc, "PROP_HUMAN_SEAT_CHAIR", sitX + offset.x, sitY + offset.y, sitZ + offset.z, spawnInfo.prop.heading, 0, true, true)
            TaskPlayAnim(convNpc, "gestures@m@standing@casual", anim, 8.0, -8.0, -1, 49, 0, false, false, false)
            table.insert(npcs, convNpc)
        end
        -- O NPC principal também pode animar
        TaskPlayAnim(npc, "gestures@m@standing@casual", "gesture_point", 8.0, -8.0, -1, 49, 0, false, false, false)
    end
    return npc
end

-- Removido spawn fixo ao iniciar o recurso, evitando duplicidade de NPCs

function EnumerateObjects()
    return EnumerateEntities(FindFirstObject, FindNextObject, EndFindObject)
end

function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(function()
        local iter, id = initFunc()
        if not id or id == 0 then
            disposeFunc(iter)
            return
        end
        local entity = id
        repeat
            coroutine.yield(entity)
            success, entity = moveFunc(iter)
        until not success
        disposeFunc(iter)
    end)
end

-- Para adicionar mais locais, basta inserir novos blocos em npcSpawns
-- Para adicionar mais tipos de prop, crie novos arrays com modelo, coords, heading, rotation e lista de NPCs