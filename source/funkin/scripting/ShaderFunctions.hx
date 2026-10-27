package funkin.scripting;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end

typedef ShaderTweenValue = {
	name:String,
	kind:String,
	from:Array<Float>,
	to:Array<Float>,
	?bools:Array<Bool>
}

class ShaderFunctions
{
	#if (!flash && MODS_ALLOWED && sys)
	public static function getCameraByName(name:String):FlxCamera {
		return switch(name.toLowerCase()) {
			case 'camgame' | 'game': PlayState.instance != null ? PlayState.instance.camGame : FlxG.camera;
			case 'camhud' | 'hud': PlayState.instance != null ? PlayState.instance.camHUD : FlxG.camera;
			case 'camother' | 'other': PlayState.instance != null ? PlayState.instance.camOther : FlxG.camera;
			case 'camera': FlxG.camera;
			default:
				var cam:Dynamic = MusicBeatState.getVariables().get(name);
				(cam != null && Std.isOfType(cam, FlxCamera)) ? cast cam : FlxG.camera;
		};
	}

	public static function cameraKey(name:String):String {
		return switch(name.toLowerCase()) {
			case 'camgame' | 'game': 'camGame';
			case 'camhud' | 'hud': 'camHUD';
			case 'camother' | 'other': 'camOther';
			default: name;
		};
	}

	public static function cameraPart(obj:String):String {
		var index:Int = obj.indexOf(':');
		return (index > -1) ? obj.substr(0, index) : obj;
	}

	public static function shaderPart(obj:String):String {
		var index:Int = obj.indexOf(':');
		return (index > -1 && index < obj.length - 1) ? obj.substr(index + 1) : null;
	}

	public static function cameraShader(camera:String):FlxRuntimeShader {
		return funkin.graphics.shaders.CameraShaders.get(getCameraByName(cameraPart(camera)), shaderPart(camera));
	}

	public static function isCamera(obj:String):Bool {
		obj = cameraPart(obj);
		return switch(obj.toLowerCase()) {
			case 'camgame' | 'game' | 'camhud' | 'hud' | 'camother' | 'other' | 'camera': true;
			default:
				var cam:Dynamic = MusicBeatState.getVariables().get(obj);
				(cam != null && Std.isOfType(cam, FlxCamera));
		};
	}
	#end

