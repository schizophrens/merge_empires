ME = ME or {}

local HUD_FONT = "Roboto"
ME.UI.Font("ME_HudMoney",  { font = HUD_FONT, size = 25, weight = 700 })
ME.UI.Font("ME_HudIncome", { font = HUD_FONT, size = 14, weight = 400 })
ME.UI.Font("ME_HudUnit",   { font = HUD_FONT, size = 22, weight = 700 })
ME.UI.Font("ME_HudGuide",  { font = "Roboto", size = 20, weight = 700 })

local S = ME.UI.Scale

local MAT_COIN  = Material("mergeempires/game/me_coin.png", "smooth")
local MAT_POP   = Material("mergeempires/game/me_pop.png", "smooth")
local MAT_BOOK  = Material("mergeempires/game/me_book.png", "smooth")
local MAT_EXIT  = Material("mergeempires/game/me_exit.png", "smooth")

local TOPM     = 16
local BH       = 38
local GAP      = 7
local BANNER_H = 46
local GUIDE_W  = 106
local SQ_W     = 38
local BTN_GAP  = 7

local COL_MONEY  = Color(255, 214, 64)
local COL_INCOME = Color(180, 184, 188)
local COL_BAND   = { r = 32, g = 33, b = 37, a = 255 }

local function comma(n)
	local s = tostring(math.floor(n))
	s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end

local function dropShadow(w, h, r)
	DisableClipping(true)
	for i = 1, 3 do
		draw.RoundedBox(r + i, -i, S(2) + i, w + i * 2, h, Color(0, 0, 0, 18))
	end
	DisableClipping(false)
end

local dispMoney

