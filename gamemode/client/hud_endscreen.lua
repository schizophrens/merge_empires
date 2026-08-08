ME = ME or {}

ME.EndData = ME.EndData or nil

local blurMat = Material("pp/blurscreen")
local function paintBlur(w, h, frac, tint)
	frac = math.Clamp(frac or 1, 0, 1)
	if frac <= 0.001 then return end
	surface.SetMaterial(blurMat)
	surface.SetDrawColor(255, 255, 255, math.floor(255 * frac))
	for i = 1, 4 do
		blurMat:SetFloat("$blur", i * 0.55 * frac)
		blurMat:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(0, 0, w, h)
	end
	surface.SetDrawColor(tint.r, tint.g, tint.b, math.floor(tint.a * frac))
	surface.DrawRect(0, 0, w, h)
end

local function comma(n)
	n = tostring(math.floor(tonumber(n) or 0))
	local out = n:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function clock(sec)
	sec = math.max(0, math.floor(tonumber(sec) or 0))
	return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

local function esc(s)
	return tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

local function css(c) return string.format("rgb(%d,%d,%d)", c.r, c.g, c.b) end

local avatars = {}
local function fetchAvatar(sid, panel)
	if not sid or sid == "" then return end
	if avatars[sid] then
		if IsValid(panel) then panel:RunJavascript(("setAvatar('%s','%s')"):format(sid, avatars[sid])) end
		return
	end
	if avatars[sid] == false then return end
	avatars[sid] = false
	http.Fetch("https://steamcommunity.com/profiles/" .. sid .. "?xml=1", function(body)
		local a = body:match("<avatarFull><!%[CDATA%[(.-)%]%]></avatarFull>") or body:match("<avatarFull>(.-)</avatarFull>")
		if a and a ~= "" then
			avatars[sid] = a
			if IsValid(panel) then panel:RunJavascript(("setAvatar('%s','%s')"):format(sid, a)) end
		else
			avatars[sid] = nil
		end
	end, function() avatars[sid] = nil end)
end

local function rowsHTML(data)
	local out, you = {}, data.you or -1
	for _, r in ipairs(data.rows or {}) do
		local col  = ME.FactionColor and ME.FactionColor(r.faction) or Color(200, 200, 200)
		local mine = (r.faction == you)

		local rank = math.Clamp(tonumber(r.rank) or 0, 0, 10)
		local badge = string.format("asset://garrysmod/materials/mergeempires/rank/badge_%02d.png", rank)
		out[#out + 1] = table.concat({
			'<div class="row', mine and ' me' or '', '">',
				'<div class="c-rank"><img class="badge" src="', badge, '" alt=""></div>',
				'<div class="c-name">',
					'<div class="av" id="av_', esc(r.sid), '" style="border-color:', css(col), '"></div>',
					'<span>', esc(r.name), '</span>',
				'</div>',
				'<div class="c-num">', comma(r.kills),  '</div>',
				'<div class="c-num">', comma(r.damage), '</div>',
				'<div class="c-num">', comma(r.income), '</div>',
			'</div>',
		})
	end
	return table.concat(out)
end

