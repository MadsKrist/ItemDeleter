-- ItemDeleter Addon for WoW 1.12
-- Automatically deletes specified items from inventory

-- Addon namespace
ItemDeleter = {}

-- Configuration: Add item names you want to delete
ItemDeleter.ItemsToDelete = {
    ["Refreshing Spring Water"] = true,
    -- Add more items here as needed
    -- Format: ["Exact Item Name"] = true,
}

-- Settings
ItemDeleter.Settings = {
    enabled = true,
    requireConfirmation = true,  -- Set to false for automatic deletion
    debugMode = false,
    autoScanOnBagUpdate = true,
}

-- Initialize the addon
function ItemDeleter:Initialize()
    self:Print("ItemDeleter loaded! Type /itemdeleter for commands.")
    
    -- Register events
    self:RegisterEvents()
    
    -- Create slash commands
    self:CreateSlashCommands()
end

-- Register necessary events
function ItemDeleter:RegisterEvents()
    local frame = CreateFrame("Frame")
    
    -- Bag update event
    if self.Settings.autoScanOnBagUpdate then
        frame:RegisterEvent("BAG_UPDATE")
    end
    
    frame:SetScript("OnEvent", function()
        if event == "BAG_UPDATE" and ItemDeleter.Settings.enabled then
            ItemDeleter:ScanAndDeleteItems()
        end
    end)
    
    self.eventFrame = frame
end

-- Main function to scan inventory and delete items
function ItemDeleter:ScanAndDeleteItems()
    local deletedItems = {}
    
    -- Scan all bags (0-4, where 0 is backpack)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    local itemName = self:GetItemNameFromLink(itemLink)
                    
                    if self.ItemsToDelete[itemName] then
                        if self.Settings.requireConfirmation then
                            self:ConfirmDeletion(bag, slot, itemName)
                        else
                            self:DeleteItem(bag, slot, itemName)
                            table.insert(deletedItems, itemName)
                        end
                    end
                end
            end
        end
    end
    
    -- Report deleted items
    if table.getn(deletedItems) > 0 and not self.Settings.requireConfirmation then
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

-- Show confirmation dialog for item deletion
function ItemDeleter:ConfirmDeletion(bag, slot, itemName)
    local dialog = "Delete " .. itemName .. "?"
    
    -- Create a simple confirmation using the default UI
    StaticPopupDialogs["ITEMDELETER_CONFIRM"] = {
        text = dialog,
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            ItemDeleter:DeleteItem(bag, slot, itemName)
            ItemDeleter:Print("Deleted: " .. itemName)
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1
    }
    
    StaticPopup_Show("ITEMDELETER_CONFIRM")
end

-- Manually scan inventory (called by slash command)
function ItemDeleter:ManualScan()
    self:Print("Scanning inventory for items to delete...")
    self:ScanAndDeleteItems()
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
        
        if command == "scan" then
            ItemDeleter:ManualScan()
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
            ItemDeleter:Print("/itemdeleter scan - Manually scan inventory")
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