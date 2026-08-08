
local M = "models/merge_empires/"
table.Add(ME.Buildings, {
	{ id = "farm",      cat = "income", name = "Farm",      model = M .. "farm.mdl",         price = 800,   max = 0, income = 700,  health = 500,  build = 18, desc = "Generates coins by producing crops." },
	{ id = "oil_pump",  cat = "income", name = "Oil Pump",  model = M .. "oil_platform.mdl", price = 2800,  max = 0, income = 2300, health = 700,  build = 20, fitMul = 0.85, desc = "A building that produces coins." },
	{ id = "gold_mine", cat = "income", name = "Gold Mine", model = M .. "gold_farm.mdl",    price = 4500,  max = 0, income = 4800, health = 900,  build = 28, desc = "A building used for mining ores to generate coins." },
	{ id = "oil_rig",   cat = "income", name = "Oil Rig",   model = M .. "oilrig.mdl",       price = 12000, max = 0, income = 8000, health = 1000, build = 33, desc = "A water structure used for extracting oil to generate coins." },
})
