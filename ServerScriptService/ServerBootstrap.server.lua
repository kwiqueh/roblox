--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService:WaitForChild("Services")
local BreedingServerManager = require(Services:WaitForChild("BreedingServerManager"))
BreedingServerManager.Start()
