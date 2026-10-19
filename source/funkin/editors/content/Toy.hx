package funkin.editors.content;

import flixel.FlxSprite;
import flixel.util.FlxDestroyUtil;
import funkin.game.Character;
import funkin.game.InputSystem;

class Toy extends Character
{
	public static inline var TOY_HEIGHT:Int = 200;
	static inline var MEASURE_SCALE:Float = 0.05;
	static var atlasHeights:Map<String, Float> = [];
	static final singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

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
	private var measuringAtlas:Bool = false;
	public var toyName:String = '';
	public var canAnimate:Bool = false;
	private var finishingAnim:Bool = false;
	private var finishTimer:Float = 0;

	private var holdTime:Float = 0;
	private var holdStep:Float = 0;
	private var holdPiece:Int = 0;
	private var holdPieces:Int = 0;
	private var holdAnim:String = '';
	private var holdNoAnim:Bool = false;

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
		scrollFactor.set();
		if(isAnimateAtlas)
		{
			var nativeH:Null<Float> = atlasHeights.get(curCharacter);
			measuringAtlas = (nativeH == null || nativeH <= 0);
			toyScale = measuringAtlas ? MEASURE_SCALE : (TOY_HEIGHT * toySizeMult) / nativeH;
			scale.set(toyScale, toyScale);
			applyToyOffset();
			return;
		}
		measuringAtlas = false;
		var h:Float = measuredHeight();
		toyScale = (h > 0) ? (TOY_HEIGHT * toySizeMult) / h : 1;

		scale.set(toyScale, toyScale);
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

	override public function draw():Void
	{
		var drawnScale:Float = scale.y;
		super.draw();

		if(!measuringAtlas || !isAnimateAtlas || atlas == null || atlas.height <= 0 || drawnScale <= 0) return;

		atlasHeights.set(curCharacter, atlas.height / drawnScale);
		applyToyScale();
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

		if(atlas != null) atlas = FlxDestroyUtil.destroy(atlas);
		idleSuffix = '';
		danceEveryNumBeats = 2;
		settingCharacterUp = true;
		changeCharacter(character);
		resetToIdle();
		applyToyScale();
	}

	public function setIdleSuffix(suffix:String)
	{
		if(suffix == null) suffix = '';
		if(idleSuffix == suffix) return;

		idleSuffix = suffix;
		recalculateDanceIdle();
	}

	public function setAnimated(v:Bool)
	{
		if(canAnimate == v) return;

		canAnimate = v;
		holdPieces = 0;
		if(v)
		{
			finishingAnim = false;
			return;
		}

		if(!isAnimationNull() && !isAnimationFinished())
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
		holdPieces = 0;
		holdTimer = 0;
		heyTimer = 0;
		specialAnim = false;
		loopAnim = null;
		canPlayOtherAnims = true;
		color = FlxColor.WHITE;

		super.dance();
		if(!isAnimationNull())
		{
			if(isAnimateAtlas) atlas.anim.curFrame = 0;
			else animation.curAnim.curFrame = 0;
		}

		x = baseX;
		y = baseY;
	}

	public function sing(direction:Int, suffix:String, noteTime:Float, sustainLength:Float, noAnimation:Bool, hey:Bool, noteColor:FlxColor)
	{
		if(!canAnimate) return;

		holdTime = noteTime;
		holdStep = Conductor.stepCrochet;
		holdPieces = (sustainLength > 0 && holdStep > 0) ? Math.round(sustainLength / holdStep) : 0;
		holdPiece = 0;
		holdAnim = singAnimations[direction % singAnimations.length] + suffix;
		holdNoAnim = noAnimation || vsliceSustains || InputSystem.isVSlice();

		var heyAnim:String = (toyName == 'gf') ? 'cheer' : 'hey';
		if(hey && hasAnimation(heyAnim))
		{
			playAnim(heyAnim, true);
			specialAnim = true;
			heyTimer = 0.6;
		}
		else if(!noAnimation)
		{
			playAnim(holdAnim, true);
			holdTimer = 0;
			color = noteColor;
		}

		updateHold();
	}

	public function playEventAnim(anim:String, forced:Bool, loop:Bool)
	{
		if(!canAnimate) return;

		holdPieces = 0;
		if(anim == null || anim.length < 1) stopSpecialAnim();
		else if(hasAnimation(anim)) playSpecialAnim(anim, forced, loop);
	}

	public function playLegacyEventAnim(anim:String)
	{
		if(!canAnimate || anim == null || !hasAnimation(anim)) return;

		holdPieces = 0;
		playAnim(anim, true);
		specialAnim = true;
	}

	function updateHold()
	{
		if(holdPiece >= holdPieces) return;

		var pos:Float = Conductor.songPosition;
		if(pos < holdTime)
		{
			holdPieces = 0;
			return;
		}

		var reached:Int = Std.int(Math.min(holdPieces, Math.floor((pos - holdTime) / holdStep) + 1));
		if(reached <= holdPiece) return;

		holdPiece = reached;
		sustainHit();
	}

	function sustainHit()
	{
		var anim:String = getAnimationName();
		if(anim != null && anim.startsWith('sing')) holdTimer = 0;
		if(holdNoAnim) return;

		var animToPlay:String = holdAnim;
		var hold:String = holdAnim + '-hold';
		if(hasAnimation(hold)) animToPlay = hold;
		if(anim != hold && anim != hold + '-loop') playAnim(animToPlay, true);
		holdTimer = 0;
	}

	function updateDrag()
	{
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
	}

	override public function update(elapsed:Float):Void
	{
		if(!visible) return;

		if(canAnimate || finishingAnim)
		{
			updateHold();
			super.update(elapsed);

			var anim:String = getAnimationName();
			if(isPlayer && anim != null && anim.startsWith('sing') && !anim.endsWith('miss') &&
				holdTimer > Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
				dance();

			if(finishingAnim)
			{
				finishTimer -= elapsed;
				if(finishTimer <= 0 || isAnimationNull() || isAnimationFinished())
					resetToIdle();
			}
		}

		updateDrag();
		applyToyOffset();
	}

	override public function dance():Void
	{
		if(!canAnimate && !finishingAnim) return;

		color = FlxColor.WHITE;
		super.dance();
	}
}
