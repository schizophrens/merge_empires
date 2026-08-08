ME = ME or {}

ME.Skins = {
	{ id = "gunner_blue",      item = "u_gunner",     name = "Gunner Marine",   price = 175, unit = true,
	  model = "models/tt_soldiers/skin_gunner_blue.mdl",       weapon = "models/tt_soldiers/weapons/w_m4a1.mdl" },
	{ id = "shotgunner_blue",  item = "u_shotgunner", name = "Shotgunner Marine",  price = 150, unit = true,
	  model = "models/tt_soldiers/skin_shotgunner_blue.mdl",   weapon = "models/tt_soldiers/weapons/w_shotgun.mdl" },
	{ id = "sniper_blue",      item = "u_sniper",     name = "Sniper Marine",    price = 220, unit = true,
	  model = "models/tt_soldiers/skin_sniper_blue.mdl",       weapon = "models/tt_soldiers/weapons/w_awp.mdl" },
	{ id = "rocketeer_militia", item = "u_rocketeer", name = "Terrorist",         price = 300, unit = true,
	  model = "models/tt_soldiers/skin_rocketeer_militia.mdl", weapon = "models/tt_soldiers/weapons/w_rpg.mdl" },
}

function ME.GetSkin(id)
	for _, s in ipairs(ME.Skins) do if s.id == id then return s end end
end

function ME.SkinnableItems()
	local set = {}
	for _, s in ipairs(ME.Skins) do set[s.item] = true end
	return set
end

if SERVER then
	for _, s in ipairs(ME.Skins) do if s.model then util.PrecacheModel(s.model) end end
end
