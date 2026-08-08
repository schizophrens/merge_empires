ME = ME or {}
ME.Scoreboard = ME.Scoreboard or {}
local SB = ME.Scoreboard

local S = ME.UI.Scale

local open = false
local anim = 0

local MAT_RING   = Material("mergeempires/game/players/ring.png", "smooth mips")
local MAT_DISC   = Material("mergeempires/game/players/disc.png", "smooth mips")
local MAT_DCON   = Material("mergeempires/game/me_disconnected_light_red.png", "smooth")
local MAT_RANK   = Material("mergeempires/game/me_interrogation.png", "smooth mips")
local MAT_DEVICE = Material("mergeempires/game/me_device.png", "smooth mips")
local MAT_PING   = Material("mergeempires/game/me_ping.png", "smooth mips")

local BADGE = {}
for i = 1, 10 do BADGE[i] = Material(string.format("mergeempires/rank/badge_%02d.png", i), "smooth mips") end
local BADGE_AR = 299 / 338

local BG      = Color(38, 40, 42, 255)
local HEADER  = Color(38, 40, 41, 255)
local BLACK   = Color(0, 0, 0, 235)
local HEADCOL = Color(154, 159, 166)
local SEP     = Color(255, 255, 255, 34)
local RANKCOL = Color(120, 126, 134)
local ICONCOL = Color(228, 231, 236)

local PING_OK  = Color(235, 238, 242)
local PING_MID = Color(232, 162, 52)
local PING_BAD = Color(226, 64, 52)

ME.UI.Font("ME_SbHead", { font = "Rajdhani SemiBold", size = 23, weight = 700 })
ME.UI.Font("ME_SbName", { font = "Roboto", size = 24, weight = 700 })
ME.UI.Font("ME_SbNum",  { font = "Roboto", size = 26, weight = 800 })

local function maxFac() return (ME.Config and ME.Config.MaxFactions) or 6 end
local function canShow() return not ME.MenuActive and next(ME.RosterData or {}) ~= nil end

local SEG = 48
local function circlePoly(cx, cy, r)
	local p = {}
	for i = 0, SEG - 1 do
		local a = (i / SEG) * math.pi * 2
		p[#p + 1] = { x = cx + math.cos(a) * r, y = cy + math.sin(a) * r }
	end
	return p
end

local function drawIcon(mat, cx, cy, size, col, a)
	surface.SetMaterial(mat)
	surface.SetDrawColor(col.r, col.g, col.b, a or 255)
	surface.DrawTexturedRect(cx - size / 2, cy - size / 2, size, size)
end

local function drawBadge(mat, cx, cy, h)
	local w = h * BADGE_AR
	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(cx - w / 2, cy - h / 2, w, h)
end

local avContainer
local function ensureContainer()
	if IsValid(avContainer) then
		avContainer:SetSize(ScrW(), ScrH())
		return avContainer
	end
	avContainer = vgui.Create("DPanel")
	avContainer:SetSize(ScrW(), ScrH())
	avContainer:SetPos(0, 0)
	avContainer:SetPaintBackground(false)
	avContainer:SetMouseInputEnabled(false)
	return avContainer
end

local avatarPanels = {}
local function getAvatar(sid)
	if not sid or sid == "" then return end
	local p = avatarPanels[sid]
	if not IsValid(p) then
		p = vgui.Create("AvatarImage", ensureContainer())
		p:SetSize(80, 80)
		p:SetPaintedManually(true)
		p:SetMouseInputEnabled(false)
		p:SetSteamID(sid, 64)
		avatarPanels[sid] = p
	end
	return p
end
local function clearAvatars()
	for _, p in pairs(avatarPanels) do if IsValid(p) then p:Remove() end end
	avatarPanels = {}
end

local function drawAvatar(sid, col, x, y, d, connected)
	local m  = d * 0.05
	local ad = d - m * 2
	local cx, cy, r = x + d / 2, y + d / 2, ad / 2

	if connected then
		local p = getAvatar(sid)
		if IsValid(p) then
			p:SetPos(x + m, y + m)
			p:SetSize(ad, ad)
			render.ClearStencil()
			render.SetStencilEnable(true)
			render.SetStencilWriteMask(0xFF)
			render.SetStencilTestMask(0xFF)
			render.SetStencilReferenceValue(1)
			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilPassOperation(STENCIL_REPLACE)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)
			render.OverrideColorWriteEnable(true, false)
			draw.NoTexture()
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawPoly(circlePoly(cx, cy, r))
			render.OverrideColorWriteEnable(false)
			render.SetStencilCompareFunction(STENCIL_EQUAL)
			render.SetStencilPassOperation(STENCIL_KEEP)
			p:PaintManual()
			render.SetStencilEnable(false)
		end
	else
		surface.SetMaterial(MAT_DISC)
		surface.SetDrawColor(28, 30, 36, 255)
		surface.DrawTexturedRect(x, y, d, d)
		local isz = d * 0.62
		surface.SetMaterial(MAT_DCON)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(cx - isz / 2, cy - isz / 2, isz, isz)
	end

	local bd = math.max(1, math.floor(d * 0.05 + 0.5))
	surface.SetMaterial(MAT_RING)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawTexturedRect(x, y, d, d)
	surface.SetDrawColor(col.r, col.g, col.b, 255)
	surface.DrawTexturedRect(x + bd, y + bd, d - bd * 2, d - bd * 2)
