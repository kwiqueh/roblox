# Mutation Lab V0.2

A session-only Roblox creature collection MVP. Players start with two creatures, select two parents in the GUI, breed, see the server-generated result and discard unwanted creatures (while keeping at least two). Collection progress is not saved across sessions.

## Update an existing Studio place

1. Open `MutationLab.rbxl` in Roblox Studio and stop any active Play session. Save a backup with **File > Save As**.
2. Open [InstallMVP.commandbar.lua](https://github.com/kwiqueh/roblox/blob/feature/mutation-lab-v0.2/examples/InstallMVP.commandbar.lua) on GitHub and copy its entire text (use the Raw button to see plain text).
3. In Studio, open **View > Command Bar**, paste the full script there and press Enter. Allow the network request if prompted. Check **View > Output** for `MUTATION LAB V0.2 INSTALLED` or an error. The installer must fetch source from GitHub; make the repository publicly readable or otherwise make those raw URLs accessible to Studio.
4. Save the place. Press **Play**. You should see `2 / 6`; open **BREED**, select parents A and B, then **BREED NOW**. There is no automatic breeding on join. **COLLECTION** displays the current inventory; **DISCARD** offers confirmation and keeps at least two creatures.

The installer updates exact script names, disables `BreedClient`, and creates only missing placeholder assets. Existing models, attachments and plots remain in place. It is safe to run again in edit mode. It installs `PartCatalog`, `BreedingService`, `CreatureAssembler`, `BreedingServerManager`, `ServerBootstrap` and `CreatureLabUI`. The server creates the three RemoteFunctions at runtime. When no production `Workspace.Laboratories` folder exists, Studio uses demo plots. Existing production plots need an `OwnerUserId` attribute and `SpawnPoints/Spawn1`–`Spawn6` anchored parts. See `examples/GeneratePlaceholderAssets.commandbar.lua` for the asset layout.

## Verification in Studio

Studio runtime, mobile UI, strict Roblox type diagnostics and multiplayer tests were not executed in this environment. In Studio, verify:

- Two starters and no automatic third; select distinct parents and breed once.
- Reveal genes match the newly added creature; breed to six and confirm capacity protection.
- Discard a creature, verify its model disappears and the vacant slot is reused; at two creatures discard must fail.
- Retry after failed requests, close and reopen panels, and test stale versions and rapid clicks.
- Run a two-player server and verify cross-player breed/discard attempts fail.
- Test small mobile viewport sizes and touch input. Run the installer twice and confirm no duplicate scripts or altered models.

Catalog entries use lowercase `slot`, `tier`, and `weight`. Genetics and probabilities remain in `BreedingService` and `PartCatalog`.
