

ME = ME or {}

ME.GrassModel = "models/merge_empires/tall_grass.mdl"

local DIRS      = { {1,0},{-1,0},{0,1},{0,-1},{1,-1},{-1,1} }
local BAD_DECOR = { tree = true, mountain = true, palm = true, slot = true, gold = true, rock = true }

local function drand(a, b)
	local v = math.sin(a * 127.1 + b * 311.7) * 43758.5453
	return v - math.floor(v)
end
ME.GrassRand = drand

local function byHex(a, b)
	if a.q ~= b.q then return a.q < b.q end
	return a.r < b.r
end

function ME.GrassPlan(cells, spawnHexes)
	local plan, cover = {}, {}
	if not cells then return plan, cover end

	local blocked = {}
	for _, s in ipairs(spawnHexes or {}) do
		if s and s.q then blocked[ME.HexKey(s.q, s.r)] = true end
	end

	local eligibleByKey, goldCells, rockCells = {}, {}, {}
	for key, cell in pairs(cells) do
		if cell.biome == "grass" and not BAD_DECOR[cell.decor] and not blocked[key] then
			eligibleByKey[key] = cell
		end
		if cell.decor == "gold" then goldCells[#goldCells + 1] = cell end
		if cell.biome == "rock"  then rockCells[#rockCells + 1] = cell end
	end
	table.sort(goldCells, byHex)
	table.sort(rockCells, byHex)

	local canSeed = {}
	for key, cell in pairs(eligibleByKey) do
		for _, d in ipairs(DIRS) do
			if eligibleByKey[ME.HexKey(cell.q + d[1], cell.r + d[2])] then canSeed[key] = cell break end
		end
	end

	local used = {}

	local function take(cell, count, seed)
		local key = ME.HexKey(cell.q, cell.r)
		used[key], cover[key] = true, true
		plan[#plan + 1] = { q = cell.q, r = cell.r, count = count, seed = seed }
	end

	local function pickCluster(startCell, maxN, seed)
		local key0 = ME.HexKey(startCell.q, startCell.r)
		if not canSeed[key0] or used[key0] then return {} end
		local cluster   = { startCell }
		local inCluster = { [key0] = true }
		used[key0]      = true
		local frontier  = {}
		for _, d in ipairs(DIRS) do
			local nk = ME.HexKey(startCell.q + d[1], startCell.r + d[2])
			if eligibleByKey[nk] and not used[nk] and not inCluster[nk] then
				frontier[#frontier + 1] = eligibleByKey[nk]; inCluster[nk] = true
			end
		end
		while #cluster < maxN and #frontier > 0 do
			local idx  = (math.floor(drand(seed + #cluster, #frontier + 1) * #frontier) % #frontier) + 1
			local cell = table.remove(frontier, idx)
			local key  = ME.HexKey(cell.q, cell.r)
			if not used[key] then
				cluster[#cluster + 1] = cell
				used[key] = true
				for _, d in ipairs(DIRS) do
					local nk = ME.HexKey(cell.q + d[1], cell.r + d[2])
					if eligibleByKey[nk] and not used[nk] and not inCluster[nk] then
						frontier[#frontier + 1] = eligibleByKey[nk]; inCluster[nk] = true
					end
				end
			end
		end
		return cluster
	end

	local function groupAdjacent(list)
		local keyMap, visited, groups = {}, {}, {}
		for _, c in ipairs(list) do keyMap[ME.HexKey(c.q, c.r)] = c end
		for _, start in ipairs(list) do
			local sk = ME.HexKey(start.q, start.r)
			if not visited[sk] then
				local grp, queue, qi = {}, { start }, 1
				visited[sk] = true
				while qi <= #queue do
					local cur = queue[qi]; qi = qi + 1; grp[#grp + 1] = cur
					for _, d in ipairs(DIRS) do
						local nk = ME.HexKey(cur.q + d[1], cur.r + d[2])
						if keyMap[nk] and not visited[nk] then visited[nk] = true; queue[#queue + 1] = keyMap[nk] end
					end
				end
				groups[#groups + 1] = grp
			end
		end
		return groups
	end

	local function findNearbySeeds(refCells, rings)
		local out, seen, frontier = {}, {}, {}
		for _, c in ipairs(refCells) do
			local k = ME.HexKey(c.q, c.r)
			if not seen[k] then seen[k] = true; frontier[#frontier + 1] = c end
		end
		for _ = 1, rings do
			local nxt = {}
			for _, c in ipairs(frontier) do
				for _, d in ipairs(DIRS) do
					local nk = ME.HexKey(c.q + d[1], c.r + d[2])
					if not seen[nk] then
						seen[nk] = true
						local nc = cells[nk]
						if nc and nc.biome ~= "water" then
							nxt[#nxt + 1] = nc
							if canSeed[nk] and not used[nk] then out[#out + 1] = canSeed[nk] end
						end
					end
				end
			end
			frontier = nxt
		end
		return out
	end

	local function pickSeed(seeds, seed)
		if #seeds == 0 then return nil end
		return seeds[(math.floor(drand(seed, #seeds + 1) * #seeds) % #seeds) + 1]
	end

	local function distribute(cluster, total, baseSeed)
		if #cluster == 0 then return end
		local perHex = math.max(3, math.floor(total / #cluster))
		for ci, cl in ipairs(cluster) do
			local cnt = (ci == #cluster) and math.max(3, total - perHex * (#cluster - 1)) or perHex
			take(cl, cnt, baseSeed + ci * 17)
		end
	end

	for gi, grp in ipairs(groupAdjacent(goldCells)) do
		local seeds = findNearbySeeds(grp, 3)
		local seed  = pickSeed(seeds, gi * 9 + 1)
		if seed then
			local total    = 8 + math.floor(drand(gi * 13, #grp + 1) * 3)
			local numHexes = 2 + math.floor(drand(gi * 7, total) * 2)
			local cluster  = pickCluster(seed, numHexes, gi * 100)
			if #cluster >= 2 then distribute(cluster, total, gi * 100) end
		end
	end

	if #rockCells > 0 then
		local seeds = findNearbySeeds(rockCells, 4)
		local seed  = pickSeed(seeds, 313)
		if seed then
			local total    = 30 + math.floor(drand(77, #rockCells + 1) * 11)
			local numHexes = 8 + math.floor(drand(313, total) * 5)
			local cluster  = pickCluster(seed, numHexes, 3130)
			if #cluster >= 2 then distribute(cluster, total, 3130) end
		end
	end

	return plan, cover
end
