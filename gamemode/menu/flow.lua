
local M = MEMenu
local S = M._State
local NS = MEConfig.NetStrings
local jsq = M._JSQ

local mathPow = math.pow
local function easeInOutCubic(x)
    return x < 0.5 and 4 * x * x * x or 1 - mathPow(-2 * x + 2, 3) * 0.5
end

local function fadeOutChan(chan, dur, onDone)
    if not IsValid(chan) then if onDone then onDone() end return end
    local startVol = chan:GetVolume() or 0.55
    local startT = CurTime()
    local id = "ME_BgmFadeOut_" .. tostring(SysTime())
    hook.Add("Think", id, function()
        if not IsValid(chan) then
            hook.Remove("Think", id)
            if onDone then onDone() end
            return
        end
        local frac = (CurTime() - startT) / dur
        if frac >= 1 then
            chan:Stop()
            hook.Remove("Think", id)
            if onDone then onDone() end
            return
        end
        chan:SetVolume(startVol * (1 - frac))
    end)
end

function M.Finish()
    if timer.Exists("ME_MenuActiveRefresh") then timer.Remove("ME_MenuActiveRefresh") end
    S.introActive    = false
    S.titleActive    = false
    S.titleSpaceArmed = false
    S.titleExitStart  = nil
    S.titleEnterStart = nil
    S.titleLoadingStart = nil
    S.titleManualFade = nil
    S.menuActive      = false
    if MECamera then MECamera.Stop() end
    if S.introSound then S.introSound:Stop() S.introSound = nil end
    if S.titleBgmChan then
        if IsValid(S.titleBgmChan) then S.titleBgmChan:Stop() end
        S.titleBgmChan = nil
    end
    if IsValid(S.panel)            then S.panel:Remove()            S.panel = nil            end
    if IsValid(S.blurPanel)        then S.blurPanel:Remove()        S.blurPanel = nil        end
    if IsValid(S.titleFadePanel)   then S.titleFadePanel:Remove()   S.titleFadePanel = nil   end
    if IsValid(S.introBlackPanel)  then S.introBlackPanel:Remove()  S.introBlackPanel = nil  end
    if IsValid(S.playerModelPanel) then S.playerModelPanel:Remove() S.playerModelPanel = nil end
    if IsValid(S.menuDarkPanel)    then S.menuDarkPanel:Remove()    S.menuDarkPanel = nil    end
    S.introBlackActive = false
    gui.EnableScreenClicker(false)
    net.Start(NS.Stop)
    net.SendToServer()
end

function M.StartTitleScreen()
    if not IsValid(S.panel) then return end
    if S.titleActive then return end
    S.titleActive    = true
    S.titleStartedAt = CurTime()
    S.titleSpaceArmed   = false
    S.titleSpaceWasDown = input.IsKeyDown(KEY_SPACE)

    S.introBlackActive = false
    if IsValid(S.introBlackPanel) then S.introBlackPanel:SetVisible(false) end
    if IsValid(S.blurPanel)       then S.blurPanel:SetVisible(false)       end

    M._EnsureTitleFadePanel()
    S.titleFadePanel:SetVisible(true)

    if MECamera and MECamera.StartLoop then
        MECamera.StartLoop()
    end

    S.panel:RunJavascript("CineAPI.showTitleScreen()")
    S.panel:RunJavascript("CineAPI.blackFadeOut(900)")

    local vol = M._titleCfg.MusicVolume or 0.55
    sound.PlayFile(MEConfig.Assets.SoundIntro, "mono noplay noblock", function(chan)
        if not IsValid(chan) then return end
        if not S.titleActive then chan:Stop() return end
        S.titleBgmChan = chan
        chan:SetVolume(vol)
        chan:EnableLooping(true)
        chan:Play()
    end)

    timer.Simple(0.6, function()
        if S.titleActive then S.titleSpaceArmed = true end
    end)
end

function M.FinishTitleScreen()
    if not S.titleActive then return end
    S.titleSpaceArmed = false
    if S.titleExitStart then return end
    S.titleExitDur      = M._titleCfg.ExitFadeDuration or 1.8
    S.titleEnterDur     = M._menuCfg.LoadingFadeInDuration or 1.4
    S.titleLoadingDur   = M._menuCfg.LoadingHoldDuration or 7.0
    S.titleExitFromAlpha = (MECamera and MECamera.GetFadeAlpha and MECamera.GetFadeAlpha()) or 0
    S.titleExitStart    = CurTime()
    S.titleManualFade   = S.titleExitFromAlpha
    if IsValid(S.panel) then
        S.panel:RunJavascript("try{CineAPI.fadeOutTitleTexts()}catch(e){}")
    end
    if S.titleBgmChan and IsValid(S.titleBgmChan) then
        fadeOutChan(S.titleBgmChan, S.titleExitDur)
        S.titleBgmChan = nil
    end
end

local function enterLoadingPhase()
    S.titleActive    = false
    S.titleManualFade = 1
    if IsValid(S.panel) then
        S.panel:RunJavascript("CineAPI.hideTitleScreen()")
        S.panel:RunJavascript("CineAPI.setLoadingStatus('Loading data')")
        S.panel:RunJavascript("CineAPI.showLoadingScreen()")
    end
    if MECamera then MECamera.Stop() end
    S.titleLoadingStart = CurTime()
    M._FetchSteamProfile()
    net.Start(NS.PlayerReady)
    net.SendToServer()
    M._PrecacheLoadingPhase()
    if ME.Precache then ME.Precache.Menu() end
end

