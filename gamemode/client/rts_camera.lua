ME = ME or {}
ME.Cam = ME.Cam or {
	focus    = Vector(0, 0, 0),
	yaw      = 0,
	pitch    = 65,
	dist     = 2200,
	selected = {},
	dragging = false,
	dx = 0, dy = 0,
}

local DIST_MIN, DIST_MAX = 700, 9000
local DIST_DEFAULT = 4200

local ROTATE_ICON = Material("mergeempires/game/me_icon_rotate.png", "smooth")
local FOOT_ICON   = Material("mergeempires/game/me_foot.png", "smooth")
local HAMMER_ICON = Material("mergeempires/game/me_hammer.png", "smooth")
local SWORDS_ICON = Material("mergeempires/game/me_swords.png", "smooth")
local PITCH_MIN, PITCH_MAX = 35, 89

local moveIntent = { fwd = false, back = false, left = false, right = false }
hook.Add("CreateMove", "ME_CamMoveIntent", function(cmd)
	if ME.Chat and ME.Chat.typing then
		moveIntent.fwd, moveIntent.back, moveIntent.left, moveIntent.right = false, false, false, false
		return
	end
	moveIntent.fwd   = cmd:KeyDown(IN_FORWARD)
	moveIntent.back  = cmd:KeyDown(IN_BACK)
	moveIntent.left  = cmd:KeyDown(IN_MOVELEFT)
	moveIntent.right = cmd:KeyDown(IN_MOVERIGHT)
end)

local function inGame()
	local ply = LocalPlayer()
	if not IsValid(ply) then return false end
	if ME.MenuActive then return false end
	local t = ply:Team()
	return t >= 1 and t <= ME.Config.MaxFactions
end
ME.InGame = inGame

ME.MatchOver = ME.MatchOver or nil

function ME.InputLocked()
	return ME.MatchOver == "defeat" or ME.MatchOver == "deathcam"
end

function ME.HudOn(name)
	local m = ME.MatchOver
	if m == "defeat" or m == "deathcam" then return false end

	if m == "spectate" then
		return name == "roster" or name == "chat" or name == "camera"
			or name == "exit" or name == "minimap" or name == "custom"
	end
	return true
end

local function matchLive() return GetGlobalInt("ME_MatchPhase", 0) == 2 end

local function camView()
	local c = ME.Cam
	local ang = Angle(c.pitch, c.yaw, 0)
	return c.focus - ang:Forward() * c.dist, ang
end
local function mySelectable()
	local t = LocalPlayer():Team()
	local out = {}

	for _, e in ipairs(ents.GetAll()) do
		if e.MEUnit and ME.EntFaction(e) == t and e:Health() > 0 then
			out[#out + 1] = e
		end
	end

	return out
end

local function entUnderCursor(mx, my)
	if not IsValid(ME.Panel) then return NULL end
	if not mx then mx, my = ME.Panel:LocalCursorPos() end
	local origin = camView()
	local dir = gui.ScreenToVector(mx, my)
	local tr = util.TraceLine({ start = origin, endpos = origin + dir * 32768, filter = LocalPlayer() })
	return tr.Entity
end

local function groundUnderCursor(mx, my)
	if not IsValid(ME.Panel) then return ME.Cam.focus end
	if not mx then mx, my = ME.Panel:LocalCursorPos() end
	local origin = camView()
	local dir = gui.ScreenToVector(mx, my)
	local tr = util.TraceLine({ start = origin, endpos = origin + dir * 32768, mask = MASK_SOLID_BRUSHONLY })
	return tr.HitPos
end
ME.GroundUnderCursor = groundUnderCursor

function ME.HexAtCursor(mx, my)
	if not IsValid(ME.Panel) then return nil end
	if not mx then mx, my = ME.Panel:LocalCursorPos() end
	local origin = camView()
	local dir    = gui.ScreenToVector(mx, my)
	if math.abs(dir.z) < 1e-5 then return nil end
	local p = util.TraceLine({ start = origin, endpos = origin + dir * 32768, mask = MASK_SOLID_BRUSHONLY }).HitPos
	local q, r = ME.WorldToHex(p)
	for _ = 1, 3 do
		local cell = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]
		local zs   = ((ME.MapInfo and ME.MapInfo.baseZ) or 0) + (ME.SurfaceOffset(q, r, cell and cell.biome or "grass") or 0)
		local t    = (zs - origin.z) / dir.z
		if t <= 0 then break end
		p              = origin + dir * t
		local nq, nr   = ME.WorldToHex(p)
		if nq == q and nr == r then break end
		q, r = nq, nr
	end
	return q, r, p
