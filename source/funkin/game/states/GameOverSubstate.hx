package funkin.game.states;

import funkin.data.WeekData;

import funkin.game.Character;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.math.FlxPoint;

import funkin.ui.states.StoryMenuState;
import funkin.ui.states.FreeplayState;

class GameOverSubstate extends MusicBeatSubstate
{
	public var boyfriend:Character;
	var camFollow:FlxObject;

	var stagePostfix:String = "";

	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';
	public static var deathDelay:Float = 0;

	public static var instance:GameOverSubstate;
	public function new(?playStateBoyfriend:Character = null)
	{
		if(playStateBoyfriend != null && playStateBoyfriend.curCharacter == characterName) //Avoids spawning a second boyfriend cuz animate atlas is laggy
		{
			this.boyfriend = playStateBoyfriend;
		}
		super();
	}

	public static function resetVariables() {
		characterName = 'bf-dead';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';
		deathDelay = 0;

		var _song = PlayState.SONG;
		if(_song != null)
		{
			if(_song.gameOverChar != null && _song.gameOverChar.trim().length > 0) characterName = _song.gameOverChar;
			if(_song.gameOverSound != null && _song.gameOverSound.trim().length > 0) deathSoundName = _song.gameOverSound;
			if(_song.gameOverLoop != null && _song.gameOverLoop.trim().length > 0) loopSoundName = _song.gameOverLoop;
			if(_song.gameOverEnd != null && _song.gameOverEnd.trim().length > 0) endSoundName = _song.gameOverEnd;
		}
	}

	var charX:Float = 0;
	var charY:Float = 0;

	var overlay:FlxSprite;
	var overlayConfirmOffsets:FlxPoint = FlxPoint.get();
	override function create()
	{
		instance = this;

		Conductor.songPosition = 0;

		var deathScroll:FlxPoint = FlxPoint.get();
		if(boyfriend == null)
		{
			deathScroll.set(FlxG.camera.scroll.x, FlxG.camera.scroll.y);
			boyfriend = new Character(PlayState.instance.boyfriend.getScreenPosition().x, PlayState.instance.boyfriend.getScreenPosition().y, characterName, true);
			boyfriend.x += boyfriend.positionArray[0] - PlayState.instance.boyfriend.positionArray[0];
			boyfriend.y += boyfriend.positionArray[1] - PlayState.instance.boyfriend.positionArray[1];
		}
		boyfriend.skipDance = true;
		boyfriend.canPlayOtherAnims = true;
		boyfriend.animSuffix = '';
		add(boyfriend);

		FlxG.sound.play(Paths.sound(deathSoundName));
		FlxG.camera.scroll.set();
		FlxG.camera.target = null;
		if(PlayState.instance.stageData != null) FlxG.camera.zoom = PlayState.instance.stageData.defaultZoom;

		boyfriend.playAnim('firstDeath');

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(boyfriend.getGraphicMidpoint().x + boyfriend.cameraPosition[0], boyfriend.getGraphicMidpoint().y + boyfriend.cameraPosition[1]);
		FlxG.camera.focusOn(new FlxPoint(FlxG.camera.scroll.x + (FlxG.camera.width / 2), FlxG.camera.scroll.y + (FlxG.camera.height / 2)));
		FlxG.camera.follow(camFollow, LOCKON, 0.01);
		add(camFollow);
		
		PlayState.instance.setOnScripts('inGameOver', true);
		PlayState.instance.callOnScripts('onGameOverStart', []);
		FlxG.sound.music.loadEmbedded(Paths.music(loopSoundName), true);

		if(characterName == 'pico-dead' || characterName == 'pico-christmas-dead')
		{
			overlay = new FlxSprite(boyfriend.x + 205, boyfriend.y - 80);
			overlay.frames = Paths.getSparrowAtlas('Pico_Death_Retry');
			overlay.animation.addByPrefix('deathLoop', 'Retry Text Loop', 24, true);
			overlay.animation.addByPrefix('deathConfirm', 'Retry Text Confirm', 24, false);
			overlay.antialiasing = ClientPrefs.data.antialiasing;
			overlayConfirmOffsets.set(250, 200);
			overlay.visible = false;
			add(overlay);

			boyfriend.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int)
			{
				switch(name)
				{
					case 'firstDeath':
						if(frameNumber >= 36 - 1)
						{
							overlay.visible = true;
							overlay.animation.play('deathLoop');
							boyfriend.animation.callback = null;
						}
					default:
						boyfriend.animation.callback = null;
				}
			}
		}

