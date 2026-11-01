-- Paste the entire script into Roblox Studio's Command Bar (View > Command Bar)
-- while NOT playing. This generates placeholder Models in the editable place.
-- Existing Models are left untouched; replace them later with real 3D art.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PartCatalog"))

local assets = ServerStorage:FindFirstChild("PartAssets")
if not assets then
    assets = Instance.new("Folder")
    assets.Name = "PartAssets"
    assets.Parent = ServerStorage
end
assert(assets:IsA("Folder"), "PartAssets must be a Folder")

local count = 0
for _, slot in {"Head", "Body", "Limbs"} do
    local folder = assets:FindFirstChild(slot)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = slot
        folder.Parent = assets
    end
    assert(folder:IsA("Folder"), slot .. " must be a Folder")
    local ids = {}
    for id, def in pairs(Catalog.Parts) do
        if def.slot == slot then table.insert(ids, id) end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if not folder:FindFirstChild(id) then
            local model = Instance.new("Model")
            model.Name = id
            local root = Instance.new("Part")
            root.Name = "Root"
            root.Size = if slot == "Body" then Vector3.new(2, 2, 2) else Vector3.new(1.5, 1, 1.5)
            root.Anchored = false
            root.CanCollide = false
            root.Color = if slot == "Head" then Color3.fromRGB(255, 195, 75)
                elseif slot == "Body" then Color3.fromRGB(110, 190, 255)
                else Color3.fromRGB(180, 255, 140)
            root.Parent = model
            model.PrimaryPart = root
            local function mount(name, position)
                local point = Instance.new("Attachment")
                point.Name = name
                point.Position = position
                point.Parent = root
            end
            if slot == "Body" then
                mount("HeadSocket", Vector3.new(0, 1, 0))
                mount("LimbsSocket", Vector3.new(0, -1, 0))
            elseif slot == "Head" then
                mount("RootMount", Vector3.new(0, -0.5, 0))
            else
                mount("RootMount", Vector3.new(0, 0.5, 0))
            end
            model.Parent = folder
            count += 1
        end
    end
end
print("Generated " .. count .. " placeholder parts. All catalog IDs now have a model.")
