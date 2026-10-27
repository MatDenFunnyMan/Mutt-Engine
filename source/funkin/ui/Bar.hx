package funkin.ui;

import flixel.math.FlxRect;

class Bar extends FlxSpriteGroup
{
	public var leftBar:FlxSprite;
	public var rightBar:FlxSprite;
	public var bg:FlxSprite;
	public var valueFunction:Void->Float = null;
	public var percent(default, set):Float = 0;
	public var shownPercent(default, null):Float = 0;
	public var smooth:Bool = false;
	public var smoothSpeed:Float = 9;
	public var bounds:Dynamic = {min: 0, max: 1};
	public var leftToRight(default, set):Bool = true;
	public var barCenter(default, null):Float = 0;
	public var centerY(get, never):Float;

	public var barWidth(default, set):Int = 1;
	public var barHeight(default, set):Int = 1;
	public var barOffset:FlxPoint = new FlxPoint(3, 3);

	public var baseWidth(default, null):Int = 1;
	public var baseHeight(default, null):Int = 1;
	public var customFill(default, null):String = null;
	public var customBackground(default, null):String = null;
	public var customScale:Float = 1;
	public var customOffset:FlxPoint = new FlxPoint();
	public var fillScale:FlxPoint = new FlxPoint(1, 1);
	public var fillShift:FlxPoint = new FlxPoint();

	var defaultImage:String;
	var fillOffset:FlxPoint = new FlxPoint();

	public function new(x:Float, y:Float, image:String = 'healthBar', valueFunction:Void->Float = null, boundX:Float = 0, boundY:Float = 1)
	{
		super(x, y);

		this.valueFunction = valueFunction;
		defaultImage = image;
		setBounds(boundX, boundY);

		bg = new FlxSprite().loadGraphic(Paths.image(image));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		baseWidth = Std.int(bg.width);
		baseHeight = Std.int(bg.height);
		barWidth = Std.int(bg.width - 6);
		barHeight = Std.int(bg.height - 6);

		leftBar = new FlxSprite().makeGraphic(Std.int(bg.width), Std.int(bg.height), FlxColor.WHITE);
		leftBar.antialiasing = antialiasing = ClientPrefs.data.antialiasing;

		rightBar = new FlxSprite().makeGraphic(Std.int(bg.width), Std.int(bg.height), FlxColor.WHITE);
		rightBar.color = FlxColor.BLACK;
		rightBar.antialiasing = ClientPrefs.data.antialiasing;

		add(leftBar);
		add(rightBar);
		add(bg);
		regenerateClips();
	}

	public var enabled:Bool = true;
	var snapNext:Bool = true;
	override function update(elapsed:Float) {
		if(!enabled)
		{
			super.update(elapsed);
			return;
		}

		if(valueFunction != null)
		{
			var value:Null<Float> = FlxMath.remapToRange(FlxMath.bound(valueFunction(), bounds.min, bounds.max), bounds.min, bounds.max, 0, 100);
			percent = (value != null ? value : 0);
		}
		else percent = 0;

		if(snapNext)
		{
			snapNext = false;
			shownPercent = percent;
			updateBar();
		}
		else if(smooth && shownPercent != percent)
		{
			shownPercent = FlxMath.lerp(percent, shownPercent, Math.exp(-elapsed * smoothSpeed));
			if(Math.abs(shownPercent - percent) < 0.01) shownPercent = percent;
			updateBar();
		}
		super.update(elapsed);
	}

	public function setBounds(min:Float, max:Float)
	{
		bounds.min = min;
		bounds.max = max;
	}

	public function setColors(left:FlxColor = null, right:FlxColor = null)
	{
		if (left != null)
			leftBar.color = left;
		if (right != null)
			rightBar.color = right;
	}

	public function snap()
	{
		shownPercent = percent;
		updateBar();
	}

	public function setFill(image:String, ?prefix:String, ?fps:Float)
	{
		var color1:FlxColor = leftBar.color;
		var color2:FlxColor = rightBar.color;
		customFill = (image != null && image.length > 0) ? image : null;

		for (bar in [leftBar, rightBar])
		{
			if(customFill != null) loadAnimated(bar, customFill, prefix, fps);
			else
			{
				bar.makeGraphic(baseWidth, baseHeight, FlxColor.WHITE);
				bar.animation.destroyAnimations();
			}
		}
		leftBar.color = color1;
		rightBar.color = color2;
		layout();
	}

	public function setBackground(image:String, ?prefix:String, ?fps:Float)
	{
		customBackground = (image != null && image.length > 0) ? image : null;
		if(customBackground != null) loadAnimated(bg, customBackground, prefix, fps);
		else
		{
			bg.loadGraphic(Paths.image(defaultImage));
			bg.animation.destroyAnimations();
		}
		layout();
	}

	public function resetGraphics()
	{
		customScale = 1;
		customOffset.set();
		fillScale.set(1, 1);
		fillShift.set();
		setBackground(null);
		setFill(null);
	}

