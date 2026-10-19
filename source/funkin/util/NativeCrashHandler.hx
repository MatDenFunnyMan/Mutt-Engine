package funkin.util;

import lime.media.AudioSource;

#if (cpp && windows)
@:buildXml('
<target id="haxe">
	<lib name="dbghelp.lib" if="windows"/>
	<lib name="user32.lib" if="windows"/>
</target>
')
@:cppFileCode('
#include <windows.h>
#include <dbghelp.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>

static DWORD mutt_mainThreadId = 0;
static ULONGLONG mutt_startTick = 0;
static ULONGLONG mutt_audioSwitchTick = 0;
static int mutt_audioSwitches = 0;
static char mutt_state[160] = "unknown";
static char mutt_song[160] = "none";
static double mutt_songPosition = -1;
static int mutt_activeSounds = 0;
static volatile LONG mutt_crashed = 0;
static char mutt_report[16384];

static void mutt_append(size_t* used, const char* format, ...)
{
	if (*used >= sizeof(mutt_report) - 1) return;
	va_list args;
	va_start(args, format);
	int written = vsnprintf(mutt_report + *used, sizeof(mutt_report) - *used, format, args);
	va_end(args);
	if (written > 0) *used += (size_t)written;
	if (*used > sizeof(mutt_report) - 1) *used = sizeof(mutt_report) - 1;
}

static void mutt_describe(DWORD64 address, char* out, size_t size)
{
	HMODULE module = NULL;
	char path[MAX_PATH] = "?";
	if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR)address, &module) && module)
	{
		GetModuleFileNameA(module, path, MAX_PATH);
		const char* name = strrchr(path, \'\\\\\');
		snprintf(out, size, "%s+0x%llx", name ? name + 1 : path, (unsigned long long)(address - (DWORD64)module));
	}
	else snprintf(out, size, "0x%llx", (unsigned long long)address);
}

static const char* mutt_exceptionName(DWORD code)
{
	switch (code)
	{
		case EXCEPTION_ACCESS_VIOLATION: return "ACCESS_VIOLATION";
		case EXCEPTION_STACK_OVERFLOW: return "STACK_OVERFLOW";
		case EXCEPTION_INT_DIVIDE_BY_ZERO: return "INT_DIVIDE_BY_ZERO";
		case EXCEPTION_ILLEGAL_INSTRUCTION: return "ILLEGAL_INSTRUCTION";
		case EXCEPTION_IN_PAGE_ERROR: return "IN_PAGE_ERROR";
		case EXCEPTION_PRIV_INSTRUCTION: return "PRIV_INSTRUCTION";
		case 0xC0000374: return "HEAP_CORRUPTION";
		case 0xC0000409: return "STACK_BUFFER_OVERRUN";
		default: return "UNKNOWN";
	}
}

static void mutt_writeStack(size_t* used, CONTEXT* source)
{
#if defined(_M_X64)
	CONTEXT context = *source;
	__try
	{
		for (int i = 0; i < 32 && context.Rip != 0; i++)
		{
			char frame[MAX_PATH + 32];
			mutt_describe(context.Rip, frame, sizeof(frame));
			mutt_append(used, "  %s\\r\\n", frame);

			DWORD64 imageBase = 0;
			PRUNTIME_FUNCTION function = RtlLookupFunctionEntry(context.Rip, &imageBase, NULL);
			if (function == NULL)
			{
				context.Rip = *(DWORD64*)context.Rsp;
				context.Rsp += 8;
			}
			else
			{
				PVOID handlerData = NULL;
				DWORD64 establisherFrame = 0;
				RtlVirtualUnwind(UNW_FLAG_NHANDLER, imageBase, context.Rip, function, &context, &handlerData, &establisherFrame, NULL);
			}
		}
	}
	__except (EXCEPTION_EXECUTE_HANDLER)
	{
		mutt_append(used, "  (stack ends here)\\r\\n");
	}
#endif
}

