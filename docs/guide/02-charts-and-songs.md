# Charts & Songs

This page covers everything about songs: where the files go, the Chart Editor, events, extra characters and song subtitles.
This page covers everything about songs and charting (directories, Chart Editor, events, Extra Characters, Subtitles)

## Song Folder - Structure

An extended look on the new `songs` directory, similar to how Codename Engine works.
A good practice for song files (JSON, folder names, scripts) is to keep them short, simple, lowercase and with `-` instead of spaces, but following this is optional!

```
data/songs/my-song/
  charts/
    my-song-easy.json
    my-song.json          Normal difficulty
    my-song-hard.json
  song/
    Inst.ogg
    Voices.ogg            or Voices-Player.ogg + Voices-Opponent.ogg
  scripts/                Lua / HScript files that run only in this song
  events.json             chart events (optional)
  subtitles/              song-lyrics.json and other subtitles (optional)
  healthbar.json          health bar for this song (optional)
  dialogue.json           dialogue before the song (optional)
  modchart.json           modchart (optional)
```

**Legacy Psych** charts (`data/my-song/my-song.json`), **V-Slice** and **Codename Engine** charts (must have metadata JSON file) are automatically converted in the Chart Editor.

## CHART EDITOR

Accessible via Editor Menu (**6**) or in PlayState (**7, if Developer Mode Enabled**).

### Chart Editor - Start-up Wizard 

The start-up wizard works similar to V-Slice, used to initialize data for a new chart:

- **Open Recent Charts** or **Browse for Charts**;
- **Create From Song**: pick an existing song from JSON file;
- **New Chart**: metadata (name, credits, BPM, Scroll Speed, audio files, ...);
- **From Codename**: import a Codename Engine chart.

When you make a new chart, the editor asks for the audio files (`Inst`, `Voices`, or separate `Voices-Player` / `Voices-Opponent`) and copies them into the song folder for you.
When making a new chart, the wizard asks for audio files (`Inst`, `Voices` or `Voices-Player` / `Voices-Opponent`). These files will be automatically copied inside the `song/` folder.

### Menus and Tabs

Mutt Engine reworked most of the engine's editors, adding tons of new content and features. Here's the list:

| Menu/Tabs | Content |
|---|---|
| **`File`** | `New, Open Chart, Open Autosave, Open Events,` **`Import V-Slice, Import Codename`**, `Save, Save As, Save Events, Reload Chart` |
| **`Audio`** | `Mute Instrumental/Vocals, Hitsounds, Metronome` |
| **`Edit`** | `Undo, Redo, Copy, Paste, Cut, Select All, Delete, Autosave Settings, Clear All Notes / Events` |
| **`View`** | `Vortex Editor, Waveform, Go to, Theme, Last/Next Section Preview, Note Type Labels, Toys, Reset UI Boxes` |
| **`Test`** | `Playtest, Playtest Here, Preview Chart` |
| **`Song`** | `Song name, BPM, scroll speed, audio offset, characters, stage,` **`Extra Characters`** |
| **`Chart`** | **`Difficulty`** `(switch difficulty without leaving), Playback Rate` |
| **`Meta`** | `Song Credits: Artist, Composer, Charter, Coder` |
| **`Data`** | `Game Over Data (Sounds/Music),` **`Note Pack`** |
| **`Section`**, **`Note`**, **`Events`** | Selected Section, Note or Event |

**Toys** (View) can be used to **Preview Character** behavior in-game (animations)

### Shortcuts

Press **F1** in the editor for the full list.

| Key | Action |
|---|---|
| **`W / S, Mouse Wheel`** | Move around the song (Shift = faster, Alt = slower) |
| **`A / D`** | Previous / Next Section |
| **`Space`** | Play / Pause |
| **`Z / X`** | Zoom OUT / IN |
| **`Left / Right`** | Change Snap |
| **`Left Click`** | Place Note (hold & drag for hold notes) |
| **`Right Click`** | Delete Note |
| **`Right Click + Drag`** | Selection Box |
| **`Shift + Drag`** | Duplicate Selected Notes |
| **`Q / E`** | Shorter / Longer Hold Note |
| **`Ctrl + Z / Ctrl + Shift + Z`** | Undo / Redo |
| **`Ctrl + C / X / V`** | Copy / Cut / Paste |
| **`Ctrl + S`** | Save |
| **`Enter`** | Playtest (Shift + Enter = From current position, Ctrl + Enter = Preview) |

## Note Types

Built-in note types:

