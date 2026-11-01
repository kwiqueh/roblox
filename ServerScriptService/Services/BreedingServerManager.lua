--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Assembler = require(script.Parent.CreatureAssembler)
local BreedingService = require(script.Parent.BreedingService)
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PartCatalog"))
type Creature = Assembler.Creature
type GeneData = Assembler.GeneData
export type BreedRequest = { parentAId: string, parentBId: string, expectedInventoryVersion: number? }
export type DiscardRequest = {creatureId: string, expectedInventoryVersion: number?}
export type DiscardResult = {success: boolean, code: string, message: string, inventoryVersion: number}
export type BreedResult = {success: boolean, code: string, message: string, creature: Creature?, slotIndex: number?, inventoryVersion: number}
export type CreatureStateResult = {success: boolean, code: string, message: string, creatures: {Creature}, occupiedSlots: {[string]: string}, inventoryVersion: number, maxSlots: number}
type State = {creaturesById: {[string]: Creature}, creatureOrder: {string}, modelsById: {[string]: Model}, occupiedSlots: {[number]: string}, inventoryVersion: number, isBreeding: boolean, lastSuccessfulBreedTime: number, laboratory: Model?, isReady: boolean, demo: boolean, folder: Folder?, active: boolean}
local MAX_CREATURES = 6
local BREED_COOLDOWN_SECONDS = 1.5
local SPAWN_HEIGHT = 3
local ENABLE_DEMO = true
local states: {[Player]: State} = {}
local connections: {RBXScriptConnection} = {}
local started = false
local generation = 0
local breedRemote: RemoteFunction? = nil
local stateRemote: RemoteFunction? = nil
local discardRemote: RemoteFunction? = nil
local manager = {}

local function folder(parent: Instance, name: string): Folder
 local found = parent:FindFirstChild(name)
 if found then assert(found:IsA("Folder"), name .. " must be a Folder"); return found end
 local value = Instance.new("Folder"); value.Name = name; value.Parent = parent; return value
end
local function remote(parent: Folder, name: string): RemoteFunction
 local found = parent:FindFirstChild(name)
 if found then assert(found:IsA("RemoteFunction"), name .. " must be a RemoteFunction"); return found end
 local value = Instance.new("RemoteFunction"); value.Name = name; value.Parent = parent; return value
end
local function copyCreature(c: Creature): Creature
 return {id = c.id, genes = {Head = c.genes.Head, Body = c.genes.Body, Limbs = c.genes.Limbs}, bornAt = c.bornAt, parents = table.clone(c.parents)}
end
local function validGenes(genes: GeneData): boolean
 if type(genes) ~= "table" then return false end
 for _, slot in {"Head", "Body", "Limbs"} do
  local id = (genes :: {[string]: string})[slot]
  if type(id) ~= "string" or #id == 0 or #id > 128 then return false end
  local entry = Catalog.Parts[id]
  if type(entry) ~= "table" or entry.slot ~= slot then return false end
 end
 return true
end
local function result(state: State?, code: string, message: string): BreedResult
 return {success = false, code = code, message = message, creature = nil, slotIndex = nil, inventoryVersion = if state then state.inventoryVersion else 0}
end
local function plotFor(player: Player): (Model?, boolean)
 local production = workspace:FindFirstChild("Laboratories")
 if production then
  if not production:IsA("Folder") then warn("Laboratories must be a Folder"); return nil, false end
  for _, plot in production:GetChildren() do
   if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then return plot, false end
  end
  return nil, false
 end
 if not ENABLE_DEMO or not RunService:IsStudio() then return nil, false end
 local plots = folder(workspace, "DemoLaboratories")
 local plot = Instance.new("Model"); plot.Name = tostring(player.UserId); plot:SetAttribute("OwnerUserId", player.UserId)
 -- Use the lowest unused index, independent of player UserId and join order.
 local used: {[number]: boolean} = {}
 for _, existing in plots:GetChildren() do
  local index = existing:GetAttribute("DemoIndex")
  if type(index) == "number" then used[index] = true end
 end
 local index = 0
 while used[index] do index += 1 end
 plot:SetAttribute("DemoIndex", index)
 local origin = Vector3.new(index * 50, 0, 0)
 local platform = Instance.new("Part"); platform.Name = "Platform"; platform.Anchored = true; platform.Size = Vector3.new(28, 1, 20); platform.Position = origin; platform.Parent = plot
 local points = Instance.new("Folder"); points.Name = "SpawnPoints"; points.Parent = plot
 for i = 1, MAX_CREATURES do
  local p = Instance.new("Part"); p.Name = "Spawn" .. i; p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.Transparency = 1; p.Size = Vector3.new(1, 1, 1)
  p.Position = origin + Vector3.new(((i - 1) % 3 - 1) * 8, 1, (math.floor((i - 1) / 3) - 0.5) * 8); p.Parent = points
 end
 plot.Parent = plots
 return plot, true
