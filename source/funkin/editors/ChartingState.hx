package funkin.editors;

import flixel.FlxSubState;
import flixel.util.FlxSave;
import flixel.util.FlxSort;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxStringUtil;
import flixel.util.FlxDestroyUtil;
import flixel.input.keyboard.FlxKey;

import lime.utils.Assets;
import lime.media.AudioBuffer;

import flash.media.Sound;
import flash.geom.Rectangle;

import haxe.Json;
import haxe.Exception;
import haxe.io.Bytes;

import openfl.display.BitmapData;

import funkin.editors.content.MetaNote;
import funkin.editors.content.VSlice;
import funkin.editors.content.VSlice.VSliceChart;
import funkin.editors.content.VSlice.VSliceMetadata;
import funkin.editors.content.VSlice.PsychPackage;
import funkin.editors.content.Prompt;
import funkin.editors.content.NewChartPrompt;
import funkin.editors.content.SongAudioPrompt;
import flash.net.FileFilter;
import funkin.editors.content.*;
import funkin.editors.content.CreateStrumlinePrompt.StrumlineConfigData;
import funkin.editors.content.Prompt.BasePrompt;

import funkin.data.Song;
import funkin.data.WeekData;
import funkin.data.WeekData.WeekFile;
import funkin.data.StageData;
import funkin.save.Highscore;
import funkin.data.Difficulty;
import funkin.backend.StateManager;
import funkin.util.CursorLoader.PointerCursor;
import funkin.util.CursorLoader.GrabbingCursor;
import funkin.util.CursorLoader.CellCursor;

import funkin.game.Character;
import funkin.ui.HealthIcon;
import funkin.game.notes.Note;
import funkin.game.notes.StrumNote;

using DateTools;

typedef UndoStruct = {
	var action:UndoAction;
	var data:Dynamic;
}

enum abstract UndoAction(String)
{
	var ADD_NOTE = 'Add Note';
	var DELETE_NOTE = 'Delete Note';
	var MOVE_NOTE = 'Move Note';
	var SELECT_NOTE = 'Select Note';
}

enum abstract ChartingTheme(String)
{
	var LIGHT = 'light';
	var DARK = 'dark';
	var DEFAULT = 'default';
	var VSLICE = 'vslice';
	var CUSTOM = 'custom';
}

class ChartingState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	public static var goToTime:Float = 0;
	public static final defaultEvents:Array<Array<String>> =
	[
		['', "Nothing. Yep, that's right."], //Always leave this one empty pls
		['Dadbattle Spotlight', "Used in Dad Battle,\nValue 1: 0/1 = ON/OFF,\n2 = Target Dad\n3 = Target BF"],
		['Hey!', "Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s"],
		['Set GF Speed', "Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"],
		['Philly Glow', "Exclusive to Week 3\nValue 1: 0/1/2 = OFF/ON/Reset Gradient\n \nNo, i won't add it to other weeks."],
		['Kill Henchmen', "For Mom's songs, don't use this please, i love them :("],
		['Add Camera Zoom', "Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."],
		['BG Freaks Expression', "Should be used only in \"school\" Stage!"],
		['Trigger BG Ghouls', "Should be used only in \"schoolEvil\" Stage!"],
		['Play Animation', "Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)\nOr strumline number (3, 4, 5...)"],
		['Target Follow Pos', "Locks camera to a specific position or character.\n\nValue 1: Position or Target\n- BF, GF, Dad (follows character)\n- Or absolute position: X, Y (e.g., 400, 800)\n- Leave empty to unlock and return to normal\n\nValue 2: Tween settings or instant\n- Leave empty or 'instant' for instant movement\n- Format: duration, easeName\n- Example: 1.5, sineInOut\n- Available eases: linear, quadIn, quadOut, quadInOut, cubeIn, cubeOut, cubeInOut, sineIn, sineOut, sineInOut, etc.\n\nNote: Camera stays locked until you clear it (empty Value 1) or use Target Camera event"],
		['Camera Follow Pos', "Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank."],
		['Alt Idle Animation', "Sets a specified postfix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF, GF)\nOr strumline number (3, 4, 5...)\nValue 2: New postfix (Leave it blank to disable)"],
		['Screen Shake', "Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."],
		['Change Character', "Value 1: Character to change\n- Dad, BF, GF\n- Or strumline number (3, 4, 5...)\nValue 2: New character's name"],
		['Change Scroll Speed', "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."],
		['Set Property', "Value 1: Variable name\nValue 2: New value"],
		['Play Sound', "Value 1: Sound file name\nValue 2: Volume (Default: 1), ranges from 0 to 1"],
		['Flash Camera', "Value 1: Duration in seconds (Default: 1)\nValue 2: Color name or hex code (#FFFFFF)\nSupported colors: white, black, red, green, blue, yellow, cyan, magenta, purple, orange, pink, lime, gray, brown"],
		['Video Player', "Plays a video file.\n\nValue 1: Video Name, Camera, Layer\n- Format: videoName, camera, layer\n- Example: cutscene1, hud, 0\n- Camera options: game, hud, other (default: other)\n- Layer: number (0 = bottom, leave empty for default)\n\nValue 2: Can Skip, Mid-Song, Loop, Play On Load\n- Format: true/false, true/false, true/false, true/false\n- Example: false, true, false, true\n- Can Skip: allows skipping (default: false)\n- Mid-Song: continues music during video (default: true)\n- Loop: repeats video (default: false)\n- Play On Load: auto-play (default: true)"],
		['Set Cam Zoom', "Value 1: Camera zoom level\n- Example: 1.05\n\nValue 2: Tween settings or instant\n- Leave empty or 'instant' for instant zoom\n- Format: duration, easeName\n- Example: 1.5, cubeInOut\n- Available eases: linear, quadIn, quadOut, quadInOut, cubeIn, cubeOut, cubeInOut, sineIn, sineOut, sineInOut, etc."],
		['Target Camera', "Moves camera to a specific target or position.\n\nValue 1: Target\n- BF, GF, Dad\n- Or strumline number (3, 4, 5...)\n- Or absolute position: X, Y (e.g., 400, 800)\n- Or target + offset: BF, 300 (character + X offset)\n\nValue 2: Tween settings\n- Format: easeName, duration\n- Example: sineInOut, 0.3\n- Available eases: linear, quadIn, quadOut, quadInOut, cubeIn, cubeOut, cubeInOut, sineIn, sineOut, sineInOut, elasticIn, elasticOut, elasticInOut, etc.\n\nNote: Overrides mustHitSection until tween completes"],
		['(STEPS) Set Cam Zoom', "Like Set Cam Zoom, but the tween duration uses steps instead of seconds.\n\nValue 1: Camera zoom level\n- Example: 1.05\n\nValue 2: Tween settings or instant\n- Leave empty or 'instant' for instant zoom\n- Format: steps, easeName\n- Example: 16, cubeInOut"],
		['(STEPS) Target Camera', "Like Target Camera, but the tween duration uses steps instead of seconds.\n\nValue 1: Target\n- BF, GF, Dad\n- Or absolute position: X, Y (e.g., 400, 800)\n- Or target + offset: BF, 300 (character + X offset)\n\nValue 2: Tween settings\n- Format: easeName, steps\n- Example: sineInOut, 8\n\nNote: Overrides mustHitSection until tween completes"],
		['(STEPS) Target Follow Pos', "Like Target Follow Pos, but the tween duration uses steps instead of seconds.\n\nValue 1: Position or Target\n- BF, GF, Dad (follows character)\n- Or absolute position: X, Y (e.g., 400, 800)\n- Leave empty to unlock and return to normal\n\nValue 2: Tween settings or instant\n- Leave empty or 'instant' for instant movement\n- Format: steps, easeName\n- Example: 8, sineInOut\n\nNote: Camera stays locked until you clear it (empty Value 1) or use Target Camera event"],
		['Change Note Skin', "Changes the falling note skin.\n\nValue 1: Skin name or path\n(e.g. myNote or noteSkins/myNote)\nLeave blank to use default.\n\nValue 2: Target\n- BF\n- Dad\n- Both (default)"],
		['Change NoteStrum Skin', "Changes the strum arrows skin.\n\nValue 1: Skin name or path\n(e.g. myNote or noteSkins/myNote)\nLeave blank to use default.\n\nValue 2: Target\n- BF\n- Dad\n- Both (default)"],
		['Change Hold Cover Skin', "Changes the hold cover skin.\n\nValue 1: Skin name or path\n(e.g. myCover or holdCovers/myCover)\nLeave blank to use default.\n\nValue 2: Target\n- BF\n- Dad\n- Both (default)"],
		['Change Note Splash Skin', "Changes the note splash skin.\n\nValue 1: Skin name or path\n(e.g. mySplash or noteSplashes/mySplash)\nLeave blank to use default.\n\nValue 2: Target\n- BF\n- Dad\n- Both (default)"]
	];
	
	public static var keysArray:Array<FlxKey> = [ONE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT]; //Used for Vortex Editor
	public static var SHOW_EVENT_COLUMN = true;
	public static var GRID_COLUMNS_PER_PLAYER = 4;
	public static var GRID_PLAYERS = 2;
	public static var GRID_SIZE = 40;
	public static final ALLOW_EXTRA_STRUMS:Bool = false;
	public static inline final WAVE_STRIP:Int = 80;
	static inline final CURSOR_POINTER = 0;
	static inline final CURSOR_GRABBING = 1;
	static inline final CURSOR_CELL = 2;
	final BACKUP_EXT = 'bkp';

	public var quantizations:Array<Int> = [
		4,
		8,
		12,
		16,
		20,
		24,
		32,
		48,
		64,
		96,
		192
	];
	public var quantColors:Array<FlxColor> = [
		0xFFDF0000,
		0xFF4040CF,
		0xFFAF00AF,
		0xFFFFAF00,
		0xFFFFFFFF,
		0xFFFFA0FF,
		0xFFFF6030,
		0xFF00CFCF,
		0xFF00CF00,
		0xFF9F9F9F,
		0xFF3F3F3F,
	];
	var curQuant(default, set):Int = 16;
	function set_curQuant(v:Int)
	{
		curQuant = v;
		updateVortexColor();
		return curQuant;
	}
	function updateVortexColor()
	{
		if(vortexIndicator == null) return;
		var col:FlxColor = quantColors[Std.int(FlxMath.bound(quantizations.indexOf(curQuant), 0, quantColors.length - 1))];
		vortexIndicator.color = col;
		if(vortexQuantTxt != null)
		{
			vortexQuantTxt.text = '1/$curQuant';
			vortexQuantTxt.color = col;
			updateVortexQuantPosition();
		}
	}

	function updateVortexQuantPosition()
	{
		if(vortexIndicator == null || vortexQuantTxt == null) return;
		vortexQuantTxt.x = vortexIndicator.x - vortexQuantTxt.fieldWidth - 4;
		vortexQuantTxt.y = vortexIndicator.y + vortexIndicator.height * 0.5 - vortexQuantTxt.height * 0.5;
	}

	var sectionFirstNoteID:Int = 0;
	var sectionFirstEventID:Int = 0;
	var curSec:Int = 0;

	var chartEditorSave:FlxSave;
	var mainBox:PsychUIBox;
	var mainBoxPosition:FlxPoint = FlxPoint.get(FlxG.width - 300, 24);
	var mainBoxOriginalHeight:Int = 300;
	var lastMainBoxTab:String = '';
	var lastMainBoxMinimized:Bool = false;
	var mainBoxMoved:Bool = false;
	var infoBoxMoved:Bool = false;
	var infoBox:PsychUIBox;
	var infoBoxPosition:FlxPoint = FlxPoint.get(FlxG.width - 220, 304);
	var upperBox:PsychUIBox;
	
	var miniChart:FlxSprite;
	var miniChartHandle:FlxSprite;
	var miniChartBg:FlxSprite;
	var isDraggingMiniChart:Bool = false;
	var miniChartScrollTween:FlxTween;
	
	var camUI:FlxCamera;
	var camNotifications:FlxCamera;
	var previewBtn:PsychUIButton = null;

	var prevGridBg:ChartingGridSprite;
	var gridBg:ChartingGridSprite;
	var nextGridBg:ChartingGridSprite;
	var waveformSprite:FlxSprite;
	var waveformPlayerSprite:FlxSprite;
	var waveformOppSprite:FlxSprite;
	var scrollY:Float = 0;
	var gridTargetX:Float = 0;
	var gridCurrentX:Float = 0;
	
	var zoomList:Array<Float> = [
		0.25,
		0.5,
		1,
		2,
		3,
		4,
		6,
		8,
		12,
		16,
		24
	];
	var curZoom:Float = 1;

	var mustHitIndicator:FlxSprite;
	var eventIcon:FlxSprite;
	var icons:Array<HealthIcon> = [];

	var events:Array<EventMetaNote> = [];
	var notes:Array<MetaNote> = [];

	var behindRenderedNotes:FlxTypedGroup<MetaNote> = new FlxTypedGroup<MetaNote>();
	var curRenderedNotes:FlxTypedGroup<MetaNote> = new FlxTypedGroup<MetaNote>();
	var movingNotes:FlxTypedGroup<MetaNote> = new FlxTypedGroup<MetaNote>();
	var eventLockOverlay:FlxSprite;
	var vortexIndicator:FlxSprite;
	var vortexQuantTxt:FlxText;
	var strumLineNotes:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	var dummyArrow:FlxSprite;
	var isMovingNotes:Bool = false;
	var stretchingNote:MetaNote = null;
	var stretchSoundFlip:Bool = false;
	var movingNotesLastData:Int = 0;
	var movingNotesLastY:Float = 0;
	var toyEnabled:Array<Bool> = [false, false, false]; // 0 = bf, 1 = gf, 2 = opponent
	var toysEnabled(get, never):Bool;
	function get_toysEnabled():Bool return toyEnabled[0] || toyEnabled[1] || toyEnabled[2];
	
	public static var instance:ChartingState;
	
	var bfToy:Toy;
	var gfToy:Toy;
	var opponentToy:Toy;
	var toyGroup:FlxTypedGroup<Toy>;
	var toyHitboxes:FlxTypedGroup<FlxSprite>;
	var showToyHitboxes:Bool = false;
	
	var vocals:FlxSound = new FlxSound();
	var opponentVocals:FlxSound = new FlxSound();
	var editorLoop:FlxSound = new FlxSound();
	var editorLoopTimer:FlxTimer;
	var editorMusicMuted:Bool = false;
	var editorMusicCheckBox:PsychUICheckBox;

	var timeLine:FlxSprite;
	var infoText:FlxText;

	var autoSaveIcon:FlxSprite;
	var outputTxt:FlxText;

	var selectionStart:FlxPoint = FlxPoint.get();
	var _selectionBounds:flixel.math.FlxRect = flixel.math.FlxRect.get();
	var _noteBounds:flixel.math.FlxRect = flixel.math.FlxRect.get();
	var selectionBox:FlxSprite;
	var noteHighlights:FlxTypedGroup<FlxSprite>;
	var sustainHighlights:FlxTypedGroup<FlxSprite>;

	public static var skipStartupMenu:Bool = false;

	var _shouldReset:Bool = true;
	var _startTime:Float = 0;
	var _showStartup:Bool = false;
	public function new(?shouldReset:Bool = true, ?startTime:Float = 0)
	{
		this._shouldReset = shouldReset;
		this._showStartup = !skipStartupMenu;
		skipStartupMenu = false;
		
		if(startTime > 0)
			this._startTime = startTime;
		else if(goToTime > 0)
			this._startTime = goToTime;
		else
			this._startTime = 0;
		
		goToTime = 0;
		super();
	}

	var bg:FlxSprite;
	var theme:ChartingTheme = DEFAULT;

	var copiedNotes:Array<Dynamic> = [];
	var copiedEvents:Array<Dynamic> = [];
	
	var _keysPressedBuffer:Array<Bool> = [];

	var tipBg:FlxSprite;
	var fullTipText:FlxText;
	var tipPageTxt:FlxText;
	var tipPages:Array<String> = [];
	var curTipPage:Int = 0;
	
	var vortexEnabled:Bool = false;
	var _openingSubState:Bool = false;
	var _loopMutedByPlaytest:Bool = false;
	var _songPlayIntent:Bool = false;
	var customCursor:FlxSprite;
	var cursorKind:Int = -1;
	var cursorFrames:Array<flixel.graphics.frames.FlxImageFrame> = [];
	var isHoveringNote:Bool = false;
	var cursorGrabTimer:Float = 0;
	var isGrabbingCursor:Bool = false;
	var hideCursorFrames:Int = 0;
	var waveformEnabled:Bool = false;
	var waveformPlayerEnabled:Bool = false;
	var waveformOppEnabled:Bool = false;

	override function create()
	{
		instance = this;
		if(Difficulty.list.length < 1) Difficulty.resetList();
		_keysPressedBuffer.resize(keysArray.length);

		var savedPosition:Float = _startTime > 0 ? _startTime : Conductor.songPosition;
		if(_shouldReset && _startTime <= 0) Conductor.songPosition = 0;
		persistentUpdate = false;
		FlxG.mouse.visible = true;
		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);

		vocals.autoDestroy = false;
		vocals.looped = true;
		opponentVocals.autoDestroy = false;
		opponentVocals.looped = true;

		FlxG.sound.list.add(editorLoop);
		editorLoop.loadEmbedded(Paths.music('chartEditorLoop'), true, false);
		editorLoop.autoDestroy = false;
		editorLoop.volume = 0;
		scheduleEditorLoop(10);

		initPsychCamera();
		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;
		FlxG.cameras.add(camUI, false);

		camNotifications = new FlxCamera();
		camNotifications.bgColor.alpha = 0;
		FlxG.cameras.add(camNotifications, false);

		chartEditorSave = new FlxSave();
		chartEditorSave.bind('chart_editor_data', CoolUtil.getSavePath());

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set();
		add(bg);

		if(chartEditorSave.data.autoSave != null) autoSaveCap = chartEditorSave.data.autoSave;
		if(chartEditorSave.data.backupLimit != null) backupLimit = chartEditorSave.data.backupLimit;
		if(chartEditorSave.data.vortex != null) vortexEnabled = chartEditorSave.data.vortex;
		if(chartEditorSave.data.editorMusicMuted != null) editorMusicMuted = (chartEditorSave.data.editorMusicMuted == true);
		if(chartEditorSave.data.toyHitboxes != null) showToyHitboxes = (chartEditorSave.data.toyHitboxes == true);
		if(chartEditorSave.data.toyEnabled != null)
		{
			var saved:Array<Dynamic> = chartEditorSave.data.toyEnabled;
			for (i in 0...3)
				if(saved != null && i < saved.length) toyEnabled[i] = (saved[i] == true);
		}
		else
		{
			var old:Bool = (chartEditorSave.data.toys == true);
			toyEnabled = [old, old, old];
		}

		if(chartEditorSave.data.customBgColor == null) chartEditorSave.data.customBgColor = '303030';
		if(chartEditorSave.data.customGridColors == null || chartEditorSave.data.customGridColors.length < 2)
			chartEditorSave.data.customGridColors = ['DFDFDF', 'BFBFBF'];
		if(chartEditorSave.data.customNextGridColors == null || chartEditorSave.data.customNextGridColors.length < 2)
			chartEditorSave.data.customNextGridColors = ['5F5F5F', '4A4A4A'];
		
		changeTheme(chartEditorSave.data.theme != null ? chartEditorSave.data.theme : DEFAULT, false);

		GRID_PLAYERS = 2;
		if(PlayState.SONG != null)
		{
			var extraCount:Int = (PlayState.SONG.extraStrumlines != null) ? PlayState.SONG.extraStrumlines.length : 0;
			var detectedPlayers:Int = (PlayState.SONG.mania >= 1) ? PlayState.SONG.mania : (2 + extraCount);
			if(PlayState.SONG.notes != null)
			{
				var maxCol:Int = 0;
				for(section in PlayState.SONG.notes)
					if(section != null && section.sectionNotes != null)
						for(note in section.sectionNotes)
							if(note != null && Std.int(note[1]) > maxCol && Std.int(note[1]) < GRID_COLUMNS_PER_PLAYER * 8)
								maxCol = Std.int(note[1]);
				var detectedFromNotes:Int = Math.ceil((maxCol + 1) / GRID_COLUMNS_PER_PLAYER);
				if(detectedFromNotes > detectedPlayers)
					detectedPlayers = detectedFromNotes;
			}
			GRID_PLAYERS = Std.int(Math.max(1, detectedPlayers));
		}

		createGrids();

		waveformOppSprite = new FlxSprite(gridBg.x - WAVE_STRIP, 0).makeGraphic(1, 1, 0x00FFFFFF, true);
		waveformOppSprite.scrollFactor.x = 0;
		waveformOppSprite.visible = false;
		add(waveformOppSprite);

		waveformPlayerSprite = new FlxSprite(gridBg.x + gridBg.width, 0).makeGraphic(1, 1, 0x00FFFFFF, true);
		waveformPlayerSprite.scrollFactor.x = 0;
		waveformPlayerSprite.visible = false;
		add(waveformPlayerSprite);

		waveformSprite = new FlxSprite(gridBg.x + (SHOW_EVENT_COLUMN ? GRID_SIZE : 0), 0).makeGraphic(1, 1, 0x00FFFFFF, true);
		waveformSprite.scrollFactor.x = 0;
		waveformSprite.visible = false;
		add(waveformSprite);

		dummyArrow = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		dummyArrow.setGraphicSize(GRID_SIZE, GRID_SIZE);
		dummyArrow.updateHitbox();
		dummyArrow.scrollFactor.x = 0;
		add(dummyArrow);

		vortexIndicator = new FlxSprite(gridBg.x - GRID_SIZE, FlxG.height/2).loadGraphic(Paths.image('editors/vortex_indicator'));
		vortexIndicator.setGraphicSize(GRID_SIZE);
		vortexIndicator.updateHitbox();
		vortexIndicator.scrollFactor.set();
		vortexIndicator.active = false;
		add(vortexIndicator);

		vortexQuantTxt = new FlxText(0, 0, 64, '1/16');
		vortexQuantTxt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		vortexQuantTxt.scrollFactor.set();
		vortexQuantTxt.active = false;
		add(vortexQuantTxt);
		updateVortexColor();
		add(strumLineNotes);

		add(behindRenderedNotes);
		add(curRenderedNotes);
		add(movingNotes);

		eventLockOverlay = new FlxSprite(gridBg.x, 0).makeGraphic(1, 1, FlxColor.BLACK);
		eventLockOverlay.alpha = 0.6;
		eventLockOverlay.visible = false;
		eventLockOverlay.scrollFactor.x = 0;
		eventLockOverlay.scale.x = GRID_SIZE;
		eventLockOverlay.updateHitbox();
		add(eventLockOverlay);

		timeLine = new FlxSprite(gridBg.x, 0).makeGraphic(1, 1, FlxColor.WHITE);
		timeLine.setGraphicSize(Std.int(gridBg.width), 4);
		timeLine.updateHitbox();
		timeLine.screenCenter(Y);
		timeLine.scrollFactor.set();
		add(timeLine);
		
		var startX:Float = gridBg.x;
		var startY:Float = FlxG.height/2;
		vortexQuantTxt.visible = vortexIndicator.visible = strumLineNotes.visible = strumLineNotes.active = vortexEnabled;
		if(SHOW_EVENT_COLUMN) startX += GRID_SIZE;

		for (i in 0...Std.int(GRID_PLAYERS * GRID_COLUMNS_PER_PLAYER))
		{
			var note:StrumNote = new StrumNote(startX + (GRID_SIZE * i), startY, i % GRID_COLUMNS_PER_PLAYER, 0);
			note.scrollFactor.set();
			note.playAnim('static');
			note.alpha = 0.4;
			note.updateHitbox();
			if(note.width > note.height)
				note.setGraphicSize(GRID_SIZE);
			else
				note.setGraphicSize(0, GRID_SIZE);
	
			note.updateHitbox();
			note.x += GRID_SIZE/2 - note.width/2;
			note.y += GRID_SIZE/2 - note.height/2;
			strumLineNotes.add(note);
		}

		var columns:Int = 0;
		var iconX:Float = gridBg.x;
		var iconY:Float = 50;
		if(SHOW_EVENT_COLUMN)
		{
			eventIcon = new FlxSprite(0, iconY).loadGraphic(Paths.image('editors/eventIcon'));
			eventIcon.antialiasing = ClientPrefs.data.antialiasing;
			eventIcon.alpha = 0.6;
			eventIcon.setGraphicSize(30, 30);
			eventIcon.updateHitbox();
			eventIcon.scrollFactor.set();
			add(eventIcon);
			eventIcon.x = iconX + (GRID_SIZE * 0.5) - eventIcon.width/2;
			iconX += GRID_SIZE;

			columns++;
		}

		mustHitIndicator = FlxSpriteUtil.drawTriangle(new FlxSprite(0, iconY - 20).makeGraphic(16, 16, FlxColor.TRANSPARENT), 0, 0, 16);
		mustHitIndicator.scrollFactor.set();
		mustHitIndicator.flipY = true;
		mustHitIndicator.offset.x += mustHitIndicator.width/2;
		add(mustHitIndicator);

		var gridStripes:Array<Int> = [];
		for (i in 0...GRID_PLAYERS)
		{
			if(columns > 0) gridStripes.push(columns);
			columns += GRID_COLUMNS_PER_PLAYER;

			var icon:HealthIcon = new HealthIcon();
			icon.autoAdjustOffset = false;
			icon.y = iconY;
			icon.alpha = 0.6;
			icon.scrollFactor.set();
			icon.scale.set(0.3, 0.3);
			icon.updateHitbox();
			icon.ID = i+1;
			add(icon);
			icons.push(icon);
			
			icon.x = iconX + GRID_SIZE * (GRID_COLUMNS_PER_PLAYER/2) - icon.width/2;
			iconX += GRID_SIZE * GRID_COLUMNS_PER_PLAYER;
		}
		prevGridBg.stripes = nextGridBg.stripes = gridBg.stripes = gridStripes;
		
		selectionBox = new FlxSprite().makeGraphic(1, 1, FlxColor.CYAN);
		selectionBox.alpha = 0.4;
		selectionBox.blend = ADD;
		selectionBox.scrollFactor.set();
		selectionBox.visible = false;
		selectionBox.cameras = [camUI];

		noteHighlights = new FlxTypedGroup<FlxSprite>();
		add(noteHighlights);

		sustainHighlights = new FlxTypedGroup<FlxSprite>();
		add(sustainHighlights);

		var miniChartWidth:Int = 40;
		var miniChartHeight:Int = Std.int(FlxG.height - mainBoxPosition.y * 2);
		var miniChartX:Float = gridBg.x + gridBg.width + WAVE_STRIP;
		var miniChartY:Float = mainBoxPosition.y;
		
		miniChartBg = new FlxSprite(miniChartX, miniChartY).makeGraphic(miniChartWidth, miniChartHeight, 0xFF606060);
		miniChartBg.scrollFactor.set();
		miniChartBg.cameras = [camUI];
		add(miniChartBg);
		
		miniChart = new FlxSprite(miniChartX, miniChartY).makeGraphic(miniChartWidth, miniChartHeight, 0x00FFFFFF, true);
		miniChart.scrollFactor.set();
		miniChart.cameras = [camUI];
		add(miniChart);
		
		miniChartHandle = new FlxSprite(miniChartX, miniChartY).makeGraphic(miniChartWidth, 20, 0x00FFFFFF, true);
		miniChartHandle.pixels.fillRect(new Rectangle(0, 0, miniChartWidth, 20), 0x80FF8800);
		miniChartHandle.pixels.fillRect(new Rectangle(0, 0, miniChartWidth, 2), 0xFFFFAA44);
		miniChartHandle.pixels.fillRect(new Rectangle(0, 18, miniChartWidth, 2), 0xFFFFAA44);
		miniChartHandle.pixels.fillRect(new Rectangle(0, 0, 2, 20), 0xFFFFAA44);
		miniChartHandle.pixels.fillRect(new Rectangle(miniChartWidth - 2, 0, 2, 20), 0xFFFFAA44);
		miniChartHandle.scrollFactor.set();
		miniChartHandle.cameras = [camUI];
		add(miniChartHandle);

		add(selectionBox);

		infoBox = new PsychUIBox(infoBoxPosition.x, infoBoxPosition.y, 220, 220, ['Information']);
		infoBox.scrollFactor.set();
		infoBox.cameras = [camUI];
		infoBox.canMove = true;
		infoText = new FlxText(15, 15, 230, '', 16);
		infoText.scrollFactor.set();
		infoBox.getTab('Information').menu.add(infoText);
		add(infoBox);

		mainBox = new PsychUIBox(mainBoxPosition.x, mainBoxPosition.y, 300, 280, ['Meta', 'Chart', 'Data', 'Events', 'Note', 'Section', 'Song']);
		mainBox.selectedName = 'Song';
		mainBox.scrollFactor.set();
		mainBox.cameras = [camUI];
		mainBox.canMove = true;
		add(mainBox);

		autoSaveIcon = new FlxSprite(50).loadGraphic(Paths.image('editors/autosave'));
		autoSaveIcon.screenCenter(Y);
		autoSaveIcon.scale.set(0.6, 0.6);
		autoSaveIcon.antialiasing = ClientPrefs.data.antialiasing;
		autoSaveIcon.scrollFactor.set();
		autoSaveIcon.alpha = 0;
		add(autoSaveIcon);

		// set fixed positions for the UI boxes
		mainBox.setPosition(FlxG.width - 300, 24);
		infoBox.setPosition(FlxG.width - 220, mainBoxPosition.y + mainBoxOriginalHeight);
		loadUIBoxPositions();

		upperBox = new PsychUIBox(0, 0, 375, 300, ['File', 'Audio', 'Edit', 'View', 'Test']);
		upperBox.scrollFactor.set();
		upperBox.isMinimized = true;
		upperBox.minimizeOnFocusLost = true;
		upperBox.canMove = false;
		upperBox.cameras = [camUI];
		upperBox.bg.visible = false;
		upperBox.bg.alpha = 1;
		add(upperBox);

		upperBox.getTab('File').menuOffsetX = 0;
		upperBox.getTab('Audio').menuOffsetX = 75;
		upperBox.getTab('Edit').menuOffsetX = 150;
		upperBox.getTab('View').menuOffsetX = 225;
		upperBox.getTab('Test').menuOffsetX = 300;

		outputTxt = new FlxText(25, FlxG.height - 50, FlxG.width - 50, '', 20);
		outputTxt.borderSize = 2;
		outputTxt.borderStyle = OUTLINE_FAST;
		outputTxt.scrollFactor.set();
		outputTxt.cameras = [camNotifications];
		outputTxt.alpha = 0;
		add(outputTxt);

		if(PlayState.SONG == null) //Atleast try to avoid crashes
		{
			openNewChart();
		}

		updateJsonData();
		
		// TABS
		////// for main box
		addMetaDataTab();
		addChartingTab();
		addDataTab();
		addEventsTab();
		addNoteTab();
		addSectionTab();
		addSongTab();
		
		////// for upper box
		addFileTab();
		addEditTab();
		addViewTab();
		addAudioTab();
		addTestTab();
		//

		loadMusic();
		reloadNotesDropdowns();
		
		reloadNotes();
		updateGridVisibility();

		// CHARACTERS FOR THE DROP DOWNS
		var gameOverCharacters:Array<String> = loadFileList('characters/', 'data/characterList.txt');
		characterList = gameOverCharacters.filter((name:String) -> (!name.endsWith('-dead') && !name.endsWith('-death')));
		playerDropDown.list = characterList;
		opponentDropDown.list = characterList;
		girlfriendDropDown.list = characterList;

		gameOverCharacters.insert(0, '');
		gameOverCharacters.sort(function(a:String, b:String)
		{
			if((a == '' || a.endsWith('-dead') || a.endsWith('-death')) && !(b == '' || b.endsWith('-dead') || b.endsWith('-death'))) return -1; //Prioritize "-dead" or "-death" characters
			return 0;
		});
		gameOverCharDropDown.list = gameOverCharacters;

		stageDropDown.list = loadFileList('stages/', 'data/stageList.txt');
		onChartLoaded();

		var tipText:FlxText = new FlxText(FlxG.width - 210, FlxG.height - 30, 200, 'Press F1 for Help', 20);
		tipText.cameras = [camUI];
		tipText.setFormat(null, 16, FlxColor.WHITE, RIGHT);
		tipText.borderColor = FlxColor.BLACK;
		tipText.scrollFactor.set();
		tipText.borderSize = 1;
		tipText.active = false;
		add(tipText);

		toyGroup = new FlxTypedGroup<Toy>();
		toyGroup.cameras = [camUI];
		if(toysEnabled) createToys();

		toyHitboxes = new FlxTypedGroup<FlxSprite>();
		toyHitboxes.cameras = [camUI];

		var toyLayer:Int = members.indexOf(infoBox);
		if(toyLayer < 0)
		{
			add(toyGroup);
			add(toyHitboxes);
		}
		else
		{
			insert(toyLayer, toyGroup);
			insert(toyLayer + 1, toyHitboxes);
		}

		tipBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		tipBg.cameras = [camUI];
		tipBg.scale.set(FlxG.width, FlxG.height);
		tipBg.updateHitbox();
		tipBg.scrollFactor.set();
		tipBg.visible = tipBg.active = false;
		tipBg.alpha = 0.85;
		add(tipBg);
		
		fullTipText = new FlxText(0, 0, FlxG.width - 200);
		fullTipText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER);
		fullTipText.cameras = [camUI];
		fullTipText.scrollFactor.set();
		fullTipText.visible = fullTipText.active = false;
		tipPages = [
			[
				"- NAVIGATION -",
				"W/S or Mouse Wheel - Move Conductor's Time",
				"Hold Shift - 4x Faster / Hold Alt - 4x Slower",
				"A/D - Previous / Next Section",
				"P - Go to Start of Song / L - Go to End of Song",
				"Space - Play / Pause Song",
				"Ctrl + Mouse Wheel - Scroll the Grid Sideways",
				"Z/X - Zoom Out / Zoom In",
				"Left/Right - Change Snap",
				"Click or Drag on the Mini Chart - Jump to that Position",
				"",
				"- PLAYTEST -",
				"Enter - Playtest Chart",
				"Shift + Enter - Playtest from Current Position",
				"Ctrl + Enter - Preview Chart (Minimal Mode)",
				"",
				"F1 - Toggle this Help / Left-Right - Change Page",
				"Escape - Exit Editor",
			].join('\n'),
			[
				"- NOTES -",
				"Left Click on an empty Cell - Place Note",
				"Hold and Drag right after placing - Set Hold Length",
				"Right Click on a Note - Erase it",
				"Q/E - Decrease/Increase Sustain of the Selected Note",
				"Hold Ctrl - Ignore Snapping while placing or stretching",
				"Vortex Mode (Edit menu) - place Notes with your gameplay keys",
				"",
				"- SELECTION -",
				"Left Click on a Note - Select it, Click again to Unselect",
				"Left Click + Drag - Move the Selected Notes",
				"(dragging a Note that wasn't selected moves only that one)",
				"Shift + Drag - Duplicate the Selection and move the copies",
				"Right Click + Drag on empty Grid - Selection Box",
				"Right Click on empty Grid - Unselect All",
				"Hold Alt while releasing the Box - Remove from Selection",
				"Ctrl + A - Select all in the current Section",
				"Ctrl + Shift + A - Select all Notes in the Song",
				"Delete/Backspace - Delete Selected",
				"Escape or Right Click while moving - Cancel the Move",
			].join('\n'),
			[
				"- EDITING -",
				"Ctrl + Z - Undo",
				"Ctrl + Shift + Z - Redo",
				"Ctrl + C / X / V - Copy / Cut / Paste Selected",
				"Ctrl + S - Quicksave",
				"R - Reload Chart from Disk",
				"",
				"- TOYS -",
				"Enable them in the View menu",
				"Left Click + Drag - Move a Toy",
				"Mouse Wheel over a Toy - Resize it",
				"H - Show/Hide Toy Hitboxes",
				"",
				"- INTERFACE -",
				"Drag a Box by its Tab Strip - Move it",
				"View menu, Reset UI Boxes - put them back in place",
			].join('\n'),
		];
		add(fullTipText);

		tipPageTxt = new FlxText(0, FlxG.height - 60, FlxG.width, '', 22);
		tipPageTxt.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, CENTER);
		tipPageTxt.cameras = [camUI];
		tipPageTxt.scrollFactor.set();
		tipPageTxt.visible = tipPageTxt.active = false;
		add(tipPageTxt);
		showTipPage(0);
		
		customCursor = new FlxSprite();
		var cursorKeys:Array<String> = ['chartEditorCursorPointer', 'chartEditorCursorGrab', 'chartEditorCursorCell'];
		for (i in 0...cursorKeys.length)
		{
			var graphic:flixel.graphics.FlxGraphic = FlxG.bitmap.get(cursorKeys[i]);
			if(graphic == null)
			{
				var bmp:BitmapData = switch(i)
				{
					case 1: new GrabbingCursor(0, 0);
					case 2: new CellCursor(0, 0);
					default: new PointerCursor(0, 0);
				}
				graphic = flixel.graphics.FlxGraphic.fromBitmapData(bmp, false, cursorKeys[i], true);
			}
			graphic.persist = true;
			graphic.destroyOnNoUse = false;
			cursorFrames.push(graphic.imageFrame);
		}
		setCursorKind(CURSOR_POINTER);
		customCursor.setGraphicSize(32, 32);
		customCursor.updateHitbox();
		customCursor.cameras = [camUI];
		customCursor.visible = false;
		add(customCursor);
		
		super.create();
		
		curSec = 0;
		Conductor.songPosition = 0;
		
		if(FlxG.sound.music != null)
			FlxG.sound.music.time = 0;
		
		vocals.time = 0;
		opponentVocals.time = 0;
		
		if(GRID_PLAYERS > 2)
			rebuildGridPlayers();

		loadSection(0);
		scrollY = -FlxG.height/2;
		forceDataUpdate = true;
		
		if(_startTime >= 0.001)
		{
			var targetSection:Int = 0;
			for(i in 0...cachedSectionTimes.length)
			{
				if(cachedSectionTimes[i] > _startTime) break;
				targetSection = i;
			}
			
			curSec = targetSection;
			Conductor.songPosition = _startTime;
			
			if(FlxG.sound.music != null)
				FlxG.sound.music.time = _startTime - Conductor.offset;
			
			vocals.time = _startTime - Conductor.offset;
			opponentVocals.time = _startTime - Conductor.offset;
			
			if(_startTime - Conductor.offset >= vocals.length)
				vocals.pause();
			if(_startTime - Conductor.offset >= opponentVocals.length)
				opponentVocals.pause();
			
			loadSection(curSec);
			updateScrollY();
			forceDataUpdate = true;
		}

		if(_showStartup) openStartupPrompt();
	}

	function createToys()
	{
		if(bfToy != null) return;
		var slot:Float = gridBg.x / 3;
		var baseY:Float = FlxG.height - Toy.TOY_HEIGHT - 20;

		var frankX:Float = 10;
		var frankY:Float = baseY;
		var gfX:Float = slot + 10;
		var gfY:Float = baseY;
		var bfX:Float = slot * 2 + 10;
		var bfY:Float = baseY;
		
		if(chartEditorSave.data.toyPositions != null)
		{
			var positions:Dynamic = chartEditorSave.data.toyPositions;
			if(Reflect.hasField(positions, 'gf'))
			{
				gfX = Reflect.field(positions, 'gf').x;
				gfY = Reflect.field(positions, 'gf').y;
			}
			if(Reflect.hasField(positions, 'bf'))
			{
				bfX = Reflect.field(positions, 'bf').x;
				bfY = Reflect.field(positions, 'bf').y;
			}
			if(Reflect.hasField(positions, 'opponent'))
			{
				frankX = Reflect.field(positions, 'opponent').x;
				frankY = Reflect.field(positions, 'opponent').y;
			}
		}
		
		gfToy = new Toy(gfX, gfY, 'gfSigma', false, 'gf');
		bfToy = new Toy(bfX, bfY, 'bfSigma', true, 'bf');
		opponentToy = new Toy(frankX, frankY, 'frank', false, 'opponent');
		
		toyGroup.add(gfToy);
		toyGroup.add(bfToy);
		toyGroup.add(opponentToy);
		if(chartEditorSave.data.toySizes != null)
		{
			var sizes:Dynamic = chartEditorSave.data.toySizes;
			for (toy in toyGroup)
				if(toy != null && Reflect.hasField(sizes, toy.toyName))
					toy.setToySize(Reflect.field(sizes, toy.toyName));
		}

		clampToysToScreen();
		updateToyCharacters();

		setToysAnimated(FlxG.sound.music != null && FlxG.sound.music.playing);
		applyToyVisibility();
	}

	function applyToyVisibility()
	{
		if(bfToy == null) return;

		bfToy.visible = toyEnabled[0];
		gfToy.visible = toyEnabled[1];
		opponentToy.visible = toyEnabled[2];
	}

	var _lastToyRaw:Array<String> = [null, null, null];

	function toyCharacterFor(name:String, fallback:String):String
	{
		if(name == null || name.length < 1) return fallback;

		var data:CharacterFile = loadCharacterFile(name);
		if(data == null || data.image == null) return fallback;

		var firstImage:String = data.image.split(',')[0].trim();
		if(firstImage.length < 1) return fallback;
		if(Paths.fileExists('images/$firstImage.png', IMAGE)) return name;
		if(Paths.fileExists('images/$firstImage/Animation.json', TEXT)) return name;

		return fallback;
	}

	function clampToysToScreen()
	{
		for (toy in toyGroup)
		{
			if(toy == null) continue;

			toy.baseX = FlxMath.bound(toy.baseX, 0, FlxG.width - toy.width);
			toy.baseY = FlxMath.bound(toy.baseY, 0, FlxG.height - toy.height);
			toy.x = toy.baseX;
			toy.y = toy.baseY;
		}
	}

	function updateToyCharacters(?overrideP1:String, ?overrideP2:String)
	{
		if(bfToy == null) return;

		var raw:Array<String> = [
			overrideP1 != null ? overrideP1 : PlayState.SONG.player1,
			PlayState.SONG.gfVersion,
			overrideP2 != null ? overrideP2 : PlayState.SONG.player2
		];
		var toys:Array<Toy> = [bfToy, gfToy, opponentToy];
		var fallbacks:Array<String> = ['bfSigma', 'gfSigma', 'frank'];

		for (i in 0...3)
		{
			if(_lastToyRaw[i] == raw[i]) continue;

			_lastToyRaw[i] = raw[i];
			toys[i].changeToyCharacter(toyCharacterFor(raw[i], fallbacks[i]));
		}
	}

	function resizeHoveredToy(wheel:Int):Bool
	{
		if(!toysEnabled || bfToy == null) return false;

		for (toy in toyGroup)
		{
			if(toy == null || !toy.grabAllowed) continue;

			toy.changeToySize(wheel * 0.1);
			return true;
		}
		return false;
	}

	var hitboxBtn:PsychUIButton;
	function hitboxButtonLabel():String
	{
		return '  Toy Hitboxes: ' + (showToyHitboxes ? 'ON' : 'OFF');
	}

	function toggleToyHitboxes()
	{
		showToyHitboxes = !showToyHitboxes;
		chartEditorSave.data.toyHitboxes = showToyHitboxes;
		updateToyHitboxes();

		if(hitboxBtn != null) hitboxBtn.text.text = hitboxButtonLabel();
		showOutput('Toy Hitboxes: ' + (showToyHitboxes ? 'ON' : 'OFF'));
	}

	function updateToyHitboxes()
	{
		if(toyHitboxes == null) return;

		if(!showToyHitboxes || !toysEnabled || bfToy == null)
		{
			for (box in toyHitboxes)
				if(box != null) box.visible = false;
			return;
		}

		var i:Int = 0;
		for (toy in toyGroup)
		{
			if(toy == null) continue;

			while(toyHitboxes.length <= i)
			{
				var newBox:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
				newBox.color = FlxColor.LIME;
				newBox.alpha = 0.35;
				newBox.scrollFactor.set();
				newBox.cameras = [camUI];
				toyHitboxes.add(newBox);
			}

			var box:FlxSprite = toyHitboxes.members[i];
			i++;
			if(box == null) continue;

			box.visible = toy.visible;
			box.scale.set(toy.width, toy.height);
			box.updateHitbox();
			box.setPosition(toy.hitboxX, toy.hitboxY);
		}
	}

	function updateToyHover()
	{
		if(bfToy == null) return;

		var hovered:Toy = null;
		var blocked:Bool = (subState != null || _openingSubState || mouseOverUpperMenu() ||
			FlxG.mouse.overlaps(mainBox.bg) || FlxG.mouse.overlaps(infoBox.bg) || FlxG.mouse.overlaps(miniChartBg));

		for (toy in toyGroup)
		{
			if(toy == null || !toy.visible) continue;

			if(toy.isDragging)
			{
				hovered = toy;
				break;
			}
			if(!blocked && FlxG.mouse.overlaps(toy)) hovered = toy;
		}

		for (toy in toyGroup)
			if(toy != null) toy.grabAllowed = (toy == hovered);
	}

	function setToysAnimated(v:Bool)
	{
		if(bfToy == null) return;

		for (toy in toyGroup)
			if(toy != null) toy.setAnimated(v);
	}

	var _lastToySec:Int = -1;
	function danceToys()
	{
		if(bfToy == null) return;

		for (toy in toyGroup)
			if(toy != null) toy.dance();
	}

	var gridColors:Array<FlxColor>;
	var gridColorsOther:Array<FlxColor>;
	function changeTheme(changeTo:ChartingTheme, ?doSave:Bool = true)
	{
		var oldTheme:ChartingTheme = theme;
		theme = changeTo;
		chartEditorSave.data.theme = changeTo;
		if(doSave) chartEditorSave.flush();

		switch(theme)
		{
			case LIGHT:
				bg.color = 0xFFA0A0A0;
				gridColors = [0xFFDFDFDF, 0xFFBFBFBF];
				gridColorsOther = [0xFF5F5F5F, 0xFF4A4A4A];
			case DARK:
				bg.color = 0xFF222222;
				gridColors = [0xFF3F3F3F, 0xFF2F2F2F];
				gridColorsOther = [0xFF1F1F1F, 0xFF111111];
			case VSLICE:
				bg.color = 0xFF673AB7;
				gridColors = [0xFFD0D0D0, 0xFFAFAFAF];
				gridColorsOther = [0xFF595959, 0xFF464646];
			case CUSTOM:
				bg.color = CoolUtil.colorFromString(chartEditorSave.data.customBgColor);
				gridColors = [CoolUtil.colorFromString(chartEditorSave.data.customGridColors[0]), CoolUtil.colorFromString(chartEditorSave.data.customGridColors[1])];
				gridColorsOther = [CoolUtil.colorFromString(chartEditorSave.data.customNextGridColors[0]), CoolUtil.colorFromString(chartEditorSave.data.customNextGridColors[1])];
			default:
				bg.color = 0xFF303030;
				gridColors = [0xFFDFDFDF, 0xFFBFBFBF];
				gridColorsOther = [0xFF5F5F5F, 0xFF4A4A4A];
		}

		if(theme != oldTheme || theme == CUSTOM)
		{
			if(gridBg != null)
			{
				gridBg.loadGrid(gridColors[0], gridColors[1]);
				gridBg.vortexLineEnabled = vortexEnabled;
				gridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
			}
			if(prevGridBg != null)
			{
				prevGridBg.loadGrid(gridColorsOther[0], gridColorsOther[1]);
				prevGridBg.vortexLineEnabled = vortexEnabled;
				prevGridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
			}
			if(nextGridBg != null)
			{
				nextGridBg.loadGrid(gridColorsOther[0], gridColorsOther[1]);
				nextGridBg.vortexLineEnabled = vortexEnabled;
				nextGridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
			}
		}
	}

	function openNewChart(?songName:String)
	{
		var song:SwagSong = {
			song: (songName != null && songName.length > 0) ? songName : 'Test',
			notes: [],
			events: [],
			bpm: 150,
			needsVoices: true,
			speed: 1,
			offset: 0,

			player1: 'bf',
			player2: 'dad',
			gfVersion: 'gf',
			stage: 'stage',
			format: 'psych_v1'
		};
		Song.chartPath = null;
		loadChart(song);
	}

	function recentChartList():Array<String>
	{
		var list:Array<String> = chartEditorSave.data.recentCharts;
		if(list == null) return [];

		var cleaned:Array<String> = [];
		for (path in list)
		{
			if(path == null || path.length < 1 || cleaned.contains(path)) continue;
			if(!FileSystem.exists(path)) continue;
			cleaned.push(path);
		}

		if(cleaned.length != list.length)
		{
			chartEditorSave.data.recentCharts = cleaned;
			chartEditorSave.flush();
		}
		return cleaned;
	}

	function pushRecentChart(path:String)
	{
		if(path == null || path.length < 1) return;

		var list:Array<String> = recentChartList();
		list.remove(path);
		list.insert(0, path);
		while(list.length > 10) list.pop();

		chartEditorSave.data.recentCharts = list;
		chartEditorSave.flush();
	}

	function recentChartLabel(path:String):String
	{
		var parts:Array<String> = path.split('/');
		var file:String = parts.pop();
		var folder:String = (parts.length > 0) ? parts[parts.length - 1] : '';
		return (folder.length > 0) ? '$folder/$file' : file;
	}

	var startupSongWeek:Map<String, String> = new Map<String, String>();
	function gameSongList():Array<String>
	{
		if(WeekData.weeksList.length < 1) WeekData.reloadWeekFiles(false);

		var list:Array<String> = [];
		startupSongWeek.clear();

		for (weekName in WeekData.weeksList)
		{
			var week:WeekData = WeekData.weeksLoaded.get(weekName);
			if(week == null || week.songs == null) continue;

			for (song in week.songs)
			{
				var songName:String = song[0];
				if(songName == null || songName.length < 1 || list.contains(songName)) continue;
				list.push(songName);
				startupSongWeek.set(songName, weekName);
			}
		}
		return list;
	}

	function defaultDifficultyIndex(diffs:Array<String>):Int
	{
		var def:String = Paths.formatToSongPath(Difficulty.getDefault());
		for (i in 0...diffs.length)
			if(Paths.formatToSongPath(diffs[i]) == def) return i;
		return 0;
	}

	function currentDifficultyIndex(diffs:Array<String>):Int
	{
		if(Song.chartPath == null) return defaultDifficultyIndex(diffs);

		var file:String = Song.chartPath.replace('\\', '/');
		file = file.substring(file.lastIndexOf('/') + 1);
		if(file.toLowerCase().endsWith('.json')) file = file.substr(0, file.length - 5);
		file = Paths.formatToSongPath(file);

		var songKey:String = Paths.formatToSongPath(PlayState.SONG.song);
		for (i in 0...diffs.length)
			if(file == songKey + Difficulty.getFilePath(i)) return i;

		return defaultDifficultyIndex(diffs);
	}

	function refreshDifficultyDropDown()
	{
		if(difficultyDropDown == null || PlayState.SONG == null) return;

		var diffs:Array<String> = difficultiesForSong(PlayState.SONG.song);
		if(diffs.length < 1) diffs = ['Normal'];

		difficultyDropDown.list = diffs;
		difficultyDropDown.list = diffs.concat([NEW_DIFF_LABEL]);
		curDifficultyIndex = currentDifficultyIndex(diffs);
		difficultyDropDown.selectedIndex = curDifficultyIndex;
	}

	function switchDifficulty(index:Int)
	{
		if(PlayState.SONG == null || difficultyDropDown == null) return;
		if(index == curDifficultyIndex) return;

		var diffs:Array<String> = difficultiesForSong(PlayState.SONG.song);
		var cancel:Void->Void = function() difficultyDropDown.selectedIndex = curDifficultyIndex;

		if(index == diffs.length)
		{
			openNewDifficultyPrompt();
			return;
		}

		if(index < 0 || index >= diffs.length)
		{
			cancel();
			return;
		}

		var songName:String = PlayState.SONG.song;
		var diffName:String = diffs[index];
		var chartFile:String = Paths.formatToSongPath(songName) + Difficulty.getFilePath(index);

		var alreadyThere:Bool = false;
		try { alreadyThere = (Song.getChart(chartFile, songName) != null); }
		catch(e:Exception) { alreadyThere = false; }

		if(alreadyThere)
		{
			var load:Void->Void = function()
			{
				try
				{
					Song.loadFromJson(chartFile, songName);
					Song.chartPath = Song.chartPath.replace('\\', '/');
					loadChart(PlayState.SONG);
					pushRecentChart(Song.chartPath);
					reloadNotesDropdowns();
					prepareReload();
					showOutput('Switched to "$diffName".');
				}
				catch(e:Exception)
				{
					showOutput('Error: ${e.message}', true);
					cancel();
				}
			}
			openSubState(new Prompt('Switch to "$diffName"?\nAny unsaved progress will be lost.', load, cancel));
		}
		else
		{
			var create:Void->Void = function()
			{
				var dir:String = songChartFolder(songName);
				try
				{
					if(!FileSystem.exists(dir)) FileSystem.createDirectory(dir);

					Song.chartPath = dir + chartFile + '.json';
					saveChart();

					curDifficultyIndex = index;
					difficultyDropDown.selectedIndex = index;
					pushRecentChart(Song.chartPath);
					showOutput('Created "$diffName" as a copy of the current chart.');
				}
				catch(e:Exception)
				{
					showOutput('Error: ${e.message}', true);
					cancel();
				}
			}
			openSubState(new Prompt('"$diffName" doesn\'t exist yet.\nCreate it as a copy of the current chart?', create, cancel));
		}
	}

	function openNewDifficultyPrompt()
	{
		var input:PsychUIInputText = null;
		var warn:FlxText = null;

		var prompt:BasePrompt = new BasePrompt(520, 260, 'New Difficulty', function(state:BasePrompt)
		{
			var cams = state.cameras;

			var label:FlxText = new FlxText(state.bg.x + 20, state.bg.y + 80, 480, 'Name of new difficulty:', 14);
			label.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			label.borderSize = 1;
			label.cameras = cams;
			state.add(label);

			warn = new FlxText(state.bg.x + 20, state.bg.y + 145, 480, '', 12);
			warn.setFormat(Paths.font('vcr.ttf'), 12, 0xFFFF5555, CENTER, OUTLINE, FlxColor.BLACK);
			warn.borderSize = 1;
			warn.visible = false;
			warn.cameras = cams;
			state.add(warn);

			var okBtn:PsychUIButton = new PsychUIButton(state.bg.x + 100, state.bg.y + 205, 'Create', function()
			{
				var error:String = createNewDifficulty(input.text);
				if(error != null)
				{
					warn.text = error;
					warn.visible = true;
					return;
				}
				PsychUIInputText.focusOn = null;
				state.close();
			}, 150, 24);
			var cancelBtn:PsychUIButton = new PsychUIButton(state.bg.x + 270, state.bg.y + 205, 'Cancel', function()
			{
				PsychUIInputText.focusOn = null;
				state.close();
			}, 150, 24);
			okBtn.cameras = cancelBtn.cameras = cams;
			state.add(okBtn);
			state.add(cancelBtn);

			input = new PsychUIInputText(state.bg.x + 160, state.bg.y + 108, 200, '', 8);
			input.cameras = cams;
			state.add(input);
		});

		prompt.closeCallback = function()
		{
			PsychUIInputText.focusOn = null;
			refreshDifficultyDropDown();
		}
		openSubState(prompt);
	}

	function createNewDifficulty(rawName:String):String
	{
		if(PlayState.SONG == null) return 'No chart loaded.';

		var name:String = (rawName != null) ? rawName.trim() : '';
		if(name.length < 1) return 'Type a name first.';
		if(~/[\\\/:*?"<>|]/.match(name)) return 'Name cannot contain used characters.';

		var songName:String = PlayState.SONG.song;
		var diffs:Array<String> = difficultiesForSong(songName);
		for (diff in diffs)
			if(Paths.formatToSongPath(diff) == Paths.formatToSongPath(name))
				return '"$name" already exists for this song.';

		var weekName:String = weekOfSong(songName);
		var week:WeekData = (weekName != null) ? WeekData.weeksLoaded.get(weekName) : null;
		if(week == null) return 'Song not present in any week, cannot create difficulty.\nAdd the song to a week!';

		var chartFile:String = Paths.formatToSongPath(songName) + Paths.formatToSongPath('-' + name);
		var dir:String = songChartFolder(songName);
		try
		{
			if(!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			Song.chartPath = dir + chartFile + '.json';
			saveChart();
			pushRecentChart(Song.chartPath);
		}
		catch(e:Exception) { return 'Could not save chart: ${e.message}'; }

		var weekError:String = addDifficultyToWeek(week, name);
		if(weekError != null) return weekError;

		showOutput('Created "$name", added to week "$weekName".');
		return null;
	}

	function addDifficultyToWeek(week:WeekData, name:String):String
	{
		var current:String = (week.difficulties != null) ? week.difficulties.trim() : '';
		var updated:String = (current.length > 0) ? '$current, $name' : 'Easy, Normal, Hard, $name';

		var weekFile:WeekFile = {
			songs: week.songs,
			weekCharacters: week.weekCharacters,
			weekBackground: week.weekBackground,
			weekBefore: week.weekBefore,
			storyName: week.storyName,
			weekName: week.weekName,
			startUnlocked: week.startUnlocked,
			hiddenUntilUnlocked: week.hiddenUntilUnlocked,
			hideStoryMode: week.hideStoryMode,
			hideFreeplay: week.hideFreeplay,
			difficulties: updated
		};

		var folder:String = Paths.getRoutedSharedPath('weeks/');
		#if MODS_ALLOWED
		if(week.folder != null && week.folder.length > 0) folder = Paths.modsRoutedFolder('weeks/', week.folder);
		#end
		var path:String = folder + week.fileName + '.json';

		try
		{
			if(!FileSystem.exists(folder)) FileSystem.createDirectory(folder);
			File.saveContent(path, haxe.Json.stringify(weekFile, "\t"));
			week.difficulties = updated;
		}
		catch(e:Exception) { return 'Could not save the week: ${e.message}'; }

		trace('Week saved to: ${readablePath(path)}');
		return null;
	}

	function openGameSong(songName:String, diffIndex:Int)
	{
		difficultiesForSong(songName);

		var chartFile:String = Paths.formatToSongPath(songName) + Difficulty.getFilePath(diffIndex);
		var loaded:Bool = false;

		try
		{
			Song.loadFromJson(chartFile, songName);
			Song.chartPath = Song.chartPath.replace('\\', '/');
			loadChart(PlayState.SONG);
			pushRecentChart(Song.chartPath);
			loaded = true;
		}
		catch(e:Exception)
		{
			openNewChart(songName);
		}

		reloadNotesDropdowns();
		prepareReload();
		showOutput(loaded ? 'Opened "$chartFile" successfully!' : 'New chart created for "$songName".');
		closeStartupPrompt();
	}

	function findVSliceMetadata(chartPath:String):String
	{
		var cut:Int = chartPath.lastIndexOf('/') + 1;
		var folder:String = chartPath.substr(0, cut);
		var file:String = chartPath.substr(cut);

		var guess:String = folder + file.replace('chart.json', 'metadata.json');
		if(guess != chartPath && FileSystem.exists(guess)) return guess;

		if(folder.length > 0 && FileSystem.exists(folder) && FileSystem.isDirectory(folder))
		{
			for (found in FileSystem.readDirectory(folder))
				if(found.toLowerCase().endsWith('metadata.json')) return folder + found;
		}
		return null;
	}

	function importVSliceChart(?onDone:Void->Void)
	{
		if(!fileDialog.completed) return;
		if(upperBox != null)
		{
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;
		}

		fileDialog.open(null, 'Select a V-Slice chart file', null, function()
		{
			try
			{
				var chartPath:String = fileDialog.path.replace('\\', '/');
				var metaPath:String = findVSliceMetadata(chartPath);
				if(metaPath == null)
				{
					showOutput('Error: metadata file not found next to the chart.', true);
					return;
				}

				var chart:VSliceChart = cast Json.parse(fileDialog.data);
				var metadata:VSliceMetadata = cast Json.parse(File.getContent(metaPath));
				if(chart == null || metadata == null || metadata.playData == null)
				{
					showOutput('Error: File loaded is not a valid V-Slice chart.', true);
					return;
				}

				applyVSlicePackage(VSlice.convertToPsych(chart, metadata), onDone);
			}
			catch(e:Exception)
			{
				showOutput('Error: ${e.message}', true);
				trace(e.stack);
			}
		});
	}

	function applyVSlicePackage(pack:PsychPackage, ?onDone:Void->Void)
	{
		var diffNames:Array<String> = [];
		for (key in pack.difficulties.keys()) diffNames.push(key);

		if(diffNames.length < 1)
		{
			showOutput('Error: no difficulties found in this V-Slice chart.', true);
			return;
		}

		var loadDiff:String->Void = function(diff:String)
		{
			var song:SwagSong = pack.difficulties.get(diff);
			if(song == null) return;

			if(pack.events != null && pack.events.events != null)
				song.events = pack.events.events;

			loadChart(song);
			Song.chartPath = null;
			reloadNotesDropdowns();
			prepareReload();
			showOutput('Imported "${song.song}" ($diff) from V-Slice successfully!');
		}

		if(diffNames.length == 1)
		{
			loadDiff(diffNames[0]);
			if(onDone != null) onDone();
			return;
		}

		if(onDone != null) onDone();

		var hei:Int = 120 + diffNames.length * 30;
		openSubState(new BasePrompt(420, hei, 'Choose a Difficulty',
			function(state:BasePrompt) {
				var btnY:Float = state.bg.y + 70;
				for (diff in diffNames)
				{
					var btn:PsychUIButton = new PsychUIButton(0, btnY, diff, function()
					{
						loadDiff(diff);
						state.close();
					}, 180);
					btn.screenCenter(X);
					btn.cameras = state.cameras;
					state.add(btn);
					btnY += 30;
				}
			}));
	}

	function findCodenameMeta(chartPath:String):String
	{
		var cut:Int = chartPath.lastIndexOf('/') + 1;
		var folder:String = chartPath.substr(0, cut);

		var candidates:Array<String> = [folder + 'meta.json'];
		if(folder.length > 1)
		{
			var parts:Array<String> = folder.substr(0, folder.length - 1).split('/');
			parts.pop();
			if(parts.length > 0) candidates.push(parts.join('/') + '/meta.json');
		}

		for (path in candidates)
			if(FileSystem.exists(path)) return path;

		return null;
	}

	function importCodenameChart(?onDone:Void->Void)
	{
		if(!fileDialog.completed) return;
		if(upperBox != null)
		{
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;
		}

		fileDialog.open(null, 'Select a Codename difficulty chart', null, function()
		{
			try
			{
				var chartPath:String = fileDialog.path.replace('\\', '/');
				var chart:Dynamic = Json.parse(fileDialog.data);
				if(chart == null || chart.strumLines == null)
				{
					showOutput('Error: File loaded is not a valid Codename chart.', true);
					return;
				}

				var metaPath:String = findCodenameMeta(chartPath);
				var meta:Dynamic = (metaPath != null) ? Json.parse(File.getContent(metaPath)) : null;
				if(meta == null) showOutput('Warning: meta.json not found, BPM defaulted to 100.', true);

				var songName:String = getSongFolderFromPath(chartPath);
				if(meta != null && Reflect.field(meta, 'name') != null) songName = Reflect.field(meta, 'name');

				chart.format = 'codename_convert';
				Codename.convertToPsych(chart, meta, songName);

				loadChart(chart);
				Song.chartPath = null;
				reloadNotesDropdowns();
				prepareReload();
				showOutput('Imported "${chart.song}" from Codename successfully!');
				if(onDone != null) onDone();
			}
			catch(e:Exception)
			{
				showOutput('Error: ${e.message}', true);
				trace(e.stack);
			}
		});
	}

	function weekOfSong(songName:String):String
	{
		if(songName == null) return null;

		var cached:String = startupSongWeek.get(songName);
		if(cached != null) return cached;

		if(WeekData.weeksList.length < 1) WeekData.reloadWeekFiles(false);

		var formatted:String = Paths.formatToSongPath(songName);
		for (weekName in WeekData.weeksList)
		{
			var week:WeekData = WeekData.weeksLoaded.get(weekName);
			if(week == null || week.songs == null) continue;

			for (song in week.songs)
			{
				if(song[0] == null) continue;
				if(Paths.formatToSongPath(song[0]) == formatted)
				{
					startupSongWeek.set(songName, weekName);
					return weekName;
				}
			}
		}
		return null;
	}

	function difficultiesForSong(songName:String):Array<String>
	{
		var weekName:String = weekOfSong(songName);
		var week:WeekData = (weekName != null) ? WeekData.weeksLoaded.get(weekName) : null;

		if(week != null) Difficulty.loadFromWeek(week);
		else Difficulty.resetList();

		return Difficulty.list.copy();
	}

	function refreshStartupRecents()
	{
		if(startupPrompt == null) return;

		var paths:Array<String> = recentChartList();
		var labels:Array<String> = [];
		for (path in paths) labels.push(recentChartLabel(path));
		startupPrompt.setRecents(paths, labels);
	}

	function openRecentChart(path:String)
	{
		if(!FileSystem.exists(path))
		{
			showOutput('Error: "$path" no longer exists.', true);
			refreshStartupRecents();
			return;
		}

		try
		{
			var loadedChart:SwagSong = Song.parseJSON(File.getContent(path), getSongFolderFromPath(path));
			if(loadedChart == null || !Reflect.hasField(loadedChart, 'song'))
			{
				showOutput('Error: File loaded not compatible. Must be Psych/FNF Legacy Chart!', true);
				return;
			}

			loadChart(loadedChart);
			Song.chartPath = path;
			reloadNotesDropdowns();
			prepareReload();
			pushRecentChart(path);
			showOutput('Opened chart "$path" successfully!');
			closeStartupPrompt();
		}
		catch(e:Exception)
		{
			showOutput('Error: ${e.message}', true);
			trace(e.stack);
		}
	}

	var startupPrompt:ChartStartupPrompt;
	function openStartupPrompt()
	{
		startupPrompt = new ChartStartupPrompt();
		startupPrompt.onBrowse = function() openChartDialog(true, closeStartupPrompt);
		startupPrompt.onImportVSlice = function() importVSliceChart(closeStartupPrompt);
		startupPrompt.onImportCodename = function() importCodenameChart(closeStartupPrompt);
		startupPrompt.onCreateNew = openNewChartWizard;
		startupPrompt.onCreateNewTest = function()
		{
			openNewChart();
			reloadNotesDropdowns();
			prepareReload();
			closeStartupPrompt();
		}
		startupPrompt.onOpenRecent = openRecentChart;
		startupPrompt.difficultiesOf = difficultiesForSong;
		startupPrompt.onCreateFromSong = openGameSong;
		refreshStartupRecents();
		startupPrompt.setSongs(gameSongList());
		openSubState(startupPrompt);
	}

	function openNewChartWizard()
	{
		closeStartupPrompt();

		var wizard:NewChartPrompt = new NewChartPrompt(stageDropDown.list, characterList);
		wizard.onAccept = function(song:SwagSong)
		{
			openSongAudioPrompt(song, wizard.outArtist, wizard.outComposer, wizard.outCharter, wizard.outCoder);
		}
		wizard.onCancel = openStartupPrompt;
		openSubState(wizard);
	}

	function songAudioFolder(songName:String):String
	{
		var folder:String = Paths.formatToSongPath(songName);

		#if MODS_ALLOWED
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			return Paths.mods(Mods.currentModDirectory + '/data/songs/$folder/song/');
		#end

		return 'assets/data/songs/$folder/song/';
	}

	function songDataFolder(songName:String):String
	{
		var folder:String = Paths.formatToSongPath(songName);

		#if MODS_ALLOWED
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			return Paths.mods(Mods.currentModDirectory + '/data/songs/$folder/');
		#end

		return 'assets/data/songs/$folder/';
	}

	function songChartFolder(songName:String):String
		return songDataFolder(songName) + 'charts/';

	function readablePath(path:String):String
	{
		try { return FileSystem.absolutePath(path).replace('\\', '/'); }
		catch(e:Exception) { return path; }
	}

	function defaultChartPath(songName:String):String
	{
		var folder:String = Paths.formatToSongPath(songName);
		return songChartFolder(songName) + '$folder.json';
	}

	function importSongAudio(sourcePath:String, songName:String, targetName:String):String
	{
		if(sourcePath == null || sourcePath.length < 1) return 'No file selected.';

		var src:String = sourcePath.replace('\\', '/');
		if(!src.toLowerCase().endsWith('.${Paths.SOUND_EXT}'))
			return 'Only .${Paths.SOUND_EXT} files are supported.';

		if(!FileSystem.exists(src)) return 'File not found: $src';

		var dir:String = songAudioFolder(songName);
		var dest:String = dir + targetName + '.${Paths.SOUND_EXT}';

		try
		{
			if(!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			if(FileSystem.exists(dest) && FileSystem.absolutePath(src) == FileSystem.absolutePath(dest))
				return null;

			File.copy(src, dest);
		}
		catch(e:Exception)
		{
			return 'Could not copy: ${e.message}';
		}
		return null;
	}
		function openSongAudioPrompt(song:SwagSong, artist:String, composer:String, charter:String, coder:String)
	{
		var dir:String = songAudioFolder(song.song);
		var prompt:SongAudioPrompt = new SongAudioPrompt(dir, readablePath(dir));
		prompt.onBrowse = function(target:String) browseSongAudio(prompt, song.song, target);
		prompt.onDone = function() finishNewChart(song, artist, composer, charter, coder);
		openSubState(prompt);
	}

	function browseSongAudio(prompt:SongAudioPrompt, songName:String, target:String)
	{
		if(!fileDialog.completed) return;

		fileDialog.open(null, 'Select the "$target" file', [new FileFilter('OGG', 'ogg')],
			function()
			{
				var error:String = importSongAudio(fileDialog.path, songName, target);
				if(error != null) prompt.setStatus(target, error, false);
				else prompt.setStatus(target, 'copied', true);
			},
			function() {},
			function() prompt.setStatus(target, 'error opening the file', false));
	}

	function finishNewChart(song:SwagSong, artist:String, composer:String, charter:String, coder:String)
	{
		var dataDir:String = songDataFolder(song.song);
		try
		{
			if(!FileSystem.exists(dataDir)) FileSystem.createDirectory(dataDir);
			Song.chartPath = defaultChartPath(song.song);
		}
		catch(e:Exception)
		{
			Song.chartPath = null;
		}

		song.needsVoices = FileSystem.exists(songAudioFolder(song.song) + 'Voices.${Paths.SOUND_EXT}') || FileSystem.exists(songAudioFolder(song.song) + 'Voices-Player.${Paths.SOUND_EXT}');
		loadChart(song);
		reloadNotesDropdowns();
		prepareReload();
		applyNewChartCredits(artist, composer, charter, coder);
	}

	function closeStartupPrompt()
	{
		if(startupPrompt == null) return;
		var prompt:ChartStartupPrompt = startupPrompt;
		startupPrompt = null;
		prompt.close();
	}

	function openChartDialog(?skipWarning:Bool = false, ?onLoaded:Void->Void)
	{
		if(!fileDialog.completed) return;
		if(upperBox != null)
		{
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;
		}

		fileDialog.open(function()
		{
			try
			{
				var filePath:String = fileDialog.path.replace('\\', '/');
				var loadedChart:SwagSong = Song.parseJSON(fileDialog.data, getSongFolderFromPath(filePath));
				if(loadedChart == null || !Reflect.hasField(loadedChart, 'song'))
				{
					showOutput('Error: File loaded not compatible. Must be Psych/FNF Legacy Chart!', true);
					return;
				}

				var func:Void->Void = function()
				{
					loadChart(loadedChart);
					Song.chartPath = filePath;
					reloadNotesDropdowns();
					prepareReload();
					pushRecentChart(filePath);
					showOutput('Opened chart "${Song.chartPath}" successfully!');
					if(onLoaded != null) onLoaded();
				}

				if(!skipWarning && !ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning!\nAny unsaved progress will be lost.', func));
				else func();
			}
			catch(e:Exception)
			{
				showOutput('Error: ${e.message}', true);
				trace(e.stack);
			}
		});
	}

	function prepareReload()
	{
		updateJsonData();
		loadMusic();
		onChartLoaded();
		updateHeads(true);

		rebuildGridPlayers();

		reloadNotesDropdowns();
		reloadNotes();

		autoSaveTime = 0;
		Conductor.songPosition = 0;
		if(FlxG.sound.music != null) FlxG.sound.music.time = 0;
		curSec = 0;
		loadSection();
		forceDataUpdate = true;
	}

	function onChartLoaded()
	{
		if(PlayState.SONG == null) return;

		// SONG TAB
		songNameInputText.text = PlayState.SONG.song;
		allowVocalsCheckBox.checked = (PlayState.SONG.needsVoices != false); //If the song for some reason does not have this value, it will be set to true

		bpmStepper.value = PlayState.SONG.bpm;
		scrollSpeedStepper.value = PlayState.SONG.speed;
		audioOffsetStepper.value = Reflect.hasField(PlayState.SONG, 'offset') ? PlayState.SONG.offset : 0;
		Conductor.offset = audioOffsetStepper.value;

		playerDropDown.selectedLabel = PlayState.SONG.player1;
		opponentDropDown.selectedLabel = PlayState.SONG.player2;
		girlfriendDropDown.selectedLabel = PlayState.SONG.gfVersion;
		stageDropDown.selectedLabel = PlayState.SONG.stage;
		StageData.loadDirectory(PlayState.SONG);

		// DATA TAB
		gameOverCharDropDown.selectedLabel = PlayState.SONG.gameOverChar;
		gameOverSndInputText.text = PlayState.SONG.gameOverSound;
		gameOverLoopInputText.text = PlayState.SONG.gameOverLoop;
		gameOverRetryInputText.text = PlayState.SONG.gameOverEnd;

		noRGBCheckBox.checked = (PlayState.SONG.disableNoteRGB == true);
		noSplashRGBCheckBox.checked = (PlayState.SONG.disableSplashRGB == true);
		noHoldRGBCheckBox.checked = (PlayState.SONG.disableHoldRGB == true);

		noteTextureInputText.text = PlayState.SONG.arrowSkin;
		noteSplashesInputText.text = PlayState.SONG.splashSkin;
		holdCoverInputText.text = PlayState.SONG.holdCoverSkin;

		strumlineConfigs = [];
		if(PlayState.SONG.extraStrumlines != null)
			for(data in PlayState.SONG.extraStrumlines)
				strumlineConfigs.push(data);

		var extraCount:Int = strumlineConfigs.length;
		var detectedPlayers:Int = (PlayState.SONG.mania >= 1) ? PlayState.SONG.mania : (2 + extraCount);
		if(PlayState.SONG.notes != null)
		{
			var maxCol:Int = 0;
			for(section in PlayState.SONG.notes)
				if(section != null && section.sectionNotes != null)
					for(note in section.sectionNotes)
						if(note != null && Std.int(note[1]) > maxCol && Std.int(note[1]) < GRID_COLUMNS_PER_PLAYER * 8)
								maxCol = Std.int(note[1]);
			var detectedFromNotes:Int = Math.ceil((maxCol + 1) / GRID_COLUMNS_PER_PLAYER);
			if(detectedFromNotes > detectedPlayers)
				detectedPlayers = detectedFromNotes;
		}
		GRID_PLAYERS = Std.int(Math.max(1, detectedPlayers));
		var savedCallback = strumsStepper.onValueChange;
		strumsStepper.onValueChange = null;
		strumsStepper.value = GRID_PLAYERS;
		strumsStepper.onValueChange = savedCallback;

		updateJsonData();

		loadMetaDataCredits();
		refreshDifficultyDropDown();
	}

	function loadMetaDataCredits()
	{
		var loadedMeta:funkin.data.MetaData.SongMeta = funkin.data.MetaData.parse(Paths.formatToSongPath(PlayState.SONG.song));

		metaDataCreditsA = [];
		metaDataCreditsCO = [];
		metaDataCreditsCH = [];
		metaDataCreditsCOD = [];
		artistInputText.text = '';
		composerInputText.text = '';
		charterInputText.text = '';
		coderInputText.text = '';
		pauseDisplayNameInputText.text = (loadedMeta.pauseDisplayName != null) ? loadedMeta.pauseDisplayName : '';
		showAllCreditsCheckBox.checked = loadedMeta.showAllCredits;
		
		for(credit in loadedMeta.credits)
		{
			if(credit.names != null && credit.names.length > 0)
			{
				if(credit.role == "Artist")
				{
					metaDataCreditsA = credit.names;
					artistInputText.text = credit.names.join(', ');
				}
				else if(credit.role == "Composer")
				{
					metaDataCreditsCO = credit.names;
					composerInputText.text = credit.names.join(', ');
				}
				else if(credit.role == "Charter")
				{
					metaDataCreditsCH = credit.names;
					charterInputText.text = credit.names.join(', ');
				}
				else if(credit.role == "Coder")
				{
					metaDataCreditsCOD = credit.names;
					coderInputText.text = credit.names.join(', ');
				}
			}
		}
	}

	function applyNewChartCredits(artist:String, composer:String, charter:String, coder:String)
	{
		metaDataCreditsA = splitCredits(artist);
		metaDataCreditsCO = splitCredits(composer);
		metaDataCreditsCH = splitCredits(charter);
		metaDataCreditsCOD = splitCredits(coder);

		artistInputText.text = metaDataCreditsA.join(', ');
		composerInputText.text = metaDataCreditsCO.join(', ');
		charterInputText.text = metaDataCreditsCH.join(', ');
		coderInputText.text = metaDataCreditsCOD.join(', ');
	}

	function splitCredits(raw:String):Array<String>
	{
		if(raw == null) return [];
		return raw.split(',').map(function(s:String) return s.trim()).filter(function(s:String) return s.length > 0);
	}
	
	var noteSelectionSine:Float = 0;
	var selectedNotes:Array<MetaNote> = [];

	var pendingNote:MetaNote = null;
	var pendingWasSelected:Bool = false;
	var pendingDuplicate:Bool = false;
	var pendingMouseX:Float = 0;
	var pendingMouseY:Float = 0;
	static inline final DRAG_THRESHOLD:Float = 4;

	var ignoreClickForThisFrame:Bool = false;
	var _leftClickedOffGrid:Bool = false;
	var _rightClickedOffGrid:Bool = false;
	var outputAlpha:Float = 0;
	var songFinished:Bool = false;

	var fileDialog:FileDialogHandler = new FileDialogHandler();
	var lastFocus:PsychUIInputText;

	var autoSaveTime:Float = 0;
	var autoSaveCap:Int = 2; //in minutes
	var backupLimit:Int = 10;

	var lastBeatHit:Int = 0;

	function setCursorKind(kind:Int)
	{
		if(cursorKind == kind || customCursor == null || kind >= cursorFrames.length) return;

		cursorKind = kind;
		customCursor.frames = cursorFrames[kind];
		customCursor.setGraphicSize(32, 32);
		customCursor.updateHitbox();
		customCursor.setPosition(FlxG.mouse.screenX, FlxG.mouse.screenY);
	}

	function mouseOverUpperMenu():Bool
	{
		if(upperBox == null || upperBox.isMinimized || upperBox.selectedTab == null) return false;

		var menu = upperBox.selectedTab.menu;
		return (menu != null && menu.visible && FlxG.mouse.overlaps(menu));
	}

	function mouseOverGrid():Bool{
		if(gridBg == null || mouseOverUpperMenu()) return false;

		return FlxG.mouse.x >= gridBg.x && FlxG.mouse.x < gridBg.x + gridBg.width &&
			FlxG.mouse.y >= gridBg.y && FlxG.mouse.y < gridBg.y + gridBg.height;
	}

	override function update(elapsed:Float)
	{
		if(customCursor != null && customCursor.visible)
			customCursor.setPosition(FlxG.mouse.screenX, FlxG.mouse.screenY);

		#if FLX_DEBUG
		if(!_songPlayIntent && FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}
		#end

		if(upperBox != null && !upperBox.isMinimized && (FlxG.mouse.justPressed || FlxG.mouse.justPressedRight))
		{
			var overTabs:Bool = (FlxG.mouse.screenY < upperBox.tabHeight + 6 && FlxG.mouse.screenX < upperBox.bg.width);
			if(!overTabs && !mouseOverUpperMenu())
			{
				upperBox.isMinimized = true;
				upperBox.bg.visible = false;
			}
		}

		if(!fileDialog.completed)
		{
			lastFocus = PsychUIInputText.focusOn;
			return;
		}

		for (num => key in keysArray)
			_keysPressedBuffer[num] = FlxG.keys.checkStatus(key, JUST_PRESSED);

		if(autoSaveCap > 0)
		{
			autoSaveTime += elapsed / 60.0;
			//trace(autoSaveTime);
			//#if debug if(FlxG.keys.justPressed.J) autoSaveTime += 20/60.0; #end
			if(autoSaveTime >= autoSaveCap #if debug || FlxG.keys.justPressed.NUMPADMULTIPLY #end)
			{
				FlxTween.cancelTweensOf(autoSaveIcon);
				autoSaveTime = 0;
				autoSaveIcon.alpha = 0;
				updateChartData();
				var chartName:String = 'unknown';
				if(Song.chartPath != null)
				{
					chartName = Song.chartPath.replace('\\', '/');
					chartName = chartName.substring(chartName.lastIndexOf('/')+1, chartName.lastIndexOf('.'));
				}
				chartName += DateTools.format(Date.now(), '_%Y-%m-%d_%H-%M-%S');
				var songCopy:SwagSong = Reflect.copy(PlayState.SONG);
				Reflect.setField(songCopy, '__original_path', Song.chartPath);
				var dataToSave:String = haxe.Json.stringify(songCopy);
				//trace(chartName, dataToSave);
				if(!FileSystem.isDirectory('backups')) FileSystem.createDirectory('backups');
				File.saveContent('backups/$chartName.$BACKUP_EXT', dataToSave);

				if(backupLimit > 0)
				{
					var files:Array<String> = FileSystem.readDirectory('backups/').filter((file:String) -> file.endsWith('.$BACKUP_EXT'));
					if(files.length > backupLimit)
					{
						var incorrect:Array<String> = [];
						var map:Map<String, Float> = [];
						for(file in files)
						{
							var split:Array<String> = file.split('_');
							if(split.length > 2) //is properly formatted
							{
								try
								{
									var timeStr:String = split[split.length-1].replace('-', ':');
									timeStr = timeStr.substr(0, timeStr.indexOf('.'));

									var fileJoin:String = split[split.length-2] + ' ' + timeStr;
									var date:Date = Date.fromString(fileJoin);
									//trace(fileJoin, date.getTime());
									map.set(file, date.getTime());
								}
								catch(e:Exception)
								{
									incorrect.push(file);
								}
							}
							else incorrect.push(file);
						}

						if(incorrect.length > 0) files = files.filter((file:String) -> !incorrect.contains(file));
						files.sort(function(a:String, b:String) return map.get(a) > map.get(b) ? 1 : -1);

						while(files.length > backupLimit)
						{
							var file = files.shift();
							//trace('removed $file');
							try
							{
								FileSystem.deleteFile('backups/$file');
							}
							catch(e:Exception) {}
						}
					}
				}

				FlxTween.tween(autoSaveIcon, {alpha: 1}, 0.5, {onComplete: function(_)
					FlxTween.tween(autoSaveIcon, {alpha: 0}, 0.5, {startDelay: 2})
				});
			}
		}

		ClientPrefs.toggleVolumeKeys(PsychUIInputText.focusOn == null);

		var lastTime:Float = Conductor.songPosition;
		outputAlpha = Math.max(0, outputAlpha - elapsed);
		var holdingAlt:Bool = FlxG.keys.pressed.ALT;
		if(FlxG.sound.music != null)
		{
			if(PsychUIInputText.focusOn == null && lastFocus == null) //If not typing anything
			{
				if(FlxG.keys.justPressed.ENTER)
				{
					if(FlxG.keys.pressed.CONTROL)
					{
						super.update(elapsed);
						openEditorPlayState();
						lastFocus = PsychUIInputText.focusOn;
						return;
					}

					goToPlayState(FlxG.keys.pressed.SHIFT);
					return;
				}
				else if(FlxG.keys.justPressed.F1)
				{
					setTipVisible(!fullTipText.visible);
				}

				if(vortexEnabled && _keysPressedBuffer.contains(true))
				{
					var typeSelected:String = noteTypes[noteTypeDropDown.selectedIndex];
					if(typeSelected != null)
					{
						typeSelected = typeSelected.trim();
						if(typeSelected.length < 1) typeSelected = null;
					}

					var sectionStart:Float = cachedSectionTimes[curSec];
					var strumTime:Float = Conductor.songPosition - sectionStart;
					strumTime -= strumTime % (Conductor.stepCrochet * 16 / curQuant);
					strumTime += sectionStart;

					trace('Vortex editor press at time: $strumTime');
					var deletedNotes:Array<MetaNote> = [];
					var addedNotes:Array<MetaNote> = [];
					for (num => press in _keysPressedBuffer)
					{
						if(!press) continue;

						// Try to find a note to delete first
						var didDelete:Bool = false;
						for (note in curRenderedNotes)
						{
							if(note == null || note.isEvent) continue;

							if(note.songData[1] == num && Math.abs(strumTime - note.strumTime) < 1)
							{
								deletedNotes.push(note);
								didDelete = true;
								break;
							}
						}

						if(didDelete) continue;

						// If no notes were found, add a new in its place
						var didAdd:Bool = false;
						var noteSetupData:Array<Dynamic> = [strumTime, num, 0];
						if(typeSelected != null) noteSetupData.push(typeSelected);
	
						var noteAdded:MetaNote = createNote(noteSetupData);
						for (num in sectionFirstNoteID...notes.length)
						{
							var note = notes[num];
							if(note.strumTime >= strumTime)
							{
								notes.insert(num, noteAdded);
								didAdd = true;
								break;
							}
						}
						if(!didAdd) notes.push(noteAdded);
						addedNotes.push(noteAdded);
					}

					if(deletedNotes.length > 0)
					{
						var wasSelected:Bool = false;
						for (note in deletedNotes)
						{
							if(selectedNotes.contains(note))
							{
								selectedNotes.remove(note);
								wasSelected = true;
							}
							notes.remove(note);
						}
						if(wasSelected) onSelectNote();
						addUndoAction(DELETE_NOTE, {notes: deletedNotes});
					}
					if(addedNotes.length > 0)
						addUndoAction(ADD_NOTE, {notes: addedNotes});

					softReloadNotes(true);
				}
				else if(FlxG.keys.justPressed.A != FlxG.keys.justPressed.D && !holdingAlt && !FlxG.keys.pressed.CONTROL)
				{
					if(FlxG.sound.music.playing)
						setSongPlaying(false);

					var shiftAdd:Int = FlxG.keys.pressed.SHIFT ? 4 : 1;

					if(FlxG.keys.justPressed.A)
					{
						if(curSec - shiftAdd < 0) shiftAdd = curSec;

						if(shiftAdd > 0)
						{
							var targetSec:Int = curSec - shiftAdd;
							Conductor.songPosition = FlxG.sound.music.time = cachedSectionTimes[targetSec] - Conductor.offset + 0.000001;
							loadSection(targetSec);
						}
					}
					else if(FlxG.keys.justPressed.D)
					{
						if(curSec + shiftAdd >= PlayState.SONG.notes.length) shiftAdd = PlayState.SONG.notes.length - curSec - 1;
						
						if(shiftAdd > 0)
						{
							var targetSec:Int = curSec + shiftAdd;
							Conductor.songPosition = FlxG.sound.music.time = cachedSectionTimes[targetSec] - Conductor.offset + 0.000001;
							loadSection(targetSec);
						}
					}
				}
				else if(FlxG.keys.justPressed.P)
				{
					setSongPlaying(false);
					Conductor.songPosition = FlxG.sound.music.time = 0;
					loadSection(0);
				}
				else if(FlxG.keys.justPressed.L)
				{
					setSongPlaying(false);
					Conductor.songPosition = FlxG.sound.music.time = FlxG.sound.music.length - 1;
					loadSection(PlayState.SONG.notes.length - 1);
				}

				var toyWheel:Bool = (FlxG.mouse.wheel != 0 && resizeHoveredToy(FlxG.mouse.wheel));

				if(FlxG.keys.pressed.CONTROL && FlxG.mouse.wheel != 0 && !toyWheel)
				{
					gridTargetX += FlxG.mouse.wheel * GRID_SIZE * 3;
				}
				else
				if(FlxG.keys.pressed.W != FlxG.keys.pressed.S || (FlxG.mouse.wheel != 0 && !FlxG.keys.pressed.CONTROL && !toyWheel))
				{
					if(FlxG.sound.music.playing)
						setSongPlaying(false);

					if(mouseSnapCheckBox.checked && FlxG.mouse.wheel != 0)
					{
						var snap:Float = Conductor.stepCrochet / (curQuant/16) / curZoom;
						var timeAdd:Float = (FlxG.keys.pressed.SHIFT ? 4 : 1) / (holdingAlt ? 4 : 1) * -FlxG.mouse.wheel * snap;
						var time:Float = Math.round((FlxG.sound.music.time + timeAdd) / snap) * snap;
						if(time > 0) time += 0.000001; //goes at the start of a section more properly
						FlxG.sound.music.time = time;
					}
					else
					{
						var speedMult:Float = (FlxG.keys.pressed.SHIFT ? 4 : 1) * (FlxG.mouse.wheel != 0 ? 4 : 1) / (holdingAlt ? 4 : 1);
						if(FlxG.keys.pressed.W || FlxG.mouse.wheel > 0)
							FlxG.sound.music.time -= Conductor.crochet * speedMult * 1.5 * elapsed / curZoom;
						else if(FlxG.keys.pressed.S || FlxG.mouse.wheel < 0)
							FlxG.sound.music.time += Conductor.crochet * speedMult * 1.5 * elapsed / curZoom;
					}

					FlxG.sound.music.time = FlxMath.bound(FlxG.sound.music.time, 0, FlxG.sound.music.length - 1);
					if(FlxG.sound.music.playing) setSongPlaying(!FlxG.sound.music.playing);
				}
				else if(FlxG.keys.justPressed.SPACE)
				{
					setSongPlaying(!FlxG.sound.music.playing);
				}
			}

			if(!songFinished) Conductor.songPosition = FlxMath.bound(FlxG.sound.music.time + Conductor.offset, 0, FlxG.sound.music.length - 1);
			updateScrollY();
		}

		updateToyHover();
		super.update(elapsed);
		
		if(songFinished)
		{
			onSongComplete();
			lastTime = FlxG.sound.music.time;
			songFinished = false;
		}
		else if(FlxG.sound.music != null)
		{
			if(FlxG.sound.music.time >= vocals.length)
				vocals.pause();
			if(FlxG.sound.music.time >= opponentVocals.length)
				opponentVocals.pause();

			while(curSec > 0 && Conductor.songPosition < cachedSectionTimes[curSec])
				loadSection(curSec - 1);
			while(curSec < cachedSectionTimes.length - 1 && Conductor.songPosition >= cachedSectionTimes[curSec + 1])
				loadSection(curSec + 1);
		}

		if(PsychUIInputText.focusOn == null && lastFocus == null)
		{
			var doCut:Bool = false;
			var canContinue:Bool = true;
			if(FlxG.keys.justPressed.ESCAPE && !isMovingNotes)
			{
				if(fullTipText.visible)
					setTipVisible(false);
				else
					exitEditor();

				return;
			}
			else if(fullTipText.visible && FlxG.keys.justPressed.LEFT != FlxG.keys.justPressed.RIGHT)
			{
				showTipPage(curTipPage + (FlxG.keys.justPressed.RIGHT ? 1 : -1));
				return;
			}
			else if(FlxG.keys.justPressed.ENTER)
			{
				goToPlayState();
				return;
			}
			else if(FlxG.keys.pressed.CONTROL && !isMovingNotes && (FlxG.keys.justPressed.Z || FlxG.keys.justPressed.X ||
				FlxG.keys.justPressed.C || FlxG.keys.justPressed.V || FlxG.keys.justPressed.A || FlxG.keys.justPressed.S))
			{
				canContinue = false;
				if(FlxG.keys.justPressed.Z)
				{
					if(FlxG.keys.pressed.SHIFT) redo();
					else undo();
					return;
				}
				else if((doCut = FlxG.keys.justPressed.X) || FlxG.keys.justPressed.C) // Cut (Ctrl + X) and Copy (Ctrl + C)
				{
					if(selectedNotes.length > 0)
					{
						copiedNotes = [];
						copiedEvents = [];
						var pushedNotes:Array<Array<Dynamic>> = [];

						for (note in selectedNotes)
						{
							if(note == null) continue;

							var copied:Array<Dynamic> = makeNoteDataCopy(note.songData, note.isEvent);
							pushedNotes.push(copied);
							if(note.isEvent) copiedEvents.push(copied);
							else copiedNotes.push(copied);
						}
						pushedNotes.sort((a:Array<Dynamic>, b:Array<Dynamic>) -> FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]));
						
						var minTime:Float = pushedNotes[0][0];
						for (note in pushedNotes)
							note[0] -= minTime;
					}
				}
				else if(FlxG.keys.justPressed.V) // Paste (Ctrl + V)
				{
					if(copiedNotes.length > 0 || copiedEvents.length > 0)
					{
						selectionBox.visible = false;
						stopMovingNotes();
						resetSelectedNotes();
						selectedNotes = pasteCopiedNotesToSection();
						selectedNotes.sort(PlayState.sortByTime);

						var didFind:Bool = false;
						var minNoteData:Float = Math.POSITIVE_INFINITY;
						for (note in selectedNotes)
						{
							if(note == null || note.isEvent) continue;

							if(minNoteData > note.songData[1]) minNoteData = note.songData[1];
							didFind = true;
						}
						if(!didFind) minNoteData = 0;
						
						var pushedNotes:Array<MetaNote> = [];
						var pushedEvents:Array<EventMetaNote> = [];
						for (note in selectedNotes)
						{
							if(note == null) continue;

							if(!note.isEvent)
							{
								note.changeNoteData(Std.int(note.songData[1] - minNoteData));
								pushedNotes.push(note);
							}
							else pushedEvents.push(cast (note, EventMetaNote));
						}
						addUndoAction(ADD_NOTE, {notes: pushedNotes, events: pushedEvents});
						moveSelectedNotes(Std.int(minNoteData), selectedNotes[0].y);
					}
				}
				else if(FlxG.keys.justPressed.A)
				{
					var sel = selectedNotes.copy();
					if(FlxG.keys.pressed.SHIFT)
						selectedNotes = notes.copy().concat(cast events);
					else
						selectedNotes = curRenderedNotes.members.copy();

					addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
					onSelectNote();
					trace('Notes selected: ' + selectedNotes.length);
				}
				else if(FlxG.keys.justPressed.S) // Save (Ctrl + S)
					saveChart();
			}
			
			if(doCut || FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE || (isMovingNotes && (FlxG.mouse.justPressedRight || FlxG.keys.justPressed.ESCAPE)))
			{
				if(selectedNotes.length > 0)
				{
					FlxG.sound.play(Paths.sound('chartingSounds/undo'));
					var removedNotes:Array<MetaNote> = [];
					var removedEvents:Array<EventMetaNote> = [];
					while(selectedNotes.length > 0)
					{
						var note:MetaNote = selectedNotes[0];
						selectedNotes.shift();
						if(note == null) continue;
		
						var kind:String = !note.isEvent ? 'note' : 'event';
						trace('Removed $kind at time: ${note.strumTime}');
						if(!note.isEvent)
						{
							notes.remove(note);
							removedNotes.push(note);
						}
						else
						{
							var ev:EventMetaNote = cast (note, EventMetaNote);
							events.remove(ev);
							removedEvents.push(ev);
						}
					}
					movingNotes.clear();
					isMovingNotes = false;
					selectedNotes = [];
					noteHighlights.clear();
					onSelectNote();
					softReloadNotes();
					addUndoAction(DELETE_NOTE, {notes: removedNotes, events: removedEvents});
				}
			}
			else if(canContinue)
			{
				if(FlxG.keys.justPressed.LEFT != FlxG.keys.justPressed.RIGHT) //Lower/Higher quant
				{
					if(FlxG.keys.justPressed.LEFT)
						curQuant = quantizations[Std.int(Math.max(quantizations.indexOf(curQuant) - 1, 0))];
					else
						curQuant = quantizations[Std.int(Math.min(quantizations.indexOf(curQuant) + 1, quantizations.length - 1))];
					forceDataUpdate = true;
				}
				else if(FlxG.keys.justPressed.Z != FlxG.keys.justPressed.X) //Decrease/Increase Zoom
				{
					if(FlxG.keys.justPressed.Z)
						curZoom = zoomList[Std.int(Math.max(zoomList.indexOf(curZoom) - 1, 0))];
					else
						curZoom = zoomList[Std.int(Math.min(zoomList.indexOf(curZoom) + 1, zoomList.length - 1))];
	
					notes.sort(PlayState.sortByTime);
					var noteSec:Int = 0;
					for (num => note in notes)
					{
						if(note == null) continue;
			
						while(noteSec + 1 < cachedSectionCrochets.length && cachedSectionTimes[noteSec + 1] <= note.strumTime)
							noteSec++;

						positionNoteYOnTime(note, noteSec);
						note.updateSustainToZoom(cachedSectionCrochets[noteSec] / 4, curZoom);
					}
	
					for (event in events)
					{
						var secNum:Int = 0;
						for (time in cachedSectionTimes)
						{
							if(time > event.strumTime) break;
							secNum++;
						}
						positionNoteYOnTime(event, secNum);
					}
					loadSection();
					showOutput('Zoom: ${Math.round(curZoom * 100)}%');
					updateScrollY();
					if(selectedNotes.length > 0)
						onSelectNote();
				}
				else if(FlxG.keys.justPressed.H){
					toggleToyHitboxes();
				}
				else if(FlxG.keys.justPressed.R){
					reloadChartFromDisk();
				}
			}
		}

		if(selectionBox.visible)
		{
			if(FlxG.mouse.releasedRight)
			{
				var sel = selectedNotes.copy();
				updateSelectionBox();
				if(!FlxG.keys.pressed.SHIFT && !holdingAlt)
					resetSelectedNotes();

				var selectionBounds = selectionBox.getScreenBounds(_selectionBounds, camUI);
				for (note in curRenderedNotes)
				{
					if(note == null) continue;

					if(!selectedNotes.contains(note) || holdingAlt /*&& FlxG.overlap(selectionBox, note)*/) //overlap doesnt work here
					{
						var noteBounds = note.getScreenBounds(_noteBounds, camUI);
						noteBounds.top -= scrollY;
						noteBounds.bottom -= scrollY;

						if(selectionBounds.overlaps(noteBounds))
						{
							if(holdingAlt && selectedNotes.contains(note))
							{
								selectedNotes.remove(note);
								note.colorTransform.redMultiplier = note.colorTransform.greenMultiplier = note.colorTransform.blueMultiplier = 1;
								if(note.animation.curAnim != null) note.animation.curAnim.curFrame = 0;
							}
							else selectedNotes.push(note);
							onSelectNote();
						}
					}
				}
				selectionBox.visible = false;
				addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
			}
			else if(FlxG.mouse.justMoved)
				updateSelectionBox();
		}
		else if(FlxG.mouse.pressedRight && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0))
		{
			selectionBox.setPosition(FlxG.mouse.screenX, FlxG.mouse.screenY);
			selectionStart.set(FlxG.mouse.screenX, FlxG.mouse.screenY);
			selectionBox.visible = true;
			updateSelectionBox();
		}
		
		if(FlxG.mouse.justPressed){
			_leftClickedOffGrid = !mouseOverGrid();
			if(_leftClickedOffGrid) FlxG.sound.play(Paths.sound('chartingSounds/ClickDown'), 0.75);
		}

		if(FlxG.mouse.justReleased){
			if(_leftClickedOffGrid) FlxG.sound.play(Paths.sound('chartingSounds/ClickUp'), 0.75);
			_leftClickedOffGrid = false;
		}

		if(FlxG.mouse.justPressedRight){
			_rightClickedOffGrid = !mouseOverGrid();
			if(_rightClickedOffGrid) FlxG.sound.play(Paths.sound('chartingSounds/ClickDown'), 0.75);
		}

		if(FlxG.mouse.justReleasedRight){
			if(_rightClickedOffGrid) FlxG.sound.play(Paths.sound('chartingSounds/ClickUp'), 0.75);
			_rightClickedOffGrid = false;
		}
		
		if((FlxG.mouse.justPressed || FlxG.mouse.justPressedRight) && (FlxG.mouse.overlaps(mainBox.bg) || FlxG.mouse.overlaps(infoBox.bg) || mouseOverUpperMenu())){
			ignoreClickForThisFrame = true;
		}
		
		var isOverToy:Bool = false;
		if(toysEnabled)
		{
			for(toy in toyGroup)
			{
				if(toy != null && toy.grabAllowed)
				{
					isOverToy = true;
					if(FlxG.mouse.justPressed)
					{
						setCursorKind(CURSOR_GRABBING);
						isGrabbingCursor = true;
						cursorGrabTimer = 0.1;
					}
					ignoreClickForThisFrame = true;
					break;
				}
			}
		}

		if((FlxG.mouse.overlaps(miniChartBg) && !ignoreClickForThisFrame) || isDraggingMiniChart)
		{
			if(FlxG.mouse.justPressed)
			{
				if(miniChartScrollTween != null)
				{
					miniChartScrollTween.cancel();
					miniChartScrollTween = null;
				}
				
				isDraggingMiniChart = true;
				ignoreClickForThisFrame = true;
				
				if(FlxG.sound.music != null && FlxG.sound.music.playing)
					setSongPlaying(false);
				
				var clickY:Float = FlxG.mouse.screenY - miniChartBg.y;
				var clickProgress:Float = FlxMath.bound(clickY / miniChartBg.height, 0, 1);
				
				var targetTime:Float = FlxG.sound.music.length * clickProgress;
				var startTime:Float = FlxG.sound.music.time;
				
				miniChartScrollTween = FlxTween.tween(this, {}, 0.2, {
					ease: FlxEase.quadOut,
					onUpdate: function(twn:FlxTween) {
						var progress:Float = twn.percent;
						FlxG.sound.music.time = FlxMath.bound(FlxMath.lerp(startTime, targetTime - Conductor.offset, progress), 0, FlxG.sound.music.length - 1);
						Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;
					},
					onComplete: function(twn:FlxTween) {
						miniChartScrollTween = null;
					}
				});
			}
		}
		
		if(isDraggingMiniChart)
		{
			if(FlxG.mouse.pressed)
			{
				if(miniChartScrollTween != null)
				{
					miniChartScrollTween.cancel();
					miniChartScrollTween = null;
				}
				
				var clickY:Float = FlxG.mouse.screenY - miniChartBg.y;
				var clickProgress:Float = FlxMath.bound(clickY / miniChartBg.height, 0, 1);
				
				var targetTime:Float = FlxG.sound.music.length * clickProgress;
				var wasPlaying:Bool = FlxG.sound.music.playing;
				
				FlxG.sound.music.time = FlxMath.bound(targetTime - Conductor.offset, 0, FlxG.sound.music.length - 1);
				Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;
				
				vocals.time = FlxG.sound.music.time;
				opponentVocals.time = FlxG.sound.music.time;
				
				if(wasPlaying)
				{
					if(vocals.time < vocals.length && !vocals.playing) vocals.play(true, vocals.time);
					if(opponentVocals.time < opponentVocals.length && !opponentVocals.playing) opponentVocals.play(true, opponentVocals.time);
				}
				
				ignoreClickForThisFrame = true;
			}
			else
			{
				isDraggingMiniChart = false;
			}
		}

		if(FlxG.sound.music != null && FlxG.sound.music.length > 0)
		{
			var songProgress:Float = FlxMath.bound(Conductor.songPosition / FlxG.sound.music.length, 0, 1);
			var handleY:Float = miniChartBg.y + (songProgress * miniChartBg.height) - (miniChartHandle.height * 0.5);
			miniChartHandle.y = FlxMath.bound(handleY, miniChartBg.y, miniChartBg.y + miniChartBg.height - miniChartHandle.height);
			
			updateMiniChart();
		}

		var minX:Float = gridBg.x;
		if(SHOW_EVENT_COLUMN && lockedEvents) minX += GRID_SIZE;

		if(isMovingNotes && FlxG.mouse.justReleased)
			stopMovingNotes();

		if(pendingNote != null && (!FlxG.mouse.pressed || !pendingNote.exists))
		{
			if(pendingWasSelected && pendingNote.exists) deselectNote(pendingNote);
			pendingNote = null;
		}

		if(stretchingNote != null){
			if(FlxG.mouse.pressed)
			{
				var stretchY:Float = FlxG.mouse.y - gridBg.y;
				if(!FlxG.keys.pressed.CONTROL)
					stretchY -= stretchY % (GRID_SIZE / (curQuant/16));

				var stretchTime:Float = (stretchY / GRID_SIZE * Conductor.stepCrochet / curZoom) + cachedSectionTimes[curSec];

				var noteSec:Int = 0;
				while(cachedSectionCrochets.length > noteSec + 1 && cachedSectionTimes[noteSec + 1] <= stretchingNote.strumTime)
					noteSec++;

				var oldSus:Float = stretchingNote.sustainLength;
				stretchingNote.setSustainLength(Math.max(0, stretchTime - stretchingNote.strumTime), cachedSectionCrochets[noteSec] / 4, curZoom);

				if(stretchingNote.sustainLength != oldSus)
				{
					susLengthLastVal = susLengthStepper.value = stretchingNote.sustainLength;
					updateSustainHighlights(stretchingNote);

					stretchSoundFlip = !stretchSoundFlip;
					FlxG.sound.play(Paths.sound('chartingSounds/stretch${stretchSoundFlip ? 1 : 2}_UI'), 0.4);
				}
			}
			else
			{
				if(stretchingNote.sustainLength > 0)
					FlxG.sound.play(Paths.sound('chartingSounds/stretchSNAP_UI'), 0.6);

				stretchingNote = null;
			}
		}

		isHoveringNote = false;
		
		if(FlxG.mouse.x >= minX && FlxG.mouse.x < gridBg.x + gridBg.width)
		{
			for (note in curRenderedNotes)
			{
				if(note != null && FlxG.mouse.overlaps(note))
				{
					isHoveringNote = true;
					break;
				}
			}
			
			var diffX:Float = FlxG.mouse.x - gridBg.x;
			var diffY:Float = FlxG.mouse.y - gridBg.y;
			if(!FlxG.keys.pressed.CONTROL)
				diffY -= diffY % (GRID_SIZE / (curQuant/16));

			if(nextGridBg.visible) diffY = Math.min(diffY, gridBg.height + nextGridBg.height);
			else diffY = Math.min(diffY, gridBg.height);

			if(prevGridBg.visible) diffY = Math.max(diffY, -prevGridBg.height);
			else diffY = Math.max(diffY, 0);

			var noteData:Int = Math.floor(diffX / GRID_SIZE);
			dummyArrow.visible = !selectionBox.visible;
			dummyArrow.x = gridBg.x + noteData * GRID_SIZE;
			if(SHOW_EVENT_COLUMN)
				noteData--;

			dummyArrow.y = gridBg.y + diffY;
			if(pendingNote != null && FlxG.mouse.pressed &&
				(Math.abs(FlxG.mouse.x - pendingMouseX) >= DRAG_THRESHOLD || Math.abs(FlxG.mouse.y - pendingMouseY) >= DRAG_THRESHOLD))
			{
				if(!pendingWasSelected && !pendingDuplicate && selectedNotes.length > 1)
				{
					var sel = selectedNotes.copy();
					resetSelectedNotes();
					selectedNotes.push(pendingNote);
					addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
					onSelectNote();
				}

				if(pendingDuplicate) duplicateSelectedNotes();
				moveSelectedNotes(noteData, dummyArrow.y);
				pendingNote = null;
			}

			if(isMovingNotes)
			{
				var scrollMargin:Float = 150;
				var maxScrollSpeed:Float = 1200;
				
				if(FlxG.mouse.screenY < scrollMargin)
				{
					var distance:Float = (scrollMargin - FlxG.mouse.screenY) / scrollMargin;
					var scrollSpeed:Float = maxScrollSpeed * distance * elapsed;
					FlxG.sound.music.time = Math.max(0, FlxG.sound.music.time - scrollSpeed);
					Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;
					updateScrollY();
				}
				else if(FlxG.mouse.screenY > FlxG.height - scrollMargin)
				{
					var distance:Float = (FlxG.mouse.screenY - (FlxG.height - scrollMargin)) / scrollMargin;
					var scrollSpeed:Float = maxScrollSpeed * distance * elapsed;
					FlxG.sound.music.time = Math.min(FlxG.sound.music.length - 1, FlxG.sound.music.time + scrollSpeed);
					Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;
					updateScrollY();
				}
			}

			if(isMovingNotes)
			{
				// Move note data
				var nData:Int = Std.int(Math.max(0, noteData));
				if(movingNotesLastData != nData)
				{
					var isFirst:Bool = true;
					var movingNotesMinData:Int = 0;
					var movingNotesMaxData:Int = 0;
					for (note in selectedNotes)
					{
						if(note == null || note.isEvent) continue;
	
						var data:Int = note.songData[1];
						if(isFirst || data < movingNotesMinData) movingNotesMinData = data;
						if(data > movingNotesMaxData) movingNotesMaxData = data;
						isFirst = false;
					}

					var diff:Int = nData - movingNotesLastData;
					var maxn:Int = (GRID_PLAYERS * GRID_COLUMNS_PER_PLAYER) - 1;
					movingNotesMinData += diff;
					movingNotesMaxData += diff;
					if(movingNotesMinData < 0)
						diff -= movingNotesMinData;
					else if(movingNotesMaxData > maxn)
						diff -= movingNotesMaxData - maxn;

					for (note in movingNotes)
					{
						if(note == null || note.isEvent) continue;

						note.changeNoteData(note.songData[1] + diff);
						positionNoteXByData(note);
					}
					
					var highlightIndex:Int = 0;
					for (note in selectedNotes)
					{
						if(note == null) continue;
						if(highlightIndex < noteHighlights.length)
						{
							var highlight = noteHighlights.members[highlightIndex];
							if(highlight != null)
								highlight.x = note.x;
							highlightIndex++;
						}
					}
					
					if(selectedNotes.length == 1 && !selectedNotes[0].isEvent)
						updateSustainHighlights(selectedNotes[0]);
					
					FlxG.sound.play(Paths.sound('chartingSounds/noteLay'));
				}
				movingNotesLastData = nData;

				// Move note strum time
				if(dummyArrow.y != movingNotesLastY)
				{
					var diff:Float = dummyArrow.y - movingNotesLastY;
					for (note in movingNotes)
					{
						if(note == null) continue;

						note.chartY += diff;
						var row:Float = note.chartY / (GRID_SIZE * curZoom);
						var curSecRow:Int = 0;
						while(curSecRow + 1 < cachedSectionRow.length && cachedSectionRow[curSecRow] <= row)
						{
							curSecRow++;
						}

						note.setStrumTime(Math.max(-5000, note.strumTime + (diff * cachedSectionCrochets[curSecRow] / 4) / (GRID_SIZE * curZoom)));
						positionNoteYOnTime(note, curSecRow);
						if(note.isEvent) cast (note, EventMetaNote).updateEventText();
					}
					
					var highlightIndex:Int = 0;
					for (note in selectedNotes)
					{
						if(note == null) continue;
						if(highlightIndex < noteHighlights.length)
						{
							var highlight = noteHighlights.members[highlightIndex];
							if(highlight != null)
								highlight.y = note.chartY;
							highlightIndex++;
						}
					}
					
					if(selectedNotes.length == 1 && !selectedNotes[0].isEvent)
						updateSustainHighlights(selectedNotes[0]);
					
					FlxG.sound.play(Paths.sound('chartingSounds/noteLay'));
					movingNotesLastY = dummyArrow.y;
				}
			}
			else if((FlxG.mouse.justPressed || FlxG.mouse.justPressedRight) && !ignoreClickForThisFrame)
			{
				if(FlxG.mouse.x >= gridBg.x && FlxG.mouse.x < gridBg.x + gridBg.width)
				{
					var closeNotes:Array<MetaNote> = curRenderedNotes.members.filter(function(note:MetaNote)
					{
						if(note == null) return false;

						var chartY:Float = FlxG.mouse.y - note.chartY;
						return ((note.isEvent && noteData < 0) || (!note.isEvent && note.songData[1] == noteData)) && chartY >= 0 && chartY < GRID_SIZE;
					});
					closeNotes.sort(function(a:MetaNote, b:MetaNote) return Math.abs(a.chartY - FlxG.mouse.y) < Math.abs(b.chartY - FlxG.mouse.y) ? -1 : 1);

					var closest = closeNotes[0];
					if(closest != null && (!closest.isEvent || !lockedEvents))
					{
						if(FlxG.mouse.justPressedRight)
						{
						FlxG.sound.play(Paths.sound('chartingSounds/noteErase'));
						var kind:String = !closest.isEvent ? 'note' : 'event';
						trace('Removed $kind at time: ${closest.strumTime}');
						if(!closest.isEvent)
							notes.remove(closest);
						else
							events.remove(cast (closest, EventMetaNote));

						selectedNotes.remove(closest);
						curRenderedNotes.remove(closest, true);
						noteHighlights.clear();
						addUndoAction(DELETE_NOTE, !closest.isEvent ? {notes: [closest]} : {events: [closest]});
						forceDataUpdate = true;
						softReloadNotes();
					}
						else if(FlxG.mouse.justPressed)
						{
							pendingNote = closest;
							pendingWasSelected = selectedNotes.contains(closest);
							pendingDuplicate = FlxG.keys.pressed.SHIFT;
							pendingMouseX = FlxG.mouse.x;
							pendingMouseY = FlxG.mouse.y;
							
							if(!pendingWasSelected)
							{
								var sel = selectedNotes.copy();
								selectedNotes.push(closest);
								addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
								onSelectNote();
							}
							forceDataUpdate = true;
							trace('Notes selected: ' + selectedNotes.length);
						}
					}
					else if(!holdingAlt && FlxG.mouse.justPressed && FlxG.mouse.y >= gridBg.y && FlxG.mouse.y < gridBg.y + gridBg.height)
					{
						var strumTime:Float = (diffY / GRID_SIZE * Conductor.stepCrochet / curZoom) + cachedSectionTimes[curSec];
						if(noteData >= 0)
						{
							FlxG.sound.play(Paths.sound('chartingSounds/noteLay'));
							trace('Added note at time: $strumTime');
							var didAdd:Bool = false;

							var noteSetupData:Array<Dynamic> = [strumTime, noteData, 0];
							var typeSelected:String = noteTypes[noteTypeDropDown.selectedIndex].trim();
							if(typeSelected != null && typeSelected.length > 0)
								noteSetupData.push(typeSelected);

							var noteAdded:MetaNote = createNote(noteSetupData);
							for (num in sectionFirstNoteID...notes.length)
							{
								var note = notes[num];
								if(note.strumTime >= strumTime)
								{
									notes.insert(num, noteAdded);
									didAdd = true;
									break;
								}
							}
							if(!didAdd) notes.push(noteAdded);

							if(!holdingAlt)
								resetSelectedNotes();

							selectedNotes.push(noteAdded);
							addUndoAction(ADD_NOTE, {notes: [noteAdded]});
							onSelectNote();
							softReloadNotes();
							stretchingNote = noteAdded;
						}
						else if(!lockedEvents)
						{
							FlxG.sound.play(Paths.sound('chartingSounds/noteLay'));
							trace('Added event at time: $strumTime');
							var didAdd:Bool = false;

							var _useEase:Bool = (easeDropDown != null && easeDropDown.visible);
							var _val2Create:String = _useEase ? (valueInputTexts[2].text.trim().length > 0 ? valueInputTexts[1].text + ', ' + valueInputTexts[2].text.trim() : valueInputTexts[1].text) : valueInputTexts[1].text;
							var _evData:Array<Dynamic> = [eventsList[Std.int(Math.max(eventDropDown.selectedIndex, 0))][0], valueInputTexts[0].text, _val2Create, _useEase ? '' : valueInputTexts[2].text];
							for(_i in 3...valueInputTexts.length) _evData.push(valueInputTexts[_i].text);
							var eventAdded:EventMetaNote = createEvent([strumTime, [_evData]]);
							for (num in sectionFirstEventID...events.length)
							{
								var event = events[num];
								if(event.strumTime >= strumTime)
								{
									events.insert(num, eventAdded);
									didAdd = true;
									break;
								}
							}
							if(!didAdd) events.push(eventAdded);

							if(!holdingAlt)
								resetSelectedNotes();

							selectedNotes.push(eventAdded);
							addUndoAction(ADD_NOTE, {events: [eventAdded]});
							onSelectNote();
							softReloadNotes();
						}
						ignoreClickForThisFrame = true;
					}
				}
			}
		}
		else if(!ignoreClickForThisFrame)
		{
			if(FlxG.mouse.justPressed)
				resetSelectedNotes();

			dummyArrow.visible = false;
		}
		ignoreClickForThisFrame = false;

		if(mainBox.selectedName != lastMainBoxTab || mainBox.isMinimized != lastMainBoxMinimized)
		{
			lastMainBoxTab = mainBox.selectedName;
			lastMainBoxMinimized = mainBox.isMinimized;
			
			if(!mainBox.isMinimized && lastMainBoxTab != 'Events' && lastMainBoxTab != null)
			{
				mainBox.resize(300, mainBoxOriginalHeight, true);
				if(!infoBoxMoved) infoBox.setPosition(infoBoxPosition.x, mainBox.y + mainBoxOriginalHeight);
			}
			else if(!mainBox.isMinimized && lastMainBoxTab == 'Events')
			{
				if(selectedNotes.length > 0 && selectedNotes[0].isEvent)
					updateSelectedEventText();
				else
				{
					var currentEventName:String = (eventDropDown != null && eventDropDown.selectedIndex >= 0 && eventDropDown.selectedIndex < eventsList.length) ? eventsList[eventDropDown.selectedIndex][0] : '';
					updateEventSpecialUI(currentEventName);
					updateEventDescriptionHeight();
				}
			}
		}

		if(curSec != _lastToySec){
			_lastToySec = curSec;
			if(toysEnabled && FlxG.sound.music != null && FlxG.sound.music.playing)
				danceToys();
		}

		if(Conductor.songPosition != lastTime || forceDataUpdate)
		{
			var curTime:String = FlxStringUtil.formatTime(Conductor.songPosition / 1000, true);
			var songLength:String = (FlxG.sound.music != null) ? FlxStringUtil.formatTime(FlxG.sound.music.length / 1000, true) : '???';
			var str:String =  '$curTime / $songLength' +
							  '\n\nSection: $curSec' +
							  '\nBeat: $curBeat' +
							  '\nStep: $curStep' +
							  '\n\nSelected: ${selectedNotes.length}';

			if(str != infoText.text)
			{
				infoText.text = str;
				if(infoText.autoSize) infoText.autoSize = false;
			}

			var vortexPlaying:Bool = (vortexEnabled && FlxG.sound.music != null && FlxG.sound.music.playing);
			var canPlayHitSound:Bool = (FlxG.sound.music != null && FlxG.sound.music.playing && lastTime < Conductor.songPosition);
			var hitSoundPlayer:Bool = (hitsoundPlayerSlider.value > 0);
			var hitSoundOpp:Bool = (hitsoundOpponentSlider.value > 0);
			for (note in curRenderedNotes)
			{
				if(note == null || note.isEvent) continue;

				note.alpha = (note.strumTime >= Conductor.songPosition) ? 1 : 0.6;
				if(Conductor.songPosition > note.strumTime && lastTime <= note.strumTime)
				{
					if(toysEnabled)
				{
					var noteData:Int = Std.int(note.songData[1]) % 4;
					var animName:String = ['LEFT', 'DOWN', 'UP', 'RIGHT'][noteData];
					var sustainLength:Float = note.sustainLength;
					var noteColor:FlxColor = [0xFFC04B99, 0xFF01FFFF, 0xFF12FA06, 0xFFFA3941][noteData];
					
					var section:SwagSection = PlayState.SONG.notes[curSec];
					var isGfSection:Bool = (section != null && section.gfSection == true);
					var isGfNote:Bool = note.gfNote;
					
					if(note.mustPress)
					{
						if(isGfNote || isGfSection)
						{
							gfToy.performPose(animName, sustainLength, noteColor);
						}
						else
						{
							bfToy.performPose(animName, sustainLength, noteColor);
						}
					}
					else
					{
						if(isGfSection)
						{
							gfToy.performPose(animName, sustainLength, noteColor);
						}
						else
						{
							opponentToy.performPose(animName, sustainLength, noteColor);
						}
					}
				}
					
					if(canPlayHitSound)
					{
						if(hitSoundPlayer && note.mustPress)
						{
							FlxG.sound.play(Paths.sound('chartingSounds/hitNotePlayer'), sliderVolume(hitsoundPlayerSlider));
							hitSoundPlayer = false;
						}
						else if(hitSoundOpp && !note.mustPress)
						{
							FlxG.sound.play(Paths.sound('chartingSounds/hitNoteOpponent'), sliderVolume(hitsoundOpponentSlider));
							hitSoundOpp = false;
						}
					}

					if(vortexPlaying)
					{
						var strumNote:StrumNote = strumLineNotes.members[note.songData[1]];
						if(strumNote != null)
						{
							strumNote.playAnim('confirm', true);
							strumNote.resetAnim = Math.max(Conductor.stepCrochet * 1.25, note.sustainLength) / 1000 / playbackRate;
						}
					}
				}
			}
			forceDataUpdate = false;
			
			// moved from beatHit()
			if(metronomeSlider.value > 0 && lastBeatHit != curBeat)
				FlxG.sound.play(Paths.sound('Metronome_Tick'), sliderVolume(metronomeSlider));

			if(lastBeatHit != curBeat && FlxG.sound.music.playing)
			{
				for(icon in icons)
				{
					if(icon != null)
					{
						icon.scale.set(0.375, 0.375);
						icon.updateHitbox();
					}
				}
			}

			lastBeatHit = curBeat;
		}

		if(selectedNotes.length > 0)
		{
			noteSelectionSine += elapsed;
			var sineValue:Float = 0.75 + Math.cos(Math.PI * noteSelectionSine * (isMovingNotes ? 8 : 2)) / 4;
			//trace(sineValue);

			var qPress = FlxG.keys.justPressed.Q;
			var ePress = FlxG.keys.justPressed.E;
			var addSus = (FlxG.keys.pressed.SHIFT ? 4 : 1) * (Conductor.stepCrochet / 2);
			if(qPress) addSus *= -1;

			if(qPress != ePress && selectedNotes.length != 1)
			{
				susLengthStepper.value = susLengthStepper.value + addSus;
				susLengthLastVal = susLengthStepper.value;
			}

			var noteSec:Int = 0;
			for (note in selectedNotes)
			{
				if(note == null || !note.exists) continue;

				if(!note.isEvent)
				{
					if(qPress != ePress)
					{
						while(cachedSectionCrochets.length > noteSec + 1 && cachedSectionTimes[noteSec + 1] <= note.strumTime)
							noteSec++;

						note.setSustainLength(note.sustainLength + addSus, cachedSectionCrochets[noteSec] / 4, curZoom);
						if(selectedNotes.length == 1)
						{
							susLengthStepper.value = note.sustainLength;
							susLengthLastVal = susLengthStepper.value;
							updateSustainHighlights(note);
						}
					}
					note.animation.update(elapsed); //let selected notes be animated for better visibility
				}
				note.colorTransform.redMultiplier = note.colorTransform.greenMultiplier = note.colorTransform.blueMultiplier = sineValue;
			}
		}
		else
		{
			noteSelectionSine = 0;
			sustainHighlights.clear();
		}

		outputTxt.alpha = outputAlpha;
		outputTxt.visible = (outputAlpha > 0);
		FlxG.camera.scroll.y = scrollY;
		gridCurrentX = FlxMath.lerp(gridCurrentX, gridTargetX, FlxMath.bound(elapsed * 12, 0, 1));
		var gridOffsetX:Float = gridCurrentX;
		gridBg.x = (FlxG.width - gridBg.width) / 2 + gridOffsetX;
		prevGridBg.x = nextGridBg.x = gridBg.x;
		updateMiniChartPosition();
		updateToyHitboxes();

		updateIconsScale(elapsed);
		
		if(_openingSubState || subState != null)
		{
			customCursor.visible = false;
			FlxG.mouse.visible = true;
			lastFocus = PsychUIInputText.focusOn;
			return;
		}

		var showCustomCursor:Bool = false;
		var isOverGrid:Bool = false;
		var isOverMiniChart:Bool = FlxG.mouse.overlaps(miniChartBg);
		
		if(mouseOverGrid()){
			isOverGrid = true;
			showCustomCursor = true;
		}
		
		if(isHoveringNote || FlxG.mouse.overlaps(mainBox.bg) || FlxG.mouse.overlaps(infoBox.bg) || isOverMiniChart || mouseOverUpperMenu())
		{
			showCustomCursor = true;
			isOverGrid = false;
		}
		
		var isOverClickable:Bool = isHoveringNote || FlxG.mouse.overlaps(mainBox.bg) || FlxG.mouse.overlaps(infoBox.bg) || isOverToy || isOverMiniChart || mouseOverUpperMenu();
		
		if(showCustomCursor || isOverClickable)
		{
			if(isMovingNotes || isDraggingMiniChart || (FlxG.mouse.pressed && isOverClickable))
			{
				setCursorKind(CURSOR_GRABBING);
				isGrabbingCursor = true;
				cursorGrabTimer = 0.1;
			}
			else
			{
				if(isGrabbingCursor)
				{
					cursorGrabTimer -= elapsed;
					if(cursorGrabTimer <= 0) isGrabbingCursor = false;
				}

				if(isGrabbingCursor)
					setCursorKind(CURSOR_GRABBING);
				else if(isOverGrid && !isHoveringNote && !isOverClickable)
					setCursorKind(CURSOR_CELL);
				else
					setCursorKind(CURSOR_POINTER);
			}
			
			FlxG.mouse.visible = false;
			customCursor.visible = true;
			hideCursorFrames = 0;
		}
		else
		{
			if(customCursor.visible)
			{
				customCursor.visible = false;
				FlxG.mouse.visible = false;
				hideCursorFrames = 2;
			}
			else if(hideCursorFrames > 0)
			{
				hideCursorFrames--;
				FlxG.mouse.visible = false;
			}
			else
			{
				FlxG.mouse.visible = true;
			}
		}
		
		if(customCursor.visible)
			customCursor.setPosition(FlxG.mouse.screenX, FlxG.mouse.screenY);

		lastFocus = PsychUIInputText.focusOn;
	}

	function moveSelectedNotes(noteData:Int = 0, lastY:Float) //This turns selected notes into moving notes
	{
		var originalNotes:Array<MetaNote> = [];
		var originalEvents:Array<EventMetaNote> = [];
		var movedNotes:Array<MetaNote> = [];
		var movedEvents:Array<EventMetaNote> = [];
		for (note in selectedNotes)
		{
			if(note == null) continue;

			if(!note.isEvent)
			{
				notes.remove(note);
				var secNum:Int = 0;
				for (i in 1...cachedSectionTimes.length)
				{
					if(cachedSectionTimes[i] > note.strumTime) break;
					secNum++;
				}
				originalNotes.push(note);
				var mov:MetaNote = createNote(makeNoteDataCopy(note.songData, false), secNum);
				movingNotes.add(mov);
				movedNotes.push(mov);
			}
			else
			{
				events.remove(cast (note, EventMetaNote));
				originalEvents.push(cast (note, EventMetaNote));
				var mov:EventMetaNote = createEvent(makeNoteDataCopy(note.songData, true));
				movingNotes.add(mov);
				movedEvents.push(mov);
			}
		}
		selectedNotes = movingNotes.members.copy();
		isMovingNotes = true;
		movingNotesLastY = lastY;
		movingNotesLastData = noteData;
		movingNotes.sort(cast PlayState.sortByTime);
		addUndoAction(MOVE_NOTE, {originalNotes: originalNotes, originalEvents: originalEvents, movedNotes: movedNotes, movedEvents: movedEvents});
		softReloadNotes();
	}

	function stopMovingNotes() //This turns moving notes into saved notes
	{
		var pushedNotes:Array<MetaNote> = [];
		var pushedEvents:Array<EventMetaNote> = [];
		movingNotes.forEachAlive(function(note:MetaNote)
		{
			if(!note.isEvent)
			{
				notes.push(note);
				pushedNotes.push(note);
			}
			else
			{
				events.push(cast (note, EventMetaNote));
				pushedEvents.push(cast (note, EventMetaNote));
			}
		});
		notes.sort(PlayState.sortByTime);
		events.sort(PlayState.sortByTime);
		movingNotes.clear();
		isMovingNotes = false;
		softReloadNotes();
	}

	function makeNoteDataCopy(originalData:Array<Dynamic>, isEvent:Bool)
	{
		var dataCopy:Array<Dynamic> = originalData.copy();
		if(isEvent)
		{
			var eventGrp:Array<Array<Dynamic>> = cast dataCopy[1].copy();
			for (num => subEvent in eventGrp)
				eventGrp[num] = subEvent.copy();

			dataCopy[1] = eventGrp;
		}
		return dataCopy;
	}

	function updateScrollY()
	{
		var secStartTime:Null<Float> = cast cachedSectionTimes[curSec];
		var secCrochet:Null<Float> = cast cachedSectionCrochets[curSec];
		var secRows:Null<Float> = cast cachedSectionRow[curSec];
		if(secStartTime == null || secCrochet == null || secRows == null) return;

		scrollY = (((Conductor.songPosition - secStartTime) / secCrochet * GRID_SIZE * 4) + (secRows * GRID_SIZE)) * curZoom - FlxG.height/2;
	}

	var miniChartRedrawTimer:Float = 0;
	var miniChartHandleTall:Bool = false;

	function rebuildMiniChartHandle(tall:Bool)
	{
		if(miniChartHandleTall == tall && miniChartHandle.height > 0) return;
		miniChartHandleTall = tall;

		var wid:Int = Std.int(miniChart.width);
		var hei:Int = tall ? Std.int(miniChart.height) : 20;
		var border:Int = tall ? 1 : 2;

		miniChartHandle.makeGraphic(wid, hei, 0x00FFFFFF, true);
		miniChartHandle.pixels.fillRect(new Rectangle(0, 0, wid, hei), 0x80FF8800);
		miniChartHandle.pixels.fillRect(new Rectangle(0, 0, wid, border), 0xFFFFAA44);
		miniChartHandle.pixels.fillRect(new Rectangle(0, hei - border, wid, border), 0xFFFFAA44);
		miniChartHandle.pixels.fillRect(new Rectangle(0, 0, border, hei), 0xFFFFAA44);
		miniChartHandle.pixels.fillRect(new Rectangle(wid - border, 0, border, hei), 0xFFFFAA44);
	}

	function updateMiniChart()
	{
		if(miniChart == null || !miniChart.exists) return;

		if(FlxG.sound.music == null)
		{
			rebuildMiniChartHandle(true);
			miniChartHandle.y = miniChartBg.y;
			return;
		}
		rebuildMiniChartHandle(false);

		miniChartRedrawTimer -= FlxG.elapsed;
		if(miniChartRedrawTimer > 0) return;
		miniChartRedrawTimer = 0.1;

		miniChart.pixels.fillRect(new Rectangle(0, 0, miniChart.width, miniChart.height), 0x00FFFFFF);

		var songLength:Float = FlxG.sound.music.length;
		if(songLength <= 0) return;

		var chartHeight:Float = miniChart.height - 2;
		var chartWidth:Float = miniChart.width;
		var columnWidth:Float = chartWidth / (GRID_PLAYERS * GRID_COLUMNS_PER_PLAYER);

		for(note in notes)
		{
			if(note == null || note.isEvent) continue;

			var noteProgress:Float = note.strumTime / songLength;
			if(noteProgress < 0 || noteProgress > 1) continue;

			var noteY:Float = noteProgress * chartHeight;
			var rawColumn:Int = Std.int(note.songData[1]);
			var noteX:Float = rawColumn * columnWidth;

			var noteColor:Int = selectedNotes.contains(note) ? 0xFFFFFF00 : [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F][rawColumn % 4];
			miniChart.pixels.fillRect(new Rectangle(noteX, noteY, columnWidth, 2), noteColor);
		}
	}

	function updateSelectionBox()
	{
		var diffX:Float = FlxG.mouse.screenX - selectionStart.x;
		var diffY:Float = FlxG.mouse.screenY - selectionStart.y;
		selectionBox.setPosition(selectionStart.x, selectionStart.y);

		if(diffX < 0) //Fixes negative X scale
		{
			diffX = Math.abs(diffX);
			selectionBox.x -= diffX;
		}
		if(diffY < 0) //Fixes negative Y scale
		{
			diffY = Math.abs(diffY);
			selectionBox.y -= diffY;
		}
		selectionBox.scale.set(diffX, diffY);
		selectionBox.updateHitbox();
	}

	function showOutput(message:String, isError:Bool = false)
	{
		trace(message);
		outputTxt.text = message;
		outputTxt.y = FlxG.height - outputTxt.height - 30;
		outputAlpha = 4;
		if(isError)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
			outputTxt.color = FlxColor.RED;
		}
		else
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			outputTxt.color = FlxColor.WHITE;
		}
	}

	function deselectNote(note:MetaNote)
	{
		if(note == null || !selectedNotes.contains(note)) return;

		var sel = selectedNotes.copy();
		note.colorTransform.redMultiplier = note.colorTransform.greenMultiplier = note.colorTransform.blueMultiplier = 1;
		if(note.animation.curAnim != null) note.animation.curAnim.curFrame = 0;

		selectedNotes.remove(note);
		onSelectNote();
		addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
		forceDataUpdate = true;
	}

	function duplicateSelectedNotes()
	{
		var duplicatedNotes:Array<MetaNote> = [];
		var duplicatedEvents:Array<EventMetaNote> = [];
		for (note in selectedNotes)
		{
			if(note == null) continue;

			if(!note.isEvent)
			{
				var noteCopy:Array<Dynamic> = makeNoteDataCopy(note.songData, false);
				var newNote:MetaNote = createNote(noteCopy, curSec);
				notes.push(newNote);
				duplicatedNotes.push(newNote);
			}
			else
			{
				var eventCopy:Array<Dynamic> = makeNoteDataCopy(note.songData, true);
				var newEvent:EventMetaNote = createEvent(eventCopy);
				events.push(newEvent);
				duplicatedEvents.push(newEvent);
			}
		}
		notes.sort(PlayState.sortByTime);
		events.sort(PlayState.sortByTime);
		resetSelectedNotes();
		selectedNotes = duplicatedNotes.concat(cast duplicatedEvents);
		addUndoAction(ADD_NOTE, {notes: duplicatedNotes, events: duplicatedEvents});
	}

	function resetSelectedNotes()
	{
		for (note in selectedNotes)
		{
			if(note == null || !note.exists) continue;

			note.colorTransform.redMultiplier = note.colorTransform.greenMultiplier = note.colorTransform.blueMultiplier = 1;
			if(note.animation.curAnim != null) note.animation.curAnim.curFrame = 0;
		}
		selectedNotes = [];
		noteHighlights.clear();
		sustainHighlights.clear();
		onSelectNote();
		forceDataUpdate = true;
	}

	function onSelectNote()
	{
		noteHighlights.clear();
		sustainHighlights.clear();
		
		for (note in selectedNotes)
		{
			if(note == null) continue;
			
			var highlight:FlxSprite = new FlxSprite(note.x, note.chartY).makeGraphic(GRID_SIZE, GRID_SIZE, FlxColor.GREEN);
			highlight.alpha = 0.3;
			highlight.scrollFactor.x = 0;
			noteHighlights.add(highlight);
		}

		if(selectedNotes.length == 1 && !selectedNotes[0].isEvent)
			updateSustainHighlights(selectedNotes[0]);
		
		if(selectedNotes.length == 1)
		{
			var note:MetaNote = selectedNotes[0];
			strumTimeStepper.value = note.strumTime;
			if(!note.isEvent)
			{
				if(!note.isEvent)
				{
					susLengthLastVal = susLengthStepper.value = note.sustainLength;
					var curTypeIndex:Int = noteTypes.indexOf(note.noteType);
					noteTypeDropDown.selectedLabel = (curTypeIndex >= 0) ? noteTypeDropDown.list[curTypeIndex] : '';
					
					altAnimInputText.visible = altAnimDescText.visible = altAnimLabelText.visible = (note.noteType == 'Alt Animation');
					if(note.noteType == 'Alt Animation')
						altAnimInputText.text = note.animSuffix;
				}
				else
				{
					susLengthLastVal = susLengthStepper.value = 0;
					noteTypeDropDown.selectedLabel = '';
					altAnimInputText.visible = altAnimDescText.visible = altAnimLabelText.visible = false;
				}
			}
			else
			{
				var eventNote:EventMetaNote = cast (selectedNotes[0], EventMetaNote);
				updateSelectedEventText();
				altAnimInputText.visible = altAnimDescText.visible = altAnimLabelText.visible = false;
			}
		}
		else if(selectedNotes.length > 1)
		{
			susLengthStepper.min = -susLengthStepper.max;
			susLengthLastVal = susLengthStepper.value = 0;
			strumTimeStepper.value = selectedNotes[0].strumTime;
			noteTypeDropDown.selectedLabel = '';
			eventDropDown.selectedLabel = '';
			for(inp in valueInputTexts) inp.text = '';
			altAnimInputText.visible = altAnimDescText.visible = altAnimLabelText.visible = false;
		}
		forceDataUpdate = true;
	}

	function updateSustainHighlights(note:MetaNote)
	{
		sustainHighlights.clear();
		
		if(note == null || note.isEvent || note.sustainLength <= 0) return;
		
		var noteSec:Int = 0;
		for (i in 1...cachedSectionTimes.length)
		{
			if(cachedSectionTimes[i] > note.strumTime) break;
			noteSec++;
		}
		
		var stepCrochet:Float = cachedSectionCrochets[noteSec] / 4;
		var numSquares:Int = Math.round(note.sustainLength / stepCrochet * curZoom) - 1;
		
		if(numSquares < 1) return;
		
		for(i in 0...numSquares)
		{
			var highlight:FlxSprite = new FlxSprite(note.x, note.chartY + GRID_SIZE + (i * GRID_SIZE)).makeGraphic(GRID_SIZE, GRID_SIZE, FlxColor.GREEN);
			highlight.alpha = 0.3;
			highlight.scrollFactor.x = 0;
			sustainHighlights.add(highlight);
		}
	}

	function updateSelectedEventText()
	{
		if(selectedNotes.length == 1 && selectedNotes[0].isEvent)
		{
			var eventNote:EventMetaNote = cast (selectedNotes[0], EventMetaNote);
			curEventSelected = Std.int(FlxMath.bound(curEventSelected, 0, eventNote.events.length - 1));
			selectedEventText.text = 'Selected Event: ${curEventSelected + 1} / ${eventNote.events.length}';
			selectedEventText.visible = true;
			
			var myEvent:Array<String> = eventNote.events[curEventSelected];
			if(myEvent != null)
			{
				var eventName:String = (myEvent[0] != null) ? myEvent[0] : '';
				for (num => event in eventsList)
				{
					if(event[0] == eventName)
					{
						eventDropDown.selectedIndex = num;
						if(eventDescriptionText != null)
							eventDescriptionText.text = event[1];
						break;
					}
				}
				valueInputTexts[0].text = (myEvent[1] != null) ? myEvent[1] : '';
				if(eventName == 'Set Cam Zoom' || eventName == 'Target Camera' || eventName == 'Target Follow Pos' || eventName == '(STEPS) Set Cam Zoom' || eventName == '(STEPS) Target Camera' || eventName == '(STEPS) Target Follow Pos')
				{
					var rawVal2:String = (myEvent[2] != null) ? myEvent[2] : '';
					var parts:Array<String> = rawVal2.split(',');
					var _seconds:String = parts[0].trim();
					var _ease:String = parts.length > 1 ? parts[1].trim() : '';
					if(_seconds.length == 0 && _ease.length > 0)
					{
						myEvent[2] = _ease;
						rawVal2 = _ease;
					}
					else if(_seconds.length > 0 && _ease.length > 0)
					{
						myEvent[2] = _seconds + ', ' + _ease;
					}
					valueInputTexts[1].text = _seconds;
					valueInputTexts[2].text = _ease;
				}
				else
				{
					for(i in 1...valueInputTexts.length)
						valueInputTexts[i].text = (myEvent[i + 1] != null) ? myEvent[i + 1] : '';
				}
				updateEventSpecialUI(eventName);
				updateEventDescriptionHeight();
				_syncCustomUIFromValues();
			}
		}
		else selectedEventText.visible = false;
	}

	function createGrids()
	{
		var destroyed:Bool = false;
		var stripes:Array<Int> = null;
		if(prevGridBg != null)
		{
			stripes = prevGridBg.stripes;
			remove(prevGridBg);
			remove(gridBg);
			remove(nextGridBg);
			prevGridBg = FlxDestroyUtil.destroy(prevGridBg);
			gridBg = FlxDestroyUtil.destroy(gridBg);
			nextGridBg = FlxDestroyUtil.destroy(nextGridBg);
			destroyed = true;
		}

		var columnCount:Int = (GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS) + (SHOW_EVENT_COLUMN ? 1 : 0);
		gridBg = new ChartingGridSprite(columnCount, gridColors[0], gridColors[1]);
		gridBg.screenCenter(X);

		prevGridBg = new ChartingGridSprite(columnCount, gridColorsOther[0], gridColorsOther[1]);
		nextGridBg = new ChartingGridSprite(columnCount, gridColorsOther[0], gridColorsOther[1]);
		prevGridBg.x = nextGridBg.x = gridBg.x;
		prevGridBg.stripes = nextGridBg.stripes = gridBg.stripes = stripes;
		
		if(destroyed)
		{
			insert(getFirstNull(), prevGridBg);
			insert(getFirstNull(), nextGridBg);
			insert(getFirstNull(), gridBg);
			loadSection();
		}
		else
		{
			add(prevGridBg);
			add(nextGridBg);
			add(gridBg);
		}
	}

	var cachedSectionRow:Array<Int>;
	var cachedSectionTimes:Array<Float>;
	var cachedSectionCrochets:Array<Float>;
	var cachedSectionBPMs:Array<Float>;
	function loadChart(song:SwagSong)
	{
		PlayState.SONG = song;
		StageData.loadDirectory(PlayState.SONG);
		Conductor.bpm = PlayState.SONG.bpm;

		strumlineConfigs = [];
		if(PlayState.SONG.extraStrumlines != null)
		{
			for(data in PlayState.SONG.extraStrumlines)
				strumlineConfigs.push(data);
		}
	}

	function getSongFolderFromPath(path:String):String
	{
		if(path == null) return '';

		var parts:Array<String> = path.replace('\\', '/').split('/');
		parts.pop();

		var last:String = (parts.length > 0) ? parts[parts.length - 1] : '';
		if(last.toLowerCase() == 'charts' || last.toLowerCase() == 'chart')
		{
			parts.pop();
			last = (parts.length > 0) ? parts[parts.length - 1] : '';
		}
		return last;
	}

	function loadMusic(?killAudio:Bool = false)
	{
		setSongPlaying(false);
		var time:Float = Conductor.songPosition;

				if(killAudio)
		{
			var sndsToKill:Array<String> = [];
			var formattedSong = Paths.formatToSongPath(PlayState.SONG.song);
			for (key => snd in Paths.currentTrackedSounds)
			{
				//trace(key, snd);
				if((key.contains('/songs/$formattedSong/') || 
				    key.contains('/data/$formattedSong/song/') || 
				    key.contains('/data/$formattedSong/songs/')) && snd != null)
				{
					sndsToKill.push(key);
					snd.close();
				}
			}

			for (key in sndsToKill)
			{
				Assets.cache.clear(key);
				Paths.currentTrackedSounds.remove(key);
				Paths.localTrackedAssets.remove(key);
			}
		}

		try
		{
			FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song, Difficulty.getFilePath(curDifficultyIndex)), 0);
			FlxG.sound.music.pause();
			FlxG.sound.music.time = time;
			FlxG.sound.music.onComplete = (function() songFinished = true);
		}
		catch(e:Exception)
		{
			FlxG.log.error('Error loading song: $e');
			return;
		}

		@:privateAccess vocals.cleanup(true);
		@:privateAccess opponentVocals.cleanup(true);
		if (PlayState.SONG.needsVoices)
		{
			try
			{
				var playerVocals:Sound = Paths.voices(PlayState.SONG.song, (characterData.vocalsP1 == null || characterData.vocalsP1.length < 1) ? 'Player' : characterData.vocalsP1, Difficulty.getFilePath(curDifficultyIndex));
				vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(PlayState.SONG.song, null, Difficulty.getFilePath(curDifficultyIndex)));
				vocals.volume = 0;
				vocals.play();
				vocals.pause();
				vocals.time = time;
				
				var oppVocals:Sound = Paths.voices(PlayState.SONG.song, (characterData.vocalsP2 == null || characterData.vocalsP2.length < 1) ? 'Opponent' : characterData.vocalsP2, Difficulty.getFilePath(curDifficultyIndex));
				if(oppVocals != null && oppVocals.length > 0)
				{
					opponentVocals.loadEmbedded(oppVocals);
					opponentVocals.volume = 0;
					opponentVocals.play();
					opponentVocals.pause();
					opponentVocals.time = time;
				}
			}
			catch (e:Dynamic) {}
		}

		#if DISCORD_ALLOWED
		#if MODS_ALLOWED
		DiscordClient.loadModRPC();
		#end
		DiscordClient.changePresence('Chart Editor', 'Song: ' + PlayState.SONG.song);
		#end

		updateAudioVolume();
		setPitch();
		_cacheSections();
	}

	function onSongComplete()
	{
		trace('song completed');
		setSongPlaying(false);
		Conductor.songPosition = FlxG.sound.music.time = vocals.time = opponentVocals.time = FlxG.sound.music.length - 1;
		curSec = PlayState.SONG.notes.length - 1;
		forceDataUpdate = true;
	}

	inline function sliderVolume(slider:PsychUISlider):Float
		return FlxMath.bound(slider.value / 100, 0, 1);

	function updateAudioVolume()
	{
		FlxG.sound.music.volume = sliderVolume(instVolumeSlider);
		vocals.volume = sliderVolume(playerVolumeSlider);
		opponentVocals.volume = sliderVolume(opponentVolumeSlider);
		if(instMuteCheckBox.checked) FlxG.sound.music.volume = 0;
		if(playerMuteCheckBox.checked) vocals.volume = 0;
		if(opponentMuteCheckBox.checked) opponentVocals.volume = 0;
	}

	var playbackRate:Float = 1;
	function setPitch(?value:Null<Float>)
	{
		#if FLX_PITCH
		if(value == null) value = playbackRate;
		FlxG.sound.music.pitch = value;
		vocals.pitch = value;
		opponentVocals.pitch = value;
		#end
	}
	
	function scheduleEditorLoop(delay:Float){
		stopEditorLoopFade();
		if(editorMusicMuted)
		{
			editorLoop.volume = 0;
			return;
		}
		editorLoopTimer = new FlxTimer().start(delay, function(_) {
			editorLoopTimer = null;
			editorLoop.fadeIn(1.5, 0, 0.75);
		});
	}

	function stopEditorLoopFade(){
		if(editorLoopTimer != null){
			editorLoopTimer.cancel();
			editorLoopTimer = null;
		}

		if(editorLoop.fadeTween != null){
			editorLoop.fadeTween.cancel();
			editorLoop.fadeTween = null;
		}
	}

	function muteEditorLoop(){
		stopEditorLoopFade();
		editorLoop.volume = 0;
	}

	function setSongPlaying(doPlay:Bool){
		if(FlxG.sound.music == null) return;

		var wasPlaying:Bool = FlxG.sound.music.playing;
		_songPlayIntent = doPlay;

		vocals.time = FlxG.sound.music.time;
		opponentVocals.time = FlxG.sound.music.time;

		if(doPlay){
			FlxG.sound.music.play();
			if(FlxG.sound.music.time < vocals.length) vocals.play(true, FlxG.sound.music.time);
			if(FlxG.sound.music.time < opponentVocals.length) opponentVocals.play(true, FlxG.sound.music.time);
			updateAudioVolume();
			muteEditorLoop();
			setToysAnimated(true);
		}
		else{
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
			if(wasPlaying) scheduleEditorLoop(3.5);
			setToysAnimated(false);
		}

		for (note in strumLineNotes){
			note.alpha = doPlay ? 1 : 0.4;
			if(!doPlay){
				note.playAnim('static');
				note.resetAnim = 0;
			}
		}

		if(!doPlay){
			for(icon in icons){
				if(icon != null){
					icon.scale.set(0.3, 0.3);
					icon.updateHitbox();
				}
			}
		}
	}

	function reloadNotes()
	{
		selectedNotes = [];
		for (note in notes) if(note != null) note.destroy();
		for (event in events) if(event != null) event.destroy();
		notes = [];
		events = [];
		undoActions = [];

		for (secNum => section in PlayState.SONG.notes)
			for (note in section.sectionNotes)
				if(note != null)
					notes.push(createNote(note, secNum));

		for (eventNum => event in PlayState.SONG.events)
			if(event != null && (cachedSectionTimes.length < 1 || event[0] < cachedSectionTimes[cachedSectionTimes.length-1])) //dont spawn events over the time limit
				events.push(createEvent(event));

		notes.sort(PlayState.sortByTime);
		events.sort(PlayState.sortByTime);

		trace('Note count: ${notes.length}');
		trace('Events count: ${events.length}');
		loadSection();
	}

	function createNote(note:Dynamic, ?secNum:Null<Int> = null)
	{
		if(secNum == null) secNum = curSec;
		secNum = Std.int(FlxMath.bound(secNum, 0, PlayState.SONG.notes.length - 1));
		var section = PlayState.SONG.notes[secNum];

		var daStrumTime:Float = note[0];
		var noteColumn:Int = (note[1] != null) ? Std.int(note[1]) : 0;
		var daNoteData:Int = Std.int(noteColumn % GRID_COLUMNS_PER_PLAYER);
		var gottaHitNote:Bool = (noteColumn < GRID_COLUMNS_PER_PLAYER);
		var strumlineIndex:Int = Math.floor(noteColumn / GRID_COLUMNS_PER_PLAYER);

		var swagNote:MetaNote = new MetaNote(daStrumTime, daNoteData, note);
		swagNote.mustPress = gottaHitNote;
		swagNote.setSustainLength(note[2], cachedSectionCrochets[secNum] / 4, curZoom);
		swagNote.gfNote = (section.gfSection && gottaHitNote == section.mustHitSection);
		swagNote.noteType = (note[3] != null && !Std.isOfType(note[3], String)) ? Note.defaultNoteTypes[note[3]] : note[3];
		if(note[3] == 'Alt Animation')
			swagNote.animSuffix = (note[4] != null) ? note[4] : '';
		swagNote.scrollFactor.x = 0;
		var txt:FlxText = swagNote.findNoteTypeText(swagNote.noteType != null ? noteTypes.indexOf(swagNote.noteType) : 0);
		if(txt != null) txt.visible = showNoteTypeLabels;

		swagNote.updateHitbox();
		if(swagNote.width > swagNote.height)
			swagNote.setGraphicSize(GRID_SIZE);
		else
			swagNote.setGraphicSize(0, GRID_SIZE);

		swagNote.updateHitbox();
		swagNote.active = false;
		positionNoteXByData(swagNote);
		positionNoteYOnTime(swagNote, secNum);
		return swagNote;
	}

	function createEvent(event:Dynamic)
	{
		var daStrumTime:Float = event[0];
		var swagEvent:EventMetaNote = new EventMetaNote(daStrumTime, event);
		swagEvent.x = gridBg.x;
		swagEvent.eventText.x = swagEvent.x - swagEvent.eventText.width - 10;
		swagEvent.scrollFactor.x = 0;
		swagEvent.active = false;

		var secNum:Int = 0;
		for (i in 1...cachedSectionTimes.length)
		{
			if(cachedSectionTimes[i] > daStrumTime) break;
			secNum++;
		}
		positionNoteYOnTime(swagEvent, secNum);
		return swagEvent;
	}

	function _cacheSections()
	{
		var time:Float = 0;
		var row:Int = 0;
		cachedSectionRow = [];
		cachedSectionTimes = [];
		cachedSectionCrochets = [];
		cachedSectionBPMs = [];

		if(PlayState.SONG == null)
		{
			cachedSectionRow.push(0);
			cachedSectionTimes.push(0);
			cachedSectionCrochets.push(0);
			cachedSectionBPMs.push(0);
			return;
		}

		var bpm:Float = PlayState.SONG.bpm;
		var reachedLimit:Bool = false;
		for (secNum => section in PlayState.SONG.notes)
		{
			var secs:Null<Float> = cast section.sectionBeats;
			if(secs == null || Math.isNaN(secs) || secs <= 0) section.sectionBeats = 4;
	
			if(section.changeBPM) bpm = section.bpm;
			var beat:Float = Conductor.calculateCrochet(bpm);
			//trace(secBPM, beat);
			
			cachedSectionRow.push(row);
			cachedSectionTimes.push(time);
			cachedSectionCrochets.push(beat);
			cachedSectionBPMs.push(bpm);

			var lastTime:Float = time;
			var rowRound:Int = Math.round(4 * section.sectionBeats);
			row += rowRound;
			time += beat * (rowRound / 4);

			for (note in section.sectionNotes)
			{
				if(secNum > 0 && note[0] < lastTime) note[0] = lastTime;
				else if(secNum < PlayState.SONG.notes.length && note[0] >= time - 0.000001) note[0] = time - 0.000001;
			}

			if(FlxG.sound.music != null && time >= FlxG.sound.music.length)
			{
				var lastSectionNum:Int = PlayState.SONG.notes.length - 1;
				if(secNum < lastSectionNum)
				{
					var hasNotes:Bool = false;
					for(i in (secNum + 1)...PlayState.SONG.notes.length)
					{
						var sec = PlayState.SONG.notes[i];
						if(sec != null && sec.sectionNotes != null && sec.sectionNotes.length > 0)
						{
							hasNotes = true;
							break;
						}
					}
					if(!hasNotes)
					{
						while(PlayState.SONG.notes.length - 1 > secNum)
						{
							PlayState.SONG.notes.pop();
						}
						trace('breaking at section $secNum');
					}
					reachedLimit = true;
					break;
				}
				else if(secNum == lastSectionNum)
				{
					trace('reached limit at section $secNum');
					reachedLimit = true;
				}
			}
		}

		if(FlxG.sound.music != null && !reachedLimit) //Created sections to fill blank space
		{
			var lastSection = PlayState.SONG.notes[PlayState.SONG.notes.length-1];
			var beat:Float = Conductor.calculateCrochet(bpm);
			var sectionBeats:Float = lastSection != null ? lastSection.sectionBeats : 4;
			var rowRound:Int = Math.round(4 * sectionBeats);
			var timeAdd:Float = beat * (rowRound / 4);
			var mustHitSec:Bool = lastSection != null ? lastSection.mustHitSection : true;
			var changeBpmSec:Bool = lastSection != null ? lastSection.changeBPM : false;
			var altAnimSec:Bool = lastSection != null ? lastSection.altAnim : false;
			var gfSec:Bool = lastSection != null ? lastSection.gfSection : false;

			while(!reachedLimit)
			{
				PlayState.SONG.notes.push({
					sectionNotes: [],
					sectionBeats: sectionBeats,
					mustHitSection: mustHitSec,
					bpm: bpm,
					changeBPM: changeBpmSec,
					altAnim: altAnimSec,
					gfSection: gfSec
				});

				cachedSectionRow.push(row);
				cachedSectionTimes.push(time);
				cachedSectionCrochets.push(beat);
				cachedSectionBPMs.push(bpm);

				row += rowRound;
				time += timeAdd;

				if(time >= FlxG.sound.music.length)
				{
					trace('created sections until ${PlayState.SONG.notes.length-1}');
					reachedLimit = true;
				}
			}
		}
		cachedSectionRow.push(row);
		cachedSectionTimes.push(time);
	}

	var showPreviousSection:Bool = true;
	var showNextSection:Bool = true;
	var showNoteTypeLabels:Bool = true;
	var forceDataUpdate:Bool = true;
	function loadSection(?sec:Null<Int> = null)
	{
		if(sec != null) curSec = sec;
		curSec = Std.int(FlxMath.bound(curSec, 0, PlayState.SONG.notes.length-1));
		Conductor.bpm = cachedSectionBPMs[curSec];

		var hei:Float = 0;
		if(curSec > 0)
		{
			prevGridBg.y = cachedSectionRow[curSec-1] * GRID_SIZE * curZoom;
			prevGridBg.rows = 4 * PlayState.SONG.notes[curSec-1].sectionBeats * curZoom;
			prevGridBg.visible = showPreviousSection;
			hei += prevGridBg.height;
			eventLockOverlay.y = prevGridBg.y;
		}
		else prevGridBg.visible = false;

		if(curSec < PlayState.SONG.notes.length - 1)
		{
			nextGridBg.y = cachedSectionRow[curSec+1] * GRID_SIZE * curZoom;
			nextGridBg.rows = 4 * PlayState.SONG.notes[curSec+1].sectionBeats * curZoom;
			nextGridBg.visible = showNextSection;
			hei += nextGridBg.height;
		}
		else nextGridBg.visible = false;

		gridBg.y = cachedSectionRow[curSec] * GRID_SIZE * curZoom;
		gridBg.rows = 4 * PlayState.SONG.notes[curSec].sectionBeats * curZoom;
		hei += gridBg.height;

		if(!prevGridBg.visible) eventLockOverlay.y = gridBg.y;
		eventLockOverlay.scale.y = hei;
		eventLockOverlay.updateHitbox();

		softReloadNotes();
		updateHeads();

		var sec = getCurChartSection();
		if(sec != null)
		{
				var mustHitOptions:Array<String> = (GRID_PLAYERS == 1) ? ['BF', 'GF', 'GF (Player)'] : ['Dad', 'BF', 'GF', 'GF (Player)'];
			if (PlayState.SONG.extraStrumlines != null)
				for (i in 0...PlayState.SONG.extraStrumlines.length)
					mustHitOptions.push('Strumline #${i + 3}');
			mustHitDropDown.list = mustHitOptions;

			if (sec.mustHitTarget != null && mustHitOptions.contains(sec.mustHitTarget))
				mustHitDropDown.selectedLabel = sec.mustHitTarget;
			else if (sec.gfSection == true)
				mustHitDropDown.selectedLabel = 'GF';
			else if (sec.mustHitSection == true)
				mustHitDropDown.selectedLabel = 'BF';
			else
				mustHitDropDown.selectedLabel = (GRID_PLAYERS == 1) ? 'BF' : 'Dad';

			altAnimSectionCheckBox.checked = sec.altAnim;
			changeBpmCheckBox.checked = sec.changeBPM;
			changeBpmStepper.value = Conductor.bpm;
			beatsPerSecStepper.value = sec.sectionBeats;

			strumTimeStepper.step = Conductor.stepCrochet;
			susLengthStepper.step = cachedSectionCrochets[curSec] / 4 / 2;
			susLengthStepper.max = susLengthStepper.step * 128;
			if(selectedNotes.length > 1) susLengthStepper.min = -susLengthStepper.max;
			else susLengthStepper.min = 0;
		}
		prevGridBg.vortexLineEnabled = gridBg.vortexLineEnabled = nextGridBg.vortexLineEnabled = vortexEnabled;
		prevGridBg.vortexLineSpace = gridBg.vortexLineSpace = nextGridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
		updateWaveform();
	}

	function softReloadNotes(onlyCurrent:Bool = false)
	{
		if(!onlyCurrent) behindRenderedNotes.clear();
		curRenderedNotes.clear();

		var minTime:Float = getMinNoteTime(curSec);
		var maxTime:Float = getMaxNoteTime(curSec);
		function curSecFilter(note:MetaNote)
		{
			return (note.strumTime >= minTime && note.strumTime < maxTime);
		}

		var firstNote:Bool = false;
		var firstEvent:Bool = false;
		sectionFirstNoteID = 0;
		sectionFirstEventID = 0;
		for (num => note in notes)
		{
			if(note != null && curSecFilter(note))
			{
				if(!firstNote) sectionFirstNoteID = num;
				curRenderedNotes.add(note);
				note.alpha = (note.strumTime >= Conductor.songPosition) ? 1 : 0.6;
				if(note.hasSustain) note.updateSustainToZoom(cachedSectionCrochets[curSec] / 4, curZoom);
			}
		}

		if(SHOW_EVENT_COLUMN)
		{
			for (num => event in events)
			{
				if(event != null && curSecFilter(event))
				{
					if(!firstEvent) sectionFirstEventID = num;
					curRenderedNotes.add(event);
					event.alpha = (event.strumTime >= Conductor.songPosition) ? 1 : 0.6;
					event.eventText.visible = true;
				}
			}
		}

		if(!onlyCurrent)
		{
			if(showPreviousSection || showNextSection)
			{
				var prevMinTime:Float = getMinNoteTime(curSec-1);
				var prevMaxTime:Float = getMaxNoteTime(curSec-1);
				var nextMinTime:Float = getMinNoteTime(curSec+1);
				var nextMaxTime:Float = getMaxNoteTime(curSec+1);
				function otherSecFilter(note:MetaNote)
				{
					return (prevGridBg.visible && (note.strumTime >= prevMinTime && note.strumTime < prevMaxTime)) ||
						(nextGridBg.visible && (note.strumTime >= nextMinTime && note.strumTime < nextMaxTime));
				}
	
				for(note in notes.filter(otherSecFilter))
				{
					behindRenderedNotes.add(note);
					note.alpha = 0.4;
					if(note.hasSustain) note.updateSustainToZoom(cachedSectionCrochets[curSec] / 4, curZoom);
				}

				if(SHOW_EVENT_COLUMN)
				{
					for(event in events.filter(otherSecFilter))
					{
						behindRenderedNotes.add(event);
						event.alpha = 0.4;
						event.eventText.visible = false;
					}
				}
			}
		}
	}

	function getMinNoteTime(sec:Int)
	{
		var minTime:Float = Math.NEGATIVE_INFINITY;
		if(sec > 0)
			minTime = cachedSectionTimes[sec];
		return minTime;
	}

	function getMaxNoteTime(sec:Int)
	{
		var maxTime:Float = Math.POSITIVE_INFINITY;
		if(sec < cachedSectionTimes.length)
			maxTime = cachedSectionTimes[sec + 1];
		return maxTime;
	}

	function positionNoteXByData(note:MetaNote, ?data:Null<Int> = null)
	{
		if(data == null) data = note.songData[1];

		var noteX:Float = gridBg.x + (GRID_SIZE - note.width) / 2;
		if(SHOW_EVENT_COLUMN) noteX += GRID_SIZE;

		noteX += GRID_SIZE * (data % (GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS));
		note.x = noteX;
	}

	function positionNoteYOnTime(note:MetaNote, section:Int)
	{
		if(cachedSectionCrochets.length < 1) return;
		section = Std.int(FlxMath.bound(section, 0, cachedSectionCrochets.length - 1));

		var time:Float = note.strumTime - cachedSectionTimes[section];
		var noteY:Float = (time / cachedSectionCrochets[section]) * GRID_SIZE * 4 * curZoom;
		noteY += cachedSectionRow[section] * GRID_SIZE * curZoom;
		noteY = Math.max(noteY, -150);
		note.y = noteY + (GRID_SIZE/2 - note.height/2);
		note.chartY = noteY;
		//trace(gridBg.y, noteY);
	}

	var characterData:Dynamic = {};
	function updateJsonData():Void
	{
		for (i in 1...GRID_PLAYERS+1)
		{
			var charName:String = i <= 2
				? Reflect.field(PlayState.SONG, 'player$i')
				: (strumlineConfigs[i - 3] != null ? strumlineConfigs[i - 3].character : null);
			var data:CharacterFile = loadCharacterFile(charName);
			Reflect.setField(characterData, 'iconP$i', data != null && data.healthicon != null ? data.healthicon : 'face');
			Reflect.setField(characterData, 'vocalsP$i', data != null && data.vocals_file != null ? data.vocals_file : '');
		}
	}

	function updateIconsScale(elapsed:Float)
	{
		for(icon in icons)
		{
			if(icon != null)
			{
				var mult:Float = FlxMath.lerp(0.3, icon.scale.x, Math.exp(-elapsed * 9 * playbackRate));
				icon.scale.set(mult, mult);
				icon.updateHitbox();
			}
		}
	}
	
	var _lastSec:Int = -1;
	var _lastGfSection:Null<Bool> = null;
	var _lastChangeCharTime:Float = -1;
	function updateHeads(ignoreCheck:Bool = false):Void
	{
		var curSecData:SwagSection = PlayState.SONG.notes[curSec];
		var isGfSection:Bool = (curSecData != null && curSecData.gfSection == true);

		var changeCharTime:Float = Conductor.songPosition;
		if(_lastGfSection == isGfSection && _lastSec == curSec && _lastChangeCharTime == changeCharTime && !ignoreCheck) return;

		var overrideP1:String = null;
		var overrideP2:String = null;
		for (ev in events)
		{
			if(ev == null || ev.strumTime > Conductor.songPosition) continue;
			for (subEvent in ev.events)
			{
				if(subEvent == null || subEvent[0] != 'Change Character') continue;
				var target:String = subEvent[1] != null ? subEvent[1].toLowerCase().trim() : '';
				var newChar:String = subEvent[2] != null ? subEvent[2].trim() : '';
				if(newChar.length < 1) continue;
				if(target == 'bf' || target == 'player')
					overrideP1 = newChar;
				else if(target == 'dad' || target == 'opponent')
					overrideP2 = newChar;
			}
		}

		for (i in 0...GRID_PLAYERS)
		{
			var icon:HealthIcon = icons[i];
			if(icon == null) continue;
			var iconName:String = Reflect.field(characterData, 'iconP${icon.ID}');
			if(i == 0 && overrideP1 != null)
			{
				var data:CharacterFile = loadCharacterFile(overrideP1);
				iconName = (data != null && data.healthicon != null) ? data.healthicon : iconName;
			}
			else if(i == 1 && overrideP2 != null)
			{
				var data:CharacterFile = loadCharacterFile(overrideP2);
				iconName = (data != null && data.healthicon != null) ? data.healthicon : iconName;
			}
			icon.changeIcon(iconName);
		}

		if(toysEnabled) updateToyCharacters(overrideP1, overrideP2);
		var mustHitSection:Bool = (curSecData != null && curSecData.mustHitSection == true);
		var mustHitTarget:String = (curSecData != null && curSecData.mustHitTarget != null) ? curSecData.mustHitTarget : '';
		if(icons.length > 1)
		{
			var iconP1:HealthIcon = icons[0];
			var iconP2:HealthIcon = icons[1];
			if (isGfSection)
			{
				if (mustHitSection)
					iconP1.changeIcon('gf');
				else
					iconP2.changeIcon('gf');
			}

			if (isGfSection)
				mustHitIndicator.x = (mustHitSection ? iconP1.x : iconP2.x) + iconP1.width / 2;
			else if (mustHitSection)
				mustHitIndicator.x = iconP1.x + iconP1.width / 2;
			else if (mustHitTarget.startsWith('Strumline #'))
			{
				var strumIndex:Null<Int> = Std.parseInt(mustHitTarget.substr('Strumline #'.length));
				var targetIcon:HealthIcon = (strumIndex != null && strumIndex - 1 < icons.length) ? icons[strumIndex - 1] : null;
				mustHitIndicator.x = (targetIcon != null ? targetIcon.x : iconP2.x) + iconP2.width / 2;
			}
			else
				mustHitIndicator.x = iconP2.x + iconP2.width / 2;
		}
		else if(icons.length == 1)
		{
			if (isGfSection)
				icons[0].changeIcon('gf');
			mustHitIndicator.x = icons[0].x + icons[0].width / 2;
		}
		else if(icons.length == 0)
		{
			mustHitIndicator.x = gridBg.x + gridBg.width / 2;
		}
		_lastGfSection = isGfSection;
		_lastSec = curSec;
		_lastChangeCharTime = changeCharTime;
	}

	var playbackSlider:PsychUISlider;

	var mouseSnapCheckBox:PsychUICheckBox;
	var ignoreProgressCheckBox:PsychUICheckBox;
	var hitsoundPlayerSlider:PsychUISlider;
	var hitsoundOpponentSlider:PsychUISlider;
	var metronomeSlider:PsychUISlider;

	var instVolumeSlider:PsychUISlider;
	var instMuteCheckBox:PsychUICheckBox;
	var playerVolumeSlider:PsychUISlider;
	var playerMuteCheckBox:PsychUICheckBox;
	var opponentVolumeSlider:PsychUISlider;
	var opponentMuteCheckBox:PsychUICheckBox;

	var difficultyDropDown:PsychUIDropDownMenu;
	var curDifficultyIndex:Int = 0;
	static inline final NEW_DIFF_LABEL:String = 'New Difficulty...';

	function addChartingTab()
	{
		var tab_group = mainBox.getTab('Chart').menu;
		var objX = 10;
		var objY = 10;

		var diffLabel = new FlxText(objX, objY, 200, 'Difficulty:');
		difficultyDropDown = new PsychUIDropDownMenu(objX, objY + 18, ['Normal'], function(id:Int, diff:String) switchDifficulty(id));

		objY += 55;
		var txt = new FlxText(objX, objY, 280, "The options below won't affect gameplay!");
		txt.alignment = CENTER;

		objY += 25;
		playbackSlider = new PsychUISlider(50, objY, function(v:Float) setPitch(playbackRate = v), 1, 0.1, 5.0, 200);
		playbackSlider.label = 'Playback Rate';

		objY += 60;
		mouseSnapCheckBox = new PsychUICheckBox(objX, objY, 'Mouse Scroll Snap', 100, function() chartEditorSave.data.mouseScrollSnap = mouseSnapCheckBox.checked);
		mouseSnapCheckBox.checked = chartEditorSave.data.mouseScrollSnap;

		ignoreProgressCheckBox = new PsychUICheckBox(objX + 150, objY, 'Ignore Progress Warnings', 100, function() chartEditorSave.data.ignoreProgressWarns = ignoreProgressCheckBox.checked);
		ignoreProgressCheckBox.checked = chartEditorSave.data.ignoreProgressWarns;

		tab_group.add(txt);
		tab_group.add(playbackSlider);
		tab_group.add(mouseSnapCheckBox);
		tab_group.add(ignoreProgressCheckBox);
		tab_group.add(diffLabel);
		tab_group.add(difficultyDropDown);

		difficultyDropDown.autoSort = false;
	}

	var artistInputText:PsychUIInputText;
	var composerInputText:PsychUIInputText;
	var charterInputText:PsychUIInputText;
	var coderInputText:PsychUIInputText;
	var showAllCreditsCheckBox:PsychUICheckBox;
	
	var metaDataCreditsA:Array<String> = [];
	var metaDataCreditsCO:Array<String> = [];
	var metaDataCreditsCH:Array<String> = [];
	var metaDataCreditsCOD:Array<String> = [];
	var pauseDisplayNameInputText:PsychUIInputText;

	function addMetaDataTab()
	{
		var loadedMeta:funkin.data.MetaData.SongMeta = funkin.data.MetaData.parse(Paths.formatToSongPath(PlayState.SONG.song));
		
		var tab_group = mainBox.getTab('Meta').menu;
		var objX = 10;
		var objY = 10;

		var txt = new FlxText(objX, objY, 280, "Put the song credits here!");
		txt.alignment = CENTER;
		tab_group.add(txt);

		objY += 20;
		var pauseDisplayName:String = loadedMeta.pauseDisplayName != null ? loadedMeta.pauseDisplayName : '';
		pauseDisplayNameInputText = new PsychUIInputText(objX + 40, objY + 15, 200, pauseDisplayName, 8);
		var pauseLabel = new FlxText(objX + 40, objY, 200, 'Display Song Name:');
		pauseLabel.alignment = CENTER;
		tab_group.add(pauseLabel);
		tab_group.add(pauseDisplayNameInputText);

		objY += 45;
		var artistNames:Array<String> = [""];
		var composerNames:Array<String> = [""];
		var charterNames:Array<String> = [""];
		var coderNames:Array<String> = [""];
		
		for(credit in loadedMeta.credits)
		{
			if(credit.role == "Artist") artistNames = credit.names;
			else if(credit.role == "Composer") composerNames = credit.names;
			else if(credit.role == "Charter") charterNames = credit.names;
			else if(credit.role == "Coder") coderNames = credit.names;
		}
		
		artistInputText = new PsychUIInputText(objX, objY + 15, 120, artistNames.join(', '), 8);
		metaDataCreditsA = artistNames.filter(function(s:String) return s.length > 0);
		artistInputText.onChange = function(old:String, cur:String)
		{
			metaDataCreditsA = cur.split(',').map(function(s:String) return s.trim()).filter(function(s:String) return s.length > 0);
		};
		
		composerInputText = new PsychUIInputText(objX + 150, objY + 15, 120, composerNames.join(', '), 8);
		metaDataCreditsCO = composerNames.filter(function(s:String) return s.length > 0);
		composerInputText.onChange = function(old:String, cur:String)
		{
			metaDataCreditsCO = cur.split(',').map(function(s:String) return s.trim()).filter(function(s:String) return s.length > 0);
		};

		objY += 40;
		charterInputText = new PsychUIInputText(objX, objY + 15, 120, charterNames.join(', '), 8);
		metaDataCreditsCH = charterNames.filter(function(s:String) return s.length > 0);
		charterInputText.onChange = function(old:String, cur:String)
		{
			metaDataCreditsCH = cur.split(',').map(function(s:String) return s.trim()).filter(function(s:String) return s.length > 0);
		};
		
		coderInputText = new PsychUIInputText(objX + 150, objY + 15, 120, coderNames.join(', '), 8);
		metaDataCreditsCOD = coderNames.filter(function(s:String) return s.length > 0);
		coderInputText.onChange = function(old:String, cur:String)
		{
			metaDataCreditsCOD = cur.split(',').map(function(s:String) return s.trim()).filter(function(s:String) return s.length > 0);
		};

		objY += 50;
		var exportButton:PsychUIButton = new PsychUIButton(objX, objY, 'Export Metadata', function()
		{
			exportMetaData();
		}, 120);
		tab_group.add(exportButton);
		
		showAllCreditsCheckBox = new PsychUICheckBox(objX + 140, objY, 'Show All Credits', 120);
		showAllCreditsCheckBox.checked = loadedMeta.showAllCredits;
		tab_group.add(showAllCreditsCheckBox);

		tab_group.add(new FlxText(artistInputText.x, artistInputText.y - 15, 120, 'Artist:'));
		tab_group.add(new FlxText(composerInputText.x, composerInputText.y - 15, 120, 'Composer:'));
		tab_group.add(new FlxText(charterInputText.x, charterInputText.y - 15, 120, 'Charter:'));
		tab_group.add(new FlxText(coderInputText.x, coderInputText.y - 15, 120, 'Coder:'));

		tab_group.add(artistInputText);
		tab_group.add(composerInputText);
		tab_group.add(charterInputText);
		tab_group.add(coderInputText);
	}

	function exportMetaData()
	{
		if(metaDataCreditsA.length == 0 && metaDataCreditsCO.length == 0 && metaDataCreditsCH.length == 0 && metaDataCreditsCOD.length == 0)
		{
			showOutput('Please fill at least one credit field!', true);
			return;
		}

		var creditLines:Array<String> = [];
		
		if(metaDataCreditsA.length > 0)
			creditLines.push('\t\t"Artist": ' + haxe.Json.stringify(metaDataCreditsA));
		if(metaDataCreditsCO.length > 0)
			creditLines.push('\t\t"Composer": ' + haxe.Json.stringify(metaDataCreditsCO));
		if(metaDataCreditsCH.length > 0)
			creditLines.push('\t\t"Charter": ' + haxe.Json.stringify(metaDataCreditsCH));
		if(metaDataCreditsCOD.length > 0)
			creditLines.push('\t\t"Coder": ' + haxe.Json.stringify(metaDataCreditsCOD));
		
		var pauseNameValue:String = pauseDisplayNameInputText.text.trim();
		var pauseNameJson:String = pauseNameValue.length > 0 ? (',\n\t"pauseDisplayName": ' + haxe.Json.stringify(pauseNameValue)) : '';
		var metadataJson:String = '{\n\t"credits": {\n' + creditLines.join(',\n') + '\n\t},\n\t"showAllCredits": ' + (showAllCreditsCheckBox.checked ? 'true' : 'false') + pauseNameJson + '\n}';
		var songFolder:String = Paths.formatToSongPath(PlayState.SONG.song);
		var chartName:String = 'metadata.json';

		updateChartData();
		
		if(!fileDialog.completed) return;
		upperBox.isMinimized = true;
		upperBox.bg.visible = false;

		fileDialog.save(chartName, metadataJson,
			function()
			{
				var newPath:String = fileDialog.path;
				showOutput('Metadata saved successfully to: $newPath');
			}, 
			null, 
			function() 
			{
				showOutput('Error on saving metadata!', true);
			}
		);
	}

	var gameOverCharDropDown:PsychUIDropDownMenu;
	var gameOverSndInputText:PsychUIInputText;
	var gameOverLoopInputText:PsychUIInputText;
	var gameOverRetryInputText:PsychUIInputText;
	var noRGBCheckBox:PsychUICheckBox;
	var noSplashRGBCheckBox:PsychUICheckBox;
	var noHoldRGBCheckBox:PsychUICheckBox;
	var noteTextureInputText:PsychUIInputText;
	var noteSplashesInputText:PsychUIInputText;
	var holdCoverInputText:PsychUIInputText;
	function addDataTab()
	{
		var tab_group = mainBox.getTab('Data').menu;
		var objX = 10;
		var objY = 25;
		gameOverCharDropDown = new PsychUIDropDownMenu(objX, objY, [''], function(id:Int, character:String)
		{
			PlayState.SONG.gameOverChar = character;
			if(character.length < 1) Reflect.deleteField(PlayState.SONG, 'gameOverChar');
			trace('selected $character');
		});

		objY += 40;
		gameOverSndInputText = new PsychUIInputText(objX, objY, 120, '', 8);
		gameOverSndInputText.onChange = function(old:String, cur:String)
		{
			PlayState.SONG.gameOverSound = cur;
			if(cur.trim().length < 1) Reflect.deleteField(PlayState.SONG, 'gameOverSound');
		}
		objY += 40;
		gameOverLoopInputText = new PsychUIInputText(objX, objY, 120, '', 8);
		gameOverLoopInputText.onChange = function(old:String, cur:String)
		{
			PlayState.SONG.gameOverLoop = cur;
			if(cur.trim().length < 1) Reflect.deleteField(PlayState.SONG, 'gameOverLoop');
		}
		objY += 40;
		gameOverRetryInputText = new PsychUIInputText(objX, objY, 120, '', 8);
		gameOverRetryInputText.onChange = function(old:String, cur:String)
		{
			PlayState.SONG.gameOverEnd = cur;
			if(cur.trim().length < 1) Reflect.deleteField(PlayState.SONG, 'gameOverEnd');
		}

		objY += 35;
		noRGBCheckBox = new PsychUICheckBox(objX, objY, 'Disable Note RGB', 140, updateNotesRGB);
		noteTextureInputText = new PsychUIInputText(objX + 150, objY, 120, '');
		noteTextureInputText.unfocus = function()
		{
			var changed:Bool = false;
			if(PlayState.SONG.arrowSkin != noteTextureInputText.text) changed = true;
			PlayState.SONG.arrowSkin = noteTextureInputText.text.trim();
			if(PlayState.SONG.arrowSkin.trim().length < 1) PlayState.SONG.arrowSkin = null;

			if(changed)
			{
				var textureLoad:String = 'images/${noteTextureInputText.text}.png';
				if(Paths.fileExists(textureLoad, IMAGE) || noteTextureInputText.text.trim() == '')
				{
					for (note in notes)
					{
						if(note == null) continue;
						note.reloadNote(note.texture);
		
						if(note.width > note.height)
							note.setGraphicSize(GRID_SIZE);
						else
							note.setGraphicSize(0, GRID_SIZE);
		
						note.updateHitbox();
					}
					strumLineNotes.forEachAlive(function(n) n.destroy());
					strumLineNotes.clear();
					var strumStartX:Float = gridBg.x + (SHOW_EVENT_COLUMN ? GRID_SIZE : 0);
					var strumStartY:Float = FlxG.height / 2;
					for (i in 0...Std.int(GRID_PLAYERS * GRID_COLUMNS_PER_PLAYER))
					{
						var sn:StrumNote = new StrumNote(strumStartX + (GRID_SIZE * i), strumStartY, i % GRID_COLUMNS_PER_PLAYER, 0);
						sn.scrollFactor.set();
						sn.playAnim('static');
						sn.alpha = 0.4;
						sn.updateHitbox();
						if(sn.width > sn.height)
							sn.setGraphicSize(GRID_SIZE);
						else
							sn.setGraphicSize(0, GRID_SIZE);
						sn.updateHitbox();
						sn.x += GRID_SIZE / 2 - sn.width / 2;
						sn.y += GRID_SIZE / 2 - sn.height / 2;
						strumLineNotes.add(sn);
					}
					strumLineNotes.visible = strumLineNotes.active = vortexEnabled;
					updateMiniChartPosition();
					if(noteTextureInputText.text.trim().length > 0) showOutput('Reloaded notes to: "$textureLoad"');
					else showOutput('Reloaded notes to default texture');
				}
				else showOutput('ERROR: "$textureLoad" not found.', true);
			}
		};

		objY += 30;
		noSplashRGBCheckBox = new PsychUICheckBox(objX, objY, 'Disable Note Splash RGB', 140, updateSplashRGB);
		noteSplashesInputText = new PsychUIInputText(objX + 150, objY, 120, '');
		noteSplashesInputText.onChange = function(old:String, cur:String)
		{
			PlayState.SONG.splashSkin = cur;
			if(cur.trim().length < 1) PlayState.SONG.splashSkin = null;
		};

		objY += 30;
		noHoldRGBCheckBox = new PsychUICheckBox(objX, objY, 'Disable Hold Cover RGB', 140, updateHoldRGB);
		holdCoverInputText = new PsychUIInputText(objX + 150, objY, 120, '');
		holdCoverInputText.unfocus = function()
		{
			var changed:Bool = false;
			if(PlayState.SONG.holdCoverSkin != holdCoverInputText.text) changed = true;
			PlayState.SONG.holdCoverSkin = holdCoverInputText.text.trim();
			if(PlayState.SONG.holdCoverSkin.trim().length < 1) PlayState.SONG.holdCoverSkin = null;

			if(changed)
			{
				var textureLoad:String = 'images/${holdCoverInputText.text}.png';
				if(Paths.fileExists(textureLoad, IMAGE) || holdCoverInputText.text.trim() == '')
				{
					if(holdCoverInputText.text.trim().length > 0) showOutput('Reloaded hold covers to: "$textureLoad"');
					else showOutput('Reloaded hold covers to default texture');
				}
				else showOutput('ERROR: "$textureLoad" not found.', true);
			}
		};

		tab_group.add(new FlxText(gameOverCharDropDown.x, gameOverCharDropDown.y - 15, 120, 'Game Over Character:'));
		tab_group.add(new FlxText(gameOverSndInputText.x, gameOverSndInputText.y - 15, 180, 'Game Over Death Sound (sounds/):'));
		tab_group.add(new FlxText(gameOverLoopInputText.x, gameOverLoopInputText.y - 15, 180, 'Game Over Loop Music (music/):'));
		tab_group.add(new FlxText(gameOverRetryInputText.x, gameOverRetryInputText.y - 15, 180, 'Game Over Retry Music (music/):'));
		tab_group.add(gameOverSndInputText);
		tab_group.add(gameOverLoopInputText);
		tab_group.add(gameOverRetryInputText);

		tab_group.add(noRGBCheckBox);
		tab_group.add(new FlxText(noteTextureInputText.x, noteTextureInputText.y - 14, 120, 'Note Texture:'));
		tab_group.add(noteTextureInputText);

		tab_group.add(noSplashRGBCheckBox);
		tab_group.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 14, 140, 'Note Splashes Texture:'));
		tab_group.add(noteSplashesInputText);

		tab_group.add(noHoldRGBCheckBox);
		tab_group.add(new FlxText(holdCoverInputText.x, holdCoverInputText.y - 14, 130, 'Hold Cover Texture:'));
		tab_group.add(holdCoverInputText);

		tab_group.add(gameOverCharDropDown);
	}

	var eventDropDown:PsychUIDropDownMenu;
	var easeDropDown:PsychUIDropDownMenu;
	var easeInOutDropDown:PsychUIDropDownMenu;
	var easeInOutLabel:FlxText;
	var valueInputTexts:Array<PsychUIInputText> = [];
	var valueLabels:Array<FlxText> = [];
	static inline var MAX_EVENT_VALUES:Int = 10;
	var selectedEventText:FlxText;
	var eventDescriptionText:FlxText;
	var _customUIAll:Array<Dynamic> = [];
	var _customUISync:Array<{ctrl:Dynamic, inputIdx:Int}> = [];
	var _customUIReplacedIndices:Array<Int> = [];
	var _lastCustomUIEvent:String = null;
	var _pendingUIData:Array<Dynamic> = null;

	var eventsList:Array<Array<String>>;
	var curEventSelected:Int = 0;

	function _changeEventValue(str:String, n:Int)
	{
		if(selectedNotes.length > 1)
		{
			for (note in selectedNotes)
			{
				if(note == null || !note.isEvent) continue;
				var event:EventMetaNote = cast (note, EventMetaNote);
				event.events[event.events.length - 1][n] = str;
				event.updateEventText();
			}
		}
		else if(selectedNotes.length == 1 && selectedNotes[0].isEvent)
		{
			var event:EventMetaNote = cast (selectedNotes[0], EventMetaNote);
			event.events[Std.int(FlxMath.bound(curEventSelected, 0, event.events.length - 1))][n] = str;
			event.updateEventText();
		}
	}

	function getEventUIData(eventName:String):Array<Dynamic>
	{
		if(eventName == null || eventName.trim().length == 0) return null;

		var jsonFile:String = Paths.getTextFromFile('custom_events/$eventName.json');
		if(jsonFile != null && jsonFile.length > 0)
		{
			try
			{
				var parsed:Dynamic = haxe.Json.parse(jsonFile);
				var result:Array<Dynamic> = [];
				if(Std.isOfType(parsed, Array))
				{
					result = cast parsed;
					for(i in 0...result.length)
						if(result[i] != null && !Reflect.hasField(result[i], 'value'))
							Reflect.setField(result[i], 'value', i + 1);
				}
				if(result.length > 0) return result;
			}
			catch(e:Dynamic) {}
		}

		var content:String = null;
		var isHScript:Bool = false;
		#if LUA_ALLOWED
		if(content == null)
		{
			var c:String = Paths.getTextFromFile('custom_events/$eventName.lua');
			if(c != null && c.length > 0) content = c;
		}
		#end
		#if HSCRIPT_ALLOWED
		if(content == null)
		{
			var c:String = Paths.getTextFromFile('custom_events/$eventName.hx');
			if(c != null && c.length > 0) { content = c; isHScript = true; }
		}
		#end
		if(content == null) return null;

		#if HSCRIPT_ALLOWED
		if(isHScript && content.indexOf('getEventUI') != -1)
		{
			try
			{
				var hs:funkin.scripting.HScript = new funkin.scripting.HScript(null, content, null, true);
				hs.execute();
				if(hs.exists('getEventUI'))
				{
					var retVal = hs.call('getEventUI', []);
					if(retVal != null && retVal.returnValue != null)
					{
						var raw:Array<Dynamic> = cast retVal.returnValue;
						for(i in 0...raw.length)
							if(raw[i] != null && !Reflect.hasField(raw[i], 'value'))
								Reflect.setField(raw[i], 'value', i + 1);
						hs.destroy();
						if(raw.length > 0) return raw;
					}
				}
				hs.destroy();
			}
			catch(e:Dynamic) {}
		}
		#end

		#if LUA_ALLOWED
		if(!isHScript && content.indexOf('getEventUI') != -1)
		{
			try
			{
				var L:State = LuaL.newstate();
				LuaL.openlibs(L);
				LuaL.dostring(L, content);
				LuaL.dostring(L, "
function __encode(v)
	if type(v) == 'table' then
		local isArr = true
		local n = 0
		for k in pairs(v) do
			n = n + 1
			if type(k) ~= 'number' then
				isArr = false
			end
		end
		if isArr then
			local parts = {}
			for i = 1, n do
				parts[i] = __encode(v[i])
			end
			return '[' .. table.concat(parts, ',') .. ']'
		else
			local parts = {}
			for k, val in pairs(v) do
				parts[#parts+1] = '\"' .. tostring(k) .. '\":' .. __encode(val)
			end
			return '{' .. table.concat(parts, ',') .. '}'
		end
	elseif type(v) == 'string' then
		return '\"' .. v .. '\"'
	elseif type(v) == 'number' or type(v) == 'boolean' then
		return tostring(v)
	else
		return 'null'
	end
end
if type(getEventUI) == 'function' then
	__ui_result = __encode(getEventUI())
else
	__ui_result = nil
end
");
				Lua.getglobal(L, '__ui_result');
				if(Lua.type(L, -1) == Lua.LUA_TSTRING)
				{
					var jsonStr:String = Lua.tostring(L, -1);
					Lua.pop(L, 1);
					Lua.close(L);
					try
					{
						var raw:Array<Dynamic> = cast haxe.Json.parse(jsonStr);
						for(i in 0...raw.length)
							if(raw[i] != null && !Reflect.hasField(raw[i], 'value'))
								Reflect.setField(raw[i], 'value', i + 1);
						if(raw.length > 0) return raw;
					}
					catch(e:Dynamic) {}
				}
				else
				{
					Lua.pop(L, 1);
					Lua.close(L);
				}
			}
			catch(e:Dynamic) {}
		}
		#end

		return null;
	}

	function _clearCustomUI()
	{
		var evTab = mainBox != null ? mainBox.getTab('Events') : null;
		var tab_group:FlxSpriteGroup = evTab != null ? evTab.menu : null;
		for(ctrl in _customUIAll)
		{
			if(tab_group != null) tab_group.remove(ctrl, true);
			ctrl.destroy();
		}
		_customUIAll = [];
		_customUISync = [];
		_customUIReplacedIndices = [];
	}

	function _buildCustomUI(uiData:Array<Dynamic>)
	{
		if(uiData == null || uiData.length == 0) return;
		var evTab = mainBox != null ? mainBox.getTab('Events') : null;
		var tab_group:FlxSpriteGroup = evTab != null ? evTab.menu : null;
		if(tab_group == null) return;

		for(item in uiData)
		{
			var valueIdx:Int = Reflect.hasField(item, 'value') ? Std.int(Reflect.field(item, 'value')) : 1;
			var inputIdx:Int = valueIdx - 1;
			if(inputIdx < 0 || inputIdx >= valueInputTexts.length) continue;

			var inp:PsychUIInputText = valueInputTexts[inputIdx];
			var lbl:FlxText = (inputIdx < valueLabels.length) ? valueLabels[inputIdx] : null;
			var type:String = Reflect.hasField(item, 'type') ? Std.string(Reflect.field(item, 'type')).toLowerCase() : 'inputtext';
			var label:String = Reflect.hasField(item, 'label') ? Std.string(Reflect.field(item, 'label')) : 'Value $valueIdx';

			if(type == 'inputtext')
			{
				if(lbl != null) lbl.text = '$label:';
				continue;
			}

			inp.visible = inp.active = false;
			if(lbl != null) lbl.visible = false;
			_customUIReplacedIndices.push(inputIdx);

			var menuX:Float = evTab.menu.x;
			var menuY:Float = evTab.menu.y;
			var offX:Float = Reflect.hasField(item, 'x') ? cast Reflect.field(item, 'x') : 0;
			var offY:Float = Reflect.hasField(item, 'y') ? cast Reflect.field(item, 'y') : 0;
			var lblText:FlxText = new FlxText(inp.x - menuX + offX, inp.y - menuY - 15 + offY, 140, '$label:');
			tab_group.add(lblText);
			_customUIAll.push(lblText);

			var capturedIdx:Int = inputIdx;
			if(eventDropDown != null) eventDropDown.showDropDown(false);

			switch(type)
			{
				case 'checkbox':
					var check:PsychUICheckBox = new PsychUICheckBox(inp.x - menuX + offX, inp.y - menuY + offY, '', 0, null);
					check.checked = (inp.text == 'true');
					check.onClick = function()
					{
						if(eventDropDown != null) eventDropDown.showDropDown(false);
						var val:String = Std.string(check.checked);
						valueInputTexts[capturedIdx].text = val;
						_changeEventValue(val, capturedIdx + 1);
					};
					tab_group.add(check);
					_customUIAll.push(check);
					_customUISync.push({ctrl: check, inputIdx: capturedIdx});

				case 'dropdown':
					var opts:Array<String> = Reflect.hasField(item, 'options') ? cast Reflect.field(item, 'options') : [];
					var dropW:Int = Reflect.hasField(item, 'width') ? Std.int(Reflect.field(item, 'width')) : 140;
					var drop:PsychUIDropDownMenu = new PsychUIDropDownMenu(inp.x - menuX + offX, inp.y - menuY + offY, opts, function(id:Int, selected:String)
					{
						valueInputTexts[capturedIdx].text = selected;
						_changeEventValue(selected, capturedIdx + 1);
					}, dropW);
					drop.autoSort = false;
					if(inp.text.length > 0 && opts.contains(inp.text))
						drop.selectedLabel = inp.text;
					drop.onChange = function(old:String, cur:String)
					{
						if(PsychUIInputText.focusOn == drop && eventDropDown != null)
							eventDropDown.showDropDown(false);
					};
					tab_group.insert(tab_group.members.indexOf(eventDropDown), drop);
					_customUIAll.push(drop);
					_customUISync.push({ctrl: drop, inputIdx: capturedIdx});

				case 'stepper':
					var minVal:Float = Reflect.hasField(item, 'min') ? cast Reflect.field(item, 'min') : 0;
					var maxVal:Float = Reflect.hasField(item, 'max') ? cast Reflect.field(item, 'max') : 100;
					var stepVal:Float = Reflect.hasField(item, 'step') ? cast Reflect.field(item, 'step') : 1;
					var decimals:Int = Reflect.hasField(item, 'decimals') ? Std.int(Reflect.field(item, 'decimals')) : 0;
					var stepW:Int = Reflect.hasField(item, 'width') ? Std.int(Reflect.field(item, 'width')) : 100;
					var defVal:Float = Std.parseFloat(inp.text);
					if(Math.isNaN(defVal)) defVal = minVal;
					var stepper:PsychUINumericStepper = new PsychUINumericStepper(inp.x - menuX + offX, inp.y - menuY + offY, stepVal, defVal, minVal, maxVal, decimals, stepW);
					stepper.onValueChange = function()
					{
						var val:String = Std.string(stepper.value);
						valueInputTexts[capturedIdx].text = val;
						_changeEventValue(val, capturedIdx + 1);
					};
					tab_group.add(stepper);
					_customUIAll.push(stepper);
					_customUISync.push({ctrl: stepper, inputIdx: capturedIdx});

				case 'slider':
					var minVal:Float = Reflect.hasField(item, 'min') ? cast Reflect.field(item, 'min') : 0;
					var maxVal:Float = Reflect.hasField(item, 'max') ? cast Reflect.field(item, 'max') : 1;
					var decimals:Int = Reflect.hasField(item, 'decimals') ? Std.int(Reflect.field(item, 'decimals')) : 2;
					var sliderW:Float = Reflect.hasField(item, 'width') ? cast Reflect.field(item, 'width') : 130;
					var defVal:Float = Std.parseFloat(inp.text);
					if(Math.isNaN(defVal)) defVal = minVal;
					var slider:PsychUISlider = new PsychUISlider(inp.x - menuX + offX, inp.y - menuY + offY, function(v:Float)
					{
						if(eventDropDown != null) eventDropDown.showDropDown(false);
						var val:String = Std.string(v);
						valueInputTexts[capturedIdx].text = val;
						_changeEventValue(val, capturedIdx + 1);
					}, defVal, minVal, maxVal, sliderW);
					slider.decimals = decimals;
					tab_group.add(slider);
					_customUIAll.push(slider);
					_customUISync.push({ctrl: slider, inputIdx: capturedIdx});

				case 'radiogroup':
					var opts:Array<String> = Reflect.hasField(item, 'options') ? cast Reflect.field(item, 'options') : [];
					var radioW:Int = Reflect.hasField(item, 'width') ? Std.int(Reflect.field(item, 'width')) : 120;
					var radio:PsychUIRadioGroup = new PsychUIRadioGroup(inp.x - menuX + offX, inp.y - menuY + offY, opts, 20, 0, false, radioW);
					if(inp.text.length > 0)
					{
						var ridx:Int = opts.indexOf(inp.text);
						if(ridx >= 0) radio.checked = ridx;
					}
					radio.onClick = function()
					{
						if(eventDropDown != null) eventDropDown.showDropDown(false);
						var val:String = (radio.checkedRadio != null) ? radio.checkedRadio.label : '';
						valueInputTexts[capturedIdx].text = val;
						_changeEventValue(val, capturedIdx + 1);
					};
					tab_group.add(radio);
					_customUIAll.push(radio);
					_customUISync.push({ctrl: radio, inputIdx: capturedIdx});

				default:
					inp.visible = inp.active = true;
					if(lbl != null) lbl.visible = true;
					_customUIReplacedIndices.remove(inputIdx);
					tab_group.remove(lblText, true);
					lblText.destroy();
					_customUIAll.remove(lblText);
			}
		}
	}

	function _syncCustomUIFromValues()
	{
		for(entry in _customUISync)
		{
			var idx:Int = entry.inputIdx;
			if(idx >= valueInputTexts.length) continue;
			var text:String = valueInputTexts[idx].text;
			var ctrl:Dynamic = entry.ctrl;

			if(Std.isOfType(ctrl, PsychUICheckBox))
				(cast ctrl:PsychUICheckBox).checked = (text == 'true');
			else if(Std.isOfType(ctrl, PsychUIDropDownMenu))
			{
				var drop:PsychUIDropDownMenu = cast ctrl;
				if(drop.list.contains(text))
					drop.selectedLabel = text;
			}
			else if(Std.isOfType(ctrl, PsychUINumericStepper))
			{
				var val:Float = Std.parseFloat(text);
				if(!Math.isNaN(val)) (cast ctrl:PsychUINumericStepper).value = val;
			}
			else if(Std.isOfType(ctrl, PsychUISlider))
			{
				var val:Float = Std.parseFloat(text);
				if(!Math.isNaN(val)) (cast ctrl:PsychUISlider).value = val;
			}
			else if(Std.isOfType(ctrl, PsychUIRadioGroup))
			{
				var radio:PsychUIRadioGroup = cast ctrl;
				var ridx:Int = radio.labels.indexOf(text);
				if(ridx >= 0) radio.checked = ridx;
			}
		}
	}

	function updateEventDescriptionHeight()
	{
		if(eventDescriptionText != null && mainBox != null)
		{
			eventDescriptionText.autoSize = true;
			var textHeight:Float = eventDescriptionText.height;
			var contentBottom:Float = eventDescriptionText.y + textHeight;
			var neededHeight:Int = Std.int(contentBottom + mainBox.tabHeight + 10);

			if(neededHeight < mainBoxOriginalHeight)
				neededHeight = mainBoxOriginalHeight;

			mainBox.resize(300, neededHeight, false);
			if(!infoBoxMoved)
			{
				var newInfoY:Float = mainBox.y + neededHeight;
				infoBox.setPosition(infoBoxPosition.x, newInfoY);
			}
		}
	}

	function updateEventSpecialUI(eventName:String)
	{
		if(easeDropDown == null) return;
		if(eventName != _lastCustomUIEvent)
		{
			_clearCustomUI();
			_lastCustomUIEvent = eventName;
			_pendingUIData = getEventUIData(eventName);
		}
		var useEaseDropDown:Bool = (eventName == 'Set Cam Zoom' || eventName == 'Target Camera' || eventName == 'Target Follow Pos' || eventName == '(STEPS) Set Cam Zoom' || eventName == '(STEPS) Target Camera' || eventName == '(STEPS) Target Follow Pos');
		var isSetCamZoom:Bool = (eventName == 'Set Cam Zoom' || eventName == '(STEPS) Set Cam Zoom');
		var isTargetCamera:Bool = (eventName == 'Target Camera' || eventName == '(STEPS) Target Camera');
		var isTargetFollow:Bool = (eventName == 'Target Follow Pos' || eventName == '(STEPS) Target Follow Pos');
		var useSteps:Bool = (eventName == '(STEPS) Set Cam Zoom' || eventName == '(STEPS) Target Camera' || eventName == '(STEPS) Target Follow Pos');

		var defaultValueCounts:Map<String, Int> = [
			'' => 1,
			'Dadbattle Spotlight' => 1,
			'Hey!' => 2,
			'Set GF Speed' => 1,
			'Philly Glow' => 1,
			'Kill Henchmen' => 0,
			'Add Camera Zoom' => 2,
			'BG Freaks Expression' => 0,
			'Trigger BG Ghouls' => 0,
			'Play Animation' => 2,
			'Target Follow Pos' => 2,
			'Camera Follow Pos' => 2,
			'Alt Idle Animation' => 2,
			'Screen Shake' => 2,
			'Change Character' => 2,
			'Change Scroll Speed' => 2,
			'Set Property' => 2,
			'Play Sound' => 2,
			'Flash Camera' => 2,
			'Video Player' => 2,
			'Set Cam Zoom' => 2,
			'Target Camera' => 2,
			'(STEPS) Set Cam Zoom' => 2,
			'(STEPS) Target Camera' => 2,
			'(STEPS) Target Follow Pos' => 2,
			'Change Note Skin' => 2,
			'Change NoteStrum Skin' => 2
		];

		var detectedIndices:Array<Int> = [];
		var detectedNames:Array<String> = [];
		if(defaultValueCounts.exists(eventName))
		{
			var count:Int = defaultValueCounts.get(eventName);
			for(n in 1...count + 1)
			{
				detectedIndices.push(n);
				detectedNames.push(null);
			}
		}
		else
		{
			for(ev in eventsList)
			{
				if(ev[0] == eventName && ev.length > 2)
				{
					for(part in ev[2].split(','))
					{
						var trimmed:String = part.trim();
						if(trimmed.indexOf(':') >= 0)
						{
							var colonPos:Int = trimmed.indexOf(':');
							var n:Int = Std.parseInt(trimmed.substr(0, colonPos));
							var name:String = trimmed.substr(colonPos + 1).trim();
							if(n > 0)
							{
								detectedIndices.push(n);
								detectedNames.push(name.length > 0 ? name : null);
							}
						}
						else
						{
							var n:Int = Std.parseInt(trimmed);
							if(n > 0)
							{
								detectedIndices.push(n);
								detectedNames.push(null);
							}
						}
					}
					break;
				}
			}
		}
		if(detectedIndices.length == 0)
		{
			detectedIndices = [1, 2];
			detectedNames = [null, null];
		}
		var detectedValues:Int = detectedIndices.length;

		var baseX:Float = valueInputTexts[0].x;
		var baseX2:Float = valueInputTexts[0].x + 150;
		var rowY:Float = valueInputTexts[0].y;
		var rowH:Float = 40;

		for(i in 0...valueInputTexts.length)
		{
			var n:Int = i + 1;
			var isEaseSeconds:Bool = useEaseDropDown && i == 1;
			var isEaseType:Bool = useEaseDropDown && i == 2;
			var show:Bool = n <= detectedValues && !(useEaseDropDown && i >= 2);

			var labelN:Int = (detectedIndices.length > i) ? detectedIndices[i] : n;
			var customName:String = (detectedNames.length > i) ? detectedNames[i] : null;
			if(customName != null && customName.length > 0)
				customName = customName.charAt(0).toUpperCase() + customName.substr(1);
			valueLabels[i].text = (i == 0) ? (isSetCamZoom ? 'New Zoom:' : (isTargetCamera ? 'Target:' : (isTargetFollow ? 'Target:' : (customName != null ? '$customName:' : 'Value ${detectedIndices[0]}:')))) : (isEaseSeconds ? (useSteps ? 'Steps:' : 'Seconds:') : (isEaseType ? 'Ease:' : (customName != null ? '$customName:' : 'Value $labelN:')));
			if(!_customUIReplacedIndices.contains(i))
			{
				valueLabels[i].visible = show || isEaseSeconds || isEaseType;
				valueInputTexts[i].visible = valueInputTexts[i].active = show;
			}

			var col:Int = i % 2;
			var row:Int = Std.int(i / 2);
			var x:Float = col == 0 ? baseX : baseX2;
			var y:Float = rowY + row * rowH;
			valueLabels[i].x = x;
			valueLabels[i].y = y - 15;
			valueInputTexts[i].x = x;
			valueInputTexts[i].y = y;
		}

		easeDropDown.visible = easeDropDown.active = useEaseDropDown;
		easeInOutDropDown.visible = easeInOutDropDown.active = useEaseDropDown;
		if(easeInOutLabel != null) easeInOutLabel.visible = useEaseDropDown;
		if(useEaseDropDown)
		{
			easeDropDown.x = valueInputTexts[2].x;
			easeDropDown.y = valueInputTexts[2].y;
			easeInOutDropDown.x = valueInputTexts[3].x;
			easeInOutDropDown.y = valueInputTexts[3].y;
		}

		var lastRow:Int = useEaseDropDown ? 1 : Std.int(Math.max(0, detectedValues - 1) / 2);
		eventDescriptionText.y = rowY + (lastRow + 1) * rowH;

		if(useEaseDropDown)
		{
			var easeVal:String = valueInputTexts[2].text.trim();
			var baseEase:String = easeVal;
			var direction:String = 'In';
			if(easeVal.endsWith('InOut')) { direction = 'InOut'; baseEase = easeVal.substr(0, easeVal.length - 5); }
			else if(easeVal.endsWith('In')) { direction = 'In'; baseEase = easeVal.substr(0, easeVal.length - 2); }
			else if(easeVal.endsWith('Out')) { direction = 'Out'; baseEase = easeVal.substr(0, easeVal.length - 3); }

			var prevOnChange = easeDropDown.onChange;
			easeDropDown.onChange = null;
			if(baseEase.length > 0 && easeDropDown.list.contains(baseEase))
				easeDropDown.selectedLabel = baseEase;
			else
				easeDropDown.selectedLabel = '';
			easeDropDown.showDropDown(false);
			easeDropDown.onChange = prevOnChange;

			var prevOnChange2 = easeInOutDropDown.onChange;
			easeInOutDropDown.onChange = null;
			var _noDir:Bool = (baseEase == '' || baseEase == 'instant' || baseEase == 'linear');
			easeInOutDropDown.list = _noDir ? [''] : ['In', 'Out', 'InOut'];
			easeInOutDropDown.selectedLabel = _noDir ? '' : direction;
			easeInOutDropDown.showDropDown(false);
			easeInOutDropDown.onChange = prevOnChange2;
		}
		if(_pendingUIData != null)
		{
			_buildCustomUI(_pendingUIData);
			_pendingUIData = null;
		}
	}

	function addEventsTab()
	{
		var tab_group = mainBox.getTab('Events').menu;
		var objX = 10;
		var objY = 25;

		eventDropDown = new PsychUIDropDownMenu(objX, objY, [], function(id:Int, character:String)
		{
			var eventSelected:Array<String> = eventsList[id];
			var eventName:String = eventSelected[0];
			var description:String = eventSelected[1];
			eventDescriptionText.text = description;
			var _useEase:Bool = (eventName == 'Set Cam Zoom' || eventName == 'Target Camera' || eventName == 'Target Follow Pos' || eventName == '(STEPS) Set Cam Zoom' || eventName == '(STEPS) Target Camera' || eventName == '(STEPS) Target Follow Pos');
			if(!_useEase) valueInputTexts[2].text = '';
			updateEventSpecialUI(eventName);
			updateEventDescriptionHeight();
			if(selectedNotes.length > 1)
			{
				for (note in selectedNotes)
				{
					if(note == null || !note.isEvent) continue;

					var event:EventMetaNote = cast (note, EventMetaNote);
					event.events[event.events.length - 1][0] = eventName;
					event.updateEventText();
				}
			}
			else if(selectedNotes.length == 1 && selectedNotes[0].isEvent)
			{
				var event:EventMetaNote = cast (selectedNotes[0], EventMetaNote);
				event.events[Std.int(FlxMath.bound(curEventSelected, 0, event.events.length - 1))][0] = eventName;
				event.updateEventText();
			}
		});

		function genericEventButton(func:EventMetaNote->Void)
		{
			if(selectedNotes.length == 1)
			{
				if(selectedNotes[0].isEvent)
				{
					var event:EventMetaNote = cast (selectedNotes[0], EventMetaNote);
					func(event);
					updateSelectedEventText();
				}
				else showOutput('Note selected must be an Event!', true);
			}
			else showOutput('You must select a single event to press this button.', true);
		}

		var objX2 = 140;
		var removeButton:PsychUIButton = new PsychUIButton(objX2, objY, '-', function()
		{
			genericEventButton(function(event:EventMetaNote)
			{
				if(event.events.length > 1)
				{
					var selectedEvent = event.events[curEventSelected];
					if(selectedEvent != null)
					{
						event.events.remove(selectedEvent);
						event.updateEventText();
						curEventSelected = Std.int(Math.max(0, curEventSelected - 1));
					}
					else showOutput('No event is selected when you deleted it?? Weird.', true);
				}
				else
				{
					selectedNotes.remove(event);
					events.remove(event);
					curRenderedNotes.remove(event, true);
					noteHighlights.clear();
					addUndoAction(DELETE_NOTE, {events: [event]});
					onSelectNote();
					softReloadNotes();
				}
			});
		}, 20);
		var addButton:PsychUIButton = new PsychUIButton(objX2 + 30, objY, '+', function()
		{
			genericEventButton(function(event:EventMetaNote)
			{
				var _useEase:Bool = (easeDropDown != null && easeDropDown.visible);
			var val2Push:String = _useEase ? (valueInputTexts[2].text.trim().length > 0 ? valueInputTexts[1].text + ', ' + valueInputTexts[2].text.trim() : valueInputTexts[1].text) : valueInputTexts[1].text;
			var _evData:Array<String> = [eventsList[Std.int(Math.max(eventDropDown.selectedIndex, 0))][0], valueInputTexts[0].text, val2Push, _useEase ? '' : valueInputTexts[2].text];
			for(_i in 3...valueInputTexts.length) _evData.push(valueInputTexts[_i].text);
			event.events.push(_evData);
				event.updateEventText();
				curEventSelected++;
			});
		}, 20);
		var leftButton:PsychUIButton = new PsychUIButton(objX2 + 80, objY, '<', function()
		{
			genericEventButton(function(event:EventMetaNote) curEventSelected = FlxMath.wrap(curEventSelected - 1, 0, event.events.length - 1));
		}, 20);
		var rightButton:PsychUIButton = new PsychUIButton(objX2 + 110, objY, '>', function()
		{
			genericEventButton(function(event:EventMetaNote) curEventSelected = FlxMath.wrap(curEventSelected + 1, 0, event.events.length - 1));
		}, 20);
		removeButton.normalStyle.bgColor = FlxColor.RED;
		removeButton.normalStyle.textColor = FlxColor.WHITE;
		addButton.normalStyle.bgColor = FlxColor.GREEN;
		addButton.normalStyle.textColor = FlxColor.WHITE;

		selectedEventText = new FlxText(150, objY + 30, 150, '');
		selectedEventText.visible = false;

		function changeEventsValue(str:String, n:Int)
		{
			if(selectedNotes.length > 1)
			{
				for (note in selectedNotes)
				{
					if(note == null || !note.isEvent) continue;

					var event:EventMetaNote = cast (note, EventMetaNote);
					event.events[event.events.length - 1][n] = str;
					event.updateEventText();
				}
			}
			else if(selectedNotes.length == 1 && selectedNotes[0].isEvent)
			{
				var event:EventMetaNote = cast (selectedNotes[0], EventMetaNote);
				event.events[Std.int(FlxMath.bound(curEventSelected, 0, event.events.length - 1))][n] = str;
				event.updateEventText();
			}
		}

		objY += 70;
		for(i in 0...MAX_EVENT_VALUES)
		{
			var inp:PsychUIInputText = new PsychUIInputText(objX + (i % 2 == 0 ? 0 : 150), objY + Std.int(i / 2) * 40, 120, '', 8);
			var idx:Int = i;
			inp.onChange = function(old:String, cur:String)
			{
				if(idx == 1 && easeDropDown != null && easeDropDown.visible)
				{
					var ease:String = valueInputTexts[2].text.trim();
					var combined:String = ease.length > 0 ? (cur.length > 0 ? cur + ', ' + ease : ease) : cur;
					changeEventsValue(combined, 2);
				}
				else if(idx == 2)
				{
					if(easeDropDown == null || !easeDropDown.visible)
						changeEventsValue(cur, idx + 1);
				}
				else
					changeEventsValue(cur, idx + 1);
			};
			valueInputTexts.push(inp);
		}
		objY += Std.int(MAX_EVENT_VALUES / 2) * 40;
		eventDescriptionText = new FlxText(objX, objY, 280, defaultEvents[0][1]);

		var easeList:Array<String> = [
			'',
			'instant',
			'linear',
			'back', 'bounce', 'circ', 'cube', 'elastic', 'expo',
			'quad', 'quart', 'quint', 'sine', 'smoothStep', 'smootherStep'
		];
		easeDropDown = new PsychUIDropDownMenu(valueInputTexts[2].x, valueInputTexts[2].y, easeList, function(id:Int, base:String)
		{
			var noDir:Bool = (base == '' || base == 'instant' || base == 'linear');
			var dir:String = (easeInOutDropDown != null && !noDir) ? easeInOutDropDown.selectedLabel : '';
			var ease:String = noDir ? base : base + dir;
			valueInputTexts[2].text = ease;
			if(easeInOutDropDown != null)
			{
				easeInOutDropDown.list = noDir ? [''] : ['In', 'Out', 'InOut'];
				var validDir:String = (dir == 'In' || dir == 'Out' || dir == 'InOut') ? dir : 'In';
				easeInOutDropDown.selectedLabel = noDir ? '' : validDir;
				easeInOutDropDown.showDropDown(false);
			}
			if(easeDropDown != null && easeDropDown.visible)
			{
				var seconds:String = valueInputTexts[1].text.trim();
				var combined:String = ease.length > 0 ? (seconds.length > 0 ? seconds + ', ' + ease : ease) : seconds;
				changeEventsValue(combined, 2);
				changeEventsValue('', 3);
			}
		}, 100);
		easeDropDown.selectedLabel = '';
		easeDropDown.visible = easeDropDown.active = false;

		easeInOutDropDown = new PsychUIDropDownMenu(valueInputTexts[3].x, valueInputTexts[3].y, ['In', 'Out', 'InOut'], function(id:Int, dir:String)
		{
			var base:String = (easeDropDown != null) ? easeDropDown.selectedLabel : '';
			var noDir:Bool = (base == '' || base == 'instant' || base == 'linear');
			var ease:String = noDir ? base : base + dir;
			valueInputTexts[2].text = ease;
			if(easeInOutDropDown != null && easeInOutDropDown.visible)
			{
				var seconds:String = valueInputTexts[1].text.trim();
				var combined:String = ease.length > 0 ? (seconds.length > 0 ? seconds + ', ' + ease : ease) : seconds;
				changeEventsValue(combined, 2);
				changeEventsValue('', 3);
			}
		}, 100);
		easeInOutDropDown.autoSort = false;
		easeInOutDropDown.selectedLabel = 'In';
		easeInOutDropDown.visible = easeInOutDropDown.active = false;

		for(i in 0...MAX_EVENT_VALUES)
		{
			var lbl:FlxText = new FlxText(valueInputTexts[i].x, valueInputTexts[i].y - 15, 80, 'Value ${i + 1}:');
			lbl.visible = false;
			valueLabels.push(lbl);
		}

		tab_group.add(new FlxText(eventDropDown.x, eventDropDown.y - 15, 80, 'Event:'));
		tab_group.add(new FlxText(eventDropDown.x, eventDropDown.y - 15, 80, 'Event:'));
		for(lbl in valueLabels) tab_group.add(lbl);

		tab_group.add(removeButton);
		tab_group.add(addButton);
		tab_group.add(leftButton);
		tab_group.add(rightButton);
		tab_group.add(selectedEventText);

		for(inp in valueInputTexts) tab_group.add(inp);
		tab_group.add(eventDescriptionText);
		tab_group.add(easeDropDown);
		easeInOutLabel = new FlxText(easeInOutDropDown.x, easeInOutDropDown.y - 15, 80, 'Direction:');
		easeInOutLabel.visible = false;
		tab_group.add(easeInOutLabel);
		tab_group.add(easeInOutDropDown);

		tab_group.add(eventDropDown); //lowest priority to display properly

		updateEventSpecialUI('');
	}

	var susLengthLastVal:Float = 0; //used for multiple notes selected
	var susLengthStepper:PsychUINumericStepper;
	var strumTimeStepper:PsychUINumericStepper;
	var noteTypeDropDown:PsychUIDropDownMenu;
	var altAnimInputText:PsychUIInputText;
	var altAnimDescText:FlxText;
	var altAnimLabelText:FlxText;
	var noteTypes:Array<String>;
	function addNoteTab()
	{
		var tab_group = mainBox.getTab('Note').menu;
		var objX = 10;
		var objY = 25;

		susLengthStepper = new PsychUINumericStepper(objX, objY, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 128, 1, 80);
		susLengthStepper.onValueChange = function()
		{
			var halfStep:Float = (Conductor.stepCrochet / 2);
			var val:Float = Math.round(susLengthStepper.value / halfStep) * halfStep;
			susLengthStepper.value = val;
			if(susLengthLastVal != susLengthStepper.value)
			{
				if(selectedNotes.length > 1)
				{
					for (note in selectedNotes)
					{
						if(note == null || note.isEvent) continue;
						note.setSustainLength(note.sustainLength + (susLengthStepper.value - susLengthLastVal), Conductor.stepCrochet, curZoom);
					}
				}
				else if(selectedNotes.length == 1) selectedNotes[0].setSustainLength(susLengthStepper.value, Conductor.stepCrochet, curZoom);
				susLengthLastVal = susLengthStepper.value;
			}
		};

		objY += 40;
		strumTimeStepper = new PsychUINumericStepper(objX, objY, Conductor.stepCrochet, 0, -5000, Math.POSITIVE_INFINITY, 3, 120);
		strumTimeStepper.onValueChange = function()
		{
			if(selectedNotes.length < 1) return;

			var firstTime:Float = selectedNotes[0].strumTime;
			for (note in selectedNotes)
			{
				if(note == null) continue;

				note.setStrumTime(Math.max(-5000, strumTimeStepper.value + (note.strumTime - firstTime)));
				positionNoteYOnTime(note, curSec);

				if(note.isEvent)
				{
					cast (note, EventMetaNote).updateEventText();
				}
			}
			softReloadNotes();
		};
		
		objY += 40;
		noteTypeDropDown = new PsychUIDropDownMenu(objX, objY, [], function(id:Int, changeToType:String)
		{
			var newSelected:Array<MetaNote> = [];
			var typeSelected:String = noteTypes[id].trim();
			for (note in selectedNotes)
			{
				if(note == null || note.isEvent) continue;

				if(typeSelected != null && typeSelected.length > 0)
				{
					note.songData[3] = typeSelected;
						if(typeSelected == 'Alt Animation')
					{
						if(note.songData.length <= 4)
							note.songData.push('');
					}
					else if(note.songData.length > 4)
						note.songData.remove(note.songData[4]);
				}
				else
				{
					note.songData.remove(note.songData[3]);
					if(note.songData.length > 4)
						note.songData.remove(note.songData[4]);
				}

				var id:Int = notes.indexOf(note);
				if(id > -1)
				{
					notes[id] = createNote(note.songData, curSec);
					actionReplaceNotes(note, notes[id]);
					newSelected.push(notes[id]);
					note.destroy();
				}
			}
			selectedNotes = newSelected;
			softReloadNotes();
			
			altAnimInputText.visible = altAnimDescText.visible = altAnimLabelText.visible = (typeSelected == 'Alt Animation');
			if(typeSelected == 'Alt Animation')
				altAnimInputText.text = '';
		}, 150);
		
		tab_group.add(new FlxText(susLengthStepper.x, susLengthStepper.y - 15, 80, 'Sustain length:'));
		tab_group.add(new FlxText(strumTimeStepper.x, strumTimeStepper.y - 15, 100, 'Note Hit time (ms):'));
		tab_group.add(new FlxText(noteTypeDropDown.x, noteTypeDropDown.y - 15, 80, 'Note Type:'));
		tab_group.add(susLengthStepper);
		tab_group.add(strumTimeStepper);

		objY += 40;
		altAnimInputText = new PsychUIInputText(objX, objY, 150, '', 8);
		altAnimInputText.onChange = function(old:String, cur:String)
		{
			for (note in selectedNotes)
			{
				if(note == null || note.isEvent) continue;
				if(note.noteType != 'Alt Animation') continue;
				
				note.animSuffix = cur.trim();
				note.songData[4] = cur.trim();
			}
		};
		altAnimInputText.visible = false;
		
		altAnimDescText = new FlxText(objX, objY + 25, 280, 'Select the JSON prefix for more ALT SPRITES\nFor example: -ALTSIGMA');
		altAnimDescText.visible = false;
		
		altAnimLabelText = new FlxText(altAnimInputText.x, altAnimInputText.y - 15, 150, 'Alt Animation Suffix:');
		altAnimLabelText.visible = false;
		
		tab_group.add(altAnimLabelText);
		tab_group.add(altAnimInputText);
		tab_group.add(altAnimDescText);
	
		tab_group.add(noteTypeDropDown);
	}

	var mustHitDropDown:PsychUIDropDownMenu;
	var altAnimSectionCheckBox:PsychUICheckBox;

	var changeBpmCheckBox:PsychUICheckBox;
	var changeBpmStepper:PsychUINumericStepper;
	var beatsPerSecStepper:PsychUINumericStepper;

	function addSectionTab()
	{
		var affectNotes:PsychUICheckBox = null;
		var affectEvents:PsychUICheckBox = null;
		var copyLastSecStepper:PsychUINumericStepper = null;
		var tab_group = mainBox.getTab('Section').menu;
		var objX = 10;
		var objY = 10;
		function copyNotesOnSection(?secOff:Int = 0, ?showMessage:Bool = true) //Used on "Copy Section" and "Copy Last Section" buttons
		{
			var curSectionTime:Null<Float> = cachedSectionTimes[curSec - secOff];
			if(curSectionTime == null)
			{
				//showOutput('ERROR: Unknown section??', true);
				return;
			}

			var nextSectionTime:Null<Float> = cachedSectionTimes[curSec - secOff + 1];
			if(nextSectionTime == null) Math.POSITIVE_INFINITY;

			var notesCopyNum:Int = 0;
			if(affectNotes.checked)
			{
				copiedNotes = [];
				for (note in notes)
				{
					if(note.strumTime >= curSectionTime && note.strumTime < nextSectionTime)
					{
						var dataCopy:Array<Dynamic> = makeNoteDataCopy(note.songData, false);
						dataCopy[0] = note.strumTime - curSectionTime;
						copiedNotes.push(dataCopy);
						notesCopyNum++;
					}
				}
			}

			var eventsCopyNum:Int = 0;
			if(affectEvents.checked)
			{
				copiedEvents = [];
				for (event in events)
				{
					if(event.strumTime >= curSectionTime && event.strumTime < nextSectionTime)
					{
						var dataCopy:Array<Dynamic> = makeNoteDataCopy(event.songData, true);
						dataCopy[0] = event.strumTime - curSectionTime;
						copiedEvents.push(dataCopy);
						eventsCopyNum++;
					}
				}
			}

			if(showMessage)
			{
				if(notesCopyNum == 0 && eventsCopyNum == 0)
				{
					showOutput('Nothing to copy!', true);
					return;
				}

				var str:String = '';
				if(notesCopyNum > 0) str += 'Notes Copied: $notesCopyNum';
				if(eventsCopyNum > 0)
				{
					if(str.length > 0) str += '\n';
					str += 'Events Copied: $eventsCopyNum';
				}
	
				if(str.length > 0) showOutput(str);
			}
		}

		var mustHitOptions:Array<String> = ['Dad', 'BF', 'GF', 'GF (Player)'];
		if (PlayState.SONG.extraStrumlines != null)
			for (i in 0...PlayState.SONG.extraStrumlines.length)
				mustHitOptions.push('Strumline #${i + 3}');

		var mustHitLabel:FlxText = new FlxText(objX, objY, 100, 'Must Hit Section:');
		mustHitLabel.cameras = cameras;
		tab_group.add(mustHitLabel);

		objY += 15;
		mustHitDropDown = new PsychUIDropDownMenu(objX, objY, mustHitOptions, function(id:Int, val:String)
		{
			var sec = getCurChartSection();
			if (sec == null) return;
			sec.mustHitTarget = val;
			sec.mustHitSection = (val == 'BF' || val == 'GF (Player)');
			sec.gfSection = (val == 'GF' || val == 'GF (Player)');
			updateHeads(true);
		});
		mustHitDropDown.cameras = cameras;

		altAnimSectionCheckBox = new PsychUICheckBox(objX + 150, objY, 'Alt Anim', 70, function()
		{
			var sec = getCurChartSection();
			if(sec != null) sec.altAnim = altAnimSectionCheckBox.checked;
		});

		objY += 40;
		changeBpmCheckBox = new PsychUICheckBox(objX, objY, 'Change BPM', 80, function()
		{
			var sec = getCurChartSection();
			if(sec != null)
			{
				var oldTimes:Array<Float> = cachedSectionTimes.copy();
				sec.changeBPM = changeBpmCheckBox.checked;
				if(!Reflect.hasField(sec, 'bpm')) sec.bpm = changeBpmStepper.value;
				adaptNotesToNewTimes(oldTimes);
			}
		});

		objY += 25;
		changeBpmStepper = new PsychUINumericStepper(objX, objY, 0.001, 0, 1, 400, 3);
		changeBpmStepper.onValueChange = function()
		{
			var sec = getCurChartSection();
			if(sec != null)
			{
				var oldTimes:Array<Float> = cachedSectionTimes.copy();
				sec.bpm = changeBpmStepper.value;
				sec.changeBPM = true;
				changeBpmCheckBox.checked = true;
				adaptNotesToNewTimes(oldTimes);
			}
		};

		beatsPerSecStepper = new PsychUINumericStepper(objX + 150, objY, 1, 4, 1, 16, 2);
		beatsPerSecStepper.onValueChange = function()
		{
			beatsPerSecStepper.value = Math.round(beatsPerSecStepper.value * 4) / 4;
			var sec = getCurChartSection();
			if(sec != null)
			{
				var oldTimes:Array<Float> = cachedSectionTimes.copy();
				sec.sectionBeats = beatsPerSecStepper.value;
				adaptNotesToNewTimes(oldTimes);
			}
		};

		objY += 40;
		var copyButton:PsychUIButton = new PsychUIButton(objX, objY, 'Copy Section', copyNotesOnSection.bind());
		var pasteButton:PsychUIButton = new PsychUIButton(objX + 100, objY, 'Paste Section', function()
		{
			pasteCopiedNotesToSection(affectNotes.checked, affectEvents.checked);
		});
		var clearButton:PsychUIButton = new PsychUIButton(objX + 200, objY, 'Clear', function()
		{
			for (note in curRenderedNotes)
			{
				if(note == null) continue;

				if(!note.isEvent && affectNotes.checked)
					notes.remove(note);
				if(note.isEvent && affectEvents.checked)
					events.remove(cast (note, EventMetaNote));

				selectedNotes.remove(note);
			}
			softReloadNotes(true);
		});
		clearButton.normalStyle.bgColor = FlxColor.RED;
		clearButton.normalStyle.textColor = FlxColor.WHITE;

		objY += 25;
		affectNotes = new PsychUICheckBox(objX, objY, 'Notes', 60);
		affectNotes.checked = true;
		affectEvents = new PsychUICheckBox(objX + 100, objY, 'Events', 60);

		objY += 32;
		var copyLastSecButton:PsychUIButton = new PsychUIButton(objX, objY, 'Copy Last Section', function()
		{
			var lastCopiedNotes = copiedNotes;
			var lastCopiedEvents = copiedEvents;
			copyNotesOnSection(Std.int(copyLastSecStepper.value), false);
			pasteCopiedNotesToSection(affectNotes.checked, affectEvents.checked);
			copiedNotes = lastCopiedNotes;
			copiedEvents = lastCopiedEvents;
		});
		copyLastSecButton.resize(80, 26);
		copyLastSecStepper = new PsychUINumericStepper(objX + 110, objY + 2, 1, 1, -999, 999, 0);
		
		objY += 40;
		var swapSectionButton:PsychUIButton = new PsychUIButton(objX, objY, 'Swap Section', function()
		{
			var maxData:Int = GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS;
			for (note in curRenderedNotes)
			{
				if(note != null && !note.isEvent)
				{
					var data:Int = note.songData[1] + GRID_COLUMNS_PER_PLAYER;
					if(data >= maxData) data -= maxData;
					note.changeNoteData(data);
					positionNoteXByData(note);
				}
			}
			softReloadNotes(true);
		});
		var duetSectionButton:PsychUIButton = new PsychUIButton(objX + 100, objY, 'Duet Section', function()
		{
			var side:Int = -1;
			for (note in curRenderedNotes.members)
			{
				if(note == null || note.isEvent) continue;

				//First figure out if there are notes on more than one player's sides to cancel operation early
				if(side > -1)
				{
					if(Math.floor(note.songData[1] / GRID_COLUMNS_PER_PLAYER) != side)
					{
						showOutput('You cannot press this button with notes on more than one side.');
						return;
					}
				}
				else side = Math.floor(note.songData[1] / GRID_COLUMNS_PER_PLAYER);
			}

			var pushedNotes:Array<MetaNote> = [];
			for (note in curRenderedNotes.members)
			{
				if(note == null || note.isEvent) continue;

				for (i in 0...GRID_PLAYERS)
				{
					if(i == side) continue;

					var songDataCopy:Array<Dynamic> = note.songData.copy();
					songDataCopy[1] = note.noteData + i * GRID_COLUMNS_PER_PLAYER;
					var newNote = createNote(songDataCopy);
					notes.push(newNote);
					pushedNotes.push(newNote);
				}
			}
			notes.sort(PlayState.sortByTime);
			softReloadNotes(true);
			
			addUndoAction(ADD_NOTE, {notes: pushedNotes});
		});
		var mirrorNotesButton:PsychUIButton = new PsychUIButton(objX + 200, objY, 'Mirror Notes', function()
		{
			var maxData:Int = GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS;
			for (note in curRenderedNotes)
			{
				if(note == null || note.isEvent) continue;

				var data:Int = Std.int(note.songData[1]);
				note.changeNoteData((Math.floor(data / GRID_COLUMNS_PER_PLAYER) * GRID_COLUMNS_PER_PLAYER) + GRID_COLUMNS_PER_PLAYER - note.noteData - 1);
				positionNoteXByData(note);
			}
			softReloadNotes(true);
		});

		tab_group.add(mustHitDropDown);
		tab_group.add(altAnimSectionCheckBox);

		tab_group.add(new FlxText(beatsPerSecStepper.x, beatsPerSecStepper.y - 15, 100, 'Beats per Section:'));
		tab_group.add(changeBpmCheckBox);
		tab_group.add(changeBpmStepper);
		tab_group.add(beatsPerSecStepper);
		
		tab_group.add(copyButton);
		tab_group.add(pasteButton);
		tab_group.add(clearButton);
		tab_group.add(affectNotes);
		tab_group.add(affectEvents);

		tab_group.add(copyLastSecButton);
		tab_group.add(copyLastSecStepper);

		tab_group.add(swapSectionButton);
		tab_group.add(duetSectionButton);
		tab_group.add(mirrorNotesButton);
	}

	function detectEventValues(eventName:String):Array<String>
	{
		var content:String = null;
		#if LUA_ALLOWED
		if(content == null)
		{
			var luaPath:String = Paths.getTextFromFile('custom_events/$eventName.lua');
			if(luaPath != null && luaPath.length > 0) content = luaPath;
		}
		#end
		#if HSCRIPT_ALLOWED
		if(content == null)
		{
			var hxPath:String = Paths.getTextFromFile('custom_events/$eventName.hx');
			if(hxPath != null && hxPath.length > 0) content = hxPath;
		}
		#end
		if(content == null) return ['1', '2'];

		var stripped:String = '';
		var lines:Array<String> = content.split('\n');
		for (line in lines)
		{
			var singleComment:Int = -1;
			var inString:Bool = false;
			var strChar:String = '';
			var i:Int = 0;
			while(i < line.length)
			{
				var c:String = line.charAt(i);
				if(inString)
				{
					if(c == strChar) inString = false;
				}
				else if(c == '"' || c == "'")
				{
					inString = true;
					strChar = c;
				}
				else if(line.substr(i, 2) == '--' || line.substr(i, 2) == '//')
				{
					singleComment = i;
					break;
				}
				i++;
			}
			stripped += (singleComment >= 0 ? line.substr(0, singleComment) : line) + '\n';
		}

		var blockCommentRegex:EReg = ~/\/\*[\s\S]*?\*\//g;
		stripped = blockCommentRegex.replace(stripped, '');

		var result:Array<String> = [];
		for(n in 1...MAX_EVENT_VALUES + 1)
		{
			var r:EReg = new EReg('value$n', 'i');
			if(r.match(stripped)) result.push(Std.string(n));
		}

		var sigRegex:EReg = ~/function\s+onEvent\s*\(([^)]*)\)/i;
		if(sigRegex.match(stripped))
		{
			var rawParams:Array<String> = sigRegex.matched(1).split(',');
			var isDefaultName:EReg = ~/^value\d+$/i;

			if(result.length == 0)
			{
				var valueCounter:Int = 1;
				for(pi in 1...rawParams.length)
				{
					if(pi == 3) continue;
					var paramName:String = rawParams[pi].trim();
					if(paramName.length == 0) break;
					if(isDefaultName.match(paramName))
						result.push(Std.string(valueCounter));
					else
						result.push('$valueCounter:$paramName');
					valueCounter++;
				}
			}
			else
			{
				for(ri in 0...result.length)
				{
					var valueIdx:Int = Std.parseInt(result[ri].split(':')[0]);
					if(valueIdx < 1) continue;
					var paramPos:Int = (valueIdx <= 2) ? valueIdx : valueIdx + 1;
					if(paramPos < rawParams.length)
					{
						var paramName:String = rawParams[paramPos].trim();
						if(paramName.length > 0 && !isDefaultName.match(paramName))
							result[ri] = '$valueIdx:$paramName';
					}
				}
			}
		}

		return result.length > 0 ? result : ['1', '2'];
	}

	function reloadNotesDropdowns()
	{
		// Event drop down
		if(eventDropDown != null)
		{
			eventsList = [];
			var eventFiles:Array<String> = loadFileList('custom_events/', ['.txt']);
			for (file in eventFiles)
			{
				var desc:String = Paths.getTextFromFile('custom_events/$file.txt');
				var detectedVals:Array<String> = detectEventValues(file);
				eventsList.push([file, desc, detectedVals.join(',')]);
			}

			for (id => event in defaultEvents)
				if(!eventsList.contains(event))
					eventsList.insert(id, event);
			
			var eventsSlice:Array<Array<String>> = eventsList.slice(1);
			eventsSlice.sort((a, b) -> a[0].toLowerCase() < b[0].toLowerCase() ? -1 : 1);
			for (i in 0...eventsSlice.length)
				eventsList[i + 1] = eventsSlice[i];
			
			var displayEventsList:Array<String> = [];
			for (id => data in eventsList)
			{
				if(id > 0)
					displayEventsList[id] = '$id. ${data[0]}';
				else
					displayEventsList.push('');
			}

			var lastSelected:String = eventDropDown.selectedLabel;
			eventDropDown.list = displayEventsList;
			eventDropDown.selectedLabel = lastSelected;
		}

		// Note type drop down
		if(noteTypeDropDown != null)
		{
			var exts:Array<String> = ['.txt'];
			#if LUA_ALLOWED exts.push('.lua'); #end
			#if HSCRIPT_ALLOWED exts.push('.hx'); #end
			noteTypes = loadFileList('custom_notetypes/', exts);
			
			var defaultTypes:Array<String> = ['', 'Alt Animation', 'Hey!', 'Hurt Note', 'GF Sing', 'Opponent Sing', 'No Animation', 'GF + BF Note', 'Opponent + GF Note', 'Boyfriend SING', 'Opponent + BF + GF'];
			for (id => noteType in defaultTypes)
				if(!noteTypes.contains(noteType))
					noteTypes.insert(id, noteType);

			if(Song.chartPath != null && Song.chartPath.length > 0)
			{
				var parentFolder:String = Song.chartPath.replace('\\', '/');
				parentFolder = parentFolder.substr(0, parentFolder.lastIndexOf('/') + 1);
				var notetypeFile:Array<String> = CoolUtil.coolTextFile(parentFolder + 'notetypes.txt');
				if(notetypeFile.length < 1)
				{
					var upFolder:String = parentFolder.substr(0, parentFolder.length - 1);
					upFolder = upFolder.substr(0, upFolder.lastIndexOf('/') + 1);
					notetypeFile = CoolUtil.coolTextFile(upFolder + 'notetypes.txt');
				}
				if(notetypeFile.length > 0)
				{
					for (ntTyp in notetypeFile)
					{
						var name:String = ntTyp.trim();
						if(!noteTypes.contains(name))
							noteTypes.push(name);
					}
				}
			}
			
			var displayNoteTypes:Array<String> = noteTypes.copy();
			for (id => key in displayNoteTypes)
			{
				if(id == 0) continue;
				displayNoteTypes[id] = '$id. $key';
			}
			
			var lastSelected:String = noteTypeDropDown.selectedLabel;
			noteTypeDropDown.list = displayNoteTypes;
			noteTypeDropDown.selectedLabel = lastSelected;
		}
	}

	function pasteCopiedNotesToSection(?canCopyNotes:Bool = true, ?canCopyEvents:Bool = true, ?showMessage:Bool = true) //Used on "Paste Section" and "Copy Last Section" buttons
	{
		var curSectionTime:Null<Float> = cachedSectionTimes[curSec];
		if(curSectionTime == null)
		{
			showOutput('ERROR: Unknown section??', true);
			return [];
		}

		var pushedNotes:Array<MetaNote> = [];
		var nts:Array<MetaNote> = [];
		var evs:Array<EventMetaNote> = [];
		if(canCopyNotes && copiedNotes.length > 0)
		{
			for (note in copiedNotes)
			{
				if(note == null) continue;
				var dataCopy:Array<Dynamic> = makeNoteDataCopy(note, false);
				dataCopy[0] += curSectionTime;

				var createdNote = createNote(dataCopy, curSec);
				notes.push(createdNote);
				pushedNotes.push(createdNote);
				nts.push(createdNote);
			}
			notes.sort(PlayState.sortByTime);
		}

		if(canCopyEvents && copiedEvents.length > 0)
		{
			for (event in copiedEvents)
			{
				if(event == null) continue;
				var dataCopy:Array<Dynamic> = makeNoteDataCopy(event, true);
				dataCopy[0] += curSectionTime;

				var createdEvent = createEvent(dataCopy);
				events.push(createdEvent);
				pushedNotes.push(createdEvent);
				evs.push(createdEvent);
			}
			events.sort(PlayState.sortByTime);
		}
		loadSection();
		
		if(showMessage)
		{
			if(nts.length == 0 && evs.length == 0)
			{
				showOutput('Nothing to paste!', true);
				return [];
			}

			var str:String = '';
			if(nts.length > 0) str += 'Notes Added: ${nts.length}';
			if(evs.length > 0)
			{
				if(str.length > 0) str += '\n';
				str += 'Events Added: ${evs.length}';
			}

			if(str.length > 0) showOutput(str);
		}
		addUndoAction(ADD_NOTE, {notes: nts, events: evs});
		return pushedNotes;
	}

	var songNameInputText:PsychUIInputText;
	var allowVocalsCheckBox:PsychUICheckBox;

	var bpmStepper:PsychUINumericStepper;
	var scrollSpeedStepper:PsychUINumericStepper;
	var audioOffsetStepper:PsychUINumericStepper;
	var strumlineConfigs:Array<StrumlineConfigData> = [];
	var strumsStepper:PsychUINumericStepper;

	var characterList:Array<String> = [];
	var stageDropDown:PsychUIDropDownMenu;
	var playerDropDown:PsychUIDropDownMenu;
	var opponentDropDown:PsychUIDropDownMenu;
	var girlfriendDropDown:PsychUIDropDownMenu;
	
	function addSongTab()
	{
		var tab_group = mainBox.getTab('Song').menu;
		var objX = 10;
		var objY = 25;

		songNameInputText = new PsychUIInputText(objX, objY, 160, 'None', 8);
		songNameInputText.onChange = function(old:String, cur:String) PlayState.SONG.song = cur;

		var reloadAudioButton:PsychUIButton = new PsychUIButton(objX + 170, objY, 'Reload Audio', function() loadMusic(true), 100);
		reloadAudioButton.resize(100, Std.int(songNameInputText.height));

		#if mac
		var reloadJsonButton:PsychUIButton = new PsychUIButton(objX + 205, objY, 'Reload JSON', function()
		{
			var cur = Paths.formatToSongPath(songNameInputText.text);
			var curdiff = Highscore.formatSong(cur, PlayState.storyDifficulty);
			var diff = false;
			var loadedChart:SwagSong = try {
				diff = true;
				Song.getChart(curdiff, cur);
			} catch (e) {
				diff = false;
				Song.getChart(cur, cur);
			}
			if(loadedChart == null || !Reflect.hasField(loadedChart, 'song'))
			{
				showOutput('Error: File loaded is not a Psych Engine/FNF 0.2.x.x chart.', true);
				return;
			}

			var func:Void->Void = function()
			{
				loadChart(loadedChart);
				Song.chartPath = diff ? curdiff : cur;
				reloadNotesDropdowns();
				prepareReload();
				showOutput('Opened chart "${diff ? curdiff : cur}" successfully!');
			}

			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning!\nAny unsaved progress will be lost.', func));
			else func();
		}, 80);
		#end

		objY += 20;
		allowVocalsCheckBox = new PsychUICheckBox(objX, objY, 'Allow Vocals', 80, function()
		{
			PlayState.SONG.needsVoices = allowVocalsCheckBox.checked;
			loadMusic();
		});

		objY += 35;
		bpmStepper = new PsychUINumericStepper(objX, objY, 0.001, 1, 1, 400, 3);
		bpmStepper.onValueChange = function()
		{
			var oldTimes:Array<Float> = cachedSectionTimes.copy();
			PlayState.SONG.bpm = bpmStepper.value;
			adaptNotesToNewTimes(oldTimes);
		};

		scrollSpeedStepper = new PsychUINumericStepper(objX + 90, objY, 0.1, 1, 0.1, 10, 2);
		scrollSpeedStepper.onValueChange = function() PlayState.SONG.speed = scrollSpeedStepper.value;

		audioOffsetStepper = new PsychUINumericStepper(objX + 180, objY, 1, 0, -500, 500, 0);
		audioOffsetStepper.onValueChange = function()
		{
			PlayState.SONG.offset = audioOffsetStepper.value;
			Conductor.offset = audioOffsetStepper.value;
			updateWaveform();
		};

		if(ALLOW_EXTRA_STRUMS) objY += 35;
		strumsStepper = new PsychUINumericStepper(objX, objY, 1, 2, 1, 10, 0);
		strumsStepper.onValueChange = function()
		{
			var newValue:Int = Std.int(strumsStepper.value);
			if(newValue > GRID_PLAYERS)
			{
				var extraNeeded:Int = Std.int(Math.max(0, newValue - 2));
				if(extraNeeded > strumlineConfigs.length)
				{
					openSubState(new CreateStrumlinePrompt(newValue, function(data:StrumlineConfigData)
					{
						strumlineConfigs.push(data);
						GRID_PLAYERS = newValue;
						updateChartData();
						rebuildGridPlayers();
					}, function()
					{
						strumsStepper.value = GRID_PLAYERS;
					}, characterList));
				}
				else
				{
					GRID_PLAYERS = newValue;
					updateChartData();
					rebuildGridPlayers();
				}
			}
			else if(newValue < GRID_PLAYERS)
			{
				var oldValue:Int = GRID_PLAYERS;
				var removeFunc:Void->Void = function()
				{
					var extraNeeded:Int = Std.int(Math.max(0, newValue - 2));
					if(extraNeeded < strumlineConfigs.length)
						strumlineConfigs.resize(extraNeeded);

					var maxColumn:Int = GRID_COLUMNS_PER_PLAYER * newValue;
					for (section in PlayState.SONG.notes)
						section.sectionNotes = section.sectionNotes.filter(function(n) return Std.int(n[1]) < maxColumn);

					for (note in notes.copy())
					{
						if(note == null) continue;
						if(Std.int(note.songData[1]) >= maxColumn)
						{
							note.destroy();
							notes.remove(note);
						}
					}

					GRID_PLAYERS = newValue;
					rebuildGridPlayers();
					updateChartData();
				}

				openSubState(new Prompt('Are you sure you want to delete this strumline?\nAny notes on it will be lost.', removeFunc, function()
				{
					strumsStepper.value = oldValue;
				}));
			}
		};

		var editStrumsButton:PsychUIButton = new PsychUIButton(objX + 75, objY, 'Edit Strums', function()
		{
			if(strumlineConfigs.length < 1) return;
			openSubState(new CreateStrumlinePrompt(0, null, null, characterList, strumlineConfigs, function(newConfigs:Array<StrumlineConfigData>)
			{
				strumlineConfigs = newConfigs;
				updateChartData();
				updateJsonData();
				updateHeads(true);
			}));
		}, 100);
		editStrumsButton.resize(100, Std.int(strumsStepper.height));

		objY += 40;
		playerDropDown = new PsychUIDropDownMenu(objX, objY, [''], function(id:Int, character:String)
		{
			if (GRID_PLAYERS == 1 && character == 'dad')
			{
				PlayState.SONG.player1 = 'bf';
				playerDropDown.selectedLabel = 'bf';
			}
			else
				PlayState.SONG.player1 = character;
			updateJsonData();
			updateHeads(true);
			loadMusic();
			trace('selected $character');
		});
		opponentDropDown = new PsychUIDropDownMenu(objX + 140, objY, [''], function(id:Int, character:String)
		{
			PlayState.SONG.player2 = character;
			updateJsonData();
			updateHeads(true);
			loadMusic();
			trace('selected $character');
		});

		objY += 40;
		girlfriendDropDown = new PsychUIDropDownMenu(objX, objY, [''], function(id:Int, character:String)
		{
			PlayState.SONG.gfVersion = character;
			trace('selected $character');
		});
		stageDropDown = new PsychUIDropDownMenu(objX + 140, objY, [''], function(id:Int, stage:String)
		{
			PlayState.SONG.stage = stage;
			StageData.loadDirectory(PlayState.SONG);
			trace('selected $stage');
		});

		tab_group.add(new FlxText(songNameInputText.x, songNameInputText.y - 15, 80, 'Song Name:'));
		tab_group.add(songNameInputText);
		tab_group.add(reloadAudioButton);
		#if mac
		tab_group.add(reloadJsonButton);
		#end
		tab_group.add(allowVocalsCheckBox);

		tab_group.add(new FlxText(bpmStepper.x, bpmStepper.y - 15, 50, 'BPM:'));
		tab_group.add(new FlxText(scrollSpeedStepper.x, scrollSpeedStepper.y - 15, 80, 'Scroll Speed:'));
		tab_group.add(new FlxText(audioOffsetStepper.x, audioOffsetStepper.y - 15, 100, 'Audio Offset (ms):'));
		tab_group.add(bpmStepper);
		tab_group.add(scrollSpeedStepper);
		tab_group.add(audioOffsetStepper);

		if(ALLOW_EXTRA_STRUMS)
		{
			tab_group.add(new FlxText(strumsStepper.x, strumsStepper.y - 15, 60, 'Strums:'));
			tab_group.add(strumsStepper);
			tab_group.add(editStrumsButton);
		}

		tab_group.add(new FlxText(playerDropDown.x, playerDropDown.y - 15, 80, 'Player:'));
		tab_group.add(new FlxText(opponentDropDown.x, opponentDropDown.y - 15, 80, 'Opponent:'));
		tab_group.add(new FlxText(girlfriendDropDown.x, girlfriendDropDown.y - 15, 80, 'Girlfriend:'));
		tab_group.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 80, 'Stage:'));
		tab_group.add(girlfriendDropDown);
		tab_group.add(stageDropDown);
		tab_group.add(playerDropDown);
		tab_group.add(opponentDropDown);
	}

	function addFileTab()
	{
		var tab = upperBox.getTab('File');
		var tab_group = tab.menu;
		var btnX = 0;
		var btnY = 0;
		var btnWid = 150;

		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  New', function()
		{
			var func:Void->Void = function()
			{
				openNewChart();
				reloadNotesDropdowns();
				prepareReload();
			}

			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Are you sure you want to start over?', func));
			else func();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Open Chart...', function()
		{
			openChartDialog();
		}, btnWid);

		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Open Autosave...', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			if(!FileSystem.exists('backups/'))
			{
				showOutput('The "backups" folder does not exist.', true);
				return;
			}
			
			var fileList:Array<String> = FileSystem.readDirectory('backups/').filter((file:String) -> file.endsWith('.$BACKUP_EXT'));
			if(fileList.length < 1)
			{
				showOutput('No autosave files found.', true);
				return;
			}

			fileList.sort((a:String, b:String) -> (a.toUpperCase() < b.toUpperCase()) ? 1 : -1); //Sort alphabetically descending
			var maxItems:Int = Std.int(Math.min(5, fileList.length));
			var radioGrp:PsychUIRadioGroup = new PsychUIRadioGroup(0, 0, fileList, 25, maxItems, false, 240);
			radioGrp.checked = 0;

			var hei:Float = radioGrp.height + 160;
			openSubState(new BasePrompt(420, hei, 'Choose an Autosave',
				function(state:BasePrompt) {
					upperBox.isMinimized = true;
					upperBox.bg.visible = false;

					var btn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
					btn.cameras = state.cameras;
					state.add(btn);

					radioGrp.screenCenter(X);
					radioGrp.y = state.bg.y + 80;
					radioGrp.cameras = state.cameras;
					state.add(radioGrp);

					var btn:PsychUIButton = new PsychUIButton(0, radioGrp.y + radioGrp.height + 20, 'Load', function()
					{
						var autosaveName:String = fileList[radioGrp.checked];
						var path:String = 'backups/$autosaveName';
						state.close();

						if(FileSystem.exists(path))
						{
							try
							{
								var loadedChart:SwagSong = Song.parseJSON(File.getContent(path), autosaveName, null);
								if(loadedChart == null || !Reflect.hasField(loadedChart, '__original_path'))
								{
									showOutput('Error: File loaded is not a valid Psych Engine autosave.', true);
									return;
								}
	
								var originalPath:String = Reflect.field(loadedChart, '__original_path');
								Reflect.deleteField(loadedChart, '__original_path');
	
								var func:Void->Void = function()
								{
									Song.chartPath = FileSystem.exists(originalPath) ? originalPath : null;
									loadChart(loadedChart);
									reloadNotesDropdowns();
									prepareReload();
	
									showOutput('Opened autosave "$autosaveName" successfully!');
								}
								
								if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning!\nAny unsaved progress will be lost.', func));
								else func();
							}
							catch(e:Exception)
							{
								showOutput('Error on loading autosave: ${e.message}', true);
							}
						}
						else showOutput('Error! Autosave file selected could not be found, huh??', true);
					});
					btn.cameras = state.cameras;
					btn.screenCenter(X);
					state.add(btn);
				}
			));
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		if(SHOW_EVENT_COLUMN)
		{
			btnY += 20;
			var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Open Events...', function()
			{
				if(!fileDialog.completed) return;
				upperBox.isMinimized = true;
				upperBox.bg.visible = false;
	
				fileDialog.open(function()
				{
					try
					{
						var filePath:String = fileDialog.path.replace('\\', '/');
						var eventsFile:SwagSong = Song.parseJSON(fileDialog.data, getSongFolderFromPath(filePath));
						if(eventsFile == null || Reflect.hasField(eventsFile, 'scrollSpeed') || eventsFile.events == null)
						{
							showOutput('Error: File loaded is not a Psych Engine chart/events file.', true);
							return;
						}
	
						var loadedEvents:Array<Dynamic> = eventsFile.events;
						if(loadedEvents.length < 1)
						{
							showOutput('Events file loaded is empty.', true);
							return;
						}
	
						openSubState(new BasePrompt('Events Found! Choose an action.',
							function(state:BasePrompt)
							{
								var btnY = 390;
								var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Replace All', function()
								{
									for (event in events)
									{
										if(event != null)
										{
											event.destroy();
											selectedNotes.remove(event);
										}
									}
									undoActions = [];
									events = [];
	
									for (event in loadedEvents)
										events.push(createEvent(event));
	
									softReloadNotes();
									state.close();
									showOutput('Events loaded successfully!');
								});
								btn.normalStyle.bgColor = FlxColor.RED;
								btn.normalStyle.textColor = FlxColor.WHITE;
								btn.screenCenter(X);
								btn.x -= 125;
								btn.cameras = state.cameras;
								state.add(btn);
								
								var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Add', function()
								{
									for (event in loadedEvents)
										events.push(createEvent(event));
	
									softReloadNotes();
									state.close();
									showOutput('Events added successfully!');
								});
								btn.screenCenter(X);
								btn.cameras = state.cameras;
								state.add(btn);
						
								var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Cancel', state.close);
								btn.screenCenter(X);
								btn.x += 125;
								btn.cameras = state.cameras;
								state.add(btn);
							}
						));
					}
					catch(e:Exception)
					{
						showOutput('Error: ${e.message}', true);
						trace(e.stack);
					}
				});
			}, btnWid);
			btn.text.alignment = LEFT;
			tab_group.add(btn);
		}

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Import V-Slice...', function()
		{
			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning!\nAny unsaved progress will be lost.', function() importVSliceChart()));
			else importVSliceChart();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Import Codename...', function()
		{
			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning!\nAny unsaved progress will be lost.', function() importCodenameChart()));
			else importCodenameChart();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Save', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			saveChart();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Save as...', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			saveChart(false);
		},btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		if(SHOW_EVENT_COLUMN)
		{
			btnY += 20;
			var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Save Events...', function()
			{
				if(!fileDialog.completed) return;
				upperBox.isMinimized = true;
	
				updateChartData();
				fileDialog.save('events.json', PsychJsonPrinter.print({events: PlayState.SONG.events, format: 'psych_v1'}, ['events']),
					function() showOutput('Events saved successfully to: ${fileDialog.path}'), null,
					function() showOutput('Error on saving events!', true));
			}, btnWid);
			btn.text.alignment = LEFT;
			tab_group.add(btn);
		}

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Reload Chart', reloadChartFromDisk, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
		
		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Exit', function()
		{
			exitEditor();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
	}

	var lockedEvents:Bool = false;
	function addEditTab()
	{
		var tab = upperBox.getTab('Edit');
		var tab_group = tab.menu;
		var btnX = 0;
		var btnY = 0;
		var btnWid = 150;

		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Undo', undo, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Redo', redo, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Copy', function()
		{
			if(selectedNotes.length > 0)
			{
				copiedNotes = [];
				copiedEvents = [];
				var pushedNotes:Array<Array<Dynamic>> = [];

				for (note in selectedNotes)
				{
					if(note == null) continue;

					var copied:Array<Dynamic> = makeNoteDataCopy(note.songData, note.isEvent);
					pushedNotes.push(copied);
					if(note.isEvent) copiedEvents.push(copied);
					else copiedNotes.push(copied);
				}
				pushedNotes.sort((a:Array<Dynamic>, b:Array<Dynamic>) -> FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]));
				
				var minTime:Float = pushedNotes[0][0];
				for (note in pushedNotes)
					note[0] -= minTime;
			}
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Paste', function()
		{
			if(copiedNotes.length > 0 || copiedEvents.length > 0)
			{
				selectionBox.visible = false;
				stopMovingNotes();
				resetSelectedNotes();
				selectedNotes = pasteCopiedNotesToSection();
				selectedNotes.sort(PlayState.sortByTime);

				var didFind:Bool = false;
				var minNoteData:Float = Math.POSITIVE_INFINITY;
				for (note in selectedNotes)
				{
					if(note == null || note.isEvent) continue;

					if(minNoteData > note.songData[1]) minNoteData = note.songData[1];
					didFind = true;
				}
				if(!didFind) minNoteData = 0;
				
				var pushedNotes:Array<MetaNote> = [];
				var pushedEvents:Array<EventMetaNote> = [];
				for (note in selectedNotes)
				{
					if(note == null) continue;

					if(!note.isEvent)
					{
						note.changeNoteData(Std.int(note.songData[1] - minNoteData));
						pushedNotes.push(note);
					}
					else pushedEvents.push(cast (note, EventMetaNote));
				}
				addUndoAction(ADD_NOTE, {notes: pushedNotes, events: pushedEvents});
				moveSelectedNotes(Std.int(minNoteData), selectedNotes[0].y);
			}
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Select All', function()
		{
			var sel = selectedNotes.copy();
			selectedNotes = curRenderedNotes.members.copy();
			addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
			onSelectNote();
			trace('Notes selected: ' + selectedNotes.length);
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Cut', function()
		{
			if(selectedNotes.length > 0)
			{
				copiedNotes = [];
				copiedEvents = [];
				var pushedNotes:Array<Array<Dynamic>> = [];

				for (note in selectedNotes)
				{
					if(note == null) continue;

					var copied:Array<Dynamic> = makeNoteDataCopy(note.songData, note.isEvent);
					pushedNotes.push(copied);
					if(note.isEvent) copiedEvents.push(copied);
					else copiedNotes.push(copied);
				}
				pushedNotes.sort((a:Array<Dynamic>, b:Array<Dynamic>) ->FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]));
			var minTime:Float = pushedNotes[0][0];
			for (note in pushedNotes)
				note[0] -= minTime;

			var removedNotes:Array<MetaNote> = [];
			var removedEvents:Array<EventMetaNote> = [];
			while(selectedNotes.length > 0)
			{
				var note:MetaNote = selectedNotes[0];
				selectedNotes.shift();
				if(note == null) continue;

				if(!note.isEvent)
				{
					notes.remove(note);
					removedNotes.push(note);
				}
				else
				{
					var ev:EventMetaNote = cast (note, EventMetaNote);
					events.remove(ev);
					removedEvents.push(ev);
				}
			}
			movingNotes.clear();
			isMovingNotes = false;
			selectedNotes = [];
			onSelectNote();
			softReloadNotes();
			addUndoAction(DELETE_NOTE, {notes: removedNotes, events: removedEvents});
		}
	}, btnWid);
	btn.text.alignment = LEFT;
	tab_group.add(btn);

	btnY += 20;
	var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Delete', function()
	{
		if(selectedNotes.length > 0)
		{
			var removedNotes:Array<MetaNote> = [];
			var removedEvents:Array<EventMetaNote> = [];
			while(selectedNotes.length > 0)
			{
				var note:MetaNote = selectedNotes[0];
				selectedNotes.shift();
				if(note == null) continue;

				var kind:String = !note.isEvent ? 'note' : 'event';
				trace('Removed $kind at time: ${note.strumTime}');
				if(!note.isEvent)
				{
					notes.remove(note);
					removedNotes.push(note);
				}
				else
				{
					var ev:EventMetaNote = cast (note, EventMetaNote);
					events.remove(ev);
					removedEvents.push(ev);
				}
			}
			movingNotes.clear();
			isMovingNotes = false;
			selectedNotes = [];
			onSelectNote();
			softReloadNotes();
			addUndoAction(DELETE_NOTE, {notes: removedNotes, events: removedEvents});
		}
	}, btnWid);
	btn.text.alignment = LEFT;
	tab_group.add(btn);

	btnY++;
	btnY += 20;
	var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Autosave Settings...', btnWid);
	btn.onClick = function()
	{
		upperBox.isMinimized = true;
		upperBox.bg.visible = false;
		openSubState(new BasePrompt(400, 160, 'Autosave Settings',
			function(state:BasePrompt)
			{
				var btn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
				btn.cameras = state.cameras;
				state.add(btn);

				var checkbox:PsychUICheckBox = null;
				var timeStepper:PsychUINumericStepper = null;

				timeStepper = new PsychUINumericStepper(state.bg.x + 50, state.bg.y + 90, 1, autoSaveCap, 1, 30, 0);
				timeStepper.onValueChange = function() {
					autoSaveTime = 0;
					checkbox.checked = true;
					autoSaveCap = chartEditorSave.data.autoSave = Std.int(timeStepper.value);
				};
				timeStepper.cameras = state.cameras;

				checkbox = new PsychUICheckBox(timeStepper.x + 80, timeStepper.y, 'Enabled', 60, function() {
					autoSaveTime = 0;
					autoSaveCap = chartEditorSave.data.autoSave = checkbox.checked ? Std.int(timeStepper.value) : 0;
				});
				checkbox.checked = (autoSaveCap > 0);
				checkbox.cameras = state.cameras;
				
				var maxFileStepper:PsychUINumericStepper = new PsychUINumericStepper(checkbox.x + 140, checkbox.y, 1, backupLimit, 0, 50, 0);
				maxFileStepper.onValueChange = function() {
					autoSaveTime = 0;
					checkbox.checked = true;
					chartEditorSave.data.backupLimit = backupLimit = Std.int(maxFileStepper.value);
				};
				maxFileStepper.cameras = state.cameras;

				var txt1:FlxText = new FlxText(timeStepper.x, timeStepper.y - 15, 100, 'Time (in minutes):');
				txt1.cameras = state.cameras;
				var txt2:FlxText = new FlxText(maxFileStepper.x, maxFileStepper.y - 15, 100, 'File Limit:');
				txt2.cameras = state.cameras;

				state.add(txt1);
				state.add(txt2);
				state.add(checkbox);
				state.add(timeStepper);
				state.add(maxFileStepper);
			}
		));

	};
	btn.text.alignment = LEFT;
	tab_group.add(btn);

	btnY++;
	btnY += 20;
	var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Clear All Notes', function()
	{
		var func:Void->Void = function()
		{
			resetSelectedNotes();
			addUndoAction(DELETE_NOTE, {notes: notes.copy()});
			notes = [];
			loadSection();
		}

		if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Delete all Notes in the song?', func));
		else func();
	}, btnWid);
	btn.normalStyle.bgColor = FlxColor.RED;
	btn.normalStyle.textColor = FlxColor.WHITE;
	btn.text.alignment = LEFT;
	tab_group.add(btn);

	if(SHOW_EVENT_COLUMN)
	{
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Clear All Events', function()
		{
			var func:Void->Void = function()
			{
				resetSelectedNotes();
				addUndoAction(DELETE_NOTE, {events: events.copy()});
				events = [];
				loadSection();
			}

			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Delete all Events in the song?', func));
			else func();
		}, btnWid);
		btn.normalStyle.bgColor = FlxColor.RED;
		btn.normalStyle.textColor = FlxColor.WHITE;
		btn.text.alignment = LEFT;
		tab_group.add(btn);
	}
}

	var showLastGridButton:PsychUIButton;
	var showNextGridButton:PsychUIButton;
	var noteTypeLabelsButton:PsychUIButton;
	var vortexEditorButton:PsychUIButton;
	function addViewTab()
	{
		var tab = upperBox.getTab('View');
		var tab_group = tab.menu;
		var btnX = 0;
		var btnY = 0;
		var btnWid = 150;

		if(chartEditorSave.data.waveformEnabled != null)
			waveformEnabled = chartEditorSave.data.waveformEnabled;
		if(chartEditorSave.data.waveformPlayer != null)
			waveformPlayerEnabled = (chartEditorSave.data.waveformPlayer == true);
		if(chartEditorSave.data.waveformOpp != null)
			waveformOppEnabled = (chartEditorSave.data.waveformOpp == true);

		waveformSprite.color = CoolUtil.colorFromString(waveformColorOf('waveformColor', '0000FF'));
		waveformPlayerSprite.color = CoolUtil.colorFromString(waveformColorOf('waveformPlayerColor', '00FF00'));
		waveformOppSprite.color = CoolUtil.colorFromString(waveformColorOf('waveformOppColor', 'FF0000'));

		waveformPlayerSprite.alpha = (chartEditorSave.data.waveformPlayerAlpha != null) ? chartEditorSave.data.waveformPlayerAlpha : 0.6;
		waveformOppSprite.alpha = (chartEditorSave.data.waveformOppAlpha != null) ? chartEditorSave.data.waveformOppAlpha : 0.6;

		showLastGridButton = new PsychUIButton(btnX, btnY, '', function()
		{
			showPreviousSection = !showPreviousSection;
			updateGridVisibility();
		}, btnWid);
		showLastGridButton.text.alignment = LEFT;
		tab_group.add(showLastGridButton);

		btnY += 20;
		showNextGridButton = new PsychUIButton(btnX, btnY, '', function()
		{
			showNextSection = !showNextSection;
			updateGridVisibility();
		}, btnWid);
		showNextGridButton.text.alignment = LEFT;
		tab_group.add(showNextGridButton);

		btnY++;
		btnY += 20;
		noteTypeLabelsButton = new PsychUIButton(btnX, btnY, '', function()
		{
			showNoteTypeLabels = !showNoteTypeLabels;
			updateGridVisibility();
		}, btnWid);
		noteTypeLabelsButton.text.alignment = LEFT;
		tab_group.add(noteTypeLabelsButton);

		btnY++;
		btnY += 20;
		vortexEditorButton = new PsychUIButton(btnX, btnY, vortexEnabled ? '  Vortex Editor ON' : '  Vortex Editor OFF', function()
		{
			vortexEnabled = !vortexEnabled;
			chartEditorSave.data.vortex = vortexEnabled;
			vortexQuantTxt.visible = vortexIndicator.visible = strumLineNotes.visible = strumLineNotes.active = vortexEnabled;
			vortexEditorButton.text.text = vortexEnabled ? '  Vortex Editor ON' : '  Vortex Editor OFF';

			for (note in strumLineNotes)
			{
				note.playAnim('static');
				note.resetAnim = 0;
			}
			prevGridBg.vortexLineEnabled = gridBg.vortexLineEnabled = nextGridBg.vortexLineEnabled = vortexEnabled;
		}, btnWid);
		vortexEditorButton.text.alignment = LEFT;
		tab_group.add(vortexEditorButton);
		
		var toyLabels:Array<String> = ['Boyfriend', 'Girlfriend', 'Opponent'];
		for (i in 0...3)
		{
			var idx:Int = i;
			var btn:PsychUIButton = null;

			btnY += 20;
			btn = new PsychUIButton(btnX, btnY, '  ${toyLabels[idx]} Toy: ${toyEnabled[idx] ? "ON" : "OFF"}', function()
			{
				toyEnabled[idx] = !toyEnabled[idx];
				chartEditorSave.data.toyEnabled = toyEnabled;

				if(toysEnabled) createToys();
				applyToyVisibility();

				btn.text.text = '  ${toyLabels[idx]} Toy: ${toyEnabled[idx] ? "ON" : "OFF"}';
			}, btnWid);
			btn.text.alignment = LEFT;
			tab_group.add(btn);
		}
		
		btnY += 20;
		hitboxBtn = new PsychUIButton(btnX, btnY, hitboxButtonLabel(), toggleToyHitboxes, btnWid);
		hitboxBtn.text.alignment = LEFT;
		tab_group.add(hitboxBtn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Waveform...', function()
		{
			ClientPrefs.toggleVolumeKeys(false);
			openSubState(new BasePrompt(470, 320, 'Waveform Settings',
				function(state:BasePrompt) {
					upperBox.isMinimized = true;
					upperBox.bg.visible = false;

					var closeBtn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
					closeBtn.cameras = state.cameras;
					state.add(closeBtn);

					var rowX:Float = state.bg.x + 30;
					var rowY:Float = state.bg.y + 80;
					var rowStep:Float = 70;

					var instCheck:PsychUICheckBox = new PsychUICheckBox(rowX, rowY, 'Instrumental', 110);
					instCheck.onClick = function()
					{
						chartEditorSave.data.waveformEnabled = waveformEnabled = instCheck.checked;
						updateWaveform();
					};
					instCheck.checked = waveformEnabled;
					instCheck.cameras = state.cameras;
					state.add(instCheck);

					var instColor:PsychUIInputText = new PsychUIInputText(rowX + 160, rowY, 60, waveformColorOf('waveformColor', '0000FF'), 10);
					instColor.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.waveformColor = cur;
						waveformSprite.color = CoolUtil.colorFromString(cur);
					}
					instColor.maxLength = 6;
					instColor.filterMode = ONLY_HEXADECIMAL;
					instColor.forceCase = UPPER_CASE;
					instColor.cameras = state.cameras;

					var instLabel:FlxText = new FlxText(instColor.x, instColor.y - 15, 80, 'Color (Hex):');
					instLabel.cameras = state.cameras;
					state.add(instLabel);
					state.add(instColor);

					rowY += rowStep;
					var playerCheck:PsychUICheckBox = new PsychUICheckBox(rowX, rowY, 'Main Vocals', 110);
					playerCheck.onClick = function()
					{
						chartEditorSave.data.waveformPlayer = waveformPlayerEnabled = playerCheck.checked;
						updateWaveform();
					};
					playerCheck.checked = waveformPlayerEnabled;
					playerCheck.cameras = state.cameras;
					state.add(playerCheck);

					var playerColor:PsychUIInputText = new PsychUIInputText(rowX + 160, rowY, 60, waveformColorOf('waveformPlayerColor', '00FF00'), 10);
					playerColor.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.waveformPlayerColor = cur;
						waveformPlayerSprite.color = CoolUtil.colorFromString(cur);
					}
					playerColor.maxLength = 6;
					playerColor.filterMode = ONLY_HEXADECIMAL;
					playerColor.forceCase = UPPER_CASE;
					playerColor.cameras = state.cameras;

					var playerLabel:FlxText = new FlxText(playerColor.x, playerColor.y - 15, 80, 'Color (Hex):');
					playerLabel.cameras = state.cameras;
					state.add(playerLabel);
					state.add(playerColor);

					var playerAlpha:PsychUINumericStepper = new PsychUINumericStepper(rowX + 280, rowY, 0.1, waveformPlayerSprite.alpha, 0, 1, 2, 60);
					playerAlpha.onValueChange = function()
					{
						chartEditorSave.data.waveformPlayerAlpha = playerAlpha.value;
						waveformPlayerSprite.alpha = playerAlpha.value;
					};
					playerAlpha.cameras = state.cameras;

					var playerAlphaLabel:FlxText = new FlxText(playerAlpha.x, playerAlpha.y - 15, 80, 'Alpha:');
					playerAlphaLabel.cameras = state.cameras;
					state.add(playerAlphaLabel);
					state.add(playerAlpha);

					rowY += rowStep;
					var oppCheck:PsychUICheckBox = new PsychUICheckBox(rowX, rowY, 'Opponent Vocals', 110);
					oppCheck.onClick = function()
					{
						chartEditorSave.data.waveformOpp = waveformOppEnabled = oppCheck.checked;
						updateWaveform();
					};
					oppCheck.checked = waveformOppEnabled;
					oppCheck.cameras = state.cameras;
					state.add(oppCheck);

					var oppColor:PsychUIInputText = new PsychUIInputText(rowX + 160, rowY, 60, waveformColorOf('waveformOppColor', 'FF0000'), 10);
					oppColor.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.waveformOppColor = cur;
						waveformOppSprite.color = CoolUtil.colorFromString(cur);
					}
					oppColor.maxLength = 6;
					oppColor.filterMode = ONLY_HEXADECIMAL;
					oppColor.forceCase = UPPER_CASE;
					oppColor.cameras = state.cameras;

					var oppLabel:FlxText = new FlxText(oppColor.x, oppColor.y - 15, 80, 'Color (Hex):');
					oppLabel.cameras = state.cameras;
					state.add(oppLabel);
					state.add(oppColor);

					var oppAlpha:PsychUINumericStepper = new PsychUINumericStepper(rowX + 280, rowY, 0.1, waveformOppSprite.alpha, 0, 1, 2, 60);
					oppAlpha.onValueChange = function()
					{
						chartEditorSave.data.waveformOppAlpha = oppAlpha.value;
						waveformOppSprite.alpha = oppAlpha.value;
					};
					oppAlpha.cameras = state.cameras;

					var oppAlphaLabel:FlxText = new FlxText(oppAlpha.x, oppAlpha.y - 15, 80, 'Alpha:');
					oppAlphaLabel.cameras = state.cameras;
					state.add(oppAlphaLabel);
					state.add(oppAlpha);
				}
			));
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Go to...', function()
		{
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;
			openSubState(new BasePrompt(420, 200, 'Go to Time/Section:',
				function(state:BasePrompt)
				{
					var curTime:Float = Conductor.songPosition;
					var currentSec:Int = curSec;

					var timeStepper:PsychUINumericStepper = new PsychUINumericStepper(state.bg.x + 100, state.bg.y + 90, 1, Math.floor(curTime)/1000, 0, FlxG.sound.music.length/1000 - 0.01, 2, 80);
					timeStepper.cameras = state.cameras;
					var sectionStepper:PsychUINumericStepper = new PsychUINumericStepper(timeStepper.x + 160, timeStepper.y, 1, currentSec, 0, PlayState.SONG.notes.length - 1, 0);
					sectionStepper.cameras = state.cameras;

					var txt1:FlxText = new FlxText(timeStepper.x, timeStepper.y - 15, 100, 'Time (in seconds):');
					var txt2:FlxText = new FlxText(sectionStepper.x, sectionStepper.y - 15, 100, 'Section:');
					txt1.cameras = state.cameras;
					txt2.cameras = state.cameras;
					state.add(txt1);
					state.add(txt2);
					state.add(timeStepper);
					state.add(sectionStepper);

					var timeTxt:FlxText = new FlxText(15, state.bg.y + state.bg.height - 75, 230, '', 16);
					timeTxt.alignment = CENTER;
					timeTxt.screenCenter(X);
					timeTxt.cameras = state.cameras;
					state.add(timeTxt);
					function updateTime()
					{
						var tm:String = FlxStringUtil.formatTime(curTime / 1000, true);
						var ln:String = FlxStringUtil.formatTime(FlxG.sound.music.length / 1000, true);
						timeTxt.text = '$tm / $ln';
					}
					updateTime();

					timeStepper.onValueChange = function()
					{
						curTime = timeStepper.value * 1000;
						for (i => time in cachedSectionTimes)
						{
							if(time <= curTime)
								currentSec = i;
							else break;
						}
						updateTime();
					};
					sectionStepper.onValueChange = function()
					{
						currentSec = Std.int(sectionStepper.value);
						curTime = cachedSectionTimes[currentSec] + 0.000001;
						updateTime();
					};

					var btn:PsychUIButton = new PsychUIButton(0, timeTxt.y + 30, 'Go To', function()
					{
						curSec = currentSec;
						FlxG.sound.music.time = FlxMath.bound(curTime, 0, FlxG.sound.music.length - 1);
						loadSection();
						state.close();
					});
					btn.cameras = state.cameras;
					btn.screenCenter(X);
					btn.x -= 60;
					state.add(btn);

					var btn:PsychUIButton = new PsychUIButton(0, btn.y, 'Cancel', state.close);
					btn.cameras = state.cameras;
					btn.screenCenter(X);
					btn.x += 60;
					state.add(btn);
				}
			));
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Theme...', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			openSubState(new BasePrompt(500, 260, 'Chart Editor Theme',
				function(state:BasePrompt)
				{
					var btn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
					btn.cameras = state.cameras;
					state.add(btn);

					var btnY = 320;
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Light', changeTheme.bind(LIGHT));
					btn.screenCenter(X);
					btn.x -= 180;
					btn.cameras = state.cameras;
					state.add(btn);
			
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Dark', changeTheme.bind(DARK));
					btn.screenCenter(X);
					btn.x -= 60;
					btn.cameras = state.cameras;
					state.add(btn);
					
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Default', changeTheme.bind(DEFAULT));
					btn.screenCenter(X);
					btn.cameras = state.cameras;
					btn.x += 60;
					state.add(btn);
			
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'V-Slice', changeTheme.bind(VSLICE));
					btn.screenCenter(X);
					btn.x += 180;
					btn.cameras = state.cameras;
					state.add(btn);

					btnY += 60;
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Custom', changeTheme.bind(CUSTOM));
					btn.screenCenter(X);
					btn.x -= 180;
					btn.cameras = state.cameras;
					state.add(btn);

					var customBgC:String = '303030';
					if(chartEditorSave.data.customBgColor != null)
						customBgC = chartEditorSave.data.customBgColor;

					var input:PsychUIInputText = new PsychUIInputText(0, btnY, 80, customBgC, 10);
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.forceCase = UPPER_CASE;
					input.screenCenter(X);
					input.x -= 60;
					input.cameras = state.cameras;
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.customBgColor = cur;
						changeTheme(CUSTOM);
					}

					var txt:FlxText = new FlxText(input.x, input.y - 15, 120, 'BG Color:');
					txt.cameras = state.cameras;
					state.add(txt);
					state.add(input);

					var customGridC:Array<String> = ['DFDFDF', 'BFBFBF'];
					if(chartEditorSave.data.customGridColors != null && chartEditorSave.data.customGridColors.length > 1)
						customGridC = chartEditorSave.data.customGridColors;

					var input:PsychUIInputText = new PsychUIInputText(0, btnY, 80, customGridC[0], 10);
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.forceCase = UPPER_CASE;
					input.screenCenter(X);
					input.x += 60;
					input.cameras = state.cameras;
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.customGridColors[0] = cur;
						changeTheme(CUSTOM);
					}

					var txt:FlxText = new FlxText(input.x, input.y - 15, 120, 'Grid Colors:');
					txt.cameras = state.cameras;
					state.add(txt);
					state.add(input);

					var input:PsychUIInputText = new PsychUIInputText(0, btnY + 30, 80, customGridC[1], 10);
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.forceCase = UPPER_CASE;
					input.screenCenter(X);
					input.x += 60;
					input.cameras = state.cameras;
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.customGridColors[1] = cur;
						changeTheme(CUSTOM);
					}
					state.add(input);

					var customGridOtherC:Array<String> = ['5F5F5F', '4A4A4A'];
					if(chartEditorSave.data.customNextGridColors != null && chartEditorSave.data.customNextGridColors.length > 1)
						customGridOtherC = chartEditorSave.data.customNextGridColors;

					var input:PsychUIInputText = new PsychUIInputText(0, btnY, 80, customGridOtherC[0], 10);
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.forceCase = UPPER_CASE;
					input.screenCenter(X);
					input.x += 180;
					input.cameras = state.cameras;
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.customNextGridColors[0] = cur;
						changeTheme(CUSTOM);
					}

					var txt:FlxText = new FlxText(input.x, input.y - 15, 120, 'Next Grid Colors:');
					txt.cameras = state.cameras;
					state.add(txt);
					state.add(input);

					var input:PsychUIInputText = new PsychUIInputText(0, btnY + 30, 80, customGridOtherC[1], 10);
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.forceCase = UPPER_CASE;
					input.screenCenter(X);
					input.x += 180;
					input.cameras = state.cameras;
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.customNextGridColors[1] = cur;
						changeTheme(CUSTOM);
					}
					state.add(input);
				}
			));
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Reset UI Boxes', function()
		{
			mainBoxMoved = infoBoxMoved = false;
			mainBox.setPosition(mainBoxPosition.x, mainBoxPosition.y);
			infoBox.setPosition(infoBoxPosition.x, mainBoxPosition.y + mainBoxOriginalHeight);

			Reflect.deleteField(chartEditorSave.data, 'mainBoxPos');
			Reflect.deleteField(chartEditorSave.data, 'infoBoxPos');
			chartEditorSave.data.mainBoxMoved = false;
			chartEditorSave.data.infoBoxMoved = false;
			chartEditorSave.flush();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
	}

	function addAudioTab()
	{
		var tab = upperBox.getTab('Audio');
		var tab_group = tab.menu;
		var labelX:Int = 8;
		var sliderX:Int = 105;
		var sliderWid:Int = 125;
		var muteX:Int = 235;
		var objY:Int = 18;
		var rowStep:Int = 36;

		var panel:FlxSprite = new FlxSprite().makeGraphic(300, 270, FlxColor.BLACK, true);
		panel.alpha = 0.8;
		tab_group.add(panel);

		var rowLabels:Array<FlxText> = [];

		instVolumeSlider = new PsychUISlider(sliderX, objY, null, 60, 0, 100, sliderWid);
		instMuteCheckBox = new PsychUICheckBox(muteX, objY - 6, 'Mute', 60, updateAudioVolume);
		rowLabels.push(new FlxText(labelX, objY - 2, 95, 'Inst.', 8));

		objY += rowStep;
		playerVolumeSlider = new PsychUISlider(sliderX, objY, null, 100, 0, 100, sliderWid);
		playerMuteCheckBox = new PsychUICheckBox(muteX, objY - 6, 'Mute', 60, updateAudioVolume);
		rowLabels.push(new FlxText(labelX, objY - 2, 95, 'Main Vocals', 8));

		objY += rowStep;
		opponentVolumeSlider = new PsychUISlider(sliderX, objY, null, 100, 0, 100, sliderWid);
		opponentMuteCheckBox = new PsychUICheckBox(muteX, objY - 6, 'Mute', 60, updateAudioVolume);
		rowLabels.push(new FlxText(labelX, objY - 2, 95, 'Opp. Vocals', 8));

		objY += rowStep;
		hitsoundPlayerSlider = new PsychUISlider(sliderX, objY, null, 0, 0, 100, sliderWid);
		rowLabels.push(new FlxText(labelX, objY - 2, 95, 'Hitsound (P)', 8));

		objY += rowStep;
		hitsoundOpponentSlider = new PsychUISlider(sliderX, objY, null, 0, 0, 100, sliderWid);
		rowLabels.push(new FlxText(labelX, objY - 2, 95, 'Hitsound (O)', 8));

		objY += rowStep;
		metronomeSlider = new PsychUISlider(sliderX, objY, null, 0, 0, 100, sliderWid);
		rowLabels.push(new FlxText(labelX, objY - 2, 95, 'Metronome', 8));

		for (slider in [instVolumeSlider, playerVolumeSlider, opponentVolumeSlider, hitsoundPlayerSlider, hitsoundOpponentSlider, metronomeSlider])
		{
			slider.decimals = 0;
			slider.minText.visible = slider.maxText.visible = false;
			tab_group.add(slider);
		}

		instVolumeSlider.onChange = function(_) updateAudioVolume();
		playerVolumeSlider.onChange = function(_) updateAudioVolume();
		opponentVolumeSlider.onChange = function(_) updateAudioVolume();

		tab_group.add(instMuteCheckBox);
		tab_group.add(playerMuteCheckBox);
		tab_group.add(opponentMuteCheckBox);

		for (txt in rowLabels) tab_group.add(txt);

		objY += rowStep + 6;
		editorMusicCheckBox = new PsychUICheckBox(labelX + 2, objY, 'Mute Editor Music', 150);
		editorMusicCheckBox.checked = editorMusicMuted;
		editorMusicCheckBox.onClick = function()
		{
			editorMusicMuted = editorMusicCheckBox.checked;
			chartEditorSave.data.editorMusicMuted = editorMusicMuted;

			if(editorMusicMuted) muteEditorLoop();
			else if(FlxG.sound.music == null || !FlxG.sound.music.playing) scheduleEditorLoop(1);
		};
		tab_group.add(editorMusicCheckBox);
	}

	function addTestTab()
	{
		var tab = upperBox.getTab('Test');
		var tab_group = tab.menu;
		var btnX = 0;
		var btnY = 0;
		var btnWid = 255;

		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Playtest (ENTER)', function()
		{
			goToPlayState();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Playtest Here (SHIFT+ENTER)', function()
		{
			goToPlayState(true);
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Preview Chart (CTRL+ENTER)', function()
		{
			openEditorPlayState();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
	}

	function updateChartData()
	{
		PlayState.SONG.mania = GRID_PLAYERS;

		if(strumlineConfigs.length > 0)
			PlayState.SONG.extraStrumlines = strumlineConfigs.copy();
		else
			PlayState.SONG.extraStrumlines = null;

		for (secNum => section in PlayState.SONG.notes)
			PlayState.SONG.notes[secNum].sectionNotes = [];

		notes.sort(PlayState.sortByTime);
		var noteSec:Int = 0;
		var nextSectionTime:Float = cachedSectionTimes.length > 1 ? cachedSectionTimes[noteSec + 1] : Math.POSITIVE_INFINITY;
		var curSectionTime:Float = cachedSectionTimes.length > 0 ? cachedSectionTimes[noteSec] : 0;

		for (num => note in notes)
		{
			if(note == null) continue;

			while(noteSec + 1 < cachedSectionTimes.length && cachedSectionTimes[noteSec + 1] <= note.strumTime)
			{
				noteSec++;
				nextSectionTime = (noteSec + 1 < cachedSectionTimes.length) ? cachedSectionTimes[noteSec + 1] : Math.POSITIVE_INFINITY;
				curSectionTime = cachedSectionTimes[noteSec];
			}

			if(noteSec >= PlayState.SONG.notes.length)
			{
				var lastSec = PlayState.SONG.notes[PlayState.SONG.notes.length - 1];
				if(lastSec != null)
					lastSec.sectionNotes.push(note.songData);
				continue;
			}
			var arr:Array<Dynamic> = PlayState.SONG.notes[noteSec].sectionNotes;
			arr.push(note.songData);
		}

		events.sort(PlayState.sortByTime);
		PlayState.SONG.events = [];
		for (event in events)
			PlayState.SONG.events.push(event.songData);
	}

	function saveChart(canQuickSave:Bool = true)
	{
		updateChartData();
		var chartData:String = PsychJsonPrinter.print(PlayState.SONG, ['sectionNotes', 'events']);
		if(canQuickSave && Song.chartPath != null)
		{
			File.saveContent(Song.chartPath, chartData);
			showOutput('Chart saved successfully to: ${Song.chartPath}');
		}
		else
		{
			var chartName:String = Paths.formatToSongPath(PlayState.SONG.song) + '.json';
			if(Song.chartPath != null)
			{
				var normalized:String = Song.chartPath.replace('\\', '/');
				chartName = normalized.substr(normalized.lastIndexOf('/') + 1).trim();
			}
			fileDialog.save(chartName, chartData,
				function()
				{
					var newPath:String = fileDialog.path;
					Song.chartPath = newPath.replace('\\', '/');
					pushRecentChart(Song.chartPath);
					reloadNotesDropdowns();
					showOutput('Chart saved successfully to: $newPath');

				}, null, function() showOutput('Error on saving chart!', true));
		}
	}
	
	inline function getCurChartSection()
	{
		return PlayState.SONG.notes != null ? PlayState.SONG.notes[curSec] : null;
	}

	function clampUIBox(box:PsychUIBox)
	{
		if(box == null) return;

		box.setPosition(FlxMath.bound(box.x, 0, FlxG.width - box.bg.width),
			FlxMath.bound(box.y, 0, FlxG.height - box.tabHeight - 20));
	}

	function loadUIBoxPositions()
	{
		mainBoxMoved = (chartEditorSave.data.mainBoxMoved == true);
		infoBoxMoved = (chartEditorSave.data.infoBoxMoved == true);

		var saved:Array<Dynamic> = chartEditorSave.data.mainBoxPos;
		if(mainBoxMoved && saved != null && saved.length > 1)
		{
			mainBox.setPosition(saved[0], saved[1]);
			clampUIBox(mainBox);
		}

		saved = chartEditorSave.data.infoBoxPos;
		if(infoBoxMoved && saved != null && saved.length > 1)
		{
			infoBox.setPosition(saved[0], saved[1]);
			clampUIBox(infoBox);
		}
	}

	function updateMiniChartPosition()
	{
		var newX:Float = gridBg.x + gridBg.width + WAVE_STRIP;
		miniChartBg.x = newX;
		miniChart.x = newX;
		miniChartHandle.x = newX;

		vortexIndicator.x = gridBg.x - GRID_SIZE;
		updateVortexQuantPosition();
		waveformOppSprite.x = gridBg.x - WAVE_STRIP;
		waveformPlayerSprite.x = gridBg.x + gridBg.width;

		if(SHOW_EVENT_COLUMN && eventIcon != null)
			eventIcon.x = gridBg.x + (GRID_SIZE * 0.5) - eventIcon.width / 2;

		timeLine.x = gridBg.x;
		timeLine.setGraphicSize(Std.int(gridBg.width), 4);
		timeLine.updateHitbox();

		waveformSprite.x = gridBg.x + (SHOW_EVENT_COLUMN ? GRID_SIZE : 0);

		var iconX:Float = gridBg.x + (SHOW_EVENT_COLUMN ? GRID_SIZE : 0);
		for (i in 0...icons.length)
		{
			var icon:HealthIcon = icons[i];
			if(icon == null) continue;
			icon.x = iconX + GRID_SIZE * (GRID_COLUMNS_PER_PLAYER / 2) - icon.width / 2;
			iconX += GRID_SIZE * GRID_COLUMNS_PER_PLAYER;
		}

		var curSecData:SwagSection = PlayState.SONG.notes != null ? PlayState.SONG.notes[curSec] : null;
		var mustHitSection:Bool = (curSecData != null && curSecData.mustHitSection == true);
		var mustHitTarget:String = (curSecData != null && curSecData.mustHitTarget != null) ? curSecData.mustHitTarget : '';
		if(icons.length > 1)
		{
			if(mustHitSection)
				mustHitIndicator.x = icons[0].x + icons[0].width / 2;
			else if (mustHitTarget.startsWith('Strumline #'))
			{
				var strumIndex:Null<Int> = Std.parseInt(mustHitTarget.substr('Strumline #'.length));
				var targetIcon:HealthIcon = (strumIndex != null && strumIndex - 1 < icons.length) ? icons[strumIndex - 1] : null;
				mustHitIndicator.x = (targetIcon != null ? targetIcon.x : icons[1].x) + icons[1].width / 2;
			}
			else
				mustHitIndicator.x = icons[1].x + icons[1].width / 2;
		}
		else if(icons.length == 1)
			mustHitIndicator.x = icons[0].x + icons[0].width / 2;
		else
			mustHitIndicator.x = gridBg.x + gridBg.width / 2;

		var strumX:Float = gridBg.x + (SHOW_EVENT_COLUMN ? GRID_SIZE : 0);
		for (i in 0...strumLineNotes.length)
		{
			var note:StrumNote = strumLineNotes.members[i];
			if(note == null) continue;
			note.x = strumX + (GRID_SIZE * i) + GRID_SIZE / 2 - note.width / 2;
		}

		eventLockOverlay.x = gridBg.x;

		var baseNoteX:Float = gridBg.x + (SHOW_EVENT_COLUMN ? GRID_SIZE : 0);
		function repositionNoteGroup(group:FlxTypedGroup<MetaNote>)
		{
			for (note in group)
			{
				if(note == null) continue;
				if(note.isEvent)
				{
					note.x = gridBg.x;
					var eventNote:EventMetaNote = cast(note, EventMetaNote);
					eventNote.eventText.x = note.x - eventNote.eventText.width - 10;
				}
				else
				{
					var noteX:Float = baseNoteX + (GRID_SIZE - note.width) / 2 + GRID_SIZE * (note.songData[1] % (GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS));
					note.x = noteX;
				}
			}
		}
		repositionNoteGroup(behindRenderedNotes);
		repositionNoteGroup(curRenderedNotes);
		repositionNoteGroup(movingNotes);

		for (i in 0...noteHighlights.length)
		{
			var highlight:FlxSprite = noteHighlights.members[i];
			var note:MetaNote = selectedNotes.length > i ? selectedNotes[i] : null;
			if(highlight == null || note == null) continue;
			highlight.x = note.x;
		}

		for (i in 0...sustainHighlights.length)
		{
			var highlight:FlxSprite = sustainHighlights.members[i];
			if(highlight == null || selectedNotes.length < 1 || selectedNotes[0] == null) continue;
			highlight.x = selectedNotes[0].x;
		}
	}

	function rebuildGridPlayers()
	{
		createGrids();

		strumLineNotes.forEachAlive(function(n) n.destroy());
		strumLineNotes.clear();

		var startX:Float = gridBg.x;
		var startY:Float = FlxG.height / 2;
		if(SHOW_EVENT_COLUMN) startX += GRID_SIZE;

		for (i in 0...Std.int(GRID_PLAYERS * GRID_COLUMNS_PER_PLAYER))
		{
			var note:StrumNote = new StrumNote(startX + (GRID_SIZE * i), startY, i % GRID_COLUMNS_PER_PLAYER, 0);
			note.scrollFactor.set();
			note.playAnim('static');
			note.alpha = 0.4;
			note.updateHitbox();
			if(note.width > note.height)
				note.setGraphicSize(GRID_SIZE);
			else
				note.setGraphicSize(0, GRID_SIZE);
			note.updateHitbox();
			note.x += GRID_SIZE / 2 - note.width / 2;
			note.y += GRID_SIZE / 2 - note.height / 2;
			strumLineNotes.add(note);
		}
		strumLineNotes.visible = strumLineNotes.active = vortexEnabled;

		for (icon in icons)
		{
			remove(icon);
			icon.destroy();
		}
		icons.resize(0);

		var columns:Int = SHOW_EVENT_COLUMN ? 1 : 0;
		var iconX:Float = gridBg.x + (SHOW_EVENT_COLUMN ? GRID_SIZE : 0);
		var iconY:Float = 50;
		var gridStripes:Array<Int> = [];

		for (i in 0...GRID_PLAYERS)
		{
			if(columns > 0) gridStripes.push(columns);
			columns += GRID_COLUMNS_PER_PLAYER;

			var icon:HealthIcon = new HealthIcon();
			icon.autoAdjustOffset = false;
			icon.y = iconY;
			icon.alpha = 0.6;
			icon.scrollFactor.set();
			icon.scale.set(0.3, 0.3);
			icon.updateHitbox();
			icon.ID = i + 1;
			add(icon);
			icons.push(icon);

			icon.x = iconX + GRID_SIZE * (GRID_COLUMNS_PER_PLAYER / 2) - icon.width / 2;
			iconX += GRID_SIZE * GRID_COLUMNS_PER_PLAYER;
		}
		prevGridBg.stripes = nextGridBg.stripes = gridBg.stripes = gridStripes;

		updateJsonData();
		updateHeads(true);
		updateWaveform();
		reloadNotes();
		updateMiniChartPosition();
	}

	function updateNotesRGB()
	{
		PlayState.SONG.disableNoteRGB = noRGBCheckBox.checked;

		for (note in notes)
		{
			if(note == null) continue;

			note.rgbShader.enabled = !noRGBCheckBox.checked;
			if(note.rgbShader.enabled)
			{
				var data = funkin.data.NoteTypesConfig.loadNoteTypeData(note.noteType);
				if(data == null || data.length < 1) continue;

				for (line in data)
				{
					var prop:String = line.property.join('.');
					if(prop == 'rgbShader.enabled')
						note.rgbShader.enabled = line.value;
				}
			}
		}

		for (note in strumLineNotes)
			note.rgbShader.enabled = !noRGBCheckBox.checked;
	}

	function updateSplashRGB()
	{
		PlayState.SONG.disableSplashRGB = noSplashRGBCheckBox.checked;
	}

	function updateHoldRGB()
	{
		PlayState.SONG.disableHoldRGB = noHoldRGBCheckBox.checked;
	}

	function updateGridVisibility()
	{
		showLastGridButton.text.text = showPreviousSection	? '  Hide Last Section' :  '  Show Last Section';
		showNextGridButton.text.text = showNextSection		? '  Hide Next Section' :  '  Show Next Section';

		prevGridBg.visible = (curSec > 0 && showPreviousSection);
		nextGridBg.visible = (curSec < PlayState.SONG.notes.length - 1 && showNextSection);
		
		noteTypeLabelsButton.text.text = showNoteTypeLabels ? '  Hide Note Labels' : '  Show Note Labels';
		for (num => text in MetaNote.noteTypeTexts)
			text.visible = showNoteTypeLabels;
		softReloadNotes();
	}

	function adaptNotesToNewTimes(oldTimes:Array<Float>)
	{
		undoActions = [];
		setSongPlaying(false);
		var gridLerp:Float = FlxMath.bound((scrollY + FlxG.height/2 - gridBg.y) / gridBg.height, 0.000001, 0.999999);
		notes.sort(PlayState.sortByTime);
		_cacheSections();

		var noteSec:Int = 0;
		var oldNextSectionTime:Float = oldTimes[noteSec + 1];
		var oldCurSectionTime:Float = oldTimes[noteSec];
		var nextSectionTime:Float = cachedSectionTimes[noteSec + 1];
		var curSectionTime:Float = cachedSectionTimes[noteSec];

		for (num => note in notes)
		{
			if(note == null || note.strumTime <= 0) continue;

			while(noteSec + 2 < oldTimes.length && oldTimes[noteSec + 1] <= note.strumTime)
			{
				noteSec++;
				oldNextSectionTime = oldTimes[noteSec + 1];
				oldCurSectionTime = oldTimes[noteSec];
				nextSectionTime = cachedSectionTimes[noteSec + 1];
				curSectionTime = cachedSectionTimes[noteSec];

				if(noteSec + 1 >= cachedSectionTimes.length)
				{
					trace('failsafe, cancel early and delete notes after this');
					var changedSelected:Bool = false;
					for(i in num...notes.length)
					{
						var n = notes[num];
						if(n != null)
						{
							if(selectedNotes.contains(n))
							{
								selectedNotes.remove(n);
								changedSelected = true;
							}
							notes.remove(n);
							note.destroy();
						}
					}
					if(changedSelected) onSelectNote();
					loadSection();
					return;
				}
				//trace('changed section: $noteSec, $oldNextSectionTime, $oldCurSectionTime, $nextSectionTime, $curSectionTime');
			}

			var shouldBound:Bool = (note.strumTime >= oldCurSectionTime && note.strumTime < oldNextSectionTime);
			var strumTime:Float = note.strumTime;

			var ratio:Float = (nextSectionTime - curSectionTime) / (oldNextSectionTime - oldCurSectionTime);
			var adaptedStrumTime:Float = ((note.strumTime - oldCurSectionTime) * ratio) + curSectionTime;
			note.setStrumTime(adaptedStrumTime);
			if(shouldBound)
				note.setStrumTime(FlxMath.bound(note.strumTime, curSectionTime, nextSectionTime));

			positionNoteYOnTime(note, noteSec);
			note.updateSustainToStepCrochet(cachedSectionCrochets[noteSec] / 4);
		}
		
		for (event in events)
		{
			var secNum:Int = 0;
			for (time in cachedSectionTimes)
			{
				if(time > event.strumTime) break;
				secNum++;
			}
			positionNoteYOnTime(event, secNum);
		}
		
		var time:Float = FlxMath.remapToRange(gridLerp, 0, 1, cachedSectionTimes[curSec], cachedSectionTimes[curSec + 1]);
		if(Math.isNaN(time))
		{
			time = 0;
			curSec = 0;
		}
		
		if(FlxG.sound.music != null && time >= FlxG.sound.music.length)
		{
			time = FlxG.sound.music.length - 1;
			curSec = PlayState.SONG.notes.length - 1;
		}
		FlxG.sound.music.time = time;
		Conductor.songPosition = time;
		forceDataUpdate = true;
		loadSection();
	}

	public function UIEvent(id:String, sender:Dynamic)
	{
		//trace(id, sender);
		switch(id)
		{
			case PsychUIButton.CLICK_EVENT, PsychUIDropDownMenu.CLICK_EVENT:
				ignoreClickForThisFrame = true;

			case PsychUIBox.CLICK_EVENT:
				ignoreClickForThisFrame = true;

			case PsychUIBox.MINIMIZE_EVENT:
				if(sender == upperBox)
				{
					upperBox.bg.visible = false;
				}

			case PsychUIBox.DROP_EVENT:
				if(sender == mainBox)
				{
					mainBoxMoved = true;
					clampUIBox(mainBox);
					chartEditorSave.data.mainBoxPos = [mainBox.x, mainBox.y];
				}
				else if(sender == infoBox)
				{
					infoBoxMoved = true;
					clampUIBox(infoBox);
					chartEditorSave.data.infoBoxPos = [infoBox.x, infoBox.y];
				}
				chartEditorSave.data.mainBoxMoved = mainBoxMoved;
				chartEditorSave.data.infoBoxMoved = infoBoxMoved;
				chartEditorSave.flush();
		}
	}

	function openEditorPlayState()
	{
		if(FlxG.sound.music == null)
		{
			showOutput('Load a valid song to preview!', true);
			return;
		}
		setSongPlaying(false);
		chartEditorSave.flush(); //just in case a random crash happens before loading

		openSubState(new EditorPlayState(cast notes, [vocals, opponentVocals]));
		_loopMutedByPlaytest = true;
		muteEditorLoop();
		upperBox.isMinimized = true;
		upperBox.visible = mainBox.visible = infoBox.visible = false;
	}

	function setTipVisible(v:Bool)
	{
		tipBg.visible = tipBg.active = v;
		fullTipText.visible = fullTipText.active = v;
		tipPageTxt.visible = tipPageTxt.active = v;
		if(v) showTipPage(0);
	}

	function showTipPage(page:Int)
	{
		curTipPage = FlxMath.wrap(page, 0, tipPages.length - 1);
		fullTipText.text = tipPages[curTipPage];
		fullTipText.screenCenter();
		fullTipText.y -= 25;
		tipPageTxt.text = '< ${curTipPage + 1} / ${tipPages.length} >';
	}

	function reloadChartFromDisk()
	{
		var func:Void->Void = function()
		{
			if(Song.chartPath == null || !FileSystem.exists(Song.chartPath))
			{
				showOutput('You must save/load a Chart first to Reload it!', true);
				return;
			}

			try
			{
				var reloadedChart:SwagSong = Song.parseJSON(File.getContent(Song.chartPath), getSongFolderFromPath(Song.chartPath));
				loadChart(reloadedChart);
				reloadNotesDropdowns();
				prepareReload();
				showOutput('Chart reloaded successfully!');
			}
			catch(e:Exception)
			{
				showOutput('Error: ${e.message}', true);
				trace(e.stack);
			}
		}

		if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning!\nAny unsaved progress will be lost', func));
		else func();
	}
	
	function exitEditor()
	{
		var func:Void->Void = function()
		{
			PlayState.chartingMode = false;
			FlxG.mouse.visible = false;
			funkin.editors.EditorHelper.returnToPreviousState();
		};

		if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning!\nAny unsaved progress will be lost', func));
		else func();
	}

	function goToPlayState(?startFromHere:Bool = false)
	{
		persistentUpdate = false;
		FlxG.mouse.visible = false;
		chartEditorSave.flush();

		setSongPlaying(false);
		updateChartData();
		StageData.loadDirectory(PlayState.SONG);

		PlayState.startOnTime = startFromHere ? Conductor.songPosition : 0;

		LoadingState.loadAndSwitchState(new PlayState());
		ClientPrefs.toggleVolumeKeys(true);
	}
	
	override function openSubState(SubState:FlxSubState)
	{
		if(!persistentUpdate) setSongPlaying(false);

		_openingSubState = true;
		if(customCursor != null) customCursor.visible = false;
		hideCursorFrames = 0;
		isGrabbingCursor = false;
		FlxG.mouse.visible = true;

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		ClientPrefs.toggleVolumeKeys(true);
		_openingSubState = false;
		if(_loopMutedByPlaytest)
		{
			_loopMutedByPlaytest = false;
			scheduleEditorLoop(3.5);
		}
		super.closeSubState();
		upperBox.isMinimized = true;
		upperBox.bg.visible = false;
		upperBox.visible = mainBox.visible = infoBox.visible = true;
		updateAudioVolume();
	}

	public function saveToyPosition(toyName:String, x:Float, y:Float)
	{
		if(chartEditorSave.data.toyPositions == null)
			chartEditorSave.data.toyPositions = {};
		
		Reflect.setField(chartEditorSave.data.toyPositions, toyName, {x: x, y: y});
		chartEditorSave.flush();
	}

	public function saveToySize(toyName:String, mult:Float)
	{
		if(chartEditorSave.data.toySizes == null)
			chartEditorSave.data.toySizes = {};

		Reflect.setField(chartEditorSave.data.toySizes, toyName, mult);
		chartEditorSave.flush();
	}
	
	override function destroy()
	{
		instance = null;
		Note.globalRgbShaders = [];
		funkin.data.NoteTypesConfig.clearNoteTypesData();

		for (num => text in MetaNote.noteTypeTexts)
			text.destroy();

		MetaNote.noteTypeTexts = [];
		fileDialog.destroy();
		
		if(miniChartScrollTween != null)
		{
			miniChartScrollTween.cancel();
			miniChartScrollTween = null;
		}
		
		if(customCursor != null) customCursor.destroy();
		if(customCursor != null) customCursor.destroy();
		if(miniChart != null) miniChart.destroy();
		if(miniChartBg != null) miniChartBg.destroy();
		if(miniChartHandle != null) miniChartHandle.destroy();
		
		super.destroy();
	}

	function loadFileList(mainFolder:String, ?optionalList:String = null, ?fileTypes:Array<String> = null)
	{
		if(fileTypes == null) fileTypes = ['.json'];

		var fileList:Array<String> = [];
		if(optionalList != null)
		{
			for (file in Mods.mergeAllTextsNamed(optionalList))
			{
				file = file.trim();
				if(file.length > 0 && !fileList.contains(file))
					fileList.push(file);
			}
		}

		for (directory in Mods.directoriesWithFile(Paths.getSharedPath(), mainFolder))
		{
			for (file in FileSystem.readDirectory(directory))
			{
				var path = haxe.io.Path.join([directory, file.trim()]);
				if (!FileSystem.isDirectory(path) && !file.startsWith('readme.'))
				{
					for (fileType in fileTypes)
					{
						var fileToCheck:String = file.substr(0, file.length - fileType.length);
						if(fileToCheck.length > 0 && path.endsWith(fileType) && !fileList.contains(fileToCheck))
						{
							fileList.push(fileToCheck);
							break;
						}
					}
				}
			}
		}
		return fileList;
	}
	
	function loadCharacterFile(char:String):CharacterFile
	{
		if(char != null)
		{
			try
			{
				var path:String = Paths.getPath('characters/' + char + '.json', TEXT);
				#if MODS_ALLOWED
				var unparsedJson = File.getContent(path);
				#else
				var unparsedJson = Assets.getText(path);
				#end
				return cast Json.parse(unparsedJson);
			}
			catch (e:Dynamic) {}
		}
		return null;
	}
	
	var overwriteSavedSomething:Bool = false;
	function overwriteCheck(savePath:String, overwriteName:String, saveData:String, continueFunc:Void->Void = null, ?continueOnCancel:Bool = false)
	{
		if(FileSystem.exists(savePath))
		{
			openSubState(new Prompt('Overwrite: "$overwriteName"?', function()
			{
				overwriteSavedSomething = true;
				File.saveContent(savePath, saveData);
				if(continueFunc != null) continueFunc();
			},
			continueOnCancel ? (function() if(continueFunc != null) continueFunc()) : null));
		}
		else
		{
			overwriteSavedSomething = true;
			File.saveContent(savePath, saveData);
			if(continueFunc != null) continueFunc();
		}
	}

	// Undo/Redo stuff
	var undoActions:Array<UndoStruct> = [];
	var currentUndo:Int = 0;
	function addUndoAction(action:UndoAction, data:Dynamic)
	{
		function destroyFromArr(arr:Array<MetaNote>)
		{
			if(arr == null || arr.length < 1) return;

			for (note in arr)
				if(note != null)
					note.destroy();
		}

		//trace('pushed action: $action');
		if(currentUndo > 0)
		{
			for (i in 0...currentUndo)
			{
				var dropped:UndoStruct = undoActions[i];
				if(dropped == null) continue;

				switch(dropped.action)
				{
					case ADD_NOTE:
						destroyFromArr(dropped.data.notes);
						destroyFromArr(dropped.data.events);
					case MOVE_NOTE:
						destroyFromArr(dropped.data.movedNotes);
						destroyFromArr(dropped.data.movedEvents);
					default:
				}
			}
			undoActions = undoActions.slice(currentUndo);
		}
		currentUndo = 0;
		undoActions.insert(0, {action: action, data: data});
		while(undoActions.length > 15)
		{
			var lastAction:UndoStruct = undoActions.pop();
			if(lastAction != null)
			{
				switch(lastAction.action)
				{
					case DELETE_NOTE:
						destroyFromArr(lastAction.data.notes);
						destroyFromArr(lastAction.data.events);
					case MOVE_NOTE:
						destroyFromArr(lastAction.data.originalNotes);
						destroyFromArr(lastAction.data.originalEvents);
					default:
				}
			}
		}
	}

	function undo()
	{
		if(isMovingNotes || currentUndo >= undoActions.length)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
			return;
		}

		var action:UndoStruct = undoActions[currentUndo];
		switch(action.action)
		{
			case ADD_NOTE:
				actionRemoveNotes(action.data.notes, action.data.events);

			case DELETE_NOTE:
				actionPushNotes(action.data.notes, action.data.events);

			case MOVE_NOTE:
				actionRemoveNotes(action.data.movedNotes, action.data.movedEvents);
				actionPushNotes(action.data.originalNotes, action.data.originalEvents);
				onSelectNote();

			case SELECT_NOTE:
				resetSelectedNotes();
				selectedNotes = (action.data.old != null) ? (cast action.data.old : Array<MetaNote>).copy() : [];
				selectedNotes = selectedNotes.filter((note:MetaNote) -> note != null && (!lockedEvents || !note.isEvent));
				onSelectNote();
		}
		showOutput('Undo #${currentUndo+1}: ${action.action}');
		FlxG.sound.play(Paths.sound('chartingSounds/undo'));
		currentUndo++;
	}
	function redo()
	{
		if(isMovingNotes || currentUndo < 1)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
			return;
		}

		currentUndo--;
		var action:UndoStruct = undoActions[currentUndo];
		switch(action.action)
		{
			case ADD_NOTE:
				actionPushNotes(action.data.notes, action.data.events);

			case DELETE_NOTE:
				actionRemoveNotes(action.data.notes, action.data.events);

			case MOVE_NOTE:
				actionRemoveNotes(action.data.originalNotes, action.data.originalEvents);
				actionPushNotes(action.data.movedNotes, action.data.movedEvents);
				onSelectNote();

			case SELECT_NOTE:
				resetSelectedNotes();
				selectedNotes = (action.data.current != null) ? (cast action.data.current : Array<MetaNote>).copy() : [];
				selectedNotes = selectedNotes.filter((note:MetaNote) -> note != null && (!lockedEvents || !note.isEvent));
				onSelectNote();
		}
		showOutput('Redo #${currentUndo+1}: ${action.action}');
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function actionPushNotes(dataNotes:Array<MetaNote>, dataEvents:Array<EventMetaNote>)
	{
		resetSelectedNotes();
		if(dataNotes != null && dataNotes.length > 0)
		{
			for (note in dataNotes)
			{
				if(note != null)
				{
					notes.push(note);
					selectedNotes.push(note);
					note.songData[0] = note.strumTime;
					positionNoteXByData(note);
				}
			}
			notes.sort(PlayState.sortByTime);
		}
		if(dataEvents != null && dataEvents.length > 0)
		{
			for (event in dataEvents)
			{
				if(event != null)
				{
					events.push(event);
					selectedNotes.push(event);
					event.songData[0] = event.strumTime;
				}
			}
			events.sort(PlayState.sortByTime);
		}
		softReloadNotes();
	}

	function actionRemoveNotes(dataNotes:Array<MetaNote>, dataEvents:Array<EventMetaNote>)
	{
		if(dataNotes != null && dataNotes.length > 0)
		{
			for (note in dataNotes)
			{
				if(note != null)
				{
					notes.remove(note);
					selectedNotes.remove(note);

					if(note.exists)
					{
						note.colorTransform.redMultiplier = note.colorTransform.greenMultiplier = note.colorTransform.blueMultiplier = 1;
						if(note.animation.curAnim != null) note.animation.curAnim.curFrame = 0;
					}
				}

			}
		}
		if(dataEvents != null && dataEvents.length > 0)
		{
			for (event in dataEvents)
			{
				if(event != null)
				{
					events.remove(event);
					selectedNotes.remove(event);

					if(event.exists)
					{
						event.colorTransform.redMultiplier = event.colorTransform.greenMultiplier = event.colorTransform.blueMultiplier = 1;
						if(event.animation.curAnim != null) event.animation.curAnim.curFrame = 0;
					}
				}
			}
		}
		onSelectNote();
		softReloadNotes();
	}

	function actionReplaceNotes(oldNote:MetaNote, newNote:MetaNote)
	{
		for (act in undoActions)
		{
			for (field in Reflect.fields(act.data))
			{
				var fld:Array<MetaNote> = cast Reflect.field(act.data, field);
				if(fld != null && fld.length > 0)
					for (num => actNote in fld)
						if(actNote == oldNote)
							fld[num] = newNote;
			}
		}
	}

	// Ported from the old chart editor
	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];
	function waveformColorOf(key:String, fallback:String):String
	{
		var saved:Dynamic = Reflect.field(chartEditorSave.data, key);
		if(saved == null || Std.string(saved).length < 1) return fallback;

		return Std.string(saved);
	}

	function updateWaveform() {
		#if (lime_cffi && !macro)
		var validSec:Bool = (curSec >= 0 && curSec + 1 < cachedSectionTimes.length);
		var height:Int = Std.int(gridBg.height);
		var fullWidth:Int = Std.int(GRID_SIZE * GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS);

		drawWaveformInto(waveformSprite, FlxG.sound.music, fullWidth, height, validSec && waveformEnabled);
		drawWaveformInto(waveformOppSprite, opponentVocals, WAVE_STRIP, height, validSec && waveformOppEnabled);
		drawWaveformInto(waveformPlayerSprite, vocals, WAVE_STRIP, height, validSec && waveformPlayerEnabled);
		#else
		waveformSprite.visible = false;
		waveformOppSprite.visible = false;
		waveformPlayerSprite.visible = false;
		#end
	}

	function drawWaveformInto(sprite:FlxSprite, sound:FlxSound, width:Int, height:Int, enabled:Bool)
	{
		#if (lime_cffi && !macro)
		if(sprite == null) return;

		if(!enabled || width < 1 || height < 1)
		{
			sprite.visible = false;
			return;
		}

		@:privateAccess
		if(sound == null || sound._sound == null || sound._sound.__buffer == null)
		{
			sprite.visible = false;
			return;
		}

		sprite.visible = true;
		sprite.y = gridBg.y;

		if(Std.int(sprite.width) != width || Std.int(sprite.height) != height)
		{
			if(sprite.pixels != null)
			{
				sprite.pixels.dispose();
				sprite.pixels.disposeImage();
			}
			sprite.makeGraphic(width, height, 0x00FFFFFF, true);
		}
		sprite.pixels.fillRect(new Rectangle(0, 0, width, height), 0x00FFFFFF);

		wavData[0][0].resize(0);
		wavData[0][1].resize(0);
		wavData[1][0].resize(0);
		wavData[1][1].resize(0);

		@:privateAccess
		var bytes:Bytes = sound._sound.__buffer.data.toBytes();
		@:privateAccess
		wavData = waveformData(sound._sound.__buffer, bytes, cachedSectionTimes[curSec] - Conductor.offset, cachedSectionTimes[curSec + 1] - Conductor.offset, 1, wavData, height);

		var gSize:Int = width;
		var hSize:Int = Std.int(gSize / 2);
		var size:Float = 1;

		var leftLength:Int = (wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length);
		var rightLength:Int = (wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length);
		var length:Int = leftLength > rightLength ? leftLength : rightLength;

		for (index in 0...length)
		{
			var lmin:Float = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var lmax:Float = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			var rmin:Float = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var rmax:Float = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			sprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), index * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.WHITE);
		}
		#end
	}

	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>, ?steps:Float):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];

		var khz:Float = (buffer.sampleRate / 1000);
		var channels:Int = buffer.channels;
		if (channels < 1) channels = 1;
		var maxSamples:Int = Std.int(bytes.length / (channels * 2)) - 1;

		var index:Int = Std.int(time * khz);

		var samples:Float = ((endTime - time) * khz);

		if (steps == null) steps = 1280;

		var samplesPerRow:Float = samples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = true;//samples > 17200;
		var v1:Bool = false;

		if (array == null) array = [[[0], [0]], [[0], [0]]];

		while (index < maxSamples) {
			if (index >= 0) {
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2) byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0) {
					if (sample > lmax) lmax = sample;
				} else if (sample < 0) {
					if (sample < lmin) lmin = sample;
				}

				if (channels >= 2) {
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2) byte -= 65535;

					sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}

			v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
			while (simpleSample ? v1 : rows >= samplesPerRow) {
				v1 = false;
				rows -= samplesPerRow;

				gotIndex++;

				var lRMin:Float = Math.abs(lmin) * multiply;
				var lRMax:Float = lmax * multiply;

				var rRMin:Float = Math.abs(rmin) * multiply;
				var rRMax:Float = rmax * multiply;

				if (gotIndex > array[0][0].length) array[0][0].push(lRMin);
					else array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

				if (gotIndex > array[0][1].length) array[0][1].push(lRMax);
					else array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

				if (channels >= 2)
				{
					if (gotIndex > array[1][0].length) array[1][0].push(rRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(rRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
				}
				else
				{
					if (gotIndex > array[1][0].length) array[1][0].push(lRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(lRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
				}

				lmin = 0;
				lmax = 0;

				rmin = 0;
				rmax = 0;
			}

			index++;
			rows++;
			if(gotIndex > steps) break;
		}

		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}
}