
local M = MEMenu
local S = M._State
local jsq = M._JSQ

local mathFloor = math.floor
local mathMax = math.max
local strFormat = string.format

local function readLevelingValues(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return 0, 1, 1 end
    local cur, mx, lvl
    if GlorifiedLeveling then
        lvl = GlorifiedLeveling.GetPlayerLevel and GlorifiedLeveling.GetPlayerLevel(ply) or ply:GetNWInt("GlorifiedLeveling.Level", 1)
        cur = GlorifiedLeveling.GetPlayerXP    and GlorifiedLeveling.GetPlayerXP(ply)    or ply:GetNWInt("GlorifiedLeveling.XP", 0)
        mx  = GlorifiedLeveling.GetPlayerMaxXP and GlorifiedLeveling.GetPlayerMaxXP(ply) or 1
    else
        lvl = ply:GetNWInt("GlorifiedLeveling.Level", 1)
        cur = ply:GetNWInt("GlorifiedLeveling.XP", 0)
        local lvlSafe = mathMax(1, lvl)
        mx = (100 + (lvlSafe * (lvlSafe + 1) * 75))
    end
    return tonumber(cur) or 0, mathMax(1, tonumber(mx) or 1), mathMax(1, tonumber(lvl) or 1)
end

local function readPlayerMoney(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return 0 end
    if ply.getDarkRPVar then
        local m = ply:getDarkRPVar("money")
        if m ~= nil then return tonumber(m) or 0 end
    end
    if ply.GetMoney then
        local m = ply:GetMoney()
        if m ~= nil then return tonumber(m) or 0 end
    end
    local m = ply:GetNWInt("money", -1)
    if m >= 0 then return m end
    return 0
end

local function readPlayerKills(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return 0 end
    if ply.GetTotalKills then
        local k = ply:GetTotalKills()
        if k and k > 0 then return tonumber(k) or 0 end
    end
    local nw = ply:GetNWInt("TotalKills", -1)
    if nw >= 0 then return nw end
    return (isfunction(ply.Frags) and ply:Frags()) or 0
end

local function readPlayerDeaths(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return 0 end
    if ply.GetTotalDeaths then
        local d = ply:GetTotalDeaths()
        if d and d > 0 then return tonumber(d) or 0 end
    end
    local nw = ply:GetNWInt("TotalDeaths", -1)
    if nw >= 0 then return nw end
    return (isfunction(ply.Deaths) and ply:Deaths()) or 0
end

local PLAYTIME_NW_KEYS = { "UTimeTotalTime", "Playtime", "PlayTime", "TotalTime" }
local function readPlayerPlaytime(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return 0 end
    if ply.GetUTimeTotalTime then
        local t = ply:GetUTimeTotalTime()
        if t and t > 0 then return tonumber(t) or 0 end
    end
    if ply.GetPlayTime then
        local t = ply:GetPlayTime()
        if t and t > 0 then return tonumber(t) or 0 end
    end
    for i = 1, #PLAYTIME_NW_KEYS do
        local v = ply:GetNWInt(PLAYTIME_NW_KEYS[i], 0)
        if v > 0 then return v end
    end
    return (isfunction(ply.TimeConnected) and ply:TimeConnected()) or 0
end

function M.RefreshXP()
    if not IsValid(S.panel) then return end
    local cur, mx, lvl = readLevelingValues(LocalPlayer())
    S.panel:RunJavascript(strFormat("try{CineAPI.setXP(%d,%d,%d)}catch(e){}",
        mathFloor(cur), mathFloor(mx), mathFloor(lvl)))
end

function M.RefreshMoney()
    if not IsValid(S.panel) then return end
    S.panel:RunJavascript(strFormat("try{CineAPI.setMoney(%d)}catch(e){}",
        mathFloor(readPlayerMoney(LocalPlayer()))))
end

function M.SetMoney(n)
    if not IsValid(S.panel) then return end
    S.panel:RunJavascript(strFormat("try{CineAPI.setMoney(%d)}catch(e){}",
        mathFloor(tonumber(n) or 0)))
end

function M.RefreshProfileCard()
    if not IsValid(S.panel) then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local name     = (isfunction(ply.SteamName) and ply:SteamName()) or (isfunction(ply.Nick) and ply:Nick()) or ""
    local avatar   = S.steamAvatarURL or ""
    local kills    = readPlayerKills(ply)
    local deaths   = readPlayerDeaths(ply)
    local playtime = readPlayerPlaytime(ply)
    S.panel:RunJavascript(strFormat(
        "try{CineAPI.setProfileStats(%s,%s,%d,%d,%d)}catch(e){}",
        jsq(name), jsq(avatar),
        mathFloor(kills), mathFloor(deaths), mathFloor(playtime)
    ))
end

local function getMapPlayerCount(mapKey)
    local custom = hook.Run("MEMenu_GetMapPlayerCount", mapKey)
    if custom ~= nil then return mathMax(0, mathFloor(tonumber(custom) or 0)) end
    local count = 0
    local lp = LocalPlayer()
    local players = player.GetAll()
    for i = 1, #players do
        local ply = players[i]
        if IsValid(ply) and ply ~= lp and not ply:GetNWBool("MEInMenu", false) then
            count = count + 1
        end
    end
    return count
end

function M.RefreshMapPlayers()
    if not IsValid(S.panel) then return end
    local desert = getMapPlayerCount("desert")
    S.panel:RunJavascript(strFormat("try{CineAPI.setMapPlayers('desert',%d)}catch(e){}", desert))
end

function M.RefreshLobby()
    if not IsValid(S.panel) then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local frag     = mathMax(0, ply:GetNWInt("ME_Fragments", 0))
    local gem      = mathMax(0, ply:GetNWInt("ME_Gems", 0))

    local matches = hook.Run("MEMenu_GetActiveMatches")
    if matches == nil then matches = #player.GetAll() end

    local multiplayer = not game.SinglePlayer()
    S.panel:RunJavascript(strFormat("try{CineAPI.setMultiplayer(%s)}catch(e){}", multiplayer and "true" or "false"))

    S.panel:RunJavascript(strFormat("try{CineAPI.showReconnect(%s)}catch(e){}", S.canRejoin and "true" or "false"))

    S.panel:RunJavascript(strFormat("try{CineAPI.setCurrencies(%d,%d)}catch(e){}", frag, gem))
    S.panel:RunJavascript(strFormat("try{CineAPI.setActiveMatches(%d)}catch(e){}", mathFloor(tonumber(matches) or 0)))

    local name = (isfunction(ply.SteamName) and ply:SteamName()) or (isfunction(ply.Nick) and ply:Nick()) or ""
    if name ~= "" then
        S.panel:RunJavascript("try{CineAPI.setSteamProfile(" .. jsq(name) .. "," .. jsq(S.steamAvatarURL or "") .. ")}catch(e){}")
    end
end

function M._FetchSteamProfile()
    if S.steamFetchInflight or S.steamAvatarURL then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not isfunction(ply.SteamID64) then return end
    local sid = ply:SteamID64()
    if not sid or sid == "" or sid == "0" then return end
    S.steamFetchInflight = true
    local url = "https://steamcommunity.com/profiles/" .. sid .. "?xml=1"
    http.Fetch(url, function(body)
        S.steamFetchInflight = false
        if not body then return end
        local avatar = string.match(body, "<avatarFull><!%[CDATA%[(.-)%]%]></avatarFull>")
                    or string.match(body, "<avatarFull>(.-)</avatarFull>")
        if not avatar then return end
        S.steamAvatarURL = avatar
        local name = (IsValid(ply) and isfunction(ply.SteamName) and ply:SteamName()) or (IsValid(ply) and isfunction(ply.Nick) and ply:Nick()) or ""
        if IsValid(S.panel) and S.htmlReady then
            S.panel:RunJavascript("try{CineAPI.setSteamProfile(" .. jsq(name) .. "," .. jsq(avatar) .. ")}catch(e){}")
            if M.RefreshProfileCard then M.RefreshProfileCard() end
        end
    end, function()
        S.steamFetchInflight = false
    end)
end

hook.Add("GlorifiedLeveling.XPUpdated", "ME_XPSync", function(ply)
    if ply ~= LocalPlayer() then return end
    if IsValid(S.panel) and S.menuActive then M.RefreshXP() end
end)

hook.Add("GlorifiedLeveling.LevelUp", "ME_LevelSync", function(ply)
    if ply ~= LocalPlayer() then return end
    if IsValid(S.panel) and S.menuActive then M.RefreshXP() end
end)

hook.Add("DarkRPVarChanged", "ME_MoneySync", function(ply, varName)
    if varName ~= "money" then return end
    if ply ~= LocalPlayer() then return end
    if IsValid(S.panel) and S.menuActive then M.RefreshMoney() end
end)

timer.Create("ME_MapPlayersRefresh", 6, 0, function()
    if S.menuActive and M.RefreshMapPlayers then M.RefreshMapPlayers() end
end)
