package funkin.editors.content;

import flixel.FlxSprite;
import flixel.util.FlxTimer;
import funkin.game.Character;

class Toy extends Character
{
	public static inline var TOY_HEIGHT:Int = 200;

	var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
	public var isDragging:Bool = false;
	public var grabAllowed:Bool = false;
	public var hitboxX:Float = 0;
	public var hitboxY:Float = 0;
	private var dragOffsetX:Float = 0;
	private var dragOffsetY:Float = 0;
	public var baseX:Float = 0;
	public var baseY:Float = 0;
	public var toyScale:Float = 1;
	public var toySizeMult:Float = 1;
	private var idleOffX:Float = 0;
	private var idleOffY:Float = 0;
	private var animHoldTimer:Float = 0;
	private var currentAnim:String = '';
	private var atlasMeasured:Bool = false;
	public var toyName:String = '';
	public var canAnimate:Bool = false;
	private var finishingAnim:Bool = false;
	private var finishTimer:Float = 0;

	public function new(x:Float, y:Float, character:String, isPlayer:Bool = false, name:String = '')
	{
		super(x, y, character, isPlayer);

		baseX = x;
		baseY = y;
		toyName = name;

		resetToIdle();
		applyToyScale();
	}

	function cacheIdleOffset()
	{
		idleOffX = 0;
		idleOffY = 0;

		for (name in ['idle', 'danceLeft', 'danceRight'])
		{
			var off = animOffsets.get(name);
			if(off != null && off.length > 1)
			{
				idleOffX = off[0];
				idleOffY = off[1];
				return;
			}
		}
	}

	function applyToyScale()
	{
		cacheIdleOffset();
		if(isAnimateAtlas)
		{
			atlasMeasured = false;
			toyScale = 1;
			scale.set(1, 1);
			scrollFactor.set();
			return;
		}
		var h:Float = measuredHeight();
		toyScale = (h > 0) ? (TOY_HEIGHT * toySizeMult) / h : 1;

		scale.set(toyScale, toyScale);
		scrollFactor.set();
		applyToyOffset();
	}

	function measuredHeight():Float
	{
		if(frame != null && frame.frame != null && frame.frame.height > 0)
			return frame.frame.height;

		return frameHeight;
	}

	function applyToyOffset()
	{
		if(isAnimateAtlas)
		{
			var offScale:Float = (jsonScale > 0) ? toyScale / jsonScale : toyScale;
			var off = animOffsets.get(getAnimationName());
			var ox:Float = (off != null && off.length > 1) ? (off[0] - idleOffX) * offScale : 0;
			var oy:Float = (off != null && off.length > 1) ? (off[1] - idleOffY) * offScale : 0;

			offset.set(ox, oy);
			hitboxX = x + atlas.relativeX;
			hitboxY = y + atlas.relativeY;
			width = atlas.width;
			height = atlas.height;
			return;
		}

		width = frameWidth * toyScale;
		height = frameHeight * toyScale;
		centerOrigin();

		var off = animOffsets.get(getAnimationName());
		var ox:Float = (off != null && off.length > 1) ? off[0] : 0;
		var oy:Float = (off != null && off.length > 1) ? off[1] : 0;

		var offScale:Float = (jsonScale > 0) ? toyScale / jsonScale : toyScale;
		ox = (ox - idleOffX) * offScale;
		oy = (oy - idleOffY) * offScale;

		offset.set(frameWidth * (1 - toyScale) * 0.5 + ox,
		frameHeight * (1 - toyScale) * 0.5 + oy);

		hitboxX = x - ox;
		hitboxY = y - oy;
	}

