local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rayfield = require(ReplicatedStorage.Rayfield)

-- Let the viewport settle before opening, so the window fits to the full screen size.
task.wait(2)

-- Localization. Keys are the English source strings exactly as they read in the UI. A partial table
-- is fine, anything left out stays in English. German is added at runtime to show that path too.
local translations = {
    fr = {
        ["Gameplay"] = "Jeu",
        ["Interface"] = "Interface",
        ["Auto Sprint"] = "Sprint auto",
        ["Reduced Motion"] = "Animations réduites",
        ["Field of View"] = "Champ de vision",
        ["Player Name"] = "Nom du joueur",
    },
    es = {
        ["Gameplay"] = "Juego",
        ["Interface"] = "Interfaz",
        ["Auto Sprint"] = "Sprint automático",
        ["Reduced Motion"] = "Movimiento reducido",
        ["Field of View"] = "Campo de visión",
        ["Player Name"] = "Nombre del jugador",
    },
}

local window = Rayfield:CreateWindow({
    name = "Example",
    subtitle = "Rayfield Gen2",
    theme = "cobalt",
    translations = translations,
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "ExampleConfigFile",
    },
})

-- Topbar tag, next to the window title.
window:CreateTag({ text = "Beta", color = Color3.fromRGB(255, 175, 15) })

-- Home ----------------------------------------------------------------------
local home = window:CreateTab({ name = "Home", icon = 93364949241311 })

home:CreateSection({ name = "Gameplay" })

home:CreateToggle({
    name = "Auto Sprint",
    value = true,
    callback = function(value)
        print("Auto Sprint:", value)
    end,
})

home:CreateToggle({
    name = "Reduced Motion",
    description = "Disables screen shake and camera effects for a smoother experience.",
    callback = function(value)
        print("Reduced Motion:", value)
    end,
})

home:CreateSlider({
    name = "Field of View",
    range = { 70, 120 },
    increment = 1,
    value = 90,
    suffix = "°",
    callback = function(value)
        workspace.CurrentCamera.FieldOfView = value
    end,
})

home:CreateSection({ name = "Interface" })

home:CreateToggle({ name = "Show FPS Counter" })

home:CreateDropdown({
    name = "Quality",
    options = { "Low", "Medium", "High", "Ultra" },
    value = "High",
    callback = function(value)
        print("Quality:", value)
    end,
})

home:CreateSection({ name = "Feedback" })

home:CreateButton({
    name = "Send Notification",
    icon = 93364949241311,
    callback = function()
        window:Notify({
            title = "Auto-saved",
            content = "Your configuration was saved.",
            icon = 125823673784681,
        })
    end,
})

home:CreateButton({
    name = "Send Toast",
    icon = 125823673784681,
    callback = function()
        window:Toast({ title = "Saved", icon = 125823673784681 })
    end,
})

home:CreateButton({
    name = "Open Popup",
    icon = 83277910885129,
    callback = function()
        window:Popup({
            title = "Reset everything?",
            content = "This clears every saved value and puts the menu back to its defaults. You can't undo it.",
            icon = 83277910885129,
            options = {
                { text = "Cancel" },
                { text = "Reset", style = "danger" },
            },
        })
    end,
})

-- Combat --------------------------------------------------------------------
local combat = window:CreateTab({ name = "Combat", icon = 84750991656135 })

combat:CreateSection({ name = "Aiming" })

combat:CreateToggle({ name = "Aimbot", value = true })

combat:CreateSlider({ name = "Smoothness", range = { 0, 100 }, value = 40, suffix = "%" })

combat:CreateDropdown({
    name = "Modules",
    description = "Pick any combination of modules to load.",
    multiSelect = true,
    options = { "Aimbot", "ESP", "Triggerbot", "Fly" },
    value = { "ESP" },
    placeholder = "None selected",
})

-- Fields --------------------------------------------------------------------
local fields = window:CreateTab({ name = "Fields", icon = 100604009889706 })

fields:CreateSection({ name = "Setup" })

fields:CreateInput({ name = "Player Name", placeholder = "Enter a name" })

fields:CreateInput({
    name = "Max Players",
    description = "Numeric only, commits when you click away or press enter.",
    numeric = true,
    value = "16",
})

fields:CreateKeybind({ name = "Sprint", value = Enum.KeyCode.LeftShift })

