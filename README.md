# roblox

# Creature breeding backend

This is a session-only implementation: collections are lost when the player leaves or the server stops. It does not add a DataStore.

## Studio setup and required dependencies

1. Place `CreatureAssembler.lua` and `BreedingServerManager.lua` as ModuleScripts in `ServerScriptService.Services`; place `ServerBootstrap.server.lua` as a Script in `ServerScriptService`.
2. Provide `ReplicatedStorage.Shared.PartCatalog` with `Parts[id].Slot` equal to `"Head"`, `"Body"`, or `"Limbs"`. **This schema is an explicit integration assumption**: the repository contained no catalog, so the actual entry field cannot be verified. Adapt the two catalog lookups if the real catalog differs.
3. Provide `ServerScriptService.Services.BreedingService` exposing `Breed(parentA, parentB)` returning a new serializable Creature with a globally unique server-generated ID, integer Unix timestamp, the selected parent IDs in order, and catalog-valid genes. Its inheritance and mutation probabilities must implement the specified genetics. This repository contains no genetics engine, so its behavior cannot be verified here.
4. Create `ServerStorage.PartAssets` with `Head`, `Body`, and `Limbs` folders. Each gene ID must name a Model in its matching folder. Every Model must have a `Root` BasePart set as PrimaryPart. Body Root needs `HeadSocket` and `LimbsSocket` Attachments; the other Roots need `RootMount`. All attachments describe both position and orientation. Source assets must be archivable and contain no joints, constraints, scripts, or Humanoids; geometry is welded to the body root during assembly. Supply all catalog assets, including the starter genes `H_TOAST`, `H_CONE`, `B_DONUT`, `B_BRICK`, and `L_ODD_SOCKS`.
5. For production, create `Workspace.Laboratories` as a Folder with a Model per plot, `OwnerUserId` numeric attribute, and `SpawnPoints` containing anchored BaseParts `Spawn1` through `Spawn6`. When the folder is absent, a demo plot is created only in Studio; disable it with `ENABLE_DEMO`. `ActiveCreatures` and both RemoteFunctions under `ReplicatedStorage.Remotes` are created as needed. Existing instances with wrong classes are rejected.
6. Start a Studio local server with at least two players (Test > Server & Clients). Use `examples/BreedClient.client.lua` as an example LocalScript; wait until initialization finishes before calling it. The two starters commit together at inventory version 1. Slot dictionary keys in the remote state are strings `"1"` through `"6"`, to support sparse serializable dictionaries.

The manager's server-only `RespawnCreature(player, id)` can restore a missing decorative model without altering inventory. `Stop()` removes its session state, models and demo plots. The system does not persist data. The genetics engine is trusted server code and must not mutate inputs; defensive copies are passed to it.

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
