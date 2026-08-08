ME = ME or {}

local SQRT3 = math.sqrt(3)
local function size() return ME.Config and ME.Config.HexSize or 96 end

function ME.HexToWorld(q, r, z)
	local s = size()
	local x = s * (SQRT3 * q + SQRT3 * 0.5 * r)
	local y = s * (1.5 * r)
	return Vector(x, y, z or 0)
end

local function hexRound(qf, rf)
	local xf, zf = qf, rf
	local yf = -xf - zf
	local rx, ry, rz = math.Round(xf), math.Round(yf), math.Round(zf)
	local dx, dy, dz = math.abs(rx - xf), math.abs(ry - yf), math.abs(rz - zf)
	if dx > dy and dx > dz then
		rx = -ry - rz
	elseif dy > dz then
		ry = -rx - rz
	else
		rz = -rx - ry
	end
	return rx, rz
end
ME.HexRound = hexRound

function ME.WorldToHex(pos)
	local s = size()
	local qf = (SQRT3 / 3 * pos.x - 1 / 3 * pos.y) / s
	local rf = (2 / 3 * pos.y) / s
	return hexRound(qf, rf)
end

local NEIGHBORS = { {1,0}, {1,-1}, {0,-1}, {-1,0}, {-1,1}, {0,1} }
ME.HexDirs = NEIGHBORS

ME.FaceDirs = { [0] = {1,0}, [1] = {0,1}, [2] = {-1,1}, [3] = {-1,0}, [4] = {0,-1}, [5] = {1,-1} }
function ME.FaceNeighbor(q, r, idx)
	local d = ME.FaceDirs[idx % 6]
	return q + d[1], r + d[2]
end

function ME.HexNeighbors(q, r)
	local out = {}
	for i = 1, 6 do out[i] = { q + NEIGHBORS[i][1], r + NEIGHBORS[i][2] } end
	return out
end

function ME.HexDistance(q1, r1, q2, r2)
	local dq, dr = q1 - q2, r1 - r2
	return (math.abs(dq) + math.abs(dr) + math.abs(dq + dr)) / 2
end

function ME.HexCorners(center, z)
	local s = size()
	local cx, cy = center.x, center.y
	z = z or center.z or 0
	local pts = {}
	for i = 0, 5 do
		local ang = math.rad(60 * i - 30)
		pts[i + 1] = Vector(cx + s * math.cos(ang), cy + s * math.sin(ang), z)
	end
	return pts
end

function ME.HexEachInRadius(radius, fn)
	for q = -radius, radius do
		local r1 = math.max(-radius, -q - radius)
		local r2 = math.min(radius, -q + radius)
		for r = r1, r2 do fn(q, r) end
	end
end

function ME.HexKey(q, r) return q .. ":" .. r end

function ME.ReliefNoise(q, r)
	return (math.sin(q * 0.45 + r * 0.15) + math.sin(r * 0.5 - q * 0.2) + math.sin((q + r) * 0.30)) / 3
end

local function grassTierHeight(q, r)
	local H = (ME.Config and ME.Config.Heights) or {}
	local tiers = (ME.Config and ME.Config.TerrainTiers) or 4
	local step  = (ME.Config and ME.Config.TierStep) or 20
	local n = ME.ReliefNoise(q, r) * 0.5 + 0.5
	local preset = ME.Presets and ME.Config and ME.Presets[ME.Config.Preset]
	if preset and preset.centralIsland then
		local cr = (ME.Config.IslandRadius or 7) * (preset.centralScale or 1.8)
		local cd = ME.HexDistance(q, r, 0, 0)
		if cd < cr then n = n + (1 - cd / cr) * (ME.Config.CentralReliefBias or 0.6) end
	end
	local tier = math.Clamp(math.floor(math.Clamp(n, 0, 0.999) * tiers), 0, tiers - 1)
	return (H.grass or 0) + tier * step
end

ME.FlatHexes = ME.FlatHexes or {}
function ME.BuildFlatHexes(spawnHexes)
	ME.FlatHexes = {}
	if not spawnHexes then return end
	for _, sp in ipairs(spawnHexes) do
		local sq, sr = sp.q or sp[1], sp.r or sp[2]
		if sq then
			local h = grassTierHeight(sq, sr)
			ME.FlatHexes[ME.HexKey(sq, sr)] = h
			for _, nb in ipairs(ME.HexNeighbors(sq, sr)) do
				ME.FlatHexes[ME.HexKey(nb[1], nb[2])] = h
			end
		end
	end
