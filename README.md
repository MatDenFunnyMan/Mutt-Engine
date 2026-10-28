# Mutt Engine

An FNF engine focused on "modernizing" modding, bringing features from other projects (Codename, Nightmare Vision, V-Slice, and more!) whilst adding TONS of useful coding functions for modding.
Base used: Cheese Engine by [@Chris](https://github.com/whenkenas) - Version 1.61

## WARNING
This project is partially **VIBE-CODED**. I used the assistance of AI for certain features and fixes, as I'm not a source code expert and don't know how to make such big changes on my own.
I wish I hadn't come to this, but sadly I don't have a team to help with this projects (plus I'm kinda lazy ok.).

### PLEASE DO NOT HARASS ME FOR USING AI.
This project is not meant to be taken seriously. Rather, this is meant to be a "mock-up" idea for other programmers to make a better NON VIBE-CODED engine and take my additions as a "baseplate" for your own projects.
Please someone take this and make it better without AI, thank you :)

Oh also yeah this was made to help me save some time for mods and add some cool features.

## CHANGES:

- New source structure, re-organized for a more "modern" look.
- EVEN better Chart Editor - Startup Wizard, Change Difficulty inside Editor, V-Slice/Codename compatibility, etc.
- Character Editor - Spritesheet View, Multi-Ghost, Icon Sub-Editor (4 icon states + animated icons)
- **Stage Editor** - TONS of bug fixes, Pixel Stage support, base game stages converted to JSON
- Custom States/Substates, softcoded in LUA/HX (custom Game Over, Pause Menu, etc.)
- V-Slice style Results Screen with ranks
- Modcharting, using [@TheZoroForce420's Modcharting Tools](https://github.com/TheZoroForce240/FNF-Modcharting-Tools) as a base.
- [@MaybeMaru](https://github.com/MaybeMaru/flixel-animate) for better Animate Atlas support, boosting performance.
- Friday Night Funkin' 0.8.6 content (Erect stages, Pico/BF Mixes), ported from [P-Slice](https://github.com/Psych-Slice/P-Slice).

## NEW IN 1.2:

- **Multi-Character** - up to 10 characters per song, sharing a strumline with BF/Dad or with their own strumline. Set them up in the Stage and Chart Editor, make them sing together with the new "Character Sing-Along" event.
- **Note Editor** - one editor for note skins, splashes and hold covers (Note Packs), strumline tint, and custom notetypes with their own skin and gameplay.
- **Shader Editor** - starting shaders for stages, objects and characters, plus RTX lighting for characters.
- **Week Editor** - Menu Character Editor merged inside, custom week colors, File menu and per-song Freeplay backgrounds (color picker or image).
- **Scripting refresh** - new Lua/HScript functions (createSprite, createText, focusCamera, noteTween, switchState, backdrops, particles, skew, shader tweens, autoPlay and more), old ones deprecated but still working.
- **New effects** - Ghost Trails, Silhouette and Background Flash, as events and script functions.
- **Custom Health Bar** - shape, frame and animated bars from your mod folder, smooth health bar option.
- **Blend modes** redone like V-Slice: every mode works now.
- **V-Slice ranks** for the Results Screen and Freeplay.
- **New options** - Unfocused Volume, Input Overlay, Note Camera Ease, Hold Note Tail.
- Random crashes fixed (audio streaming and loading screen).
- TONS of bug fixes.

**AND MORE!!**

---

## Installation:

Refer to [the Build Instructions](/docs/BUILDING.md)

## Customization:

If you wish to disable things like *Lua Scripts* or *Video Cutscenes*, you can refer to the `Project.xml` file.

Inside `Project.xml`, you will find several variables to customize Mutt Engine to your liking.

To start you off, disabling *Video Cutscenes* should be simple, simply delete the line `"VIDEOS_ALLOWED"` or comment it out by wrapping the line in XML-like comments, like this: `<!-- YOUR_LINE_HERE -->`

Same goes for *Lua Scripts*, comment out or delete the line with `LUA_ALLOWED`, this and other customization options are all available within the `Project.xml` file.

## Credits:
* **Matdenfunnyman** - Creator of Mutt Engine
