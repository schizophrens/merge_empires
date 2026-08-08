include("shared.lua")

function ENT:Initialize()
	self:SetRenderBounds(Vector(-260, -260, -260), Vector(260, 260, 520))
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local maxhp = math.max(1, self:GetMaxHP())
	local frac  = math.Clamp(self:GetHP() / maxhp, 0, 1)
	local col   = ME.FactionColor(self:GetFaction())

	local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 40)
	local ang = Angle(0, ply:EyeAngles().y - 90, 90)

	cam.Start3D2D(pos, ang, 0.5)
		surface.SetDrawColor(0, 0, 0, 200);            surface.DrawRect(-160, -18, 320, 36)
		surface.SetDrawColor(col.r, col.g, col.b, 255); surface.DrawRect(-156, -14, 312 * frac, 28)
		draw.SimpleText("CORE  " .. self:GetHP() .. " / " .. self:GetMaxHP(),
			"DermaDefaultBold", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end