end

function ME.SurfaceOffset(q, r, biome)
	local H = (ME.Config and ME.Config.Heights) or {}
	if biome == "water" then return H.water or -24 end
	if biome == "sand"  then return H.sand or 0 end
	local flat = ME.FlatHexes[ME.HexKey(q, r)]
	if flat then return flat end
	return grassTierHeight(q, r)
end

local RAMP_BLOCK = { mountain = true, tree = true, palm = true, rock = true, bush = true }
local MIN_OPEN   = 3

local function isLand(cell) return cell and cell.biome ~= "water" and not RAMP_BLOCK[cell.decor] end

local function tierOf(cells, q, r)
	local cell = cells[ME.HexKey(q, r)]
	local H    = (ME.Config and ME.Config.Heights) or {}
	local step = (ME.Config and ME.Config.TierStep) or 20
	local h
	if cell and cell.biome == "sand" then h = H.sand or 0
	else h = ME.FlatHexes[ME.HexKey(q, r)] or grassTierHeight(q, r) end
	return math.Round((h - (H.grass or 0)) / step)
end

function ME.BuildBeachRamps(cells)
	if not cells then return end
	local H     = (ME.Config and ME.Config.Heights) or {}
	local step  = (ME.Config and ME.Config.TierStep) or 20

	local function pin(q, r, tier)
		local k = ME.HexKey(q, r)
		if ME.FlatHexes[k] ~= nil then return false end
		ME.FlatHexes[k] = (H.grass or 0) + tier * step
		return true
	end

	local function sandOpen(c)
		for _, nb in ipairs(ME.HexNeighbors(c.q, c.r)) do
			local n = cells[ME.HexKey(nb[1], nb[2])]
			if isLand(n) and n.biome ~= "sand" and tierOf(cells, nb[1], nb[2]) <= 1 then return true end
		end
		return false
	end

	local function carve(c)
		local prev, cq, cr = 0, c.q, c.r
		local seen = { [ME.HexKey(c.q, c.r)] = true }
		for _ = 1, (ME.Config and ME.Config.TerrainTiers) or 4 do
			local best, bestT
			for _, nb in ipairs(ME.HexNeighbors(cq, cr)) do
				local k = ME.HexKey(nb[1], nb[2])
				local n = cells[k]
				if not seen[k] and isLand(n) and n.biome ~= "sand" then
					local t = tierOf(cells, nb[1], nb[2])
					if not bestT or t < bestT then bestT, best = t, nb end
				end
			end
			if not best then return end
			if bestT <= prev + 1 then return end
			if not pin(best[1], best[2], prev + 1) then return end
			seen[ME.HexKey(best[1], best[2])] = true
			prev, cq, cr = prev + 1, best[1], best[2]
		end
	end

	local sand = {}
	for _, c in pairs(cells) do if c.biome == "sand" then sand[#sand + 1] = c end end
	table.sort(sand, function(a, b) if a.q ~= b.q then return a.q < b.q end return a.r < b.r end)

	local visited = {}
	for _, seed in ipairs(sand) do
		local sk = ME.HexKey(seed.q, seed.r)
		if not visited[sk] then
			local beach, qi = { seed }, 1
			visited[sk] = true
			while qi <= #beach do
				local cur = beach[qi]; qi = qi + 1
				for _, nb in ipairs(ME.HexNeighbors(cur.q, cur.r)) do
					local k = ME.HexKey(nb[1], nb[2])
					local n = cells[k]
					if n and n.biome == "sand" and not visited[k] then visited[k] = true; beach[#beach + 1] = n end
				end
			end
			local open = 0
			for _, c in ipairs(beach) do if sandOpen(c) then open = open + 1 end end
			for _, c in ipairs(beach) do
				if open >= MIN_OPEN then break end
				if not sandOpen(c) then
					carve(c)
					if sandOpen(c) then open = open + 1 end
				end
			end
		end
	end
end
