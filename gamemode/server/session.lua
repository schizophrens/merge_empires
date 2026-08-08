
util.AddNetworkString("ME_Custom_Code")
util.AddNetworkString("ME_Custom_Create")
util.AddNetworkString("ME_Custom_Join")
util.AddNetworkString("ME_Custom_Kicked")
util.AddNetworkString("ME_SpectateEnter")
util.AddNetworkString("ME_HostKick")

ME.Session = ME.Session or {}
local SS = ME.Session

SS.active     = SS.active     or false
SS.mode       = SS.mode       or "casual"
SS.kind       = SS.kind       or "mm"
SS.code       = SS.code       or nil
SS.host       = SS.host       or nil
SS.players    = SS.players    or {}
SS.spectators = SS.spectators or {}

local CODE_LEN   = 5
local CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local function randCode()
    local s = ""
    for _ = 1, CODE_LEN do
        local i = math.random(#CODE_CHARS)
        s = s .. string.sub(CODE_CHARS, i, i)
    end
    return s
end

local function sanitizeCode(code)
    code = string.upper(string.Trim(tostring(code or "")))
    return string.gsub(code, "[^A-Z0-9]", "")
end

function SS.IsCustom() return SS.active and SS.kind == "custom" end

function SS.Recipients()
    local t = {}
    for ply in pairs(SS.players) do if IsValid(ply) then t[#t + 1] = ply end end
    for ply in pairs(SS.spectators) do if IsValid(ply) then t[#t + 1] = ply end end
    return t
end

function SS.SpectatorCount()
    local n = 0
    for ply in pairs(SS.spectators) do if IsValid(ply) then n = n + 1 end end
    return n
end

local function pushSpecCount()
    SetGlobalInt("ME_SpecCount", SS.SpectatorCount())
end

function SS.HumanCount()
    local n = 0
    for ply in pairs(SS.players) do if IsValid(ply) and not ply:IsBot() then n = n + 1 end end
    return n
end

local function firstFreeFaction()
    for i = 1, ME.Config.MaxFactions do
        if not IsValid(ME.Used and ME.Used[i]) then return i end
    end
    return nil
end

function SS.Begin(kind, mode, host, code)
    SS.active     = true
    SS.kind       = kind or "mm"
    SS.mode       = mode or "casual"
    SS.host       = IsValid(host) and host or nil
    SS.code       = code
    SS.players    = {}
    SS.spectators = {}

    ME.MM = ME.MM or {}
    ME.MM.CurrentMode = SS.mode

    ME.StartMatch()

    for i = 1, ME.Config.MaxFactions do
        local p = ME.Used and ME.Used[i]
        if IsValid(p) then SS.players[p] = true end
    end

    SetGlobalBool("ME_CustomMatch", SS.kind == "custom")
    SetGlobalString("ME_MatchCode", SS.code or "")
    pushSpecCount()
end

function SS.RemovePlayer(ply)
    if not IsValid(ply) then return end
    SS.players[ply]    = nil
    SS.spectators[ply] = nil
    if ply == SS.host then ply:SetNWBool("ME_IsHost", false) end
    for i = 1, ME.Config.MaxFactions do
        if ME.Used and ME.Used[i] == ply then ME.Used[i] = nil end
    end
    pushSpecCount()
    SS.CheckEmpty()
end

function SS.AddSpectator(ply)
    if not IsValid(ply) then return end
    SS.players[ply] = nil
    SS.spectators[ply] = true
    pushSpecCount()
end

function SS.CheckEmpty()
    if not SS.active then return end
    if SS.HumanCount() > 0 then return end
    if SS.SpectatorCount() > 0 then return end
    if ME.HasPendingReconnect and ME.HasPendingReconnect() then return end
    SS.End()
end

function SS.End()
    if not SS.active then return end
    SS.active = false
    ME.MatchActive = false

    for ply in pairs(SS.players) do if IsValid(ply) then if ME.ReturnToMenu then ME.ReturnToMenu(ply) end ply:SetNWBool("ME_IsHost", false) end end
    for ply in pairs(SS.spectators) do if IsValid(ply) and ME.ReturnToMenu then ME.ReturnToMenu(ply) end end
    if IsValid(SS.host) then SS.host:SetNWBool("ME_IsHost", false) end

    SS.players, SS.spectators = {}, {}
    SS.host, SS.code, SS.kind = nil, nil, "mm"
    ME.Used = {}
    if ME.ClearAllReconnects then ME.ClearAllReconnects() end

    if ME.ClearArena then ME.ClearArena() end
    SetGlobalInt("ME_ActiveMatches", 0)
    SetGlobalInt("ME_MatchPhase", 0)
    SetGlobalBool("ME_CustomMatch", false)
    SetGlobalString("ME_MatchCode", "")
    SetGlobalInt("ME_SpecCount", 0)

    if ME.MM and ME.MM.OnMatchEnded then ME.MM.OnMatchEnded() end
end

function SS.CreateCustom(host, mode)
    if not IsValid(host) then return end
    if SS.active then

        if ME.Party and ME.Party.Toast then ME.Party.Toast(host, "A match is already running. Try again shortly.") end
        return
    end
    mode = string.lower(string.Trim(tostring(mode or "casual")))
    if not (ME.ModeEnabled and ME.ModeEnabled(mode)) then mode = "casual" end

    if ME.Party and ME.Party.Sync then
        local lobby = ME.Party.GetLobby and ME.Party.GetLobby(host)
        if lobby then lobby.queuing = false end
    end
    ME.Used = ME.Used or {}
    host:SetTeam(1)
    ME.Used[1] = host

    local code = randCode()
    SS.Begin("custom", mode, host, code)
    host:SetNWBool("ME_IsHost", true)

    net.Start("ME_MM_Found"); net.WriteString(mode); net.Send(host)

    timer.Simple(0.2, function()
        if not IsValid(host) then return end
        net.Start("ME_Custom_Code")
        net.WriteString(code)
        net.WriteFloat(0)
        net.Send(host)
    end)
end

local function syncMatchTo(ply)
    if not IsValid(ply) then return end
    if ME.SendBoard then ME.SendBoard(ply) end
    if ME.SendRoster then ME.SendRoster(ply) end
    if ME.NetBuilding then
        for _, e in ipairs(ents.FindByClass("ent_me_building")) do ME.NetBuilding(e, ply) end
    end
end

function SS.JoinCustom(ply, code)
    if not IsValid(ply) then return end
    code = sanitizeCode(code)
    if not SS.IsCustom() or code == "" or code ~= SS.code then
        if ME.Party then ME.Party.Toast(ply, "No custom match with that code.") end
        return
    end
    if SS.players[ply] then return end
    local f = firstFreeFaction()
    if not f then
        if ME.Party then ME.Party.Toast(ply, "This match is full (6 players).") end
        return
    end
    ME.Used[f] = ply
    ply:SetTeam(f)
    SS.players[ply]    = true
    SS.spectators[ply] = nil
    ply._meDefeated    = nil

    if ME.Roster then
        ME.Roster[f] = { sid = ply:SteamID64() or "", name = ply:Nick() or "", connected = true, rank = ply.MERank or 0 }
    end
    if ME.SendRoster then ME.SendRoster() end
    ME.SetMoney(ply, ME.Config.StartMoney)
    ply:SetNWInt("ME_Income", ME.Config.BaseIncome)
    ply:SetNWInt("ME_Units", 0)
    ply:SetNWInt("ME_UnitMax", (ME.Config and ME.Config.UnitMax) or 10)

    syncMatchTo(ply)
    net.Start("ME_MM_Found"); net.WriteString(SS.mode); net.Send(ply)
    pushSpecCount()
end

function SS.SpectateCustom(ply, code)
    if not IsValid(ply) then return false end
    code = sanitizeCode(code)
    if not SS.IsCustom() or code == "" or code ~= SS.code then return false end
    SS.AddSpectator(ply)
    ply._meDefeated = nil

    if ME.ForceExitIntroState then ME.ForceExitIntroState(ply) end
    ply:SetTeam(ME.TEAM_SPECTATOR or 100)
    ply:Spectate(OBS_MODE_ROAMING)
    ply:SpectateEntity(NULL)
    local c = ME.GetSpawnFor and ME.GetSpawnFor(1)
    timer.Simple(0.1, function()
        if IsValid(ply) and c then ply:SetPos(c + Vector(0, 0, 1400)) end
    end)
    syncMatchTo(ply)
    net.Start("ME_SpectateEnter"); net.Send(ply)
    return true
end

function SS.HostKick(host, faction)
    if not IsValid(host) or not SS.IsCustom() or SS.host ~= host then return end
    faction = tonumber(faction) or 0
    if faction < 1 or faction > ME.Config.MaxFactions then return end
    local target = ME.Used and ME.Used[faction]
    if not IsValid(target) or target == host then return end

    net.Start("ME_Custom_Kicked"); net.Send(target)
    target._meDefeated = nil
    if ME.RosterMarkGone then ME.RosterMarkGone(target) end
    if ME.ReturnToMenu then ME.ReturnToMenu(target) end
    SS.RemovePlayer(target)
end

net.Receive("ME_HostKick", function(_, ply)
    ply.MEKickNext = ply.MEKickNext or 0
    if ply.MEKickNext > CurTime() then return end
    ply.MEKickNext = CurTime() + 0.3
    SS.HostKick(ply, net.ReadUInt(3))
end)

net.Receive("ME_Custom_Create", function(_, ply)
    ply.MECustomNext = ply.MECustomNext or 0
    if ply.MECustomNext > CurTime() then return end
    ply.MECustomNext = CurTime() + 1
    SS.CreateCustom(ply, net.ReadString())
end)

net.Receive("ME_Custom_Join", function(_, ply)
    ply.MECustomNext = ply.MECustomNext or 0
    if ply.MECustomNext > CurTime() then return end
    ply.MECustomNext = CurTime() + 0.4
    SS.JoinCustom(ply, net.ReadString())
end)

hook.Add("MEMenu_SpectateCode", "ME_Session_Spectate", function(ply, code)
    return SS.SpectateCustom(ply, code)
end)

hook.Add("PlayerDisconnected", "ME_Session_Cleanup", function(ply)
    if not SS.active then return end
    if SS.players[ply] or SS.spectators[ply] then
        if ME.Reconnect_OnDisconnect then ME.Reconnect_OnDisconnect(ply) end
        SS.players[ply], SS.spectators[ply] = nil, nil
        for i = 1, ME.Config.MaxFactions do
            if ME.Used and ME.Used[i] == ply then ME.Used[i] = nil end
        end
        pushSpecCount()
        timer.Simple(0, function() SS.CheckEmpty() end)
    end
end)

