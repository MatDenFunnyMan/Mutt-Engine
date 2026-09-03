CUSTOM STATES & SUBSTATES - FULL FUNCTION REFERENCE
Mutt Engine 1.0.0

WHERE FILES GO
--------------
  mods/<yourmod>/states/MyState.lua        a custom state written in Lua
  mods/<yourmod>/states/MyState.hx         a custom state written in HScript
  mods/<yourmod>/states/substates/X.lua    a custom substate written in Lua
  mods/<yourmod>/states/substates/X.hx     a custom substate written in HScript

Subfolders work: states/menus/MyState.lua is found by the name "MyState".
The engine looks for the .hx file FIRST. If both MyState.hx and MyState.lua
exist, the .hx one wins and the .lua one is never loaded.

Custom states only work in SINGLE MOD mode. In "ALL MODS", "MODS + FNF SONGS"
and "DISABLE MODS" the loaders return nothing and the hardcoded state is used.

You can also REPLACE a built-in state: name your file after it
(MainMenuState.lua, FreeplayState.hx, CreditsState.lua, ...) and your version
is used instead of the engine's.

Note: states/LoadingState and states/LoadingScreen are deliberately ignored.
The loading screen script is a different thing and lives in
mods/<yourmod>/data/LoadingScreen.lua instead.


HOW TO OPEN
---------------
  From any script:      switchState('MyState')
  Without transition:   switchStateDirect('MyState')
  With stickers:        switchStateWithStickers('MyState')
  As a substate:        openSubState('MySubState')

To make your state the one the game BOOTS INTO instead of the title screen,
declare isInitialState and return true:

  function isInitialState()
      return true
  end

Careful: the boot scan only looks at files sitting DIRECTLY in states/, not in
subfolders. switchState is recursive, the boot scan is not. If your initial
state lives in states/menus/ it will never be picked at startup.

PART 1 - LUA

CALLBACKS
-------------------
Declare any of these in your .lua file. All are optional.

  onCreate()                    state is being built, before anything is added
  onCreatePost()                right after onCreate
  onUpdate(elapsed)             every frame, before the engine updates
  onUpdatePost(elapsed)         every frame, after the engine updates
  onStepHit()                   on every step of the song/music
  onBeatHit()                   on every beat of the song/music
  onCloseSubState()             a substate on top of you was just closed
  onDestroy()                   state is being thrown away
  onTweenCompleted(tag)         a tween made with doTween*/startTween finished
  onTimerCompleted(tag, loops, loopsLeft)   a runTimer timer fired
  onVideoFinished(name)         a startVideo video reached its end
  onVideoSkipped(name)          the player skipped a startVideo video
  isInitialState()              return true to boot the game into this state

Substates get the same list. onCustomSubstateCreate, onCustomSubstateCreatePost,
onCustomSubstateUpdate, onCustomSubstateUpdatePost and onCustomSubstateDestroy
fire instead when the substate was opened with openCustomSubstate.


PRESET VARIABLES
----------------
  stateName            name of the current state
  subStateName         name of the current substate (substates only)
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


--- STATE FLOW ---
  switchState(name)                                 leave for another state, with transition
  switchStateDirect(name)                           same, but skip the transition
  switchStateWithStickers(name, mode, song, diff)   leave using the sticker transition
  resetState()                                      rebuild the current state from scratch
  openSubState(name)                                open a substate from states/substates/
  closeSubState()                                   close the substate on top
  close()                                           inside a substate, closes itself
  setReturnState(name)                              remember where to go back to
  getReturnState()                                  read back what setReturnState stored
  openCustomSubstate(name, pauseGame)               open a CustomSubstate by tag
  closeCustomSubstate()                             close it
  insertToCustomSubstate(tag, pos)                  move an object into the custom substate

--- SONGS, WEEKS AND SCORES ---
  getSongsFromWeek(weekName)                        list of song names in that week json
  getDifficulties()                                 list of difficulty names
  getDifficultyName(index)                          difficulty name at that index
  loadSong(song, difficulty, folder)                load a chart and jump into PlayState
  songExists(song, difficulty, folder)              true if that chart file exists
  getSongDifficulties(song, folder)                 difficulties that song actually has
  getCurrentSong()                                  name of the song currently loaded
  getSongPosition()                                 playback position of the music, in ms
  getHighscore(song, difficulty)                    best score saved for that song
  getHighscoreRating(song, difficulty)              best accuracy saved for that song
  getHighscoreMisses(song, difficulty)              fewest misses saved for that song
  getScore(song, diffIndex)                         same as getHighscore but by index
  isMusicPlaying()                                  true if music is currently playing

