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

class LuaState extends MusicBeatState implements IFunkinScript
{
	public var lua:State = null;
	public var stateName:String;
	public var modDirectory:String;
	public var isInitialState:Bool = false;
	public var closed:Bool = false;
	public var lastCalledFunction:String = '';
	public var luaArray:Array<LuaStateScript> = [];
	public static var instance:LuaState = null;
	public var scriptName:String = '';
	public var luaDebugGroup:FlxTypedGroup<funkin.scripting.DebugLuaText>;
	public var displayTarget:flixel.group.FlxGroup = null;
	public function scriptTrace(text:String):Void
		addTextToDebug(text, FlxColor.RED);

	public function stop():Void
	{
		closed = true;
		if(lua != null)
		{
			Lua.close(lua);
			lua = null;
		}
	}

	override public function add(obj:FlxBasic):FlxBasic
	{
		if(displayTarget != null) return displayTarget.add(obj);
		return super.add(obj);
	}

	override public function remove(obj:FlxBasic, splice:Bool = false):FlxBasic
	{
		if(displayTarget != null) return displayTarget.remove(obj, splice);
		return super.remove(obj, splice);
	}

	override public function insert(position:Int, obj:FlxBasic):FlxBasic
	{
		if(displayTarget != null) return displayTarget.insert(position, obj);
		return super.insert(position, obj);
	}

	#if HSCRIPT_ALLOWED
	public var hscript:HScript = null;
	#end

	public function new(scriptPath:String, name:String, ?modDir:String)
	{
		super();
		this.stateName = name;
		this.modDirectory = modDir;

		if(modDirectory != null && modDirectory != '')
			Mods.currentModDirectory = modDirectory;

		lua = LuaL.newstate();
		LuaL.openlibs(lua);

		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('Function_StopLua', LuaUtils.Function_StopLua);
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);
		set('buildTarget', LuaUtils.getBuildTarget());
		set('currentModDirectory', Mods.currentModDirectory);
		set('stateName', name);

		LuaState.instance = this;
		this.scriptName = scriptPath;
		registerCallbacks();

		try {
			var result:Dynamic = LuaL.dofile(lua, scriptPath);
			var resultStr:String = Lua.tostring(lua, result);
			if(resultStr != null && result != 0) {
				trace('LuaState: Error loading $scriptPath\n$resultStr');
				lua = null;
				return;
			}
		} catch(e:Dynamic) {
			trace('LuaState: Exception loading $scriptPath: $e');
			lua = null;
			return;
		}

