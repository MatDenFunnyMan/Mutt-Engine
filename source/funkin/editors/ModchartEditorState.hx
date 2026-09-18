package funkin.editors;

import haxe.Json;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.tweens.FlxTween;

import funkin.game.notes.Note;
import funkin.game.notes.StrumNote;
import funkin.data.Song;
import funkin.data.Song.SwagSection;
import funkin.ui.psychui.PsychUIInputText.FilterMode;

import modcharting.PlayfieldRenderer;
import modcharting.PlayfieldRenderer.StrumNoteType;
import modcharting.NoteMovement;
import modcharting.ModchartFile;
import modcharting.ModchartFile.ModchartJson;
import modcharting.ModchartUtil;

typedef TimelineTarget = {
	var mod:String;
	var sub:String;
	var value:String;
}

typedef TimelineEvent = {
	var index:Int;
	var type:String;
	var beat:Float;
	var length:Float;
	var ease:String;
	var targets:Array<TimelineTarget>;
	var repeatCount:Int;
	var repeatGap:Float;
}

typedef TimelineHit = {
	var x:Float;
	var y:Float;
	var event:Int;
	var mod:String;
}

class ModchartEditorState extends MusicBeatState
{
	static inline final PREVIEW_Y:Int = 24;
	static inline final PREVIEW_H:Int = 456;
	static inline final PANEL_X:Int = 8;
	static inline final PANEL_Y:Int = 488;
	static inline final PANEL_W:Int = 1004;
	static inline final RULER_H:Int = 18;
	static inline final ROW_H:Int = 22;
	static inline final VISIBLE_ROWS:Int = 8;
	static inline final LABEL_W:Int = 170;
	static inline final PLAYBAR_Y:Int = 690;
	static inline final PLAYBAR_H:Int = 14;
	static inline final INFO_X:Int = 1020;
	static inline final INFO_W:Int = 252;
	static inline final PROP_X:Int = 1052;
	static inline final PROP_W:Int = 222;
	static inline final PLAYHEAD_RATIO:Float = 0.2;
	static inline final MIN_ZOOM:Float = 12;
	static inline final MAX_ZOOM:Float = 240;
	static inline final MAX_UNDO:Int = 100;
	static inline final MAIN_VALUE:String = '(main value)';

	static inline final DRAG_NONE:Int = 0;
	static inline final DRAG_MOVE:Int = 1;
	static inline final DRAG_RESIZE:Int = 2;
	static inline final DRAG_PLAYBAR:Int = 3;

	static inline final COLOR_SET:FlxColor = 0xFF5EC8FF;
	static inline final COLOR_EASE:FlxColor = 0xFFFFFFFF;
	static inline final COLOR_SELECTED:FlxColor = 0xFFFFD84A;

	static final SNAP_LABELS:Array<String> = ['1 beat', '1/2 beat', '1/4 beat', '1/8 beat', '1/16 beat', 'None'];
	static final SNAP_VALUES:Array<Float> = [1, 0.5, 0.25, 0.125, 0.0625, 0];

	static final EASES:Array<String> = [
		'backIn', 'backInOut', 'backOut',
		'bounceIn', 'bounceInOut', 'bounceOut',
		'circIn', 'circInOut', 'circOut',
		'cubeIn', 'cubeInOut', 'cubeOut',
		'elasticIn', 'elasticInOut', 'elasticOut',
		'expoIn', 'expoInOut', 'expoOut',
		'linear',
		'quadIn', 'quadInOut', 'quadOut',
		'quartIn', 'quartInOut', 'quartOut',
		'quintIn', 'quintInOut', 'quintOut',
		'sineIn', 'sineInOut', 'sineOut',
		'smoothStepIn', 'smoothStepInOut', 'smoothStepOut',
		'smootherStepIn', 'smootherStepInOut', 'smootherStepOut'
	];

	var camPreview:FlxCamera;
	var camUI:FlxCamera;

	public var strumLineNotes:FlxTypedGroup<StrumNoteType>;
	public var opponentStrums:FlxTypedGroup<StrumNoteType>;
	public var playerStrums:FlxTypedGroup<StrumNoteType>;
	public var notes:FlxTypedGroup<Note>;
	var unspawnNotes:Array<Note> = [];
	var loadedNotes:Array<Note> = [];

	var vocals:FlxSound;
	var opponentVocals:FlxSound;

	var playbackSpeed:Float = 1;
	var pixelsPerBeat:Float = 48;
	var snap:Float = 0.25;
	var rowScroll:Int = 0;
	var playfieldFilter:Int = -1;
	var selectedEvent:Int = -1;
	var curTarget:Int = 0;
	var dirtyNotes:Bool = true;
	var dirtyEvents:Bool = true;

	var dragMode:Int = DRAG_NONE;
	var dragEvent:Int = -1;
	var dragOffset:Float = 0;
	var dragStartX:Float = 0;
	var dragMoved:Bool = false;

	var undoStack:Array<String> = [];
	var redoStack:Array<String> = [];
	var editTag:String = null;
	var clipboard:String = null;
	var lastFocus:PsychUIInputText = null;

	var timelineEvents:Array<TimelineEvent> = [];
	var visibleMods:Array<Array<Dynamic>> = [];
	var hits:Array<TimelineHit> = [];
	var resizeHits:Array<TimelineHit> = [];

	var upperBox:PsychUIBox;
	var playfieldDropDown:PsychUIDropDownMenu;
	var snapDropDown:PsychUIDropDownMenu;
	var knownPlayfields:Int = -1;

	var rowLabels:Array<FlxText> = [];
	var rowValues:Array<FlxText> = [];
	var rowsInfoText:FlxText;
	var emptyText:FlxText;
	var linePool:Array<FlxSprite> = [];
	var rulerPool:Array<FlxText> = [];
	var diamondPool:Array<FlxSprite> = [];
	var barPool:Array<FlxSprite> = [];
	var timelineLayer:FlxTypedGroup<FlxSprite>;
	var playhead:FlxSprite;

	var playbarFill:FlxSprite;
	var playbarHead:FlxSprite;
	var infoText:FlxText;

	var propsEmptyText:FlxText;
	var propsWidgets:Array<FlxSprite> = [];
	var easeWidgets:Array<FlxSprite> = [];
	var typeDropDown:PsychUIDropDownMenu;
	var beatStepper:PsychUINumericStepper;
	var lengthStepper:PsychUINumericStepper;
	var easeDropDown:PsychUIDropDownMenu;
	var repeatCheckBox:PsychUICheckBox;
	var repeatCountStepper:PsychUINumericStepper;
	var repeatGapStepper:PsychUINumericStepper;
	var targetCountText:FlxText;
	var targetModDropDown:PsychUIDropDownMenu;
	var targetSubDropDown:PsychUIDropDownMenu;
	var targetValueInput:PsychUIInputText;
	var targetsListText:FlxText;
	var knownModNames:String = null;
	var knownSubMod:String = null;

	var helpBg:FlxSprite;
	var helpText:FlxText;
	var helpPage:Int = 0;

	override function create()
	{
		initPsychCamera().bgColor = 0xFF1B1B22;

		var previewZoom:Float = PREVIEW_H / FlxG.height;
		camPreview = new FlxCamera(Std.int((FlxG.width - FlxG.width * previewZoom) / 2), PREVIEW_Y, FlxG.width, FlxG.height, previewZoom);
		camPreview.bgColor = FlxColor.BLACK;
		FlxG.cameras.add(camPreview, false);

		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;
		FlxG.cameras.add(camUI, false);

		if(PlayState.SONG == null)
			PlayState.SONG = Song.loadFromJson('tutorial');

		Conductor.mapBPMChanges(PlayState.SONG);
		Conductor.bpm = PlayState.SONG.bpm;
		Conductor.songPosition = 0;
		FlxG.mouse.visible = true;

		strumLineNotes = new FlxTypedGroup<StrumNoteType>();
		opponentStrums = new FlxTypedGroup<StrumNoteType>();
		playerStrums = new FlxTypedGroup<StrumNoteType>();
		add(strumLineNotes);

		loadAudio();
		generateNotes();

		playfieldRenderer = new PlayfieldRenderer(strumLineNotes, notes, this);
		playfieldRenderer.cameras = [camPreview];
		playfieldRenderer.inEditor = true;
		playfieldRenderer.editorPaused = true;
		add(playfieldRenderer);

		generateStrums(0);
		generateStrums(1);
		NoteMovement.getDefaultStrumPosFromGroup(strumLineNotes, playerStrums.length);

		createTimeline();
		createPlaybar();
		createInfoPanel();
		createPropertiesPanel();
		createUpperMenu();
		createHelp();

		refreshTimelineData();
		refreshProps();
		super.create();
	}

