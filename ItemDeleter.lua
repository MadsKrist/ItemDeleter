-- ItemDeleter Addon for WoW 1.12
-- Automatically deletes specified items from inventory

-- Addon namespace
ItemDeleter = {}

-- Configuration: Add item names you want to delete
ItemDeleter.ItemsToDelete = {
    ["Broken Fang"] = true,
    ["Worn Leather Scraps"] = true,
    ["Cracked Leather Belt"] = true,
    ["Tattered Cloth Vest"] = true,
    -- Add more items here as needed
    -- Format: ["Exact Item Name"] = true,
}

-- Settings
ItemDeleter.Settings = {
    enabled = true,
    requireConfirmation = true,  -- Set to false for automatic deletion
    debugMode = false,
}

-- Initialize the addon
function ItemDeleter:Initialize()
    self:Print("ItemDeleter loaded! Type /itemdeleter for commands.")
    
    -- Create slash commands
    self:CreateSlashCommands()
end

-- Scan inventory and collect items to delete (without deleting)
function ItemDeleter:ScanInventoryForDeletion()
    local itemsToDelete = {}
    
    -- Scan all bags (0-4, where 0 is backpack)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    local itemName = self:GetItemNameFromLink(itemLink)
                    
                    if self.ItemsToDelete[itemName] then
                        local _, itemCount = GetContainerItemInfo(bag, slot)
                        table.insert(itemsToDelete, {
                            bag = bag,
                            slot = slot,
                            name = itemName,
                            count = itemCount or 1
                        })
                    end
                end
            end
        end
    end
    
    return itemsToDelete
end

-- Main function to scan inventory and delete items
function ItemDeleter:ScanAndDeleteItems()
    local itemsToDelete = self:ScanInventoryForDeletion()
    
    if table.getn(itemsToDelete) == 0 then
        self:Print("No items found to delete.")
        return
    end
    
    if self.Settings.requireConfirmation then
        self:ShowDeletionConfirmation(itemsToDelete)
    else
        self:DeleteItemsList(itemsToDelete)
    end
end

-- Delete a list of items
function ItemDeleter:DeleteItemsList(itemsToDelete)
    local deletedItems = {}
    
    for i = 1, table.getn(itemsToDelete) do
        local item = itemsToDelete[i]
        self:DeleteItem(item.bag, item.slot, item.name)
        
        local countText = ""
        if item.count > 1 then
            countText = " x" .. item.count
        end
        table.insert(deletedItems, item.name .. countText)
    end
    
    if table.getn(deletedItems) > 0 then
        self:Print("Deleted items: " .. table.concat(deletedItems, ", "))
    end
end

-- Extract item name from item link
function ItemDeleter:GetItemNameFromLink(itemLink)
    if not itemLink then return nil end
    local itemName = string.gsub(itemLink, ".*%[(.+)%].*", "%1")
    return itemName
end

-- Delete item from specific bag and slot
function ItemDeleter:DeleteItem(bag, slot, itemName)
    if self.Settings.debugMode then
        self:Print("DEBUG: Would delete " .. itemName .. " from bag " .. bag .. " slot " .. slot)
        return
    end
    
    -- Pick up the item and delete it
    PickupContainerItem(bag, slot)
    DeleteCursorItem()
    
    if self.Settings.debugMode then
        self:Print("Deleted: " .. itemName)
    end
end

-- Show comprehensive confirmation dialog for item deletion
function ItemDeleter:ShowDeletionConfirmation(itemsToDelete)
    -- Build the confirmation message
    local message = "Delete the following items?|n|n"
    local itemCounts = {}
    
    -- Group items by name and count them
    for i = 1, table.getn(itemsToDelete) do
        local item = itemsToDelete[i]
        if not itemCounts[item.name] then
            itemCounts[item.name] = 0
        end
        itemCounts[item.name] = itemCounts[item.name] + item.count
    end
    
    -- Build the display list
    for itemName, totalCount in pairs(itemCounts) do
        if totalCount > 1 then
            message = message .. "- " .. itemName .. " x" .. totalCount .. "|n"
        else
            message = message .. "- " .. itemName .. "|n"
        end
    end
    
    message = message .. "|nThis action cannot be undone!"
    
    -- Create confirmation dialog
    StaticPopupDialogs["ITEMDELETER_CONFIRM_ALL"] = {
        text = message,
        button1 = "Delete All",
        button2 = "Cancel",
        OnAccept = function()
            ItemDeleter:DeleteItemsList(itemsToDelete)
        end,
        OnCancel = function()
            ItemDeleter:Print("Deletion cancelled.")
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,  -- Higher priority popup
    }
    
    StaticPopup_Show("ITEMDELETER_CONFIRM_ALL")
