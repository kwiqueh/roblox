--!strict
-- Studio edit-time asset factory. Templates contain no runtime scripts or joints.
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Factory = {}
local GENERATOR = "MutationLabCreatureAssetFactory"
local VERSION = 3
local PI = math.pi
local WHITE = Color3.fromRGB(244, 243, 231)
local BLACK = Color3.fromRGB(27, 30, 42)
local PINK = Color3.fromRGB(255, 111, 180)
local CYAN = Color3.fromRGB(61, 236, 241)
local PURPLE = Color3.fromRGB(168, 77, 239)
type Builder = (Model) -> ()
type Report = {created: number, upgraded: number, unchanged: number, preserved: number, failed: number}

local function piece(model: Model, name: string, size: Vector3, pos: Vector3, color: Color3, shape: Enum.PartType?, material: Enum.Material?, rotation: CFrame?): Part
 local p = Instance.new("Part")
 p.Name = name; p.Size = size; p.CFrame = CFrame.new(pos) * (rotation or CFrame.identity)
 p.Color = color; p.Shape = shape or Enum.PartType.Block; p.Material = material or Enum.Material.SmoothPlastic
 p.Anchored = false; p.CanCollide = false; p.CanTouch = false; p.Parent = model
 return p
end
local function block(m: Model, name: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, color: Color3): Part
 return piece(m, name, Vector3.new(sx, sy, sz), Vector3.new(x,y,z), color)
end
local function ball(m: Model, name: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, color: Color3): Part
 return piece(m, name, Vector3.new(sx, sy, sz), Vector3.new(x,y,z), color, Enum.PartType.Ball)
end
local function cylinder(m: Model, name: string, diameter: number, height: number, x: number, y: number, z: number, color: Color3): Part
 return piece(m, name, Vector3.new(height, diameter, diameter), Vector3.new(x,y,z), color, Enum.PartType.Cylinder, nil, CFrame.Angles(0,0,PI/2))
end
local function neon(p: Part)
 p.Material = Enum.Material.Neon
end
local function eyes(m: Model, y: number, z: number, spread: number)
 for _, side in {-1, 1} do
  ball(m, "Eye", .33, .38, .13, side * spread, y, z, WHITE)
  ball(m, "Pupil", .14, .19, .08, side * spread, y, z - .09, BLACK)
 end
end
local function ring(m: Model, radius: number, segments: number, width: number, depth: number, color: Color3, material: Enum.Material?, zOffset: number?)
 for i = 1, segments do
  local angle = (i - 1) * 2 * PI / segments
  local p = piece(m, "Ring", Vector3.new(width, 2 * radius * math.sin(PI / segments) + .12, depth), Vector3.new(radius * math.cos(angle), radius * math.sin(angle), zOffset or 0), color, nil, material, CFrame.Angles(0,0,angle))
  p.CastShadow = true
 end
end
local function toast(m: Model)
 local steel = Color3.fromRGB(162, 175, 183); local bread = Color3.fromRGB(243, 192, 111)
 local base = block(m,"Toaster",2.15,1.12,1.25,0,.12,0,steel); base.Material = Enum.Material.Metal
 block(m,"Slot",1.65,.08,.72,0,.72,0,BLACK)
 for _, x in {-.48,.48} do
  block(m,"ToastCrust",.78,.58,.32,x,.92,0,Color3.fromRGB(162,95,54))
  block(m,"Toast",.64,.49,.34,x,.96,-.01,bread)
 end
 eyes(m,.23,-.64,.46)
 block(m,"Lever",.15,.42,.18,1.16,.18,0,BLACK)
end
local function cone(m: Model)
 local orange = Color3.fromRGB(251,125,40)
 block(m,"Base",2.2,.18,1.7,0,-.4,0,orange)
 cylinder(m,"LowerCone",1.7,.42,0,-.1,0,orange)
 cylinder(m,"LowerStripe",1.45,.24,0,.22,0,WHITE)
 cylinder(m,"MiddleCone",1.22,.32,0,.49,0,orange)
 cylinder(m,"UpperStripe",.88,.2,0,.75,0,WHITE)
 cylinder(m,"Tip",.58,.36,0,1.01,0,orange)
 eyes(m,.06,-.86,.32)
