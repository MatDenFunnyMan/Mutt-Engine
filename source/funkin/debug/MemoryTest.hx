package funkin.debug;

#if MEMTEST
import funkin.data.Song;
import funkin.data.Difficulty;
import funkin.game.states.PlayState;
import funkin.ui.states.LoadingState;
import funkin.util.MemoryUtils;
import sys.io.File;
import sys.io.FileOutput;

@:access(funkin.game.states.PlayState)
class MemoryTest
{
	static var output:FileOutput;
	static var startTime:Float = 0;
	static var lastLog:Float = 0;
	static var duration:Float = 60;
	static var peakGC:Float = 0;
	static var peakTask:Float = 0;
	static var sumGC:Float = 0;
	static var sumTask:Float = 0;
	static var samples:Int = 0;
	static var songStarted:Bool = false;
	static var songList:Array<String> = [];
	static var songIndex:Int = 0;
	static var difficultyIndex:Int = 0;
	static var difficultyName:String = null;
	static var frames:Int = 0;
	static var shots:Array<Float> = [8, 16];
	static var shotPending:String = null;
	static var sumFps:Float = 0;
	static var shotTimes:Array<Float> = [8, 16];
	static var viaFreeplay:Bool = false;
	static var freeplayUntil:Float = -1;
	static var actions:Array<String> = [];
	static var frameLogUntil:Float = 0;
	static var flashShots:Int = 0;
	static var loadingSince:Float = -1;
	static var spikes:sys.thread.Deque<String> = new sys.thread.Deque<String>();
	public static var phase:String = 'boot';

	public static function start():Bool
	{
		var args:Array<String> = Sys.args();
		if(args.contains('--atlascompare'))
		{
			output = File.write('memtest.log', false);
			Paths.setCurrentLevel(args[args.indexOf('--atlascompare') + 1]);
			FlxG.switchState(new flixel.FlxState());
			FlxG.signals.postUpdate.add(atlasCompareTick);
			FlxG.stage.window.onRender.add(onRender, false, -1000);
			return true;
		}
		if(args.contains('--rescycle'))
		{
			output = File.write('memtest.log', false);
			startResCycle();
			return true;
		}
		if(args.contains('--optionsmenu'))
		{
			output = File.write('memtest.log', false);
			startOptionsMenu();
			FlxG.stage.window.onRender.add(onRender, false, -1000);
			return true;
		}
		if(args.contains('--borderlesshold'))
		{
			output = File.write('memtest.log', false);
			var hold:Float = Std.parseFloat(args[args.indexOf('--borderlesshold') + 1]);
			var flat:flixel.FlxState = new flixel.FlxState();
			flat.bgColor = 0xFFFF00FF;
			FlxG.switchState(flat);
			ClientPrefs.data.resolution = 'Borderless';
			funkin.backend.DisplaySettings.applyResolution();
			haxe.Timer.delay(() -> logWindow('borderless'), 1500);
			haxe.Timer.delay(() -> { output.close(); Sys.exit(0); }, Std.int(hold * 1000));
			return true;
		}
		if(args.contains('--resultsshot'))
		{
			output = File.write('memtest.log', false);
			applyContentFlags(args);
			startResultsShot();
			FlxG.stage.window.onRender.add(onRender, false, -1000);
			return true;
		}
		if(args.contains('--peak'))
		{
			output = File.write('memtest.log', false);
			for (path in args[args.indexOf('--peak') + 1].split(','))
			{
				var decodeStart:Float = haxe.Timer.stamp();
				var buffer:lime.media.AudioBuffer = lime.media.AudioBuffer.fromFile(path);
				log('decode $path ${Math.round((haxe.Timer.stamp() - decodeStart) * 1000)}ms');
				if(buffer == null) { log('peak $path missing'); continue; }
				var bytes:haxe.io.Bytes = buffer.data.buffer;
				var offset:Int = buffer.data.byteOffset;
				var count:Int = Std.int(buffer.data.byteLength / 2);
				var peak:Int = 0;
				var hot:Int = 0;
				for (i in 0...count)
				{
					var raw:Int = bytes.getUInt16(offset + i * 2);
					if(raw >= 32768) raw -= 65536;
					var v:Int = raw < 0 ? -raw : raw;
					if(v > peak) peak = v;
					if(v >= 32000) hot++;
				}
				log('peak $path bits ${buffer.bitsPerSample} rate ${buffer.sampleRate} channels ${buffer.channels} samples $count peak $peak (${fmt(20 * Math.log(peak / 32768) / Math.log(10))} dBFS) hot $hot');
			}
			var textStart:Float = haxe.Timer.stamp();
			var text:flixel.text.FlxText = new flixel.text.FlxText(0, 0, 0, 'Singing that was cool and all but...', 30);
			text.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.WHITE, CENTER);
			text.drawFrame(true);
			log('first subtitle text ${Math.round((haxe.Timer.stamp() - textStart) * 1000)}ms');
			output.close();
			Sys.exit(0);
		}
		if(args.contains('--naughtycheck'))
		{
			output = File.write('memtest.log', false);
			naughtyCheck();
			output.close();
			Sys.exit(0);
			return true;
		}
		if(args.contains('--inputmenu'))
		{
			output = File.write('memtest.log', false);
			startInputMenu();
			FlxG.stage.window.onRender.add(onRender, false, -1000);
			return true;
		}
		if(args.contains('--mousecycle'))
		{
			output = File.write('memtest.log', false);
			startMouseCycle();
			return true;
		}
		if(args.contains('--freeplayscroll'))
		{
			startFreeplayScroll(args);
			return true;
		}
		var index:Int = args.indexOf('--memtest');
		if(index < 0 || args.length < index + 3) return false;

		var song:String = args[index + 1];
		var difficulty:String = args[index + 2];
		difficultyName = difficulty;
		if(args.length > index + 3) duration = Std.parseFloat(args[index + 3]);
		if(args.length > index + 4 && !args[index + 4].startsWith('--'))
		{
			Mods.currentModDirectory = args[index + 4];
		}

		if(args.contains('--shots')) shotTimes = [for (s in args[args.indexOf('--shots') + 1].split(',')) Std.parseFloat(s)];
		if(args.contains('--budget')) LoadingState.DECODE_BUDGET = Std.parseFloat(args[args.indexOf('--budget') + 1]) * 1048576;
		if(args.contains('--collect')) Paths.COLLECT_AFTER_UPLOAD = Std.parseFloat(args[args.indexOf('--collect') + 1]) * 1048576;
		if(args.contains('--nostream')) ClientPrefs.data.streamSongs = false;
		if(args.contains('--downscroll')) ClientPrefs.data.downScroll = true;
		if(args.contains('--middlescroll')) ClientPrefs.data.middleScroll = true;
		var prefsLine:String = ('prefs vsync ${ClientPrefs.data.vsync} unlocked ${ClientPrefs.data.unlockedFramerate} framerate ${ClientPrefs.data.framerate} resolution ${ClientPrefs.data.resolution} stream ${ClientPrefs.data.streamSongs} modMode ${FlxG.save.data.modMode} mod ${Mods.currentModDirectory} fixedTimestep ${FlxG.fixedTimestep} maxElapsed ${FlxG.maxElapsed}');
		if(args.contains('--vsync')) ClientPrefs.data.vsync = true;
		if(args.contains('--novsync')) ClientPrefs.data.vsync = false;
		if(args.contains('--noscreenshots')) ClientPrefs.data.allowScreenshots = false;
		applyContentFlags(args);
		if(args.contains('--unlocked')) ClientPrefs.data.unlockedFramerate = true;
		if(args.contains('--fps')) ClientPrefs.data.framerate = Std.parseInt(args[args.indexOf('--fps') + 1]);
		if(args.contains('--res')) ClientPrefs.data.resolution = args[args.indexOf('--res') + 1];
		funkin.backend.DisplaySettings.apply();
		if(args.contains('--noopponent')) ClientPrefs.data.opponentStrums = false;
		if(args.contains('--gpu')) ClientPrefs.data.cacheOnGPU = true;
		if(args.contains('--nogpu')) ClientPrefs.data.cacheOnGPU = false;
		if(args.contains('--level')) Paths.setCurrentLevel(args[args.indexOf('--level') + 1]);
		if(args.contains('--nocutscene')) PlayState.seenCutscene = true;
		if(args.contains('--cutscene'))
		{
			funkin.game.cutscenes.TwoPicos.forcePlayerShoots = args[args.indexOf('--cutscene') + 1] == '1';
			funkin.game.cutscenes.TwoPicos.forceExplode = args[args.indexOf('--cutscene') + 2] == '1';
		}
		MemoryTestNative.installCrashLog();
		output = File.write('memtest.log', false);
		log('song $song difficulty $difficulty mod ${Mods.currentModDirectory} cacheOnGPU ${ClientPrefs.data.cacheOnGPU}');
		log(prefsLine + ' naughtyness ${ClientPrefs.data.naughtyness} subtitles ${ClientPrefs.data.subtitles} downscroll ${ClientPrefs.data.downScroll}');

		var before:Float = MemoryUtils.getGCMemory() / 1048576;
		cpp.vm.Gc.run(true);
		cpp.vm.Gc.compact();
		log('boot gc before collect ${fmt(before)} after ${fmt(MemoryUtils.getGCMemory() / 1048576)}');
		dumpAssets();
		ClientPrefs.data.gameplaySettings.set('botplay', true);
		if(args.contains('--inputtest'))
		{
			inputTest = true;
			ClientPrefs.data.inputSystem = args[args.indexOf('--inputtest') + 1];
			ClientPrefs.data.ghostTapping = !args.contains('--noghost');
			ClientPrefs.data.safeFrames = 10;
			ClientPrefs.data.gameplaySettings.set('botplay', false);
			log('inputtest system ${funkin.game.InputSystem.current} ghostTapping pref ${ClientPrefs.data.ghostTapping} effective ${funkin.game.InputSystem.ghostTapping()} safeFrames ${funkin.game.InputSystem.safeFrames()} window ${fmt(funkin.game.InputSystem.hitWindowMs())}ms sustainsAsOne ${funkin.game.InputSystem.sustainsAsOneNote()}');
		}
		ClientPrefs.data.autoPause = false;
		FlxG.autoPause = false;
		Difficulty.list = Difficulty.defaultList.copy();
		var diffIndex:Int = Difficulty.list.indexOf(difficulty);
		if(diffIndex < 0)
		{
			Difficulty.list.push(difficulty);
			diffIndex = Difficulty.list.length - 1;
		}

