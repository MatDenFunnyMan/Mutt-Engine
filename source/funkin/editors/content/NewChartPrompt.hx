package funkin.editors.content;

import funkin.editors.content.Prompt.BasePrompt;
import funkin.data.Song.SwagSong;

class NewChartPrompt extends BasePrompt
{
	public var onAccept:SwagSong->Void;
	public var onCancel:Void->Void;

	public var outArtist:String = '';
	public var outComposer:String = '';
	public var outCharter:String = '';
	public var outCoder:String = '';

	static inline final BOX_W:Int = 640;
	static inline final BOX_H:Int = 420;
	static inline final FIELD_W:Int = 170;
	static inline final DROP_W:Int = 160;

	var stageList:Array<String>;
	var charList:Array<String>;
	var accepted:Bool = false;

	var songNameInput:PsychUIInputText;
	var artistInput:PsychUIInputText;
	var composerInput:PsychUIInputText;
	var charterInput:PsychUIInputText;
	var coderInput:PsychUIInputText;
	var stageDrop:PsychUIDropDownMenu;
	var playerDrop:PsychUIDropDownMenu;
	var gfDrop:PsychUIDropDownMenu;
	var opponentDrop:PsychUIDropDownMenu;
	var bpmStepper:PsychUINumericStepper;
	var warnText:FlxText;

	public function new(stages:Array<String>, characters:Array<String>)
	{
		this.stageList = (stages != null && stages.length > 0) ? stages.copy() : ['stage'];
		this.charList = (characters != null && characters.length > 0) ? characters.copy() : ['bf'];
		super(BOX_W, BOX_H, 'New Song');
	}

	override function create()
	{
		super.create();

		closeCallback = function()
		{
			PsychUIInputText.focusOn = null;
			if(!accepted && onCancel != null) onCancel();
		}

		var leftLabelX:Float = bg.x + 30;
		var leftFieldX:Float = bg.x + 130;
		var rightLabelX:Float = bg.x + 340;
		var rightFieldX:Float = bg.x + 450;

		var labels:Array<FlxText> = [];

		songNameInput = new PsychUIInputText(leftFieldX, bg.y + 70, FIELD_W, '', 8);
		labels.push(addLabel(leftLabelX, bg.y + 70, 'Song Name:'));

		labels.push(addHeader(leftLabelX, bg.y + 110, 'Metadata (optional)'));
		artistInput = new PsychUIInputText(leftFieldX, bg.y + 145, FIELD_W, '', 8);
		labels.push(addLabel(leftLabelX, bg.y + 145, 'Artist:'));
		composerInput = new PsychUIInputText(leftFieldX, bg.y + 185, FIELD_W, '', 8);
		labels.push(addLabel(leftLabelX, bg.y + 185, 'Composer:'));
		charterInput = new PsychUIInputText(leftFieldX, bg.y + 225, FIELD_W, '', 8);
		labels.push(addLabel(leftLabelX, bg.y + 225, 'Charter:'));
		coderInput = new PsychUIInputText(leftFieldX, bg.y + 265, FIELD_W, '', 8);
		labels.push(addLabel(leftLabelX, bg.y + 265, 'Coder:'));

		labels.push(addHeader(rightLabelX, bg.y + 110, 'Song Setup'));
		stageDrop = new PsychUIDropDownMenu(rightFieldX, bg.y + 145, stageList, null, DROP_W);
		labels.push(addLabel(rightLabelX, bg.y + 145, 'Stage:'));
		playerDrop = new PsychUIDropDownMenu(rightFieldX, bg.y + 185, charList, null, DROP_W);
		labels.push(addLabel(rightLabelX, bg.y + 185, 'Player:'));
		gfDrop = new PsychUIDropDownMenu(rightFieldX, bg.y + 225, charList, null, DROP_W);
		labels.push(addLabel(rightLabelX, bg.y + 225, 'Girlfriend:'));
		opponentDrop = new PsychUIDropDownMenu(rightFieldX, bg.y + 265, charList, null, DROP_W);
		labels.push(addLabel(rightLabelX, bg.y + 265, 'Opponent:'));
		bpmStepper = new PsychUINumericStepper(rightFieldX, bg.y + 305, 1, 150, 1, 1000, 2, 90);
		labels.push(addLabel(rightLabelX, bg.y + 305, 'BPM:'));

		selectIn(stageDrop, 'stage');
		selectIn(playerDrop, 'bf');
		selectIn(gfDrop, 'gf');
		selectIn(opponentDrop, 'dad');

		for (input in [songNameInput, artistInput, composerInput, charterInput, coderInput])
			input.cameras = cameras;
		bpmStepper.cameras = cameras;

		var divider:FlxSprite = new FlxSprite(bg.x + 320, bg.y + 100).makeGraphic(1, 1, FlxColor.WHITE);
		divider.scale.set(1, 230);
		divider.updateHitbox();
		divider.alpha = 0.35;
		divider.cameras = cameras;

		warnText = new FlxText(bg.x, bg.y + BOX_H - 76, BOX_W, '', 12);
		warnText.setFormat(Paths.font('vcr.ttf'), 12, 0xFFFF5555, CENTER, OUTLINE, FlxColor.BLACK);
		warnText.borderSize = 1;
		warnText.visible = false;
		warnText.cameras = cameras;

		var btnY:Float = bg.y + BOX_H - 44;
		var createBtn:PsychUIButton = new PsychUIButton(bg.x + BOX_W * 0.5 - 160, btnY, 'Create Chart', accept, 150, 24);
		var cancelBtn:PsychUIButton = new PsychUIButton(bg.x + BOX_W * 0.5 + 10, btnY, 'Cancel', function() close(), 150, 24);
		createBtn.cameras = cancelBtn.cameras = cameras;

		add(divider);
		for (txt in labels) add(txt);
		add(warnText);
		add(createBtn);
		add(cancelBtn);
		add(songNameInput);
		add(artistInput);
		add(composerInput);
		add(charterInput);
		add(coderInput);
		add(bpmStepper);
		add(opponentDrop);
		add(gfDrop);
		add(playerDrop);
		add(stageDrop);
	}

