
local M = "models/merge_empires/"
table.Add(ME.Buildings, {
	{ id = "at_mine",    cat = "defense", name = "Anti-Tank Mine",  model = M .. "mine.mdl",         price = 700,   max = 10,  health = 200,  build = 8,  fitMul = 0.85, desc = "A defense that explodes when vehicles get within range." },
	{ id = "naval_mine", cat = "defense", name = "Naval Mine",      model = M .. "mine_naval.mdl",   price = 800,   max = 10,  health = 200,  build = 8,  fitMul = 0.85, desc = "A defense that explode when boats get within range." },
	{ id = "wall",       cat = "defense", name = "Wall",            model = M .. "mur_brique.mdl",   price = 900,   max = 100, health = 1000, build = 10, fitMul = 0.5, desc = "A structure used to define an area and protect a settlement." },
	{ id = "gate",       cat = "defense", name = "Gate",            model = M .. "mur_porte.mdl",    price = 1000,  max = 10,  health = 800,  build = 12, fitMul = 0.6, desc = "A structure used to define an area and protect a settlement." },

	{ id = "turret",     cat = "defense", name = "Turret",          model = M .. "tourelle.mdl",     price = 3500,  max = 16,  health = 700,  build = 20, fitMul = 0.58, center = true,
	  rangeHex = 4, dmg = 45, reload = 0.6, desc = "A defense that fires single rounds at enemies quickly." },

	{ id = "missile",    cat = "defense", name = "Missile Defense", model = M .. "anti_missile.mdl", price = 16000, max = 5,   health = 900,  build = 30,
	  rangeHex = 4, reload = 10, desc = "A defense that intercepts incoming missiles." },
})
