package funkin.ui.freeplay;

class FreeplayDJ extends FlxAnimate
{
	static inline final POSITION_X:Float = 640;
	static inline final POSITION_Y:Float = 366;
	static inline final INSTANCE_X:Float = 640;
	static inline final INSTANCE_Y:Float = 360;
	static inline final AFK_TIME:Float = 60;

	public var onIntroDone:Void->Void = null;

	var player:FreeplayPlayer;
	var current:String = null;
	var idleTime:Float = 0;
	var seenAfk:Bool = false;
	var holdingReaction:Bool = false;
	var reactionFrames:Array<Int> = null;

	public function new(player:FreeplayPlayer, offsetX:Float = 0, offsetY:Float = 0)
	{
		super(POSITION_X + offsetX, POSITION_Y + offsetY);
		this.player = player;

		Paths.loadAnimateAtlas(this, player.djAtlas);
		for (name => data in player.djAnimations)
			anim.addBySymbol(name, data.symbol + '\\', 24, false, INSTANCE_X, INSTANCE_Y);
		antialiasing = ClientPrefs.data.antialiasing;
		anim.onComplete.add(onAnimationDone);
	}

	public function playIntro()
	{
		resetAfk();
		playDJ(player.djAnimations.exists('intro') ? 'intro' : 'idle');
	}

	public function confirm()
	{
		holdingReaction = false;
		playDJ('confirm');
	}

	public function reactionIntro(good:Bool)
	{
		reactionFrames = good ? player.fistPumpFrames : player.lossFrames;
		holdingReaction = true;
		playDJ(good ? 'fistPump' : 'loss', reactionFrames[0]);
	}

	public function reaction(good:Bool)
	{
		reactionFrames = good ? player.fistPumpFrames : player.lossFrames;
		holdingReaction = false;
		playDJ(good ? 'fistPump' : 'loss', reactionFrames[2]);
	}

	public function resetAfk()
	{
		idleTime = 0;
		seenAfk = false;
	}

	function playDJ(name:String, frame:Int = 0)
	{
		var data = player.djAnimations.get(name);
		if(data == null) return;

		current = name;
		anim.play(name, true, false, frame);
		offset.set(data.offsetX, data.offsetY);
	}

	function onAnimationDone()
	{
		switch(current)
		{
			case 'intro':
				playDJ('idle');
				if(onIntroDone != null) onIntroDone();
			case 'idle':
				if(!seenAfk && idleTime >= AFK_TIME && player.djAnimations.exists('afk'))
				{
					seenAfk = true;
					playDJ('afk');
				}
				else playDJ('idle');
			case 'afk' | 'fistPump' | 'loss':
				if(holdingReaction && reactionFrames != null)
				{
					playDJ(current, reactionFrames[0]);
					return;
				}
				idleTime = 0;
				playDJ('idle');
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(current == 'idle') idleTime += elapsed;

		if(holdingReaction && reactionFrames != null && anim.curFrame >= reactionFrames[1])
			playDJ(current, reactionFrames[0]);
	}
}
