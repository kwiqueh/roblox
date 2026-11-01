--!strict
-- Public, immutable catalog contract: the field name is LOWERCASE "slot".
-- Creature instances store only the IDs defined in Parts.

export type Slot = "Head" | "Body" | "Limbs"
export type Tier = "Common" | "Rare" | "Insane" | "Glitched"
export type PartDefinition = {slot: Slot, tier: Tier, weight: number}
export type TierDefinition = {id: Tier, weight: number}
export type Catalog = {
    Slots: {Slot},
    Tiers: {TierDefinition},
    Parts: {[string]: PartDefinition},
}

local catalog: Catalog = {
    Slots = {"Head", "Body", "Limbs"},
    -- The 10% mutation branch uses these weights (sum: 1,000,000).
    -- A Glitched mutation occurs at 10/1,000,000 within that branch.
    Tiers = {
        {id = "Common", weight = 900000},
        {id = "Rare", weight = 90000},
        {id = "Insane", weight = 9990},
        {id = "Glitched", weight = 10},
    },
    -- Part weights are conditional on the chosen rarity and body slot.
    Parts = {
        -- Common
        H_TOAST = {slot = "Head", tier = "Common", weight = 70},
        H_CONE = {slot = "Head", tier = "Common", weight = 30},
        B_DONUT = {slot = "Body", tier = "Common", weight = 100},
        B_BRICK = {slot = "Body", tier = "Common", weight = 100},
        L_ODD_SOCKS = {slot = "Limbs", tier = "Common", weight = 100},

        -- Rare
        H_AQUARIUM = {slot = "Head", tier = "Rare", weight = 100},
        B_FRIDGE = {slot = "Body", tier = "Rare", weight = 100},
        L_CHAIR_WHEELS = {slot = "Limbs", tier = "Rare", weight = 60},
        L_SPAGHETTI = {slot = "Limbs", tier = "Rare", weight = 40},

        -- Insane
        H_SCREAM = {slot = "Head", tier = "Insane", weight = 100},
        B_GYM = {slot = "Body", tier = "Insane", weight = 100},
        L_ROCKET = {slot = "Limbs", tier = "Insane", weight = 100},

        -- Glitched
        H_ERROR = {slot = "Head", tier = "Glitched", weight = 100},
        B_VOID = {slot = "Body", tier = "Glitched", weight = 100},
        L_INVERT = {slot = "Limbs", tier = "Glitched", weight = 100},
    },
}

return catalog
