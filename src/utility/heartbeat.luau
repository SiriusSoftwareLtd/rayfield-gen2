--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Sentivel heartbeats, driven by a window. A heartbeat monitor stays green while pings keep
-- arriving. The window pings once when it opens and again every few minutes while it's up, so
-- the monitor reads "someone is running this script right now". Unloading stops it.
--
-- Everything here is best-effort. Pings run off the calling thread, never throw, and never hold
-- up the script. Two things do warn, because each would otherwise sit silent while the monitor
-- reads it as an outage: a link that isn't a Sentivel heartbeat, and a token Sentivel says it
-- doesn't know. Like all of Rayfield's output, those warnings are silenced under secure mode.

local network = require(script.Parent.network)
local log = require(script.Parent.log)
local runtime = require(script.Parent.runtime)

local heartbeat = {}

-- Seconds between pings while the window is up. A monitor set to 5 minutes with a little grace
-- stays green for as long as anyone has the script open. Slower would force every developer onto
-- long intervals; faster only costs requests, since one ping per interval is all a monitor needs.
heartbeat.period = 300

-- Consecutive 404s before the loop gives up. Sentivel answers 404 for a token it doesn't know,
-- which never recovers, but one stray 404 from a bad deploy shouldn't silence every session.
heartbeat.giveUpAfter = 3

-- the loop that currently owns each ping URL. a newer window on the same link takes it over and
-- the older loop retires when it next wakes, so the link is never pinged twice over, and a
-- window rebuilt straight after an unload isn't turned away by a loop that's still asleep
local owners: { [string]: {} } = {}

-- what a pinging window needs from the outside world. the live one is built per start; specs
-- pass a fake. `get` returns the HTTP status when the transport can see it, nil when it can't
export type Environment = {
    isStudio: boolean,
    get: ((url: string) -> number?)?,
    spawn: (callback: () -> ()) -> (),
    wait: (seconds: number) -> (),
}

-- always www: the bare domain answers with a redirect, which is one more round trip per ping
heartbeat.base = "https://www.sentivel.com/api/heartbeat/"

local HOSTS = { ["sentivel.com"] = true, ["www.sentivel.com"] = true }

-- tokens are hex. the bounds are loose so a future token format still passes; a monitor id (a
-- UUID, so it has dashes) falls outside them and gets told what to paste instead
local function validToken(token: string): boolean
    return #token >= 32 and #token <= 128 and string.match(token, "^%x+$") ~= nil
end

-- A full ping URL or its bare token, to the canonical URL. Returns nil and the reason when the
-- target is not a Sentivel heartbeat, worded for the developer who passed it.
function heartbeat.resolve(target: any): (string?, string?)
    if type(target) ~= "string" then
        return nil, `heartbeat takes your Sentivel ping URL or token as a string, got {typeof(target)}`
    end
    -- a real link is under 100 characters; this keeps the trim below cheap on anything absurd
    if #target > 512 then
        return nil, "heartbeat is far too long to be a Sentivel ping URL. Copy the ping URL and try again"
    end

    -- a copy out of Discord or a browser can drag along no-break and zero-width spaces, which %s
    -- doesn't cover
    local cleaned = string.gsub(string.gsub(target, "\194\160", " "), "\226\128\139", "")
    cleaned = string.gsub(cleaned, "\239\187\191", "")
    local trimmed = string.match(cleaned, "^%s*(.-)%s*$") :: string
    if trimmed == "" then
        return nil, "heartbeat is empty. Paste the ping URL from your Sentivel heartbeat monitor"
    end

    -- a link pasted without its scheme is still a link
    if not string.find(trimmed, "://", 1, true) and string.find(trimmed, "/", 1, true) then
        trimmed = "https://" .. trimmed
    end

    local token = trimmed
    if string.find(trimmed, "://", 1, true) then
        -- host first, on its own, so a Sentivel link that is merely the wrong page is told that
        -- rather than being told it isn't Sentivel
        local host, rest = string.match(trimmed, "^[Hh][Tt][Tt][Pp][Ss]?://([^/?#]+)(.*)$")
        -- the default port and a fully qualified trailing dot name the same host
        local bare = if host then string.gsub(string.gsub(string.lower(host), ":443$", ""), "%.$", "") else nil
        if not bare or not HOSTS[bare] then
            return nil, "heartbeat only pings Sentivel. Use the ping URL from your heartbeat monitor"
        end
        local found = string.match(rest :: string, "^/api/heartbeat/([^/?#]+)/?$")
        if not found then
            return nil,
                "That Sentivel link isn't a heartbeat ping URL. It should look like " .. heartbeat.base .. "<token>"
        end
        token = found
    end

    if not validToken(token) then
        if string.match(token, "^%x+%-%x+%-%x+%-%x+%-%x+$") then
            return nil, "That looks like a monitor ID. heartbeat needs the monitor's ping URL, not its ID"
        end
        return nil, "That doesn't look like a Sentivel heartbeat token. Copy the whole ping URL and try again"
    end

    -- Sentivel issues lowercase tokens and matches them exactly, so an uppercased one would 404
    return heartbeat.base .. string.lower(token), nil
