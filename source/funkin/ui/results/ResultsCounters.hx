package funkin.ui.results;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

class ClearPercentCounter extends FlxTypedSpriteGroup<FlxSprite>
{
	public var curNumber(default, set):Int = 0;

	var small:Bool = false;
	var numberChanged:Bool = false;

	public function new(x:Float, y:Float, startingNumber:Int = 0, small:Bool = false)
	{
		super(x, y);

		this.small = small;
		curNumber = startingNumber;

		var text:FlxSprite = new FlxSprite(small ? 40 : 0, 0);
		text.loadGraphic(Paths.image('results/clearPercent/clearPercentText' + (small ? 'Small' : '')));
		text.antialiasing = ClientPrefs.data.antialiasing;
		add(text);

		drawNumbers();
	}

	function set_curNumber(value:Int):Int
	{
		numberChanged = true;
		return curNumber = value;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(numberChanged) drawNumbers();
	}

	function drawNumbers()
	{
		numberChanged = false;

		var separated:Array<Int> = [];
		var temp:Int = Math.round(curNumber);

		while(temp != 0)
		{
			separated.push(temp % 10);
			temp = Math.floor(temp / 10);
		}
		if(separated.length == 0) separated.push(0);
		separated.reverse();

		for(ind in 0...separated.length)
		{
			var digitIndex:Int = ind + 1;
			var digitOffset:Int = (separated.length == 1) ? 1 : (separated.length == 3) ? -1 : 0;
			var digitSize:Float = small ? 32 : 72;
			var digitHeightOffset:Float = small ? -4 : 0;

			var xPos:Float = (digitIndex - 1 + digitOffset) * (digitSize * scale.x);
			xPos += small ? -24 : 0;

			var yPos:Float = (digitIndex - 1 + digitOffset) * (digitHeightOffset * scale.y);
			yPos += small ? 0 : 72;

			if(digitIndex >= members.length)
			{
				var variant:Bool = (separated.length == 3) ? (digitIndex >= 2) : (digitIndex >= 1);
				var numb:ClearPercentNumber = new ClearPercentNumber(xPos, yPos, separated[ind], variant, small);
				numb.scale.set(scale.x, scale.y);
				add(numb);
			}
			else
			{
				members[digitIndex].animation.play(Std.string(separated[ind]));
				members[digitIndex].x = xPos + this.x;
				members[digitIndex].y = yPos + this.y;
				members[digitIndex].visible = true;
			}
		}

		for(ind in (separated.length + 1)...members.length)
			members[ind].visible = false;
	}
}

class ClearPercentNumber extends FlxSprite
{
	public function new(x:Float, y:Float, digit:Int, variant:Bool, small:Bool)
	{
		super(x, y);

		var which:String = small ? 'Small' : (variant ? 'Right' : 'Left');
		frames = Paths.getSparrowAtlas('results/clearPercent/clearPercentNumber$which');

		for(i in 0...10) animation.addByPrefix('$i', 'number $i 0', 24, false);

		animation.play('$digit');
		antialiasing = ClientPrefs.data.antialiasing;
		updateHitbox();
	}
}

class TallyCounter extends FlxTypedSpriteGroup<FlxSprite>
{
	public var curNumber:Float = 0;
	public var neededNumber:Int = 0;
	public var flavour:FlxColor = FlxColor.WHITE;

	public function new(x:Float, y:Float, neededNumber:Int = 0, ?flavour:FlxColor)
	{
		super(x, y);

		if(flavour != null) this.flavour = flavour;
		this.neededNumber = neededNumber;

		if(curNumber == neededNumber) drawNumbers();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(curNumber < neededNumber) drawNumbers();
	}

	function drawNumbers()
	{
		var separated:Array<Int> = [];
		var temp:Int = Math.round(curNumber);

		while(temp != 0)
		{
			separated.push(temp % 10);
			temp = Math.floor(temp / 10);
		}
		if(separated.length == 0) separated.push(0);
		separated.reverse();

		for(ind in 0...separated.length)
		{
			if(ind >= members.length)
			{
				var numb:TallyNumber = new TallyNumber(ind * (43 * scale.x), 0, separated[ind]);
				numb.scale.set(scale.x, scale.y);
				add(numb);
				numb.color = flavour;
			}
			else
			{
				members[ind].animation.play(Std.string(separated[ind]));
				members[ind].color = flavour;
			}
		}
	}
}