	function addLabel(x:Float, y:Float, label:String):FlxText
	{
		var txt:FlxText = new FlxText(x, y + 2, 190, label, 14);
		txt.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		txt.borderSize = 1;
		txt.cameras = cameras;
		return txt;
	}

	function addHeader(x:Float, y:Float, label:String):FlxText
	{
		var txt:FlxText = new FlxText(x, y, 280, label, 16);
		txt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		txt.borderSize = 1;
		txt.cameras = cameras;
		return txt;
	}

	function selectIn(drop:PsychUIDropDownMenu, want:String)
	{
		drop.cameras = cameras;
		var idx:Int = drop.list.indexOf(want);
		drop.selectedIndex = (idx >= 0) ? idx : 0;
	}

	inline function pick(drop:PsychUIDropDownMenu, fallback:String):String
	{
		var v:String = drop.selectedLabel;
		return (v != null && v.length > 0) ? v : fallback;
	}

	function accept()
	{
		var name:String = songNameInput.text.trim();
		if(name.length < 1)
		{
			warnText.text = 'The song needs a name.';
			warnText.visible = true;
			return;
		}

		var song:SwagSong = {
			song: name,
			notes: [],
			events: [],
			bpm: bpmStepper.value,
			needsVoices: true,
			speed: 1,
			offset: 0,

			player1: pick(playerDrop, 'bf'),
			player2: pick(opponentDrop, 'dad'),
			gfVersion: pick(gfDrop, 'gf'),
			stage: pick(stageDrop, 'stage'),
			format: 'psych_v1'
		};

		outArtist = artistInput.text.trim();
		outComposer = composerInput.text.trim();
		outCharter = charterInput.text.trim();
		outCoder = coderInput.text.trim();

		accepted = true;
		PsychUIInputText.focusOn = null;
		if(onAccept != null) onAccept(song);
		close();
	}
}