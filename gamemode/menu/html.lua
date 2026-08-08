
local M = MEMenu
local esc, escAttr = M._Esc, M._EscAttr

local function computeParams()
    local titleCfg = M._titleCfg
    local menuCfg  = M._menuCfg

    local barH       = titleCfg.BarHeight or 90
    local blink      = titleCfg.BlinkInterval or 2.0
    local shotDur    = titleCfg.ShotDuration or 6.5
    local fadeDur    = titleCfg.FadeDuration or 1.4
    local cycle      = shotDur + fadeDur * 2
    local visStart   = (fadeDur / cycle) * 100
    local visEnd     = ((fadeDur + shotDur) / cycle) * 100

    local titleCopyRaw  = titleCfg.Copyright or "© 2026 ME Entertainment\nDeveloped by the ME team. All Rights Reserved."
    local titleCopyHTML = esc(titleCopyRaw):gsub("\\n", "<br>"):gsub("\n", "<br>")

    local openWorld = menuCfg.OpenWorldBanner or {}
    local owImgRaw
    if openWorld.URL and openWorld.URL ~= "" then
        owImgRaw = openWorld.URL
    elseif openWorld.Material and openWorld.Material ~= "" then
        owImgRaw = "asset://garrysmod/materials/" .. openWorld.Material
    else
        owImgRaw = ""
    end

    local trainingBanner = menuCfg.TrainingBanner or {}
    local trImgRaw
    if trainingBanner.URL and trainingBanner.URL ~= "" then
        trImgRaw = trainingBanner.URL
    elseif trainingBanner.Material and trainingBanner.Material ~= "" then
        trImgRaw = "asset://garrysmod/materials/" .. trainingBanner.Material
    else
        trImgRaw = owImgRaw
    end

    local desertImgRaw, desertTitle = "", "DESERT"
    if menuCfg.OpenWorld and menuCfg.OpenWorld.Maps then
        for _, m in ipairs(menuCfg.OpenWorld.Maps) do
            if m.Key == "desert" then
                desertImgRaw = m.Image or ""
                desertTitle  = m.Title or "DESERT"
                break
            end
        end
    end

    local assets = MEConfig.Assets or {}
    local matchLoad = menuCfg.MatchLoading or {}

    local bn = {}
    for _, mode in ipairs({ "casual", "blitz", "ambush", "duel", "ranked" }) do
        bn[mode] = escAttr(M._ModeBanner(mode))
    end
    bn.map_desert = escAttr((menuCfg.MapBanners or {}).desert or M._ModeBanner(nil))

    return {
        bn              = bn,
        matchFadeIn     = matchLoad.FadeIn or 0.55,
        barHeight       = barH,
        cycleStr        = string.format("%.3f", cycle),
        visStartStr     = string.format("%.3f", visStart),
        visEndStr       = string.format("%.3f", visEnd),
        blink           = blink,
        titleCopyHTML   = titleCopyHTML,
        owImg           = escAttr(owImgRaw),
        trImg           = escAttr(trImgRaw),
        desertImg       = escAttr(desertImgRaw),
        desertTitleHTML = esc(desertTitle),
        hoverSnd        = assets.SoundHover  or "asset://garrysmod/sound/mergeempires/hover.mp3",
        refuseSnd       = assets.SoundRefuse or "asset://garrysmod/sound/mergeempires/refuse.mp3",
        purchaseSnd     = assets.SoundPurchase or "asset://garrysmod/sound/mergeempires/menu/purchase.mp3",
    }
end

function M._BuildHTML()
    local p = computeParams()
    return table.concat({
        [[<!doctype html><html><head><meta charset="utf-8"><style>]],
        M._BuildAnimations(p),
        M._BuildStyles(p),
        [[</style></head><body>]],
        M._BuildMarkup(p),
        [[<script>]],
        M._BuildScripts(p),
        [[</script></body></html>]],
    })
end