| Note type | What it does |
|---|---|
| Alt Animation | The character sings with the `-alt` animations. |
| Hey! | The character plays its "hey" animation. |
| Hurt Note | Hitting it hurts. Let it pass. |
| GF Sing | Girlfriend sings it. |
| No Animation | No sing animation. |
| Censor | The character sings with its `-censor` animations. |

To make your own note types with their own look and rules, see [Notes](05-notes.md).

## Events

Events are saved in the chart or in `events.json`. These are the built-in ones:

| Event | Description |
|---|---|
| Add Cam Zoom | A quick zoom bump on the game and HUD cameras. |
| Cam Zoom | Changes the camera zoom, with duration and ease. |
| Cam Bopping | How many camera bumps per beat, and how strong. |
| Cam Follow Pos | Moves the camera to a character (BF, Dad, GF, 3, 4...), to a position, or to a character plus an offset. |
| Center Camera | Moves the camera to the center of the stage. |
| Cam Speed | How fast the camera follows. |
| Cam Flash | Flashes a camera with a color. |
| Cam Shake | Shakes a camera. |
| Cam Rotation | Rotates a camera. |
| Change Character | Replaces a character. |
| Set Char Idle Alt | Uses another idle animation (like `-alt`). |
| Play Animation | Plays an animation on a character, optionally looping. |
| Character Sing-Along | Makes characters copy another one's animations (duets). |
| Set GF Speed | How often Girlfriend bops. |
| Change Notes | Changes the skin of notes, strums, splashes and hold covers (also with Note Packs). |
| Set Note Speed | Changes the scroll speed, for one side or both. |
| Play Video | Plays a video during the song. |
| Health Drain | The player loses health while the opponent sings (or all the time, with *Persistent*). |
| Ghost Trail | Leaves ghost copies behind a character. |
| Silhouette | Turns characters into colored shapes, with a colored background. |
| BG Flash | Flashes the background and characters with a color. |

The *Events* tab of the Chart Editor explains what each value does.

### Custom Events

Put a script with the event's name in `custom_events/`. It runs when the event is triggered:

```lua
-- custom_events/Flash Red.lua
function onEvent(name, value1, value2, strumTime)
	if name == 'Flash Red' then
		cameraFlash('game', 'FF0000', tonumber(value1) or 0.5)
	end
end
```

Optionally add:

- `Flash Red.txt`: the description shown in the Chart Editor.
- `Flash Red.json`: the fields shown in the Chart Editor, instead of plain text boxes.

```json
[
	{"label": "Duration", "type": "stepper", "min": 0, "max": 5, "step": 0.1, "decimals": 1},
	{"label": "Camera", "type": "dropdown", "options": ["game", "hud"]},
	{"label": "Fade Out", "type": "checkbox"}
]
```

Field types: `inputtext` (default), `stepper`, `slider`, `dropdown`, `checkbox`. The values arrive in `onEvent` in the same order: `value1`, `value2`, then the next ones as extra arguments.

## Extra characters

A song can have up to **10 characters**: BF, Dad and 8 more (Girlfriend doesn't count).

1. In the **Stage Editor**, *Extras* tab, add the spots for the extra characters (Character 3, 4...). See [Stages](04-stages.md).
2. In the **Chart Editor**, *Song* tab, press **Extra Characters** and pick a character for each slot.
3. Choose how it sings:
   - **Shared strumline**: it uses the notes of BF, Dad or GF. Each extra character gets its own note types (`Character 3 Note`, `Character 3 ALT Note`...): place those notes and only that character sings them.
   - **Own strumline**: it gets its own arrows, played by the player or by the opponent.

In events and scripts, extra characters are called by their number (`3`, `4`...) or as `character3`, `character4`...

The **Character Sing-Along** event makes duets easy: one character "leads" and the others copy its animations, misses included. Leave the followers empty and *All* off to stop it.

## Song subtitles

Put `subtitles/song-lyrics.json` in the song folder and the lyrics show up by themselves while the song plays (when the Subtitles option is on).

```json
{
	"subtitles": [
		{"text": "Beep bop!", "start": 1.5, "end": 3},
		{"text": "Skee-dah bop!", "start": "0:04.2", "end": "0:06"}
	]
}
```

Times are in seconds, or `minutes:seconds`. Each line can also have its own `font`, `size`, `color`, `x`, `y`, `scale`, `background`, `backgroundColor`, `outline` and `outlineColor`. `.srt` files work too.

Scripts can show other subtitles with `playSubtitles('name')`, which looks in the song's `subtitles/` folder first.