end

-- Manually scan and delete items (called by slash command)
function ItemDeleter:ManualDelete()
    if not self.Settings.enabled then
        self:Print("ItemDeleter is disabled. Use /id toggle to enable.")
        return
    end
    
    self:Print("Scanning inventory for items to delete...")
    self:ScanAndDeleteItems()
end

-- Preview what items would be deleted
function ItemDeleter:PreviewDeletion()
    self:Print("Scanning inventory for items that would be deleted...")
    local itemsToDelete = self:ScanInventoryForDeletion()
    
    if table.getn(itemsToDelete) == 0 then
        self:Print("No items found that match deletion list.")
        return
    end
    
    self:Print("Items that would be deleted:")
    local itemCounts = {}
    
    -- Group items by name and count them
    for i = 1, table.getn(itemsToDelete) do
        local item = itemsToDelete[i]
        if not itemCounts[item.name] then
            itemCounts[item.name] = 0
        end
        itemCounts[item.name] = itemCounts[item.name] + item.count
    end
    
    -- Display the list
    for itemName, totalCount in pairs(itemCounts) do
        if totalCount > 1 then
            self:Print("- " .. itemName .. " x" .. totalCount)
        else
            self:Print("- " .. itemName)
        end
    end
end

-- Add item to deletion list
function ItemDeleter:AddItem(itemName)
    if itemName and itemName ~= "" then
        self.ItemsToDelete[itemName] = true
        self:Print("Added '" .. itemName .. "' to deletion list.")
    else
        self:Print("Usage: /itemdeleter add <item name>")
    end
end

-- Remove item from deletion list
function ItemDeleter:RemoveItem(itemName)
    if itemName and self.ItemsToDelete[itemName] then
        self.ItemsToDelete[itemName] = nil
        self:Print("Removed '" .. itemName .. "' from deletion list.")
    else
        self:Print("Item not found in deletion list.")
    end
end

-- List all items in deletion list
function ItemDeleter:ListItems()
    self:Print("Items configured for deletion:")
    local count = 0
    for itemName, _ in pairs(self.ItemsToDelete) do
        self:Print("- " .. itemName)
        count = count + 1
    end
    if count == 0 then
        self:Print("No items configured.")
    end
end

-- Print function
function ItemDeleter:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[ItemDeleter]|r " .. message)
end

-- Create slash commands
function ItemDeleter:CreateSlashCommands()
    SLASH_ITEMDELETER1 = "/itemdeleter"
    SLASH_ITEMDELETER2 = "/id"
    
    SlashCmdList["ITEMDELETER"] = function(msg)
        local command, arg = string.match(msg, "^(%S+)%s*(.*)$")
        command = string.lower(command or "")
        
        if command == "delete" then
            ItemDeleter:ManualDelete()
        elseif command == "preview" then
            ItemDeleter:PreviewDeletion()
        elseif command == "add" then
            ItemDeleter:AddItem(arg)
        elseif command == "remove" or command == "rem" then
            ItemDeleter:RemoveItem(arg)
        elseif command == "list" then
            ItemDeleter:ListItems()
        elseif command == "toggle" then
            ItemDeleter.Settings.enabled = not ItemDeleter.Settings.enabled
            ItemDeleter:Print("ItemDeleter " .. (ItemDeleter.Settings.enabled and "enabled" or "disabled"))
        elseif command == "confirm" then
            ItemDeleter.Settings.requireConfirmation = not ItemDeleter.Settings.requireConfirmation
            ItemDeleter:Print("Confirmation " .. (ItemDeleter.Settings.requireConfirmation and "enabled" or "disabled"))
        elseif command == "debug" then
            ItemDeleter.Settings.debugMode = not ItemDeleter.Settings.debugMode
            ItemDeleter:Print("Debug mode " .. (ItemDeleter.Settings.debugMode and "enabled" or "disabled"))
        else
            ItemDeleter:Print("Commands:")
            ItemDeleter:Print("/itemdeleter delete - Scan and delete configured items")
            ItemDeleter:Print("/itemdeleter preview - Show what items would be deleted")
            ItemDeleter:Print("/itemdeleter add <item> - Add item to deletion list")
            ItemDeleter:Print("/itemdeleter remove <item> - Remove item from deletion list")
            ItemDeleter:Print("/itemdeleter list - Show all items in deletion list")
            ItemDeleter:Print("/itemdeleter toggle - Enable/disable addon")
            ItemDeleter:Print("/itemdeleter confirm - Toggle confirmation dialogs")
            ItemDeleter:Print("/itemdeleter debug - Toggle debug mode")
        end
    end
end

-- Initialize when addon loads
ItemDeleter:Initialize()