end

function SB.IsOpen() return open end

local function paint()
	if ME.MatchOver then return end
	local show = open and canShow()
	anim = Lerp(FrameTime() * 13, anim, show and 1 or 0)
	if anim < 0.01 then return end

	surface.SetDrawColor(0, 0, 0, math.floor(150 * anim))
	surface.DrawRect(0, 0, ScrW(), ScrH())

	surface.SetAlphaMultiplier(anim)

	local rows = {}
	for fac = 1, maxFac() do if ME.RosterData[fac] then rows[#rows + 1] = fac end end
	local n = #rows
	if n > 0 then
		local W      = S(972)
		local headH  = S(58)
		local rowH   = S(86)
		local panelH = headH + n * rowH
		local px = math.floor((ScrW() - W) / 2)
		local py = S(180)
		local rad, bk = S(10), S(2)
		SB.panelRect = { x = px, y = py, w = W, h = panelH }

		draw.RoundedBox(rad + bk, px - bk, py - bk, W + bk * 2, panelH + bk * 2, BLACK)
		draw.RoundedBox(rad, px, py, W, panelH, BG)
		draw.RoundedBoxEx(rad, px, py, W, headH, HEADER, true, true, false, false)

		local xRank, xPlayer, xKills, xDamage, xDevice, xPing = S(0), S(120), S(440), S(580), S(730), S(840)
		local wRank, wKills, wDamage, wDevice, wPing = S(120), S(140), S(150), S(110), S(132)

		draw.SimpleText("RANK",   "ME_SbHead", px + S(38), py + headH / 2, HEADCOL, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("KILLS",  "ME_SbHead", px + xKills + wKills / 2, py + headH / 2, HEADCOL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("DAMAGE", "ME_SbHead", px + xDamage + wDamage / 2, py + headH / 2, HEADCOL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("DEVICE", "ME_SbHead", px + xDevice + wDevice / 2, py + headH / 2, HEADCOL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("PING",   "ME_SbHead", px + xPing + wPing / 2, py + headH / 2, HEADCOL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(SEP.r, SEP.g, SEP.b, SEP.a + 10)
		surface.DrawRect(px, py + headH - 1, W, 1)

		local mySid = IsValid(LocalPlayer()) and LocalPlayer():SteamID64() or ""
		local pingBySid = {}
		for _, p in ipairs(player.GetAll()) do
			if isfunction(p.SteamID64) then pingBySid[p:SteamID64()] = p:Ping() end
		end

		for i, fac in ipairs(rows) do
			local d   = ME.RosterData[fac]
			local col = ME.FactionColor(fac)
			local ry  = py + headH + (i - 1) * rowH
			local cyr = ry + rowH / 2
			local connected = d.connected and true or false
			local isLocal   = (d.sid == mySid)
			local a = connected and 255 or 130

			if i < n then
				surface.SetDrawColor(SEP.r, SEP.g, SEP.b, SEP.a)
				surface.DrawRect(px + S(14), ry + rowH - 1, W - S(28), 1)
			end

			local rk = d.rank or 0
			if rk >= 1 and BADGE[math.min(rk, 10)] then
				drawBadge(BADGE[math.min(rk, 10)], px + xRank + wRank / 2, cyr, S(48))
			else
				drawIcon(MAT_RANK, px + xRank + wRank / 2, cyr, S(34), RANKCOL, a)
			end

			local av = S(56)
			local ax = px + xPlayer + S(4)
			drawAvatar(d.sid, col, ax, cyr - av / 2, av, connected)
			local nameCol = isLocal and ColorAlpha(col, a) or Color(255, 255, 255, a)
			draw.SimpleText(d.name or "Player", "ME_SbName", ax + av + S(18), cyr, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(tostring(d.kills or 0),  "ME_SbNum", px + xKills + wKills / 2,   cyr, Color(255, 255, 255, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(tostring(d.damage or 0), "ME_SbNum", px + xDamage + wDamage / 2, cyr, Color(255, 255, 255, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			drawIcon(MAT_DEVICE, px + xDevice + wDevice / 2, cyr, S(34), ICONCOL, a)

			local ping = pingBySid[d.sid] or d.ping or 0
			local pcol = (ping >= 150 and PING_BAD) or (ping >= 80 and PING_MID) or PING_OK
			drawIcon(MAT_PING, px + xPing + wPing / 2, cyr, S(34), pcol, a)
		end
	end

	surface.SetAlphaMultiplier(1)
end

hook.Add("HUDPaint", "ME_Scoreboard", paint)

hook.Add("ScoreboardShow", "ME_Scoreboard", function()
	if ME.MenuActive then return end
	if canShow() then open = true end
	return true
end)

hook.Add("ScoreboardHide", "ME_Scoreboard", function()
	if open then open = false return true end
end)

hook.Add("Think", "ME_ScoreboardAvatars", function()
	if canShow() then
		for fac = 1, maxFac() do
			local d = ME.RosterData[fac]
			if d and d.sid and d.sid ~= "" and not avatarPanels[d.sid] then getAvatar(d.sid) end
		end
	elseif ME.MenuActive and next(avatarPanels) then
		clearAvatars()
		open = false
	end
end)
