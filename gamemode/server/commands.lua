util.AddNetworkString("ME_OrderMove")
util.AddNetworkString("ME_OrderTarget")
util.AddNetworkString("ME_SpawnUnit")
util.AddNetworkString("ME_Forfeit")
util.AddNetworkString("ME_UnitQueue")
util.AddNetworkString("ME_UnitDequeue")

ME.MaxQueue = ME.MaxQueue or 3

for name in pairs(ME.UnitKinds or {}) do
	local m = ME.UnitModel(name)
	if m and util.IsValidModel(m) then util.PrecacheModel(m) end
end

local function playerCore(ply)
	ME.Cores = ME.Cores or {}
	return ME.Cores[ply:Team()]
end

ME.Prod = ME.Prod or {}

local function prodDur(kind) return (ME.GetUnitKind(kind).build or 6) / ME.Speed() end

local function prodSend(faction)
	local plys = team.GetPlayers(faction)
	if #plys == 0 then return end
	local q = ME.Prod[faction]
	local n = (q and #q.items) or 0
	local dur, start = 0, 0
	if n > 0 then
		dur   = prodDur(q.items[1].kind)
		start = q.start or CurTime()
	end
	net.Start("ME_UnitQueue")
	net.WriteUInt(n, 6)
	net.WriteFloat(dur)
	net.WriteFloat(start)
	net.Send(plys)
end


net.Receive("ME_SpawnUnit", function(_, ply)
	if not (IsValid(ply) and ME.MatchActive) then return end
	local t = ply:Team()
	if t < 1 or t > ME.Config.MaxFactions then return end
	local kind = net.ReadString()
	if kind ~= "builder" then return end
	local k = ME.GetUnitKind(kind)
	local core = playerCore(ply)
	if not IsValid(core) then return end
	ME.Prod[t] = ME.Prod[t] or { items = {} }
	local q = ME.Prod[t]
	if #q.items >= ME.MaxQueue then return end

	if not ME.CanAfford(ply, k.cost) then return end
	ME.TakeMoney(ply, k.cost)
	if #q.items == 0 then q.start = CurTime() end
	q.items[#q.items + 1] = { kind = kind, cost = k.cost }
	prodSend(t)
end)

net.Receive("ME_UnitDequeue", function(_, ply)
	if not (IsValid(ply) and ME.MatchActive) then return end
	local t   = ply:Team()
	local idx = net.ReadUInt(6)
	local q   = ME.Prod[t]
	if not (q and q.items[idx]) then return end
	ME.AddMoney(ply, q.items[idx].cost or ME.GetUnitKind(q.items[idx].kind).cost or 0)
	table.remove(q.items, idx)
	if idx == 1 and q.items[1] then q.start = CurTime() end
	prodSend(t)
end)

timer.Create("ME_ProdTick", 0.2, 0, function()
	if not ME.MatchActive then return end
	for faction, q in pairs(ME.Prod) do
		local it = q.items[1]
		if it then
			local core = ME.Cores and ME.Cores[faction]
			if not IsValid(core) then
				ME.Prod[faction] = nil
				prodSend(faction)
			elseif CurTime() - (q.start or CurTime()) >= prodDur(it.kind) then
				local kk = ME.GetUnitKind(it.kind)

				if ME.UnitPop(faction) + (kk.pop or 1) <= ME.UnitMax(faction) then
					local ang = math.rad(math.random(0, 359))
					local pos = core:GetPos() + Vector(math.cos(ang), math.sin(ang), 0) * (ME.Config.HexSize or 96) * 0.95
					local u = ME.SpawnUnit(it.kind, faction, pos)
					if IsValid(u) then u.MEPop = kk.pop or 1; u:OrderMove(u:GetPos()) end
					ME.RefreshPop(faction)
					table.remove(q.items, 1)
					if q.items[1] then q.start = CurTime() end
					prodSend(faction)
				end
			end
		end
	end
end)

util.AddNetworkString("ME_TrainUnit")
util.AddNetworkString("ME_TrainDequeue")
util.AddNetworkString("ME_TrainQueue")

ME.TrainProd = ME.TrainProd or {}
ME.TrainMax  = 5

local function trainDur(kind) return (ME.GetUnitKind(kind).build or 8) / ME.Speed() end

local function trainSend(bidx)
	local ent = Entity(bidx)
	if not IsValid(ent) then return end
	local plys = team.GetPlayers(ent.MEFaction or 0)
	if #plys == 0 then return end
	local q = ME.TrainProd[bidx]
	local n = (q and #q.items) or 0
	net.Start("ME_TrainQueue")
	net.WriteUInt(bidx, 16)
	net.WriteUInt(n, 6)
	for i = 1, n do net.WriteString(q.items[i].kind) end
	net.WriteFloat(n > 0 and trainDur(q.items[1].kind) or 0)
	net.WriteFloat(n > 0 and (q.start or CurTime()) or 0)
	net.Send(plys)
end

net.Receive("ME_TrainUnit", function(_, ply)
	if not (IsValid(ply) and ME.MatchActive) then return end
	local bidx = net.ReadUInt(16)
	local kind = net.ReadString()
	local ent  = Entity(bidx)
	if not (IsValid(ent) and ent:GetClass() == "ent_me_building" and ent.MEBuilt and (ent.MEFaction or 0) == ply:Team()) then return end
	local list = ME.BuildingUnits and ME.BuildingUnits(ent.MEBID)
	if not list then return end
	local ok = false; for _, k in ipairs(list) do if k == kind then ok = true break end end
	if not ok then return end
	local k = ME.GetUnitKind(kind)
	ME.TrainProd[bidx] = ME.TrainProd[bidx] or { items = {} }
	local q = ME.TrainProd[bidx]
	if #q.items >= ME.TrainMax then return end
	if not ME.CanAfford(ply, k.cost) then return end
	ME.TakeMoney(ply, k.cost)
	if #q.items == 0 then q.start = CurTime() end
	q.items[#q.items + 1] = { kind = kind, cost = k.cost }
	trainSend(bidx)
end)

net.Receive("ME_TrainDequeue", function(_, ply)
	if not ME.InMatch(ply) then return end
	if ME.Throttle(ply, "dequeue", 0.1) then return end

	local bidx = net.ReadUInt(16)
	local idx  = net.ReadUInt(6)
	local ent  = Entity(bidx)
	if not (IsValid(ent) and (ent.MEFaction or 0) == ply:Team()) then return end
	local q = ME.TrainProd[bidx]
	if not (q and q.items[idx]) then return end
	ME.AddMoney(ply, q.items[idx].cost or ME.GetUnitKind(q.items[idx].kind).cost or 0)
	table.remove(q.items, idx)
	if idx == 1 and q.items[1] then q.start = CurTime() end
	trainSend(bidx)
end)

timer.Create("ME_TrainTick", 0.2, 0, function()
	if not ME.MatchActive then return end
	for bidx, q in pairs(ME.TrainProd) do
		local ent = Entity(bidx)
		if not (IsValid(ent) and ent.MEBuilt) then
			ME.TrainProd[bidx] = nil
		else
			local it = q.items[1]
			if it and CurTime() - (q.start or CurTime()) >= trainDur(it.kind) then
				local kk, fac = ME.GetUnitKind(it.kind), ent.MEFaction or 0
				if ME.UnitPop(fac) + (kk.pop or 1) <= ME.UnitMax(fac) then
					local ang = math.rad(math.random(0, 359))
					local pos = ent:GetPos() + Vector(math.cos(ang), math.sin(ang), 0) * (ME.Config.HexSize or 96) * 0.95

					local u = ME.SpawnUnit(it.kind, fac, pos)
					if IsValid(u) then u.MEPop = kk.pop or 1; u:OrderMove(u:GetPos()) end
					ME.RefreshPop(fac)
					table.remove(q.items, 1)
					if q.items[1] then q.start = CurTime() end
					trainSend(bidx)
				end
			end
		end
	end
end)

net.Receive("ME_Forfeit", function(_, ply)
	if not (IsValid(ply) and ME.MatchActive) then return end
	if CurTime() - GetGlobalFloat("ME_MatchStartAt", CurTime()) < 15 * 60 then return end
	local core = playerCore(ply)

	if IsValid(core) and not core._meDead then
		core._lastAttFac = 0
		core._meDead = true
		core:MEMeltdown()
	end
end)

local ORDER_RATE = 0.05

local function readUnitIds()
	local count = net.ReadUInt(9)
	if count <= 0 or count > ME.Config.UnitCap then return nil end
	local ids = {}
	for i = 1, count do ids[i] = net.ReadUInt(16) end
	return ids
end

local function gmAll(ply) return IsValid(ply) and ply:IsSuperAdmin() end

local function ownedUnits(ply, ids)
	local out = {}
	local any = gmAll(ply)
	for _, id in ipairs(ids) do
		local u = Entity(id or 0)
		if ME.IsUnit(u) and (any or ME.EntFaction(u) == ply:Team()) then out[#out + 1] = u end
	end
	return out
end

local function gated(ply)
	ply.MENextOrder = ply.MENextOrder or 0
	if ply.MENextOrder > CurTime() then return false end
	ply.MENextOrder = CurTime() + ORDER_RATE
	return true
end

net.Receive("ME_OrderMove", function(_, ply)
	if not ME.MatchActive then return end
	if not IsValid(ply) or ply:Team() == ME.TEAM_SPECTATOR then return end
	if not gated(ply) then return end

	local ids = readUnitIds(); if not ids then return end
	local pos = net.ReadVector()
	if not isvector(pos) then return end

	local q, r = ME.WorldToHex(pos)
	if not (ME.Board and ME.Board.cells and ME.Board.cells[ME.HexKey(q, r)]) then return end

	for _, u in ipairs(ownedUnits(ply, ids)) do
		if u.OrderMove then u:OrderMove(pos, true) end
	end
end)

util.AddNetworkString("ME_OrderBuild")
util.AddNetworkString("ME_OrderStop")
util.AddNetworkString("ME_DeleteUnits")

net.Receive("ME_DeleteUnits", function(_, ply)
	if not ME.MatchActive then return end
	if not IsValid(ply) or ply:Team() == ME.TEAM_SPECTATOR then return end
	local ids = readUnitIds(); if not ids then return end
	for _, u in ipairs(ownedUnits(ply, ids)) do
		ME.NetUnitDied(u:GetPos(), u.MEKind)
		u:Remove()
	end
end)

net.Receive("ME_OrderStop", function(_, ply)
	if not ME.MatchActive then return end
	if not IsValid(ply) or ply:Team() == ME.TEAM_SPECTATOR then return end
	if not gated(ply) then return end
	local ids = readUnitIds(); if not ids then return end
	for _, u in ipairs(ownedUnits(ply, ids)) do
		u.Path, u.MoveTarget, u.Moving, u.GoalQ, u.GoalR = nil, nil, false, nil, nil
		u.BuildTarget, u.Building = nil, false
		ME.NetUnitSync(u)
	end
end)

net.Receive("ME_OrderBuild", function(_, ply)
	if not ME.MatchActive then return end
	if not IsValid(ply) or ply:Team() == ME.TEAM_SPECTATOR then return end
	if not gated(ply) then return end
	local ids = readUnitIds(); if not ids then return end
	local b = Entity(net.ReadUInt(16) or 0)
	if not (IsValid(b) and b:GetClass() == "ent_me_building" and not b.MEBuilt) then return end
	if not gmAll(ply) and (b.MEFaction or 0) ~= ply:Team() then return end

	for _, u in ipairs(ownedUnits(ply, ids)) do
		if u.OrderBuild then u:OrderBuild(b) end
	end
end)

util.AddNetworkString("ME_BargeLoad")
util.AddNetworkString("ME_BargeDrop")
util.AddNetworkString("ME_BargeMsg")

local function bargeMsg(ply, code)
	net.Start("ME_BargeMsg"); net.WriteString(code); net.Send(ply)
end

local function selectedBarges(ply, ids)
	local out = {}
	for _, u in ipairs(ownedUnits(ply, ids)) do if u.MECarrier then out[#out + 1] = u end end
	return out
end

net.Receive("ME_BargeLoad", function(_, ply)
	if not ME.MatchActive then return end
	if not IsValid(ply) or ply:Team() == ME.TEAM_SPECTATOR then return end
	if not gated(ply) then return end
	local ids = readUnitIds(); if not ids then return end
	local n = 0
	for _, b in ipairs(selectedBarges(ply, ids)) do n = n + (b:BargeCallIn() or 0) end
	bargeMsg(ply, n > 0 and "loading" or "noone")
end)

net.Receive("ME_BargeDrop", function(_, ply)
	if not ME.MatchActive then return end
	if not IsValid(ply) or ply:Team() == ME.TEAM_SPECTATOR then return end
	if not gated(ply) then return end
	local ids = readUnitIds(); if not ids then return end
	local landed, why = 0, nil
	for _, b in ipairs(selectedBarges(ply, ids)) do
		local n, w = b:BargeDropOff()
		if n then landed = landed + n else why = why or w end
	end
	bargeMsg(ply, landed > 0 and "landed" or (why or "empty"))
end)

net.Receive("ME_OrderTarget", function(_, ply)
	if not ME.MatchActive then return end
	if not IsValid(ply) or ply:Team() == ME.TEAM_SPECTATOR then return end
	if not gated(ply) then return end

	local ids = readUnitIds(); if not ids then return end
	local target = Entity(net.ReadUInt(16) or 0)
	if not IsValid(target) then return end

	for _, u in ipairs(ownedUnits(ply, ids)) do
		if u.OrderAttack then u:OrderAttack(target) end
	end
end)
