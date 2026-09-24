package funkin.ui.freeplay;

import funkin.ui.HealthIcon;
import funkin.ui.results.ResultsRank;

class FreeplaySongRow extends FlxTypedGroup<FlxSprite>
{
	static inline final ICON_WIDTH:Float = 110;
	static inline final TEXT_GAP:Float = 35;
	static inline final TEXT_HEIGHT:Float = 70;
	static inline final MAX_TEXT_WIDTH:Float = 520;
	static inline final MIN_TEXT_SQUASH:Float = 0.7;
	static inline final ICON_SCALE:Float = 0.8;
	static inline final RANK_GAP:Float = 20;
	static inline final RANK_SIZE:Float = 50;
	static inline final RANK_SCALE:Float = 0.8;

	public var icon:HealthIcon;
	public var symbol:Alphabet;
	public var text:Alphabet;
	public var rankBadge:FlxSprite;
	public var rank(default, null):Null<ResultsRank> = null;

	var baseTextWidth:Float = 1;
	var baseSymbolWidth:Float = 1;
	var fitX:Float = 1;
	var fitY:Float = 1;
	var lastScale:Float = -1;
	var shakeTime:Float = 0;
	var shakeDuration:Float = 0;
	var shakeAmount:Float = 0;
	var shakeX:Float = 0;
	var shakeY:Float = 0;

	public function new(name:String, iconName:String, isRandom:Bool = false)
	{
		super();

		if(isRandom)
		{
			symbol = new Alphabet(0, 0, '?', true);
			baseSymbolWidth = Math.max(1, symbol.width);
			add(symbol);
		}
		else
		{
			icon = new HealthIcon(iconName);
			add(icon);
		}

		text = new Alphabet(0, 0, name, true);
		baseTextWidth = Math.max(1, text.width);
		fitX = Math.min(1, MAX_TEXT_WIDTH / baseTextWidth);
		fitY = (fitX >= MIN_TEXT_SQUASH) ? 1 : fitX / MIN_TEXT_SQUASH;
		add(text);

		rankBadge = new FlxSprite();
		rankBadge.frames = Paths.getSparrowAtlas('freeplay/rankbadges');
		rankBadge.animation.addByPrefix('PERFECT_GOLD', 'PERFECT rank GOLD', 24, false);
		rankBadge.animation.addByPrefix('PERFECT', 'PERFECT rank0', 24, false);
		rankBadge.animation.addByPrefix('EXCELLENT', 'EXCELLENT rank0', 24, false);
		rankBadge.animation.addByPrefix('GREAT', 'GREAT rank0', 24, false);
		rankBadge.animation.addByPrefix('GOOD', 'GOOD rank0', 24, false);
		rankBadge.animation.addByPrefix('LOSS', 'LOSS rank0', 24, false);
		rankBadge.scale.set(RANK_SCALE, RANK_SCALE);
		rankBadge.antialiasing = ClientPrefs.data.antialiasing;
		rankBadge.visible = false;
		add(rankBadge);

		visible = active = false;
	}

	public function setRank(newRank:Null<ResultsRank>)
	{
		if(newRank == rank) return;

		rank = newRank;
		rankBadge.visible = (rank != null);
		if(rank == null) return;

		rankBadge.animation.play(rankAnimation(rank), true);
	}

	public function revealRank(newRank:ResultsRank)
	{
		rank = newRank;
		rankBadge.visible = true;
		rankBadge.animation.play(rankAnimation(newRank), true);
		FlxTween.cancelTweensOf(rankBadge.scale);
		rankBadge.scale.set(20, 20);
		FlxTween.tween(rankBadge.scale, {x: RANK_SCALE, y: RANK_SCALE}, 0.1);
	}

	static function rankAnimation(rank:ResultsRank):String
	{
		return switch(rank)
		{
			case PERFECT_GOLD: 'PERFECT_GOLD';
			case PERFECT: 'PERFECT';
			case EXCELLENT: 'EXCELLENT';
			case GREAT: 'GREAT';
			case GOOD: 'GOOD';
			case SHIT: 'LOSS';
		}
	}

	public function shake(amount:Float, duration:Float)
	{
		shakeAmount = amount;
		shakeDuration = shakeTime = duration;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(shakeTime > 0)
		{
			shakeTime -= elapsed;
			var progress:Float = Math.max(shakeTime, 0) / shakeDuration;
			var power:Float = shakeAmount * progress * progress;
			shakeX = FlxG.random.float(-power, power);
			shakeY = FlxG.random.float(-power, power);
		}
		else shakeX = shakeY = 0;
	}

	public function layout(x:Float, centerY:Float, scale:Float, alpha:Float)
	{
		x += shakeX;
		centerY += shakeY;
		if(scale != lastScale)
		{
			text.setScale(fitX * scale, fitY * scale);
			if(symbol != null) symbol.setScale(scale);
			lastScale = scale;
		}

		var iconCenterX:Float = x + ICON_WIDTH * scale / 2;
		if(icon != null)
		{
			icon.scale.set(ICON_SCALE * scale, ICON_SCALE * scale);
			icon.x = iconCenterX - icon.frameWidth / 2 + icon.offset.x;
			icon.y = centerY - icon.frameHeight / 2 + icon.offset.y;
		}
		if(symbol != null)
		{
			symbol.x = iconCenterX - baseSymbolWidth * scale / 2;
			symbol.y = centerY - TEXT_HEIGHT * scale / 2;
		}

		text.x = x + (ICON_WIDTH + TEXT_GAP) * scale;
		text.y = centerY - TEXT_HEIGHT * fitY * scale / 2;

		var rankX:Float = text.x + baseTextWidth * fitX * scale + RANK_GAP * scale;
		rankBadge.centerOrigin();
		rankBadge.setPosition(rankX + (RANK_SIZE - rankBadge.frameWidth) / 2, centerY - rankBadge.frameHeight / 2);

		for (member in members)
			if(member != null)
				member.alpha = alpha;
	}
}