	function loadAudio()
	{
		var song:String = PlayState.SONG.song;
		var diff:String = Difficulty.getFilePath();

		FlxG.sound.playMusic(Paths.inst(song, diff), 1, false);
		FlxG.sound.music.pause();
		FlxG.sound.music.time = 0;
		FlxG.sound.music.onComplete = function()
		{
			setPlaying(false);
			seekTo(0);
		};

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		if(PlayState.SONG.needsVoices)
		{
			var playerSound = Paths.voices(song, 'Player', diff);
			vocals.loadEmbedded(playerSound != null ? playerSound : Paths.voices(song, null, diff));

			var opponentSound = Paths.voices(song, 'Opponent', diff);
			if(opponentSound != null) opponentVocals.loadEmbedded(opponentSound);
		}
		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);
	}

	function generateNotes()
	{
		notes = new FlxTypedGroup<Note>();
		add(notes);

		for (section in PlayState.SONG.notes)
		{
			for (songNotes in section.sectionNotes)
			{
				var column:Int = Std.int(songNotes[1]);
				if(column < 0 || column > 7) continue;

				var strumTime:Float = songNotes[0];
				var noteData:Int = column % 4;
				var mustPress:Bool = (column < 4);

				var oldNote:Note = (unspawnNotes.length > 0) ? unspawnNotes[unspawnNotes.length - 1] : null;
				var note:Note = new Note(strumTime, noteData, oldNote);
				note.sustainLength = Math.isNaN(songNotes[2]) ? 0 : songNotes[2];
				note.mustPress = mustPress;
				note.gfNote = (section.gfSection && mustPress == section.mustHitSection);
				note.noteType = songNotes[3];
				if(!Std.isOfType(songNotes[3], String)) note.noteType = Note.defaultNoteTypes[songNotes[3]];
				note.scrollFactor.set();
				unspawnNotes.push(note);

				var susLength:Int = Math.floor(note.sustainLength / Conductor.stepCrochet);
				if(susLength > 0)
				{
					for (susNote in 0...susLength + 1)
					{
						oldNote = unspawnNotes[unspawnNotes.length - 1];
						var sustain:Note = new Note(strumTime + (Conductor.stepCrochet * susNote) + (Conductor.stepCrochet / FlxMath.roundDecimal(PlayState.SONG.speed, 2)), noteData, oldNote, true);
						sustain.mustPress = mustPress;
						sustain.gfNote = note.gfNote;
						sustain.noteType = note.noteType;
						note.tail.push(sustain);
						sustain.parent = note;
						sustain.scrollFactor.set();
						unspawnNotes.push(sustain);
					}
				}
			}
		}

		unspawnNotes.sort(function(a:Note, b:Note) return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime));
		loadedNotes = unspawnNotes.copy();
	}

	function generateStrums(player:Int)
	{
		var strumX:Float = ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X;
		var strumY:Float = ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50;

		for (i in 0...4)
		{
			var targetAlpha:Float = 1;
			if(player < 1)
			{
				if(!ClientPrefs.data.opponentStrums) targetAlpha = 0;
				else if(ClientPrefs.data.middleScroll) targetAlpha = 0.35;
			}

			var strum:StrumNote = new StrumNote(strumX, strumY, i, player);
			strum.downScroll = ClientPrefs.data.downScroll;
			strum.alpha = targetAlpha;

			if(player == 1) playerStrums.add(strum);
			else
			{
				if(ClientPrefs.data.middleScroll)
				{
					strum.x += 310;
					if(i > 1) strum.x += FlxG.width / 2 + 25;
				}
				opponentStrums.add(strum);
			}

			strumLineNotes.add(strum);
			strum.playerPosition();
		}
	}

	function createTimeline()
	{
		var panel:FlxSprite = new FlxSprite(PANEL_X, PANEL_Y).makeGraphic(PANEL_W, RULER_H + VISIBLE_ROWS * ROW_H, 0xFF26262F);
		panel.cameras = [camUI];
		add(panel);

		var labelPanel:FlxSprite = new FlxSprite(PANEL_X, PANEL_Y).makeGraphic(LABEL_W, RULER_H + VISIBLE_ROWS * ROW_H, 0xFF3A3A4A);
		labelPanel.cameras = [camUI];
		add(labelPanel);

		for (row in 0...VISIBLE_ROWS)
		{
			if(row % 2 == 1)
			{
				var stripe:FlxSprite = new FlxSprite(gridX(), rowY(row)).makeGraphic(Std.int(gridW()), ROW_H, 0xFF2C2C36);
				stripe.cameras = [camUI];
				add(stripe);
			}

			var separator:FlxSprite = new FlxSprite(PANEL_X, rowY(row) + ROW_H - 1).makeGraphic(PANEL_W, 1, 0xFF1B1B22);
			separator.cameras = [camUI];
			add(separator);

			var label:FlxText = new FlxText(PANEL_X + 6, rowY(row) + 4, LABEL_W - 60, '', 10);
			label.cameras = [camUI];
			rowLabels.push(label);
			add(label);

			var value:FlxText = new FlxText(PANEL_X + LABEL_W - 60, rowY(row) + 4, 54, '', 10);
			value.alignment = RIGHT;
			value.color = 0xFFBBBBBB;
			value.cameras = [camUI];
			rowValues.push(value);
			add(value);
		}

		rowsInfoText = new FlxText(PANEL_X + 6, PANEL_Y + 3, LABEL_W - 10, '', 9);
		rowsInfoText.color = 0xFFBBBBBB;
		rowsInfoText.cameras = [camUI];
		add(rowsInfoText);

		timelineLayer = new FlxTypedGroup<FlxSprite>();
		timelineLayer.cameras = [camUI];
		add(timelineLayer);

		emptyText = new FlxText(gridX(), rowY(3), gridW(), 'This modchart has no modifiers yet.', 14);
		emptyText.alignment = CENTER;
		emptyText.color = 0xFF888888;
		emptyText.cameras = [camUI];
		add(emptyText);

		playhead = new FlxSprite(playheadX() - 1, PANEL_Y).makeGraphic(2, RULER_H + VISIBLE_ROWS * ROW_H, 0xFFFF4A4A);
		playhead.cameras = [camUI];
		add(playhead);
	}

	function createPlaybar()
	{
		var bg:FlxSprite = new FlxSprite(PANEL_X, PLAYBAR_Y).makeGraphic(PANEL_W, PLAYBAR_H, 0xFF3A3A4A);
		bg.cameras = [camUI];
		add(bg);

		playbarFill = new FlxSprite(PANEL_X, PLAYBAR_Y).makeGraphic(1, PLAYBAR_H, 0xFF8A8AA8);
		playbarFill.origin.set(0, 0);
		playbarFill.cameras = [camUI];
		add(playbarFill);

		playbarHead = new FlxSprite(PANEL_X, PLAYBAR_Y - 3).makeGraphic(6, PLAYBAR_H + 6, FlxColor.WHITE);
		playbarHead.cameras = [camUI];
		add(playbarHead);
	}

	function createInfoPanel()
	{
		var panel:FlxSprite = new FlxSprite(INFO_X, PANEL_Y).makeGraphic(INFO_W, PLAYBAR_Y + PLAYBAR_H - PANEL_Y, 0xFF26262F);
		panel.cameras = [camUI];
		add(panel);

		var title:FlxText = new FlxText(INFO_X, PANEL_Y + 4, INFO_W, 'Information', 12);
		title.alignment = CENTER;
		title.cameras = [camUI];
		add(title);

		infoText = new FlxText(INFO_X + 10, PANEL_Y + 78, INFO_W - 20, '', 10);
		infoText.cameras = [camUI];
		add(infoText);

		var playfieldLabel:FlxText = new FlxText(INFO_X + 10, PANEL_Y + 27, 70, 'Playfield:', 10);
		playfieldLabel.cameras = [camUI];
		add(playfieldLabel);

		var snapLabel:FlxText = new FlxText(INFO_X + 10, PANEL_Y + 51, 70, 'Snap:', 10);
		snapLabel.cameras = [camUI];
		add(snapLabel);

		snapDropDown = new PsychUIDropDownMenu(INFO_X + 80, PANEL_Y + 48, SNAP_LABELS, function(index:Int, _) {
			snap = SNAP_VALUES[index];
		}, 100);
		snapDropDown.selectedLabel = '1/4 beat';
		snapDropDown.cameras = [camUI];
		add(snapDropDown);

		playfieldDropDown = new PsychUIDropDownMenu(INFO_X + 80, PANEL_Y + 24, ['All'], function(_, label:String) {
			playfieldFilter = (label == 'All') ? -1 : Std.parseInt(label);
			rowScroll = 0;
			refreshTimelineData();
		}, 100);
		playfieldDropDown.cameras = [camUI];
		add(playfieldDropDown);
	}

	function createPropertiesPanel()
	{
		var panel:FlxSprite = new FlxSprite(PROP_X, PREVIEW_Y).makeGraphic(PROP_W, PREVIEW_H, 0xFF26262F);
		panel.cameras = [camUI];
		add(panel);

		var title:FlxText = new FlxText(PROP_X, PREVIEW_Y + 4, PROP_W, 'Event', 12);
		title.alignment = CENTER;
		title.cameras = [camUI];
		add(title);

		propsEmptyText = new FlxText(PROP_X + 10, PREVIEW_Y + 34, PROP_W - 20, 'No event selected.\n\n'
			+ 'Click on a mark of the timeline to select it.\n\n'
			+ 'Right click on an empty spot of a row to create a new event for that modifier.', 10);
		propsEmptyText.color = 0xFFBBBBBB;
		propsEmptyText.cameras = [camUI];
		add(propsEmptyText);

		var fx:Float = PROP_X + 76;

		propLabel(30, 'Type:');
		typeDropDown = propWidget(new PsychUIDropDownMenu(fx, PREVIEW_Y + 30, ['set', 'ease'], function(_, label:String) setEventType(label), 100));

		propLabel(56, 'Beat:');
		beatStepper = propWidget(new PsychUINumericStepper(fx, PREVIEW_Y + 56, 0.25, 0, 0, 9999, 3, 80));
		beatStepper.onValueChange = function() {
			editSelected('beat', function(ev:Array<Dynamic>) {
				ev[ModchartFile.EVENT_DATA][ModchartFile.EVENT_TIME] = beatStepper.value;
			});
		};

		propLabel(82, 'Length:', easeWidgets);
		lengthStepper = propWidget(new PsychUINumericStepper(fx, PREVIEW_Y + 82, 0.25, 1, 0, 999, 3, 80), easeWidgets);
		lengthStepper.onValueChange = function() {
			editSelected('length', function(ev:Array<Dynamic>) {
				ev[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASETIME] = lengthStepper.value;
			});
		};

		propLabel(108, 'Ease:', easeWidgets);
		easeDropDown = propWidget(new PsychUIDropDownMenu(fx, PREVIEW_Y + 108, EASES, function(_, label:String) {
			editSelected(null, function(ev:Array<Dynamic>) {
				ev[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASE] = label;
			});
		}, 136), easeWidgets);

		repeatCheckBox = propWidget(new PsychUICheckBox(PROP_X + 10, PREVIEW_Y + 138, 'Repeat this event', 150));
		repeatCheckBox.onClick = function() {
			editSelected(null, function(ev:Array<Dynamic>) {
				repeatData(ev)[ModchartFile.EVENT_REPEATBOOL] = repeatCheckBox.checked;
			});
		};

		propLabel(160, 'Repeats:');
		repeatCountStepper = propWidget(new PsychUINumericStepper(fx, PREVIEW_Y + 160, 1, 1, 1, 999, 0, 60));
		repeatCountStepper.onValueChange = function() {
			editSelected('repeatCount', function(ev:Array<Dynamic>) {
				repeatData(ev)[ModchartFile.EVENT_REPEATCOUNT] = Std.int(repeatCountStepper.value);
			});
		};

		propLabel(186, 'Every:');
		repeatGapStepper = propWidget(new PsychUINumericStepper(fx, PREVIEW_Y + 186, 0.25, 1, 0, 999, 3, 60));
		repeatGapStepper.onValueChange = function() {
			editSelected('repeatGap', function(ev:Array<Dynamic>) {
				repeatData(ev)[ModchartFile.EVENT_REPEATBEATGAP] = repeatGapStepper.value;
			});
		};
		var beatsLabel:FlxText = propLabel(186, 'beats');
		beatsLabel.x = fx + 98;

		propWidget(new FlxSprite(PROP_X + 10, PREVIEW_Y + 216).makeGraphic(PROP_W - 20, 1, 0xFF4A4A5A));

		targetCountText = propLabel(222, '');
		targetCountText.fieldWidth = 140;
		propWidget(new PsychUIButton(PROP_X + PROP_W - 58, PREVIEW_Y + 222, '<', function() changeTarget(-1), 22));
		propWidget(new PsychUIButton(PROP_X + PROP_W - 32, PREVIEW_Y + 222, '>', function() changeTarget(1), 22));

		propLabel(250, 'Modifier:');
		targetModDropDown = propWidget(new PsychUIDropDownMenu(fx, PREVIEW_Y + 250, [], function(_, label:String) {
			editTarget(null, function(target:TimelineTarget) {
				target.mod = label;
				target.sub = '';
			});
		}, 136));

		propLabel(276, 'Sub value:');
		targetSubDropDown = propWidget(new PsychUIDropDownMenu(fx, PREVIEW_Y + 276, [MAIN_VALUE], function(_, label:String) {
			editTarget(null, function(target:TimelineTarget) {
				target.sub = (label == MAIN_VALUE) ? '' : label;
			});
		}, 136));

		propLabel(302, 'Value:');
		targetValueInput = propWidget(new PsychUIInputText(fx, PREVIEW_Y + 302, 136, '', 8));
		targetValueInput.customFilterPattern = ~/[^0-9.\-]*/g;
		targetValueInput.filterMode = FilterMode.CUSTOM_FILTER;
		targetValueInput.onChange = function(_, cur:String) {
			if(Math.isNaN(Std.parseFloat(cur))) return;
			editTarget('value', function(target:TimelineTarget) {
				target.value = cur;
			});
		};

		propWidget(new PsychUIButton(PROP_X + 10, PREVIEW_Y + 330, 'Add modifier', addTarget, 98));
		propWidget(new PsychUIButton(PROP_X + 114, PREVIEW_Y + 330, 'Remove modifier', removeTarget, 98));

		targetsListText = propLabel(358, '');
		targetsListText.fieldWidth = PROP_W - 20;
		targetsListText.size = 9;
		targetsListText.color = 0xFFBBBBBB;

		var hint:FlxText = propLabel(420, 'Delete: delete event\nCtrl + C / V: copy / paste at the playhead');
		hint.fieldWidth = PROP_W - 20;
		hint.size = 9;
		hint.color = 0xFF9A9AB0;

		var i:Int = propsWidgets.length;
		while(i-- > 0) add(propsWidgets[i]);
	}

	function propLabel(y:Float, text:String, ?group:Array<FlxSprite>):FlxText
	{
		var label:FlxText = new FlxText(PROP_X + 10, PREVIEW_Y + y + 3, 64, text, 10);
		return propWidget(label, group);
	}

	function propWidget<T:FlxSprite>(widget:T, ?group:Array<FlxSprite>):T
	{
		widget.cameras = [camUI];
		propsWidgets.push(widget);
		if(group != null) group.push(widget);
		return widget;
	}

	function createUpperMenu()
	{
		upperBox = new PsychUIBox(0, 0, 150, 90, ['File']);
		upperBox.scrollFactor.set();
		upperBox.isMinimized = true;
		upperBox.minimizeOnFocusLost = true;
		upperBox.canMove = false;
		upperBox.cameras = [camUI];
		upperBox.bg.visible = false;
		add(upperBox);

		var menu = upperBox.getTab('File').menu;
		var panel:FlxSprite = new FlxSprite().makeGraphic(150, 62, FlxColor.BLACK);
		panel.alpha = 0.8;
		menu.add(panel);

		var entries:Array<Array<Dynamic>> = [
			['  Play / Pause (Space)', function() setPlaying(!FlxG.sound.music.playing)],
			['  Playtest (Enter)', goToPlayState],
			['  Exit (Esc)', goToPlayState]
		];
		for (i => entry in entries)
		{
			var btn:PsychUIButton = new PsychUIButton(0, i * 20, entry[0], entry[1], 150);
			btn.text.alignment = LEFT;
			menu.add(btn);
		}
	}

	function createHelp()
	{
		var hint:FlxText = new FlxText(0, 4, FlxG.width - 10, 'Press F1 for Help', 12);
		hint.setFormat(null, 12, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		hint.cameras = [camUI];
		hint.alpha = 0.6;
		add(hint);

		helpBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		helpBg.scale.set(FlxG.width, FlxG.height);
		helpBg.updateHitbox();
		helpBg.alpha = 0.8;
		helpBg.cameras = [camUI];
		helpBg.visible = false;
		add(helpBg);

		helpText = new FlxText(0, 0, FlxG.width - 160, '', 14);
		helpText.setFormat(null, 14, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		helpText.borderSize = 1;
		helpText.cameras = [camUI];
		helpText.visible = false;
		add(helpText);
	}

	static final HELP_PAGES:Array<String> = [
		"CONTROLS  (page 1/2 - Left/Right to change page)\n\n"
		+ "PLAYBACK\n"
		+ "Space - Play / Pause\n"
		+ "A / D  or  Left / Right - Go back / forward 1 beat (hold Shift: 1 measure)\n"
		+ "Mouse Wheel over the timeline - Scroll through the song (hold Shift: faster)\n"
		+ "Home / End - Go to the start / end of the song\n"
		+ "[ / ] - Change playback speed (Alt + [ or ]: reset)\n"
		+ "Click or drag the bar at the bottom - Jump to any point of the song\n\n"
		+ "TIMELINE\n"
		+ "Ctrl + Mouse Wheel - Zoom the timeline\n"
		+ "Mouse Wheel over the modifier names - Scroll the rows\n"
		+ "Click on an empty spot of the timeline - Jump there\n\n"
		+ "EDITING\n"
		+ "Click on an event - Select it (its settings appear in the Event panel on the right)\n"
		+ "Right click on an empty spot of a row - Create an event for that modifier\n"
		+ "Right click on an event - Remove that modifier from the event (the last one deletes it)\n"
		+ "Drag an event - Move it (hold Alt to ignore the Snap)\n"
		+ "Drag the yellow handle at the end of a selected ease - Change how long it lasts\n"
		+ "Delete / Backspace - Delete the selected event\n"
		+ "Ctrl + C / Ctrl + V - Copy the selected event / Paste it at the playhead\n"
		+ "Ctrl + Z / Ctrl + Y - Undo / Redo\n\n"
		+ "OTHER\n"
		+ "Enter - Playtest the song\n"
		+ "Esc - Deselect the event (with nothing selected: exit the editor)\n"
		+ "F1 - Show / Hide this help",

		"HOW A MODCHART WORKS  (page 2/2 - Left/Right to change page)\n\n"
		+ "A modchart is made of MODIFIERS and EVENTS.\n\n"
		+ "MODIFIERS are the rows of the timeline.\n"
		+ "Each one is an effect with its own name, for example \"drunk\" using the DrunkX effect.\n"
		+ "Next to the name you can see which arrows it affects:\n"
		+ "ALL = every arrow, OPP = opponent (0-3), PLR = player (4-7), L0...L7 = a single arrow.\n"
		+ "The number on the right is the value the modifier has right now.\n\n"
		+ "EVENTS are the marks on each row. They change the value of a modifier at a certain beat.\n"
		+ "A blue diamond is a SET: the value changes instantly.\n"
		+ "A white diamond with a bar is an EASE: the value changes gradually,\n"
		+ "and the bar shows how many beats it takes.\n"
		+ "Faded marks are repeats of the same event.\n\n"
		+ "One event can change more than one modifier at the same time: its mark appears on every row it changes.\n"
		+ "In the Event panel use < and > to go through them, and Add / Remove modifier to change the list.\n"
		+ "Some modifiers have sub values (like the speed of \"drunk\"): pick them from Sub value.\n\n"
		+ "The preview on top always shows the modchart at the current point of the song:\n"
		+ "move through the song to see every effect exactly as it will look in game."
	];

	inline function modchartData():ModchartJson
		return playfieldRenderer.modchart.data;

	function refreshTimelineData()
	{
		var data:ModchartJson = modchartData();

		visibleMods = [];
		for (mod in data.modifiers)
		{
			var pf:Int = parseIntSafe(mod[ModchartFile.MOD_PF], -1);
			if(playfieldFilter < 0 || pf < 0 || pf == playfieldFilter)
				visibleMods.push(mod);
		}

		timelineEvents = [];
		for (i => ev in data.events)
		{
			var parsed:TimelineEvent = parseEvent(i, ev);
			if(parsed != null) timelineEvents.push(parsed);
		}

		if(data.playfields != knownPlayfields)
		{
			knownPlayfields = data.playfields;
			var playfields:Array<String> = ['All'];
			for (i in 0...data.playfields) playfields.push(Std.string(i));
			var lastLabel:String = playfieldDropDown.selectedLabel;
			playfieldDropDown.list = playfields;
			playfieldDropDown.selectedLabel = (lastLabel != null && playfields.contains(lastLabel)) ? lastLabel : 'All';
		}

		rowScroll = Std.int(FlxMath.bound(rowScroll, 0, Math.max(0, visibleMods.length - VISIBLE_ROWS)));
		emptyText.visible = (visibleMods.length == 0);
	}

	function parseEvent(index:Int, ev:Array<Dynamic>):TimelineEvent
	{
		if(ev == null || ev.length < 2) return null;

		var type:String = Std.string(ev[ModchartFile.EVENT_TYPE]);
		var eventData:Array<Dynamic> = ev[ModchartFile.EVENT_DATA];
		if(eventData == null || (type != 'ease' && type != 'set')) return null;

		var parsed:TimelineEvent = {
			index: index,
			type: type,
			beat: parseFloatSafe(eventData[ModchartFile.EVENT_TIME]),
			length: (type == 'ease') ? parseFloatSafe(eventData[ModchartFile.EVENT_EASETIME]) : 0,
			ease: (type == 'ease') ? Std.string(eventData[ModchartFile.EVENT_EASE]) : '',
			targets: readTargets(ev),
			repeatCount: 0,
			repeatGap: 0
		};

		var repeat:Array<Dynamic> = ev[ModchartFile.EVENT_REPEAT];
		if(repeat != null && repeat[ModchartFile.EVENT_REPEATBOOL] == true)
		{
			parsed.repeatCount = parseIntSafe(repeat[ModchartFile.EVENT_REPEATCOUNT], 0);
			parsed.repeatGap = parseFloatSafe(repeat[ModchartFile.EVENT_REPEATBEATGAP]);
		}
		return parsed;
	}

	static function targetsIndex(ev:Array<Dynamic>):Int
		return (ev[ModchartFile.EVENT_TYPE] == 'ease') ? ModchartFile.EVENT_EASEDATA : ModchartFile.EVENT_SETDATA;

	static function readTargets(ev:Array<Dynamic>):Array<TimelineTarget>
	{
		var targets:Array<TimelineTarget> = [];
		var eventData:Array<Dynamic> = ev[ModchartFile.EVENT_DATA];
		if(eventData == null || eventData[targetsIndex(ev)] == null) return targets;

		var parts:Array<String> = Std.string(eventData[targetsIndex(ev)]).split(',');
		for (i in 0...Math.floor(parts.length / 2))
		{
			var name:String = parts[i * 2 + 1].trim();
			if(name.length < 1) continue;

			var split:Array<String> = name.split(':');
			targets.push({mod: split[0], sub: (split.length > 1) ? split[1] : '', value: parts[i * 2].trim()});
		}
		return targets;
	}

	static function writeTargets(ev:Array<Dynamic>, targets:Array<TimelineTarget>)
	{
		var parts:Array<String> = [];
		for (target in targets)
		{
			parts.push(target.value);
			parts.push(target.sub.length > 0 ? target.mod + ':' + target.sub : target.mod);
		}
		ev[ModchartFile.EVENT_DATA][targetsIndex(ev)] = parts.join(',');
	}

	static function repeatData(ev:Array<Dynamic>):Array<Dynamic>
	{
		if(ev[ModchartFile.EVENT_REPEAT] == null)
		{
			var repeat:Array<Dynamic> = [false, 1, 0];
			ev[ModchartFile.EVENT_REPEAT] = repeat;
		}
		return ev[ModchartFile.EVENT_REPEAT];
	}

	static function parseFloatSafe(value:Dynamic):Float
	{
		var result:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(result) ? 0 : result;
	}

	static function parseIntSafe(value:Dynamic, fallback:Int):Int
	{
		var result:Null<Int> = Std.parseInt(Std.string(value));
		return (result == null) ? fallback : result;
	}

	inline function gridX():Float return PANEL_X + LABEL_W;
	inline function gridW():Float return PANEL_W - LABEL_W;
	inline function rowY(row:Int):Float return PANEL_Y + RULER_H + row * ROW_H;
	inline function playheadX():Float return gridX() + gridW() * PLAYHEAD_RATIO;
	inline function currentBeat():Float return Conductor.getBeat(Conductor.songPosition);
	inline function beatToX(beat:Float):Float return playheadX() + (beat - currentBeat()) * pixelsPerBeat;
	inline function xToBeat(x:Float):Float return currentBeat() + (x - playheadX()) / pixelsPerBeat;

	function snapBeat(beat:Float):Float
	{
		beat = Math.max(0, beat);
		if(snap <= 0 || FlxG.keys.pressed.ALT) return FlxMath.roundDecimal(beat, 3);
		return FlxMath.roundDecimal(Math.round(beat / snap) * snap, 4);
	}

	override function update(elapsed:Float)
	{
		if(FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		var bpmChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
		var bpm:Float = (bpmChange.songTime <= 0) ? PlayState.SONG.bpm : bpmChange.bpm;
		if(bpm != Conductor.bpm) Conductor.bpm = bpm;

		super.update(elapsed);

		if(PsychUIInputText.focusOn != lastFocus) editTag = null;

		if(helpBg.visible) updateHelpInput();
		else
		{
			if(PsychUIInputText.focusOn == null && lastFocus == null) updateKeys();
			updateMouse();
		}
		lastFocus = PsychUIInputText.focusOn;

		playfieldRenderer.speed = playbackSpeed;
		FlxG.sound.music.pitch = playbackSpeed;
		vocals.pitch = playbackSpeed;
		opponentVocals.pitch = playbackSpeed;

		updateNotes();

		if(dirtyNotes)
		{
			for (note in notes.members.copy())
				if(note != null) notes.remove(note, true);
			unspawnNotes = [for (note in loadedNotes) if(note.strumTime + 350 >= Conductor.songPosition) note];
			for (note in unspawnNotes)
			{
				note.active = true;
				note.visible = true;
				note.wasGoodHit = false;
			}
			dirtyNotes = false;
		}

		if(dirtyEvents)
		{
			FlxTween.globalManager.completeAll();
			playfieldRenderer.tweenManager.completeAll();
			playfieldRenderer.eventManager.clearEvents();
			playfieldRenderer.modifierTable.resetMods();
			playfieldRenderer.modchart.loadEvents();
			playfieldRenderer.update(0);
			dirtyEvents = false;
		}

		updateTimeline();
		updatePlaybar();
		updateInfo();
	}

	function updateKeys()
	{
		if(FlxG.keys.justPressed.F1)
		{
			showHelp(true);
			return;
		}

		if(FlxG.keys.pressed.CONTROL)
		{
			if(dragMode == DRAG_NONE)
			{
				if(FlxG.keys.justPressed.Z)
				{
					if(FlxG.keys.pressed.SHIFT) redo();
					else undo();
				}
				else if(FlxG.keys.justPressed.Y) redo();
			}
			if(FlxG.keys.justPressed.C) copyEvent();
			if(FlxG.keys.justPressed.V) pasteEvent();
			return;
		}

		if(FlxG.keys.justPressed.ESCAPE)
		{
			if(selectedEvent >= 0) selectEvent(-1);
			else goToPlayState();
			return;
		}

		if(FlxG.keys.justPressed.ENTER)
		{
			goToPlayState();
			return;
		}

		if(FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE)
			deleteEvent(selectedEvent);

		if(FlxG.keys.justPressed.SPACE)
			setPlaying(!FlxG.sound.music.playing);

		var beatStep:Float = FlxG.keys.pressed.SHIFT ? 4 : 1;
		if(FlxG.keys.justPressed.D || FlxG.keys.justPressed.RIGHT)
			seekToBeat(Math.floor(currentBeat() / beatStep + 0.001) * beatStep + beatStep);
		if(FlxG.keys.justPressed.A || FlxG.keys.justPressed.LEFT)
			seekToBeat(Math.ceil(currentBeat() / beatStep - 0.001) * beatStep - beatStep);

		if(FlxG.keys.justPressed.HOME) seekTo(0);
		if(FlxG.keys.justPressed.END) seekTo(FlxG.sound.music.length - 1);

		if(FlxG.keys.pressed.ALT && (FlxG.keys.justPressed.LBRACKET || FlxG.keys.justPressed.RBRACKET))
			setPlaybackSpeed(1);
		else if(FlxG.keys.justPressed.LBRACKET)
			setPlaybackSpeed(playbackSpeed - 0.05);
		else if(FlxG.keys.justPressed.RBRACKET)
			setPlaybackSpeed(playbackSpeed + 0.05);
	}

	function updateMouse()
	{
		var mx:Float = FlxG.mouse.screenX;
		var my:Float = FlxG.mouse.screenY;
		var overLabels:Bool = (mx >= PANEL_X && mx < gridX() && my >= PANEL_Y && my < rowY(VISIBLE_ROWS));
		var overGrid:Bool = (mx >= gridX() && mx < gridX() + gridW() && my >= PANEL_Y && my < rowY(VISIBLE_ROWS));
		var overRows:Bool = (overGrid && my >= rowY(0));
		var overPlaybar:Bool = (mx >= PANEL_X && mx < PANEL_X + PANEL_W && my >= PLAYBAR_Y - 4 && my < PLAYBAR_Y + PLAYBAR_H + 4);

		if(FlxG.mouse.wheel != 0)
		{
			if(overLabels)
				rowScroll = Std.int(FlxMath.bound(rowScroll - FlxG.mouse.wheel, 0, Math.max(0, visibleMods.length - VISIBLE_ROWS)));
			else if(overGrid && FlxG.keys.pressed.CONTROL)
				pixelsPerBeat = FlxMath.bound(pixelsPerBeat * Math.pow(1.2, FlxG.mouse.wheel), MIN_ZOOM, MAX_ZOOM);
			else if(overGrid)
				seekToBeat(currentBeat() - FlxG.mouse.wheel * (FlxG.keys.pressed.SHIFT ? 1 : 0.25));
		}

		if(dragMode != DRAG_NONE)
		{
			updateDrag(mx);
			return;
		}

		if(FlxG.mouse.justPressed)
		{
			if(overPlaybar)
			{
				startDrag(DRAG_PLAYBAR, -1, mx);
				updateDrag(mx);
			}
			else if(overGrid)
			{
				var handle:TimelineHit = findHit(resizeHits, mx, my, 5, 8);
				var hit:TimelineHit = findHit(hits, mx, my, 7, 9);
				if(handle != null)
					startDrag(DRAG_RESIZE, handle.event, mx);
				else if(hit != null)
				{
					selectEvent(hit.event, hit.mod);
					startDrag(DRAG_MOVE, hit.event, mx);
					dragOffset = xToBeat(mx) - eventBeat(hit.event);
				}
				else
				{
					selectEvent(-1);
					seekToBeat(Math.max(0, xToBeat(mx)));
				}
			}
		}
		else if(FlxG.mouse.justPressedRight && overRows)
		{
			PsychUIInputText.focusOn = null;
			var hit:TimelineHit = findHit(hits, mx, my, 7, 9);
			if(hit != null) removeFromEvent(hit.event, hit.mod);
			else
			{
				var mod:Array<Dynamic> = visibleMods[rowScroll + Math.floor((my - rowY(0)) / ROW_H)];
				if(mod != null) createEvent(snapBeat(xToBeat(mx)), Std.string(mod[ModchartFile.MOD_NAME]));
			}
		}
	}

	function startDrag(mode:Int, event:Int, mx:Float)
	{
		dragMode = mode;
		dragEvent = event;
		dragStartX = mx;
		dragMoved = false;
		editTag = null;
	}

	function updateDrag(mx:Float)
	{
		if(!FlxG.mouse.pressed)
		{
			dragMode = DRAG_NONE;
			editTag = null;
			return;
		}

		if(dragMode == DRAG_PLAYBAR)
		{
			var ratio:Float = FlxMath.bound((mx - PANEL_X) / PANEL_W, 0, 1);
			var target:Float = ratio * FlxG.sound.music.length;
			if(Math.abs(target - FlxG.sound.music.time) > 5) seekTo(target);
			return;
		}

		if(!dragMoved && Math.abs(mx - dragStartX) < 4) return;
		dragMoved = true;

		var ev:Array<Dynamic> = modchartData().events[dragEvent];
		if(ev == null)
		{
			dragMode = DRAG_NONE;
			return;
		}

		var eventData:Array<Dynamic> = ev[ModchartFile.EVENT_DATA];
		if(dragMode == DRAG_MOVE)
		{
			var beat:Float = snapBeat(xToBeat(mx) - dragOffset);
			if(beat != parseFloatSafe(eventData[ModchartFile.EVENT_TIME]))
				applyEdit('drag', function() { eventData[ModchartFile.EVENT_TIME] = beat; });
		}
		else
		{
			var length:Float = FlxMath.roundDecimal(Math.max(0, snapBeat(xToBeat(mx)) - parseFloatSafe(eventData[ModchartFile.EVENT_TIME])), 4);
			if(length != parseFloatSafe(eventData[ModchartFile.EVENT_EASETIME]))
				applyEdit('drag', function() { eventData[ModchartFile.EVENT_EASETIME] = length; });
		}
	}

	static function findHit(list:Array<TimelineHit>, mx:Float, my:Float, rangeX:Float, rangeY:Float):TimelineHit
	{
		var found:TimelineHit = null;
		for (candidate in list)
			if(Math.abs(candidate.x - mx) <= rangeX && Math.abs(candidate.y - my) <= rangeY) found = candidate;
		return found;
	}

	function eventBeat(index:Int):Float
	{
		var ev:Array<Dynamic> = modchartData().events[index];
		return (ev != null) ? parseFloatSafe(ev[ModchartFile.EVENT_DATA][ModchartFile.EVENT_TIME]) : 0;
	}

	function selectedData():Array<Dynamic>
	{
		var events:Array<Array<Dynamic>> = modchartData().events;
		return (selectedEvent >= 0 && selectedEvent < events.length) ? events[selectedEvent] : null;
	}

	function selectEvent(index:Int, ?mod:String)
	{
		selectedEvent = index;
		curTarget = 0;
		editTag = null;

		var ev:Array<Dynamic> = selectedData();
		if(ev != null && mod != null)
		{
			var targets:Array<TimelineTarget> = readTargets(ev);
			for (i in 0...targets.length)
			{
				if(targets[i].mod != mod) continue;
				curTarget = i;
				break;
			}
		}
		refreshProps();
	}

	function applyEdit(tag:String, change:Void->Void)
	{
		var before:String = Json.stringify(modchartData());
		change();
		if(Json.stringify(modchartData()) == before) return;

		if(tag == null || tag != editTag) pushUndoState(before);
		editTag = tag;
		commit();
	}

	function editSelected(tag:String, change:Array<Dynamic>->Void)
	{
		var ev:Array<Dynamic> = selectedData();
		if(ev == null) return;
		applyEdit((tag != null) ? tag + selectedEvent : null, function() change(ev));
	}

	function editTarget(tag:String, change:TimelineTarget->Void)
	{
		var ev:Array<Dynamic> = selectedData();
		if(ev == null) return;

		var targets:Array<TimelineTarget> = readTargets(ev);
		if(curTarget >= targets.length) return;

		applyEdit((tag != null) ? tag + selectedEvent + '_' + curTarget : null, function() {
			change(targets[curTarget]);
			writeTargets(ev, targets);
		});
	}

	function commit()
	{
		refreshTimelineData();
		refreshProps();
		dirtyEvents = true;
	}

	function createEvent(beat:Float, mod:String)
	{
		var template:Array<Dynamic> = selectedData();
		var eventData:Array<Dynamic>;
		var type:String = 'ease';
		if(template != null && template[ModchartFile.EVENT_TYPE] == 'set')
		{
			type = 'set';
			eventData = [beat, ''];
		}
		else
		{
			var length:Dynamic = (template != null) ? template[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASETIME] : 1;
			var ease:Dynamic = (template != null) ? template[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASE] : 'cubeInOut';
			eventData = [beat, length, ease, ''];
		}

		var repeat:Array<Dynamic> = [false, 1, 1];
		var ev:Array<Dynamic> = [type, eventData, repeat];
		writeTargets(ev, [{mod: mod, sub: '', value: '1'}]);

		var events:Array<Array<Dynamic>> = modchartData().events;
		applyEdit(null, function() { events.push(ev); });
		selectEvent(events.length - 1, mod);
	}

	function deleteEvent(index:Int)
	{
		var events:Array<Array<Dynamic>> = modchartData().events;
		if(index < 0 || index >= events.length) return;

		applyEdit(null, function() {
			events.splice(index, 1);
			if(selectedEvent == index) selectedEvent = -1;
			else if(selectedEvent > index) selectedEvent--;
		});
		selectEvent(selectedEvent);
	}

	function removeFromEvent(index:Int, mod:String)
	{
		var ev:Array<Dynamic> = modchartData().events[index];
		if(ev == null) return;

		var remaining:Array<TimelineTarget> = [for (target in readTargets(ev)) if(target.mod != mod) target];
		if(remaining.length == 0)
		{
			deleteEvent(index);
			return;
		}
		applyEdit(null, function() writeTargets(ev, remaining));
		if(selectedEvent == index) selectEvent(index);
	}

	function setEventType(type:String)
	{
		editSelected(null, function(ev:Array<Dynamic>) {
			if(ev[ModchartFile.EVENT_TYPE] == type) return;

			var targets:Array<TimelineTarget> = readTargets(ev);
			var time:Dynamic = ev[ModchartFile.EVENT_DATA][ModchartFile.EVENT_TIME];
			var eventData:Array<Dynamic> = (type == 'ease') ? [time, 1, 'cubeInOut', ''] : [time, ''];
			ev[ModchartFile.EVENT_TYPE] = type;
			ev[ModchartFile.EVENT_DATA] = eventData;
			writeTargets(ev, targets);
		});
	}

	function addTarget()
	{
		var ev:Array<Dynamic> = selectedData();
		if(ev == null || modchartData().modifiers.length < 1) return;

		var targets:Array<TimelineTarget> = readTargets(ev);
		var used:Array<String> = [for (target in targets) target.mod];
		var name:String = Std.string(modchartData().modifiers[0][ModchartFile.MOD_NAME]);
		for (mod in modchartData().modifiers)
		{
			var modName:String = Std.string(mod[ModchartFile.MOD_NAME]);
			if(used.contains(modName)) continue;
			name = modName;
			break;
		}

		targets.push({mod: name, sub: '', value: '1'});
		curTarget = targets.length - 1;
		applyEdit(null, function() writeTargets(ev, targets));
	}

	function removeTarget()
	{
		var ev:Array<Dynamic> = selectedData();
		if(ev == null) return;

		var targets:Array<TimelineTarget> = readTargets(ev);
		if(targets.length <= 1 || curTarget >= targets.length) return;

		targets.splice(curTarget, 1);
		curTarget = Std.int(Math.min(curTarget, targets.length - 1));
		applyEdit(null, function() writeTargets(ev, targets));
	}

	function changeTarget(change:Int)
	{
		var ev:Array<Dynamic> = selectedData();
		if(ev == null) return;

		var count:Int = readTargets(ev).length;
		if(count < 1) return;
		curTarget = FlxMath.wrap(curTarget + change, 0, count - 1);
		editTag = null;
		refreshProps();
	}

	function copyEvent()
	{
		var ev:Array<Dynamic> = selectedData();
		if(ev != null) clipboard = Json.stringify(ev);
	}

	function pasteEvent()
	{
		if(clipboard == null) return;

		var ev:Array<Dynamic> = Json.parse(clipboard);
		ev[ModchartFile.EVENT_DATA][ModchartFile.EVENT_TIME] = snapBeat(currentBeat());

		var events:Array<Array<Dynamic>> = modchartData().events;
		applyEdit(null, function() { events.push(ev); });
		selectEvent(events.length - 1);
	}

	function pushUndoState(state:String)
	{
		undoStack.push(state);
		if(undoStack.length > MAX_UNDO) undoStack.shift();
		redoStack = [];
	}

	function undo()
	{
		if(undoStack.length < 1) return;
		redoStack.push(Json.stringify(modchartData()));
		restoreData(undoStack.pop());
	}

	function redo()
	{
		if(redoStack.length < 1) return;
		undoStack.push(Json.stringify(modchartData()));
		restoreData(redoStack.pop());
	}

	function restoreData(state:String)
	{
		var modchart:ModchartFile = playfieldRenderer.modchart;
		var oldModifiers:String = Json.stringify(modchart.data.modifiers);
		var oldPlayfields:Int = modchart.data.playfields;

		modchart.data = cast Json.parse(state);
		if(modchart.data.playfields != oldPlayfields) modchart.loadPlayfields();
		if(Json.stringify(modchart.data.modifiers) != oldModifiers) modchart.loadModifiers();

		editTag = null;
		if(selectedEvent >= modchart.data.events.length) selectedEvent = -1;
		commit();
	}

	function refreshProps()
	{
		var ev:Array<Dynamic> = selectedData();
		propsEmptyText.visible = (ev == null);
		for (widget in propsWidgets) setWidgetShown(widget, ev != null);
		if(ev == null) return;

		var isEase:Bool = (ev[ModchartFile.EVENT_TYPE] == 'ease');
		for (widget in easeWidgets) setWidgetShown(widget, isEase);

		var eventData:Array<Dynamic> = ev[ModchartFile.EVENT_DATA];
		setDropDown(typeDropDown, Std.string(ev[ModchartFile.EVENT_TYPE]));
		setStepper(beatStepper, parseFloatSafe(eventData[ModchartFile.EVENT_TIME]));
		if(isEase)
		{
			setStepper(lengthStepper, parseFloatSafe(eventData[ModchartFile.EVENT_EASETIME]));
			setDropDown(easeDropDown, Std.string(eventData[ModchartFile.EVENT_EASE]));
		}

		var repeat:Array<Dynamic> = ev[ModchartFile.EVENT_REPEAT];
		repeatCheckBox.checked = (repeat != null && repeat[ModchartFile.EVENT_REPEATBOOL] == true);
		setStepper(repeatCountStepper, (repeat != null) ? parseFloatSafe(repeat[ModchartFile.EVENT_REPEATCOUNT]) : 1);
		setStepper(repeatGapStepper, (repeat != null) ? parseFloatSafe(repeat[ModchartFile.EVENT_REPEATBEATGAP]) : 1);

		var names:Array<String> = [for (mod in modchartData().modifiers) Std.string(mod[ModchartFile.MOD_NAME])];
		var joined:String = names.join('\n');
		if(joined != knownModNames)
		{
			knownModNames = joined;
			targetModDropDown.list = names;
		}

		var targets:Array<TimelineTarget> = readTargets(ev);
		curTarget = Std.int(FlxMath.bound(curTarget, 0, Math.max(0, targets.length - 1)));
		targetCountText.text = (targets.length > 0) ? 'Modifier ${curTarget + 1} of ${targets.length}' : 'No modifiers';

		var target:TimelineTarget = targets[curTarget];
		if(target != null)
		{
			setDropDown(targetModDropDown, target.mod);
			if(target.mod != knownSubMod)
			{
				knownSubMod = target.mod;
				var subs:Array<String> = [MAIN_VALUE];
				var live = playfieldRenderer.modifierTable.modifiers.get(target.mod);
				if(live != null)
					for (key in live.subValues.keys()) subs.push(key);
				targetSubDropDown.list = subs;
			}
			setDropDown(targetSubDropDown, (target.sub.length > 0) ? target.sub : MAIN_VALUE);
			if(PsychUIInputText.focusOn != targetValueInput) targetValueInput.text = target.value;
		}

		var lines:Array<String> = [];
		for (i => entry in targets)
			lines.push(((i == curTarget) ? '> ' : '   ') + entry.mod + ((entry.sub.length > 0) ? ':' + entry.sub : '') + ' = ' + entry.value);
		targetsListText.text = lines.join('\n');
	}

	static function setWidgetShown(widget:FlxSprite, shown:Bool)
	{
		widget.visible = shown;
		widget.active = shown;
	}

	static function setStepper(stepper:PsychUINumericStepper, value:Float)
	{
		if(PsychUIInputText.focusOn != stepper) stepper.value = value;
	}

	static function setDropDown(dropDown:PsychUIDropDownMenu, label:String)
	{
		if(PsychUIInputText.focusOn != dropDown) dropDown.selectedLabel = label;
	}

	function updateHelpInput()
	{
		if(FlxG.keys.justPressed.F1 || FlxG.keys.justPressed.ESCAPE)
			showHelp(false);
		else if(FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.RIGHT)
		{
			helpPage = (helpPage + 1) % HELP_PAGES.length;
			showHelp(true);
		}
	}

	function showHelp(show:Bool)
	{
		helpBg.visible = helpText.visible = show;
		if(!show) return;

		helpText.text = HELP_PAGES[helpPage];
		helpText.screenCenter();
	}

	function setPlaying(play:Bool)
	{
		if(play)
		{
			for (sound in [vocals, opponentVocals])
			{
				if(sound.length <= 0) continue;
				sound.play();
				sound.pause();
				sound.time = FlxG.sound.music.time;
				if(sound.time < sound.length) sound.play();
			}
			FlxG.sound.music.play();
			playfieldRenderer.editorPaused = false;
			dirtyNotes = true;
			dirtyEvents = true;
		}
		else
		{
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
			playfieldRenderer.editorPaused = true;
		}
	}

	function seekTo(time:Float)
	{
		if(FlxG.sound.music.playing) setPlaying(false);

		time = FlxMath.bound(time, 0, FlxG.sound.music.length - 1);
		FlxG.sound.music.time = time;
		vocals.time = time;
		opponentVocals.time = time;
		Conductor.songPosition = time;
		dirtyNotes = true;
		dirtyEvents = true;
	}

	inline function seekToBeat(beat:Float)
		seekTo(ModchartUtil.getTimeFromBeat(Math.max(0, beat)));

	function setPlaybackSpeed(speed:Float)
	{
		playbackSpeed = FlxMath.roundDecimal(FlxMath.bound(speed, 0.5, 3), 2);
		dirtyEvents = true;
	}

	function updateNotes()
	{
		var spawnTime:Float = 2000;
		if(PlayState.SONG.speed < 1) spawnTime /= PlayState.SONG.speed;

		while(unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < spawnTime)
		{
			var note:Note = unspawnNotes.shift();
			notes.insert(0, note);
			note.spawned = true;
		}

		var killOffset:Float = 350 / PlayState.SONG.speed;
		for (note in notes.members.copy())
		{
			if(note == null || !note.alive) continue;

			if(Conductor.songPosition >= note.strumTime && !note.wasGoodHit)
			{
				note.wasGoodHit = true;
				var strum:StrumNote = strumLineNotes.members[note.noteData + (note.mustPress ? NoteMovement.keyCount : 0)];
				if(strum != null)
				{
					strum.playAnim('confirm', true);
					strum.resetAnim = (note.isSustainNote && note.animation.curAnim != null && !note.animation.curAnim.name.endsWith('end')) ? 0.3 : 0.15;
				}
				if(!note.isSustainNote) notes.remove(note, true);
			}
			else if(Conductor.songPosition > killOffset + note.strumTime)
				notes.remove(note, true);
		}
	}

	function updateTimeline()
	{
		hits = [];
		resizeHits = [];
		var lineIndex:Int = 0;
		var rulerIndex:Int = 0;
		var diamondIndex:Int = 0;
		var barIndex:Int = 0;

		var left:Float = gridX();
		var right:Float = gridX() + gridW();
		var firstBeat:Int = Std.int(Math.max(0, Math.floor(xToBeat(left))));
		var lastBeat:Int = Math.ceil(xToBeat(right));
		var subdivisions:Int = (pixelsPerBeat >= 80) ? 4 : 1;

		for (beat in firstBeat...lastBeat + 1)
		{
			for (sub in 0...subdivisions)
			{
				var x:Float = beatToX(beat + sub / subdivisions);
				if(x < left || x >= right) continue;

				var isMeasure:Bool = (sub == 0 && beat % 4 == 0);
				var line:FlxSprite = pooledLine(lineIndex++);
				line.x = x;
				line.y = (sub == 0) ? PANEL_Y : PANEL_Y + RULER_H;
				line.scale.y = (sub == 0) ? RULER_H + VISIBLE_ROWS * ROW_H : VISIBLE_ROWS * ROW_H;
				line.updateHitbox();
				line.color = isMeasure ? 0xFF6E6E88 : (sub == 0 ? 0xFF474758 : 0xFF33333F);
			}

			var x:Float = beatToX(beat);
			if(x >= left && x < right - 20 && (pixelsPerBeat >= 30 || beat % 4 == 0))
			{
				var text:FlxText = pooledRuler(rulerIndex++);
				text.text = Std.string(beat);
				text.x = x + 3;
				text.color = (beat % 4 == 0) ? FlxColor.WHITE : 0xFF9A9AB0;
			}
		}

		var rowByName:Map<String, Int> = [];
		for (i in 0...VISIBLE_ROWS)
		{
			var mod:Array<Dynamic> = visibleMods[rowScroll + i];
			if(mod == null)
			{
				rowLabels[i].text = '';
				rowValues[i].text = '';
				continue;
			}

			var name:String = Std.string(mod[ModchartFile.MOD_NAME]);
			rowByName.set(name, i);
			rowLabels[i].text = name + '  ' + targetLabel(mod);

			var live = playfieldRenderer.modifierTable.modifiers.get(name);
			rowValues[i].text = (live != null) ? Std.string(FlxMath.roundDecimal(live.currentValue, 2)) : '';
		}

		var total:Int = visibleMods.length;
		rowsInfoText.text = (total > VISIBLE_ROWS) ? 'Modifiers ${rowScroll + 1}-${Std.int(Math.min(total, rowScroll + VISIBLE_ROWS))} of $total' : 'Modifiers: $total';

		for (ev in timelineEvents)
		{
			var isSelected:Bool = (ev.index == selectedEvent);
			for (occurrence in 0...ev.repeatCount + 1)
			{
				var beat:Float = ev.beat + occurrence * ev.repeatGap;
				var startX:Float = beatToX(beat);
				var endX:Float = startX + ev.length * pixelsPerBeat;
				if(endX < left - 6 || startX >= right) continue;

				var alpha:Float = (occurrence == 0) ? 1 : 0.4;
				var color:FlxColor = isSelected ? COLOR_SELECTED : (ev.type == 'ease' ? COLOR_EASE : COLOR_SET);

				for (target in ev.targets)
				{
					if(!rowByName.exists(target.mod)) continue;
					var centerY:Float = rowY(rowByName.get(target.mod)) + ROW_H / 2;

					if(ev.type == 'ease' && ev.length > 0)
					{
						var barStart:Float = Math.max(startX, left);
						var barEnd:Float = Math.min(endX, right);
						if(barEnd > barStart)
						{
							var bar:FlxSprite = pooledBar(barIndex++);
							bar.x = barStart;
							bar.y = centerY - 2;
							bar.scale.set(barEnd - barStart, 1);
							bar.updateHitbox();
							bar.color = color;
							bar.alpha = 0.45 * alpha;
						}
					}

					if(isSelected && occurrence == 0 && ev.type == 'ease' && endX - startX >= 8 && endX >= left && endX < right)
					{
						var handle:FlxSprite = pooledBar(barIndex++);
						handle.x = endX - 1;
						handle.y = centerY - 6;
						handle.scale.set(3, 3);
						handle.updateHitbox();
						handle.color = COLOR_SELECTED;
						handle.alpha = 1;
						resizeHits.push({x: endX, y: centerY, event: ev.index, mod: target.mod});
					}

					if(startX >= left && startX < right)
					{
						var diamond:FlxSprite = pooledDiamond(diamondIndex++);
						diamond.x = startX - diamond.width / 2;
						diamond.y = centerY - diamond.height / 2;
						diamond.color = color;
						diamond.alpha = alpha;
						if(occurrence == 0) hits.push({x: startX, y: centerY, event: ev.index, mod: target.mod});
					}
				}
			}
		}

		hidePool(linePool, lineIndex);
		hidePool(rulerPool, rulerIndex);
		hidePool(diamondPool, diamondIndex);
		hidePool(barPool, barIndex);
	}

	function targetLabel(mod:Array<Dynamic>):String
	{
		var type:String = Std.string(mod[ModchartFile.MOD_TYPE]).toLowerCase();
		var label:String = switch(type)
		{
			case 'player': 'PLR';
			case 'opponent': 'OPP';
			case 'lane' | 'lanespecific': 'L' + parseIntSafe(mod[ModchartFile.MOD_LANE], 0);
			default: 'ALL';
		}
		var pf:Int = parseIntSafe(mod[ModchartFile.MOD_PF], -1);
		return (pf >= 0) ? '($label PF$pf)' : '($label)';
	}

	function pooledLine(index:Int):FlxSprite
	{
		if(index >= linePool.length)
		{
			var line:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
			line.origin.set(0, 0);
			linePool.push(line);
			timelineLayer.add(line);
		}
		var line:FlxSprite = linePool[index];
		line.visible = true;
		return line;
	}

	function pooledRuler(index:Int):FlxText
	{
		if(index >= rulerPool.length)
		{
			var text:FlxText = new FlxText(0, PANEL_Y + 2, 0, '', 10);
			text.cameras = [camUI];
			rulerPool.push(text);
			add(text);
		}
		var text:FlxText = rulerPool[index];
		text.visible = true;
		return text;
	}

	function pooledDiamond(index:Int):FlxSprite
	{
		if(index >= diamondPool.length)
		{
			var diamond:FlxSprite = new FlxSprite().makeGraphic(10, 10, FlxColor.WHITE);
			diamond.angle = 45;
			diamondPool.push(diamond);
			timelineLayer.add(diamond);
		}
		var diamond:FlxSprite = diamondPool[index];
		diamond.visible = true;
		return diamond;
	}

	function pooledBar(index:Int):FlxSprite
	{
		if(index >= barPool.length)
		{
			var bar:FlxSprite = new FlxSprite().makeGraphic(1, 4, FlxColor.WHITE);
			bar.origin.set(0, 0);
			barPool.push(bar);
			timelineLayer.insert(0, bar);
		}
		var bar:FlxSprite = barPool[index];
		bar.visible = true;
		return bar;
	}

	static function hidePool<T:FlxSprite>(pool:Array<T>, used:Int)
	{
		for (i in used...pool.length)
			pool[i].visible = false;
	}

	function updatePlaybar()
	{
		var length:Float = FlxG.sound.music.length;
		var ratio:Float = (length > 0) ? FlxMath.bound(FlxG.sound.music.time / length, 0, 1) : 0;
		playbarFill.scale.x = Math.max(1, PANEL_W * ratio);
		playbarFill.updateHitbox();
		playbarHead.x = PANEL_X + PANEL_W * ratio - playbarHead.width / 2;
	}

	function updateInfo()
	{
		var beat:Float = currentBeat();
		infoText.text = [
			FlxStringUtil.formatTime(Conductor.songPosition / 1000, true) + ' / ' + FlxStringUtil.formatTime(FlxG.sound.music.length / 1000, true),
			'',
			'Section: ' + Math.floor(beat / 4),
			'Beat: ' + FlxMath.roundDecimal(beat, 2),
			'Step: ' + Math.floor(beat * 4),
			'BPM: ' + Conductor.bpm,
			'Speed: ' + playbackSpeed + 'x   Zoom: ' + Math.round(pixelsPerBeat) + ' px/beat',
			'',
			'Events: ' + modchartData().events.length,
			'Undo: ' + undoStack.length + '   Redo: ' + redoStack.length
		].join('\n');
	}

	function goToPlayState()
	{
		FlxG.mouse.visible = false;
		FlxG.sound.music.stop();
		vocals.stop();
		opponentVocals.stop();
		funkin.data.StageData.loadDirectory(PlayState.SONG);
		LoadingState.loadAndSwitchState(new PlayState());
	}
}