end
local function spawnPoint(state: State, player: Player, slot: number): (CFrame?, string?)
 local plot = state.laboratory
 if not plot or not plot:IsDescendantOf(workspace) or plot:GetAttribute("OwnerUserId") ~= player.UserId then return nil, "PLOT_MISSING" end
 local points = plot:FindFirstChild("SpawnPoints")
 local point = if points then points:FindFirstChild("Spawn" .. slot) else nil
 if not point or not point:IsA("BasePart") or not point.Anchored then return nil, "SPAWN_POINT_MISSING" end
 return point.CFrame * CFrame.new(0, point.Size.Y / 2 + SPAWN_HEIGHT, 0), nil
end
local function cleanup(player: Player, state: State)
 state.active = false; state.isReady = false
 for _, model in state.modelsById do Assembler.Destroy(model) end
 table.clear(state.modelsById)
 if state.folder then state.folder:Destroy(); state.folder = nil end
 if state.demo and state.laboratory then state.laboratory:Destroy() end
 if states[player] == state then states[player] = nil end
end
local function newCreature(genes: GeneData): Creature
 return {id = HttpService:GenerateGUID(false), genes = genes, bornAt = os.time(), parents = {}}
end
local function initialize(player: Player, currentGeneration: number)
 if states[player] or player.Parent ~= Players then return end
 local state: State = {creaturesById = {}, creatureOrder = {}, modelsById = {}, occupiedSlots = {}, inventoryVersion = 0, isBreeding = false, lastSuccessfulBreedTime = -math.huge, laboratory = nil, isReady = false, demo = false, folder = nil, active = true}
 states[player] = state
 local ok, failure = pcall(function()
  local plot, demo = plotFor(player); state.laboratory = plot; state.demo = demo
  assert(plot, "No assigned laboratory")
  local active = folder(workspace, "ActiveCreatures")
  assert(not active:FindFirstChild(tostring(player.UserId)), "Creature folder already exists")
  local owned = Instance.new("Folder"); owned.Name = tostring(player.UserId); owned.Parent = active; state.folder = owned
  local starters = {newCreature({Head = "H_TOAST", Body = "B_DONUT", Limbs = "L_ODD_SOCKS"}), newCreature({Head = "H_CONE", Body = "B_BRICK", Limbs = "L_ODD_SOCKS"})}
  for slot, creature in starters do
   local cf, why = spawnPoint(state, player, slot); assert(cf, why)
   local model, err = Assembler.Assemble(creature, cf); assert(model, err)
   state.modelsById[creature.id] = model
   assert(state.active and generation == currentGeneration and player.Parent == Players, "player departed")
   model:SetAttribute("OwnerUserId", player.UserId); model:SetAttribute("SlotIndex", slot)
   model.Parent = owned; Assembler.StartAnimation(model)
   state.creaturesById[creature.id] = creature; table.insert(state.creatureOrder, creature.id); state.occupiedSlots[slot] = creature.id
  end
  state.inventoryVersion = 1; state.isReady = true
 end)
 if not ok then
  warn("Creature initialization failed for " .. player.UserId .. ": " .. tostring(failure))
  -- Keep the unready state, but remove all partially initialized world objects.
  for _, model in state.modelsById do Assembler.Destroy(model) end
  table.clear(state.modelsById); table.clear(state.creaturesById); table.clear(state.creatureOrder); table.clear(state.occupiedSlots)
  if state.folder then state.folder:Destroy(); state.folder = nil end
  if state.demo and state.laboratory then state.laboratory:Destroy(); state.laboratory = nil end
 end
