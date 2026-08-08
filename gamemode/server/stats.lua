

util.AddNetworkString("ME_Stats")

ME.Stats = ME.Stats or {}

local function esc(s) return string.gsub(tostring(s or ""), "'", "''") end

local function modes()
	return (ME.MM and ME.MM.Modes) or { "casual", "blitz", "ambush", "duel", "ranked" }
end

local function isMode(m)
	for _, x in ipairs(modes()) do if x == m then return true end end
	return false
end

if not sql.TableExists("me_stats") then
	sql.Query([[CREATE TABLE me_stats (
		sid    TEXT    NOT NULL,
		mode   TEXT    NOT NULL,
		wins   INTEGER NOT NULL DEFAULT 0,
		played INTEGER NOT NULL DEFAULT 0,
		PRIMARY KEY (sid, mode)
	)]])
end

function ME.Stats.Get(sid)
	local out = {}
	for _, m in ipairs(modes()) do out[m] = 0 end

	local rows = sql.Query("SELECT mode, wins FROM me_stats WHERE sid = '" .. esc(sid) .. "'")
	if istable(rows) then
		for _, r in ipairs(rows) do
			if out[r.mode] ~= nil then out[r.mode] = tonumber(r.wins) or 0 end
		end
	end
	return out
end

local function bump(sid, mode, column, n)
	if not (sid and sid ~= "" and isMode(mode)) then return end
	n = math.max(0, math.floor(tonumber(n) or 0))
	if n == 0 then return end
	sid, mode = esc(sid), esc(mode)
	sql.Query("INSERT OR IGNORE INTO me_stats (sid, mode, wins, played) VALUES ('" .. sid .. "', '" .. mode .. "', 0, 0)")
	sql.Query("UPDATE me_stats SET " .. column .. " = " .. column .. " + " .. n ..
		" WHERE sid = '" .. sid .. "' AND mode = '" .. mode .. "'")
end

function ME.Stats.AddWin(ply, mode, n)
	if not IsValid(ply) then return end
	bump(ply:SteamID64(), mode, "wins", n or 1)
	ME.Stats.Send(ply)
end

function ME.Stats.Send(ply)
	if not IsValid(ply) then return end
	net.Start("ME_Stats")
	net.WriteString(util.TableToJSON(ME.Stats.Get(ply:SteamID64())) or "{}")
	net.Send(ply)
end

net.Receive("ME_Stats", function(_, ply)
	if not IsValid(ply) then return end
	ply.MEStatsNext = ply.MEStatsNext or 0
	if ply.MEStatsNext > CurTime() then return end
	ply.MEStatsNext = CurTime() + 0.5
	ME.Stats.Send(ply)
end)

hook.Add("PlayerInitialSpawn", "ME_StatsSend", function(ply)
	timer.Simple(3, function() if IsValid(ply) then ME.Stats.Send(ply) end end)
end)

