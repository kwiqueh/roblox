--!strict
-- The server owns all inventory and genetics; this controller only renders snapshots.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
-- A second copy must not bind another set of buttons or remote requests.
if playerGui:FindFirstChild("MutationLabUI") then return end
local gui = Instance.new("ScreenGui")
gui.Name = "MutationLabUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 10
gui.Parent = playerGui

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PartCatalog"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getState = remotes:WaitForChild("GetCreatureState") :: RemoteFunction
local breedRemote = remotes:WaitForChild("BreedCreature") :: RemoteFunction
local discardRemote = remotes:WaitForChild("DiscardCreature") :: RemoteFunction

type Genes = {Head: string, Body: string, Limbs: string}
type Creature = {id: string, genes: Genes, bornAt: number, parents: {string}}
type Snapshot = {success: boolean, code: string, message: string, creatures: {Creature}, occupiedSlots: {[string]: string}, inventoryVersion: number, maxSlots: number}
type Operation = {success: boolean, code: string, message: string, inventoryVersion: number, creature: Creature?, slotIndex: number?}
local COLOR = {
 background = Color3.fromRGB(12, 19, 34), panel = Color3.fromRGB(22, 33, 53), card = Color3.fromRGB(32, 46, 68),
 text = Color3.fromRGB(235, 245, 252), muted = Color3.fromRGB(158, 181, 199), cyan = Color3.fromRGB(44, 223, 220),
 danger = Color3.fromRGB(231, 81, 119), Common = Color3.fromRGB(165, 177, 189), Rare = Color3.fromRGB(69, 171, 255),
 Insane = Color3.fromRGB(205, 98, 255), Glitched = Color3.fromRGB(255, 83, 139),
}
local TEXT = {
 hint = "Select two creatures to create your first mutant.",
 rules = "Each gene: 45% parent A  •  45% parent B  •  10% mutation roll",
 capacity = "Laboratory full. Discard a creature to make room.",
 minimum = "Keep at least two creatures so you can keep breeding.",
}
local rank: {[string]: number} = {Common = 1, Rare = 2, Insane = 3, Glitched = 4}
local tiers = {"Common", "Rare", "Insane", "Glitched"}
local snapshot: Snapshot? = nil
local minimumVersion = 0
local parentA: string? = nil
local parentB: string? = nil
local chosen: string? = nil
local mode = ""
local chooseTarget = ""
local busy = false
local revealToken = 0

local function corner(parent: Instance, radius: number)
 local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, radius); c.Parent = parent
end
local function stroke(parent: Instance, color: Color3): UIStroke
 local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = 1.5; s.Parent = parent; return s
end
local function label(parent: Instance, text: string, size: number, color: Color3): TextLabel
 local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = color
 l.Font = Enum.Font.GothamMedium; l.TextSize = size; l.TextWrapped = true; l.Parent = parent; return l
end
local function button(parent: Instance, text: string, color: Color3): TextButton
 local b = Instance.new("TextButton"); b.Text = text; b.BackgroundColor3 = color; b.TextColor3 = COLOR.text
 b.Font = Enum.Font.GothamBold; b.TextSize = 16; b.AutoButtonColor = true; corner(b, 10); b.Parent = parent
 b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0.15}):Play() end)
 b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play() end)
 return b
end
local function setEnabled(b: TextButton, enabled: boolean)
 b.Active = enabled; b.AutoButtonColor = enabled; b.TextTransparency = if enabled then 0 else 0.5
 b.BackgroundColor3 = if enabled then COLOR.cyan else COLOR.card
 b.TextColor3 = if enabled then COLOR.background else COLOR.muted
end
local function rarity(c: Creature): string
 local highest = 1
 for _, id in {c.genes.Head, c.genes.Body, c.genes.Limbs} do
  local part = Catalog.Parts[id]
  if part and rank[part.tier] then highest = math.max(highest, rank[part.tier]) end
 end
 return tiers[highest]
end
local function rarityColor(tier: string): Color3
 if tier == "Glitched" then return COLOR.Glitched elseif tier == "Insane" then return COLOR.Insane elseif tier == "Rare" then return COLOR.Rare end
 return COLOR.Common
