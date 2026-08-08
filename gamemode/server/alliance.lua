ME = ME or {}

ME.Ally         = ME.Ally or {}
ME.AllyBreakEnd = ME.AllyBreakEnd or {}
ME.AllyInvite   = ME.AllyInvite or {}

local INVITE_WINDOW = 15 * 60
local INVITE_TTL    = 10
local BREAK_DELAY   = 30

util.AddNetworkString("ME_AllyInvite")
util.AddNetworkString("ME_AllyRespond")
util.AddNetworkString("ME_AllyBreak")
util.AddNetworkString("ME_AllyRequest")
util.AddNetworkString("ME_AllyPing")

local function facPlayer(f)
	local p = ME.Used and ME.Used[f]
	return (IsValid(p) and p:IsPlayer()) and p or nil
end

local function inviteWindowOpen()
	local startAt = GetGlobalFloat("ME_MatchStartAt", 0)
	return startAt > 0 and (CurTime() - startAt) <= INVITE_WINDOW
end

local function syncRoster()
	if ME.SendRoster then ME.SendRoster() end
end

function ME.ClearAlliance(a)
	local b = ME.Ally[a]
	ME.Ally[a] = nil
	ME.AllyBreakEnd[a] = nil
	if b then
		ME.Ally[b] = nil
		ME.AllyBreakEnd[b] = nil
	end
	return b
end

hook.Add("ME_MatchBegan", "ME_AllyReset", function()
	ME.Ally, ME.AllyBreakEnd, ME.AllyInvite = {}, {}, {}
end)

net.Receive("ME_AllyInvite", function(_, ply)
	if not IsValid(ply) or not ME.MatchActive then return end
	local from = ply:Team()
	if from < 1 or from > ME.Config.MaxFactions then return end
	if not inviteWindowOpen() then return end
	local to = net.ReadUInt(3)
	if to < 1 or to > ME.Config.MaxFactions or to == from then return end
	if ME.Ally[from] or ME.Ally[to] then return end
	ply.MEAllyNextInvite = ply.MEAllyNextInvite or 0
	if ply.MEAllyNextInvite > CurTime() then return end
	ply.MEAllyNextInvite = CurTime() + 3
	local tp = facPlayer(to)
	if not tp then return end
	ME.AllyInvite[to] = { from = from, expires = CurTime() + INVITE_TTL }
	net.Start("ME_AllyRequest")
	net.WriteUInt(from, 3)
	net.WriteFloat(INVITE_TTL)
	net.Send(tp)
end)

net.Receive("ME_AllyRespond", function(_, ply)
	if not IsValid(ply) or not ME.MatchActive then return end
	local to     = ply:Team()
	local accept = net.ReadBool()
	local inv    = ME.AllyInvite[to]
	ME.AllyInvite[to] = nil
	if not inv or inv.expires < CurTime() then return end
	if not accept then return end
	local from = inv.from
	if from == to or ME.Ally[from] or ME.Ally[to] then return end
	if not (facPlayer(from) and facPlayer(to)) then return end
	ME.Ally[from] = to
	ME.Ally[to]   = from
	syncRoster()
	if ME.ChatSystem and ME.TeamLabel then
		ME.ChatSystem(ME.TeamLabel(from) .. " and " .. ME.TeamLabel(to) .. " have formed an alliance.", Color(120, 210, 255))
	end
end)

net.Receive("ME_AllyBreak", function(_, ply)
	if not IsValid(ply) or not ME.MatchActive then return end
	local a = ply:Team()
	local b = ME.Ally[a]
	if not b then return end
	if ME.AllyBreakEnd[a] then return end
	local endt = CurTime() + BREAK_DELAY
	ME.AllyBreakEnd[a] = endt
	ME.AllyBreakEnd[b] = endt
	syncRoster()
	if ME.ChatSystem and ME.TeamLabel then
		ME.ChatSystem(ME.TeamLabel(a) .. " has broken the alliance with " .. ME.TeamLabel(b)
			.. " — they become enemies again in " .. BREAK_DELAY .. " seconds.", Color(255, 150, 70))
	end
	timer.Simple(BREAK_DELAY, function()
		if ME.Ally[a] == b and ME.AllyBreakEnd[a] and ME.AllyBreakEnd[a] <= CurTime() + 0.1 then
			ME.ClearAlliance(a)
			syncRoster()
		end
	end)
end)

net.Receive("ME_AllyPing", function(_, ply)
	if not ME.InMatch(ply) then return end
	if ME.Throttle(ply, "ping", 0.5) then return end

	local a = ply:Team()
	local b = ME.Ally[a]
	if not b then return end
	local pos  = net.ReadVector()
	local kind = net.ReadUInt(2)
	if not isvector(pos) then return end
	net.Start("ME_AllyPing")
	net.WriteUInt(a, 3)
	net.WriteVector(pos)
	net.WriteUInt(kind, 2)
	local recips = { ply }
	local bp = facPlayer(b)
	if bp then recips[#recips + 1] = bp end
	net.Send(recips)
end)

hook.Add("PlayerDisconnected", "ME_AllyDisconnect", function(ply)
	if not IsValid(ply) then return end
	local f = ply:Team()
	if f and ME.Ally[f] then
		ME.ClearAlliance(f)
		timer.Simple(0, syncRoster)
	end
end)
