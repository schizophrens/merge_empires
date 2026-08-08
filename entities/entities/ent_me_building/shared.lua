ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Building"
ENT.Spawnable   = false
ENT.Category    = "Merge Empires"
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:GetBID()      return self:GetNWString("MEBID", "") end
function ENT:GetBuilt()    return self:GetNWBool("MEBuilt", false) end
function ENT:GetHP()       return self:GetNWInt("MEHP", 0) end
function ENT:GetMaxHP()    return self:GetNWInt("MEMaxHP", 0) end
