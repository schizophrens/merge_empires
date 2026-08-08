ME = ME or {}

ME.Modes = {
	{ key = "casual", label = "CASUAL", enabled = true,  min = 6, speed = 1 },
	{ key = "blitz",  label = "BLITZ",  enabled = true,  min = 6, speed = 2 },
	{ key = "ambush", label = "AMBUSH", enabled = false, min = 6, speed = 1 },
	{ key = "duel",   label = "DUEL",   enabled = false, min = 2, speed = 1 },
	{ key = "ranked", label = "RANKED", enabled = false, min = 6, speed = 1 },
}

ME.ModeByKey = {}
for _, m in ipairs(ME.Modes) do ME.ModeByKey[m.key] = m end

function ME.GetMode(key)
	return ME.ModeByKey[string.lower(string.Trim(tostring(key or "")))]
end

function ME.ModeEnabled(key)
	local m = ME.GetMode(key)
	return m ~= nil and m.enabled == true
end

function ME.ModeMinPlayers(key)
	local m = ME.GetMode(key)
	return (m and m.min) or 6
end

function ME.ModeSpeed(key)
	local m = ME.GetMode(key)
	return (m and m.speed) or 1
end

function ME.Speed()
	if SERVER then
		return ME.ModeSpeed((ME.MM and ME.MM.CurrentMode) or "casual")
	end
	return GetGlobalFloat("ME_Speed", 1)
end
