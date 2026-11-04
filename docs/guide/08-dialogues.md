# Dialogues

Mutt Engine has its own dialogue system: talking portraits with voices, backgrounds, music, sound effects, fades and screen effects. Everything is made with the **Dialogue Editor**.

> The old Psych dialogue files (`dialogue.json` with `dialogue` and `portrait` lines) no longer work. The week 6 pixel dialogues still use their own system.

## The files

A dialogue is made of three kinds of files:

| File | Where | What it is |
|---|---|---|
| **Dialogue** | `data/songs/<song>/dialogue.json` | The scenes, in order. |
| **Characters** | `data/dialogue/characters/<id>.json` | Who talks: portrait, name, colors, voice. Shared by every dialogue. |
| **Styles** | `data/dialogue/styles/<name>.json` | The look: box, fonts, text speed, hints, backgrounds. Shared by every dialogue. |

Images go in `images/dialogue/`, voices and sound effects in `sounds/`, music in `music/`.

### When dialogues start

- `dialogue.json` starts before the song.
- `dialogue-end.json` starts after the song.

`dialogue.json` doesn't play again when you restart the song. Neither plays in the Chart Editor's playtest. Any other dialogue file in the song folder can be started from a script with `startDialogue('name')`.

## A small dialogue

```json
{
	"style": "default",
	"scenes": [
		{"scene": "normal", "character": "bf", "portrait": "happy", "text": "Beep bop!"},
		{"scene": "normal", "character": "gf", "portrait": "neutral", "text": "He says hi."},
		{"scene": "ending", "fade": true}
	]
}
```

## Scene types

| Type | What it does |
|---|---|
| `normal` | A character talks: portrait, name tag and text box. |
| `single` | Text in the middle of the screen, without box or portrait. |
| `wait` | Waits a few seconds (`duration`). |
| `fade` | Fades backgrounds to an `alpha` in `duration` seconds. `target` = background IDs, or `black` (the default). |
| `free` | Does nothing by itself: a script handles it (see below). |
| `ending` | Ends the dialogue, with a fade if `fade` is on. |

Every scene can also:

- change the **speed**, **font** and **size** of the text;
- **advance by itself**, right away or after a delay;
- play an **effect**: `shake` the screen, `flash` it with a color, or `textShake` the text;
- start or stop a **music track** (it loops) and play a **sound effect**, each with volume, fade, pitch, delay and how long it plays;
- keep the text of the scene before (`keepText`).

## The Dialogue Editor

Open it from the Editor Menu. It opens the dialogue of the last played song, or a template.

The preview on the left is the real dialogue, exactly as it looks in game.

| Part | What's inside |
|---|---|
| **File** menu | Save, Load from JSON, Load Template, Antialiasing ON/OFF, Exit. |
| **Scene** tab | The selected scene: type, character, portrait, text, speed, effects. Buttons to duplicate, add, remove and move scenes. |
| **Audio** tab | Music and sound of the scene, and the music of the whole dialogue. |
| **Character** tab | The character: portrait, size, position, colors, name tag, voice, animations. |
| **Style** tab | The style: box, text, fonts, voices, hints, backgrounds. |
| Bottom | **Mute Editor Music**, **Mute Voices**, **Preview Music/SFX**. |

**Save** writes the dialogue, and also the style and every character you changed in the mod's `data/dialogue/` folder.

Color fields have a **+** button that opens a color picker. A color can be a hex code (`FF0000`), `bf` / `dad` / `gf`, or the name of a character (it uses its health bar color).

| Key | Action |
|---|---|
| A / D | Previous / next scene |
| Space | Replay the scene |
| Enter | Advance the preview |
| W / S | Previous / next portrait animation |
| Arrow keys | Move the portrait (*Style* tab: move the box). Shift = 10x |
| Ctrl + arrow keys | Move the offset of the portrait animation |
| Ctrl + S | Save |

## Scripts

### Free scenes

A `free` scene stops the dialogue and calls `onDialogueCustom` in the song's scripts. Do anything you want, then call `nextDialogueScene()` to go on:

```lua
function onDialogueCustom(name, index)
	if name == 'doorSlam' then
		playSound('doorslam')
		cameraShake('other', 0.02, 0.5)
		runTimer('afterSlam', 0.6)
	end
end

function onTimerCompleted(tag)
	if tag == 'afterSlam' then
		nextDialogueScene()
	end
end
```

### Functions and callbacks

| Function | What it does |
|---|---|
| `startDialogue(?name, ?resume)` | Starts `data/songs/<song>/<name>.json`. With `resume` on, the song starts (or ends) when the dialogue is over. |
| `nextDialogueScene()` | Goes to the next scene. |
| `endDialogue(?fade, ?duration)` | Ends the dialogue now. |
| `isDialogueRunning()` | `true` while a dialogue is on screen. |

| Callback | When |
|---|---|
| `onDialogueStart(name)` | Before a dialogue starts. Return `Function_Stop` to cancel it. |
| `onDialogueScene(index, type, character)` | At every new scene. |
| `onDialogueCustom(name, index)` | At a `free` scene. |
| `onDialogueEnd(name)` | When the dialogue ends. |

While a dialogue runs, its parts can be used like any other object: `dialogue_box`, `dialogue_text`, `dialogue_black`, `dialogue_<background id>` and `dialogue_portrait_<character id>`.
