--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PartCatalog"))
type Slot = "Head" | "Body" | "Limbs"
type GeneData = {Head: string, Body: string, Limbs: string}
type Creature = {id: string, genes: GeneData, bornAt: number, parents: {string}}
local rng = Random.new()
local BreedingService = {}

local function choosePart(slot: Slot, tier: string): string
    local total = 0
    for _, definition in Catalog.Parts do
        if definition.slot == slot and definition.tier == tier then
            total += definition.weight
        end
    end
    assert(total > 0, "No eligible parts for " .. slot .. "/" .. tier)
    local roll = rng:NextInteger(1, total)
    -- Sort IDs to ensure deterministic iteration, independent of table hash order.
    local ids: {string} = {}
    for id, definition in Catalog.Parts do
        if definition.slot == slot and definition.tier == tier then
            table.insert(ids, id)
        end
    end
    table.sort(ids)
    for _, id in ids do
        roll -= Catalog.Parts[id].weight
        if roll <= 0 then return id end
    end
    error("Invalid part weights")
end

local function mutation(slot: Slot): string
    local total = 0
    for _, tier in Catalog.Tiers do total += tier.weight end
    assert(total == 1000000, "Tier weights must total 1,000,000")
    local roll = rng:NextInteger(1, total)
    for _, tier in Catalog.Tiers do
        roll -= tier.weight
        if roll <= 0 then return choosePart(slot, tier.id) end
    end
    error("Invalid tier weights")
end

local function inherit(id: string, slot: Slot): string
    local definition = Catalog.Parts[id]
    assert(definition ~= nil and definition.slot == slot, "Invalid parent gene")
    if definition.tier == "Glitched" and rng:NextInteger(1, 100) > 5 then
        return choosePart(slot, "Common")
    end
    return id
end

function BreedingService.Breed(a: Creature, b: Creature): Creature
    local genes: GeneData = {Head = "", Body = "", Limbs = ""}
    for _, slot in Catalog.Slots do
        local roll = rng:NextInteger(1, 100)
        if roll <= 45 then
            genes[slot] = inherit(a.genes[slot], slot)
        elseif roll <= 90 then
            genes[slot] = inherit(b.genes[slot], slot)
        else
            genes[slot] = mutation(slot)
        end
    end
    return {
        id = HttpService:GenerateGUID(false),
        genes = genes,
        bornAt = os.time(),
        parents = {a.id, b.id},
    }
end

return BreedingService
