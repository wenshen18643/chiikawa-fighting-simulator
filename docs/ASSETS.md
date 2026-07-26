# Assets

Model ids for world decor. The game reads
`src/shared/Modules/Config/Assets.lua`, not this file — keep them in step.

## Status, checked 2026-07-26

`InsertService:LoadAsset` only serves models that are **public**, or **owned by
the account that owns the place**. Four of these are private models belonging to
somebody else, so they fail on a live server and cannot be made to work by
changing anything in this repo:

| Key | Id | Status |
|---|---|---|
| terrain | 97974769788038 | **loads** |
| logs | 9731248486 | not authorized |
| bushes | 11337757315 | not authorized |
| house | 136868946197723 | not authorized |
| nature pack | 82060619904561 | **public domain** — should load. Replaced 71032774784968 (not authorized) |
| tree | — | no id yet |
| grass | — | no id yet |

Every one of them has a procedural fallback, so the world builds either way —
a failed id costs the nicer model and nothing else.

**To fix one:** re-upload the model to the account that owns this place (or find
a genuinely free equivalent in the Creator Store), then put the new id in
`Config/Assets.lua`. Nothing else needs touching.

`terrain` loads but is not wired to any helper yet.

## The nature pack

`82060619904561` — "🌿 Nature Pack Studs Trees Bush Grass Flower", by
`St3althPow3rHaz358` (verified), uploaded 2026-03-11, 54↑/6↓, category
`3d__nature`. `AssetTypeId 10` (Model), `hasScripts: false`,
**`IsPublicDomain: true`** — which is why this one can load where the four
above cannot.

Checked with:

```
curl -s "https://economy.roblox.com/v2/assets/82060619904561/details"
curl -s "https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=82060619904561"
```

Both are public and need no auth — a fast way to check whether an id is usable
(`IsPublicDomain`) before wiring it up. Downloading the model itself to list its
parts does NOT work unauthenticated: `assetdelivery.roblox.com/v1/asset/?id=...`
returns `401`.

### Contents, as reported at startup

Items are nested inside a Folder, so `AssetService.collectItems` recurses through
folders and stops at the first Model.

| Prop | Approx size (studs) | Used by |
|---|---|---|
| `Tree 1`, `Tree 2` | 14–18 tall | `helpers.tree` |
| `Tree` | 12 × 2.2 × 2.2 — slender | `helpers.tree` (scales uniformly, reads as a sapling) |
| `Bush 1`, `Bush 2` ×2 | 4–5 tall, 8–10 wide | `helpers.bush` |
| `Grass 1`–`3` | ~1–2.5 | ground cover |
| `Flower 1`–`3` | ~1.5 | path beds, ground cover |
| `Rock 1`–`5` | 2.5–7 | `helpers.stone` |
| `Mushroom 1`, `2` | ~1 — scaled up on use | Woods mushrooms |
| `GrassWandSquare`, `GrassWandCylinder` | ~8 cubes | **excluded** |

The two wands are Studio authoring tools for painting grass, not scenery. They
match a `"grass"` filter and are eight times the right size, so
`Config/Assets.lua` drops them via `exclude = { "wand" }`.

Selection is by case-insensitive substring on these names, falling back to any
prop and then to the procedural version.