end

local function edgeBuildingRay(mx, my)
	if not (IsValid(ME.Panel) and ME.BuildingModels) then return nil end
	if not mx then mx, my = ME.Panel:LocalCursorPos() end
	local origin = camView()
	local delta  = gui.ScreenToVector(mx, my) * 32768
	local best, bestD
	for idx, rec in pairs(ME.BuildingModels) do
		if IsValid(rec.model) and ME.IsEdgeBuilding and ME.IsEdgeBuilding(rec.bid) then
			local m  = rec.model
			local sc = m:GetModelScale(); if not sc or sc == 0 then sc = 1 end
			local hit = util.IntersectRayWithOBB(origin, delta, m:GetPos(), m:GetAngles(), m:OBBMins() * sc, m:OBBMaxs() * sc)
			if hit then
				local d = origin:DistToSqr(hit)
				if not bestD or d < bestD then bestD, best = d, idx end
			end
		end
	end
	return best
end
ME.EdgeBuildingRay = edgeBuildingRay

local function unitRay(mx, my, team)
	if not (IsValid(ME.Panel) and ME.UnitModels) then return NULL end
	if not mx then mx, my = ME.Panel:LocalCursorPos() end
	local origin = camView()
	local delta  = gui.ScreenToVector(mx, my) * 32768
	local best, bestD
	for idx, rec in pairs(ME.UnitModels) do
		if IsValid(rec.model) and (not team or rec.faction == team) then
			local m  = rec.model
			local sc = m:GetModelScale(); if not sc or sc == 0 then sc = 1 end

			local bmin, bmax = ME.UnitBounds(rec.kind, m)
			local hit = util.IntersectRayWithOBB(origin, delta, m:GetPos(), m:GetAngles(), bmin * sc, bmax * sc)
			if hit then
				local e = Entity(idx)
				if IsValid(e) and e.MEUnit then
					local d = origin:DistToSqr(hit)
					if not bestD or d < bestD then bestD, best = d, e end
				end
			end
		end
	end
	return best or NULL
end
ME.UnitRay = unitRay

