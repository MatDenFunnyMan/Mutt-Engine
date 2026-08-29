package funkin.editors;

import flixel.graphics.FlxGraphic;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.math.FlxRect;

import flixel.system.debug.interaction.tools.Pointer.GraphicCursorCross;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSpriteUtil;

import openfl.events.Event;
import openfl.utils.Assets;

import funkin.game.Character;
import funkin.ui.HealthIcon;
import funkin.ui.Bar;

import funkin.editors.content.Prompt;
import funkin.editors.content.PsychJsonPrinter;
import funkin.editors.content.FileDialogHandler;
import funkin.editors.content.Prompt.BasePrompt;

class CharacterEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	var character:Character;
	var cameraFollowPointer:FlxSprite;
	var isAnimateSprite:Bool = false;

	var silhouettes:FlxSpriteGroup;
	var dadPosition = FlxPoint.weak();
	var bfPosition = FlxPoint.weak();

	var helpBg:FlxSprite;
	var helpTexts:FlxSpriteGroup;
	var cameraZoomText:FlxText;
	var frameAdvanceText:FlxText;
	var outputTxt:FlxText;
	var outputTime:Float = 0;
	var fileDialog:FileDialogHandler = new FileDialogHandler();
	var upperBox:PsychUIBox;
	var viewMode:String = 'animations';
	var sheetBackdrop:FlxBackdrop;
	var sheetSprite:FlxSprite;
	var sheetFrames:FlxSpriteGroup;
	var sheetCursor:Array<FlxSprite> = [];
	var stageSprites:Array<FlxSprite> = [];
	var _animCamZoom:Float = 1;
	var _animCamScroll:FlxPoint = FlxPoint.get();
	var _sheetCamZoom:Float = 1;
	var _sheetCamScroll:FlxPoint = FlxPoint.get();

	var healthBar:Bar;
	var healthIcon:HealthIcon;

	var copiedOffset:Array<Float> = [0, 0];
	var _char:String = null;
	var _goToPlayState:Bool = true;

	var anims:Array<AnimArray> = null;
	var animScrollList:AnimScrollList;
	var curAnim = 0;

	private var camEditor:FlxCamera;
	private var camHUD:FlxCamera;

	var UI_box:PsychUIBox;
	var UI_characterbox:PsychUIBox;

	var unsavedProgress:Bool = false;

	var holdingObjectType:Int = -1;
	var showCharHitbox:Bool = false;
	var showCharCamera:Bool = true;
	var showCharAxis:Bool = false;

	var hitboxLines:Array<FlxSprite> = [];
	var axisLines:Array<FlxSprite> = [];
	var _debugRect:FlxRect = FlxRect.get();

	var _pressedOverUI:Bool = false;
	public var skipMouseDelta:Bool = false;

	public function new(char:String = null, goToPlayState:Bool = false)
	{
		this._char = char;
		this._goToPlayState = goToPlayState;
		if(this._char == null) this._char = Character.DEFAULT_CHARACTER;

		super();
	}

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		FlxG.sound.music.stop();
		camEditor = initPsychCamera();

		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		loadBG();
		makeSpritesheetView();

		silhouettes = new FlxSpriteGroup();
		add(silhouettes);

		var dad:FlxSprite = new FlxSprite(dadPosition.x, dadPosition.y).loadGraphic(Paths.image('editors/silhouetteDad'));
		dad.antialiasing = ClientPrefs.data.antialiasing;
		dad.active = false;
		dad.offset.set(-4, 1);
		silhouettes.add(dad);

		var boyfriend:FlxSprite = new FlxSprite(bfPosition.x, bfPosition.y + 350).loadGraphic(Paths.image('editors/silhouetteBF'));
		boyfriend.antialiasing = ClientPrefs.data.antialiasing;
		boyfriend.active = false;
		boyfriend.offset.set(-6, 2);
		silhouettes.add(boyfriend);

		silhouettes.alpha = 0.25;

		animScrollList = new AnimScrollList(10, FlxG.height - 195, 210, 170);
		animScrollList.scrollFactor.set();
		animScrollList.cameras = [camHUD];
		animScrollList.onSelect = function(idx:Int) {
			undoOffsets = null;
			curAnim = idx;
			character.playAnim(anims[curAnim].anim, true);
			updateSheetFrames();
		};

		addCharacter();

		cameraFollowPointer = new FlxSprite().loadGraphic(FlxGraphic.fromClass(GraphicCursorCross));
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();

		healthBar = new Bar(0, 0);
		healthBar.scrollFactor.set();
		healthBar.cameras = [camHUD];

		healthIcon = new HealthIcon(character.healthIcon, false, false);
		healthIcon.cameras = [camHUD];

		add(cameraFollowPointer);
		add(animScrollList);
		makeDebugShapes();

		var tipText:FlxText = new FlxText(FlxG.width - 300, FlxG.height - 24, 300, "Press F1 for Help", 20);
		tipText.cameras = [camHUD];
		tipText.setFormat(null, 16, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		tipText.borderColor = FlxColor.BLACK;
		tipText.scrollFactor.set();
		tipText.borderSize = 1;
		tipText.active = false;
		add(tipText);

		outputTxt = new FlxText(0, 0, 800, '', 24);
		outputTxt.alignment = CENTER;
		outputTxt.borderStyle = OUTLINE_FAST;
		outputTxt.borderSize = 1;
		outputTxt.cameras = [camHUD];
		outputTxt.screenCenter();
		outputTxt.y = FlxG.height - 90;
		outputTxt.alpha = 0;
		add(outputTxt);

		cameraZoomText = new FlxText(0, 50, 200, 'Zoom: 1x');
		cameraZoomText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		cameraZoomText.scrollFactor.set();
		cameraZoomText.borderSize = 1;
		cameraZoomText.screenCenter(X);
		cameraZoomText.cameras = [camHUD];
		add(cameraZoomText);

		frameAdvanceText = new FlxText(0, 75, 350, '');
		frameAdvanceText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		frameAdvanceText.scrollFactor.set();
		frameAdvanceText.borderSize = 1;
		frameAdvanceText.screenCenter(X);
		frameAdvanceText.cameras = [camHUD];
		add(frameAdvanceText);

		addHelpScreen();
		FlxG.mouse.visible = true;
		FlxG.camera.zoom = 1;

		makeUIMenu();

		updatePointerPos();
		updateHealthBar();
		character.finishAnimation();

		if(ClientPrefs.data.cacheOnGPU) Paths.clearUnusedMemory();

		new FlxTimer().start(10, function(_) {
			FlxG.sound.playMusic(Paths.music('chartEditorLoop'), 0);
			FlxG.sound.music.fadeIn(1.5, 0, 0.75);
		});

		super.create();
	}

	function addHelpScreen()
	{
		var str:Array<String> = ["CAMERA",
		"E/Q - Camera Zoom In/Out",
		"J/K/L/I - Move Camera",
		"R - Reset Camera Zoom",
		"",
		"CHARACTER",
		"Ctrl + R - Reset Current Offset",
		"Ctrl + C - Copy Current Offset",
		"Ctrl + V - Paste Copied Offset on Current Animation",
		"Ctrl + Z - Undo Last Paste or Reset",
		"W/S - Previous/Next Animation",
		"Space - Replay Animation",
		"F - Toggle Ghost of Selected Animation",
		"Arrow Keys/Mouse & Right Click - Move Offset",
		"A/D - Frame Advance (Back/Forward)",
		"",
		"OTHER",
		"F12 - Toggle Silhouettes",
		"Left Click (on Ghost List) - Remove Ghost",
		"Hold Shift - Move Offsets 10x faster and Camera 4x faster",
		"Hold Control - Move camera 4x slower"];

		helpBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		helpBg.scale.set(FlxG.width, FlxG.height);
		helpBg.updateHitbox();
		helpBg.alpha = 0.6;
		helpBg.cameras = [camHUD];
		helpBg.active = helpBg.visible = false;
		add(helpBg);

		helpTexts = new FlxSpriteGroup();
		helpTexts.cameras = [camHUD];
		for (i => txt in str)
		{
			if(txt.length < 1) continue;

			var helpText:FlxText = new FlxText(0, 0, 600, txt, 16);
			helpText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
			helpText.borderColor = FlxColor.BLACK;
			helpText.scrollFactor.set();
			helpText.borderSize = 1;
			helpText.screenCenter();
			add(helpText);
			helpText.y += ((i - str.length/2) * 32) + 16;
			helpText.active = false;
			helpTexts.add(helpText);
		}
		helpTexts.active = helpTexts.visible = false;
		add(helpTexts);
	}

	function addCharacter(reload:Bool = false)
	{
		clearGhosts();

		var pos:Int = -1;
		if(character != null)
		{
			pos = members.indexOf(character);
			remove(character);
			character.destroy();
		}

		var isPlayer = (reload ? character.isPlayer : !predictCharacterIsNotPlayer(_char));
		character = new Character(0, 0, _char, isPlayer);
		if(!reload && character.editorIsPlayer != null && isPlayer != character.editorIsPlayer)
		{
			character.isPlayer = !character.isPlayer;
			character.flipX = (character.originalFlipX != character.isPlayer);
			if(check_player != null) check_player.checked = character.isPlayer;
		}
		character.debugMode = true;
		character.missingCharacter = false;

		if(pos > -1) insert(pos, character);
		else add(character);
		updateCharacterPositions();
		reloadAnimList();
		if(healthBar != null && healthIcon != null) updateHealthBar();
		character.visible = (viewMode != 'spritesheet');
		reloadSpritesheet();
	}

	function makeSpritesheetView()
	{
		sheetBackdrop = new FlxBackdrop(FlxGridOverlay.createGrid(50, 50, 100, 100, true, 0xFFAAAAAA, 0xFF666666));
		sheetBackdrop.visible = false;
		sheetBackdrop.active = false;
		add(sheetBackdrop);

		sheetSprite = new FlxSprite();
		sheetSprite.antialiasing = false;
		sheetSprite.active = false;
		sheetSprite.visible = false;
		add(sheetSprite);

		sheetFrames = new FlxSpriteGroup();
		sheetFrames.visible = false;
		add(sheetFrames);

		for (i in 0...4)
		{
			var line:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
			line.color = FlxColor.YELLOW;
			line.active = false;
			line.visible = false;
			sheetCursor.push(line);
			add(line);
		}
	}

	function spritesheetKey():String
	{
		if(character == null || character.imageFile == null || character.imageFile.length < 1) return null;

		var key:String = character.imageFile.split(',')[0].trim();
		if(character.isAnimateAtlas) key = '$key/spritemap1';
		return Paths.fileExists('images/$key.png', IMAGE) ? key : null;
	}

	function reloadSpritesheet()
	{
		if(sheetSprite == null) return;

		var key:String = spritesheetKey();
		if(key == null)
		{
			sheetSprite.visible = false;
			clearSheetFrames();
			if(viewMode == 'spritesheet') showOutput('No spritesheet image found for this character.', true);
			return;
		}

		sheetSprite.loadGraphic(Paths.image(key));
		sheetSprite.setPosition(0, 0);
		sheetSprite.visible = (viewMode == 'spritesheet');
		updateSheetFrames();
	}

	function clearSheetFrames()
	{
		if(sheetFrames == null) return;

		while(sheetFrames.members.length > 0)
		{
			var spr:FlxSprite = sheetFrames.members[0];
			sheetFrames.remove(spr, true);
			if(spr != null) spr.destroy();
		}
	}

	function updateSheetFrames()
	{
		clearSheetFrames();
		if(character == null || character.isAnimateAtlas || character.frames == null) return;

		var animName:String = (anims != null && anims[curAnim] != null) ? anims[curAnim].anim : null;
		if(animName == null) return;

		var anim = character.animation.getByName(animName);
		if(anim == null) return;

		for (index in anim.frames)
		{
			if(index < 0 || index >= character.frames.frames.length) continue;

			var region = character.frames.frames[index].frame;
			if(region == null) continue;

			var box:FlxSprite = new FlxSprite(region.x, region.y).makeGraphic(1, 1, FlxColor.WHITE);
			box.color = 0xFF00FFFF;
			box.alpha = 0.22;
			box.active = false;
			box.scale.set(region.width, region.height);
			box.updateHitbox();
			sheetFrames.add(box);
		}
	}

	function updateSheetCursor()
	{
		var show:Bool = (viewMode == 'spritesheet' && character != null && !character.isAnimateAtlas && character.frame != null);
		for (line in sheetCursor) line.visible = show;
		if(!show) return;

		var region = character.frame.frame;
		if(region == null) return;

		var thick:Float = 1 / camEditor.zoom;
		setDebugLine(sheetCursor[0], region.x, region.y, region.width, thick);
		setDebugLine(sheetCursor[1], region.x, region.y + region.height - thick, region.width, thick);
		setDebugLine(sheetCursor[2], region.x, region.y, thick, region.height);
		setDebugLine(sheetCursor[3], region.x + region.width - thick, region.y, thick, region.height);
	}

	function applyViewMode()
	{
		var sheet:Bool = (viewMode == 'spritesheet');

		for (spr in stageSprites) if(spr != null) spr.visible = !sheet;
		if(silhouettes != null) silhouettes.visible = !sheet;
		if(character != null) character.visible = !sheet;

		for (layer in ghostLayers)
			if(layer.sprite != null) layer.sprite.visible = !sheet;

		if(sheetBackdrop != null) sheetBackdrop.visible = sheet;
		if(sheetFrames != null) sheetFrames.visible = sheet;

		if(sheet) reloadSpritesheet();
		else if(sheetSprite != null) sheetSprite.visible = false;
	}

	function makeDebugShapes()
	{
		for (i in 0...4)
		{
			var line:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
			line.color = 0xFF00FFFF;
			line.active = false;
			line.visible = false;
			hitboxLines.push(line);
			add(line);
		}

		for (i in 0...2)
		{
			var line:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
			line.color = 0xFFFFFF00;
			line.alpha = 0.7;
			line.active = false;
			line.visible = false;
			axisLines.push(line);
			add(line);
		}
	}

	public function showOutput(txt:String, isError:Bool = false)
	{
		outputTxt.color = isError ? FlxColor.RED : FlxColor.WHITE;
		outputTxt.text = txt;
		outputTime = 3;

		if(isError) FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
		else FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function updateDebugShapes()
	{
		updateSheetCursor();
		if(viewMode == 'spritesheet')
		{
			for (line in hitboxLines) line.visible = false;
			for (line in axisLines) line.visible = false;
			if(cameraFollowPointer != null) cameraFollowPointer.visible = false;
			return;
		}

		for (line in hitboxLines) line.visible = showCharHitbox;
		for (line in axisLines) line.visible = showCharAxis;
		if(cameraFollowPointer != null) cameraFollowPointer.visible = showCharCamera;

		if(character == null) return;

		var thick:Float = 1 / camEditor.zoom;

		if(showCharHitbox)
		{
			var spr:FlxSprite = (character.isAnimateAtlas && character.atlas != null) ? character.atlas : character;
			spr.getScreenBounds(_debugRect, camEditor);

			var left:Float = _debugRect.x + camEditor.scroll.x;
			var top:Float = _debugRect.y + camEditor.scroll.y;
			var wid:Float = Math.max(_debugRect.width, thick);
			var hei:Float = Math.max(_debugRect.height, thick);

			setDebugLine(hitboxLines[0], left, top, wid, thick);
			setDebugLine(hitboxLines[1], left, top + hei - thick, wid, thick);
			setDebugLine(hitboxLines[2], left, top, thick, hei);
			setDebugLine(hitboxLines[3], left + wid - thick, top, thick, hei);
		}

		if(showCharAxis)
		{
			var span:Float = 4000;
			setDebugLine(axisLines[0], character.x - span, character.y, span * 2, thick);
			setDebugLine(axisLines[1], character.x, character.y - span, thick, span * 2);
		}
	}

	function setDebugLine(line:FlxSprite, x:Float, y:Float, wid:Float, hei:Float)
	{
		line.setPosition(x, y);
		line.scale.set(wid, hei);
		line.updateHitbox();
	}

	function mouseOverUIBox(box:PsychUIBox):Bool
	{
		if(box == null || box.bg == null || !box.visible) return false;

		return FlxG.mouse.overlaps(box.bg, camHUD);
	}

	function mouseOverUpperMenu():Bool
	{
		if(upperBox == null || upperBox.isMinimized || upperBox.selectedTab == null) return false;

		var menu = upperBox.selectedTab.menu;
		return (menu != null && menu.visible && FlxG.mouse.overlaps(menu, camHUD));
	}

	function mouseOverEditorUI():Bool
	{
		if(upperBox != null && FlxG.mouse.screenY < upperBox.tabHeight + 6 && FlxG.mouse.screenX < 225) return true;

		return colorPickerDragging > 0 || FlxG.mouse.overlaps(animScrollList, camHUD)
			|| mouseOverUIBox(UI_box) || mouseOverUIBox(UI_characterbox) || mouseOverUpperMenu();
	}

	override function onFocus()
	{
		super.onFocus();
		skipMouseDelta = true;
	}

	function reloadCharacterFile()
	{
		addCharacter(true);
		updatePointerPos();
		reloadCharacterOptions();
		reloadCharacterDropDown();
		showOutput('Reloaded character "$_char".');
	}

	function loadTemplateCharacter()
	{
		final _template:CharacterFile =
		{
			animations: [
				newAnim('idle', 'BF idle dance'),
				newAnim('singLEFT', 'BF NOTE LEFT0'),
				newAnim('singDOWN', 'BF NOTE DOWN0'),
				newAnim('singUP', 'BF NOTE UP0'),
				newAnim('singRIGHT', 'BF NOTE RIGHT0')
			],
			no_antialiasing: false,
			flip_x: false,
			healthicon: 'face',
			image: 'characters/BOYFRIEND',
			sing_duration: 4,
			scale: 1,
			healthbar_colors: [161, 161, 161],
			camera_position: [0, 0],
			position: [0, 0],
			vocals_file: null
		};

		character.loadCharacterFile(_template);
		character.missingCharacter = false;
		character.color = FlxColor.WHITE;
		character.alpha = 1;
		reloadAnimList();
		reloadCharacterOptions();
		updateCharacterPositions();
		updatePointerPos();
		reloadCharacterDropDown();
		updateHealthBar();
		showOutput('Loaded blank template.');
	}

	function makeUpperBox()
	{
		upperBox = new PsychUIBox(0, 0, 225, 260, ['File', 'View', 'Icon']);
		upperBox.scrollFactor.set();
		upperBox.isMinimized = true;
		upperBox.minimizeOnFocusLost = true;
		upperBox.canMove = false;
		upperBox.cameras = [camHUD];
		upperBox.bg.visible = false;
		upperBox.bg.alpha = 1;
		add(upperBox);

		upperBox.getTab('File').menuOffsetX = 0;
		upperBox.getTab('View').menuOffsetX = 75;
		upperBox.getTab('Icon').menuOffsetX = 150;

		addUpperFileTab();
		addUpperViewTab();
		addUpperIconTab();
	}

	function addUpperFileTab()
	{
		var tab_group = upperBox.getTab('File').menu;
		var btnY:Int = 0;
		var btnWid:Int = 150;

		var panel:FlxSprite = new FlxSprite().makeGraphic(btnWid, 62, FlxColor.BLACK, true);
		panel.alpha = 0.8;
		tab_group.add(panel);

		var btn:PsychUIButton = new PsychUIButton(0, btnY, '  Save Character', saveCharacter, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(0, btnY, '  Reload Character', reloadCharacterFile, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(0, btnY, '  Load Template', loadTemplateCharacter, btnWid);
		btn.normalStyle.bgColor = FlxColor.RED;
		btn.normalStyle.textColor = FlxColor.WHITE;
		btn.text.alignment = LEFT;
		tab_group.add(btn);
	}

	function addUpperViewTab()
	{
		var tab_group = upperBox.getTab('View').menu;
		var btnY:Int = 0;
		var btnWid:Int = 150;

		var panel:FlxSprite = new FlxSprite().makeGraphic(btnWid, 105, FlxColor.BLACK, true);
		panel.alpha = 0.8;
		tab_group.add(panel);

		var btn:PsychUIButton = new PsychUIButton(0, btnY, '  Switch View...', openViewPrompt, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 30;
		var hitboxCheckBox:PsychUICheckBox = new PsychUICheckBox(5, btnY, 'Character Hitbox', 120);
		hitboxCheckBox.checked = showCharHitbox;
		hitboxCheckBox.onClick = function() showCharHitbox = hitboxCheckBox.checked;
		tab_group.add(hitboxCheckBox);

		btnY += 25;
		var camPointCheckBox:PsychUICheckBox = new PsychUICheckBox(5, btnY, 'Character Camera', 120);
		camPointCheckBox.checked = showCharCamera;
		camPointCheckBox.onClick = function() showCharCamera = camPointCheckBox.checked;
		tab_group.add(camPointCheckBox);

		btnY += 25;
		var axisCheckBox:PsychUICheckBox = new PsychUICheckBox(5, btnY, 'XY Axis', 120);
		axisCheckBox.checked = showCharAxis;
		axisCheckBox.onClick = function() showCharAxis = axisCheckBox.checked;
		tab_group.add(axisCheckBox);
	}

	function addUpperIconTab()
	{
		var tab_group = upperBox.getTab('Icon').menu;
		var btnWid:Int = 150;

		var panel:FlxSprite = new FlxSprite().makeGraphic(btnWid, 22, FlxColor.BLACK, true);
		panel.alpha = 0.8;
		tab_group.add(panel);

		var btn:PsychUIButton = new PsychUIButton(0, 0, '  Properties...', openIconPrompt, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
	}

	function openViewPrompt()
	{
		upperBox.isMinimized = true;
		upperBox.bg.visible = false;

		openSubState(new BasePrompt(460, 200, 'Which view do you want to switch to?',
			function(state:BasePrompt) {
				var btn:PsychUIButton = new PsychUIButton(0, state.bg.y + 110, 'Spritesheet', function() {
					setViewMode('spritesheet');
					state.close();
				}, 150);
				btn.screenCenter(X);
				btn.x -= 85;
				btn.cameras = state.cameras;
				state.add(btn);

				var btn:PsychUIButton = new PsychUIButton(0, state.bg.y + 110, 'Animations', function() {
					setViewMode('animations');
					state.close();
				}, 150);
				btn.screenCenter(X);
				btn.x += 85;
				btn.cameras = state.cameras;
				state.add(btn);
			}));
	}

	function setViewMode(mode:String)
	{
		if(viewMode == mode)
		{
			showOutput('You are already in the $mode view.', true);
			return;
		}

		if(viewMode == 'spritesheet')
		{
			_sheetCamZoom = FlxG.camera.zoom;
			_sheetCamScroll.set(FlxG.camera.scroll.x, FlxG.camera.scroll.y);
		}
		else
		{
			_animCamZoom = FlxG.camera.zoom;
			_animCamScroll.set(FlxG.camera.scroll.x, FlxG.camera.scroll.y);
		}

		viewMode = mode;
		applyViewMode();

		if(mode == 'spritesheet')
		{
			FlxG.camera.zoom = _sheetCamZoom;
			FlxG.camera.scroll.set(_sheetCamScroll.x, _sheetCamScroll.y);
		}
		else
		{
			FlxG.camera.zoom = _animCamZoom;
			FlxG.camera.scroll.set(_animCamScroll.x, _animCamScroll.y);
		}
		cameraZoomText.text = 'Zoom: ' + FlxMath.roundDecimal(FlxG.camera.zoom, 2) + 'x';

		showOutput('Switched to the $mode view.');
	}

	function makeUIMenu()
	{
		UI_characterbox = new PsychUIBox(FlxG.width - 335, 10, 330, 320, ['Animations', 'Character']);
		UI_characterbox.scrollFactor.set();
		UI_characterbox.cameras = [camHUD];

		UI_box = new PsychUIBox(FlxG.width - 255, UI_characterbox.y + UI_characterbox.height + 5, 250, 270, ['Ghost']);
		UI_box.scrollFactor.set();
		UI_box.cameras = [camHUD];
		add(UI_box);
		add(UI_characterbox);

		addGhostUI();
		addAnimationsUI();
		addCharacterUI();

		UI_characterbox.selectedName = 'Character';

		makeUpperBox();
	}

	var ghostAlpha:Float = 0.6;
	var ghostHighlight:Bool = false;
	var ghostLayers:Array<GhostLayer> = [];
	var ghostList:AnimScrollList;

	function addGhostUI()
	{
		var tab_group = UI_box.getTab('Ghost').menu;

		var addGhostButton:PsychUIButton = new PsychUIButton(10, 8, "Add Ghost", addGhostLayer, 110);
		var clearGhostButton:PsychUIButton = new PsychUIButton(128, 8, "Clear All", function()
		{
			if(ghostLayers.length < 1)
			{
				showOutput('There are no ghosts to clear.', true);
				return;
			}
			clearGhosts();
			FlxG.sound.play(Paths.sound('chartingSounds/noteErase'));
		}, 110);

		var highlightGhost:PsychUICheckBox = new PsychUICheckBox(10, 34, "Highlight Ghosts", 130);
		highlightGhost.checked = ghostHighlight;
		highlightGhost.onClick = function()
		{
			ghostHighlight = highlightGhost.checked;
			applyGhostVisuals();
		};

		var ghostAlphaSlider:PsychUISlider = new PsychUISlider(25, 58, function(v:Float)
		{
			ghostAlpha = v;
			applyGhostVisuals();
		}, ghostAlpha, 0, 1, 190);
		ghostAlphaSlider.label = 'Opacity:';

		ghostList = new AnimScrollList(10, 112, 230, 132);
		ghostList.setTitle('Ghost List');
		ghostList.labelOf = function(data:Dynamic) return data.label;
		ghostList.onSelect = function(idx:Int) removeGhostLayer(idx);

		tab_group.add(addGhostButton);
		tab_group.add(clearGhostButton);
		tab_group.add(highlightGhost);
		tab_group.add(ghostAlphaSlider);
		tab_group.add(ghostList);
		refreshGhostList();
	}

	function ghostFor(animName:String):GhostLayer
	{
		for (layer in ghostLayers)
			if(layer.anim == animName) return layer;

		return null;
	}

	function addGhostLayer()
	{
		if(character == null || character.isAnimationNull())
		{
			showOutput('Play an animation before adding a ghost.', true);
			return;
		}

		var myAnim:AnimArray = (anims != null) ? anims[curAnim] : null;
		if(myAnim == null)
		{
			showOutput('This animation cannot be ghosted.', true);
			return;
		}

		var existing:GhostLayer = ghostFor(myAnim.anim);
		var wasUpdated:Bool = (existing != null);
		var layer:GhostLayer = {anim: myAnim.anim, sprite: null, animate: null, label: ''};

		if(!character.isAnimateAtlas)
		{
			var spr:FlxSprite = new FlxSprite();
			spr.loadGraphic(character.graphic);
			spr.frames.frames = character.frames.frames;
			spr.animation.copyFrom(character.animation);
			spr.animation.play(character.animation.curAnim.name, true, false, character.animation.curAnim.curFrame);
			spr.animation.pause();
			spr.active = false;
			layer.sprite = spr;
			layer.label = myAnim.anim + ' (' + character.animation.curAnim.curFrame + ')';
		}
		else
		{
			var atl:FlxAnimate = new FlxAnimate(character.x, character.y);
			atl.showPivot = false;
			atl.active = false;
			try
			{
				Paths.loadAnimateAtlas(atl, character.imageFile);
			}
			catch(e:Dynamic)
			{
				atl.destroy();
				showOutput('Could not load the atlas for this ghost.', true);
				return;
			}

			if(myAnim.indices != null && myAnim.indices.length > 0)
				atl.anim.addBySymbolIndices('anim', myAnim.name, myAnim.indices, 0, false);
			else
				atl.anim.addBySymbol('anim', myAnim.name, 0, false);

			atl.anim.play('anim', true, false, character.atlas.anim.curFrame);
			atl.anim.pause();
			layer.sprite = atl;
			layer.animate = atl;
			layer.label = myAnim.anim + ' (' + character.atlas.anim.curFrame + ')';
		}

		if(wasUpdated)
		{
			destroyGhostLayer(existing);
			ghostLayers.remove(existing);
		}

		var spr:FlxSprite = layer.sprite;
		spr.antialiasing = character.antialiasing;
		spr.flipX = character.flipX;
		spr.scale.set(character.scale.x, character.scale.y);
		spr.updateHitbox();
		spr.offset.set(character.offset.x, character.offset.y);
		spr.origin.set(character.origin.x, character.origin.y);
		spr.setPosition(character.x, character.y);
		spr.visible = (viewMode != 'spritesheet');

		var pos:Int = members.indexOf(character);
		if(pos > -1) insert(pos, spr);
		else add(spr);

		ghostLayers.push(layer);
		applyGhostVisuals();
		refreshGhostList();
		FlxG.sound.play(Paths.sound('chartingSounds/noteLay'));
		showOutput(wasUpdated ? 'Ghost updated for "${myAnim.anim}".' : 'Ghost added for "${myAnim.anim}".');
	}

	function toggleGhostLayer()
	{
		var myAnim:AnimArray = (anims != null) ? anims[curAnim] : null;
		if(character == null || character.isAnimationNull() || myAnim == null)
		{
			showOutput('Play an animation before adding a ghost.', true);
			return;
		}

		var existing:GhostLayer = ghostFor(myAnim.anim);
		if(existing == null)
		{
			addGhostLayer();
			return;
		}

		removeGhostLayer(ghostLayers.indexOf(existing));
		showOutput('Ghost removed for "${myAnim.anim}".');
	}

	function removeGhostLayer(idx:Int)
	{
		if(idx < 0 || idx >= ghostLayers.length) return;

		destroyGhostLayer(ghostLayers[idx]);
		ghostLayers.splice(idx, 1);
		refreshGhostList();
		FlxG.sound.play(Paths.sound('chartingSounds/noteErase'));
	}

	function clearGhosts()
	{
		while(ghostLayers.length > 0)
			destroyGhostLayer(ghostLayers.pop());

		refreshGhostList();
	}

	function destroyGhostLayer(layer:GhostLayer)
	{
		if(layer == null) return;

		if(layer.sprite != null)
		{
			remove(layer.sprite, true);
			layer.sprite.destroy();
		}
		layer.sprite = null;
		layer.animate = null;
	}

	function applyGhostVisuals()
	{
		var value:Int = ghostHighlight ? 125 : 0;
		for (layer in ghostLayers)
		{
			if(layer.sprite == null) continue;

			layer.sprite.alpha = ghostAlpha;
			layer.sprite.colorTransform.redOffset = value;
			layer.sprite.colorTransform.greenOffset = value;
			layer.sprite.colorTransform.blueOffset = value;
		}
	}

	function refreshGhostList()
	{
		if(ghostList == null) return;

		ghostList.setList(cast ghostLayers, -1);
	}

	var check_player:PsychUICheckBox;
	var charDropDown:PsychUIDropDownMenu;
	var animationDropDown:PsychUIDropDownMenu;
	var animationInputText:PsychUIInputText;
	var animationNameInputText:PsychUIInputText;
	var animationIndicesInputText:PsychUIInputText;
	var animationFramerate:PsychUINumericStepper;
	var animationLoopCheckBox:PsychUICheckBox;
	function addAnimationsUI()
	{
		var tab_group = UI_characterbox.getTab('Animations').menu;

		animationInputText = new PsychUIInputText(15, 85, 80, '', 8);
		animationNameInputText = new PsychUIInputText(animationInputText.x, animationInputText.y + 45, 150, '', 8);
		animationIndicesInputText = new PsychUIInputText(animationNameInputText.x, animationNameInputText.y + 45, 250, '', 8);
		animationFramerate = new PsychUINumericStepper(animationInputText.x + 170, animationInputText.y, 1, 24, 0, 240, 0);
		animationLoopCheckBox = new PsychUICheckBox(animationNameInputText.x + 170, animationNameInputText.y - 1, "Should it Loop?", 100);

		animationDropDown = new PsychUIDropDownMenu(15, animationInputText.y - 55, [''], function(selectedAnimation:Int, pressed:String) {
			var selectedName:String = animationDropDown.list[selectedAnimation];
			var anim:AnimArray = null;
			for(a in character.animationsArray)
				if(a.anim == selectedName) { anim = a; break; }
			if(anim == null) return;
			animationInputText.text = anim.anim;
			animationNameInputText.text = anim.name;
			animationLoopCheckBox.checked = anim.loop;
			animationFramerate.value = anim.fps;

			var indicesStr:String = anim.indices.toString();
			animationIndicesInputText.text = indicesStr.substr(1, indicesStr.length - 2);
		});

		var addUpdateButton:PsychUIButton = new PsychUIButton(70, animationIndicesInputText.y + 55, "Add/Update", function() {
			if(animationInputText.text.trim().length < 1)
			{
				showOutput('The animation needs a name.', true);
				return;
			}

			var indicesText:String = animationIndicesInputText.text.trim();
			var indices:Array<Int> = [];
			if(indicesText.length > 0)
			{
				var indicesStr:Array<String> = animationIndicesInputText.text.trim().split(',');
				if(indicesStr.length > 0)
				{
					for (ind in indicesStr)
					{
						if(ind.contains('-'))
						{
							var splitIndices:Array<String> = ind.split('-');
							var indexStart:Int = Std.parseInt(splitIndices[0]);
							if(Math.isNaN(indexStart) || indexStart < 0) indexStart = 0;
	
							var indexEnd:Int = Std.parseInt(splitIndices[1]);
							if(Math.isNaN(indexEnd) || indexEnd < indexStart) indexEnd = indexStart;
	
							for (index in indexStart...indexEnd+1)
								indices.push(index);
						}
						else
						{
							var index:Int = Std.parseInt(ind);
							if(!Math.isNaN(index) && index > -1)
								indices.push(index);
						}
					}
				}
			}

			var lastAnim:String = (character.animationsArray[curAnim] != null) ? character.animationsArray[curAnim].anim : '';
			var lastOffsets:Array<Int> = [0, 0];
			for (anim in character.animationsArray)
				if(animationInputText.text == anim.anim) {
					lastOffsets = anim.offsets;
					if(character.hasAnimation(animationInputText.text))
					{
						if(!character.isAnimateAtlas) character.animation.remove(animationInputText.text);
						else @:privateAccess character.atlas.anim.animsMap.remove(animationInputText.text);
					}
					character.animationsArray.remove(anim);
				}

			var addedAnim:AnimArray = newAnim(animationInputText.text, animationNameInputText.text);
			addedAnim.fps = Math.round(animationFramerate.value);
			addedAnim.loop = animationLoopCheckBox.checked;
			addedAnim.indices = indices;
			addedAnim.offsets = lastOffsets;
			addAnimation(addedAnim.anim, addedAnim.name, addedAnim.fps, addedAnim.loop, addedAnim.indices);
			character.animationsArray.push(addedAnim);

			reloadAnimList();
			@:arrayAccess curAnim = Std.int(Math.max(0, character.animationsArray.indexOf(addedAnim)));
			character.playAnim(addedAnim.anim, true);
			trace('Added/Updated animation: ' + animationInputText.text);
			FlxG.sound.play(Paths.sound('chartingSounds/noteLay'));
		});

		var removeButton:PsychUIButton = new PsychUIButton(180, animationIndicesInputText.y + 55, "Remove", function() {
			for (anim in character.animationsArray)
				if(animationInputText.text == anim.anim)
				{
					var resetAnim:Bool = false;
					if(anim.anim == character.getAnimationName()) resetAnim = true;
					if(character.hasAnimation(anim.anim))
					{
						if(!character.isAnimateAtlas) character.animation.remove(anim.anim);
						else @:privateAccess character.atlas.anim.animsMap.remove(anim.anim);
						character.animOffsets.remove(anim.anim);
						character.animationsArray.remove(anim);
					}

					if(resetAnim && character.animationsArray.length > 0) {
						curAnim = FlxMath.wrap(curAnim, 0, anims.length-1);
						character.playAnim(anims[curAnim].anim, true);
					}
					reloadAnimList();
					trace('Removed animation: ' + animationInputText.text);
					FlxG.sound.play(Paths.sound('chartingSounds/noteErase'));
					break;
				}
		});
		reloadAnimList();
		animationDropDown.selectedLabel = anims[0] != null ? anims[0].anim : '';

		tab_group.add(new FlxText(animationDropDown.x, animationDropDown.y - 18, 100, 'Animations:'));
		tab_group.add(new FlxText(animationInputText.x, animationInputText.y - 18, 100, 'Animation name:'));
		tab_group.add(new FlxText(animationFramerate.x, animationFramerate.y - 18, 100, 'Framerate:'));
		tab_group.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 18, 150, 'Animation Symbol Name/Tag:'));
		tab_group.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 18, 170, 'ADVANCED - Animation Indices:'));

		tab_group.add(animationInputText);
		tab_group.add(animationNameInputText);
		tab_group.add(animationIndicesInputText);
		tab_group.add(animationFramerate);
		tab_group.add(animationLoopCheckBox);
		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);
		tab_group.add(animationDropDown);
	}

	var imageInputText:PsychUIInputText;
	var healthIconInputText:PsychUIInputText;
	var vocalsInputText:PsychUIInputText;

	var singDurationStepper:PsychUINumericStepper;
	var scaleStepper:PsychUINumericStepper;
	var danceEveryBeatsStepper:PsychUINumericStepper;
	var positionXStepper:PsychUINumericStepper;
	var positionYStepper:PsychUINumericStepper;
	var positionCameraXStepper:PsychUINumericStepper;
	var positionCameraYStepper:PsychUINumericStepper;

	var flipXCheckBox:PsychUICheckBox;
	var noAntialiasingCheckBox:PsychUICheckBox;
	var vsliceSustainsCheckBox:PsychUICheckBox;
	var swapSingSidesCheckBox:PsychUICheckBox;

	var healthColorStepperR:PsychUINumericStepper;
	var healthColorStepperG:PsychUINumericStepper;
	var healthColorStepperB:PsychUINumericStepper;
	var healthBarDisplay:FlxSprite;
	var colorPickerSprite:FlxSprite;
	var hueSliderSprite:FlxSprite;
	var colorPickerDot:FlxSprite;
	var hueSliderLine:FlxSprite;
	var colorPickerHue:Float = 0;
	var colorPickerS:Float = 1;
	var colorPickerV:Float = 1;
	var colorPickerDragging:Int = 0;
	var hexColorInput:PsychUIInputText;
	function addCharacterUI()
	{
		var tab_group = UI_characterbox.getTab('Character').menu;

		check_player = new PsychUICheckBox(185, 30, "Playable", 90);
		check_player.checked = character.isPlayer;
		check_player.onClick = function()
		{
			character.isPlayer = !character.isPlayer;
			character.flipX = !character.flipX;
			updateCharacterPositions();
			updatePointerPos(false);
		};

		charDropDown = new PsychUIDropDownMenu(15, 30, [''], function(index:Int, intended:String)
		{
			if(intended == null || intended.length < 1) return;

			var characterPath:String = 'characters/$intended.json';
			var path:String = Paths.getPath(characterPath, TEXT, null, true);
			#if MODS_ALLOWED
			if (FileSystem.exists(path))
			#else
			if (Assets.exists(path))
			#end
			{
				_char = intended;
				check_player.checked = character.isPlayer;
				addCharacter();
				reloadCharacterOptions();
				reloadCharacterDropDown();
				updatePointerPos();
			}
			else
			{
				reloadCharacterDropDown();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
		}, 120);
		reloadCharacterDropDown();
		charDropDown.selectedLabel = _char;
		check_player.setPosition(charDropDown.button.x + charDropDown.button.width + 10, charDropDown.y);

		imageInputText = new PsychUIInputText(15, charDropDown.y + 42, 200, character.imageFile, 8);
		var reloadImage:PsychUIButton = new PsychUIButton(imageInputText.x + 210, imageInputText.y - 3, "Reload Image", function()
		{
			var lastAnim = character.getAnimationName();
			character.imageFile = imageInputText.text;
			reloadCharacterImage();
			if(!character.isAnimationNull()) {
				character.playAnim(lastAnim, true);
			}
		}, 90);

		vocalsInputText = new PsychUIInputText(15, imageInputText.y + 40, 150, character.vocalsFile != null ? character.vocalsFile : '', 8);

		singDurationStepper = new PsychUINumericStepper(15, vocalsInputText.y + 40, 0.1, 4, 0, 999, 1);
		danceEveryBeatsStepper = new PsychUINumericStepper(170, singDurationStepper.y, 1, character.danceEveryNumBeats, 1, 32, 0);

		scaleStepper = new PsychUINumericStepper(15, singDurationStepper.y + 40, 0.1, 1, 0.05, 10, 2);

		positionXStepper = new PsychUINumericStepper(15, scaleStepper.y + 40, 10, character.positionArray[0], -9000, 9000, 0);
		positionYStepper = new PsychUINumericStepper(positionXStepper.x + 97, positionXStepper.y, 10, character.positionArray[1], -9000, 9000, 0);

		positionCameraXStepper = new PsychUINumericStepper(positionXStepper.x, positionXStepper.y + 40, 10, character.cameraPosition[0], -9000, 9000, 0);
		positionCameraYStepper = new PsychUINumericStepper(positionYStepper.x, positionCameraXStepper.y, 10, character.cameraPosition[1], -9000, 9000, 0);

		flipXCheckBox = new PsychUICheckBox(170, scaleStepper.y, "Flip X", 50);
		flipXCheckBox.checked = character.flipX;
		if(character.isPlayer) flipXCheckBox.checked = !flipXCheckBox.checked;
		flipXCheckBox.onClick = function() {
			var prev = character.originalFlipX;
			_pushUndo(function() {
				character.originalFlipX = prev;
				character.flipX = (prev != character.isPlayer);
				flipXCheckBox.checked = prev;
				if(character.isPlayer) flipXCheckBox.checked = !flipXCheckBox.checked;
				unsavedProgress = true;
			});
			character.originalFlipX = !character.originalFlipX;
			character.flipX = (character.originalFlipX != character.isPlayer);
		};

		noAntialiasingCheckBox = new PsychUICheckBox(212, positionXStepper.y, "No Antialiasing", 110);
		vsliceSustainsCheckBox = new PsychUICheckBox(212, positionCameraXStepper.y, "VSlice Sustains", 110);

		vsliceSustainsCheckBox.checked = character.vsliceSustains;
		vsliceSustainsCheckBox.onClick = function() {
			var prev = character.vsliceSustains;
			_pushUndo(function() {
				character.vsliceSustains = prev;
				vsliceSustainsCheckBox.checked = prev;
				unsavedProgress = true;
			});
			character.vsliceSustains = vsliceSustainsCheckBox.checked;
			unsavedProgress = true;
		};

		noAntialiasingCheckBox.checked = character.noAntialiasing;
		noAntialiasingCheckBox.onClick = function() {
			var prev = character.noAntialiasing;
			_pushUndo(function() {
				character.noAntialiasing = prev;
				character.antialiasing = !prev && ClientPrefs.data.antialiasing;
				noAntialiasingCheckBox.checked = prev;
				unsavedProgress = true;
			});
			character.antialiasing = false;
			if(!noAntialiasingCheckBox.checked && ClientPrefs.data.antialiasing) {
				character.antialiasing = true;
			}
			character.noAntialiasing = noAntialiasingCheckBox.checked;
		};

		tab_group.add(new FlxText(15, charDropDown.y - 18, 120, 'Character:'));
		tab_group.add(new FlxText(15, imageInputText.y - 18, 120, 'Image file name:'));
		tab_group.add(new FlxText(15, vocalsInputText.y - 18, 130, 'Vocals File Postfix:'));
		tab_group.add(new FlxText(15, singDurationStepper.y - 18, 140, 'Sing Animation length:'));
		tab_group.add(new FlxText(danceEveryBeatsStepper.x, danceEveryBeatsStepper.y - 18, 100, 'Dance every:'));
		tab_group.add(new FlxText(15, scaleStepper.y - 18, 100, 'Scale:'));
		tab_group.add(new FlxText(15, positionXStepper.y - 18, 120, 'Character X/Y:'));
		tab_group.add(new FlxText(15, positionCameraXStepper.y - 18, 120, 'Camera X/Y:'));

		tab_group.add(imageInputText);
		tab_group.add(reloadImage);
		tab_group.add(vocalsInputText);
		tab_group.add(singDurationStepper);
		tab_group.add(danceEveryBeatsStepper);
		tab_group.add(scaleStepper);
		tab_group.add(positionXStepper);
		tab_group.add(positionYStepper);
		tab_group.add(positionCameraXStepper);
		tab_group.add(positionCameraYStepper);
		tab_group.add(flipXCheckBox);
		tab_group.add(noAntialiasingCheckBox);
		tab_group.add(vsliceSustainsCheckBox);
		tab_group.add(check_player);
		tab_group.add(charDropDown);
	}

	function openIconPrompt()
	{
		upperBox.isMinimized = true;
		upperBox.bg.visible = false;

		var prompt:BasePrompt = new BasePrompt(640, 280, 'Icon Properties', buildIconPrompt, function(_, _) {
			updateColorPicker();
		});
		prompt.closeCallback = function()
		{
			PsychUIInputText.focusOn = null;
			colorPickerDragging = 0;
			prompt.remove(healthIcon, true);
			healthIconInputText = null;
			healthBarDisplay = null;
			colorPickerSprite = null;
			hueSliderSprite = null;
			colorPickerDot = null;
			hueSliderLine = null;
			hexColorInput = null;
			healthColorStepperR = null;
			healthColorStepperG = null;
			healthColorStepperB = null;
		};
		openSubState(prompt);
	}

	function buildIconPrompt(state:BasePrompt)
	{
		var cams = state.cameras;
		var baseX:Float = state.bg.x;
		var contentY:Float = state.bg.y + 70;
		var iconX:Float = baseX + 25;

		var iconBg:FlxSprite = new FlxSprite(iconX, contentY).makeGraphic(150, 150, 0xFF222222);
		iconBg.cameras = cams;
		state.add(iconBg);

		healthIcon.setGraphicSize(150);
		healthIcon.updateHitbox();
		healthIcon.setPosition(iconX, contentY);
		healthIcon.cameras = cams;
		state.add(healthIcon);

		var midX:Float = baseX + 195;
		var iconLabel:FlxText = new FlxText(midX, contentY, 150, 'Health icon name:');
		iconLabel.cameras = cams;
		state.add(iconLabel);

		healthIconInputText = new PsychUIInputText(midX, contentY + 18, 130, character.healthIcon, 8);
		healthIconInputText.onChange = function(prev:String, next:String) {
			var lastIcon:String = healthIcon.getCharacter();
			healthIcon.changeIcon(next, false);
			healthIcon.setGraphicSize(150);
			healthIcon.updateHitbox();
			healthIcon.setPosition(iconX, contentY);
			character.healthIcon = next;
			if(lastIcon != healthIcon.getCharacter()) updatePresence();
			unsavedProgress = true;
		};
		healthIconInputText.cameras = cams;
		state.add(healthIconInputText);

		var decideIconColor:PsychUIButton = new PsychUIButton(midX, contentY + 48, "Get Icon Color", function()
		{
			var coolColor:FlxColor = FlxColor.fromInt(CoolUtil.dominantColor(healthIcon));
			character.healthColorArray[0] = coolColor.red;
			character.healthColorArray[1] = coolColor.green;
			character.healthColorArray[2] = coolColor.blue;
			updateHealthBar();
			unsavedProgress = true;
		}, 130);
		decideIconColor.cameras = cams;
		state.add(decideIconColor);

		var barLabel:FlxText = new FlxText(midX, contentY + 100, 150, 'Health Bar Color:');
		barLabel.cameras = cams;
		state.add(barLabel);

		var healthBarBg:FlxSprite = new FlxSprite(midX, contentY + 120).makeGraphic(150, 20, FlxColor.BLACK);
		healthBarBg.cameras = cams;
		state.add(healthBarBg);

		healthBarDisplay = new FlxSprite(midX + 3, contentY + 123).makeGraphic(144, 14, FlxColor.WHITE);
		healthBarDisplay.color = FlxColor.fromRGB(character.healthColorArray[0], character.healthColorArray[1], character.healthColorArray[2]);
		healthBarDisplay.cameras = cams;
		state.add(healthBarDisplay);

		var pickerX:Float = baseX + 375;
		var pickerW:Int = 90;
		var pickerH:Int = 90;
		var hueW:Int = 18;
		var pickerY:Float = contentY + 48;

		var initColor:FlxColor = FlxColor.fromRGB(character.healthColorArray[0], character.healthColorArray[1], character.healthColorArray[2]);
		colorPickerHue = initColor.hue;
		colorPickerS = initColor.saturation;
		colorPickerV = initColor.brightness;

		var hexLabel:FlxText = new FlxText(pickerX, contentY, pickerW + 40, 'Hex Color:');
		hexLabel.cameras = cams;
		state.add(hexLabel);

		var initHex:String = '#' + StringTools.hex(character.healthColorArray[0], 2) + StringTools.hex(character.healthColorArray[1], 2) + StringTools.hex(character.healthColorArray[2], 2);
		hexColorInput = new PsychUIInputText(pickerX, contentY + 18, pickerW, initHex, 8);
		hexColorInput.onChange = function(prev:String, next:String) {
			if (!StringTools.startsWith(next, '#'))
			{
				hexColorInput.text = '#' + StringTools.ltrim(next.replace('#', ''));
				return;
			}
			var clean:String = next.substr(1).toUpperCase();
			if (clean.length == 6) {
				var r:Int = Std.parseInt('0x' + clean.substr(0, 2));
				var g:Int = Std.parseInt('0x' + clean.substr(2, 2));
				var b:Int = Std.parseInt('0x' + clean.substr(4, 2));
				if (!Math.isNaN(r) && !Math.isNaN(g) && !Math.isNaN(b)) {
					var pr = character.healthColorArray.copy();
					_pushUndo(function() {
						character.healthColorArray = pr.copy();
						updateHealthBar();
						unsavedProgress = true;
					});
					character.healthColorArray[0] = r;
					character.healthColorArray[1] = g;
					character.healthColorArray[2] = b;
					updateHealthBar();
					unsavedProgress = true;
				}
			}
		};
		hexColorInput.cameras = cams;
		state.add(hexColorInput);

		colorPickerSprite = new FlxSprite(pickerX, pickerY);
		colorPickerSprite.makeGraphic(pickerW, pickerH, FlxColor.WHITE);
		colorPickerSprite.cameras = cams;

		hueSliderSprite = new FlxSprite(pickerX + pickerW + 4, pickerY);
		hueSliderSprite.makeGraphic(hueW, pickerH, FlxColor.WHITE);
		hueSliderSprite.pixels.lock();
		for (py in 0...pickerH)
		{
			var hue:Float = (py / pickerH) * 360;
			var col:FlxColor = FlxColor.fromHSB(hue, 1.0, 1.0);
			for (px in 0...hueW)
				hueSliderSprite.pixels.setPixel32(px, py, col);
		}
		hueSliderSprite.pixels.unlock();
		hueSliderSprite.dirty = true;
		hueSliderSprite.cameras = cams;

		redrawColorPicker();

		var rgbX:Float = pickerX + pickerW + hueW + 16;
		healthColorStepperR = new PsychUINumericStepper(rgbX + 20, pickerY, 20, character.healthColorArray[0], 0, 255, 0);
		healthColorStepperG = new PsychUINumericStepper(rgbX + 20, pickerY + 32, 20, character.healthColorArray[1], 0, 255, 0);
		healthColorStepperB = new PsychUINumericStepper(rgbX + 20, pickerY + 64, 20, character.healthColorArray[2], 0, 255, 0);

		healthColorStepperR.onValueChange = function() {
			var prev = character.healthColorArray[0];
			_pushUndo(function() {
				character.healthColorArray[0] = prev;
				updateHealthBar();
				unsavedProgress = true;
			});
			character.healthColorArray[0] = Math.round(healthColorStepperR.value);
			updateHealthBar();
			unsavedProgress = true;
		};
		healthColorStepperG.onValueChange = function() {
			var prev = character.healthColorArray[1];
			_pushUndo(function() {
				character.healthColorArray[1] = prev;
				updateHealthBar();
				unsavedProgress = true;
			});
			character.healthColorArray[1] = Math.round(healthColorStepperG.value);
			updateHealthBar();
			unsavedProgress = true;
		};
		healthColorStepperB.onValueChange = function() {
			var prev = character.healthColorArray[2];
			_pushUndo(function() {
				character.healthColorArray[2] = prev;
				updateHealthBar();
				unsavedProgress = true;
			});
			character.healthColorArray[2] = Math.round(healthColorStepperB.value);
			updateHealthBar();
			unsavedProgress = true;
		};

		for (i => label in ['R:', 'G:', 'B:'])
		{
			var txt:FlxText = new FlxText(rgbX, pickerY + i * 32, 30, label);
			txt.cameras = cams;
			state.add(txt);
		}

		colorPickerDot = new FlxSprite(0, 0);
		colorPickerDot.makeGraphic(8, 8, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawCircle(colorPickerDot, 4, 4, 3, FlxColor.WHITE);
		colorPickerDot.setPosition(
			colorPickerSprite.x + colorPickerS * colorPickerSprite.width - 3,
			colorPickerSprite.y + (1 - colorPickerV) * colorPickerSprite.height - 3
		);
		colorPickerDot.cameras = cams;

		hueSliderLine = new FlxSprite(0, 0);
		hueSliderLine.makeGraphic(Std.int(hueSliderSprite.width), 2, FlxColor.WHITE);
		hueSliderLine.setPosition(
			hueSliderSprite.x,
			hueSliderSprite.y + (colorPickerHue / 360) * hueSliderSprite.height - 1
		);
		hueSliderLine.cameras = cams;

		state.add(colorPickerSprite);
		state.add(hueSliderSprite);
		state.add(healthColorStepperR);
		state.add(healthColorStepperG);
		state.add(healthColorStepperB);
		state.add(colorPickerDot);
		state.add(hueSliderLine);

		var closeBtn:PsychUIButton = new PsychUIButton(0, state.bg.y + 245, 'Close', state.close, 100);
		closeBtn.screenCenter(X);
		closeBtn.cameras = cams;
		state.add(closeBtn);
	}

	function redrawColorPicker()
	{
		if (colorPickerSprite == null) return;
		var w:Int = colorPickerSprite.pixels.width;
		var h:Int = colorPickerSprite.pixels.height;
		colorPickerSprite.pixels.lock();
		for (py in 0...h)
			for (px in 0...w)
				colorPickerSprite.pixels.setPixel32(px, py, FlxColor.fromHSB(colorPickerHue, px / w, 1.0 - py / h));
		colorPickerSprite.pixels.unlock();
		colorPickerSprite.dirty = true;
	}

	public function UIEvent(id:String, sender:Dynamic) {
		//trace(id, sender);
		if(id == PsychUICheckBox.CLICK_EVENT)
			unsavedProgress = true;

		if(id == PsychUIInputText.CHANGE_EVENT)
		{
			if(sender == vocalsInputText)
			{
				character.vocalsFile = vocalsInputText.text;
				unsavedProgress = true;
			}
			else if(sender == imageInputText)
			{
				character.imageFile = imageInputText.text;
				unsavedProgress = true;
			}
		}
		else if(id == PsychUINumericStepper.CHANGE_EVENT)
		{
			if (sender == scaleStepper)
			{
				var prev = character.jsonScale;
				_pushUndo(function() {
					character.jsonScale = prev;
					character.scale.set(prev, prev);
					character.updateHitbox();
					scaleStepper.value = prev;
					updatePointerPos(false);
					unsavedProgress = true;
				});
				character.jsonScale = sender.value;
				character.scale.set(character.jsonScale, character.jsonScale);
				character.updateHitbox();
				reloadCharacterImage();
				updatePointerPos(false);
				unsavedProgress = true;
			}
			else if(sender == positionXStepper)
			{
				var prev = character.positionArray[0];
				_pushUndo(function() {
					character.positionArray[0] = prev;
					positionXStepper.value = prev;
					previewAsPlayer(false);
					unsavedProgress = true;
				});
				character.positionArray[0] = positionXStepper.value;
				previewAsPlayer(false);
				unsavedProgress = true;
			}
			else if(sender == positionYStepper)
			{
				var prev = character.positionArray[1];
				_pushUndo(function() {
					character.positionArray[1] = prev;
					positionYStepper.value = prev;
					previewAsPlayer(false);
					unsavedProgress = true;
				});
				character.positionArray[1] = positionYStepper.value;
				previewAsPlayer(false);
				unsavedProgress = true;
			}
			else if(sender == singDurationStepper)
			{
				var prev = character.singDuration;
				_pushUndo(function() {
					character.singDuration = prev;
					singDurationStepper.value = prev;
					unsavedProgress = true;
				});
				character.singDuration = singDurationStepper.value;
				unsavedProgress = true;
			}
			else if(sender == danceEveryBeatsStepper)
			{
				var prev = character.danceEveryNumBeats;
				_pushUndo(function() {
					character.danceEveryNumBeats = prev;
					danceEveryBeatsStepper.value = prev;
					unsavedProgress = true;
				});
				character.danceEveryNumBeats = Math.round(danceEveryBeatsStepper.value);
				unsavedProgress = true;
			}
			else if(sender == positionCameraXStepper)
			{
				var prev = character.cameraPosition[0];
				_pushUndo(function() {
					character.cameraPosition[0] = prev;
					positionCameraXStepper.value = prev;
					previewAsPlayer(false, true);
					unsavedProgress = true;
				});
				character.cameraPosition[0] = positionCameraXStepper.value;
				previewAsPlayer(false, true);
				unsavedProgress = true;
			}
			else if(sender == positionCameraYStepper)
			{
				var prev = character.cameraPosition[1];
				_pushUndo(function() {
					character.cameraPosition[1] = prev;
					positionCameraYStepper.value = prev;
					previewAsPlayer(false, true);
					unsavedProgress = true;
				});
				character.cameraPosition[1] = positionCameraYStepper.value;
				previewAsPlayer(false, true);
				unsavedProgress = true;
			}
		}
	}

	function reloadCharacterImage()
	{
		clearGhosts();

		var lastAnim:String = character.getAnimationName();
		var anims:Array<AnimArray> = character.animationsArray.copy();

		character.atlas = FlxDestroyUtil.destroy(character.atlas);
		character.isAnimateAtlas = false;
		character.color = FlxColor.WHITE;
		character.alpha = 1;

		if(Paths.fileExists('images/' + character.imageFile + '/Animation.json', TEXT))
		{
			character.atlas = new FlxAnimate();
			character.atlas.showPivot = false;
			try
			{
				Paths.loadAnimateAtlas(character.atlas, character.imageFile);
			}
			catch(e:Dynamic)
			{
				FlxG.log.warn('Could not load atlas ${character.imageFile}: $e');
			}
			character.isAnimateAtlas = true;
		}
		else
		{
			character.frames = Paths.getMultiAtlas(character.imageFile.split(','));
		}

		for (anim in anims) {
			var animAnim:String = '' + anim.anim;
			var animName:String = '' + anim.name;
			var animFps:Int = anim.fps;
			var animLoop:Bool = !!anim.loop; //Bruh
			var animIndices:Array<Int> = anim.indices;
			addAnimation(animAnim, animName, animFps, animLoop, animIndices);
		}

		if(anims.length > 0)
		{
			if(lastAnim != '') character.playAnim(lastAnim, true);
			else character.dance();
		}
	}

	function reloadCharacterOptions() {
		if(UI_characterbox == null) return;

		check_player.checked = character.isPlayer;
		imageInputText.text = character.imageFile;
		if(healthIconInputText != null) healthIconInputText.text = character.healthIcon;
		vocalsInputText.text = character.vocalsFile != null ? character.vocalsFile : '';
		singDurationStepper.value = character.singDuration;
		scaleStepper.value = character.jsonScale;
		if(danceEveryBeatsStepper != null) danceEveryBeatsStepper.value = character.danceEveryNumBeats;
		if(vsliceSustainsCheckBox != null) vsliceSustainsCheckBox.checked = character.vsliceSustains;
		flipXCheckBox.checked = character.originalFlipX;
		noAntialiasingCheckBox.checked = character.noAntialiasing;
		positionXStepper.value = character.positionArray[0];
		positionYStepper.value = character.positionArray[1];
		positionCameraXStepper.value = character.cameraPosition[0];
		positionCameraYStepper.value = character.cameraPosition[1];
		reloadAnimationDropDown();
		updateHealthBar();
	}

	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;
	var holdingFrameTime:Float = 0;
	var holdingFrameElapsed:Float = 0;
	var undoOffsets:Array<Float> = null;

	var _undoStack:Array<Void->Void> = [];
	static inline final MAX_UNDO:Int = 50;

	function _pushUndo(undoFn:Void->Void) {
		_undoStack.push(undoFn);
		if (_undoStack.length > MAX_UNDO) _undoStack.shift();
	}
	function updateColorPicker()
	{
		if (colorPickerSprite == null) return;

		{
			if (FlxG.mouse.justPressed)
			{
				if (FlxG.mouse.overlaps(hueSliderSprite, camHUD))
				{
					var pr = character.healthColorArray.copy();
					_pushUndo(function() {
						character.healthColorArray = pr.copy();
						updateHealthBar();
						unsavedProgress = true;
					});
					colorPickerDragging = 1;
				}
				else if (FlxG.mouse.overlaps(colorPickerSprite, camHUD))
				{
					var pr = character.healthColorArray.copy();
					_pushUndo(function() {
						character.healthColorArray = pr.copy();
						updateHealthBar();
						unsavedProgress = true;
					});
					colorPickerDragging = 2;
				}
				else
					colorPickerDragging = 0;
			}
			else if (FlxG.mouse.justReleased)
				colorPickerDragging = 0;

			if (FlxG.mouse.pressed && colorPickerDragging == 1)
			{
				var mousePos:FlxPoint = FlxG.mouse.getWorldPosition(camHUD);
				var bounds = hueSliderSprite.getScreenBounds(camHUD);
				var relY:Float = Math.max(0, Math.min(1, (mousePos.y - bounds.y) / bounds.height));
				colorPickerHue = relY * 360;
				mousePos.put();
				bounds.put();
				redrawColorPicker();
				if (hueSliderLine != null)
					hueSliderLine.y = hueSliderSprite.y + (colorPickerHue / 360) * hueSliderSprite.height - 1;
				var col:FlxColor = FlxColor.fromHSB(colorPickerHue, colorPickerS, colorPickerV);
				character.healthColorArray[0] = col.red;
				character.healthColorArray[1] = col.green;
				character.healthColorArray[2] = col.blue;
				updateHealthBar();
			}
			else if (FlxG.mouse.pressed && colorPickerDragging == 2)
			{
				var mousePos:FlxPoint = FlxG.mouse.getWorldPosition(camHUD);
				var bounds = colorPickerSprite.getScreenBounds(camHUD);
				colorPickerS = Math.max(0, Math.min(1, (mousePos.x - bounds.x) / bounds.width));
				colorPickerV = Math.max(0, Math.min(1, 1.0 - (mousePos.y - bounds.y) / bounds.height));
				mousePos.put();
				bounds.put();
				var col:FlxColor = FlxColor.fromHSB(colorPickerHue, colorPickerS, colorPickerV);
				character.healthColorArray[0] = col.red;
				character.healthColorArray[1] = col.green;
				character.healthColorArray[2] = col.blue;
				updateHealthBar();
				if (colorPickerDot != null)
					colorPickerDot.setPosition(
						colorPickerSprite.x + colorPickerS * colorPickerSprite.width - 3,
						colorPickerSprite.y + (1 - colorPickerV) * colorPickerSprite.height - 3
					);
			}
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		updateDebugShapes();
		outputTime = Math.max(0, outputTime - elapsed);
		outputTxt.alpha = outputTime;

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

		var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		var shiftMultBig:Float = 1;
		if(FlxG.keys.pressed.SHIFT)
		{
			shiftMult = 4;
			shiftMultBig = 10;
		}
		if(FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		var mouseDX:Float = FlxG.mouse.deltaScreenX;
		var mouseDY:Float = FlxG.mouse.deltaScreenY;
		if(skipMouseDelta)
		{
			if(mouseDX != 0 || mouseDY != 0) skipMouseDelta = false;
			mouseDX = 0;
			mouseDY = 0;
		}

		if(FlxG.mouse.justPressed || FlxG.mouse.justPressedRight)
			_pressedOverUI = mouseOverEditorUI();
		else if(!FlxG.mouse.pressed && !FlxG.mouse.pressedRight)
			_pressedOverUI = false;

		if(FlxG.mouse.justPressed)
	{
		if (_pressedOverUI) holdingObjectType = -1;
		else if(FlxG.mouse.pressedRight) holdingObjectType = 0;
		else if(FlxG.mouse.pressedMiddle) holdingObjectType = 2;
		else if(FlxG.mouse.pressed) holdingObjectType = 1;
	}
	else if(FlxG.mouse.justReleased) holdingObjectType = -1;

	if(FlxG.mouse.pressedRight && FlxG.mouse.pressed)
	{
		holdingObjectType = -1;
	}

	if(holdingObjectType == 0 && FlxG.mouse.pressedRight)
	{
		character.x -= mouseDX / FlxG.camera.zoom;
		character.y -= mouseDY / FlxG.camera.zoom;
		updatePointerPos(false);
	}
	else if(holdingObjectType == 1 && FlxG.mouse.pressed && !FlxG.mouse.pressedRight)
	{
		FlxG.camera.scroll.x -= mouseDX * shiftMult * ctrlMult;
		FlxG.camera.scroll.y -= mouseDY * shiftMult * ctrlMult;
	}

		// CAMERA CONTROLS
		if (FlxG.keys.pressed.J) FlxG.camera.scroll.x -= elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.K) FlxG.camera.scroll.y += elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.L) FlxG.camera.scroll.x += elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.I) FlxG.camera.scroll.y -= elapsed * 500 * shiftMult * ctrlMult;

		var lastZoom = FlxG.camera.zoom;
		if(FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL) FlxG.camera.zoom = 1;
		else if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3) {
			FlxG.camera.zoom += elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom > 3) FlxG.camera.zoom = 3;
		}
		else if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) {
			FlxG.camera.zoom -= elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
		}

		if(FlxG.mouse.wheel != 0)
	{
		var zoomAmount:Float = 0.05;
		if(FlxG.keys.pressed.CONTROL) zoomAmount = 0.01;
		else if(FlxG.keys.pressed.SHIFT) zoomAmount = 0.10;

		FlxG.camera.zoom += FlxG.mouse.wheel * zoomAmount;
		if(FlxG.camera.zoom > 3) FlxG.camera.zoom = 3;
		if(FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
	}

	if(lastZoom != FlxG.camera.zoom) cameraZoomText.text = 'Zoom: ' + FlxMath.roundDecimal(FlxG.camera.zoom, 2) + 'x';

		// CHARACTER CONTROLS
		var changedAnim:Bool = false;
		if(anims.length > 1)
		{
			if(FlxG.keys.justPressed.W && (changedAnim = true)) curAnim--;
			else if(FlxG.keys.justPressed.S && (changedAnim = true)) curAnim++;

			if(changedAnim)
			{
				undoOffsets = null;
				curAnim = FlxMath.wrap(curAnim, 0, anims.length-1);
				character.playAnim(anims[curAnim].anim, true);
				updateText();
			}
		}

		var canEditOffsets:Bool = (viewMode != 'spritesheet');
		var changedOffset = false;
		var moveKeysP = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];
		var moveKeys = [FlxG.keys.pressed.LEFT, FlxG.keys.pressed.RIGHT, FlxG.keys.pressed.UP, FlxG.keys.pressed.DOWN];
		if(canEditOffsets && moveKeysP.contains(true))
		{
			var prevX = character.offset.x;
			var prevY = character.offset.y;
			_pushUndo(function() {
				character.offset.x = prevX;
				character.offset.y = prevY;
				unsavedProgress = true;
			});
			character.offset.x += ((moveKeysP[0] ? 1 : 0) - (moveKeysP[1] ? 1 : 0)) * shiftMultBig;
			character.offset.y += ((moveKeysP[2] ? 1 : 0) - (moveKeysP[3] ? 1 : 0)) * shiftMultBig;
			changedOffset = true;
		}

		if(canEditOffsets && moveKeys.contains(true))
		{
			holdingArrowsTime += elapsed;
			if(holdingArrowsTime > 0.6)
			{
				holdingArrowsElapsed += elapsed;
				while(holdingArrowsElapsed > (1/60))
				{
					character.offset.x += ((moveKeys[0] ? 1 : 0) - (moveKeys[1] ? 1 : 0)) * shiftMultBig;
					character.offset.y += ((moveKeys[2] ? 1 : 0) - (moveKeys[3] ? 1 : 0)) * shiftMultBig;
					holdingArrowsElapsed -= (1/60);
					changedOffset = true;
				}
			}
		}
		else holdingArrowsTime = 0;

		if(canEditOffsets && FlxG.mouse.justPressedRight && !_pressedOverUI)
		{
			var prevX = character.offset.x;
			var prevY = character.offset.y;
			_pushUndo(function() {
				character.offset.x = prevX;
				character.offset.y = prevY;
				unsavedProgress = true;
			});
		}

		if(canEditOffsets && FlxG.mouse.pressedRight && !_pressedOverUI && (mouseDX != 0 || mouseDY != 0))
		{
			character.offset.x -= mouseDX;
			character.offset.y -= mouseDY;
			changedOffset = true;
		}

		if(FlxG.keys.pressed.CONTROL)
		{
			if(FlxG.keys.justPressed.C)
			{
				copiedOffset[0] = character.offset.x;
				copiedOffset[1] = character.offset.y;
				changedOffset = true;
			}
			else if(FlxG.keys.justPressed.V)
			{
				undoOffsets = [character.offset.x, character.offset.y];
				character.offset.x = copiedOffset[0];
				character.offset.y = copiedOffset[1];
				changedOffset = true;
			}
			else if(FlxG.keys.justPressed.R)
			{
				undoOffsets = [character.offset.x, character.offset.y];
				character.offset.set(0, 0);
				changedOffset = true;
			}
			else if(FlxG.keys.justPressed.Z)
			{
				if (_undoStack.length > 0)
					_undoStack.pop()();
				else if(undoOffsets != null)
				{
					character.offset.x = undoOffsets[0];
					character.offset.y = undoOffsets[1];
					changedOffset = true;
				}
			}
		}

		var anim = anims[curAnim];
		if(changedOffset && anim != null && anim.offsets != null)
		{
			anim.offsets[0] = Std.int(character.offset.x);
			anim.offsets[1] = Std.int(character.offset.y);

			character.addOffset(anim.anim, character.offset.x, character.offset.y);
			updateText();
		}

		var txt = 'ERROR: No Animation Found';
		var clr = FlxColor.RED;
		if(!character.isAnimationNull())
		{
			if(FlxG.keys.pressed.A || FlxG.keys.pressed.D)
			{
				holdingFrameTime += elapsed;
				if(holdingFrameTime > 0.5) holdingFrameElapsed += elapsed;
			}
			else holdingFrameTime = 0;

			if(FlxG.keys.justPressed.SPACE)
				character.playAnim(anims[curAnim].anim, true);

			var frames:Int = -1;
			var length:Int = -1;
			if(!character.isAnimateAtlas && character.animation.curAnim != null)
			{
				frames = character.animation.curAnim.curFrame;
				length = character.animation.curAnim.numFrames;
			}
			else if(character.isAnimateAtlas && character.atlas.anim != null)
			{
				frames = character.atlas.anim.curFrame;
				length = character.atlas.anim.length;
			}

			if(length >= 0)
			{
				if(FlxG.keys.justPressed.A || FlxG.keys.justPressed.D || holdingFrameTime > 0.5)
				{
					var isLeft = false;
					if((holdingFrameTime > 0.5 && FlxG.keys.pressed.A) || FlxG.keys.justPressed.A) isLeft = true;
					character.animPaused = true;
	
					if(holdingFrameTime <= 0.5 || holdingFrameElapsed > 0.1)
					{
						frames = FlxMath.wrap(frames + Std.int(isLeft ? -shiftMult : shiftMult), 0, length-1);
						if(!character.isAnimateAtlas) character.animation.curAnim.curFrame = frames;
						else character.atlas.anim.curFrame = frames;
						holdingFrameElapsed -= 0.1;
					}
				}
	
				txt = 'Frames: ( $frames / ${length-1} )';
				//if(character.animation.curAnim.paused) txt += ' - PAUSED';
				clr = FlxColor.WHITE;
			}
		}
		if(txt != frameAdvanceText.text) frameAdvanceText.text = txt;
		frameAdvanceText.color = clr;

		// OTHER CONTROLS
		if(FlxG.keys.justPressed.F12)
			silhouettes.visible = !silhouettes.visible;

		if(FlxG.keys.justPressed.F)
			toggleGhostLayer();

		if(FlxG.keys.justPressed.F1 || (helpBg.visible && FlxG.keys.justPressed.ESCAPE))
		{
			helpBg.visible = !helpBg.visible;
			helpTexts.visible = helpBg.visible;
		}
		else if(FlxG.keys.justPressed.ESCAPE)
		{
			if(!_goToPlayState)
			{
				if(!unsavedProgress)
				{
					FlxG.sound.music.stop();
					FlxG.mouse.visible = false;
					Conductor.reset();
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					funkin.editors.EditorHelper.returnToPreviousState();
				}
				else openSubState(new ExitConfirmationPrompt());
			}
			else
			{
				FlxG.sound.music.stop();
				FlxG.mouse.visible = false;
				Conductor.reset();
				MusicBeatState.switchState(new PlayState());
			}
			return;
		}
	}

	final assetFolder = 'week1';  //load from assets/week1/
	inline function loadBG()
	{
		var lastLoaded = Paths.currentLevel;
		Paths.currentLevel = assetFolder;

		/////////////
		// bg data //
		/////////////
		#if !BASE_GAME_FILES
		camEditor.bgColor = 0xFF666666;
		#else
		var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.9, 0.9);
		add(bg);
		stageSprites.push(bg);

		var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		add(stageFront);
		stageSprites.push(stageFront);
		#end

		dadPosition.set(100, 100);
		bfPosition.set(770, 100);
		/////////////

		Paths.currentLevel = lastLoaded;
	}

	inline function updatePointerPos(?snap:Bool = true)
	{
		if(character == null || cameraFollowPointer == null) return;

		var offX:Float = 0;
		var offY:Float = 0;
		var camArray:Array<Float> = character.cameraPosition;
		if(!character.isPlayer && !_previewingAsPlayer)
		{
			offX = character.getMidpoint().x + 150 + camArray[0];
			offY = character.getMidpoint().y - 100 + camArray[1];
		}
		else
		{
			offX = character.getMidpoint().x - 100 - camArray[0];
			offY = character.getMidpoint().y - 100 + camArray[1];
		}
		cameraFollowPointer.setPosition(offX, offY);

		if(snap)
		{
			FlxG.camera.scroll.x = cameraFollowPointer.getMidpoint().x - FlxG.width/2;
			FlxG.camera.scroll.y = cameraFollowPointer.getMidpoint().y - FlxG.height/2;
		}
	}

	inline function updateHealthBar()
	{
		if(healthColorStepperR != null) healthColorStepperR.value = character.healthColorArray[0];
		if(healthColorStepperG != null) healthColorStepperG.value = character.healthColorArray[1];
		if(healthColorStepperB != null) healthColorStepperB.value = character.healthColorArray[2];
		healthBar.leftBar.color = healthBar.rightBar.color = FlxColor.fromRGB(character.healthColorArray[0], character.healthColorArray[1], character.healthColorArray[2]);
		if(healthBarDisplay != null) healthBarDisplay.color = FlxColor.fromRGB(character.healthColorArray[0], character.healthColorArray[1], character.healthColorArray[2]);
		healthIcon.changeIcon(character.healthIcon, false);
		healthIcon.setGraphicSize(150);
		healthIcon.updateHitbox();
		updatePresence();

		var newColor:FlxColor = FlxColor.fromRGB(character.healthColorArray[0], character.healthColorArray[1], character.healthColorArray[2]);
		colorPickerHue = newColor.hue;
		colorPickerS = newColor.saturation;
		colorPickerV = newColor.brightness;
		redrawColorPicker();
		if (hexColorInput != null)
			hexColorInput.text = '#' + StringTools.hex(character.healthColorArray[0], 2) + StringTools.hex(character.healthColorArray[1], 2) + StringTools.hex(character.healthColorArray[2], 2);
		if(colorPickerDot != null && colorPickerSprite != null)
			colorPickerDot.setPosition(
				colorPickerSprite.x + colorPickerS * colorPickerSprite.width - 4,
				colorPickerSprite.y + (1 - colorPickerV) * colorPickerSprite.height - 4
			);
		if(hueSliderLine != null && hueSliderSprite != null)
			hueSliderLine.y = hueSliderSprite.y + (colorPickerHue / 360) * hueSliderSprite.height - 1;
	}

	inline function updatePresence() {
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Character Editor", "Character: " + _char, healthIcon.getCharacter());
		#end
	}

	inline function reloadAnimList()
	{
		anims = character.animationsArray;
		if(anims.length > 0) character.playAnim(anims[0].anim, true);
		curAnim = 0;

		updateText();
		updateSheetFrames();
		if(animScrollList != null) animScrollList.setList(anims, curAnim);
		if(animationDropDown != null) reloadAnimationDropDown();
	}

	inline function updateText()
	{
		if (animScrollList != null)
			animScrollList.setCurrent(curAnim);
	}

	inline function updateCharacterPositions()
	{
		if((character != null && !character.isPlayer) || (character == null && predictCharacterIsNotPlayer(_char))) character.setPosition(dadPosition.x, dadPosition.y);
		else character.setPosition(bfPosition.x, bfPosition.y);

		character.x += character.positionArray[0];
		character.y += character.positionArray[1];
		updatePointerPos(false);
	}

	var _previewingAsPlayer:Bool = false;
	function previewAsPlayer(active:Bool, snapCamera:Bool = false)
	{
		_previewingAsPlayer = active;
		if(active)
		{
			character.setPosition(bfPosition.x, bfPosition.y);
			character.x += character.positionArray[0];
			character.y += character.positionArray[1];
			character.flipX = !character.originalFlipX;
		}
		else
		{
			character.flipX = (character.originalFlipX != character.isPlayer);
			updateCharacterPositions();
		}
		updatePointerPos(snapCamera);
	}

	inline function predictCharacterIsNotPlayer(name:String)
	{
		return (name != 'bf' && !name.startsWith('bf-') && !name.endsWith('-player') && !name.endsWith('-playable') && !name.endsWith('-dead')) ||
				name.endsWith('-opponent') || name.startsWith('gf-') || name.endsWith('-gf') || name == 'gf';
	}

	function addAnimation(anim:String, name:String, fps:Float, loop:Bool, indices:Array<Int>)
	{
		if(!character.isAnimateAtlas)
		{
			if(indices != null && indices.length > 0)
				character.animation.addByIndices(anim, name, indices, "", fps, loop);
			else
				character.animation.addByPrefix(anim, name, fps, loop);
		}
		else
		{
			if(indices != null && indices.length > 0)
				character.atlas.anim.addBySymbolIndices(anim, name, indices, fps, loop);
			else
				character.atlas.anim.addBySymbol(anim, name, fps, loop);
		}

		if(!character.hasAnimation(anim))
			character.addOffset(anim, 0, 0);
	}

	inline function newAnim(anim:String, name:String):AnimArray
	{
		return {
			offsets: [0, 0],
			loop: false,
			fps: 24,
			anim: anim,
			indices: [],
			name: name
		};
	}

	var characterList:Array<String> = [];
	function reloadCharacterDropDown() {
		characterList = [];

		var foldersToCheck:Array<String> = [];
		var sharedPath:String = Paths.getRoutedSharedPath('characters/');
		if(FileSystem.exists(sharedPath))
			foldersToCheck.push(sharedPath);

		#if MODS_ALLOWED
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var modPath:String = Paths.mods(Mods.currentModDirectory + '/characters/');
			if(FileSystem.exists(modPath) && !foldersToCheck.contains(modPath))
				foldersToCheck.push(modPath);
		}
		#end

		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json'))
				{
					var charToCheck:String = file.substr(0, file.length - 5);
					if(!characterList.contains(charToCheck))
						characterList.push(charToCheck);
				}

		characterList.sort(function(a, b) return a.toLowerCase() < b.toLowerCase() ? -1 : 1);
		if(characterList.length < 1) characterList.push('');
		charDropDown.list = characterList;
		charDropDown.selectedLabel = _char;
	}

	function reloadAnimationDropDown() {
		var animList:Array<String> = [];
		for (anim in anims) animList.push(anim.anim);
		if(animList.length < 1) animList.push('NO ANIMATIONS'); //Prevents crash

		animationDropDown.list = animList;
	}

	// save
	function saveCharacter() {
		if(!fileDialog.completed) return;

		var json:Dynamic = {
			"animations": character.animationsArray,
			"image": character.imageFile,
			"scale": character.jsonScale,
			"sing_duration": character.singDuration,
			"healthicon": character.healthIcon,

			"position":	character.positionArray,
			"camera_position": character.cameraPosition,

			"flip_x": character.originalFlipX,
			"no_antialiasing": character.noAntialiasing,
			"healthbar_colors": character.healthColorArray,
			"vocals_file": character.vocalsFile,
			"dance_every_num_beats": character.danceEveryNumBeats,
			"vslice_sustains": character.vsliceSustains,
			"_editor_isPlayer": character.isPlayer
		};

		var data:String = PsychJsonPrinter.print(json, ['offsets', 'position', 'healthbar_colors', 'camera_position', 'indices']);

		if(data.length < 1) return;

		fileDialog.save('$_char.json', data,
			function() {
				unsavedProgress = false;
				showOutput('Character saved successfully to: ${fileDialog.path}');
			}, null,
			function() showOutput('Error on saving character!', true));
	}
}

typedef EditorSnapshot = {
	offsetX:Float, offsetY:Float,
	posX:Float, posY:Float,
	scaleJ:Float,
	flipX:Bool,
	noAntialiasing:Bool,
	healthColor:Array<Int>,
	singDuration:Float,
	cameraPos:Array<Float>
}

typedef GhostLayer = {
	var anim:String;
	var sprite:FlxSprite;
	var animate:FlxAnimate;
	var label:String;
}
