package funkin.editors;

import haxe.Json;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.tweens.FlxTween;

import funkin.game.notes.Note;
import funkin.game.notes.StrumNote;
import funkin.game.notes.NotePack;
import funkin.data.Song;
import funkin.data.Song.SwagSection;
import funkin.data.Song.ExtraCharacterData;
import funkin.game.notes.ExtraStrumlineLayout;
import funkin.ui.psychui.PsychUIInputText.FilterMode;
import funkin.editors.content.Prompt;
import funkin.editors.content.FileDialogHandler;
import funkin.editors.content.EditorSongs;
import funkin.editors.content.ModchartStartupPrompt;
import flixel.util.FlxSave;

import modcharting.Modifier;
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

typedef EffectInfo = {
	var desc:String;
	var value:String;
	var sub:String;
}

class ModchartEditorState extends MusicBeatState
{
	static inline final PREVIEW_X:Int = 8;
	static inline final PREVIEW_Y:Int = 28;
	static inline final PREVIEW_H:Int = 452;
	static inline final SIDE_X:Int = 820;
	static inline final SIDE_W:Int = 452;
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
	static inline final MAX_PLAYFIELDS:Int = 16;
	static inline final PLAYHEAD_RATIO:Float = 0.2;
	static inline final MIN_ZOOM:Float = 12;
	static inline final MAX_ZOOM:Float = 240;
	static inline final MAX_UNDO:Int = 100;
	static inline final MAIN_VALUE:String = '(Value)';
	public static inline final ALL_PLAYFIELDS:String = 'All playfields';

	static inline final DRAG_NONE:Int = 0;
	static inline final DRAG_MOVE:Int = 1;
	static inline final DRAG_RESIZE:Int = 2;
	static inline final DRAG_PLAYBAR:Int = 3;

	static inline final COLOR_SET:FlxColor = 0xFF5EC8FF;
	static inline final COLOR_EASE:FlxColor = 0xFFFFFFFF;
	static inline final COLOR_SELECTED:FlxColor = 0xFFFFD84A;

	static final SNAP_LABELS:Array<String> = ['1 beat', '1/2 beat', '1/4 beat', '1/8 beat', '1/16 beat', 'None'];
	static final SNAP_VALUES:Array<Float> = [1, 0.5, 0.25, 0.125, 0.0625, 0];

	public static final TYPE_LABELS:Array<String> = ['All', 'Player', 'Opponent', 'Lane'];

	static final BUILT_IN_MODIFIERS:Array<Class<Modifier>> = [
		XModifier, YModifier, ZModifier, ConfusionModifier,
		ScaleModifier, ScaleXModifier, ScaleYModifier, MiniModifier,
		StealthModifier, NoteStealthModifier, ReverseModifier, InvertModifier, FlipModifier,
		DrunkXModifier, DrunkYModifier, DrunkZModifier,
		TipsyXModifier, TipsyYModifier, TipsyZModifier,
		BeatXModifier, BeatYModifier, BeatZModifier, JumpModifier,
		RotateModifier, StrumLineRotateModifier, IncomingAngleModifier,
		SpeedModifier, BoostModifier, BrakeModifier, ShrinkModifier, BumpyModifier,
		BounceXModifier, BounceYModifier, BounceZModifier, InvertSineModifier,
		EaseCurveModifier, EaseCurveXModifier, EaseCurveYModifier, EaseCurveZModifier, EaseCurveAngleModifier
	];

	static final EFFECTS:Map<String, EffectInfo> = [
		'X' => {desc: 'Tween Note X Position, in pixels (default: 0)', value: '100', sub: ''},
		'Y' => {desc: 'Tween Note Y Position, in pixels (default: 0)', value: '100', sub: ''},
		'Z' => {desc: 'Tween Note Z Position (aka size), in pixels (default: 0)', value: '200', sub: ''},
		'Confusion' => {desc: 'SPEEEENNNNN!\nNote Spin modifier, in degrees (default: 0)', value: '360', sub: ''},
		'Scale' => {desc: 'Note Scale X/Y modifier (default: 1)', value: '0.5', sub: ''},
		'ScaleX' => {desc: 'Note Scale X modifier (default: 1)', value: '2', sub: ''},
		'ScaleY' => {desc: 'Note Scale Y modifier (default: 1)', value: '2', sub: ''},
		'Mini' => {desc: 'Note Scale X/Y modifier (default: 1)\nSimilar to "Scale" but strums shift in position when scaled instead of being centered', value: '0.5', sub: ''},
		'Stealth' => {desc: 'Note Alpha modifier (default: 0)\nAffects both notes & strums', value: '1', sub: ''},
		'NoteStealth' => {desc: 'Note Alpha modifier (default: 0)\nOnly affects notes', value: '1', sub: ''},
		'Reverse' => {desc: 'Changes strumlines position, affects scroll (default: 0)\nCan be used for easy Downscroll switch', value: '1', sub: ''},
		'Invert' => {desc: 'Swap note position (left-down, up-right) (default: 0)', value: '1', sub: ''},
		'Flip' => {desc: 'Mirrors strumline notes (right/up/down/left) (default: 0)', value: '1', sub: ''},
		'DrunkX' => {desc: 'I drank a beer. Another beer. 3 beers, 4 beers, 5 BEERS, 67 BEERS\nDrunk modifier on X axis\nSpeed = velocity of effect\n(default: 0)', value: '1', sub: ''},
		'DrunkY' => {desc: 'I drank a beer. Another beer. 3 beers, 4 beers, 5 BEERS, 67 BEERS\nDrunk modifier on Y axis\nSpeed: velocity of effect\n(default: 0)', value: '1', sub: ''},
		'DrunkZ' => {desc: 'I drank a beer. Another beer. 3 beers, 4 beers, 5 BEERS, 67 BEERS\nDrunk modifier on Z axis\nSpeed: velocity of effect\n(default: 0)', value: '1', sub: ''},
		'TipsyX' => {desc: 'Tipsy modifier on X axis\nMoves the notes funny (default: 0)', value: '1', sub: ''},
		'TipsyY' => {desc: 'Tipsy modifier on Y axis\nMoves the notes funny (default: 0)', value: '1', sub: ''},
		'TipsyZ' => {desc: 'Tipsy modifier on Z axis\nMoves the notes funny (default: 0)', value: '1', sub: ''},
		'BeatX' => {desc: 'Dope ass effect on beat, X axis (default: 0)', value: '2', sub: ''},
		'BeatY' => {desc: 'Dope ass effect on beat, Y axis (default: 0)', value: '2', sub: ''},
		'BeatZ' => {desc: 'Dope ass effect on beat, Z axis (default: 0)', value: '2', sub: ''},
		'Jump' => {desc: 'Notes go bunny hopping LOL (default: 0)', value: '1', sub: ''},
		'Rotate' => {desc: 'Notes rotate funny, in degrees (default: 1)', value: '45', sub: 'x'},
		'StrumLineRotate' => {desc: 'Notes rotate SUPER funny, in degrees (default: 1)\n"What changes from Rotate?" Nothing, lol', value: '45', sub: 'x'},
		'IncomingAngle' => {desc: 'Note direction tween (default: 1)', value: '45', sub: 'x'},
		'Speed' => {desc: 'Scrool speed modifier, similar to Chart Editor (default: 1)', value: '2', sub: ''},
		'Boost' => {desc: 'Notes get faster closer to strumline (default: 0)', value: '1', sub: ''},
		'Brake' => {desc: 'Notes get slower closer to strumline (default: 0)', value: '1', sub: ''},
		'Shrink' => {desc: 'Notes shrink and resize closer to strumline (default: 0)\nIf negative, notes grow instead', value: '1', sub: ''},
		'Bumpy' => {desc: 'buckle up, road\'s gonna be bumpy :D\nSpeed: velocity of effect\n(default: 0)', value: '1', sub: ''},
		'BounceX' => {desc: 'Notes bounce sideways\nSpeed: velocity of effect\n(default: 0)', value: '1', sub: ''},
		'BounceY' => {desc: 'Notes bounce up and down\nSpeed: velocity of effect\n(default: 0)', value: '1', sub: ''},
		'BounceZ' => {desc: 'Notes BOUNCE, we\'re BOUNCING now?\nSpeed: velocity of effect\n(default: 0)', value: '1', sub: ''},
		'InvertSine' => {desc: 'I\'m getting tired of ts cuh...\nNotes dance funny (default: 0)', value: '1', sub: ''},
		'EaseCurve' => {desc: 'Base for EaseCurve events, USE THIS BEFORE THE OTHERS!', value: '1', sub: ''},
		'EaseCurveX' => {desc: 'I have no idea bruh.', value: '100', sub: ''},
		'EaseCurveY' => {desc: 'This whole shit was vibe-coded please somebody grab this engine and make it real', value: '100', sub: ''},
		'EaseCurveZ' => {desc: 'I\'m a fat chud and I got no wife', value: '100', sub: ''},
		'EaseCurveAngle' => {desc: 'ANGLE.', value: '100', sub: ''}
	];