	function loadAnimated(sprite:FlxSprite, image:String, ?prefix:String, ?fps:Float)
	{
		var xml:Bool = Paths.fileExists('images/$image.xml', TEXT);
		if(xml)
		{
			sprite.frames = Paths.getSparrowAtlas(image);
			sprite.animation.addByPrefix('idle', (prefix != null) ? prefix : '', (fps != null && fps > 0) ? fps : 24, true);
			if(sprite.animation.getByName('idle') != null) sprite.animation.play('idle', true);
		}
		else
		{
			sprite.loadGraphic(Paths.image(image));
			sprite.animation.destroyAnimations();
		}
		sprite.antialiasing = ClientPrefs.data.antialiasing;
	}

	public function layout()
	{
		var centerX:Float = x + baseWidth / 2 + customOffset.x;
		var middleY:Float = y + baseHeight / 2 + customOffset.y;
		var scale:Float = 1;

		if(customFill != null)
			scale = (baseWidth - 6) / Math.max(1, leftBar.frameWidth) * customScale;
		else if(customBackground != null)
			scale = baseWidth / Math.max(1, bg.frameWidth) * customScale;

		bg.visible = (customBackground != null || customFill == null);
		bg.scale.set(customBackground != null ? scale : 1, customBackground != null ? scale : 1);
		bg.updateHitbox();
		bg.setPosition(centerX - bg.width / 2, middleY - bg.height / 2);

		if(customFill != null)
		{
			for (bar in [leftBar, rightBar])
			{
				bar.scale.set(scale * fillScale.x, scale * fillScale.y);
				bar.updateHitbox();
			}
			fillOffset.set(centerX - leftBar.width / 2 - bg.x + fillShift.x, middleY - leftBar.height / 2 - bg.y + fillShift.y);
			@:bypassAccessor barWidth = leftBar.frameWidth;
			@:bypassAccessor barHeight = leftBar.frameHeight;
			barOffset.set(0, 0);
			leftBar.clipRect = new FlxRect(0, 0, leftBar.frameWidth, leftBar.frameHeight);
			rightBar.clipRect = new FlxRect(0, 0, rightBar.frameWidth, rightBar.frameHeight);
			updateBar();
		}
		else
		{
			fillOffset.set(0, 0);
			@:bypassAccessor barWidth = Std.int(bg.width - 6);
			@:bypassAccessor barHeight = Std.int(bg.height - 6);
			barOffset.set(3, 3);
			regenerateClips();
		}
	}

	public function updateBar()
	{
		if(leftBar == null || rightBar == null) return;

		leftBar.setPosition(bg.x + fillOffset.x, bg.y + fillOffset.y);
		rightBar.setPosition(bg.x + fillOffset.x, bg.y + fillOffset.y);

		var shown:Float = smooth ? shownPercent : percent;
		var leftSize:Float = 0;
		if(leftToRight) leftSize = FlxMath.lerp(0, barWidth, shown / 100);
		else leftSize = FlxMath.lerp(0, barWidth, 1 - shown / 100);

		leftBar.clipRect.width = leftSize;
		leftBar.clipRect.height = barHeight;
		leftBar.clipRect.x = barOffset.x;
		leftBar.clipRect.y = barOffset.y;

		rightBar.clipRect.width = barWidth - leftSize;
		rightBar.clipRect.height = barHeight;
		rightBar.clipRect.x = barOffset.x + leftSize;
		rightBar.clipRect.y = barOffset.y;

		barCenter = leftBar.x + (leftSize + barOffset.x) * Math.abs(leftBar.scale.x);

		leftBar.clipRect = leftBar.clipRect;
		rightBar.clipRect = rightBar.clipRect;
	}

	public function regenerateClips()
	{
		if(leftBar != null)
		{
			leftBar.setGraphicSize(Std.int(bg.width), Std.int(bg.height));
			leftBar.updateHitbox();
			leftBar.clipRect = new FlxRect(0, 0, Std.int(bg.width), Std.int(bg.height));
		}
		if(rightBar != null)
		{
			rightBar.setGraphicSize(Std.int(bg.width), Std.int(bg.height));
			rightBar.updateHitbox();
			rightBar.clipRect = new FlxRect(0, 0, Std.int(bg.width), Std.int(bg.height));
		}
		if(customFill == null && leftBar != null && rightBar != null)
		{
			for (bar in [leftBar, rightBar])
			{
				bar.scale.set(bar.scale.x * fillScale.x, bar.scale.y * fillScale.y);
				bar.updateHitbox();
			}
			fillOffset.set((bg.width - leftBar.width) / 2 + fillShift.x, (bg.height - leftBar.height) / 2 + fillShift.y);
		}
		updateBar();
	}

	function get_centerY():Float
		return bg.y + bg.height / 2;

	private function set_percent(value:Float)
	{
		var doUpdate:Bool = false;
		if(value != percent) doUpdate = true;
		percent = value;
		if(!smooth) shownPercent = value;

		if(doUpdate) updateBar();
		return value;
	}

	private function set_leftToRight(value:Bool)
	{
		leftToRight = value;
		updateBar();
		return value;
	}

	private function set_barWidth(value:Int)
	{
		barWidth = value;
		regenerateClips();
		return value;
	}

	private function set_barHeight(value:Int)
	{
		barHeight = value;
		regenerateClips();
		return value;
	}
}
