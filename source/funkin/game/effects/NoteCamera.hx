package funkin.game.effects;

class NoteCameraSide
{
	public var x:Float = 0;
	public var y:Float = 0;
	public var decayTimer:Float = 0;
	public var resetTimer:Float = 0;

	public function new() {}

	public function set(x:Float, y:Float)
	{
		this.x = x;
		this.y = y;
	}

	public function scale(value:Float)
		set(x * value, y * value);
}

class NoteCamera
{
	public static final MODES:Array<String> = ['Off', 'Simple', 'Advanced'];
	public static final EASES:Array<String> = ['Default', 'Linear', 'Sine Out', 'Quad Out', 'Cube Out', 'Quart Out', 'Expo Out', 'Circ Out', 'Back Out', 'Elastic Out', 'Bounce Out', 'Sine In Out', 'Quad In Out', 'Cube In Out', 'Smooth Step'];
	static final DIRECTIONS:Array<Array<Float>> = [[-1, 0], [0, 1], [0, -1], [1, 0]];
	static inline final DECAY_TIME:Float = 0.1;
	static inline final DECAY:Float = 0.5;
	static inline final SMOOTHING:Float = 0.04;
	static inline final EASE_TIME:Float = 0.5;
	static inline final DEFAULT_INTENSITY:Int = 5;

	public var enabled:Bool = true;
	public var distance:Float = 25;
	public var decay:Bool = false;
	public var inactiveSide:Float = 0;
	public var speed:Float = SMOOTHING;
	public var ease:Float->Float = null;
	public var easeTime:Float = EASE_TIME;
	public var ignoredTypes:Array<String> = ['No Animation'];

	public var offsetX(default, null):Float = 0;
	public var offsetY(default, null):Float = 0;

	var camera:FlxCamera;
	var player:NoteCameraSide = new NoteCameraSide();
	var opponent:NoteCameraSide = new NoteCameraSide();
	var drawX:Float = 0;
	var drawY:Float = 0;

	var target:Array<Float> = [0, 0];
	var easeFrom:Array<Float> = [0, 0];
	var easeProgress:Float = 1;

	public function new(mode:String, camera:FlxCamera, intensity:Int = DEFAULT_INTENSITY, ?easeName:String)
	{
		this.camera = camera;
		if(mode == 'Advanced')
		{
			distance = 35;
			decay = true;
			ease = easeFromName(easeName);
		}
		var level:Int = Std.int(FlxMath.bound(intensity, 1, 10)) - DEFAULT_INTENSITY;
		var scale:Float = 1 + level * 0.15;
		distance *= scale;
		speed = SMOOTHING * Math.pow(1.2, level);
		easeTime = EASE_TIME / Math.pow(1.2, level);
		FlxG.signals.preDraw.add(applyOffset);
		FlxG.signals.postDraw.add(removeOffset);
	}

	public static function easeFromName(name:String):Float->Float
	{
		return switch(name)
		{
			case 'Linear': FlxEase.linear;
			case 'Sine Out': FlxEase.sineOut;
			case 'Quad Out': FlxEase.quadOut;
			case 'Cube Out': FlxEase.cubeOut;
			case 'Quart Out': FlxEase.quartOut;
			case 'Expo Out': FlxEase.expoOut;
			case 'Circ Out': FlxEase.circOut;
			case 'Back Out': FlxEase.backOut;
			case 'Elastic Out': FlxEase.elasticOut;
			case 'Bounce Out': FlxEase.bounceOut;
			case 'Sine In Out': FlxEase.sineInOut;
			case 'Quad In Out': FlxEase.quadInOut;
			case 'Cube In Out': FlxEase.cubeInOut;
			case 'Smooth Step': FlxEase.smoothStepInOut;
			default: null;
		}
	}

	public function noteHit(isPlayer:Bool, direction:Int, sustain:Bool, noteType:String)
	{
		if(!enabled || direction < 0 || direction > 3 || ignoredTypes.contains(noteType)) return;
		var side:NoteCameraSide = isPlayer ? player : opponent;
		side.resetTimer = Conductor.crochet / 1000;
		if(sustain) return;
		var dir:Array<Float> = DIRECTIONS[direction];
		side.set(dir[0], dir[1]);
		side.decayTimer = decay ? DECAY_TIME : 0;
	}

	public function update(elapsed:Float, mustHitSection:Bool, rate:Float)
	{
		updateSide(player, elapsed * rate);
		updateSide(opponent, elapsed * rate);

		var playerWeight:Float = mustHitSection ? 1 : inactiveSide;
		var opponentWeight:Float = mustHitSection ? inactiveSide : 1;
		var active:Float = enabled ? 1 : 0;
		var targetX:Float = (player.x * playerWeight + opponent.x * opponentWeight) * distance * active;
		var targetY:Float = (player.y * playerWeight + opponent.y * opponentWeight) * distance * active;

		if(ease == null)
		{
			var blend:Float = 1 - Math.pow(1 - speed, elapsed * 60 * rate);
			offsetX += (targetX - offsetX) * blend;
			offsetY += (targetY - offsetY) * blend;
			return;
		}

		if(targetX != target[0] || targetY != target[1])
		{
			target = [targetX, targetY];
			easeFrom = [offsetX, offsetY];
			easeProgress = 0;
		}

		easeProgress = Math.min(1, easeProgress + elapsed * rate / easeTime);
		var value:Float = ease(easeProgress);
		offsetX = easeFrom[0] + (target[0] - easeFrom[0]) * value;
		offsetY = easeFrom[1] + (target[1] - easeFrom[1]) * value;
	}

	public function reset()
	{
		player.set(0, 0);
		opponent.set(0, 0);
		offsetX = offsetY = 0;
		target = [0, 0];
		easeFrom = [0, 0];
		easeProgress = 1;
	}

	public function destroy()
	{
		FlxG.signals.preDraw.remove(applyOffset);
		FlxG.signals.postDraw.remove(removeOffset);
		camera = null;
	}

	function applyOffset()
	{
		if(camera == null || !camera.exists) return;
		drawX = offsetX;
		drawY = offsetY;
		camera.scroll.add(drawX, drawY);
	}

	function removeOffset()
	{
		if(camera != null && camera.exists)
		{
			camera.scroll.subtract(drawX, drawY);
		}
		drawX = drawY = 0;
	}

	function updateSide(side:NoteCameraSide, elapsed:Float)
	{
		if(side.decayTimer > 0)
		{
			side.decayTimer -= elapsed;
			if(side.decayTimer <= 0) side.scale(DECAY);
		}
		if(side.resetTimer > 0)
		{
			side.resetTimer -= elapsed;
			if(side.resetTimer <= 0) side.set(0, 0);
		}
	}
}
