
MECamera = MECamera or {}
local M = MECamera

local DEFAULT_START_POS = Vector(-7064.416992, 1336.490234,  7.807098)
local DEFAULT_START_ANG = Angle(0.330002, 179.970871, 0)
local DEFAULT_END_POS   = Vector(-6541.694824, 1336.223511, 10.817829)
local DEFAULT_END_ANG   = Angle(0.330002, 179.970871, 0)

local mathSin   = math.sin
local mathMin   = math.min
local mathClamp = math.Clamp
local mathPow   = math.pow

local active, handoff = false, false
local handoffStart, handoffTime = 0, 1
local handoffPos, handoffAng
local startTime, introDuration = 0, 12
local startPos, startAng, startFov
local endPos, endAng, endFov

local viewPos   = Vector()
local viewAng   = Angle()
local viewTable = { origin = viewPos, angles = viewAng, fov = 70, drawviewer = true }

local loopActive, loopShots, loopOrder = false, nil, nil
local loopShotIndex, loopShotStart    = 1, 0
local loopShotDur, loopFadeDur        = 5.0, 2.2
local loopFadeAlpha                   = 1.0
local loopShotCache                   = {}
local loopLastPlayed                  = 0

local staticActive = false
local staticPos, staticAng, staticFov = Vector(), Angle(), 70

local function easeInOutCubic(x)
    return x < 0.5 and 4 * x * x * x or 1 - mathPow(-2 * x + 2, 3) * 0.5
end

local function easeOutQuad(x)
    return 1 - (1 - x) * (1 - x)
end

local function shortestAngle(from, to)
    local d = to - from
    while d > 180 do d = d - 360 end
    while d < -180 do d = d + 360 end
    return d
end

local function cacheShot(shot)
    local cached = loopShotCache[shot]
    if cached then return cached end

    local A  = shot.A or { pos = shot.pos or DEFAULT_START_POS, ang = shot.ang or DEFAULT_START_ANG }
    local B  = shot.B or A
    local ap, aa = A.pos or DEFAULT_START_POS, A.ang or DEFAULT_START_ANG
    local bp, ba = B.pos or ap,                B.ang or aa

    local data = {
        ax = ap.x, ay = ap.y, az = ap.z,
        bx = bp.x, by = bp.y, bz = bp.z,
        ap_p = aa.p, ap_y = aa.y, ap_r = aa.r,
        dyaw   = shortestAngle(aa.y, ba.y),
        dpitch = shortestAngle(aa.p, ba.p),
        droll  = shortestAngle(aa.r, ba.r),
        fov = shot.fov or 70,
    }
    loopShotCache[shot] = data
    return data
end

local function shuffleLoopOrder()
    local n = #loopShots
    loopOrder = {}
    for i = 1, n do loopOrder[i] = i end
    for i = n, 2, -1 do
        local j = math.random(i)
        loopOrder[i], loopOrder[j] = loopOrder[j], loopOrder[i]
    end
    if n > 1 and loopOrder[1] == loopLastPlayed then
        local k = math.random(2, n)
        loopOrder[1], loopOrder[k] = loopOrder[k], loopOrder[1]
    end
end

function M.Start()
    if active then return end
    active   = true
    handoff  = false
    startTime = CurTime()

    local camCfg = MEConfig and MEConfig.Camera
    local shots  = camCfg and camCfg.Shots
    handoffTime  = (camCfg and camCfg.HandoffTime) or 1
    introDuration = (MEConfig and MEConfig.Intro and MEConfig.Intro.TotalDuration) or 12

    if shots and #shots >= 2 then
        startPos, startAng, startFov = shots[1].pos, shots[1].ang, shots[1].fov or 70
        endPos,   endAng,   endFov   = shots[2].pos, shots[2].ang, shots[2].fov or 70
    else
        startPos, startAng, startFov = DEFAULT_START_POS, DEFAULT_START_ANG, 70
        endPos,   endAng,   endFov   = DEFAULT_END_POS,   DEFAULT_END_ANG,   70
    end
end

function M.SetIntroDuration(dur)
    introDuration = dur or 12
end

function M.Stop()
    active, handoff = false, false
    loopActive   = false
    staticActive = false
    loopShots    = nil
    loopFadeAlpha = 0
    loopShotCache = {}
end

function M.GetFadeAlpha() return loopFadeAlpha end

function M.StartLoop()
    local cfg   = MEConfig and MEConfig.TitleScreen
    local shots = cfg and (cfg.TravelShots or cfg.LoopShots)
    if not shots or #shots == 0 then return end

    loopActive    = true
    loopShots     = shots
    loopLastPlayed = 0
    shuffleLoopOrder()
    loopShotIndex = 1
    loopShotStart = CurTime()
    loopShotDur   = cfg.ShotDuration or 5.0
    loopFadeDur   = cfg.FadeDuration or 2.2
    loopFadeAlpha = 1.0
    loopShotCache = {}

    active   = true
    handoff  = false
    startTime = CurTime()
    introDuration = 1e9
end

function M.StopLoop()
    loopActive    = false
    loopShots     = nil
    loopFadeAlpha = 0
    loopShotCache = {}
end

function M.StartStatic(pos, ang, fov)
    local cfg = MEConfig and MEConfig.MainMenu and MEConfig.MainMenu.Background
    staticPos = pos or (cfg and cfg.pos) or Vector(422.428741, 2914.438965, -10641.968750)
    staticAng = ang or (cfg and cfg.ang) or Angle(-14.256055, -92.698105, 0)
    staticFov = fov or (cfg and cfg.fov) or 70
    staticActive = true
    loopActive   = false
    handoff      = false
    active       = true
