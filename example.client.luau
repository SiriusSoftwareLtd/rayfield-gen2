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
    -- Uptime monitoring: pings your Sentivel heartbeat while the window is open. Skipped in Studio.
    -- See https://docs.sirius.menu/rayfield-gen2/heartbeat
    -- heartbeat = "https://www.sentivel.com/api/heartbeat/<your token>",
    subtitle = "Rayfield Gen2",
    translations = translations,
    sidebarLayout = true, -- flip this for tabs across the top instead of down the left
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "ExampleConfigFile",
    },
})

-- Rail sections group the tabs under them. Sidebar layout only - on the top strip they do
-- nothing. This one heads the list, so it carries no space above it.
window:CreateSection({ name = "General" })

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
-- this one follows tabs, so it sits with a gap above it
window:CreateSection({ name = "Reference" })

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

-- What's new -----------------------------------------------------------------
local whatsNew = window:CreateTab({ name = "What's New", icon = 93364949241311 })

whatsNew:CreateSection({ name = "Progress" })

local download = whatsNew:CreateProgress({
    name = "Download",
    description = "Takes a range like a slider does. The readout is a percentage unless you give it a line of your own.",
    range = { 0, 100 },
    value = 35,
    format = function(value, _, max)
        return string.format("%d of %d MB", value, max)
    end,
})

whatsNew:CreateProgress({
    name = "Setup",
    description = "A stepped bar counts stages instead of distance.",
    steps = 5,
    value = 2,
})

whatsNew:CreateProgress({
    name = "Syncing",
    text = "Please wait",
    indeterminate = true, -- a sweep, for work with no known length
})

whatsNew:CreateSlider({
    name = "Download progress",
    description = "Drives the bar above. The slider now tells its callback whether you are still dragging.",
    range = { 0, 100 },
    value = 35,
    suffix = "%",
    forgetState = true,
    callback = function(value, dragging)
        download:Set(value)
        download:SetText(if dragging then "Downloading" else nil)
    end,
})

whatsNew:CreateSection({ name = "Output" })

local console = whatsNew:CreateConsole({
    name = "Console",
    text = "-- output lands here",
    height = 130,
    follow = true, -- pins itself to the newest line
    maxLines = 50, -- past this the oldest roll off the top
})

whatsNew:CreateButton({
    name = "Log a line",
    description = "The block holds its height and scrolls inside itself, so the page never grows.",
    callback = function()
        console:Append(string.format("[%s] player joined", os.date("%H:%M:%S")))
    end,
})

local group = whatsNew:CreateGroup()

group:CreateButton({
    name = "Copy",
    callback = function()
        window:Notify({
            title = if console:Copy() then "Copied" else "No clipboard here",
            content = "Copy needs an executor that provides setclipboard.",
        })
    end,
})

group:CreateButton({
    name = "Clear",
    callback = function()
        console:Clear()
    end,
})

whatsNew:CreateSection({ name = "Locking" })

local lockable = whatsNew:CreateToggle({
    name = "Auto Farm",
    description = "Lock this and it dims, stops taking input, and never fires its callback.",
    value = false,
    forgetState = true,
    callback = function(state)
        print("this never runs while the toggle is locked", state)
    end,
})

whatsNew:CreateToggle({
    name = "Lock Auto Farm",
    description = "Locking is what a key check or a missing dependency should do to an element.",
    value = false,
    forgetState = true,
    callback = function(state)
        if state then
            lockable:Lock("Needs a premium key")
        else
            lockable:Unlock()
        end
    end,
})

window:Navigate("Home")
