package funkin.ui.states;

import flixel.addons.display.FlxBackdrop;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxBitmapFont;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxBitmapText;
import flixel.util.FlxGradient;
import funkin.ui.results.ResultsRank;
import funkin.ui.results.ResultsRank.RankData;
import funkin.ui.results.ResultsCounters;

typedef ResultsData = {
	var songName:String;
	var difficulty:String;
	var score:Int;
	var accuracy:Float;
	var misses:Int;
	var sicks:Int;
	var goods:Int;
	var bads:Int;
	var shits:Int;
	var totalHits:Int;
	var maxCombo:Int;
	var ratingFC:String;
	var isStoryMode:Bool;
	var isNewHighscore:Bool;
	var playerCharacter:String;
}

class ResultsState extends MusicBeatState
{
	public static var FONT_LETTERS:String = "AaBbCcDdEeFfGgHhiIJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz:1234567890";

	public static var SCORE_X:Float = 70;
	public static var SCORE_Y:Float = 610;

	var data:ResultsData;
	var onContinue:Void->Void;
	var rank:ResultsRank;
	var character:String;

	var camBG:FlxCamera;
	var camScroll:FlxCamera;
	var camMain:FlxCamera;

	var layerBG:FlxGroup;
	var layerScroll:FlxGroup;
	var layerPercent:FlxGroup;
	var layerChars:FlxGroup;
	var layerRankVert:FlxGroup;
	var layerTop:FlxGroup;
	var layerFront:FlxGroup;

	var bgFlash:FlxSprite;
	var blackTopBar:FlxSprite;
	var songNameText:FlxBitmapText;
	var difficultySprite:FlxSprite;
	var clearPercentSmall:ClearPercentCounter;
	var clearPercentBig:ClearPercentCounter;
	var score:ResultScore;
	var highscoreNew:FlxSprite;

	var tallies:Array<TallyCounter> = [];
	var atlasLayers:Array<{sprite:FlxSprite, delay:Float, sparrow:Bool}> = [];

	var timers:Array<FlxTimer> = [];
	var clearPercentTarget:Int = 0;
	var canExit:Bool = false;

	public function new(data:ResultsData, onContinue:Void->Void)
	{
		super();
		this.data = data;
		this.onContinue = onContinue;
		this.character = RankData.resolveCharacter(data.playerCharacter);
		this.rank = RankData.calculate(data.accuracy, data.misses, data.sicks, data.totalHits);
	}

	override function create()
	{
		persistentUpdate = false;
		if(FlxG.sound.music != null) FlxG.sound.music.stop();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Results Screen', data.songName);
		#end

		clearPercentTarget = Math.round(data.accuracy * 100);

		setupCameras();
		setupLayers();

		buildBackground();
		buildCharacters();
		buildTopBar();
		buildSoundSystem();
		buildResultsAnim();
		buildPopins();
		buildScore();
		buildTallies();
		buildHighscore();

		scheduleSequence();

		super.create();
	}

	function setupCameras()
	{
		camBG = new FlxCamera();
		camScroll = new FlxCamera();
		camMain = new FlxCamera();

		camScroll.angle = -3.8;
		camScroll.bgColor.alpha = 0;
		camMain.bgColor.alpha = 0;

		FlxG.cameras.reset(camBG);
		FlxG.cameras.add(camScroll, false);
		FlxG.cameras.add(camMain, false);
		FlxG.cameras.setDefaultDrawTarget(camMain, true);

		_psychCameraInitialized = true;
	}

	function setupLayers()
	{
		layerBG = new FlxGroup();
		layerScroll = new FlxGroup();
		layerPercent = new FlxGroup();
		layerChars = new FlxGroup();
		layerRankVert = new FlxGroup();
		layerTop = new FlxGroup();
		layerFront = new FlxGroup();

		add(layerBG);
		add(layerScroll);
		add(layerPercent);
		add(layerChars);
		add(layerRankVert);
		add(layerTop);
		add(layerFront);
	}

	function wait(delay:Float, action:Void->Void)
	{
		if(delay <= 0)
		{
			action();
			return;
		}

		timers.push(new FlxTimer().start(delay, function(_) action()));
	}

