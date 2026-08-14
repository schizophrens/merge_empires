
local M = MEMenu

function M._BuildStyles(params)
    local barH      = params.barHeight
    local cycleStr  = params.cycleStr
    local blinkStr  = tostring(params.blink)

    return [[
@import url('https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600;700;800;900&display=swap');
@font-face{font-family:'HanleyPro';src:url('asset://garrysmod/materials/mergeempires/fonts/Hanley-Pro-Sans.otf') format('opentype');font-weight:normal;font-style:normal}
@font-face{font-family:'EinaSemiBold';src:url('asset://garrysmod/materials/mergeempires/fonts/Eina-03-SemiBold.otf') format('opentype');font-weight:normal;font-style:normal}
@font-face{font-family:'MEMini';src:url('asset://garrysmod/materials/mergeempires/fonts/merge-empires-mini.ttf') format('truetype');font-weight:normal;font-style:normal}
@font-face{font-family:'MEBig';src:url('asset://garrysmod/materials/mergeempires/fonts/merge-empires-big.otf') format('opentype');font-weight:normal;font-style:normal}
@font-face{font-family:'MEFin';src:url('asset://garrysmod/materials/mergeempires/fonts/merge-empires-fin.ttf') format('truetype');font-weight:normal;font-style:normal}
@font-face{font-family:'Rajdhani';src:url('asset://garrysmod/materials/mergeempires/fonts/Rajdhani-SemiBold.ttf') format('truetype');font-weight:normal;font-style:normal}
@font-face{font-family:'BarlowLight';src:url('asset://garrysmod/materials/mergeempires/fonts/Barlow-Light.ttf') format('truetype');font-weight:normal;font-style:normal}
html,body{width:100%;height:100%;margin:0;padding:0;overflow:hidden;background:transparent;font-family:'HanleyPro','Segoe UI',sans-serif;color:#fff}
*{user-select:none;box-sizing:border-box}
.veil{position:fixed;inset:0;background:#000;opacity:0;z-index:2100;display:none;pointer-events:none}
#rating{position:fixed;inset:0;display:none;align-items:center;justify-content:center;pointer-events:none;z-index:2200}
#rating img{position:fixed;left:50%;top:50%;display:block;width:22vw;max-width:260px;height:auto;opacity:0;transform:translate(-50%,-50%) scale(.96);transition:opacity .75s,transform .75s}

#titleScreen{position:fixed;inset:0;display:none;z-index:2400;pointer-events:none;color:#fff}
#titleScreen.show{display:block}
#titleScreen.fading #titleTextWrap,#titleScreen.fading #titleCopyright,#titleScreen.fading #titlePressLine{animation:none !important;opacity:0 !important;transition:opacity .25s ease-out !important}
#titleBarTop,#titleBarBot{position:fixed;left:0;right:0;height:]] .. barH .. [[px;background:#000;z-index:2410}
#titleBarTop{top:0;animation:titleBarSlideTop .9s cubic-bezier(.6,.05,.2,1) both}
#titleBarBot{bottom:0;animation:titleBarSlideBot .9s cubic-bezier(.6,.05,.2,1) both}
#titleCopyright{position:fixed;left:0;right:0;bottom:]] .. (barH + 14) .. [[px;text-align:center;z-index:2420;font-family:'Segoe UI','Segoe UI Light','Arial',sans-serif;font-weight:300;font-size:11px;letter-spacing:.45px;color:rgba(220,220,225,.78);text-shadow:0 2px 6px rgba(0,0,0,.6);pointer-events:none;line-height:1.7;opacity:0;animation:titleFadeSync ]] .. cycleStr .. [[s cubic-bezier(.65,0,.35,1) infinite;will-change:opacity}
#titleTextWrap{position:fixed;left:6vw;top:50%;transform:translateY(-50%);z-index:2420;pointer-events:none;opacity:0;animation:titleFadeSync ]] .. cycleStr .. [[s cubic-bezier(.65,0,.35,1) infinite;will-change:opacity}
#titleTextBlock{display:flex;flex-direction:column;align-items:flex-start;gap:6px;will-change:transform,opacity}
#titleLogoLine{display:flex;flex-direction:column;align-items:flex-start;gap:4px;line-height:.95}
#titleLogoTop{display:flex;align-items:stretch;gap:0;width:100%;letter-spacing:2px;text-transform:uppercase;font-weight:800;font-size:64px;color:#fff;text-shadow:0 4px 18px rgba(0,0,0,.55)}
#titleMESvg{display:block;height:72px;width:100%;margin-left:0}
#titleLogoSub{font-family:'Montserrat','Segoe UI',sans-serif;font-weight:700;font-size:34px;letter-spacing:6px;text-transform:uppercase;color:rgba(245,245,250,.95);text-shadow:0 4px 18px rgba(0,0,0,.55);margin-top:2px}
#titlePressLine{margin-top:10px;font-family:'Montserrat','Segoe UI',sans-serif;font-weight:600;font-size:18px;letter-spacing:3.5px;text-transform:uppercase;color:rgba(255,255,255,.92);text-shadow:0 3px 12px rgba(0,0,0,.65);animation:titleBlinkAnim ]] .. blinkStr .. [[s ease-in-out infinite}

#loadingScreen{position:fixed;inset:0;display:none;z-index:2500;pointer-events:none;color:#fff}
#loadingScreen.show{display:block}
#loadCorner{position:fixed;right:60px;bottom:60px;display:flex;align-items:center;gap:14px;opacity:0;animation:loadFadeIn .9s cubic-bezier(.4,0,.2,1) .25s both}
/* the spinner says everything the caption did. CREATING LOBBY / LOADING DATA / CONNECTING TO MATCH
   are still set by the Lua side (MainMenu.LoadingMessages) -- they are simply not shown any more, so
   putting the line back is one display change and nothing else. */
#loadStatus{display:none;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:13px;letter-spacing:2.5px;color:rgba(255,255,255,.62);text-transform:uppercase;white-space:nowrap}
#loadSpinner{width:42px;height:42px;animation:lSpin 1.1s linear infinite;will-change:transform}
#loadSpinner circle{fill:none;stroke:rgba(255,255,255,.92);stroke-width:2.2;stroke-linecap:round;stroke-dasharray:88;stroke-dashoffset:62}

#matchLoad{position:fixed;top:0;left:0;right:0;bottom:0;width:100%;height:100%;z-index:2520;display:none;overflow:hidden;background:linear-gradient(180deg,rgb(46,94,150) 0%,rgb(26,58,102) 36%,rgb(16,38,74) 100%)}
#matchLoad.show{display:block;animation:mlFadeIn ]] .. string.format("%.2f", (params.matchFadeIn or 0.55)) .. [[s ease both}
@keyframes mlFadeIn{from{opacity:0}to{opacity:1}}
.mlBanner{position:absolute;top:0;left:0;right:0;bottom:0;background-position:center center;background-size:cover;background-repeat:no-repeat}
.mlScrim{position:absolute;top:0;left:0;right:0;height:46%;background:linear-gradient(180deg,rgba(10,26,52,.34) 0%,rgba(10,26,52,0) 100%);pointer-events:none;z-index:1}
.mlInfo{position:absolute;left:64px;top:74px;z-index:2}
.mlTitle{margin-left:-1px;font-family:'Montserrat','Segoe UI',sans-serif;font-weight:500;font-size:74px;letter-spacing:1px;color:#fff;line-height:.96;text-shadow:0 3px 20px rgba(0,0,0,.5)}
.mlMode{margin-top:6px;margin-left:-1px;font-family:'Montserrat','Segoe UI',sans-serif;font-weight:600;font-size:21px;letter-spacing:5px;color:rgba(221,229,239,.72);text-transform:uppercase;text-shadow:0 2px 12px rgba(0,0,0,.55)}
.mlSpinner{position:absolute;right:54px;bottom:48px;width:92px;height:92px;z-index:2}
.mlSpinner svg{width:92px;height:92px;animation:lSpin 1.1s linear infinite;will-change:transform}
.mlSpinner circle{fill:none;stroke:rgba(255,255,255,.95);stroke-width:2.2;stroke-linecap:round;stroke-dasharray:88;stroke-dashoffset:62}
.mlFade{position:absolute;top:0;left:0;right:0;bottom:0;background:#000;opacity:0;pointer-events:none;z-index:5}

#mainMenu{position:fixed;inset:0;display:none;z-index:2300;color:#f2f3f5;pointer-events:none;font-family:'HanleyPro','Segoe UI',sans-serif}
#mainMenu.show{display:block}
#mainMenu .sec{pointer-events:auto}
#mmOverlay{position:fixed;inset:0;z-index:2301;pointer-events:none;background:rgba(0,0,0,.62)}
#mmHex{position:fixed;top:78px;left:0;right:0;bottom:0;z-index:2302;pointer-events:none;overflow:hidden;-webkit-mask-image:radial-gradient(150% 110% at 50% 100%,transparent 66%,#000 90%);-webkit-mask-repeat:no-repeat;mask-image:radial-gradient(150% 110% at 50% 100%,transparent 66%,#000 90%);mask-repeat:no-repeat}
#mmHexInner{position:absolute;inset:-180px;will-change:transform;transform:translateZ(0);backface-visibility:hidden;animation:hexDrift 60s linear infinite}
#mmHexInner svg{display:block}
#mmHexInner polygon{pointer-events:none;stroke-opacity:.05;fill:rgba(150,190,255,0)}

#mmTopbar{position:fixed;left:0;right:0;top:0;height:78px;z-index:2360;animation:menuIn .45s cubic-bezier(.4,0,.2,1) both;background:rgba(16,16,16,.45);border-bottom:1px solid rgba(39,39,39,1)}
.tbBarBg{display:none}
.tbBrand{display:none}
.tbCenter{position:absolute;left:50%;top:0;height:78px;transform:translateX(-50%);display:flex;align-items:center;gap:10px;pointer-events:auto}
.tbHome{width:48px;height:48px;display:flex;align-items:center;justify-content:center;cursor:pointer;margin-right:14px;transition:opacity .15s,transform .15s;opacity:.78}
.tbHome img{width:29px;height:25px;object-fit:contain;filter:drop-shadow(0 2px 4px rgba(0,0,0,.5))}
.tbHome:hover,.tbHome.active{opacity:1}
.tbHome:hover{transform:scale(1.05)}
.tbNav{position:relative;top:0;height:46px;display:flex;align-items:center;justify-content:center;padding:0 24px;cursor:pointer;font-family:'HanleyPro','Segoe UI',sans-serif;font-weight:300;font-size:24px;letter-spacing:1.8px;color:rgba(112,113,113,1);transition:color .15s}
.tbNav::before{content:'';position:absolute;left:0;right:0;top:5px;bottom:-3px;border-radius:5px;background:transparent;transition:background .15s;z-index:0}
.tbNav span{position:relative;left:1px;z-index:1}
.tbNav:hover{color:rgba(205,205,205,1)}
.tbNav.active{color:#fff}
.tbNav.active::before{background:rgba(222,43,97,1)}
.tbRight{position:absolute;right:18px;top:0;height:78px;display:flex;align-items:center;gap:8px;pointer-events:auto;transition:transform .32s cubic-bezier(.4,0,.2,1)}
.curBox{display:flex;align-items:center;height:35px;padding:0 5px 0 9px;background:rgba(16,16,16,1);border:1px solid rgba(39,39,39,1);border-radius:9px;gap:6px}
.curIco{width:30px;height:30px;display:flex;align-items:center;justify-content:center}
.curIco img{width:30px;height:30px;object-fit:contain;filter:drop-shadow(0 1px 2px rgba(0,0,0,.5))}
.curVal{font-family:'Rajdhani','Segoe UI',sans-serif;font-weight:700;font-size:19px;letter-spacing:.6px;min-width:12px;text-align:left}
.fragVal{color:rgba(120,157,236,1)}
.gemVal{color:rgba(239,113,237,1)}
.curPlus{width:25px;height:25px;display:flex;align-items:center;justify-content:center;margin-left:3px;background:rgba(223,41,233,1);border-radius:6px;color:#fff;cursor:pointer}
.curPlus svg{width:14px;height:14px;display:block}
.curPlus:hover{filter:brightness(1.12)}
.tbAvatar{display:none}

#mmSubnav{position:fixed;left:0;right:0;top:78px;height:44px;z-index:2355;pointer-events:none;animation:menuIn .45s cubic-bezier(.4,0,.2,1) .05s both}
.snTabs{position:absolute;left:50%;top:0;height:44px;transform:translateX(-50%);display:flex;align-items:center;justify-content:center;gap:30px;pointer-events:auto;white-space:nowrap}
.snTab{cursor:pointer;font-family:'HanleyPro','Segoe UI',sans-serif;font-weight:300;font-size:20px;letter-spacing:1.8px;color:rgba(112,113,113,1);transition:color .15s;text-shadow:0 1px 4px rgba(0,0,0,.6);white-space:nowrap}
.snTab:hover{color:rgba(205,205,205,1)}
.snTab.active{color:rgba(255,255,255,1)}

/* DISCONNECTED FROM A MATCH: no panel background, centred REJOIN button, top-left, only in the PLAY tab */
#mmReconnect{position:fixed;left:34px;top:104px;z-index:2402;display:none;flex-direction:column;align-items:center;gap:16px;pointer-events:auto;animation:menuIn .3s ease both}
#mainMenu.rcOpen:not(.navShop):not(.navInv) #mmReconnect{display:flex}
.rcTitle{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:800;font-size:20px;letter-spacing:.4px;color:#fff;text-shadow:0 1px 4px rgba(0,0,0,.85)}
.rcBtn{width:186px;height:54px;background:#ff8018;border-radius:9px;display:flex;align-items:center;justify-content:center;cursor:pointer;box-shadow:inset 0 2px 0 rgba(255,255,255,.2),0 4px 12px rgba(0,0,0,.4);transition:filter .12s,transform .1s}
.rcBtn:hover{filter:brightness(1.08);transform:translateY(-1px)}
.rcBtn span{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:800;font-size:24px;letter-spacing:1px;color:#fff}
#mmLobby{position:fixed;left:0;right:0;top:122px;bottom:196px;z-index:2335;display:flex;align-items:stretch;justify-content:center;pointer-events:none}
/* two equal-width flex sides keep the leader banner dead-centre no matter how many joiners each holds.
   .lbMembers must span a fixed width (not shrink-to-fit) so the two flex:1 sides are truly equal. */
.lbMembers{display:flex;align-items:center;justify-content:center;pointer-events:auto;width:100%;max-width:1300px}
.lbSide{flex:1 1 0;display:flex;align-items:center;gap:14px;min-width:0}
.lbSideL{justify-content:flex-end}
.lbSideR{justify-content:flex-start}
/* leader banner: a full-height vertical column (subnav separator down to the SELECT MODE box), masked,
   with the avatar + crown centred inside it */
.lobbyBanner{position:relative;width:248px;flex:none;align-self:stretch;margin:0 14px;display:flex;flex-direction:column;align-items:center;justify-content:center;background:rgba(16,16,18,.55);padding:18px 14px;cursor:pointer;animation:vbIn .5s backwards;-webkit-mask-image:linear-gradient(to bottom,transparent 0%,#000 14%,#000 86%,transparent 100%);mask-image:linear-gradient(to bottom,transparent 0%,#000 14%,#000 86%,transparent 100%)}
.lbAvatar{width:220px;height:220px;border-radius:6px;background:#2b2e36 center/cover no-repeat;box-shadow:0 6px 18px rgba(0,0,0,.5);border:1px solid rgba(255,255,255,.12)}
.lbName{margin-top:12px;max-width:100%;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:19px;letter-spacing:.4px;color:#fff;text-align:center;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;text-shadow:0 1px 4px rgba(0,0,0,.7)}
.lbCrown{margin-top:10px;width:36px;height:36px;cursor:default;transition:transform .25s}
.lbCrown img{width:36px;height:36px;object-fit:contain;filter:drop-shadow(0 1px 3px rgba(0,0,0,.6));transition:filter .3s}
/* joiners: plain square (avatar + name), no banner mask, sitting left/right of the leader */
.lobbyMate{position:relative;display:flex;flex-direction:column;align-items:center;justify-content:center;width:150px;animation:vbIn .4s backwards}
.lbMateAv{width:132px;height:132px;border-radius:8px;background:#2b2e36 center/cover no-repeat;box-shadow:0 6px 18px rgba(0,0,0,.5);border:1px solid rgba(255,255,255,.12)}
.lbMateName{margin-top:11px;max-width:100%;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:16px;color:#fff;text-align:center;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;text-shadow:0 1px 4px rgba(0,0,0,.7)}
/* kick: a red "KICK" rectangle under the joiner's name, shown to the leader on hover. It sits IN FLOW
   (space always reserved via visibility:hidden) so there is no gap between the name and the button --
   the cursor can travel from the square onto the button without the hover dropping. */
.lbKick{margin-top:11px;height:30px;padding:0 17px;border-radius:7px;background:rgba(200,46,46,.95);display:flex;align-items:center;justify-content:center;visibility:hidden;cursor:pointer;box-shadow:0 3px 10px rgba(0,0,0,.45);transition:filter .12s;white-space:nowrap}
.lbKick span{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:14px;letter-spacing:1.5px;color:#fff}
.lbKick:hover{filter:brightness(1.12)}
#mainMenu.isLeader .lobbyMate:hover .lbKick{visibility:visible}
/* the + is a real flex item in the right side (never overlaps joiners) */
.lbAdd{flex:none;width:86px;height:86px;border-radius:50%;background:rgba(255,255,255,.06);border:1.5px solid rgba(255,255,255,.22);display:flex;align-items:center;justify-content:center;cursor:pointer;pointer-events:auto;box-shadow:0 8px 24px rgba(0,0,0,.4);transition:transform .25s,background .25s}
.lbAdd:hover{transform:scale(1.08);background:rgba(255,255,255,.1)}
.lbAdd svg{width:52px;height:52px;display:block}
#mainMenu:not(.isLeader) .lbAdd{display:none}

#mmMode{position:fixed;left:0;right:0;bottom:26px;z-index:2340;display:flex;flex-direction:column;align-items:center;gap:11px;pointer-events:none;animation:menuIn .45s cubic-bezier(.4,0,.2,1) .14s both}
#mmMode .mpSelected,#mmMode .mpButtons,#mmMode .mpBtn{pointer-events:auto}
.mpSelected{width:248px;height:74px;background:rgba(6,6,6,.92);border:1px solid rgba(39,39,39,1);border-radius:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
.mpSelLabel{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:16px;letter-spacing:2.5px;color:#9a9fa6;text-transform:uppercase}
.mpSelValue{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:32px;letter-spacing:1.5px;color:#fff;margin-top:3px}
.mpButtons{display:flex;align-items:stretch;gap:12px}
.mpBtn{height:74px;display:flex;align-items:center;justify-content:center;border-radius:0;cursor:pointer;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;letter-spacing:2px;color:#e8eaed;border:1px solid rgba(39,39,39,1);transition:filter .15s,transform .12s}
.mpBtn span{position:relative;top:1px}
.mpChange{width:178px;font-size:26px;background:rgba(6,6,6,.92)}
.mpQueue{width:248px;font-size:31px;color:#fff;background:rgba(39,148,194,1);overflow:hidden;position:relative}
.qAur{position:absolute;top:0;left:0;right:0;bottom:0;z-index:0;pointer-events:none;overflow:hidden}
.qAur .qShine{position:absolute;top:0;bottom:0;left:0;width:55%;background:linear-gradient(105deg,transparent 0%,rgba(255,255,255,.18) 50%,transparent 100%);animation:qShine 5s ease-in-out infinite}
.mpQueue span{position:relative;z-index:1}
.mpQueue.cancelling{background:rgba(200,46,46,1)}
.mpLeave{width:178px;font-size:26px;font-weight:700;background:rgba(6,6,6,.92)}
.mpBtn:not(.disabled):hover{filter:brightness(1.12);transform:translateY(-1px)}
.mpBtn:not(.disabled):active{transform:translateY(0)}
.mpLeave.disabled{color:#585d65;cursor:default}

#mainMenu.modeSelecting #mmLobby,
#mainMenu.modeSelecting #mmMode{display:none}
#mainMenu.modeSelecting #mmFinding{opacity:0;pointer-events:none}
#mmModeSelect{position:fixed;left:0;right:0;top:50%;z-index:2336;display:flex;flex-direction:column;align-items:center;pointer-events:none;opacity:0;transform:translateY(-50%);transition:opacity .32s ease}
#mainMenu.modeSelecting #mmModeSelect{opacity:1;pointer-events:auto}
.msBar{width:100%;max-width:1460px;height:48px;display:flex;align-items:center;justify-content:center;background:rgba(16,16,16,.85);border:1px solid rgba(39,39,39,1);font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:19px;letter-spacing:3px;color:#fff;text-transform:uppercase}
.msGrid{width:100%;max-width:1460px;height:54vh;display:flex;gap:8px;padding:12px 0 0}
/* each mode sits in a NON-clipping cell so its SOON/NEW pill can straddle the bottom edge without being
   cut by the banner's overflow:hidden */
.msCell{flex:1;position:relative;display:flex;min-width:0}
.msCellH{flex:1;position:relative;display:flex;min-width:0}
.msCol{flex:1;display:flex;flex-direction:column;gap:8px;position:relative}
.msBanner{flex:1;position:relative;background:#16161a center center/cover no-repeat;border:1px solid rgba(255,255,255,.92);overflow:hidden;cursor:pointer;transition:transform .2s cubic-bezier(.4,0,.2,1)}
.msHalf{flex:1}
.msBanner::before{content:'';position:absolute;inset:0;background:rgba(0,0,0,.28);z-index:1;pointer-events:none}
.msBanner::after{content:'';position:absolute;top:0;bottom:0;left:0;width:42%;background:linear-gradient(105deg,transparent,rgba(255,255,255,.22),transparent);transform:translateX(-180%) skewX(-12deg);opacity:0;z-index:3;pointer-events:none}
.msBanner:hover{transform:scale(1.012)}
.msBanner:hover::after{animation:msSheen .75s ease-out}
.msShade{position:absolute;left:0;right:0;bottom:0;height:62%;background:linear-gradient(to top,rgba(0,0,0,.88),rgba(0,0,0,.35) 55%,transparent);z-index:1;pointer-events:none}
.msWins{position:absolute;top:12px;left:13px;display:flex;align-items:center;gap:7px;z-index:2}
.msWins img{width:33px;height:33px;object-fit:contain;filter:drop-shadow(0 1px 3px rgba(0,0,0,.85))}
.msWins span{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:26px;color:#fff;text-shadow:0 1px 4px rgba(0,0,0,.9)}
.msInfo{position:absolute;left:0;right:0;bottom:0;padding:0 18px 18px;z-index:2;text-align:center}
.msName{font-family:'MEBig','EinaSemiBold',sans-serif;font-weight:400;font-size:34px;letter-spacing:.5px;color:#fff;line-height:1.05;text-shadow:0 2px 6px rgba(0,0,0,.85)}
.msName em{font-style:normal;font-weight:400;font-size:21px;opacity:.85;margin-left:5px;font-family:'EinaSemiBold',sans-serif}
.msDesc{font-family:'BarlowLight','Segoe UI',sans-serif;font-weight:300;font-size:13.5px;line-height:1.4;color:rgba(255,255,255,.8);margin:6px auto 9px;max-width:90%;text-shadow:0 1px 4px rgba(0,0,0,.85)}
.msQueue{font-family:'MEFin','EinaSemiBold',sans-serif;font-weight:400;font-size:14px;letter-spacing:1px;color:rgba(255,255,255,.75);text-transform:uppercase}
.msNew{position:absolute;left:50%;bottom:0;transform:translate(-50%,50%);background:#46d33b;color:#0a2a06;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:13px;letter-spacing:1px;padding:5px 16px;border-radius:3px;z-index:5;text-shadow:none}
/* disabled / coming-soon modes: desaturated, dimmed, non-interactive, stamped SOON */
.msBanner.msLocked{cursor:not-allowed;filter:grayscale(1) brightness(.5) contrast(.9)}
.msBanner.msLocked:hover{transform:none}
.msBanner.msLocked:hover::after{animation:none}
.msSoon{position:absolute;left:50%;bottom:0;transform:translate(-50%,50%);background:#6b7178;color:#0c0d0f;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:13px;letter-spacing:1px;padding:5px 16px;border-radius:3px;z-index:6;text-shadow:none;filter:none}
.cmItem{position:relative}
.cmItem.cmLocked{cursor:not-allowed;filter:grayscale(1) brightness(.55)}
.cmItem.cmLocked .cmSoon{position:absolute;top:6px;right:6px;background:#6b7178;color:#0c0d0f;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:10px;letter-spacing:1px;padding:2px 7px;border-radius:3px}

#mmInvite{position:fixed;top:0;right:0;bottom:0;width:374px;z-index:2370;display:flex;flex-direction:column;padding:0 18px 0;background:rgba(14,14,16,.7);box-shadow:-10px 0 44px rgba(0,0,0,.55),0 0 30px rgba(255,255,255,.07);transform:translateX(100%);transition:transform .32s cubic-bezier(.4,0,.2,1);pointer-events:auto}
#mmInvite::before{content:'';position:absolute;left:0;top:78px;bottom:0;width:1px;background:rgba(255,255,255,.10);pointer-events:none}
#mmInvite.show{transform:translateX(0)}
#mainMenu.inviteOpen .tbRight{transform:translateX(-388px)}
#mmMatches{transition:opacity .3s ease}
#mainMenu.inviteOpen #mmFinding{opacity:0;pointer-events:none}
#mainMenu.inviteOpen #mmMatches{animation:none;opacity:0;pointer-events:none}

.ivSelf{display:flex;align-items:center;gap:13px;height:78px;padding:0 4px}
.ivAvatar{width:54px;height:54px;border-radius:8px;background:#2b2e36 center/cover no-repeat;border:1px solid rgba(255,255,255,.12);flex:none}
.ivSelfTxt{display:flex;flex-direction:column;gap:3px;min-width:0}
.ivSelfName{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:19px;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:255px}
.ivLobbyTag{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:14px;color:rgba(232,58,120,1)}
.ivRank{display:flex;align-items:center;gap:11px;padding:14px 4px;border-bottom:1px solid rgba(255,255,255,.07)}
.ivRankIco{width:34px;height:34px;object-fit:contain}
.ivRankTxt{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:18px;letter-spacing:1px;color:#9a9fa6;text-transform:uppercase}
.ivFriendsTitle{text-align:center;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:17px;letter-spacing:2px;color:#fff;text-transform:uppercase;padding:15px 0 10px}
.ivFriends{flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:6px;min-height:0}
.ivFriends::-webkit-scrollbar{width:6px}
.ivFriends::-webkit-scrollbar-thumb{background:rgba(255,255,255,.12);border-radius:3px}
.ivFriend{display:flex;align-items:center;gap:11px;background:rgba(255,255,255,.04);border-radius:7px;padding:8px 9px}
.ivFrAvatar{width:40px;height:40px;border-radius:6px;background:#2b2e36 center/cover no-repeat;flex:none}
.ivFrTxt{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px}
.ivFrName{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:15px;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ivFrStatus{font-family:'HanleyPro','Segoe UI',sans-serif;font-size:12px;color:#5fd06a}
.ivInviteBtn{flex:none;padding:8px 16px;background:#fff;border-radius:6px;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:13px;letter-spacing:.5px;color:#15171a;cursor:pointer;transition:filter .15s,transform .1s}
.ivInviteBtn:hover{filter:brightness(.9)}
.ivInviteBtn:active{transform:scale(.95)}
.ivFriendsEmpty{text-align:center;color:#6c7178;font-family:'HanleyPro','Segoe UI',sans-serif;font-size:13px;padding:22px 0}
.ivFooter{padding:13px 0 16px;border-top:1px solid rgba(255,255,255,.07)}
.ivMini{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:12px;letter-spacing:1.5px;color:#8a8f96;text-transform:uppercase;margin-bottom:7px}
.ivJoinLbl{margin-top:15px}
.ivCodeRow{display:flex;align-items:center;gap:10px;background:rgba(8,8,8,.85);border:1px solid rgba(39,39,39,1);border-radius:7px;padding:7px 11px}
.invCode{flex:1;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:22px;letter-spacing:4px;color:#fff}
.invEye{width:36px;height:36px;display:flex;align-items:center;justify-content:center;cursor:pointer;border-radius:5px;transition:background .15s,opacity .15s}
.invEye:hover{background:rgba(255,255,255,.08)}
.invEye img{width:28px;height:28px;object-fit:contain}
.invEye.off{opacity:.42}
.ivJoinRow{display:flex;gap:9px}
.invInput{flex:1;height:44px;background:rgba(8,8,8,.85);border:1px solid rgba(39,39,39,1);border-radius:7px;padding:0 13px;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-size:15px;letter-spacing:2px;color:#fff;text-transform:uppercase;outline:none;transition:border-color .15s}
.invInput::placeholder{color:#585d65;letter-spacing:1px}
.invInput:focus{border-color:rgba(120,120,120,1)}
.invInput.bad{border-color:#ff5555;animation:invShake .42s cubic-bezier(.36,.07,.19,.97)}
.invInput.ok{border-color:#46d33b}
.invJoinBtn{position:relative;overflow:hidden;min-width:92px;height:44px;display:flex;align-items:center;justify-content:center;background:rgba(39,148,194,1);border-radius:7px;cursor:pointer}
.invJoinBtn span{position:relative;z-index:1;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-size:17px;letter-spacing:1px;color:#fff}
.ivJoinShine{position:absolute;top:0;bottom:0;left:0;width:55%;background:linear-gradient(105deg,transparent 0%,rgba(255,255,255,.32) 50%,transparent 100%);animation:qShine 5s ease-in-out infinite;z-index:0}
.invToast{min-height:15px;margin-top:9px;text-align:center;font-family:'HanleyPro','Segoe UI',sans-serif;font-size:12.5px;color:#ff8585}
.ivBack{margin-top:13px;height:48px;display:flex;align-items:center;justify-content:center;background:rgba(222,43,97,1);border-radius:7px;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-size:17px;letter-spacing:1.5px;color:#fff;text-transform:uppercase;cursor:pointer;transition:filter .15s}
.ivBack:hover{filter:brightness(1.08)}
@keyframes invShake{0%,100%{transform:translateX(0)}20%{transform:translateX(-5px)}40%{transform:translateX(5px)}60%{transform:translateX(-4px)}80%{transform:translateX(3px)}}

#mmChat{position:fixed;left:20px;bottom:26px;width:430px;z-index:2330;display:flex;flex-direction:column;gap:0;pointer-events:auto;animation:menuIn .45s cubic-bezier(.4,0,.2,1) .16s both}
.chatLog{height:260px;overflow-y:auto;overflow-x:hidden;display:flex;flex-direction:column;background:rgba(20,20,20,.35);-webkit-backdrop-filter:blur(4px);backdrop-filter:blur(4px);padding:0 10px 8px;direction:rtl;-webkit-mask-image:linear-gradient(to top,#000 35%,transparent 100%);mask-image:linear-gradient(to top,#000 35%,transparent 100%);opacity:.5;transition:opacity .2s linear}
.chatLog>*{direction:ltr}
.chatLog>*:first-child{margin-top:auto}
#mmChat.cActive .chatLog,#mmChat:hover .chatLog{opacity:1;-webkit-mask-image:none;mask-image:none}
.chatLog::-webkit-scrollbar{width:5px}
.chatLog::-webkit-scrollbar-track{background:rgba(255,255,255,.06)}
.chatLog::-webkit-scrollbar-thumb{background:rgba(255,255,255,.32);border-radius:0}
.chatLog::-webkit-scrollbar-thumb:hover{background:rgba(255,255,255,.5)}
.chatLine{font-family:'BarlowLight','Segoe UI',sans-serif;font-weight:300;font-size:16px;line-height:18px;margin-bottom:2px;color:rgba(200,200,200,.9);text-shadow:0 1px 1px rgba(0,0,0,.47);word-wrap:break-word;-webkit-user-select:text;user-select:text;cursor:text}
.chatLine.chMsg{display:flex;align-items:center;gap:8px;margin-bottom:4px}
.chAvatar{flex:0 0 24px;width:24px;height:24px;border-radius:4px;background:#2b2e36 center/cover no-repeat;box-shadow:0 1px 3px rgba(0,0,0,.5)}
.chBody{flex:1;min-width:0}
.chSys{font-family:'EinaSemiBold','Segoe UI',sans-serif;color:rgba(180,180,180,1)}
.chUser{font-family:'EinaSemiBold','Segoe UI',sans-serif;color:#dcdfe4}
.chRare{font-weight:700}
.chItem{font-family:'EinaSemiBold','Segoe UI',sans-serif}
.chRed{color:#e2473d}
.chBlue{color:#4a9bff}
.chatInput{height:30px;width:100%;padding:0 8px;background:rgba(22,22,22,.62);border:1px solid rgba(255,255,255,.09);border-radius:2px;font-family:'BarlowLight','Segoe UI',sans-serif;font-weight:300;font-size:16px;color:#e6e8ec;letter-spacing:.3px;outline:none;pointer-events:auto;cursor:text;-webkit-user-select:text;user-select:text;opacity:.6;transition:opacity .2s linear,border-color .15s}
#mmChat.cActive .chatInput,#mmChat:hover .chatInput{opacity:1}
.chatInput::placeholder{color:rgba(200,200,200,.6)}
.chatInput:focus{border-color:rgba(255,255,255,.22)}
.chatInput:focus::placeholder{color:transparent}

#mmFinding{position:fixed;right:24px;bottom:54px;z-index:2345;width:262px;padding:13px 18px 11px;background:rgba(39,148,194,.96);border:none;border-radius:5px;box-shadow:0 8px 26px rgba(0,0,0,.42);text-align:center;overflow:hidden;pointer-events:none;opacity:0;transform:translateY(14px) scale(.96);transition:opacity .38s cubic-bezier(.4,0,.2,1),transform .38s cubic-bezier(.4,0,.2,1)}
#mmFinding.show{opacity:1;transform:translateY(0) scale(1)}
.fdShine{position:absolute;top:0;bottom:0;left:0;width:55%;background:linear-gradient(105deg,transparent 0%,rgba(255,255,255,.17) 50%,transparent 100%);animation:qShine 5s ease-in-out infinite;pointer-events:none;z-index:0}
#mmFinding i{position:absolute;z-index:2;pointer-events:none}
.fcTRh{top:0;right:0;height:3px;width:70px;background:linear-gradient(to left,#d2f4ff,rgba(170,228,255,0))}
.fcTRv{top:0;right:0;width:3px;height:70px;background:linear-gradient(to bottom,#d2f4ff,rgba(170,228,255,0))}
.fcBLh{bottom:0;left:0;height:3px;width:70px;background:linear-gradient(to right,#d2f4ff,rgba(170,228,255,0))}
.fcBLv{bottom:0;left:0;width:3px;height:70px;background:linear-gradient(to top,#d2f4ff,rgba(170,228,255,0))}
.fdTitle{position:relative;z-index:1;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:15px;letter-spacing:1.8px;color:#fff;text-transform:uppercase;text-shadow:0 1px 4px rgba(0,0,0,.35)}
.fdTimer{position:relative;z-index:1;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:34px;letter-spacing:1px;color:#fff;line-height:1.05;margin:3px 0 4px}
.fdSub{position:relative;z-index:1;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:12px;letter-spacing:1.2px;color:rgba(255,255,255,.85);text-transform:uppercase}

#mmMatches{position:fixed;right:24px;bottom:26px;z-index:2330;display:flex;align-items:center;gap:9px;pointer-events:none;font-family:'EinaSemiBold','Segoe UI',sans-serif;animation:menuIn .45s cubic-bezier(.4,0,.2,1) .16s both}
.amCount{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:18px;color:#fff;letter-spacing:1px;text-shadow:0 1px 5px rgba(0,0,0,.85)}
.amLabel{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:18px;letter-spacing:1px;color:#fff;text-shadow:0 1px 5px rgba(0,0,0,.85)}
.amIco{width:24px;height:24px;object-fit:contain;filter:drop-shadow(0 1px 3px rgba(0,0,0,.7));animation:amSpin 7s linear infinite}

#mmNotif{position:fixed;top:90px;right:24px;z-index:2365;width:262px;padding:13px 18px 12px;background:rgba(200,46,46,.96);box-shadow:0 8px 26px rgba(0,0,0,.42);overflow:hidden;pointer-events:none;opacity:0;transform:translateX(125%);transition:opacity .3s ease,transform .42s cubic-bezier(.22,1,.36,1)}
#mmNotif.ntOk{background:rgba(43,158,71,.96)}
#mmNotif.show{opacity:1;transform:translateX(0)}
.ntShine{position:absolute;top:0;bottom:0;left:0;width:55%;background:linear-gradient(105deg,transparent 0%,rgba(255,255,255,.16) 50%,transparent 100%);animation:qShine 5s ease-in-out infinite;pointer-events:none;z-index:0}
#mmNotif i,#mmInviteReq i{position:absolute;z-index:2;pointer-events:none}
#mmInviteReq{position:fixed;top:90px;right:24px;z-index:2366;width:262px;padding:13px 18px 14px;background:rgba(30,34,44,.97);box-shadow:0 8px 26px rgba(0,0,0,.5);overflow:hidden;pointer-events:none;opacity:0;transform:translateX(125%);transition:opacity .3s ease,transform .42s cubic-bezier(.22,1,.36,1)}
#mmInviteReq.show{opacity:1;transform:translateX(0);pointer-events:auto}
.irBtns{position:relative;z-index:3;display:flex;gap:10px;margin-top:12px}
.irBtn{flex:1 1 0;height:34px;display:flex;align-items:center;justify-content:center;cursor:pointer;box-shadow:inset 0 2px 0 rgba(255,255,255,.18),0 3px 10px rgba(0,0,0,.38);transition:filter .12s,transform .1s}
.irBtn:hover{filter:brightness(1.12);transform:translateY(-1px)}
.irBtn span{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:15px;letter-spacing:1.2px;color:#fff;text-shadow:0 1px 4px rgba(0,0,0,.45)}
.irYes{background:rgba(43,158,71,.96)}
.irNo{background:rgba(200,46,46,.96)}
.ntcTRh{top:0;right:0;height:3px;width:62px;background:linear-gradient(to left,rgba(255,255,255,.92),rgba(255,255,255,0))}
.ntcTRv{top:0;right:0;width:3px;height:62px;background:linear-gradient(to bottom,rgba(255,255,255,.92),rgba(255,255,255,0))}
.ntcBLh{bottom:0;left:0;height:3px;width:62px;background:linear-gradient(to right,rgba(255,255,255,.92),rgba(255,255,255,0))}
.ntcBLv{bottom:0;left:0;width:3px;height:62px;background:linear-gradient(to top,rgba(255,255,255,.92),rgba(255,255,255,0))}
.ntText{position:relative;z-index:1;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:15px;letter-spacing:.4px;line-height:1.32;color:#fff;text-align:center;text-shadow:0 1px 4px rgba(0,0,0,.38)}

#mmReward{position:fixed;top:0;left:0;right:0;bottom:0;width:100%;height:100%;z-index:2500;display:none;flex-direction:column;align-items:center;justify-content:center;background:radial-gradient(circle at 50% 40%,rgba(255,176,80,1) 0%,rgba(250,154,45,1) 52%,rgba(238,135,28,1) 100%);pointer-events:auto}
#mmReward.show{display:flex}
.rwContent{display:flex;flex-direction:column;align-items:center}
.rwTitle{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:46px;letter-spacing:2px;color:#fff;text-shadow:0 3px 12px rgba(0,0,0,.2);margin-bottom:58px}
.rwCard{display:flex;flex-direction:column;align-items:center}
.rwSquare{position:relative;width:172px;height:172px;background:rgba(54,54,54,1);border:1px solid rgba(89,89,89,1);border-radius:6px;display:flex;align-items:center;justify-content:center;overflow:hidden;box-shadow:0 16px 36px rgba(0,0,0,.28)}
.rwSheen{position:absolute;top:0;bottom:0;left:-30%;width:46%;background:linear-gradient(105deg,transparent,rgba(255,255,255,.07),transparent);transform:skewX(-12deg)}
.rwIcon{max-width:62%;max-height:62%;object-fit:contain;filter:drop-shadow(0 5px 12px rgba(0,0,0,.45))}
.rwCount{position:absolute;left:11px;bottom:7px;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:23px;color:#fff;text-shadow:0 2px 5px rgba(0,0,0,.7)}
.rwName{margin-top:15px;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:18px;letter-spacing:1px;color:#fff;text-transform:uppercase}
.rwType{margin-top:3px;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:15px;letter-spacing:1.5px;color:rgba(255,255,255,.62);text-transform:uppercase}
.rwClose{margin-top:66px;width:230px;height:64px;display:flex;align-items:center;justify-content:center;background:rgba(208,64,206,1);border:2px solid rgba(177,67,177,1);border-radius:4px;cursor:pointer;box-shadow:0 10px 26px rgba(0,0,0,.22);transition:filter .15s,transform .12s}
.rwClose span{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:26px;letter-spacing:1.5px;color:#fff}
.rwClose:hover{filter:brightness(1.08)}
.rwClose:active{transform:translateY(1px)}
#mmReward.show{animation:rwFadeIn .3s ease both}
#mmReward.closing{animation:rwFadeOut .3s ease forwards;pointer-events:none}
@keyframes rwFadeIn{from{opacity:0}to{opacity:1}}
@keyframes rwFadeOut{from{opacity:1}to{opacity:0}}

#mmRanks{position:fixed;left:0;right:0;top:122px;bottom:0;width:min(1180px,86vw);height:min(560px,72vh);margin:auto;z-index:2335;display:none;flex-direction:column;background:rgba(16,16,16,.6);border:1px solid rgba(39,39,39,1);pointer-events:auto;contain:layout paint;will-change:transform;transform:translateZ(0);animation:menuIn .4s cubic-bezier(.4,0,.2,1) both}
#mainMenu.subRanks #mmRanks{display:flex}
#mainMenu.subRanks #mmLobby,#mainMenu.subRanks #mmMode,#mainMenu.subRanks #mmChat{display:none}
.rkTitleBar{height:58px;flex:0 0 58px;display:flex;align-items:center;justify-content:center;padding-bottom:6px;border-bottom:1px solid rgba(39,39,39,1);font-family:'HanleyPro','Segoe UI',sans-serif;font-weight:300;font-size:30px;letter-spacing:2px;color:#fff;text-shadow:0 1px 4px rgba(0,0,0,.6)}
.rkGrid{flex:1;display:flex;align-items:stretch;padding:18px 22px 24px}
.rkCol{flex:1;display:flex;flex-direction:column;align-items:center;border-left:1px solid rgba(255,255,255,.05)}
.rkCol:first-child{border-left:none}
.rkHead{height:52px;display:flex;flex-direction:column;align-items:center;gap:3px}
.rkTitle{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:20px;letter-spacing:2px;color:#9a9fa6;text-transform:uppercase}
.rkTop{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:13px;letter-spacing:1px;color:#fff;text-transform:uppercase}
.rkStack{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;padding:6px 0 2px}
.rkStack.rkSingle{justify-content:center}
.rkBadge{width:104px;height:104px;object-fit:contain;filter:drop-shadow(0 4px 10px rgba(0,0,0,.5))}
.rkArrow{width:30px;height:30px;object-fit:contain;opacity:.7}

#mmLeaderboard{position:fixed;left:0;right:0;top:122px;bottom:0;width:min(1000px,80vw);height:min(620px,80vh);margin:auto;z-index:2335;display:none;flex-direction:column;background:rgba(13,13,15,.97);border:1px solid rgba(39,39,39,1);box-shadow:0 18px 60px rgba(0,0,0,.55);overflow:hidden;pointer-events:auto;contain:layout paint;will-change:transform;transform:translateZ(0);animation:menuIn .4s cubic-bezier(.4,0,.2,1) both}
#mainMenu.subLeaderboard #mmLeaderboard{display:flex}
#mainMenu.subLeaderboard #mmLobby,#mainMenu.subLeaderboard #mmMode,#mainMenu.subLeaderboard #mmChat{display:none}
.lbdHead{flex:0 0 84px;display:flex;flex-direction:column;align-items:center;justify-content:center;background:rgba(39,148,194,1);box-shadow:inset 0 1px 0 rgba(255,255,255,.18),inset 0 -1px 0 rgba(0,0,0,.25)}
.lbdTitle{font-family:'MEBig','EinaSemiBold',sans-serif;font-weight:400;font-size:40px;letter-spacing:2.5px;color:#eaf7ff;line-height:1;text-shadow:0 2px 8px rgba(0,0,0,.35)}
.lbdSub{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:13px;letter-spacing:5px;color:rgba(235,247,255,.72);text-transform:uppercase;margin-top:5px}
.lbdCols{flex:0 0 36px;display:flex;align-items:center;padding:0 24px;background:rgba(26,26,28,.95);border-bottom:1px solid rgba(255,255,255,.06)}
.lbdCols .lbdHC{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:13px;letter-spacing:1.5px;color:#7d828a;text-transform:uppercase;text-shadow:none}
.lbdBody{flex:1;overflow-y:auto;overflow-x:hidden;contain:layout paint;will-change:transform;transform:translateZ(0)}
.lbdBody::-webkit-scrollbar{width:6px}
.lbdBody::-webkit-scrollbar-track{background:rgba(255,255,255,.04)}
.lbdBody::-webkit-scrollbar-thumb{background:rgba(255,255,255,.18);border-radius:0}
.lbdBody::-webkit-scrollbar-thumb:hover{background:rgba(255,255,255,.3)}
.lbdRow{display:flex;align-items:center;height:54px;padding:0 24px;border-bottom:1px solid rgba(255,255,255,.045)}
.lbdRow:nth-child(even){background:rgba(255,255,255,.022)}
.lbdC-rank{flex:0 0 58px;text-align:center;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:23px;color:#fff}
.lbdC-rating{flex:0 0 170px;display:flex;align-items:center;justify-content:center;gap:13px}
.lbdBadge{width:40px;height:40px;object-fit:contain}
.lbdScore{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:22px;letter-spacing:.5px;color:#fff}
.lbdC-player{flex:1;display:flex;align-items:center;justify-content:center;gap:14px;min-width:0}
.lbdAvatar{width:42px;height:42px;border-radius:5px;background:#22242b center/cover no-repeat;border:1px solid rgba(255,255,255,.08);flex:none}
.lbdName{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:20px;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.lbdC-wl{flex:0 0 120px;text-align:left;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:20px;color:#e8eaed}
.lbdC-wins{flex:0 0 88px;text-align:center;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:20px;color:#e8eaed}
.lbdRow:nth-child(1) .lbdC-rank{color:#ffd34d}
.lbdRow:nth-child(2) .lbdC-rank{color:#cfd6e0}
.lbdRow:nth-child(3) .lbdC-rank{color:#e0915a}
.lbdEmpty{text-align:center;color:#9098a2;font-family:'BarlowLight','Segoe UI',sans-serif;font-size:18px;line-height:1.65;letter-spacing:.4px;max-width:620px;margin:0 auto;padding:90px 30px}

#mmCustom{position:fixed;left:0;right:0;top:110px;bottom:0;width:min(1040px,84vw);height:min(600px,84vh);margin:auto;z-index:2335;display:none;flex-direction:column;gap:14px;pointer-events:auto;animation:menuIn .4s cubic-bezier(.4,0,.2,1) both}
#mainMenu.subCustom #mmCustom{display:flex}
#mainMenu.subCustom #mmLobby,#mainMenu.subCustom #mmMode,#mainMenu.subCustom #mmChat{display:none}
.cmCard{flex:1;display:flex;flex-direction:column;align-items:center;background:rgba(13,13,15,.9);border:1px solid rgba(39,39,39,1);box-shadow:0 18px 60px rgba(0,0,0,.5);padding:28px 40px 22px;contain:layout paint;will-change:transform;transform:translateZ(0)}
.cmHead{text-align:center}
.cmTitle{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:34px;letter-spacing:1px;color:#fff;text-transform:uppercase;text-shadow:0 2px 6px rgba(0,0,0,.5)}
.cmSub{font-family:'BarlowLight','Segoe UI',sans-serif;font-size:15px;line-height:1.5;letter-spacing:.4px;color:#9098a2;max-width:560px;margin:9px auto 0}
.cmPick{display:flex;gap:54px;width:100%;justify-content:center;margin-top:22px;flex:1;min-height:0}
.cmCol{flex:1;max-width:430px;display:flex;flex-direction:column;align-items:center;min-height:0}
.cmColTitle{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:21px;letter-spacing:2px;color:#fff;text-transform:uppercase;margin-bottom:14px;text-shadow:0 1px 4px rgba(0,0,0,.6)}
.cmList{width:100%;display:flex;flex-direction:column;overflow:hidden}
.cmItem{position:relative;height:46px;display:flex;align-items:center;justify-content:center;cursor:pointer;background-size:cover;background-position:center center;overflow:hidden;filter:grayscale(1);transition:filter .18s}
.cmItem::before{content:'';position:absolute;inset:0;background:rgba(7,8,10,.72);transition:background .18s}
.cmItem span{position:relative;z-index:1;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:19px;letter-spacing:.5px;color:rgba(150,156,164,1);text-shadow:0 1px 5px rgba(0,0,0,.85);transition:color .18s}
.cmItem:hover{filter:grayscale(.5)}
.cmItem:hover::before{background:rgba(7,8,10,.56)}
.cmItem.active{filter:none}
.cmItem.active::before{background:rgba(6,8,12,.24)}
.cmItem.active span{color:#fff}
.cmCreateWrap{display:flex;flex-direction:column;align-items:center;margin-top:20px}
.cmCreate{width:208px;height:56px;display:flex;align-items:center;justify-content:center;background:rgba(222,43,97,1);cursor:pointer;transition:filter .15s,transform .12s}
.cmCreate span{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:26px;letter-spacing:2px;color:#fff}
.cmCreate:hover{filter:brightness(1.1);transform:translateY(-1px)}
.cmCreate:active{transform:translateY(0)}
.cmCreateNote{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:13px;letter-spacing:1.5px;color:#7d828a;text-transform:uppercase;margin-top:13px}
.cmJoinBar{position:relative;display:flex;align-items:center;gap:14px;flex:0 0 64px;align-self:center;width:min(900px,100%);padding:0 18px;background:rgba(13,13,15,.92);border:1px solid rgba(39,39,39,1);box-shadow:0 12px 40px rgba(0,0,0,.45)}
.cmJoinLabel{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:20px;letter-spacing:1px;color:#fff;text-transform:uppercase;margin-right:4px}
.cmJoinInput{flex:1;height:40px;background:rgba(8,8,8,.85);border:1px solid rgba(39,39,39,1);padding:0 14px;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-size:18px;letter-spacing:3px;color:#fff;text-transform:uppercase;outline:none;transition:border-color .15s}
.cmJoinInput::placeholder{color:#585d65;letter-spacing:2px}
.cmJoinInput:focus{border-color:rgba(120,120,120,1)}
.cmJoinInput.bad{border-color:#ff5555;animation:invShake .42s cubic-bezier(.36,.07,.19,.97)}
.cmJoinInput.ok{border-color:#46d33b}
.cmJoinBtn{min-width:104px;height:40px;display:flex;align-items:center;justify-content:center;background:rgba(46,201,59,1);cursor:pointer;transition:filter .15s}
.cmJoinBtn span{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-size:18px;letter-spacing:1px;color:#fff}
.cmJoinBtn:hover{filter:brightness(1.08)}
.cmJoinEye{width:46px;height:40px;display:flex;align-items:center;justify-content:center;background:none;cursor:pointer;opacity:.82;transition:opacity .15s}
.cmJoinEye:hover{opacity:1}
.cmJoinEye img{width:34px;height:34px;object-fit:contain}
.cmJoinEye.off img{opacity:.45}
.cmToast{position:absolute;left:0;right:0;bottom:-23px;text-align:center;font-family:'HanleyPro','Segoe UI',sans-serif;font-size:12.5px;color:#ff8585}

#mmServers{position:fixed;left:0;right:0;top:122px;bottom:0;width:min(1080px,84vw);height:min(640px,82vh);margin:auto;z-index:2335;display:none;flex-direction:column;background:rgba(13,13,15,.97);border:1px solid rgba(39,39,39,1);box-shadow:0 18px 60px rgba(0,0,0,.55);overflow:hidden;pointer-events:auto;contain:layout paint;will-change:transform;transform:translateZ(0);animation:menuIn .4s cubic-bezier(.4,0,.2,1) both}
#mainMenu.subServers #mmServers{display:flex}
#mainMenu.subServers #mmLobby,#mainMenu.subServers #mmMode,#mainMenu.subServers #mmChat{display:none}
.svCols{flex:0 0 38px;display:flex;align-items:center;padding:0 30px;background:rgba(26,26,28,.95);border-bottom:1px solid rgba(255,255,255,.06)}
.svCols .svHC{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:13px;letter-spacing:1.5px;color:#7d828a;text-transform:uppercase}
.svBody{flex:1;overflow-y:auto;overflow-x:hidden;contain:layout paint;will-change:transform;transform:translateZ(0)}
.svBody::-webkit-scrollbar{width:6px}
.svBody::-webkit-scrollbar-track{background:rgba(255,255,255,.04)}
.svBody::-webkit-scrollbar-thumb{background:rgba(255,255,255,.18);border-radius:0}
.svBody::-webkit-scrollbar-thumb:hover{background:rgba(255,255,255,.3)}
.svRow{display:flex;align-items:center;height:48px;padding:0 30px;border-bottom:1px solid rgba(255,255,255,.05)}
.svRow:nth-child(even){background:rgba(255,255,255,.022)}
.svC-time{flex:0 0 132px;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:18px;letter-spacing:.5px;color:#e8eaed}
.svC-time.svStarting{color:#ffb02e}
.svC-map{flex:0 0 204px;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:18px;color:#fff}
.svC-mode{flex:0 0 178px;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:18px;color:#fff}
.svC-players{flex:1;display:flex;align-items:center;gap:7px;min-width:0;overflow:hidden}
.svAv{width:30px;height:30px;border-radius:50%;background:#22242b center/cover no-repeat;border:1px solid rgba(255,255,255,.12);flex:none}
.svC-act{flex:0 0 64px;display:flex;align-items:center;justify-content:flex-end}
.svSpec{width:48px;height:38px;display:flex;align-items:center;justify-content:center;background:rgba(40,40,44,1);cursor:pointer;transition:background .15s}
.svSpec:hover{background:rgba(55,55,60,1)}
.svSpec img{width:32px;height:32px;object-fit:contain}
.svEmpty{text-align:center;color:#9098a2;font-family:'BarlowLight','Segoe UI',sans-serif;font-size:18px;line-height:1.65;letter-spacing:.4px;max-width:620px;margin:0 auto;padding:90px 30px}

#mmShop{position:fixed;left:0;right:0;top:78px;bottom:0;z-index:2336;display:none;flex-direction:column;align-items:center;pointer-events:none;animation:menuIn .4s cubic-bezier(.4,0,.2,1) both}
#mainMenu.navShop #mmShop{display:flex}
#mainMenu.navShop #mmSubnav,#mainMenu.navShop #mmLobby,#mainMenu.navShop #mmMode,#mainMenu.navShop #mmChat,#mainMenu.navShop #mmFinding,#mainMenu.navShop #mmMatches,#mainMenu.navShop #mmRanks,#mainMenu.navShop #mmLeaderboard,#mainMenu.navShop #mmCustom,#mainMenu.navShop #mmServers{display:none}
#mmInventory{position:fixed;top:0;left:0;right:0;bottom:0;width:100%;height:100%;z-index:2336;display:none;flex-direction:column;align-items:center;justify-content:center;background:rgba(21,21,21,1);pointer-events:auto;animation:menuIn .4s cubic-bezier(.4,0,.2,1) both}
#mainMenu.navInv #mmInventory{display:flex}
#mainMenu.navInv #mmSubnav,#mainMenu.navInv #mmLobby,#mainMenu.navInv #mmMode,#mainMenu.navInv #mmChat,#mainMenu.navInv #mmFinding,#mainMenu.navInv #mmMatches,#mainMenu.navInv #mmRanks,#mainMenu.navInv #mmLeaderboard,#mainMenu.navInv #mmCustom,#mainMenu.navInv #mmServers,#mainMenu.navInv #mmShop{display:none}
.invBox{width:min(1010px,84vw);max-height:calc(100% - 132px);margin-top:30px;display:flex;flex-direction:column;background:rgba(27,27,29,1);border:1px solid rgba(50,50,52,1);box-shadow:0 18px 60px rgba(0,0,0,.5);overflow:hidden;contain:layout paint;will-change:transform;transform:translateZ(0)}
.invBar{flex:0 0 44px;display:flex;align-items:center;justify-content:center;background:rgba(48,48,50,1);border-bottom:1px solid rgba(62,62,64,1);font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:18px;letter-spacing:2px;color:#fff}
.invBody{flex:1 1 auto;min-height:0;overflow-y:auto;overflow-x:hidden;padding:22px;display:flex;flex-wrap:wrap;gap:14px;align-content:flex-start}
.invBody::-webkit-scrollbar{width:6px}
.invBody::-webkit-scrollbar-track{background:rgba(255,255,255,.04)}
.invBody::-webkit-scrollbar-thumb{background:rgba(255,255,255,.18);border-radius:0}
.invCard{position:relative;width:calc((100% - 84px) / 7);height:116px;background:rgba(40,40,42,1);border:1px solid rgba(58,58,60,1);cursor:pointer;transition:border-color .15s}
.invCard:hover{border-color:rgba(110,110,114,1)}
.invCard::before{content:'';position:absolute;top:0;left:50%;transform:translateX(-50%);border-left:9px solid transparent;border-right:9px solid transparent;border-top:11px solid rgba(72,72,74,1);z-index:1}
.invThumb{position:absolute;top:0;left:0;width:100%;height:100%;object-fit:contain;padding:8px;background-color:#262628}
.invCheck{position:absolute;top:5px;left:5px;width:22px;height:22px;object-fit:contain;z-index:2;opacity:0;transition:opacity .12s}
.invCard.equipped .invCheck{opacity:1}
.shopTabs{position:relative;z-index:1;display:flex;align-items:flex-start;justify-content:center;gap:48px;height:62px;padding-top:6px;pointer-events:auto}
.shopTab{position:relative;display:flex;flex-direction:column;align-items:center;gap:5px;cursor:pointer}
.shopTab span{font-family:'HanleyPro','Segoe UI',sans-serif;font-weight:300;font-size:24px;letter-spacing:1.8px;color:rgba(112,113,113,1);transition:color .15s}
.shopTab:hover span{color:rgba(205,205,205,1)}
.shopTab.active span{color:#fff}
.shopTag{padding:2px 10px;border-radius:10px;background:rgba(233,60,74,1);font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:11px;letter-spacing:.5px;color:#fff;text-transform:uppercase;box-shadow:0 2px 6px rgba(0,0,0,.4)}
.shopBox{flex:0 1 auto;max-height:calc(100% - 80px);width:min(1040px,86vw);margin:auto 0;background:rgba(21,21,21,1);border:1px solid rgba(39,39,39,1);box-shadow:0 18px 60px rgba(0,0,0,.5);overflow:hidden;display:flex;flex-direction:column;pointer-events:auto;contain:layout paint;will-change:transform;transform:translateZ(0)}
.shopBox.shopBare{background:none;border:none;box-shadow:none}
.shopBody{flex:1 1 auto;min-height:0;overflow-y:auto;overflow-x:hidden;contain:layout paint;will-change:transform;transform:translateZ(0)}
.shopBody::-webkit-scrollbar{width:6px}
.shopBody::-webkit-scrollbar-track{background:rgba(255,255,255,.04)}
.shopBody::-webkit-scrollbar-thumb{background:rgba(255,255,255,.18);border-radius:0}
.shopBody::-webkit-scrollbar-thumb:hover{background:rgba(255,255,255,.3)}
.shopPane{display:none}
.shopPane.shopActive{display:block;padding-bottom:18px}
.shopColl{margin-top:14px}
.shopCollBar{height:40px;display:flex;align-items:center;justify-content:center;background:rgba(43,43,43,1);font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:18px;letter-spacing:2px;color:#fff;text-transform:uppercase}
/* justify-content + max-width: a row holding fewer than four skins keeps card-sized cards instead of
   stretching the leftovers across the whole panel, which is what made a single skin fill a banner */
.shopGrid{display:flex;justify-content:center;gap:14px;padding:16px 20px 4px}
.shopCard{position:relative;flex:1 1 0;min-width:0;max-width:196px;display:flex;flex-direction:column;cursor:pointer}
.shopGem{position:absolute;top:-9px;left:50%;width:24px;height:24px;transform:translateX(-50%);z-index:3;object-fit:contain;filter:drop-shadow(0 2px 5px rgba(0,0,0,.55))}
.shopThumb{position:relative;height:126px;background:rgba(38,38,40,1);border:1px solid rgba(60,60,62,1);overflow:hidden}
.shopFoot{position:absolute;left:0;right:0;bottom:0;padding:7px 5px 7px;background:linear-gradient(to top,rgba(0,0,0,.88),rgba(0,0,0,.25) 72%,transparent);display:flex;flex-direction:column;align-items:center;gap:2px}
.shopName{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:400;font-size:12px;letter-spacing:.5px;color:#fff;text-transform:uppercase}
.shopPrice{display:flex;align-items:center;gap:4px;font-family:'Rajdhani','Segoe UI',sans-serif;font-weight:700;font-size:15px;letter-spacing:.4px;color:rgba(239,113,237,1)}
.shopPrice img{width:16px;height:16px;object-fit:contain}
.shopEmpty{text-align:center;color:#9098a2;font-family:'BarlowLight','Segoe UI',sans-serif;font-size:18px;letter-spacing:.4px;padding:100px 30px}
/* the shop dims nothing: no blur, no dark overlay, on any tab */
.shopVeil{display:none}
#gemsVeil{display:none}
.shopBox{position:relative;z-index:1}
.gemGrid{display:flex;gap:16px;padding:26px}
.gemPack{position:relative;flex:1;min-width:0;height:332px;background:rgba(139,42,124,1);border:3px solid rgba(195,57,181,1);overflow:hidden;cursor:pointer;transform:translateZ(0);isolation:isolate}
.gemPack::after{content:'';position:absolute;top:0;bottom:0;left:-60%;width:50%;background:linear-gradient(105deg,transparent,rgba(255,255,255,.4),transparent);transform:translate3d(0,0,0) skewX(-14deg);opacity:0;z-index:3;pointer-events:none;will-change:transform;backface-visibility:hidden}
.gemPack:hover::after{animation:gemSheen 1.2s cubic-bezier(.25,.6,.3,1)}
@keyframes gemSheen{0%{transform:translate3d(0,0,0) skewX(-14deg);opacity:1}100%{transform:translate3d(520%,0,0) skewX(-14deg);opacity:1}}
.gemArt{position:absolute;left:0;right:0;top:0;bottom:66px;display:flex;align-items:center;justify-content:center;background:linear-gradient(158deg,rgba(201,84,183,1) 0%,rgba(150,49,135,1) 48%,rgba(108,31,96,1) 100%)}
.gemIcon{max-width:74%;max-height:76%;object-fit:contain;filter:drop-shadow(0 7px 18px rgba(0,0,0,.42))}
.gemFoot{position:absolute;left:0;right:0;bottom:0;height:66px;padding:0 18px;display:flex;flex-direction:column;justify-content:center;gap:0;background:rgba(0,0,0,.2)}
.gemAmount{font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:23px;letter-spacing:.5px;color:rgba(238,150,226,1)}
.gemPrice{font-family:'BarlowLight','Segoe UI',sans-serif;font-weight:300;font-size:17px;letter-spacing:1px;color:#fff;margin-top:-3px}
.gemRibbon{position:absolute;top:15px;right:-4px;background:rgba(222,43,97,1);color:#fff;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:13px;letter-spacing:.5px;padding:5px 13px;transform:rotate(-6deg);box-shadow:0 3px 8px rgba(0,0,0,.4);z-index:2}
.gemDisclaimer{margin:20px auto 8px;max-width:780px;padding:14px 24px;background:rgba(222,43,97,1);border:2px solid rgba(150,26,62,1);border-radius:6px;box-shadow:0 6px 22px rgba(0,0,0,.45);text-align:center;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:16px;letter-spacing:.3px;line-height:1.4;color:#fff}

#mmRail{position:fixed;right:64px;top:48%;transform:translateY(-50%);z-index:2330;display:flex;flex-direction:column;gap:26px;align-items:center;pointer-events:auto;animation:menuIn .45s cubic-bezier(.4,0,.2,1) .18s both}
.railItem{display:flex;flex-direction:column;align-items:center;gap:5px;cursor:pointer;transition:transform .15s}
.railItem:hover{transform:scale(1.06)}
.railIco{width:48px;height:48px;display:flex;align-items:center;justify-content:center;filter:drop-shadow(0 3px 6px rgba(0,0,0,.6))}
.railIco svg{width:42px;height:42px}
.railLbl{font-weight:700;font-size:11px;letter-spacing:1px;color:#dfe2e6;text-transform:uppercase;text-shadow:0 1px 4px rgba(0,0,0,.85)}

#mmEdge{position:fixed;right:8px;top:92px;z-index:2350;display:flex;flex-direction:column;align-items:center;gap:14px;pointer-events:auto}
.edgeIco{width:34px;height:34px;display:flex;align-items:center;justify-content:center;color:#aeb2b9;cursor:pointer;border-radius:8px;transition:color .15s,background .15s}
.edgeIco svg{width:24px;height:24px}
.edgeIco:hover{color:#fff;background:rgba(255,255,255,.08)}
#mmMail{position:fixed;right:8px;top:57%;z-index:2350;pointer-events:auto}
#mmMic{position:fixed;right:8px;bottom:16px;z-index:2350;pointer-events:auto}
]]
end
