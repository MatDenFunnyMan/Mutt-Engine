# Stages

A stage is a `.json` file in `data/stages/`, with its images in `content/images/stages/`. You can also add a Lua or HScript file with the same name next to it, for anything the JSON can't do. The **Stage Editor** builds the JSON for you.

All the base game stages are JSON files too, so you can open them in the editor and learn from them.

## The Stage Editor

Open it from the Editor Menu. Press **F1** inside the editor for every shortcut.

| Part | What's inside |
|---|---|
| **Sprite List** | Every object of the stage, from back to front. The characters are in the list too: move them up or down to put objects in front of them. |
| **Stage** box | Pick the stage to edit, reload it, or load a template. |
| **Data** tab | Camera zoom and speed, positions of BF, GF and the opponent, camera offsets, hide a character, **Pixel Stage**, UI style. |
| **Object** tab | The selected object: name, image, position, scale, scroll factor, angle, color, opacity, blend mode, flip, antialiasing, and in which quality it shows up (low, high or both). |
| **Meta** tab | Which characters to preview in the editor, and the **Preload List** (files loaded before the song starts). |
| **Extras** tab | Spots for the extra characters (Character 3 to 10). |

Press **Enter** to add an object. It can be:

- **No Animation**: a normal image.
- **Animated**: a spritesheet with animations (Enter again with the object selected opens its animations).
- **Square**: a plain colored rectangle, no image needed.

### Shortcuts

| Key | Action |
|---|---|
| Arrow keys, right click + drag | Move the selected object (Shift = faster, Ctrl = one pixel at a time) |
| E / Q | Zoom in / out |
| J / K / L / I | Move the camera |
| R | Reset the zoom |
| Delete | Remove the selected object |
| Ctrl + C / X / V | Copy / Cut / Paste |
| Ctrl + Z / Ctrl + Shift + Z | Undo / Redo |
| Ctrl + S | Save |
| F12 | Show / hide the selection rectangle |

## Pixel stages

Check **Pixel Stage** in the *Data* tab for stages made of pixel art, like the week 6 school. The countdown, ratings and notes switch to their pixel versions.

## Extra characters

The *Extras* tab adds spots for extra characters, from **Character 3** up to **Character 10**. For each one you set:

- the **position** (drag it, like the other characters);
- the **camera offset**, or **Camera Follows** to make the camera use BF's, GF's or the opponent's spot;
- a character to **preview** it in the editor (only for the editor: the real character is picked in the chart).

New spots appear in the *Sprite List* as `character3`, `character4`..., so you can put them behind or in front of any object. **Remove Last** only removes the last spot, so the numbers in your charts never change.

Then give each spot a character in the Chart Editor: see [Extra characters](02-charts-and-songs.md#extra-characters).

## Stage scripts

A script with the same name as the stage (`data/stages/park.lua`) runs in every song that uses that stage. Objects made in the editor can be used by their **name**:

```lua
function onBeatHit()
	if curBeat % 4 == 0 then
		playAnim('crowd', 'cheer', true)
	end
end
```

### Moving backgrounds

Two functions are made for stages:

```lua
function onCreate()
	createBackdrop('clouds', 'stages/park/clouds', 0, -200, {axes = 'x', velocityX = 30, scrollX = 0.3})
	createParticles('leaves', 'stages/park/leaf', 0, -100, {amount = 40, speed = {50, 120}, spin = {-90, 90}})
end
```

- `createBackdrop` repeats an image forever (sky, clouds, a road) and can scroll it by itself.
- `createParticles` shoots many small copies of an image, or colored squares when there is no image (snow, leaves, sparks).

Every option of both functions is on the [Lua API page](15-lua-api.md).
