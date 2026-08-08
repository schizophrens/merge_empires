function ME.InitMoney(ply)  ply:SetNWInt("ME_Money", ME.Config.StartMoney) end
function ME.GetMoney(ply)   return ply:GetNWInt("ME_Money", 0) end
function ME.SetMoney(ply, n) ply:SetNWInt("ME_Money", math.max(0, math.floor(n))) end
function ME.AddMoney(ply, n) ME.SetMoney(ply, ME.GetMoney(ply) + n) end

function ME.AddFactionMoney(faction, n)
	for _, ply in ipairs(team.GetPlayers(faction)) do ME.AddMoney(ply, n) end
end
function ME.CanAfford(ply, n) return ME.GetMoney(ply) >= n end

function ME.TakeMoney(ply, n)
	if ME.CanAfford(ply, n) then
		ME.SetMoney(ply, ME.GetMoney(ply) - n)
		return true
	end
	return false
end

function ME.BuildingCounts(faction)
	local counts = {}
	for _, e in ipairs(ents.FindByClass("ent_me_building")) do
		if (e.MEFaction or 0) == faction then counts[e.MEBID or ""] = (counts[e.MEBID or ""] or 0) + 1 end
	end
	return counts
end

function ME.PlayerIncome(faction)
	local per = (ME.Config.IncomeInterval or 3) / 60
	local inc = ME.Config.BaseIncome
	for _, e in ipairs(ents.FindByClass("ent_me_building")) do
		if (e.MEFaction or 0) == faction and e.MEBuilt then
			local b = ME.GetBuilding(e.MEBID or "")
			if b and b.cat == "income" and (b.income or 0) > 0 then inc = inc + b.income * per end
		end
	end
	return inc * ME.Speed()
end

ME.UnitSlotsPerHouse = ME.UnitSlotsPerHouse or 5
ME.PopHardCap        = ME.PopHardCap or 40
ME.CoreKills         = ME.CoreKills or {}
ME.HousesPerCoreKill = ME.HousesPerCoreKill or 4

function ME.HouseBonus(faction)
	return (ME.CoreKills[faction] or 0) * ME.HousesPerCoreKill
end

function ME.BuildingMaxFor(faction, id)
	local b = ME.GetBuilding and ME.GetBuilding(id)
	local m = (b and b.max) or 0
	if m > 0 and id == "house" then m = m + ME.HouseBonus(faction) end
	return m
end

function ME.UnitMax(faction)
	local houses = 0
	for _, e in ipairs(ents.FindByClass("ent_me_building")) do
		if (e.MEFaction or 0) == faction and e.MEBuilt and (e.MEBID == "house") then houses = houses + 1 end
	end

	local extra = ME.HouseBonus(faction) * ME.UnitSlotsPerHouse
	return math.min(ME.PopHardCap + extra, (ME.Config.UnitMax or 10) + houses * ME.UnitSlotsPerHouse)
end

function ME.UnitPop(faction)
	local n = 0
	for _, u in ipairs(ents.FindByClass("ent_me_unit")) do
		if ME.EntFaction(u) == faction then n = n + (u.MEPop or 1) end
	end
	return n
end

function ME.RefreshPop(faction)
	local umax, pop = ME.UnitMax(faction), ME.UnitPop(faction)
	local hb = ME.HouseBonus(faction)
	for _, ply in ipairs(team.GetPlayers(faction)) do
		ply:SetNWInt("ME_Units", pop)
		ply:SetNWInt("ME_UnitMax", umax)
		ply:SetNWInt("ME_HouseBonus", hb)
	end
end

function ME.RefreshIncome(faction)
	local inc = math.floor(ME.PlayerIncome(faction) + 0.5)
	for _, ply in ipairs(team.GetPlayers(faction)) do ply:SetNWInt("ME_Income", inc) end
end

local ACCRUE = 0.5

ME.FacMoneyAcc = ME.FacMoneyAcc or {}

timer.Create("ME_Income", ACCRUE, 0, function()
	if not ME.MatchActive then return end
	local per = ME.Config.IncomeInterval or 3

	for fac = 1, ME.Config.MaxFactions do
		local plys     = team.GetPlayers(fac)
		local inMatch  = (ME.Roster and ME.Roster[fac] ~= nil) or #plys > 0
		if inMatch then
			local inc = ME.PlayerIncome(fac)
			for _, ply in ipairs(plys) do
				ply:SetNWInt("ME_Income", math.floor(inc + 0.5))
			end

			ME.FacMoneyAcc[fac] = (ME.FacMoneyAcc[fac] or 0) + inc * (ACCRUE / per)
			local whole = math.floor(ME.FacMoneyAcc[fac])
			if whole > 0 then
				ME.FacMoneyAcc[fac] = ME.FacMoneyAcc[fac] - whole
				if ME.MSAddIncome then ME.MSAddIncome(fac, whole) end
				for _, ply in ipairs(plys) do ME.AddMoney(ply, whole) end
			end

			ME.RefreshPop(fac)
		end
	end
end)
