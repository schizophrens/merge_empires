ME = ME or {}
ME.BoardMeshes   = ME.BoardMeshes or {}
ME.WaterMeshes   = ME.WaterMeshes or {}
ME.BoardDecor    = ME.BoardDecor  or {}
ME.CoreModels    = ME.CoreModels  or {}

local MAX_TRIS = 21000

local boardMat = CreateMaterial("me_board_mat", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite", ["$vertexcolor"] = "1", ["$nocull"] = "1",
})

local waterMat = CreateMaterial("me_water", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite", ["$vertexcolor"] = "1",
	["$vertexalpha"] = "1", ["$alpha"] = "1", ["$translucent"] = "1", ["$nocull"] = "1",
})
local WATER_ALPHA = 198

local function cfgColor(biome)
	local C = ME.Config.Colors
	if biome == "water" then return C.water end
	if biome == "sand"  then return C.sand  end
	if biome == "rock"  then return C.darkRock or C.rockSide end
	return C.grass
end

local function vary(c, q, r, amp)
	amp = amp or 9
	local v = math.sin(q * 12.9 + r * 78.2) * 43758.5453
	local d = math.floor((v - math.floor(v)) * (amp * 2 + 1)) - amp
	return math.Clamp(c.r + d, 0, 255), math.Clamp(c.g + d, 0, 255), math.Clamp(c.b + d, 0, 255)
end

local L       = ME.Config.Light or {}
local SUN_DIR = (L.SunDir or Vector(-0.7, -0.45, 0.40)):GetNormalized()
local SUN_COL = L.SunColor or Vector(0.50, 0.36, 0.20)
local AMB_COL = L.Ambient  or Vector(0.30, 0.32, 0.40)

local BOX_FILL = 0.30
local BOX_W    = {}
do
	local faces = {
		{ BOX_FRONT,  Vector( 1,  0,  0) },
		{ BOX_BACK,   Vector(-1,  0,  0) },
		{ BOX_RIGHT,  Vector( 0,  1,  0) },
		{ BOX_LEFT,   Vector( 0, -1,  0) },
		{ BOX_TOP,    Vector( 0,  0,  1) },
		{ BOX_BOTTOM, Vector( 0,  0, -1) },
	}
	for i, f in ipairs(faces) do
		local w

		if     f[1] == BOX_TOP    then w = 0.95
		elseif f[1] == BOX_BOTTOM then w = 0.12
		else   w = BOX_FILL + (1 - BOX_FILL) * math.max(0, f[2]:Dot(SUN_DIR)) ^ 0.75 end
		BOX_W[i] = { f[1], w }
	end
end

local function applyModelLighting(ar, ag, ab, sr, sg, sb)
	render.ResetModelLighting(ar, ag, ab)
	for i = 1, 6 do
		local f = BOX_W[i]
		local w = f[2]
		render.SetModelLighting(f[1], ar + sr * w, ag + sg * w, ab + sb * w)
	end
end

local function pushTri(tris, a, b, c, base)
	local nrm = (b - a):Cross(c - a)
	if nrm:LengthSqr() > 0 then nrm:Normalize() end
	local d = math.max(0, nrm:Dot(SUN_DIR))
	tris[#tris + 1] = {
		a, b, c,
		r = math.floor(math.Clamp(base.r * (AMB_COL.x + SUN_COL.x * d), 0, 255)),
		g = math.floor(math.Clamp(base.g * (AMB_COL.y + SUN_COL.y * d), 0, 255)),
		b = math.floor(math.Clamp(base.b * (AMB_COL.z + SUN_COL.z * d), 0, 255)),
	}
end

