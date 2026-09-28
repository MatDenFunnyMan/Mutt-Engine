package funkin.game.cutscenes;

import funkin.game.stages.erect.TankErect;
import funkin.graphics.shaders.DropShadowShader;

class PicoTankman
{
	public static inline final ENDING_OFFSET_X:Float = 87;
	public static inline final ENDING_OFFSET_Y:Float = -18;
	static inline final ATLAS_OFFSET_X:Float = 732;
	static inline final ATLAS_OFFSET_Y:Float = 278;
	static inline final ENDING_NO_RIM_THRESHOLD:Float = 2;

	var cutscene:CutsceneHandler;
	var stage:TankErect;
	var tankmanEnding:FlxAnimate;
	var cutsceneSounds:FlxSound;
	var bgSprite:FlxSprite;

	public function new(stage:TankErect)
	{
		this.stage = stage;
	}

	public function preloadCutscene()
	{
		tankmanEnding = new FlxAnimate();
		Paths.loadAnimateAtlas(tankmanEnding, 'erect/cutscene/tankmanEnding');
		tankmanEnding.anim.addBySymbol('ending', 'tankman stress ending', 24, false);
		tankmanEnding.antialiasing = ClientPrefs.data.antialiasing;

		cutsceneSounds = new FlxSound().loadEmbedded(Paths.sound('erect/endCutscene'));
		PlayState.instance.preloadSubtitles('end-cutscene');

		bgSprite = new FlxSprite().makeGraphic(1, 1, 0xFF000000);
		bgSprite.scale.set(2000, 2500);
		bgSprite.updateHitbox();
		bgSprite.cameras = [stage.camOther];
		bgSprite.alpha = 0;
		PlayState.instance.add(bgSprite);
	}

	public function placeEnding()
	{
		var dad:Character = PlayState.instance.dad;
		var idle:Array<Dynamic> = dad.animOffsets.exists('idle') ? dad.animOffsets.get('idle') : [dad.offset.x, dad.offset.y];
		tankmanEnding.setPosition(dad.x - idle[0] + ENDING_OFFSET_X + ATLAS_OFFSET_X, dad.y - idle[1] + ENDING_OFFSET_Y + ATLAS_OFFSET_Y);
		tankmanEnding.scrollFactor.set(dad.scrollFactor.x, dad.scrollFactor.y);
	}

	function makeEndingShader(dad:Character):DropShadowShader
	{
		var rim:DropShadowShader = new DropShadowShader();
		rim.setAdjustColor(-46, -38, -25, -20);
		rim.color = 0xFFDFEF3C;
		rim.angle = 25;
		rim.threshold = ENDING_NO_RIM_THRESHOLD;
		rim.updateFrameInfo(dad.frame);
		return rim;
	}

	public function playCutscene()
	{
		var game = PlayState.instance;
		cutscene = new CutsceneHandler();
		FlxG.sound.list.add(cutsceneSounds);

		var tankmanPos:Array<Float> = [500, 500];
		cutscene.endTime = 320 / 24;
		cutscene.onStart = () ->
		{
			FlxTween.tween(game.camHUD, {alpha: 0}, 1);
			FlxTween.tween(game.camFollow, {x: tankmanPos[0] + 320, y: tankmanPos[1] - 70}, 2.8, {ease: FlxEase.expoOut});
			game.defaultCamZoom = 0.65;
			game.dad.visible = false;
			tankmanEnding.anim.play('ending', true);
			cutsceneSounds.play();
			game.playSubtitles('end-cutscene', cutsceneSounds);
		};
		cutscene.finishCallback = () -> game.endSong();
		cutscene.skipCallback = () -> game.endSong();

		cutscene.timer(176 / 24, () ->
		{
			stage.boyfriend.canPlayOtherAnims = true;
			stage.boyfriend.playAnim('laughEnd', true);
			stage.boyfriend.specialAnim = true;
		});
		cutscene.onUpdate = function(elapsed:Float)
		{
			var bf:Character = stage.boyfriend;
			if(bf.getAnimationName() == 'laughEnd' && bf.isAnimationFinished() && bf.hasAnimation('laughEnd-loop'))
			{
				bf.playAnim('laughEnd-loop', true);
				bf.specialAnim = true;
			}
		};
		cutscene.timer(270 / 24, () ->
		{
			FlxTween.tween(game.camFollow, {x: tankmanPos[0] + 320, y: tankmanPos[1] - 370}, 2, {ease: FlxEase.quadInOut});
			FlxTween.tween(bgSprite, {alpha: 1}, 2);
		});

		placeEnding();
		if(ClientPrefs.data.shaders) tankmanEnding.shader = makeEndingShader(game.dad);

		@:privateAccess game.canPause = false;
		game.addBehindDad(tankmanEnding);
		cutscene.objects.push(tankmanEnding);
		game.inCutscene = true;
	}
}
