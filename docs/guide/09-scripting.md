# Scripting

Scripts add anything the editors can't do. Mutt Engine runs **Lua** (`.lua`) and **HScript** (`.hx`, Haxe code) scripts. Every function on the [Lua API page](15-lua-api.md) works in Lua; HScript can also use the engine's classes directly.

## Where scripts go

| Folder | When it runs |
|---|---|
| `scripts/` | In every song of the mod. |
| `data/songs/<song>/scripts/` | Only in that song. |
| `data/stages/<stage>.lua` | In every song with that stage. |
| `custom_events/<Event Name>.lua` | When the chart has that event. See [Charts & Songs](02-charts-and-songs.md#your-own-events). |
| `custom_notetypes/<Note Type>.lua` | When the chart has that note type. See [Notes](05-notes.md#note-types). |
| `states/` and `states/substates/` | Your own menus and screens (see below). |
| `data/LoadingScreen.lua` | The loading screen. |

## A first script

A script is made of **callbacks**: functions with fixed names that the game calls at the right moment.

```lua
function onCreate()
	createText('hello', 'Hello!', 0, 100, {size = 48})
	screenCenter('hello', 'x')
end

function onBeatHit()
	if curBeat % 2 == 0 then
		setProperty('hello.angle', 10)
	else
		setProperty('hello.angle', -10)
	end
end
```

The most used callbacks:

| Callback | When |
|---|---|
| `onCreate()` / `onCreatePost()` | When the song is loading / after everything is loaded. |
| `onSongStart()` | When the music starts. |
| `onUpdate(elapsed)` / `onUpdatePost(elapsed)` | Every frame. |
| `onBeatHit()` / `onStepHit()` / `onSectionHit()` | On every beat / step / section (`curBeat`, `curStep`, `curSection`). |
| `goodNoteHit(id, direction, noteType, isSustainNote)` | The player hits a note. |
| `opponentNoteHit(...)` / `noteMiss(...)` | The opponent hits a note / the player misses one. |
| `onEvent(name, value1, value2, strumTime)` | A chart event is triggered. |
| `onTweenCompleted(tag)` / `onTimerCompleted(tag, loops, loopsLeft)` | A tween or a timer ends. |
| `onEndSong()` / `onGameOver()` / `onPause()` | End of the song / game over / pause. Return `Function_Stop` to stop it. |

New in Mutt Engine: `onCountdownStarted`, `onHoldDrop(direction, remaining)` (a hold note released too early), `onExitSong` (leaving from the pause menu), `onResultsScreen(score, accuracy, misses)` and the [dialogue callbacks](08-dialogues.md#functions-and-callbacks).

## New functions

Mutt Engine adds many functions on top of Psych Engine's. A few examples:

| Function | What it does |
|---|---|
| `createSprite`, `createAnimatedSprite`, `createText` | Create **and add** an object in one line, with an options table. |
| `createBackdrop`, `createParticles`, `createGradient` | Scrolling backgrounds, particles, gradients. |
| `startTween`, `noteTween`, `tweenNumber`, `tweenShader` | Tween several values at once. `pauseTween` / `resumeTween` work on all of them. |
| `focusCamera`, `centerCamera` | Move the camera like the Cam Follow Pos and Center Camera events. |
| `setCharacterPos`, `setCamOffset` | Move a character, or the spot its camera looks at. |
| `typeText` | Writes a text letter by letter. |
| `switchState(name, {transition = ...})` | Changes screen with a fade, stickers or nothing. |
| `autoPlay(true)` | The game plays by itself, but it counts as real play. |
| Window functions | Move, resize, tween, rename the game window. |
| `string.split`, `table.contains`, `math.clamp`... | Small helpers added to the Lua standard library. |

### Options tables

Many new functions take a table of options as the last value. Write only the options you need, by name:

```lua
createSprite('sky', 'stages/park/sky', -400, -300, {scrollX = 0.2, scrollY = 0.2, alpha = 0.8})
startTween('fade', 'sky', {alpha = 0}, 2, {ease = 'sineOut', startDelay = 1})
```

### Deprecated functions

Some old functions have a better replacement (for example `makeLuaSprite` + `addLuaSprite` became `createSprite`). They still work. With `luaDebugMode = true` the game shows a warning once, with the name of the replacement. The [Lua API page](15-lua-api.md) marks them as **DEPRECATED**.

## Custom states

A custom state is your own screen: a menu, a gallery, a credits page. Put a script in `states/` and open it with `switchState('MyState')`.

```lua
-- states/MyState.lua
function onCreate()
	createText('title', 'My Gallery', 0, 80, {size = 64})
	screenCenter('title', 'x')
end

function onUpdate(elapsed)
	if keyJustPressed('back') then
		switchState('MainMenuState')
	end
end
```

- Name the file like a built-in state (`MainMenuState.lua`, `FreeplayState.lua`...) to **replace** it.
- Return `true` from `isInitialState()` to make the game boot into your state instead of the title screen (only for files directly in `states/`).
- Substates go in `states/substates/` and open on top of the current state with `openSubState('Name')`. Close them with `closeSubState()`.
- If both `MyState.hx` and `MyState.lua` exist, the `.hx` one is used.
- Custom states only work when one mod is active (see [Getting Started](01-getting-started.md#choosing-mods)).

State scripts have some functions of their own (songs, weeks, scores, loading bar): the API page marks them as **STATE**.

## The loading screen

`data/LoadingScreen.lua` changes the loading screen. It gets `onCreate`, `onUpdate` and `onLoad`, the objects `bar` and `barBack` (the loading bar), and the functions `getLoaded()` and `getLoadMax()`.

## Writing scripts in VS Code

**DogO-01** is a Visual Studio Code extension made for Mutt Engine. It knows every function, callback and variable, warns about deprecated functions, suggests the images, sounds and other files of your mod while you type, checks the JSON files and creates new scripts from templates.

Install it from `dogo-01-1.3.0.vsix`: in VS Code, *Extensions* > `...` > **Install from VSIX**.
