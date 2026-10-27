package funkin.backend.vfs;

#if sys
class FileSystem
{
	public static function exists(path:String):Bool
		return sys.FileSystem.exists(path) || EmbeddedFiles.hasFile(path) || EmbeddedFiles.hasFolder(path);

	public static function isDirectory(path:String):Bool
	{
		if(sys.FileSystem.exists(path)) return sys.FileSystem.isDirectory(path);
		return EmbeddedFiles.hasFolder(path);
	}

	public static function readDirectory(path:String):Array<String>
	{
		var list:Array<String> = (sys.FileSystem.exists(path) && sys.FileSystem.isDirectory(path)) ? sys.FileSystem.readDirectory(path) : [];
		for (name in EmbeddedFiles.children(path))
			if(!list.contains(name)) list.push(name);
		return list;
	}

	public static inline function createDirectory(path:String):Void
		sys.FileSystem.createDirectory(path);

	public static inline function deleteFile(path:String):Void
		sys.FileSystem.deleteFile(path);

	public static inline function deleteDirectory(path:String):Void
		sys.FileSystem.deleteDirectory(path);

	public static inline function rename(path:String, newPath:String):Void
		sys.FileSystem.rename(path, newPath);

	public static inline function absolutePath(relPath:String):String
		return sys.FileSystem.absolutePath(relPath);

	public static inline function fullPath(relPath:String):String
		return sys.FileSystem.fullPath(relPath);

	public static inline function stat(path:String):sys.FileStat
		return sys.FileSystem.stat(path);
}
#end
