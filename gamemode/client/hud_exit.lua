ME = ME or {}

local panel

local HTML = [==[
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
@font-face{font-family:'EinaSemiBold';src:url('asset://garrysmod/materials/mergeempires/fonts/Eina-03-SemiBold.otf') format('opentype')}
*{margin:0;padding:0;box-sizing:border-box;-webkit-user-select:none;user-select:none}
html{zoom:__ZOOM__}
html,body{width:100%;height:100%;background:transparent;overflow:hidden;color:#fff;font-family:'EinaSemiBold','Segoe UI',sans-serif;display:flex;align-items:center;justify-content:center;opacity:0;animation:fin .2s ease forwards}
@keyframes fin{to{opacity:1}}
#dlg{width:474px;background:#393939;border-radius:14px;box-shadow:0 20px 55px rgba(0,0,0,.6);overflow:hidden;padding-bottom:26px}
#bar{height:66px;display:flex;align-items:center;justify-content:center;position:relative}
.tt{font-weight:800;font-size:27px;letter-spacing:.5px}
#x{position:absolute;top:13px;right:13px;width:44px;height:44px;border-radius:10px;background:#ff4e4e;display:flex;align-items:center;justify-content:center;cursor:pointer;transition:background .12s,transform .1s}
#x:hover{background:#ff6a6a;transform:translateY(-1px)}
#x line{stroke:#fff;stroke-width:3;stroke-linecap:round}
#bd{margin:0 18px;background:#2e2e2e;border-radius:10px;padding:24px 22px}
#note{background:#ff8018;border-radius:10px;padding:22px 18px;text-align:center}
.nh{font-weight:800;font-size:31px;letter-spacing:.5px;margin-bottom:9px}
.nd{font-weight:700;font-size:17px;line-height:1.32}
#sure{text-align:center;font-weight:700;font-size:17px;letter-spacing:1px;color:#d6d6d6;margin:26px 0 14px}
#exit{width:202px;height:58px;margin:0 auto;border-radius:11px;background:#ff4e4e;display:flex;align-items:center;justify-content:center;cursor:pointer;box-shadow:inset 0 2px 0 rgba(255,255,255,.18),0 4px 12px rgba(0,0,0,.4);transition:background .12s,transform .1s}
#exit:hover{background:#ff6a6a;transform:translateY(-1px)}
#exit span{font-weight:800;font-size:25px;letter-spacing:.5px}
</style></head><body>
<div id="dlg">
  <div id="bar"><span class="tt">EXIT TO MENU</span><div id="x"><svg width="22" height="22" viewBox="0 0 24 24"><line x1="5" y1="5" x2="19" y2="19"/><line x1="19" y1="5" x2="5" y2="19"/></svg></div></div>
  <div id="bd">
    <div id="note"><div class="nh">NOTE</div><div class="nd">Match progress may be lost if you disconnect!</div></div>
    <div id="sure">ARE YOU SURE?</div>
    <div id="exit"><span>EXIT</span></div>
  </div>
</div>
<script>
window.onload=function(){
  document.getElementById('x').onclick=function(){exitc.cancel();};
  document.getElementById('exit').onclick=function(){exitc.confirm();};
  document.addEventListener('keydown',function(e){if(e.key==='Escape')exitc.cancel();});
};
</script></body></html>
]==]

local function buildHTML()
	local zoom = string.format("%.4f", ScrH() / 1080)
	return (HTML:gsub("__ZOOM__", function() return zoom end))
end

local function removePanel()
	if IsValid(panel) then panel:Remove() end
	panel = nil
end

function ME.CloseExitConfirm()
	local p = panel
	if not IsValid(p) then return end
	if p.closing then return end
	p.closing = true
	p.closeAt = SysTime()
	if IsValid(p.html) then
		p.html:RunJavascript("document.body.style.animation='none';document.body.style.transition='opacity .18s';document.body.style.opacity=0;")
	end
	timer.Simple(0.2, removePanel)
end

function ME.OpenExitConfirm()
	if IsValid(panel) then return end

	local p = vgui.Create("EditablePanel")
	p:SetSize(ScrW(), ScrH())
	p:SetPos(0, 0)
	p:MakePopup()
	p.openAt = SysTime()
	p.Paint = function(self, w, h)
		Derma_DrawBackgroundBlur(self, self.openAt)
		local f
		if self.closing then
			f = math.Clamp(1 - (SysTime() - self.closeAt) / 0.18, 0, 1)
		else
			f = math.Clamp((SysTime() - self.openAt) / 0.18, 0, 1)
		end
		surface.SetDrawColor(8, 10, 14, 180 * f)
		surface.DrawRect(0, 0, w, h)
	end
	p.OnKeyCodePressed = function(_, key)
		if key == KEY_ESCAPE then ME.CloseExitConfirm() return true end
	end

	local html = vgui.Create("DHTML", p)
	html:Dock(FILL)
	html:SetAllowLua(false)
	html:AddFunction("exitc", "cancel", function() ME.CloseExitConfirm() end)

	html:AddFunction("exitc", "confirm", function()
		ME.CloseExitConfirm()
		local go = function()
			net.Start("ME_LeaveToLobby"); net.SendToServer()
			ME.MatchOver  = nil
			ME.MenuActive = true
			if ME.Cam then ME.Cam.selected = {} end
			if ME.HideEndScreen then ME.HideEndScreen() end
			if ME.CloseCommander then ME.CloseCommander() end
			if MEMenu and MEMenu.ReturnToLobby then MEMenu.ReturnToLobby() end
		end
		if ME.TransitionToLobby then ME.TransitionToLobby(go) else go() end
	end)
	html:SetHTML(buildHTML())
	p.html = html

	panel = p
end

hook.Add("Think", "ME_ExitConfirmAutoClose", function()

	if IsValid(panel) and not ((ME.InGame and ME.InGame()) or ME.MatchOver == "spectate") then removePanel() end
end)
