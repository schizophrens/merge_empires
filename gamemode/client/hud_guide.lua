ME = ME or {}

local guidePanel

local CATEGORIES = {
	{
		name = "GET STARTED",
		cards = {
			{ img = "start_1.gif", cap = "BUILD FARMS FOR STEADY INCOME, AND MINES AND PUMPS ON RESOURCE TILES" },
			{ img = "start_2.gif", cap = "SEND SEVERAL BUILDERS ONTO THE SAME SITE TO RAISE IT FASTER" },
			{ img = "start_3.gif", cap = "HOUSES RAISE YOUR POPULATION CAP SO YOU CAN FIELD A BIGGER ARMY" },
		},
	},
	{
		name = "BASIC CONTROLS",
		cards = {
			{ img = "ctrl_1.gif", cap = "LEFT CLICK A UNIT OR BUILDING TO SELECT IT" },
			{ img = "ctrl_2.gif", cap = "LEFT CLICK A TILE TO MOVE THE SELECTED UNITS THERE" },
			{ img = "ctrl_3.gif", cap = "CLICK AND DRAG TO BOX SELECT, HOLD SHIFT TO ADD TO THE SELECTION" },
			{ img = "ctrl_4.gif", cap = "PRESS B FOR THE BUILD MENU, R TO ROTATE, W TO CANCEL, X TO STOP" },
		},
	},
	{
		name = "ATTACKING",
		cards = {
			{ img = "atk_1.gif", cap = "RAISE YOUR ARMY AT THE TRAINING CAMP, THE FACTORY AND THE HARBOR" },
			{ img = "atk_2.gif", cap = "UNITS FIRE ON THEIR OWN IN RANGE, LEFT CLICK AN ENEMY TO FOCUS IT" },
			{ img = "atk_3.gif", cap = "TREES, ROCKS AND CLIFFS ARE SOLID COVER, NOTHING SHOOTS THROUGH" },
			{ img = "atk_4.gif", cap = "DESTROY THE ENEMY CORE TO ELIMINATE THEM FROM THE MATCH" },
		},
	},
	{
		name = "DEFENDING",
		cards = {
			{ img = "def_1.gif", cap = "TURRETS FIRE AUTOMATICALLY AT ANYTHING THAT ENTERS THEIR RANGE" },
			{ img = "def_2.gif", cap = "WALLS SEAL A HEX EDGE, GATES LET YOUR OWN UNITS THROUGH" },
			{ img = "def_3.gif", cap = "MISSILE DEFENSE SHOOTS DOWN INCOMING SALVOS IN MID-AIR" },
			{ img = "def_4.gif", cap = "MINES TURN INVISIBLE ONCE BUILT AND DETONATE UNDER ENEMY VEHICLES" },
		},
	},
	{
		name = "NAVAL",
		cards = {
			{ img = "sea_1.gif", cap = "HARBORS STAND ON WATER BACKING ONTO A BEACH AND BUILD EVERY SHIP" },
			{ img = "sea_2.gif", cap = "LOAD LAND UNITS ONTO A BARGE WITH F, PUT THEM ASHORE WITH G" },
			{ img = "sea_3.gif", cap = "DESTROYERS SHELL THE COAST, SUBMARINES HUNT SHIPS AND NOTHING ELSE" },
		},
	},
}

