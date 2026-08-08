ME = ME or {}

function ME.Throttle(ply, key, cd)
	if not IsValid(ply) then return true end

	ply.MENetGate = ply.MENetGate or {}

	local now = CurTime()
	if (ply.MENetGate[key] or 0) > now then return true end

	ply.MENetGate[key] = now + (cd or 0.25)
	return false
end

function ME.PlayingFaction(ply)
	if not IsValid(ply) then return 0 end

	local t = ply:Team()
	if t < 1 or t > (ME.Config.MaxFactions or 6) then return 0 end

	return t
end

function ME.InMatch(ply)
	return ME.MatchActive and ME.PlayingFaction(ply) > 0
end

hook.Add("PlayerDisconnected", "ME_SecurityClearGate", function(ply)
	if IsValid(ply) then ply.MENetGate = nil end
end)
