--!strict
-- Test client only: insert as a LocalScript in StarterPlayerScripts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getState = remotes:WaitForChild("GetCreatureState") :: RemoteFunction
local breed = remotes:WaitForChild("BreedCreature") :: RemoteFunction

local state = nil
for _ = 1, 30 do
    local ok, response = pcall(function()
        return getState:InvokeServer()
    end)
    if ok and response and response.success and #response.creatures >= 2 then
        state = response
        break
    end
    task.wait(0.25)
end

if not state then
    warn("Starter collection not ready. Check Server Output and missing assets.")
    return
end

local ok, response = pcall(function()
    return breed:InvokeServer({
        parentAId = state.creatures[1].id,
        parentBId = state.creatures[2].id,
        expectedInventoryVersion = state.inventoryVersion,
    })
end)
if ok then
    print("Breed result:", response.code, response.message)
else
    warn("Breed remote failed:", response)
end
