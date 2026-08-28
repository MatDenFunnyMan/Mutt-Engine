package funkin.editors.content;

import funkin.editors.content.Prompt.BasePrompt;

class SongAudioPrompt extends BasePrompt
{
	public var onBrowse:String->Void;
	public var onDone:Void->Void;

	static inline final BOX_W:Int = 620;
	static inline final BOX_H:Int = 400;

	static final TARGETS:Array<Array<String>> = [
		['Inst', 'Instrumental:'],
		['Voices', 'Voices (Both):'],
		['Voices-Player', 'Voices (Player):'],
		['Voices-Opponent', 'Voices (Opponent):']
	];

	var folder:String;
	var readableFolder:String;
	var finished:Bool = false;
    var warnText:FlxText;
	var statusTexts:Map<String, FlxText> = [];

	public function new(folder:String, readableFolder:String)
	{
		this.folder = folder;
		this.readableFolder = readableFolder;
		super(BOX_W, BOX_H, 'Song Audio');
	}

	override function create()
	{
		super.create();

		closeCallback = function()
		{
			if(finished) return;
			finished = true;
			if(onDone != null) onDone();
		}

		var destLabel:FlxText = new FlxText(bg.x + 20, bg.y + 56, BOX_W - 40, 'Files will be copied to:\n$readableFolder', 12);
		destLabel.setFormat(Paths.font('vcr.ttf'), 12, 0xFFBBBBBB, CENTER);
		destLabel.cameras = cameras;
		add(destLabel);

		var y:Float = bg.y + 110;
		for (entry in TARGETS)
		{
			var key:String = entry[0];

			var label:FlxText = new FlxText(bg.x + 40, y + 4, 170, entry[1], 14);
			label.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			label.borderSize = 1;
			label.cameras = cameras;
			add(label);

			var alreadyThere:Bool = FileSystem.exists(folder + key + '.${Paths.SOUND_EXT}');
			var status:FlxText = new FlxText(bg.x + 220, y + 6, 240, alreadyThere ? 'already present' : 'not set', 11);
			status.setFormat(Paths.font('vcr.ttf'), 11, alreadyThere ? 0xFF66DD66 : 0xFF9F9F9F, LEFT);
			status.cameras = cameras;
			add(status);
			statusTexts.set(key, status);

			var btn:PsychUIButton = new PsychUIButton(bg.x + BOX_W - 150, y, 'Browse...', function() if(onBrowse != null) onBrowse(key), 110, 24);
			btn.cameras = cameras;
			add(btn);

			y += 45;
		}

		var hint:FlxText = new FlxText(bg.x + 20, bg.y + 296, BOX_W - 40, 'Player and Opponent are optional: without them the game uses Voices (Both).', 11);
		hint.setFormat(Paths.font('vcr.ttf'), 11, 0xFF9F9F9F, CENTER);
		hint.cameras = cameras;
		add(hint);

		warnText = new FlxText(bg.x + 20, bg.y + 326, BOX_W - 40, '', 12);
		warnText.setFormat(Paths.font('vcr.ttf'), 12, 0xFFFF5555, CENTER, OUTLINE, FlxColor.BLACK);
		warnText.borderSize = 1;
		warnText.visible = false;
		warnText.cameras = cameras;
		add(warnText);

		var doneBtn:PsychUIButton = new PsychUIButton(bg.x + BOX_W * 0.5 - 160, bg.y + BOX_H - 44, 'Done', tryDone, 150, 24);
		var skipBtn:PsychUIButton = new PsychUIButton(bg.x + BOX_W * 0.5 + 10, bg.y + BOX_H - 44, 'Skip', finish, 150, 24);
		doneBtn.cameras = skipBtn.cameras = cameras;
		add(doneBtn);
		add(skipBtn);
	}

	public function setStatus(target:String, message:String, ok:Bool)
	{
		var txt:FlxText = statusTexts.get(target);
		if(txt == null) return;
		txt.text = message;
		txt.color = ok ? 0xFF66DD66 : 0xFFFF5555;
	}

    function tryDone()
	{
		if(!FileSystem.exists(folder + 'Inst.${Paths.SOUND_EXT}'))
		{
			warnText.text = 'An Instrumental is required. Use Skip to continue without audio.';
			warnText.visible = true;
			return;
		}
		finish();
	}

	function finish()
	{
		if(finished) return;
		finished = true;
		if(onDone != null) onDone();
		close();
	}
}