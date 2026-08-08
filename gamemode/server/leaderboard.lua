
util.AddNetworkString("ME_Leaderboard")

ME.Leaderboard = ME.Leaderboard or {}

function ME.Leaderboard.Build()
    local custom = hook.Run("MEMenu_BuildLeaderboard")
    if istable(custom) then return custom end
    return {}
end

local function send(ply)
    local sp = game.SinglePlayer() or game.MaxPlayers() <= 1
    local payload = { sp = sp }
    if not sp then payload.list = ME.Leaderboard.Build() end
    net.Start("ME_Leaderboard")
    net.WriteString(util.TableToJSON(payload))
    if IsValid(ply) then net.Send(ply) else net.Broadcast() end
end
ME.Leaderboard.Send = send

net.Receive("ME_Leaderboard", function(_, ply)
    if not IsValid(ply) then return end
    ply.MELbNext = ply.MELbNext or 0
    if ply.MELbNext > CurTime() then return end
    ply.MELbNext = CurTime() + 0.5
    send(ply)
end)

timer.Create("ME_Leaderboard_Hourly", 3600, 0, function() send() end)
