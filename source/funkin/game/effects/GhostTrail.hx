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
	var pools:Map<String, Array<TrailGhost>> = [];
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

	public function precache(type:String, ?options:Dynamic, ?characterName:String, ?isPlayer:Null<Bool>)
	{
		var source:Character = resolver();
		if(characterName == null && source == null) return;
		if(characterName == null) characterName = source.curCharacter;
		if(isPlayer == null) isPlayer = (source != null) ? source.isPlayer : false;
		var aura:Bool = (type == 'aura');
		fillPool(characterName, isPlayer, poolSize(type, number(options, 'duration', aura ? 0.4 : 0.5), 1 / Math.max(1, number(options, 'rate', 30))));
	}

	var lastChordPose:String = null;
	public function onSing(source:Character, strumTime:Float, ?chordPose:String, ?holdPoseShown:Bool = false, ?forcePose:Bool = false)
	{
		if(!enabled || type == 'aura' || source != resolver()) return;

		var chord:Bool = Math.abs(strumTime - lastStrumTime) < 1;
		lastStrumTime = strumTime;
		if(!chord) lastChordPose = null;
		if(doubleNote && !chord) return;
		if(!chord && holdPoseShown) return;

		var useOverride:Bool = (chord || forcePose) && chordPose != null && source.hasAnimation(chordPose);
		var pose:String = useOverride ? chordPose : source.getAnimationName();
		if(pose == null || !pose.startsWith('sing')) return;
		if(chord && pose == lastChordPose) return;
		lastChordPose = pose;
		spawn(source, useOverride ? chordPose : null);
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

	function spawn(source:Character, ?pose:String)
	{
		if(source == null || !source.visible || source.alpha <= 0 || source.isAnimationNull()) return;
		preparePool(source, poolSize(type, duration, interval));
		if(ghosts.length < 1) return;

		var ghost:TrailGhost = ghosts[nextGhost];
		nextGhost = (nextGhost + 1) % ghosts.length;
		if(ghost.tween != null) ghost.tween.cancel();

		var sprite:Character = ghost.sprite;
		copyPose(sprite, source, pose);
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
			var pose:String = sprite.getAnimationName();
			pose = (pose != null) ? pose.toUpperCase() : '';
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
		if(characterName != source.curCharacter || characterIsPlayer != source.isPlayer || ghosts.length < 1)
		{
			characterName = source.curCharacter;
			characterIsPlayer = source.isPlayer;
			ghosts = fillPool(characterName, characterIsPlayer, 0);
			nextGhost = 0;
		}
		fillPool(characterName, characterIsPlayer, size);
	}

	function fillPool(name:String, isPlayer:Bool, size:Int):Array<TrailGhost>
	{
		var key:String = name + (isPlayer ? ':player' : ':opponent');
		var pool:Array<TrailGhost> = pools.get(key);
		if(pool == null)
		{
			pool = [];
			pools.set(key, pool);
		}
		if(pool.length >= size) return pool;

		var speakerNotes:Array<Dynamic> = TankmenBG.animationNotes;
		while(pool.length < size)
		{
			var sprite:Character = new Character(0, 0, name, isPlayer);
			sprite.debugMode = true;
			sprite.active = false;
			sprite.visible = false;
			add(sprite);
			pool.push(new TrailGhost(sprite));
		}
		TankmenBG.animationNotes = speakerNotes;
		return pool;
	}

	static function copyPose(ghost:Character, source:Character, ?pose:String)
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
		if(pose != null) ghost.playAnim(pose, true);
		else ghost.playAnim(source.getAnimationName(), true, reversed, frame);
		ghost.setPosition(source.x, source.y);
		if(pose == null) ghost.offset.copyFrom(source.offset);
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
		for (pool in pools)
			for (ghost in pool)
				if(ghost.tween != null) ghost.tween.cancel();
		pools = null;
		ghosts = null;
		resolver = null;
		super.destroy();
	}
}
