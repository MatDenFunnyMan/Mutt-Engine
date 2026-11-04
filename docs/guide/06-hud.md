# HUD

This page covers the custom health bar, the icons and the results screen.

## Custom health bar

The health bar has two images, both optional:

- **bg**: the frame, drawn on top.
- **bar**: the colored part. It can have any shape (white works best), and it's tinted with the health colors, so `setHealthBarColors` keeps working.

Both are scaled to the size of the normal health bar and centered by themselves.

### healthbar.json

Write a `healthbar.json` and Mutt Engine loads it by itself. The first one found is used:

1. `data/songs/<song>/healthbar.json`: only that song.
2. `data/healthbar.json`: every song of the mod.

```json
{
	"bg": "healthbar/my-mod/frame",
	"bar": "healthbar/my-mod/fill",
	"scale": 1.1
}
```

The paths are inside `images/`. Every other field is optional:

| Field | What it does |
|---|---|
| `bg`, `bar` | The two images. Empty or missing = the normal ones. |
| `scale` | Size of the whole health bar. |
| `offset` | Moves the whole health bar, `[x, y]`. |
| `barScale` | Size of the colored part only, `[x, y]` or one number. |
| `barOffset` | Moves the colored part only, `[x, y]`. |
| `iconScale` | Size of the icons. |
| `iconOffset` | Moves the icons, `[x, y]`. A bigger `x` moves them further apart. |
| `iconBop` | `false` = the icons don't bop on the beat. |
| `bgAnimation`, `barAnimation` | `{"prefix": "...", "fps": 24}` for animated images (with an `.xml` next to them). |

The old way, `bar.png` and `bg.png` in `content/images/healthbar/`, still works.

### From scripts

```lua
function onSectionHit()
	if curSection == 32 then
		loadHealthBar('healthbars/angry')
	end
end
```

| Function | What it does |
|---|---|
| `loadHealthBar(?path)` | Loads a style from a `.json` in `data/` (`'healthbars/angry'` = `data/healthbars/angry.json`). Empty = back to the song's or mod's style. |
| `setHealthBarBG(?image, ?prefix, ?fps)` | Changes only the frame. |
| `setHealthBarSprite(?image, ?prefix, ?fps)` | Changes only the colored part. |
| `resetHealthBar()` | Back to the last loaded style. |
| `setHealthBarColors(left, right)` | The two colors. |

To flip the frame upside down (for example with downscroll), use `setProperty('healthBar.bg.flipY', true)`.

## Icons

Icons have up to four states (neutral, losing, winning, winning more) and can be animated: see [Health icons](03-characters.md#health-icons).

Extra characters (Character 3 to 10) get their icon on the health bar too, smaller, next to the icon of the side they sing for.

## Results screen

At the end of a song in Freeplay, and at the end of a week in Story Mode, the results screen shows your score, the hits of each rating and a **rank**, like in the base game.

The rank comes from the **clear**: Sick and Good hits, minus misses, divided by the number of notes.

| Rank | When |
|---|---|
| Perfect (gold) | Every note hit as Sick. |
| Perfect | No misses, and clear at 100%. |
| Excellent | Clear 90% or more. |
| Great | Clear 80% or more. |
| Good | Clear 60% or more. |
| Loss | Below 60%. |

The rank also shows up in Freeplay, next to the song.

The player can turn the results screen off with the **Disable Results** option. A script can skip it for one song:

```lua
function onResultsScreen(score, accuracy, misses)
	return Function_Stop
end
```
