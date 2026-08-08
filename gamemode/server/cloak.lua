
ME = ME or {}

function ME.ApplyCloak(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if ply:Team() == ME.TEAM_SPECTATOR then return end
    ply:SetNoDraw(true)
    ply:SetNoTarget(true)
    ply:DrawShadow(false)
end

function ME.CloakAll()
    local players = player.GetAll()
    for i = 1, #players do
        ME.ApplyCloak(players[i])
    end
end

hook.Add("PlayerSpawn", "ME_Cloak_OnSpawn", function(ply)
    timer.Simple(0, function() ME.ApplyCloak(ply) end)
end)

hook.Add("PlayerInitialSpawn", "ME_Cloak_OnJoin", function(ply)
    timer.Simple(0.1, function() ME.ApplyCloak(ply) end)
end)

timer.Create("ME_CloakHeartbeat", 1, 0, function()
    ME.CloakAll()
end)