		Lua.getglobal(lua, 'isInitialState');
		if(Lua.type(lua, -1) == Lua.LUA_TFUNCTION) {
			var status:Int = Lua.pcall(lua, 0, 1, 0);
			if(status == Lua.LUA_OK) {
				var result:Dynamic = cast Convert.fromLua(lua, -1);
				if(result == true) isInitialState = true;
			}
			Lua.pop(lua, 1);
		} else {
			Lua.pop(lua, 1);
		}
	}

	public function registerCallbacks(?targetLua:State = null)
	{
		if(targetLua == null) targetLua = lua;
		var lua:State = targetLua;
		LuaSharedFunctions.registerFileAndSaveFunctions(lua);
		LuaCallbacks.registerCommon(lua, this);

		Lua_helper.add_callback(lua, "switchState", function(stateName:String) {
			if(stateName == 'PlayState' && funkin.game.states.PlayState.SONG != null) {
				FlxG.state.persistentUpdate = false;
				funkin.ui.states.LoadingState.loadAndSwitchState(new funkin.game.states.PlayState());
			} else {
				funkin.backend.MusicBeatState.switchStateByName(stateName);
			}
		});

		Lua_helper.add_callback(lua, "switchStateDirect", function(stateName:String) {
			if(stateName == 'PlayState' && funkin.game.states.PlayState.SONG != null) {
				FlxG.state.persistentUpdate = false;
				FlxTransitionableState.skipNextTransIn = true;
				funkin.ui.states.LoadingState.loadAndSwitchState(new funkin.game.states.PlayState());
			} else {
				funkin.backend.MusicBeatState.switchStateDirectByName(stateName);
			}
		});




		Lua_helper.add_callback(lua, "getSongsFromWeek", function(weekName:String) {
			var result:Array<String> = [];
			#if MODS_ALLOWED
			var weekPath = Paths.mods(Mods.currentModDirectory + '/weeks/' + weekName + '.json');
			if(FileSystem.exists(weekPath)) {
				var weekData:Dynamic = haxe.Json.parse(sys.io.File.getContent(weekPath));
				for(songData in cast(weekData.songs, Array<Dynamic>)) {
					result.push(songData[0]);
				}
			}
			#end
			return result;
		});

		Lua_helper.add_callback(lua, "getDifficulties", function() {
			return funkin.data.Difficulty.list;
		});


		Lua_helper.add_callback(lua, "loadSong", function(songName:String, ?difficulty:Dynamic = 'normal', ?folder:String = null) {
			var diffIdx:Int = 0;
			var resolvedDiff:String = 'normal';
			if(Std.isOfType(difficulty, Int)) {
				diffIdx = cast(difficulty, Int);
				if(diffIdx < 0 || diffIdx >= funkin.data.Difficulty.list.length) diffIdx = 0;
				if(funkin.data.Difficulty.list.length > 0)
					resolvedDiff = funkin.data.Difficulty.list[diffIdx];
			} else if(Std.isOfType(difficulty, String)) {
				resolvedDiff = cast(difficulty, String);
				var diffLower:String = resolvedDiff.toLowerCase();
				var idx:Int = -1;
				for(i in 0...funkin.data.Difficulty.list.length) {
					if(funkin.data.Difficulty.list[i].toLowerCase() == diffLower) { idx = i; break; }
				}
				if(idx >= 0) diffIdx = idx;
			}
			var songFolder:String = folder != null ? Paths.formatToSongPath(folder) : Paths.formatToSongPath(songName);
			var jsonName:String = Paths.formatToSongPath(songName) + '-' + Paths.formatToSongPath(resolvedDiff);
			var chartCheck = funkin.data.Song.getChart(jsonName, songFolder);
			if(chartCheck == null)
				jsonName = Paths.formatToSongPath(songName);
			if(funkin.data.Song.getChart(jsonName, songFolder) != null) {
					funkin.data.Song.loadFromJson(jsonName, songFolder);
					funkin.game.states.PlayState.isStoryMode = false;
					funkin.game.states.PlayState.storyDifficulty = diffIdx;
					funkin.game.states.PlayState.previousState = stateName;
					FlxG.state.persistentUpdate = false;
					if(FlxG.sound.music == null)
						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0, true);
					funkin.ui.states.LoadingState.loadAndSwitchState(new funkin.game.states.PlayState());
				}
		});

		Lua_helper.add_callback(lua, "songExists", function(songName:String, ?difficulty:Dynamic = null, ?folder:String = null):Bool {
			var songFolder:String = folder != null ? Paths.formatToSongPath(folder) : Paths.formatToSongPath(songName);
			if(difficulty != null) {
				var resolvedDiff:String = 'normal';
				if(Std.isOfType(difficulty, Int)) {
					var idx:Int = cast(difficulty, Int);
					if(idx >= 0 && idx < funkin.data.Difficulty.list.length)
						resolvedDiff = funkin.data.Difficulty.list[idx].toLowerCase();
				} else if(Std.isOfType(difficulty, String)) {
					resolvedDiff = cast(difficulty, String).toLowerCase();
				}
				var jsonName:String = Paths.formatToSongPath(songName) + '-' + resolvedDiff;
				if(funkin.data.Song.getChart(jsonName, songFolder) != null) return true;
			}
			return funkin.data.Song.getChart(Paths.formatToSongPath(songName), songFolder) != null;
		});

		Lua_helper.add_callback(lua, "getSongDifficulties", function(songName:String, ?folder:String = null):Array<String> {
			var result:Array<String> = [];
			#if MODS_ALLOWED
			var songFolder:String = folder != null ? Paths.formatToSongPath(folder) : Paths.formatToSongPath(songName);
			var dirPath:String = Paths.mods(Mods.currentModDirectory + '/data/' + songFolder + '/');
			if(FileSystem.exists(dirPath) && FileSystem.isDirectory(dirPath)) {
				var prefix:String = Paths.formatToSongPath(songName) + '-';
				for(file in FileSystem.readDirectory(dirPath)) {
					if(file.endsWith('.json')) {
						var base:String = file.substr(0, file.length - 5);
						if(base.startsWith(prefix))
							result.push(base.substr(prefix.length));
					}
				}
			}
			#end
			return result;
		});

		Lua_helper.add_callback(lua, "getCurrentSong", function():String {
			if(funkin.game.states.PlayState.SONG != null)
				return funkin.game.states.PlayState.SONG.song;
			return null;
		});

		Lua_helper.add_callback(lua, "getHighscore", function(songName:String, ?difficulty:Dynamic = 'normal'):Int {
			var diffIdx:Int = 0;
			if(Std.isOfType(difficulty, Int)) {
				diffIdx = cast(difficulty, Int);
				if(diffIdx < 0 || diffIdx >= funkin.data.Difficulty.list.length) diffIdx = 0;
			} else if(Std.isOfType(difficulty, String)) {
				var diffStr:String = cast(difficulty, String).toLowerCase();
				for(i in 0...funkin.data.Difficulty.list.length) {
					if(funkin.data.Difficulty.list[i].toLowerCase() == diffStr) { diffIdx = i; break; }
				}
			}
			return funkin.save.Highscore.getScore(songName, diffIdx);
		});

		Lua_helper.add_callback(lua, "getHighscoreRating", function(songName:String, ?difficulty:Dynamic = 'normal'):Float {
			var diffIdx:Int = 0;
			if(Std.isOfType(difficulty, Int)) {
				diffIdx = cast(difficulty, Int);
				if(diffIdx < 0 || diffIdx >= funkin.data.Difficulty.list.length) diffIdx = 0;
			} else if(Std.isOfType(difficulty, String)) {
				var diffStr:String = cast(difficulty, String).toLowerCase();
				for(i in 0...funkin.data.Difficulty.list.length) {
					if(funkin.data.Difficulty.list[i].toLowerCase() == diffStr) { diffIdx = i; break; }
				}
			}
			return funkin.save.Highscore.getRating(songName, diffIdx);
		});

		Lua_helper.add_callback(lua, "getHighscoreMisses", function(songName:String, ?difficulty:Dynamic = 'normal'):Int {
			var diffIdx:Int = 0;
			if(Std.isOfType(difficulty, Int)) {
				diffIdx = cast(difficulty, Int);
				if(diffIdx < 0 || diffIdx >= funkin.data.Difficulty.list.length) diffIdx = 0;
			} else if(Std.isOfType(difficulty, String)) {
				var diffStr:String = cast(difficulty, String).toLowerCase();
				for(i in 0...funkin.data.Difficulty.list.length) {
					if(funkin.data.Difficulty.list[i].toLowerCase() == diffStr) { diffIdx = i; break; }
				}
			}
			return funkin.save.Highscore.getMisses(songName, diffIdx);
		});

        Lua_helper.add_callback(lua, "resetState", function() {
			MusicBeatState.resetState();
		});
		Lua_helper.add_callback(lua, "openSubState", function(substate:Dynamic) {
			if(Std.isOfType(substate, String)) {
				var shortNames:Map<String, String> = [
					'EditorPickerSubstate' => 'funkin.editors.EditorPickerSubstate'
				];
				var resolved:String = shortNames.exists(substate) ? shortNames.get(substate) : substate;
				var cls = Type.resolveClass(resolved);
				if(cls != null) openSubState(Type.createInstance(cls, []));
			} else {
				openSubState(substate);
			}
		});
		Lua_helper.add_callback(lua, "closeSubState", function() {
			closeSubState();
		});



		LuaSharedFunctions.registerSpriteFunctions(lua);
		Lua_helper.add_callback(lua, "createInstance", function(variableToSave:String, className:String, ?args:Array<Dynamic>) {
			if (!Std.isOfType(args, Array)) args = [];
			variableToSave = variableToSave.trim().replace('.', '');
			if(MusicBeatState.getVariables().get(variableToSave) == null)
			{
				if(args == null) args = [];
				var myType:Dynamic = Type.resolveClass(className);

				if(myType == null)
				{
					trace('createInstance: Class $className not found');
					return false;
				}

				var obj:Dynamic = Type.createInstance(myType, ReflectionFunctions.parseInstances(args));
				if(obj != null)
					MusicBeatState.getVariables().set(variableToSave, obj);
				else
					trace('createInstance: Failed to create $variableToSave, arguments are possibly wrong.');

				return (obj != null);
			}
			else trace('createInstance: Variable $variableToSave is already being used and cannot be replaced!');
			return false;
		});
		Lua_helper.add_callback(lua, "addInstance", function(objectName:String, ?inFront:Bool = false) {
			var savedObj:Dynamic = MusicBeatState.getVariables().get(objectName);
			if(savedObj != null)
				LuaUtils.getTargetInstance().add(savedObj);
			else
				trace('addInstance: Can\'t add what doesn\'t exist~ ($objectName)');
		});
		Lua_helper.add_callback(lua, "addLuaSprite", function(tag:String, ?inFront:Bool = true) {
			var mySprite:FlxSprite = MusicBeatState.getVariables().get(tag);
			if(mySprite == null) return;
			add(mySprite);
		});
		Lua_helper.add_callback(lua, "removeLuaSprite", function(tag:String, destroy:Bool = true) {
			var obj:FlxSprite = LuaUtils.getObjectDirectly(tag);
			if(obj == null || obj.destroy == null) return;
			remove(obj, true);
			if(destroy) {
				MusicBeatState.getVariables().remove(tag);
				obj.destroy();
			}
		});

		LuaSharedFunctions.registerObjectOrderFunctions(lua, () -> MusicBeatState.getState(), () -> MusicBeatState.getState());


		LuaSharedFunctions.registerTweenFunctions(lua, (name, args) -> call(name, args));




		Lua_helper.add_callback(lua, "debugPrint", function(text:Dynamic = '', color:String = 'WHITE') {
			addTextToDebug(Std.string(text), CoolUtil.colorFromString(color));
		});

		#if MODS_ALLOWED
		Lua_helper.add_callback(lua, "getModSetting", function(saveTag:String, ?modName:String = null) {
			if(modName == null) modName = modDirectory;
			if(modName == null) return null;
			return LuaUtils.getModSetting(saveTag, modName);
		});
		#end






		Lua_helper.add_callback(lua, "addLuaText", function(tag:String, ?inFront:Bool = false) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) {
				add(obj);
				if(inFront) members.remove(obj);
				if(inFront) members.push(obj);
			}
		});
		Lua_helper.add_callback(lua, "removeLuaText", function(tag:String, destroy:Bool = true) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj == null) return;
			remove(obj, true);
			if(destroy) {
				MusicBeatState.getVariables().remove(tag);
				obj.destroy();
			}
		});


		Lua_helper.add_callback(lua, "flxRandomInt", function(min:Int, max:Int, ?exclude:Any = null) {
			var excludeArray:Array<Int> = exclude == null ? [] : exclude;
			return FlxG.random.int(min, max, excludeArray);
		});
		Lua_helper.add_callback(lua, "flxRandomFloat", function(min:Float, max:Float, ?exclude:Any = null) {
			var excludeArray:Array<Float> = exclude == null ? [] : exclude;
			return FlxG.random.float(min, max, excludeArray);
		});
		Lua_helper.add_callback(lua, "flxRandomBool", function(?chance:Float = 50) {
			return FlxG.random.bool(chance);
		});

		Lua_helper.add_callback(lua, "getColorFromName", function(color:String) return FlxColor.fromString(color));

		Lua_helper.add_callback(lua, "getGraphicMidpointX", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getGraphicMidpoint().x;
			return 0;
		});
		Lua_helper.add_callback(lua, "getGraphicMidpointY", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getGraphicMidpoint().y;
			return 0;
		});

		Lua_helper.add_callback(lua, "luaSoundExists", function(tag:String) {
			var obj:FlxSound = MusicBeatState.getVariables().get('sound_$tag');
			return (obj != null && Std.isOfType(obj, FlxSound));
		});

		Lua_helper.add_callback(lua, "soundFadeIn", function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.fadeIn(duration, fromValue, toValue);
			}
		});
		Lua_helper.add_callback(lua, "soundFadeOut", function(tag:String, duration:Float, toValue:Float = 0) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.fadeOut(duration, toValue);
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.fadeOut(duration, toValue);
			}
		});
		Lua_helper.add_callback(lua, "soundFadeCancel", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null && FlxG.sound.music.fadeTween != null)
					FlxG.sound.music.fadeTween.cancel();
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null && snd.fadeTween != null) snd.fadeTween.cancel();
			}
		});
		Lua_helper.add_callback(lua, "getSoundVolume", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) return FlxG.sound.music.volume;
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) return snd.volume;
			}
			return 0;
		});
		Lua_helper.add_callback(lua, "setSoundVolume", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.volume = value;
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.volume = value;
			}
		});
		Lua_helper.add_callback(lua, "getSoundTime", function(tag:String) {
			if(tag == null || tag.length < 1)
				return FlxG.sound.music != null ? FlxG.sound.music.time : 0;
			tag = LuaUtils.formatVariable('sound_$tag');
			var snd:FlxSound = MusicBeatState.getVariables().get(tag);
			return snd != null ? snd.time : 0;
		});
		Lua_helper.add_callback(lua, "setSoundTime", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.time = value;
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.time = value;
			}
		});
		Lua_helper.add_callback(lua, "getSoundPitch", function(tag:String) {
			#if FLX_PITCH
			tag = LuaUtils.formatVariable('sound_$tag');
			var snd:FlxSound = MusicBeatState.getVariables().get(tag);
			return snd != null ? snd.pitch : 1;
			#else
			return 1;
			#end
		});
		Lua_helper.add_callback(lua, "setSoundPitch", function(tag:String, value:Float, ?doPause:Bool = false) {
			#if FLX_PITCH
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					var wasResumed:Bool = FlxG.sound.music.playing;
					if(doPause) FlxG.sound.music.pause();
					FlxG.sound.music.pitch = value;
					if(doPause && wasResumed) FlxG.sound.music.play();
				}
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) {
					var wasResumed:Bool = snd.playing;
					if(doPause) snd.pause();
					snd.pitch = value;
					if(doPause && wasResumed) snd.play();
				}
			}
			#end
		});

		Lua_helper.add_callback(lua, "doTweenZoom", function(tag:String, camera:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			var cam:FlxCamera = FlxG.camera;
			var camObj:Dynamic = MusicBeatState.getVariables().get(camera);
			if(camObj != null && Std.isOfType(camObj, FlxCamera)) cam = cast camObj;
			var variables = MusicBeatState.getVariables();
			if(tag != null) {
				var originalTag:String = tag;
				tag = LuaUtils.formatVariable('tween_$tag');
				variables.set(tag, FlxTween.tween(cam, {zoom: value}, duration, {
					ease: LuaUtils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						variables.remove(tag);
						call('onTweenCompleted', [originalTag, camera]);
					}
				}));
				return tag;
			} else {
				FlxTween.tween(cam, {zoom: value}, duration, {ease: LuaUtils.getTweenEaseByString(ease)});
			}
			return null;
		});

		Lua_helper.add_callback(lua, "setReturnState", function(stateName:String) {
			PlayState.returnAfterSongState = stateName;
		});
		Lua_helper.add_callback(lua, "getReturnState", function() {
			return PlayState.returnAfterSongState;
		});

		Lua_helper.add_callback(lua, "close", function() {
			closed = true;
		});

		LuaSharedFunctions.registerGroupFunctions(lua, luaTrace);
		LuaSharedFunctions.registerExtraTextFunctions(lua, luaTrace);
		#if flxanimate
		LuaSharedFunctions.registerAnimateFunctions(lua);
		#end

		Lua_helper.add_callback(lua, "getSongPosition", function() return Conductor.songPosition);

		Lua_helper.add_callback(lua, "startVideo", function(videoFile:String, ?canSkip:Bool = true, ?forMidSong:Bool = false, ?shouldLoop:Bool = false, ?playOnLoad:Bool = true) {
			#if VIDEOS_ALLOWED
			if(!FileSystem.exists(Paths.video(videoFile)))
			{
				luaTrace('startVideo: Video file not found: $videoFile');
				return false;
			}

			var variables = MusicBeatState.getVariables();
			var oldVideo:funkin.graphics.VideoSprite = variables.get('videoCutscene');
			if(oldVideo != null)
			{
				remove(oldVideo);
				oldVideo.destroy();
				variables.remove('videoCutscene');
			}

			var video:funkin.graphics.VideoSprite = new funkin.graphics.VideoSprite(Paths.video(videoFile), forMidSong, canSkip, shouldLoop);
			video.finishCallback = function() {
				variables.remove('videoCutscene');
				call('onVideoFinished', [videoFile]);
			};
			video.onSkip = function() call('onVideoSkipped', [videoFile]);
			add(video);
			variables.set('videoCutscene', video);
			if(playOnLoad) video.play();
			return true;
			#else
			luaTrace('startVideo: Videos are not supported on this platform!');
			return false;
			#end
		});

		var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();

		Lua_helper.add_callback(lua, "initLuaShader", function(name:String) {
			if(!ClientPrefs.data.shaders) return false;
			#if MODS_ALLOWED
			if(runtimeShaders.exists(name)) {
				var shaderData:Array<String> = runtimeShaders.get(name);
				if(shaderData != null && (shaderData[0] != null || shaderData[1] != null))
					return true;
			}
			var foldersToCheck:Array<String> = [Paths.getRoutedSharedPath('shaders/')];
			foldersToCheck.push(Paths.mods('shaders/'));
			foldersToCheck.push(Paths.mods('content/shaders/'));
			if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			{
				foldersToCheck.insert(0, Paths.mods(Mods.currentModDirectory + '/shaders/'));
				foldersToCheck.insert(0, Paths.mods(Mods.currentModDirectory + '/content/shaders/'));
			}
			for(mod in Mods.getGlobalMods())
			{
				foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
				foldersToCheck.insert(0, Paths.mods(mod + '/content/shaders/'));
			}
			for(folder in foldersToCheck) {
				if(FileSystem.exists(folder)) {
					var frag:String = folder + name + '.frag';
					var vert:String = folder + name + '.vert';
					var found:Bool = false;
					if(FileSystem.exists(frag)) { frag = File.getContent(frag); found = true; } else frag = null;
					if(FileSystem.exists(vert)) { vert = File.getContent(vert); found = true; } else vert = null;
					if(found) { runtimeShaders.set(name, [frag, vert]); return true; }
				}
			}
			#end
			return false;
		});
		Lua_helper.add_callback(lua, "setSpriteShader", function(obj:String, shader:String) {
			if(!ClientPrefs.data.shaders) return false;
			if(!runtimeShaders.exists(shader)) return false;
			#if (!flash && MODS_ALLOWED && sys)
			if(ShaderFunctions.isCamera(obj)) {
				var cam:FlxCamera = ShaderFunctions.getCameraByName(obj);
				var arr:Array<String> = runtimeShaders.get(shader);
				var rShader:FlxRuntimeShader = new funkin.graphics.shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
				ShaderFunctions.cameraShaders.set(obj, rShader);
				cam.setFilters([new openfl.filters.ShaderFilter(cast rShader)]);
				return true;
			}
			#end
			var split:Array<String> = obj.split('.');
			var leObj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				leObj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(leObj != null) {
				var arr:Array<String> = runtimeShaders.get(shader);
				leObj.shader = new funkin.graphics.shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "removeSpriteShader", function(obj:String) {
			#if (!flash && MODS_ALLOWED && sys)
			if(ShaderFunctions.isCamera(obj)) {
				var cam:FlxCamera = ShaderFunctions.getCameraByName(obj);
				ShaderFunctions.cameraShaders.remove(obj);
				cam.setFilters([]);
				return true;
			}
			#end
			var split:Array<String> = obj.split('.');
			var leObj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				leObj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(leObj != null) { leObj.shader = null; return true; }
			return false;
		});
		Lua_helper.add_callback(lua, "setShaderFloat", function(obj:String, prop:String, value:Float) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			shader.setFloat(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderFloat", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			return shader == null ? null : shader.getFloat(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderInt", function(obj:String, prop:String, value:Int) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			shader.setInt(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderInt", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			return shader == null ? null : shader.getInt(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderBool", function(obj:String, prop:String, value:Bool) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			shader.setBool(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderBool", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			return shader == null ? null : shader.getBool(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderFloatArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			shader.setFloatArray(prop, values);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderFloatArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) { trace('getShaderFloatArray: Shader is not FlxRuntimeShader!'); return null; }
			return shader.getFloatArray(prop);
			#else
			trace('getShaderFloatArray: Platform unsupported for Runtime Shaders!');
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderIntArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			shader.setIntArray(prop, values);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderIntArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) { trace('getShaderIntArray: Shader is not FlxRuntimeShader!'); return null; }
			return shader.getIntArray(prop);
			#else
			trace('getShaderIntArray: Platform unsupported for Runtime Shaders!');
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderBoolArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			shader.setBoolArray(prop, values);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderBoolArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) { trace('getShaderBoolArray: Shader is not FlxRuntimeShader!'); return null; }
			return shader.getBoolArray(prop);
			#else
			trace('getShaderBoolArray: Platform unsupported for Runtime Shaders!');
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderSampler2D", function(obj:String, prop:String, bitmapdataPath:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			var value = Paths.image(bitmapdataPath);
			if(value != null && value.bitmap != null) { shader.setSampler2D(prop, value.bitmap); return true; }
			return false;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShader", function(camera:String, shader:String) {
			if(!ClientPrefs.data.shaders) return false;
			if(!runtimeShaders.exists(shader)) return false;
			#if (!flash && MODS_ALLOWED && sys)
			var cam:FlxCamera = ShaderFunctions.getCameraByName(camera);
			var arr:Array<String> = runtimeShaders.get(shader);
			var rShader:FlxRuntimeShader = new funkin.graphics.shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
			ShaderFunctions.cameraShaders.set(camera, rShader);
			cam.setFilters([new openfl.filters.ShaderFilter(cast rShader)]);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "removeCameraShader", function(camera:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var cam:FlxCamera = ShaderFunctions.getCameraByName(camera);
			ShaderFunctions.cameraShaders.remove(camera);
			cam.setFilters([]);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderFloat", function(camera:String, prop:String, value:Float) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			if(shader == null) return false;
			shader.setFloat(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getCameraShaderFloat", function(camera:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			return shader == null ? null : shader.getFloat(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderInt", function(camera:String, prop:String, value:Int) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			if(shader == null) return false;
			shader.setInt(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getCameraShaderInt", function(camera:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			return shader == null ? null : shader.getInt(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderBool", function(camera:String, prop:String, value:Bool) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			if(shader == null) return false;
			shader.setBool(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getCameraShaderBool", function(camera:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			return shader == null ? null : shader.getBool(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderFloatArray", function(camera:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			if(shader == null) return false;
			shader.setFloatArray(prop, values);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderSampler2D", function(camera:String, prop:String, bitmapdataPath:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			if(shader == null) return false;
			var value = Paths.image(bitmapdataPath);
			if(value != null && value.bitmap != null) { shader.setSampler2D(prop, value.bitmap); return true; }
			return false;
			#else
			return false;
			#end
		});

		Lua_helper.add_callback(lua, "getRunningScripts", function() {
			var result:Array<String> = [stateName];
			if(PlayState.instance != null)
				for(script in PlayState.instance.luaArray)
					result.push(script.scriptName);
			return result;
		});
		Lua_helper.add_callback(lua, "setOnScripts", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			set(varName, arg);
			if(PlayState.instance != null)
				PlayState.instance.setOnScripts(varName, arg, exclusions);
		});
		Lua_helper.add_callback(lua, "setOnHScript", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			#if HSCRIPT_ALLOWED
			if(hscript != null) hscript.set(varName, arg);
			#end
			if(PlayState.instance != null)
				PlayState.instance.setOnHScript(varName, arg, exclusions);
		});
		Lua_helper.add_callback(lua, "setOnLuas", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			set(varName, arg);
			if(PlayState.instance != null)
				PlayState.instance.setOnLuas(varName, arg, exclusions);
		});
		Lua_helper.add_callback(lua, "callOnScripts", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops:Bool = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(args == null) args = [];
			if(excludeScripts == null) excludeScripts = [];
			if(PlayState.instance != null)
				return PlayState.instance.callOnScripts(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return call(funcName, args);
		});
		Lua_helper.add_callback(lua, "callOnLuas", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops:Bool = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(args == null) args = [];
			if(excludeScripts == null) excludeScripts = [];
			if(PlayState.instance != null)
				return PlayState.instance.callOnLuas(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return call(funcName, args);
		});
		Lua_helper.add_callback(lua, "callOnHScript", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops:Bool = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(args == null) args = [];
			if(excludeScripts == null) excludeScripts = [];
			if(PlayState.instance != null)
				return PlayState.instance.callOnHScript(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return LuaUtils.Function_Continue;
		});
		Lua_helper.add_callback(lua, "callScript", function(luaFile:String, funcName:String, ?args:Array<Dynamic> = null) {
			if(args == null) args = [];
			if(PlayState.instance != null) {
				for(luaInstance in PlayState.instance.luaArray)
					if(luaInstance.scriptName == luaFile)
						return luaInstance.call(funcName, args);
			} else if(LuaState.instance != null) {
				for(luaInstance in LuaState.instance.luaArray)
					if(luaInstance.scriptName == luaFile)
						return luaInstance.call(funcName, args);
			}
			return null;
		});
		Lua_helper.add_callback(lua, "isRunning", function(scriptFile:String) {
			if(PlayState.instance != null) {
				for(luaInstance in PlayState.instance.luaArray)
					if(luaInstance.scriptName == scriptFile)
						return true;
				#if HSCRIPT_ALLOWED
				for(hscriptInstance in PlayState.instance.hscriptArray)
					if(hscriptInstance.origin == scriptFile)
						return true;
				#end
			}
			return (lua != null && !closed);
		});
		Lua_helper.add_callback(lua, "addLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) {
			var resolvedFile:String = resolveLuaScriptPath(luaFile);
			if(PlayState.instance != null) {
				if(!ignoreAlreadyRunning)
					for(luaInstance in PlayState.instance.luaArray)
						if(luaInstance.scriptName == resolvedFile) return;
				new FunkinLua(resolvedFile);
			} else if(LuaState.instance != null) {
				if(!ignoreAlreadyRunning)
					for(luaInstance in LuaState.instance.luaArray)
						if(luaInstance.scriptName == resolvedFile) return;
				var newScript = new LuaStateScript(resolvedFile, LuaState.instance.modDirectory);
				LuaState.instance.luaArray.push(newScript);
			}
		});
		Lua_helper.add_callback(lua, "addHScript", function(scriptFile:String, ?ignoreAlreadyRunning:Bool = false) {
			#if HSCRIPT_ALLOWED
			var resolvedFile:String = resolveHScriptPath(scriptFile);
			if(PlayState.instance != null) {
				if(!ignoreAlreadyRunning)
					for(script in PlayState.instance.hscriptArray)
						if(script.origin == resolvedFile) return;
				PlayState.instance.initHScript(resolvedFile);
			}
			#end
		});
		Lua_helper.add_callback(lua, "removeLuaScript", function(luaFile:String) {
			if(PlayState.instance != null) {
				for(luaInstance in PlayState.instance.luaArray) {
					if(luaInstance.scriptName == luaFile) {
						luaInstance.stop();
						return true;
					}
				}
			}
			return false;
		});
		Lua_helper.add_callback(lua, "removeHScript", function(scriptFile:String) {
			#if HSCRIPT_ALLOWED
			if(PlayState.instance != null) {
				for(script in PlayState.instance.hscriptArray) {
					if(script.origin == scriptFile) {
						script.destroy();
						return true;
					}
				}
			}
			#end
			return false;
		});
		Lua_helper.add_callback(lua, "stringStartsWith", function(str:String, start:String) {
			return str.startsWith(start);
		});
		Lua_helper.add_callback(lua, "stringEndsWith", function(str:String, end:String) {
			return str.endsWith(end);
		});
		Lua_helper.add_callback(lua, "stringSplit", function(str:String, split:String) {
			return str.split(split);
		});
		Lua_helper.add_callback(lua, "stringTrim", function(str:String) {
			return str.trim();
		});
		Lua_helper.add_callback(lua, "getRandomBool", function(chance:Float = 50) {
			return FlxG.random.bool(chance);
		});
		Lua_helper.add_callback(lua, "getRandomFloat", function(min:Float, max:Float = 1, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Float> = [];
			for(i in 0...excludeArray.length) {
				if(exclude == '') break;
				toExclude.push(Std.parseFloat(excludeArray[i].trim()));
			}
			return FlxG.random.float(min, max, toExclude);
		});
		Lua_helper.add_callback(lua, "getRandomInt", function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Int> = [];
			for(i in 0...excludeArray.length) {
				if(exclude == '') break;
				toExclude.push(Std.parseInt(excludeArray[i].trim()));
			}
			return FlxG.random.int(min, max, toExclude);
		});
		Lua_helper.add_callback(lua, "openCustomSubstate", function(name:String, ?pauseGame:Bool = false) {
			if(pauseGame) {
				persistentUpdate = false;
				persistentDraw = true;
				if(FlxG.sound.music != null)
					FlxG.sound.music.pause();
			}
			openSubState(new LuaStateCustomSubstate(name, this));
		});
		Lua_helper.add_callback(lua, "closeCustomSubstate", function() {
			if(LuaStateCustomSubstate.instance != null) {
				closeSubState();
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "insertToCustomSubstate", function(tag:String, ?pos:Int = -1) {
			if(LuaStateCustomSubstate.instance != null) {
				var tagObject:FlxObject = cast(MusicBeatState.getVariables().get(tag), FlxObject);
				if(tagObject != null) {
					if(pos < 0) LuaStateCustomSubstate.instance.add(tagObject);
					else LuaStateCustomSubstate.instance.insert(pos, tagObject);
					return true;
				}
			}
			return false;
		});
		#if DISCORD_ALLOWED
		Lua_helper.add_callback(lua, "changeDiscordPresence", DiscordClient.changePresence);
		Lua_helper.add_callback(lua, "changeDiscordClientID", function(?newID:String) {
			if(newID == null) DiscordClient.resetClientID();
			else DiscordClient.clientID = newID;
		});
		#end
		#if ACHIEVEMENTS_ALLOWED
		Lua_helper.add_callback(lua, "achievementExists", function(name:String) return Achievements.achievements.exists(name));
		Lua_helper.add_callback(lua, "getAchievementScore", function(name:String):Float {
			if(!Achievements.achievements.exists(name)) {
				trace('getAchievementScore: Couldnt find achievement: $name');
				return -1;
			}
			return Achievements.getScore(name);
		});
		Lua_helper.add_callback(lua, "setAchievementScore", function(name:String, ?value:Float = 0, ?saveIfNotUnlocked:Bool = true):Float {
			if(!Achievements.achievements.exists(name)) {
				trace('setAchievementScore: Couldnt find achievement: $name');
				return -1;
			}
			return Achievements.setScore(name, value, saveIfNotUnlocked);
		});
		Lua_helper.add_callback(lua, "addAchievementScore", function(name:String, ?value:Float = 1, ?saveIfNotUnlocked:Bool = true):Float {
			if(!Achievements.achievements.exists(name)) {
				trace('addAchievementScore: Couldnt find achievement: $name');
				return -1;
			}
			return Achievements.addScore(name, value, saveIfNotUnlocked);
		});
		Lua_helper.add_callback(lua, "unlockAchievement", function(name:String):Dynamic {
			if(!Achievements.achievements.exists(name)) {
				trace('unlockAchievement: Couldnt find achievement: $name');
				return null;
			}
			return Achievements.unlock(name);
		});
		Lua_helper.add_callback(lua, "isAchievementUnlocked", function(name:String):Dynamic {
			if(!Achievements.achievements.exists(name)) {
				trace('isAchievementUnlocked: Couldnt find achievement: $name');
				return null;
			}
			return Achievements.isUnlocked(name);
		});
		#end
		#if TRANSLATIONS_ALLOWED
		Lua_helper.add_callback(lua, "getTranslationPhrase", function(key:String, ?defaultPhrase:String, ?values:Array<Dynamic> = null) {
			return Language.getPhrase(key, defaultPhrase, values);
		});
		Lua_helper.add_callback(lua, "getFileTranslation", function(key:String) {
			return Language.getFileTranslation(key);
		});
		Lua_helper.add_callback(lua, "setTranslationPhrase", function(key:String, value:String) {
			Language.setPhrase(key, value);
		});
		Lua_helper.add_callback(lua, "setFileTranslation", function(key:String, value:String) {
			Language.setFileTranslation(key, value);
		});
		#end
		Lua_helper.add_callback(lua, "addCharacterToList", function(name:String, type:String) {
			if(PlayState.instance == null) return;
			var charType:Int = 0;
			switch(type.toLowerCase()) {
				case 'dad': charType = 1;
				case 'gf' | 'girlfriend': charType = 2;
			}
			PlayState.instance.addCharacterToList(name, charType);
		});
		Lua_helper.add_callback(lua, "getCharacterX", function(type:String) {
			if(PlayState.instance == null) return 0.0;
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent': return PlayState.instance.dadGroup.x;
				case 'gf' | 'girlfriend': return PlayState.instance.gfGroup.x;
				default: return PlayState.instance.boyfriendGroup.x;
			}
		});
		Lua_helper.add_callback(lua, "setCharacterX", function(type:String, value:Float) {
			if(PlayState.instance == null) return;
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent': PlayState.instance.dadGroup.x = value;
				case 'gf' | 'girlfriend': PlayState.instance.gfGroup.x = value;
				default: PlayState.instance.boyfriendGroup.x = value;
			}
		});
		Lua_helper.add_callback(lua, "getCharacterY", function(type:String) {
			if(PlayState.instance == null) return 0.0;
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent': return PlayState.instance.dadGroup.y;
				case 'gf' | 'girlfriend': return PlayState.instance.gfGroup.y;
				default: return PlayState.instance.boyfriendGroup.y;
			}
		});
		Lua_helper.add_callback(lua, "setCharacterY", function(type:String, value:Float) {
			if(PlayState.instance == null) return;
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent': PlayState.instance.dadGroup.y = value;
				case 'gf' | 'girlfriend': PlayState.instance.gfGroup.y = value;
				default: PlayState.instance.boyfriendGroup.y = value;
			}
		});
		Lua_helper.add_callback(lua, "characterDance", function(character:String) {
			if(PlayState.instance == null) return;
			switch(character.toLowerCase()) {
				case 'dad': PlayState.instance.dad.dance();
				case 'gf' | 'girlfriend':
					if(PlayState.instance.gf != null) PlayState.instance.gf.dance();
				default: PlayState.instance.boyfriend.dance();
			}
		});

		#if HSCRIPT_ALLOWED
		Lua_helper.add_callback(lua, "runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null):Dynamic {
			if(hscript != null)
			{
				var retVal = hscript.call(funcToRun, funcArgs);
				if(retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
			}
			else
			{
				var pos:HScriptInfos = cast {fileName: stateName, showLine: false, isLua: true};
				if(lastCalledFunction != '') pos.funcName = lastCalledFunction;
				Iris.error("runHaxeFunction: HScript has not been initialized yet! Use \"runHaxeCode\" to initialize it", pos);
			}
			return null;
		});
		Lua_helper.add_callback(lua, "addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			var str:String = '';
			if(libPackage.length > 0)
				str = libPackage + '.';
			else if(libName == null)
				libName = '';

			var c:Dynamic = Type.resolveClass(str + libName);
			if(c == null)
				c = Type.resolveEnum(str + libName);

			if(hscript == null)
				initHaxeModuleCode('', null);

			if(hscript != null)
			{
				var pos:HScriptInfos = cast {fileName: stateName, showLine: false, isLua: true};
				if(lastCalledFunction != '') pos.funcName = lastCalledFunction;

				try {
					if(c != null) hscript.set(libName, c);
				}
				catch(e:IrisError) {
					Iris.error(Printer.errorToString(e, false), pos);
				}
			}
		});
		#end
	}

	override function create()
	{
		if(modDirectory != null && modDirectory != '')
			Mods.currentModDirectory = modDirectory;

		persistentUpdate = true;
		super.create();

		luaDebugGroup = new FlxTypedGroup<funkin.scripting.DebugLuaText>();
		luaDebugGroup.cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		funkin.save.Highscore.load();
		call('onCreate', []);

		add(luaDebugGroup);
		call('onCreatePost', []);
		for(script in luaArray)
			script.call('onCreatePost', []);

		#if CHECK_FOR_UPDATES
		if(stateName.toLowerCase() == 'mainmenustate' && ClientPrefs.data.checkForUpdates
			&& funkin.ui.states.OutdatedSubState.updateVersion != null
			&& Std.parseFloat(funkin.ui.states.OutdatedSubState.updateVersion) > Std.parseFloat(funkin.ui.states.MainMenuState.muttEngineVersion))
		{
			persistentUpdate = false;
			openSubState(new funkin.ui.states.OutdatedSubState());
		}
		#end

	}

	override function closeSubState()
	{
		persistentUpdate = true;
		super.closeSubState();
		call('onCloseSubState', []);
	}

	override function update(elapsed:Float)
	{
		if(FlxG.sound.music != null && FlxG.sound.music.playing)
			Conductor.songPosition = FlxG.sound.music.time;

		super.update(elapsed);

		var _hasBlockingSubState:Bool = subState != null
			&& !Std.isOfType(subState, CustomFadeTransition)
			&& !Std.isOfType(subState, funkin.ui.states.ResetScoreSubState);

		if(!_hasBlockingSubState)
		{
			if(stateName.toLowerCase() == 'mainmenustate' && FlxG.keys.justPressed.TAB) {
				var sub = new funkin.modding.ModSelectorSubstate();
				sub._mouseWasVisible = FlxG.mouse.visible;
				FlxG.mouse.visible = false;
				openSubState(sub);
			}

			call('onUpdate', [elapsed]);
			for(script in luaArray)
				script.call('onUpdate', [elapsed]);

			call('onUpdatePost', [elapsed]);
			for(script in luaArray)
				script.call('onUpdatePost', [elapsed]);
		}
	}

		var lastStepHit:Int = -1;
		override function stepHit()
		{
			super.stepHit();

			if(curStep == lastStepHit)
				return;

			lastStepHit = curStep;
			set('curStep', curStep);
			call('onStepHit', []);
			for(script in luaArray)
			{
				script.set('curStep', curStep);
				script.call('onStepHit', []);
			}
			#if HSCRIPT_ALLOWED
			if(hscript != null && hscript.exists('onStepHit'))
			{
				hscript.set('curStep', curStep);
				hscript.call('onStepHit', []);
			}
			#end
		}

		var lastBeatHit:Int = -1;
		override function beatHit()
		{
			super.beatHit();

			if(curBeat == lastBeatHit)
				return;

			lastBeatHit = curBeat;
			set('curBeat', curBeat);
			call('onBeatHit', []);
			for(script in luaArray)
			{
				script.set('curBeat', curBeat);
				script.call('onBeatHit', []);
			}
			#if HSCRIPT_ALLOWED
			if(hscript != null && hscript.exists('onBeatHit'))
			{
				hscript.set('curBeat', curBeat);
				hscript.call('onBeatHit', []);
			}
			#end
		}

		override function destroy()
	{
		if(lua != null) {
			call('onDestroy', []);
			Lua.close(lua);
			lua = null;
		}
		for(script in luaArray)
			script.stop();
		luaArray = [];
		#if HSCRIPT_ALLOWED
		if(hscript != null)
		{
			hscript.destroy();
			hscript = null;
		}
		#end
		super.destroy();
	}

	public function call(func:String, args:Array<Dynamic>):Dynamic
	{
		if(closed || lua == null) return LuaUtils.Function_Continue;
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
				trace('LuaState error in $func: $error');
				return LuaUtils.Function_Continue;
			}
			var result:Dynamic = cast Convert.fromLua(lua, -1);
			if(result == null) result = LuaUtils.Function_Continue;
			Lua.pop(lua, 1);
			return result;
		} catch(e:Dynamic) {
			trace('LuaState exception in $func: $e');
		}
		return LuaUtils.Function_Continue;
	}

	public function set(variable:String, data:Dynamic)
	{
		if(lua == null) return;
		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
	}

	public function addTextToDebug(text:String, ?color:FlxColor = FlxColor.WHITE)
	{
		trace('[LuaState:$stateName] $text');
		if(luaDebugGroup == null) return;

		var newText:funkin.scripting.DebugLuaText = luaDebugGroup.recycle(funkin.scripting.DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);

		luaDebugGroup.forEachAlive(function(spr:funkin.scripting.DebugLuaText) {
			spr.y += newText.height + 2;
		});
		luaDebugGroup.add(newText);
	}

	public function luaTrace(text:String)
		addTextToDebug(text, FlxColor.RED);

    #if HSCRIPT_ALLOWED
	public function initHaxeModuleCode(code:String, ?varsToBring:Any = null)
	{
		if(hscript != null)
		{
			hscript.destroy();
			hscript = null;
		}
		try {
			hscript = new HScript(null, code, varsToBring);
			hscript.origin = stateName;
			hscript.modFolder = modDirectory;
		}
		catch(e:IrisError) {
			var pos:HScriptInfos = cast {fileName: stateName, isLua: true};
			if(lastCalledFunction != '') pos.funcName = lastCalledFunction;
			Iris.error(Printer.errorToString(e, false), pos);
			hscript = null;
		}
	}
	#end
