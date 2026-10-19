package funkin.scripting;

import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import funkin.scripting.LuaUtils.LuaTweenOptions;
import Type.ValueType;

class LuaSharedFunctions
{
	public static function registerFileAndSaveFunctions(lua:State, ?onError:String->Void)
	{
		var report:String->Void = (onError != null) ? onError : function(msg:String) trace(msg);

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
				report('saveFile: Error trying to save ' + path + ': ' + e);
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
				report('deleteFile: Error trying to delete ' + path + ': ' + e);
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
			report('initSaveData: Save file already initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "eraseSaveData", function(name:String) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				variables.get('save_$name').erase();
				return;
			}
			report('eraseSaveData: Save file not initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "flushSaveData", function(name:String) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				variables.get('save_$name').flush();
				return;
			}
			report('flushSaveData: Save file not initialized: ' + name);
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
			report('getDataFromSave: Save file not initialized: ' + name);
			return defaultValue;
		});
		Lua_helper.add_callback(lua, "setDataFromSave", function(name:String, field:String, value:Dynamic) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				Reflect.setField(variables.get('save_$name').data, field, value);
				return;
			}
			report('setDataFromSave: Save file not initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "getSave", function(key:String) {
			LuaUtils.warnDeprecated('getSave', 'initSaveData and getDataFromSave');
			if(FlxG.save.data != null) return Reflect.getProperty(FlxG.save.data, key);
			return null;
		});
		Lua_helper.add_callback(lua, "setSave", function(key:String, value:Dynamic) {
			LuaUtils.warnDeprecated('setSave', 'initSaveData and setDataFromSave');
			if(FlxG.save.data != null) Reflect.setProperty(FlxG.save.data, key, value);
		});
		Lua_helper.add_callback(lua, "flushSave", function() {
			LuaUtils.warnDeprecated('flushSave', 'flushSaveData');
			FlxG.save.flush();
		});
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
			LuaUtils.warnDeprecated('makeLuaSprite', 'createSprite');
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
				leSprite.loadGraphic(Paths.image(image));
			MusicBeatState.getVariables().set(tag, leSprite);
			leSprite.active = true;
		});
		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = 'auto') {
			LuaUtils.warnDeprecated('makeAnimatedLuaSprite', 'createSprite');
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

	public static function registerCreateFunctions(lua:State, place:FlxBasic->Bool->Null<Int>->Void, ?textCamera:Void->FlxCamera)
	{
		registerGradient(lua, place);
		Lua_helper.add_callback(lua, "createSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?options:Dynamic = null) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var sprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.trim().length > 0)
			{
				if(image.contains(',')) sprite.frames = Paths.getMultiAtlas([for (part in image.split(',')) part.trim()]);
				else if(LuaUtils.hasAtlas(image)) LuaUtils.loadFrames(sprite, image, 'auto');
				else sprite.loadGraphic(Paths.image(image));
			}
			sprite.active = true;
			applyCreateOptions(sprite, options);
			MusicBeatState.getVariables().set(tag, sprite);
			place(sprite, LuaUtils.option(options, 'front') == true, zIndexOption(options));
			return tag;
		});
		Lua_helper.add_callback(lua, "createText", function(tag:String, ?text:String = '', ?x:Float = 0, ?y:Float = 0, ?options:Dynamic = null) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var size:Null<Float> = LuaUtils.option(options, 'size');
			var width:Null<Float> = LuaUtils.option(options, 'width');
			var font:String = LuaUtils.option(options, 'font');
			var leText:FlxText = new FlxText(x, y, width != null ? width : 0, text, size != null ? Std.int(size) : 16);
			leText.setFormat(Paths.font(font != null && font.length > 0 ? font : 'vcr.ttf'), size != null ? Std.int(size) : 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			leText.borderSize = 2;
			leText.scrollFactor.set();
			if(textCamera != null && textCamera() != null) leText.cameras = [textCamera()];
			var height:Null<Float> = LuaUtils.option(options, 'height');
			if(height != null) leText.fieldHeight = height;
			var autoSize:Null<Bool> = LuaUtils.option(options, 'autoSize');
			if(autoSize != null) leText.autoSize = autoSize;
			var color:String = LuaUtils.option(options, 'color');
			if(color != null && color.length > 0) leText.color = CoolUtil.colorFromString(color);
			applyCreateOptions(leText, options);
			MusicBeatState.getVariables().set(tag, leText);
			place(leText, LuaUtils.option(options, 'front') != false, zIndexOption(options));
			return tag;
		});
	}

	static function registerGradient(lua:State, place:FlxBasic->Bool->Null<Int>->Void)
	{
		Lua_helper.add_callback(lua, "createGradient", function(tag:String, x:Float, y:Float, width:Int, height:Int, colors:Array<String>, ?options:Dynamic = null) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var parsed:Array<FlxColor> = [];
			if(colors != null) for (color in colors) parsed.push(CoolUtil.colorFromString(Std.string(color)));
			if(parsed.length < 2) parsed = [FlxColor.WHITE, FlxColor.BLACK];
			var angle:Null<Float> = LuaUtils.option(options, 'angle');
			var chunkSize:Null<Float> = LuaUtils.option(options, 'chunkSize');
			var interpolate:Null<Bool> = LuaUtils.option(options, 'interpolate');
			var sprite:ModchartSprite = new ModchartSprite(x, y);
			sprite.pixels = flixel.util.FlxGradient.createGradientBitmapData(Std.int(Math.max(1, width)), Std.int(Math.max(1, height)), parsed,
				chunkSize != null ? Std.int(Math.max(1, chunkSize)) : 1, angle != null ? Std.int(angle) : 90, interpolate != false);
			sprite.active = true;
			applyCreateOptions(sprite, options);
			MusicBeatState.getVariables().set(tag, sprite);
			place(sprite, LuaUtils.option(options, 'front') == true, zIndexOption(options));
			return tag;
		});
	}

	public static function applyCreateOptions(obj:FlxSprite, options:Dynamic)
	{
		if(options == null) return;
		var scrollX:Null<Float> = LuaUtils.option(options, 'scrollX');
		var scrollY:Null<Float> = LuaUtils.option(options, 'scrollY');
		if(scrollX != null || scrollY != null) obj.scrollFactor.set(scrollX != null ? scrollX : obj.scrollFactor.x, scrollY != null ? scrollY : obj.scrollFactor.y);
		var skewX:Null<Float> = LuaUtils.option(options, 'skewX');
		var skewY:Null<Float> = LuaUtils.option(options, 'skewY');
		if((skewX != null || skewY != null) && Std.isOfType(obj, flixel.addons.effects.FlxSkewedSprite))
			cast(obj, flixel.addons.effects.FlxSkewedSprite).skew.set(skewX != null ? skewX : 0, skewY != null ? skewY : 0);
		var alpha:Null<Float> = LuaUtils.option(options, 'alpha');
		if(alpha != null) obj.alpha = alpha;
		var scaleX:Null<Float> = LuaUtils.option(options, 'scaleX');
		var scaleY:Null<Float> = LuaUtils.option(options, 'scaleY');
		if(scaleX != null || scaleY != null)
		{
			obj.scale.set(scaleX != null ? scaleX : obj.scale.x, scaleY != null ? scaleY : obj.scale.y);
			obj.updateHitbox();
		}
		var camera:String = LuaUtils.option(options, 'camera');
		if(camera != null && camera.length > 0) obj.cameras = [LuaUtils.cameraFromString(camera)];
	}

	public static function zIndexOption(options:Dynamic):Null<Int>
	{
		var zIndex:Null<Float> = LuaUtils.option(options, 'zIndex');
		return zIndex != null ? Std.int(zIndex) : null;
	}

	public static function switchStateWithOptions(stateName:String, options:Dynamic, normal:String->Void, direct:String->Void)
	{
		var transition:String = LuaUtils.option(options, 'transition');
		switch(transition != null ? transition.toLowerCase() : 'fade')
		{
			case 'none' | 'direct':
				direct(stateName);
			case 'stickers' | 'sticker':
				switchStateWithStickers(stateName, LuaUtils.option(options, 'mode'), LuaUtils.option(options, 'song'), LuaUtils.option(options, 'difficulty'));
			default:
				normal(stateName);
		}
	}

	public static function switchStateWithStickers(stateName:String, ?mode:String, ?songName:String, ?difficulty:String)
	{
		if(stateName.toLowerCase() == 'playstate')
		{
			if(songName != null && songName != '')
			{
				var diff:String = (difficulty != null && difficulty != '') ? difficulty : 'normal';
				var diffIdx:Int = 0;
				for(i in 0...funkin.data.Difficulty.list.length)
					if(funkin.data.Difficulty.list[i].toLowerCase() == diff.toLowerCase()) { diffIdx = i; break; }
				var jsonName:String = Paths.formatToSongPath(songName) + '-' + Paths.formatToSongPath(diff);
				var folder:String = Paths.formatToSongPath(songName);
				if(funkin.data.Song.getChart(jsonName, folder) == null)
					jsonName = Paths.formatToSongPath(songName);
				funkin.data.Song.loadFromJson(jsonName, folder);
				funkin.game.states.PlayState.isStoryMode = false;
				funkin.game.states.PlayState.storyDifficulty = diffIdx;
			}
			if(funkin.game.states.PlayState.SONG != null)
				funkin.backend.MusicBeatState.switchStateWithStickers(new funkin.game.states.PlayState(), mode);
		}
		else
		{
			funkin.backend.MusicBeatState.switchStateWithStickersByName(stateName, mode);
		}
	}

	public static function registerTweenFunctions(lua:State, notify:(String, Array<Dynamic>)->Void, ?onError:String->Void)
	{
		function tweenEngine(tag:String, vars:String, tweenValue:Any, duration:Float, ease:String, funcName:String):Dynamic
		{
			if(funkin.game.states.PlayState.instance != null && funkin.game.states.PlayState.instance.skipInstantTweens) duration = 0.001;
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
		Lua_helper.add_callback(lua, "setCameraRotation", function(camera:String, angle:Float) {
			funkin.game.PsychCamera.setRotation(LuaUtils.cameraFromString(camera), angle);
		});
		Lua_helper.add_callback(lua, "getCameraRotation", function(camera:String) {
			return funkin.game.PsychCamera.getRotation(LuaUtils.cameraFromString(camera));
		});
		Lua_helper.add_callback(lua, "doTweenCameraRotation", function(tag:String, camera:String, angle:Float, duration:Float, ?ease:String = 'linear') {
			if(funkin.game.states.PlayState.instance != null && funkin.game.states.PlayState.instance.skipInstantTweens) duration = 0.001;

			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if(tag == null)
			{
				funkin.game.PsychCamera.tweenRotation(cam, angle, duration, LuaUtils.getTweenEaseByString(ease));
				return null;
			}

			LuaUtils.cancelTween(tag);
			var originalTag:String = tag;
			var variables = MusicBeatState.getVariables();
			tag = LuaUtils.formatVariable('tween_$tag');
			variables.set(tag, funkin.game.PsychCamera.tweenRotation(cam, angle, duration, LuaUtils.getTweenEaseByString(ease), function(twn:FlxTween) {
				variables.remove(tag);
				notify('onTweenCompleted', [originalTag, camera]);
			}));
			return tag;
		});
		Lua_helper.add_callback(lua, "doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ?ease:String = 'linear') {
			if(funkin.game.states.PlayState.instance != null && funkin.game.states.PlayState.instance.skipInstantTweens) duration = 0.001;
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
			if(funkin.game.states.PlayState.instance != null && funkin.game.states.PlayState.instance.skipInstantTweens) duration = 0.001;
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
						var tweenKey:String = originalTag;
						variables.set(tweenKey, FlxTween.tween(target, values, duration, myOptions != null ? {
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
								if(twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD) variables.remove(tweenKey);
								if(myOptions.onComplete != null) notify(myOptions.onComplete, [originalTag, vars]);
							}
						} : {onComplete: function(twn:FlxTween) variables.remove(tweenKey)}));
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