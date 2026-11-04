# Notes

Mutt Engine has one editor for everything about notes: the **Note Editor**. With it you make **Note Packs** (a full note skin) and **note types** (notes with their own look and rules).

## Note Packs

A Note Pack is one `.json` file in `data/notes/` with the look of:

- the **strums** (the arrows at the top),
- the **notes**,
- the **splashes** (the effect when you hit Sick),
- the **hold covers** (the effect while you hold a note).

Each part can be different for the player and the opponent, and can have a **pixel** version for pixel stages. A pack can also give the strums a starting **tint** (a color over the arrows).

To use a pack in a song, pick it in the Chart Editor, *Data* tab, **Note Pack**. To change it in the middle of a song, write its name in the **Change Notes** event.

## The Note Editor

Open it from the Editor Menu. Press **F1** inside the editor for the controls.

| Part | What's inside |
|---|---|
| **File** menu | Save, Load from JSON, Load Template, New Notetype, Load Notetype. |
| **Shader** menu | **Strumline Shader** (the tint of the arrows), **Notes RGB**, **Splashes RGB**, **Hold RGB** (colors of each part). |
| **Strumline**, **Notes**, **Splashes**, **Hold Notes** tabs | Image, scale, antialiasing, **Pixel?** (edit the pixel version), RGB, and the animations of that part. |
| **Gameplay** tab | Only for note types: the rules of the note. |

The preview on the left is a real strumline: press **your note keys** to try the animations, click an arrow to select it.

| Key | Action |
|---|---|
| Your note keys | Press the arrows like in a song |
| Arrow keys | Move the offset of the selected animation |
| Ctrl + arrow keys | Move the base offset of the whole part |
| Q / E | Previous / next frame |
| G | Show / hide the default strumline, to compare positions |
| Ctrl + S | Save |

Fields you don't touch keep the default values, so a pack can change only what it needs (for example, only the splashes).

## Note types

A note type is a note with its own look and its own rules, like the hurt notes or the static notes of Sonic.EXE mods. It's made of two files with the same name in `custom_notetypes/`:

- `Static Note.json`: the look and the rules, made in the Note Editor (*File > New Notetype*).
- `Static Note.lua` (or `.hx`): anything else, written by you. The *Gameplay* tab has buttons that create it already filled in.

For a note type that exists in one song only, put the files in `data/songs/<song>/custom_notetypes/`.

### The Gameplay tab

| Rule | What it does |
|---|---|
| Hit Causes Miss | Hitting the note counts as a miss. |
| Can Skip (No Miss) | The player can let it pass without a miss. |
| Opponent Ignores Note | The opponent doesn't hit it. |
| No Animation / No Miss Anim | The character doesn't sing / doesn't play the miss animation. |
| No Splash | No splash on Sick. |
| Low Priority | When two notes overlap, this one is hit last. |
| Health Gain / Health Loss | Health on hit and on miss (normal: 0.02 and 0.1). |
| Hitsound | Sound when you hit it, from `sounds/`. |
| Animation Suffix | Added to the sing animation, like `-alt`. |

### The script

The script runs only when the song has notes of that type. Check the note type, because the functions run for every note:

```lua
function noteMiss(id, direction, noteType, isSustainNote)
	if noteType == 'Static Note' then
		playSound('static', 0.6)
		cameraShake('game', 0.01, 0.2)
	end
end
```

Old Psych note types (a `.lua` with an optional `.txt` description) still work.

## Tinting the strums

The strums can be tinted with a color, from the Note Pack or from a script:

```lua
function onBeatHit()
	if curBeat == 64 then
		tweenStrumTint('redArrows', 'opponent', 'FF0000', 1, 'sineOut', 0.6)
	end
end
```

| Function | What it does |
|---|---|
| `setStrumTint(target, color, ?strength)` | Tints the arrows right away. |
| `tweenStrumTint(tag, target, color, duration, ?ease, ?strength)` | Fades to a tint. |
| `resetStrumTint(target, ?duration, ?ease)` | Back to the tint of the Note Pack (or none). |

`target` is `player`, `opponent`, `all`, `char3` (strumline of Character 3) or a lane number. `strength` goes from 0 (no tint) to 1 (full color).
