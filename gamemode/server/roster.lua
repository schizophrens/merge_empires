
util.AddNetworkString("ME_Roster")

ME.Roster = ME.Roster or {}

function ME.BuildRoster()
	ME.Roster = {}
	for i = 1, ME.Config.MaxFactions do
		local p = ME.Used and ME.Used[i]
		if IsValid(p) and p:IsPlayer() then
			ME.Roster[i] = {
				sid       = p:SteamID64() or "",
				name      = p:Nick() or "",
				connected = true,
				rank      = p.MERank or 0,
			}
		end
	end
end

function ME.FactionInPlay(i)
	return (ME.Roster and ME.Roster[i]) ~= nil
end

function ME.SendRoster(target)
	local maxF = ME.Config.MaxFactions
	net.Start("ME_Roster")
	net.WriteUInt(maxF, 4)
	for i = 1, maxF do
		local e = ME.Roster[i]
		net.WriteBool(e ~= nil)
		if e then
			net.WriteString(e.sid or "")
			net.WriteString(e.name or "")
			net.WriteBool(e.connected and true or false)
			net.WriteUInt((ME.Ally and ME.Ally[i]) or 0, 3)
			net.WriteBool((ME.AllyBreakEnd and ME.AllyBreakEnd[i] and ME.AllyBreakEnd[i] > CurTime()) and true or false)
			net.WriteUInt(e.rank or 0, 3)
			net.WriteUInt(math.Clamp(e.ping or 0, 0, 2047), 11)
			net.WriteBool(e.spectating and true or false)

			local s = ME.MatchStats and ME.MatchStats[i]
			net.WriteUInt(math.Clamp((s and s.kills) or 0, 0, 4095), 12)
			net.WriteUInt(math.Clamp(math.floor((s and s.damage) or 0), 0, 16777215), 24)
		end
	end
	if target then net.Send(target) else net.Broadcast() end
end

timer.Create("ME_RosterStatsSync", 1, 0, function()
	if ME.MatchActive and ME.SendRoster then ME.SendRoster() end
end)

local function slotOf(ply)
	for i = 1, ME.Config.MaxFactions do if ME.Used and ME.Used[i] == ply then return i end end
	local sid = ply:SteamID64()
	for i, e in pairs(ME.Roster) do if e.sid == sid then return i end end
end
function ME.RosterMarkGone(ply)
	local i = slotOf(ply); if not (i and ME.Roster[i]) then return end
	ME.Roster[i].connected, ME.Roster[i].spectating = false, false
	ME.SendRoster()
end
function ME.RosterMarkSpectating(ply)
	local i = slotOf(ply); if not (i and ME.Roster[i]) then return end
	ME.Roster[i].connected, ME.Roster[i].spectating = true, true
	ME.SendRoster()
end

local DUMMY_NAMES = { "AlphaStrike", "NovaShard", "IronVeil", "DuskReaper", "GlassEdge" }

local DUMMY_SIDS  = { "76561197960287930","76561197960435530","76561198355625888","76561197979911851","76561198028530710" }
local DUMMY_PINGS = { 38, 95, 175, 55, 210 }


hook.Add("PlayerDisconnected", "ME_RosterDisconnect", function(ply)
	if not IsValid(ply) then return end
	local sid = ply:SteamID64()
	local changed = false
	for _, e in pairs(ME.Roster) do
		if e.sid == sid and e.connected then
			e.connected = false
			changed = true
		end
	end
	if changed then timer.Simple(0, function() ME.SendRoster() end) end
end)

hook.Add("PlayerInitialSpawn", "ME_RosterLateJoin", function(ply)
	timer.Simple(2.5, function()
		if IsValid(ply) and ME.MatchActive then ME.SendRoster(ply) end
	end)
end)
