-- SpeakCraft: UI Components
local addonName, addon = ...
local ui = addon.ui

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
    
    -- Add resize grip (without using SetResizable which isn't available in some clients)
    local resizeGrip = CreateFrame("Button", nil, logFrame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -1, 1)
    resizeGrip:EnableMouse(true)
    
    -- Create resize grip texture
    local gripTexture = resizeGrip:CreateTexture(nil, "ARTWORK")
    gripTexture:SetAllPoints(resizeGrip)
    gripTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetNormalTexture(gripTexture)
    
    -- Hover and click textures
    local hoverTexture = resizeGrip:CreateTexture(nil, "HIGHLIGHT")
    hoverTexture:SetAllPoints(resizeGrip)
    hoverTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetHighlightTexture(hoverTexture)
    
    local downTexture = resizeGrip:CreateTexture(nil, "OVERLAY")
    downTexture:SetAllPoints(resizeGrip)
    downTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetPushedTexture(downTexture)
    
    -- Set up manual resize functionality (without using SetResizable)
    local minWidth, minHeight = 300, 200
    local maxWidth, maxHeight = 800, 600
    local isResizing = false
    
    resizeGrip:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isResizing = true
            logFrame:SetScript("OnUpdate", function(self, elapsed)
                if isResizing then
                    local cursorX, cursorY = GetCursorPosition()
                    local scale = UIParent:GetScale()
                    local x, y = logFrame:GetCenter()
                    local halfWidth = logFrame:GetWidth() / 2
                    local halfHeight = logFrame:GetHeight() / 2
                    local left, bottom = x - halfWidth, y - halfHeight
                    
                    -- Calculate new width and height
                    local newWidth = cursorX / scale - left
                    local newHeight = bottom + logFrame:GetHeight() - cursorY / scale
                    
                    -- Apply size limits
                    newWidth = math.max(minWidth, math.min(newWidth, maxWidth))
                    newHeight = math.max(minHeight, math.min(newHeight, maxHeight))
                    
                    -- Set the new size
                    logFrame:SetSize(newWidth, newHeight)
                end
            end)
        end
    end)
    
    resizeGrip:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            isResizing = false
            logFrame:SetScript("OnUpdate", nil)
            -- Refresh display after resize
            ui.RefreshLogDisplay()
        end
    end)
    
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
    
    -- Scroll frame for log entries
    local scrollFrame = CreateFrame("ScrollFrame", "SpeakCraftLogScrollFrame", logFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50) -- Leave space for the volume slider
    
    local scrollChild = CreateFrame("Frame")
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1) -- Will be resized as entries are added
    
    logFrame.scrollChild = scrollChild
    
    -- Update scroll frame size when frame is resized
    logFrame:HookScript("OnSizeChanged", function(self, width, height)
        scrollFrame:SetPoint("BOTTOMRIGHT", -40, 50) -- Maintain bottom margin for slider
        scrollChild:SetWidth(scrollFrame:GetWidth())
        ui.RefreshLogDisplay()
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
    
    -- Create a new entry table with all required information
    local entry = {
        gender = gender,
        type = type,
        text = text,
        voice = voice,
        timestamp = GetTime()
    }
    
    -- Insert at the beginning of the list
    table.insert(addon.logEntries, 1, entry)
    
    -- Keep only the max number of entries
    if #addon.logEntries > addon.MAX_LOG_ENTRIES then
        table.remove(addon.logEntries)
    end
    
    -- Refresh the visual log
    ui.RefreshLogDisplay()
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
    
    local entryHeight = 50
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
        headerText:SetText(string.format("[%s] [%s]:", entry.gender, entry.type))
        headerText:SetTextColor(1, 0.8, 0)
        
        -- Main text
        local contentText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        contentText:SetPoint("TOPLEFT", 5, -20)
        contentText:SetPoint("BOTTOMRIGHT", -40, 5)
        contentText:SetText(entry.text:sub(1, 200) .. (entry.text:len() > 200 and "..." or ""))
        contentText:SetJustifyH("LEFT")
        
        -- Play button
        local playButton = CreateFrame("Button", nil, entryFrame, "UIPanelButtonTemplate")
        playButton:SetSize(30, 30)
        playButton:SetPoint("RIGHT", -5, 0)
        playButton:SetText("►")
        playButton:SetScript("OnClick", function()
            addon.core.SpeakWithVoice(entry.text, entry.voice)
        end)
        
        totalHeight = totalHeight + entryHeight + 5
    end
    
    -- Set the height of the scroll child
    scrollChild:SetHeight(math.max(totalHeight, scrollChild:GetParent():GetHeight()))
end