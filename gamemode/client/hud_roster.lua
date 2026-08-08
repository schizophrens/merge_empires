ME = ME or {}
ME.RosterData = ME.RosterData or {}
ME.RosterSlotRects = ME.RosterSlotRects or {}

local MAT_RING = Material("mergeempires/game/players/ring.png", "smooth mips")
local MAT_DISC = Material("mergeempires/game/players/disc.png", "smooth mips")
local DISCONNECT_ICON = Material("mergeempires/game/me_disconnected_light_red.png", "smooth")
local SPECTATE_ICON   = Material("mergeempires/game/me_spectate.png", "smooth")

local SLOT      = 80
local BORDER    = 2
local AV_MARGIN = 5
local GAP       = 6
local TOPY      = 82
local SEG       = 64

local function circlePoly(cx, cy, r)
	local p = {}
	for i = 0, SEG - 1 do
		local a = (i / SEG) * math.pi * 2
		p[#p + 1] = { x = cx + math.cos(a) * r, y = cy + math.sin(a) * r }
	end
	return p
end

local PANEL = {}

function PANEL:Init()
	self.connected = true
	self.faction   = 1
	self.Avatar    = vgui.Create("AvatarImage", self)
	self.Avatar:SetPaintedManually(true)
end

function PANEL:PerformLayout()
	local m = ME.UI.Scale(AV_MARGIN)
	local d = self:GetWide() - m * 2
	self.Avatar:SetPos(m, m)
	self.Avatar:SetSize(d, d)
end

function PANEL:SetFaction(f) self.faction = f end
function PANEL:SetConnected(b) self.connected = b and true or false end
function PANEL:SetSpectating(b) self.spectating = b and true or false end
function PANEL:SetSID(sid) if sid and sid ~= "" then self.Avatar:SetSteamID(sid, 64) end end

function PANEL:MoveTo2(tx, ty)
	self.tx, self.ty = tx, ty
	if not self.posInit then self.posInit = true self:SetPos(tx, ty) end
end
function PANEL:Think()
	if not self.tx then return end
	local x, y = self:GetPos()
	if math.abs(x - self.tx) < 0.5 and math.abs(y - self.ty) < 0.5 then
		self:SetPos(self.tx, self.ty)
		return
	end
	local f = math.min(1, FrameTime() * 12)
	self:SetPos(x + (self.tx - x) * f, y + (self.ty - y) * f)
end

function PANEL:Paint(w, h)
	local cx, cy = w / 2, h / 2
	local m      = ME.UI.Scale(AV_MARGIN)
	local clipR  = w / 2 - m
	local inner  = w - m * 2

	if not self.connected then
		surface.SetMaterial(MAT_DISC)
		surface.SetDrawColor(28, 30, 36, 255)
		surface.DrawTexturedRect(m, m, inner, inner)
		local isz = clipR * 1.2
		surface.SetMaterial(DISCONNECT_ICON)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(cx - isz / 2, cy - isz / 2, isz, isz)
		return
	end

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
	surface.DrawPoly(circlePoly(cx, cy, clipR))
	render.OverrideColorWriteEnable(false)

	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.SetStencilPassOperation(STENCIL_KEEP)
	self.Avatar:PaintManual()
	render.SetStencilEnable(false)
end

function PANEL:PaintOver(w, h)
	local col = ME.FactionColor(self.faction)

	surface.SetMaterial(MAT_RING)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawTexturedRect(0, 0, w, h)

	local bd = ME.UI.Scale(BORDER)
	surface.SetDrawColor(col.r, col.g, col.b, 255)
	surface.DrawTexturedRect(bd, bd, w - bd * 2, h - bd * 2)

	if self.spectating then
		surface.SetDrawColor(0, 0, 0, 150)
		surface.SetMaterial(MAT_DISC)
		surface.DrawTexturedRect(bd, bd, w - bd * 2, h - bd * 2)
		local isz = (w - bd * 2) * 0.54
		surface.SetMaterial(SPECTATE_ICON)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(math.Round(w / 2 - isz / 2), math.Round(h / 2 - isz / 2), isz, isz)
	end
end

vgui.Register("MERosterSlot", PANEL, "DPanel")

local container
local slots = {}
local lastMatchOver

local function maxFactions() return (ME.Config and ME.Config.MaxFactions) or 6 end

local function layout()
	if not IsValid(container) then return end

	for fac, s in pairs(slots) do
		if not ME.RosterData[fac] then
			if IsValid(s) then s:Remove() end
			slots[fac] = nil
		end
	end

	local order, added = {}, {}
	for i = 1, maxFactions() do
		if ME.RosterData[i] and not added[i] then
			order[#order + 1] = i; added[i] = true
			local a = ME.RosterData[i].ally
			if a and a > 0 and ME.RosterData[a] and not added[a] then
				order[#order + 1] = a; added[a] = true
			end
		end
	end
	local n = #order
	ME.RosterSlotRects = {}
	if n == 0 then return end

	local slot = ME.UI.Scale(SLOT)
	local gap  = ME.UI.Scale(GAP)
	local topy = ME.UI.Scale(TOPY)
	local totalW = n * slot + (n - 1) * gap
	local x0     = math.floor((ScrW() - totalW) / 2)

	for idx, fac in ipairs(order) do
		local s = slots[fac]
		if not IsValid(s) then
			s = vgui.Create("MERosterSlot", container)
			s:SetFaction(fac)
			slots[fac] = s
		end
		s:SetSize(slot, slot)
		local d = ME.RosterData[fac]
		local conn, spec = d.connected, d.spectating

		if ME.MatchOver == "spectate" and ME.MyFaction == fac then conn, spec = true, true end
		s:SetConnected(conn)
		s:SetSpectating(spec)
		if conn then s:SetSID(d.sid) end
		local px = x0 + (idx - 1) * (slot + gap)
		s:MoveTo2(px, topy)
		ME.RosterSlotRects[fac] = { x = px, y = topy, w = slot, h = slot, idx = idx }
	end
end

function ME.RosterSlotAt(mx, my)
	for fac, r in pairs(ME.RosterSlotRects or {}) do
		if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then return fac end
	end
end

net.Receive("ME_Roster", function()
	local n = net.ReadUInt(4)
	local data = {}
	for i = 1, n do
		if net.ReadBool() then
			local sid      = net.ReadString()
			local name     = net.ReadString()
			local conn     = net.ReadBool()
			local ally     = net.ReadUInt(3)
			local breaking = net.ReadBool()
			local rank     = net.ReadUInt(3)
			local ping     = net.ReadUInt(11)
			local spec     = net.ReadBool()
			local kills    = net.ReadUInt(12)
			local damage   = net.ReadUInt(24)
			data[i] = { sid = sid, name = name, connected = conn, ally = ally, breaking = breaking, rank = rank, ping = ping, spectating = spec,
			            kills = kills, damage = damage }
		end
	end
	ME.RosterData = data
	layout()
end)

hook.Add("Think", "ME_RosterEnsure", function()

	local on = ME.HudOn and ME.HudOn("roster")
		and ((ME.MatchOver == "spectate") or (ME.InGame and ME.InGame()))
	if on then
		if not IsValid(container) then
			container = vgui.Create("DPanel")
			container:SetSize(ScrW(), ScrH())
			container:SetPos(0, 0)
			container:SetPaintBackground(false)
			container:SetMouseInputEnabled(false)
			container:SetKeyboardInputEnabled(false)
			slots = {}
			layout()
		end

		if ME.MatchOver ~= lastMatchOver then
			lastMatchOver = ME.MatchOver
			layout()
		end
	elseif IsValid(container) then
		container:Remove()
		container = nil
		slots = {}
	end
end)

hook.Add("OnScreenSizeChanged", "ME_RosterRescale", function()
	if IsValid(container) then
		container:SetSize(ScrW(), ScrH())
		layout()
	end
end)
