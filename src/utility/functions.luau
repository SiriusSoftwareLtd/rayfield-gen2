--!nocheck

local functions = {}

local textMetrics = require(script.Parent.textMetrics)
local colors = require(script.Parent.colors)
local flags = require(script.Parent.flagNames)

functions.textWidth = textMetrics.textWidth
functions.textHeight = textMetrics.textHeight
functions.deriveFlagFromName = flags.deriveFlagFromName
functions.contrastColor = colors.contrastColor
functions.toColorSequence = colors.toColorSequence
functions.contrastText = colors.contrastText

return functions
