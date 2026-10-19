package funkin.scripting;

import flixel.text.FlxText.FlxTextFormat;
import flixel.text.FlxText.FlxTextFormatMarkerPair;
import funkin.input.InputFormatter;
import funkin.util.MemoryUtils;

typedef WindowBackup = {
	x:Int,
	y:Int,
	width:Int,
	height:Int,
	title:String,
	alphaChanged:Bool,
	styleChanged:Bool
}

class UtilityFunctions
{
	public static var windowBackup:WindowBackup = null;

	public static function register(lua:State, notify:(String, Array<Dynamic>)->Void, ?onError:String->Void)
	{
		var report:String->Void = (onError != null) ? onError : function(msg:String) trace(msg);

		Lua_helper.add_callback(lua, "rgbToHex", function(red:Int, green:Int, blue:Int) {
			return StringTools.hex(red & 0xFF, 2) + StringTools.hex(green & 0xFF, 2) + StringTools.hex(blue & 0xFF, 2);
		});
		Lua_helper.add_callback(lua, "hexToRgb", function(hex:String) {
			var color:Null<FlxColor> = LuaUtils.colorFromLua(hex);
			if(color == null) return null;
			return [color.red, color.green, color.blue];
		});
		Lua_helper.add_callback(lua, "getColorChannels", function(color:Dynamic) {
			var value:Null<FlxColor> = Std.isOfType(color, String) ? LuaUtils.colorFromLua(color) : (color != null ? Std.int(color) : null);
			if(value == null) return null;
			return [value.red, value.green, value.blue, value.alpha];
		});
		Lua_helper.add_callback(lua, "setColorTransform", function(obj:String, values:Dynamic) {
			var spr:FlxSprite = objectFromPath(obj);
			if(spr == null || values == null)
			{
				report('setColorTransform: Object $obj doesn\'t exist!');
				return false;
			}
			var current = spr.colorTransform;
			function value(field:String, fallback:Float):Float
			{
				var given:Null<Float> = LuaUtils.option(values, field);
				return given != null ? given : fallback;
			}
			spr.setColorTransform(
				value('redMultiplier', current != null ? current.redMultiplier : 1), value('greenMultiplier', current != null ? current.greenMultiplier : 1),
				value('blueMultiplier', current != null ? current.blueMultiplier : 1), value('alphaMultiplier', current != null ? current.alphaMultiplier : 1),
				value('redOffset', current != null ? current.redOffset : 0), value('greenOffset', current != null ? current.greenOffset : 0),
				value('blueOffset', current != null ? current.blueOffset : 0), value('alphaOffset', current != null ? current.alphaOffset : 0));
			return true;
		});
		Lua_helper.add_callback(lua, "getHealthColor", function(character:Dynamic) {
			var game:PlayState = PlayState.instance;
			if(game == null) return null;
			var char:funkin.game.Character = game.characterFromName(Std.string(character), game.boyfriend);
			if(char == null || char.healthColorArray == null) return null;
			return StringTools.hex(char.healthColorArray[0] & 0xFF, 2) + StringTools.hex(char.healthColorArray[1] & 0xFF, 2) + StringTools.hex(char.healthColorArray[2] & 0xFF, 2);
		});

		Lua_helper.add_callback(lua, "parseJSON", function(text:String) {
			try {
				return haxe.Json.parse(text);
			} catch(e:Dynamic) {
				report('parseJSON: $e');
			}
			return null;
		});
		Lua_helper.add_callback(lua, "stringifyJSON", function(value:Dynamic, ?pretty:Bool = false) {
			try {
				return haxe.Json.stringify(value, null, pretty ? '\t' : null);
			} catch(e:Dynamic) {
				report('stringifyJSON: $e');
			}
			return null;
		});

		Lua_helper.add_callback(lua, "getKeybind", function(name:String, ?gamepad:Bool = false) {
			var names:Array<String> = [];
			if(gamepad)
			{
				var buttons = ClientPrefs.gamepadBinds.get(name);
				if(buttons != null) for (button in buttons) if(button != NONE) names.push(InputFormatter.getGamepadName(button));
			}
			else
			{
				var keys = ClientPrefs.keyBinds.get(name);
				if(keys != null) for (key in keys) if(key != NONE) names.push(InputFormatter.getKeyName(key));
			}
			return names;
		});

		Lua_helper.add_callback(lua, "pauseTween", function(tag:String) return setTweenActive(tag, false));
		Lua_helper.add_callback(lua, "resumeTween", function(tag:String) return setTweenActive(tag, true));
		Lua_helper.add_callback(lua, "pauseTimer", function(tag:String) return setTimerActive(tag, false));
		Lua_helper.add_callback(lua, "resumeTimer", function(tag:String) return setTimerActive(tag, true));
		Lua_helper.add_callback(lua, "tweenNumber", function(tag:String, from:Float, to:Float, duration:Float, ?options:Dynamic = null) {
			if(tag == null) return null;
			LuaUtils.cancelTween(tag);
			var myOptions = LuaUtils.getLuaTween(options);
			var key:String = 'tween_' + LuaUtils.formatVariable(tag);
			var variables = MusicBeatState.getVariables();
			var tween:FlxTween = FlxTween.num(from, to, duration, {
				type: myOptions != null ? myOptions.type : FlxTweenType.ONESHOT,
				ease: myOptions != null ? myOptions.ease : FlxEase.linear,
				startDelay: myOptions != null ? myOptions.startDelay : 0,
				loopDelay: myOptions != null ? myOptions.loopDelay : 0,
				onComplete: function(twn:FlxTween) {
					if(twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD) variables.remove(key);
					if(myOptions != null && myOptions.onComplete != null) notify(myOptions.onComplete, [tag, to]);
				}
			}, function(value:Float) {
				if(myOptions != null && myOptions.onUpdate != null) notify(myOptions.onUpdate, [tag, value]);
			});
			variables.set(key, tween);
			return tag;
		});

		Lua_helper.add_callback(lua, "applyTextMarkup", function(tag:String, text:String, rules:Array<Dynamic>) {
			var obj:FlxText = objectFromPath(tag);
			if(obj == null)
			{
				report('applyTextMarkup: Text $tag doesn\'t exist!');
				return false;
			}
			var pairs:Array<FlxTextFormatMarkerPair> = [];
			if(rules != null)
			{
				for (rule in rules)
				{
					var marker:String = LuaUtils.option(rule, 'marker');
					if(marker == null || marker.length < 1) continue;
					var color:String = LuaUtils.option(rule, 'color');
					var border:String = LuaUtils.option(rule, 'borderColor');
					var format:FlxTextFormat = new FlxTextFormat(
						(color != null && color.length > 0) ? CoolUtil.colorFromString(color) : null,
						LuaUtils.option(rule, 'bold') == true,
						LuaUtils.option(rule, 'italic') == true,
						(border != null && border.length > 0) ? CoolUtil.colorFromString(border) : null);
					pairs.push(new FlxTextFormatMarkerPair(format, marker));
				}
			}
			obj.applyMarkup(text != null ? text : obj.text, pairs);
			return true;
		});

		Lua_helper.add_callback(lua, "getFps", function() return funkin.Main.fpsVar != null ? funkin.Main.fpsVar.currentFPS : 0);
		Lua_helper.add_callback(lua, "getMemory", function() return Math.round(MemoryUtils.getGCMemory() / 1048576 * 100) / 100);
		Lua_helper.add_callback(lua, "openURL", function(url:String) {
			if(url == null) return false;
			url = url.trim();
			if(!url.startsWith('https://') && !url.startsWith('http://'))
			{
				report('openURL: Only http:// and https:// links can be opened');
				return false;
			}
			CoolUtil.browserLoad(url);
			return true;
		});

		Lua_helper.add_callback(lua, "appendFile", function(path:String, content:String, ?absolute:Bool = false) {
			try {
				var target:String = filePath(path, absolute);
				var output = File.append(target, false);
				output.writeString(content);
				output.close();
				return true;
			} catch(e:Dynamic) {
				report('appendFile: Error trying to write $path: $e');
			}
			return false;
		});
		Lua_helper.add_callback(lua, "isDirectory", function(path:String, ?absolute:Bool = false) {
			var target:String = filePath(path, absolute);
			return FileSystem.exists(target) && FileSystem.isDirectory(target);
		});
		Lua_helper.add_callback(lua, "createDirectory", function(path:String, ?absolute:Bool = false) {
			try {
				FileSystem.createDirectory(filePath(path, absolute));
				return true;
			} catch(e:Dynamic) {
				report('createDirectory: Error trying to create $path: $e');
			}
			return false;
		});

		registerWindowFunctions(lua, notify, report);
	}

