ME = ME or {}
ME.Chat = ME.Chat or {}
local C = ME.Chat

local dhtml
local lastMsg = 0
C.typing = false

local HTML = [==[
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
@font-face{font-family:'BarlowLight';src:url('asset://garrysmod/materials/mergeempires/fonts/Barlow-Light.ttf') format('truetype')}
@font-face{font-family:'EinaSemiBold';src:url('asset://garrysmod/materials/mergeempires/fonts/Eina-03-SemiBold.otf') format('opentype')}
*{margin:0;padding:0;box-sizing:border-box}
html{zoom:__ZOOM__}
html,body{width:100%;height:100%;background:transparent;overflow:hidden}
#mmChat{position:fixed;left:20px;top:50%;transform:translateY(-50%);width:370px;display:flex;flex-direction:column;gap:0;pointer-events:auto;opacity:1;transition:opacity .35s ease}
#mmChat.cRaise{transform:translateY(calc(-50% - 44px))}   /* lifted a touch when the X-Stop hint is up */
#mmChat.cFaded{opacity:.30}
#mmChat.cFaded .chatInput{background:rgba(22,22,22,.35);border-color:rgba(255,255,255,.06)}
.chatLog{height:300px;overflow:hidden;display:flex;flex-direction:column;padding:0 4px 8px;background:transparent}
.chatLog>*:first-child{margin-top:auto}
.chatLine{font-family:'BarlowLight','Segoe UI',sans-serif;font-weight:300;font-size:16px;line-height:18px;margin-bottom:3px;color:rgba(222,224,228,.96);text-shadow:0 1px 2px rgba(0,0,0,.9),0 0 3px rgba(0,0,0,.6);word-wrap:break-word}
.chatLine.chMsg{display:flex;align-items:center;gap:8px;margin-bottom:5px}
.chAvatar{flex:0 0 24px;width:24px;height:24px;border-radius:4px;background:#2b2e36 center/cover no-repeat;box-shadow:0 1px 3px rgba(0,0,0,.6)}
.chBody{flex:1;min-width:0}
.chUser{font-family:'EinaSemiBold','Segoe UI',sans-serif;color:#dcdfe4}
.chSys{font-family:'EinaSemiBold','Segoe UI',sans-serif;color:rgba(205,207,210,.95)}
.chJoin{color:rgba(195,200,205,.85)}
.chatInput{height:30px;width:100%;padding:0 8px;background:rgba(22,22,22,.7);border:1px solid rgba(255,255,255,.12);border-radius:4px;font-family:'BarlowLight','Segoe UI',sans-serif;font-weight:300;font-size:16px;color:#e6e8ec;letter-spacing:.3px;outline:none}
.chatInput::placeholder{color:rgba(200,200,200,.6)}
.chatInput:focus{border-color:rgba(255,255,255,.25)}
.chatInput:focus::placeholder{color:transparent}
</style></head><body>
<div id="mmChat">
  <div class="chatLog" id="chatLog"></div>
  <input class="chatInput" id="chatInput" placeholder="Press ENTER to type..." maxlength="50" spellcheck="false">
</div>
<script>
function $(id){return document.getElementById(id)}
function esc(s){return (s+'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')}
function fire(ev,data){try{if(ev==='ChatSend')mechat.send(data);else if(ev==='ChatOpen')mechat.open();else if(ev==='ChatClose')mechat.close();}catch(e){}}
function chatScroll(){var l=$('chatLog');if(l)l.scrollTop=l.scrollHeight}
function chatAdd(html,cls){var l=$('chatLog');if(!l)return;var d=document.createElement('div');d.className='chatLine'+(cls?(' '+cls):'');d.innerHTML=html;l.appendChild(d);while(l.children.length>60)l.removeChild(l.firstChild);chatScroll();}
function chatSystem(t){chatAdd('<span class="chSys">[System]:</span> '+esc(t))}
function chatTeamMsg(t,color){chatAdd('<span class="chSys" style="color:'+(color||'#cdcfd2')+'">'+esc(t)+'</span>')}
function chatJoin(n){chatAdd('<span class="chJoin">'+esc(n)+' connected.</span>')}
function chatSetAvatar(sid,url){if(!sid||!url)return;var els=document.querySelectorAll('.chAvatar[data-sid="'+sid+'"]');for(var i=0;i<els.length;i++)els[i].style.backgroundImage="url('"+url+"')";}
function chatMessage(name,text,color,sid,avatar){var body='<span class="chBody"><span class="chUser" style="color:'+(color||'#dcdfe4')+'">'+esc(name)+'</span><span class="chSys">:</span> '+esc(text)+'</span>';chatAdd('<div class="chAvatar" data-sid="'+esc(sid||'')+'"></div>'+body,'chMsg');if(avatar)chatSetAvatar(sid,avatar);}
var ci=$('chatInput');
function chatSubmit(){if(!ci)return;var v=ci.value.replace(/^\s+|\s+$/g,'');if(v)fire('ChatSend',v);ci.value='';ci.blur();}
if(ci){
  ci.onfocus=function(){fire('ChatOpen');var c=$('mmChat');if(c)c.classList.add('cActive');chatScroll();};
  ci.onblur=function(){fire('ChatClose');var c=$('mmChat');if(c)c.classList.remove('cActive');};
  ci.onkeydown=function(e){if(!e)return;if(e.keyCode===13){if(e.preventDefault)e.preventDefault();chatSubmit();}else if(e.keyCode===27){ci.value='';ci.blur();}};
}
</script></body></html>
]==]

local function maxFac() return (ME.Config and ME.Config.MaxFactions) or 6 end
local function canChat()
	if ME.MatchOver == "spectate" then return true end
	if ME.MatchOver then return false end
	if not (ME.InGame and ME.InGame()) then return false end
	local t = LocalPlayer():Team()
	return t >= 1 and t <= maxFac()
end

local function jsq(s)
	s = tostring(s or ""):gsub("\\", "\\\\"):gsub("'", "\\'"):gsub("[\r\n]", " ")
	return "'" .. s .. "'"
end

local avatars = {}
local function fetchAvatar(sid)
	if not sid or sid == "" or avatars[sid] ~= nil then return end
	avatars[sid] = false
	http.Fetch("https://steamcommunity.com/profiles/" .. sid .. "?xml=1", function(body)
		local a = body:match("<avatarFull><!%[CDATA%[(.-)%]%]></avatarFull>") or body:match("<avatarFull>(.-)</avatarFull>")
		if a and a ~= "" then
			avatars[sid] = a
			if IsValid(dhtml) then dhtml:RunJavascript("chatSetAvatar(" .. jsq(sid) .. "," .. jsq(a) .. ")") end
		end
	end, function() avatars[sid] = nil end)
end

local function deactivate()
	C.typing = false
	if not IsValid(dhtml) then return end
	dhtml:RunJavascript("var e=document.getElementById('chatInput');if(e){e.value='';e.blur();}var c=document.getElementById('mmChat');if(c)c.classList.remove('cActive');")
	dhtml:SetMouseInputEnabled(false)
	dhtml:SetKeyboardInputEnabled(false)
	dhtml:KillFocus()
end

function C.SetUIHidden(hidden)
	if not IsValid(dhtml) then return end
	if hidden then
		if C.typing and C.Close then C.Close() end
		dhtml:SetMouseInputEnabled(false)
		dhtml:SetKeyboardInputEnabled(false)
		dhtml:KillFocus()
		dhtml:SetVisible(false)
	end
	C._uiHidden = hidden and true or false
end

local function activate()
	if C.typing or not canChat() or not IsValid(dhtml) then return end
	C.typing = true
	dhtml:SetVisible(true)
	dhtml:SetMouseInputEnabled(true)
	dhtml:SetKeyboardInputEnabled(true)
	dhtml:MakePopup()
	dhtml:RequestFocus()
	dhtml:RunJavascript("var e=document.getElementById('chatInput');if(e){e.focus();}")
end
C.Open = activate

local function buildHTML()
	return (HTML:gsub("__ZOOM__", function() return string.format("%.4f", ScrH() / 1080) end))
end

local function ensurePanel()
	if IsValid(dhtml) then return end
	dhtml = vgui.Create("DHTML")
	dhtml:SetSize(math.ceil(492 * (ScrH() / 1080)), ScrH())
	dhtml:SetPos(0, 0)
	dhtml:SetMouseInputEnabled(false)
	dhtml:SetKeyboardInputEnabled(false)
	dhtml:SetAllowLua(false)
	dhtml:AddFunction("mechat", "send", function(text)
		text = tostring(text or "")
		if text ~= "" then
			net.Start("ME_Chat")
			net.WriteString(string.sub(text, 1, (MEConfig.Chat and MEConfig.Chat.MaxLength) or 50))
			net.SendToServer()
		end
	end)
	dhtml:AddFunction("mechat", "open", function() end)
	dhtml:AddFunction("mechat", "close", function() deactivate() end)
	dhtml:SetHTML(buildHTML())
end

local function removePanel()
	if IsValid(dhtml) then dhtml:Remove() end
	dhtml = nil
	C.typing = false
end

function C.OnMessage(ply, text)
	if not IsValid(ply) or not (ME.InGame and ME.InGame()) then return end
	if not IsValid(dhtml) then return end
	lastMsg = CurTime()
	local name = ply:Nick() or "Player"
	local sid  = (isfunction(ply.SteamID64) and ply:SteamID64()) or ""
	local c    = ME.FactionColor(ply:Team())
	local col  = c and string.format("#%02x%02x%02x", c.r, c.g, c.b) or "#dcdfe4"
	local av   = (sid ~= "" and avatars[sid]) or ""
	dhtml:RunJavascript("chatMessage(" .. jsq(name) .. "," .. jsq(text) .. "," .. jsq(col) .. "," .. jsq(sid) .. "," .. jsq(av) .. ")")
	if sid ~= "" then fetchAvatar(sid) end
end

function C.OnSystem(text, r, g, b)
	if not (ME.InGame and ME.InGame()) or not IsValid(dhtml) then return end
	lastMsg = CurTime()
	local col = string.format("#%02x%02x%02x", r or 210, g or 214, b or 220)
	dhtml:RunJavascript("chatTeamMsg(" .. jsq(text) .. "," .. jsq(col) .. ")")
end

function C.ClickBar(mx, my)
	if C.typing or not canChat() then return false end

	local z = ScrH() / 1080
	local x, y, w, h = 20 * z, 668 * z, 370 * z, 44 * z
	if mx >= x and mx <= x + w and my >= y and my <= y + h then activate() return true end
	return false
end

hook.Add("PlayerBindPress", "ME_BlockDefaultChat", function(_, bind, pressed)
	if bind == "messagemode" or bind == "messagemode2" then
		if pressed and canChat() then activate() end
		return true
	end
end)
hook.Add("HUDShouldDraw", "ME_HideDefaultChat", function(name)
	if name == "CHudChat" then return false end
end)

local joinKnown, joinPrimed = {}, false
hook.Add("Think", "ME_ChatJoinWatch", function()
	if not (ME.InGame and ME.InGame()) or not IsValid(dhtml) then
		joinKnown, joinPrimed = {}, false
		return
	end
	local mySid = IsValid(LocalPlayer()) and LocalPlayer():SteamID64() or ""
	for fac, e in pairs(ME.RosterData or {}) do
		if e.connected and not joinKnown[fac] then
			joinKnown[fac] = true
			if joinPrimed and e.sid ~= mySid then
				lastMsg = CurTime()
				dhtml:RunJavascript("chatJoin(" .. jsq(e.name or "Player") .. ")")
			end
		elseif not e.connected and joinKnown[fac] then
			joinKnown[fac] = nil
		end
	end
	joinPrimed = true
end)

local enterWas = false
hook.Add("Think", "ME_IngameChatEnter", function()
	if C._uiHidden then return end
	if canChat() then
		ensurePanel()
		if IsValid(dhtml) then

			if ME.Build and ME.Build.IsPlacing and ME.Build.IsPlacing() and not C.typing then
				dhtml:SetVisible(false)
				C._chatFull = nil
				return
			end
			dhtml:SetVisible(true)
			local raise = (ME.Cam and ME.Cam.xStopShown) and true or false
			if raise ~= C._raised then
				C._raised = raise
				dhtml:RunJavascript("var c=document.getElementById('mmChat');if(c)c.classList.toggle('cRaise'," .. (raise and "true" or "false") .. ")")
			end
			local mx, my = gui.MousePos()
			local z = ScrH() / 1080
			local hover = mx >= 20 * z and mx <= 450 * z and my >= ScrH() / 2 - 175 * z and my <= ScrH() / 2 + 175 * z
			local full  = C.typing or (CurTime() - lastMsg) < 5 or hover
			if full ~= C._chatFull then
				C._chatFull = full
				dhtml:RunJavascript("var c=document.getElementById('mmChat');if(c)c.classList.toggle('cFaded'," .. (full and "false" or "true") .. ")")
			end
		end
		local down = input.IsKeyDown(KEY_ENTER) or input.IsKeyDown(KEY_PAD_ENTER)
		if down and not enterWas and not C.typing and not gui.IsConsoleVisible() then activate() end
		enterWas = down
	else
		removePanel()
		enterWas = false
	end
end)
