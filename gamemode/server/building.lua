
util.AddNetworkString("ME_PlaceBuilding")
util.AddNetworkString("ME_BuildingSync")
util.AddNetworkString("ME_BuildingRemove")
util.AddNetworkString("ME_BuildingReq")
util.AddNetworkString("ME_PurchaseSfx")
util.AddNetworkString("ME_BuildingSfx")
util.AddNetworkString("ME_DestroyBuilding")
util.AddNetworkString("ME_PlaceDenied")
util.AddNetworkString("ME_BuildingHP")

local BLOCK_DECOR = { mountain = true, tree = true, palm = true, rock = true, bush = true }

local function denyPlace(ply, reason)
	net.Start("ME_PlaceDenied")
	net.WriteString(reason or "")
	net.Send(ply)
end

function ME.NetBuildingSfx(kind, pos)
	net.Start("ME_BuildingSfx")
	net.WriteUInt(kind, 2)
	net.WriteVector(pos)
	net.Broadcast()
end

for _, b in ipairs(ME.Buildings or {}) do
	if b.model then util.PrecacheModel(b.model) end
end

local MINE_HIDDEN = { at_mine = true, naval_mine = true }
local function mineOwnerOnly(ent, ply)
	if not (ent.MEBuilt and MINE_HIDDEN[ent.MEBID or ""]) then return true end
	local t = ply:Team()

	if ent.MEMineSeen and ent.MEMineSeen[t] then return true end
	return t == (ent.MEFaction or 0) or (ME.AreAllied and ME.AreAllied(t, ent.MEFaction or 0))
end

