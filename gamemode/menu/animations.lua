
local M = MEMenu

function M._BuildAnimations(params)
    return [[
@keyframes titleBlinkAnim{0%,40%{opacity:1}50%,90%{opacity:0}100%{opacity:1}}
@keyframes titleBarSlideTop{from{transform:translateY(-100%)}to{transform:translateY(0)}}
@keyframes titleBarSlideBot{from{transform:translateY(100%)}to{transform:translateY(0)}}
@keyframes titleFadeSync{
  0%{opacity:0}
  ]] .. params.visStartStr .. [[%{opacity:1}
  ]] .. params.visEndStr .. [[%{opacity:1}
  100%{opacity:0}
}
@keyframes loadFadeIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
@keyframes lSpin{from{transform:rotate(0deg)}to{transform:rotate(360deg)}}
@keyframes menuIn{from{opacity:0;transform:translateY(4px)}to{opacity:1;transform:translateY(0)}}
@keyframes spawnFadeIn{from{opacity:0;transform:translate(-50%,calc(-50% + 14px))}to{opacity:1;transform:translate(-50%,-50%)}}
@keyframes spawnDotsFadeIn{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:translateY(0)}}
@keyframes mmQueueGlow{0%,100%{box-shadow:0 6px 22px rgba(29,160,236,.5),inset 0 1px 0 rgba(255,255,255,.42),inset 0 0 22px rgba(130,222,255,.32)}50%{box-shadow:0 8px 28px rgba(29,160,236,.7),inset 0 1px 0 rgba(255,255,255,.5),inset 0 0 30px rgba(150,230,255,.55)}}
@keyframes vbIn{from{opacity:0;transform:translateY(22px) scale(.96)}to{opacity:1;transform:translateY(0) scale(1)}}
@keyframes hexDrift{0%{transform:translate(0,0)}100%{transform:translate(-162px,-93.5px)}}
@keyframes qShine{0%{transform:translateX(-120%)}55%{transform:translateX(320%)}100%{transform:translateX(320%)}}
@keyframes msSheen{0%{transform:translateX(-180%) skewX(-12deg);opacity:0}15%{opacity:1}100%{transform:translateX(320%) skewX(-12deg);opacity:0}}
@keyframes amSpin{to{transform:rotate(360deg)}}
]]
end
