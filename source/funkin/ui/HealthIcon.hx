package funkin.ui;

import flixel.graphics.frames.FlxAtlasFrames;

class HealthIcon extends FlxSprite
{
	public static inline final STATE_NEUTRAL:Int = 0;
	public static inline final STATE_LOSING:Int = 1;
	public static inline final STATE_WINNING:Int = 2;
	public static inline final STATE_WINNING_EXTREME:Int = 3;

	public var sprTracker:FlxSprite;
	public var isAnimated(default, null):Bool = false;
	public var totalStates(default, null):Int = 1;

	private var isPlayer:Bool = false;
	private var char:String = '';
	private var curState:Int = -1;
	private var stateAnims:Array<String> = [null, null, null, null];

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String, ?allowGPU:Bool = true) {
		if(this.char == char) return;

		var name:String = 'icons/' + char;
		if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char;
		if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face';

		this.char = char;
		isAnimated = false;
		totalStates = 1;
		curState = -1;
		stateAnims = [null, null, null, null];
		animation.destroyAnimations();

		if(Paths.fileExists('images/' + name + '.xml', TEXT))
			isAnimated = loadAnimatedIcon(name, allowGPU);

		if(!isAnimated) loadStaticIcon(name, allowGPU);

		if(char.endsWith('-pixel'))
			antialiasing = false;
		else
			antialiasing = ClientPrefs.data.antialiasing;

		setIconState(STATE_NEUTRAL);
	}

	function loadStaticIcon(name:String, ?allowGPU:Bool = true)
	{
		var graphic = Paths.image(name, allowGPU);
		var iSize:Float = Math.round(graphic.width / graphic.height);
		loadGraphic(graphic, true, Math.floor(graphic.width / iSize), Math.floor(graphic.height));
		iconOffsets[0] = (width - 150) / iSize;
		iconOffsets[1] = (height - 150) / iSize;
		updateHitbox();

		totalStates = frames.frames.length;
		animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
		animation.play(char);
	}

	static final STATE_PREFIXES:Array<Array<String>> = [
		['neutral', 'normal', 'idle', 'icon', 'default'],
		['lose', 'losing', 'loss'],
		['win', 'winning'],
		['winextra', 'superwin', 'perfect']
	];

	function loadAnimatedIcon(name:String, ?allowGPU:Bool = true):Bool
	{
		var atlas:FlxAtlasFrames = null;
		try
		{
			atlas = Paths.getSparrowAtlas(name, allowGPU);
		}
		catch(e:Dynamic)
		{
			atlas = null;
		}

		if(atlas == null || atlas.frames == null || atlas.frames.length < 1) return false;

		frames = atlas;
		for (state => list in STATE_PREFIXES)
		{
			for (prefix in list)
			{
				var indices:Array<Int> = framesWithPrefix(prefix);
				if(indices.length < 1) continue;

				var animName:String = 'iconState' + state;
				animation.add(animName, indices, 24, true, isPlayer);
				stateAnims[state] = animName;
				totalStates = state + 1;
				break;
			}
		}

		if(stateAnims[STATE_NEUTRAL] == null) return false;

		iconOffsets[0] = (frameWidth - 150) / 2;
		iconOffsets[1] = (frameHeight - 150) / 2;
		updateHitbox();
		return true;
	}

	function framesWithPrefix(prefix:String):Array<Int>
	{
		var result:Array<Int> = [];
		for (i => frame in frames.frames)
		{
			if(frame.name == null || !frame.name.startsWith(prefix)) continue;

			var rest:String = frame.name.substr(prefix.length);
			if(rest.length < 1) continue;

			var onlyDigits:Bool = true;
			for (pos in 0...rest.length)
			{
				var code:Int = rest.charCodeAt(pos);
				if(code < 48 || code > 57)
				{
					onlyDigits = false;
					break;
				}
			}
			if(onlyDigits) result.push(i);
		}
		return result;
	}

	inline public function hasState(state:Int):Bool
		return isAnimated ? (state > -1 && state < stateAnims.length && stateAnims[state] != null) : (state > -1 && state < totalStates);

	public function setIconState(state:Int)
	{
		if(state < STATE_NEUTRAL) state = STATE_NEUTRAL;
		if(!hasState(state))
		{
			if(state == STATE_WINNING_EXTREME && hasState(STATE_WINNING)) state = STATE_WINNING;
			else state = STATE_NEUTRAL;
		}

		if(state == curState) return;
		curState = state;

		if(isAnimated) animation.play(stateAnims[state], true);
		else if(animation.curAnim != null) animation.curAnim.curFrame = state;
	}

	public function updateState(percent:Float, ?isOpponent:Bool = false)
	{
		var state:Int = STATE_NEUTRAL;
		if(!isOpponent)
		{
			if(percent < 20) state = STATE_LOSING;
			else if(percent > 90) state = STATE_WINNING_EXTREME;
			else if(percent > 80) state = STATE_WINNING;
		}
		else
		{
			if(percent > 80) state = STATE_LOSING;
			else if(percent < 10) state = STATE_WINNING_EXTREME;
			else if(percent < 20) state = STATE_WINNING;
		}
		setIconState(state);
	}

	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();
		if(autoAdjustOffset)
		{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		}
	}

	public function getCharacter():String {
		return char;
	}
}
