package funkin.scripting;

import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import psychlua.LuaUtils.LuaTweenOptions;
import Type.ValueType;

class LuaSharedFunctions
{
	public static function registerFileAndSaveFunctions(lua:State)
	{
		Lua_helper.add_callback(lua, "getTextFromFile", function(path:String, ?ignoreModFolders:Bool = false) {
			return Paths.getTextFromFile(path, ignoreModFolders);
		});
		Lua_helper.add_callback(lua, "saveFile", function(path:String, content:String, ?absolute:Bool = false) {
			try {
				#if MODS_ALLOWED
				if(!absolute)
					File.saveContent(Paths.mods(path), content);
				else
				#end
					File.saveContent(path, content);
				return true;
			} catch(e:Dynamic) {
				trace('saveFile: Error trying to save ' + path + ': ' + e);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "deleteFile", function(path:String, ?ignoreModFolders:Bool = false, ?absolute:Bool = false) {
			try {
				var lePath:String = path;
				if(!absolute) lePath = Paths.getPath(path, TEXT, !ignoreModFolders);
				if(FileSystem.exists(lePath)) {
					FileSystem.deleteFile(lePath);
					return true;
				}
			} catch(e:Dynamic) {
				trace('deleteFile: Error trying to delete ' + path + ': ' + e);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "checkFileExists", function(filename:String, ?absolute:Bool = false) {
			#if MODS_ALLOWED
			if(absolute) return FileSystem.exists(filename);
			return FileSystem.exists(Paths.getPath(filename, TEXT));
			#else
			if(absolute) return openfl.utils.Assets.exists(filename, TEXT);
			return openfl.utils.Assets.exists(Paths.getPath(filename, TEXT));
			#end
		});
		Lua_helper.add_callback(lua, "directoryFileList", function(folder:String) {
			#if sys
			if(sys.FileSystem.exists(folder) && sys.FileSystem.isDirectory(folder))
				return sys.FileSystem.readDirectory(folder);
			#end
			return [];
		});
		Lua_helper.add_callback(lua, "initSaveData", function(name:String, ?folder:String = 'psychenginemods') {
			var variables = MusicBeatState.getVariables();
			if(!variables.exists('save_$name')) {
				var save:flixel.util.FlxSave = new flixel.util.FlxSave();
				save.bind(name, CoolUtil.getSavePath() + '/' + folder);
				variables.set('save_$name', save);
				return;
			}
			trace('initSaveData: Save file already initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "eraseSaveData", function(name:String) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				variables.get('save_$name').erase();
				return;
			}
			trace('eraseSaveData: Save file not initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "flushSaveData", function(name:String) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				variables.get('save_$name').flush();
				return;
			}
			trace('flushSaveData: Save file not initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "getDataFromSave", function(name:String, field:String, ?defaultValue:Dynamic = null) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				var saveData = variables.get('save_$name').data;
				if(Reflect.hasField(saveData, field))
					return Reflect.field(saveData, field);
				else
					return defaultValue;
			}
			trace('getDataFromSave: Save file not initialized: ' + name);
			return defaultValue;
		});
		Lua_helper.add_callback(lua, "setDataFromSave", function(name:String, field:String, value:Dynamic) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				Reflect.setField(variables.get('save_$name').data, field, value);
				return;
			}
			trace('setDataFromSave: Save file not initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "getSave", function(key:String) {
			if(FlxG.save.data != null) return Reflect.getProperty(FlxG.save.data, key);
			return null;
		});
		Lua_helper.add_callback(lua, "setSave", function(key:String, value:Dynamic) {
			if(FlxG.save.data != null) Reflect.setProperty(FlxG.save.data, key, value);
		});
		Lua_helper.add_callback(lua, "flushSave", function() FlxG.save.flush());
	}

	public static function registerObjectOrderFunctions(lua:State, getGroupSource:Void->Dynamic, getFallbackContainer:Void->Dynamic, ?onError:String->Void)
	{
		Lua_helper.add_callback(lua, "getObjectOrder", function(obj:String, ?group:String = null) {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			if(leObj != null)
			{
				if(group != null)
				{
					var groupOrArray:Dynamic = Reflect.getProperty(getGroupSource(), group);
					if(groupOrArray != null)
					{
						switch(Type.typeof(groupOrArray))
						{
							case TClass(Array):
								return groupOrArray.indexOf(leObj);
							default:
								return Reflect.getProperty(groupOrArray, 'members').indexOf(leObj);
						}
					}
					else
					{
						if(onError != null) onError('getObjectOrder: Group $group doesn\'t exist!');
						return -1;
					}
				}
				return getFallbackContainer().members.indexOf(leObj);
			}
			if(onError != null) onError('getObjectOrder: Object $obj doesn\'t exist!');
			return -1;
		});
		Lua_helper.add_callback(lua, "setObjectOrder", function(obj:String, position:Int, ?group:String = null) {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			if(leObj != null)
			{
				if(group != null)
				{
					var groupOrArray:Dynamic = Reflect.getProperty(getGroupSource(), group);
					if(groupOrArray != null)
					{
						switch(Type.typeof(groupOrArray))
						{
							case TClass(Array):
								groupOrArray.remove(leObj);
								groupOrArray.insert(position, leObj);
							default:
								groupOrArray.remove(leObj, true);
								groupOrArray.insert(position, leObj);
						}
					}
					else if(onError != null) onError('setObjectOrder: Group $group doesn\'t exist!');
				}
				else
				{
					var container:Dynamic = getFallbackContainer();
					container.remove(leObj, true);
					container.insert(position, leObj);
				}
				return;
			}
			if(onError != null) onError('setObjectOrder: Object $obj doesn\'t exist!');
		});
	}

	public static function registerSpriteFunctions(lua:State)
	{
		Lua_helper.add_callback(lua, "makeLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
				leSprite.loadGraphic(Paths.image(image));
			MusicBeatState.getVariables().set(tag, leSprite);
			leSprite.active = true;
		});
		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = 'auto') {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
				LuaUtils.loadFrames(leSprite, image, spriteType);
			MusicBeatState.getVariables().set(tag, leSprite);
		});
		Lua_helper.add_callback(lua, "luaSpriteExists", function(tag:String) {
			var obj = MusicBeatState.getVariables().get(tag);
			return (obj != null && (Std.isOfType(obj, ModchartSprite) || Std.isOfType(obj, ModchartAnimateSprite)));
		});
		Lua_helper.add_callback(lua, "makeGraphic", function(obj:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF') {
			var spr:FlxSprite = LuaUtils.getObjectDirectly(obj);
			if(spr != null) spr.makeGraphic(width, height, CoolUtil.colorFromString(color));
		});
		Lua_helper.add_callback(lua, "loadGraphic", function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			var animated = gridX != 0 || gridY != 0;
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && image != null && image.length > 0)
				spr.loadGraphic(Paths.image(image), animated, gridX, gridY);
		});
		Lua_helper.add_callback(lua, "loadFrames", function(variable:String, image:String, spriteType:String = 'auto') {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && image != null && image.length > 0)
				LuaUtils.loadFrames(spr, image, spriteType);
		});
		Lua_helper.add_callback(lua, "loadMultipleFrames", function(variable:String, images:Array<String>) {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && images != null && images.length > 0)
				spr.frames = Paths.getMultiAtlas(images);
		});
	}

	public static function registerTweenFunctions(lua:State, notify:(String, Array<Dynamic>)->Void, ?onError:String->Void)
	{
		function tweenEngine(tag:String, vars:String, tweenValue:Any, duration:Float, ease:String, funcName:String):Dynamic
		{
			if(states.PlayState.instance != null && states.PlayState.instance.skipInstantTweens) duration = 0.001;
			var target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			var variables = MusicBeatState.getVariables();
			if(target != null)
			{
				if(tag != null)
				{
					var originalTag:String = tag;
					tag = LuaUtils.formatVariable('tween_$tag');
					variables.set(tag, FlxTween.tween(target, tweenValue, duration, {
						ease: LuaUtils.getTweenEaseByString(ease),
						onComplete: function(twn:FlxTween) {
							variables.remove(tag);
							notify('onTweenCompleted', [originalTag, vars]);
						}
					}));
					return tag;
				}
				else FlxTween.tween(target, tweenValue, duration, {ease: LuaUtils.getTweenEaseByString(ease)});
			}
			else if(onError != null) onError('$funcName: Couldnt find object: $vars');
			return null;
		}

		Lua_helper.add_callback(lua, "doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return tweenEngine(tag, vars, {x: value}, duration, ease, 'doTweenX');
		});
		Lua_helper.add_callback(lua, "doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return tweenEngine(tag, vars, {y: value}, duration, ease, 'doTweenY');
		});
		Lua_helper.add_callback(lua, "doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return tweenEngine(tag, vars, {angle: value}, duration, ease, 'doTweenAngle');
		});
		Lua_helper.add_callback(lua, "doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return tweenEngine(tag, vars, {alpha: value}, duration, ease, 'doTweenAlpha');
		});
		Lua_helper.add_callback(lua, "doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ?ease:String = 'linear') {
			if(states.PlayState.instance != null && states.PlayState.instance.skipInstantTweens) duration = 0.001;
			var target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if(target != null)
			{
				var curColor:FlxColor = target.color;
				curColor.alphaFloat = target.alpha;
				var variables = MusicBeatState.getVariables();
				if(tag != null)
				{
					var originalTag:String = tag;
					tag = LuaUtils.formatVariable('tween_$tag');
					variables.set(tag, FlxTween.color(target, duration, curColor, CoolUtil.colorFromString(targetColor), {
						ease: LuaUtils.getTweenEaseByString(ease),
						onComplete: function(twn:FlxTween) {
							variables.remove(tag);
							notify('onTweenCompleted', [originalTag, vars]);
						}
					}));
					return tag;
				}
				else FlxTween.color(target, duration, curColor, CoolUtil.colorFromString(targetColor), {ease: LuaUtils.getTweenEaseByString(ease)});
			}
			else if(onError != null) onError('doTweenColor: Couldnt find object: $vars');
			return null;
		});
		Lua_helper.add_callback(lua, "startTween", function(tag:String, vars:String, values:Any = null, duration:Float, ?options:Any = null) {
			if(states.PlayState.instance != null && states.PlayState.instance.skipInstantTweens) duration = 0.001;
			var target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if(target != null)
			{
				if(values != null)
				{
					var myOptions:LuaTweenOptions = LuaUtils.getLuaTween(options);
					if(tag != null)
					{
						var variables = MusicBeatState.getVariables();
						var originalTag:String = 'tween_' + LuaUtils.formatVariable(tag);
						variables.set(tag, FlxTween.tween(target, values, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
							onUpdate: function(twn:FlxTween) {
								if(myOptions.onUpdate != null) notify(myOptions.onUpdate, [originalTag, vars]);
							},
							onStart: function(twn:FlxTween) {
								if(myOptions.onStart != null) notify(myOptions.onStart, [originalTag, vars]);
							},
							onComplete: function(twn:FlxTween) {
								if(twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD) variables.remove(tag);
								if(myOptions.onComplete != null) notify(myOptions.onComplete, [originalTag, vars]);
							}
						} : null));
						return tag;
					}
					else
					{
						FlxTween.tween(target, values, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
							onUpdate: function(twn:FlxTween) {
								if(myOptions.onUpdate != null) notify(myOptions.onUpdate, [null, vars]);
							},
							onStart: function(twn:FlxTween) {
								if(myOptions.onStart != null) notify(myOptions.onStart, [null, vars]);
							},
							onComplete: function(twn:FlxTween) {
								if(myOptions.onComplete != null) notify(myOptions.onComplete, [null, vars]);
							}
						} : null);
					}
				}
				else if(onError != null) onError('startTween: No values on 2nd argument!');
			}
			else if(onError != null) onError('startTween: Couldnt find object: $vars');
			return null;
		});
		Lua_helper.add_callback(lua, "cancelTween", function(tag:String) LuaUtils.cancelTween(tag));
		Lua_helper.add_callback(lua, "runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			LuaUtils.cancelTimer(tag);
			var variables = MusicBeatState.getVariables();
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('timer_$tag');
			variables.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if(tmr.finished) variables.remove(tag);
				notify('onTimerCompleted', [originalTag, tmr.loops, tmr.loopsLeft]);
			}, loops));
			return tag;
		});
		Lua_helper.add_callback(lua, "cancelTimer", function(tag:String) LuaUtils.cancelTimer(tag));
	}

	static function resolveGroup(group:String, ?allowMaps:Bool = false):Dynamic
	{
		var split:Array<String> = group.split('.');
		if(split.length > 1) return LuaUtils.getPropertyLoop(split, false, allowMaps);
		return LuaUtils.getObjectDirectly(group, allowMaps);
	}

	public static function registerGroupFunctions(lua:State, ?onError:String->Void)
	{
		Lua_helper.add_callback(lua, "getPropertyFromGroup", function(group:String, index:Int, variable:Dynamic, ?allowMaps:Bool = false) {
			var groupOrArray:Dynamic = resolveGroup(group, allowMaps);
			if(groupOrArray != null)
			{
				switch(Type.typeof(groupOrArray))
				{
					case TClass(Array):
						var leArray:Dynamic = groupOrArray[index];
						if(leArray != null)
						{
							if(Type.typeof(variable) == ValueType.TInt)
								return leArray[variable];
							return LuaUtils.getGroupStuff(leArray, variable, allowMaps);
						}
						if(onError != null) onError('getPropertyFromGroup: Object #$index from group: $group doesn\'t exist!');

					default:
						return LuaUtils.getGroupStuff(groupOrArray.members[index], variable, allowMaps);
				}
			}
			else if(onError != null) onError('getPropertyFromGroup: Group/Array $group doesn\'t exist!');
			return null;
		});
		Lua_helper.add_callback(lua, "setPropertyFromGroup", function(group:String, index:Int, variable:Dynamic, value:Dynamic, ?allowMaps:Bool = false, ?allowInstances:Bool = false) {
			var groupOrArray:Dynamic = resolveGroup(group, allowMaps);
			if(groupOrArray != null)
			{
				var newValue:Dynamic = allowInstances ? ReflectionFunctions.parseInstances(value) : value;
				switch(Type.typeof(groupOrArray))
				{
					case TClass(Array):
						var leArray:Dynamic = groupOrArray[index];
						if(leArray != null)
						{
							if(Type.typeof(variable) == ValueType.TInt)
							{
								leArray[variable] = newValue;
								return value;
							}
							LuaUtils.setGroupStuff(leArray, variable, newValue, allowMaps);
						}
						else if(onError != null) onError('setPropertyFromGroup: Object #$index from group: $group doesn\'t exist!');

					default:
						LuaUtils.setGroupStuff(groupOrArray.members[index], variable, newValue, allowMaps);
				}
			}
			else if(onError != null) onError('setPropertyFromGroup: Group/Array $group doesn\'t exist!');
			return value;
		});
		Lua_helper.add_callback(lua, "addToGroup", function(group:String, tag:String, ?index:Int = -1) {
			var obj:FlxBasic = LuaUtils.getObjectDirectly(tag);
			if(obj == null || obj.destroy == null)
			{
				if(onError != null) onError('addToGroup: Object $tag is not valid!');
				return;
			}

			var groupOrArray:Dynamic = resolveGroup(group);
			if(groupOrArray == null)
			{
				if(onError != null) onError('addToGroup: Group/Array $group is not valid!');
				return;
			}

			if(index < 0)
			{
				switch(Type.typeof(groupOrArray))
				{
					case TClass(Array):
						groupOrArray.push(obj);

					default:
						groupOrArray.add(obj);
				}
			}
			else groupOrArray.insert(index, obj);
		});
		Lua_helper.add_callback(lua, "removeFromGroup", function(group:String, ?index:Int = -1, ?tag:String = null, ?destroy:Bool = true) {
			var obj:FlxBasic = null;
			if(tag != null)
			{
				obj = LuaUtils.getObjectDirectly(tag);
				if(obj == null || obj.destroy == null)
				{
					if(onError != null) onError('removeFromGroup: Object $tag is not valid!');
					return;
				}
			}

			var groupOrArray:Dynamic = resolveGroup(group);
			if(groupOrArray == null)
			{
				if(onError != null) onError('removeFromGroup: Group/Array $group is not valid!');
				return;
			}

			switch(Type.typeof(groupOrArray))
			{
				case TClass(Array):
					if(obj != null)
					{
						groupOrArray.remove(obj);
						if(destroy) obj.destroy();
					}
					else groupOrArray.remove(groupOrArray[index]);

				default:
					if(obj == null) obj = groupOrArray.members[index];
					if(obj == null) return;
					groupOrArray.remove(obj, true);
					if(destroy) obj.destroy();
			}
		});
	}

	public static function registerExtraTextFunctions(lua:State, ?onError:String->Void)
	{
		function getText(tag:String):FlxText
		{
			var split:Array<String> = tag.split('.');
			if(split.length > 1) return LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			return LuaUtils.getObjectDirectly(split[0]);
		}

		Lua_helper.add_callback(lua, "getTextFont", function(tag:String) {
			var obj:FlxText = getText(tag);
			if(obj != null) return obj.font;

			if(onError != null) onError('getTextFont: Object $tag doesn\'t exist!');
			return null;
		});
		Lua_helper.add_callback(lua, "getTextWidth", function(tag:String) {
			var obj:FlxText = getText(tag);
			if(obj != null) return obj.fieldWidth;

			if(onError != null) onError('getTextWidth: Object $tag doesn\'t exist!');
			return 0;
		});
		Lua_helper.add_callback(lua, "setTextHeight", function(tag:String, height:Float) {
			var obj:FlxText = getText(tag);
			if(obj != null)
			{
				obj.fieldHeight = height;
				return true;
			}
			if(onError != null) onError('setTextHeight: Object $tag doesn\'t exist!');
			return false;
		});
		Lua_helper.add_callback(lua, "setTextAutoSize", function(tag:String, value:Bool) {
			var obj:FlxText = getText(tag);
			if(obj != null)
			{
				obj.autoSize = value;
				return true;
			}
			if(onError != null) onError('setTextAutoSize: Object $tag doesn\'t exist!');
			return false;
		});
	}

	#if flxanimate
	public static function registerAnimateFunctions(lua:State)
	{
		Lua_helper.add_callback(lua, "makeFlxAnimateSprite", function(tag:String, ?x:Float = 0, ?y:Float = 0, ?loadFolder:String = null) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);

			var mySprite:ModchartAnimateSprite = new ModchartAnimateSprite(x, y);
			if(loadFolder != null) Paths.loadAnimateAtlas(mySprite, loadFolder);
			MusicBeatState.getVariables().set(tag, mySprite);
			mySprite.active = true;
		});
		Lua_helper.add_callback(lua, "loadAnimateAtlas", function(tag:String, folderOrImg:String, ?spriteJson:String = null, ?animationJson:String = null) {
			var spr:FlxAnimate = MusicBeatState.getVariables().get(tag);
			if(spr != null) Paths.loadAnimateAtlas(spr, folderOrImg, spriteJson, animationJson);
		});
		Lua_helper.add_callback(lua, "addAnimationBySymbol", function(tag:String, name:String, symbol:String, ?framerate:Float = 24, ?loop:Bool = false, ?matX:Float = 0, ?matY:Float = 0) {
			var obj:FlxAnimate = cast MusicBeatState.getVariables().get(tag);
			if(obj == null) return false;

			obj.anim.addBySymbol(name, symbol, framerate, loop, matX, matY);
			if(obj.anim.curSymbol == null)
			{
				var obj2:ModchartAnimateSprite = cast (obj, ModchartAnimateSprite);
				if(obj2 != null) obj2.playAnim(name, true);
				else obj.anim.play(name, true);
			}
			return true;
		});
		Lua_helper.add_callback(lua, "addAnimationBySymbolIndices", function(tag:String, name:String, symbol:String, ?indices:Any = null, ?framerate:Float = 24, ?loop:Bool = false, ?matX:Float = 0, ?matY:Float = 0) {
			var obj:FlxAnimate = cast MusicBeatState.getVariables().get(tag);
			if(obj == null) return false;

			if(indices == null)
				indices = [0];
			else if(Std.isOfType(indices, String))
			{
				var strIndices:Array<String> = cast (indices, String).trim().split(',');
				var myIndices:Array<Int> = [];
				for (i in 0...strIndices.length)
					myIndices.push(Std.parseInt(strIndices[i]));
				indices = myIndices;
			}

			obj.anim.addBySymbolIndices(name, symbol, indices, framerate, loop, matX, matY);
			if(obj.anim.curSymbol == null)
			{
				var obj2:ModchartAnimateSprite = cast (obj, ModchartAnimateSprite);
				if(obj2 != null) obj2.playAnim(name, true);
				else obj.anim.play(name, true);
			}
			return true;
		});
	}
	#end
}