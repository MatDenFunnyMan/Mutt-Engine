CUSTOM SUBSTATES - FULL FUNCTION REFERENCE
Mutt Engine 1.0.0

Read states/readme.txt first. This file only covers what is DIFFERENT for
substates. Everything in the state reference still applies unless said
otherwise here.


WHERE FILES GO
--------------
  mods/<yourmod>/states/substates/PauseSubState.hx     HScript version
  mods/<yourmod>/states/substates/PauseSubState.lua    Lua version

Subfolders work: states/substates/menus/PauseSubState.lua is found by the
name "PauseSubState".

The engine looks for the .hx file FIRST. If both PauseSubState.hx and
PauseSubState.lua exist, the .hx one wins and the .lua one is never loaded.

Custom substates only work in SINGLE MOD mode. In "ALL MODS",
"MODS + FNF SONGS" and "DISABLE MODS" the loaders return nothing and the
hardcoded substate is used.


HOW A SUBSTATE GETS OPENED
--------------------------
This is the part people get wrong, so read it twice.

A file in states/substates/ is a REPLACEMENT for a built-in substate. You do
not open it by name from a script. The engine opens it for you, by file name,
at the moment it would have opened its own version. If the file is there,
yours runs instead. If it is not, the built-in one runs.

Name your file after one of these and it takes over:

  PauseSubState               PlayState, when the player pauses
  GameOverSubstate            PlayState, when the player dies
  GameplayChangersSubstate    FreeplayState and StoryMenuState
  ResetScoreSubState          FreeplayState and StoryMenuState
  ResetAchievementSubstate    AchievementsMenuState
  ControlsSubState            OptionsState
  NotesColorSubState          OptionsState
  GraphicsSettingsSubState    OptionsState
  VisualsSettingsSubState     OptionsState
  GameplaySettingsSubState    OptionsState
  DeveloperSettingsSubState   OptionsState
  LanguageSubState            OptionsState

Any other file name in states/substates/ is dead weight. Nothing will ever
load it.

If what you want is a substate of your own, opened whenever you feel like it,
that is a different feature and it already exists: openCustomSubstate. See
"YOUR OWN SUBSTATE" at the bottom.


PART 1 - LUA

A Lua substate is a full Lua state under the hood, so EVERY callback and EVERY
function listed in states/readme.txt is available here too: sprites, text,
tweens, timers, sound, cameras, input, shaders, video, files, save data,
properties, characters, achievements, translations, discord, math. Nothing is
taken away. Sprites you add with addLuaSprite land on the substate, not on the
state below it.

CALLBACKS
-------------------
  onCreate()                    substate is being built
  onCreatePost()                right after onCreate
  onUpdate(elapsed)             every frame, before the engine updates
  onUpdatePost(elapsed)         every frame, after the engine updates
  onStepHit()                   on every step of the song/music
  onBeatHit()                   on every beat of the song/music
  onDestroy()                   substate is being thrown away

PRESET VARIABLES
----------------
  subStateName         name of this substate, same as the file name
  curStep              current step, updated before onStepHit
  curBeat              current beat, updated before onBeatHit
  screenWidth          1280
  screenHeight         720
  buildTarget          'windows', 'linux', 'mac', 'browser' or 'unknown'
  currentModDirectory  folder name of the mod running this script
  Function_Stop        return this from a callback to stop the engine's default
  Function_Continue    return this to let everything continue (default)
  Function_StopLua     stop other Lua scripts from getting this callback
  Function_StopHScript stop HScript scripts from getting this callback
  Function_StopAll     stop everything

CLOSING YOURSELF
----------------
  close()              close this substate and go back to the state below
  closeSubState()      exactly the same thing

Both are rewired to close YOU, not something on top of you. This is the one
place where a substate behaves differently from a state.

FUNCTIONS THAT DO NOT WORK HERE
-------------------------------
These exist because a substate borrows the state API, but they act on a
detached object and you will see nothing happen. Do not use them:

  openSubState(name)            does nothing, close() first and let the state
                                below open the next one
  openCustomSubstate(name)      does nothing, it is a PlayState feature
  closeCustomSubstate()         same
  insertToCustomSubstate(...)   same
  isInitialState()              only scanned for states, never for substates

resetState() works but it rebuilds the STATE underneath, which throws your
substate away in the process. Rarely what you want.


PART 2 - HSCRIPT

HScript substates are NOT the Lua API. You get the real Haxe classes and you
use them directly.

LIFECYCLE CALLBACKS
-------------------
Note the names differ from Lua. It is create and update, not onCreate and
onUpdate.

  create(substate)          substate is being built, receives itself
  update(elapsed)           every frame
  onStepHit()               on every step, curStep is set before it runs
  onBeatHit()               on every beat, curBeat is set before it runs
  onDestroy()               fired right before the substate is destroyed

There is no create post or update post in HScript, and no onCloseSubState
either, that one is a state callback.

PRESET VARIABLES
----------------
  substate                  the substate object itself
  parent                    the state underneath it
  game                      PlayState.instance, null outside of gameplay
  members                   everything currently in it
  add(obj)                  add an object
  remove(obj, splice)       remove an object
  insert(position, obj)     add an object at a specific draw position
  camera / cameras          the current camera and the camera list
  save                      the engine's FlxSave
  sound                     FlxG.sound
  close()                   close this substate
  switchState(state)        leave for another state, taking an instance
  switchStateByName(name)   leave for another state by its name
  curStep / curBeat         set right before onStepHit and onBeatHit

