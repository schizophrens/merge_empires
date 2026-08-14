ME = ME or {}
ME.Build = ME.Build or {}
ME.BuildingModels = ME.BuildingModels or {}
local B = ME.Build
local S = ME.UI.Scale

local function localTeam()
	local lp = LocalPlayer()
	return IsValid(lp) and lp:Team() or -1
end

local COMBAT_LULL = 6
local function combatPing(sFac, vFac)
	local myTeam = localTeam()
	if myTeam ~= sFac and myTeam ~= vFac then return end
	local now = RealTime()
	if (now - (ME._lastCombat or -999)) > COMBAT_LULL then
		if B.ShowCombat then B.ShowCombat() end
		ME.Sfx.Play2D("combat_alert")
	end
	ME._lastCombat = now
end

function ME.FitScale(cm, isEdge)
	if not IsValid(cm) then return 1 end
	local mins, maxs = cm:GetModelRenderBounds()
	local horiz = math.max(math.abs(maxs.x - mins.x), math.abs(maxs.y - mins.y))
	if horiz <= 1 then return 1 end
	if isEdge then

		return ((ME.Config and ME.Config.HexSize) or 96) / horiz
	end
	local target = ((ME.Config and ME.Config.HexSize) or 96) * 1.3
	return math.Clamp(target / horiz, 0.35, 1.25)
end

net.Receive("ME_BuildingSync", function()
	local idx   = net.ReadUInt(16)
	local bid   = net.ReadString()
	local model = net.ReadString()
	local pos   = net.ReadVector()
	local ang   = net.ReadAngle()
	local built = net.ReadBool()
	local fac   = net.ReadInt(8)
	local prog  = net.ReadFloat()
	local bnear = net.ReadBool()

	local b = ME.GetBuilding and ME.GetBuilding(bid)
	if not b or not b.model then return end
	if model == "" then model = b.model end

	local rec = ME.BuildingModels[idx]
	if not rec or not IsValid(rec.model) or rec.bid ~= bid or rec.mdl ~= model then
		if rec and IsValid(rec.model) then rec.model:Remove() end
		local cm = ClientsideModel(model, RENDERGROUP_OTHER)
		if not IsValid(cm) then return end
		cm:SetNoDraw(true)
		local isEdge = ME.IsEdgeBuilding(bid)
		cm:SetModelScale(ME.FitScale(cm, isEdge) * (isEdge and 1 or (b.fitMul or 1)), 0)
		rec = { model = cm, bid = bid, mdl = model, centerB = b.center, fresh = true }
		ME.BuildingModels[idx] = rec
		if not built and fac == localTeam() and RealTime() > (ME.SfxGraceUntil or 0) then
			ME.Sfx.Play("build_place", pos)
		end
	end
	rec.model:SetPos(pos)

	if not (rec.bid == "turret" and rec._aimAt) then rec.model:SetAngles(ang) end

	if rec.centerB then
		if rec.centerShift == nil then
			local mins, maxs = rec.model:GetModelRenderBounds()
			local lc = Vector((mins.x + maxs.x) * 0.5, (mins.y + maxs.y) * 0.5, 0) * rec.model:GetModelScale()
			rec.centerShift = pos - rec.model:LocalToWorld(lc); rec.centerShift.z = 0
		end
		rec.model:SetPos(pos + rec.centerShift)
	end

	if bid == "naval_mine" and built then
		if not rec._sink then
			local mins, maxs = rec.model:GetModelRenderBounds()
			local sc = rec.model:GetModelScale(); if not sc or sc == 0 then sc = 1 end
			rec._sink = math.max(4, (maxs.z - mins.z) * sc * 0.5)
		end
		rec.model:SetPos(rec.model:GetPos() - Vector(0, 0, rec._sink))
	end
	rec.model:SetupBones()

	if built and not rec.built and not rec.fresh then rec._builtAt = RealTime() end

	if built and bid == "naval_mine" and (rec.fresh or rec._hideFade) then
		rec._hideFade, rec._revealAt = nil, RealTime()
	end
	rec.fresh = nil
	rec.built = built
	rec.faction = fac
	rec.progress = prog
	rec.builderNear = bnear
end)

local FIGHT_BIDS = { turret = true, missile = true }

net.Receive("ME_BuildingHP", function()
	local idx = net.ReadUInt(16)
	local hp  = net.ReadInt(32)
	local rec = ME.BuildingModels and ME.BuildingModels[idx]
	if rec then

		if rec.hp and hp < rec.hp then
			rec._hitAt = RealTime()

			if FIGHT_BIDS[rec.bid] then ME.MarkFight("b" .. idx) end
		end
		rec.hp = hp
	end
end)

ME.CoreHP = ME.CoreHP or {}
net.Receive("ME_CoreHP", function()
	local fac = net.ReadInt(8)
	local hp  = net.ReadInt(32)
	local mx  = net.ReadInt(32)
	ME.CoreHP[fac] = { hp = hp, mx = mx }
end)

net.Receive("ME_BuildingRemove", function()
	local idx       = net.ReadUInt(16)
	local destroyed = net.ReadBool()
	local pos       = net.ReadVector()
	local rec = ME.BuildingModels[idx]

	local canFade = destroyed and rec and rec.built and IsValid(rec.model)
	                and rec.bid ~= "naval_mine" and rec.bid ~= "at_mine"

	if not destroyed and rec and rec.bid == "naval_mine" and rec.built and IsValid(rec.model) then
		rec._hideFade = rec._hideFade or RealTime()
		return
	end
	if canFade then
		rec._destroyFade = RealTime()
	else
		if rec and IsValid(rec.model) then rec.model:Remove() end
		ME.BuildingModels[idx] = nil
	end
	if ME.Cam and ME.Cam.inspect and ME.Cam.inspect.idx == idx then ME.Cam.inspect = nil end
	if destroyed then
		ME.Sfx.Play("build_destroyed", pos)
		if ME.ShakeAt then ME.ShakeAt(pos, 12, 0.55, 3000) end
	elseif rec and rec.built ~= nil then
		ME.Sfx.Play("build_sold", pos)
	end
end)

net.Receive("ME_BuildingSfx", function()
	local kind = net.ReadUInt(2)
	local pos  = net.ReadVector()

	if RealTime() <= (ME.SfxGraceUntil or 0) or GetGlobalInt("ME_MatchPhase", 0) < 2 then return end
	if kind == 1 then
		ME.Sfx.Play("build_start", pos)
	elseif kind == 2 then
		ME.Sfx.Play("build_finished", pos)
	end
end)

local DENY_MSG = {
	occupied   = "Something is already there",
	money      = "Not enough money",
	max        = "You've reached the limit for this building",
	tile       = "Can't be built on this tile",
	shore      = "Harbors go on water right next to the shore",
	harbor_rot = "Rotate the harbor to face the beach",
	harbor_walled = "That beach is walled off — the harbor would have no way in",
	harbor_dock = "That is a harbor's dock — sealing it would strand the harbor",
	relief     = "The higher tile owns this edge — build it from up there",
}
net.Receive("ME_PlaceDenied", function()
	if ME.Sfx then ME.Sfx.Play2D("build_denied") end
	local reason = net.ReadString()
	B.denyMsg = DENY_MSG[reason] or "Can't build here"
	B.denyAt  = RealTime()
end)

net.Receive("ME_PurchaseSfx", function()

	sound.PlayFile("sound/mergeempires/menu/purchase_building.mp3", "noplay noblock", function(chan)
		if IsValid(chan) then chan:SetVolume(0.7) chan:Play() end
	end)
end)

function ME.EdgeBuildingAt(worldpos)
	if not (ME.BuildingModels and worldpos) then return nil end

	local best, bestD = nil, (((ME.Config and ME.Config.HexSize) or 96) * 0.34) ^ 2
	for idx, rec in pairs(ME.BuildingModels) do
		if IsValid(rec.model) and ME.IsEdgeBuilding(rec.bid) then
			local d = rec.model:GetPos():DistToSqr(worldpos)
			if d < bestD then bestD, best = d, idx end
		end
	end
	return best
end

function ME.BuildingAtHex(q, r)
	if not ME.BuildingModels then return nil end
	for idx, rec in pairs(ME.BuildingModels) do
		if IsValid(rec.model) and not (ME.IsEdgeBuilding and ME.IsEdgeBuilding(rec.bid)) then
			local mq, mr = ME.WorldToHex(rec.model:GetPos())
			if mq == q and mr == r then return idx, rec end
		end
	end
	return nil
end

local function requestBuildings()
	net.Start("ME_BuildingReq")
	net.SendToServer()
end
hook.Add("InitPostEntity", "ME_BuildingReqSync", requestBuildings)
timer.Simple(2, requestBuildings)

hook.Add("Think", "ME_GateDoors", function()
	if not ME.BuildingModels then return end
	local ft = FrameTime()
	local OPEN_R = ((ME.Config and ME.Config.HexSize) or 96) * 1.2
	for _, rec in pairs(ME.BuildingModels) do
		if rec.bid == "gate" and IsValid(rec.model) then
			if rec._doorBG == nil then rec._doorBG = rec.model:FindBodygroupByName("door") end
			if rec._doorBG and rec._doorBG >= 0 then
				if not rec.built then
					if rec._doorOpen ~= false then
						rec._doorOpen = false
						rec.model:SetBodygroup(rec._doorBG, 0)
					end
				else
					rec._gT = (rec._gT or 0) - ft
					if rec._gT <= 0 then
						rec._gT = 0.15
						local open, gp, gf = false, rec.model:GetPos(), rec.faction or 0
						for _, u in pairs(ME.UnitModels or {}) do
							if IsValid(u.model) and (u.faction or 0) == gf and gp:DistToSqr(u.model:GetPos()) < OPEN_R * OPEN_R then
								open = true break
							end
						end
						if open ~= rec._doorOpen then
							rec._doorOpen = open
							rec.model:SetBodygroup(rec._doorBG, open and 1 or 0)
						end
					end
				end
			end
		end
	end
end)

