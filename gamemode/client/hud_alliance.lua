ME = ME or {}
ME.Alliance = ME.Alliance or {}
local A = ME.Alliance

ME.UI.Font("ME_AllyBtn",   { font = "Roboto", size = 17, weight = 700 })
ME.UI.Font("ME_AllyKick",  { font = "Roboto", size = 14, weight = 700 })
ME.UI.Font("ME_AllyName",  { font = "Roboto", size = 21, weight = 800 })
ME.UI.Font("ME_AllySub",   { font = "Roboto", size = 17, weight = 700 })
ME.UI.Font("ME_AllyPing",  { font = "Roboto", size = 16, weight = 800 })

local S = ME.UI.Scale

local INVITE_TTL  = 10
local PING_LIFE   = 6
local PING_KINDS  = {
	[0] = { label = "ATTACK HERE", col = Color(244, 64, 64) },
	[1] = { label = "DEFEND HERE", col = Color(70, 200, 110) },
}

A.menuFac    = nil
A.sentTo     = nil
A.sentExpire = 0
A.request    = nil
A.reqAnim    = 0
A.reqAvatar  = nil
A.pings      = A.pings or {}

local yesRect, noRect

local function myTeam() return IsValid(LocalPlayer()) and LocalPlayer():Team() or 0 end
local function rdata(f) return ME.RosterData and ME.RosterData[f] end

local function isHost() return IsValid(LocalPlayer()) and LocalPlayer():GetNWBool("ME_IsHost", false) end
local function windowOpen()
	local s = GetGlobalFloat("ME_MatchStartAt", 0)
	return s > 0 and (CurTime() - s) <= 15 * 60
end

local function sendInvite(fac)
	net.Start("ME_AllyInvite") net.WriteUInt(fac, 3) net.SendToServer()
	A.sentTo, A.sentExpire = fac, CurTime() + INVITE_TTL
end

local function sendBreak()
	net.Start("ME_AllyBreak") net.SendToServer()
end

local function sendRespond(accept)
	net.Start("ME_AllyRespond") net.WriteBool(accept) net.SendToServer()
end

function A.Ping(kind)
	if not (ME.AreAllied and rdata(myTeam()) and rdata(myTeam()).ally and rdata(myTeam()).ally > 0) then return end
	if not ME.GroundUnderCursor then return end
	local pos = ME.GroundUnderCursor()
	if not pos then return end
	net.Start("ME_AllyPing") net.WriteVector(pos) net.WriteUInt(kind or 0, 2) net.SendToServer()
end

local function clearRequest()
	if IsValid(A.reqAvatar) then A.reqAvatar:Remove() end
	A.reqAvatar = nil
	A.request = nil
end

local function closeRequest()
	if A.request then A.request.closing = true end
end

local function showRequest(from, dur)
	clearRequest()
	A.request = { from = from, expire = CurTime() + (dur or INVITE_TTL), closing = false }
	A.reqAnim = 0
	if IsValid(ME.Panel) then
		local s = vgui.Create("MERosterSlot", ME.Panel)
		s:SetMouseInputEnabled(false)
		s:SetFaction(from)
		s:SetConnected(true)
		local e = rdata(from)
		if e and e.sid then s:SetSID(e.sid) end
		A.reqAvatar = s
	end
end

net.Receive("ME_AllyRequest", function()
	local from = net.ReadUInt(3)
	local dur  = net.ReadFloat()
	if ME.Sfx then ME.Sfx.Play2D("ally_request") end
	showRequest(from, dur)
end)

