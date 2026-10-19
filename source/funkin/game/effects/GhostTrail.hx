package funkin.game.effects;

import openfl.display.BlendMode;
import funkin.scripting.LuaUtils;
import funkin.game.stages.objects.TankmenBG;

class TrailGhost
{
	public var sprite:Character;
	public var tween:FlxTween;
	public var startX:Float = 0;
	public var startY:Float = 0;
	public var moveX:Float = 0;
	public var moveY:Float = 0;
	public var scaleX:Float = 1;
	public var scaleY:Float = 1;

	public function new(sprite:Character)
	{
		this.sprite = sprite;
	}
}

class GhostTrail extends FlxTypedGroup<Character>
{
	public static final TYPES:Array<String> = ['simple', 'animated', 'aura'];
	static inline final SIMPLE_POOL:Int = 8;

	public var type:String = 'simple';
	public var enabled:Bool = false;
	public var doubleNote:Bool = false;
	public var tint:Null<FlxColor> = null;
	public var healthTint:Bool = false;
	public var duration:Float = 0.5;
	public var ghostAlpha:Float = 0.6;
	public var distance:Float = 50;
	public var grow:Float = 0.3;
	public var interval:Float = 1 / 30;
	public var blend:BlendMode = NORMAL;

	var resolver:Void->Character;
	var ghosts:Array<TrailGhost> = [];
	var nextGhost:Int = 0;
	var characterName:String = null;
	var characterIsPlayer:Bool = false;
	var lastStrumTime:Float = Math.NEGATIVE_INFINITY;
	var spawnTimer:Float = 0;

	public function new(resolver:Void->Character)
	{
		super();
		this.resolver = resolver;
	}

	public function setup(type:String, ?options:Dynamic)
	{
		type = (type != null) ? type.trim().toLowerCase() : '';
		if(!TYPES.contains(type))
		{
			enabled = false;
			return;
		}

		this.type = type;
		enabled = true;
		var aura:Bool = (type == 'aura');
		doubleNote = !aura && option(options, 'doubleNote') == true;
		duration = number(options, 'duration', aura ? 0.4 : 0.5);
		ghostAlpha = number(options, 'alpha', aura ? 1 : 0.6);
		distance = number(options, 'distance', 50);
		grow = number(options, 'grow', 0.3);
		interval = 1 / Math.max(1, number(options, 'rate', 30));

		var blendName:String = option(options, 'blend');
		blend = (blendName != null && blendName.length > 0) ? LuaUtils.blendModeFromString(blendName) : (aura ? ADD : NORMAL);

		var colorName:String = option(options, 'color');
		colorName = (colorName != null) ? Std.string(colorName).trim() : '';
		healthTint = (colorName.length < 1 && aura) || colorName.toLowerCase() == 'health' || colorName.toLowerCase() == 'hp';
		tint = (colorName.length > 0 && !healthTint) ? CoolUtil.colorFromString(colorName) : null;

		lastStrumTime = Math.NEGATIVE_INFINITY;
		spawnTimer = 0;
		reserve();
	}

	public function reserve()
	{
		var source:Character = resolver();
		if(source != null) preparePool(source, poolSize(type, duration, interval));
	}

	public function precache(type:String, ?options:Dynamic)
	{
		var source:Character = resolver();
		if(source == null) return;
		var aura:Bool = (type == 'aura');
		preparePool(source, poolSize(type, number(options, 'duration', aura ? 0.4 : 0.5), 1 / Math.max(1, number(options, 'rate', 30))));
	}

	public function onSing(source:Character, strumTime:Float)
	{
		if(!enabled || type == 'aura' || source != resolver()) return;

		var chord:Bool = Math.abs(strumTime - lastStrumTime) < 1;
		lastStrumTime = strumTime;
		if(doubleNote && !chord) return;

		var pose:String = source.getAnimationName();
		if(pose == null || !pose.startsWith('sing')) return;
		spawn(source);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(!enabled || type != 'aura') return;

		spawnTimer += elapsed;
		if(spawnTimer < interval) return;
		spawnTimer = Math.min(spawnTimer - interval, interval);
		spawn(resolver());
	}