--- SPRITES ---
  makeLuaSprite(tag, image, x, y)                   create a plain sprite
  makeAnimatedLuaSprite(tag, image, x, y, type)     create a sprite with a sparrow/packer atlas
  makeFlxAnimateSprite(tag, x, y, folder)           create an Adobe Animate atlas sprite
  loadAnimateAtlas(tag, folder, sprJson, animJson)  load atlas data into an animate sprite
  luaSpriteExists(tag)                              true if that tag is a sprite
  addLuaSprite(tag, inFront)                        actually put the sprite on screen
  removeLuaSprite(tag, destroy)                     take it off screen
  makeGraphic(obj, width, height, color)            fill the sprite with a solid rectangle
  loadGraphic(obj, image, gridX, gridY)             swap its image
  loadFrames(obj, image, type)                      swap its atlas
  loadMultipleFrames(obj, images)                   build one atlas out of several images
  screenCenter(obj, axes)                           center it, axes is 'x', 'y' or 'xy'
  setGraphicSize(obj, x, y, updateHitbox)           resize in pixels
  scaleObject(obj, x, y, updateHitbox)              resize by multiplier
  updateHitbox(obj)                                 recalculate size and offsets
  setScrollFactor(obj, x, y)                        how much it follows the camera
  setObjectCamera(obj, camera)                      move it to another camera
  setBlendMode(obj, blend)                          'add', 'multiply', 'screen', ...
  getObjectOrder(obj, group)                        its draw position
  setObjectOrder(obj, position, group)              change its draw position
  getMidpointX(obj) / getMidpointY(obj)             center point in world space
  getGraphicMidpointX(obj) / getGraphicMidpointY(obj)   center point of the drawn graphic
  getScreenPositionX(obj) / getScreenPositionY(obj) position as seen on screen
  getPixelColor(obj, x, y)                          color of one pixel of the sprite
  objectsOverlap(obj1, obj2)                        true if the two are touching

--- ANIMATIONS ---
  addAnimationByPrefix(obj, name, prefix, fps, loop)             add from an atlas prefix
  addAnimation(obj, name, frames, fps, loop)                     add from a frame list
  addAnimationByIndices(obj, name, prefix, indices, fps, loop)   add from selected frames
  addAnimationBySymbol(obj, name, symbol, fps, loop, x, y)       add from an Animate symbol
  addAnimationBySymbolIndices(obj, name, symbol, indices, fps, loop, x, y)   same, selected frames
  playAnim(obj, name, forced, reverse, startFrame)               play one
  addOffset(obj, anim, x, y)                                     per-animation offset

--- TEXT ---
  makeLuaText(tag, text, width, x, y)               create a text object
  addLuaText(tag, inFront)                          put it on screen
  removeLuaText(tag, destroy)                       take it off screen
  luaTextExists(tag)                                true if that tag is a text
  setTextString(tag, text) / getTextString(tag)     its content
  setTextSize(tag, size) / getTextSize(tag)         font size
  setTextWidth(tag, width) / getTextWidth(tag)      wrapping width
  setTextHeight(tag, height)                        fixed height
  setTextAutoSize(tag, value)                       let the box resize itself
  setTextFont(tag, font) / getTextFont(tag)         font file in fonts/
  setTextColor(tag, color)                          fill color
  setTextBorder(tag, size, color, style)            outline, style is 'outline' or 'shadow'
  setTextItalic(tag, italic)                        slant it
  setTextAlignment(tag, alignment)                  'left', 'center' or 'right'

