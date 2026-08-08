
util.AddNetworkString("ME_MM_Counts")
util.AddNetworkString("ME_MM_Found")
util.AddNetworkString("ME_MM_Request")

ME.MM = ME.MM or {}
ME.MM.Modes = {}
for _, m in ipairs(ME.Modes or {}) do ME.MM.Modes[#ME.MM.Modes + 1] = m.key end
ME.MM.Queues     = ME.MM.Queues or {}
ME.MM.PlayerMode = ME.MM.PlayerMode or {}
for _, m in ipairs(ME.MM.Modes) do ME.MM.Queues[m] = ME.MM.Queues[m] or {} end

ME.MM.Config = ME.MM.Config or {
    Countdown = 3,
}

local function minFor(mode) return ME.ModeMinPlayers(mode) end

local function throttle(ply, key, cd)
    if not IsValid(ply) then return false end
    ply.MEMMNext = ply.MEMMNext or {}
    local now = CurTime()
    if (ply.MEMMNext[key] or 0) > now then return true end
    ply.MEMMNext[key] = now + cd
    return false
end

local function isValidMode(m)
    return ME.ModeEnabled and ME.ModeEnabled(m)
end

local function prune(mode)
    local q = ME.MM.Queues[mode]
    if not q then return 0 end
    for i = #q, 1, -1 do if not IsValid(q[i]) then table.remove(q, i) end end
    return #q
end

local function indexIn(mode, ply)
    local q = ME.MM.Queues[mode]
    if not q then return nil end
    for i, p in ipairs(q) do if p == ply then return i end end
    return nil
end

local function countsTable()
    local t = {}
    for _, m in ipairs(ME.MM.Modes) do t[m] = prune(m) end
    return t
end

local function broadcastCounts()
    net.Start("ME_MM_Counts")
    net.WriteString(util.TableToJSON(countsTable()))
    net.Broadcast()
end

local function sendCountsTo(ply)
    if not IsValid(ply) then return end
    net.Start("ME_MM_Counts")
    net.WriteString(util.TableToJSON(countsTable()))
    net.Send(ply)
end

local function maxPlayers() return (ME.Config and ME.Config.MaxFactions) or 6 end

local function cancelCountdown(mode)
    if timer.Exists("ME_MM_CD_" .. mode) then timer.Remove("ME_MM_CD_" .. mode) end
end

local function sessionBusy() return ME.Session and ME.Session.active end

local function maybeLaunch(mode)
    if sessionBusy() then return end
    if prune(mode) >= minFor(mode) then
        if not timer.Exists("ME_MM_CD_" .. mode) then
            timer.Create("ME_MM_CD_" .. mode, ME.MM.Config.Countdown, 1, function()
                ME.MM.Launch(mode)
            end)
        end
    end
end

function ME.MM.Add(ply, mode)
    if not IsValid(ply) then return end
    if not isValidMode(mode) then mode = "casual" end
    if not ME.MM.Queues[mode] then return end
    if ME.ReconnectForfeitIfQueued then ME.ReconnectForfeitIfQueued(ply) end
    ME.MM.Remove(ply)
    table.insert(ME.MM.Queues[mode], ply)
    ME.MM.PlayerMode[ply] = mode
    broadcastCounts()
    maybeLaunch(mode)
end

function ME.MM.Remove(ply)
    local mode = ME.MM.PlayerMode[ply]
    if not mode then return end
    local i = indexIn(mode, ply)
    if i then table.remove(ME.MM.Queues[mode], i) end
    ME.MM.PlayerMode[ply] = nil
    broadcastCounts()
    if prune(mode) < minFor(mode) then cancelCountdown(mode) end
end

function ME.MM.Launch(mode)
    cancelCountdown(mode)
    if ME.MatchActive or sessionBusy() then return end
    if not isValidMode(mode) then return end
    if prune(mode) < minFor(mode) then return end

    local q   = ME.MM.Queues[mode]
    local cap = maxPlayers()
    local take = math.min(cap, #q)

    ME.Used = {}
    local launched = {}
    for i = 1, take do
        local p = q[i]
        if IsValid(p) then
            ME.Used[i] = p
            p:SetTeam(i)
            launched[#launched + 1] = p
            ME.MM.PlayerMode[p] = nil
        end
    end
    for _ = 1, take do table.remove(q, 1) end

    ME.MM.CurrentMode = mode
    if ME.Session then ME.Session.Begin("mm", mode) else ME.StartMatch() end

    for _, p in ipairs(launched) do
        if IsValid(p) then
            net.Start("ME_MM_Found")
            net.WriteString(mode)
            net.Send(p)
        end
    end
    broadcastCounts()
end

function ME.MM.LaunchWith(mode, players)
    if ME.MatchActive or sessionBusy() then return false end
    if not isValidMode(mode) then return false end
    local cap = maxPlayers()
    ME.Used = {}
    local launched = {}
    for _, p in ipairs(players) do
        if #launched >= cap then break end
        if IsValid(p) then
            if ME.ReconnectForfeitIfQueued then ME.ReconnectForfeitIfQueued(p) end
            local i = #launched + 1
            ME.Used[i] = p
            p:SetTeam(i)
            launched[#launched + 1] = p
            ME.MM.Remove(p)
        end
    end
    if #launched == 0 then return false end

    ME.MM.CurrentMode = mode
    if ME.Session then ME.Session.Begin("mm", mode) else ME.StartMatch() end

    for _, p in ipairs(launched) do
        if IsValid(p) then net.Start("ME_MM_Found"); net.WriteString(mode); net.Send(p) end
    end
    broadcastCounts()
    return true
end

function ME.MM.OnMatchEnded()
    for _, m in ipairs(ME.MM.Modes) do maybeLaunch(m) end
end

net.Receive("ME_MM_Request", function(_, ply)
    if throttle(ply, "request", 0.4) then return end
    sendCountsTo(ply)
end)

hook.Add("PlayerDisconnected", "ME_MM_Cleanup", function(ply)
    ME.MM.Remove(ply)
end)