function ME.NetBuilding(ent, target)
	if not IsValid(ent) then return end
	local players = IsValid(target) and { target } or player.GetAll()
	local show, hide = {}, {}
	for _, ply in ipairs(players) do
		if IsValid(ply) then
			if mineOwnerOnly(ent, ply) then show[#show + 1] = ply else hide[#hide + 1] = ply end
		end
	end
	if #show > 0 then
		net.Start("ME_BuildingSync")
		net.WriteUInt(ent:EntIndex(), 16)
		net.WriteString(ent.MEBID or ent:GetBID() or "")
		net.WriteString(ent:GetModel() or "")
		net.WriteVector(ent:GetPos())
		net.WriteAngle(ent:GetAngles())
		net.WriteBool(ent.MEBuilt and true or false)
		net.WriteInt(ent.MEFaction or 0, 8)
		net.WriteFloat(ent.MEProgress or 0)
		net.WriteBool(ent.MEBuilderNear and true or false)
		net.Send(show)
	end
	if #hide > 0 then
		net.Start("ME_BuildingRemove")
		net.WriteUInt(ent:EntIndex(), 16)
		net.WriteBool(false)
		net.WriteVector(ent:GetPos())
		net.Send(hide)
	end
end

function ME.NetBuildingRemove(idx, pos, destroyed)
	net.Start("ME_BuildingRemove")
	net.WriteUInt(idx, 16)
	net.WriteBool(destroyed and true or false)
	net.WriteVector(pos or vector_origin)
	net.Broadcast()
end

net.Receive("ME_BuildingReq", function(_, ply)
	if ME.Throttle(ply, "buildreq", 3) then return end

	for _, e in ipairs(ents.FindByClass("ent_me_building")) do
		ME.NetBuilding(e, ply)
	end
end)

net.Receive("ME_DestroyBuilding", function(_, ply)
	if ME.Throttle(ply, "destroy", 0.2) then return end

	local ent = Entity(net.ReadUInt(16))
	if not IsValid(ent) or ent:GetClass() ~= "ent_me_building" then return end
	if ent._destroyed then return end
	if (ent.MEFaction or 0) ~= ME.PlayingFaction(ply) then return end

	ent._destroyed = true

	if not ent.MEBuilt then
		local b = ME.GetBuilding and ME.GetBuilding(ent.MEBID)
		if b and ME.AddMoney then ME.AddMoney(ply, b.price or 0) end
	end

	ent:Remove()
end)

local function cellAt(q, r)
	return ME.Board and ME.Board.cells and ME.Board.cells[ME.HexKey(q, r)]
end

local function tierAt(q, r)
	local c    = cellAt(q, r)
	local step = (ME.Config and ME.Config.TierStep) or 20
	local Hg   = (ME.Config and ME.Config.Heights and ME.Config.Heights.grass) or 0
	return math.Round(((ME.SurfaceOffset(q, r, c and c.biome or "grass") or 0) - Hg) / step)
end

local function isSand(q, r) local c = cellAt(q, r); return c and c.biome == "sand" end

function ME.HarborShoreOK(q, r)
	for _, d in ipairs(ME.HexDirs) do if isSand(q + d[1], r + d[2]) then return true end end
	return false
end

function ME.HarborRotOK(q, r, rotIdx)
	local nq, nr = ME.FaceNeighbor(q, r, rotIdx + 3)
	return isSand(nq, nr)
end

function ME.TileAllows(rule, cell)
	if not cell then return false end
	if rule == "slot"    then return cell.decor == "slot" end
	if rule == "gold"    then return cell.decor == "gold" end
	if rule == "oilspot" then return cell.decor == "oilspot" end
	if rule == "water"   then return cell.biome == "water" end
	return cell.biome ~= "water" and cell.decor ~= "mountain" and cell.decor ~= "slot" and cell.decor ~= "gold"
end

local function hexWorld(q, r, cell)
	local z = (ME.Board.baseZ or 0) + (ME.SurfaceOffset(q, r, cell and cell.biome or "grass") or 0)
	return ME.HexToWorld(q, r, z)
end

local function hexOccupied(q, r, fac)
	for _, e in ipairs(ents.FindByClass("ent_me_building")) do
		if not ME.IsEdgeBuilding(e.MEBID) then
			local mine = ME.IsMineBuilding and ME.IsMineBuilding(e)
			local ours = (e.MEFaction or 0) == fac or (ME.AreAllied and ME.AreAllied(fac, e.MEFaction or 0))
			if not (mine and not ours) then
				local eq, er = ME.WorldToHex(e:GetPos())
				if eq == q and er == r then return true end
			end
		end
	end
	for _, e in ipairs(ents.FindByClass("ent_me_core")) do
		local eq, er = ME.WorldToHex(e:GetPos())
		if eq == q and er == r then return true end
	end
	return false
end

local function edgeWalled(q, r, idx)
	local nq, nr = ME.FaceNeighbor(q, r, idx)
	for _, e in ipairs(ents.FindByClass("ent_me_building")) do
		local ed = IsValid(e) and e.MEEdge
		if ed then
			if (ed.q == q  and ed.r == r  and ed.side % 6 == idx % 6)
			or (ed.q == nq and ed.r == nr and ed.side % 6 == (idx + 3) % 6) then return true end
		end
	end
	return false
end

local function harborDockEdge(q, r, idx)
	local nq, nr = ME.FaceNeighbor(q, r, idx)
	for _, e in ipairs(ents.FindByClass("ent_me_building")) do
		local d = IsValid(e) and e.MEDock
		if d then
			if (d.q == q  and d.r == r  and d.side % 6 == idx % 6)
			or (d.q == nq and d.r == nr and d.side % 6 == (idx + 3) % 6) then return true end
		end
	end
	return false
end

local function edgeOccupied(pos)
	local r2 = ((ME.Config.HexSize or 96) * 0.4) ^ 2
	for _, e in ipairs(ents.FindByClass("ent_me_building")) do
		if ME.IsEdgeBuilding(e.MEBID) and e:GetPos():DistToSqr(pos) < r2 then return true end
	end
	return false
end

net.Receive("ME_PlaceBuilding", function(_, ply)
	if not (IsValid(ply) and ME.MatchActive) then return end
	local t = ply:Team()
	if t == ME.TEAM_SPECTATOR or t < 1 or t > ME.Config.MaxFactions then return end

	local id     = net.ReadString()
	local q      = net.ReadInt(16)
	local r      = net.ReadInt(16)
	local rotIdx = net.ReadUInt(3) % 6

	if ME.Throttle(ply, "place", 0.15) then return end

	local b = ME.GetBuilding and ME.GetBuilding(id)
	if not b then return end

	local cell = cellAt(q, r)
	if not ME.TileAllows(ME.BuildPlaceRule(b), cell) then denyPlace(ply, "tile") return end
	if cell and BLOCK_DECOR[cell.decor] then denyPlace(ply, "tile") return end
	if not ME.CanAfford(ply, b.price or 0) then denyPlace(ply, "money") return end

	if id == "harbor" then
		if not ME.HarborShoreOK(q, r) then denyPlace(ply, "shore") return end
		if not ME.HarborRotOK(q, r, rotIdx) then denyPlace(ply, "harbor_rot") return end

		if edgeWalled(q, r, rotIdx + 3) then denyPlace(ply, "harbor_walled") return end
	end

	local pos, ang
	local edgeSide
	if ME.IsEdgeBuilding(id) then

		local nq, nr = ME.FaceNeighbor(q, r, rotIdx)
		if tierAt(nq, nr) > tierAt(q, r) then denyPlace(ply, "relief") return end
		local z = hexWorld(q, r, cell).z
		local mid, yaw = ME.EdgePlacement(q, r, rotIdx, z)
		pos, ang, edgeSide = mid, Angle(0, yaw, 0), rotIdx
		if edgeOccupied(pos) then denyPlace(ply, "occupied") return end
		if harborDockEdge(q, r, rotIdx) then denyPlace(ply, "harbor_dock") return end
	else
		pos = hexWorld(q, r, cell)
		ang = Angle(0, rotIdx * 60, 0)
		if id == "harbor" then
			local nq, nr = ME.FaceNeighbor(q, r, rotIdx + 3)
			local dir = ME.HexToWorld(nq, nr, pos.z) - pos; dir.z = 0
			if dir:LengthSqr() > 1 then dir:Normalize(); pos = pos + dir * ((ME.Config.HexSize or 96) * 0.45) end
		end
		if hexOccupied(q, r, t) then denyPlace(ply, "occupied") return end
	end

	local effMax = (ME.BuildingMaxFor and ME.BuildingMaxFor(t, id)) or (b.max or 0)
	if effMax > 0 and (ME.BuildingCounts(t)[id] or 0) >= effMax then denyPlace(ply, "max") return end

	ME.TakeMoney(ply, b.price or 0)
	local ent = ents.Create("ent_me_building")
	if not IsValid(ent) then return end
	ent:SetBuilding(id, t)
	ent:SetPos(pos)
	ent:SetAngles(ang)
	if edgeSide then ent.MEEdge = { q = q, r = r, side = edgeSide } end

	if id == "harbor" then ent.MEDock = { q = q, r = r, side = (rotIdx + 3) % 6 } end
	ent:Spawn()

	ent:SetNWFloat("MEProgress", 0)

	ME.NetBuilding(ent)
	ME.NetBuildingSfx(1, pos)
	net.Start("ME_PurchaseSfx"); net.Send(ply)
	if ME.RepathNear then ME.RepathNear(pos, 6) end
end)

