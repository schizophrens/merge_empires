ME = ME or {}
ME.Build = ME.Build or {}
local B = ME.Build
local S = ME.UI.Scale

local ICON_CAM_DIR  = Vector(1, -0.82, 0.72)
local ICON_FACE     = Angle(0, math.deg(math.atan2(ICON_CAM_DIR.y, ICON_CAM_DIR.x)) - 90, 0)

local ICON_FACE_VEH = Angle(0, math.deg(math.atan2(ICON_CAM_DIR.y, ICON_CAM_DIR.x)) - 90 - 35, 0)

local function renderIcon(model, ang, weapon, kind, zoom)
	local SIZE = 128
	local ent = ClientsideModel(model)
	if not IsValid(ent) then return end
	ent:SetNoDraw(true)
	ent:SetPos(vector_origin)
	ent:SetAngles(ang or angle_zero)
	ent:SetupBones()

	local wep
	if weapon then
		wep = ClientsideModel(weapon)
		if IsValid(wep) then
			wep:SetNoDraw(true)
			local ok = pcall(function()
				local wp, wa = ME.HandPose and ME.HandPose(ent)
				if not (wp and wa) then error("no hand pose") end
				wep:SetPos(wp); wep:SetAngles(wa); wep:SetupBones()
			end)
			if not ok then wep:Remove(); wep = nil end
		end
	end

	local mins, maxs
	if kind then mins, maxs = ME.UnitBounds(kind, ent) else mins, maxs = ent:GetModelRenderBounds() end

	local center = ent:LocalToWorld((mins + maxs) * 0.5)
	local radius = math.max(6, (maxs - mins):Length() * 0.5)
	local fov  = 30

	local dist = radius / math.sin(math.rad(fov) * 0.5) * (weapon and 1.22 or 1.06) / (zoom or 1)
	local dir  = ICON_CAM_DIR:GetNormalized()
	local camPos = center + dir * dist
	local rt = GetRenderTarget("me_build_icon_rt", SIZE, SIZE)
	render.PushRenderTarget(rt)
	render.Clear(0, 0, 0, 0, true, true)
	cam.Start3D(camPos, (center - camPos):Angle(), fov, 0, 0, SIZE, SIZE)
		render.SuppressEngineLighting(false)
		render.ResetModelLighting(0.58, 0.58, 0.6)
		render.SetModelLighting(BOX_TOP,   1.0, 1.0, 1.0)
		render.SetModelLighting(BOX_FRONT, 0.7, 0.7, 0.72)
		render.SetModelLighting(BOX_RIGHT, 0.45, 0.45, 0.47)
		ent:DrawModel()
		if IsValid(wep) then wep:DrawModel() end
	cam.End3D()
	local png = render.Capture({ format = "png", x = 0, y = 0, w = SIZE, h = SIZE, alpha = true })
	render.PopRenderTarget()
	ent:Remove()
	if IsValid(wep) then wep:Remove() end
	return png
end

local ICON_VERSION = "23"

