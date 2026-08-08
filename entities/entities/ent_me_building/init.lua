AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:SetBuilding(id, faction)
	local b = ME.GetBuilding and ME.GetBuilding(id)
	self.MEBID     = id
	self.MEFaction = faction or 0
	self:SetNWString("MEBID", id)
	self:SetNWInt("MEFaction", faction or 0)

	self.MEFullHP = (b and b.health) or 500
	self.HP    = 1
	self.MaxHP = 1
	self:SetNWInt("MEHP", self.HP)
	self:SetNWInt("MEMaxHP", self.MaxHP)
	self.MEBuilt = false
	self:SetNWBool("MEBuilt", false)

	local base = (b and b.model) or "models/hunter/blocks/cube025x025x025.mdl"
	self:SetModel((ME.SkinnedModel and ME.SkinnedModel(faction or 0, "b_" .. id, base)) or base)
end

function ENT:MEConstruct()
	self.MEBuilt = true

	local full = self.MEFullHP or (ME.GetBuilding and ME.GetBuilding(self.MEBID) or {}).health or 500
	self.HP, self.MaxHP = full, full
	self:SetNWInt("MEHP", full)
	self:SetNWInt("MEMaxHP", full)
	self:SetNWBool("MEBuilt", true)
	self:SetNWFloat("MEProgress", 1)
	if ME.NetBuilding then ME.NetBuilding(self) end
	if ME.NetBuildingSfx then ME.NetBuildingSfx(2, self:GetPos()) end
	if ME.RefreshPop and self.MEBID == "house" then ME.RefreshPop(self.MEFaction or 0) end
	if ME.RefreshIncome then ME.RefreshIncome(self.MEFaction or 0) end
end

local HS          = (ME.Config and ME.Config.HexSize) or 96
local BUILD_RANGE = HS * 1.9
local AUTO_HEXES  = 5
local AUTO_RANGE  = HS * 9.2
local AUTO_MAX    = 4
function ENT:Think()
	self:NextThink(CurTime() + 0.1)
	if self.MEBuilt then return true end

	local crew = (ME.BOAT_ONLY and ME.BOAT_ONLY[self.MEBID]) and "builderboat" or "builder"

	local mq, mr = ME.WorldToHex(self:GetPos())
	local building, assigned, freeBest, freeD = 0, 0, nil, nil
	for _, u in ipairs(ents.FindInSphere(self:GetPos(), AUTO_RANGE)) do
		if u.MEUnit and u.MEKind == crew and (u.MEFaction or 0) == self.MEFaction then
			if u.BuildTarget == self then
				assigned = assigned + 1
				if u.Building and u:GetPos():Distance(self:GetPos()) <= BUILD_RANGE then building = building + 1 end
			elseif not IsValid(u.BuildTarget) and not u.MoveTarget then
				local uq, ur = ME.WorldToHex(u:GetPos())
				if ME.HexDistance(uq, ur, mq, mr) <= AUTO_HEXES then
					local dd = u:GetPos():DistToSqr(self:GetPos())
					if not freeD or dd < freeD then freeD, freeBest = dd, u end
				end
			end
		end
	end

	if assigned < AUTO_MAX and IsValid(freeBest) and freeBest.OrderBuild then freeBest:OrderBuild(self); assigned = assigned + 1 end

	local near = assigned > 0
	if near ~= self.MEBuilderNear then self.MEBuilderNear = near; ME.NetBuilding(self) end

	if building > 0 then
		local b   = ME.GetBuilding and ME.GetBuilding(self.MEBID)
		local dur = ((b and b.build) or 15) / ME.Speed()
		self.MEProgress = math.Clamp((self.MEProgress or 0) + (building * 0.1) / dur, 0, 1)
		self:SetNWFloat("MEProgress", self.MEProgress)
		if self.MEProgress >= 1 then self:MEConstruct() else ME.NetBuilding(self) end
	end
	return true
end

function ENT:OnRemove()
	local idx, pos, destroyed = self:EntIndex(), self:GetPos(), self._destroyed
	if ME.NetBuildingRemove then timer.Simple(0, function() ME.NetBuildingRemove(idx, pos, destroyed) end) end
	if self.MEBuilt then
		local fac, bid = self.MEFaction or 0, self.MEBID
		timer.Simple(0, function()
			if ME.RefreshPop and bid == "house" then ME.RefreshPop(fac) end
			if ME.RefreshIncome then ME.RefreshIncome(fac) end
		end)
	end
end

function ENT:Initialize()
	if not self:GetModel() then self:SetModel("models/hunter/blocks/cube025x025x025.mdl") end
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) end
end

function ENT:OnTakeDamage(dmg)

	local attacker = dmg:GetAttacker()
	if IsValid(attacker) and attacker:IsPlayer() then
		if attacker:Team() == self.MEFaction then return end
		if ME.AreAllied and ME.AreAllied(attacker:Team(), self.MEFaction) then return end
	end
	if not self.MEBuilt then
		self._destroyed = true
		self:Remove()
		return
	end
	self.HP = (self.HP or 500) - dmg:GetDamage()
	self:SetNWInt("MEHP", math.max(0, math.floor(self.HP)))
	if self.HP <= 0 then
		self._destroyed = true
		self:Remove()
	end
end