	function buildBackground()
	{
		var bg:FlxSprite = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFFFECC5C, 0xFFFDC05C], 90);
		bg.scrollFactor.set();
		bg.cameras = [camBG];
		layerBG.add(bg);

		bgFlash = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFFFFF1A6, 0xFFFFF1BE], 90);
		bgFlash.scrollFactor.set();
		bgFlash.visible = false;
		layerBG.add(bgFlash);
	}

	function buildCharacters()
	{
		for(layer in RankData.layers(rank, character))
		{
			var posX:Float = layer.x != null ? layer.x : 0;
			var posY:Float = layer.y != null ? layer.y : 0;
			var scaleValue:Float = layer.scale != null ? layer.scale : 1;
			var delay:Float = layer.delay != null ? layer.delay : 0;
			var loopFrame:Int = layer.loopFrame != null ? layer.loopFrame : 0;

			if(layer.sparrow == true)
			{
				if(!Paths.fileExists('images/${layer.asset}.png', IMAGE)) continue;

				var spr:FlxSprite = new FlxSprite(posX, posY);
				spr.frames = Paths.getSparrowAtlas(layer.asset);
				spr.animation.addByPrefix('idle', '', 24, false);
				spr.animation.finishCallback = function(_) spr.animation.play('idle', true, false, loopFrame);
				spr.scale.set(scaleValue, scaleValue);
				spr.antialiasing = ClientPrefs.data.antialiasing;
				spr.visible = false;
				layerChars.add(spr);
				atlasLayers.push({sprite: spr, delay: delay, sparrow: true});
				continue;
			}

			#if flxanimate
			if(!Paths.fileExists('images/${layer.asset}/Animation.json', TEXT)) continue;

			var atlas:FlxAnimate = new FlxAnimate(posX, posY);
			atlas.showPivot = false;

			try
			{
				Paths.loadAnimateAtlas(atlas, layer.asset);
			}
			catch(e:haxe.Exception)
			{
				FlxG.log.warn('Results: atlas ${layer.asset} non caricato');
				continue;
			}

			atlas.scale.set(scaleValue, scaleValue);
			atlas.antialiasing = ClientPrefs.data.antialiasing;
			atlas.anim.onComplete.add(function() atlas.anim.play('', true, false, loopFrame));
			atlas.visible = false;
			layerChars.add(atlas);
			atlasLayers.push({sprite: atlas, delay: delay, sparrow: false});
			#end
		}
	}

	function buildTopBar()
	{
		var diffKey:String = 'results/diff_' + data.difficulty.toLowerCase();
		if(!Paths.fileExists('images/$diffKey.png', IMAGE)) diffKey = 'results/diff_normal';

		difficultySprite = new FlxSprite(555, 0);
		if(Paths.fileExists('images/$diffKey.png', IMAGE))
		{
			difficultySprite.loadGraphic(Paths.image(diffKey));
			difficultySprite.antialiasing = ClientPrefs.data.antialiasing;
		}
		else difficultySprite.makeGraphic(1, 1, FlxColor.TRANSPARENT);

		difficultySprite.y = -difficultySprite.height;
		layerTop.add(difficultySprite);
		FlxTween.tween(difficultySprite, {y: 122}, 0.5, {ease: FlxEase.expoOut, startDelay: 0.8});

		clearPercentSmall = new ClearPercentCounter(difficultySprite.x + difficultySprite.width + 60, 0, clearPercentTarget, true);
		clearPercentSmall.y = -clearPercentSmall.height;
		clearPercentSmall.visible = false;
		layerTop.add(clearPercentSmall);

		songNameText = new FlxBitmapText(FlxBitmapFont.fromMonospace(Paths.image('results/tardlingSpritesheet'), FONT_LETTERS, FlxPoint.get(49, 62)));
		songNameText.text = data.songName;
		songNameText.letterSpacing = -15;
		songNameText.angle = -4.4;
		songNameText.x = clearPercentSmall.x + 94;
		songNameText.y = -songNameText.height;
		layerTop.add(songNameText);

		var nudge:Float = 10 * (songNameText.text.length / 15);
		FlxTween.tween(songNameText, {y: 122 - 25 - nudge}, 0.5, {ease: FlxEase.expoOut, startDelay: 0.9});

		blackTopBar = new FlxSprite(0, 0);
		if(Paths.fileExists('images/results/topBarBlack.png', IMAGE))
			blackTopBar.loadGraphic(Paths.image('results/topBarBlack'));
		else
			blackTopBar.makeGraphic(FlxG.width, 148, FlxColor.BLACK);

		blackTopBar.y = -blackTopBar.height;
		layerTop.add(blackTopBar);
		FlxTween.tween(blackTopBar, {y: 0}, 7 / 24, {ease: FlxEase.quartOut, startDelay: 3 / 24});
	}

	function buildSoundSystem()
	{
		if(!Paths.fileExists('images/results/soundSystem.png', IMAGE)) return;

		var soundSystem:FlxSprite = new FlxSprite(-15, -180);
		soundSystem.frames = Paths.getSparrowAtlas('results/soundSystem');
		soundSystem.animation.addByPrefix('idle', 'sound system', 24, false);
		soundSystem.antialiasing = ClientPrefs.data.antialiasing;
		soundSystem.visible = false;
		layerTop.add(soundSystem);

		wait(8 / 24, function()
		{
			soundSystem.visible = true;
			soundSystem.animation.play('idle');
		});
	}

	function buildResultsAnim()
	{
		if(!Paths.fileExists('images/results/results.png', IMAGE)) return;

		var anim:FlxSprite = new FlxSprite(FlxG.width - 1480, -10);
		anim.frames = Paths.getSparrowAtlas('results/results');
		anim.animation.addByPrefix('idle', 'results instance 1', 24, false);
		anim.antialiasing = ClientPrefs.data.antialiasing;
		anim.visible = false;
		layerFront.add(anim);

		wait(6 / 24, function()
		{
			anim.visible = true;
			anim.animation.play('idle');
		});
	}

	function buildPopins()
	{
		if(Paths.fileExists('images/results/ratingsPopin.png', IMAGE))
		{
			var ratingsPopin:FlxSprite = new FlxSprite(-135, 135);
			ratingsPopin.frames = Paths.getSparrowAtlas('results/ratingsPopin');
			ratingsPopin.animation.addByPrefix('idle', 'Categories', 24, false);
			ratingsPopin.antialiasing = ClientPrefs.data.antialiasing;
			ratingsPopin.visible = false;
			layerFront.add(ratingsPopin);

			wait(21 / 24, function()
			{
				ratingsPopin.visible = true;
				ratingsPopin.animation.play('idle');
			});
		}

		if(Paths.fileExists('images/results/scorePopin.png', IMAGE))
		{
			var scorePopin:FlxSprite = new FlxSprite(-180, 515);
			scorePopin.frames = Paths.getSparrowAtlas('results/scorePopin');
			scorePopin.animation.addByPrefix('idle', 'tally score', 24, false);
			scorePopin.antialiasing = ClientPrefs.data.antialiasing;
			scorePopin.visible = false;
			layerFront.add(scorePopin);

			wait(36 / 24, function()
			{
				scorePopin.visible = true;
				scorePopin.animation.play('idle');
			});
		}
	}

	function buildScore()
	{
		score = new ResultScore(SCORE_X, SCORE_Y, 10, data.score);
		score.visible = false;
		layerFront.add(score);
	}

	function buildTallies()
	{
		var hStuf:Int = 50;
		var extra:Float = 7;

		var entries:Array<{x:Float, y:Float, value:Int, color:FlxColor}> = [
			{x: 375, y: hStuf * 3, value: data.totalHits, color: FlxColor.WHITE},
			{x: 375, y: hStuf * 4, value: data.maxCombo, color: FlxColor.WHITE}
		];

		hStuf += 4;

		entries.push({x: 230, y: (hStuf * 5) + extra, value: data.sicks, color: 0xFF89E59E});
		entries.push({x: 210, y: (hStuf * 6) + extra, value: data.goods, color: 0xFF89C9E5});
		entries.push({x: 190, y: (hStuf * 7) + extra, value: data.bads, color: 0xFFE6CF8A});
		entries.push({x: 220, y: (hStuf * 8) + extra, value: data.shits, color: 0xFFE68C8A});
		entries.push({x: 260, y: (hStuf * 9) + extra, value: data.misses, color: 0xFFC68AE6});

		for(entry in entries)
		{
			var tally:TallyCounter = new TallyCounter(entry.x, entry.y, 0, entry.color);
			tally.visible = false;
			layerFront.add(tally);
			tallies.push(tally);
		}

		for(i in 0...tallies.length)
		{
			var tally:TallyCounter = tallies[i];
			var target:Int = entries[i].value;

			wait((0.3 * i) + 1.2, function()
			{
				tally.visible = true;
				tally.neededNumber = target;
				FlxTween.tween(tally, {curNumber: target}, 0.5, {ease: FlxEase.quartOut});
			});
		}
	}

	function buildHighscore()
	{
		if(!Paths.fileExists('images/results/highscoreNew.png', IMAGE)) return;

		highscoreNew = new FlxSprite(44, 557);
		highscoreNew.frames = Paths.getSparrowAtlas('results/highscoreNew');
		highscoreNew.animation.addByPrefix('new', 'highscoreAnim0', 24, false);
		highscoreNew.antialiasing = ClientPrefs.data.antialiasing;
		highscoreNew.visible = false;
		layerFront.add(highscoreNew);

		if(!data.isNewHighscore) return;

		wait(RankData.highscoreDelay(rank), function()
		{
			highscoreNew.visible = true;
			highscoreNew.animation.play('new');
			highscoreNew.animation.finishCallback = function(_) highscoreNew.animation.play('new', true, false, 16);
		});
	}

	function scheduleSequence()
	{
		wait(37 / 24, function()
		{
			score.visible = true;
			score.animateNumbers();
			startPercentSequence();
		});

		wait(RankData.characterDelay(rank), afterCharacterDelay);
		wait(RankData.flashDelay(rank), displayRankText);
		wait(RankData.musicDelay(rank), startMusic);
		wait(0.5, function() canExit = true);
	}

	function startPercentSequence()
	{
		bgFlash.visible = true;
		bgFlash.alpha = 1;
		FlxTween.tween(bgFlash, {alpha: 0}, 5 / 24);

		var startAt:Int = Std.int(Math.max(0, clearPercentTarget - 36));
		var lerped:Int = startAt;

		clearPercentBig = new ClearPercentCounter(FlxG.width / 2 + 190, FlxG.height / 2 - 70, startAt);
		layerPercent.add(clearPercentBig);

		FlxTween.tween(clearPercentBig, {curNumber: clearPercentTarget}, 58 / 24, {
			ease: FlxEase.quartOut,
			onUpdate: function(_)
			{
				if(lerped != clearPercentBig.curNumber)
				{
					lerped = clearPercentBig.curNumber;
					FlxG.sound.play(Paths.sound('scrollMenu'));
				}
			},
			onComplete: function(_)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				clearPercentBig.curNumber = clearPercentTarget;

				wait(0.75, function()
				{
					FlxTween.tween(clearPercentBig, {alpha: 0}, 0.5, {
						ease: FlxEase.quartOut,
						onComplete: function(_) layerPercent.remove(clearPercentBig, true)
					});
				});
			}
		});
	}

	function afterCharacterDelay()
	{
		if(clearPercentSmall != null)
		{
			clearPercentSmall.visible = true;
			clearPercentSmall.curNumber = clearPercentTarget;
			FlxTween.tween(clearPercentSmall, {y: 117}, 0.5, {ease: FlxEase.expoOut});
		}

		for(layer in atlasLayers)
		{
			var entry = layer;
			wait(entry.delay, function()
			{
				entry.sprite.visible = true;

				if(entry.sparrow)
				{
					entry.sprite.animation.play('idle', true);
					return;
				}

				#if flxanimate
				var atlas:FlxAnimate = cast entry.sprite;
				atlas.anim.play('', true);
				#end
			});
		}
	}

	function displayRankText()
	{
		bgFlash.visible = true;
		bgFlash.alpha = 1;
		FlxTween.tween(bgFlash, {alpha: 0}, 14 / 24);

		var vertKey:String = 'results/rankText/rankText' + RankData.suffix(rank);
		if(Paths.fileExists('images/$vertKey.png', IMAGE))
		{
			var rankTextVert:FlxBackdrop = new FlxBackdrop(Paths.image(vertKey), Y, 0, 30);
			rankTextVert.x = FlxG.width - 44;
			rankTextVert.y = 100;
			layerRankVert.add(rankTextVert);

			FlxFlicker.flicker(rankTextVert, 2 / 24 * 3, 2 / 24, true);
			wait(30 / 24, function() rankTextVert.velocity.y = -80);
		}

		var horKey:String = 'results/rankText/rankScroll' + RankData.suffix(rank);
		if(!Paths.fileExists('images/$horKey.png', IMAGE)) return;

		for(i in 0...12)
		{
			var back:FlxBackdrop = new FlxBackdrop(Paths.image(horKey), X, 10, 0);
			back.x = FlxG.width / 2 - 320;
			back.y = 50 + (135 * i / 2) + 10;
			back.cameras = [camScroll];
			back.velocity.x = (i % 2 == 0) ? -7 : 7;
			layerScroll.add(back);
		}
	}

	function startMusic()
	{
		var track:String = RankData.musicPath(rank, character);
		if(!musicExists('$track/$track')) track = RankData.musicPath(rank, 'bf');
		if(!musicExists('$track/$track')) return;

		var intro:String = '$track/$track-intro';
		if(musicExists(intro))
		{
			FlxG.sound.playMusic(Paths.music(intro), 1, false);
			FlxG.sound.music.onComplete = function() FlxG.sound.playMusic(Paths.music('$track/$track'), 1, true);
			return;
		}

		FlxG.sound.playMusic(Paths.music('$track/$track'), 1, true);
	}

	function musicExists(key:String):Bool
		return Paths.fileExists('music/$key.${Paths.SOUND_EXT}', SOUND);

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(canExit && (controls.ACCEPT || controls.BACK))
		{
			canExit = false;
			FlxG.sound.play(Paths.sound('confirmMenu'));
			finish();
		}
	}

	function finish()
	{
		for(timer in timers) if(timer != null) timer.cancel();
		if(FlxG.sound.music != null) FlxG.sound.music.onComplete = null;

		if(onContinue != null) onContinue();
	}
}
