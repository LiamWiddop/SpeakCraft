-- SpeakCraft: UI Components
local addonName, addon = ...
local ui = addon.ui

-- Track currently speaking entry
addon.currentlySpeakingEntryID = nil

-- Display model from a log entry without speaking
function ui.DisplayModelFromEntry(entry)
    if not addon.TTSLogFrame or not addon.TTSLogFrame.modelDisplay then
        addon.utils.Debug("Model display not available")
        return
    end
    
    local modelDisplay = addon.TTSLogFrame.modelDisplay
    
    -- Reset model first
    modelDisplay:ClearModel()
    addon.utils.Debug("Model cleared")
    
    if not entry or not entry.model then
        addon.utils.Debug("No model info in entry")
        return
    end
    
    addon.utils.Debug("Attempting to display model for entry: " .. entry.id)
    addon.utils.Debug("Model information:")
    addon.utils.Debug("  - Name: " .. (entry.model.name or "Unknown"))
    addon.utils.Debug("  - Display ID: " .. tostring(entry.model.displayID))
    addon.utils.Debug("  - NPC ID: " .. tostring(entry.model.npcID))
    
    -- Helper to setup the model after it's loaded
    local function SetupModel(model, name)
        -- Set camera and position
        model:SetCamera(0)
        model:SetPosition(0, 0, 0)
        model:SetFacing(math.pi * -0.075)
        
        -- Update name plate
        local parent = model:GetParent()
        if parent then
            if not parent.nameText then
                local nameText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            end
        end
        
        -- Reset debug state
        addon.DEBUG_MODE = oldDebugState
    end
    
    -- Function declarations for our model loading sequence
    local TryNextMethod, TryDisplayID, TryCreatureID, TryFallbacks
    
    -- Simple sequential approach to try different methods
    
    -- 1. Current target if it matches our entry
    if entry.model.guid and UnitExists("target") and UnitGUID("target") == entry.model.guid then
        addon.utils.Debug("Current target matches entry - using SetUnit")
        modelDisplay:SetUnit("target")
        
        -- Setup after a small delay
        C_Timer.After(0.1, function()
            if modelDisplay:GetModelFileID() then
                addon.utils.Debug("Model set successfully from target")
                SetupModel(modelDisplay, entry.model.name)
            else
                if TryNextMethod then
                    TryNextMethod()
                end
            end
        end)
        return
    end
    
    -- Try other methods
    TryNextMethod = function()
        -- 2. Try using cached display ID
        if entry.model.npcID and addon.modelCache and addon.modelCache[entry.model.npcID] then
            local cachedDisplayID = addon.modelCache[entry.model.npcID]
            addon.utils.Debug("Using cached display ID: " .. tostring(cachedDisplayID))
            
            -- Try to set the display info directly
            modelDisplay:SetDisplayInfo(cachedDisplayID)
            
            -- Check if successful
            C_Timer.After(0.1, function()
                if modelDisplay:GetModelFileID() then
                    addon.utils.Debug("Model set successfully from cache")
                    SetupModel(modelDisplay, entry.model.name)
                else
                    addon.utils.Debug("Failed to set model using cached display ID")
                    TryDisplayID()
                end
            end)
            return
        end
        
        -- Otherwise move to next method
        TryDisplayID()
    end
    
    -- Try to use the stored display ID
    TryDisplayID = function()
        if entry.model.displayID and type(entry.model.displayID) == "number" then
            addon.utils.Debug("Trying stored display ID: " .. entry.model.displayID)
            
            modelDisplay:SetDisplayInfo(entry.model.displayID)
            
            C_Timer.After(0.1, function()
                if modelDisplay:GetModelFileID() then
                    addon.utils.Debug("Model set successfully using stored display ID")
                    
                    -- Save to cache if not already there
                    if entry.model.npcID and (not addon.modelCache or not addon.modelCache[entry.model.npcID]) then
                        addon.modelCache = addon.modelCache or {}
                        addon.modelCache[entry.model.npcID] = entry.model.displayID
                        addon.utils.Debug("Added display ID to cache for future use")
                    end
                    
                    SetupModel(modelDisplay, entry.model.name)
                else
                    addon.utils.Debug("Failed to set model using display ID")
                    TryCreatureID()
                end
            end)
            return
        end
        
        -- No valid display ID, try creature ID
        TryCreatureID()
    end
    
    -- Try using the stored npcID as a creature ID
    TryCreatureID = function()
        if entry.model.npcID then
            addon.utils.Debug("Trying creature ID: " .. entry.model.npcID)
            
            modelDisplay:SetCreature(entry.model.npcID)
            
            C_Timer.After(0.1, function()
                if modelDisplay:GetModelFileID() then
                    addon.utils.Debug("Model set successfully using creature ID")
                    SetupModel(modelDisplay, entry.model.name)
                else
                    addon.utils.Debug("Failed to set model using creature ID")
                    TryFallbacks()
                end
            end)
            return
        end
        
        -- No NPC ID, try fallbacks
        TryFallbacks()
    end
    
    -- Try fallback models
    TryFallbacks = function()
        addon.utils.Debug("Trying fallback models")
        
        -- Common creature IDs that usually work
        local fallbackIDs = {
            117,    -- Human
            2043,   -- Dwarf
            1418,   -- Gnome
            15990,  -- Blood Elf
            10921,  -- Dragon
            19938   -- Demon
        }
        
        local function TryFallback(index)
            if index > #fallbackIDs then
                addon.utils.Debug("All fallbacks failed")
                addon.DEBUG_MODE = oldDebugState
                return
            end
            
            local id = fallbackIDs[index]
            addon.utils.Debug("Trying fallback ID: " .. id)
            
            modelDisplay:SetCreature(id)
            
            C_Timer.After(0.1, function()
                if modelDisplay:GetModelFileID() then
                    addon.utils.Debug("Fallback model set successfully")
                    SetupModel(modelDisplay, entry.model.name .. " (Fallback)")
                else
                    TryFallback(index + 1)
                end
            end)
        end
        
        TryFallback(1)
    end
    
    -- If we get here, we need to try other methods
    TryNextMethod()