public static function resolveLuaScriptPath(path:String):String
	{
		#if (sys && MODS_ALLOWED)
		if(sys.FileSystem.exists(path)) return path;
		var modDir:String = Mods.currentModDirectory;
		if(modDir != null && modDir != '')
		{
			var inMod:String = 'mods/$modDir/$path';
			if(sys.FileSystem.exists(inMod)) return inMod;
		}
		var inMods:String = 'mods/$path';
		if(sys.FileSystem.exists(inMods)) return inMods;
		#end
		return path;
	}

	public static function resolveHScriptPath(path:String):String
	{
		#if (sys && MODS_ALLOWED)
		if(sys.FileSystem.exists(path)) return path;
		var modDir:String = Mods.currentModDirectory;
		if(modDir != null && modDir != '')
		{
			var inMod:String = 'mods/$modDir/$path';
			if(sys.FileSystem.exists(inMod)) return inMod;
		}
		var inMods:String = 'mods/$path';
		if(sys.FileSystem.exists(inMods)) return inMods;
		#end
		return path;
	}
}

class LuaStateScript extends FunkinLuaScript
{
	public function new(scriptPath:String, ?modDir:String)
	{
		super(scriptPath);
		traceLabel = 'LuaStateScript';

		if(modDir != null && modDir != '')
			Mods.currentModDirectory = modDir;

		initLua();

		if(LuaState.instance != null)
			LuaState.instance.registerCallbacks(this.lua);

		if(!runFile(scriptPath)) return;

		call('onCreate', []);
	}

