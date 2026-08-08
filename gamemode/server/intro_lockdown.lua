
local NS = MEConfig.NetStrings
local svCfg = MEConfig.Server
local introDur = svCfg.IntroDuration or 15.0

local states = {}
ME._DevFreed = ME._DevFreed or {}

function ME.ForceExitIntroState(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    states[sid] = nil
    ME._DevFreed[sid] = true
end

function ME.IsInMenu(ply)
    if not IsValid(ply) then return false end
    return states[ply:SteamID()] ~= nil
end

function ME.ReturnToMenu(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    states[sid] = { intro = false, menu = true, t = CurTime() }

    ply:UnSpectate()
    ply:SetMoveType(MOVETYPE_NOCLIP)
    if ply.GodEnable then ply:GodEnable() end
    ply:Freeze(true)
    ply:SetNotSolid(true)
    if ME.ApplyCloak then ME.ApplyCloak(ply) end

    local menuCfg = MEConfig.MainMenu or {}
    local sp = menuCfg.SpawnPoint
    local pos = sp and sp.pos or Vector(400.028748, 3492.190186, -10605.968750)
    local ang = sp and sp.ang or Angle(3.167944, -90.585991, 0)
    timer.Simple(0.05, function()
        if not IsValid(ply) then return end
        ply:SetPos(pos)
        ply:SetEyeAngles(ang)
    end)

end

local cachedConfigJSON
local function getConfigJSON()
    if cachedConfigJSON then return cachedConfigJSON end
    cachedConfigJSON = util.TableToJSON({
        intro = MEConfig.Intro,
    }) or "{}"
    return cachedConfigJSON
end

local function cloakPlayer(ply)
    if not IsValid(ply) then return end
    ply:SetNoDraw(true)
    ply:SetNoTarget(true)
    ply:DrawShadow(false)
    ply:Freeze(true)
    if ply.GodEnable then ply:GodEnable() end
end

hook.Add("PlayerInitialSpawn", "ME_PlayerJoin", function(ply)
    if not IsValid(ply) then return end

    local sid = ply:SteamID()
    states[sid] = { intro = true, menu = true, t = CurTime() }

    net.Start(NS.Config)
    net.WriteString(getConfigJSON())
    net.Send(ply)

    net.Start(NS.Start)
    net.Send(ply)

    timer.Simple(introDur + 5, function()
        if not states[sid] then return end
        states[sid].intro = false
    end)
end)

hook.Add("SetupMove", "ME_BlockMove", function(ply, mv)
    local s = states[ply:SteamID()]
    if not s or not s.intro then return end
    mv:SetMaxSpeed(0)
    mv:SetMaxClientSpeed(0)
    mv:SetButtons(0)
end)

net.Receive(NS.PlayerReady, function(_, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    local s = states[sid]
    if not s then return end
    s.intro = false

    local menuCfg = MEConfig.MainMenu or {}
    local sp = menuCfg.SpawnPoint
    local pos = sp and sp.pos or Vector(400.028748, 3492.190186, -10605.968750)
    local ang = sp and sp.ang or Angle(3.167944, -90.585991, 0)

    timer.Simple(0.05, function()
        if not IsValid(ply) then return end
        ply:SetPos(pos)
        ply:SetEyeAngles(ang)
        ply:SetVelocity(-ply:GetVelocity())
    end)
end)

net.Receive(NS.Stop, function(_, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    states[sid] = nil

    if ME._DevFreed[sid] then
        ME._DevFreed[sid] = nil
        return
    end

    if ply:Team() == (ME.TEAM_SPECTATOR or 100) then return end

    if ME.MatchActive then
        cloakPlayer(ply)
        timer.Simple(0.05, function()
            if not IsValid(ply) then return end
            local sp = ME.GetSpawnFor(ply:Team())
            if sp then ply:SetPos(sp + Vector(0, 0, 1800)) end
        end)
    end
end)

hook.Add("PlayerDisconnected", "ME_CleanupState", function(ply)
    if not IsValid(ply) then return end
    states[ply:SteamID()] = nil
end)

hook.Add("onNotify", "ME_BlockDarkRPNotify", function(ply)
    if not IsValid(ply) then return end
    local st = states[ply:SteamID()]
    if st and st.menu then return true end
end)