	override public function overlapsPoint(point:FlxPoint, InScreenSpace:Bool = false, ?Camera:FlxCamera):Bool
	{
		if(!InScreenSpace)
		{
			var result:Bool = (point.x >= hitboxX) && (point.x < hitboxX + width) && (point.y >= hitboxY) && (point.y < hitboxY + height);
			point.putWeak();
			return result;
		}

		if(Camera == null) Camera = FlxG.camera;

		var xPos:Float = point.x - Camera.scroll.x;
		var yPos:Float = point.y - Camera.scroll.y;
		point.putWeak();

		return (xPos >= hitboxX) && (xPos < hitboxX + width) && (yPos >= hitboxY) && (yPos < hitboxY + height);
	}

	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		super.playAnim(AnimName, Force, Reversed, Frame);
		applyToyOffset();
	}

	public function setToySize(mult:Float)
	{
		toySizeMult = FlxMath.bound(mult, 0.25, 4);
		applyToyScale();
	}

	public function changeToySize(delta:Float)
	{
		setToySize(toySizeMult + delta);

		@:privateAccess
		if(funkin.editors.ChartingState.instance != null)
			funkin.editors.ChartingState.instance.saveToySize(toyName, toySizeMult);
	}

	public function changeToyCharacter(character:String)
	{
		if(character == null || character == curCharacter) return;

		changeCharacter(character);
		resetToIdle();
		applyToyScale();
	}

	public function setAnimated(v:Bool)
	{
		if(canAnimate == v) return;

		canAnimate = v;
		if(v)
		{
			finishingAnim = false;
			return;
		}

		if(animation.curAnim != null && !animation.curAnim.finished)
		{
			finishingAnim = true;
			finishTimer = 2;
			return;
		}

		resetToIdle();
	}

	public function resetToIdle()
	{
		finishingAnim = false;
		animHoldTimer = 0;
		currentAnim = '';
		color = FlxColor.WHITE;

		super.dance();
		if(animation.curAnim != null) animation.curAnim.curFrame = 0;

		x = baseX;
		y = baseY;
	}

	function isIdlePlaying():Bool
	{
		var anim = animation.curAnim;
		if(anim == null || anim.finished) return false;

		return anim.name.startsWith('idle') || anim.name.startsWith('dance');
	}

	public function performPose(direction:String, sustainLength:Float = 0, noteColor:FlxColor = FlxColor.WHITE)
	{
		if(!canAnimate) return;

		var animName:String = direction.toLowerCase();

		if(!animOffsets.exists(animName))
			animName = 'sing$direction';

		currentAnim = animName;

		var baseHoldTime:Float = Conductor.stepCrochet * 4 / 1000;
		var sustainTime:Float = sustainLength / 1000;

		animHoldTimer = Math.max(baseHoldTime, sustainTime + baseHoldTime);

		playAnim(animName, true);

		this.color = noteColor;

		x = baseX;
		y = baseY;
	}

	override public function update(elapsed:Float):Void
	{
		if(!visible) return;
		if(isAnimateAtlas)
		{
			atlas.update(elapsed);

			if(!atlasMeasured && atlas.height > 0)
			{
				var nativeH:Float = atlas.height / Math.max(scale.y, 0.001);
				if(nativeH > 0)
				{
					atlasMeasured = true;
					toyScale = (TOY_HEIGHT * toySizeMult) / nativeH;
					scale.set(toyScale, toyScale);
				}
			}
		}
		if(animHoldTimer > 0 && (canAnimate || finishingAnim))
		{
			animHoldTimer -= elapsed;
			if(animHoldTimer <= 0)
			{
				animHoldTimer = 0;
				currentAnim = '';
				this.color = FlxColor.WHITE;
				dance();
				x = baseX;
				y = baseY;
			}
		}

		if(grabAllowed && FlxG.mouse.justPressed && !isDragging)
		{
			isDragging = true;
			dragOffsetX = FlxG.mouse.screenX - baseX;
			dragOffsetY = FlxG.mouse.screenY - baseY;
			alpha = 0.6;
		}

		if(isDragging)
		{
			baseX = FlxG.mouse.screenX - dragOffsetX;
			baseY = FlxG.mouse.screenY - dragOffsetY;
			x = baseX;
			y = baseY;

			if(FlxG.mouse.justReleased)
			{
				isDragging = false;
				alpha = 1.0;

				@:privateAccess
				if(funkin.editors.ChartingState.instance != null)
					funkin.editors.ChartingState.instance.saveToyPosition(toyName, baseX, baseY);
			}
		}

		if((canAnimate || finishingAnim) && animation.curAnim != null)
			animation.curAnim.update(elapsed);

		if(finishingAnim)
		{
			finishTimer -= elapsed;
			if(finishTimer <= 0 || isAnimationNull() || isAnimationFinished())
				resetToIdle();
		}

		applyToyOffset();
	}

	override public function dance():Void
	{
		if(isDragging || animHoldTimer > 0 || finishingAnim) return;
		if(!canAnimate || isIdlePlaying()) return;

		super.dance();
		x = baseX;
		y = baseY;
	}
}