ME = ME or {}
ME.Minimap = ME.Minimap or {}
local M = ME.Minimap

local S = ME.UI.Scale

local RT_RES   = 384
local BG       = Color(47, 48, 44)
local BORDER   = Color(120, 132, 146)
local BLACK    = Color(0, 0, 0, 235)

local MAT_CORE   = Material("mergeempires/game/me_core.png", "smooth")

local rt    = GetRenderTarget("me_minimap_rt", RT_RES, RT_RES)
local rtMat = CreateMaterial("me_minimap_mat", "UnlitGeneric", {
	["$basetexture"] = rt:GetName(),
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
})

local baked, bakedCells, bnds = false, nil, nil

local function biomeColor(biome)
	if biome == "water" then return nil end
	local Cc = ME.Config.Colors or {}
	local c
	if biome == "sand" then c = Cc.sand
	elseif biome == "rock" then c = Cc.darkRock or Cc.rockSide
	else c = Cc.grass end
	if not c then c = Color(140, 140, 140) end
	local g = math.floor(0.299 * c.r + 0.587 * c.g + 0.114 * c.b)
	return Color(g, g, g)
end

local function computeBounds()
	if not ME.BoardCells then return false end
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, cell in pairs(ME.BoardCells) do
		local w = ME.HexToWorld(cell.q, cell.r, 0)
		if w.x < minX then minX = w.x end
		if w.x > maxX then maxX = w.x end
		if w.y < minY then minY = w.y end
		if w.y > maxY then maxY = w.y end
	end
	if minX == math.huge then return false end
	local pad   = 12
	local ww, wh = maxX - minX, maxY - minY
	local scale = (RT_RES - pad * 2) / math.max(ww, wh, 1)
	bnds = {
		minX = minX, maxY = maxY, scale = scale,
		ox = pad + (RT_RES - pad * 2 - ww * scale) / 2,
		oy = pad + (RT_RES - pad * 2 - wh * scale) / 2,
	}
	return true
end

local function worldToRT(wx, wy)
	local b = bnds
	return b.ox + (wx - b.minX) * b.scale, b.oy + (b.maxY - wy) * b.scale
end

local function bake()
	if not computeBounds() then return false end

	local cs = math.max(2, math.ceil(bnds.scale * (ME.Config.HexSize or 96) * 1.75))
	render.PushRenderTarget(rt)
	render.Clear(BG.r, BG.g, BG.b, 255, true, true)
	cam.Start2D()
	for _, cell in pairs(ME.BoardCells) do
		local col = biomeColor(cell.biome)
		if col then
			local w = ME.HexToWorld(cell.q, cell.r, 0)
			local rx, ry = worldToRT(w.x, w.y)
			surface.SetDrawColor(col.r, col.g, col.b, 255)
			surface.DrawRect(rx - cs / 2, ry - cs / 2, cs, cs)
		end
	end
	cam.End2D()
	render.PopRenderTarget()
	baked, bakedCells = true, ME.BoardCells
	return true
end