fields:CreateKeybind({
    name = "Zoom",
    description = "Hold mode: fires true once held, false on release.",
    value = Enum.KeyCode.C,
    hold = true,
    callback = function(holding)
        print("Zoom:", holding)
    end,
})

fields:CreateColorPicker({ name = "Highlight", color = Color3.fromRGB(96, 205, 255) })

-- Stats ---------------------------------------------------------------------
local stats = window:CreateTab({ name = "Stats", icon = 85925158736685 })

stats:CreateSection({ name = "Session" })

local revenue = stats:CreateStat({ name = "Revenue", prefix = "$", value = 12400 })
local kills = stats:CreateStat({ name = "Kills", value = 128 })

stats:CreateButton({
    name = "Simulate Round",
    callback = function()
        revenue:Set(revenue.value + math.random(500, 3000))
        kills:Set(kills.value + math.random(1, 20))
    end,
})

-- Layout --------------------------------------------------------------------
local layout = window:CreateTab({ name = "Layout", icon = 84750991656135 })

layout:CreateSection({ name = "Loadout" })

local grid = layout:CreateGroup()

local leftColumn = grid:CreateGroup({ direction = "column" })
-- own flag: "Aimbot" is taken by the Combat toggle and derived flags must stay unique
leftColumn:CreateToggle({ name = "Aimbot", flag = "LoadoutAimbot", value = true })
leftColumn:CreateToggle({ name = "Triggerbot" })

local rightColumn = grid:CreateGroup({ direction = "column" })
rightColumn:CreateToggle({ name = "ESP", value = true })
rightColumn:CreateToggle({ name = "Tracers" })

-- Text ----------------------------------------------------------------------
local text = window:CreateTab({ name = "Text", icon = 100604009889706 })

text:CreateSection({ name = "Text" })

-- a title and a body, the usual shape
text:CreateText({
    name = "Read this first",
    text = "Text carries a title, a body, or both. Either half can be left out and the card closes up around what's left.",
})

-- title only, for a heading that isn't a section
text:CreateText({ name = "Heading on its own" })

-- body only, evenly padded with no room held for the missing title
text:CreateText({
    text = "Body on its own, for a note that doesn't need a heading over it.",
})

-- with an icon beside the title
text:CreateText({
    name = "Worth knowing",
    text = "An icon sits to the left of the title.",
    icon = 93364949241311,
})

local live = text:CreateText({ name = "Changes at runtime", text = "Waiting." })

text:CreateButton({
    name = "Rewrite the body",
    callback = function()
        live:Set("Rewritten at " .. os.date("%H:%M:%S") .. ".")
    end,
})

text:CreateButton({
    name = "Rewrite the title",
    callback = function()
        live:SetTitle("Retitled")
    end,
})

text:CreateSection({ name = "Dividers" })

text:CreateText({ text = "A plain rule, with the default room around it." })
text:CreateDivider()

text:CreateText({ text = "A rule with a word in the middle." })
text:CreateDivider({ text = "or" })

text:CreateText({ text = "More room above and below." })
text:CreateDivider({ text = "spaced", spacing = 24 })

text:CreateText({ text = "No rule at all, just the room. A spacer." })
text:CreateDivider({ line = false, spacing = 20 })

text:CreateText({ text = "The one below starts bare and gains a word." })
local divider = text:CreateDivider()

text:CreateButton({
    name = "Give the divider a word",
    callback = function()
        divider:Set("added later")
    end,
})

text:CreateButton({
    name = "Take it back off",
    callback = function()
        divider:Set("")
    end,
})

-- Language ------------------------------------------------------------------
local language = window:CreateTab({ name = "Language", icon = 100604009889706 })

language:CreateSection({ name = "Localization" })

local localeIds = { English = "en", ["Français"] = "fr", ["Español"] = "es", ["Deutsch"] = "de" }

language:CreateDropdown({
    name = "Language",
    description = "Switches every localized label in place. Untranslated strings stay in English.",
    options = { "English", "Français", "Español", "Deutsch" },
    value = "English",
    forgetState = true,
    callback = function(value)
        if value == "Deutsch" then
            window:RegisterTranslations({
                de = {
                    ["Gameplay"] = "Spiel",
                    ["Interface"] = "Benutzeroberfläche",
                    ["Auto Sprint"] = "Auto-Sprint",
                    ["Field of View"] = "Sichtfeld",
                    ["Player Name"] = "Spielername",
                },
            })
        end
        window:SetLocale(localeIds[value] or "en")
    end,
})

window:Navigate("Home")
