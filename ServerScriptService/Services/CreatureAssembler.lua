--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PartCatalog"))

export type GeneData = { Head: string, Body: string, Limbs: string }
export type Creature = { id: string, genes: GeneData, bornAt: number, parents: {string} }

type Animated = { base: CFrame, phase: number }
local UPDATE_INTERVAL = 1 / 15
local BOB_AMPLITUDE = 0.15
local BOB_FREQUENCY = 1.2
local SWAY = math.rad(3)
local animated: {[Model]: Animated} = {}
local heartbeat: RBXScriptConnection? = nil
local accumulator = 0
local random = Random.new()
local Assembler = {}

local function rootOf(model: Model): BasePart?
 local root = model:FindFirstChild("Root")
 if root and root:IsA("BasePart") and model.PrimaryPart == root then return root end
 return nil
end

local function attachment(root: BasePart, name: string): Attachment?
 local value = root:FindFirstChild(name)
 if value and value:IsA("Attachment") then return value end
 return nil
end

local function template(slot: string, id: string): (Model?, string?)
 local entry = Catalog.Parts[id]
 if type(entry) ~= "table" then return nil, "INVALID_GENE" end
 if entry.slot ~= slot then return nil, "INVALID_SLOT" end
 local assets = ServerStorage:FindFirstChild("PartAssets")
 local folder = if assets then assets:FindFirstChild(slot) else nil
 if not folder or not folder:IsA("Folder") then return nil, "ASSET_FOLDER_MISSING" end
 local value = folder:FindFirstChild(id)
 if not value then return nil, "ASSET_MISSING" end
 if not value:IsA("Model") or not value.Archivable then return nil, "ASSET_INVALID" end
 local root = rootOf(value)
 if not root then return nil, "ASSET_INVALID" end
 if slot == "Body" then
  if not attachment(root, "HeadSocket") or not attachment(root, "LimbsSocket") then return nil, "ATTACHMENT_MISSING" end
 elseif not attachment(root, "RootMount") then return nil, "ATTACHMENT_MISSING" end
 -- Existing joints and scripts can conflict with the single-root assembly.
 for _, descendant in value:GetDescendants() do
  if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") or descendant:IsA("Constraint") or descendant:IsA("LuaSourceContainer") or descendant:IsA("Humanoid") then
   return nil, "ASSET_INVALID"
  end
 end
 return value, nil
end

function Assembler.Assemble(creature: Creature, spawnCFrame: CFrame): (Model?, string?)
 if type(creature) ~= "table" or type(creature.id) ~= "string" or creature.id == "" or type(creature.genes) ~= "table" or typeof(spawnCFrame) ~= "CFrame" then return nil, "INVALID_CREATURE" end
 local genes = creature.genes
 if type(genes.Head) ~= "string" or type(genes.Body) ~= "string" or type(genes.Limbs) ~= "string" then return nil, "INVALID_GENE" end
 local bodyTemplate, bodyError = template("Body", genes.Body)
 if not bodyTemplate then return nil, bodyError end
 local headTemplate, headError = template("Head", genes.Head)
 if not headTemplate then return nil, headError end
 local limbsTemplate, limbsError = template("Limbs", genes.Limbs)
 if not limbsTemplate then return nil, limbsError end
 local composite = Instance.new("Model")
 local ok, failure = pcall(function()
  composite.Name = "Creature_" .. creature.id
  local body = bodyTemplate:Clone(); body.Parent = composite
  local head = headTemplate:Clone(); head.Parent = composite
  local limbs = limbsTemplate:Clone(); limbs.Parent = composite
  body.Name = "Body"; head.Name = "Head"; limbs.Name = "Limbs"
  local root = assert(rootOf(body))
  local headRoot = assert(rootOf(head))
  local limbsRoot = assert(rootOf(limbs))
  composite.PrimaryPart = root
  body:PivotTo(spawnCFrame * root.CFrame:Inverse() * body:GetPivot())
  local headSocket = assert(attachment(root, "HeadSocket"))
  local limbsSocket = assert(attachment(root, "LimbsSocket"))
  local headMount = assert(attachment(headRoot, "RootMount"))
  local limbsMount = assert(attachment(limbsRoot, "RootMount"))
  head:PivotTo(headSocket.WorldCFrame * headMount.WorldCFrame:Inverse() * head:GetPivot())
  limbs:PivotTo(limbsSocket.WorldCFrame * limbsMount.WorldCFrame:Inverse() * limbs:GetPivot())
  assert((headSocket.WorldPosition - headMount.WorldPosition).Magnitude < 0.001 and (limbsSocket.WorldPosition - limbsMount.WorldPosition).Magnitude < 0.001, "attachment alignment failed")
  for _, part in composite:GetDescendants() do
   if part:IsA("BasePart") then
    part.Anchored = part == root
    part.CanCollide = false; part.CanTouch = false
    if part ~= root then
     part.Massless = true
     local weld = Instance.new("WeldConstraint")
     weld.Part0 = root; weld.Part1 = part; weld.Parent = root
    end
   end
  end
  composite:SetAttribute("CreatureId", creature.id)
  composite:SetAttribute("HeadId", genes.Head)
  composite:SetAttribute("BodyId", genes.Body)
  composite:SetAttribute("LimbsId", genes.Limbs)
 end)
 if not ok then
  composite:Destroy()
  warn("Creature assembly failed: " .. tostring(failure))
  return nil, "ASSEMBLY_FAILED"
 end
 return composite, nil
end

function Assembler.StopAnimation(model: Model)
 animated[model] = nil
 if next(animated) == nil and heartbeat then heartbeat:Disconnect(); heartbeat = nil; accumulator = 0 end
end
function Assembler.StartAnimation(model: Model)
 if animated[model] then return end
 animated[model] = {base = model:GetPivot(), phase = random:NextNumber(0, 2 * math.pi)}
 if heartbeat then return end
 heartbeat = RunService.Heartbeat:Connect(function(dt: number)
  accumulator += dt
  if accumulator < UPDATE_INTERVAL then return end
  accumulator = 0
  local now = os.clock()
  for current, data in animated do
   if not current:IsDescendantOf(workspace) then
    Assembler.StopAnimation(current)
   else
    local angle = now * 2 * math.pi * BOB_FREQUENCY + data.phase
    current:PivotTo(data.base * CFrame.new(0, BOB_AMPLITUDE * math.sin(angle), 0) * CFrame.Angles(0, 0, SWAY * math.sin(angle * 0.7)))
   end
  end
 end)
end
function Assembler.Destroy(model: Model)
 Assembler.StopAnimation(model)
 model:Destroy()
end
return Assembler
