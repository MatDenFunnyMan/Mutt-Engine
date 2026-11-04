# Options

Options have been completely **re-organized from scratch!**
This page covers the new SETTINGS and CHANGES made for the `Options state` and its `substates`!

## Preferences

| Option | Description |
|---|---|
| **Naughtyness** | Same as V-Slice with a few additions. |
| **Subtitles** | Subtitles for cutscenes, songs and videos. |
| **Unfocused Volume** | Volume of the game when not in focus. |
| **Input Overlay** | Small window on left side with Keys, NPS, BPM and Hold Timer |
| **Smooth Health Bar** | Self-explanatory, similar to V-Slice. |
| **Note Camera** | Camera moves on note hit. Two modes: **SIMPLE** and **ADVANCED**. |
| **Note Camera Intensity** | Value goes from 1-10, changes how fast and strong movement is. |
| **Note Camera Ease** | Ease for camera, ONLY for ADVANCED. |
| **Hide Mouse** | Hides the mouse in-game except Main Menu and Editors |

## Notes

| Option | Description |
|---|---|
| **Strumline Background** | BG for Strumline so you can see better. |
| **Hold Note Tail** | Hold Note tails position, **Front** uses V-Slice style, **Behind** is best used for modcharts, "legacy" styled notes. |
| **Quant Notes** | Applies Note Quantization for all songs. |

## Lag Adjustment

Taken from V-Slice cause it's cooler and more sigma. Changes Input Offsets and timing. On "Offset Calibration", there are a few easter eggs to find if you keep spamming the UP key :)

## Graphics

| Option | Description |
|---|---|
| **V-Sync** | Uses monitor's refresh rate. You already know this lol. |
| **Unlocked Framerate** | UNCAPPED framerate (might cause lag or issues in-game) |
| **Resolution** | *Fullscreen*, *Borderless* or *Windowed*. F11 and Alt+Enter to switch between modes. |
| **GPU Caching** | Saves cache memory in GPU rather than RAM for a more optimized experience (DO NOT ENABLE IF YOUR GPU SUCKS OR YOU DON'T HAVE A DEDICATED GRAPHICS CARD) |

## Gameplay

| Option | Description |
|---|---|
| **Input System** | *Psych*: normal Psych Engine input. *V-Slice*: base game's input and scoring (no ghost tapping). *Legacy*: old Psych input, hold notes DO NOT count as single notes. |
| **Safe Frames** | Safe Frames... I don't use this much. |
| **Disable Results** | Skips the Results screen at the end of songs. |

## Debug

| Option | Description |
|---|---|
| **Developer Mode** | Enables Editors (press 6 on Main Menu) and the new in-game DEBUG MODE (Ctrl+Shift+Enter) |
| **Debug Display** | FPS and Memory, three modes: *Simple*, *Simpler* or *Advanced*, *OFF* to disable (use F6 to toggle between modes) |
| **Debug Display BG** | Display BG opacity, duh. |
| **Allow Screenshots** | If unchecked, screenshot are permanently disabled including hotkey. |

## For modders: Naughtyness

If "Naughtyness" is unchecked, the game will check for two types of files in this order:

```txt 
'-censored' --> '_safe' --> File without suffixes
```

Here's an example:

- **Videos**: `videos/my-cutscene-censored.mp4` is played instead of `my-cutscene.mp4`.
- **Subtitles**: `my-cutscene-censored.json` is used instead of `my-cutscene.json`.
- **Characters**: a character's `.json` can name a `censored_character` to use instead.

For scripts, a global variable **`naughtyness`** can be used for certain conditions:

```lua
function onCreate()
	if not naughtyness then
		setTextString('sign', 'Have a nice day')
	end
end
```

Additionally, you can add the value to a variable this way:

```lua
local badwords = getPropertyFromClass('funkin.save.ClientPrefs', 'data.naughtyness')
```

Or simply:

```lua
local badwords = naughtyness
-- NOTE: badwords is a BOOLEAN variable, not STRING! (like ofc lol)
```
