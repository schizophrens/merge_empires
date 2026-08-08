ME = ME or {}
ME.UI = ME.UI or {}

local DESIGN_H = 1080

local function factor() return ScrH() / DESIGN_H end

function ME.UI.Scale(px) return math.floor(px * factor() + 0.5) end

ME.UI._fonts = ME.UI._fonts or {}

local function build(id, spec)
	surface.CreateFont(id, {
		font      = spec.font,
		size      = math.max(1, math.floor(spec.size * factor() + 0.5)),
		weight    = spec.weight or 500,
		antialias = spec.antialias ~= false,
		extended  = true,
	})
end

function ME.UI.Font(id, spec)
	ME.UI._fonts[id] = spec
	build(id, spec)
end

hook.Add("OnScreenSizeChanged", "ME_UI_Rescale", function()
	for id, spec in pairs(ME.UI._fonts) do build(id, spec) end
	hook.Run("ME_UI_Rescaled")
end)
