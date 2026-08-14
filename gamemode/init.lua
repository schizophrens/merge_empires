local CLIENT_FILES = {
	"shared.lua",
	"cl_init.lua",
	"config/arena.lua",
	"config/modes.lua",
	"config/menu.lua",
	"config/buildings.lua",
	"config/skins.lua",
	"config/sfx.lua",
	"shared/hexgrid.lua",
	"shared/grass.lua",
	"shared/maplock.lua",
	"client/sfx.lua",
	"client/precache.lua",
	"client/rts_camera.lua",
	"client/board.lua",
	"client/hud_scale.lua",
	"client/hud_roster.lua",
	"client/hud_timer.lua",
	"client/hud_economy.lua",
	"client/hud_guide.lua",
	"client/hud_exit.lua",
	"client/hud_alliance.lua",
	"client/hud_chat.lua",
	"client/hud_minimap.lua",
	"client/hud_scoreboard.lua",
	"client/hud_endscreen.lua",
	"client/hud_custom.lua",
	"client/hud_build.lua",
	"client/build_place.lua",
	"client/hud_barge.lua",
	"client/menu_bridge.lua",
	"menu/camera.lua",
	"menu/state.lua",
	"menu/animations.lua",
	"menu/styles.lua",
	"menu/scripts.lua",
	"menu/markup.lua",
	"menu/html.lua",
	"menu/overlays.lua",
	"menu/player_data.lua",
	"menu/block.lua",
	"menu/flow.lua",
}
for _, f in ipairs(CLIENT_FILES) do AddCSLuaFile(f) end

include("shared.lua")

if not ME.MapOK then return end

include("config/menu.lua")
include("config/buildings.lua")
include("config/skins.lua")
include("config/sfx.lua")

include("server/security.lua")
include("server/mapgen.lua")
include("server/economy.lua")
include("server/building.lua")
include("server/commands.lua")
include("server/matchmaking.lua")
include("server/party.lua")
include("server/session.lua")
include("server/reconnect.lua")
include("server/chat.lua")
include("server/leaderboard.lua")
include("server/stats.lua")
include("server/matchstats.lua")
include("server/servers.lua")
include("server/gems.lua")
include("server/shop.lua")
include("server/inventory.lua")
include("server/roster.lua")
include("server/alliance.lua")
include("server/net_strings.lua")
include("server/resources.lua")
include("server/intro_lockdown.lua")
include("server/cloak.lua")
include("server/structures.lua")

ME.Used = ME.Used or {}

function ME.FactionReserved(i)
	if not ME.Reconnect then return false end
	for _, e in pairs(ME.Reconnect) do if e.faction == i then return true end end
	return false
end

function ME.AssignFaction(ply)
	for i = 1, ME.Config.MaxFactions do

		if not IsValid(ME.Used[i]) and not ME.FactionReserved(i) then
			ME.Used[i] = ply
			ply:SetTeam(i)
			return i
		end
	end
	ply:SetTeam(ME.TEAM_SPECTATOR)
	return ME.TEAM_SPECTATOR
end

function GM:PlayerInitialSpawn(ply)

	local sid = ply:SteamID64()
	if ME.Reconnect and sid and ME.Reconnect[sid] then
		ME.InitMoney(ply)
		return
	end
	ME.AssignFaction(ply)
	ME.InitMoney(ply)
end

