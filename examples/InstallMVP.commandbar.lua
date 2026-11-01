-- Roblox Studio setup installer. Run ONCE in the Command Bar in EDIT mode, not Play.
-- Downloads ONLY source files from this project's public GitHub branch.
-- Make a backup before running in an existing place: it overwrites matching script names.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(),
    "Open a Baseplate in Roblox Studio and STOP Play before installing")

local HttpService = game:GetService("HttpService")
local base = "https://raw.githubusercontent.com/kwiqueh/roblox/fix/breeding-mvp-catalog-and-studio-assets/"
local files = {
    {"ReplicatedStorage/Shared/PartCatalog.lua", "ReplicatedStorage", {"Shared"}, "PartCatalog", "ModuleScript"},
    {"ServerScriptService/Services/BreedingService.lua", "ServerScriptService", {"Services"}, "BreedingService", "ModuleScript"},
    {"ServerScriptService/Services/CreatureAssembler.lua", "ServerScriptService", {"Services"}, "CreatureAssembler", "ModuleScript"},
    {"ServerScriptService/Services/BreedingServerManager.lua", "ServerScriptService", {"Services"}, "BreedingServerManager", "ModuleScript"},
    {"ServerScriptService/ServerBootstrap.server.lua", "ServerScriptService", {}, "ServerBootstrap", "Script"},
    {"examples/BreedClient.client.lua", "StarterPlayer", {"StarterPlayerScripts"}, "BreedClient", "LocalScript"},
}
local oldHttpEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local sources = {}
local downloaded, failure = pcall(function()
    for i, spec in ipairs(files) do
        local code = HttpService:GetAsync(base .. spec[1], true)
        assert(type(code) == "string" and #code > 30 and code:find("%-%-!strict"),
            "Invalid Luau source for " .. spec[1])
        sources[i] = code
    end
end)
HttpService.HttpEnabled = oldHttpEnabled
assert(downloaded, "Could not fetch code from GitHub: " .. tostring(failure))

local function getFolder(parent, name)
    local child = parent:FindFirstChild(name)
    if not child then
        child = Instance.new("Folder")
        child.Name = name
        child.Parent = parent
    end
    return child
end
for i, spec in ipairs(files) do
    local parent = game:GetService(spec[2])
    for _, folderName in ipairs(spec[3]) do
        if folderName == "StarterPlayerScripts" then
            parent = parent:WaitForChild(folderName)
        else
            parent = getFolder(parent, folderName)
        end
    end
    local existing = parent:FindFirstChild(spec[4])
    assert(not existing or existing.ClassName == spec[5],
        "Existing instance has wrong type: " .. spec[4])
    local scriptObject = existing or Instance.new(spec[5])
    scriptObject.Name = spec[4]
    -- Script.Source can be set from Studio's Command Bar, not from game scripts.
    scriptObject.Source = sources[i]
    scriptObject.Parent = parent
end

local storage = game:GetService("ServerStorage")
local assets = getFolder(storage, "PartAssets")
assert(assets:IsA("Folder"), "PartAssets must be a Folder")
local slots = {
    Head = {"H_TOAST", "H_CONE", "H_AQUARIUM", "H_SCREAM", "H_ERROR"},
    Body = {"B_DONUT", "B_BRICK", "B_FRIDGE", "B_GYM", "B_VOID"},
    Limbs = {"L_ODD_SOCKS", "L_CHAIR_WHEELS", "L_SPAGHETTI", "L_ROCKET", "L_INVERT"},
}
local generated = 0
for slot, ids in pairs(slots) do
    local folder = getFolder(assets, slot)
    assert(folder:IsA("Folder"), slot .. " must be a Folder")
    for _, id in ipairs(ids) do
        if not folder:FindFirstChild(id) then
            local model = Instance.new("Model")
            model.Name = id
            local root = Instance.new("Part")
            root.Name = "Root"
            root.Size = if slot == "Body" then Vector3.new(2, 2, 2)
                else Vector3.new(1.5, 1, 1.5)
            root.CanCollide = false
            root.Anchored = false
            root.Color = if slot == "Head" then Color3.fromRGB(255, 195, 75)
                elseif slot == "Body" then Color3.fromRGB(110, 190, 255)
                else Color3.fromRGB(180, 255, 140)
            root.Parent = model
            model.PrimaryPart = root
            local function attach(name, offset)
                local a = Instance.new("Attachment")
                a.Name, a.Position, a.Parent = name, offset, root
            end
            if slot == "Body" then
                attach("HeadSocket", Vector3.new(0, 1, 0))
                attach("LimbsSocket", Vector3.new(0, -1, 0))
            elseif slot == "Head" then
                attach("RootMount", Vector3.new(0, -0.5, 0))
            else
                attach("RootMount", Vector3.new(0, 0.5, 0))
            end
            model.Parent = folder
            generated += 1
        end
    end
end
print("MUTATION LAB INSTALLED: 6 scripts, " .. generated .. " new test body parts.")
print("Now press Play. The two starters should spawn, followed by a third creature.")