static LONG WINAPI mutt_onNativeCrash(EXCEPTION_POINTERS* info)
{
	if (InterlockedExchange(&mutt_crashed, 1) != 0) return EXCEPTION_CONTINUE_SEARCH;

	EXCEPTION_RECORD* record = info->ExceptionRecord;
	SYSTEMTIME now;
	GetLocalTime(&now);
	ULONGLONG tick = GetTickCount64();
	size_t used = 0;
	mutt_report[0] = 0;

	char where[MAX_PATH + 32];
	mutt_describe((DWORD64)record->ExceptionAddress, where, sizeof(where));

	mutt_append(&used, "Mutt Engine native crash\\r\\n");
	mutt_append(&used, "Date: %04d-%02d-%02d %02d:%02d:%02d\\r\\n", now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond);
	mutt_append(&used, "Exception: 0x%08lX (%s)\\r\\n", record->ExceptionCode, mutt_exceptionName(record->ExceptionCode));
	mutt_append(&used, "Address: %s\\r\\n", where);
	if (record->ExceptionCode == EXCEPTION_ACCESS_VIOLATION && record->NumberParameters >= 2)
	{
		ULONG_PTR kind = record->ExceptionInformation[0];
		mutt_append(&used, "Access: %s at 0x%llx\\r\\n", kind == 0 ? "read" : (kind == 1 ? "write" : "execute"), (unsigned long long)record->ExceptionInformation[1]);
	}
	if (GetCurrentThreadId() == mutt_mainThreadId) mutt_append(&used, "Thread: main (game)\\r\\n");
	else mutt_append(&used, "Thread: background (id %lu)\\r\\n", GetCurrentThreadId());
	mutt_append(&used, "Uptime: %.1f s\\r\\n", (tick - mutt_startTick) / 1000.0);
	mutt_append(&used, "\\r\\nState: %s\\r\\n", mutt_state);
	mutt_append(&used, "Song: %s\\r\\n", mutt_song);
	if (mutt_songPosition >= 0) mutt_append(&used, "Song position: %.0f ms\\r\\n", mutt_songPosition);
	mutt_append(&used, "Active sounds: %d\\r\\n", mutt_activeSounds);
	if (mutt_audioSwitches > 0) mutt_append(&used, "Audio device switches: %d (last %.1f s before the crash)\\r\\n", mutt_audioSwitches, (tick - mutt_audioSwitchTick) / 1000.0);
	else mutt_append(&used, "Audio device switches: 0\\r\\n");
	mutt_append(&used, "\\r\\nStack:\\r\\n");
	mutt_writeStack(&used, info->ContextRecord);

	CreateDirectoryA("crash", NULL);
	char base[MAX_PATH];
	snprintf(base, sizeof(base), "crash\\\\MuttEngine_native_%04d-%02d-%02d_%02d-%02d-%02d", now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond);

	char path[MAX_PATH];
	snprintf(path, sizeof(path), "%s.txt", base);
	HANDLE text = CreateFileA(path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
	if (text != INVALID_HANDLE_VALUE)
	{
		DWORD written = 0;
		WriteFile(text, mutt_report, (DWORD)used, &written, NULL);
		CloseHandle(text);
	}

	char dumpPath[MAX_PATH];
	snprintf(dumpPath, sizeof(dumpPath), "%s.dmp", base);
	HANDLE dump = CreateFileA(dumpPath, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
	if (dump != INVALID_HANDLE_VALUE)
	{
		MINIDUMP_EXCEPTION_INFORMATION exceptionInfo;
		exceptionInfo.ThreadId = GetCurrentThreadId();
		exceptionInfo.ExceptionPointers = info;
		exceptionInfo.ClientPointers = FALSE;
		MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), dump, (MINIDUMP_TYPE)(MiniDumpWithThreadInfo | MiniDumpWithIndirectlyReferencedMemory), &exceptionInfo, NULL, NULL);
		CloseHandle(dump);
	}

	char message[MAX_PATH * 2 + 256];
	snprintf(message, sizeof(message), "Mutt Engine has encountered a FATAL ERROR (%s)\\n\\nCrash report saved to:\\n%s\\n%s", where, path, dumpPath);
	MessageBoxA(NULL, message, "Mutt Engine", MB_OK | MB_ICONERROR | MB_SYSTEMMODAL);
	return EXCEPTION_CONTINUE_SEARCH;
}

static void mutt_copy(char* target, size_t size, const char* value)
{
	if (value == NULL) value = "";
	strncpy(target, value, size - 1);
	target[size - 1] = 0;
}
')
#end
class NativeCrashHandler
{
	static var lastSong:String = null;

	public static function init():Void
	{
		#if (cpp && windows)
		untyped __cpp__('mutt_mainThreadId = GetCurrentThreadId(); mutt_startTick = GetTickCount64(); SetUnhandledExceptionFilter(mutt_onNativeCrash);');
		FlxG.signals.postStateSwitch.add(onStateSwitch);
		FlxG.signals.postUpdate.add(update);
		onStateSwitch();
		#end
	}

	public static function markAudioSwitch():Void
	{
		#if (cpp && windows)
		untyped __cpp__('mutt_audioSwitchTick = GetTickCount64(); mutt_audioSwitches++;');
		#end
	}

	static function onStateSwitch():Void
	{
		#if (cpp && windows)
		var name:String = FlxG.state != null ? Type.getClassName(Type.getClass(FlxG.state)) : 'none';
		if(name == null) name = 'unknown';
		untyped __cpp__('mutt_copy(mutt_state, sizeof(mutt_state), {0}.utf8_str())', name);
		#end
	}

	static function update():Void
	{
		#if (cpp && windows)
		var song:String = null;
		var position:Float = -1;
		if(Std.isOfType(FlxG.state, funkin.game.states.PlayState) && funkin.game.states.PlayState.SONG != null)
		{
			song = funkin.game.states.PlayState.SONG.song;
			position = Conductor.songPosition;
		}
		if(song != lastSong)
		{
			lastSong = song;
			untyped __cpp__('mutt_copy(mutt_song, sizeof(mutt_song), {0}.utf8_str())', song != null ? song : 'none');
		}
		var sounds:Int = @:privateAccess AudioSource.activeSources.length;
		untyped __cpp__('mutt_songPosition = {0}; mutt_activeSounds = {1};', position, sounds);
		#end
	}
}
