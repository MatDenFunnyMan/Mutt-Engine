package funkin.backend;

import openfl.utils.Assets as OpenFlAssets;

class Naughtyness
{
	public static final SAFE_SUFFIXES:Array<String> = ['-censored', '_safe'];

	public static var enabled(get, never):Bool;
	static function get_enabled():Bool
		return ClientPrefs.data.naughtyness;

	public static inline final UH_OH_SOUND:String = 'uh-oh';
	public static inline final UH_OH_MIN_PITCH:Float = 0.93;
	public static inline final UH_OH_MAX_PITCH:Float = 1.07;

	public static function playUhOh(volume:Float = 1):FlxSound
	{
		var sound:FlxSound = FlxG.sound.play(Paths.sound(UH_OH_SOUND), volume);
		sound.pitch = FlxG.random.float(UH_OH_MIN_PITCH, UH_OH_MAX_PITCH);
		return sound;
	}

	public static function soundKey(key:String):String
	{
		for (candidate in candidates(key)) if(soundExists(candidate)) return candidate;
		return key;
	}

	public static function soundExists(key:String):Bool
	{
		var file:String = Paths.getPath('sounds/$key.${Paths.SOUND_EXT}', SOUND);
		#if sys
		if(FileSystem.exists(file)) return true;
		#end
		return Paths.assetExists(file);
	}

	public static function sound(key:String):openfl.media.Sound
		return Paths.sound(soundKey(key));

	public static function candidates(key:String):Array<String>
	{
		if(enabled) return [key];
		return [for (suffix in SAFE_SUFFIXES) key + suffix].concat([key]);
	}

	public static function safePath(path:String):String
	{
		if(enabled || path == null) return path;

		var dot:Int = path.lastIndexOf('.');
		var hasExt:Bool = dot > path.lastIndexOf('/');
		var base:String = hasExt ? path.substr(0, dot) : path;
		var ext:String = hasExt ? path.substr(dot) : '';
		for (suffix in SAFE_SUFFIXES)
			if(Paths.assetExists(base + suffix + ext)) return base + suffix + ext;
		return path;
	}

	public static function readFile(path:String):String
	{
		if(path == null) return null;
		#if sys
		if(FileSystem.exists(path)) return File.getContent(path);
		#end
		return OpenFlAssets.exists(path, TEXT) ? OpenFlAssets.getText(path) : null;
	}
}