	public static function objectFromPath(path:String):Dynamic
	{
		var split:Array<String> = path.split('.');
		if(split.length > 1) return LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
		return LuaUtils.getObjectDirectly(split[0]);
	}

	static function filePath(path:String, absolute:Bool):String
	{
		#if MODS_ALLOWED
		if(!absolute) return Paths.mods(path);
		#end
		return path;
	}

	static function findTween(tag:String):FlxTween
	{
		var variables = MusicBeatState.getVariables();
		var tween:Dynamic = variables.get(tag.startsWith('tween_') ? tag : 'tween_' + LuaUtils.formatVariable(tag));
		if(tween == null) tween = variables.get(tag);
		return Std.isOfType(tween, FlxTween) ? tween : null;
	}

	static function setTweenActive(tag:String, active:Bool):Bool
	{
		var tween:FlxTween = findTween(tag);
		if(tween == null) return false;
		tween.active = active;
		return true;
	}

	static function setTimerActive(tag:String, active:Bool):Bool
	{
		var timer:Dynamic = MusicBeatState.getVariables().get(tag.startsWith('timer_') ? tag : LuaUtils.formatVariable('timer_$tag'));
		if(!Std.isOfType(timer, FlxTimer)) return false;
		cast(timer, FlxTimer).active = active;
		return true;
	}

