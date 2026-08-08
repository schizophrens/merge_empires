ME = ME or {}
ME.Precache = ME.Precache or {}

local P = ME.Precache

local FRAME_MS = 6
local held = {}

local function keep(x)
	held[#held + 1] = x
	return x
end

local function warmModel(path)
	if not path or path == "" or not util.IsValidModel(path) then return end
	util.PrecacheModel(path)
	local e = ClientsideModel(path, RENDERGROUP_OTHER)
	if IsValid(e) then
		e:SetNoDraw(true)
		e:SetupBones()
		keep(e)
	end
end

local function warmMaterial(path)
	if not path or path == "" then return end
	local m = Material(path)
	if not m or m:IsError() then return end
	local t = m:GetTexture("$basetexture")
	if t and not t:IsError() then t:Download() end
end

local function warmSound(path)
	if not path or path == "" or not file.Exists(path, "GAME") then return end
	sound.PlayFile(path, "noplay noblock", function(chan)
		if IsValid(chan) then keep(chan) end
	end)
end

local function warmAvatar(sid)
	if not sid or sid == "" or sid == "0" then return end
	local a = vgui.Create("AvatarImage")
	if not IsValid(a) then return end
	a:SetSize(64, 64)
	a:SetPos(-256, -256)
	a:SetVisible(false)
	a:SetSteamID(sid, 64)
	keep(a)
end

local function release()
	for _, x in ipairs(held) do
		if isentity(x) or (istable(x) and x.Remove) then
			if IsValid(x) then x:Remove() end
		elseif IsValid(x) and x.Stop then
			x:Stop()
		end
	end
	held = {}
end

local function run(jobs, budget, onDone)
	local i, deadline = 1, SysTime() + (budget or 20)
	local id = "ME_Precache_" .. tostring(SysTime())

	hook.Add("Think", id, function()
		local stop = SysTime() + FRAME_MS / 1000

		while i <= #jobs do
			local job = jobs[i]
			i = i + 1
			pcall(job)
			if SysTime() >= stop then break end
		end

		if i > #jobs or SysTime() >= deadline then
			hook.Remove("Think", id)
			timer.Simple(1, release)
			if onDone then onDone() end
		end
	end)
end

local function pushModels(jobs, seen, list)
	for _, m in ipairs(list) do
		if m and m ~= "" and not seen[m] then
			seen[m] = true
			jobs[#jobs + 1] = function() warmModel(m) end
		end
	end
end

local function boardModels()
	local out = {}

	for _, list in pairs((ME.Config and ME.Config.Models) or {}) do
		if istable(list) then for _, m in ipairs(list) do out[#out + 1] = m end
		else out[#out + 1] = list end
	end

	for _, m in pairs((ME.Config and ME.Config.Buildings) or {}) do out[#out + 1] = m end
	for _, f in ipairs(ME.Factions or {}) do out[#out + 1] = f.core end
	for _, b in ipairs(ME.Buildings or {}) do out[#out + 1] = b.model end

	for _, k in pairs(ME.UnitKinds or {}) do
		out[#out + 1] = k.model
		out[#out + 1] = k.weapon
	end

	for _, s in ipairs(ME.Skins or {}) do
		out[#out + 1] = s.model
		out[#out + 1] = s.weapon
	end

	out[#out + 1] = ME.GrassModel
	out[#out + 1] = "models/merge_empires/caillou.mdl"
	out[#out + 1] = "models/merge_empires/missile.mdl"
	out[#out + 1] = "models/tt_props/grave.mdl"

	return out
end

local function gameMaterials()
	local out = {}

	for _, f in ipairs(file.Find("materials/mergeempires/game/*.png", "GAME") or {}) do
		out[#out + 1] = "mergeempires/game/" .. string.StripExtension(f)
	end
	for _, f in ipairs(file.Find("materials/mergeempires/game/players/*.png", "GAME") or {}) do
		out[#out + 1] = "mergeempires/game/players/" .. string.StripExtension(f)
	end

	return out
end

local function menuMaterials()
	local out = {}

	for _, sub in ipairs({ "menu", "banner", "rank", "intro", "loading" }) do
		for _, f in ipairs(file.Find("materials/mergeempires/" .. sub .. "/*.png", "GAME") or {}) do
			out[#out + 1] = "mergeempires/" .. sub .. "/" .. string.StripExtension(f)
		end
	end

	return out
end

local function sfxPaths()
	local out, exts = {}, { ".mp3", ".wav", ".ogg", ".aiff", ".aif" }

	for _, d in pairs(ME.SfxDefs or {}) do
		local n = math.max(1, d.variants or 1)
		for i = 1, n do
			local base = n == 1 and d.file or (d.file .. "_" .. i)
			for _, e in ipairs(exts) do
				local p = "sound/mergeempires/" .. base .. e
				if file.Exists(p, "GAME") then out[#out + 1] = p break end
			end
		end
	end

	return out
end

local function connectedIDs()
	local out = {}

	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and isfunction(ply.SteamID64) then out[#out + 1] = ply:SteamID64() end
	end

	return out
end

function P.Menu(onDone)
	local jobs, seen = {}, {}

	for _, m in ipairs(menuMaterials()) do jobs[#jobs + 1] = function() warmMaterial(m) end end
	for _, m in ipairs(gameMaterials()) do jobs[#jobs + 1] = function() warmMaterial(m) end end

	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) then pushModels(jobs, seen, { ply:GetModel() }) end
	end
	pushModels(jobs, seen, boardModels())

	for _, s in ipairs({ "sound/mergeempires/music/background.mp3", "sound/mergeempires/menu/purchase.mp3",
	                     "sound/mergeempires/menu/purchase_building.mp3", "sound/mergeempires/menu/shop_open.mp3" }) do
		jobs[#jobs + 1] = function() warmSound(s) end
	end

	for _, sid in ipairs(connectedIDs()) do jobs[#jobs + 1] = function() warmAvatar(sid) end end

	run(jobs, 30, onDone)
end

function P.Match(onDone)
	local jobs, seen = {}, {}

	pushModels(jobs, seen, boardModels())
	for _, m in ipairs(gameMaterials()) do jobs[#jobs + 1] = function() warmMaterial(m) end end
	for _, s in ipairs(sfxPaths()) do jobs[#jobs + 1] = function() warmSound(s) end end
	jobs[#jobs + 1] = function() warmSound("sound/mergeempires/music/theme_game.mp3") end

	for _, sid in ipairs(connectedIDs()) do jobs[#jobs + 1] = function() warmAvatar(sid) end end

	run(jobs, 20, onDone)
end

hook.Add("ShutDown", "ME_PrecacheRelease", release)