local function chunkColor(tris, into, alpha)
	alpha = alpha or 255
	local total, i = #tris, 1
	while i <= total do
		local last = math.min(i + MAX_TRIS - 1, total)
		local m = Mesh(boardMat)
		mesh.Begin(m, MATERIAL_TRIANGLES, last - i + 1)
		for t = i, last do
			local d = tris[t]
			for v = 1, 3 do
				mesh.Position(d[v])
				mesh.Color(d.r, d.g, d.b, alpha)
				mesh.TexCoord(0, 0, 0)
				mesh.AdvanceVertex()
			end
		end
		mesh.End()
		into[#into + 1] = m
		i = last + 1
	end
end

local function destroyList(list) for _, m in ipairs(list) do if m and m.Destroy then m:Destroy() end end end
local function destroyBoard()
	destroyList(ME.BoardMeshes); ME.BoardMeshes = {}
	destroyList(ME.WaterMeshes); ME.WaterMeshes = {}
	for _, e in ipairs(ME.BoardDecor) do if IsValid(e) then e:Remove() end end
	ME.BoardDecor = {}
	for _, e in ipairs(ME.CoreModels) do if IsValid(e) then e:Remove() end end
	ME.CoreModels = {}
	goldEmitters = {}
end

local function buildLand(baseZ)
	destroyList(ME.BoardMeshes); ME.BoardMeshes = {}
	local H         = ME.Config.Heights or {}
	local waterZ    = baseZ + (H.water or -24)
	local baseLevel = waterZ - (ME.Config.CliffDepth or 16)
	local landAmp   = ME.Config.LandGradient or 4
	local side      = ME.Config.Colors.rockSide or Color(104, 100, 96)
	local dirt      = ME.Config.Colors.dirt or Color(126, 88, 54)
	local sandSide  = ME.Config.Colors.sandSide or Color(196, 158, 96)
	local darkRock  = ME.Config.Colors.darkRock or Color(74, 78, 86)
	local HS        = ME.Config.HexSize or 96
	local tris = {}

	for _, cell in pairs(ME.BoardCells) do
		if cell.biome ~= "water" then
			local isMtn  = cell.decor == "mountain"
			local isDark = cell.decor == "gold" or cell.biome == "rock"
			local topZ   = baseZ + ME.SurfaceOffset(cell.q, cell.r, cell.biome)
			local center = ME.HexToWorld(cell.q, cell.r, topZ)
			local cs     = ME.HexCorners(center, topZ)
			local topC = isMtn and side or (isDark and darkRock or cfgColor(cell.biome))
			local vr, vg, vb = vary(topC, cell.q, cell.r, landAmp)
			local base = Color(vr, vg, vb)
			local wallCol = isMtn and side or (isDark and darkRock or (cell.biome == "sand" and sandSide or dirt))
			local rim = Color(base.r * 0.99, base.g * 0.99, base.b * 0.99)
			local INSET, DIP = 0.98, 1.5
			local inner = {}
			for i = 1, 6 do inner[i] = center + (cs[i] - center) * INSET end
			for i = 1, 6 do pushTri(tris, center, inner[i], inner[(i % 6) + 1], base) end
			for i = 1, 6 do
				local nidx = (i % 6) + 1
				local A, B = cs[i], cs[nidx]
				local oA = Vector(A.x, A.y, topZ - DIP)
				local oB = Vector(B.x, B.y, topZ - DIP)
				pushTri(tris, inner[i], inner[nidx], oB, rim)
				pushTri(tris, inner[i], oB, oA, rim)
				local mid = (A + B) * 0.5
				local nq, nr = ME.WorldToHex(mid + (mid - center):GetNormalized() * HS * 0.6)
				local nc = ME.BoardCells[ME.HexKey(nq, nr)]
				local higher = nc and nc.biome ~= "water"
					and (baseZ + ME.SurfaceOffset(nq, nr, nc.biome)) >= topZ - 0.5
				if not higher then
					pushTri(tris, oA, oB, Vector(B.x, B.y, baseLevel), wallCol)
					pushTri(tris, oA, Vector(B.x, B.y, baseLevel), Vector(A.x, A.y, baseLevel), wallCol)
				end
			end
		end
	end

	chunkColor(tris, ME.BoardMeshes)
end

local function buildWater(baseZ)
	destroyList(ME.WaterMeshes); ME.WaterMeshes = {}
	local H      = ME.Config.Heights or {}
	local waterZ = baseZ + (H.water or -24)
	local wcol   = ME.Config.Colors.water
	local tris = {}
	local S = 30000
	pushTri(tris, Vector(-S,-S,waterZ), Vector(S,-S,waterZ), Vector(S,S,waterZ),  wcol)
	pushTri(tris, Vector(-S,-S,waterZ), Vector(S,S,waterZ),  Vector(-S,S,waterZ), wcol)
	chunkColor(tris, ME.WaterMeshes, WATER_ALPHA)
end

local function pickVariant(list, q, r)
	if type(list) ~= "table" then return list end
	local n = #list
	if n == 0 then return nil end
	return list[(math.floor(math.abs(math.sin(q * 12.9 + r * 4.7) * 1000)) % n) + 1]
end

local function spawnDecor(baseZ)
	local scale = ME.Config.DecorScale or 1
	local BUCKET, placed = 256, {}
	local function near(x, y, rad)
		local bx, by = math.floor(x / BUCKET), math.floor(y / BUCKET)
		for ox = -1, 1 do for oy = -1, 1 do
			local b = placed[(bx + ox) .. "," .. (by + oy)]
			if b then for _, pp in ipairs(b) do
				local dx, dy, rr = x - pp.x, y - pp.y, (rad + pp.r) * 0.55
				if dx * dx + dy * dy < rr * rr then return true end
			end end
		end end
		return false
	end
	local function add(x, y, rad) local k = math.floor(x / BUCKET) .. "," .. math.floor(y / BUCKET); placed[k] = placed[k] or {}; placed[k][#placed[k] + 1] = { x = x, y = y, r = rad } end

	local palmSink = ME.Config.PalmSink or 0
	ME.MountainSpots, ME.GoldSpots, ME.SlotSpots, ME.OilSpots = {}, {}, {}, {}
	for _, cell in pairs(ME.BoardCells) do
		local topZ = baseZ + ME.SurfaceOffset(cell.q, cell.r, cell.biome)
		if cell.decor == "gold" then
			ME.GoldSpots[#ME.GoldSpots + 1] = ME.HexToWorld(cell.q, cell.r, topZ)
		elseif cell.decor == "slot" then
			ME.SlotSpots[#ME.SlotSpots + 1] = ME.HexToWorld(cell.q, cell.r, topZ)
		elseif cell.decor == "oilspot" then
			ME.OilSpots[#ME.OilSpots + 1] = ME.HexToWorld(cell.q, cell.r, topZ)
		elseif cell.decor ~= "none" then
			local isMtn, isPalm = cell.decor == "mountain", cell.decor == "palm"
			local mdl = pickVariant(ME.Config.Models[cell.decor], cell.q, cell.r)
			if mdl then
				local cw = ME.HexToWorld(cell.q, cell.r, topZ)
				local e = ClientsideModel(mdl, RENDERGROUP_OTHER)
				if IsValid(e) then
					local mscale = scale * ((ME.Config.ModelScale and ME.Config.ModelScale[mdl]) or 1)
					if mscale ~= 1 then e:SetModelScale(mscale, 0) end
					local mins, maxs = e:OBBMins(), e:OBBMaxs()
					local rad = math.max(maxs.x - mins.x, maxs.y - mins.y) * 0.5 * mscale
					if not isMtn and near(cw.x, cw.y, rad) then
						e:Remove()
					else
						local sink = isPalm and palmSink or 0
						e:SetPos(Vector(cw.x, cw.y, topZ - mins.z * mscale - sink))
						local yaw = isMtn and ((cell.q * 2 + cell.r) % 6) * 60 or (cell.q * 53 + cell.r * 131) % 360
						e:SetAngles(Angle(0, yaw, 0))
						if not isMtn then add(cw.x, cw.y, rad) end
						ME.BoardDecor[#ME.BoardDecor + 1] = e
						if isMtn then
							ME.MountainSpots[#ME.MountainSpots + 1] = ME.HexToWorld(cell.q, cell.r, topZ + (maxs.z - mins.z) * mscale * 0.5)
						end
					end
				end
			end
		end
	end
end

local function spawnSandPebbles(baseZ)
	local pebble, HS = "models/merge_empires/caillou.mdl", ME.Config.HexSize or 96
	local base = (ME.Config.DecorScale or 1) / 3
	for _, cell in pairs(ME.BoardCells) do
		if cell.biome == "sand" then
			local topZ = baseZ + ME.SurfaceOffset(cell.q, cell.r, cell.biome)
			local cw   = ME.HexToWorld(cell.q, cell.r, topZ)
			local h3 = math.abs(math.sin(cell.q * 33.1 + cell.r * 9.7))
			local e = ClientsideModel(pebble, RENDERGROUP_OTHER)
			if IsValid(e) then
				local ms = base * (0.6 + h3 * 0.9)
				e:SetModelScale(ms, 0)
				local mins = e:OBBMins()
				e:SetPos(Vector(cw.x, cw.y, topZ - mins.z * ms))
				e:SetAngles(Angle(0, 0, 0))
				ME.BoardDecor[#ME.BoardDecor + 1] = e
			end
		end
	end
end

local function spawnTallGrass(baseZ)
	local scale = ME.Config.DecorScale or 1
	local drand = ME.GrassRand

	local spawnHexes = {}
	for _, sv in ipairs((ME.MapInfo and ME.MapInfo.spawns) or {}) do
		local sq, sr = ME.WorldToHex(sv)
		spawnHexes[#spawnHexes + 1] = { q = sq, r = sr }
	end

	local plan, cover = ME.GrassPlan(ME.BoardCells, spawnHexes)
	ME.GrassCover = cover

	for _, p in ipairs(plan) do
		local topZ = baseZ + ME.SurfaceOffset(p.q, p.r, "grass")
		local c    = ME.HexToWorld(p.q, p.r, topZ)
		for i = 1, p.count do
			local ang = drand(p.seed + i,     c.x) * math.pi * 2
			local rad = drand(p.seed + i * 7, c.y) * 6 + 1
			local e   = ClientsideModel(ME.GrassModel, RENDERGROUP_OTHER)
			if IsValid(e) then
				local ms = scale * (0.82 + drand(p.seed + i * 3, c.z) * 0.38)
				if ms ~= 1 then e:SetModelScale(ms, 0) end
				local mins = e:OBBMins()
				e:SetPos(Vector(c.x + math.cos(ang) * rad, c.y + math.sin(ang) * rad, c.z - mins.z * ms))
				e:SetAngles(Angle(0, math.floor(drand(p.seed + i * 5, c.x) * 360), 0))
				ME.BoardDecor[#ME.BoardDecor + 1] = e
			end
		end
	end
end

local function spawnCoreModels()
	for _, e in ipairs(ME.CoreModels) do if IsValid(e) then e:Remove() end end
	ME.CoreModels = {}
	local spawns = ME.MapInfo and ME.MapInfo.spawns
	if not spawns then return end
	local cs = ME.Config.CoreScale or 1
	for i = 1, #spawns do
		local sv = spawns[i]
		local f  = ME.GetFaction(i)
		local mdl = f and f.core
		if sv and mdl then
			local e = ClientsideModel(mdl, RENDERGROUP_OTHER)
			if IsValid(e) then
				if cs ~= 1 then e:SetModelScale(cs, 0) end
				e:SetPos(sv + Vector(0, 0, 1))

				e:SetAngles(Angle(0, (ME.Config.CoreYaw or 0) + i * 60, 0))
				e.MEFaction = i
				ME.CoreModels[#ME.CoreModels + 1] = e
			end
		end
	end
end

net.Receive("ME_Board", function()

	ME.SfxGraceUntil = RealTime() + 6
	local seed   = net.ReadUInt(32)
	local radius = net.ReadUInt(8)
	local baseZ  = net.ReadFloat()
	local center = net.ReadVector()
	local nFac   = net.ReadUInt(4)
	local spawns = {}
	for i = 1, nFac do spawns[i] = net.ReadVector() end

	local cells = {}
	ME.HexEachInRadius(radius, function(q, r)
		local biome = ME.BIOME_NAME[net.ReadUInt(3)] or "water"
		local decor = ME.DECOR_NAME[net.ReadUInt(3)] or "none"
		cells[ME.HexKey(q, r)] = { q = q, r = r, biome = biome, decor = decor }
	end)

	ME.BoardCells = cells
	ME.MapInfo = ME.MapInfo or {}
	ME.MapInfo.seed, ME.MapInfo.radius, ME.MapInfo.baseZ, ME.MapInfo.center, ME.MapInfo.spawns = seed, radius, baseZ, center, spawns

	local t = LocalPlayer():Team()
	if spawns[t] then ME.Cam.focus = Vector(spawns[t].x, spawns[t].y, spawns[t].z) end

	local spawnHexes = {}
	for i = 1, nFac do
		local sv = spawns[i]
		if sv then local sq, sr = ME.WorldToHex(sv); spawnHexes[i] = { q = sq, r = sr } end
	end
	ME.BuildFlatHexes(spawnHexes)
	ME.BuildBeachRamps(cells)

	destroyBoard()
	buildLand(baseZ)
	buildWater(baseZ)
	spawnDecor(baseZ)
	spawnSandPebbles(baseZ)
	spawnTallGrass(baseZ)
	spawnCoreModels()
end)

local function tideBob()
	local amp, spd = ME.Config.WaveAmplitude or 13, ME.Config.WaveSpeed or 1
	if amp == 0 then return 0 end
	local t = RealTime() * spd
	return (math.sin(t * 0.5) * 0.5 + math.sin(t * 0.23 + 1.3) * 0.32 + math.sin(t * 0.11 + 2.7) * 0.28) * amp
end

hook.Add("PostDrawOpaqueRenderables", "ME_BoardDraw", function(_, sky)
	if sky then return end
	render.SetMaterial(boardMat)
	for _, m in ipairs(ME.BoardMeshes) do m:Draw() end
end)

local function drawLitModels(list)
	for i = 1, #list do
		local e = list[i]
		if IsValid(e) then e:DrawModel() end
	end
end

local function drawUnits()
	if not ME.UnitModels then return end
	for idx, rec in pairs(ME.UnitModels) do
		if IsValid(rec.model) then
			if not rec.sub then
				rec.model:SetupBones()
				rec.model:DrawModel()

				if IsValid(rec.wep) then
					local wp, wa = ME.HandPose(rec.model)
					if wp then
						rec.wep:SetPos(wp)
						rec.wep:SetAngles(wa)
						rec.wep:SetupBones()
						rec.wep:DrawModel()
					end
				end
			end
		else
			if IsValid(rec.wep) then rec.wep:Remove() end
			ME.UnitModels[idx] = nil
		end
	end
end

local function drawBuildings()
	if not ME.BuildingModels then return end
	local now = RealTime()
	for idx, rec in pairs(ME.BuildingModels) do
		local cm = rec.model
		if IsValid(cm) then

			if rec.built and rec.bid ~= "naval_mine" then
				local df = rec._destroyFade
				local bs = rec._burnStart
				if df then
					local f = (now - df) / 0.35
					if f >= 1 then cm:Remove(); ME.BuildingModels[idx] = nil
					else
						render.SetColorModulation(1 - f * 0.5, 1 - f * 0.6, 1 - f * 0.6)
						render.SetBlend(1 - f)
						cm:DrawModel()
						render.SetBlend(1); render.SetColorModulation(1, 1, 1)
					end
				elseif bs and now >= bs then
					local f = (now - bs) / (rec._burnDur or 3.2)
					local a = f < 0.55 and 1 or math.max(0, 1 - (f - 0.55) / 0.45)
					render.SetColorModulation(1 - f * 0.62, (1 - f * 0.8) * 0.9, (1 - f * 0.82) * 0.8)
					render.SetBlend(a)
					cm:DrawModel()
					render.SetBlend(1); render.SetColorModulation(1, 1, 1)
				else
					cm:DrawModel()
				end
			end
		else
			ME.BuildingModels[idx] = nil
		end
	end
end

local MINE_FADE = 0.55

local function drawNavalMines()
	if not ME.BuildingModels then return end
	render.OverrideDepthEnable(true, true)
	render.SuppressEngineLighting(true)

	applyModelLighting(AMB_COL.x + 0.30, AMB_COL.y + 0.30, AMB_COL.z + 0.26,
	                   SUN_COL.x + 0.10, SUN_COL.y + 0.10, SUN_COL.z + 0.10)
	local now, gone = RealTime(), nil
	for idx, rec in pairs(ME.BuildingModels) do
		if rec.built and rec.bid == "naval_mine" and IsValid(rec.model) then

			local a = 1
			if rec._hideFade then
				a = 1 - (now - rec._hideFade) / MINE_FADE
				if a <= 0 then gone = gone or {}; gone[#gone + 1] = idx; a = 0 end
			elseif rec._revealAt then
				a = (now - rec._revealAt) / MINE_FADE
				if a >= 1 then rec._revealAt, a = nil, 1 end
			end
			if a > 0.002 then
				render.SetBlend(a)
				rec.model:DrawModel()
			end
		end
	end
	render.SetBlend(1)
	render.SuppressEngineLighting(false)
	render.OverrideDepthEnable(false, false)
	if gone then
		for _, idx in ipairs(gone) do
			local rec = ME.BuildingModels[idx]
			if rec and IsValid(rec.model) then rec.model:Remove() end
			ME.BuildingModels[idx] = nil
		end
	end
end

local BP_BLUE   = { 0.42, 0.72, 1.0 }
local BP_AMBER  = { 1.0,  0.6,  0.18 }
local BP_ALPHA  = 0.5
local BP_REVEAL = 0.7
local BP_BANDS  = 6

local function drawPillars(cm, col, alpha, hfrac, small)
	local mins, maxs = cm:GetModelRenderBounds()
	local sc = cm:GetModelScale(); if not sc or sc == 0 then sc = 1 end
	local rx = math.max(math.abs(maxs.x - mins.x), math.abs(maxs.y - mins.y)) * sc * 0.5 * (small and 0.62 or 0.8)
	local h  = math.max(small and 22 or 34, (maxs.z - mins.z) * sc * (small and 1.1 or 1.4)) * (hfrac or 1)
	local a  = math.floor(230 * (alpha or 1))
	if a <= 3 or h < 2 or rx < 4 then return end
	local base = cm:GetPos()
	local w    = math.Clamp(rx * (small and 0.05 or 0.06), small and 1.0 or 1.6, small and 2.2 or 3.5)
	local c    = Color(col[1] * 255, col[2] * 255, col[3] * 255, a)
	render.SetColorMaterial()
	for _, s in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		local cx, cy = base.x + s[1] * rx, base.y + s[2] * rx
		local z0, z1 = base.z, base.z + h
		for _, d in ipairs({ { w, 0 }, { 0, w } }) do
			local p1 = Vector(cx - d[1], cy - d[2], z0)
			local p2 = Vector(cx + d[1], cy + d[2], z0)
			local p3 = Vector(cx + d[1], cy + d[2], z1)
			local p4 = Vector(cx - d[1], cy - d[2], z1)
			render.DrawQuad(p1, p2, p3, p4, c)
			render.DrawQuad(p4, p3, p2, p1, c)
		end
	end
end

local function drawBlueprints()
	if not ME.BuildingModels then return end
	render.SuppressEngineLighting(true)
	applyModelLighting(0.62, 0.66, 0.72, 0.9, 0.95, 1.0)
	for _, rec in pairs(ME.BuildingModels) do
		local cm = rec.model
		if IsValid(cm) then
			if not rec.built then
				local col   = rec.builderNear and BP_BLUE or BP_AMBER
				local small = ME.IsEdgeBuilding and ME.IsEdgeBuilding(rec.bid)

				render.SetColorModulation(col[1], col[2], col[3])
				render.SetBlend(BP_ALPHA)
				cm:DrawModel()
				render.SetBlend(1); render.SetColorModulation(1, 1, 1)
				drawPillars(cm, col, 1, 1, small)

				local p = rec.progress or 0
				if p > 0.001 then
					local mins, maxs = cm:GetModelRenderBounds()
					local scb  = cm:GetModelScale(); if not scb or scb == 0 then scb = 1 end
					local base = cm:GetPos()
					local botZ = base.z + mins.z * scb
					local H    = math.max(1, (maxs.z - mins.z) * scb)
					local DROP = math.Clamp(H * 2.4, 160, 460)
					render.SuppressEngineLighting(true)
					applyModelLighting(AMB_COL.x + 0.24, AMB_COL.y + 0.24, AMB_COL.z + 0.2,
					                   SUN_COL.x + 0.16, SUN_COL.y + 0.13, SUN_COL.z + 0.1)
					render.EnableClipping(true)
					for i = 0, BP_BANDS - 1 do
						local t0 = i / BP_BANDS
						if p > t0 then
							local zi  = botZ + H * (i / BP_BANDS)
							local zi1 = botZ + H * ((i + 1) / BP_BANDS)
							local f   = math.Clamp((p - t0) / (1 / BP_BANDS), 0, 1)
							local fd  = math.Clamp(f / 0.55, 0, 1)
							local dz  = DROP * ((1 - fd) ^ 3)
							cm:SetPos(base + Vector(0, 0, dz))
							render.PushCustomClipPlane(Vector(0, 0, 1),  zi  + dz - 0.4)
							render.PushCustomClipPlane(Vector(0, 0, -1), -(zi1 + dz + 0.4))
							if fd < 1 then
								render.SetColorModulation(0.66, 0.86, 1.0)
								render.SetBlend(0.6 + 0.4 * fd)
							end
							cm:DrawModel()
							render.SetColorModulation(1, 1, 1); render.SetBlend(1)
							render.PopCustomClipPlane(); render.PopCustomClipPlane()
						end
					end
					render.EnableClipping(false)
					cm:SetPos(base)

					applyModelLighting(0.62, 0.66, 0.72, 0.9, 0.95, 1.0)
				end
			elseif rec._builtAt then
				local age = RealTime() - rec._builtAt
				if age >= BP_REVEAL then rec._builtAt = nil
				else
					local f = 1 - age / BP_REVEAL
					render.SetColorModulation(BP_BLUE[1], BP_BLUE[2], BP_BLUE[3])
					render.SetBlend(BP_ALPHA * f)
					cm:DrawModel()
					render.SetBlend(1); render.SetColorModulation(1, 1, 1)
					drawPillars(cm, BP_BLUE, f, f)
				end
			end
		end
	end
	render.SuppressEngineLighting(false)
end

local OUTLINE_PX  = 2.6

local OUTLINE_MAT = CreateMaterial("me_outline_flat", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$model"]       = "1",
	["$nocull"]      = "1",
})
local function outlineDraw(items)
	if #items == 0 then return end

	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(0xFF)
	render.SetStencilTestMask(0xFF)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)

	render.OverrideColorWriteEnable(true, false)
	for _, it in ipairs(items) do it[1]:DrawModel() end
	render.OverrideColorWriteEnable(false)

	render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
	render.SetStencilPassOperation(STENCIL_KEEP)
	render.MaterialOverride(OUTLINE_MAT)
	render.SetBlend(1)

	local insIdx = ME.Cam and ME.Cam.inspect and ME.Cam.inspect.kind == "building" and ME.Cam.inspect.idx
	local selModel = insIdx and ME.BuildingModels and ME.BuildingModels[insIdx] and ME.BuildingModels[insIdx].model
	for _, it in ipairs(items) do
		local cm, fac = it[1], it[2]
		local base = cm:GetModelScale(); if base == 0 then base = 1 end
		local col  = (cm == selModel) and Color(255, 255, 255) or ME.FactionColor(fac)
		local diag = math.max(cm:OBBMaxs():Distance(cm:OBBMins()), 1)
		local sc   = base * (1 + (OUTLINE_PX * (cm == selModel and 2.6 or 2)) / diag)
		render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
		cm:SetModelScale(sc, 0)
		cm:SetupBones()
		cm:DrawModel()
		cm:SetModelScale(base, 0)
	end
	render.MaterialOverride(nil)
	render.SetColorModulation(1, 1, 1)
	render.SetStencilEnable(false)
end

local function outlineList()
	local items = {}
	for _, cm in ipairs(ME.CoreModels) do
		if IsValid(cm) and (cm.MEFaction or 0) > 0 then items[#items + 1] = { cm, cm.MEFaction } end
	end
	if ME.BuildingModels then
		for _, rec in pairs(ME.BuildingModels) do
			if rec.built and IsValid(rec.model) and (rec.faction or 0) > 0 and not rec._burnStart then
				items[#items + 1] = { rec.model, rec.faction }
			end
		end
	end
	if ME.UnitModels then
		for _, rec in pairs(ME.UnitModels) do

			if IsValid(rec.model) and (rec.faction or 0) > 0 and not rec.sub then
				items[#items + 1] = { rec.model, rec.faction }
			end
		end
	end
	outlineDraw(items)
end

local SUB_SINK = 0.5

local function subSink(rec)
	if rec._sink then return rec._sink end
	local mins, maxs = ME.UnitBounds(rec.kind, rec.model)
	local sc = rec.model:GetModelScale(); if not sc or sc == 0 then sc = 1 end
	local k = ME.UnitKinds and ME.UnitKinds[rec.kind]
	local f = (k and isnumber(k.submerge) and k.submerge) or SUB_SINK
	rec._sink = math.max(4, (maxs.z - mins.z) * sc * f)
	return rec._sink
end

local function sinkSubs(bob)
	if not ME.UnitModels then return nil end
	local subs
	for _, rec in pairs(ME.UnitModels) do
		if rec.sub and IsValid(rec.model) then
			subs = subs or {}
			local p = rec.model:GetPos()
			subs[#subs + 1] = { rec = rec, pos = p }
			rec.model:SetPos(p - Vector(0, 0, subSink(rec) - (bob or 0)))
		end
	end
	return subs
end

local function raiseSubs(subs)
	if not subs then return end
	for _, s in ipairs(subs) do if IsValid(s.rec.model) then s.rec.model:SetPos(s.pos) end end
end

local function drawSubmarines(subs)
	if not subs then return end

	render.OverrideDepthEnable(true, true)
	render.SuppressEngineLighting(true)

	applyModelLighting(AMB_COL.x + 0.34, AMB_COL.y + 0.34, AMB_COL.z + 0.30,
	                   SUN_COL.x + 0.10, SUN_COL.y + 0.10, SUN_COL.z + 0.10)
	for _, s in ipairs(subs) do
		local m = s.rec.model
		if IsValid(m) then m:SetupBones(); m:DrawModel() end
	end
	render.SuppressEngineLighting(false)
	render.OverrideDepthEnable(false, false)
end

local function outlineSubs(subs)
	if not subs then return end
	local items = {}
	for _, s in ipairs(subs) do
		local rec = s.rec
		if IsValid(rec.model) and (rec.faction or 0) > 0 then items[#items + 1] = { rec.model, rec.faction } end
	end
	outlineDraw(items)
end

hook.Add("PostDrawOpaqueRenderables", "ME_DecorDraw", function(_, sky)
	if sky then return end
	render.SuppressEngineLighting(true)
	render.SetColorModulation(1, 1, 1)
	render.SetBlend(1)
	applyModelLighting(AMB_COL.x, AMB_COL.y, AMB_COL.z, SUN_COL.x, SUN_COL.y, SUN_COL.z)
		drawLitModels(ME.BoardDecor)
		drawLitModels(ME.CoreModels)

		applyModelLighting(AMB_COL.x + 0.28, AMB_COL.y + 0.28, AMB_COL.z + 0.24,
		                   SUN_COL.x + 0.18, SUN_COL.y + 0.14, SUN_COL.z + 0.10)
		drawBuildings()

		applyModelLighting(AMB_COL.x, AMB_COL.y, AMB_COL.z, SUN_COL.x, SUN_COL.y, SUN_COL.z)
		drawUnits()
	render.SuppressEngineLighting(false)
	outlineList()
end)

local fogSpriteMat  = Material("particle/smokesprites_0001")
local gnatSpriteMat = Material("sprites/light_glow02_add")

local function drawMountainFog()
	local spots = ME.MountainSpots
	if not spots or #spots == 0 then return end
	local t   = RealTime()
	local eye = EyePos()
	render.SetMaterial(fogSpriteMat)
	for si, s in ipairs(spots) do
		if s:DistToSqr(eye) > 8000 * 8000 then continue end
		for wi = 1, 4 do
			local phase    = si * 5.73 + wi * 1.27
			local lifetime = 5.5 + math.abs(math.sin(phase)) * 3
			local tl       = (t * 0.7 + phase * lifetime) % lifetime
			local frac     = tl / lifetime
			local angle    = phase + tl * 0.4
			local drift    = 22 + math.abs(math.sin(phase * 2.3)) * 18
			local pos      = Vector(
				s.x + math.cos(angle) * drift,
				s.y + math.sin(angle) * drift,
				s.z + frac * 88 + math.sin(tl * 1.1) * 5
			)
			local a
			if frac < 0.25 then a = frac / 0.25 * 30
			elseif frac < 0.6 then a = 30
			else a = (1 - frac) / 0.4 * 30 end
			local sz = (26 + frac * 88) * (0.9 + 0.1 * math.sin(phase * 7))
			if a > 3 then render.DrawSprite(pos, sz, sz, Color(168, 172, 180, math.floor(a))) end
		end
	end
end

local beamMat = CreateMaterial("me_corebeam", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite", ["$additive"] = "1",
	["$vertexcolor"] = "1", ["$vertexalpha"] = "1", ["$nocull"] = "1",
})
local function drawBeam(base, col)
	local H, W, SEGS, VS = 1100, 6, 3, 12
	local t = RealTime()
	local pulse = 0.72 + 0.28 * math.sin(t * 2.2)
	local function inten(f)
		local band = 0.5 + 0.5 * math.sin(f * 7.0 - t * 5.0)
		return (1 - f) * pulse * (0.45 + 0.55 * band)
	end
	mesh.Begin(MATERIAL_QUADS, SEGS * VS)
	for s = 0, SEGS - 1 do
		local a = (s / SEGS) * math.pi
		local dx, dy = math.cos(a) * W, math.sin(a) * W
		for v = 0, VS - 1 do
			local f0, f1 = v / VS, (v + 1) / VS
			local i0, i1 = inten(f0), inten(f1)
			local z0, z1 = base.z + f0 * H, base.z + f1 * H
			local r0, g0, b0 = math.floor(col.r * i0), math.floor(col.g * i0), math.floor(col.b * i0)
			local r1, g1, b1 = math.floor(col.r * i1), math.floor(col.g * i1), math.floor(col.b * i1)
			mesh.Position(Vector(base.x - dx, base.y - dy, z0)); mesh.Color(r0, g0, b0, 255); mesh.AdvanceVertex()
			mesh.Position(Vector(base.x + dx, base.y + dy, z0)); mesh.Color(r0, g0, b0, 255); mesh.AdvanceVertex()
			mesh.Position(Vector(base.x + dx, base.y + dy, z1)); mesh.Color(r1, g1, b1, 255); mesh.AdvanceVertex()
			mesh.Position(Vector(base.x - dx, base.y - dy, z1)); mesh.Color(r1, g1, b1, 255); mesh.AdvanceVertex()
		end
	end
	mesh.End()
end

local function drawRipples(base, col, maxA)
	local SEGS, CYCLE, RINGS = 30, 2.0, 3
	for k = 0, RINGS - 1 do
		local phase = ((RealTime() / CYCLE) + k / RINGS) % 1
		local rad   = 12 + phase * 82
		local inten = (1 - phase) * 0.9
		if inten > 0.02 then
			local r, g, b = math.floor(col.r * inten), math.floor(col.g * inten), math.floor(col.b * inten)
			local a = maxA and math.floor(maxA * inten) or 255
			local T = 3 + phase * 5
			local ri, ro = rad - T, rad + T
			mesh.Begin(MATERIAL_TRIANGLES, SEGS * 2)
			for s = 0, SEGS - 1 do
				local a0, a1 = (s / SEGS) * math.pi * 2, ((s + 1) / SEGS) * math.pi * 2
				local c0, s0, c1, s1 = math.cos(a0), math.sin(a0), math.cos(a1), math.sin(a1)
				local i0 = Vector(base.x + c0 * ri, base.y + s0 * ri, base.z)
				local o0 = Vector(base.x + c0 * ro, base.y + s0 * ro, base.z)
				local i1 = Vector(base.x + c1 * ri, base.y + s1 * ri, base.z)
				local o1 = Vector(base.x + c1 * ro, base.y + s1 * ro, base.z)
				mesh.Position(i0); mesh.Color(r, g, b, a); mesh.AdvanceVertex()
				mesh.Position(o0); mesh.Color(r, g, b, a); mesh.AdvanceVertex()
				mesh.Position(o1); mesh.Color(r, g, b, a); mesh.AdvanceVertex()
				mesh.Position(i0); mesh.Color(r, g, b, a); mesh.AdvanceVertex()
				mesh.Position(o1); mesh.Color(r, g, b, a); mesh.AdvanceVertex()
				mesh.Position(i1); mesh.Color(r, g, b, a); mesh.AdvanceVertex()
			end
			mesh.End()
		end
	end
end

local goldDecalMat = CreateMaterial("me_gold_decal", "UnlitGeneric", {
	["$basetexture"] = "mergeempires/map/floor/me_gold",
	["$additive"] = "1", ["$nocull"] = "1",
	["$vertexcolor"] = "1", ["$vertexalpha"] = "1",
})
local goldEmitters = {}
local function drawGoldGnats()
	local spots = ME.GoldSpots
	if not spots or #spots == 0 then return end
	local t  = RealTime()
	local HS = ME.Config.HexSize or 96
	render.SetMaterial(gnatSpriteMat)
	for si, s in ipairs(spots) do
		for gi = 1, 4 do
			local phase    = si * 6.11 + gi * 2.71
			local lifetime = 2.2 + math.abs(math.sin(phase * 1.3)) * 1.5
			local tl       = (t * 0.85 + phase * lifetime) % lifetime
			local frac     = tl / lifetime
			local ox = math.sin(phase * 5.1 + tl * 2.3) * HS * 0.28
			local oy = math.cos(phase * 3.7 + tl * 1.9) * HS * 0.28
			local pos = Vector(s.x + ox, s.y + oy, s.z + frac * 44)
			local a
			if frac < 0.2 then a = frac / 0.2
			elseif frac < 0.8 then a = 1
			else a = (1 - frac) / 0.2 end
			a = a * (0.60 + 0.40 * math.abs(math.sin(t * 9.3 + phase)))
			a = math.floor(a * 225)
			local sz = 4 + math.abs(math.sin(phase * 7 + tl * 3)) * 3
			if a > 10 then render.DrawSprite(pos, sz, sz, Color(255, 210, 40, a)) end
		end
	end
end

local function drawGoldDecal(center)
	local HS    = ME.Config.HexSize or 96
	local z     = center.z + 2.5
	local cz    = Vector(center.x, center.y, z)
	local cs    = ME.HexCorners(cz, z)
	local SQRT3 = math.sqrt(3)
	local function uv(p)
		return (p.x - center.x) / (HS * SQRT3) + 0.5,
		       (p.y - center.y) / (HS * 2)     + 0.5
	end

	render.SetMaterial(goldDecalMat)
	mesh.Begin(MATERIAL_TRIANGLES, 6)
	for i = 1, 6 do
		local n = (i % 6) + 1
		local u0, v0 = uv(cz); local u1, v1 = uv(cs[i]); local u2, v2 = uv(cs[n])
		mesh.Position(cz);    mesh.Color(255, 255, 255, 255); mesh.TexCoord(0, u0, v0); mesh.AdvanceVertex()
		mesh.Position(cs[i]); mesh.Color(255, 255, 255, 255); mesh.TexCoord(0, u1, v1); mesh.AdvanceVertex()
		mesh.Position(cs[n]); mesh.Color(255, 255, 255, 255); mesh.TexCoord(0, u2, v2); mesh.AdvanceVertex()
	end
	mesh.End()
end

local oilRippleMat = CreateMaterial("me_oil_ripple", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$vertexcolor"] = "1", ["$vertexalpha"] = "1",
	["$translucent"] = "1", ["$nocull"] = "1",
})
local OIL_GREY = Color(150, 152, 158)

local function clipPolyHex(poly, corners, center)
	for i = 1, 6 do
		if #poly == 0 then break end
		local a = corners[i]
		local e = corners[(i % 6) + 1] - a
		local n = Vector(-e.y, e.x, 0)
		if (center - a):Dot(n) < 0 then n = -n end
		local out, cnt = {}, #poly
		for j = 1, cnt do
			local cur, nxt = poly[j], poly[(j % cnt) + 1]
			local dc, dn = (cur - a):Dot(n), (nxt - a):Dot(n)
			if dc >= 0 then out[#out + 1] = cur end
			if (dc >= 0) ~= (dn >= 0) then
				local t = dc / (dc - dn)
				out[#out + 1] = cur + (nxt - cur) * t
			end
		end
		poly = out
	end
	return poly
end

local function drawSlotStripes(center)
	local HS = ME.Config.HexSize or 96
	local z  = center.z + 2.5
	local c0 = Vector(center.x, center.y, z)
	local cs = ME.HexCorners(c0, z)
	local hex = {}
	for i = 1, 6 do hex[i] = c0 + (cs[i] - c0) * 0.965 end
	local N    = 9
	local ang  = math.rad(58)
	local dir  = Vector(math.cos(ang), math.sin(ang), 0)
	local perp = Vector(-dir.y, dir.x, 0)
	local spacing, barW, L = HS * 0.2, HS * 0.075, HS * 2
	local polys, ntri = {}, 0
	for i = 1, N do
		local c2 = c0 + perp * ((i - (N + 1) / 2) * spacing)
		local rect = { c2 - dir * L - perp * barW, c2 + dir * L - perp * barW,
		               c2 + dir * L + perp * barW, c2 - dir * L + perp * barW }
		local p = clipPolyHex(rect, hex, c0)
		if #p >= 3 then polys[#polys + 1] = p; ntri = ntri + (#p - 2) end
	end
	if ntri == 0 then return end
	mesh.Begin(MATERIAL_TRIANGLES, ntri)
	for _, p in ipairs(polys) do
		for k = 2, #p - 1 do
			mesh.Position(p[1]);     mesh.Color(58, 64, 46, 255); mesh.AdvanceVertex()
			mesh.Position(p[k]);     mesh.Color(58, 64, 46, 255); mesh.AdvanceVertex()
			mesh.Position(p[k + 1]); mesh.Color(58, 64, 46, 255); mesh.AdvanceVertex()
		end
	end
	mesh.End()
end

local function buildingOnTile(pos)
	if not ME.BuildingModels then return false end
	local hs = (ME.Config.HexSize or 96) * 0.5
	local r2 = hs * hs
	for _, rec in pairs(ME.BuildingModels) do
		local m = rec.model
		if IsValid(m) then
			local mp = m:GetPos()
			local dx, dy = mp.x - pos.x, mp.y - pos.y
			if dx * dx + dy * dy < r2 then return true end
		end
	end
	return false
end

local function drawSelectionHex()
	local ins = ME.Cam and ME.Cam.inspect
	if not ins then return end

	if ins.kind == "building" and ME.BuildingModels and ME.BuildingModels[ins.idx] then
		local erec = ME.BuildingModels[ins.idx]
		if erec and ME.IsEdgeBuilding and ME.IsEdgeBuilding(erec.bid) then return end
	end
	local pos
	if ins.kind == "building" and ME.BuildingModels and ME.BuildingModels[ins.idx] then
		local m = ME.BuildingModels[ins.idx].model
		if IsValid(m) then pos = m:GetPos() end
	elseif ins.kind == "core" and ins.faction and ME.CoreModels then
		for _, cm in ipairs(ME.CoreModels) do
			if IsValid(cm) and cm.MEFaction == ins.faction then pos = cm:GetPos(); break end
		end
	end
	if not pos then return end
	local q, r  = ME.WorldToHex(pos)
	local cell  = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]
	local z     = ((ME.MapInfo and ME.MapInfo.baseZ) or 0) + (ME.SurfaceOffset(q, r, cell and cell.biome or "grass") or 0) + 4
	local ctr   = ME.HexToWorld(q, r, z)
	local cor   = ME.HexCorners(ctr, z)
	local pulse = 14 + math.floor(9 * math.abs(math.sin(RealTime() * 3)))

	render.SetMaterial(oilRippleMat)
	mesh.Begin(MATERIAL_TRIANGLES, 6)
	for i = 1, 6 do
		mesh.Position(ctr);              mesh.Color(255, 255, 255, pulse); mesh.AdvanceVertex()
		mesh.Position(cor[i]);           mesh.Color(255, 255, 255, pulse); mesh.AdvanceVertex()
		mesh.Position(cor[(i % 6) + 1]); mesh.Color(255, 255, 255, pulse); mesh.AdvanceVertex()
	end
	mesh.End()

	local H, botA = 20, 16
	render.SetColorMaterial()
	for _, cmode in ipairs({ MATERIAL_CULLMODE_CCW, MATERIAL_CULLMODE_CW }) do
		render.CullMode(cmode)
		mesh.Begin(MATERIAL_TRIANGLES, 12)
		for i = 1, 6 do
			local a, b   = cor[i], cor[(i % 6) + 1]
			local ta, tb = a + Vector(0, 0, H), b + Vector(0, 0, H)
			mesh.Position(a);  mesh.Color(255, 255, 255, botA); mesh.AdvanceVertex()
			mesh.Position(b);  mesh.Color(255, 255, 255, botA); mesh.AdvanceVertex()
			mesh.Position(tb); mesh.Color(255, 255, 255, 0);    mesh.AdvanceVertex()
			mesh.Position(a);  mesh.Color(255, 255, 255, botA); mesh.AdvanceVertex()
			mesh.Position(tb); mesh.Color(255, 255, 255, 0);    mesh.AdvanceVertex()
			mesh.Position(ta); mesh.Color(255, 255, 255, 0);    mesh.AdvanceVertex()
		end
		mesh.End()
	end
	render.CullMode(MATERIAL_CULLMODE_CCW)

	render.SetColorMaterial()
	for i = 1, 6 do render.DrawLine(cor[i], cor[(i % 6) + 1], Color(255, 255, 255, 130), false) end
end

local function drawPlacementHex()
	local B = ME.Build
	if not (B and B.IsPlacing and B.IsPlacing() and B.q and B.r) then return end
	local q, r  = B.q, B.r
	local cell  = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]
	local z     = ((ME.MapInfo and ME.MapInfo.baseZ) or 0) + (ME.SurfaceOffset(q, r, cell and cell.biome or "grass") or 0) + 4
	local ctr   = ME.HexToWorld(q, r, z)
	local cor   = ME.HexCorners(ctr, z)
	local cR, cG, cB
	if (not B.valid) or B.blocked then cR, cG, cB = 235, 70, 62
	elseif B.builderNear           then cR, cG, cB = 236, 238, 240
	else                                cR, cG, cB = 240, 160, 60 end
	local pulse = 18 + math.floor(12 * math.abs(math.sin(RealTime() * 3)))
	render.SetMaterial(oilRippleMat)
	mesh.Begin(MATERIAL_TRIANGLES, 6)
	for i = 1, 6 do
		mesh.Position(ctr);              mesh.Color(cR, cG, cB, pulse); mesh.AdvanceVertex()
		mesh.Position(cor[i]);           mesh.Color(cR, cG, cB, pulse); mesh.AdvanceVertex()
		mesh.Position(cor[(i % 6) + 1]); mesh.Color(cR, cG, cB, pulse); mesh.AdvanceVertex()
	end
	mesh.End()
	render.SetColorMaterial()
	for i = 1, 6 do render.DrawLine(cor[i], cor[(i % 6) + 1], Color(cR, cG, cB, 150), false) end
end

function ME.DrawHexCell(q, r, cr, cg, cb, fillA, lineA)
	local cell = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]
	local z    = ((ME.MapInfo and ME.MapInfo.baseZ) or 0) + (ME.SurfaceOffset(q, r, cell and cell.biome or "grass") or 0) + 4
	local ctr  = ME.HexToWorld(q, r, z)
	local cor  = ME.HexCorners(ctr, z)
	render.SetMaterial(oilRippleMat)
	mesh.Begin(MATERIAL_TRIANGLES, 6)
	for i = 1, 6 do
		mesh.Position(ctr);              mesh.Color(cr, cg, cb, fillA); mesh.AdvanceVertex()
		mesh.Position(cor[i]);           mesh.Color(cr, cg, cb, fillA); mesh.AdvanceVertex()
		mesh.Position(cor[(i % 6) + 1]); mesh.Color(cr, cg, cb, fillA); mesh.AdvanceVertex()
	end
	mesh.End()
	render.SetColorMaterial()
	for i = 1, 6 do render.DrawLine(cor[i], cor[(i % 6) + 1], Color(cr, cg, cb, lineA), false) end
end

local function drawMoveMark()
	local m = ME.Cam and ME.Cam.moveMark
	if not m then return end
	local age = CurTime() - (m.t or 0)
	if age < 0 or age > 0.9 then ME.Cam.moveMark = nil return end
	local frac = age / 0.9
	local a    = math.floor((1 - frac) * 230)
	local cell = ME.BoardCells and ME.BoardCells[ME.HexKey(m.q, m.r)]
	local z    = ((ME.MapInfo and ME.MapInfo.baseZ) or 0) + (ME.SurfaceOffset(m.q, m.r, cell and cell.biome or "grass") or 0) + 4
	local ctr  = ME.HexToWorld(m.q, m.r, z)
	local cor  = ME.HexCorners(ctr, z)
	local scl  = 0.5 + frac * 0.65
	render.SetColorMaterial()
	for i = 1, 6 do
		local p1 = ctr + (cor[i] - ctr) * scl
		local p2 = ctr + (cor[(i % 6) + 1] - ctr) * scl
		render.DrawLine(p1, p2, Color(255, 255, 255, a), false)
	end
end

local PP_BLOCK = { mountain = true, tree = true, palm = true, rock = true, bush = true }

local PP_MINE = { at_mine = true, naval_mine = true }
local function ppOccupied()
	local occ = {}
	if ME.BuildingModels then
		for _, rec in pairs(ME.BuildingModels) do

			if IsValid(rec.model) and not (ME.IsEdgeBuilding and ME.IsEdgeBuilding(rec.bid)) and not PP_MINE[rec.bid] then
				local q, r = ME.WorldToHex(rec.model:GetPos()); occ[ME.HexKey(q, r)] = true
			end
		end
	end
	for _, cm in ipairs(ME.CoreModels or {}) do
		if IsValid(cm) then local q, r = ME.WorldToHex(cm:GetPos()); occ[ME.HexKey(q, r)] = true end
	end
	return occ
end

local function ppEdgeKey(aq, ar, bq, br)
	if aq < bq or (aq == bq and ar <= br) then return aq .. "," .. ar .. "|" .. bq .. "," .. br end
	return bq .. "," .. br .. "|" .. aq .. "," .. ar
end

local function ppBlockedEdges()
	local set = {}
	if not ME.BuildingModels then return set end
	for _, rec in pairs(ME.BuildingModels) do
		if IsValid(rec.model) and rec.built and rec.bid == "wall" then
			local p = rec.model:GetPos()
			local q, r = ME.WorldToHex(p)
			local bestSide, bestD
			for side = 0, 5 do
				local nq, nr = ME.FaceNeighbor(q, r, side)
				local mid = (ME.HexToWorld(q, r, 0) + ME.HexToWorld(nq, nr, 0)) * 0.5
				local d = (mid.x - p.x) ^ 2 + (mid.y - p.y) ^ 2
				if not bestD or d < bestD then bestD, bestSide = d, side end
			end
			if bestSide then
				local nq, nr = ME.FaceNeighbor(q, r, bestSide)
				set[ppEdgeKey(q, r, nq, nr)] = true
			end
		end
	end
	return set
end

local function ppPassable(q, r, occ, domain)
	local cell = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]
	if not cell then return false end
	if domain == "sea" then
		if cell.biome ~= "water" then return false end
	else
		if cell.biome == "water" then return false end
		if PP_BLOCK[cell.decor] then return false end
	end
	if occ and occ[ME.HexKey(q, r)] then return false end
	return true
end

local function ppTier(q, r)
	local cell  = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]
	local biome = cell and cell.biome or "grass"
	local H     = (ME.Config and ME.Config.Heights) or {}
	local step  = (ME.Config and ME.Config.TierStep) or 20
	return math.Round(((ME.SurfaceOffset(q, r, biome) or 0) - (H.grass or 0)) / step)
end

local function ppTierOK(aq, ar, bq, br, domain)
	if domain == "sea" then return true end
	return math.abs(ppTier(aq, ar) - ppTier(bq, br)) <= 1
end
local function ppNearest(gq, gr, occ, domain)
	if ppPassable(gq, gr, occ, domain) then return gq, gr end
	local seen, fr = { [ME.HexKey(gq, gr)] = true }, { { gq, gr } }
	for _ = 1, 24 do
		local nx = {}
		for _, h in ipairs(fr) do
			for _, nb in ipairs(ME.HexNeighbors(h[1], h[2])) do
				local k = ME.HexKey(nb[1], nb[2])
				if not seen[k] then seen[k] = true
					if ppPassable(nb[1], nb[2], occ, domain) then return nb[1], nb[2] end
					nx[#nx + 1] = nb
				end
			end
		end
		fr = nx; if #fr == 0 then break end
	end
	return nil
end
local function ppLineClear(aq, ar, bq, br, occ, blocked, domain)
	local a, b = ME.HexToWorld(aq, ar, 0), ME.HexToWorld(bq, br, 0)
	local dx, dy = b.x - a.x, b.y - a.y
	local steps  = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / ((ME.Config.HexSize or 96) * 0.45)))
	local pq, pr
	for i = 0, steps do
		local t = i / steps
		local q, r = ME.WorldToHex(Vector(a.x + dx * t, a.y + dy * t, 0))
		if not ppPassable(q, r, occ, domain) then return false end
		if pq and (q ~= pq or r ~= pr) then
			if not ppTierOK(pq, pr, q, r, domain) then return false end
			if blocked and blocked[ppEdgeKey(pq, pr, q, r)] then return false end
		end
		pq, pr = q, r
	end
	return true
end
local function ppStringPull(sq, sr, hexes, occ, blocked, domain)
	local full = { { sq, sr } }
	for _, h in ipairs(hexes) do full[#full + 1] = h end
	local out, i = {}, 1
	while i < #full do
		local j = #full
		while j > i + 1 do
			if ppLineClear(full[i][1], full[i][2], full[j][1], full[j][2], occ, blocked, domain) then break end
			j = j - 1
		end
		out[#out + 1] = full[j]
		i = j
	end
	return out
end

local PP_STRUCT_COST = 4
local function ppFindPath(sq, sr, gq, gr, domain)
	local occ = ppOccupied(); occ[ME.HexKey(sq, sr)] = nil
	local blocked = ppBlockedEdges()
	gq, gr = ppNearest(gq, gr, nil, domain)
	if not gq then return nil, nil, nil end
	local startK, goalK = ME.HexKey(sq, sr), ME.HexKey(gq, gr)
	if startK == goalK then return {}, gq, gr end
	local coordOf = { [startK] = { sq, sr } }
	local came, gS = {}, { [startK] = 0 }
	local fS = { [startK] = ME.HexDistance(sq, sr, gq, gr) }
	local open, guard = { [startK] = true }, 0
	while next(open) and guard < 4000 do
		guard = guard + 1
		local curK, bestF = nil, math.huge
		for k in pairs(open) do local f = fS[k] or math.huge; if f < bestF then bestF, curK = f, k end end
		if not curK then break end
		if curK == goalK then
			local path, k = {}, goalK
			while came[k] do local c = coordOf[k]; table.insert(path, 1, { c[1], c[2] }); k = came[k] end
			return ppStringPull(sq, sr, path, occ, blocked, domain), gq, gr
		end
		open[curK] = nil
		local cc = coordOf[curK]
		for _, nb in ipairs(ME.HexNeighbors(cc[1], cc[2])) do
			local nq, nr, nk = nb[1], nb[2], ME.HexKey(nb[1], nb[2])
			if ppPassable(nq, nr, nil, domain) and ppTierOK(cc[1], cc[2], nq, nr, domain)
			   and not blocked[ppEdgeKey(cc[1], cc[2], nq, nr)] then
				local t = (gS[curK] or math.huge) + (occ[nk] and PP_STRUCT_COST or 1)
				if t < (gS[nk] or math.huge) then
					coordOf[nk], came[nk] = { nq, nr }, curK
					gS[nk] = t; fS[nk] = t + ME.HexDistance(nq, nr, gq, gr); open[nk] = true
				end
			end
		end
	end
	return nil, gq, gr
end
local function ppGround(q, r)
	local cell = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]
	local z = ((ME.MapInfo and ME.MapInfo.baseZ) or 0) + (ME.SurfaceOffset(q, r, cell and cell.biome or "grass") or 0) + 5
	return ME.HexToWorld(q, r, z)
end

local function ppGroundAt(x, y)
	local q, r = ME.WorldToHex(Vector(x, y, 0))
	local cell = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]
	return ((ME.MapInfo and ME.MapInfo.baseZ) or 0) + (ME.SurfaceOffset(q, r, cell and cell.biome or "grass") or 0) + 4
end

function ME.ClientBuildPath(sq, sr, gq, gr, domain)
	local hexes = ppFindPath(sq, sr, gq, gr, domain)
	if not hexes or #hexes == 0 then return nil end
	local centers = { ppGround(sq, sr) }
	for _, h in ipairs(hexes) do centers[#centers + 1] = ppGround(h[1], h[2]) end

	local pts = { centers[1] }
	for i = 1, #centers - 1 do
		local a, b = centers[i], centers[i + 1]
		for s = 1, 4 do
			local f = s / 4
			pts[#pts + 1] = Vector(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f, a.z + (b.z - a.z) * f)
		end
	end
	return pts
end

hook.Add("Think", "ME_MoveHover", function()
	local sel = ME.Cam and ME.Cam.selected
	if not (sel and #sel > 0) or (ME.Build and ME.Build.IsPlacing and ME.Build.IsPlacing()) then
		if ME.Cam then ME.Cam.hoverHex = nil end
		return
	end
	local hit = ME.GroundUnderCursor and ME.GroundUnderCursor()
	if not hit then ME.Cam.hoverHex = nil return end
	local gq, gr = ME.WorldToHex(hit)
	local cell   = ME.BoardCells and ME.BoardCells[ME.HexKey(gq, gr)]

	if cell and ME.SelectionDomains then
		local land, sea = ME.SelectionDomains()
		local ok = (cell.biome == "water") and sea or (cell.biome ~= "water" and land)
		if not ok then ME.Cam.hoverHex = nil return end
	end
	ME.Cam.hoverHex = { gq, gr }
end)

local function drawEndDot(groundB, fade)

	local ep = Vector(groundB.x, groundB.y, ppGroundAt(groundB.x, groundB.y) - 2.5)
	local dotA, R, seg = math.floor(235 * (fade or 1)), 10, 20
	if dotA <= 4 then return end
	render.SetColorMaterial()
	for _, cm in ipairs({ MATERIAL_CULLMODE_CCW, MATERIAL_CULLMODE_CW }) do
		render.CullMode(cm)
		mesh.Begin(MATERIAL_TRIANGLES, seg)
		for i = 0, seg - 1 do
			local a1, a2 = i / seg * 6.2831853, (i + 1) / seg * 6.2831853
			mesh.Position(ep);                                             mesh.Color(255, 255, 255, dotA); mesh.AdvanceVertex()
			mesh.Position(ep + Vector(math.cos(a1), math.sin(a1), 0) * R); mesh.Color(255, 255, 255, dotA); mesh.AdvanceVertex()
			mesh.Position(ep + Vector(math.cos(a2), math.sin(a2), 0) * R); mesh.Color(255, 255, 255, dotA); mesh.AdvanceVertex()
		end
		mesh.End()
	end
	render.CullMode(MATERIAL_CULLMODE_CCW)
end

local function drawOneRoute(mp, uid)
	local u   = Entity(uid)
	local rec = ME.UnitModels and ME.UnitModels[uid]
	if not (IsValid(u) and rec) then return false end

	if (rec.buildIdx or 0) > 0 then return true end

	local grace = (CurTime() - (mp.t or 0)) < 0.5
	local fade  = 1
	if rec.moving or grace then
		mp._arrived = nil
	else
		mp._arrived = mp._arrived or CurTime()
		fade = 1 - (CurTime() - mp._arrived) / 0.6
		if fade <= 0 then return false end
	end

	local up      = IsValid(rec.model) and rec.model:GetPos() or u:GetPos()
	local groundB = mp.dotAt or mp.pts[#mp.pts]

	if mp.builder then

		local b    = Vector(groundB.x, groundB.y, ppGroundAt(groundB.x, groundB.y) + 2)
		local a    = Vector(up.x, up.y, up.z + 5)
		local flat = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
		if flat > 6 then
			local lift = math.Clamp(flat * 0.28, 14, 110)
			render.SetColorMaterial()
			local col, N, prev = Color(255, 255, 255, math.floor(150 * fade)), 20, nil
			for i = 0, N do
				local tt = i / N
				local p = Vector(a.x + (b.x - a.x) * tt, a.y + (b.y - a.y) * tt,
				                 a.z + (b.z - a.z) * tt + math.sin(math.pi * tt) * lift)
				if prev then render.DrawLine(prev, p, col, false) end
				prev = p
			end
		end
		drawEndDot(groundB, fade)
		return true
	end

	local nearI, nearD = 1, math.huge
	for i = 1, #mp.pts do
		local dx, dy = mp.pts[i].x - up.x, mp.pts[i].y - up.y
		local d = dx * dx + dy * dy
		if d < nearD then nearD, nearI = d, i end
	end
	local rem = { Vector(up.x, up.y, up.z + 4) }
	for i = nearI + 1, #mp.pts do rem[#rem + 1] = mp.pts[i] end
	if #rem >= 2 then
		render.SetColorMaterial()
		local col = Color(255, 255, 255, math.floor(130 * fade))
		for i = 1, #rem - 1 do
			local a, b = rem[i], rem[i + 1]
			local d = b - a; d.z = 0
			if d:Length() > 0.5 then
				d:Normalize()
				local perp = Vector(-d.y, d.x, 0) * 1.0
				render.DrawQuad(a - perp, a + perp, b + perp, b - perp, col)
				render.DrawQuad(b - perp, b + perp, a + perp, a - perp, col)
			end
		end
	end
	drawEndDot(groundB, fade)
	return true
end

local function drawBuildArcs()
	if not ME.UnitModels then return end
	local myTeam = LocalPlayer():Team()
	for _, rec in pairs(ME.UnitModels) do
		local bidx = rec.buildIdx or 0
		local brec = bidx > 0 and ME.BuildingModels and ME.BuildingModels[bidx]
		if IsValid(rec.model) and rec.faction == myTeam and brec and IsValid(brec.model) and not brec.built then
			local fade = 1
			if rec.moving then rec._bArr = nil
			else rec._bArr = rec._bArr or CurTime(); fade = 1 - (CurTime() - rec._bArr) / 0.6 end
			if fade > 0 then
				local up = rec.model:GetPos()
				local dp = brec.model:GetPos()
				local a, b = Vector(up.x, up.y, up.z + 5), Vector(dp.x, dp.y, ppGroundAt(dp.x, dp.y) + 2)
				local flat = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
				if flat > 6 then
					local lift = math.Clamp(flat * 0.28, 14, 110)
					render.SetColorMaterial()
					local col, N, prev = Color(255, 255, 255, math.floor(150 * fade)), 20, nil
					for i = 0, N do
						local tt = i / N
						local p = Vector(a.x + (b.x - a.x) * tt, a.y + (b.y - a.y) * tt,
						                 a.z + (b.z - a.z) * tt + math.sin(math.pi * tt) * lift)
						if prev then render.DrawLine(prev, p, col, false) end
						prev = p
					end
				end
				drawEndDot(brec.model:GetPos(), fade)
			end
		else
			rec._bArr = nil
		end
	end
end

local function drawMovePreview()

	local paths = ME.Cam and ME.Cam.movePaths
	render.OverrideDepthEnable(true, false)
	if paths and next(paths) then
		for uid, mp in pairs(paths) do
			if not (mp.pts and #mp.pts >= 2 and drawOneRoute(mp, uid)) then paths[uid] = nil end
		end
	end
	drawBuildArcs()
	render.OverrideDepthEnable(false)

	local hv = ME.Cam and ME.Cam.hoverHex
	if hv then
		local ctr = ppGround(hv[1], hv[2])
		local cor = ME.HexCorners(ctr, ctr.z)
		render.SetMaterial(oilRippleMat)
		mesh.Begin(MATERIAL_TRIANGLES, 6)
		for i = 1, 6 do
			mesh.Position(ctr);              mesh.Color(255, 255, 255, 24); mesh.AdvanceVertex()
			mesh.Position(cor[i]);           mesh.Color(255, 255, 255, 24); mesh.AdvanceVertex()
			mesh.Position(cor[(i % 6) + 1]); mesh.Color(255, 255, 255, 24); mesh.AdvanceVertex()
		end
		mesh.End()
		render.SetColorMaterial()
		for i = 1, 6 do render.DrawLine(cor[i], cor[(i % 6) + 1], Color(255, 255, 255, 150), false) end
	end
end

local coinSprite  = Material("mergeempires/game/me_coin.png", "smooth")
local INCOME_BIDS = { farm = true, oil_pump = true, oil_rig = true }

local RING_MAT = CreateMaterial("me_blast_ring", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$additive"]    = "1",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
	["$nocull"]      = "1",
	["$ignorez"]     = "0",
})
local RING_SEGS = 40

local function blastRing(center, radius, width, col)
	if not col or col.a <= 1 or radius <= 0 then return end
	render.SetMaterial(RING_MAT)
	local inner = math.max(0, radius - width * 0.5)
	local outer = radius + width * 0.5
	for i = 0, RING_SEGS - 1 do
		local a0 = (i / RING_SEGS) * math.pi * 2
		local a1 = ((i + 1) / RING_SEGS) * math.pi * 2
		local c0, s0 = math.cos(a0), math.sin(a0)
		local c1, s1 = math.cos(a1), math.sin(a1)
		render.DrawQuad(
			center + Vector(c0 * inner, s0 * inner, 0),
			center + Vector(c1 * inner, s1 * inner, 0),
			center + Vector(c1 * outer, s1 * outer, 0),
			center + Vector(c0 * outer, s0 * outer, 0), col)
	end
end

local fxGlow  = Material("sprites/light_glow02_add")
local fxLaser = Material("effects/spark")

local fxBeamFlat = CreateMaterial("me_beam_flat", "UnlitGeneric", {
	["$basetexture"] = "models/debug/debugwhite",
	["$additive"] = "1", ["$vertexcolor"] = "1", ["$vertexalpha"] = "1", ["$nocull"] = "1",
})
local fxSpark = Material("effects/yellowflare")
local fxSmoke = Material("particle/particle_smokegrenade")

ME.ArtFlight = (ME.Config and ME.Config.ArtFlight) or 1.1
ME.IntFlight = 0.45
ME.ArtKillU  = 0.55
function ME.ArtArc(a, b, u)
	local p = LerpVector(u, a, b)
	p.z = p.z + math.sin(u * math.pi) * 300
	return p
end

local MISSILE_MDL = "models/merge_empires/missile.mdl"
local missileEnt

local function drawMissile(pos, dir, scale)
	if not IsValid(missileEnt) then
		missileEnt = ClientsideModel(MISSILE_MDL, RENDERGROUP_OPAQUE)
		if not IsValid(missileEnt) then return end
		missileEnt:SetNoDraw(true)
	end
	if dir:LengthSqr() < 1e-6 then return end
	missileEnt:SetPos(pos)
	missileEnt:SetAngles(dir:Angle())
	missileEnt:SetModelScale(scale or 1, 0)
	missileEnt:SetupBones()
	render.SuppressEngineLighting(true)
	render.SetColorModulation(1, 1, 1)
	render.SetBlend(1)
	applyModelLighting(AMB_COL.x + 0.42, AMB_COL.y + 0.42, AMB_COL.z + 0.40,
	                   SUN_COL.x + 0.25, SUN_COL.y + 0.20, SUN_COL.z + 0.14)
	missileEnt:DrawModel()
	render.SuppressEngineLighting(false)
end

local function launchSmoke(origin, age, dur, scale)
	if age > dur then return end
	local f = age / dur
	local a = (1 - f) * (1 - f)
	scale = scale or 1
	render.SetMaterial(fxSmoke)
	for s = 0, 4 do
		local sp = s * 1.7
		local off = Vector(math.cos(sp) * (10 + f * 34) * scale,
		                   math.sin(sp) * (10 + f * 34) * scale,
		                   (6 + f * 40) * scale)
		local sz = (26 + f * 62 + s * 5) * scale
		render.DrawSprite(origin + off, sz, sz, Color(158, 156, 152, math.floor(165 * a)))
	end
	render.SetMaterial(fxGlow)
	if f < 0.45 then
		local g = 1 - f / 0.45
		render.DrawSprite(origin, (70 + 40 * g) * scale, (70 + 40 * g) * scale,
			Color(255, 190, 110, math.floor(230 * g)))
	end
end

local function drawFX()
	if not ME.FX then return end
	local now = RealTime()
	for i = #ME.FX, 1, -1 do
		local fx  = ME.FX[i]
		local age = now - fx.t0
		if fx.kind == "shot" then
			local life = 0.07
			if age > life then table.remove(ME.FX, i)
			else
				local f = 1 - age / life

				render.SetMaterial(fxLaser)
				render.DrawBeam(fx.a, fx.b, 9 * f + 2,  0, 1, Color(255, 210, 110, math.floor(120 * f)))
				render.DrawBeam(fx.a, fx.b, 3,          0, 1, Color(255, 248, 210, math.floor(255 * f)))
				render.SetMaterial(fxGlow)
				render.DrawSprite(fx.a, 34 * f + 8, 34 * f + 8, Color(255, 226, 150, math.floor(255 * f)))
				render.SetMaterial(fxSpark)
				render.DrawSprite(fx.b, 20 * f + 6, 20 * f + 6, Color(255, 236, 190, math.floor(230 * f)))
			end
		elseif fx.kind == "corepop" then
			local life = 0.45
			if age > life then table.remove(ME.FX, i)
			else
				local f  = age / life
				local sz = (fx.sz or 90) * (0.35 + f * 0.9)
				render.SetMaterial(fxGlow)
				render.DrawSprite(fx.b, sz, sz, Color(255, math.floor(210 - f * 150), math.floor(120 - f * 100), math.floor(255 * (1 - f))))
				render.SetMaterial(fxSpark)
				render.DrawSprite(fx.b, sz * 0.5, sz * 0.5, Color(255, 245, 210, math.floor(230 * (1 - f))))
			end
		elseif fx.kind == "coreblast" then

			local life = 2.8
			if age > life then table.remove(ME.FX, i)
			else
				local o  = fx.b
				local gz = o + Vector(0, 0, 6)

				if age < 0.22 then
					local wf = (1 - age / 0.22) ^ 0.6
					render.SetMaterial(fxGlow)
					render.DrawSprite(o + Vector(0, 0, 70), 900 * wf + 200, 900 * wf + 200, Color(255, 250, 225, math.floor(255 * wf)))
					blastRing(gz, 40 + (1 - wf) * 300, 260 * wf + 40, Color(255, 250, 220, math.floor(230 * wf)))
				end

				local s1 = math.min(1, age / 0.75)
				if s1 < 1 then
					local e1 = 1 - (1 - s1) ^ 3
					blastRing(gz, 60 + e1 * 1150, 190 * (1 - e1) + 26,
						Color(255, math.floor(200 - e1 * 120), 90, math.floor(220 * (1 - e1))))
				end

				local s2 = math.min(1, age / 1.5)
				if s2 < 1 then
					local e2 = 1 - (1 - s2) ^ 2
					blastRing(o + Vector(0, 0, 3), 40 + e2 * 760, 150 * (1 - e2) + 30,
						Color(150, 126, 96, math.floor(120 * (1 - e2))))
				end

				local bf = math.min(1, age / 1.1)
				if bf < 1 then
					local grow = 1 - (1 - bf) ^ 2
					render.SetMaterial(fxGlow)
					local sz = 240 + grow * 460
					render.DrawSprite(o + Vector(0, 0, 90 + grow * 210), sz, sz,
						Color(255, math.floor(190 - bf * 165), math.floor(70 - bf * 60), math.floor(255 * (1 - bf))))
				end

				render.SetMaterial(fxGlow)
				for k = 1, 8 do
					local a2 = age - 0.05 - k * 0.055
					if a2 > 0 then
						local f2 = a2 / 0.95
						if f2 < 1 then
							local ang = (k / 8) * math.pi * 2 + 0.4
							local rad = 70 + f2 * 210
							local p   = o + Vector(math.cos(ang) * rad, math.sin(ang) * rad, 40 + f2 * 190)
							local sz  = 90 + f2 * 210
							render.DrawSprite(p, sz, sz, Color(255, math.floor(175 - f2 * 145), 45, math.floor(240 * (1 - f2))))
						end
					end
				end

				local df = math.min(1, age / 1.9)
				if df < 1 then
					for k = 1, 18 do
						local ang  = (k / 18) * math.pi * 2 + 1.1
						local rise = 0.75 + ((k * 37) % 100) / 100 * 1.5
						local far  = 320 + ((k * 53) % 100) / 100 * 520
						local zz   = (rise * 470) * df - (rise * 640) * df * df
						local dp   = o + Vector(math.cos(ang) * df * far, math.sin(ang) * df * far, math.max(4, zz + 40))
						local sz   = 34 * (1 - df) + 7
						local al   = math.floor(255 * (1 - df))
						if df < 0.55 then
							local pd = math.max(0, df - 0.07)
							local pz = (rise * 470) * pd - (rise * 640) * pd * pd
							local pp = o + Vector(math.cos(ang) * pd * far, math.sin(ang) * pd * far, math.max(4, pz + 40))
							render.SetMaterial(fxLaser)
							render.DrawBeam(pp, dp, sz * 0.8, 0, 1, Color(255, 170, 80, math.floor(al * 0.75)))
						end
						render.SetMaterial(fxSpark)
						render.DrawSprite(dp, sz, sz, Color(255, 205, 120, al))
					end
				end

				render.SetMaterial(fxSmoke)
				for s = 0, 7 do
					local sf = age / life - s * 0.045
					if sf > 0 then
						sf = math.min(1, sf)
						local sz    = 200 + sf * 420
						local shade = math.floor(70 - sf * 40)
						render.DrawSprite(o + Vector(math.sin(s * 1.7) * sf * 90, math.cos(s * 2.1) * sf * 90, 60 + sf * 620 + s * 40),
							sz, sz, Color(shade, shade - 2, shade - 4, math.floor(165 * (1 - sf))))
					end
				end

				for s = 0, 5 do
					local sf = math.min(1, age / 1.6 + s * 0.05)
					if sf < 1 then
						local ang = (s / 6) * math.pi * 2
						local rad = 90 + sf * 520
						render.DrawSprite(o + Vector(math.cos(ang) * rad, math.sin(ang) * rad, 30 + sf * 70),
							180 + sf * 260, 180 + sf * 260, Color(132, 112, 88, math.floor(120 * (1 - sf))))
					end
				end
			end
		elseif fx.kind == "vehicleblast" then
			local life = 1.1
			if age > life then table.remove(ME.FX, i)
			else
				local o  = fx.b
				local gz = o + Vector(0, 0, 6)

				if age < 0.14 then
					local wf = (1 - age / 0.14) ^ 0.6
					render.SetMaterial(fxGlow)
					render.DrawSprite(o + Vector(0, 0, 30), 340 * wf + 90, 340 * wf + 90, Color(255, 250, 225, math.floor(255 * wf)))
				end

				local bf = math.min(1, age / 0.78)
				if bf < 1 then
					local grow = 1 - (1 - bf) ^ 2
					render.SetMaterial(fxGlow)
					local sz = 120 + grow * 190
					render.DrawSprite(o + Vector(0, 0, 44 + grow * 100), sz, sz,
						Color(255, math.floor(185 - bf * 160), math.floor(65 - bf * 55), math.floor(255 * (1 - bf))))
				end

				render.SetMaterial(fxSpark)
				local df = math.min(1, age / 0.9)
				if df < 1 then
					for k = 1, 11 do
						local ang  = (k / 11) * math.pi * 2 + 0.6
						local rise = 0.7 + ((k * 37) % 100) / 100 * 1.1
						local far  = 90 + ((k * 53) % 100) / 100 * 230
						local zz   = (rise * 240) * df - (rise * 330) * df * df
						local dp   = o + Vector(math.cos(ang) * df * far, math.sin(ang) * df * far, math.max(4, zz + 30))
						local sz   = 16 * (1 - df) + 4
						render.DrawSprite(dp, sz, sz, Color(255, 205, 120, math.floor(255 * (1 - df))))
					end
				end

				render.SetMaterial(fxSmoke)
				for s = 0, 4 do
					local sf = age / life - s * 0.06
					if sf > 0 then
						sf = math.min(1, sf)
						local sz    = 90 + sf * 200
						local shade = math.floor(74 - sf * 42)
						render.DrawSprite(o + Vector(math.sin(s * 1.7) * sf * 42, math.cos(s * 2.1) * sf * 42, 40 + sf * 240 + s * 20),
							sz, sz, Color(shade, shade - 2, shade - 4, math.floor(150 * (1 - sf))))
					end
				end
			end
		elseif fx.kind == "corebeam" then

			local tgt   = (fx.tgt or 0) > 0 and Entity(fx.tgt) or nil
			local alive = IsValid(tgt) and (not tgt.GetHP or tgt:GetHP() > 0)

			if alive then fx.b = tgt:GetPos() + Vector(0, 0, ME.HitHeight(fx.tgt)) end
			local f = 1
			if alive and now < (fx.hold or 0) then
				fx.fadeAt = nil
			else
				fx.fadeAt = fx.fadeAt or now
				f = 1 - (now - fx.fadeAt) / 0.22
				if f <= 0 then table.remove(ME.FX, i) end
			end
			if f > 0 then
				if alive and ME.Sfx then ME.Sfx.Loop("corebeam" .. fx.fac, "core_beam_loop", fx.b) end
				local tc = (ME.BeamColors and ME.BeamColors[fx.fac]) or Color(120, 200, 255)
				local a, b = fx.a, fx.b
				local dir = b - a
				local len = dir:Length()
				if len > 1 then
					local fwd  = dir / len
					local seed = fx.fac * 2.3

					local w = (0.55 + 0.45 * math.abs(math.sin(now * 21 + seed) * math.sin(now * 7.3 + seed))) * f
					local br = (0.86 + 0.14 * math.sin(now * 5.5 + seed)) * f

					render.SetMaterial(fxBeamFlat)
					render.DrawBeam(a, b, 32 * w, 0, 1, Color(tc.r, tc.g, tc.b, math.floor(46 * br)))
					render.DrawBeam(a, b, 16 * w, 0, 1, Color(tc.r, tc.g, tc.b, math.floor(150 * br)))
					render.DrawBeam(a, b, 5.5* w, 0, 1, Color(255, 255, 255, math.floor(225 * br)))

					local PULSES = 3
					for p = 0, PULSES - 1 do
						local t0 = ((now * 1.9 + p / PULSES + fx.fac * 0.11) % 1)
						local ease = t0 * t0
						local pa = a + fwd * (len * ease)
						local pb = a + fwd * (len * math.min(1, ease + 0.075))
						local pf = (1 - t0) * f
						render.DrawBeam(pa, pb, 24 * w, 0, 1, Color(tc.r, tc.g, tc.b, math.floor(150 * pf)))
						render.DrawBeam(pa, pb, 9  * w, 0, 1, Color(255, 255, 255, math.floor(190 * pf)))
					end

					local side = fwd:Cross(vector_up)
					if side:LengthSqr() < 0.01 then side = fwd:Cross(Vector(1, 0, 0)) end
					side:Normalize()
					local up = side:Cross(fwd)
					render.SetMaterial(fxSpark)
					for s = 1, 8 do
						local u  = ((s * 0.1379 + now * 0.55 + fx.fac * 0.07) % 1)
						local an = s * 2.399 + now * 3.1
						local rad = (9 + 13 * math.abs(math.sin(s * 1.7 + now * 2.2))) * w
						local pt = a + fwd * (len * u) + side * (math.cos(an) * rad) + up * (math.sin(an) * rad)
						local sz = (5 + 6 * math.abs(math.sin(s * 2.1 + now * 4.7))) * f
						render.DrawSprite(pt, sz, sz, Color(tc.r, tc.g, tc.b, math.floor(215 * f)))
					end

					render.SetMaterial(fxGlow)
					render.DrawSprite(a, 70 * w, 70 * w, Color(tc.r, tc.g, tc.b, math.floor(255 * br)))
					render.DrawSprite(b, 50 * w, 50 * w, Color(tc.r, tc.g, tc.b, math.floor(240 * br)))
					render.DrawSprite(b, 24 * w, 24 * w, Color(255, 255, 255, math.floor(240 * br)))
				end
			end
		elseif fx.kind == "vshot" then
			local life = 0.09
			if age > life then table.remove(ME.FX, i)
			else
				local f = 1 - age / life
				render.SetMaterial(fxLaser)
				render.DrawBeam(fx.a, fx.b, 14 * f + 3, 0, 1, Color(255, 200, 100, math.floor(150 * f)))
				render.DrawBeam(fx.a, fx.b, 5,          0, 1, Color(255, 245, 210, math.floor(255 * f)))
				render.SetMaterial(fxGlow)
				render.DrawSprite(fx.a, 56 * f + 14, 56 * f + 14, Color(255, 220, 150, math.floor(255 * f)))
				render.SetMaterial(fxSpark)
				render.DrawSprite(fx.b, 34 * f + 10, 34 * f + 10, Color(255, 230, 180, math.floor(240 * f)))
			end
		elseif fx.kind == "interceptor" then
			local flight = ME.IntFlight
			if age >= flight + 0.4 then table.remove(ME.FX, i)
			elseif age < flight then
				local u = age / flight
				local p = LerpVector(u, fx.a, fx.b)
				render.SetMaterial(fxSmoke)
				for s = 0, 5 do
					local tp = LerpVector(math.max(0, u - s * 0.07), fx.a, fx.b)
					render.DrawSprite(tp, 12 + s * 5, 12 + s * 5, Color(170, 170, 175, 130 - s * 20))
				end
				render.SetMaterial(fxGlow)
				render.DrawSprite(p, 22, 22, Color(190, 230, 255, 255))
				launchSmoke(fx.a, age, 0.5, 0.85)
				drawMissile(p, fx.b - fx.a, 0.7)
			else

				if not fx._boom then
					fx._boom = true
					if ME.ShakeAt then ME.ShakeAt(fx.b, 10, 0.45, 3200) end
					if ME.Sfx then ME.Sfx.Play("interceptor_pop", fx.b) end
				end
				local f = (age - flight) / 0.4
				render.SetMaterial(fxGlow)
				local sz = 90 + f * 190
				render.DrawSprite(fx.b, sz, sz, Color(210, 240, 255, math.floor(255 * (1 - f))))
				render.SetMaterial(fxSpark)
				for s = 1, 9 do
					local ang = (s / 9) * math.pi * 2
					local rad = f * 150
					render.DrawSprite(fx.b + Vector(math.cos(ang) * rad, math.sin(ang) * rad, math.sin(s) * rad * 0.4),
						18 * (1 - f) + 4, 18 * (1 - f) + 4, Color(235, 250, 255, math.floor(255 * (1 - f))))
				end
			end
		elseif fx.kind == "artmissile" then
			local flight = ME.ArtFlight
			if fx.killAt and age >= fx.killAt then

				table.remove(ME.FX, i)
			elseif age >= flight then
				ME.FX[#ME.FX + 1] = { kind = "vehicleblast", b = fx.b, t0 = RealTime() }
				if ME.ShakeAt then ME.ShakeAt(fx.b, 15, 0.6, 3400) end
				if ME.Sfx then ME.Sfx.Play("artillery_impact", fx.b) end
				table.remove(ME.FX, i)
			else
				local u = age / flight
				render.SetMaterial(fxSmoke)
				for s = 0, 6 do
					local tu = math.max(0, u - s * 0.05)
					render.DrawSprite(ME.ArtArc(fx.a, fx.b, tu), 15 + s * 4, 15 + s * 4, Color(150, 150, 150, 120 - s * 15))
				end
				local at = ME.ArtArc(fx.a, fx.b, u)
				render.SetMaterial(fxGlow)
				render.DrawSprite(at, 20, 20, Color(255, 175, 85, 255))
				launchSmoke(fx.a, age, 0.55, 1.15)

				drawMissile(at, ME.ArtArc(fx.a, fx.b, math.min(1, u + 0.02)) - at, 1)
			end
		else

			local travel = (ME.Config and ME.Config.RocketFlight) or 0.52
			if age <= travel then
				local t = age / travel
				local p = LerpVector(t, fx.a, fx.b)
				render.SetMaterial(fxSmoke)
				for s = 0, 4 do
					local tp = LerpVector(math.max(0, t - s * 0.06), fx.a, fx.b)
					render.DrawSprite(tp, 14 + s * 5, 14 + s * 5, Color(150, 150, 150, 90 - s * 16))
				end
				render.SetMaterial(fxGlow)
				render.DrawSprite(p, 16, 16, Color(255, 170, 80, 255))
				launchSmoke(fx.a, age, 0.4, 0.7)
				drawMissile(p, fx.b - fx.a, 0.8)
			else

				local ex, elife = age - travel, 0.72
				if not fx._boom then
					fx._boom = true
					if ME.ShakeAt then ME.ShakeAt(fx.b, 9, 0.42, 2600) end
					if ME.Sfx then ME.Sfx.Play("rocket_impact", fx.b) end
				end
				if ex > elife then table.remove(ME.FX, i)
				else
					local f = ex / elife
					local o = fx.b

					if f < 0.16 then
						local wf = (1 - f / 0.16) ^ 0.55
						render.SetMaterial(fxGlow)
						render.DrawSprite(o + Vector(0, 0, 16), 250 * wf + 70, 250 * wf + 70,
							Color(255, 250, 230, math.floor(255 * wf)))
					end

					local bf = math.min(1, f / 0.62)
					if bf < 1 then
						local grow = 1 - (1 - bf) ^ 2
						local sz = 90 + grow * 165
						render.SetMaterial(fxGlow)
						render.DrawSprite(o + Vector(0, 0, 20 + grow * 60), sz, sz,
							Color(255, math.floor(180 - bf * 155), math.floor(60 - bf * 52), math.floor(255 * (1 - bf))))
					end

					render.SetMaterial(fxSpark)
					local t2 = f * elife
					for s = 1, 10 do
						local a2 = s * 2.399
						local sp = 150 + (s % 4) * 55
						local dz = 210 * t2 - 620 * t2 * t2
						local pt = o + Vector(math.cos(a2) * sp * t2, math.sin(a2) * sp * t2, 12 + dz)
						local sz = (13 - f * 9) * (0.7 + (s % 3) * 0.2)
						if sz > 0 then render.DrawSprite(pt, sz, sz, Color(255, 210, 130, math.floor(235 * (1 - f)))) end
					end

					render.SetMaterial(fxSmoke)
					for s = 0, 3 do
						local a2 = s * 1.9
						local rr = f * (30 + s * 14)
						local sz = 62 + f * 96 + s * 8
						render.DrawSprite(o + Vector(math.cos(a2) * rr, math.sin(a2) * rr, 14 + f * 56 + s * 6),
							sz, sz, Color(74, 71, 68, math.floor(160 * (1 - f))))
					end
				end
			end
		end
	end
end

local function drawFlames(o, R, H, seed, intensity, alpha)
	if alpha <= 0.01 then return end
	local now = RealTime()

	render.SetMaterial(fxGlow)
	for k = 0, 6 do
		local ph   = ((now * (1.15 + (k % 3) * 0.18) + k * 0.37 + seed) % 1)
		local ang  = seed * 3.1 + k * 2.39 + now * 0.5
		local rad  = R * (0.10 + (k % 4) * 0.16)
		local rise = ph * H * 1.15
		local wob  = math.sin(now * 7 + k * 1.9 + seed) * R * 0.13

		local w = (R * 1.05 + 26) * (1 - ph * 0.55) * intensity
		local p = o + Vector(math.cos(ang) * rad + wob, math.sin(ang) * rad + wob * 0.6, 14 + rise)

		local heat = 1 - ph
		local g = math.floor(90 + heat * 145)
		local b = math.floor(20 + heat * 55)
		local a = math.floor(235 * (1 - ph * 0.85) * alpha)
		render.DrawSprite(p, w, w * 1.5, Color(255, g, b, a))
	end

	local flick = 0.78 + 0.22 * math.sin(now * 19 + seed * 5)
	render.DrawSprite(o + Vector(0, 0, H * 0.16), R * 2.1 * intensity, R * 1.5 * intensity,
		Color(255, 150, 45, math.floor(190 * flick * alpha)))
	render.DrawSprite(o + Vector(0, 0, H * 0.10), R * 1.2 * intensity, R * 0.9 * intensity,
		Color(255, 235, 170, math.floor(150 * flick * alpha)))

	render.SetMaterial(fxSpark)
	for k = 0, 7 do
		local ph  = ((now * (0.55 + (k % 4) * 0.09) + k * 0.41 + seed * 0.7) % 1)
		local ang = seed * 2.2 + k * 2.7
		local rad = R * (0.2 + (k % 3) * 0.28) * (0.4 + ph)
		local p   = o + Vector(math.cos(ang) * rad + math.sin(now * 3 + k) * 12,
			math.sin(ang) * rad + math.cos(now * 2.6 + k) * 12, 20 + ph * (H * 2.1 + 130))
		local sz  = (9 + (k % 3) * 5) * (1 - ph * 0.6)
		render.DrawSprite(p, sz, sz, Color(255, math.floor(200 - ph * 110), 70, math.floor(255 * (1 - ph) * alpha)))
	end

	render.SetMaterial(fxSmoke)
	for k = 0, 4 do
		local ph = ((now * 0.34 + k * 0.2 + seed * 0.5) % 1)
		local sz = R * 1.6 + ph * (R * 2.6 + 150)
		local sh = math.floor(64 - ph * 34)
		render.DrawSprite(o + Vector(math.sin(now * 0.8 + k) * ph * 70, math.cos(now * 0.7 + k) * ph * 70,
			H * 0.55 + ph * (H * 2.4 + 260)), sz, sz, Color(sh, sh - 2, sh - 4, math.floor(120 * (1 - ph) * alpha)))
	end
end

local function drawBurns()
	local now = RealTime()

	if ME.BuildingModels then
		for idx, rec in pairs(ME.BuildingModels) do
			local bs = rec._burnStart
			if bs and now >= bs and IsValid(rec.model) then
				local cm  = rec.model
				local f   = (now - bs) / (rec._burnDur or 3.2)
				if f >= 1 then
					cm:StopParticles()
					cm:Remove()
					ME.BuildingModels[idx] = nil
				else
					local mins, maxs = cm:GetModelRenderBounds()
					local sc = cm:GetModelScale(); if not sc or sc == 0 then sc = 1 end
					local H = math.max(50, (maxs.z - mins.z) * sc)
					local R = math.max(38, math.max(maxs.x - mins.x, maxs.y - mins.y) * sc * 0.5)

					local intensity = math.min(1, f / 0.18) * (f > 0.7 and (1 - (f - 0.7) / 0.3) or 1)
					drawFlames(cm:GetPos(), R, H, idx * 0.618, 0.75 + intensity * 0.45, math.min(1, intensity + 0.15))
				end
			end
		end
	end

	if ME.BuildingModels then
		for idx, rec in pairs(ME.BuildingModels) do
			if rec.built and not rec._burnStart and rec.hp and IsValid(rec.model)
			   and not (ME.IsEdgeBuilding and ME.IsEdgeBuilding(rec.bid)) then
				local cfg = ME.GetBuilding and ME.GetBuilding(rec.bid)
				local mx  = (cfg and cfg.health) or 500
				local frac = rec.hp / math.max(1, mx)
				if rec.hp > 0 and frac < 0.35 then
					local cm = rec.model
					local mins, maxs = cm:GetModelRenderBounds()
					local sc = cm:GetModelScale(); if not sc or sc == 0 then sc = 1 end
					local H   = math.max(40, (maxs.z - mins.z) * sc)
					local R   = math.max(28, math.max(maxs.x - mins.x, maxs.y - mins.y) * sc * 0.5)
					local sev = 1 - frac / 0.35
					drawFlames(cm:GetPos(), R * 0.9, H * 0.9, idx * 0.618, 0.4 + sev * 0.55, 0.35 + sev * 0.55)
				end
			end
		end
	end

	if ME.CoreModels then
		for _, cm in ipairs(ME.CoreModels) do
			if IsValid(cm) and cm.MEBurning then
				drawFlames(cm:GetPos(), 95, 190, (cm.MEFaction or 1) * 1.37, 1.15, 1)
			end
		end
	end
end

local GRAVE_LIFE = 2.2
local GRAVE_FADE = 0.8
local function drawGraves()
	if not ME.Graves then return end
	render.SuppressEngineLighting(true)
	applyModelLighting(AMB_COL.x + 0.1, AMB_COL.y + 0.1, AMB_COL.z + 0.1, SUN_COL.x, SUN_COL.y, SUN_COL.z)
	local now = RealTime()
	for i = #ME.Graves, 1, -1 do
		local g = ME.Graves[i]
		if IsValid(g.m) then
			local age = now - g.t0
			if age >= GRAVE_LIFE then g.m:Remove(); table.remove(ME.Graves, i)
			else
				render.SetBlend(age > GRAVE_LIFE - GRAVE_FADE and (GRAVE_LIFE - age) / GRAVE_FADE or 1)
				g.m:DrawModel()
				render.SetBlend(1)
			end
		else table.remove(ME.Graves, i) end
	end
	render.SuppressEngineLighting(false)
end

local function drawIncomeCoins()
	if not ME.BuildingModels then return end
	local t = RealTime()
	render.SetMaterial(coinSprite)
	for idx, rec in pairs(ME.BuildingModels) do
		if rec.built and INCOME_BIDS[rec.bid] and IsValid(rec.model) then
			local base   = rec.model:GetPos()

			local period = 2.4
			local prog   = (t / period) + (idx * 0.613)
			local frac   = prog % 1

			local cyc    = math.floor(prog)
			local ang    = (cyc * 2.3999632 + idx * 1.7) % (math.pi * 2)
			local rad    = 14 + ((cyc * 37 + idx * 53) % 24)
			local a
			if frac < 0.08 then a = frac / 0.08 * 235
			elseif frac < 0.45 then a = 235
			else a = (1 - frac) / 0.55 * 235 end
			if a > 4 then
				local pos = Vector(base.x + math.cos(ang) * rad, base.y + math.sin(ang) * rad, base.z + 28 + frac * 62)
				render.DrawSprite(pos, 21, 21, Color(255, 255, 255, math.floor(a)))
			end
		end
	end
end

local function exhaustPose(m, kind)
	local k  = ME.GetUnitKind and ME.GetUnitKind(kind)
	local ky = (k and k.yaw) or 0
	local sc = m:GetModelScale(); if not sc or sc == 0 then sc = 1 end
	local back = -Angle(0, m:GetAngles().yaw - ky, 0):Forward()
	for _, an in ipairs({ "exhaust", "muffler", "smoke", "exhaust_1" }) do
		local a = m:LookupAttachment(an)
		if a and a > 0 then
			local at = m:GetAttachment(a)
			if at and at.Pos then return at.Pos, back end
		end
	end
	local mins, maxs = ME.UnitBounds(kind, m)
	local lf  = Angle(0, -ky, 0):Forward()
	local ctr = (mins + maxs) * 0.5
	local ext = math.abs(lf.x) * (maxs.x - mins.x) * 0.5 + math.abs(lf.y) * (maxs.y - mins.y) * 0.5
	local lp  = ctr - lf * (ext * 1.05)
	lp.z = mins.z + (maxs.z - mins.z) * 0.30
	return m:LocalToWorld(lp * sc), back
end

local RING_SPEED = 13
local RING_DASH  = 11
local RING_GAP   = 13
local RING_W     = 2.5
local RING_LIFT  = 6

local function hexTopZ(q, r)
	local cell = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]
	return ((ME.MapInfo and ME.MapInfo.baseZ) or 0) + (ME.SurfaceOffset(q, r, cell and cell.biome or "grass") or 0)
end

local function ringLoop(cq, cr, R)
	local segs, byStart = {}, {}
	local side = (ME.Config and ME.Config.HexSize) or 96
	local function key(v) return math.Round(v.x / 3) .. "," .. math.Round(v.y / 3) end
	for dq = -R, R do
		for dr = math.max(-R, -dq - R), math.min(R, -dq + R) do
			local q, r = cq + dq, cr + dr
			if ME.HexDistance(cq, cr, q, r) == R then
				local a = ME.HexToWorld(q, r, 0)
				for s = 0, 5 do
					local nq, nr = ME.FaceNeighbor(q, r, s)
					if ME.HexDistance(cq, cr, nq, nr) > R then
						local b   = ME.HexToWorld(nq, nr, 0)
						local mid = (a + b) * 0.5
						local out = b - a; out.z = 0; out:Normalize()
						local dir = Vector(-out.y, out.x, 0)

						local e   = { a = mid - dir * (side * 0.5), b = mid + dir * (side * 0.5),
						              z = math.max(hexTopZ(q, r), hexTopZ(nq, nr)) + RING_LIFT }
						segs[#segs + 1] = e
						byStart[key(e.a)] = e
					end
				end
			end
		end
	end
	if #segs == 0 then return nil end

	local loop, cur, guard = {}, segs[1], 0
	while cur and guard <= #segs do
		guard = guard + 1
		loop[#loop + 1] = cur
		cur = byStart[key(cur.b)]
		if cur == segs[1] then break end
	end
	return loop
end

local function drawRangeRingAt(worldPos, R)
	if not (worldPos and R and R > 0) then return end
	local cq, cr = ME.WorldToHex(worldPos)
	local loop = ringLoop(cq, cr, R)
	if not loop then return end

	local period = RING_DASH + RING_GAP

	local phase = (RealTime() * RING_SPEED) % period
	local d = 0
	render.SetColorMaterial()
	for _, e in ipairs(loop) do
		local p, q2 = e.a, e.b
		local len = (q2 - p):Length()
		if len > 0.01 then
			local s = math.floor((d + phase) / period) * period - phase
			while s < d + len do
				local a0 = math.max(s, d)
				local a1 = math.min(s + RING_DASH, d + len)
				if a1 > a0 then
					local f0, f1 = (a0 - d) / len, (a1 - d) / len
					local s0, s1 = LerpVector(f0, p, q2), LerpVector(f1, p, q2)
					local dir = s1 - s0; dir.z = 0
					if dir:LengthSqr() > 0.001 then
						dir:Normalize()
						local n  = Vector(-dir.y, dir.x, 0) * (RING_W * 0.5)
						local z  = e.z
						render.DrawQuad(
							Vector(s0.x - n.x, s0.y - n.y, z), Vector(s0.x + n.x, s0.y + n.y, z),
							Vector(s1.x + n.x, s1.y + n.y, z), Vector(s1.x - n.x, s1.y - n.y, z),
							Color(255, 255, 255, 225))
					end
				end
				s = s + period
			end
			d = d + len
		end
	end
end

local function drawHoverRange()
	if not (ME.InGame and ME.InGame()) then return end
	if ME.Build and ME.Build.IsPlacing and ME.Build.IsPlacing() then return end
	if ME.Build and ME.Build.overUI then return end

	local u = ME.UnitRay and ME.UnitRay()
	if IsValid(u) and u.GetUKind then
		local k = ME.GetUnitKind and ME.GetUnitKind(u:GetUKind())
		if k and (k.rangeHex or 0) > 0 then drawRangeRingAt(u:GetPos(), k.rangeHex) return end
	end

	local hit = ME.GroundUnderCursor and ME.GroundUnderCursor()
	if not hit then return end
	local gq, gr = ME.WorldToHex(hit)

	for _, cm in ipairs(ME.CoreModels or {}) do
		if IsValid(cm) then
			local q, r = ME.WorldToHex(cm:GetPos())
			if q == gq and r == gr then
				drawRangeRingAt(cm:GetPos(), ME.CoreDefRangeHex or 5)
				return
			end
		end
	end

	local idx = ME.BuildingAtHex and ME.BuildingAtHex(gq, gr)
	local rec = idx and ME.BuildingModels and ME.BuildingModels[idx]
	if rec and rec.built then
		local b = ME.GetBuilding and ME.GetBuilding(rec.bid)
		if b and (b.rangeHex or 0) > 0 then drawRangeRingAt(rec.model:GetPos(), b.rangeHex) end
	end
end

local function drawExhaust()
	if not ME.UnitModels then return end
	local now = RealTime()
	render.SetMaterial(fxSmoke)
	for _, rec in pairs(ME.UnitModels) do

		if rec.vehicle and not rec.sub and IsValid(rec.model) then
			local m = rec.model
			local pipe, back = exhaustPose(m, rec.kind)
			local moving = rec.moving
			local boat   = rec.boat
			local rate   = (moving and 1.6 or 1.0) * (boat and 0.62 or 1)
			local grow   = (moving and 44 or 34) * (boat and 1.35 or 1)
			local ph0    = (m:EntIndex() % 89) * 0.13
			for k = 0, 13 do
				local phase = (now * rate + k / 14 + ph0) % 1
				local p  = pipe + back * (phase * (moving and 46 or 30))
					+ Vector(math.sin(now * 3 + k) * 4, math.cos(now * 2.6 + k) * 4, 4 + phase * grow)
				local sz = (boat and 16 or 13) + phase * grow
				local a  = (moving and 235 or 195) * (1 - phase) * (phase < 0.1 and phase / 0.1 or 1)
				if a > 2 then render.DrawSprite(p, sz, sz, Color(52, 52, 56, math.floor(a))) end
			end
		end
	end
end

hook.Add("PostDrawTranslucentRenderables", "ME_BoardFX", function(_, sky)
	if sky then return end
	local bob = tideBob()
	local mtx = Matrix(); mtx:Translate(Vector(0, 0, bob))

	local subs = sinkSubs(bob)
	drawSubmarines(subs)
	outlineSubs(subs)
	raiseSubs(subs)
	drawNavalMines()
	if #ME.WaterMeshes > 0 then
		render.SetMaterial(waterMat)
		cam.PushModelMatrix(mtx)
			for _, m in ipairs(ME.WaterMeshes) do m:Draw() end
		cam.PopModelMatrix()
	end
	drawBlueprints()

	for _, s in ipairs(ME.GoldSpots or {}) do if not buildingOnTile(s) then drawGoldDecal(s) end end
	if ME.OilSpots and #ME.OilSpots > 0 then
		local bz = Vector(0, 0, bob)
		render.SetMaterial(oilRippleMat)
		for _, s in ipairs(ME.OilSpots) do
			if not buildingOnTile(s) then drawRipples(s + bz + Vector(0, 0, 2), OIL_GREY, 165) end
		end
	end
	render.SetMaterial(beamMat)
	for _, s in ipairs(ME.SlotSpots or {}) do if not buildingOnTile(s) then drawSlotStripes(s) end end
	for _, c in ipairs(ME.CoreModels) do
		if IsValid(c) then
			local fac = c.MEFaction or 0
			local col = ME.BeamColors and ME.BeamColors[fac]
			if col then
				local sc = c:GetModelScale(); if not sc or sc == 0 then sc = 1 end
				drawBeam(c:GetPos() + Vector(0, 0, c:OBBMaxs().z * sc), col)
				drawRipples(c:GetPos() + Vector(0, 0, 2), col)
			end
		end
	end
	drawMountainFog()
	drawGoldGnats()
	drawIncomeCoins()
	drawGraves()
	drawBurns()
	drawExhaust()
	drawFX()
	drawHoverRange()
	drawSelectionHex()
	drawPlacementHex()
	drawMoveMark()
	drawMovePreview()
end)

local function applyFog(scale)
	scale = scale or 1
	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogColor(ME.Config.Colors.water.r, ME.Config.Colors.water.g, ME.Config.Colors.water.b)
	render.FogStart(3500 * scale); render.FogEnd(15000 * scale); render.FogMaxDensity(1)
	return true
end
hook.Add("SetupWorldFog",  "ME_WorldFog", function()  if ME.InGame and ME.InGame() then return applyFog(1) end end)
hook.Add("SetupSkyboxFog", "ME_SkyFog",   function(s) if ME.InGame and ME.InGame() then return applyFog(s or 1) end end)

hook.Add("ShutDown", "ME_BoardCleanup", destroyBoard)