end
local function validChild(child: Creature, a: Creature, b: Creature, state: State): boolean
 if type(child) == "table" and type(child.id) == "string" then
  for _, other in states do if other.creaturesById[child.id] then return false end end
 end
 return type(child) == "table" and type(child.id) == "string" and #child.id > 0 and #child.id <= 128 and state.creaturesById[child.id] == nil
  and type(child.bornAt) == "number" and child.bornAt == child.bornAt and child.bornAt > 0 and child.bornAt < math.huge and child.bornAt % 1 == 0
  and type(child.parents) == "table" and #child.parents == 2 and child.parents[1] == a.id and child.parents[2] == b.id and validGenes(child.genes)
end
local function breed(player: Player, request: unknown): BreedResult
 local state = states[player]
 if not state or not state.active or not state.isReady or player.Parent ~= Players then return result(state, "NOT_READY", "Collection is not ready") end
 if state.isBreeding then return result(state, "BUSY", "A breeding request is already in progress") end
 if type(request) ~= "table" then return result(state, "INVALID_REQUEST", "Invalid request") end
 local data = request :: {[string]: unknown}
 for key in data do if key ~= "parentAId" and key ~= "parentBId" and key ~= "expectedInventoryVersion" then return result(state, "INVALID_REQUEST", "Invalid request") end end
 local aId, bId, expected = data.parentAId, data.parentBId, data.expectedInventoryVersion
 if type(aId) ~= "string" or type(bId) ~= "string" or #aId == 0 or #bId == 0 or #aId > 128 or #bId > 128 then return result(state, "INVALID_REQUEST", "Invalid parent identifiers") end
 if expected ~= nil and (type(expected) ~= "number" or expected ~= expected or expected < 0 or expected == math.huge or expected % 1 ~= 0) then return result(state, "INVALID_REQUEST", "Invalid inventory version") end
 if aId == bId then return result(state, "INVALID_PARENT", "Select two different parents") end
 if expected ~= nil and expected ~= state.inventoryVersion then return result(state, "STALE_STATE", "Collection has changed") end
 local a, b = state.creaturesById[aId], state.creaturesById[bId]
 if not a or not b then return result(state, "PARENT_NOT_FOUND", "Parent not found in your collection") end
 if not validGenes(a.genes) or not validGenes(b.genes) then return result(state, "INVALID_PARENT", "Invalid parent data") end
 if #state.creatureOrder >= MAX_CREATURES then return result(state, "CAPACITY_FULL", "Your laboratory is full (6/6)") end
 if os.clock() - state.lastSuccessfulBreedTime < BREED_COOLDOWN_SECONDS then return result(state, "COOLDOWN", "Please wait before breeding again") end
 local slot = 0
 for i = 1, MAX_CREATURES do if not state.occupiedSlots[i] then slot = i; break end end
 if slot == 0 then warn("Inconsistent creature slots for " .. player.UserId); return result(state, "NO_FREE_SLOT", "No free slot") end
 local spawn, err = spawnPoint(state, player, slot)
 if not spawn then return result(state, err or "PLOT_MISSING", "Laboratory is unavailable") end
 state.isBreeding = true
 local version = state.inventoryVersion
 local previousBreedTime = state.lastSuccessfulBreedTime
 local prepared: Model? = nil
 local childId: string? = nil
 local outcome: BreedResult? = nil
 local ok, failure = pcall(function()
  -- Pass copies so a misbehaving genetics engine cannot mutate authoritative parents.
  local generated, child = pcall(BreedingService.Breed, copyCreature(a), copyCreature(b))
  if not generated or not validChild(child, a, b, state) then outcome = result(state, "BREEDING_FAILED", "Could not generate offspring"); return end
  local creature = copyCreature(child)
  local model, assemblyError = Assembler.Assemble(creature, spawn)
  if not model then
   local code = assemblyError or "ASSEMBLY_FAILED"
   if code == "ASSET_FOLDER_MISSING" then code = "ASSET_MISSING" elseif code == "INVALID_SLOT" then code = "INVALID_GENE" end
   outcome = result(state, code, "Could not assemble offspring"); return
  end
  prepared = model
  if not state.active or states[player] ~= state or player.Parent ~= Players or not state.isReady or state.inventoryVersion ~= version or state.creaturesById[aId] ~= a or state.creaturesById[bId] ~= b or #state.creatureOrder >= MAX_CREATURES or state.occupiedSlots[slot] or state.creaturesById[creature.id] then outcome = result(state, "STALE_STATE", "Collection has changed"); return end
  local currentSpawn = spawnPoint(state, player, slot)
  if not currentSpawn or currentSpawn ~= spawn or not state.folder or not state.folder:IsDescendantOf(workspace) then outcome = result(state, "SPAWN_FAILED", "Laboratory is unavailable"); return end
  childId = creature.id
  state.creaturesById[creature.id] = creature; table.insert(state.creatureOrder, creature.id); state.occupiedSlots[slot] = creature.id; state.modelsById[creature.id] = model
  model:SetAttribute("OwnerUserId", player.UserId); model:SetAttribute("SlotIndex", slot); model.Parent = state.folder
  Assembler.StartAnimation(model)
  state.inventoryVersion = version + 1; state.lastSuccessfulBreedTime = os.clock()
  outcome = {success = true, code = "SUCCESS", message = "Creature created successfully", creature = copyCreature(creature), slotIndex = slot, inventoryVersion = state.inventoryVersion}
 end)
 if not ok or not outcome or not outcome.success then
  if childId then
   state.creaturesById[childId] = nil; state.modelsById[childId] = nil
   if state.occupiedSlots[slot] == childId then state.occupiedSlots[slot] = nil end
   local index = table.find(state.creatureOrder, childId); if index then table.remove(state.creatureOrder, index) end
   state.inventoryVersion = version; state.lastSuccessfulBreedTime = previousBreedTime
  end
  if prepared then Assembler.Destroy(prepared) end
  if not ok then warn("Breeding transaction failed for " .. player.UserId .. ": " .. tostring(failure)); outcome = result(state, "INTERNAL_ERROR", "Breeding failed") end
 end
 state.isBreeding = false
 return outcome or result(state, "INTERNAL_ERROR", "Breeding failed")