ME.UnitModels = ME.UnitModels or {}

for _, rec in pairs(ME.UnitModels) do rec.animSeq, rec._wasMoving = nil, nil end

local function unitSeq(cm, moving, aset)
	local names = {}
	if aset then
		names = moving and { aset .. "_run", aset .. "_walk" } or { aset .. "_idle" }
	end
	local base = moving and { "run_all", "walk_all", "walk_all_01", "cwalk_all", "walk", "walkfast", "run" }
	                     or  { "idle_all_01", "idle_all", "idle_subtle", "menu_walk", "idle" }
	for _, nm in ipairs(base) do names[#names + 1] = nm end
	for _, nm in ipairs(names) do local s = cm:LookupSequence(nm); if s and s >= 0 then return s end end
	local acts = moving and { ACT_HL2MP_RUN, ACT_RUN, ACT_HL2MP_WALK, ACT_WALK }
	                     or  { ACT_HL2MP_IDLE, ACT_IDLE }
	for _, a in ipairs(acts) do
		if a then local s = cm:SelectWeightedSequence(a); if s and s >= 0 then return s end end
	end

	local subs = moving and { "run", "walk", "move" } or { "idle", "stand", "aim" }
	local count = cm.GetSequenceCount and cm:GetSequenceCount() or 0
	for i = 1, count - 1 do
		local nm = (cm:GetSequenceName(i) or ""):lower()
		for _, sub in ipairs(subs) do if nm:find(sub, 1, true) then return i end end
	end
	return count > 1 and 1 or 0
end

function ME.HandPose(model)
	if not IsValid(model) then return nil end

	for _, an in ipairs({ "anim_attachment_RH", "RHand", "righthand", "hand_R" }) do
		local a = model:LookupAttachment(an)
		if a and a > 0 then local at = model:GetAttachment(a); if at and at.Pos then return at.Pos, at.Ang end end
	end

	for _, bn in ipairs({ "ValveBiped.Bip01_R_Hand", "Bip01 R Hand", "Bip001 R Hand", "R_hand_container" }) do
		local b = model:LookupBone(bn)
		if b then local bp, ba = model:GetBonePosition(b); if bp and bp ~= model:GetPos() then return bp, ba end end
	end

	local n = model.GetBoneCount and model:GetBoneCount() or 0
	for i = 0, n - 1 do
		local bn = (model:GetBoneName(i) or ""):lower()
		if bn:find("hand") and (bn:find("right") or bn:find("%f[%a]r%f[%A]")) then
			local bp, ba = model:GetBonePosition(i)
			if bp and bp ~= model:GetPos() then return bp, ba end
		end
	end
	return nil
end

function ME.TurretPose(model)
	if not IsValid(model) then return nil end
	for _, an in ipairs({ "muzzle", "turret", "barrel", "cannon", "gun", "launcher" }) do
		local a = model:LookupAttachment(an)
		if a and a > 0 then local at = model:GetAttachment(a); if at and at.Pos then return at.Pos, at.Ang end end
	end
	local n = model.GetBoneCount and model:GetBoneCount() or 0
	for i = 0, n - 1 do
		local bn = (model:GetBoneName(i) or ""):lower()
		if bn:find("turret") or bn:find("barrel") or bn:find("cannon") or bn:find("launch") or bn:find("gun") then
			local bp, ba = model:GetBonePosition(i)
			if bp and bp ~= model:GetPos() then return bp, Angle(0, model:GetAngles().yaw, 0) end
		end
	end

	local mins, maxs = model:GetModelRenderBounds()
	local sc = model:GetModelScale(); if not sc or sc == 0 then sc = 1 end
	local ang = model:GetAngles()
	local top = model:GetPos() + Vector(0, 0, maxs.z * sc * 0.82)
	return top + ang:Forward() * (maxs.x * sc * 0.45), ang
end

ME.VehTurret = {
	tank        = { turret = "Turret", barrel = "Barrel", yawSlot = "y", yawSign = 1, pitchSlot = "r", pitchSign = -1 },
	apc         = { turret = "Turret", yawSlot = "y", yawSign = 1 },
	humvee      = { turret = "Turret", yawSlot = "y", yawSign = 1 },
	missiletank = { turret = "Turret", yawSlot = "y", yawSign = 1, pitchSlot = "p", pitchSign = 1 },
}
local function applySlot(a, slot, val) if slot == "p" then a.p = val elseif slot == "r" then a.r = val else a.y = val end end

function ME.AimTurret(model, kind, targetPos, pitchUp)
	local cfg = ME.VehTurret and ME.VehTurret[kind]
	if not (cfg and IsValid(model) and targetPos) then return end
	local bone = model:LookupBone(cfg.turret)
	if not bone then return end
	local dir = targetPos - model:GetPos(); dir.z = 0
	if dir:LengthSqr() < 1 then return end
	local delta = math.NormalizeAngle(dir:Angle().yaw - model:GetAngles().yaw) * (cfg.yawSign or 1)
	local a = Angle(0, 0, 0)
	applySlot(a, cfg.yawSlot or "y", delta)
	model:ManipulateBoneAngles(bone, a)
	if pitchUp then
		local pb = cfg.barrel and model:LookupBone(cfg.barrel) or bone
		if pb then local pa = Angle(0, 0, 0); applySlot(pa, cfg.pitchSlot or "p", 58 * (cfg.pitchSign or 1)); model:ManipulateBoneAngles(pb, pa) end
	end
end

function ME.ResetTurret(model, kind)
	local cfg = ME.VehTurret and ME.VehTurret[kind]
	if not (cfg and IsValid(model)) then return end
	local b = model:LookupBone(cfg.turret); if b then model:ManipulateBoneAngles(b, angle_zero) end
	if cfg.barrel then local bb = model:LookupBone(cfg.barrel); if bb then model:ManipulateBoneAngles(bb, angle_zero) end end
end

ME.TurretAim = false

net.Receive("ME_UnitSync", function()
	local idx    = net.ReadUInt(16)
	local kind   = net.ReadString()
	local model  = net.ReadString()
	local fac    = net.ReadInt(8)
	local sc     = net.ReadFloat()
	local pos    = net.ReadVector()
	local ang    = net.ReadAngle()
	local moving = net.ReadBool()
	local bidx   = net.ReadUInt(16)
	local blocked = net.ReadBool()
	local stowed = net.ReadBool()
	local hidden = net.ReadBool()
	local k      = ME.GetUnitKind and ME.GetUnitKind(kind)
	if not (k and k.model) then return end
	if model == "" then model = ME.UnitModel(kind) end

	if stowed then
		local old = ME.UnitModels[idx]
		if old then
			if IsValid(old.model) then old.model:Remove() end
			if IsValid(old.wep) then old.wep:Remove() end
			ME.UnitModels[idx] = nil
		end
		return
	end

	pos = pos + Vector(0, 0, 11)

	local rec = ME.UnitModels[idx]
	if not rec or not IsValid(rec.model) or rec.kind ~= kind or rec.mdl ~= model then

		if not rec and fac == localTeam() and RealTime() > (ME.SfxGraceUntil or 0) then
			ME.Sfx.Play("unit_ready", pos)
		end
		if rec and IsValid(rec.model) then rec.model:Remove() end
		if rec and IsValid(rec.wep) then rec.wep:Remove() end
		local cm = ClientsideModel(model, RENDERGROUP_OTHER)
		if not IsValid(cm) then return end
		cm:SetNoDraw(true)
		if sc ~= 1 then cm:SetModelScale(sc, 0) end
		cm:SetPos(pos); cm:SetAngles(ang)
		rec = { model = cm, kind = kind, mdl = model, vehicle = k.vehicle, boat = k.boat, sub = k.submerge, moving = nil }

		if k.weapon then
			local wep = ClientsideModel(k.weapon, RENDERGROUP_OTHER)
			if IsValid(wep) then wep:SetNoDraw(true); if sc ~= 1 then wep:SetModelScale(sc, 0) end; rec.wep = wep end
		end
		ME.UnitModels[idx] = rec
	end
	rec.faction   = fac
	rec.blocked   = blocked
	rec.hidden    = hidden
	rec.buildIdx  = bidx
	rec.targetPos = pos
	if rec.animSeq ~= "fire" then rec.targetAng = ang end
	rec.moving = moving
	if not rec.wep and not rec.vehicle and rec._wasMoving ~= moving then
		rec._wasMoving = moving
		rec.model:SetSequence(unitSeq(rec.model, moving)); rec.model:SetCycle(0); rec.model:SetPlaybackRate(1)
	end

end)

hook.Add("Think", "ME_UnitAnim", function()
	if not ME.UnitModels then return end
	local ft = FrameTime()
	local t  = math.min(1, ft * 12)
	for _, rec in pairs(ME.UnitModels) do
		if IsValid(rec.model) then
			if rec.wep then

				local aset = (ME.GetUnitKind and ME.GetUnitKind(rec.kind).animset) or nil
				local firing = rec._fireT and (RealTime() - rec._fireT) < 0.4
				local want = firing and "fire" or (rec.moving and "move" or "idle")
				if want ~= rec.animSeq then
					rec.animSeq = want
					local s
					if want == "move" then
						s = unitSeq(rec.model, true, aset)
					elseif want == "fire" then

						local tries = {}
						if aset then tries = { aset .. "_shoot_loop", aset .. "_shoot" } end
						for _, nm in ipairs({ "shoot", "fire", "aim" }) do tries[#tries + 1] = nm end
						for _, nm in ipairs(tries) do
							local q = rec.model:LookupSequence(nm); if q and q >= 0 then s = q; break end
						end
						if not s or s < 0 then s = unitSeq(rec.model, false, aset) end
					else

						s = rec.model:LookupSequence("aim")
						if not s or s < 0 then s = unitSeq(rec.model, false, aset) end
					end
					if s and s >= 0 then rec.model:SetSequence(s); rec.model:SetCycle(0); rec.model:SetPlaybackRate(1) end
				end
				if firing and rec._aimAt then
					if rec.model:GetCycle() >= 0.98 then rec.model:SetCycle(0) end
					local dir = rec._aimAt - rec.model:GetPos(); dir.z = 0
					if dir:LengthSqr() > 1 then
						local k = ME.GetUnitKind and ME.GetUnitKind(rec.kind)
						rec.targetAng = Angle(0, dir:Angle().yaw + ((k and k.yaw) or 0), 0)
					end
				end
			elseif rec.vehicle then

				local arting = rec._artUntil and RealTime() < rec._artUntil
				local want   = arting and "turret" or "idle"
				if want ~= rec.animSeq then
					rec.animSeq = want
					local s = rec.model:LookupSequence(want)
					if not s or s < 0 then s = rec.model:LookupSequence("idle") end
					if s and s >= 0 then rec.model:SetSequence(s); rec.model:SetCycle(0); rec.model:SetPlaybackRate(1) end
				end

				if ME.TurretAim and arting and rec._aimAt then
					if ME.AimTurret then ME.AimTurret(rec.model, rec.kind, rec._aimAt, true) end
					rec._turretOn = true
				elseif rec._turretOn then
					if ME.ResetTurret then ME.ResetTurret(rec.model, rec.kind) end
					rec._turretOn = false
				end
			end
			if rec.targetPos then
				if rec.vehicle and not rec.boat then

					rec._smoothPos = LerpVector(t, rec._smoothPos or rec.targetPos, rec.targetPos)
					local amp = rec.moving and 0.8 or 0.45
					local rt  = RealTime() * (rec.moving and 52 or 38) + (rec.model:EntIndex() % 128) * 0.4
					local jit = Vector(math.sin(rt) * amp * 0.4, math.cos(rt * 1.13) * amp * 0.4, (0.5 + 0.5 * math.sin(rt * 1.9)) * amp)
					rec.model:SetPos(rec._smoothPos + jit)
				else
					rec.model:SetPos(LerpVector(t, rec.model:GetPos(), rec.targetPos))
				end
			end
			if rec.targetAng then rec.model:SetAngles(LerpAngle(t, rec.model:GetAngles(), rec.targetAng)) end
			rec.model:FrameAdvance(ft)
		end
	end
end)

ME.FX     = ME.FX or {}
ME.Graves = ME.Graves or {}
net.Receive("ME_Fire", function()
	local idx    = net.ReadUInt(16)
	local tpos   = net.ReadVector()
	local splash = net.ReadBool()
	local sFac   = net.ReadInt(8)
	local vFac   = net.ReadInt(8)

	combatPing(sFac, vFac)
	ME.MarkFight("u" .. idx)
	local from
	local rec = ME.UnitModels and ME.UnitModels[idx]
	if rec and IsValid(rec.model) then
		if rec.vehicle then

			local d = tpos - rec.model:GetPos(); d.z = 0
			if d:LengthSqr() > 1 then
				local k = ME.GetUnitKind and ME.GetUnitKind(rec.kind)
				local a = Angle(0, d:Angle().yaw + ((k and k.yaw) or 0), 0)
				rec.model:SetAngles(a)
				rec.targetAng = a
			end
		end
		rec.model:SetupBones()
		if rec.vehicle then

			local tp = ME.TurretPose and ME.TurretPose(rec.model)
			from = (tp and tp + Vector(0, 0, 2)) or (rec.model:GetPos() + Vector(0, 0, 40))
		else
			local wp = ME.HandPose and ME.HandPose(rec.model)
			from = (wp and wp + Vector(0, 0, 2)) or (rec.model:GetPos() + Vector(0, 0, 40))
		end
		rec._aimAt = tpos
		rec._fireT = RealTime()
	else
		from = tpos + Vector(0, 0, 40)
	end

	local kind = splash and "rocket" or (rec and rec.vehicle and "vshot" or "shot")
	ME.FX[#ME.FX + 1] = { kind = kind, a = from, b = tpos + Vector(0, 0, 18), t0 = RealTime() }

	local ukind = rec and rec.kind
	ME.Sfx.Play(kind == "rocket" and "rocket_launch"
		or kind == "vshot" and "shot_cannon"
		or ukind == "sniper" and "shot_sniper"
		or ukind == "shotgunner" and "shot_shotgun"
		or "shot_rifle", from)

	if kind ~= "rocket" then ME.Sfx.Play("bullet_impact", tpos, { delay = 0.07 }) end

	if kind == "vshot" and ME.ShakeAt then ME.ShakeAt(from, 3.5, 0.16, 1500) end
end)

net.Receive("ME_Artillery", function()
	local idx  = net.ReadUInt(16)
	local tpos = net.ReadVector()
	local intIdx = net.ReadUInt(16)

	ME.MarkFight("u" .. idx)
	if intIdx > 0 then ME.MarkFight("b" .. intIdx) end
	local rec  = ME.UnitModels and ME.UnitModels[idx]
	if rec then rec._artUntil = RealTime() + 3.5; rec._aimAt = tpos end
	local function launchPos()
		if rec and IsValid(rec.model) then
			rec.model:SetupBones()
			local tp = ME.TurretPose and ME.TurretPose(rec.model)
			return (tp and tp + Vector(0, 0, 8)) or (rec.model:GetPos() + Vector(0, 0, 60))
		end
		return tpos + Vector(0, 0, 60)
	end

	local ifrom
	if intIdx > 0 then
		local irec = ME.BuildingModels and ME.BuildingModels[intIdx]
		ifrom = IsValid(irec and irec.model) and (irec.model:GetPos() + Vector(0, 0, 40)) or nil
	end

	for i = 1, 4 do
		timer.Simple(3.0 + i * 0.18, function()
			ME.FX = ME.FX or {}
			local from = launchPos()
			local jit  = Vector(math.Rand(-46, 46), math.Rand(-46, 46), 0)
			local to   = tpos + jit + Vector(0, 0, 16)
			local fx   = { kind = "artmissile", a = from, b = to, t0 = RealTime() }
			ME.Sfx.Play("artillery_fire", from)

			if intIdx > 0 and ME.ArtArc then
				local killAt  = ME.ArtKillU * ME.ArtFlight
				local killPos = ME.ArtArc(from, to, ME.ArtKillU)
				fx.killAt = killAt
				local a0 = ifrom or (killPos - Vector(0, 0, 260))
				timer.Simple(math.max(0, killAt - ME.IntFlight), function()
					ME.FX = ME.FX or {}
					ME.FX[#ME.FX + 1] = { kind = "interceptor", a = a0, b = killPos, t0 = RealTime() }
					ME.MarkFight("b" .. intIdx)
					ME.Sfx.Play("rocket_launch", a0)
				end)
			end
			ME.FX[#ME.FX + 1] = fx
		end)
	end
end)

local HIT_MIN, HIT_MAX = 30, 66
function ME.HitHeight(idx)
	local rec = (ME.UnitModels and ME.UnitModels[idx]) or (ME.BuildingModels and ME.BuildingModels[idx])
	local m   = rec and rec.model
	if not IsValid(m) then return HIT_MIN end
	local mx = m:OBBMaxs()
	local sc = m:GetModelScale(); if not sc or sc == 0 then sc = 1 end
	if not (mx and mx.z and mx.z > 0) then return HIT_MIN end
	return math.Clamp(mx.z * sc * 0.5, HIT_MIN, HIT_MAX)
end

net.Receive("ME_CoreBeam", function()
	local fac  = net.ReadInt(8)
	local from = net.ReadVector()
	local to   = net.ReadVector()
	local tgt  = net.ReadUInt(16)
	local vFac = net.ReadInt(8)

	local cm
	for _, m in ipairs(ME.CoreModels or {}) do if IsValid(m) and m.MEFaction == fac then cm = m break end end
	if IsValid(cm) then
		local sc = cm:GetModelScale(); if not sc or sc == 0 then sc = 1 end
		from = cm:GetPos() + Vector(0, 0, (cm:OBBMaxs().z or 90) * sc * 0.86)
	else
		from = from + Vector(0, 0, 90)
	end
	ME.FX = ME.FX or {}
	local rec
	for _, fx in ipairs(ME.FX) do if fx.kind == "corebeam" and fx.fac == fac then rec = fx break end end
	if not rec then
		rec = { kind = "corebeam", fac = fac, t0 = RealTime() }
		ME.FX[#ME.FX + 1] = rec
	end
	if tgt > 0 then
		combatPing(fac, vFac)
		ME.MarkFight("c" .. fac)

		if ME.Sfx and (rec.tgt or 0) == 0 then ME.Sfx.Play("core_beam_start", to) end
	end
	rec.a, rec.b, rec.tgt, rec.fadeAt = from, to + Vector(0, 0, ME.HitHeight(tgt)), tgt, nil

	rec.hold = tgt > 0 and (RealTime() + 0.8) or 0
end)

ME.HealFX = ME.HealFX or {}
net.Receive("ME_Heal", function()
	local idx = net.ReadUInt(16)
	local rec = ME.UnitModels and ME.UnitModels[idx]
	local pos = rec and IsValid(rec.model) and rec.model:GetPos()
	if not pos then local e = Entity(idx); pos = IsValid(e) and e:GetPos() end
	if pos then ME.Sfx.Play("heal_pulse", pos) end
	if not pos then return end
	ME.HealFX[#ME.HealFX + 1] = {
		pos = pos + Vector(math.Rand(-16, 16), math.Rand(-16, 16), 0),
		t0 = RealTime(), idx = idx,
	}
end)

local MAT_HEAL   = Material("mergeempires/game/me_heal.png", "smooth")
local HEAL_HASMAT = MAT_HEAL and not MAT_HEAL:IsError()
local HEAL_COL    = Color(86, 226, 122)
hook.Add("HUDPaint", "ME_HealIcons", function()
	if not ME.HealFX or #ME.HealFX == 0 then return end
	if not (ME.InGame and ME.InGame()) then return end
	local now = RealTime()
	for i = #ME.HealFX, 1, -1 do
		local h   = ME.HealFX[i]
		local age = now - h.t0
		local life = 1.0
		if age >= life then table.remove(ME.HealFX, i)
		else
			local f = age / life

			local rec = ME.UnitModels and ME.UnitModels[h.idx]
			local base = (rec and IsValid(rec.model) and rec.model:GetPos()) or h.pos
			local s = (base + Vector(0, 0, 46 + f * 46)):ToScreen()
			if s.visible then
				local cf = math.Clamp(2800 / ((ME.Cam and ME.Cam.dist) or 2800), 0.4, 1.0)
				local sz = S(20) * cf
				local a  = math.floor(255 * (1 - f) * (f < 0.15 and f / 0.15 or 1))
				if a > 3 then
					if HEAL_HASMAT then
						surface.SetMaterial(MAT_HEAL)
						surface.SetDrawColor(255, 255, 255, a)
						surface.DrawTexturedRect(s.x - sz / 2, s.y - sz / 2, sz, sz)
					else
						local t2 = math.max(2, sz * 0.3)
						surface.SetDrawColor(20, 60, 32, math.floor(a * 0.55))
						surface.DrawRect(s.x - sz / 2 - 1, s.y - t2 / 2 - 1, sz + 2, t2 + 2)
						surface.DrawRect(s.x - t2 / 2 - 1, s.y - sz / 2 - 1, t2 + 2, sz + 2)
						surface.SetDrawColor(HEAL_COL.r, HEAL_COL.g, HEAL_COL.b, a)
						surface.DrawRect(s.x - sz / 2, s.y - t2 / 2, sz, t2)
						surface.DrawRect(s.x - t2 / 2, s.y - sz / 2, t2, sz)
					end
				end
			end
		end
	end
end)

net.Receive("ME_TurretFire", function()
	local idx  = net.ReadUInt(16)
	local tpos = net.ReadVector()
	local sFac = net.ReadInt(8)
	local vFac = net.ReadInt(8)
	combatPing(sFac, vFac)
	ME.MarkFight("b" .. idx)
	local rec  = ME.BuildingModels and ME.BuildingModels[idx]
	ME.Sfx.Play("turret_fire", (rec and IsValid(rec.model) and rec.model:GetPos()) or tpos)
	local from
	if rec and IsValid(rec.model) then
		rec._aimAt, rec._fireT = tpos, RealTime()
		local sc = rec.model:GetModelScale(); if not sc or sc == 0 then sc = 1 end
		from = rec.model:GetPos() + Vector(0, 0, (rec.model:OBBMaxs().z or 40) * sc * 0.82)
	else
		from = tpos + Vector(0, 0, 60)
	end
	ME.FX = ME.FX or {}
	ME.FX[#ME.FX + 1] = { kind = "vshot", a = from, b = tpos + Vector(0, 0, 18), t0 = RealTime() }
end)

hook.Add("Think", "ME_TurretAim", function()
	if not ME.BuildingModels then return end
	local ft = math.min(1, FrameTime() * 6)
	for _, rec in pairs(ME.BuildingModels) do
		if rec.bid == "turret" and IsValid(rec.model) and rec._aimAt then
			local dir = rec._aimAt - rec.model:GetPos(); dir.z = 0
			if dir:LengthSqr() > 1 then
				local cur = rec.model:GetAngles()
				rec.model:SetAngles(LerpAngle(ft, cur, Angle(0, dir:Angle().yaw, 0)))
			end
		end
	end
end)

net.Receive("ME_MineBlast", function()
	local pos = net.ReadVector()
	ME.FX = ME.FX or {}
	ME.FX[#ME.FX + 1] = { kind = "vehicleblast", b = pos + Vector(0, 0, 14), t0 = RealTime() }
	if ME.ShakeAt then ME.ShakeAt(pos, 11, 0.4, 2400) end
	ME.Sfx.Play("mine_blast", pos)
end)

net.Receive("ME_CoreMeltdown", function()
	local pos = net.ReadVector()
	local fac = net.ReadInt(8)
	local dur = net.ReadFloat()

	local cm
	if fac and fac > 0 and ME.CoreModels then
		for _, m in ipairs(ME.CoreModels) do
			if IsValid(m) and m.MEFaction == fac then cm = m break end
		end
	end
	if IsValid(cm) then pos = cm:GetPos() end

	ME.Meltdown = { model = cm, base = Vector(pos.x, pos.y, pos.z), t0 = RealTime(), dur = dur or 3, nextPop = 0 }
end)

hook.Add("Think", "ME_CoreMeltdown", function()
	local md = ME.Meltdown
	if not md then return end

	local t = RealTime() - md.t0
	local f = math.Clamp(t / md.dur, 0, 1)
	if t >= md.dur then
		if IsValid(md.model) then md.model:SetPos(md.base) end
		ME.Meltdown = nil
		return
	end

	local amp = 1.5 + f * f * 13
	if IsValid(md.model) then
		md.model:SetPos(md.base + Vector(math.Rand(-amp, amp), math.Rand(-amp, amp), math.Rand(-amp, amp) * 0.5))
	end

	if ME.ShakeCam then ME.ShakeCam(1.5 + f * f * 11, 0.2) end

	if RealTime() >= md.nextPop then
		md.nextPop = RealTime() + math.Rand(0.10, 0.30) * (1 - f * 0.75)
		ME.FX = ME.FX or {}
		local a = math.Rand(0, math.pi * 2)
		local r = math.Rand(10, 70)
		ME.FX[#ME.FX + 1] = {
			kind = "corepop",
			b    = md.base + Vector(math.cos(a) * r, math.sin(a) * r, math.Rand(30, 150)),
			t0   = RealTime(),
			sz   = math.Rand(60, 140) * (0.6 + f),
		}
	end
end)

net.Receive("ME_CoreExplode", function()
	local pos = net.ReadVector()
	local fac = net.ReadInt(8)
	ME.Meltdown = nil

	if fac and fac > 0 and ME.CoreModels then
		for i = #ME.CoreModels, 1, -1 do
			local cm = ME.CoreModels[i]
			if IsValid(cm) and cm.MEFaction == fac then
				pos = cm:GetPos()
				cm:StopParticles()
				cm:Remove()
				table.remove(ME.CoreModels, i)
			end
		end
	end

	ME.FX = ME.FX or {}
	ME.FX[#ME.FX + 1] = { kind = "coreblast", b = pos, t0 = RealTime() }
	util.ScreenShake(pos, 22, 20, 1.8, 3200)
	if ME.ShakeCam then ME.ShakeCam(26, 1.1) end

	local dl = DynamicLight(0)
	if dl then
		dl.pos        = pos + Vector(0, 0, 90)
		dl.r, dl.g, dl.b = 255, 170, 70
		dl.brightness = 6
		dl.Decay      = 900
		dl.Size       = 1400
		dl.DieTime    = CurTime() + 1.3
	end
end)

function ME.IgniteModel(rec)
	if not (rec and IsValid(rec.model)) or rec._burnFX then return end
	rec._burnFX = true
	local cm, P = rec.model, ME.PFX
	if not P then return end

	local mins, maxs = cm:GetModelRenderBounds()
	local sc = cm:GetModelScale(); if not sc or sc == 0 then sc = 1 end
	local big = ((maxs.z - mins.z) * sc) > 90

	ParticleEffectAttach(big and P.fire_big or P.fire, PATTACH_ABSORIGIN_FOLLOW, cm, 0)
	ParticleEffectAttach(P.groundfire, PATTACH_ABSORIGIN_FOLLOW, cm, 0)
	ParticleEffectAttach(P.smoke,      PATTACH_ABSORIGIN_FOLLOW, cm, 0)
end

net.Receive("ME_CoreBurn", function()
	local idx = net.ReadUInt(16)
	local tries = 0
	timer.Create("ME_CoreBurnFX_" .. idx, 0.1, 12, function()
		tries = tries + 1
		local e, P = Entity(idx), ME.PFX
		if not P then timer.Remove("ME_CoreBurnFX_" .. idx) return end
		if IsValid(e) then
			timer.Remove("ME_CoreBurnFX_" .. idx)

			local fac = e.GetFaction and e:GetFaction() or nil
			if fac and ME.CoreModels then
				for _, cm in ipairs(ME.CoreModels) do
					if IsValid(cm) and cm.MEFaction == fac then cm.MEBurning = true end
				end
			end
		end
	end)
end)

net.Receive("ME_FactionWipe", function()
	local fac = net.ReadInt(8)
	if not ME.BuildingModels then return end
	local n = 0
	for _, rec in pairs(ME.BuildingModels) do
		if (rec.faction or 0) == fac and IsValid(rec.model) and not rec._burnStart then
			local at = RealTime() + n * 0.14
			rec._burnStart = at
			rec._burnDur   = 3.2
			local r = rec
			timer.Simple(n * 0.14, function() ME.IgniteModel(r) end)
			n = n + 1
		end
	end
end)

local GRAD_DOWN = Material("gui/gradient_down")
local GRAD_UP   = Material("gui/gradient_up")
local GRAD_SIDE = Material("gui/gradient")

hook.Add("HUDPaint", "ME_CombatAlert", function()
	if ME.MatchOver then return end
	if not (ME.InGame and ME.InGame()) then return end

	local last = ME._lastCombat
	if not last then return end
	local age = RealTime() - last
	local HOLD, FADE = 3.0, 1.6
	if age > HOLD + FADE then return end

	local a = (age <= HOLD) and 1 or (1 - (age - HOLD) / FADE)
	a = a * (0.72 + 0.28 * math.sin(RealTime() * 3))
	local alpha = math.floor(46 * math.Clamp(a, 0, 1))
	if alpha <= 1 then return end

	local w, h   = ScrW(), ScrH()
	local ew, eh = w * 0.15, h * 0.19
	surface.SetDrawColor(205, 32, 26, alpha)
	surface.SetMaterial(GRAD_DOWN); surface.DrawTexturedRect(0, 0, w, eh)
	surface.SetMaterial(GRAD_UP);   surface.DrawTexturedRect(0, h - eh, w, eh)
	surface.SetMaterial(GRAD_SIDE)
	surface.DrawTexturedRect(0, 0, ew, h)
	surface.DrawTexturedRectUV(w - ew, 0, ew, h, 1, 0, 0, 1)
end)

net.Receive("ME_UnitDied", function()
	local pos  = net.ReadVector()
	local kind = net.ReadString()
	local k    = ME.GetUnitKind and ME.GetUnitKind(kind)

	if k and k.vehicle then
		ME.FX = ME.FX or {}
		ME.FX[#ME.FX + 1] = { kind = "vehicleblast", b = pos + Vector(0, 0, 20), t0 = RealTime() }
		if ME.ShakeAt then ME.ShakeAt(pos, 8, 0.35, 2200) end
		ME.Sfx.Play("mine_blast", pos)
		return
	end
	ME.Sfx.Play("unit_death", pos)

	local g = ClientsideModel("models/tt_props/grave.mdl", RENDERGROUP_OTHER)
	if IsValid(g) then
		g:SetNoDraw(true)
		g:SetModelScale(0.7, 0)
		g:SetPos(pos)
		g:SetAngles(Angle(0, (pos.x + pos.y) % 360, 0))
		g:SetupBones()
		ME.Graves[#ME.Graves + 1] = { m = g, t0 = RealTime() }
	end
	ME.Skulls = ME.Skulls or {}
	ME.Skulls[#ME.Skulls + 1] = { pos = pos, t0 = RealTime() }
end)

local MAT_SKULL = Material("mergeempires/game/me_skull.png", "smooth")
hook.Add("HUDPaint", "ME_DeathSkulls", function()
	if not ME.Skulls or #ME.Skulls == 0 then return end
	if not (ME.InGame and ME.InGame()) then return end
	local now = RealTime()
	for i = #ME.Skulls, 1, -1 do
		local sk  = ME.Skulls[i]
		local age = now - sk.t0
		local life = 2.2
		if age >= life then table.remove(ME.Skulls, i)
		else
			local f    = age / life
			local rise = 24 + f * 52
			local s    = (sk.pos + Vector(0, 0, rise)):ToScreen()
			if s.visible then
				local cf = math.Clamp(2800 / ((ME.Cam and ME.Cam.dist) or 2800), 0.4, 1.0)
				local sz = S(24) * cf * (1 + f * 0.4)
				local a  = math.floor(255 * (1 - f) * (f < 0.12 and (f / 0.12) or 1))
				if a > 2 then
					surface.SetMaterial(MAT_SKULL)
					surface.SetDrawColor(0, 0, 0, math.floor(a * 0.5)); surface.DrawTexturedRect(s.x - sz / 2 + 1, s.y - sz / 2 + 1, sz, sz)
					surface.SetDrawColor(255, 255, 255, a);             surface.DrawTexturedRect(s.x - sz / 2,     s.y - sz / 2,     sz, sz)
				end
			end
		end
	end
end)

ME.Cargo = ME.Cargo or {}

net.Receive("ME_UnitRemove", function()
	local idx = net.ReadUInt(16)
	local rec = ME.UnitModels[idx]
	if rec and IsValid(rec.model) then rec.model:Remove() end
	if rec and IsValid(rec.wep) then rec.wep:Remove() end
	ME.UnitModels[idx] = nil
	ME.Cargo[idx] = nil
end)

net.Receive("ME_Cargo", function()
	local idx   = net.ReadUInt(16)
	local max   = net.ReadUInt(6)
	local n     = net.ReadUInt(6)
	local kinds = {}
	for i = 1, n do kinds[i] = net.ReadString() end
	ME.Cargo[idx] = { n = n, max = max, kinds = kinds }
end)

local function requestUnits()
	net.Start("ME_UnitReq")
	net.SendToServer()
end
hook.Add("InitPostEntity", "ME_UnitReqSync", requestUnits)
timer.Simple(2, requestUnits)

ME.UI.Font("ME_BuildWarn", { font = "Roboto", size = 21, weight = 900 })
ME.UI.Font("ME_BuildCount", { font = "Roboto", size = 18, weight = 700 })

local MAT_HG = Material("mergeempires/game/me_hourglass.png", "smooth")

local function tileAllows(rule, cell)
	if not cell then return false end
	if rule == "slot"    then return cell.decor == "slot" end
	if rule == "gold"    then return cell.decor == "gold" end
	if rule == "oilspot" then return cell.decor == "oilspot" end
	if rule == "water"   then return cell.biome == "water" end
	return cell.biome ~= "water" and cell.decor ~= "mountain" and cell.decor ~= "slot" and cell.decor ~= "gold"
end

local function cIsSand(q, r) local c = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]; return c and c.biome == "sand" end
local function harborShoreOK(q, r) for _, d in ipairs(ME.HexDirs or {}) do if cIsSand(q + d[1], r + d[2]) then return true end end return false end
local function harborRotOK(q, r, idx) local nq, nr = ME.FaceNeighbor(q, r, idx + 3); return cIsSand(nq, nr) end

local function harborDockEdge(q, r, idx)
	if not (ME.BuildingModels and ME.EdgePlacement) then return false end
	local mid = ME.EdgePlacement(q, r, idx, 0)
	for _, rec in pairs(ME.BuildingModels) do
		if IsValid(rec.model) and rec.bid == "harbor" then
			local hq, hr = ME.WorldToHex(rec.model:GetPos())
			local face   = math.floor(((rec.model:GetAngles().y % 360) + 30) / 60) % 6
			local dm     = ME.EdgePlacement(hq, hr, face + 3, 0)
			if math.abs(dm.x - mid.x) < 2 and math.abs(dm.y - mid.y) < 2 then return true end
		end
	end
	return false
end

local function harborEdgeWalled(q, r, idx)
	if not (ME.BuildingModels and ME.FaceDirs) then return false end
	local d   = ME.FaceDirs[idx % 6]
	local c   = ME.HexToWorld(q, r, 0)
	local nb  = ME.HexToWorld(q + d[1], r + d[2], 0)
	local mx, my = (c.x + nb.x) * 0.5, (c.y + nb.y) * 0.5
	local r2  = (((ME.Config and ME.Config.HexSize) or 96) * 0.4) ^ 2
	for _, rec in pairs(ME.BuildingModels) do
		if IsValid(rec.model) and ME.IsEdgeBuilding(rec.bid) then
			local p = rec.model:GetPos()
			local dx, dy = p.x - mx, p.y - my
			if dx * dx + dy * dy < r2 then return true end
		end
	end
	return false
end

local function harborNextRot(q, r, cur)
	local base = math.floor(((cur or 0) % 360) / 60)
	for step = 1, 6 do
		local idx = (base + step) % 6
		if harborRotOK(q, r, idx) and not harborEdgeWalled(q, r, idx + 3) then return idx * 60 end
	end
	for step = 1, 6 do local idx = (base + step) % 6; if harborRotOK(q, r, idx) then return idx * 60 end end
	return ((cur or 0) + 60) % 360
end

function ME.CellTier(q, r)
	local c    = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]
	local step = (ME.Config and ME.Config.TierStep) or 20
	local Hg   = (ME.Config and ME.Config.Heights and ME.Config.Heights.grass) or 0
	return math.Round(((ME.SurfaceOffset(q, r, c and c.biome or "grass") or 0) - Hg) / step)
end

function B.IsPlacing() return B.placing ~= nil end

function B.StartPlace(bld)
	if not bld then return end
	B.placing = bld
	B.rot = 0

	if IsValid(B.ghost) then B.ghost:Remove() end
	B.ghost = bld.model and ClientsideModel(bld.model) or nil
	if IsValid(B.ghost) then B.ghost:SetNoDraw(true); local ge = ME.IsEdgeBuilding(bld); B.ghost:SetModelScale(ME.FitScale(B.ghost, ge) * (ge and 1 or (bld.fitMul or 1)), 0) end
	if IsValid(B.dhtml) then B.dhtml:Call("if(window.setHints)setHints(true)") end
end

function B.StopPlace()
	B.placing = nil
	if IsValid(B.ghost) then B.ghost:Remove() end
	B.ghost = nil
	if IsValid(B.dhtml) then B.dhtml:Call("if(window.setHints)setHints(false)") end
end

function B.HintHold(id, on)
	if IsValid(B.dhtml) then B.dhtml:Call("if(window.holdHint)holdHint('" .. id .. "'," .. (on and "true" or "false") .. ")") end
end

local function updateGhost()
	local q, r, cpt
	if ME.HexAtCursor then q, r, cpt = ME.HexAtCursor() end
	if not (q and r) then
		local hit = ME.GroundUnderCursor and ME.GroundUnderCursor()
		if not hit then B.valid = false return end
		q, r = ME.WorldToHex(hit); cpt = hit
	end
	B.q, B.r = q, r

	if ME.IsEdgeBuilding(B.placing.id) and cpt then
		local c   = ME.HexToWorld(q, r, 0)
		local off = Vector(cpt.x - c.x, cpt.y - c.y, 0)
		if off:LengthSqr() > 1 then
			off:Normalize()
			local bestIdx, bestDot = 0, -2
			for idx = 0, 5 do
				local d  = ME.FaceDirs[idx]
				local wd = ME.HexToWorld(q + d[1], r + d[2], 0) - c; wd.z = 0; wd:Normalize()
				local dp = wd:Dot(off)
				if dp > bestDot then bestDot, bestIdx = dp, idx end
			end
			B.rot = bestIdx * 60
		end
	end
	local cell = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]
	B.valid = tileAllows(ME.BuildPlaceRule(B.placing), cell)
	B.harborBadRot, B.reliefBad, B.harborWalled, B.harborDock = false, false, false, false

	if B.valid and ME.IsEdgeBuilding(B.placing.id) then
		local side = math.floor((B.rot or 0) / 60)
		local nq, nr = ME.FaceNeighbor(q, r, side)
		if (ME.CellTier and ME.CellTier(nq, nr) or 0) > (ME.CellTier and ME.CellTier(q, r) or 0) then
			B.valid = false; B.reliefBad = true
		elseif harborDockEdge(q, r, side) then
			B.valid = false; B.harborDock = true
		end
	end
	if B.valid and B.placing.id == "harbor" then
		local back = math.floor((B.rot or 0) / 60) + 3
		if not harborShoreOK(q, r) then
			B.valid = false
		elseif not harborRotOK(q, r, math.floor((B.rot or 0) / 60)) then
			B.valid = false; B.harborBadRot = true
		elseif harborEdgeWalled(q, r, back) then
			B.valid = false; B.harborWalled = true
		end
	end

	local edge = ME.IsEdgeBuilding(B.placing.id)
	B.blocked = false
	local d = cell and cell.decor
	if d == "tree" or d == "palm" or d == "mountain" or d == "rock" then
		B.blocked = true
	elseif not edge and ME.BuildingAtHex and ME.BuildingAtHex(q, r) then
		B.blocked = true
	elseif not edge and ME.CoreModels then
		for _, cm in ipairs(ME.CoreModels) do
			if IsValid(cm) then
				local cq, cr = ME.WorldToHex(cm:GetPos())
				if cq == q and cr == r then B.blocked = true break end
			end
		end
	end
	if IsValid(B.ghost) then
		local z = ((ME.MapInfo and ME.MapInfo.baseZ) or 0) + (ME.SurfaceOffset(q, r, cell and cell.biome or "grass") or 0)
		if edge then
			local mid, yaw = ME.EdgePlacement(q, r, math.floor((B.rot or 0) / 60), z)
			B.ghost:SetPos(mid)
			B.ghost:SetAngles(Angle(0, yaw, 0))
		else
			local pos = ME.HexToWorld(q, r, z)
			if B.placing.id == "harbor" then
				local nq, nr = ME.FaceNeighbor(q, r, math.floor((B.rot or 0) / 60) + 3)
				local dir = ME.HexToWorld(nq, nr, z) - pos; dir.z = 0
				if dir:LengthSqr() > 1 then dir:Normalize(); pos = pos + dir * (((ME.Config and ME.Config.HexSize) or 96) * 0.45) end
			end
			B.ghost:SetPos(pos)
			B.ghost:SetAngles(Angle(0, B.rot or 0, 0))
			if B.placing and B.placing.center then
				local mins, maxs = B.ghost:GetModelRenderBounds()
				local lc = Vector((mins.x + maxs.x) * 0.5, (mins.y + maxs.y) * 0.5, 0) * B.ghost:GetModelScale()
				local shift = pos - B.ghost:LocalToWorld(lc); shift.z = 0
				B.ghost:SetPos(pos + shift)
			end
		end
	end
end

function B.PlaceClick()
	if not (B.placing and B.valid and not B.blocked and B.q) then return end
	net.Start("ME_PlaceBuilding")
	net.WriteString(B.placing.id)
	net.WriteInt(B.q, 16)
	net.WriteInt(B.r, 16)
	net.WriteUInt(math.floor(((B.rot or 0) % 360) / 60), 3)
	net.SendToServer()

end

local rWas, wWas, lWas = false, false, false
hook.Add("Think", "ME_BuildPlaceThink", function()
	if not B.placing then rWas, wWas, lWas = false, false, false return end
	if not (ME.InGame and ME.InGame()) then B.StopPlace() return end

	local rDown = input.IsKeyDown(KEY_R)
	if rDown ~= rWas then B.HintHold("r", rDown) end
	if rDown and not rWas then
		if B.placing.id == "harbor" and B.q then
			B.rot = harborNextRot(B.q, B.r, B.rot or 0)
		else
			B.rot = ((B.rot or 0) + 60) % 360
		end
	end
	rWas = rDown

	local lDown = input.IsMouseDown(MOUSE_LEFT)
	if lDown ~= lWas then B.HintHold("lmb", lDown) end
	lWas = lDown

	local wDown = input.IsKeyDown(KEY_W)
	if wDown and not wWas then B.HintHold("w", true); B.StopPlace() return end
	wWas = wDown

	updateGhost()
end)

local ARROW_MAT = Material("mergeempires/game/me_arrow.png", "smooth")

local function arrowGround(x, y)
	local q, r  = ME.WorldToHex(Vector(x, y, 0))
	local cell  = ME.BoardCells and ME.BoardCells[ME.HexKey(q, r)]
	local z     = ((ME.MapInfo and ME.MapInfo.baseZ) or 0) + (ME.SurfaceOffset(q, r, cell and cell.biome or "grass") or 0)
	return Vector(x, y, z + 3)
end
local function drawGroundArrow(center, fwd, right, size, col)
	local h  = size * 0.5

	local tl = arrowGround(center.x + (fwd.x - right.x) * h, center.y + (fwd.y - right.y) * h)
	local tr = arrowGround(center.x + (fwd.x + right.x) * h, center.y + (fwd.y + right.y) * h)
	local br = arrowGround(center.x + (-fwd.x + right.x) * h, center.y + (-fwd.y + right.y) * h)
	local bl = arrowGround(center.x + (-fwd.x - right.x) * h, center.y + (-fwd.y - right.y) * h)
	render.SetMaterial(ARROW_MAT)
	render.DrawQuad(tl, tr, br, bl, col)
end

hook.Remove("PostDrawOpaqueRenderables", "ME_BuildGhost")
hook.Add("PostDrawTranslucentRenderables", "ME_BuildGhost", function(_, sky)
	if sky or not (B.placing and IsValid(B.ghost)) then return end
	local r, g, b = 1, 0.55, 0.14
	if not (B.valid and not B.blocked) then r, g, b = 1, 0.22, 0.18
	elseif B.builderNear then r, g, b = 0.92, 0.94, 0.96 end
	render.SuppressEngineLighting(true)
	render.ResetModelLighting(0.9, 0.9, 0.9)
	render.SetColorModulation(r, g, b)
	render.SetBlend(0.6)
	B.ghost:SetupBones()
	B.ghost:DrawModel()
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
	render.SuppressEngineLighting(false)

	local ang   = Angle(0, B.rot or 0, 0)
	local fwd   = ang:Forward()
	local right = ang:Right()
	local base  = B.ghost:GetPos() + Vector(0, 0, 3)
	local hex   = (ME.Config and ME.Config.HexSize) or 96
	local col   = Color(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), 235)

	local edge  = ME.IsEdgeBuilding(B.placing.id)
	local sz    = hex * (edge and 0.3 or 0.42)
	local lat   = hex * (edge and 0.16 or 0.28)
	local fdist = hex * (edge and 0.22 or 0.98)
	drawGroundArrow(base + fwd * fdist - right * lat, fwd, right, sz, col)
	drawGroundArrow(base + fwd * fdist + right * lat, fwd, right, sz, col)
end)

local function drawHourglass(worldTop)
	local s = worldTop:ToScreen()
	if not s.visible then return end

	local cf = math.Clamp(2800 / ((ME.Cam and ME.Cam.dist) or 2800), 0.4, 1.05)
	local sz = S(30) * cf
	surface.SetMaterial(MAT_HG)
	surface.SetDrawColor(255, 175, 45, 255)
	surface.DrawTexturedRect(s.x - sz / 2, s.y - sz, sz, sz)
end

local NO_HP_BAR = {}
local NO_PROD_BAR = { wall = true, gate = true }

local function prodFrac(idx)
	local q = B.trainQ and B.trainQ[idx]
	if not (q and q.kinds and #q.kinds > 0 and (q.dur or 0) > 0 and (q.start or 0) > 0) then return nil end
	return math.Clamp((CurTime() - q.start) / q.dur, 0, 1)
end
local BAR_ORANGE = Color(255, 150, 40)

local BAR_BLUE = Color(63, 134, 255)
local function hpColor(frac)
	if frac > 0.5  then return Color(74, 186, 58) end
	if frac > 0.25 then return Color(214, 172, 34) end

	local f = math.Clamp(frac / 0.25, 0, 1)
	return Color(math.floor(180 + 40 * f), math.floor(30 + 90 * f), 30)
end

function ME.BarWidthFor(ent)
	if not IsValid(ent) then return 48 end
	local mins, maxs = ent:GetModelRenderBounds()
	local sc = ent:GetModelScale(); if not sc or sc == 0 then sc = 1 end
	local horiz = math.max(math.abs(maxs.x - mins.x), math.abs(maxs.y - mins.y)) * sc
	return math.Clamp(horiz * 0.32 + 12, 22, 74)
end

ME._barAnim = ME._barAnim or {}
function ME.DrawWorldBar(worldpos, frac, col, width, anim, key, alpha)
	local s = worldpos:ToScreen()
	if not s.visible then return end
	alpha = math.Clamp(alpha or 1, 0, 1)
	if alpha <= 0.004 then return end
	frac = math.Clamp(frac, 0, 1)
	if key then
		local a = ME._barAnim[key]
		if a == nil or math.abs(a - frac) < 0.002 then a = frac
		else a = Lerp(math.min(1, FrameTime() * 7), a, frac) end
		ME._barAnim[key] = a
		frac = a
	end

	local cf   = math.Clamp(2800 / ((ME.Cam and ME.Cam.dist) or 2800), 0.3, 0.6)
	local w, h = math.Round(S(width or 50) * cf), math.max(3, math.Round(S(7) * cf))
	local x, y = math.floor(s.x - w / 2), math.floor(s.y)
	surface.SetDrawColor(16, 18, 16, math.floor(240 * alpha)); surface.DrawRect(x - 1, y - 1, w + 2, h + 2)
	surface.SetDrawColor(30, 33, 30, math.floor(255 * alpha)); surface.DrawRect(x, y, w, h)
	local fw = math.floor(w * frac)

	surface.SetDrawColor(col.r, col.g, col.b, math.floor(255 * alpha)); surface.DrawRect(x, y, fw, h)
end

local ENGINE_OF = {
	tank = "engine_tank",  missiletank = "engine_tank",
	humvee = "engine_light", apc = "engine_light",
	builderboat = "engine_builderboat", barge = "engine_barge", destroyer = "engine_boat",
	submarine = "engine_submarine",
}
local ENG_MOVE = 12

hook.Add("Think", "ME_SfxSustained", function()
	if not (ME.Sfx and ME.InGame and ME.InGame()) then return end
	local ft = math.max(0.001, FrameTime())

	if ME.UnitModels then
		for idx, rec in pairs(ME.UnitModels) do
			local id = ENGINE_OF[rec.kind or ""]
			if id and IsValid(rec.model) then
				local p, last = rec.model:GetPos(), rec._engPos
				rec._engPos = p

				if last then
					local spd = p:Distance(last) / ft
					if spd > ENG_MOVE then
						ME.Sfx.Loop("eng" .. idx, id, p, math.Clamp(0.45 + spd / 260, 0.45, 1))
					end
				end
			end
		end
	end

	if ME.BuildingModels then
		for idx, rec in pairs(ME.BuildingModels) do
			if IsValid(rec.model) and rec.built then

				local burning = rec._burnStart and RealTime() >= rec._burnStart
				if not burning and rec.hp then
					local cfg = ME.GetBuilding and ME.GetBuilding(rec.bid)
					local mx  = (cfg and cfg.health) or 500
					burning = rec.hp > 0 and (rec.hp / mx) < 0.35
				end
				if burning then ME.Sfx.Loop("burn" .. idx, "amb_fire", rec.model:GetPos()) end

				if rec.builderNear and rec.hp then
					local cfg = ME.GetBuilding and ME.GetBuilding(rec.bid)
					if rec.hp < ((cfg and cfg.health) or 500) then
						ME.Sfx.Loop("fix" .. idx, "repair_loop", rec.model:GetPos())
					end
				end
			end
		end
	end
end)

ME.Fight = ME.Fight or {}
local FIGHT_HOLD, FIGHT_FADE = 2.2, 0.9
local MAT_FIGHT  = Material("mergeempires/game/me_swords.png", "smooth")
local FIGHT_COL  = Color(255, 116, 104)

function ME.MarkFight(key) if key then ME.Fight[key] = RealTime() end end

local function fightAlpha(key)
	local t = key and ME.Fight[key]
	if not t then return 0 end
	local since = RealTime() - t
	if since <= FIGHT_HOLD then return 1 end
	local a = 1 - (since - FIGHT_HOLD) / FIGHT_FADE
	if a <= 0 then ME.Fight[key] = nil return 0 end
	return a
end

function ME.DrawFightIcon(worldpos, key)
	local a = fightAlpha(key)
	if a <= 0.004 then return end
	local s = worldpos:ToScreen()
	if not s.visible then return end
	local cf   = math.Clamp(2800 / ((ME.Cam and ME.Cam.dist) or 2800), 0.3, 0.6)
	local barH = math.max(3, math.Round(S(7) * cf))
	local sz   = math.max(9, math.Round(S(30) * cf))
	local x, y = math.floor(s.x - sz / 2), math.floor(s.y - barH - sz - math.Round(S(3) * cf))
	surface.SetMaterial(MAT_FIGHT)
	surface.SetDrawColor(20, 8, 8, math.floor(190 * a))
	surface.DrawTexturedRect(x + 1, y + 1, sz, sz)
	surface.SetDrawColor(FIGHT_COL.r, FIGHT_COL.g, FIGHT_COL.b, math.floor(255 * a))
	surface.DrawTexturedRect(x, y, sz, sz)
end

local function drawSegHP(worldpos, hp, maxhp, width, key, alpha)
	local frac = math.Clamp(hp / math.max(1, maxhp), 0, 1)
	ME.DrawWorldBar(worldpos, frac, hpColor(frac), width, false, key, alpha)
end

local function unitHPFrac(u)
	local hp = u.GetHP and u:GetHP() or u:Health()
	local mx = u.GetMaxHP and u:GetMaxHP() or u:GetMaxHealth()
	return math.Clamp(hp / math.max(1, mx), 0, 1)
end
local function drawUnitHP(u)
	local top  = math.max(u:OBBMaxs().z or 0, 40)
	local frac = unitHPFrac(u)
	ME.DrawWorldBar(u:GetPos() + Vector(0, 0, top + 12), frac, hpColor(frac), ME.BarWidthFor(u), false, "u" .. u:EntIndex())
end

hook.Add("HUDPaint", "ME_UnitSelHP", function()
	if not (ME.InGame and ME.InGame()) or B.placing then return end
	local seen = {}
	for _, u in ipairs((ME.Cam and ME.Cam.selected) or {}) do
		if IsValid(u) and u.MEUnit then drawUnitHP(u); seen[u] = true end
	end

	if ME.Cam and ME.Cam.dragging and ME.Cam.dx then
		local mx, my = gui.MousePos()
		local lx, rx = math.min(ME.Cam.dx, mx), math.max(ME.Cam.dx, mx)
		local ty, by = math.min(ME.Cam.dy, my), math.max(ME.Cam.dy, my)
		local t = LocalPlayer():Team()
		for _, e in ipairs(ents.GetAll()) do
			if e.MEUnit and not seen[e] and ME.EntFaction(e) == t and e:Health() > 0 then
				local s = e:GetPos():ToScreen()
				if s.visible and s.x >= lx and s.x <= rx and s.y >= ty and s.y <= by then drawUnitHP(e) end
			end
		end
	end
end)

local unitLastHP = setmetatable({}, { __mode = "k" })

hook.Add("HUDPaint", "ME_DamagedUnitHP", function()
	if not (ME.InGame and ME.InGame()) or B.placing then return end
	local hovered = ME.UnitRay and ME.UnitRay()
	for _, e in ipairs(ents.FindByClass("ent_me_unit")) do

		local shown = IsValid(e) and ME.UnitModels and ME.UnitModels[e:EntIndex()] ~= nil
		if shown and (e.GetHP and e:GetHP() or 0) > 0 then

			local idx = e:EntIndex()
			local hp  = e:GetHP()
			local was = unitLastHP[e]
			if was and hp < was then ME.MarkFight("u" .. idx) end
			unitLastHP[e] = hp

			if e == hovered or unitHPFrac(e) < 0.999 then
				drawUnitHP(e)
			end
			local top = math.max(e:OBBMaxs().z or 0, 40)
			ME.DrawFightIcon(e:GetPos() + Vector(0, 0, top + 12), "u" .. idx)
		end
	end
end)

local function coreHPFor(fac)
	local d = ME.CoreHP and ME.CoreHP[fac]
	if d and d.mx and d.mx > 0 then return d.hp, d.mx end
end

local CORE_BAR_W = 44
hook.Add("HUDPaint", "ME_CoreHP", function()
	if not (ME.InGame and ME.InGame()) or B.placing then return end
	for _, cm in ipairs(ME.CoreModels or {}) do
		if IsValid(cm) then
			local hp, mx = coreHPFor(cm.MEFaction)
			if hp and hp < mx then
				local top = cm:OBBMaxs().z or 90
				drawSegHP(cm:GetPos() + Vector(0, 0, top + 26), hp, mx, CORE_BAR_W, "c" .. (cm.MEFaction or 0))
			end
		end
	end
end)

hook.Add("HUDPaint", "ME_HoverHP", function()
	if not (ME.InGame and ME.InGame()) or B.placing then return end

	local hit = ME.GroundUnderCursor and ME.GroundUnderCursor()
	if not hit then return end
	local gq, gr = ME.WorldToHex(hit)
	for _, cm in ipairs(ME.CoreModels or {}) do
		if IsValid(cm) then
			local cq, cr = ME.WorldToHex(cm:GetPos())
			if cq == gq and cr == gr then
				local hp, mx = coreHPFor(cm.MEFaction)
				mx = mx or (ME.Config.CoreHealth or 5200)
				hp = hp or mx
				drawSegHP(cm:GetPos() + Vector(0, 0, (cm:OBBMaxs().z or 90) + 26), hp, mx, CORE_BAR_W, "c" .. (cm.MEFaction or 0))
				return
			end
		end
	end
	local idx = ME.BuildingAtHex and ME.BuildingAtHex(gq, gr)
	local rec = idx and ME.BuildingModels[idx]

	if not (rec and IsValid(rec.model)) or NO_HP_BAR[rec.bid] or not rec.built then return end
	if prodFrac(idx) then return end
	local cfg = ME.GetBuilding and ME.GetBuilding(rec.bid)
	local maxhp = (cfg and cfg.health) or 500
	local hp    = rec.hp or maxhp
	local top   = rec.model:OBBMaxs().z or 60
	drawSegHP(rec.model:GetPos() + Vector(0, 0, top + 22), math.Clamp(hp, 0, maxhp), maxhp, ME.BarWidthFor(rec.model), "b" .. idx)
end)

local HP_HOLD, HP_FADE = 4.0, 1.1

hook.Add("HUDPaint", "ME_FightStructures", function()
	if not (ME.InGame and ME.InGame()) or B.placing then return end
	for idx, rec in pairs(ME.BuildingModels or {}) do
		if rec.built and IsValid(rec.model) and FIGHT_BIDS[rec.bid] then
			local top = rec.model:OBBMaxs().z or 60
			ME.DrawFightIcon(rec.model:GetPos() + Vector(0, 0, top + 22), "b" .. idx)
		end
	end
	for _, cm in ipairs(ME.CoreModels or {}) do
		if IsValid(cm) then
			ME.DrawFightIcon(cm:GetPos() + Vector(0, 0, (cm:OBBMaxs().z or 90) + 26), "c" .. (cm.MEFaction or 0))
		end
	end
end)

hook.Add("HUDPaint", "ME_DamagedHP", function()
	if not (ME.InGame and ME.InGame()) or B.placing then return end
	local now = RealTime()
	for idx, rec in pairs(ME.BuildingModels or {}) do
		if rec.built and IsValid(rec.model) and not NO_HP_BAR[rec.bid] and rec.hp and not prodFrac(idx) then
			local cfg   = ME.GetBuilding and ME.GetBuilding(rec.bid)
			local maxhp = (cfg and cfg.health) or 500
			local hp    = math.Clamp(rec.hp, 0, maxhp)
			if hp > 0 and hp < maxhp then
				local since = now - (rec._hitAt or 0)
				local a = since <= HP_HOLD and 1 or (1 - (since - HP_HOLD) / HP_FADE)
				if a > 0 then
					local top = rec.model:OBBMaxs().z or 60
					drawSegHP(rec.model:GetPos() + Vector(0, 0, top + 22), hp, maxhp, ME.BarWidthFor(rec.model), "b" .. idx, a)
				end
			end
		end
	end
end)

hook.Add("HUDPaint", "ME_BuildProdBar", function()
	if not (ME.InGame and ME.InGame()) or B.placing then return end
	local myTeam = LocalPlayer():Team()
	for idx, rec in pairs(ME.BuildingModels or {}) do
		if rec.built and IsValid(rec.model) and rec.faction == myTeam and not NO_PROD_BAR[rec.bid] then
			local frac = prodFrac(idx)
			if frac then
				local top = rec.model:OBBMaxs().z or 60
				ME.DrawWorldBar(rec.model:GetPos() + Vector(0, 0, top + 22), frac, BAR_ORANGE, ME.BarWidthFor(rec.model), true)
			end
		end
	end
end)

local MAT_EYE_OFF = Material("mergeempires/menu/me_eye_off.png", "smooth")
local MINE_BIDS = { at_mine = true, naval_mine = true }

local MAT_BLOCKED = Material("mergeempires/game/me_blocked.png", "smooth")
hook.Add("HUDPaint", "ME_UnitBlocked", function()
	if not (ME.InGame and ME.InGame()) then return end
	local myTeam = LocalPlayer():Team()
	for _, rec in pairs(ME.UnitModels or {}) do

		if rec.blocked and not rec.moving and (rec.buildIdx or 0) == 0 and IsValid(rec.model) and rec.faction == myTeam then
			local top = rec.model:OBBMaxs().z or 60
			local s   = (rec.model:GetPos() + Vector(0, 0, top + 22)):ToScreen()
			if s.visible then
				local cf = math.Clamp(2800 / ((ME.Cam and ME.Cam.dist) or 2800), 0.34, 1.0)
				local sz = S(26) * cf
				surface.SetMaterial(MAT_BLOCKED)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(s.x - sz / 2, s.y - sz / 2, sz, sz)
			end
		end
	end
end)

hook.Add("HUDPaint", "ME_UnitHidden", function()
	if not (ME.InGame and ME.InGame()) or B.placing then return end
	local myTeam = LocalPlayer():Team()
	for _, rec in pairs(ME.UnitModels or {}) do
		if rec.hidden and IsValid(rec.model) and rec.faction == myTeam then
			local top = rec.model:OBBMaxs().z or 40
			local s   = (rec.model:GetPos() + Vector(0, 0, top + 34)):ToScreen()
			if s.visible then
				local cf = math.Clamp(2800 / ((ME.Cam and ME.Cam.dist) or 2800), 0.34, 1.0)
				local sz = S(26) * cf
				local x, y = s.x - sz / 2, s.y - sz / 2
				surface.SetMaterial(MAT_EYE_OFF)
				surface.SetDrawColor(0, 0, 0, 170); surface.DrawTexturedRect(x + 1, y + 1, sz, sz)
				surface.SetDrawColor(255, 255, 255, 255); surface.DrawTexturedRect(x, y, sz, sz)
			end
		end
	end
end)

hook.Add("HUDPaint", "ME_MineHidden", function()
	if not (ME.InGame and ME.InGame()) or B.placing then return end
	local myTeam = LocalPlayer():Team()
	for _, rec in pairs(ME.BuildingModels) do
		if rec.built and IsValid(rec.model) and rec.faction == myTeam and MINE_BIDS[rec.bid] then
			local top = rec.model:OBBMaxs().z or 30
			local s   = (rec.model:GetPos() + Vector(0, 0, top + 40)):ToScreen()
			if s.visible then

				local cf = math.Clamp(2800 / ((ME.Cam and ME.Cam.dist) or 2800), 0.34, 1.0)
				local sz = S(30) * cf
				local x, y = s.x - sz / 2, s.y - sz / 2
				surface.SetMaterial(MAT_EYE_OFF)
				surface.SetDrawColor(0, 0, 0, 170); surface.DrawTexturedRect(x + 1, y + 1, sz, sz)
				surface.SetDrawColor(255, 255, 255, 255); surface.DrawTexturedRect(x, y, sz, sz)
			end
		end
	end
end)

hook.Add("HUDPaint", "ME_BuildOverlays", function()
	if B.placing and IsValid(B.ghost) and B.valid and not B.blocked then
		drawHourglass(B.ghost:GetPos() + Vector(0, 0, (B.ghost:OBBMaxs().z or 60) + 24))
	end
	if B.placing then
		local mx, my = gui.MousePos()
		local yoff = S(2)
		if not B.valid or B.blocked then
			local msg = B.blocked and "Can't build here, something is in the way"
				or (B.reliefBad and "The higher tile owns this edge")
				or (B.harborDock and "That is a harbor's dock — it would be sealed in")
				or (B.harborWalled and "That beach is walled off — break it open first")
				or (B.harborBadRot and "Rotate (R) the harbor to face the beach")
				or (B.placing.id == "harbor" and "Harbors go on water next to the shore")
				or "Can't be built on this tile"
			draw.SimpleTextOutlined("- " .. msg, "ME_BuildWarn", mx + S(22), my + yoff, Color(255, 74, 66), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, S(2), Color(20, 8, 8, 235))
			yoff = yoff + S(25)
		end

		local money = IsValid(LocalPlayer()) and LocalPlayer():GetNWInt("ME_Money", 0) or 0
		if money < (B.placing.price or 0) then
			draw.SimpleTextOutlined("- Not enough money", "ME_BuildWarn", mx + S(22), my + yoff, Color(255, 74, 66), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, S(2), Color(20, 8, 8, 235))
			yoff = yoff + S(25)
		end

		local bmax = B.placing.max or 0

		if bmax > 0 and B.placing.id == "house" then bmax = bmax + LocalPlayer():GetNWInt("ME_HouseBonus", 0) end
		if bmax > 0 then
			local n, myTeam = 0, LocalPlayer():Team()
			for _, rec in pairs(ME.BuildingModels) do
				if rec.faction == myTeam and rec.bid == B.placing.id then n = n + 1 end
			end
			draw.SimpleTextOutlined("You have built " .. n .. "/" .. bmax .. " of these", "ME_BuildCount", mx + S(22), my + yoff, Color(236, 238, 242), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, S(2), Color(18, 18, 20, 235))
		end
	end

	for _, rec in pairs(ME.BuildingModels) do
		if not rec.built and IsValid(rec.model) then
			local top = rec.model:OBBMaxs().z or 60
			ME.DrawWorldBar(rec.model:GetPos() + Vector(0, 0, top + 18), rec.progress or 0, BAR_BLUE, ME.BarWidthFor(rec.model))
			if (rec.progress or 0) <= 0 then drawHourglass(rec.model:GetPos() + Vector(0, 0, top + 40)) end
		end
	end
end)