That is the whole list. A substate does NOT get state, openSubState,
closeSubState, switchStateDirect, switchStateDirectByName, resetState,
persistentUpdate or persistentDraw. If you need the state's own fields, go
through parent.

CLASSES YOU CAN USE WITHOUT IMPORTING
-------------------------------------
Flixel:      FlxG, FlxSprite, FlxText, FlxCamera, FlxTimer, FlxTween, FlxEase,
             FlxColor, FlxMath, FlxGradient, FlxAxes, FlxSubState, FlxAnimate
Engine:      PlayState, Paths, Conductor, ClientPrefs, Mods, Character, Alphabet,
             Note, HoldCover, Countdown, Achievements, CustomSubstate,
             MusicBeatSubstate, StateManager, LoadingState, PsychCamera,
             ModchartSprite
Shaders:     FlxRuntimeShader, ErrorHandledRuntimeShader, ShaderFilter, ColorSwap
Scale modes: FillScaleMode, RatioScaleMode, FixedScaleMode, StageSizeScaleMode
Haxe/system: Type, Sys, System, StringTools, Json, File, FileSystem, Sound,
             Capabilities, Application, lime
3D (Away3D): Flx3DView, Flxview3D, Flx3DUtil, Flx3DCamera, Mesh, ColorMaterial,
             PerspectiveLens, Vector3D, Asset3DType

Blend mode constants are ready to use as bare names: ADD, ALPHA, DARKEN,
DIFFERENCE, ERASE, HARDLIGHT, INVERT, LAYER, LIGHTEN, MULTIPLY, NORMAL,
OVERLAY, SCREEN, SHADER, SUBTRACT.

HELPER FUNCTIONS
----------------
  setVar(name, value) / getVar(name) / removeVar(name)    shared with Lua scripts
  debugPrint(text, color)                                 on-screen debug log
  getModSetting(saveTag, modName)                         read a mod settings value
  switchStateWithStickers(state, mode)                    sticker transition
  getHoldCoverProperty(cover, variable)
  setHoldCoverProperty(cover, variable, value)
  updateHoldCoverHitbox(cover)
  keyboardJustPressed(name) / keyboardPressed(name) / keyboardReleased(name)
  keyJustPressed(name) / keyPressed(name) / keyReleased(name)
  anyGamepadJustPressed(name) / anyGamepadPressed(name) / anyGamepadReleased(name)
  gamepadJustPressed(id, name) / gamepadPressed(id, name) / gamepadReleased(id, name)
  gamepadAnalogX(id, leftStick) / gamepadAnalogY(id, leftStick)


YOUR OWN SUBSTATE

If you want a substate that is yours and that you open when you decide, do not
put a file in states/substates/. Use the custom substate, which is built from
inside a PlayState script:

  openCustomSubstate(name, pauseGame)     open a blank substate
  insertToCustomSubstate(tag, pos)        move one of your objects into it
  closeCustomSubstate()                   close it

It fires its own callbacks instead of the normal ones:

  onCustomSubstateCreate(name)
  onCustomSubstateCreatePost(name)
  onCustomSubstateUpdate(name, elapsed)
  onCustomSubstateUpdatePost(name, elapsed)
  onCustomSubstateDestroy(name)

This works from song scripts and from custom states written in Lua. It is a
blank canvas you fill yourself, so there is no file to write.


QUICK EXAMPLES

states/substates/PauseSubState.lua

  function onCreate()
      makeLuaSprite('dim', '', 0, 0)
      makeGraphic('dim', 1280, 720, '000000')
      setProperty('dim.alpha', 0.6)
      addLuaSprite('dim', true)

      makeLuaText('label', 'PAUSED', 1280, 0, 300)
      setTextSize('label', 64)
      setTextAlignment('label', 'center')
      addLuaText('label')
  end

  function onUpdate(elapsed)
      if keyJustPressed('back') then
          close()
      end
  end


states/substates/PauseSubState.hx

  var label:FlxText;

  function create(substate) {
      var dim = new FlxSprite().makeGraphic(1280, 720, FlxColor.BLACK);
      dim.alpha = 0.6;
      add(dim);

      label = new FlxText(0, 300, 1280, 'PAUSED');
      label.setFormat(Paths.font('vcr.ttf'), 64, FlxColor.WHITE, 'center');
      add(label);
  }

  function update(elapsed) {
      if (keyJustPressed('back'))
          close();
  }


=== NOTES ===

- Lua uses onCreate/onUpdate, HScript uses create/update. Mixing them up is the
  single most common reason a script "does nothing".
- The file name IS the trigger. Rename PauseSubState.lua to Pause.lua and it
  will never run again.
- .hx beats .lua when both exist under the same name.
- Custom substates are ignored unless the mod mode is SINGLE MOD.
- Replacing PauseSubState or GameOverSubstate means YOU are now responsible for
  resuming, restarting and quitting the song. If your script has no way out,
  the player is stuck.
- close() is the way out of a substate. In Lua closeSubState() does the same.
- If a script fails to load, the engine falls back to the built-in substate
  without saying anything on screen. Check the terminal output or the crash/
  folder.
