ME = ME or {}

ME.MapOK = game.GetMap() == (ME.Config and ME.Config.OfficialMap or "me_map")

local WARN = "[Merge Empires] This gamemode only runs on " ..
	((ME.Config and ME.Config.OfficialMap) or "me_map") .. ". Current map: " .. game.GetMap() .. "."

function ME.MapLockNotice(ply)
	if SERVER then
		if IsValid(ply) then ply:ChatPrint(WARN) end
	else
		chat.AddText(Color(255, 90, 90), WARN)
	end
end

if ME.MapOK then return end

MsgN(WARN)

if SERVER then

	hook.Add("PlayerInitialSpawn", "ME_MapLockNotice", function(ply)
		timer.Simple(3, function() ME.MapLockNotice(ply) end)
	end)

else

	hook.Add("InitPostEntity", "ME_MapLockNotice", function()
		timer.Simple(3, ME.MapLockNotice)
	end)

end
