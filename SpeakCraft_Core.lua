-- SpeakCraft: Core TTS Functionality
local addonName, addon = ...
local core = addon.core

-- Stop any previous TTS before starting a new one
function core.StopPreviousTTS(callback)
    if C_VoiceChat.StopSpeakingText then
        C_VoiceChat.StopSpeakingText()
        addon.utils.Debug("Stopped previous TTS")
        
        -- Add a delay before starting new TTS to avoid conflicts
        C_Timer.After(0.3, function()
            if callback then callback() end
        end)
        return true
    end
    
    -- If we couldn't stop the TTS, call the callback immediately
    if callback then callback() end
    return false
end

-- Define the working test function
function core.TestSpeech(text, voiceIndex)
    local voice = voiceIndex or (addon.USE_GENDER_BASED_VOICE and addon.utils.GetNPCGender() or addon.TTS_DEFAULT_VOICE)
    print("Testing speech: " .. (text or "Hello, this is a test.") .. " with voice: " .. voice)
    
    -- Use the approach that we know works
    local destination = Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback or 1
    addon.TTS_RATE = math.random(-2, 10)
    C_VoiceChat.SpeakText(voice, text or "Hello, this is a test.", destination, addon.TTS_RATE, addon.TTS_VOLUME)
end

-- Function to speak the text with the given voice
function core.SpeakWithVoice(text, voice, entryID)
    core.StopPreviousTTS(function()
        addon.utils.Debug("----------------")
        addon.utils.Debug("Processing text: " .. text)

        local parts = {}
        local destination = Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback or 1
        
        for part in string.gmatch(text, "[^.,!?]+") do
            -- Clean up any leading/trailing whitespace
            part = part:match("^%s*(.-)%s*$")
            if part ~= "" then
                table.insert(parts, part)
            end
        end
        
        -- Set currently speaking entry for highlighting
        addon.currentlySpeakingEntryID = entryID
        
        -- Update the UI to show highlighting and model
        if addon.TTSLogFrame then
            -- Find the entry in log entries to display model
            for i, entry in ipairs(addon.logEntries) do
                if entry.id == entryID then
                    addon.utils.Debug("Found entry for ID: " .. entryID)
                    
                    -- Display the model using the shared function
                    if addon.ui and addon.ui.DisplayModelFromEntry then
                        addon.ui.DisplayModelFromEntry(entry)
                    else
                        addon.utils.Debug("UI or DisplayModelFromEntry function not available")
                    end
                    break
                end
            end
            
            -- Refresh the log display to show highlighting
            if addon.ui and addon.ui.RefreshLogDisplay then
                addon.ui.RefreshLogDisplay()
            else
                addon.utils.Debug("UI or RefreshLogDisplay function not available")
            end
        end
        
        -- Process the parts sequentially with delays between them
        addon.utils.Debug("Parts to speak: " .. #parts)
        local function ProcessNextPart(index)
            if index <= #parts then
                local part = parts[index]
                addon.TTS_RATE = math.random(1, 3)
                C_VoiceChat.SpeakText(voice, part, destination, addon.TTS_RATE, addon.TTS_VOLUME)
                addon.utils.Debug("Speaking part: " .. part)
                
                -- Schedule the next part with a delay based on text length
                -- Longer text needs more delay to complete speaking before next segment starts
                local delay = 0.5 -- 0.05 seconds per character, minimum 0.3 seconds
                C_Timer.After(delay, function() 
                    ProcessNextPart(index + 1)
                end)
            else
                -- When finished, clear the currently speaking entry
                C_Timer.After(0.5, function()
                    addon.currentlySpeakingEntryID = nil
                    
                    -- Update UI after speech completes
                    if addon.ui and addon.ui.RefreshLogDisplay then
                        addon.ui.RefreshLogDisplay()
                    end
                end)
            end
        end
        
        -- Start processing the first part
        ProcessNextPart(1)
    end)
end

-- Read dialog function using our working TTS method with gender detection
function core.ReadGossip()
    if not addon.TTS_ENABLED then return end
    
    -- Get the text first
    local text = addon.utils.GetDialogTextClassic()
    text = addon.utils.CleanText(text)
    
    -- Determine voice based on NPC gender
    local voice, genderText
    if addon.USE_GENDER_BASED_VOICE then
        voice, genderText = addon.utils.GetNPCGender()
    else
        voice, genderText = addon.TTS_DEFAULT_VOICE, "Default"
    end
    addon.utils.Debug("Using voice: " .. voice)
    
    -- Log to the TTS frame BEFORE processing with gmatch
    local entry = addon.ui.AddLogEntry(genderText, "GOSSIP", text, voice)
    
    -- Use SpeakWithVoice function instead of duplicating the logic
    core.SpeakWithVoice(text, voice, entry.id)
end

-- Read quest function using our working TTS method with gender detection
function core.ReadQuest()
    if not addon.TTS_ENABLED then return end
    
    -- Get the text first
    local text = addon.utils.GetQuestTextClassic()
    text = addon.utils.CleanText(text)
    
    -- Determine voice based on NPC gender
    local voice, genderText
    if addon.USE_GENDER_BASED_VOICE then
        voice, genderText = addon.utils.GetNPCGender()
    else
        voice, genderText = addon.TTS_DEFAULT_VOICE, "Default"
    end
    addon.utils.Debug("Using voice: " .. voice)
    
    -- Log to the TTS frame BEFORE processing with gmatch
    local entry = addon.ui.AddLogEntry(genderText, "QUEST", text, voice)
    
    -- Use SpeakWithVoice function instead of duplicating the logic
    core.SpeakWithVoice(text, voice, entry.id)
end