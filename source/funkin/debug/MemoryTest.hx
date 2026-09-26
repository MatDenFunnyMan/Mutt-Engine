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
		if(args.contains('--gpu')) ClientPrefs.data.cacheOnGPU = true;
		if(args.contains('--nogpu')) ClientPrefs.data.cacheOnGPU = false;
		if(args.contains('--level')) Paths.setCurrentLevel(args[args.indexOf('--level') + 1]);
		if(args.contains('--nocutscene')) PlayState.seenCutscene = true;
		if(args.contains('--cutscene'))
		{
			funkin.game.cutscenes.TwoPicos.forcePlayerShoots = args[args.indexOf('--cutscene') + 1] == '1';
			funkin.game.cutscenes.TwoPicos.forceExplode = args[args.indexOf('--cutscene') + 2] == '1';
		}
		output = File.write('memtest.log', false);
		log('song $song difficulty $difficulty mod ${Mods.currentModDirectory} cacheOnGPU ${ClientPrefs.data.cacheOnGPU}');

		var before:Float = MemoryUtils.getGCMemory() / 1048576;
		cpp.vm.Gc.run(true);
		cpp.vm.Gc.compact();
		log('boot gc before collect ${fmt(before)} after ${fmt(MemoryUtils.getGCMemory() / 1048576)}');
		dumpAssets();
		ClientPrefs.data.gameplaySettings.set('botplay', true);
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
		FlxG.signals.postUpdate.add(tick);
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

	@:access(funkin.Paths)
	static function neneCheck(game:PlayState)
	{
		var abot:funkin.game.stages.objects.ABotSpeaker = (funkin.game.stages.PicoCapableStage.instance != null) ? funkin.game.stages.PicoCapableStage.instance.abot : null;
		if(abot == null)
			for (s in game.stages)
			{
				var found:Dynamic = Reflect.getProperty(s, 'abot');
				if(Std.isOfType(found, funkin.game.stages.objects.ABotSpeaker)) abot = cast found;
			}
		if(neneSteps == null)
		{
			log('nene viz before test: music playing ${FlxG.sound.music != null && FlxG.sound.music.playing} visible ${[for (viz in abot.vizSprites) viz.visible]}');
			neneSteps = ['nene', 'abot', 'probe', 'full'];
			if(FlxG.sound.music != null) FlxG.sound.music.pause();
			game.vocals.pause();
			game.opponentVocals.pause();
			var folder:String = (PlayState.SONG.gfVersion == 'nene-dark') ? 'abot/dark/abotSystem' : 'abot/abotSystem';
			neneProbe = new animate.FlxAnimate();
			neneProbe.frames = Paths.loadModernAtlas(folder, Paths.getTextFromFile('images/$folder/Animation.json'));
			neneProbe.antialiasing = ClientPrefs.data.antialiasing;
			game.add(neneProbe);
			log('nenecheck gf ${game.gf.curCharacter} gf ${game.gf.x},${game.gf.y} offset ${game.gf.offset.x},${game.gf.offset.y} gfGroup ${game.gfGroup.x},${game.gfGroup.y} abot ${abot.x},${abot.y} speaker ${abot.speaker.x},${abot.speaker.y} sf gf ${game.gf.scrollFactor.x},${game.gf.scrollFactor.y} abot ${abot.scrollFactor.x} speaker ${abot.speaker.scrollFactor.x},${abot.speaker.scrollFactor.y}');
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

		var gf = game.gf;
		gf.playAnim('danceLeft', true, false, 0);
		if(gf.animation.curAnim != null) gf.animation.curAnim.pause();
		abot.speaker.anim.curFrame = 0;
		abot.speaker.anim.pause();
		neneProbe.setPosition(gf.x - gf.offset.x - 95, gf.y - gf.offset.y + 384);

		switch(step)
		{
			case 'nene':
				game.gfGroup.visible = true;
			case 'abot':
				abot.visible = true;
				for (member in abot.members) member.visible = (member == abot.speaker);
			case 'probe':
				neneProbe.visible = true;
			case 'full':
				game.gfGroup.visible = true;
				abot.visible = true;
				for (member in abot.members) member.visible = true;
		}

		FlxG.camera.target = null;
		FlxG.camera.zoom = LIT_ZOOM;
		FlxG.camera.angle = 0;
		FlxG.camera.scroll.set(gf.x + 300 - FlxG.width / 2, gf.y + 450 - FlxG.height / 2);

		litTick++;
		if(litTick == 3)
		{
			log('neneshot $step probe ${neneProbe.x},${neneProbe.y}');
			shotPending = 'nene_$step';
		}
		if(litTick >= 4 && shotPending == null)
		{
			neneSteps.shift();
			litTick = 0;
		}
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
		var state:String = '${gf.getAnimationName()} state ${stage != null ? Std.string(stage.currentNeneState) : "-"} train ${stage != null && stage.trainPassing} skipDance ${gf.skipDance} special ${gf.specialAnim}';
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
		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = difficultyIndex;
		startTime = haxe.Timer.stamp();
		songStarted = false;
		shots = shotTimes.copy();
		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
	}

	static function tick()
	{
		var now:Float = haxe.Timer.stamp();
		frames++;
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
			else if(action == 'blur')
			{
				FlxG.stage.dispatchEvent(new openfl.events.Event(openfl.events.Event.DEACTIVATE));
				haxe.Timer.delay(function() {
					log('activate');
					FlxG.stage.dispatchEvent(new openfl.events.Event(openfl.events.Event.ACTIVATE));
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
			log('frame elapsed ${Math.round(FlxG.elapsed * 1000)} pos ${Math.round(Conductor.songPosition)} inst ${Math.round(FlxG.sound.music.time)} voc ${Math.round(PlayState.instance.vocals.time)} playing ${FlxG.sound.music.playing}');
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
')
class MemoryTestNative
{
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
