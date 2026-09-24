package funkin.game.cutscenes;

import flixel.system.FlxAssets.FlxShader;
import funkin.game.Character;
import funkin.game.stages.objects.PicoDopplegangerSprite;

class TwoPicos
{
	var cutsceneHandler:CutsceneHandler;
	public var imposterPico:PicoDopplegangerSprite;
	var pico:PicoDopplegangerSprite;
	var bloodPool:FlxAnimate;
	var cigarette:FlxSprite;

	var playerShoots:Bool;
	var explode:Bool;
	var seenOutcome:Bool;
	var host:BaseStage;
	var shader:FlxShader;

	public function new(host:BaseStage, shader:FlxShader)
	{
		this.host = host;
		this.shader = shader;
	}

	function prepareCutscene()
	{
		cutsceneHandler = new CutsceneHandler();
		var game = PlayState.instance;

		host.boyfriend.visible = host.dad.visible = false;
		host.camHUD.visible = false;

		imposterPico = new PicoDopplegangerSprite(host.dad.x + 82, host.dad.y + 400);
		cutsceneHandler.push(imposterPico);

		pico = new PicoDopplegangerSprite(host.boyfriend.x + 48.5, host.boyfriend.y + 400);
		cutsceneHandler.push(pico);

		bloodPool = new FlxAnimate(0, 0);
		bloodPool.visible = false;
		Paths.loadAnimateAtlas(bloodPool, 'philly/erect/cutscenes/bloodPool');
		funkin.util.AtlasUtil.addAnimation(bloodPool, 'bloodPool', 'bloodPool', null, 24, false);
		bloodPool.antialiasing = ClientPrefs.data.antialiasing;

		cigarette = new FlxSprite();
		cigarette.frames = Paths.getSparrowAtlas('philly/erect/cutscenes/cigarette');
		cigarette.animation.addByPrefix('cigarette spit', 'cigarette spit', 24, false);
		cigarette.antialiasing = ClientPrefs.data.antialiasing;
		cigarette.visible = false;

		cutsceneHandler.finishCallback = function()
		{
			PlayState.seenCutscene = true;
			var timeForStuff:Float = Conductor.crochet / 1000 * 4.5;
			FlxG.sound.music.fadeOut(timeForStuff);
			FlxTween.tween(FlxG.camera, {zoom: host.defaultCamZoom}, timeForStuff, {ease: FlxEase.quadInOut});

			if(explode)
			{
				if(playerShoots) host.boyfriend.visible = true;
				else host.dad.visible = true;
			}
			else host.boyfriend.visible = host.dad.visible = true;

			host.camHUD.visible = true;

			host.boyfriend.animation.finishCallback = null;
			if(host.gf != null) host.gf.animation.finishCallback = null;

			pico.cancelSounds();
			imposterPico.cancelSounds();

			if(explode)
			{
				if(playerShoots)
				{
					if(seenOutcome) imposterPico.playAnimation('loopOpponent');
					else
					{
						imposterPico.kill();
						game.remove(imposterPico);
						imposterPico.destroy();
						host.dad.visible = true;
					}
				}
				else
				{
					if(seenOutcome)
					{
						pico.playAnimation('loopPlayer');
						if(FlxG.sound.music.fadeTween != null) FlxG.sound.music.fadeTween.cancel();
						game.endSong();
					}
					else
					{
						pico.kill();
						game.remove(pico);
						pico.destroy();
						host.boyfriend.visible = true;
					}
				}

				if(seenOutcome && playerShoots)
				{
					game.camZooming = true;
					game.opponentVocals = new FlxSound();
					for (note in game.unspawnNotes)
						if(!note.mustPress && note.eventName == '')
							note.ignoreNote = true;
				}
			}

			host.dad.dance();
			host.boyfriend.dance();
			if(host.gf != null) host.gf.dance();

			FlxTween.cancelTweensOf(FlxG.camera);
			FlxTween.cancelTweensOf(host.camFollow);
			game.moveCameraSection();
			FlxG.camera.scroll.set(host.camFollow.x - FlxG.width / 2, host.camFollow.y - FlxG.height / 2);
			FlxG.camera.zoom = host.defaultCamZoom;
			if(!explode || playerShoots || !seenOutcome)
				game.startCountdown();
		};
		cutsceneHandler.skipCallback = function() cutsceneHandler.finishCallback();
		host.camFollow_set(host.dad.x + 280, host.dad.y + 170);
	}

