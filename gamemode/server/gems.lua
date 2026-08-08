
function ME.GetGems(ply) return IsValid(ply) and ply:GetNWInt("ME_Gems", 0) or 0 end

function ME.SetGems(ply, n)
    if not IsValid(ply) then return end
    ply:SetNWInt("ME_Gems", math.max(0, math.floor(tonumber(n) or 0)))
end

function ME.AddGems(ply, n)
    if IsValid(ply) then ME.SetGems(ply, ME.GetGems(ply) + (tonumber(n) or 0)) end
end

function ME.CanAffordGems(ply, n) return ME.GetGems(ply) >= (tonumber(n) or 0) end

function ME.TakeGems(ply, n)
    n = tonumber(n) or 0
    if ME.CanAffordGems(ply, n) then
        ME.SetGems(ply, ME.GetGems(ply) - n)
        return true
    end
    return false
end