end
local function donut(m: Model)
 ring(m, .9, 10, .52, 1.0, Color3.fromRGB(196,133,69), nil)
 ring(m, .9, 10, .25, .14, PINK, nil, -.56)
 -- Icing sits on the front; keep the center truly open.
 for i, x in {-.62,-.22,.28,.65} do
  local p = block(m,"Sprinkle",.22,.07,.06,x,if i%2==0 then .91 else -.91,-.66,if i%2==0 then CYAN else WHITE)
  p.CFrame *= CFrame.Angles(0,0,if i%2==0 then .4 else -.4)
 end
end
local function brick(m: Model)
 local red = Color3.fromRGB(163,69,55); local mortar = Color3.fromRGB(221,185,154)
 block(m,"BrickTorso",2.6,2,1.2,0,0,0,red)
 for _, y in {-.48, .1, .66} do block(m,"Mortar",2.58,.045,.04,0,y,-.62,mortar) end
 for _, entry in {{-.64,-.75},{.64,-.75},{0,-.19},{-.64,.38},{.64,.38},{0,.86}} do
  block(m,"Joint",.045,.5,.04,entry[1],entry[2],-.62,mortar)
 end
end
local function socks(m: Model)
 for _, side in {-1,1} do
  local c = if side < 0 then Color3.fromRGB(248,105,164) else Color3.fromRGB(85,210,236)
  block(m,"Sock",.55,1.15,.58,side*.55,-.1,0,c)
  block(m,"Stripe",.57,.14,.6,side*.55,.14,0,WHITE)
  block(m,"Shoe",.78,.42,1.05,side*.55,-.78,-.18,if side<0 then PURPLE else Color3.fromRGB(238,159,51))
 end
end
local function aquarium(m: Model)
 local glass = block(m,"AquariumGlass",2.1,1.55,1.35,0,.3,0,Color3.fromRGB(166,228,242)); glass.Transparency=.66; glass.Material=Enum.Material.Glass
 local water = block(m,"Water",1.84,1.02,1.1,0,.12,0,Color3.fromRGB(72,176,224)); water.Transparency=.38; water.Material=Enum.Material.Glass
 block(m,"AquariumBase",2.15,.18,1.4,0,-.49,0,Color3.fromRGB(53,94,110))
 block(m,"AquariumRim",2.15,.14,1.4,0,1.1,0,Color3.fromRGB(53,94,110))
 ball(m,"Fish",.7,.4,.28,0,.23,-.22,Color3.fromRGB(255,173,55))
 local tail=block(m,"FishTail",.3,.4,.12,.47,.23,-.22,Color3.fromRGB(255,126,48)); tail.CFrame *= CFrame.Angles(0,0,.55)
 ball(m,"FishEye",.09,.09,.06,-.18,.29,-.39,BLACK)
end
local function fridge(m: Model)
 local white=Color3.fromRGB(224,238,231)
 block(m,"Fridge",2,2.35,1.22,0,0,0,white)
 block(m,"DoorLine",1.98,.055,.04,0,.35,-.63,Color3.fromRGB(141,164,167))
 block(m,"Handle",.1,.55,.12,.7,-.1,-.71,Color3.fromRGB(97,117,128))
 block(m,"MagnetRed",.24,.24,.05,-.5,.7,-.65,PINK)
 ball(m,"MagnetBlue",.23,.23,.07,.05,.68,-.66,CYAN)
 block(m,"MagnetYellow",.2,.15,.05,-.1,-.35,-.65,Color3.fromRGB(255,208,70))
end
local function wheels(m: Model)
 local metal=Color3.fromRGB(116,132,145)
 cylinder(m,"Support",.22,.8,0,-.03,0,metal)
 block(m,"Axle",2.0,.16,.16,0,-.45,0,metal)
 for _, side in {-1,1} do
  block(m,"Fork",.14,.35,.14,side*.78,-.59,0,metal)
  local wheel=piece(m,"Wheel",Vector3.new(.28,.48,.48),Vector3.new(side*.78,-.82,0),BLACK,Enum.PartType.Cylinder)
  wheel.Material=Enum.Material.Metal
 end
end
local function spaghetti(m: Model)
 local noodle=Color3.fromRGB(250,207,100)
 for _, side in {-1,1} do
  for i=1,4 do
   local p=block(m,"Noodle",.21,.38,.22,side*(.5 + (if i%2==0 then .12 else -.08)),.35-i*.32,0,noodle)
   p.CFrame *= CFrame.Angles(0,0,side*(if i%2==0 then -.4 else .4))
  end
  ball(m,"NoodleFoot",.45,.22,.65,side*.5,-1,-.14,Color3.fromRGB(218,150,64))
 end
