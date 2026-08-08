util.AddNetworkString("ME_Board")

local function groundZ(pos)
	local bottom = Vector(pos.x, pos.y, -16384)
	local tr = util.TraceLine({ start = Vector(pos.x, pos.y, 16384), endpos = bottom, mask = MASK_SOLID_BRUSHONLY })
	local guard = 0
	while tr.Hit and tr.HitSky and guard < 8 do
		guard = guard + 1
		tr = util.TraceLine({ start = tr.HitPos - Vector(0, 0, 4), endpos = bottom, mask = MASK_SOLID_BRUSHONLY })
	end
	if tr.Hit and not tr.HitSky then return tr.HitPos.z end
	return pos.z
end

local function noise(q, r)
	local v = math.sin(q * 12.9898 + r * 78.233) * 43758.5453
	return v - math.floor(v)
end

local function landNeighbours(cells, q, r)
	local n = 0
	for _, nb in ipairs(ME.HexNeighbors(q, r)) do
		local c = cells[ME.HexKey(nb[1], nb[2])]
		if c and c.biome ~= "water" then n = n + 1 end
	end
	return n
end

local function touchesWater(cells, q, r)
	for _, nb in ipairs(ME.HexNeighbors(q, r)) do
		local c = cells[ME.HexKey(nb[1], nb[2])]
		if not c or c.biome == "water" then return true end
	end
	return false
end