end
local function describe(c: Creature): string
 return "MUTANT #" .. string.upper(string.sub(c.id, 1, 4)) .. "\nHEAD: " .. c.genes.Head .. "\nBODY: " .. c.genes.Body .. "\nLIMBS: " .. c.genes.Limbs .. "\n" .. string.upper(rarity(c))
end
local function findCreature(id: string?): Creature?
 if not id or not snapshot then return nil end
 for _, c in snapshot.creatures do if c.id == id then return c end end
 return nil
end

local top = Instance.new("Frame"); top.Size = UDim2.new(1, -24, 0, 56); top.Position = UDim2.fromOffset(12, 8); top.BackgroundColor3 = COLOR.background; top.Parent = gui; corner(top, 12)
local title = label(top, "MUTATION LAB", 19, COLOR.cyan); title.Font = Enum.Font.GothamBold; title.TextXAlignment = Enum.TextXAlignment.Left; title.Position = UDim2.fromOffset(14, 0); title.Size = UDim2.new(0.5, -10, 1, 0)
local status = label(top, "LAB LOADING", 14, COLOR.muted); status.TextXAlignment = Enum.TextXAlignment.Right; status.Position = UDim2.new(0.5, 0, 0, 0); status.Size = UDim2.new(0.5, -14, 1, 0)
local controls = Instance.new("Frame"); controls.BackgroundTransparency = 1; controls.Size = UDim2.new(1, -24, 0, 52); controls.Position = UDim2.new(0, 12, 1, -64); controls.Parent = gui
local controlsLayout = Instance.new("UIListLayout"); controlsLayout.FillDirection = Enum.FillDirection.Horizontal; controlsLayout.Padding = UDim.new(0, 8); controlsLayout.Parent = controls
local breedButton = button(controls, "BREED", COLOR.cyan); breedButton.TextColor3 = COLOR.background
local collectionButton = button(controls, "COLLECTION", COLOR.panel)
local discardButton = button(controls, "DISCARD", COLOR.panel)
for _, b in {breedButton, collectionButton, discardButton} do b.Size = UDim2.new(1/3, -6, 1, 0); b.TextScaled = true; local limit = Instance.new("UITextSizeConstraint"); limit.MaxTextSize = 17; limit.MinTextSize = 10; limit.Parent = b end
local hint = button(gui, TEXT.hint .. "  ×", COLOR.panel); hint.Size = UDim2.new(1, -32, 0, 48); hint.Position = UDim2.new(0, 16, 0, 70); hint.TextSize = 14
hint.Activated:Connect(function() hint.Visible = false end)
local toast = label(gui, "", 15, COLOR.text); toast.Size = UDim2.new(1, -40, 0, 42); toast.Position = UDim2.new(0, 20, 1, -115); toast.BackgroundColor3 = COLOR.panel; toast.BackgroundTransparency = 0.05; toast.Visible = false; corner(toast, 10)
local toastVersion = 0
local function notify(message: string)
 toastVersion += 1; local version = toastVersion; toast.Text = message; toast.Visible = true
 task.delay(4, function() if toastVersion == version then toast.Visible = false end end)
end
local overlay = Instance.new("Frame"); overlay.Size = UDim2.fromScale(1, 1); overlay.BackgroundColor3 = Color3.new(0, 0, 0); overlay.BackgroundTransparency = 0.35; overlay.Visible = false; overlay.Parent = gui
local panel = Instance.new("Frame"); panel.AnchorPoint = Vector2.new(0.5, 0.5); panel.Position = UDim2.fromScale(0.5, 0.5); panel.Size = UDim2.new(0.94, 0, 0.88, 0); panel.BackgroundColor3 = COLOR.background; panel.Parent = overlay; corner(panel, 16); stroke(panel, COLOR.card)
local sizeLimit = Instance.new("UISizeConstraint"); sizeLimit.MaxSize = Vector2.new(780, 650); sizeLimit.Parent = panel
local heading = label(panel, "", 20, COLOR.text); heading.Font = Enum.Font.GothamBold; heading.TextXAlignment = Enum.TextXAlignment.Left; heading.Position = UDim2.fromOffset(18, 4); heading.Size = UDim2.new(1, -76, 0, 48)
local close = button(panel, "×", COLOR.card); close.Size = UDim2.fromOffset(42, 40); close.Position = UDim2.new(1, -50, 0, 8); close.TextSize = 24
local content = Instance.new("ScrollingFrame"); content.Position = UDim2.fromOffset(12, 54); content.Size = UDim2.new(1, -24, 1, -66); content.BackgroundTransparency = 1; content.BorderSizePixel = 0; content.ScrollBarThickness = 5; content.AutomaticCanvasSize = Enum.AutomaticSize.Y; content.CanvasSize = UDim2.new(); content.Parent = panel
local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0, 10); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = content
local function clearContent()
 for _, item in content:GetChildren() do if item ~= list then item:Destroy() end end
 content.CanvasPosition = Vector2.zero
