package funkin.scripting;

#if (LUA_ALLOWED && HSCRIPT_ALLOWED)
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
import funkin.scripting.HScript;
import funkin.scripting.HScript.HScriptInfos;
#end

interface IFunkinScript
{
	public var scriptName:String;
	public var closed:Bool;
	public var lastCalledFunction:String;

	public function set(variable:String, data:Dynamic):Void;
	public function call(func:String, args:Array<Dynamic>):Dynamic;
	public function stop():Void;
	public function scriptTrace(text:String):Void;

	#if (LUA_ALLOWED && HSCRIPT_ALLOWED)
	public var hscript:HScript;
	public function initHaxeModuleCode(code:String, ?varsToBring:Any):Void;
	#end
}

class FunkinScript implements IFunkinScript
{
	public var scriptName:String = '';
	public var modFolder:String = null;
	public var closed:Bool = false;
	public var lastCalledFunction:String = '';

	public function new(?scriptName:String)
	{
		if(scriptName != null) setScriptName(scriptName);
	}

	public function setScriptName(name:String)
	{
		scriptName = name.trim();
		modFolder = resolveModFolder(scriptName);
	}

	public static function resolveModFolder(path:String):String
	{
		#if MODS_ALLOWED
		if(path == null) return null;
		var parts:Array<String> = path.replace('\\', '/').split('/');
		if(parts.length > 1 && parts[0] + '/' == Paths.mods()
			&& (Mods.currentModDirectory == parts[1] || Mods.getGlobalMods().contains(parts[1])))
			return parts[1];
		#end
		return null;
	}

	#if (LUA_ALLOWED && HSCRIPT_ALLOWED)
	public var hscript:HScript = null;

	public function initHaxeModuleCode(code:String, ?varsToBring:Any = null):Void
	{
		if(hscript != null) {
			hscript.destroy();
			hscript = null;
		}
		try {
			hscript = new HScript(null, code, varsToBring);
			hscript.origin = scriptName;
			hscript.modFolder = modFolder;
		}
		catch(e:IrisError) {
			var pos:HScriptInfos = cast {fileName: scriptName, isLua: true};
			if(lastCalledFunction != '') pos.funcName = lastCalledFunction;
			Iris.error(Printer.errorToString(e, false), pos);
			hscript = null;
		}
	}
	#end

	public function set(variable:String, data:Dynamic):Void {}
	public function call(func:String, args:Array<Dynamic>):Dynamic return LuaUtils.Function_Continue;
	public function stop():Void closed = true;
	public function scriptTrace(text:String):Void trace('[$scriptName] $text');
}

#if LUA_ALLOWED
class FunkinLuaScript extends FunkinScript
{
	public var lua:State = null;
	public var traceLabel:String = 'FunkinLuaScript';

	public function new(?scriptName:String)
	{
		super(scriptName);
	}

	public function initLua()
	{
		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		LuaSharedFunctions.registerFileAndSaveFunctions(lua);

		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('Function_StopLua', LuaUtils.Function_StopLua);
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);
		set('buildTarget', LuaUtils.getBuildTarget());
		set('currentModDirectory', Mods.currentModDirectory);
	}

	public function runFile(path:String):Bool
	{
		if(lua == null) return false;
		try {
			var result:Dynamic = LuaL.dofile(lua, path);
			var resultStr:String = Lua.tostring(lua, result);
			if(resultStr != null && result != 0) {
				trace('$traceLabel: Error loading $path\n$resultStr');
				lua = null;
				return false;
			}
		} catch(e:Dynamic) {
			trace('$traceLabel: Exception loading $path: $e');
			lua = null;
			return false;
		}
		return true;
	}

	public function exists(func:String):Bool
	{
		if(lua == null) return false;
		Lua.getglobal(lua, func);
		var type:Int = Lua.type(lua, -1);
		Lua.pop(lua, 1);
		return type == Lua.LUA_TFUNCTION;
	}

	override public function set(variable:String, data:Dynamic):Void
	{
		if(lua == null) return;
		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
	}

	override public function call(func:String, args:Array<Dynamic>):Dynamic
	{
		if(closed || lua == null) return LuaUtils.Function_Continue;

		lastCalledFunction = func;
		try {
			Lua.getglobal(lua, func);
			var type:Int = Lua.type(lua, -1);
			if(type != Lua.LUA_TFUNCTION) {
				Lua.pop(lua, 1);
				return LuaUtils.Function_Continue;
			}
			for(arg in args) Convert.toLua(lua, arg);
			var status:Int = Lua.pcall(lua, args.length, 1, 0);
			if(status != Lua.LUA_OK) {
				var error:String = Lua.tostring(lua, -1);
				Lua.pop(lua, 1);
				trace('$traceLabel error in $func: $error');
				return LuaUtils.Function_Continue;
			}
			var result:Dynamic = cast Convert.fromLua(lua, -1);
			if(result == null) result = LuaUtils.Function_Continue;
			Lua.pop(lua, 1);
			return result;
		} catch(e:Dynamic) {
			trace('$traceLabel exception in $func: $e');
		}
		return LuaUtils.Function_Continue;
	}

	override public function stop():Void
	{
		closed = true;
		if(lua != null) {
			Lua.close(lua);
			lua = null;
		}
		#if HSCRIPT_ALLOWED
		if(hscript != null) {
			hscript.destroy();
			hscript = null;
		}
		#end
	}

}
#end