end

local function calcLoopView()
    local orderIdx = loopOrder[loopShotIndex] or 1
    local shot = loopShots[orderIdx] or loopShots[1]
    if not shot then return end

    local now = CurTime()
    local cycle = loopShotDur + loopFadeDur * 2
    local elapsed = now - loopShotStart

    if elapsed >= cycle then
        loopLastPlayed = orderIdx
        loopShotIndex  = loopShotIndex + 1
        if loopShotIndex > #loopOrder then
            shuffleLoopOrder()
            loopShotIndex = 1
        end
        loopShotStart = now
        orderIdx = loopOrder[loopShotIndex] or 1
        shot = loopShots[orderIdx]
        elapsed = 0
    end

    if elapsed < loopFadeDur then
        loopFadeAlpha = 1 - easeInOutCubic(elapsed / loopFadeDur)
    elseif elapsed < loopFadeDur + loopShotDur then
        loopFadeAlpha = 0
    else
        loopFadeAlpha = easeInOutCubic((elapsed - loopFadeDur - loopShotDur) / loopFadeDur)
    end

    local s = cacheShot(shot)
    local t = elapsed / cycle
    if t > 1 then t = 1 end
    local inv = 1 - t

    viewPos.x = s.ax * inv + s.bx * t
    viewPos.y = s.ay * inv + s.by * t
    viewPos.z = s.az * inv + s.bz * t

    viewAng.p = s.ap_p + s.dpitch * t
    viewAng.y = s.ap_y + s.dyaw   * t
    viewAng.r = s.ap_r + s.droll  * t

    viewTable.fov = s.fov
    return viewTable
end

hook.Add("CalcView", "ME_CalcView", function(_, _, _, fov)
    if not active then return end

    if staticActive then
        local t = CurTime()
        viewPos.x = staticPos.x + mathSin(t * 0.32) * 1.1 + mathSin(t * 0.19 + 1.4) * 0.4
        viewPos.y = staticPos.y + mathSin(t * 0.27 + 1.3) * 1.0 + mathSin(t * 0.16 + 0.6) * 0.4
        viewPos.z = staticPos.z + mathSin(t * 0.42) * 2.2 + mathSin(t * 0.23 + 0.8) * 0.9
        viewAng.p = staticAng.p + mathSin(t * 0.40) * 1.1 + mathSin(t * 0.24 + 1.0) * 0.4
        viewAng.y = staticAng.y + mathSin(t * 0.31 + 0.5) * 0.35
        viewAng.r = staticAng.r + mathSin(t * 0.36 + 1.1) * 1.0 + mathSin(t * 0.22 + 0.4) * 0.35
        viewTable.fov = staticFov
        return viewTable
    end

    if loopActive then
        return calcLoopView()
    end

    if handoff then
        local frac = mathMin((CurTime() - handoffStart) / handoffTime, 1)
        if frac >= 1 then return end

        local e   = easeOutQuad(frac)
        local inv = 1 - e

        viewPos.x = endPos.x * inv + handoffPos.x * e
        viewPos.y = endPos.y * inv + handoffPos.y * e
        viewPos.z = endPos.z * inv + handoffPos.z * e

        viewAng.p = endAng.p * inv + handoffAng.p * e
        viewAng.y = endAng.y * inv + handoffAng.y * e
        viewAng.r = endAng.r * inv + handoffAng.r * e

        viewTable.fov = endFov * inv + fov * e
        return viewTable
    end

    local frac = mathClamp((CurTime() - startTime) / introDuration, 0, 1)
    local e    = easeInOutCubic(frac)
    local inv  = 1 - e

    local t = CurTime()
    local driftScale = 1 - frac * 0.5

    local driftX = mathSin(t * 0.15) * 1.8 * driftScale + mathSin(t * 0.31 + 1.2) * 0.9 * driftScale
    local driftY = mathSin(t * 0.12 + 2.1) * 1.4 * driftScale
    local driftZ = mathSin(t * 0.18 + 0.7) * 1.1 * driftScale

    local angP = mathSin(t * 0.22) * 0.35 * driftScale + mathSin(t * 0.38 + 1.5) * 0.18 * driftScale
    local angY = mathSin(t * 0.16 + 0.5) * 0.28 * driftScale
    local angR = mathSin(t * 0.11 + 0.3) * 0.08 * driftScale

    viewPos.x = startPos.x * inv + endPos.x * e + driftX
    viewPos.y = startPos.y * inv + endPos.y * e + driftY
    viewPos.z = startPos.z * inv + endPos.z * e + driftZ

    viewAng.p = startAng.p * inv + endAng.p * e + angP
    viewAng.y = startAng.y * inv + endAng.y * e + angY
    viewAng.r = startAng.r * inv + endAng.r * e + angR

    viewTable.fov = startFov * inv + endFov * e
    return viewTable
end)

hook.Add("Think", "ME_CineProgress", function()
    if not active or not handoff or loopActive then return end
    if CurTime() - handoffStart >= handoffTime then
        M.Stop()
        if MEMenu and MEMenu.Finish then MEMenu.Finish() end
    end
end)

hook.Add("CreateMove", "ME_CineBlock", function(cmd)
    if not active then return end
    cmd:ClearButtons()
    cmd:ClearMovement()
end)

hook.Add("InputMouseApply", "ME_CineMouse", function()
    if active then return true end
end)
