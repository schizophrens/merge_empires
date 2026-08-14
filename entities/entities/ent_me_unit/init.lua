AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("ME_UnitSync")
util.AddNetworkString("ME_UnitRemove")
util.AddNetworkString("ME_UnitReq")
util.AddNetworkString("ME_Cargo")

function ME.NetCargo(b)
	if not IsValid(b) or not b.MECarrier then return end
	local plys = team.GetPlayers(b.MEFaction or 0)

	for _, p in ipairs(player.GetAll()) do
		if IsValid(p) and p:IsSuperAdmin() and p:Team() ~= (b.MEFaction or 0) then plys[#plys + 1] = p end
	end
	if #plys == 0 then return end
	local cargo = b.MECargo or {}
	local kinds = {}
	for _, u in ipairs(cargo) do if IsValid(u) then kinds[#kinds + 1] = u.MEKind or "builder" end end
	net.Start("ME_Cargo")
	net.WriteUInt(b:EntIndex(), 16)
	net.WriteUInt(math.min(63, b.MECarrier), 6)
	net.WriteUInt(math.min(63, #kinds), 6)
	for i = 1, math.min(63, #kinds) do net.WriteString(kinds[i]) end
	net.Send(plys)
end

function ME.UnitConcealed(u)
	return IsValid(u) and u.MEHidden and (u._revealUntil or 0) <= CurTime() or false
end

local function spots(u, t)
	return (u.MESpotters and u.MESpotters[t]) or false
end

local function seesUnit(u, ply)
	if not ME.UnitConcealed(u) then return true end
	local t = ply:Team()
	if t == (u.MEFaction or 0) or (ME.AreAllied and ME.AreAllied(t, u.MEFaction or 0)) then return true end
	return spots(u, t)
end
ME.UnitSpotsFrom = spots

function ME.NetUnitSync(u, target)
	if not IsValid(u) then return end

	local send
	if target then
		if IsValid(target) and not seesUnit(u, target) then return end
		send = target
	elseif ME.UnitConcealed(u) then
		send = {}
		for _, p in ipairs(player.GetAll()) do if IsValid(p) and seesUnit(u, p) then send[#send + 1] = p end end
		if #send == 0 then return end
	end
	net.Start("ME_UnitSync")
	net.WriteUInt(u:EntIndex(), 16)
	net.WriteString(u.MEKind or "builder")
	net.WriteString(u:GetModel() or "")
	net.WriteInt(u.MEFaction or 0, 8)
	net.WriteFloat(u.MEScale or 1)
	net.WriteVector(u:GetPos())
	net.WriteAngle(u:GetAngles())
	net.WriteBool(u.Moving and true or false)
	net.WriteUInt(IsValid(u.BuildTarget) and u.BuildTarget:EntIndex() or 0, 16)
	net.WriteBool(u.MEBlocked and true or false)
	net.WriteBool(u.MEStowed and true or false)
	net.WriteBool(ME.UnitConcealed(u))
	if send then net.Send(send) else net.Broadcast() end
end

function ME.RefreshConceal(u)
	if not IsValid(u) then return end
	local prev = u._visShown
	local vis, gained, lost = {}, nil, nil
	for _, p in ipairs(player.GetAll()) do
		if IsValid(p) then
			local now = seesUnit(u, p)
			vis[p] = now
			local was = prev and prev[p]
			if now and not was then gained = gained or {}; gained[#gained + 1] = p
			elseif was and not now then lost = lost or {}; lost[#lost + 1] = p end
		end
	end
	u._visShown = vis
	if lost then
		net.Start("ME_UnitRemove"); net.WriteUInt(u:EntIndex(), 16); net.Send(lost)
	end
	if gained then ME.NetUnitSync(u, gained) end
end

net.Receive("ME_UnitReq", function(_, ply)
	if ME.Throttle(ply, "unitreq", 3) then return end

	for _, u in ipairs(ents.FindByClass("ent_me_unit")) do ME.NetUnitSync(u, ply) end
	for _, u in ipairs(ents.FindByClass("ent_me_unit")) do if u.MECarrier then ME.NetCargo(u) end end
end)

function ENT:SetUnit(kind, faction)
	local k = ME.GetUnitKind(kind)
	self.MEKind    = kind
	self.MEFaction = faction or 0
	self.Speed     = (k.speed or 220) * (ME.UnitSpeedScale or 1)
	self.MEScale   = k.scale or 1
	self.MEYaw     = k.yaw or 0
	self.MERadius  = k.radius or 20
	self.MEDmg     = k.dmg or 0
	self.MERange   = k.range or 0
	self.MERangeHex = k.rangeHex
	self.MEReload  = k.reload or 1
	self.MESplash  = k.splash
	self.MEVehicle = k.vehicle == true
	self.METurn    = k.turn or 150
	self.MEArtillery = k.artillery == true
	self.MEDomain  = k.domain or "land"
	self.MEBoat    = k.boat == true
	self.MECarrier = k.carrier
	self.MEUnitsOnly = k.unitsOnly == true
	self.METierCap = k.tierCap
	self.HP        = k.hp
	self:SetUKind(kind)
	self:SetFaction(faction or 0)

	local base = ME.UnitModel(kind)
	self:SetModel((ME.SkinnedModel and ME.SkinnedModel(faction or 0, "u_" .. kind, base)) or base)
	self:SetMaxHP(k.hp); self:SetHP(k.hp)
	self:SetMaxHealth(k.hp); self:SetHealth(k.hp)
end

function ENT:Initialize()
	if not self:GetModel() or self:GetModel() == "" then self:SetModel("models/tt_soldiers/green_builder.mdl") end
	local s = self.MEScale or 1
	local mins, maxs = Vector(-13, -13, 0) * s, Vector(13, 13, 72) * s
	self:PhysicsInitBox(mins, maxs)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionBounds(mins, maxs)
	self:DrawShadow(true)
	local seq = self:LookupSequence("idle_all_01") ; if seq < 0 then seq = self:LookupSequence("idle") end
	if seq and seq >= 0 then self:ResetSequence(seq) end
	self:SetPlaybackRate(1)
end

function ENT:UpdateTransmitState() return TRANSMIT_ALWAYS end

local function surfaceZ(pos)
	local q, r = ME.WorldToHex(pos)
	local cell = ME.Board and ME.Board.cells and ME.Board.cells[ME.HexKey(q, r)]
	return (ME.Board and ME.Board.baseZ or pos.z) + (ME.SurfaceOffset(q, r, cell and cell.biome or "grass") or 0)
end
ME.SurfaceZAt = surfaceZ
local function hexCenter(q, r)
	local cell = ME.Board and ME.Board.cells and ME.Board.cells[ME.HexKey(q, r)]
	local z = (ME.Board and ME.Board.baseZ or 0) + (ME.SurfaceOffset(q, r, cell and cell.biome or "grass") or 0)
	return ME.HexToWorld(q, r, z)
end

local BLOCK_DECOR = { mountain = true, tree = true, palm = true, rock = true, bush = true }

local MINE_BIDS = { at_mine = true, naval_mine = true }
function ME.IsMineBuilding(e) return IsValid(e) and MINE_BIDS[e.MEBID] or false end

local function occupiedHexes()
	local occ = {}
	for _, cls in ipairs({ "ent_me_building", "ent_me_core" }) do
		for _, e in ipairs(ents.FindByClass(cls)) do

			if IsValid(e) and not (ME.IsEdgeBuilding and ME.IsEdgeBuilding(e.MEBID)) and not MINE_BIDS[e.MEBID] then
				local q, r = ME.WorldToHex(e:GetPos()); occ[ME.HexKey(q, r)] = true
			end
		end
	end
	return occ
end

function ME.BuildingRadius(ent)
	if ent.MECollR then return ent.MECollR end
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local horiz = math.max(math.abs(maxs.x - mins.x), math.abs(maxs.y - mins.y))
	local r
	if horiz <= 1 then r = 16 else
		local hs  = (ME.Config and ME.Config.HexSize) or 96
		local fit = math.Clamp((hs * 1.3) / horiz, 0.35, 1.25)
		local b   = ME.GetBuilding and ME.GetBuilding(ent.MEBID)
		fit = fit * ((b and b.fitMul) or 1)
		r = horiz * 0.5 * fit * 0.82
	end
	ent.MECollR = r
	return r
end

local function edgeKey(q1, r1, q2, r2)
	if q1 < q2 or (q1 == q2 and r1 <= r2) then return q1 .. ":" .. r1 .. "|" .. q2 .. ":" .. r2 end
	return q2 .. ":" .. r2 .. "|" .. q1 .. ":" .. r1
end

local function blockedEdges()
	local set = {}
	for _, e in ipairs(ents.FindByClass("ent_me_building")) do
		if IsValid(e) and e.MEBID == "wall" and e.MEBuilt and e.MEEdge then
			local ed = e.MEEdge
			local nq, nr = ME.FaceNeighbor(ed.q, ed.r, ed.side)
			set[edgeKey(ed.q, ed.r, nq, nr)] = true
		end
	end
	return set
end

local function cellPassable(q, r, occ, domain)
	local cell = ME.Board and ME.Board.cells and ME.Board.cells[ME.HexKey(q, r)]
	if not cell then return false end
	if domain == "sea" then
		if cell.biome ~= "water" then return false end
	else
		if cell.biome == "water" then return false end
		if BLOCK_DECOR[cell.decor] then return false end
	end
	if occ and occ[ME.HexKey(q, r)] then return false end
	return true
end

local function onWalkable(pos, domain)
	local q, r = ME.WorldToHex(pos)
	local cell = ME.Board and ME.Board.cells and ME.Board.cells[ME.HexKey(q, r)]
	if not cell then return false end
	if domain == "sea" then return cell.biome == "water" end
	if cell.biome == "water" then return false end
	if BLOCK_DECOR[cell.decor] then return false end
	return true
end

local losMemo = {}
function ME.ClearLOSCache() losMemo = {} end

function ME.HasLineOfSight(from, to)
	local cells = ME.Board and ME.Board.cells
	if not cells then return true end
	local sq, sr = ME.WorldToHex(from)
	local gq, gr = ME.WorldToHex(to)
	if ME.HexDistance(sq, sr, gq, gr) <= 1 then return true end

	local key = sq .. "," .. sr .. "|" .. gq .. "," .. gr
	local memo = losMemo[key]
	if memo ~= nil then return memo end

	local hs = (ME.Config and ME.Config.HexSize) or 96
	local a, b = ME.HexToWorld(sq, sr, 0), ME.HexToWorld(gq, gr, 0)
	local dx, dy = b.x - a.x, b.y - a.y
	local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / (hs * 0.45)))
	local ok = true
	local pq, pr = sq, sr
	for i = 1, steps - 1 do
		local t = i / steps
		local q, r = ME.WorldToHex(Vector(a.x + dx * t, a.y + dy * t, 0))
		if q ~= pq or r ~= pr then
			local c = cells[ME.HexKey(q, r)]
			if c and BLOCK_DECOR[c.decor] then ok = false break end
			pq, pr = q, r
		end
	end
	losMemo[key] = ok
	return ok
end

local function hexTier(q, r)
	local cell  = ME.Board and ME.Board.cells and ME.Board.cells[ME.HexKey(q, r)]
	local biome = cell and cell.biome or "grass"
	local H     = (ME.Config and ME.Config.Heights) or {}
	local step  = (ME.Config and ME.Config.TierStep) or 20
	return math.Round(((ME.SurfaceOffset(q, r, biome) or 0) - (H.grass or 0)) / step)
end

local function tierStepOK(aq, ar, bq, br, domain)
	if domain == "sea" then return true end
	return math.abs(hexTier(aq, ar) - hexTier(bq, br)) <= 1
end

local function nearestPassable(gq, gr, occ, domain)
	if cellPassable(gq, gr, occ, domain) then return gq, gr end
	local seen, frontier = { [ME.HexKey(gq, gr)] = true }, { { gq, gr } }
	for _ = 1, 40 do
		local nxt = {}
		for _, h in ipairs(frontier) do
			for _, nb in ipairs(ME.HexNeighbors(h[1], h[2])) do
				local k = ME.HexKey(nb[1], nb[2])
				if not seen[k] then
					seen[k] = true
					if cellPassable(nb[1], nb[2], occ, domain) then return nb[1], nb[2] end
					nxt[#nxt + 1] = nb
				end
			end
		end
		frontier = nxt
		if #frontier == 0 then break end
	end
	return nil
end

local function lineClear(aq, ar, bq, br, occ, blocked, domain)
	local a, b = ME.HexToWorld(aq, ar, 0), ME.HexToWorld(bq, br, 0)
	local dx, dy = b.x - a.x, b.y - a.y
	local steps  = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / ((ME.Config.HexSize or 96) * 0.45)))
	local pq, pr
	for i = 0, steps do
		local t = i / steps
		local q, r = ME.WorldToHex(Vector(a.x + dx * t, a.y + dy * t, 0))
		if not cellPassable(q, r, occ, domain) then return false end
		if pq and (q ~= pq or r ~= pr) then
			if not tierStepOK(pq, pr, q, r, domain) then return false end
			if blocked and blocked[edgeKey(pq, pr, q, r)] then return false end
		end
		pq, pr = q, r
	end
	return true
end

local function stringPull(sq, sr, hexes, occ, blocked, domain)
	local full = { { sq, sr } }
	for _, h in ipairs(hexes) do full[#full + 1] = h end
	local out, i = {}, 1
	while i < #full do
		local j = #full
		while j > i + 1 do
			if lineClear(full[i][1], full[i][2], full[j][1], full[j][2], occ, blocked, domain) then break end
			j = j - 1
		end
		out[#out + 1] = full[j]
		i = j
	end
	return out
end

local STRUCT_COST = 4

function ME.FindHexPath(sq, sr, gq, gr, domain)
	local occ     = occupiedHexes()
	local blocked = blockedEdges()
	occ[ME.HexKey(sq, sr)] = nil

	gq, gr = nearestPassable(gq, gr, nil, domain)
	if not gq then return nil end
	local startK, goalK = ME.HexKey(sq, sr), ME.HexKey(gq, gr)
	if startK == goalK then return {} end

	local coordOf = { [startK] = { sq, sr } }
	local came, gS = {}, { [startK] = 0 }
	local fS = { [startK] = ME.HexDistance(sq, sr, gq, gr) }
	local open = { [startK] = true }
	local guard = 0
	while next(open) and guard < 6000 do
		guard = guard + 1
		local curK, bestF = nil, math.huge
		for k in pairs(open) do local fk = fS[k] or math.huge; if fk < bestF then bestF, curK = fk, k end end
		if not curK then break end
		if curK == goalK then
			local path, k = {}, goalK
			while came[k] do local c = coordOf[k]; table.insert(path, 1, { c[1], c[2] }); k = came[k] end
			return stringPull(sq, sr, path, occ, blocked, domain)
		end
		open[curK] = nil
		local cc = coordOf[curK]
		for _, nb in ipairs(ME.HexNeighbors(cc[1], cc[2])) do
			local nq, nr, nk = nb[1], nb[2], ME.HexKey(nb[1], nb[2])
			if cellPassable(nq, nr, nil, domain) and tierStepOK(cc[1], cc[2], nq, nr, domain)
			   and not blocked[edgeKey(cc[1], cc[2], nq, nr)] then
				local tentative = (gS[curK] or math.huge) + (occ[nk] and STRUCT_COST or 1)
				if tentative < (gS[nk] or math.huge) then
					coordOf[nk], came[nk] = { nq, nr }, curK
					gS[nk] = tentative
					fS[nk] = tentative + ME.HexDistance(nq, nr, gq, gr)
					open[nk] = true
				end
			end
		end
	end
	return nil
end

function ME.SpawnSpot(pos, domain)
	local q, r = ME.WorldToHex(pos)
	local occ  = occupiedHexes()
	local nq, nr = nearestPassable(q, r, occ, domain)
	if not nq then return pos end
	if nq == q and nr == r then return pos end
	return hexCenter(nq, nr)
end

local BUILD_RANGE = ((ME.Config and ME.Config.HexSize) or 96) * 1.9

function ENT:OrderMove(pos, manual)
	self.BuildTarget, self.Building = nil, false
	if manual then self.MEForceTarget = nil; self.MERepairTarget = nil end
	if self.MEStowed then return end
	self._buildStuck, self._buildFromHere, self._closeSince = nil, nil, nil
	local sq, sr = ME.WorldToHex(self:GetPos())
	local gq, gr = ME.WorldToHex(pos)
	local hexes  = ME.FindHexPath(sq, sr, gq, gr, self.MEDomain)
	if hexes and #hexes > 0 then
		self.Path, self.PathI = {}, 1
		for _, h in ipairs(hexes) do self.Path[#self.Path + 1] = hexCenter(h[1], h[2]) end
		self.GoalQ, self.GoalR = hexes[#hexes][1], hexes[#hexes][2]
		self.MoveTarget = self.Path[1]
		self.Moving     = true
		self.MEBlocked  = false
	else

		self.Path, self.PathI, self.MoveTarget, self.Moving = nil, nil, nil, false
		self.GoalQ, self.GoalR = nil, nil
		self.MEBlocked = (sq ~= gq or sr ~= gr)
	end
	ME.NetUnitSync(self)
end

function ENT:OrderAttack(target)
	if not IsValid(target) then return end
	if (self.MEDmg or 0) <= 0 then self:OrderMove(target:GetPos()) return end

	local tp  = target:GetPos()
	local dir = self:GetPos() - tp; dir.z = 0
	local d   = dir:Length()
	if d > 1 then dir:Normalize() else dir = Vector(1, 0, 0) end
	local stand = tp + dir * math.min(d, (self.MERange or 400) * 0.75)
	self:OrderMove(stand)
	self.MEForceTarget = target
end

function ME.RepathNear(pos, hexRadius)
	local r2 = ((hexRadius or 6) * 1.732 * ((ME.Config and ME.Config.HexSize) or 96)) ^ 2
	for _, u in ipairs(ents.FindByClass("ent_me_unit")) do
		if IsValid(u) and u.Moving and u.GoalQ and not IsValid(u.BuildTarget) and u:GetPos():DistToSqr(pos) < r2 then
			u:OrderMove(ME.HexToWorld(u.GoalQ, u.GoalR, 0))
		end
	end
end

function ENT:OrderBuild(b)
	if not IsValid(b) then return end

	if not (ME.CanBuildAs and ME.CanBuildAs(self.MEKind, b.MEBID)) then return end

	local bq, br = ME.WorldToHex(b:GetPos())
	local sq, sr = ME.WorldToHex(self:GetPos())
	local best, bestLen
	for _, nb in ipairs(ME.HexNeighbors(bq, br)) do
		local path = ME.FindHexPath(sq, sr, nb[1], nb[2], self.MEDomain)
		if path then
			local len = #path
			if not bestLen or len < bestLen then bestLen, best = len, nb end
		end
	end
	self._buildStuck, self._buildFromHere, self._closeSince = nil, nil, nil
	self:OrderMove(best and ME.HexToWorld(best[1], best[2], 0) or b:GetPos())
	self.BuildTarget, self.Building = b, false
end

function ME.CargoCount(b) return (b.MECargo and #b.MECargo) or 0 end
function ME.CargoFull(b) return ME.CargoCount(b) >= (b.MECarrier or 0) end

local function stow(u, barge)
	barge.MECargo = barge.MECargo or {}
	if ME.CargoFull(barge) then return false end
	u.MEStowed = barge
	u.Path, u.PathI, u.MoveTarget, u.Moving = nil, nil, nil, false
	u.GoalQ, u.GoalR, u.MEBlocked = nil, nil, false
	u.BuildTarget, u.Building, u.MERepairTarget, u.MEForceTarget = nil, false, nil, nil
	u:SetPos(barge:GetPos())
	barge.MECargo[#barge.MECargo + 1] = u
	ME.NetUnitSync(u)
	ME.NetCargo(barge)
	return true
end

local function landingSpots(centre)
	local hs = (ME.Config and ME.Config.HexSize) or 96
	local spots = { centre }
	for ri, rad in ipairs({ hs * 0.33, hs * 0.62 }) do
		local n = (ri == 1) and 5 or 8
		for i = 1, n do
			local a = (i / n) * math.pi * 2 + ri * 0.7
			spots[#spots + 1] = centre + Vector(math.cos(a), math.sin(a), 0) * rad
		end
	end
	return spots
end

local function spotFree(sp, u, taken, units, builds)
	if not onWalkable(sp, "land") then return false end
	local ur = u.MERadius or 20
	for _, t in ipairs(taken) do
		local d = t - sp; d.z = 0
		if d:Length() < ur * 2 then return false end
	end
	for _, o in ipairs(units) do
		if IsValid(o) and o ~= u and not o.MEStowed then
			local d = o:GetPos() - sp; d.z = 0
			if d:Length() < ur + (o.MERadius or 20) then return false end
		end
	end
	for _, b in ipairs(builds) do
		if IsValid(b) and not (ME.IsEdgeBuilding and ME.IsEdgeBuilding(b.MEBID)) and not MINE_BIDS[b.MEBID] then
			local d = b:GetPos() - sp; d.z = 0
			if d:Length() < ur + ME.BuildingRadius(b) then return false end
		end
	end
	return true
end

function ENT:BargePutAshore(q, r)
	local cargo = self.MECargo
	if not cargo or #cargo == 0 then return 0 end
	local spots  = landingSpots(hexCenter(q, r))
	local units  = ents.FindByClass("ent_me_unit")
	local builds = ents.FindByClass("ent_me_building")
	for _, c in ipairs(ents.FindByClass("ent_me_core")) do builds[#builds + 1] = c end
	local taken, landed = {}, 0
	for i = #cargo, 1, -1 do
		local u = cargo[i]
		if not IsValid(u) then
			table.remove(cargo, i)
		else
			local put
			for _, sp in ipairs(spots) do
				if spotFree(sp, u, taken, units, builds) then put = Vector(sp.x, sp.y, sp.z) break end
			end
			if put then
				table.remove(cargo, i)
				taken[#taken + 1] = put
				put.z = surfaceZ(put)
				u.MEStowed = nil
				u:SetPos(put)
				u:OrderMove(put, true)
				landed = landed + 1
			end
		end
	end
	if landed > 0 then ME.NetCargo(self) end
	return landed
end

local function sealedShore(fac)
	local set = {}
	for _, e in ipairs(ents.FindByClass("ent_me_building")) do
		if IsValid(e) and e.MEBuilt and e.MEEdge and (e.MEBID == "wall" or e.MEBID == "gate") then
			local mine = (e.MEFaction or 0) == fac or (ME.AreAllied and ME.AreAllied(e.MEFaction or 0, fac))
			if e.MEBID == "wall" or not mine then
				local ed = e.MEEdge
				local nq, nr = ME.FaceNeighbor(ed.q, ed.r, ed.side)
				set[edgeKey(ed.q, ed.r, nq, nr)] = true
			end
		end
	end
	return set
end

function ENT:BargeLanding(q, r)
	if not self.MECarrier then return nil, "notransport" end
	local cells = ME.Board and ME.Board.cells
	if not cells then return nil, "nobeach" end
	local bq, br = ME.WorldToHex(self:GetPos())
	local here   = cells[ME.HexKey(bq, br)]
	if not here or here.biome ~= "water" then return nil, "notwater" end
	local sealed = sealedShore(self.MEFaction or 0)
	local walled = false
	for _, nb in ipairs(ME.HexNeighbors(bq, br)) do
		if not q or (nb[1] == q and nb[2] == r) then
			local c = cells[ME.HexKey(nb[1], nb[2])]
			if c and c.biome == "sand" then
				if sealed[edgeKey(bq, br, nb[1], nb[2])] then walled = true
				else return nb[1], nb[2] end
			end
		end
	end
	return nil, walled and "walled" or "nobeach"
end

function ME.IsBeachHex(q, r)
	local c = ME.Board and ME.Board.cells and ME.Board.cells[ME.HexKey(q, r)]
	return c ~= nil and c.biome == "sand"
end

function ENT:BargeCallIn()
	if not self.MECarrier then return 0 end
	local free = (self.MECarrier or 0) - ME.CargoCount(self)
	if free <= 0 then return 0 end
	local k     = ME.UnitKinds[self.MEKind or ""]
	local tiles = (k and k.pickupHex) or 2
	local fac   = self.MEFaction or 0
	local bq, br = ME.WorldToHex(self:GetPos())
	local list = {}
	for _, u in ipairs(ents.FindByClass("ent_me_unit")) do
		if IsValid(u) and u ~= self and not u.MEStowed and (u.MEFaction or 0) == fac and u.MEDomain ~= "sea" then
			local uq, ur = ME.WorldToHex(u:GetPos())
			if ME.HexDistance(bq, br, uq, ur) <= tiles and ME.IsBeachHex(uq, ur) then
				local d = u:GetPos() - self:GetPos(); d.z = 0
				list[#list + 1] = { u = u, d = d:Length() }
			end
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	local n = 0
	for i = 1, math.min(#list, math.max(0, free)) do
		if stow(list[i].u, self) then n = n + 1 end
	end
	return n
end

function ENT:BargeDropOff()
	if ME.CargoCount(self) == 0 then return nil, "empty" end
	local q, r, why = self:BargeLanding(nil, nil)
	if not q then return nil, why end
	local n = self:BargePutAshore(q, r)
	if n == 0 then return nil, "nospace" end
	return n
end

function ENT:Think()
	local now = CurTime()
	local nt  = now + 0.03
	local dt  = math.Clamp(now - (self._lastThink or now), 0, 0.25)
	self._lastThink = now

	if self.MEStowed then
		if IsValid(self.MEStowed) then self:SetPos(self.MEStowed:GetPos()) else self.MEStowed = nil end
		self:NextThink(nt)
		return true
	end

	if IsValid(self.BuildTarget) then
		local bt   = self.BuildTarget
		local dist = self:GetPos():Distance(bt:GetPos())
		local CLOSE = ((ME.Config and ME.Config.HexSize) or 96) * 0.85
		if bt.MEBuilt then
			self.BuildTarget, self.Building, self.Path, self.MoveTarget, self.Moving = nil, false, nil, nil, false
			ME.NetUnitSync(self)
		elseif dist <= BUILD_RANGE then
			self.Path, self.MoveTarget = nil, nil
			self._buildStuck = nil

			if dist > CLOSE and not self._buildFromHere then
				self._closeSince = self._closeSince or CurTime()
				if CurTime() - self._closeSince > 2 then
					self._buildFromHere = true
				else
					local dir = bt:GetPos() - self:GetPos(); dir.z = 0
					local d = dir:Length(); dir:Normalize()
					local np = self:GetPos() + dir * math.min((self.Speed or 220) * dt, d - CLOSE)
					if not onWalkable(np, self.MEDomain) then self._buildFromHere = true; self:NextThink(nt); return true end
					np.z = surfaceZ(np)
					self:SetPos(np)
					self:SetAngles(Angle(0, dir:Angle().yaw + (self.MEYaw or 0), 0))
					self.Building, self.Moving = false, true
					if (self._nextSync or 0) <= CurTime() then self._nextSync = CurTime() + 0.1; ME.NetUnitSync(self) end
					self:NextThink(nt)
					return true
				end
			end

			self._closeSince = nil
			self.MEBlocked   = false
			if self.Moving or not self.Building then
				self.Building, self.Moving = true, false
				self:SetAngles(Angle(0, (bt:GetPos() - self:GetPos()):Angle().yaw + (self.MEYaw or 0), 0))
				ME.NetUnitSync(self)
			end
			self:NextThink(nt)
			return true
		else
			self.Building, self._buildFromHere, self._closeSince = false, nil, nil
			if self._buildStuck then

				if self.Moving then self.Moving = false; ME.NetUnitSync(self) end
			elseif not self.MoveTarget then
				self:OrderMove(bt:GetPos())
				self.BuildTarget = bt
			end
		end
	end
	if self.MoveTarget then
		local cur  = self:GetPos()
		local flat = self.MoveTarget - cur; flat.z = 0
		local dist = flat:Length()

		local last   = not (self.Path and self.Path[(self.PathI or 1) + 1])
		local reached = last and 28 or 10
		if dist < reached then
			self.PathI = (self.PathI or 1) + 1
			if self.Path and self.Path[self.PathI] then
				self.MoveTarget = self.Path[self.PathI]
			else
				self.Path, self.MoveTarget, self.Moving, self.GoalQ, self.GoalR = nil, nil, false, nil, nil
				ME.NetUnitSync(self)
			end
		else
			local dir  = flat:GetNormalized()
			local step = math.min((self.Speed or 220) * dt, dist)
			local np   = cur + dir * step
			np.z = surfaceZ(np)
			self:SetPos(np)
			self:SetAngles(Angle(0, dir:Angle().yaw + (self.MEYaw or 0), 0))
			self.Moving = true
			if (self._nextSync or 0) <= CurTime() then
				self._nextSync = CurTime() + 0.1
				ME.NetUnitSync(self)
			end
		end
	end
	self:NextThink(nt)
	return true
end

local PUSH_TIMEOUT = 2
hook.Add("Think", "ME_UnitSeparation", function()

	local units = {}
	for _, u in ipairs(ents.FindByClass("ent_me_unit")) do
		if IsValid(u) and not u.MEStowed then units[#units + 1] = u end
	end
	local n = #units
	if n == 0 then return end
	local t = CurTime()
	for _, u in ipairs(units) do u._pushedNow = false end

	local builds = ents.FindByClass("ent_me_building")
	for _, c in ipairs(ents.FindByClass("ent_me_core")) do builds[#builds + 1] = c end
	for _, u in ipairs(units) do
		if IsValid(u) and not u.MoveTarget and not (u._debugNoclip and u._debugNoclip > t) then
			for _, bl in ipairs(builds) do
				if IsValid(bl) and not (ME.IsEdgeBuilding and ME.IsEdgeBuilding(bl.MEBID)) and not MINE_BIDS[bl.MEBID] then
					local d = u:GetPos() - bl:GetPos(); d.z = 0
					local dist = d:Length()
					local minD = (u.MERadius or 20) + ME.BuildingRadius(bl)
					if dist < minD then

						local dir = dist > 0.1 and d:GetNormalized()
							or Vector(math.cos(u:EntIndex()), math.sin(u:EntIndex()), 0):GetNormalized()
						local np  = bl:GetPos() + dir * minD
						if onWalkable(np, u.MEDomain) then np.z = surfaceZ(np); u:SetPos(np)
							if (u._nextSync or 0) <= t then u._nextSync = t + 0.1; ME.NetUnitSync(u) end end
					end
				end
			end
		end
	end

	for i = 1, n do
		local a = units[i]
		if IsValid(a) then
			local aNoclip = a._debugNoclip and a._debugNoclip > t
			for j = i + 1, n do
				local b = units[j]
				if IsValid(b) and not aNoclip and not (b._debugNoclip and b._debugNoclip > t) then

					local d = a:GetPos() - b:GetPos(); d.z = 0
					local dist = d:Length()
					local minD = (a.MERadius or 20) + (b.MERadius or 20)
					if dist < minD then
						a._pushedNow, b._pushedNow = true, true

						local dir  = dist > 0.1 and d:GetNormalized() or Vector(((i * 7 + j) % 3) - 1, ((i * 5) % 3) - 1, 0):GetNormalized()
						local push = dir * ((minD - math.max(dist, 0.1)) * 0.5 + 0.5)
						local ap = a:GetPos() + push
						if onWalkable(ap, a.MEDomain) then ap.z = surfaceZ(ap); a:SetPos(ap)
							if (a._nextSync or 0) <= t then a._nextSync = t + 0.1; ME.NetUnitSync(a) end end
						local bp = b:GetPos() - push
						if onWalkable(bp, b.MEDomain) then bp.z = surfaceZ(bp); b:SetPos(bp)
							if (b._nextSync or 0) <= t then b._nextSync = t + 0.1; ME.NetUnitSync(b) end end
					end
				end
			end
		end
	end

	for _, u in ipairs(units) do
		if IsValid(u) then
			if u._pushedNow and (u.MoveTarget or IsValid(u.BuildTarget)) then
				u._pushSince = u._pushSince or t
				if (t - u._pushSince) > PUSH_TIMEOUT then
					u._debugNoclip = t + 2
					u._pushSince = nil
				end
			else
				u._pushSince = nil
			end
		end
	end
end)

function ENT:OnRemove()

	if self.MECargo then
		for _, c in ipairs(self.MECargo) do
			if IsValid(c) then
				c.MEStowed = nil
				c:Remove()
			end
		end
		self.MECargo = nil
	end

	if IsValid(self.MEStowed) and self.MEStowed.MECargo then
		table.RemoveByValue(self.MEStowed.MECargo, self)
		ME.NetCargo(self.MEStowed)
	end

	local idx, fac = self:EntIndex(), self.MEFaction or 0
	timer.Simple(0, function()
		net.Start("ME_UnitRemove"); net.WriteUInt(idx, 16); net.Broadcast()
		if ME.RefreshPop then ME.RefreshPop(fac) end
	end)
end

function ENT:OnTakeDamage(dmg)
	local attacker = dmg:GetAttacker()
	if IsValid(attacker) and attacker:IsPlayer() then
		if attacker:Team() == self.MEFaction then return end
		if ME.AreAllied and ME.AreAllied(attacker:Team(), self.MEFaction) then return end
	end
	local hp = self:GetHP() - dmg:GetDamage()
	self:SetHP(math.max(0, math.floor(hp)))
	self:SetHealth(math.max(0, math.floor(hp)))
	if hp <= 0 then self:Remove() end
end

util.AddNetworkString("ME_Fire")
util.AddNetworkString("ME_UnitDied")
util.AddNetworkString("ME_Artillery")
util.AddNetworkString("ME_MineBlast")

local function facOf(e) return e.MEFaction or (ME.EntFaction and ME.EntFaction(e)) or 0 end
local function isEnemyEnt(myFac, e)
	local f = facOf(e)
	if f <= 0 or f == myFac then return false end
	if ME.AreAllied and ME.AreAllied(myFac, f) then return false end
	return true
end

local function tierReachable(u, e)
	local cap = u and u.METierCap
	if not cap then return true end
	local q, r = ME.WorldToHex(e:GetPos())
	return hexTier(q, r) <= cap
end

local function targetable(e, u)
	if e == u or not IsValid(e) then return false end
	if e.MEStowed then return false end

	if u and not u.MEArtillery and ME.HasLineOfSight and not ME.HasLineOfSight(u:GetPos(), e:GetPos()) then
		return false
	end
	local c = e:GetClass()
	if c == "ent_me_building" then

		if MINE_BIDS[e.MEBID] then return false end
		if u and u.MEUnitsOnly then return false end
		return tierReachable(u, e)
	end
	if c == "ent_me_core" then
		if u and u.MEUnitsOnly then return false end
		return tierReachable(u, e)
	end
	if c == "ent_me_unit" then

		if u and (e.MEFaction or 0) ~= (u.MEFaction or 0) then
			if ME.UnitConcealed(e) and not ME.UnitSpotsFrom(e, u.MEFaction or 0) then return false end

			if ME.UnitConcealed(u) and not ME.UnitSpotsFrom(u, e.MEFaction or 0) then return false end
		end
		return not (u and u.MEArtillery)
	end
	return false
end

local function targetPriority(e)
	local c = e:GetClass()
	if c == "ent_me_unit" then return 0 end
	if c == "ent_me_core" then return 3 end
	if c == "ent_me_building" then
		local b = ME.GetBuilding and ME.GetBuilding(e.MEBID)
		return (b and b.cat == "defense") and 1 or 2
	end
	return 4
end

function ME.NetUnitDied(pos, kind)
	if util.NetworkStringToID("ME_UnitDied") == 0 then return end
	net.Start("ME_UnitDied")
	net.WriteVector(pos)
	net.WriteString(kind or "")
	net.Broadcast()
end

local SPLASH_UNIT   = 0.5
local SPLASH_STRUCT = 0.5
local function splashFrac(o, dist, radius)
	local base = (o:GetClass() == "ent_me_unit") and SPLASH_UNIT or SPLASH_STRUCT
	return base * math.max(0, 1 - dist / math.max(1, radius))
end

local REVEAL_TIME = 3

function ME.NetFire(shooter, tpos, splash, victimFac)
	if IsValid(shooter) and shooter.MEHidden then
		shooter._revealUntil = CurTime() + REVEAL_TIME
		ME.RefreshConceal(shooter)
	end
	net.Start("ME_Fire")
	net.WriteUInt(shooter:EntIndex(), 16)
	net.WriteVector(tpos)
	net.WriteBool(splash and true or false)
	net.WriteInt(shooter.MEFaction or 0, 8)
	net.WriteInt(victimFac or 0, 8)
	net.Broadcast()
end

local function damageEnt(target, dmg, attFac)
	if not IsValid(target) then return end
	local c = target:GetClass()
	if ME.MSAddDamage then ME.MSAddDamage(attFac, dmg) end
	if c == "ent_me_unit" then
		target.HP = (target.HP or target:GetHP()) - dmg
		target:SetHP(math.max(0, math.floor(target.HP)))
		if target.HP <= 0 then
			if ME.MSAddKill then ME.MSAddKill(attFac, 1) end
			ME.NetUnitDied(target:GetPos(), target.MEKind)
			target:Remove()
		end
	elseif c == "ent_me_building" then

		if not target.MEBuilt then
			target._destroyed = true
			target:Remove()
			return
		end
		target.HP = (target.HP or 500) - dmg
		target:SetNWInt("MEHP", math.max(0, math.floor(target.HP)))
		if (target._hpNet or 0) <= CurTime() then
			target._hpNet = CurTime() + 0.1
			net.Start("ME_BuildingHP")
			net.WriteUInt(target:EntIndex(), 16)
			net.WriteInt(math.max(0, math.floor(target.HP)), 32)
			net.Broadcast()
		end
		if target.HP <= 0 then

			local b = ME.GetBuilding and ME.GetBuilding(target.MEBID)
			if b and ME.AddFactionMoney then ME.AddFactionMoney(attFac, math.floor((b.price or 0) * 0.5)) end
			target._destroyed = true; target:Remove()
		end
	elseif c == "ent_me_core" then
		target._lastAttFac = attFac
		local nh = target:GetHP() - dmg
		target:SetHP(math.max(0, math.floor(nh)))
		target:SetHealth(math.max(0, math.floor(nh)))
		if target.PushHP then target:PushHP() end
		if nh <= 0 and not target._meDead then
			target._meDead = true

			if target.MEMeltdown then target:MEMeltdown()
			elseif target.MEDie then target:MEDie() end
		end
	end
end

local ART_AIM, ART_GAP = 3.0, 0.18
local ART_FLIGHT = (ME.Config and ME.Config.ArtFlight) or 1.1
function ME.FireArtillery(u, tpos)
	if not IsValid(u) then return end
	local myFac  = u.MEFaction or 0
	local dmg    = u.MEDmg or 100
	local splash = u.MESplash or 180

	local interceptor = ME.FindInterceptor and ME.FindInterceptor(myFac, tpos)

	net.Start("ME_Artillery")
	net.WriteUInt(u:EntIndex(), 16)
	net.WriteVector(tpos)
	net.WriteUInt(IsValid(interceptor) and interceptor:EntIndex() or 0, 16)
	net.Broadcast()

	if IsValid(interceptor) then return end

	for i = 1, 4 do
		timer.Simple(ART_AIM + i * ART_GAP + ART_FLIGHT, function()
			if not (ME.MatchActive and IsValid(u)) then return end
			for _, o in ipairs(ents.FindInSphere(tpos, splash)) do
				local c = IsValid(o) and o:GetClass()
				if (c == "ent_me_building" and not MINE_BIDS[o.MEBID] or c == "ent_me_core") and isEnemyEnt(myFac, o) then
					damageEnt(o, dmg, myFac)
				elseif c == "ent_me_unit" and not o.MEStowed and isEnemyEnt(myFac, o) then
					local f = splashFrac(o, tpos:Distance(o:GetPos()), splash)
					if f > 0 then damageEnt(o, dmg * f, myFac) end
				end
			end
		end)
	end
end

ME.DamageEnt = damageEnt
ME.IsEnemyEnt = isEnemyEnt

local VEH_FIRE_ARC = 10
local function aimVehicle(u, tpos)
	local dir = tpos - u:GetPos(); dir.z = 0
	if dir:LengthSqr() < 1 then return true end
	local want = dir:Angle().yaw + (u.MEYaw or 0)
	local cur  = u:GetAngles().yaw
	local err  = math.NormalizeAngle(want - cur)
	if u.Moving then return math.abs(err) <= VEH_FIRE_ARC end
	if math.abs(err) > 0.5 then
		local step = math.min(math.abs(err), (u.METurn or 150) * FrameTime())
		u:SetAngles(Angle(0, cur + (err > 0 and step or -step), 0))
		if (u._nextSync or 0) <= CurTime() then u._nextSync = CurTime() + 0.1; ME.NetUnitSync(u) end
	end
	return math.abs(err) <= VEH_FIRE_ARC
end

hook.Add("Think", "ME_UnitCombat", function()
	if not ME.MatchActive then return end
	local t = CurTime()
	for _, u in ipairs(ents.FindByClass("ent_me_unit")) do

		local canFight = IsValid(u) and (u.MEDmg or 0) > 0 and not IsValid(u.BuildTarget) and not u.MEStowed
			and (u.MEVehicle or not u.MoveTarget)
		if canFight then
			local myFac, pos, range = u.MEFaction or 0, u:GetPos(), u.MERange or 0
			local best, bestPr, bestd
			local rHex   = u.MERangeHex
			local uq, ur = ME.WorldToHex(pos)
			local function inHexRange(o)
				if not rHex then return true end
				local oq, orr = ME.WorldToHex(o:GetPos())
				return ME.HexDistance(uq, ur, oq, orr) <= rHex
			end

			if IsValid(u.MEForceTarget) and isEnemyEnt(myFac, u.MEForceTarget) and targetable(u.MEForceTarget, u)
			   and pos:Distance(u.MEForceTarget:GetPos()) <= range and inHexRange(u.MEForceTarget) then
				best = u.MEForceTarget
			else
				for _, o in ipairs(ents.FindInSphere(pos, range)) do
					if targetable(o, u) and isEnemyEnt(myFac, o) and inHexRange(o) then
						local pr = targetPriority(o)
						local d  = pos:DistToSqr(o:GetPos())
						if not best or pr < bestPr or (pr == bestPr and d < bestd) then best, bestPr, bestd = o, pr, d end
					end
				end
			end
			if IsValid(best) then
				u.MECombatTarget = best

				local aimed = not u.MEVehicle or aimVehicle(u, best:GetPos())
				if aimed and (u._nextFire or 0) <= t then
					u._nextFire = t + (u.MEReload or 1)
					if u.MEArtillery then
						ME.FireArtillery(u, best:GetPos())
					else
						local sp = u.MESplash
						ME.NetFire(u, best:GetPos(), sp and sp > 0, facOf(best))
						if sp and sp > 0 then

							local vic, bp, dmg = best, best:GetPos(), u.MEDmg
							timer.Simple((ME.Config and ME.Config.RocketFlight) or 0.52, function()
								if not ME.MatchActive then return end

								if IsValid(vic) then damageEnt(vic, dmg, myFac) end

								if not IsValid(u) then return end
								for _, o in ipairs(ents.FindInSphere(bp, sp)) do
									if o ~= vic and targetable(o, u) and isEnemyEnt(myFac, o) then
										local f = splashFrac(o, bp:Distance(o:GetPos()), sp)
										if f > 0 then damageEnt(o, dmg * f, myFac) end
									end
								end
							end)
						else
							damageEnt(best, u.MEDmg, myFac)
						end
					end
				end
			else
				u.MECombatTarget = nil
			end
		elseif IsValid(u) then
			u.MECombatTarget = nil
		end
	end
end)

function ME.SpawnUnit(kind, faction, pos)
	local ent = ents.Create("ent_me_unit")
	if not IsValid(ent) then return end
	ent:SetUnit(kind, faction)

	pos = ME.SpawnSpot(pos, ent.MEDomain)
	local sc = ent.MEScale or 1
	ent:SetPos(Vector(pos.x, pos.y, surfaceZ(pos)))
	ent:Spawn()
	if sc ~= 1 then ent:SetModelScale(sc, 0) end
	ME.NetUnitSync(ent)
	if ent.MECarrier then ent.MECargo = {}; ME.NetCargo(ent) end
	return ent
end

local REPAIR_TICK   = 0.4
local REPAIR_RATE   = 35

local REPAIR_REACH  = ((ME.Config and ME.Config.HexSize) or 96) * 1.5
local REPAIR_SCAN   = ((ME.Config and ME.Config.HexSize) or 96) * 9

local function bMax(b) local cfg = ME.GetBuilding and ME.GetBuilding(b.MEBID); return (cfg and cfg.health) or 500 end
local function bDamaged(b) return IsValid(b) and b.MEBuilt and (b.HP or bMax(b)) < bMax(b) end

local function canRepair(u, b)
	if ME.IsEdgeBuilding and ME.IsEdgeBuilding(b.MEBID) then return false end
	return ME.CanBuildAs and ME.CanBuildAs(u.MEKind, b.MEBID) or false
end
local REPAIR_KINDS = { builder = true, builderboat = true }
local function pushBuildHP(b)
	b:SetNWInt("MEHP", math.max(0, math.floor(b.HP)))
	if (b._hpNet or 0) <= CurTime() then
		b._hpNet = CurTime() + 0.15
		net.Start("ME_BuildingHP"); net.WriteUInt(b:EntIndex(), 16); net.WriteInt(math.max(0, math.floor(b.HP)), 32); net.Broadcast()
	end
end

timer.Create("ME_AutoRepair", REPAIR_TICK, 0, function()
	if not ME.MatchActive then return end
	for _, u in ipairs(ents.FindByClass("ent_me_unit")) do
		if IsValid(u) and REPAIR_KINDS[u.MEKind] and not u.MEStowed and not IsValid(u.BuildTarget) then
			local rt = u.MERepairTarget

			if IsValid(rt) and (not bDamaged(rt) or ME.EntFaction(rt) ~= (u.MEFaction or 0) or not canRepair(u, rt)) then
				u.MERepairTarget, rt = nil, nil
			end

			if IsValid(rt) then
				if u:GetPos():Distance(rt:GetPos()) <= REPAIR_REACH then
					rt.HP = math.min(bMax(rt), (rt.HP or bMax(rt)) + REPAIR_RATE * REPAIR_TICK)
					pushBuildHP(rt)
					u.Moving, u.Path, u.MoveTarget = false, nil, nil
					local d = rt:GetPos() - u:GetPos(); d.z = 0
					if d:LengthSqr() > 1 then u:SetAngles(Angle(0, d:Angle().yaw + (u.MEYaw or 0), 0)) end
					ME.NetUnitSync(u)
				elseif not u.Moving then
					u:OrderMove(rt:GetPos())
					u.MERepairTarget = rt
					if u.MEBlocked then u.MERepairTarget = nil end
				end
			elseif not u.Moving then

				local best, bestd
				for _, b in ipairs(ents.FindInSphere(u:GetPos(), REPAIR_SCAN)) do
					if b:GetClass() == "ent_me_building" and (b.MEFaction or 0) == (u.MEFaction or 0)
					   and bDamaged(b) and canRepair(u, b) then
						local dd = u:GetPos():DistToSqr(b:GetPos())
						if not bestd or dd < bestd then best, bestd = b, dd end
					end
				end
				if IsValid(best) then
					u:OrderMove(best:GetPos())
					u.MERepairTarget = best
					if u.MEBlocked then u.MERepairTarget = nil end
				end
			end
		end
	end
end)

local MINE_DMG    = { at_mine = 2200, naval_mine = 2200 }
local MINE_RADIUS = ((ME.Config and ME.Config.HexSize) or 96) * 1.4

function ME.NetMineBlast(pos)
	if util.NetworkStringToID("ME_MineBlast") == 0 then return end
	net.Start("ME_MineBlast"); net.WriteVector(pos); net.Broadcast()
end

function ME.DetonateMine(m)
	if not (IsValid(m) and not m._detonated) then return end
	m._detonated = true
	local pos, mfac = m:GetPos(), m.MEFaction or 0
	local dmg = MINE_DMG[m.MEBID] or 2000
	for _, o in ipairs(ents.FindInSphere(pos, MINE_RADIUS)) do
		if IsValid(o) and isEnemyEnt(mfac, o) then
			local c = o:GetClass()
			if c == "ent_me_unit" or (c == "ent_me_building" and o.MEBuilt) or c == "ent_me_core" then
				damageEnt(o, dmg, mfac)
			end
		end
	end
	ME.NetMineBlast(pos)
	m._destroyed = true; m:Remove()
end

local MINE_REVEAL = ((ME.Config and ME.Config.HexSize) or 96) * 2.1
timer.Create("ME_MineReveal", 0.3, 0, function()
	if not ME.MatchActive then return end
	for _, m in ipairs(ents.FindByClass("ent_me_building")) do
		if IsValid(m) and m.MEBuilt and m.MEBID == "naval_mine" and not m._detonated then
			local mfac, seen, changed = m.MEFaction or 0, {}, false
			for _, u in ipairs(ents.FindInSphere(m:GetPos(), MINE_REVEAL)) do
				if IsValid(u) and u:GetClass() == "ent_me_unit" and u.MEDomain == "sea" and isEnemyEnt(mfac, u) then
					seen[u.MEFaction or 0] = true
				end
			end
			local prev = m.MEMineSeen or {}
			for f in pairs(seen) do if not prev[f] then changed = true end end
			for f in pairs(prev) do if not seen[f] then changed = true end end
			if changed then
				m.MEMineSeen = seen
				ME.NetBuilding(m)
			end
		end
	end
end)

local SPOT_TILES = 1
timer.Create("ME_Conceal", 0.25, 0, function()
	if not ME.MatchActive then return end
	local cover = ME.GrassCover
	local all   = ents.FindByClass("ent_me_unit")
	local hexOf = {}
	for _, u in ipairs(all) do
		if IsValid(u) and not u.MEStowed then
			local q, r = ME.WorldToHex(u:GetPos())
			hexOf[u] = { q, r }
		end
	end
	for _, u in ipairs(all) do
		local h = hexOf[u]
		u.MEHidden = (h and cover and cover[ME.HexKey(h[1], h[2])]) or false

		if u.MEHidden then
			local seen
			for _, o in ipairs(all) do
				local oh = hexOf[o]
				if oh and o ~= u and (o.MEFaction or 0) ~= (u.MEFaction or 0)
				   and ME.HexDistance(h[1], h[2], oh[1], oh[2]) <= SPOT_TILES then
					seen = seen or {}
					seen[o.MEFaction or 0] = true
				end
			end
			u.MESpotters = seen
		else
			u.MESpotters = nil
		end
		if IsValid(u) then ME.RefreshConceal(u) end
	end
end)

local MINE_TRIGGER = ((ME.Config and ME.Config.HexSize) or 96) * 0.72
timer.Create("ME_MineTick", 0.15, 0, function()
	if not ME.MatchActive then return end
	for _, m in ipairs(ents.FindByClass("ent_me_building")) do
		if IsValid(m) and m.MEBuilt and MINE_BIDS[m.MEBID] and not m._detonated then
			local mfac = m.MEFaction or 0
			for _, u in ipairs(ents.FindInSphere(m:GetPos(), MINE_TRIGGER)) do
				if IsValid(u) and u:GetClass() == "ent_me_unit" and u.MEVehicle and isEnemyEnt(mfac, u) then
					ME.DetonateMine(m)
					break
				end
			end
		end
	end
end)
