-- SpeakCraft: Event Handler
local addonName, addon = ...
local events = addon.events

-- Handle all addon events
function events.HandleEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        self:UnregisterEvent("ADDON_LOADED")
        print("SpeakCraft: TTS loaded. Use /sc for commands.")
        
        -- Create the TTS Log Frame
        addon.TTSLogFrame = addon.ui.CreateTTSLogFrame()
        
        -- Register for basic dialog events
        self:RegisterEvent("GOSSIP_SHOW")
        self:RegisterEvent("QUEST_DETAIL")
        self:RegisterEvent("QUEST_PROGRESS")
        self:RegisterEvent("QUEST_COMPLETE")
        
        -- Register for target change to update gender info
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Just log the new target's gender if in debug mode
        if addon.DEBUG_MODE then
            local sex = UnitSex("target")
            if sex then
                local gender = "unknown"
                if sex == 2 then gender = "male" 
                elseif sex == 3 then gender = "female" end
                addon.utils.Debug("Target changed, gender: " .. gender)
            end
        end
    elseif event == "GOSSIP_SHOW" then
        if addon.TTS_ENABLED then
            C_Timer.After(0.5, addon.core.ReadGossip)
        end
    elseif event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        if addon.TTS_ENABLED then
            C_Timer.After(0.5, addon.core.ReadQuest)
        end
    end
end