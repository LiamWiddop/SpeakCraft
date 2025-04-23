-- SpeakCraft: Utility Functions
local addonName, addon = ...
local utils = addon.utils

-- Debug function
function utils.Debug(...)
    if addon.DEBUG_MODE then
        print("|cFF00FFFF[TTS Debug]|r", ...)
    end
end

-- Determine NPC gender based on unit information
function utils.GetNPCGender()
    -- Default to male voice if we can't determine
    local currentVoice = addon.TTS_MALE_VOICE
    local genderText = "Male"
    
    -- Try to get the target's gender
    local targetGUID = UnitGUID("target")
    if targetGUID then
        local targetSex = UnitSex("target")
        utils.Debug("Target sex: " .. (targetSex or "unknown"))
        
        -- UnitSex returns:
        -- 1 = Unknown
        -- 2 = Male
        -- 3 = Female
        if targetSex == 3 then
            currentVoice = addon.TTS_FEMALE_VOICE
            genderText = "Female"
            utils.Debug("Using female voice for female NPC")
        elseif targetSex == 2 then
            currentVoice = addon.TTS_MALE_VOICE
            genderText = "Male"
            utils.Debug("Using male voice for male NPC")
        else
            genderText = "Unknown"
        end
    else
        utils.Debug("No target selected, using default voice")
    end
    
    return currentVoice, genderText
end

-- Get NPC Display ID for model viewer
function utils.GetNPCDisplayID()
    -- Check if target exists
    if not UnitExists("target") then
        utils.Debug("No target exists for getting display ID")
        return nil
    end
    
    -- Try to get the display ID
    local modelDisplay = nil
    local npcID = nil
    
    -- Try to get from GUID first (most reliable for storage)
    local guid = UnitGUID("target")
    if guid then
        local type, _, _, _, _, id = strsplit("-", guid)
        if type == "Creature" and id then
            npcID = tonumber(id)
            utils.Debug("Got NPC ID: " .. tostring(npcID))
        end
    end
    
    -- Store the npcID for now, we'll try to get a real display ID during actual display
    if npcID then
        modelDisplay = npcID
    end
    
    -- If we have a log frame with a model display, try to capture the real display ID
    if addon.TTSLogFrame and addon.TTSLogFrame.modelDisplay then
        utils.Debug("Attempting to get displayID from model")
        
        -- Create a temporary hidden model to avoid messing with the visible one
        local tempFrame = CreateFrame("Frame")
        tempFrame:Hide()
        local tempModel = CreateFrame("PlayerModel", nil, tempFrame)
        
        -- Try to set the model and get its display info
        tempModel:SetUnit("target")
        
        -- Try to get the display info after a tiny delay to allow the model to load
        C_Timer.After(0.05, function()
            pcall(function()
                local displayID = tempModel:GetDisplayInfo()
                if displayID then
                    utils.Debug("Successfully captured displayID: " .. displayID)
                    -- If we've found a real display ID, update our stored model info
                    for i, entry in ipairs(addon.logEntries) do
                        if entry.model and entry.model.guid == guid then
                            entry.model.displayID = displayID
                            utils.Debug("Updated stored displayID for entry")
                        end
                    end
                end
            end)
            
            -- Clean up
            tempModel:SetParent(nil)
            tempModel = nil
            tempFrame:SetParent(nil)
            tempFrame = nil
        end)
    end
    
    return modelDisplay
end

