
local M = MEMenu

function M._BuildMarkup(params)
    return [[
<div class="veil" id="veil"></div>
<div id="rating"><img id="ratingImg" alt=""></div>

<div id="titleScreen">
  <div id="titleBarTop"></div>
  <div id="titleBarBot"></div>
  <div id="titleTextWrap">
    <div id="titleTextBlock">
      <div id="titleLogoLine">
        <div id="titleLogoTop">
          <svg id="titleMESvg" viewBox="0 0 545 90" preserveAspectRatio="none">
            <defs>
              <mask id="MEMask">
                <rect x="0" y="0" width="545" height="90" fill="white"/>
                <text x="272" y="64" text-anchor="middle" fill="black"
                      font-family="Montserrat, 'Segoe UI', sans-serif"
                      font-size="60" font-weight="900" letter-spacing="6">MERGE</text>
              </mask>
            </defs>
            <rect x="0" y="0" width="545" height="90" fill="white" mask="url(#MEMask)"/>
          </svg>
        </div>
        <div id="titleLogoSub">EMPIRES KINGDOMS</div>
      </div>
      <div id="titlePressLine">PRESS [SPACE] TO START</div>
    </div>
  </div>
  <div id="titleCopyright">]] .. params.titleCopyHTML .. [[</div>
</div>

<div id="loadingScreen">
  <div id="loadCorner">
    <svg id="loadSpinner" viewBox="0 0 32 32">
      <circle cx="16" cy="16" r="14"/>
    </svg>
    <div id="loadStatus"></div>
  </div>
</div>

<div id="matchLoad">
  <div class="mlBanner" id="mlBanner"></div>
  <div class="mlScrim"></div>
  <div class="mlInfo">
    <div class="mlTitle" id="mlTitle">BREAKTIDE</div>
    <div class="mlMode" id="mlMode">CASUAL</div>
  </div>
  <div class="mlSpinner">
    <svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="14"/></svg>
  </div>
  <div class="mlFade" id="mlFade"></div>
</div>

<div id="mainMenu">
  <div id="mmOverlay"></div>
  <div id="mmHex"><div id="mmHexInner"></div></div>

  <div id="mmTopbar">
    <div class="tbCenter">
      <div class="tbHome" data-nav="home">
        <img src="asset://garrysmod/materials/mergeempires/menu/me_house.png" alt="">
      </div>
      <div class="tbNav" data-nav="shop"><span>SHOP</span></div>
      <div class="tbNav active" data-nav="play"><span>PLAY</span></div>
      <div class="tbNav" data-nav="inventory"><span>INVENTORY</span></div>
    </div>

    <div class="tbRight">
      <div class="curBox" data-act="frag">
        <span class="curIco"><img src="asset://garrysmod/materials/mergeempires/menu/me_fragment.png" alt=""></span>
        <span class="curVal fragVal" id="curFrag">0</span>
      </div>
      <div class="curBox" data-act="gem">
        <span class="curIco"><img src="asset://garrysmod/materials/mergeempires/menu/me_gem.png" alt=""></span>
        <span class="curVal gemVal" id="curGem">0</span>
        <span class="curPlus" data-act="gemplus"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" stroke="#fff" stroke-width="3.4" stroke-linecap="round"/></svg></span>
      </div>
    </div>
  </div>

  <div id="mmSubnav">
    <div class="snTabs">
      <div class="snTab active" data-sub="lobby">LOBBY</div>
      <div class="snTab" data-sub="ranks">RANKS</div>
      <div class="snTab" data-sub="leaderboard">LEADERBOARD</div>
      <div class="snTab" data-sub="custom">CUSTOM</div>
      <div class="snTab" data-sub="servers">SERVERS</div>
    </div>
  </div>

  <div id="mmReconnect">
    <div class="rcTitle">DISCONNECTED FROM A MATCH</div>
    <div class="rcBtn" id="rcRejoin"><span>REJOIN</span></div>
  </div>

  <div id="mmLobby">
    <div class="lbMembers" id="lbMembers">
      <div class="lobbyBanner self" data-act="profile">
        <div class="lbAvatar" id="lbAvatar"></div>
        <div class="lbName" id="lbName">PLAYER</div>
        <div class="lbCrown" id="lbCrown">
          <img src="asset://garrysmod/materials/mergeempires/menu/me_crown.png" alt="">
        </div>
      </div>
    </div>
  </div>

  <div id="mmRanks">
    <div class="rkTitleBar">RANKS</div>
    <div class="rkGrid">
      <div class="rkCol">
        <div class="rkHead"><div class="rkTitle">BRONZE</div></div>
        <div class="rkStack">
          <img class="rkBadge" src="asset://garrysmod/materials/mergeempires/rank/badge_02.png" alt="">
          <img class="rkArrow" src="asset://garrysmod/materials/mergeempires/menu/me_arrow_up.png" alt="">
          <img class="rkBadge" src="asset://garrysmod/materials/mergeempires/rank/badge_01.png" alt="">
          <img class="rkArrow" src="asset://garrysmod/materials/mergeempires/menu/me_arrow_up.png" alt="">
          <img class="rkBadge" src="asset://garrysmod/materials/mergeempires/rank/badge_00.png" alt="">
        </div>
      </div>
      <div class="rkCol">
        <div class="rkHead"><div class="rkTitle">SILVER</div></div>
        <div class="rkStack">
          <img class="rkBadge" src="asset://garrysmod/materials/mergeempires/rank/badge_05.png" alt="">
          <img class="rkArrow" src="asset://garrysmod/materials/mergeempires/menu/me_arrow_up.png" alt="">
          <img class="rkBadge" src="asset://garrysmod/materials/mergeempires/rank/badge_04.png" alt="">
          <img class="rkArrow" src="asset://garrysmod/materials/mergeempires/menu/me_arrow_up.png" alt="">
          <img class="rkBadge" src="asset://garrysmod/materials/mergeempires/rank/badge_03.png" alt="">
        </div>
      </div>
      <div class="rkCol">
        <div class="rkHead"><div class="rkTitle">GOLD</div></div>
        <div class="rkStack">
          <img class="rkBadge" src="asset://garrysmod/materials/mergeempires/rank/badge_08.png" alt="">
          <img class="rkArrow" src="asset://garrysmod/materials/mergeempires/menu/me_arrow_up.png" alt="">
          <img class="rkBadge" src="asset://garrysmod/materials/mergeempires/rank/badge_07.png" alt="">
          <img class="rkArrow" src="asset://garrysmod/materials/mergeempires/menu/me_arrow_up.png" alt="">
          <img class="rkBadge" src="asset://garrysmod/materials/mergeempires/rank/badge_06.png" alt="">
        </div>
      </div>
      <div class="rkCol">
        <div class="rkHead"><div class="rkTitle">MASTER</div></div>
        <div class="rkStack rkSingle">
          <img class="rkBadge" src="asset://garrysmod/materials/mergeempires/rank/badge_09.png" alt="">
        </div>
      </div>
      <div class="rkCol">
        <div class="rkHead"><div class="rkTitle">EMPIRATOR</div></div>
        <div class="rkStack rkSingle">
          <img class="rkBadge" src="asset://garrysmod/materials/mergeempires/rank/badge_10.png" alt="">
        </div>
      </div>
    </div>
  </div>

  <div id="mmLeaderboard">
    <div class="lbdHead">
      <div class="lbdTitle">MERGE EMPIRES</div>
      <div class="lbdSub">LEADERBOARD</div>
    </div>
    <div class="lbdCols">
      <div class="lbdHC lbdC-rank">RANK</div>
      <div class="lbdHC lbdC-rating">RATING</div>
      <div class="lbdHC lbdC-player"></div>
      <div class="lbdHC lbdC-wl">W/L</div>
      <div class="lbdHC lbdC-wins">WINS</div>
    </div>
    <div class="lbdBody" id="lbdBody"></div>
  </div>

  <div id="mmCustom">
    <div class="cmCard">
      <div class="cmHead">
        <div class="cmTitle">CREATE A CUSTOM MATCH</div>
        <div class="cmSub">Create a match on your favorite map and decide who can join with a unique match code!</div>
      </div>
      <div class="cmPick">
        <div class="cmCol">
          <div class="cmColTitle">SELECT A MODE</div>
          <div class="cmList" id="cmModeList">
            <div class="cmItem active" data-mode="casual" style="background-image:url(']] .. params.bn.casual .. [[')"><span>Casual</span></div>
            <div class="cmItem" data-mode="blitz" style="background-image:url(']] .. params.bn.blitz .. [[')"><span>Blitz</span></div>
            <div class="cmItem cmLocked" data-mode="ambush" data-enabled="0" style="background-image:url(']] .. params.bn.ambush .. [[')"><span>Ambush</span></div>
            <div class="cmItem cmLocked" data-mode="duel" data-enabled="0" style="background-image:url(']] .. params.bn.duel .. [[')"><span>Duel 1v1</span></div>
          </div>
        </div>
        <div class="cmCol">
          <div class="cmColTitle">SELECT A MAP</div>
          <div class="cmList" id="cmMapList">
            <div class="cmItem active" data-map="desert" style="background-image:url(']] .. params.bn.map_desert .. [[')"><span>Breaktide</span></div>
          </div>
        </div>
      </div>
      <div class="cmCreateWrap">
        <div class="cmCreate" id="cmCreate"><span>CREATE</span></div>
        <div class="cmCreateNote">STATS AND MISSIONS ARE UNAFFECTED</div>
      </div>
    </div>
    <div class="cmJoinBar">
      <div class="cmJoinLabel">JOIN A CUSTOM MATCH</div>
      <input class="cmJoinInput" id="cmJoinInput" placeholder="MATCH CODE" maxlength="5" spellcheck="false">
      <div class="cmJoinBtn" id="cmJoinBtn"><span>JOIN</span></div>
      <div class="cmJoinEye" id="cmJoinEye"><img src="asset://garrysmod/materials/mergeempires/menu/me_eye.png" alt=""></div>
      <div class="cmToast" id="cmToast"></div>
    </div>
  </div>

  <div id="mmServers">
    <div class="svCols">
      <div class="svHC svC-time">TIME</div>
      <div class="svHC svC-map">MAP</div>
      <div class="svHC svC-mode">MODE</div>
      <div class="svHC svC-players">PLAYERS</div>
      <div class="svHC svC-act"></div>
    </div>
    <div class="svBody" id="svBody"></div>
  </div>

  <div id="mmShop">
    <div class="shopVeil"></div>
    <div class="shopTabs">
      <div class="shopTab active" data-shop="skins"><span>SKINS</span><div class="shopTag tagNew">NEW</div></div>
      <div class="shopTab" data-shop="gems"><span>GEMS</span><div class="shopTag tagValue">2x VALUE</div></div>
    </div>
    <div class="shopBox">
      <div class="shopBody" id="shopBody">
        <div class="shopPane shopActive" id="shopSkins"></div>
        <div class="shopPane" id="shopGems"></div>
      </div>
    </div>
  </div>

  <div id="mmInventory">
    <div class="invBox">
      <div class="invBar">SKINS</div>
      <div class="invBody" id="invBody"></div>
    </div>
  </div>

  <div id="mmMode">
    <div class="mpSelected">
      <div class="mpSelLabel">SELECTED MODE</div>
      <div class="mpSelValue" id="mpMode">CASUAL</div>
    </div>
    <div class="mpButtons">
      <div class="mpBtn mpChange" data-act="change"><span>CHANGE</span></div>
      <div class="mpBtn mpQueue"  data-act="queue"><div class="qAur"></div><span>QUEUE</span></div>
      <div class="mpBtn mpLeave disabled" data-act="leave"><span>LEAVE</span></div>
    </div>
  </div>

  <div id="mmModeSelect">
    <div class="msBar">SELECT A MODE</div>
    <div class="msGrid">

      <div class="msCell">
        <div class="msBanner" data-mode="casual" data-label="CASUAL" style="background-image:url(']] .. params.bn.casual .. [[')">
          <div class="msWins"><img src="asset://garrysmod/materials/mergeempires/menu/me_trophee.png" alt=""><span>0</span></div>
          <div class="msShade"></div>
          <div class="msInfo">
            <div class="msName">CASUAL</div>
            <div class="msDesc">Ally with another player or fight alone. The last alliance standing wins.</div>
            <div class="msQueue"><span>0</span> PLAYERS IN QUEUE</div>
          </div>
        </div>
      </div>

      <div class="msCell">
        <div class="msBanner" data-mode="blitz" data-label="BLITZ" style="background-image:url(']] .. params.bn.blitz .. [[')">
          <div class="msWins"><img src="asset://garrysmod/materials/mergeempires/menu/me_trophee.png" alt=""><span>0</span></div>
          <div class="msShade"></div>
          <div class="msInfo">
            <div class="msName">BLITZ</div>
            <div class="msDesc">A fast-paced mode with 2x income, building, and unit production speed.</div>
            <div class="msQueue"><span>0</span> PLAYERS IN QUEUE</div>
          </div>
        </div>
        <div class="msNew">NEW</div>
      </div>

      <div class="msCol">
        <div class="msCellH">
          <div class="msBanner msHalf msLocked" data-mode="ambush" data-enabled="0" data-label="AMBUSH" style="background-image:url(']] .. params.bn.ambush .. [[')">
            <div class="msWins"><img src="asset://garrysmod/materials/mergeempires/menu/me_trophee.png" alt=""><span>0</span></div>
            <div class="msShade"></div>
            <div class="msInfo">
              <div class="msName">AMBUSH</div>
              <div class="msDesc">The battlefield has been covered in fog and you must stay alert.</div>
              <div class="msQueue"><span>0</span> PLAYERS IN QUEUE</div>
            </div>
          </div>
        </div>
        <div class="msCellH">
          <div class="msBanner msHalf msLocked" data-mode="duel" data-enabled="0" data-label="DUEL" style="background-image:url(']] .. params.bn.duel .. [[')">
            <div class="msWins"><img src="asset://garrysmod/materials/mergeempires/menu/me_trophee.png" alt=""><span>0</span></div>
            <div class="msShade"></div>
            <div class="msInfo">
              <div class="msName">DUEL <em>1v1</em></div>
              <div class="msDesc">Fight versus one other player with up to 120 units each.</div>
              <div class="msQueue"><span>0</span> PLAYERS IN QUEUE</div>
            </div>
          </div>
        </div>
      </div>

      <div class="msCell">
        <div class="msBanner msLocked" data-mode="ranked" data-enabled="0" data-label="RANKED" style="background-image:url(']] .. params.bn.ranked .. [[')">
          <div class="msWins"><img src="asset://garrysmod/materials/mergeempires/menu/me_trophee.png" alt=""><span>0</span></div>
          <div class="msShade"></div>
          <div class="msInfo">
            <div class="msName">RANKED <em>3v3</em></div>
            <div class="msDesc">Prove your skills in this competitive team mode and rise through the ranks.</div>
            <div class="msQueue"><span>0</span> PLAYERS IN QUEUE</div>
          </div>
        </div>
      </div>

    </div>
  </div>

  <div id="mmInvite">
    <div class="ivSelf">
      <div class="ivAvatar" id="ivAvatar"></div>
      <div class="ivSelfTxt">
        <div class="ivSelfName" id="ivSelfName">PLAYER</div>
        <div class="ivLobbyTag">In lobby</div>
      </div>
    </div>
    <div class="ivRank">
      <img class="ivRankIco" src="asset://garrysmod/materials/mergeempires/rank/badge_00.png" alt="">
      <span class="ivRankTxt">UNRANKED</span>
    </div>
    <div class="ivFriendsTitle">FRIENDS</div>
    <div class="ivFriends" id="ivFriends"></div>
    <div class="ivFooter">
      <div class="ivMini">LOBBY CODE</div>
      <div class="ivCodeRow">
        <div class="invCode" id="invCode">&#8226;&#8226;&#8226;&#8226;&#8226;</div>
        <div class="invEye off" id="invEye">
          <img src="asset://garrysmod/materials/mergeempires/menu/me_eye.png" alt="">
        </div>
      </div>
      <div class="ivMini ivJoinLbl">JOIN A FRIEND</div>
      <div class="ivJoinRow">
        <input class="invInput" id="invInput" placeholder="ENTER CODE" maxlength="5" spellcheck="false">
        <div class="invJoinBtn" id="invJoinBtn"><div class="ivJoinShine"></div><span>JOIN</span></div>
      </div>
      <div class="invToast" id="invToast"></div>
      <div class="ivBack" id="invClose">BACK TO MENU</div>
    </div>
  </div>

  <div id="mmChat">
    <div class="chatLog" id="chatLog"></div>
    <input class="chatInput" id="chatInput" placeholder="Press ENTER to type..." maxlength="50" spellcheck="false">
  </div>

  <div id="mmFinding">
    <div class="fdShine"></div>
    <i class="fcTRh"></i><i class="fcTRv"></i><i class="fcBLh"></i><i class="fcBLv"></i>
    <div class="fdTitle">FINDING A MATCH</div>
    <div class="fdTimer" id="fdTimer">0:00</div>
    <div class="fdSub"><span id="fdCount">0</span> PLAYERS IN QUEUE</div>
  </div>

  <div id="mmMatches">
    <span class="amCount" id="amCount">0</span>
    <span class="amLabel">ACTIVE MATCHES</span>
    <img class="amIco" src="asset://garrysmod/materials/mergeempires/menu/me_world.png" alt="">
  </div>

  <div id="mmNotif">
    <div class="ntShine"></div>
    <i class="ntcTRh"></i><i class="ntcTRv"></i><i class="ntcBLh"></i><i class="ntcBLv"></i>
    <div class="ntText" id="ntText"></div>
  </div>

  <div id="mmInviteReq">
    <div class="ntShine"></div>
    <i class="ntcTRh"></i><i class="ntcTRv"></i><i class="ntcBLh"></i><i class="ntcBLv"></i>
    <div class="ntText" id="irText"></div>
    <div class="irBtns">
      <div class="irBtn irYes" id="irYes"><span>YES</span></div>
      <div class="irBtn irNo" id="irNo"><span>NO</span></div>
    </div>
  </div>

  <div id="mmReward">
    <div class="rwContent">
      <div class="rwTitle">YOU RECEIVED</div>
      <div class="rwCard">
        <div class="rwSquare">
          <div class="rwSheen"></div>
          <img class="rwIcon" id="rwIcon" src="" alt="">
          <div class="rwCount" id="rwCount">x0</div>
        </div>
        <div class="rwName" id="rwName">GEMS</div>
        <div class="rwType" id="rwType">CURRENCY</div>
      </div>
      <div class="rwClose" id="rwClose"><span>CLOSE</span></div>
    </div>
  </div>

</div>
]]
end