		if(['pico-dead', 'pico-christmas-dead', 'pico-pixel-dead'].contains(characterName))
		{
			var gf:Character = PlayState.instance.gf;
			if(gf != null && funkin.game.stages.PicoCapableStage.NENE_LIST.contains(gf.curCharacter))
			{
				var idle:Array<Dynamic> = gf.animOffsets.get(gf.animOffsets.exists('danceLeft') ? 'danceLeft' : 'idle');
				var neneX:Float = gf.x - (idle != null ? idle[0] : 0) - deathScroll.x * gf.scrollFactor.x;
				var neneY:Float = gf.y - (idle != null ? idle[1] : 0) - deathScroll.y * gf.scrollFactor.y;
				var neneKnife:FlxSprite = new FlxSprite();
				switch(gf.curCharacter)
				{
					case 'nene-pixel':
						neneKnife.frames = Paths.getSparrowAtlas('characters_pixel/nenePixel/nenePixelKnifeToss');
						neneKnife.animation.addByPrefix('anim', 'knifetosscolor', 24, false);
						neneKnife.scale.set(6, 6);
						neneKnife.antialiasing = false;
						neneKnife.setPosition(neneX + gf.origin.x * (1 - gf.scale.x) + 280, neneY + gf.origin.y * (1 - gf.scale.y) + 170);
					case 'nene-christmas':
						neneKnife.frames = Paths.getSparrowAtlas('characters/mallPico/neneChristmasKnife');
						neneKnife.animation.addByPrefix('anim', 'knife toss xmas', 24, false);
						neneKnife.antialiasing = ClientPrefs.data.antialiasing;
						neneKnife.setPosition(neneX + 16, neneY + 49);
					default:
						neneKnife.frames = Paths.getSparrowAtlas('NeneKnifeToss');
						neneKnife.animation.addByPrefix('anim', 'knife toss', 24, false);
						neneKnife.antialiasing = ClientPrefs.data.antialiasing;
						neneKnife.setPosition(neneX + 116, neneY + 89);
				}
				neneKnife.scrollFactor.set(gf.scrollFactor.x, gf.scrollFactor.y);
				neneKnife.animation.finishCallback = function(_)
				{
					remove(neneKnife);
					neneKnife.destroy();
				}
				insert(0, neneKnife);
				neneKnife.animation.play('anim', true);
			}
		}
		deathScroll.put();

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		PlayState.instance.callOnScripts('onUpdate', [elapsed]);

		var justPlayedLoop:Bool = false;
		if (!boyfriend.isAnimationNull() && boyfriend.getAnimationName() == 'firstDeath' && boyfriend.isAnimationFinished())
		{
			boyfriend.playAnim('deathLoop');
			if(overlay != null && overlay.animation.exists('deathLoop'))
			{
				overlay.visible = true;
				overlay.animation.play('deathLoop');
			}
			justPlayedLoop = true;
		}

