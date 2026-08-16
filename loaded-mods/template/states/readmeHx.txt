Put your custom HScript state scripts here!

IMPORTANT NOTES:
- File name must match the state name (e.g., MainMenuState.hx for Main Menu)
- ALWAYS include "import backend.StateManager;" at the top of your script
- You can organize scripts in subfolders! (e.g., MyFolder/MainMenuState.hx)

HOW TO USE:
1. Create a new .hx file with your state name (e.g., "MainMenuState.hx")
2. Start with: import backend.StateManager;
3. Add your create() function to initialize sprites and objects
4. Add your update(elapsed) function for logic and controls
5. Use StateManager.switchState('StateName') to navigate between states

EXAMPLE STRUCTURE:

import backend.StateManager;

var mySprite;

function create(state) {
    mySprite = new FlxSprite().loadGraphic(Paths.image('myImage'));
    state.add(mySprite);
}

function update(elapsed) {
    if (FlxG.keys.justPressed.ENTER) {
        StateManager.switchState('FreeplayState');
    }
}

SWITCHING STATES:
- Use StateManager.switchState('StateName') to navigate between states
- Available states: TitleState, MainMenuState, StoryMenuState, FreeplayState, OptionsState, etc.

RETURN STATE AFTER SONG:
- Set PlayState.returnAfterSongState = 'StateName' inside a song script to control where the game goes after the song ends
- By default the game returns to FreeplayState, but you can override it!

Example (put this in your song's script):

function onCreate() {
    PlayState.returnAfterSongState = 'MainMenuState';
}

Available states: TitleState, MainMenuState, StoryMenuState, FreeplayState, OptionsState, etc.
You can also use custom states: PlayState.returnAfterSongState = 'MySigmaState';
NOTE: This only works in song scripts (inside PlayState), not in state scripts.
      Place your script in one of these locations:
      - scripts/myScript.hx        (global, runs on every song)
      - data/mySong/myScript.hx    (specific song only)

CUSTOM STATES:
You can create completely new states that don't replace existing ones!

Examples:
- TitleState.hx           (replaces the original Title State)
- SigmaState.hx           (creates a brand new state called "SigmaState")
- CreditsState.hx         (replaces the original Credits State)
- MyFolder/MyState.hx     (organized in a subfolder, works the same!)

Access custom states with: StateManager.switchState('YourStateName')

INITIAL STATE (Advanced):
If you want your state to load first instead of TitleState, add this to your script:

function isInitialState() {
    return true;
}

CONTROLS:
- FlxG.keys.justPressed.KEY          -- keyboard key just pressed (UP, DOWN, ENTER, ESCAPE...)
- FlxG.keys.pressed.KEY              -- held down
- FlxG.keys.justReleased.KEY         -- just released
- controls.ACCEPT                    -- game action just pressed (ACCEPT, BACK, UI_UP, UI_DOWN...)

SPRITES:
- new FlxSprite(x, y)
- sprite.loadGraphic(Paths.image('imagePath'))
- new FlxAnimateFrame(x, y, Paths.getPath('atlasPath', IMAGE))
- state.add(sprite)                  -- adds sprite to the state
- state.remove(sprite)               -- removes sprite from the state
- sprite.antialiasing = ClientPrefs.data.antialiasing

ANIMATIONS:
- sprite.animation.addByPrefix('animName', 'prefix', fps, looped)
- sprite.animation.play('animName', true)

CAMERA:
- FlxG.camera.zoom = 1.0
- FlxG.camera.scroll.set(x, y)
- FlxMath.lerp(a, b, t)             -- useful for smooth camera movement

SOUND:
- FlxG.sound.play(Paths.sound('soundName'))
- FlxG.sound.playMusic(Paths.music('musicName'))
- FlxG.sound.music.stop()

TIPS:
- Use ClientPrefs.data.antialiasing for antialiasing on sprites
- FlxG.width and FlxG.height are available for screen dimensions
- Use FlxMath.lerp(current, target, 0.1) for smooth movement/zoom effects
- Check MainMenuState.hx as a reference for a full working example