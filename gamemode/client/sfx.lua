ME = ME or {}
ME.Sfx = ME.Sfx or {}
local X = ME.Sfx

local SND_ROOT   = "sound/mergeempires/"
local GLOBAL_CAP = 24
local POOL_MAX   = 4
local LOOP_GRACE = 0.35

local defs      = {}
local pool      = {}
local active    = {}
local pending    = {}
local lastPlay  = {}
local lastPick  = {}
local loops     = {}
local totalOpen = 0

local EXTS = { ".mp3", ".wav", ".ogg", ".aiff", ".aif" }
local function findFile(base)
	for _, e in ipairs(EXTS) do
		local p = SND_ROOT .. base .. e
		if file.Exists(p, "GAME") then return p end
	end
end

local function resolve()
	defs = {}
	for id, d in pairs(ME.SfxDefs or {}) do
		local paths, n = {}, math.max(1, d.variants or 1)
		if n == 1 then
			paths[1] = findFile(d.file)
		else
			for i = 1, n do
				local p = findFile(d.file .. "_" .. i)
				if p then paths[#paths + 1] = p end
			end

			if #paths == 0 then paths[1] = findFile(d.file) end
		end
		defs[id] = {
			paths = paths, vol = d.vol or 0.5, pitch = d.pitch or 0, voices = d.voices or 3,
			near = d.near or 900, far = d.far or 5000, cooldown = d.cooldown or 0, zoomPow = d.zoomPow or 1,
			loop = d.loop and true or false, ui = d.ui and true or false,
		}
	end
end
hook.Add("InitPostEntity", "ME_SfxResolve", resolve)
resolve()

local function listenPos()
	local c = ME.Cam
	return (c and c.focus) or (IsValid(LocalPlayer()) and LocalPlayer():GetPos()) or vector_origin
end

local function falloff(d, pos)
	local dist = listenPos():Distance(pos)
	if dist >= d.far then return nil end
	local f = 1
	if dist > d.near then f = 1 - (dist - d.near) / (d.far - d.near) end

	local zoom = math.Clamp(3000 / math.max(1, (ME.Cam and ME.Cam.dist) or 3000), 0.10, 1.05)
	if d.zoomPow and d.zoomPow ~= 1 then zoom = math.Clamp(math.pow(zoom, d.zoomPow), 0, 1.05) end

	return math.pow(f, 1.35) * zoom, dist
end

local function sweep(id)
	local list = active[id]
	if not list then return 0 end
	for i = #list, 1, -1 do
		local v = list[i]
		if not IsValid(v.chan) or v.chan:GetState() == GMOD_CHANNEL_STOPPED then
			if IsValid(v.chan) then
				local key = v.path .. (v.is3d and "|3d" or "|2d")
				local p = pool[key]
				if not p then p = {}; pool[key] = p end
				if #p < POOL_MAX then p[#p + 1] = v.chan else v.chan:Stop() end
			end
			table.remove(list, i)
			totalOpen = math.max(0, totalOpen - 1)
		end
	end
	return #list + (pending[id] or 0)
end

local function claimVoice(id, d, dist)
	local n = sweep(id)
	if totalOpen >= GLOBAL_CAP then return false end
	if n < d.voices then return true end
	local list, worst, worstI = active[id], -1, nil
	for i, v in ipairs(list or {}) do
		if v.dist > worst then worst, worstI = v.dist, i end
	end
	if worstI and dist < worst then
		local v = list[worstI]
		if IsValid(v.chan) then v.chan:Stop() end
		table.remove(list, worstI)
		totalOpen = math.max(0, totalOpen - 1)
		return true
	end
	return false
end

local function pickPath(id, d)
	local n = #d.paths
	if n == 0 then return nil end
	if n == 1 then return d.paths[1] end
	local last, i = lastPick[id], nil
	for _ = 1, 6 do
		i = math.random(n)
		if i ~= last then break end
	end
	lastPick[id] = i
	return d.paths[i]
end

local function open(path, is3d, cb)
	local key = path .. (is3d and "|3d" or "|2d")
	local p = pool[key]
	if p then
		for i = #p, 1, -1 do
			local c = p[i]
			table.remove(p, i)
			if IsValid(c) then c:SetTime(0); cb(c) return end
		end
	end

	sound.PlayFile(path, is3d and "3d mono noplay noblock" or "noplay noblock",
		function(chan) cb(IsValid(chan) and chan or nil) end)
end

local function configure(chan, d, pos, vol, pitch)

	if pos and chan.Is3D and chan:Is3D() then
		chan:SetPos(pos)

		chan:Set3DFadeDistance(60000, 120000)
	end
	chan:SetVolume(math.Clamp(vol, 0, 1) * (ME.SfxMaster or 1))
	if pitch and pitch ~= 0 then chan:SetPlaybackRate(math.Clamp(1 + pitch, 0.5, 2)) end
end

function X.Play(id, pos, opts)
	local d = defs[id]
	if not (d and #d.paths > 0) or d.loop then return end
	opts = opts or {}

	local vol, dist = d.vol, 0
	if d.ui or not pos then
		pos = nil
	else
		local f, dd = falloff(d, pos)
		if not f then return end
		vol, dist = d.vol * f, dd
	end
	vol = vol * (opts.vol or 1)

	if d.cooldown > 0 then
		local key = pos and (id .. "|" .. math.floor(pos.x / 160) .. "|" .. math.floor(pos.y / 160)) or id
		local now = RealTime()
		if (lastPlay[key] or -99) + d.cooldown > now then return end
		lastPlay[key] = now
	end

	if not claimVoice(id, d, dist) then return end

	local path  = pickPath(id, d)
	local pitch = (opts.pitch or d.pitch)
	pitch = pitch ~= 0 and math.Rand(-pitch, pitch) or 0

	pending[id] = (pending[id] or 0) + 1
	local function launch(chan)
		pending[id] = math.max(0, (pending[id] or 1) - 1)
		if not IsValid(chan) then return end
		configure(chan, d, pos, vol, pitch)
		chan:Play()
		active[id] = active[id] or {}
		table.insert(active[id], { chan = chan, path = path, is3d = pos ~= nil, t = RealTime(), dist = dist })
		totalOpen = totalOpen + 1
	end

	if (opts.delay or 0) > 0 then
		timer.Simple(opts.delay, function() open(path, pos ~= nil, launch) end)
	else
		open(path, pos ~= nil, launch)
	end
end

function X.Play2D(id, opts) X.Play(id, nil, opts) end

function X.Loop(key, id, pos, volMul)
	local d = defs[id]
	if not (d and #d.paths > 0 and d.loop) then return end
	local f = 1
	if pos then
		f = falloff(d, pos)
		if not f then f = 0 end
	end
	local vol = d.vol * f * (volMul or 1)

	local L = loops[key]
	if not L then
		if totalOpen >= GLOBAL_CAP then return end
		L = { until_ = RealTime() + LOOP_GRACE }
		loops[key] = L
		local path = pickPath(id, d)
		totalOpen = totalOpen + 1
		open(path, pos ~= nil, function(chan)
			if not IsValid(chan) or not loops[key] then
				totalOpen = math.max(0, totalOpen - 1)
				if IsValid(chan) then chan:Stop() end
				return
			end
			chan:EnableLooping(true)
			configure(chan, d, pos, vol, d.pitch ~= 0 and math.Rand(-d.pitch, d.pitch) or 0)
			chan:Play()
			L.chan = chan
		end)
	end
	L.until_ = RealTime() + LOOP_GRACE
	L.vol, L.pos = vol, pos
	if IsValid(L.chan) then
		if pos and L.chan.Is3D and L.chan:Is3D() then L.chan:SetPos(pos) end
		L.chan:SetVolume(math.Clamp(vol, 0, 1) * (ME.SfxMaster or 1))
	end
end

function X.StopLoop(key)
	local L = loops[key]
	if not L then return end
	if IsValid(L.chan) then L.chan:Stop() end
	loops[key] = nil
	totalOpen = math.max(0, totalOpen - 1)
end

hook.Add("Think", "ME_SfxLoops", function()
	local now = RealTime()
	for key, L in pairs(loops) do
		if now > L.until_ then X.StopLoop(key) end
	end
end)

function X.StopAll()
	for key in pairs(loops) do X.StopLoop(key) end
	for id, list in pairs(active) do
		for _, v in ipairs(list) do if IsValid(v.chan) then v.chan:Stop() end end
		active[id] = nil
	end
	for path, p in pairs(pool) do
		for _, c in ipairs(p) do if IsValid(c) then c:Stop() end end
		pool[path] = nil
	end
	totalOpen = 0
end
hook.Add("ShutDown", "ME_SfxShutdown", X.StopAll)