	public function startCutscene()
	{
		prepareCutscene();
		var game = PlayState.instance;

		seenOutcome = false;
		playerShoots = FlxG.random.bool(50);
		explode = FlxG.random.bool(8);

		cutsceneHandler.endTime = 13;
		cutsceneHandler.music = playerShoots ? 'cutscene/cutscene2' : 'cutscene/cutscene';
		for (snd in ['picoCigarette', 'picoExplode', 'picoShoot', 'picoSpin', 'picoCigarette2', 'picoGasp'])
			Paths.sound('cutscene/$snd');

		var cigarettePos:Array<Float> = [];
		var shooterPos:Array<Float> = [];
		if(playerShoots)
		{
			cigarette.flipX = true;

			host.addBehindBF(cigarette);
			host.addBehindBF(bloodPool);
			host.addBehindBF(imposterPico);
			host.addBehindBF(pico);

			cigarette.setPosition(host.boyfriend.x - 143.5, host.boyfriend.y + 210);
			bloodPool.setPosition(host.dad.x - 1487, host.dad.y - 173);

			shooterPos = cameraPos(host.boyfriend, game.boyfriendCameraOffset);
			cigarettePos = cameraPos(host.dad, [250, 0]);
		}
		else
		{
			host.addBehindDad(cigarette);
			host.addBehindDad(bloodPool);
			host.addBehindDad(pico);
			host.addBehindDad(imposterPico);

			bloodPool.setPosition(host.boyfriend.x - 788.5, host.boyfriend.y - 173);
			cigarette.setPosition(host.boyfriend.x - 478.5, host.boyfriend.y + 205);

			cigarettePos = cameraPos(host.boyfriend, game.boyfriendCameraOffset);
			shooterPos = cameraPos(host.dad, [250, 0]);
		}
		var midPoint:Array<Float> = [(shooterPos[0] + cigarettePos[0]) / 2, (shooterPos[1] + cigarettePos[1]) / 2];

		imposterPico.doAnim('Opponent', !playerShoots, explode, cutsceneHandler);
		pico.doAnim('Player', playerShoots, explode, cutsceneHandler);

		host.camFollow_set(midPoint[0], midPoint[1]);

		if(ClientPrefs.data.shaders && shader != null)
		{
			cutsceneHandler.timer(0.01, () ->
			{
				pico.shader = shader;
				imposterPico.shader = shader;
				bloodPool.shader = shader;
			});
		}
		cutsceneHandler.timer(0.3, () -> FlxG.sound.play(Paths.sound('cutscene/picoGasp')));
		cutsceneHandler.timer(4, () -> host.camFollow_set(cigarettePos[0], cigarettePos[1]));
		cutsceneHandler.timer(6.3, () -> host.camFollow_set(shooterPos[0], shooterPos[1]));
		cutsceneHandler.timer(8.75, () ->
		{
			seenOutcome = true;
			host.camFollow_set(cigarettePos[0], cigarettePos[1]);
		});
		cutsceneHandler.timer(11.2, () ->
		{
			if(explode)
			{
				bloodPool.visible = true;
				bloodPool.anim.play('bloodPool', true);
			}
		});
		cutsceneHandler.timer(11.5, () ->
		{
			if(!explode)
			{
				cigarette.visible = true;
				cigarette.animation.play('cigarette spit');
			}
		});
	}

	function cameraPos(char:Character, camOffset:Array<Float>)
	{
		var point = new FlxPoint(char.getMidpoint().x - 100, char.getMidpoint().y - 100);
		point.x -= char.cameraPosition[0] - camOffset[0];
		point.y += char.cameraPosition[1] + camOffset[1];
		return [point.x, point.y];
	}
}
