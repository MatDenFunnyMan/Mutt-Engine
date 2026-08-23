package funkin.editors;

import funkin.data.StageData;
import funkin.game.PsychCamera;
import funkin.game.Character;
import funkin.scripting.LuaUtils;

import flixel.FlxObject;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;
import openfl.display.BlendMode;
import flixel.util.FlxTimer;

import openfl.utils.Assets;

import openfl.display.Sprite;

import openfl.net.FileReference;

import openfl.events.Event;
import openfl.events.IOErrorEvent;

import funkin.scripting.ModchartSprite;
import flash.net.FileFilter;

import funkin.editors.content.Prompt;
import funkin.editors.content.PreloadListSubState;
import funkin.editors.content.PsychJsonPrinter;

class StageEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	final minZoom = 0.1;
	final maxZoom = 2;

	var gf:Character;
	var dad:Character;
	var boyfriend:Character;
	var stageJson:StageFile;

	var camGame:FlxCamera;
	public var camHUD:FlxCamera;

	var UI_stagebox:PsychUIBox;
	var UI_box:PsychUIBox;
	var spriteList_box:PsychUIBox;
	var stageSprites:Array<StageEditorMetaSprite> = [];
	public function new(stageToLoad:String = 'stage', cachedJson:StageFile = null)
	{
		lastLoadedStage = stageToLoad;
		stageJson = cachedJson;
		super();
	}

	var lastLoadedStage:String;
	var camFollow:FlxObject = new FlxObject(0, 0, 1, 1);
	var camDragging:Bool = false;
	var movedWithMouse:Bool = false;
	public var skipMouseDelta:Bool = false;

	var _preClickSelected:Int = -1;
	var clipboardSprite:Dynamic = null;

	var helpBg:FlxSprite;
	var helpTexts:FlxSpriteGroup;
	var posTxt:FlxText;
	var outputTxt:FlxText;

	var animationEditor:StageEditorAnimationSubstate;
	var unsavedProgress:Bool = false;
	
	var selectionSprites:FlxSpriteGroup = new FlxSpriteGroup();
	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		camGame = initPsychCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		#if DISCORD_ALLOWED
		#if MODS_ALLOWED
		DiscordClient.loadModRPC();
		#end
		DiscordClient.changePresence('Stage Editor', 'Stage: ' + lastLoadedStage);
		#end

		if(stageJson == null) stageJson = StageData.getStageFile(lastLoadedStage);
		FlxG.camera.follow(null, LOCKON, 0);

		loadJsonAssetDirectory();
		gf = new Character(0, 0, stageJson._editorMeta != null ? stageJson._editorMeta.gf : 'gf');
		gf.visible = !(stageJson.hide_girlfriend);
		dad = new Character(0, 0, stageJson._editorMeta != null ? stageJson._editorMeta.dad : 'dad');
		boyfriend = new Character(0, 0, stageJson._editorMeta != null ? stageJson._editorMeta.boyfriend : 'bf', true);

		for (i in 0...4)
		{
			var spr:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.LIME);
			spr.alpha = 0.8;
			selectionSprites.add(spr);
		}

		FlxG.camera.zoom = stageJson.defaultZoom;
		repositionGirlfriend();
		repositionDad();
		repositionBoyfriend();
		var point = focusOnTarget('boyfriend');
		FlxG.camera.scroll.set(point.x - FlxG.width/2, point.y - FlxG.height/2);

		screenUI();
		spriteCreatePopup();
		editorUI();
		
		add(camFollow);
		updateSpriteList();
		checkPreviewSupport();

		addHelpScreen();
		FlxG.mouse.visible = true;
		animationEditor = new StageEditorAnimationSubstate();

		if(FlxG.sound.music != null && FlxG.sound.music.playing)
			FlxG.sound.music.fadeOut(0.6, 0);

		new FlxTimer().start(10, function(_) {
			FlxG.sound.playMusic(Paths.music('chartEditorLoop'), 0);
			FlxG.sound.music.fadeIn(1.5, 0, 0.75);
		});

		super.create();
	}

	function loadJsonAssetDirectory()
	{
		var directory:String = 'shared';
		var weekDir:String = stageJson.directory;
		if (weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;

		Paths.setCurrentLevel(directory);
		trace('Setting asset folder to ' + directory);
	}

	var showSelectionQuad:Bool = true;
	function addHelpScreen()
	{
		#if FLX_DEBUG
		var btn = 'F3';
		#else
		var btn = 'F2';
		#end

		var str:Array<String> = [
			"E/Q - Camera Zoom In/Out",
			"J/K/L/I - Move Camera",
			"R - Reset Camera Zoom",
			"Arrow Keys/Mouse & Right Click - Move Object",
			"Enter - New Sprite (or Animations, if one is selected)",
			"Delete - Remove selected Sprite",
			"Ctrl + Z - Undo, Ctrl + Shift + Z - Redo",
			"Ctrl + C - Copy, Ctrl + V - Paste, Ctrl + X - Cut",
			"P - Reload Stage",
			"",
			'$btn - Toggle HUD',
			"F12 - Toggle Selection Rectangle",
			"Hold Shift - Move Objects and Camera 4x faster",
			"Hold Control - Move Objects pixel-by-pixel and Camera 4x slower"
		];

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

			var helpText:FlxText = new FlxText(0, 0, 680, txt, 16);
			helpText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
			helpText.borderColor = FlxColor.BLACK;
			helpText.scrollFactor.set();
			helpText.borderSize = 1;
			helpText.screenCenter();
			helpText.y += ((i - str.length/2) * 32) + 16;
			helpText.active = false;
			helpTexts.add(helpText);
		}
		helpTexts.active = helpTexts.visible = false;
		add(helpTexts);
	}

	function updateSpriteList()
	{
		for (spr in stageSprites)
			if(spr != null && !StageData.reservedNames.contains(spr.type))
				spr.sprite = FlxDestroyUtil.destroy(spr.sprite);

		stageSprites = [];
		
		var list:Map<String, FlxSprite> = [];
		if(stageJson.objects != null && stageJson.objects.length > 0)
		{
			list = StageData.addObjectsToState(stageJson.objects, gf, dad, boyfriend, null, true);
			var byID:Array<StageEditorMetaSprite> = [];
			for (key => spr in list)
				byID[spr.ID] = new StageEditorMetaSprite(stageJson.objects[spr.ID], spr);

			var lost:Int = 0;
			for (i in 0...stageJson.objects.length){
				if(byID[i] != null) stageSprites.push(byID[i]);
				else lost++;
			}
			if (lost > 0) showOutput('$lost object(s) skipped: cannot have duplicates for the stage!', true);
		}

		var characterIndices:Array<Int> = [];
		for (i in 0...stageSprites.length)
		{
			if(stageSprites[i] != null && StageData.reservedNames.contains(stageSprites[i].type))
				characterIndices.push(i);
		}

		for (character in ['gf', 'dad', 'boyfriend'])
		{
			if(!list.exists(character))
			{
				var charIndex = characterIndices.length > 0 ? characterIndices[0] : stageSprites.length;
				stageSprites.insert(charIndex, new StageEditorMetaSprite({type: character}, Reflect.field(this, character)));
				for (i in 0...characterIndices.length)
					characterIndices[i]++;
			}
		}

		loadLuaStageIfExists(lastLoadedStage);

		updateSpriteListRadio();
	}

	var spriteListRadioGroup:PsychUIRadioGroup;
	var focusRadioGroup:PsychUIRadioGroup;

	function screenUI()
	{
		var lowQualityCheckbox:PsychUICheckBox = null;
		var highQualityCheckbox:PsychUICheckBox = null;
		function visibilityFilterUpdate()
		{
			curFilters = 0;
			if(lowQualityCheckbox.checked) curFilters |= LOW_QUALITY;
			if(highQualityCheckbox.checked) curFilters |= HIGH_QUALITY;
		}

		spriteList_box = new PsychUIBox(25, 40, 250, 200, ['Sprite List']);
		spriteList_box.scrollFactor.set();
		spriteList_box.cameras = [camHUD];
		add(spriteList_box);
		addSpriteListBox();

		var bg:FlxSprite = new FlxSprite(0, FlxG.height - 60).makeGraphic(1, 1, FlxColor.BLACK);
		bg.cameras = [camHUD];
		bg.alpha = 0.4;
		bg.scale.set(FlxG.width, FlxG.height - bg.y);
		bg.updateHitbox();
		add(bg);
		
		var tipText:FlxText = new FlxText(0, FlxG.height - 44, 300, 'Press F1 for Help', 20);
		tipText.alignment = CENTER;
		tipText.cameras = [camHUD];
		tipText.scrollFactor.set();
		tipText.screenCenter(X);
		tipText.active = false;
		add(tipText);

		var targetTxt:FlxText = new FlxText(30, FlxG.height - 52, 300, 'Camera Target', 16);
		targetTxt.alignment = CENTER;
		targetTxt.cameras = [camHUD];
		targetTxt.scrollFactor.set();
		targetTxt.active = false;
		add(targetTxt);

		focusRadioGroup = new PsychUIRadioGroup(targetTxt.x, FlxG.height - 24, ['dad', 'boyfriend', 'gf'], 10, 0, true);
		focusRadioGroup.onClick = function() {
			//trace('Changed focus to $target');
			var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
			camFollow.setPosition(point.x, point.y);
			FlxG.camera.target = camFollow;
		}
		focusRadioGroup.radios[0].label = 'Opponent';
		focusRadioGroup.radios[1].label = 'Boyfriend';
		focusRadioGroup.radios[2].label = 'Girlfriend';

		for (radio in focusRadioGroup.radios)
			radio.text.size = 11;
		
		focusRadioGroup.cameras = [camHUD];
		add(focusRadioGroup);

		lowQualityCheckbox = new PsychUICheckBox(FlxG.width - 240, FlxG.height - 36, 'Can see Low Quality Sprites?', 90);
		lowQualityCheckbox.cameras = [camHUD];
		lowQualityCheckbox.onClick = visibilityFilterUpdate;
		lowQualityCheckbox.checked = false;
		add(lowQualityCheckbox);

		highQualityCheckbox = new PsychUICheckBox(FlxG.width - 120, FlxG.height - 36, 'Can see High Quality Sprites?', 90);
		highQualityCheckbox.cameras = [camHUD];
		highQualityCheckbox.onClick = visibilityFilterUpdate;
		highQualityCheckbox.checked = true;
		add(highQualityCheckbox);
		visibilityFilterUpdate();

		posTxt = new FlxText(0, 50, 500, 'X: 0\nY: 0', 24);
		posTxt.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		posTxt.borderSize = 2;
		posTxt.cameras = [camHUD];
		posTxt.screenCenter(X);
		posTxt.visible = false;
		add(posTxt);

		outputTxt = new FlxText(0, 0, 800, '', 24);
		outputTxt.alignment = CENTER;
		outputTxt.borderStyle = OUTLINE_FAST;
		outputTxt.borderSize = 1;
		outputTxt.cameras = [camHUD];
		outputTxt.screenCenter();
		outputTxt.alpha = 0;
		add(outputTxt);
	}

	function addSpriteListBox()
	{
		var tab_group = spriteList_box.getTab('Sprite List').menu;
		spriteListRadioGroup = new PsychUIRadioGroup(10, 10, [], 25, 18, false, 200);
		spriteListRadioGroup.cameras = [camHUD];
		spriteListRadioGroup.onClick = function() {
			trace('Selected sprite: ${spriteListRadioGroup.checkedRadio.label}');
			updateSelectedUI();
		}
		tab_group.add(spriteListRadioGroup);
		
		var buttonX = spriteList_box.x + spriteList_box.width - 10;
		var buttonY = spriteListRadioGroup.y - 30;
		var buttonMoveUp:PsychUIButton = new PsychUIButton(buttonX, buttonY, 'Move Up', function()
		{
			var selected:Int = getSelectedIndex();
			if(selected < 0) return;

			var spr = stageSprites[selected];
			if(spr == null) return;

			pushAction();

			var newSel:Int = Std.int(Math.min(stageSprites.length-1, selected + 1));
			stageSprites.remove(spr);
			stageSprites.insert(newSel, spr);

			updateSpriteListRadio();
		});
		buttonMoveUp.cameras = [camHUD];
		tab_group.add(buttonMoveUp);

		var buttonMoveDown:PsychUIButton = new PsychUIButton(buttonX, buttonY + 30, 'Move Down', function()
		{
			var selected:Int = getSelectedIndex();
			if(selected < 0) return;

			var spr = stageSprites[selected];
			if(spr == null) return;

			pushAction();

			var newSel:Int = Std.int(Math.max(0, selected - 1));
			stageSprites.remove(spr);
			stageSprites.insert(newSel, spr);

			updateSpriteListRadio();
		});
		buttonMoveDown.cameras = [camHUD];
		tab_group.add(buttonMoveDown);
		
		var buttonCreate:PsychUIButton = new PsychUIButton(buttonX, buttonY + 60, 'New', function() createPopup.visible = createPopup.active = true);
		buttonCreate.cameras = [camHUD];
		buttonCreate.normalStyle.bgColor = FlxColor.GREEN;
		buttonCreate.normalStyle.textColor = FlxColor.WHITE;
		tab_group.add(buttonCreate);

		var buttonDuplicate:PsychUIButton = new PsychUIButton(buttonX, buttonY + 90, 'Duplicate', function()
		{
			var selected:Int = getSelectedIndex();
			if(selected < 0) return;

			var spr = stageSprites[selected];
			if(spr == null || StageData.reservedNames.contains(spr.type)) return;

			var copiedSpr = new ModchartSprite();
			var copiedMeta:StageEditorMetaSprite = new StageEditorMetaSprite(null, copiedSpr);
			for (field in Reflect.fields(spr))
			{
				if(field == 'sprite') continue; //do NOT copy sprite or it might get messy
				try
				{
					var fld:Dynamic = Reflect.getProperty(spr, field);
					if(field == 'animations')
					{
						var arr:Array<Dynamic> = cast fld;
						if(arr != null)
						{
							var copiedAnims:Array<Dynamic> = [];
							for (v in arr)
							{
								if (v == null) continue;

								var indices:Array<Int> = v.indices;
								if(indices != null) indices = indices.copy();
	
								var offs:Array<Int> = v.offsets;
								if(offs != null) offs = offs.copy();

								copiedAnims.push({
									anim: v.anim,
									name: v.name,
									fps: v.fps,
									loop: v.loop,
									indices: indices,
									offsets: offs
								});
							}
							fld = copiedAnims;
						}
					} else if (fld is Array){
						var arr:Array<Dynamic> = fld;
						fld = arr.copy();
					}
					Reflect.setProperty(copiedMeta, field, fld);
				}
				catch(e:Dynamic){}
			}

			if(copiedMeta.animations != null)
			{
				for (num => anim in copiedMeta.animations)
				{
					if(anim == null || anim.anim == null) continue;
	
					if(anim.indices != null && anim.indices.length > 0)
						copiedSpr.animation.addByIndices(anim.anim, anim.name, anim.indices, '', anim.fps, anim.loop);
					else
						copiedSpr.animation.addByPrefix(anim.anim, anim.name, anim.fps, anim.loop);
	
					if(anim.offsets != null && anim.offsets.length > 1)
						copiedSpr.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
	
					if(copiedSpr.animation.curAnim == null || copiedMeta.firstAnimation == anim.anim)
						copiedSpr.playAnim(anim.anim, true);
				}
			}
			copiedMeta.setScale(copiedMeta.scale[0], copiedMeta.scale[1]);
			copiedMeta.setScrollFactor(copiedMeta.scroll[0], copiedMeta.scroll[1]);
			copiedMeta.name = findUnoccupiedCopyName(copiedMeta.name);
			insertMeta(copiedMeta, 1);
		});
		buttonDuplicate.cameras = [camHUD];
		buttonDuplicate.normalStyle.bgColor = FlxColor.BLUE;
		buttonDuplicate.normalStyle.textColor = FlxColor.WHITE;
		tab_group.add(buttonDuplicate);
	
		var buttonDelete:PsychUIButton = new PsychUIButton(buttonX, buttonY + 120, 'Delete', deleteSelected);
		buttonDelete.cameras = [camHUD];
		buttonDelete.normalStyle.bgColor = FlxColor.RED;
		buttonDelete.normalStyle.textColor = FlxColor.WHITE;
		tab_group.add(buttonDelete);
	}

	public function showOutput(txt:String, isError:Bool = false)
	{
		outputTxt.color = isError ? FlxColor.RED : FlxColor.WHITE;
		outputTxt.text = txt;
		outputTime = 3;
		
		if(isError) FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
		else FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	var createPopup:FlxSpriteGroup;
	function findUnoccupiedName(prefix = 'sprite')
	{
		var num:Int = 1;
		var name:String = 'unnamed';
		while(true)
		{
			var cantUseName:Bool = false;
			
			name = prefix + num;
			for (basic in stageSprites)
			{
				if(basic == null) continue;
				if(basic.name == name)
				{
					cantUseName = true;
					break;
				}
			}
			
			if(cantUseName)
			{
				num++;
				continue;
			}
			break;
		}
		return name;
	}

	function nameExists(name:String):Bool {
		for (basic in stageSprites)
			if (basic != null && basic.name == name) return true;
		return false;
	}

	function findUnoccupiedCopyName(baseName:String):String {
		var clean:String = baseName;
		var under:Int = clean.lastIndexOf('_');

		if (under > 0) {
			var inner:String = clean.substring(under + 1);
			if (inner.length > 0 && ~/^[0-9]+$/.match(inner))
				clean = clean.substring(0, under);
		}

		var num:Int = 1;
		var name:String = '${clean}_$num';
		while(nameExists(name)){
			num++;
			name = '${clean}_$num';
		}

		return name;
	}

	function insertMeta(meta, insertOffset:Int = 0)
	{
		pushAction();

		var num:Int = Std.int(Math.max(0, Math.min(spriteListRadioGroup.labels.length, spriteListRadioGroup.labels.length - spriteListRadioGroup.checked - 1 + insertOffset)));
		stageSprites.insert(num, meta);
		updateSpriteListRadio();
		createPopup.visible = createPopup.active = false;
		spriteListRadioGroup.checked = spriteListRadioGroup.labels.length - num - 1;
		updateSelectedUI();
		checkUIOnObject();
		unsavedProgress = true;
		FlxG.sound.play(Paths.sound('chartingSounds/noteLay'));
	}

	function spriteCreatePopup()
	{
		createPopup = new FlxSpriteGroup();
		createPopup.cameras = [camHUD];
		
		var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.alpha = 0.6;
		bg.scale.set(300, 240);
		bg.updateHitbox();
		bg.screenCenter();
		createPopup.add(bg);

		var txt:FlxText = new FlxText(0, bg.y + 10, 180, 'New Sprite', 24);
		txt.screenCenter(X);
		txt.alignment = CENTER;
		createPopup.add(txt);

		var btnY = 320;
		var btn:PsychUIButton = new PsychUIButton(0, btnY, 'No Animation', function() loadImage('sprite'));
		btn.screenCenter(X);
		createPopup.add(btn);

		btnY += 50;
		var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Animated', function() loadImage('animatedSprite'));
		btn.screenCenter(X);
		createPopup.add(btn);

		btnY += 50;
		var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Solid Color', function() {
			var meta:StageEditorMetaSprite = new StageEditorMetaSprite({type: 'square', scale: [200, 200], name: findUnoccupiedName()}, new ModchartSprite());
			meta.sprite.makeGraphic(1, 1, FlxColor.WHITE);
			meta.sprite.scale.set(200, 200);
			meta.sprite.updateHitbox();
			meta.sprite.screenCenter();
			insertMeta(meta);
		});
		btn.screenCenter(X);
		createPopup.add(btn);
		add(createPopup);
		createPopup.visible = createPopup.active = false;
	}
	
	function updateSpriteListRadio()
	{
		var _sel:String = (spriteListRadioGroup.checkedRadio != null ? spriteListRadioGroup.checkedRadio.label : null);
		var nameList:Array<String> = [];
		for (spr in stageSprites)
		{
			if(spr == null) continue;

			switch(spr.type)
			{
				case 'gf':
					nameList.push('- Girlfriend -');
				case 'boyfriend':
					nameList.push('- Boyfriend -');
				case 'dad':
					nameList.push('- Opponent -');
				default:
					nameList.push(spr.name);
			}
		}
		nameList.reverse();
		
		spriteListRadioGroup.labels = nameList;
		for (radio in spriteListRadioGroup.radios)
		{
			if(radio.label == _sel)
			{
				spriteListRadioGroup.checkedRadio = radio;
				break;
			}
		}

		final maxNum:Int = 19;
		spriteList_box.resize(250, Std.int(Math.min(maxNum, spriteListRadioGroup.labels.length) * 25 + 35));
	}

	function editorUI()
	{
		UI_box = new PsychUIBox(FlxG.width - 225, 10, 200, 500, ['Meta', 'Data', 'Object']);
		UI_box.cameras = [camHUD];
		UI_box.scrollFactor.set();
		add(UI_box);
		UI_box.selectedName = 'Data';

		UI_stagebox = new PsychUIBox(FlxG.width - 275, 25, 250, 100, ['Stage']);
		UI_stagebox.cameras = [camHUD];
		UI_stagebox.scrollFactor.set();
		add(UI_stagebox);
		UI_box.y += UI_stagebox.y + UI_stagebox.height;

		addDataTab();
		addObjectTab();
		addMetaTab();
		addStageTab();
	}

	var directoryDropDown:PsychUIDropDownMenu;
	var uiInputText:PsychUIInputText;
	var pixelStageCheckbox:PsychUICheckBox;
	var hideGirlfriendCheckbox:PsychUICheckBox;
	var hideBoyfriendCheckbox:PsychUICheckBox;
	var hideDadCheckbox:PsychUICheckBox;
	var zoomStepper:PsychUINumericStepper;
	var cameraSpeedStepper:PsychUINumericStepper;
	var camDadStepperX:PsychUINumericStepper;
	var camDadStepperY:PsychUINumericStepper;
	var camGfStepperX:PsychUINumericStepper;
	var camGfStepperY:PsychUINumericStepper;
	var camBfStepperX:PsychUINumericStepper;
	var camBfStepperY:PsychUINumericStepper;

	function findAssetFolders():Array<String>
	{
		var folders:Array<String> = ['week1', 'week6'];
		var dir:String = stageJson.directory;
		if(dir != null && dir.length > 0 && !folders.contains(dir)) folders.push(dir);
		return folders;
	}

	function reloadSpriteImages()
	{
		for (spr in stageSprites)
		{
			if(spr == null || spr.type == 'square') continue;
			if(StageData.reservedNames.contains(spr.type)) continue;

			var img:String = spr.image;
			spr.image = img;
		}
	}

	function forceAntialiasing(value:Bool)
	{
		for (spr in stageSprites)
		{
			if(spr == null || spr.type == 'square') continue;
			if(StageData.reservedNames.contains(spr.type)) continue;
			spr.antialiasing = value;
		}
	}

	function loadStageTemplate(pixel:Bool)
	{
		var templateName:String = pixel ? 'school' : 'stage';
		stageJson = StageData.getStageFile(templateName);
		stageJson.stageUI = pixel ? 'pixel' : '';
		stageJson.isPixelStage = null;

		loadJsonAssetDirectory();

		var oldStage:String = lastLoadedStage;
		lastLoadedStage = templateName;
		updateSpriteList();
		lastLoadedStage = oldStage;

		forceAntialiasing(!pixel);
		updateStageDataUI();
		reloadCharacters();

		undoStack = [];
		redoStack = [];
		unsavedProgress = false;
		showOutput(pixel ? 'Pixel stage template loaded.' : 'Normal stage template loaded.');
	}

	function isPixelUI(ui:String):Bool
	{
		if(ui == null) return false;
		ui = ui.trim();
		return ui == 'pixel' || ui.endsWith('-pixel');
	}

	function addDataTab()
	{
		var tab_group = UI_box.getTab('Data').menu;

		var objX = 10;
		var objY = 20;
		tab_group.add(new FlxText(objX, objY - 18, 150, 'Compiled Assets:'));

		var saveButton:PsychUIButton = new PsychUIButton(UI_box.width - 90, UI_box.height - 50, 'Save', function() {
			askScriptFormat();
		});
		tab_group.add(saveButton);

		directoryDropDown = new PsychUIDropDownMenu(objX, objY, findAssetFolders(), function(sel:Int, selected:String) {
			stageJson.directory = selected;
			loadJsonAssetDirectory();
			reloadSpriteImages();
		});
		directoryDropDown.selectedLabel = (stageJson.directory != null) ? stageJson.directory : '';

		objY += 50;
		tab_group.add(new FlxText(objX, objY - 18, 100, 'UI Style:'));
		uiInputText = new PsychUIInputText(objX, objY, 100, stageJson.stageUI != null ? stageJson.stageUI : '', 8);
		uiInputText.onChange = function(old:String, cur:String)
		{
			stageJson.stageUI = uiInputText.text;
			stageJson.isPixelStage = null;
			pixelStageCheckbox.checked = isPixelUI(stageJson.stageUI);
		};

		objY += 30;
		pixelStageCheckbox = new PsychUICheckBox(objX, objY, 'Pixel Stage?', 100);
		pixelStageCheckbox.onClick = function()
		{
			var wanted:Bool = pixelStageCheckbox.checked;
			pixelStageCheckbox.checked = !wanted;

			var action:String = wanted ? 'Checking' : 'Unchecking';
			var msg:String = 'Warning!\n$action the option will REMOVE all current loaded sprites.\nAre you sure?';

			openSubState(new BasePrompt(560, 200, msg, function(state:BasePrompt)
			{
				state.titleText.fieldWidth = 520;
				state.titleText.screenCenter(X);

				var btnY:Int = 390;

				var yesBtn:PsychUIButton = new PsychUIButton(0, btnY, 'Yes', function() {
					state.close();
					pixelStageCheckbox.checked = wanted;
					loadStageTemplate(wanted);
				});
				yesBtn.normalStyle.bgColor = FlxColor.RED;
				yesBtn.normalStyle.textColor = FlxColor.WHITE;
				yesBtn.screenCenter(X);
				yesBtn.x -= 100;
				yesBtn.cameras = state.cameras;
				state.add(yesBtn);

				var noBtn:PsychUIButton = new PsychUIButton(0, btnY, 'No', state.close);
				noBtn.screenCenter(X);
				noBtn.x += 100;
				noBtn.cameras = state.cameras;
				state.add(noBtn);
			}));
		};
		pixelStageCheckbox.checked = isPixelUI(stageJson.stageUI) || stageJson.isPixelStage == true;
		if(pixelStageCheckbox.checked && !isPixelUI(stageJson.stageUI))
		{
			stageJson.stageUI = 'pixel';
			stageJson.isPixelStage = null;
			uiInputText.text = 'pixel';
		}

		objY += 30;
		hideGirlfriendCheckbox = new PsychUICheckBox(objX, objY, 'Hide Girlfriend?', 100);
		hideGirlfriendCheckbox.onClick = function()
		{
			stageJson.hide_girlfriend = hideGirlfriendCheckbox.checked;
			gf.alpha = hideGirlfriendCheckbox.checked ? 0 : 1;
			if(focusRadioGroup.checked > -1)
			{
				var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
				camFollow.setPosition(point.x, point.y);
			}
		};
		hideGirlfriendCheckbox.checked = (stageJson.hide_girlfriend == true);

		objY += 30;
		hideBoyfriendCheckbox = new PsychUICheckBox(objX, objY, 'Hide Boyfriend?', 100);
		hideBoyfriendCheckbox.onClick = function()
		{
			stageJson.hide_boyfriend = hideBoyfriendCheckbox.checked;
			boyfriend.alpha = hideBoyfriendCheckbox.checked ? 0 : 1;
			if(focusRadioGroup.checked > -1)
			{
				var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
				camFollow.setPosition(point.x, point.y);
			}
		};
		hideBoyfriendCheckbox.checked = (stageJson.hide_boyfriend == true);

		objY += 30;
		hideDadCheckbox = new PsychUICheckBox(objX, objY, 'Hide Opponent?', 100);
		hideDadCheckbox.onClick = function()
		{
			stageJson.hide_opponent = hideDadCheckbox.checked;
			dad.alpha = hideDadCheckbox.checked ? 0 : 1;
			if(focusRadioGroup.checked > -1)
			{
				var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
				camFollow.setPosition(point.x, point.y);
			}
		};
		hideDadCheckbox.checked = (stageJson.hide_opponent == true);

		objY += 50;
		tab_group.add(new FlxText(objX, objY - 18, 100, 'Camera Offsets:'));

		objY += 20;
		tab_group.add(new FlxText(objX, objY - 18, 100, 'Opponent:'));

		var cx:Float = 0;
		var cy:Float = 0;
		if(stageJson.camera_opponent != null && stageJson.camera_opponent.length > 1)
		{
			cx = stageJson.camera_opponent[0];
			cy = stageJson.camera_opponent[1];
		}
		camDadStepperX = new PsychUINumericStepper(objX, objY, 50, cx, -10000, 10000, 0);
		camDadStepperY = new PsychUINumericStepper(objX + 80, objY, 50, cy, -10000, 10000, 0);
		camDadStepperX.onValueChange = camDadStepperY.onValueChange = function() {
			if(stageJson.camera_opponent == null) stageJson.camera_opponent = [0, 0];
			stageJson.camera_opponent[0] = camDadStepperX.value;
			stageJson.camera_opponent[1] = camDadStepperY.value;
			_updateCamera();
		};

		objY += 40;
		var cx:Float = 0;
		var cy:Float = 0;
		if(stageJson.camera_girlfriend != null && stageJson.camera_girlfriend.length > 1)
		{
			cx = stageJson.camera_girlfriend[0];
			cy = stageJson.camera_girlfriend[1];
		}
		tab_group.add(new FlxText(objX, objY - 18, 100, 'Girlfriend:'));
		camGfStepperX = new PsychUINumericStepper(objX, objY, 50, cx, -10000, 10000, 0);
		camGfStepperY = new PsychUINumericStepper(objX + 80, objY, 50, cy, -10000, 10000, 0);
		camGfStepperX.onValueChange = camGfStepperY.onValueChange = function() {
			if(stageJson.camera_girlfriend == null) stageJson.camera_girlfriend = [0, 0];
			stageJson.camera_girlfriend[0] = camGfStepperX.value;
			stageJson.camera_girlfriend[1] = camGfStepperY.value;
			_updateCamera();
		};

		objY += 40;
		var cx:Float = 0;
		var cy:Float = 0;
		if(stageJson.camera_boyfriend != null && stageJson.camera_boyfriend.length > 1)
		{
			cx = stageJson.camera_boyfriend[0];
			cy = stageJson.camera_boyfriend[1];
		}
		tab_group.add(new FlxText(objX, objY - 18, 100, 'Boyfriend:'));
		camBfStepperX = new PsychUINumericStepper(objX, objY, 50, cx, -10000, 10000, 0);
		camBfStepperY = new PsychUINumericStepper(objX + 80, objY, 50, cy, -10000, 10000, 0);
		camBfStepperX.onValueChange = camBfStepperY.onValueChange = function() {
			if(stageJson.camera_boyfriend == null) stageJson.camera_boyfriend = [0, 0];
			stageJson.camera_boyfriend[0] = camBfStepperX.value;
			stageJson.camera_boyfriend[1] = camBfStepperY.value;
			_updateCamera();
		};

		objY += 50;
		tab_group.add(new FlxText(objX, objY - 18, 100, 'Camera Data:'));
		objY += 20;
		tab_group.add(new FlxText(objX, objY - 18, 100, 'Zoom:'));
		zoomStepper = new PsychUINumericStepper(objX, objY, 0.05, stageJson.defaultZoom, minZoom, maxZoom, 2);
		zoomStepper.onValueChange = function() {
			stageJson.defaultZoom = zoomStepper.value;
			FlxG.camera.zoom = stageJson.defaultZoom;
		};

		tab_group.add(new FlxText(objX + 80, objY - 18, 100, 'Speed:'));
		cameraSpeedStepper = new PsychUINumericStepper(objX + 80, objY, 0.1, stageJson.camera_speed != null ? stageJson.camera_speed : 1, 0, 10, 2);
		cameraSpeedStepper.onValueChange = function() {
			stageJson.camera_speed = cameraSpeedStepper.value;
			FlxG.camera.followLerp = 0.04 * stageJson.camera_speed;
		};
		FlxG.camera.followLerp = 0.04 * cameraSpeedStepper.value;

		tab_group.add(hideGirlfriendCheckbox);
		tab_group.add(hideBoyfriendCheckbox);
		tab_group.add(hideDadCheckbox);
		tab_group.add(camDadStepperX);
		tab_group.add(camDadStepperY);
		tab_group.add(camGfStepperX);
		tab_group.add(camGfStepperY);
		tab_group.add(camBfStepperX);
		tab_group.add(camBfStepperY);
		tab_group.add(zoomStepper);
		tab_group.add(cameraSpeedStepper);
		
		tab_group.add(uiInputText);
		tab_group.add(pixelStageCheckbox);
		tab_group.add(directoryDropDown);
	}
	
	function _updateCamera()
	{
		if(focusRadioGroup.checked > -1)
		{
			var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
			camFollow.setPosition(point.x, point.y);
		}
	}

	var colorInputText:PsychUIInputText;
	var nameInputText:PsychUIInputText;
	var imgTxt:FlxText;

	var scaleStepperX:PsychUINumericStepper;
	var scaleStepperY:PsychUINumericStepper;
	var scrollStepperX:PsychUINumericStepper;
	var scrollStepperY:PsychUINumericStepper;
	var angleStepper:PsychUINumericStepper;
	var alphaStepper:PsychUINumericStepper;

	var antialiasingCheckbox:PsychUICheckBox;
	var flipXCheckBox:PsychUICheckBox;
	var flipYCheckBox:PsychUICheckBox;
	var lowQualityCheckbox:PsychUICheckBox;
	var highQualityCheckbox:PsychUICheckBox;
	var blendDropdown:PsychUIDropDownMenu;

	function getSelectedIndex():Int
	{
		var row:Int = spriteListRadioGroup.checked;
		if(row < 0) return -1;

		var listIndex:Int = row + spriteListRadioGroup.curScroll;
		if(listIndex < 0 || listIndex >= stageSprites.length) return -1;

		return stageSprites.length - listIndex - 1;
	}

	function getSelected(blockReserved:Bool = true)
	{
		var selected:Int = getSelectedIndex();
		if(selected >= 0)
		{
			var spr = stageSprites[selected];
			if(spr != null && (!blockReserved || !StageData.reservedNames.contains(spr.type)))
				return spr;
		}
		return null;
	}

	function applyBlendMode(meta:StageEditorMetaSprite)
	{
		if(meta == null || meta.sprite == null) return;
		
		var blendMode:BlendMode = BlendMode.NORMAL;
		switch(meta.blend)
		{
			case 'add': blendMode = BlendMode.ADD;
			case 'alpha': blendMode = BlendMode.ALPHA;
			case 'darken': blendMode = BlendMode.DARKEN;
			case 'difference': blendMode = BlendMode.DIFFERENCE;
			case 'erase': blendMode = BlendMode.ERASE;
			case 'hardlight': blendMode = BlendMode.HARDLIGHT;
			case 'invert': blendMode = BlendMode.INVERT;
			case 'layer': blendMode = BlendMode.LAYER;
			case 'lighten': blendMode = BlendMode.LIGHTEN;
			case 'multiply': blendMode = BlendMode.MULTIPLY;
			case 'overlay': blendMode = BlendMode.OVERLAY;
			case 'screen': blendMode = BlendMode.SCREEN;
			case 'shader': blendMode = BlendMode.SHADER;
			case 'subtract': blendMode = BlendMode.SUBTRACT;
			default: blendMode = BlendMode.NORMAL;
		}
		meta.sprite.blend = blendMode;
	}

	function addObjectTab()
	{
		var tab_group = UI_box.getTab('Object').menu;

		var objX = 10;
		var objY = 30;
		tab_group.add(new FlxText(objX, objY - 18, 150, 'Name (for Lua/HScript):'));
		nameInputText = new PsychUIInputText(objX, objY, 120, '', 8);
		nameInputText.customFilterPattern = ~/[^a-zA-Z0-9_\-]*/g;
		nameInputText.onChange = function(old:String, cur:String) {
			// change name
			var selected = getSelected();
			if(selected != null)
			{
				var changedName:String = nameInputText.text;
				if(changedName.length < 1)
				{
					showOutput('Sprite name cannot be empty!', true);
					return;
				}
				
				if(StageData.reservedNames.contains(changedName))
				{
					showOutput('To avoid conflicts, this name cannot be used!', true);
					return;
				}

				for (basic in stageSprites)
				{
					if (basic == null) continue;
					if (selected != basic && basic.name == changedName)
					{
						showOutput('Name "$changedName" is already in use!', true);
						return;
					}
				}

				pushPropertyAction('name');
				selected.name = changedName;
				spriteListRadioGroup.checkedRadio.label = selected.name;
				outputTime = 0;
				outputTxt.alpha = 0;
			}
		};
		tab_group.add(nameInputText);

		objY += 50;
		imgTxt = new FlxText(objX, objY - 18, 200, 'Image: ', 8);
		tab_group.add(imgTxt);
		
		var imgButton:PsychUIButton = new PsychUIButton(objX, objY + 20, 'Change Image', function() {
			trace('attempt to load image');
			loadImage();
		});
		tab_group.add(imgButton);
		
		var animationsButton:PsychUIButton = new PsychUIButton(objX + 90, objY + 20, 'Animations', openAnimationEditor);
		tab_group.add(animationsButton);
		
		objY += 70;
		tab_group.add(new FlxText(objX, objY - 18, 80, 'Color:'));
		colorInputText = new PsychUIInputText(objX, objY, 80, 'FFFFFF', 8);
		colorInputText.filterMode = ONLY_ALPHANUMERIC;
		colorInputText.onChange = function(old:String, cur:String) {
			// change color
			var selected = getSelected();
			if(selected != null){
				pushPropertyAction('color');
				selected.color = colorInputText.text;
			}
		};
		tab_group.add(colorInputText);

		function updateScale()
		{
			// scale
			var selected = getSelected();
			if(selected != null)
			{
				pushPropertyAction('scale');
				selected.setScale(scaleStepperX.value, scaleStepperY.value);
			}
		}
		
		objY += 50;
		tab_group.add(new FlxText(objX, objY - 18, 100, 'Scale (X/Y):'));
		scaleStepperX = new PsychUINumericStepper(objX, objY, 0.05, 1, 0.05, 10, 2);
		scaleStepperY = new PsychUINumericStepper(objX + 70, objY, 0.05, 1, 0.05, 10, 2);
		scaleStepperX.onValueChange = scaleStepperY.onValueChange = updateScale;
		tab_group.add(scaleStepperX);
		tab_group.add(scaleStepperY);

		function updateScroll()
		{
			// scroll factor
			var selected = getSelected();
			if(selected != null){
				pushPropertyAction('scroll');
				selected.setScrollFactor(scrollStepperX.value, scrollStepperY.value);
			}
		}

		objY += 40;
		tab_group.add(new FlxText(objX, objY - 18, 150, 'Scroll Factor (X/Y):'));
		scrollStepperX = new PsychUINumericStepper(objX, objY, 0.05, 1, 0, 10, 2);
		scrollStepperY = new PsychUINumericStepper(objX + 70, objY, 0.05, 1, 0, 10, 2);
		scrollStepperX.onValueChange = scrollStepperY.onValueChange = updateScroll;
		tab_group.add(scrollStepperX);
		tab_group.add(scrollStepperY);
		
		objY += 40;
		tab_group.add(new FlxText(objX, objY - 18, 80, 'Opacity:'));
		alphaStepper = new PsychUINumericStepper(objX, objY, 0.1, 1, 0, 1, 2, true);
		alphaStepper.onValueChange = function() {
			// alpha/opacity
			var selected = getSelected();
			if(selected != null){
				pushPropertyAction('alpha');
				selected.alpha = alphaStepper.value;
			}
		};
		tab_group.add(alphaStepper);

		antialiasingCheckbox = new PsychUICheckBox(objX + 90, objY, 'Anti-Aliasing', 80);
		antialiasingCheckbox.onClick = function()
		{
			// antialiasing
			var selected = getSelected();
			if(selected != null)
			{
				pushPropertyAction('antialiasing');
				if(selected.type != 'square')
					selected.antialiasing = antialiasingCheckbox.checked;
				else
				{
					antialiasingCheckbox.checked = false;
					selected.antialiasing = false;
				}
			}
		};
		tab_group.add(antialiasingCheckbox);

		objY += 40;
		tab_group.add(new FlxText(objX, objY - 18, 80, 'Angle:'));
		angleStepper = new PsychUINumericStepper(objX, objY, 10, 0, 0, 360, 0);
		angleStepper.onValueChange = function() {
			// alpha/opacity
			var selected = getSelected();
			if(selected != null){
				pushPropertyAction('angle');
				selected.angle = angleStepper.value;
			}
		};
		tab_group.add(angleStepper);

		function updateFlip()
		{
			//flip X and flip Y
			var selected = getSelected();
			if(selected != null)
			{
				pushPropertyAction('flip');
				if(selected.type != 'square')
				{
					selected.flipX = flipXCheckBox.checked;
					selected.flipY = flipYCheckBox.checked;
				}
				else
				{
					flipXCheckBox.checked = flipYCheckBox.checked = false;
					selected.flipX = selected.flipY = false;
				}
			}
		}

		objY += 25;
		flipXCheckBox = new PsychUICheckBox(objX, objY, 'Flip X', 60);
		flipXCheckBox.onClick = updateFlip;
		flipYCheckBox = new PsychUICheckBox(objX + 90, objY, 'Flip Y', 60);
		flipYCheckBox.onClick = updateFlip;
		tab_group.add(flipXCheckBox);
		tab_group.add(flipYCheckBox);

		objY += 45;
		function recalcFilter()
		{
			// low and/or high quality
			var selected = getSelected();
			if(selected != null)
			{
				pushPropertyAction('filters');
				var filt = 0;
				if(lowQualityCheckbox.checked) filt |= LOW_QUALITY;
				if(highQualityCheckbox.checked) filt |= HIGH_QUALITY;
				selected.filters = filt;
			}
		};
		tab_group.add(new FlxText(objX + 60, objY - 18, 100, 'Visible in:'));
		lowQualityCheckbox = new PsychUICheckBox(objX, objY, 'Low Quality', 70);
		highQualityCheckbox = new PsychUICheckBox(objX + 90, objY, 'High Quality', 70);
		lowQualityCheckbox.onClick = recalcFilter;
		highQualityCheckbox.onClick = recalcFilter;
		tab_group.add(lowQualityCheckbox);
		tab_group.add(highQualityCheckbox);

		var blendModes:Array<String> = ['', 'add', 'alpha', 'darken', 'difference', 'erase', 'hardlight', 'invert', 'layer', 'lighten', 'multiply', 'overlay', 'screen', 'shader', 'subtract'];
		blendDropdown = new PsychUIDropDownMenu(objX + 100, colorInputText.y, blendModes, function(id:Int, name:String) {
			var selected = getSelected();
			if(selected != null){
				pushPropertyAction('blend');
				selected.blend = name;
				applyBlendMode(selected);
			}
		}, 60);
		blendDropdown.cameras = [camHUD];
		blendDropdown.scrollFactor.set();
		var blendText = new FlxText(blendDropdown.x, blendDropdown.y - 18, 100, 'Blend Mode:');
		tab_group.add(blendText);
		tab_group.add(blendDropdown);
	}

	var oppDropdown:PsychUIDropDownMenu;
	var gfDropdown:PsychUIDropDownMenu;
	var plDropdown:PsychUIDropDownMenu;
	function addMetaTab()
	{
		var tab_group = UI_box.getTab('Meta').menu;

		var characterList = Mods.mergeAllTextsNamed('data/characterList.txt');
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'characters/');
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json'))
				{
					var charToCheck:String = file.substr(0, file.length - 5);
					if(!characterList.contains(charToCheck))
						characterList.push(charToCheck);
				}

		if(characterList.length < 1) characterList.push(''); //Prevents crash
		
		var objX = 10;
		var objY = 20;

		var openPreloadButton:PsychUIButton = new PsychUIButton(objX, objY, 'Preload List', function() {
			var lockedList:Array<String> = [];
			var currentMap:Map<String, LoadFilters> = [];
			for (spr in stageSprites)
			{
				if(spr == null || StageData.reservedNames.contains(spr.type)) continue;

				switch(spr.type)
				{
					case 'sprite', 'animatedSprite':
						if(spr.image != null && spr.image.length > 0 && !lockedList.contains(spr.image))
							lockedList.push(spr.image);
				}
			}

			if(stageJson.preload != null)
			{
				for (field in Reflect.fields(stageJson.preload))
				{
					if(!currentMap.exists(field) && !lockedList.contains(field))
						currentMap.set(field, Reflect.field(stageJson.preload, field));
				}
			}

			destroySubStates = true;
			openSubState(new PreloadListSubState(function(newSave:Map<String, LoadFilters>)
			{
				var len:Int = 0;
				for (name in newSave.keys())
					len++;

				stageJson.preload = {};
				for (key => value in newSave)
				{
					Reflect.setField(stageJson.preload, key, value);
				}
				unsavedProgress = true;
				showOutput('Saved new Preload List with $len files/folders!');
			}, lockedList, currentMap));
		});

		function setMetaData(data:String, char:String)
		{
			if(stageJson._editorMeta == null) stageJson._editorMeta = {dad: 'dad', gf: 'gf', boyfriend: 'bf'};
			Reflect.setField(stageJson._editorMeta, data, char);
		}

		objY += 60;
		oppDropdown = new PsychUIDropDownMenu(objX, objY, characterList, function(sel:Int, selected:String)
		{
			if(selected == null || selected.length < 1) return;
			dad.changeCharacter(selected);
			setMetaData('dad', selected);
			repositionDad();
		});
		oppDropdown.selectedLabel = dad.curCharacter;

		objY += 60;
		gfDropdown = new PsychUIDropDownMenu(objX, objY, characterList, function(sel:Int, selected:String)
		{
			if(selected == null || selected.length < 1) return;
			gf.changeCharacter(selected);
			setMetaData('gf', selected);
			repositionGirlfriend();
		});
		gfDropdown.selectedLabel = gf.curCharacter;

		objY += 60;
		plDropdown = new PsychUIDropDownMenu(objX, objY, characterList, function(sel:Int, selected:String)
		{
			if(selected == null || selected.length < 1) return;
			boyfriend.changeCharacter(selected);
			setMetaData('boyfriend', selected);
			repositionBoyfriend();
		});
		plDropdown.selectedLabel = boyfriend.curCharacter;

		tab_group.add(openPreloadButton);
		tab_group.add(new FlxText(plDropdown.x, plDropdown.y - 18, 100, 'Player:'));
		tab_group.add(plDropdown);
		tab_group.add(new FlxText(gfDropdown.x, gfDropdown.y - 18, 100, 'Girlfriend:'));
		tab_group.add(gfDropdown);
		tab_group.add(new FlxText(oppDropdown.x, oppDropdown.y - 18, 100, 'Opponent:'));
		tab_group.add(oppDropdown);
	}

	var stageDropDown:PsychUIDropDownMenu;

	function stageDummy(){
		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Stage Editor', 'New Stage');
		#end

		stageJson = StageData.dummy();
		updateSpriteList();
		updateStageDataUI();
		reloadCharacters();
	}

	function addStageTab()
	{
		var tab_group = UI_stagebox.getTab('Stage').menu;
		var reloadStage:PsychUIButton = new PsychUIButton(140, 10, 'Reload', reloadStageFromDisk);
		var dummyStage:PsychUIButton = new PsychUIButton(140, 40, 'Load Template', stageDummy);

		dummyStage.normalStyle.bgColor = FlxColor.RED;
		dummyStage.normalStyle.textColor = FlxColor.WHITE;

		stageDropDown = new PsychUIDropDownMenu(10, 30, [''], function(sel:Int, selected:String)
		{
			var characterPath:String = 'stages/$selected.json';
			var path:String = Paths.getPath(characterPath, TEXT, null, true);
			#if MODS_ALLOWED
			if (FileSystem.exists(path))
			#else
			if (Assets.exists(path))
			#end
            {
				stageJson = StageData.getStageFile(selected);
				lastLoadedStage = selected;
				#if DISCORD_ALLOWED
				#if MODS_ALLOWED
				DiscordClient.loadModRPC();
				#end
				DiscordClient.changePresence('Stage Editor', 'Stage: ' + lastLoadedStage);
				#end
				
				loadLuaStageIfExists(selected);
				
				updateSpriteList();
				updateStageDataUI();
				reloadCharacters();
				reloadStageDropDown();
				checkPreviewSupport();
			}
			else
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadStageDropDown();
			}
		});
		reloadStageDropDown();

		tab_group.add(new FlxText(stageDropDown.x, stageDropDown.y - 18, 60, 'Stage:'));
		tab_group.add(reloadStage);
		tab_group.add(dummyStage);
		tab_group.add(stageDropDown);
	}
	
	function updateStageDataUI()
	{
		directoryDropDown.list = findAssetFolders();
		directoryDropDown.selectedLabel = (stageJson.directory != null) ? stageJson.directory : '';
		//input texts
		uiInputText.text = (stageJson.stageUI != null ? stageJson.stageUI : '');
		pixelStageCheckbox.checked = isPixelUI(stageJson.stageUI) || stageJson.isPixelStage == true;
		//checkboxes
		hideGirlfriendCheckbox.checked = (stageJson.hide_girlfriend);
		gf.alpha = hideGirlfriendCheckbox.checked ? 0 : 1;

		hideBoyfriendCheckbox.checked = (stageJson.hide_boyfriend == true);
		boyfriend.alpha = hideBoyfriendCheckbox.checked ? 0 : 1;

		hideDadCheckbox.checked = (stageJson.hide_opponent == true);
		dad.alpha = hideDadCheckbox.checked ? 0 : 1;
		//steppers
		zoomStepper.value = FlxG.camera.zoom = stageJson.defaultZoom;
		
		if(stageJson.camera_speed != null) cameraSpeedStepper.value = stageJson.camera_speed;
		else cameraSpeedStepper.value = 1;
		FlxG.camera.followLerp = 0.04 * cameraSpeedStepper.value;

		if(stageJson.camera_opponent != null && stageJson.camera_opponent.length > 1)
		{
			camDadStepperX.value = stageJson.camera_opponent[0];
			camDadStepperY.value = stageJson.camera_opponent[1];
		}
		else camDadStepperX.value = camDadStepperY.value = 0;

		if(stageJson.camera_girlfriend != null && stageJson.camera_girlfriend.length > 1)
		{
			camGfStepperX.value = stageJson.camera_girlfriend[0];
			camGfStepperY.value = stageJson.camera_girlfriend[1];
		}
		else camGfStepperX.value = camGfStepperY.value = 0;

		if(stageJson.camera_boyfriend != null && stageJson.camera_boyfriend.length > 1)
		{
			camBfStepperX.value = stageJson.camera_boyfriend[0];
			camBfStepperY.value = stageJson.camera_boyfriend[1];
		}
		else camBfStepperX.value = camBfStepperY.value = 0;

		if(focusRadioGroup.checked > -1)
		{
			var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
			camFollow.setPosition(point.x, point.y);
		}
		loadJsonAssetDirectory();
	}

	function updateSelectedUI()
	{
		posTxt.visible = false;
		var selected = getSelected(false);
		if(selected == null) return;

		var displayX:Float = Math.round(selected.x);
		var displayY:Float = Math.round(selected.y);
		
		var char:Character = (selected.sprite is Character) ? cast selected.sprite : null;
		if(char != null)
		{
			displayX -= char.positionArray[0];
			displayY -= char.positionArray[1];
		}

		posTxt.text = 'X: $displayX\nY: $displayY';
		posTxt.visible = true;

		var selected = getSelected();
		if(selected == null) return;

		// Texts/Input Texts
		colorInputText.text = selected.color;
		nameInputText.text = selected.name;
		imgTxt.text = 'Image: ' + selected.image;

		// Steppers
		if (selected.type != 'square')
		{
			scaleStepperX.decimals = scaleStepperY.decimals = 2;
			scaleStepperX.max = scaleStepperY.max = 10;
			scaleStepperX.min = scaleStepperY.min = 0.05;
			scaleStepperX.step = scaleStepperY.step = 0.05;
		}
		else
		{
			scaleStepperX.decimals = scaleStepperY.decimals = 0;
			scaleStepperX.max = scaleStepperY.max = 10000;
			scaleStepperX.min = scaleStepperY.min = 50;
			scaleStepperX.step = scaleStepperY.step = 50;
		}
		scaleStepperX.value = selected.scale[0];
		scaleStepperY.value = selected.scale[1];
		scrollStepperX.value = selected.scroll[0];
		scrollStepperY.value = selected.scroll[1];
		angleStepper.value = selected.angle;
		alphaStepper.value = selected.alpha;

		// Checkboxes
		antialiasingCheckbox.checked = selected.antialiasing;
		flipXCheckBox.checked = selected.flipX;
		flipYCheckBox.checked = selected.flipY;
		lowQualityCheckbox.checked = (selected.filters & LOW_QUALITY) == LOW_QUALITY;
		highQualityCheckbox.checked = (selected.filters & HIGH_QUALITY) == HIGH_QUALITY;

		var blendValue:String = (selected.blend != null && selected.blend.length > 0) ? selected.blend : '';
		for (i in 0...blendDropdown.list.length)
		{
			if (blendDropdown.list[i] == blendValue)
			{
				blendDropdown.selectedIndex = i;
				break;
			}
		}
	}

	function reloadCharacters()
	{
		if(stageJson._editorMeta != null)
		{
			gf.changeCharacter(stageJson._editorMeta.gf);
			dad.changeCharacter(stageJson._editorMeta.dad);
			boyfriend.changeCharacter(stageJson._editorMeta.boyfriend);
		}
		repositionGirlfriend();
		repositionDad();
		repositionBoyfriend();

		focusRadioGroup.checked = -1;
		FlxG.camera.target = null;
		var point = focusOnTarget('boyfriend');
		FlxG.camera.scroll.set(point.x - FlxG.width/2, point.y - FlxG.height/2);
		FlxG.camera.zoom = stageJson.defaultZoom;
		oppDropdown.selectedLabel = dad.curCharacter;
		gfDropdown.selectedLabel = gf.curCharacter;
		plDropdown.selectedLabel = boyfriend.curCharacter;
	}
	
	function reloadStageDropDown()
	{
		var stageList:Array<String> = [];
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'stages/');
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json'))
				{
					var stageToCheck:String = file.substr(0, file.length - '.json'.length);
					if(StageData.editorHiddenStages.contains(stageToCheck)) continue;
					if(!stageList.contains(stageToCheck))
						stageList.push(stageToCheck);
				}

		if(stageList.length < 1) stageList.push('');
		stageDropDown.list = stageList;
		stageDropDown.selectedLabel = lastLoadedStage;
	}

	function deleteSelected()
	{
		var selected:Int = getSelectedIndex();
		if(selected < 0) return;

		var spr = stageSprites[selected];
		if(spr == null || StageData.reservedNames.contains(spr.type)) return;

		pushAction();

		stageSprites.remove(spr);
		spr.sprite = FlxDestroyUtil.destroy(spr.sprite);

		updateSpriteListRadio();
		checkUIOnObject();
		unsavedProgress = true;
		FlxG.sound.play(Paths.sound('chartingSounds/noteErase'));
	}

	function openAnimationEditor()
	{
		var selected = getSelected();
		if(selected == null) return;

		if(selected.type != 'animatedSprite')
		{
			showOutput('Only Animated Sprites can hold Animation data.', true);
			return;
		}

		destroySubStates = false;
		persistentDraw = false;
		animationEditor.target = selected;
		unsavedProgress = true;
		openSubState(animationEditor);
	}

		function copySelected()
	{
		var sel = getSelected();
		if(sel == null) return;

		clipboardSprite = haxe.Json.parse(haxe.Json.stringify(sel.formatToJson(false)));
		showOutput('Copied "${sel.name}"');
	}

	function cutSelected()
	{
		if(getSelected() == null) return;

		copySelected();
		deleteSelected();
	}

	function pasteSprite()
	{
		if(clipboardSprite == null) return;

		var data:Dynamic = haxe.Json.parse(haxe.Json.stringify(clipboardSprite));
		data.name = findUnoccupiedCopyName(data.name);

		var list = StageData.addObjectsToState([data], gf, dad, boyfriend, null, true);
		var spr = list.get(data.name);
		if(spr == null)
		{
			showOutput('Couldn\'t paste sprite.', true);
			return;
		}

		insertMeta(new StageEditorMetaSprite(data, spr), 1);
	}

		function checkPreviewSupport(){
		if(StageData.editorHiddenStages.contains(lastLoadedStage))
			showOutput('Stage cannot be edited! Create a custom stage instead.', true);
	}

	function reloadStageFromDisk()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Stage Editor', 'Stage: ' + lastLoadedStage);
		#end

		stageJson = StageData.getStageFile(lastLoadedStage);
		updateSpriteList();
		updateStageDataUI();
		reloadCharacters();
		reloadStageDropDown();

		undoStack = [];
		redoStack = [];
		unsavedProgress = false;
		showOutput('Stage reloaded.');
		checkPreviewSupport();
	}

	var undoStack:Array<Dynamic> = [];
	var redoStack:Array<Dynamic> = [];
	static inline var MAX_UNDO:Int = 30;
	var _lastPropAction:String = null;
	var _lastPropTime:Float = 0;

	function pushPropertyAction(id:String)
	{
		var key:String = '${getSelectedIndex()}:$id';
		var now:Float = haxe.Timer.stamp();
		if(_lastPropAction == key && now - _lastPropTime < 1)
		{
			_lastPropTime = now;
			return;
		}
		pushAction();
		_lastPropAction = key;
		_lastPropTime = now;
	}

	function stageSnapshot():Dynamic
	{
		var objs:Array<Dynamic> = [];
		var charIndex:Int = highestCharacterIndex();
		for (index => spr in stageSprites)
		{
			if(spr == null) continue;
			objs.push(spr.formatToJson(index > charIndex));
		}

		return {
			objects: objs,
			boyfriend: stageJson.boyfriend.copy(),
			girlfriend: stageJson.girlfriend.copy(),
			opponent: stageJson.opponent.copy()
		};
	}

	function pushAction()
	{
		_lastPropAction = null;
		undoStack.push(stageSnapshot());
		if(undoStack.length > MAX_UNDO) undoStack.shift();
		redoStack = [];
	}

	function applySnapshot(snap:Dynamic)
	{
		_lastPropAction = null;
		stageJson.objects = snap.objects;
		stageJson.boyfriend = snap.boyfriend;
		stageJson.girlfriend = snap.girlfriend;
		stageJson.opponent = snap.opponent;

		updateSpriteList();
		repositionGirlfriend();
		repositionDad();
		repositionBoyfriend();
		checkUIOnObject();
		updateSelectedUI();
		unsavedProgress = true;
	}

	function undo()
	{
		if(undoStack.length < 1)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
			return;
		}

		redoStack.push(stageSnapshot());
		applySnapshot(undoStack.pop());
		FlxG.sound.play(Paths.sound('chartingSounds/undo'));
	}

	function redo()
	{
		if(redoStack.length < 1)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
			return;
		}

		undoStack.push(stageSnapshot());
		applySnapshot(redoStack.pop());
		FlxG.sound.play(Paths.sound('chartingSounds/undo'));
	}

	function checkUIOnObject()
	{
		if(UI_box.selectedName == 'Object')
		{
			var selected:Int = getSelectedIndex();
			if(selected >= 0)
			{
				var spr = stageSprites[selected];
				if(spr != null && StageData.reservedNames.contains(spr.type))
				{
					UI_box.selectedName = 'Data';
					UI_box.getTab('Object').visible = false;
				}
				else
				{
					UI_box.getTab('Object').visible = true;
				}
			}
			else UI_box.selectedName = 'Data';
		}
		else
		{
			var selected:Int = getSelectedIndex();
			if(selected >= 0)
			{
				var spr = stageSprites[selected];
				if(spr != null && StageData.reservedNames.contains(spr.type))
					UI_box.getTab('Object').visible = false;
				else
					UI_box.getTab('Object').visible = true;
			}
		}
	}

	public function UIEvent(id:String, sender:Dynamic)
	{
		switch(id)
		{
			case PsychUIRadioGroup.CLICK_EVENT, PsychUIBox.CLICK_EVENT:
				if(sender == spriteListRadioGroup)
				{
					if(_preClickSelected >= 0 && getSelectedIndex() == _preClickSelected)
						spriteListRadioGroup.checked = -1;

					_preClickSelected = -1;
					checkUIOnObject();
					updateSelectedUI();
				}
				else if(sender == UI_box) checkUIOnObject();
				
			case PsychUICheckBox.CLICK_EVENT:
				unsavedProgress = true;

			case PsychUIInputText.CHANGE_EVENT, PsychUINumericStepper.CHANGE_EVENT:
				unsavedProgress = true;
		}
	}

	var outputTime:Float = 0;
	override function onFocus() {
		super.onFocus(); 
		skipMouseDelta = true; 
	}
	override function update(elapsed:Float)
	{
		if(FlxG.mouse.justPressed || FlxG.mouse.justPressedRight){
			_preClickSelected = getSelectedIndex();
			FlxG.sound.play(Paths.sound('chartingSounds/ClickDown'), 0.75);
		}

		if(FlxG.mouse.justReleased || FlxG.mouse.justReleasedRight)
			FlxG.sound.play(Paths.sound('chartingSounds/ClickUp'), 0.75);
		
		if(createPopup.visible && (FlxG.mouse.justPressedRight || (FlxG.mouse.justPressed && !FlxG.mouse.overlaps(createPopup, camHUD))))
			createPopup.visible = createPopup.active = false;

		for (basic in stageSprites)
			if(basic != null) basic.update(curFilters, elapsed);

		super.update(elapsed);
		
		outputTime = Math.max(0, outputTime - elapsed);
		outputTxt.alpha = outputTime;

		if(PsychUIInputText.focusOn != null) return;

		if(FlxG.keys.justPressed.ESCAPE)
		{
			if(createPopup.visible){
				createPopup.visible = createPopup.active = false;
				return;
			}

			if(helpBg.visible){
				helpBg.visible = helpTexts.visible = false;
				return;
			}

			if(!unsavedProgress){
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				funkin.editors.EditorHelper.returnToPreviousState();
			}
			else openSubState(new ExitConfirmationPrompt());
			return;
		}

		if(FlxG.keys.justPressed.W){
			spriteListRadioGroup.checked = FlxMath.wrap(spriteListRadioGroup.checked - 1, 0, spriteListRadioGroup.labels.length-1);
			trace(spriteListRadioGroup.checked);
			checkUIOnObject();
			updateSelectedUI();
		}
		else if(FlxG.keys.justPressed.S){
			spriteListRadioGroup.checked = FlxMath.wrap(spriteListRadioGroup.checked + 1, 0, spriteListRadioGroup.labels.length-1);
			trace(spriteListRadioGroup.checked);
			checkUIOnObject();
			updateSelectedUI();
		}

		if(FlxG.keys.justPressed.SPACE){
			var selected = getSelected();
			if(selected != null && selected.type == 'animatedSprite' && selected.sprite.animation.curAnim != null)
			{
				selected.sprite.animation.play(selected.sprite.animation.curAnim.name, true);
			}
		}

		if(FlxG.keys.justPressed.F1 || (helpBg.visible && FlxG.keys.justPressed.ESCAPE)){
			helpBg.visible = !helpBg.visible;
			helpTexts.visible = helpBg.visible;
		}

		if(!createPopup.visible && !helpBg.visible){
			if(FlxG.keys.justPressed.DELETE) deleteSelected();

			if(FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Z)
			{
				if(FlxG.keys.pressed.SHIFT) redo();
				else undo();
			}

			if(FlxG.keys.justPressed.P) reloadStageFromDisk();

			if(FlxG.keys.pressed.CONTROL){
				if(FlxG.keys.justPressed.C) copySelected();
				else if(FlxG.keys.justPressed.X) cutSelected();
				else if(FlxG.keys.justPressed.V) pasteSprite();
			}

			if(FlxG.keys.justPressed.ENTER)
			{
				var selected = getSelected();
				if(selected == null) createPopup.visible = createPopup.active = true;
				else openAnimationEditor();
			}
		}

		#if FLX_DEBUG
		if(FlxG.keys.justPressed.F3)
		#else
		if(FlxG.keys.justPressed.F2)
		#end
		{
			UI_box.visible = !UI_box.visible;
			UI_box.active = !UI_box.active;

			var objs = [UI_stagebox, spriteListRadioGroup, spriteList_box];
			for (obj in objs)
			{
				obj.visible = UI_box.visible;
				if(!(obj is FlxText)) obj.active = UI_box.active;
			}
			spriteListRadioGroup.updateRadioItems();
		}
		
		if(FlxG.keys.justPressed.F12)
			showSelectionQuad = !showSelectionQuad;
		
		var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		if(FlxG.keys.pressed.SHIFT) shiftMult = 4;
		if(FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		// CAMERA CONTROLS
		var camX:Float = 0;
		var camY:Float = 0;
		var camMove:Float = elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.J) camX -= camMove;
		if (FlxG.keys.pressed.K) camY += camMove;
		if (FlxG.keys.pressed.L) camX += camMove;
		if (FlxG.keys.pressed.I) camY -= camMove;

		var isOverUI = (UI_box.visible && FlxG.mouse.overlaps(UI_box, camHUD)) || // change stuff here
		               (UI_stagebox.visible && FlxG.mouse.overlaps(UI_stagebox, camHUD)) ||
		               (spriteList_box.visible && FlxG.mouse.overlaps(spriteList_box, camHUD)) ||
		               (createPopup.visible && FlxG.mouse.overlaps(createPopup, camHUD));
		
		var mouseDX:Int = 0;
		var mouseDY:Int = 0;
		if (skipMouseDelta) skipMouseDelta = false;
		else {
			mouseDX = FlxG.mouse.deltaScreenX;
			mouseDY = FlxG.mouse.deltaScreenY;
		}

		if(FlxG.mouse.justPressed && !FlxG.mouse.pressedRight) camDragging = !isOverUI;
		else if(!FlxG.mouse.pressed || FlxG.mouse.pressedRight) camDragging = false;

		if(camDragging && (mouseDX != 0 || mouseDY != 0)){
			camX -= mouseDX;
			camY -= mouseDY;
		}

		if(camX != 0 || camY != 0)
		{
			FlxG.camera.scroll.x += camX;
			FlxG.camera.scroll.y += camY;
			if(FlxG.camera.target != null) FlxG.camera.target = null;
			if(focusRadioGroup.checked > -1) focusRadioGroup.checked = -1;
		}

		var lastZoom = FlxG.camera.zoom;
		if(FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL)
			FlxG.camera.zoom = stageJson.defaultZoom;
		else if (FlxG.keys.pressed.E && FlxG.camera.zoom < maxZoom)
			FlxG.camera.zoom = Math.min(maxZoom, FlxG.camera.zoom + elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);
		else if (FlxG.keys.pressed.Q && FlxG.camera.zoom > minZoom)
			FlxG.camera.zoom = Math.max(minZoom, FlxG.camera.zoom - elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);
		
		if(!isOverUI && FlxG.mouse.wheel != 0)
		{
			var zoomAmount = FlxG.mouse.wheel * 0.1;
			FlxG.camera.zoom = Math.max(minZoom, Math.min(maxZoom, FlxG.camera.zoom + zoomAmount));
		}
		
		// SPRITE X/Y
		var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		if(FlxG.keys.pressed.SHIFT) shiftMult = 4;
		if(FlxG.keys.pressed.CONTROL) ctrlMult = 0.2;

		if(getSelectedIndex() >= 0 && (FlxG.mouse.justPressedRight || FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN))
			pushAction();

		var moveX:Float = 0;
		var moveY:Float = 0;
		if (FlxG.keys.justPressed.LEFT) moveX -= 1 * shiftMult * ctrlMult;
		if (FlxG.keys.justPressed.RIGHT) moveX += 1 * shiftMult * ctrlMult;
		if (FlxG.keys.justPressed.UP) moveY -= 1 * shiftMult * ctrlMult;
		if (FlxG.keys.justPressed.DOWN) moveY += 1 * shiftMult * ctrlMult;

		if(FlxG.mouse.pressedRight && (mouseDX != 0 || mouseDY != 0)){
			moveX += mouseDX * ctrlMult;
			moveY += mouseDY * ctrlMult;
			_updateCamera();
		}

		if(movedWithMouse && !FlxG.mouse.pressedRight){
			movedWithMouse = false;
			FlxG.sound.play(Paths.sound('chartingSounds/noteLay'));
		}

		if(moveX != 0 || moveY != 0)
		{
			var selected:Int = getSelectedIndex();
			if(selected < 0) return;

			var spr = stageSprites[selected];
			if(spr != null)
			{
				var displayX:Float, displayY:Float;
				spr.x = displayX = Math.round(spr.x + moveX);
				spr.y = displayY = Math.round(spr.y + moveY);
				if(FlxG.mouse.pressedRight) movedWithMouse = true;
				var char:Character = cast spr.sprite;
				switch(spr.type)
				{
					case 'boyfriend':
						stageJson.boyfriend[0] = displayX = spr.x - char.positionArray[0];
						stageJson.boyfriend[1] = displayY = spr.y - char.positionArray[1];
					case 'gf':
						stageJson.girlfriend[0] = displayX = spr.x - char.positionArray[0];
						stageJson.girlfriend[1] = displayY = spr.y - char.positionArray[1];
					case 'dad':
						stageJson.opponent[0] = displayX = spr.x - char.positionArray[0];
						stageJson.opponent[1] = displayY = spr.y - char.positionArray[1];
				}
				posTxt.text = 'X: $displayX\nY: $displayY';
			}
		}
	}

	var curFilters:LoadFilters = (LOW_QUALITY)|(HIGH_QUALITY);
	override function draw()
	{
		if(persistentDraw || subState == null)
		{

			for (basic in stageSprites)
				if(basic != null && basic.visible)
					basic.draw(curFilters);
	
			if(showSelectionQuad && spriteListRadioGroup.checkedRadio != null)
			{
				var selected:Int = getSelectedIndex();
				var spr = (selected >= 0) ? stageSprites[selected] : null;
				if(spr != null) drawDebugOnCamera(spr.sprite);
			}
		}

		super.draw();
	}

	var focusPoint:FlxPoint = FlxPoint.get();
	var midPoint:FlxPoint = FlxPoint.get();
	function focusOnTarget(target:String)
	{
		focusPoint.set(0, 0);
		switch(target)
		{
			case 'boyfriend':
				boyfriend.getMidpoint(midPoint);
				focusPoint.x += midPoint.x - boyfriend.cameraPosition[0] - 100;
				focusPoint.y += midPoint.y + boyfriend.cameraPosition[1] - 100;
				if(stageJson.camera_boyfriend != null && stageJson.camera_boyfriend.length > 1)
				{
					focusPoint.x += stageJson.camera_boyfriend[0];
					focusPoint.y += stageJson.camera_boyfriend[1];
				}
			case 'dad':
				dad.getMidpoint(midPoint);
				focusPoint.x += midPoint.x + dad.cameraPosition[0] + 150;
				focusPoint.y += midPoint.y + dad.cameraPosition[1] - 100;
				if(stageJson.camera_opponent != null && stageJson.camera_opponent.length > 1)
				{
					focusPoint.x += stageJson.camera_opponent[0];
					focusPoint.y += stageJson.camera_opponent[1];
				}
			case 'gf':
				if(gf.visible)
				{
					gf.getMidpoint(midPoint);
					focusPoint.x += midPoint.x + gf.cameraPosition[0];
					focusPoint.y += midPoint.y + gf.cameraPosition[1];
				}

				if(stageJson.camera_girlfriend != null && stageJson.camera_girlfriend.length > 1)
				{
					focusPoint.x += stageJson.camera_girlfriend[0];
					focusPoint.y += stageJson.camera_girlfriend[1];
				}
		}
		return focusPoint;
	}

	function repositionGirlfriend()
	{
		gf.setPosition(stageJson.girlfriend[0], stageJson.girlfriend[1]);
		gf.x += gf.positionArray[0];
		gf.y += gf.positionArray[1];
	}
	function repositionDad()
	{
		dad.setPosition(stageJson.opponent[0], stageJson.opponent[1]);
		dad.x += dad.positionArray[0];
		dad.y += dad.positionArray[1];
	}
	function repositionBoyfriend()
	{
		boyfriend.setPosition(stageJson.boyfriend[0], stageJson.boyfriend[1]);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
	}
	
	public function drawDebugOnCamera(spr:FlxSprite):Void
	{
		if (spr == null || !spr.isOnScreen(FlxG.camera))
			return;

		@:privateAccess
		var lineSize:Int = Std.int(Math.max(2, Math.floor(3 / FlxG.camera.zoom)));

		var sprX:Float = spr.x - spr.offset.x;
		var sprY:Float = spr.y - spr.offset.y;
		var sprWidth:Int = Std.int(spr.frameWidth * spr.scale.x);
		var sprHeight:Int = Std.int(spr.frameHeight * spr.scale.y);
		for (num => sel in selectionSprites.members)
		{
			sel.x = sprX;
			sel.y = sprY;
			switch(num)
			{
				case 0: //Top
					sel.setGraphicSize(sprWidth, lineSize);
				case 1: //Bottom
					sel.setGraphicSize(sprWidth, lineSize);
					sel.y += sprHeight - lineSize;
				case 2: //Left
					sel.setGraphicSize(lineSize, sprHeight);
				case 3: //Right
					sel.setGraphicSize(lineSize, sprHeight);
					sel.x += sprWidth - lineSize;
			}
			sel.updateHitbox();
			sel.scrollFactor.set(spr.scrollFactor.x, spr.scrollFactor.y);
		}
		selectionSprites.draw();
	}

	// save

	function highestCharacterIndex():Int
	{
		var found:Int = -1;
		for (i in 0...stageSprites.length)
		{
			var spr = stageSprites[i];
			if(spr == null) continue;
			if(spr.type == 'gf' || spr.type == 'dad' || spr.type == 'boyfriend') found = i;
		}
		return found;
	}

	function saveObjectsToJson()
	{
		var objectsArray:Array<Dynamic> = [];
		var charIndex:Int = highestCharacterIndex();
		for (index => spr in stageSprites)
		{
			if(spr == null) continue;

			var isForeground:Bool = index > charIndex;

			objectsArray.push(spr.formatToJson(isForeground));
		}
		
		var cleanJson:Dynamic = {
			directory: stageJson.directory,
			defaultZoom: stageJson.defaultZoom,
			stageUI: stageJson.stageUI,
			
			boyfriend: stageJson.boyfriend,
			girlfriend: stageJson.girlfriend,
			opponent: stageJson.opponent,
			hide_girlfriend: hideGirlfriendCheckbox.checked,
			
			camera_boyfriend: stageJson.camera_boyfriend,
			camera_opponent: stageJson.camera_opponent,
			camera_girlfriend: stageJson.camera_girlfriend,
			camera_speed: stageJson.camera_speed
		};
		
		if(stageJson.isPixelStage != null)
			cleanJson.isPixelStage = stageJson.isPixelStage;
		
		if(hideBoyfriendCheckbox.checked)
			cleanJson.hide_boyfriend = true;
		
		if(hideDadCheckbox.checked)
			cleanJson.hide_opponent = true;
		
		if(stageJson.preload != null)
			cleanJson.preload = stageJson.preload;

		cleanJson.objects = objectsArray;

		if(stageJson._editorMeta != null)
			cleanJson._editorMeta = stageJson._editorMeta;

		stageJson = cleanJson;
	}

	var scriptFormat:String = 'lua';
	function askScriptFormat()
	{
		if(_file != null || _fileLua != null) return;

		openSubState(new BasePrompt(520, 200, 'What format would you like to save "$lastLoadedStage"?', function(state:BasePrompt)
		{
			var btnY:Int = 390;

			var luaBtn:PsychUIButton = new PsychUIButton(0, btnY, 'Lua', function() {
				scriptFormat = 'lua';
				state.close();
				saveData();
			});
			luaBtn.normalStyle.bgColor = FlxColor.BLUE;
			luaBtn.normalStyle.textColor = FlxColor.WHITE;
			luaBtn.screenCenter(X);
			luaBtn.x -= 100;
			luaBtn.cameras = state.cameras;
			state.add(luaBtn);

			var hxBtn:PsychUIButton = new PsychUIButton(0, btnY, 'HScript', function() {
				scriptFormat = 'hx';
				state.close();
				saveData();
			});
			hxBtn.normalStyle.bgColor = FlxColor.BLUE;
			hxBtn.normalStyle.textColor = FlxColor.WHITE;
			hxBtn.screenCenter(X);
			hxBtn.x += 100;
			hxBtn.cameras = state.cameras;
			state.add(hxBtn);
		}));
	}

	function saveData()
	{
		if(_file != null) return;

		saveObjectsToJson();

		var orderedJson:String = haxe.format.JsonPrinter.print(stageJson, null, '\t');
		
		if (orderedJson.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(orderedJson, '$lastLoadedStage.json');
		}
	}

	function saveLuaScript()
	{
		if(_fileLua != null) return;

		var isHx:Bool = (scriptFormat == 'hx');
		var scriptCode:String = isHx ? generateHScript() : generateLuaScript();
		if (scriptCode.length > 0)
		{
			_fileLua = new FileReference();
			_fileLua.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveLuaComplete);
			_fileLua.addEventListener(Event.CANCEL, onSaveLuaCancel);
			_fileLua.addEventListener(IOErrorEvent.IO_ERROR, onSaveLuaError);
			_fileLua.save(scriptCode, lastLoadedStage + (isHx ? '.hx' : '.lua'));
		}
	}

	function generateLuaScript():String
	{
		var lua:String = 'function onCreate()\n';
		var charIndex:Int = highestCharacterIndex();

		for (index => basic in stageSprites)
		{
			if (basic == null) continue;
			
			if (StageData.reservedNames.contains(basic.type)) continue;

			switch(basic.type)
			{
				case 'sprite':
					lua += "makeLuaSprite('" + basic.name + "', '" + basic.image + "', " + basic.x + ", " + basic.y + ")\n";
					
					if (basic.blend != null && basic.blend.length > 0)
						lua += "setBlendMode('" + basic.name + "', '" + basic.blend + "')\n";
					
					lua += "setScrollFactor('" + basic.name + "', " + basic.scroll[0] + ", " + basic.scroll[1] + ")\n";
					lua += "scaleObject('" + basic.name + "', " + basic.scale[0] + ", " + basic.scale[1] + ")\n";
					
					if (basic.alpha != 1)
						lua += "setProperty('" + basic.name + ".alpha', " + basic.alpha + ")\n";
					
					if (basic.angle != 0)
						lua += "setProperty('" + basic.name + ".angle', " + basic.angle + ")\n";
					
					if (basic.color != 'FFFFFF')
					{
						var colorVal = Std.parseInt('0x' + basic.color);
						lua += "setProperty('" + basic.name + ".color', getColorFromHex('" + basic.color + "'))\n";
					}
					
					if (basic.flipX)
						lua += "setProperty('" + basic.name + ".flipX', true)\n";
					
					if (basic.flipY)
						lua += "setProperty('" + basic.name + ".flipY', true)\n";
					
					lua += "setProperty('" + basic.name + ".antialiasing', " + (basic.antialiasing ? 'true' : 'false') + ")\n";
					
					var isForeground:Bool = index > charIndex;

					lua += "addLuaSprite('" + basic.name + "', " + (isForeground ? 'true' : 'false') + ")\n\n";

				case 'animatedSprite':
					var animPrefix:String = 'idle';
					if(basic.sprite.animation.curAnim != null && basic.sprite.animation.curAnim.numFrames > 0)
					{
						var frameName = basic.sprite.animation.curAnim.name;
						var detectedPrefix:String = '';
						
						if(basic.sprite.frames != null && basic.sprite.frames.frames.length > 0)
						{
							frameName = basic.sprite.frames.frames[0].name;
							for(i in 0...frameName.length)
							{
								var char = frameName.charAt(i);
								if(char >= '0' && char <= '9')
									break;
								detectedPrefix += char;
							}
							if(detectedPrefix.length > 0)
								animPrefix = detectedPrefix;
						}
					}
					
					lua += "makeAnimatedLuaSprite('" + basic.name + "', '" + basic.image + "', " + basic.x + ", " + basic.y + ")\n";

					if(basic.animations != null && basic.animations.length > 0)
					{
						for (anim in basic.animations)
						{
							if(anim == null || anim.anim == null) continue;

							if(anim.indices != null && anim.indices.length > 0)
								lua += "addAnimationByIndices('" + basic.name + "', '" + anim.anim + "', '" + anim.name + "', '" + anim.indices.join(',') + "', " + anim.fps + ", " + (anim.loop ? 'true' : 'false') + ")\n";
							else
								lua += "addAnimationByPrefix('" + basic.name + "', '" + anim.anim + "', '" + anim.name + "', " + anim.fps + ", " + (anim.loop ? 'true' : 'false') + ")\n";

							if(anim.offsets != null && anim.offsets.length > 1 && (anim.offsets[0] != 0 || anim.offsets[1] != 0))
								lua += "addOffset('" + basic.name + "', '" + anim.anim + "', " + anim.offsets[0] + ", " + anim.offsets[1] + ")\n";
						}

						var firstAnim:String = (basic.firstAnimation != null) ? basic.firstAnimation : basic.animations[0].anim;
						lua += "playAnim('" + basic.name + "', '" + firstAnim + "', true)\n";
					}
					else
						lua += "addAnimationByPrefix('" + basic.name + "', 'idle', '" + animPrefix + "', " + basic.animFps + ", " + (basic.animLoop ? 'true' : 'false') + ")\n";
					
					if (basic.blend != null && basic.blend.length > 0)
						lua += "setBlendMode('" + basic.name + "', '" + basic.blend + "')\n";

					lua += "setScrollFactor('" + basic.name + "', " + basic.scroll[0] + ", " + basic.scroll[1] + ")\n";
					lua += "scaleObject('" + basic.name + "', " + basic.scale[0] + ", " + basic.scale[1] + ")\n";

					if (basic.alpha != 1)
						lua += "setProperty('" + basic.name + ".alpha', " + basic.alpha + ")\n";
					
					if (basic.angle != 0)
						lua += "setProperty('" + basic.name + ".angle', " + basic.angle + ")\n";
					
					if (basic.color != 'FFFFFF')
					{
						var colorVal = Std.parseInt('0x' + basic.color);
						lua += "setProperty('" + basic.name + ".color', getColorFromHex('" + basic.color + "'))\n";
					}
					
					if (basic.flipX)
						lua += "setProperty('" + basic.name + ".flipX', true)\n";
					
					if (basic.flipY)
						lua += "setProperty('" + basic.name + ".flipY', true)\n";
					
					lua += "setProperty('" + basic.name + ".antialiasing', " + (basic.antialiasing ? 'true' : 'false') + ")\n";
					
					var isForeground:Bool = index > charIndex;

					lua += "addLuaSprite('" + basic.name + "', " + (isForeground ? 'true' : 'false') + ")\n\n";

				case 'square':
					lua += "makeLuaSprite('" + basic.name + "', nil, " + basic.x + ", " + basic.y + ")\n";
					lua += "makeGraphic('" + basic.name + "', " + Std.int(basic.scale[0]) + ", " + Std.int(basic.scale[1]) + ", '" + basic.color + "')\n";
					
					if (basic.blend != null && basic.blend.length > 0)
						lua += "setBlendMode('" + basic.name + "', '" + basic.blend + "')\n";
					
					lua += "setScrollFactor('" + basic.name + "', " + basic.scroll[0] + ", " + basic.scroll[1] + ")\n";
					
					if (basic.alpha != 1)
						lua += "setProperty('" + basic.name + ".alpha', " + basic.alpha + ")\n";
					
					if (basic.angle != 0)
						lua += "setProperty('" + basic.name + ".angle', " + basic.angle + ")\n";
					
					var isForeground:Bool = index > charIndex;

					lua += "addLuaSprite('" + basic.name + "', " + (isForeground ? 'true' : 'false') + ")\n\n";
			}
		}

		if (hideDadCheckbox.checked)
			lua += "setProperty('dad.alpha', 0)\n";
		
		if (hideBoyfriendCheckbox.checked)
			lua += "setProperty('boyfriend.alpha', 0)\n";
		
		if (hideGirlfriendCheckbox.checked)
			lua += "setProperty('gf.alpha', 0)\n";

		lua += 'end';
		return lua;
	}

	function hxVarName(name:String):String
	{
		var out:String = ~/[^a-zA-Z0-9_]/g.replace(name, '_');
		if(out.length < 1) return 'obj';

		var first:String = out.charAt(0);
		if(first >= '0' && first <= '9') out = '_' + out;
		return out;
	}

	function generateHScript():String
	{
		var usesBlend:Bool = false;
		for (basic in stageSprites)
		{
			if(basic == null || StageData.reservedNames.contains(basic.type)) continue;
			if(basic.blend != null && basic.blend.length > 0)
			{
				usesBlend = true;
				break;
			}
		}

		var hx:String = '';
		if(usesBlend) hx += "import openfl.display.BlendMode;\n\n";
		hx += "function onCreate()\n{\n";

		var usedNames:Map<String, Bool> = new Map<String, Bool>();
		var charIndex:Int = highestCharacterIndex();

		for (index => basic in stageSprites)
		{
			if (basic == null) continue;

			if (StageData.reservedNames.contains(basic.type)) continue;

			var v:String = hxVarName(basic.name);
			var dupe:Int = 1;
			while(usedNames.exists(v))
			{
				v = hxVarName(basic.name) + '_' + dupe;
				dupe++;
			}
			usedNames.set(v, true);

			switch(basic.type)
			{
				case 'sprite':
					hx += "\tvar " + v + " = new ModchartSprite(" + basic.x + ", " + basic.y + ");\n";
					hx += "\t" + v + ".loadGraphic(Paths.image('" + basic.image + "'));\n";

				case 'animatedSprite':
					var animPrefix:String = 'idle';
					if(basic.sprite.animation.curAnim != null && basic.sprite.animation.curAnim.numFrames > 0)
					{
						var frameName = basic.sprite.animation.curAnim.name;
						var detectedPrefix:String = '';

						if(basic.sprite.frames != null && basic.sprite.frames.frames.length > 0)
						{
							frameName = basic.sprite.frames.frames[0].name;
							for(i in 0...frameName.length)
							{
								var char = frameName.charAt(i);
								if(char >= '0' && char <= '9')
									break;
								detectedPrefix += char;
							}
							if(detectedPrefix.length > 0)
								animPrefix = detectedPrefix;
						}
					}

					hx += "\tvar " + v + " = new ModchartSprite(" + basic.x + ", " + basic.y + ");\n";
					hx += "\t" + v + ".frames = Paths.getSparrowAtlas('" + basic.image + "');\n";

					if(basic.animations != null && basic.animations.length > 0){
						for(anim in basic.animations){
							if(anim == null || anim.anim == null) continue;
							if (anim.indices != null && anim.indices.length > 0)
								hx += "\t" + v + ".animation.addByIndices('" + anim.anim + "', '" + anim.name + "', [" + anim.indices.join(', ') + "], '', " + anim.fps + ", " + (anim.loop ? 'true' : 'false') + ");\n";
							else
								hx += "\t" + v + ".animation.addByPrefix('" + anim.anim + "', '" + anim.name + "', " + anim.fps + ", " + (anim.loop ? 'true' : 'false') + ");\n";

							if (anim.offsets != null && anim.offsets.length > 1 && (anim.offsets[0] != 0 || anim.offsets[1] != 0))
								hx += "\t" + v + ".addOffset('" + anim.anim + "', " + anim.offsets[0] + ", " + anim.offsets[1] + ");\n";
						}
						var firstAnim:String = (basic.firstAnimation != null) ? basic.firstAnimation : basic.animations[0].anim;
						hx += "\t" + v + ".playAnim('" + firstAnim + "', true);\n";
					} 
					else{
						hx += "\t" + v + ".animation.addByPrefix('idle', '" + animPrefix + "', " + basic.animFps + ", " + (basic.animLoop ? 'true' : 'false') + ");\n";
						hx += "\t" + v + ".playAnim('idle', true);\n";
					}

				case 'square':
					hx += "\tvar " + v + " = new ModchartSprite(" + basic.x + ", " + basic.y + ");\n";
					hx += "\t" + v + ".makeGraphic(" + Std.int(basic.scale[0]) + ", " + Std.int(basic.scale[1]) + ", 0xFF" + basic.color + ");\n";

				default:
					continue;
			}

			if (basic.blend != null && basic.blend.length > 0)
				hx += "\t" + v + ".blend = BlendMode." + basic.blend.toUpperCase() + ";\n";

			hx += "\t" + v + ".scrollFactor.set(" + basic.scroll[0] + ", " + basic.scroll[1] + ");\n";

			if (basic.type != 'square')
			{
				hx += "\t" + v + ".scale.set(" + basic.scale[0] + ", " + basic.scale[1] + ");\n";
				hx += "\t" + v + ".updateHitbox();\n";
			}

			if (basic.alpha != 1)
				hx += "\t" + v + ".alpha = " + basic.alpha + ";\n";

			if (basic.angle != 0)
				hx += "\t" + v + ".angle = " + basic.angle + ";\n";

			if (basic.type != 'square' && basic.color != 'FFFFFF')
				hx += "\t" + v + ".color = 0xFF" + basic.color + ";\n";

			if (basic.flipX)
				hx += "\t" + v + ".flipX = true;\n";

			if (basic.flipY)
				hx += "\t" + v + ".flipY = true;\n";

			if (basic.type != 'square')
				hx += "\t" + v + ".antialiasing = " + (basic.antialiasing ? 'true' : 'false') + ";\n";

			var isForeground:Bool = index > charIndex;

			hx += "\tgame." + (isForeground ? "add" : "addBehindGF") + "(" + v + ");\n";
			hx += "\tsetVar('" + basic.name + "', " + v + ");\n\n";
		}

		if (hideDadCheckbox.checked)
			hx += "\tif(game.dad != null) game.dad.alpha = 0;\n";

		if (hideBoyfriendCheckbox.checked)
			hx += "\tif(game.boyfriend != null) game.boyfriend.alpha = 0;\n";

		if (hideGirlfriendCheckbox.checked)
			hx += "\tif(game.gf != null) game.gf.alpha = 0;\n";

		hx += "}";
		return hx;
	}

	var _file:FileReference;
	var _fileLua:FileReference;
	function onSaveComplete(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice('Successfully saved JSON file.');
		saveLuaScript();
	}

	function onSaveLuaComplete(_):Void
	{
		if(_fileLua == null) return;
		_fileLua.removeEventListener(Event.COMPLETE, onSaveLuaComplete);
		_fileLua.removeEventListener(Event.CANCEL, onSaveLuaCancel);
		_fileLua.removeEventListener(IOErrorEvent.IO_ERROR, onSaveLuaError);
		_fileLua = null;
		FlxG.log.notice('Successfully saved ' + (scriptFormat == 'hx' ? 'HScript' : 'Lua') + ' file.');
	}

	function onSaveLuaCancel(_):Void
	{
		if(_fileLua == null) return;
		_fileLua.removeEventListener(Event.COMPLETE, onSaveLuaComplete);
		_fileLua.removeEventListener(Event.CANCEL, onSaveLuaCancel);
		_fileLua.removeEventListener(IOErrorEvent.IO_ERROR, onSaveLuaError);
		_fileLua = null;
	}

	function onSaveLuaError(_):Void
	{
		if(_fileLua == null) return;
		_fileLua.removeEventListener(Event.COMPLETE, onSaveLuaComplete);
		_fileLua.removeEventListener(Event.CANCEL, onSaveLuaCancel);
		_fileLua.removeEventListener(IOErrorEvent.IO_ERROR, onSaveLuaError);
		_fileLua = null;
		FlxG.log.error('Problem saving Lua file');
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
	function onSaveCancel(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	function onSaveError(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error('Problem saving file');
	}

	var _makeNewSprite = null;
	public function loadImage(onNewSprite:String = null) {
		if(_file != null) return;

		_makeNewSprite = onNewSprite;
		_file = new FileReference();
		_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		final filters = [new FileFilter('PNG (Image)', '*.png'), new FileFilter('XML (Sparrow)', '*.xml'), new FileFilter('JSON (Aseprite)', '*.json'), new FileFilter('TXT (Packer)', '*.txt')];
		_file.browse(#if !mac filters #else [] #end);
	}
	
	private function onLoadComplete(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		#if sys
		var fullPath:String = null;
		@:privateAccess
		if(_file.__path != null) fullPath = _file.__path;

		function loadSprite(imageToLoad:String)
		{
			if(_makeNewSprite != null)
			{
				if(_makeNewSprite == 'animatedSprite' && !Paths.fileExists('images/$imageToLoad.xml', TEXT) &&
					!Paths.fileExists('images/$imageToLoad.json', TEXT) && !Paths.fileExists('images/$imageToLoad.txt', TEXT))
				{
					showOutput('No Animation file found with the same name of the image!', true);
					_makeNewSprite = null;
					_file = null;
					return;
				}
				var newMeta:StageEditorMetaSprite = new StageEditorMetaSprite({type: _makeNewSprite, name: findUnoccupiedName()}, new ModchartSprite());
				if(isPixelUI(stageJson.stageUI)) newMeta.antialiasing = false;
				insertMeta(newMeta);
			}

			var selected = getSelected();
			if(_makeNewSprite == null) pushAction();
			tryLoadImage(selected, imageToLoad);
			
			if(_makeNewSprite != null)
			{
				selected.sprite.x = Math.round(FlxG.camera.scroll.x + FlxG.width/2 - selected.sprite.width/2);
				selected.sprite.y = Math.round(FlxG.camera.scroll.y + FlxG.height/2 - selected.sprite.height/2);
				posTxt.visible = true;
				posTxt.text = 'X: ${selected.sprite.x}\nY: ${selected.sprite.y}';
			}
			_makeNewSprite = null;
		}
		_file = null;

		if(fullPath != null)
		{
			fullPath = fullPath.replace('\\', '/');
			var exePath = Sys.getCwd().replace('\\', '/');
			if(fullPath.startsWith(exePath))
			{
				fullPath = fullPath.substr(exePath.length);
				if((fullPath.startsWith('assets/') #if MODS_ALLOWED || fullPath.startsWith('mods/') #end) && fullPath.contains('/images/'))
				{
					loadSprite(fullPath.substring(fullPath.indexOf('/images/') + '/images/'.length, fullPath.lastIndexOf('.')));
					//trace('Inside Psych Engine Folder');
					return;
				}
			}

			createPopup.visible = createPopup.active = false;
			#if MODS_ALLOWED
			var modFolder:String = (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) ? Paths.mods('${Mods.currentModDirectory}/images/') : Paths.mods('images/');
			openSubState(new BasePrompt(480, 160, 'This file is not inside Psych Engine.', function(state:BasePrompt)
			{
				var txt:FlxText = new FlxText(0, state.bg.y + 60, 460, 'Copy to: "$modFolder"?', 11);
				txt.alignment = CENTER;
				txt.screenCenter(X);
				txt.cameras = state.cameras;
				state.add(txt);
				
				var btnY = 390;
				var btn:PsychUIButton = new PsychUIButton(0, btnY, 'OK', function() {
					var fileName:String = fullPath.substring(fullPath.lastIndexOf('/') + 1, fullPath.lastIndexOf('.'));
					var pathNoExt:String = fullPath.substring(0, fullPath.lastIndexOf('.'));
					function saveFile(ext:String)
					{
						var p1:String = '$pathNoExt.$ext';
						var p2:String = modFolder + '$fileName.$ext';
						trace(p1, p2);
						if(FileSystem.exists(p1))
							File.saveBytes(p2, File.getBytes(p1));
					}

					FileSystem.createDirectory(modFolder);
					saveFile('png');
					saveFile('xml');
					saveFile('txt');
					saveFile('json');
					loadSprite(fileName);
					state.close();
				});
				btn.normalStyle.bgColor = FlxColor.GREEN;
				btn.normalStyle.textColor = FlxColor.WHITE;
				btn.screenCenter(X);
				btn.x -= 100;
				btn.cameras = state.cameras;
				state.add(btn);

				var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Cancel', function()
				{
					_makeNewSprite = null;
					state.close();
				});
				btn.screenCenter(X);
				btn.x += 100;
				btn.cameras = state.cameras;
				state.add(btn);
			}));
			#else
			showOutput('ERROR! File cannot be used, move it to "assets" and recompile.', true);
			#end
		}
		_file = null;
		#else
		trace('File couldn\'t be loaded! You aren\'t on Desktop, are you?');
		#end
	}

	function tryLoadImage(spr:StageEditorMetaSprite, imgPath:String)
	{
		if(spr == null || StageData.reservedNames.contains(spr.type) || spr.type == 'square' || imgPath == null) return;

		spr.image = imgPath;
		if(spr.type == 'animatedSprite' && spr.sprite.animation.curAnim != null)
		{
			spr.sprite.animation.play(spr.sprite.animation.curAnim.name, true);
		}
		updateSelectedUI();
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
	private function onLoadCancel(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		
		if(_makeNewSprite != null)
		{
			createPopup.visible = createPopup.active = false;
			_makeNewSprite = null;
		}
		trace('Cancelled file loading.');
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	private function onLoadError(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;

		if(_makeNewSprite != null)
		{
			createPopup.visible = createPopup.active = false;
			_makeNewSprite = null;
		}
		trace('Problem loading file');
	}

	function loadLuaStageIfExists(stageName:String)
	{
		var luaPath:String = 'stages/$stageName.lua';
		var path:String = Paths.getPath(luaPath, TEXT, null, true);
		
		#if MODS_ALLOWED
		if (FileSystem.exists(path))
		{
			try
			{
				var luaContent:String = File.getContent(path);
				parseLuaToStageAdditive(luaContent);
			}
			catch(e:Dynamic)
			{
				trace('Could not load Lua file for stage: $e');
			}
		}
		#end
	}

	var _luaParsedNames:Array<String> = [];
	function parseLuaToStageAdditive(luaContent:String)
	{
		_luaParsedNames = [];
		var lines:Array<String> = luaContent.split('\n');
		var currentSprite:Dynamic = null;
		var spriteName:String = '';
		var isForeground:Bool = false;
		var backgroundSprites:Array<StageEditorMetaSprite> = [];
		var foregroundSprites:Array<StageEditorMetaSprite> = [];

		for (line in lines)
		{
			line = StringTools.trim(line);
			
			if (line.indexOf('makeLuaSprite(') != -1 || line.indexOf('makeAnimatedLuaSprite(') != -1)
			{
				if (currentSprite != null)
				{
					var meta:StageEditorMetaSprite = createMetaFromLuaObject(currentSprite, spriteName, isForeground);
					if (meta != null)
					{
						if (isForeground)
							foregroundSprites.push(meta);
						else
							backgroundSprites.push(meta);
					}
				}

				var isAnimated = line.indexOf('makeAnimatedLuaSprite(') != -1;
				var params = extractLuaParams(line);
				if (params.length >= 4)
				{
					spriteName = params[0];
					var imagePath = params[1];
					var xPos = Std.parseFloat(params[2]);
					var yPos = Std.parseFloat(params[3]);

					currentSprite = {
						name: spriteName,
						image: imagePath,
						x: xPos,
						y: yPos,
						scale: [1.0, 1.0],
						scroll: [1.0, 1.0],
						alpha: 1.0,
						angle: 0.0,
						color: 'FFFFFF',
						antialiasing: true,
						flipX: false,
						flipY: false,
						filters: (LOW_QUALITY)|(HIGH_QUALITY),
						type: isAnimated ? 'animatedSprite' : ((imagePath == 'nil' || imagePath == 'null' || imagePath == '') ? 'square' : 'sprite'),
						animFps: 24,
						animLoop: true,
						blend: ''
					};
				}
			}
			else if (currentSprite != null)
			{
				if (line.indexOf('addAnimationByPrefix(') != -1)
				{
					var params = extractLuaParams(line);
					if (params.length >= 5)
					{
						currentSprite.animFps = Std.parseInt(params[3]);
						currentSprite.animLoop = (params[4] == 'true');
					}
				}
				else if (line.indexOf('setBlendMode(') != -1)
				{
					var params = extractLuaParams(line);
					if (params.length >= 2)
					{
						currentSprite.blend = params[1];
					}
				}
				else if (line.indexOf('scaleObject(') != -1)
				{
					var params = extractLuaParams(line);
					if (params.length >= 3)
					{
						currentSprite.scale = [Std.parseFloat(params[1]), Std.parseFloat(params[2])];
					}
				}
				else if (line.indexOf('setScrollFactor(') != -1)
				{
					var params = extractLuaParams(line);
					if (params.length >= 3)
					{
						currentSprite.scroll = [Std.parseFloat(params[1]), Std.parseFloat(params[2])];
					}
				}
				else if (line.indexOf('.alpha') != -1)
				{
					var value = extractPropertyValue(line);
					if (value != null) currentSprite.alpha = Std.parseFloat(value);
				}
				else if (line.indexOf('.angle') != -1)
				{
					var value = extractPropertyValue(line);
					if (value != null) currentSprite.angle = Std.parseFloat(value);
				}
				else if (line.indexOf('.color') != -1 || line.indexOf('getColorFromHex(') != -1)
				{
					var colorMatch = ~/'([0-9A-Fa-f]{6})'/;
					if (colorMatch.match(line))
					{
						currentSprite.color = colorMatch.matched(1);
					}
				}
				else if (line.indexOf('.flipX') != -1)
				{
					currentSprite.flipX = line.indexOf('true') != -1;
				}
				else if (line.indexOf('.flipY') != -1)
				{
					currentSprite.flipY = line.indexOf('true') != -1;
				}
				else if (line.indexOf('.antialiasing') != -1)
				{
					currentSprite.antialiasing = line.indexOf('true') != -1;
				}
				else if (line.indexOf('makeGraphic(') != -1)
				{
					var params = extractLuaParams(line);
					if (params.length >= 4)
					{
						currentSprite.scale = [Std.parseFloat(params[1]), Std.parseFloat(params[2])];
						currentSprite.color = params[3];
						currentSprite.type = 'square';
					}
				}
				else if (line.indexOf('addLuaSprite(') != -1)
				{
					isForeground = line.indexOf('true') != -1;
					
					var meta:StageEditorMetaSprite = createMetaFromLuaObject(currentSprite, spriteName, isForeground);
					if (meta != null)
					{
						if (isForeground)
							foregroundSprites.push(meta);
						else
							backgroundSprites.push(meta);
					}
					
					currentSprite = null;
					spriteName = '';
					isForeground = false;
				}
			}
		}

		if (currentSprite != null)
		{
			var meta:StageEditorMetaSprite = createMetaFromLuaObject(currentSprite, spriteName, isForeground);
			if (meta != null)
			{
				if (isForeground)
					foregroundSprites.push(meta);
				else
					backgroundSprites.push(meta);
			}
		}

		var gfIndex:Int = -1;
		var dadIndex:Int = -1;
		var bfIndex:Int = -1;
		
		for (i in 0...stageSprites.length)
		{
			if (stageSprites[i].type == 'gf') gfIndex = i;
			else if (stageSprites[i].type == 'dad') dadIndex = i;
			else if (stageSprites[i].type == 'boyfriend') bfIndex = i;
		}
		
		var lowestCharIndex:Int = Math.floor(Math.min(gfIndex, Math.min(dadIndex, bfIndex)));
		if (lowestCharIndex == -1) lowestCharIndex = 0;
		
		backgroundSprites.reverse();
		for (spr in backgroundSprites)
			stageSprites.insert(lowestCharIndex, spr);
		
		var highestCharIndex:Int = -1;
		for (i in 0...stageSprites.length)
		{
			if (stageSprites[i].type == 'gf') highestCharIndex = Math.floor(Math.max(highestCharIndex, i));
			else if (stageSprites[i].type == 'dad') highestCharIndex = Math.floor(Math.max(highestCharIndex, i));
			else if (stageSprites[i].type == 'boyfriend') highestCharIndex = Math.floor(Math.max(highestCharIndex, i));
		}
		if (highestCharIndex == -1) highestCharIndex = stageSprites.length - 1;
		
		for (spr in foregroundSprites)
			stageSprites.insert(highestCharIndex + 1, spr);
	}

	function extractLuaParams(line:String):Array<String>
	{
		var startIdx = line.indexOf('(');
		var endIdx = line.lastIndexOf(')');
		if (startIdx == -1 || endIdx == -1) return [];

		var paramsStr = line.substring(startIdx + 1, endIdx);
		var params:Array<String> = [];
		var quoteChar = '';
		var currentParam = '';

		for (i in 0...paramsStr.length)
		{
			var char = paramsStr.charAt(i);

			if (quoteChar == '' && (char == "'" || char == '"'))
			{
				quoteChar = char;
			}
			else if (quoteChar == char)
			{
				quoteChar = '';
			}
			else if (char == ',' && quoteChar == '')
			{
				params.push(StringTools.trim(currentParam));
				currentParam = '';
			}
			else
			{
				currentParam += char;
			}
		}

		if (currentParam.length > 0)
			params.push(StringTools.trim(currentParam));

		return params;
	}

	function extractPropertyValue(line:String):String
	{
		var parts = line.split(',');
		if (parts.length < 2) return null;
		
		var value = StringTools.trim(parts[1].split(')')[0]);
		return value;
	}

	function createMetaFromLuaObject(luaObj:Dynamic, name:String, isForeground:Bool):StageEditorMetaSprite
	{
		if (luaObj == null) return null;
		if (nameExists(name) || _luaParsedNames.contains(name)) return null;
		_luaParsedNames.push(name);

		var spr:ModchartSprite = new ModchartSprite();
		var meta:StageEditorMetaSprite = new StageEditorMetaSprite(null, spr);

		meta.name = name;
		meta.type = luaObj.type;
		meta.x = luaObj.x;
		meta.y = luaObj.y;
		meta.scale = luaObj.scale;
		meta.scroll = luaObj.scroll;
		meta.alpha = luaObj.alpha;
		meta.angle = luaObj.angle;
		meta.color = luaObj.color;
		meta.antialiasing = luaObj.antialiasing;
		meta.flipX = luaObj.flipX;
		meta.flipY = luaObj.flipY;
		meta.filters = luaObj.filters;
		
		if(luaObj.blend != null)
			meta.blend = luaObj.blend;

			meta.applyOwnBlendMode();
		
		if(luaObj.type == 'animatedSprite')
		{
			if(luaObj.animFps != null) meta.animFps = luaObj.animFps;
			if(luaObj.animLoop != null) meta.animLoop = luaObj.animLoop;
		}

		if (luaObj.type == 'square')
		{
			spr.makeGraphic(1, 1, CoolUtil.colorFromString(luaObj.color));
			spr.scale.set(luaObj.scale[0], luaObj.scale[1]);
			spr.updateHitbox();
		}
		else if (luaObj.image != null && luaObj.image.length > 0)
		{
			try
			{
				if(luaObj.type == 'animatedSprite')
				{
					spr.frames = Paths.getAtlas(luaObj.image);
					meta.image = luaObj.image;
					meta.autoDetectAndPlayAnimation();
				}
				else
				{
					spr.loadGraphic(Paths.image(luaObj.image));
					meta.image = luaObj.image;
				}
				spr.scale.set(meta.scale[0], meta.scale[1]);
				spr.updateHitbox();
			}
			catch(e:Dynamic)
			{
				showOutput('Could not load image: ${luaObj.image}', true);
			}
		}

		spr.setPosition(meta.x, meta.y);
		spr.scrollFactor.set(meta.scroll[0], meta.scroll[1]);
		spr.alpha = meta.alpha;
		spr.angle = meta.angle;
		spr.color = CoolUtil.colorFromString(meta.color);
		spr.flipX = meta.flipX;
		spr.flipY = meta.flipY;
		spr.antialiasing = meta.antialiasing && ClientPrefs.data.antialiasing;

		return meta;
	}

	override function destroy()
	{
		destroySubStates = true;
		if(animationEditor != null) animationEditor.destroy();
		super.destroy();
	}
}

class StageEditorMetaSprite
{
	public var sprite:FlxSprite;
	public var visible(get, set):Bool;
	function get_visible() return sprite.visible;
	function set_visible(v:Bool) return (sprite.visible = v);

	// basic variables for all types
	public var type:String;

	// variables for all types that aren't Character
	public var name:String;
	public var filters:LoadFilters = (LOW_QUALITY)|(HIGH_QUALITY);
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var alpha(get, set):Float;
	public var angle(get, set):Float;
	function get_x() return sprite.x;
	function set_x(v:Float) return (sprite.x = v);
	function get_y() return sprite.y;
	function set_y(v:Float) return (sprite.y = v);
	function get_alpha() return sprite.alpha;
	function set_alpha(v:Float) return (sprite.alpha = v);
	function get_angle() return sprite.angle;
	function set_angle(v:Float) return (sprite.angle = v);

	public var color(default, set):String = 'FFFFFF';
	function set_color(v:String)
	{
		sprite.color = CoolUtil.colorFromString(v);
		return (color = v);
	}
	public var image(default, set):String = 'unknown';
	function set_image(v:String)
	{
		try
		{
			switch(type)
			{
				case 'sprite':
					sprite.loadGraphic(Paths.image(v));
				case 'animatedSprite':
					sprite.frames = Paths.getAtlas(v);
					autoDetectAndPlayAnimation();
			}
		}
		catch (e:Dynamic) {}
		sprite.updateHitbox();
		return (image = v);
	}

	public var scroll:Array<Float> = [1, 1];
	public function setScrollFactor(scrX:Null<Float> = null, scrY:Null<Float> = null)
	{
		scroll[0] = (scrX != null ? scrX : scroll[0]);
		scroll[1] = (scrY != null ? scrY : scroll[1]);
		sprite.scrollFactor.set(scroll[0], scroll[1]);
	}

	public var scale:Array<Float> = [1, 1];
	public var antialiasing(default, set):Bool = true;
	function set_antialiasing(v:Bool)
	{
		sprite.antialiasing = (v && ClientPrefs.data.antialiasing);
		return (antialiasing = v);
	}

	public var blend:String = '';

	public function setScale(wid:Null<Float> = null, hei:Null<Float> = null)
	{
		scale[0] = (wid != null ? wid : scale[0]);
		scale[1] = (hei != null ? hei : scale[1]);
		sprite.scale.set(scale[0], scale[1]);
		sprite.updateHitbox();
	}
	
	public var flipX(get, set):Bool;
	public var flipY(get, set):Bool;
	function get_flipX() return sprite.flipX;
	function set_flipX(v:Bool) return (sprite.flipX = (v && type != 'square'));
	function get_flipY() return sprite.flipY;
	function set_flipY(v:Bool) return (sprite.flipY = (v && type != 'square'));

	// "animatedSprite" only variables
	public var firstAnimation:String;
	public var animations:Array<AnimArray>;
	public var animFps:Int = 24;
	public var animLoop:Bool = true;

	public function new(data:Dynamic, spr:FlxSprite)
	{
		this.sprite = spr;
		if(data == null) return;

		this.type = data.type;
		switch(this.type)
		{
			case 'sprite', 'square', 'animatedSprite':
				for (v in ['name', 'image', 'scale', 'scroll', 'color', 'filters', 'antialiasing', 'blend'])
				{
					var dat:Dynamic = Reflect.field(data, v);
					if(dat != null) Reflect.setField(this, v, dat);
				}

				if(this.type == 'animatedSprite')
				{
					this.animations = data.animations;
					this.firstAnimation = data.firstAnimation;
					if(data.animFps != null) this.animFps = data.animFps;
					if(data.animLoop != null) this.animLoop = data.animLoop;
					autoDetectAndPlayAnimation();
				}
				
				applyOwnBlendMode();
		}
	}

	public function applyOwnBlendMode()
	{
		if(sprite == null) return;
		
		var blendMode:BlendMode = BlendMode.NORMAL;
		switch(blend)
		{
			case 'add': blendMode = BlendMode.ADD;
			case 'alpha': blendMode = BlendMode.ALPHA;
			case 'darken': blendMode = BlendMode.DARKEN;
			case 'difference': blendMode = BlendMode.DIFFERENCE;
			case 'erase': blendMode = BlendMode.ERASE;
			case 'hardlight': blendMode = BlendMode.HARDLIGHT;
			case 'invert': blendMode = BlendMode.INVERT;
			case 'layer': blendMode = BlendMode.LAYER;
			case 'lighten': blendMode = BlendMode.LIGHTEN;
			case 'multiply': blendMode = BlendMode.MULTIPLY;
			case 'overlay': blendMode = BlendMode.OVERLAY;
			case 'screen': blendMode = BlendMode.SCREEN;
			case 'shader': blendMode = BlendMode.SHADER;
			case 'subtract': blendMode = BlendMode.SUBTRACT;
			default: blendMode = BlendMode.NORMAL;
		}
		sprite.blend = blendMode;
	}

	public function autoDetectAndPlayAnimation()
	{
		if(type != 'animatedSprite' || sprite.frames == null) return;

		var frameNames:Array<String> = [];
		for(frame in sprite.frames.frames)
			frameNames.push(frame.name);

		if(frameNames.length == 0) return;

		var detectedPrefix:String = null;
		var prefixCounts:Map<String, Int> = new Map();

		for(frameName in frameNames)
		{
			var prefix:String = '';
			var numberPart:String = '';
			var foundNumber:Bool = false;

			for(i in 0...frameName.length)
			{
				var char = frameName.charAt(i);
				if(char >= '0' && char <= '9')
				{
					foundNumber = true;
					numberPart += char;
				}
				else if(!foundNumber)
				{
					prefix += char;
				}
			}

			if(prefix.length > 0)
			{
				if(!prefixCounts.exists(prefix))
					prefixCounts.set(prefix, 0);
				prefixCounts.set(prefix, prefixCounts.get(prefix) + 1);
			}
		}

		var maxCount:Int = 0;
		for(prefix in prefixCounts.keys())
		{
			var count = prefixCounts.get(prefix);
			if(count > maxCount)
			{
				maxCount = count;
				detectedPrefix = prefix;
			}
		}

		if(detectedPrefix != null)
		{
			sprite.animation.addByPrefix('idle', detectedPrefix, animFps, animLoop);
			if(sprite.animation.exists('idle')){
				if(animations == null) animations = [];
				animations.push({
					anim: 'idle',
					name: detectedPrefix,
					fps: animFps,
					loop: animLoop,
					indices: [],
					offsets: [0,0]
				});
				if(firstAnimation == null) firstAnimation = 'idle';
				sprite.animation.play('idle', true);
			}
		}
	}

	public function formatToJson(isForeground:Bool = false)
	{
		var obj:Dynamic = {type: type};
		switch(type)
		{
			case 'square', 'sprite', 'animatedSprite':
				obj.name = name;
				obj.x = x;
				obj.y = y;
				obj.scale = scale;
				obj.scroll = scroll;
				obj.alpha = alpha;
				obj.angle = angle;
				obj.color = color;
				obj.filters = filters;
				obj.addLuaSprite = isForeground;

				if(type != 'square')
				{
					obj.flipX = flipX;
				obj.flipY = flipY;
				obj.image = image;
				obj.antialiasing = antialiasing;
				if(blend != null && blend.length > 0)
					obj.blend = blend;
				if(type == 'animatedSprite')
				{
					obj.animations = animations;
					obj.firstAnimation = firstAnimation;
					obj.animFps = animFps;
					obj.animLoop = animLoop;
				}
				}
		}
		return obj;
	}

	public function update(curFilters:LoadFilters, elapsed:Float)
	{
		if((curFilters & filters) != 0 || StageData.reservedNames.contains(type))
			sprite.update(elapsed);
	}

	public function draw(curFilters:LoadFilters)
	{
		if((curFilters & filters) != 0 || StageData.reservedNames.contains(type))
			sprite.draw();
	}
}

class StageEditorAnimationSubstate extends MusicBeatSubstate {
	var bg:FlxSprite;
	var originalZoom:Float;
	var originalCamPoint:FlxPoint;
	var originalPosition:FlxPoint;
	var originalCamTarget:FlxObject;
	var originalAlpha:Float = 1;
	public var target:StageEditorMetaSprite;
	
	var curAnim:Int = 0;
	var outputTxt:FlxText;
	var outputTime:Float = 0;
	var animsTxtGroup:FlxTypedGroup<FlxText>;

	var UI_animationbox:PsychUIBox;
	var camHUD:FlxCamera = cast(FlxG.state, StageEditorState).camHUD;
	var parentState:StageEditorState = cast(FlxG.state, StageEditorState); 
	var camDragging:Bool = false;
	public function new()
	{
		super();

		var grid:FlxBackdrop = new FlxBackdrop(FlxGridOverlay.createGrid(50, 50, 100, 100, true, 0xFFAAAAAA, 0xFF666666));
		add(grid);
		
		animsTxtGroup = new FlxTypedGroup<FlxText>();
		animsTxtGroup.cameras = [camHUD];
		add(animsTxtGroup);
		
		UI_animationbox = new PsychUIBox(FlxG.width - 320, 20, 300, 250, ['Animations']);
		UI_animationbox.cameras = [camHUD];
		UI_animationbox.scrollFactor.set();
		add(UI_animationbox);
		addAnimationsUI();

		outputTxt = new FlxText(0, 0, 800, '', 24);
		outputTxt.alignment = CENTER;
		outputTxt.borderStyle = OUTLINE_FAST;
		outputTxt.borderSize = 1;
		outputTxt.cameras = [camHUD];
		outputTxt.screenCenter();
		outputTxt.alpha = 0;
		add(outputTxt);

		openCallback = function()
		{
			PsychUIInputText.focusOn = null;
			PsychUIInputText.blockFocusOnClick = false;
			curAnim = 0;
			originalZoom = FlxG.camera.zoom;
			originalCamPoint = FlxPoint.weak(FlxG.camera.scroll.x, FlxG.camera.scroll.y);
			originalPosition = FlxPoint.weak(target.x, target.y);
			originalCamTarget = FlxG.camera.target;
			originalAlpha = target.alpha;
			FlxG.camera.zoom = 0.5;
			FlxG.camera.scroll.set(0, 0);
			FlxG.camera.target = null;

			target.alpha = 1;
			add(target.sprite);
			reloadAnimList();
			centerTargetOnFrame();
			trace('Opened substate');
		};

		closeCallback = function()
		{
			PsychUIInputText.focusOn = null;
			PsychUIInputText.blockFocusOnClick = false;
			FlxG.camera.zoom = originalZoom;
			FlxG.camera.scroll.set(originalCamPoint.x, originalCamPoint.y);
			FlxG.camera.target = originalCamTarget;

			target.x = originalPosition.x;
			target.y = originalPosition.y;
			target.alpha = originalAlpha;
			remove(target.sprite);

			if(target.animations.length > 0)
			{
				if(target.firstAnimation == null) target.firstAnimation = target.animations[0].anim;
				playAnim(target.firstAnimation);
			}
		};
	}

	function centerTargetOnFrame(){
		var spr:FlxSprite = target.sprite;
		if(spr == null) return;

		var f = spr.frame;
		if(f == null){
			spr.screenCenter(); return;
		}

		var fw:Float = f.frame.width;
		var fh:Float = f.frame.height;
		if(f.angle != 0){
			var tmp:Float = fw;
			fw = fh; fh = tmp;
		}

		var localX:Float = f.offset.x + fw/2;
		var localY:Float = f.offset.y + fh/2;

		spr.x = FlxG.camera.scroll.x + FlxG.width / 2 + spr.offset.x - spr.origin.x - (localX - spr.origin.x) * spr.scale.x;
		spr.y = FlxG.camera.scroll.y + FlxG.height / 2 + spr.offset.y - spr.origin.y - (localY - spr.origin.y) * spr.scale.y;
	}

	var animationDropDown:PsychUIDropDownMenu;
	var animationInputText:PsychUIInputText;
	var animationNameInputText:PsychUIInputText;
	var animationIndicesInputText:PsychUIInputText;
	var animationFramerate:PsychUINumericStepper;
	var animationLoopCheckBox:PsychUICheckBox;
	var mainAnimTxt:FlxText;
	function addAnimationsUI()
	{
		var tab_group = UI_animationbox.getTab('Animations').menu;

		animationInputText = new PsychUIInputText(15, 85, 80, '', 8);
		animationNameInputText = new PsychUIInputText(animationInputText.x, animationInputText.y + 35, 150, '', 8);
		animationIndicesInputText = new PsychUIInputText(animationNameInputText.x, animationNameInputText.y + 40, 250, '', 8);
		animationFramerate = new PsychUINumericStepper(animationInputText.x + 170, animationInputText.y, 1, 24, 0, 240, 0);
		animationLoopCheckBox = new PsychUICheckBox(animationNameInputText.x + 170, animationNameInputText.y - 1, 'Should it Loop?', 100);

		animationDropDown = new PsychUIDropDownMenu(15, animationInputText.y - 55, [''], function(selectedAnimation:Int, pressed:String) {
			var anim:AnimArray = target.animations[selectedAnimation];
			if(anim == null) return;

			animationInputText.text = anim.anim;
			animationNameInputText.text = anim.name;
			animationLoopCheckBox.checked = anim.loop;
			animationFramerate.value = anim.fps;

			var indicesStr:String = anim.indices.toString();
			animationIndicesInputText.text = indicesStr.substr(1, indicesStr.length - 2);
		});

		mainAnimTxt = new FlxText(160, animationDropDown.y - 18, 0, 'Main Anim.: ');
		var initAnimButton:PsychUIButton = new PsychUIButton(160, animationDropDown.y, 'Main Animation', function() {
			var anim:AnimArray = target.animations[curAnim];
			if(anim == null) return;

			mainAnimTxt.text = 'Main Anim.: ${anim.anim}';
			target.firstAnimation = anim.anim;
		});
		tab_group.add(mainAnimTxt);
		tab_group.add(initAnimButton);

		var addUpdateButton:PsychUIButton = new PsychUIButton(40, animationIndicesInputText.y + 35, 'Add/Update', function() {
			if(animationInputText.text == '') return;

			var indices:Array<Int> = [];
			var indicesStr:Array<String> = animationIndicesInputText.text.trim().split(',');
			if(indicesStr.length > 1) {
				for (i in 0...indicesStr.length) {
					var index:Int = Std.parseInt(indicesStr[i]);
					if(indicesStr[i] != null && indicesStr[i] != '' && !Math.isNaN(index) && index > -1) {
						indices.push(index);
					}
				}
			}

			var lastAnim:String = (target.animations[curAnim] != null) ? target.animations[curAnim].anim : '';
			var lastOffsets:Array<Int> = null;
			var sprCast:ModchartSprite = cast (target.sprite, ModchartSprite);

			for (anim in target.animations.copy())
				if(animationInputText.text == anim.anim)
				{
					lastOffsets = anim.offsets;
					sprCast.animOffsets.remove(animationInputText.text);
					if(sprCast.animation.curAnim != null && sprCast.animation.curAnim.name == animationInputText.text)
						sprCast.animation.curAnim = null;

					sprCast.animation.remove(animationInputText.text);
					target.animations.remove(anim);
				}

			var addedAnim:AnimArray = {
				anim: animationInputText.text,
				name: animationNameInputText.text,
				fps: Math.round(animationFramerate.value),
				loop: animationLoopCheckBox.checked,
				indices: indices,
				offsets: lastOffsets
			};

			if(addedAnim.indices != null && addedAnim.indices.length > 0)
				target.sprite.animation.addByIndices(addedAnim.anim, addedAnim.name, addedAnim.indices, '', addedAnim.fps, addedAnim.loop);
			else
				target.sprite.animation.addByPrefix(addedAnim.anim, addedAnim.name, addedAnim.fps, addedAnim.loop);
				if(!target.sprite.animation.exists(addedAnim.anim)){
					showOutput('No animation found with tag "${addedAnim.name}"', true);
					return;
				}

			target.animations.push(addedAnim);
			reloadAnimList();
			playAnim(addedAnim.anim, true);

			curAnim = target.animations.length - 1;
			updateTextColors();
			trace('Added/Updated animation: ' + animationInputText.text);
		});

		var removeButton:PsychUIButton = new PsychUIButton(160, animationIndicesInputText.y + 35, 'Remove', function()
		{
			for (anim in target.animations)
			{
				if(animationInputText.text == anim.anim)
				{
					var targetSprite:ModchartSprite = cast (target.sprite, ModchartSprite);
					var resetAnim:Bool = false;
					if(targetSprite.animation.curAnim != null && anim.anim == targetSprite.animation.curAnim.name) resetAnim = true;

					if(targetSprite.animOffsets.exists(anim.anim))
						targetSprite.animOffsets.remove(anim.anim);

					target.animations.remove(anim);
					targetSprite.animation.remove(anim.anim);

					if(resetAnim && target.animations.length > 0)
					{
						curAnim = FlxMath.wrap(curAnim, 0, target.animations.length-1);
						playAnim(target.animations[curAnim].anim, true);
						updateTextColors();
					}
					else if(target.animations.length < 1)
						target.sprite.animation.curAnim = null;

					trace('Removed animation: ' + animationInputText.text);
					reloadAnimList();
					break;
				}
			}
		});

		tab_group.add(new FlxText(animationDropDown.x, animationDropDown.y - 18, 0, 'Animations:'));
		tab_group.add(new FlxText(animationInputText.x, animationInputText.y - 18, 0, 'Animation name:'));
		tab_group.add(new FlxText(animationFramerate.x, animationFramerate.y - 18, 0, 'Framerate:'));
		tab_group.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 18, 0, 'Animation Symbol Name/Tag:'));
		tab_group.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 18, 0, 'ADVANCED - Animation Indices:'));

		tab_group.add(animationInputText);
		tab_group.add(animationNameInputText);
		tab_group.add(animationIndicesInputText);
		tab_group.add(animationFramerate);
		tab_group.add(animationLoopCheckBox);
		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);
		tab_group.add(animationDropDown);
	}

	function reloadAnimList()
	{
		if(target.animations == null) target.animations = [];
		else if(target.animations.length > 0) playAnim(target.animations[0].anim, true);
		curAnim = 0;

		for (text in animsTxtGroup)
			text.kill();

		var spr:ModchartSprite = cast (target.sprite, ModchartSprite);
		if(target.animations.length > 0)
		{
			if(target.firstAnimation == null || !target.sprite.animation.exists(target.firstAnimation))
				target.firstAnimation = target.animations[0].anim;

			mainAnimTxt.text = 'Main Anim.: ${target.firstAnimation}';
		}
		else
		{
			target.firstAnimation = null;
			mainAnimTxt.text = '(No Main Animation)';
		}

		for (num => anim in target.animations)
		{
			var text:FlxText = animsTxtGroup.recycle(FlxText);
			text.x = 10;
			text.y = 32 + (20 * num);
			text.fieldWidth = 400;
			text.fieldHeight = 20;
			if(anim.offsets != null)
				text.text = '${anim.anim}: ${spr.animOffsets.get(anim.anim)}';
			else
				text.text = '${anim.anim}: No offsets';

			text.setFormat(null, 16, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
			text.scrollFactor.set();
			text.borderSize = 1;
			animsTxtGroup.add(text);
		}
		updateTextColors();
		reloadAnimationDropDown();
	}
	
	function reloadAnimationDropDown() {
		var animList:Array<String> = [];
		for (anim in target.animations) animList.push(anim.anim);
		if(animList.length < 1) animList.push('NO ANIMATIONS'); //Prevents crash

		animationDropDown.list = animList;
	}

	inline function updateTextColors()
	{
		for (num => text in animsTxtGroup)
		{
			text.color = FlxColor.WHITE;
			if(num == curAnim) text.color = FlxColor.LIME;
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

	function playAnim(name:String, force:Bool = false)
	{
		var spr:ModchartSprite = cast (target.sprite, ModchartSprite);
		spr.playAnim(name, force);
		if(!spr.animOffsets.exists(name)) spr.updateHitbox();
	}
	
	final minZoom = 0.25;
	final maxZoom = 2;
	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;
	var holdingFrameTime:Float = 0;
	var holdingFrameElapsed:Float = 0;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		outputTime = Math.max(0, outputTime - elapsed);
		outputTxt.alpha = outputTime;

		if(PsychUIInputText.focusOn != null) return;

		var mouseDX:Int = 0;
		var mouseDY:Int = 0;
		if(parentState.skipMouseDelta) parentState.skipMouseDelta = false;
		else{
			mouseDX = FlxG.mouse.deltaScreenX;
			mouseDY = FlxG.mouse.deltaScreenY;
		}

		// ANIMATION SCROLLING
		if(target.animations.length > 1)
		{
			var changedAnim:Bool = false;
			if(FlxG.keys.justPressed.W && (changedAnim = true)) curAnim--;
			else if(FlxG.keys.justPressed.S && (changedAnim = true)) curAnim++;
			else if(FlxG.keys.justPressed.SPACE) changedAnim = true;

			if(changedAnim)
			{
				curAnim = FlxMath.wrap(curAnim, 0, target.animations.length-1);
				playAnim(target.animations[curAnim].anim, true);
				updateTextColors();
			}
		}

		var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		var shiftMultBig:Float = 1;
		if(FlxG.keys.pressed.SHIFT)
		{
			shiftMult = 4;
			shiftMultBig = 10;
		}
		if(FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		// OFFSET
		if(target.sprite.animation.curAnim != null)
		{
			var spr:ModchartSprite = cast (target.sprite, ModchartSprite);
			var anim:String = spr.animation.curAnim.name;
			var changedOffset = false;
			var moveKeysP = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];
			var moveKeys = [FlxG.keys.pressed.LEFT, FlxG.keys.pressed.RIGHT, FlxG.keys.pressed.UP, FlxG.keys.pressed.DOWN];
			if(moveKeysP.contains(true))
			{
				if(spr.animOffsets.get(anim) != null)
				{
					spr.offset.x += ((moveKeysP[0] ? 1 : 0) - (moveKeysP[1] ? 1 : 0)) * shiftMultBig;
					spr.offset.y += ((moveKeysP[2] ? 1 : 0) - (moveKeysP[3] ? 1 : 0)) * shiftMultBig;
				}
				else spr.offset.x = spr.offset.y = 0;
				changedOffset = true;
			}
	
			if(moveKeys.contains(true))
			{
				holdingArrowsTime += elapsed;
				if(holdingArrowsTime > 0.6)
				{
					holdingArrowsElapsed += elapsed;
					while(holdingArrowsElapsed > (1/60))
					{
						if(spr.animOffsets.get(anim) != null)
						{
							spr.offset.x += ((moveKeys[0] ? 1 : 0) - (moveKeys[1] ? 1 : 0)) * shiftMultBig;
							spr.offset.y += ((moveKeys[2] ? 1 : 0) - (moveKeys[3] ? 1 : 0)) * shiftMultBig;
						}
						else spr.offset.x = spr.offset.y = 0;
						holdingArrowsElapsed -= (1/60);
						changedOffset = true;
					}
				}
			}
			else holdingArrowsTime = 0;
	
			if(FlxG.mouse.pressedRight && (mouseDX != 0 || mouseDY != 0))
			{
				spr.offset.x -= mouseDX;
				spr.offset.y -= mouseDY;
				changedOffset = true;
			}

			if (FlxG.keys.justPressed.R && FlxG.keys.pressed.CONTROL)
			{
				target.animations[curAnim].offsets = null;
				spr.animOffsets.remove(anim);
				spr.updateHitbox();
				animsTxtGroup.members[curAnim].text = '${anim}: No offsets';
			}
			
			if(changedOffset)
			{
				var offX = Math.round(spr.offset.x);
				var offY = Math.round(spr.offset.y);

				spr.addOffset(anim, offX, offY);
				target.animations[curAnim].offsets = [offX, offY];
				animsTxtGroup.members[curAnim].text = '${anim}: ${spr.animOffsets.get(anim)}';
			}
		}
		else
		{
			holdingArrowsTime = 0;
			holdingArrowsElapsed = 0;
		}

		// CAMERA CONTROLS
		var camMove:Float = 500 * elapsed / FlxG.camera.zoom;
		var camX:Float = 0;
		var camY:Float = 0;
		if (FlxG.keys.pressed.J) camX -= camMove;
		if (FlxG.keys.pressed.K) camY += camMove;
		if (FlxG.keys.pressed.L) camX += camMove;
		if (FlxG.keys.pressed.I) camY -= camMove;

		var isOverUI:Bool = UI_animationbox.visible && FlxG.mouse.overlaps(UI_animationbox, camHUD);

		if(FlxG.mouse.justPressed && !FlxG.mouse.pressedRight) camDragging = !isOverUI;
		else if(!FlxG.mouse.pressed || FlxG.mouse.pressedRight) camDragging = false;

		if(camDragging && (mouseDX != 0 || mouseDY != 0)){
			camX -= mouseDX;
			camY -= mouseDY;
		}

		if(camX != 0 || camY != 0) 
			FlxG.camera.scroll.add(camX, camY);
		if(!isOverUI && FlxG.mouse.wheel != 0)
			FlxG.camera.zoom = Math.max(minZoom, Math.min(maxZoom, FlxG.camera.zoom + (FlxG.mouse.wheel*0.1)));

		var lastZoom = FlxG.camera.zoom;
		if(FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL){
			FlxG.camera.zoom = 0.5;
			FlxG.camera.scroll.set(0,0);
			centerTargetOnFrame();
		}
		else if (FlxG.keys.pressed.E && FlxG.camera.zoom < maxZoom)
			FlxG.camera.zoom = Math.min(maxZoom, FlxG.camera.zoom + elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);
		else if (FlxG.keys.pressed.Q && FlxG.camera.zoom > minZoom)
			FlxG.camera.zoom = Math.max(minZoom, FlxG.camera.zoom - elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);

		if(FlxG.keys.justPressed.ESCAPE)
		{
			persistentDraw = true;
			close();
		}
	}
}