	static function backupWindow()
	{
		if(windowBackup != null) return;
		var window = lime.app.Application.current.window;
		windowBackup = {x: window.x, y: window.y, width: window.width, height: window.height, title: window.title, alphaChanged: false, styleChanged: false};
	}

	public static function restoreWindow()
	{
		if(windowBackup == null) return;
		var backup:WindowBackup = windowBackup;
		windowBackup = null;
		var window = lime.app.Application.current.window;
		if(!window.fullscreen && !window.maximized)
		{
			window.move(backup.x, backup.y);
			window.resize(backup.width, backup.height);
		}
		setTitle(backup.title);
		#if windows
		if(backup.alphaChanged) funkin.external.winapi.WindowsCPP.setWindowAlpha(1);
		if(backup.styleChanged)
		{
			funkin.external.winapi.WindowsCPP.setWindowDarkMode(false);
			funkin.external.winapi.WindowsCPP.setWindowBorderColor(-1);
			funkin.external.winapi.WindowsCPP.setWindowRound(funkin.external.winapi.WindowsAPI.WindowRound.DWMWCP_DEFAULT);
		}
		#end
	}

	static function setTitle(title:String)
	{
		lime.app.Application.current.window.title = title;
		#if windows
		funkin.external.winapi.WindowsCPP.reDefineMainWindowTitle(title);
		#end
	}

	static function syncNativeWindow()
	{
		#if windows
		funkin.external.winapi.WindowsCPP.reDefineMainWindowTitle(lime.app.Application.current.window.title);
		#end
	}

