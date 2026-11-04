# Getting Started

#### Welcome to Mutt Engine's "Instruction Booklet", official (ig?) documentation for my very own Psych fork.

## Where do MODS go?

Put them in `mods/`, like in the example.

```
MuttEngine.exe
mods/
  my-mod/
  another-mod/
```

Name of the folder is recognized as the mod's "ID", used by the `currentModDirectory` variable. Make sure to name them right (and not call it superduperamazingshitassmodtm or smth)

Mutt Engine ships with two template mod folders to use:

| Template | Description |
|---|---|
| `mods/your-mod` | A **NEW** and **MODERNIZED** mod folder similar to new engines like Codename or V-Slice, more organized. |
| `mods/your-mod-legacy` | The **OG Psych Engine** mod folder, backwards compatibility with Mutt, allowing base Psych mods to work. |

## NEW MOD FOLDER STRUCTURE (Expanded View)

```
your-mod/
  pack.json             mod name, description, color...
  pack.png              mod icon in the Mods menu
  content/
    images/             every image (characters, stages, menus...)
    audio/
      music/            menu and cutscene music
      sounds/           sound effects
    shaders/            .frag shaders
    translations/       translated text and images
    custom_weeks/       assets used by one week only
  data/
    characters/         character .json files
    stages/             stage .json files (+ .lua / .hx stage scripts)
    weeks/              week .json files
    songs/
      my-song/
        charts/         my-song-easy.json, my-song.json, my-song-hard.json...
        song/           Inst.ogg, Voices.ogg
        scripts/        scripts that run only in this song
        events.json     chart events (optional)
  scripts/              scripts that run in every song
  states/               custom menus and screens (see Scripting)
  custom_events/        your own chart events
  custom_notetypes/     your own note types
  fonts/
  videos/
```

***NOTE: Not all folders are needed for the mod to work.***

### PATH SHORTCUTS

Scripts and JSON files allow for quick **"shortcut" paths**, like Psych Engine does. Here's how it works for Mutt:

| "Shortcut" Path | Full Path |
|---|---|
| `images/...` | `content/images/...` |
| `sounds/...` | `content/audio/sounds/...` |
| `music/...` | `content/audio/music/...` |
| `shaders/...` | `content/shaders/...` |
| `characters/...` | `data/characters/...` |
| `stages/...` | `data/stages/...` |
| `weeks/...` | `data/weeks/...` |

Ex. =  `createSprite('bg', 'stages/park/sky')` loads `content/images/stages/park/sky.png`.

Changes were made to **image folders** as well, but old directories are <u>backwards compatible</u>:

| Old (Psych) | New (Mutt) [`content/images/`] |
|---|---|
| `icons/` | `characters/icons/` |
| `dialogue/` | `extra/dialogue/` |
| `achievements/` | `extra/achievements/` |
| `soundtray/` | `extra/soundtray/` |
| `menubackgrounds/` | `storymode/weekbg/` |
| `menucharacters/` | `storymode/weekcharacters/` |
| `menudifficulties/` | `storymode/weekdiff/` |
| `storymenu/` | `storymode/weekname/` |
| `noteSkins/` | `notes/` |
| `noteSplashes/` | `notes/splashes/` |

## pack.json

`pack.json` describes the mod. All fields are optional.

```json
{
	"name": "My Mod",
	"description": "A short description.",
	"color": [255, 120, 0]
}
```

| Field | Description |
|---|---|
| `name` | Name shown in the Mods menu. |
| `description` | Text shown under the name in the Mods menu. |
| `color` | Background color of the Mods menu, `[red, green, blue]`. |
| `iconFramerate` | Speed of `pack.png` when it is animated. |
| `restart` | `true` = the game restarts when the mod is turned on or off. |
| `runsGlobally` | `true` = the mod's scripts also run while other mods are active. |
| `changeTitle` | `false` = keep the engine's window title. `true` (default) = use `windowTitle`, or `name` if it's missing. |
| `windowTitle` | Title of the game window while the mod is active. |
| `discordRPC` | Discord application ID, to show your own name and images in Discord. |

## CHOOSING MODS

Press **TAB** in the Main Menu to open the mod selector. You'll find these options:

| Mode | Description |
|---|---|
| **"YOUR MOD NAME"** | Allows ONE of your mods to run **WITHOUT** base game content. Remember, more mods can appear in the list but only the selected one is active. |
| **ALL MODS** | All mods loaded run at the same time, **WITHOUT** base game content. |
| **MODS + FNF SONGS** | All mods + base game content (Funkin 0.8.6) |
| **DISABLE MODS** | Only base game content (Funkin 0.8.6) |

Custom states (AKA custom menus, see [Scripting](09-scripting.md)) only work for **each SINGULAR mod**. It is recommended, if you have more than one mod with custom states, to DISABLE mods you're not playing and run one at a time to avoid conflicts.
If more than one mod is loaded, it will default to base game menus to avoid crashes.
