package funkin.util;

import haxe.PosInfos;

enum abstract Severity(Int) to Int
{
	var PRINT;
	var WARN;
	var ERROR;
	var NOTICE;

	public function toString():String
	{
		return switch(cast this : Severity)
		{
			case WARN: '[WARN] ';
			case ERROR: '[ERROR] ';
			case NOTICE: '[NOTICE] ';
			default: '[LOG] ';
		}
	}
}

class Logger
{
	public static var DUMP_FOLDER:String = './crash/';

	public static function log(data:Dynamic, severity:Severity = PRINT, ?pos:PosInfos)
	{
		#if FLX_DEBUG
		switch(severity)
		{
			case ERROR: FlxG.log.error(data);
			case WARN: FlxG.log.warn(data);
			case NOTICE: FlxG.log.notice(data);
			case PRINT:
		}
		#end

		var output:String = severity.toString() + haxe.Log.formatOutput(data, pos);

		#if sys
		Sys.println(output);
		#else
		trace(output);
		#end
	}

	public static function warn(data:Dynamic, ?pos:PosInfos)
		log(data, WARN, pos);

	public static function error(data:Dynamic, ?pos:PosInfos)
		log(data, ERROR, pos);

	public static function notice(data:Dynamic, ?pos:PosInfos)
		log(data, NOTICE, pos);

	public static function colorOf(severity:Severity):FlxColor
	{
		return switch(severity)
		{
			case ERROR: 0xFFFF4040;
			case WARN: FlxColor.YELLOW;
			case NOTICE: FlxColor.LIME;
			default: FlxColor.WHITE;
		}
	}

	public static function sanitize(name:String):String
	{
		return ~/[\\\/:*?"<>|]/g.replace(name, '_');
	}

	public static function timestamp():String
		return sanitize(Date.now().toString()).replace(' ', '_');

	public static function writeDump(content:String, fileName:String, ?folder:String):String
	{
		#if sys
		if(folder == null) folder = DUMP_FOLDER;

		try
		{
			if(!FileSystem.exists(folder)) FileSystem.createDirectory(folder);

			var path:String = haxe.io.Path.join([folder, fileName + '_' + timestamp() + '.txt']);
			File.saveContent(path, content);
			return path;
		}
		catch(e:Dynamic) {}
		#end

		return null;
	}
}
