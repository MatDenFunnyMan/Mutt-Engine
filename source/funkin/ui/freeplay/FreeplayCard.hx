package funkin.ui.freeplay;

import flixel.FlxBasic;

class FreeplayCard extends FlxTypedGroup<FlxBasic>
{
	public static inline final X:Int = 863;
	public static inline final Y:Int = 290;
	public static inline final WIDTH:Int = 387;
	public static inline final HEIGHT:Int = 415;
	static inline final VIEW_X:Float = 22;
	static inline final VIEW_Y:Float = 290;

	public var dj(default, null):FreeplayDJ;
	public var player(default, null):FreeplayPlayer;
	public var onIntroDone:Void->Void = null;

	var introTimer:FlxTimer;

	public function new()
	{
		super();
	}

	public function show(newPlayer:FreeplayPlayer)
	{
		clearCard();
		player = newPlayer;

		if(!ClientPrefs.data.lowQuality)
		{
			dj = new FreeplayDJ(player, X - VIEW_X, Y - VIEW_Y);
			dj.onIntroDone = introDone;
			add(dj);
			dj.playIntro();
		}
		else introTimer = new FlxTimer().start(0.6, function(_) introDone());
	}

	function introDone()
	{
		if(onIntroDone != null) onIntroDone();
	}

	public function confirm()
	{
		if(dj != null) dj.confirm();
	}

	public function reactionIntro(good:Bool)
	{
		if(dj != null) dj.reactionIntro(good);
	}

	public function reaction(good:Bool)
	{
		if(dj != null) dj.reaction(good);
	}

	public function resetAfk()
	{
		if(dj != null) dj.resetAfk();
	}

	public function containsMouse():Bool
	{
		var point:FlxPoint = FlxG.mouse.getScreenPosition();
		var inside:Bool = point.x >= X && point.x <= X + WIDTH && point.y >= Y && point.y <= Y + HEIGHT;
		point.put();
		return inside;
	}

	function clearCard()
	{
		if(introTimer != null) introTimer.cancel();
		introTimer = null;
		for (member in members)
			if(member != null)
				member.destroy();
		clear();
		dj = null;
	}
}
