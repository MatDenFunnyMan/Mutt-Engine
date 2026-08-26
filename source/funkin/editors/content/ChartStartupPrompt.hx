package funkin.editors.content;
import funkin.editors.content.Prompt.BasePrompt;

class ChartStartupPrompt extends BasePrompt
{
	public var onBrowse:Void->Void;
	public var onCreateNew:Void->Void;
	public var onCreateNewTest:Void->Void;
	public var onImportVSlice:Void->Void;
	public var onImportCodename:Void->Void;
	public var onFromSong:Void->Void;
	public var onOpenRecent:String->Void;
	public var onCreateFromSong:String->Int->Void;
	public var difficultiesOf:String->Array<String>;

	static inline final PAD:Int = 20;
	static inline final COL_W:Int = 306;

	var recentPaths:Array<String> = [];
	var recentLabels:Array<String> = [];
	var recentList:AnimScrollList;
	var recentHint:FlxText;

	var songNames:Array<String> = [];
	var songDiffs:Array<String> = ['Normal'];
	var curSong:Int = -1;
	var curDiff:Int = 0;
	var songList:AnimScrollList;
	var diffButton:PsychUIButton;
	var loadButton:PsychUIButton;

	public function new()
	{
		super(1000, 500, 'Chart Editor');
	}

	override function create()
	{
		super.create();

		var colX:Array<Float> = [];
		for (i in 0...3) colX.push(bg.x + PAD + i * (COL_W + PAD));

		var topY:Float = bg.y + 70;
		var botY:Float = bg.y + bg.height - PAD - 24;

		for (i in 1...3)
		{
			var line:FlxSprite = new FlxSprite(colX[i] - PAD * 0.5, topY - 10).makeGraphic(1, 1, FlxColor.WHITE);
			line.scale.set(1, botY - topY + 34);
			line.updateHitbox();
			line.alpha = 0.35;
			line.cameras = cameras;
			add(line);
		}

		addHeader(colX[0], topY, 'Open Recent');

		recentList = new AnimScrollList(colX[0], topY + 34, COL_W, Std.int(botY - topY - 44));
		recentList.setTitle('');
		recentList.labelOf = function(v:Dynamic) return Std.string(v);
		recentList.onSelect = function(i:Int)
		{
			if(onOpenRecent == null || i < 0 || i >= recentPaths.length) return;
			onOpenRecent(recentPaths[i]);
		}
		recentList.cameras = cameras;
		add(recentList);

		recentHint = addHint(colX[0], topY + 60, 'No recent charts yet.');
		addButton(colX[0], botY, 'Browse for Chart...', onBrowse);

		addHeader(colX[1], topY, 'Create New');
		addButton(colX[1], topY + 34, 'New Chart', onCreateNew);
		addButton(colX[1], topY + 64, 'New Chart (Test)', onCreateNewTest);
		

		addHeader(colX[1], topY + 190, 'Import Chart');
		addButton(colX[1], topY + 224, 'From V-Slice', onImportVSlice);
		addButton(colX[1], topY + 254, 'From Codename', onImportCodename);

		addHeader(colX[2], topY, 'Create From Song');

		songList = new AnimScrollList(colX[2], topY + 34, COL_W, Std.int(botY - topY - 104));
		songList.setTitle('');
		songList.labelOf = function(v:Dynamic) return Std.string(v);
		songList.onSelect = function(i:Int)
		{
			if(i < 0 || i >= songNames.length) return;
			curSong = i;
			curDiff = 0;
			songDiffs = (difficultiesOf != null) ? difficultiesOf(songNames[i]) : ['Normal'];
			if(songDiffs.length < 1) songDiffs = ['Normal'];
			updateSongButtons();
		}
		songList.cameras = cameras;
		add(songList);

		diffButton = addButton(colX[2], botY - 30, 'Difficulty: ---', function()
		{
			if(curSong < 0) return;
			curDiff = (curDiff + 1) % songDiffs.length;
			updateSongButtons();
		});

		loadButton = addButton(colX[2], botY, 'Select a Song', function()
		{
			if(curSong < 0 || onCreateFromSong == null) return;
			onCreateFromSong(songNames[curSong], curDiff);
		});

		applyRecents();
		setSongs(songNames);
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
		var btn:PsychUIButton = new PsychUIButton(x, y, label, function() run(callback), COL_W, 24);
		if(callback == null)
		{
			btn.normalStyle.bgColor = 0xFF555555;
			btn.normalStyle.textColor = 0xFF9F9F9F;
		}
		btn.cameras = cameras;
		add(btn);
		return btn;
	}

	public function setRecents(paths:Array<String>, labels:Array<String>)
	{
		recentPaths = (paths != null) ? paths : [];
		recentLabels = (labels != null) ? labels : [];
		applyRecents();
	}

	public function setSongs(names:Array<String>)
	{
		songNames = (names != null) ? names : [];
		if(songList == null) return;
		songList.setList(cast songNames, -1);
		updateSongButtons();
	}

	function updateSongButtons()
	{
		if(diffButton == null || loadButton == null) return;

		if(curSong < 0)
		{
			diffButton.text.text = 'Difficulty: ---';
			loadButton.text.text = 'Select a Song';
			return;
		}
		diffButton.text.text = 'Difficulty: ${songDiffs[curDiff]}';
		loadButton.text.text = 'Load "${songNames[curSong]}"';
	}

	function applyRecents()
	{
		if(recentList == null) return;
		recentList.setList(cast recentLabels, -1);
		if(recentHint != null) recentHint.visible = (recentPaths.length < 1);
	}

	function run(callback:Void->Void)
	{
		if(callback == null) return;
		callback();
	}
}