		if(args.contains('--uncapped'))
		{
			FlxG.updateFramerate = 1000;
			FlxG.drawFramerate = 1000;
		}
		songList = song.split(',');
		difficultyIndex = diffIndex;
		var sampleStart:Float = haxe.Timer.stamp();
		sys.thread.Thread.create(function()
		{
			var windowMax:Float = 0;
			var windowStart:Float = haxe.Timer.stamp();
			var lastPhase:String = null;
			while (true)
			{
				if (phase != lastPhase)
				{
					lastPhase = phase;
					spikes.add('phase $phase at ${Math.round((haxe.Timer.stamp() - sampleStart) * 100) / 100}s');
				}
				var ws:Float = MemoryTestNative.workingSet() / 1048576;
				if (ws > windowMax) windowMax = ws;
				var now:Float = haxe.Timer.stamp();
				if (now - windowStart >= 0.1)
				{
					if (windowMax >= 380) spikes.add('spike ${Math.round((now - sampleStart) * 10) / 10}s ${fmt(windowMax)}MB during $phase ${Type.getClassName(Type.getClass(FlxG.state))}');
					windowMax = 0;
					windowStart = now;
				}
				Sys.sleep(0.002);
			}
		});
		FlxG.signals.preUpdate.add(() -> updateStart = haxe.Timer.stamp());
		FlxG.signals.postUpdate.add(() -> lastUpdateMs = (haxe.Timer.stamp() - updateStart) * 1000);
		FlxG.signals.preDraw.add(() -> drawStart = haxe.Timer.stamp());
		FlxG.signals.postDraw.add(() -> lastDrawMs = (haxe.Timer.stamp() - drawStart) * 1000);
		FlxG.signals.postUpdate.add(tick);
		lime.app.Application.current.window.onRender.add(_ -> renderStart = haxe.Timer.stamp(), false, 1000);
		lime.app.Application.current.window.onRender.add(_ -> lastRenderMs = (haxe.Timer.stamp() - renderStart) * 1000, false, -999);
		lime.app.Application.current.window.onRender.add(onRender, false, -1000);
		if(args.contains('--actions')) actions = args[args.indexOf('--actions') + 1].split(',');
		viaFreeplay = args.contains('--viafreeplay');
		if(viaFreeplay) openFreeplay();
		else loadSong(songList[0]);
		return true;
	}

	static var litSteps:Array<{dark:funkin.game.Character, lit:funkin.game.Character, group:flixel.group.FlxSpriteGroup, anim:String, showLit:Bool, tag:String}> = null;
	static var litTick:Int = 0;
	static inline final LIT_ZOOM:Float = 0.5;

	@:access(funkin.game.stages.erect.SpookyMansionErect)
	static function litCheck(game:PlayState)
	{
		if(litSteps == null)
		{
			litSteps = [];
			var stage:funkin.game.stages.erect.SpookyMansionErect = null;
			for (s in game.stages)
				if(Std.isOfType(s, funkin.game.stages.erect.SpookyMansionErect))
					stage = cast s;
			if(stage == null)
			{
				log('litcheck: stage not found');
				output.close();
				Sys.exit(0);
			}
			if(FlxG.sound.music != null) FlxG.sound.music.pause();
			game.vocals.pause();
			game.opponentVocals.pause();
			for (pair in [
				{tag: 'bf', dark: game.boyfriend, lit: stage.boyfriendLit, group: game.boyfriendGroup},
				{tag: 'gf', dark: game.gf, lit: stage.gfLit, group: game.gfGroup},
				{tag: 'dad', dark: game.dad, lit: stage.dadLit, group: game.dadGroup}])
			{
				if(pair.dark == null || pair.lit == null) continue;
				log('litcheck ${pair.tag} dark ${pair.dark.curCharacter} lit ${pair.lit.curCharacter} pos ${pair.dark.x},${pair.dark.y}');
				var names:Array<String> = [for (name in pair.dark.animOffsets.keys()) if(pair.lit.animOffsets.exists(name)) name];
				names.sort((a, b) -> a < b ? -1 : 1);
				for (name in names)
					for (showLit in [false, true])
						litSteps.push({dark: pair.dark, lit: pair.lit, group: pair.group, anim: name, showLit: showLit, tag: pair.tag});
			}
			log('litcheck steps ${litSteps.length}');
		}

		if(litSteps.length < 1)
		{
			if(shotPending != null) return;
			output.close();
			Sys.exit(0);
		}

		var step = litSteps[0];
		for (member in game.members)
			if(member != null) member.visible = false;
		step.group.visible = true;
		for (member in step.group.members)
			if(member != null) member.visible = false;
		game.camHUD.visible = false;
		for (cam in FlxG.cameras.list) if(cam != FlxG.camera) cam.visible = false;
		FlxG.camera.filters = null;
		FlxG.camera.bgColor = 0xFFFF00FF;

		for (char in [step.dark, step.lit])
		{
			if(char.getAnimationName() != step.anim || litTick == 0) char.playAnim(step.anim, true, false, 0);
			if(char.animation.curAnim != null)
			{
				char.animation.curAnim.curFrame = 0;
				char.animation.curAnim.pause();
			}
			char.alpha = 1;
		}
		step.lit.setPosition(step.dark.x, step.dark.y);
		var shown:funkin.game.Character = step.showLit ? step.lit : step.dark;
		shown.visible = true;

		var mid = step.dark.getGraphicMidpoint();
		FlxG.camera.target = null;
		FlxG.camera.zoom = LIT_ZOOM;
		FlxG.camera.angle = 0;
		FlxG.camera.scroll.set(step.dark.x + 300 - FlxG.width / 2, step.dark.y + 350 - FlxG.height / 2);
		mid.put();

		litTick++;
		if(litTick == 3)
		{
			var name:String = '${step.tag}_${step.anim}_${step.showLit ? "lit" : "dark"}';
			log('litshot $name offset ${shown.offset.x},${shown.offset.y} pos ${shown.x},${shown.y} frame ${shown.frameWidth}x${shown.frameHeight} scroll ${FlxG.camera.scroll.x},${FlxG.camera.scroll.y} zoom ${FlxG.camera.zoom}');
			shotPending = name;
		}
		if(litTick >= 4 && shotPending == null)
		{
			litSteps.shift();
			litTick = 0;
		}
	}

	static var neneSteps:Array<String> = null;
	static var neneProbe:animate.FlxAnimate = null;
	static var neneProbePixel:FlxSprite = null;

	static function worldLeft(spr:FlxSprite):Float
		return spr.x - spr.offset.x + spr.origin.x * (1 - spr.scale.x);

	static function worldTop(spr:FlxSprite):Float
		return spr.y - spr.offset.y + spr.origin.y * (1 - spr.scale.y);

	@:access(funkin.Paths)
	static function neneCheck(game:PlayState)
	{
		var stage = funkin.game.stages.PicoCapableStage.instance;
		var abot:funkin.game.stages.objects.ABotSpeaker = (stage != null) ? stage.abot : null;
		var abotPixel:funkin.game.stages.objects.ABotPixel = (stage != null) ? stage.abotPixel : null;
		if(abot == null && abotPixel == null)
			for (s in game.stages)
			{
				var found:Dynamic = Reflect.getProperty(s, 'abot');
				if(Std.isOfType(found, funkin.game.stages.objects.ABotSpeaker)) abot = cast found;
			}
		var gf = game.gf;
		var neneAnim:String = args().contains('--neneanim') ? args()[args().indexOf('--neneanim') + 1] : (gf.hasAnimation('danceLeft') ? 'danceLeft' : 'idle');
		var probeOffset:Array<Float> = (gf.curCharacter == 'otis-speaker') ? [170, 455] : [-95, 384];
		if(neneSteps == null)
		{
			neneSteps = ['nene', 'abot', 'probe', 'full'];
			if(FlxG.sound.music != null) FlxG.sound.music.pause();
			game.vocals.pause();
			game.opponentVocals.pause();
			if(abotPixel != null)
			{
				neneProbePixel = new FlxSprite();
				neneProbePixel.frames = Paths.getSparrowAtlas('abot/pixel/aBotPixelBody');
				neneProbePixel.animation.addByPrefix('danceLeft', 'danceLeft', 24, false);
				neneProbePixel.animation.play('danceLeft', true);
				neneProbePixel.animation.curAnim.pause();
				neneProbePixel.scale.set(6, 6);
				neneProbePixel.antialiasing = false;
				neneProbePixel.scrollFactor.set(gf.scrollFactor.x, gf.scrollFactor.y);
				game.add(neneProbePixel);
			}
			else
			{
				var folder:String = (PlayState.SONG.gfVersion == 'nene-dark') ? 'abot/dark/abotSystem' : 'abot/abotSystem';
				neneProbe = new animate.FlxAnimate();
				neneProbe.frames = Paths.loadModernAtlas(folder, Paths.getTextFromFile('images/$folder/Animation.json'));
				neneProbe.antialiasing = ClientPrefs.data.antialiasing;
				game.add(neneProbe);
			}
			log('nenecheck gf ${gf.curCharacter} anim $neneAnim gf ${gf.x},${gf.y} offset ${gf.offset.x},${gf.offset.y} gfGroup ${game.gfGroup.x},${game.gfGroup.y} sf ${gf.scrollFactor.x},${gf.scrollFactor.y}');
		}
		if(neneSteps.length < 1)
		{
			if(shotPending != null) return;
			output.close();
			Sys.exit(0);
		}

		var step:String = neneSteps[0];
		for (member in game.members)
			if(member != null) member.visible = false;
		game.camHUD.visible = false;
		for (cam in FlxG.cameras.list) if(cam != FlxG.camera) cam.visible = false;
		FlxG.camera.filters = null;
		FlxG.camera.bgColor = 0xFFFF00FF;

		gf.playAnim(neneAnim, true, false, 0);
		if(gf.animation.curAnim != null) gf.animation.curAnim.pause();
		if(abotPixel != null)
		{
			abotPixel.speaker.animation.play(abotPixel.speaker.animation.getNameList().contains('danceLeft') ? 'danceLeft' : 'anim', true);
			abotPixel.speaker.animation.curAnim.pause();
			neneProbePixel.setPosition(worldLeft(gf) + 296, worldTop(gf) + 430);
		}
		else
		{
			abot.speaker.anim.curFrame = 0;
			abot.speaker.anim.pause();
			neneProbe.setPosition(gf.x - gf.offset.x + probeOffset[0], gf.y - gf.offset.y + probeOffset[1]);
		}

		var abotGroup:FlxSpriteGroup = (abotPixel != null) ? abotPixel : abot;
		var abotBody:FlxSprite = (abotPixel != null) ? abotPixel.speaker : abot.speaker;
		switch(step)
		{
			case 'nene':
				game.gfGroup.visible = true;
			case 'abot':
				abotGroup.visible = true;
				for (member in abotGroup.members) member.visible = (member == abotBody);
			case 'probe':
				if(neneProbePixel != null) neneProbePixel.visible = true;
				if(neneProbe != null) neneProbe.visible = true;
			case 'full':
				game.gfGroup.visible = true;
				abotGroup.visible = true;
				for (member in abotGroup.members) member.visible = true;
		}

		FlxG.camera.target = null;
		FlxG.camera.zoom = LIT_ZOOM;
		FlxG.camera.angle = 0;
		FlxG.camera.scroll.set(gf.x + 300 - FlxG.width / 2, gf.y + 450 - FlxG.height / 2);

		litTick++;
		if(litTick == 3)
		{
			log('neneshot $step gfWorld ${worldLeft(gf)},${worldTop(gf)} body ${worldLeft(abotBody)},${worldTop(abotBody)} scroll ${FlxG.camera.scroll.x},${FlxG.camera.scroll.y} zoom ${FlxG.camera.zoom} gfsf ${gf.scrollFactor.x} bodysf ${abotBody.scrollFactor.x}');
			shotPending = 'nene_$step';
		}
		if(litTick >= 4 && shotPending == null)
		{
			neneSteps.shift();
			litTick = 0;
		}
	}

	static var gameOverStart:Float = -1;
	static var gameOverShots:Array<Float> = [0.5, 1.0, 2.0];
	static var gameOverSnapped:Bool = false;
	static var gameOverSettledShot:Bool = false;

	@:access(funkin.game.states.GameOverSubstate)
	static function gameOverTick(sub:funkin.game.states.GameOverSubstate)
	{
		var now:Float = haxe.Timer.stamp();
		if(gameOverStart < 0)
		{
			gameOverStart = now;
			var bf = sub.boyfriend;
			var player = PlayState.instance.boyfriend;
			log('gameover char ${bf.curCharacter} pos ${bf.x},${bf.y} off ${bf.offset.x},${bf.offset.y} world ${worldLeft(bf)},${worldTop(bf)} fw ${bf.frameWidth}x${bf.frameHeight} player ${player.curCharacter} pos ${player.x},${player.y} w ${player.width} h ${player.height} off ${player.offset.x},${player.offset.y} idle ${player.animOffsets.get("idle")} gf ${PlayState.instance.gf != null ? PlayState.instance.gf.curCharacter : "none"} zoom ${FlxG.camera.zoom} default ${PlayState.instance.defaultCamZoom}');
		}
		var t:Float = now - gameOverStart;
		if(gameOverShots.length > 0 && t >= gameOverShots[0] && shotPending == null)
			shotPending = 'go_' + Std.string(gameOverShots.shift()).replace('.', '_');
		if(t >= 4 && !gameOverSnapped)
		{
			gameOverSnapped = true;
			FlxG.camera.snapToTarget();
			log('gameover follow ${sub.camFollow.x},${sub.camFollow.y} scroll ${FlxG.camera.scroll.x},${FlxG.camera.scroll.y} zoom ${FlxG.camera.zoom} anim ${sub.boyfriend.getAnimationName()}');
		}
		if(gameOverSnapped && !gameOverSettledShot && t >= 4.3 && shotPending == null)
		{
			gameOverSettledShot = true;
			shotPending = 'go_settled';
		}
		if(t > 5 && shotPending == null)
		{
			output.close();
			Sys.exit(0);
		}
	}

	static var charLast:String = null;
	static var charGame:PlayState = null;
	static var charSeen:Float = 0;
	static var charShots:Array<Float> = [0.3, 1.0, 1.4, 2.2];

	static function charLog(game:PlayState)
	{
		var dad = game.dad;
		var bf = game.boyfriend;
		if(charGame != game)
		{
			charGame = game;
			charSeen = haxe.Timer.stamp();
		}
		var gf = game.gf;
		var sub:String = FlxG.state.subState != null ? Type.getClassName(Type.getClass(FlxG.state.subState)) : 'none';
		var state:String = 'dad ${dad.curCharacter} ${dad.getAnimationName()} lock ${!dad.canPlayOtherAnims} suffix ${dad.animSuffix} special ${dad.specialAnim} | bf ${bf.getAnimationName()} lock ${!bf.canPlayOtherAnims} special ${bf.specialAnim} | gf ${gf != null ? gf.getAnimationName() : 'none'} special ${gf != null && gf.specialAnim} | cutscene ${game.inCutscene} video ${game.videoCutscene != null} sub $sub';
		var age:Float = haxe.Timer.stamp() - charSeen;
		if(charShots.length > 0 && age >= charShots[0] && shotPending == null) shotPending = 'age_' + Std.int(charShots.shift() * 10);
		if(state == charLast) return;
		charLast = state;
		log('charlog ${fmt(Conductor.songPosition / 1000)}s age ${fmt(haxe.Timer.stamp() - charSeen)} $state');
	}

	static var endSteps:Array<String> = null;
	static var endProbe:animate.FlxAnimate = null;
	static var endOld:FlxAnimate = null;

	@:access(funkin.game.stages.erect.TankErect)
	@:access(funkin.game.cutscenes.PicoTankman)
	static function endCheck(game:PlayState)
	{
		var dad = game.dad;
		if(endSteps == null)
		{
			endSteps = ['old', 'new', 'dad'];
			if(FlxG.sound.music != null) FlxG.sound.music.pause();
			game.vocals.pause();
			game.opponentVocals.pause();
			var tank:funkin.game.stages.erect.TankErect = null;
			for (st in game.stages) if(Std.isOfType(st, funkin.game.stages.erect.TankErect)) tank = cast st;
			tank.cutscene.placeEnding();
			endOld = tank.cutscene.tankmanEnding;
			endOld.anim.play('ending', true);
			endOld.anim.pause();
			game.add(endOld);
			endProbe = new animate.FlxAnimate();
			endProbe.frames = Paths.getAnimateAtlasFrames('erect/cutscene/tankmanEnding');
			funkin.util.AtlasUtil.ModernAtlasUtil.addAnimation(endProbe, 'ending', 'tankman stress ending', null, 24, false);
			endProbe.anim.play('ending', true);
			endProbe.anim.pause();
			var idle:Array<Dynamic> = dad.animOffsets.get('idle');
			endProbe.setPosition(dad.x - idle[0] + funkin.game.cutscenes.PicoTankman.ENDING_OFFSET_X, dad.y - idle[1] + funkin.game.cutscenes.PicoTankman.ENDING_OFFSET_Y);
			game.add(endProbe);
			log('endcheck dad ${dad.curCharacter} ${dad.x},${dad.y} idle $idle old ${endOld.x},${endOld.y} probe ${endProbe.x},${endProbe.y}');
		}
		if(endSteps.length < 1)
		{
			if(shotPending != null) return;
			output.close();
			Sys.exit(0);
		}
		var step:String = endSteps[0];
		for (member in game.members) if(member != null) member.visible = false;
		game.camHUD.visible = false;
		for (cam in FlxG.cameras.list) if(cam != FlxG.camera) cam.visible = false;
		FlxG.camera.filters = null;
		FlxG.camera.bgColor = 0xFFFF00FF;
		endOld.shader = null;
		dad.shader = null;
		dad.playAnim('idle', true, false, 0);
		switch(step)
		{
			case 'old': endOld.visible = true;
			case 'new': endProbe.visible = true;
			case 'dad': game.dadGroup.visible = true;
		}
		FlxG.camera.target = null;
		FlxG.camera.zoom = LIT_ZOOM;
		FlxG.camera.angle = 0;
		FlxG.camera.scroll.set(dad.x + 300 - FlxG.width / 2, dad.y + 300 - FlxG.height / 2);
		litTick++;
		if(litTick == 3) shotPending = 'end_$step';
		if(litTick >= 4 && shotPending == null)
		{
			endSteps.shift();
			litTick = 0;
		}
	}

	static var animSteps:Array<{frame:Int, shader:Bool}> = null;
	static var animShader:flixel.system.FlxAssets.FlxShader = null;

	static function animShots(game:PlayState)
	{
		var a:Array<String> = args();
		var i:Int = a.indexOf('--animshots');
		var who:String = a[i + 1];
		var animName:String = a[i + 2];
		var char:funkin.game.Character = (who == 'bf') ? game.boyfriend : (who == 'gf' ? game.gf : game.dad);
		var group:FlxSpriteGroup = (who == 'bf') ? game.boyfriendGroup : (who == 'gf' ? game.gfGroup : game.dadGroup);
		if(animSteps == null)
		{
			animSteps = [];
			for (f in a[i + 3].split(','))
				for (sh in [true, false]) animSteps.push({frame: Std.parseInt(f), shader: sh});
			if(FlxG.sound.music != null) FlxG.sound.music.pause();
			game.vocals.pause();
			game.opponentVocals.pause();
			animShader = cast char.shader;
			log('animshots ${char.curCharacter} $animName shader ${animShader != null} pos ${char.x},${char.y}');
		}
		if(animSteps.length < 1)
		{
			if(shotPending != null) return;
			output.close();
			Sys.exit(0);
		}
		var step = animSteps[0];
		for (member in game.members) if(member != null) member.visible = false;
		game.camHUD.visible = false;
		for (cam in FlxG.cameras.list) if(cam != FlxG.camera) cam.visible = false;
		FlxG.camera.filters = null;
		FlxG.camera.bgColor = 0xFFFF00FF;
		group.visible = true;
		char.shader = step.shader ? animShader : null;
		char.canPlayOtherAnims = true;
		char.playAnim(animName, true, false, step.frame);
		char.animation.pause();
		FlxG.camera.target = null;
		FlxG.camera.zoom = 0.4;
		FlxG.camera.angle = 0;
		FlxG.camera.scroll.set(char.x + 200 - FlxG.width / 2, char.y + 300 - FlxG.height / 2);
		litTick++;
		if(litTick == 3)
		{
			log('animshot frame ${step.frame} shader ${step.shader} w ${char.width} h ${char.height} frameIndex ${char.animation.frameIndex}');
			shotPending = 'anim_${step.frame}_${step.shader ? "sh" : "nosh"}';
		}
		if(litTick >= 4 && shotPending == null)
		{
			animSteps.shift();
			litTick = 0;
		}
	}

	@:access(funkin.game.stages.erect.TankErect)
	@:access(funkin.game.cutscenes.PicoTankman)
	static function cutFrameLog(game:PlayState)
	{
		var bf = game.boyfriend;
		var tank:funkin.game.stages.erect.TankErect = null;
		for (st in game.stages) if(Std.isOfType(st, funkin.game.stages.erect.TankErect)) tank = cast st;
		var ending = (tank != null && tank.cutscene != null) ? tank.cutscene.tankmanEnding : null;
		log('cf ${fmt(haxe.Timer.stamp() - startTime)} pos ${Math.round(Conductor.songPosition)} bf ${bf.getAnimationName()}:${bf.animation.frameIndex} fin ${bf.isAnimationFinished()} bfw ${Math.round(bf.width)}x${Math.round(bf.height)} ending ${ending != null ? ending.anim.curFrame + "/" + ending.anim.length + " vis " + ending.visible : "none"} gf ${game.gf.getAnimationName()} music ${FlxG.sound.music != null && FlxG.sound.music.playing}');
	}

	static var compareSteps:Array<Array<Dynamic>> = [
		['philly/erect/cutscenes/pico_doppleganger', 'shootPlayer', 0, -585, -609, -205, -154], ['philly/erect/cutscenes/pico_doppleganger', 'shootPlayer', 60, -585, -609, -205, -154],
		['philly/erect/cutscenes/pico_doppleganger', 'shootOpponent', 0, -585, -609, -205, -154], ['philly/erect/cutscenes/pico_doppleganger', 'cigarettePlayer', 40, -585, -609, -205, -154],
		['philly/erect/cutscenes/pico_doppleganger', 'explodeOpponent', 40, -585, -609, -205, -154], ['philly/erect/cutscenes/pico_doppleganger', 'loopPlayer', 0, -585, -609, -205, -154],
		['philly/erect/cutscenes/bloodPool', 'poolAnim', 80, 1292, 610, 1000, 500]];
	static var compareOld:FlxAnimate = null;
	static var compareNew:animate.FlxAnimate = null;
	static var compareTick:Int = 0;
	static var compareShowNew:Bool = false;

	static function atlasCompareTick()
	{
		if(!Std.isOfType(FlxG.state, flixel.FlxState) || Std.isOfType(FlxG.state, funkin.ui.states.InitialState)) return;
		if(compareSteps.length < 1)
		{
			if(shotPending != null) return;
			output.close();
			Sys.exit(0);
		}

		var step = compareSteps[0];
		var folder:String = step[0];
		var label:String = step[1];
		var frame:Int = step[2];
		if(compareTick == 0)
		{
			if(compareOld != null) { FlxG.state.remove(compareOld); compareOld.destroy(); }
			if(compareNew != null) { FlxG.state.remove(compareNew); compareNew.destroy(); }
			compareOld = new FlxAnimate(300, 300);
			Paths.loadAnimateAtlas(compareOld, folder);
			funkin.util.AtlasUtil.addAnimation(compareOld, 'a', label, null, 24, false);
			compareOld.antialiasing = true;
			compareNew = new animate.FlxAnimate(300 + step[3], 300 + step[4]);
			compareNew.frames = Paths.getAnimateAtlasFrames(folder);
			compareNew.useRenderTexture = true;
			funkin.util.AtlasUtil.ModernAtlasUtil.addAnimation(compareNew, 'a', label, null, 24, false);
			compareNew.antialiasing = true;
			var colorShader = new funkin.graphics.shaders.AdjustColorShader();
			colorShader.hue = -26;
			colorShader.saturation = -16;
			colorShader.contrast = 0;
			colorShader.brightness = -5;
			compareOld.shader = colorShader;
			compareNew.shader = colorShader;
			FlxG.state.add(compareOld);
			FlxG.state.add(compareNew);
		}
		compareOld.anim.play('a', true, false, frame);
		compareOld.anim.pause();
		compareNew.anim.play('a', true, false, frame);
		compareNew.anim.pause();
		compareOld.visible = !compareShowNew;
		compareNew.visible = compareShowNew;
		FlxG.camera.bgColor = 0xFFFF00FF;
		FlxG.camera.zoom = 2.2;
		FlxG.camera.scroll.set(step[5] + 0.37, step[6] + 0.61);

		compareTick++;
		if(compareTick == 4)
		{
			var name:String = 'cmp_' + label + '_' + frame + (compareShowNew ? '_new' : '_old');
			log('compare $name');
			shotPending = name;
		}
		if(compareTick >= 5 && shotPending == null)
		{
			compareTick = 1;
			if(compareShowNew)
			{
				compareShowNew = false;
				compareTick = 0;
				compareSteps.shift();
			}
			else compareShowNew = true;
		}
	}

	static var litLast:Map<String, String> = [];

	@:access(funkin.game.stages.erect.SpookyMansionErect)
	static var neneLast:String = null;

	@:access(funkin.game.stages.PicoCapableStage)
	static function neneLog(game:PlayState)
	{
		var stage = funkin.game.stages.PicoCapableStage.instance;
		var gf = game.gf;
		var state:String = '${gf.getAnimationName()} state ${stage != null ? Std.string(stage.currentNeneState) : "-"} train ${stage != null && stage.trainPassing} skipDance ${gf.skipDance} special ${gf.specialAnim}' + ((stage != null && stage.abotPixel != null && stage.abotPixel.speaker.animation.curAnim != null) ? ' body ${stage.abotPixel.speaker.animation.curAnim.name}:${stage.abotPixel.speaker.animation.curAnim.curFrame < 3 ? "start" : "run"} gfframe ${gf.animation.curAnim != null && gf.animation.curAnim.curFrame < 3 ? "start" : "run"}' : '');
		if(state == neneLast) return;
		neneLast = state;
		log('nenelog ${fmt(Conductor.songPosition / 1000)}s $state');
	}

	static var litCalls:Int = 0;
	static var litHooked:Bool = false;

	static function litLog(game:PlayState)
	{
		litCalls++;
		if(litCalls % 60 == 0) log('litlog heartbeat $litCalls pos ${Math.round(Conductor.songPosition)}');
		try litLogInner(game) catch(e:Dynamic) log('litlog EXCEPTION $e ' + haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
	}

	@:access(funkin.game.stages.erect.SpookyMansionErect)
	static function litLogInner(game:PlayState)
	{
		var stage:funkin.game.stages.erect.SpookyMansionErect = null;
		for (s in game.stages)
			if(Std.isOfType(s, funkin.game.stages.erect.SpookyMansionErect)) stage = cast s;
		if(stage == null) return;

		for (pair in [{tag: 'bf', dark: game.boyfriend, lit: stage.boyfriendLit}, {tag: 'gf', dark: game.gf, lit: stage.gfLit}, {tag: 'dad', dark: game.dad, lit: stage.dadLit}])
		{
			var tag:String = pair.tag;
			var dark:funkin.game.Character = pair.dark;
			var lit:funkin.game.Character = pair.lit;
			if(dark == null || lit == null) continue;

			var state:String = '';
			var litShown:Bool = lit.alpha > 0 && lit.visible;
			var darkFrame:Int = dark.animation.curAnim != null ? dark.animation.curAnim.curFrame : -1;
			var litFrame:Int = lit.animation.curAnim != null ? lit.animation.curAnim.curFrame : -1;
			if(litShown && dark.alpha >= 1) state = 'LIT SHOWN UNDER OPAQUE DARK';
			else if(!litShown && dark.alpha < 1) state = 'DARK TRANSPARENT BUT LIT HIDDEN';
			else if(litShown)
			{
				if(dark.getAnimationName() != lit.getAnimationName()) state = 'ANIM ' + dark.getAnimationName() + ' vs ' + lit.getAnimationName();
				else if(darkFrame != litFrame) state = 'FRAME ' + dark.getAnimationName() + ' ' + darkFrame + ' vs ' + litFrame;
				else if(dark.x != lit.x || dark.y != lit.y) state = 'POS ' + dark.x + ',' + dark.y + ' vs ' + lit.x + ',' + lit.y;
				else state = 'ok';
			}
			if(litLast.get(tag) == state) continue;
			litLast.set(tag, state);
			log('litlog ${fmt(Conductor.songPosition / 1000)}s $tag darkAlpha ${fmt(dark.alpha)} litAlpha ${fmt(lit.alpha)} $state');
		}
	}

	static var cutsceneStart:Float = -1;
	static var cutsceneLastLog:Float = -1;
	static var cutsceneShots:Array<Float> = [1, 3, 5, 7, 9, 11.5];

	@:access(funkin.game.stages.erect.PhillyTrainErect)
	@:access(funkin.game.cutscenes.TwoPicos)
	static function cutsceneLog(game:PlayState)
	{
		var now:Float = haxe.Timer.stamp();
		if(cutsceneStart < 0)
		{
			cutsceneStart = now;
			log('cutscene forced playerShoots ${funkin.game.cutscenes.TwoPicos.forcePlayerShoots} explode ${funkin.game.cutscenes.TwoPicos.forceExplode}');
			for (c in [game.dad, game.boyfriend])
			{
				var mid = c.getMidpoint();
				log('camchar ${c.curCharacter} x ${c.x} y ${c.y} w ${c.width} h ${c.height} fw ${c.frameWidth} fh ${c.frameHeight} off ${c.offset.x},${c.offset.y} mid ${mid.x},${mid.y} campos ${c.cameraPosition} anim ${c.getAnimationName()} bfoff ${game.boyfriendCameraOffset} opoff ${game.opponentCameraOffset}');
			}
		}
		var t:Float = now - cutsceneStart;

		if(t - cutsceneLastLog >= 0.5)
		{
			cutsceneLastLog = t;
			var music = FlxG.sound.music;
			var abot = funkin.game.stages.PicoCapableStage.instance != null ? funkin.game.stages.PicoCapableStage.instance.abot : null;
			var cutscene:funkin.game.cutscenes.TwoPicos = null;
			for (s in game.stages)
				if(Std.isOfType(s, funkin.game.stages.erect.PhillyTrainErect)) cutscene = cast(s, funkin.game.stages.erect.PhillyTrainErect).cutsceneObj;
			var info:String = (cutscene != null && cutscene.cutsceneHandler != null) ? ' track ${cutscene.cutsceneHandler.music} playerShoots ${cutscene.playerShoots} explode ${cutscene.explode}' : '';
			log('cutscene ${fmt(t)}s music ${music != null && music.playing} ${music != null ? Math.round(music.time) : -1} gf ${game.gf.getAnimationName()}:${game.gf.animation.curAnim != null ? game.gf.animation.curAnim.curFrame : -1} abot ${abot != null ? abot.speaker.anim.curFrame : -1} scroll ${Math.round(FlxG.camera.scroll.x)},${Math.round(FlxG.camera.scroll.y)} follow ${Math.round(game.camFollow.x)},${Math.round(game.camFollow.y)} zoom ${fmt(FlxG.camera.zoom)} countdown ${game.startedCountdown}$info');
		}
		if(cutsceneShots.length > 0 && t >= cutsceneShots[0] && shotPending == null)
			shotPending = 'cut_' + Std.string(cutsceneShots.shift()).replace('.', '_');
		if(t > 16 && shotPending == null)
		{
			output.close();
			Sys.exit(0);
		}
	}

	static var scrollInterval:Float = 0.15;
	static var scrollMode:String = 'sel';
	static var nextScroll:Float = 0;
	static var lastFrame:Float = 0;
	static var scrollCount:Int = 0;

	static function logWindow(tag:String)
	{
		var w = lime.app.Application.current.window;
		var b = w.display.bounds;
		log('$tag mode ${ClientPrefs.data.resolution} window ${w.x},${w.y} ${w.width}x${w.height} fullscreen ${FlxG.fullscreen} borderless ${w.borderless} minimized ${w.minimized} display ${b.x},${b.y} ${b.width}x${b.height} vsync ${funkin.backend.DisplaySettings.applyVSync()}');
	}

	static function startResCycle()
	{
		var setRes = (mode:String) -> () -> {
			ClientPrefs.data.resolution = mode;
			funkin.backend.DisplaySettings.applyResolution();
			return 'set $mode';
		};
		var altEnter = () -> {
			var mod:lime.ui.KeyModifier = lime.ui.KeyModifier.LEFT_ALT;
			lime.app.Application.current.window.onKeyDown.dispatch(lime.ui.KeyCode.RETURN, mod);
			return 'alt+enter';
		};
		var f11 = () -> { funkin.backend.DisplaySettings.toggleFullscreen(); return 'f11'; };
		var check = (tag:String) -> () -> { logWindow(tag); return 'logged $tag'; };
		var minimize = () -> { lime.app.Application.current.window.minimized = true; return 'minimize'; };
		if(Sys.args().contains('--alttab'))
		{
			optionSteps = [check('start'), setRes('Fullscreen'), check('fullscreen'), minimize, check('restored'),
				setRes('Windowed'), check('windowed after alttab'),
				setRes('Fullscreen'), minimize, check('fullscreen again'), f11, check('f11 after alttab'),
				setRes('Fullscreen'), minimize, check('fullscreen third'), altEnter, check('altenter after alttab'),
				setRes('Borderless'), minimize, check('borderless alttab'), setRes('Windowed'), check('windowed from borderless')];
			optionSteps.push(() -> { output.close(); Sys.exit(0); return 'exit'; });
			optionNext = haxe.Timer.stamp() + 1.5;
			FlxG.signals.postUpdate.add(optionsTick);
			return;
		}
		optionSteps = [check('start'), setRes('Borderless'), check('borderless'), setRes('Fullscreen'), check('fullscreen'),
			f11, check('f11 from fullscreen'), altEnter, check('altenter'), altEnter, check('altenter back'),
			setRes('Windowed'), check('windowed'), f11, check('f11 from windowed'), f11, check('f11 back')];
		optionSteps.push(() -> { output.close(); Sys.exit(0); return 'exit'; });
		optionNext = haxe.Timer.stamp() + 1.5;
		FlxG.signals.postUpdate.add(optionsTick);
	}

	static var optionSteps:Array<Void->String> = [];
	static var optionNext:Float = 0;

	static function topSub():flixel.FlxState
	{
		var st:flixel.FlxState = FlxG.state;
		while(st.subState != null) st = st.subState;
		return st;
	}

	@:access(funkin.ui.options.BaseOptionsMenu)
	static function logMenu(tag:String)
	{
		var menu:funkin.ui.options.BaseOptionsMenu = Std.downcast(topSub(), funkin.ui.options.BaseOptionsMenu);
		if(menu == null)
		{
			log('$tag top ${Type.getClassName(Type.getClass(topSub()))}');
			return;
		}
		log('$tag menu ${menu.title}');
		for(o in menu.optionsArray) log('$tag   ${o.name} | ${o.type} | ${o.variable} = ${o.getValue()}');
	}

	@:access(funkin.ui.options.BaseOptionsMenu)
	static function pressOption(name:String):String
	{
		var menu:funkin.ui.options.BaseOptionsMenu = Std.downcast(topSub(), funkin.ui.options.BaseOptionsMenu);
		for(o in menu.optionsArray) if(o.name == name)
		{
			o.change();
			return 'pressed $name';
		}
		return 'NOT FOUND $name';
	}

	@:access(funkin.ui.options.OptionsState)
	static function startOptionsMenu()
	{
		var cats:Array<String> = ['Preferences', 'Notes', 'Controls', 'Graphics', 'Gameplay', 'Debug'];
		optionSteps.push(() -> { FlxG.switchState(new funkin.ui.options.OptionsState()); return 'open options'; });
		optionSteps.push(() -> { shotPending = 'opt_main'; return 'shot main'; });
		for(cat in cats)
		{
			optionSteps.push(() -> { cast(FlxG.state, funkin.ui.options.OptionsState).openSelectedSubstate(cat); return 'open $cat'; });
			optionSteps.push(() -> { logMenu(cat); shotPending = 'opt_$cat'; return 'shot $cat'; });
			if(cat == 'Preferences')
			{
				optionSteps.push(() -> pressOption('Language'));
				optionSteps.push(() -> { logMenu('Language'); shotPending = 'opt_Language'; return 'shot language'; });
				optionSteps.push(() -> { cast(topSub(), flixel.FlxSubState).close(); return 'close language'; });
				optionSteps.push(() -> { logMenu('backToPrefs'); shotPending = 'opt_Preferences_back'; return 'shot prefs back'; });
			}
			if(cat == 'Notes')
			{
				optionSteps.push(() -> pressOption('Open Note Color Editor'));
				optionSteps.push(() -> { logMenu('NoteColors'); shotPending = 'opt_NoteColors'; return 'shot note colors'; });
				optionSteps.push(() -> { cast(topSub(), flixel.FlxSubState).close(); return 'close note colors'; });
			}
			optionSteps.push(() -> { cast(topSub(), flixel.FlxSubState).close(); return 'close $cat'; });
		}
		optionSteps.push(() -> { FlxG.state.openSubState(new funkin.ui.options.CustomSettingsSubState()); return 'open custom'; });
		optionSteps.push(() -> { logMenu('Custom'); shotPending = 'opt_Custom'; return 'shot custom'; });
		optionSteps.push(() -> {
			for(v in ['exampleBool', 'exampleInt', 'exampleFloat', 'examplePercent', 'exampleString', 'exampleKeybind'])
				log('custom default $v = ${funkin.ui.options.CustomSettingsSubState.get(v)}');
			var menu:funkin.ui.options.BaseOptionsMenu = Std.downcast(topSub(), funkin.ui.options.BaseOptionsMenu);
			@:privateAccess for(o in menu.optionsArray) switch(o.type)
			{
				case BOOL: o.setValue(true);
				case INT: o.setValue(7);
				case FLOAT: o.setValue(2.3);
				case PERCENT: o.setValue(0.8);
				case STRING: o.setValue('Third');
				case KEYBIND: o.setValue('G');
				default:
			}
			return 'custom set';
		});
		optionSteps.push(() -> {
			for(v in ['exampleBool', 'exampleInt', 'exampleFloat', 'examplePercent', 'exampleString', 'exampleKeybind'])
				log('custom get $v = ${funkin.ui.options.CustomSettingsSubState.get(v)}');
			return 'custom values';
		});
		optionSteps.push(() -> { cast(topSub(), flixel.FlxSubState).close(); return 'close custom'; });
		optionSteps.push(() -> {
			for(v in ['exampleBool', 'exampleInt', 'exampleFloat', 'examplePercent', 'exampleString', 'exampleKeybind'])
				Reflect.deleteField(FlxG.save.data, 'customSettings_' + v);
			FlxG.save.flush();
			return 'custom cleaned ${funkin.ui.options.CustomSettingsSubState.get("exampleBool")}';
		});
		optionSteps.push(() -> { output.close(); Sys.exit(0); return 'exit'; });
		optionNext = haxe.Timer.stamp() + 1.5;
		FlxG.signals.postUpdate.add(optionsTick);
	}

	static function menuKey(key:flixel.input.keyboard.FlxKey)
	{
		FlxG.stage.dispatchEvent(new openfl.events.KeyboardEvent(openfl.events.KeyboardEvent.KEY_DOWN, true, false, 0, key));
		haxe.Timer.delay(() -> FlxG.stage.dispatchEvent(new openfl.events.KeyboardEvent(openfl.events.KeyboardEvent.KEY_UP, true, false, 0, key)), 100);
	}

	@:access(funkin.ui.options.BaseOptionsMenu)
	static function selectOption(name:String):String
	{
		var menu:funkin.ui.options.BaseOptionsMenu = Std.downcast(topSub(), funkin.ui.options.BaseOptionsMenu);
		for (i => o in menu.optionsArray) if(o.name == name)
		{
			menu.changeSelection(i - menu.curSelected);
			return 'selected $name';
		}
		return 'NOT FOUND $name';
	}

	@:access(funkin.ui.options.BaseOptionsMenu)
	static function logInputMenu(tag:String)
	{
		var menu:funkin.ui.options.BaseOptionsMenu = Std.downcast(topSub(), funkin.ui.options.BaseOptionsMenu);
		for (i => o in menu.optionsArray)
			log('$tag ${o.name} = ${o.getValue()} locked ${o.isLocked()} alpha ${Math.round(menu.grpOptions.members[i].alpha * 100) / 100}${o.name == "Safe Frames" ? " max " + o.maxValue : ""}');
		log('$tag stored ghostTapping ${ClientPrefs.data.ghostTapping} safeFrames ${ClientPrefs.data.safeFrames} inputSystem ${ClientPrefs.data.inputSystem} desc "${menu.descText.text.split("\n").join(" / ")}"');
	}

	@:access(funkin.ui.options.OptionsState)
	static function startInputMenu()
	{
		var savedInput:String = ClientPrefs.data.inputSystem;
		var savedGhost:Bool = ClientPrefs.data.ghostTapping;
		var savedFrames:Float = ClientPrefs.data.safeFrames;
		optionSteps.push(() -> { ClientPrefs.data.inputSystem = 'Psych'; ClientPrefs.data.ghostTapping = true; ClientPrefs.data.safeFrames = 10; return 'reset prefs'; });
		optionSteps.push(() -> { FlxG.switchState(new funkin.ui.options.OptionsState()); return 'open options'; });
		optionSteps.push(() -> { cast(FlxG.state, funkin.ui.options.OptionsState).openSelectedSubstate('Gameplay'); return 'open gameplay'; });
		for (mode in funkin.game.InputSystem.LIST)
		{
			optionSteps.push(() -> selectOption('Input System'));
			optionSteps.push(() -> {
				if(ClientPrefs.data.inputSystem != mode) { menuKey(RIGHT); return 'press right (now ${ClientPrefs.data.inputSystem})'; }
				return 'on $mode';
			});
			optionSteps.push(() -> {
				if(ClientPrefs.data.inputSystem != mode) { menuKey(RIGHT); return 'press right again (now ${ClientPrefs.data.inputSystem})'; }
				return 'on $mode';
			});
			optionSteps.push(() -> {
				if(ClientPrefs.data.inputSystem != mode) { menuKey(RIGHT); return 'press right third (now ${ClientPrefs.data.inputSystem})'; }
				return 'on $mode';
			});
			optionSteps.push(() -> { logInputMenu('menu $mode'); shotPending = 'input_menu_${Paths.formatToSongPath(mode)}'; return 'shot $mode'; });
			optionSteps.push(() -> selectOption('Ghost Tapping'));
			optionSteps.push(() -> { menuKey(ENTER); return 'enter on ghost tapping'; });
			optionSteps.push(() -> { log('menu $mode after ENTER ghost shown ${funkin.game.InputSystem.ghostTapping()} stored ${ClientPrefs.data.ghostTapping}'); menuKey(ENTER); return 'enter again'; });
			optionSteps.push(() -> { log('menu $mode after 2x ENTER ghost shown ${funkin.game.InputSystem.ghostTapping()} stored ${ClientPrefs.data.ghostTapping}'); return 'logged ghost'; });
			optionSteps.push(() -> selectOption('Safe Frames'));
			optionSteps.push(() -> { menuKey(RIGHT); return 'right on safe frames'; });
			optionSteps.push(() -> { log('menu $mode after RIGHT safe frames shown ${funkin.game.InputSystem.safeFrames()} stored ${ClientPrefs.data.safeFrames}'); menuKey(LEFT); return 'left on safe frames'; });
			optionSteps.push(() -> { log('menu $mode after LEFT safe frames shown ${funkin.game.InputSystem.safeFrames()} stored ${ClientPrefs.data.safeFrames}'); shotPending = 'input_menu_${Paths.formatToSongPath(mode)}_frames'; return 'shot frames'; });
		}
		optionSteps.push(() -> {
			ClientPrefs.data.inputSystem = savedInput;
			ClientPrefs.data.ghostTapping = savedGhost;
			ClientPrefs.data.safeFrames = savedFrames;
			return 'restored prefs';
		});
		optionSteps.push(() -> { output.close(); Sys.exit(0); return 'exit'; });
		optionNext = haxe.Timer.stamp() + 1.5;
		FlxG.signals.postUpdate.add(optionsTick);
	}

	@:access(funkin.ui.options.OptionsState)
	static function startMouseCycle()
	{
		var chain = () -> {
			var names:Array<String> = [];
			var st:flixel.FlxState = FlxG.state;
			while(st != null) { var p = Type.getClassName(Type.getClass(st)); names.push(p.substr(p.lastIndexOf('.') + 1)); st = st.subState; }
			return names.join('>');
		};
		var show = () -> { FlxG.mouse.visible = true; return 'show'; };
		var check = (tag:String) -> () -> { log('mouse $tag hideMouse ${ClientPrefs.data.hideMouse} chain ${chain()} visible ${FlxG.mouse.visible} enabled ${FlxG.mouse.enabled} hidden ${funkin.backend.MouseVisibility.isHidden()} controllerMode ${Controls.instance.controllerMode}'); return 'checked $tag'; };
		var go = (make:Void->flixel.FlxState, name:String) -> () -> { FlxG.switchState(make()); return 'switch $name'; };
		optionSteps = [() -> { ClientPrefs.data.hideMouse = true; return 'hideMouse on'; }];
		optionSteps = optionSteps.concat([go(() -> new funkin.ui.states.MainMenuState(), 'main'), show, check('mainmenu')]);
		optionSteps = optionSteps.concat([go(() -> new funkin.ui.states.FreeplayState(), 'freeplay'), show, check('freeplay')]);
		optionSteps.push(() -> { funkin.backend.MouseVisibility.setScriptVisible(true); return 'script show'; });
		optionSteps.push(check('freeplay script'));
		optionSteps = optionSteps.concat([go(() -> new funkin.ui.states.StoryMenuState(), 'story'), show, check('story after script')]);
		optionSteps = optionSteps.concat([go(() -> new funkin.ui.states.ModsMenuState(), 'mods'), show, check('mods')]);
		optionSteps = optionSteps.concat([go(() -> new funkin.ui.options.OptionsState(), 'options'), show, check('options')]);
		optionSteps.push(() -> { cast(FlxG.state, funkin.ui.options.OptionsState).openSelectedSubstate('Notes'); return 'open notes'; });
		optionSteps.push(() -> pressOption('Open Note Color Editor'));
		optionSteps.push(check('notecolors'));
		optionSteps.push(() -> { cast(topSub(), flixel.FlxSubState).close(); return 'close note colors'; });
		optionSteps = optionSteps.concat([show, check('notes menu')]);
		optionSteps.push(() -> { cast(topSub(), flixel.FlxSubState).close(); return 'close notes'; });
		optionSteps.push(() -> { ClientPrefs.data.hideMouse = false; return 'hideMouse off'; });
		optionSteps = optionSteps.concat([show, check('options off')]);
		optionSteps.push(() -> { ClientPrefs.data.hideMouse = true; return 'hideMouse on'; });
		optionSteps.push(check('options on again'));
		optionSteps = optionSteps.concat([go(() -> new funkin.editors.MasterEditorMenu(), 'master editor'), show, check('master editor')]);
		optionSteps = optionSteps.concat([go(() -> new funkin.editors.CharacterEditorState(), 'char editor'), check('char editor')]);
		optionSteps.push(() -> { output.close(); Sys.exit(0); return 'exit'; });
		optionNext = haxe.Timer.stamp() + 1.5;
		FlxG.signals.postUpdate.add(optionsTick);
	}

	static function optionsTick()
	{
		if(lime.app.Application.current.window.minimized) optionNext = haxe.Timer.stamp() + 0.8;
		if(shotPending != null || haxe.Timer.stamp() < optionNext || optionSteps.length < 1) return;
		optionNext = haxe.Timer.stamp() + 0.8;
		try log('step ' + optionSteps.shift()())
		catch(e:Dynamic) log('step ERROR $e');
	}

	static function startFreeplayScroll(args:Array<String>)
	{
		output = File.write('memtest.log', false);
		var index:Int = args.indexOf('--freeplayscroll');
		scrollInterval = Std.parseFloat(args[index + 1]) / 1000;
		scrollMode = args[index + 2];
		duration = Std.parseFloat(args[index + 3]);
		log('freeplay scroll every ${scrollInterval * 1000}ms mode $scrollMode for ${duration}s');
		startTime = haxe.Timer.stamp();
		FlxG.signals.postUpdate.add(scrollTick);
		FlxG.switchState(new funkin.ui.states.FreeplayState());
	}

	@:access(funkin.ui.states.FreeplayState)
	static function scrollTick()
	{
		var now:Float = haxe.Timer.stamp();
		frames++;
		if(lastFrame > 0 && now - lastFrame > 0.1)
			log('FREEZE ${Math.round((now - lastFrame) * 1000)}ms at ${fmt(now - startTime)}s working ${fmt(MemoryTestNative.workingSet() / 1048576)} gc ${fmt(MemoryUtils.getGCMemory() / 1048576)}');
		lastFrame = now;

		var state:funkin.ui.states.FreeplayState = Std.downcast(FlxG.state, funkin.ui.states.FreeplayState);
		if(state == null || state.songs.length < 2) return;

		if(now >= nextScroll && scrollMode != 'idle')
		{
			nextScroll = now + scrollInterval;
			scrollCount++;
			switch(scrollMode)
			{
				case 'diff':
					state.changeDiff(1, true);
				case 'nopreview':
					state.changeSelection(1, false);
					if(state.previewTimer != null) state.previewTimer.cancel();
				case 'raw':
					funkin.ui.states.FreeplayState.curSelected = (funkin.ui.states.FreeplayState.curSelected + 1) % state.songs.length;
				case 'diff0':
					state.changeDiff(0);
				case 'color':
					var song = state.songs[(scrollCount) % state.songs.length];
					FlxTween.cancelTweensOf(state.bg);
					FlxTween.color(state.bg, 1, state.bg.color, song.isRandom ? 0xFF808080 : song.color);
				case 'nosound':
					state.changeSelection(1, false);
				default:
					state.changeSelection(1);
			}
		}

		if(now - lastLog < 1) return;
		var fps:Float = frames / (now - lastLog);
		frames = 0;
		lastLog = now;
		var reserved:Float = cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_RESERVED) / 1048576;
		log('${fmt(now - startTime)}s changes $scrollCount gc ${fmt(MemoryUtils.getGCMemory() / 1048576)} reserved ${fmt(reserved)} working ${fmt(MemoryTestNative.workingSet() / 1048576)} private ${fmt(MemoryTestNative.privateUsage() / 1048576)} fps ${Math.round(fps)}');

		if(now - startTime >= duration)
		{
			output.close();
			Sys.exit(0);
		}
	}

	static function openFreeplay()
	{
		freeplayUntil = haxe.Timer.stamp() + 8;
		FlxG.switchState(new funkin.ui.states.FreeplayState());
	}

	static function loadSong(song:String)
	{
		Difficulty.list = Difficulty.defaultList.copy();
		difficultyIndex = Difficulty.list.indexOf(difficultyName);
		if(difficultyIndex < 0)
		{
			Difficulty.list.push(difficultyName);
			difficultyIndex = Difficulty.list.length - 1;
		}
		var formatted:String = Paths.formatToSongPath(song);
		Song.loadFromJson(formatted + Difficulty.getFilePath(difficultyIndex), formatted);
		PlayState.isStoryMode = args().contains('--story');
		PlayState.storyDifficulty = difficultyIndex;
		startTime = haxe.Timer.stamp();
		songStarted = false;
		shots = shotTimes.copy();
		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
	}

	static function applyContentFlags(args:Array<String>)
	{
		if(args.contains('--nonaughty')) ClientPrefs.data.naughtyness = false;
		if(args.contains('--naughty')) ClientPrefs.data.naughtyness = true;
		if(args.contains('--nosubs')) ClientPrefs.data.subtitles = false;
		if(args.contains('--subs')) ClientPrefs.data.subtitles = true;
		if(output != null) log('content naughtyness ${ClientPrefs.data.naughtyness} subtitles ${ClientPrefs.data.subtitles}');
	}

	static var lastSubs:String = null;
	static var lastDad:String = null;
	static var lastVideo:String = null;
	static var subShots:Int = 0;
	static var lastSounds:String = null;
	static var lastSubStamp:Float = 0;
	static var updateStart:Float = 0;
	static var drawStart:Float = 0;
	static var lastUpdateMs:Float = 0;
	static var lastDrawMs:Float = 0;
	static var renderStart:Float = 0;
	static var lastRenderMs:Float = 0;
	static var soundTimes:haxe.ds.ObjectMap<FlxSound, Float> = new haxe.ds.ObjectMap();

	static function subLog()
	{
		var game:PlayState = PlayState.instance;
		if(game == null) return;

		if(game.dad != null && game.dad.curCharacter != lastDad)
		{
			lastDad = game.dad.curCharacter;
			log('subs dad ${lastDad} pos ${Math.round(Conductor.songPosition)}');
		}

		var stamp:Float = haxe.Timer.stamp();
		if(lastSubStamp > 0 && stamp - lastSubStamp > 0.04) log('subs hitch ${Math.round((stamp - lastSubStamp) * 1000)}ms at ${lime.system.System.getTimer()} pos ${Math.round(Conductor.songPosition)} gc ${fmt(MemoryUtils.getGCMemory() / 1048576)} bf ${game.boyfriend?.getAnimationName()} gf ${game.gf?.getAnimationName()} dad ${game.dad?.getAnimationName()} update ${Math.round(lastUpdateMs)}ms draw ${Math.round(lastDrawMs)}ms render ${Math.round(lastRenderMs)}ms');
		lastSubStamp = stamp;

		var sounds:Array<String> = [];
		if(FlxG.sound.music != null && FlxG.sound.music.playing) sounds.push('music len ${Math.round(FlxG.sound.music.length)} vol ${fmt(FlxG.sound.music.volume)}');
		for (sound in FlxG.sound.list)
		{
			if(sound == null || !sound.playing) continue;
			var times:Float = soundTimes.exists(sound) ? soundTimes.get(sound) : -1;
			if(sound.time + 50 < times) log('subs sound RESTART len ${Math.round(sound.length)} at ${Math.round(sound.time)} was ${Math.round(times)}');
			soundTimes.set(sound, sound.time);
			sounds.push('len ${Math.round(sound.length)} vol ${fmt(sound.volume)}');
		}
		var soundLine:String = sounds.join(' | ');
		if(soundLine != lastSounds)
		{
			lastSounds = soundLine;
			log('subs sounds pos ${Math.round(Conductor.songPosition)} ${soundLine.length > 0 ? soundLine : "(none)"}');
		}

		var groups:Array<funkin.game.subtitles.Subtitles> = [game.subtitles];
		#if VIDEOS_ALLOWED
		if(game.videoCutscene != null)
		{
			var name:String = @:privateAccess game.videoCutscene.videoName;
			if(name != lastVideo)
			{
				lastVideo = name;
				log('subs video $name subtitles ${game.videoCutscene.subtitles != null ? game.videoCutscene.subtitles.data.path : "none"}');
			}
			groups.push(game.videoCutscene.subtitles);
		}
		#end

		var parts:Array<String> = [];
		for (group in groups)
		{
			if(group == null) continue;
			for (member in group.members)
			{
				if(member == null || !member.visible || !Std.isOfType(member, flixel.text.FlxText)) continue;
				var text:flixel.text.FlxText = cast member;
				parts.push('"${text.text}" at ${Math.round(text.x + text.width / 2)},${Math.round(text.y + text.height / 2)} size ${text.size} scale ${text.scale.x},${text.scale.y} color ${text.color.toHexString(false)} font ${text.font.split("/").pop()}');
			}
		}
		var line:String = parts.join(' | ');
		if(line == lastSubs) return;
		lastSubs = line;
		log('subs pos ${Math.round(Conductor.songPosition)} ${line.length > 0 ? line : "(none)"}');
		if(line.length > 0 && shotPending == null && !args().contains('--noshots')) shotPending = 'subs_${++subShots}';
	}

	static var dialogStart:Float = 0;
	static var dialogStep:Int = 0;

	static function dialogShot(now:Float)
	{
		if(dialogStart == 0) dialogStart = now;
		var age:Float = now - dialogStart;
		var plan:Array<Float> = [4, 5, 8, 9, 12];
		if(dialogStep >= plan.length || age < plan[dialogStep] || shotPending != null) return;
		if(dialogStep % 2 == 0) shotPending = 'dialog_${Std.int(dialogStep / 2) + 1}';
		else
		{
			FlxG.stage.dispatchEvent(new openfl.events.KeyboardEvent(openfl.events.KeyboardEvent.KEY_DOWN, true, false, 13, 13));
			haxe.Timer.delay(() -> FlxG.stage.dispatchEvent(new openfl.events.KeyboardEvent(openfl.events.KeyboardEvent.KEY_UP, true, false, 13, 13)), 80);
			log('dialog advance');
		}
		dialogStep++;
	}

	static function startResultsShot()
	{
		var data:funkin.ui.states.ResultsState.ResultsData = {
			songName: 'Test', difficulty: 'hard', score: 123456, accuracy: 1, misses: 0, sicks: 100, goods: 0, bads: 0, shits: 0,
			totalHits: 100, maxCombo: 100, ratingFC: 'SFC', isStoryMode: false, isNewHighscore: false, playerCharacter: 'bf'
		};
		FlxG.switchState(new funkin.ui.states.ResultsState(data, () -> {}));
		var tag:String = ClientPrefs.data.naughtyness ? 'naughty' : 'safe';
		for (time in [4.5, 6.5, 9.0, 12.0])
			haxe.Timer.delay(() -> { shotPending = 'results_${tag}_${Std.int(time * 10)}'; log('results shot $time'); }, Std.int(time * 1000));
		haxe.Timer.delay(() -> {
			for (member in FlxG.state.members)
				log('results member ${Type.getClassName(Type.getClass(member))}');
			output.close();
			Sys.exit(0);
		}, 13500);
	}

	static function naughtyCheck()
	{
		for (state in [true, false])
		{
			ClientPrefs.data.naughtyness = state;
			log('naughtyness $state');
			log('  video stressPicoCutscene -> ${Paths.video("stressPicoCutscene")}');
			log('  video darnellCutscene -> ${Paths.video("darnellCutscene")}');
			log('  subtitles video -> ${funkin.game.subtitles.SubtitleData.findNextTo(Paths.video("stressPicoCutscene")) != null ? funkin.game.subtitles.SubtitleData.findNextTo(Paths.video("stressPicoCutscene")).path : "none"}');
			log('  subtitles end-cutscene -> ${funkin.game.subtitles.SubtitleData.find("songs/stress-(pico-mix)/subtitles/end-cutscene")}');
			log('  subtitles lyrics tutorial -> ${funkin.game.subtitles.SubtitleData.find("songs/tutorial/subtitles/song-lyrics")}');
			log('  subtitles santa -> ${funkin.game.subtitles.SubtitleData.find("subtitles/santa-emotions")}');
			for (dialogue in funkin.backend.Naughtyness.candidates('rosesDialogue'))
				log('  roses txt candidate $dialogue exists ${Paths.fileExists("data/songs/roses/" + dialogue + ".txt", TEXT)}');
			for (dialogue in funkin.backend.Naughtyness.candidates('roses-(pico-mix)Dialogue'))
				log('  roses pico json candidate $dialogue exists ${Paths.fileExists("data/songs/roses-(pico-mix)/" + dialogue + ".json", TEXT)}');
			log('  results layers ${[for (layer in funkin.ui.results.ResultsRank.RankData.layers(PERFECT, "bf")) layer.asset.split("/").pop() + (layer.startFrame != null ? "@" + layer.startFrame : "")].join(", ")}');
		}

		ClientPrefs.data.naughtyness = true;
		var sample:funkin.game.subtitles.SubtitleData = funkin.game.subtitles.SubtitleData.load('songs/tutorial/subtitles/song-lyrics');
		log('parsed tutorial srt lines ${sample.lines.length} first "${sample.lines[0].text}" ${sample.lines[0].start}-${sample.lines[0].end}ms');
		var json:funkin.game.subtitles.SubtitleData = funkin.game.subtitles.SubtitleData.fromFullPath(Paths.video("stressPicoCutscene").replace('.mp4', '.json'));
		log('parsed video json lines ${json.lines.length} font ${json.style.font} screams ${json.lines[3].text} x ${json.lines[3].style.x} start ${json.lines[3].start}');
		var times:Array<Dynamic> = ['00:01:02,500', '1:02.5', 62.5, '62.5'];
		for (time in times)
			log('parseTime $time -> ${funkin.game.subtitles.SubtitleData.parseTime(time)}ms');
	}

	static var inputTest:Bool = false;
	static var inputPlanned:Map<String, Bool> = new Map();
	static var inputEvents:Array<{time:Float, press:Bool, lane:Int, tag:String, noteTime:Float}> = [];
	static var inputHeld:Array<Bool> = [false, false, false, false];
	static var inputTapCount:Int = 0;
	static var inputHoldCount:Int = 0;
	static var inputNextGhost:Float = 4000;
	static var inputLast:Array<Float> = null;
	static final INPUT_OFFSETS:Array<Null<Float>> = [0, 30, -60, 80, -100, 115, 125, 145, null, 0, -20, 160];

	static function inputSnapshot(game:PlayState):Array<Float>
	{
		return [game.songScore, game.health, game.songMisses, game.combo, game.ratingsData[0].hits, game.ratingsData[1].hits,
			game.ratingsData[2].hits, game.ratingsData[3].hits, game.vsliceComboBreaks, game.maxCombo];
	}

	static function inputDelta(before:Array<Float>, after:Array<Float>):String
	{
		var names:Array<String> = ['sick', 'good', 'bad', 'shit'];
		var rating:String = 'none';
		for (i in 0...4) if(after[4 + i] > before[4 + i]) rating = names[i];
		return 'rating $rating dScore ${after[0] - before[0]} dHealth ${Math.round((after[1] - before[1]) * 10000) / 10000} misses ${after[2]} combo ${after[3]} breaks ${after[8]}';
	}

	static function inputKeyCode(lane:Int):Int
	{
		var keys = Controls.instance.keyboardBinds.get(['note_left', 'note_down', 'note_up', 'note_right'][lane]);
		for (key in keys) if(key != flixel.input.keyboard.FlxKey.NONE) return key;
		return -1;
	}

	static function inputKey(lane:Int, press:Bool)
	{
		var type:String = press ? openfl.events.KeyboardEvent.KEY_DOWN : openfl.events.KeyboardEvent.KEY_UP;
		var code:Int = inputKeyCode(lane);
		var charCode:Int = (code >= 65 && code <= 90) ? code + 32 : 0;
		FlxG.stage.dispatchEvent(new openfl.events.KeyboardEvent(type, true, false, charCode, code));
		inputHeld[lane] = press;
	}

	static var inputHeldBy:Array<Float> = [-2, -2, -2, -2];
	static var inputTracked:Map<String, String> = new Map();

	static function inputNoteState(note:funkin.game.notes.Note):String
		return '${note.isSustainNote ? "piece" : "head"} hit=${note.wasGoodHit} missed=${note.missed} ignore=${note.ignoreNote}';

	static function inputGoneNotes(game:PlayState):String
	{
		var alive:Map<String, String> = new Map();
		for (note in game.notes.members)
			if(note != null && note.alive && note.mustPress)
				alive.set('${Math.round(note.strumTime)}L${note.noteData}${note.isSustainNote ? "s" : ""}', inputNoteState(note));
		var gone:Array<String> = [for (id => state in inputTracked) if(!alive.exists(id)) '$id($state)'];
		inputTracked = alive;
		gone.sort((a, b) -> a < b ? -1 : 1);
		return gone.join(' ');
	}

	static function inputDriver(game:PlayState)
	{
		if(FlxG.sound.music == null) return;
		var pos:Float = FlxG.sound.music.time + Conductor.offset;

		for (note in game.notes.members)
		{
			if(note == null || !note.mustPress || note.isSustainNote || note.noteData < 0 || note.noteData > 3) continue;
			var id:String = '${Math.round(note.strumTime)}_${note.noteData}';
			if(inputPlanned.exists(id)) continue;
			inputPlanned.set(id, true);

			if(note.sustainLength > 0)
			{
				var kind:Int = inputHoldCount++ % 4;
				var end:Float = note.strumTime + note.sustainLength;
				var tag:String = ['hold-full', 'hold-drop', 'hold-late', 'hold-regrab'][kind];
				log('input plan $tag note ${Math.round(note.strumTime)} lane ${note.noteData} length ${Math.round(note.sustainLength)} pieces ${note.tail.length}');
				switch(kind)
				{
					case 0:
						inputEvents.push({time: note.strumTime, press: true, lane: note.noteData, tag: tag, noteTime: note.strumTime});
						inputEvents.push({time: end + 80, press: false, lane: note.noteData, tag: tag, noteTime: note.strumTime});
					case 1:
						inputEvents.push({time: note.strumTime, press: true, lane: note.noteData, tag: tag, noteTime: note.strumTime});
						inputEvents.push({time: note.strumTime + note.sustainLength * 0.4, press: false, lane: note.noteData, tag: tag, noteTime: note.strumTime});
					case 2:
						inputEvents.push({time: note.strumTime + 200, press: true, lane: note.noteData, tag: tag, noteTime: note.strumTime});
						inputEvents.push({time: end + 80, press: false, lane: note.noteData, tag: tag, noteTime: note.strumTime});
					default:
						inputEvents.push({time: note.strumTime, press: true, lane: note.noteData, tag: tag, noteTime: note.strumTime});
						inputEvents.push({time: note.strumTime + note.sustainLength * 0.3, press: false, lane: note.noteData, tag: tag, noteTime: note.strumTime});
						inputEvents.push({time: note.strumTime + note.sustainLength * 0.55, press: true, lane: note.noteData, tag: tag + '-again', noteTime: note.strumTime});
						inputEvents.push({time: end + 80, press: false, lane: note.noteData, tag: tag + '-again', noteTime: note.strumTime});
				}
			}
			else
			{
				var offset:Null<Float> = INPUT_OFFSETS[inputTapCount++ % INPUT_OFFSETS.length];
				if(offset == null)
				{
					log('input plan skip note ${Math.round(note.strumTime)} lane ${note.noteData}');
					continue;
				}
				inputEvents.push({time: note.strumTime + offset, press: true, lane: note.noteData, tag: 'tap$offset', noteTime: note.strumTime});
				inputEvents.push({time: note.strumTime + offset + 40, press: false, lane: note.noteData, tag: 'tap$offset', noteTime: note.strumTime});
			}
		}

		if(pos >= inputNextGhost)
		{
			inputNextGhost = pos + 4000;
			for (lane in 0...4)
			{
				if(inputHeld[lane]) continue;
				var busy:Bool = false;
				for (note in game.notes.members)
					if(note != null && note.mustPress && note.noteData == lane && Math.abs(note.strumTime - pos) < 400) busy = true;
				for (event in inputEvents)
					if(event.lane == lane && Math.abs(event.time - pos) < 400) busy = true;
				if(busy) continue;
				inputEvents.push({time: pos, press: true, lane: lane, tag: 'ghost', noteTime: -1});
				inputEvents.push({time: pos + 40, press: false, lane: lane, tag: 'ghost', noteTime: -1});
				break;
			}
		}

		inputEvents.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

		if(inputLast == null) log('input binds ${[for (lane in 0...4) inputKeyCode(lane)].join(',')}');
		var gone:String = inputGoneNotes(game);
		if(inputLast != null)
		{
			var now:Array<Float> = inputSnapshot(game);
			if(now.join(',') != inputLast.join(','))
				log('input passive pos ${Math.round(pos)} ${inputDelta(inputLast, now)} gone [$gone]');
		}
		game.health = 1;

		while(inputEvents.length > 0 && inputEvents[0].time <= pos)
		{
			var event = inputEvents.shift();
			if(!event.press && (!inputHeld[event.lane] || inputHeldBy[event.lane] != event.noteTime)) continue;

			if(event.press && inputHeld[event.lane])
			{
				game.health = 1;
				var beforeRelease:Array<Float> = inputSnapshot(game);
				inputKey(event.lane, false);
				log('input release forced lane ${event.lane} note ${Math.round(inputHeldBy[event.lane])} ${inputDelta(beforeRelease, inputSnapshot(game))}');
			}

			game.health = 1;
			var before:Array<Float> = inputSnapshot(game);
			var at:Float = FlxG.sound.music.time + Conductor.offset;
			inputKey(event.lane, event.press);
			if(event.press) inputHeldBy[event.lane] = event.noteTime;
			var after:Array<Float> = inputSnapshot(game);
			var diff:String = event.noteTime >= 0 ? '${Math.round(at - event.noteTime)}' : '-';
			log('input ${event.press ? "press" : "release"} ${event.tag} lane ${event.lane} note ${Math.round(event.noteTime)} diff $diff ${inputDelta(before, after)}');
			if(event.press && event.noteTime >= 0 && after[4] + after[5] + after[6] + after[7] == before[4] + before[5] + before[6] + before[7])
			{
				var code:Int = inputKeyCode(event.lane);
				var info:Array<String> = [];
				for (note in game.notes.members)
					if(note != null && note.noteData == event.lane && Math.abs(note.strumTime - event.noteTime) < 1)
						info.push('${note.isSustainNote ? "piece" : "head"} must ${note.mustPress} canBeHit ${note.canBeHit} tooLate ${note.tooLate} hit ${note.wasGoodHit} block ${note.blockHit} strumline ${note.extraData != null ? note.extraData.get("strumlineIndex") : null} blocked ${game.strumsBlocked[note.noteData]}');
				log('input nohit justPressed ${FlxG.keys.checkStatus(code, JUST_PRESSED)} pressed ${FlxG.keys.checkStatus(code, PRESSED)} laneFromKey ${PlayState.getKeyFromEvent(game.keysArray, code)} controllerMode ${Controls.instance.controllerMode} notes ${info.join(" | ")}');
			}
			game.health = 1;
		}
		inputLast = inputSnapshot(game);
	}

	static function inputSummary(game:PlayState)
	{
		log('input SUMMARY system ${game.inputSystem} score ${game.songScore} misses ${game.songMisses} sick ${game.ratingsData[0].hits} good ${game.ratingsData[1].hits} bad ${game.ratingsData[2].hits} shit ${game.ratingsData[3].hits} breaks ${game.vsliceComboBreaks} maxCombo ${game.maxCombo} fc ${game.ratingFC} accuracy ${fmt(game.ratingPercent * 100)} ghostTapping ${game.ghostTapping} sustainsAsOne ${game.guitarHeroSustains} safeZone ${fmt(Conductor.safeZoneOffset)} windows ${[for (r in game.ratingsData) fmt(r.hitWindow)].join('/')}');
	}

	static function tick()
	{
		var now:Float = haxe.Timer.stamp();
		frames++;
		if(inputTest && PlayState.instance != null && PlayState.instance.startedCountdown && !PlayState.instance.paused && Std.isOfType(FlxG.state, PlayState))
			inputDriver(PlayState.instance);
		if(args().contains('--sublog') && Std.isOfType(FlxG.state, PlayState)) subLog();
		if(args().contains('--dialogshot') && !songStarted && Std.isOfType(FlxG.state, PlayState)) dialogShot(now);
		var spike:String = spikes.pop(false);
		while (spike != null)
		{
			log(spike);
			spike = spikes.pop(false);
		}
		if(freeplayUntil > 0 && now >= freeplayUntil)
		{
			freeplayUntil = -1;
			loadSong(songList[songIndex]);
		}
		if(songStarted && actions.length > 0 && now - startTime >= Std.parseFloat(actions[0].split(':')[0]))
		{
			var action:String = actions.shift().split(':')[1];
			log('action $action');
			var game:PlayState = PlayState.instance;
			if(action == 'pause' && game != null) game.openPauseMenu();
			else if(action == 'resume' && FlxG.state.subState != null) FlxG.state.subState.close();
			else if(action == 'finish' && game != null) game.finishSong(true);
			else if(action == 'nobot' && game != null) game.cpuControlled = false;
			else if(action == 'framelog') frameLogUntil = haxe.Timer.stamp() + 0.3;
			else if(action == 'shotkey')
			{
				var key:Int = ClientPrefs.keyBinds.get('screenshot')[0];
				FlxG.stage.dispatchEvent(new openfl.events.KeyboardEvent(openfl.events.KeyboardEvent.KEY_DOWN, true, false, 0, key));
				log('shotkey sent $key allow ${ClientPrefs.data.allowScreenshots}');
			}
			else if(action == 'endcut' && game != null)
			{
				game.KillNotes();
				game.finishSong(true);
			}
			else if(action.startsWith('seek') && game != null)
			{
				var target:Float = Std.parseFloat(action.substr(4)) * 1000;
				game.clearNotesBefore(target);
				game.setSongTime(target);
			}
			else if(action == 'lowhp' && game != null)
			{
				game.healthGain = 0;
				game.health = 0.3;
			}
			else if(action == 'explode' && game != null)
			{
				funkin.game.states.GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pico-explode';
				funkin.game.states.GameOverSubstate.loopSoundName = 'gameOverStart-pico-explode';
				funkin.game.states.GameOverSubstate.characterName = 'pico-explosion-dead';
				game.health = 0;
				game.doDeathCheck();
			}
			else if(action == 'endnow' && game != null)
			{
				game.KillNotes();
				game.finishSong(true);
				log('endnow cpuControlled ${game.cpuControlled} completedRank ${funkin.ui.states.FreeplayState.completedRank}');
				output.close();
				Sys.exit(0);
			}
			else if(action == 'blur')
			{
				var before:Float = FlxG.sound.volume;
				var songBefore:Float = Conductor.songPosition;
				FlxG.stage.dispatchEvent(new openfl.events.Event(openfl.events.Event.DEACTIVATE));
				log('blur volume $before -> ${FlxG.sound.volume} autoPause ${FlxG.autoPause} paused ${game != null && game.paused}');
				haxe.Timer.delay(function() {
					log('before activate volume ${FlxG.sound.volume} song advanced ${Math.round(Conductor.songPosition - songBefore)}ms paused ${PlayState.instance != null && PlayState.instance.paused}');
					FlxG.stage.dispatchEvent(new openfl.events.Event(openfl.events.Event.ACTIVATE));
					log('activate volume ${FlxG.sound.volume}');
					frameLogUntil = haxe.Timer.stamp() + 1.5;
				}, 1500);
			}
			else if(action == 'drop' && game != null)
			{
				game.combo = 80;
				game.noteMissCommon(0);
			}
			else if(action == 'die' && game != null)
			{
				game.health = 0;
				game.doDeathCheck();
			}
			else if(action == 'retry' && Std.isOfType(FlxG.state.subState, funkin.game.states.GameOverSubstate))
			{
				songStarted = false;
				@:privateAccess cast(FlxG.state.subState, funkin.game.states.GameOverSubstate).endBullshit();
			}
			else if(action == 'restart')
			{
				songStarted = false;
				FlxG.state.closeSubState();
				FlxG.resetState();
			}
		}
		if(Std.isOfType(FlxG.state, LoadingState))
		{
			if(loadingSince < 0) { loadingSince = now; log('loading screen opened'); }
		}
		else if(loadingSince >= 0)
		{
			log('loading screen closed after ${Math.round((now - loadingSince) * 1000)}ms');
			loadingSince = -1;
		}
		if(args().contains('--flashshot') && PlayState.instance != null && flashShots < 6)
		{
			for (stage in PlayState.instance.stages)
			{
				if (!Std.isOfType(stage, funkin.game.stages.erect.TankErect)) continue;
				var flash:flixel.FlxSprite = @:privateAccess cast(stage, funkin.game.stages.erect.TankErect).muzzleFlash;
				if (flash != null && flash.visible && flash.animation.curAnim != null && flash.animation.curAnim.curFrame == 2 && shotPending == null)
				{
					flashShots++;
					var gf = PlayState.instance.gf;
					log('flash ${flash.animation.curAnim.name} pos ${Math.round(flash.x)},${Math.round(flash.y)} size ${Math.round(flash.frameWidth)}x${Math.round(flash.frameHeight)} gf ${Math.round(gf.x)},${Math.round(gf.y)} off ${Math.round(gf.offset.x)},${Math.round(gf.offset.y)}');
					shotPending = 'flash_$flashShots';
				}
			}
		}
		#if VIDEOS_ALLOWED
		if(args().contains('--skipvideo') && Std.isOfType(FlxG.state, PlayState) && PlayState.instance != null && PlayState.instance.videoCutscene != null && PlayState.instance.videoCutscene.holdingTime < 2)
		{
			log('skipping video');
			PlayState.instance.videoCutscene.holdingTime = 2;
		}
		#end
		if(args().contains('--litlog') && PlayState.instance != null && !litHooked)
		{
			litHooked = true;
			FlxG.signals.preDraw.add(function() if(PlayState.instance != null) litLog(PlayState.instance));
		}
		if(args().contains('--nenelog') && PlayState.instance != null && PlayState.instance.gf != null) neneLog(PlayState.instance);
		if(args().contains('--cutscene') && PlayState.instance != null)
		{
			cutsceneLog(PlayState.instance);
			return;
		}
		if(args().contains('--resultcheck') && Std.isOfType(FlxG.state, funkin.ui.states.ResultsState))
		{
			log('resultcheck completedRank ${funkin.ui.states.FreeplayState.completedRank}');
			output.close();
			Sys.exit(0);
		}
		if(songStarted && args().contains('--animshots') && PlayState.instance != null)
		{
			animShots(PlayState.instance);
			return;
		}
		if(args().contains('--cutframes') && PlayState.instance != null && PlayState.instance.inCutscene) cutFrameLog(PlayState.instance);
		if(args().contains('--charlog') && PlayState.instance != null && PlayState.instance.dad != null) charLog(PlayState.instance);
		if(songStarted && args().contains('--endcheck') && PlayState.instance != null)
		{
			endCheck(PlayState.instance);
			return;
		}
		if(args().contains('--gameover') && Std.isOfType(FlxG.state.subState, funkin.game.states.GameOverSubstate))
		{
			gameOverTick(cast FlxG.state.subState);
			return;
		}
		if(songStarted && args().contains('--nenecheck') && PlayState.instance != null)
		{
			neneCheck(PlayState.instance);
			return;
		}
		if(songStarted && args().contains('--litcheck') && PlayState.instance != null)
		{
			litCheck(PlayState.instance);
			return;
		}
		if(now < frameLogUntil && PlayState.instance != null && FlxG.sound.music != null)
			log('frame stamp ${Math.round(now * 10000) / 10} elapsed ${Math.round(FlxG.elapsed * 10000) / 10} pos ${Math.round(Conductor.songPosition)} inst ${Math.round(FlxG.sound.music.time)} voc ${Math.round(PlayState.instance.vocals.time)} playing ${FlxG.sound.music.playing}');
		if(songStarted && shots.length > 0 && now - startTime >= shots[0])
			shotPending = '${Paths.formatToSongPath(songList[songIndex])}_${Std.int(shots.shift() * 10)}';
		if(now - lastLog < 1) return;
		var fps:Float = frames / (now - lastLog);
		frames = 0;
		lastLog = now;

		var gc:Float = MemoryUtils.getGCMemory() / 1048576;
		var reserved:Float = cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_RESERVED) / 1048576;
		var task:Float = MemoryUtils.getTaskMemory() / 1048576;
		var working:Float = MemoryTestNative.workingSet() / 1048576;
		var privateBytes:Float = MemoryTestNative.privateUsage() / 1048576;
		var inSong:Bool = Std.isOfType(FlxG.state, PlayState) && PlayState.instance != null && PlayState.instance.startedCountdown;
		if(inSong && !songStarted)
		{
			songStarted = true;
			startTime = now;
			log('--- song started ${songList[songIndex]}');
			dumpAssets();
		}

		if(songStarted)
		{
			if(gc > peakGC) peakGC = gc;
			if(task > peakTask) peakTask = task;
			sumGC += gc;
			sumTask += task;
			sumFps += fps;
			samples++;
		}

		var sync:String = '';
		var camInfo:String = '';
		if(args().contains('--skipvideo') && PlayState.instance != null) { var g = PlayState.instance; camInfo = ' countdown ${g.startedCountdown} cutscene ${g.inCutscene} video ${g.videoCutscene != null} starting ${g.startingSong} generated ${g.generatedMusic} seen ${PlayState.seenCutscene} substate ${g.subState != null}'; }
		if(inSong && args().contains('--shaderlog')) { var g = PlayState.instance; camInfo = ' shaders bf ${g.boyfriend.shader != null ? Type.getClassName(Type.getClass(g.boyfriend.shader)) : "none"} gf ${g.gf != null && g.gf.shader != null ? Type.getClassName(Type.getClass(g.gf.shader)) : "none"} dad ${g.dad.shader != null ? Type.getClassName(Type.getClass(g.dad.shader)) : "none"} pref ${funkin.save.ClientPrefs.data.shaders} bfchar ${g.boyfriend.curCharacter} gfchar ${g.gf != null ? g.gf.curCharacter : "none"} bfcount ${g.boyfriendGroup.length} gfcount ${g.gfGroup.length}'; }
		if(inSong && args().contains('--camlog')) { var g = PlayState.instance; camInfo = ' cam ${Math.round(g.camFollow.x)},${Math.round(g.camFollow.y)} zoom ${Math.round(FlxG.camera.zoom * 1000) / 1000} forced ${g.isCameraOnForcedPos} section ${PlayState.SONG.notes[g.curSection] != null ? PlayState.SONG.notes[g.curSection].mustHitSection : null} bfmid ${Math.round(g.boyfriend.getMidpoint().x)},${Math.round(g.boyfriend.getMidpoint().y)} dadmid ${Math.round(g.dad.getMidpoint().x)},${Math.round(g.dad.getMidpoint().y)}'; }
		if(args().contains('--vizlog') && funkin.game.stages.PicoCapableStage.instance != null && funkin.game.stages.PicoCapableStage.instance.abot != null) camInfo = ' viz ' + [for (viz in funkin.game.stages.PicoCapableStage.instance.abot.vizSprites) viz.visible ? 5 - viz.animation.curAnim.curFrame : -1].join(',') + ' playing ' + (FlxG.sound.music != null && FlxG.sound.music.playing);
		if(inSong && FlxG.sound.music != null) sync = ' pos ${Math.round(Conductor.songPosition)} inst ${Math.round(FlxG.sound.music.time)} voc ${Math.round(PlayState.instance.vocals.time)} opp ${Math.round(PlayState.instance.opponentVocals.time)}';
		log('${Math.round(now - startTime)}s ${Type.getClassName(Type.getClass(FlxG.state))} gc ${fmt(gc)} reserved ${fmt(reserved)} task ${fmt(task)} working ${fmt(working)} fps ${Math.round(fps)}$sync$camInfo');

		if(songStarted && now - startTime >= duration)
		{
			if(inputTest && PlayState.instance != null) inputSummary(PlayState.instance);
			log('RESULT ${songList[songIndex]} avgGC ${fmt(sumGC / samples)} peakGC ${fmt(peakGC)} avgTask ${fmt(sumTask / samples)} peakTask ${fmt(peakTask)} working ${fmt(working)} private ${fmt(privateBytes)} avgFps ${Math.round(sumFps / samples)} processPeak ${fmt(MemoryTestNative.peakWorkingSet() / 1048576)}');
			peakGC = peakTask = sumGC = sumTask = sumFps = 0;
			samples = 0;
			songIndex++;
			if(songIndex < songList.length)
			{
				if(viaFreeplay) openFreeplay();
				else loadSong(songList[songIndex]);
				return;
			}
			output.close();
			Sys.exit(0);
		}
	}

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	@:access(openfl.display.BitmapData)
	static function dumpAssets()
	{
		var lines:Array<{size:Float, text:String}> = [];
		var total:Float = 0;
		var totalRam:Float = 0;
		for (key => graphic in FlxG.bitmap._cache)
		{
			if(graphic == null || graphic.bitmap == null) continue;
			var bitmap = graphic.bitmap;
			var size:Float = bitmap.width * bitmap.height * 4 / 1048576;
			var inRam:Bool = bitmap.image != null;
			total += size;
			if(inRam) totalRam += size;
			lines.push({size: size, text: 'bitmap ${fmt(size)}MB ${bitmap.width}x${bitmap.height} ram $inRam gpu ${bitmap.__texture != null} $key'});
		}
		lines.sort(function(a, b) return a.size > b.size ? -1 : (a.size < b.size ? 1 : 0));
		for (line in lines) log(line.text);
		log('bitmaps total ${fmt(total)}MB inRam ${fmt(totalRam)}MB count ${lines.length}');

		var soundTotal:Float = 0;
		for (key => sound in Paths.currentTrackedSounds)
		{
			@:privateAccess var buffer = sound != null ? sound.__buffer : null;
			var size:Float = (buffer != null && buffer.data != null) ? buffer.data.length / 1048576 : 0;
			soundTotal += size;
			log('sound ${fmt(size)}MB $key');
		}
		log('sounds total ${fmt(soundTotal)}MB');
	}

	static function onRender(_)
	{
		if(shotPending == null) return;
		var image = lime.app.Application.current.window.readPixels();
		if(image != null)
		{
			if(!sys.FileSystem.exists('memshots')) sys.FileSystem.createDirectory('memshots');
			File.saveBytes('memshots/$shotPending.png', image.encode(lime.graphics.ImageFileFormat.PNG));
		}
		if(args().contains('--notelog') && PlayState.instance != null)
		{
			var g = PlayState.instance;
			for (c in g.grpHoldCovers.members)
				if (c != null && c.visible) log('cover $shotPending data ${c.noteData} opp ${c.isOpponent} anim ${c.animation.curAnim != null ? c.animation.curAnim.name + ":" + c.animation.curAnim.curFrame : "none"} frame ${c.frame != null ? c.frame.name : "none"} pos ${Math.round(c.x)},${Math.round(c.y)} scale ${c.scale.x} size ${Math.round(c.width)}x${Math.round(c.height)} alpha ${c.alpha}');
			for (s in g.grpNoteSplashes.members)
				if (s != null && s.visible && s.exists) log('splash $shotPending pos ${Math.round(s.x)},${Math.round(s.y)} scale ${s.scale.x} anim ${s.animation.curAnim != null ? s.animation.curAnim.name : "none"} frame ${s.frame != null ? s.frame.name : "none"}');
			for (s in g.opponentStrums.members) log('strum $shotPending opp pos ${Math.round(s.x)},${Math.round(s.y)} anim ${s.animation.curAnim != null ? s.animation.curAnim.name : "none"}');
		}
		shotPending = null;
	}

	static function args():Array<String> return Sys.args();

	static function fmt(value:Float):String
		return Std.string(Math.round(value * 10) / 10);

	static function log(text:String)
	{
		output.writeString(text + '\n');
		output.flush();
	}
}

