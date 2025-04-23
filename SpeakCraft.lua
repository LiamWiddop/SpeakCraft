-- SpeakCraft: Main File
local addonName, addon = ...

-- Initialize namespace
addon.core = {}
addon.ui = {}
addon.utils = {}
addon.events = {}

-- Simple settings
addon.TTS_ENABLED = true
addon.TTS_RATE = -2
addon.TTS_VOLUME = 75
addon.DEBUG_MODE = false -- Debug off by default

-- Voice settings
addon.TTS_DEFAULT_VOICE = 0   -- Default voice (usually male)
addon.TTS_FEMALE_VOICE = 1    -- Female voice index
addon.TTS_MALE_VOICE = 0      -- Male voice index
addon.USE_GENDER_BASED_VOICE = true -- Toggle for gender-based voice

-- TTS Log Frame settings
addon.MAX_LOG_ENTRIES = 10
addon.logEntries = {}

-- Create main frame
addon.TTSFrame = CreateFrame("Frame")

-- Register slash command handler
SLASH_SC1 = "/sc"
SlashCmdList["SC"] = function(msg)
    addon.utils.HandleSlashCommand(msg)
end

-- Initialize addon when it's loaded
addon.TTSFrame:RegisterEvent("ADDON_LOADED")
addon.TTSFrame:SetScript("OnEvent", function(self, event, ...)
    addon.events.HandleEvent(self, event, ...)
end)