local function bakeIcons()
	if B._baking then return end
	B._baking = true
	file.CreateDir("mergeempires")
	file.CreateDir("mergeempires/build")
	local queue, done = {}, 0
	for _, b in ipairs(ME.Buildings or {}) do if b.model then queue[#queue + 1] = b end end
	for kind, k in pairs(ME.UnitKinds or {}) do
		if k.model then

			local ang = k.vehicle
				and Angle(0, k.iconYaw or (ICON_FACE_VEH.yaw + 90 + (k.yaw or 0)), 0)
				or ICON_FACE
			queue[#queue + 1] = { id = "unit_" .. kind, kind = kind, model = ME.UnitModel(kind), ang = ang,
			                      weapon = k.weapon, zoom = k.iconZoom }
		end
	end
	for i = 1, (ME.Config.MaxFactions or 6) do
		local f = ME.GetFaction and ME.GetFaction(i)
		if f and f.core then queue[#queue + 1] = { id = "core_" .. i, model = f.core } end
	end
	for _, sk in ipairs(ME.Skins or {}) do if sk.model then queue[#queue + 1] = { id = "skin_" .. sk.id, model = sk.model, ang = sk.unit and ICON_FACE or nil, weapon = sk.weapon } end end
	hook.Add("PostRender", "ME_BuildIconRender", function()
		local b = table.remove(queue, 1)
		if b then

			local ok, png = pcall(renderIcon, b.model, b.ang, b.weapon, b.kind, b.zoom)
			if not ok then
				ErrorNoHalt("[ME] icon bake failed for " .. tostring(b.id) .. ": " .. tostring(png) .. "\n")
			elseif png and #png > 0 then
				file.Write("mergeempires/build/" .. b.id .. ".png", png); done = done + 1
			end
		else
			hook.Remove("PostRender", "ME_BuildIconRender")
			file.Write("mergeempires/build/version.txt", ICON_VERSION)
			B._baking = false
			print(string.format("[ME] Rendered %d build icons -> garrysmod/data/mergeempires/build/", done))
			if IsValid(B.dhtml) then B.dhtml:Remove(); B.dhtml = nil end
			if MEMenu and MEMenu.RefreshInventory then MEMenu.RefreshInventory() end
			if MEMenu and MEMenu.RefreshShopSkins then MEMenu.RefreshShopSkins() end
		end
	end)
end

local function iconsMissing()
	for kind, k in pairs(ME.UnitKinds or {}) do
		if k.model and not file.Exists("mergeempires/build/unit_" .. kind .. ".png", "DATA") then return true end
	end
	for _, b in ipairs(ME.Buildings or {}) do
		if b.model and not file.Exists("mergeempires/build/" .. b.id .. ".png", "DATA") then return true end
	end
	return false
end
local function autoBakeCheck()
	if file.Read("mergeempires/build/version.txt", "DATA") ~= ICON_VERSION or iconsMissing() then bakeIcons() end
end
hook.Add("InitPostEntity", "ME_BuildIconAutoBake", function() timer.Simple(3, autoBakeCheck) end)
timer.Simple(3, autoBakeCheck)

local AST = "asset://garrysmod/materials/mergeempires/"

local function iconSrc(id)
	local path = "mergeempires/build/" .. id .. ".png"
	if file.Exists(path, "DATA") then
		local data = file.Read(path, "DATA")
		if data and #data > 0 then return "data:image/png;base64," .. (util.Base64Encode(data):gsub("%s", "")) end
	end
end

ME.BuildIconSrc = iconSrc

local function skinIconSrc(itemKey, baseIconId)
	local lp = LocalPlayer()
	if IsValid(lp) then
		local skinId = lp:GetNWString("ME_Skin_" .. itemKey, "")
		if skinId ~= "" then
			local s = iconSrc("skin_" .. skinId)
			if s then return s end
		end
	end
	return iconSrc(baseIconId)
end

local function buildSlotsHTML()
	local html = {}
	for _, cat in ipairs(ME.BuildCategories or {}) do
		local list = ME.BuildingsInCategory(cat.id)
		if #list > 0 then
			local c = cat.color
			html[#html + 1] = string.format('<div class="cat" style="background:rgb(%d,%d,%d)">%s</div><div class="grid">', c.r, c.g, c.b, cat.label)
			for _, b in ipairs(list) do
				local src = skinIconSrc("b_" .. b.id, b.id)
				if src then
					html[#html + 1] = string.format('<div class="slot" data-id="%s"><img src="%s"></div>', b.id, src)
				else
					html[#html + 1] = string.format('<div class="slot noimg" data-id="%s"></div>', b.id)
				end
			end
			html[#html + 1] = '</div>'
		end
	end
	return table.concat(html)
end

local function buildDataJSON()
	local data = {}
	for _, b in ipairs(ME.Buildings or {}) do
		data[b.id] = { name = b.name, desc = b.desc, price = b.price, max = b.max }
	end
	return util.TableToJSON(data)
end

local function buildHTML()
	local zoom = string.format("%.4f", ScrH() / 1080)
	local HTML = [==[
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
@font-face{font-family:'Eina';src:url(']==] .. AST .. [==[fonts/Eina-03-SemiBold.otf') format('opentype')}
@font-face{font-family:'Barlow';src:url(']==] .. AST .. [==[fonts/Barlow-Light.ttf') format('truetype')}
@font-face{font-family:'Rajdhani';src:url(']==] .. AST .. [==[fonts/Rajdhani-SemiBold.ttf') format('truetype')}
*{margin:0;padding:0;box-sizing:border-box;user-select:none}
html{zoom:__ZOOM__}
html,body{width:100%;height:100%;background:transparent;overflow:hidden;font-family:'Eina','Segoe UI',sans-serif;pointer-events:none}
#band{position:fixed;right:14px;bottom:72px;width:232px;max-height:500px;display:flex;flex-direction:column;
  background:linear-gradient(180deg,#343530 0%,#2b2c28 100%);border:1px solid #4d4e48;border-radius:11px;
  box-shadow:0 0 0 2px #000,0 12px 34px rgba(0,0,0,.5);overflow:hidden;pointer-events:auto;
  transform-origin:50% 100%;transition:transform .3s cubic-bezier(.2,.85,.25,1),opacity .22s ease}
#band.closed{transform:translateY(48px);opacity:0;pointer-events:none}
#hdr{flex:0 0 auto;height:46px;display:flex;align-items:center;justify-content:center;gap:7px;
  background:rgba(0,0,0,.22);font-size:19px;letter-spacing:.6px;color:#eef0f3}
#hdr img{width:34px;height:34px;object-fit:contain}
#scroll{flex:1 1 auto;min-height:0;overflow-y:scroll;overflow-x:hidden;padding:0 7px 8px}
#scroll::-webkit-scrollbar{width:5px}
#scroll::-webkit-scrollbar-track{background:rgba(0,0,0,.3);border-radius:3px;margin:6px 0}
#scroll::-webkit-scrollbar-thumb{background:rgba(255,255,255,.32);border-radius:3px}
#scroll::-webkit-scrollbar-thumb:hover{background:rgba(255,255,255,.5)}
.cat{height:26px;display:flex;align-items:center;padding:0 9px;margin:8px 0 6px;border-radius:5px;
  font-size:13px;letter-spacing:.6px;color:#1d1f1b;font-weight:600}
.grid{display:flex;flex-wrap:wrap;gap:6px}
.slot{position:relative;width:64px;height:64px;flex:0 0 auto;background:#16171a;border:1px solid rgba(255,255,255,.35);border-radius:7px;
  box-shadow:0 0 0 1px rgba(0,0,0,.55);cursor:pointer;transition:background .12s,border-color .12s,transform .08s}
.slot:hover{background:#2b2e33}
.slot:active{transform:scale(.95)}
.slot img{position:absolute;inset:2px;width:calc(100% - 4px);height:calc(100% - 4px);object-fit:contain;
  filter:drop-shadow(0 2px 4px rgba(0,0,0,.5));transition:filter .15s}
.slot.broke img{filter:brightness(0)}
/* limit reached: the slot is greyed out and no longer clickable */
.slot.maxed{cursor:default;opacity:.4;border-color:rgba(224,72,58,.6)}
.slot.maxed:hover{background:#16171a}
.slot.maxed:active{transform:none}
.slot.maxed img{filter:grayscale(1) brightness(.6)}
.slot.noimg::after{content:'?';position:absolute;inset:0;display:flex;align-items:center;justify-content:center;color:#5a5d63;font-size:20px}
#buildBtn{position:fixed;right:14px;bottom:14px;width:232px;height:50px;display:flex;align-items:center;justify-content:center;gap:9px;
  background:#121316;border:1px solid #4d4e48;border-radius:11px;
  box-shadow:0 0 0 2px #000,0 10px 28px rgba(0,0,0,.5);cursor:pointer;color:#eef0f3;font-size:23px;letter-spacing:.5px;pointer-events:auto;transition:background .12s}
#buildBtn:hover{background:#1c1e22}
#buildBtn img{width:31px;height:31px;object-fit:contain}
#buildBtn .k{color:#9a9ea4;font-size:19px}
#tip{position:fixed;right:254px;top:0;width:200px;opacity:0;transition:opacity .12s;pointer-events:none;z-index:50}
#tip .box{position:relative;background:#1a1b1e;border:1px solid #3a3d42;border-radius:8px;padding:10px 12px;box-shadow:0 8px 26px rgba(0,0,0,.55)}
#tip .box::after{content:'';position:absolute;right:-7px;top:50%;transform:translateY(-50%);
  border-top:7px solid transparent;border-bottom:7px solid transparent;border-left:7px solid #1a1b1e}
#tip .t{font-size:16px;color:#fff;margin-bottom:3px}
#tip .d{font-family:'Barlow','Segoe UI',sans-serif;font-weight:300;font-size:11px;line-height:1.32;color:#9a9ea4;margin-bottom:9px}
#tip .row{display:flex;align-items:center;gap:16px}
#tip .stat{display:flex;align-items:center;gap:5px;font-family:'Rajdhani','Segoe UI',sans-serif;font-weight:700;font-size:15px}
#tip .stat img{width:15px;height:15px;object-fit:contain}
#tip .stat.cnt{gap:3px}
#tip .stat.cnt img{width:20px;height:20px}
#tipP{color:#f5cd46}#tipM{color:#eef0f3}
/* ---- info cards (building + core): same pattern as the build-menu band.
   NOTE: centred with margin:auto, NOT translateX(-50%) — a permanent transform puts the card on its
   own compositing layer at a half-pixel, which makes the border/background edges look transparent. */
.card{position:fixed;left:0;right:0;bottom:20px;margin:0 auto;
  width:-webkit-fit-content;width:fit-content;max-width:400px;
  display:flex;flex-direction:column;align-items:center;padding:11px 20px 13px;
  pointer-events:none;opacity:0;transform:translateY(48px);
  transition:transform .3s cubic-bezier(.2,.85,.25,1),opacity .22s ease;
  background:linear-gradient(180deg,#343530 0%,#2b2c28 100%);border:1px solid #4d4e48;border-radius:11px;
  box-shadow:0 0 0 2px #000,0 12px 34px rgba(0,0,0,.5)}
.card.show{opacity:1;pointer-events:auto;transform:none}
/* producing building: the card spans exactly the same width as the unit row above it. The value below is
   only the pre-measurement default — layoutTrain() replaces it with the row's measured width. */
.card.wide{width:371px;min-width:371px;max-width:371px}
.card .t{font-size:23px;font-weight:700;color:#fff;line-height:1.05;letter-spacing:.3px;text-align:center}
.card .d{font-family:'Barlow','Segoe UI',sans-serif;font-weight:300;font-size:13px;color:#b7bac0;
  margin-top:6px;line-height:1.34;text-align:center;max-width:320px}
.card .btn{margin-top:12px;width:164px;height:36px;border-radius:8px;font-size:17px;font-weight:800;letter-spacing:.4px;
  display:flex;align-items:center;justify-content:center;box-shadow:0 3px 0 rgba(0,0,0,.28);transition:background .12s,color .12s}
.card .btn.red{background:#ef524f;color:#fff;cursor:pointer}
.card .btn.red:hover{background:#ff6360}
.card .btn.red:active{transform:translateY(2px);box-shadow:0 1px 0 rgba(0,0,0,.28)}
.card .btn.off{background:#4a4d53;color:#8b8e94;cursor:not-allowed}
/* confirm state: pure white (beats the .red:hover rule), reverts on timeout */
.card .btn.armed,.card .btn.armed:hover{background:#fff;color:#1a1b1e;cursor:pointer}
/* ---- unit card TRASH square: sits at the card's right edge, same height, same DA as the card ---- */
#biTrash{position:absolute;left:100%;top:0;bottom:0;margin-left:9px;min-width:54px;display:none;
  align-items:center;justify-content:center;pointer-events:auto;cursor:pointer;
  background:linear-gradient(180deg,#3b3c37 0%,#313230 100%);border:1px solid #4d4e48;border-radius:11px;
  box-shadow:0 0 0 2px #000,0 12px 34px rgba(0,0,0,.5);transition:background .12s}
#biTrash.show{display:flex}
#biTrash img{width:50%;height:50%;max-width:32px;max-height:32px;object-fit:contain;pointer-events:none}
#biTrash:hover{background:linear-gradient(180deg,#46473f 0%,#3a3b36 100%)}
/* armed (confirm) state: RED, not white — a white square hid the white trash icon completely */
#biTrash.armed,#biTrash.armed:hover{background:#ef524f;border-color:#ff7b78}
/* ---- unit-creation panel: a ROW of cards floating above the info card (soldiers for the training camp,
   vehicles for the factory, ships for the harbor). Positioned with left+margin-left (NOT translateX — a
   transform makes CEF mis-map the clicks). The margin here is only the pre-measurement default: layoutTrain()
   overrides it with -width/2 once the real cards are in, so ANY number of them ends up dead centre. ---- */
#tspawn{position:absolute;left:50%;margin-left:-186px;bottom:calc(100% + 13px);display:none;gap:9px;pointer-events:auto}
#tspawn.show{display:flex}
.tcard{display:flex;flex-direction:column;align-items:center;width:85px;padding:5px 6px 6px;cursor:pointer;
  background:linear-gradient(180deg,#343530 0%,#2b2c28 100%);border:1px solid #4d4e48;border-radius:11px;
  box-shadow:0 0 0 2px #000,0 12px 34px rgba(0,0,0,.5);transition:background .1s}
.tcard:hover{background:linear-gradient(180deg,#3f4039,#343530)}
.tcard:active{background:#242520}
.tcard.broke{cursor:not-allowed}
.tcard.broke .cs-img{filter:brightness(0)}
/* ---- training production queue: a vertical band of slots to the RIGHT of the whole panel. It runs the
   FULL height of the block — from the top of the unit-card row down to the bottom edge of the DESTROY
   card — so it reads as one tall column beside the interface rather than a stub floating next to the
   cards. Both edges are pinned in layoutTrainQueue() (top from the measured card row, bottom flush with
   the card), which makes its height exact for every producer: training camp, factory and harbor. The
   slots then divide that height evenly, exactly like the core's queue. ---- */
#tprod{position:absolute;left:calc(100% + 12px);bottom:0;top:auto;display:none;flex-direction:column;justify-content:center;
  padding:8px;pointer-events:auto;
  background:linear-gradient(180deg,#343530 0%,#2b2c28 100%);border:1px solid #4d4e48;border-radius:12px;
  box-shadow:0 0 0 2px #000,0 12px 34px rgba(0,0,0,.5)}
#tprod.show{display:flex}
#tprodList{display:flex;flex-direction:column;gap:0;align-items:center}
#tprodList .uslot{width:46px;height:46px}
/* ---- builder spawn card (floats above the core card) ---- */
#cspawn{position:absolute;left:50%;margin-left:-44px;bottom:calc(100% + 13px);display:flex;flex-direction:column;align-items:center;
  width:88px;padding:7px 7px 9px;pointer-events:auto;cursor:pointer;
  background:linear-gradient(180deg,#343530 0%,#2b2c28 100%);border:1px solid #4d4e48;border-radius:11px;box-shadow:0 0 0 2px #000,0 12px 34px rgba(0,0,0,.5)}
#cspawn:hover{background:linear-gradient(180deg,#3f4039,#343530)}
.cs-title{font-size:13px;font-weight:600;color:#eef0f3;margin-bottom:3px;white-space:nowrap}
/* the dark square lives on the box; the model is the img inside, so blackening the img blackens only the model */
.cs-imgbox{width:52px;height:52px;background:#191a1d;border-radius:8px;box-shadow:inset 0 0 0 1px rgba(0,0,0,.6);overflow:hidden}
.cs-img{width:100%;height:100%;object-fit:contain}
.cs-row{display:flex;align-items:center;justify-content:center;gap:5px;margin-top:3px;font-family:'Rajdhani',sans-serif;font-weight:700;font-size:13px;color:#eef0f3}
.cs-row img{width:14px;height:14px;object-fit:contain}
.cs-row .p{color:#f5cd46}
#cstip{position:absolute;left:50%;margin-left:-112px;bottom:calc(100% + 168px);display:none;width:224px;pointer-events:none;z-index:60}
#cstip.show{display:block}
#cstip .box{position:relative;background:#1a1b1e;border:1px solid #3a3d42;border-radius:8px;padding:10px 12px;box-shadow:0 8px 26px rgba(0,0,0,.55);text-align:center}
#cstip .box::after{content:'';position:absolute;bottom:-7px;left:50%;transform:translateX(-50%);border-left:7px solid transparent;border-right:7px solid transparent;border-top:7px solid #1a1b1e}
#cstip .t{font-size:15px;color:#fff;margin-bottom:3px}
#cstip .d{font-family:'Barlow','Segoe UI',sans-serif;font-weight:300;font-size:12px;line-height:1.32;color:#9a9ea4}
/* ---- unit production queue: 4 evenly-spaced capacity slots to the RIGHT of the core card ---- */
#uprod{position:absolute;left:calc(100% + 12px);bottom:0;max-height:100%;display:none;flex-direction:column;
  padding:8px;width:74px;pointer-events:auto;overflow:hidden;
  background:linear-gradient(180deg,#343530 0%,#2b2c28 100%);border:1px solid #4d4e48;border-radius:12px;
  box-shadow:0 0 0 2px #000,0 12px 34px rgba(0,0,0,.5)}
#uprod.show{display:flex}
#uprodList{display:flex;flex-direction:column;gap:0;align-items:center}
.uslot{position:relative;width:52px;height:52px;flex:0 0 auto;border-radius:9px;overflow:hidden;background:#20222a;
  border:1px solid #4d4e48;box-shadow:0 3px 8px rgba(0,0,0,.5),inset 0 0 0 1px rgba(0,0,0,.3)}
.uslot .fill{position:absolute;left:0;right:0;bottom:0;height:0;background:linear-gradient(180deg,#3f86ff 0%,#0a4ff0 100%);opacity:.92;z-index:1}
.uslot img{position:absolute;left:0;top:0;right:0;bottom:0;width:100%;height:100%;object-fit:contain;padding:4px;z-index:2}
.uslot.pending{filter:brightness(.7)}
.uslot.pending img{filter:grayscale(.4)}
/* empty capacity slot: a dim recessed placeholder (no centre dot) */
.uslot.empty{background:#191a1d;border-color:#33342f;box-shadow:inset 0 2px 5px rgba(0,0,0,.55)}
/* hover a queued slot -> it wobbles like an iOS app about to be deleted, with a centred trash icon
   (no red background). Click to cancel that unit (refunded). Empty slots don't react. */
.uslot .utrash{position:absolute;left:0;top:0;right:0;bottom:0;z-index:4;display:none;align-items:center;justify-content:center;
  background:rgba(0,0,0,.28);cursor:pointer}
.uslot:not(.empty):hover .utrash{display:flex}
.uslot:not(.empty):hover{animation:uJiggle .32s ease-in-out infinite}
.uslot .utrash img{position:static;width:24px;height:24px;padding:0;filter:drop-shadow(0 1px 3px rgba(0,0,0,.85))}
@keyframes uJiggle{0%{transform:rotate(-2.4deg)}25%{transform:rotate(1.6deg)}50%{transform:rotate(-1.4deg)}75%{transform:rotate(2deg)}100%{transform:rotate(-2.4deg)}}
/* builder card unaffordable: only the MODEL goes black (the square box stays), like the build-menu slots */
#cspawn.broke{cursor:not-allowed}
#cspawn.broke .cs-img{filter:brightness(0)}
/* ---- "WE ARE IN COMBAT" banner: top-centre (below the player bubbles), slides down-in / up-out ---- */
#combat{position:fixed;left:0;right:0;top:178px;margin:0 auto;width:-webkit-fit-content;width:fit-content;
  padding:11px 34px;pointer-events:none;z-index:60;
  background:linear-gradient(180deg,#f01d12 0%,#cf0d05 100%);border-radius:9px;
  box-shadow:0 0 15px rgba(255,42,28,.95),0 0 34px rgba(255,34,22,.65),0 0 62px rgba(232,20,12,.42),0 6px 18px rgba(0,0,0,.42);
  font-family:'Rajdhani','Segoe UI',sans-serif;font-weight:800;font-size:23px;letter-spacing:1.2px;color:#fff;
  text-shadow:0 1px 3px rgba(90,0,0,.6);white-space:nowrap;
  opacity:0;transform:translateY(-70px);transition:transform .42s cubic-bezier(.2,.9,.3,1),opacity .3s ease}
#combat.show{opacity:1;transform:translateY(0)}
/* ---- placement control hints (bottom-left, above the minimap) ---- */
#phints,#chints{position:fixed;left:16px;bottom:300px;display:none;flex-direction:column;align-items:flex-start;gap:6px;pointer-events:none;z-index:40}
#phints.show,#chints.show{display:flex}
.ph{display:flex;align-items:center;gap:6px;padding:3px 11px 3px 5px;border-radius:15px;
  background:linear-gradient(180deg,#343530 0%,#2b2c28 100%);border:1px solid #4d4e48;box-shadow:0 0 0 2px #000,0 5px 13px rgba(0,0,0,.45);
  font-family:'Rajdhani','Segoe UI',sans-serif;font-weight:600;font-size:13px;color:#e7e9ee;letter-spacing:.3px;transition:background .1s,border-color .1s}
.ph.flash,.ph.hold{background:#2f6fd6;border-color:#5a97ec}
.ph .ico{flex:0 0 20px;display:flex;align-items:center;justify-content:center}
.mkey{position:relative;width:14px;height:20px;border:2px solid #d3d6db;border-radius:7px 7px 6px 6px}
.mkey::before{content:'';position:absolute;left:50%;top:2px;width:2px;height:6px;background:#d3d6db;transform:translateX(-50%)}
.mkey.l::after{content:'';position:absolute;left:2px;top:2px;width:4px;height:6px;background:#d3d6db;border-radius:4px 0 0 0}
.mkey.r::after{content:'';position:absolute;right:2px;top:2px;width:4px;height:6px;background:#d3d6db;border-radius:0 4px 0 0}
.kkey{min-width:20px;height:20px;padding:0 4px;border:2px solid #d3d6db;border-radius:5px;display:flex;align-items:center;justify-content:center;font-family:'Rajdhani',sans-serif;font-weight:700;font-size:13px;color:#e7e9ee}
/* barge F/G live in this same stack, so a transport's controls read exactly like X Stop and W Cancel */
#ch_f,#ch_g{display:none}
#ch_msg{display:none;padding:6px 17px;font-weight:700}
</style></head><body>
<div id="combat">WE ARE IN COMBAT</div>
<div id="band" class="__BCLS__">
  <div id="hdr"><img src="]==] .. AST .. [==[game/me_home.png">BUILD MENU</div>
  <div id="scroll">__SLOTS__</div>
</div>
<div id="buildBtn"><img src="]==] .. AST .. [==[game/me_build.png">BUILD <span class="k">[B]</span></div>
<div id="tip"><div class="box">
  <div class="t" id="tipT"></div><div class="d" id="tipD"></div>
  <div class="row">
    <div class="stat"><img src="]==] .. AST .. [==[game/me_coin.png"><span id="tipP"></span></div>
    <div class="stat cnt"><img src="]==] .. AST .. [==[game/me_house.png"><span id="tipM"></span></div>
  </div>
</div></div>
<div id="binfo" class="card">
  <div id="tspawn"></div>
  <div id="tprod"><div id="tprodList"></div></div>
  <div class="t" id="biName"></div>
  <div class="d" id="biDesc"></div>
  <div class="btn red" id="biDestroy">DESTROY</div>
  <div id="biTrash"><img id="biTrashImg"></div>
</div>
<div id="cinfo" class="card">
  <div id="cstip"><div class="box"><div class="t" id="cstipT"></div><div class="d" id="cstipD"></div></div></div>
  <div id="cspawn"><div class="cs-title">Builder</div><div class="cs-imgbox"><img class="cs-img" id="csImg"></div><div class="cs-row"><img src="]==] .. AST .. [==[game/me_pop.png"><span>1</span></div><div class="cs-row"><img src="]==] .. AST .. [==[game/me_coin.png"><span class="p" id="csPrice">200</span></div></div>
  <div id="uprod"><div id="uprodList"></div></div>
  <div class="t" id="ciName"></div>
  <div class="d" id="ciDesc"></div>
  <div class="btn off" id="ciForfeit">FORFEIT</div>
</div>
<div id="phints">
  <div class="ph" id="ph_lmb"><span class="ico"><span class="mkey l"></span></span>Place</div>
  <div class="ph" id="ph_r"><span class="ico"><span class="kkey">R</span></span>Rotate</div>
  <div class="ph" id="ph_w"><span class="ico"><span class="kkey">W</span></span>Cancel</div>
</div>
<div id="chints">
  <div class="ph" id="ch_msg"></div>
  <div class="ph" id="ch_g"><span class="ico"><span class="kkey">G</span></span>Unload troops</div>
  <div class="ph" id="ch_f"><span class="ico"><span class="kkey">F</span></span><span id="ch_ftxt">Load troops</span></div>
  <div class="ph" id="ch_x"><span class="ico"><span class="kkey">X</span></span>Stop</div>
  <div class="ph" id="ch_w"><span class="ico"><span class="kkey">W</span></span>Cancel</div>
</div>
<script>
var DATA=__DATA__;var ZOOM=__ZOOM__;var MONEY=0;var COUNTS={};var curId=null;var HBONUS=0;
function $(id){return document.getElementById(id)}
function comma(n){return (n+'').replace(/\B(?=(\d{3})+(?!\d))/g,',')}
var tip=$('tip');
/* effective limit: destroying an enemy core unlocks +4 extra HOUSE build slots (HBONUS) */
function effMax(b,id){return (b.max>0&&id==='house')?(b.max+HBONUS):b.max;}
function countText(b,id){var c=COUNTS[id]||0;var m=effMax(b,id);return m>0?(c+'/'+m):(''+c);}
function refreshNums(id){var b=DATA[id];if(!b)return;
  $('tipP').textContent=comma(b.price||0);$('tipP').style.color=(MONEY<b.price)?'#e0483a':'#f5cd46';
  var c=COUNTS[id]||0;var m=effMax(b,id);
  $('tipM').textContent=countText(b,id);
  $('tipM').style.color=(m>0&&c>=m)?'#e0483a':'#eef0f3';}  /* red once the limit is reached */
function showTip(slot){var id=slot.getAttribute('data-id');var b=DATA[id];if(!b)return;curId=id;
  $('tipT').textContent=b.name;$('tipD').textContent=b.desc;refreshNums(id);
  var r=slot.getBoundingClientRect();tip.style.top=((r.top+r.height/2)/ZOOM-tip.offsetHeight/2)+'px';tip.style.opacity=1;}
function hideTip(){tip.style.opacity=0;curId=null;}
function setBand(open){var bd=$('band');if(bd)bd.classList.toggle('closed',!open);if(!open)hideTip();}
function updateState(s){MONEY=s.money||0;COUNTS=s.counts||{};HBONUS=s.houseBonus||0;
  var sl=document.querySelectorAll('.slot');
  for(var i=0;i<sl.length;i++){var id=sl[i].getAttribute('data-id');var b=DATA[id];if(!b)continue;
    var c=COUNTS[id]||0;var m=effMax(b,id);var maxed=(m>0&&c>=m);
    sl[i].classList.toggle('maxed',maxed);
    sl[i].classList.toggle('broke',!maxed&&MONEY<b.price);}
  var cs=$('cspawn');if(cs)cs.classList.toggle('broke',MONEY<UPRICE);   /* builder unaffordable -> black */
  if(window.trainBroke)trainBroke();   /* training cards go black when unaffordable, live with money */
  if(curId)refreshNums(curId);}
var slots=document.querySelectorAll('.slot');
for(var i=0;i<slots.length;i++){(function(s){
  s.onmouseenter=function(){showTip(s)};s.onmouseleave=hideTip;
  s.onclick=function(){if(s.classList.contains('maxed'))return;try{mebuild.select(s.getAttribute('data-id'))}catch(e){}};
})(slots[i]);}
$('buildBtn').onclick=function(){try{mebuild.build()}catch(e){}};
function setHints(on){var h=$('phints');if(h){h.classList.toggle('show',!!on);if(!on){var e=h.getElementsByClassName('hold');while(e.length)e[0].classList.remove('hold');}}}
function holdHint(id,on){var el=$('ph_'+id);if(el)el.classList.toggle('hold',!!on)}
function setCardHint(on,hasSel){var h=$('chints');if(h)h.classList.toggle('show',!!on);
  var x=$('ch_x');if(x)x.style.display=hasSel?'flex':'none';}   /* X Stop only for a unit selection */
function flashChint(id){var el=$('ch_'+id);if(!el)return;el.classList.add('flash');setTimeout(function(){el.classList.remove('flash')},220)}
/* barge controls: F is shown for any selected transport, G only while it actually has someone aboard */
function setBargeHint(f,g,ftxt){
  var e=$('ch_f');if(e){e.style.display=f?'flex':'none';var t=$('ch_ftxt');if(t&&ftxt)t.textContent=ftxt;}
  var h=$('ch_g');if(h)h.style.display=g?'flex':'none';}
function setBargeMsg(txt,good){var m=$('ch_msg');if(!m)return;
  if(!txt){m.style.display='none';m.textContent='';return;}
  m.textContent=txt;m.style.color=good?'#9ce39c':'#f2988d';m.style.display='flex';}
var combatT=null;
function showCombat(){var c=$('combat');if(!c)return;c.classList.add('show');
  if(combatT)clearTimeout(combatT);combatT=setTimeout(function(){c.classList.remove('show');},5000);}
/* ---- exact geometry. Every floating piece is sized and centred from the LIVE layout, never from a magic
   number: the unit row must span exactly the same width as the card under it whatever the number of units
   the building trains (4 soldiers, 4 vehicles, 2 ships...), and the trash square must be exactly as tall
   as the card it hangs off. These same measured rectangles are what Lua uses as the click zones. ---- */
function clearTrainWidth(){var c=$('binfo');c.style.width='';c.style.minWidth='';c.style.maxWidth='';var sp=$('tspawn');if(sp)sp._w=0;}
function layoutTrain(){
  var sp=$('tspawn');if(!sp||!sp.classList.contains('show')||!sp.children.length)return;
  var w=sp.offsetWidth;if(!w||sp._w===w)return;   /* only write when it actually changed: this runs on a tick */
  sp._w=w;
  sp.style.marginLeft=(-w/2)+'px';   /* centred by measurement (a transform makes CEF mis-map the clicks) */
  var c=$('binfo');c.style.width=w+'px';c.style.minWidth=w+'px';c.style.maxWidth=w+'px';
}
/* the queue band spans the WHOLE block: its top sits on the top edge of the unit-card row, its bottom is
   flush with the bottom of the DESTROY card. Pinning both edges (instead of setting a height) makes the
   span exact whatever the card grows to, and the slots then divide the measured result. */
function layoutTrainQueue(){
  var sp=$('tspawn'),band=$('tprod'),list=$('tprodList'),card=$('binfo');
  if(!sp||!band||!list||!card||!sp.classList.contains('show')||!sp.children.length)return;
  var h=sp.offsetHeight;if(!h)return;
  var ch=card.clientHeight;
  if(band._h===h&&band._c===ch&&band._n===list.children.length)return;   /* only write on a real change: this runs on a tick */
  band._h=h;band._c=ch;band._n=list.children.length;
  band.style.height='';band.style.bottom='0px';band.style.top=(-(h+13))+'px';   /* 13 = the row's gap above the card */
  var total=band.offsetHeight;
  var GAP=6,pad=16;
  var sq=Math.max(20,Math.min(64,Math.floor((Math.max(28,total-pad)-(TQ_MAX-1)*GAP)/TQ_MAX)));
  band.style.width=(sq+16)+'px';
  for(var i=0;i<list.children.length;i++){
    var s=list.children[i];
    s.style.width=sq+'px';s.style.height=sq+'px';s.style.marginTop=(i===0?0:GAP)+'px';
  }
}
function layoutCard(){
  layoutTrain();
  layoutTrainQueue();
  var tr=$('biTrash');
  if(tr&&tr.classList.contains('show')){
    var h=$('binfo').offsetHeight;
    if(h>0&&tr._h!==h){tr._h=h;tr.style.width=h+'px';}   /* square: as wide as the card is tall */
  }
}
function showBInfo(d){
  $('biName').textContent=d.name||'';$('biDesc').textContent=d.desc||'';
  $('biDesc').style.display=(d.desc&&d.desc.length)?'block':'none';
  var db=$('biDestroy');
  db.style.display=d.destroyable?'flex':'none';
  /* a blueprint is CANCELLED, not destroyed -- nothing stands there yet. Re-setting the text also
     disarms a half-armed button when the card changes to a different structure. */
  db._base=d.destroyLabel||'DESTROY';
  db.classList.remove('armed');
  db.textContent=db._base;
  var tr=$('biTrash');
  if(d.trash){ tr.classList.remove('armed'); tr.classList.add('show'); $('biTrashImg').src=TRASHICON; }
  else { tr.classList.remove('show'); tr.classList.remove('armed'); }
  if(!d.train)hideTrain();   // training buildings re-show it right after via showTrain()
  $('binfo').classList.toggle('wide',!!d.train);   // widen to span the unit slots for a training camp
  if(!d.train)clearTrainWidth();
  $('cinfo').classList.remove('show');
  $('binfo').classList.add('show');
  layoutCard();
}
function hideBInfo(){$('binfo').classList.remove('show');hideTrain();var tr=$('biTrash');if(tr){tr.classList.remove('show');tr.classList.remove('armed');}}
// double-click confirm: first click arms (shows CONFIRM), second within 2.5s fires
/* the label lives on the element (_base) rather than in this closure, so the card can switch it
   between DESTROY and CANCEL depending on whether the structure is up yet */
function armBtn(el,base,fn){el._base=base;var armed=false,t=null;el.onclick=function(){
  if(el._gate&&!el._gate())return;
  if(armed){armed=false;clearTimeout(t);el.classList.remove('armed');el.textContent=el._base;fn();return;}
  armed=true;el.textContent='CONFIRM';el.classList.add('armed');
  t=setTimeout(function(){armed=false;el.classList.remove('armed');el.textContent=el._base;},2500);};}
armBtn($('biDestroy'),'DESTROY',function(){try{mebuild.destroy()}catch(e){}});
/* unit trash square: first click arms (turns white), second within 2.5s deletes the selected unit(s) */
(function(){var tr=$('biTrash');if(!tr)return;var armed=false,t=null;
  tr.onclick=function(){
    if(armed){armed=false;clearTimeout(t);tr.classList.remove('armed');try{mebuild.deleteUnits()}catch(e){}return;}
    armed=true;tr.classList.add('armed');
    t=setTimeout(function(){armed=false;tr.classList.remove('armed');},2500);};})();

function showCInfo(d){
  $('ciName').textContent=d.name||'';$('ciDesc').textContent=d.desc||'';
  updCInfo(d.unlocked);
  $('csImg').src=d.builderIcon||'';$('csPrice').textContent=comma(d.builderPrice||200);
  UPRICE=d.builderPrice||200;UQICON=d.builderIcon||'';renderUnitQueue();
  var cs=$('cspawn');if(cs)cs.classList.toggle('broke',MONEY<UPRICE);
  $('binfo').classList.remove('show');
  $('cinfo').classList.add('show');
}
/* ---- unit production queue: n squares stacked, front one builds with a blue bottom-to-top fill ---- */
var UQ={n:0,dur:0,start:0};var UQICON='';var UPRICE=200;
var TRASHICON='asset://garrysmod/materials/mergeempires/game/me_trash.png';
var UQ_MAX=3;   /* the core queue holds 3; we show all 3 as capacity slots (filled + empty) */
/* size the slots so all 4 fit inside the core card height, evenly spaced, no overlap */
function layoutUnitQueue(){
  var list=$('uprodList');if(!list||!list.children.length)return;
  var card=$('cinfo');var cardH=(card&&card.clientHeight)?card.clientHeight:180;
  var GAP=6, pad=16;
  var sq=Math.max(30,Math.min(56,Math.floor((Math.max(40,cardH-pad)-(UQ_MAX-1)*GAP)/UQ_MAX)));
  var band=$('uprod');if(band)band.style.width=(sq+16)+'px';
  for(var i=0;i<list.children.length;i++){var s=list.children[i];
    s.style.width=sq+'px';s.style.height=sq+'px';s.style.marginTop=(i===0?0:GAP)+'px';
  }
}
function renderUnitQueue(){
  var list=$('uprodList');if(!list)return;
  if(list.getAttribute('data-n')!==(''+UQ.n)){
    list.setAttribute('data-n',''+UQ.n);
    list.innerHTML='';
    for(var i=0;i<UQ_MAX;i++){
      var filled=i<UQ.n;
      var s=document.createElement('div');
      s.className='uslot'+(filled?(i>0?' pending':''):' empty');
      var f=document.createElement('div');f.className='fill';s.appendChild(f);
      if(filled){
        var im=document.createElement('img');im.src=UQICON;s.appendChild(im);
        var tr=document.createElement('div');tr.className='utrash';
        var ti=document.createElement('img');ti.src=TRASHICON;tr.appendChild(ti);
        (function(idx){tr.onclick=function(e){if(e&&e.stopPropagation)e.stopPropagation();try{mebuild.dequeue(idx+1)}catch(err){}};})(i);
        s.appendChild(tr);
      }
      list.appendChild(s);
    }
    layoutUnitQueue();
  }
  var el=$('uprod');if(el)el.classList.add('show');   /* shown whenever the core card is open */
}
function setUnitQueue(n,dur,elapsed){
  UQ.n=n;UQ.dur=dur;UQ.start=(Date.now()/1000)-(elapsed||0);
  renderUnitQueue();
}
function uqTick(){
  var list=$('uprodList');if(!list||!UQ.n)return;
  var frac=UQ.dur>0?Math.min(1,Math.max(0,(Date.now()/1000-UQ.start)/UQ.dur)):0;
  var first=list.children[0];if(first){var fl=first.getElementsByClassName('fill')[0];if(fl)fl.style.height=(frac*100)+'%';}
}
setInterval(uqTick,50);
/* ---- TRAINING CAMP: a row of unit cards above the info card + a queue band on the right ---- */
var POPICON='asset://garrysmod/materials/mergeempires/game/me_pop.png';
var COINICON='asset://garrysmod/materials/mergeempires/game/me_coin.png';
var TICON={};var TBIDX=0;var TQ={bidx:0,kinds:[],dur:0,start:0};var TQ_MAX=5;
function trainBroke(){var sp=$('tspawn');for(var i=0;i<sp.children.length;i++){var c=sp.children[i];c.classList.toggle('broke',MONEY<c._price);}}
function showTrain(d){
  TBIDX=d.bidx;TICON={};
  var sp=$('tspawn');sp.innerHTML='';
  (d.units||[]).forEach(function(u){
    TICON[u.kind]=u.icon||'';
    var c=document.createElement('div');c.className='tcard';c._price=u.price;
    c.innerHTML='<div class="cs-title">'+u.name+'</div>'
      +'<div class="cs-imgbox"><img class="cs-img" src="'+(u.icon||'')+'"></div>'
      +'<div class="cs-row"><img src="'+POPICON+'"><span>'+u.pop+'</span></div>'
      +'<div class="cs-row"><img src="'+COINICON+'"><span class="p">'+comma(u.price)+'</span></div>';
    (function(kind,price){c.onclick=function(){if(MONEY<price)return;try{mebuild.trainunit(TBIDX,kind)}catch(e){}};})(u.kind,u.price);
    sp.appendChild(c);
  });
  trainBroke();
  sp.classList.add('show');$('tprod').classList.add('show');
  layoutCard();   // the row now has its real cards: centre it and match the card width to it
}
function hideTrain(){$('tspawn').classList.remove('show');$('tprod').classList.remove('show');clearTrainWidth();}
function renderTrainQueue(){
  var list=$('tprodList');if(!list)return;var sig=TQ.kinds.join(',');
  if(list.getAttribute('data-sig')!==sig){
    list.setAttribute('data-sig',sig);list.innerHTML='';
    var bd=$('tprod');if(bd)bd._h=0;   /* fresh slot elements carry no inline size: force a re-fit below */
    for(var i=0;i<TQ_MAX;i++){
      var filled=i<TQ.kinds.length;
      var s=document.createElement('div');s.className='uslot'+(filled?(i>0?' pending':''):' empty');
      var f=document.createElement('div');f.className='fill';s.appendChild(f);
      if(filled){
        var im=document.createElement('img');im.src=TICON[TQ.kinds[i]]||'';s.appendChild(im);
        var tr=document.createElement('div');tr.className='utrash';var ti=document.createElement('img');ti.src=TRASHICON;tr.appendChild(ti);
        (function(idx){tr.onclick=function(e){if(e&&e.stopPropagation)e.stopPropagation();try{mebuild.traindequeue(TQ.bidx,idx+1)}catch(err){}};})(i);
        s.appendChild(tr);
      }
      list.appendChild(s);
    }
    layoutTrainQueue();   // fresh slots: re-fit them to the card row's height
  }
}
function setTrainQueue(bidx,kindsCsv,dur,elapsed){
  TQ.bidx=bidx;TQ.kinds=kindsCsv?kindsCsv.split(','):[];TQ.dur=dur;TQ.start=(Date.now()/1000)-(elapsed||0);
  renderTrainQueue();$('tprod').classList.add('show');
}
function tqTick(){var list=$('tprodList');if(!list||!TQ.kinds.length)return;var frac=TQ.dur>0?Math.min(1,Math.max(0,(Date.now()/1000-TQ.start)/TQ.dur)):0;var first=list.children[0];if(first){var fl=first.getElementsByClassName('fill')[0];if(fl)fl.style.height=(frac*100)+'%';}}
setInterval(tqTick,50);
function updCInfo(unlocked){
  var b=$('ciForfeit');
  b.classList.toggle('red',!!unlocked);   // unlocked after 15 min on your own core
  b.classList.toggle('off',!unlocked);
}
function hideCInfo(){$('cinfo').classList.remove('show');$('cstip').classList.remove('show');}
var _cf=$('ciForfeit');_cf._gate=function(){return _cf.classList.contains('red');};
armBtn(_cf,'FORFEIT',function(){try{mebuild.forfeit()}catch(e){}});
$('cspawn').onclick=function(){
  if(UQ.n>=4)return;              /* max 4 in the core queue — silently ignored */
  if(MONEY<UPRICE)return;         /* unaffordable (card shows black) — silently ignored */
  try{mebuild.spawnunit('builder')}catch(e){}
};
$('cspawn').onmouseenter=function(){$('cstipT').textContent='Builder';$('cstipD').textContent='A civilian that constructs and repairs buildings.';$('cstip').classList.add('show');};
$('cspawn').onmouseleave=function(){$('cstip').classList.remove('show');};
/* ---- CLICK ZONES. Lua lets the panel eat the mouse only over the pixels an interactive element really
   covers, so everything else keeps reaching the game. The rects are read straight off the live layout with
   getBoundingClientRect (already screen pixels, zoom included), which makes the clickable area and the
   drawn overlay the exact same rectangle — a hand-tuned box always ends up either clipping a button or
   swallowing the board around it. ---- */
var HITSEL=['#buildBtn','#band','#binfo','#biTrash','#tspawn','#tprod','#cinfo','#cspawn','#uprod'];
function elLive(el){
  if(window.getComputedStyle(el).pointerEvents==='none')return false;
  for(var p=el;p&&p!==document.body;p=p.parentElement){
    var cs=window.getComputedStyle(p);
    if(cs.display==='none'||cs.visibility==='hidden')return false;
    if(parseFloat(cs.opacity||'1')<0.06)return false;
    /* a hidden card keeps its children laid out: they are only clickable once the card is shown */
    if(p.classList&&p.classList.contains('card')&&!p.classList.contains('show'))return false;
  }
  return true;
}
function hitZones(){
  var out=[];
  for(var i=0;i<HITSEL.length;i++){
    var el=document.querySelector(HITSEL[i]);if(!el||!elLive(el))continue;
    var r=el.getBoundingClientRect();
    if(r.width<1||r.height<1)continue;
    out.push([Math.floor(r.left),Math.floor(r.top),Math.ceil(r.width),Math.ceil(r.height)]);
  }
  return out;
}
var lastZones='';
setInterval(function(){
  layoutCard();
  var s=JSON.stringify(hitZones());
  if(s===lastZones)return;lastZones=s;
  try{mebuild.hitzones(s)}catch(e){}
},50);
</script></body></html>
]==]
	return (HTML:gsub("__ZOOM__", zoom)
	            :gsub("__BCLS__", function() return B.open and "" or "closed" end)
	            :gsub("__SLOTS__", function() return buildSlotsHTML() end)
	            :gsub("__DATA__", function() return buildDataJSON() end))
end

local function pushState()
	if not IsValid(B.dhtml) then return end
	local ply = LocalPlayer()
	local money = IsValid(ply) and ply:GetNWInt("ME_Money", 0) or 0

	local counts, myTeam = {}, IsValid(ply) and ply:Team() or 0
	if ME.BuildingModels then
		for _, rec in pairs(ME.BuildingModels) do
			if rec.faction == myTeam and rec.bid then counts[rec.bid] = (counts[rec.bid] or 0) + 1 end
		end
	end
	local hb = IsValid(ply) and ply:GetNWInt("ME_HouseBonus", 0) or 0
	B.dhtml:Call("if(window.updateState)updateState(" .. util.TableToJSON({ money = money, counts = counts, houseBonus = hb }) .. ")")
end

local function ensurePanel()
	if IsValid(B.dhtml) then return end
	if not IsValid(ME.Panel) then return end
	B.dhtml = vgui.Create("DHTML", ME.Panel)
	B.dhtml:SetSize(ScrW(), ScrH())
	B.dhtml:SetPos(0, 0)
	B.dhtml:SetMouseInputEnabled(false)
	B.dhtml:SetKeyboardInputEnabled(false)
	B.dhtml:SetAllowLua(false)
	B.dhtml:AddFunction("mebuild", "select", function(id)
		if ME.Sfx then ME.Sfx.Play2D("ui_click") end
		B.Select(ME.GetBuilding and ME.GetBuilding(id))
	end)
	B.dhtml:AddFunction("mebuild", "build", function() B.Toggle() end)
	B.dhtml:AddFunction("mebuild", "destroy", function() B.Destroy() end)
	B.dhtml:AddFunction("mebuild", "deleteUnits", function() B.DeleteUnits() end)
	B.dhtml:AddFunction("mebuild", "trainunit", function(bidx, kind) B.TrainUnit(bidx, kind) end)
	B.dhtml:AddFunction("mebuild", "traindequeue", function(bidx, i) B.TrainDequeue(bidx, i) end)
	B.dhtml:AddFunction("mebuild", "forfeit", function() B.Forfeit() end)
	B.dhtml:AddFunction("mebuild", "spawnunit", function(kind) B.SpawnUnit(kind) end)
	B.dhtml:AddFunction("mebuild", "dequeue", function(i) B.Dequeue(i) end)

	B.dhtml:AddFunction("mebuild", "hitzones", function(json)
		local t = util.JSONToTable(tostring(json or ""))
		if istable(t) then B.hit = t end
	end)
	B.hit = nil
	B.dhtml:SetHTML(buildHTML())
	B.dhtml.OnMouseWheeled = function(_, d)
		if IsValid(B.dhtml) then B.dhtml:Call("var s=document.getElementById('scroll');if(s)s.scrollTop-=" .. tostring(d * 64) .. ";") end
		return true
	end
	timer.Simple(0.25, pushState)
	B._infoKey, B._infoShown = nil, false
	B.overUI = false
end

local function removePanel()
	if IsValid(B.dhtml) then B.dhtml:Remove() end
	B.dhtml, B.hit = nil, nil
end

B.open = true
function B.Toggle()
	B.open = not B.open
	if IsValid(B.dhtml) then B.dhtml:Call("if(window.setBand)setBand(" .. (B.open and "true" or "false") .. ")") end
end

function B.Select(bld)
	B.selected = bld
	if B.StartPlace then B.StartPlace(bld) end
end

B.overUI = false
hook.Add("Think", "ME_BuildMouse", function()
	if gui.IsGameUIVisible() then
		if B.overUI and IsValid(B.dhtml) then B.overUI = false; B.dhtml:SetMouseInputEnabled(false) end
		return
	end
	if not IsValid(B.dhtml) then return end
	local mx, my = gui.MousePos()
	local over = false
	if B.hit then
		for _, r in ipairs(B.hit) do
			if mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4] then over = true break end
		end
	else
		local bw = S(232)
		local inX = mx >= ScrW() - S(14) - bw and mx <= ScrW() - S(14)
		over = inX and my >= ScrH() - S(64) and my <= ScrH() - S(14)
		if not over and B.open then over = inX and my >= ScrH() - S(572) and my <= ScrH() - S(72) end
	end
	if over ~= B.overUI then
	if over and ME.Sfx then ME.Sfx.Play2D("ui_hover") end
		B.overUI = over
		B.dhtml:SetMouseInputEnabled(over)

		if over then
			if not (ME.Chat and ME.Chat.typing) then B.dhtml:MoveToFront() end
		else
			B.dhtml:Call("if(window.hideTip)hideTip()")
		end
	end
end)

local nextState = 0
hook.Add("Think", "ME_BuildState", function()
	if not IsValid(B.dhtml) then return end
	if CurTime() < nextState then return end
	nextState = CurTime() + 0.3
	pushState()
end)

local bWas = false
hook.Add("Think", "ME_BuildKeyWatch", function()
	if not (ME.InGame and ME.InGame()) then bWas = false return end
	local down = input.IsKeyDown(KEY_B)
	if down and not bWas and not (ME.Chat and ME.Chat.typing) and not gui.IsConsoleVisible() then
		if B.IsPlacing and B.IsPlacing() then B.StopPlace() else B.Toggle() end
	end
	bWas = down
end)

function B.ShowInfo(d)
	if IsValid(B.dhtml) then B.dhtml:Call("if(window.showBInfo)showBInfo(" .. util.TableToJSON(d) .. ")") end
	B._infoShown = true
end

function B.ShowCombat()
	if IsValid(B.dhtml) then B.dhtml:Call("if(window.showCombat)showCombat()") end
end
function B.HideInfo()
	if IsValid(B.dhtml) then B.dhtml:Call("if(window.hideBInfo)hideBInfo()") end
	B._infoShown = false
end
function B.Destroy()
	local ins = ME.Cam and ME.Cam.inspect
	if not (ins and ins.kind == "building" and ins.idx) then return end
	net.Start("ME_DestroyBuilding"); net.WriteUInt(ins.idx, 16); net.SendToServer()
	ME.Cam.inspect = nil
end

B.trainQ = B.trainQ or {}
function B.TrainUnit(bidx, kind)
	bidx = math.floor(tonumber(bidx) or 0); if bidx < 1 or not kind then return end
	if ME.Sfx then ME.Sfx.Play2D("build_sold") end
	net.Start("ME_TrainUnit"); net.WriteUInt(bidx, 16); net.WriteString(kind); net.SendToServer()
end
function B.TrainDequeue(bidx, i)
	bidx = math.floor(tonumber(bidx) or 0); i = math.floor(tonumber(i) or 0)
	if bidx < 1 or i < 1 then return end
	net.Start("ME_TrainDequeue"); net.WriteUInt(bidx, 16); net.WriteUInt(i, 6); net.SendToServer()
end
function B.ShowTrain(d)
	if IsValid(B.dhtml) then B.dhtml:Call("if(window.showTrain)showTrain(" .. util.TableToJSON(d) .. ")") end
end

function B.PushTrain(bidx)
	if not IsValid(B.dhtml) then return end
	local q = B.trainQ[bidx]
	local kinds = (q and table.concat(q.kinds or {}, ",")) or ""
	local dur   = (q and q.dur) or 0
	local elapsed = 0
	if q and #(q.kinds or {}) > 0 and (q.start or 0) > 0 and dur > 0 then
		elapsed = math.Clamp(CurTime() - q.start, 0, dur)
	end
	B.dhtml:Call(string.format("if(window.setTrainQueue)setTrainQueue(%d,%q,%s,%s)",
		bidx, kinds, string.format("%.3f", dur), string.format("%.3f", elapsed)))
end
net.Receive("ME_TrainQueue", function()
	local bidx = net.ReadUInt(16)
	local n    = net.ReadUInt(6)
	local kinds = {}
	for i = 1, n do kinds[i] = net.ReadString() end
	local dur, start = net.ReadFloat(), net.ReadFloat()
	B.trainQ[bidx] = { kinds = kinds, dur = dur, start = start }
	local ins = ME.Cam and ME.Cam.inspect
	if ins and ins.kind == "building" and ins.idx == bidx then B.PushTrain(bidx) end
end)

function B.DeleteUnits()
	local sel = ME.Cam and ME.Cam.selected
	if not (sel and #sel > 0) then return end
	local ids = {}
	for _, u in ipairs(sel) do if IsValid(u) and u.MEUnit then ids[#ids + 1] = u:EntIndex() end end
	if #ids == 0 then return end
	net.Start("ME_DeleteUnits")
	net.WriteUInt(#ids, 9)
	for _, id in ipairs(ids) do net.WriteUInt(id, 16) end
	net.SendToServer()
	ME.Cam.selected = {}
end
function B.Forfeit()
	net.Start("ME_Forfeit"); net.SendToServer()
end
function B.SpawnUnit(kind)
	if ME.Sfx then ME.Sfx.Play2D("build_sold") end
	net.Start("ME_SpawnUnit"); net.WriteString(kind or "builder"); net.SendToServer()
end
function B.Dequeue(i)
	i = math.floor(tonumber(i) or 0)
	if i < 1 then return end
	net.Start("ME_UnitDequeue"); net.WriteUInt(i, 6); net.SendToServer()
end
function B.ShowCore(d)
	if IsValid(B.dhtml) then B.dhtml:Call("if(window.showCInfo)showCInfo(" .. util.TableToJSON(d) .. ")") end
	B._coreShown = true
	B.PushProd()
end

B.prod = B.prod or { n = 0, dur = 0, start = 0 }
function B.PushProd()
	if not IsValid(B.dhtml) then return end
	local p = B.prod

	local elapsed = 0
	if (p.n or 0) > 0 and (p.start or 0) > 0 and (p.dur or 0) > 0 then
		elapsed = math.Clamp(CurTime() - p.start, 0, p.dur)
	end
	B.dhtml:Call(string.format("if(window.setUnitQueue)setUnitQueue(%d,%s,%s)",
		p.n or 0, string.format("%.3f", p.dur or 0), string.format("%.3f", elapsed)))
end

net.Receive("ME_UnitQueue", function()
	local n     = net.ReadUInt(6)
	local dur   = net.ReadFloat()
	local start = net.ReadFloat()
	B.prod = { n = n, dur = dur, start = start }
	B.PushProd()
end)
function B.UpdCore(unlocked)
	if IsValid(B.dhtml) then B.dhtml:Call("if(window.updCInfo)updCInfo(" .. (unlocked and "true" or "false") .. ")") end
end
function B.HideCore()
	if IsValid(B.dhtml) then B.dhtml:Call("if(window.hideCInfo)hideCInfo()") end
	B._coreShown = false
end

hook.Add("Think", "ME_BuildInfoWatch", function()
	if not IsValid(B.dhtml) then return end
	local ins = ME.Cam and ME.Cam.inspect

	local sel = ME.Cam and ME.Cam.selected
	if sel and #sel > 0 then
		local counts, order, total = {}, {}, 0
		for _, e in ipairs(sel) do
			if IsValid(e) and e.MEUnit then
				local kk = (e.GetUKind and e:GetUKind()) or "builder"
				if not counts[kk] then counts[kk] = 0; order[#order + 1] = kk end
				counts[kk] = counts[kk] + 1; total = total + 1
			end
		end
		if total > 0 then
			if B._coreShown then B.HideCore(); B._coreKey = nil end
			local name, desc, keyparts = nil, nil, {}
			if #order == 1 then
				local kk = order[1]; local k = ME.GetUnitKind and ME.GetUnitKind(kk); local n = counts[kk]
				name = (n > 1) and (n .. " " .. ((k and k.name) or "Unit") .. "s") or ((k and k.name) or "Unit")
				desc = (n > 1) and "" or ((k and k.desc) or "")
				keyparts[1] = kk .. n
			else
				name = total .. " units"
				local parts = {}
				for _, kk in ipairs(order) do
					local k = ME.GetUnitKind and ME.GetUnitKind(kk)
					parts[#parts + 1] = counts[kk] .. " " .. ((k and k.name) or kk) .. (counts[kk] > 1 and "s" or "")
					keyparts[#keyparts + 1] = kk .. counts[kk]
				end
				desc = table.concat(parts, "   •   ")
			end
			local key = "u|" .. table.concat(keyparts, ",")
			if key ~= B._infoKey then
				B._infoKey = key
				B.ShowInfo({ name = name, desc = desc, destroyable = false, trash = true })
			end
			return
		end
	end

	if ins and ins.kind == "core" and ins.faction then
		if B._infoShown then B.HideInfo(); B._infoKey = nil end
		local fac      = ins.faction
		local own      = fac == LocalPlayer():Team()
		local unlocked = own and (CurTime() - GetGlobalFloat("ME_MatchStartAt", CurTime())) >= 15 * 60
		local key      = "c" .. fac
		if key ~= B._coreKey then
			B._coreKey, B._coreUnlk = key, unlocked
			local bk = (ME.GetUnitKind and ME.GetUnitKind("builder")) or { cost = 200 }
			B.ShowCore({
				name = "Core",
				desc = "Your most important structure. You lose the game if destroyed!",
				unlocked = unlocked,
				builderIcon  = skinIconSrc("u_builder", "unit_builder") or "",
				builderPrice = bk.cost or 200,
			})
		elseif unlocked ~= B._coreUnlk then
			B._coreUnlk = unlocked
			B.UpdCore(unlocked)
		end
		return
	end
	if B._coreShown then B.HideCore(); B._coreKey = nil end

	if not (ins and ins.kind == "building") then
		if B._infoShown then B.HideInfo(); B._infoKey = nil end
		return
	end
	local rec = ins.idx and ME.BuildingModels and ME.BuildingModels[ins.idx]
	local cfg = rec and ME.GetBuilding and ME.GetBuilding(rec.bid)
	if not cfg then
		if B._infoShown then B.HideInfo(); B._infoKey = nil end
		return
	end
	local ent = Entity(ins.idx)
	local fac = rec.faction
	if not fac or fac == 0 then fac = IsValid(ent) and ent:GetNWInt("MEFaction", -1) or -1 end
	local destroyable = fac == LocalPlayer():Team()

	local produces = rec.built and destroyable and ME.BuildingUnits and ME.BuildingUnits(rec.bid)

	local key = "b" .. ins.idx .. (rec.built and "B" or "b") .. (produces and "T" or "")
	if key ~= B._infoKey or destroyable ~= B._infoOwn then
		B._infoKey, B._infoOwn = key, destroyable
		B.ShowInfo({ name = cfg.name, desc = cfg.desc, destroyable = destroyable,
			destroyLabel = rec.built and "DESTROY" or "CANCEL", train = produces and true or false })
		if produces then
			local units = {}
			for _, kk in ipairs(produces) do
				local k = ME.GetUnitKind(kk)
				units[#units + 1] = { kind = kk, name = k.short or k.name or kk, icon = skinIconSrc("u_" .. kk, "unit_" .. kk) or "", pop = k.pop or 1, price = k.cost or 0 }
			end
			B.ShowTrain({ bidx = ins.idx, units = units })
			B.PushTrain(ins.idx)
		end
	end
end)

local bkWas, wWas, xWas = false, false, false
hook.Add("Think", "ME_BuildDestroyKey", function()
	if not (ME.InGame and ME.InGame()) then bkWas, wWas, xWas = false, false, false return end
	local ins     = ME.Cam and ME.Cam.inspect
	local placing = B.IsPlacing and B.IsPlacing()
	local sel     = ME.Cam and ME.Cam.selected
	local hasSel  = sel and #sel > 0
	local typing  = ME.Chat and ME.Chat.typing

	local selMoving = false
	if hasSel and ME.UnitModels then
		for _, u in ipairs(sel) do
			if IsValid(u) then local rec = ME.UnitModels[u:EntIndex()]; if rec and rec.moving then selMoving = true break end end
		end
	end

	local bk = input.IsKeyDown(KEY_BACKSPACE)
	if bk and not bkWas and ins and ins.kind == "building" then B.Destroy() end
	bkWas = bk

	local w = input.IsKeyDown(KEY_W)
	if w and not wWas and not placing and not typing then
		if IsValid(B.dhtml) then B.dhtml:Call("if(window.flashChint)flashChint('w')") end
		if ins then ME.Cam.inspect = nil
		elseif hasSel then ME.Cam.selected = {} end
	end
	wWas = w

	local x = input.IsKeyDown(KEY_X)
	if x and not xWas and hasSel and not placing and not typing and IsValid(B.dhtml) then
		B.dhtml:Call("if(window.flashChint)flashChint('x')")
	end
	xWas = x

	local showHint = (ins ~= nil or hasSel) and not placing
	local showX    = hasSel and selMoving and not placing
	if showHint ~= B._cardHint or showX ~= B._cardHintSel then
		B._cardHint, B._cardHintSel = showHint, showX
		if IsValid(B.dhtml) then
			B.dhtml:Call("if(window.setCardHint)setCardHint(" .. (showHint and "true" or "false") .. "," .. (showX and "true" or "false") .. ")")
		end
	end
	ME.Cam.xStopShown = showX
end)

hook.Add("Think", "ME_BuildEnsure", function()
	if (ME.InGame and ME.InGame()) and not ME.MatchOver then
		ensurePanel()
	elseif IsValid(B.dhtml) then
		removePanel()
	end
end)

hook.Add("OnScreenSizeChanged", "ME_BuildRescale", function() removePanel() end)