@:cppFileCode('
#include <Windows.h>
#include <psapi.h>
#include <stdio.h>

static DWORD memtestMainThread = 0;

static void memtestModuleOf(void* address, char* out, int size)
{
	HMODULE module = NULL;
	out[0] = 0;
	if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR)address, &module) && module)
	{
		char path[MAX_PATH];
		GetModuleFileNameA(module, path, MAX_PATH);
		_snprintf_s(out, size, _TRUNCATE, "%s+0x%llx", path, (unsigned long long)((char*)address - (char*)module));
	}
	else _snprintf_s(out, size, _TRUNCATE, "?%p", address);
}

static LONG WINAPI memtestVectoredHandler(PEXCEPTION_POINTERS info)
{
	DWORD code = info->ExceptionRecord->ExceptionCode;
	if (code != EXCEPTION_ACCESS_VIOLATION && code != EXCEPTION_ILLEGAL_INSTRUCTION && code != EXCEPTION_STACK_OVERFLOW) return EXCEPTION_CONTINUE_SEARCH;
	FILE* file = NULL;
	fopen_s(&file, "segv.log", "a");
	if (!file) return EXCEPTION_CONTINUE_SEARCH;
	char where[600];
	memtestModuleOf(info->ExceptionRecord->ExceptionAddress, where, 600);
	fprintf(file, "EXCEPTION 0x%lx thread %lu main %d at %s", code, GetCurrentThreadId(), GetCurrentThreadId() == memtestMainThread, where); fputc(10, file);
	if (code == EXCEPTION_ACCESS_VIOLATION && info->ExceptionRecord->NumberParameters >= 2)
		{ fprintf(file, "  access %s address %p", info->ExceptionRecord->ExceptionInformation[0] ? "write" : "read", (void*)info->ExceptionRecord->ExceptionInformation[1]); fputc(10, file); }
	fflush(file);
	void* frames[48];
	USHORT count = CaptureStackBackTrace(0, 48, frames, NULL);
	for (USHORT i = 0; i < count; i++)
	{
		memtestModuleOf(frames[i], where, 600);
		fprintf(file, "  #%d %s", i, where); fputc(10, file);
	}
	fflush(file);
	if (GetCurrentThreadId() == memtestMainThread)
	{
		::Array< ::String > haxeStack = __hxcpp_get_call_stack(false);
		for (int i = 0; i < haxeStack->length; i++) { fprintf(file, "  hx %s", haxeStack[i].utf8_str()); fputc(10, file); fflush(file); }
	}
	fclose(file);
	return EXCEPTION_CONTINUE_SEARCH;
}
')
class MemoryTestNative
{
	@:functionCode('
		memtestMainThread = GetCurrentThreadId();
		AddVectoredExceptionHandler(0, memtestVectoredHandler);
	')
	public static function installCrashLog():Void {}

	@:functionCode('
		PROCESS_MEMORY_COUNTERS_EX counters;
		if (K32GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&counters, sizeof(counters)))
			return (double)counters.WorkingSetSize;
		return 0;
	')
	public static function workingSet():Float
	{
		return 0;
	}

	@:functionCode('
		PROCESS_MEMORY_COUNTERS_EX counters;
		if (K32GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&counters, sizeof(counters)))
			return (double)counters.PrivateUsage;
		return 0;
	')
	public static function privateUsage():Float
	{
		return 0;
	}

	@:functionCode('
		PROCESS_MEMORY_COUNTERS_EX counters;
		if (K32GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&counters, sizeof(counters)))
			return (double)counters.PeakWorkingSetSize;
		return 0;
	')
	public static function peakWorkingSet():Float
	{
		return 0;
	}
}
#end
