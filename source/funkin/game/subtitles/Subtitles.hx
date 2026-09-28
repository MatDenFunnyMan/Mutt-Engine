package funkin.game.subtitles;

import funkin.game.subtitles.SubtitleData.SubtitleLine;

typedef SubtitleEntry = {
	var text:FlxText;
	var box:FlxSprite;
}

class Subtitles extends FlxSpriteGroup
{
	public static inline final PADDING:Float = 6;

	public var data(default, null):SubtitleData;
	public var timeSource:Void->Float;
	public var margin:Float;
	public var alignTop:Bool;
	public var ignorePreference:Bool = false;

	public var clock:Float = 0;

	var shown:Array<SubtitleLine> = [];
	var entries:Map<SubtitleLine, SubtitleEntry> = new Map();

	public function new(margin:Float = 42, alignTop:Bool = false)
	{
		super();
		this.margin = margin;
		this.alignTop = alignTop;
		scrollFactor.set();
	}

	public function prepare(data:SubtitleData):Subtitles
	{
		if(data == null) return this;
		for (line in data.lines)
			if(line.text.length > 0 && !entries.exists(line))
				entries.set(line, makeEntry(data, line));
		return this;
	}

	public function play(data:SubtitleData, ?timeSource:Void->Float):Subtitles
	{
		prepare(data);
		this.data = data;
		this.timeSource = timeSource;
		clock = 0;
		hideLines();
		return this;
	}

	public static function soundClock(sound:FlxSound):Void->Float
		return () -> (sound != null && (sound.playing || sound.time > 0)) ? sound.time : -1;

	public function stop()
	{
		data = null;
		timeSource = null;
		hideLines();
	}

	public var playing(get, never):Bool;
	function get_playing():Bool
		return data != null;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(data == null || (!ignorePreference && !ClientPrefs.data.subtitles))
		{
			if(shown.length > 0) hideLines();
			return;
		}

		clock += elapsed * 1000;
		var time:Float = timeSource != null ? timeSource() : clock;
		if(!sameLines(time)) showLines(data.activeLines(time));
	}

	function sameLines(time:Float):Bool
	{
		var index:Int = 0;
		for (line in data.lines)
		{
			if(!line.activeAt(time)) continue;
			if(index >= shown.length || shown[index] != line) return false;
			index++;
		}
		return index == shown.length;
	}

	function hideLines()
	{
		for (line in shown)
		{
			var entry:SubtitleEntry = entries.get(line);
			if(entry == null) continue;
			entry.text.visible = false;
			if(entry.box != null) entry.box.visible = false;
		}
		shown = [];
	}

	function showLines(active:Array<SubtitleLine>)
	{
		hideLines();
		shown = active;

		var stacked:Float = 0;
		for (line in active)
		{
			var entry:SubtitleEntry = entries.get(line);
			if(entry == null) entries.set(line, entry = makeEntry(data, line));

			var text:FlxText = entry.text;
			var boxWidth:Float = entry.box != null ? entry.box.width : text.width;
			var boxHeight:Float = entry.box != null ? entry.box.height : text.height;

			var posX:Null<Float> = data.styleOf(line, 'x');
			var posY:Null<Float> = data.styleOf(line, 'y');
			var centerX:Float = posX != null ? posX : FlxG.width / 2;
			var centerY:Float;
			if(posY != null) centerY = posY;
			else
			{
				var half:Float = boxHeight / 2;
				centerY = alignTop ? margin + stacked + half : FlxG.height - margin - stacked - half;
				stacked += boxHeight;
			}

			if(entry.box != null)
			{
				entry.box.setPosition(centerX - boxWidth / 2, centerY - boxHeight / 2);
				entry.box.visible = true;
			}
			text.setPosition(centerX - text.width / 2, centerY - text.height / 2);
			text.visible = true;
		}
	}

	function makeEntry(data:SubtitleData, line:SubtitleLine):SubtitleEntry
	{
		var text:FlxText = makeText(data, line);
		var box:FlxSprite = makeBox(data, line, text);
		if(box.alpha > 0)
		{
			box.visible = false;
			add(box);
		}
		else
		{
			box.destroy();
			box = null;
		}
		text.visible = false;
		add(text);
		return {text: text, box: box};
	}

	function makeText(data:SubtitleData, line:SubtitleLine):FlxText
	{
		var text:FlxText = new FlxText(0, 0, 0, line.text.replace('\\n', '\n'), data.styleOf(line, 'size'));
		text.setFormat(Paths.font(data.styleOf(line, 'font')), data.styleOf(line, 'size'), colorOf(data.styleOf(line, 'color'), FlxColor.WHITE), CENTER);

		var outline:Float = data.styleOf(line, 'outline');
		if(outline > 0)
		{
			text.borderStyle = OUTLINE;
			text.borderColor = colorOf(data.styleOf(line, 'outlineColor'), FlxColor.BLACK);
			text.borderSize = outline;
		}

		var scale:Array<Float> = data.styleOf(line, 'scale');
		if(scale != null && scale.length > 0) text.scale.set(scale[0], scale.length > 1 ? scale[1] : scale[0]);
		text.updateHitbox();
		text.scrollFactor.set();
		text.antialiasing = ClientPrefs.data.antialiasing;
		text.drawFrame(true);
		return text;
	}

	function makeBox(data:SubtitleData, line:SubtitleLine, text:FlxText):FlxSprite
	{
		var box:FlxSprite = new FlxSprite().makeGraphic(1, 1, colorOf(data.styleOf(line, 'backgroundColor'), FlxColor.BLACK));
		box.scale.set(Math.ceil(text.width + PADDING * 2), Math.ceil(text.height + PADDING));
		box.updateHitbox();
		box.alpha = data.styleOf(line, 'background');
		box.scrollFactor.set();
		return box;
	}

	static function colorOf(value:Dynamic, fallback:FlxColor):FlxColor
	{
		if(value == null) return fallback;
		if(value is Int) return value;
		var color:Null<FlxColor> = FlxColor.fromString(Std.string(value));
		return color != null ? color : fallback;
	}

	override function destroy()
	{
		data = null;
		timeSource = null;
		shown = [];
		entries = null;
		super.destroy();
	}
}
