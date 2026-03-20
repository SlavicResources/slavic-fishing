exports('fishingrod', function(data, slot)
    local src = source

    exports.ox_inventory:useItem(data, function(success)
        if success then
            TriggerClientEvent('fishing:start', src)
        end
    end)
end)

RegisterServerEvent('fishing:useMessageBottle')
AddEventHandler('fishing:useMessageBottle', function()
    local src = source
    local success = exports.ox_inventory:RemoveItem(src, 'message_in_a_bottle', 1)
    if success then
        TriggerClientEvent('fishing:showTreasureMap', src)
        print(('Debug: Player ID %d used a message_in_a_bottle.'):format(src))
    else
        print(('Debug: Failed to remove message_in_a_bottle from player ID %d.'):format(src))
    end
end)

RegisterServerEvent("fishing:rewardTreasure")
AddEventHandler("fishing:rewardTreasure", function()
    local src = source
    local rewardGiven = false

    for _, reward in ipairs(Config.TreasureRewards) do

        local success = exports.ox_inventory:AddItem(src, reward.item, reward.amount)
        if success then
            TriggerClientEvent("ox_lib:notify", src, { type = "success", description = ("You found Treasure!"):format(reward.item) })
            print(('Debug: Successfully gave %d x %s to player ID %d'):format(reward.amount, reward.item, src))
            rewardGiven = true
        else
            print(('Debug: Failed to give %d x %s to player ID %d'):format(reward.amount, reward.item, src))
        end
    end

    if not rewardGiven then
        TriggerClientEvent("ox_lib:notify", src, { type = "error", description = "Failed to give you the treasure reward!" })
    end
end)


RegisterServerEvent('fishing:catch')
AddEventHandler('fishing:catch', function(isDeepSea)
    local src = source

    print('Debug: fishing:catch triggered by player ID: ' .. src)


    local rewardItems = isDeepSea and Config.DeepSeaFishingItems or Config.NormalFishingItems

    if not rewardItems or #rewardItems == 0 then
        print('Debug: Reward items are not defined or empty.')
        return
    end

    local selectedItem = nil


    for _, reward in pairs(rewardItems) do
        if math.random(1, 100) <= reward.chance then
            selectedItem = reward
            break
        end
    end

    if not selectedItem then
        print('Debug: No items to give to player:', src)
        TriggerClientEvent("ox_lib:notify", src, { type = "error", description = "You didn't catch anything!" })
        return
    end


    local success = exports.ox_inventory:AddItem(src, selectedItem.item, 1)
    if success then
        TriggerClientEvent("ox_lib:notify", src, { type = "success", description = ("You caught a %s!"):format(selectedItem.item) })
        print(('Debug: Successfully gave 1 x %s to player ID %d'):format(selectedItem.item, src))
    else
        TriggerClientEvent("ox_lib:notify", src, { type = "error", description = "Failed to add the item to your inventory!" })
        print(('Debug: Failed to give 1 x %s to player ID %d'):format(selectedItem.item, src))
    end
end)


RegisterServerEvent('fishing:consumeBait')
AddEventHandler('fishing:consumeBait', function(bait)
    local src = source
    local removed = exports.ox_inventory:RemoveItem(src, bait, 1)
    if removed then
        print(('Debug: Removed 1 %s from player ID: %d'):format(bait, src))
    else
        print(('Debug: Failed to remove %s from player ID: %d'):format(bait, src))
    end
end)


RegisterServerEvent("fishing:sellAllFish")
AddEventHandler("fishing:sellAllFish", function()
    local src = source
    local totalMoney = 0


    for _, itemConfig in ipairs(Config.SellPrices) do
        local itemName = itemConfig.item
        local itemPrice = itemConfig.price
        local itemCount = exports.ox_inventory:Search(src, 'count', itemName)

        if itemCount > 0 then
            local sellAmount = itemPrice * itemCount
            totalMoney = totalMoney + sellAmount


            local removed = exports.ox_inventory:RemoveItem(src, itemName, itemCount)
            if removed then
                print(('Debug: Sold %d x %s for $%d'):format(itemCount, itemName, sellAmount))
            else
                print(('Debug: Failed to remove %d x %s from player ID: %d'):format(itemCount, itemName, src))
            end
        else
            print(('Debug: Player ID %d has no %s to sell'):format(src, itemName))
        end
    end


    if totalMoney > 0 then
        local success = exports.ox_inventory:AddItem(src, 'money', totalMoney)
        if success then
            TriggerClientEvent("ox_lib:notify", src, { type = "success", description = ("You sold all your fish for $%d!"):format(totalMoney) })
            print(('Debug: Added $%d to player ID %d as money item'):format(totalMoney, src))
        else
            TriggerClientEvent("ox_lib:notify", src, { type = "error", description = "Failed to add money to your inventory!" })
            print(('Debug: Failed to add money item to player ID %d'):format(src))
        end
    else
        TriggerClientEvent("ox_lib:notify", src, { type = "error", description = "You have no fish to sell!" })
        print(('Debug: Player ID %d has no fish to sell'):format(src))
    end
end)


















