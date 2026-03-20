local fishing = false
local fishingRodProp = nil
local deepSeaFishingZone = vector3(-2084.6890, -1188.6348, 0.5700)
local deepSeaFishingRadius = 200.0
local npcEntity = nil
local envelopeProp = nil
local treasureBlip = nil
local treasureLocation = nil
local digging = false


Citizen.CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200) then
            SetNuiFocus(false, false)
            SendNUIMessage({ action = "hide" })
        end
    end
end)


-- Coordinates and model for the Fishing Vendor NPC
local fishingVendorLocation = vector4(-1687.2799, -1042.1547, 13.0128, 234.3537)
local fishingVendorModel = "a_m_m_farmer_01"


local function hasItemsToSell()
    for _, itemConfig in pairs(Config.SellPrices) do
        local itemName = itemConfig.item
        local itemCount = exports.ox_inventory:Search("count", itemName)
        if itemCount and itemCount > 0 then
            return true
        end
    end
    return false
end


local function spawnFishingVendor()
    local npcModel = GetHashKey(fishingVendorModel)

    RequestModel(npcModel)
    while not HasModelLoaded(npcModel) do
        Wait(10)
    end

    npcEntity = CreatePed(4, npcModel, fishingVendorLocation.x, fishingVendorLocation.y, fishingVendorLocation.z - 1.0, fishingVendorLocation.w, false, true)
    SetEntityInvincible(npcEntity, true)
    SetBlockingOfNonTemporaryEvents(npcEntity, true)
    FreezeEntityPosition(npcEntity, true)

    exports['qb-target']:AddTargetEntity(npcEntity, {
        options = {
            {
                icon = "fas fa-fish",
                label = "Sell Fish",
                action = function()
                    if hasItemsToSell() then
                        startHandshakeProcess()
                    else
                        TriggerEvent("ox_lib:notify", { type = "error", description = "You have no fish to sell!" })
                    end
                end
            }
        },
        distance = 1.5
    })

    local blip = AddBlipForCoord(fishingVendorLocation.x, fishingVendorLocation.y, fishingVendorLocation.z)
    SetBlipSprite(blip, 792)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 47)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Fish Buyer")
    EndTextCommandSetBlipName(blip)
end

Citizen.CreateThread(function()
    spawnFishingVendor()
end)

local function positionPlayerForAnimation()
    local playerPed = PlayerPedId()
    local npcCoords = vector3(fishingVendorLocation.x, fishingVendorLocation.y, fishingVendorLocation.z)
    local npcHeading = fishingVendorLocation.w

    local targetCoords = GetOffsetFromEntityInWorldCoords(npcEntity, 0.0, 0.8, 0.0)
    local targetHeading = npcHeading + 180.0
    if targetHeading > 360.0 then
        targetHeading = targetHeading - 360.0
    end

    TaskGoStraightToCoord(playerPed, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, 4000, targetHeading, 0.1)

    while #(GetEntityCoords(playerPed) - targetCoords) > 0.1 do
        Wait(100)
    end

    SetEntityHeading(playerPed, targetHeading)
end

local function attachEnvelopeToNPC()
    local propModel = GetHashKey("prop_cs_cashenvelope")

    RequestModel(propModel)
    while not HasModelLoaded(propModel) do
        Wait(10)
    end

    envelopeProp = CreateObject(propModel, 0, 0, 0, true, true, false)
    AttachEntityToEntity(
        envelopeProp,
        npcEntity,
        GetPedBoneIndex(npcEntity, 57005),
        0.1, 0.0, 0.0,
        0.0, 90.0, 0.0,
        true, true, false, true, 1, true
    )
end

local function transferEnvelopeToPlayer()
    if envelopeProp then
        DetachEntity(envelopeProp, true, false)
        local playerPed = PlayerPedId()
        AttachEntityToEntity(
            envelopeProp,
            playerPed,
            GetPedBoneIndex(playerPed, 57005),
            0.1, 0.0, 0.0,
            0.0, 90.0, 0.0,
            true, true, false, true, 1, true
        )
    end
end

local function detachAndDeleteEnvelope()
    if DoesEntityExist(envelopeProp) then
        DetachEntity(envelopeProp, true, false)
        DeleteObject(envelopeProp)
        envelopeProp = nil
    end
end

function startHandshakeProcess()
    local playerPed = PlayerPedId()
    positionPlayerForAnimation()

    RequestAnimDict("mp_ped_interaction")
    RequestAnimDict("mp_common")
    while not HasAnimDictLoaded("mp_ped_interaction") or not HasAnimDictLoaded("mp_common") do
        Wait(10)
    end

    TaskPlayAnim(playerPed, "mp_ped_interaction", "hugs_guy_a", 8.0, -8.0, 3400, 0, 0, false, false, false)
    TaskPlayAnim(npcEntity, "mp_ped_interaction", "hugs_guy_a", 8.0, -8.0, 3400, 0, 0, false, false, false)

    Citizen.Wait(3500)

    attachEnvelopeToNPC()
    TaskPlayAnim(npcEntity, "mp_common", "givetake1_a", 8.0, -8.0, 3000, 0, 0, false, false, false)
    TaskPlayAnim(playerPed, "mp_common", "givetake2_a", 8.0, -8.0, 3000, 0, 0, false, false, false)

    Citizen.Wait(1500)
    transferEnvelopeToPlayer()
    Citizen.Wait(1500)

    detachAndDeleteEnvelope()

    ClearPedTasks(playerPed)
    ClearPedTasks(npcEntity)

    TriggerServerEvent("fishing:sellAllFish")
