

util.AddNetworkString("ME_TurretFire")
util.AddNetworkString("ME_Heal")

local function hexRange(tiles)
	return tiles * (((ME.Config and ME.Config.HexSize) or 96) * math.sqrt(3))
end

local function cfgOf(b) return ME.GetBuilding and ME.GetBuilding(b.MEBID) end

timer.Create("ME_HospitalHeal", 0.5, 0, function()
	if not ME.MatchActive then return end
	for _, h in ipairs(ents.FindByClass("ent_me_building")) do
		if IsValid(h) and h.MEBuilt and h.MEBID == "hospital" then
			local cfg = cfgOf(h)
			if cfg and (cfg.healAmount or 0) > 0 then
				local fac = h.MEFaction or 0
				for _, u in ipairs(ents.FindInSphere(h:GetPos(), hexRange(cfg.rangeHex or 3))) do
					if IsValid(u) and u:GetClass() == "ent_me_unit" and (u.MEFaction or 0) == fac and not u.MEBoat then
						local hp, mx = u:GetHP(), u:GetMaxHP()
						if hp > 0 and hp < mx then
							local nh = math.min(mx, hp + (cfg.healAmount or 50))
							u.HP = nh
							u:SetHP(nh); u:SetHealth(nh)
							net.Start("ME_Heal"); net.WriteUInt(u:EntIndex(), 16); net.Broadcast()
						end
					end
				end
			end
		end
	end
end)

timer.Create("ME_TurretFire", 0.1, 0, function()
	if not ME.MatchActive then return end
	local now = CurTime()
	for _, t in ipairs(ents.FindByClass("ent_me_building")) do
		if IsValid(t) and t.MEBuilt and t.MEBID == "turret" and (t._nextFire or 0) <= now then
			local cfg = cfgOf(t)
			if cfg and (cfg.dmg or 0) > 0 then
				local fac, origin = t.MEFaction or 0, t:GetPos()
				local rng = cfg.rangeHex or 4
				local tq, tr = ME.WorldToHex(origin)
				local best, bestVeh, bestD

				for _, e in ipairs(ents.FindInSphere(origin, hexRange(rng + 1))) do
					if IsValid(e) and e:GetClass() == "ent_me_unit" and (e.GetHP and e:GetHP() or 0) > 0
					   and ME.IsEnemyEnt and ME.IsEnemyEnt(fac, e) then
						local ep = e:GetPos()
						local eq, er = ME.WorldToHex(ep)

						if ME.HexDistance(tq, tr, eq, er) <= rng
						   and (not ME.HasLineOfSight or ME.HasLineOfSight(origin, ep)) then
							local veh = e.MEVehicle and true or false
							local d   = origin:DistToSqr(ep)
							if not best or (veh and not bestVeh) or (veh == bestVeh and d < bestD) then
								best, bestVeh, bestD = e, veh, d
							end
						end
					end
				end
				if IsValid(best) then
					t._nextFire = now + (cfg.reload or 0.6)
					if ME.DamageEnt then ME.DamageEnt(best, cfg.dmg, fac) end
					net.Start("ME_TurretFire")
					net.WriteUInt(t:EntIndex(), 16)
					net.WriteVector(best:GetPos())
					net.WriteInt(fac, 8)
					net.WriteInt((ME.EntFaction and ME.EntFaction(best)) or 0, 8)
					net.Broadcast()
				end
			end
		end
	end
end)

function ME.FindInterceptor(attFac, tpos)
	local now = CurTime()
	for _, m in ipairs(ents.FindByClass("ent_me_building")) do
		if IsValid(m) and m.MEBuilt and m.MEBID == "missile" and (m._nextFire or 0) <= now then
			local cfg = cfgOf(m)
			local fac = m.MEFaction or 0

			if cfg and fac > 0 and fac ~= attFac and not (ME.AreAllied and ME.AreAllied(fac, attFac)) then
				if m:GetPos():Distance(tpos) <= hexRange(cfg.rangeHex or 5) then
					m._nextFire = now + (cfg.reload or 10)
					return m
				end
			end
		end
	end
end