function ME.GenerateArena(seed)
	seed = seed or (os.time() % 2147483647)
	math.randomseed(seed)
	for _ = 1, 5 do math.random() end

	local radius  = ME.Config.BoardRadius or 44
	local baseZ   = ME.Config.ArenaBaseZ or groundZ(Vector(0, 0, 0))
	local HS      = ME.Config.HexSize or 96
	local n       = ME.Config.MaxFactions
	local clearR  = ME.Config.CoreClearRadius or 4
	local beachMax        = ME.Config.BeachMax or 22
	local beachMaxNeutral = ME.Config.BeachMaxNeutral or 14
	local mClear  = ME.Config.MountainClear or 2
	local preset  = (ME.Presets or {})[ME.Config.Preset or "Breaktide"] or {}

	local ringWorld = radius * HS * 1.15
	local islandR   = ME.Config.IslandRadius or 7
	local islands = {}
	for i = 1, n do
		local ang = (i - 1) / n * math.pi * 2 + 0.4
		local cq, cr = ME.WorldToHex(Vector(math.cos(ang) * ringWorld, math.sin(ang) * ringWorld, 0))
		islands[i] = { q = cq, r = cr, rad = islandR * math.Rand(0.85, 1.15), faction = i,
		               beaches = { math.random() * 360 } }
	end
	if preset.centralIsland then
		islands[#islands + 1] = { q = 0, r = 0, rad = islandR * (preset.centralScale or 1.8),
		                          central = true, beaches = preset.centralBeaches or { 90, 270 } }
		local smallN   = preset.smallIslands or 3
		local centRad  = islandR * (preset.centralScale or 1.8)
		local smallRad = islandR * 0.70
		local blobExtra = 1.26
		local clearHex  = 7
		local minDist   = (centRad * blobExtra + smallRad * blobExtra + clearHex) * HS
		for s = 1, smallN do
			local ang = (s - 1) / smallN * math.pi * 2 + 1.0
			local sq, sr = ME.WorldToHex(Vector(math.cos(ang) * minDist, math.sin(ang) * minDist, 0))
			islands[#islands + 1] = { q = sq, r = sr, rad = smallRad,
			                          neutral = true, beaches = { math.random() * 360 }, forceBeach = true }
		end
	end
	local function nearestIsland(q, r)
		local best, bd = nil, 1e9
		for _, b in ipairs(islands) do
			local d = ME.HexDistance(q, r, b.q, b.r)
			if d < bd then bd, best = d, b end
		end
		return best, bd
	end

	local cells = {}
	ME.HexEachInRadius(radius, function(q, r)
		local best = -999
		for _, b in ipairs(islands) do
			local v = 1 - ME.HexDistance(q, r, b.q, b.r) / b.rad
			if v > best then best = v end
		end
		best = best + (noise(q, r) - 0.5) * 0.26
		cells[ME.HexKey(q, r)] = { q = q, r = r, biome = (best > 0) and "grass" or "water",
		                           passable = (best > 0), decor = "none" }
	end)

	do
		local GAP = 2
		local centIsl
		for _, isl in ipairs(islands) do if isl.central then centIsl = isl; break end end
		if centIsl then
			for _, isl in ipairs(islands) do
				if isl.neutral then
					ME.HexEachInRadius(radius, function(q, r)
						local dc = ME.HexDistance(q, r, centIsl.q, centIsl.r)
						local dn = ME.HexDistance(q, r, isl.q, isl.r)
						if dc <= centIsl.rad + GAP and dn <= isl.rad + GAP and dc + dn <= ME.HexDistance(centIsl.q, centIsl.r, isl.q, isl.r) + GAP then
							local c = cells[ME.HexKey(q, r)]
							if c and c.biome ~= "water" and dc > centIsl.rad - 1 and dn > isl.rad - 1 then
								c.biome, c.passable = "water", false
							end
						end
					end)
				end
			end
		end
	end

	do
		local keep, queue = {}, {}
		for _, isl in ipairs(islands) do
			local k, c = ME.HexKey(isl.q, isl.r), cells[ME.HexKey(isl.q, isl.r)]
			if c and c.biome ~= "water" then keep[k] = true; queue[#queue + 1] = c end
		end
		local qi = 1
		while qi <= #queue do
			local c = queue[qi]; qi = qi + 1
			for _, nb in ipairs(ME.HexNeighbors(c.q, c.r)) do
				local nk, nc = ME.HexKey(nb[1], nb[2]), cells[ME.HexKey(nb[1], nb[2])]
				if nc and nc.biome ~= "water" and not keep[nk] then keep[nk] = true; queue[#queue + 1] = nc end
			end
		end
		for key, c in pairs(cells) do
			if c.biome ~= "water" and not keep[key] then c.biome, c.passable = "water", false end
		end
	end

	for _ = 1, 2 do
		local drop = {}
		for key, c in pairs(cells) do
			if c.biome ~= "water" and landNeighbours(cells, c.q, c.r) < 3 then drop[key] = true end
		end
		for key in pairs(drop) do local c = cells[key]; c.biome, c.passable = "water", false end
	end

	do
		local centIsl
		for _, isl in ipairs(islands) do if isl.central then centIsl = isl; break end end
		if centIsl then
			local centLand = {}
			do
				local q = { cells[ME.HexKey(centIsl.q, centIsl.r)] }; centLand[ME.HexKey(centIsl.q, centIsl.r)] = true
				local qi = 1
				while qi <= #q do
					local c = q[qi]; qi = qi + 1
					for _, nb in ipairs(ME.HexNeighbors(c.q, c.r)) do
						local nk = ME.HexKey(nb[1], nb[2])
						local nc = cells[nk]
						if nc and nc.biome ~= "water" and not centLand[nk] then centLand[nk] = true; q[#q + 1] = nc end
					end
				end
			end
			for _, isl in ipairs(islands) do
				if isl.neutral then
					local neutLand = {}
					do
						local q = { cells[ME.HexKey(isl.q, isl.r)] }
						if q[1] then
							neutLand[ME.HexKey(isl.q, isl.r)] = true
							local qi = 1
							while qi <= #q do
								local c = q[qi]; qi = qi + 1
								for _, nb in ipairs(ME.HexNeighbors(c.q, c.r)) do
									local nk = ME.HexKey(nb[1], nb[2])
									local nc = cells[nk]
									if nc and nc.biome ~= "water" and not neutLand[nk] then neutLand[nk] = true; q[#q + 1] = nc end
								end
							end
						end
					end
					for key in pairs(neutLand) do
						if centLand[key] then
							local c = cells[key]
							if c then c.biome, c.passable = "water", false end
						end
					end
					centLand = {}
					local q = { cells[ME.HexKey(centIsl.q, centIsl.r)] }
					centLand[ME.HexKey(centIsl.q, centIsl.r)] = true
					local qi = 1
					while qi <= #q do
						local c = q[qi]; qi = qi + 1
						for _, nb in ipairs(ME.HexNeighbors(c.q, c.r)) do
							local nk = ME.HexKey(nb[1], nb[2])
							local nc = cells[nk]
							if nc and nc.biome ~= "water" and not centLand[nk] then centLand[nk] = true; q[#q + 1] = nc end
						end
					end
				end
			end
		end
	end

	do
		local ocean, queue = {}, {}
		for key, c in pairs(cells) do
			if c.biome == "water" then
				for _, nb in ipairs(ME.HexNeighbors(c.q, c.r)) do
					if not cells[ME.HexKey(nb[1], nb[2])] then ocean[key] = true; queue[#queue + 1] = c; break end
				end
			end
		end
		local qi = 1
		while qi <= #queue do
			local c = queue[qi]; qi = qi + 1
			for _, nb in ipairs(ME.HexNeighbors(c.q, c.r)) do
				local nk, nc = ME.HexKey(nb[1], nb[2]), cells[ME.HexKey(nb[1], nb[2])]
				if nc and nc.biome == "water" and not ocean[nk] then ocean[nk] = true; queue[#queue + 1] = nc end
			end
		end
		for key, c in pairs(cells) do
			if c.biome == "water" and not ocean[key] then c.biome, c.passable = "grass", true end
		end
	end

	ME.Board = { seed = seed, radius = radius, baseZ = baseZ, center = ME.HexToWorld(0, 0, baseZ), cells = cells, spawns = {} }
	for i = 1, n do ME.Board.spawns[i] = { q = islands[i].q, r = islands[i].r } end
	ME.BuildFlatHexes(ME.Board.spawns)

	local function islandAngle(isl, q, r)
		local a, b = ME.HexToWorld(isl.q, isl.r, 0), ME.HexToWorld(q, r, 0)
		return math.deg(math.atan2(b.y - a.y, b.x - a.x))
	end
	local function angDiff(x, y) local d = math.abs((x - y) % 360); return math.min(d, 360 - d) end

	local coastByIsland = {}
	for _, c in pairs(cells) do
		if c.biome == "grass" and touchesWater(cells, c.q, c.r) then
			local isl = nearestIsland(c.q, c.r)
			coastByIsland[isl] = coastByIsland[isl] or {}
			table.insert(coastByIsland[isl], c)
		end
	end
	for _, isl in ipairs(islands) do
		local coast = coastByIsland[isl]
		if coast then
			local coastSet = {}
			for _, c in ipairs(coast) do coastSet[ME.HexKey(c.q, c.r)] = c end
			local cap = (isl.central or isl.neutral) and beachMaxNeutral or beachMax
			local beachPlaced = false
			for _, ba in ipairs(isl.beaches) do
				local seed, bd = nil, 1e9
				for _, c in ipairs(coast) do local d = angDiff(islandAngle(isl, c.q, c.r), ba); if d < bd then bd, seed = d, c end end
				if seed then
					local q2, seen, count, qi = { seed }, { [ME.HexKey(seed.q, seed.r)] = true }, 0, 1
					while qi <= #q2 and count < cap do
						local cc = q2[qi]; qi = qi + 1
						cc.biome, cc.passable, cc.decor = "sand", true, "none"
						count = count + 1
						beachPlaced = count > 0
						for _, nb in ipairs(ME.HexNeighbors(cc.q, cc.r)) do
							local nk = ME.HexKey(nb[1], nb[2])
							if coastSet[nk] and not seen[nk] then seen[nk] = true; q2[#q2 + 1] = coastSet[nk] end
						end
					end
				end
			end
			if isl.forceBeach and not beachPlaced and #coast > 0 then
				for _, c in ipairs(coast) do
					c.biome, c.passable, c.decor = "sand", true, "none"
					beachPlaced = true
					break
				end
				local seed = coast[1]
				local q2, seen, count, qi = { seed }, { [ME.HexKey(seed.q, seed.r)] = true }, 1, 1
				while qi <= #q2 and count < math.max(4, cap) do
					local cc = q2[qi]; qi = qi + 1
					for _, nb in ipairs(ME.HexNeighbors(cc.q, cc.r)) do
						local nk = ME.HexKey(nb[1], nb[2])
						if coastSet[nk] and not seen[nk] and count < cap then
							seen[nk] = true; q2[#q2 + 1] = coastSet[nk]
							coastSet[nk].biome, coastSet[nk].passable, coastSet[nk].decor = "sand", true, "none"
							count = count + 1
						end
					end
				end
			end
		end
	end

	for _, c in pairs(cells) do
		if c.biome == "grass" then
			local allSand, count = true, 0
			for _, nb in ipairs(ME.HexNeighbors(c.q, c.r)) do
				local nc = cells[ME.HexKey(nb[1], nb[2])]
				if nc then count = count + 1; if nc.biome ~= "sand" then allSand = false end else allSand = false end
			end
			if allSand and count == 6 then c.biome = "sand" end
		end
	end

	for i = 1, n do
		local cq, cr = islands[i].q, islands[i].r
		local plot = { { cq, cr } }
		for _, nb in ipairs(ME.HexNeighbors(cq, cr)) do plot[#plot + 1] = nb end
		for _, pc in ipairs(plot) do
			local c = cells[ME.HexKey(pc[1], pc[2])]
			if c then c.biome, c.passable, c.decor = "grass", true, "none" end
		end
	end

	if preset.centralIsland then
		ME.HexEachInRadius(preset.centralRockRadius or 2, function(dq, dr)
			local c = cells[ME.HexKey(dq, dr)]
			if c and c.biome ~= "water" then c.biome, c.passable, c.decor = "rock", true, "none" end
		end)
	end

	if preset.centralIsland then
		local c = cells[ME.HexKey(0, 0)]
		if c then c.biome, c.passable, c.decor = "grass", true, "gold" end
	end
	if preset.centralIsland then
		local rockR = preset.centralRockRadius or 2
		local ringCells = {}
		ME.HexEachInRadius(rockR + 2, function(q, r)
			if ME.HexDistance(q, r, 0, 0) == rockR + 1 then
				local c = cells[ME.HexKey(q, r)]
				if c and (c.biome == "grass" or c.biome == "rock") and c.decor == "none" then
					ringCells[#ringCells + 1] = c
				end
			end
		end)
		local placed = 0
		for i = 1, #ringCells, 2 do
			if placed >= 5 then break end
			ringCells[i].decor, ringCells[i].passable = "mountain", false
			placed = placed + 1
		end
	end
	if preset.centralIsland then
		local rockR = preset.centralRockRadius or 2
		local slotAngles = { 0, 120, 240 }
		for _, deg in ipairs(slotAngles) do
			local a  = math.rad(deg)
			local wx = math.cos(a) * (rockR + 2) * (ME.Config.HexSize or 96) * 1.0
			local wy = math.sin(a) * (rockR + 2) * (ME.Config.HexSize or 96) * 1.0
			local sq, sr = ME.WorldToHex(Vector(wx, wy, 0))
			local sc = cells[ME.HexKey(sq, sr)]

			if not (sc and sc.biome ~= "water" and sc.decor == "none") then
				sc = nil
				for dq = -3, 3 do
					for dr = math.max(-3, -dq - 3), math.min(3, -dq + 3) do
						if not sc then
							local c = cells[ME.HexKey(sq + dq, sr + dr)]
							if c and c.biome ~= "water" and c.decor == "none" then sc = c end
						end
					end
				end
			end

			if sc and sc.biome ~= "water" and sc.decor == "none" then
				sc.decor, sc.passable = "slot", true
			end
		end
	end
	for _, isl in ipairs(islands) do
		if isl.neutral then
			local c = cells[ME.HexKey(isl.q, isl.r)]
			if c and c.biome ~= "water" then c.biome, c.passable, c.decor = "grass", true, "gold" end
		end
	end

	local reserved = {}
	local function reserveDisc(q, r, rad)
		local frontier, seen, i = { { q, r, 0 } }, { [ME.HexKey(q, r)] = true }, 1
		reserved[ME.HexKey(q, r)] = true
		while i <= #frontier do
			local cur = frontier[i]; i = i + 1
			if cur[3] < rad then
				for _, nb in ipairs(ME.HexNeighbors(cur[1], cur[2])) do
					local nk = ME.HexKey(nb[1], nb[2])
					if not seen[nk] then seen[nk] = true; reserved[nk] = true; frontier[#frontier + 1] = { nb[1], nb[2], cur[3] + 1 } end
				end
			end
		end
	end

	local pools = {}
	for _, c in pairs(cells) do
		if c.biome == "grass" and c.decor == "none" then
			local isl, d = nearestIsland(c.q, c.r)
			if isl and d > clearR then
				c._d = d
				pools[isl] = pools[isl] or {}
				pools[isl][#pools[isl] + 1] = c
			end
		end
	end
	local sandPools = {}
	for _, c in pairs(cells) do
		if c.biome == "sand" and c.decor == "none" then
			local isl = nearestIsland(c.q, c.r)
			if isl then sandPools[isl] = sandPools[isl] or {}; sandPools[isl][#sandPools[isl] + 1] = c end
		end
	end
	local function shuffle(t) for i = #t, 2, -1 do local j = math.random(i); t[i], t[j] = t[j], t[i] end end
	local function place(pool, want, kind, test)
		for _, c in ipairs(pool) do
			if want <= 0 then break end
			if c.decor == "none" and not reserved[ME.HexKey(c.q, c.r)] and test(c) then
				c.decor, c.passable = kind, false
				want = want - 1
			end
		end
	end

	local function islWorld(isl) return ME.HexToWorld(isl.q, isl.r, 0) end
	local function mtnOK(c)
		if not c or c.biome ~= "grass" or c.decor ~= "none" or reserved[ME.HexKey(c.q, c.r)] then return false end
		for _, nb in ipairs(ME.HexNeighbors(c.q, c.r)) do
			local nc = cells[ME.HexKey(nb[1], nb[2])]
			if nc and nc.biome == "sand" then return false end
		end
		return true
	end
	local function placeMountainRidge(pool, isl, beachAng)
		local a   = math.rad((beachAng or 0) + 180)
		local ox, oy = math.cos(a), math.sin(a)
		local cw  = islWorld(isl)
		local seed, best = nil, -1e9
		for _, c in ipairs(pool) do
			if mtnOK(c) then
				local w = ME.HexToWorld(c.q, c.r, 0)
				local score = (w.x - cw.x) * ox + (w.y - cw.y) * oy
				if score > best then best, seed = score, c end
			end
		end
		if not seed then return end
		local ring   = ME.HexDistance(seed.q, seed.r, isl.q, isl.r)
		local line   = { seed }
		local isUsed = { [ME.HexKey(seed.q, seed.r)] = true }
		seed.decor, seed.passable = "mountain", false
		local function hexAngle(c)
			local w = ME.HexToWorld(c.q, c.r, 0)
			return math.atan2(w.y - cw.y, w.x - cw.x)
		end
		local startAng = hexAngle(seed)
		for _ = 2, math.random(3, 5) do
			local cand, cbest = nil, 1e9
			for _, mc in ipairs(line) do
				for _, nb in ipairs(ME.HexNeighbors(mc.q, mc.r)) do
					local nk = ME.HexKey(nb[1], nb[2])
					local nc = cells[nk]
					if mtnOK(nc) and not isUsed[nk] then
						local da = math.abs(hexAngle(nc) - startAng) % (math.pi * 2)
						if da > math.pi then da = math.pi * 2 - da end
						if da < 2.2 then
							local d = math.abs(ME.HexDistance(nc.q, nc.r, isl.q, isl.r) - ring) + math.random() * 0.6
							if d < cbest then cbest, cand = d, nc end
						end
					end
				end
			end
			if not cand then break end
			isUsed[ME.HexKey(cand.q, cand.r)] = true
			cand.decor, cand.passable = "mountain", false
			line[#line + 1] = cand
		end
		if #line < 2 then seed.decor, seed.passable = "none", true; return end
		for _, mc in ipairs(line) do reserveDisc(mc.q, mc.r, mClear) end
	end

	for _, isl in ipairs(islands) do
		local pool = pools[isl]
		if pool then
			shuffle(pool)
			for _, ba in ipairs(isl.beaches or { 0 }) do placeMountainRidge(pool, isl, ba) end
			local treeWant
			if isl.faction then treeWant = math.random(4, 7)
			elseif isl.central then treeWant = math.max(5, math.floor(#pool * 0.26))
			else treeWant = math.max(8, math.floor(#pool * 0.5)) end
			place(pool, treeWant, "tree", function(c) return not touchesWater(cells, c.q, c.r) end)
			if isl.faction then
				local function nearSand(q, r)
					for _, nb in ipairs(ME.HexNeighbors(q, r)) do
						local c = cells[ME.HexKey(nb[1], nb[2])]
						if c and c.biome == "sand" then return true end
					end
					return false
				end
				local scand = {}
				for _, c in pairs(cells) do
					if c.biome == "grass" and c.decor == "none"
						and not reserved[ME.HexKey(c.q, c.r)]
						and not touchesWater(cells, c.q, c.r)
						and not nearSand(c.q, c.r) then
						local d = ME.HexDistance(c.q, c.r, isl.q, isl.r)
						if d >= 4 and d <= isl.rad then
							local ni = nearestIsland(c.q, c.r)
							if ni == isl then c._d = d; scand[#scand + 1] = c end
						end
					end
				end
				if #scand == 0 then
					for _, c in pairs(cells) do
						if c.biome == "grass" and c.decor == "none"
							and not touchesWater(cells, c.q, c.r) then
							local d = ME.HexDistance(c.q, c.r, isl.q, isl.r)
							if d >= 3 and d <= isl.rad then c._d = d; scand[#scand + 1] = c end
						end
					end
				end
				local chosen = {}

				local function take(pool, minGap)
					for _, c in ipairs(pool) do
						if #chosen >= 3 then return end
						if c.decor == "none" then
							local ok = true
							for _, p in ipairs(chosen) do
								if ME.HexDistance(c.q, c.r, p.q, p.r) < minGap then ok = false break end
							end
							if ok then c.decor, c.passable = "slot", true; chosen[#chosen + 1] = c end
						end
					end
				end

				table.sort(scand, function(a, b) return a._d > b._d end)

				for gap = 4, 1, -1 do
					if #chosen >= 3 then break end
					take(scand, gap)
				end

				if #chosen < 3 then
					local wide = {}
					for _, c in pairs(cells) do
						if c.biome == "grass" and c.decor == "none"
							and not reserved[ME.HexKey(c.q, c.r)] then
							local d = ME.HexDistance(c.q, c.r, isl.q, isl.r)
							if d >= 2 and d <= isl.rad and nearestIsland(c.q, c.r) == isl then
								c._d = d
								wide[#wide + 1] = c
							end
						end
					end
					table.sort(wide, function(a, b) return a._d > b._d end)
					for gap = 3, 1, -1 do
						if #chosen >= 3 then break end
						take(wide, gap)
					end
				end
			end
		end
		local sp = sandPools[isl]
		if sp then
			shuffle(sp)
			place(sp, math.random(2, 4), "palm", function() return true end)
		end
	end

	do
		local fac, nf = {}, 0
		for _, isl in ipairs(islands) do if isl.faction then fac[isl.faction] = isl; nf = nf + 1 end end
		local function nearestWater(wx, wy)
			local cq, cr = ME.WorldToHex(Vector(wx, wy, 0))
			local best, bd
			for dq = -3, 3 do for dr = -3, 3 do
				local c = cells[ME.HexKey(cq + dq, cr + dr)]
				if c and c.biome == "water" and c.decor == "none" then
					local w = ME.HexToWorld(c.q, c.r, 0)
					local d = (w.x - wx) ^ 2 + (w.y - wy) ^ 2
					if not bd or d < bd then bd, best = d, c end
				end
			end end
			return best
		end
		for i = 1, nf do
			local a, b = fac[i], fac[(i % nf) + 1]
			if a and b then
				local wa, wb = ME.HexToWorld(a.q, a.r, 0), ME.HexToWorld(b.q, b.r, 0)
				local c = nearestWater((wa.x + wb.x) * 0.5, (wa.y + wb.y) * 0.5)
				if c then c.decor = "oilspot" end
			end
		end
	end

	local function hexLine(q1, r1, q2, r2)
		local steps = math.max(1, ME.HexDistance(q1, r1, q2, r2))
		local out = {}
		for i = 0, steps do
			local t = i / steps
			local q, r = ME.HexRound(q1 + (q2 - q1) * t, r1 + (r2 - r1) * t)
			out[#out + 1] = { q, r }
		end
		return out
	end
	for _, isl in ipairs(islands) do
		if isl.faction then
			local cw = ME.HexToWorld(isl.q, isl.r, 0)
			for _, ba in ipairs(isl.beaches or { 0 }) do
				local a = math.rad(ba)
				local tq, tr = ME.WorldToHex(cw + Vector(math.cos(a), math.sin(a), 0) * (isl.rad * HS))
				for _, p in ipairs(hexLine(isl.q, isl.r, tq, tr)) do
					local c = cells[ME.HexKey(p[1], p[2])]
					if c and c.biome == "grass" and (c.decor == "tree" or c.decor == "mountain") then
						c.decor, c.passable = "none", true
					end
				end
			end
		end
	end

	ME.Map = ME.Map or {}
	ME.Map.seed, ME.Map.spawns = seed, {}
	for i = 1, n do
		local sp = ME.Board.spawns[i]
		ME.Map.spawns[i] = ME.HexToWorld(sp.q, sp.r, baseZ + ME.SurfaceOffset(sp.q, sp.r, "grass"))
	end

	if ME.ClearLOSCache then ME.ClearLOSCache() end
	ME.BuildBeachRamps(ME.Board.cells)

	local _, cover = ME.GrassPlan(ME.Board.cells, ME.Board.spawns)
	ME.GrassCover = cover

	ME.SendBoard()
	return ME.Board
end

function ME.ClearArena()

	for _, cls in ipairs({ "ent_me_unit", "ent_me_building", "ent_me_core" }) do
		for _, e in ipairs(ents.FindByClass(cls)) do if IsValid(e) then e:Remove() end end
	end
	ME.Cores = {}
	ME.Board = nil
	ME.GrassCover = nil
end

function ME.SendBoard(target)
	if not ME.Board then return end
	local b = ME.Board
	net.Start("ME_Board")
	net.WriteUInt(b.seed, 32)
	net.WriteUInt(b.radius, 8)
	net.WriteFloat(b.baseZ)
	net.WriteVector(b.center or ME.HexToWorld(0, 0, b.baseZ))
	net.WriteUInt(ME.Config.MaxFactions, 4)
	for i = 1, ME.Config.MaxFactions do
		local sp = b.spawns[i]
		net.WriteVector(sp and ME.HexToWorld(sp.q, sp.r, b.baseZ + ME.SurfaceOffset(sp.q, sp.r, "grass")) or Vector(0, 0, b.baseZ))
	end
	ME.HexEachInRadius(b.radius, function(q, r)
		local c = b.cells[ME.HexKey(q, r)]
		net.WriteUInt(ME.BIOME_ID[c.biome] or 0, 3)
		net.WriteUInt(ME.DECOR_ID[c.decor] or 0, 3)
	end)
	if target then net.Send(target) else net.Broadcast() end
end

hook.Add("PlayerInitialSpawn", "ME_BoardLateJoin", function(ply)
	timer.Simple(2, function() if IsValid(ply) and ME.Board then ME.SendBoard(ply) end end)
end)
