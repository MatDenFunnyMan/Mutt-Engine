package funkin.backend.vfs;

#if sys
import openfl.utils.Assets as OpenFlAssets;
import openfl.display.BitmapData;
import openfl.media.Sound;
import haxe.io.Bytes;

class EmbeddedFiles
{
	public static inline final ROOT:String = 'assets/embed/';

	static var files:Map<String, String> = null;
	static var folders:Map<String, Array<String>> = null;
	static var cwd:String = null;

	static function index()
	{
		if(files != null) return;
		files = [];
		folders = [];
		cwd = Sys.getCwd().replace('\\', '/');
		if(!cwd.endsWith('/')) cwd += '/';

		var library = lime.utils.Assets.getLibrary('default');
		if(library == null) return;
		var embedded:Array<String> = [];
		@:privateAccess for (id in library.classTypes.keys()) embedded.push(id);
		for (id in embedded)
		{
			if(!id.startsWith(ROOT)) continue;
			var path:String = 'assets/' + id.substr(ROOT.length);
			files.set(path.toLowerCase(), id);
			for (alias in [path, path.toLowerCase()])
			{
				@:privateAccess if(!library.types.exists(alias))
				{
					library.classTypes.set(alias, library.classTypes.get(id));
					library.types.set(alias, library.types.get(id));
				}
			}

			var parts:Array<String> = path.split('/');
			var parent:String = parts[0];
			for (i in 1...parts.length)
			{
				var list:Array<String> = folders.get(parent.toLowerCase());
				if(list == null)
				{
					list = [];
					folders.set(parent.toLowerCase(), list);
				}
				if(!list.contains(parts[i])) list.push(parts[i]);
				parent += '/' + parts[i];
			}
		}
	}

	public static function init()
		index();

	static function key(path:String):String
	{
		if(path == null) return null;
		index();
		var result:String = path.replace('\\', '/');
		while(result.startsWith('./')) result = result.substr(2);
		if(result.toLowerCase().startsWith(cwd.toLowerCase())) result = result.substr(cwd.length);
		while(result.endsWith('/')) result = result.substr(0, result.length - 1);
		return result.toLowerCase();
	}

	static function assetId(path:String):String
	{
		var k:String = key(path);
		return (k != null) ? files.get(k) : null;
	}

	public static function hasFile(path:String):Bool
		return assetId(path) != null;

	public static function hasFolder(path:String):Bool
	{
		var k:String = key(path);
		return k != null && folders.exists(k);
	}

	public static function children(path:String):Array<String>
	{
		var k:String = key(path);
		return (k != null && folders.exists(k)) ? folders.get(k).copy() : [];
	}

	public static function getBytes(path:String):Bytes
		return OpenFlAssets.getBytes(assetId(path));

	public static function getText(path:String):String
		return OpenFlAssets.getText(assetId(path));

	static inline function onlyEmbedded(path:String):Bool
		return !sys.FileSystem.exists(path) && hasFile(path);

	public static function readableAsset(path:String):String
		return (path != null && onlyEmbedded(path)) ? getText(path) : path;

	public static function loadBitmap(path:String):BitmapData
	{
		if(onlyEmbedded(path)) return OpenFlAssets.getBitmapData(assetId(path), false);
		return BitmapData.fromFile(path);
	}

	public static function loadSound(path:String):Sound
	{
		if(onlyEmbedded(path)) return OpenFlAssets.getSound(assetId(path), false);
		return Sound.fromFile(path);
	}

	#if LUA_ALLOWED
	public static function runLua(lua:llua.State, path:String):Int
	{
		if(onlyEmbedded(path)) return llua.LuaL.dostring(lua, getText(path));
		return llua.LuaL.dofile(lua, path);
	}
	#end
}
#end