end
local function discard(player: Player, request: unknown): DiscardResult
 local state = states[player]
 local function response(success: boolean, code: string, message: string): DiscardResult
  return {success = success, code = code, message = message, inventoryVersion = if state then state.inventoryVersion else 0}
 end
 if not state or not state.active or not state.isReady or player.Parent ~= Players then return response(false, "NOT_READY", "Collection is not ready") end
 if state.isBreeding then return response(false, "BUSY", "Another request is in progress") end
 if type(request) ~= "table" then return response(false, "INVALID_REQUEST", "Invalid request") end
 local data = request :: {[string]: unknown}
 for key in data do
  if key ~= "creatureId" and key ~= "expectedInventoryVersion" then return response(false, "INVALID_REQUEST", "Invalid request") end
 end
 local id, expected = data.creatureId, data.expectedInventoryVersion
 if type(id) ~= "string" or #id == 0 or #id > 128 then return response(false, "INVALID_REQUEST", "Invalid creature identifier") end
 if expected ~= nil and (type(expected) ~= "number" or expected ~= expected or expected < 0 or expected == math.huge or expected % 1 ~= 0) then return response(false, "INVALID_REQUEST", "Invalid inventory version") end
 if expected ~= nil and expected ~= state.inventoryVersion then return response(false, "STALE_STATE", "Collection has changed") end
 if not state.creaturesById[id] then return response(false, "PARENT_NOT_FOUND", "Creature not found in your collection") end
 if #state.creatureOrder <= 2 then return response(false, "MINIMUM_CREATURES", "Keep at least two creatures for breeding") end
 local slot: number? = nil
 for index, occupied in state.occupiedSlots do if occupied == id then slot = index; break end end
 local orderIndex = table.find(state.creatureOrder, id)
 if not slot or not orderIndex then
  warn("Inconsistent creature inventory for " .. player.UserId)
  return response(false, "INTERNAL_ERROR", "Could not discard creature")
 end
 -- The commit does not yield, and uses the same lock as breeding and respawning.
 state.isBreeding = true
 local model = state.modelsById[id]
 state.creaturesById[id] = nil
 state.modelsById[id] = nil
 state.occupiedSlots[slot] = nil
 table.remove(state.creatureOrder, orderIndex)
 state.inventoryVersion += 1
 state.isBreeding = false
 if model then
  local ok, err = pcall(Assembler.Destroy, model)
  if not ok then warn("Could not destroy discarded creature model: " .. tostring(err)) end
 end
 return response(true, "SUCCESS", "Creature discarded")