end
local function scream(m: Model)
 local skin=Color3.fromRGB(246,191,151)
 ball(m,"Head",2.3,1.6,1.3,0,.35,0,skin)
 eyes(m,.76,-.64,.62)
 for i,x in {-.58,0,.58} do
  ball(m,"Mouth",.38,if i==2 then .75 else .52,.13,x,.12,-.66,BLACK)
  block(m,"Teeth",.22,.07,.07,x,.29,-.75,WHITE)
 end
end
local function gym(m: Model)
 local skin=Color3.fromRGB(213,151,106)
 block(m,"Torso",1.55,1.8,1,0,0,0,skin)
 for _, side in {-1,1} do
  ball(m,"Pectoral",1.25,.9,.76,side*.6,.48,-.5,skin)
  ball(m,"Shoulder",.82,.82,.88,side*1.25,.5,0,skin)
  block(m,"TinyArm",.35,.65,.4,side*1.48,-.08,0,skin)
 end
 block(m,"Belt",1.6,.25,1.05,0,-.75,0,BLACK)
end
local function rocket(m: Model)
 for _, side in {-1,1} do
  block(m,"Boot",.75,1.0,.85,side*.56,-.03,0,Color3.fromRGB(180,195,207))
  block(m,"Toe",.78,.38,1.05,side*.56,-.35,-.18,Color3.fromRGB(225,81,71))
  cylinder(m,"Nozzle",.48,.3,side*.56,-.66,.13,BLACK)
  local flame=ball(m,"Flame",.28,.42,.28,side*.56,-1.0,.13,Color3.fromRGB(255,157,56)); neon(flame)
 end
end
local function errorHead(m: Model)
 block(m,"GlitchHead",1.8,1.4,1.15,0,.3,0,Color3.fromRGB(34,29,56))
 local visor=block(m,"Visor",1.45,.44,.1,0,.52,-.62,BLACK)
 visor.Material=Enum.Material.Neon
 for _, side in {-1,1} do
  local eye=block(m,"ErrorEye",.35,.1,.08,side*.39,.52,-.7,if side<0 then CYAN else PINK); neon(eye)
 end
 local mouth=block(m,"ErrorMouth",.7,.08,.08,-.1,.05,-.7,PINK); neon(mouth)
 for i, data in {{-.95,.96,.1},{1.05,.2,.15},{.7,1.17,.18}} do
  local shard=block(m,"Fragment",.35,.24,.35,data[1],data[2],data[3],if i%2==0 then PINK else CYAN); neon(shard)
 end
end
local function void(m: Model)
 ring(m, 1.0, 10, .32, .55, PURPLE, Enum.Material.Neon)
 local center=ball(m,"Void",1.6,1.6,.3,0,0,.12,Color3.fromRGB(12,8,25)); center.Material=Enum.Material.SmoothPlastic
 local shard=block(m,"VoidShard",.22,.22,.18,.22,.23,-.1,CYAN); neon(shard)
end
local function invert(m: Model)
 for _, side in {-1,1} do
  local leg=block(m,"InvertedLeg",.44,.85,.46,side*.53,-.24,0,Color3.fromRGB(64,44,86)); leg.CFrame *= CFrame.Angles(0,0,side*.25)
  local shoe=block(m,"FloatingShoe",.75,.3,.75,side*.65,-.98,-.1,if side<0 then CYAN else PINK); neon(shoe)
  local shard=block(m,"DigitalFragment",.18,.18,.18,side*.95,-.58,.05,PURPLE); neon(shard)
 end
end
local builders: {[string]: Builder} = {
 H_TOAST=toast,H_CONE=cone,H_AQUARIUM=aquarium,H_SCREAM=scream,H_ERROR=errorHead,
 B_DONUT=donut,B_BRICK=brick,B_FRIDGE=fridge,B_GYM=gym,B_VOID=void,
 L_ODD_SOCKS=socks,L_CHAIR_WHEELS=wheels,L_SPAGHETTI=spaghetti,L_ROCKET=rocket,L_INVERT=invert,
}
local slots: {[string]: {string}} = {
 Head={"H_TOAST","H_CONE","H_AQUARIUM","H_SCREAM","H_ERROR"},
 Body={"B_DONUT","B_BRICK","B_FRIDGE","B_GYM","B_VOID"},
 Limbs={"L_ODD_SOCKS","L_CHAIR_WHEELS","L_SPAGHETTI","L_ROCKET","L_INVERT"},
}
local function folder(parent: Instance, name: string): Folder
 local existing=parent:FindFirstChild(name)
 if existing then assert(existing:IsA("Folder"), name .. " must be a Folder"); return existing end
 local f=Instance.new("Folder"); f.Name=name; f.Parent=parent; return f
