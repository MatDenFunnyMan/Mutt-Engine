package funkin.ui.freeplay;

class FreeplayDifficulty extends FlxTypedGroup<FlxSprite>
{
	static inline final CENTER_X:Float = 200;
	static inline final CENTER_Y:Float = 72;
	static inline final LEFT_ARROW_X:Float = 27;
	static inline final RIGHT_ARROW_X:Float = 328;
	static inline final SLIDE_DISTANCE:Float = 160;
	static inline final SLIDE_TIME:Float = 0.2;
	static inline final MAX_WIDTH:Float = 260;

	public var leftArrow:FlxSprite;
	public var rightArrow:FlxSprite;

	var sprites:Map<String, FlxSprite> = [];
	var current:FlxSprite;
	var currentKey:String;

	public function new(selectorAsset:String)
	{
		super();
		leftArrow = new FlxSprite(LEFT_ARROW_X, 0);
		rightArrow = new FlxSprite(RIGHT_ARROW_X, 0);
		rightArrow.flipX = true;
		add(leftArrow);
		add(rightArrow);
		setStyle(selectorAsset);
	}

	public function setStyle(selectorAsset:String)
	{
		for (arrow in [leftArrow, rightArrow])
		{
			arrow.frames = Paths.getSparrowAtlas(selectorAsset);
			arrow.animation.addByPrefix('shine', 'arrow pointer loop', 24);
			arrow.animation.play('shine');
			arrow.antialiasing = ClientPrefs.data.antialiasing;
			arrow.scale.set(1, 1);
			arrow.setColorTransform();
			arrow.updateHitbox();
			arrow.y = CENTER_Y - arrow.height / 2;
		}
	}

	public function setArrowsVisible(value:Bool)
	{
		leftArrow.visible = rightArrow.visible = value;
	}

	public function setPressed(left:Bool, right:Bool)
	{
		pressArrow(leftArrow, left);
		pressArrow(rightArrow, right);
	}

	function pressArrow(arrow:FlxSprite, pressed:Bool)
	{
		if(pressed == (arrow.scale.x < 1)) return;

		if(pressed)
		{
			arrow.scale.set(0.5, 0.5);
			arrow.setColorTransform(0, 0, 0, 1, 255, 255, 255);
		}
		else
		{
			arrow.scale.set(1, 1);
			arrow.setColorTransform();
		}
	}

	public function show(name:String, displayName:String, change:Int = 0)
	{
		var key:String = Paths.formatToSongPath(name);
		if(key == currentKey) return;

		var next:FlxSprite = sprites.get(key);
		if(next == null)
		{
			next = makeSprite(key, displayName);
			sprites.set(key, next);
			add(next);
		}

		var restX:Float = CENTER_X - next.width / 2;
		next.y = CENTER_Y - next.height / 2;
		FlxTween.cancelTweensOf(next);
		next.visible = true;

		if(current != null && current != next)
		{
			var old:FlxSprite = current;
			FlxTween.cancelTweensOf(old);
			if(change != 0)
			{
				var outX:Float = CENTER_X - old.width / 2 - change * SLIDE_DISTANCE;
				FlxTween.tween(old, {x: outX, alpha: 0}, SLIDE_TIME, {ease: FlxEase.circInOut, onComplete: function(_) old.visible = false});
			}
			else old.visible = false;
		}

		if(change != 0)
		{
			next.x = restX + change * SLIDE_DISTANCE;
			next.alpha = 0;
			FlxTween.tween(next, {x: restX, alpha: 1}, SLIDE_TIME, {ease: FlxEase.circInOut});
		}
		else
		{
			next.x = restX;
			next.alpha = 1;
		}

		current = next;
		currentKey = key;
	}

	function makeSprite(key:String, displayName:String):FlxSprite
	{
		var path:String = 'freeplay/freeplayDifficulties/freeplay' + key;
		var spr:FlxSprite = null;

		if(Paths.fileExists('images/$path.xml', TEXT))
		{
			spr = new FlxSprite();
			spr.frames = Paths.getSparrowAtlas(path);
			spr.animation.addByPrefix('idle', 'idle0', 24, true);
			spr.animation.play('idle');
			if(!ClientPrefs.data.flashing) spr.animation.pause();
		}
		else if(Paths.fileExists('images/$path.png', IMAGE))
			spr = new FlxSprite().loadGraphic(Paths.image(path));
		else if(Paths.fileExists('images/menudifficulties/$key.png', IMAGE))
			spr = new FlxSprite().loadGraphic(Paths.image('menudifficulties/$key'));
		else
		{
			var text:FlxText = new FlxText(0, 0, 0, displayName.toUpperCase(), 56);
			text.setFormat(Paths.font('vcr.ttf'), 56, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.borderSize = 3;
			spr = text;
		}

		spr.antialiasing = ClientPrefs.data.antialiasing;
		if(spr.width > MAX_WIDTH)
		{
			spr.setGraphicSize(Std.int(MAX_WIDTH));
		}
		spr.updateHitbox();
		spr.visible = false;
		return spr;
	}
}
