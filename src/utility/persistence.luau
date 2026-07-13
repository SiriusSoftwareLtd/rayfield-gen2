--!nocheck

local persistence = {}

local config = require(script.Parent.persistenceConfig)
local settings = require(script.Parent.persistenceSettings)

persistence.getPath = config.getPath
persistence.save = config.save
persistence.load = config.load
persistence.list = config.list
persistence.delete = config.delete
persistence.getSettingsPath = settings.getSettingsPath
persistence.saveSettings = settings.saveSettings
persistence.loadSettings = settings.loadSettings

return persistence
