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
	static var spikes:sys.thread.Deque<String> = new sys.thread.Deque<String>();
	public static var phase:String = 'boot';

	public static function start():Bool
	{
		var args:Array<String> = Sys.args();
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
		if(inSong && FlxG.sound.music != null) sync = ' pos ${Math.round(Conductor.songPosition)} inst ${Math.round(FlxG.sound.music.time)} voc ${Math.round(PlayState.instance.vocals.time)} opp ${Math.round(PlayState.instance.opponentVocals.time)}';
		log('${Math.round(now - startTime)}s ${Type.getClassName(Type.getClass(FlxG.state))} gc ${fmt(gc)} reserved ${fmt(reserved)} task ${fmt(task)} working ${fmt(working)} fps ${Math.round(fps)}$sync');

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
		shotPending = null;
	}

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
