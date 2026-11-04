# Lua API

Every Lua function of Mutt Engine, by category.

- **NEW** = added by Mutt Engine. **CHANGED** = works differently than in Psych Engine.
- **DEPRECATED** = still works, but use the function written next to it. With `luaDebugMode = true` the game shows a warning.
- **STATE** = only in custom state scripts (see [Scripting](09-scripting.md#custom-states)).
- `?` before a value = optional. `{...}` = an options table: write only the options you need, by name (`{alpha = 0.5}`).

This page is made from the same list used by the **DogO-01** VS Code extension.

## Scripts & variables

| Function | What it does |
|---|---|
| `getRunningScripts()` | Lists the running scripts. |
| `setOnScripts(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null)` | Sets a variable in every script (Lua and HScript). |
| `setOnHScript(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null)` | Sets a variable in HScripts only. |
| `setOnLuas(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null)` | Sets a variable in Lua scripts only. |
| `callOnScripts(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null)` | Calls a function in every script. |
| `callOnLuas(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null)` | Calls a function in Lua scripts only. |
| `callOnHScript(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null)` | Calls a function in HScripts only. |
| `callScript(luaFile:String, funcName:String, ?args:Array<Dynamic> = null)` | Calls a function in one specific script. |
| `isRunning(scriptFile:String)` | Checks if a script is running. |
| `setVar(varName:String, value:Dynamic)` | Saves a value shared between scripts. |
| `getVar(varName:String)` | Reads a value saved with setVar. |
| `addLuaScript(luaFile:String, ?ignoreAlreadyRunning:Bool = false)` | Starts another Lua script. |
| `addHScript(scriptFile:String, ?ignoreAlreadyRunning:Bool = false)` | Starts another HScript. |
| `removeLuaScript(luaFile:String)` | Stops a Lua script. |
| `removeHScript(scriptFile:String)` | Stops an HScript. |
| `getModSetting(saveTag:String, ?modName:String = null)` | Reads a mod option (settings.json). |
| `debugPrint(text:Dynamic = '', color:String = 'WHITE')` | Prints a debug message on screen. |
| `close()` | Closes this script. |

## Song & gameplay

| Function | What it does |
|---|---|
| `loadSong(?name:String = null, ?difficulty:Dynamic = -1)` | Loads and starts another song. |
| `addCharacterToList(name:String, type:String)` | **DEPRECATED** - use `precacheCharacter`<br>Preloads a character. |
| `precacheImage(name:String, ?allowGPU:Bool = true)` | Preloads an image. |
| `precacheSound(name:String)` | Preloads a sound. |
| `precacheMusic(name:String)` | Preloads music. |
| `triggerEvent(name:String, ?value1:String = '', ?value2:String = '', ?value3:String, ?value4:String, ?value5:String, ?value6:String, ?value7:String, ?value8:String, ?value9:String, ?value10:String)` | Triggers a chart event (up to 10 values). |
| `autoPlay(?on:Bool)` | **NEW**<br>Turns autoplay on or off: the game hits the notes for the player like botplay, but it counts as real play (no BOTPLAY text, normal score, records are saved). The player's keys are ignored while it's on. Without an argument it only tells you if it's on. Returns true if autoplay is on. Every note is hit as Sick, so accuracy is 100% in those parts. Also in HScript. |
| `startCountdown()` | Starts the countdown (if it was blocked). |
| `endSong()` | Ends the song. |
| `switchStateWithStickers(stateName:String, ?mode:String, ?songName:String, ?difficulty:String)` | **DEPRECATED** - use `switchState(name, {transition = "stickers"})`<br>Switches state with the sticker transition. |
| `switchStateDirect(stateName:String)` | **DEPRECATED** - use `switchState(name, {transition = "none"})`<br>Switches state with no transition. |
| `switchState(stateName:String, ?options:{transition, mode, song, difficulty})` | **CHANGED**<br>Switches state. transition = "fade" (default), "none" or "stickers". Now replaces switchStateDirect and switchStateWithStickers. |
| `restartSong(?skipTransition:Bool = false)` | Restarts the song. |
| `exitSong(?skipTransition:Bool = false)` | Leaves the song and goes back to the menu. |
| `getSongPosition()` | Current song time (ms). |
| `startDialogue(?name = "dialogue", ?resume = true)` | **CHANGED**<br>Starts a dialogue of this song: data/songs/<song>/<name>.json (e.g. "dialogue-mid"). The HUD is hidden and pause is off until it ends. resume = true: when it ends, the countdown starts (or the song ends, if it was the end dialogue). Returns false if the file is missing. Changed in 1.3. dialogue.json and dialogue-end.json start by themselves (start and end of the song, only once, not in charting mode). The old Psych dialogue files no longer work. Made with the Dialogue Editor. |
| `nextDialogueScene()` | **NEW**<br>Skips to the next scene of the running dialogue (like pressing Enter). Returns false if no dialogue is running. New in 1.3. |
| `endDialogue(?fade = true, ?duration = 1)` | **NEW**<br>Ends the running dialogue. fade = true fades it out in duration seconds. Returns false if no dialogue is running. New in 1.3. |
| `isDialogueRunning()` | **NEW**<br>True while a dialogue is on screen. New in 1.3. |
| `onDialogueStart / onDialogueScene / onDialogueCustom / onDialogueEnd` | **NEW**<br>onDialogueStart(name) - return Function_Stop to cancel it. onDialogueScene(index, type, character) - every new scene. onDialogueCustom(name, index) - a "free" scene: call nextDialogueScene() when your effect is done. onDialogueEnd(name). New in 1.3. Objects: dialogue_<bg id>, dialogue_portrait_<character>, dialogue_black, dialogue_box, dialogue_text. |
| `startVideo(videoFile:String, ?canSkip:Bool = true, ?forMidSong:Bool = false, ?shouldLoop:Bool = false, ?playOnLoad:Bool = true)` | Plays a video. |
| `setReturnState(stateName:String)` | Sets where the game goes after the song. |
| `getReturnState()` | Reads where the game goes after the song. |
| `openCustomSubstate((= openCustomSubstate))` | Opens a custom substate. |
| `closeCustomSubstate((= closeCustomSubstate))` | Closes the custom substate. |
| `insertToCustomSubstate((= insertToCustomSubstate))` | Adds an object to the custom substate. |
| `precacheCharacter(name, ?type = "bf" \| "dad" \| "gf" \| 3..10 \| "character3")` | **NEW**<br>Preloads a character so changing it later doesn't stutter. Also works with extra characters (number or "character3"). |

## Score, health & HUD

| Function | What it does |
|---|---|
| `addScore(value:Int = 0)` | Adds score. |
| `addMisses(value:Int = 0)` | Adds misses. |
| `addHits(value:Int = 0)` | Adds hit notes. |
| `setScore(value:Int = 0)` | Sets the score. |
| `setMisses(value:Int = 0)` | Sets the misses. |
| `setHits(value:Int = 0)` | Sets the hit notes. |
| `setHealth(value:Float = 1)` | Sets health (0-2). |
| `addHealth(value:Float = 0)` | Adds health. |
| `getHealth()` | Reads health. |
| `setRatingPercent(value:Float)` | Sets the accuracy percent. |
| `setRatingName(value:String)` | Sets the rating name. |
| `setRatingFC(value:String)` | Sets the FC tag (SFC, GFC...). |
| `updateScoreText()` | Refreshes the score text. |
| `setHealthBarColors(left:String, right:String)` | Health bar colors. |
| `setHealthBarBG(?image, ?prefix, ?fps)` | **NEW**<br>Replaces the health bar frame (drawn on top) with an image from images/. It is scaled and centered on the normal health bar by itself. With an .xml next to it, it plays as an animation (prefix = animation prefix, fps = speed, default 24). Empty = back to the mod's frame or the normal one. Mods with the new folder structure can also put bg.png in content/images/healthbar/ to use it in every song. |
| `setHealthBarSprite(?image, ?prefix, ?fps)` | **NEW**<br>Replaces the colored part of the health bar with an image (any shape, white is best). It is tinted with the health bar colors, so setHealthBarColors still works. Scaled to the width of the normal bar and centered. Animated with an .xml like setHealthBarBG. Empty = back to the mod's bar or the normal one. JSON version: data/songs/<song>/healthbar.json (that song) or data/healthbar.json (whole mod) with bg, bar (paths inside images/), scale, offset, barScale ([x, y] or one number, only the colored bar), barOffset ([x, y], moves only the colored bar), iconScale, iconOffset, iconBop, bgAnimation, barAnimation. Old folder content/images/healthbar/ still works. |
| `resetHealthBar()` | **NEW**<br>Puts the health bar back to the last loaded style (song or mod healthbar.json, or the normal one). |
| `loadHealthBar(?path:String)` | **NEW**<br>Loads a health bar style from a JSON inside data/ (e.g. 'healthbars/sonic' = data/healthbars/sonic.json), same fields as healthbar.json. Returns false if the file is missing. Empty = back to the song/mod healthbar.json. |
| `setTimeBarColors(left:String, right:String)` | Time bar colors. |

## Characters

| Function | What it does |
|---|---|
| `setCharacterPos(character = "bf" \| "dad" \| "gf" \| 3..10 \| "character3", ?x, ?y, ?zIndex)` | **NEW**<br>Moves a character's group. x or y = nil keeps that coordinate. zIndex moves the character to another layer, like objects (0 = behind everything, the background too). Replaces setCharacterX and setCharacterY. Returns true if the character exists. |
| `getCharacterPos(character = "bf" \| "dad" \| "gf" \| 3..10 \| "character3")` | **NEW**<br>Position and layer of a character's group: returns {x, y, zIndex} (use pos.x, pos.y, pos.zIndex). nil if the character doesn't exist. Replaces getCharacterX and getCharacterY. |
| `setCamOffset(character = "bf" \| "dad" \| "gf" \| 3..10 \| "character3", ?x, ?y)` | **NEW**<br>Changes the camera offset of a character (the Camera X/Y set in the Character Editor). x or y = nil keeps that value. Useful when a stage needs the camera in another spot for that character. Works from the next camera move (next section or event). Returns true if the character exists. |
| `getCamOffset(character = "bf" \| "dad" \| "gf" \| 3..10 \| "character3")` | **NEW**<br>Camera offset of a character: returns {x, y} (use off.x, off.y). nil if the character doesn't exist. |
| `getCharacterX(type = "bf" \| "dad" \| "gf" \| 3..10 \| "character3")` | **DEPRECATED** - use `getCharacterPos`<br>X of a character's group. Also works with extra characters (number or "character3"). |
| `setCharacterX(type = "bf" \| "dad" \| "gf" \| 3..10 \| "character3", value)` | **DEPRECATED** - use `setCharacterPos`<br>Moves a character's group on X. Also works with extra characters (number or "character3"). |
| `getCharacterY(type = "bf" \| "dad" \| "gf" \| 3..10 \| "character3")` | **DEPRECATED** - use `getCharacterPos`<br>Y of a character's group. Also works with extra characters (number or "character3"). |
| `setCharacterY(type = "bf" \| "dad" \| "gf" \| 3..10 \| "character3", value)` | **DEPRECATED** - use `setCharacterPos`<br>Moves a character's group on Y. Also works with extra characters (number or "character3"). |
| `characterDance(character = "bf" \| "dad" \| "gf" \| 3..10 \| "character3")` | **CHANGED**<br>Makes a character dance (idle). Also works with extra characters (number or "character3"). |
| `setSingAlong(father, ?children, ?all = false)` | **NEW**<br>Makes characters sing together: the children copy every sing animation of the father, misses too. father and children: bf, dad, gf, 3..10 or "character3"; children as text "3, 4" or table {3, 4}. all = true: every character on the father's side. No children and all off = the father sings alone again. Same as the Character Sing-Along event. Returns false if the father isn't a valid name. |
| `getSingAlong(father)` | **NEW**<br>Table of who is singing along with the father ("bf", "dad", "gf", "3"...). Empty = nobody. |
| `getExtraCharacters()` | **NEW**<br>Table of the chart's extra characters. Each one has: slot (3..10), name ("character3", use it in getProperty, playAnim...), character (loaded character, empty = the side sings), parent (bf, dad or gf), strumline ("shared" or "separate"), playable (true = the player plays its notes), visible (has a visible strumline of its own). |

## Camera

| Function | What it does |
|---|---|
| `cameraSetTarget(target:String)` | **DEPRECATED** - use `focusCamera`<br>Moves the camera to dad, bf or gf (old system). |
| `setCameraScroll(x:Float, y:Float)` | Sets the camera scroll. |
| `setCameraFollowPoint(x:Float, y:Float)` | **DEPRECATED** - use `focusCamera("x, y", duration, ease)`<br>Sets the camera follow point. |
| `addCameraScroll(?x:Float = 0, ?y:Float = 0)` | Adds to the camera scroll. |
| `addCameraFollowPoint(?x:Float = 0, ?y:Float = 0)` | Nudges the camera follow point. |
| `getCameraScrollX()` | Camera center X (not the real scroll, despite the name). |
| `getCameraScrollY()` | Camera center Y (not the real scroll, despite the name). |
| `getCameraFollowX()` | X of the camera follow point. |
| `getCameraFollowY()` | Y of the camera follow point. |
| `cameraShake(camera:String, intensity:Float, duration:Float)` | Shakes a camera. |
| `cameraFlash(camera:String, color:String, duration:Float,forced:Bool)` | Flashes a camera with a color. |
| `cameraFade(camera:String, color:String, duration:Float, forced:Bool, ?fadeOut:Bool = false)` | Fades a camera to a color. |
| `setCameraRotation(camera:String, angle:Float)` | Rotates a camera. |
| `getCameraRotation(camera:String)` | Reads a camera's rotation. |
| `setCameraZoom(zoom:Float)` | Sets the camera zoom. |
| `getCameraZoom()` | Reads the camera zoom. |
| `setCameraScrollX(x:Float)` | **CHANGED**<br>Camera scroll X. Now also in game. |
| `setCameraScrollY(y:Float)` | **CHANGED**<br>Camera scroll Y. Now also in game. |
| `getCameraScrollRawX()` | **CHANGED**<br>Real camera scroll X. Now also in game. |
| `getCameraScrollRawY()` | **CHANGED**<br>Real camera scroll Y. Now also in game. |
| `focusCamera(position, ?duration, ?ease, ?forced = true)` | **NEW**<br>Moves the camera like the Cam Follow Pos event (dad, bf, gf, char number 3, 4..., "x, y", "bf, 50, 20", "3, 100, -50"). No ease = stage camera speed. Now accepts an extra character number, with offsets too. |
| `centerCamera(?duration, ?ease)` | **NEW**<br>Centers the camera between player and opponent, like the Center Camera event. |

## Sprites & objects

| Function | What it does |
|---|---|
| `getMidpointX(variable:String)` | Hitbox center X. |
| `getMidpointY(variable:String)` | Hitbox center Y. |
| `getGraphicMidpointX(variable:String)` | Graphic center X. |
| `getGraphicMidpointY(variable:String)` | Graphic center Y. |
| `getScreenPositionX(variable:String, ?camera:String = 'game')` | On-screen X. |
| `getScreenPositionY(variable:String, ?camera:String = 'game')` | On-screen Y. |
| `setScrollFactor(obj:String, scrollX:Float, scrollY:Float)` | Parallax of an object. |
| `addLuaSprite(tag:String, ?inFront:Bool = false)` | Adds a sprite to the scene. |
| `setGraphicSize(obj:String, x:Float, y:Float = 0, updateHitbox:Bool = true)` | Resizes a sprite in pixels. |
| `scaleObject(obj:String, x:Float, y:Float, updateHitbox:Bool = true)` | Scales a sprite. |
| `updateHitbox(obj:String)` | Updates the hitbox after scaling. |
| `getHoldCoverProperty(cover:Dynamic, variable:String)` | Reads a hold cover property. |
| `setHoldCoverProperty(cover:Dynamic, variable:String, value:Dynamic)` | Changes a hold cover property. |
| `updateHoldCoverHitbox(cover:Dynamic)` | Updates a hold cover hitbox. |
| `removeLuaSprite(tag:String, destroy:Bool = true, ?group:String = null)` | **CHANGED**<br>Removes a sprite from the scene. Now also removes backdrops and particles. |
| `setObjectCamera(obj:String, camera:String = 'game')` | Moves an object to another camera. |
| `setBlendMode(obj:String, blend:String = '')` | **CHANGED**<br>Blend mode of an object: add, alpha, color, colorburn, colordodge, darken, difference, erase, exclusion, hardlight, hue, invert, layer, lighten, luminosity, multiply, overlay, saturation, screen, shader, softlight, subtract. Empty = normal. color, colorburn, colordodge, exclusion, hue, luminosity, saturation and softlight are new (same as V-Slice). The same names work for the blend option of setGhostTrail and createParticles, and for objects in stage .json files. |
| `screenCenter(obj:String, pos:String = 'xy')` | Centers an object on screen. |
| `objectsOverlap(obj1:String, obj2:String)` | Checks if two objects overlap. |
| `getPixelColor(obj:String, x:Int, y:Int)` | Color of a sprite pixel. |
| `getObjectOrder(obj:String, ?group:String = null)` | Layer position of an object. |
| `setObjectOrder(obj:String, position:Int, ?group:String = null)` | Changes the layer position of an object. |
| `makeLuaSprite(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0)` | **DEPRECATED** - use `createSprite`<br>Creates a sprite. |
| `makeAnimatedLuaSprite(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = 'auto')` | **DEPRECATED** - use `createAnimatedSprite`<br>Creates an animated sprite. |
| `luaSpriteExists(tag:String)` | Checks if a sprite exists. |
| `makeGraphic(obj:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF')` | Fills a sprite with a color. |
| `loadGraphic(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0)` | Loads an image into a sprite. |
| `loadFrames(variable:String, image:String, spriteType:String = 'auto')` | Loads a spritesheet into a sprite. |
| `loadMultipleFrames(variable:String, images:Array<String>)` | Loads several spritesheets into a sprite. |
| `makeFlxAnimateSprite(tag:String, ?x:Float = 0, ?y:Float = 0, ?loadFolder:String = null)` | Creates an Adobe Animate sprite (texture atlas). |
| `loadAnimateAtlas(tag:String, folderOrImg:String, ?spriteJson:String = null, ?animationJson:String = null)` | Loads a texture atlas. |
| `addAnimationBySymbol(tag:String, name:String, symbol:String, ?framerate:Float = 24, ?loop:Bool = false, ?matX:Float = 0, ?matY:Float = 0)` | Animation from a texture atlas symbol. |
| `addAnimationBySymbolIndices(tag:String, name:String, symbol:String, ?indices:Any = null, ?framerate:Float = 24, ?loop:Bool = false, ?matX:Float = 0, ?matY:Float = 0)` | Animation from a symbol with indices. |
| `createSprite(tag, ?image, ?x, ?y, ?{alpha, scaleX, scaleY, camera, zIndex, front, scrollX, scrollY, skewX, skewY})` | **NEW**<br>Creates a sprite from an image and adds it to the scene. For animated sprites use createAnimatedSprite. If the tag is already a sprite (also one from the stage .json), that sprite is kept and the values given here replace the .json ones; x and y can be left out (nil) to keep its position. |
| `createAnimatedSprite(tag, ?image, ?x, ?y, ?{alpha, scaleX, scaleY, camera, zIndex, front, scrollX, scrollY, skewX, skewY, spriteType})` | **NEW**<br>Creates an animated sprite from a spritesheet (xml/json/txt next to the image) and adds it to the scene. More images separated by commas are joined in one sprite. Add the animations with addAnimationByPrefix and play them with playAnim. spriteType = "auto" (default), "sparrow", "packer" or "aseprite". If the tag is already a sprite (also one from the stage .json), that sprite is kept and the values given here replace the .json ones; x and y can be left out (nil) to keep its position. |
| `createGradient(tag, x, y, width, height, colors, ?{angle, chunkSize, interpolate, alpha, camera, zIndex, front, scrollX, scrollY, skewX, skewY})` | **NEW**<br>Creates a gradient sprite (two or more colors) and adds it to the scene. |
| `createBackdrop(tag, image, ?x, ?y, ?{axes = "xy" \| "x" \| "y", spacingX, spacingY, velocityX, velocityY, alpha, scaleX, scaleY, scrollX, scrollY, camera, zIndex, front})` | **NEW**<br>Creates an endlessly repeating image (scrolling backgrounds) and adds it to the scene. velocityX/velocityY make it scroll by itself. |
| `createParticles(tag, ?image, ?x, ?y, ?{amount, size, color, width, height, lifespan, speed, angle, spin, alpha, scale, gravity, gravityX, startColor, endColor, blend, frequency, quantity, explode, start, scrollX, scrollY, camera, zIndex, front})` | **NEW**<br>Creates a particle emitter and adds it to the scene. No image = squares of color and size. lifespan, speed, angle, spin = number or {min, max}; alpha and scale = {start, end}. Starts by itself (start = false to stop that). |
| `startParticles(tag, ?explode = false, ?frequency = 0.1, ?quantity = 0)` | **NEW**<br>Starts the particles. explode = true fires them all at once. |
| `stopParticles(tag, ?clear = false)` | **NEW**<br>Stops the particles. clear = true also removes the ones already flying. |
| `setSkew(obj, x, ?y)` | **NEW**<br>Skews a Lua sprite or a character (degrees). |

## Animations

| Function | What it does |
|---|---|
| `addAnimationByPrefix(obj:String, name:String, prefix:String, framerate:Float = 24, loop:Bool = true)` | Adds an animation from a prefix. |
| `addAnimation(obj:String, name:String, frames:Any, framerate:Float = 24, loop:Bool = true)` | Adds an animation from frames. |
| `addAnimationByIndices(obj:String, name:String, prefix:String, indices:Any, framerate:Float = 24, loop:Bool = false)` | Adds an animation from indices. |
| `playAnim(obj:String, name:String, ?forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0, ?looped:Bool)` | **CHANGED**<br>Plays an animation. Also works with extra characters ("character3"). New looped: true/false makes the animation loop or not (it stays that way for the next plays too); nil = as it was added. |
| `addOffset(obj:String, anim:String, x:Float, y:Float)` | Offset of an animation. |

## Effects

| Function | What it does |
|---|---|
| `setGhostTrail(character, type = "simple" \| "animated" \| "aura" \| "off", ?{doubleNote, color, alpha, duration, distance, grow, rate, blend})` | **NEW**<br>Ghost trail on a character (bf, dad, gf or char number 3, 4...). simple = still ghosts that fade, animated = ghosts slide where the note points (distance = how far, in px), aura = glow that's always on, idle too. doubleNote (simple/animated only) = ghosts only on 2+ notes. color: "hp" or "health" = health bar color, empty = normal colors (aura: health bar color). Same as the Ghost Trail event. |
| `setSilhouette(enabled, ?{characterColor, characterColors, backgroundColor, strength, characterAlpha, backgroundAlpha, duration, ease, hud, details})` | **NEW**<br>Turns characters into silhouettes with a solid background. characterColor = one color for everyone (empty = health colors), characterColors = one per character ({dad = "red", bf = "blue", ["3"] = "yellow"}), backgroundColor (empty = black), characterAlpha / backgroundAlpha, hud = also colors icons and health bar, details = keeps faces and lines visible (darker on light colors, lighter on dark ones). Same as the Silhouette event. |
| `backgroundFlash(?color = "FFFFFF", ?duration = 1, ?{characterColor, ease = "quadOut"})` | **NEW**<br>Color flash behind the characters that fades out. With characterColor the characters flash too. Same as the BG Flash event. |
| `setStrumTint(target, color, ?strength = 1)` | **NEW**<br>Tints the strum arrows with a color. target = "all" (or empty), "player", "opponent", "char3" (strumline of character 3, 4...) or a lane number (0-3 opponent, 4-7 player, 8+ extra strumlines). strength goes from 0 (no tint) to 1 (full color). Returns true if it worked. Stops a tweenStrumTint running on the same arrows. A note pack can give the arrows a starting tint (Note Editor > Shader > Strumline Shader): that is what resetStrumTint goes back to. Errors (no arrows, wrong color) only show with luaDebugMode = true. |
| `tweenStrumTint(tag, target, color, duration, ?ease = "linear", ?strength = 1)` | **NEW**<br>Fades the tint of the strum arrows to a color in duration seconds. Same targets as setStrumTint. Returns the tag. Calls onTweenCompleted(tag) at the end. cancelTween, pauseTween and resumeTween work with the tag. A new tween or setStrumTint on the same arrows takes over. |
| `resetStrumTint(target, ?duration = 0, ?ease = "linear")` | **NEW**<br>Puts the tint of the strum arrows back to the one of the note pack (no tint if the pack has none). With a duration it fades back. Same targets as setStrumTint. |

## Tweens & timers

| Function | What it does |
|---|---|
| `doTweenZoom(tag:String, camera:String, value:Dynamic, duration:Float, ?ease:String = 'linear')` | Tweens a camera's zoom. |
| `noteTweenX(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear')` | Tweens a strum's X. |
| `noteTweenY(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear')` | Tweens a strum's Y. |
| `noteTweenAngle(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear')` | Tweens a strum's angle. |
| `noteTweenAlpha(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear')` | Tweens a strum's alpha. |
| `noteTweenDirection(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear')` | Tweens a strum's scroll direction. |
| `doTweenX(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear')` | Tweens X. |
| `doTweenY(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear')` | Tweens Y. |
| `doTweenAngle(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear')` | Tweens the angle. |
| `doTweenAlpha(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear')` | Tweens the alpha. |
| `doTweenCameraRotation(tag:String, camera:String, angle:Float, duration:Float, ?ease:String = 'linear')` | Tweens a camera's rotation. |
| `doTweenColor(tag:String, vars:String, targetColor:String, duration:Float, ?ease:String = 'linear')` | Tweens the color. |
| `startTween(tag:String, vars:String, values:Any = null, duration:Float, ?{ease, type, startDelay, loopDelay, onStart, onUpdate, onComplete})` | **CHANGED**<br>Tweens several properties at once. cancelTween, pauseTween and resumeTween now find it. |
| `cancelTween(tag:String)` | Stops a tween. |
| `runTimer(tag:String, time:Float = 1, loops:Int = 1)` | Starts a timer. |
| `cancelTimer(tag:String)` | Stops a timer. |
| `noteTween(tag, note, values, duration, ?{ease, type, startDelay, loopDelay, onStart, onUpdate, onComplete})` | **NEW**<br>Tweens several strum properties at once (options like startTween). note: 0-3 opponent, 4-7 player, 8+ extra strumlines (8-11 the first, 12-15 the second...). |
| `tweenNumber(tag, from, to, duration, ?{ease, type, startDelay, loopDelay, onStart, onUpdate, onComplete})` | **NEW**<br>Tweens a number: onUpdate gets (tag, value). |
| `pauseTween(tag)` | **NEW**<br>Pauses a tween. |
| `resumeTween(tag)` | **NEW**<br>Resumes a paused tween. |
| `pauseTimer(tag)` | **NEW**<br>Pauses a timer. |
| `resumeTimer(tag)` | **NEW**<br>Resumes a paused timer. |

## Text

| Function | What it does |
|---|---|
| `luaTextExists(tag:String)` | Checks if a text exists. |
| `makeLuaText(tag:String, ?text:String = '', ?width:Int = 0, ?x:Float = 0, ?y:Float = 0)` | **DEPRECATED** - use `createText`<br>Creates a text. |
| `setTextString(tag:String, text:String)` | Changes the text. |
| `setTextSize(tag:String, size:Int)` | Text size. |
| `setTextWidth(tag:String, width:Float)` | Text width. |
| `setTextHeight(tag:String, height:Float)` | Text height. |
| `setTextAutoSize(tag:String, value:Bool)` | Text auto size. |
| `setTextBorder(tag:String, size:Float, color:String, ?style:String = 'outline')` | Text border. |
| `setTextColor(tag:String, color:String)` | Text color. |
| `setTextFont(tag:String, newFont:String)` | Text font. |
| `setTextItalic(tag:String, italic:Bool)` | Italic. |
| `setTextAlignment(tag:String, alignment:String = 'left')` | Text alignment. |
| `getTextString(tag:String)` | Reads the text. |
| `getTextSize(tag:String)` | Reads the size. |
| `getTextFont(tag:String)` | Reads the font. |
| `getTextWidth(tag:String)` | Reads the width. |
| `addLuaText(tag:String)` | Adds a text to the scene. |
| `removeLuaText(tag:String, destroy:Bool = true)` | Removes a text from the scene. |
| `createText(tag, ?text, ?x, ?y, ?{font, size, width, height, autoSize, color, alpha, camera, zIndex, front, scrollX, scrollY})` | **NEW**<br>Creates a text and adds it to the scene (in front, on the HUD). |
| `applyTextMarkup(tag, text, rules: {{marker, color, bold, italic, borderColor}, ...})` | **NEW**<br>Colors or bolds the parts of a text between markers. |
| `typeText(tag, text, ?{speed = 30, sound, volume, append})` | **NEW**<br>Types a text letter by letter (speed = letters per second). append = adds at the end. Calls onTypeTextCompleted(tag) when done. |
| `skipTypeText(tag)` | **NEW**<br>Finishes typing right away (still calls onTypeTextCompleted). |
| `isTyping(tag)` | **NEW**<br>Checks if the text is still typing. |

## Sounds, music & subtitles

| Function | What it does |
|---|---|
| `luaSoundExists(tag:String)` | Checks if a sound exists. |
| `playMusic(sound:String, ?volume:Float = 1, ?loop:Bool = false)` | Plays music. |
| `playSound(sound:String, ?volume:Float = 1, ?tag:String = null, ?loop:Bool = false)` | Plays a sound. |
| `playSubtitles(file:String, ?soundTag:String = null, ?margin:Null<Float> = null)` | Starts subtitles. |
| `preloadSubtitles(file:String)` | Preloads subtitles. |
| `stopSubtitles()` | Stops subtitles. |
| `stopSound(tag:String)` | Stops a sound. |
| `pauseSound(tag:String)` | Pauses a sound. |
| `resumeSound(tag:String)` | Resumes a sound. |
| `soundFadeIn(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1)` | Fades a sound in. |
| `soundFadeOut(tag:String, duration:Float, toValue:Float = 0)` | Fades a sound out. |
| `soundFadeCancel(tag:String)` | Stops a fade. |
| `getSoundVolume(tag:String)` | Reads the volume. |
| `setSoundVolume(tag:String, value:Float)` | Sets the volume. |
| `getSoundTime(tag:String)` | Reads a sound's time. |
| `setSoundTime(tag:String, value:Float)` | Moves a sound's time. |
| `getSoundPitch(tag:String)` | Reads the pitch. |
| `setSoundPitch(tag:String, value:Float, ?doPause:Bool = false)` | Changes the pitch. |
| `isMusicPlaying()` | Checks if music is playing. |

## Input

| Function | What it does |
|---|---|
| `mouseClicked(?button:String = 'left')` | Mouse button just clicked. |
| `mousePressed(?button:String = 'left')` | Mouse button held. |
| `mouseReleased(?button:String = 'left')` | Mouse button just released. |
| `getMouseX(?camera:String = 'game')` | Mouse X. |
| `getMouseY(?camera:String = 'game')` | Mouse Y. |
| `keyboardJustPressed(name:String)` | PHYSICAL key just pressed (e.g. "SPACE"). |
| `keyboardPressed(name:String)` | Physical key held. |
| `keyboardReleased(name:String)` | Physical key just released. |
| `anyGamepadJustPressed(name:String)` | Button just pressed on any gamepad. |
| `anyGamepadPressed(name:String)` | **CHANGED**<br>Button held on any gamepad. Fixed: it returned nothing before. |
| `anyGamepadReleased(name:String)` | Button released on any gamepad. |
| `gamepadAnalogX(id:Int, ?leftStick:Bool = true)` | Gamepad stick X. |
| `gamepadAnalogY(id:Int, ?leftStick:Bool = true)` | Gamepad stick Y. |
| `gamepadJustPressed(id:Int, name:String)` | Button just pressed on one gamepad. |
| `gamepadPressed(id:Int, name:String)` | Button held on one gamepad. |
| `gamepadReleased(id:Int, name:String)` | Button released on one gamepad. |
| `keyJustPressed(name:String = '')` | GAME control just pressed (left, accept...), follows the player's keybinds. |
| `keyPressed(name:String = '')` | Game control held. |
| `keyReleased(name:String = '')` | Game control just released. |
| `setMouseVisible(visible:Bool)` | Shows/hides the mouse. |
| `getMouseVisible()` | Checks if the mouse is visible. |
| `getKeybind(name, ?gamepad = false)` | **NEW**<br>Keys the player picked for a control (e.g. "note_left"). |

## Colors & utilities

| Function | What it does |
|---|---|
| `FlxColor(color:String)` | **DEPRECATED** - use `getColorFromString`<br>Color from a name or #hex. |
| `getColorFromName(color:String)` | **DEPRECATED** - use `getColorFromString`<br>Color from a name or #hex. |
| `getColorFromString(color:String)` | **CHANGED**<br>Color from a name or hex (# optional, 8 digits = with alpha). Now accepts hex without # and 8-digit colors with alpha. |
| `getColorFromHex(color:String)` | **DEPRECATED** - use `getColorFromString`<br>Color from hex without #. |
| `stringStartsWith(str:String, start:String)` | Text starts with... |
| `stringEndsWith(str:String, end:String)` | Text ends with... |
| `stringSplit(str:String, split:String)` | Splits a text. |
| `stringTrim(str:String)` | Removes spaces on both sides. |
| `getRandomInt(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '')` | Random integer. |
| `getRandomFloat(min:Float, max:Float = 1, exclude:String = '')` | Random decimal. |
| `getRandomBool(chance:Float = 50)` | Random true/false with a percent chance. |
| `lerp(a:Float, b:Float, t:Float)` | Interpolates between two values. |
| `rgbToHex(red, green, blue)` | **NEW**<br>Three 0-255 numbers to "RRGGBB". |
| `hexToRgb(hex)` | **NEW**<br>"RRGGBB" to {r, g, b}. |
| `getColorChannels(color)` | **NEW**<br>Channels {r, g, b, a} of a color (number or string). |
| `setColorTransform(obj, {redMultiplier, greenMultiplier, blueMultiplier, alphaMultiplier, redOffset, greenOffset, blueOffset, alphaOffset})` | **NEW**<br>Changes a sprite's color transform (silhouettes, tints). |
| `getHealthColor(character = "bf" \| "dad" \| "gf" \| 3..10 \| "character3")` | **NEW**<br>Health bar color of a character as "RRGGBB". Also works with extra characters (number or "character3"). |
| `parseJSON(text)` | **NEW**<br>JSON text to a Lua table. |
| `stringifyJSON(value, ?pretty)` | **NEW**<br>Lua table to JSON text. |
| `getFps()` | **NEW**<br>Current FPS. |
| `getMemory()` | **NEW**<br>Memory used by the game in MB. |
| `openURL(url)` | **NEW**<br>Opens a link in the browser. Only http:// and https://. |

## Files & saves

| Function | What it does |
|---|---|
| `getTextFromFile(path:String, ?ignoreModFolders:Bool = false)` | Reads a text file. |
| `saveFile(path:String, content:String, ?absolute:Bool = false)` | Writes a file. |
| `deleteFile(path:String, ?ignoreModFolders:Bool = false, ?absolute:Bool = false)` | Deletes a file. |
| `checkFileExists(filename:String, ?absolute:Bool = false)` | Checks if a file exists. |
| `directoryFileList(folder:String)` | Lists the files in a folder. |
| `initSaveData(name:String, ?folder:String = 'psychenginemods')` | Opens a mod save. |
| `eraseSaveData(name:String)` | Erases a mod save. |
| `flushSaveData(name:String)` | Writes a mod save to disk. |
| `getDataFromSave(name:String, field:String, ?defaultValue:Dynamic = null)` | Reads a value from a mod save. |
| `setDataFromSave(name:String, field:String, value:Dynamic)` | Writes a value to a mod save. |
| `getSave(key:String)` | **DEPRECATED** - use `initSaveData + getDataFromSave`<br>Reads a value from the GAME save. Mods should not touch the game save: it can break the player's settings. |
| `setSave(key:String, value:Dynamic)` | **DEPRECATED** - use `initSaveData + setDataFromSave`<br>Writes to the GAME save. Mods should not touch the game save: it can break the player's settings. |
| `flushSave()` | **DEPRECATED** - use `flushSaveData`<br>Writes the game save to disk. Mods should not touch the game save: it can break the player's settings. |
| `appendFile(path, content, ?absolute)` | **NEW**<br>Adds text at the end of a file. |
| `isDirectory(path, ?absolute)` | **NEW**<br>Checks if a path is a folder. |
| `createDirectory(path, ?absolute)` | **NEW**<br>Creates a folder. |

## Window

| Function | What it does |
|---|---|
| `setWindowPosition(x, y)` | **NEW**<br>Moves the game window. |
| `getWindowPosition()` | **NEW**<br>Window position {x, y}. |
| `setWindowSize(width, height)` | **NEW**<br>Resizes the window. |
| `getWindowSize()` | **NEW**<br>Window size {width, height}. |
| `centerWindow()` | **NEW**<br>Centers the window on screen. |
| `doTweenWindow(tag, {x, y, width, height}, duration, ?{ease, type, startDelay, loopDelay, onStart, onUpdate, onComplete})` | **NEW**<br>Tweens window position and size. |
| `setWindowTitle(title)` | **NEW**<br>Changes the window title. |
| `getWindowTitle()` | **NEW**<br>Window title. |
| `setWindowIcon(image)` | **NEW**<br>Changes the window icon. |
| `focusWindow()` | **NEW**<br>Brings the window to the front. |
| `windowAlert(title, message)` | **NEW**<br>Shows an alert box (the game waits until you close it). |
| `setWindowAlpha(alpha)` | **NEW**<br>Window transparency (Windows only). |
| `getWindowAlpha()` | **NEW**<br>Window transparency (Windows only). |
| `setWindowDarkMode(enable)` | **NEW**<br>Dark title bar (Windows only). |
| `setWindowBorderColor(?color)` | **NEW**<br>Window border color, empty = normal (Windows 11 only). |
| `setWindowCorners(?mode = "default" \| "none" \| "round" \| "small")` | **NEW**<br>Window corners (Windows 11 only). |

## Lua standard library

| Function | What it does |
|---|---|
| `string.split(s, ?sep = ",")` | **NEW**<br>Splits a text into a table. Available in every script, also as s:split(...). |
| `string.trim / ltrim / rtrim(s)` | **NEW**<br>Removes spaces on the sides. Available in every script. |
| `string.startswith / endswith(s, text)` | **NEW**<br>Text starts / ends with... Available in every script. |
| `string.contains(s, text)` | **NEW**<br>Checks if a text contains a part. Available in every script. |
| `string.replace(s, from, to)` | **NEW**<br>Replaces every match (plain text, not a pattern). Available in every script. |
| `table.contains / indexof(t, value)` | **NEW**<br>Finds a value in a table. Available in every script. |
| `table.filter / map(t, fn)` | **NEW**<br>Filters or maps a table. Available in every script. |
| `table.clone / reverse / keys(t)` | **NEW**<br>Copies, reverses or lists the keys of a table. Available in every script. |
| `math.lerp(a, b, t)` | **NEW**<br>Interpolation. Available in every script. |
| `math.clamp(v, min, max)` | **NEW**<br>Clamps a value. Available in every script. |
| `math.round(v, ?decimals)` | **NEW**<br>Rounds with decimals. Available in every script. |
| `math.sign / isnan(v)` | **NEW**<br>Sign of a number / checks NaN. Available in every script. |
| `math.distance(x1, y1, x2, y2)` | **NEW**<br>Distance between two points. Available in every script. |

## Shaders

| Function | What it does |
|---|---|
| `initLuaShader(name:String)` | Loads a shader from the shaders folder. |
| `setSpriteShader(obj:String, shader:String)` | Puts a shader on a sprite. |
| `removeSpriteShader(obj:String)` | Removes a sprite's shader. |
| `getShaderBool(obj:String, prop:String)` | **CHANGED**<br>Reads a Bool from a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `getShaderBoolArray(obj:String, prop:String)` | **CHANGED**<br>Reads a Bool array from a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `getShaderInt(obj:String, prop:String)` | **CHANGED**<br>Reads an Int from a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `getShaderIntArray(obj:String, prop:String)` | **CHANGED**<br>Reads an Int array from a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `getShaderFloat(obj:String, prop:String)` | **CHANGED**<br>Reads a Float from a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `getShaderFloatArray(obj:String, prop:String)` | **CHANGED**<br>Reads a Float array from a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `setShaderBool(obj:String, prop:String, value:Bool)` | **CHANGED**<br>Sets a Bool in a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `setShaderBoolArray(obj:String, prop:String, values:Dynamic)` | **CHANGED**<br>Sets a Bool array in a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `setShaderInt(obj:String, prop:String, value:Int)` | **CHANGED**<br>Sets an Int in a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `setShaderIntArray(obj:String, prop:String, values:Dynamic)` | **CHANGED**<br>Sets an Int array in a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `setShaderFloat(obj:String, prop:String, value:Float)` | **CHANGED**<br>Sets a Float in a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `setShaderFloatArray(obj:String, prop:String, values:Dynamic)` | **CHANGED**<br>Sets a Float array in a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `setShaderSampler2D(obj:String, prop:String, bitmapdataPath:String)` | **CHANGED**<br>Passes an image to a shader. Cameras: use "camGame:name" to pick one shader, "camGame" alone = the first one. |
| `setCameraShader(camera:String, shader:String)` | Puts a shader on a camera (removes the others). |
| `removeCameraShader(camera, ?name)` | **CHANGED**<br>Removes a camera's shaders. With a name it removes only that shader. |
| `setCameraShaderFloat(camera:String, prop:String, value:Float)` | **DEPRECATED** - use `setShaderFloat with the camera name`<br>Sets a Float in a camera shader. |
| `getCameraShaderFloat(camera:String, prop:String)` | **DEPRECATED** - use `getShaderFloat with the camera name`<br>Reads a Float from a camera shader. |
| `setCameraShaderInt(camera:String, prop:String, value:Int)` | **DEPRECATED** - use `setShaderInt with the camera name`<br>Sets an Int in a camera shader. |
| `getCameraShaderInt(camera:String, prop:String)` | **DEPRECATED** - use `getShaderInt with the camera name`<br>Reads an Int from a camera shader. |
| `setCameraShaderBool(camera:String, prop:String, value:Bool)` | **DEPRECATED** - use `setShaderBool with the camera name`<br>Sets a Bool in a camera shader. |
| `getCameraShaderBool(camera:String, prop:String)` | **DEPRECATED** - use `getShaderBool with the camera name`<br>Reads a Bool from a camera shader. |
| `setCameraShaderFloatArray(camera:String, prop:String, values:Dynamic)` | **DEPRECATED** - use `setShaderFloatArray with the camera name`<br>Sets a Float array in a camera shader. |
| `setCameraShaderSampler2D(camera:String, prop:String, bitmapdataPath:String)` | **DEPRECATED** - use `setShaderSampler2D with the camera name`<br>Passes an image to a camera shader. |
| `addCameraShader(camera, shader, ?name)` | **NEW**<br>Adds a shader to a camera without removing the others (applied in order). name = name to find it later (empty = file name). Returns the name. |
| `getCameraShaders(camera)` | **NEW**<br>Names of the active shaders on a camera, in order. |
| `tweenShaderFloat(tag, obj, uniform, value, duration, ?{ease, type, startDelay, loopDelay, onStart, onUpdate, onComplete})` | **NEW**<br>Tweens a float of a shader (sprite, character or "camGame:name"). Stop it with cancelTween(tag), pause it with pauseTween. obj can also be "stage:name" for a shader added in the Stage Editor. |
| `tweenShader(tag, obj, values, duration, ?{ease, type, startDelay, loopDelay, onStart, onUpdate, onComplete})` | **NEW**<br>Tweens several shader values at once, of any type: values = {uniform = value, ...}. float and int take a number (int is rounded), vec2/vec3/vec4 take a list ({0.5, 1}) or one number for every part, vec3/vec4 also take a color ("FF3344", turned into 0-1 values). bool values change at the end of the tween. obj = an object or character with a shader, "camGame:name" for a camera shader, or "stage:name" for a shader added in the Stage Editor. options like startTween (ease, type, startDelay, loopDelay, onStart, onUpdate, onComplete). Returns the tag. The uniform type is read from the shader by itself. onStart, onUpdate and onComplete receive (tag, obj). cancelTween, pauseTween and resumeTween work with the tag. Wrong names or values are skipped with an error (luaDebugMode = true). |

## Properties & classes

| Function | What it does |
|---|---|
| `getProperty(variable:String, ?allowMaps:Bool = false)` | **CHANGED**<br>Reads a property (e.g. "boyfriend.x", "character3.alpha"). Extra characters: "character3" = the character, "character3Group" = its group (position), "character3Strums" = its own strums. |
| `setProperty(variable:String, value:Dynamic, ?allowMaps:Bool = false, ?allowInstances:Bool = false)` | **CHANGED**<br>Changes a property. Extra characters: "character3", "character3Group", "character3Strums". |
| `getPropertyFromClass(classVar:String, variable:String, ?allowMaps:Bool = false)` | Reads a static property of a class. |
| `setPropertyFromClass(classVar:String, variable:String, value:Dynamic, ?allowMaps:Bool = false, ?allowInstances:Bool = false)` | Changes a static property of a class. |
| `getPropertyFromGroup(group:String, index:Int, variable:Dynamic, ?allowMaps:Bool = false)` | **CHANGED**<br>Reads a property of a group member. Now also finds "character3Strums" and groups saved by scripts. |
| `setPropertyFromGroup(group:String, index:Int, variable:Dynamic, value:Dynamic, ?allowMaps:Bool = false, ?allowInstances:Bool = false)` | **CHANGED**<br>Changes a property of a group member. Now also finds "character3Strums" and groups saved by scripts. |
| `addToGroup(group:String, tag:String, ?index:Int = -1)` | Adds an object to a group. |
| `removeFromGroup(group:String, ?index:Int = -1, ?tag:String = null, ?destroy:Bool = true)` | Removes an object from a group. |
| `callMethod(funcToRun:String, ?args:Array<Dynamic>)` | **CHANGED**<br>Calls a method of an object. Also works with extra characters (e.g. "character3.getAnimationName"). |
| `callMethodFromClass(className:String, funcToRun:String, ?args:Array<Dynamic>)` | Calls a static method of a class. |
| `createInstance(variableToSave:String, className:String, ?args:Array<Dynamic>)` | Creates an object of a Haxe class. |
| `addInstance(objectName:String, ?inFront:Bool = false)` | Adds an object made with createInstance to the scene. |
| `instanceArg(instanceName:String, ?className:String = null)` | Passes an object as an argument to callMethod. |

## Haxe from Lua

| Function | What it does |
|---|---|
| `runHaxeCode(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null)` | Runs Haxe code written in a string. |
| `runHaxeFunction(funcToRun:String, ?funcArgs:Array<Dynamic> = null)` | Calls a function defined with runHaxeCode. |
| `addHaxeLibrary(libName:String, ?libPackage:String = '')` | Imports a class for runHaxeCode. |

## Modchart

| Function | What it does |
|---|---|
| `startMod(name:String, modClass:String, type:String = '', pf:Int = -1)` | **CHANGED**<br>Creates a modchart modifier. type = "all", "player", "opponent", "lane" (pick the lane with setModTargetLane) or "character" (pick the character number with setModTargetLane). "character" affects the 4 lanes of a character with its own strumline (Char 3, 4...). "player" and "opponent" only affect the main strumlines. |
| `setMod(name:String, value:Float)` | Sets a modifier. |
| `setSubMod(name:String, subValName:String, value:Float)` | Sets a modifier sub-value. |
| `setModTargetLane(name:String, value:Int)` | **CHANGED**<br>Lane of a "lane" modifier, or character number of a "character" modifier. Lanes 8 and up are the extra strumlines (4 lanes each, in character order). |
| `setModPlayfield(name:String, value:Int)` | Limits a modifier to one playfield. |
| `addPlayfield(?x:Float = 0, ?y:Float = 0, ?z:Float = 0)` | Adds a playfield. |
| `removePlayfield(idx:Int)` | Removes a playfield. |
| `tweenModifier(modifier:String, val:Float, time:Float, ease:String)` | Tweens a modifier. |
| `tweenModifierSubValue(modifier:String, subValue:String, val:Float, time:Float, ease:String)` | Tweens a sub-value. |
| `setModEaseFunc(name:String, ease:String)` | Ease of a modifier. |
| `set(beat:Float, argsAsString:String)` | Modchart: sets values at a beat. |
| `ease(beat:Float, time:Float, easeStr:String, argsAsString:String)` | Modchart: tweens values at a beat. |

## Language, achievements & Discord

| Function | What it does |
|---|---|
| `changeDiscordPresence((= changePresence))` | Changes the Discord status. |
| `changeDiscordClientID(?newID:String)` | Changes the Discord app. |
| `getTranslationPhrase(key:String, ?defaultPhrase:String, ?values:Array<Dynamic> = null)` | Translated phrase. |
| `getFileTranslation(key:String)` | Translated file path. |
| `setTranslationPhrase(key:String, value:String)` | Sets a translation. |
| `setFileTranslation(key:String, value:String)` | Sets a translated file. |
| `getAchievementScore(name:String)` | Progress of an achievement. |
| `setAchievementScore(name:String, ?value:Float = 0, ?saveIfNotUnlocked:Bool = true)` | Sets achievement progress. |
| `addAchievementScore(name:String, ?value:Float = 1, ?saveIfNotUnlocked:Bool = true)` | Adds achievement progress. |
| `unlockAchievement(name:String)` | Unlocks an achievement. |
| `isAchievementUnlocked(name:String)` | Checks if an achievement is unlocked. |
| `achievementExists(name:String)` | Checks if an achievement exists. |

## Old deprecated names

| Function | What it does |
|---|---|
| `addAnimationByIndicesLoop(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24)` | **DEPRECATED** - use `addAnimationByIndices`<br>Old name, still works with a warning. |
| `objectPlayAnimation(obj:String, name:String, forced:Bool = false, ?startFrame:Int = 0)` | **DEPRECATED** - use `playAnim`<br>Old name, still works with a warning. |
| `characterPlayAnim(character:String, anim:String, ?forced:Bool = false)` | **DEPRECATED** - use `playAnim`<br>Old name, still works with a warning. |
| `luaSpriteMakeGraphic(tag:String, width:Int, height:Int, color:String)` | **DEPRECATED** - use `makeGraphic`<br>Old name, still works with a warning. |
| `luaSpriteAddAnimationByPrefix(tag:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true)` | **DEPRECATED** - use `addAnimationByPrefix`<br>Old name, still works with a warning. |
| `luaSpriteAddAnimationByIndices(tag:String, name:String, prefix:String, indices:String, framerate:Int = 24)` | **DEPRECATED** - use `addAnimationByIndices`<br>Old name, still works with a warning. |
| `luaSpritePlayAnimation(tag:String, name:String, forced:Bool = false)` | **DEPRECATED** - use `playAnim`<br>Old name, still works with a warning. |
| `setLuaSpriteCamera(tag:String, camera:String = '')` | **DEPRECATED** - use `setObjectCamera`<br>Old name, still works with a warning. |
| `setLuaSpriteScrollFactor(tag:String, scrollX:Float, scrollY:Float)` | **DEPRECATED** - use `setScrollFactor`<br>Old name, still works with a warning. |
| `scaleLuaSprite(tag:String, x:Float, y:Float)` | **DEPRECATED** - use `scaleObject`<br>Old name, still works with a warning. |
| `getPropertyLuaSprite(tag:String, variable:String)` | **DEPRECATED** - use `getProperty`<br>Old name, still works with a warning. |
| `setPropertyLuaSprite(tag:String, variable:String, value:Dynamic)` | **DEPRECATED** - use `setProperty`<br>Old name, still works with a warning. |
| `musicFadeIn(duration:Float, fromValue:Float = 0, toValue:Float = 1)` | **DEPRECATED** - use `soundFadeIn`<br>Old name, still works with a warning. |
| `musicFadeOut(duration:Float, toValue:Float = 0)` | **DEPRECATED** - use `soundFadeOut`<br>Old name, still works with a warning. |
| `updateHitboxFromGroup(group:String, index:Int)` | **DEPRECATED** - use `updateHitbox`<br>Old name, still works with a warning. |

## State scripts only

| Function | What it does |
|---|---|
| `getSongsFromWeek(weekName:String)` | **STATE**<br>Songs of a week. |
| `getDifficulties()` | **STATE**<br>Available difficulties. |
| `songExists(songName:String, ?difficulty:Dynamic = null, ?folder:String = null)` | **STATE**<br>Checks if a song exists. |
| `getSongDifficulties(songName:String, ?folder:String = null)` | **STATE**<br>Difficulties of a song. |
| `getCurrentSong()` | **STATE**<br>Current song. |
| `getHighscore(songName:String, ?difficulty:Dynamic = 'normal')` | **STATE**<br>High score of a song. |
| `getHighscoreRating(songName:String, ?difficulty:Dynamic = 'normal')` | **STATE**<br>High score accuracy. |
| `getHighscoreMisses(songName:String, ?difficulty:Dynamic = 'normal')` | **STATE**<br>High score misses. |
| `resetState()` | **STATE**<br>Reloads the state. |
| `openSubState(substate:Dynamic)` | **STATE**<br>Opens a substate. |
| `closeSubState()` | **STATE**<br>Closes the substate. |
| `flxRandomInt(min:Int, max:Int, ?exclude:Any = null)` | **STATE** · **DEPRECATED** - use `getRandomInt`<br>Random integer. |
| `flxRandomFloat(min:Float, max:Float, ?exclude:Any = null)` | **STATE** · **DEPRECATED** - use `getRandomFloat`<br>Random decimal. |
| `flxRandomBool(?chance:Float = 50)` | **STATE** · **DEPRECATED** - use `getRandomBool`<br>Random true/false. |
| `getLoaded()` | **STATE**<br>Loaded items (loading screen). |
| `getLoadMax()` | **STATE**<br>Total items to load. |
| `addBehindBar(tag:String)` | **STATE**<br>Puts an object behind the loading bar. |
| `flxLerp(a:Float, b:Float, t:Float)` | **STATE** · **DEPRECATED** - use `lerp`<br>Interpolation. |
| `getScore(songName:String, diffIndex:Int)` | **STATE** · **DEPRECATED** - use `getHighscore`<br>High score of a song (difficulty index). |
| `getDifficultyName(index:Int)` | **STATE**<br>Name of a difficulty. |
| `getBuildTarget()` | **STATE**<br>System the game runs on (same as the buildTarget variable). |
