package funkin.ui.states;

import flixel.FlxBasic;
import flixel.addons.display.FlxBackdrop;
import flixel.text.FlxBitmapText;
import flixel.graphics.frames.FlxBitmapFont;
import flixel.util.FlxGradient;
import flixel.math.FlxPoint;
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
	public static var FONT_LETTERS:String = "AaBbCcDdEeFfGgHhiIJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz:1234567890().-";

	var data:ResultsData;
	var onContinue:Void->Void;
	var rank:ResultsRank;
	var character:String;

	var camBG:FlxCamera;
	var camScroll:FlxCamera;
	var camMain:FlxCamera;

	var blackTopBar:FlxSprite;
	var songNameText:FlxBitmapText;
	var difficultySprite:FlxSprite;
	var clearPercentBig:ClearPercentCounter;
	var clearPercentSmall:ClearPercentCounter;
	var scoreCounter:ScoreCounter;
	var highscoreSprite:FlxSprite;

	var rankTextBack:FlxBackdrop;
	var rankTextFront:FlxBackdrop;

	var characterLayers:Array<FlxBasic> = [];
	var timers:Array<FlxTimer> = [];
	var tweens:Array<FlxTween> = [];

	var displayedScore:Int = 0;
	var canExit:Bool = false;

	public function new(data:ResultsData, onContinue:Void->Void)
	{
		super();
		this.data = data;
		this.onContinue = onContinue;
		this.rank = RankData.calculate(data.accuracy, data.misses, data.sicks, data.totalHits);
		this.character = RankData.resolveCharacter(data.playerCharacter);
	}

	override function create()
	{
		persistentUpdate = false;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Results Screen', data.songName);
		#end

		setupCameras();

		var bg:FlxSprite = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFFFECC5C, 0xFFFDC05C], 90);
		bg.cameras = [camBG];
		add(bg);

		buildRankBackdrops();
		buildCharacters();
		buildSoundSystem();
		buildResultsAnimation();
		buildTopBar();
		buildCounters();
		buildTallies();
		buildPopins();

		startMusic();

		wait(0.5, function() canExit = true);

		super.create();
	}

	function setupCameras()
	{
		camBG = new FlxCamera();
		camScroll = new FlxCamera();
		camMain = new FlxCamera();

		camScroll.bgColor.alpha = 0;
		camMain.bgColor.alpha = 0;
		camScroll.angle = -3.8;

		FlxG.cameras.reset(camBG);
		FlxG.cameras.add(camScroll, false);
		FlxG.cameras.add(camMain, false);

		FlxG.cameras.setDefaultDrawTarget(camMain, true);
		_psychCameraInitialized = true;
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

	function buildRankBackdrops()
	{
		var scrollKey:String = 'results/rankText/rankScroll' + RankData.suffix(rank);
		var textKey:String = 'results/rankText/rankText' + RankData.suffix(rank);

		if(Paths.fileExists('images/$scrollKey.png', IMAGE))
		{
			rankTextBack = new FlxBackdrop(Paths.image(scrollKey), X, 0, 0);
			rankTextBack.cameras = [camScroll];
			rankTextBack.y = FlxG.height / 2 - 50;
			rankTextBack.velocity.x = -80;
			rankTextBack.visible = false;
			add(rankTextBack);
		}

		if(Paths.fileExists('images/$textKey.png', IMAGE))
		{
			rankTextFront = new FlxBackdrop(Paths.image(textKey), X, 30, 0);
			rankTextFront.cameras = [camScroll];
			rankTextFront.y = FlxG.height / 2 - 220;
			rankTextFront.velocity.x = -220;
			rankTextFront.visible = false;
			add(rankTextFront);
		}

		wait(RankData.flashDelay(rank), function()
		{
			if(rankTextBack != null) rankTextBack.visible = true;
			if(rankTextFront != null) rankTextFront.visible = true;

			var flash:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, RankData.color(rank));
			flash.cameras = [camMain];
			add(flash);
			tweens.push(FlxTween.tween(flash, {alpha: 0}, 0.6, {onComplete: function(_) {
				remove(flash, true);
				flash.destroy();
			}}));
		});
	}

	function buildCharacters()
	{
		var layers:Array<ResultsLayer> = RankData.layers(rank, character);

		for(layer in layers)
		{
			if(layer.sparrow == true)
			{
				if(!Paths.fileExists('images/${layer.asset}.png', IMAGE)) continue;

				var spr:FlxSprite = new FlxSprite(layer.offsetX != null ? layer.offsetX : 0, layer.offsetY != null ? layer.offsetY : 0);
				spr.frames = Paths.getSparrowAtlas(layer.asset);
				spr.animation.addByPrefix('idle', '', 24, layer.loop == true);
				spr.animation.play('idle');
				spr.antialiasing = ClientPrefs.data.antialiasing;
				spr.visible = false;
				add(spr);
				characterLayers.push(spr);
				continue;
			}

			#if flxanimate
			if(!Paths.fileExists('images/${layer.asset}/Animation.json', TEXT)) continue;

			var atlas:FlxAnimate = new FlxAnimate(layer.offsetX != null ? layer.offsetX : 0, layer.offsetY != null ? layer.offsetY : 0);
			atlas.showPivot = false;

			try
			{
				Paths.loadAnimateAtlas(atlas, layer.asset);
			}
			catch(e:haxe.Exception)
			{
				FlxG.log.warn('Results: atlas ${layer.asset} non caricato: $e');
				continue;
			}

			atlas.anim.play('');
			atlas.anim.pause();
			if(layer.loop == true) atlas.anim.loopType = flxanimate.data.AnimationData.Loop.Loop;
			atlas.antialiasing = ClientPrefs.data.antialiasing;
			atlas.visible = false;
			add(atlas);
			characterLayers.push(atlas);
			#end
		}

		wait(RankData.characterDelay(rank), function()
		{
			for(layer in characterLayers)
			{
				if(Std.isOfType(layer, FlxSprite))
				{
					var spr:FlxSprite = cast layer;
					spr.visible = true;
					if(spr.animation.curAnim != null) spr.animation.play(spr.animation.curAnim.name, true);
				}

				#if flxanimate
				if(Std.isOfType(layer, FlxAnimate))
				{
					var atlas:FlxAnimate = cast layer;
					atlas.visible = true;
					atlas.anim.play('', true);
				}
				#end
			}
		});
	}

	function buildSoundSystem()
	{
		if(!Paths.fileExists('images/results/soundSystem.png', IMAGE)) return;

		var soundSystem:FlxSprite = new FlxSprite(-15, -180);
		soundSystem.frames = Paths.getSparrowAtlas('results/soundSystem');
		soundSystem.animation.addByPrefix('idle', 'sound system', 24, false);
		soundSystem.antialiasing = ClientPrefs.data.antialiasing;
		soundSystem.visible = false;
		add(soundSystem);

		wait(8 / 24, function()
		{
			soundSystem.visible = true;
			soundSystem.animation.play('idle');
		});
	}

	function buildResultsAnimation()
	{
		if(!Paths.fileExists('images/results/results.png', IMAGE)) return;

		var anim:FlxSprite = new FlxSprite(FlxG.width - 1480, -10);
		anim.frames = Paths.getSparrowAtlas('results/results');
		anim.animation.addByPrefix('idle', 'results instance', 24, false);
		anim.antialiasing = ClientPrefs.data.antialiasing;
		anim.visible = false;
		add(anim);

		wait(6 / 24, function()
		{
			anim.visible = true;
			anim.animation.play('idle');
		});
	}

	function buildTopBar()
	{
		blackTopBar = new FlxSprite(0, 0);
		if(Paths.fileExists('images/results/topBarBlack.png', IMAGE))
			blackTopBar.loadGraphic(Paths.image('results/topBarBlack'));
		else
			blackTopBar.makeGraphic(FlxG.width, 148, FlxColor.BLACK);

		blackTopBar.y = -blackTopBar.height;
		add(blackTopBar);

		tweens.push(FlxTween.tween(blackTopBar, {y: 0}, 7 / 24, {ease: FlxEase.quartOut, startDelay: 3 / 24}));

		var diffKey:String = 'results/diff_' + data.difficulty.toLowerCase();
		if(!Paths.fileExists('images/$diffKey.png', IMAGE)) diffKey = 'results/diff_normal';

		difficultySprite = new FlxSprite(0, 0);
		if(Paths.fileExists('images/$diffKey.png', IMAGE))
		{
			difficultySprite.loadGraphic(Paths.image(diffKey));
			difficultySprite.antialiasing = ClientPrefs.data.antialiasing;
			difficultySprite.x = 100;
			difficultySprite.y = -difficultySprite.height;
			add(difficultySprite);

			tweens.push(FlxTween.tween(difficultySprite, {y: 90}, 0.5, {ease: FlxEase.expoOut, startDelay: 0.9}));
		}

		songNameText = new FlxBitmapText(FlxBitmapFont.fromMonospace(Paths.image('results/tardlingSpritesheet'), FONT_LETTERS, FlxPoint.get(49, 61)));
		songNameText.text = data.songName;
		songNameText.letterSpacing = -15;
		songNameText.angle = -4.4;
		songNameText.x = 220;
		songNameText.y = -songNameText.height;
		add(songNameText);

		tweens.push(FlxTween.tween(songNameText, {y: 25}, 0.5, {ease: FlxEase.expoOut, startDelay: 0.9}));
	}

	function buildCounters()
	{
		var targetPercent:Int = Math.round(data.accuracy * 100);

		clearPercentBig = new ClearPercentCounter(FlxG.width / 2 + 190, FlxG.height / 2 - 70, 0, false);
		clearPercentBig.visible = false;
		add(clearPercentBig);

		clearPercentSmall = new ClearPercentCounter(100, 30, targetPercent, true);
		clearPercentSmall.visible = false;
		add(clearPercentSmall);

		wait(21 / 24, function()
		{
			clearPercentBig.visible = true;
			var counter = {value: 0.0};
			tweens.push(FlxTween.tween(counter, {value: targetPercent}, 58 / 24, {
				ease: FlxEase.quartOut,
				onUpdate: function(_) clearPercentBig.curNumber = Math.round(counter.value),
				onComplete: function(_)
				{
					clearPercentBig.curNumber = targetPercent;
					clearPercentSmall.visible = true;
				}
			}));
		});

		scoreCounter = new ScoreCounter(35, 305);
		scoreCounter.visible = false;
		add(scoreCounter);

		wait(37 / 24, function()
		{
			scoreCounter.visible = true;
			var counter = {value: 0.0};
			tweens.push(FlxTween.tween(counter, {value: data.score}, 1.5, {
				ease: FlxEase.quartOut,
				onUpdate: function(_) scoreCounter.curNumber = Math.round(counter.value),
				onComplete: function(_) scoreCounter.curNumber = data.score
			}));
		});

		if(data.isNewHighscore && Paths.fileExists('images/results/highscoreNew.png', IMAGE))
		{
			highscoreSprite = new FlxSprite(44, 557);
			highscoreSprite.frames = Paths.getSparrowAtlas('results/highscoreNew');
			highscoreSprite.animation.addByPrefix('idle', 'highscoreAnim', 24, false);
			highscoreSprite.antialiasing = ClientPrefs.data.antialiasing;
			highscoreSprite.visible = false;
			add(highscoreSprite);

			wait(RankData.highscoreDelay(rank), function()
			{
				highscoreSprite.visible = true;
				highscoreSprite.animation.play('idle');
			});
		}
	}

	function buildTallies()
	{
		var entries:Array<{name:String, value:Int, y:Float, color:FlxColor}> = [
			{name: 'TOTAL NOTES HIT', value: data.totalHits, y: 150, color: FlxColor.WHITE},
			{name: 'MAXIMUM COMBO', value: data.maxCombo, y: 200, color: FlxColor.WHITE},
			{name: 'SICK', value: data.sicks, y: 235, color: 0xFF89E59E},
			{name: 'GOOD', value: data.goods, y: 285, color: 0xFF89C9E5},
			{name: 'BAD', value: data.bads, y: 335, color: 0xFFE6CF8A},
			{name: 'SHIT', value: data.shits, y: 385, color: 0xFFE68C8A},
			{name: 'MISSED', value: data.misses, y: 435, color: 0xFFC68AE6}
		];

		for(i in 0...entries.length)
		{
			var entry = entries[i];
			var tally:TallyCounter = new TallyCounter(FlxG.width - 500, entry.y, entry.name, entry.value, entry.color);
			tally.visible = false;
			add(tally);

			wait(1.2 + (0.3 * i), function() tally.visible = true);
		}
	}

	function buildPopins()
	{
		if(Paths.fileExists('images/results/ratingsPopin.png', IMAGE))
		{
			var ratings:FlxSprite = new FlxSprite(-135, 135);
			ratings.frames = Paths.getSparrowAtlas('results/ratingsPopin');
			ratings.animation.addByPrefix('idle', 'Categories', 24, false);
			ratings.antialiasing = ClientPrefs.data.antialiasing;
			ratings.visible = false;
			add(ratings);

			wait(21 / 24, function()
			{
				ratings.visible = true;
				ratings.animation.play('idle');
			});
		}

		if(Paths.fileExists('images/results/scorePopin.png', IMAGE))
		{
			var scorePop:FlxSprite = new FlxSprite(-180, 515);
			scorePop.frames = Paths.getSparrowAtlas('results/scorePopin');
			scorePop.animation.addByPrefix('idle', 'tally score', 24, false);
			scorePop.antialiasing = ClientPrefs.data.antialiasing;
			scorePop.visible = false;
			add(scorePop);

			wait(36 / 24, function()
			{
				scorePop.visible = true;
				scorePop.animation.play('idle');
			});
		}
	}

	function startMusic()
	{
		var track:String = resolveMusic(RankData.musicPath(rank));
		if(track == null) return;

		wait(RankData.musicDelay(rank), function()
		{
			var intro:String = '$track-intro';
			if(musicExists('$track/$intro'))
			{
				FlxG.sound.playMusic(Paths.music('$track/$intro'), 1, false);
				FlxG.sound.music.onComplete = function()
				{
					FlxG.sound.playMusic(Paths.music('$track/$track'), 1, true);
				};
				return;
			}

			FlxG.sound.playMusic(Paths.music('$track/$track'), 1, true);
		});
	}

	function resolveMusic(track:String):String
	{
		if(character != 'bf' && musicExists('$track-$character/$track-$character')) return '$track-$character';
		if(musicExists('$track/$track')) return track;
		if(musicExists('$track-pico/$track-pico')) return '$track-pico';
		return null;
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
		for(tween in tweens) if(tween != null) tween.cancel();

		if(FlxG.sound.music != null) FlxG.sound.music.onComplete = null;

		FlxG.cameras.setDefaultDrawTarget(camMain, false);

		if(onContinue != null) onContinue();
	}
}