--- PROPERTIES AND OBJECTS ---
  getProperty(variable, allowMaps)                              read anything on the state
  setProperty(variable, value, allowMaps, allowInstances)       write anything on the state
  getPropertyFromClass(class, variable, allowMaps)              read a static field
  setPropertyFromClass(class, variable, value, ...)             write a static field
  getPropertyFromGroup(group, index, variable, allowMaps)       read a field of a group member
  setPropertyFromGroup(group, index, variable, value, ...)      write a field of a group member
  addToGroup(group, tag, index)                                 put an object into a group
  removeFromGroup(group, index, tag, destroy)                   take one out
  callMethod(object, func, args)                                call a method on an object
  callMethodFromClass(class, func, args)                        call a static method
  createInstance(varName, className, args)                      build any Haxe class by name
  addInstance(varName, inFront)                                 add that instance to the state
  instanceArg(name, className)                                  pass an instance as an argument
  setVar(name, value) / getVar(name)                            shared variables between scripts

--- TWEENS AND TIMERS ---
  doTweenX(tag, obj, value, duration, ease)         tween the X position
  doTweenY(tag, obj, value, duration, ease)         tween the Y position
  doTweenAngle(tag, obj, value, duration, ease)     tween the rotation
  doTweenAlpha(tag, obj, value, duration, ease)     tween the transparency
  doTweenColor(tag, obj, color, duration, ease)     tween the color
  doTweenZoom(tag, camera, value, duration, ease)   tween a camera's zoom
  startTween(tag, obj, values, duration, options)   tween any set of fields at once
  cancelTween(tag)                                  stop a tween early
  runTimer(tag, time, loops)                        fire onTimerCompleted after a delay
  cancelTimer(tag)                                  stop a timer early

--- SOUND AND MUSIC ---
  playMusic(sound, volume, loop)                    replace the background music
  playSound(sound, volume, tag, loop)               play a sound effect
  stopSound(tag) / pauseSound(tag) / resumeSound(tag)   control a tagged sound
  luaSoundExists(tag)                               true if that tagged sound exists
  soundFadeIn(tag, duration, from, to)              fade a sound up
  soundFadeOut(tag, duration, to)                   fade a sound down
  soundFadeCancel(tag)                              stop a fade
  getSoundVolume(tag) / setSoundVolume(tag, value)  volume, 0 to 1
  getSoundTime(tag) / setSoundTime(tag, value)      playback position in ms
  getSoundPitch(tag) / setSoundPitch(tag, value, doPause)   playback speed
  precacheImage(name, allowGPU)                     load an image early to avoid a stutter
  precacheSound(name)                               same for a sound
  precacheMusic(name)                               same for music

--- CAMERAS ---
  setCameraZoom(zoom) / getCameraZoom()             zoom level
  cameraShake(camera, intensity, duration)          shake it
  cameraFlash(camera, color, duration, forced)      flash a color over it
  cameraFade(camera, color, duration, forced, fadeOut)   fade it in or out
  setCameraScroll(x, y)                             move the camera
  addCameraScroll(x, y)                             nudge the camera
  getCameraScrollX() / getCameraScrollY()           where it is
  setCameraScrollX(x) / setCameraScrollY(y)         move one axis
  getCameraScrollRawX() / getCameraScrollRawY()     position without the lerp smoothing

--- INPUT ---
  getMouseX() / getMouseY()                         mouse position
  mouseClicked(button) / mousePressed(button) / mouseReleased(button)
  setMouseVisible(visible) / getMouseVisible()      show or hide the cursor
  keyboardJustPressed(name) / keyboardPressed(name) / keyboardReleased(name) - raw keyboard, name is a key like 'SPACE' or 'A'
  keyJustPressed(name) / keyPressed(name) / keyReleased(name) - the game's own binds: 'left', 'down', 'up', 'right', 'accept', 'back', 'pause'
  anyGamepadJustPressed(name) / anyGamepadPressed(name) / anyGamepadReleased(name)
  gamepadJustPressed(id, name) / gamepadPressed(id, name) / gamepadReleased(id, name)
  gamepadAnalogX(id, leftStick) / gamepadAnalogY(id, leftStick)   stick position

