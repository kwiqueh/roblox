--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getState = remotes:WaitForChild("GetCreatureState") :: RemoteFunction
local breed = remotes:WaitForChild("BreedCreature") :: RemoteFunction
local state = getState:InvokeServer()
if state.success and #state.creatures >= 2 then
 local response = breed:InvokeServer({
  parentAId = state.creatures[1].id,
  parentBId = state.creatures[2].id,
  expectedInventoryVersion = state.inventoryVersion,
 })
 print(response.code, response.message)
else
 warn("Collection not ready:", state.code)
end
