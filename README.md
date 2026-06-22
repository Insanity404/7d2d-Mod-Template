<div align="center">

<!-- 💡 SUGGESTED IMAGE: A dark, apocalyptic banner - burnt orange sky, crumbling buildings,
     with bold text "7 Days to Die Mod Template" and a subtitle "Mod. Validate. Survive."
     Recommended size: 1200×400px. Save as docs/banner.png and uncomment the line below. -->
<!-- <img src="docs/banner.png" alt="7 Days to Die Mod Template" width="100%" /> -->

# 🧟 7 Days to Die Mod Template


**A smooth, VS Code–powered development environment for building XML and DLL (Harmony) mods.**

Validate your XML patches, build and deploy C# Harmony DLLs, and iterate fast—all from your editor.

[![VS Code](https://img.shields.io/badge/VS%20Code-Ready-007ACC?logo=visualstudiocode&logoColor=white)](https://code.visualstudio.com/)
[![7 Days to Die](https://img.shields.io/badge/7%20Days%20to%20Die-XML%20Mods-b22222)](https://7daystodie.com/)
[![7 Days to Die](https://img.shields.io/badge/7%20Days%20to%20Die-Harmony%20Mods-gold)](https://7daystodie.com/)

</div>

---

## 🪓 What Is This?


This template gives you a **professional modding workspace** for 7 Days to Die XML and C# Harmony DLL mods:

- 🔍 **4-phase XML validation** catches syntax errors, bad XPaths, and vanilla schema mismatches before you ever launch the game
- ⚡ **One-key workflow** - press **F5** to validate, build DLL (if present), deploy, and start your dev server
- 🧩 **DLL mod support**: Write C# Harmony patches in `Scripts/`, build to `Plugins/`, and deploy with your XML
- 🧟 **Multi-mod by default**: drop any number of mod folders in `src/Mods/` and every command builds, validates, deploys, and packages them all at once
- 📋 **Example XML files** for most moddable config, each with commented patch examples
- 📦 **One-command publishing** packages each mod—including DLLs—into its own release-ready ZIP

No more hunting through logs to find a typo in an XPath. No more manual file copying. Just edit, build, and test.

---

## 🚀 Quick Start

### 1. 🧰 Configure your mod

Edit [`mod.config.json`](mod.config.json) - set your mod name, author, and version.
Then rename `src/Mods/MyMod/` to match your `modName`.

```json
{
  "modName":        "MyAwesomeMod",
  "modDisplayName": "My Awesome Mod",
  "modAuthor":      "YourName",
  "modVersion":     "1.0.0"
}
```

Update [`src/Mods/MyMod/ModInfo.xml`](src/Mods/MyMod/ModInfo.xml) to match.

### 2. 🖥️ Set up the dev server (once)

```powershell
.\scripts\setup-server.ps1
```

Auto-detects your Steam installation. Or point it at a custom path:

```powershell
.\scripts\setup-server.ps1 -SourcePath "D:\SteamLibrary\steamapps\common\7 Days to Die"
```

Or download the dedicated server fresh via SteamCMD:

```powershell
.\scripts\setup-server.ps1 -UseSteamCmd
```

To target the **experimental branch** (currently V3.0 *"Dead Hot Summer"*)
instead of stable, add `-Experimental`:

```powershell
.\scripts\setup-server.ps1 -UseSteamCmd -Experimental
# or pin a specific beta branch:
.\scripts\setup-server.ps1 -UseSteamCmd -Branch latest_experimental
```

> ⚠️ The experimental branch reorganized some config files (see
> [V3.0 Config Changes](#-v30-experimental-config-changes) below). The
> `-Experimental`/`-Branch` flags only apply to SteamCMD downloads—a copied
> local install uses whatever branch you've selected in the Steam client.

### 3. 💀 Write your mod

Edit XML files in `src/Mods/<YourMod>/Config/`. Every file has inline
commented examples to get you started. Vanilla reference files live in
`server/Data/Config/` once your dev server is set up.


### 4. 🎮 Build, deploy, and run

Every command processes **all mods in `src/Mods/` by default**. You can build
XML-only, DLL-only, or both, and target a single mod when you need to:

| Action | How |
|--------|-----|
| **Validate + build DLL + deploy + launch server** | **F5** in VS Code |
| **Validate + build DLL + deploy only** | **Ctrl+Shift+B** |
| **Build XML only** | `./scripts/build.ps1 -BuildType xml` |
| **Build DLL only** | `./scripts/build.ps1 -BuildType csharp` |
| **Build both (default)** | `./scripts/build.ps1 -BuildType all` |
| **Build just one mod** | `./scripts/build.ps1 -ModName MyMod` |
| **Terminal** | `./scripts/start-server.ps1 -Build` |

> 💡 `-ModName` defaults to `all`, so a bare `./scripts/build.ps1` builds and
> deploys every mod folder. Pass a folder name to scope a command to one mod.

---

## 🗺️ Project Structure

```
📁 7d2d Mod Template/
├── 📄 mod.config.json           ← Mod name, version, author, server settings
│
├── 📁 scripts/
│   ├── setup-server.ps1         ← One-time dev server setup
│   ├── build.ps1                ← Build DLLs + validate XML + deploy all mods to server/Mods/
│   ├── validate-xml.ps1         ← Standalone 4-phase XML validator
│   ├── start-server.ps1         ← Launch the dev server (-Build to deploy first)
│   ├── clean.ps1                ← Remove deployed mods from server/Mods/
│   └── publish.ps1              ← Package each mod into its own release ZIP
│
├── 📁 src/Mods/                 ← One folder per mod (all built/deployed together)
│   └── 📁 MyMod/                ← Rename to match your modName; add more folders for more mods
│       ├── ModInfo.xml          ← Mod metadata (required by the game)
│       ├── README.md            ← Mod-specific best practices
│       ├── 📁 Scripts/          ← C# Harmony source (optional, not deployed)
│       │   ├── MyMod.csproj     ← .NET 4.8 DLL project (portable, no user paths)
│       │   └── Entry.cs, ...    ← Your Harmony patches
│       ├── 📁 Resources/        ← Unity asset bundles (if any)
│       ├── 📁 Textures/         ← Game texture overrides (if any)
│       └── 📁 Config/           ← XML patches
│           ├── items.xml        ← Items, weapons, tools
│           ├── blocks.xml       ← Blocks and terrain
│           ├── buffs.xml        ← Status effects
│           ├── recipes.xml      ← Crafting recipes
│           ├── loot.xml         ← Loot tables
│           ├── entitygroups.xml ← Zombie/animal spawn pools
│           ├── progression.xml  ← Skills and perks
│           ├── traders.xml      ← Trader inventory
│           ├── quests.xml       ← Quests and rewards
│           ├── ...              ← (+ more - see Config File Reference below)
│           ├── Localization.txt ← Display strings
│           └── 📁 XUi_InGame/   ← UI patches (V3.0; was XUi/ on stable)
│               ├── templates.xml ← reusable UI templates (was controls.xml)
│               └── windows.xml
│
├── 📁 .vscode/
│   ├── tasks.json               ← Build, validate, start-server, publish tasks
│   ├── launch.json              ← F5 = Deploy + Launch Dev Server
│   └── extensions.json          ← Recommended extensions
│
├── server/                      ← Dev server (gitignored - setup-server.ps1)
├── data/                        ← Save games and logs (gitignored)
└── releases/                    ← Distribution ZIPs (gitignored - publish.ps1)
## 🛡️ Portability

The compiled DLL is placed at your mod's root and deployed directly alongside Config/ and other mod assets.
```

---

## 🔍 XML Validation

`validate-xml.ps1` runs **four phases** before anything gets deployed:

| Phase | What It Checks | Requires |
|-------|---------------|----------|
| **1 - Well-formedness** | Valid XML syntax, no unclosed tags | Nothing |
| **2 - Patch syntax** | Known operations, non-empty XPaths, valid `ModInfo.xml` fields | Nothing |
| **3 - Vanilla schema** | Attribute names match real vanilla XML files | `server/` set up |
| **4 - DLL scan** *(experimental)* | Attribute names found in `Assembly-CSharp.dll` string table | `server/` + `-DllScan` flag |

```powershell
.\scripts\validate-xml.ps1                   # Standard (Phases 1–3)
.\scripts\validate-xml.ps1 -Strict           # Warnings become errors
.\scripts\validate-xml.ps1 -Strict -DllScan  # All 4 phases
```

> 💡 Phase 3 catches common typos like `EntityDmg` instead of `EntityDamage`
> by comparing your attributes against the parsed vanilla config files.

---

## ⚔️ Mod Patch Syntax

Your Config files are **patches against vanilla XML** - not replacements.
The game merges them at load time using XPath operations:

```xml
<!-- Add new content -->
<append xpath="/items">
  <item name="myMod_customSword">...</item>
</append>

<!-- Modify an existing value -->
<set xpath="/items/item[@name='meleeToolPickaxeIron']/property[@name='EntityDamage']/@value">30</set>

<!-- Insert adjacent to an existing element -->
<insertAfter xpath="...">...</insertAfter>
<insertBefore xpath="...">...</insertBefore>

<!-- Remove an element -->
<remove xpath="..."/>

<!-- Add or remove a single attribute -->
<setAttribute xpath="..." name="myAttr" value="myValue"/>
<removeAttribute xpath="..." name="myAttr"/>
```

Vanilla configs are in `server/Data/Config/` - use them as your reference.

---

## 🏗️ VS Code Tasks

Open the Command Palette (`Ctrl+Shift+P`) → **Tasks: Run Task**. All build,
validate, and publish tasks run across **every mod** in `src/Mods/`:

| Task | Shortcut | Description |
|------|----------|-------------|
| Build (Validate + Deploy) | `Ctrl+Shift+B` | Build DLLs, validate XML, deploy all mods to `server/Mods/` |
| Validate XML Only | - | Validate every mod without deploying |
| Validate XML (Strict + DLL Scan) | - | Full validation of all mods, all 4 phases |
| Setup Dev Server | - | Run `setup-server.ps1` |
| Start Dev Server | - | Launch the server (no build) |
| Start Dev Server (with Build) | - | Build all mods, deploy, then launch |
| Clean Deployed Mods | - | Remove mods from `server/Mods/` |
| Publish (Create Release ZIP) | - | Package each mod into its own ZIP |

---

## 📦 Config File Reference

Every file ships as an **empty template with commented examples**.
Delete any files you aren't using.

| File | Vanilla Reference | What Goes Here |
|------|-------------------|----------------|
| `items.xml` | `Data/Config/items.xml` | Items, weapons, tools, gear |
| `blocks.xml` | `Data/Config/blocks.xml` | Blocks and terrain |
| `buffs.xml` | `Data/Config/buffs.xml` | Status effects and debuffs |
| `recipes.xml` | `Data/Config/recipes.xml` | Crafting recipes |
| `loot.xml` | `Data/Config/loot.xml` | Loot tables and probabilities |
| `entitygroups.xml` | `Data/Config/entitygroups.xml` | Zombie and animal spawn pools |
| `entityclasses.xml` | `Data/Config/entityclasses.xml` | Entity AI and stats |
| `spawning.xml` | `Data/Config/spawning.xml` | Biome spawn rules |
| `gamestages.xml` | `Data/Config/gamestages.xml` | Difficulty scaling |
| `progression.xml` | `Data/Config/progression.xml` | Skills, perks, level caps |
| `traders.xml` | `Data/Config/traders.xml` | Trader inventory and tiers |
| `quests.xml` | `Data/Config/quests.xml` | Quests and rewards |
| `biomes.xml` | `Data/Config/biomes.xml` | Biome properties |
| `sounds.xml` | `Data/Config/sounds.xml` | Sound definitions |
| `vehicles.xml` | `Data/Config/vehicles.xml` | Vehicle stats |
| `weathersurvival.xml` | `Data/Config/weathersurvival.xml` | Weather and temperature |
| `misc.xml` | `Data/Config/misc.xml` | Game settings and tuning |
| `XUi_InGame/templates.xml` † | `Data/Config/XUi_InGame/templates.xml` | Reusable UI control templates |
| `XUi_InGame/windows.xml` † | `Data/Config/XUi_InGame/windows.xml` | In-game UI window layout |
| `XUi_Menu/windows.xml` | `Data/Config/XUi_Menu/windows.xml` | Main-menu UI layout |
| `XUi_Common/styles.xml` | `Data/Config/XUi_Common/styles.xml` | Shared UI styles and colors |
| `Localization.txt` | `Data/Config/Localization.txt` | All player-visible strings |

> **†** Names shown are for the **V3.0 experimental** layout. On **stable (≤2.6)**
> these live under `XUi/` and the templates file is named `controls.xml`. See
> [V3.0 Config Changes](#-v30-experimental-config-changes).

---

## 🧪 V3.0 Experimental Config Changes

The experimental branch (V3.0 *"Dead Hot Summer"*) reorganized parts of
`Data/Config/`. Because a modlet's `Config/` folder **must mirror the vanilla
folder and file names**, mods built for stable need to be migrated:

| Stable (≤2.6) | V3.0 Experimental | Notes |
|---------------|-------------------|-------|
| `Config/XUi/` | `Config/XUi_InGame/` | The in-game UI folder was renamed |
| `Config/XUi/controls.xml` | `Config/XUi_InGame/templates.xml` | Renamed to avoid confusion with XUi controller classes |
| `Config/XUi/windows.xml` | `Config/XUi_InGame/windows.xml` | Same file, new parent folder |
| `Config/XUi_Common/` | `Config/XUi_Common/` | Unchanged (shared styles/templates) |
| `Config/XUi_Menu/` | `Config/XUi_Menu/` | Unchanged (main-menu UI) |

Other XUi notes for V3.0:

- The **`force_hide` attribute was removed**—control visibility through the
  regular `visible` attribute instead.
- XUi views were reworked (more consistent table/grid/window attributes) and a
  new XML binding system plus `video`, `scrollbar`, and `scrollview` views were
  added.

> 💡 **Always reference your installed server.** The validator and your XPaths
> are checked against `server/Data/Config/`, so set the server up on the branch
> you're targeting (`-Experimental` for V3.0) and mirror whatever folder/file
> names you find there. When in doubt, the authoritative list lives on the
> [7D2D Modding Wiki](https://7d2dmodding.wiki.gg/wiki/XML_File_Index).

---

## 🔄 Dev Workflow

```
✏️  Edit XML / C# in src/Mods/<YourMod>/
                    │
              F5 in VS Code
   (build DLLs → validate → deploy all → start server)
                    │
              🎮 Test in-game
                    │
       .\scripts\publish.ps1
                    │
  📦 releases/<Mod>-v1.0.0-YYYYMMDD.zip  (one per mod)
```

---

## 🧟‍♂️ Multiple Modlets

Shipping a suite of mods, a compatibility patch, or a debug variant? Just add
as many folders as you like under `src/Mods/`—each is a self-contained modlet
with its own `ModInfo.xml`, `Config/`, and optional `Scripts/` DLL project:

```
src/Mods/
├── MyMod/
├── MyMod-compat-SomeOtherMod/
└── MyMod-debug/
```

Every script defaults to `-ModName all`, so the whole `src/Mods/` tree is
processed automatically—no list to maintain:

```powershell
.\scripts\build.ps1                  # validate + build DLLs + deploy ALL mods
.\scripts\build.ps1 -ModName MyMod   # scope to a single mod folder
.\scripts\publish.ps1                # one release ZIP PER mod
```

What "all" does for each command:

| Script | With `-ModName all` (default) |
|--------|-------------------------------|
| `build.ps1` | Builds each mod's DLL (if it has a `Scripts/*.csproj`), validates its XML, and deploys every mod into `server/Mods/` |
| `publish.ps1` | Creates a **separate versioned ZIP per mod** in `releases/`, each versioned from its own `ModInfo.xml` |
| F5 / `Ctrl+Shift+B` | Run the build task across every mod, then (F5) launch the server |

> 💡 Each mod is deployed and zipped independently, so adding, removing, or
> renaming a folder under `src/Mods/` is all it takes—no config changes needed.

---

## 🏁 Getting Started with a Real Mod

1. 📋 Copy this template to a new repo
2. ✏️ Edit `mod.config.json` - set `modName`, `modDisplayName`, `modAuthor`
3. 📁 Rename `src/Mods/MyMod/` to match `modName`
4. 📄 Update `src/Mods/<YourMod>/ModInfo.xml` to match
5. 🖥️ Run `setup-server.ps1`, then **F5** to confirm everything works
6. 💀 Start editing XML - reference the vanilla configs in `server/Data/Config/`
7. 📖 Read `src/Mods/<YourMod>/README.md` for XML patching best practices

---

<div align="center">

**🧟 Happy modding. May your XPaths be specific and your blood moons plentiful. 🌙**

</div>
