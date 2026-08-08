
ME = ME or {}
ME.CoreDefRangeHex = ME.CoreDefRangeHex or 5
ME.CoreDefDamage   = ME.CoreDefDamage   or 130
ME.CoreDefReload   = ME.CoreDefReload   or 0.5

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Core"
ENT.Spawnable = false
ENT.Category  = "Merge Empires"

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Faction")
	self:NetworkVar("Int", 1, "HP")
	self:NetworkVar("Int", 2, "MaxHP")
end
