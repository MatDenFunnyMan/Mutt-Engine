package funkin.backend;

import flixel.FlxState;
import flixel.FlxSubState;
import funkin.scripting.HScript;

class HScriptSubState extends MusicBeatSubstate
{
	public var hscript:HScript;
	public var subStateName:String;
	public var modDirectory:String;

	public function new(script:HScript, name:String, ?modDir:String)
	{
		super();
		this.hscript = script;
		this.subStateName = name;
		this.modDirectory = modDir;
	}

	override function create()
	{
		super.create();

		if(hscript != null && hscript.exists('create'))
			hscript.call('create', [this]);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(hscript != null && hscript.exists('update'))
			hscript.call('update', [elapsed]);
	}

	var lastStepHit:Int = -1;
	override public function stepHit():Void
	{
		super.stepHit();

		if(curStep == lastStepHit) return;

		lastStepHit = curStep;
		if(hscript != null && hscript.exists('onStepHit'))
		{
			hscript.set('curStep', curStep);
			hscript.call('onStepHit', []);
		}
	}

	var lastBeatHit:Int = -1;
	override public function beatHit():Void
	{
		super.beatHit();

		if(curBeat == lastBeatHit) return;

		lastBeatHit = curBeat;
		if(hscript != null && hscript.exists('onBeatHit'))
		{
			hscript.set('curBeat', curBeat);
			hscript.call('onBeatHit', []);
		}
	}

	override function destroy()
	{
		if(hscript != null)
		{
			if(hscript.exists('onDestroy')) hscript.call('onDestroy', []);
			hscript.destroy();
		}
		super.destroy();
	}
}

class HScriptSubStateLoader
{
	public static function loadSubStateScript(parent:FlxState, subStateName:String):FlxSubState
	{
		#if (HSCRIPT_ALLOWED && MODS_ALLOWED)
		var modDirectory:String = Mods.currentModDirectory;
		if(modDirectory == null || modDirectory == '')
		{
			var save = FlxG.save;
			if(save != null && save.data != null && save.data.currentMod != null)
				modDirectory = save.data.currentMod;
		}

		if(modDirectory == null || modDirectory == '') return null;

		var dir:String = Paths.mods('$modDirectory/states/substates/');
		var scriptPath:String = HScriptStateLoader.findScriptInDir(dir, '$subStateName.hx');
		if(scriptPath == null) return null;

		try
		{
			var hscript = new HScript(null, scriptPath, null, false);
			var instance = new HScriptSubState(hscript, subStateName, modDirectory);

			hscript.set('substate', instance);
			hscript.set('parent', parent);
			hscript.set('game', funkin.game.states.PlayState.instance);
			hscript.set('add', function(obj:Dynamic) { return instance.add(obj); });
			hscript.set('remove', function(obj:Dynamic, splice:Bool = false) { return instance.remove(obj, splice); });
			hscript.set('insert', function(position:Int, obj:Dynamic) { return instance.insert(position, obj); });
			hscript.set('members', instance.members);
			hscript.set('camera', FlxG.camera);
			hscript.set('cameras', FlxG.cameras);
			hscript.set('save', FlxG.save);
			hscript.set('sound', FlxG.sound);
			hscript.set('close', function() { parent.closeSubState(); });
			hscript.set('switchState', function(nextState:Dynamic) { MusicBeatState.switchState(nextState); });
			hscript.set('switchStateByName', function(name:String) { MusicBeatState.switchStateByName(name); });

			return instance;
		}
		catch(e:Dynamic)
		{
			trace('Substate script "$subStateName" failed: $e');
		}
		#end

		return null;
	}
}