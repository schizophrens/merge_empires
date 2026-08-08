
local cfg = MEConfig and MEConfig.Server
if not cfg then return end

local resources = cfg.Resources
if not istable(resources) then return end

for i = 1, #resources do
    resource.AddFile(resources[i])
end