local function unitsInRect(x1, y1, x2, y2)
	local lx, rx = math.min(x1, x2), math.max(x1, x2)
	local ty, by = math.min(y1, y2), math.max(y1, y2)
	local out = {}
	for _, u in ipairs(mySelectable()) do
		local s = u:GetPos():ToScreen()
		if s.visible and s.x >= lx and s.x <= rx and s.y >= ty and s.y <= by then
			out[#out + 1] = u
		end
	end
	return out
end

local function cleanSelection()
	local s, out = ME.Cam.selected, {}
	for _, u in ipairs(s) do
		if IsValid(u) and u:Health() > 0 then out[#out + 1] = u end
	end
	ME.Cam.selected = out
end

local function writeIds(sel)
	net.WriteUInt(#sel, 9)
	for _, u in ipairs(sel) do net.WriteUInt(u:EntIndex(), 16) end
end

local function sendMove(sel, pos)
	if #sel == 0 then return end
	net.Start("ME_OrderMove"); writeIds(sel); net.WriteVector(pos); net.SendToServer()
end

local function sendAttackIdx(sel, idx)
	if #sel == 0 or not idx then return end
	net.Start("ME_OrderTarget"); writeIds(sel); net.WriteUInt(idx, 16); net.SendToServer()
end

local function hoverEnemyIdx(mx, my)
	local mine = LocalPlayer():Team()
	local e = entUnderCursor(mx, my)
	if not (IsValid(e) and e.MEUnit) then local re = unitRay(mx, my); if IsValid(re) then e = re end end
	if IsValid(e) and (e.MEUnit or e:GetClass() == "ent_me_core")
	   and ME.EntFaction(e) ~= mine and not ME.AreAllied(ME.EntFaction(e), mine) then
		return e:EntIndex()
	end
	local wpt    = groundUnderCursor(mx, my)
	local gq, gr = ME.WorldToHex(wpt)
	local idx = (ME.EdgeBuildingRay and ME.EdgeBuildingRay(mx, my))
		or (ME.EdgeBuildingAt and ME.EdgeBuildingAt(wpt))
		or (ME.BuildingAtHex and ME.BuildingAtHex(gq, gr))
	if idx and ME.BuildingModels then
		local rec = ME.BuildingModels[idx]

		if rec and rec.faction and rec.faction ~= mine and not ME.AreAllied(rec.faction, mine) then
			return idx
		end
	end

	for _, cm in ipairs(ME.CoreModels or {}) do
		if IsValid(cm) then
			local fac = cm.MEFaction or 0
			if fac > 0 and fac ~= mine and not ME.AreAllied(fac, mine) then
				local cq, cr = ME.WorldToHex(cm:GetPos())
				if cq == gq and cr == gr then
					local ce = ME.CoreEntFor and ME.CoreEntFor(fac)
					if IsValid(ce) then return ce:EntIndex() end
				end
			end
		end
	end
	return nil
end

function ME.CoreEntFor(fac)
	for _, e in ipairs(ents.FindByClass("ent_me_core")) do
		if IsValid(e) and (e.GetFaction and e:GetFaction() or e.MEFaction) == fac then return e end
	end
end

function ME.SelectionDomains()
	local land, sea = false, false
	for _, u in ipairs((ME.Cam and ME.Cam.selected) or {}) do
		if IsValid(u) and u.GetUKind then
			if ME.UnitDomain(u:GetUKind()) == "sea" then sea = true else land = true end
		end
	end
	return land, sea
end

local function selectionHasCombat()
	for _, u in ipairs((ME.Cam and ME.Cam.selected) or {}) do
		if IsValid(u) and u.GetUKind then
			local k = ME.GetUnitKind and ME.GetUnitKind(u:GetUKind())
			if k and (k.dmg or 0) > 0 then return true end
		end
	end
	return false
end

local function onPressed(k)

	if ME.MatchOver then
		if k == MOUSE_LEFT and ME.MatchOver == "spectate" then
			local mx, my = ME.Panel:LocalCursorPos()
			if ME.Custom and ME.Custom.Click and ME.Custom.Click(mx, my) then return end
			if ME.Chat and ME.Chat.ClickBar and ME.Chat.ClickBar(mx, my) then return end
			if ME.Minimap and ME.Minimap.Contains and ME.Minimap.Contains(mx, my) then
				ME.Cam.miniNav = true
			end
		end
		return
	end
	if k == MOUSE_LEFT then
		local mx, my = ME.Panel:LocalCursorPos()
		if ME.Custom and ME.Custom.Click and ME.Custom.Click(mx, my) then return end
		if ME.Build and ME.Build.IsPlacing and ME.Build.IsPlacing() then
			ME.Build.PlaceClick()
			return
		end
		if ME.Scoreboard and ME.Scoreboard.IsOpen and ME.Scoreboard.IsOpen() then
			return
		end
		if ME.Minimap and ME.Minimap.Contains and ME.Minimap.Contains(mx, my) then
			ME.Cam.miniNav = true
			local wx, wy = ME.Minimap.WorldAt(mx, my)
			if wx then ME.Cam.focus.x, ME.Cam.focus.y = wx, wy end
			return
		end
		ME.Cam.dragging = true
		ME.Cam.dx, ME.Cam.dy = mx, my
	end
end

local function onReleased(k)
	if ME.MatchOver then ME.Cam.dragging = false return end
	if k ~= MOUSE_LEFT or not ME.Cam.dragging then return end
	ME.Cam.dragging = false

	local x1, y1 = ME.Cam.dx, ME.Cam.dy
	local x2, y2 = ME.Panel:LocalCursorPos()
	local shift = input.IsButtonDown(KEY_LSHIFT)

	if math.abs(x2 - x1) < 6 and math.abs(y2 - y1) < 6 then
		if ME.Chat and ME.Chat.ClickBar and ME.Chat.ClickBar(x2, y2) then return end
		if ME.Alliance and ME.Alliance.Click and ME.Alliance.Click(x2, y2) then return end
		local mine = LocalPlayer():Team()
		local pick = mine
		local function selectable(u) return IsValid(u) and u.MEUnit and (not pick or ME.EntFaction(u) == pick) end
		local e    = entUnderCursor()

		if not selectable(e) then
			local re = unitRay(x2, y2, pick)
			if IsValid(re) then e = re end
		end

		if matchLive() and selectable(e) then
			if shift then table.insert(ME.Cam.selected, e) else ME.Cam.selected = { e } end
			ME.Cam.inspect = nil
			return
		end

		cleanSelection()
		if matchLive() and #ME.Cam.selected > 0 then
			local enemyIdx = hoverEnemyIdx(x2, y2)
			if enemyIdx then
				sendAttackIdx(ME.Cam.selected, enemyIdx)
			else
				local mp = groundUnderCursor(x2, y2)
				local mq, mr = ME.WorldToHex(mp)

				local bidx = ME.BuildingAtHex and ME.BuildingAtHex(mq, mr)
				local brec = bidx and ME.BuildingModels and ME.BuildingModels[bidx]

				local canBuildIt = false
				if brec then
					for _, u in ipairs(ME.Cam.selected) do
						if IsValid(u) and u.GetUKind and ME.CanBuildAs(u:GetUKind(), brec.bid) then canBuildIt = true break end
					end
				end
				if brec and not brec.built and brec.faction == mine and canBuildIt then

					net.Start("ME_OrderBuild"); writeIds(ME.Cam.selected); net.WriteUInt(bidx, 16); net.SendToServer()
					ME.Cam.moveMark = { q = mq, r = mr, t = CurTime() }
					return
				end
				local mcell  = ME.BoardCells and ME.BoardCells[ME.HexKey(mq, mr)]
				local water  = mcell and mcell.biome == "water"
				local land, sea = ME.SelectionDomains()

				local movers = ME.Cam.selected

				if water and not sea then return end
				if not water and not land then return end
				sendMove(movers, mp)

				ME.Cam.movePaths = ME.Cam.movePaths or {}
				local now, markAt = CurTime(), nil
				for _, u in ipairs(movers) do
					if IsValid(u) and ME.ClientBuildPath then
						local kind = u.GetUKind and u:GetUKind()
						local sq, sr = ME.WorldToHex(u:GetPos())
						local pts = ME.ClientBuildPath(sq, sr, mq, mr, ME.UnitDomain(kind))
						if pts then
							local isB = kind == "builder"
							ME.Cam.movePaths[u:EntIndex()] = { pts = pts, t = now, builder = isB, dest = isB and pts[#pts] or nil,

								dotAt = pts[#pts] }
							markAt = markAt or pts[#pts]
						end
					end
				end

				local kq, kr = mq, mr
				if markAt then kq, kr = ME.WorldToHex(markAt) end
				ME.Cam.moveMark = { q = kq, r = kr, t = CurTime() }
			end
			return
		end

		local wpt    = groundUnderCursor(x2, y2)
		local gq, gr = ME.WorldToHex(wpt)
		local coreEnt
		for _, ce in ipairs(ME.CoreModels or {}) do
			if IsValid(ce) then
				local cq, cr = ME.WorldToHex(ce:GetPos())
				local sp = (ce:GetPos() + Vector(0, 0, 55)):ToScreen()
				if (cq == gq and cr == gr) or (sp.visible and (sp.x - x2) ^ 2 + (sp.y - y2) ^ 2 < ME.UI.Scale(60) ^ 2) then coreEnt = ce break end
			end
		end

		local eIdx = (ME.EdgeBuildingRay and ME.EdgeBuildingRay(x2, y2))
			or (ME.EdgeBuildingAt and ME.EdgeBuildingAt(wpt))
		local bidx = eIdx or (ME.BuildingAtHex and ME.BuildingAtHex(gq, gr))
		if IsValid(coreEnt) and coreEnt.MEFaction == mine then
			ME.Cam.inspect = { kind = "core", faction = coreEnt.MEFaction }
		elseif bidx and ME.BuildingModels and ME.BuildingModels[bidx] and ME.BuildingModels[bidx].faction == mine then
			ME.Cam.inspect = { kind = "building", idx = bidx }
		elseif not shift then
			ME.Cam.inspect = nil
		end
	elseif matchLive() then
		local picked = unitsInRect(x1, y1, x2, y2)
		if shift then
			for _, u in ipairs(picked) do table.insert(ME.Cam.selected, u) end
		else
			ME.Cam.selected = picked
		end
		if #picked > 0 and ME.Sfx then ME.Sfx.Play2D("unit_select") end
		ME.Cam.inspect = nil
	end
end

local function boardCenter()
	local ctr = ME.MapInfo and ME.MapInfo.center
	return ctr and Vector(ctr.x, ctr.y, ctr.z) or Vector(0, 0, 0)
end

local function playerBase()
	local sp = ME.MapInfo and ME.MapInfo.spawns
	local t  = IsValid(LocalPlayer()) and LocalPlayer():Team()
	if sp and t and sp[t] then return Vector(sp[t].x, sp[t].y, sp[t].z) end
	return boardCenter()
end
local function panLimit()
	local margin = ME.Config.CamPanMargin or 1.2
	return (ME.Config.BoardRadius or 26) * (ME.Config.HexSize or 96) * margin
end

local DC_MOVE, DC_HOLD = 1.05, 3.0

function ME.StartDeathCam(pos)
	if ME.DeathCam or ME.MatchOver == "defeat" then return end
	ME.MatchOver = "deathcam"

	local t = IsValid(LocalPlayer()) and LocalPlayer():Team()
	if t and t >= 1 and t <= (ME.Config.MaxFactions or 6) then ME.MyFaction = t end

	local c = ME.Cam
	ME.DeathCam = {
		t0    = RealTime(),
		fFrom = Vector(c.focus.x, c.focus.y, c.focus.z),
		dFrom = c.dist,
		yFrom = c.yaw,
		pFrom = c.pitch,
		fTo   = Vector(pos.x, pos.y, pos.z),
		dTo   = 1500,
		yTo   = c.yaw + 28,
		pTo   = 46,
	}
	ME.Cam.selected = {}
end

local function deathCamThink(c)
	local d  = ME.DeathCam
	local t  = RealTime() - d.t0
	local f  = math.Clamp(t / DC_MOVE, 0, 1)
	local e  = 1 - (1 - f) ^ 3

	c.focus = LerpVector(e, d.fFrom, d.fTo)
	c.dist  = Lerp(e, d.dFrom, d.dTo)
	c.yaw   = Lerp(e, d.yFrom, d.yTo)
	c.pitch = Lerp(e, d.pFrom, d.pTo)
	c.distTarget = c.dist

	if f >= 1 then c.yaw = c.yaw + FrameTime() * 3.5 end

	if t >= DC_MOVE + DC_HOLD then
		ME.DeathCam = nil
		ME.ShowDefeat()
	end
end

local function camThink()
	local c, ft = ME.Cam, FrameTime()

	if ME.DeathCam then deathCamThink(c) return end
	if ME.MatchOver == "defeat" then return end

	if c.miniNav then
		if input.IsMouseDown(MOUSE_LEFT) and ME.Minimap and ME.Minimap.WorldAt then
			local mx, my = ME.Panel:LocalCursorPos()
			local wx, wy = ME.Minimap.WorldAt(mx, my)
			if wx then c.focus.x, c.focus.y = wx, wy end
		else
			c.miniNav = false
		end
	end

	local pan = c.dist * 0.9
	local fwd, right = Angle(0, c.yaw, 0):Forward(), Angle(0, c.yaw, 0):Right()
	local move = Vector(0, 0, 0)
	if moveIntent.fwd   then move = move + fwd end
	if moveIntent.back  then move = move - fwd end
	if moveIntent.right then move = move + right end
	if moveIntent.left  then move = move - right end
	if move:LengthSqr() > 0 then
		move:Normalize()
		c.focus = c.focus + move * pan * ft
	end

	do
		local held = input.IsMouseDown(MOUSE_RIGHT)

		local placing   = ME.Build and ME.Build.IsPlacing and ME.Build.IsPlacing()
		local wantBlank = held or (#c.selected > 0 and not placing)
		if wantBlank ~= c.cursorBlank then
			c.cursorBlank = wantBlank
			if IsValid(ME.Panel) then ME.Panel:SetCursor(wantBlank and "blank" or "arrow") end
		end
		if held and not c.rmbWas then
			c.rmbMoved = false
			c.rmbAnchorX, c.rmbAnchorY = input.GetCursorPos()
			c.rmbLastX = c.rmbAnchorX
		elseif held then
			local mx = input.GetCursorPos()
			local dx = mx - (c.rmbLastX or mx)
			if math.abs(dx) > 1 then c.rmbMoved = true end
			c.yaw = c.yaw - dx * 0.12
			input.SetCursorPos(c.rmbAnchorX, c.rmbAnchorY)
			c.rmbLastX = c.rmbAnchorX
		end
		c.rmbWas = held
	end

	local typing = ME.Chat and ME.Chat.typing
	local cDown = input.IsButtonDown(KEY_C)
	if not typing and cDown and not c._cWasDown then
		c.focus = playerBase()
		c.yaw   = 0
		c.distTarget = math.Clamp(DIST_DEFAULT, DIST_MIN, DIST_MAX)
	end
	c._cWasDown = cDown

	local xDown = input.IsButtonDown(KEY_X)
	if not typing and xDown and not c._xWas and #c.selected > 0 and matchLive() then
		net.Start("ME_OrderStop"); writeIds(c.selected); net.SendToServer()
		c.movePaths = nil
	end
	c._xWas = xDown

	do
		local canPing = not ME.MatchOver
		local vDown = input.IsButtonDown(KEY_V)
		if canPing and not typing and vDown and not c._vWas and ME.Alliance and ME.Alliance.Ping then ME.Alliance.Ping(0) end
		c._vWas = vDown
		local bDown = input.IsButtonDown(KEY_B)
		if canPing and not typing and bDown and not c._bWas and ME.Alliance and ME.Alliance.Ping then ME.Alliance.Ping(1) end
		c._bWas = bDown
	end

	do
		local ctr = boardCenter()
		local lim = panLimit()
		c.focus.x = math.Clamp(c.focus.x, ctr.x - lim, ctr.x + lim)
		c.focus.y = math.Clamp(c.focus.y, ctr.y - lim, ctr.y + lim)
	end

	local frac = (c.dist - DIST_MIN) / (DIST_MAX - DIST_MIN)

	c.distTarget = math.Clamp(c.distTarget or c.dist, DIST_MIN, DIST_MAX)
	c.dist = Lerp(math.min(1, ft * 9), c.dist, c.distTarget)

	local frac2 = (c.dist - DIST_MIN) / (DIST_MAX - DIST_MIN)
	local pitchTarget = Lerp(math.Clamp(frac2, 0, 1), PITCH_MIN + 10, PITCH_MAX - 7)
	c.pitch = Lerp(ft * 8, c.pitch, pitchTarget)

	if not matchLive() then c.selected = {}; c.movePaths = nil end
	cleanSelection()
end

local function paint(_, w, h)

	if input.IsMouseDown(MOUSE_RIGHT) and ME.Cam.rmbMoved and ME.Cam.rmbAnchorX then
		local sz = ME.UI.Scale(44)
		local cx, cy = ME.Cam.rmbAnchorX, ME.Cam.rmbAnchorY
		local ix, iy = cx - sz / 2, cy - sz / 2
		local o = ME.UI.Scale(1)
		surface.SetMaterial(ROTATE_ICON)
		surface.SetDrawColor(0, 0, 0, 235)
		for _, d in ipairs({ { -o, 0 }, { o, 0 }, { 0, -o }, { 0, o }, { -o, -o }, { o, o }, { -o, o }, { o, -o } }) do
			surface.DrawTexturedRect(ix + d[1], iy + d[2], sz, sz)
		end
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(ix, iy, sz, sz)

		local dr = ME.UI.Scale(5)
		draw.RoundedBox(dr, cx - dr, cy - dr, dr * 2, dr * 2, Color(0, 0, 0, 235))
		local dw = ME.UI.Scale(3)
		draw.RoundedBox(dw, cx - dw, cy - dw, dw * 2, dw * 2, color_white)
	end

	local placing = ME.Build and ME.Build.IsPlacing and ME.Build.IsPlacing()
	if #ME.Cam.selected > 0 and not input.IsMouseDown(MOUSE_RIGHT) and not (ME.Build and ME.Build.overUI) and not placing then
		local mx, my = ME.Panel:LocalCursorPos()
		local hammer, swords = false, false
		local anyBuilder = false
		for _, u in ipairs(ME.Cam.selected) do
			local uk = IsValid(u) and u.GetUKind and u:GetUKind()
			if uk == "builder" or uk == "builderboat" then anyBuilder = true break end
		end
		if anyBuilder then
			local hit = ME.GroundUnderCursor and ME.GroundUnderCursor()
			if hit then
				local hq, hr = ME.WorldToHex(hit)
				local bidx = ME.BuildingAtHex and ME.BuildingAtHex(hq, hr)
				local brec = bidx and ME.BuildingModels and ME.BuildingModels[bidx]
				if brec and not brec.built and brec.faction == LocalPlayer():Team() then

					for _, u in ipairs(ME.Cam.selected) do
						if IsValid(u) and u.GetUKind and ME.CanBuildAs(u:GetUKind(), brec.bid) then hammer = true break end
					end
				end
			end
		end

		if not hammer and selectionHasCombat() and hoverEnemyIdx(mx, my) then swords = true end
		local icon = swords and SWORDS_ICON or (hammer and HAMMER_ICON or FOOT_ICON)
		local sz = ME.UI.Scale(swords and 33 or (hammer and 34 or 38))
		surface.SetMaterial(icon)
		surface.SetDrawColor(0, 0, 0, 210)
		surface.DrawTexturedRect(mx - sz / 2 + ME.UI.Scale(1), my - sz / 2 + ME.UI.Scale(1), sz, sz)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(mx - sz / 2, my - sz / 2, sz, sz)
	end

	if ME.Alliance and ME.Alliance.Draw then ME.Alliance.Draw(w, h) end
end

function ME.OpenCommander()
	if IsValid(ME.Panel) then return end
	local p = vgui.Create("DPanel")
	ME.Panel = p
	p:SetSize(ScrW(), ScrH())
	p:SetPos(0, 0)
	p:SetPaintBackground(false)
	p:MakePopup()
	p:SetKeyboardInputEnabled(false)
	p:SetMouseInputEnabled(true)
	p:SetCursor("arrow")

	p.Paint            = paint
	p.OnMousePressed   = function(_, k) onPressed(k) end
	p.OnMouseReleased  = function(_, k) onReleased(k) end
	p.OnMouseWheeled   = function(_, d)
		if ME.InputLocked() then return true end
		ME.Cam.distTarget = math.Clamp((ME.Cam.distTarget or ME.Cam.dist) - d * 300, DIST_MIN, DIST_MAX)
		return true
	end
	p.Think            = camThink
end

function ME.CloseCommander()
	if IsValid(ME.Panel) then ME.Panel:Remove() end
	ME.Panel = nil
end

hook.Add("Think", "ME_EnsurePanel", function()

	if ME.MatchOver == "spectate" then
		local t = IsValid(LocalPlayer()) and LocalPlayer():Team()
		if t == (ME.TEAM_SPECTATOR or 100) then
			ME._specSeen = true
		elseif ME._specSeen and inGame() then
			ME._specSeen, ME.MatchOver = nil, nil
		end
	end

	do
		local ui = gui.IsGameUIVisible()
		if ui ~= ME._uiWasVisible then
			ME._uiWasVisible = ui

			if IsValid(ME.Panel) then
				ME.Panel:SetMouseInputEnabled(not ui)
				ME.Panel:SetVisible(not ui)
				if not ui then ME.Panel:MoveToFront() end
			end
			if ME.Chat and ME.Chat.SetUIHidden then ME.Chat.SetUIHidden(ui) end
			if ui then
				gui.EnableScreenClicker(false)
				ME.Cam.dragging, ME.Cam.miniNav = false, false
			end
		end
	end

	if inGame() or ME.MatchOver == "spectate" then
		if not IsValid(ME.Panel) then ME.OpenCommander() end
	else
		ME.CloseCommander()
	end
end)

net.Receive("ME_CoreLost", function()
	local pos = net.ReadVector()
	if ME.Sfx then ME.Sfx.Play2D("core_lost") end

	ME._coreWasLost = true
	ME.StartDeathCam(pos)
end)

hook.Add("PostRenderVGUI", "ME_SelectionBox", function()
	local c = ME.Cam
	if not (c and c.dragging and IsValid(ME.Panel)) then return end

	if not input.IsMouseDown(MOUSE_LEFT) then c.dragging = false return end
	local x2, y2 = ME.Panel:LocalCursorPos()
	local lx, ty = math.min(c.dx, x2), math.min(c.dy, y2)
	local ww, hh = math.abs(x2 - c.dx), math.abs(y2 - c.dy)
	surface.SetDrawColor(0, 0, 0, 4)
	surface.DrawRect(lx, ty, ww, hh)
	surface.SetDrawColor(255, 255, 255, 215)
	surface.DrawOutlinedRect(lx, ty, ww, hh)
end)

function ME.ShakeCam(amp, dur)
	ME.Shake = { amp = amp or 6, t0 = RealTime(), dur = dur or 0.5 }
end

function ME.ShakeAt(pos, amp, dur, radius)
	if not pos then return end
	local c = ME.Cam
	if not (c and c.focus) then return end
	radius = radius or 2600
	local d = c.focus:Distance(pos)
	if d >= radius then return end
	local near = (1 - d / radius) ^ 1.6
	local zoom = math.Clamp(2600 / math.max(1, c.dist or 2600), 0.30, 1.15)
	local a = (amp or 6) * near * zoom
	if a < 0.35 then return end
	local s = ME.Shake
	if s then
		local left = s.amp * math.max(0, 1 - (RealTime() - s.t0) / s.dur)
		if left >= a then return end
	end
	ME.Shake = { amp = a, t0 = RealTime(), dur = dur or 0.45 }
end

local function shakeOffset()
	local s = ME.Shake
	if not s then return end
	local f = (RealTime() - s.t0) / s.dur
	if f >= 1 then ME.Shake = nil return end
	local a = s.amp * (1 - f)
	return Vector(math.Rand(-a, a), math.Rand(-a, a), math.Rand(-a, a)), a
end

hook.Add("CalcView", "ME_Cam", function()
	if inGame() or ME.MatchOver == "spectate" then
		local origin, ang = camView()
		local off, a = shakeOffset()
		if off then
			origin = origin + off
			ang = Angle(ang.p + math.Rand(-a, a) * 0.05, ang.y + math.Rand(-a, a) * 0.05, ang.r + math.Rand(-a, a) * 0.05)
		end
		return { origin = origin, angles = ang, fov = 60, drawviewmodel = false }
	elseif ME.LobbyActive and ME.MapInfo then
		local ctr = boardCenter()
		local ang = Angle(50, (RealTime() * 5) % 360, 0)
		return { origin = ctr + Vector(0, 0, 700) - ang:Forward() * 7400, angles = ang, fov = 72, drawviewmodel = false }
	end
end)

hook.Add("ShouldDrawLocalPlayer", "ME_NoLocal", function() if inGame() or ME.LobbyActive or ME.MatchOver == "spectate" then return false end end)

local matchBgm, bgmLoading = nil, false
timer.Create("ME_MatchMusic", 1, 0, function()
	local playing = inGame() and GetGlobalInt("ME_MatchPhase", 0) >= 1
	if playing then
		if not IsValid(matchBgm) and not bgmLoading then
			bgmLoading = true
			sound.PlayFile("sound/mergeempires/music/theme_game.mp3", "mono noplay noblock", function(chan)
				bgmLoading = false
				if not IsValid(chan) then return end
				if not inGame() then chan:Stop() return end
				matchBgm = chan
				chan:SetVolume(0.012)
				chan:EnableLooping(true)
				chan:Play()
			end)
		end
	elseif IsValid(matchBgm) then
		matchBgm:Stop()
		matchBgm = nil
	end
end)
