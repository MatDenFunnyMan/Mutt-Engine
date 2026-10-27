package funkin.scripting;

import flixel.FlxBasic;
import flixel.addons.display.FlxBackdrop;
import flixel.effects.particles.FlxEmitter;
import flixel.effects.particles.FlxParticle;
import flixel.util.FlxAxes;

class ObjectFunctions
{
	public static function register(lua:State, place:FlxBasic->Bool->Null<Int>->Void, notify:(String, Array<Dynamic>)->Void, ?onError:String->Void)
	{
		var report:String->Void = (onError != null) ? onError : function(msg:String) trace(msg);

		Lua_helper.add_callback(lua, "createBackdrop", function(tag:String, image:String, ?x:Float = 0, ?y:Float = 0, ?options:Dynamic = null) {
			options = LuaUtils.namedOptions(options, ['axes', 'spacingX', 'spacingY', 'velocityX', 'velocityY', 'alpha', 'scaleX', 'scaleY', 'scrollX', 'scrollY', 'camera', 'zIndex', 'front']);
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var axes:String = LuaUtils.option(options, 'axes');
			var repeat:FlxAxes = switch(axes != null ? axes.toLowerCase() : 'xy')
			{
				case 'x': X;
				case 'y': Y;
				default: XY;
			}
			var backdrop:FlxBackdrop = new FlxBackdrop(null, repeat, number(options, 'spacingX', 0), number(options, 'spacingY', 0));
			if(image != null && image.trim().length > 0)
			{
				if(LuaUtils.hasAtlas(image)) LuaUtils.loadFrames(backdrop, image, 'auto');
				else backdrop.loadGraphic(Paths.image(image));
			}
			backdrop.setPosition(x, y);
			backdrop.antialiasing = ClientPrefs.data.antialiasing;
			backdrop.velocity.set(number(options, 'velocityX', 0), number(options, 'velocityY', 0));
			LuaSharedFunctions.applyCreateOptions(backdrop, options);
			MusicBeatState.getVariables().set(tag, backdrop);
			place(backdrop, LuaUtils.option(options, 'front') == true, LuaSharedFunctions.zIndexOption(options));
			return tag;
		});

		Lua_helper.add_callback(lua, "createParticles", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?options:Dynamic = null) {
			options = LuaUtils.namedOptions(options, ['amount', 'size', 'color', 'width', 'height', 'lifespan', 'speed', 'angle', 'spin', 'alpha', 'scale', 'gravity', 'gravityX', 'startColor', 'endColor', 'blend', 'frequency', 'quantity', 'explode', 'start', 'scrollX', 'scrollY', 'camera', 'zIndex', 'front']);
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var emitter:FlxEmitter = new FlxEmitter(x, y);
			var amount:Int = Std.int(Math.max(1, number(options, 'amount', 50)));
			if(image != null && image.trim().length > 0)
				emitter.loadParticles(Paths.image(image), amount, 0);
			else
			{
				var size:Int = Std.int(Math.max(1, number(options, 'size', 8)));
				var color:Null<FlxColor> = LuaUtils.colorFromLua(LuaUtils.option(options, 'color'));
				emitter.makeParticles(size, size, color != null ? color : FlxColor.WHITE, amount);
			}
			emitter.width = number(options, 'width', 0);
			emitter.height = number(options, 'height', 0);

			var lifespan:Array<Float> = range(options, 'lifespan', 1, 2);
			emitter.lifespan.set(lifespan[0], lifespan[1]);
			var speed:Array<Float> = range(options, 'speed', 50, 150);
			emitter.speed.set(speed[0], speed[1]);
			var angle:Array<Float> = range(options, 'angle', -180, 180);
			emitter.launchAngle.set(angle[0], angle[1]);
			var spin:Array<Float> = range(options, 'spin', 0, 0);
			emitter.angularVelocity.set(spin[0], spin[1]);
			var alpha:Array<Float> = range(options, 'alpha', 1, 1);
			emitter.alpha.set(alpha[0], alpha[0], alpha[1], alpha[1]);
			var scale:Array<Float> = range(options, 'scale', 1, 1);
			emitter.scale.set(scale[0], scale[0], scale[0], scale[0], scale[1], scale[1], scale[1], scale[1]);
			emitter.acceleration.set(number(options, 'gravityX', 0), number(options, 'gravity', 0));

			var startColor:Null<FlxColor> = LuaUtils.colorFromLua(LuaUtils.option(options, 'startColor'));
			var endColor:Null<FlxColor> = LuaUtils.colorFromLua(LuaUtils.option(options, 'endColor'));
			if(startColor != null || endColor != null)
			{
				var first:FlxColor = startColor != null ? startColor : FlxColor.WHITE;
				emitter.color.set(first, first, endColor != null ? endColor : first, endColor != null ? endColor : first);
			}

			var blend:String = LuaUtils.option(options, 'blend');
			if(blend != null && blend.length > 0) emitter.blend = LuaUtils.blendModeFromString(blend);
			var camera:String = LuaUtils.option(options, 'camera');
			if(camera != null && camera.length > 0) emitter.cameras = [LuaUtils.cameraFromString(camera)];
			var scrollX:Float = number(options, 'scrollX', 1);
			var scrollY:Float = number(options, 'scrollY', 1);
			for (particle in emitter.members)
			{
				particle.antialiasing = ClientPrefs.data.antialiasing;
				particle.scrollFactor.set(scrollX, scrollY);
			}

			MusicBeatState.getVariables().set(tag, emitter);
			place(emitter, LuaUtils.option(options, 'front') == true, LuaSharedFunctions.zIndexOption(options));
			if(LuaUtils.option(options, 'start') != false)
				emitter.start(LuaUtils.option(options, 'explode') == true, number(options, 'frequency', 0.1), Std.int(number(options, 'quantity', 0)));
			return tag;
		});
		Lua_helper.add_callback(lua, "startParticles", function(tag:String, ?explode:Bool = false, ?frequency:Float = 0.1, ?quantity:Int = 0) {
			var emitter:FlxEmitter = emitterFromTag(tag);
			if(emitter == null)
			{
				report('startParticles: Particles $tag don\'t exist!');
				return false;
			}
			emitter.start(explode, frequency, quantity);
			return true;
		});
		Lua_helper.add_callback(lua, "stopParticles", function(tag:String, ?clear:Bool = false) {
			var emitter:FlxEmitter = emitterFromTag(tag);
			if(emitter == null)
			{
				report('stopParticles: Particles $tag don\'t exist!');
				return false;
			}
			emitter.emitting = false;
			if(clear) for (particle in emitter.members) particle.kill();
			return true;
		});

