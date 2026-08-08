
local M = "models/merge_empires/"
table.Add(ME.Buildings, {
	{ id = "house",    cat = "civilian", name = "House",    model = M .. "house_dl.mdl", price = 4000, max = 6, health = 800,  build = 20, fitMul = 0.74, desc = "A building which increases population capacity." },

	{ id = "hospital", cat = "civilian", name = "Hospital", model = M .. "hospital.mdl", price = 4000, max = 2, health = 1000, build = 25, fitMul = 0.85,

	  rangeHex = 2, healAmount = 50, healInterval = 0.5, desc = "A building which heals nearby units and produces the medic." },
})
