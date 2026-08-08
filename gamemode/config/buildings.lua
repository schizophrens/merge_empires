ME = ME or {}

ME.BuildCategories = {
	{ id = "income",   label = "INCOME",   color = Color(96, 184, 58)  },
	{ id = "civilian", label = "CIVILIAN", color = Color(178, 138, 78) },
	{ id = "produce",  label = "PRODUCE",  color = Color(92, 126, 208) },
	{ id = "defense",  label = "DEFENSE",  color = Color(170, 200, 142) },
}

ME.Buildings = {}
for _, catf in ipairs({ "income", "civilian", "produce", "defense" }) do
	local path = "buildings/" .. catf .. ".lua"
	if SERVER then AddCSLuaFile(path) end
	include(path)
end

function ME.BuildPlaceRule(b)
	local id = istable(b) and b.id or b
	if id == "farm" or id == "oil_pump" then return "slot" end
	if id == "gold_mine" then return "gold" end
	if id == "oil_rig" then return "oilspot" end
	if id == "harbor" or id == "naval_mine" then return "water" end
	return "land"
end

ME.EDGE_BUILDINGS = { wall = true, gate = true }
function ME.IsEdgeBuilding(id)
	return ME.EDGE_BUILDINGS[istable(id) and id.id or id] == true
end

function ME.EdgePlacement(q, r, idx, z)
	z = z or 0
	local c   = ME.HexToWorld(q, r, z)
	local d   = ME.FaceDirs[idx % 6]
	local nb  = ME.HexToWorld(q + d[1], r + d[2], z)
	local mid = (c + nb) * 0.5
	local dir = nb - c; dir.z = 0
	local yaw = (dir:LengthSqr() > 1 and dir:Angle().yaw or 0) + ((ME.Config and ME.Config.WallEdgeYaw) or 90)
	return mid, yaw
end

ME.BOAT_ONLY = { naval_mine = true, oil_rig = true }
function ME.BuilderCanBuild(id)
	return not ME.BOAT_ONLY[istable(id) and id.id or id]
end
function ME.BoatBuilderCanBuild(id)
	return ME.BOAT_ONLY[istable(id) and id.id or id] == true
end

function ME.CanBuildAs(kind, id)
	if kind == "builderboat" then return ME.BoatBuilderCanBuild(id) end
	if kind == "builder"     then return ME.BuilderCanBuild(id) end
	return false
end

function ME.GetBuilding(id)
	for _, b in ipairs(ME.Buildings) do if b.id == id then return b end end
end

function ME.BuildingsInCategory(cat)
	local t = {}
	for _, b in ipairs(ME.Buildings) do if b.cat == cat then t[#t + 1] = b end end
	return t
end
