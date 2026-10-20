package funkin.editors;

import funkin.data.WeekData;

import openfl.utils.Assets;
import openfl.net.FileReference;
import funkin.editors.content.FileDialogHandler.FileReferenceCustom;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import flash.net.FileFilter;
import lime.system.Clipboard;
import haxe.Json;

import funkin.ui.HealthIcon;
import funkin.ui.MenuCharacter;
import funkin.ui.MenuItem;

import funkin.editors.MasterEditorMenu;
import funkin.editors.content.Prompt;
import funkin.editors.content.PsychJsonPrinter;
import funkin.editors.content.FileDialogHandler;
import funkin.editors.NoteEditorState.NoteEditorColorPicker;
import funkin.ui.states.FreeplayState;
import funkin.graphics.shaders.WeekColorShader;

class WeekEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	var txtWeekTitle:FlxText;
	var bgSprite:FlxSprite;
	var lock:FlxSprite;
	var txtTracklist:FlxText;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;
	var weekThing:MenuItem;
	var missingFileText:FlxText;

	public static var unsavedProgress:Bool = false;
	public static var editedCharacters:Map<String, MenuCharacterFile> = [];

	var charFiles:Array<MenuCharacterFile> = [null, null, null];
	var selectedChar:Int = 0;
	var txtOffsets:FlxText;
	var messageText:FlxText;

	var weekFile:WeekFile = null;
	public function new(weekFile:WeekFile = null)
	{
		super();
		this.weekFile = WeekData.createWeekFile();
		if(weekFile != null) this.weekFile = weekFile;
		else
		{
			weekFileName = 'week1';
			weekPath = null;
			editedCharacters.clear();
		}
	}

	override function create() {
		txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, "", 32);
		txtWeekTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;
		
		var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		bgYellow = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, FlxColor.WHITE);
		bgSprite = new FlxSprite(0, 56);
		bgSprite.antialiasing = ClientPrefs.data.antialiasing;

		weekThing = new MenuItem(0, bgSprite.y + 396, weekFileName);
		weekThing.y += weekThing.height + 20;
		weekThing.antialiasing = ClientPrefs.data.antialiasing;
		add(weekThing);

		var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBarThingie);
		
		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();
		
		lock = new FlxSprite();
		lock.frames = ui_tex;
		lock.animation.addByPrefix('lock', 'lock');
		lock.animation.play('lock');
		lock.antialiasing = ClientPrefs.data.antialiasing;
		add(lock);
		
		missingFileText = new FlxText(0, 0, FlxG.width, "");
		missingFileText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingFileText.borderSize = 2;
		missingFileText.visible = false;
		add(missingFileText); 
		
		var charArray:Array<String> = weekFile.weekCharacters;
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charArray[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		add(bgYellow);
		add(bgSprite);
		add(grpWeekCharacters);

		var tracksSprite:FlxSprite = new FlxSprite(FlxG.width * 0.07, bgSprite.y + 435).loadGraphic(Paths.image('Menu_Tracks'));
		tracksSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(tracksSprite);

		txtTracklist = new FlxText(FlxG.width * 0.05, tracksSprite.y + 60, 0, "", 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = Paths.font("vcr.ttf");
		txtTracklist.color = 0xFFe55777;
		add(txtTracklist);
		add(txtWeekTitle);

		txtOffsets = new FlxText(330, 10, 0, "", 32);
		txtOffsets.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT);
		txtOffsets.alpha = 0.7;
		txtOffsets.visible = false;
		add(txtOffsets);

		messageText = new FlxText(10, 0, FlxG.width - 280, "", 16);
		messageText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		messageText.alpha = 0;
		add(messageText);

		addEditorBox();
		reloadAllShit();

		FlxG.mouse.visible = true;
		add(EditorHelper.createEditorMusicCheckBox(160, 8, 120));
		startEditorMusic();

		super.create();
	}

	var UI_box:PsychUIBox;
	function addEditorBox() {
		UI_box = new PsychUIBox(FlxG.width, FlxG.height, 250, 375, ['Other', 'Week', 'Menu Character']);
		UI_box.x -= UI_box.width;
		UI_box.y -= UI_box.height;
		UI_box.scrollFactor.set();
		add(UI_box);
		addOtherUI();
		addWeekUI();
		addCharacterUI();

		UI_box.selectedName = 'Week';
		add(UI_box);

		var freeplayButton:PsychUIButton = new PsychUIButton(0, 650, "Freeplay", function() MusicBeatState.switchState(new WeekEditorFreeplayState(weekFile)));
		freeplayButton.screenCenter(X);
		add(freeplayButton);

		addUpperMenu();
	}

	var bgYellow:FlxSprite;
	var upperBox:PsychUIBox;
	var colorBox:PsychUIBox;
	var colorPicker:NoteEditorColorPicker;
	var colorHexInput:PsychUIInputText;

	function addUpperMenu() {
		upperBox = new PsychUIBox(0, 0, 150, 90, ['File', 'Color']);
		upperBox.scrollFactor.set();
		upperBox.isMinimized = true;
		upperBox.minimizeOnFocusLost = true;
		upperBox.canMove = false;
		upperBox.bg.visible = false;
		add(upperBox);

		var entries:Array<Array<Dynamic>> = [
			['  Save (Ctrl+S)', function() saveWeek(weekFile)],
			['  Save As...', function() saveWeekAs(weekFile)],
			['  Load from JSON', function() loadWeek()],
			['  Load Template', loadTemplate]
		];
		var menu = upperBox.getTab('File').menu;
		var panel:FlxSprite = new FlxSprite().makeGraphic(200, entries.length * 20 + 2, FlxColor.BLACK);
		panel.alpha = 0.8;
		menu.add(panel);
		for (i => entry in entries)
		{
			var button:PsychUIButton = new PsychUIButton(0, i * 20, entry[0], function() {
				upperBox.isMinimized = true;
				entry[1]();
			}, 200);
			button.text.alignment = LEFT;
			menu.add(button);
		}

		colorBox = new PsychUIBox(FlxG.width / 2 - 115, 100, 230, 240, ['Edit Week Color']);
		colorBox.scrollFactor.set();
		colorBox.canMinimize = false;
		colorBox.selectedName = 'Edit Week Color';
		var colorMenu = colorBox.getTab('Edit Week Color').menu;

		colorPicker = new NoteEditorColorPicker(10, 10);
		colorPicker.onChange = function(color:FlxColor) {
			setWeekColor(color);
			colorHexInput.text = color.toHexString(false, false);
		};
		colorHexInput = new PsychUIInputText(10, 182, 80, '', 8);
		var resetButton:PsychUIButton = new PsychUIButton(100, 180, 'Reset', function() {
			Reflect.deleteField(weekFile, 'weekColor');
			unsavedProgress = true;
			refreshWeekColor();
		}, 80);
		var closeButton:PsychUIButton = new PsychUIButton(196, 6, 'X', function() colorBox.visible = colorBox.active = false, 24, 24);

		colorMenu.add(colorPicker);
		colorMenu.add(new FlxText(10, colorHexInput.y - 16, 0, 'Hex color:'));
		colorMenu.add(colorHexInput);
		colorMenu.add(resetButton);
		colorMenu.add(closeButton);
		colorBox.visible = colorBox.active = false;
		add(colorBox);
	}

	function openColorBox() {
		refreshWeekColor();
		colorBox.visible = colorBox.active = true;
	}

	function setWeekColor(color:FlxColor) {
		weekFile.weekColor = [color.red, color.green, color.blue];
		bgYellow.color = color;
		applyWeekShader(color);
		unsavedProgress = true;
	}

	function refreshWeekColor() {
		var color:FlxColor = WeekData.getWeekColor(weekFile.weekColor);
		bgYellow.color = color;
		applyWeekShader(color);
		colorPicker.setColor(color);
		colorHexInput.text = color.toHexString(false, false);
	}

	function applyWeekShader(color:FlxColor) {
		WeekColorShader.apply(bgSprite, weekFile.weekColor, color);
		for (char in grpWeekCharacters.members) WeekColorShader.apply(char, weekFile.weekColor, color);
	}

	function loadTemplate() {
		openSubState(new Prompt('Replace everything with Template?', function() {
			var template:WeekFile = WeekData.createWeekFile();
			template.songs = [["Test", "face", [146, 113, 253]]];
			template.weekCharacters = ['', 'bf', ''];
			template.weekBackground = 'stage';
			template.weekName = 'weekTemp';
			template.storyName = 'Template Week';
			weekFile = template;
			weekFileName = 'week1';
			weekPath = null;
			unsavedProgress = true;
			reloadAllShit();
			showMessage('Template Loaded');
		}, null, 'Replace'));
	}

	public function refreshWeekFileName() {
		weekFileInputText.text = weekFileName;
		reloadWeekThing();
	}

	var songsInputText:PsychUIInputText;
	var backgroundInputText:PsychUIInputText;
	var displayNameInputText:PsychUIInputText;
	var weekNameInputText:PsychUIInputText;
	var weekFileInputText:PsychUIInputText;
	
	var opponentInputText:PsychUIInputText;
	var boyfriendInputText:PsychUIInputText;
	var girlfriendInputText:PsychUIInputText;

	var hideCheckbox:PsychUICheckBox;

	public static var weekFileName:String = 'week1';
	
	function addWeekUI() {
		var tab_group = UI_box.getTab('Week').menu;

		songsInputText = new PsychUIInputText(10, 30, 200, '', 8);

		opponentInputText = new PsychUIInputText(10, songsInputText.y + 40, 70, '', 8);
		boyfriendInputText = new PsychUIInputText(opponentInputText.x + 75, opponentInputText.y, 70, '', 8);
		girlfriendInputText = new PsychUIInputText(boyfriendInputText.x + 75, opponentInputText.y, 70, '', 8);

		backgroundInputText = new PsychUIInputText(10, opponentInputText.y + 40, 120, '', 8);
		displayNameInputText = new PsychUIInputText(10, backgroundInputText.y + 60, 200, '', 8);
		weekNameInputText = new PsychUIInputText(10, displayNameInputText.y + 60, 150, '', 8);
		weekFileInputText = new PsychUIInputText(10, weekNameInputText.y + 40, 100, '', 8);
		reloadWeekThing();

		hideCheckbox = new PsychUICheckBox(10, weekFileInputText.y + 40, "Hide Week from Story Mode?", 100);
		hideCheckbox.onClick = function()
		{
			weekFile.hideStoryMode = hideCheckbox.checked;
			unsavedProgress = true;
		};

		tab_group.add(new FlxText(songsInputText.x, songsInputText.y - 18, 0, 'Songs:'));
		tab_group.add(new FlxText(opponentInputText.x, opponentInputText.y - 18, 0, 'Characters:'));
		tab_group.add(new FlxText(backgroundInputText.x, backgroundInputText.y - 18, 0, 'Background Asset:'));
		tab_group.add(new FlxText(displayNameInputText.x, displayNameInputText.y - 18, 0, 'Display Name:'));
		tab_group.add(new FlxText(weekNameInputText.x, weekNameInputText.y - 18, 0, 'Week Name (for Reset Score Menu):'));
		tab_group.add(new FlxText(weekFileInputText.x, weekFileInputText.y - 18, 0, 'Week File:'));

		tab_group.add(songsInputText);
		tab_group.add(opponentInputText);
		tab_group.add(boyfriendInputText);
		tab_group.add(girlfriendInputText);
		tab_group.add(backgroundInputText);

		tab_group.add(displayNameInputText);
		tab_group.add(weekNameInputText);
		tab_group.add(weekFileInputText);
		tab_group.add(hideCheckbox);
	}

	var weekBeforeInputText:PsychUIInputText;
	var difficultiesInputText:PsychUIInputText;
	var lockedCheckbox:PsychUICheckBox;
	var hiddenUntilUnlockCheckbox:PsychUICheckBox;

	function addOtherUI() {
		var tab_group = UI_box.getTab('Other').menu;

		lockedCheckbox = new PsychUICheckBox(10, 30, "Week starts Locked", 100);
		lockedCheckbox.onClick = function()
		{
			weekFile.startUnlocked = !lockedCheckbox.checked;
			lock.visible = lockedCheckbox.checked;
			hiddenUntilUnlockCheckbox.alpha = 0.4 + 0.6 * (lockedCheckbox.checked ? 1 : 0);
			unsavedProgress = true;
		};

		hiddenUntilUnlockCheckbox = new PsychUICheckBox(10, lockedCheckbox.y + 25, "Hidden until Unlocked", 110);
		hiddenUntilUnlockCheckbox.onClick = function()
		{
			weekFile.hiddenUntilUnlocked = hiddenUntilUnlockCheckbox.checked;
			unsavedProgress = true;
		};
		hiddenUntilUnlockCheckbox.alpha = 0.4;

		weekBeforeInputText = new PsychUIInputText(10, hiddenUntilUnlockCheckbox.y + 55, 100, '', 8);
		difficultiesInputText = new PsychUIInputText(10, weekBeforeInputText.y + 60, 200, '', 8);
		
		tab_group.add(new FlxText(weekBeforeInputText.x, weekBeforeInputText.y - 28, 0, 'Week File name of the Week you have\nto finish for Unlocking:'));
		tab_group.add(new FlxText(difficultiesInputText.x, difficultiesInputText.y - 20, 0, 'Difficulties:'));
		tab_group.add(new FlxText(difficultiesInputText.x, difficultiesInputText.y + 20, 0, 'Default difficulties are "Easy, Normal, Hard"\nwithout quotes.'));
		tab_group.add(weekBeforeInputText);
		tab_group.add(difficultiesInputText);
		tab_group.add(hiddenUntilUnlockCheckbox);
		tab_group.add(lockedCheckbox);
	}

	var charTypeRadio:PsychUIRadioGroup;
	var charImageInputText:PsychUIInputText;
	var charIdleInputText:PsychUIInputText;
	var charConfirmInputText:PsychUIInputText;
	var charScaleStepper:PsychUINumericStepper;
	var charFlipXCheckbox:PsychUICheckBox;
	var charAntialiasingCheckbox:PsychUICheckBox;
	var charNameText:FlxText;

	function addCharacterUI() {
		var tab_group = UI_box.getTab('Menu Character').menu;

		charTypeRadio = new PsychUIRadioGroup(10, 10, ['Opponent', 'Boyfriend', 'Girlfriend'], 25);
		charTypeRadio.checked = selectedChar;
		charTypeRadio.onClick = function() selectCharacter(charTypeRadio.checked);

		charNameText = new FlxText(120, 10, 120, '');

		charImageInputText = new PsychUIInputText(10, 110, 140, '', 8);
		charScaleStepper = new PsychUINumericStepper(165, charImageInputText.y, 0.05, 1, 0.1, 30, 2);
		charIdleInputText = new PsychUIInputText(10, charImageInputText.y + 40, 200, '', 8);
		charConfirmInputText = new PsychUIInputText(10, charIdleInputText.y + 40, 200, '', 8);

		charFlipXCheckbox = new PsychUICheckBox(10, charConfirmInputText.y + 30, "Flip X", 60);
		charFlipXCheckbox.onClick = function() editCharacter(function(file) file.flipX = charFlipXCheckbox.checked);

		charAntialiasingCheckbox = new PsychUICheckBox(110, charFlipXCheckbox.y, "Antialiasing", 80);
		charAntialiasingCheckbox.onClick = function() editCharacter(function(file) file.antialiasing = charAntialiasingCheckbox.checked);

		tab_group.add(new FlxText(10, charImageInputText.y - 18, 0, 'Image:'));
		tab_group.add(new FlxText(charScaleStepper.x, charScaleStepper.y - 18, 0, 'Scale:'));
		tab_group.add(new FlxText(10, charIdleInputText.y - 18, 0, 'Idle anim (XML):'));
		tab_group.add(new FlxText(10, charConfirmInputText.y - 18, 0, 'HEY animation (XML):'));
		tab_group.add(new FlxText(10, charFlipXCheckbox.y + 35, 230, 'CONTROLS\n\nArrow Keys - Change Offset (Shift for x10)\nSpace - Preview "HEY" Animation\nClick on chars to select them.'));
		tab_group.add(charTypeRadio);
		tab_group.add(charNameText);
		tab_group.add(charImageInputText);
		tab_group.add(charScaleStepper);
		tab_group.add(charIdleInputText);
		tab_group.add(charConfirmInputText);
		tab_group.add(charFlipXCheckbox);
		tab_group.add(charAntialiasingCheckbox);
	}

	function reloadCharacters() {
		for (i in 0...grpWeekCharacters.length) {
			var name:String = weekFile.weekCharacters[i];
			var file:MenuCharacterFile = null;
			if(name != null && name.length > 0)
				file = editedCharacters.exists(name) ? editedCharacters.get(name) : MenuCharacter.parseFile(MenuCharacter.filePath(name));
			charFiles[i] = file;

			var char:MenuCharacter = grpWeekCharacters.members[i];
			char.character = null;
			char.changeCharacter(name);
			if(file != null) char.applyFile(file);
		}
		fillCharacterFields();
	}

	function selectCharacter(id:Int) {
		selectedChar = id;
		charTypeRadio.checked = id;
		fillCharacterFields();
	}

	function fillCharacterFields() {
		var name:String = weekFile.weekCharacters[selectedChar];
		var file:MenuCharacterFile = charFiles[selectedChar];
		if(name == null || name.length < 1) charNameText.text = 'No character';
		else charNameText.text = 'File: ' + name + '.json' + (file == null ? '\n(new file)' : '');

		charImageInputText.text = (file != null && file.image != null) ? file.image : '';
		charIdleInputText.text = (file != null && file.idle_anim != null) ? file.idle_anim : '';
		charConfirmInputText.text = (file != null && file.confirm_anim != null) ? file.confirm_anim : '';
		charScaleStepper.value = (file != null) ? file.scale : 1;
		charFlipXCheckbox.checked = (file != null && file.flipX == true);
		charAntialiasingCheckbox.checked = (file == null || file.antialiasing != false);
		updateOffsetText();
	}

	function editCharacter(change:MenuCharacterFile->Void) {
		var name:String = weekFile.weekCharacters[selectedChar];
		if(name == null || name.length < 1) return;

		var file:MenuCharacterFile = charFiles[selectedChar];
		if(file == null)
		{
			file = {
				image: '',
				scale: 1,
				position: [0, 0],
				idle_anim: '',
				confirm_anim: '',
				flipX: false,
				antialiasing: true
			};
			charFiles[selectedChar] = file;
			charNameText.text = 'File: ' + name + '.json';
		}
		change(file);
		editedCharacters.set(name, file);
		unsavedProgress = true;

		var char:MenuCharacter = grpWeekCharacters.members[selectedChar];
		char.color = FlxColor.WHITE;
		char.applyFile(file);
		updateOffsetText();
	}

	function updateOffsetText() {
		var file:MenuCharacterFile = charFiles[selectedChar];
		txtOffsets.text = (file != null) ? '[' + file.position[0] + ', ' + file.position[1] + ']' : '';
	}

	public function showMessage(text:String, ?error:Bool = false) {
		messageText.text = text;
		messageText.y = FlxG.height - messageText.height - 8;
		messageText.color = error ? FlxColor.RED : FlxColor.WHITE;
		messageText.alpha = 1;
		FlxTween.cancelTweensOf(messageText);
		FlxTween.tween(messageText, {alpha: 0}, 1, {startDelay: 2});
	}

	//Used on onCreate and when you load a week
	function reloadAllShit() {
		var weekString:String = weekFile.songs[0][0];
		for (i in 1...weekFile.songs.length) {
			weekString += ', ' + weekFile.songs[i][0];
		}
		songsInputText.text = weekString;
		backgroundInputText.text = weekFile.weekBackground;
		displayNameInputText.text = weekFile.storyName;
		weekNameInputText.text = weekFile.weekName;
		weekFileInputText.text = weekFileName;
		
		opponentInputText.text = weekFile.weekCharacters[0];
		boyfriendInputText.text = weekFile.weekCharacters[1];
		girlfriendInputText.text = weekFile.weekCharacters[2];

		hideCheckbox.checked = weekFile.hideStoryMode;

		weekBeforeInputText.text = weekFile.weekBefore;

		difficultiesInputText.text = '';
		if(weekFile.difficulties != null) difficultiesInputText.text = weekFile.difficulties;

		lockedCheckbox.checked = !weekFile.startUnlocked;
		lock.visible = lockedCheckbox.checked;
		
		hiddenUntilUnlockCheckbox.checked = weekFile.hiddenUntilUnlocked;
		hiddenUntilUnlockCheckbox.alpha = 0.4 + 0.6 * (lockedCheckbox.checked ? 1 : 0);

		reloadBG();
		reloadWeekThing();
		updateText();
		reloadCharacters();
		refreshWeekColor();
	}

	function updateText()
	{
		var stringThing:Array<String> = [];
		for (i in 0...weekFile.songs.length) {
			stringThing.push(weekFile.songs[i][0]);
		}

		txtTracklist.text = '';
		for (i in 0...stringThing.length)
		{
			txtTracklist.text += stringThing[i] + '\n';
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;
		
		txtWeekTitle.text = weekFile.storyName.toUpperCase();
		txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);
	}

	function reloadBG() {
		bgSprite.visible = true;
		var assetName:String = weekFile.weekBackground;

		var isMissing:Bool = true;
		if(assetName != null && assetName.length > 0) {
			if( #if MODS_ALLOWED FileSystem.exists(Paths.modsImages('menubackgrounds/menu_' + assetName)) || #end
			Assets.exists(Paths.getPath('images/menubackgrounds/menu_' + assetName + '.png', IMAGE), IMAGE)) {
				bgSprite.loadGraphic(Paths.image('menubackgrounds/menu_' + assetName));
				isMissing = false;
			}
		}

		if(isMissing) {
			bgSprite.visible = false;
		}
	}

	function reloadWeekThing() {
		weekThing.visible = true;
		missingFileText.visible = false;
		var assetName:String = weekFileInputText.text.trim();
		
		var isMissing:Bool = true;
		if(assetName != null && assetName.length > 0) {
			if( #if MODS_ALLOWED FileSystem.exists(Paths.modsImages('storymenu/' + assetName)) || #end
			Assets.exists(Paths.getPath('images/storymenu/' + assetName + '.png', IMAGE), IMAGE)) {
				weekThing.loadGraphic(Paths.image('storymenu/' + assetName));
				isMissing = false;
			}
		}

		if(isMissing) {
			weekThing.visible = false;
			missingFileText.visible = true;
			missingFileText.text = 'MISSING FILE: images/storymenu/' + assetName + '.png';
		}
		recalculateStuffPosition();

		#if DISCORD_ALLOWED
		#if MODS_ALLOWED
		DiscordClient.loadModRPC();
		#end
		DiscordClient.changePresence("Week Editor", "Editting: " + weekFileName);
		#end
	}
	
	public function UIEvent(id:String, sender:Dynamic) {
		if(id == PsychUICheckBox.CLICK_EVENT)
			unsavedProgress = true;

		if(id == PsychUIBox.CLICK_EVENT && sender == upperBox && upperBox.selectedName == 'Color')
		{
			upperBox.isMinimized = true;
			openColorBox();
			return;
		}

		if(id == PsychUIInputText.CHANGE_EVENT && sender == colorHexInput)
		{
			var hex:String = colorHexInput.text.trim().replace('#', '');
			var color:Null<FlxColor> = (hex.length == 6) ? FlxColor.fromString('#' + hex) : null;
			if(color != null)
			{
				setWeekColor(color);
				colorPicker.setColor(color);
			}
			return;
		}

		if(id == PsychUIInputText.CHANGE_EVENT && (sender is PsychUIInputText)) {
			if(sender == weekFileInputText) {
				weekFileName = weekFileInputText.text.trim();
				unsavedProgress = true;
				reloadWeekThing();
			} else if(sender == opponentInputText || sender == boyfriendInputText || sender == girlfriendInputText) {
				weekFile.weekCharacters[0] = opponentInputText.text.trim();
				weekFile.weekCharacters[1] = boyfriendInputText.text.trim();
				weekFile.weekCharacters[2] = girlfriendInputText.text.trim();
				unsavedProgress = true;
				reloadCharacters();
			} else if(sender == backgroundInputText) {
				weekFile.weekBackground = backgroundInputText.text.trim();
				unsavedProgress = true;
				reloadBG();
			} else if(sender == displayNameInputText) {
				weekFile.storyName = displayNameInputText.text.trim();
				unsavedProgress = true;
				updateText();
			} else if(sender == weekNameInputText) {
				weekFile.weekName = weekNameInputText.text.trim();
				unsavedProgress = true;
			} else if(sender == songsInputText) {
				var splittedText:Array<String> = songsInputText.text.trim().split(',');
				for (i in 0...splittedText.length) {
					splittedText[i] = splittedText[i].trim();
				}

				while(splittedText.length < weekFile.songs.length) {
					weekFile.songs.pop();
				}

				for (i in 0...splittedText.length) {
					if(i >= weekFile.songs.length) { //Add new song
						weekFile.songs.push([splittedText[i], 'face', [146, 113, 253]]);
					} else { //Edit song
						weekFile.songs[i][0] = splittedText[i];
						if(weekFile.songs[i][1] == null || weekFile.songs[i][1]) {
							weekFile.songs[i][1] = 'face';
							weekFile.songs[i][2] = [146, 113, 253];
						}
					}
				}
				updateText();
				unsavedProgress = true;
			} else if(sender == weekBeforeInputText) {
				weekFile.weekBefore = weekBeforeInputText.text.trim();
				unsavedProgress = true;
			} else if(sender == difficultiesInputText) {
				weekFile.difficulties = difficultiesInputText.text.trim();
				unsavedProgress = true;
			} else if(sender == charImageInputText) {
				editCharacter(function(file) file.image = charImageInputText.text.trim());
			} else if(sender == charIdleInputText) {
				editCharacter(function(file) file.idle_anim = charIdleInputText.text);
			} else if(sender == charConfirmInputText) {
				editCharacter(function(file) file.confirm_anim = charConfirmInputText.text);
			}
		}
		else if(id == PsychUINumericStepper.CHANGE_EVENT && sender == charScaleStepper) {
			editCharacter(function(file) file.scale = charScaleStepper.value);
		}
	}
	
	public static var musicRunning:Bool = false;
	public static function startEditorMusic() {
		if(!musicRunning)
		{
			if(FlxG.sound.music != null && FlxG.sound.music.playing) FlxG.sound.music.fadeOut(0.6, 0);
			EditorHelper.scheduleEditorMusic(10);
			musicRunning = true;
		}
		else if(FlxG.sound.music == null || !FlxG.sound.music.playing || FlxG.sound.music.volume < 0.05)
			EditorHelper.scheduleEditorMusic(1);
	}

	public static function leaveEditor() {
		musicRunning = false;
		editedCharacters.clear();
		@:privateAccess EditorHelper.cancelEditorMusicTimer();
	}

	public static function playClickSounds() {
		if(FlxG.mouse.justPressed || FlxG.mouse.justPressedRight)
			FlxG.sound.play(Paths.sound('chartingSounds/ClickDown'), 0.75);
		if(FlxG.mouse.justReleased || FlxG.mouse.justReleasedRight)
			FlxG.sound.play(Paths.sound('chartingSounds/ClickUp'), 0.75);
	}

	override function update(elapsed:Float)
	{
		playClickSounds();
		if(loadedWeek != null) {
			weekFile = loadedWeek;
			loadedWeek = null;

			reloadAllShit();
		}

		if(PsychUIInputText.focusOn == null)
		{
			ClientPrefs.toggleVolumeKeys(true);
			if(FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveWeek(weekFile);
			else if(FlxG.keys.justPressed.ESCAPE)
			{
				if(!unsavedProgress)
				{
					leaveEditor();
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					funkin.editors.EditorHelper.returnToPreviousState();
				}
				else openSubState(new ExitConfirmationPrompt(function() {
					unsavedProgress = false;
					leaveEditor();
				}));
			}
			else if(UI_box.selectedName == 'Menu Character') updateCharacterKeys();
		}
		else ClientPrefs.toggleVolumeKeys(false);

		var editing:Bool = (UI_box.selectedName == 'Menu Character');
		txtOffsets.visible = editing;
		for (i in 0...grpWeekCharacters.length)
		{
			var char:MenuCharacter = grpWeekCharacters.members[i];
			var baseAlpha:Float = (charFiles[i] != null) ? 1 : 0.6;
			char.alpha = (!editing || i == selectedChar) ? baseAlpha : baseAlpha * 0.35;
			if(char.animation.curAnim != null && char.animation.curAnim.name == 'confirm' && char.animation.curAnim.finished)
				char.animation.play('idle', true);
		}

		super.update(elapsed);

		lock.y = weekThing.y;
		missingFileText.y = weekThing.y + 36;
	}

	function updateCharacterKeys() {
		if(FlxG.mouse.justPressed && !FlxG.mouse.overlaps(UI_box))
		{
			for (i in 0...grpWeekCharacters.length)
			{
				var char:MenuCharacter = grpWeekCharacters.members[i];
				if(char.visible && FlxG.mouse.overlaps(char))
				{
					selectCharacter(i);
					break;
				}
			}
		}

		var shiftMult:Int = FlxG.keys.pressed.SHIFT ? 10 : 1;
		var moveX:Int = 0;
		var moveY:Int = 0;
		if(FlxG.keys.justPressed.LEFT) moveX += shiftMult;
		if(FlxG.keys.justPressed.RIGHT) moveX -= shiftMult;
		if(FlxG.keys.justPressed.UP) moveY += shiftMult;
		if(FlxG.keys.justPressed.DOWN) moveY -= shiftMult;
		if(moveX != 0 || moveY != 0)
			editCharacter(function(file) {
				file.position[0] += moveX;
				file.position[1] += moveY;
			});

		var char:MenuCharacter = grpWeekCharacters.members[selectedChar];
		if(FlxG.keys.justPressed.SPACE && char.hasConfirmAnimation)
			char.animation.play('confirm', true);
	}

	function recalculateStuffPosition() {
		weekThing.screenCenter(X);
		lock.x = weekThing.width + 10 + weekThing.x;
	}

	private static var _file:FileReference;
	public static function loadWeek() {
		var jsonFilter:FileFilter = new FileFilter('JSON', 'json');
		_file = new FileReferenceCustom();
		_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file.browse([#if !mac jsonFilter #end]);
	}
	
	public static var loadedWeek:WeekFile = null;
	public static var loadError:Bool = false;
	private static function onLoadComplete(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		#if sys
		var fullPath:String = null;
		@:privateAccess
		if(_file.__path != null) fullPath = _file.__path;

		if(fullPath != null) {
			var rawJson:String = File.getContent(fullPath);
			if(rawJson != null) {
				loadedWeek = cast Json.parse(rawJson);
				if(loadedWeek.weekCharacters != null && loadedWeek.weekName != null) //Make sure it's really a week
				{
					var cutName:String = _file.name.substr(0, _file.name.length - 5);
					trace("Successfully loaded file: " + cutName);
					loadError = false;

					weekFileName = cutName;
					weekPath = fullPath;
					_file = null;
					unsavedProgress = false;
					return;
				}
			}
		}
		loadError = true;
		loadedWeek = null;
		_file = null;
		#else
		trace("File couldn't be loaded! You aren't on Desktop, are you?");
		#end
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
		private static function onLoadCancel(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		trace("Cancelled file loading.");
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	private static function onLoadError(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		trace("Problem loading file");
	}

	public static var weekPath:String = null;

	public static function saveWeek(weekFile:WeekFile) {
		#if sys
		if(weekPath != null)
		{
			var path:String = haxe.io.Path.join([haxe.io.Path.directory(weekPath), weekFileName + '.json']);
			try
			{
				File.saveContent(path, haxe.Json.stringify(weekFile, "\t"));
			}
			catch(e:Dynamic)
			{
				if(FlxG.state is WeekEditorState) (cast FlxG.state:WeekEditorState).showMessage('ERROR: Week not saved.', true);
				return;
			}
			finishSave(path);
			return;
		}
		#end
		saveWeekAs(weekFile);
	}

	public static function saveWeekAs(weekFile:WeekFile) {
		var data:String = haxe.Json.stringify(weekFile, "\t");
		if (data.length > 0)
		{
			_file = new FileReferenceCustom();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, weekFileName + ".json");
		}
	}
	
	private static function onSaveComplete(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		var savedPath:String = @:privateAccess (cast _file:FileReferenceCustom)._trackSavedPath;
		_file = null;
		FlxG.log.notice("Successfully saved file.");
		finishSave(savedPath);
	}

	static function finishSave(savedPath:String):Void
	{
		if(savedPath != null && savedPath.length > 0)
		{
			weekPath = savedPath;
			weekFileName = haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(savedPath));
			if(FlxG.state is WeekEditorState) (cast FlxG.state:WeekEditorState).refreshWeekFileName();
		}

		var message:String = 'Saved: ' + weekFileName + '.json';
		var error:Bool = false;
		var count:Int = Lambda.count(editedCharacters);
		if(count > 0)
		{
			var saved:Int = saveCharacters(savedPath);
			if(saved == count) message += ' + ' + saved + ' menu character' + (saved == 1 ? '' : 's');
			else
			{
				message = 'ERROR: ' + (count - saved) + ' Menu Characters not saved!';
				error = true;
			}
		}
		unsavedProgress = error;

		if(FlxG.state is WeekEditorState) (cast FlxG.state:WeekEditorState).showMessage(message, error);
	}

	static function saveCharacters(weekPath:String):Int
	{
		#if sys
		if(weekPath == null || weekPath.length < 1) return 0;
		var folder:String = haxe.io.Path.directory(weekPath);
		if(haxe.io.Path.withoutDirectory(folder).toLowerCase() == 'weeks')
			folder = haxe.io.Path.join([haxe.io.Path.directory(folder), 'images', 'menucharacters']);

		var saved:Int = 0;
		for (name in [for (key in editedCharacters.keys()) key])
		{
			try
			{
				if(!FileSystem.exists(folder)) FileSystem.createDirectory(folder);
				File.saveContent(haxe.io.Path.join([folder, name + '.json']), PsychJsonPrinter.print(editedCharacters.get(name), ['position']));
				editedCharacters.remove(name);
				saved++;
			}
			catch(e:Dynamic) trace('Couldn\'t save menu character "$name": $e');
		}
		return saved;
		#else
		return 0;
		#end
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
		private static function onSaveCancel(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		trace("Cancelled file saving.");
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	private static function onSaveError(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving file");
		if(FlxG.state is WeekEditorState) (cast FlxG.state:WeekEditorState).showMessage('ERROR: Week not saved.', true);
	}
}

class WeekEditorFreeplayState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	var weekFile:WeekFile = null;
	public function new(weekFile:WeekFile = null)
	{
		super();
		this.weekFile = WeekData.createWeekFile();
		if(weekFile != null) this.weekFile = weekFile;
	}

	var bg:FlxSprite;
	var bgImage:FlxSprite;
	var fileDialog:FileDialogHandler = new FileDialogHandler();
	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<HealthIcon> = [];

	var curSelected = 0;

	override function create() {
		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = FlxColor.WHITE;
		add(bg);

		bgImage = new FlxSprite();
		bgImage.antialiasing = ClientPrefs.data.antialiasing;
		bgImage.visible = false;
		add(bgImage);
		add(fileDialog);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...weekFile.songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, weekFile.songs[i][0], true);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);
			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			var icon:HealthIcon = new HealthIcon(weekFile.songs[i][1]);
			icon.sprTracker = songText;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}

		addEditorBox();
		changeSelection();
		add(EditorHelper.createEditorMusicCheckBox(20, 685, 120));
		WeekEditorState.startEditorMusic();
		super.create();
	}
	
	var UI_box:PsychUIBox;
	function addEditorBox() {
		var tabs = [
			{name: 'Freeplay', label: 'Freeplay'},
		];
		UI_box = new PsychUIBox(FlxG.width, FlxG.height, 250, 200, ['Freeplay']);
		UI_box.x -= UI_box.width + 100;
		UI_box.y -= UI_box.height + 60;
		UI_box.scrollFactor.set();
		addFreeplayUI();
		add(UI_box);

		bgBox = new PsychUIBox(FlxG.width - 270, 20, 250, 290, ['Background']);
		bgBox.scrollFactor.set();
		addBackgroundUI();
		add(bgBox);

		var blackBlack:FlxSprite = new FlxSprite(0, 670).makeGraphic(FlxG.width, 50, FlxColor.BLACK);
		blackBlack.alpha = 0.6;
		add(blackBlack);

		var loadWeekButton:PsychUIButton = new PsychUIButton(0, 685, "Load Week", function() {
			WeekEditorState.loadWeek();
		});
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 120;
		add(loadWeekButton);
		
		var storyModeButton:PsychUIButton = new PsychUIButton(0, 685, "Story Mode", function() {
			MusicBeatState.switchState(new WeekEditorState(weekFile));
			
		});
		storyModeButton.screenCenter(X);
		add(storyModeButton);
	
		var saveWeekButton:PsychUIButton = new PsychUIButton(0, 685, "Save", function() {
			WeekEditorState.saveWeek(weekFile);
		});
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 120;
		add(saveWeekButton);
	}
	
	public function UIEvent(id:String, sender:Dynamic)
	{
		if(id == PsychUICheckBox.CLICK_EVENT)
			WeekEditorState.unsavedProgress = true;

		if(id == PsychUIInputText.CHANGE_EVENT && sender == iconInputText)
		{
			weekFile.songs[curSelected][1] = iconInputText.text;
			iconArray[curSelected].changeIcon(iconInputText.text);
		}
		else if(id == PsychUIInputText.CHANGE_EVENT && sender == bgImageInputText)
			setBGImage(bgImageInputText.text.trim(), bgTintCheckbox.checked);
		else if(id == PsychUINumericStepper.CHANGE_EVENT && (sender is PsychUINumericStepper))
		{
			if(sender == bgColorStepperR || sender == bgColorStepperG || sender == bgColorStepperB)
			{
				updateBG();
				bgPicker.setColor(bg.color);
			}
		}
	}

	var bgColorStepperR:PsychUINumericStepper;
	var bgColorStepperG:PsychUINumericStepper;
	var bgColorStepperB:PsychUINumericStepper;
	var iconInputText:PsychUIInputText;
	function addFreeplayUI() {
		var tab_group = UI_box.getTab('Freeplay').menu;

		bgColorStepperR = new PsychUINumericStepper(10, 40, 20, 255, 0, 255, 0);
		bgColorStepperG = new PsychUINumericStepper(80, 40, 20, 255, 0, 255, 0);
		bgColorStepperB = new PsychUINumericStepper(150, 40, 20, 255, 0, 255, 0);

		var copyColor:PsychUIButton = new PsychUIButton(10, bgColorStepperR.y + 25, "Copy Color", function() Clipboard.text = bg.color.red + ',' + bg.color.green + ',' + bg.color.blue);

		var pasteColor:PsychUIButton = new PsychUIButton(140, copyColor.y, "Paste Color", function()
		{
			if(Clipboard.text != null)
			{
				var leColor:Array<Int> = [];
				var splitted:Array<String> = Clipboard.text.trim().split(',');
				for (i in 0...splitted.length)
				{
					var toPush:Int = Std.parseInt(splitted[i]);
					if(!Math.isNaN(toPush))
					{
						if(toPush > 255) toPush = 255;
						else if(toPush < 0) toPush *= -1;
						leColor.push(toPush);
					}
				}

				if(leColor.length > 2)
				{
					bgColorStepperR.value = leColor[0];
					bgColorStepperG.value = leColor[1];
					bgColorStepperB.value = leColor[2];
					updateBG();
					bgPicker.setColor(bg.color);
				}
			}
		});

		iconInputText = new PsychUIInputText(10, bgColorStepperR.y + 70, 100, '', 8);

		var hideFreeplayCheckbox:PsychUICheckBox = new PsychUICheckBox(10, iconInputText.y + 30, "Hide Week from Freeplay?", 100);
		hideFreeplayCheckbox.checked = weekFile.hideFreeplay;
		hideFreeplayCheckbox.onClick = function()
		{
			weekFile.hideFreeplay = hideFreeplayCheckbox.checked;
			WeekEditorState.unsavedProgress = true;
		};
		
		tab_group.add(new FlxText(10, bgColorStepperR.y - 18, 0, 'Selected background Color R/G/B:'));
		tab_group.add(new FlxText(10, iconInputText.y - 18, 0, 'Selected icon:'));
		tab_group.add(bgColorStepperR);
		tab_group.add(bgColorStepperG);
		tab_group.add(bgColorStepperB);
		tab_group.add(copyColor);
		tab_group.add(pasteColor);
		tab_group.add(iconInputText);
		tab_group.add(hideFreeplayCheckbox);
	}

	var bgBox:PsychUIBox;
	var bgPicker:NoteEditorColorPicker;
	var bgImageInputText:PsychUIInputText;
	var bgTintCheckbox:PsychUICheckBox;
	var bgImageStatus:FlxText;
	function addBackgroundUI() {
		var tab_group = bgBox.getTab('Background').menu;

		bgPicker = new NoteEditorColorPicker(10, 10);
		bgPicker.onChange = function(color:FlxColor) {
			bgColorStepperR.value = color.red;
			bgColorStepperG.value = color.green;
			bgColorStepperB.value = color.blue;
			updateBG();
			WeekEditorState.unsavedProgress = true;
		};

		bgImageInputText = new PsychUIInputText(10, 190, 230, '', 8);
		var browseButton:PsychUIButton = new PsychUIButton(10, bgImageInputText.y + 22, 'Browse...', browseBGImage, 110);
		var removeButton:PsychUIButton = new PsychUIButton(130, browseButton.y, 'Remove', function() {
			bgImageInputText.text = '';
			setBGImage('', false);
		}, 110);

		bgTintCheckbox = new PsychUICheckBox(10, browseButton.y + 28, 'Use BG Color', 150);
		bgTintCheckbox.onClick = function() setBGImage(bgImageInputText.text.trim(), bgTintCheckbox.checked);

		bgImageStatus = new FlxText(10, bgTintCheckbox.y + 24, 230, '');
		bgImageStatus.color = FlxColor.RED;

		tab_group.add(new FlxText(10, bgImageInputText.y - 16, 0, 'Image (in images/, OPTIONAL):'));
		tab_group.add(bgPicker);
		tab_group.add(bgImageInputText);
		tab_group.add(browseButton);
		tab_group.add(removeButton);
		tab_group.add(bgTintCheckbox);
		tab_group.add(bgImageStatus);
	}

	function browseBGImage() {
		if(!fileDialog.completed) return;
		fileDialog.open(null, 'Open BG Image', [new FileFilter('PNG', 'png')], function() {
			var fullPath:String = fileDialog.path.replace('\\', '/');
			var exePath:String = Sys.getCwd().replace('\\', '/');
			var key:String = null;
			if(fullPath.toLowerCase().startsWith(exePath.toLowerCase()))
			{
				fullPath = fullPath.substr(exePath.length);
				if((fullPath.startsWith('assets/') #if MODS_ALLOWED || fullPath.startsWith('mods/') #end) && fullPath.contains('/images/'))
					key = fullPath.substring(fullPath.indexOf('/images/') + '/images/'.length, fullPath.lastIndexOf('.'));
			}

			if(key == null)
			{
				bgImageStatus.text = 'Image must be in images folder (same for mods)';
				return;
			}
			bgImageInputText.text = key;
			setBGImage(key, bgTintCheckbox.checked);
		});
	}

	function setBGImage(key:String, tint:Bool) {
		var song:Array<Dynamic> = weekFile.songs[curSelected];
		while(song.length > 3) song.pop();
		if(key != null && key.length > 0)
		{
			song.push(key);
			if(tint) song.push(true);
		}
		WeekEditorState.unsavedProgress = true;
		refreshBGImage();
	}

	function refreshBGImage() {
		var song:Array<Dynamic> = weekFile.songs[curSelected];
		var key:String = (song.length > 3) ? song[3] : null;
		var hasKey:Bool = (key != null && key.length > 0);
		bgTintCheckbox.checked = (hasKey && song.length > 4 && song[4] == true);
		bgTintCheckbox.alpha = hasKey ? 1 : 0.4;
		bgImageStatus.text = '';
		bgImage.visible = false;
		if(!hasKey) return;

		if(!Paths.fileExists('images/$key.png', IMAGE))
		{
			bgImageStatus.text = 'Image not found: images/$key.png';
			return;
		}
		FreeplayState.fitBackground(bgImage.loadGraphic(Paths.image(key)));
		bgImage.visible = true;
		bgImage.color = bgTintCheckbox.checked ? bg.color : FlxColor.WHITE;
	}

	function updateBG() {
		weekFile.songs[curSelected][2][0] = Math.round(bgColorStepperR.value);
		weekFile.songs[curSelected][2][1] = Math.round(bgColorStepperG.value);
		weekFile.songs[curSelected][2][2] = Math.round(bgColorStepperB.value);
		bg.color = FlxColor.fromRGB(weekFile.songs[curSelected][2][0], weekFile.songs[curSelected][2][1], weekFile.songs[curSelected][2][2]);
		if(bgImage.visible && bgTintCheckbox.checked) bgImage.color = bg.color;
	}

	function changeSelection(change:Int = 0) {
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected = FlxMath.wrap(curSelected + change, 0, weekFile.songs.length - 1);
		for (num => item in grpSongs.members)
		{
			var icon:HealthIcon = iconArray[num];
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			icon.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
				icon.alpha = 1;
			}
		}
		//trace(weekFile.songs[curSelected]);
		iconInputText.text = weekFile.songs[curSelected][1];

		var colors = weekFile.songs[curSelected][2];
		bgColorStepperR.value = Math.round(colors[0]);
		bgColorStepperG.value = Math.round(colors[1]);
		bgColorStepperB.value = Math.round(colors[2]);
		updateBG();
		bgPicker.setColor(bg.color);

		var song:Array<Dynamic> = weekFile.songs[curSelected];
		bgImageInputText.text = (song.length > 3 && song[3] != null) ? song[3] : '';
		refreshBGImage();
	}

	override function update(elapsed:Float) {
		WeekEditorState.playClickSounds();
		if(WeekEditorState.loadedWeek != null) {
			super.update(elapsed);
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new WeekEditorFreeplayState(WeekEditorState.loadedWeek));
			WeekEditorState.loadedWeek = null;
			return;
		}
		
		if(PsychUIInputText.focusOn != null)
			ClientPrefs.toggleVolumeKeys(false);
		else
		{
			ClientPrefs.toggleVolumeKeys(true);
			if(FlxG.keys.justPressed.ESCAPE) {
				if(!WeekEditorState.unsavedProgress)
				{
					WeekEditorState.leaveEditor();
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					funkin.editors.EditorHelper.returnToPreviousState();
				}
				else openSubState(new ExitConfirmationPrompt(function() {
					WeekEditorState.unsavedProgress = false;
					WeekEditorState.leaveEditor();
				}));
			}

			if(FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) WeekEditorState.saveWeek(weekFile);
			if(controls.UI_UP_P && fileDialog.completed) changeSelection(-1);
			if(controls.UI_DOWN_P && fileDialog.completed) changeSelection(1);
		}
		super.update(elapsed);
	}
}