end
local function makeTemplate(slot: string, id: string): Model
 local m=Instance.new("Model"); m.Name=id
 m:SetAttribute("MutationLabGenerator",GENERATOR); m:SetAttribute("MutationLabVersion",VERSION)
 local root=piece(m,"Root",Vector3.new(1,1,1),Vector3.zero,WHITE)
 root.Transparency=1; root.CastShadow=false; m.PrimaryPart=root
 local function mount(name: string, position: Vector3)
  local a=Instance.new("Attachment"); a.Name=name; a.Position=position; a.Parent=root
 end
 if slot=="Body" then mount("HeadSocket",Vector3.new(0,1,0)); mount("LimbsSocket",Vector3.new(0,-1,0))
 else mount("RootMount",Vector3.new(0,if slot=="Head" then -.5 else .5,0)) end
 builders[id](m)
 return m
end
-- Recognize only the exact single-block templates made by the previous installers.
-- Extra geometry, attributes, altered size/color/material or mount transforms mean custom work.
local function oldPlaceholder(obj: Instance, slot: string): boolean
 if not obj:IsA("Model") or next(obj:GetAttributes()) ~= nil then return false end
 local children=obj:GetChildren()
 if #children~=1 or not children[1]:IsA("Part") then return false end
 local root=children[1] :: Part
 if root.Name~="Root" or obj.PrimaryPart~=root or next(root:GetAttributes())~=nil then return false end
 local expectedSize=if slot=="Body" then Vector3.new(2,2,2) else Vector3.new(1.5,1,1.5)
 local expectedColor=if slot=="Head" then Color3.fromRGB(255,195,75) elseif slot=="Body" then Color3.fromRGB(110,190,255) else Color3.fromRGB(180,255,140)
 if root.Size~=expectedSize or root.Color~=expectedColor or root.Transparency~=0 or root.Shape~=Enum.PartType.Block or root.Material~=Enum.Material.Plastic or root.Anchored or root.CanCollide or not root.CanTouch or not root.CanQuery or not root.CastShadow or root.Reflectance~=0 or root.CFrame~=CFrame.identity then return false end
 local expected: {[string]: Vector3} = if slot=="Body" then {HeadSocket=Vector3.new(0,1,0),LimbsSocket=Vector3.new(0,-1,0)} else {RootMount=Vector3.new(0,if slot=="Head" then -.5 else .5,0)}
 local mounts=root:GetChildren(); if #mounts~=(if slot=="Body" then 2 else 1) then return false end
 for _, a in mounts do
  if not a:IsA("Attachment") or not expected[a.Name] or a.Position~=expected[a.Name] or a.Orientation~=Vector3.zero or next(a:GetAttributes())~=nil then return false end
  expected[a.Name]=nil
 end
 return next(expected)==nil
end
function Factory.Generate(): Report
 assert(RunService:IsStudio() and not RunService:IsRunning(), "Generate assets in Studio edit mode with Play stopped")
 local assets=folder(ServerStorage,"PartAssets")
 local report: Report={created=0,upgraded=0,unchanged=0,preserved=0,failed=0}
 for slot, ids in slots do
  local destination=folder(assets,slot)
  for _, id in ids do
   local matches: {Instance}={}
   for _, child in destination:GetChildren() do if child.Name==id then table.insert(matches,child) end end
   local existing=matches[1]
   if #matches>1 then
    report.preserved+=1; warn("Mutation Lab: multiple assets named " .. slot .. "/" .. id .. "; all preserved")
   elseif existing and existing:GetAttribute("MutationLabGenerator")==GENERATOR and existing:GetAttribute("MutationLabVersion")==VERSION then
    report.unchanged+=1
   elseif existing and not (existing:GetAttribute("MutationLabGenerator")==GENERATOR or oldPlaceholder(existing,slot)) then
    report.preserved+=1; warn("Mutation Lab: preserved unrecognized custom asset " .. slot .. "/" .. id)
   else
    local built: Model?=nil
    local ok, err=pcall(function() built=makeTemplate(slot,id) end)
    if not ok or not built then
     if built then built:Destroy() end
     report.failed+=1; warn("Mutation Lab: failed to create " .. id .. ": " .. tostring(err))
    else
     if existing then existing:Destroy(); report.upgraded+=1 else report.created+=1 end
     built.Parent=destination
    end
   end
  end
 end
 return report
end
return Factory
