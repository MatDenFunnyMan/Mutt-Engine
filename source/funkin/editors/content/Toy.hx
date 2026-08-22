package funkin.editors.content;

import flixel.FlxSprite;
import flixel.util.FlxTimer;
import funkin.game.Character;

class Toy extends Character
{
	public static inline var TOY_HEIGHT:Int = 200;

	var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
	public var isDragging:Bool = false;
	private var dragOffsetX:Float = 0;
	private var dragOffsetY:Float = 0;
	public var baseX:Float = 0;
	public var baseY:Float = 0;
	public var toyScale:Float = 1;
	public var toySizeMult:Float = 1;
	private var animHoldTimer:Float = 0;
	private var currentAnim:String = '';
	public var toyName:String = '';
	public var canAnimate:Bool = false;

	public function new(x:Float, y:Float, character:String, isPlayer:Bool = false, name:String = '')
	{
		super(x, y, character, isPlayer);

		baseX = x;
		baseY = y;
		toyName = name;

		resetToIdle();
		applyToyScale();
	}

	function applyToyScale()
	{
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
		width = frameWidth * toyScale;
		height = frameHeight * toyScale;
		centerOrigin();

		var off = animOffsets.get(getAnimationName());
		var ox:Float = (off != null && off.length > 1) ? off[0] : 0;
		var oy:Float = (off != null && off.length > 1) ? off[1] : 0;

		offset.set(frameWidth * (1 - toyScale) * 0.5 + ox * toyScale,
		frameHeight * (1 - toyScale) * 0.5 + oy * toyScale);
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
		if(!v) resetToIdle();
	}

	public function resetToIdle()
	{
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
		if(animHoldTimer > 0)
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

		var mouseOverlap:Bool = FlxG.mouse.overlaps(this);

		if(mouseOverlap && FlxG.mouse.justPressed && !isDragging)
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

		if(canAnimate && animation.curAnim != null)
			animation.curAnim.update(elapsed);

		applyToyOffset();
	}

	override public function dance():Void
	{
		if(isDragging || animHoldTimer > 0) return;
		if(!canAnimate || isIdlePlaying()) return;

		super.dance();
		x = baseX;
		y = baseY;
	}
}