--- SHADERS ---
Shaders live in mods/<yourmod>/content/shaders/ as a .frag and/or .vert pair.

  initLuaShader(name)                               load a shader by file name
  setSpriteShader(obj, shader)                      apply it to a sprite
  removeSpriteShader(obj)                           take it off
  setShaderFloat(obj, prop, value) / getShaderFloat(obj, prop)
  setShaderInt(obj, prop, value) / getShaderInt(obj, prop)
  setShaderBool(obj, prop, value) / getShaderBool(obj, prop)
  setShaderFloatArray(obj, prop, values) / getShaderFloatArray(obj, prop)
  setShaderIntArray(obj, prop, values) / getShaderIntArray(obj, prop)
  setShaderBoolArray(obj, prop, values) / getShaderBoolArray(obj, prop)
  setShaderSampler2D(obj, prop, imagePath)          feed an image into the shader
  setCameraShader(camera, shader)                   apply a shader to a whole camera
  removeCameraShader(camera)                        take it off
  setCameraShaderFloat(camera, prop, value) / getCameraShaderFloat(camera, prop)
  setCameraShaderInt(camera, prop, value) / getCameraShaderInt(camera, prop)
  setCameraShaderBool(camera, prop, value) / getCameraShaderBool(camera, prop)
  setCameraShaderFloatArray(camera, prop, values)
  setCameraShaderSampler2D(camera, prop, imagePath)

--- VIDEO ---
  startVideo(file, canSkip, forMidSong, shouldLoop, playOnLoad) - play a video from mods/<yourmod>/videos/, fires onVideoFinished or onVideoSkipped

--- FILES AND SAVE DATA ---
  getTextFromFile(path, ignoreModFolders)           read a text file
  saveFile(path, content, absolute)                 write a text file
  deleteFile(path, ignoreModFolders, absolute)      delete a file
  checkFileExists(filename, absolute)               true if it is there
  directoryFileList(folder)                         list of files in a folder
  initSaveData(name, folder)                        open a save slot of your own
  getDataFromSave(name, field, default)             read a field from it
  setDataFromSave(name, field, value)               write a field into it
  flushSaveData(name)                               commit it to disk
  eraseSaveData(name)                               wipe it
  getSave(key) / setSave(key, value) / flushSave()  quick access to the engine's own save
  getModSetting(saveTag, modName)                   read a value from the mod's settings menu

--- OTHER SCRIPTS ---
  getRunningScripts()                               list of scripts currently loaded
  isRunning(scriptFile)                             true if that one is loaded
  addLuaScript(file, ignoreAlreadyRunning)          load another Lua script
  addHScript(file, ignoreAlreadyRunning)            load an HScript script
  removeLuaScript(file) / removeHScript(file)       unload one
  setOnScripts(name, value, ignoreSelf, exclusions) set a variable on every script
  setOnLuas(...) / setOnHScript(...)                same, one language only
  callOnScripts(func, args, ...)                    call a function on every script
  callOnLuas(...) / callOnHScript(...)              same, one language only
  callScript(luaFile, func, args)                   call a function in one specific script
  runHaxeCode(code, vars, func, args)               run Haxe source from inside Lua
  runHaxeFunction(func, args)                       call a function defined by runHaxeCode
  addHaxeLibrary(name, package)                     make a Haxe class visible to runHaxeCode

--- CHARACTERS ---
  addCharacterToList(name, type)                    preload a character
  getCharacterX(type) / setCharacterX(type, value)  type is 'boyfriend', 'dad' or 'gf'
  getCharacterY(type) / setCharacterY(type, value)
  characterDance(character)                         force the idle animation

--- ACHIEVEMENTS ---
  achievementExists(name)                           true if it is defined
  isAchievementUnlocked(name)                       true if the player has it
  unlockAchievement(name)                           give it to them
  getAchievementScore(name)                         its progress counter
  setAchievementScore(name, value, saveIfNotUnlocked)   set the counter
  addAchievementScore(name, value, saveIfNotUnlocked)   add to the counter

--- TRANSLATIONS ---
  getTranslationPhrase(key, default, values)        translated string for a key
  setTranslationPhrase(key, value)                  override one at runtime
  getFileTranslation(key)                           translated file name for a key
  setFileTranslation(key, value)                    override one at runtime

--- DISCORD ---
  changeDiscordPresence(details, state, image, hasTime, endTime)   change the rich presence
  changeDiscordClientID(newID)                      use your own app id, no argument resets it