-- Version-specific text extraction for different game versions
function utils.ExtractTextFromGossip()
    local text = ""
    
    -- Check direct elements first (most common)
    if GossipGreetingText and GossipGreetingText:IsVisible() then
        text = GossipGreetingText:GetText() or ""
        utils.Debug("Got text from GossipGreetingText: " .. text:sub(1, 40) .. (text:len() > 40 and "..." or ""))
        return text
    end
    
    -- Try modern UI (Shadowlands+)
    if GossipFrame and GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.ScrollBox then
        for i = 1, GossipFrame.GreetingPanel.ScrollBox:GetNumChildren() do
            local child = select(i, GossipFrame.GreetingPanel.ScrollBox:GetChildren())
            if child and child.Text then
                local childText = child.Text:GetText()
                if childText and childText ~= "" then
                    text = childText
                    utils.Debug("Got text from modern gossip UI: " .. text:sub(1, 40) .. (text:len() > 40 and "..." or ""))
                    return text
                end
            end
        end
    end
    
    -- Try retail frame structure
    if GossipFrame and GossipFrame:GetNumRegions() > 0 then
        for i = 1, GossipFrame:GetNumRegions() do
            local region = select(i, GossipFrame:GetRegions())
            if region and region:GetObjectType() == "FontString" and region:IsVisible() then
                local regionText = region:GetText()
                if regionText and regionText ~= "" and not regionText:match("^<") then
                    -- Skip the NPC name which often starts with <
                    if text == "" then
                        text = regionText
                    elseif regionText:len() > text:len() then
                        -- Assume longer text is the actual dialog
                        text = regionText
                    end
                end
            end
        end
        
        if text ~= "" then
            utils.Debug("Got text from GossipFrame regions: " .. text:sub(1, 40) .. (text:len() > 40 and "..." or ""))
            return text
        end
    end
    
    -- Try classic UI structure
    if GossipFrameGreetingPanel then
        for i = 1, GossipFrameGreetingPanel:GetNumRegions() do
            local region = select(i, GossipFrameGreetingPanel:GetRegions())
            if region and region:GetObjectType() == "FontString" and region:IsVisible() then
                local regionText = region:GetText()
                if regionText and regionText ~= "" and not regionText:match("^<") then
                    if text == "" then
                        text = regionText
                    elseif regionText:len() > text:len() then
                        -- Assume longer text is the actual dialog
                        text = regionText
                    end
                end
            end
        end
        
        if text ~= "" then
            utils.Debug("Got text from GossipFrameGreetingPanel: " .. text:sub(1, 40) .. (text:len() > 40 and "..." or ""))
            return text
        end
    end
    
    utils.Debug("No gossip text found")
    return ""
end

function utils.ExtractTextFromQuestFrame()
    local title = "";
    local text = ""
    local questObjectives = "";
    local progressText = "";
    local completionText = "";

    questTitle = GetTitleText()
    questText = GetQuestText()
    questObjectives = GetObjectiveText()
    progressText = GetProgressText()
    completionText = GetRewardText()

    if questTitle and questTitle ~= "" then
        print("Quest Title: " .. questTitle)
    end

    if questText and questText ~= "" then
        print("Quest Text: " .. questText)
        text = text .. questText .. "\n"
    end

    if progressText and progressText ~= "" then
        print("Quest Progress Text: " .. progressText)
        text = text .. "\n" .. progressText
    end
    
    if questObjectives and questObjectives ~= "" then
        print("Quest Objectives: " .. questObjectives)
        text = text .. "\n" .. "Your objectives are to " .. questObjectives
    end

    if completionText and completionText ~= "" then
        print("Quest Completion Text: " .. completionText)
        text = text .. "\n" .. completionText
    end

    return text
end

-- Get dialog text 
function utils.GetDialogTextClassic()
    -- Get dialog text 
    local gossipText = C_GossipInfo.GetText()
    utils.Debug("Gossip Text:", gossipText)
    
    -- Get available gossip options
    local options = C_GossipInfo.GetOptions()
    for i, option in ipairs(options) do
        utils.Debug("Option", i, ":", option.name)
    end

    -- Try newer API first
    if gossipText and gossipText ~= "" then
        return gossipText
    end
    
    -- Fallback to our extraction methods
    gossipText = utils.ExtractTextFromGossip()
    
    -- If still no gossip text, try quest text
    if gossipText == "" then
        gossipText = utils.ExtractTextFromQuestFrame()
    end
    
    return gossipText
