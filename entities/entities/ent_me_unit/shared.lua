ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Unit"
ENT.Spawnable = false
ENT.Category  = "Merge Empires"
ENT.MEUnit    = true

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Faction")
	self:NetworkVar("Int", 1, "HP")
	self:NetworkVar("Int", 2, "MaxHP")
	self:NetworkVar("String", 0, "UKind")
end

ME = ME or {}

ME.HexSpacing = ((ME and ME.Config and ME.Config.HexSize) or 96) * math.sqrt(3)
function ME.HexRange(tiles) return math.floor(tiles * ME.HexSpacing + 0.5) end

ME.UnitSpeedScale = 0.55

ME.UnitKinds = {
	builder = {
		name   = "Builder",
		desc   = "A civilian that constructs and repairs buildings.",
		model  = "models/tt_soldiers/green_builder.mdl",
		hp     = 120,
		speed  = 230,
		cost   = 200,
		pop    = 1,
		build  = 6,
		scale  = 0.7,
		yaw    = -90,
		radius = 20,
	},

	gunner = {
		name = "Gunner", desc = "A soldier that lays down rapid rifle fire.",
		model = "models/tt_soldiers/green_support.mdl", weapon = "models/tt_soldiers/weapons/w_m4a1.mdl", animset = "weapon",
		hp = 160, speed = 210, cost = 700, pop = 1, build = 9, scale = 0.7, yaw = -90, radius = 20,
		dmg = 16, rangeHex = 2, range = ME.HexRange(2), reload = 0.5,
	},
	shotgunner = {
		name = "Shotgunner", desc = "A soldier that hits hard at close range.",
		model = "models/tt_soldiers/green_soldier.mdl", weapon = "models/tt_soldiers/weapons/w_shotgun.mdl", animset = "weapon",
		hp = 200, speed = 205, cost = 950, pop = 1, build = 11, scale = 0.7, yaw = -90, radius = 20,
		dmg = 42, rangeHex = 1, range = ME.HexRange(1), reload = 1.1,
	},
	sniper = {
		name = "Sniper", desc = "A soldier that picks off targets from afar.",
		model = "models/tt_soldiers/green_sniper.mdl", weapon = "models/tt_soldiers/weapons/w_awp.mdl", animset = "weapon",
		hp = 120, speed = 200, cost = 1200, pop = 1, build = 13, scale = 0.7, yaw = -90, radius = 20,
		dmg = 85, rangeHex = 3, range = ME.HexRange(3), reload = 2.6,
	},
	rocketeer = {
		name = "Rocketeer", desc = "A soldier that fires explosive rockets.",
		model = "models/tt_soldiers/green_officer.mdl", weapon = "models/tt_soldiers/weapons/w_rpg.mdl", animset = "launcher",
		hp = 180, speed = 195, cost = 2500, pop = 2, build = 16, scale = 0.7, yaw = -90, radius = 20,
		dmg = 165, rangeHex = 2, range = ME.HexRange(2), reload = 3.2, splash = 190,
	},

	humvee = {
		name = "Humvee", desc = "A fast, lightly-armed scout vehicle.", vehicle = true,
		model = "models/tt_vehicles/humvee.mdl",
		hp = 320, speed = 300, cost = 1600, pop = 2, build = 12, scale = 0.62, yaw = -90, radius = 30,
		dmg = 22, rangeHex = 2, range = ME.HexRange(2), reload = 0.5, turn = 220,
	},
	apc = {
		name = "APC", desc = "An armoured carrier that soaks up a lot of damage.", vehicle = true,
		model = "models/tt_vehicles/apc.mdl",
		hp = 600, speed = 240, cost = 2400, pop = 3, build = 16, scale = 0.62, yaw = -90, radius = 32,
		dmg = 32, rangeHex = 2, range = ME.HexRange(2), reload = 0.8, turn = 170,
	},
	tank = {
		name = "Tank", desc = "A heavy tank with a devastating main gun.", vehicle = true,
		model = "models/tt_vehicles/tank.mdl",
		hp = 1100, speed = 170, cost = 4200, pop = 5, build = 24, scale = 0.62, yaw = -90, radius = 38,
		dmg = 95, rangeHex = 2, range = ME.HexRange(2), reload = 2.2, turn = 110,
	},

	missiletank = {
		name = "Missile Tank", short = "Missile", desc = "Siege artillery: lobs a salvo of missiles onto enemy structures.", vehicle = true, artillery = true,
		model = "models/tt_vehicles/missiletank.mdl",
		hp = 650, speed = 160, cost = 6000, pop = 5, build = 28, scale = 0.62, yaw = -90, radius = 36,
		dmg = 95, rangeHex = 3, range = ME.HexRange(3), reload = 5.0, splash = 200, turn = 95,
	},

	builderboat = {
		name = "Builder Boat", short = "Builder", desc = "A civilian ship that builds and repairs sea structures.",
		vehicle = true, boat = true, domain = "sea",
		model = "models/tt_sea/builder.mdl",
		hp = 200, speed = 240, cost = 400, pop = 1, build = 8, scale = 0.58, yaw = 90, radius = 30,
		turn = 200,
	},

	barge = {
		name = "Barge", desc = "A transport ship that ferries up to 6 land units across the water.",
		vehicle = true, boat = true, domain = "sea", carrier = 6, pickupHex = 2,
		model = "models/tt_sea/barge.mdl",
		bounds = { Vector(-30.1, -75, 0), Vector(30.1, 75, 35.4) },
		hp = 900, speed = 220, cost = 4100, pop = 3, build = 20, scale = 0.68, yaw = -90, radius = 40,
		turn = 130, iconZoom = 1.4,
	},

	destroyer = {
		name = "Destroyer", desc = "A heavy warship: missiles against ships and coastal structures.",
		vehicle = true, boat = true, domain = "sea", tierCap = 0,
		model = "models/tt_sea/s1.mdl",
		hp = 1500, speed = 220, cost = 6000, pop = 5, build = 26, scale = 0.80, yaw = 0, radius = 46,
		dmg = 185, rangeHex = 3, range = ME.HexRange(3), reload = 3.4, splash = 160, turn = 110,
		iconZoom = 1.4,
	},

	submarine = {
		name = "Submarine", short = "Sub", desc = "A missile submarine: hunts ships, cannot touch structures.",
		vehicle = true, boat = true, domain = "sea", unitsOnly = true, submerge = true,
		model = "models/tt_sea/submarine.mdl",
		hp = 800, speed = 230, cost = 5200, pop = 5, build = 24, scale = 0.68, yaw = 90, radius = 38,
		dmg = 400, rangeHex = 2, range = ME.HexRange(2), reload = 5.5, splash = 160, turn = 120,
		iconZoom = 1.4,
	},
}

