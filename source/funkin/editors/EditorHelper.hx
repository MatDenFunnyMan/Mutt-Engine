package funkin.editors;
import funkin.backend.HScriptStateLoader.HScriptState;
import funkin.backend.StateManager;

class EditorHelper
{
	public static var returnToState:String = 'MainMenuState';
	
	public static function saveCurrentState():Void
	{
		var currentState = Type.getClassName(Type.getClass(FlxG.state));
		if(currentState != null)
		{
			var parts = currentState.split('.');
			var stateName = parts[parts.length - 1];
			if(stateName == 'HScriptState' && Std.isOfType(FlxG.state, HScriptState))
			{
				var hscriptState:HScriptState = cast FlxG.state;
				stateName = hscriptState.stateName;
			}
			else if(stateName == 'LuaState' && Std.isOfType(FlxG.state, funkin.scripting.LuaStateLoader.LuaState))
			{
				var luaState:funkin.scripting.LuaStateLoader.LuaState = cast FlxG.state;
				stateName = luaState.stateName;
			}
			if(stateName == 'MasterEditorMenu' || stateName == 'EditorMenuState')
				stateName = 'MainMenuState';
			returnToState = stateName;
			trace('EditorHelper: Saved return state: $stateName');
		}
	}
	
	public static function returnToPreviousState():Void
	{
		var stateToReturn = returnToState != null ? returnToState : 'MainMenuState';
		returnToState = 'MainMenuState';
		trace('EditorHelper: Returning to state: $stateToReturn');
		
		var hadMusic:Bool = false;
		var musicVolume:Float = 1;
		
		trace('EditorHelper: Music status BEFORE - music is null? ${FlxG.sound.music == null}');
		if(FlxG.sound.music != null)
		{
			trace('EditorHelper: Music status BEFORE - playing? ${FlxG.sound.music.playing}');
			trace('EditorHelper: Music status BEFORE - volume? ${FlxG.sound.music.volume}');
		}
		
		if(FlxG.sound.music == null || !FlxG.sound.music.playing)
		{
			trace('EditorHelper: Starting freakyMenu music...');
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			hadMusic = true;
			musicVolume = 0.7;
		}
		else
		{
			trace('EditorHelper: Music is already playing, preserving it');
			hadMusic = true;
			musicVolume = FlxG.sound.music.volume;
		}
		
		trace('EditorHelper: About to switch state...');
		StateManager.switchState(stateToReturn);
		trace('EditorHelper: State switched!');
		
		if(hadMusic && FlxG.sound.music != null)
		{
			trace('EditorHelper: Music status AFTER switch - playing? ${FlxG.sound.music.playing}');
			trace('EditorHelper: Music status AFTER switch - volume? ${FlxG.sound.music.volume}');
			
			if(!FlxG.sound.music.playing)
			{
				trace('EditorHelper: Music was stopped by state switch! Restarting...');
				FlxG.sound.playMusic(Paths.music('freakyMenu'), musicVolume);
			}
		}
	}
}