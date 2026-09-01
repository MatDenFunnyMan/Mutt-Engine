Put your custom Lua state scripts here!

IMPORTANT NOTES:
- File name must match the state name (e.g., MainMenuState.lua for Main Menu)
- You can organize scripts in subfolders! (e.g., MyFolder/MainMenuState.lua)

HOW TO USE:
1. Create a new .lua file with your state name (e.g., "MainMenuState.lua")
2. Add your onCreate() function to initialize sprites and objects
3. Add your onUpdate(elapsed) function for logic and controls
4. Use switchState('StateName') to navigate between states

EXAMPLE STRUCTURE:

function onCreate()
    makeLuaSprite('mySprite', 'myImage', 0, 0)
    addLuaSprite('mySprite', false)
end

function onUpdate(elapsed)
    if keyboardJustPressed('ENTER') then
        switchState('FreeplayState')
    end
end

SWITCHING STATES:
- Use switchState('StateName') to navigate between states
- Available states: TitleState, MainMenuState, StoryMenuState, FreeplayState, OptionsState, etc.

RETURN STATE AFTER SONG:
- Use setReturnState('StateName') inside a song script to control where the game goes after the song ends
- By default the game returns to FreeplayState, but you can override it!
- Call getReturnState() to check what state is currently set

Example (put this in your song's script):

function onCreate()
    setReturnState('MainMenuState')
end

Available states: TitleState, MainMenuState, StoryMenuState, FreeplayState, OptionsState, etc.
You can also use custom states: setReturnState('MySigmaState')
NOTE: This only works in song scripts (inside PlayState), not in state scripts.
      Place your script in one of these locations:
      - scripts/myScript.lua        (global, runs on every song)
      - data/mySong/myScript.lua    (specific song only)

CUSTOM STATES:
You can create completely new states that don't replace existing ones!

Examples:
- TitleState.lua          (replaces the original Title State)
- SigmaState.lua          (creates a brand new state called "SigmaState")
- CreditsState.lua        (replaces the original Credits State)
- MyFolder/MyState.lua    (organized in a subfolder, works the same!)

Access custom states with: switchState('YourStateName')

INITIAL STATE (Advanced):
If you want your state to load first instead of TitleState, add this to your script:

function isInitialState()
    return true
end

CONTROLS:
- keyboardJustPressed('KEY')   -- keyboard key just pressed (UP, DOWN, ENTER, ESCAPE...)
- keyJustPressed('ACTION')     -- game action just pressed (accept, back, ui_up, ui_down...)
- keyboardPressed('KEY')       -- held down
- keyboardReleased('KEY')      -- just released

SPRITES:
- makeLuaSprite('tag', 'imagePath', x, y)
- makeAnimatedLuaSprite('tag', 'atlasPath', x, y)
- addLuaSprite('tag', false)         -- false = behind HUD, true = in front
- removeLuaSprite('tag')
- setProperty('tag.x', value)
- getProperty('tag.width')

ANIMATIONS:
- addAnimationByPrefix('tag', 'animName', 'prefix', fps, looped)
- playAnim('tag', 'animName', true)

CAMERA:
- setCameraZoom(1.0)
- setCameraScrollX(x)
- setCameraScrollY(y)
- lerp(a, b, t)                -- useful for smooth camera movement

SOUND:
- playSound('soundName')
- playMusic('musicName')
- stopSound('tag')

TIPS:
- Use getPropertyFromClass('backend.ClientPrefs', 'data.antialiasing') for antialiasing
- screenWidth and screenHeight are available as global variables
- Use lerp(current, target, 0.1) for smooth movement/zoom effects
- Check MainMenuState.lua as a reference for a full working example