local function enterMenuPhase()
    S.titleLoadingStart = nil
    if IsValid(S.panel) then
        S.panel:RunJavascript("CineAPI.hideLoadingScreen()")
        S.panel:RunJavascript("CineAPI.showMainMenu()")
        S.panel:SetMouseInputEnabled(true)
        if S.panel.MakePopup then S.panel:MakePopup() end
        S.panel:SetKeyboardInputEnabled(false)
    end
    if MECamera and MECamera.StartStatic then MECamera.StartStatic() end
    if IsValid(S.blurPanel) then S.blurPanel:SetVisible(true) end
    gui.EnableScreenClicker(true)
    S.blurOverlayAlpha  = 0
    S.blurOverlayTarget = 0
    S.menuActive = true

    net.Start("ME_MM_Request")
    net.SendToServer()

    net.Start("ME_Party_Request")
    net.SendToServer()

    net.Start("ME_Leaderboard")
    net.SendToServer()

    net.Start("ME_Stats")
    net.SendToServer()

    if S.modeWinsJSON and IsValid(S.panel) then
        S.panel:RunJavascript("try{CineAPI.setModeWins(" .. jsq(S.modeWinsJSON) .. ")}catch(e){}")
    end

    M._FetchSteamProfile()
    if M.RefreshLobby then M.RefreshLobby() end
    timer.Simple(0.25, function() if S.menuActive and M.RefreshLobby then M.RefreshLobby() end end)
    timer.Simple(0.9,  function() if S.menuActive and M.RefreshLobby then M.RefreshLobby() end end)

    timer.Create("ME_MenuActiveRefresh", 3, 0, function()
        if not S.menuActive or not IsValid(S.panel) then return end
        local m = hook.Run("MEMenu_GetActiveMatches") or 0
        S.panel:RunJavascript(string.format("try{CineAPI.setActiveMatches(%d)}catch(e){}", math.floor(tonumber(m) or 0)))
        local lp = LocalPlayer()
        if IsValid(lp) then
            local frag = math.max(0, lp:GetNWInt("ME_Fragments", 0))
            local gem  = math.max(0, lp:GetNWInt("ME_Gems", 0))
            S.panel:RunJavascript(string.format("try{CineAPI.setCurrencies(%d,%d)}catch(e){}", frag, gem))
        end
    end)

    local menuVol = M._titleCfg.MusicVolume or 0.55
    sound.PlayFile(MEConfig.Assets.SoundBackground, "mono noplay noblock", function(chan)
        if not IsValid(chan) then return end
        S.titleBgmChan = chan
        chan:SetVolume(menuVol)
        chan:EnableLooping(true)
        chan:Play()
    end)
    S.titleEnterStart = CurTime()
end

hook.Add("Think", "ME_TitleStateMachine", function()
    if S.titleExitStart then
        local frac = (CurTime() - S.titleExitStart) / S.titleExitDur
        if frac >= 1 then
            S.titleExitStart = nil
            S.titleManualFade = 1
            enterLoadingPhase()
        else
            local e = easeInOutCubic(frac)
            S.titleManualFade = S.titleExitFromAlpha + (1 - S.titleExitFromAlpha) * e
        end
    end
    if S.titleLoadingStart then
        if CurTime() - S.titleLoadingStart >= S.titleLoadingDur then
            enterMenuPhase()
        end
    end
    if S.titleEnterStart then
        local frac = (CurTime() - S.titleEnterStart) / S.titleEnterDur
        if frac >= 1 then
            S.titleEnterStart = nil
            S.titleManualFade = nil
            if IsValid(S.titleFadePanel) then S.titleFadePanel:SetVisible(false) end
            S.introActive = false
        else
            S.titleManualFade = 1 - easeInOutCubic(frac)
        end
    end
end)

hook.Add("Think", "ME_TitleSpaceInput", function()
    if not S.titleActive then return end
    local down = input.IsKeyDown(KEY_SPACE)
    if S.titleSpaceArmed and down and not S.titleSpaceWasDown then
        S.titleSpaceArmed = false
        M.FinishTitleScreen()
    end
    S.titleSpaceWasDown = down
end)

