package funkin.util;

import openfl.Lib;
import openfl.errors.Error;
import openfl.events.ErrorEvent;
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import funkin.ui.states.ErrorState;
import funkin.ui.states.MainMenuState;

class CrashHandler
{
	public static var crashing:Bool = false;

	public static function init()
	{
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);

		@:privateAccess
		{
			var stageEvents = FlxG.stage != null ? FlxG.stage.__uncaughtErrorEvents : null;
			if(stageEvents != null && stageEvents != Lib.current.loaderInfo.uncaughtErrorEvents)
			{
				stageEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
				stageEvents.__enabled = true;
			}
		}

		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(onCriticalError);
		#end
	}

	public static function test():Void
	{
		Logger.log('CrashHandler.test() called');
		onUncaughtError(new UncaughtErrorEvent(UncaughtErrorEvent.UNCAUGHT_ERROR, true, true, 'test crash'));
	}

	static function onCriticalError(message:String):Void
	{
		throw Std.string(message);
	}

	static function onUncaughtError(event:UncaughtErrorEvent):Void
	{
		event.preventDefault();
		event.stopPropagation();
		event.stopImmediatePropagation();

		if(crashing) return;
		crashing = true;

		var report:String = buildReport(messageOf(event.error));
		var path:String = Logger.writeDump(report, 'MuttEngine');

		Logger.error(report);
		if(path != null) Logger.log('Crash dump saved: $path');

		recover(report, path);
	}

	static function messageOf(error:Dynamic):String
	{
		if(Std.isOfType(error, Error)) return cast(error, Error).message;
		if(Std.isOfType(error, ErrorEvent)) return cast(error, ErrorEvent).text;
		return Std.string(error);
	}

	static function buildReport(message:String):String
	{
		var lines:Array<String> = [
			'Mutt Engine v' + Main.engineVersion,
			'Date: ' + Date.now().toString(),
			'System: ' + systemName(),
			'State: ' + currentState()
		];

		#if MODS_ALLOWED
		var mod:String = Mods.currentModDirectory;
		lines.push('Mod: ' + (mod != null && mod.length > 0 ? mod : 'none'));
		#end

		lines.push('');
		lines.push('Exception: ' + message);
		lines.push('');
		lines.push('Callstack:');

		var stack:String = formatStack(CallStack.exceptionStack(true));
		lines.push(stack.length > 0 ? stack : '  N/A');

		return lines.join('\n');
	}

	static function formatStack(callStack:Array<StackItem>):String
	{
		var out:String = '';

		for(item in callStack)
		{
			switch(item)
			{
				case FilePos(_, file, line, _): out += '  $file (line $line)';
				case Method(classname, method): out += '  $classname.$method()';
				case Module(m): out += '  module $m';
				case LocalFunction(v): out += '  localFunction $v';
				case CFunction: out += '  cFunction';
			}

			out += '\n';
		}

		return out.trim();
	}

	static function currentState():String
	{
		if(FlxG.state == null) return 'N/A';

		var cl = Type.getClass(FlxG.state);
		if(cl == null) return 'N/A';

		var name:String = Type.getClassName(cl);
		return name != null ? name : 'N/A';
	}

	static function systemName():String
	{
		#if sys
		return Sys.systemName();
		#else
		return 'unknown';
		#end
	}

	public static var SHOWN_STACK_LINES:Int = 6;

	static function shorten(report:String):String
	{
		var lines:Array<String> = report.split('\n');
		var kept:Array<String> = [];
		var stackLines:Int = 0;
		var inStack:Bool = false;

		for(line in lines)
		{
			if(line == 'Callstack:')
			{
				inStack = true;
				kept.push(line);
				continue;
			}

			if(!inStack)
			{
				kept.push(line);
				continue;
			}

			if(stackLines < SHOWN_STACK_LINES)
			{
				kept.push(line);
				stackLines++;
			}
		}

		if(stackLines >= SHOWN_STACK_LINES) kept.push('  ...');

		return kept.join('\n');
	}

	static function recover(report:String, path:String):Void
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		if(FlxG.state != null)
		{
			FlxG.state.persistentUpdate = false;
			FlxG.state.persistentDraw = false;
		}

		try
		{
			if(FlxG.sound.music != null) FlxG.sound.music.stop();
			FlxTween.globalManager.clear();
			FlxTimer.globalManager.clear();
		}
		catch(e:Dynamic) {}

		var shown:String = shorten(report);
		if(path != null) shown += '\n\nSaved to: ' + path;
		shown += '\n\nPress ACCEPT or BACK to return to the menu.';

		var toMenu:Void->Void = function()
		{
			crashing = false;
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			FlxG.switchState(new MainMenuState());
		};

		FlxG.switchState(new ErrorState(shown, toMenu, toMenu));
	}
}