	function spawn(source:Character)
	{
		if(source == null || !source.visible || source.alpha <= 0 || source.isAnimationNull()) return;
		preparePool(source, poolSize(type, duration, interval));
		if(ghosts.length < 1) return;

		var ghost:TrailGhost = ghosts[nextGhost];
		nextGhost = (nextGhost + 1) % ghosts.length;
		if(ghost.tween != null) ghost.tween.cancel();

		var sprite:Character = ghost.sprite;
		copyPose(sprite, source);
		sprite.color = healthTint ? FlxColor.fromRGB(source.healthColorArray[0], source.healthColorArray[1], source.healthColorArray[2]) : (tint != null ? tint : FlxColor.WHITE);
		sprite.blend = blend;
		#if flxanimate
		if(sprite.isAnimateAtlas && sprite.atlas != null) sprite.atlas.blend = blend;
		#end
		sprite.alpha = ghostAlpha * source.alpha;
		sprite.visible = true;

		ghost.startX = source.x;
		ghost.startY = source.y;
		ghost.scaleX = source.scale.x;
		ghost.scaleY = source.scale.y;
		ghost.moveX = ghost.moveY = 0;
		if(type == 'animated')
		{
			var pose:String = source.getAnimationName().toUpperCase();
			if(pose.contains('LEFT')) ghost.moveX = -distance;
			else if(pose.contains('RIGHT')) ghost.moveX = distance;
			else if(pose.contains('UP')) ghost.moveY = -distance;
			else if(pose.contains('DOWN')) ghost.moveY = distance;
		}

		var startAlpha:Float = sprite.alpha;
		var aura:Bool = (type == 'aura');
		var rate:Float = (PlayState.instance != null) ? PlayState.instance.playbackRate : 1;
		ghost.tween = FlxTween.num(0, 1, duration / rate, {onComplete: function(_) {
			sprite.visible = false;
			ghost.tween = null;
		}}, function(progress:Float) {
			var moved:Float = FlxEase.quadOut(progress);
			sprite.alpha = startAlpha * (1 - progress);
			sprite.x = ghost.startX + ghost.moveX * moved;
			sprite.y = ghost.startY + ghost.moveY * moved;
			if(aura) sprite.scale.set(ghost.scaleX * (1 + grow * progress), ghost.scaleY * (1 + grow * progress));
		});
	}

	static function poolSize(type:String, duration:Float, interval:Float):Int
	{
		if(type == 'aura') return Std.int(Math.ceil(duration / interval)) + 1;
		return SIMPLE_POOL;
	}

	function preparePool(source:Character, size:Int)
	{
		if(characterName != source.curCharacter || characterIsPlayer != source.isPlayer) clearPool();
		characterName = source.curCharacter;
		characterIsPlayer = source.isPlayer;
		if(ghosts.length >= size) return;

		var speakerNotes:Array<Dynamic> = TankmenBG.animationNotes;
		while(ghosts.length < size)
		{
			var sprite:Character = new Character(0, 0, characterName, characterIsPlayer);
			sprite.debugMode = true;
			sprite.active = false;
			sprite.visible = false;
			add(sprite);
			ghosts.push(new TrailGhost(sprite));
		}
		TankmenBG.animationNotes = speakerNotes;
	}

	function clearPool()
	{
		for (ghost in ghosts)
		{
			if(ghost.tween != null) ghost.tween.cancel();
			remove(ghost.sprite, true);
			ghost.sprite.destroy();
		}
		ghosts = [];
		nextGhost = 0;
	}

	static function copyPose(ghost:Character, source:Character)
	{
		var frame:Int = 0;
		var reversed:Bool = false;
		if(source.isAnimateAtlas)
		{
			#if flxanimate
			if(source.atlas != null) frame = source.atlas.anim.curFrame;
			#end
		}
		else if(source.animation.curAnim != null)
		{
			frame = source.animation.curAnim.curFrame;
			reversed = source.animation.curAnim.reversed;
		}

		ghost.canPlayOtherAnims = true;
		ghost.loopAnim = null;
		ghost.animSuffix = '';
		ghost.playAnim(source.getAnimationName(), true, reversed, frame);
		ghost.setPosition(source.x, source.y);
		ghost.offset.copyFrom(source.offset);
		ghost.origin.copyFrom(source.origin);
		ghost.scale.copyFrom(source.scale);
		ghost.scrollFactor.copyFrom(source.scrollFactor);
		ghost.flipX = source.flipX;
		ghost.flipY = source.flipY;
		ghost.angle = source.angle;
		ghost.antialiasing = source.antialiasing;
		ghost.cameras = source.cameras;
	}

	static function option(options:Dynamic, name:String):Dynamic
		return (options != null) ? LuaUtils.option(options, name) : null;

	static function number(options:Dynamic, name:String, fallback:Float):Float
	{
		var value:Dynamic = option(options, name);
		if(value == null) return fallback;
		var parsed:Float = Std.isOfType(value, String) ? Std.parseFloat(value) : value;
		return (Math.isNaN(parsed) || parsed <= 0) ? fallback : parsed;
	}

	override function destroy()
	{
		for (ghost in ghosts)
			if(ghost.tween != null) ghost.tween.cancel();
		ghosts = null;
		resolver = null;
		super.destroy();
	}
}