local function bindPanelCallbacks(panel)
    panel:AddFunction("CineEvent", "OpenURL", function(url) gui.OpenURL(url) end)
    panel:AddFunction("CineEvent", "TabClick", function() end)
    panel:AddFunction("CineEvent", "OpenWorldClick", function() end)
    panel:AddFunction("CineEvent", "GameModeClick", function() end)
    panel:AddFunction("CineEvent", "GameModeDenied", function() end)
    panel:AddFunction("CineEvent", "OpenWorldOpen", function()
        M._HidePlayerModelPanel()
        if M.RefreshMapPlayers then M.RefreshMapPlayers() end
    end)
    panel:AddFunction("CineEvent", "OpenWorldClose", function()
        M._ShowPlayerModelPanel()
    end)
    panel:AddFunction("CineEvent", "MapClick", function(mapKey)
        mapKey = tostring(mapKey or "")
        M._ShowPlayerModelPanel()
        hook.Run("MEMenu_MapClick", mapKey)
        timer.Create("ME_SpawnSearch_" .. mapKey, 8, 1, function()
            if not S.menuActive then return end
            hook.Run("MEMenu_MapStart", mapKey)
        end)
    end)
    panel:AddFunction("CineEvent", "StoreOpen", function() end)

    panel:AddFunction("CineEvent", "SetMode", function(mode)
        net.Start("ME_Party_SetMode")
        net.WriteString(tostring(mode or "casual"))
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "PartyQueue", function(on)
        net.Start("ME_Party_Queue")
        net.WriteBool(on and true or false)
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "PartyLeave", function()
        net.Start("ME_Party_Leave")
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "PartyJoin", function(code)
        net.Start("ME_Party_Join")
        net.WriteString(tostring(code or ""))
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "PartyInvite", function(sid)
        net.Start("ME_Party_Invite")
        net.WriteString(tostring(sid or ""))
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "PartyKick", function(sid)
        net.Start("ME_Party_Kick")
        net.WriteString(tostring(sid or ""))
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "Rejoin", function()
        S.canRejoin = false
        net.Start("ME_Rejoin")
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "PartyRefresh", function()
        net.Start("ME_Party_Request")
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "KbOn",  function()
        if IsValid(S.panel) then
            S.panel:SetKeyboardInputEnabled(true)
            S.panel:RequestFocus()
        end
    end)
    panel:AddFunction("CineEvent", "KbOff", function() if IsValid(S.panel) then S.panel:SetKeyboardInputEnabled(false) end end)
    panel:AddFunction("CineEvent", "ChatOpen",  function()
        if not IsValid(S.panel) then return end
        S.panel:SetKeyboardInputEnabled(true)
        S.panel:RequestFocus()
    end)
    panel:AddFunction("CineEvent", "ChatClose", function() if IsValid(S.panel) then S.panel:SetKeyboardInputEnabled(false) end end)
    panel:AddFunction("CineEvent", "ChatSend", function(text)
        text = string.Trim(tostring(text or ""))
        if text == "" then return end
        net.Start("ME_Chat")
        net.WriteString(string.sub(text, 1, (MEConfig.Chat and MEConfig.Chat.MaxLength) or 50))
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "Nav",        function() end)
    panel:AddFunction("CineEvent", "Sub",        function(sub)
        sub = tostring(sub)
        if sub == "leaderboard" then
            net.Start("ME_Leaderboard")
            net.SendToServer()
        elseif sub == "servers" then
            net.Start("ME_Servers")
            net.SendToServer()
        end
    end)
    panel:AddFunction("CineEvent", "CustomCreate", function(mode)
        net.Start("ME_Custom_Create")
        net.WriteString(tostring(mode or "casual"))
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "JoinCustomMatch", function(code)
        net.Start("ME_Custom_Join")
        net.WriteString(tostring(code or ""))
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "Spectate", function(mid)
        net.Start("ME_Servers_Spectate")
        net.WriteString(tostring(mid or ""))
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "SpectateCode", function(code)
        net.Start("ME_Custom_Spectate")
        net.WriteString(tostring(code or ""))
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "ShopOpen", function()
        if not IsValid(S.panel) then return end
        sound.PlayFile("sound/mergeempires/menu/shop_open.mp3", "noplay noblock", function(chan)
            if IsValid(chan) then chan:SetVolume(0.6) chan:Play() end
        end)
        S.panel:RunJavascript("try{CineAPI.setShopSkins(" .. jsq(M._BuildShopSkins()) .. ")}catch(e){}")
        S.panel:RunJavascript("try{CineAPI.setShopGems(" .. jsq(M._BuildShopGems()) .. ")}catch(e){}")
    end)
    panel:AddFunction("CineEvent", "InventoryOpen", function()
        M.RefreshInventory()
    end)

    panel:AddFunction("CineEvent", "InvEquip", function(payload)
        local item, skin = string.match(tostring(payload or ""), "^(.-)|(.*)$")
        if not item or item == "" then return end
        if ME and ME.Sfx then ME.Sfx.Play2D("inv_equip") end
        net.Start("ME_InvEquip")
        net.WriteString(item)
        net.WriteString(skin or "")
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "ShopBuy", function(id)
        id = tostring(id or "")
        if ME.GetSkin and ME.GetSkin(id) then
            net.Start("ME_InvBuy"); net.WriteString(id); net.SendToServer()
            return
        end
        net.Start("ME_Shop_Buy")
        net.WriteString(id)
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "GemBuy", function(id)
        net.Start("ME_Shop_Gem")
        net.WriteString(tostring(id or ""))
        net.SendToServer()
    end)
    panel:AddFunction("CineEvent", "MenuAction", function() end)

    panel:AddFunction("CineReady", "Set", function()
        S.htmlReady = true
        timer.Simple(0, function()
            if not S.introActive or S.introStarted then return end
            S.introStarted = true

            local intro = M._introCfg
            local pegiDur = intro.PegiDuration or 4.4
            local esrbDur = intro.EsrbDuration or 4.1
            local gap     = intro.Gap or 1.1
            local endGap  = intro.EndGap or 0.5
            local sfxVol  = intro.SfxVolume or 0.85
            local totalIntroDuration = intro.TotalDuration or (pegiDur + gap + esrbDur + endGap + 1.5)

            if MECamera then MECamera.SetIntroDuration(totalIntroDuration) end

            panel:RunJavascript("CineAPI.black(true)")
            panel:RunJavascript("CineAPI.blackLevel(1)")
            panel:RunJavascript("CineAPI.showLogo(" .. jsq(MEConfig.Assets.ImagePegi) .. ")")

            sound.PlayFile(MEConfig.Assets.SoundPegi, "mono", function(chan)
                if IsValid(chan) then chan:SetVolume(sfxVol) chan:Play() end
            end)

            timer.Simple(pegiDur, function()
                if not IsValid(panel) then return end
                panel:RunJavascript("CineAPI.hideLogo()")
            end)

            timer.Simple(pegiDur + gap, function()
                if not IsValid(panel) then return end
                panel:RunJavascript("CineAPI.showLogo(" .. jsq(MEConfig.Assets.ImageEsrb) .. ")")
                sound.PlayFile(MEConfig.Assets.SoundEsrb, "mono", function(chan)
                    if IsValid(chan) then chan:SetVolume(sfxVol) chan:Play() end
                end)
            end)

            timer.Simple(pegiDur + gap + esrbDur, function()
                if not IsValid(panel) then return end
                panel:RunJavascript("(function(){var r=document.getElementById('rating'),i=document.getElementById('ratingImg');if(r)r.style.display='none';if(i){i.style.opacity='0';i.src=''}})()")
                S.blurOverlayTarget = 0
                if M.StartTitleScreen then M.StartTitleScreen() end
            end)
        end)
    end)
end

