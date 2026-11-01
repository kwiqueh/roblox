# Roblox creature breeding MVP

This repository includes the **PartCatalog**, **BreedingService**, **CreatureAssembler**, and **BreedingServerManager**. Inventories are SESSION-ONLY (no DataStore yet).

## Quick setup in Roblox Studio

1. Create **ReplicatedStorage > Shared** and insert `ReplicatedStorage/Shared/PartCatalog.lua` as a ModuleScript named `PartCatalog`.
2. Create **ServerScriptService > Services** and insert the three ModuleScripts from `ServerScriptService/Services`, preserving their exact names.
3. Insert `ServerScriptService/ServerBootstrap.server.lua` into **ServerScriptService** as a normal Script.
4. Open **View > Command Bar**, paste and run `examples/GeneratePlaceholderAssets.commandbar.lua` **while not playing**. It creates all 15 catalog assets in `ServerStorage.PartAssets`. These are temporary cubes, not final art.
5. Insert `examples/BreedClient.client.lua` as a LocalScript in **StarterPlayer > StarterPlayerScripts**.
6. Press **Play**. In Studio without a production Laboratories folder, demo plots are generated. Two starter creatures appear and the sample client requests a third. Inspect **Output** for errors.

**Schema:** catalog entries use lowercase `slot`, `tier` and `weight`. Both runtime modules use `entry.slot`.

All placeholder models have a `Root` BasePart set as `PrimaryPart`. The Body Root has `HeadSocket` and `LimbsSocket`; Head/Limbs Roots have `RootMount`. No preexisting constraints, joints, scripts or Humanoids are included.

**Not verified in Roblox Studio:** runtime behavior, strict diagnostics, and multiplayer acceptance tests still need execution in Studio. The files have been reviewed for schema consistency; this is not a claim of a successful Studio run.

## Detailed setup and test checklist

## Acceptance checklist

No Roblox Studio, assets, catalog or genetics engine were available in this workspace. None of the following runtime checks has been executed; perform them in Studio after adding the missing dependencies:

- [ ] A: Join and confirm two unique starters, slots 1–2, visible assembly and animation.
- [ ] B: Breed them and verify valid genes, parents, slot 3 and incremented version.
- [ ] C: Breed to six (wait 1.5 seconds between successful requests); verify the next returns `CAPACITY_FULL` with no seventh model.
- [ ] D: Submit a missing parent ID and verify no change.
- [ ] E: Send simultaneous requests at five creatures and verify at most one success.
- [ ] F: Remove a required asset and verify rollback and no occupied slot.
- [ ] G: Remove a required attachment and verify an error and cleanup.
- [ ] H: With two players, try breeding using the other player's IDs and verify isolation.
- [ ] I: Disconnect a player during a request; verify models and demo plot are cleaned up.
- [ ] J: Inspect both modules with Studio's strict type checker and fix any reported integration or Roblox API type issues.
- [ ] K: Observe 48 creatures over time; verify no drift, falling geometry or accumulating connections.
- [ ] L: Force publication/assembly failure and verify inventory, slot and version rollback and lock release.

Static review covers ownership checks, lock/rollback paths, client input validation and a shared animation registry; it is not a substitute for these tests or the Studio type checker.

Verification performed in this workspace: all four Luau sources parsed without syntax errors using the official Luau parser built from source. Roblox-aware strict type checking and all runtime scenarios remain untested.
