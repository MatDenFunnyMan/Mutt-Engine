package funkin.game.subtitles;

import haxe.Json;

typedef SubtitleStyle = {
	@:optional var font:String;
	@:optional var size:Null<Int>;
	@:optional var color:String;
	@:optional var x:Null<Float>;
	@:optional var y:Null<Float>;
	@:optional var scale:Array<Float>;
	@:optional var background:Null<Float>;
	@:optional var backgroundColor:String;
	@:optional var outline:Null<Float>;
	@:optional var outlineColor:String;
}

class SubtitleLine
{
	public var text:String;
	public var start:Float;
	public var end:Float;
	public var style:SubtitleStyle;

	public function new(text:String, start:Float, end:Float, ?style:SubtitleStyle)
	{
		this.text = text;
		this.start = start;
		this.end = end;
		this.style = style != null ? style : {};
	}

	public inline function activeAt(time:Float):Bool
		return time >= start && time <= end && text.length > 0;
}

class SubtitleData
{
	public static final DEFAULT_STYLE:SubtitleStyle = {
		font: 'vcr.ttf',
		size: 30,
		color: '#FFFFFF',
		scale: [1, 1],
		background: 0.5,
		backgroundColor: '#080808',
		outline: 0,
		outlineColor: '#000000'
	};

	public static final STYLE_FIELDS:Array<String> = ['font', 'size', 'color', 'x', 'y', 'scale', 'background', 'backgroundColor', 'outline', 'outlineColor'];
	public static final EXTENSIONS:Array<String> = ['json', 'srt'];

	public var lines:Array<SubtitleLine> = [];
	public var censors:Array<{start:Float, end:Float}> = [];
	public var style:SubtitleStyle = {};
	public var path:String = null;

	public function new() {}

	public static function load(key:String):SubtitleData
	{
		var file:String = find(key);
		return file != null ? fromFullPath(file) : null;
	}

	public static function find(key:String):String
	{
		if(key == null) return null;

		for (candidate in funkin.backend.Naughtyness.candidates(key))
		{
			for (ext in EXTENSIONS)
			{
				var path:String = Paths.getPath('data/$candidate.$ext', TEXT);
				if(Paths.assetExists(path)) return path;
			}
		}
		return null;
	}

	public static function findNextTo(file:String):SubtitleData
	{
		if(file == null) return null;

		var dot:Int = file.lastIndexOf('.');
		var base:String = dot > file.lastIndexOf('/') ? file.substr(0, dot) : file;
		for (candidate in funkin.backend.Naughtyness.candidates(base))
			for (ext in EXTENSIONS)
				if(Paths.assetExists('$candidate.$ext')) return fromFullPath('$candidate.$ext');
		return null;
	}

	public static function fromFullPath(path:String):SubtitleData
	{
		var raw:String = funkin.backend.Naughtyness.readFile(path);
		if(raw == null) return null;

		var data:SubtitleData = parse(raw, path);
		if(data != null) data.path = path;
		return data;
	}

	public static function parse(raw:String, ?fileName:String):SubtitleData
	{
		if(raw == null || raw.trim().length < 1) return null;
		try
		{
			if(fileName != null && fileName.toLowerCase().endsWith('.srt')) return parseSrt(raw);
			return parseJson(raw);
		}
		catch(e:Dynamic)
		{
			trace('Could not read subtitles $fileName: $e');
		}
		return null;
	}

	public static function parseJson(raw:String):SubtitleData
	{
		var json:Dynamic = Json.parse(raw);
		var data:SubtitleData = new SubtitleData();
		data.style = readStyle(json);

		var list:Array<Dynamic> = Reflect.field(json, 'subtitles');
		if(list == null) return data;

		for (entry in list)
		{
			if(entry == null || Reflect.field(entry, 'text') == null) continue;
			var start:Float = parseTime(Reflect.field(entry, 'start'));
			var end:Float = parseTime(Reflect.field(entry, 'end'));
			if(start < 0 || end < start) continue;
			data.lines.push(new SubtitleLine(Std.string(Reflect.field(entry, 'text')), start, end, readStyle(entry)));
		}
		data.lines.sort((a, b) -> a.start < b.start ? -1 : (a.start > b.start ? 1 : 0));

		var censorList:Array<Dynamic> = Reflect.field(json, 'censor');
		if(censorList != null)
		{
			for (entry in censorList)
			{
				var start:Float = parseTime(Reflect.field(entry, 'start'));
				var end:Float = parseTime(Reflect.field(entry, 'end'));
				if(start >= 0 && end > start) data.censors.push({start: start, end: end});
			}
			data.censors.sort((a, b) -> a.start < b.start ? -1 : (a.start > b.start ? 1 : 0));
		}
		return data;
	}

	public function censorAt(time:Float):Int
	{
		for (i in 0...censors.length) if(time >= censors[i].start && time < censors[i].end) return i;
		return -1;
	}

	public static function parseSrt(raw:String):SubtitleData
	{
		var data:SubtitleData = new SubtitleData();
		var normalized:String = raw.replace('\r\n', '\n').replace('\r', '\n');
		if(normalized.length > 0 && normalized.charCodeAt(0) == 0xFEFF) normalized = normalized.substr(1);

		for (block in normalized.split('\n\n'))
		{
			var blockLines:Array<String> = block.trim().split('\n');
			var index:Int = 0;
			while(index < blockLines.length && blockLines[index].indexOf('-->') < 0) index++;
			if(index >= blockLines.length) continue;

			var times:Array<String> = blockLines[index].split('-->');
			var start:Float = parseTime(times[0]);
			var end:Float = parseTime(times[1]);
			if(start < 0 || end < start) continue;

			var text:String = blockLines.slice(index + 1).join('\n');
			data.lines.push(new SubtitleLine(text, start, end));
		}
		data.lines.sort((a, b) -> a.start < b.start ? -1 : (a.start > b.start ? 1 : 0));
		return data;
	}

	public static function parseTime(value:Dynamic):Float
	{
		if(value == null) return -1;
		if(value is Int || value is Float) return value * 1000;

		var clean:String = Std.string(value).trim().replace(',', '.');
		if(clean.length < 1) return -1;

		var seconds:Float = 0;
		for (part in clean.split(':'))
		{
			var parsed:Float = Std.parseFloat(part);
			if(Math.isNaN(parsed)) return -1;
			seconds = seconds * 60 + parsed;
		}
		return seconds * 1000;
	}

	static function readStyle(source:Dynamic):SubtitleStyle
	{
		var style:SubtitleStyle = {};
		if(source == null) return style;
		for (field in STYLE_FIELDS)
			if(Reflect.hasField(source, field)) Reflect.setField(style, field, Reflect.field(source, field));
		return style;
	}

	public function styleOf(line:SubtitleLine, field:String):Dynamic
	{
		var value:Dynamic = Reflect.field(line.style, field);
		if(value == null) value = Reflect.field(style, field);
		if(value == null) value = Reflect.field(DEFAULT_STYLE, field);
		return value;
	}

	public function activeLines(time:Float):Array<SubtitleLine>
		return [for (line in lines) if(line.activeAt(time)) line];

	public function endTime():Float
	{
		var last:Float = 0;
		for (line in lines) if(line.end > last) last = line.end;
		return last;
	}
}
