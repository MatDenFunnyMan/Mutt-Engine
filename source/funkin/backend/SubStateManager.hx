package funkin.backend;

import flixel.FlxState;
import flixel.FlxSubState;

class SubStateManager
{
	public static function open(parent:FlxState, name:String, factory:Void->FlxSubState):Void
	{
		var custom:FlxSubState = null;

		#if HSCRIPT_ALLOWED
		custom = HScriptSubStateLoader.loadSubStateScript(parent, name);
		#end

		#if LUA_ALLOWED
		if(custom == null)
			custom = funkin.scripting.LuaSubStateLoader.loadSubStateScript(parent, name);
		#end

		parent.openSubState(custom != null ? custom : factory());
	}
}