local function drawBanner()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local money    = ply:GetNWInt("ME_Money", 0)
	local income   = ply:GetNWInt("ME_Income", 0)
	local units    = ply:GetNWInt("ME_Units", 0)
	local umax     = ply:GetNWInt("ME_UnitMax", (ME.Config and ME.Config.UnitMax) or 10)
	local interval = (ME.Config and ME.Config.IncomeInterval) or 3

	if dispMoney == nil then dispMoney = money end
	local rate = interval > 0 and (income / interval) or 0
	local ft   = FrameTime()

	if dispMoney < money then dispMoney = math.min(dispMoney + rate * ft, money) end
	dispMoney = dispMoney + (money - dispMoney) * math.min(1, ft * 4)

	local bh = S(BANNER_H)
	local by = S(TOPM) + S(BH) + S(GAP)
	local cy = by + bh / 2

	local moneyStr = comma(dispMoney)
	local incStr   = "(+" .. comma(income * 60 / interval) .. ")"
	local unitStr  = units .. "/" .. umax

	local pad    = S(16)
	local rightX = ScrW() - pad

	surface.SetFont("ME_HudUnit")
	local uw = surface.GetTextSize(unitStr)
	local us = S(28)
	local unitTextX = rightX
	local unitIconX = rightX - uw - S(8) - us

	surface.SetFont("ME_HudIncome")
	local iw = surface.GetTextSize(incStr)
	local incRightX = unitIconX - S(26)

	surface.SetFont("ME_HudMoney")
	local mw = surface.GetTextSize(moneyStr)
	local moneyRightX = incRightX - iw - S(8)

	local cs    = S(26)
	local coinX = moneyRightX - mw - S(10) - cs

	local solidL = coinX - S(18)
	local gradW  = S(230)
	local gradL  = solidL - gradW
	local A, r, g, b = COL_BAND.a, COL_BAND.r, COL_BAND.g, COL_BAND.b
	for i = 0, gradW - 1 do
		local t = i / gradW
		surface.SetDrawColor(r, g, b, (t * t * (3 - 2 * t)) * A)
		surface.DrawRect(gradL + i, by, 1, bh)
	end
	surface.SetDrawColor(r, g, b, A)
	surface.DrawRect(solidL, by, ScrW() - solidL, bh)

	surface.SetMaterial(MAT_COIN)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(coinX, cy - cs / 2, cs, cs)
	draw.SimpleText(moneyStr, "ME_HudMoney", moneyRightX, cy, COL_MONEY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	draw.SimpleText(incStr, "ME_HudIncome", incRightX, cy, COL_INCOME, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	surface.SetMaterial(MAT_POP)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(unitIconX, cy - us / 2, us, us)
	draw.SimpleText(unitStr, "ME_HudUnit", unitTextX, cy, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "ME_HudEconomy", function()
	if ME.MatchOver then return end
	if not (ME.InGame and ME.InGame()) then return end
	drawBanner()
end)

local guideBtn, exitBtn

local function styleGuide(b, mat, label)
	b.Paint = function(_, w, h)
		dropShadow(w, h, S(8))
		draw.RoundedBox(S(8), 0, 0, w, h, Color(0, 0, 0, 185))
		local fill = b:IsHovered() and Color(40, 42, 50, 250) or Color(24, 26, 32, 250)
		draw.RoundedBox(S(8), S(1), S(1), w - S(2), h - S(2), fill)

		local is  = S(21)
		local gap = S(6)
		surface.SetFont("ME_HudGuide")
		local tw = surface.GetTextSize(label)
		local sx = math.floor((w - (is + gap + tw)) / 2)

		surface.SetMaterial(mat)
		surface.SetDrawColor(235, 238, 245, 255)
		local iy = (h - is) / 2
		surface.DrawTexturedRect(sx, iy, is, is)
		draw.SimpleText(label, "ME_HudGuide", sx + is + gap, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

local function styleExit(b)
	b.Paint = function(_, w, h)
		local hov  = b:IsHovered()
		local base = hov and Color(255, 105, 105, 255) or Color(255, 78, 78, 255)

		dropShadow(w, h, S(8))
		draw.RoundedBox(S(8), 0, 0, w, h, Color(0, 0, 0, 185))
		draw.RoundedBox(S(8), S(1), S(1), w - S(2), h - S(2), base)

		local is = S(24)
		surface.SetMaterial(MAT_EXIT)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect((w - is) / 2 + S(1), (h - is) / 2 + S(1), is, is)
	end
end

local function ensureButtons()
	if IsValid(guideBtn) then guideBtn:Remove() end
	if IsValid(exitBtn)  then exitBtn:Remove() end

	local topm   = S(TOPM)
	local bhh    = S(BH)
	local guideW = S(GUIDE_W)
	local sqW    = S(SQ_W)
	local btnGap = S(BTN_GAP)

	local exitX  = ScrW() - sqW - S(10)
	local guideX = exitX - btnGap - guideW

	guideBtn = vgui.Create("DButton", ME.Panel)
	guideBtn:SetText("")
	guideBtn:SetSize(guideW, bhh)
	guideBtn:SetPos(guideX, topm)
	guideBtn:SetCursor("hand")
	styleGuide(guideBtn, MAT_BOOK, "GUIDE")
	guideBtn.DoClick = function()
		if ME.OpenGuide then ME.OpenGuide() end
	end

	exitBtn = vgui.Create("DButton", ME.Panel)
	exitBtn:SetText("")
	exitBtn:SetSize(sqW, bhh)
	exitBtn:SetPos(exitX, topm)
	exitBtn:SetCursor("hand")
	styleExit(exitBtn)
	exitBtn.DoClick = function()
		if ME.OpenExitConfirm then ME.OpenExitConfirm() end
	end
end

hook.Add("Think", "ME_HudButtons", function()
	local live = (ME.InGame and ME.InGame()) or ME.MatchOver == "spectate"
	if not live then return end
	if IsValid(ME.Panel) and not (IsValid(guideBtn) and guideBtn:GetParent() == ME.Panel) then
		ensureButtons()
	end
	if IsValid(guideBtn) then guideBtn:SetVisible(ME.HudOn and ME.HudOn("guide") or false) end
	if IsValid(exitBtn)  then exitBtn:SetVisible(ME.HudOn and ME.HudOn("exit")  or false) end
end)

hook.Add("OnScreenSizeChanged", "ME_HudButtonsRescale", function()
	if (ME.InGame and ME.InGame()) and IsValid(ME.Panel) then
		ensureButtons()
	end
end)