	static function registerWindowFunctions(lua:State, notify:(String, Array<Dynamic>)->Void, report:String->Void)
	{
		Lua_helper.add_callback(lua, "setWindowPosition", function(x:Int, y:Int) {
			backupWindow();
			lime.app.Application.current.window.move(x, y);
		});
		Lua_helper.add_callback(lua, "getWindowPosition", function() {
			var window = lime.app.Application.current.window;
			return {x: window.x, y: window.y};
		});
		Lua_helper.add_callback(lua, "setWindowSize", function(width:Int, height:Int) {
			backupWindow();
			lime.app.Application.current.window.resize(width, height);
		});
		Lua_helper.add_callback(lua, "getWindowSize", function() {
			var window = lime.app.Application.current.window;
			return {width: window.width, height: window.height};
		});
		Lua_helper.add_callback(lua, "centerWindow", function() {
			backupWindow();
			var window = lime.app.Application.current.window;
			var bounds = window.display != null ? window.display.bounds : null;
			if(bounds == null) return;
			window.move(Std.int(bounds.x + (bounds.width - window.width) / 2), Std.int(bounds.y + (bounds.height - window.height) / 2));
		});
		Lua_helper.add_callback(lua, "doTweenWindow", function(tag:String, values:Dynamic, duration:Float, ?options:Dynamic = null) {
			if(values == null) return null;
			backupWindow();
			var window = lime.app.Application.current.window;
			var fields:Dynamic = {};
			for (field in ['x', 'y', 'width', 'height'])
			{
				var value:Null<Float> = LuaUtils.option(values, field);
				if(value != null) Reflect.setField(fields, field, value);
			}
			var myOptions = LuaUtils.getLuaTween(options);
			var key:String = (tag != null) ? 'tween_' + LuaUtils.formatVariable(tag) : null;
			if(key != null) LuaUtils.cancelTween(key);
			var variables = MusicBeatState.getVariables();
			var tween:FlxTween = FlxTween.tween(window, fields, duration, {
				type: myOptions != null ? myOptions.type : FlxTweenType.ONESHOT,
				ease: myOptions != null ? myOptions.ease : FlxEase.linear,
				startDelay: myOptions != null ? myOptions.startDelay : 0,
				loopDelay: myOptions != null ? myOptions.loopDelay : 0,
				onUpdate: function(twn:FlxTween) {
					if(myOptions != null && myOptions.onUpdate != null) notify(myOptions.onUpdate, [tag]);
				},
				onComplete: function(twn:FlxTween) {
					if(key != null && (twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD)) variables.remove(key);
					if(myOptions != null && myOptions.onComplete != null) notify(myOptions.onComplete, [tag]);
				}
			});
			if(key != null) variables.set(key, tween);
			return tag;
		});
		Lua_helper.add_callback(lua, "setWindowTitle", function(title:String) {
			backupWindow();
			setTitle(title);
		});
		Lua_helper.add_callback(lua, "getWindowTitle", function() return lime.app.Application.current.window.title);
		Lua_helper.add_callback(lua, "setWindowIcon", function(image:String) {
			var graphic = Paths.image(image);
			if(graphic == null || graphic.bitmap == null || graphic.bitmap.image == null)
			{
				report('setWindowIcon: Image $image doesn\'t exist!');
				return false;
			}
			lime.app.Application.current.window.setIcon(graphic.bitmap.image);
			return true;
		});
		Lua_helper.add_callback(lua, "focusWindow", function() lime.app.Application.current.window.focus());
		Lua_helper.add_callback(lua, "windowAlert", function(title:String, message:String) {
			lime.app.Application.current.window.alert(message, title);
		});
		Lua_helper.add_callback(lua, "setWindowAlpha", function(alpha:Float) {
			#if windows
			backupWindow();
			windowBackup.alphaChanged = true;
			syncNativeWindow();
			funkin.external.winapi.WindowsCPP.enableWindowLayered();
			funkin.external.winapi.WindowsCPP.setWindowAlpha(alpha);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getWindowAlpha", function() {
			#if windows
			syncNativeWindow();
			return funkin.external.winapi.WindowsCPP.getWindowAlpha();
			#else
			return 1.0;
			#end
		});
		Lua_helper.add_callback(lua, "setWindowDarkMode", function(enable:Bool) {
			#if windows
			backupWindow();
			windowBackup.styleChanged = true;
			syncNativeWindow();
			funkin.external.winapi.WindowsCPP.setWindowDarkMode(enable);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setWindowBorderColor", function(?color:String = null) {
			#if windows
			backupWindow();
			windowBackup.styleChanged = true;
			syncNativeWindow();
			var value:Int = -1;
			if(color != null && color.trim().length > 0)
			{
				var parsed:Null<FlxColor> = LuaUtils.colorFromLua(color);
				if(parsed != null) value = (parsed.blue << 16) | (parsed.green << 8) | parsed.red;
			}
			funkin.external.winapi.WindowsCPP.setWindowBorderColor(value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setWindowCorners", function(?mode:String = 'default') {
			#if windows
			backupWindow();
			windowBackup.styleChanged = true;
			syncNativeWindow();
			funkin.external.winapi.WindowsCPP.setWindowRound(switch(mode != null ? mode.toLowerCase() : 'default')
			{
				case 'none' | 'square': funkin.external.winapi.WindowsAPI.WindowRound.DWMWCP_DONOTROUND;
				case 'round': funkin.external.winapi.WindowsAPI.WindowRound.DWMWCP_ROUND;
				case 'small': funkin.external.winapi.WindowsAPI.WindowRound.DWMWCP_ROUNDSMALL;
				default: funkin.external.winapi.WindowsAPI.WindowRound.DWMWCP_DEFAULT;
			});
			return true;
			#else
			return false;
			#end
		});
	}

	public static final LUA_LIBRARY:String = "
local function def(t, k, f) if t[k] == nil then t[k] = f end end
def(string, 'split', function(s, sep)
	sep = sep or ','
	local out, start = {}, 1
	if sep == '' then for i = 1, #s do out[#out + 1] = s:sub(i, i) end return out end
	while true do
		local i, j = s:find(sep, start, true)
		if not i then out[#out + 1] = s:sub(start) break end
		out[#out + 1] = s:sub(start, i - 1)
		start = j + 1
	end
	return out
end)
def(string, 'trim', function(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end)
def(string, 'ltrim', function(s) return (s:gsub('^%s+', '')) end)
def(string, 'rtrim', function(s) return (s:gsub('%s+$', '')) end)
def(string, 'startswith', function(s, prefix) return s:sub(1, #prefix) == prefix end)
def(string, 'endswith', function(s, suffix) return suffix == '' or s:sub(-#suffix) == suffix end)
def(string, 'contains', function(s, part) return s:find(part, 1, true) ~= nil end)
def(string, 'replace', function(s, from, to)
	if from == '' then return s end
	local out, start = {}, 1
	while true do
		local i, j = s:find(from, start, true)
		if not i then out[#out + 1] = s:sub(start) break end
		out[#out + 1] = s:sub(start, i - 1) .. to
		start = j + 1
	end
	return table.concat(out)
end)
def(table, 'contains', function(t, value) for _, v in pairs(t) do if v == value then return true end end return false end)
def(table, 'indexof', function(t, value) for i, v in ipairs(t) do if v == value then return i end end return nil end)
def(table, 'filter', function(t, fn) local out = {} for _, v in ipairs(t) do if fn(v) then out[#out + 1] = v end end return out end)
def(table, 'map', function(t, fn) local out = {} for i, v in ipairs(t) do out[i] = fn(v) end return out end)
def(table, 'clone', function(t) local out = {} for k, v in pairs(t) do out[k] = v end return out end)
def(table, 'reverse', function(t) local out = {} for i = #t, 1, -1 do out[#out + 1] = t[i] end return out end)
def(table, 'keys', function(t) local out = {} for k in pairs(t) do out[#out + 1] = k end return out end)
def(math, 'lerp', function(a, b, t) return a + (b - a) * t end)
def(math, 'clamp', function(v, lo, hi) return math.max(lo, math.min(hi, v)) end)
def(math, 'round', function(v, decimals) local m = 10 ^ (decimals or 0) return math.floor(v * m + 0.5) / m end)
def(math, 'sign', function(v) if v > 0 then return 1 elseif v < 0 then return -1 end return 0 end)
def(math, 'distance', function(x1, y1, x2, y2) return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) end)
def(math, 'isnan', function(v) return v ~= v end)
";
}
