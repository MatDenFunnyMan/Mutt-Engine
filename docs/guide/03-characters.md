# Characters

A character is a `.json` file in `data/characters/` plus its spritesheet in `content/images/characters/`. The easiest way to make one is the **Character Editor**.

## The Character Editor

Open it from the Editor Menu, or with key **8** during a song (Developer Mode on). Press **F1** inside the editor for every shortcut.

| Part | What's inside |
|---|---|
| **File** menu | Save Character, Reload Character, Load Template. |
| **View** menu | **Switch View**: the normal *Character* view, or the *Spritesheet* view that shows the whole image with the frames of the selected animation. |
| **Icon** menu | **Properties** and **Animations** of the health icon (see below). |
| **Animations** tab | Add, change and remove animations. |
| **Character** tab | Image, scale, health icon, health bar color, camera position, flip, antialiasing, **VSlice Sustains**. |
| **Ghost** tab | Ghosts: see-through copies of other animations, to line up the offsets. |

### Ghosts

Press **F** to leave a ghost of the selected animation on screen. You can keep **as many ghosts as you want**, with different animations, and remove one by clicking it in the ghost list. Ghosts stay when you change the image or the character, marked as `(old)`, so you can line up a new spritesheet with the old one.

### Shortcuts

| Key | Action |
|---|---|
| W / S | Previous / next animation |
| Space | Replay the animation |
| Arrow keys, right click + drag | Move the offset (Shift = 10x) |
| A / D | Previous / next frame |
| Ctrl + C / Ctrl + V | Copy / paste the offset |
| Ctrl + R | Reset the offset |
| F | Ghost of the selected animation |
| F12 | Show / hide silhouettes |
| Ctrl + S | Save |

## The character file

These are the fields you may want to change by hand. The editor writes all the others.

| Field | What it does |
|---|---|
| `image` | Spritesheet in `images/`. More images separated by commas are joined together. |
| `healthicon` | Name of the icon in `images/icons/`. |
| `healthicon_antialiasing` | `false` for pixel icons. Small icons and icons ending in `-pixel` are already sharp. |
| `healthbar_colors` | Health bar color, `[red, green, blue]`. |
| `censored_character` | Character used when the Naughtyness option is off. |
| `pause_music` | Pause menu music while this character is the player. |
| `vocals_file` | Vocals of this character (`Voices-<name>.ogg`). |
| `vslice_sustains` | See below. |

## Hold notes like the base game

Turn on **VSlice Sustains** (or `"vslice_sustains": true`) and the character keeps its pose during hold notes, instead of restarting the animation every few frames. The V-Slice input system always does this.

If the character has an animation with the same name plus `-hold`, like `singLEFT-hold`, that one plays while the note is held. When you let go, the normal animation finishes from where the hold one stopped.

```json
{"anim": "singLEFT-hold", "name": "BF NOTE LEFT HOLD", "fps": 24, "loop": true, "indices": [], "offsets": [5, -6]}
```

## Health icons

Icons go in `content/images/characters/icons/` (or the old `images/icons/`), named `icon-<name>.png` or `<name>.png`.

### Icon states

A normal icon is a row of 150x150 squares, one for each state:

| Square | State | When |
|---|---|---|
| 1 | Neutral | Always, when the others are missing. |
| 2 | Losing | Health below 20%. |
| 3 | Winning | Health above 80%. |
| 4 | Winning more | Health above 90%. |

So an icon 300 pixels wide has neutral and losing, 600 pixels wide has all four.

### Animated icons

Put an `.xml` next to the icon and it becomes animated. Name the animations in the spritesheet with these prefixes and Mutt Engine finds them by itself:

| State | Prefixes |
|---|---|
| Neutral | `neutral`, `normal`, `idle`, `icon`, `default` |
| Losing | `lose`, `losing`, `loss` |
| Winning | `win`, `winning` |
| Winning more | `winextra`, `superwin`, `perfect` |

To choose the animations yourself, use **Icon > Animations** in the Character Editor: it saves an `.json` next to the icon.

```json
{
	"animations": [
		{"state": "neutral", "prefix": "bf idle", "fps": 24, "loop": true},
		{"state": "losing", "prefix": "bf hurt", "fps": 24, "loop": true, "offsets": [0, 4]}
	]
}
```

## Ghost Trails

Ghost trails are copies of a character that fade behind it while it sings. Use the **Ghost Trail** event in the chart, or `setGhostTrail` in a script:

```lua
function onCreate()
	setGhostTrail('dad', 'animated', {color = 'health', distance = 15})
end
```

| Type | Look |
|---|---|
| `simple` | A still copy of the last pose. |
| `animated` | A copy that moves away in the direction of the note. |
| `aura` | Copies appear all the time, even when the character doesn't sing, glowing in the health bar color. |
| `off` | No trail. |

Options: `doubleNote` (only on two or more notes at once), `color` (a color, or `health` for the health bar color), `alpha`, `duration`, `distance`, `grow`, `rate`, `blend`.
