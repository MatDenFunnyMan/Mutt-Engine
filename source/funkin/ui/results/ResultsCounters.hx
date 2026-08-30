package funkin.ui.results;

import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

class ClearPercentCounter extends FlxSpriteGroup
{
	public var small:Bool = false;
	public var curNumber(default, set):Int = 0;

	var digits:Array<FlxSprite> = [];
	var label:FlxSprite;

	public function new(x:Float, y:Float, value:Int = 0, small:Bool = false)
	{
		super(x, y);
		this.small = small;

		label = new FlxSprite(0, 0);
		label.loadGraphic(Paths.image('results/clearPercent/' + (small ? 'clearPercentTextSmall' : 'clearPercentText')));
		label.antialiasing = ClientPrefs.data.antialiasing;
		add(label);

		curNumber = value;
	}

	function set_curNumber(value:Int):Int
	{
		curNumber = value;
		rebuild();
		return value;
	}

	function rebuild()
	{
		for(digit in digits)
		{
			remove(digit, true);
			digit.destroy();
		}
		digits = [];

		var text:String = Std.string(Std.int(Math.max(0, curNumber)));
		var xPos:Float = 0;

		for(i in 0...text.length)
		{
			var isLast:Bool = (i == text.length - 1);
			var atlas:String = small ? 'clearPercentNumberSmall' : (isLast ? 'clearPercentNumberRight' : 'clearPercentNumberLeft');

			var digit:FlxSprite = new FlxSprite(xPos, 0);
			digit.frames = Paths.getSparrowAtlas('results/clearPercent/$atlas');
			digit.animation.addByPrefix('digit', 'number ' + text.charAt(i), 24, false);
			digit.animation.play('digit');
			digit.animation.pause();
			digit.antialiasing = ClientPrefs.data.antialiasing;
			digit.updateHitbox();
			add(digit);
			digits.push(digit);

			xPos += digit.width;
		}

		label.x = xPos + (small ? 4 : 10);
		label.y = small ? 0 : 20;
	}
}

class ScoreCounter extends FlxSpriteGroup
{
	public static var DIGIT_NAMES:Array<String> = [
		'ZERO DIGITAL', 'ONE DIGITAL', 'TWO DIGITAL', 'THREE DIGITAL', 'FOUR DIGITAL',
		'FIVE DIGITAL', 'SIX DIGITAL', 'SEVEN DIGITAL', 'EIGHT DIGITAL', 'NINE DIGITAL'
	];

	public var digitCount:Int = 7;
	public var curNumber(default, set):Int = 0;

	var digits:Array<FlxSprite> = [];

	public function new(x:Float, y:Float, digitCount:Int = 7)
	{
		super(x, y);
		this.digitCount = digitCount;

		var xPos:Float = 0;
		for(i in 0...digitCount)
		{
			var digit:FlxSprite = new FlxSprite(xPos, 0);
			digit.frames = Paths.getSparrowAtlas('results/score-digital-numbers');

			for(num in 0...DIGIT_NAMES.length)
				digit.animation.addByPrefix('$num', DIGIT_NAMES[num], 24, false);

			digit.animation.addByPrefix('disabled', 'DISABLED', 24, false);
			digit.animation.addByPrefix('gone', 'GONE', 24, false);
			digit.animation.play('disabled');
			digit.antialiasing = ClientPrefs.data.antialiasing;
			digit.updateHitbox();
			add(digit);
			digits.push(digit);

			xPos += digit.width;
		}
	}

	function set_curNumber(value:Int):Int
	{
		curNumber = value;

		var text:String = Std.string(Std.int(Math.max(0, value)));
		while(text.length < digitCount) text = ' ' + text;

		for(i in 0...digits.length)
		{
			var char:String = text.charAt(i);
			if(char == ' ')
			{
				digits[i].animation.play('disabled');
				continue;
			}

			if(digits[i].animation.name != char) digits[i].animation.play(char, true);
		}

		return value;
	}
}

class TallyCounter extends FlxSpriteGroup
{
	public var curNumber(default, set):Int = 0;

	var label:FlxText;
	var digits:Array<FlxSprite> = [];
	var digitStart:Float = 0;

	public function new(x:Float, y:Float, name:String, value:Int = 0, ?labelColor:FlxColor)
	{
		super(x, y);

		label = new FlxText(0, 0, 0, name, 20);
		label.setFormat(Paths.font('vcr.ttf'), 20, labelColor != null ? labelColor : FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		label.borderSize = 1;
		add(label);

		digitStart = 320;
		curNumber = value;
	}

	function set_curNumber(value:Int):Int
	{
		curNumber = value;

		for(digit in digits)
		{
			remove(digit, true);
			digit.destroy();
		}
		digits = [];

		var text:String = Std.string(Std.int(Math.max(0, value)));
		var xPos:Float = digitStart;

		for(i in 0...text.length)
		{
			var digit:FlxSprite = new FlxSprite(xPos, -6);
			digit.frames = Paths.getSparrowAtlas('results/tallieNumber');
			digit.animation.addByPrefix('digit', text.charAt(i) + ' small', 24, false);
			digit.animation.play('digit');
			digit.animation.pause();
			digit.antialiasing = ClientPrefs.data.antialiasing;
			digit.updateHitbox();
			add(digit);
			digits.push(digit);

			xPos += digit.width;
		}

		return value;
	}
}