end
local function rowLabel(text: string, height: number, color: Color3?): TextLabel
 local l = label(content, text, 14, color or COLOR.muted); l.Size = UDim2.new(1, -8, 0, height); return l
end
local function wideButton(text: string, height: number): TextButton
 local b = button(content, text, COLOR.card); b.Size = UDim2.new(1, -8, 0, height); return b
end
local function stateMessage(code: string, fallback: string): string
 local messages: {[string]: string} = {NOT_READY = "Lab is loading. Try again shortly.", INVALID_REQUEST = "Invalid request. Please try again.", INVALID_PARENT = "Choose two different creatures.", PARENT_NOT_FOUND = "Creature is no longer in your collection.", STALE_STATE = "Collection changed; refreshing.", CAPACITY_FULL = TEXT.capacity, BUSY = "Another action is in progress.", COOLDOWN = "Please wait a moment before breeding again.", ASSET_MISSING = "Could not create this creature. Please try again.", ASSEMBLY_FAILED = "Could not create this creature. Please try again.", MINIMUM_CREATURES = TEXT.minimum, INTERNAL_ERROR = "Something went wrong. Please try again."}
 return messages[code] or fallback
end
local function applySnapshot(nextState: Snapshot)
 if nextState.inventoryVersion < minimumVersion or (snapshot and nextState.inventoryVersion < snapshot.inventoryVersion) then return end
 minimumVersion = nextState.inventoryVersion
 snapshot = nextState
 if not findCreature(parentA) then parentA = nil end
 if not findCreature(parentB) then parentB = nil end
 if not findCreature(chosen) then chosen = nil end
 status.Text = tostring(#nextState.creatures) .. " / " .. tostring(nextState.maxSlots) .. "   •   LAB ONLINE"
end
-- All invocations share one guard, so refreshes cannot overtake mutations.
local function refresh(): boolean
 local ok, response = pcall(function() return getState:InvokeServer() end)
 if not ok or type(response) ~= "table" then notify("Cannot reach the lab. Please retry."); return false end
 local data: Snapshot = response
 if not data.success then status.Text = "LAB LOADING"; notify(stateMessage(data.code, "Lab not ready. Please retry.")); return false end
 applySnapshot(data); return true
end
local render: () -> ()
local function open(newMode: string)
 if busy then return end
 mode = newMode; overlay.Visible = true; busy = true; render()
 task.spawn(function() refresh(); busy = false; if overlay.Visible and mode == newMode then render() end end)
end
local function refreshThenRender()
 if busy then return end
 busy = true; refresh(); busy = false; render()
end
local function runReveal(creature: Creature)
 revealToken += 1; local token = revealToken; mode = "reveal"; overlay.Visible = true; clearContent(); heading.Text = "MUTATION CHAMBER"
 local tier = rarity(creature); local color = rarityColor(tier)
 rowLabel("INCUBATING  •  GENETIC SEQUENCE STABLE", 40, color)
 local chamber = label(content, "◉", 80, color); chamber.Size = UDim2.new(1, -8, 0, 150)
 local scale = Instance.new("UIScale"); scale.Parent = chamber
 TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true), {Scale = 1.2}):Play()
 local skip = wideButton("SKIP", 48)
 local function finish()
  if revealToken ~= token or mode ~= "reveal" then return end
  revealToken += 1; clearContent(); heading.Text = "NEW MUTANT DISCOVERED!"
  for _, item in {{"HEAD", creature.genes.Head}, {"BODY", creature.genes.Body}, {"LIMBS", creature.genes.Limbs}} do
   local definition = Catalog.Parts[item[2]]
   local geneTier = if definition then definition.tier else "Common"
   local result = rowLabel(item[1] .. ": " .. item[2] .. "  •  " .. string.upper(geneTier) .. (if geneTier == tier then "  ★" else ""), 42, rarityColor(geneTier))
   result.TextSize = 16; result.Font = Enum.Font.GothamBold
   if geneTier == "Glitched" then TweenService:Create(result, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), {TextColor3 = COLOR.Insane}):Play() end
  end
  rowLabel(if tier == "Glitched" then "GLITCHED  •  RARE GENETIC SIGNATURE" else "HIGHEST RARITY: " .. string.upper(tier), 45, color)
  local done = wideButton("CONTINUE", 52); setEnabled(done, true); done.Activated:Connect(function() mode = "collection"; render() end)
 end
 skip.Activated:Connect(finish)
 task.delay(1.1, function() if revealToken == token and mode == "reveal" then chamber.Text = "✧  ◉  ✧"; heading.Text = "GENETIC ENERGY RISING" end end)
 task.delay(2.4, finish)