	static final EXAMPLE_MODCHART:String = '{"modifiers":['
		+ '["slide","XModifier","player",-1],'
		+ '["spin","ConfusionModifier","all",-1],'
		+ '["drunk","DrunkXModifier","opponent",-1],'
		+ '["reverse","ReverseModifier","player",-1]'
		+ '],"events":['
		+ '["ease",[4,2,"cubeInOut","-200,slide"],[false,1,0]],'
		+ '["ease",[8,2,"cubeInOut","0,slide"],[false,1,0]],'
		+ '["ease",[12,4,"quadInOut","360,spin"],[false,1,0]],'
		+ '["set",[16,"0,spin"],[false,1,0]],'
		+ '["ease",[16,1,"sineOut","1,drunk"],[false,1,0]],'
		+ '["ease",[20,2,"expoOut","1,reverse"],[false,1,0]],'
		+ '["ease",[24,1,"sineIn","0,drunk"],[false,1,0]],'
		+ '["ease",[28,2,"expoOut","0,reverse"],[false,1,0]]'
		+ '],"playfields":1}';

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

	static final GUIDE_TEXT:String = 'QUICK START\n'
		+ '\n'
		+ '1. Press "New" to create a MODIFIER. Choose an effect and what arrows it affects, and give it a name.\n'
		+ '\n'
		+ '2. Below preview, add an EVENT with RIGHT CLICK on the modifier row.\n'
		+ '\n'
		+ '3. Clicking an event opens its SETTINGS in this panel. Customize however you want!\n'
		+ '\n'
		+ '4. To reset an event\'s values, create a new one after the previous with value 0.\n'
		+ '\n'
		+ 'It\'s that easy, ha ha!\n'
		+ 'Press SPACE to preview modchart.\n'
		+ '\n'
		+ 'For a quick example, go to "File > Example Modchart" and tweak around!\n'
		+ '\n'
		+ 'Press F1 for more info.';

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
	var playfieldCountText:FlxText;
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

	var interactiveWidgets:Array<FlxSprite> = [];
	var propsEmptyText:FlxText;
	var propsWidgets:Array<FlxSprite> = [];
	var easeWidgets:Array<FlxSprite> = [];
	var subWidgets:Array<FlxSprite> = [];
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
	var effectTitleText:FlxText;
	var effectDescText:FlxText;
	var knownModNames:String = null;
	var knownSubMod:String = null;

	var fileDialog:FileDialogHandler = new FileDialogHandler();
	var hasUnsaved:Bool = false;
	var loadedModifiers:String = null;
	var loadedPlayfields:Int = -1;
	var statusText:FlxText;
	var messageTime:Float = 0;

	var helpBg:FlxSprite;
	var helpText:FlxText;
	var helpPageText:FlxText;
	var helpPage:Int = 0;

	public static var skipStartupMenu:Bool = false;
	var showStartup:Bool = true;

	var editorLoop:FlxSound = new FlxSound();
	var editorLoopTimer:FlxTimer;
	var editorMusicMuted:Bool = false;
	var instVolumeSlider:PsychUISlider;
	var playerVolumeSlider:PsychUISlider;
	var opponentVolumeSlider:PsychUISlider;
	var hitsoundPlayerSlider:PsychUISlider;
	var hitsoundOpponentSlider:PsychUISlider;
	var instMuteCheckBox:PsychUICheckBox;
	var playerMuteCheckBox:PsychUICheckBox;
	var opponentMuteCheckBox:PsychUICheckBox;

	override function create()
	{
		NotePack.clearCache();
		showStartup = !skipStartupMenu;
		skipStartupMenu = false;

		initPsychCamera().bgColor = 0xFF1B1B22;

		var previewZoom:Float = PREVIEW_H / FlxG.height;
		camPreview = new FlxCamera(PREVIEW_X, PREVIEW_Y, FlxG.width, FlxG.height, previewZoom);
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
		generateExtraStrums();

		loadedModifiers = Json.stringify(modchartData().modifiers);
		loadedPlayfields = modchartData().playfields;
		hasUnsaved = (ModchartFile.editorData != null && ModchartFile.editorDataSong == songKey());

		createTimeline();
		createPlaybar();
		createInfoPanel();
		createPropertiesPanel();
		createUpperMenu();
		createHelp();

		refreshTimelineData();
		refreshProps();
		super.create();

		editorMusicMuted = EditorHelper.isEditorMusicMuted();
		FlxG.sound.list.add(editorLoop);
		editorLoop.loadEmbedded(Paths.music('chartEditorLoop'), true, false);
		editorLoop.autoDestroy = false;
		editorLoop.volume = 0;
		scheduleEditorLoop(showStartup ? 1 : 10);
		updateAudioVolume();

		var data:ModchartJson = modchartData();
		if(data.modifiers.length > 0 || data.events.length > 0) pushRecent();
		if(showStartup) openStartupPrompt();
	}

	static function bindModchartSave():FlxSave
	{
		var save:FlxSave = new FlxSave();
		save.bind('modchart_editor_data', CoolUtil.getSavePath());
		return save;
	}

	static function recentEntries():Array<String>
	{
		var save:FlxSave = bindModchartSave();
		var list:Array<String> = save.data.recentModcharts;
		save.close();
		return (list != null) ? list.copy() : [];
	}

	function pushRecent()
	{
		var song:String = EditorSongs.baseSongOf(PlayState.SONG.song);
		var diff:String = Difficulty.getString(PlayState.storyDifficulty, false);
		if(diff == null || diff.length < 1) diff = Difficulty.getDefault();
		var entry:String = song + '|' + diff;
		var list:Array<String> = recentEntries();
		list.remove(entry);
		list.insert(0, entry);
		while(list.length > 10) list.pop();

		var save:FlxSave = bindModchartSave();
		save.data.recentModcharts = list;
		save.flush();
		save.close();
	}

	var startupPrompt:ModchartStartupPrompt;
	function openStartupPrompt()
	{
		var entries:Array<String> = recentEntries();
		var labels:Array<String> = [for (entry in entries) entry.split('|').join(' - ')];

		startupPrompt = new ModchartStartupPrompt(PlayState.SONG.song);
		startupPrompt.persistentDraw = false;
		startupPrompt.onOpenRecent = function(i:Int)
		{
			var parts:Array<String> = entries[i].split('|');
			openSong(parts[0], parts.length > 1 ? parts[1] : Difficulty.getDefault());
		};
		startupPrompt.onFromSong = function()
		{
			var songPrompt:ModchartSongPrompt = new ModchartSongPrompt();
			songPrompt.onLoad = openSong;
			startupPrompt.openSubState(songPrompt);
		};
		openSubState(startupPrompt);
		startupPrompt.setRecents(labels);
	}

	function openSong(song:String, diff:String):Bool
	{
		var savedDiffs:Array<String> = Difficulty.list.copy();
		var savedIndex:Int = PlayState.storyDifficulty;
		if(!EditorSongs.loadChart(song, diff))
		{
			Difficulty.list = savedDiffs;
			PlayState.storyDifficulty = savedIndex;
			showMessage('Could not load "$song" ($diff): Chart not found!', true);
			return false;
		}

		ModchartFile.editorData = null;
		stopAudio();
		skipStartupMenu = true;
		MusicBeatState.switchState(new ModchartEditorState());
		return true;
	}

