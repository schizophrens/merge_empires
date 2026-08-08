
local M = MEMenu
local S = M._State

local blurMat = Material("pp/blurscreen")

local lowpolyColorMod = {
    ["$pp_colour_addr"]       = 0,
    ["$pp_colour_addg"]       = 0,
    ["$pp_colour_addb"]       = 0,
    ["$pp_colour_brightness"] = -0.09,
    ["$pp_colour_contrast"]   = 1.20,
    ["$pp_colour_colour"]     = 1.55,
    ["$pp_colour_mulr"]       = 0,
    ["$pp_colour_mulg"]       = 0,
    ["$pp_colour_mulb"]       = 0,
}

function M._EnsurePlayerModelPanel()
    if IsValid(S.playerModelPanel) then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local p = vgui.Create("DModelPanel")
    p:SetSize(ScrW(), ScrH())
    p:SetPos(0, 0)
    p:SetMouseInputEnabled(false)
    p:SetKeyboardInputEnabled(false)
    p:SetZPos(8800)
    p:SetModel(ply:GetModel() or "models/player/group01/male_07.mdl")
    p:SetFOV(40)
    p:SetCamPos(Vector(160, 20, 52))
    p:SetLookAt(Vector(0, 0, 52))
    p.LayoutEntity = function(_, e)
        if not IsValid(e) then return end
        e:SetAngles(Angle(0, 20 + math.sin(CurTime() * 0.35) * 1.8, 0))
    end
    p:SetVisible(false)
    S.playerModelPanel = p
end

function M._ShowPlayerModelPanel()
    M._EnsurePlayerModelPanel()
    if IsValid(S.playerModelPanel) then S.playerModelPanel:SetVisible(true) end
end

function M._HidePlayerModelPanel()
    if IsValid(S.playerModelPanel) then S.playerModelPanel:SetVisible(false) end
end

function M._EnsureBlurPanel()
    if IsValid(S.blurPanel) then return end
    local bp = vgui.Create("DPanel")
    bp:SetSize(ScrW(), ScrH())
    bp:SetPos(0, 0)
    bp:SetMouseInputEnabled(false)
    bp:SetKeyboardInputEnabled(false)
    bp:SetZPos(8000)
    bp.Paint = function(self, w, h)
        local x, y = self:LocalToScreen(0, 0)
        surface.SetMaterial(blurMat)
        surface.SetDrawColor(255, 255, 255, 255)
        for i = 1, 2 do
            blurMat:SetFloat("$blur", i * 2)
            blurMat:Recompute()
            render.UpdateScreenEffectTexture()
            surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
        end
        surface.SetDrawColor(0, 0, 0, math.floor(S.blurOverlayAlpha))
        surface.DrawRect(0, 0, w, h)
    end
    S.blurPanel = bp
end

function M._EnsureIntroBlackPanel()
    if IsValid(S.introBlackPanel) then return end
    local p = vgui.Create("DPanel")
    p:SetSize(ScrW(), ScrH())
    p:SetPos(0, 0)
    p:SetMouseInputEnabled(false)
    p:SetKeyboardInputEnabled(false)
    p:SetZPos(8500)
    p.Paint = function(_, w, h)
        if not S.introBlackActive then return end
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, w, h)
    end
    S.introBlackPanel = p
end

function M._EnsureTitleFadePanel()
    if IsValid(S.titleFadePanel) then return end
    local p = vgui.Create("DPanel")
    p:SetSize(ScrW(), ScrH())
    p:SetPos(0, 0)
    p:SetMouseInputEnabled(false)
    p:SetKeyboardInputEnabled(false)
    p:SetZPos(8990)
    p.Paint = function(_, w, h)
        local a = S.titleManualFade
        if not a then
            a = MECamera and MECamera.GetFadeAlpha and MECamera.GetFadeAlpha() or 0
        end
        if a > 0 then
            surface.SetDrawColor(0, 0, 0, math.floor(a * 255))
            surface.DrawRect(0, 0, w, h)
        end
    end
    S.titleFadePanel = p
end

local LP_COLS      = 85
local MAX_TRI_BATCH  = 8000
local MAX_LINE_BATCH = 5000

local lpFacetMat = CreateMaterial("me_lowpoly_facet", "UnlitGeneric", {
    ["$basetexture"] = "white", ["$nocull"] = "1", ["$clampX"] = "1", ["$clampY"] = "1",
})
local lpEdgeMat = CreateMaterial("me_lowpoly_edge", "UnlitGeneric", {
    ["$basetexture"] = "models/debug/debugwhite",
    ["$vertexcolor"] = "1", ["$vertexalpha"] = "1", ["$additive"] = "1", ["$nocull"] = "1",
})

local lpTris    = {}
local lpMeshes  = {}
local lpEdgeMeshes = {}
local lpW, lpH  = 0, 0

local function destroyLPMeshes()
    for _, m in ipairs(lpMeshes)     do if m then m:Destroy() end end
    for _, m in ipairs(lpEdgeMeshes) do if m then m:Destroy() end end
    lpMeshes, lpEdgeMeshes = {}, {}
end



hook.Add("ShutDown", "ME_LPMeshCleanup", destroyLPMeshes)

hook.Add("RenderScreenspaceEffects", "ME_TitleLowpoly", function()
    if not S.titleActive then return end
    DrawColorModify(lowpolyColorMod)
end)

hook.Add("Think", "ME_BlurOverlayLerp", function()
    if math.abs(S.blurOverlayAlpha - S.blurOverlayTarget) < 0.5 then
        S.blurOverlayAlpha = S.blurOverlayTarget
        return
    end
    S.blurOverlayAlpha = Lerp(FrameTime() * 1.7, S.blurOverlayAlpha, S.blurOverlayTarget)
end)
