
local M = "models/merge_empires/"
table.Add(ME.Buildings, {
	{ id = "training", cat = "produce", name = "Training Camp",   model = M .. "tent_soldat.mdl",      price = 2500, max = 5, health = 900,  build = 22, desc = "A building which produces troops." },
	{ id = "harbor",   cat = "produce", name = "Harbor",          model = M .. "port.mdl",             price = 3500, max = 3, health = 1200, build = 26, desc = "A building which produces and heals ships." },
	{ id = "factory",  cat = "produce", name = "Vehicle Factory", model = M .. "vehicule_factory.mdl", price = 7600, max = 4, health = 1500, build = 30, fitMul = 0.7, desc = "A building which produces land vehicles." },
})