end

-- Create the TTS Log Frame
function ui.CreateTTSLogFrame()
    -- Main frame
    local logFrame = CreateFrame("Frame", "SpeakCraftLogFrame", UIParent, "BackdropTemplate")
    logFrame:SetSize(300, 200)
    logFrame:SetPoint("BOTTOMRIGHT", -20, 20)
    
    -- Set backdrop (without border)
    if logFrame.SetBackdrop then
        logFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            tile = true,
            tileSize = 32,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
    else
        -- Fallback for newer versions
        local bg = logFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.7)
    end
    
    -- Make frame movable
    logFrame:SetMovable(true)
    logFrame:EnableMouse(true)
    logFrame:RegisterForDrag("LeftButton")
    logFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    logFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Set up manual resize functionality (without using SetResizable)
    local minWidth, minHeight = 300, 200
    local maxWidth, maxHeight = 800, 600
    local isResizing = false
    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, logFrame)
    titleBar:SetSize(logFrame:GetWidth(), 30)
    titleBar:SetPoint("TOP", 0, 0)
    
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("CENTER", titleBar, "CENTER")
    titleText:SetText("SpeakCraft TTS Log")
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", logFrame, "TOPRIGHT", 0, 0)
    closeButton:SetScript("OnClick", function() logFrame:Hide() end)
    
    -- Create model viewer frame on the right side - SMALLER SIZE (~100px)
    local modelFrame = CreateFrame("Frame", "SpeakCraftModelFrame", logFrame)
    modelFrame:SetSize(50, 50) -- Changed from 150x200 to 100x100
    modelFrame:SetPoint("TOPLEFT", logFrame, "TOPLEFT", 10, -30)
    -- No longer set bottom point - just use fixed size
    
    -- Background for model frame
    if modelFrame.SetBackdrop then
        modelFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
    else
        -- Fallback for newer versions
        local bg = modelFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.7)
    end
    
    -- Create the model display
    local modelDisplay = CreateFrame("PlayerModel", "SpeakCraftModelDisplay", modelFrame)
    modelDisplay:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 0, 0)
    modelDisplay:SetPoint("BOTTOMRIGHT", modelFrame, "BOTTOMRIGHT", 0, 0)
    logFrame.modelDisplay = modelDisplay
    
    -- Scroll frame for log entries - now fills the entire height of the frame with model frame on top right
    local scrollFrame = CreateFrame("ScrollFrame", "SpeakCraftLogScrollFrame", logFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 60, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40) -- Position to fill the entire frame height, leaving space for volume slider
    
    local scrollChild = CreateFrame("Frame")
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1) -- Will be resized as entries are added
    
    logFrame.scrollChild = scrollChild
    
    -- Update scroll frame size when frame is resized
    logFrame:HookScript("OnSizeChanged", function(self, width, height)
        -- Keep model frame in top right, but let scrollframe fill remaining space
        scrollFrame:SetPoint("BOTTOMRIGHT", -120, 50) -- Maintain full height scrollable area
        scrollChild:SetWidth(scrollFrame:GetWidth())
        addon.ui.RefreshLogDisplay()
    end)
    
    -- Add volume slider
    local volumeSlider = CreateFrame("Slider", "SpeakCraftVolumeSlider", logFrame, "OptionsSliderTemplate")
    volumeSlider:SetWidth(logFrame:GetWidth() - 20)
    volumeSlider:SetHeight(16)
    volumeSlider:SetPoint("BOTTOM", logFrame, "BOTTOM", 0, 15)
    volumeSlider:SetOrientation("HORIZONTAL")
    volumeSlider:SetMinMaxValues(0, 100)
    volumeSlider:SetValue(addon.TTS_VOLUME)
    volumeSlider:SetValueStep(1)
    volumeSlider:SetObeyStepOnDrag(true)
    
    -- Set slider text
    _G[volumeSlider:GetName() .. "Low"]:SetText("0%")
    _G[volumeSlider:GetName() .. "High"]:SetText("100%")
    _G[volumeSlider:GetName() .. "Text"]:SetText("Volume: " .. addon.TTS_VOLUME .. "%")
    
    -- Update volume when slider changes
    volumeSlider:SetScript("OnValueChanged", function(self, value)
        addon.TTS_VOLUME = value
        _G[self:GetName() .. "Text"]:SetText("Volume: " .. floor(value) .. "%")
    end)
    
    -- Update slider width when frame is resized
    logFrame:HookScript("OnSizeChanged", function(self, width, height)
        volumeSlider:SetWidth(width - 20)
    end)
    
    -- Add a button to toggle the frame
    local toggleButton = CreateFrame("Button", "SpeakCraftToggleButton", UIParent, "UIPanelButtonTemplate")
    toggleButton:SetSize(120, 25)
    toggleButton:SetPoint("BOTTOMRIGHT", -20, 340)
    toggleButton:SetText("Toggle TTS Log")
    toggleButton:SetScript("OnClick", function()
        if logFrame:IsShown() then
            logFrame:Hide()
        else
            logFrame:Show()
        end
    end)
    
    -- Make toggle button movable
    toggleButton:SetMovable(true)
    toggleButton:EnableMouse(true)
    toggleButton:RegisterForDrag("LeftButton")
    toggleButton:SetScript("OnDragStart", function(self) self:StartMoving() end)
    toggleButton:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    toggleButton:SetClampedToScreen(true)
    
    -- Save position between sessions
    toggleButton:HookScript("OnDragStop", function(self)
        -- You could add code here to save the position
        -- This would require a saved variables table
    end)
    
    logFrame:Show()
    return logFrame
