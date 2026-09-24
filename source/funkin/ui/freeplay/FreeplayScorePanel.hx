package funkin.ui.freeplay;

class FreeplayScorePanel extends FlxTypedGroup<FlxSprite>
{
	static inline final HIGHSCORE_X:Float = 823;
	static inline final HIGHSCORE_Y:Float = 8;
	static inline final DIGIT_COUNT:Int = 7;
	static inline final DIGIT_X:Float = 903;
	static inline final DIGIT_Y:Float = 62;
	static inline final DIGIT_SPACING:Float = 48;
	static inline final DIGIT_SCALE:Float = 0.42;
	static inline final CLEAR_BOX_X:Float = 1132;
	static inline final CLEAR_BOX_Y:Float = 0;
	static inline final CLEAR_RIGHT:Float = 1204;
	static inline final CLEAR_Y:Float = 22;
	static final DIGIT_NAMES:Array<String> = ['ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE'];

	var highscore:FlxSprite;
	var digits:Array<FlxSprite> = [];
	var digitValues:Array<Int> = [];
	var clearBox:FlxSprite;
	var clearDigits:Array<FlxSprite> = [];

	var targetScore:Int = 0;
	var shownScore:Float = 0;
	var targetClear:Int = 0;
	var shownClear:Float = 0;
	var lastClear:Int = -1;
	var shineTimer:Float = 0;

	public function new(player:FreeplayPlayer)
	{
		super();

		highscore = new FlxSprite(HIGHSCORE_X, HIGHSCORE_Y);
		highscore.frames = Paths.getSparrowAtlas('freeplay/highscore');
		highscore.animation.addByPrefix('shine', 'highscore small instance 1', 24, false);
		highscore.animation.play('shine');
		highscore.antialiasing = ClientPrefs.data.antialiasing;
		add(highscore);

		for (i in 0...DIGIT_COUNT)
		{
			var digit:FlxSprite = new FlxSprite(DIGIT_X + DIGIT_SPACING * i, DIGIT_Y);
			digit.antialiasing = ClientPrefs.data.antialiasing;
			digits.push(digit);
			digitValues.push(-1);
			add(digit);
		}

		clearBox = new FlxSprite(CLEAR_BOX_X, CLEAR_BOX_Y).loadGraphic(Paths.image('freeplay/clearBox'));
		clearBox.antialiasing = ClientPrefs.data.antialiasing;
		add(clearBox);

		var clearFrames = Paths.getSparrowAtlas('freeplay/freeplay-clear');
		for (i in 0...3)
		{
			var clearDigit:FlxSprite = new FlxSprite(0, CLEAR_Y);
			clearDigit.frames = clearFrames;
			for (n in 0...10)
				clearDigit.animation.addByNames('$n', ['${n}0000'], 0, false);
			clearDigit.antialiasing = ClientPrefs.data.antialiasing;
			clearDigit.visible = false;
			clearDigits.push(clearDigit);
			add(clearDigit);
		}

		setStyle(player);
		shineTimer = FlxG.random.float(12, 50);
	}

	public function setStyle(player:FreeplayPlayer)
	{
		var numberFrames = Paths.getSparrowAtlas(player.numbersAsset);
		for (i in 0...digits.length)
		{
			var digit:FlxSprite = digits[i];
			digit.frames = numberFrames;
			for (name in DIGIT_NAMES)
				digit.animation.addByPrefix(name, '$name DIGITAL', 24, false);
			digit.scale.set(DIGIT_SCALE, DIGIT_SCALE);
			digitValues[i] = -1;
		}
		refreshDigits(Math.round(shownScore));
	}

	public function setValues(score:Int, clear:Int)
	{
		targetScore = score;
		targetClear = clear;
	}

	override function update(elapsed:Float)
	{
		shownScore = FlxMath.lerp(targetScore, shownScore, Math.exp(-elapsed * 24));
		if(Math.abs(shownScore - targetScore) <= 10) shownScore = targetScore;
		refreshDigits(Math.round(shownScore));

		shownClear = FlxMath.lerp(targetClear, shownClear, Math.exp(-elapsed * 12));
		if(Math.abs(shownClear - targetClear) <= 0.5) shownClear = targetClear;
		refreshClear(Math.round(shownClear));

		shineTimer -= elapsed;
		if(shineTimer <= 0)
		{
			highscore.animation.play('shine', true);
			shineTimer = FlxG.random.float(20, 60);
		}

		super.update(elapsed);
	}

	function refreshDigits(value:Int)
	{
		var maxValue:Int = Std.int(Math.pow(10, DIGIT_COUNT)) - 1;
		if(value > maxValue) value = maxValue;
		if(value < 0) value = 0;

		var i:Int = DIGIT_COUNT - 1;
		while(i >= 0)
		{
			var n:Int = value % 10;
			value = Std.int(value / 10);
			if(digitValues[i] != n)
			{
				var digit:FlxSprite = digits[i];
				digitValues[i] = n;
				digit.animation.play(DIGIT_NAMES[n], true);
				digit.updateHitbox();
				if(n == 1) digit.offset.x -= 15;
			}
			i--;
		}
	}

	function refreshClear(value:Int)
	{
		if(value == lastClear) return;
		lastClear = value;

		var text:String = Std.string(Std.int(FlxMath.bound(value, 0, 100)));
		var right:Float = CLEAR_RIGHT;
		for (i in 0...clearDigits.length)
		{
			var clearDigit:FlxSprite = clearDigits[i];
			var index:Int = text.length - 1 - i;
			clearDigit.visible = (index >= 0);
			if(index < 0) continue;

			clearDigit.animation.play(text.charAt(index), true);
			clearDigit.updateHitbox();
			right -= clearDigit.width;
			clearDigit.x = right;
			right -= 1;
		}
	}
}