	function scheduleEditorLoop(delay:Float)
	{
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

	function stopEditorLoopFade()
	{
		if(editorLoopTimer != null)
		{
			editorLoopTimer.cancel();
			editorLoopTimer = null;
		}
		if(editorLoop.fadeTween != null)
		{
			editorLoop.fadeTween.cancel();
			editorLoop.fadeTween = null;
		}
	}

	function muteEditorLoop()
	{
		stopEditorLoopFade();
		editorLoop.volume = 0;
	}

	inline function sliderVolume(slider:PsychUISlider):Float
		return FlxMath.bound(slider.value / 100, 0, 1);

	function updateAudioVolume()
	{
		if(instVolumeSlider == null) return;
		FlxG.sound.music.volume = instMuteCheckBox.checked ? 0 : sliderVolume(instVolumeSlider);
		vocals.volume = playerMuteCheckBox.checked ? 0 : sliderVolume(playerVolumeSlider);
		opponentVocals.volume = opponentMuteCheckBox.checked ? 0 : sliderVolume(opponentVolumeSlider);
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

		var lines:Array<ExtraCharacterData> = Song.separateCharacters(PlayState.SONG);
		for (section in PlayState.SONG.notes)
		{
			for (songNotes in section.sectionNotes)
			{
				var column:Int = Std.int(songNotes[1]);
				var line:Int = (column > 7) ? Std.int((column - 8) / 4) : -1;
				if(column < 0 || line >= lines.length) continue;

				var strumTime:Float = songNotes[0];
				var noteData:Int = column % 4;
				var mustPress:Bool = (line >= 0) ? ExtraStrumlineLayout.playable(lines[line]) : (column < 4);
				var shown:Bool = (line < 0 || lines[line].visible != false);

				var oldNote:Note = (unspawnNotes.length > 0) ? unspawnNotes[unspawnNotes.length - 1] : null;
				var packOpponent:Bool = (line >= 0) ? !ExtraStrumlineLayout.isPlayer(lines[line], false) : (column >= 4);
				var note:Note = new Note(strumTime, noteData, oldNote, false, false, null, packOpponent);
				note.sustainLength = Math.isNaN(songNotes[2]) ? 0 : songNotes[2];
				note.mustPress = mustPress;
				note.gfNote = (section.gfSection && mustPress == section.mustHitSection);
				note.noteType = songNotes[3];
				if(!Std.isOfType(songNotes[3], String)) note.noteType = Note.defaultNoteTypes[songNotes[3]];
				note.scrollFactor.set();
				note.strumline = line;
				note.visible = shown;
				unspawnNotes.push(note);

				var susLength:Int = Math.floor(note.sustainLength / Conductor.stepCrochet);
				if(susLength > 0)
				{
					for (susNote in 0...susLength + 1)
					{
						oldNote = unspawnNotes[unspawnNotes.length - 1];
						var sustain:Note = new Note(strumTime + (Conductor.stepCrochet * susNote) + (Conductor.stepCrochet / FlxMath.roundDecimal(PlayState.SONG.speed, 2)), noteData, oldNote, true, false, null, packOpponent);
						sustain.mustPress = mustPress;
						sustain.gfNote = note.gfNote;
						sustain.noteType = note.noteType;
						sustain.strumline = line;
						sustain.visible = shown;
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

	function generateExtraStrums()
	{
		var lines:Array<ExtraCharacterData> = Song.separateCharacters(PlayState.SONG);
		var mainScale:Float = ExtraStrumlineLayout.sharesMainRow(lines) ? ExtraStrumlineLayout.fitMainRow(cast opponentStrums, cast playerStrums) : 1;
		var lineScales:Array<Float> = [];
		for (line in ExtraStrumlineLayout.create(lines, false, false))
		{
			for (strum in line.strums.members) strumLineNotes.add(strum);
			lineScales.push(line.scale);
		}

		NoteMovement.getDefaultStrumPosFromGroup(strumLineNotes, playerStrums.length, opponentStrums.length);
		var firstLane:Int = opponentStrums.length + playerStrums.length;
		for (lane in 0...NoteMovement.defaultScale.length)
		{
			var scale:Float = (lane < firstLane) ? mainScale : lineScales[Std.int((lane - firstLane) / 4)];
			NoteMovement.defaultScale[lane] *= scale;
			NoteMovement.arrowSizes[lane] *= scale;
		}
		NoteMovement.characterLanes = [for (k => data in lines) data.slot => firstLane + k * 4];
		playfieldRenderer.modifierTable.refreshLanes();
	}

	public function characterTargetLabels():Array<String>
		return [for (data in Song.separateCharacters(PlayState.SONG)) 'Char ' + data.slot];

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

		rowsInfoText = new FlxText(PANEL_X + 6, PANEL_Y + 3, LABEL_W - 66, '', 9);
		rowsInfoText.color = 0xFFBBBBBB;
		rowsInfoText.cameras = [camUI];
		add(rowsInfoText);

		var newButton:PsychUIButton = new PsychUIButton(PANEL_X + LABEL_W - 58, PANEL_Y + 1, 'New', function() openModifierPopup(-1), 54, 16);
		newButton.cameras = [camUI];
		interactiveWidgets.push(newButton);
		add(newButton);

		timelineLayer = new FlxTypedGroup<FlxSprite>();
		timelineLayer.cameras = [camUI];
		add(timelineLayer);

		emptyText = new FlxText(gridX(), rowY(3), gridW(), 'Modchart is empty.\nPress "NEW" to add a modifier.', 14);
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

		var title:FlxText = new FlxText(INFO_X, PANEL_Y + 4, INFO_W, 'Info', 12);
		title.alignment = CENTER;
		title.cameras = [camUI];
		add(title);

		playfieldCountText = new FlxText(INFO_X + 10, PANEL_Y + 29, 150, '', 10);
		playfieldCountText.cameras = [camUI];
		add(playfieldCountText);

		var removeButton:PsychUIButton = new PsychUIButton(INFO_X + INFO_W - 60, PANEL_Y + 26, '-', function() changePlayfields(-1), 22);
		removeButton.cameras = [camUI];
		interactiveWidgets.push(removeButton);
		add(removeButton);

		var addButton:PsychUIButton = new PsychUIButton(INFO_X + INFO_W - 34, PANEL_Y + 26, '+', function() changePlayfields(1), 22);
		addButton.cameras = [camUI];
		interactiveWidgets.push(addButton);
		add(addButton);

		var showLabel:FlxText = new FlxText(INFO_X + 10, PANEL_Y + 55, 70, 'Show:', 10);
		showLabel.cameras = [camUI];
		add(showLabel);

		var snapLabel:FlxText = new FlxText(INFO_X + 10, PANEL_Y + 81, 70, 'Snap:', 10);
		snapLabel.cameras = [camUI];
		add(snapLabel);

		infoText = new FlxText(INFO_X + 10, PANEL_Y + 108, INFO_W - 20, '', 10);
		infoText.cameras = [camUI];
		add(infoText);

		snapDropDown = new PsychUIDropDownMenu(INFO_X + 80, PANEL_Y + 78, SNAP_LABELS, function(index:Int, _) {
			snap = SNAP_VALUES[index];
		}, 140);
		snapDropDown.selectedLabel = '1/4 beat';
		snapDropDown.cameras = [camUI];
		interactiveWidgets.push(snapDropDown);
		add(snapDropDown);

		playfieldDropDown = new PsychUIDropDownMenu(INFO_X + 80, PANEL_Y + 52, [ALL_PLAYFIELDS], function(_, label:String) {
			playfieldFilter = playfieldFromLabel(label);
			rowScroll = 0;
			refreshTimelineData();
		}, 140);
		playfieldDropDown.cameras = [camUI];
		interactiveWidgets.push(playfieldDropDown);
		add(playfieldDropDown);
	}

	public static function playfieldFromLabel(label:String):Int
	{
		if(label == null || label == ALL_PLAYFIELDS) return -1;
		return parseIntSafe(label.replace('Playfield ', ''), -1);
	}

	public function playfieldLabels():Array<String>
	{
		var labels:Array<String> = [ALL_PLAYFIELDS];
		for (i in 0...modchartData().playfields) labels.push('Playfield ' + i);
		return labels;
	}

	function createPropertiesPanel()
	{
		var panel:FlxSprite = new FlxSprite(SIDE_X, PREVIEW_Y).makeGraphic(SIDE_W, PREVIEW_H, 0xFF26262F);
		panel.cameras = [camUI];
		add(panel);

		var title:FlxText = new FlxText(SIDE_X, PREVIEW_Y + 4, SIDE_W, 'Event', 12);
		title.alignment = CENTER;
		title.cameras = [camUI];
		add(title);

		propsEmptyText = new FlxText(SIDE_X + 14, PREVIEW_Y + 30, SIDE_W - 28, GUIDE_TEXT, 10);
		propsEmptyText.color = 0xFFDDDDDD;
		propsEmptyText.cameras = [camUI];
		add(propsEmptyText);

		var left:Float = SIDE_X + 10;
		var col1:Float = SIDE_X + 80;
		var col2Label:Float = SIDE_X + 236;
		var col2:Float = SIDE_X + 306;

		propLabel(left, 30, 'Type:');
		typeDropDown = propWidget(new PsychUIDropDownMenu(col1, PREVIEW_Y + 30, ['set', 'ease'], function(_, label:String) setEventType(label), 100));

		propLabel(col2Label, 30, 'Beat:');
		beatStepper = propWidget(new PsychUINumericStepper(col2, PREVIEW_Y + 30, 0.25, 0, 0, 9999, 3, 70));
		beatStepper.onValueChange = function() {
			editSelected('beat', function(ev:Array<Dynamic>) {
				ev[ModchartFile.EVENT_DATA][ModchartFile.EVENT_TIME] = beatStepper.value;
			});
		};

		propLabel(left, 56, 'Length:', easeWidgets);
		lengthStepper = propWidget(new PsychUINumericStepper(col1, PREVIEW_Y + 56, 0.25, 1, 0, 999, 3, 70), easeWidgets);
		lengthStepper.onValueChange = function() {
			editSelected('length', function(ev:Array<Dynamic>) {
				ev[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASETIME] = lengthStepper.value;
			});
		};

		propLabel(col2Label, 56, 'Ease:', easeWidgets);
		easeDropDown = propWidget(new PsychUIDropDownMenu(col2, PREVIEW_Y + 56, EASES, function(_, label:String) {
			editSelected(null, function(ev:Array<Dynamic>) {
				ev[ModchartFile.EVENT_DATA][ModchartFile.EVENT_EASE] = label;
			});
		}, 110), easeWidgets);

		repeatCheckBox = propWidget(new PsychUICheckBox(left, PREVIEW_Y + 85, 'Repeat', 60));
		repeatCheckBox.onClick = function() {
			editSelected(null, function(ev:Array<Dynamic>) {
				repeatData(ev)[ModchartFile.EVENT_REPEATBOOL] = repeatCheckBox.checked;
			});
		};

		propLabel(SIDE_X + 100, 84, 'Times:');
		repeatCountStepper = propWidget(new PsychUINumericStepper(SIDE_X + 150, PREVIEW_Y + 84, 1, 1, 1, 999, 0, 40));
		repeatCountStepper.onValueChange = function() {
			editSelected('repeatCount', function(ev:Array<Dynamic>) {
				repeatData(ev)[ModchartFile.EVENT_REPEATCOUNT] = Std.int(repeatCountStepper.value);
			});
		};

		propLabel(col2Label, 84, 'Every:');
		repeatGapStepper = propWidget(new PsychUINumericStepper(col2, PREVIEW_Y + 84, 0.25, 1, 0, 999, 3, 50));
		repeatGapStepper.onValueChange = function() {
			editSelected('repeatGap', function(ev:Array<Dynamic>) {
				repeatData(ev)[ModchartFile.EVENT_REPEATBEATGAP] = repeatGapStepper.value;
			});
		};
		propLabel(col2 + 88, 84, 'beats');

		propWidget(new FlxSprite(left, PREVIEW_Y + 114).makeGraphic(SIDE_W - 20, 1, 0xFF4A4A5A));

		var header:FlxText = propLabel(left, 120, 'Event Description');
		header.fieldWidth = 200;
		header.color = COLOR_SELECTED;

		targetCountText = propLabel(SIDE_X + SIDE_W - 200, 120, '');
		targetCountText.fieldWidth = 136;
		targetCountText.alignment = RIGHT;
		propWidget(new PsychUIButton(SIDE_X + SIDE_W - 58, PREVIEW_Y + 118, '<', function() changeTarget(-1), 22));
		propWidget(new PsychUIButton(SIDE_X + SIDE_W - 32, PREVIEW_Y + 118, '>', function() changeTarget(1), 22));

		propLabel(left, 146, 'Modifier:');
		targetModDropDown = propWidget(new PsychUIDropDownMenu(col1, PREVIEW_Y + 146, [], function(_, label:String) {
			editTarget(null, function(target:TimelineTarget) {
				target.mod = label;
				target.sub = '';
			});
		}, 130));

		propLabel(col2Label, 146, 'Sub-value:', subWidgets);
		targetSubDropDown = propWidget(new PsychUIDropDownMenu(col2, PREVIEW_Y + 146, [MAIN_VALUE], function(_, label:String) {
			editTarget(null, function(target:TimelineTarget) {
				target.sub = (label == MAIN_VALUE) ? '' : label;
			});
		}, 110), subWidgets);

		propLabel(left, 172, 'Value:');
		targetValueInput = propWidget(new PsychUIInputText(col1, PREVIEW_Y + 172, 100, '', 8));
		targetValueInput.customFilterPattern = ~/[^0-9.\-]*/g;
		targetValueInput.filterMode = FilterMode.CUSTOM_FILTER;
		targetValueInput.onChange = function(_, cur:String) {
			if(Math.isNaN(Std.parseFloat(cur))) return;
			editTarget('value', function(target:TimelineTarget) {
				target.value = cur;
			});
		};

		propWidget(new PsychUIButton(SIDE_X + 196, PREVIEW_Y + 170, 'Add', addTarget, 124));
		propWidget(new PsychUIButton(SIDE_X + 326, PREVIEW_Y + 170, 'Remove', removeTarget, 116));

		targetsListText = propLabel(left, 200, '');
		targetsListText.fieldWidth = SIDE_W - 20;
		targetsListText.size = 9;
		targetsListText.color = 0xFFBBBBBB;

		propWidget(new FlxSprite(left, PREVIEW_Y + 250).makeGraphic(SIDE_W - 20, 1, 0xFF4A4A5A));

		effectTitleText = propLabel(left, 256, '');
		effectTitleText.fieldWidth = SIDE_W - 20;
		effectTitleText.color = COLOR_SELECTED;

		effectDescText = propLabel(left, 276, '');
		effectDescText.fieldWidth = SIDE_W - 20;
		effectDescText.color = 0xFFDDDDDD;

		var hint:FlxText = propLabel(left, 404, 'Right Click on Mark: Delete Modifier\n'
			+ 'DELETE: Remove Event\n'
			+ 'Ctrl+C/V: Copy/Paste');
		hint.fieldWidth = SIDE_W - 20;
		hint.size = 9;
		hint.color = 0xFF9A9AB0;

		var i:Int = propsWidgets.length;
		while(i-- > 0) add(propsWidgets[i]);
	}

	function propLabel(x:Float, y:Float, text:String, ?group:Array<FlxSprite>):FlxText
	{
		var label:FlxText = new FlxText(x, PREVIEW_Y + y + 3, 70, text, 10);
		return propWidget(label, group);
	}

	function propWidget<T:FlxSprite>(widget:T, ?group:Array<FlxSprite>):T
	{
		widget.cameras = [camUI];
		propsWidgets.push(widget);
		interactiveWidgets.push(widget);
		if(group != null) group.push(widget);
		return widget;
	}

	function createUpperMenu()
	{
		upperBox = new PsychUIBox(0, 0, 150, 90, ['File', 'Audio']);
		upperBox.scrollFactor.set();
		upperBox.isMinimized = true;
		upperBox.minimizeOnFocusLost = true;
		upperBox.canMove = false;
		upperBox.cameras = [camUI];
		upperBox.bg.visible = false;
		add(upperBox);

		var entries:Array<Array<Dynamic>> = [
			['  Save (Ctrl+S)', function() saveModchart(false)],
			['  Save As...', function() saveModchart(true)],
			['  Open Modchart', openModchartFile],
			['  Reload', reloadFromFile],
			['  Example Modchart', loadExample],
			['  Clear', clearModchart],
			['  Playtest (Enter)', goToPlayState],
			['  Exit', exitToMenu]
		];

		var menu = upperBox.getTab('File').menu;
		var panel:FlxSprite = new FlxSprite().makeGraphic(200, entries.length * 20 + 2, FlxColor.BLACK);
		panel.alpha = 0.8;
		menu.add(panel);

		for (i => entry in entries)
		{
			var btn:PsychUIButton = new PsychUIButton(0, i * 20, entry[0], entry[1], 200);
			btn.text.alignment = LEFT;
			menu.add(btn);
		}

		createAudioTab();
	}

	function createAudioTab()
	{
		var tab = upperBox.getTab('Audio');
		tab.menuOffsetX = 75;
		var menu = tab.menu;
		var labelX:Int = 8;
		var sliderX:Int = 105;
		var sliderWid:Int = 125;
		var muteX:Int = 235;
		var objY:Int = 18;
		var rowStep:Int = 36;

		var panel:FlxSprite = new FlxSprite().makeGraphic(300, 230, FlxColor.BLACK, true);
		panel.alpha = 0.8;
		menu.add(panel);

		var labels:Array<FlxText> = [];

		instVolumeSlider = new PsychUISlider(sliderX, objY, null, 60, 0, 100, sliderWid);
		instMuteCheckBox = new PsychUICheckBox(muteX, objY - 6, 'Mute', 60, updateAudioVolume);
		labels.push(new FlxText(labelX, objY - 2, 95, 'Inst.', 8));

		objY += rowStep;
		playerVolumeSlider = new PsychUISlider(sliderX, objY, null, 100, 0, 100, sliderWid);
		playerMuteCheckBox = new PsychUICheckBox(muteX, objY - 6, 'Mute', 60, updateAudioVolume);
		labels.push(new FlxText(labelX, objY - 2, 95, 'Player Vocals', 8));

		objY += rowStep;
		opponentVolumeSlider = new PsychUISlider(sliderX, objY, null, 100, 0, 100, sliderWid);
		opponentMuteCheckBox = new PsychUICheckBox(muteX, objY - 6, 'Mute', 60, updateAudioVolume);
		labels.push(new FlxText(labelX, objY - 2, 95, 'Opp. Vocals', 8));

		objY += rowStep;
		hitsoundPlayerSlider = new PsychUISlider(sliderX, objY, null, 0, 0, 100, sliderWid);
		labels.push(new FlxText(labelX, objY - 2, 95, 'Hitsound (P)', 8));

		objY += rowStep;
		hitsoundOpponentSlider = new PsychUISlider(sliderX, objY, null, 0, 0, 100, sliderWid);
		labels.push(new FlxText(labelX, objY - 2, 95, 'Hitsound (O)', 8));

		for (slider in [instVolumeSlider, playerVolumeSlider, opponentVolumeSlider, hitsoundPlayerSlider, hitsoundOpponentSlider])
		{
			slider.decimals = 0;
			slider.minText.visible = slider.maxText.visible = false;
			menu.add(slider);
		}
		for (slider in [instVolumeSlider, playerVolumeSlider, opponentVolumeSlider])
			slider.onChange = function(_) updateAudioVolume();

		menu.add(instMuteCheckBox);
		menu.add(playerMuteCheckBox);
		menu.add(opponentMuteCheckBox);
		for (txt in labels) menu.add(txt);

		objY += rowStep + 6;
		var musicCheckBox:PsychUICheckBox = new PsychUICheckBox(labelX + 2, objY, 'Mute Editor Music', 150);
		musicCheckBox.checked = editorMusicMuted;
		musicCheckBox.onClick = function()
		{
			editorMusicMuted = musicCheckBox.checked;
			EditorHelper.setEditorMusicMuted(editorMusicMuted);
			if(editorMusicMuted) muteEditorLoop();
			else if(!FlxG.sound.music.playing) scheduleEditorLoop(1);
		};
		menu.add(musicCheckBox);
	}

	function createHelp()
	{
		statusText = new FlxText(160, 4, 860, '', 12);
		statusText.setFormat(null, 12, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		statusText.cameras = [camUI];
		add(statusText);

		var hint:FlxText = new FlxText(0, 4, FlxG.width - 10, 'Press F1 for Help', 12);
		hint.setFormat(null, 12, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		hint.cameras = [camUI];
		hint.alpha = 0.6;
		add(hint);

		helpBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		helpBg.scale.set(FlxG.width, FlxG.height);
		helpBg.updateHitbox();
		helpBg.alpha = 0.85;
		helpBg.cameras = [camUI];
		helpBg.visible = false;
		add(helpBg);

		helpText = new FlxText(0, 0, FlxG.width - 140, '', 14);
		helpText.setFormat(null, 14, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		helpText.borderSize = 1;
		helpText.cameras = [camUI];
		helpText.visible = false;
		add(helpText);

		helpPageText = new FlxText(0, FlxG.height - 44, FlxG.width, '', 16);
		helpPageText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		helpPageText.cameras = [camUI];
		helpPageText.visible = false;
		add(helpPageText);
	}

	static final HELP_PAGES:Array<String> = [
		"BASIC EXPLANATION\n"
		+ "\n"
		+ "You should know already what a modchart is, so I'll be quick to explain.\n"
		+ "\n"
		+ "MODIFIERS are the effects applied to notes, having name and value (ex. \"slide\" - value: 1.5)\n"
		+ "Value 0/1 resets previous value if changed.\n"
		+ "OPTIONS: ALL/OPP/PLR/0-7/C\n"
		+ "Note: Opponent (0-3), Player (4-7), Extra strumlines (8+), C = Char N\n"
		+ "\n"
		+ "EVENTS change a MODIFIER's value at a certain beat. They can be placed in the event timeline below the preview.\n"
		+ "You can change its DURATION and EASING to your like.\n"
		+ "Remember: value 0 or 1 = resets value to default\n"
		+ "\n"
		+ "PLAYFIELDS are essentially \"copies\" of the base strumlines. Use them for crazy visual effects and stuff.\n"
		+ "\n"
		+ "Be sure to test ALL the modifiers before creating a modchart. If you don't know what you're doing, experiment and keep trying!\n"
		+ "\n"
		+ "Use the Example Modchart for a better understanding of how this editor works.",

		"CONTROLS\n"
		+ "\n"
		+ "PLAYBACK\n"
		+ "Space - Play/Pause\n"
		+ "A/D or LEFT/RIGHT - Move 1 beat forward/back\n"
		+ "Mouse Wheel - Scroll Timeline (Hold SHIFT to go faster)\n"
		+ "HOME/END - Go to Start/End of song\n"
		+ "[ / ] - Playback Speed (ALT to reset)\n"
		+ "Slider (below Preview) - Click or Drag to Move\n"
		+ "\n"
		+ "TIMELINE\n"
		+ "Ctrl + Mouse Wheel - Zoom\n"
		+ "Mouse Wheel on Name List - Scroll rows\n"
		+ "Click on Empty to Snap at Position\n"
		+ "\n"
		+ "Ctrl+S - Save\n"
		+ "Ctrl+Shift+S - Save As\n"
		+ "Ctrl+O - Open Modchart\n"
		+ "ENTER - Playtest\n"
		+ "ESC - Back to Song\n"
		+ "F1 - Open Help Menu",

		"EDITING\n"
		+ "\n"
		+ "MODIFIERS\n"
		+ "New - Create Modifier\n"
		+ "Click on Name - Edit/Delete\n"
		+ "-/+ (Information) - Remove/Add Playfield\n"
		+ "\n"
		+ "EVENTS\n"
		+ "Right Click on Row - New Event\n"
		+ "Click on Event - Select it\n"
		+ "Drag Event - Move it (Hold SHIFT to ignore snapping)\n"
		+ "Drag Event Tail - Change Duration\n"
		+ "SHIFT + (-/+) on Beat/Length/Every - Change by 0.01\n"
		+ "Right Click on Event - Remove Modifier from it\n"
		+ "DEL/BACKSPACE - Delete Event\n"
		+ "Ctrl+C/V - Copy/Paste at current position\n"
		+ "Ctrl+Z/Ctrl+Shift+Z - Undo/Redo\n"
		+ "\n"
		+ "One Event can change more Modifiers:\n"
		+ "use \"Add\" and < > in the Event panel."
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
			var labels:Array<String> = playfieldLabels();
			var lastLabel:String = playfieldDropDown.selectedLabel;
			playfieldDropDown.list = labels;
			playfieldDropDown.selectedLabel = (lastLabel != null && labels.contains(lastLabel)) ? lastLabel : ALL_PLAYFIELDS;
			playfieldCountText.text = 'Playfields: ' + data.playfields;

			if(playfieldFilter >= data.playfields)
			{
				playfieldFilter = -1;
				playfieldDropDown.selectedLabel = ALL_PLAYFIELDS;
				refreshTimelineData();
				return;
			}
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

	static function isEditableEvent(ev:Array<Dynamic>):Bool
	{
		var type:Dynamic = ev[ModchartFile.EVENT_TYPE];
		return (type == 'set' || type == 'ease');
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

	public static function effectInfo(effect:String):EffectInfo
	{
		var key:String = (effect != null) ? effect.replace('Modifier', '') : '';
		var info:EffectInfo = EFFECTS.get(key);
		if(info != null) return info;
		return {desc: 'Custom effect loaded.', value: '1', sub: ''};
	}

	function effectOfModifier(name:String):String
	{
		var index:Int = modIndex(name);
		return (index >= 0) ? Std.string(modchartData().modifiers[index][ModchartFile.MOD_CLASS]) : null;
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
		if(snap <= 0 || FlxG.keys.pressed.SHIFT) return FlxMath.roundDecimal(beat, 3);
		return FlxMath.roundDecimal(Math.round(beat / snap) * snap, 4);
	}

	override function update(elapsed:Float)
	{
		if(FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		var bpmChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
		var bpm:Float = (bpmChange.songTime <= 0) ? PlayState.SONG.bpm : bpmChange.bpm;
		if(bpm != Conductor.bpm) Conductor.bpm = bpm;

		var fineStep:Float = FlxG.keys.pressed.SHIFT ? 0.01 : 0.25;
		beatStepper.step = lengthStepper.step = repeatGapStepper.step = fineStep;

		lockUnderDropDown(interactiveWidgets);
		super.update(elapsed);

		if(PsychUIInputText.focusOn != lastFocus) editTag = null;
		updateStatus(elapsed);

		if(helpBg.visible) updateHelpInput();
		else
		{
			if(PsychUIInputText.focusOn == null && lastFocus == null) updateKeys();
			if(!Std.isOfType(lastFocus, PsychUIDropDownMenu)) updateMouse();
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
				note.extraData.remove(EDITOR_HIT);
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
			if(FlxG.keys.justPressed.S)
			{
				saveModchart(FlxG.keys.pressed.SHIFT);
				return;
			}
			if(FlxG.keys.justPressed.O)
			{
				openModchartFile();
				return;
			}
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
			else if(overLabels && my >= rowY(0))
			{
				var mod:Array<Dynamic> = visibleMods[rowScroll + Math.floor((my - rowY(0)) / ROW_H)];
				if(mod != null) openModifierPopup(modchartData().modifiers.indexOf(mod));
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
		var modchart:ModchartFile = playfieldRenderer.modchart;
		if(modchart.data.playfields != loadedPlayfields)
		{
			loadedPlayfields = modchart.data.playfields;
			modchart.loadPlayfields();
		}

		var modifiers:String = Json.stringify(modchart.data.modifiers);
		if(modifiers != loadedModifiers)
		{
			loadedModifiers = modifiers;
			modchart.loadModifiers();
			knownSubMod = null;
		}

		hasUnsaved = true;
		refreshTimelineData();
		refreshProps();
		dirtyEvents = true;
	}

	function defaultTarget(mod:String):TimelineTarget
	{
		var info:EffectInfo = effectInfo(effectOfModifier(mod));
		return {mod: mod, sub: info.sub, value: info.value};
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
		writeTargets(ev, [defaultTarget(mod)]);

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

		targets.push(defaultTarget(name));
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
		playfieldRenderer.modchart.data = cast Json.parse(state);
		editTag = null;
		if(selectedEvent >= modchartData().events.length) selectedEvent = -1;
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
		targetCountText.text = (targets.length > 1) ? '${curTarget + 1} of ${targets.length}' : '';

		var hasSubs:Bool = false;
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
			hasSubs = (targetSubDropDown.list.length > 1);
			setDropDown(targetSubDropDown, (target.sub.length > 0) ? target.sub : MAIN_VALUE);
			if(PsychUIInputText.focusOn != targetValueInput) targetValueInput.text = target.value;

			var effect:String = effectOfModifier(target.mod);
			effectTitleText.text = (effect != null) ? '"${target.mod}" - ${effect.replace('Modifier', '')} Effect' : 'Modifier "${target.mod}" doesn\'t exist!';
			effectDescText.text = (effect != null) ? effectInfo(effect).desc : 'Pick a modifier from list, or press "New" to create one.';
		}
		for (widget in subWidgets) setWidgetShown(widget, hasSubs);

		var lines:Array<String> = [];
		for (i => entry in targets)
			lines.push(((i == curTarget) ? '> ' : '   ') + entry.mod + ((entry.sub.length > 0) ? ':' + entry.sub : '') + ' = ' + entry.value);
		targetsListText.text = (targets.length > 1) ? lines.join('\n') : '';
	}

	public static function lockUnderDropDown(widgets:Array<FlxSprite>)
	{
		var openDropDown:PsychUIInputText = Std.isOfType(PsychUIInputText.focusOn, PsychUIDropDownMenu) ? PsychUIInputText.focusOn : null;
		for (widget in widgets)
			widget.active = widget.visible && (openDropDown == null || widget == openDropDown);
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

	function openModifierPopup(index:Int)
	{
		PsychUIInputText.focusOn = null;
		if(FlxG.sound.music.playing) setPlaying(false);
		openSubState(new ModifierPopup(this, index));
	}

	public function effectList():Array<String>
	{
		var list:Array<String> = [for (cls in BUILT_IN_MODIFIERS) Type.getClassName(cls).replace('modcharting.', '')];
		for (name in playfieldRenderer.modchart.customModifiers.keys()) list.push(name);
		return list;
	}

	public function modifierEntry(index:Int):Array<Dynamic>
	{
		var mods:Array<Array<Dynamic>> = modchartData().modifiers;
		return (index >= 0 && index < mods.length) ? mods[index] : null;
	}

	public function modIndex(name:String):Int
	{
		for (i => mod in modchartData().modifiers)
			if(Std.string(mod[ModchartFile.MOD_NAME]) == name) return i;
		return -1;
	}

	public function uniqueModName(effect:String, ignoreIndex:Int):String
	{
		var base:String = effect.replace('Modifier', '');
		base = base.charAt(0).toLowerCase() + base.substr(1);
		var name:String = base;
		var n:Int = 2;
		while(modIndex(name) >= 0 && modIndex(name) != ignoreIndex) name = base + (n++);
		return name;
	}

	public function submitModifier(index:Int, entry:Array<Dynamic>):String
	{
		var mods:Array<Array<Dynamic>> = modchartData().modifiers;
		var name:String = entry[ModchartFile.MOD_NAME];
		var other:Int = modIndex(name);
		if(other >= 0 && other != index) return 'Modifier with same name already exists.';

		if(index < 0 || index >= mods.length)
		{
			applyEdit(null, function() { mods.push(entry); });
			rowScroll = Std.int(Math.max(0, visibleMods.length - VISIBLE_ROWS));
			showMessage('Added "$name".');
			return null;
		}

		var oldName:String = Std.string(mods[index][ModchartFile.MOD_NAME]);
		applyEdit(null, function() {
			mods[index] = entry;
			if(name != oldName) renameInEvents(oldName, name);
		});
		showMessage('Modifier "$name" updated');
		return null;
	}

	public function deleteModifierAt(index:Int)
	{
		var mods:Array<Array<Dynamic>> = modchartData().modifiers;
		if(index < 0 || index >= mods.length) return;
		var name:String = Std.string(mods[index][ModchartFile.MOD_NAME]);

		applyEdit(null, function() {
			mods.splice(index, 1);
			var events:Array<Array<Dynamic>> = modchartData().events;
			var i:Int = events.length;
			while(i-- > 0)
			{
				var ev:Array<Dynamic> = events[i];
				if(!isEditableEvent(ev)) continue;

				var targets:Array<TimelineTarget> = readTargets(ev);
				var remaining:Array<TimelineTarget> = [for (target in targets) if(target.mod != name) target];
				if(remaining.length == targets.length) continue;

				if(remaining.length == 0) events.splice(i, 1);
				else writeTargets(ev, remaining);
			}
			selectedEvent = -1;
		});
		selectEvent(-1);
		showMessage('Deleted "$name". Events removed.');
	}

	function renameInEvents(oldName:String, newName:String)
	{
		for (ev in modchartData().events)
		{
			if(!isEditableEvent(ev)) continue;

			var targets:Array<TimelineTarget> = readTargets(ev);
			var changed:Bool = false;
			for (target in targets)
			{
				if(target.mod != oldName) continue;
				target.mod = newName;
				changed = true;
			}
			if(changed) writeTargets(ev, targets);
		}
	}

	function changePlayfields(change:Int)
	{
		var data:ModchartJson = modchartData();
		var count:Int = Std.int(FlxMath.bound(data.playfields + change, 1, MAX_PLAYFIELDS));
		if(count == data.playfields) return;
		applyEdit(null, function() { data.playfields = count; });
		showMessage((change > 0) ? 'Playfield added.' : 'Playfield removed');
	}

	inline function songKey():String
		return Paths.formatToSongPath(PlayState.SONG.song.toLowerCase());

	function savePath():String
	{
		var current:String = playfieldRenderer.modchart.filePath;
		if(current != null) current = current.replace('\\', '/');
		if(current != null && current.startsWith('mods/')) return current;

		#if MODS_ALLOWED
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			return Paths.mods(Mods.currentModDirectory + '/data/songs/' + songKey() + '/modchart.json');
		#end

		return (current != null) ? current : Paths.json('songs/' + songKey() + '/modchart');
	}

	function saveModchart(saveAs:Bool)
	{
		var content:String = Json.stringify(modchartData(), '\t');

		#if sys
		if(!saveAs)
		{
			var path:String = savePath();
			try
			{
				var folder:String = haxe.io.Path.directory(path);
				if(folder.length > 0 && !FileSystem.exists(folder)) FileSystem.createDirectory(folder);
				File.saveContent(path, content);
				playfieldRenderer.modchart.filePath = path;
				markSaved();
				pushRecent();
				showMessage('Saved: ' + path);
				return;
			}
			catch(e:Dynamic)
			{
				showMessage('Cannot save in path ' + path + '. Choose another one!', true);
			}
		}
		#end

		if(!fileDialog.completed) return;
		fileDialog.save('modchart.json', content, function() {
			markSaved();
			showMessage('Saved: ' + fileDialog.path);
		}, null, function() showMessage('Error while saving modchart!', true));
	}

	function markSaved()
	{
		hasUnsaved = false;
		ModchartFile.editorData = null;
	}

	function replaceData(json:String)
	{
		pushUndoState(Json.stringify(modchartData()));
		selectedEvent = -1;
		restoreData(json);
		selectEvent(-1);
	}

	function openModchartFile()
	{
		if(!fileDialog.completed) return;
		fileDialog.open('modchart.json', 'Open Modchart', null, function() {
			var parsed:Dynamic = null;
			try
			{
				parsed = Json.parse(fileDialog.data);
			}
			catch(e:Dynamic) {}

			if(parsed == null || !Std.isOfType(parsed.modifiers, Array) || !Std.isOfType(parsed.events, Array))
			{
				showMessage('File is not valid modchart.json file!', true);
				return;
			}
			if(parsed.playfields == null) parsed.playfields = 1;

			replaceData(Json.stringify(parsed));
			showMessage('Opened ' + fileDialog.path);
		});
	}

	function reloadFromFile()
	{
		var reload = function() {
			ModchartFile.editorData = null;
			var fresh:ModchartJson = playfieldRenderer.modchart.loadFromJson(PlayState.SONG.song.toLowerCase());
			replaceData(Json.stringify(fresh));
			hasUnsaved = false;
			showMessage('Modchart Reloaded');
		};

		if(hasUnsaved) openSubState(new Prompt('Reload Modchart?\nUnsaved changes will be lost!', reload, null, 'Reload'));
		else reload();
	}

	function loadExample()
	{
		var load = function() {
			replaceData(EXAMPLE_MODCHART);
			seekTo(0);
			showMessage('Example Loaded!');
		};

		var data:ModchartJson = modchartData();
		if(data.modifiers.length > 0 || data.events.length > 0)
			openSubState(new Prompt('Replace modchart with example?', load, null, 'Replace'));
		else load();
	}

	function clearModchart()
	{
		var clear = function() {
			var data:ModchartJson = modchartData();
			applyEdit(null, function() {
				data.modifiers = [];
				data.events = [];
				data.playfields = 1;
				selectedEvent = -1;
			});
			selectEvent(-1);
			showMessage('Modchart Cleared');
		};
		openSubState(new Prompt('Delete everything? This cannot be undone.', clear, null, 'Clear'));
	}

	function showMessage(text:String, ?isError:Bool = false)
	{
		statusText.text = text;
		statusText.color = isError ? 0xFFFF6A6A : 0xFF7CFF8A;
		messageTime = 5;
	}

	function updateStatus(elapsed:Float)
	{
		if(messageTime > 0)
		{
			messageTime -= elapsed;
			return;
		}

		statusText.text = PlayState.SONG.song + (hasUnsaved ? '  -  UNSAVED CHANGES' : '  -  SAVED');
		statusText.color = hasUnsaved ? 0xFFFFB84A : 0xFFBBBBBB;
	}

	function updateHelpInput()
	{
		if(FlxG.keys.justPressed.F1 || FlxG.keys.justPressed.ESCAPE)
			showHelp(false);
		else if(FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.RIGHT)
		{
			helpPage = FlxMath.wrap(helpPage + (FlxG.keys.justPressed.LEFT ? -1 : 1), 0, HELP_PAGES.length - 1);
			showHelp(true);
		}
	}

	function showHelp(show:Bool)
	{
		helpBg.visible = helpText.visible = helpPageText.visible = show;
		if(!show) return;

		helpText.text = HELP_PAGES[helpPage];
		helpText.screenCenter();
		helpPageText.text = '<PAGE ' + (helpPage + 1) + '/' + HELP_PAGES.length + '>';
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
			updateAudioVolume();
			muteEditorLoop();
			playfieldRenderer.editorPaused = false;
			dirtyNotes = true;
			dirtyEvents = true;
		}
		else
		{
			var wasPlaying:Bool = FlxG.sound.music.playing;
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
			playfieldRenderer.editorPaused = true;
			if(wasPlaying) scheduleEditorLoop(3.5);
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

	static inline final EDITOR_HIT:String = 'modchartEditorHit';

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
		var playing:Bool = FlxG.sound.music.playing;
		var hitPlayer:Bool = playing && hitsoundPlayerSlider.value > 0;
		var hitOpponent:Bool = playing && hitsoundOpponentSlider.value > 0;
		for (note in notes.members.copy())
		{
			if(note == null || !note.alive) continue;

			if(Conductor.songPosition >= note.strumTime && note.extraData.get(EDITOR_HIT) != true)
			{
				note.extraData.set(EDITOR_HIT, true);
				note.wasGoodHit = true;
				if(!note.isSustainNote)
				{
					if(note.mustPress && hitPlayer)
					{
						FlxG.sound.play(Paths.sound('chartingSounds/hitNotePlayer'), sliderVolume(hitsoundPlayerSlider));
						hitPlayer = false;
					}
					else if(!note.mustPress && hitOpponent)
					{
						FlxG.sound.play(Paths.sound('chartingSounds/hitNoteOpponent'), sliderVolume(hitsoundOpponentSlider));
						hitOpponent = false;
					}
				}
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

		var selectedMods:Array<String> = [];
		for (ev in timelineEvents)
			if(ev.index == selectedEvent)
				for (target in ev.targets) selectedMods.push(target.mod);

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
			rowLabels[i].color = selectedMods.contains(name) ? COLOR_SELECTED : FlxColor.WHITE;

			var live = playfieldRenderer.modifierTable.modifiers.get(name);
			rowValues[i].text = (live != null) ? Std.string(FlxMath.roundDecimal(live.currentValue, 2)) : '';
		}

		var total:Int = visibleMods.length;
		rowsInfoText.text = (total > VISIBLE_ROWS) ? '${rowScroll + 1}-${Std.int(Math.min(total, rowScroll + VISIBLE_ROWS))} of $total' : 'Modifiers: $total';

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
			case 'character' | 'char': 'C' + parseIntSafe(mod[ModchartFile.MOD_LANE], 0);
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
			rulerPool.push(text);
			timelineLayer.add(text);
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
			'Beat: ' + FlxMath.roundDecimal(beat, 2) + '   Step: ' + Math.floor(beat * 4) + '   Section: ' + Math.floor(beat / 4),
			'BPM: ' + Conductor.bpm + '   Speed: ' + playbackSpeed + 'x',
			'Zoom: ' + Math.round(pixelsPerBeat) + ' px',
			'Events: ' + modchartData().events.length + '   Undo: ' + undoStack.length + '   Redo: ' + redoStack.length
		].join('\n');
	}

	function goToPlayState()
	{
		if(hasUnsaved)
		{
			ModchartFile.editorData = cast Json.parse(Json.stringify(modchartData()));
			ModchartFile.editorDataSong = songKey();
		}
		else ModchartFile.editorData = null;

		stopAudio();
		FlxG.mouse.visible = false;
		funkin.data.StageData.loadDirectory(PlayState.SONG);
		LoadingState.loadAndSwitchState(new PlayState());
	}

	function exitToMenu()
	{
		var leave = function() {
			ModchartFile.editorData = null;
			stopAudio();
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new EditorMenuState());
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
		};

		if(hasUnsaved) openSubState(new Prompt('WARNING\nUnsaved progress, make sure to Save before Exit!', leave, null, 'Exit'));
		else leave();
	}

	function stopAudio()
	{
		FlxG.sound.music.onComplete = null;
		FlxG.sound.music.stop();
		vocals.stop();
		opponentVocals.stop();
		stopEditorLoopFade();
		editorLoop.stop();
	}
}

class ModifierPopup extends MusicBeatSubstate
{
	static inline final W:Int = 560;
	static inline final H:Int = 380;

	var editor:ModchartEditorState;
	var index:Int;
	var widgets:Array<FlxSprite> = [];

	var nameInput:PsychUIInputText;
	var effectDropDown:PsychUIDropDownMenu;
	var typeDropDown:PsychUIDropDownMenu;
	var laneLabel:FlxText;
	var laneStepper:PsychUINumericStepper;
	var playfieldDropDown:PsychUIDropDownMenu;
	var descText:FlxText;
	var errorText:FlxText;

	public function new(editor:ModchartEditorState, index:Int)
	{
		super();
		this.editor = editor;
		this.index = (editor.modifierEntry(index) != null) ? index : -1;
	}

	override function create()
	{
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		var shade:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		shade.scale.set(FlxG.width, FlxG.height);
		shade.updateHitbox();
		shade.alpha = 0.6;
		shade.cameras = cameras;
		add(shade);

		var bg:FlxSprite = new FlxSprite().makeGraphic(W, H, 0xFF26262F);
		bg.screenCenter();
		bg.cameras = cameras;
		add(bg);

		var x0:Float = bg.x + 20;
		var y0:Float = bg.y;
		var fx:Float = bg.x + 110;
		var entry:Array<Dynamic> = editor.modifierEntry(index);

		var title:FlxText = new FlxText(bg.x, y0 + 12, W, (entry != null) ? 'Edit modifier' : 'New modifier', 16);
		title.alignment = CENTER;
		widget(title);

		widget(new FlxText(x0, y0 + 53, 90, 'Name:', 10));
		nameInput = widget(new PsychUIInputText(fx, y0 + 50, 200, '', 8));
		nameInput.customFilterPattern = ~/[^a-zA-Z0-9_]*/g;
		nameInput.filterMode = FilterMode.CUSTOM_FILTER;
		hint(fx, y0 + 72, 'Letters, numbers and _ only. Leave it empty for automatic name.');

		widget(new FlxText(x0, y0 + 101, 90, 'Effect:', 10));
		effectDropDown = widget(new PsychUIDropDownMenu(fx, y0 + 98, editor.effectList(), function(_, label:String) refreshDescription(), 180));

		var descBg:FlxSprite = widget(new FlxSprite(x0, y0 + 126).makeGraphic(W - 40, 70, 0xFF1B1B22));
		descBg.alpha = 0.8;
		descText = widget(new FlxText(x0 + 8, y0 + 132, W - 56, '', 10));
		descText.color = 0xFFDDDDDD;

		widget(new FlxText(x0, y0 + 215, 90, 'Moves:', 10));
		typeDropDown = widget(new PsychUIDropDownMenu(fx, y0 + 212, ModchartEditorState.TYPE_LABELS.concat(editor.characterTargetLabels()), function(_, label:String) refreshLane(), 110));
		laneLabel = widget(new FlxText(fx + 160, y0 + 215, 50, 'Lane:', 10));
		laneStepper = widget(new PsychUINumericStepper(fx + 210, y0 + 212, 1, 0, 0, Math.max(7, NoteMovement.laneCount - 1), 0, 40));
		hint(fx, y0 + 234, 'All, Player/Opp, Char N, Lane (0-3/4-7, 8+: extra)');

		widget(new FlxText(x0, y0 + 263, 90, 'Playfield:', 10));
		playfieldDropDown = widget(new PsychUIDropDownMenu(fx, y0 + 260, editor.playfieldLabels(), null, 140));
		hint(fx, y0 + 282, 'Keep "All playfields" unless more were added.');

		errorText = widget(new FlxText(x0, y0 + 306, W - 40, '', 10));
		errorText.alignment = CENTER;
		errorText.color = 0xFFFF6A6A;

		var buttons:Array<PsychUIButton> = [];
		var confirmButton:PsychUIButton = new PsychUIButton(0, y0 + H - 44, (entry != null) ? 'Save' : 'Create', confirm, 100, 24);
		confirmButton.normalStyle.bgColor = 0xFF3A7A3A;
		confirmButton.normalStyle.textColor = FlxColor.WHITE;
		buttons.push(confirmButton);
		if(entry != null)
		{
			var deleteButton:PsychUIButton = new PsychUIButton(0, y0 + H - 44, 'Delete', deleteModifier, 100, 24);
			deleteButton.normalStyle.bgColor = FlxColor.RED;
			deleteButton.normalStyle.textColor = FlxColor.WHITE;
			buttons.push(deleteButton);
		}
		buttons.push(new PsychUIButton(0, y0 + H - 44, 'Cancel', close, 100, 24));

		var rowWidth:Float = buttons.length * 100 + (buttons.length - 1) * 20;
		for (i => button in buttons)
		{
			button.x = bg.x + (W - rowWidth) / 2 + i * 120;
			widget(button);
		}

		var i:Int = widgets.length;
		while(i-- > 0) add(widgets[i]);

		loadEntry(entry);
		super.create();
	}

	function hint(x:Float, y:Float, text:String):FlxText
	{
		var label:FlxText = widget(new FlxText(x, y, W - (x - FlxG.width / 2 + W / 2) - 20, text, 9));
		label.color = 0xFF9A9AB0;
		return label;
	}

	function widget<T:FlxSprite>(item:T):T
	{
		item.cameras = cameras;
		widgets.push(item);
		return item;
	}

	function loadEntry(entry:Array<Dynamic>)
	{
		var effects:Array<String> = effectDropDown.list;
		if(entry == null)
		{
			nameInput.text = '';
			effectDropDown.selectedLabel = effects[0];
			typeDropDown.selectedLabel = 'All';
			laneStepper.value = 0;
			playfieldDropDown.selectedLabel = ModchartEditorState.ALL_PLAYFIELDS;
		}
		else
		{
			nameInput.text = Std.string(entry[ModchartFile.MOD_NAME]);

			var effect:String = Std.string(entry[ModchartFile.MOD_CLASS]);
			if(!effects.contains(effect) && effects.contains(effect + 'Modifier')) effect += 'Modifier';
			effectDropDown.selectedLabel = effect;

			typeDropDown.selectedLabel = switch(Std.string(entry[ModchartFile.MOD_TYPE]).toLowerCase())
			{
				case 'player': 'Player';
				case 'opponent': 'Opponent';
				case 'lane' | 'lanespecific': 'Lane';
				case 'character' | 'char': 'Char ' + Std.string(entry[ModchartFile.MOD_LANE]);
				default: 'All';
			}

			var lane:Null<Int> = Std.parseInt(Std.string(entry[ModchartFile.MOD_LANE]));
			laneStepper.value = (lane != null) ? lane : 0;

			var pf:Null<Int> = Std.parseInt(Std.string(entry[ModchartFile.MOD_PF]));
			playfieldDropDown.selectedLabel = (pf != null && pf >= 0) ? 'Playfield ' + pf : ModchartEditorState.ALL_PLAYFIELDS;
		}
		refreshDescription();
		refreshLane();
	}

	function refreshDescription()
	{
		var effect:String = effectDropDown.selectedLabel;
		descText.text = (effect != null) ? ModchartEditorState.effectInfo(effect).desc : '';
	}

	function refreshLane()
	{
		var shown:Bool = (typeDropDown.selectedLabel == 'Lane');
		laneLabel.visible = laneStepper.visible = shown;
	}

	function confirm()
	{
		var effect:String = effectDropDown.selectedLabel;
		if(effect == null || effect.length < 1)
		{
			errorText.text = 'Choose an effect first.';
			return;
		}

		var name:String = nameInput.text.trim();
		if(name.length < 1) name = editor.uniqueModName(effect, index);

		var label:String = (typeDropDown.selectedLabel != null) ? typeDropDown.selectedLabel : 'All';
		var character:Null<Int> = label.startsWith('Char ') ? Std.parseInt(label.substr('Char '.length)) : null;
		var type:String = (character != null) ? 'character' : label.toLowerCase();
		var pf:Int = ModchartEditorState.playfieldFromLabel(playfieldDropDown.selectedLabel);

		var entry:Array<Dynamic> = [name, effect, type, pf];
		if(type == 'lane') entry.push(Std.int(laneStepper.value));
		if(character != null) entry.push(character);

		var error:String = editor.submitModifier(index, entry);
		if(error != null)
		{
			errorText.text = error;
			return;
		}
		close();
	}

	function deleteModifier()
	{
		editor.deleteModifierAt(index);
		close();
	}

	override function update(elapsed:Float)
	{
		ModchartEditorState.lockUnderDropDown(widgets);
		super.update(elapsed);
		if(PsychUIInputText.focusOn == null && FlxG.keys.justPressed.ESCAPE) close();
	}
}