class TallyNumber extends FlxSprite
{
	public function new(x:Float, y:Float, digit:Int)
	{
		super(x, y);

		frames = Paths.getSparrowAtlas('results/tallieNumber');
		for(i in 0...10) animation.addByPrefix(Std.string(i), i + ' small', 24, false);

		animation.play(Std.string(digit));
		antialiasing = ClientPrefs.data.antialiasing;
		updateHitbox();
	}
}

class ResultScore extends FlxTypedSpriteGroup<ScoreNum>
{
	public static var DIGIT_SPACING:Float = 85;

	public var scoreValue(default, set):Int = 0;

	var filledDigits:Int = 0;

	public function new(x:Float, y:Float, digitCount:Int = 10, value:Int = 0)
	{
		super(x, y);

		for(i in 0...digitCount) add(new ScoreNum(DIGIT_SPACING * i, 0));

		scoreValue = value;
	}

	function set_scoreValue(value:Int):Int
	{
		if(group == null || group.members == null) return value;

		filledDigits = 0;

		var index:Int = group.members.length - 1;
		var temp:Int = value;

		while(temp > 0 && index >= 0)
		{
			filledDigits++;
			group.members[index].finalDigit = temp % 10;
			temp = Math.floor(temp / 10);
			index--;
		}

		if(filledDigits == 0 && group.members.length > 0)
		{
			filledDigits = 1;
			group.members[group.members.length - 1].finalDigit = 0;
			index = group.members.length - 2;
		}

		while(index >= 0)
		{
			group.members[index].digit = 10;
			index--;
		}

		return scoreValue = value;
	}

	public function animateNumbers()
	{
		var start:Int = group.members.length - filledDigits;

		for(i in start...group.members.length)
		{
			var member:ScoreNum = group.members[i];
			var delay:Float = (i - 1) / 24;

			new FlxTimer().start(delay < 0 ? 0 : delay, function(_)
			{
				member.finalDelay = filledDigits - (i - 1);
				member.playAnim();
				member.shuffle();
			});
		}
	}
}

class ScoreNum extends FlxSprite
{
	public static var NAMES:Array<String> = [
		'ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE', 'DISABLED'
	];

	public var digit(default, set):Int = 10;
	public var finalDigit(default, set):Int = 10;
	public var finalDelay:Float = 0;

	var glow:Bool = true;
	var shuffleTimer:FlxTimer;

	public function new(x:Float, y:Float)
	{
		super(x, y);

		frames = Paths.getSparrowAtlas('results/score-digital-numbers');

		for(i in 0...10) animation.addByPrefix(NAMES[i], NAMES[i] + ' DIGITAL', 24, false);
		animation.addByPrefix('DISABLED', 'DISABLED', 24, false);
		animation.addByPrefix('GONE', 'GONE', 24, false);

		antialiasing = ClientPrefs.data.antialiasing;
		this.digit = 10;
		animation.play(NAMES[digit], true);
		updateHitbox();
	}

	function set_finalDigit(value:Int):Int
	{
		animation.play('GONE', true, false, 0);
		return finalDigit = value;
	}

	function set_digit(value:Int):Int
	{
		if(value >= 0 && value < NAMES.length && animation.curAnim != null && animation.curAnim.name != NAMES[value])
		{
			if(glow)
			{
				animation.play(NAMES[value], true, false, 0);
				glow = false;
			}
			else animation.play(NAMES[value], true, false, 4);

			updateHitbox();
			centerOffsets(false);
		}

		return digit = value;
	}

	public function playAnim()
		animation.play(NAMES[digit], true, false, 0);

	public function shuffle()
	{
		var interval:Float = 1 / 24;
		shuffleTimer = new FlxTimer().start(interval, shuffleProgress, Std.int((41 / 24) / interval));
	}

	function shuffleProgress(timer:FlxTimer)
	{
		var next:Int = digit + 1;
		if(next > 9 || next < 0) next = 0;
		digit = next;

		if(timer.loops > 0 && timer.loopsLeft == 0) finishShuffle();
	}

	function finishShuffle()
	{
		FlxTween.num(0, finalDigit, 23 / 24, {
			ease: FlxEase.quadOut,
			onComplete: function(_)
			{
				new FlxTimer().start(finalDelay / 24, function(_)
				{
					if(animation.curAnim != null) animation.play(animation.curAnim.name, true, false, 0);
				});
			}
		}, function(v:Float) digit = Math.floor(v));
	}
}
