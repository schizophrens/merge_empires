
MEMenu = MEMenu or {}
local M = MEMenu

M._State = M._State or {
    introActive    = false,
    introStarted   = false,
    htmlReady      = false,
    titleActive    = false,
    titleStartedAt = 0,
    titleSpaceArmed   = false,
    titleSpaceWasDown = false,
    titleExitStart    = nil,
    titleExitDur      = 1.8,
    titleExitFromAlpha = 0,
    titleEnterStart   = nil,
    titleEnterDur     = 1.4,
    titleManualFade   = nil,
    titleLoadingStart = nil,
    titleLoadingDur   = 7.0,
    menuActive        = false,
    introBlackActive  = false,
    blurOverlayAlpha  = 150,
    blurOverlayTarget = 150,
    lastPlayersPush   = 0,
    lastPlayersCount  = -1,
    steamAvatarURL    = nil,
    steamFetchInflight = false,

    panel             = nil,
    blurPanel         = nil,
    introSound        = nil,
    titleBgmChan      = nil,
    titleFadePanel    = nil,
    introBlackPanel   = nil,
    playerModelPanel  = nil,
    menuDarkPanel     = nil,
}

local S = M._State

local function isMenuOpen()
    return S.introActive or (IsValid(S.panel) and S.panel:IsVisible())
end
M.IsOpen = isMenuOpen

M._cfg      = MEConfig or {}
M._introCfg = M._cfg.Intro or {}
M._titleCfg = M._cfg.TitleScreen or {}
M._menuCfg  = M._cfg.MainMenu or {}

function M._ReloadConfig()
    M._cfg      = MEConfig or {}
    M._introCfg = M._cfg.Intro or {}
    M._titleCfg = M._cfg.TitleScreen or {}
    M._menuCfg  = M._cfg.MainMenu or {}
end

function M._ModeBanner(mode)
    local cfg = M._menuCfg or {}
    mode = string.lower(string.Trim(tostring(mode or "")))
    return (cfg.ModeBanners or {})[mode] or cfg.ModeBannerDefault or ""
end

function M._JSQ(s) return string.format("%q", s or "") end

local escapeMap = {
    ['"'] = "&quot;", ["'"] = "&#39;", ["\\"] = "\\\\",
    ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;",
}
function M._Esc(s)
    if string.JavascriptSafe then return string.JavascriptSafe(s or "") end
    return (string.gsub(s or "", "[\"'\\<>&]", escapeMap))
end

local htmlAttrMap = {
    ["&"] = "&amp;", ['"'] = "&quot;", ["'"] = "&#39;",
    ["<"] = "&lt;", [">"] = "&gt;",
}
function M._EscAttr(s)
    return (string.gsub(s or "", "[&\"'<>]", htmlAttrMap))
end
