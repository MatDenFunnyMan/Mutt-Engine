package funkin.game.cutscenes;

import funkin.game.stages.erect.TankErect;

class PicoTankman
{
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
		tankmanEnding = new FlxAnimate(520, 350);
		Paths.loadAnimateAtlas(tankmanEnding, 'erect/cutscene/tankmanEnding');
		tankmanEnding.anim.addBySymbol('ending', 'tankman stress ending', 24, false);
		tankmanEnding.antialiasing = ClientPrefs.data.antialiasing;

		cutsceneSounds = new FlxSound().loadEmbedded(Paths.sound('erect/endCutscene'));

		bgSprite = new FlxSprite().makeGraphic(1, 1, 0xFF000000);
		bgSprite.scale.set(2000, 2500);
		bgSprite.updateHitbox();
		bgSprite.cameras = [stage.camOther];
		bgSprite.alpha = 0;
		PlayState.instance.add(bgSprite);
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
		};
		cutscene.finishCallback = () -> game.endSong();
		cutscene.skipCallback = () -> game.endSong();

		cutscene.timer(176 / 24, () -> stage.boyfriend.playAnim('laughEnd', true));
		cutscene.timer(270 / 24, () ->
		{
			FlxTween.tween(game.camFollow, {x: tankmanPos[0] + 320, y: tankmanPos[1] - 370}, 2, {ease: FlxEase.quadInOut});
			FlxTween.tween(bgSprite, {alpha: 1}, 2);
		});

		if(ClientPrefs.data.shaders) stage.applyAbotShader(tankmanEnding);

		@:privateAccess game.canPause = false;
		game.add(tankmanEnding);
		cutscene.objects.push(tankmanEnding);
		game.inCutscene = true;
	}
}
