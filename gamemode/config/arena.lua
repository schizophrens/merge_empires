ME = ME or {}
ME.Config = {
	OfficialMap    = "me_map",
	MaxFactions    = 6,
	StartMoney     = 1000,
	StartCountdown = 30,
	UnitMax        = 10,

	IncomeInterval = 3,
	BaseIncome     = 60,
	IncomePerFarm  = 15,
	UnitCap        = 40,

	CoreHealth     = 5200,
	MapName        = "Breaktide",

	Costs = {
		farm    = 150,
		camp    = 250,
		turret  = 200,
		soldier = 75,
	},

	ArenaCenter    = Vector(0, 0, 0),
	SpawnRing      = 3000,
	ResourceNodes  = 12,
	ResourceRingMin= 900,
	ResourceRingMax= 2400,
	Obstacles      = 26,
	ObstacleRing   = 2600,
	MinNodeSpacing = 450,
	GroundTraceUp  = 1200,
	GroundTraceDown= 6000,

	Models = {
		tree = {
			"models/merge_empires/pine_forest.mdl",
			"models/merge_empires/pine_forest_tall.mdl",
		},
		palm     = { "models/merge_empires/palm_group.mdl" },
		mountain = { "models/merge_empires/mountain_hex.mdl" },
	},
	DecorScale = 1,
	CoreScale  = 0.9,
	CoreYaw    = 0,
	WallEdgeYaw = 90,
	ModelScale = {
		["models/merge_empires/palm_group.mdl"] = 0.5,
	},
	PalmSink = 14,

	Buildings = {
		camp        = "models/merge_empires/tent_soldat.mdl",
		factory     = "models/merge_empires/vehicule_factory.mdl",
		turret      = "models/merge_empires/tourelle.mdl",
		antimissile = "models/merge_empires/anti_missile.mdl",
		hospital    = "models/merge_empires/hospital.mdl",
		mine        = "models/merge_empires/mine.mdl",
		navalmine   = "models/merge_empires/mine_naval.mdl",
		oilrig      = "models/merge_empires/oilrig.mdl",
		oilplatform = "models/merge_empires/oil_platform.mdl",
		farm        = "models/merge_empires/farm.mdl",
		wall        = "models/merge_empires/mur_brique.mdl",
		gate        = "models/merge_empires/mur_porte.mdl",
		port        = "models/merge_empires/port.mdl",
	},

	RocketFlight = 0.52,
	ArtFlight    = 1.1,

	HexSize     = 96,
	BoardRadius  = 52,
	IslandRadius = 7,
	Preset          = "Breaktide",
	CoreClearRadius = 4,
	BeachWidth      = 26,
	BeachMax        = 22,
	BeachMaxNeutral = 14,

	Colors = {
		grass    = Color(124, 182,  64),
		sand     = Color(240, 202, 122),
		water    = Color( 40, 112, 178),
		rockSide = Color(112, 116, 124),
		dirt     = Color(126,  88,  54),
		sandSide = Color(200, 162, 100),
		darkRock = Color( 74,  78,  86),
		gold     = Color(255, 205,  40),
		shadow   = Color( 48,  54,  46),
	},

	Light = {
		SunDir   = Vector(-0.7, -0.45, 0.40),
		SunColor = Vector(1.02, 0.82, 0.50),
		Ambient  = Vector(0.50, 0.54, 0.66),
	},

	Heights = {
		water = -24,
		sand  =   0,
		grass =   0,
	},
	CliffDepth  = 28,

	WaveAmplitude  = 0,
	WaveSpeed      = 1.0,

	LandGradient   = 4,

	TerrainTiers      = 4,
	TierStep          = 10,
	CentralReliefBias = 0.6,

	CamPanMargin   = 1.5,
}

ME.Presets = ME.Presets or {}
ME.Presets.Breaktide = {
	centralIsland  = true,
	centralScale   = 1.8,
	centralBeaches = { 90, 270 },
	goldSpots      = { { 4, -1 }, { -4, 1 }, { 1, 4 } },
	centralRockRadius = 2,
	smallIslands   = 3,
}
