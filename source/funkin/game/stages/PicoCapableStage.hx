package funkin.game.stages;

import flixel.graphics.tile.FlxGraphicsShader;
import funkin.game.notes.Note;
import funkin.game.states.GameOverSubstate;
import funkin.game.stages.objects.ABotSpeaker;
import funkin.game.stages.objects.ABotPixel;

enum PicoNeneState
{
	STATE_DEFAULT;
	STATE_PRE_RAISE;
	STATE_RAISE;
	STATE_READY;
	STATE_LOWER;
	STATE_HAIR_BLOWING;
	STATE_HAIR_FALLING;
	STATE_HAIR_BLOWING_RAISE;
	STATE_HAIR_FALLING_RAISE;
}

class PicoCapableStage extends BaseStage
{
	final MIN_BLINK_DELAY:Int = 3;
	final MAX_BLINK_DELAY:Int = 7;
	final VULTURE_THRESHOLD:Float = 0.5;

	public static var instance:PicoCapableStage = null;
	public static var NENE_LIST:Array<String> = ['nene', 'nene-pixel', 'nene-christmas', 'nene-dark'];
	public static var PIXEL_LIST:Array<String> = ['nene-pixel'];
	public static var SELF_HANDLED_STAGES:Array<String> = ['phillyStreets', 'phillyBlazin'];

	public var abot:ABotSpeaker;
	public var abotPixel:ABotPixel;
	public var forceABot:Bool = false;
	public var onABotInit:Array<PicoCapableStage->Void> = [];

	var blinkCountdown:Int = 3;
	var currentNeneState:PicoNeneState = STATE_DEFAULT;
	var animationFinished:Bool = false;
	public var trainPassing:Bool = false;

	public static function shouldAdd(stage:String):Bool
	{
		return !SELF_HANDLED_STAGES.contains(stage) && NENE_LIST.contains(PlayState.SONG.gfVersion);
	}

	public static function addToGame(?forceABot:Bool = false):PicoCapableStage
	{
		var pico = new PicoCapableStage(forceABot);
		var game = PlayState.instance;
		game.stages.remove(pico);
		game.stages.insert(0, pico);
		return pico;
	}

	public function new(forceABot:Bool = false)
	{
		if(instance != null) instance.destroy();
		instance = this;
		this.forceABot = forceABot;
		super();
	}

	function isActive():Bool
	{
		return NENE_LIST.contains(PlayState.SONG.gfVersion) || forceABot;
	}

	public function applyABotShader(shader:FlxGraphicsShader)
	{
		if(abotPixel != null)
		{
			abotPixel.bg.shader = shader;
			abotPixel.eyes.shader = shader;
			abotPixel.speaker.shader = shader;
			for (viz in abotPixel.vizSprites) viz.shader = shader;
		}
		else if(abot != null)
		{
			abot.bg.shader = shader;
			abot.eyes.shader = shader;
			abot.speaker.shader = shader;
			for (viz in abot.vizSprites) viz.shader = shader;
		}
	}

	public function ABot_plink()
	{
		if(abot == null || abot.speakerAlt == null) return;
		abot.speakerAlt.alpha = 1;
		abot.speaker.alpha = 0;
		FlxTween.tween(abot.speakerAlt, {alpha: 0}, 1.5);
		FlxTween.tween(abot.speaker, {alpha: 1}, 1.5);
	}

	override function destroy()
	{
		if(instance == this) instance = null;
		onABotInit = [];
		super.destroy();
	}

	override function create()
	{
		if(!isActive()) return;

		var _song = PlayState.SONG;
		if(_song.gameOverSound == null || _song.gameOverSound.trim().length < 1) GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pico';
		if(_song.gameOverLoop == null || _song.gameOverLoop.trim().length < 1) GameOverSubstate.loopSoundName = 'gameOver-pico';
		if(_song.gameOverEnd == null || _song.gameOverEnd.trim().length < 1) GameOverSubstate.endSoundName = 'gameOverEnd-pico';
		if(_song.gameOverChar == null || _song.gameOverChar.trim().length < 1) GameOverSubstate.characterName = 'pico-dead';
	}

