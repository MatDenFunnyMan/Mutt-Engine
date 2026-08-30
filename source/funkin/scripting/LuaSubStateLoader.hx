package funkin.scripting;

#if LUA_ALLOWED

import flixel.FlxState;
import flixel.FlxSubState;
import funkin.scripting.LuaStateLoader.LuaState;

class LuaSubState extends MusicBeatSubstate
{
	public var luaVM:LuaState;
	public var subStateName:String;
	public var modDirectory:String;
	public var parentState:FlxState;

	public function new(scriptPath:String, name:String, parent:FlxState, ?modDir:String)
	{
		super();
		this.subStateName = name;
		this.modDirectory = modDir;
		this.parentState = parent;

		var previous:LuaState = LuaState.instance;
		luaVM = new LuaState(scriptPath, name, modDir);
		luaVM.displayTarget = this;
		LuaState.instance = previous;

		if(luaVM.lua != null)
		{
			luaVM.set('subStateName', name);
			Lua_helper.add_callback(luaVM.lua, "closeSubState", function() { parentState.closeSubState(); });
			Lua_helper.add_callback(luaVM.lua, "close", function() { parentState.closeSubState(); });
		}
	}

	override function create()
	{
		super.create();

		if(luaVM != null)
		{
			luaVM.call('onCreate', []);
			luaVM.call('onCreatePost', []);
		}
	}

	override function update(elapsed:Float)
	{
		if(luaVM != null) luaVM.call('onUpdate', [elapsed]);
		super.update(elapsed);
		if(luaVM != null) luaVM.call('onUpdatePost', [elapsed]);
	}

	var lastStepHit:Int = -1;
	override public function stepHit():Void
	{
		super.stepHit();

		if(curStep == lastStepHit || luaVM == null) return;

		lastStepHit = curStep;
		luaVM.set('curStep', curStep);
		luaVM.call('onStepHit', []);
	}

	var lastBeatHit:Int = -1;
	override public function beatHit():Void
	{
		super.beatHit();

		if(curBeat == lastBeatHit || luaVM == null) return;

		lastBeatHit = curBeat;
		luaVM.set('curBeat', curBeat);
		luaVM.call('onBeatHit', []);
	}

	override function destroy()
	{
		if(luaVM != null)
		{
			luaVM.displayTarget = null;
			luaVM.destroy();
			luaVM = null;
		}
		super.destroy();
	}
}

class LuaSubStateLoader
{
	public static function loadSubStateScript(parent:FlxState, subStateName:String):FlxSubState
	{
		#if MODS_ALLOWED
		var modDirectory:String = Mods.currentModDirectory;
		if(modDirectory == null || modDirectory == '')
		{
			var save = FlxG.save;
			if(save != null && save.data != null && save.data.currentMod != null)
				modDirectory = save.data.currentMod;
		}

		if(modDirectory == null || modDirectory == '') return null;

		var dir:String = Paths.mods('$modDirectory/states/substates/');
		var scriptPath:String = LuaStateLoader.findScriptInDir(dir, '$subStateName.lua');
		if(scriptPath == null) return null;

		try
		{
			return new LuaSubState(scriptPath, subStateName, parent, modDirectory);
		}
		catch(e:Dynamic)
		{
			trace('Lua substate "$subStateName" failed: $e');
		}
		#end

		return null;
	}
}

#end