ME.ProducedBy = {
	training = { "gunner", "shotgunner", "sniper", "rocketeer" },
	factory  = { "humvee", "apc", "tank", "missiletank" },
	harbor   = { "builderboat", "barge", "destroyer", "submarine" },
}
function ME.BuildingUnits(bid) return ME.ProducedBy[bid] end

function ME.GetUnitKind(k) return ME.UnitKinds[k] or ME.UnitKinds.builder end

function ME.UnitDomain(kind)
	local k = ME.UnitKinds[kind]
	return (k and k.domain) or "land"
end

local MODEL_FALLBACK = {
	builderboat = "models/tt_vehicles/humvee.mdl",
	barge       = "models/tt_vehicles/apc.mdl",
	destroyer   = "models/tt_vehicles/tank.mdl",
	submarine   = "models/tt_vehicles/missiletank.mdl",
}
function ME.UnitModel(kind)
	local k = ME.GetUnitKind(kind)
	local m = k.model
	if m and util.IsValidModel(m) then return m end
	local fb = MODEL_FALLBACK[kind]
	if fb and util.IsValidModel(fb) then return fb end
	return m or "models/error.mdl"
end

function ME.UnitBounds(kind, mdlEnt)
	local k = ME.UnitKinds[kind]
	if k and k.bounds then return k.bounds[1], k.bounds[2] end
	if IsValid(mdlEnt) then return mdlEnt:GetModelRenderBounds() end
	return Vector(-16, -16, 0), Vector(16, 16, 32)
end
