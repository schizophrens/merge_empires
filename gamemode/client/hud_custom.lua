ME = ME or {}
ME.Custom = ME.Custom or {}
local C = ME.Custom

ME.UI.Font("ME_CustBtn",   { font = "Roboto", size = 17, weight = 800 })
ME.UI.Font("ME_CustCode",  { font = "Roboto", size = 20, weight = 800 })
ME.UI.Font("ME_CustSpec",  { font = "Roboto", size = 19, weight = 800 })

local S = ME.UI.Scale
local MAT_EYE   = Material("mergeempires/menu/me_eye.png", "smooth")
local BLUE      = Color(56, 150, 235)
local BLUE_HI   = Color(74, 168, 250)
local COL_PILL  = Color(47, 48, 44, 255)

local codeShown = false
local codeRect  = nil

local function matchCode() return GetGlobalString("ME_MatchCode", "") end
local function inCustom()  return GetGlobalBool("ME_CustomMatch", false) and matchCode() ~= "" end

net.Receive("ME_Custom_Code", function()
	net.ReadString(); net.ReadFloat()
	codeShown = true
end)

net.Receive("ME_Custom_Kicked", function()
	local go = function()
		ME.MatchOver  = nil
		ME.MenuActive = true
		if ME.Cam then ME.Cam.selected = {} end
		if ME.HideEndScreen then ME.HideEndScreen() end
		if ME.CloseCommander then ME.CloseCommander() end
		if MEMenu and MEMenu.ReturnToLobby then MEMenu.ReturnToLobby() end
		timer.Simple(1.4, function()
			if MEMenu and MEMenu._State and IsValid(MEMenu._State.panel) then
				MEMenu._State.panel:RunJavascript("try{CineAPI.notify('You were removed from the match by the host.')}catch(e){}")
			end
		end)
	end
	if ME.TransitionToLobby then ME.TransitionToLobby(go) else go() end
end)

net.Receive("ME_SpectateEnter", function()
	if ME.MenuActive and MEMenu and MEMenu.Finish then MEMenu.Finish() end
	ME.MenuActive = false
	ME.MatchOver  = "spectate"
	local ctr = ME.MapInfo and ME.MapInfo.center
	if ctr and ME.Cam then
		ME.Cam.focus = Vector(ctr.x, ctr.y, ctr.z)
		ME.Cam.yaw, ME.Cam.pitch, ME.Cam.dist = 0, 60, 4200
		ME.Cam.distTarget = 4200
	end
	if ME.StartWakeFade then ME.StartWakeFade(1.2) end
end)

local function drawTriUp(cx, baseY, halfW, ht, col)
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	for i = 0, ht - 1 do
		local hw = halfW * (i / ht)
		surface.DrawRect(cx - hw, baseY - ht + i, hw * 2 + 1, 1)
	end
end

local function drawCodeButton()
	local x, y = S(16), S(16)
	local h    = S(33)
	local pad  = S(16)
	surface.SetFont("ME_CustBtn")
	local tw = surface.GetTextSize("CODE")
	local w  = pad * 2 + tw
	codeRect = { x = x, y = y, w = w, h = h }

	local mx, my = 0, 0
	if IsValid(ME.Panel) then mx, my = ME.Panel:LocalCursorPos() end
	local hover = mx >= x and mx <= x + w and my >= y and my <= y + h
	draw.RoundedBox(S(11), x, y, w, h, hover and BLUE_HI or BLUE)
	draw.SimpleText("CODE", "ME_CustBtn", x + w / 2, y + h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if codeShown then
		local code  = matchCode()
		surface.SetFont("ME_CustCode")
		local cw    = surface.GetTextSize(code)
		local pw    = math.max(w - S(6), cw + S(14))
		local ph    = S(25)
		local triH  = S(9)
		local py    = y + h + triH + S(6)
		local px    = math.max(S(6), x + (w - pw) / 2)
		local tcx   = x + w / 2

		drawTriUp(tcx, py, S(5), triH, COL_PILL)
		draw.RoundedBox(S(6), px, py, pw, ph, COL_PILL)
		draw.SimpleText(code, "ME_CustCode", px + pw / 2, py + ph / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

local function drawSpecCount()
	local n = GetGlobalInt("ME_SpecCount", 0)
	if n <= 0 then return end

	local x = (codeRect and (codeRect.x + codeRect.w + S(10))) or S(16)
	local y = S(16)
	local h = S(28)
	local pad = S(10)

	surface.SetFont("ME_CustSpec")
	local numW = surface.GetTextSize(tostring(n))
	local icoS = S(17)
	local w = pad + icoS + S(7) + numW + pad

	draw.RoundedBox(S(6), x, y, w, h, Color(10, 11, 13, 225))
	surface.SetDrawColor(230, 236, 244, 255)
	surface.SetMaterial(MAT_EYE)
	surface.DrawTexturedRect(x + pad, y + (h - icoS) / 2, icoS, icoS)
	draw.SimpleText(tostring(n), "ME_CustSpec", x + pad + icoS + S(7), y + h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "ME_CustomHUD", function()
	if ME.HudOn and not ME.HudOn("custom") then return end
	if not ((ME.InGame and ME.InGame()) or ME.MatchOver == "spectate") then return end
	if not inCustom() then codeRect = nil return end
	drawCodeButton()
	drawSpecCount()
end)

function C.Click(mx, my)
	if not inCustom() or not codeRect then return false end
	local r = codeRect
	if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
		codeShown = not codeShown
		return true
	end
	return false
end

