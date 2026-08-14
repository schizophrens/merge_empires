
util.AddNetworkString("ME_Chat")
util.AddNetworkString("ME_ChatSys")

function ME.ChatSystem(text, color)
    if not text or text == "" then return end
    color = color or Color(210, 214, 220)
    net.Start("ME_ChatSys")
    net.WriteString(text)
    net.WriteUInt(math.Clamp(math.floor(color.r or 210), 0, 255), 8)
    net.WriteUInt(math.Clamp(math.floor(color.g or 214), 0, 255), 8)
    net.WriteUInt(math.Clamp(math.floor(color.b or 220), 0, 255), 8)
    local rec = ME.Session and ME.Session.active and ME.Session.Recipients and ME.Session.Recipients()
    if rec and #rec > 0 then net.Send(rec) else net.Broadcast() end
end

local cooldown = {}

local maxLen = (MEConfig.Chat and MEConfig.Chat.MaxLength) or 50

local banSet = {}
for _, w in ipairs((MEConfig.Chat and MEConfig.Chat.BanWords) or {}) do
    banSet[string.lower(w)] = true
end

local function censor(text)
    return (string.gsub(text, "%S+", function(word)
        local clean = string.match(string.lower(word), "^%p*(.-)%p*$")
        if clean and clean ~= "" and banSet[clean] then
            return string.rep("*", utf8.len(clean) or #clean)
        end
        return word
    end))
end

local function canSay(ply)
    local now = SysTime()
    if (cooldown[ply] or 0) > now then return false end
    cooldown[ply] = now + 0.66
    return true
end

local function isSpectating(ply)
    local SS = ME.Session
    return (SS and SS.active and SS.spectators and SS.spectators[ply]) and true or false
end

net.Receive("ME_Chat", function(_, ply)
    if not IsValid(ply) then return end
    local t = ply:Team()
    if (t < 1 or t > ((ME.Config and ME.Config.MaxFactions) or 6)) and not isSpectating(ply) then return end
    if not canSay(ply) then return end

    local text = string.sub(net.ReadString() or "", 1, maxLen)
    text = hook.Run("PlayerSay", ply, text, false)
    if type(text) ~= "string" or text == "" then return end
    text = censor(text)

    if game.IsDedicated() then ServerLog(ply:Nick() .. ": " .. text .. "\n") end

    local omit, n = {}, 0
    for _, target in ipairs(player.GetAll()) do
        if target ~= ply and hook.Run("PlayerCanSeePlayersChat", text, false, target, ply) == false then
            n = n + 1
            omit[n] = target
        end
    end

    net.Start("ME_Chat")
    net.WriteEntity(ply)
    net.WriteString(text)
    net.SendOmit(omit)
end)

hook.Add("PlayerInitialSpawn", "ME_Chat_Color", function(ply)
    if not IsValid(ply) then return end
    ply:SetNWInt("ME_ChatColor", math.random(#ME.BeamColors))
end)

hook.Add("PlayerDisconnected", "ME_Chat_Cleanup", function(ply)
    cooldown[ply] = nil
end)

