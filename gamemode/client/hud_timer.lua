ME = ME or {}

ME.UI.Font("ME_TimerPill",  { font = "Rajdhani SemiBold", size = 27, weight = 600 })
ME.UI.Font("ME_StartLabel", { font = "Barlow Light",      size = 24, weight = 400 })
ME.UI.Font("ME_StartNum",   { font = "Rajdhani SemiBold", size = 78, weight = 700 })

local S = ME.UI.Scale

local function fmtUp(sec)
	sec = math.max(0, math.floor(sec))
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	if h > 0 then
		return string.format("%02d:%02d:%02d", h, m, s)
	end
	return string.format("%02d:%02d", m, s)
end

local refW = {}
hook.Add("ME_UI_Rescaled", "ME_TimerClearCache", function() refW = {} end)
local function pillTextWidth(hasHours)
	local key = hasHours and "h" or "m"
	if not refW[key] then
		surface.SetFont("ME_TimerPill")
		refW[key] = surface.GetTextSize(hasHours and "00:00:00" or "00:00")
	end
	return refW[key]
end

local function drawPill()
	local t   = GetGlobalFloat("ME_MatchStartAt", 0)
	local txt = fmtUp(t > 0 and (CurTime() - t) or 0)
	local hasHours = #txt > 5

	surface.SetFont("ME_TimerPill")
	local padX = S(19)
	local w = pillTextWidth(hasHours) + padX * 2
	local h = S(38)
	local x = math.floor((ScrW() - w) / 2)
	local y = S(16)
	local b = S(1)

	draw.RoundedBox(S(8), x - b, y - b, w + b * 2, h + b * 2, Color(0, 0, 0, 185))
	draw.RoundedBox(S(8), x, y, w, h, Color(44, 46, 52, 245))
	draw.SimpleText(txt, "ME_TimerPill", x + w / 2, y + h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function drawStartBox()
	local endAt = GetGlobalFloat("ME_CountdownEnd", 0)
	local left  = math.max(0, math.ceil(endAt - CurTime()))

	local cx, cy = ScrW() / 2, ScrH() / 2
	local num = tostring(left)
	local o = S(3)
	draw.SimpleText(num, "ME_StartNum", cx + o, cy + o, Color(0, 0, 0, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(num, "ME_StartNum", cx,     cy,     color_white,         TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "ME_MatchTimer", function()
	if ME.MatchOver then return end
	if not (ME.InGame and ME.InGame()) then return end
	drawPill()
	if GetGlobalInt("ME_MatchPhase", 0) == 1 then
		drawStartBox()
	end
end)
