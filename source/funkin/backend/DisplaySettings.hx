package funkin.backend;

import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.ui.Window;

#if (cpp && windows)
@:cppFileCode('
#include <windows.h>

typedef BOOL (WINAPI *MuttSwapIntervalProc)(int);
typedef PROC (WINAPI *MuttGetProcAddressProc)(LPCSTR);
static MuttSwapIntervalProc muttSwapInterval = NULL;

static bool muttSetSwapInterval(int interval)
{
	if (muttSwapInterval == NULL)
	{
		HMODULE gl = GetModuleHandleA("opengl32.dll");
		if (gl == NULL) return false;
		MuttGetProcAddressProc getProc = (MuttGetProcAddressProc)GetProcAddress(gl, "wglGetProcAddress");
		if (getProc == NULL) return false;
		muttSwapInterval = (MuttSwapIntervalProc)getProc("wglSwapIntervalEXT");
		if (muttSwapInterval == NULL) return false;
	}
	return muttSwapInterval(interval) != FALSE;
}
')
#end
class DisplaySettings
{
	public static final RESOLUTIONS:Array<String> = ['Fullscreen', 'Borderless', 'Windowed'];
	static inline final UNLOCKED_FRAMERATE:Int = 1000;

	static var currentMode:String = 'Windowed';
	static var lastWindowMode:String = 'Windowed';
	static var windowedRect:Array<Int> = null;
	static var initialized:Bool = false;
	static var borderlessFrames:Int = 0;
	static inline final BORDERLESS_SETTLE_FRAMES:Int = 5;

	public static function apply()
	{
		if(!initialized)
		{
			initialized = true;
			window().onKeyDown.add(onWindowKeyDown, false, 1000);
			window().onRestore.add(onWindowRestore);
			FlxG.signals.postUpdate.add(syncFullscreen);
		}
		applyFramerate();
		applyResolution();
		applyVSync();
	}

	public static function applyFramerate()
	{
		var target:Int = ClientPrefs.data.unlockedFramerate ? UNLOCKED_FRAMERATE : ClientPrefs.data.framerate;
		if(target > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = target;
			FlxG.drawFramerate = target;
		}
		else
		{
			FlxG.drawFramerate = target;
			FlxG.updateFramerate = target;
		}
	}

	public static function applyVSync():Bool
	{
		#if (cpp && windows)
		var enabled:Bool = ClientPrefs.data.vsync;
		return untyped __cpp__('muttSetSwapInterval({0} ? 1 : 0)', enabled);
		#else
		return false;
		#end
	}

	public static function applyResolution()
	{
		var mode:String = ClientPrefs.data.resolution;
		if(!RESOLUTIONS.contains(mode)) mode = 'Windowed';
		if(mode == currentMode) return;

		leaveMode(currentMode);
		enterMode(mode);
		currentMode = mode;
		if(mode != 'Fullscreen') lastWindowMode = mode;
		applyVSync();
	}

	public static function toggleFullscreen()
	{
		ClientPrefs.data.resolution = (currentMode == 'Fullscreen') ? lastWindowMode : 'Fullscreen';
		applyResolution();
		ClientPrefs.saveSettings();
	}

	static function leaveMode(mode:String)
	{
		var win:Window = window();
		switch(mode)
		{
			case 'Fullscreen':
				FlxG.fullscreen = false;
				win.fullscreen = false;
			case 'Borderless':
				win.borderless = false;
				restoreWindowedRect();
			default:
				windowedRect = [win.x, win.y, win.width, win.height];
		}
	}

	static function enterMode(mode:String)
	{
		var win:Window = window();
		switch(mode)
		{
			case 'Fullscreen':
				FlxG.fullscreen = true;
			case 'Borderless':
				win.borderless = true;
				fitBorderless();
				borderlessFrames = BORDERLESS_SETTLE_FRAMES;
			default:
				restoreWindowedRect();
		}
	}

	static function fitBorderless()
	{
		var win:Window = window();
		var bounds = win.display.bounds;
		win.resize(Std.int(bounds.width), Std.int(bounds.height) + 1);
		win.move(Std.int(bounds.x), Std.int(bounds.y));
	}

	static function restoreWindowedRect()
	{
		if(windowedRect == null) return;
		var win:Window = window();
		win.resize(windowedRect[2], windowedRect[3]);
		win.move(windowedRect[0], windowedRect[1]);
	}

	static function onWindowKeyDown(key:KeyCode, modifier:KeyModifier)
	{
		if(key == RETURN && modifier.altKey && !modifier.ctrlKey && !modifier.shiftKey && !modifier.metaKey)
		{
			window().onKeyDown.cancel();
			toggleFullscreen();
		}
	}

	static function onWindowRestore()
	{
		if(currentMode == 'Fullscreen') FlxG.fullscreen = true;
	}

	static function syncFullscreen()
	{
		if(borderlessFrames > 0)
		{
			borderlessFrames--;
			if(currentMode == 'Borderless') fitBorderless();
		}
		if(window().minimized || FlxG.fullscreen == (currentMode == 'Fullscreen')) return;
		currentMode = FlxG.fullscreen ? 'Fullscreen' : lastWindowMode;
		ClientPrefs.data.resolution = currentMode;
	}

	static inline function window():Window
		return lime.app.Application.current.window;
}
