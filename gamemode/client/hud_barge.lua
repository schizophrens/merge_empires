

ME = ME or {}
ME.Barge = ME.Barge or {}
local BG_ = ME.Barge
local S = ME.UI.Scale

local DISC_BG    = Color(84, 88, 94, 235)
local DISC_EMPTY = Color(38, 40, 45, 205)
local DISC_EDGE  = Color(0, 0, 0, 240)

local MSG_TIME = 3
local MSGS = {
	loading  = { "Troops boarding…",                     true  },
	noone    = { "No troops inside the pickup radius",   false },
	landed   = { "Troops ashore",                        true  },
	empty    = { "The hold is empty",                    false },
	notwater = { "The barge is not at sea",              false },
	nobeach  = { "Move alongside a beach to land",       false },
	walled   = { "That shore is walled off — break it open first", false },
	nospace  = { "No room left on that beach",           false },
}

local msgText, msgGood, msgUntil = nil, false, 0
net.Receive("ME_BargeMsg", function()
	local m = MSGS[net.ReadString()]
	if not m then return end
	msgText, msgGood, msgUntil = m[1], m[2], CurTime() + MSG_TIME
end)

function BG_.Selected()
	if not (ME.Cam and ME.Cam.selected and ME.Cargo) then return {} end
	local out = {}
	for _, u in ipairs(ME.Cam.selected) do
		if IsValid(u) and u.MEUnit then
			local c = ME.Cargo[u:EntIndex()]
			if c then out[#out + 1] = { ent = u, cargo = c } end
		end
	end
	return out
end

local function selectedLoad()
	local n, max = 0, 0
	for _, b in ipairs(BG_.Selected()) do n = n + b.cargo.n; max = max + b.cargo.max end
	return n, max
end

local function sendBarges(msg)
	local ids = {}
	for _, b in ipairs(BG_.Selected()) do ids[#ids + 1] = b.ent:EntIndex() end
	if #ids == 0 then return end
	net.Start(msg)
	net.WriteUInt(#ids, 9)
	for _, id in ipairs(ids) do net.WriteUInt(id, 16) end
	net.SendToServer()
end

local fWas, gWas = false, false
hook.Add("Think", "ME_BargeKeys", function()
	if not (ME.InGame and ME.InGame()) or ME.MatchOver then fWas, gWas = false, false return end
	local typing = (ME.Chat and ME.Chat.typing) or gui.IsConsoleVisible()
	local sel = BG_.Selected()
	local dh  = ME.Build and ME.Build.dhtml

	local f = input.IsKeyDown(KEY_F)
	if f and not fWas and not typing and #sel > 0 then
		if IsValid(dh) then dh:Call("if(window.flashChint)flashChint('f')") end
		sendBarges("ME_BargeLoad")
	end
	fWas = f

	local loaded = selectedLoad()
	local g = input.IsKeyDown(KEY_G)
	if g and not gWas and not typing and #sel > 0 and loaded > 0 then
		if IsValid(dh) then dh:Call("if(window.flashChint)flashChint('g')") end
		sendBarges("ME_BargeDrop")
	end
	gWas = g
end)

local lastF, lastG, lastLbl, lastMsg, lastPanel = nil, nil, nil, nil, nil

local function pushHints()
	local dh = ME.Build and ME.Build.dhtml

	if not IsValid(dh) or dh ~= lastPanel then
		lastF, lastG, lastLbl, lastMsg, lastPanel = nil, nil, nil, nil, IsValid(dh) and dh or nil
		if not IsValid(dh) then return end
	end

	local sel = BG_.Selected()
	local n, max = selectedLoad()
	local showF = #sel > 0
	local showG = showF and n > 0
	local lbl   = showF and ("Load troops  (" .. n .. "/" .. max .. ")") or ""

	if showF ~= lastF or showG ~= lastG or lbl ~= lastLbl then
		lastF, lastG, lastLbl = showF, showG, lbl
		dh:Call(string.format("if(window.setBargeHint)setBargeHint(%s,%s,%q)",
			showF and "true" or "false", showG and "true" or "false", lbl))
	end

	local msg = (msgText and CurTime() < msgUntil) and msgText or nil
	if msg ~= lastMsg then
		lastMsg = msg
		dh:Call(string.format("if(window.setBargeMsg)setBargeMsg(%s,%s)",
			msg and string.format("%q", msg) or "null", msgGood and "true" or "false"))
	end
end

hook.Add("Think", "ME_BargeHints", function()
	if not (ME.InGame and ME.InGame()) or ME.MatchOver then return end
	pushHints()
end)

local iconCache = {}
local function unitIcon(kind)
	if iconCache[kind] ~= nil then return iconCache[kind] or nil end
	local path = "mergeempires/build/unit_" .. kind .. ".png"
	local m = file.Exists(path, "DATA") and Material("../data/" .. path, "smooth mips") or false
	iconCache[kind] = m
	return m or nil
end

local function circlePoly(cx, cy, rad, seg)
	seg = seg or 20
	local p = {}
	for i = 0, seg do
		local a = (i / seg) * math.pi * 2
		p[#p + 1] = { x = cx + math.cos(a) * rad, y = cy + math.sin(a) * rad }
	end
	return p
end

local function disc(cx, cy, rad, col)
	draw.NoTexture()
	surface.SetDrawColor(DISC_EDGE)
	surface.DrawPoly(circlePoly(cx, cy, rad))
	surface.SetDrawColor(col)
	surface.DrawPoly(circlePoly(cx, cy, rad - math.max(1, rad * 0.09)))
end

local function discSize(rec)
	local p  = rec.model:GetPos()
	local a  = p:ToScreen()
	local b  = (p + Vector(0, 0, 40)):ToScreen()
	if not (a.visible or b.visible) then return nil end
	local px = math.abs(b.y - a.y)
	local cf = math.Clamp(2800 / ((ME.Cam and ME.Cam.dist) or 2800), 0.42, 1)
	return math.Clamp(px * 0.40, S(4), S(17)) * cf
end

hook.Add("HUDPaint", "ME_BargeCargo", function()
	if not (ME.InGame and ME.InGame()) or not ME.Cargo then return end
	if ME.HudOn and not ME.HudOn("minimap") then return end
	local myTeam = LocalPlayer():Team()
	local sel = {}
	for _, u in ipairs((ME.Cam and ME.Cam.selected) or {}) do if IsValid(u) then sel[u:EntIndex()] = true end end

	for idx, c in pairs(ME.Cargo) do
		local rec = ME.UnitModels and ME.UnitModels[idx]

		if c and IsValid(rec and rec.model) and rec.faction == myTeam and (c.n > 0 or sel[idx]) then
			local rad = discSize(rec)
			if rad then

				local top = rec.model:OBBMaxs().z or 40
				local s   = (rec.model:GetPos() + Vector(0, 0, top + 12)):ToScreen()
				if s.visible then
					local y     = s.y - S(16) - rad
					local shown = math.max(c.n, c.max)
					local gap   = rad * 2.16
					local x0    = s.x - (shown - 1) * gap * 0.5
					for i = 1, shown do
						local cx = x0 + (i - 1) * gap
						local kind = c.kinds and c.kinds[i]
						disc(cx, y, rad, kind and DISC_BG or DISC_EMPTY)
						local mat = kind and unitIcon(kind)
						if mat then
							local isz = rad * 1.62
							surface.SetMaterial(mat)
							surface.SetDrawColor(255, 255, 255, 255)
							surface.DrawTexturedRect(cx - isz / 2, y - isz / 2, isz, isz)
						end
					end
				end
			end
		end
	end
end)

local ZONE_R, ZONE_G, ZONE_B = 240, 214, 130

hook.Add("PostDrawTranslucentRenderables", "ME_BargeRing", function(_, sky)
	if sky or not (ME.InGame and ME.InGame()) then return end
	if not (ME.DrawHexCell and ME.BoardCells) then return end
	local pulse = 26 + math.floor(14 * math.abs(math.sin(RealTime() * 3)))
	local drawn = {}
	for _, b in ipairs(BG_.Selected()) do
		local rec = ME.UnitModels and ME.UnitModels[b.ent:EntIndex()]
		if IsValid(rec and rec.model) then
			local k = ME.GetUnitKind(rec.kind)
			local R = k.pickupHex or 2
			local bq, br = ME.WorldToHex(rec.model:GetPos())
			for dq = -R, R do
				for dr = math.max(-R, -dq - R), math.min(R, -dq + R) do
					local q, r = bq + dq, br + dr
					local key  = ME.HexKey(q, r)
					local cell = ME.BoardCells[key]
					if cell and cell.biome == "sand" and not drawn[key] then
						drawn[key] = true
						ME.DrawHexCell(q, r, ZONE_R, ZONE_G, ZONE_B, pulse, 165)
					end
				end
			end
		end
	end
end)
