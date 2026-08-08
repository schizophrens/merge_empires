AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("ME_CoreHP")

function ENT:PushHP()
	if (self._hpNet or 0) > CurTime() then return end
	self._hpNet = CurTime() + 0.1
	net.Start("ME_CoreHP")
	net.WriteInt(self:GetFaction() or 0, 8)
	net.WriteInt(math.max(0, math.floor(self:GetHP())), 32)
	net.WriteInt(math.max(1, math.floor(self:GetMaxHP())), 32)
	net.Broadcast()
end

function ENT:Initialize()
	if not self:GetModel() or self:GetModel() == "" then
		self:SetModel("models/merge_empires/core.mdl")
	end
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:DrawShadow(true)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) end

	local hp = ME.Config.CoreHealth
	self:SetMaxHealth(hp); self:SetHealth(hp)
	self:SetHP(hp); self:SetMaxHP(hp)
end

function ENT:UpdateTransmitState() return TRANSMIT_ALWAYS end

function ENT:OnTakeDamage(dmg)
	if not ME.MatchActive then return end

	local af = ME.EntFaction(dmg:GetAttacker())
	if af ~= 0 and af == self:GetFaction() then return end
	if af ~= 0 and ME.AreAllied(af, self:GetFaction()) then return end

	self._lastAttFac = af
	local nh = self:Health() - dmg:GetDamage()
	self:SetHealth(nh)
	self:SetHP(math.max(0, math.floor(nh)))
	self:PushHP()

	if nh > 0 and not self._meBurning and nh <= (ME.CoreBurnHP or 500) then
		self._meBurning = true
		if ME.NetCoreBurn then ME.NetCoreBurn(self) end
	end

	if nh <= 0 and not self._meDead then self._meDead = true; self:MEMeltdown() end
end

function ENT:MEMeltdown()
	local faction = self:GetFaction()
	local pos     = self:GetPos()

	if ME.OnCoreMeltdown then ME.OnCoreMeltdown(faction, pos) end

	local dur = ME.MeltdownTime or 3
	timer.Simple(dur, function()
		if IsValid(self) then self:MEDie() end
	end)
end

function ENT:MEDie()
	local faction = self:GetFaction()
	local pos = self:GetPos()

	util.ScreenShake(pos, 24, 24, 2.3, 4400)
	if ME.NetCoreExplode then ME.NetCoreExplode(pos, faction) end

	local killer = self._lastAttFac
	if killer and killer > 0 and killer ~= faction and ME.CoreKills then
		ME.CoreKills[killer] = (ME.CoreKills[killer] or 0) + 1
		if ME.RefreshPop then ME.RefreshPop(killer) end
	end

	if ME.ChatSystem and ME.TeamLabel then
		local msg = ME.TeamLabel(faction) .. "'s CORE has been destroyed"
		if killer and killer > 0 and killer ~= faction then msg = msg .. " by " .. ME.TeamLabel(killer) end
		ME.ChatSystem(msg .. ".", ME.TeamColor and ME.TeamColor(faction) or Color(255, 80, 70))
	end

	self:Remove()
	if ME.OnCoreDestroyed then ME.OnCoreDestroyed(faction, pos) end
end

util.AddNetworkString("ME_CoreBeam")

ME.CoreDefRangeHex = ME.CoreDefRangeHex or 5
ME.CoreDefDamage   = ME.CoreDefDamage   or 130
ME.CoreDefReload   = ME.CoreDefReload   or 0.5

local BEAM_REFRESH = 0.35

local function coreDefRange()
	return (ME.CoreDefRangeHex + 1) * (((ME.Config and ME.Config.HexSize) or 96) * math.sqrt(3))
end

local function coreCanHit(origin, oq, orr, e)
	local eq, er = ME.WorldToHex(e:GetPos())
	if ME.HexDistance(oq, orr, eq, er) > ME.CoreDefRangeHex then return false end
	if ME.HasLineOfSight and not ME.HasLineOfSight(origin, e:GetPos()) then return false end
	return true
end

local CORE_DEF_MINES = { at_mine = true, naval_mine = true }
local function coreDefPriority(e)
	local c = e:GetClass()
	if c == "ent_me_unit" then
		if (e.GetHP and e:GetHP() or 0) <= 0 then return nil end
		return e.MEVehicle and 0 or 1
	end
	if c == "ent_me_building" then
		if CORE_DEF_MINES[e.MEBID] then return nil end
		return 2
	end
	return nil
end

local function sendBeam(fac, origin, tgt)
	local valid = IsValid(tgt)
	net.Start("ME_CoreBeam")
	net.WriteInt(fac, 8)
	net.WriteVector(origin)
	net.WriteVector(valid and tgt:GetPos() or origin)
	net.WriteUInt(valid and tgt:EntIndex() or 0, 16)
	net.Broadcast()
end

timer.Create("ME_CoreDefense", 0.1, 0, function()
	if not ME.MatchActive then return end
	local now, range = CurTime(), coreDefRange()
	for fac, core in pairs(ME.Cores or {}) do
		if IsValid(core) and not core._meDead then
			local origin = core:GetPos()
			local oq, orr = ME.WorldToHex(origin)
			local best, bestPr, bestD
			for _, e in ipairs(ents.FindInSphere(origin, range)) do
				if IsValid(e) and ME.IsEnemyEnt and ME.IsEnemyEnt(fac, e) then
					local pr = coreDefPriority(e)
					if pr and coreCanHit(origin, oq, orr, e) then
						local d = origin:DistToSqr(e:GetPos())

						if not best or pr < bestPr or (pr == bestPr and d < bestD) then best, bestPr, bestD = e, pr, d end
					end
				end
			end
			if IsValid(best) then
				if (core._nextBeam or 0) <= now then
					core._nextBeam = now + ME.CoreDefReload
					if ME.DamageEnt then ME.DamageEnt(best, ME.CoreDefDamage, fac) end
				end
				if core._beamTgt ~= best or (core._beamAt or 0) <= now then
					core._beamTgt, core._beamAt = best, now + BEAM_REFRESH
					sendBeam(fac, origin, best)
				end
			elseif core._beamTgt then
				core._beamTgt, core._beamAt = nil, 0
				sendBeam(fac, origin, nil)
			end
		end
	end
end)
