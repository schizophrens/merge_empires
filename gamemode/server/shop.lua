
util.AddNetworkString("ME_Shop_Buy")
util.AddNetworkString("ME_Shop_Gem")
util.AddNetworkString("ME_Reward")
util.AddNetworkString("ME_Notify")

local function findGem(id)
    local gems = MEConfig.Shop and MEConfig.Shop.Gems
    if not istable(gems) then return end
    for _, g in ipairs(gems) do
        if g.id == id then return g end
    end
end

local function findItem(id)
    local skins = MEConfig.Shop and MEConfig.Shop.Skins
    if not istable(skins) then return end
    for _, coll in ipairs(skins) do
        for _, it in ipairs(coll.items or {}) do
            if it.id == id then return it end
        end
    end
end

local function notify(ply, msg, ok)
    net.Start("ME_Notify")
    net.WriteString(msg or "")
    net.WriteBool(ok and true or false)
    net.Send(ply)
end

net.Receive("ME_Shop_Buy", function(_, ply)
    if not IsValid(ply) then return end
    ply.MEShopNext = ply.MEShopNext or 0
    if ply.MEShopNext > CurTime() then return end
    ply.MEShopNext = CurTime() + 0.4

    local it = findItem(net.ReadString())
    if not it then return end
    if hook.Run("MEMenu_ShopBuy", ply, it) ~= nil then return end

    if not ME.CanAffordGems(ply, it.price) then
        notify(ply, "Not enough gems.", false)
        return
    end
    ME.TakeGems(ply, it.price)
    notify(ply, "Purchase successful.", true)
end)

net.Receive("ME_Shop_Gem", function(_, ply)
    if ME.Throttle(ply, "gem", 0.5) then return end

    local g = findGem(net.ReadString())
    if not g then return end

    if hook.Run("MEMenu_GemBuy", ply, g) ~= nil then return end

    ME.GrantGemPack(ply, g.id)
end)

function ME.GrantGemPack(ply, id)
    if not IsValid(ply) then return false end

    local g = findGem(id)
    if not g then return false end

    ME.AddGems(ply, g.amount)

    net.Start("ME_Reward")
    net.WriteString("GEMS")
    net.WriteString("CURRENCY")
    net.WriteUInt(g.amount or 0, 32)
    net.WriteString("me_gem.png")
    net.Send(ply)

    return true
end