		Lua_helper.add_callback(lua, "setSkew", function(obj:String, x:Float, ?y:Float = 0) {
			var target:Dynamic = UtilityFunctions.objectFromPath(obj);
			var value:Dynamic = (target != null) ? Reflect.getProperty(target, 'skew') : null;
			var skew:FlxPoint = Std.isOfType(value, flixel.math.FlxPoint.FlxBasePoint) ? value : null;
			if(skew == null)
			{
				report('setSkew: Object $obj doesn\'t exist or can\'t be skewed!');
				return false;
			}
			skew.set(x, y);
			return true;
		});

		Lua_helper.add_callback(lua, "typeText", function(tag:String, text:String, ?options:Dynamic = null) {
			options = LuaUtils.namedOptions(options, ['speed', 'sound', 'volume', 'append']);
			var obj:FlxText = UtilityFunctions.objectFromPath(tag);
			if(obj == null)
			{
				report('typeText: Text $tag doesn\'t exist!');
				return false;
			}
			stopTyping(tag);
			if(text == null) text = '';
			var full:String = (LuaUtils.option(options, 'append') == true) ? obj.text + text : text;
			var from:Int = (LuaUtils.option(options, 'append') == true) ? obj.text.length : 0;
			var speed:Float = Math.max(1, number(options, 'speed', 30));
			var soundName:String = LuaUtils.option(options, 'sound');
			var sound = (soundName != null && soundName.length > 0) ? Paths.sound(soundName) : null;
			var volume:Float = number(options, 'volume', 1);
			var rate:Float = Std.isOfType(FlxG.state, PlayState) ? PlayState.instance.playbackRate : 1;
			var key:String = typeKey(tag);
			var variables = MusicBeatState.getVariables();
			var shown:Int = from;
			obj.text = full.substr(0, from);

			function finish(_)
			{
				obj.text = full;
				variables.remove(key);
				notify('onTypeTextCompleted', [tag]);
			}
			if(full.length <= from)
			{
				finish(null);
				return true;
			}
			var tween:FlxTween = FlxTween.num(from, full.length, (full.length - from) / speed / rate, {onComplete: finish}, function(value:Float) {
				var count:Int = Std.int(Math.min(full.length, value));
				if(count <= shown) return;
				var typed:String = full.substring(shown, count);
				shown = count;
				obj.text = full.substr(0, count);
				if(sound != null && typed.trim().length > 0) FlxG.sound.play(sound, volume);
			});
			variables.set(key, tween);
			return true;
		});
		Lua_helper.add_callback(lua, "skipTypeText", function(tag:String) {
			var tween:FlxTween = MusicBeatState.getVariables().get(typeKey(tag));
			if(tween == null) return false;
			var complete = tween.onComplete;
			tween.cancel();
			if(complete != null) complete(tween);
			return true;
		});
		Lua_helper.add_callback(lua, "isTyping", function(tag:String) {
			return MusicBeatState.getVariables().get(typeKey(tag)) != null;
		});
	}

	static inline function typeKey(tag:String):String
		return 'typetext_' + LuaUtils.formatVariable(tag);

	static function stopTyping(tag:String)
	{
		var variables = MusicBeatState.getVariables();
		var tween:FlxTween = variables.get(typeKey(tag));
		if(tween != null) tween.cancel();
		variables.remove(typeKey(tag));
	}

	static function emitterFromTag(tag:String):FlxEmitter
	{
		var obj:Dynamic = MusicBeatState.getVariables().get(tag);
		return Std.isOfType(obj, FlxEmitter) ? obj : null;
	}

	static function number(options:Dynamic, name:String, fallback:Float):Float
	{
		var value:Dynamic = LuaUtils.option(options, name);
		if(value == null) return fallback;
		var parsed:Float = Std.isOfType(value, String) ? Std.parseFloat(value) : value;
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function range(options:Dynamic, name:String, min:Float, max:Float):Array<Float>
	{
		var value:Dynamic = LuaUtils.option(options, name);
		if(value == null) return [min, max];
		if(Std.isOfType(value, Array))
		{
			var list:Array<Dynamic> = value;
			if(list.length < 1) return [min, max];
			var first:Float = list[0];
			return [first, list.length > 1 ? (list[1] : Float) : first];
		}
		var single:Float = Std.isOfType(value, String) ? Std.parseFloat(value) : value;
		return Math.isNaN(single) ? [min, max] : [single, single];
	}
}