function M.StartIntro()
    if S.introActive then return end
    ME.MenuActive = true
    S.introActive = true
    S.blurOverlayAlpha  = 235
    S.blurOverlayTarget = 235
    if MECamera then MECamera.Start() end

    S.introBlackActive = true
    M._EnsureIntroBlackPanel()
    S.introBlackPanel:SetVisible(true)

    if not IsValid(S.panel) then
        local panel = vgui.Create("DHTML")
        panel:SetSize(ScrW(), ScrH())
        panel:SetPos(0, 0)
        panel:SetMouseInputEnabled(true)
        panel:SetKeyboardInputEnabled(false)
        panel:SetZPos(9000)

        panel.OnMouseWheeled = function(self, delta)
            self:RunJavascript("if(window.chatWheel)chatWheel(" .. (-delta * 70) .. ")")
            return true
        end

        bindPanelCallbacks(panel)

        panel:SetHTML(M._BuildHTML())
        panel:SetVisible(true)
        S.panel = panel
    end

    M._EnsureBlurPanel()
end

function M.ReturnToLobby()
    if timer.Exists("ME_MenuActiveRefresh") then timer.Remove("ME_MenuActiveRefresh") end
    if timer.Exists("ME_ReturnLobbyWait")   then timer.Remove("ME_ReturnLobbyWait")   end

    S.introActive       = false
    S.introStarted      = false
    S.titleActive       = false
    S.titleSpaceArmed   = false
    S.titleExitStart    = nil
    S.titleEnterStart   = nil
    S.titleLoadingStart = nil
    S.titleManualFade   = nil
    S.introBlackActive  = false
    S.menuActive        = false
    ME.MenuActive       = true

    if IsValid(S.introBlackPanel) then S.introBlackPanel:SetVisible(false) end
    if IsValid(S.titleFadePanel)  then S.titleFadePanel:SetVisible(false)  end

    if not IsValid(S.panel) then
        S.htmlReady = false
        local panel = vgui.Create("DHTML")
        panel:SetSize(ScrW(), ScrH())
        panel:SetPos(0, 0)
        panel:SetMouseInputEnabled(true)
        panel:SetKeyboardInputEnabled(false)
        panel:SetZPos(9000)
        panel.OnMouseWheeled = function(self, delta)
            self:RunJavascript("if(window.chatWheel)chatWheel(" .. (-delta * 70) .. ")")
            return true
        end
        bindPanelCallbacks(panel)
        panel:SetHTML(M._BuildHTML())
        panel:SetVisible(true)
        S.panel = panel
    end

    M._EnsureBlurPanel()
    S.blurOverlayAlpha, S.blurOverlayTarget = 0, 0

    local waited = 0
    timer.Create("ME_ReturnLobbyWait", 0.1, 0, function()
        if not IsValid(S.panel) then timer.Remove("ME_ReturnLobbyWait") return end
        waited = waited + 0.1
        if S.htmlReady or waited >= 6 then
            timer.Remove("ME_ReturnLobbyWait")
            enterMenuPhase()
        end
    end)
end

net.Receive(NS.Config, function()
    local raw = net.ReadString()
    local data = util.JSONToTable(raw)
    if not data then return end
    if data.intro then MEConfig.Intro = data.intro end
    M._ReloadConfig()
end)

net.Receive(NS.Start, function()
    M.StartIntro()
end)

local MODE_LABELS = {
    casual = "CASUAL", blitz = "BLITZ", ambush = "AMBUSH", duel = "DUEL", ranked = "RANKED",
}

local function modeLabel(mode)
    mode = string.lower(string.Trim(tostring(mode or "")))
    return MODE_LABELS[mode] or string.upper(mode ~= "" and mode or "CASUAL")
end

function M.OnMatchFound(mode)
    if not IsValid(S.panel) then
        hook.Run("MEMenu_MapStart", "queue")
        return
    end

    local mlCfg   = (M._menuCfg and M._menuCfg.MatchLoading) or {}
    local minDur  = tonumber(mlCfg.MinDuration) or 4.0
    local mapName = mlCfg.MapName or "ARENA"

    local banner  = M._ModeBanner(mode)
    if banner == "" then banner = mlCfg.Banner or "" end

    S.panel:RunJavascript("try{CineAPI.matchFound()}catch(e){}")
    S.panel:RunJavascript("try{CineAPI.hideMainMenu()}catch(e){}")
    S.panel:RunJavascript(string.format("try{CineAPI.showMatchLoad(%s,%s,%s)}catch(e){}",
        jsq(mapName), jsq(modeLabel(mode)), jsq(banner)))

    M._MatchWarmAssets()
    if ME.Precache then ME.Precache.Match() end

    local startedAt = CurTime()
    timer.Remove("ME_MatchLoadWatch")
    timer.Create("ME_MatchLoadWatch", 0.1, 0, function()
        if not IsValid(S.panel) then timer.Remove("ME_MatchLoadWatch") return end
        local ready   = ME.MapInfo ~= nil and ME.MapInfo.spawns ~= nil
        local elapsed = CurTime() - startedAt
        if not (elapsed >= minDur and ready) then return end
        timer.Remove("ME_MatchLoadWatch")

        local fadeBlack = tonumber(mlCfg.FadeBlack) or 0.7
        local wakeFade  = tonumber(mlCfg.WakeFade)  or 1.7
        S.panel:RunJavascript(string.format("try{CineAPI.matchLoadToBlack(%d)}catch(e){}",
            math.floor(fadeBlack * 1000)))
        timer.Simple(fadeBlack, function()
            if ME.StartWakeFade then ME.StartWakeFade(wakeFade) end
            hook.Run("MEMenu_MapStart", "queue")
        end)
    end)
end

net.Receive("ME_MM_Counts", function()
    local json = net.ReadString()
    if IsValid(S.panel) then
        S.panel:RunJavascript("try{CineAPI.setModeCounts(" .. jsq(json) .. ")}catch(e){}")
    end
end)

