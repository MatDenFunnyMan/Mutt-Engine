package funkin.editors;
import funkin.backend.HScriptStateLoader.HScriptState;
import funkin.backend.StateManager;
import flixel.util.FlxSave;

class EditorHelper
{
	public static var returnToState:String = 'MainMenuState';

	static var _editorMusicTimer:FlxTimer;

	static function bindEditorSave():FlxSave
	{
		var save:FlxSave = new FlxSave();
		save.bind('chart_editor_data', CoolUtil.getSavePath());
		return save;
	}

	public static function isEditorMusicMuted():Bool
	{
		var save:FlxSave = bindEditorSave();
		var muted:Bool = (save.data.editorMusicMuted == true);
		save.close();
		return muted;
	}

	public static function setEditorMusicMuted(value:Bool):Void
	{
		var save:FlxSave = bindEditorSave();
		save.data.editorMusicMuted = value;
		save.flush();
		save.close();
	}

	public static function scheduleEditorMusic(delay:Float):Void
	{
		cancelEditorMusicTimer();
		if(isEditorMusicMuted()) return;

		_editorMusicTimer = new FlxTimer().start(delay, function(_) {
			_editorMusicTimer = null;
			FlxG.sound.playMusic(Paths.music('chartEditorLoop'), 0);
			FlxG.sound.music.fadeIn(1.5, 0, 0.75);
		});
	}

	public static function stopEditorMusic():Void
	{
		cancelEditorMusicTimer();
		if(FlxG.sound.music == null) return;

		if(FlxG.sound.music.fadeTween != null)
		{
			FlxG.sound.music.fadeTween.cancel();
			FlxG.sound.music.fadeTween = null;
		}
		FlxG.sound.music.stop();
	}

	static function cancelEditorMusicTimer():Void
	{
		if(_editorMusicTimer == null) return;
		_editorMusicTimer.cancel();
		_editorMusicTimer = null;
	}

	public static function createEditorMusicCheckBox(x:Float, y:Float, ?textWid:Int = 150):PsychUICheckBox
	{
		var checkBox:PsychUICheckBox = new PsychUICheckBox(x, y, 'Mute Editor Music', textWid);
		checkBox.checked = isEditorMusicMuted();
		checkBox.onClick = function()
		{
			setEditorMusicMuted(checkBox.checked);
			if(checkBox.checked) stopEditorMusic();
			else if(FlxG.sound.music == null || !FlxG.sound.music.playing) scheduleEditorMusic(1);
		};
		return checkBox;
	}

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