

util.AddNetworkString("ME_MatchEnd")

ME.MatchStats    = ME.MatchStats or {}
ME.MatchStartedAt = ME.MatchStartedAt or 0

function ME.MSReset()
	ME.MatchStats = {}
	for i = 1, ME.Config.MaxFactions do
		ME.MatchStats[i] = { kills = 0, damage = 0, income = 0 }
	end
	ME.FacMoneyAcc    = {}
	ME.MatchStartedAt = CurTime()
end

local function slot(fac)
	fac = tonumber(fac) or 0
	if fac < 1 or fac > (ME.Config.MaxFactions or 6) then return nil end
	ME.MatchStats[fac] = ME.MatchStats[fac] or { kills = 0, damage = 0, income = 0 }
	return ME.MatchStats[fac]
end

function ME.MSAddKill(fac, n)
	local s = slot(fac); if s then s.kills = s.kills + (tonumber(n) or 1) end
end
function ME.MSAddDamage(fac, n)
	local s = slot(fac); if s then s.damage = s.damage + math.max(0, math.floor(tonumber(n) or 0)) end
end
function ME.MSAddIncome(fac, n)
	local s = slot(fac); if s then s.income = s.income + math.max(0, math.floor(tonumber(n) or 0)) end
end

function ME.MatchDuration()
	if (ME.MatchStartedAt or 0) <= 0 then return 0 end
	return math.max(0, CurTime() - ME.MatchStartedAt)
end

function ME.MapLabel()
	return (ME.Config and ME.Config.MapName) or "Breaktide"
end

function ME.ModeLabel()
	local m = tostring((ME.MM and ME.MM.CurrentMode) or "casual")
	return m:sub(1, 1):upper() .. m:sub(2)
end

function ME.BuildMatchSummary()
	local rows = {}
	for i = 1, ME.Config.MaxFactions do
		local e = ME.Roster and ME.Roster[i]
		if e then
			local s = ME.MatchStats[i] or {}
			rows[#rows + 1] = {
				faction = i,
				sid     = e.sid  or "",
				name    = e.name or "Player",
				rank    = e.rank or 0,
				kills   = s.kills  or 0,
				damage  = s.damage or 0,
				income  = s.income or 0,
			}
		end
	end
	return {
		map  = ME.MapLabel(),
		mode = ME.ModeLabel(),
		time = math.floor(ME.MatchDuration()),
		rows = rows,
	}
end

function ME.SendMatchEnd(ply, kind, canSpectate)
	if not IsValid(ply) then return end
	local data = ME.BuildMatchSummary()
	data.kind        = kind
	data.canSpectate = canSpectate and true or false
	data.you         = ply:Team()
	net.Start("ME_MatchEnd")
	net.WriteString(util.TableToJSON(data) or "{}")
	net.Send(ply)
end