end
local function getState(player: Player): CreatureStateResult
 local state = states[player]
 local ready = state ~= nil and state.active and state.isReady and player.Parent == Players
 local creatures: {Creature} = {}; local slots: {[string]: string} = {}
 if ready and state then
  for _, id in state.creatureOrder do
   local creature = state.creaturesById[id]
   if creature then table.insert(creatures, copyCreature(creature)) end
   local model = state.modelsById[id]
   if not model or not model:IsDescendantOf(workspace) then warn("Missing creature model " .. id .. " for " .. player.UserId) end
  end
  -- String keys preserve sparse slot dictionaries over RemoteFunctions.
  for index, id in state.occupiedSlots do slots[tostring(index)] = id end
 end
 return {success = ready, code = if ready then "SUCCESS" else "NOT_READY", message = if ready then "Collection loaded" else "Collection is not ready", creatures = creatures, occupiedSlots = slots, inventoryVersion = if state then state.inventoryVersion else 0, maxSlots = MAX_CREATURES}
end
-- Server-only recovery for a decorative model destroyed by another system.
function manager.RespawnCreature(player: Player, id: string): (boolean, string)
 local state = states[player]
 if not state or not state.active or not state.isReady then return false, "NOT_READY" end
 if state.isBreeding then return false, "BUSY" end
 local creature = state.creaturesById[id]
 if not creature then return false, "PARENT_NOT_FOUND" end
 local slot = 0
 for index, occupied in state.occupiedSlots do if occupied == id then slot = index; break end end
 if slot == 0 then return false, "NO_FREE_SLOT" end
 local old = state.modelsById[id]
 if old and old:IsDescendantOf(workspace) then return true, "SUCCESS" end
 local cf, why = spawnPoint(state, player, slot)
 if not cf then return false, why or "PLOT_MISSING" end
 state.isBreeding = true
 local model: Model? = nil
 local ok, failure = pcall(function()
  local assembled, err = Assembler.Assemble(creature, cf)
  if not assembled then error(err or "ASSEMBLY_FAILED") end
  model = assembled
  if not state.active or states[player] ~= state or not state.folder or not state.folder:IsDescendantOf(workspace) then error("SPAWN_FAILED") end
  assembled:SetAttribute("OwnerUserId", player.UserId); assembled:SetAttribute("SlotIndex", slot)
  assembled.Parent = state.folder
  Assembler.StartAnimation(assembled)
  state.modelsById[id] = assembled
 end)
 state.isBreeding = false
 if not ok then
  if model then Assembler.Destroy(model) end
  warn("Creature respawn failed: " .. tostring(failure))
  return false, "ASSEMBLY_FAILED"
 end
 if old then Assembler.Destroy(old) end
 return true, "SUCCESS"
end
function manager.Start()
 if started then return end
 local remotes = folder(ReplicatedStorage, "Remotes")
 local breeding = remote(remotes, "BreedCreature"); local collection = remote(remotes, "GetCreatureState")
 local discarding = remote(remotes, "DiscardCreature")
 started = true; generation += 1; local currentGeneration = generation
 breedRemote = breeding; stateRemote = collection; discardRemote = discarding
 breeding.OnServerInvoke = breed; collection.OnServerInvoke = getState; discarding.OnServerInvoke = discard
 table.insert(connections, Players.PlayerAdded:Connect(function(player) initialize(player, currentGeneration) end))
 table.insert(connections, Players.PlayerRemoving:Connect(function(player) local state = states[player]; if state then cleanup(player, state) end end))
 for _, player in Players:GetPlayers() do task.spawn(initialize, player, currentGeneration) end
end
function manager.Stop()
 if not started then return end
 started = false; generation += 1
 for _, connection in connections do connection:Disconnect() end
 table.clear(connections)
 if breedRemote then breedRemote.OnServerInvoke = nil; breedRemote = nil end
 if stateRemote then stateRemote.OnServerInvoke = nil; stateRemote = nil end
 if discardRemote then discardRemote.OnServerInvoke = nil; discardRemote = nil end
 for player, state in states do cleanup(player, state) end
end
return manager
