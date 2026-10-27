package funkin.scripting;

import funkin.game.notes.StrumNote;
import flixel.tweens.FlxTween;

class EffectFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua = funk.lua;
		Lua_helper.add_callback(lua, "setGhostTrail", function(character:String, type:String, ?options:Dynamic = null) {
			options = LuaUtils.namedOptions(options, ['doubleNote', 'color', 'alpha', 'duration', 'distance', 'grow', 'rate', 'blend']);
			if(PlayState.instance == null) return false;
			if(!PlayState.instance.setGhostTrail(character, type, options))
			{
				if(type != null && funkin.game.effects.GhostTrail.TYPES.contains(type.trim().toLowerCase()))
					FunkinLua.luaTrace('setGhostTrail: Character $character doesn\'t exist!', false, false, FlxColor.RED);
				return false;
			}
			return true;
		});
		Lua_helper.add_callback(lua, "setSilhouette", function(enabled:Bool, ?options:Dynamic = null) {
			options = LuaUtils.namedOptions(options, ['characterColor', 'characterColors', 'backgroundColor', 'strength', 'characterAlpha', 'backgroundAlpha', 'duration', 'ease', 'hud', 'details']);
			if(PlayState.instance == null) return false;
			PlayState.instance.setSilhouette(enabled, options);
			return true;
		});
		Lua_helper.add_callback(lua, "backgroundFlash", function(?color:String = 'FFFFFF', ?duration:Float = 1, ?options:Dynamic = null) {
			options = LuaUtils.namedOptions(options, ['characterColor', 'ease']);
			if(PlayState.instance == null) return false;
			PlayState.instance.backgroundFlash(color, duration, options);
			return true;
		});

		Lua_helper.add_callback(lua, "setStrumTint", function(target:String, color:String, ?strength:Float = 1) {
			var strums:Array<StrumNote> = tintTargets('setStrumTint', target);
			var tint:Null<FlxColor> = tintColor('setStrumTint', color);
			if(strums == null || tint == null) return false;
			for (strum in strums)
			{
				strum.tintTweenId++;
				strum.setTint(tint, strength);
			}
			return true;
		});
		Lua_helper.add_callback(lua, "tweenStrumTint", function(tag:String, target:String, color:String, duration:Float, ?ease:String = 'linear', ?strength:Float = 1) {
			var strums:Array<StrumNote> = tintTargets('tweenStrumTint', target);
			var tint:Null<FlxColor> = tintColor('tweenStrumTint', color);
			if(strums == null || tint == null) return null;
			return tweenTint(tag, strums, [for (strum in strums) tint], [for (strum in strums) strength], duration, ease);
		});
		Lua_helper.add_callback(lua, "resetStrumTint", function(target:String, ?duration:Float = 0, ?ease:String = 'linear') {
			var strums:Array<StrumNote> = tintTargets('resetStrumTint', target);
			if(strums == null) return false;
			if(duration <= 0)
			{
				for (strum in strums)
				{
					strum.tintTweenId++;
					strum.setTint(strum.baseTintColor, strum.baseTintStrength);
				}
				return true;
			}
			tweenTint('strumTintReset_' + LuaUtils.formatVariable(target != null ? target : 'all'), strums,
				[for (strum in strums) strum.baseTintColor], [for (strum in strums) strum.baseTintStrength], duration, ease);
			return true;
		});
	}

	static function tintColor(funcName:String, color:String):Null<FlxColor>
	{
		var tint:Null<FlxColor> = (color != null) ? LuaUtils.colorFromLua(color) : null;
		if(tint == null) FunkinLua.luaTrace('$funcName: "$color" is not a valid color!', false, false, FlxColor.RED);
		return tint;
	}

	static function tintTargets(funcName:String, target:String):Array<StrumNote>
	{
		if(PlayState.instance == null) return null;
		var strums:Array<StrumNote> = PlayState.instance.strumsForTarget(target);
		if(strums.length < 1)
		{
			FunkinLua.luaTrace('$funcName: Target "$target" has no arrows! Use player, opponent, all, charN or a lane number.', false, false, FlxColor.RED);
			return null;
		}
		return strums;
	}

	static function tweenTint(tag:String, strums:Array<StrumNote>, colors:Array<FlxColor>, strengths:Array<Float>, duration:Float, ease:String):String
	{
		if(tag == null || tag.trim().length < 1) tag = 'strumTint';
		LuaUtils.cancelTween(tag);
		var startColors:Array<FlxColor> = [for (strum in strums) strum.tintColor];
		var startStrengths:Array<Float> = [for (strum in strums) strum.tintStrength];
		var ids:Array<Int> = [for (strum in strums) ++strum.tintTweenId];

		if(duration <= 0)
		{
			for (i => strum in strums) strum.setTint(colors[i], strengths[i]);
			if(PlayState.instance != null) PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
			return tag;
		}

		var key:String = 'tween_' + LuaUtils.formatVariable(tag);
		var variables = MusicBeatState.getVariables();
		var tween:FlxTween = FlxTween.num(0, 1, duration, {
			ease: LuaUtils.getTweenEaseByString(ease),
			onComplete: function(twn:FlxTween) {
				variables.remove(key);
				if(PlayState.instance != null) PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
			}
		}, function(value:Float) {
			for (i => strum in strums)
				if(strum.tintTweenId == ids[i])
					strum.setTint(FlxColor.interpolate(startColors[i], colors[i], value), FlxMath.lerp(startStrengths[i], strengths[i], value));
		});
		variables.set(key, tween);
		return tag;
	}
}
