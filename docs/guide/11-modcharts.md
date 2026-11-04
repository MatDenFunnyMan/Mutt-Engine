# Modcharts

A modchart moves, spins, hides or bends the notes and the strums during a song. Mutt Engine's modcharts are based on [TheZoroForce240's Modcharting Tools](https://github.com/TheZoroForce240/FNF-Modcharting-Tools), with an editor made to be easy.

A modchart is saved as `data/songs/<song>/modchart.json` and plays by itself with the song.

## The words

| Word | Meaning |
|---|---|
| **Modifier** | An effect on the notes, like moving them sideways or making them drunk. It has a name, a type and a value. |
| **Event** | Changes the value of one or more modifiers at a beat, over a duration, with an ease. |
| **Playfield** | A copy of the strumlines. Use it for effects with two sets of arrows on screen. |

A modifier can affect all the notes, only the player's (`PLR`), only the opponent's (`OPP`), one lane (`0`-`3` opponent, `4`-`7` player, `8`+ extra strumlines) or the strumline of an extra character (`C`).

## The Modchart Editor

Open it from the Editor Menu, or with the **Modchart** debug key during a song (Developer Mode on).

1. Press **New** to create a modifier: choose the effect, the notes it affects, and give it a name.
2. **Right click** on the modifier's row, under the preview, to add an event.
3. Click the event to change its value, beat, duration and ease in the side panel.
4. Press **Space** to watch the modchart.

To bring a modifier back to normal, add another event later with value 0.

**File > Example Modchart** loads a ready example to play with. Press **F1** for the full help.

| Key | Action |
|---|---|
| Space | Play / pause |
| A / D, Left / Right | One beat back / forward |
| Mouse wheel | Scroll the timeline (Shift = faster) |
| Ctrl + mouse wheel | Zoom the timeline |
| Home / End | Start / end of the song |
| [ / ] | Playback speed (Alt = reset) |
| Right click on a row | New event |
| Drag an event / its tail | Move it / change its duration |
| Delete | Delete the event |
| Ctrl + C / Ctrl + V | Copy / paste at the current position |
| Ctrl + Z / Ctrl + Shift + Z | Undo / redo |
| Ctrl + S | Save |
| Enter | Playtest |

One event can change more modifiers at once: use **Add** and the arrows in the event panel.

## Modcharts in scripts

Modcharts can also be written in a song script, with the same functions as Modcharting Tools:

```lua
function onCreatePost()
	startMod('wave', 'DrunkXModifier', '', -1)
	ease(16, 4, 'sineInOut', '1, wave')
	ease(32, 2, 'sineInOut', '0, wave')
end
```

| Function | What it does |
|---|---|
| `startMod(name, modClass, ?type, ?playfield)` | Creates a modifier. `type`: `all`, `player`, `opponent`, `lane` or `character`. |
| `setMod(name, value)` / `setSubMod(name, sub, value)` | Sets a value right away. |
| `set(beat, 'value, name')` | Sets a value at a beat. |
| `ease(beat, duration, ease, 'value, name')` | Tweens a value at a beat. |
| `tweenModifier(name, value, time, ease)` | Tweens a value now. |
| `setModTargetLane(name, lane)` | The lane (or character number) of a `lane` / `character` modifier. |
| `addPlayfield(?x, ?y, ?z)` / `removePlayfield(index)` | Add / remove a playfield. |

The modifier classes (`DrunkXModifier`, `TipsyYModifier`, `ReverseModifier`...) are the ones listed in the editor's **New** window.