end
local function doBreed()
 if busy or not snapshot or not parentA or not parentB or parentA == parentB or #snapshot.creatures >= snapshot.maxSlots then return end
 busy = true; render()
 local current = snapshot; local a, b = parentA, parentB
 local ok, response = pcall(function() return breedRemote:InvokeServer({parentAId = a, parentBId = b, expectedInventoryVersion = current.inventoryVersion}) end)
 local result: Operation? = if ok and type(response) == "table" then response else nil
 if result and result.success and result.creature then
  -- Refresh after the server commits; never fabricate a client-side creature.
  minimumVersion = result.inventoryVersion; snapshot = nil; status.Text = "SYNCING..."
  refresh(); busy = false; runReveal(result.creature); return
 end
 if result and (result.code == "STALE_STATE" or result.code == "PARENT_NOT_FOUND") then refresh() end
 busy = false; notify(if result then stateMessage(result.code, result.message) else "Cannot reach the lab. Please retry."); render()
end
local function doDiscard()
 if busy or not snapshot or not chosen then return end
 busy = true; render()
 local current = snapshot; local id = chosen
 local ok, response = pcall(function() return discardRemote:InvokeServer({creatureId = id, expectedInventoryVersion = current.inventoryVersion}) end)
 local result: Operation? = if ok and type(response) == "table" then response else nil
 if result and result.success then
  chosen = nil; minimumVersion = result.inventoryVersion; snapshot = nil; status.Text = "SYNCING..."
  refresh(); mode = "discard"; notify("Creature discarded")
 elseif result and (result.code == "STALE_STATE" or result.code == "PARENT_NOT_FOUND") then refresh(); mode = "discard"; notify("Collection refreshed. " .. stateMessage(result.code, result.message))
 else notify(if result then stateMessage(result.code, result.message) else "Cannot reach the lab. Please retry.") end
 busy = false; render()
end
local function drawCards(selectable: boolean)
 local grid = Instance.new("Frame"); grid.BackgroundTransparency = 1; grid.Size = UDim2.new(1, -8, 0, 390); grid.Parent = content
 local layout = Instance.new("UIGridLayout"); layout.CellPadding = UDim2.fromOffset(8, 8); layout.CellSize = UDim2.new(0.5, -4, 0, 120); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = grid
 local function resize()
  local columns = if grid.AbsoluteSize.X >= 560 then 3 else 2
  layout.CellSize = UDim2.new(1 / columns, -6, 0, 120)
  grid.Size = UDim2.new(1, -8, 0, math.ceil(6 / columns) * 128)
 end
 grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize); resize()
 for slot = 1, 6 do
  local id = if snapshot then snapshot.occupiedSlots[tostring(slot)] else nil
  local creature = findCreature(id)
  local card = button(grid, if creature then "SLOT " .. slot .. "\n" .. describe(creature) else "SLOT " .. slot .. "\nEMPTY SLOT", COLOR.card)
  card.LayoutOrder = slot; card.TextSize = 12; card.TextWrapped = true
  local border = stroke(card, if creature then rarityColor(rarity(creature)) else COLOR.card)
  if creature and (creature.id == parentA or creature.id == parentB or creature.id == chosen) then border.Color = COLOR.cyan; border.Thickness = 3 end
  card.Active = selectable and creature ~= nil and not busy
  if creature and selectable then
   card.Activated:Connect(function()
    if busy then return end
    if mode == "choose" then
     if (chooseTarget == "A" and parentB == creature.id) or (chooseTarget == "B" and parentA == creature.id) then notify("Choose two different creatures."); return end
     if chooseTarget == "A" then parentA = creature.id else parentB = creature.id end
     mode = "breed"; render()
    elseif mode == "discard" then chosen = creature.id; mode = "confirm"; render() end
   end)
  end
 end