local function roundedRectPoly(px, py, pw, ph, rad)
	local pts, seg = {}, 12
	local function arc(cx, cy, a0)
		for i = 0, seg do
			local a = math.rad(a0 + 90 * i / seg)
			pts[#pts + 1] = { x = cx + math.cos(a) * rad, y = cy + math.sin(a) * rad }
		end
	end
	arc(px + pw - rad, py + rad, -90)
	arc(px + pw - rad, py + ph - rad, 0)
	arc(px + rad, py + ph - rad, 90)
	arc(px + rad, py + rad, 180)
	return pts
end

local function filledCircle(cx, cy, rad, col)
	local segs = 14
	local poly = {}
	for i = 0, segs - 1 do
		local a = (i / segs) * math.pi * 2
		poly[#poly + 1] = { x = cx + math.cos(a) * rad, y = cy + math.sin(a) * rad }
	end
	draw.NoTexture()
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	surface.DrawPoly(poly)
end

local unitList, nextUnitScan = {}, 0
local function scanUnits()
	if CurTime() < nextUnitScan then return end
	nextUnitScan = CurTime() + 0.3
	unitList = {}
	for _, e in ipairs(ents.GetAll()) do
		if e.MEUnit then unitList[#unitList + 1] = e end
	end
end

local function paintMinimap()
	if ME.HudOn and not ME.HudOn("minimap") then return end
	if not ((ME.InGame and ME.InGame()) or ME.MatchOver == "spectate") then return end
	if baked and bakedCells ~= ME.BoardCells then baked = false end
	if not baked and not bake() then return end

	local MS  = S(272)
	local x   = S(16)
	local y   = ScrH() - MS - S(16)
	local b   = S(2)
	local bk  = S(2)
	local rad = S(6)
	M.rect = { x = x, y = y, MS = MS }

	draw.RoundedBox(rad + b + bk, x - b - bk, y - b - bk, MS + (b + bk) * 2, MS + (b + bk) * 2, BLACK)
	draw.RoundedBox(rad + b, x - b, y - b, MS + b * 2, MS + b * 2, BORDER)

	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(0xFF)
	render.SetStencilTestMask(0xFF)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_NEVER)
	render.SetStencilFailOperation(STENCIL_REPLACE)
	render.SetStencilPassOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	draw.NoTexture()
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawPoly(roundedRectPoly(x, y, MS, MS, rad))
	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.SetStencilFailOperation(STENCIL_KEEP)

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(rtMat)
	surface.DrawTexturedRect(x, y, MS, MS)

	local function toScreen(wx, wy)
		local rx, ry = worldToRT(wx, wy)
		return x + rx / RT_RES * MS, y + ry / RT_RES * MS
	end

	local baseZ  = (ME.MapInfo and ME.MapInfo.baseZ) or 0
	local origin = EyePos()
	local corners = { { 0, 0 }, { ScrW(), 0 }, { ScrW(), ScrH() }, { 0, ScrH() } }
	local pts = {}
	for i, c in ipairs(corners) do
		local dir = gui.ScreenToVector(c[1], c[2])
		local dz  = dir.z > -0.02 and -0.02 or dir.z
		local t   = (baseZ - origin.z) / dz
		local w   = origin + dir * t
		pts[i] = { toScreen(w.x, w.y) }
	end
	surface.SetDrawColor(255, 255, 255, 215)
	for i = 1, 4 do
		local a, bb = pts[i], pts[i % 4 + 1]
		surface.DrawLine(a[1], a[2], bb[1], bb[2])
	end

	if ME.CoreModels then
		surface.SetMaterial(MAT_CORE)
		local is = S(28)
		for _, cm in ipairs(ME.CoreModels) do
			if IsValid(cm) then
				local col = ME.FactionColor(cm.MEFaction or 0)
				local p = cm:GetPos()
				local sx, sy = toScreen(p.x, p.y)
				local ix, iy = sx - is / 2, sy - is / 2
				surface.SetDrawColor(0, 0, 0, 230)
				surface.DrawTexturedRect(ix - S(1), iy - S(1), is + S(2), is + S(2))
				surface.SetDrawColor(col.r, col.g, col.b, 255)
				surface.DrawTexturedRect(ix, iy, is, is)
			end
		end
	end

	if ME.BuildingModels then
		local bs = S(6)
		for _, rec in pairs(ME.BuildingModels) do
			if IsValid(rec.model) then
				local col = ME.FactionColor(rec.faction or 0)
				local p = rec.model:GetPos()
				local sx, sy = toScreen(p.x, p.y)
				surface.SetDrawColor(0, 0, 0, 235)
				surface.DrawRect(sx - bs / 2 - S(1), sy - bs / 2 - S(1), bs + S(2), bs + S(2))
				surface.SetDrawColor(col.r, col.g, col.b, 255)
				surface.DrawRect(sx - bs / 2, sy - bs / 2, bs, bs)
			end
		end
	end

	scanUnits()
	local ur = S(2.2)
	for _, e in ipairs(unitList) do
		if IsValid(e) then
			local col = ME.FactionColor(ME.EntFaction(e))
			local p = e:GetPos()
			local sx, sy = toScreen(p.x, p.y)
			filledCircle(sx, sy, ur + S(1), Color(0, 0, 0, 235))
			filledCircle(sx, sy, ur, col)
		end
	end

	render.SetStencilEnable(false)
end

hook.Add("HUDPaint", "ME_Minimap", paintMinimap)

function M.Contains(mx, my)
	local r = M.rect
	return r ~= nil and mx >= r.x and mx <= r.x + r.MS and my >= r.y and my <= r.y + r.MS
end

function M.WorldAt(mx, my)
	local r = M.rect
	if not r or not bnds then return end
	local rx = (mx - r.x) / r.MS * RT_RES
	local ry = (my - r.y) / r.MS * RT_RES
	return (rx - bnds.ox) / bnds.scale + bnds.minX, bnds.maxY - (ry - bnds.oy) / bnds.scale
end
