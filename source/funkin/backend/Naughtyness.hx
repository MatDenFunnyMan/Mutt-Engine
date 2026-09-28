package funkin.backend;

import openfl.utils.Assets as OpenFlAssets;

class Naughtyness
{
	public static final SAFE_SUFFIXES:Array<String> = ['-censored', '_safe'];

	public static var enabled(get, never):Bool;
	static function get_enabled():Bool
		return ClientPrefs.data.naughtyness;

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