	override public function stop():Void
	{
		if(!closed && lua != null) call('onDestroy', []);
		super.stop();
	}
}

class LuaStateLoader
{
	public static function loadStateScript(stateName:String):FlxState
	{
		#if MODS_ALLOWED
		var save = FlxG.save;
		var modMode:String = null;
		if(save != null && save.data != null && save.data.modMode != null)
			modMode = save.data.modMode;

		if(modMode == 'DISABLE MODS' || modMode == 'ALL MODS' || modMode == 'MODS + FNF SONGS')
			return null;

		var savedModDirectory = Mods.currentModDirectory;

		if(savedModDirectory == null || savedModDirectory == '') {
			if(save != null && save.data != null && save.data.currentMod != null && save.data.currentMod != '') {
				savedModDirectory = save.data.currentMod;
				Mods.currentModDirectory = savedModDirectory;
			}
		}

		if(savedModDirectory != null && savedModDirectory != '') {
			var statesDir = Paths.modFolders('$savedModDirectory/states/');
			var scriptPath = findScriptInDir(statesDir, '$stateName.lua');
			var exists = scriptPath != null;

			if(exists && stateName != 'LoadingState' && stateName != 'LoadingScreen') {
				Mods.currentModDirectory = savedModDirectory;
				Mods.loadTopMod();

				try {
					var stateInstance = new LuaState(scriptPath, stateName, savedModDirectory);
					return stateInstance;
				} catch(e:Dynamic) {
					trace('LuaStateLoader: Error creating state $stateName: $e');
				}
			}
		}
		#end
		return null;
	}
    public static function findScriptInDir(dir:String, fileName:String):String
		{
			if(!sys.FileSystem.exists(dir) || !sys.FileSystem.isDirectory(dir))
				return null;

			var direct = dir + fileName;
			if(sys.FileSystem.exists(direct))
				return direct;

			for(entry in sys.FileSystem.readDirectory(dir))
			{
				var full = dir + entry;
				if(sys.FileSystem.isDirectory(full))
				{
					var found = findScriptInDir(full + '/', fileName);
					if(found != null) return found;
				}
			}
			return null;
		}

