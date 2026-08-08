
util.AddNetworkString("ME_InvSync")
util.AddNetworkString("ME_InvEquip")
util.AddNetworkString("ME_InvBuy")

ME.Inv = ME.Inv or {}

local DIR = "mergeempires/inv"
local function pathFor(sid) return DIR .. "/" .. sid .. ".json" end

local function load(sid)
	local raw = file.Read(pathFor(sid), "DATA")
	local t   = raw and util.JSONToTable(raw) or nil
	if not istable(t) then t = {} end
	t.owned    = istable(t.owned)    and t.owned    or {}
	t.equipped = istable(t.equipped) and t.equipped or {}
	return t
end

local function save(sid)
	local rec = ME.Inv[sid]; if not rec then return end
	file.CreateDir("mergeempires")
	file.CreateDir(DIR)
	file.Write(pathFor(sid), util.TableToJSON({ owned = rec.owned, equipped = rec.equipped }))
end

local function recOf(ply)
	local sid = IsValid(ply) and ply:SteamID64()
	if not sid or sid == "0" then return nil end
	if not ME.Inv[sid] then ME.Inv[sid] = load(sid) end
	return ME.Inv[sid], sid
end

local function pushEquippedNW(ply, rec)
	for item in pairs(ME.SkinnableItems and ME.SkinnableItems() or {}) do
		ply:SetNWString("ME_Skin_" .. item, rec.equipped[item] or "")
	end
end

local function syncTo(ply, rec)
	net.Start("ME_InvSync")
	net.WriteString(util.TableToJSON({ owned = rec.owned, equipped = rec.equipped }))
	net.Send(ply)
end

function ME.InvSync(ply)
	local rec = recOf(ply); if not rec then return end
	pushEquippedNW(ply, rec)
	syncTo(ply, rec)
end

function ME.SkinnedModel(faction, itemKey, baseModel)
	local ply = ME.Used and ME.Used[faction]
	if not IsValid(ply) or not ply:IsPlayer() then return baseModel end
	local skinId = ply:GetNWString("ME_Skin_" .. itemKey, "")
	if skinId == "" then return baseModel end
	local s = ME.GetSkin and ME.GetSkin(skinId)
	return (s and s.model) or baseModel
end

net.Receive("ME_InvEquip", function(_, ply)
	if ME.Throttle(ply, "equip", 0.3) then return end

	local rec, sid = recOf(ply); if not rec then return end
	local itemKey = net.ReadString()
	local skinId  = net.ReadString()

	if rec.equipped[itemKey] == (skinId ~= "" and skinId or nil) then return end

	if skinId == "" then
		rec.equipped[itemKey] = nil
	else
		local s = ME.GetSkin(skinId)
		if not s or s.item ~= itemKey or not rec.owned[skinId] then return end
		rec.equipped[itemKey] = skinId
	end
	pushEquippedNW(ply, rec)
	save(sid)
	syncTo(ply, rec)
end)

net.Receive("ME_InvBuy", function(_, ply)
	ply.MEInvBuyNext = ply.MEInvBuyNext or 0
	if ply.MEInvBuyNext > CurTime() then return end
	ply.MEInvBuyNext = CurTime() + 0.4

	local rec, sid = recOf(ply); if not rec then return end
	local s = ME.GetSkin(net.ReadString())
	if not s then return end
	if rec.owned[s.id] then return end
	if not ME.TakeGems(ply, s.price or 0) then
		net.Start("ME_Notify"); net.WriteString("Not enough gems."); net.WriteBool(false); net.Send(ply)
		return
	end
	rec.owned[s.id] = true
	save(sid)
	syncTo(ply, rec)
	net.Start("ME_Notify"); net.WriteString("Skin unlocked! Equip it in your inventory."); net.WriteBool(true); net.Send(ply)
end)

hook.Add("PlayerInitialSpawn", "ME_Inv_Load", function(ply)
	timer.Simple(1.5, function() if IsValid(ply) then ME.InvSync(ply) end end)
end)