--- COLORS, MATH AND STRINGS ---
  FlxColor(color) / getColorFromString(color) / getColorFromHex(color) - turn 'RED' or 'FF00FF' into a usable color
  getColorFromName(color)                           same, by color name only
  lerp(a, b, t)                                     blend two numbers
  flxRandomInt(min, max, exclude)                   random whole number
  flxRandomFloat(min, max, exclude)                 random decimal
  flxRandomBool(chance)                             random true/false, chance is 0 to 100
  getRandomInt(min, max, exclude)                   same, exclude is a string like '3,7'
  getRandomFloat(min, max, exclude)
  getRandomBool(chance)
  stringStartsWith(str, start) / stringEndsWith(str, end)
  stringSplit(str, split) / stringTrim(str)
  getBuildTarget()                                  platform this build runs on
  debugPrint(text, color)                           print to the on-screen debug log


PART 2 - HSCRIPT

HScript states are NOT the same API as Lua. There are no add_callback helpers:
you get the real Haxe classes and you use them directly. Anything you can do in
Haxe you can do here.

LIFECYCLE CALLBACKS
-------------------
Note the names are different from Lua. It is create and update, not onCreate
and onUpdate.

  create(state)             state is being built, receives the state itself
  update(elapsed)           every frame
  onStepHit()               on every step, curStep is set before it runs
  onBeatHit()               on every beat, curBeat is set before it runs
  onCloseSubState()         a substate was closed. If you do not define this, the engine shows the mouse cursor by default
  onDestroy()               substates only, fired before it is thrown away
  isInitialState()          return true to boot the game into this state

PRESET VARIABLES IN A STATE
---------------------------
  state                     the state object itself
  members                   everything currently in it
  add(obj)                  add an object
  remove(obj, splice)       remove an object
  insert(position, obj)     add an object at a specific draw position
  camera / cameras          the current camera and the camera list
  save                      the engine's FlxSave
  sound                     FlxG.sound
  openSubState(substate)    open a substate
  closeSubState()           close the one on top
  switchState(state)        go to another state, taking an instance
  switchStateDirect(state)  same, without the transition
  switchStateByName(name)   go to another state by its name
  switchStateDirectByName(name)
  resetState()              rebuild this state
  persistentUpdate / persistentDraw   keep running or drawing under a substate
  curStep / curBeat         set right before onStepHit and onBeatHit

PRESET VARIABLES IN A SUBSTATE
------------------------------
  substate                  the substate object itself
  parent                    the state underneath it
  game                      PlayState.instance, null outside of gameplay
  close()                   close this substate
  add / remove / insert / members / camera / cameras / save / sound
  switchState(state) / switchStateByName(name)

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


QUICK EXAMPLES

states/MyState.lua

  function onCreate()
      makeLuaSprite('bg', 'menuDesat', 0, 0)
      addLuaSprite('bg', false)

      makeLuaText('title', 'HELLO', 1280, 0, 200)
      setTextSize('title', 64)
      setTextAlignment('title', 'center')
      addLuaText('title')
  end

  function onUpdate(elapsed)
      if keyJustPressed('accept') then
          switchState('MainMenuState')
      end
      if keyJustPressed('back') then
          switchState('MainMenuState')
      end
  end


states/MyState.hx

  var title:FlxText;

  function create(state) {
      var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
      bg.screenCenter();
      add(bg);

      title = new FlxText(0, 200, 1280, 'HELLO');
      title.setFormat(Paths.font('vcr.ttf'), 64, FlxColor.WHITE, 'center');
      add(title);
  }

  function update(elapsed) {
      if (keyJustPressed('accept'))
          switchStateByName('MainMenuState');
  }

=== NOTES ===

- Lua uses onCreate/onUpdate, HScript uses create/update. Mixing them up is the
  single most common reason a script "does nothing".
- A sprite made with makeLuaSprite is not visible until you call addLuaSprite.
  Same for text and addLuaText.
- .hx beats .lua when both exist under the same name.
- Custom states are ignored unless the mod mode is SINGLE MOD.
- isInitialState is only scanned in the top level of states/, not in subfolders.
- Substates read from states/substates/, and openSubState takes the file name
  without its extension.
- If a script fails to load, the engine falls back to the built-in state without
  saying anything on screen. Check the terminal output or the crash/ folder.