end

function utils.GetQuestTextClassic()
    local questText = ""
    
    -- Try to extract text from the quest frame
    questText = utils.ExtractTextFromQuestFrame()
    
    -- Get available quest options if you still need them and the API exists
    if C_QuestLog and C_QuestLog.GetOptions then
        local options = C_QuestLog.GetOptions()
        if options then
            for i, option in ipairs(options) do
                utils.Debug("Option", i, ":", option.name)
            end
        end
    end
    
    return questText
end

function utils.CleanText(text)
    if text and text ~= "" then
        utils.Debug("Dialog text found, length: " .. text:len())
        -- Clean the text
        text = text:gsub("<[^>]+>", "") -- Remove any HTML-like tags
        text = text:gsub("|c%x%x%x%x%x%x%x%x", "") -- Remove color codes
        text = text:gsub("|r", "") -- Remove color restore codes
        text = text:gsub("%s+", " ")    -- Normalize whitespace
    else
        utils.Debug("No dialog text found to read")
    end
    return text
end

-- Handle slash commands
function utils.HandleSlashCommand(msg)
    local cmd, arg = strsplit(" ", msg, 2)
    
    if cmd == "on" or cmd == "enable" then
        addon.TTS_ENABLED = true
        print("TTS enabled")
    elseif cmd == "off" or cmd == "disable" then
        addon.TTS_ENABLED = false
        addon.core.StopPreviousTTS()
        print("TTS disabled")
    elseif cmd == "test" then
        addon.core.TestSpeech(arg)
    elseif cmd == "speak" or cmd == "read" then
        addon.core.ReadGossip() -- Assuming we want to read gossip by default
    elseif cmd == "debug" then
        addon.DEBUG_MODE = not addon.DEBUG_MODE
        print("Debug mode: " .. (addon.DEBUG_MODE and "ON" or "OFF"))
    elseif cmd == "gender" or cmd == "voice" then
        addon.USE_GENDER_BASED_VOICE = not addon.USE_GENDER_BASED_VOICE
        print("Gender-based voice: " .. (addon.USE_GENDER_BASED_VOICE and "ON" or "OFF"))
    elseif cmd == "male" then
        addon.core.TestSpeech("This is the male voice test.", addon.TTS_MALE_VOICE)
    elseif cmd == "female" then
        addon.core.TestSpeech("This is the female voice test.", addon.TTS_FEMALE_VOICE)
    elseif cmd == "log" then
        if addon.TTSLogFrame:IsShown() then
            addon.TTSLogFrame:Hide()
        else
            addon.TTSLogFrame:Show()
        end
        print("TTS Log " .. (addon.TTSLogFrame:IsShown() and "shown" or "hidden"))
    elseif cmd == "rate" and arg then
        local rate = tonumber(arg)
        if rate and rate >= -10 and rate <= 10 then
            addon.TTS_RATE = rate
            print("TTS rate set to " .. rate)
        else
            print("TTS rate must be between -10 and 10")
        end
    elseif cmd == "volume" and arg then
        local volume = tonumber(arg)
        if volume and volume >= 0 and volume <= 100 then
            addon.TTS_VOLUME = volume
            print("TTS volume set to " .. volume)
        else
            print("TTS volume must be between 0 and 100")
        end
    else
        print("SpeakCraft commands:")
        print("/sc on - Enable TTS")
        print("/sc off - Disable TTS")
        print("/sc test [text] - Test with custom text")
        print("/sc speak - Read current dialog")
        print("/sc debug - Toggle debug messages")
        print("/sc gender - Toggle gender-based voices")
        print("/sc log - Toggle TTS log display")
        print("/sc male - Test male voice")
        print("/sc female - Test female voice")
        print("/sc rate [number] - Set rate (-10 to 10)")
        print("/sc volume [number] - Set volume (0 to 100)")
    end
end