S.modeWinsJSON = S.modeWinsJSON or "{}"
net.Receive("ME_Stats", function()
    local json = net.ReadString()
    S.modeWinsJSON = json
    if IsValid(S.panel) then
        S.panel:RunJavascript("try{CineAPI.setModeWins(" .. jsq(json) .. ")}catch(e){}")
    end
end)

net.Receive("ME_Party_State", function()
    local json = net.ReadString()
    if IsValid(S.panel) then
        S.panel:RunJavascript("try{CineAPI.setLobby(" .. jsq(json) .. ")}catch(e){}")
    end

    local data = util.JSONToTable(json)
    if data and data.members and M._FetchAvatar then
        for _, m in ipairs(data.members) do
            if m.sid64 and m.sid64 ~= "" and m.sid64 ~= "0" then M._FetchAvatar(m.sid64) end
        end
    end
end)

net.Receive("ME_Party_Toast", function()
    local msg = net.ReadString()
    if IsValid(S.panel) then
        S.panel:RunJavascript("try{CineAPI.toast(" .. jsq(msg) .. ")}catch(e){}")
    end
end)

net.Receive("ME_Party_Players", function()
    local json = net.ReadString()
    if IsValid(S.panel) then
        S.panel:RunJavascript("try{CineAPI.setPlayers(" .. jsq(json) .. ")}catch(e){}")
    end
    local list = util.JSONToTable(json)
    if list and M._FetchAvatar then
        for _, p in ipairs(list) do
            if p.sid64 and p.sid64 ~= "" and p.sid64 ~= "0" then M._FetchAvatar(p.sid64) end
        end
    end
end)

net.Receive("ME_MM_Found", function()
    local mode = net.ReadString()
    M.OnMatchFound(mode)
end)

net.Receive("ME_CanRejoin", function()
    local can = net.ReadBool()
    net.ReadFloat()
    S.canRejoin = can
    if IsValid(S.panel) then
        S.panel:RunJavascript("try{CineAPI.showReconnect(" .. (can and "true" or "false") .. ")}catch(e){}")
    end
end)

function M.OpenChat()
    if not IsValid(S.panel) then return end
    S.panel:SetKeyboardInputEnabled(true)
    S.panel:RunJavascript("try{CineAPI.chatFocus()}catch(e){}")
end

S.chatAvatars = S.chatAvatars or {}

function M._PushAvatar(sid, url)
    if not (IsValid(S.panel) and sid and url) then return end
    for _, fn in ipairs({ "chatAvatar", "lbdAvatar", "svAvatar", "frAvatar", "lbMemberAvatar" }) do
        S.panel:RunJavascript("try{CineAPI." .. fn .. "(" .. jsq(sid) .. "," .. jsq(url) .. ")}catch(e){}")
    end
end

local function fetchChatAvatar(sid)
    if not sid or sid == "" or sid == "0" then return end
    if S.chatAvatars[sid] == false then return end
    if S.chatAvatars[sid] then M._PushAvatar(sid, S.chatAvatars[sid]) return end
    S.chatAvatars[sid] = false
    http.Fetch("https://steamcommunity.com/profiles/" .. sid .. "?xml=1", function(body)
        if not body then S.chatAvatars[sid] = nil return end
        local avatar = string.match(body, "<avatarFull><!%[CDATA%[(.-)%]%]></avatarFull>")
                    or string.match(body, "<avatarFull>(.-)</avatarFull>")
        if not avatar then S.chatAvatars[sid] = nil return end
        S.chatAvatars[sid] = avatar
        M._PushAvatar(sid, avatar)
    end, function() S.chatAvatars[sid] = nil end)
end
M._FetchAvatar = fetchChatAvatar

function M._MatchWarmAssets()
    local cfg = ME.Config or {}
    for _, list in pairs(cfg.Models or {}) do
        if istable(list) then
            for _, mdl in ipairs(list) do util.PrecacheModel(mdl) end
        end
    end
    for _, mdl in pairs(cfg.Buildings or {}) do util.PrecacheModel(mdl) end
    for _, f in ipairs(ME.Factions or {}) do
        if f.core and f.core ~= "" then util.PrecacheModel(f.core) end
    end
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and isfunction(ply.SteamID64) then
            local sid = ply:SteamID64()
            if sid and sid ~= "" and sid ~= "0" then fetchChatAvatar(sid) end
        end
    end
end

local ME_MENU_ASSET_BASE = "asset://garrysmod/materials/mergeempires/"
local ME_MAT_BASE        = "materials/mergeempires/"

local _MENU_ICONS = {
    "menu/me_house.png",    "menu/me_fragment.png",  "menu/me_gem.png",
    "menu/me_crown.png",    "menu/me_arrow_up.png",  "menu/me_eye.png",
    "menu/me_check.png",    "menu/me_trophee.png",   "menu/me_world.png",
    "menu/me_losange_bleu.png", "menu/me_losange_orange.png",
    "banner/me_banner_casual.png",
    "banner/me_banner_blitz.png",
    "intro/pegi.png",       "intro/esrb.png",
}