end
render = function()
 clearContent()
 if mode == "breed" then
  heading.Text = "BREEDING LAB"
  rowLabel(TEXT.rules, 48)
  local a = findCreature(parentA); local b = findCreature(parentB)
  local aButton = wideButton(if a then "PARENT A\n" .. describe(a) else "SELECT PARENT A  +", 105)
  local bButton = wideButton(if b then "PARENT B\n" .. describe(b) else "SELECT PARENT B  +", 105)
  for _, v in {aButton, bButton} do v.TextSize = 13; v.TextWrapped = true end
  if a then stroke(aButton, rarityColor(rarity(a))) end; if b then stroke(bButton, rarityColor(rarity(b))) end
  aButton.Activated:Connect(function() if not busy then chooseTarget = "A"; mode = "choose"; render() end end)
  bButton.Activated:Connect(function() if not busy then chooseTarget = "B"; mode = "choose"; render() end end)
  local full = snapshot ~= nil and #snapshot.creatures >= snapshot.maxSlots
  rowLabel(if full then TEXT.capacity else "Choose two different creatures from your collection.", 40, if full then COLOR.danger else COLOR.muted)
  local go = wideButton(if busy then "PLEASE WAIT..." else "BREED NOW", 54)
  setEnabled(go, not busy and a ~= nil and b ~= nil and parentA ~= parentB and not full); go.Activated:Connect(doBreed)
 elseif mode == "choose" then
  heading.Text = "CHOOSE PARENT " .. chooseTarget; rowLabel("Tap a creature to select it.", 28); drawCards(true)
  local back = wideButton("BACK", 44); back.Activated:Connect(function() if not busy then mode = "breed"; render() end end)
 elseif mode == "collection" or mode == "discard" then
  heading.Text = if mode == "collection" then "YOUR COLLECTION" else "DISCARD A CREATURE"
  rowLabel(if mode == "discard" then "Select a creature to review before discarding." else "Your current laboratory collection.", 34)
  drawCards(mode == "discard")
  local retry = wideButton("REFRESH COLLECTION", 44); setEnabled(retry, not busy); retry.Activated:Connect(refreshThenRender)
 elseif mode == "confirm" then
  heading.Text = "DISCARD MUTANT?"
  local creature = findCreature(chosen)
  if creature then
   rowLabel(describe(creature), 150, rarityColor(rarity(creature)))
   local tier = rarity(creature)
   rowLabel(if tier == "Insane" or tier == "Glitched" then "WARNING: This creature is " .. string.upper(tier) .. ". It will be permanently removed from this session." else "This creature will be permanently removed from your current collection.", 68, COLOR.danger)
   local confirm = wideButton(if busy then "PLEASE WAIT..." else "CONFIRM DISCARD", 54); setEnabled(confirm, not busy); confirm.Activated:Connect(doDiscard)
  else rowLabel("Creature no longer found. Refresh your collection.", 55) end
  local cancel = wideButton("CANCEL", 48); cancel.Activated:Connect(function() if not busy then mode = "discard"; render() end end)
 end
end
close.Activated:Connect(function() if busy then return end; revealToken += 1; overlay.Visible = false; mode = "" end)
breedButton.Activated:Connect(function() open("breed") end)
collectionButton.Activated:Connect(function() open("collection") end)
discardButton.Activated:Connect(function() open("discard") end)
-- Starter initialization can complete after the client starts; bounded retries, never breed automatically.
task.spawn(function()
 for _ = 1, 12 do
  if snapshot then break end
  if not busy then busy = true; local loaded = refresh(); busy = false; if loaded then break end end
  task.wait(1)
 end
end)
