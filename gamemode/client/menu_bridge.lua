ME = ME or {}
ME.MenuActive = true

local wakeStart, wakeDur = nil, 1.7
function ME.StartWakeFade(dur)
	wakeDur   = math.max(0.1, tonumber(dur) or 1.7)
	wakeStart = RealTime()
end

local function easeOutCubic(x) return 1 - math.pow(1 - x, 3) end

hook.Add("HUDPaint", "ME_WakeFade", function()
	if not wakeStart then return end
	local f = (RealTime() - wakeStart) / wakeDur
	if f >= 1 then wakeStart = nil return end
	local a = math.floor((1 - easeOutCubic(f)) * 255)
	if a <= 0 then return end
	surface.SetDrawColor(0, 0, 0, a)
	surface.DrawRect(0, 0, ScrW(), ScrH())
end)

local T_OUT, T_HOLD, T_IN = 0.5, 1.1, 0.9
local trT, trCB, trFired

function ME.TransitionToLobby(cb)
	if trT then return end
	trT, trCB, trFired = RealTime(), cb, false
end

hook.Add("PostRenderVGUI", "ME_LobbyTransition", function()
	if not trT then return end
	local t = RealTime() - trT
	local a
	if t < T_OUT then                          a = t / T_OUT
	elseif t < T_OUT + T_HOLD then             a = 1
	elseif t < T_OUT + T_HOLD + T_IN then      a = 1 - (t - T_OUT - T_HOLD) / T_IN
	else trT = nil return end

	if not trFired and t >= T_OUT then
		trFired = true
		local cb = trCB; trCB = nil
		if cb then cb() end
	end

	surface.SetDrawColor(0, 0, 0, math.floor(math.Clamp(a, 0, 1) * 255))
	surface.DrawRect(0, 0, ScrW(), ScrH())
end)

local function enterMatch()
	if not ME.MenuActive then return end
	if MEMenu and MEMenu.Finish then MEMenu.Finish() end
	ME.MenuActive = false
	ME.MatchOver = nil
end

hook.Add("MEMenu_MapClick", "ME_PlayClicked", function() timer.Simple(0.9, enterMatch) end)
hook.Add("MEMenu_MapStart", "ME_PlayStart",   function() enterMatch() end)

hook.Add("MEMenu_GetActiveMatches", "ME_ActiveCount", function()
    return GetGlobalInt("ME_ActiveMatches", 0)
end)