		if(!isEnding)
		{
			if (controls.ACCEPT)
			{
				endBullshit();
			}
			else if (controls.BACK)
			{
				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
				FlxG.camera.visible = false;
				FlxG.sound.music.stop();
				PlayState.deathCounter = 0;
				PlayState.seenCutscene = false;
				PlayState.chartingMode = false;
	
				Mods.loadTopMod();
				if (PlayState.isStoryMode)
					MusicBeatState.switchState(new StoryMenuState());
				else
					MusicBeatState.switchState(new FreeplayState());
	
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				PlayState.instance.callOnScripts('onGameOverConfirm', [false]);
			}
			else if (justPlayedLoop)
			{
				switch(PlayState.SONG.stage)
				{
					case 'tank' | 'tankmanBattlefieldErect':
						coolStartDeath(0.2);

						var jeffLine:String = switch(PlayState.SONG.player1)
						{
							case 'pico-playable' | 'pico-holding-nene': pickJeffLine(JEFF_PICO_FOLDER, 9, JEFF_PICO_SWEARS);
							case 'bf' | 'bf-holding-gf': pickJeffLine(JEFF_FOLDER, 25, JEFF_SWEARS);
							default: PlayState.SONG.player1.startsWith('pico') ? '$JEFF_PICO_FOLDER/jeffGameover-10' : pickJeffLine(JEFF_FOLDER, 25, JEFF_SWEARS);
						}
						var jeffSound:FlxSound = FlxG.sound.play(boostedJeffSound(jeffSoundKey(jeffLine)), 1, false, null, true, function() {
							if(!isEnding)
							{
								FlxG.sound.music.fadeIn(0.2, 1, 4);
							}
						});
						playJeffSubtitles(jeffLine, jeffSound);

					default:
						coolStartDeath();
				}
			}
			
			if (FlxG.sound.music.playing)
			{
				Conductor.songPosition = FlxG.sound.music.time;
			}
		}
		PlayState.instance.callOnScripts('onUpdatePost', [elapsed]);
	}

	static inline final JEFF_FOLDER:String = 'jeffGameover';
	static inline final JEFF_PICO_FOLDER:String = 'jeffGameover-pico';
	static final JEFF_SWEARS:Array<Int> = [1, 3, 8, 13, 17, 21];
	static final JEFF_PICO_SWEARS:Array<Int> = [4, 7, 8, 9];
	static inline final JEFF_BOOST_DB:Float = 4;
	static inline final JEFF_LIMIT:Float = 0.8;

	var jeffSubtitles:funkin.game.subtitles.Subtitles;

	function pickJeffLine(folder:String, count:Int, swears:Array<Int>):String
	{
		var pool:Array<Int> = [];
		for (number in 1...count + 1)
			if(ClientPrefs.data.naughtyness || !swears.contains(number) || censoredJeffKey('$folder/jeffGameover-$number') != null)
				pool.push(number);
		#if MEMTEST
		funkin.debug.MemoryTest.log('jeff pool $folder ${pool.join(",")}');
		if(funkin.debug.MemoryTest.forceJeff > 0) return '$folder/jeffGameover-${funkin.debug.MemoryTest.forceJeff}';
		#end
		return '$folder/jeffGameover-${pool[FlxG.random.int(0, pool.length - 1)]}';
	}

	function censoredJeffKey(line:String):String
	{
		var slash:Int = line.lastIndexOf('/');
		var folder:String = line.substr(0, slash);
		var number:String = line.substr(line.lastIndexOf('-') + 1);
		for (key in ['$folder/censored/jeffGameover-c$number', '$folder/censored/$folder' + '_c$number', '$line-censored'])
			if(funkin.backend.Naughtyness.soundExists(key)) return key;
		return null;
	}

	function jeffSoundKey(line:String):String
	{
		if(ClientPrefs.data.naughtyness) return line;
		var censored:String = censoredJeffKey(line);
		return censored != null ? censored : line;
	}

	function boostedJeffSound(key:String):openfl.media.Sound
	{
		#if sys
		var file:String = Paths.getPath('sounds/$key.${Paths.SOUND_EXT}', SOUND);
		if(sys.FileSystem.exists(file))
		{
			var buffer:lime.media.AudioBuffer = lime.media.AudioBuffer.fromFile(file);
			if(buffer != null && buffer.data != null && buffer.bitsPerSample == 16)
			{
				boostSamples(buffer, Math.pow(10, JEFF_BOOST_DB / 20));
				return openfl.media.Sound.fromAudioBuffer(buffer);
			}
		}
		#end
		return Paths.sound(key);
	}

	static function boostSamples(buffer:lime.media.AudioBuffer, gain:Float)
	{
		var bytes:haxe.io.Bytes = buffer.data.buffer;
		var offset:Int = buffer.data.byteOffset;
		for (i in 0...Std.int(buffer.data.byteLength / 2))
		{
			var raw:Int = bytes.getUInt16(offset + i * 2);
			if(raw >= 32768) raw -= 65536;
			var value:Float = raw / 32768 * gain;
			var level:Float = Math.abs(value);
			if(level > JEFF_LIMIT)
			{
				var over:Float = (level - JEFF_LIMIT) / (1 - JEFF_LIMIT);
				level = JEFF_LIMIT + (1 - JEFF_LIMIT) * (1 - 2 / (Math.exp(2 * over) + 1));
			}
			var sample:Int = Math.round((value < 0 ? -level : level) * 32767);
			bytes.setUInt16(offset + i * 2, sample & 0xFFFF);
		}
	}

	function playJeffSubtitles(line:String, sound:FlxSound)
	{
		var data:funkin.game.subtitles.SubtitleData = funkin.game.subtitles.SubtitleData.load('subtitles/$line');
		if(data == null || sound == null) return;

		if(jeffSubtitles == null)
		{
			jeffSubtitles = new funkin.game.subtitles.Subtitles(PlayState.CUTSCENE_SUBTITLES_MARGIN);
			jeffSubtitles.cameras = [PlayState.instance.camOther];
			add(jeffSubtitles);
		}
		jeffSubtitles.play(data, funkin.game.subtitles.Subtitles.soundClock(sound));
	}

	var isEnding:Bool = false;
	function coolStartDeath(?volume:Float = 1):Void
	{
		FlxG.sound.music.play(true);
		FlxG.sound.music.volume = volume;
	}

	function endBullshit():Void
	{
		if (!isEnding)
		{
			isEnding = true;
			if(boyfriend.hasAnimation('deathConfirm'))
				boyfriend.playAnim('deathConfirm', true);
			else if(boyfriend.hasAnimation('deathLoop'))
				boyfriend.playAnim('deathLoop', true);

			if(overlay != null && overlay.animation.exists('deathConfirm'))
			{
				overlay.visible = true;
				overlay.animation.play('deathConfirm');
				overlay.offset.set(overlayConfirmOffsets.x, overlayConfirmOffsets.y);
			}
			FlxG.sound.music.stop();
			FlxG.sound.play(Paths.music(endSoundName));
			new FlxTimer().start(0.7, function(tmr:FlxTimer)
			{
				FlxG.camera.fade(FlxColor.BLACK, 2, false, function()
				{
					MusicBeatState.resetState();
				});
			});
			PlayState.instance.callOnScripts('onGameOverConfirm', [true]);
		}
	}

	override function destroy()
	{
		instance = null;
		super.destroy();
	}
}