local HTML = [==[
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
@font-face{font-family:'HanleyPro';src:url('asset://garrysmod/materials/mergeempires/fonts/Hanley-Pro-Sans.otf') format('opentype')}
@font-face{font-family:'EinaSemiBold';src:url('asset://garrysmod/materials/mergeempires/fonts/Eina-03-SemiBold.otf') format('opentype')}
*{margin:0;padding:0;box-sizing:border-box;-webkit-user-select:none;user-select:none}
html{zoom:__ZOOM__}
html,body{width:100%;height:100%;background:transparent;overflow:hidden;font-family:'HanleyPro','Segoe UI',sans-serif;color:#fff;opacity:0;animation:gfin .22s ease forwards}
@keyframes gfin{to{opacity:1}}
#index{position:fixed;left:52px;top:78px;width:268px}
.ix-label{font-size:15px;letter-spacing:2px;color:#7a7d83;margin:0 0 14px 6px}
.ix-item{height:44px;display:flex;align-items:center;justify-content:center;text-align:center;padding:0 18px;margin-bottom:8px;border-radius:8px;font-size:17px;letter-spacing:.5px;color:#9a9da3;background:rgba(18,20,26,.55);cursor:pointer;transition:background .12s,color .12s}
.ix-item:hover{color:#d6d8dc;background:rgba(34,36,44,.78)}
.ix-item.active{color:#fff;background:rgba(40,42,50,.97);box-shadow:0 2px 10px rgba(0,0,0,.4)}
.ix-item.back{margin-top:16px;color:#fff;background:#e42020;box-shadow:0 4px 14px rgba(0,0,0,.45)}
.ix-item.back:hover{color:#fff;background:#ff3a3a}
.ix-item span{display:inline-block;transform:translateY(-3px)}
#content{position:fixed;left:0;right:0;top:88px;bottom:40px;display:flex;align-items:center;justify-content:center;gap:26px;pointer-events:none}
#cards{display:flex;flex-wrap:wrap;gap:24px;align-items:flex-start;justify-content:center;max-width:824px}
.card{width:376px;border-radius:12px;overflow:hidden;background:rgba(8,10,14,.92);box-shadow:0 10px 30px rgba(0,0,0,.55);pointer-events:auto}
.card-img{height:188px;background-size:cover;background-position:center;background-color:#16212c}
.card-img.empty{background:linear-gradient(135deg,#223344,#11171f)}
.card-cap{padding:16px 18px 20px;text-align:center;font-family:'EinaSemiBold','Segoe UI',sans-serif;font-weight:700;font-size:15px;line-height:1.32;letter-spacing:.4px;color:#f2f3f5;text-transform:uppercase}
.arrow{flex:none;width:42px;height:60px;cursor:pointer;opacity:.85;pointer-events:auto;background-image:url('asset://garrysmod/materials/mergeempires/game/me_arrow.png');background-size:contain;background-repeat:no-repeat;background-position:center;transition:opacity .12s,transform .1s}
.arrow:hover{opacity:1}
#arrowL{transform:rotate(-90deg)}
#arrowL:hover{transform:rotate(-90deg) scale(1.06)}
#arrowR{transform:rotate(90deg)}
#arrowR:hover{transform:rotate(90deg) scale(1.06)}
</style></head><body>
<div id="index"></div>
<div id="content"><div id="arrowL" class="arrow"></div><div id="cards"></div><div id="arrowR" class="arrow"></div></div>
<script>
var DATA=__DATA__;
var ASSET='asset://garrysmod/materials/mergeempires/guide/';
var cur=0;
function buildIndex(){
  var h="<div class='ix-label'>INDEX</div>";
  for(var i=0;i<DATA.length;i++)h+="<div class='ix-item cat'><span>"+DATA[i].name+"</span></div>";
  h+="<div class='ix-item back'><span>BACK</span></div>";
  document.getElementById('index').innerHTML=h;
  var it=document.querySelectorAll('.cat');
  for(var i=0;i<it.length;i++){(function(n){it[n].onclick=function(){cur=n;render();};})(i);}
  document.querySelector('.back').onclick=function(){guide.close();};
}
function render(){
  var c=DATA[cur];
  var it=document.querySelectorAll('.cat');
  for(var i=0;i<it.length;i++)it[i].className='ix-item cat'+(i===cur?' active':'');
  var h='';
  for(var i=0;i<c.cards.length;i++){
    var cd=c.cards[i];
    var st=cd.img?("background-image:url('"+ASSET+cd.img+"')"):"";
    h+="<div class='card'><div class='card-img"+(cd.img?'':' empty')+"' style=\""+st+"\"></div><div class='card-cap'>"+cd.cap+"</div></div>";
  }
  document.getElementById('cards').innerHTML=h;
}
function go(d){cur=(cur+d+DATA.length)%DATA.length;render();}
window.onload=function(){
  buildIndex();render();
  document.getElementById('arrowL').onclick=function(){go(-1);};
  document.getElementById('arrowR').onclick=function(){go(1);};
  document.addEventListener('keydown',function(e){if(e.key==='Escape')guide.close();});
};
</script></body></html>
]==]

local function buildHTML()
	local json = util.TableToJSON(CATEGORIES)
	local zoom = string.format("%.4f", ScrH() / 1080)
	local out  = HTML:gsub("__ZOOM__", function() return zoom end)
	out        = out:gsub("__DATA__", function() return json end)
	return out
end

local function removeGuide()
	if IsValid(guidePanel) then guidePanel:Remove() end
	guidePanel = nil
end

function ME.CloseGuide()
	local p = guidePanel
	if not IsValid(p) then return end
	if p.closing then return end
	p.closing = true
	p.closeAt = SysTime()
	if IsValid(p.html) then
		p.html:RunJavascript("document.body.style.animation='none';document.body.style.transition='opacity .2s';document.body.style.opacity=0;")
	end
	timer.Simple(0.22, removeGuide)
end

function ME.OpenGuide()
	removeGuide()

	local p = vgui.Create("EditablePanel")
	p:SetSize(ScrW(), ScrH())
	p:SetPos(0, 0)
	p:MakePopup()
	p.openAt = SysTime()
	p.Paint = function(self, w, h)
		Derma_DrawBackgroundBlur(self, self.openAt)
		local f
		if self.closing then
			f = math.Clamp(1 - (SysTime() - self.closeAt) / 0.2, 0, 1)
		else
			f = math.Clamp((SysTime() - self.openAt) / 0.2, 0, 1)
		end
		surface.SetDrawColor(8, 10, 14, 178 * f)
		surface.DrawRect(0, 0, w, h)
	end
	p.OnKeyCodePressed = function(_, key)
		if key == KEY_ESCAPE then ME.CloseGuide() return true end
	end

	local html = vgui.Create("DHTML", p)
	html:Dock(FILL)
	html:SetAllowLua(false)
	html:AddFunction("guide", "close", function() ME.CloseGuide() end)
	html:SetHTML(buildHTML())
	p.html = html

	guidePanel = p
end

hook.Add("Think", "ME_GuideAutoClose", function()
	if IsValid(guidePanel) and not (ME.InGame and ME.InGame()) then
		removeGuide()
	end
end)
