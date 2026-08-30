package funkin.scripting;

#if LUA_ALLOWED

import flixel.FlxState;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import flixel.math.FlxMath;

import funkin.scripting.FunkinScript;
import funkin.scripting.FunkinScript.IFunkinScript;
import funkin.scripting.FunkinScript.FunkinLuaScript;
import funkin.scripting.LuaUtils;
import funkin.scripting.LuaUtils.LuaTweenOptions;
import funkin.scripting.ModchartSprite;
import funkin.scripting.CustomSubstate;
import funkin.scripting.ShaderFunctions;
import funkin.scripting.ReflectionFunctions;

import flixel.input.gamepad.FlxGamepadInputID;

import flixel.addons.display.FlxRuntimeShader;

#if DISCORD_ALLOWED
import funkin.util.Discord.DiscordClient;
#end
#if ACHIEVEMENTS_ALLOWED
import funkin.save.Achievements;
#end
#if TRANSLATIONS_ALLOWED
import funkin.data.Language;
#end

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
import funkin.scripting.HScript;
import funkin.scripting.HScript.HScriptInfos;
#end

class LuaCallbacks
{
	public static function registerCommon(lua:State, host:IFunkinScript)
	{
		Lua_helper.add_callback(lua, "switchStateWithStickers", function(stateName:String, ?mode:String, ?songName:String, ?difficulty:String) {
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
			return true;
		});
		Lua_helper.add_callback(lua, "isMusicPlaying", function() {
			return FlxG.sound.music != null && FlxG.sound.music.playing;
		});
		Lua_helper.add_callback(lua, "getScore", function(songName:String, diffIndex:Int) {
			return funkin.save.Highscore.getScore(songName, diffIndex);
		});
		Lua_helper.add_callback(lua, "getDifficultyName", function(index:Int) {
			if(index < 0 || index >= funkin.data.Difficulty.list.length) return 'normal';
			return funkin.data.Difficulty.list[index];
		});
		Lua_helper.add_callback(lua, "setVar", function(varName:String, value:Dynamic) {
			MusicBeatState.getVariables().set(varName, value);
			return value;
		});
		Lua_helper.add_callback(lua, "getVar", function(varName:String) {
			return MusicBeatState.getVariables().get(varName);
		});
		Lua_helper.add_callback(lua, "setProperty", function(variable:String, value:Dynamic, ?allowMaps:Bool = false, ?allowInstances:Bool = false) {
			var newValue:Dynamic = allowInstances ? ReflectionFunctions.parseInstances(value) : value;
			var split:Array<String> = variable.split('.');
			if(split.length > 1)
				LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split, true, allowMaps), split[split.length - 1], newValue, allowMaps);
			else
				LuaUtils.setVarInArray(MusicBeatState.getState(), variable, newValue, allowMaps);
			return value;
		});
		Lua_helper.add_callback(lua, "getProperty", function(variable:String, ?allowMaps:Bool = false) {
			var split:Array<String> = variable.split('.');
			if(split.length > 1)
				return LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split, true, allowMaps), split[split.length - 1], allowMaps);
			return LuaUtils.getVarInArray(MusicBeatState.getState(), variable, allowMaps);
		});
		Lua_helper.add_callback(lua, "instanceArg", function(instanceName:String, ?className:String = null) {
			var retStr:String = '##PSYCHLUA_STRINGTOOBJ::$instanceName';
			if(className != null) retStr += '::$className';
			return retStr;
		});
		Lua_helper.add_callback(lua, "setObjectCamera", function(obj:String, camera:String = 'game') {
			var split:Array<String> = obj.split('.');
			var object:FlxBasic = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				object = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(object != null) {
				object.cameras = [LuaUtils.cameraFromString(camera)];
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "screenCenter", function(obj:String, pos:String = 'xy') {
			var split:Array<String> = obj.split('.');
			var spr:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) {
				switch(pos.trim().toLowerCase()) {
					case 'x': spr.screenCenter(X);
					case 'y': spr.screenCenter(Y);
					default:  spr.screenCenter(XY);
				}
			}
		});
		Lua_helper.add_callback(lua, "setGraphicSize", function(obj:String, x:Float, y:Float = 0, updateHitbox:Bool = true) {
			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				poop = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(poop != null) {
				poop.setGraphicSize(x, y);
				if(updateHitbox) poop.updateHitbox();
			}
		});
		Lua_helper.add_callback(lua, "scaleObject", function(obj:String, x:Float, y:Float, updateHitbox:Bool = true) {
			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				poop = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(poop != null) {
				poop.scale.set(x, y);
				if(updateHitbox) poop.updateHitbox();
			}
		});
		Lua_helper.add_callback(lua, "updateHitbox", function(obj:String) {
			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				poop = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(poop != null) poop.updateHitbox();
		});
		Lua_helper.add_callback(lua, "setScrollFactor", function(obj:String, scrollX:Float, scrollY:Float) {
			var split:Array<String> = obj.split('.');
			var object:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				object = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(object != null)
				object.scrollFactor.set(scrollX, scrollY);
		});
		Lua_helper.add_callback(lua, "addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Float = 24, loop:Bool = true) {
			var obj:FlxSprite = cast LuaUtils.getObjectDirectly(obj);
			if(obj != null && obj.animation != null) {
				obj.animation.addByPrefix(name, prefix, framerate, loop);
				if(obj.animation.curAnim == null) {
					var dyn:Dynamic = cast obj;
					if(dyn.playAnim != null) dyn.playAnim(name, true);
					else dyn.animation.play(name, true);
				}
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "addAnimation", function(obj:String, name:String, frames:Any, framerate:Float = 24, loop:Bool = true) {
			return LuaUtils.addAnimByIndices(obj, name, null, frames, framerate, loop);
		});
		Lua_helper.add_callback(lua, "addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:Any, framerate:Float = 24, loop:Bool = false) {
			return LuaUtils.addAnimByIndices(obj, name, prefix, indices, framerate, loop);
		});
		Lua_helper.add_callback(lua, "playAnim", function(obj:String, name:String, ?forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if(obj.playAnim != null) {
				obj.playAnim(name, forced, reverse, startFrame);
				return true;
			} else {
				if(obj.anim != null) obj.anim.play(name, forced, reverse, startFrame);
				else obj.animation.play(name, forced, reverse, startFrame);
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "addOffset", function(obj:String, anim:String, x:Float, y:Float) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if(obj != null && obj.addOffset != null) {
				obj.addOffset(anim, x, y);
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "playMusic", function(sound:String, ?volume:Float = 1, ?loop:Bool = false) {
			FlxG.sound.playMusic(Paths.music(sound), volume, loop);
		});
		Lua_helper.add_callback(lua, "playSound", function(sound:String, ?volume:Float = 1, ?tag:String = null, ?loop:Bool = false) {
			if(tag != null && tag.length > 0) {
				var originalTag:String = tag;
				tag = LuaUtils.formatVariable('sound_$tag');
				var variables = MusicBeatState.getVariables();
				var oldSnd:FlxSound = variables.get(tag);
				if(oldSnd != null) {
					oldSnd.stop();
					oldSnd.destroy();
				}
				variables.set(tag, FlxG.sound.play(Paths.sound(sound), volume, loop, null, true, function() {
					if(!loop) variables.remove(tag);
					host.call('onSoundFinished', [originalTag]);
				}));
				return tag;
			}
			FlxG.sound.play(Paths.sound(sound), volume);
			return null;
		});
		Lua_helper.add_callback(lua, "stopSound", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.stop();
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) {
					snd.stop();
					MusicBeatState.getVariables().remove(tag);
				}
			}
		});
		Lua_helper.add_callback(lua, "pauseSound", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.pause();
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.pause();
			}
		});
		Lua_helper.add_callback(lua, "resumeSound", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.play();
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.play();
			}
		});
		Lua_helper.add_callback(lua, "FlxColor", function(color:String) return FlxColor.fromString(color));
		Lua_helper.add_callback(lua, "getColorFromString", function(color:String) return FlxColor.fromString(color));
		Lua_helper.add_callback(lua, "getColorFromHex", function(color:String) return FlxColor.fromString('#$color'));
		Lua_helper.add_callback(lua, "precacheImage", function(name:String, ?allowGPU:Bool = true) {
			Paths.image(name, allowGPU);
		});
		Lua_helper.add_callback(lua, "precacheSound", function(name:String) {
			Paths.sound(name);
		});
		Lua_helper.add_callback(lua, "precacheMusic", function(name:String) {
			Paths.music(name);
		});
		Lua_helper.add_callback(lua, "getBuildTarget", function() return LuaUtils.getBuildTarget());
		Lua_helper.add_callback(lua, "getMouseX", function() return FlxG.mouse.x);
		Lua_helper.add_callback(lua, "getMouseY", function() return FlxG.mouse.y);
		Lua_helper.add_callback(lua, "mouseClicked", function(?button:String = 'left') {
			switch(button.trim().toLowerCase()) {
				case 'middle': return FlxG.mouse.justPressedMiddle;
				case 'right':  return FlxG.mouse.justPressedRight;
			}
			return FlxG.mouse.justPressed;
		});
		Lua_helper.add_callback(lua, "mousePressed", function(?button:String = 'left') {
			switch(button.trim().toLowerCase()) {
				case 'middle': return FlxG.mouse.pressedMiddle;
				case 'right':  return FlxG.mouse.pressedRight;
			}
			return FlxG.mouse.pressed;
		});
		Lua_helper.add_callback(lua, "mouseReleased", function(?button:String = 'left') {
			switch(button.trim().toLowerCase()) {
				case 'middle': return FlxG.mouse.justReleasedMiddle;
				case 'right':  return FlxG.mouse.justReleasedRight;
			}
			return FlxG.mouse.justReleased;
		});
		Lua_helper.add_callback(lua, "keyboardJustPressed", function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		Lua_helper.add_callback(lua, "keyboardPressed", function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		Lua_helper.add_callback(lua, "keyboardReleased", function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));
		Lua_helper.add_callback(lua, "anyGamepadJustPressed", function(name:String) return FlxG.gamepads.anyJustPressed(name));
		Lua_helper.add_callback(lua, "anyGamepadPressed", function(name:String) FlxG.gamepads.anyPressed(name));
		Lua_helper.add_callback(lua, "anyGamepadReleased", function(name:String) return FlxG.gamepads.anyJustReleased(name));
		Lua_helper.add_callback(lua, "gamepadAnalogX", function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return 0.0;
			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		Lua_helper.add_callback(lua, "gamepadAnalogY", function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return 0.0;
			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		Lua_helper.add_callback(lua, "gamepadJustPressed", function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return false;
			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		Lua_helper.add_callback(lua, "gamepadPressed", function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return false;
			return Reflect.getProperty(controller.pressed, name) == true;
		});
		Lua_helper.add_callback(lua, "gamepadReleased", function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return false;
			return Reflect.getProperty(controller.justReleased, name) == true;
		});
		Lua_helper.add_callback(lua, "keyJustPressed", function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_P;
				case 'down': return Controls.instance.NOTE_DOWN_P;
				case 'up': return Controls.instance.NOTE_UP_P;
				case 'right': return Controls.instance.NOTE_RIGHT_P;
				default: return Controls.instance.justPressed(name);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "keyPressed", function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT;
				case 'down': return Controls.instance.NOTE_DOWN;
				case 'up': return Controls.instance.NOTE_UP;
				case 'right': return Controls.instance.NOTE_RIGHT;
				default: return Controls.instance.pressed(name);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "keyReleased", function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_R;
				case 'down': return Controls.instance.NOTE_DOWN_R;
				case 'up': return Controls.instance.NOTE_UP_R;
				case 'right': return Controls.instance.NOTE_RIGHT_R;
				default: return Controls.instance.justReleased(name);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "getPropertyFromClass", function(className:String, variable:String, ?allowMaps:Bool = false) {
			var split:Array<String> = variable.split('.');
			var obj:Dynamic = Type.resolveClass(className);
			if(obj != null) {
				for(i in 0...split.length)
					obj = LuaUtils.getVarInArray(obj, split[i], allowMaps);
			}
			return obj;
		});
		Lua_helper.add_callback(lua, "setPropertyFromClass", function(className:String, variable:String, value:Dynamic, ?allowMaps:Bool = false, ?allowInstances:Bool = false) {
			var newValue:Dynamic = allowInstances ? ReflectionFunctions.parseInstances(value) : value;
			var split:Array<String> = variable.split('.');
			var obj:Dynamic = Type.resolveClass(className);
			if(obj != null) {
				if(split.length > 1) {
					var lastObj:Dynamic = obj;
					for(i in 0...split.length - 1)
						lastObj = LuaUtils.getVarInArray(lastObj, split[i], allowMaps);
					LuaUtils.setVarInArray(lastObj, split[split.length - 1], newValue, allowMaps);
				} else {
					LuaUtils.setVarInArray(obj, variable, newValue, allowMaps);
				}
			}
			return value;
		});
		Lua_helper.add_callback(lua, "callMethod", function(funcOrObject:Dynamic, ?funcOrArgs:Dynamic = null, ?legacyArgs:Array<Dynamic> = null) {
			if(Std.isOfType(funcOrArgs, String))
			{
				var object:Dynamic = (funcOrObject == null) ? MusicBeatState.getState() : LuaUtils.getObjectDirectly(funcOrObject);
				if(object == null) return null;
				return ReflectionFunctions.callMethodFromObject(object, cast funcOrArgs, ReflectionFunctions.parseInstances(legacyArgs != null ? legacyArgs : []));
			}

			var funcToRun:String = cast funcOrObject;
			if(funcToRun == null) return null;

			var args:Array<Dynamic> = Std.isOfType(funcOrArgs, Array) ? cast funcOrArgs : [];
			var parent:Dynamic = MusicBeatState.getState();
			var split:Array<String> = funcToRun.split('.');
			var varParent:Dynamic = MusicBeatState.getVariables().get(split[0].trim());
			if(varParent != null)
			{
				split.shift();
				funcToRun = split.join('.').trim();
				parent = varParent;
			}

			if(funcToRun.length > 0)
				return ReflectionFunctions.callMethodFromObject(parent, funcToRun, ReflectionFunctions.parseInstances(args));
			return Reflect.callMethod(null, parent, ReflectionFunctions.parseInstances(args));
		});
		Lua_helper.add_callback(lua, "callMethodFromClass", function(className:String, funcToRun:String, ?args:Array<Dynamic> = null) {
			if(args == null) args = [];
			var myClass:Dynamic = Type.resolveClass(className);
			if(myClass == null || funcToRun == null) return null;
			return ReflectionFunctions.callMethodFromObject(myClass, funcToRun, ReflectionFunctions.parseInstances(args));
		});
		Lua_helper.add_callback(lua, "makeLuaText", function(tag:String, text:String, width:Int, x:Float, y:Float) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leText:flixel.text.FlxText = new flixel.text.FlxText(x, y, width, text, 16);
			leText.fieldWidth = width;
			MusicBeatState.getVariables().set(tag, leText);
		});
		Lua_helper.add_callback(lua, "setTextString", function(tag:String, text:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.text = text;
		});
		Lua_helper.add_callback(lua, "getTextString", function(tag:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) return obj.text;
			return null;
		});
		Lua_helper.add_callback(lua, "setTextSize", function(tag:String, size:Int) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.size = size;
		});
		Lua_helper.add_callback(lua, "getTextSize", function(tag:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) return obj.size;
			return 0;
		});
		Lua_helper.add_callback(lua, "setTextWidth", function(tag:String, width:Float) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.fieldWidth = width;
		});
		Lua_helper.add_callback(lua, "setTextBorder", function(tag:String, size:Float, color:String, ?style:String = 'outline') {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) {
				var borderStyle:flixel.text.FlxText.FlxTextBorderStyle = OUTLINE;
				switch(style.toLowerCase().trim()) {
					case 'shadow': borderStyle = SHADOW;
					case 'outline_fast': borderStyle = OUTLINE_FAST;
					case 'none': borderStyle = NONE;
				}
				obj.setBorderStyle(borderStyle, CoolUtil.colorFromString(color), size);
			}
		});
		Lua_helper.add_callback(lua, "setTextColor", function(tag:String, color:Dynamic) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) {
				if(Std.isOfType(color, Int))
					obj.color = cast(color, Int);
				else
					obj.color = CoolUtil.colorFromString(Std.string(color));
			}
		});
		Lua_helper.add_callback(lua, "setTextFont", function(tag:String, font:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.font = Paths.font(font);
		});
		Lua_helper.add_callback(lua, "setTextItalic", function(tag:String, italic:Bool) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.italic = italic;
		});
		Lua_helper.add_callback(lua, "setTextAlignment", function(tag:String, alignment:String = 'left') {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) {
				obj.alignment = switch(alignment.toLowerCase().trim()) {
					case 'center': CENTER;
					case 'right': RIGHT;
					case 'justify': JUSTIFY;
					default: LEFT;
				};
			}
		});
		Lua_helper.add_callback(lua, "luaTextExists", function(tag:String) {
			var obj = MusicBeatState.getVariables().get(tag);
			return (obj != null && Std.isOfType(obj, flixel.text.FlxText));
		});
		Lua_helper.add_callback(lua, "getPixelColor", function(obj:String, x:Int, y:Int) {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) return spr.pixels.getPixel32(x, y);
			return FlxColor.BLACK;
		});
		Lua_helper.add_callback(lua, "getMidpointX", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getMidpoint().x;
			return 0;
		});
		Lua_helper.add_callback(lua, "getMidpointY", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getMidpoint().y;
			return 0;
		});
		Lua_helper.add_callback(lua, "getScreenPositionX", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getScreenPosition(FlxG.camera).x;
			return 0;
		});
		Lua_helper.add_callback(lua, "getScreenPositionY", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getScreenPosition(FlxG.camera).y;
			return 0;
		});
		Lua_helper.add_callback(lua, "objectsOverlap", function(obj1:String, obj2:String) {
			var o1:FlxBasic = LuaUtils.getObjectDirectly(obj1);
			var o2:FlxBasic = LuaUtils.getObjectDirectly(obj2);
			return (o1 != null && o2 != null && FlxG.overlap(o1, o2));
		});
		Lua_helper.add_callback(lua, "setBlendMode", function(obj:String, blend:String = '') {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) {
				spr.blend = LuaUtils.blendModeFromString(blend);
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "cameraShake", function(camera:String, intensity:Float, duration:Float) {
			LuaUtils.cameraFromString(camera).shake(intensity, duration);
		});
		Lua_helper.add_callback(lua, "cameraFlash", function(camera:String, color:String, duration:Float, forced:Bool) {
			LuaUtils.cameraFromString(camera).flash(CoolUtil.colorFromString(color), duration, null, forced);
		});
		Lua_helper.add_callback(lua, "cameraFade", function(camera:String, color:String, duration:Float, forced:Bool, ?fadeOut:Bool = false) {
			LuaUtils.cameraFromString(camera).fade(CoolUtil.colorFromString(color), duration, fadeOut, null, forced);
		});
		Lua_helper.add_callback(lua, "setCameraScroll", function(x:Float, y:Float) FlxG.camera.scroll.set(x - FlxG.width / 2, y - FlxG.height / 2));
		Lua_helper.add_callback(lua, "addCameraScroll", function(?x:Float = 0, ?y:Float = 0) FlxG.camera.scroll.add(x, y));
		Lua_helper.add_callback(lua, "getCameraScrollX", function() return FlxG.camera.scroll.x + FlxG.width / 2);
		Lua_helper.add_callback(lua, "getCameraScrollY", function() return FlxG.camera.scroll.y + FlxG.height / 2);
		Lua_helper.add_callback(lua, "setCameraScrollX", function(x:Float) FlxG.camera.scroll.x = x);
		Lua_helper.add_callback(lua, "setCameraScrollY", function(y:Float) FlxG.camera.scroll.y = y);
		Lua_helper.add_callback(lua, "getCameraScrollRawX", function() return FlxG.camera.scroll.x);
		Lua_helper.add_callback(lua, "getCameraScrollRawY", function() return FlxG.camera.scroll.y);
		Lua_helper.add_callback(lua, "lerp", function(a:Float, b:Float, t:Float) return a + (b - a) * t);
		Lua_helper.add_callback(lua, "setCameraZoom", function(zoom:Float) FlxG.camera.zoom = zoom);
		Lua_helper.add_callback(lua, "getCameraZoom", function() return FlxG.camera.zoom);
		Lua_helper.add_callback(lua, "setMouseVisible", function(visible:Bool) FlxG.mouse.visible = visible);
		Lua_helper.add_callback(lua, "getMouseVisible", function() return FlxG.mouse.visible);
		#if HSCRIPT_ALLOWED
		Lua_helper.add_callback(lua, "runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			host.initHaxeModuleCode(codeToRun, varsToBring);
			if(host.hscript != null)
			{
				var retVal = host.hscript.call(funcToRun, funcArgs);
				if(retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
				else if(host.hscript.returnValue != null)
				{
					return host.hscript.returnValue;
				}
			}
			return null;
		});
		#end
	}
}

#end
