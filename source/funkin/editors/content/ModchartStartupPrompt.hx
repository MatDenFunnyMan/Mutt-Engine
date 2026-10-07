package funkin.editors.content;

import funkin.editors.content.Prompt.BasePrompt;

class ModchartStartupPrompt extends BasePrompt
{
	public static function addDim(prompt:BasePrompt)
	{
		var dim:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		dim.scale.set(FlxG.width, FlxG.height);
		dim.updateHitbox();
		dim.alpha = 0.6;
		dim.cameras = prompt.cameras;
		prompt.insert(0, dim);
	}

	public var onOpenRecent:Int->Void;
	public var onFromSong:Void->Void;

	static inline final PAD:Int = 20;
	static inline final COL_W:Int = 310;

	var recentLabels:Array<String> = [];
	var recentList:AnimScrollList;
	var recentHint:FlxText;
	var currentSong:String;

	public function new(currentSong:String)
	{
		this.currentSong = currentSong;
		super(680, 420, 'Modchart Editor');
	}

	override function create()
	{
		super.create();
		addDim(this);

		var leftX:Float = bg.x + PAD;
		var rightX:Float = leftX + COL_W + PAD;
		var topY:Float = bg.y + 70;
		var botY:Float = bg.y + bg.height - PAD - 24;

		var line:FlxSprite = new FlxSprite(rightX - PAD * 0.5, topY - 10).makeGraphic(1, 1, FlxColor.WHITE);
		line.scale.set(1, botY - topY + 34);
		line.updateHitbox();
		line.alpha = 0.35;
		line.cameras = cameras;
		add(line);

		addHeader(leftX, topY, 'Recent Modcharts');
		recentList = new AnimScrollList(leftX, topY + 34, COL_W, Std.int(botY - topY - 10));
		recentList.setTitle('');
		recentList.labelOf = function(v:Dynamic) return Std.string(v);
		recentList.onSelect = function(i:Int)
		{
			if(onOpenRecent != null && i >= 0 && i < recentLabels.length) onOpenRecent(i);
		}
		recentList.cameras = cameras;
		add(recentList);
		recentHint = addHint(leftX, topY + 60, 'No modcharts started yet.');

		addHeader(rightX, topY, 'Create New');
		addButton(rightX, topY + 34, 'From Song...', function() if(onFromSong != null) onFromSong());
		addHint(rightX, topY + 70, 'Pick a song and a difficulty:\nthe modchart is saved with the song.');

		if(currentSong != null)
			addHint(rightX, botY, 'Esc: keep "$currentSong"');

		applyRecents();
	}

	public function setRecents(labels:Array<String>)
	{
		recentLabels = (labels != null) ? labels : [];
		applyRecents();
	}

	function applyRecents()
	{
		if(recentList == null) return;
		recentList.setList(cast recentLabels, -1);
		recentHint.visible = (recentLabels.length < 1);
	}

	function addHeader(x:Float, y:Float, label:String)
	{
		var txt:FlxText = new FlxText(x, y, COL_W, label, 18);
		txt.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		txt.cameras = cameras;
		add(txt);
	}

	function addHint(x:Float, y:Float, label:String):FlxText
	{
		var txt:FlxText = new FlxText(x, y, COL_W, label, 12);
		txt.setFormat(Paths.font('vcr.ttf'), 12, 0xFF9F9F9F, CENTER);
		txt.cameras = cameras;
		add(txt);
		return txt;
	}

	function addButton(x:Float, y:Float, label:String, callback:Void->Void):PsychUIButton
	{
		var btn:PsychUIButton = new PsychUIButton(x, y, label, callback, COL_W, 24);
		btn.cameras = cameras;
		add(btn);
		return btn;
	}
}

class ModchartSongPrompt extends BasePrompt
{
	public var onLoad:String->String->Bool;

	static inline final PAD:Int = 20;
	static inline final COL_W:Int = 380;

	var songNames:Array<String> = [];
	var songDiffs:Array<String> = [];
	var curSong:Int = -1;
	var curDiff:Int = 0;
	var diffButton:PsychUIButton;
	var loadButton:PsychUIButton;
	var savedDiffs:Array<String>;
	var loaded:Bool = false;

	public function new()
	{
		super(COL_W + PAD * 2, 460, 'Create From Song');
	}

	override function close()
	{
		if(!loaded && savedDiffs != null) Difficulty.list = savedDiffs;
		super.close();
	}

	override function create()
	{
		super.create();
		ModchartStartupPrompt.addDim(this);

		var x:Float = bg.x + PAD;
		var topY:Float = bg.y + 60;
		var botY:Float = bg.y + bg.height - PAD - 24;

		savedDiffs = Difficulty.list.copy();
		songNames = EditorSongs.songList();

		var songList:AnimScrollList = new AnimScrollList(x, topY, COL_W, Std.int(botY - topY - 40));
		songList.setTitle('');
		songList.labelOf = function(v:Dynamic) return Std.string(v);
		songList.onSelect = function(i:Int)
		{
			if(i < 0 || i >= songNames.length) return;
			curSong = i;
			songDiffs = EditorSongs.difficulties(songNames[i]);
			if(songDiffs.length < 1) songDiffs = [Difficulty.getDefault()];
			curDiff = Std.int(Math.max(0, songDiffs.indexOf(Difficulty.getDefault())));
			updateButtons();
		}
		songList.cameras = cameras;
		add(songList);
		songList.setList(cast songNames, -1);

		diffButton = new PsychUIButton(x, botY - 30, '', function()
		{
			if(curSong < 0) return;
			curDiff = (curDiff + 1) % songDiffs.length;
			updateButtons();
		}, COL_W, 24);
		diffButton.cameras = cameras;
		add(diffButton);

		loadButton = new PsychUIButton(x, botY, '', function()
		{
			if(curSong < 0 || onLoad == null) return;
			loaded = onLoad(songNames[curSong], songDiffs[curDiff]);
		}, COL_W, 24);
		loadButton.cameras = cameras;
		add(loadButton);

		updateButtons();
	}

	function updateButtons()
	{
		if(curSong < 0)
		{
			diffButton.text.text = 'Difficulty: ---';
			loadButton.text.text = 'Select a Song';
			return;
		}
		diffButton.text.text = 'Difficulty: ${songDiffs[curDiff]}';
		loadButton.text.text = 'Load "${songNames[curSong]}"';
	}
}
