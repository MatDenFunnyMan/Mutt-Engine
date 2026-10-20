package funkin.editors;

import haxe.Json;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.input.keyboard.FlxKey;
import funkin.data.NotePackData;
import funkin.game.notes.Note;
import funkin.game.notes.NotePack;
import funkin.game.notes.NoteSplash;
import funkin.game.notes.StrumNote;
import funkin.game.notes.HoldCover;
import funkin.editors.content.FileDialogHandler;
import funkin.editors.content.Prompt;
import funkin.graphics.shaders.RGBPalette.RGBShaderReference;

using StringTools;

class NoteEditorColorPicker extends FlxSpriteGroup
{
	public static final SIZE:Int = 150;
	public static final HUE_WIDTH:Int = 18;
	public var onChange:FlxColor->Void;

	var square:FlxSprite;
	var hueBar:FlxSprite;
	var dot:FlxSprite;
	var hueLine:FlxSprite;
	var hue:Float = 0;
	var sat:Float = 1;
	var bright:Float = 1;
	var dragging:Int = 0;

	public function new(x:Float, y:Float)
	{
		super(x, y);
		square = new FlxSprite().makeGraphic(SIZE, SIZE, FlxColor.WHITE, true);
		add(square);
		hueBar = new FlxSprite(SIZE + 6, 0).makeGraphic(HUE_WIDTH, SIZE, FlxColor.WHITE, true);
		hueBar.pixels.lock();
		for (py in 0...SIZE)
		{
			var hueColor:FlxColor = FlxColor.fromHSB((py / SIZE) * 360, 1, 1);
			for (px in 0...HUE_WIDTH) hueBar.pixels.setPixel32(px, py, hueColor);
		}
		hueBar.pixels.unlock();
		hueBar.dirty = true;
		add(hueBar);
		dot = new FlxSprite().makeGraphic(8, 8, FlxColor.TRANSPARENT, true);
		flixel.util.FlxSpriteUtil.drawCircle(dot, 4, 4, 3, FlxColor.WHITE);
		add(dot);
		hueLine = new FlxSprite().makeGraphic(HUE_WIDTH, 2, FlxColor.WHITE);
		add(hueLine);
		setColor(FlxColor.RED);
	}

	public function setColor(color:FlxColor)
	{
		hue = color.hue;
		sat = color.saturation;
		bright = color.brightness;
		redraw();
		placeMarks();
	}

	function redraw()
	{
		square.pixels.lock();
		for (py in 0...SIZE)
			for (px in 0...SIZE)
				square.pixels.setPixel32(px, py, FlxColor.fromHSB(hue, px / SIZE, 1 - py / SIZE));
		square.pixels.unlock();
		square.dirty = true;
	}

	function placeMarks()
	{
		dot.setPosition(square.x + sat * SIZE - 4, square.y + (1 - bright) * SIZE - 4);
		hueLine.setPosition(hueBar.x, hueBar.y + (hue / 360) * SIZE - 1);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(FlxG.mouse.justPressed)
		{
			dragging = 0;
			if(FlxG.mouse.overlaps(hueBar)) dragging = 1;
			else if(FlxG.mouse.overlaps(square)) dragging = 2;
		}
		else if(FlxG.mouse.justReleased) dragging = 0;
		if(!FlxG.mouse.pressed || dragging == 0) return;

		var mouse:FlxPoint = FlxG.mouse.getScreenPosition(FlxG.camera);
		if(dragging == 1)
		{
			hue = Math.max(0, Math.min(1, (mouse.y - hueBar.y) / SIZE)) * 360;
			redraw();
		}
		else
		{
			sat = Math.max(0, Math.min(1, (mouse.x - square.x) / SIZE));
			bright = Math.max(0, Math.min(1, 1 - (mouse.y - square.y) / SIZE));
		}
		mouse.put();
		placeMarks();
		if(onChange != null) onChange(FlxColor.fromHSB(hue, sat, bright));
	}
}

class NoteEditorTab
{
	public var image:PsychUIInputText;
	public var pixel:PsychUICheckBox;
	public var animated:PsychUICheckBox;
	public var rgb:PsychUICheckBox;
	public var antialiasing:PsychUICheckBox;
	public var side:PsychUIDropDownMenu;
	public var note:PsychUIDropDownMenu;
	public var scale:PsychUIInputText;
	public var grid:PsychUIInputText;
	public var gridLabel:FlxText;
	public var holdImage:PsychUIInputText;
	public var holdImageLabel:FlxText;
	public var anim:PsychUIDropDownMenu;
	public var animName:PsychUIInputText;
	public var holdNotes:PsychUICheckBox;
	public var previewNotes:PsychUICheckBox;
	public var prefix:PsychUIInputText;
	public var prefixLabel:FlxText;
	public var indices:PsychUIInputText;
	public var indicesLabel:FlxText;
	public var fps:PsychUINumericStepper;
	public var loop:PsychUICheckBox;

	public function new() {}
}

class NoteEditorState extends MusicBeatState
{
	static final TABS:Array<String> = ['Strumline', 'Notes', 'Splashes', 'Hold Notes'];
	static final TAB_PARTS:Array<String> = ['strums', 'notes', 'splashes', 'holdCovers'];
	static final TYPE_TABS:Array<String> = ['Notes', 'Splashes', 'Hold Notes', 'Gameplay'];
	static final TYPE_PARTS:Array<String> = ['notes', 'splashes', 'holdCovers', 'gameplay'];
	static final GAMEPLAY_FLAGS:Array<Array<String>> = [
		['hitCausesMiss', 'Hit Causes Miss'],
		['ignoreNote', 'Can Skip (No Miss)'],
		['opponentIgnoreNote', 'Opponent Ignores Note'],
		['noAnimation', 'No Animation'],
		['noMissAnimation', 'No Miss Anim'],
		['noSplash', 'No Splash'],
		['lowPriority', 'Low Priority']
	];
	static final GAMEPLAY_VALUES:Array<Array<String>> = [
		['hitHealth', 'Health Gain (def: 0.02):'],
		['missHealth', 'Health Loss (def: 0.1):'],
		['hitsound', 'Hitsound:'],
		['animSuffix', 'Animation Suffix:']
	];
	static final DIRECTION_NAMES:Array<String> = ['Left', 'Down', 'Up', 'Right'];
	static final BOX_X:Int = 740;
	static final BOX_Y:Int = 48;
	static final BOX_WIDTH:Int = 480;
	static final BOX_HEIGHT:Int = 560;
	static final PREVIEW_WIDTH:Float = 720;
	static final STRUM_Y:Float = 280;
	static final NOTES_STRUM_Y:Float = 80;
	static final NOTE_GAP:Float = 1500;
	static final NOTE_SPEED:Float = 1.6;
	static final HOLD_PIECES:Int = 4;
	static final POPUP_X:Float = 620;
	static final POPUP_Y:Float = 200;
	static final POPUP_W:Int = 580;
	static final POPUP_H:Int = 380;

	var file:NotePackFile = {};
	var unsaved:Bool = false;
	var tabNames:Array<String> = TABS;
	var tabParts:Array<String> = TAB_PARTS;
	var typeMode:Bool = false;
	var typeName:String = '';
	var gameplayTab:Bool = false;
	var modeText:FlxText;
	var gameplayBoxes:Map<String, PsychUICheckBox> = new Map();
	var gameplayInputs:Map<String, PsychUIInputText> = new Map();
	var opponent:Bool = false;
	var pixel:Bool = false;
	var direction:Int = 0;
	var variant:Int = 0;
	var part:String = 'strums';
	var animNames:Map<String, String> = ['strums' => 'static', 'notes' => 'note', 'holdCovers' => 'hold'];
	var lastTab:String = null;
	var oldStageUI:String = 'normal';

	var upperBox:PsychUIBox;
	var mainBox:PsychUIBox;
	var tabs:Map<String, NoteEditorTab> = new Map();

	var strums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	var notes:FlxTypedGroup<Note> = new FlxTypedGroup<Note>();
	var sustains:FlxTypedGroup<Note> = new FlxTypedGroup<Note>();
	var ghostNotes:FlxTypedGroup<Note> = new FlxTypedGroup<Note>();
	static var previewNotes:Bool = false;
	static final STATIC_NOTE_DISTANCE:Float = 170;
	var hitNotes:Array<Note> = [];
	static var showHoldNotes:Bool = false;
	var splashes:FlxTypedGroup<NoteSplash> = new FlxTypedGroup<NoteSplash>();
	var covers:FlxTypedGroup<HoldCover> = new FlxTypedGroup<HoldCover>();
	var ghosts:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	var ghostCheckBox:PsychUICheckBox;
	static var showGhost:Bool = true;
	static final GHOST_ALPHA:Float = 0.4;

	var animText:FlxText;
	var offsetText:FlxText;
	var messageText:FlxText;
	var fileDialog:FileDialogHandler = new FileDialogHandler();

	var shaderSideDropDown:PsychUIDropDownMenu;
	var shaderColorInput:PsychUIInputText;
	var shaderStrengthInput:PsychUIInputText;

	var previewTime:Float = 0;
	var nextNoteTime:Float = 0;
	var noteCounter:Int = 0;
	var shaderPopup:FlxSpriteGroup;
	var rgbPopup:FlxSpriteGroup;
	var rgbTitle:FlxText;
	var rgbInfo:FlxText;
	var rgbPart:String = 'holdCovers';
	var shaderSwatch:FlxSprite;
	var rgbNote:Int = 0;
	var rgbChannel:Int = 0;
	var rgbNoteDropDown:PsychUIDropDownMenu;
	var channelSwatches:Array<FlxSprite> = [];
	var channelInputs:Array<PsychUIInputText> = [];
	var channelFrame:FlxSprite;
	var rgbPicker:NoteEditorColorPicker;
	var shaderPicker:NoteEditorColorPicker;
	var paused:Bool = false;
	var frameText:FlxText;
	var holdingFrameTime:Float = 0;
	var holdingFrameElapsed:Float = 0;
	var testKeys:Array<Array<FlxKey>> = [];
	var holdingKeys:Array<Bool> = [false, false, false, false];
	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;

	override function create()
	{
		FlxG.mouse.visible = true;
		oldStageUI = PlayState.stageUI;
		NotePack.clearCache();

		#if DISCORD_ALLOWED
		#if MODS_ALLOWED
		DiscordClient.loadModRPC();
		#end
		DiscordClient.changePresence('Note Editor');
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);

		add(ghosts);
		add(strums);
		add(ghostNotes);
		add(sustains);
		add(notes);
		add(covers);
		add(splashes);