	public static function implement(funk:FunkinLua)
	{
		var lua = funk.lua;
		// shader shit
		funk.addLocalCallback("initLuaShader", function(name:String) {
			if(!ClientPrefs.data.shaders) return false;

			#if (!flash && MODS_ALLOWED && sys)
			return funk.initLuaShader(name);
			#else
			FunkinLua.luaTrace("initLuaShader: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
			return false;
		});
		
		funk.addLocalCallback("setSpriteShader", function(obj:String, shader:String) {
			if(!ClientPrefs.data.shaders) return false;

			#if (!flash && sys)
			if(!funk.runtimeShaders.exists(shader) && !funk.initLuaShader(shader))
			{
				FunkinLua.luaTrace('setSpriteShader: Shader $shader is missing!', false, false, FlxColor.RED);
				return false;
			}

			#if (!flash && MODS_ALLOWED && sys)
			if(isCamera(obj)) {
				var cam:FlxCamera = getCameraByName(cameraPart(obj));
				var arr:Array<String> = funk.runtimeShaders.get(shader);
				var rShader:FlxRuntimeShader = new funkin.graphics.shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
				funkin.graphics.shaders.CameraShaders.reset(cam);
				funkin.graphics.shaders.CameraShaders.add(cam, shader, rShader);
				return true;
			}
			#end

			var split:Array<String> = obj.split('.');
			var leObj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				leObj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(leObj != null) {
				var arr:Array<String> = funk.runtimeShaders.get(shader);
				leObj.shader = new funkin.graphics.shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
				return true;
			}
			#else
			FunkinLua.luaTrace("setSpriteShader: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			#end
			return false;
		});
		Lua_helper.add_callback(lua, "removeSpriteShader", function(obj:String) {
			#if (!flash && MODS_ALLOWED && sys)
			if(isCamera(obj)) {
				var cam:FlxCamera = getCameraByName(cameraPart(obj));
				if(shaderPart(obj) != null) return funkin.graphics.shaders.CameraShaders.remove(cam, shaderPart(obj));
				funkin.graphics.shaders.CameraShaders.reset(cam);
				return true;
			}
			#end

			var split:Array<String> = obj.split('.');
			var leObj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				leObj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(leObj != null) {
				leObj.shader = null;
				return true;
			}
			return false;
		});


		Lua_helper.add_callback(lua, "getShaderBool", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				FunkinLua.luaTrace("getShaderBool: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return null;
			}
			return shader.getBool(prop);
			#else
			FunkinLua.luaTrace("getShaderBool: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderBoolArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				FunkinLua.luaTrace("getShaderBoolArray: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return null;
			}
			return shader.getBoolArray(prop);
			#else
			FunkinLua.luaTrace("getShaderBoolArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderInt", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				FunkinLua.luaTrace("getShaderInt: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return null;
			}
			return shader.getInt(prop);
			#else
			FunkinLua.luaTrace("getShaderInt: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderIntArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				FunkinLua.luaTrace("getShaderIntArray: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return null;
			}
			return shader.getIntArray(prop);
			#else
			FunkinLua.luaTrace("getShaderIntArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderFloat", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				FunkinLua.luaTrace("getShaderFloat: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return null;
			}
			return shader.getFloat(prop);
			#else
			FunkinLua.luaTrace("getShaderFloat: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderFloatArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null)
			{
				FunkinLua.luaTrace("getShaderFloatArray: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return null;
			}
			return shader.getFloatArray(prop);
			#else
			FunkinLua.luaTrace("getShaderFloatArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return null;
			#end
		});


		Lua_helper.add_callback(lua, "setShaderBool", function(obj:String, prop:String, value:Bool) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderBool: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}
			shader.setBool(prop, value);
			return true;
			#else
			FunkinLua.luaTrace("setShaderBool: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderBoolArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderBoolArray: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}
			shader.setBoolArray(prop, values);
			return true;
			#else
			FunkinLua.luaTrace("setShaderBoolArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderInt", function(obj:String, prop:String, value:Int) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderInt: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}
			shader.setInt(prop, value);
			return true;
			#else
			FunkinLua.luaTrace("setShaderInt: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderIntArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderIntArray: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}
			shader.setIntArray(prop, values);
			return true;
			#else
			FunkinLua.luaTrace("setShaderIntArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderFloat", function(obj:String, prop:String, value:Float) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderFloat: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}
			shader.setFloat(prop, value);
			return true;
			#else
			FunkinLua.luaTrace("setShaderFloat: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderFloatArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderFloatArray: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}

			shader.setFloatArray(prop, values);
			return true;
			#else
			FunkinLua.luaTrace("setShaderFloatArray: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return true;
			#end
		});

		Lua_helper.add_callback(lua, "setShaderSampler2D", function(obj:String, prop:String, bitmapdataPath:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				FunkinLua.luaTrace("setShaderSampler2D: Shader is not FlxRuntimeShader!", false, false, FlxColor.RED);
				return false;
			}

			// trace('bitmapdatapath: $bitmapdataPath');
			var value = Paths.image(bitmapdataPath);
			if(value != null && value.bitmap != null)
			{
				// trace('Found bitmapdata. Width: ${value.bitmap.width} Height: ${value.bitmap.height}');
				shader.setSampler2D(prop, value.bitmap);
				return true;
			}
			return false;
			#else
			FunkinLua.luaTrace("setShaderSampler2D: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});

		funk.addLocalCallback("setCameraShader", function(camera:String, shader:String) {
			if(!ClientPrefs.data.shaders) return false;

			#if (!flash && MODS_ALLOWED && sys)
			if(!funk.runtimeShaders.exists(shader) && !funk.initLuaShader(shader))
			{
				FunkinLua.luaTrace('setCameraShader: Shader $shader is missing!', false, false, FlxColor.RED);
				return false;
			}

			var cam:FlxCamera = getCameraByName(cameraPart(camera));
			var arr:Array<String> = funk.runtimeShaders.get(shader);
			var rShader:FlxRuntimeShader = new funkin.graphics.shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
			funkin.graphics.shaders.CameraShaders.reset(cam);
			funkin.graphics.shaders.CameraShaders.add(cam, shader, rShader);
			return true;
			#else
			FunkinLua.luaTrace("setCameraShader: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "removeCameraShader", function(camera:String, ?name:String = null) {
			#if (!flash && MODS_ALLOWED && sys)
			var cam:FlxCamera = getCameraByName(cameraPart(camera));
			if(name == null) name = shaderPart(camera);
			if(name != null) return funkin.graphics.shaders.CameraShaders.remove(cam, name);
			funkin.graphics.shaders.CameraShaders.reset(cam);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderFloat", function(camera:String, prop:String, value:Float) {
			LuaUtils.warnDeprecated('setCameraShaderFloat', 'setShaderFloat with the camera name');
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = cameraShader(camera);
			if(shader == null) return false;
			shader.setFloat(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getCameraShaderFloat", function(camera:String, prop:String) {
			LuaUtils.warnDeprecated('getCameraShaderFloat', 'getShaderFloat with the camera name');
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = cameraShader(camera);
			return (shader == null) ? null : shader.getFloat(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderInt", function(camera:String, prop:String, value:Int) {
			LuaUtils.warnDeprecated('setCameraShaderInt', 'setShaderInt with the camera name');
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = cameraShader(camera);
			if(shader == null) return false;
			shader.setInt(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getCameraShaderInt", function(camera:String, prop:String) {
			LuaUtils.warnDeprecated('getCameraShaderInt', 'getShaderInt with the camera name');
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = cameraShader(camera);
			return (shader == null) ? null : shader.getInt(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderBool", function(camera:String, prop:String, value:Bool) {
			LuaUtils.warnDeprecated('setCameraShaderBool', 'setShaderBool with the camera name');
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = cameraShader(camera);
			if(shader == null) return false;
			shader.setBool(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getCameraShaderBool", function(camera:String, prop:String) {
			LuaUtils.warnDeprecated('getCameraShaderBool', 'getShaderBool with the camera name');
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = cameraShader(camera);
			return (shader == null) ? null : shader.getBool(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderFloatArray", function(camera:String, prop:String, values:Dynamic) {
			LuaUtils.warnDeprecated('setCameraShaderFloatArray', 'setShaderFloatArray with the camera name');
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = cameraShader(camera);
			if(shader == null) return false;
			shader.setFloatArray(prop, values);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderSampler2D", function(camera:String, prop:String, bitmapdataPath:String) {
			LuaUtils.warnDeprecated('setCameraShaderSampler2D', 'setShaderSampler2D with the camera name');
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = cameraShader(camera);
			if(shader == null) return false;
			var value = Paths.image(bitmapdataPath);
			if(value != null && value.bitmap != null)
			{
				shader.setSampler2D(prop, value.bitmap);
				return true;
			}
			return false;
			#else
			return false;
			#end
		});
		registerShared(lua, (name, args) -> if(PlayState.instance != null) PlayState.instance.callOnLuas(name, args), (msg) -> FunkinLua.luaTrace(msg, false, false, FlxColor.RED));
	}

	public static function registerShared(lua:State, notify:(String, Array<Dynamic>)->Void, ?onError:String->Void)
	{
		var report:String->Void = (onError != null) ? onError : function(msg:String) trace(msg);

		Lua_helper.add_callback(lua, "addCameraShader", function(camera:String, shader:String, ?name:String = null) {
			#if (!flash && MODS_ALLOWED && sys)
			if(!ClientPrefs.data.shaders) return null;
			var rShader:FlxRuntimeShader = funkin.graphics.shaders.ShaderLoader.create(shader);
			if(rShader == null)
			{
				report('addCameraShader: Shader $shader is missing!');
				return null;
			}
			return funkin.graphics.shaders.CameraShaders.add(getCameraByName(cameraPart(camera)), (name != null && name.length > 0) ? name : shader, rShader);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "getCameraShaders", function(camera:String) {
			#if (!flash && MODS_ALLOWED && sys)
			return funkin.graphics.shaders.CameraShaders.names(getCameraByName(cameraPart(camera)));
			#else
			return [];
			#end
		});
		Lua_helper.add_callback(lua, "tweenShaderFloat", function(tag:String, obj:String, prop:String, value:Float, duration:Float, ?options:Dynamic = null) {
			options = LuaUtils.namedOptions(options, LuaUtils.TWEEN_OPTIONS);
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				report('tweenShaderFloat: Shader of $obj not found!');
				return null;
			}
			if(tag == null) tag = 'shader_' + obj + '_' + prop;
			LuaUtils.cancelTween(tag);
			var start:Null<Float> = shader.getFloat(prop);
			var myOptions = LuaUtils.getLuaTween(options);
			var key:String = 'tween_' + LuaUtils.formatVariable(tag);
			var variables = MusicBeatState.getVariables();
			var tween:FlxTween = FlxTween.num(start != null ? start : 0, value, duration, {
				type: myOptions != null ? myOptions.type : FlxTweenType.ONESHOT,
				ease: myOptions != null ? myOptions.ease : FlxEase.linear,
				startDelay: myOptions != null ? myOptions.startDelay : 0,
				loopDelay: myOptions != null ? myOptions.loopDelay : 0,
				onComplete: function(twn:FlxTween) {
					if(twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD) variables.remove(key);
					if(myOptions != null && myOptions.onComplete != null) notify(myOptions.onComplete, [tag, prop]);
				}
			}, function(current:Float) {
				shader.setFloat(prop, current);
				if(myOptions != null && myOptions.onUpdate != null) notify(myOptions.onUpdate, [tag, current]);
			});
			variables.set(key, tween);
			return tag;
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "tweenShader", function(tag:String, obj:String, values:Dynamic, duration:Float, ?options:Dynamic = null) {
			options = LuaUtils.namedOptions(options, LuaUtils.TWEEN_OPTIONS);
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null)
			{
				report('tweenShader: Shader of $obj not found!');
				return null;
			}
			if(values == null || Type.typeof(values) != TObject)
			{
				report('tweenShader: values must be a table, like {intensity = 1}');
				return null;
			}
			var targets:Array<ShaderTweenValue> = [];
			for (name in Reflect.fields(values))
			{
				var target:ShaderTweenValue = tweenTarget(shader, name, Reflect.field(values, name));
				if(target == null) report('tweenShader: "$name" is not a float, int, bool or vec uniform of the shader of $obj, or its value is not valid!');
				else targets.push(target);
			}
			if(targets.length < 1) return null;

			if(tag == null || tag.length < 1) tag = 'shader_' + obj;
			LuaUtils.cancelTween(tag);
			var myOptions = LuaUtils.getLuaTween(options);
			var key:String = 'tween_' + LuaUtils.formatVariable(tag);
			var variables = MusicBeatState.getVariables();
			var tween:FlxTween = FlxTween.num(0, 1, duration, {
				type: myOptions != null ? myOptions.type : FlxTweenType.ONESHOT,
				ease: myOptions != null ? myOptions.ease : FlxEase.linear,
				startDelay: myOptions != null ? myOptions.startDelay : 0,
				loopDelay: myOptions != null ? myOptions.loopDelay : 0,
				onStart: function(twn:FlxTween) {
					if(myOptions != null && myOptions.onStart != null) notify(myOptions.onStart, [tag, obj]);
				},
				onComplete: function(twn:FlxTween) {
					for (target in targets) if(target.kind == 'bool') setShaderValue(shader, target, 1);
					if(twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD) variables.remove(key);
					if(myOptions != null && myOptions.onComplete != null) notify(myOptions.onComplete, [tag, obj]);
				}
			}, function(progress:Float) {
				for (target in targets) if(target.kind != 'bool') setShaderValue(shader, target, progress);
				if(myOptions != null && myOptions.onUpdate != null) notify(myOptions.onUpdate, [tag, obj]);
			});
			variables.set(key, tween);
			return tag;
			#else
			return null;
			#end
		});
	}

	#if (!flash && MODS_ALLOWED && sys)
	static function tweenTarget(shader:FlxRuntimeShader, name:String, value:Dynamic):ShaderTweenValue
	{
		if(value == null || shader.data == null) return null;
		var param:Dynamic = Reflect.field(shader.data, name);
		if(param == null) return null;
		var rawType:Dynamic = null;
		try rawType = Reflect.getProperty(param, 'type') catch(e:Dynamic) {}
		var type:Null<Int> = Std.parseInt(Std.string(rawType));
		if(type == null || type < 0 || type > 11) return null;
		var kind:String = (type < 4) ? 'bool' : ((type < 8) ? 'float' : 'int');
		var size:Int = (type % 4) + 1;

		var current:Array<Dynamic> = Reflect.getProperty(param, 'value');
		var from:Array<Float> = [for (i in 0...size) (current != null && i < current.length) ? numberOf(current[i], 0) : 0];
		if(kind == 'bool')
		{
			var list:Array<Dynamic> = Std.isOfType(value, Array) ? value : [for (i in 0...size) value];
			var bools:Array<Bool> = [for (i in 0...size) (i < list.length) ? boolOf(list[i]) : (current != null && i < current.length && current[i] == true)];
			return {name: name, kind: kind, from: from, to: from.copy(), bools: bools};
		}

		var to:Array<Float> = null;
		if(Std.isOfType(value, Array))
		{
			var list:Array<Dynamic> = value;
			to = [for (i in 0...size) (i < list.length) ? numberOf(list[i], from[i]) : from[i]];
		}
		else if(Std.isOfType(value, String) && Math.isNaN(Std.parseFloat(value)))
		{
			if(kind != 'float' || size < 3) return null;
			var color:Null<FlxColor> = LuaUtils.colorFromLua(value);
			if(color == null) return null;
			var channels:Array<Float> = [color.redFloat, color.greenFloat, color.blueFloat, color.alphaFloat];
			to = [for (i in 0...size) channels[i]];
		}
		else
		{
			var number:Float = numberOf(value, Math.NaN);
			if(Math.isNaN(number)) return null;
			to = [for (i in 0...size) number];
		}
		return {name: name, kind: kind, from: from, to: to};
	}

	static function setShaderValue(shader:FlxRuntimeShader, target:ShaderTweenValue, progress:Float)
	{
		switch(target.kind)
		{
			case 'bool':
				if(target.bools.length == 1) shader.setBool(target.name, target.bools[0]);
				else shader.setBoolArray(target.name, target.bools);
			case 'int':
				var values:Array<Int> = [for (i in 0...target.to.length) Math.round(FlxMath.lerp(target.from[i], target.to[i], progress))];
				if(values.length == 1) shader.setInt(target.name, values[0]);
				else shader.setIntArray(target.name, values);
			default:
				var values:Array<Float> = [for (i in 0...target.to.length) FlxMath.lerp(target.from[i], target.to[i], progress)];
				if(values.length == 1) shader.setFloat(target.name, values[0]);
				else shader.setFloatArray(target.name, values);
		}
	}

	static function numberOf(value:Dynamic, fallback:Float):Float
	{
		if(value == null) return fallback;
		if(Std.isOfType(value, Bool)) return value ? 1 : 0;
		var number:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(number) ? fallback : number;
	}

	static function boolOf(value:Dynamic):Bool
	{
		if(Std.isOfType(value, Bool)) return value;
		var text:String = Std.string(value).trim().toLowerCase();
		return text == 'true' || text == '1';
	}
	#end

	#if (!flash && MODS_ALLOWED && sys)
	public static function getShader(obj:String):FlxRuntimeShader
	{
		if(obj.startsWith('stage:'))
		{
			var name:String = obj.substr(6).trim();
			var found:FlxRuntimeShader = (PlayState.instance != null) ? PlayState.instance.getStageShader(name) : null;
			if(found == null) FunkinLua.luaTrace('Error on getting shader: Stage shader "$name" not found', false, false, FlxColor.RED);
			return found;
		}
		if(isCamera(obj))
			return cameraShader(obj);

		var split:Array<String> = obj.split('.');
		var target:FlxSprite = null;
		if(split.length > 1) target = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
		else target = LuaUtils.getObjectDirectly(split[0]);

		if(target == null)
		{
			FunkinLua.luaTrace('Error on getting shader: Object $obj not found', false, false, FlxColor.RED);
			return null;
		}
		return cast (target.shader, FlxRuntimeShader);
	}
	#end
}