end

-- The executor's HTTP request function first, the same one asset downloads use, since it hands
-- back the status code. Then HttpGet, which every executor has in some form. It throws on a
-- failed request instead, so a 404 is read out of its error. nil when there is no way to send.
function heartbeat.transport(env: any?, dataModel: any?): ((url: string) -> number?)?
    local requestFn = network.getRequestFn(env)
    if requestFn then
        return function(url: string): number?
            local response = requestFn({ Url = url, Method = "GET" })
            -- some executors hand the status back as a string
            return if type(response) == "table" then tonumber(response.StatusCode) else nil
        end
    end

    local target = dataModel or game
    local found, httpGet = pcall(function()
        return target.HttpGet
    end)
    if found and type(httpGet) == "function" then
        return function(url: string): number?
            -- called as a method: some executors only route HttpGet through __namecall
            local ok, err = pcall(function()
                return target:HttpGet(url)
            end)
            if not ok and string.find(tostring(err), "404", 1, true) then
                return 404
            end
            return nil
        end
    end

    return nil
end

local function liveEnvironment(): Environment
    local isStudio = runtime.runService:IsStudio()
    return {
        isStudio = isStudio,
        get = if isStudio then nil else heartbeat.transport(),
        -- deferred rather than spawned: spawning runs the first ping right away, and a request
        -- that blocks without yielding would hold CreateWindow up for a whole round trip
        spawn = function(callback)
            task.defer(callback)
        end,
        wait = function(seconds)
            task.wait(seconds)
        end,
    }
end

-- Ping `target` now and every `heartbeat.period` seconds after, for as long as `alive` says so.
-- Returns true when the loop started, false when the link was bad or there is nowhere to send
-- (Studio, or no HTTP at all). A bad link warns; Studio stays quiet, since playtests aren't runs.
function heartbeat.start(target: any, alive: () -> boolean, environment: Environment?): boolean
    local url, reason = heartbeat.resolve(target)
    if not url then
        log.warn(`Rayfield: {reason}.`)
        return false
    end

    local env = environment or liveEnvironment()
    if env.isStudio then
        return false
    end

    local get = env.get
    if not get then
        log.warn("Rayfield: heartbeat couldn't find an HTTP function in this executor, so no pings will be sent.")
        return false
    end

    local send = get :: (url: string) -> number?
    local resolved = url :: string
    local owner = {}
    owners[resolved] = owner
    env.spawn(function()
        local notFound = 0
        while owners[resolved] == owner and alive() do
            local ok, status = pcall(send, resolved)
            -- a 404 is Sentivel saying the token names no heartbeat (deleted, rotated, or mistyped
            -- into another valid-looking one). once it keeps saying so, stop asking
            notFound = if ok and status == 404 then notFound + 1 else 0
            if notFound >= heartbeat.giveUpAfter then
                log.warn(
                    "Rayfield: Sentivel doesn't recognise this heartbeat, so pings have stopped. Check the ping URL."
                )
                break
            end
            env.wait(heartbeat.period)
        end
        if owners[resolved] == owner then
            owners[resolved] = nil
        end
    end)
    return true
end

return heartbeat