function M._PrecacheLoadingPhase()
    local panel = S.panel

    for i = 0, 10 do
        Material(ME_MAT_BASE .. string.format("rank/badge_%02d.png", i))
    end
    for _, rel in ipairs(_MENU_ICONS) do
        Material(ME_MAT_BASE .. rel)
    end
    if MEConfig.Shop and istable(MEConfig.Shop.Gems) then
        for _, p in ipairs(MEConfig.Shop.Gems) do
            if p.icon and p.icon ~= "" then
                Material(ME_MAT_BASE .. "menu/" .. p.icon)
            end
        end
    end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            local mdl = ply:GetModel()
            if mdl and mdl ~= "" then util.PrecacheModel(mdl) end
        end
    end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            local sid = ply:SteamID64()
            if sid and sid ~= "" then fetchChatAvatar(sid) end
        end
    end

    if not IsValid(panel) then return end

    panel:RunJavascript("try{CineAPI.setShopSkins("  .. jsq(M._BuildShopSkins())  .. ")}catch(e){}")
    panel:RunJavascript("try{CineAPI.setShopGems("   .. jsq(M._BuildShopGems())   .. ")}catch(e){}")

    local urls = {}
    for i = 0, 10 do
        urls[#urls+1] = ME_MENU_ASSET_BASE .. string.format("rank/badge_%02d.png", i)
    end
    for _, rel in ipairs(_MENU_ICONS) do
        urls[#urls+1] = ME_MENU_ASSET_BASE .. rel
    end
    if MEConfig.Shop and istable(MEConfig.Shop.Gems) then
        for _, p in ipairs(MEConfig.Shop.Gems) do
            if p.icon and p.icon ~= "" then
                urls[#urls+1] = ME_MENU_ASSET_BASE .. "menu/" .. p.icon
            end
        end
    end
    panel:RunJavascript("try{CineAPI.precache(" .. jsq(util.TableToJSON(urls)) .. ")}catch(e){}")

    local loadCfg = M._menuCfg and M._menuCfg.LoadingMessages or {}
    local holdDur = M._menuCfg and M._menuCfg.LoadingHoldDuration or 5.0
    local msgs = {
        { holdDur * 0.20, "Caching assets"    },
        { holdDur * 0.45, "Fetching profiles" },
        { holdDur * 0.70, loadCfg.joining_lobby or "Creating lobby" },
    }
    for _, pair in ipairs(msgs) do
        local delay, msg = pair[1], pair[2]
        timer.Simple(delay, function()
            if IsValid(S.panel) and S.titleLoadingStart then
                S.panel:RunJavascript("try{CineAPI.setLoadingStatus(" .. jsq(msg) .. ")}catch(e){}")
            end
        end)
    end
end

local LB_RANK_BASE = "asset://garrysmod/materials/mergeempires/rank/"
local LB_SP_MSG = "You must be on a multiplayer server, not singleplayer, so that player data can be generated to populate the leaderboard."

local function lbEsc(s)
    s = tostring(s or "")
    s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
    return s
end

local function lbComma(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local k
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end

local function lbBadge(idx)
    idx = math.Clamp(math.floor(tonumber(idx) or 0), 0, 10)
    return LB_RANK_BASE .. string.format("badge_%02d.png", idx)
end

local function lbMessageHTML(msg)
    return '<div class="lbdEmpty">' .. lbEsc(msg) .. "</div>"
end

local function lbRowsHTML(list)
    if not istable(list) or #list == 0 then
        return lbMessageHTML("No ranked players yet. Check back soon.")
    end
    local b = {}
    for i, e in ipairs(list) do
        local style = ""
        if e.avatar and e.avatar ~= "" then
            style = " style=\"background-image:url('" .. e.avatar .. "')\""
        end
        b[#b + 1] = table.concat({
            '<div class="lbdRow" data-sid="', lbEsc(e.steamid or ""), '">',
            '<div class="lbdC-rank">', tostring(i), "</div>",
            '<div class="lbdC-rating"><img class="lbdBadge" src="', lbBadge(e.rank), '"><span class="lbdScore">', lbComma(e.rating), "</span></div>",
            '<div class="lbdC-player"><div class="lbdAvatar"', style, '></div><div class="lbdName">', lbEsc(e.name), "</div></div>",
            '<div class="lbdC-wl">', lbEsc(e.wl or "0%"), "</div>",
            '<div class="lbdC-wins">', lbComma(e.wins), "</div>",
            "</div>",
        })
    end
    return table.concat(b)
end

local SHOP_GEM_ICON = "asset://garrysmod/materials/mergeempires/menu/me_gem.png"

function M._BuildShopSkins()
    local skins = ME.Skins or {}
    if #skins == 0 then return '<div class="shopEmpty">No skins available yet.</div>' end
    local iconOf = ME.BuildIconSrc
    local owned  = M._InvOwnedSet or {}
    local rows   = {}
    for i = 1, #skins, 4 do
        local cards = {}
        for j = i, math.min(i + 3, #skins) do
            local s     = skins[j]
            local src   = iconOf and iconOf("skin_" .. s.id)
            local thumb = src and (' style="background-image:url(\'' .. src .. '\');background-size:contain;background-position:center;background-repeat:no-repeat"') or ''
            local price = owned[s.id]
                and '<div class="shopPrice" style="color:#7fd18a">OWNED</div>'
                or  ('<div class="shopPrice"><img src="' .. SHOP_GEM_ICON .. '">' .. lbComma(s.price or 0) .. '</div>')
            cards[#cards + 1] = table.concat({
                '<div class="shopCard" data-id="', lbEsc(s.id), '">',
                '<img class="shopGem" src="asset://garrysmod/materials/mergeempires/menu/me_losange_bleu.png">',
                '<div class="shopThumb"', thumb, '><div class="shopFoot">',
                '<div class="shopName">', lbEsc(s.name or s.id), '</div>', price,
                '</div></div></div>',
            })
        end
        rows[#rows + 1] = '<div class="shopGrid">' .. table.concat(cards) .. '</div>'
    end
    return '<div class="shopColl"><div class="shopCollBar">SKINS COLLECTION</div>' .. table.concat(rows) .. '</div>'
end

function M._BuildShopGems()
    local cfg = MEConfig.Shop and MEConfig.Shop.Gems
    if not istable(cfg) or #cfg == 0 then
        return '<div class="shopEmpty">No gem packages yet.</div>'
    end
    local packs = {}
    for _, p in ipairs(cfg) do
        local ribbon = ""
        if p.bonus and p.bonus ~= "" then
            ribbon = '<div class="gemRibbon">' .. lbEsc(p.bonus) .. "</div>"
        end
        local amount = (lbComma(p.amount):gsub(",", " "))
        local iconHTML = ""
        if p.icon and p.icon ~= "" then
            iconHTML = '<img class="gemIcon" src="asset://garrysmod/materials/mergeempires/menu/' .. p.icon .. '">'
        end
        packs[#packs + 1] = table.concat({
            '<div class="gemPack" data-id="', lbEsc(p.id or ""), '">', ribbon,
            '<div class="gemArt">', iconHTML, "</div>",
            '<div class="gemFoot"><div class="gemAmount">', amount, ' GEMS</div><div class="gemPrice">FREE</div></div>',
            "</div>",
        })
    end
    local disclaimer = '<div class="gemDisclaimer">This gamemode is currently in review, so no real-money transactions are processed here. Every purchase is fictional.</div>'
    return '<div class="gemGrid">' .. table.concat(packs) .. "</div>" .. disclaimer
end

M._InvEquipped = M._InvEquipped or {}
M._InvOwned    = M._InvOwned    or {}
function M._InvSkinsFor(itemKey) return M._InvOwned[itemKey] or {} end

function M.RefreshInventory()
    if not IsValid(S.panel) then return end
    local cards = M._InventoryCards()

    S.panel:RunJavascript("try{CineAPI.invStart()}catch(e){}")
    if #cards == 0 then
        S.panel:RunJavascript("try{CineAPI.invPush(" .. jsq('<div class="shopEmpty">No items.</div>') .. ")}catch(e){}")
    else
        local buf = {}
        for i = 1, #cards do
            buf[#buf + 1] = cards[i]
            if #buf >= 3 then
                S.panel:RunJavascript("try{CineAPI.invPush(" .. jsq(table.concat(buf)) .. ")}catch(e){}")
                buf = {}
            end
        end
        if #buf > 0 then
            S.panel:RunJavascript("try{CineAPI.invPush(" .. jsq(table.concat(buf)) .. ")}catch(e){}")
        end
    end
    S.panel:RunJavascript("try{CineAPI.invFlush()}catch(e){}")
end

function M.RefreshShopSkins()
    if not IsValid(S.panel) then return end
    S.panel:RunJavascript("try{CineAPI.setShopSkins(" .. jsq(M._BuildShopSkins()) .. ")}catch(e){}")
end

net.Receive("ME_InvSync", function()
    local data     = util.JSONToTable(net.ReadString() or "") or {}
    local owned    = istable(data.owned)    and data.owned    or {}
    local equipped = istable(data.equipped) and data.equipped or {}
    M._InvOwnedSet = owned
    M._InvEquipped = {}
    for item, sid in pairs(equipped) do M._InvEquipped[item] = sid end
    M._InvOwned = {}
    for _, s in ipairs(ME.Skins or {}) do
        if owned[s.id] then
            M._InvOwned[s.item] = M._InvOwned[s.item] or {}
            table.insert(M._InvOwned[s.item], { id = s.id, name = s.name, icon = "skin_" .. s.id })
        end
    end
    if M.RefreshInventory then M.RefreshInventory() end
    if M.RefreshShopSkins then M.RefreshShopSkins() end
end)

function M._InventoryCards()
    local iconOf   = ME.BuildIconSrc
    local equipped = M._InvEquipped or {}
    local cards    = {}

    local function esc(s) return (tostring(s or "")):gsub('"', "") end
    local function card(itemKey, skinId, src, label, isEquipped)

        local thumb = src and ('<img class="invThumb" src="' .. src .. '">') or '<div class="invThumb"></div>'
        cards[#cards + 1] = table.concat({
            '<div class="invCard', isEquipped and ' equipped' or '',
            '" data-item="', esc(itemKey), '" data-skin="', esc(skinId or ""), '" title="', esc(label), '">',
            thumb,
            '<img class="invCheck" src="asset://garrysmod/materials/mergeempires/menu/me_check.png">',
            '</div>',
        })
    end

    for _, b in ipairs(ME.Buildings or {}) do
        local key = "b_" .. b.id
        card(key, nil, iconOf and iconOf(b.id), b.name or b.id, equipped[key] == nil)
        for _, sk in ipairs(M._InvSkinsFor and M._InvSkinsFor(key) or {}) do
            card(key, sk.id, iconOf and iconOf(sk.icon or sk.id), sk.name or sk.id, equipped[key] == sk.id)
        end
    end

    local units = {}
    for kind, k in pairs(ME.UnitKinds or {}) do units[#units + 1] = { kind = kind, k = k } end
    table.sort(units, function(a, b) return (a.k.cost or 0) < (b.k.cost or 0) end)
    for _, u in ipairs(units) do
        local key = "u_" .. u.kind
        card(key, nil, iconOf and iconOf("unit_" .. u.kind), u.k.name or u.kind, equipped[key] == nil)
        for _, sk in ipairs(M._InvSkinsFor and M._InvSkinsFor(key) or {}) do
            card(key, sk.id, iconOf and iconOf(sk.icon or sk.id), sk.name or sk.id, equipped[key] == sk.id)
        end
    end

    return cards
end

net.Receive("ME_Leaderboard", function()
    local json = net.ReadString()
    if not IsValid(S.panel) then return end
    local data = util.JSONToTable(json) or {}

    local html = data.sp and lbMessageHTML(LB_SP_MSG) or lbRowsHTML(data.list)
    S.panel:RunJavascript("try{CineAPI.setLeaderboardHTML(" .. jsq(html) .. ")}catch(e){}")

    if data.sp or not istable(data.list) then return end
    for _, e in ipairs(data.list) do
        local sid = tostring(e.steamid or "")
        if sid ~= "" and sid ~= "0" then
            local cached = S.chatAvatars[sid]
            if cached then
                S.panel:RunJavascript("try{CineAPI.lbdAvatar(" .. jsq(sid) .. "," .. jsq(cached) .. ")}catch(e){}")
            else
                fetchChatAvatar(sid)
            end
        end
    end
end)

local SV_SP_MSG = "You must be on a multiplayer server, not singleplayer, so that match data can be generated to list active matches."

local function svMessageHTML(msg)
    return '<div class="svEmpty">' .. lbEsc(msg) .. "</div>"
end

local function svFmtAge(a)
    a = math.floor(tonumber(a) or 0)
    if a < 30 then return "STARTING" end
    return string.format("%d:%02d", math.floor(a / 60), a % 60)
end

local function svRowsHTML(list)
    if not istable(list) or #list == 0 then
        return '<div class="svEmpty">No active matches right now.</div>'
    end
    local b = {}
    for i, m in ipairs(list) do
        local avs = {}
        if istable(m.players) then
            for _, p in ipairs(m.players) do
                local style = ""
                if p.avatar and p.avatar ~= "" then
                    style = " style=\"background-image:url('" .. p.avatar .. "')\""
                end
                avs[#avs + 1] = '<div class="svAv" data-sid="' .. lbEsc(p.steamid or "") .. '"' .. style .. "></div>"
            end
        end
        b[#b + 1] = table.concat({
            '<div class="svRow">',
            '<div class="svC-time" data-age="', tostring(math.floor(tonumber(m.age) or 0)), '">', svFmtAge(m.age), "</div>",
            '<div class="svC-map">', lbEsc(m.map or "Breaktide"), "</div>",
            '<div class="svC-mode">', lbEsc(m.mode or "Casual"), "</div>",
            '<div class="svC-players">', table.concat(avs), "</div>",
            '<div class="svC-act"><div class="svSpec" data-mid="', lbEsc(tostring(m.id or i)), '"><img src="asset://garrysmod/materials/mergeempires/menu/me_eye.png" alt=""></div></div>',
            "</div>",
        })
    end
    return table.concat(b)
end

net.Receive("ME_Servers", function()
    local json = net.ReadString()
    if not IsValid(S.panel) then return end
    local data = util.JSONToTable(json) or {}
    local html = data.sp and svMessageHTML(SV_SP_MSG) or svRowsHTML(data.list)
    S.panel:RunJavascript("try{CineAPI.setServersHTML(" .. jsq(html) .. ")}catch(e){}")

    if data.sp or not istable(data.list) then return end
    for _, m in ipairs(data.list) do
        if istable(m.players) then
            for _, p in ipairs(m.players) do
                local sid = tostring(p.steamid or "")
                if sid ~= "" and sid ~= "0" then
                    local cached = S.chatAvatars[sid]
                    if cached then
                        S.panel:RunJavascript("try{CineAPI.svAvatar(" .. jsq(sid) .. "," .. jsq(cached) .. ")}catch(e){}")
                    else
                        fetchChatAvatar(sid)
                    end
                end
            end
        end
    end
end)

net.Receive("ME_Notify", function()
    local msg = net.ReadString()
    local ok  = net.ReadBool()
    if not IsValid(S.panel) then return end
    if ok then
        S.panel:RunJavascript("try{CineAPI.purchase(" .. jsq(msg) .. ")}catch(e){}")
        if M.RefreshLobby then M.RefreshLobby() end
    else
        S.panel:RunJavascript("try{CineAPI.notify(" .. jsq(msg) .. ",'err')}catch(e){}")
    end
end)

net.Receive("ME_Reward", function()
    local name  = net.ReadString()
    local typ   = net.ReadString()
    local count = net.ReadUInt(32)
    local icon  = net.ReadString()
    if not IsValid(S.panel) then return end
    local url = "asset://garrysmod/materials/mergeempires/menu/" .. icon
    S.panel:RunJavascript(string.format("try{CineAPI.reward(%s,%d,%s,%s)}catch(e){}",
        jsq(url), count, jsq(name), jsq(typ)))
    if M.RefreshLobby then
        M.RefreshLobby()
        timer.Simple(0.2, function() if S.menuActive and M.RefreshLobby then M.RefreshLobby() end end)
    end
end)

net.Receive("ME_Chat", function()
    if ME and ME.Sfx and ME.InGame and ME.InGame() then ME.Sfx.Play2D("chat_message") end
    local ply  = net.ReadEntity()
    local text = net.ReadString()
    if ME.Chat and ME.Chat.OnMessage then ME.Chat.OnMessage(ply, text) end
    if not IsValid(S.panel) then return end
    local name = IsValid(ply) and ((isfunction(ply.SteamName) and ply:SteamName()) or ply:Nick()) or "Player"
    local sid  = (IsValid(ply) and isfunction(ply.SteamID64) and ply:SteamID64()) or ""
    local col  = "#dcdfe4"
    if IsValid(ply) then
        local c = ME.BeamColors and ME.BeamColors[ply:GetNWInt("ME_ChatColor", 0)]
        if c then col = string.format("#%02x%02x%02x", c.r, c.g, c.b) end
    end
    local avatar = (sid ~= "" and S.chatAvatars[sid]) or ""
    S.panel:RunJavascript("try{CineAPI.chatMessage(" .. jsq(name) .. "," .. jsq(text) .. "," .. jsq(col) .. "," .. jsq(sid) .. "," .. jsq(avatar) .. ")}catch(e){}")
    if sid ~= "" then fetchChatAvatar(sid) end
end)

net.Receive("ME_ChatSys", function()
    local text = net.ReadString()
    local r, g, b = net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)
    if ME.Chat and ME.Chat.OnSystem then ME.Chat.OnSystem(text, r, g, b) end
end)