net.Receive("ME_AllyPing", function()
	local fac  = net.ReadUInt(3)
	local pos  = net.ReadVector()
	local kind = net.ReadUInt(2)
	A.pings[#A.pings + 1] = { fac = fac, pos = pos, kind = kind, die = CurTime() + PING_LIFE }
	if ME.Sfx then ME.Sfx.Play2D("ping") end
end)

function A.OpenMenu(fac)
	local me = myTeam()
	if fac == me then A.menuFac = nil return end
	local mine = rdata(me)
	if mine and mine.breaking and mine.ally == fac then A.menuFac = nil return end
	local e = rdata(fac)
	if not (e and e.connected) then A.menuFac = nil return end
	A.menuFac = fac
end

local function menuState(fac)
	local me  = myTeam()
	local mine = rdata(me)
	local them = rdata(fac)
	if not (them and them.connected) then return end

	if isHost() and fac ~= me then
		return "Kick", Color(228, 52, 52), "kick"
	end
	if not mine then return end
	if mine.ally == fac then
		return "Break", Color(228, 52, 52), "break"
	end
	if A.sentTo == fac and CurTime() < A.sentExpire then
		return "Sent", Color(70, 74, 82), nil
	end
	if windowOpen() and (mine.ally or 0) == 0 and (them.ally or 0) == 0 then
		return "Ally", Color(43, 108, 230), "invite"
	end
end

local function drawHover()
	local mx, my = gui.MousePos()
	local fac = ME.RosterSlotAt and ME.RosterSlotAt(mx, my)
	if not fac then return end
	local r = (ME.RosterSlotRects or {})[fac]
	if not r then return end
	local cx, cy = r.x + r.w / 2, r.y + r.h / 2
	local rad = r.w / 2 - S(4)
	local poly = {}
	for i = 0, 39 do
		local a = (i / 40) * math.pi * 2
		poly[#poly + 1] = { x = cx + math.cos(a) * rad, y = cy + math.sin(a) * rad }
	end
	draw.NoTexture()
	surface.SetDrawColor(255, 255, 255, 18)
	surface.DrawPoly(poly)
end

local function drawLines()
	local rects = ME.RosterSlotRects or {}
	local me = myTeam()
	for fac, e in pairs(ME.RosterData or {}) do
		local ally = e.ally or 0
		if ally > fac and rects[fac] and rects[ally] then
			local ra, rb = rects[fac], rects[ally]
			local ax = ra.x + ra.w / 2
			local bx = rb.x + rb.w / 2
			local topY = ra.y - S(10)
			local r, g, b = 255, 255, 255
			if e.breaking then
				local t = (math.sin(CurTime() * 3) + 1) / 2
				r = 255 - (255 - 244) * t
				g = 255 - (255 - 64) * t
				b = 255 - (255 - 64) * t
			end
			surface.SetDrawColor(r, g, b, 255)
			local th = S(3)
			surface.DrawRect(math.min(ax, bx), topY, math.abs(bx - ax), th)
			surface.DrawRect(ax - th / 2, topY, th, ra.y - topY)
			surface.DrawRect(bx - th / 2, topY, th, rb.y - topY)
		end
	end
end

local btnRectScreen, lastBtnKey

local function buildBtnHTML()
	local AST  = "asset://garrysmod/materials/mergeempires/"
	local zoom = string.format("%.4f", ScrH() / 1080)
	return ([==[
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
@font-face{font-family:'Eina';src:url('__AST__fonts/Eina-03-SemiBold.otf') format('opentype')}
*{margin:0;padding:0;box-sizing:border-box;user-select:none}
html{zoom:__ZOOM__}
html,body{width:100%;height:100%;background:transparent;overflow:hidden;pointer-events:none;font-family:'Eina','Segoe UI',sans-serif}
#allyBtn{position:fixed;left:0;top:0;transform:translateX(-50%);display:none;flex-direction:column;align-items:center;z-index:60}
#allyBtn.on{display:flex}
.aTri{width:0;height:0;border-left:8px solid transparent;border-right:8px solid transparent;border-bottom:9px solid #0c0c0e;margin-bottom:-1px}
.aBtnInner{display:flex;align-items:center;justify-content:center;gap:7px;height:35px;min-width:84px;padding:0 13px;border-radius:8px;
  box-shadow:0 0 0 2px #000,0 5px 14px rgba(0,0,0,.5);cursor:pointer;pointer-events:auto;color:#fff;font-size:18px;font-weight:700;letter-spacing:.4px;transition:filter .1s}
.aBtnInner:hover{filter:brightness(1.1)}
.aBtnInner.ally{background:#2b6ce6}
.aBtnInner.sent{background:#494d55;cursor:default}
.aBtnInner.sent:hover{filter:none}
.aBtnInner.brk{background:#e43838}
.aBtnInner.kick{background:#c8322e}
.ashake{flex:0 0 auto;width:26px;height:16px;background:url('__AST__game/me_headshake.png') center / 100% auto no-repeat}
.ahammer{flex:0 0 auto;width:18px;height:18px;background:url('__AST__menu/me_kick.png') center / 100% auto no-repeat;display:none}
.aBtnInner.kick .ashake{display:none}
.aBtnInner.kick .ahammer{display:block}
</style></head><body>
<div id="allyBtn"><div class="aTri"></div>
  <div class="aBtnInner ally" id="allyInner" onclick="try{meally.act()}catch(e){}"><div class="ashake"></div><div class="ahammer"></div><span id="allyLabel">Ally</span></div>
</div>
<script>
function $(i){return document.getElementById(i)}
function setBtn(show,x,top,label,state){var b=$('allyBtn');if(!b)return;
  if(!show){b.className='';return;}
  b.style.left=x+'px';b.style.top=top+'px';b.className='on';
  $('allyInner').className='aBtnInner '+state;$('allyLabel').textContent=label;}
</script></body></html>
]==]):gsub("__AST__", AST):gsub("__ZOOM__", zoom)
end

local function ensureBtn()
	if IsValid(A.btn) or not IsValid(ME.Panel) then return end
	A.btn = vgui.Create("DHTML", ME.Panel)
	A.btn:SetSize(ScrW(), ScrH())
	A.btn:SetPos(0, 0)
	A.btn:SetMouseInputEnabled(false)
	A.btn:SetKeyboardInputEnabled(false)
	A.btn:SetAllowLua(false)
	A.btn:AddFunction("meally", "act", function()
		local _, _, action = menuState(A.menuFac)
		if action == "invite" then sendInvite(A.menuFac)
		elseif action == "break" then sendBreak(); A.menuFac = nil
		elseif action == "kick" then
			net.Start("ME_HostKick") net.WriteUInt(A.menuFac or 0, 3) net.SendToServer()
			A.menuFac = nil
		end
	end)
	A.btn:SetHTML(buildBtnHTML())
	lastBtnKey = nil
end

local function updateBtn()
	if not IsValid(A.btn) then btnRectScreen = nil return end
	local fac = A.menuFac
	local label = fac and select(1, menuState(fac)) or nil
	local r = fac and (ME.RosterSlotRects or {})[fac]
	if not (fac and label and r) then
		btnRectScreen = nil
		if lastBtnKey ~= "off" then A.btn:Call("setBtn(false)"); lastBtnKey = "off" end
		return
	end
	local state = (label == "Break" and "brk") or (label == "Sent" and "sent") or (label == "Kick" and "kick") or "ally"
	local cx  = r.x + r.w / 2
	local top = r.y + r.h + S(3)
	local z   = ScrH() / 1080
	A.btn:Call(string.format("setBtn(true,%d,%d,'%s','%s')", math.floor(cx / z), math.floor(top / z), label, state))
	lastBtnKey = label
	btnRectScreen = { x = cx - S(80), y = top, w = S(160), h = S(54) }
end

local function drawRequest()
	yesRect, noRect = nil, nil
	local req = A.request
	if not req then return end

	if req.closing then
		A.reqAnim = A.reqAnim - FrameTime() * 6
		if A.reqAnim <= 0 then clearRequest() return end
	else
		A.reqAnim = math.min(1, A.reqAnim + FrameTime() * 6)
		if CurTime() >= req.expire then closeRequest() end
	end
	A.reqAnim = math.Clamp(A.reqAnim, 0, 1)

	local col = ME.FactionColor(req.from)
	local fname = (ME.GetFaction(req.from) and string.upper(ME.GetFaction(req.from).name) or "ENEMY") .. " FACTION"

	local popW, popH = S(388), S(82)
	local restX = ScrW() - popW - S(24)
	local x = Lerp(A.reqAnim, ScrW() + S(30), restX)
	local y = S(150)

	draw.RoundedBox(S(10), x, y, popW, popH, Color(0, 0, 0, 255))
	draw.RoundedBox(S(10), x + S(1), y + S(1), popW - S(2), popH - S(2), Color(44, 44, 48, 255))

	local av = S(56)
	local ax, ay = x + S(12), y + (popH - av) / 2
	if IsValid(A.reqAvatar) then
		A.reqAvatar:SetSize(av, av)
		A.reqAvatar:SetPos(ax, ay)
	end

	local tx = ax + av + S(10)
	draw.SimpleText(fname, "ME_AllyName", tx, y + S(27), col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText("JOIN ALLIANCE?", "ME_AllySub", tx, y + S(51), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local btw, bth = S(64), S(40)
	local nbx = x + popW - btw - S(14)
	local ybx = nbx - btw - S(9)
	local bty = y + (popH - bth) / 2 - S(3)
	yesRect = { x = ybx, y = bty, w = btw, h = bth }
	noRect  = { x = nbx, y = bty, w = btw, h = bth }
	local mx, my = gui.MousePos()
	local yh = mx >= ybx and mx <= ybx + btw and my >= bty and my <= bty + bth
	local nh = mx >= nbx and mx <= nbx + btw and my >= bty and my <= bty + bth
	draw.RoundedBox(S(8), ybx, bty, btw, bth, yh and Color(74, 138, 255) or Color(43, 108, 230))
	draw.SimpleText("YES", "ME_AllyBtn", ybx + btw / 2, bty + bth / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.RoundedBox(S(8), nbx, bty, btw, bth, nh and Color(100, 104, 112) or Color(78, 82, 90))
	draw.SimpleText("NO", "ME_AllyBtn", nbx + btw / 2, bty + bth / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local frac = math.Clamp((req.expire - CurTime()) / INVITE_TTL, 0, 1)
	draw.RoundedBox(S(2), x + S(14), y + popH - S(9), (popW - S(28)) * frac, S(3), col)
end

local function drawPings()
	for i = #A.pings, 1, -1 do
		local p = A.pings[i]
		if CurTime() >= p.die then table.remove(A.pings, i)
		else
			local sc = p.pos:ToScreen()
			if sc.visible then
				local k = PING_KINDS[p.kind] or PING_KINDS[0]
				local a = math.Clamp((p.die - CurTime()) / PING_LIFE, 0, 1) * 255
				local pulse = 1 + math.sin(CurTime() * 6) * 0.12
				local sz = S(16) * pulse
				surface.SetDrawColor(k.col.r, k.col.g, k.col.b, a)

				draw.NoTexture()
				surface.DrawPoly({
					{ x = sc.x, y = sc.y },
					{ x = sc.x - sz, y = sc.y - sz * 1.6 },
					{ x = sc.x + sz, y = sc.y - sz * 1.6 },
				})
				draw.SimpleText(k.label, "ME_AllyPing", sc.x, sc.y - sz * 1.6 - S(14), Color(k.col.r, k.col.g, k.col.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			end
		end
	end
end

function A.Draw(w, h)
	drawLines()
	drawHover()
	drawPings()
	updateBtn()
	drawRequest()
end

local function inRect(r, mx, my) return r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h end

function A.Click(mx, my)
	if A.request and not A.request.closing then
		if inRect(yesRect, mx, my) then sendRespond(true)  closeRequest() return true end
		if inRect(noRect,  mx, my) then sendRespond(false) closeRequest() return true end
	end

	local fac = ME.RosterSlotAt and ME.RosterSlotAt(mx, my)
	if fac then A.OpenMenu(fac) return true end
	if A.menuFac then A.menuFac = nil end
	return false
end

A.btnOver = false
hook.Add("Think", "ME_AllyBtnEnsure", function()
	if (ME.InGame and ME.InGame()) and not ME.MatchOver then
		ensureBtn()
	elseif IsValid(A.btn) then
		A.btn:Remove(); A.btn = nil
	end
end)
hook.Add("Think", "ME_AllyBtnMouse", function()
	if gui.IsGameUIVisible() then
		if A.btnOver and IsValid(A.btn) then A.btnOver = false; A.btn:SetMouseInputEnabled(false) end
		return
	end
	if not IsValid(A.btn) then return end
	local over = false
	if btnRectScreen then
		local mx, my = gui.MousePos()
		local r = btnRectScreen
		over = mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
	end
	if over ~= A.btnOver then
		A.btnOver = over
		A.btn:SetMouseInputEnabled(over)
	end
end)

