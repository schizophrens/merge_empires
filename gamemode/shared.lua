GM.Name    = "Merge Empires"
GM.Author  = "Merge Empires contributors"
GM.Email   = ""
GM.Website = ""

ME = ME or {}

include("config/arena.lua")
include("config/modes.lua")
include("shared/maplock.lua")
include("shared/hexgrid.lua")
include("shared/grass.lua")

ME.BIOME_ID   = { water = 0, sand = 1, grass = 2, rock = 3, hill = 4 }
ME.BIOME_NAME = { [0] = "water", [1] = "sand", [2] = "grass", [3] = "rock", [4] = "hill" }
ME.DECOR_ID   = { none = 0, tree = 1, rock = 2, gold = 3, mountain = 4, palm = 5, slot = 6, oilspot = 7 }
ME.DECOR_NAME = { [0] = "none", [1] = "tree", [2] = "rock", [3] = "gold", [4] = "mountain", [5] = "palm", [6] = "slot", [7] = "oilspot" }

ME.BeamColors = {
	[1] = Color(252,  66,  66),
	[2] = Color( 47, 125, 255),
	[3] = Color( 59, 154,  52),
	[4] = Color(250, 233,   0),
	[5] = Color(166,  77, 255),
	[6] = Color(252, 126,   0),
}

ME.TEAM_SPECTATOR = 100

ME.Factions = {
	{ id = 1, name = "Red",    color = Color(220,  70,  60), core = "models/merge_empires/core_rouge.mdl"  },
	{ id = 2, name = "Blue",   color = Color( 60, 130, 230), core = "models/merge_empires/core_bleu.mdl"   },
	{ id = 3, name = "Green",  color = Color( 70, 200, 110), core = "models/merge_empires/core_vert.mdl"   },
	{ id = 4, name = "Yellow", color = Color(235, 200,  60), core = "models/merge_empires/core_jaune.mdl"  },
	{ id = 5, name = "Violet", color = Color(170,  90, 220), core = "models/merge_empires/core_violet.mdl" },
	{ id = 6, name = "Orange", color = Color(235, 140,  50), core = "models/merge_empires/core_orange.mdl" },
}

function ME.GetFaction(id)
	for _, f in ipairs(ME.Factions) do
		if f.id == id then return f end
	end
end

function ME.FactionColor(id)
	local f = ME.GetFaction(id)
	return f and f.color or Color(200, 200, 200)
end

function ME.SetupTeams()
	for i = 1, ME.Config.MaxFactions do
		local f = ME.Factions[i]
		if f then team.SetUp(f.id, f.name, f.color) end
	end
	team.SetUp(ME.TEAM_SPECTATOR, "Spectator", Color(150, 150, 150))
	team.SetSpawnPoint(ME.TEAM_SPECTATOR, {})
end

function GM:Initialize()
	ME.SetupTeams()
	if self.BaseClass and self.BaseClass.Initialize then
		self.BaseClass.Initialize(self)
	end
end

function ME.IsUnit(ent)
	return IsValid(ent) and ent.MEUnit == true
end

function ME.EntFaction(ent)
	if not IsValid(ent) then return 0 end
	if ent.GetFaction then return ent:GetFaction() end
	return ent.MEFaction or 0
end

function ME.AreAllied(a, b)
	if not a or not b or a == 0 or b == 0 or a == b then return false end
	if SERVER then
		return ME.Ally ~= nil and ME.Ally[a] == b
	else
		local e = ME.RosterData and ME.RosterData[a]
		return e ~= nil and e.ally == b
	end
end

ME.PFX = {
	fire_big   = "[1]_large_campfire",
	fire       = "[1]campfire1",
	groundfire = "[1]groundflame1",
	smoke      = "[1]big_smoke",
	smoke_soft = "[1]smoke_lifting_01",
}

if not ME._ParticlesLoaded then
	ME._ParticlesLoaded = true
	game.AddParticles("particles/pfx_redux.pcf")
	for _, sys in pairs(ME.PFX) do PrecacheParticleSystem(sys) end
end