		var hint:FlxText = new FlxText(250, 8, 0, 'Press F1 for Help', 16);
		hint.setFormat(null, 16, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		hint.alpha = 0.6;
		add(hint);

		frameText = new FlxText(0, 40, PREVIEW_WIDTH, '', 16);
		frameText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		add(frameText);

		var blocked:Array<FlxKey> = [FlxKey.LEFT, FlxKey.DOWN, FlxKey.UP, FlxKey.RIGHT, FlxKey.Q, FlxKey.E, FlxKey.G, FlxKey.SPACE];
		for (bind in ['note_left', 'note_down', 'note_up', 'note_right'])
		{
			var keys:Array<FlxKey> = ClientPrefs.keyBinds.get(bind);
			testKeys.push((keys != null) ? [for (key in keys) if(key != FlxKey.NONE && !blocked.contains(key)) key] : []);
		}

		ghostCheckBox = new PsychUICheckBox(460, 8, 'Show Base Strumline (G)', 170, function() setGhost(ghostCheckBox.checked));
		ghostCheckBox.checked = showGhost;
		add(ghostCheckBox);
		add(EditorHelper.createEditorMusicCheckBox(650, 8, 120));

		animText = new FlxText(15, FlxG.height - 70, PREVIEW_WIDTH - 30, '', 24);
		animText.setFormat(null, 24, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		add(animText);

		offsetText = new FlxText(15, FlxG.height - 38, PREVIEW_WIDTH - 30, '', 24);
		offsetText.setFormat(null, 24, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		add(offsetText);

		messageText = new FlxText(PREVIEW_WIDTH, FlxG.height - 30, FlxG.width - PREVIEW_WIDTH - 15, '', 20);
		messageText.setFormat(null, 20, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		messageText.alpha = 0;
		add(messageText);

		modeText = new FlxText(15, FlxG.height - 100, PREVIEW_WIDTH - 30, '', 20);
		modeText.setFormat(null, 20, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		modeText.alpha = 0.8;
		add(modeText);
		refreshMode();

		createMainBox();

		createUpperMenu();
		add(fileDialog);

		rebuildPreview();
		refreshTab();

		if(FlxG.sound.music != null && FlxG.sound.music.playing)
			FlxG.sound.music.fadeOut(0.6, 0);
		EditorHelper.scheduleEditorMusic(10);
		super.create();
	}

	function createMainBox()
	{
		var position:Int = (mainBox != null) ? members.indexOf(mainBox) : -1;
		if(mainBox != null)
		{
			remove(mainBox, true);
			mainBox.destroy();
		}
		tabs.clear();
		gameplayBoxes.clear();
		gameplayInputs.clear();
		mainBox = new PsychUIBox(BOX_X, BOX_Y, BOX_WIDTH, BOX_HEIGHT, tabNames);
		mainBox.canMove = mainBox.canMinimize = false;
		mainBox.scrollFactor.set();
		if(position > -1) insert(position, mainBox);
		else add(mainBox);
		for (index => name in tabNames)
		{
			if(tabParts[index] == 'gameplay') buildGameplayTab(name);
			else buildTab(name, tabParts[index]);
		}
		mainBox.selectedName = tabNames[0];
	}

	function setMode(type:Bool)
	{
		typeMode = type;
		tabNames = type ? TYPE_TABS : TABS;
		tabParts = type ? TYPE_PARTS : TAB_PARTS;
		createMainBox();
		part = tabParts[0];
		lastTab = tabNames[0];
		gameplayTab = false;
		variant = 0;
		refreshMode();
	}

	function refreshMode()
		modeText.text = typeMode ? 'Notetype: ' + ((typeName.length > 0) ? typeName : '(NOT SAVED)') : 'Note Pack';

	function buildGameplayTab(tabName:String)
	{
		var menu = mainBox.getTab(tabName).menu;
		menu.add(new FlxText(24, 14, BOX_WIDTH - 48, 'Create custom notes for gimmicks/mechanics. Script file can be modified after creation.\nYou don\'t need to change skins using LUA or HX file!'));
		for (index => entry in GAMEPLAY_FLAGS)
		{
			var field:String = entry[0];
			var box:PsychUICheckBox = new PsychUICheckBox(24, 60 + index * 30, entry[1], 150);
			box.onClick = function() setGameplay(field, box.checked ? true : null);
			menu.add(box);
			gameplayBoxes.set(field, box);
		}
		for (index => entry in GAMEPLAY_VALUES)
		{
			var field:String = entry[0];
			var y:Float = 60 + index * 45;
			menu.add(new FlxText(250, y, 0, entry[1]));
			var input:PsychUIInputText = new PsychUIInputText(250, y + 16, 160, '', 8);
			input.onChange = function(prev:String, next:String) setGameplayText(field, next);
			menu.add(input);
			gameplayInputs.set(field, input);
		}
		menu.add(new FlxText(24, 300, BOX_WIDTH - 48, 'Mechanics can be added to the script file after creation. Have fun!\nHitsounds path = \'sounds/\'\nAnimation suffix = \'-alt\' or a custom suffix for character.'));
		menu.add(new PsychUIButton(92, 370, 'Create LUA', function() createScript('lua'), 120, 25));
		menu.add(new PsychUIButton(268, 370, 'Create HScript', function() createScript('hx'), 120, 25));
	}

	function setGameplay(field:String, value:Dynamic)
	{
		var data:Dynamic = Reflect.field(file, 'gameplay');
		if(data == null)
		{
			if(value == null) return;
			data = {};
			Reflect.setField(file, 'gameplay', data);
		}
		if(value == null) Reflect.deleteField(data, field);
		else Reflect.setField(data, field, value);
		if(Reflect.fields(data).length < 1) Reflect.deleteField(file, 'gameplay');
		unsaved = true;
	}

	function setGameplayText(field:String, text:String)
	{
		var clean:String = text.trim();
		if(clean.length < 1)
		{
			setGameplay(field, null);
			return;
		}
		if(field == 'hitHealth' || field == 'missHealth')
		{
			var number:Float = Std.parseFloat(clean);
			if(!Math.isNaN(number)) setGameplay(field, number);
			return;
		}
		setGameplay(field, clean);
	}

	function refreshGameplay()
	{
		var data:Dynamic = Reflect.field(file, 'gameplay');
		for (field => box in gameplayBoxes) box.checked = data != null && Reflect.field(data, field) == true;
		for (field => input in gameplayInputs)
		{
			var value:Dynamic = (data != null) ? Reflect.field(data, field) : null;
			input.text = (value != null) ? Std.string(value) : '';
		}
	}

	function createScript(extension:String)
	{
		if(!fileDialog.completed) return;
		if(typeName.length < 1)
		{
			showMessage('Create a notetype before scripts!', true);
			return;
		}
		var name:String = typeName.replace("'", "\\'");
		var lines:Array<String> = [];
		for (callback in ['goodNoteHit', 'opponentNoteHit', 'noteMiss'])
		{
			if(extension == 'lua')
			{
				lines.push('function $callback(id, direction, noteType, isSustainNote)');
				lines.push("\tif noteType == '" + name + "' then");
				lines.push('\tend');
				lines.push('end');
			}
			else
			{
				lines.push('function $callback(note:Note)');
				lines.push('{');
				lines.push("\tif(note.noteType != '" + name + "') return;");
				lines.push('}');
			}
			lines.push('');
		}
		fileDialog.save('$typeName.$extension', lines.join('\n'), function() {
			showMessage('Saved: ' + haxe.io.Path.withoutDirectory(fileDialog.path));
		}, null, function() showMessage('ERROR: Script not saved.', true));
	}

	function newNoteType()
	{
		openSubState(new Prompt('Start a new notetype?\nUnsaved changes will be lost.', function() {
			file = {};
			typeName = '';
			setMode(true);
			unsaved = false;
			rebuildPreview();
			refreshTab();
			refreshGameplay();
			refreshShader();
			showMessage('New notetype');
		}, null, 'New'));
	}

	function loadNoteType()
	{
		if(!fileDialog.completed) return;
		fileDialog.open('noteType.json', 'Open Notetype', null, function() {
			try
			{
				file = NotePackData.parse(fileDialog.data);
				typeName = haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(fileDialog.path));
				setMode(true);
				unsaved = false;
				rebuildPreview();
				refreshTab();
				refreshGameplay();
				refreshShader();
				if(imagesFound()) showMessage('Opened ' + haxe.io.Path.withoutDirectory(fileDialog.path));
				else showMessage('Image not found!', true);
			}
			catch(e:Dynamic)
			{
				showMessage('File not a valid notetype: $e', true);
			}
		});
	}

	function createUpperMenu()
	{
		upperBox = new PsychUIBox(0, 0, 150, 90, ['File', 'Shader']);
		upperBox.scrollFactor.set();
		upperBox.isMinimized = true;
		upperBox.minimizeOnFocusLost = true;
		upperBox.canMove = false;
		upperBox.bg.visible = false;
		add(upperBox);

		var entries:Array<Array<Dynamic>> = [
			['  Save (Ctrl+S)', saveFile],
			['  Load from JSON', loadFile],
			['  Load Template', loadTemplate],
			['  New Notetype', newNoteType],
			['  Load Notetype', loadNoteType],
			['  Exit', exitEditor]
		];
		var menu = upperBox.getTab('File').menu;
		var panel:FlxSprite = new FlxSprite().makeGraphic(200, entries.length * 20 + 2, FlxColor.BLACK);
		panel.alpha = 0.8;
		menu.add(panel);
		for (i => entry in entries)
		{
			var button:PsychUIButton = new PsychUIButton(0, i * 20, entry[0], entry[1], 200);
			button.text.alignment = LEFT;
			menu.add(button);
		}

		var shaderEntries:Array<Array<Dynamic>> = [
			['  Strumline Shader', function() {
				if(typeMode) showMessage('ERROR: Strumline Shader not available for notetypes!', true);
				else openPopup(shaderPopup);
			}],
			['  Notes RGB', function() openRGBPopup('notes')],
			['  Splashes RGB', function() openRGBPopup('splashes')],
			['  Hold RGB', function() openRGBPopup('holdCovers')]
		];
		var shaderTab = upperBox.getTab('Shader');
		shaderTab.menuOffsetX = 75;
		var shader = shaderTab.menu;
		var shaderPanel:FlxSprite = new FlxSprite().makeGraphic(200, shaderEntries.length * 20 + 2, FlxColor.BLACK);
		shaderPanel.alpha = 0.8;
		shader.add(shaderPanel);
		for (i => entry in shaderEntries)
		{
			var button:PsychUIButton = new PsychUIButton(0, i * 20, entry[0], entry[1], 200);
			button.text.alignment = LEFT;
			shader.add(button);
		}

		createShaderPopup();
		createRGBPopup();
	}

	function createPopup(title:String):FlxSpriteGroup
	{
		var popup:FlxSpriteGroup = new FlxSpriteGroup(POPUP_X, POPUP_Y);
		popup.scrollFactor.set();
		var border:FlxSprite = new FlxSprite().makeGraphic(POPUP_W, POPUP_H, FlxColor.WHITE);
		border.alpha = 0.6;
		popup.add(border);
		var bg:FlxSprite = new FlxSprite(2, 2).makeGraphic(POPUP_W - 4, POPUP_H - 4, FlxColor.BLACK);
		bg.alpha = 0.9;
		popup.add(bg);
		var titleText:FlxText = new FlxText(0, 12, POPUP_W, title, 16);
		titleText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		popup.add(titleText);
		popup.add(new PsychUIButton(POPUP_W - 34, 10, 'X', closePopups, 24, 24));
		popup.visible = popup.active = false;
		add(popup);
		return popup;
	}

	function createShaderPopup()
	{
		shaderPopup = createPopup('Strumline Shader');
		shaderPopup.add(new FlxText(30, 44, POPUP_W - 60, 'Changes strumline tint instantly. Use script to tween or change properties.\n\'Alpha\' value must be DECIMAL and between 0-1.'));
		shaderPopup.add(new FlxText(30, 84, 0, 'Side:'));
		shaderPopup.add(new PsychUIButton(30, POPUP_H - 50, 'Remove', removeShader, 140, 25));

		shaderPicker = new NoteEditorColorPicker(190, 100);
		shaderPicker.onChange = function(color:FlxColor) {
			shaderColorInput.text = color.toHexString(false, false);
			applyShader();
		};
		shaderPopup.add(shaderPicker);

		var columnX:Float = 190 + NoteEditorColorPicker.SIZE + NoteEditorColorPicker.HUE_WIDTH + 24;
		shaderPopup.add(new FlxText(columnX, 84, 0, 'Color:'));
		shaderSwatch = new FlxSprite(columnX, 100).makeGraphic(36, 36, FlxColor.WHITE);
		shaderPopup.add(shaderSwatch);
		shaderColorInput = new PsychUIInputText(columnX + 44, 111, 80, 'FF0000', 8);
		shaderColorInput.onChange = function(prev:String, next:String) {
			var parsed:Null<FlxColor> = parseHex(next);
			if(parsed == null) return;
			shaderPicker.setColor(parsed);
			applyShader();
		};
		shaderPopup.add(shaderColorInput);

		shaderPopup.add(new FlxText(columnX, 160, 0, 'Alpha:'));
		shaderStrengthInput = new PsychUIInputText(columnX, 176, 60, '0', 8);
		shaderStrengthInput.onChange = function(prev:String, next:String) applyShader();
		shaderPopup.add(shaderStrengthInput);
		shaderPopup.add(new PsychUIButton(columnX + 64, 174, '+', function() nudgeStrength(0.1), 20));
		shaderPopup.add(new PsychUIButton(columnX + 86, 174, '-', function() nudgeStrength(-0.1), 20));

		shaderSideDropDown = new PsychUIDropDownMenu(30, 100, [''], function(id:Int, name:String) refreshShader(), 120);
		shaderSideDropDown.autoSort = false;
		shaderSideDropDown.list = ['Player', 'Opponent'];
		shaderSideDropDown.selectedIndex = 0;
		shaderPopup.add(shaderSideDropDown);
		refreshShader();
	}

	function createRGBPopup()
	{
		rgbPopup = createPopup('Hold RGB');
		rgbTitle = cast rgbPopup.members[2];
		rgbInfo = new FlxText(30, 44, POPUP_W - 60, '');
		rgbPopup.add(rgbInfo);
		rgbPopup.add(new FlxText(30, 84, 0, 'Note:'));
		rgbPopup.add(new PsychUIButton(30, POPUP_H - 50, 'Default Colors', resetRGBColors, 140, 25));

		rgbPicker = new NoteEditorColorPicker(190, 100);
		rgbPicker.onChange = function(color:FlxColor) setRGBColor(color);
		rgbPopup.add(rgbPicker);

		var columnX:Float = 190 + NoteEditorColorPicker.SIZE + NoteEditorColorPicker.HUE_WIDTH + 24;
		channelFrame = new FlxSprite().makeGraphic(40, 40, FlxColor.WHITE);
		rgbPopup.add(channelFrame);
		for (c => name in ['R', 'G', 'B'])
		{
			var y:Float = 100 + c * 55;
			rgbPopup.add(new FlxText(columnX, y + 12, 0, name));
			var swatch:FlxSprite = new FlxSprite(columnX + 16, y).makeGraphic(36, 36, FlxColor.WHITE);
			rgbPopup.add(swatch);
			channelSwatches.push(swatch);
			var input:PsychUIInputText = new PsychUIInputText(columnX + 60, y + 11, 80, '', 8);
			var channel:Int = c;
			input.onChange = function(prev:String, next:String) {
				var parsed:Null<FlxColor> = parseHex(next);
				if(parsed == null) return;
				rgbChannel = channel;
				setRGBColor(parsed, false);
				selectChannel(channel);
			};
			rgbPopup.add(input);
			channelInputs.push(input);
		}

		rgbNoteDropDown = new PsychUIDropDownMenu(30, 100, [''], function(id:Int, name:String) {
			rgbNote = id;
			refreshRGBColors();
			if(rgbPart == 'splashes') splashAt(rgbNote);
		}, 120);
		rgbNoteDropDown.autoSort = false;
		rgbNoteDropDown.list = DIRECTION_NAMES.copy();
		rgbNoteDropDown.selectedIndex = 0;
		rgbPopup.add(rgbNoteDropDown);
	}

	function openRGBPopup(partName:String)
	{
		rgbPart = partName;
		if(partName == 'notes')
		{
			rgbTitle.text = 'Notes RGB';
			rgbInfo.text = 'Change note colors to your liking. RGB option must be active!';
		}
		else if(partName == 'splashes')
		{
			rgbTitle.text = 'Splashes RGB';
			rgbInfo.text = 'Change note splashes colors to your liking. Only applies to Player notes and custom notetypes.';
		}
		else
		{
			rgbTitle.text = 'Hold RGB';
			rgbInfo.text = 'Change hold cover and splash colors to your liking. End splashes only apply to player or custom notetypes.';
		}
		openPopup(rgbPopup);
	}

	function openPopup(popup:FlxSpriteGroup)
	{
		closePopups();
		popup.visible = popup.active = true;
		if(popup == rgbPopup)
		{
			var tabName:String = tabNames[tabParts.indexOf(rgbPart)];
			mainBox.selectedName = tabName;
			mainBox.forceCheckNext = true;
			mainBox.update(0);
			if(part != rgbPart)
			{
				lastTab = tabName;
				part = rgbPart;
				rebuildPreview();
				refreshTab();
			}
			refreshRGBColors();
			if(rgbPart == 'splashes') splashAt(rgbNote);
		}
		else refreshShader();
		mainBox.active = false;
		upperBox.isMinimized = true;
	}

	function closePopups()
	{
		for (popup in [shaderPopup, rgbPopup]) popup.visible = popup.active = false;
		mainBox.active = true;
		PsychUIInputText.focusOn = null;
		for (strum in strums) strum.applyBaseTint();
	}

	function popupOpen():Bool
		return shaderPopup.visible || rgbPopup.visible;

	function parseHex(text:String):Null<FlxColor>
	{
		var clean:String = text.trim().replace('#', '').replace('0x', '');
		if(clean.length != 6) return null;
		return FlxColor.fromString('#' + clean);
	}

	function updatePopups()
	{
		if(!rgbPopup.visible || !FlxG.mouse.justPressed) return;
		for (c => swatch in channelSwatches)
			if(FlxG.mouse.overlaps(swatch)) selectChannel(c);
		if(FlxG.mouse.overlaps(rgbPopup)) return;
		var clicked:Int = clickedDirection();
		if(clicked < 0) return;
		rgbNote = clicked;
		refreshRGBColors();
		if(rgbPart == 'splashes') splashAt(rgbNote);
	}

	function partColor(note:Int, channel:Int):FlxColor
	{
		var display:NotePackPart = displayPart(rgbPart);
		var own:Array<Dynamic> = (display.colors != null) ? Reflect.field(display.colors, NotePackData.DIRECTIONS[note]) : null;
		if(own != null && own.length > 2)
		{
			var parsed:Null<FlxColor> = parseHex(Std.string(own[channel]));
			if(parsed != null) return parsed;
		}
		var player:Array<FlxColor> = pixel ? ClientPrefs.data.arrowRGBPixel[note] : ClientPrefs.data.arrowRGB[note];
		return player[channel];
	}

	function refreshRGBColors()
	{
		rgbNoteDropDown.selectedIndex = rgbNote;
		for (c in 0...3)
		{
			var color:FlxColor = partColor(rgbNote, c);
			channelSwatches[c].color = color;
			if(PsychUIInputText.focusOn != channelInputs[c]) channelInputs[c].text = color.toHexString(false, false);
		}
		selectChannel(rgbChannel);
	}

	function selectChannel(channel:Int)
	{
		rgbChannel = channel;
		var swatch:FlxSprite = channelSwatches[channel];
		channelFrame.setPosition(swatch.x - 2, swatch.y - 2);
		rgbPicker.setColor(partColor(rgbNote, channel));
	}

	function setRGBColor(color:FlxColor, ?updateInput:Bool = true)
	{
		var raw:Dynamic = rawSection(rgbPart, true);
		if(raw.colors == null)
		{
			var colors:Dynamic = {};
			for (i => dir in NotePackData.DIRECTIONS)
				Reflect.setField(colors, dir, [for (c in 0...3) partColor(i, c).toHexString(false, false)]);
			raw.colors = colors;
		}
		var dirName:String = NotePackData.DIRECTIONS[rgbNote];
		var list:Array<Dynamic> = Reflect.field(raw.colors, dirName);
		if(list == null || list.length < 3)
		{
			list = [for (c in 0...3) partColor(rgbNote, c).toHexString(false, false)];
			Reflect.setField(raw.colors, dirName, list);
		}
		var hex:String = color.toHexString(false, false);
		list[rgbChannel] = hex;
		unsaved = true;
		channelSwatches[rgbChannel].color = color;
		if(updateInput) channelInputs[rgbChannel].text = hex;

		if(rgbPart == 'notes')
		{
			NotePack.setPreview(file);
			for (group in [notes, sustains])
				for (note in group)
				{
					if(note.noteData != rgbNote || note.rgbShader == null) continue;
					switch(rgbChannel)
					{
						case 0: note.rgbShader.r = color;
						case 1: note.rgbShader.g = color;
						default: note.rgbShader.b = color;
					}
				}
			return;
		}

		if(rgbPart == 'splashes')
		{
			NotePack.setPreview(file);
			var splash:NoteSplash = splashes.members[rgbNote];
			if(splash == null) return;
			if(!splash.alive)
			{
				splashAt(rgbNote);
				return;
			}
			var values:Array<Float> = [color.redFloat, color.greenFloat, color.blueFloat];
			switch(rgbChannel)
			{
				case 0: splash.rgbShader.shader.r.value = values;
				case 1: splash.rgbShader.shader.g.value = values;
				default: splash.rgbShader.shader.b.value = values;
			}
			return;
		}

		var cover:HoldCover = covers.members[rgbNote];
		if(cover != null && cover.rgbShader != null)
		{
			switch(rgbChannel)
			{
				case 0: cover.rgbShader.r = color;
				case 1: cover.rgbShader.g = color;
				default: cover.rgbShader.b = color;
			}
		}
	}

	function resetRGBColors()
	{
		var raw:Dynamic = rawSection(rgbPart, false);
		if(raw != null) Reflect.deleteField(raw, 'colors');
		changed();
		refreshRGBColors();
		showMessage('Applied Default Colors');
	}

	function buildTab(tabName:String, partName:String)
	{
		var menu = mainBox.getTab(tabName).menu;
		var tab:NoteEditorTab = new NoteEditorTab();
		tabs.set(tabName, tab);
		var arrows:Bool = (partName == 'strums' || partName == 'notes');

		menu.add(new FlxText(24, 43, 0, 'Image:'));
		tab.image = new PsychUIInputText(90, 40, 365, '', 8);
		menu.add(tab.image);
		menu.add(new PsychUIButton(222, 74, 'Reload', function() applyTab(), 100, 22));

		tab.pixel = new PsychUICheckBox(34, 125, 'Pixel?', 55);
		tab.pixel.onClick = function() setPixel(tab.pixel.checked);
		menu.add(tab.pixel);

		menu.add(new FlxText(34, 172, 0, 'Note:'));
		var noteY:Float = 188;
		var scaleX:Float = 34;
		var scaleY:Float = 244;
		menu.add(new FlxText(scaleX, scaleY - 16, 0, 'Scale:'));
		tab.scale = new PsychUIInputText(scaleX, scaleY, 50, '', 8);
		menu.add(tab.scale);
		menu.add(new PsychUIButton(scaleX + 54, scaleY - 2, '+', function() nudgeScale(1), 20));
		menu.add(new PsychUIButton(scaleX + 76, scaleY - 2, '-', function() nudgeScale(-1), 20));

		var gridX:Float = 150;
		var gridY:Float = scaleY;
		tab.gridLabel = new FlxText(gridX, gridY - 16, 0, 'Grid (cols,rows):');
		menu.add(tab.gridLabel);
		tab.grid = new PsychUIInputText(gridX, gridY, 60, '', 8);
		menu.add(tab.grid);

		if(arrows)
		{
			tab.animated = new PsychUICheckBox(140, 125, 'Animated?', 70);
			tab.rgb = new PsychUICheckBox(255, 125, 'RGB?', 45);
			tab.antialiasing = new PsychUICheckBox(360, 125, 'Antialiasing?', 85);
		}
		switch(partName)
		{
			case 'strums':
			case 'notes':
				tab.holdNotes = new PsychUICheckBox(330, 170, 'Hold Notes', 70);
				tab.holdNotes.checked = showHoldNotes;
				tab.holdNotes.onClick = function() {
					showHoldNotes = tab.holdNotes.checked;
					rebuildPreview();
				};
				menu.add(tab.holdNotes);
				tab.previewNotes = new PsychUICheckBox(330, 196, 'Preview Notes', 80);
				tab.previewNotes.checked = previewNotes;
				tab.previewNotes.onClick = function() {
					previewNotes = tab.previewNotes.checked;
					rebuildPreview();
				};
				menu.add(tab.previewNotes);
				tab.holdImageLabel = new FlxText(300, scaleY - 16, 0, 'Hold Image (optional):');
				menu.add(tab.holdImageLabel);
				tab.holdImage = new PsychUIInputText(300, scaleY, 155, '', 8);
				menu.add(tab.holdImage);
			default:
				menu.add(new FlxText(250, 135, 0, 'Animations:'));
				tab.rgb = new PsychUICheckBox(250, 200, 'RGB?', 45);
				tab.antialiasing = new PsychUICheckBox(250, 245, 'Antialiasing?', 85);
				if(partName == 'splashes')
				{
					menu.add(new PsychUIButton(365, 196, 'Add', addSplashVariant, 90));
					menu.add(new PsychUIButton(365, 241, 'Remove', removeSplashVariant, 90));
				}
		}
		for (box in [tab.animated, tab.rgb, tab.antialiasing])
		{
			if(box == null) continue;
			box.onClick = function() applyTab(true);
			menu.add(box);
		}

		var header:FlxText = new FlxText(0, 300, BOX_WIDTH, 'Animation', 12);
		header.alignment = CENTER;
		menu.add(header);

		var nameLabel:FlxText = new FlxText(27, 340, 192, 'Animation name');
		nameLabel.alignment = CENTER;
		menu.add(nameLabel);
		tab.prefixLabel = new FlxText(262, 340, 192, 'Animation Prefix');
		tab.prefixLabel.alignment = CENTER;
		menu.add(tab.prefixLabel);
		if(!arrows)
		{
			tab.animName = new PsychUIInputText(27, 356, 192, '', 8);
			tab.animName.active = false;
			menu.add(tab.animName);
		}
		tab.prefix = new PsychUIInputText(262, 356, 192, '', 8);
		menu.add(tab.prefix);

		if(partName == 'holdCovers')
		{
			tab.loop = new PsychUICheckBox(60, 421, 'Loop', 50);
			tab.loop.onClick = function() applyTab(true);
			menu.add(tab.loop);
		}
		else
		{
			tab.indicesLabel = new FlxText(27, 405, 192, 'Indices (optional)');
			tab.indicesLabel.alignment = CENTER;
			menu.add(tab.indicesLabel);
			tab.indices = new PsychUIInputText(27, 421, 192, '', 8);
			menu.add(tab.indices);
		}
		menu.add(new FlxText(262, 405, 0, 'FPS'));
		tab.fps = new PsychUINumericStepper(262, 421, 1, 24, 0, 120, 0);
		menu.add(tab.fps);

		menu.add(new PsychUIButton((BOX_WIDTH - 104) / 2, 500, 'Reset', resetTab, 104, 25));

		tab.anim = new PsychUIDropDownMenu(arrows ? 27 : 250, arrows ? 356 : 151, [''], function(id:Int, name:String) {
			if(part == 'splashes') variant = id;
			else animNames.set(part, name);
			if(part == 'notes' && !previewNotes) rebuildPreview();
			playSelected();
			refreshTab();
		}, arrows ? 192 : 122);
		tab.anim.autoSort = false;
		tab.note = new PsychUIDropDownMenu(34, noteY, [''], function(id:Int, name:String) {
			direction = id;
			playSelected();
			refreshTab();
		}, 122);
		tab.note.autoSort = false;

		if(arrows) menu.add(tab.anim);
		menu.add(tab.note);
		if(!arrows) menu.add(tab.anim);

		for (input in [tab.image, tab.holdImage])
			if(input != null) input.onChange = function(prev:String, next:String) applyImage(next);
		for (input in [tab.scale, tab.grid, tab.prefix, tab.indices])
			if(input != null) input.onChange = function(prev:String, next:String) applyTab(true);
		tab.fps.onValueChange = function() applyTab(true);
	}

	function applyImage(text:String)
	{
		var image:String = text.trim();
		if(image.length < 1 || Paths.fileExists('images/$image.png', IMAGE)) applyTab(true);
	}

	function setInput(input:PsychUIInputText, value:String)
	{
		if(input != null && PsychUIInputText.focusOn != input) input.text = value;
	}

	function nudgeScale(amount:Int)
	{
		var tab:NoteEditorTab = currentTab();
		var current:Float = Std.parseFloat(tab.scale.text);
		if(Math.isNaN(current)) current = defaultScale(displayPart(part));
		var step:Float = NotePack.isGridded(displayPart(part)) ? 0.5 : 0.05;
		var value:Float = Math.round((current + step * amount) * 100) / 100;
		if(value < step) value = step;
		tab.scale.text = Std.string(value);
		applyTab(true);
	}

	function imagesFound():Bool
	{
		for (name in NotePackData.PARTS)
		{
			var display:NotePackPart = displayPart(name);
			for (image in [display.image, display.holdImage])
				if(image != null && image.length > 0 && !Paths.fileExists('images/$image.png', IMAGE)) return false;
		}
		return true;
	}

	function currentTab():NoteEditorTab
		return tabs.get(tabNames[tabParts.indexOf(part)]);

	function displayPart(name:String):NotePackPart
	{
		var raw:NotePackPart = NotePackData.rawPart(file, name, opponent, pixel);
		var merged:NotePackPart = NotePackData.mergePart(NotePackData.defaultPart(name, pixel), raw, name);
		if(name == 'splashes' && merged.animations == null) merged.animations = legacySplashAnims(merged.image);
		return merged;
	}

	function legacySplashAnims(image:String):Dynamic
	{
		var lists:Array<Array<NotePackAnim>> = [[], [], [], []];
		var colors:Array<String> = Note.colArray;
		if(Paths.fileExists('images/$image.json', TEXT))
		{
			try
			{
				var json:Dynamic = Json.parse(Paths.getTextFromFile('images/$image.json'));
				if(json.animations != null)
				{
					var found:Array<Dynamic> = [for (key in Reflect.fields(json.animations)) Reflect.field(json.animations, key)];
					found.sort(function(a:Dynamic, b:Dynamic) return Std.int(a.noteData) - Std.int(b.noteData));
					for (anim in found)
					{
						var data:Int = Std.int(anim.noteData);
						var fps:Array<Dynamic> = anim.fps;
						lists[data % 4].push({prefix: anim.prefix, offsets: anim.offsets, indices: anim.indices, fps: (fps != null && fps.length > 1) ? fps[1] : 24});
					}
				}
			}
			catch(e:Dynamic) {}
		}
		if(lists[0].length < 1 && image == 'pixelUI/pixelNoteSplash')
			for (i => col in ['purple', 'blue', 'green', 'orange'])
				for (number in 1...4) lists[i].push({prefix: '$col$number', offsets: [-140.8, -135], fps: 35});
		if(lists[0].length < 1)
			for (i in 0...4) lists[i].push({prefix: 'note splash ${colors[i]} 1', offsets: [0, 0], fps: 24});

		var result:Dynamic = {};
		for (i => dir in NotePackData.DIRECTIONS) Reflect.setField(result, dir, lists[i]);
		return result;
	}

	function animList(name:String, display:NotePackPart):Array<String>
	{
		if(name != 'splashes') return NotePackData.PART_ANIMS.get(name).copy();
		var count:Int = splashVariantCount(display);
		return [for (i in 0...count) 'Variant ${i + 1}'];
	}

	function splashVariantCount(display:NotePackPart):Int
	{
		var count:Int = 0;
		for (i in 0...4)
		{
			var list:Array<NotePackAnim> = NotePackData.splashAnims(display, i);
			var length:Int = (list != null) ? list.length : 0;
			if(i == 0 || length < count) count = length;
		}
		return Std.int(Math.max(1, count));
	}

	function currentAnimName():String
		return (part == 'splashes') ? 'Variant ${variant + 1}' : animNames.get(part);

	function displayAnim(display:NotePackPart):NotePackAnim
	{
		if(part == 'splashes')
		{
			var list:Array<NotePackAnim> = NotePackData.splashAnims(display, direction);
			return (list != null && variant < list.length) ? list[variant] : null;
		}
		return NotePackData.anim(display, direction, animNames.get(part));
	}

	function refreshTab()
	{
		var tab:NoteEditorTab = currentTab();
		var display:NotePackPart = displayPart(part);
		var gridded:Bool = NotePack.isGridded(display);

		setInput(tab.image, (display.image != null) ? display.image : '');
		tab.pixel.checked = pixel;
		tab.rgb.checked = display.rgb != false;
		tab.antialiasing.checked = display.antialiasing != false;
		setInput(tab.scale, Std.string((display.scale != null) ? display.scale : defaultScale(display)));
		setInput(tab.grid, (display.grid != null) ? display.grid.join(',') : '');
		tab.grid.visible = tab.gridLabel.visible = pixel;
		if(tab.holdImage != null)
		{
			setInput(tab.holdImage, (display.holdImage != null) ? display.holdImage : '');
			tab.holdImage.visible = tab.holdImageLabel.visible = pixel || display.holdImage != null;
		}
		tab.note.list = DIRECTION_NAMES.copy();
		tab.note.selectedIndex = direction;

		var names:Array<String> = animList(part, display);
		if(part == 'splashes' && variant >= names.length) variant = names.length - 1;
		tab.anim.list = names;
		tab.anim.selectedLabel = currentAnimName();
		if(tab.animName != null) tab.animName.text = currentAnimName();
		if(tab.holdNotes != null) tab.holdNotes.checked = showHoldNotes;
		if(tab.previewNotes != null) tab.previewNotes.checked = previewNotes;

		var anim:NotePackAnim = displayAnim(display);
		tab.prefixLabel.text = gridded ? 'Frames (numbers, commas)' : 'Animation Prefix';
		if(anim != null)
		{
			setInput(tab.prefix, gridded ? ((anim.frames != null) ? anim.frames.join(',') : '') : ((anim.prefix != null) ? anim.prefix : ''));
			setInput(tab.indices, (anim.indices != null && anim.indices.length > 0) ? anim.indices.join(',') : '');
			if(PsychUIInputText.focusOn != tab.fps) tab.fps.value = (anim.fps != null) ? anim.fps : 24;
			if(tab.loop != null) tab.loop.checked = anim.loop == true;
		}
		else
		{
			setInput(tab.prefix, '');
			setInput(tab.indices, '');
			if(PsychUIInputText.focusOn != tab.fps) tab.fps.value = 24;
		}
		if(tab.indices != null) tab.indices.visible = tab.indicesLabel.visible = !gridded;

		if(tab.animated != null)
		{
			var idle:NotePackAnim = NotePackData.anim(display, direction, (part == 'strums') ? 'static' : 'note');
			tab.animated.checked = idle != null && idle.loop == true;
		}
		refreshStatus();
	}

	function defaultScale(display:NotePackPart):Float
	{
		if(NotePack.isGridded(display)) return PlayState.daPixelZoom;
		return (part == 'strums' || part == 'notes') ? 0.7 : 1;
	}

	function refreshStatus()
	{
		var display:NotePackPart = displayPart(part);
		var anim:NotePackAnim = displayAnim(display);
		var animOffsets:Array<Float> = (anim != null && anim.offsets != null && anim.offsets.length > 1) ? anim.offsets : [0, 0];
		var baseOffsets:Array<Float> = (display.offsets != null && display.offsets.length > 1) ? display.offsets : [0, 0];
		var extra:String = (part == 'holdCovers') ? ' | ${DIRECTION_NAMES[direction]}' : '';
		animText.text = 'Animation: ${currentAnimName()} [${animOffsets[0]}, ${animOffsets[1]}]$extra';
		offsetText.text = 'Offsets: [${baseOffsets[0]}, ${baseOffsets[1]}]';
		var tab:NoteEditorTab = currentTab();
		animText.visible = (tab.animated == null) || tab.animated.checked || part == 'strums';
	}

	function rawSection(name:String, create:Bool):Dynamic
	{
		var root:Dynamic = file;
		if(pixel)
		{
			if(Reflect.field(file, 'pixel') == null)
			{
				if(!create) return null;
				Reflect.setField(file, 'pixel', {});
			}
			root = Reflect.field(file, 'pixel');
		}
		var sideName:String = (opponent && name != 'splashes') ? 'opponent' : 'player';
		var side:Dynamic = Reflect.field(root, sideName);
		if(side == null)
		{
			if(!create) return null;
			side = {};
			Reflect.setField(root, sideName, side);
		}
		var raw:Dynamic = Reflect.field(side, name);
		if(raw == null && create)
		{
			raw = {};
			if(sideName == 'opponent')
			{
				var player:Dynamic = Reflect.field(root, 'player');
				var source:Dynamic = (player != null) ? Reflect.field(player, name) : null;
				if(source != null) raw = Json.parse(Json.stringify(source));
			}
			Reflect.setField(side, name, raw);
		}
		return raw;
	}

	function rawAnim(raw:Dynamic, ?animName:String):Dynamic
	{
		var display:NotePackPart = displayPart(part);
		if(raw.animations == null)
			raw.animations = (part == 'splashes') ? Json.parse(Json.stringify(display.animations)) : {};
		var dirName:String = NotePackData.DIRECTIONS[direction];
		var dir:Dynamic = Reflect.field(raw.animations, dirName);
		if(part == 'splashes')
		{
			if(dir == null || !Std.isOfType(dir, Array))
			{
				dir = Json.parse(Json.stringify(NotePackData.splashAnims(display, direction)));
				Reflect.setField(raw.animations, dirName, dir);
			}
			var list:Array<Dynamic> = dir;
			while(list.length <= variant) list.push({});
			return list[variant];
		}
		if(dir == null)
		{
			dir = {};
			Reflect.setField(raw.animations, dirName, dir);
		}
		var name:String = (animName != null) ? animName : animNames.get(part);
		var anim:Dynamic = Reflect.field(dir, name);
		if(anim == null)
		{
			anim = {};
			Reflect.setField(dir, name, anim);
		}
		return anim;
	}

	function setField(target:Dynamic, field:String, value:Dynamic, defaultValue:Dynamic)
	{
		if(value == null || value == defaultValue) Reflect.deleteField(target, field);
		else Reflect.setField(target, field, value);
	}

	function parseNumbers(text:String):Array<Int>
	{
		var result:Array<Int> = [];
		for (piece in text.split(','))
		{
			var number:Null<Int> = Std.parseInt(piece.trim());
			if(number != null) result.push(number);
		}
		return result;
	}

	function applyTab(?silent:Bool = false)
	{
		var tab:NoteEditorTab = currentTab();
		var display:NotePackPart = displayPart(part);
		var base:NotePackPart = NotePackData.defaultPart(part, pixel);
		var raw:Dynamic = rawSection(part, true);

		var image:String = tab.image.text.trim();
		setField(raw, 'image', (image.length > 0) ? image : null, base.image);
		setField(raw, 'rgb', tab.rgb.checked, base.rgb != false);
		setField(raw, 'antialiasing', tab.antialiasing.checked, base.antialiasing != false);
		var scale:Float = Std.parseFloat(tab.scale.text);
		if(!Math.isNaN(scale) && scale > 0) setField(raw, 'scale', scale, (base.scale != null) ? base.scale : defaultScale(base));
		if(pixel)
		{
			var grid:Array<Int> = parseNumbers(tab.grid.text);
			if(grid.length > 1) raw.grid = [grid[0], grid[1]];
			else Reflect.deleteField(raw, 'grid');
		}
		if(tab.holdImage != null)
		{
			var holdImage:String = tab.holdImage.text.trim();
			setField(raw, 'holdImage', (holdImage.length > 0) ? holdImage : null, base.holdImage);
		}

		var merged:NotePackPart = NotePackData.mergePart(base, raw, part);
		var gridded:Bool = NotePack.isGridded(merged);
		var anim:Dynamic = rawAnim(raw);
		if(gridded)
		{
			anim.frames = parseNumbers(tab.prefix.text);
			Reflect.deleteField(anim, 'prefix');
			Reflect.deleteField(anim, 'indices');
		}
		else
		{
			anim.prefix = tab.prefix.text.trim();
			if(tab.indices != null)
			{
				var indices:Array<Int> = parseNumbers(tab.indices.text);
				if(indices.length > 0) anim.indices = indices;
				else Reflect.deleteField(anim, 'indices');
			}
		}
		anim.fps = tab.fps.value;
		if(tab.loop != null) anim.loop = tab.loop.checked;
		if(tab.animated != null)
		{
			var idle:Dynamic = rawAnim(raw, (part == 'strums') ? 'static' : 'note');
			idle.loop = tab.animated.checked;
		}

		changed();
		if(!imagesFound()) showMessage('Image not found!', true);
		else if(!silent) showMessage('Applied ${tabNames[tabParts.indexOf(part)]}${pixel ? ' (pixel)' : ''}');
	}

	function resetTab()
	{
		var label:String = '${DIRECTION_NAMES[direction]} (${currentAnimName()})';
		openSubState(new Prompt('Reset $label to default?', function() {
			var raw:Dynamic = rawSection(part, false);
			var all:Dynamic = (raw != null) ? raw.animations : null;
			var dirName:String = NotePackData.DIRECTIONS[direction];
			var dir:Dynamic = (all != null) ? Reflect.field(all, dirName) : null;
			if(dir != null)
			{
				if(part == 'splashes' && Std.isOfType(dir, Array))
				{
					var list:Array<Dynamic> = dir;
					var base:Array<NotePackAnim> = NotePackData.splashAnims(defaultSplashPart(raw), direction);
					if(variant < list.length) list[variant] = (base != null && variant < base.length) ? Json.parse(Json.stringify(base[variant])) : {};
				}
				else if(!Std.isOfType(dir, Array))
				{
					Reflect.deleteField(dir, animNames.get(part));
					if(Reflect.fields(dir).length < 1) Reflect.deleteField(all, dirName);
				}
				if(Reflect.fields(all).length < 1) Reflect.deleteField(raw, 'animations');
			}
			changed();
			showMessage('Reset to Default');
		}, null, 'Reset'));
	}

	function defaultSplashPart(raw:Dynamic):NotePackPart
	{
		var copy:Dynamic = Json.parse(Json.stringify(raw));
		Reflect.deleteField(copy, 'animations');
		var merged:NotePackPart = NotePackData.mergePart(NotePackData.defaultPart('splashes', pixel), copy, 'splashes');
		if(merged.animations == null) merged.animations = legacySplashAnims(merged.image);
		return merged;
	}

	function addSplashVariant()
	{
		var raw:Dynamic = rawSection('splashes', true);
		var display:NotePackPart = displayPart('splashes');
		if(raw.animations == null) raw.animations = Json.parse(Json.stringify(display.animations));
		var count:Int = splashVariantCount(display);
		for (i => dirName in NotePackData.DIRECTIONS)
		{
			var list:Array<Dynamic> = Reflect.field(raw.animations, dirName);
			if(list == null)
			{
				list = Json.parse(Json.stringify(NotePackData.splashAnims(display, i)));
				Reflect.setField(raw.animations, dirName, list);
			}
			while(list.length > count) list.pop();
			list.push(Json.parse(Json.stringify(list[list.length - 1])));
		}
		variant = count;
		changed();
	}

	function removeSplashVariant()
	{
		var display:NotePackPart = displayPart('splashes');
		var count:Int = splashVariantCount(display);
		if(count < 2)
		{
			showMessage('Splashes require at least ONE variant!', true);
			return;
		}
		var raw:Dynamic = rawSection('splashes', true);
		if(raw.animations == null) raw.animations = Json.parse(Json.stringify(display.animations));
		for (i => dirName in NotePackData.DIRECTIONS)
		{
			var list:Array<Dynamic> = Reflect.field(raw.animations, dirName);
			if(list == null)
			{
				list = Json.parse(Json.stringify(NotePackData.splashAnims(display, i)));
				Reflect.setField(raw.animations, dirName, list);
			}
			if(variant < list.length) list.splice(variant, 1);
		}
		variant = Std.int(Math.max(0, variant - 1));
		changed();
	}

	function changed()
	{
		unsaved = true;
		rebuildPreview();
		refreshTab();
	}

	function setPixel(value:Bool)
	{
		pixel = value;
		for (tab in tabs) tab.pixel.checked = value;
		rebuildPreview();
		refreshTab();
	}

	function strumX(index:Int):Float
		return (PREVIEW_WIDTH - Note.swagWidth * 4) / 2 + Note.swagWidth * index;

	function rebuildPreview()
	{
		NotePack.setPreview(file);
		PlayState.stageUI = pixel ? 'pixel' : 'normal';

		clearGroup(strums);
		clearGroup(notes);
		clearGroup(sustains);
		clearGroup(ghostNotes);
		hitNotes = [];
		clearGroup(splashes);
		clearGroup(covers);
		clearGroup(ghosts);
		var y:Float = (part == 'notes') ? NOTES_STRUM_Y : STRUM_Y;
		for (i in 0...4)
		{
			var strum:StrumNote = new StrumNote(strumX(i), y, i, opponent ? 0 : 1, opponent);
			strum.ID = i;
			strum.scrollFactor.set();
			strum.playAnim('static', true);
			strums.add(strum);
		}

		NotePack.setPreview({});
		for (i in 0...4)
		{
			var ghost:StrumNote = new StrumNote(strumX(i), y, i, opponent ? 0 : 1, opponent);
			ghost.ID = i;
			ghost.scrollFactor.set();
			ghost.alpha = GHOST_ALPHA;
			ghost.playAnim('static', true);
			ghosts.add(ghost);
		}
		ghosts.visible = ghostNotes.visible = showGhost;
		NotePack.setPreview(file);

		if(part == 'holdCovers') createCovers();
		else if(part == 'splashes') createSplashes();
		else if(part == 'notes')
		{
			previewTime = 0;
			nextNoteTime = 600;
			noteCounter = 0;
			if(!previewNotes) createStaticNotes();
		}
		holdingKeys = [false, false, false, false];
		playSelected(false);
		positionCovers();
	}

	function createCovers()
	{
		clearGroup(covers);
		for (i in 0...4)
		{
			var cover:HoldCover = new HoldCover(i, opponent, pixel, FlxG.camera, opponent);
			cover.rgbShader = new RGBShaderReference(cover, Note.initializeGlobalRGBShader(i));
			var colors:Array<FlxColor> = cover.packColors();
			if(colors == null) colors = pixel ? ClientPrefs.data.arrowRGBPixel[i] : ClientPrefs.data.arrowRGB[i];
			cover.rgbShader.r = colors[0];
			cover.rgbShader.g = colors[1];
			cover.rgbShader.b = colors[2];
			cover.rgbShader.enabled = cover.useRGB;
			covers.add(cover);
		}
	}

	function createSplashes()
	{
		clearGroup(splashes);
		for (i in 0...4)
		{
			var splash:NoteSplash = new NoteSplash();
			splash.babyArrow = strums.members[i];
			splashes.add(splash);
			splash.kill();
		}
	}

	function positionCovers()
	{
		var endMode:Bool = animNames.get('holdCovers') == 'end';
		for (i => cover in covers.members)
		{
			if(cover == null) continue;
			var anim = cover.animation.curAnim;
			if(anim != null && anim.name == 'end' && anim.finished)
			{
				if(endMode)
				{
					cover.visible = false;
					continue;
				}
				cover.animation.play('hold', true);
				cover.visible = true;
			}
			if(!cover.visible) continue;
			cover.followStrum(strums.members[i], pixel);
			cover.alpha = 1;
			cover.visible = true;
		}
	}

	function playCoverEnd(index:Int)
	{
		var cover:HoldCover = covers.members[index];
		if(cover == null) return;
		cover.visible = true;
		cover.animation.play('end', true);
		positionCovers();
	}

	function setPaused(value:Bool)
	{
		paused = value;
		var groups:Array<flixel.FlxBasic> = [strums, ghosts, ghostNotes, sustains, notes, covers, splashes];
		for (group in groups) group.active = !value;
	}

	function frameTarget():FlxSprite
	{
		switch(part)
		{
			case 'strums':
				return strums.members[direction];
			case 'notes':
				if(!previewNotes)
					for (note in notes)
						if(note.noteData == direction) return note;
			case 'splashes':
				var splash:NoteSplash = splashes.members[direction];
				return (splash != null && splash.alive) ? splash : null;
			case 'holdCovers':
				var cover:HoldCover = covers.members[direction];
				return (cover != null && cover.visible) ? cover : null;
		}
		return null;
	}

	function stepFrame(amount:Int)
	{
		if(part == 'notes' && previewNotes)
		{
			var step:Float = amount / 60;
			updateNotesPreview(step);
			if(step > 0)
			{
				var groups:Array<flixel.FlxBasic> = [strums, ghosts, sustains, notes];
				for (group in groups) group.update(step);
			}
			return;
		}
		var sprite:FlxSprite = frameTarget();
		if(sprite == null || sprite.animation.curAnim == null) return;
		var anim = sprite.animation.curAnim;
		anim.curFrame = FlxMath.wrap(anim.curFrame + amount, 0, anim.numFrames - 1);
		if(part == 'holdCovers') positionCovers();
	}

	function updateFrameKeys(elapsed:Float)
	{
		var back:Bool = FlxG.keys.pressed.Q;
		var forward:Bool = FlxG.keys.pressed.E;
		if(back || forward)
		{
			holdingFrameTime += elapsed;
			if(holdingFrameTime > 0.5) holdingFrameElapsed += elapsed;
		}
		else
		{
			holdingFrameTime = 0;
			holdingFrameElapsed = 0;
		}

		var amount:Int = 0;
		if(FlxG.keys.justPressed.Q) amount = -1;
		else if(FlxG.keys.justPressed.E) amount = 1;
		else if(holdingFrameTime > 0.5 && holdingFrameElapsed > 0.1)
		{
			amount = back ? -1 : 1;
			holdingFrameElapsed -= 0.1;
		}
		if(amount == 0) return;
		if(!paused) setPaused(true);
		stepFrame(amount);
	}

	function updateFrameText()
	{
		var text:String = '';
		if(part == 'notes' && previewNotes) text = 'Time: ${Std.int(previewTime)} ms';
		else
		{
			var sprite:FlxSprite = frameTarget();
			if(sprite != null && sprite.animation.curAnim != null)
				text = 'Frames: ( ${sprite.animation.curAnim.curFrame} / ${sprite.animation.curAnim.numFrames - 1} )';
		}
		if(paused) text += (text.length > 0 ? ' - ' : '') + 'PAUSED';
		if(frameText.text != text) frameText.text = text;
	}

	function updateTestKeys()
	{
		for (i in 0...4)
		{
			var strum:StrumNote = strums.members[i];
			if(strum == null || testKeys[i].length < 1) continue;
			if(FlxG.keys.anyJustPressed(testKeys[i]))
			{
				holdingKeys[i] = true;
				switch(part)
				{
					case 'splashes':
						splashAt(i);
					case 'holdCovers':
						strum.playAnim('confirm', true);
						strum.resetAnim = 0;
						var cover:HoldCover = covers.members[i];
						if(cover != null)
						{
							cover.visible = true;
							cover.animation.play('hold', true);
						}
					default:
						strum.playAnim('pressed', true);
						strum.resetAnim = 0;
				}
			}
			if(holdingKeys[i] && !FlxG.keys.anyPressed(testKeys[i]))
			{
				holdingKeys[i] = false;
				if(part == 'splashes') continue;
				strum.playAnim('static', true);
				strum.resetAnim = 0;
				var cover:HoldCover = covers.members[i];
				if(part == 'holdCovers' && cover != null) cover.playEnd();
			}
		}
		if(part == 'holdCovers') positionCovers();
	}

	function animState(sprite:FlxSprite):Array<Dynamic>
	{
		if(sprite == null || !sprite.alive || sprite.animation.curAnim == null) return null;
		return [sprite.animation.curAnim.name, sprite.animation.curAnim.curFrame];
	}

	function restoreFrame(sprite:FlxSprite, state:Array<Dynamic>)
	{
		if(sprite.animation.curAnim == null) return;
		var frame:Int = state[1];
		sprite.animation.curAnim.curFrame = Std.int(Math.min(frame, sprite.animation.curAnim.numFrames - 1));
	}

	function refreshAfterOffset()
	{
		NotePack.setPreview(file);
		switch(part)
		{
			case 'strums':
				var states:Array<Array<Dynamic>> = [for (strum in strums.members) animState(strum)];
				for (i => strum in strums.members)
				{
					strum.refreshPack();
					var state:Array<Dynamic> = states[i];
					if(state == null || !strum.animation.exists(state[0])) continue;
					strum.playAnim(state[0], true);
					restoreFrame(strum, state);
				}
			case 'notes':
				for (note in notes) note.reloadNote();
				for (sustain in sustains) sustain.refreshPackPart();
			case 'splashes':
				var states:Array<Array<Dynamic>> = [for (splash in splashes.members) animState(splash)];
				var data:Array<Int> = [for (splash in splashes.members) splash.noteData];
				createSplashes();
				var shown:Bool = false;
				for (i => splash in splashes.members)
				{
					var state:Array<Dynamic> = states[i];
					if(state == null) continue;
					var strum:StrumNote = strums.members[i];
					splash.revive();
					splash.spawnSplashNote(strum.x, strum.y, data[i], null, false);
					restoreFrame(splash, state);
					if(i == direction) shown = true;
				}
				if(!shown) splashAt(direction);
			case 'holdCovers':
				var states:Array<Array<Dynamic>> = [for (cover in covers.members) animState(cover)];
				var shown:Array<Bool> = [for (cover in covers.members) cover.visible];
				createCovers();
				for (i => cover in covers.members)
				{
					cover.visible = shown[i];
					var state:Array<Dynamic> = states[i];
					if(state == null || !cover.animation.exists(state[0])) continue;
					cover.animation.play(state[0], true);
					restoreFrame(cover, state);
				}
				if(animNames.get('holdCovers') == 'end' && !covers.members[direction].visible) playCoverEnd(direction);
				positionCovers();
		}
	}

	function clearGroup<T:flixel.FlxBasic>(group:FlxTypedGroup<T>)
	{
		for (member in group.members) if(member != null) member.destroy();
		group.clear();
	}

	function playSelected(?withSplash:Bool = true)
	{
		for (strum in strums)
		{
			var anim:String = (part == 'strums' && strum.ID == direction) ? animNames.get('strums') : 'static';
			if(strum.animation.exists(anim)) strum.playAnim(anim, true);
			else strum.playAnim('static', true);
		}
		for (ghost in ghosts) ghost.playAnim(strumAnim(ghost.ID), true);
		var endMode:Bool = animNames.get('holdCovers') == 'end';
		for (cover in covers.members)
		{
			if(cover == null) continue;
			cover.visible = !endMode;
			if(!endMode) cover.animation.play('hold', true);
		}
		if(withSplash && part == 'holdCovers' && endMode) playCoverEnd(direction);
		positionCovers();
		if(withSplash && part == 'splashes') splashAt(direction);
	}

	function splashAt(index:Int)
	{
		var strum:StrumNote = strums.members[index];
		var splash:NoteSplash = splashes.members[index];
		if(strum == null || splash == null) return;
		pressStrum(strum);
		splash.revive();
		splash.spawnSplashNote(strum.x, strum.y, index + variant * Note.colArray.length, null, false);
	}

	function pressStrum(strum:StrumNote)
	{
		if(strum == null) return;
		strum.playAnim('confirm', true);
		strum.resetAnim = 0.15;
	}

	function strumAnim(index:Int):String
	{
		var strum:StrumNote = strums.members[index];
		return (strum != null && strum.animation.curAnim != null) ? strum.animation.curAnim.name : 'static';
	}

	function syncGhosts()
	{
		if(!ghosts.visible) return;
		for (ghost in ghosts)
		{
			var strum:StrumNote = strums.members[ghost.ID];
			if(strum == null || strum.animation.curAnim == null) continue;
			var name:String = strum.animation.curAnim.name;
			var current:String = (ghost.animation.curAnim != null) ? ghost.animation.curAnim.name : '';
			var restarted:Bool = name == current && strum.animation.curAnim.curFrame == 0 && ghost.animation.curAnim.curFrame > 0;
			if((name != current || restarted) && ghost.animation.exists(name)) ghost.playAnim(name, true);
		}
	}

	function setGhost(value:Bool)
	{
		showGhost = value;
		ghostCheckBox.checked = value;
		ghosts.visible = ghostNotes.visible = value;
		if(value) for (ghost in ghosts) ghost.playAnim(strumAnim(ghost.ID), true);
	}

	function createNote(time:Float, dir:Int, holds:Bool, heads:FlxTypedGroup<Note>, tails:FlxTypedGroup<Note>):Note
	{
		var head:Note = new Note(time, dir, null, false, true, null, opponent);
		head.scrollFactor.set();
		if(holds)
		{
			var previous:Note = head;
			for (piece in 0...HOLD_PIECES)
			{
				var sustain:Note = new Note(time + Conductor.stepCrochet * piece, dir, previous, true, true, {songSpeed: NOTE_SPEED}, opponent);
				sustain.flipY = false;
				sustain.scrollFactor.set();
				sustain.correctionOffset = head.height / 2;
				if(previous.isSustainNote && !pixel)
				{
					previous.scale.y *= Note.SUSTAIN_SIZE / previous.frameHeight;
					previous.updateHitbox();
				}
				tails.add(sustain);
				previous = sustain;
			}
		}
		heads.add(head);
		return head;
	}

	function spawnPreviewNote()
	{
		createNote(nextNoteTime, noteCounter % 4, showHoldNotes, notes, sustains);
		noteCounter++;
		nextNoteTime += NOTE_GAP;
	}

	function createStaticNotes()
	{
		Conductor.songPosition = previewTime;
		var time:Float = previewTime + STATIC_NOTE_DISTANCE / (0.45 * NOTE_SPEED);
		var holds:Bool = showHoldNotes || animNames.get('notes') != 'note';
		NotePack.setPreview({});
		for (i in 0...4) createNote(time, i, holds, ghostNotes, ghostNotes);
		NotePack.setPreview(file);
		for (i in 0...4) createNote(time, i, holds, notes, sustains);
		followNotes();
	}

	function followNotes()
	{
		Conductor.songPosition = previewTime;
		for (group in [notes, sustains])
			for (note in group)
				note.followStrumNote(strums.members[note.noteData], Conductor.stepCrochet, NOTE_SPEED);
		for (note in ghostNotes)
			note.followStrumNote(ghosts.members[note.noteData], Conductor.stepCrochet, NOTE_SPEED);
	}

	function updateNotesPreview(elapsed:Float)
	{
		previewTime += elapsed * 1000;
		Conductor.songPosition = previewTime;
		if(previewTime >= nextNoteTime - 2000) spawnPreviewNote();

		var dead:Array<Note> = [];
		var tailTime:Float = showHoldNotes ? Conductor.stepCrochet * HOLD_PIECES : 0;
		for (note in notes)
		{
			var strum:StrumNote = strums.members[note.noteData];
			note.followStrumNote(strum, Conductor.stepCrochet, NOTE_SPEED);
			if(note.strumTime <= previewTime && !hitNotes.contains(note))
			{
				hitNotes.push(note);
				note.visible = false;
				pressStrum(strum);
			}
			if(previewTime > note.strumTime + tailTime) dead.push(note);
		}
		for (sustain in sustains)
		{
			var strum:StrumNote = strums.members[sustain.noteData];
			sustain.followStrumNote(strum, Conductor.stepCrochet, NOTE_SPEED);
			if(sustain.strumTime <= previewTime)
			{
				if(!hitNotes.contains(sustain))
				{
					hitNotes.push(sustain);
					pressStrum(strum);
				}
				sustain.wasGoodHit = true;
				sustain.clipToStrumNote(strum);
			}
			if(previewTime > sustain.strumTime + Conductor.stepCrochet) dead.push(sustain);
		}
		for (note in dead)
		{
			if(note.isSustainNote) sustains.remove(note, true);
			else notes.remove(note, true);
			hitNotes.remove(note);
			note.destroy();
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(mainBox.selectedName != lastTab)
		{
			lastTab = mainBox.selectedName;
			var index:Int = tabNames.indexOf(lastTab);
			if(index > -1)
			{
				gameplayTab = tabParts[index] == 'gameplay';
				part = gameplayTab ? 'notes' : tabParts[index];
				rebuildPreview();
				if(gameplayTab) refreshGameplay();
				else refreshTab();
			}
		}

		if(!paused)
		{
			if(part == 'notes')
			{
				if(previewNotes) updateNotesPreview(elapsed);
			}
		}
		if(part == 'notes' && (paused || !previewNotes)) followNotes();
		syncGhosts();
		positionCovers();
		updateFrameText();
		if(popupOpen()) updatePopups();

		if(PsychUIInputText.focusOn != null)
		{
			ClientPrefs.toggleVolumeKeys(false);
			return;
		}
		ClientPrefs.toggleVolumeKeys(true);

		if(FlxG.mouse.justPressed || FlxG.mouse.justPressedRight)
			FlxG.sound.play(Paths.sound('chartingSounds/ClickDown'), 0.75);
		if(FlxG.mouse.justReleased || FlxG.mouse.justReleasedRight)
			FlxG.sound.play(Paths.sound('chartingSounds/ClickUp'), 0.75);

		if(popupOpen())
		{
			if(FlxG.keys.justPressed.ESCAPE) closePopups();
			return;
		}

		if(FlxG.keys.justPressed.F1)
		{
			openSubState(new NoteEditorHelpSubState());
			return;
		}
		if(FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S)
		{
			saveFile();
			return;
		}
		if(FlxG.keys.justPressed.ESCAPE)
		{
			exitEditor();
			return;
		}
		if(FlxG.keys.justPressed.SPACE) setPaused(!paused);
		if(FlxG.keys.justPressed.G) setGhost(!showGhost);
		updateTestKeys();
		updateFrameKeys(elapsed);

		if(FlxG.mouse.justPressed && !FlxG.mouse.overlaps(mainBox) && !upperBoxOpen())
		{
			var clicked:Int = clickedDirection();
			if(clicked > -1)
			{
				direction = clicked;
				playSelected();
				refreshTab();
			}
		}

		updateOffsetKeys(elapsed);
	}

	function clickedDirection():Int
	{
		if(part == 'notes')
			for (group in [notes, sustains, ghostNotes])
				for (note in group)
					if(group.visible && spriteClicked(note)) return note.noteData;
		for (strum in strums)
			if(spriteClicked(strum)) return strum.ID;
		for (ghost in ghosts)
			if(ghosts.visible && spriteClicked(ghost)) return ghost.ID;
		return -1;
	}

	function spriteClicked(sprite:FlxSprite):Bool
	{
		if(sprite == null || !sprite.alive || !sprite.visible) return false;
		var bounds:flixel.math.FlxRect = sprite.getScreenBounds(null, FlxG.camera);
		var mouse:FlxPoint = FlxG.mouse.getScreenPosition(FlxG.camera);
		var hit:Bool = bounds.containsPoint(mouse);
		bounds.put();
		mouse.put();
		return hit;
	}

	function upperBoxOpen():Bool
		return upperBox != null && !upperBox.isMinimized;

	function updateOffsetKeys(elapsed:Float)
	{
		if(gameplayTab) return;
		var multiplier:Int = FlxG.keys.pressed.SHIFT ? 10 : 1;
		var pressed:Array<Bool> = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];
		var held:Array<Bool> = [FlxG.keys.pressed.LEFT, FlxG.keys.pressed.RIGHT, FlxG.keys.pressed.UP, FlxG.keys.pressed.DOWN];
		var moveX:Int = 0;
		var moveY:Int = 0;
		if(pressed.contains(true))
		{
			moveX = ((pressed[1] ? 1 : 0) - (pressed[0] ? 1 : 0)) * multiplier;
			moveY = ((pressed[3] ? 1 : 0) - (pressed[2] ? 1 : 0)) * multiplier;
		}
		if(held.contains(true))
		{
			holdingArrowsTime += elapsed;
			if(holdingArrowsTime > 0.5)
			{
				holdingArrowsElapsed += elapsed;
				while(holdingArrowsElapsed > 1 / 30)
				{
					moveX += ((held[1] ? 1 : 0) - (held[0] ? 1 : 0)) * multiplier;
					moveY += ((held[3] ? 1 : 0) - (held[2] ? 1 : 0)) * multiplier;
					holdingArrowsElapsed -= 1 / 30;
				}
			}
		}
		else
		{
			holdingArrowsTime = 0;
			holdingArrowsElapsed = 0;
		}
		if(moveX == 0 && moveY == 0) return;
		if(part != 'holdCovers')
		{
			moveX = -moveX;
			moveY = -moveY;
		}

		var display:NotePackPart = displayPart(part);
		var raw:Dynamic = rawSection(part, true);
		if(FlxG.keys.pressed.CONTROL)
		{
			var current:Array<Float> = (display.offsets != null && display.offsets.length > 1) ? display.offsets : [0, 0];
			raw.offsets = [current[0] + moveX, current[1] + moveY];
		}
		else
		{
			var anim:NotePackAnim = displayAnim(display);
			var current:Array<Float> = (anim != null && anim.offsets != null && anim.offsets.length > 1) ? anim.offsets : [0, 0];
			var target:Dynamic = rawAnim(raw);
			if(Reflect.field(target, 'prefix') == null && Reflect.field(target, 'frames') == null && anim != null)
			{
				if(anim.prefix != null) target.prefix = anim.prefix;
				if(anim.frames != null) target.frames = anim.frames.copy();
			}
			target.offsets = [current[0] + moveX, current[1] + moveY];
		}
		unsaved = true;
		refreshAfterOffset();
		refreshStatus();
	}

	function refreshShader()
	{
		var opp:Bool = shaderSideDropDown.selectedIndex == 1;
		var tint:NotePackTint = NotePackData.tint(file, opp);
		var own:Dynamic = (Reflect.field(file, 'tint') != null) ? Reflect.field(Reflect.field(file, 'tint'), opp ? 'opponent' : 'player') : null;
		if(tint != null && (own != null || !opp))
		{
			shaderColorInput.text = tint.color;
			shaderStrengthInput.text = Std.string(tint.strength);
		}
		else shaderStrengthInput.text = '0';
		var parsed:Null<FlxColor> = parseHex(shaderColorInput.text);
		if(parsed == null) parsed = FlxColor.RED;
		shaderSwatch.color = parsed;
		shaderPicker.setColor(parsed);
		previewShader();
	}

	function shaderStrength():Float
	{
		var strength:Float = Std.parseFloat(shaderStrengthInput.text);
		if(Math.isNaN(strength)) strength = 0;
		return Math.max(0, Math.min(1, strength));
	}

	function previewShader()
	{
		if(!shaderPopup.visible) return;
		var parsed:Null<FlxColor> = parseHex(shaderColorInput.text);
		if(parsed == null) return;
		for (strum in strums) strum.setTint(parsed, shaderStrength());
	}

	function applyShader()
	{
		var parsed:Null<FlxColor> = parseHex(shaderColorInput.text);
		if(parsed == null) return;
		var strength:Float = shaderStrength();
		if(Reflect.field(file, 'tint') == null) Reflect.setField(file, 'tint', {});
		var tints:Dynamic = Reflect.field(file, 'tint');
		var sideName:String = (shaderSideDropDown.selectedIndex == 1) ? 'opponent' : 'player';
		if(strength <= 0) Reflect.deleteField(tints, sideName);
		else Reflect.setField(tints, sideName, {color: parsed.toHexString(false, false), strength: strength});
		if(Reflect.fields(tints).length < 1) Reflect.deleteField(file, 'tint');
		unsaved = true;
		shaderSwatch.color = parsed;
		previewShader();
	}

	function nudgeStrength(amount:Float)
	{
		var value:Float = Math.round((shaderStrength() + amount) * 10) / 10;
		shaderStrengthInput.text = Std.string(Math.max(0, Math.min(1, value)));
		applyShader();
	}

	function removeShader()
	{
		shaderStrengthInput.text = '0';
		applyShader();
		showMessage('Shader Removed');
	}

	function cleanValue(value:Dynamic):Dynamic
	{
		if(value == null) return null;
		if(Std.isOfType(value, Array))
		{
			var list:Array<Dynamic> = cast value;
			return [for (item in list) cleanValue(item)];
		}
		if(Type.typeof(value) == TObject)
		{
			var result:Dynamic = {};
			var any:Bool = false;
			for (field in Reflect.fields(value))
			{
				var cleaned:Dynamic = cleanValue(Reflect.field(value, field));
				if(cleaned == null) continue;
				Reflect.setField(result, field, cleaned);
				any = true;
			}
			return any ? result : null;
		}
		return value;
	}

	function saveFile()
	{
		if(!fileDialog.completed) return;
		var cleaned:Dynamic = cleanValue(file);
		var content:String = Json.stringify((cleaned != null) ? cleaned : {}, '\t');
		var defaultName:String = typeMode ? ((typeName.length > 0) ? typeName : 'noteType') + '.json' : 'notes.json';
		fileDialog.save(defaultName, content, function() {
			unsaved = false;
			if(typeMode)
			{
				typeName = haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(fileDialog.path));
				refreshMode();
			}
			showMessage('Saved: ' + haxe.io.Path.withoutDirectory(fileDialog.path));
		}, null, function() showMessage(typeMode ? 'ERROR: Notetype not saved.' : 'ERROR: Note pack not saved.', true));
	}

	function loadFile()
	{
		if(!fileDialog.completed) return;
		fileDialog.open('notes.json', 'Open Note Pack', null, function() {
			try
			{
				file = NotePackData.parse(fileDialog.data);
				if(typeMode)
				{
					typeName = '';
					setMode(false);
				}
				unsaved = false;
				variant = 0;
				rebuildPreview();
				refreshTab();
				refreshShader();
				if(imagesFound()) showMessage('Opened ' + haxe.io.Path.withoutDirectory(fileDialog.path));
				else showMessage('Image not found!', true);
			}
			catch(e:Dynamic)
			{
				showMessage('File not a valid note pack: $e', true);
			}
		});
	}

	function loadTemplate()
	{
		openSubState(new Prompt('Replace everything with Template?', function() {
			file = NotePackData.defaultFile();
			if(typeMode)
			{
				typeName = '';
				setMode(false);
			}
			variant = 0;
			changed();
			refreshShader();
			showMessage('Template Loaded');
		}, null, 'Replace'));
	}

	function exitEditor()
	{
		if(unsaved) openSubState(new Prompt('There are unsaved changes.\nExit anyway?', leave, null, 'Exit'));
		else leave();
	}

	function leave()
	{
		NotePack.setPreview(null);
		PlayState.stageUI = oldStageUI;
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
		EditorHelper.returnToPreviousState();
	}

	function showMessage(text:String, ?error:Bool = false)
	{
		messageText.text = text;
		messageText.y = FlxG.height - messageText.height - 8;
		messageText.color = error ? FlxColor.RED : FlxColor.WHITE;
		messageText.alpha = 1;
		FlxG.sound.play(Paths.sound(error ? 'cancelMenu' : 'scrollMenu'), 0.4);
		FlxTween.cancelTweensOf(messageText);
		FlxTween.tween(messageText, {alpha: 0}, 1, {startDelay: 2});
	}

	override function destroy()
	{
		NotePack.setPreview(null);
		PlayState.stageUI = oldStageUI;
		Conductor.songPosition = 0;
		ClientPrefs.toggleVolumeKeys(true);
		super.destroy();
	}
}

class NoteEditorHelpSubState extends MusicBeatSubstate
{
	public function new()
	{
		super();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.75;
		add(bg);

		var lines:Array<String> = [
			'NOTE EDITOR',
			'',
			'Click on a Note to Select. Splashes play in "Splashes" tab if clicked.',
			'Use your KEYBINDS to Test the Note Animations.',
			'',
			'CONTROLS',
			'',
			'KEYBINDS - Test Notes',
			'Arrows - Change Offsets',
			'Ctrl+Arrows - Change base Offsets',
			'Q/E - Previous/Next Frame',
			'Ctrl+S - Save',
			'ESC to Exit',
			'',
			'Untouched fields keep default values.'
		];
		var text:FlxText = new FlxText(0, 0, FlxG.width - 200, lines.join('\n'), 18);
		text.setFormat(null, 18, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		text.screenCenter();
		add(text);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(controls.BACK || FlxG.keys.justPressed.F1) close();
	}
}
