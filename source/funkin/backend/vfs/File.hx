package funkin.backend.vfs;

#if sys
import haxe.io.Bytes;

class File
{
	public static function getContent(path:String):String
	{
		if(!sys.FileSystem.exists(path) && EmbeddedFiles.hasFile(path)) return EmbeddedFiles.getBytes(path).toString();
		return sys.io.File.getContent(path);
	}

	public static function getBytes(path:String):Bytes
	{
		if(!sys.FileSystem.exists(path) && EmbeddedFiles.hasFile(path)) return EmbeddedFiles.getBytes(path);
		return sys.io.File.getBytes(path);
	}

	public static inline function saveContent(path:String, content:String):Void
		sys.io.File.saveContent(path, content);

	public static inline function saveBytes(path:String, bytes:Bytes):Void
		sys.io.File.saveBytes(path, bytes);

	public static inline function read(path:String, binary:Bool = true):sys.io.FileInput
		return sys.io.File.read(path, binary);

	public static inline function write(path:String, binary:Bool = true):sys.io.FileOutput
		return sys.io.File.write(path, binary);

	public static inline function append(path:String, binary:Bool = true):sys.io.FileOutput
		return sys.io.File.append(path, binary);

	public static inline function update(path:String, binary:Bool = true):sys.io.FileOutput
		return sys.io.File.update(path, binary);

	public static inline function copy(srcPath:String, dstPath:String):Void
		sys.io.File.copy(srcPath, dstPath);
}
#end