end

local function isNearAndFacingWater(ped)
    local pedCoords = GetEntityCoords(ped)
    local forwardVector = GetEntityForwardVector(ped)
    local radius = 15.0
    local checkDistance = 5.0

    local isNearWater, waterHeight = GetWaterHeight(pedCoords.x, pedCoords.y, pedCoords.z)
    local nearbyWater = isNearWater or #(pedCoords - vector3(pedCoords.x, pedCoords.y, waterHeight or 0.0)) <= radius
    local checkPoint = pedCoords + (forwardVector * checkDistance)
    local isFacingWater, _ = GetWaterHeight(checkPoint.x, checkPoint.y, checkPoint.z)

    return nearbyWater and isFacingWater
end

local function isInDeepSeaFishingZone(pedCoords)
    return #(pedCoords - deepSeaFishingZone) <= deepSeaFishingRadius
end

RegisterNetEvent('fishing:start', function()
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    if fishing or not IsPedOnFoot(ped) then
        TriggerEvent('ox_lib:notify', { type = 'error', description = 'You need to be on foot to fish!' })
        return
    end

    local inDeepSeaZone = isInDeepSeaFishingZone(pedCoords)
    local requiredBait = inDeepSeaZone and 'deepseabait' or 'fishbait'
    local baitCount = exports.ox_inventory:Search('count', requiredBait)

    if baitCount < 1 then
        TriggerEvent('ox_lib:notify', { type = 'error', description = 'You need ' .. requiredBait .. ' to fish!' })
        return
    end

    if not isNearAndFacingWater(ped) then
        TriggerEvent('ox_lib:notify', { type = 'error', description = 'You need to be near and facing water to fish!' })
        return
    end

    TriggerServerEvent('fishing:consumeBait', requiredBait)

    local rodModel = GetHashKey('prop_fishing_rod_01')
    RequestModel(rodModel)
    while not HasModelLoaded(rodModel) do
        Wait(10)
    end

    fishingRodProp = CreateObject(rodModel, 0, 0, 0, true, true, false)
    AttachEntityToEntity(
        fishingRodProp,
        ped,
        GetPedBoneIndex(ped, 60309),
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )

    RequestAnimDict('amb@world_human_stand_fishing@base')
    while not HasAnimDictLoaded('amb@world_human_stand_fishing@base') do
        Wait(10)
    end

    TaskPlayAnim(ped, 'amb@world_human_stand_fishing@base', 'base', 8.0, -8.0, -1, 49, 0, false, false, false)

    fishing = true
    TriggerEvent('ox_lib:notify', { type = 'success', description = 'You cast your fishing rod!' })

    Citizen.CreateThread(function()
        while fishing do
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 73, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 257, true)
            Wait(0)
        end
    end)

    local waitTime = math.random(5000, 10000)
    Citizen.Wait(waitTime)

    local success = exports['ox_lib']:skillCheck({'easy', 'easy', 'medium'}, {'e', 'e', 'e'})
    ClearPedTasks(ped)
    if fishingRodProp then
        DeleteObject(fishingRodProp)
        fishingRodProp = nil
    end

    if success then
        local inDeepSeaZone = isInDeepSeaFishingZone(GetEntityCoords(PlayerPedId()))
        TriggerServerEvent('fishing:catch', inDeepSeaZone)
    else
        TriggerEvent('ox_lib:notify', { type = 'error', description = 'You failed to catch anything!' })
    end

    fishing = false
end)

Citizen.CreateThread(function()
    local blip = AddBlipForCoord(deepSeaFishingZone.x, deepSeaFishingZone.y, deepSeaFishingZone.z)
    SetBlipSprite(blip, 68)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 9)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Deep Sea Fishing")
    EndTextCommandSetBlipName(blip)

    local fishingZone = AddBlipForRadius(deepSeaFishingZone.x, deepSeaFishingZone.y, deepSeaFishingZone.z, deepSeaFishingRadius)
    SetBlipAlpha(fishingZone, 100)
    SetBlipColour(fishingZone, 9)
end)

local shopPed = nil
local shopCoords = vec3(25.7, -1347.3, 29.49) -- change this
local shopHeading = 270.0

local createdBlips = {}

CreateThread(function()
    for i = 1, #Config.Locations do
        local loc = Config.Locations[i]

        -- BLIP
        if loc.blip.enabled then
            local blip = AddBlipForCoord(loc.coords)

            SetBlipSprite(blip, loc.blip.sprite)
            SetBlipColour(blip, loc.blip.color)
            SetBlipScale(blip, loc.blip.scale)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(loc.blip.label)
            EndTextCommandSetBlipName(blip)

            createdBlips[#createdBlips + 1] = blip
        end
    end
end)

