	override function createPost()
	{
		abot = null;
		abotPixel = null;
		if(!isActive()) return;

		gfGroup.y -= 200;
		if(PIXEL_LIST.contains(PlayState.SONG.gfVersion) || PlayState.isPixelStage)
		{
			abotPixel = new ABotPixel(gfGroup.x - 165, gfGroup.y + 340 - 30);
			updateABotEye(true);
			addBehindGF(abotPixel);
		}
		else
		{
			abot = new ABotSpeaker(gfGroup.x - 50, gfGroup.y + 550 - 30, PlayState.SONG.gfVersion == 'nene-dark');
			updateABotEye(true);
			addBehindGF(abot);
			gfGroup.x -= 24;
			gfGroup.y -= 74;
		}

		if(gf != null)
		{
			var oldCallback = gf.animation.callback;
			gf.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int)
			{
				if(oldCallback != null) oldCallback(name, frameNumber, frameIndex);
				if(currentNeneState == STATE_PRE_RAISE && name == 'danceLeft' && frameNumber >= 14)
				{
					animationFinished = true;
					transitionState();
				}
			}
		}
		for (callback in onABotInit) callback(this);
	}

	override function startSong()
	{
		if(gf != null && NENE_LIST.contains(PlayState.SONG.gfVersion)) gf.animation.finishCallback = onNeneAnimationFinished;
		if(abot != null) abot.snd = FlxG.sound.music;
		if(abotPixel != null) abotPixel.snd = FlxG.sound.music;
	}

	override function sectionHit()
	{
		if(abot != null || abotPixel != null) updateABotEye();
	}

	function onNeneAnimationFinished(name:String)
	{
		if(!game.startedCountdown) return;

		switch(currentNeneState)
		{
			case STATE_RAISE, STATE_LOWER:
				if(name == 'raiseKnife' || name == 'lowerKnife')
				{
					animationFinished = true;
					transitionState();
				}
			default:
		}
	}

	override function beatHit()
	{
		if(gf == null || !NENE_LIST.contains(PlayState.SONG.gfVersion)) return;
		if(abotPixel != null) abotPixel.speaker.animation.play('anim', true);

		if(currentNeneState == STATE_READY)
		{
			if(blinkCountdown == 0)
			{
				gf.playAnim('idleKnife', false);
				blinkCountdown = FlxG.random.int(MIN_BLINK_DELAY, MAX_BLINK_DELAY);
			}
			else blinkCountdown--;
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(gf == null || !NENE_LIST.contains(PlayState.SONG.gfVersion) || !game.startedCountdown) return;

		animationFinished = gf.isAnimationFinished();
		transitionState();
	}

	override function goodNoteHit(note:Note)
	{
		if(gf == null || !NENE_LIST.contains(PlayState.SONG.gfVersion)) return;

		switch(game.combo)
		{
			case 50, 100:
				var animToPlay:String = 'combo${game.combo}';
				if(gf.hasAnimation(animToPlay))
				{
					gf.playAnim(animToPlay);
					gf.specialAnim = true;
				}
		}
	}

	public function handlesTrain():Bool
	{
		return gf != null && NENE_LIST.contains(PlayState.SONG.gfVersion) && gf.hasAnimation('hairBlowNormal');
	}

	function checkTrainPassing(raised:Bool = false)
	{
		if(!trainPassing || !handlesTrain()) return;

		currentNeneState = raised ? STATE_HAIR_BLOWING_RAISE : STATE_HAIR_BLOWING;
		gf.playAnim(raised ? 'hairBlowKnife' : 'hairBlowNormal', true);
		gf.skipDance = true;
		animationFinished = false;
	}

	function transitionState()
	{
		switch(currentNeneState)
		{
			case STATE_DEFAULT:
				if(game.health <= VULTURE_THRESHOLD)
				{
					currentNeneState = STATE_PRE_RAISE;
					gf.skipDance = true;
				}
				checkTrainPassing();

			case STATE_PRE_RAISE:
				if(game.health > VULTURE_THRESHOLD)
				{
					currentNeneState = STATE_DEFAULT;
					gf.skipDance = false;
				}
				else if(animationFinished)
				{
					currentNeneState = STATE_RAISE;
					gf.playAnim('raiseKnife');
					gf.skipDance = true;
					gf.danced = true;
					animationFinished = false;
				}
				checkTrainPassing();

			case STATE_RAISE:
				if(animationFinished)
				{
					currentNeneState = STATE_READY;
					animationFinished = false;
				}
				checkTrainPassing(true);

			case STATE_READY:
				if(game.health > VULTURE_THRESHOLD)
				{
					currentNeneState = STATE_LOWER;
					gf.playAnim('lowerKnife');
				}
				else checkTrainPassing(true);

			case STATE_LOWER:
				if(animationFinished)
				{
					currentNeneState = STATE_DEFAULT;
					animationFinished = false;
					gf.skipDance = false;
				}
				checkTrainPassing();

			case STATE_HAIR_BLOWING:
				if(!trainPassing)
				{
					currentNeneState = STATE_HAIR_FALLING;
					gf.playAnim('hairFallNormal', true);
					animationFinished = false;
				}
				else if(animationFinished)
				{
					gf.playAnim('hairBlowNormal', true);
					animationFinished = false;
				}

			case STATE_HAIR_FALLING:
				if(animationFinished)
				{
					currentNeneState = STATE_DEFAULT;
					animationFinished = false;
					gf.skipDance = false;
					gf.danced = false;
				}

			case STATE_HAIR_BLOWING_RAISE:
				if(!trainPassing)
				{
					currentNeneState = STATE_HAIR_FALLING_RAISE;
					gf.playAnim('hairFallKnife', true);
					animationFinished = false;
				}
				else if(animationFinished)
				{
					gf.playAnim('hairBlowKnife', true);
					animationFinished = false;
				}

			case STATE_HAIR_FALLING_RAISE:
				if(animationFinished)
				{
					currentNeneState = STATE_READY;
					animationFinished = false;
				}
		}
	}

	function updateABotEye(finishInstantly:Bool = false)
	{
		var section = PlayState.SONG.notes[Std.int(FlxMath.bound(curSection, 0, PlayState.SONG.notes.length - 1))];
		var right:Bool = section != null && section.mustHitSection;
		if(abot != null)
		{
			if(right) abot.lookRight();
			else abot.lookLeft();
			if(finishInstantly) abot.eyes.anim.curFrame = abot.eyes.anim.length - 1;
		}
		if(abotPixel != null)
		{
			if(right) abotPixel.lookRight();
			else abotPixel.lookLeft();
			if(finishInstantly) abotPixel.eyes.animation.curAnim.curFrame = abotPixel.eyes.animation.curAnim.numFrames - 1;
		}
	}
}
