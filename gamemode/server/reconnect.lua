
util.AddNetworkString("ME_CanRejoin")
util.AddNetworkString("ME_Rejoin")

ME.Reconnect = ME.Reconnect or {}
local GRACE = 120

function ME.TeamLabel(f)
    local fac  = ME.GetFaction and ME.GetFaction(f)
    local name = (fac and fac.name and fac.name ~= "" and string.upper(fac.name)) or ("FACTION " .. tostring(f))
    return name .. " TEAM"
end
function ME.TeamColor(f)
    return (ME.FactionColor and ME.FactionColor(f)) or Color(210, 214, 220)
end
local teamLabel, teamColor = ME.TeamLabel, ME.TeamColor
local function announceDisconnect(f)
    if ME.ChatSystem then ME.ChatSystem(teamLabel(f) .. " has disconnected. Reconnect within 2 minutes or be disqualified.", teamColor(f)) end
end
local function announceReconnect(f)
    if ME.ChatSystem then ME.ChatSystem(teamLabel(f) .. " has reconnected.", teamColor(f)) end
end
local function announceDisqualified(f)
    if ME.ChatSystem then ME.ChatSystem(teamLabel(f) .. " has been disqualified.", teamColor(f)) end
end

local function forfeitFaction(f)
    if not ME.MatchActive then return end
    local core = ME.Cores and ME.Cores[f]
    if IsValid(core) and not core._meDead then
        core._meDead     = true
        core._lastAttFac = 0
        if core.MEMeltdown then core:MEMeltdown() end
    end
end

function ME.HasPendingReconnect()
    return next(ME.Reconnect) ~= nil
end

local function tellClient(sid, canRejoin, secs)
    for _, p in ipairs(player.GetHumans()) do
        if p:SteamID64() == sid then
            net.Start("ME_CanRejoin")
            net.WriteBool(canRejoin and true or false)
            net.WriteFloat(math.max(0, secs or 0))
            net.Send(p)
            return
        end
    end
end

function ME.ClearReconnect(sid, forfeit)
    local e = ME.Reconnect[sid]
    if not e then return end
    ME.Reconnect[sid] = nil
    timer.Remove("ME_Reconnect_" .. sid)
    tellClient(sid, false, 0)
    if forfeit then forfeitFaction(e.faction) end
end

function ME.ClearReconnectForFaction(f)
    for sid, e in pairs(ME.Reconnect) do
        if e.faction == f then ME.ClearReconnect(sid, false) end
    end
end

function ME.ClearAllReconnects()
    for sid in pairs(ME.Reconnect) do
        timer.Remove("ME_Reconnect_" .. sid)
        tellClient(sid, false, 0)
    end
    ME.Reconnect = {}
end

local function graceExpired(sid)
    local e = ME.Reconnect[sid]
    if e and e.faction and ME.MatchActive then announceDisqualified(e.faction) end
    ME.ClearReconnect(sid, true)
    if ME.Session and ME.Session.CheckEmpty then ME.Session.CheckEmpty() end
end

function ME.Reconnect_OnDisconnect(ply)
    if not IsValid(ply) then return false end
    local SS = ME.Session
    if not (SS and SS.active and SS.kind == "mm") then return false end
    if GetGlobalInt("ME_MatchPhase", 0) < 1 then return false end
    if not SS.players[ply] then return false end
    local f = ply:Team()
    if f < 1 or f > ME.Config.MaxFactions then return false end
    if not IsValid(ME.Cores and ME.Cores[f]) then return false end
    local sid = ply:SteamID64()
    if not sid or sid == "0" then return false end

    ME.Reconnect[sid] = { faction = f, mode = SS.mode, expire = CurTime() + GRACE, money = ME.GetMoney and ME.GetMoney(ply) or nil }

    if ME.Roster and ME.Roster[f] then ME.Roster[f].connected = false; if ME.SendRoster then ME.SendRoster() end end
    timer.Create("ME_Reconnect_" .. sid, GRACE, 1, function() graceExpired(sid) end)
    announceDisconnect(f)
    return true
end

function ME.Reconnect_OnLeave(ply)
    if not IsValid(ply) then return false end
    local SS = ME.Session
    if not (SS and SS.active and SS.kind == "mm") then return false end
    if GetGlobalInt("ME_MatchPhase", 0) < 1 then return false end
    local f = ply:Team()
    if f < 1 or f > ME.Config.MaxFactions then return false end
    if not IsValid(ME.Cores and ME.Cores[f]) then return false end
    local sid = ply:SteamID64()
    if not sid or sid == "0" then return false end

    ME.Reconnect[sid] = { faction = f, mode = SS.mode, expire = CurTime() + GRACE, money = ME.GetMoney and ME.GetMoney(ply) or nil }
    if ME.Roster and ME.Roster[f] then ME.Roster[f].connected = false; if ME.SendRoster then ME.SendRoster() end end
    timer.Create("ME_Reconnect_" .. sid, GRACE, 1, function() graceExpired(sid) end)
    tellClient(sid, true, GRACE)
    timer.Simple(2, function() if ME.Reconnect[sid] then tellClient(sid, true, GRACE) end end)
    announceDisconnect(f)
    return true
end

function ME.ReconnectForfeitIfQueued(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    if sid and ME.Reconnect[sid] then ME.ClearReconnect(sid, true) end
end

net.Receive("ME_Rejoin", function(_, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    local e   = sid and ME.Reconnect[sid]
    if not e then return end
    local SS = ME.Session
    local core = ME.Cores and ME.Cores[e.faction]
    if not (SS and SS.active) or not IsValid(core) then ME.ClearReconnect(sid, false); return end

    ME.Reconnect[sid] = nil
    timer.Remove("ME_Reconnect_" .. sid)

    ME.Used = ME.Used or {}
    ME.Used[e.faction] = ply
    ply:SetTeam(e.faction)
    SS.players[ply] = true
    ply._meDefeated = nil
    if ME.Roster and ME.Roster[e.faction] then ME.Roster[e.faction].connected = true end
    if ME.SendRoster then ME.SendRoster() end

    if ME.SendBoard then ME.SendBoard(ply) end
    if ME.SendRoster then ME.SendRoster(ply) end
    if ME.NetBuilding then
        for _, b in ipairs(ents.FindByClass("ent_me_building")) do ME.NetBuilding(b, ply) end
    end
    ME.SetMoney(ply, e.money or ME.Config.StartMoney)
    net.Start("ME_MM_Found"); net.WriteString(e.mode); net.Send(ply)
    announceReconnect(e.faction)
end)

hook.Add("PlayerInitialSpawn", "ME_Reconnect_Offer", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    timer.Simple(3.5, function()
        if not IsValid(ply) then return end
        local e = sid and ME.Reconnect[sid]
        if not e then return end
        if not (ME.Session and ME.Session.active and IsValid(ME.Cores and ME.Cores[e.faction])) then
            ME.ClearReconnect(sid, false); return
        end
        tellClient(sid, true, e.expire - CurTime())
    end)
end)