	public static function createLoadingScript(barBack:flixel.FlxSprite, bar:flixel.FlxSprite, loadingState:funkin.ui.states.LoadingState):LoadingLuaScript
	{
		#if MODS_ALLOWED
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.trim().length > 0)
		{
			var scriptPath:String = 'mods/${Mods.currentModDirectory}/data/LoadingScreen.lua';
			if(!sys.FileSystem.exists(scriptPath))
				scriptPath = 'mods/${Mods.currentModDirectory}/data/LoadingState.lua';
			if(sys.FileSystem.exists(scriptPath))
			{
				try
				{
					return new LoadingLuaScript(scriptPath, barBack, bar, loadingState);
				}
				catch(e:Dynamic)
				{
					trace('LuaStateLoader: Error creating LoadingLuaScript: $e');
				}
			}
		}
		#end
		return null;
	}
}

class LoadingLuaScript extends FunkinLuaScript
{
	var loadingState:funkin.ui.states.LoadingState;

	public function new(scriptPath:String, barBack:flixel.FlxSprite, bar:flixel.FlxSprite, loadingState:funkin.ui.states.LoadingState)
	{
		super(scriptPath);
		traceLabel = 'LoadingLuaScript';
		this.loadingState = loadingState;

		initLua();

		MusicBeatState.getVariables().set('barBack', barBack);
		MusicBeatState.getVariables().set('bar', bar);
		set('game', loadingState);

		registerCallbacks();
		runFile(scriptPath);
	}

