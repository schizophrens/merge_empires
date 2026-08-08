
util.AddNetworkString("ME_Servers")
util.AddNetworkString("ME_Servers_Spectate")
util.AddNetworkString("ME_Custom_Spectate")

ME.Servers = ME.Servers or {}

function ME.Servers.Build()
    local custom = hook.Run("MEMenu_BuildServers")
    if istable(custom) then return custom end
    return {}
end

local function send(ply)
    local sp = game.SinglePlayer() or game.MaxPlayers() <= 1
    local payload = { sp = sp }
    if not sp then payload.list = ME.Servers.Build() end
    net.Start("ME_Servers")
    net.WriteString(util.TableToJSON(payload))
    if IsValid(ply) then net.Send(ply) else net.Broadcast() end
end
ME.Servers.Send = send

net.Receive("ME_Servers", function(_, ply)
    if not IsValid(ply) then return end
    ply.MESvNext = ply.MESvNext or 0
    if ply.MESvNext > CurTime() then return end
    ply.MESvNext = CurTime() + 0.5
    send(ply)
end)

net.Receive("ME_Servers_Spectate", function(_, ply)
    if ME.Throttle(ply, "spec", 1) then return end
    hook.Run("MEMenu_Spectate", ply, net.ReadString())
end)

net.Receive("ME_Custom_Spectate", function(_, ply)
    if ME.Throttle(ply, "speccode", 1) then return end
    local code = net.ReadString()
    if hook.Run("MEMenu_SpectateCode", ply, code) then return end
    net.Start("ME_Party_Toast")
    net.WriteString("No custom match with that code to spectate.")
    net.Send(ply)
end)
