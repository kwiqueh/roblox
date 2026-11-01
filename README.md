# Mutation Lab V0.3

A session-only Roblox creature collection MVP. Players start with two creatures, select two parents in the GUI, breed, see the server-generated result and discard unwanted creatures (while keeping at least two). Collection progress is not saved across sessions.

## Update an existing Studio place

1. Open `MutationLab.rbxl` in Roblox Studio and stop any active Play session. Save a backup with **File > Save As**.
2. Open [InstallMVP.commandbar.lua](https://github.com/kwiqueh/roblox/blob/feature/mutation-lab-v0.3/examples/InstallMVP.commandbar.lua) on GitHub and copy its entire text (use the Raw button to see plain text).
3. In Studio, open **View > Command Bar**, paste the full script there and press Enter. Allow the network request if prompted. Check **View > Output** for `MUTATION LAB V0.3 INSTALLED` or an error. The installer must fetch source from GitHub; make the repository publicly readable or otherwise make those raw URLs accessible to Studio.
4. Save the place. Press **Play**. You should see `2 / 6`; open **BREED**, select parents A and B, then **BREED NOW**. There is no automatic breeding on join. **COLLECTION** displays the current inventory; **DISCARD** offers confirmation and keeps at least two creatures.

The installer updates exact script names, disables `BreedClient`, installs the edit-time `CreatureAssetFactory`, and generates 15 modular models. It upgrades only recognizable legacy single-block placeholders or older models marked by this factory. Unrecognized models and duplicate asset names are preserved and listed in Output; inspect them if an expected creature still appears as a cube. Existing custom models, attachments and plots are preserved. Reinstalling in edit mode keeps current generated assets. It installs `PartCatalog`, `BreedingService`, `CreatureAssembler`, `BreedingServerManager`, `ServerBootstrap`, `CreatureLabUI`, and the factory. The server creates the three RemoteFunctions at runtime. When no production `Workspace.Laboratories` folder exists, Studio uses demo plots. Existing production plots need an `OwnerUserId` attribute and `SpawnPoints/Spawn1`–`Spawn6` anchored parts. Templates are built in edit mode and cloned at runtime; no runtime HTTP or uploaded assets are needed. All parts share attachment conventions: a `Root` PrimaryPart with `HeadSocket`/`LimbsSocket` on bodies or `RootMount` on heads and limbs.

## Verification in Studio

The official Luau parser accepted the changed files. A Luau test with mocked Roblox objects checked all 15 generated IDs, mounts, repeat generation, legacy replacement, and custom preservation. This does not validate Roblox rendering or Studio APIs. Studio runtime, physical assembly, visual quality, mobile UI, Roblox-aware strict diagnostics and multiplayer tests were not executed in this environment. In Studio, verify:

- Run the installer twice; confirm generated/upgraded counts in Output, 15 distinct models and no duplicates. Inspect any preserved-asset warnings.
- Two visibly distinct starters and no automatic third; select distinct parents and breed once.
- Try mixed parts, verify joins and labels, and inspect the reveal for legible text and correct rarity.
- Reveal genes match the newly added creature; breed to six and confirm capacity protection.
- Discard a creature, verify its model disappears and the vacant slot is reused; at two creatures discard must fail.
- Retry after failed requests, close and reopen panels, and test stale versions and rapid clicks.
- Run a two-player server and verify cross-player breed/discard attempts fail.
- Test 1440×900, 1280×720, and mobile viewport sizes with chat expanded, the player list visible, and touch input. Verify card borders, text, scrolling, and panel headings. Run the installer twice and confirm no duplicate scripts or altered models.

Catalog entries use lowercase `slot`, `tier`, and `weight`. Genetics and probabilities remain in `BreedingService` and `PartCatalog`.