end

-- Add a log entry to the TTS Log Frame
function ui.AddLogEntry(gender, type, text, voice)
    if not addon.TTSLogFrame then
        addon.TTSLogFrame = ui.CreateTTSLogFrame()
    end
    
    -- Get NPC model information
    local modelInfo = {}
    if UnitExists("target") then
        local npcID = nil
        local guid = UnitGUID("target")
        
        -- Extract NPC ID from GUID
        if guid then
            local type, _, _, _, _, id = strsplit("-", guid)
            if type == "Creature" and id then
                npcID = tonumber(id)
            end
        end
        
        modelInfo = {
            displayID = addon.utils.GetNPCDisplayID(),
            name = UnitName("target") or "Unknown NPC",
            guid = guid,
            npcID = npcID
        }
    else
        modelInfo = {
            displayID = nil,
            name = "Unknown NPC",
            guid = nil,
            npcID = nil
        }
    end
    
    -- Create a unique ID for this entry
    local entryID = tostring(GetTime()) .. "-" .. type
    
    -- Create a new entry table with all required information
    local entry = {
        id = entryID,
        name = modelInfo.name or "Unknown",
        gender = gender,
        type = type,
        text = text,
        voice = voice,
        timestamp = GetTime(),
        model = modelInfo
    }
    
    -- Insert at the beginning of the list
    table.insert(addon.logEntries, 1, entry)
    
    -- Keep only the max number of entries
    if #addon.logEntries > addon.MAX_LOG_ENTRIES then
        table.remove(addon.logEntries)
    end
    
    -- Refresh the visual log
    addon.ui.RefreshLogDisplay()
    
    return entry
