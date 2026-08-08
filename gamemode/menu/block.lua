
local M = MEMenu
local S = M._State
local isMenuOpen = M.IsOpen

local DEFAULT_HIDE_LIST = { { Global = "MEHUD", Field = "Panel" } }
local function getHideWhileMenuList()
    return (MEConfig and MEConfig.HideWhileMenuOpen) or DEFAULT_HIDE_LIST
end

local _origAddLegacy = notification and notification.AddLegacy
if _origAddLegacy then
    notification.AddLegacy = function(text, typ, len)
        if isMenuOpen() then return end
        return _origAddLegacy(text, typ, len)
    end
end

local gm = GAMEMODE
if gm and gm.AddNotify then
    local orig = gm.AddNotify
    gm.AddNotify = function(self, text, typ, life)
        if isMenuOpen() then return end
        return orig(self, text, typ, life)
    end
end

local _darkRPPatched = false
hook.Add("Think", "ME_PatchDarkRPNotify", function()
    if _darkRPPatched then return end
    if not DarkRP then return end
    _darkRPPatched = true
    hook.Remove("Think", "ME_PatchDarkRPNotify")
    if DarkRP.notify then
        local origNotify = DarkRP.notify
        DarkRP.notify = function(...)
            if isMenuOpen() then return end
            return origNotify(...)
        end
    end
    if DarkRP.openF4Menu then
        local origF4 = DarkRP.openF4Menu
        DarkRP.openF4Menu = function(...)
            if isMenuOpen() then return end
            return origF4(...)
        end
    end
end)

hook.Add("HUDPaintBackground", "ME_BlockDarkRPHUD", function()
    if isMenuOpen() then return true end
end)

hook.Add("HUDPaint", "ME_BlockHUDPaint", function()
    if not isMenuOpen() then return end
    if notification and notification.Kill then notification.Kill() end
    if GAMEMODE and istable(GAMEMODE.Notifications) then table.Empty(GAMEMODE.Notifications) end
    if DarkRP and istable(DarkRP.Notifications) then table.Empty(DarkRP.Notifications) end
    return true
end)

local _darkRPNotifyMsgHooked = false
hook.Add("Think", "ME_BlockDarkRPNotifyUsermessage", function()
    if _darkRPNotifyMsgHooked then return end
    if not usermessage or not usermessage.Hook then return end
    _darkRPNotifyMsgHooked = true
    usermessage.Hook("_Notify", function(msg)
        local txt = msg:ReadString()
        local typ = msg:ReadShort()
        local len = msg:ReadLong()
        if isMenuOpen() then return end
        if GAMEMODE and GAMEMODE.AddNotify then
            GAMEMODE:AddNotify(txt, typ, len)
            return
        end
        if notification and notification.AddLegacy then
            notification.AddLegacy(txt, typ, len)
        end
    end)
end)

hook.Add("CreateMove", "ME_BlockMove", function(cmd)
    if isMenuOpen() or S.titleActive then
        cmd:ClearButtons()
        cmd:ClearMovement()
    end
end)

hook.Add("InputMouseApply", "ME_BlockMouse", function()
    if S.introActive or S.titleActive then return true end
end)

hook.Add("PlayerBindPress", "ME_BlockBinds", function(_, bind, pressed)
    if not (isMenuOpen() or S.titleActive) then return end
    if pressed and isMenuOpen() and bind and string.find(bind, "messagemode") and M.OpenChat then
        M.OpenChat()
    end
    return true
end)

local _enterWasDown = false
hook.Add("Think", "ME_ChatEnterKey", function()
    local down = input.IsKeyDown(KEY_ENTER) or input.IsKeyDown(KEY_PAD_ENTER)
    if down and not _enterWasDown and isMenuOpen() and not S.titleActive
        and not gui.IsGameUIVisible() and IsValid(S.panel)
        and not S.panel:IsKeyboardInputEnabled() and M.OpenChat then
        M.OpenChat()
    end
    _enterWasDown = down
end)

hook.Add("HUDShouldDraw", "ME_HideHUD", function()
    if S.introActive or isMenuOpen() then return false end
end)

hook.Add("HUDDrawScoreBoard", "ME_HideScoreboard", function()
    if S.introActive or isMenuOpen() then return true end
end)

hook.Add("StartChat", "ME_BlockChat", function()
    if S.introActive or isMenuOpen() then return true end
end)

hook.Add("ScoreboardShow", "ME_BlockScoreboard", function()
    if S.introActive or isMenuOpen() then return true end
end)

local function hideMenuForGameUI()
    if IsValid(S.panel) then
        S.panel:SetVisible(false)
        S.panel:SetMouseInputEnabled(false)
        S.panel:SetKeyboardInputEnabled(false)
    end
    if IsValid(S.blurPanel)        then S.blurPanel:SetVisible(false)        end
    if IsValid(S.playerModelPanel) then S.playerModelPanel:SetVisible(false) end
    if IsValid(S.menuDarkPanel)    then S.menuDarkPanel:SetVisible(false)    end
    gui.EnableScreenClicker(false)
end

local function showMenuAfterGameUI()
    if IsValid(S.panel) then
        S.panel:SetVisible(true)
        S.panel:SetMouseInputEnabled(true)
        if S.panel.MakePopup then S.panel:MakePopup() end
        S.panel:SetKeyboardInputEnabled(false)
    end
    if IsValid(S.blurPanel) then S.blurPanel:SetVisible(true) end
    if S.menuActive and IsValid(S.playerModelPanel) then S.playerModelPanel:SetVisible(true) end
    if S.menuActive and IsValid(S.menuDarkPanel)    then S.menuDarkPanel:SetVisible(true)    end
    gui.EnableScreenClicker(true)
end

local _hidByGameUI = false
hook.Add("Think", "ME_GameUIWatch", function()
    local visible = gui.IsGameUIVisible()
    if visible and not _hidByGameUI then
        if isMenuOpen() or S.introActive then
            hideMenuForGameUI()
            _hidByGameUI = true
        end
    elseif not visible and _hidByGameUI then
        showMenuAfterGameUI()
        _hidByGameUI = false
    end
end)

local foreignHudState = {}
hook.Add("Think", "ME_ForeignHUD", function()
    local hide = isMenuOpen()
    for _, e in ipairs(getHideWhileMenuList()) do
        local obj = _G[e.Global]
        local target = obj and obj[e.Field]
        if IsValid(target) then
            local key = e.Global .. "." .. e.Field
            if hide and foreignHudState[key] == nil then
                foreignHudState[key] = target:IsVisible()
                target:SetVisible(false)
            elseif not hide and foreignHudState[key] ~= nil then
                target:SetVisible(foreignHudState[key])
                foreignHudState[key] = nil
            end
        end
    end
end)