local function buildHTML(data)
	local win = data.kind == "victory"
	local title    = win and "VICTORY" or "DEFEAT"
	local hot      = win and "#5cc8ff" or "#ff5142"
	local glowA    = win and "80,190,255" or "255,60,46"
	local glowB    = win and "30,130,235" or "242,26,16"

	local btnMain      = win and "#2f86e0" or "#ff4e4e"
	local btnMainHover = win and "#4a9bef" or "#ff6a6a"
	local btnLabel     = "CONTINUE"

	local spectate = ""
	if (not win) and data.canSpectate then
		spectate = '<div class="btn spec" onclick="meend.spec()">SPECTATE</div>'
	end

	return table.concat({
[==[<!doctype html><html><head><meta charset="utf-8">
<script>
// defined up front, and we tell Lua when the DOM is ready, so avatar pushes can never race the page
var __avq = {};
function setAvatar(sid,url){
  var e=document.getElementById('av_'+sid);
  if(e){e.style.backgroundImage="url('"+url+"')"}else{__avq[sid]=url}
}
window.addEventListener('DOMContentLoaded',function(){
  for(var s in __avq)setAvatar(s,__avq[s]);
  try{meend.ready()}catch(e){}
});
</script>
<style>
html,body{margin:0;height:100%;width:100%;overflow:hidden;background:transparent;user-select:none;
  font-family:'EinaSemiBold','Segoe UI',sans-serif}
body{display:flex;flex-direction:column;align-items:center;justify-content:center;
  opacity:0;animation:inn .6s cubic-bezier(.4,0,.2,1) forwards}
@keyframes inn{from{opacity:0;transform:translateY(14px)}to{opacity:1;transform:none}}
.title{font-family:'EinaSemiBold','Arial Black','Segoe UI',sans-serif;font-size:150px;font-weight:900;
  letter-spacing:6px;line-height:1;margin:0;color:]==], hot, [==[;
  text-shadow:0 0 20px rgba(]==], glowA, [==[,1),0 0 50px rgba(]==], glowA, [==[,.95),
    0 0 100px rgba(]==], glowB, [==[,.85),0 0 160px rgba(]==], glowB, [==[,.6),0 8px 16px rgba(0,0,0,.7)}
.sub{margin:12px 0 26px;font-size:21px;letter-spacing:1px;color:#b9bec6;font-weight:400}
.sub b{color:#e8eaed;font-weight:400}

/* neon gradient frame glowing in from every edge */
.frame{position:fixed;top:0;left:0;right:0;bottom:0;pointer-events:none;z-index:0;
  background:
    linear-gradient(to right, rgba(]==], glowA, [==[,.30), rgba(]==], glowA, [==[,0) 20%,
                              rgba(]==], glowA, [==[,0) 80%, rgba(]==], glowA, [==[,.30)),
    linear-gradient(to bottom, rgba(]==], glowA, [==[,.26), rgba(]==], glowA, [==[,0) 16%,
                               rgba(]==], glowA, [==[,0) 84%, rgba(]==], glowA, [==[,.26));
  box-shadow:inset 0 0 210px 45px rgba(]==], glowB, [==[,.30), inset 0 0 70px 8px rgba(]==], glowA, [==[,.22);
  animation:breathe 4.5s ease-in-out infinite}
@keyframes breathe{0%,100%{opacity:.8}50%{opacity:1}}
.wrap{position:relative;z-index:1;display:flex;flex-direction:column;align-items:center}

/* transparent board. Header and rows share the SAME padding and column widths, so every label sits
   exactly above its values. */
.board{width:1040px;max-width:94vw}
.head{display:flex;align-items:center;height:34px;padding:0 16px;font-size:14px;letter-spacing:2px;color:#9aa0a8}
.row{display:flex;align-items:center;height:60px;padding:0 16px;background:rgba(255,255,255,.035);
  border-bottom:1px solid rgba(255,255,255,.07)}
.row:nth-child(even){background:rgba(255,255,255,.06)}
.row.me{background:rgba(255,210,63,.10)}
.row.me .c-name span{color:#ffd23f}
.c-rank,.h-rank{width:90px;flex:none;display:flex;align-items:center;justify-content:center}
.badge{width:40px;height:40px;object-fit:contain}
.c-name,.h-name{flex:1;min-width:0;display:flex;align-items:center;gap:14px}
.c-name span{font-size:22px;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.av{width:38px;height:38px;border-radius:50%;background:#2b2e36 center/cover no-repeat;
  border:3px solid #888;flex:none;box-shadow:0 2px 6px rgba(0,0,0,.5)}
.c-num,.h-num{width:180px;flex:none;text-align:center}
.c-num{font-size:21px;color:#e8eaed}

.btns{display:flex;flex-direction:column;align-items:center;gap:13px;margin-top:30px}
.btn{display:flex;align-items:center;justify-content:center;cursor:pointer;color:#fff;font-weight:700;
  text-transform:uppercase;border-radius:11px;transition:background .12s,transform .1s;
  box-shadow:inset 0 2px 0 rgba(255,255,255,.18),0 4px 12px rgba(0,0,0,.4)}
.btn:hover{transform:translateY(-1px)}
.btn:active{transform:translateY(1px)}
.main{width:300px;height:58px;font-size:23px;letter-spacing:2px;background:]==], btnMain, [==[}
.main:hover{background:]==], btnMainHover, [==[}
.spec{width:230px;height:50px;font-size:18px;letter-spacing:2px;background:#4a4d52;color:#eef0f3}
.spec:hover{background:#5a5e64}
</style></head><body>
<div class="frame"></div>
<div class="wrap">
  <div class="title">]==], title, [==[</div>
  <div class="sub"><b>]==], esc(data.map or "?"), [==[</b> &nbsp;&bull;&nbsp; ]==], esc(data.mode or "?"),
  [==[ &nbsp;&bull;&nbsp; ]==], clock(data.time), [==[</div>
  <div class="board">
    <div class="head"><div class="h-rank">RANK</div><div class="h-name"></div>
      <div class="h-num">KILLS</div><div class="h-num">DAMAGE</div><div class="h-num">INCOME</div></div>
    ]==], rowsHTML(data), [==[
  </div>
  <div class="btns">
    <div class="btn main" onclick="meend.main()">]==], btnLabel, [==[</div>
    ]==], spectate, [==[
  </div>
</div>
</body></html>]==],
	})
end

function ME.HideEndScreen()
	if IsValid(ME.EndPanel) then ME.EndPanel:Remove() end
	ME.EndPanel = nil
	if ME.InputLocked and ME.InputLocked() then ME.MatchOver = nil end
end

function ME.ShowEndScreen(data)
	if IsValid(ME.EndPanel) then return end
	data = data or ME.EndData or { kind = "defeat", rows = {}, canSpectate = false }
	local win = data.kind == "victory"

	ME.MatchOver = "defeat"
	ME.Cam.selected = {}

	local p = vgui.Create("DPanel")
	ME.EndPanel = p
	p:SetSize(ScrW(), ScrH()); p:SetPos(0, 0); p:MakePopup(); p:SetKeyboardInputEnabled(false)
	p._t0 = RealTime()
	local tint = win and { r = 6, g = 14, b = 26, a = 190 } or { r = 16, g = 7, b = 7, a = 180 }
	p.Paint = function(self, w, h) paintBlur(w, h, (RealTime() - (self._t0 or 0)) / 0.6, tint) end

	local html = vgui.Create("DHTML", p)
	html:Dock(FILL)
	html:SetKeyboardInputEnabled(false)
	html:SetHTML(buildHTML(data))

	local function leaveToLobby()
		if IsValid(html) then html:SetMouseInputEnabled(false) end
		local go = function()
			net.Start("ME_LeaveToLobby"); net.SendToServer()
			ME.MatchOver  = nil
			ME.MenuActive = true
			ME.Cam.selected = {}
			ME.HideEndScreen()
			ME.CloseCommander()
			if MEMenu and MEMenu.ReturnToLobby then MEMenu.ReturnToLobby() end
		end
		if ME.TransitionToLobby then ME.TransitionToLobby(go) else go() end
	end

	html:AddFunction("meend", "ready", function()
		p._htmlReady = true
		for _, r in ipairs(data.rows or {}) do fetchAvatar(r.sid, html) end
	end)

	html:AddFunction("meend", "main", leaveToLobby)
	html:AddFunction("meend", "spec", function()
		net.Start("ME_Spectate"); net.SendToServer()
		ME.MatchOver = "spectate"
		ME.Cam.selected = {}
		ME.HideEndScreen()
		ME.MatchOver = "spectate"
	end)

	timer.Simple(1, function()
		if IsValid(p) and not p._htmlReady and IsValid(html) then
			for _, r in ipairs(data.rows or {}) do fetchAvatar(r.sid, html) end
		end
	end)
end

function ME.ShowDefeat()

	if ME._coreWasLost then
		ME._coreWasLost = nil
		if ME.Sfx then ME.Sfx.Play2D("defeat") end
	end
	ME.ShowEndScreen()
end

net.Receive("ME_MatchEnd", function()
	local data = util.JSONToTable(net.ReadString() or "") or {}
	ME.EndData = data

	if data.kind == "victory" then
		if ME.Sfx then ME.Sfx.Play2D("victory") end
		ME.ShowEndScreen(data)
	end
end)
