
local M = MEMenu

function M._BuildScripts(params)
    return [[
(function(){
var $=function(id){return document.getElementById(id)};
var rating=$('rating'),ratingImg=$('ratingImg'),veil=$('veil');
var loadingScreen=$('loadingScreen'),mainMenu=$('mainMenu');

var hoverSfx,refuseSfx,purchaseSfx;
try{hoverSfx=new Audio(']] .. params.hoverSnd .. [[');hoverSfx.volume=1.0}catch(e){}
try{refuseSfx=new Audio(']] .. params.refuseSnd .. [[');refuseSfx.volume=0.85}catch(e){}
try{purchaseSfx=new Audio(']] .. params.purchaseSnd .. [[');purchaseSfx.volume=0.9}catch(e){}
function playHover(){try{if(hoverSfx){hoverSfx.currentTime=0;var p=hoverSfx.play();if(p&&p.catch)p.catch(function(){})}}catch(e){}}
function playRefuse(){try{if(refuseSfx){refuseSfx.currentTime=0;var p=refuseSfx.play();if(p&&p.catch)p.catch(function(){})}}catch(e){}}
function playPurchase(){try{if(purchaseSfx){purchaseSfx.currentTime=0;var p=purchaseSfx.play();if(p&&p.catch)p.catch(function(){})}}catch(e){}}
function fmt(n){return Number(n||0).toLocaleString('en-US')}
function fire(name,a){try{if(window.CineEvent&&CineEvent[name])CineEvent[name](a)}catch(e){}}
function each(sel,fn){var l=document.querySelectorAll(sel);for(var i=0;i<l.length;i++)fn(l[i])}

var _decorBuilt=false;
function buildHexBg(){
  var host=$('mmHexInner');if(!host)return;
  var W=(window.innerWidth||1920)+360,H=(window.innerHeight||1080)+360;
  var s=54,hStep=1.5*s,vStep=1.7320508*s;
  var svg='<svg width="'+W+'" height="'+H+'" xmlns="http://www.w3.org/2000/svg" style="display:block">';
  var col=0;
  for(var cx=-s;cx<W+s;cx+=hStep){
    var offY=(col&1)?vStep/2:0;
    for(var cy=offY-vStep;cy<H+vStep;cy+=vStep){
      var p='';
      for(var k=0;k<6;k++){var ang=Math.PI/3*k;p+=(cx+s*Math.cos(ang)).toFixed(1)+','+(cy+s*Math.sin(ang)).toFixed(1)+' '}
      svg+='<polygon points="'+p+'" fill="none" stroke="#ffffff" stroke-width="1"/>';
    }
    col++;
  }
  svg+='</svg>';
  host.innerHTML=svg;
}
function buildQueueDecor(){var host=document.querySelector('.qAur');if(!host)return;host.innerHTML='<div class="qShine"></div>'}
function buildDecor(){if(_decorBuilt)return;_decorBuilt=true;try{buildHexBg()}catch(e){}try{buildQueueDecor()}catch(e){}}

var navItems=[].slice.call(document.querySelectorAll('.tbNav'));
var homeBtn=document.querySelector('.tbHome');
function setNav(el){for(var i=0;i<navItems.length;i++)navItems[i].classList.toggle('active',navItems[i]===el)}
for(var i=0;i<navItems.length;i++){(function(t){t.onmouseenter=function(){if(!t.classList.contains('active'))playHover()};t.onclick=function(){if(!t.classList.contains('active'))playHover();setNav(t);var nav=t.getAttribute('data-nav');var mm=$('mainMenu');if(mm){mm.classList.remove('navShop');mm.classList.remove('navInv');if(nav==='shop'){clearPanelSubs(mm);resetToLobbyTab();mm.classList.add('navShop');shopOpen()}else if(nav==='inventory'){clearPanelSubs(mm);resetToLobbyTab();mm.classList.add('navInv');invOpen()}}fire('Nav',nav)}})(navItems[i])}
if(homeBtn){homeBtn.onmouseenter=function(){playHover()};homeBtn.onclick=function(){playHover();var mm=$('mainMenu');if(mm){mm.classList.remove('navShop');mm.classList.remove('navInv')}var play=document.querySelector('.tbNav[data-nav="play"]');if(play)setNav(play);fire('Nav','home')}}

var subTabs=[].slice.call(document.querySelectorAll('.snTab'));
var PANEL_SUBS={ranks:'subRanks',leaderboard:'subLeaderboard',custom:'subCustom',servers:'subServers'};
var PANEL_IDS={ranks:'#mmRanks',leaderboard:'#mmLeaderboard',custom:'#mmCustom',servers:'#mmServers'};
function clearPanelSubs(mm){for(var k in PANEL_SUBS)mm.classList.remove(PANEL_SUBS[k])}
function resetToLobbyTab(){for(var k=0;k<subTabs.length;k++)subTabs[k].classList.toggle('active',subTabs[k].getAttribute('data-sub')==='lobby')}
for(var s=0;s<subTabs.length;s++){(function(t){t.onmouseenter=function(){if(!t.classList.contains('active'))playHover()};t.onclick=function(){for(var k=0;k<subTabs.length;k++)subTabs[k].classList.toggle('active',subTabs[k]===t);playHover();var sub=t.getAttribute('data-sub');var mm=$('mainMenu');if(mm){clearPanelSubs(mm);if(PANEL_SUBS[sub])mm.classList.add(PANEL_SUBS[sub])}fire('Sub',sub)}})(subTabs[s])}

var SKIP_ACT={change:1,queue:1,leave:1,addplayer:1,profile:1};
each('[data-act]',function(el){
  var act=el.getAttribute('data-act');
  if(SKIP_ACT[act])return;
  el.onmouseenter=function(){playHover()};
  el.onclick=function(e){if(e&&e.stopPropagation)e.stopPropagation();playHover();fire('MenuAction',act)};
});

var MODE_LABELS={casual:'CASUAL',blitz:'BLITZ',ambush:'AMBUSH',duel:'DUEL',ranked:'RANKED'};
var CROWN_URL='asset://garrysmod/materials/mergeempires/menu/me_crown.png';
var currentModeKey='casual',modeCounts={};
var mpMode=$('mpMode');
var changeBtn=document.querySelector('.mpChange');
var queueBtn=document.querySelector('.mpQueue');
var leaveBtn=document.querySelector('.mpLeave');
var qSpan=queueBtn?queueBtn.querySelector('span'):null;
var fdPanel=$('mmFinding'),fdTimerEl=$('fdTimer'),fdCountEl=$('fdCount');
var lobbyState=null,isLeader=true,localAvatarUrl='',queuing=false,findTimer=null,findElapsed=0;
function esc(s){return String(s||'').replace(/[&<>"']/g,function(c){return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c]})}
function fmtTime(s){var m=Math.floor(s/60),ss=s%60;return m+':'+(ss<10?'0':'')+ss}

function openModeSelect(){if(mainMenu){closeInvite();mainMenu.classList.add('modeSelecting')}}
function closeModeSelect(){if(mainMenu)mainMenu.classList.remove('modeSelecting')}
if(changeBtn){changeBtn.onmouseenter=function(){if(isLeader)playHover()};changeBtn.onclick=function(){if(!isLeader){playRefuse();return}playHover();openModeSelect()}}
each('.msBanner',function(b){
  var locked=b.getAttribute('data-enabled')==='0';
  b.onmouseenter=function(){if(!locked)playHover()};
  b.onclick=function(){
    if(locked){playRefuse();notify('This mode is coming soon.');return}
    playHover();
    var k=b.getAttribute('data-mode')||'casual';
    currentModeKey=k;
    if(mpMode)mpMode.textContent=MODE_LABELS[k]||k.toUpperCase();
    if(fdCountEl&&modeCounts[k]!=null)fdCountEl.textContent=fmt(modeCounts[k]);
    fire('SetMode',k);
    closeModeSelect();
  };
});

function enterSearchUI(){
  queuing=true;
  if(qSpan)qSpan.textContent='CANCEL';
  if(queueBtn)queueBtn.classList.add('cancelling');
  if(fdPanel)fdPanel.classList.add('show');
  if(!findTimer){
    findElapsed=0;if(fdTimerEl)fdTimerEl.textContent='0:00';
    findTimer=setInterval(function(){
      findElapsed++;if(fdTimerEl)fdTimerEl.textContent=fmtTime(findElapsed);
      if(findElapsed>=300&&isLeader)fire('PartyQueue',false);
    },1000);
  }
  if(fdCountEl&&modeCounts[currentModeKey]!=null)fdCountEl.textContent=fmt(modeCounts[currentModeKey]);
}
function exitSearchUI(){
  queuing=false;
  if(qSpan)qSpan.textContent='QUEUE';
  if(queueBtn)queueBtn.classList.remove('cancelling');
  if(fdPanel)fdPanel.classList.remove('show');
  if(findTimer){clearInterval(findTimer);findTimer=null}
}
if(queueBtn){
  queueBtn.onmouseenter=function(){if(isLeader)playHover()};
  queueBtn.onclick=function(){
    if(!isLeader){playRefuse();return}
    playHover();
    var next=!queuing;
    if(next)enterSearchUI();else exitSearchUI();
    fire('PartyQueue',next);
  };
}
if(leaveBtn){leaveBtn.onclick=function(){if(leaveBtn.classList.contains('disabled')){playRefuse();return}playHover();fire('PartyLeave')}}

var HAMMER_URL='asset://garrysmod/materials/mergeempires/menu/me_kick.png';
function mateHTML(m,you){
  var av=(m.steamid===you)?localAvatarUrl:'';
  var h='<div class="lobbyMate" data-sid="'+esc(m.sid64||'')+'">';
  h+='<div class="lbMateAv" data-photo="'+esc(m.sid64||'')+'"'+(av?(' style="background-image:url(\''+av+'\')"'):'')+'></div>';
  h+='<div class="lbMateName">'+esc(m.name).toUpperCase()+'</div>';
  h+='<div class="lbKick" data-kick="'+esc(m.sid64||'')+'" data-name="'+esc(m.name)+'"><span>KICK</span></div>';
  h+='</div>';
  return h;
}
function leaderHTML(m,you){
  var av=(m.steamid===you)?localAvatarUrl:'';
  var h='<div class="lobbyBanner self" data-sid="'+esc(m.sid64||'')+'">';
  h+='<div class="lbAvatar" data-photo="'+esc(m.sid64||'')+'"'+(av?(' style="background-image:url(\''+av+'\')"'):'')+'></div>';
  h+='<div class="lbName">'+esc(m.name).toUpperCase()+'</div>';
  h+='<div class="lbCrown"><img src="'+CROWN_URL+'" alt=""></div>';
  h+='</div>';
  return h;
}
var lastLobbySig='';
function renderLobby(){
  var st=lobbyState,host=$('lbMembers');
  if(!st||!host)return;
  var you=st.you,leader=st.leader;
  isLeader=(you===leader);
  var mm=$('mainMenu');if(mm)mm.classList.toggle('isLeader',isLeader);
  var sig=you+'|'+leader+'|'+localAvatarUrl+'|'+isLeader;
  for(var s=0;s<st.members.length;s++){sig+='|'+st.members[s].sid64+':'+st.members[s].name}
  if(sig!==lastLobbySig){
    lastLobbySig=sig;
    // leader stays centered; joiners split evenly to the left and right of them
    var lead=null,mates=[];
    for(var i=0;i<st.members.length;i++){if(st.members[i].steamid===leader&&!lead)lead=st.members[i];else mates.push(st.members[i])}
    if(!lead)lead=st.members[0]||{name:'PLAYER',sid64:'',steamid:you};
    var half=Math.ceil(mates.length/2),left=mates.slice(0,half),right=mates.slice(half);
    var lh='';for(var l=0;l<left.length;l++)lh+=mateHTML(left[l],you);
    var rh='';for(var r=0;r<right.length;r++)rh+=mateHTML(right[r],you);
    // the + is only offered while there is room (max 6) and only to the leader (CSS hides it otherwise)
    if(st.members.length<6)rh+='<div class="lbAdd" data-act="addplayer"><svg viewBox="0 0 24 24"><path d="M12 4v16M4 12h16" stroke="rgba(255,255,255,.82)" stroke-width="2.2" stroke-linecap="round"/></svg></div>';
    // left and right are equal-width flex sides, so the leader is centred regardless of the split
    var html='<div class="lbSide lbSideL">'+lh+'</div>'+leaderHTML(lead,you)+'<div class="lbSide lbSideR">'+rh+'</div>';
    host.innerHTML=html;
    bindLobbyControls(host);
  }
  if(leaveBtn)leaveBtn.classList.toggle('disabled',st.members.length<=1);
  currentModeKey=st.mode||'casual';
  if(mpMode)mpMode.textContent=MODE_LABELS[currentModeKey]||currentModeKey.toUpperCase();
  if(st.queuing)enterSearchUI();else exitSearchUI();
  var me=null;for(var j=0;j<st.members.length;j++){if(st.members[j].steamid===you){me=st.members[j];break}}
  var ivN=$('ivSelfName');if(ivN&&me)ivN.textContent=String(me.name).toUpperCase();
  var ivA=$('ivAvatar');if(ivA)ivA.style.backgroundImage=localAvatarUrl?("url('"+localAvatarUrl+"')"):'';
  updateInvCode();
  if(pendingJoin&&st.code===pendingJoin){pendingJoin='';flashJoin(true,closeInvite)}
}
function bindLobbyControls(host){
  var add=host.querySelector('.lbAdd');
  if(add){
    add.onmouseenter=function(){playHover()};
    add.onclick=function(e){
      if(e)e.stopPropagation();
      if(invEl&&invEl.classList.contains('show')){playHover();closeInvite();return}
      playHover();openInvite();
    };
  }
  var kicks=host.querySelectorAll('.lbKick');
  for(var i=0;i<kicks.length;i++){(function(b){
    b.onmouseenter=function(){playHover()};
    b.onclick=function(e){
      if(e)e.stopPropagation();
      playHover();
      fire('PartyKick',b.getAttribute('data-kick'));
    };
  })(kicks[i])}
}
function lbMemberSetAvatar(sid,url){
  if(!sid||!url)return;
  var els=document.querySelectorAll('#lbMembers [data-photo="'+sid+'"]');
  for(var i=0;i<els.length;i++)els[i].style.backgroundImage="url('"+url+"')";
}

var invShowCode=false,pendingJoin='';
var invEl=$('mmInvite'),invCodeEl=$('invCode'),invEyeEl=$('invEye'),invInputEl=$('invInput'),invToastEl=$('invToast');
function lobbyCode(){return (lobbyState&&lobbyState.code)?lobbyState.code:''}
function updateInvCode(){
  if(!invCodeEl)return;
  var c=lobbyCode();
  invCodeEl.textContent=invShowCode?(c||'-----'):(c?c.replace(/./g,'•'):'•••••');
  if(invEyeEl)invEyeEl.classList.toggle('off',!invShowCode);
}
function flashJoin(ok,done){
  if(!invInputEl){if(done)done();return}
  invInputEl.classList.remove('bad','ok');
  invInputEl.classList.add(ok?'ok':'bad');
  setTimeout(function(){invInputEl.classList.remove(ok?'ok':'bad');if(done)done()},ok?320:850);
}
function openInvite(){
  if(!invEl)return;
  closeModeSelect();
  invShowCode=false;updateInvCode();
  if(invToastEl)invToastEl.textContent='';
  if(invInputEl){invInputEl.value='';invInputEl.classList.remove('bad','ok')}
  invEl.classList.add('show');
  if(mainMenu)mainMenu.classList.add('inviteOpen');
  fire('KbOn');
  fire('PartyRefresh');
}
function closeInvite(){
  if(invEl)invEl.classList.remove('show');
  if(mainMenu)mainMenu.classList.remove('inviteOpen');
  if(invInputEl)invInputEl.blur();
  fire('KbOff');
}
function onAddBtn(t){return t&&t.closest&&t.closest('.lbAdd')}
document.addEventListener('mousedown',function(e){
  if(invEl&&invEl.classList.contains('show')&&!invEl.contains(e.target)&&!onAddBtn(e.target))closeInvite();
  if(mainMenu&&mainMenu.classList.contains('modeSelecting')){
    var ms=document.getElementById('mmModeSelect');
    if(ms&&!ms.contains(e.target))closeModeSelect();
  }
},true);
var lbAddBtn=document.querySelector('.lbAdd');
if(lbAddBtn){
  lbAddBtn.onmouseenter=function(){playHover()};
  lbAddBtn.onclick=function(e){
    if(e)e.stopPropagation();
    if(invEl&&invEl.classList.contains('show')){playHover();closeInvite();return}
    playHover();openInvite();
  };
}
if(invEyeEl){invEyeEl.onclick=function(){invShowCode=!invShowCode;updateInvCode()}}
var invCloseEl=$('invClose');if(invCloseEl){invCloseEl.onclick=function(){playHover();closeInvite()}}
function doJoin(){
  var v=invInputEl?invInputEl.value.replace(/[^A-Za-z0-9]/g,'').toUpperCase():'';
  if(v.length<3){flashJoin(false);notify('Please enter a valid lobby code.');return}
  playHover();pendingJoin=v;fire('PartyJoin',v);
}
var invJoinEl=$('invJoinBtn');if(invJoinEl){invJoinEl.onmouseenter=function(){playHover()};invJoinEl.onclick=doJoin}
if(invInputEl){
  invInputEl.onmousedown=function(){fire('KbOn')};
  invInputEl.onfocus=function(){fire('KbOn')};
  invInputEl.oninput=function(){invInputEl.classList.remove('bad','ok')};
  invInputEl.onkeydown=function(e){if(!e)return;if(e.keyCode===13)doJoin();else if(e.keyCode===27)closeInvite()};
}

function renderPlayers(list){
  var host=$('ivFriends');if(!host)return;
  if(!list||!list.length){host.innerHTML='<div class="ivFriendsEmpty">No other players online.</div>';return}
  var html='';
  for(var i=0;i<list.length;i++){
    var p=list[i];
    html+='<div class="ivFriend" data-sid="'+esc(p.sid64||p.steamid)+'">';
    html+='<div class="ivFrAvatar"></div>';
    html+='<div class="ivFrTxt"><div class="ivFrName">'+esc(p.name)+'</div><div class="ivFrStatus">'+esc(p.status||'Online')+'</div></div>';
    html+='<div class="ivInviteBtn" data-sid="'+esc(p.steamid)+'">INVITE</div>';
    html+='</div>';
  }
  host.innerHTML=html;
  var btns=host.querySelectorAll('.ivInviteBtn');
  for(var k=0;k<btns.length;k++){(function(b){b.onmouseenter=function(){playHover()};b.onclick=function(){playHover();fire('PartyInvite',b.getAttribute('data-sid'))}})(btns[k])}
}
function frSetAvatar(sid,url){
  if(!sid||!url)return;
  var els=document.querySelectorAll('.ivFriend[data-sid="'+sid+'"] .ivFrAvatar');
  for(var i=0;i<els.length;i++)els[i].style.backgroundImage="url('"+url+"')";
}

function setBg(el,url){if(el&&url)el.style.backgroundImage="url('"+url+"')"}

function chatScroll(){var l=$('chatLog');if(l)l.scrollTop=l.scrollHeight}
function chatAdd(html,cls){
  var l=$('chatLog');if(!l)return;
  var d=document.createElement('div');d.className='chatLine'+(cls?(' '+cls):'');d.innerHTML=html;
  l.appendChild(d);
  while(l.children.length>60)l.removeChild(l.firstChild);
  chatScroll();
}
function chatSystem(t){chatAdd('<span class="chSys">[System]:</span> '+esc(t))}
function chatUnbox(user,kind,rarity,item){
  var c=(rarity==='red')?'chRed':'chBlue';
  chatAdd('<span class="chSys">[System]:</span> <span class="chUser">@'+esc(user)+'</span> unboxed a '+esc(kind)+' <span class="chRare '+c+'">&#9670;</span> <span class="chItem '+c+'">'+esc(item)+'</span> skin blueprint!');
}
function chatSetAvatar(sid,url){
  if(!sid||!url)return;
  var els=document.querySelectorAll('.chAvatar[data-sid="'+sid+'"]');
  for(var i=0;i<els.length;i++)els[i].style.backgroundImage="url('"+url+"')";
}
function chatMessage(name,text,color,sid,avatar){
  var body='<span class="chBody"><span class="chUser" style="color:'+(color||'#dcdfe4')+'">'+esc(name)+'</span><span class="chSys">:</span> '+esc(text)+'</span>';
  chatAdd('<div class="chAvatar" data-sid="'+esc(sid||'')+'"></div>'+body,'chMsg');
  if(avatar)chatSetAvatar(sid,avatar);
}
var chatInputEl=$('chatInput');
function chatSubmit(){
  if(!chatInputEl)return;
  var v=chatInputEl.value.replace(/^\s+|\s+$/g,'');
  if(v)fire('ChatSend',v);
  chatInputEl.value='';chatInputEl.blur();
}
if(chatInputEl){
  chatInputEl.onmousedown=function(){fire('ChatOpen');var c=$('mmChat');if(c)c.classList.add('cActive')};
  chatInputEl.onfocus=function(){fire('ChatOpen');var c=$('mmChat');if(c)c.classList.add('cActive');chatScroll()};
  chatInputEl.onblur=function(){fire('ChatClose');var c=$('mmChat');if(c)c.classList.remove('cActive')};
  chatInputEl.onkeydown=function(e){
    if(!e)return;
    if(e.keyCode===13){if(e.preventDefault)e.preventDefault();chatSubmit()}
    else if(e.keyCode===27){chatInputEl.value='';chatInputEl.blur()}
  };
}
var chatLogEl=$('chatLog');
var chatHover=false;
var mmChatEl=$('mmChat');
if(mmChatEl){
  mmChatEl.onmouseenter=function(){chatHover=true};
  mmChatEl.onmouseleave=function(){chatHover=false};
}
window.chatWheel=function(d){if(chatHover&&chatLogEl)chatLogEl.scrollTop+=d};
if(chatLogEl){
  chatLogEl.onwheel=function(e){
    if(!e)return;
    chatLogEl.scrollTop+=(e.deltaY||0);
    if(e.preventDefault)e.preventDefault();
  };
}
chatSystem('Chat connection established.');

var RANK_BASE='asset://garrysmod/materials/mergeempires/rank/';
var RANKS=[
  {name:'UNRANKED', img:RANK_BASE+'badge_00.png'},
  {name:'IRON I',     img:RANK_BASE+'badge_01.png'},
  {name:'IRON II',    img:RANK_BASE+'badge_02.png'},
  {name:'IRON III',   img:RANK_BASE+'badge_03.png'},
  {name:'BRONZE I',   img:RANK_BASE+'badge_04.png'},
  {name:'BRONZE II',  img:RANK_BASE+'badge_05.png'},
  {name:'SILVER I',   img:RANK_BASE+'badge_06.png'},
  {name:'SILVER II',  img:RANK_BASE+'badge_07.png'},
  {name:'GOLD I',     img:RANK_BASE+'badge_08.png'},
  {name:'GOLD II',    img:RANK_BASE+'badge_09.png'},
  {name:'ELITE',      img:RANK_BASE+'badge_10.png'},
];
function applyRank(idx){
  var r=RANKS[Math.max(0,Math.min(idx||0,RANKS.length-1))];
  var ico=document.querySelector('.ivRankIco');
  var txt=document.querySelector('.ivRankTxt');
  if(ico)ico.src=r.img;
  if(txt)txt.textContent=r.name;
}
function lbdSetAvatar(sid,url){
  if(!sid||!url)return;
  var els=document.querySelectorAll('.lbdRow[data-sid="'+sid+'"] .lbdAvatar');
  for(var i=0;i<els.length;i++)els[i].style.backgroundImage="url('"+url+"')";
}

var cmSelMode='casual',cmSelMap='desert';
var cmModeList=$('cmModeList'),cmMapList=$('cmMapList');
function cmMark(list,attr,val){
  if(!list)return;
  var items=list.querySelectorAll('.cmItem');
  for(var i=0;i<items.length;i++)items[i].classList.toggle('active',items[i].getAttribute(attr)===val);
}
function cmBindList(list,attr,set){
  if(!list)return;
  var items=list.querySelectorAll('.cmItem');
  for(var i=0;i<items.length;i++){(function(it){
    var locked=it.getAttribute('data-enabled')==='0';
    it.onmouseenter=function(){if(!locked&&!it.classList.contains('active'))playHover()};
    it.onclick=function(){if(locked){playRefuse();notify('This mode is coming soon.');return}playHover();var v=it.getAttribute(attr);set(v);cmMark(list,attr,v)};
  })(items[i])}
}
cmBindList(cmModeList,'data-mode',function(v){cmSelMode=v||'casual'});
cmBindList(cmMapList,'data-map',function(v){cmSelMap=v||'desert'});
var cmJoinInput=$('cmJoinInput'),cmJoinBtn=$('cmJoinBtn'),cmJoinEye=$('cmJoinEye'),cmToast=$('cmToast'),cmCreateBtn=$('cmCreate');
function cmFlash(ok){
  if(!cmJoinInput)return;
  cmJoinInput.classList.remove('bad','ok');
  cmJoinInput.classList.add(ok?'ok':'bad');
  setTimeout(function(){if(cmJoinInput)cmJoinInput.classList.remove(ok?'ok':'bad')},ok?320:850);
}
function cmDoJoin(){
  var v=cmJoinInput?cmJoinInput.value.replace(/[^A-Za-z0-9]/g,'').toUpperCase():'';
  if(v.length<3){cmFlash(false);notify('Please enter a valid match code.');return}
  if(cmToast)cmToast.textContent='';
  playHover();fire('JoinCustomMatch',v);   // join the running custom match as a team player
}
if(cmCreateBtn){
  cmCreateBtn.onmouseenter=function(){playHover()};
  cmCreateBtn.onclick=function(){
    playHover();
    fire('CustomCreate',cmSelMode);   // server spins up the match + hands us a code popup in-game
  };
}
if(cmJoinBtn){cmJoinBtn.onmouseenter=function(){playHover()};cmJoinBtn.onclick=cmDoJoin}
if(cmJoinInput){
  cmJoinInput.onmousedown=function(){fire('KbOn')};
  cmJoinInput.onfocus=function(){fire('KbOn')};
  cmJoinInput.onblur=function(){fire('KbOff')};
  cmJoinInput.oninput=function(){cmJoinInput.classList.remove('bad','ok')};
  cmJoinInput.onkeydown=function(e){if(!e)return;if(e.keyCode===13)cmDoJoin();else if(e.keyCode===27)cmJoinInput.blur()};
}
function cmCode(){return cmJoinInput?cmJoinInput.value.replace(/[^A-Za-z0-9]/g,'').toUpperCase():''}
if(cmJoinEye){
  cmJoinEye.onmouseenter=function(){playHover()};
  cmJoinEye.onclick=function(){
    var v=cmCode();
    if(v.length<3){cmFlash(false);notify('Please enter a valid match code.');return}
    if(cmToast)cmToast.textContent='';
    playHover();fire('SpectateCode',v);
  };
}

var svBodyEl=$('svBody'),svRecvTime=0;
function svFmtAge(a){if(a<30)return 'STARTING';var m=Math.floor(a/60),s=Math.floor(a%60);return m+':'+(s<10?'0':'')+s}
function svTick(){
  var mm=$('mainMenu');if(!mm||!mm.classList.contains('subServers'))return;
  var cells=document.querySelectorAll('.svC-time[data-age]');
  var dt=(Date.now()-svRecvTime)/1000;
  for(var i=0;i<cells.length;i++){
    var a=(parseFloat(cells[i].getAttribute('data-age'))||0)+dt;
    var lab=svFmtAge(a);
    if(cells[i].textContent!==lab)cells[i].textContent=lab;
    var st=(a<30);
    if(cells[i].classList.contains('svStarting')!==st)cells[i].classList.toggle('svStarting',st);
  }
}
setInterval(svTick,1000);
function svSetAvatar(sid,url){
  if(!sid||!url)return;
  var els=document.querySelectorAll('.svAv[data-sid="'+sid+'"]');
  for(var i=0;i<els.length;i++)els[i].style.backgroundImage="url('"+url+"')";
}
if(svBodyEl){
  svBodyEl.addEventListener('click',function(e){
    var t=e.target;if(!t||!t.closest)return;
    var sp=t.closest('.svSpec');
    if(sp){playHover();fire('Spectate',sp.getAttribute('data-mid')||'')}
  });
}

var rcRejoinEl=$('rcRejoin');
if(rcRejoinEl){rcRejoinEl.onmouseenter=function(){playHover()};rcRejoinEl.onclick=function(){playHover();fire('Rejoin');if(mainMenu)mainMenu.classList.remove('rcOpen')}}

var rwEl=$('mmReward'),rwIconEl=$('rwIcon'),rwCountEl=$('rwCount'),rwNameEl=$('rwName'),rwTypeEl=$('rwType'),rwCloseEl=$('rwClose'),rwTimer=null;
function rewardShow(icon,count,name,type){
  if(!rwEl)return;
  if(rwIconEl)rwIconEl.src=icon||'';
  if(rwCountEl)rwCountEl.textContent='x'+fmt(count||0);
  if(rwNameEl)rwNameEl.textContent=String(name||'');
  if(rwTypeEl)rwTypeEl.textContent=String(type||'');
  if(rwTimer){clearTimeout(rwTimer);rwTimer=null}
  rwEl.classList.remove('closing');
  rwEl.classList.remove('show');
  void rwEl.offsetWidth;
  rwEl.classList.add('show');
  playPurchase();
}
function rewardClose(){
  if(!rwEl||!rwEl.classList.contains('show'))return;
  rwEl.classList.add('closing');
  if(rwTimer)clearTimeout(rwTimer);
  rwTimer=setTimeout(function(){if(rwEl){rwEl.classList.remove('show');rwEl.classList.remove('closing')}},320);
}
if(rwCloseEl){rwCloseEl.onmouseenter=function(){playHover()};rwCloseEl.onclick=function(){playHover();rewardClose()}}

var ntEl=$('mmNotif'),ntTextEl=$('ntText'),ntTimer=null;
function notify(msg,type){
  if(!ntEl||!ntTextEl)return;
  var m=String(msg==null?'':msg).replace(/^\s+|\s+$/g,'');
  if(!m)return;
  ntTextEl.textContent=m;
  ntEl.classList.toggle('ntOk',type==='ok');
  ntEl.classList.add('show');
  if(ntTimer)clearTimeout(ntTimer);
  ntTimer=setTimeout(function(){if(ntEl)ntEl.classList.remove('show')},3000);
}

var irEl=$('mmInviteReq'),irTextEl=$('irText'),irYesEl=$('irYes'),irNoEl=$('irNo'),irTimer=null;
function inviteReqHide(){
  if(irTimer){clearTimeout(irTimer);irTimer=null}
  if(irEl)irEl.classList.remove('show');
}
function inviteReqShow(name){
  if(!irEl||!irTextEl)return;
  irTextEl.textContent=String(name||'A PLAYER').toUpperCase()+' WANTS YOU IN THEIR LOBBY';
  irEl.classList.add('show');
  if(irTimer)clearTimeout(irTimer);
  irTimer=setTimeout(function(){inviteReqHide()},30000);
}
function inviteReqAnswer(ok){
  playHover();
  inviteReqHide();
  fire('PartyInviteAnswer',ok?'1':'0');
}
if(irYesEl){irYesEl.onmouseenter=function(){playHover()};irYesEl.onclick=function(){inviteReqAnswer(true)}}
if(irNoEl){irNoEl.onmouseenter=function(){playHover()};irNoEl.onclick=function(){inviteReqAnswer(false)}}

var shopTabsEls=[].slice.call(document.querySelectorAll('.shopTab'));
var SHOP_PANES={skins:'shopSkins',gems:'shopGems'};
function shopShow(key){
  for(var i=0;i<shopTabsEls.length;i++)shopTabsEls[i].classList.toggle('active',shopTabsEls[i].getAttribute('data-shop')===key);
  for(var k in SHOP_PANES){var p=$(SHOP_PANES[k]);if(p)p.classList.toggle('shopActive',k===key)}
  var box=document.querySelector('.shopBox');if(box)box.classList.toggle('shopBare',key==='gems');
  var shop=$('mmShop');if(shop)shop.classList.toggle('gemsTab',key==='gems');
}
for(var si=0;si<shopTabsEls.length;si++){(function(t){
  t.onmouseenter=function(){if(!t.classList.contains('active'))playHover()};
  t.onclick=function(){playHover();shopShow(t.getAttribute('data-shop'))};
})(shopTabsEls[si])}
function shopOpen(){shopShow('skins');fire('ShopOpen')}
function invOpen(){fire('InventoryOpen')}
var gemPlusEl=document.querySelector('[data-act="gemplus"]');
if(gemPlusEl){gemPlusEl.onclick=function(e){if(e&&e.stopPropagation)e.stopPropagation();playHover();var mm=$('mainMenu');if(mm){clearPanelSubs(mm);resetToLobbyTab();mm.classList.add('navShop')}var shopNav=document.querySelector('.tbNav[data-nav="shop"]');if(shopNav)setNav(shopNav);fire('ShopOpen');shopShow('gems')}}
var shopBodyEl=$('shopBody');
if(shopBodyEl){
  shopBodyEl.addEventListener('click',function(e){
    var t=e.target;if(!t||!t.closest)return;
    var c=t.closest('.shopCard');
    if(c){playHover();fire('ShopBuy',c.getAttribute('data-id')||'');return}
    var g=t.closest('.gemPack');
    if(g){
      playHover();
      // optimistic reward popup: a gem claim always succeeds server-side, so show it
      // instantly instead of waiting for the ME_Reward round-trip (removes the latency)
      var amtEl=g.querySelector('.gemAmount');
      var amt=amtEl?(parseInt(String(amtEl.textContent).replace(/[^0-9]/g,''),10)||0):0;
      rewardShow('asset://garrysmod/materials/mergeempires/menu/me_gem.png',amt,'GEMS','CURRENCY');
      window._rwOpt=Date.now();
      fire('GemBuy',g.getAttribute('data-id')||'');
    }
  });
}
var invBodyEl=$('invBody');
if(invBodyEl){
  invBodyEl.addEventListener('click',function(e){
    var t=e.target;if(!t||!t.closest)return;
    var c=t.closest('.invCard');if(!c)return;
    var item=c.getAttribute('data-item')||'';if(!item)return;
    playHover();
    // clicking the currently-equipped cell reverts to the base model; any other cell equips its skin
    var skin=c.classList.contains('equipped')?'':(c.getAttribute('data-skin')||'');
    fire('InvEquip',item+'|'+skin);
  });
}

window.CineAPI={
  showLogo:function(src){ratingImg.src=src||'';ratingImg.style.opacity='0';ratingImg.style.transform='translate(-50%,-50%) scale(0.94)';rating.style.display='flex';setTimeout(function(){ratingImg.style.opacity='1';ratingImg.style.transform='translate(-50%,-50%) scale(1)'},30)},
  hideLogo:function(){ratingImg.style.opacity='0';ratingImg.style.transform='translate(-50%,-50%) scale(0.94)';setTimeout(function(){rating.style.display='none';ratingImg.src=''},800)},
  black:function(on){veil.style.display=on?'block':'none';veil.style.opacity=on?'1':'0'},
  blackLevel:function(a){veil.style.display='block';veil.style.opacity=String(a||0)},
  blackFadeOut:function(ms){var d=(ms||450)/1000;veil.style.display='block';veil.style.transition='opacity '+d+'s cubic-bezier(.4,0,.2,1)';veil.style.opacity='0';setTimeout(function(){veil.style.display='none';veil.style.transition=''},ms||450)},
  showTitleScreen:function(){var t=$('titleScreen');if(t)t.classList.add('show')},
  hideTitleScreen:function(){var t=$('titleScreen');if(t){t.classList.remove('show');t.classList.remove('fading')}},
  fadeOutTitleTexts:function(){var t=$('titleScreen');if(t)t.classList.add('fading')},
  showLoadingScreen:function(){if(loadingScreen)loadingScreen.classList.add('show')},
  hideLoadingScreen:function(){if(loadingScreen)loadingScreen.classList.remove('show')},
  setLoadingStatus:function(msg){var el=$('loadStatus');if(el)el.textContent=String(msg||'')},
  precache:function(jsonUrls){try{var urls=JSON.parse(jsonUrls);if(!urls||!urls.length)return;for(var i=0;i<urls.length;i++){var img=new Image();img.src=urls[i]}}catch(e){}},
  showMatchLoad:function(title,mode,banner){
    var t=$('mlTitle');if(t)t.textContent=String(title||'');
    var m=$('mlMode');if(m)m.textContent=String(mode||'');
    var b=$('mlBanner');if(b)b.style.backgroundImage=banner?("url('"+banner+"')"):'';
    var f=$('mlFade');if(f){f.style.transition='none';f.style.opacity='0'}
    var el=$('matchLoad');if(el){el.classList.remove('show');void el.offsetWidth;el.classList.add('show')}
  },
  matchLoadToBlack:function(ms){var f=$('mlFade');if(f){f.style.transition='opacity '+((ms||700)/1000)+'s ease';f.style.opacity='1'}},
  hideMatchLoad:function(){var el=$('matchLoad');if(el)el.classList.remove('show')},

  showMainMenu:function(){if(mainMenu)mainMenu.classList.add('show');buildDecor();chatScroll()},
  hideMainMenu:function(){if(mainMenu)mainMenu.classList.remove('show')},

  setSteamProfile:function(name,url){
    if(url)localAvatarUrl=url;
    setBg($('tbAvatar'),url);
    renderLobby();
  },
  setProfileStats:function(name,avatarUrl,kills,deaths,playtimeSec){
    if(avatarUrl)localAvatarUrl=avatarUrl;
    setBg($('tbAvatar'),avatarUrl);
    var s=Math.max(0,parseInt(playtimeSec||0,10)||0);var ps=$('psPlaytime');
    if(ps)ps.textContent=(s/3600).toFixed(1)+'h';
    renderLobby();
  },
  setLobby:function(json){try{lobbyState=JSON.parse(json)}catch(e){lobbyState=null}renderLobby()},
  setPlayers:function(json){var l;try{l=JSON.parse(json)}catch(e){l=[]}renderPlayers(l)},
  frAvatar:function(s,u){frSetAvatar(s,u)},
  lbMemberAvatar:function(s,u){lbMemberSetAvatar(s,u)},
  toast:function(msg){if(pendingJoin){pendingJoin='';flashJoin(false);cmFlash(false)}notify(msg)},
  notify:function(msg,type){notify(msg,type)},
  inviteRequest:function(name){inviteReqShow(name)},
  purchase:function(msg){notify(msg,'ok');playPurchase()},
  playPurchase:function(){playPurchase()},
  reward:function(icon,count,name,type){if(window._rwOpt&&(Date.now()-window._rwOpt)<2500){window._rwOpt=0;return}rewardShow(icon,count,name,type)},
  setMultiplayer:function(mp){if(mainMenu)mainMenu.classList.toggle('mpMulti',!!mp)},
  showReconnect:function(show){if(mainMenu)mainMenu.classList.toggle('rcOpen',!!show)},
  setCurrencies:function(frag,gem){
    var f=$('curFrag');if(f)f.textContent=fmt(frag);
    var g=$('curGem');if(g)g.textContent=fmt(gem);
  },
  setActiveMatches:function(n){var a=$('amCount');if(a)a.textContent=fmt(n)},
  setModeCounts:function(json){
    var c;try{c=JSON.parse(json)}catch(e){c=null}
    if(!c)return;modeCounts=c;
    each('.msBanner',function(b){
      var k=b.getAttribute('data-mode'),q=b.querySelector('.msQueue');
      if(q&&c[k]!=null){var n=c[k];q.textContent=fmt(n)+' '+(n===1?'PLAYER':'PLAYERS')+' IN QUEUE'}
    });
    if(fdCountEl&&c[currentModeKey]!=null)fdCountEl.textContent=fmt(c[currentModeKey]);
  },
  setModeWins:function(json){
    var w;try{w=JSON.parse(json)}catch(e){w=null}
    if(!w)return;
    each('.msBanner',function(b){
      var k=b.getAttribute('data-mode'),s=b.querySelector('.msWins span');
      if(s&&w[k]!=null)s.textContent=fmt(w[k]);
    });
  },
  matchFound:function(){exitSearchUI()},
  setMode:function(m){if(mpMode){mpMode.textContent=String(m).toUpperCase()}},

  setRank:function(idx){applyRank(idx)},
  setLeaderboardHTML:function(h){var b=$('lbdBody');if(b)b.innerHTML=h},
  lbdAvatar:function(s,u){lbdSetAvatar(s,u)},
  setServersHTML:function(h){var b=$('svBody');if(b){b.innerHTML=h;svRecvTime=Date.now();svTick()}},
  svAvatar:function(s,u){svSetAvatar(s,u)},
  setShopSkins:function(h){var b=$('shopSkins');if(b)b.innerHTML=h},
  setShopGems:function(h){var b=$('shopGems');if(b)b.innerHTML=h},
  setInventory:function(h){var b=$('invBody');if(b)b.innerHTML=h},
  invStart:function(){window.__invBuf=''},
  invPush:function(h){window.__invBuf=(window.__invBuf||'')+h},
  invFlush:function(){var b=$('invBody');if(b)b.innerHTML=(window.__invBuf||'');window.__invBuf=''},
  chatSystem:function(t){chatSystem(t)},
  chatUnbox:function(u,k,r,i){chatUnbox(u,k,r,i)},
  chatMessage:function(n,t,c,s,a){chatMessage(n,t,c,s,a)},
  chatAvatar:function(s,u){chatSetAvatar(s,u)},
  chatFocus:function(){if(chatInputEl)chatInputEl.focus()},
  setXP:function(){},setMoney:function(){},setMapPlayers:function(){},selectTab:function(){}
};
if(window.CineReady)CineReady.Set();
})();
]]
end
