-- Mutation Lab V0.3 installer. Paste into the Command Bar in EDIT mode, not Play.
-- Downloads ONLY source files from this project's public GitHub commit.
-- Make a backup before running in an existing place: it overwrites matching script names.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(),
    "Open a Baseplate in Roblox Studio and STOP Play before installing")

local HttpService = game:GetService("HttpService")
local base = "https://raw.githubusercontent.com/kwiqueh/roblox/fd82d55b9877f82d2612ba2f8ee4bc36e008cf67/"
local files = {
    {"ServerStorage/AssetGeneration/CreatureAssetFactory.lua", "ServerStorage", {"AssetGeneration"}, "CreatureAssetFactory", "ModuleScript"},
    {"ReplicatedStorage/Shared/PartCatalog.lua", "ReplicatedStorage", {"Shared"}, "PartCatalog", "ModuleScript"},
    {"ServerScriptService/Services/BreedingService.lua", "ServerScriptService", {"Services"}, "BreedingService", "ModuleScript"},
    {"ServerScriptService/Services/CreatureAssembler.lua", "ServerScriptService", {"Services"}, "CreatureAssembler", "ModuleScript"},
    {"ServerScriptService/Services/BreedingServerManager.lua", "ServerScriptService", {"Services"}, "BreedingServerManager", "ModuleScript"},
    {"ServerScriptService/ServerBootstrap.server.lua", "ServerScriptService", {}, "ServerBootstrap", "Script"},
    {"StarterPlayer/StarterPlayerScripts/CreatureLabUI.client.lua", "StarterPlayer", {"StarterPlayerScripts"}, "CreatureLabUI", "LocalScript"},
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
    assert(child:IsA("Folder"), name .. " must be a Folder")
    return child
end
local factoryModule = nil
for i, spec in ipairs(files) do
    local parent = game:GetService(spec[2])
    for _, folderName in ipairs(spec[3]) do
        if folderName == "StarterPlayerScripts" then
            parent = parent:WaitForChild(folderName)
        else
            parent = getFolder(parent, folderName)
        end
    end
    local existing = nil
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == spec[4] then
            assert(child.ClassName == spec[5], "Existing instance has wrong type: " .. spec[4])
            if existing then child:Destroy() else existing = child end
        end
    end
    local scriptObject = existing or Instance.new(spec[5])
    scriptObject.Name = spec[4]
    -- Script.Source can be set from Studio's Command Bar, not from game scripts.
    scriptObject.Source = sources[i]
    scriptObject.Parent = parent
    if spec[4] == "CreatureAssetFactory" then factoryModule = scriptObject end
end

-- The V0.1 example breeds on join. Disable every exact-name copy.
local starterScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, child in ipairs(starterScripts:GetChildren()) do
    if child.Name == "BreedClient" and child:IsA("LocalScript") then child.Enabled = false end
end

-- A fresh ModuleScript instance avoids Roblox's require cache on repeat installs.
assert(factoryModule and factoryModule:IsA("ModuleScript"), "CreatureAssetFactory not installed")
local temporary = factoryModule:Clone()
temporary.Name = "__MutationLabInstall_" .. HttpService:GenerateGUID(false)
temporary.Parent = factoryModule.Parent
local generated, result = pcall(function()
    local factory = require(temporary)
    return factory.Generate()
end)
temporary:Destroy()
assert(generated, "Asset generation failed: " .. tostring(result))
print(string.format("MUTATION LAB V0.3: %d created, %d upgraded, %d current, %d custom/duplicate assets preserved, %d failed.",
    result.created, result.upgraded, result.unchanged, result.preserved, result.failed))
assert(result.failed == 0, "Some assets failed to generate; see Output for details")
print("MUTATION LAB V0.3 INSTALLED: 7 scripts; old BreedClient disabled. Save the place, then press Play.")
if result.preserved > 0 then warn("Some unrecognized or duplicate assets were preserved; see Output and inspect them before testing.") end
