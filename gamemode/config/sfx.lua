ME = ME or {}

local FAR_BATTLE = 5200
local FAR_LOCAL  = 3200

ME.SfxDefs = {

	shot_rifle    = { file = "sfx/combat/shot_rifle",    variants = 1, vol = 0.42, pitch = 0.09, voices = 6, near = 900, far = FAR_BATTLE, cooldown = 0.03 },
	shot_shotgun  = { file = "sfx/combat/shot_shotgun",  variants = 1, vol = 0.50, pitch = 0.07, voices = 4, near = 900, far = FAR_BATTLE, cooldown = 0.04 },
	shot_sniper   = { file = "sfx/combat/shot_sniper",   variants = 1, vol = 0.55, pitch = 0.05, voices = 3, near = 1100, far = FAR_BATTLE, cooldown = 0.05 },
	bullet_impact = { file = "sfx/combat/bullet_impact", variants = 1, vol = 0.28, pitch = 0.12, voices = 5, near = 700, far = FAR_LOCAL,  cooldown = 0.03 },

	shot_cannon   = { file = "sfx/combat/shot_cannon",   variants = 1, vol = 0.62, pitch = 0.06, voices = 4, near = 1200, far = FAR_BATTLE, cooldown = 0.05 },
	turret_fire   = { file = "sfx/combat/turret_fire",   variants = 1, vol = 0.48, pitch = 0.08, voices = 4, near = 1000, far = FAR_BATTLE, cooldown = 0.04 },

	rocket_launch    = { file = "sfx/combat/rocket_launch",    variants = 1, vol = 0.55, pitch = 0.07, voices = 4, near = 1100, far = FAR_BATTLE, cooldown = 0.04 },
	rocket_impact    = { file = "sfx/combat/rocket_impact",    variants = 1, vol = 0.70, pitch = 0.06, voices = 4, near = 1400, far = FAR_BATTLE, cooldown = 0.06 },
	artillery_fire   = { file = "sfx/combat/artillery_fire",   variants = 1, vol = 0.60, pitch = 0.05, voices = 3, near = 1300, far = FAR_BATTLE, cooldown = 0.05 },
	artillery_impact = { file = "sfx/combat/artillery_impact", variants = 1, vol = 0.80, pitch = 0.05, voices = 3, near = 1600, far = 6400,       cooldown = 0.08 },

	interceptor_pop  = { file = "sfx/combat/interceptor_pop",  variants = 1, vol = 0.62, pitch = 0.06, voices = 3, near = 1500, far = 6000, cooldown = 0.06 },
	mine_blast       = { file = "sfx/combat/mine_blast",       variants = 1, vol = 0.75, pitch = 0.05, voices = 2, near = 1500, far = 6000, cooldown = 0.10 },

	core_beam_start = { file = "sfx/combat/core_beam_start", variants = 1, vol = 0.55, pitch = 0.03, voices = 3, near = 1400, far = 6000 },
	core_beam_loop  = { file = "sfx/combat/core_beam_loop",  variants = 1, vol = 0.45, pitch = 0.02, voices = 3, near = 1400, far = 6000, loop = true },

	unit_death    = { file = "sfx/combat/unit_death",    variants = 1, vol = 0.40, pitch = 0.10, voices = 4, near = 800,  far = FAR_LOCAL,  cooldown = 0.05 },

	build_place     = { file = "sfx/build/build_place",     variants = 1, vol = 0.45, pitch = 0.05, voices = 2, near = 900,  far = FAR_LOCAL },

	build_start     = { file = "sfx/building_construction", variants = 1, vol = 0.40, pitch = 0.04, voices = 3, near = 900,  far = FAR_LOCAL },
	build_finished  = { file = "sfx/building_finished",     variants = 1, vol = 0.45, pitch = 0.03, voices = 3, near = 1000, far = FAR_LOCAL },
	build_destroyed = { file = "sfx/building_destroyed",    variants = 1, vol = 0.55, pitch = 0.05, voices = 3, near = 1400, far = FAR_BATTLE, cooldown = 0.08 },
	build_sold      = { file = "sfx/build/build_sold",      variants = 1, vol = 0.45, pitch = 0.04, voices = 2, near = 900,  far = FAR_LOCAL },
	build_denied    = { file = "sfx/build/build_denied",    variants = 1, vol = 0.55, pitch = 0,    voices = 1, ui = true, cooldown = 0.15 },
	repair_loop     = { file = "sfx/build/repair_loop",     variants = 1, vol = 0.40, pitch = 0.04, voices = 3, near = 900,  far = 3400, loop = true },
	heal_pulse      = { file = "sfx/build/heal_pulse",      variants = 1, vol = 0.32, pitch = 0.08, voices = 3, near = 800,  far = FAR_LOCAL, cooldown = 0.12 },

	unit_ready    = { file = "sfx/unit/unit_ready",    variants = 1, vol = 0.40, pitch = 0.05, voices = 2, near = 900, far = FAR_LOCAL, cooldown = 0.10 },
	unit_select   = { file = "sfx/unit/unit_select",   variants = 1, vol = 0.35, pitch = 0.07, voices = 1, ui = true, cooldown = 0.06 },

	engine_tank        = { file = "sfx/engine/engine_tank",        variants = 1, vol = 0.26, pitch = 0.05, voices = 5, near = 180, far = 950,  zoomPow = 3.2, loop = true },
	engine_light       = { file = "sfx/engine/engine_light",       variants = 1, vol = 0.22, pitch = 0.06, voices = 5, near = 180, far = 900,  zoomPow = 3.2, loop = true },
	engine_boat        = { file = "sfx/engine/engine_boat",        variants = 1, vol = 0.24, pitch = 0.05, voices = 4, near = 200, far = 1000, zoomPow = 3.2, loop = true },
	engine_submarine   = { file = "sfx/engine/engine_submarine",   variants = 1, vol = 0.22, pitch = 0.04, voices = 3, near = 200, far = 950,  zoomPow = 3.2, loop = true },
	engine_barge       = { file = "sfx/engine/engine_barge",       variants = 1, vol = 0.24, pitch = 0.04, voices = 3, near = 200, far = 1000, zoomPow = 3.2, loop = true },
	engine_builderboat = { file = "sfx/engine/engine_builderboat", variants = 1, vol = 0.22, pitch = 0.04, voices = 3, near = 200, far = 950,  zoomPow = 3.2, loop = true },

	combat_alert  = { file = "sfx/match/combat_alert", variants = 1, vol = 0.55, pitch = 0, voices = 1, ui = true, cooldown = 4.0 },
	core_lost     = { file = "sfx/match/core_lost",    variants = 1, vol = 0.80, pitch = 0, voices = 1, ui = true },
	victory       = { file = "sfx/match/victory",      variants = 1, vol = 0.75, pitch = 0, voices = 1, ui = true },
	defeat        = { file = "sfx/match/defeat",       variants = 1, vol = 0.75, pitch = 0, voices = 1, ui = true },

	ui_hover      = { file = "sfx/ui/ui_hover",     variants = 1, vol = 0.25, pitch = 0.05, voices = 1, ui = true, cooldown = 0.05 },
	ui_click      = { file = "sfx/ui/ui_click",     variants = 1, vol = 0.35, pitch = 0.04, voices = 1, ui = true, cooldown = 0.04 },
	ping          = { file = "sfx/ui/ping",         variants = 1, vol = 0.50, pitch = 0,    voices = 1, ui = true, cooldown = 0.3 },
	chat_message  = { file = "sfx/ui/chat_message", variants = 1, vol = 0.35, pitch = 0,    voices = 1, ui = true, cooldown = 0.2 },
	ally_request  = { file = "sfx/ui/ally_request", variants = 1, vol = 0.50, pitch = 0,    voices = 1, ui = true },
	inv_equip     = { file = "sfx/ui/inv_equip",    variants = 1, vol = 0.45, pitch = 0.03, voices = 1, ui = true, cooldown = 0.08 },

	amb_fire      = { file = "sfx/amb/amb_fire", variants = 1, vol = 0.35, pitch = 0.05, voices = 4, near = 900, far = 3400, loop = true },
}

ME.SfxMaster = 1.0
