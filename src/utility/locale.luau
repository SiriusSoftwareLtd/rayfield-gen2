--!nocheck

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Rayfield's localization core. Two kinds of copy pass through here: the library's own chrome
-- (search placeholder, "Signed in as", the settings page, and so on) and whatever names a dev
-- gives its elements. Both resolve the same way - the dev translator first, then the built-in
-- table for the active locale, then the source string itself - so anything untranslated still
-- reads in plain English instead of a blank or a raw key.
--
-- Only strings wrapped in locale.t() are treated as copy. Element values, slider readouts,
-- keybind keys and hex codes are data, not language, so they're deliberately left alone.

local variables = require(script.Parent.variables)

local locale = {}

-- English is canonical: every wrapped string in src is written in it, so the source text is
-- also its own lookup key. A new language is just a table keyed by those same source strings;
-- any key it omits falls back to English on its own. Regional tables ("pt-br") win over the
-- bare language ("pt") when both exist.
locale.strings = {
    -- ["fr"] = { ["Signed in as"] = "Connecte en tant que", ... },
}

-- active locale id and the optional dev hook (source, localeId) -> string?. both start neutral,
-- so with no setup at all everything renders in English.
locale.current = "en"
locale.translator = nil

-- a wrapped string carries this tag as a key so Window:Create can tell copy apart from a plain
-- value. property values are always Roblox datatypes or primitives, never plain tables, so the
-- table-with-tag shape is unambiguous.
local tokenTag = {}

local function languageOf(id)
    return string.match(id, "^(%a+)") or id
end

-- Wrap a string so it localizes. Returns the value untouched when there's nothing to translate
-- (non-strings, empty) so callers can wrap unconditionally without special-casing nil names.
function locale.t(source)
    if type(source) ~= "string" or source == "" then
        return source
    end
    return { [tokenTag] = source }
end

-- True for a value produced by locale.t that still carries a source string.
function locale.isToken(value)
    return type(value) == "table" and type(value[tokenTag]) == "string"
end

function locale.sourceOf(token)
    return token[tokenTag]
end

-- Resolve a source string to the active locale: dev translator wins, then an exact-locale table,
-- then the language-only table, then the source itself. The translator is pcall'd so a dev's bad
-- hook can't take the UI down with it.
function locale.resolve(source)
    if type(source) ~= "string" then
        return source
    end

    if locale.translator then
        local ok, translated = pcall(locale.translator, source, locale.current)
        if ok and type(translated) == "string" and translated ~= "" then
            return translated
        end
    end

    local exact = locale.strings[locale.current]
    if exact and exact[source] then
        return exact[source]
    end

    local language = locale.strings[languageOf(locale.current)]
    if language and language[source] then
        return language[source]
    end

    return source
end

-- Merge dev-supplied translation tables into the built-in set. Keyed by locale id (lowercased),
-- each a map of source string -> translation. Merges rather than replaces, so repeated calls (or
-- several windows) accumulate instead of clobbering. These sit alongside the library's own tables;
-- a dev translator, if set, still wins over both.
function locale.register(tables)
    if type(tables) ~= "table" then
        return
    end
    for id, entries in tables do
        if type(id) == "string" and type(entries) == "table" then
            id = string.lower(id)
            local target = locale.strings[id]
            if not target then
                target = {}
                locale.strings[id] = target
            end
            for source, translated in entries do
                target[source] = translated
            end
        end
    end
end

-- Point the active locale at `localeId` (lowercased), falling back to English when it isn't a
-- usable string. Setting it alone touches nothing on screen; callers re-resolve their own labels.
function locale.setActive(localeId)
    locale.current = if type(localeId) == "string" and localeId ~= "" then string.lower(localeId) else "en"
    return locale.current
end

-- The player's language from Roblox's locale id (e.g. "fr-fr"), lowercased and kept whole so a
-- translator sees the exact region. resolve() narrows to the language part when it needs to.
function locale.detect()
    local id = variables.localizationService.RobloxLocaleId
    if type(id) == "string" and id ~= "" then
        return string.lower(id)
    end
    return "en"
end

return locale
