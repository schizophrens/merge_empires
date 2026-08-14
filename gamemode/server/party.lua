
util.AddNetworkString("ME_Party_State")
util.AddNetworkString("ME_Party_Join")
util.AddNetworkString("ME_Party_Leave")
util.AddNetworkString("ME_Party_SetMode")
util.AddNetworkString("ME_Party_Queue")
util.AddNetworkString("ME_Party_Toast")
util.AddNetworkString("ME_Party_Request")
util.AddNetworkString("ME_Party_Players")
util.AddNetworkString("ME_Party_Invite")
util.AddNetworkString("ME_Party_InviteReq")
util.AddNetworkString("ME_Party_InviteAnswer")
util.AddNetworkString("ME_Party_Kick")

ME.Party = ME.Party or {}
ME.Party.Lobbies  = ME.Party.Lobbies or {}
ME.Party.ByPlayer = ME.Party.ByPlayer or {}

local MAX_MEMBERS = 6
local CODE_LEN = 5
local CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

local function randCode()
    local s = ""
    for _ = 1, CODE_LEN do
        local i = math.random(#CODE_CHARS)
        s = s .. string.sub(CODE_CHARS, i, i)
    end
    return s
end

local function genCode()
    for _ = 1, 500 do
        local c = randCode()
        if not ME.Party.Lobbies[c] then return c end
    end
    return randCode()
end

local function sanitizeCode(code)
    code = string.upper(string.Trim(tostring(code or "")))
    code = string.gsub(code, "[^A-Z0-9]", "")
    return string.sub(code, 1, CODE_LEN)
end

local function throttle(ply, key, cd)
    if not IsValid(ply) then return true end
    ply.MEPartyNext = ply.MEPartyNext or {}
    local now = CurTime()
    if (ply.MEPartyNext[key] or 0) > now then return true end
    ply.MEPartyNext[key] = now + cd
    return false
end

local function nameOf(ply) return (IsValid(ply) and (ply:Nick() or "Player")) or "Player" end

local function lobbyOf(ply)
    local c = ME.Party.ByPlayer[ply]
    return c and ME.Party.Lobbies[c]
end

local function pruneLobby(lobby)
    for i = #lobby.members, 1, -1 do
        if not IsValid(lobby.members[i]) then table.remove(lobby.members, i) end
    end
end

local function isValidMode(mode)
    return ME.ModeEnabled and ME.ModeEnabled(mode)
end

local function buildState(lobby, forPly)
    local members = {}
    for _, p in ipairs(lobby.members) do
        if IsValid(p) then
            members[#members + 1] = { steamid = p:SteamID(), sid64 = p:SteamID64() or "", name = nameOf(p) }
        end
    end
    for _, f in ipairs(lobby.fakes or {}) do
        members[#members + 1] = { steamid = f.steamid, sid64 = f.sid64 or "", name = f.name }
    end
    return util.TableToJSON({
        code    = lobby.code,
        leader  = IsValid(lobby.leader) and lobby.leader:SteamID() or "",
        mode    = lobby.mode or "casual",
        queuing = lobby.queuing or false,
        you     = IsValid(forPly) and forPly:SteamID() or "",
        members = members,
    })
end

local function syncLobby(lobby)
    if not lobby then return end
    pruneLobby(lobby)
    if #lobby.members == 0 then
        ME.Party.Lobbies[lobby.code] = nil
        return
    end
    if not IsValid(lobby.leader) or ME.Party.ByPlayer[lobby.leader] ~= lobby.code then
        lobby.leader = lobby.members[1]
    end
    for _, p in ipairs(lobby.members) do
        if IsValid(p) then
            net.Start("ME_Party_State")
            net.WriteString(buildState(lobby, p))
            net.Send(p)
        end
    end
end
ME.Party.Sync = syncLobby
ME.Party.GetLobby = lobbyOf

local function toast(ply, msg)
    if not IsValid(ply) then return end
    net.Start("ME_Party_Toast")
    net.WriteString(msg or "")
    net.Send(ply)
end
ME.Party.Toast = toast

local function detach(ply)
    local lobby = lobbyOf(ply)
    if not lobby then return nil end
    for i = #lobby.members, 1, -1 do
        if lobby.members[i] == ply then table.remove(lobby.members, i) end
    end
    ME.Party.ByPlayer[ply] = nil
    if ME.MM and ME.MM.Remove then ME.MM.Remove(ply) end
    return lobby
end

function ME.Party.CreateSolo(ply)
    if not IsValid(ply) then return end
    local old = detach(ply)
    if old then syncLobby(old) end
    local code = genCode()
    local lobby = { code = code, leader = ply, members = { ply }, mode = "casual", queuing = false }
    ME.Party.Lobbies[code] = lobby
    ME.Party.ByPlayer[ply] = code
    syncLobby(lobby)
end

function ME.Party.Join(ply, code)
    if not IsValid(ply) then return end
    code = sanitizeCode(code)
    if #code < 3 then toast(ply, "Invalid lobby code.") return end
    local lobby = ME.Party.Lobbies[code]
    if not lobby then toast(ply, "Invalid lobby code.") return end
    pruneLobby(lobby)
    if #lobby.members >= MAX_MEMBERS then toast(ply, "That lobby is full (6 max).") return end
    if lobbyOf(ply) == lobby then return end

    local old = detach(ply)
    table.insert(lobby.members, ply)
    ME.Party.ByPlayer[ply] = code
    if lobby.queuing and ME.MM and ME.MM.Add then ME.MM.Add(ply, lobby.mode) end
    if old then syncLobby(old) end
    syncLobby(lobby)
end

function ME.Party.Leave(ply)
    if not IsValid(ply) then return end
    local old = detach(ply)
    if old then syncLobby(old) end
    ME.Party.CreateSolo(ply)
end

function ME.Party.SetMode(ply, mode)
    local lobby = lobbyOf(ply)
    if not lobby or lobby.leader ~= ply then return end
    mode = string.lower(string.Trim(tostring(mode or "casual")))
    if not isValidMode(mode) then
        toast(ply, "This mode is coming soon.")
        mode = "casual"
    end
    lobby.mode = mode
    syncLobby(lobby)
end

function ME.Party.SetQueue(ply, on)
    local lobby = lobbyOf(ply)
    if not lobby or lobby.leader ~= ply then return end
    lobby.queuing = on and true or false
    if lobby.queuing then

        if ME.MM and ME.MM.LaunchWith and #lobby.members >= ME.ModeMinPlayers(lobby.mode) then
            local members = {}
            for _, p in ipairs(lobby.members) do if IsValid(p) then members[#members + 1] = p end end
            if ME.MM.LaunchWith(lobby.mode, members) then
                lobby.queuing = false
                syncLobby(lobby)
                return
            end
        end

        for _, p in ipairs(lobby.members) do
            if IsValid(p) and ME.MM and ME.MM.Add then ME.MM.Add(p, lobby.mode) end
        end
    else
        for _, p in ipairs(lobby.members) do
            if IsValid(p) and ME.MM and ME.MM.Remove then ME.MM.Remove(p) end
        end
    end
    syncLobby(lobby)
end

function ME.Party.StopQueue(ply)
    local lobby = lobbyOf(ply)
    if not lobby or not lobby.queuing then return end
    lobby.queuing = false
    syncLobby(lobby)
end

local function statusOf(ply)
    if ME.IsInMenu and ME.IsInMenu(ply) then return "In lobby" end
    return "In game"
end

local function buildPlayersJSON(forPly)
    local list = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p ~= forPly and not p:IsBot() then
            list[#list + 1] = { steamid = p:SteamID(), sid64 = p:SteamID64() or "", name = nameOf(p), status = statusOf(p) }
        end
    end
    return util.TableToJSON(list)
end

local function sendPlayers(ply)
    if not IsValid(ply) then return end
    net.Start("ME_Party_Players")
    net.WriteString(buildPlayersJSON(ply))
    net.Send(ply)
end

local function broadcastPlayers()
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and not p:IsBot() then sendPlayers(p) end
    end
end

local INVITE_COOLDOWN = 30
local INVITE_EXPIRE   = 30
local inviteCD = {}
ME.Party.Invites = ME.Party.Invites or {}

function ME.Party.Invite(inviter, sid)
    if not IsValid(inviter) then return end
    local lobby = lobbyOf(inviter)
    if not lobby or lobby.leader ~= inviter then return end
    if #lobby.members >= MAX_MEMBERS then toast(inviter, "Lobby full (6 max).") return end
    sid = string.Trim(tostring(sid or ""))
    local target
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:SteamID() == sid then target = p break end
    end
    if not IsValid(target) or target == inviter then return end
    if ME.IsInMenu and not ME.IsInMenu(target) then toast(inviter, nameOf(target) .. " is already in a match.") return end

    local key = inviter:SteamID() .. ">" .. sid
    local now = CurTime()
    if (inviteCD[key] or 0) > now then
        toast(inviter, "Wait " .. math.ceil(inviteCD[key] - now) .. "s before inviting " .. nameOf(target) .. " again.")
        return
    end
    inviteCD[key] = now + INVITE_COOLDOWN

    ME.Party.Invites[target:SteamID()] = { code = lobby.code, from = nameOf(inviter), expire = now + INVITE_EXPIRE }

    net.Start("ME_Party_InviteReq")
    net.WriteString(inviter:SteamID())
    net.WriteString(nameOf(inviter))
    net.Send(target)

    toast(inviter, "Invite sent to " .. nameOf(target) .. ".")
end

function ME.Party.AnswerInvite(ply, accept)
    if not IsValid(ply) then return end
    local inv = ME.Party.Invites[ply:SteamID()]
    ME.Party.Invites[ply:SteamID()] = nil
    if not inv then return end
    if not accept then return end
    if inv.expire < CurTime() then toast(ply, "That invite has expired.") return end
    ME.Party.Join(ply, inv.code)
end

function ME.Party.Kick(leader, sid64)
    if not IsValid(leader) then return end
    local lobby = lobbyOf(leader)
    if not lobby or lobby.leader ~= leader then return end
    sid64 = string.Trim(tostring(sid64 or ""))
    if sid64 == "" or sid64 == "0" then return end
    if leader:SteamID64() == sid64 then return end

    for _, p in ipairs(lobby.members) do
        if IsValid(p) and p:SteamID64() == sid64 then
            detach(p)
            toast(p, "You were removed from the lobby.")
            ME.Party.CreateSolo(p)
            syncLobby(lobby)
            return
        end
    end

    if lobby.fakes then
        for i = #lobby.fakes, 1, -1 do
            if lobby.fakes[i].sid64 == sid64 then table.remove(lobby.fakes, i); syncLobby(lobby); return end
        end
    end
end

net.Receive("ME_Party_Kick", function(_, ply)
    local sid = net.ReadString()
    if throttle(ply, "kick", 0.3) then return end
    ME.Party.Kick(ply, sid)
end)

net.Receive("ME_Party_Join", function(_, ply)
    local code = net.ReadString()
    if throttle(ply, "join", 0.5) then return end
    ME.Party.Join(ply, code)
end)

net.Receive("ME_Party_Invite", function(_, ply)
    local sid = net.ReadString()
    if throttle(ply, "invite", 1) then return end
    ME.Party.Invite(ply, sid)
end)

net.Receive("ME_Party_InviteAnswer", function(_, ply)
    local accept = net.ReadBool()
    if throttle(ply, "inviteanswer", 0.3) then return end
    ME.Party.AnswerInvite(ply, accept)
end)

net.Receive("ME_Party_Leave", function(_, ply)
    if throttle(ply, "leave", 0.5) then return end
    ME.Party.Leave(ply)
end)

net.Receive("ME_Party_SetMode", function(_, ply)
    local mode = net.ReadString()
    if throttle(ply, "setmode", 0.2) then return end
    ME.Party.SetMode(ply, mode)
end)

net.Receive("ME_Party_Queue", function(_, ply)
    local on = net.ReadBool()
    if throttle(ply, "queue", 0.4) then return end
    ME.Party.SetQueue(ply, on)
end)

net.Receive("ME_Party_Request", function(_, ply)
    if throttle(ply, "request", 0.4) then return end
    local lobby = lobbyOf(ply)
    if lobby then syncLobby(lobby) else ME.Party.CreateSolo(ply) end
    sendPlayers(ply)
end)

hook.Add("PlayerDisconnected", "ME_Party_Cleanup", function(ply)
    local old = detach(ply)
    if old then syncLobby(old) end
    timer.Simple(0.1, broadcastPlayers)
end)

hook.Add("PlayerInitialSpawn", "ME_Party_PlayerJoin", function()
    timer.Simple(3, broadcastPlayers)
end)