function GM:PlayerSpawn(ply)
	if ply:Team() == ME.TEAM_SPECTATOR then
		ply:Spectate(OBS_MODE_ROAMING)
		ply:SetMoveType(MOVETYPE_NOCLIP)
		return
	end

	ply:UnSpectate()
	ply:SetMoveType(MOVETYPE_NOCLIP)
	ply:GodEnable()
	ply:Freeze(true)
	ply:SetNotSolid(true)
	if ME.ApplyCloak then ME.ApplyCloak(ply) end

	if ME.IsInMenu and ME.IsInMenu(ply) then
		local spots = MEConfig and MEConfig.MainMenu and MEConfig.MainMenu.LobbySpots
		if spots and #spots > 0 then
			local idx = ((ply:Team() - 1) % #spots) + 1
			local spot = spots[idx]
			ply:SetPos(spot.pos)
			ply:SetAngles(spot.ang)
		end
		return
	end

	local sp = ME.GetSpawnFor(ply:Team())
	if sp then ply:SetPos(sp + Vector(0, 0, 1800)) end
end

function GM:PlayerLoadout(ply)
	ply:StripWeapons()
	return true
end

function GM:PlayerDeath() end
function GM:PlayerDeathThink() return false end

function GM:SpawnMenuEnabled() return false end
function GM:PhysgunPickup() return false end

function GM:PlayerDisconnected(ply)
	for i, p in pairs(ME.Used) do
		if p == ply then ME.Used[i] = nil end
	end
end

ME.MatchActive = false

function ME.GetSpawnFor(faction)
	return ME.Map and ME.Map.spawns and ME.Map.spawns[faction]
end

function ME.SpawnCores()
	ME.Cores = {}
	for i = 1, ME.Config.MaxFactions do
		local pos = ME.GetSpawnFor(i)
		if pos then
			local core = ents.Create("ent_me_core")
			if IsValid(core) then
				local f = ME.GetFaction(i)
				if f and f.core then core:SetModel(f.core) end
				core:SetPos(pos + Vector(0, 0, 1))
				core:SetAngles(Angle(0, i * 90, 0))
				if ME.Config.CoreScale and ME.Config.CoreScale ~= 1 then core:SetModelScale(ME.Config.CoreScale, 0) end
				core:Spawn()
				if core.SetFaction then core:SetFaction(i) end
				core.MEFaction = i
				ME.Cores[i] = core
			end
		end
	end
end

function ME.StartMatch()
	ME.ClearArena()
	ME.GenerateArena()
	ME.SpawnCores()
	ME.SpawnDefaults()
	ME.MatchActive = false
	SetGlobalInt("ME_ActiveMatches", 1)
	SetGlobalFloat("ME_Speed", ME.ModeSpeed((ME.MM and ME.MM.CurrentMode) or "casual"))

	for _, ply in ipairs(player.GetAll()) do
		if not (ME.IsInMenu and ME.IsInMenu(ply)) then
			local sp = ME.GetSpawnFor(ply:Team())
			if sp then ply:SetPos(sp + Vector(0, 0, 1800)) end
		end
		ME.SetMoney(ply, ME.Config.StartMoney)
		ply:SetNWInt("ME_Income", ME.Config.BaseIncome)
		ply:SetNWInt("ME_Units", 0)
		ply:SetNWInt("ME_UnitMax", (ME.Config and ME.Config.UnitMax) or 10)
	end

	if ME.BuildRoster then ME.BuildRoster() end
	if ME.SendRoster then ME.SendRoster() end

	local dur = (ME.Config and ME.Config.StartCountdown) or 30
	SetGlobalInt("ME_MatchPhase", 1)
	SetGlobalFloat("ME_CountdownEnd", CurTime() + dur)
	SetGlobalFloat("ME_MatchStartAt", 0)
	timer.Create("ME_StartCountdown", dur, 1, function()
		if ME.BeginMatch then ME.BeginMatch() end
	end)
end

function ME.SpawnDefaults()
	if not (ME.Board and ME.Board.cells) then return end
	local usedSlot = {}
	for i = 1, ME.Config.MaxFactions do
		local core = ME.Cores and ME.Cores[i]
		if IsValid(core) then
			local base = core:GetPos()
			if ME.SpawnUnit then
				local a = math.rad(i * 47 + 20)
				ME.SpawnUnit("builder", i, base + Vector(math.cos(a), math.sin(a), 0) * (ME.Config.HexSize or 96) * 1.15)
			end
			local cq, cr = ME.WorldToHex(base)
			local best, bd
			for _, cell in pairs(ME.Board.cells) do
				if cell.decor == "slot" and not usedSlot[ME.HexKey(cell.q, cell.r)] then
					local d = ME.HexDistance(cell.q, cell.r, cq, cr)
					if not bd or d < bd then bd, best = d, cell end
				end
			end
			if best then
				usedSlot[ME.HexKey(best.q, best.r)] = true
				local z   = (ME.Board.baseZ or base.z) + (ME.SurfaceOffset(best.q, best.r, best.biome) or 0)
				local ent = ents.Create("ent_me_building")
				if IsValid(ent) then
					ent:SetBuilding("farm", i)
					ent:SetPos(ME.HexToWorld(best.q, best.r, z))
					ent:SetAngles(Angle(0, math.random(0, 5) * 60, 0))
					ent:Spawn()
					ent:MEConstruct()
					if ME.NetBuilding then ME.NetBuilding(ent) end
				end
			end
		end
	end
end

function ME.BeginMatch()
	if GetGlobalInt("ME_MatchPhase", 0) ~= 1 then return end
	ME.MatchActive = true
	SetGlobalInt("ME_MatchPhase", 2)
	SetGlobalFloat("ME_MatchStartAt", CurTime())

	if ME.RefreshPop then for i = 1, (ME.Config.MaxFactions or 6) do ME.RefreshPop(i) end end
	if ME.MSReset then ME.MSReset() end
	hook.Run("ME_MatchBegan")
end

util.AddNetworkString("ME_CoreLost")
util.AddNetworkString("ME_CoreExplode")
util.AddNetworkString("ME_FactionWipe")
util.AddNetworkString("ME_CoreBurn")
util.AddNetworkString("ME_CoreMeltdown")
util.AddNetworkString("ME_LeaveToLobby")
util.AddNetworkString("ME_Spectate")

function ME.NetCoreExplode(pos, faction)
	net.Start("ME_CoreExplode")
	net.WriteVector(pos)
	net.WriteInt(faction or 0, 8)
	net.Broadcast()
end

function ME.NetFactionWipe(faction)
	net.Start("ME_FactionWipe"); net.WriteInt(faction, 8); net.Broadcast()
end

ME.CoreBurnHP = 500

function ME.NetCoreBurn(ent)
	if not IsValid(ent) then return end
	net.Start("ME_CoreBurn"); net.WriteUInt(ent:EntIndex(), 16); net.Broadcast()
end

ME.BurnTime = 3.2

ME.MeltdownTime = 3

function ME.OnCoreMeltdown(faction, pos)
	net.Start("ME_CoreMeltdown")
	net.WriteVector(pos)
	net.WriteInt(faction or 0, 8)
	net.WriteFloat(ME.MeltdownTime or 3)
	net.Broadcast()

	for _, ply in ipairs(team.GetPlayers(faction)) do
		if IsValid(ply) then
			ply._meDefeated = true
			net.Start("ME_CoreLost"); net.WriteVector(pos); net.Send(ply)
		end
	end
end

function ME.KillFactionUnits(faction)
	local n = 0
	for _, e in ipairs(ents.FindByClass("ent_me_unit")) do
		if IsValid(e) and ME.EntFaction(e) == faction then
			n = n + 1
			local pos, kind = e:GetPos(), e.MEKind
			timer.Simple(math.min(2.2, n * 0.06), function()
				ME.NetUnitDied(pos, kind)
				if IsValid(e) then e:Remove() end
			end)
		end
	end
	return n
end

function ME.OnCoreDestroyed(faction, pos)
	ME.Cores = ME.Cores or {}
	ME.Cores[faction] = nil

	if ME.ClearReconnectForFaction then ME.ClearReconnectForFaction(faction) end
	pos = pos or ME.GetSpawnFor(faction) or Vector(0, 0, 0)

	if ME.Roster and ME.Roster[faction] then ME.Roster[faction].connected = false; if ME.SendRoster then ME.SendRoster() end end

	if ME.KillFactionUnits then ME.KillFactionUnits(faction) end

	local aliveF = {}
	for i = 1, ME.Config.MaxFactions do
		if ME.FactionInPlay(i) and IsValid(ME.Cores and ME.Cores[i]) then aliveF[#aliveF + 1] = i end
	end
	local over = #aliveF <= 1 or (#aliveF == 2 and ME.AreAllied(aliveF[1], aliveF[2]))
	for _, ply in ipairs(team.GetPlayers(faction)) do
		if IsValid(ply) and ME.SendMatchEnd then ME.SendMatchEnd(ply, "defeat", not over) end
	end

	if ME.NetFactionWipe then ME.NetFactionWipe(faction) end
	local doomed = {}
	for _, e in ipairs(ents.FindByClass("ent_me_building")) do
		if IsValid(e) and ME.EntFaction(e) == faction then doomed[#doomed + 1] = e end
	end
	for i, e in ipairs(doomed) do
		local delay = (i - 1) * 0.14
		timer.Simple(ME.BurnTime + delay, function() if IsValid(e) then e:Remove() end end)
	end
	ME.CheckWin()
end

local function toSpectator(ply)
	ply:SetTeam(ME.TEAM_SPECTATOR or 100)
	ply:Spectate(OBS_MODE_ROAMING)
	ply:SpectateEntity(NULL)
end

net.Receive("ME_LeaveToLobby", function(_, ply)
	if not IsValid(ply) then return end

	local wasDefeated = ply._meDefeated
	ply._meDefeated = nil
	local SS = ME.Session

	local pending = GetGlobalInt("ME_MatchPhase", 0) >= 1
	if not wasDefeated and pending and SS and SS.active then
		if SS.kind == "mm" and ME.Reconnect_OnLeave and ME.Reconnect_OnLeave(ply) then

			ply:SetTeam(ME.TEAM_SPECTATOR or 100)
		elseif ME.MatchActive then

			local core = ME.Cores and ME.Cores[ply:Team()]
			if IsValid(core) and not core._meDead then
				core._meDead     = true
				core._lastAttFac = 0
				if core.MEMeltdown then core:MEMeltdown() end
			end
		end
	end

	if ME.RosterMarkGone then ME.RosterMarkGone(ply) end
	if ME.ReturnToMenu then ME.ReturnToMenu(ply) else toSpectator(ply) end
	if SS then SS.RemovePlayer(ply) end
end)
net.Receive("ME_Spectate", function(_, ply)
	if not IsValid(ply) or not ply._meDefeated then return end
	ply._meDefeated = nil
	if ME.RosterMarkSpectating then ME.RosterMarkSpectating(ply) end
	toSpectator(ply)
	if ME.Session then ME.Session.AddSpectator(ply) end
end)

function ME.CheckWin()
	if not ME.MatchActive then return end
	local aliveF = {}
	for i = 1, ME.Config.MaxFactions do
		if ME.FactionInPlay(i) and IsValid(ME.Cores and ME.Cores[i]) then aliveF[#aliveF + 1] = i end
	end

	local done = #aliveF <= 1
		or (#aliveF == 2 and ME.AreAllied(aliveF[1], aliveF[2]))
	if done then
		ME.MatchActive = false
		if ME.ClearAllReconnects then ME.ClearAllReconnects() end

		local mode = (ME.MM and ME.MM.CurrentMode) or "casual"
		for _, f in ipairs(aliveF) do
			for _, p in ipairs(team.GetPlayers(f)) do
				if IsValid(p) then
					if ME.Stats then ME.Stats.AddWin(p, mode, 1) end

					if ME.SendMatchEnd then ME.SendMatchEnd(p, "victory", false) end
				end
			end
		end

		SetGlobalInt("ME_MatchPhase", 0)

		if not (ME.Session and ME.Session.active) then
			SetGlobalInt("ME_ActiveMatches", 0)
			timer.Simple(8, function()
				if not ME.MatchActive then
					ME.ClearArena()
					if ME.MM and ME.MM.OnMatchEnded then ME.MM.OnMatchEnded() end
				end
			end)
		elseif ME.Session.HumanCount and ME.Session.HumanCount() == 0 then

			timer.Simple(6, function()
				if ME.Session and ME.Session.active and not ME.MatchActive and ME.Session.HumanCount() == 0 then
					ME.Session.End()
				end
			end)
		end
	end
end

hook.Add("InitPostEntity", "ME_Boot", function()
	SetGlobalInt("ME_ActiveMatches", 0)
	SetGlobalInt("ME_MatchPhase", 0)
end)