end

-- Refresh the log display with current entries
function ui.RefreshLogDisplay()
    if not addon.TTSLogFrame then return end
    
    local scrollChild = addon.TTSLogFrame.scrollChild
    
    -- Clear existing entries
    for i = scrollChild:GetNumChildren(), 1, -1 do
        local child = select(i, scrollChild:GetChildren())
        child:Hide()
        child:SetParent(nil)
        child = nil
    end
    
    local entryHeight = 36
    local totalHeight = 0
    
    -- Create frames for each log entry
    for i, entry in ipairs(addon.logEntries) do
        local entryFrame = CreateFrame("Frame", nil, scrollChild)
        entryFrame:SetSize(scrollChild:GetWidth() - 20, entryHeight)
        entryFrame:SetPoint("TOPLEFT", 10, -totalHeight)
        
        -- Background for the entry
        if entryFrame.SetBackdrop then
            entryFrame:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                tile = true,
                tileSize = 16,
                edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            entryFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
        else
            -- Fallback for newer versions
            local bg = entryFrame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(true)
            bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
        end
        
        -- Gender and type text
        local headerText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        headerText:SetPoint("TOPLEFT", 5, -5)
        headerText:SetText(string.format("%s", entry.name))
        headerText:SetTextColor(1, 0.8, 0)
        
        -- Main text
        local contentText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        contentText:SetPoint("TOPLEFT", 5, -20)
        contentText:SetPoint("BOTTOMRIGHT", -5, 5) -- Expanded to use full width since play button is removed
        contentText:SetText(entry.text:sub(1, 200) .. (entry.text:len() > 200 and "..." or ""))
        contentText:SetJustifyH("LEFT")
        
        -- Make the entire entry clickable to display the model AND play the speech
        entryFrame:EnableMouse(true)
        entryFrame:SetScript("OnMouseDown", function()
            addon.utils.Debug("Entry clicked: " .. entry.id)
            
            -- Show the model
            addon.ui.DisplayModelFromEntry(entry)
            
            -- Play the text-to-speech for this entry
            addon.core.SpeakWithVoice(entry.text, entry.voice, entry.id)
            
            -- Highlight this entry briefly
            local originalColor
            if entryFrame.SetBackdrop then
                originalColor = {entryFrame:GetBackdropColor()}
                entryFrame:SetBackdropColor(0.3, 0.3, 0.6, 0.7) -- Highlight color
            else
                local bg = entryFrame:GetRegions()
                if bg and bg:IsObjectType("Texture") then
                    originalColor = {bg:GetVertexColor()}
                    bg:SetColorTexture(0.3, 0.3, 0.6, 0.7)
                end
            end
            
            -- Return to original color after a short delay
            C_Timer.After(0.3, function()
                if entryFrame:IsShown() then
                    if entryFrame.SetBackdrop and originalColor then
                        entryFrame:SetBackdropColor(unpack(originalColor))
                    else
                        local bg = entryFrame:GetRegions()
                        if bg and bg:IsObjectType("Texture") and originalColor then
                            bg:SetColorTexture(unpack(originalColor))
                        end
                    end
                end
            end)
        end)
        
        -- Determine if this entry is currently being spoken
        local isCurrentlySpeaking = (addon.currentlySpeakingEntryID and addon.currentlySpeakingEntryID == entry.id)
        
        -- Highlight the background if currently speaking
        if isCurrentlySpeaking then
            if entryFrame.SetBackdrop then
                entryFrame:SetBackdropColor(0.2, 0.4, 0.2, 0.7) -- Green highlight
            else
                -- If using the texture method
                local bg = entryFrame:GetRegions()
                if bg and bg:IsObjectType("Texture") then
                    bg:SetColorTexture(0.2, 0.4, 0.2, 0.7)
                end
            end
            
            -- Also highlight the text
            contentText:SetTextColor(1, 1, 0.7) -- Bright yellow text
        else
            -- Regular color
            contentText:SetTextColor(1, 1, 1) -- White text
        end
        
        -- Play button removed as requested
        
        totalHeight = totalHeight + entryHeight + 5
    end
    
    -- Set the height of the scroll child
    scrollChild:SetHeight(math.max(totalHeight, scrollChild:GetParent():GetHeight()))
end