	function registerCallbacks()
	{
		LuaCallbacks.registerCommon(lua, this);
		LuaSharedFunctions.registerFileAndSaveFunctions(lua);

		Lua_helper.add_callback(lua, "getLoaded", function() return funkin.ui.states.LoadingState.loaded);
		Lua_helper.add_callback(lua, "getLoadMax", function() return funkin.ui.states.LoadingState.loadMax);
		Lua_helper.add_callback(lua, "addBehindBar", function(tag:String) {
			var obj:flixel.FlxBasic = MusicBeatState.getVariables().get(tag);
			if(obj != null) loadingState.addBehindBar(obj);
		});

		Lua_helper.add_callback(lua, "switchState", function(stateName:String) {
			if(stateName == 'PlayState' && funkin.game.states.PlayState.SONG != null) {
				FlxG.state.persistentUpdate = false;
				funkin.ui.states.LoadingState.loadAndSwitchState(new funkin.game.states.PlayState());
			} else {
				funkin.backend.StateManager.switchState(stateName);
			}
		});

		Lua_helper.add_callback(lua, "getDifficulties", function(?weekName:String = null) {
			if(weekName != null && weekName.length > 0) {
				#if MODS_ALLOWED
				var weekPath = Paths.mods(Mods.currentModDirectory + '/weeks/' + weekName + '.json');
				if(FileSystem.exists(weekPath)) {
					var weekData:funkin.data.WeekData = haxe.Json.parse(sys.io.File.getContent(weekPath));
					if(weekData != null) funkin.data.Difficulty.loadFromWeek(weekData);
				}
				#end
			}
			if(funkin.data.Difficulty.list == null || funkin.data.Difficulty.list.length == 0)
				funkin.data.Difficulty.resetList();
			return funkin.data.Difficulty.list;
		});
		Lua_helper.add_callback(lua, "flxLerp", function(a:Float, b:Float, t:Float) return flixel.math.FlxMath.lerp(a, b, t));
		Lua_helper.add_callback(lua, "resetState", function() {
			MusicBeatState.resetState();
		});
		Lua_helper.add_callback(lua, "openSubState", function(substate:Dynamic) {
			if(Std.isOfType(substate, String)) {
				var shortNames:Map<String, String> = [
					'EditorPickerSubstate' => 'funkin.editors.EditorPickerSubstate'
				];
				var resolved:String = shortNames.exists(substate) ? shortNames.get(substate) : substate;
				var cls = Type.resolveClass(resolved);
				if(cls != null) loadingState.openSubState(Type.createInstance(cls, []));
			} else {
				loadingState.openSubState(substate);
			}
		});
		Lua_helper.add_callback(lua, "closeSubState", function() {
			loadingState.closeSubState();
		});
		LuaSharedFunctions.registerSpriteFunctions(lua);
		Lua_helper.add_callback(lua, "addLuaSprite", function(tag:String, ?inFront:Bool = true) {
			var mySprite:FlxSprite = MusicBeatState.getVariables().get(tag);
			if(mySprite == null) return;
			loadingState.add(mySprite);
		});
		Lua_helper.add_callback(lua, "removeLuaSprite", function(tag:String, destroy:Bool = true) {
			var obj:FlxSprite = LuaUtils.getObjectDirectly(tag);
			if(obj == null || obj.destroy == null) return;
			loadingState.remove(obj, true);
			if(destroy) {
				MusicBeatState.getVariables().remove(tag);
				obj.destroy();
			}
		});

		var loadingTrace = function(msg:String) trace('[LoadingScript:$scriptName] $msg');
		LuaSharedFunctions.registerGroupFunctions(lua, loadingTrace);
		LuaSharedFunctions.registerExtraTextFunctions(lua, loadingTrace);
		#if flxanimate
		LuaSharedFunctions.registerAnimateFunctions(lua);
		#end

		Lua_helper.add_callback(lua, "createInstance", function(variableToSave:String, className:String, ?args:Array<Dynamic>) {
			if (!Std.isOfType(args, Array)) args = [];
			variableToSave = variableToSave.trim().replace('.', '');
			if(MusicBeatState.getVariables().get(variableToSave) == null)
			{
				var myType:Dynamic = Type.resolveClass(className);
				if(myType == null)
				{
					loadingTrace('createInstance: Class $className not found');
					return false;
				}

				var obj:Dynamic = Type.createInstance(myType, ReflectionFunctions.parseInstances(args));
				if(obj != null)
					MusicBeatState.getVariables().set(variableToSave, obj);
				else
					loadingTrace('createInstance: Failed to create $variableToSave, arguments are possibly wrong.');

				return (obj != null);
			}
			else loadingTrace('createInstance: Variable $variableToSave is already being used and cannot be replaced!');
			return false;
		});
		Lua_helper.add_callback(lua, "addInstance", function(objectName:String, ?inFront:Bool = false) {
			var savedObj:Dynamic = MusicBeatState.getVariables().get(objectName);
			if(savedObj != null)
				loadingState.add(savedObj);
			else
				loadingTrace('addInstance: Can\'t add what doesn\'t exist~ ($objectName)');
		});
		LuaSharedFunctions.registerObjectOrderFunctions(lua, () -> MusicBeatState.getState(), () -> MusicBeatState.getState());
		LuaSharedFunctions.registerTweenFunctions(lua, (name, args) -> call(name, args));
		Lua_helper.add_callback(lua, "debugPrint", function(text:Dynamic = '', color:String = 'WHITE') {
			trace('[LoadingScript:$scriptName] $text');
		});
		#if MODS_ALLOWED
		Lua_helper.add_callback(lua, "getModSetting", function(saveTag:String, ?modName:String = null) {
			if(modName == null) modName = Mods.currentModDirectory;
			if(modName == null) return null;
			return LuaUtils.getModSetting(saveTag, modName);
		});
		#end
		Lua_helper.add_callback(lua, "addLuaText", function(tag:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) loadingState.add(obj);
		});
		Lua_helper.add_callback(lua, "removeLuaText", function(tag:String, destroy:Bool = true) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj == null) return;
			loadingState.remove(obj, true);
			if(destroy) {
				MusicBeatState.getVariables().remove(tag);
				obj.destroy();
			}
		});
		#if HSCRIPT_ALLOWED
		Lua_helper.add_callback(lua, "runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null):Dynamic {
			if(hscript != null)
			{
				var retVal = hscript.call(funcToRun, funcArgs);
				if(retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
			}
			else
			{
				var pos:HScriptInfos = cast {fileName: scriptName, showLine: false, isLua: true};
				if(lastCalledFunction != '') pos.funcName = lastCalledFunction;
				Iris.error("runHaxeFunction: HScript has not been initialized yet! Use \"runHaxeCode\" to initialize it", pos);
			}
			return null;
		});
		Lua_helper.add_callback(lua, "addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			var str:String = '';
			if(libPackage.length > 0)
				str = libPackage + '.';
			else if(libName == null)
				libName = '';

			var c:Dynamic = Type.resolveClass(str + libName);
			if(c == null)
				c = Type.resolveEnum(str + libName);

			if(hscript == null)
				initHaxeModuleCode('', null);

			if(hscript != null)
			{
				var pos:HScriptInfos = cast {fileName: scriptName, showLine: false, isLua: true};
				if(lastCalledFunction != '') pos.funcName = lastCalledFunction;

				try {
					if(c != null) hscript.set(libName, c);
				}
				catch(e:IrisError) {
					Iris.error(Printer.errorToString(e, false), pos);
				}
			}
		});
		#end
	}

	public function destroy()
	{
		stop();
		MusicBeatState.getVariables().remove('barBack');
		MusicBeatState.getVariables().remove('bar');
		loadingState = null;
	}
}

class LuaStateCustomSubstate extends MusicBeatSubstate
{
	public static var instance:LuaStateCustomSubstate = null;
	public var substateName:String;
	var _luaState:LuaState;

	public function new(name:String, luaState:LuaState)
	{
		substateName = name;
		_luaState = luaState;
		super();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	override function create()
	{
		instance = this;
		_luaState.call('onCustomSubstateCreate', [substateName]);
		super.create();
		_luaState.call('onCustomSubstateCreatePost', [substateName]);
	}

	override function update(elapsed:Float)
	{
		_luaState.call('onCustomSubstateUpdate', [substateName, elapsed]);
		super.update(elapsed);
		_luaState.call('onCustomSubstateUpdatePost', [substateName, elapsed]);
	}

	override function destroy()
	{
		_luaState.call('onCustomSubstateDestroy', [substateName]);
		instance = null;
		substateName = 'unnamed';
		super.destroy();
	}
}
#end