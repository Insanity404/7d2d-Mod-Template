# MyMod

A short description of what your mod does and why someone would want it.

> **New to this template?** See the [root README](../../../README.md) for build,
> validation, and dev-server setup. This file covers mod-specific best practices.

---

## Setup Checklist

Before writing any XML, complete these steps so your mod has a clean identity:

- [ ] Rename this folder from `MyMod` to your mod's name (no spaces)
- [ ] Update `mod.config.json` at the repo root (`modName`, `modAuthor`, `modVersion`)
- [ ] Update `ModInfo.xml` in this folder to match
- [ ] Choose a short unique prefix for your mod (e.g. `acme`) - see [Naming](#naming)

---

## Naming

Every item, block, buff, style, and localization key you add should carry a unique
prefix so it cannot collide with vanilla or with another mod loaded at the same time.

```xml
<!-- Good - clearly yours, won't collide -->
<item name="acme_sniperRifle">...</item>
<style name="acme_icon32Red" type="button">...</style>
<key name="acme_sniperRifle_name" value="Acme Sniper Rifle"/>

<!-- Bad - will conflict if any other mod adds "sniperRifle" -->
<item name="sniperRifle">...</item>
```

Pick a prefix that is short, lowercase, and unique to you - your username or an
abbreviation of your mod name both work well.

---

## Writing Patches

7D2D loads your Config files as **patches against vanilla XML**, not replacements.
Prefer the smallest patch that achieves your goal.

### Be specific with XPath

A narrow XPath breaks fewer things when the game updates and is less likely to
interfere with other mods patching the same file.

```xml
<!-- Good - targets exactly the attribute you want -->
<set xpath="/items/item[@name='meleeToolPickaxeIron']/property[@name='EntityDamage']/@value">30</set>

<!-- Risky - removes the whole item, breaking anything that references it -->
<remove xpath="/items/item[@name='meleeToolPickaxeIron']"/>
```

### Prefer `append` over full replacements

Never copy a vanilla file and edit it directly. Always patch with `append`,
`insertAfter`, `set`, etc. so your changes compose with other mods.

### Use `setIfExists` for optional attributes

When you are not sure whether a vanilla attribute exists in every game version,
`setIfExists` silently skips the patch rather than erroring on a missing node.

```xml
<setIfExists xpath="/items/item[@name='meleeToolPickaxeIron']/property[@name='Tags']/@value">blade,myTag</setIfExists>
```

### Comment non-obvious patches

Leave a comment whenever the reason for a change is not immediately obvious from
the XPath alone.

```xml
<!-- Reduce one-hit kills in the early game (balancing pass v1.2) -->
<set xpath="/items/item[@name='meleeToolPickaxeIron']/property[@name='EntityDamage']/@value">30</set>
```

---

## Localization

All player-visible strings belong in `Config/Localization.txt`, not hard-coded in
XML attributes. This makes translation easier and keeps display names consistent.

```
Key,File,Type,UsedInMainMenu,NoTranslate,english,...
acme_sniperRifle_name,Items,Item,,,"Acme Sniper Rifle",...
acme_sniperRifle_desc,Items,Item,,,"A high-powered rifle with exceptional range.",...
```

Then reference the key in XML:

```xml
<property name="DisplayName" value="acme_sniperRifle_name"/>
<property name="Description" value="acme_sniperRifle_desc"/>
```

---

## Config File Reference

| File | Vanilla reference | What to put here |
|------|-------------------|------------------|
| `items.xml` | `Data/Config/items.xml` | New items, weapon/tool tweaks |
| `blocks.xml` | `Data/Config/blocks.xml` | New blocks, terrain changes |
| `recipes.xml` | `Data/Config/recipes.xml` | Crafting recipes |
| `buffs.xml` | `Data/Config/buffs.xml` | Status effects |
| `progression.xml` | `Data/Config/progression.xml` | Skills, perks, level caps |
| `loot.xml` | `Data/Config/loot.xml` | Loot tables and probabilities |
| `entitygroups.xml` | `Data/Config/entitygroups.xml` | Zombie/animal spawn pools |
| `spawning.xml` | `Data/Config/spawning.xml` | Biome spawn rules |
| `gamestages.xml` | `Data/Config/gamestages.xml` | Difficulty scaling |
| `traders.xml` | `Data/Config/traders.xml` | Trader inventory and tiers |
| `quests.xml` | `Data/Config/quests.xml` | Quests and rewards |
| `biomes.xml` | `Data/Config/biomes.xml` | Biome properties |
| `sounds.xml` | `Data/Config/sounds.xml` | Sound definitions |
| `vehicles.xml` | `Data/Config/vehicles.xml` | Vehicle stats |
| `weathersurvival.xml` | `Data/Config/weathersurvival.xml` | Weather and temperature |
| `misc.xml` | `Data/Config/misc.xml` | Game settings and tuning |
| `XUi_InGame/templates.xml` | `Data/Config/XUi_InGame/templates.xml` | Reusable UI templates (was `XUi/controls.xml` on stable ≤2.6) |
| `XUi_InGame/windows.xml` | `Data/Config/XUi_InGame/windows.xml` | In-game UI window layout |
| `XUi_Common/styles.xml` | `Data/Config/XUi_Common/styles.xml` | Shared UI styles and colors |
| `Localization.txt` | `Data/Config/Localization.txt` | Display strings |

Delete any files you are not using - empty XML files are harmless but add noise.

---

## Versioning

Follow [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

| Bump | When |
|------|------|
| `PATCH` | Bug fixes, balance tweaks - safe to update mid-save |
| `MINOR` | New content - generally safe mid-save |
| `MAJOR` | Breaking changes - may require a new save |

Update the version in both `mod.config.json` and `ModInfo.xml` together.
The `publish.ps1` script uses this version to name the release ZIP.

---

## Compatibility

- Test your mod **alongside popular overhauls** if you target the same vanilla files
- Avoid patching large sections when a smaller targeted change will do
- If two mods conflict, consider publishing a small compatibility patch as a
  separate modlet under `src/Mods/MyMod-compat/`

---

## Publishing

```powershell
.\scripts\publish.ps1
```

This produces `releases/MyMod-v1.0.0-YYYYMMDD.zip` ready to upload to Nexus Mods,
the 7D2D Forums, or wherever you distribute your work.
